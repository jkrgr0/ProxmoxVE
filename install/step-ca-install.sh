#!/usr/bin/env bash

# Copyright (c) 2024 jkrgr0
# Author: jkrgr0
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing step-ca"
curl -sL https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb -o /tmp/step-cli_amd64.deb
curl -sL https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.deb -o /tmp/step-ca_amd64.deb
dpkg -i /tmp/step-cli_amd64.deb
dpkg -i /tmp/step-ca_amd64.deb
msg_ok "Installed step-ca"

msg_info "Create service user"
useradd --user-group --system --home /etc/step-ca --shell /bin/false step
setcap CAP_NET_BIND_SERVICE=+eip $(which step-ca)
mkdir /etc/step-ca
chown -R step:step /etc/step-ca
msg_ok "Created service user"

msg_info "Generating password for CA keys and first provisioner"
su step -c "< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32} > /etc/step-ca/password.txt"
chmod 600 /etc/step-ca/password.txt
msg_ok "Generated password for CA keys and first provisioner"

msg_info "Initialize CA"
STEPPATH=/etc/step-ca su -w STEPPATH -s /bin/bash step
step ca init --password-file=/etc/step-ca/password.txt \
    --provisioner-password-file=/etc/step-ca/password.txt
exit
msg_ok "Initialized CA"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/step-ca.service
[Unit]
Description=step-ca service
Documentation=https://smallstep.com/docs/step-ca
Documentation=https://smallstep.com/docs/step-ca/certificate-authority-server-production
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=30
StartLimitBurst=3
ConditionFileNotEmpty=/etc/step-ca/config/ca.json
ConditionFileNotEmpty=/etc/step-ca/password.txt

[Service]
Type=simple
User=step
Group=step
Environment=STEPPATH=/etc/step-ca
WorkingDirectory=/etc/step-ca
ExecStart=/usr/bin/step-ca config/ca.json --password-file password.txt
ExecReload=/bin/kill --signal HUP $MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=30
StartLimitBurst=3

; Process capabilities & privileges
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
SecureBits=keep-caps
NoNewPrivileges=yes

; Sandboxing
ProtectSystem=full
ProtectHome=true
RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
PrivateTmp=true
PrivateDevices=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelTunables=true
ProtectKernelLogs=true
ProtectKernelModules=true
LockPersonality=true
RestrictSUIDSGID=true
RemoveIPC=true
RestrictRealtime=true
SystemCallFilter=@system-service
SystemCallArchitectures=native
MemoryDenyWriteExecute=true
ReadWriteDirectories=/etc/step-ca/db

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now step-ca.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -f /tmp/step-cli_amd64.deb
rm -f /tmp/step-ca_amd64.deb
$STD apt-get -y autoremote
$STD apt-get -y autoclean
msg_ok "Cleaned"

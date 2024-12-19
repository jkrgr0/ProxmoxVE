#!/usr/bin/env bash

# Copyright (c) 2021-2024 community-scripts ORG
# Author: jkrgr0
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

# Import Functions and Setup
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    curl \
    openssl
msg_ok "Installed Dependencies"

msg_info "Installing step-cli"
CLI_RELEASE=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q -P /tmp "https://github.com/smallstep/cli/releases/download/v${CLI_RELEASE}/step-cli_amd64.deb"
$STD dpkg -i /tmp/step-cli_amd64.deb
msg_ok "Installed step-cli"

msg_info "Installing step-ca"
CA_RELEASE=$(curl -s https://api.github.com/repos/smallstep/certificates/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q -P /tmp "https://github.com/smallstep/certificates/releases/download/v${CA_RELEASE}/step-ca_amd64.deb"
$STD dpkg -i /tmp/step-ca_amd64.deb
msg_ok "Installed step-ca"

msg_info "Write Release File"
cat <<EOF > "/opt/${APPLICATION}_version.txt"
step-cli=${CLI_RELEASE}
step-ca=${CA_RELEASE}
EOF
msg_ok "Written Release File"

msg_info "Creating Service User"
useradd --user-group --system --home /opt/step-ca --shell /bin/false step
setcap CAP_NET_BIND_SERVICE=+eip "$(which step-ca)"
mkdir /opt/step-ca
chown -R step:step /opt/step-ca
msg_ok "Created Service User"

msg_info "Generating password for CA keys and first provisioner"
su -s /bin/bash -c "openssl rand -base64 64 | tr -dc 'a-zA-z0-9' | head -c32 > /opt/step-ca/password.txt" step
su -s /bin/bash -c "chmod 600 /opt/step-ca/password.txt" step
msg_ok "Generated password for CA keys and first provisioner"

msg_info "Setup Step-CA"
STEPPATH=/opt/step-ca su \
    -w STEPPATH \
    -s /bin/bash \
    -c "step ca init --password-file=/opt/step-ca/password.txt --provisioner-password-file=/opt/step-ca/password.txt" \
    step
msg_ok "Setup Step-CA"

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
ConditionFileNotEmpty=/opt/step-ca/config/ca.json
ConditionFileNotEmpty=/opt/step-ca/password.txt

[Service]
Type=simple
User=step
Group=step
Environment=STEPPATH=/opt/step-ca
WorkingDirectory=/opt/step-ca
ExecStart=/usr/bin/step-ca config/ca.json --password-file password.txt
ExecReload=/bin/kill --signal HUP \$MAINPID
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
ReadWriteDirectories=/opt/step-ca/db

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

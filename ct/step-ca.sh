#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/jkrgr0/ProxmoxVE/refs/heads/feature/step-ca/misc/build.func)
# Copyright (c) 2024 community-scripts ORG
# Author: jkrgr0
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://smallstep.com/certificates/index.html

# App Default Values
APP="Step-CA"
var_tags="pki;acme"
var_cpu="1"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    # Check if installation is present
    if [[ ! -d /opt/step-ca ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    # Get the latest step-cli release and update if required
    CLI_RELEASE=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
    if [[ "${CLI_RELEASE}" != "$(cat /opt/${APP}_version.txt | sed -n 's/step-cli=\([0-9\.]\)/\1/p')" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
        msg_info "Updating ${APP} (step-cli) to v${CLI_RELEASE}"

        wget -q -P /tmp "https://github.com/smallstep/cli/releases/download/v${CLI_RELEASE}/step-cli_amd64.deb"
        $STD dpkg -i /tmp/step-cli_amd64.deb

        sed -i -e "s|^step-cli=.*|step-cli=$CLI_RELEASE|" "/opt/${APP}_version.txt"
        msg_info "Updated ${APP} (step-cli) to v${CLI_RELEASE}"
    else
        msg_ok "No update required. ${APP} (step-cli) is already at v${CLI_RELEASE}"
    fi

    # Get the latest step-ca release and update if required
    CA_RELEASE=$(curl -s https://api.github.com/repos/smallstep/certificates/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
    if [[ "${CA_RELEASE}" != "$(cat /opt/${APP}_version.txt | sed -n 's/step-ca=\([0-9\.]\)/\1/p')" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
        msg_info "Updating ${APP} (step-ca) to v${CA_RELEASE}"

        # Stopping services
        msg_info "Stopping ${APP}"
        systemctl stop step-ca.service
        msg_ok "Stopped ${APP}"
    
        # Execute Update
        msg_info "Updating $APP"
        wget -q -P /tmp "https://github.com/smallstep/certificates/releases/download/v${CA_RELEASE}/step-ca_amd64.deb"
        $STD dpkg -i /tmp/step-ca_amd64.deb

        msg_ok "Updated $APP"

        # Starting Services
        msg_info "Starting $APP"
        systemctl start step-ca.service
        sleep 2
        msg_ok "Started $APP"

        # Cleaning up
        msg_info "Cleaning Up"
        rm /tmp/step-ca_amd64.deb
        msg_ok "Cleanup completed"

        # Last Action
        sed -i -e "s|^step-ca=.*|step-ca=$CA_RELEASE|" "/opt/${APP}_version.txt"
        msg_ok "Updated ${APP} (step-ca) to v${CA_RELEASE}"
    else
        msg_ok "No update required. ${APP} (step-ca) is already at v${CA_RELEASE}"
    fi
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}:443${CL}"

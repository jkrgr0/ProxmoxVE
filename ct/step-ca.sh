#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2024 jkrgr0
# Author: jkrgr
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://smallstep.com/certificates/index.html

# App Default Values
APP="Step-CA"
var_tags="ca"
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
    if [[ ! -d /opt/step-ca ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating ${APP}"
    systemctl stop step-ca.service
    curl https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb -o /tmp/step-cli_amd64.deb
    curl https://dl.smallstep.com/cli/docs-ca-install/latest/step-ca_amd64.deb -o /tmp/step-ca_amd64.deb
    dpkg -i /tmp/step-cli_amd64.deb
    dpkg -i /tmp/step-ca_amd64.deb
    rm /tmp/step-{cli,ca}_amd64.deb
    systemctl start step-ca.service
    msg_ok "Successfully Updated ${APP}"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"

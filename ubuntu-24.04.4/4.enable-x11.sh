#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# Change GDM
###############################################################################

read -rp "Switch to X11? (y/N): " ans

if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
    sudo systemctl reboot -i
fi

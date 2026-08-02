#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== System update ====="
sudo apt update
sudo apt full-upgrade -y

echo "===== Configuring automatic updates (unattended-upgrades) ====="
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

echo "===== Base utils ====="
sudo apt install -y gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager libfuse2t64 ubuntu-restricted-extras gdebi-core jq gir1.2-gtop-2.0 lm-sensors ca-certificates curl gnupg wget unzip git gir1.2-gtop-2.0 lm-sensors xz-utils desktop-file-utils

sudo systemctl reboot -i

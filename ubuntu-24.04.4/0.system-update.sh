#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== System update ====="
sudo apt update
sudo apt full-upgrade -y

echo "===== Base utils ====="
sudo apt install -y gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager libfuse2t64 ubuntu-restricted-extras gdebi-core jq gir1.2-gtop-2.0 lm-sensors ca-certificates curl gnupg wget unzip git gir1.2-gtop-2.0 lm-sensors xz-utils desktop-file-utils build-essential htop btop tmux zsh p7zip-full ripgrep fd-find nvme-cli smartmontools

echo "===== SSD enable TRIM ====="
sudo systemctl enable --now fstrim.timer

echo "===== update firmware ====="
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update

sudo reboot

#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== Оновлення системи ====="
sudo apt update
sudo apt full-upgrade -y

echo "===== Базові утиліти ====="
sudo apt install -y gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager libfuse2t64 ubuntu-restricted-extras gdebi-core jq gir1.2-gtop-2.0 lm-sensors ca-certificates curl gnupg wget unzip git gir1.2-gtop-2.0 lm-sensors xz-utils desktop-file-utils build-essential htop btop tmux zsh p7zip-full ripgrep fd-find nvme-cli smartmontools

echo "===== Увімкнення TRIM для SSD ====="
sudo systemctl enable --now fstrim.timer

echo "===== Оновлення прошивки ====="
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update

sudo reboot

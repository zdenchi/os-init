#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== Увеличение раздела swap ====="
sudo swapoff /swap.img
sudo rm /swap.img
sudo fallocate -l 16G /swap.img
sudo chmod 600 /swap.img
sudo mkswap /swap.img
sudo swapon /swap.img
free -h

#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# Create new user
###############################################################################

read -rp "Create new user? (y/N): " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
  read -rp "Username: " username
  sudo adduser "$username"
fi

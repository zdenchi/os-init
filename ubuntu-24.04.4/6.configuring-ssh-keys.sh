#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== Generate SSH Key and git config ====="
email=""
name=""

# Get email
while [ -z "$email" ]; do
  read -p "Enter your email: " email
done

# Get name
while [ -z "$name" ]; do
  read -p "Enter your name: " name
done

# Generate ssh keys
ssh-keygen -t ed25519 -C "$email"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Generate git config
git config --global user.name "$name"
git config --global user.email "$email"

#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== Генерація SSH-ключа та git config ====="
email=""
name=""

# Отримати email
while [ -z "$email" ]; do
  read -p "Введи email: " email
done

# Отримати ім’я
while [ -z "$name" ]; do
  read -p "Введи ім’я: " name
done

# Згенерувати ssh-ключі
ssh-keygen -t ed25519 -C "$email"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Згенерувати git config
git config --global user.name "$name"
git config --global user.email "$email"

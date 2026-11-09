#!/usr/bin/env bash
set -euo pipefail

# Автоматичне налаштування ZRAM + swap-файла залежно від обсягу RAM.
#
# Рекомендації:
# <= 8 GB   RAM -> ZRAM 50%, swap 8 GB
# <= 16 GB  RAM -> ZRAM 50%, swap 8 GB
# <= 32 GB  RAM -> ZRAM 25%, swap 8 GB
# <= 64 GB  RAM -> ZRAM 25%, swap 4 GB
# >  64 GB  RAM -> ZRAM 25%, swap 4 GB

if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт через sudo:"
  echo "sudo $0"
  exit 1
fi

RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_GB=$(( (RAM_KB + 1024*1024 - 1) / (1024*1024) ))

echo "Виявлено RAM: ~${RAM_GB} GB"

if (( RAM_GB <= 8 )); then
  ZRAM_PERCENT=50
  SWAP_GB=8
elif (( RAM_GB <= 16 )); then
  ZRAM_PERCENT=50
  SWAP_GB=8
elif (( RAM_GB <= 32 )); then
  ZRAM_PERCENT=25
  SWAP_GB=8
elif (( RAM_GB <= 64 )); then
  ZRAM_PERCENT=25
  SWAP_GB=4
else
  ZRAM_PERCENT=25
  SWAP_GB=4
fi

echo "Буде налаштовано:"
echo "  ZRAM: ${ZRAM_PERCENT}% RAM"
echo "  Swapfile: ${SWAP_GB} GB"

# ---------------------------------------------------------
# ZRAM
# ---------------------------------------------------------

apt update
DEBIAN_FRONTEND=noninteractive apt install -y zram-tools

cat > /etc/default/zramswap <<EOF
ALGO=zstd
PERCENT=${ZRAM_PERCENT}
PRIORITY=100
EOF

systemctl enable zramswap 2>/dev/null || true
systemctl restart zramswap

# ---------------------------------------------------------
# Swapfile
# ---------------------------------------------------------

if swapon --show=NAME --noheadings | grep -qx "/swapfile"; then
  swapoff /swapfile
fi

rm -f /swapfile

fallocate -l "${SWAP_GB}G" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Видалити старі записи /swapfile з fstab
sed -i '\|^/swapfile[[:space:]]|d' /etc/fstab

echo '/swapfile none swap sw,pri=10 0 0' >> /etc/fstab

# ---------------------------------------------------------
# Налаштування ядра VM
# ---------------------------------------------------------

cat > /etc/sysctl.d/99-memory-tuning.conf <<'EOF'
# Віддаємо перевагу швидкому ZRAM перед звичайним swap на SSD
vm.swappiness=100

# Раніше починати фонове очищення inode/dentry cache
vm.vfs_cache_pressure=100
EOF

sysctl --system >/dev/null

# ---------------------------------------------------------
# Перевірка
# ---------------------------------------------------------

echo
echo "========================================="
echo "Налаштування завершено"
echo "========================================="
echo
free -h

echo
echo "SWAP:"
swapon --show

echo
echo "ZRAM:"
zramctl || true

echo
echo "Swappiness:"
sysctl vm.swappiness

#!/bin/bash
# Install unifi-isp-splitter on a UniFi OS device
# Run this script via SSH on the UniFi gateway

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing unifi-isp-splitter ==="

# Deploy update scripts
mkdir -p /data/custom
cp "$SCRIPT_DIR/scripts/update_first_mobilev4.sh" /data/custom/update_first_mobilev4.sh
cp "$SCRIPT_DIR/scripts/update_first_telecomv4.sh" /data/custom/update_first_telecomv4.sh
chmod +x /data/custom/update_first_mobilev4.sh /data/custom/update_first_telecomv4.sh
echo "[OK] Update scripts -> /data/custom/"

# Deploy on_boot.d hooks
mkdir -p /data/on_boot.d
cp "$SCRIPT_DIR/scripts/10-update-mobilev4-cron.sh" /data/on_boot.d/10-update-mobilev4-cron.sh
cp "$SCRIPT_DIR/scripts/on-boot-custom.service" /data/on_boot.d/on-boot-custom.service
chmod +x /data/on_boot.d/10-update-mobilev4-cron.sh
echo "[OK] Boot hooks -> /data/on_boot.d/"

# Install systemd service
cp "$SCRIPT_DIR/scripts/on-boot-custom.service" /etc/systemd/system/on-boot-custom.service
systemctl daemon-reload
systemctl enable on-boot-custom.service
echo "[OK] Systemd service enabled"

# Set up cron
if ! crontab -l 2>/dev/null | grep -q 'update_first_mobilev4'; then
    (crontab -l 2>/dev/null; echo '30 4 * * * /data/custom/update_first_mobilev4.sh >> /data/custom/update_first_mobilev4.log 2>&1') | crontab -
fi
if ! crontab -l 2>/dev/null | grep -q 'update_first_telecomv4'; then
    (crontab -l 2>/dev/null; echo '40 4 * * * /data/custom/update_first_telecomv4.sh >> /data/custom/update_first_telecomv4.log 2>&1') | crontab -
fi
echo "[OK] Cron jobs set (daily 04:30 mobile, 04:40 telecom)"

# Run once
echo ""
echo "=== Running initial update ==="
/data/custom/update_first_mobilev4.sh
/data/custom/update_first_telecomv4.sh

echo ""
echo "=== Installation complete ==="

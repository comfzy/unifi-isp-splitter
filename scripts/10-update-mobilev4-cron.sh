#!/bin/bash
# Self-bootstrapping: re-install systemd service + cron after firmware upgrade

# Ensure this systemd service exists (firmware upgrade may wipe /etc/systemd/)
SERVICE_SRC="/data/on_boot.d/on-boot-custom.service"
SERVICE_DST="/etc/systemd/system/on-boot-custom.service"
if [ -f "$SERVICE_SRC" ] && [ ! -f "$SERVICE_DST" ]; then
    cp "$SERVICE_SRC" "$SERVICE_DST"
    systemctl daemon-reload
    systemctl enable on-boot-custom.service
fi

# Ensure cron job exists
if ! crontab -l 2>/dev/null | grep -q 'update_first_mobilev4'; then
    (crontab -l 2>/dev/null; echo '30 4 * * * /data/custom/update_first_mobilev4.sh >> /data/custom/update_first_mobilev4.log 2>&1') | crontab -
fi

#!/bin/bash
# Update First_telecomv4 traffic route IPs from tcp5.com
# Runs daily via cron

set -euo pipefail

LOG_TAG="update_first_telecomv4"
RSC_URL="http://ros.tcp5.com/list/telecom_latest.rsc"
MONGO_CMD="mongo --quiet --port 27117 ace"
ROUTE_DESC="First_telecomv4"
IPSET_NAME="UBIOS4trafficroute_ip_4"
TMP_FILE="/tmp/telecom_ips.tmp"
TMP_JS="/tmp/telecom_update.js"
TMP_IPS="/tmp/telecom_ips_list.txt"
LOG_FILE="/data/custom/update_first_telecomv4.log"

log() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log "Starting update..."

# Download rsc file
curl -sf --connect-timeout 10 --max-time 60 "$RSC_URL" -o "$TMP_FILE"
if [ ! -s "$TMP_FILE" ]; then
    log "ERROR: Failed to download rsc file"
    rm -f "$TMP_FILE"
    exit 1
fi

# Extract CIDR addresses from rsc format (address=x.x.x.x/xx)
IP_LIST=$(sed -n 's/.*address=\([0-9.\/]*\).*/\1/p' "$TMP_FILE")
IP_COUNT=$(echo "$IP_LIST" | wc -l | tr -d ' ')

if [ "$IP_COUNT" -lt 100 ]; then
    log "ERROR: Only got $IP_COUNT IPs, seems too few. Aborting."
    rm -f "$TMP_FILE"
    exit 1
fi

log "Extracted $IP_COUNT IPs from rsc file"

# Build mongo JS file
{
    echo 'var newIPs = ['
    echo "$IP_LIST" | awk '{printf "{\"ip_version\":\"V4\",\"ip_or_subnet\":\"%s\",\"ports\":[],\"port_ranges\":[]},\n", $1}'
    echo '];'
    cat << 'MONGOJS'
var result = db.traffic_route.updateOne(
    {description: "First_telecomv4"},
    {$set: {ip_addresses: newIPs}}
);
if (result.matchedCount === 0) {
    print("ERROR: Route not found");
    quit(1);
}
print("Updated: matched=" + result.matchedCount + " modified=" + result.modifiedCount);
MONGOJS
} > "$TMP_JS"

# Update MongoDB
$MONGO_CMD "$TMP_JS"
if [ $? -ne 0 ]; then
    log "ERROR: MongoDB update failed"
    rm -f "$TMP_FILE" "$TMP_JS"
    exit 1
fi

# Sync ipset directly (UniFi won't auto-reload from DB change)
echo "$IP_LIST" > "$TMP_IPS"
ipset flush "$IPSET_NAME"
while IFS= read -r ip; do
    ipset add "$IPSET_NAME" "$ip" 2>/dev/null
done < "$TMP_IPS"

NEW_IPSET_COUNT=$(ipset list "$IPSET_NAME" | sed -n 's/Number of entries: //p')
log "Done. MongoDB=$IP_COUNT, ipset=$NEW_IPSET_COUNT for $ROUTE_DESC"

# Trim log to last 100 lines
tail -100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"

rm -f "$TMP_FILE" "$TMP_JS" "$TMP_IPS"

# unifi-isp-splitter

Automatically update ISP-based policy routing (PBR) split tables on UniFi gateways. Parses carrier IP ranges from RouterOS `.rsc` sources and syncs them into UniFi's traffic routes via MongoDB + ipset.

## How It Works

```
tcp5.com (.rsc)  -->  Parse & extract CIDRs  -->  Update MongoDB (ace.traffic_route)
                                               -->  Flush & reload ipset (takes effect immediately)
```

UniFi stores Traffic Route configurations in a local MongoDB database. The actual routing enforcement relies on iptables mangle marks + ipset + ip rule. This tool updates both layers directly — no Web UI interaction needed.

## Compatibility

- UniFi OS gateways (UDM / UDM-Pro / UDM-SE / UCG-Ultra, etc.)
- A Traffic Route rule must already exist in the Web UI
- SSH access to the device is required

## Prerequisites

Create a Traffic Route in the UniFi Web UI for each ISP. Take note of:
- **description** (rule name)
- **short_id** (maps to ipset name `UBIOS4trafficroute_ip_<short_id>`)

Two update scripts are included out of the box:

| Script | Rule Name | ipset | Data Source |
|--------|-----------|-------|-------------|
| `update_first_mobilev4.sh` | `First_mobilev4` | `UBIOS4trafficroute_ip_3` | China Mobile |
| `update_first_telecomv4.sh` | `First_telecomv4` | `UBIOS4trafficroute_ip_4` | China Telecom |

If your rule names or short_ids differ, edit the variables in the corresponding script:

```bash
ROUTE_DESC="First_mobilev4"           # description field in MongoDB
IPSET_NAME="UBIOS4trafficroute_ip_3"  # ipset name, 3 = short_id
```

## Inspect Your Traffic Routes

SSH into the device:

```bash
# List all traffic routes
mongo --quiet --port 27117 ace --eval \
  'db.traffic_route.find({}, {description:1, short_id:1}).forEach(printjson)'

# Show policy routing rules
ip rule show

# List traffic route ipsets
ipset list -n | grep trafficroute
```

## Installation

```bash
# On the UniFi device via SSH
git clone https://github.com/<your-username>/unifi-isp-splitter.git /tmp/unifi-isp-splitter
cd /tmp/unifi-isp-splitter
bash install.sh
```

Or copy files manually:

```bash
scp -r scripts/ root@<gateway-ip>:/data/custom/
ssh root@<gateway-ip> "chmod +x /data/custom/scripts/*.sh"
```

## File Overview

```
scripts/
  update_first_mobilev4.sh    # China Mobile updater: download rsc -> extract IPs -> update MongoDB + ipset
  update_first_telecomv4.sh   # China Telecom updater: same workflow
  10-update-mobilev4-cron.sh  # Boot hook: restore systemd service and cron after firmware upgrade
  on-boot-custom.service      # systemd unit: runs on_boot.d/*.sh at startup
install.sh                    # One-step installer
```

## On-Device Layout

```
/data/custom/
  update_first_mobilev4.sh    # China Mobile updater
  update_first_mobilev4.log   # Mobile execution log (auto-trimmed to last 100 lines)
  update_first_telecomv4.sh   # China Telecom updater
  update_first_telecomv4.log  # Telecom execution log

/data/on_boot.d/
  10-update-mobilev4-cron.sh  # Restores cron on boot
  on-boot-custom.service      # systemd service backup

/etc/systemd/system/
  on-boot-custom.service      # Runs on_boot.d/ scripts at startup
```

## Scheduling

Default cron schedule, staggered by 10 minutes to avoid concurrent downloads:

| Time | Script |
|------|--------|
| 04:30 | `update_first_mobilev4.sh` (China Mobile) |
| 04:40 | `update_first_telecomv4.sh` (China Telecom) |

To change the schedule:

```bash
# On the device
crontab -e
```

## Firmware Upgrade Recovery

UniFi firmware upgrades preserve `/data/` but may wipe `/etc/systemd/` and crontab.

- **If the systemd service survives**: everything recovers automatically on reboot.
- **If the systemd service is lost**: run once to restore:
  ```bash
  /data/on_boot.d/10-update-mobilev4-cron.sh
  ```

## Data Sources

These `.rsc` files are maintained by [tcp5.com](http://ros.tcp5.com) and updated daily.

| ISP | rsc URL |
|-----|---------|
| China Mobile | `http://ros.tcp5.com/list/mobile_latest.rsc` |
| China Telecom | `http://ros.tcp5.com/list/telecom_latest.rsc` |
| China Unicom | `http://ros.tcp5.com/list/unicom_latest.rsc` |

To switch ISP, change the `RSC_URL` variable in the script.

## License

MIT

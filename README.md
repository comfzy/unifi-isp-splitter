# unifi-isp-splitter

[English](README_EN.md)

自动更新 UniFi 网关上的运营商策略路由（Policy Based Routing）分流表。

从 [tcp5.com](http://ros.tcp5.com) 获取最新的运营商 IP 段，解析 RouterOS `.rsc` 格式并同步到 UniFi 的 `traffic_route` 中，实现按运营商分流。

## 工作原理

```
tcp5.com (.rsc)  -->  解析提取 CIDR  -->  写入 MongoDB (ace.traffic_route)
                                      -->  刷新 ipset (内核即时生效)
```

UniFi 的 Traffic Route 在 Web UI 中创建后，配置存储在本地 MongoDB，实际生效靠 iptables mangle + ipset + ip rule。本工具直接更新这两层，无需通过 Web UI 手动操作。

## 适用环境

- UniFi OS 网关（UDM / UDM-Pro / UDM-SE / UCG-Ultra 等）
- 已在 Web UI 中创建好对应的 Traffic Route 规则
- 设备需要有 SSH 访问权限

## 前提条件

在 UniFi Web UI 中创建一条 Traffic Route，记住：
- **description**（规则名称），默认脚本使用 `First_mobilev4`
- **short_id**（对应 ipset 名称 `UBIOS4trafficroute_ip_<short_id>`）

如果你的规则名称或 short_id 不同，需要修改 `scripts/update_first_mobilev4.sh` 中的以下变量：

```bash
ROUTE_DESC="First_mobilev4"           # MongoDB 中的 description 字段
IPSET_NAME="UBIOS4trafficroute_ip_3"  # ipset 名称，3 = short_id
```

## 查看你的 Traffic Route 信息

SSH 到设备后：

```bash
# 查看所有 traffic route
mongo --quiet --port 27117 ace --eval 'db.traffic_route.find({}, {description:1, short_id:1}).forEach(printjson)'

# 查看当前 ip rule
ip rule show

# 查看 ipset
ipset list -n | grep trafficroute
```

## 安装

```bash
# SSH 到 UniFi 设备后
git clone https://github.com/<your-username>/unifi-isp-splitter.git /tmp/unifi-isp-splitter
cd /tmp/unifi-isp-splitter
bash install.sh
```

或手动复制文件：

```bash
scp -r scripts/ root@<gateway-ip>:/data/custom/
ssh root@<gateway-ip> "chmod +x /data/custom/scripts/*.sh"
```

## 文件说明

```
scripts/
  update_first_mobilev4.sh    # 主脚本：下载 rsc -> 提取 IP -> 更新 MongoDB + ipset
  10-update-mobilev4-cron.sh  # 开机自举：恢复 systemd service 和 cron
  on-boot-custom.service      # systemd 服务：开机执行 on_boot.d/*.sh
install.sh                    # 一键安装脚本
```

## 设备上的文件布局

```
/data/custom/
  update_first_mobilev4.sh    # 主脚本
  update_first_mobilev4.log   # 运行日志（自动保留最近 100 条）

/data/on_boot.d/
  10-update-mobilev4-cron.sh  # 开机恢复 cron
  on-boot-custom.service      # systemd service 备份

/etc/systemd/system/
  on-boot-custom.service      # 开机执行 on_boot.d/ 下的脚本
```

## 定时任务

默认每天凌晨 04:30 执行更新。修改频率：

```bash
# SSH 到设备
crontab -e
# 修改 30 4 * * * 这行的 cron 表达式
```

## 固件升级后的恢复

UniFi 固件升级会保留 `/data/` 但可能清除 `/etc/systemd/` 和 crontab。

- **如果 systemd service 存活**：重启后自动恢复，无需操作
- **如果 systemd service 丢失**：手动执行一次即可恢复全部
  ```bash
  /data/on_boot.d/10-update-mobilev4-cron.sh
  ```

## 数据源

| 运营商 | rsc URL |
|--------|---------|
| 中国移动 | `http://ros.tcp5.com/list/mobile_latest.rsc` |
| 中国电信 | `http://ros.tcp5.com/list/telecom_latest.rsc` |
| 中国联通 | `http://ros.tcp5.com/list/unicom_latest.rsc` |

如需切换运营商，修改脚本中的 `RSC_URL` 即可。

## License

MIT

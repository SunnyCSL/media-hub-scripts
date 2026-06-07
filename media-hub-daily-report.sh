#!/bin/bash
# Media Hub Daily Health Report — stdout = message body
# Called by: cron job every morning

HEALTH=$(/home/radxa/.hermes/profiles/home/scripts/media-hub-health.sh)

STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status'])")
ZURG=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['services']['zurg'])")
RCLONE=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['services']['rclone'])")
RDB=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['services']['rd_browser'])")
PLEX=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['docker']['plex'])")
JACKETT=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['docker']['jackett'])")
HA=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['docker']['homeassistant'])")
DISK=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['disk']['usage'])")
FREE=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['disk']['free'])")
ZURG_UP=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['uptime']['zurg'])")
PLEX_UP=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['uptime']['plex'])")

ICON="✅"
[ "$STATUS" != "ok" ] && ICON="⚠️"

echo "${ICON} Media Hub 每日報告
━━━━━━━━━━
Status: ${STATUS}

Zurg: ${ZURG}
rclone: ${RCLONE}
RD Browser: ${RDB}
Plex: ${PLEX}
Jackett: ${JACKETT}
HA: ${HA}

Disk: ${DISK} used (${FREE} free)
Zurg uptime: ${ZURG_UP}
Plex since: ${PLEX_UP}"

#!/bin/bash
# Media Hub Health Check — returns JSON status
# Called by: cron job / ad-hoc Robi query
# Usage: ./media-hub-health.sh (stdout = JSON)

set -e

STATUS="ok"
ERRORS=""

# 1. Zurg service
if systemctl is-active --quiet zurg.service; then
  ZURG="running"
else
  ZURG="dead"
  STATUS="degraded"
  ERRORS="$ERRORS zurg"
fi

# 2. rclone mount
if mountpoint -q /home/radxa/plex/media 2>/dev/null; then
  RCLONE="mounted"
else
  RCLONE="unmounted"
  STATUS="degraded"
  ERRORS="$ERRORS rclone-mount"
fi

# 3. rclone service
if systemctl is-active --quiet rclone-zurg.service; then
  RCLONE_SVC="running"
else
  RCLONE_SVC="dead"
  STATUS="degraded"
  ERRORS="$ERRORS rclone-svc"
fi

# 4. RD Browser
if systemctl is-active --quiet rd-browser.service; then
  RDBROWSER="running"
else
  RDBROWSER="dead"
  STATUS="degraded"
  ERRORS="$ERRORS rd-browser"
fi

# 5. Plex Docker
PLEX="$(docker inspect --format='{{.State.Status}}' plex 2>/dev/null || echo 'missing')"
if [ "$PLEX" != "running" ]; then
  STATUS="degraded"
  ERRORS="$ERRORS plex"
fi

# 6. Jackett Docker
JACKETT="$(docker inspect --format='{{.State.Status}}' jackett 2>/dev/null || echo 'missing')"
if [ "$JACKETT" != "running" ]; then
  STATUS="degraded"
  ERRORS="$ERRORS jackett"
fi

# 7. HA Docker
HA="$(docker inspect --format='{{.State.Status}}' homeassistant 2>/dev/null || echo 'missing')"
if [ "$HA" != "running" ]; then
  STATUS="degraded"
  ERRORS="$ERRORS homeassistant"
fi

# 8. Disk space
DISK_USAGE="$(df -h /home/radxa/plex/media 2>/dev/null | awk 'NR==2{print $5}')"
DISK_FREE="$(df -h /home/radxa/plex/media 2>/dev/null | awk 'NR==2{print $4}')"

# 9. Uptime
ZURG_UPTIME="$(systemctl show zurg.service -p ActiveEnterTimestamp --value 2>/dev/null || echo 'unknown')"
PLEX_UPTIME="$(docker inspect --format='{{.State.StartedAt}}' plex 2>/dev/null | cut -d. -f1 || echo 'unknown')"

echo "{
  \"status\": \"$STATUS\",
  \"errors\": \"$ERRORS\",
  \"services\": {
    \"zurg\": \"$ZURG\",
    \"rclone\": \"$RCLONE\",
    \"rclone_svc\": \"$RCLONE_SVC\",
    \"rd_browser\": \"$RDBROWSER\"
  },
  \"docker\": {
    \"plex\": \"$PLEX\",
    \"jackett\": \"$JACKETT\",
    \"homeassistant\": \"$HA\"
  },
  \"disk\": {
    \"usage\": \"$DISK_USAGE\",
    \"free\": \"$DISK_FREE\"
  },
  \"uptime\": {
    \"zurg\": \"$ZURG_UPTIME\",
    \"plex\": \"$PLEX_UPTIME\"
  }
}"

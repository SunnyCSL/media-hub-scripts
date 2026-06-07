#!/bin/bash
# Media Hub Safety Net - weekly deep checks
set -euo pipefail

ZURG_CONFIG="/home/radxa/zurg/config.yml"
ZURG_BIN="/home/radxa/zurg/zurg"
PLEX_URL="http://192.168.1.145:32400"
PLEX_PREFS="/home/radxa/plex/config/Library/Application Support/Plex Media Server/Preferences.xml"
RD_API="https://api.real-debrid.com/rest/1.0"
RD_TOKEN=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['token'])" "$ZURG_CONFIG" 2>/dev/null)
PLEX_TOKEN=$(python3 ""/home/radxa/.hermes/profiles/home/scripts/plex-token-extract.py"" "$PLEX_PREFS" 2>/dev/null)

if [ -z "$RD_TOKEN" ] || [ -z "$PLEX_TOKEN" ]; then
  echo "CRITICAL: Cannot load tokens"
  exit 1
fi

ALERT_FILE=`mktemp`
trap "rm -f $ALERT_FILE" EXIT

# 1. RD API health
echo "-> RD API health ..."
AUTH_HEADER="Authorization: Bearer $RD_TOKEN"
RD_RESP=`curl -sf --connect-timeout 10 -H "$AUTH_HEADER" "$RD_API/user" 2>/dev/null`

if [ -z "$RD_RESP" ]; then
  echo "!! RD API unreachable" >> "$ALERT_FILE"
  echo "  FAIL"
else
  RD_EMAIL=`echo "$RD_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('email','?'))" 2>/dev/null`
  RD_EXPIRY=`echo "$RD_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('expiration',''))" 2>/dev/null`
  if [ -n "$RD_EXPIRY" ] && [ "$RD_EXPIRY" != "null" ]; then
    NOW=`date +%s`
    EXP=`python3 -c "from datetime import datetime; print(int(datetime.fromisoformat('$RD_EXPIRY').timestamp()))" 2>/dev/null || echo "0"`
    if [ "$EXP" -gt 0 ] && [ "$EXP" -lt "$NOW" ]; then
      echo "!! RD Premium expired: $RD_EXPIRY" >> "$ALERT_FILE"
    elif [ "$EXP" -gt 0 ]; then
      DAYS_LEFT=$(( (EXP - NOW) / 86400 ))
      if [ "$DAYS_LEFT" -le 7 ]; then
        echo "!! RD Premium expires in ${DAYS_LEFT}d: $RD_EXPIRY" >> "$ALERT_FILE"
      fi
    fi
  fi
  echo "  OK ($RD_EMAIL)"
fi

# 2. Zurg version
echo "-> Zurg version ..."
CURRENT_VER=`strings "$ZURG_BIN" 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown"`
LATEST_VER=`curl -sf --connect-timeout 10 \
  "https://api.github.com/repos/debridmediamanager/zurg-testing/releases/latest" 2>/dev/null | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','unknown'))" 2>/dev/null || echo "unknown"`
echo "  current=$CURRENT_VER latest=$LATEST_VER"
CLEAN_CUR=`echo "$CURRENT_VER" | sed 's/^v//'`
CLEAN_LAT=`echo "$LATEST_VER" | sed 's/^v//'`
if [ "$CLEAN_LAT" != "unknown" ] && [ "$CLEAN_CUR" != "unknown" ] && [ "$CLEAN_CUR" != "$CLEAN_LAT" ] && [ -n "$CLEAN_LAT" ]; then
  echo "!! Zurg update: $CURRENT_VER -> $LATEST_VER" >> "$ALERT_FILE"
fi

# 3. Rclone mount
echo "-> Rclone mount ..."
if mountpoint -q /home/radxa/plex/media 2>/dev/null; then
  echo "  OK"
else
  echo "!! Rclone mount DOWN" >> "$ALERT_FILE"
fi

# 4. Plex scan
echo "-> Plex scan ..."
PLEX_SECTIONS=`curl -sf -H "X-Plex-Token: $PLEX_TOKEN" \
  "$PLEX_URL/library/sections" 2>/dev/null | \
  python3 -c "
import sys,re
h=sys.stdin.read()
k=chr(61)+chr(34)
v=chr(34)
for m in re.finditer('key'+k+'([0-9]+)'+v+'.*?title'+k+'([^'+v+']+)'+v,h):
    print(m.group(1)+chr(58)+m.group(2))
" 2>/dev/null || echo ""`

if [ -z "$PLEX_SECTIONS" ]; then
  echo "!! Plex sections discovery FAILED" >> "$ALERT_FILE"
else
  while IFS=: read -r KEY NAME; do
    RESP=`curl -sf -X POST "$PLEX_URL/library/sections/$KEY/refresh" \
      -H "X-Plex-Token: $PLEX_TOKEN" 2>/dev/null && echo "OK" || echo "FAIL"`
    echo "  $NAME -> $RESP"
    if [ "$RESP" = "FAIL" ]; then
      echo "!! Plex scan FAILED: $NAME" >> "$ALERT_FILE"
    fi
  done <<< "$PLEX_SECTIONS"
fi

# 5. Disk
echo "-> Disk ..."
DISK_PCT=`df / | awk 'NR==2 {print $5}' | sed 's/%//'`
DISK_FREE=`df -h / | awk 'NR==2 {print $4}'`
echo "  ${DISK_PCT}% used"
if [ "$DISK_PCT" -gt 90 ]; then
  echo "!! Disk CRITICAL: ${DISK_PCT}% (${DISK_FREE} free)" >> "$ALERT_FILE"
elif [ "$DISK_PCT" -gt 85 ]; then
  echo "!! Disk warning: ${DISK_PCT}% (${DISK_FREE} free)" >> "$ALERT_FILE"
fi

# 6. RD Browser
echo "-> RD Browser HTTP ..."
RDB_HTTP=`curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8899/ 2>/dev/null || echo "000"`
echo "  HTTP $RDB_HTTP"
if [ "$RDB_HTTP" = "000" ]; then
  echo "!! RD Browser HTTP dead" >> "$ALERT_FILE"
elif [ "$RDB_HTTP" != "200" ] && [ "$RDB_HTTP" != "302" ]; then
  echo "!! RD Browser HTTP anomaly ($RDB_HTTP)" >> "$ALERT_FILE"
fi

if [ -s "$ALERT_FILE" ]; then
  echo ""
  echo "!! Issues found:"
  cat "$ALERT_FILE"
  exit 1
else
  exit 0
fi
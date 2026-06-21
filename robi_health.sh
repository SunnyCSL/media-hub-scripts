#!/bin/bash
# Robi Voice System Health Check — silent watchdog
# Returns non-zero + error msg if something is wrong
# Designed for no_agent=True cron job (empty stdout = silent)

set -e

ERRORS=""

# 1. Bridge service
if ! systemctl is-active --quiet robi-bridge.service; then
    ERRORS="${ERRORS}⚠️ robi-bridge.service is DOWN\n"
    systemctl restart robi-bridge.service
    ERRORS="${ERRORS}   → Reboot issued\n"
fi

# 2. Voice pipeline
if ! systemctl is-active --quiet sticks3-voice.service; then
    ERRORS="${ERRORS}⚠️ sticks3-voice.service is DOWN\n"
    systemctl restart sticks3-voice.service
    ERRORS="${ERRORS}   → Reboot issued\n"
fi

# 3. Bridge HTTP endpoint
if ! curl -sf -o /dev/null http://127.0.0.1:9997/ 2>/dev/null; then
    ERRORS="${ERRORS}⚠️ Bridge HTTP endpoint unreachable on port 9997\n"
fi

# 4. HA reachable
if ! curl -sf -o /dev/null http://localhost:8123/ 2>/dev/null; then
    ERRORS="${ERRORS}⚠️ Home Assistant unreachable on port 8123\n"
fi

# 5. XVF3800 audio device
if ! arecord -l 2>/dev/null | grep -q "reSpeaker\|XVF3800\|card 2"; then
    ERRORS="${ERRORS}⚠️ XVF3800 audio device not detected (card 2)\n"
fi

# 6. HA token recent enough
TOKEN_FILE="/home/radxa/stackchan-esphome/xvf3800/ha_token.cache"
if [ -f "$TOKEN_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$TOKEN_FILE") ))
    if [ $AGE -gt 3600 ]; then
        ERRORS="${ERRORS}⚠️ HA token cache older than 1 hour (${AGE}s)\n"
    fi
else
    ERRORS="${ERRORS}⚠️ HA token cache file missing\n"
fi

if [ -n "$ERRORS" ]; then
    echo -e "Robi Health Check — $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "$ERRORS"
    exit 1
fi

# Silent = healthy
exit 0

#!/bin/bash
# rclone mount watchdog — check every 15 min, recover if unmounted
# Called by: cron job

if ! mountpoint -q /home/radxa/plex/media 2>/dev/null; then
  logger -t media-hub-watchdog "rclone mount DOWN — attempting recovery"
  systemctl restart rclone-zurg.service
  sleep 5
  if mountpoint -q /home/radxa/plex/media 2>/dev/null; then
    logger -t media-hub-watchdog "rclone mount recovered OK"
  else
    logger -t media-hub-watchdog "rclone mount recovery FAILED"
  fi
fi

# Also check zurg
if ! systemctl is-active --quiet zurg.service; then
  logger -t media-hub-watchdog "zurg DOWN — attempting restart"
  systemctl restart zurg.service
fi

# RD Browser — service-level
if ! systemctl is-active --quiet rd-browser.service; then
  logger -t media-hub-watchdog "rd-browser DOWN — attempting restart"
  systemctl restart rd-browser.service
  sleep 5
fi

# RD Browser — HTTP-level self-heal (check the service actually responds)
RDB_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8899/ 2>/dev/null || echo "000")
if [ "$RDB_HTTP" = "000" ]; then
  logger -t media-hub-watchdog "rd-browser HTTP DEAD (no response on :8899) — restarting"
  systemctl restart rd-browser.service
elif [ "$RDB_HTTP" != "200" ] && [ "$RDB_HTTP" != "302" ]; then
  logger -t media-hub-watchdog "rd-browser HTTP anomaly (code $RDB_HTTP, expected 200) — restarting"
  systemctl restart rd-browser.service
fi

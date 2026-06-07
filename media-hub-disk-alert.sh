#!/bin/bash
# Daily disk usage alert - silent if under 85%
set -euo pipefail

DISK_PCT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')

if [ "$DISK_PCT" -gt 90 ]; then
  echo "!! Disk CRITICAL: ${DISK_PCT}% used (${DISK_USED} / ${DISK_FREE} free)"
  exit 1
elif [ "$DISK_PCT" -gt 85 ]; then
  echo "!! Disk warning: ${DISK_PCT}% used (${DISK_USED} / ${DISK_FREE} free)"
  exit 1
else
  exit 0
fi

#!/usr/bin/env bash
# Media Hub Daily Health — deep check + auto-repair
# Runs silently when healthy, alerts when issues found
# Called by: cron job every morning

set -euo pipefail

HEALTH=$(/home/radxa/.hermes/profiles/home/scripts/media-hub-health.sh)

STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status'])")

if [ "$STATUS" = "ok" ]; then
  # Silent — no news is good news
  exit 0
fi

# Degraded — report which services
echo "$HEALTH" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('⚠️ Media Hub 健康異常')
print('━━━━━━━━━━')
print(f'Status: {d[\"status\"]}')
print(f'Errors: {d[\"errors\"]}')
for svc, state in d['services'].items():
    icon = '✅' if state in ('running','mounted') else '❌'
    print(f'{icon} {svc}: {state}')
for svc, state in d['docker'].items():
    icon = '✅' if state == 'running' else '❌'
    print(f'{icon} docker/{svc}: {state}')
"

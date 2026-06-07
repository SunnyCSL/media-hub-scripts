#!/bin/bash
# Telegram Notify - send stdin as message to home channel
# Usage: echo "msg" | telegram-notify.sh
set -euo pipefail

# Source credentials. The .env is KEY=VALUE format, valid bash syntax
ENV_FILE="/home/radxa/.hermes/profiles/home/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE" 2>/dev/null || true
  set +a
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  ENV_FILE2="/home/radxa/.hermes/.env"
  if [ -f "$ENV_FILE2" ]; then
    set -a
    source "$ENV_FILE2" 2>/dev/null || true
    set +a
  fi
fi

CHAT_ID="${TELEGRAM_HOME_CHANNEL:-${TELEGRAM_ALLOWED_USERS:-565235243}}"

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  logger -t tg-notify "CRITICAL: TELEGRAM_BOT_TOKEN not found"
  exit 1
fi

# Read message from stdin
MSG=$(cat)
if [ -z "$MSG" ]; then
  exit 0
fi

# Send via Telegram Bot API
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=${MSG}" \
  -d "parse_mode=HTML" \
  -o /dev/null -w "%{http_code}" 2>/dev/null || echo "FAIL"

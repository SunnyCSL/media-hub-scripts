#!/usr/bin/env bash
# Git auto-save watchdog: commit + push any uncommitted changes
# Runs silently when nothing to do

set -uo pipefail

# Repos to monitor
REPOS=(
  "/home/radxa/stackchan-esphome"
  "/home/radxa/.hermes/vault"
  "/home/radxa/.hermes/profiles/home/scripts"
)

# Suppress all git progress output (no progress meter → no SIGPIPE)
export GIT_TERMINAL_PROMPT=0
export GIT_PROGRESS_DELAY=100000

PUSH_LOG=/tmp/git-auto-save-push.log

for REPO in "${REPOS[@]}"; do
  cd "$REPO" || continue

  # Skip if no changes
  if git diff --quiet HEAD 2>/dev/null \
     && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    continue
  fi

  # Generate descriptive commit message
  CHANGED=$(git status --short 2>/dev/null | head -20 | tr '\n' '; ' | sed 's/; $//' || echo "")
  NUM_FILES=$(git status --short 2>/dev/null | wc -l || echo "0")

  git add -A >>"$PUSH_LOG" 2>&1 || true
  git commit -m "auto-save $(date '+%Y-%m-%d %H:%M'): ${NUM_FILES} file(s) changed

${CHANGED}" >>"$PUSH_LOG" 2>&1 || true

  # Push if remote exists
  if git remote -v 2>/dev/null | grep -q push; then
    git push --quiet origin master >>"$PUSH_LOG" 2>&1 || \
      echo "[$(date '+%H:%M')] Push failed (network or auth): $REPO" >>"$PUSH_LOG"
  fi
done

# Truncate log to last 50 lines
if [ -f "$PUSH_LOG" ]; then
  tail -n 50 "$PUSH_LOG" > "$PUSH_LOG.tmp" && mv "$PUSH_LOG.tmp" "$PUSH_LOG"
fi

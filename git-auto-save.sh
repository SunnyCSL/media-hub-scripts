#!/usr/bin/env bash
# Git auto-save watchdog: commit + push any uncommitted changes
# Runs silently when nothing to do

set -euo pipefail

# Repos to monitor
REPOS=(
  "/home/radxa/stackchan-esphome"
  "/home/radxa/.hermes/vault"
)

for REPO in "${REPOS[@]}"; do
  cd "$REPO"
  
  # Skip if no changes
  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    continue
  fi
  
  # Generate descriptive commit message
  CHANGED=$(git status --short | head -20 | tr '\n' '; ' | sed 's/; $//')
  NUM_FILES=$(git status --short | wc -l)
  
  git add -A
  git commit -m "auto-save $(date '+%Y-%m-%d %H:%M'): ${NUM_FILES} file(s) changed

${CHANGED}"
  
  # Push if remote exists
  if git remote -v | grep -q push; then
    git push origin master 2>&1 || echo "Push failed (no remote or network)"
  fi
done

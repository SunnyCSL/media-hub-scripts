#!/usr/bin/env bash
set -uo pipefail

SKILL_DIR="/home/radxa/.hermes/profiles/home/skills/neural-memory-graph"
VAULT="/home/radxa/.hermes/vault"
OUT="$VAULT/.neural-graph/edges.json"
LOG="/tmp/neural-graph-update.log"

# Load API keys from profile .env
source /home/radxa/.hermes/profiles/home/.env 2>/dev/null || true

# Step 1: wikilink extraction (~10s)
python3 "$SKILL_DIR/scripts/edge_extractor.py" \
    --vault "$VAULT" --out "$OUT" --mode wikilink >>"$LOG" 2>&1
echo "[Wikilink done]" >>"$LOG"

# Step 2: LLM inference (3 batches max, 90s timeout to stay under cron limit)
if [ -n "$MINIMAX_API_KEY" ] && [ ${#MINIMAX_API_KEY} -gt 10 ]; then
    echo "[LLM start: 3 batches, 90s cap]" >>"$LOG"
    timeout 90s env MINIMAX_API_KEY="$MINIMAX_API_KEY" python3 \
        "$SKILL_DIR/scripts/llm_infer_edges.py" \
        --vault "$VAULT" --edges "$OUT" --batch 3 --limit 3 >>"$LOG" 2>&1
    echo "[LLM done: exit=$?]" >>"$LOG"
else
    echo "[No MINIMAX_API_KEY - skip LLM]" >>"$LOG"
fi

#!/usr/bin/env bash
# Neural Graph auto-update: extract wikilink edges + LLM infer typed edges
set -euo pipefail

SKILL_DIR="/home/radxa/.hermes/profiles/home/skills/neural-memory-graph"
VAULT="/home/radxa/.hermes/vault"
OUT="$VAULT/.neural-graph/edges.json"

cd "$SKILL_DIR"

# Step 1: Extract wikilink edges
python3 scripts/edge_extractor.py --vault "$VAULT" --out "$OUT" --mode wikilink 2>&1
echo "Wikilink extraction done"

# Step 2: LLM infer typed edges (silent if no API key)
API_KEY=$(python3 -c "
import os
for env_path in [
    os.path.expanduser('~/.hermes/profiles/home/.env'),
    os.path.expanduser('~/.hermes/.env'),
]:
    if os.path.exists(env_path):
        for line in open(env_path):
            line = line.strip()
            if line.startswith('MINIMAX_API_KEY='):
                print(line.split('=', 1)[1].strip().strip(\"'\\\"\"))
                break
" 2>/dev/null)

if [ -n "$API_KEY" ]; then
    MINIMAX_API_KEY="$API_KEY" python3 scripts/llm_infer_edges.py \
        --vault "$VAULT" \
        --edges "$OUT" \
        --batch 3 \
        2>&1
    echo "LLM inference done"
else
    echo "No MiniMax API key - LLM inference skipped"
fi

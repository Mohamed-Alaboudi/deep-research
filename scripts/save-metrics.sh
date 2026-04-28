#!/bin/bash
# Extracts METRICS JSON from the Stop hook payload and appends to metrics.jsonl.
# Called by the Stop hook after every response. Only acts if <!-- METRICS:{...} --> is present.
# Fast path: bash pattern match before any python invocation.

METRICS_FILE="$HOME/.claude/deep-research/metrics.jsonl"

# Read stdin once
input=$(cat)

# Fast prefilter: skip python entirely if no METRICS marker present.
# Saves ~50-100ms python startup on every unrelated Stop event.
case "$input" in
    *'<!-- METRICS:'*) ;;
    *) exit 0 ;;
esac

if ! command -v python3 &>/dev/null; then
    exit 0
fi

# Parse JSON properly, extract metrics. Skip empty objects ({}) — those add noise without information.
metrics=$(printf '%s' "$input" | python3 -c "
import sys, json, re
try:
    data = json.load(sys.stdin)
    msg = data.get('last_assistant_message', '')
    match = re.search(r'<!-- METRICS:(\{.*?\}) -->', msg, re.DOTALL)
    if match:
        parsed = json.loads(match.group(1))
        if isinstance(parsed, dict) and parsed:
            print(json.dumps(parsed, ensure_ascii=False))
except Exception:
    pass
" 2>/dev/null)

if [ -z "$metrics" ] || [ "$metrics" = "{}" ]; then
    exit 0
fi

mkdir -p "$(dirname "$METRICS_FILE")"
echo "$metrics" >> "$METRICS_FILE"

#!/bin/bash
# Extracts METRICS JSON from the Stop hook payload, normalizes it to the v4 schema,
# and appends to metrics.jsonl. Called by the Stop hook after every response.
# Only acts if <!-- METRICS:{...} --> is present.
# Fast path: bash pattern match before any python invocation.

METRICS_FILE="$HOME/.claude/deep-research/metrics.jsonl"

# Read stdin once
input=$(cat)

# Fast prefilter: skip python entirely if no METRICS marker present.
case "$input" in
    *'<!-- METRICS:'*) ;;
    *) exit 0 ;;
esac

if ! command -v python3 &>/dev/null; then
    exit 0
fi

# Parse, then normalize: every v4 key present (missing -> null), extras preserved,
# recorded_at + schema_version stamped. This keeps metrics.jsonl aggregatable even
# when the orchestrator drifts from the documented schema.
metrics=$(printf '%s' "$input" | python3 -c "
import sys, json, re
from datetime import datetime, timezone

REQUIRED = [
    'schema_version', 'run_id', 'topic', 'mode', 'tier', 'fast',
    'subquestions', 'scrapers', 'scraper_errors', 'follow_up_rounds',
    'verifier_agents', 'claims_verified', 'claims_confirmed',
    'claims_contradicted', 'claims_thrown_out', 'verify_skipped_reason',
    'links_checked', 'links_dead', 'renders_done', 'sources_total',
    'corridor_violations', 'hard_cap_hit', 'approval_gate_action',
]

try:
    data = json.load(sys.stdin)
    msg = data.get('last_assistant_message', '')
    match = re.search(r'<!-- METRICS:(\{.*?\}) -->', msg, re.DOTALL)
    if match:
        parsed = json.loads(match.group(1))
        if isinstance(parsed, dict) and parsed:
            out = {k: parsed.get(k) for k in REQUIRED}
            if out['schema_version'] is None:
                out['schema_version'] = 4
            # keep any extra keys the orchestrator emitted (drift is visible, not lost)
            for k, v in parsed.items():
                if k not in out:
                    out[k] = v
            out['recorded_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            print(json.dumps(out, ensure_ascii=False))
except Exception:
    pass
" 2>/dev/null)

if [ -z "$metrics" ] || [ "$metrics" = "{}" ]; then
    exit 0
fi

mkdir -p "$(dirname "$METRICS_FILE")"
echo "$metrics" >> "$METRICS_FILE"

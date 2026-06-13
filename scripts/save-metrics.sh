#!/bin/bash
# Extracts METRICS JSON from the Stop hook payload, normalizes it to the v4 schema,
# and appends to metrics.jsonl. Called by the Stop hook after every response.
# Only acts if <!-- METRICS:{...} --> is present.
# Fast path: bash pattern match before any python invocation.
# Failures are never silent: every dropped METRICS payload is logged to metrics-errors.log.

METRICS_FILE="$HOME/.claude/deep-research/metrics.jsonl"
ERRORS_FILE="$HOME/.claude/deep-research/metrics-errors.log"

log_error() {
    mkdir -p "$(dirname "$ERRORS_FILE")"
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$ERRORS_FILE"
}

# Read stdin once
input=$(cat)

# Fast prefilter: skip python entirely if no METRICS marker present.
case "$input" in
    *'<!-- METRICS:'*) ;;
    *) exit 0 ;;
esac

if ! command -v python3 &>/dev/null; then
    log_error "DROPPED: METRICS marker present but python3 not found"
    exit 0
fi

# Parse, then normalize: every v4 key present (missing -> null), extras preserved,
# recorded_at + schema_version stamped. This keeps metrics.jsonl aggregatable even
# when the orchestrator drifts from the documented schema.
# stderr (line 2 onward of any traceback) goes to the error log, not /dev/null.
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

def fail(reason, snippet=''):
    print('DROPPED: ' + reason + (' | ' + snippet[:200] if snippet else ''), file=sys.stderr)
    sys.exit(0)

try:
    data = json.load(sys.stdin)
except Exception as e:
    fail('stop-hook stdin is not valid JSON: %r' % e)

msg = data.get('last_assistant_message', '')
# Non-greedy first (flat schema), greedy fallback if the topic contains '} -->'.
match = re.search(r'<!-- METRICS:(\{.*?\}) -->', msg, re.DOTALL)
greedy = re.search(r'<!-- METRICS:(\{.*\}) -->', msg, re.DOTALL)
if not match:
    fail('METRICS marker present but regex did not match', msg[-300:])

parsed = None
for m in (match, greedy):
    if m is None:
        continue
    try:
        parsed = json.loads(m.group(1))
        break
    except Exception:
        continue
if parsed is None:
    fail('METRICS payload is not valid JSON', match.group(1))
if not isinstance(parsed, dict) or not parsed:
    fail('METRICS payload is not a non-empty object', match.group(1))

out = {k: parsed.get(k) for k in REQUIRED}
if out['schema_version'] is None:
    out['schema_version'] = 4
# keep any extra keys the orchestrator emitted (drift is visible, not lost)
for k, v in parsed.items():
    if k not in out:
        out[k] = v
out['recorded_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
print(json.dumps(out, ensure_ascii=False))
" 2>>"$ERRORS_FILE")

if [ -z "$metrics" ] || [ "$metrics" = "{}" ]; then
    # Python already logged the specific reason to ERRORS_FILE via stderr;
    # add a marker line if it somehow didn't.
    if [ -z "$metrics" ]; then
        tail -1 "$ERRORS_FILE" 2>/dev/null | grep -q DROPPED || log_error "DROPPED: empty output with METRICS marker present (unlogged cause)"
    fi
    exit 0
fi

mkdir -p "$(dirname "$METRICS_FILE")"
echo "$metrics" >> "$METRICS_FILE"

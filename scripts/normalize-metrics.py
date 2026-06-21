#!/usr/bin/env python3
"""
One-shot, idempotent normalizer for ~/.claude/deep-research/metrics.jsonl.

Why this exists: the METRICS schema evolved to v4, but lines written before v4
(and lines that used the older key names) are missing the verify triplet and use
`depth_corridor_violations` instead of `corridor_violations`. That makes the
ledger unaggregatable — you can't compute a confirm-rate or a corridor-violation
rate across runs when half the rows speak a different dialect. The Stop hook
(`save-metrics.sh`) only normalizes *forward* (new writes); it never rewrites the
historical file. This script backfills the history.

Design rules (each load-bearing):
  - IDEMPOTENT: running it twice produces the same file. Already-v4 lines pass
    through unchanged.
  - null, NOT 0, for absent fields. An absent `claims_thrown_out` on a pre-v4
    line means "this metric did not exist yet" (unknown), which is semantically
    different from "ran and threw out zero". Zero-filling would fabricate data
    and corrupt any rate computed over the column. Unknown stays null.
  - SAFE: back up to <file>.bak first, write to a temp file, swap on success.
    Never edit in place. A line that isn't valid JSON is preserved verbatim
    rather than dropped (we don't silently lose history).
  - Renames OLD key names to their v4 equivalents (see RENAMES) only when the v4
    key isn't already present, so a re-run can't clobber a real v4 value.

Usage:
    python3 normalize-metrics.py            # normalizes the default metrics.jsonl
    python3 normalize-metrics.py --dry-run  # report what would change, write nothing
    python3 normalize-metrics.py --file /path/to/metrics.jsonl
"""
import argparse
import json
import os
import shutil
import sys

DEFAULT_FILE = os.path.expanduser("~/.claude/deep-research/metrics.jsonl")

# The v4 schema key list — kept byte-identical to save-metrics.sh's REQUIRED list
# so forward-normalization (the Stop hook) and this backfill agree exactly.
REQUIRED = [
    "schema_version", "run_id", "topic", "mode", "tier", "fast",
    "subquestions", "scrapers", "scraper_errors", "follow_up_rounds",
    "verifier_agents", "claims_verified", "claims_confirmed",
    "claims_contradicted", "claims_thrown_out", "verify_skipped_reason",
    "links_checked", "links_dead", "renders_done", "sources_total",
    "corridor_violations", "hard_cap_hit", "approval_gate_action",
]

# Old key name -> v4 key name. Applied only when the v4 key is absent, so a real
# v4 value is never overwritten by a stale alias on a re-run.
RENAMES = {
    "depth_corridor_violations": "corridor_violations",
    "verified_claims": "claims_verified",
    "verifiers_dispatched": "verifier_agents",
    "scrapers_dispatched": "scrapers",
    "sources_count": "sources_total",
    "sub_questions": "subquestions",
}


def normalize_obj(obj):
    """Return (normalized_dict, changed_bool) for one parsed JSON object."""
    before = json.dumps(obj, sort_keys=True, ensure_ascii=False)

    # 1) migrate old key names forward (only if the v4 target isn't already set)
    for old, new in RENAMES.items():
        if old in obj:
            if new not in obj or obj[new] is None:
                obj[new] = obj[old]
            del obj[old]

    # 2) build the v4 object: every required key present, missing -> null (NOT 0)
    out = {k: obj.get(k, None) for k in REQUIRED}
    if out["schema_version"] is None:
        out["schema_version"] = 4

    # 3) preserve any extra keys the run emitted (drift stays visible, not lost),
    #    e.g. "reverify", "notes", "recorded_at", "timestamp"
    for k, v in obj.items():
        if k not in out:
            out[k] = v

    after = json.dumps(out, sort_keys=True, ensure_ascii=False)
    return out, (before != after)


def main():
    ap = argparse.ArgumentParser(description="Backfill metrics.jsonl to v4 schema (idempotent).")
    ap.add_argument("--file", default=DEFAULT_FILE, help="metrics.jsonl path")
    ap.add_argument("--dry-run", action="store_true", help="report changes, write nothing")
    args = ap.parse_args()

    path = os.path.expanduser(args.file)
    if not os.path.isfile(path):
        print(f"error: {path} not found", file=sys.stderr)
        return 1

    with open(path, "r", encoding="utf-8") as f:
        raw_lines = f.readlines()

    out_lines = []
    changed = 0
    bad = 0
    for line in raw_lines:
        s = line.strip()
        if not s:
            continue  # drop blank lines
        try:
            obj = json.loads(s)
        except json.JSONDecodeError:
            bad += 1
            out_lines.append(s)  # preserve un-parseable history verbatim
            continue
        norm, did = normalize_obj(obj)
        if did:
            changed += 1
        out_lines.append(json.dumps(norm, ensure_ascii=False))

    total = len(out_lines)
    print(f"{path}: {total} records, {changed} normalized, {bad} unparseable (preserved).")

    if args.dry_run:
        print("dry-run: no files written.")
        return 0

    if changed == 0 and bad == 0:
        print("already fully v4 — nothing to write (idempotent no-op).")
        return 0

    backup = path + ".bak"
    shutil.copy2(path, backup)  # safety net before any rewrite
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out_lines) + "\n")
    os.replace(tmp, path)  # atomic swap
    print(f"wrote {path} (backup at {backup}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

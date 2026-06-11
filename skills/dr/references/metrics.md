# METRICS field glossary (schema_version 4)

The METRICS comment is a single flat JSON object — exactly these keys, no nesting, no extras, no omissions. `scripts/save-metrics.sh` normalizes (fills missing keys with `null`, stamps `recorded_at`), but a drifted schema makes runs unaggregatable, so emit it correctly.

| Field | Type | Meaning |
|-------|------|---------|
| `schema_version` | int | Always `4` for this schema |
| `run_id` | string | Epoch-seconds of the per-run `/tmp/deep-research/<epoch>/` directory; matches a bad run back to its session transcript |
| `topic` | string | Original topic, flags stripped |
| `mode` | string | `web` \| `codebase` \| `knowledge` \| `mixed` |
| `tier` | string | `lite` \| `standard` \| `thorough` |
| `fast` | bool | `--fast` was active |
| `subquestions` | int | Sub-questions in the final plan |
| `scrapers` | int | Scraper agents actually spawned (including follow-ups) |
| `scraper_errors` | int | Scrapers that returned `ERROR\|...`, crashed, or left no usable file |
| `follow_up_rounds` | int | Step-3 follow-up rounds dispatched (0 if no trigger fired) |
| `verifier_agents` | int | `dr-verifier` agents spawned across all rounds |
| `claims_verified` | int | Central claims sent into Round 1 |
| `claims_confirmed` | int | Claims whose final verdict was `confirmed` |
| `claims_contradicted` | int | Claims that received a `contradicted` verdict in any round |
| `claims_thrown_out` | int | Claims removed after an unresolved contradiction |
| `verify_skipped_reason` | string\|null | `null` when verification ran; else `"fast-flag"`, `"no-verify-flag"`, `"user-request"`, `"no-central-claims"`, `"codebase-mode"` |
| `links_checked` | int | Sources URLs covered by the curl sweep |
| `links_dead` | int | URLs classified dead after the GET retry |
| `renders_done` | int | Playwright spot-renders performed (0-5) |
| `sources_total` | int | Numbered entries in the Sources section |
| `corridor_violations` | int | Sub-questions outside the active tier's corridor (SKILL.md Step 1 table) |
| `hard_cap_hit` | bool | Run was trimmed to fit the tier's hard subagent cap |
| `approval_gate_action` | string | `"skipped"` \| `"approved"` \| `"adjusted"` \| `"cancelled"` (cancelled runs emit no METRICS; the value exists for schema completeness) |

Template (copy, fill values):

```
<!-- METRICS:{"schema_version":4,"run_id":"<epoch>","topic":"...","mode":"web","tier":"lite","fast":false,"subquestions":N,"scrapers":N,"scraper_errors":N,"follow_up_rounds":N,"verifier_agents":N,"claims_verified":N,"claims_confirmed":N,"claims_contradicted":N,"claims_thrown_out":N,"verify_skipped_reason":null,"links_checked":N,"links_dead":N,"renders_done":N,"sources_total":N,"corridor_violations":N,"hard_cap_hit":false,"approval_gate_action":"approved"} -->
```

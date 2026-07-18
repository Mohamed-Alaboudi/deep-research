---
name: dr
description: "Run the user's decision-grade deep-research workflow: plan and approve a bounded scraper fan-out, verify central claims adversarially, link-check sources, and synthesize a cited report. Use when explicitly invoked as $dr or when the user explicitly asks for deep research; not for quick lookups."
---

# Codex Deep Research Orchestrator

You are the research head. You plan, dispatch, inspect evidence, select central claims, integrate verdicts, and synthesize. Subagents collect or verify evidence; they do not make the final decision.

Use a moderate-capability head for planning, ledgering, link checks, and ordinary synthesis. Do not upgrade the head merely because the tier is `thorough`; reserve stronger reasoning for reconciling material verifier conflicts or genuinely difficult cross-domain conclusions.

Read these references before dispatching:

- `references/scraper-web.md` for every web scraper packet.
- `references/scraper-codebase.md` for every codebase scraper packet.
- `references/verifier.md` for every verifier packet.

## Non-negotiable rules

1. Never convert memory into a sourced fact. Every external fact needs a fetched URL; every codebase fact needs `path:line` evidence.
2. Never give scrapers the preferred thesis. Pass a neutral question, constraints, depth, and output path.
3. Never do scraper or verifier work in the head agent. If the required subagent cannot be spawned, abort and report the spawn failure; do not replace the evidence layer with direct browsing or inline code search.
4. Track URLs and quotes from scraper output through verification and the saved report.
5. The approval gate is mandatory unless the input contains the literal `--yes` or `--no-confirm`, or the entire plan uses exactly one scraper.
6. Verification is mandatory unless `--fast`, `--no-verify`, codebase-only mode, or zero externally sourced central claims applies.
7. Use the smallest useful fan-out and never create recursive subagent trees.

## Flags

- `--mode web|codebase|knowledge|mixed`
- `--tier lite|standard|thorough` (default `lite`)
- `--fast` skips verification and uses link checks only
- `--no-verify` skips only adversarial verification
- `--yes` or `--no-confirm` skips plan approval
- `--reverify <run_id>` verifies an existing saved corpus and patches its matching report without re-scraping

Strip flags before treating the remainder as the topic. If no topic remains, ask for one.

Tier limits:

| Tier | Scraper target | Central-claim cap | Hard child cap |
|---|---:|---:|---:|
| lite | 2–6 | 5 | 25 |
| standard | 4–12 | 10 | 35 |
| thorough | 6–15 | 25 | 55 |

## 0. Align

Infer scope, purpose, constraints, depth, and decision frame from the conversation. Ask only questions whose answers would change the plan and cannot be inferred. If two or more dimensions remain unclear, ask them in one concise batch. “Just start” means use sensible defaults.

Select exactly one mode:

- `web`: current external evidence.
- `codebase`: local repository evidence.
- `knowledge`: use prior knowledge only to propose claims, then dispatch two web scrapers to source-check the top three.
- `mixed`: both web and local code determine the answer.

## 1. Plan and approve

Break the topic into two to four independent subquestions, each with neutral angles and a depth:

- shallow: one scraper
- standard: two scrapers
- deep: three to five scrapers (`lite`: two to three)

Prefer roughly 12 total scrapers and cap at 15. Estimate verifier count as `ceil(claim_cap / 10)`; thorough starts with three verifier batches. Trim peripheral angles before exceeding the tier's hard child cap.

Present topic, mode, tier, numbered subquestions, depth, angles, scraper count, estimated verifier count, and total budget. Unless an approval exception applies, stop and ask: “Plan OK? N scrapers will launch in parallel.” Accept go, adjust, or cancel. Re-present changes before dispatch.

## 2. Create the run

Create `/tmp/deep-research/<epoch>/`; the epoch is `run_id`. Output names are `sq<N>-web-<M>.md`, `sq<N>-codebase-<M>.md`, and `verify-r<R>-b<B>.md`.

Spawn all independent scraper packets in parallel when slots allow. Each packet must include the exact applicable reference path, original question, one neutral angle, depth, constraints, and its one allowed output file.

Use the cheapest capable routing available:

- every first-pass shallow, standard, or deep web collector, plus bounded codebase location: `gpt-5.6-terra` with low reasoning and a fresh/minimal context;
- only a targeted retry after the low-cost pass fails the corpus audit, including unresolved multi-file call-path tracing: `gpt-5.6-terra` with medium reasoning;
- never use Sol for collection.

When explicit model/effort selection is unavailable, use the lowest-cost collector role exposed by the surface, keep the packet bounded, and record the routing limitation. Upgrade an individual collector only after its low-cost pass fails the corpus audit.

## 3. Audit the corpus

Read every expected output. A subquestion requires a follow-up when any condition holds:

- missing or empty file;
- fewer than three distinct external sources;
- only weak blog/forum sources where primary sources should exist;
- “from memory,” “training data,” or similar non-fetch evidence;
- external facts lack deep URLs or quotes/version/date evidence;
- codebase facts lack paths and lines.

Use at most two follow-up rounds per subquestion. Rephrase toward the missing evidence. After that, preserve the gap explicitly. Mirror non-verifier scraper files to `~/.codex/deep-research/raw/<run_id>/` so `--reverify` survives a restart.

## 4. Extract central claims

Create a compact ledger with one row per claim:

`claim | supporting quote | source URL/path | source type | central/peripheral`

Deduplicate equivalent claims. Only external, central, URL-backed claims enter adversarial verification, up to the tier cap. Codebase claims are checked against paths during synthesis.

## 5. Verify

Unless a valid skip applies, batch up to ten claims per verifier. Each packet includes `references/verifier.md`, the original question, numbered claims, quotes, source URLs/types, and one output file. Use a fresh `gpt-5.6-terra` high-reasoning verifier for lite and standard. Use `gpt-5.6-sol` high only for thorough, high-stakes decisions, or escalation of a materially contradicted claim; never use maximum/ultra reasoning for routine verification.

Round 1 checks every selected central claim. Thorough uses exactly three evenly split Round-1 batches. Escalate only contradicted claims or material disagreements to a fresh single-claim Sol verifier, at most two escalation rounds. Aggregate:

- confirmed/high → state confidently;
- confirmed/medium or uncertain → qualify and lower confidence;
- contradicted with concrete counter-evidence → remove or explicitly frame the dispute;
- unresolved verifier disagreement → omit from the bottom line and list under uncertainty.

If verification is interrupted after scraping, save a report marked `VERIFICATION-INCOMPLETE` with the `run_id`; never present it as verified.

## 6. Link gate

Deduplicate cited HTTP(S) URLs and check them with bounded concurrent `curl -L -I --max-time 12` requests, falling back to `curl -L --range 0-2047` for HEAD-hostile sites. Replace broken sources when evidence already provides an alternative; otherwise mark inaccessible. On standard/thorough, visually spot-check up to three decision-critical pages when a browser is available. Never claim a render was checked unless it was observed.

## 7. Synthesize

Lead with the decision-grade answer, then:

1. Bottom line
2. What matters / tradeoffs
3. Recommended actions
4. Supporting detail
5. Uncertainty, contradictions, and evidence gaps

Attach direct Markdown links next to factual claims in chat. Clearly label inference. Do not expose raw subagent logs.

Offer to save a durable cited report. If accepted, write `~/.codex/deep-research/YYYY-MM-DD-<topic-slug>.md` with YAML frontmatter containing `run_id`, topic, date, mode, tier, status, scraper count, and verified-claim count. Include citations, Verification notes, and a deduplicated Sources list. Every factual statement in the saved report must have a citation or `[interpretation]` label.

## Reverify

For `--reverify <run_id>`, locate raw files first in `~/.codex/deep-research/raw/<run_id>/`, then `/tmp/deep-research/<run_id>/`. Find the unique report whose frontmatter has the same `run_id`; if ambiguous, ask. Repeat Steps 4–6 only, patch that report in place, and report confirmed/uncertain/removed counts.

## Finish

Report mode, tier, run ID, scraper success count, verification status, checked-link count, report path if saved, and any model-routing limitation. Never call the run verified without observed verifier output.

---
name: dr
description: |
  Deep research orchestrator: fan-out scrapers, batched adversarial verification, link-checked cited report.
  Use when the user explicitly asks for deep research ("/dr", "deep research", "decision-grade report",
  "verified/cited research") or invokes the /dr command. NOT for quick lookups, single facts, or casual
  "compare X and Y" questions — a direct search answers those faster and cheaper.
---

# Deep Research Orchestrator

You coordinate research by spawning sub-agents and synthesizing their findings. You never search or fetch directly.

## Three rules

1. End your final response with `<!-- METRICS:{...} -->` so the stop hook can record the run.
2. Spawn **scrapers** with `model: "sonnet"` and an explicit depth level, because without these they inherit your model (expensive) and default to shallow searches (poor results). **Verifiers are the exception — spawn `dr-verifier` with `model: "opus"`** (its verdicts are the load-bearing judgment step; never pass `"sonnet"` to a verifier). The model is set at spawn time, so the per-agent `model:` here overrides the agent frontmatter — get it right at every spawn site.
3. Track every source URL from scraper outputs through the pipeline — verification and the link gate run on them, and the **saved** report's Sources section needs them. The **chat report is clean prose** (no `[^N]`, no Sources list — see `references/output-format.md`); citations are restored only in the saved `.md` file.

## Forbidden: direct-fetch and substitute-agent fallbacks

If spawning a `deep-research:dr-scraper-web`, `deep-research:dr-scraper-codebase`, or `deep-research:dr-verifier` subagent fails for ANY reason — permission denied, subagent type not found, plugin error, prior failed attempt in this session — you MUST NOT:

1. Silently fall back to direct `WebSearch` / `WebFetch` / `Grep` / `Read` to do the research yourself.
2. Substitute another agent type (e.g. `general-purpose`) that has WebSearch/WebFetch directly. This bypasses the same source-evidence layer as direct fetching — it's the same violation with extra steps.

The whole point of this skill is the multi-agent indirection through agents that enforce fact-from-source rules. Direct-fetch and substitute-agents both produce fabrication-prone synthesis without those rules.

Phrases that signal you are about to break this rule and which you must NOT emit:
- "Skill couldn't spawn the sub-scraper, I'll just do it directly with ..."
- "Spawning failed, falling back to direct WebFetch"
- "Let me just search the web directly instead"
- "As feared ..." followed by direct tool calls
- "Switching to general-purpose agents with direct WebSearch/WebFetch access"

There is no fallback mode. Either scrapers work, or the skill aborts cleanly. For the abort + permissions-recovery flow, see `references/error-handling.md`.

## Workflow

### Step 0: Context check

Before planning, assess whether the topic has enough context for useful research. Skip this step if the user passed `--mode` together with a detailed topic (>50 words with clear constraints), or if the topic is a precise, self-contained question (named entity + specific aspect).

Evaluate five dimensions: **Scope** (one tool vs. whole landscape), **Purpose** (decision, learning, comparison, implementation), **Constraints** (stack, versions, region, timeframe, budget), **Depth** (overview vs. deep-dive), **Decision frame** (compare, pick, validate, survey).

Trigger clarification when **two or more** dimensions are unclear, **or** the topic is under 10 words without surrounding conversation context. Ask at most **3 targeted questions** via `AskUserQuestion` (one tool call), each with 2-4 concrete options. Only ask questions that would materially change sub-questions, depth, or mode.

Distill answers into a `CONSTRAINTS:` block (1-2 lines max). **Keep the original topic unchanged.** The CONSTRAINTS block flows into every scraper dispatch. If the user says "just start", skip clarification, use sensible defaults, and do not re-ask.

### Step 0.5: Flags and tier

Parse these optional flags from the topic string (strip them before treating the rest as the topic):

| Flag | Effect |
|------|--------|
| `--mode web\|codebase\|knowledge\|mixed` | Force research mode |
| `--tier lite\|standard\|thorough` | Cost/verify tier (default resolution below) |
| `--fast` | Speed mode: skip verification, curl-only link gate (no renders), wide-and-shallow corridor allowed. Record `verify_skipped_reason: "fast-flag"` |
| `--no-verify` | Skip the verify stage only. Record `verify_skipped_reason: "no-verify-flag"` |
| `--verify3` | **Deprecated.** Ignored with a one-line note: "verify3 is deprecated — the batched escalation ladder replaced fixed voters." |
| `--yes` / `--no-confirm` | Skip the approval gate |
| `--reverify <run_id>` | **Finish verification of an already-completed run** without re-scraping. Routes to Step 0.7 and exits there — skips planning, scraping, and synthesis. Use to upgrade a report shipped `VERIFICATION-INCOMPLETE` (interrupted run) to verified. |

Tier default: `--tier` if given; else `lite`. (Optional override: if `~/.claude/deep-research/config.json` exists, a `default_tier` key in it wins over `lite` — but do NOT `cat` a file you have no reason to believe exists; only read it if a prior step in this session already surfaced it. Never fabricate its contents.)

| Tier | Verify claim cap | Verify shape | Hard subagent cap |
|------|------------------|--------------|-------------------|
| lite | 5 | 1 batch agent, +1 escalation agent only if contradictions | 25 |
| standard | 10 | full ladder (see Step 5) | 35 |
| thorough | 12 | full ladder | 55 |

**Round-1 verification is a hard gate — not skippable by judgment.** The ONLY ways to skip Round 1 entirely are the explicit flags `--fast` or `--no-verify`, or the structural cases zero-central-claims / codebase mode. Everything else — including the user saying "be quick" or "skip the deep checking" mid-run — still runs Round 1 (one Opus `dr-verifier`, 1 subagent even at lite). A spoken "go faster" request demotes only the **escalation rounds** (Round 2/3): record `verify_skipped_reason: null` (Round 1 still ran) and simply don't escalate. "The run is taking long" or "the user seems to want speed" is NEVER a reason to drop Round 1 — at lite tier it costs exactly one extra subagent. If the user truly wants zero verification, that is the `--fast` / `--no-verify` flag, which is explicit and machine-checkable; do not infer a full skip from conversational hints.

### Step 0.7: Re-verify branch (`--reverify <run_id>` only)

If the topic string contains `--reverify <run_id>`, run **this step only**, then go straight to the report patch below and stop. Do NOT plan, scrape, or re-synthesize — the scrapers already ran; you are finishing the verification that an interrupted run skipped. This is the surgical "upgrade a `VERIFICATION-INCOMPLETE` report to verified" path.

1. **Locate the run dir.** Try in order: `~/.claude/deep-research/raw/<run_id>/` (durable saved copy), then `/tmp/deep-research/<run_id>/` (fresh, pre-reboot). If neither exists or it holds no `sq*.md` scraper files, abort with: "No saved scraper files for run `<run_id>` — `~/.claude/deep-research/raw/<run_id>/` and `/tmp/deep-research/<run_id>/` are both empty. A re-verify needs the original fetches; re-run `/dr` from scratch instead." (Tip the user that `--reverify` works whenever either the durable raw mirror — `~/.claude/deep-research/raw/<run_id>/`, written at the end of Step 3, survives reboot — or the `/tmp` copy still holds the run's fetches. A run interrupted *before* reaching the Step 3 mirror only has the `/tmp` copy, which a reboot clears.)

2. **Locate the report.** Find the matching file under `~/.claude/deep-research/`. Prefer an exact `run_id:` frontmatter match (reports written after this version carry it — see Step 7). Otherwise match on topic/date and, if more than one plausibly matches, list the candidates and ask the user which file to upgrade via `AskUserQuestion`. Never patch a report you are not sure maps to this run.

3. **Re-extract central claims** from the run dir exactly as in **Step 4** (claim · quote · source_url · source_type · centrality). Only `central` claims with a URL source are eligible. Use the report's own existing tier (read its frontmatter / Verification notes) for the claim cap; default to `standard` (10) if unrecorded.

4. **Run the verify ladder** exactly as in **Step 5** (batched, Opus `dr-verifier`, escalation rounds, same `references/verification.md` spawn pattern and aggregation). Verifier output files go in the run dir as usual: `<run-dir>/verify-r{round}-b{batch}.md`. The **same no-fallback rule applies** — if `dr-verifier` cannot spawn, abort cleanly; never verify the claims yourself.

5. **Patch the report in place** (do not write a new dated file; never overwrite a *different* report):
   - Flip the frontmatter `status:` from `VERIFICATION-INCOMPLETE …` to `verified — re-verified <YYYY-MM-DD> via --reverify` and add/update a `verified_claims: N` key.
   - Remove the ⚠️ "Verification status / VERIFICATION-INCOMPLETE" banner block (or replace it with a one-line "✅ Verified: N central claims checked by an Opus adversarial verifier on <date>.").
   - Attach verdict-derived **confidence** to each central claim (Step 5 mapping), and fill the saved report's **Verification** section per `references/output-format.md` (Removed / Uncertain / Not verified) — `--reverify` edits the saved `.md`, which keeps the cited Verification + Sources sections. Drop any claim the ladder threw out as an unresolved contradiction, moving it into Verification with its counter-source.
   - Append a fresh METRICS comment for the verify-only run: same flat schema, `scrapers: 0`, `verify_skipped_reason: null`, `run_id` = the re-verified run, plus the real verify counts. Add `"reverify": true`.

6. **Report what changed** in chat: claims checked, how many confirmed / uncertain / removed, and that the durable report file was upgraded in place. Then stop — Steps 1–8 do not run on a `--reverify`.

### Step 1: Plan

Detect mode. **Mode must be exactly one of `web`, `codebase`, `knowledge`, or `mixed`** — never invent new modes:

- Web: external information needed
- Codebase: topic relates to a project in the working directory
- Knowledge: foundation comes from training data, but **MUST be fact-checked** — its claims go through Step 5 like any other mode. No claim ships without a source.
- Mixed: requires both web and codebase

Break the topic into sub-questions and assign each a depth level. The corridor depends on tier:

| Tier | Sub-questions | shallow | standard | deep (hard floor) |
|------|---------------|---------|----------|-------------------|
| standard / thorough | 2-4 | 1-2 scrapers | 2-4 | 3-5 (≥3) |
| lite / `--fast` | 2-8 (wide-and-shallow allowed) | 1 | 1-2 | 2-3 (≥2) |

Deep floors are hard; ceilings are soft. **Total budget: ~12 parallel scrapers is the sweet spot, ~15 the practical ceiling.** Beyond ~10 parallel subagents each additional one delivers diminishing coverage while linearly increasing cost and timeout risk. If over the ceiling: lower a peripheral depth, merge sub-questions, or use corridor lower bounds.

Present the plan with a dispatch-budget breakdown and a one-line rationale per sub-question, so the user can spot a wrong framing before any token is spent:

```
Research plan: "[Topic]"
Mode: [web / codebase / knowledge / mixed] · Tier: [lite / standard / thorough]

1. [Sub-question] (deep) — N scrapers
   Why deep: [core decision driver / competing answers / ...]
   Angles: [angle 1] · [angle 2] · [angle 3]
2. [Sub-question] (standard) — N scrapers
   Why standard: [...]
   Angles: [angle 1] · [angle 2]

Dispatch budget: N scrapers + ~M verifiers (sweet spot ~12 scrapers, ceiling ~15)
```

For `mode: knowledge`, plan exactly one synthetic sub-question: verification of the top-3 claims you intend to make, with 2 web scrapers.

**Hard subagent cap check.** Planned total = scrapers + `ceil(verify_claim_cap / 10) + 2`. If it exceeds the tier cap, trim verify claims first (drop lowest centrality), then scrapers. Record `hard_cap_hit: true` if trimmed.

### Step 1.5: Approval gate

Ask once whether the plan is OK — each scraper consumes session quota. Skip the gate **only** if (strictly, no fuzzy matching): the topic string contains the literal token `--yes` or `--no-confirm`, OR the total dispatch budget is exactly 1 scraper. If unsure whether the user already confirmed, ask anyway.

Via `AskUserQuestion`:

> Question: "Plan OK? N scrapers will launch in parallel."
> Options: "Yes, go" | "Adjust" | "Cancel"

If "Adjust": apply any change spelled out in their notes; if no detail given, ask ONE targeted follow-up ("What should change? Sub-question, depth, scraper count, mode, or angles?") — do not re-present an unchanged plan. Then update, re-present, re-ask. Up to 5 rounds; after that suggest re-invoking with a clearer topic. If "Cancel": stop cleanly, no METRICS comment.

### Step 2: Dispatch scrapers

Create a per-run directory: `mkdir -p /tmp/deep-research/$(date +%s)`. The epoch value is the run's `run_id` (record it in METRICS — it lets a later triage match a problematic run back to its session transcript). File naming: `<run-dir>/sq{N}-{web|codebase}-{M}.md`.

Each scraper handles ONE narrow angle. Phrase angles distinctly so scrapers don't duplicate work.

**Withhold your thesis (anti-confirmation-bias).** A scraper that is told which answer you expect will preferentially find evidence for it. Pass each scraper a *neutral* angle — the thing to find out — and deliberately NOT: the answer you're leaning toward, the decision you're trying to justify, the hypothesis you're testing, or framing that telegraphs a desired conclusion. Write the QUESTION as an open information-gathering task ("What are the documented X for Y?"), never as a leading one ("Confirm that X is the best Y"). CONSTRAINTS may carry scope (stack, region, timeframe) but must not smuggle in the preferred outcome. This is the single highest-leverage guard against fabrication-by-agreement.

Launch all scrapers across all sub-questions in parallel:

<example>
Agent(
  subagent_type: "deep-research:dr-scraper-web",
  model: "sonnet",
  prompt: "Collect facts for the question below. Follow your agent instructions for output format and return value.

QUESTION: What pricing tiers does Stripe offer for SaaS billing in 2026?
DEPTH: standard
CONSTRAINTS: Mid-market SaaS, US/EU only, last 24 months
OUTPUT_FILE: /tmp/deep-research/1746619200/sq1-web-1.md"
)
</example>

For codebase scrapers: `subagent_type: "deep-research:dr-scraper-codebase"`. Do not duplicate agent-body instructions in the spawn prompt — the subagent_type loads them automatically.

Knowledge mode: do NOT skip this step. Spawn at least 2 web scrapers to verify your top 3 intended claims; do not synthesize before reading their files.

### Step 3: Read results and self-check

Read every file under the run directory, grouped by sub-question. Apply these **hard triggers** per sub-question; if any fires, dispatch follow-up scrapers with rephrased queries:

1. **Missing file** — expected file absent or empty (scraper crash).
2. **Source famine** — fewer than 3 distinct sources across the sub-question.
3. **Source monoculture** — only blog/forum sources, zero doc/github/code. Follow up biased toward authoritative sources.
4. **Insufficient-data marker** — file contains (case-insensitive): `insufficient data`, `from memory`, `from training memory`, `from training data`, `training data through`, `training cutoff`, `memory cutoff`, `from prior knowledge`, `based on memory`, `I recall`, `as I recall`, `verify against`. Treat any match as the scraper mixing fetches with memory.
5. **Fabrication smell** — discard the file and dispatch a replacement if either fires:
   - **5a. Source/URL mismatch** — Facts section has zero URLs, or every URL is a bare domain root without a deep path.
   - **5b. No fetch evidence** — no URL with `/issues/<digits>`, `/pull/<digits>`, `/releases/tag/`, `/commit/<hash>`, date stamps (`/YYYY/MM/` or `-YYYY-MM-DD-`), `?v=`/`?id=`, or `#fragment` — AND zero quoted strings AND zero version numbers. Indistinguishable from a memory dump.

**Recovery — resume before respawn.** If a scraper stalled (turn-limit death, thin checkpoint file), prefer `SendMessage` to that agent's ID — it still holds its real fetches in context — before spawning a fresh follow-up. Either path counts toward the limit: maximum 2 follow-up rounds per sub-question, then record the gap (a plain-language bullet under **What You Need to Consider** in chat; the saved report's **Verification** section) instead of papering over it.

If no trigger fires, continue directly to Step 4.

**`/vidi` candidate review (optional, bounded).** While reading the scraper files, watch for `VIDI-CANDIDATE: <url> — <why>` lines a web scraper may emit for a YouTube video whose on-screen content (demo, slides, dashboard, code, charts) is load-bearing to the question and not captured by its transcript/description. These are *suggestions*, not orders. For each, decide:
- **Is it material?** Would the video's visuals actually change or strengthen the answer, vs. a "nice to have"? If the transcript already carries the substance, skip it.
- **Budget.** `/vidi` is a heavy single-video visual pass — treat it like a follow-up scraper round, not a freebie. Cap at **1–2 `/vidi` runs per whole research run**; if more are flagged, pick only the most decision-critical. On `--fast`, skip `/vidi` entirely.
- **How to run it.** For a chosen candidate, invoke the `vidi` skill on the watch URL and fold its visual findings into the corpus under the same provenance contract as any source: the fact carries the YouTube URL plus a `quote:`/on-screen-description drawn from what `/vidi` actually reported. A `/vidi`-derived claim that is central still goes through Step 5 verification like everything else.

If no `VIDI-CANDIDATE` lines appear, or none clear the material+budget bar, this is a no-op — continue.

**Mirror the raw fetches (durable copy for `--reverify`).** Once the scraper files have passed the self-check above, copy them out of the volatile `/tmp` dir into the durable mirror so an interrupted run is recoverable (Step 0.7 reads from there first). One Bash call — `find`-based so it is robust across bash/zsh (an unmatched `*.md` glob never errors or expands), and the guard leaves no empty `raw/<run_id>/` dir when nothing matched:

```
if find /tmp/deep-research/<run_id> -maxdepth 1 -name '*.md' -type f | grep -q .; then mkdir -p ~/.claude/deep-research/raw/<run_id> && find /tmp/deep-research/<run_id> -maxdepth 1 -name '*.md' -type f -exec cp {} ~/.claude/deep-research/raw/<run_id>/ \; ; fi
```

`<run_id>` is the epoch dir name from Step 2. This is the step that makes `--reverify` dependable rather than luck-of-the-tmp-dir — without it the durable copy never exists. Negligible cost (one copy, no new subagent). Re-copy is harmless (idempotent overwrite); do it again after any follow-up scraper round so the mirror stays complete.

### Step 4: Extract candidate claims

Orchestrator work — no agents. For each concrete, falsifiable statement in the scraper files record: **claim** (one checkable sentence), **quote** (verbatim `quote:` snippet if present, else empty — the verifier fetches the source itself), **source_url** + **source_type**, and **centrality**: `central` (directly answers the research question), `supporting`, or `tangential`.

Only `central` claims enter Step 5; `supporting`/`tangential` flow unverified into synthesis with no confidence boost. Skip Step 5 only for the legitimate reasons listed in Step 0.5 — record `verify_skipped_reason` in METRICS. In `mixed` mode, only central claims with a URL source (not a file path) are eligible.

### Step 5: Verify central claims (batched escalation ladder)

Select eligible central claims up to the tier cap (lite 5 / standard 10 / thorough 12); list any dropped by the cap under the report's Verification section as "not verified (cap)".

**Never spawn one verifier per claim.** One `dr-verifier` handles a batch of up to ~10 claims, so the whole stage is a handful of agents. The ladder:

1. **Round 1 (always):** batch claims in groups of ≤10, ONE `dr-verifier` per batch, all batches in parallel.
2. **Round 2 (standard/thorough only):** one fresh verifier re-reads the *important* claims (top decision-drivers) as a single batch.
3. **Round 3:** one fresh verifier re-checks claims that came back `contradicted` AND materially affect the answer, with each contradiction noted in its prompt. Skip if none.
4. **Resolve or throw out:** an escalated claim that still cannot be resolved is **removed** from the findings and listed under Verification as "removed — unresolved contradiction" with its counter-source.

Lite tier runs Round 1 (one agent) plus at most one escalation agent when a contradiction needs it — verification at lite costs 1-2 subagents total.

Verifier output files: `<run-dir>/verify-r{round}-b{batch}.md`. Verifiers return `DONE|{path}`; read the verdict files afterward. Full spawn pattern, aggregation rules, and confidence mapping: read `references/verification.md` before dispatching verifiers.

**Same no-fallback rule as scrapers:** if `dr-verifier` fails to spawn, never verify claims yourself and never substitute an agent type — mark affected claims `unverified` and move on (see `references/error-handling.md`).

### Step 6: Link gate (curl sweep + bounded spot-render)

Every URL in the final Sources list gets checked. Two layers:

**6a. Curl sweep (always — one Bash call).** Write the Sources URLs to `<run-dir>/sources.txt`, then:

```bash
xargs -n1 -P8 -I{} curl -sIL -o /dev/null -m 15 -w '%{http_code} {}\n' "{}" < <run-dir>/sources.txt
```

For any URL returning `000`, `4xx`, or `5xx` (some servers reject HEAD), retry once with a small GET: `curl -sL -o /dev/null -m 20 -r 0-2048 -w '%{http_code}' "<url>"`. Classify: 200-399 → alive; anything else → mark the Sources entry `[link: dead]`. If a claim depended solely on a dead URL, move it to the Verification section as "source unreachable at publish time" rather than presenting it as cited fact.

**6b. Playwright spot-render (skip under `--fast`).** Render at most **5** URLs in the Playwright MCP — only URLs that (a) back a Key Finding AND (b) were not already fetched by a verifier this run (a verifier fetch is equivalent evidence). For each: `browser_navigate`, then `browser_snapshot`; confirm the cited content is visibly present. Loads but content not found → keep the source, append `[link: content not located]`, downgrade solely-dependent claims to `low` confidence. Dead/blocked → treat as 6a-dead.

If curl is unavailable or every check errors, do not silently skip: add one line under Sources — "Link check could not run; links unverified." That is the only allowed degradation; never fabricate a checked status.

### Step 6.5: Research-review gate (before synthesis)

A bad line of research becomes many bad lines of report — so review the *corpus*, not just the draft. Before writing anything, look across all verdicts + link results and ask:

- **Coverage:** does every sub-question have at least one confirmed (or uncontested) central claim? A sub-question left with only contradicted/unverified/dead-link claims is a hole.
- **Contradiction:** did two sources give incompatible answers to the same central question, with the verifier unable to resolve it? That is a finding to surface, not paper over.
- **Thinness:** is any Key Finding resting on a single source, or on sources that all share one origin?

If a gap is **material to the answer** AND you have follow-up rounds left (max 2 per sub-question, Step 3 budget), dispatch one targeted re-scrape with a sharper, still-neutral angle, then re-verify only the new central claims. Otherwise, do NOT silently smooth it over — carry it into the report explicitly (as a plain-language bullet under **What You Need to Consider** in chat, and the saved report's **Verification** section). This gate is a no-op on a clean run; its only job is to stop synthesis from laundering weak research into confident prose.

### Step 7: Synthesize and present

Synthesize across scraper files **by theme**, not by sub-question or scraper. Present using the structure in `references/output-format.md`: **Bottom Line → What You Need to Consider → Recommended Actions → Supporting Detail.** The **chat report is clean prose — no `[^N]`, no Sources section.** Lead with the answer and what the user must weigh/do; the verification already happened internally, so write with confidence (and flag low-confidence or contradicted items in plain words, per the format file).

After presenting, ask: "Should I save the results as a report? (stored under ~/.claude/deep-research/)"

If yes, write `~/.claude/deep-research/YYYY-MM-DD-<topic-slug>.md`. **The saved file is the cited version**, not a copy of the clean chat output: take the same Bottom Line / Considerations / Recommended Actions / Supporting Detail body, re-attach `[^N]` to every factual statement (synthesis → `[interpretation]`), and append the full **Sources** section (per `references/output-format.md`). This preserves traceability and lets `--reverify` work. Slug: lowercase ASCII (ä→ae, ö→oe, ü→ue, ß→ss, drop other accents), keep `[a-z0-9]`, collapse runs of other characters to a single `-`, trim edge dashes, max 60 chars; on collision append `-2`, `-3`, … (never overwrite); prepend YAML frontmatter with `topic` (verbatim), `date`, `mode`, `tier`, `run_id` (the epoch run dir — lets `--reverify <run_id>` find this exact report later), `sources_count`, then a blank line, then the report. If the run shipped before verification finished, also add `status: VERIFICATION-INCOMPLETE — …` so a later `--reverify` (Step 0.7) can spot and upgrade it.

### Step 8: Metrics

End your final response with the METRICS comment — a **flat JSON object with exactly these keys** (no nesting, no extra keys, no omissions — the stop hook normalizes, but drift makes runs unaggregatable). Field meanings: `references/metrics.md`.

```
<!-- METRICS:{"schema_version":4,"run_id":"<epoch>","topic":"...","mode":"web","tier":"lite","fast":false,"subquestions":N,"scrapers":N,"scraper_errors":N,"follow_up_rounds":N,"verifier_agents":N,"claims_verified":N,"claims_confirmed":N,"claims_contradicted":N,"claims_thrown_out":N,"verify_skipped_reason":null,"links_checked":N,"links_dead":N,"renders_done":N,"sources_total":N,"corridor_violations":N,"hard_cap_hit":false,"approval_gate_action":"approved"} -->
```

`verify_skipped_reason` is `null` when Round-1 verification ran (including runs where only escalation was dropped for speed), else one of `"fast-flag"`, `"no-verify-flag"`, `"no-central-claims"`, `"codebase-mode"`. There is no `"user-request"` full-skip value — a conversational "go faster" demotes escalation only and keeps `verify_skipped_reason: null`; a genuine zero-verify run comes from the `--fast`/`--no-verify` flag. `corridor_violations` counts sub-questions outside the **active tier's** corridor (Step 1 table).

## Context window protection

| Level | What you see | Max total |
|-------|-------------|-----------|
| Scraper return values | DONE\|path only | ~100 words |
| Scraper file reads | 600 words × ~12 files | ~7,200 words |
| Verifier return values | DONE\|path only | ~100 words |
| Verifier file reads | 1 batch file per ~10 claims + ≤2 escalation files | ~3,000 words |
| Link gate | curl status lines + ≤5 page snapshots | bounded |

Scrapers and verifiers return only `DONE|{path}`; read files on demand.

## Error handling

Read `references/error-handling.md` for spawn failures, vague questions, and quality issues.

## Self-verification

Before finishing, check:

1. Response ends with the METRICS comment, flat schema, all keys present?
2. **Chat report** is clean prose in the right order (Bottom Line → What You Need to Consider → Recommended Actions → Supporting Detail) with **no `[^N]` tags and no Sources section**?
3. **If you saved a report:** every factual statement in the saved file carries `[^N]` or `[interpretation]`, and every `[^N]` resolves to a numbered Sources entry? (Chat output is exempt — it's intentionally citation-free.)
4. Did Round-1 verification actually run? It MUST have, unless `verify_skipped_reason` is exactly one of `"fast-flag"`, `"no-verify-flag"`, `"no-central-claims"`, `"codebase-mode"` — all of which come from an explicit flag or a structural fact, never from a judgment call or a conversational "be quick" (that demotes escalation only, with `verify_skipped_reason: null`). If you skipped Round 1 for any other reason, STOP and run it. When it ran: every central claim has a verdict-derived confidence OR appears in the Verification section (unverified / removed / not verified (cap)).
5. Did the curl sweep cover every Sources URL (each alive, `[link: dead]`-tagged, or covered by the "Link check could not run" note)?

If any check fails, re-read the scraper files and fix the gaps before sending. In the **saved** file, a claim without a source is a bug, not an output — but the chat report is intentionally clean prose, and the underlying verification still ran on the sources regardless of what the chat shows.

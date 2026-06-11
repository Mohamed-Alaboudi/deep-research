---
name: dr
description: |
  Deep research across web, codebase, and knowledge domains with auto-scaling.
  Use when: "research", "deep research", "investigate", "compare", "analyze across",
  "what are best practices for", "how does X compare to Y", "survey options for".
  Supports web research, codebase analysis, knowledge synthesis, and mixed mode.
---

# Deep Research Orchestrator

You coordinate research by spawning sub-agents and synthesizing their findings. You never search or fetch directly.

## Three rules

1. End your final response with `<!-- METRICS:{...} -->` so the stop hook can record the run.
2. Spawn scrapers with `model: "sonnet"` and an explicit depth level, because without these they inherit your model (expensive) and default to shallow searches (poor results).
3. Copy every source URL from scraper outputs into your final Sources section, because the user needs them to verify claims.

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
- "Switch to general-purpose agents to get web access"

There is no fallback mode. Either scrapers work, or the skill aborts cleanly. For the abort + permissions-recovery flow, see `references/error-handling.md`.

## Workflow

### Step 0: Context-Check

Before planning, assess whether the topic has enough context for useful research. Skip this step if the user passed `--mode` together with a detailed topic (>50 words with clear constraints), or if the topic is a precise, self-contained question (named entity + specific aspect, e.g. "LiveView 1.0 streams vs. temporary_assigns for large lists").

Evaluate the topic along five dimensions:

- **Scope** — how broad? (one tool vs. whole landscape)
- **Purpose** — what will the result be used for? (decision, learning, comparison, implementation)
- **Constraints** — stack, versions, region, timeframe, budget, team size?
- **Depth** — overview vs. deep-dive?
- **Decision frame** — compare options, pick one, validate a hypothesis, or just survey?

Trigger clarification when **two or more** dimensions are unclear, **or** when the topic is under 10 words without surrounding context in the conversation.

If clarification is needed, ask at most **3 targeted questions** via `AskUserQuestion` (one tool call, multiple questions). Phrase each question with 2-4 concrete options plus an "Other" escape hatch. Questions must materially change the research plan — if an answer would not change sub-questions, depth, or mode, do not ask it.

Examples of questions that change the plan:
- "Welcher Stack-Kontext?" → steers codebase vs. web mode and keyword choice
- "Decision or overview?" → steers depth allocation (1 deep vs. 3 standard)
- "Time range of sources?" → steers whether to prioritize recent blog posts vs. established docs

After the user answers, distill the responses into a `CONSTRAINTS:` block (1-2 lines max — stack/version, decision context, source preferences, time-frame, anything that materially shapes lookups). **Keep the original topic unchanged.** The CONSTRAINTS block flows into every Analyst and Scraper dispatch as additional context, so search queries respect it.

If the user explicitly says "just start" or similar, skip clarification and use sensible defaults. Leave CONSTRAINTS empty or omit it. Continue to Step 1. Do not re-ask.

### Step 0.5: Flags and tier

Parse these optional flags from the topic string (strip them out before treating the rest
as the topic):

| Flag | Effect |
|------|--------|
| `--mode web\|codebase\|knowledge\|mixed` | Force research mode (as before) |
| `--tier lite\|standard\|thorough` | Cost/verify tier. Default resolution order below |
| `--verify3` | **Deprecated.** Verification now uses an escalation ladder (Step 5), not a flat voter count. Accepted but ignored with a one-line note. |
| `--no-verify` | Skip the verify stage entirely (v2.3.0 behavior) |
| `--yes` / `--no-confirm` | Skip the approval gate (as before) |

Tier default resolution: if `--tier` is given, use it. Otherwise read
`~/.claude/deep-research/config.json` and use its `default_tier` if present and valid
(`lite`/`standard`/`thorough`). Otherwise default to `lite`.

```bash
# tier default lookup (run once, before planning)
cat ~/.claude/deep-research/config.json 2>/dev/null
```

Tier parameters:

| Tier | Verify central-claims cap | Verification | Hard subagent cap |
|------|---------------------------|--------------|-------------------|
| lite | 8 | batched ladder (Step 5) | 25 |
| standard | 10 | batched ladder (Step 5) | 35 |
| thorough | 12 | batched ladder (Step 5) | 55 |

Verification is no longer one agent per claim. Round 1 batches up to ~10 claims into each
`dr-verifier` agent; only important or contradicted claims get a 2nd/3rd batched re-check.
See Step 5. The tier controls only the claim cap and the hard subagent cap. `--verify3` is
deprecated (the batched ladder supersedes it); if passed, ignore it with a one-line note
("verify3 ist veraltet — die gebündelte Eskalationsleiter ersetzt feste Voter, ignoriert").
The hard subagent cap is absolute — no flag raises it above the tier value.

### Step 1: Plan

Parse the topic and detect mode. **Mode must be exactly one of `web`, `codebase`, `knowledge`, or `mixed`.** Do not invent new modes (e.g. `analytics`, `survey`, `comparison`) — pick the closest of the four:

- Web: external information needed
- Codebase: topic relates to a project in the working directory
- Knowledge: foundation comes from training data, but **MUST be fact-checked** — dispatch at least 2 `dr-scraper-web` scrapers to verify the top-3 claims before synthesis. No claim ships without a source.
- Mixed: requires both web and codebase

Break the topic into 2-4 sub-questions. Assign each a depth level:
- `deep`: core question (typically 1)
- `standard`: regular sub-questions (1-2)
- `shallow`: peripheral questions (0-2)

Present the plan together with the dispatch-budget breakdown **and** a one-line rationale per sub-question so the user can spot a wrong-direction research framing before any token is spent. The user should be able to read the plan and think "no, you misunderstood — I actually care about X, not Y" and intervene. Without the rationale they can only see counts, which doesn't help them course-correct.

For each sub-question include:
- The depth level (`shallow` / `standard` / `deep`)
- The concrete scraper count inside the depth corridor (use the lower bound by default, raise only if the angle genuinely needs more coverage)
- **Why this depth**: one short clause — is it the core decision-driver, a peripheral fact-check, a sanity-check on a known fact?
- **Angles**: the distinct sub-question framings each scraper will pursue (so the user sees what gets searched, not just how many)

```
Forschungsplan: "[Topic]"
Modus: [Web / Codebase / Knowledge / Mixed]

1. [Sub-question] (deep) — N scrapers
   Why deep: [core decision driver / multiple competing answers / etc.]
   Angles: [angle 1] · [angle 2] · [angle 3]
2. [Sub-question] (standard) — N scrapers
   Why standard: [regular sub-question, established sources expected]
   Angles: [angle 1] · [angle 2]
3. [Sub-question] (shallow) — N scrapers
   Why shallow: [peripheral fact-check / known terrain]
   Angles: [angle 1]

Dispatch budget: N scrapers total (Sweet-Spot ~12, Ceiling ~15)
```

For `mode: knowledge`, the plan has exactly one synthetic sub-question — frame it as the verification of the top-3 claims you intend to make:

```
1. Verification of the 3 core claims (standard) — 2 scrapers
   Why standard: knowledge-mode mandatory fact-check, not skippable
   Angles: Claim 1 (X) · Claim 2 (Y) · Claim 3 (Z)

Dispatch budget: 2 scrapers total
```

Keep the rationale and angles short — the user wants to scan, not read prose. One line each is enough.

### Step 1.5: Approval gate

Before dispatching, ask the user once whether the plan is OK. The gate exists because each scraper consumes Claude session quota and the user may want to adjust depth or sub-questions before fanning out.

Skip this gate **only** if any of these literal conditions hold (no fuzzy matching, no "or similar" — be strict, otherwise the gate becomes meaningless):
- The user's topic string contains the exact token `--yes` or `--no-confirm`
- Total dispatch budget is exactly `1` scraper (single shallow lookup, gate would be pure ceremony)

If you are unsure whether the user already confirmed earlier in the conversation, ask anyway. False-positive skips defeat the gate's purpose.

Otherwise, ask via `AskUserQuestion`:

> Frage: "Plan OK so? N scrapers werden parallel gestartet."
> Optionen: "Ja, loslegen" | "Anpassen" | "Abbrechen"

If the user picks "Anpassen":
1. If they spelled out what to change in their answer notes, apply that change.
2. If they only picked "Anpassen" without detail, ask **one** targeted follow-up: "What should change? (sub-question, depth, scraper count, mode, or individual angles)" — do NOT re-present the unchanged plan, that wastes a turn.
3. Update the plan, re-present it (with the same dispatch-budget breakdown), ask the gate again.

Repeat up to 5 adjustment rounds. If the user is still adjusting after the 5th, suggest aborting and re-invoking with a clearer topic. Don't enforce a hard stop — the loop limit is a soft hint that something deeper is unclear.

If "Abbrechen": stop cleanly, no METRICS comment.

### Step 2: Dispatch scrapers

You dispatch scrapers directly — there is no analyst layer. For each sub-question, decide how many scrapers to spawn based on its depth level:

| Depth | Scrapers per sub-question | Rule |
|-------|--------------------------|------|
| shallow | 1-2 | Peripheral fact-check, don't over-fan-out |
| standard | 2-4 | Regular sub-question |
| deep | 3-5 | **MUST spawn at least 3 scrapers.** Never shortcut a deep question with 1-2 scrapers |

The floor for `deep` is hard. The ceilings are soft — exceed them only if the question genuinely needs more angles.

**Total scraper budget across all sub-questions: ~12 parallel spawns is the sweet spot, ~15 is the practical ceiling.** If your plan would dispatch more than 15 in parallel (e.g. 4 sub-questions × 5 deep scrapers each = 20), reduce by one of:
- Lowering depth on a peripheral sub-question (deep → standard, standard → shallow)
- Merging two related sub-questions into one
- Using the lower bound of the corridor (deep with 3 instead of 5)

Reason: beyond ~10 parallel subagents, each additional one delivers diminishing marginal coverage while linearly increasing token cost and timeout risk.

**Hard subagent cap (tier-dependent).** Before dispatching, compute the planned total:
`scrapers + planned verifiers`. With the batched ladder (Step 5), verifiers are now a small
number of batch agents, not one per claim: estimate the planned verifier count as
`ceil(central_claims / 10)` for Round 1, plus at most ~2 escalation batch agents (one
Round-2, one Round-3). A safe upper bound is `ceil(central_claims / 10) + 2`. If
`scrapers + planned_verifiers` exceeds the tier hard cap (lite 25 / standard 35 /
thorough 55), trim in this order until it fits: (1) reduce verify claims (drop
lowest-centrality / weakest-source first), (2) only then reduce scraper count. Record
`hard_cap_hit: true` in METRICS if you trimmed. The cap is absolute; never exceed it,
regardless of flags.

Each scraper handles ONE narrow angle of its sub-question. Phrase angles distinctly so scrapers don't search for the same thing.

Launch all scrapers across all sub-questions in parallel. Each scraper writes its findings to a file in `/tmp/deep-research/` and returns the file path. Files survive context compaction; OS cleans them on reboot.

Use this pattern for each scraper:

<example>
Agent(
  subagent_type: "deep-research:dr-scraper-web",
  model: "sonnet",
  prompt: "Collect facts for the question below. Follow your agent instructions for output format and return value.

QUESTION: What pricing tiers does Stripe offer for SaaS billing in 2026?
DEPTH: standard
CONSTRAINTS: Mid-market SaaS, US/EU only, last 24 months
OUTPUT_FILE: /tmp/deep-research/sq1-web-1.md"
)
</example>

For codebase scrapers: `subagent_type: "deep-research:dr-scraper-codebase"`. CONSTRAINTS still applies if present.

The full process and output format live in the agent bodies (`agents/dr-scraper-web.md`, `agents/dr-scraper-codebase.md`). Do not duplicate them in the spawn prompt — the subagent_type loads them automatically.

Before dispatching, create a per-run output directory under `/tmp/deep-research/<epoch-seconds>/` (e.g. `mkdir -p /tmp/deep-research/$(date +%s)`) and use that directory for OUTPUT_FILE paths. The per-run subdir prevents file collisions when the user runs `/dr` in two sessions simultaneously. Remember this epoch value: it is the run's `run_id` and must be recorded in the METRICS comment (Step 7), so a later triage can match a problematic run back to its session transcript.

OUTPUT_FILE naming convention: `<run-dir>/sq{N}-{type}-{M}.md` where N=sub-question index, type=`web` or `codebase`, M=scraper index within that sub-question. Example: `/tmp/deep-research/1746619200/sq2-web-3.md` is the 3rd web scraper for sub-question 2. Adapt QUESTION, DEPTH, and CONSTRAINTS per scraper.

For knowledge mode: do NOT skip this step. Treat your top 3 intended claims as one synthetic sub-question and spawn at least 2 web scrapers to verify them. Do not synthesize before reading their files. Knowledge mode without verification scrapers is a bug — every claim still needs a source from `dr-scraper-web`, just like in web mode.

### Step 3: Read results and self-check

After all scrapers complete, read every file they wrote (under your run directory), grouped by sub-question:

```
Read /tmp/deep-research/<run-dir>/sq1-web-1.md
Read /tmp/deep-research/<run-dir>/sq1-web-2.md
Read /tmp/deep-research/<run-dir>/sq2-web-1.md
...
```

Apply these **hard triggers** per sub-question (aggregate across all scraper files belonging to that sub-question). If any fires, spawn one or more follow-up scrapers targeting that sub-question with rephrased queries:

1. **Missing file** — a scraper's expected file doesn't exist or is empty (scraper crash).
2. **Source famine** — the sub-question's scrapers together produced fewer than 3 distinct sources.
3. **Source monoculture** — the sub-question has only blog/forum sources and zero doc/github/code. Spawn a follow-up biased toward authoritative sources.
4. **Insufficient data marker** — any scraper file contains these phrases (case-insensitive): `insufficient data`, `from memory`, `from training memory`, `from training data`, `training data through`, `training cutoff`, `memory cutoff`, `from prior knowledge`, `based on memory`, `I recall`, `as I recall`, `verify against`. Sonnet's honest-disclosure reflex sometimes adds these notes; treat any match as evidence that the scraper mixed real fetches with memory.
5. **Fabrication smell** — two mechanical sub-checks per scraper file. If either fires, discard that file and dispatch a replacement scraper.
   - **5a. Source/URL mismatch** — file claims facts but its Facts section has zero URLs, OR every URL is a bare domain root (e.g. `https://hex.pm/`, `https://github.com/`) without a deep path.
   - **5b. No fetch evidence** — file's Facts contain no URL with any of: `/issues/<digits>`, `/pull/<digits>`, `/releases/tag/`, `/commit/<hash>`, date stamps (`/YYYY/MM/` or `-YYYY-MM-DD-`), query string `?v=` or `?id=`, fragment `#section`. AND zero quoted strings (no `"..."` or `'...'`) AND zero version numbers (no `v?\d+\.\d+(\.\d+)?`). A scraper with no quote, no date, no version, no deep URL is indistinguishable from a memory dump.

Skip Step 3 entirely if no trigger fires. Continue to Step 4.

**Recovery strategy — resume before respawn.** When a trigger fires because a scraper stalled (hit its turn limit and returned narration instead of `DONE|path`, or wrote only a thin checkpoint file), prefer resuming that same agent via `SendMessage` to its agent ID before spawning a fresh one. A stalled scraper still holds its real fetches in context, so a resume usually produces the missing facts far cheaper than a respawn that repeats every search. Fall back to a fresh follow-up scraper only when the stalled agent has no reachable ID or the resume itself fails. Either path counts toward the 2-round limit below.

Maximum 2 follow-up rounds total per sub-question. If a sub-question still triggers after both rounds, mark it under **Contradictions & Open Questions** in the final output instead of papering over the gap with `[interpretation]`.

### Step 4: Extract candidate claims

After Step 3 (self-check), read the scraper files and extract candidate claims. This is
orchestrator work — spawn no agents here.

For each concrete, falsifiable statement in the scraper files, record:
- **claim**: one checkable sentence (not a vague generality)
- **quote**: the verbatim `quote:` snippet from the scraper file if present; else leave
  empty (the verifier will fetch the source itself)
- **source_url** + **source_type**
- **centrality**: `central` (directly answers the research question), `supporting`
  (useful context), or `tangential` (peripheral)

Only `central` claims enter Step 5. `supporting` and `tangential` claims flow unverified
into synthesis exactly as today (no confidence boost).

Skip Step 5 entirely if: `--no-verify` was passed, OR there are zero `central` claims, OR
the mode is `codebase` (codebase claims are not web-verifiable; they keep `medium`
confidence). In `mixed` mode, only `central` claims whose source is a URL (not a file
path) are eligible.

### Step 5: Verify central claims (escalation ladder)

Select the eligible `central` claims, capped at the tier's verify cap (lite 8, standard
10, thorough 12). If there are more eligible central claims than the cap, keep the ones
with the strongest centrality and best source type; list the dropped ones under the
report's Verification section as "not verified (cap)".

**Verification BATCHES claims to save agent spawns, then escalates the few contested ones.**
Do NOT spawn one agent per claim — that produces dozens of agents (e.g. 75 claims → 75
agents). Instead, one `dr-verifier` handles a BATCH of ~10 claims, so the whole verify
stage is a handful of agents (e.g. 75 claims → ~8 agents), and only contested or important
claims get individually re-checked:

1. **Round 1 — batched (always).** Group the selected central claims into batches of **up
   to 10 claims each**. Spawn ONE `dr-verifier` per batch (75 claims → 8 agents; 10 claims
   → 1 agent). Each batch agent returns one verdict per claim in its batch. This is the
   minimum; most claims are fully resolved here.
2. **Round 2 — 2nd look for important claims.** After reading Round-1 verdicts, collect the
   *important* claims (top decision-drivers the user's conclusion hinges on). Send them as a
   single new batch (up to 10) to ONE fresh `dr-verifier` for a second independent read.
   Ordinary central claims are not re-checked.
3. **Round 3 — escalate useful contradictions.** Collect every claim that came back
   `contradicted` **and is useful** (materially affects the answer — not a tangential
   aside). Send them as a single batch to ONE fresh `dr-verifier`, with each contradiction
   noted in its prompt so it digs deeper than the one-search baseline. (If there are zero
   such claims, skip this round — no agent.)
4. **Resolve or throw out.** For each escalated claim, after the Round-3 look:
   - If it now confirms (or the contradiction was spurious) → the claim survives with the
     resulting confidence.
   - If it **still cannot be resolved** (`contradicted`/`uncertain` against the claim) →
     **throw the claim out.** Drop it from the main findings and list it under the report's
     Verification section as "removed — unresolved contradiction" with the counter-source.

So a typical run is ~8 Round-1 agents + at most 1 Round-2 agent + at most 1 Round-3 agent —
roughly 10 agents total for 75 claims, versus 75+ with per-claim spawning. A claim with no
contradiction and that is not "important" costs no agent beyond its share of one batch.

Run rounds in waves: launch all Round-1 batches in parallel; once you've read every
verdict, launch the single Round-2 batch and/or single Round-3 batch that the verdicts
triggered.

Respect the hard cap from Step 2 — but with batching the verifier-agent count is now small
(`ceil(claims/10)` for Round 1, plus at most ~2 escalation agents), so the cap is rarely
the binding constraint. If the *claim* count still pushes you over, reduce claims first
(drop lowest-centrality), not the batching or the escalation logic.

Write verifier outputs into the same per-run directory used for scrapers, named
`<run-dir>/verify-r{round}-b{batchIndex}.md` (e.g. `verify-r1-b3.md` is Round 1, batch 3;
`verify-r3-b1.md` is the single Round-3 escalation batch).

Spawn pattern per batch (one agent, up to ~10 claims):

<example>
Agent(
  subagent_type: "deep-research:dr-verifier",
  model: "sonnet",
  prompt: "Verify the batch of claims below. Follow your agent instructions for output format and return value.

QUESTION: What are Stripe's 2026 payment fees for SaaS?

CLAIM 1: Stripe charges 0.4% for ACH payments in 2026.
QUOTE 1: \"ACH Direct Debit ... 0.4% per transaction (capped at $5.00)\"
SOURCE_URL 1: https://stripe.com/pricing
SOURCE_TYPE 1: doc

CLAIM 2: Stripe Billing costs 0.7% of recurring revenue.
QUOTE 2: \"Billing ... 0.7% on recurring payments\"
SOURCE_URL 2: https://stripe.com/billing/pricing
SOURCE_TYPE 2: doc

... (up to 10 claims) ...

OUTPUT_FILE: /tmp/deep-research/<run-dir>/verify-r1-b1.md"
)
</example>

Launch all Round-1 batch agents in parallel. Each returns only `DONE|{path}`; read the
verdict files afterward — each file holds one `### Verdict N` block per claim in that batch.

**Aggregation (per claim, across the rounds it appeared in).** Each claim's verdict comes
from its `### Verdict N` block in the batch file(s) that covered it:
- **Round 1 only** (ordinary central claim, not important, not contradicted): its Round-1
  verdict stands.
- **Round 1 + Round 2** (important claim): if the two reads agree, that's the verdict; if
  they disagree, treat it as contested and fold it into Round 3.
- **Escalated to Round 3** (a useful claim was contradicted in an earlier round): the
  Round-3 verdict decides. If it confirms → the claim survives. If it stays
  `contradicted`/`uncertain` → **throw the claim out** (Step 5, point 4).

Map the surviving verdict to confidence:
- all/most `confirmed` + primary source → `high`
- `confirmed` with secondary source, or a survived-after-escalation claim → `medium`
- `uncertain`, or single weak source → `low`

Thrown-out claims are removed from the main findings and listed under the report's
Verification section as "removed — unresolved contradiction" with their counter-source.

**Same no-fallback rule as scrapers.** If spawning `dr-verifier` fails for any reason, you
MUST NOT verify claims yourself with direct WebSearch/WebFetch, and MUST NOT substitute
another agent type. Either the verifier works, or you skip verification for that claim and
mark it `unverified` in the Verification section. See `references/error-handling.md`.

### Step 6: Synthesize and present

Synthesize findings across the scraper files by theme, not by sub-question and not by scraper.

**Step 5.9 — Playwright link gate (before presenting).** Every URL you are about to put in
the Sources section must be opened in the Playwright browser MCP and confirmed to actually
load and show real content — not a 404, paywall wall, login redirect, parking page, or
empty shell. Do this for the *final* Sources list only (the URLs that survived into the
report), so the cost scales with citations, not raw fetches.

For each Sources URL:
1. `mcp__playwright__browser_navigate` to the URL.
2. `mcp__playwright__browser_snapshot` (or a screenshot) to confirm the page rendered real,
   on-topic content — the thing the citation claims is there is visibly present.
3. Classify:
   - **Loads + shows the cited content** → keep the source as-is.
   - **Loads but the cited content isn't visibly there** (page changed, anchor moved) →
     keep the source but append `[link: content not located]` to that Sources entry, and
     downgrade any claim that depended solely on it to `low` confidence.
   - **Dead / 404 / blocked / parking page** → mark the Sources entry `[link: dead]`. If a
     claim depended solely on that URL, move it to the Verification section as "source
     unreachable at publish time" rather than presenting it as cited fact.

If the Playwright MCP is unavailable or every navigation errors out, do not silently skip:
present the report but add a one-line note under Sources — "Playwright link-check could not
run; links unverified" — so the user knows the gate didn't execute. This is the only
allowed degradation; never fabricate a "verified" status.

Present in chat using the structure from `references/output-format.md`. **Every Kernpunkt and every Finding-statement must end with a `[^N]` inline citation** pointing to the numbered Sources section. Build the Sources list from the actual URLs in the scraper files. If a statement cannot be tied to a source from the files, either remove it or mark it `[interpretation]` and explain why. No claim ships without either a citation or an `[interpretation]` tag.

After presenting, ask: "Should I save the results as a report? (file will be stored under ~/.claude/deep-research/)"

If yes, write to `~/.claude/deep-research/YYYY-MM-DD-<topic-slug>.md` following these rules:

- **topic-slug**: lowercase, ASCII-only (ä→ae, ö→oe, ü→ue, ß→ss, drop other accents), keep `[a-z0-9]` and replace runs of other characters with a single `-`, trim leading/trailing dashes, max 60 characters total
- **Collision**: if the target file already exists, append `-2`, `-3`, ... before `.md` (e.g. `2026-04-28-caching-2.md`). Never overwrite.
- **Frontmatter**: prepend YAML frontmatter so the file is later indexable, then a blank line, then the report:

  ```yaml
  ---
  topic: <original topic verbatim>
  date: YYYY-MM-DD
  mode: <web | codebase | knowledge | mixed>
  sources_count: <integer>
  ---
  ```

### Step 7: Metrics

End your final response with the METRICS comment so the stop hook can record the run.

The new fields after `follow_up_needed` are for compliance tracking — they let us measure whether the depth corridor and citation rules are actually followed across many runs. Compute them from your own dispatch records and your final output:

- `run_id`: the epoch-seconds value from your per-run output directory (Step 2, e.g. `"1746619200"`). Always include it — it lets a later triage match a problematic run back to its session transcript. Without it, a bad run is invisible in the aggregated metrics.
- `scraper_count_per_subquestion`: list of `{depth, count}` — one entry per sub-question with the scraper count you dispatched for it
- `depth_corridor_violations`: integer count of sub-questions that broke the corridor (deep with <3 scrapers, shallow with >2, standard outside 2-4)
- `claims_with_citation`: integer count of factual statements ending with `[^N]` or `[interpretation]` in your final response
- `claims_total`: integer count of factual statements in your final response (denominator for compliance)
- `constraints_used`: boolean — did Step 0 produce a CONSTRAINTS block that was passed to scrapers?
- `knowledge_factcheck_done`: boolean — for `mode=knowledge`, did you spawn verification scrapers with web lookups? Use `null` for non-knowledge modes.
- `approval_gate_action`: one of `"skipped"` (skip-condition matched), `"approved"` (user picked "Ja, loslegen"), `"adjusted"` (user went through one or more "Anpassen" rounds before approving), or `"cancelled"` (user picked "Abbrechen" — in that case you should not be emitting METRICS at all, this value exists only to make the schema complete).

Verify-stage fields (v3):

- `verify_tier`: `"lite" | "standard" | "thorough"`
- `verify_voters`: `"batched-ladder"` — verification batches ~10 claims per agent in
  Round 1, then escalates contested/important claims (kept in the schema for back-compat)
- `claims_verified`: int — central claims sent to Step 5 (Round 1 count)
- `verifier_agents`: int — total `dr-verifier` agents actually spawned across all rounds
  (≈ `ceil(claims/10)` + escalation batches; this is what batching shrinks)
- `claims_escalated_2`: int — important claims given a 2nd (Round-2) read
- `claims_escalated_3`: int — claims escalated to the Round-3 deep re-check
- `claims_thrown_out`: int — claims removed after an unresolved contradiction
- `claims_confirmed`: int
- `claims_uncertain`: int
- `claims_contradicted`: int — voters that returned contradicted across all rounds
- `links_checked`: int — Sources URLs opened in Playwright (Step 5.9)
- `links_dead`: int — Sources URLs found dead/blocked by the Playwright gate
- `total_subagents`: int — scrapers + verifiers actually spawned
- `hard_cap_hit`: bool — true if the run was trimmed to fit the tier hard cap

Template:

```
<!-- METRICS:{"run_id":"<epoch-seconds>","topic":"...","mode":"...","scrapers":N,"scraper_errors":N,"sources_total":N,"sources_by_type":{"doc":N,"blog":N,"forum":N,"github":N,"code":N},"gaps_found":N,"self_check_passed":BOOL,"follow_up_needed":BOOL,"scraper_count_per_subquestion":[{"depth":"deep","count":4}],"depth_corridor_violations":0,"claims_with_citation":N,"claims_total":N,"constraints_used":BOOL,"knowledge_factcheck_done":BOOL_OR_NULL,"approval_gate_action":"approved","verify_tier":"lite","verify_voters":"batched-ladder","claims_verified":N,"verifier_agents":N,"claims_escalated_2":N,"claims_escalated_3":N,"claims_thrown_out":N,"claims_confirmed":N,"claims_uncertain":N,"claims_contradicted":N,"links_checked":N,"links_dead":N,"total_subagents":N,"hard_cap_hit":false} -->
```

## Context window protection

| Level | What you see | Max total |
|-------|-------------|-----------|
| Scraper return values | DONE|path only | ~100 words |
| File reads | 600 words x ~12 files max | ~7,200 words |
| Verifier return values | DONE|path only | ~100 words |
| Verifier file reads | ~1 batch file per ~10 claims (each holds N verdict blocks) + ≤2 escalation files | ~3,000 words |

Scrapers return only `DONE|{path}`. The orchestrator reads files on demand. Each scraper file is capped at ~600 words; for a typical 4-sub-question / 3-scraper-each run that's ~12 files.

## Error handling

Read `references/error-handling.md` for failures, vague questions, and quality issues.

## Self-verification

Before finishing, check these:

1. Does the response end with the METRICS comment?
2. Does every Kernpunkt and every Finding-statement carry a `[^N]` citation or an `[interpretation]` tag?
3. Does the Sources section contain a numbered entry for every `[^N]` used above?
4. If the verify stage ran: does every `central` claim either carry a confidence marker from a verifier verdict, appear in the Verification section as unverified, or appear there as "removed — unresolved contradiction"? A central claim with no verdict and no Verification entry is a bug.
5. Did the Playwright link gate (Step 5.9) run over every Sources URL — each either kept after rendering real content, tagged `[link: dead]` / `[link: content not located]`, or covered by the "Playwright link-check could not run" note? A Sources URL that was never opened in the browser is a bug.

If any check fails, re-read the scraper files and fix the gaps before sending. A claim without a source is a bug, not an output.

---
name: deep-research
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

If spawning a `deep-research:dr-scraper-web` or `deep-research:dr-scraper-codebase` subagent fails for ANY reason — permission denied, subagent type not found, plugin error, prior failed attempt in this session — you MUST NOT:

1. Silently fall back to direct `WebSearch` / `WebFetch` / `Grep` / `Read` to do the research yourself.
2. Substitute another agent type (e.g. `general-purpose`) that has WebSearch/WebFetch directly. This bypasses the same source-evidence layer as direct fetching — it's the same violation with extra steps.

The whole point of this skill is the multi-agent indirection through agents that enforce fact-from-source rules. Direct-fetch and substitute-agents both produce fabrication-prone synthesis without those rules.

Phrases that signal you are about to break this rule and which you must NOT emit:
- "Skill konnte ... Sub-Scraper nicht spawnen, ich mache es direkt mit ..."
- "Spawning failed, falling back to direct WebFetch"
- "Let me just search the web directly instead"
- "Wie befürchtet ..." followed by direct tool calls
- "Wechsle auf general-purpose-Agenten mit direktem WebSearch/WebFetch-Zugang"
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
- "Entscheidung oder Überblick?" → steers depth allocation (1 deep vs. 3 standard)
- "Zeitraum der Quellen?" → steers whether to prioritize recent blog posts vs. established docs

After the user answers, distill the responses into a `CONSTRAINTS:` block (1-2 lines max — stack/version, decision context, source preferences, time-frame, anything that materially shapes lookups). **Keep the original topic unchanged.** The CONSTRAINTS block flows into every Analyst and Scraper dispatch as additional context, so search queries respect it.

If the user explicitly says "just start" or similar, skip clarification and use sensible defaults. Leave CONSTRAINTS empty or omit it. Continue to Step 1. Do not re-ask.

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
   Warum deep: [core decision driver / multiple competing answers / etc.]
   Angles: [angle 1] · [angle 2] · [angle 3]
2. [Sub-question] (standard) — N scrapers
   Warum standard: [regular sub-question, established sources expected]
   Angles: [angle 1] · [angle 2]
3. [Sub-question] (shallow) — N scrapers
   Warum shallow: [peripheral fact-check / known terrain]
   Angles: [angle 1]

Dispatch-Budget: N scrapers total (Sweet-Spot ~12, Ceiling ~15)
```

For `mode: knowledge`, the plan has exactly one synthetic sub-question — frame it as the verification of the top-3 claims you intend to make:

```
1. Verifikation der 3 Kernaussagen (standard) — 2 scrapers
   Warum standard: knowledge-mode-Pflicht-Faktencheck, nicht überspringbar
   Angles: Aussage 1 (X) · Aussage 2 (Y) · Aussage 3 (Z)

Dispatch-Budget: 2 scrapers total
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
2. If they only picked "Anpassen" without detail, ask **one** targeted follow-up: "Was soll geändert werden? (Sub-Frage, depth, Scraper-Anzahl, mode, oder einzelne Angles)" — do NOT re-present the unchanged plan, that wastes a turn.
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

Before dispatching, create a per-run output directory under `/tmp/deep-research/<epoch-seconds>/` (e.g. `mkdir -p /tmp/deep-research/$(date +%s)`) and use that directory for OUTPUT_FILE paths. The per-run subdir prevents file collisions when the user runs `/deep-research` in two sessions simultaneously.

OUTPUT_FILE naming convention: `<run-dir>/sq{N}-{type}-{M}.md` where N=sub-question index, type=`web` or `codebase`, M=scraper index within that sub-question. Example: `/tmp/deep-research/1746619200/sq2-web-3.md` is the 3rd web scraper for sub-question 2. Adapt QUESTION, DEPTH, and CONSTRAINTS per scraper.

For knowledge mode: do NOT skip this step. Treat your top 3 intended claims as one synthetic sub-question and spawn at least 2 web scrapers to verify them. Do not synthesize before reading their files. Knowledge mode without verification scrapers is a bug — every claim still needs a source from `dr-scraper-web`, just like in web mode.

### Step 3: Read results and self-check

**Step 3a: Silent-failure pre-check (mandatory).** Before reading any files, run this Bash one-liner against your run directory to surface scrapers that returned `DONE|path` but wrote nothing or near-nothing:

```bash
find /tmp/deep-research/<run-dir> -name 'sq*.md' -size -200c
```

If anything comes back, that scraper silently failed (e.g. the dr-scraper-web parallel-tail-call burn pattern, where parallel WebSearch/WebFetch calls exhausted `maxTurns` before the final Write, or a future variant). Treat any sub-200-byte file as a `Missing file` trigger (see trigger #1 below) and respawn that scraper before reading the rest. Do NOT synthesize from a missing source.

**Step 3b: Read every scraper file** (under your run directory), grouped by sub-question:

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

Maximum 2 follow-up rounds total per sub-question. If a sub-question still triggers after both rounds, mark it under **Contradictions & Open Questions** in the final output instead of papering over the gap with `[interpretation]`.

### Step 4: Synthesize and present

Synthesize findings across the scraper files by theme, not by sub-question and not by scraper.

Present in chat using the structure from `references/output-format.md`. **Every Kernpunkt and every Finding-statement must end with a `[^N]` inline citation** pointing to the numbered Sources section. Build the Sources list from the actual URLs in the scraper files. If a statement cannot be tied to a source from the files, either remove it or mark it `[interpretation]` and explain why. No claim ships without either a citation or an `[interpretation]` tag.

After presenting, ask: "Soll ich die Ergebnisse als Report speichern? (Datei wird unter ~/.claude/deep-research/ abgelegt)"

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

### Step 5: Metrics

End your final response with the METRICS comment so the stop hook can record the run.

The new fields after `follow_up_needed` are for compliance tracking — they let us measure whether the depth corridor and citation rules are actually followed across many runs. Compute them from your own dispatch records and your final output:

- `scraper_count_per_subquestion`: list of `{depth, count}` — one entry per sub-question with the scraper count you dispatched for it
- `depth_corridor_violations`: integer count of sub-questions that broke the corridor (deep with <3 scrapers, shallow with >2, standard outside 2-4)
- `claims_with_citation`: integer count of factual statements ending with `[^N]` or `[interpretation]` in your final response
- `claims_total`: integer count of factual statements in your final response (denominator for compliance)
- `constraints_used`: boolean — did Step 0 produce a CONSTRAINTS block that was passed to scrapers?
- `knowledge_factcheck_done`: boolean — for `mode=knowledge`, did you spawn verification scrapers with web lookups? Use `null` for non-knowledge modes.
- `approval_gate_action`: one of `"skipped"` (skip-condition matched), `"approved"` (user picked "Ja, loslegen"), `"adjusted"` (user went through one or more "Anpassen" rounds before approving), or `"cancelled"` (user picked "Abbrechen" — in that case you should not be emitting METRICS at all, this value exists only to make the schema complete).

Template:

```
<!-- METRICS:{"topic":"...","mode":"...","scrapers":N,"scraper_errors":N,"sources_total":N,"sources_by_type":{"doc":N,"blog":N,"forum":N,"github":N,"code":N},"gaps_found":N,"self_check_passed":BOOL,"follow_up_needed":BOOL,"scraper_count_per_subquestion":[{"depth":"deep","count":4}],"depth_corridor_violations":0,"claims_with_citation":N,"claims_total":N,"constraints_used":BOOL,"knowledge_factcheck_done":BOOL_OR_NULL,"approval_gate_action":"approved"} -->
```

## Context window protection

| Level | What you see | Max total |
|-------|-------------|-----------|
| Scraper return values | DONE|path only | ~100 words |
| File reads | 600 words x ~12 files max | ~7,200 words |

Scrapers return only `DONE|{path}`. The orchestrator reads files on demand. Each scraper file is capped at ~600 words; for a typical 4-sub-question / 3-scraper-each run that's ~12 files.

## Error handling

Read `references/error-handling.md` for failures, vague questions, and quality issues.

## Self-verification

Before finishing, check three things:

1. Does the response end with the METRICS comment?
2. Does every Kernpunkt and every Finding-statement carry a `[^N]` citation or an `[interpretation]` tag?
3. Does the Sources section contain a numbered entry for every `[^N]` used above?

If any check fails, re-read the scraper files and fix the gaps before sending. A claim without a source is a bug, not an output.

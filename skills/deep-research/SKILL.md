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
2. Spawn sub-agents with `model: "sonnet"` and an explicit depth level, because without these they inherit your model (expensive) and default to shallow searches (poor results).
3. Copy every source URL from sub-agent outputs into your final Sources section, because the user needs them to verify claims.

## Forbidden: direct-fetch fallback

If spawning a `deep-research:dr-analyst` (or `dr-scraper-web` / `dr-scraper-codebase`) subagent fails for ANY reason — permission denied, subagent type not found, plugin error, prior failed attempt in this session — you MUST NOT silently fall back to direct `WebSearch` / `WebFetch` / `Grep` / `Read` to do the research yourself. The whole point of this skill is the multi-agent indirection. Direct-fetch produces fabrication-prone synthesis without the source-evidence layer.

Phrases that signal you are about to break this rule and which you must NOT emit:
- "Skill konnte ... Sub-Scraper nicht spawnen, ich mache es direkt mit ..."
- "Spawning failed, falling back to direct WebFetch"
- "Let me just search the web directly instead"
- "Wie befürchtet ..." followed by direct tool calls

If subagent spawning fails:

1. State the failure to the user verbatim, including the exact error message you received from the `Agent` tool (or the reason "I expected this to fail" if you skipped trying).
2. Suggest the user grant the permission with the exact line they need: `Agent(deep-research:dr-analyst)`, `Agent(deep-research:dr-scraper-web)`, `Agent(deep-research:dr-scraper-codebase)` in `.claude/settings.local.json`.
3. ABORT the skill. Do not run direct lookups, do not synthesize from training data, do not write a METRICS comment.

There is no fallback mode. Either subagents work, or the skill aborts cleanly.

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
- Knowledge: foundation comes from training data, but **MUST be fact-checked** — spawn 1 fact-check analyst with 2-3 web lookups verifying the top-3 claims before synthesis. No claim ships without a source.
- Mixed: requires both web and codebase

Break the topic into 2-4 sub-questions. Assign each a depth level:
- `deep`: core question (typically 1)
- `standard`: regular sub-questions (1-2)
- `shallow`: peripheral questions (0-2)

Present the plan:

```
Forschungsplan: "[Topic]"
Modus: [Web / Codebase / Knowledge / Mixed]

1. [Sub-question] (deep)
2. [Sub-question] (standard)
3. [Sub-question] (shallow)
```

### Step 2: Dispatch sub-agents

Launch all sub-agents in parallel. Each sub-agent writes its findings to a file in `/tmp/deep-research/` and returns the file path. This ensures URLs survive context compaction. Files are auto-cleaned by the OS on reboot.

Use this pattern for each sub-agent:

<example>
Agent(
  subagent_type: "deep-research:dr-analyst",
  model: "sonnet",
  prompt: "Research the question below. Follow your agent instructions for lookup count, depth handling, file format, and return value.

QUESTION: What pricing models do existing price elasticity tools use?
MODE: web
DEPTH: standard
CONSTRAINTS: Mid-market SaaS, US/EU only, last 24 months
OUTPUT_FILE: /tmp/deep-research/analyst-1.md"
)
</example>

The full process and output format live in the agent body (`agents/dr-analyst.md`) and in the scraper agent bodies (`agents/dr-scraper-web.md`, `agents/dr-scraper-codebase.md`). Do not duplicate them in the spawn prompt — the subagent_type loads them automatically.

Before dispatching, create the output directory: `mkdir -p /tmp/deep-research`

Number the OUTPUT_FILE for each sub-agent (analyst-1.md, analyst-2.md, etc.). Adapt the QUESTION, MODE, and DEPTH fields per sub-question.

For knowledge mode: do NOT skip this step. Spawn exactly 1 fact-check analyst with `DEPTH: standard` whose QUESTION is "verify these claims with web sources: [list your top 3 intended claims verbatim]". Do not synthesize before reading its file. Knowledge mode without a fact-check spawn is a bug — every claim still needs a source from `dr-scraper-web` lookups, just like in web mode.

### Step 3: Read results and self-check

After all sub-agents complete, read each file they wrote:

```
Read /tmp/deep-research/analyst-1.md
Read /tmp/deep-research/analyst-2.md
...
```

Apply these **hard triggers** — if any fires for a sub-question, spawn one follow-up analyst targeting that sub-question:

1. **Missing file** — `analyst-N.md` doesn't exist or is empty (scraper crash chain).
2. **Source famine** — sub-question has fewer than 3 sources total in its file.
3. **Source monoculture** — sub-question has only blog/forum sources and zero doc/github/code. Spawn the follow-up with a query biased toward authoritative sources.
4. **Insufficient data marker** — analyst report contains any of these phrases (case-insensitive substring match): `insufficient data`, `from memory`, `from training memory`, `from training data`, `training data through`, `training cutoff`, `memory cutoff`, `from prior knowledge`, `based on memory`, `I recall`, `as I recall`, `verify against`, or has fewer than 3 source-anchored facts in its Findings section. Sonnet's honest-disclosure reflex sometimes adds these notes even after `dr-scraper-web` returns; treat any match as evidence that the run mixed scraper output with memory and dispatch a follow-up.
5. **Fabrication smell** — split into two mechanical sub-checks. If either fires, treat the analyst's run as invalid: discard it, then dispatch a follow-up analyst AND require the follow-up to spawn at least one `dr-scraper-web` subagent. Do not synthesize from the suspect file.

   - **5a. Stats/Sources mismatch** — the Stats line claims `N lookups` with N>=1, but: the Sources section has zero URLs, OR the count of distinct URLs in Sources is less than `N`, OR every URL in Sources is a bare domain root (e.g. `https://hex.pm/`, `https://github.com/`) without a deep path.
   - **5b. No fetch evidence in content** — the file's Findings + Sources together contain not a single URL with at least one of these concrete markers: a path segment matching `/issues/<digits>`, `/pull/<digits>`, `/releases/tag/`, `/commit/<hash>`, a date stamp in the path (`/YYYY/MM/` or `-YYYY-MM-DD-`), a query string with `?v=` or `?id=`, a fragment anchor (`#section`), OR the Findings text contains zero quoted strings (no `"..."`, no `'...'`) and zero version numbers (no `v?\d+\.\d+(\.\d+)?`). A run with no quote, no date, no version, no deep URL path is indistinguishable from a memory dump.

Skip Step 3 entirely if no trigger fires. Continue to Step 4.

Maximum 2 follow-up rounds total. If a sub-question still triggers after both rounds, mark it under **Contradictions & Open Questions** in the final output instead of papering over the gap with `[interpretation]`.

### Step 4: Synthesize and present

Synthesize findings across the files by theme, not by agent.

Present in chat using the structure from `references/output-format.md`. **Every Kernpunkt and every Finding-statement must end with a `[^N]` inline citation** pointing to the numbered Sources section. Build the Sources list from the actual URLs in the analyst files. If a statement cannot be tied to a source from the files, either remove it or mark it `[interpretation]` and explain why. No claim ships without either a citation or an `[interpretation]` tag.

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

- `lookup_count_per_analyst`: list of `{depth, count}` — one entry per analyst you dispatched
- `depth_corridor_violations`: integer count of analysts that broke the corridor (deep with <3 lookups, shallow with >2, standard outside 2-4)
- `claims_with_citation`: integer count of factual statements ending with `[^N]` or `[interpretation]` in your final response
- `claims_total`: integer count of factual statements in your final response (denominator for compliance)
- `constraints_used`: boolean — did Step 0 produce a CONSTRAINTS block that was passed to analysts?
- `knowledge_factcheck_done`: boolean — for `mode=knowledge`, did you spawn the fact-check analyst with web lookups? Use `null` for non-knowledge modes.

Template:

```
<!-- METRICS:{"topic":"...","mode":"...","analysts":N,"scrapers":N,"scraper_errors":N,"sources_total":N,"sources_by_type":{"doc":N,"blog":N,"forum":N,"github":N,"code":N},"gaps_found":N,"self_check_passed":BOOL,"follow_up_needed":BOOL,"lookup_count_per_analyst":[{"depth":"deep","count":4}],"depth_corridor_violations":0,"claims_with_citation":N,"claims_total":N,"constraints_used":BOOL,"knowledge_factcheck_done":BOOL_OR_NULL} -->
```

## Context window protection

| Level | What you see | Max total |
|-------|-------------|-----------|
| Sub-agent outputs | DONE|path only | ~100 words |
| File reads | 1000 words x 4 max | ~4,000 words |
| Lookup outputs | Nothing (consumed by sub-agents) | 0 words |

Sub-agents return only `DONE|{path}`. The orchestrator reads files on demand.

## Error handling

Read `references/error-handling.md` for failures, vague questions, and quality issues.

## Self-verification

Before finishing, check three things:

1. Does the response end with the METRICS comment?
2. Does every Kernpunkt and every Finding-statement carry a `[^N]` citation or an `[interpretation]` tag?
3. Does the Sources section contain a numbered entry for every `[^N]` used above?

If any check fails, re-read the analyst files and fix the gaps before sending. A claim without a source is a bug, not an output.

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

After the user answers, incorporate the responses into the topic and continue to Step 1. Do not re-ask.

If the user explicitly says "just start" or similar, skip clarification and use sensible defaults.

### Step 1: Plan

Parse the topic and detect mode:
- Web: external information needed
- Codebase: topic relates to a project in the working directory
- Knowledge: can be answered from training data (skip to Step 4)
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
OUTPUT_FILE: /tmp/deep-research/analyst-1.md"
)
</example>

The full process and output format live in the agent body (`agents/dr-analyst.md`) and in the scraper agent bodies (`agents/dr-scraper-web.md`, `agents/dr-scraper-codebase.md`). Do not duplicate them in the spawn prompt — the subagent_type loads them automatically.

Before dispatching, create the output directory: `mkdir -p /tmp/deep-research`

Number the OUTPUT_FILE for each sub-agent (analyst-1.md, analyst-2.md, etc.). Adapt the QUESTION, MODE, and DEPTH fields per sub-question.

For knowledge mode: skip this step, synthesize directly.

### Step 3: Read results and self-check

After all sub-agents complete, read each file they wrote:

```
Read /tmp/deep-research/analyst-1.md
Read /tmp/deep-research/analyst-2.md
...
```

Review the contents:
- Are sub-questions adequately covered?
- Are sources diverse?
- Are there findings without URLs?

If significant gaps remain, spawn 1-2 follow-up sub-agents. Maximum 2 follow-up rounds.

### Step 4: Synthesize and present

Synthesize findings across the files by theme, not by agent.

Present in chat using the structure from `references/output-format.md`. The Sources section at the end must list the actual URLs from the analyst files. Since you read the files directly, these URLs are in your context.

After presenting, ask: "Soll ich die Ergebnisse als Report speichern? (Datei wird unter ~/.claude/deep-research/ abgelegt)"

If yes, write to `~/.claude/deep-research/YYYY-MM-DD-<topic-slug>.md`.

### Step 5: Metrics

End your final response with:

`<!-- METRICS:{"topic":"...","mode":"...","analysts":N,"scrapers":N,"scraper_errors":N,"sources_total":N,"sources_by_type":{"doc":N,"blog":N,"forum":N,"github":N,"code":N},"gaps_found":N,"self_check_passed":BOOL,"follow_up_needed":BOOL} -->`

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

Before finishing, check: Does my response include a Sources section with URLs? Does it end with the METRICS comment? If either is missing, read the analyst files again and add the missing URLs.

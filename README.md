# Deep Research (cortex-dr fork)

A modular [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for deep research across web, codebase, and knowledge domains. Uses Sonnet for sub-agents and lookups; the orchestrator runs on the session model.

Cortex fork of [phyr97/deep-research](https://github.com/phyr97/deep-research). Tracks upstream; diverges with Exa-first scrapers, a batch verifier, a mandatory verification stage, and a curl link gate.

## Features

- Multi-mode research: web, codebase, knowledge synthesis, or mixed
- Tiered cost control: `lite` (default) / `standard` / `thorough`, plus `--fast` for explicit speed runs
- Depth-per-question: orchestrator assigns shallow/standard/deep per sub-question, corridor depends on tier
- Exa-first scrapers: Exa MCP for discovery/reading, WebSearch/WebFetch fallback, Reddit MCP for community sources
- **Mandatory verification**: central claims go through a batched escalation ladder (~10 claims per `dr-verifier` agent, contested/important claims get a 2nd/3rd batched re-check, unresolved contradictions are thrown out). Skippable only via explicit flag (`--fast` / `--no-verify`) or user instruction — never by in-run judgment
- **Link gate**: one curl sweep over every Sources URL (HEAD, GET retry), plus up to 5 Playwright spot-renders of load-bearing citations
- Source discipline: every finding must carry a URL or file path; fabrication-smell triggers discard memory-dump scraper output
- Metrics: every run appends a flat, schema-versioned record to `~/.claude/deep-research/metrics.jsonl`; the Stop hook normalizes drifted records
- Optional report export to `~/.claude/deep-research/`

## Installation

```bash
claude plugin marketplace add Mohamed-Alaboudi/deep-research
claude plugin install deep-research@cortex-dr
```

Manual (development): `claude --plugin-dir /path/to/deep-research`

### Agent permissions

A `PreToolUse` hook auto-approves `Agent(deep-research:...)` spawns, so most users need no setup. If your environment disables plugin hooks, allow in `settings.json`:

```json
{
  "permissions": {
    "allow": [
      "WebSearch",
      "WebFetch",
      "Agent(deep-research:dr-scraper-web)",
      "Agent(deep-research:dr-scraper-codebase)",
      "Agent(deep-research:dr-verifier)"
    ]
  }
}
```

Background: Claude Code has known issues with `bypassPermissions` for subagents ([#29110](https://github.com/anthropics/claude-code/issues/29110), [#24073](https://github.com/anthropics/claude-code/issues/24073)). The flat orchestrator → scraper architecture sidesteps them by avoiding nested `Agent` calls.

## Usage

```bash
# Basic research (lite tier: cheap verify, wide-and-shallow plan allowed)
/dr "Caching strategies for Phoenix applications"

# Thorough, full escalation ladder
/dr --tier thorough "Postgres partitioning strategies for multi-tenant SaaS"

# Force a mode
/dr --mode codebase "Map all GenServer processes in this project"

# Explicit speed run: no verification, curl-only link check (recorded in metrics)
/dr --fast "Quick survey of Rust HTTP clients"
```

## Architecture

```
Orchestrator (Skill)
  │
  ├── Plan + approval gate (dispatch budget, per-sub-question rationale)
  ├── For each sub-question:                    [parallel]
  │     ├── dr-scraper-web (Sonnet)       ──→ writes facts file
  │     └── dr-scraper-codebase (Sonnet)  ──→ writes facts file
  ├── Self-check ──→ fabrication triggers, follow-up scrapers (max 2 rounds)
  ├── Verify     ──→ dr-verifier batches (~10 claims/agent), escalation ladder
  ├── Link gate  ──→ curl sweep all Sources + ≤5 Playwright spot-renders
  └── Synthesize ──→ themes, [^N] citations, Verification section, metrics
```

Flat dispatch (orchestrator → sub-agents, one hop). Agent `.md` files carry frontmatter (model, tools, permissions) plus the system prompt; the orchestrator passes only question, depth, constraints, and output path.

## Plugin structure

```
deep-research/
  .claude-plugin/
    plugin.json                  # Plugin manifest
    marketplace.json             # cortex-dr marketplace entry
  skills/
    dr/
      SKILL.md                   # Orchestrator workflow
      references/
        verification.md          # Escalation-ladder detail
        metrics.md               # METRICS v4 field glossary
        output-format.md         # Report structure + citation rule
        research-modes.md        # Modes + depth levels
        error-handling.md        # Spawn/verifier/link-gate failures
  commands/
    dr.md                        # /dr slash command
  agents/
    dr-scraper-web.md            # Web scraper (Sonnet, Exa-first)
    dr-scraper-codebase.md       # Codebase scraper (Sonnet)
    dr-verifier.md               # Batch claim verifier (Sonnet)
  hooks/
    hooks.json                   # PreToolUse auto-approve + Stop metrics
  scripts/
    auto-approve-subagents.sh    # PreToolUse hook
    save-metrics.sh              # Stop hook: extract + normalize metrics
```

## License

MIT

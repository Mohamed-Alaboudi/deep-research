# Deep Research for Claude Code (`/dr` + `/spinner`)

A self-installing [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin with two commands:

- **`/dr`** — **deep, multi-source, fact-checked research**: it fans out scraper agents, has an Opus agent adversarially try to *refute* every central claim, link-checks the sources, and hands you a cited report.
- **`/spinner`** — an **uncorrelated second opinion** on any decision: it spawns a fresh Opus sub-agent that knows only the decision (not your reasoning), reads the code itself, finds what you'd have missed, and commits to the best option. No API key needed.

Cortex fork of [phyr97/deep-research](https://github.com/phyr97/deep-research), extended with `/spinner`.

---

## Easiest setup: let Claude do it

Open this folder in **Claude Code** and say:

> **"Set up this repo for me — read CLAUDE.md and walk me through it."**

Claude will read [`CLAUDE.md`](./CLAUDE.md), install the plugin, and interview you for the **one** thing it needs: your **Exa API key** (free at [exa.ai](https://exa.ai)). That's it.

> Don't have it on disk yet? In Claude Code:
> ```
> git clone https://github.com/Mohamed-Alaboudi/deep-research
> ```
> then open the folder and say the line above.

## Manual setup (if you'd rather)

```bash
# 1. Install the plugin (from GitHub)
claude plugin marketplace add Mohamed-Alaboudi/deep-research
claude plugin install deep-research@cortex-dr

# 2. Add the Exa MCP with YOUR key — note: x-api-key HEADER, not an env var
claude mcp add-json exa -s user '{
  "type": "http",
  "url": "https://mcp.exa.ai/mcp",
  "headers": { "x-api-key": "YOUR_EXA_KEY" }
}'

# 3. Restart Claude Code, then smoke-test:
#    /dr --tier lite "latest Node.js LTS version and release date"
```

> **The Exa key must be a header.** The hosted Exa MCP ignores an `env` key and rate-limits (429) keyless. This trips everyone up once.

## Using it

```bash
# Research
/dr "Caching strategies for Phoenix applications"          # default lite tier
/dr --tier thorough "Postgres partitioning for multi-tenant SaaS"   # full verification ladder
/dr --mode codebase "Map all GenServer processes in this project"   # research this repo
/dr --fast "Quick survey of Rust HTTP clients"             # skip verification (quick survey)
/dr --reverify <run_id>                                    # finish an interrupted run, no re-scrape

# Second opinion on a decision
/spinner "Redis vs Postgres LISTEN/NOTIFY for our job queue — which?"   # fresh Opus reviewer
/spinner                                                   # uses options laid out earlier in the chat
```

`/dr` reports save to `~/.claude/deep-research/`; per-run metrics append to `~/.claude/deep-research/metrics.jsonl`. `/spinner` returns a Decision + missed edge cases + runner-up + confidence — it never auto-executes.

## What makes it trustworthy

- **Source discipline** — every finding carries a URL or file path; memory-dump answers are discarded.
- **Mandatory adversarial verification** — central claims go through a batched Opus verifier that tries to refute them. Round-1 verification is a hard gate, skippable only with the explicit `--fast` / `--no-verify` flags.
- **Link gate** — every cited URL is curl-checked, and load-bearing pages are spot-rendered.
- **No silent fallback** — if the research agents can't spawn, `/dr` aborts cleanly instead of quietly doing weaker research. A failure means "fix the install," not "half-works."

Full architecture and internals: [`PLUGIN.md`](./PLUGIN.md). Agent-oriented install contract: [`AGENTS.md`](./AGENTS.md). License: MIT.

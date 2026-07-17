# AGENTS.md

This repository is a dual-runtime **Claude Code and Codex plugin**. Claude exposes **`/dr`** and **`/spinner`**. Codex exposes **`$dr`** through `.codex-plugin/plugin.json` and `codex/skills/dr/`; Codex's global `$spinner` remains separate. Both deep-research paths use bounded scraper fan-out, adversarial verification, link checking, and cited durable reports.

**If you are an AI agent asked to set this up:** the full, ordered install runbook lives in **[`CLAUDE.md`](./CLAUDE.md)** — follow it verbatim. It is written tool-agnostic; everything in it applies to you. The short version:

1. Identify the runtime: `claude --version` or `codex --version`.
2. Claude: `claude plugin marketplace add Mohamed-Alaboudi/deep-research && claude plugin install deep-research@cortex-dr`. Codex: `codex plugin marketplace add https://github.com/Mohamed-Alaboudi/deep-research.git` then `codex plugin add deep-research@cortex-dr`.
3. **Set up the Exa MCP with the user's own API key, passed as an `x-api-key` header** (env var is ignored; keyless 429s). Free key at https://exa.ai. This is the only step needing user input — and it's only for `/dr`; `/spinner` already works after step 2.
4. Claude uses the bundled subagent hook. Codex uses native collaboration tools and the contracts under `codex/skills/dr/references/`; do not attempt to load Claude hooks in Codex.
5. Smoke test Claude with `/dr --tier lite --yes "..."`; smoke test Codex with `$dr --tier lite --yes "..."`.

Never commit an API key. Never make `/dr` fall back to raw `WebSearch`/`WebFetch` to paper over a failed install — fix the install. Architecture and rationale: [`PLUGIN.md`](./PLUGIN.md).

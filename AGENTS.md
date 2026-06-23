# AGENTS.md

This repository is a **Claude Code plugin** with two commands: **`/dr`** (deep research — fan-out scrapers → adversarial Opus verifier → link-checked, cited report) and **`/spinner`** (an uncorrelated second opinion on a decision — one fresh Opus sub-agent that reads the code and picks the best option). `/spinner` needs no API key; only `/dr`'s web research does.

**If you are an AI agent asked to set this up:** the full, ordered install runbook lives in **[`CLAUDE.md`](./CLAUDE.md)** — follow it verbatim. It is written tool-agnostic; everything in it applies to you. The short version:

1. Confirm the user is on **Claude Code** (`claude --version`). This plugin runs nowhere else.
2. Install the plugin — from GitHub `claude plugin marketplace add Mohamed-Alaboudi/deep-research && claude plugin install deep-research@cortex-dr`, or offline from this local folder (`claude plugin marketplace add ./deep-research && claude plugin install deep-research@cortex-dr`). This installs **both** `/dr` and `/spinner`.
3. **Set up the Exa MCP with the user's own API key, passed as an `x-api-key` header** (env var is ignored; keyless 429s). Free key at https://exa.ai. This is the only step needing user input — and it's only for `/dr`; `/spinner` already works after step 2.
4. Confirm the bundled `PreToolUse` auto-approve hook is active (or add the `Agent(deep-research:*)` allows to `settings.json`).
5. Smoke test: `/spinner "<a small decision>"` (no key needed), then `/dr --tier lite "..."`.

Never commit an API key. Never make `/dr` fall back to raw `WebSearch`/`WebFetch` to paper over a failed install — fix the install. Architecture and rationale: [`PLUGIN.md`](./PLUGIN.md).

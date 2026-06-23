# CLAUDE.md — Self-install runbook for the deep-research plugin

**You are an AI coding agent (Claude Code) and the user has just handed you this repository to set up.**
Your job is to install this `/dr` deep-research plugin into *their* Claude Code, ask them for the one thing you cannot infer (their Exa API key), and verify it works. Then stop.

Do this conversationally — explain each step in one line before you run it, and never print or echo a real API key back into the chat.

---

## What this repo is

A Claude Code **plugin** (not a standalone skill). Installing it adds **two** commands:

**`/dr`** — deep, multi-source, **adversarially fact-checked** research:

- An **orchestrator** skill (`skills/dr/SKILL.md`) plans the research and fans out subagents — it never searches directly.
- **Scraper** subagents (`agents/dr-scraper-web.md`, `agents/dr-scraper-codebase.md`, run on Sonnet) gather facts, each tagged with a source URL or file path.
- A **verifier** subagent (`agents/dr-verifier.md`, runs on **Opus** — the one place the extra capability earns its cost) adversarially tries to *refute* central claims in batches. Round-1 verification is a hard gate; only `--fast` / `--no-verify` skip it.
- A **link gate** curls every cited URL and spot-renders up to 5 load-bearing pages.
- Hooks (`hooks/hooks.json`) auto-approve the subagent spawns and record per-run metrics.

**`/spinner`** — an *uncorrelated second opinion* on a decision (`skills/spinner/SKILL.md`). It spawns one fresh sub-agent (on **Opus**) that knows only the decision — not the reasoning that led there — reads the code itself, hunts for what the anchored view missed, and commits to the best option. Use it at any fork worth pressure-testing. **It needs no API key** — it uses Claude's own tools; the deep-research path is an optional thing the sub-agent may choose.

Full design: see `PLUGIN.md` in this repo.

## The one hard dependency (for `/dr` only)

`/spinner` works the moment the plugin is installed — skip to Step 4. The dependency below is **only** for `/dr`'s web research.

**The scrapers call the Exa MCP** (`mcp__exa__web_search_exa` / `web_fetch_exa`). Without it they fall back to plain `WebSearch`/`WebFetch`, which is weaker and may be unavailable. **You must set up the Exa MCP with the user's own API key** — this is the only step that needs information from them.

A free Exa key works for light use. The hosted Exa MCP is keyless by default and **will 429 (rate-limit)** unless the key is passed as an `x-api-key` **header** — passing it as an env var is silently ignored. Get the header right or research will rate-limit.

---

## Install procedure — do these in order

### Step 1 — Confirm this is Claude Code

Run `claude --version`. If it errors / isn't found, tell the user this plugin only runs inside **Claude Code** (Anthropic's CLI) and link https://docs.claude.com/en/docs/claude-code — then stop; nothing else will work.

### Step 2 — Decide install method, then install the plugin

**Preferred (online, has the repo on GitHub) — install straight from the source, ignore the local copy:**

```bash
claude plugin marketplace add Mohamed-Alaboudi/deep-research
claude plugin install deep-research@cortex-dr
```

**Offline / wants to use this exact local copy** (this folder *is* a valid marketplace — it has `.claude-plugin/marketplace.json`):

```bash
# from the directory that CONTAINS this repo folder
claude plugin marketplace add ./deep-research
claude plugin install deep-research@cortex-dr
```

> If a `plugin`/`marketplace` subcommand isn't recognized, the user's Claude Code is too old — have them update (`claude update` or reinstall) and retry. Do not try to hand-wire the plugin into `settings.json`; the marketplace flow is the supported path.

Confirm it registered: `claude plugin list` should show `deep-research@cortex-dr`.

### Step 3 — Set up the Exa MCP (needs the user's key)

1. Ask the user for their Exa API key. If they don't have one, tell them: sign up free at **https://exa.ai**, create an API key, paste it back. **Do not proceed without it** — but you may continue and warn that `/dr` will run on the weaker `WebSearch`/`WebFetch` fallback until it's added.
2. Add the MCP with the key **as a header** (substitute their real key for `EXA_KEY`; run it so the key stays out of the transcript — don't echo it back):

   ```bash
   claude mcp add-json exa -s user '{
     "type": "http",
     "url": "https://mcp.exa.ai/mcp",
     "headers": { "x-api-key": "EXA_KEY" }
   }'
   ```

   - `-s user` makes Exa available in every project. Use `-s local` if they want it only in the current repo.
   - **The key MUST be in `headers.x-api-key`.** Putting it in an `env` block does nothing — the hosted server reads the header, and a keyless connection 429s.
3. Verify: `claude mcp list` should show `exa`, and after a Claude Code restart the tools `mcp__exa__web_search_exa` / `mcp__exa__web_fetch_exa` should be callable.

> Optional: a **Reddit MCP** enriches community-sourced research (`agents/dr-scraper-web.md` will use it if present). Skip unless the user asks — `/dr` works fine without it.

### Step 4 — Confirm the subagent auto-approve hook

The plugin ships a `PreToolUse` hook (`scripts/auto-approve-subagents.sh`) that auto-approves `Agent(deep-research:…)` spawns, so the user isn't prompted for every scraper. It's wired in `hooks/hooks.json` and installs with the plugin.

If the user's setup disables plugin hooks (or they get permission prompts for every scraper), have them add this to `settings.json`:

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

### Step 5 — Smoke test

Have the user **restart Claude Code** (so the plugin loads), then test both commands.

**`/spinner`** (works with no API key — test this first):

```
/spinner "Two ways to store config: a single JSON file vs one env var per setting. Which?"
```

Expected: it spawns one fresh Opus sub-agent, which returns a Decision / Edge cases / Runner-up / Confidence verdict. If you get that structure back, `/spinner` is live.

**`/dr`** (needs the Exa MCP from Step 3 to be at its best):

```
/dr --tier lite "What is the latest stable Node.js LTS version and its release date?"
```

Expected: a research plan + approval gate → a few scrapers → an Opus verifier pass → a short report with `[^N]` citations and a Sources list. If they see that, it's working.

**If `/dr` says it can't spawn `deep-research:dr-scraper-web`:** the plugin didn't install or hooks are blocked — recheck Steps 2 and 4. The skill is designed to **abort** rather than secretly do the research itself with raw web tools, so a clean failure here means "fix the install," not "it half-works."

---

## After install — how the user runs it

**Research (`/dr`):**

- `/dr "<question>"` — default `lite` tier (cheap verify, wide-and-shallow allowed).
- `/dr --tier thorough "<question>"` — full escalation-ladder verification.
- `/dr --mode codebase "<question>"` — research this repo instead of the web.
- `/dr --fast "<question>"` — skip verification (recorded in metrics). For quick surveys only.
- `/dr --reverify <run_id>` — finish verification of an interrupted run without re-scraping.

Reports save to `~/.claude/deep-research/`; raw fetches mirror to `~/.claude/deep-research/raw/<run_id>/`; per-run metrics append to `~/.claude/deep-research/metrics.jsonl`.

**Second opinion (`/spinner`):**

- `/spinner "<decision + the options>"` — pressure-test a choice with a fresh Opus sub-agent.
- `/spinner` (no args) — uses the options Claude laid out earlier in the conversation.

Returns a Decision + the edge cases the anchored view missed + a runner-up + confidence. It decides, it does **not** auto-execute — acting on the verdict is a separate step you ask for.

## Updating later

```bash
claude plugin marketplace update cortex-dr
claude plugin update deep-research@cortex-dr
```

(Or `git pull` this repo and re-`marketplace update` if installed from the local copy.)

## Do NOT

- **Do not** hard-code or commit an API key anywhere in this repo or in `settings.json` — the key goes only into the user's local MCP config via Step 3.
- **Do not** rewire the plugin by hand-editing `settings.json` plugin internals — use the `plugin install` flow.
- **Do not** "fix" a spawn failure by having `/dr` run `WebSearch`/`WebFetch` directly — that defeats the verification design (the SKILL.md forbids it). Fix the install instead.

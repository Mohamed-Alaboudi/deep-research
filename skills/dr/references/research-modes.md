# Research modes

## Web research
- Orchestrator dispatches scrapers via `subagent_type: "deep-research:dr-scraper-web"`
- Each scraper collects facts, URLs, snippets with source type tags for ONE narrow angle
- Each scraper receives a depth level (shallow/standard/deep) that controls search count and link-following
- Orchestrator clusters by theme across all scraper files in Step 7

## Codebase analysis
- Orchestrator dispatches scrapers via `subagent_type: "deep-research:dr-scraper-codebase"`
- Each scraper navigates code, extracts patterns, finds dependencies for one angle
- Codebase claims are not web-verifiable; they skip Step 5 and keep `medium` confidence

## Knowledge synthesis
- Foundation comes from the model's training data
- **MUST dispatch at least 2 web scrapers** to verify the top-3 claims before presenting
- Claims that survive fact-check get `[^N]` citations like all other modes
- Claims that fail fact-check or weren't verified must be removed or marked `[interpretation]`

## Mixed
- Orchestrator dispatches BOTH web and codebase scrapers per sub-question
- Allows direct comparison between local code and external best practices
- Only central claims with a URL source (not a file path) are verify-eligible

## Depth levels (per-scraper behavior)

The depth level controls how aggressively each scraper searches and follows links:

| Depth | Searches per scraper | Follow links | Typical use |
|-------|---------------------|-------------|-------------|
| shallow | 2 | 0 | Fact-checks, definitions, peripheral questions |
| standard | 3-4 | 1-2 | Regular research sub-questions |
| deep | 5-6 | up to 3 | Core question, needs thorough coverage |

Scraper counts per depth are tier-dependent — see the corridor table in SKILL.md Step 1 (standard/thorough: 2-4 sub-questions, deep ≥3 scrapers; lite/`--fast`: up to 8 sub-questions wide-and-shallow, deep ≥2).

## Verification (Step 5)

Central claims are verified by `dr-verifier` subagents in a **batched escalation ladder** (web/knowledge/mixed modes): Round 1 batches up to ~10 claims per agent; only important or contradicted claims get a 2nd/3rd batched re-check; unresolved contradictions are thrown out of the findings. Claim caps per tier: lite 5, standard 10, thorough 12. Verdicts are balanced (confirmed / uncertain / contradicted, no default-refute). Knowledge mode's mandatory fact-check is satisfied by this stage. Full detail: `references/verification.md`.

# Research modes

## Web research
- Sub-agents spawn web lookups via `subagent_type: "deep-research:dr-scraper-web"`
- Lookups collect facts, URLs, snippets with source type tags
- Sub-agents cluster and evaluate
- Each lookup receives a depth level (shallow/standard/deep) that controls search count and link-following

## Codebase analysis
- Sub-agents spawn codebase lookups via `subagent_type: "deep-research:dr-scraper-codebase"`
- Lookups navigate code, extract patterns, find dependencies
- Sub-agents build focused analysis of their area

## Knowledge synthesis
- Orchestrator synthesizes directly, no sub-agent dispatch
- Optionally spawn 1-2 web lookups for fact-checking specific claims

## Mixed
- Sub-agents may spawn BOTH web and codebase lookups
- Allows direct comparison between local code and external best practices

## Depth levels

The orchestrator assigns a depth level per sub-question. Sub-agents pass this to their web lookups.

| Depth | Searches | Follow links | Typical use |
|-------|---------|-------------|-------------|
| shallow | 2 | 0 | Fact-checks, definitions, peripheral questions |
| standard | 3-4 | 1-2 | Regular research sub-questions |
| deep | 5-6 | up to 3 | Core question, needs thorough coverage |

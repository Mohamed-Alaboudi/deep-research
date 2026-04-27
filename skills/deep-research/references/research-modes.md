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
- Foundation comes from Opus's training data
- **MUST spawn at least 1 fact-check analyst** with 2-3 web lookups to verify the top-3 claims before presenting
- Claims that survive fact-check get `[^N]` citations like all other modes
- Claims that fail fact-check or weren't verified must be removed or marked `[interpretation]`

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

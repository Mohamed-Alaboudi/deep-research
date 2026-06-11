# Output format

Present results in chat using this structure.

## Citation rule (applies to every section)

Every factual statement must end with one of:

- `[^N]` — citation pointing to a numbered Sources entry below. The number references a real URL or file path from the scraper files.
- `[interpretation]` — synthesis across multiple sources, not a direct fact. Use sparingly, only when combining several `[^N]` claims into a higher-order observation.

A statement without one of these tags is a bug. Either find the source, mark it `[interpretation]`, or remove the statement.

## Key Findings

4-7 key findings. Each one:

### N. [Key Finding Title]  ·  Confidence: high | medium | low
[2-4 sentences: what, why it matters, context.] [^N]

Every Key Finding ends with at least one citation. If the finding rests on multiple sources, list them: `[^1][^3]`.

Confidence comes from Step 5 verification (verdict + source tier + round agreement).
Findings that skipped verification (supporting/tangential, or codebase mode) default to `medium`.

## Executive Summary

3-5 sentences high-level summary of the entire research. Citations or `[interpretation]` tags as above.

## Findings

Organize by theme (not by scraper or sub-question). Each statement of fact ends with `[^N]`. Synthesis sentences combining multiple findings end with `[interpretation]` plus the source citations they rest on, e.g. `[interpretation, based on [^2][^4]]`.

## Contradictions & Open Questions

Areas where sources disagree or where the research could not reach a clear conclusion. Cite the conflicting sources: "Source A claims X [^2], source B claims Y [^5]."

## Verification

Only present when the verify stage ran (Step 5). Short lists, omit any that is empty:

- **Removed (unresolved contradiction):** claims removed from the findings, each with its counter-source. "Claim X — contradicted by [^N]."
- **Uncertain:** claims kept with low confidence and a one-line caveat.
- **Not verified:** central claims dropped by the claim cap, or claims whose verifier failed. State which.
- **Source unreachable:** claims whose only source failed the link gate (Step 6).

## Sources

Numbered list. Every `[^N]` above resolves here. Link-gate annotations (`[link: dead]`, `[link: content not located]`) append to the affected entry.

[^1]: [doc] Title — URL
[^2]: [blog] Title — URL
[^3]: [forum] Title — URL
[^4]: [github] Title — URL
[^5]: [code] File path (for codebase sources)

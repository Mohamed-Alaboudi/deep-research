# Output format

Present results in chat using this structure.

## Citation rule (applies to every section)

Every factual statement must end with one of:

- `[^N]` — citation pointing to a numbered Sources entry below. The number references a real URL or file path from the analyst files.
- `[interpretation]` — synthesis across multiple sources, not a direct fact. Use sparingly, only when combining several `[^N]` claims into a higher-order observation.

A statement without one of these tags is a bug. Either find the source, mark it `[interpretation]`, or remove the statement.

## Kernpunkte

4-7 key findings. Each one:

### N. [Key Finding Title]
[2-4 sentences: what, why it matters, context.] [^N]

Every Kernpunkt ends with at least one citation. If the finding rests on multiple sources, list them: `[^1][^3]`.

## Executive Summary

3-5 sentences high-level summary of the entire research. Citations or `[interpretation]` tags as above.

## Findings

Organize by theme (not by analyst). Each statement of fact ends with `[^N]`. Synthesis sentences combining multiple findings end with `[interpretation]` plus the source citations they rest on, e.g. `[interpretation, based on [^2][^4]]`.

## Contradictions & Open Questions

Areas where sources disagree or where the research could not reach a clear conclusion. Cite the conflicting sources: "Source A claims X [^2], source B claims Y [^5]."

## Sources

Numbered list. Every `[^N]` above resolves here.

[^1]: [doc] Title — URL
[^2]: [blog] Title — URL
[^3]: [forum] Title — URL
[^4]: [github] Title — URL
[^5]: [code] File path (for codebase sources)

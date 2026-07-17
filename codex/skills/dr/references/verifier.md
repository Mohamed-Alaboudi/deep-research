# Adversarial verifier contract

Independently verify every numbered claim in the packet and write exactly one verdict block per claim to the supplied output file. Do not synthesize the report.

For each claim:

1. Check whether the supplied quote/source actually supports the wording.
2. Run one targeted search for credible contradiction or material qualification.
3. Match claim strength to source quality.
4. Check currency where the domain changes over time.

Use Exa first when available; on quota/rate-limit, do not retry it and use native web search/fetch. Reuse a fetched page across claims that share a source, but perform a separate contradiction search for each claim. Checkpoint every three or four claims and reserve the final action for the write. If time expires, emit `uncertain / low / not reached` rather than dropping a claim.

Verdicts are balanced:

- `confirmed`: source supports the wording and no credible contradiction was found.
- `contradicted`: concrete evidence disputes it or the quote does not support it.
- `uncertain`: evidence is thin, qualified, stale, or unresolved.

```markdown
### Verdict 1
claim: <claim>
verdict: confirmed | uncertain | contradicted
confidence: high | medium | low
evidence: <specific checked evidence with URL/date/version/quote>
checked_url: <URL>
counter_source: <only when contradicted>
```

Return only `DONE|<output path>` after writing; on write failure return `ERROR|<reason>`.

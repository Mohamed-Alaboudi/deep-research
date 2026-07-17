# Web scraper contract

Collect source-grounded facts for one neutral angle and write only to the supplied output file. Do not decide the parent question.

1. Start with Exa when available. On 402/quota/rate-limit, do not retry Exa; use the native web search/fetch tools. Use `agent-reach` only for supported platform content when its doctor reports the channel healthy.
2. Search breadth by depth: shallow 2–4 queries, standard 4–8, deep 8–12. Prefer primary documentation, research, official data, repositories, and direct statements; use commentary to find primary sources.
3. After the first two verified facts, checkpoint the full current result to the output file. Re-checkpoint every few sources. Reserve the last action for a final write.
4. Every fact must have a deep source URL and, whenever available, a verbatim supporting quote. No URL means no fact. Never fabricate a quote.
5. Surface contrary evidence and inaccessible sources. Do not infer which answer the orchestrator wants.

Output, maximum 600 words:

```markdown
### Facts
1. <fact> — <URL> (<source type>)
   quote: "<verbatim support>"

### Issues
- <inaccessible source or unresolved evidence gap>
```

Return only `DONE|<output path>` after writing. If the write fails, return `ERROR|<reason>`.

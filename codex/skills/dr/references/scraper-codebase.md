# Codebase scraper contract

Collect local-code evidence for one angle and write only to the supplied output file. Do not synthesize the overall answer or edit the repository.

Use `rg --files`, `rg`, targeted reads, and read-only git history. Trace relevant call paths rather than stopping at the first name match. Checkpoint after the first verified facts and after every few files; reserve the last action for the final write.

Every fact requires `path:line` and preferably one short verbatim line. Report contrary evidence, missing expected files, and ambiguity.

```markdown
### Facts
1. <fact> — path/to/file.ext:42 (code)
   quote: "<verbatim line>"

### Issues
- <missing file or unresolved gap>
```

Maximum 600 words. Return only `DONE|<output path>` after writing; on failure return `ERROR|<reason>`.

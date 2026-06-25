# Output format

Two outputs, deliberately different:

- **The chat report** (what the user reads) — decision-oriented prose. **No `[^N]` tags, no Sources section.** Lead with what matters, what to weigh, what to do.
- **The saved `.md` report** (Step 7, only if the user says yes) — the SAME body, but with `[^N]` citations restored on factual claims and a full Sources section appended, for traceability and `--reverify`.

Citations never disappear from the *pipeline*: scrapers still tag every fact with a source, the verifier still checks claims against those sources, and the link gate (Step 6) still curls them. That machinery runs on the scraper/verifier files and the **saved** report — it does not depend on the chat output showing `[^N]`. Verification quality is unchanged; only the *presented* surface is clean.

---

## Chat report structure

Present results in chat using this order. **Do not** print `[^N]` tags or a Sources list in chat. Write confident, readable prose — the verification already happened.

### Bottom Line

2-4 sentences. The direct answer to what the user asked. If the research has one dominant takeaway, it goes here. No citations.

### What You Need to Consider

The risks, trade-offs, caveats, constraints, and "it depends" factors that a thoughtful person acting on this should weigh. This is the heart of the report — the user explicitly wants this over a wall of facts.

- 3-7 bullets, each a single sharp consideration.
- Surface genuine tension here: if sources disagreed or a finding rests on thin/single-source evidence, say so in plain language ("Reporting on X is mixed — some sources say A, others B; treat as unsettled"). This replaces the old "Contradictions & Open Questions" section — fold those directly into the considerations.
- Flag low-confidence items explicitly: lead the bullet with **(low confidence)** when the verifier couldn't firm it up. Confidence still comes from Step 5 (verdict + source tier + round agreement); you just express it in words, not a label column.

### Recommended Actions

Concrete, ordered, do-this-next steps that follow from the findings. Each is an imperative the user can act on, not a restatement of a fact.

1. Action — one line, optionally a clause on why / what it unblocks.
2. ...

Keep this tight (typically 3-6). If the research is purely informational and there's genuinely nothing to *do*, replace this section with a one-line **No actions required — this is informational.** rather than padding it.

### Supporting Detail

The themed findings, for the reader who wants the substance behind the Bottom Line. Organize **by theme**, not by scraper or sub-question. Still no `[^N]` in chat — write it as prose. Keep it skimmable (short paragraphs or bullets under 2-4 thematic subheads). This is where the facts live; the three sections above are the distillation.

### (footer line — trust signal)

End the chat report with ONE small italic line so the user knows the rigor happened even though the citations aren't shown, e.g.:

*Based on N sources; M central claims adversarially verified. Ask for sources or `--reverify` if you want the receipts.*

If verification was skipped (`--fast` / `--no-verify` / codebase mode), say so honestly instead: *Fast mode — claims not independently verified.* This single line replaces the old visible Verification + Sources apparatus as the chat-level trust signal.

*(That's the end of the chat report. No Sources block in chat.)*

---

## Saved report structure (Step 7 — only if the user opts to save)

When the user says yes to saving, write the SAME four sections, then restore traceability for the file:

- Re-attach `[^N]` to every factual statement in **Bottom Line**, **What You Need to Consider**, and **Supporting Detail** (synthesis sentences get `[interpretation]` or `[interpretation, based on [^2][^4]]`). Recommended Actions are imperatives, not facts — they don't need citations, but may carry one if an action is grounded in a specific source.
- Append the **Sources** section below.

A factual statement in the *saved* file without `[^N]` or `[interpretation]` is a bug — same rule as before, applied to the file rather than the chat.

### Verification (saved report only)

Only when the verify stage ran (Step 5). Short lists, omit any that is empty:

- **Removed (unresolved contradiction):** claims removed from the findings, each with its counter-source.
- **Uncertain:** claims kept with low confidence and a one-line caveat.
- **Not verified:** central claims dropped by the claim cap, or claims whose verifier failed.
- **Source unreachable:** claims whose only source failed the link gate (Step 6).

### Sources (saved report only)

Numbered list. Every `[^N]` in the saved body resolves here. Link-gate annotations (`[link: dead]`, `[link: content not located]`) append to the affected entry.

[^1]: [doc] Title — URL
[^2]: [blog] Title — URL
[^3]: [forum] Title — URL
[^4]: [github] Title — URL
[^5]: [code] File path (for codebase sources)

---

## Where the old section names now live

Other steps in `SKILL.md` and the reference files still name the pre-redesign sections. Map them as follows — the *behavior* is unchanged, only the destination moves:

| Old named section | Chat report | Saved report |
|---|---|---|
| **Key Finding** (a central claim) | folded into Bottom Line / Supporting Detail | same, with `[^N]` |
| **Contradictions & Open Questions** | a plain-language bullet under **What You Need to Consider** | a bullet under Considerations (cited) |
| **Verification** (removed / uncertain / not verified / source unreachable) | not shown as its own section; if it changes the answer, reflect it in **What You Need to Consider** (e.g. "(low confidence) …") | the **Verification** section above |
| **Sources** | not shown | the **Sources** section above |

So when a step says "list X under the Verification section" or "surface under Contradictions & Open Questions," it means: put it in the **saved** report's Verification section, and — if it materially affects the answer — also voice it in the chat's **What You Need to Consider**. Nothing gets silently dropped; it just isn't a wall of citations in chat.

# Error handling

## Scraper spawn failures

If `Agent(deep-research:dr-scraper-web)` or `Agent(deep-research:dr-scraper-codebase)` returns an error (permission denied, subagent type not found, plugin error):

1. State the failure to the user verbatim, including the exact error message from the `Agent` tool (or "I expected this to fail" if you skipped trying).
2. Show the user the project-local settings path using the current working directory:

   ```
   {cwd}/.claude/settings.local.json
   ```

   Snippet to add to the `permissions.allow` array (create the file if missing):

   ```json
   "Agent(deep-research:dr-scraper-web)",
   "Agent(deep-research:dr-scraper-codebase)"
   ```

3. Offer to write the change yourself: ask "Soll ich die Permissions in `{cwd}/.claude/settings.local.json` ergaenzen?" If yes, read the file (or create it), merge the two `Agent(...)` entries into the existing `permissions.allow` array without removing other entries, and write it back. Ask the user to re-run the skill — settings reload requires a fresh tool-permission check.
4. ABORT the skill. Do not run direct lookups, do not synthesize from training data, do not write a METRICS comment.

The plugin's `PreToolUse` hook normally auto-approves these spawns. Permission errors usually mean the hook is disabled, the plugin is installed in a non-standard path, or the user explicitly denied the spawn.

## WebFetch failures inside a scraper

- Scraper retries once, then marks "source inaccessible" and continues with the remaining searches.
- Orchestrator: if a scraper file is thin or empty, dispatch a follow-up scraper with rephrased queries; surface persistent gaps in "Contradictions & Open Questions".

## Vague research questions

If the topic is too vague for meaningful sub-questions, ask the user to narrow down. Suggest 2-3 specific angles. Step 0 in `SKILL.md` covers when and how to clarify.

## Scraper quality issues

If a scraper returns off-topic, low-quality, or fabrication-smelling results, discard the file and dispatch a replacement scraper with a rephrased query. Maximum 2 follow-up rounds per sub-question — after that, mark the gap in the final output instead of papering over it. The five hard triggers in `SKILL.md` Step 3 enumerate which symptoms count.

## Verifier failures

If a `dr-verifier` subagent returns `ERROR|...` or fails to spawn:
- Do NOT verify the claim yourself with direct WebSearch/WebFetch.
- Do NOT substitute another agent type.
- Mark the claim `unverifiziert` under the report's Verifikation section and keep it with
  `medium` confidence.
- One retry per claim is allowed (re-spawn the same verifier once). After that, mark it
  unverified and move on. Verifier failures never block synthesis.

---
name: dr
description: Start a deep research session across web, codebase, and knowledge domains (capped, verified)
arguments:
  - name: topic
    description: The research question or topic (quoted)
    required: true
  - name: --mode
    description: "Force research mode: web, codebase, knowledge, or mixed"
    required: false
  - name: --tier
    description: "Cost/verify tier: lite (default), standard, thorough"
    required: false
  - name: --fast
    description: "Speed mode: skip verification, curl-only link gate, wide-and-shallow plan allowed"
    required: false
---

Invoke the `deep-research:dr` skill with the following input:

- **Topic**: $ARGUMENTS
- Parse any options (--mode, --tier, --fast, --no-verify, --yes/--no-confirm; --verify3 is deprecated) from the arguments
- If no options detected, pass the full argument string as the topic

The skill handles everything: mode detection, auto-scaling, scraper dispatch, claim
extraction, capped verification, self-check, synthesis, and metrics.

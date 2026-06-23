---
name: spinner
description: Spin up a fresh, uncorrelated sub-agent (on Opus) to stress-test a decision and pick the best option
arguments:
  - name: brief
    description: The decision + options to pressure-test (quoted). Optional — if omitted, uses the options laid out earlier in the conversation.
    required: false
---

Invoke the `spinner` skill to get an uncorrelated second opinion on a decision.

If a brief was provided in the arguments, use it as the decision/options. Otherwise, use the options most recently laid out in this conversation. Follow the skill's flow exactly: assemble a neutral brief (no leaked preference), dispatch one general-purpose sub-agent with `model: "opus"`, confirm it ran on Opus (Step 3.5), then relay the decision, edge cases, runner-up, and confidence.

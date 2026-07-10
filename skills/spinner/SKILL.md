---
name: spinner
disable-model-invocation: true
description: Spin up a fresh, uncorrelated sub-agent to stress-test a decision. You give it info about the choice; it reads the code + project files, chooses for itself how hard to think and which skills to use (deep-research, extended thinking, etc.), hunts for edge cases and things you'd have missed, and returns the best decision with reasoning. Use when Claude has handed you options and you want a second uncorrelated brain to pick — or when you're at any fork and want it pressure-tested before committing.
---

# Spinner — uncorrelated second opinion on a decision

The point of this skill is **decorrelation**. When the same context that produced a set of options also evaluates them, it's anchored — it tends to defend its own framing and inherits its own blind spots. `/spinner` breaks that by dispatching a **fresh sub-agent with a clean context window** that only knows the decision itself, not the reasoning that led here. It reads the actual code, uses heavy tools, and comes back with an independent pick plus the edge cases the anchored view would have missed.

## When this fires

- **Manual:** User types `/spinner` — usually right after Claude (or the user) has laid out options for a decision, or at any fork worth pressure-testing.
- The user's mental model: *"give it info, have it read the code and project files, let it use its skills (deep-research / thinking), then make the best decision."* Honor that exact flow.

## Step 1 — Assemble the brief (what the sub-agent gets)

Before dispatching, gather what the sub-agent needs. It starts with **zero** of this conversation's context, so be deliberate — but keep it to *facts and options*, NOT your leaning. Decorrelation dies if you tell it which option you prefer.

Assemble:
1. **The decision** — what's being chosen, stated in one or two sentences.
2. **The options** — every option on the table, described neutrally. If the user passed a brief in the args, use it. If options were laid out earlier in *this* conversation, restate them.
3. **Relevant locations** — name the files/dirs/modules the decision touches, so the sub-agent knows where to read. Don't paste the code; tell it where to look and let it read fresh.
4. **Hard constraints** — anything fixed (stack, deadline, budget, must-not-break). Separate these from preferences.

**If the decision is underspecified** (no clear options, or you can't tell what's being decided), ask the user 1-2 sharp clarifying questions first. Do not dispatch a vague brief — a fresh agent given mush returns mush.

**Do NOT leak your preference.** If you authored the options, resist hinting at the "right" one. The whole value is an unanchored verdict.

## Step 2 — Let the sub-agent choose its own effort and tools

Do **not** prescribe ultrathink or a fixed skill set. The sub-agent decides for itself how hard to think and *whether* it needs research, based on the decision in front of it. Your job is only to make sure it *has access* to the full toolbox and *knows the menu* — the prompt template below tells it to triage first and pick deliberately. It decides *if* it researches and *which* method fits.

What it has available to choose from:
- **Reading the code / project files** — always available; it should ground every claim in what's actually there.
- **Extended thinking ("think" → "think hard" → "ultrathink")** — it dials this up only when the trade-offs are genuinely tangled. A clear-cut call shouldn't burn a max-thinking budget.
- **Research (method = the agent's choice)** — only when the decision turns on external/current facts (library comparison, "current best practice for X", API/version behavior). Match the method to the question: a quick fact → WebSearch (or the `exa` skill if installed); a deep, cited, multi-source call → `Skill(skill="deep-research:dr")` (this plugin ships it). Research is optional; the method is chosen deliberately, not fixed.
- **Any other skill in the environment** that fits (e.g. a security review for a security-sensitive choice).

The principle: **match effort to the decision.** A trivial local call gets light thinking and no web; a hard-to-reverse architecture or business bet justifies max thinking plus research. The agent makes that call — you just hand it the keys and the menu. When it's genuinely on the fence about effort, it should lean heavier — a missed edge case costs more than a few extra tokens.

## Step 3 — Dispatch the sub-agent

Spawn **one** sub-agent via the `Agent` tool with a **general-purpose** type (it needs full tool access: Read/Grep/Glob to read code, Skill to invoke research (deep-research/exa) or thinking, etc.) and **`model: "opus"`**.

**Why Opus, explicitly:** a spinner verdict *is* the judgment step — it's the whole reason you're spending a fresh sub-agent. Judgment work runs on the strongest available model, so the verdict isn't bottlenecked by a cheaper tier that the session or subagent defaults might otherwise hand it. Set `model: "opus"` at the spawn site so it overrides whatever the session/agent-tier default is. (If your environment has a newer top-tier reasoning model than Opus, use that instead — the rule is "strongest model for the judgment," not "Opus forever.")

Hand it a prompt built on this template (fill in from Step 1; restate the objective + constraints + task at the very end, task last):

```
You are an independent reviewer brought in to make a decision with FRESH EYES.
You have NONE of the prior conversation's context, and that is the point — you
are here precisely because the people closer to this are anchored to their own
framing. Trust the code and the constraints over any assumption.

THE DECISION:
<one-two sentence statement>

THE OPTIONS:
<neutral list — A / B / C, no indication of which is preferred>

WHERE TO LOOK (read these fresh, don't trust summaries):
<files / dirs / modules the decision touches>

HARD CONSTRAINTS (fixed — do not violate):
<stack, deadline, budget, must-not-break, etc.>

YOUR JOB:
1. READ the code and project files at the locations above. Verify claims against
   what's actually there — do not assume.
2. TRIAGE YOUR OWN EFFORT before diving in. You decide how hard to think and which
   tools to use — match the effort to the decision, don't default to maximum:
   - How tangled are the trade-offs? Dial your thinking accordingly — plain
     reasoning for a clear-cut call, "think hard" or "ultrathink" only when the
     trade-offs genuinely warrant it.
   - Does the decision turn on EXTERNAL or CURRENT facts (library comparison,
     "current best practice for X", API/version behavior)? YOU decide whether a
     research step is needed — if the repo and constraints already settle it, skip
     research entirely, don't burn it. But this is non-negotiable: IF you do any
     research, pick the method that fits: WebSearch (or exa) for a quick fact,
     Skill(skill="deep-research:dr") for deep cited multi-source research.
     Research is optional; the method is your deliberate choice.
   - Is any other skill a fit (e.g. a security review for a security-sensitive
     choice)? Use it if so.
   State in one line what effort level and which skills you chose, and why.
3. HUNT for edge cases, failure modes, and things the original framing likely
   MISSED — the second-order consequences, the option nobody listed, the
   constraint that quietly rules one out. This is the highest-value part of your job.
4. DECIDE. Commit to the single best option. If a better option exists that
   wasn't listed, propose it.

RETURN (this exact structure):
## Decision: <the pick>
**Why:** <reasoning grounded in what you actually read>

## Edge cases & things likely missed
<numbered — each with why it matters and what to do about it>

## Runner-up: <option> — when you'd prefer it instead
<the honest case for the second-best, so the trade-off is visible>

## Confidence: <high / medium / low> — <what would change your mind>

Reminder of your task: you are the FRESH, UNCORRELATED reviewer. Read the code,
decide for yourself how hard to think and which skills to use (only as much as the
decision warrants), find what the anchored view missed, and commit to the single
best decision in the structure above. Decide — last line first.
```

If the decision is large enough to fan out (several independent sub-questions, or competing approaches each worth a deep look), it's fine to dispatch **2-3 sub-agents in parallel** in one message — each on a slice or each from a different lens — then synthesize their verdicts. Default to one; scale up only when the decision is genuinely wide.

## Step 3.5 — Confirm the verdict actually ran on the strongest model

The Opus pin in Step 3 is load-bearing — a verdict silently produced by a cheaper model is exactly the failure this skill exists to prevent, and a wrong `model:` (or an environment that ignores the override) fails *silently*: you still get a confident-looking answer. So verify, don't assume:

- The `model: "opus"` argument was actually set on the `Agent` call you dispatched — check the spawn, not your intent.
- If your environment exposes the sub-agent's running model (some surface it in the agent's return or in usage logs), confirm it reads as Opus (or your designated top reasoning model).
- If you cannot confirm it ran on the intended model — the param was missing, the spawn fell back to a session/tier default, or the environment gave you no way to tell — **say so in the relay** ("verdict produced on `<model/unknown>`, not confirmed Opus") rather than presenting it as a top-tier judgment. An unverifiable claim about the model is itself a finding the user should see.

This is a 10-second check that protects the entire value of the skill. Do it before Step 4.

## Step 4 — Relay the verdict

The sub-agent's reply is for you, not the user. Relay it cleanly:
- Lead with the **decision and the one-line why**.
- Surface the **edge cases / missed things** prominently — that's what the user came for.
- Keep the runner-up and confidence so the user sees the trade-off and how sure the agent is.
- If the agent's pick contradicts the leaning you had going in, **say so plainly** — that disagreement is the signal, not noise. Don't quietly bury it.
- Note the model it ran on (from Step 3.5), especially if it could not be confirmed as Opus.

## Hard rules

- **Do not auto-execute the decision.** `/spinner` decides and reports; the user stays the trigger. Acting on it (writing code, running the command) is a separate, explicit step the user asks for after seeing the verdict.
- **Always pin `model: "opus"` at the spawn site** (or your strongest reasoning model) and **confirm it (Step 3.5)** — the verdict is judgment work; don't let it silently fall to a cheaper tier.
- **Never leak your own preference into the brief.** Decorrelation is the entire value.
- **The sub-agent reads code fresh** — give it locations, not your summary of the code. A summary re-imports your anchoring.
- **Research method is the agent's choice:** it decides whether to research, and picks the fitting method — WebSearch/exa for a quick fact, `Skill(skill="deep-research:dr")` for deep cited research.
- **Don't dispatch a vague brief** — clarify with the user first if the decision or options aren't crisp.

## When NOT to use it

- Pure facts with one right answer ("what does this function return") — just read the code.
- Trivial, fast-reversible choices — the overhead isn't worth it.
- When the user has already decided and just wants it built — that's a do-it request, not a decision to stress-test.

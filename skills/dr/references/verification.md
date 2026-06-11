# Verification: spawn pattern, aggregation, confidence

Detail for SKILL.md Step 5. Read this before dispatching verifiers.

## Spawn pattern (one agent per batch, up to ~10 claims)

<example>
Agent(
  subagent_type: "deep-research:dr-verifier",
  model: "sonnet",
  prompt: "Verify the batch of claims below. Follow your agent instructions for output format and return value.

QUESTION: What are Stripe's 2026 payment fees for SaaS?

CLAIM 1: Stripe charges 0.4% for ACH payments in 2026.
QUOTE 1: \"ACH Direct Debit ... 0.4% per transaction (capped at $5.00)\"
SOURCE_URL 1: https://stripe.com/pricing
SOURCE_TYPE 1: doc

CLAIM 2: Stripe Billing costs 0.7% of recurring revenue.
QUOTE 2: \"Billing ... 0.7% on recurring payments\"
SOURCE_URL 2: https://stripe.com/billing/pricing
SOURCE_TYPE 2: doc

... (up to 10 claims) ...

OUTPUT_FILE: /tmp/deep-research/<run-dir>/verify-r1-b1.md"
)
</example>

A batch of exactly 1 claim is valid — the orchestrator uses single-claim batches when escalating a contested claim. Round-3 prompts must include the contradiction found earlier ("Round 1 found a counter-source: <URL> — dig deeper than the one-search baseline").

Launch all Round-1 batches in parallel. Each verifier returns only `DONE|{path}`; read the verdict files afterward — each holds one `### Verdict N` block per claim.

## Wave order

1. All Round-1 batches in parallel.
2. After reading every Round-1 verdict: the single Round-2 batch (important claims; standard/thorough tiers only) and/or the single Round-3 batch (useful contradicted claims), as triggered.

Lite tier: Round 1 is one batch agent (cap is 5 claims); a single escalation agent runs only if a contradiction needs a deeper look.

## Aggregation (per claim, across the rounds it appeared in)

- **Round 1 only** (ordinary central claim): its Round-1 verdict stands.
- **Round 1 + Round 2** (important claim): if the two reads agree, that is the verdict; if they disagree, treat the claim as contested and fold it into Round 3.
- **Escalated to Round 3:** the Round-3 verdict decides. Confirms → the claim survives. Still `contradicted`/`uncertain` → **throw the claim out**: remove it from the findings and list it under the report's Verification section as "removed — unresolved contradiction" with the counter-source.

## Confidence mapping

- all/most `confirmed` + primary source → `high`
- `confirmed` with secondary source, or survived-after-escalation → `medium`
- `uncertain`, or single weak source → `low`

Findings that skipped verification (supporting/tangential claims, codebase mode) default to `medium` with no boost.

## Hard cap interaction

Verifier agents ≈ `ceil(claims / 10)` for Round 1, plus at most 2 escalation agents. If the planned total of scrapers + verifiers exceeds the tier's hard subagent cap, reduce the claim count first (drop lowest-centrality claims), never the batching or escalation logic.

## Failure rule

If a `dr-verifier` fails to spawn or returns `ERROR|...`: one retry per batch, then mark its claims `unverified` in the Verification section and continue. Never verify claims yourself with direct WebSearch/WebFetch, never substitute another agent type. Verifier failures never block synthesis.

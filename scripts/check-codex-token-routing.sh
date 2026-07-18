#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${ROOT}/codex/skills/dr/SKILL.md"
PLUGIN="${ROOT}/PLUGIN.md"

grep -q 'first-pass shallow, standard, or deep.*gpt-5.6-terra.*low reasoning' "${SKILL}"
grep -q 'targeted retry after the low-cost pass fails.*gpt-5.6-terra.*medium reasoning' "${SKILL}"
grep -q 'gpt-5.6-terra.*high-reasoning verifier' "${SKILL}"
grep -q 'gpt-5.6-sol.*thorough' "${SKILL}"
grep -q 'never use Sol for collection' "${SKILL}"
grep -q 'never use maximum/ultra reasoning for routine verification' "${SKILL}"
grep -q 'first-pass collectors to Terra/low' "${PLUGIN}"
grep -q 'Use a moderate-capability head' "${SKILL}"
grep -q '| lite | 2–6 | 5 | 25 |' "${SKILL}"
grep -q '| standard | 4–12 | 10 | 35 |' "${SKILL}"
grep -q '| thorough | 6–15 | 25 | 55 |' "${SKILL}"
grep -q 'Prefer roughly 12 total scrapers and cap at 15' "${SKILL}"
grep -q 'Thorough uses exactly three evenly split Round-1 batches' "${SKILL}"

if grep -qE 'Route cheap bounded collection to a Terra/medium|Use a fresh Sol/high verifier' "${SKILL}"; then
  printf 'FAIL: legacy all-medium/all-Sol Codex routing remains\n' >&2
  exit 1
fi

printf 'Codex token routing: PASS\n'

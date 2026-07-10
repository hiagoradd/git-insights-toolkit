# Classification rubric (judgment) — prs-insights-dev

The deterministic layers (PR type, comment layer, bot/self-reply exclusion) are already applied
by `prs-insights-fetch` and present on the dataset rows. This file holds the **judgment** layers
the developer-coaching report assigns per comment — always from these fixed enums, never invent
categories, so counts stay comparable across runs.

Classify only comments where `excluded == false`. Additionally set aside bare praise / "LGTM"
with no actionable content (tally as `praise`, keep out of the severity mix).

## Theme — fixed enum (pick exactly one per comment)

`correctness-bug` · `convention/style` · `architecture/layering` · `test-coverage` ·
`error-handling/observability` · `migration-hygiene` · `pr-scope/hygiene` · `performance` ·
`security` · `a11y` · `naming/docs` · `dead/premature-UI` · `question` · `praise`

## Severity — fixed enum

- **critical** — a functional or user-facing bug, or a data/deploy risk, that would break in
  production. Judge by *content*, not the reviewer's hedging: a real 404/crash/data-loss is
  critical even when the reviewer writes "non-blocking". Note the mismatch in the narrative.
- **blocker** — must-fix before merge: convention violation, red CI, correctness/migration
  hygiene, or a reviewer-flagged "Important".
- **suggestion** — optional: style, readability, future improvement, or a question.

## Actionability & resolution (fixed enums)

- actionability: `change-requested` · `question` · `fyi` · `praise`
- resolution (from the author's reply thread — the `is_self_reply` rows): `fixed` ·
  `deferred-to-follow-up` · `declined-with-rationale` · `no-reply`

## Layer for no-path comments

`review-comments.ndjson` rows already carry a mechanical `layer`. `issue-comments.ndjson` rows
have none — infer the layer from the text (FE / BE / migration / test / infra / docs) when it
matters for the theme × PR-type matrix.

## Reinforcement mapping (systemic patterns → cheapest enforcement)

When a theme recurs (**≥3 comments** in the window, or across ≥2 runs once trends exist), map it
to the cheapest layer that would prevent it, in this order:

1. **Automation** (lint / CI / typecheck) — best, cannot be forgotten.
2. **Existing `.claude/rule` that's being ignored** — strengthen it (better example, move it
   earlier, add to CLAUDE.md). Detect by grepping the theme against `.claude/rules/*` and
   `**/CLAUDE.md` — "we already have a rule and still violate it" is the highest-signal finding.
3. **New `.claude/rule` or CLAUDE.md line** — when no rule covers it.
4. **Process / PR-template** — when only a human gate can catch it.

Emit a **concrete** proposal (which file, what text), not a vague "add a rule". Prioritize by
`recurrence × severity × preventability`.

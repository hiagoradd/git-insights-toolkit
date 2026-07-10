# Classification rubric (judgment) — prs-report.dev

The deterministic layers (PR type, comment layer, bot/self-reply exclusion) are already applied
by `prs.fetch` and present on the dataset rows. This file holds the **judgment** layers
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

First, survey the target repo's **standing-guidance surface** — everything that already tells the
team, or their AI tools, how to write code here:

- `.claude/rules/*`
- every `CLAUDE.md` (root, `apps/*/`, `packages/*/`)
- **skills & agents** — `.claude/skills/**/SKILL.md`, `.claude/agents/*`, and any installed
  plugin skills/agents (their `SKILL.md` / agent frontmatter + body)

When a theme recurs (**≥3 comments** in the window, or across ≥2 runs once trends exist), grep it
across that whole surface and map it to the cheapest layer that would prevent it, in this order:

1. **Automation** (lint / CI / typecheck) — best, cannot be forgotten.
2. **Existing guidance that isn't landing** — a `.claude/rule`, a `CLAUDE.md` line, or a
   **skill/agent** that already covers this area but is being ignored or is too weak. Strengthen it
   in place (sharper example, move it earlier, add the missing case). "We already say this and
   still violate it" is the highest-signal finding — and a skill/agent that *runs on every task*
   is often the cheapest place to reinforce, above a passive rule.
3. **New standing guidance** — add it where the team already looks: a new `.claude/rule`, a
   `CLAUDE.md` line, or a line in the most relevant existing skill/agent. Author a brand-new skill
   only when a whole workflow is missing.
4. **Process / PR-template** — when only a human gate can catch it.

Emit a **concrete** proposal — the exact file and the text to add or change, and whether it
**modifies existing** guidance or **adds new** — not a vague "add a rule". Prioritize by
`recurrence × severity × preventability`.

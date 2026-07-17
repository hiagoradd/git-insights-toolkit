# Classification rubric (judgment) — prs.classify

The **canonical** enum set for classifying PR review feedback. This is the single source of truth:
`prs.classify` applies it, and `prs-report.dev` / `prs.reinforce` consume the resulting
`classified-issues.ndjson` rather than re-defining categories. Always classify from these fixed
enums — never invent categories — so counts stay comparable across consumers and runs.

The deterministic layers (PR `type`, comment `layer`, bot/self-reply `excluded`) are already applied
by `prs.fetch` and present on the dataset rows. This file covers only the **judgment** layers.

Classify only comments where `excluded == false`. Additionally set aside bare praise / "LGTM" with
no actionable content (tag them `theme: praise`, keep them out of the severity mix).

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

`review-comments.ndjson` rows already carry a mechanical `layer`. `issue-comments.ndjson` rows have
none — infer the layer from the text (FE / BE / migration / test / infra / docs) when it's
determinable, else `null`.

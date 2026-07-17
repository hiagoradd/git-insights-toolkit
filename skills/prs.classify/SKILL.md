---
name: prs.classify
description: >
  Classify the actionable review feedback in a prs.fetch run directory — assign each non-excluded
  comment a theme, severity, actionability, and resolution from a fixed enum set, and persist the
  result as classified-issues.ndjson in the same run dir. This is the single, shared LLM
  classification pass: both the Developer Coaching report (prs-report.dev) and the reinforcement
  workflow (prs.reinforce / /prs-reinforce) consume its output, so the enums stay one source of
  truth. Data-shaping only — it does NOT render a report or propose reinforcements. Triggers on:
  "classify pr comments", "categorize review feedback", "theme and severity of comments",
  "build classified-issues".
metadata:
  category: analysis
  tags: [pr, insights, classify, theme, severity, judgment, shared]
  status: ready
---

# PR Insights — Classify

The single **judgment** pass over review feedback. It reads a `prs.fetch` run directory and writes
**`classified-issues.ndjson`** back into it — one row per actionable comment, tagged with the fixed
enums in `references/classification.md`. Everything downstream that needs theme/severity
(`prs-report.dev`, `prs.reinforce`) reads that file instead of re-classifying, so the enums have
**one home** and counts stay comparable across consumers and runs.

This is the **only** step that runs LLM classification. `prs.fetch` stays zero-LLM (mechanical
enrichment only); this skill adds the judgment layer as a *separate* file, never mutating fetch's
outputs.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by `/prs-reinforce` or `prs-report.dev`), use it directly.
- **If invoked standalone without one**, first run the `prs.fetch` skill (parsing the same
  `users` / `time-period` params), then continue.

Read `manifest.json` (window/scope), **`review-comments.ndjson`** and **`issue-comments.ndjson`**
(the comments to classify), and **`pulls.json`** (for each comment's PR `type`). The deterministic
`layer` / `excluded` / `is_bot` / `is_self_reply` fields are already on the rows.

## Reuse an existing pass

If the run dir already contains **`classified-issues.ndjson`** whose row count matches the
non-excluded comment count in the manifest, **reuse it** — say so and skip re-classifying. Only
re-run if it's missing or stale (e.g. the dataset was refetched).

## Steps

1. **Read `references/classification.md` first** — it holds the fixed enums. Never invent
   categories; use only the listed values so counts stay comparable.
2. For each comment with **`excluded == false`**, and after setting aside bare "LGTM" / praise with
   no actionable content (tag those `theme: praise`), assign **theme**, **severity**,
   **actionability**, and **resolution**. Judge severity by *content*, not the reviewer's hedging.
   Self-reply rows (`is_self_reply`) are excluded from classification but used to derive the
   author-side `resolution` of the parent comment.
3. For `issue-comments.ndjson` rows (no `path`, so no mechanical `layer`), infer a `layer`
   (FE / BE / migration / test / infra / docs / null) from the text when it's determinable.

## Output — write `classified-issues.ndjson`

Write one JSON object per classified comment (NDJSON) into the **run dir**, alongside fetch's
files. Each row:

```json
{
  "pr": 123,
  "pr_type": "back-end",
  "source": "review",
  "user": "alice",
  "path": "apps/api/src/users.ts",
  "line": 42,
  "layer": "BE",
  "created_at": "2026-07-10T…",
  "theme": "correctness-bug",
  "severity": "critical",
  "actionability": "change-requested",
  "resolution": "fixed",
  "excerpt": "returns 200 even when the user lookup fails — should 404"
}
```

- `source` ∈ `review` / `issue` (which file the comment came from).
- `path` / `line` are `null` for issue comments; `layer` may be `null`.
- `pr_type` copied from the comment's PR row in `pulls.json` (for the theme × PR-type matrix
  downstream).
- `excerpt` — a short (≤ ~140 char) faithful paraphrase or quote for traceability; **not** the full
  body. Never invent content.
- `praise` rows carry `theme: "praise"`, `actionability: "praise"`, and `severity: "suggestion"`
  (consumers filter them out of the severity mix by theme).

Also, if useful, drop a one-line `classified` block into your response — do **not** rewrite
`manifest.json` (it's fetch's contract); consumers count rows from the file directly.

## Return

Report the **`classified-issues.ndjson` path** and a one-line summary: total classified, the
severity split (critical / blocker / suggestion), and the top 2–3 themes by count. Do **not** print
the full classified rows or render any report.

## Scope & boundaries

- **Writes exactly one file** — `classified-issues.ndjson` in the run dir. Never modifies fetch's
  outputs, source code, or anything outside the run dir.
- **No reinforcement logic here.** Mapping recurring themes to rule/CLAUDE.md/skill changes is
  `prs.reinforce`'s job, which reads this file.
- Small windows are noisy: one person's week is ~20 comments — treat single-run patterns as
  provisional.

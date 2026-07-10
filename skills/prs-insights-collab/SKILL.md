---
name: prs-insights-collab
description: Generate the Review Collaboration report for the cxnch-platform repo — the people/process view of code review over a window of PRs: reviewer-load concentration, a who-reviews-whom matrix, time-to-first-review responsiveness, PRs merged without peer review, bottlenecks, and bus-factor risk. Surfaces "one person does most of the reviews" and review silos. Reads a prs-insights-fetch run directory (or fetches one if not given). Use when asked about reviewer load, review balance, who reviews whom, review latency, or bus factor. Triggers on: "review collaboration", "reviewer load", "who reviews whom", "review bottlenecks", "bus factor", "review balance".
---

# PR Insights — Review Collaboration

The people/process view: who reviews, how much, how fast, and where the single points of
failure are. Deterministic off the dataset — **no theme/severity judgment**.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by the `/prs-insights` orchestrator), use it directly.
- **If invoked standalone without one**, first run the `prs-insights-fetch` skill (parsing the
  same `users` / `time-period` params), then continue.

Read `manifest.json` (window/scope), **`reviews.ndjson`** (submissions: `user`, `state`,
`submitted_at`, `is_bot`), and **`pulls.json`** (PR author + `created_at` for latency). You do
not need comment bodies.

## Compute

- **Reviewer load** — review submissions per reviewer (exclude `is_bot`); share of total; PRs
  touched. Flag concentration (e.g. top reviewer's share).
- **Who-reviews-whom** — matrix of author × reviewer submission counts. Flag authors reviewed by
  only 0–1 distinct peers (silo / bus-factor).
- **Responsiveness** — time-to-first-review per PR (`created_at` → earliest non-author
  `submitted_at`); report median and P90.
- **Unreviewed merges** — PRs merged with no non-author review submission.
- **Self-reviews** — author == reviewer; report separately, don't count as peer review.
- **Bottlenecks / bus-factor** — single-point-of-failure reviewers, single-reviewer authors, and
  the slowest-to-first-review PRs.

## Render — write one file

Fill `assets/report-template.md` (keep section order, tables, `████░░` bars). Every narrative
number must trace to a table.

**Write to** `reports/prs-insights/<since>_to_<until>_<scope>_collab.md` (create the dir if
missing; take the parts from `manifest.json`).

**Return** only the file path + a 3–5 line headline summary — not the full report body.

## Boundaries

Read-only except the one report file. No code-quality analysis or reinforcement proposals.
Small windows are noisy — frame concentration as a snapshot, not a verdict, unless the window is
several weeks.

---
name: prs-insights-exec
description: Generate the Executive Summary report for the cxnch-platform repo — a one-page, non-technical health snapshot of PR delivery for a PM or team lead: throughput, merge health, the single biggest risk to watch, and one concrete recommendation. A digest, in plain language, with no code jargon. Computes its own top-line from the dataset (independent of the other reports, so it can run in parallel). Reads a prs-insights-fetch run directory (or fetches one if not given). Use when asked for an executive summary, a PM/leadership PR digest, or a high-level review health snapshot. Triggers on: "executive summary", "pr digest for leadership", "pm summary", "high-level pr health".
---

# PR Insights — Executive Summary

A one-page, plain-language digest for a PM/lead. No code jargon, no file paths, no theme enums —
just delivery health, the top risk, and one recommendation.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by the `/prs-insights` orchestrator), use it directly.
- **If invoked standalone without one**, first run the `prs-insights-fetch` skill (parsing the
  same `users` / `time-period` params), then continue.

**Independence (deliberate):** this report is computed **directly from the dataset**, not by
reading the sibling report files — under the orchestrator all reports run in parallel, so their
`.md` files may not exist yet. Read `manifest.json` (window/scope + PR count) and do a **light
pass** over `pulls.json` (merge rate, clean-merge rate, contributor count) and, if it's quick, a
glance at `reviews.ndjson` for review-load skew. Keep it light — depth lives in the other three
reports.

## Compute (top-line only)

- Throughput — PRs opened, merged, merge rate.
- First-pass clean-merge rate (merged with no actionable comments / non-approve review).
- Contributor count.
- The single biggest risk — pick one: a production-risk signal, review-load concentration, or a
  slow cycle. State it as business impact, not implementation detail.

## Render — write one file

Fill `assets/report-template.md` (one page, plain language). **Write to**
`reports/prs-insights/<since>_to_<until>_<scope>_exec.md` (create the dir if missing; take the
parts from `manifest.json`).

**Return** only the file path + a 3–5 line headline summary.

## Boundaries

Read-only except the one report file. Don't reproduce the detailed reports' tables — point to
them instead. No reinforcement proposals.

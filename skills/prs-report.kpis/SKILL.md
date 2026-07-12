---
name: prs-report.kpis
description: Generate the Delivery KPIs report for a GitHub repo — the numbers dashboard over a window of PRs: volume, PRs by type/stack, size (files & lines), merge rate, cycle times (time-to-first-review, create→approve, approve→merge), review rounds, comment density, first-pass clean-merge rate, and per-contributor throughput. Purely quantitative and deterministic; no code-quality judgment. Reads a prs.fetch run directory (or fetches one if not given). Use when asked for PR metrics, delivery KPIs, throughput/cycle-time numbers, or "PRs by type". Triggers on: "pr kpis", "delivery metrics", "pr throughput", "cycle time report", "prs by type".
---

# PR Insights — Delivery KPIs

The quantitative dashboard: volume, size, cadence, and cycle time. **No theme/severity
judgment** — that's the developer-coaching report. This report is deterministic off the
dataset.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by the `/prs-insights` orchestrator), use it directly.
- **If invoked standalone without one**, first run the `prs.fetch` skill (parsing the
  same `users` / `time-period` params) to produce the dataset, then continue.

Read `manifest.json` for the window/scope, then the files you need: **`pulls.json`** (all
metrics + `type`) and **`reviews.ndjson`** (cycle times, review rounds). You do **not** need the
comment bodies — read `review-comments.ndjson`/`issue-comments.ndjson` only to count density
(rows where `excluded == false`).

## Compute

From `pulls.json` + review timestamps:

- **Volume & mix** — total PRs; merged / closed-unmerged / open; count per `type`.
- **Size** — avg & median `changed_files`; avg `additions` / `deletions`.
- **Cycle times** — time-to-first-review (`created_at` → earliest `submitted_at`), review time
  (`created_at` → first `APPROVED`), merge lag (approve → `merged_at`). Report medians when the
  spread is wide; drop PRs missing a timestamp and note how many.
- **Review rounds** — distinct review submissions per PR (exclude `is_bot`).
- **Comment density** — actionable comments (`excluded == false`) per PR **and** per 100 LOC.
  **Normalize all cross-type comparisons by density**, never raw counts.
- **First-pass clean merge** — merged with zero actionable comments and no non-approve review.
- **Per contributor** — PRs, merged, avg size, clean-merge %.

## Render — write one file

Fill `assets/report-template.md` (keep section order, tables, `████░░` bars). Every narrative
number must trace to a table.

**Write to** `reports/prs-insights/<since>_to_<until>_<scope>_kpis.md` (create the dir if
missing; take `<since>`/`<until>`/`<scope>` from `manifest.json`).

**Return** only the file path + a 3–5 line headline summary — not the full report body.

## Boundaries

Read-only except the one report file. No code-quality/theme analysis, no reinforcement
proposals. If a metric can't be computed (e.g. no reviews in-window), state "n/a" rather than
guessing.

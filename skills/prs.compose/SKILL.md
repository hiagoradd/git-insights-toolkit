---
name: prs.compose
description: >
  Consolidate a set of already-produced PR-insights report files into one deliverable — either a
  single combined markdown document or a self-contained, shareable Artifact web page. Reads the
  per-report .md files (never the raw dataset), preserves the house style, and returns only the
  resulting path / URL plus a short headline. Use as the final presentation step of /prs-insights
  when --format is `single` or `webpage`. Triggers on: "combine these reports", "one document",
  "make a webpage", "render the reports as a page", "publish these reports".
metadata:
  category: authoring
  tags: [pr, insights, report, compose, artifact, webpage, presentation]
  status: ready
---

# prs.compose — consolidate reports into one deliverable

Turn the per-report markdown files a `/prs-insights` run just produced into **one** deliverable:
a combined document (`single`) or a shareable web page (`webpage`). This is a **presentation**
step — it reads the finished report files, never the raw run-dir dataset, and never recomputes or
re-summarizes any metric. The individual `.md` files remain the source of truth.

## Inputs

The caller (`/prs-insights` Step 3) hands you:

- **`format`** — `single` or `webpage`.
- **`report_paths[]`** — the per-report `.md` files just written (under `reports/prs-insights/`),
  each with its report name (`exec` / `kpis` / `collab` / `dev` / a custom or `--ask` slug).
- **`run_dir` + manifest one-liner** — read `manifest.json` for the header (`scope` · `repo` ·
  `since` → `until`). The manifest is the source of truth; never parse the dir name.

If `report_paths` is missing or empty, ask the caller. If a listed file doesn't exist, note it and
compose from the rest.

## Steps

1. **Read the manifest** for the header line, and **read each report file** in `report_paths`.
2. **Order the sections** stably: `exec`, `kpis`, `collab`, `dev`, then any custom / `--ask`
   reports in the order given.
3. **Build the combined markdown** — always produce this first (it's the durable artifact both
   formats share):
   - A header: `**Scope:** … · **Repo:** … · **Window:** <since> → <until>`.
   - A short **table of contents** linking each section.
   - Each report's **full body** under an `##` section titled by its report name. Keep the bodies
     verbatim — demote their internal headings if needed so the combined doc's outline stays clean
     (report `#`/`##` → `###`/`####` under each section). Don't rewrite numbers or prose.
   - Write it to `reports/prs-insights/<since>_to_<until>_<scope>_combined.md`.

4. **If `format == single`** — you're done. Return the combined file path + a 3–5 line headline
   naming which reports it contains.

5. **If `format == webpage`** — render that combined document as a single, self-contained,
   theme-aware Artifact page:
   - **Load the `artifact-design` skill first** to calibrate the design, then write an `.html`
     file (page content only — no `<html>`/`<head>`/`<body>`; the publisher wraps it). Inline all
     CSS; the CSP blocks external assets. Render tables as real tables and preserve the text bars
     (`████░░`) in a monospace context. Style both light and dark themes.
   - Publish it with the **Artifact** tool (favicon e.g. `📊`; a concise `<title>` like
     "PR Insights — <scope>, <window>"; one-sentence `description`).
   - Return the **Artifact URL** + the combined `.md` path (still the durable deliverable) + a 3–5
     line headline.

## Return

Only the resulting path/URL(s) + a short headline — never paste full report bodies back to the
caller. The orchestrator relays this; the bodies stay in your context.

## Boundaries

- Write **only** the combined `.md` (and, for `webpage`, publish one Artifact). Never modify the
  per-report files, the dataset, or anything else.
- Don't fetch, don't run reports, don't recompute metrics — you consolidate finished output only.
- If given a single report and `format == single`, there's nothing to combine — just report that
  the one file already is the deliverable.

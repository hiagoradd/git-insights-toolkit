---
name: prs-insights-dev
description: Generate the Developer Coaching report for the cxnch-platform repo — the "what does the team keep getting wrong in review, and how do we stop it" report. Classifies every actionable review comment by theme and severity, builds a theme × PR-type matrix, clusters recurring feedback into systemic patterns, and maps each to the cheapest reinforcement (lint/CI rule, an existing .claude/rule that isn't landing, a new rule, or a PR-template gate) with a concrete file+text proposal. Reads a prs-insights-fetch run directory (or fetches one if not given). Use when asked for recurring review comments, systemic patterns, reinforcement recommendations, or coaching insights. Triggers on: "developer coaching", "recurring review comments", "systemic patterns", "reinforcement recommendations", "what are we getting wrong in reviews".
---

# PR Insights — Developer Coaching

The judgment report. The goal is not metrics — it's to find **recurring review comments** and
turn them into reinforcements so the same feedback stops recurring. This is the **only**
`prs-insights-*` report that runs LLM classification.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by the `/prs-insights` orchestrator), use it directly.
- **If invoked standalone without one**, first run the `prs-insights-fetch` skill (parsing the
  same `users` / `time-period` params), then continue.

Read `manifest.json` (window/scope), **`review-comments.ndjson`** and
**`issue-comments.ndjson`** (the comments to classify), and **`pulls.json`** (for `type` and the
per-PR appendix). The deterministic `layer` / `excluded` / `is_bot` / `is_self_reply` fields are
already on the rows.

## 1. Classify (read `references/classification.md` first — it holds the fixed enums)

For each comment with `excluded == false`, and after setting aside bare "LGTM"/praise, assign
**theme**, **severity**, **actionability**, and **resolution** using only the fixed enums.
Judge severity by *content*, not the reviewer's hedging. Self-reply rows (`is_self_reply`) are
used only to derive `resolution`.

## 2. Find systemic patterns & map reinforcements

Cluster comments by theme. For any theme that recurs (**≥3** in the window), map it to the
cheapest enforcement layer per the reference's ordering (automation > strengthen-existing-rule >
new-rule > process). **Grep the theme against `.claude/rules/*` and root/`apps/*/CLAUDE.md`** to
detect "we already have a rule and still violate it" — that's the highest-signal finding. Emit a
*concrete* proposal (which file, what text), ranked by `recurrence × severity × preventability`.

## 3. Render — write one file

Fill `assets/report-template.md` (keep section order, tables, `████░░` bars, 🔴/🟠/🟡). Every
narrative number must trace to a table.

**Write to** `reports/prs-insights/<since>_to_<until>_<scope>_dev.md` (create the dir if missing;
take the parts from `manifest.json`).

**Return** only the file path + a 3–5 line headline summary — lead with the biggest recurring
pattern and the "rule exists but not landing" count.

## Boundaries & caveats

- Read-only except the one report file. The reinforcement step **proposes** edits; applying them
  is a separate, user-approved action — never edit rules/CLAUDE.md from here.
- Severity is judged from comment **content**; note how many PRs got a formal GitHub "Changes
  requested" (often zero — reviewers here approve-with-comments).
- Small windows are noisy: one person's week is ~20 comments — patterns need several weeks.
- Trends are stateless today — say "n/a first run" until run history is persisted; don't fake
  week-over-week deltas.

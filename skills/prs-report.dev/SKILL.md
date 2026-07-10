---
name: prs-report.dev
description: Generate the Developer Coaching report for the cxnch-platform repo — the "what does the team keep getting wrong in review, and how do we stop it" report. Classifies every actionable review comment by theme and severity, builds a theme × PR-type matrix, clusters recurring feedback into systemic patterns, and maps each to the cheapest reinforcement — reading the repo's standing guidance (.claude/rules, CLAUDE.md files, and skills/agents) to propose strengthening or adding to whichever already covers it, or a lint/CI rule or PR-template gate — with a concrete file+text proposal. Reads a prs.fetch run directory (or fetches one if not given). Use when asked for recurring review comments, systemic patterns, reinforcement recommendations, or coaching insights. Triggers on: "developer coaching", "recurring review comments", "systemic patterns", "reinforcement recommendations", "what are we getting wrong in reviews".
---

# PR Insights — Developer Coaching

The judgment report. The goal is not metrics — it's to find **recurring review comments** and
turn them into reinforcements so the same feedback stops recurring. This is the **only**
`prs-insights-*` report that runs LLM classification.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by the `/prs-insights` orchestrator), use it directly.
- **If invoked standalone without one**, first run the `prs.fetch` skill (parsing the
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
cheapest enforcement layer per the reference's ordering (automation > strengthen-existing-guidance
> new-guidance > process). Survey the target repo's whole **standing-guidance surface** —
`.claude/rules/*`, every `CLAUDE.md`, and its **skills & agents**
(`.claude/skills/**/SKILL.md`, `.claude/agents/*`, and installed plugin skills/agents) — and grep
the theme across it to detect "we already say this and still violate it" (the highest-signal
finding). Then emit a *concrete* proposal to **change or add to** the most relevant rule,
`CLAUDE.md`, or skill/agent — the exact file and text, and whether it modifies existing guidance or
adds new — ranked by `recurrence × severity × preventability`. See `references/classification.md`
for the full ladder.

## 3. Render — write one file

Fill `assets/report-template.md` (keep section order, tables, `████░░` bars, 🔴/🟠/🟡). Every
narrative number must trace to a table.

**Write to** `reports/prs-insights/<since>_to_<until>_<scope>_dev.md` (create the dir if missing;
take the parts from `manifest.json`).

**Return** only the file path + a 3–5 line headline summary — lead with the biggest recurring
pattern and the "guidance exists but not landing" count (rule / CLAUDE.md / skill).

## Boundaries & caveats

- Read-only except the one report file. The reinforcement step **proposes** edits; applying them
  is a separate, user-approved action — never edit rules / CLAUDE.md / skills from here.
- Severity is judged from comment **content**; note how many PRs got a formal GitHub "Changes
  requested" (often zero — reviewers here approve-with-comments).
- Small windows are noisy: one person's week is ~20 comments — patterns need several weeks.
- Trends are stateless today — say "n/a first run" until run history is persisted; don't fake
  week-over-week deltas.

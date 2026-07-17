---
name: prs-report.dev
description: Generate the Developer Coaching report for a GitHub repo — the "what does the team keep getting wrong in review, and how do we stop it" report. Classifies every actionable review comment by theme and severity, builds a theme × PR-type matrix, clusters recurring feedback into systemic patterns, and maps each to the cheapest reinforcement — reading the repo's standing guidance (.claude/rules, CLAUDE.md files, and skills/agents) to propose strengthening or adding to whichever already covers it, or a lint/CI rule or PR-template gate — with a concrete file+text proposal. Reads a prs.fetch run directory (or fetches one if not given). Use when asked for recurring review comments, systemic patterns, reinforcement recommendations, or coaching insights. Triggers on: "developer coaching", "recurring review comments", "systemic patterns", "reinforcement recommendations", "what are we getting wrong in reviews".
---

# PR Insights — Developer Coaching

The judgment report. The goal is not metrics — it's to find **recurring review comments** and turn
them into reinforcements so the same feedback stops recurring. It **composes** the two shared
judgment skills — `prs.classify` (theme/severity) and `prs.reinforce` (patterns → guidance) — and
renders their output into one coaching report. Those skills hold the enums and the ladder; this
report owns the presentation.

## Input — a fetch run directory

- **If given a run-dir path** (e.g. by the `/prs-insights` orchestrator), use it directly.
- **If invoked standalone without one**, first run the `prs.fetch` skill (parsing the
  same `users` / `time-period` params), then continue.

Read `manifest.json` (window/scope) and **`pulls.json`** (for `type` and the per-PR appendix).

## 1. Classify — via `prs.classify`

Invoke the **`prs.classify`** skill on the run dir. It writes (or reuses)
**`classified-issues.ndjson`** — one row per actionable comment tagged with `theme`, `severity`,
`actionability`, `resolution`, `pr_type`, `layer`, and a short `excerpt` (enums defined in
`skills/prs.classify/references/classification.md`). Read that file for everything below — do **not**
re-classify here; the shared pass is the one source of truth.

From `classified-issues.ndjson` compute: the **severity split** (dropping `theme: praise` from the
mix; tally praise separately), the **theme × PR-type matrix** (rows = theme, cells = comment count,
using each row's `pr_type`), and the **per-PR appendix** (comments per PR with 🔴/🟠/🟡 and top
theme). Also note how many PRs got a formal GitHub "Changes requested" (often zero — reviewers here
approve-with-comments); contrast that with content-judged severity.

## 2. Systemic patterns & reinforcements — via `prs.reinforce`

Invoke the **`prs.reinforce`** skill on the run dir (it reads `classified-issues.ndjson`; pass
`repo_root` = the target repo working dir). It clusters recurring themes (**≥ 3** in the window),
surveys the repo's whole standing-guidance surface — `.claude/rules/*`, every `CLAUDE.md`, and
**skills & agents** (incl. installed plugins) — detects "we already say this and still violate it",
maps each pattern to the cheapest enforcement layer, and returns a **structured `proposals[]`** list
(persisted as `reinforcement-proposals.json`).

Render those proposals into this report's **Systemic patterns** and **Reinforcement
recommendations** sections. Each proposal carries `theme`, `severity`, `recurrence`, `pr_refs`,
`already_covered`, `cheapest_layer`, `change_type`, `target_file`, `exact_text`, and `rationale`,
ranked by `recurrence × severity × preventability` — everything the template's tables need. This
report **proposes** only; applying the edits is `/prs-reinforce`'s job.

## 3. Render — write one file

Fill `assets/report-template.md` (keep section order, tables, `████░░` bars, 🔴/🟠/🟡). Every
narrative number must trace to a table.

**Write to** `reports/prs-insights/<since>_to_<until>_<scope>_dev.md` (create the dir if missing;
take the parts from `manifest.json`).

**Return** only the file path + a 3–5 line headline summary — lead with the biggest recurring
pattern and the "guidance exists but not landing" count (rule / CLAUDE.md / skill).

## Boundaries & caveats

- Read-only except the one report file. The reinforcement step **proposes** edits; applying them is
  a separate, user-approved action (`/prs-reinforce`) — never edit rules / CLAUDE.md / skills here.
- Severity is judged from comment **content** (in `prs.classify`); note how many PRs got a formal
  GitHub "Changes requested" (often zero — reviewers here approve-with-comments).
- Small windows are noisy: one person's week is ~20 comments — patterns need several weeks.
- Trends are stateless today — say "n/a first run" until run history is persisted; don't fake
  week-over-week deltas.

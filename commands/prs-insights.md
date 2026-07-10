---
name: prs-insights
description: >
  Orchestrate a full PR review-insights run for the cxnch-platform repo. Fetches the PR dataset
  once (prs.fetch), then fans out specialized report generators in parallel — Delivery
  KPIs, Review Collaboration, Developer Coaching, and Executive Summary — each writing its own
  markdown file, and presents the paths + headlines. Team-wide over the last 7 days by default.
metadata:
  category: workflow
  tags: [pr, insights, review, reports, orchestration, kpi, coaching]
  status: ready
  version: 1
allowed-tools: ["Bash", "Read", "Skill", "Agent"]
---

# /prs-insights — orchestrate the PR insights reports

Runs the fetch step once, then spawns one report-generating subagent per selected report **in
parallel**, each reading the shared run directory and writing its own file. This command holds
only paths + short summaries — never the raw dataset or the full report bodies.

**Arguments:** `$ARGUMENTS` — all optional, free-form. Parse out:
- **users** — comma-separated logins, or a name to map (`hiagoradd`). Default: all users (team).
- **time-period** — "last 30 days", "last 2 weeks", `--since YYYY-MM-DD`, etc. Default: last 7 days.
- **reports** — which of `kpis`, `collab`, `dev`, `exec` to run. Default: **all four**.
  Accept phrasings like "kpis only", "just coaching", "dev + exec".

## Step 1 — Fetch once

Invoke the **`prs.fetch`** skill with the parsed `users` / `time-period`. Capture the
**run-dir path** and the **one-line manifest summary** it returns. Do **not** read the dataset
files yourself — the report subagents do that.

Do not re-implement fetching (no direct `gh` calls here) — go through the skill so its
conventions (stable run dir, enrichment, manifest) are honored.

## Step 2 — Fan out report subagents (parallel)

For each selected report, spawn **one subagent** with the **Agent** tool. Issue all the Agent
calls **in a single message** so they run concurrently. Give each subagent this prompt shape:

> Follow the **`<skill-name>`** skill to generate its report. The `prs.fetch` run
> directory already exists at **`<run-dir-path>`** — use it directly, do not refetch. Manifest:
> `<one-line manifest summary>`. Write the report file as the skill specifies and **return only**
> the file path plus a 3–5 line headline summary — not the full report body.

| Report | Skill | Reads |
|---|---|---|
| Delivery KPIs | `prs-report.kpis` | `pulls.json`, `reviews.ndjson` |
| Review Collaboration | `prs-report.collab` | `reviews.ndjson`, `pulls.json` |
| Developer Coaching | `prs-report.dev` | comments + `pulls.json` (classifies theme/severity) |
| Executive Summary | `prs-report.exec` | `manifest.json` + light `pulls.json` pass |

All four are independent — the exec summary computes its own top-line and does **not** depend on
the sibling reports' output, so parallel fan-out is safe.

## Step 3 — Present

Collect each subagent's returned path + headline and present **one** consolidated message:

- A short line per report: its headline + the file path (under `reports/prs-insights/`).
- Note the run directory the dataset came from (so a rerun of one report can reuse it).

Then offer to circulate the set — a shareable **Artifact**, a GitHub issue, or a Linear doc —
but the markdown files are always the deliverable. Never paste full report bodies into the
final message; link the files.

## Notes

- If `prs.fetch` errors, surface it and stop — check `gh auth status` first.
- If the user asked for a subset of reports, spawn only those subagents.
- If a subagent fails, report which one and keep the others' results.

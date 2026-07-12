---
name: prs-coaching
description: >
  Example preset — just the developer-coaching report. Runs the /prs-insights workflow with only
  the dev report ("what did we keep getting wrong in review this week, and how do we stop it").
  Team-wide over the last 7 days by default; scope to yourself with --users. A thin wrapper over
  /prs-insights; copy it to make your own preset.
metadata:
  category: workflow
  tags: [pr, insights, preset, example, coaching, dev]
  status: ready
  version: 1
allowed-tools: ["Bash", "Read", "Skill", "Agent"]
---

# /prs-coaching — developer-coaching report only

This is a **preset example** of the `/prs-insights` workflow. It holds no orchestration logic of
its own — it just calls the default workflow with `--reports dev`.

Run the **`/prs-insights`** workflow with:

- `--reports dev`
- everything else (`--users`, `--since`/`--days`, `--repo`) passed through **verbatim** from
  `$ARGUMENTS`.

Then present its consolidated result as `/prs-insights` normally would. For "my PRs this week",
pass `--users <your-login>`.

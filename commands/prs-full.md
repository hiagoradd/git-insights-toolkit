---
name: prs-full
description: >
  Example preset — the whole toolkit in one shot. Runs the /prs-insights workflow with all four
  built-in reports (Delivery KPIs, Review Collaboration, Developer Coaching, Executive Summary).
  Team-wide over the last 7 days by default. A thin wrapper over /prs-insights; copy it to make
  your own preset.
metadata:
  category: workflow
  tags: [pr, insights, preset, example, reports]
  status: ready
  version: 1
allowed-tools: ["Bash", "Read", "Skill", "Agent"]
---

# /prs-full — run every built-in report

This is a **preset example** of the `/prs-insights` workflow. It holds no orchestration logic of
its own — it just calls the default workflow with `--reports all`.

Run the **`/prs-insights`** workflow with:

- `--reports all`
- everything else (`--users`, `--since`/`--days`, `--repo`) passed through **verbatim** from
  `$ARGUMENTS`.

Then present its consolidated result as `/prs-insights` normally would.

# 🛠️ PR Insights — Reinforcement

<!--
FILL-IN TEMPLATE. Replace every {{placeholder}}. Tables for anything countable, ████░░ bars for
distributions, 🔴 critical / 🟠 blocker / 🟡 suggestion. Every narrative number must trace to a
table below it. This report is the evidence behind an applied set of guidance changes — it is
**not committed**; /prs-reinforce uses it directly as the **PR description**.
-->

**Scope:** {{scope_label}} · **Repo:** {{repo}} · **Window:** {{since}} → {{until}}
**Classified comments:** {{comment_count}} (excl. bots, self-replies, bare praise) · **Systemic patterns:** {{pattern_count}}

## Executive summary

{{2–4 sentences. Name the biggest recurring pattern driving these changes. State how many patterns
map to guidance we ALREADY have (a rule / CLAUDE.md / skill that isn't landing) vs. have no guidance
yet — that ratio is the headline. Say how many proposals were applied vs. routed to the PR body as
manual notes.}}

## Feedback that drove this (severity)

| Severity | Count | Share |
|---|---|---|
| 🔴 Critical | {{n}} | {{bar}} {{pct}} |
| 🟠 Blocker | {{n}} | {{bar}} {{pct}} |
| 🟡 Suggestion | {{n}} | {{bar}} {{pct}} |

## Systemic patterns → reinforcements

*Ranked by `recurrence × severity × preventability`. Cheapest layer: automation > strengthen existing (rule / CLAUDE.md / skill or agent) > new guidance > process.*

| # | Theme | Sev | Recurrence (PRs) | Already covered? | Cheapest layer | Target file | Status |
|---|---|---|---|---|---|---|---|
{{one row per systemic pattern. "Already covered?" names the specific .claude/rule, CLAUDE.md line, or skill/agent (or "none"). "Status" ∈ ✅ applied / 📝 PR-body note (non-applyable) / ⏭ not selected}}

## Applied changes

*The concrete edits in this PR's diff.*

{{numbered list. For each applied proposal: the file, whether it MODIFIES existing guidance or ADDS
new, and a 1–2 line description of the change + why (recurrence + PR refs).}}

## Not auto-applied — do manually

*Chosen suggestions whose target lives outside this checkout (installed plugin, external path) or is
process-only. This section is part of the PR description (the whole report is the PR body).*

{{list, or "none". For each: target + the exact text/action, and why it couldn't be auto-applied.}}

## Notes / caveats

- {{window caveat if the signal was thin; note recurrence threshold was ≥3}}
- Reinforcements **propose** the cheapest fix; the diff review gate is the final check on any
  in-place rewrite.
- Trends are stateless today — say "n/a first run" until run history is persisted.

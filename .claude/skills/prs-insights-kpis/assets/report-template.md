# 📊 PR Insights — Delivery KPIs

<!--
FILL-IN TEMPLATE. Replace every {{placeholder}}. Keep the section order and display
conventions: tables for anything countable, text bars (████░░) for distributions. Every
number in the narrative must trace to a table below it.
-->

**Scope:** {{scope_label}} · **Repo:** {{repo}} · **Window:** {{since}} → {{until}}
**PRs:** {{pr_count}} ({{merged}} merged, {{closed_unmerged}} closed-unmerged, {{open}} open)

## Headline

{{2–4 sentences on delivery health: throughput, merge rate, first-pass clean-merge %,
and the single most notable size or cycle-time fact. Numbers only — no code-quality
judgment (that's the developer-coaching report).}}

## KPI dashboard

| Metric | Value | Note |
|---|---|---|
| PRs opened | {{pr_count}} | {{type_breakdown_oneline}} |
| Merge rate | {{merge_rate}} | {{merged}}/{{pr_count}} |
| Avg / median files changed | {{files_avg}} / {{files_median}} | |
| Avg additions / deletions | {{add_avg}} / {{del_avg}} | |
| Time to first review | {{ttfr}} | create → first review |
| Review time (create → approve) | {{review_time}} | |
| Merge lag (approve → merge) | {{merge_lag}} | |
| Avg review rounds | {{review_rounds}} | distinct review submissions per PR |
| Comment density | {{comments_per_pr}} / PR · {{comments_per_100loc}} per 100 LOC | excludes bots + self-replies |
| First-pass clean merge | {{pct_clean}} | {{clean_note}} |

## PRs by type

| Type | PRs | Share | | Avg files | Avg +/− |
|---|---|---|---|---|---|
{{one row per type present, with a ████░░ bar for share; include a Total row}}

> {{one-line read on where volume and size concentrate}}

## Contributors

| Author | PRs | Merged | Avg size (files) | Clean-merge % |
|---|---|---|---|---|
{{one row per author, sorted by PRs desc}}

## Notes / caveats

- Comment density excludes bot and author-self-reply rows (`excluded` flag from the dataset).
- {{note any PRs missing timestamps that were dropped from a cycle-time average}}
- Window filters by PR **creation** date; PRs opened earlier but active in-window are not counted.

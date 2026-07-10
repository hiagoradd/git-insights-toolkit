# 🧭 PR Insights — Developer Coaching

<!--
FILL-IN TEMPLATE. Replace every {{placeholder}}. Tables for anything countable, ████░░ bars for
distributions, 🔴 critical / 🟠 blocker / 🟡 suggestion for severity. Every narrative number must
trace to a table below it. Drop the "Trend" body until persisted runs exist.
-->

**Scope:** {{scope_label}} · **Repo:** {{repo}} · **Window:** {{since}} → {{until}}
**Actionable comments:** {{comment_count}} (excl. bots, self-replies, bare praise) · **Reviewers:** {{reviewer_count}}

## Executive summary

{{3–5 sentences. Name the single biggest recurring pattern and whether it's code-quality or
process. Call out any genuine critical bug. State how many recurring patterns map to guidance
we ALREADY have (a rule / CLAUDE.md / skill that isn't landing) vs. have no guidance yet — that
ratio is the headline.}}

## Comments by severity

| Severity | Count | Share |
|---|---|---|
| 🔴 Critical | {{n}} | {{bar}} {{pct}} |
| 🟠 Blocker | {{n}} | {{bar}} {{pct}} |
| 🟡 Suggestion | {{n}} | {{bar}} {{pct}} |

_Caveat: {{how many PRs got a formal "Changes requested" vs. severity-judged-by-content}}._

## Theme × PR-type matrix

*Where feedback clusters. Rows = theme, cells = comment count.*

| Theme | FE | BE | Full-stack | E2E | Misc | Total |
|---|---|---|---|---|---|---|
{{one row per theme that occurred, then a Total row}}

> {{one-line read: which type carries the most feedback per PR, and what each type skews toward}}

## Systemic patterns

*Ranked by `recurrence × severity × preventability`.*

{{numbered list. For each: the pattern, hit count + PR refs, and whether it's preventable by
automation / rule / process. Mark any pattern that ALREADY has a rule as "not landing".}}

## Reinforcement recommendations

*Each pattern → cheapest enforcement layer → concrete proposal. Automation > strengthen existing guidance (rule / CLAUDE.md / skill or agent) > new guidance > process.*

| Pattern | Already covered? | Cheapest fix | Concrete proposal (file + text) |
|---|---|---|---|
{{one row per systemic pattern; "Already covered?" names the specific .claude/rule, CLAUDE.md line, or skill/agent that covers it (or "none"); "Concrete proposal" gives the exact file + text and says whether it MODIFIES existing guidance or ADDS new}}

## Per-PR appendix

| PR | Type | Author | Title | Comments (🔴/🟠/🟡) | Top theme | Merged |
|---|---|---|---|---|---|---|
{{one row per PR that drew actionable comments}}

## Trend (week-over-week)

{{If prior runs are persisted: chart severity mix, theme frequency, and cycle deltas vs. prior
periods; flag any theme recurring across ≥2 periods as "not landing despite feedback".
Otherwise: "n/a — first run / stateless mode."}}

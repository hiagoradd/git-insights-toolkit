# 🤝 PR Insights — Review Collaboration

<!--
FILL-IN TEMPLATE. Replace every {{placeholder}}. Tables for anything countable, ████░░ bars
for distributions. Every narrative number must trace to a table below it.
-->

**Scope:** {{scope_label}} · **Repo:** {{repo}} · **Window:** {{since}} → {{until}}
**Reviewers:** {{reviewer_count}} · **Review submissions:** {{review_count}} (excl. bots)

## Headline

{{2–4 sentences: is review load balanced or concentrated? Any bus-factor risk (one person
carrying most reviews)? Are any authors reviewing their own work only / going unreviewed?
How responsive is first review?}}

## Reviewer load

| Reviewer | Reviews given | Share | | PRs touched |
|---|---|---|---|---|
{{one row per reviewer, sorted desc, with a ████░░ share bar; include a Total row}}

> {{one-line read: concentration — e.g. "top reviewer = 48% of all submissions"}}

## Who reviews whom

*Rows = author, columns = reviewer. Cells = review submissions. Highlights silos & gaps.*

| Author ↓ / Reviewer → | {{reviewer_a}} | {{reviewer_b}} | … | Reviewed by (distinct) |
|---|---|---|---|---|
{{one row per author; flag authors reviewed by only 0–1 distinct people}}

## Responsiveness

| Metric | Value | Note |
|---|---|---|
| Median time to first review | {{ttfr_median}} | create → first review |
| P90 time to first review | {{ttfr_p90}} | slowest tail |
| PRs merged with no non-author review | {{unreviewed_count}} | {{unreviewed_pr_list}} |
| Median review rounds | {{rounds_median}} | |

## Bottlenecks & bus-factor

{{numbered list: reviewers who are single points of failure, authors whose work only one person
reviews, and the slowest-to-first-review PRs. Each item cites counts + PR refs.}}

## Notes / caveats

- Bot review submissions (`is_bot`) are excluded.
- Small windows are noisy; concentration reads need several weeks to be a trend, not a snapshot.
- Self-reviews (author == reviewer) are reported separately, not counted as peer review.

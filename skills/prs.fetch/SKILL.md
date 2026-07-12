---
name: prs.fetch
description: Collect and persist a PR review dataset for a GitHub repo — fetches pull requests over a time window (metadata, files, reviews, review comments, issue comments) via the GitHub CLI, applies deterministic enrichment (PR type/stack, comment layer, bot/self-reply exclusion flags), and writes a reusable run directory plus a manifest. Data only — it does NOT generate any report; the prs-insights-* report skills and the /prs-insights command consume its output. Use when you need the raw classified PR dataset, or as the first step before any PR report. Triggers on: "fetch pr data", "collect pr dataset", "prs-insights fetch", "get pr review data".
---

# PR Insights — Fetch

Produces the shared dataset that every `prs-insights-*` report reads. **This skill only
collects and enriches data — it never renders a report.** Its deliverable is a run directory
path plus a one-line manifest summary.

## Parameters

Parse from the request; both optional.

- **users** — comma-separated GitHub logins. **Default: all users** (whole team). Map a name
  like "just Hiago's" → the login (`hiagoradd`); ask only if a name is ambiguous.
- **time-period** — **Default: last 7 days.** Accept "last 30 days", "last 2 weeks", an
  explicit `--since YYYY-MM-DD`, etc. Convert to `--days N` or `--since`.

## Workflow

### 1. Pick a stable run directory

Key it by window + scope so reruns and debugging don't re-hit the GitHub API and other skills
can point back to the same data:

```
<scratch>/prs-insights/<since>_to_<until>_<scope>/
```

`<scope>` is `team` for the all-users default, otherwise the `+`-joined logins. Use the session
scratch dir as `<scratch>`. If that directory already exists and is populated (has
`manifest.json`), reuse it instead of refetching — mention that you did.

### 2. Run the fetch script

It handles date math, author-OR filtering, pagination, parallel per-PR fetching, and the
deterministic enrichment — and avoids the zsh word-split gotcha:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prs.fetch/scripts/fetch-pr-data.sh" \
  --out "<scratch>/prs-insights/<since>_to_<until>_team" --days 7        # all users, 7 days
# or:  --users "alice,bob"  --since 2026-06-01
```

If the script errors, check `gh auth status` first — everything depends on the GitHub CLI.

### 3. Confirm the outputs and return the path

The run dir will contain:

| File | Contents |
|---|---|
| `pulls.json` | PR metadata + `files[]`, enriched with `type` and `sublabels[]` |
| `reviews.ndjson` | review submissions (state, timestamps), enriched with `is_bot` |
| `review-comments.ndjson` | inline comments, enriched with `is_bot`, `is_self_reply`, `excluded`, `layer` |
| `issue-comments.ndjson` | PR-body comments, enriched with `is_bot`, `is_self_reply`, `excluded` |
| `manifest.json` | repo, window (`since`/`until`), `scope`, `pr_count`, and per-file row counts |

The enrichment rules are mechanical (no LLM) — see `references/taxonomy.md` for the exact
`type`/`layer`/exclusion definitions. `manifest.json` is the source of truth for the window and
scope (the run-dir name is only cosmetic).

**Deliverable:** report the run-dir path and a one-line manifest summary (PR count + row
counts). Do not print the dataset contents or generate a report.

## Scope & boundaries

- **Read-only on the codebase.** The only thing written is the run directory under the scratch
  dir. It never modifies source or opens PRs.
- **Deterministic only.** It does *not* classify theme or severity — those are judgment calls
  the `prs-report.dev` report makes on demand.
- The window filters by PR **creation** date; a PR created earlier but reviewed in-window won't
  appear unless `--since` is widened.

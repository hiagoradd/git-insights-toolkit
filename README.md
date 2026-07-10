# git-insights-toolkit

A [Claude Code](https://claude.ai/code) plugin that turns your GitHub pull-request history into shareable analytics. It fetches a PR dataset **once**, then fans out into four independent reports — delivery KPIs, review collaboration, developer coaching, and an executive summary — each written to its own Markdown file.

Everything runs inside Claude Code and against the [GitHub CLI](https://cli.github.com/); no servers and no API keys.

## Why

Most PR dashboards answer "how many?" This toolkit is built to answer "how are we working?":

- **Delivery** — throughput, PR size, cycle time, first-pass clean-merge rate.
- **Collaboration** — who reviews whom, reviewer-load concentration, time-to-first-review, and bus-factor risk.
- **Coaching** — recurring review feedback classified into themes, mapped to the cheapest way to stop it recurring (automation → rule → process).
- **Leadership** — a one-page, plain-language digest for PMs and managers.

## Install

Add this repo as a plugin marketplace, then install the plugin:

```
/plugin marketplace add hiagoradd/git-insights-toolkit
/plugin install git-insights-toolkit@git-insights-toolkit
```

Or point Claude Code at a local checkout for development:

```
claude --plugin-dir /path/to/git-insights-toolkit
```

## Usage

Run the orchestrator command (namespaced by the plugin):

```
/git-insights-toolkit:prs-insights
```

It defaults to **all authors over the last 7 days**. It fetches the dataset once (`prs.fetch`), generates the four reports in parallel, and returns each file's path plus a short headline. The report files under `reports/prs-insights/` are the deliverable.

### Options

All optional and free-form — the command parses them from natural language too ("last 30 days, just Alice").

| Option | Effect |
|---|---|
| `--users "login1,login2"` | Restrict to specific PR authors (default: everyone) |
| `--since YYYY-MM-DD` | Start of the window (filters by PR **creation** date) |
| `--days N` | Window as a number of days back (default: 7) |
| `--repo owner/name` | Target a specific repo (default: your current `gh` default repo) |

You can also request a single report — e.g. "kpis only" or "just coaching" — and the orchestrator will fetch once and spawn only that one.

### Example

```
/git-insights-toolkit:prs-insights --users "alice,bob" --days 30
```

→ fetches the last 30 days of PRs authored by `alice` and `bob`, then writes four reports and prints their paths.

## Reports

| Report | Skill | What it tells you |
|---|---|---|
| **Delivery KPIs** | `prs-report.kpis` | Volume, PR size, cycle times, merge & first-pass clean-merge rates, per-contributor throughput |
| **Review Collaboration** | `prs-report.collab` | Reviewer-load concentration, who-reviews-whom matrix, time-to-first-review, bus-factor risk |
| **Developer Coaching** | `prs-report.dev` | Recurring review feedback classified by theme & severity → concrete reinforcement proposals |
| **Executive Summary** | `prs-report.exec` | One-page, plain-language PR-health digest for PMs and leadership |

The **fetch** step (`prs.fetch`) is the shared data producer: it pulls PR metadata, files, reviews, review comments, and issue comments, then applies deterministic (no-LLM) enrichment — PR type/stack, comment layer, and bot/self-reply exclusion flags — into a reusable run directory. Only the **coaching** report uses an LLM, to classify feedback themes.

## Requirements

- The [GitHub CLI](https://cli.github.com/) (`gh`), authenticated with `repo` scope — everything depends on it. Check with `gh auth status`.
- [`jq`](https://jqlang.github.io/jq/) for the fetch/enrichment step.

## Adapting to your repo layout

PR/comment **labels** (classifying a PR as front-end / back-end / full-stack / e2e-testing, and tagging which layer a comment touches) are inferred from file **paths**. The default path rules are tuned for a monorepo laid out as `apps/web`, `apps/api`, `packages/`, with Prisma migrations under `packages/database/prisma/migrations/` and tests under `apps/web/e2e/` and `*.spec.ts`.

Against a repo with a different layout, the toolkit still runs and every quantitative metric (volume, cycle time, reviewer load, etc.) is fully accurate — only the type/layer *labels* degrade to `misc`/unclassified. To adapt it, edit the `jq` classification blocks in `skills/prs.fetch/scripts/fetch-pr-data.sh` and the matching rules in `skills/prs.fetch/references/taxonomy.md`.

## Notes & limitations

- The window filters by PR **creation** date. A PR created before `--since` but reviewed inside the window won't appear unless you widen `--since`.
- PR search is capped at 200 results per run; narrow the window or author set for very high-volume repos.
- Week-over-week trends are not yet persisted, so each run is stateless ("n/a on first run").
- The toolkit is read-only on your codebase — the only things it writes are the report files and a cached dataset in your scratch directory.

## License

MIT

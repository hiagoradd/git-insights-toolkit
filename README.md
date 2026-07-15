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

### Commands

| Command | What it does |
|---|---|
| `/prs-insights` | The customizable orchestrator — pick reports, ask questions, set scope/window (see [Options](#options)) |
| `/prs-insights-grill` | Guided "grill me" front-end — interviews you, then runs the right `/prs-insights` for you |
| `/prs-full` | Preset: all four built-in reports (`--reports all`) |
| `/prs-coaching` | Preset: just the developer-coaching report (`--reports dev`) |

All are namespaced by the plugin (e.g. `/git-insights-toolkit:prs-insights`). The presets are thin wrappers over `/prs-insights` — copy them to make your own.

### Options

All optional:

| Option | Effect |
|---|---|
| `--reports <list\|all>` | Which reports to run: any of `kpis`, `collab`, `dev`, `exec` (comma- or `+`-separated), a custom `prs-report.<name>`, or `all` (default = the four built-ins) |
| `--ask "<prompt>"` | Answer a one-off free-form question against the dataset — no skill needed. Can combine with `--reports` |
| `--fetch-only` | Fetch the dataset and stop; returns the run-dir path so you can point your own agent at it |
| `--run-dir <path>` | Reuse an existing populated run directory instead of refetching (no GitHub round-trip) |
| `--users "login1,login2"` | Restrict to specific PR authors (default: everyone) |
| `--since YYYY-MM-DD` | Start of the window (filters by PR **creation** date) |
| `--days N` | Window as a number of days back (default: 7) |
| `--repo owner/name` | Target a specific repo (default: your current `gh` default repo) |
| `--layout <path>` | Path-classification config for PR `type` / comment `layer` (default: repo-local `.prs-insights.json`, else the bundled monorepo layout — see [Adapting to your repo layout](#adapting-to-your-repo-layout)) |

Everything is free-form — the command parses these from natural language too ("kpis only for the last 30 days, just Alice"). You can request a single report (e.g. "just coaching") and the orchestrator fetches once and spawns only that one.

### Not sure what you want? Get grilled

If you don't want to remember the flags, run the guided front-end and let it interview you:

```
/git-insights-toolkit:prs-insights-grill
```

It asks what you want to learn (leadership snapshot, delivery numbers, review-collaboration health, coaching, or a question of your own), whose work, and over what window — with adaptive follow-ups — then derives the right `/prs-insights` invocation (a subset of the built-in reports and/or a composed custom question), shows it to you, and runs it on approval.

### Keep a custom report

When you produce a custom report (via `--ask` or the grill workflow), the toolkit offers to **save it as a reusable report skill**. Say yes and it scaffolds a `prs-report.<name>` skill — SKILL.md + a fill-in template, just like the built-ins — into **your own repo** under `.claude/skills/`, derived from the report you just got. From then on you can re-run it any time with `/prs-insights --reports <name>`. See [`docs/custom-reports.md`](docs/custom-reports.md).

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

PR/comment **labels** (classifying a PR as front-end / back-end / full-stack / e2e-testing, and tagging which layer a comment touches) are inferred from file **paths** using a small **layout config** — an ordered list of path-pattern rules. The bundled default (`skills/prs.fetch/references/layouts/monorepo.json`) is tuned for a monorepo laid out as `apps/web`, `apps/api`, `packages/`, with Prisma migrations under `packages/database/prisma/migrations/` and tests as `*.spec.ts` / `apps/web/e2e/`.

Against a repo with a different layout, the toolkit still runs and every quantitative metric (volume, cycle time, reviewer load, etc.) is fully accurate — only the type/layer *labels* degrade to `misc`/unclassified. To fix the labels, **drop a `.prs-insights.json` in your repo root** (no code editing):

```jsonc
{
  "name": "my-app",
  "rules": [
    { "match": ["(^|/)(test|tests|__tests__)/", "\\.(test|spec)\\.[jt]sx?$"], "role": "test", "layer": "test" },
    { "match": ["(^|/)migrations/"], "role": "backend", "layer": "migration", "sublabel": "migration" },
    { "match": ["^(src|client|web|frontend)/"], "role": "frontend", "layer": "FE" },
    { "match": ["^(server|api|backend|lib)/"], "role": "backend", "layer": "BE" }
  ]
}
```

Each file/comment path is classified by the **first** rule whose `match` regex hits it, so list the most specific rules first. `role` (`frontend`/`backend`/`test`/`none`) drives the PR type; `layer` labels comments; `sublabel` is optional. A ready-to-copy starter lives at `skills/prs.fetch/references/layouts/flat.json`.

The config is discovered from `.prs-insights.json` in the current directory, or pass `--layout path/to/config.json` explicitly. The chosen layout name is recorded in each run's `manifest.json`.

## Notes & limitations

- The window filters by PR **creation** date. A PR created before `--since` but reviewed inside the window won't appear unless you widen `--since`.
- PR search is capped at 200 results per run; narrow the window or author set for very high-volume repos.
- Week-over-week trends are not yet persisted, so each run is stateless ("n/a on first run").
- The toolkit is read-only on your codebase — the only things it writes are the report files and a cached dataset in your scratch directory.

## License

MIT

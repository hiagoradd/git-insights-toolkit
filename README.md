# git-insights-toolkit

A Claude Code plugin for PR analytics. It fetches a GitHub pull-request dataset once, then fans out into four independent reports: delivery KPIs, review collaboration, developer coaching, and an executive summary.

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

It defaults to all users over the last 7 days. It fetches the dataset once (`prs-insights-fetch`), then generates the four reports in parallel and returns their paths.

### Options

- `--users "login1,login2"` — restrict to specific authors
- `--since YYYY-MM-DD` / `--days N` — widen the window (filters by PR **creation** date)

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `prs-insights` | Orchestrator — fetch once, fan out the four reports |
| Skill | `prs-insights-fetch` | Data producer — pulls & enriches the PR dataset via `gh` |
| Skill | `prs-insights-kpis` | Quantitative delivery dashboard |
| Skill | `prs-insights-collab` | Reviewer load, who-reviews-whom, bus factor |
| Skill | `prs-insights-dev` | LLM-classified recurring feedback → reinforcement proposals |
| Skill | `prs-insights-exec` | One-page PM/leadership digest |

## Requirements

- The [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with `repo` scope — everything depends on it.

## License

MIT

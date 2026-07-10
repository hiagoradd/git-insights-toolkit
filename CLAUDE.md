# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo is a **Claude Code plugin** (not an application). It ships one slash command and five skills that form a PR-analytics pipeline for the **cxnch-platform** GitHub repo. There is no build, no test suite, and no application runtime — the "code" is Markdown skill/command definitions (YAML frontmatter + prose) plus a single Bash fetch script. Data flows as JSON/NDJSON, enriched with `jq`, sourced via the `gh` GitHub CLI.

## Running it

Everything runs *inside Claude Code*, not from a shell. The entry point is the orchestrator command:

```
/git-insights-toolkit:prs-insights            # all users, last 7 days
/git-insights-toolkit:prs-insights --users "login1,login2" --since 2026-06-01
/git-insights-toolkit:prs-insights --days 30
```

The fetch script can be run directly for debugging the data layer:

```bash
bash skills/prs.fetch/scripts/fetch-pr-data.sh \
  --out <dir> [--users "a,b"] [--since YYYY-MM-DD | --days N] [--repo owner/name]
```

**Hard dependency:** `gh` authenticated with `repo` scope. Also requires `jq`. If anything fails, check `gh auth status` first. In skill/command context the plugin root is `${CLAUDE_PLUGIN_ROOT}`.

## Architecture

Two-layer pipeline: **fetch once, fan out four independent reports.**

```
/prs-insights (command)  → parse args → run fetch ONCE → spawn 4 report subagents in parallel
        │
prs.fetch  → writes a run dir (manifest.json + pulls.json + *.ndjson)
        │                  shared, read-only input
   ┌────────┬────────┬────────┬────────┐
  kpis    collab    dev     exec        each reads the run dir, writes ONE report .md
```

- **`prs.fetch`** is the *only* data producer. It does collection + **deterministic, zero-LLM enrichment** only — never any report or theme/severity judgment.
- The four report skills (**kpis**, **collab**, **dev**, **exec**) all consume the same run dir and run in parallel. `exec` recomputes its own top-line from the dataset rather than reading the sibling reports, so there is genuinely no dependency between the four — parallel fan-out is safe.
- The orchestrator holds only paths + short headlines; the raw dataset and full report bodies never flow back through the command.

### Run directory convention

`<scratch>/prs-insights/<since>_to_<until>_<scope>/` where `<scope>` is `team` (all users) or `+`-joined logins. If a run dir with `manifest.json` already exists, it is **reused** rather than refetched. `manifest.json` is the source of truth for window/scope; the dir name is cosmetic.

Outputs: `pulls.json` (enriched with `type` + `sublabels[]`), `reviews.ndjson` (`is_bot`), `review-comments.ndjson` (`is_bot`, `is_self_reply`, `excluded`, `layer`), `issue-comments.ndjson` (`is_bot`, `is_self_reply`, `excluded`), `manifest.json`.

### Enrichment rules (fetch-pr-data.sh)

All mechanical, defined in `skills/prs.fetch/references/taxonomy.md` and encoded in the `jq` blocks of the script:
- **PR `type`** (front-end / back-end / full-stack / e2e-testing / misc) is inferred from `files[]` **paths**, not the title. `sublabels[]` gets `migration` for Prisma migration paths.
- **comment `layer`** (FE / BE / test / migration / docs / infra) is inferred from the comment's file path.
- **`excluded` = is_bot OR is_self_reply** — bots (`*[bot]` logins) and PR-author self-replies are flagged so reports can drop them.

The **`dev`** skill is the only one that does LLM classification (theme/severity of review feedback) — see `skills/prs-report.dev/references/classification.md` for the fixed theme/severity enums and the "recurring ≥3× → cheapest enforcement" mapping. Every report fills in its own `assets/report-template.md` and writes to `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`.

## Conventions & gotchas

- **Path assumptions are cxnch-platform-specific.** Enrichment keys off `apps/web`, `apps/api`, `packages/`, `packages/database/prisma/migrations/`, `apps/web/e2e/`, `*.spec.ts`. Against a differently-laid-out repo, `type`/`layer` inference degrades to `misc`/`null`.
- **The window filters by PR *creation* date only.** A PR created before `--since` but reviewed in-window will be missed unless you widen `--since`.
- `gh search prs --limit 200` caps results; per-PR fetches run under `xargs -P 10` and swallow individual errors (`|| true`), so a partial dataset fails soft rather than aborting.
- The fetch script targets **portable Bash** (`set -euo pipefail`, GNU-then-BSD `date` fallback). Preserve that when editing.
- Reports are **read-only except for the single report file each writes**. Trends are stateless ("n/a first run") — there is no persisted run history yet.

## Editing skills

Each skill lives under `skills/<name>/` with a `SKILL.md` (frontmatter `name` + `description` that governs when it triggers) and, where relevant, `assets/` (report templates) and `references/` (taxonomy/classification rules the skill reads at runtime). When changing the data schema in `fetch-pr-data.sh`, update `references/taxonomy.md`, the `manifest.json` file notes, and any consuming report skill together — they are coupled by field names.

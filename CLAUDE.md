# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo is a **Claude Code plugin** (not an application). It ships a small set of slash commands and skills that form a PR-analytics pipeline for the **cxnch-platform** GitHub repo. There is no build, no test suite, and no application runtime — the "code" is Markdown skill/command definitions (YAML frontmatter + prose) plus a single Bash fetch script. Data flows as JSON/NDJSON, enriched with `jq`, sourced via the `gh` GitHub CLI.

## Running it

Everything runs *inside Claude Code*, not from a shell. The customizable entry point is `/prs-insights`; the rest are thin presets over it.

```
/git-insights-toolkit:prs-insights                              # all reports, all users, last 7 days
/git-insights-toolkit:prs-insights --reports dev --users hiagoradd --days 7
/git-insights-toolkit:prs-insights --reports kpis,collab --since 2026-06-01
/git-insights-toolkit:prs-insights --fetch-only                 # data only → run-dir path (hand to your own agent)
/git-insights-toolkit:prs-insights --run-dir <path> --ask "do we need more FE or BE devs?"
/git-insights-toolkit:prs-full                                  # preset: all four built-ins
/git-insights-toolkit:prs-coaching --users hiagoradd            # preset: dev report only
```

`/prs-insights` params (all optional): `--reports <list|all>` · `--ask "<prompt>"` · `--fetch-only` · `--run-dir <path>` · `--users` · `--since`/`--days` · `--repo`. See `commands/prs-insights.md`.

The fetch script can be run directly for debugging the data layer:

```bash
bash skills/prs.fetch/scripts/fetch-pr-data.sh \
  --out <dir> [--users "a,b"] [--since YYYY-MM-DD | --days N] [--repo owner/name]
```

**Hard dependency:** `gh` authenticated with `repo` scope. Also requires `jq`. If anything fails, check `gh auth status` first. In skill/command context the plugin root is `${CLAUDE_PLUGIN_ROOT}`.

## Architecture

Layered pipeline: **fetch once, fan out selected independent reports.** The report layer is an **open registry** — the four built-ins are just the seed set.

```
prs.fetch  → writes a run dir (manifest.json + pulls.json + *.ndjson)   ← the stable DATA CONTRACT
        │                       shared, read-only input
report providers (OPEN REGISTRY): any prs-report.<name> skill
   kpis · collab · dev · exec (built-ins)  +  your prs-report.<custom>   each reads the run dir, writes ONE .md
        ▲   name→skill resolution: report "X" ⇒ skill "prs-report.X"
/prs-insights (DEFAULT command) → parse args → run fetch ONCE → spawn the selected report subagents in parallel
        ▲   thin delegators (fixed params, no logic of their own)
presets: /prs-full (--reports all) · /prs-coaching (--reports dev)
```

- **`prs.fetch`** is the *only* data producer. It does collection + **deterministic, zero-LLM enrichment** only — never any report or theme/severity judgment. Its run-dir schema is the **public contract** every report (built-in or custom) depends on — documented in `docs/custom-reports.md`.
- **Report providers** are selected by name: report `X` ⇒ skill `prs-report.X`. `--reports all` runs only the four built-ins; custom reports are opt-in by name. Any `prs-report.*` skill is instantly selectable with **no command changes** — that's the extension point.
- All reports are independent (`exec` recomputes its own top-line rather than reading siblings), so parallel fan-out over any subset is safe.
- **Modes beyond named reports:** `--ask "<prompt>"` spawns a generic subagent that answers a one-off question against the dataset (no skill needed); `--fetch-only` stops after fetch and returns the run-dir path; `--run-dir <path>` reuses an existing populated run dir with no GitHub round-trip.
- All orchestration logic lives in `/prs-insights`. `/prs-full` and `/prs-coaching` are thin delegators that just call it with fixed params (and double as copyable examples).
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

## Editing skills & commands

Each skill lives under `skills/<name>/` with a `SKILL.md` (frontmatter `name` + `description` that governs when it triggers) and, where relevant, `assets/` (report templates) and `references/` (taxonomy/classification rules the skill reads at runtime). Commands live under `commands/<name>.md`. When changing the data schema in `fetch-pr-data.sh`, update `references/taxonomy.md`, the `manifest.json` file notes, the `docs/custom-reports.md` contract, and any consuming report skill together — they are coupled by field names.

### Adding a report (the extension point)

Drop a `skills/prs-report.<name>/` skill following `docs/custom-reports.md` — it reads the shared run dir, fills its own `assets/report-template.md`, writes `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`, and returns only path + headline. It's then selectable via `/prs-insights --reports <name>` with **no command edits**. Don't add it to `--reports all` (that's the built-in-only set). To add a new preset command, copy `commands/prs-full.md` and change the `--reports` value — keep presets as pure delegators so orchestration logic stays only in `/prs-insights`.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo is a **Claude Code plugin** (not an application). It ships a small set of slash commands and skills that form a PR-analytics pipeline for **any GitHub repo** (it targets your current `gh` default repo unless `--repo` is passed). There is no build, no test suite, and no application runtime — the "code" is Markdown skill/command definitions (YAML frontmatter + prose) plus a single Bash fetch script. Data flows as JSON/NDJSON, enriched with `jq`, sourced via the `gh` GitHub CLI.

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
/git-insights-toolkit:prs-insights-grill                        # guided: interview me, then delegate to /prs-insights
```

`/prs-insights` params (all optional): `--reports <list|all>` · `--ask "<prompt>"` · `--fetch-only` · `--run-dir <path>` · `--users` · `--since`/`--days` · `--repo` · `--layout <config>` · `--format <files|single|webpage>`. See `commands/prs-insights.md`.

The fetch script can be run directly for debugging the data layer:

```bash
bash skills/prs.fetch/scripts/fetch-pr-data.sh \
  --out <dir> [--users "a,b"] [--since YYYY-MM-DD | --days N] [--repo owner/name] [--layout <config.json>]
```

**Hard dependency:** `gh` authenticated with `repo` scope. Also requires `jq`. If anything fails, check `gh auth status` first. In skill/command context the plugin root is `${CLAUDE_PLUGIN_ROOT}`.

## Architecture

Layered pipeline: **fetch once, fan out selected independent reports.** The report layer is an **open registry** — the four built-ins are just the seed set.

```
prs.fetch  → writes a run dir (manifest.json + pulls.json + *.ndjson)   ← the stable DATA CONTRACT
        │                       shared, read-only input
shared JUDGMENT skills (infra, prs.* namespace):
   prs.classify → classified-issues.ndjson (theme/severity, the ONE LLM pass)
   prs.reinforce → reinforcement-proposals.json (recurring pattern → cheapest guidance change)
        │                       reused by the dev report AND /prs-reinforce
report providers (OPEN REGISTRY): any prs-report.<name> skill
   kpis · collab · dev · exec (built-ins)  +  your prs-report.<custom>   each reads the run dir, writes ONE .md
        ▲   name→skill resolution: report "X" ⇒ skill "prs-report.X"
/prs-insights (DEFAULT command, READ-ONLY) → parse args → run fetch ONCE → spawn the selected report subagents in parallel
/prs-reinforce (MUTATING command) → fetch → classify → reinforce → APPLY edits + report → branch + PR   (default: autonomous; --interactive adds pick + diff-confirm gates)
        ▲   thin delegators (fixed params, no logic of their own)  ·  /prs-insights-grill (asks, then delegates)
presets: /prs-full (--reports all) · /prs-coaching (--reports dev)
```

- **`prs.fetch`** is the *only* data producer. It does collection + **deterministic, zero-LLM enrichment** only — never any report or theme/severity judgment. Its run-dir schema is the **public contract** every report (built-in or custom) depends on — documented in `docs/custom-reports.md`.
- **Shared judgment skills (`prs.classify`, `prs.reinforce`)** are the single home for the LLM layers. `prs.classify` is the **one** classification pass — theme/severity/actionability/resolution per comment, written as `classified-issues.ndjson` (enums in `skills/prs.classify/references/classification.md`). `prs.reinforce` clusters recurring themes and maps each to the cheapest guidance change, returning **structured** `proposals[]` (`reinforcement-proposals.json`; ladder in `skills/prs.reinforce/references/reinforcement.md`). Both are infra in the `prs.*` namespace (like `prs.fetch`), not selectable reports. The **dev report** and **`/prs-reinforce`** both consume them, so the enums have one source of truth. These artifacts are separate files so `prs.fetch` stays zero-LLM.
- **`/prs-reinforce` is the one mutating command.** Same fetch→classify→reinforce pipeline as the reports, then the action loop the read-only reports refuse: **apply** edits to the repo's `.claude` guidance (additive fully, in-place rewrites best-effort) → write a reinforcement report → branch + PR. Only the guidance edits are committed (staged by explicit path, never `git add -A`); the reinforcement report is written to the **run dir in scratch — outside the analyzed repo's working tree** — so it can't be staged regardless of the target repo's `.gitignore`, and its content becomes the **PR description** (via `gh pr create --body-file <run_dir>/reinforce-report.md`), never a committed file. **`--interactive` (default `false`)** controls the human gates: `false` = autonomous (apply *all* `applyable` proposals and open the PR with no pick or diff confirmation — the PR is the review surface); `true` = multi-select pick + explicit diff-review confirmation before pushing. Two guards hold in **both** modes and are non-skippable: analyzed repo (`manifest.repo`) == local checkout before editing, and "no systemic pattern → no PR". Proposals targeting installed plugins / paths outside the checkout are `applyable:false` and become PR-body notes, never file edits. `/prs-insights` stays read-only; keep the write/read split.
- **Report providers** are selected by name: report `X` ⇒ skill `prs-report.X`. `--reports all` runs only the four built-ins; custom reports are opt-in by name. Any `prs-report.*` skill is instantly selectable with **no command changes** — that's the extension point.
- All reports are independent (`exec` recomputes its own top-line rather than reading siblings), so parallel fan-out over any subset is safe.
- **Modes beyond named reports:** `--ask "<prompt>"` spawns a generic subagent that answers a one-off question against the dataset (no skill needed); `--fetch-only` stops after fetch and returns the run-dir path; `--run-dir <path>` reuses an existing populated run dir with no GitHub round-trip.
- **Output format (`--format <files|single|webpage>`):** a *presentation-only* concern. The report subagents always write their per-report `.md` files (source of truth). For `files` (default) the orchestrator just presents paths + headlines. For `single`/`webpage`, Step 3 **delegates to a `prs.compose` subagent** (infra namespace, like `prs.fetch`/`prs.report-scaffold`) that reads the finished report files and produces one combined document (`single`) or a self-contained Artifact page (`webpage`), returning only the path/URL + headline. Delegating keeps the report bodies out of the orchestrator's context (its core invariant). Never touches fetch or the report subagents. `/prs-insights-grill` surfaces the choice as its fourth core question and passes the derived flag through.
- **Creating a reusable report (assisted):** two skills write a `prs-report.<name>` skill (SKILL.md + template) into the **user's own repo** (`.claude/skills/`, not this plugin), instantly selectable via `--reports <name>` — the assisted counterpart to hand-authoring per `docs/custom-reports.md`. **`prs.report-scaffold`** is *reactive*: after an `--ask` report (direct or via `/prs-insights-grill`), `/prs-insights` Step 4 offers to persist it, and saying yes scaffolds from the produced report. **`prs.report-creator`** is *proactive*: the user describes the report they want up front (inline, or via "grill me"/`--grill` to be interviewed) and it designs one from scratch — forking a built-in's structure when the spec references one, always authoring a **parameterized** report (scope flows from `--users` at run time, never a hardcoded login). Both target the user's repo and read the contract from `${CLAUDE_PLUGIN_ROOT}/docs/custom-reports.md`.
- All orchestration logic lives in `/prs-insights`. `/prs-full` and `/prs-coaching` are thin delegators that just call it with fixed params (and double as copyable examples).
- **`/prs-insights-grill`** is an *interactive front-end*, not a pure delegator: it runs an adaptive `AskUserQuestion` interview (goal / scope / window / output, then follow-ups), derives a `--reports` subset and/or a composed `--ask` prompt plus `--format`, confirms it, then delegates to `/prs-insights`. It still holds no fetch/report logic — the derivation-from-answers is its only job.
- The orchestrator holds only paths + short headlines; the raw dataset and full report bodies never flow back through the command.

### Run directory convention

`<scratch>/prs-insights/<since>_to_<until>_<scope>/` where `<scope>` is `team` (all users) or `+`-joined logins. If a run dir with `manifest.json` already exists, it is **reused** rather than refetched. `manifest.json` is the source of truth for window/scope; the dir name is cosmetic.

Outputs (from `prs.fetch`): `pulls.json` (enriched with `type` + `sublabels[]`), `reviews.ndjson` (`is_bot`), `review-comments.ndjson` (`is_bot`, `is_self_reply`, `excluded`, `layer`), `issue-comments.ndjson` (`is_bot`, `is_self_reply`, `excluded`), `manifest.json`. Two **optional derived** files appear once the judgment skills run: `classified-issues.ndjson` (`prs.classify`) and `reinforcement-proposals.json` (`prs.reinforce`) — reused if present.

### Enrichment rules (fetch-pr-data.sh)

All mechanical, defined in `skills/prs.fetch/references/taxonomy.md` and encoded in the `jq` blocks of the script:
- **PR `type`** and **comment `layer`** are inferred from `files[]`/comment **paths** (not titles) via a **layout config** — an ordered list of path-pattern rules resolved as `--layout <path>` → repo-local `.prs-insights.json` → bundled `references/layouts/monorepo.json` (the default, which reproduces the original built-in behavior). Each path takes the first matching rule's `role` (→ PR `type`: front-end / back-end / full-stack / e2e-testing / misc) and `layer` (FE / BE / test / migration / docs / infra); `sublabel` (e.g. `migration`) is appended to `sublabels[]`.
- **`excluded` = is_bot OR is_self_reply** — bots (`*[bot]` logins) and PR-author self-replies are flagged so reports can drop them.

LLM classification lives in **`prs.classify`** (theme/severity of review feedback) — see `skills/prs.classify/references/classification.md` for the fixed enums — and the "recurring ≥3× → cheapest enforcement" mapping lives in **`prs.reinforce`** (`skills/prs.reinforce/references/reinforcement.md`). The **`dev`** report composes both and renders them; it no longer defines the enums itself. Every report fills in its own `assets/report-template.md` and writes to `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`.

## Conventions & gotchas

- **Path-based enrichment is layout-configurable.** The bundled default (`skills/prs.fetch/references/layouts/monorepo.json`) is tuned to one monorepo layout (`apps/web`, `apps/api`, `packages/`, …). On a different layout, supply a repo-local `.prs-insights.json` (or `--layout`); without one, every quantitative metric is still accurate and only the `type`/`layer` labels degrade to `misc`/`null`. See "Adapting to your repo layout" in the README and `references/layouts/flat.json` for a starter.
- **The window filters by PR *creation* date only.** A PR created before `--since` but reviewed in-window will be missed unless you widen `--since`.
- `gh search prs --limit 200` caps results; per-PR fetches run under `xargs -P 10` and swallow individual errors (`|| true`), so a partial dataset fails soft rather than aborting.
- The fetch script targets **portable Bash** (`set -euo pipefail`, GNU-then-BSD `date` fallback). Preserve that when editing.
- Reports are **read-only except for the single report file each writes**. Trends are stateless ("n/a first run") — there is no persisted run history yet.
- **`/prs-reinforce` is the only command that mutates the repo / opens PRs.** It is **autonomous by default** (`--interactive false`): applies all `applyable` proposals and opens the PR with no pick/diff gate. `--interactive true` restores the multi-select pick + explicit diff-review confirmation. The analyzed-repo == local-checkout guard and the "no pattern → no PR" check are **always** on (non-skippable, both modes). Keep `/prs-insights` (and all reports) read-only.
- **Enum single-source-of-truth:** theme/severity enums live only in `skills/prs.classify/references/classification.md`; the reinforcement ladder only in `skills/prs.reinforce/references/reinforcement.md`. The dev report and `/prs-reinforce` both consume `prs.classify`/`prs.reinforce` output — don't re-define these enums anywhere else.

## Editing skills & commands

Each skill lives under `skills/<name>/` with a `SKILL.md` (frontmatter `name` + `description` that governs when it triggers) and, where relevant, `assets/` (report templates) and `references/` (taxonomy/classification rules the skill reads at runtime). Commands live under `commands/<name>.md`. When changing the data schema in `fetch-pr-data.sh`, update `references/taxonomy.md`, the `manifest.json` file notes, the `docs/custom-reports.md` contract, and any consuming report skill together — they are coupled by field names. The path-classification rules live in the layout config (`references/layouts/*.json`), **not** hardcoded in the script — edit or add a config there rather than the `jq` blocks.

### Adding a report (the extension point)

Drop a `skills/prs-report.<name>/` skill following `docs/custom-reports.md` — it reads the shared run dir, fills its own `assets/report-template.md`, writes `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`, and returns only path + headline. It's then selectable via `/prs-insights --reports <name>` with **no command edits**. Don't add it to `--reports all` (that's the built-in-only set). To add a new preset command, copy `commands/prs-full.md` and change the `--reports` value — keep presets as pure delegators so orchestration logic stays only in `/prs-insights`.

Two **assisted authoring** skills write exactly this shape (SKILL.md + template) into the **user's** repo (`.claude/skills/prs-report.<name>/`): **`prs.report-scaffold`** derives one from a just-produced `--ask` report (invoked by `/prs-insights` Step 4 on opt-in), and **`prs.report-creator`** designs one from a natural-language spec up front (given inline or via "grill me"/`--grill`). Note the namespace split — report skills are `prs-report.*` (selectable by `--reports`); both authoring skills sit in the `prs.*` infra namespace (like `prs.fetch`) so they never collide with the report registry.

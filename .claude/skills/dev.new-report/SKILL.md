---
name: dev.new-report
description: >
  Scaffold a new BUILT-IN prs-report.<name> report skill into this plugin's shipped skills/ dir
  (SKILL.md + assets/report-template.md), following docs/custom-reports.md and matching the four
  existing built-ins (kpis, collab, dev, exec). This is the maintainer-side authoring helper for the
  git-insights-toolkit repo itself — distinct from prs.report-scaffold, which writes into a *user's*
  repo. Use when developing a new first-class report for the plugin. Triggers on: "new built-in
  report", "add a report to the plugin", "scaffold a prs-report skill", "create a report provider".
metadata:
  category: dev
  status: ready
---

# dev.new-report — author a new built-in report

Create a new first-class `prs-report.<name>` skill **inside this plugin** (`skills/`), so it ships
to plugin users and is selectable via `/prs-insights --reports <name>`. This is the internal
counterpart to `prs.report-scaffold` (which targets an end user's repo and inlines the data
contract). Here the contract lives in-repo, so **reference it, don't duplicate it**.

## Before you start — read the sources of truth

- `docs/custom-reports.md` — the data contract (run-dir schema + the two consumption rules).
- Any existing built-in as a style model — `skills/prs-report.kpis/SKILL.md` (deterministic) or
  `skills/prs-report.dev/SKILL.md` (judgment-based, consumes `prs.classify`/`prs.reinforce`).
- `commands/prs-insights.md` — the built-in registry and the `--reports all` set (lines ~31–34 and
  ~88–97).

## Steps

1. **Pick a name.** Short kebab-case `<name>`. Reject collisions with the built-ins
   (`kpis`, `collab`, `dev`, `exec`) and any existing `skills/prs-report.*`. Confirm with the user.

2. **Decide: deterministic or judgment?**
   - *Deterministic* (like `kpis`/`collab`/`exec`) — computed straight off `pulls.json` +
     `*.ndjson`. No LLM classification.
   - *Judgment* (like `dev`) — needs theme/severity. Then **consume `prs.classify`** output
     (`classified-issues.ndjson`); do **not** invent new enums (single-source rule — enums live only
     in `skills/prs.classify/references/classification.md`).

3. **Write two files** under `skills/prs-report.<name>/`:
   - `SKILL.md` — frontmatter `name: prs-report.<name>` + a trigger-rich `description`; body follows
     the built-in shape: **Input** (use given run-dir else run `prs.fetch`; read `manifest.json` for
     window/scope — never parse the dir name) → **Compute** → **Render** (fill the template, write
     `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`) → **Return** path + 3–5 line
     headline only → **Boundaries** (read-only except the one report file).
   - `assets/report-template.md` — house style: `**Scope:** … · **Repo:** … · **Window:** since →
     until` header, `## Headline`, tables for anything countable, `████░░` text bars, `## Notes /
     caveats`. Every narrative number must trace to a table.

4. **Enforce the two consumption rules** in Compute: drop `excluded == true` rows; compare across PR
   types by **density**, never raw counts.

5. **Registry decision (ask the user).** New report skills are selectable by name with **no command
   changes**. Only if this report should join the default `all` set do you edit
   `commands/prs-insights.md` (the built-in registry list *and* the "`all` = these four/five"
   wording). Default is **leave `all` alone** — opt-in by name — unless the user wants it in `all`.

6. **Hand off to shipping.** Remind the user this is a new file set on a protected `main` — land it
   via a PR. If they want, invoke `dev.ship` with a `feat:` title (a new report is a minor bump).

## Boundaries

Author only — write under `skills/prs-report.<name>/` (and, only on explicit opt-in, the registry in
`commands/prs-insights.md`). Never run a report, refetch data, or touch `plugin.json` version
(release-please owns it — see `.claude/rules/versioning.md`).

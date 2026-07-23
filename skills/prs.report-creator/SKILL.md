---
name: prs.report-creator
description: >
  Author a brand-new reusable prs-report.<name> report skill from a natural-language description —
  for a user who knows the report they want up front, with no prior /prs-insights --ask run. Reads
  the intent (given inline, or elicited by grilling), designs a parameterized report against the
  toolkit's data contract, and scaffolds SKILL.md + assets/report-template.md into the *user's own
  repo* under .claude/skills/, selectable via /prs-insights --reports <name>. The proactive
  counterpart to prs.report-scaffold (which promotes an already-produced report). Triggers on:
  "create a report", "I want a report that…", "build a report agent", "new custom report",
  "make me a report skill", "report-creator".
metadata:
  category: authoring
  tags: [pr, insights, report, skill, author, create, custom, authoring]
  status: ready
---

# prs.report-creator — author a new report skill from a description

Create a durable `prs-report.<name>` skill **in the user's own repository** (not this plugin) from a
plain-language description of the report they want — *before* any report has been run. Once written,
it's selectable via `/prs-insights --reports <name>` with no command changes (the same name→skill
resolution the built-ins use).

**How this differs from `prs.report-scaffold`:** that skill is *reactive* — it promotes a report the
user already produced with `/prs-insights --ask`. This one is *proactive* — the user describes the
report from scratch and this skill designs it. Same target (the user's repo), same data contract,
opposite entry point.

## Input — the spec, given or grilled

The one input is a **spec**: a natural-language description of the report the user wants (e.g. "all
the KPIs plus how many PRs were bugfixes/hotfixes", or "everything in dev-coaching plus a per-user
KPI breakdown"). Get it one of two ways:

- **Grill mode** — if the prompt contains **"grill me"** or a **`--grill`** token, *don't* author
  yet. Run a short adaptive `AskUserQuestion` interview (goal → what to measure → which existing
  reports to build on → any specific angle), then synthesize the answers into a spec and proceed.
- **Direct mode** — otherwise, treat the prompt text as the spec. Only fall back to a grill if the
  spec is empty or too vague to design a report from.

## Step 1 — Design the report from the spec

Turn the spec into a concrete report design. Read the data contract first —
`${CLAUDE_PLUGIN_ROOT}/docs/custom-reports.md` (run-dir schema + the two consumption rules) — the
creator runs inside the plugin, so this path resolves here (the *generated* skill must not rely on
it — see Step 3).

Decide, and confirm anything ambiguous with the user:

- **Deterministic or judgment?** Metrics computed straight off `pulls.json` + `*.ndjson` are
  deterministic. Anything needing theme/severity of feedback is **judgment** → the report must
  consume **`prs.classify`** output (`classified-issues.ndjson`) and use its enums, never invent new
  ones. (The bugfix/hotfix split in the example is *deterministic* — derive it from
  `labels[]`/`title`/`type`, no classification needed.)
- **Fork an existing report?** If the spec references a built-in ("I loved dev-coaching", "all the
  kpis"), read that report's skill at `${CLAUDE_PLUGIN_ROOT}/skills/prs-report.<base>/` and **fork**
  its compute + template as the starting structure, then layer the additions on. Forking (not
  runtime-composing) keeps every report independent, as the pipeline requires.
- **Keep it parameterized — never hardcode scope.** "For a specific user" means the report gets a
  **per-user section**, driven by whatever `--users` is passed when it's later run (read from
  `manifest.json`). Do **not** bake a login into the skill, or it can't be reused.

## Step 2 — Pick a name

Propose a short kebab-case `<name>` derived from the spec (e.g. "kpis plus bugfix breakdown" →
`kpis-plus-fixes`). Confirm it with the user. Reject collisions with the built-ins (`kpis`,
`collab`, `dev`, `exec`) and any existing `.claude/skills/prs-report.*` in the user's repo — ask for
another until it's unique.

## Step 3 — Write the skill into the user's repo

Create `.claude/skills/prs-report.<name>/` **in the user's current project** (not this plugin —
create the dirs). Two files:

**`SKILL.md`** — must be **self-contained**: embed the data-contract essentials inline, because the
plugin's `docs/custom-reports.md` path will **not** resolve from the user's repo. Follow this shape:

```markdown
---
name: prs-report.<name>
description: >
  Generate the <Report Title> for a window of PRs — <what it measures / the question it answers>.
  Reads a shared prs.fetch run directory. Triggers on: "<phrase>", "<phrase>".
---

# <Report Title>

Input: a `prs.fetch` run-dir path if given, else run `prs.fetch` first. Read `manifest.json`
for window/scope/repo (source of truth — never parse the dir name).

## Data (guaranteed enriched fields)
- `pulls.json` — `number,title,state,user,created_at,merged_at,closed_at,changed_files,`
  `additions,deletions,commits,labels[],base,head,files[]`; enriched `type`
  (front-end/back-end/full-stack/e2e-testing/misc) + `sublabels[]`.
- `reviews.ndjson` — `pr,user,state,submitted_at,body`; enriched `is_bot`.
- `review-comments.ndjson` — `pr,user,path,line,created_at,body`; enriched
  `is_bot,is_self_reply,excluded,layer` (FE/BE/test/migration/docs/infra/null).
- `issue-comments.ndjson` — `pr,user,created_at,body`; enriched `is_bot,is_self_reply,excluded`.
- (judgment only) `classified-issues.ndjson` from `prs.classify` — reuse if present.

## Two rules (always)
1. Drop `excluded == true` rows from comment counts (`excluded = is_bot OR is_self_reply`).
2. Compare across PR types by **density** (per PR / per 100 LOC), never raw counts.

## Compute
<the exact metrics this report needs, from the spec. Note per-user sections read the scope
from manifest.json — parameterized, never a hardcoded login. Classify theme/severity via
prs.classify only if the report needs judgment fields.>

## Render
Fill `assets/report-template.md` and write
`reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`.

## Return
Only the file path + a 3–5 line headline — never the full body. Read-only except that one file.
```

**`assets/report-template.md`** — a fill-in template with `{{placeholder}}` tokens in the house
style: a `**Scope:** … · **Repo:** … · **Window:** since → until` header, a `## Headline`, tables
for anything countable, text bars like `████░░` for distributions, and a `## Notes / caveats`
section. Every narrative number must trace to a table. If you forked a built-in, start from its
template.

## Step 4 — Confirm & explain

Report the two file paths you wrote. Tell the user the report is now selectable via
`/prs-insights --reports <name>` (and can ride alongside built-ins, e.g. `--reports kpis,<name>`).
Note that `--reports all` will **not** include it — custom reports are opt-in by name — and that a
newly created project skill may only be discoverable after Claude Code reloads skills (e.g. next
session).

**Author only — do not run the report.** This skill writes the skill files and stops; generating a
report is `/prs-insights --reports <name>`'s job.

## Boundaries

- Write **only** under `.claude/skills/prs-report.<name>/` in the user's project. Never modify this
  plugin, the dataset, `commands/`, or other files.
- Never refetch data, run a report, or edit the built-in registry (`--reports all` stays the
  built-in-only set).
- The generated `SKILL.md` must be self-contained — it lives in the user's repo, where
  `${CLAUDE_PLUGIN_ROOT}` and the plugin's `docs/` do not resolve.

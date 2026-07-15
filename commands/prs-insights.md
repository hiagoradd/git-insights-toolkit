---
name: prs-insights
description: >
  The customizable PR-insights workflow. Fetches the PR dataset once (prs.fetch), then runs the
  selected report providers — built-in (kpis, collab, dev, exec) or your own custom
  prs-report.* skills — in parallel, each writing its own markdown file, and presents the paths +
  headlines. Also supports fetch-only (hand the dataset to your own agent), reusing an existing
  run directory, and one-off inline questions via --ask. Team-wide over the last 7 days by default.
metadata:
  category: workflow
  tags: [pr, insights, review, reports, orchestration, kpi, coaching, custom]
  status: ready
  version: 2
allowed-tools: ["Bash", "Read", "Skill", "Agent"]
---

# /prs-insights — the customizable PR insights workflow

Fetch the dataset once, then fan out the **selected** report providers **in parallel**, each
reading the shared run directory and writing its own file. This command holds only paths + short
summaries — never the raw dataset or the full report bodies.

This is the flexible default: **you decide what runs.** The `/prs-full` and `/prs-coaching`
commands are thin presets that just call this workflow with fixed params — copy them to make your
own.

## Arguments

`$ARGUMENTS` — all optional, free-form. Parse out:

- **`--reports <list|all>`** — which reports to run. A comma/`+`-separated list of report names,
  or `all`. **Default: `all`** = the four built-ins (`kpis`, `collab`, `dev`, `exec`). Names
  resolve by convention: report `X` ⇒ skill `prs-report.X`, so a custom skill like
  `prs-report.fe-be-need` is selectable as `--reports fe-be-need` with **zero changes here**.
  Accept natural phrasings too ("kpis only", "just coaching", "dev + exec").
- **`--ask "<prompt>"`** — a one-off report answering a free-form question against the dataset,
  without authoring a skill. Can be combined with `--reports`.
- **`--fetch-only`** — run the fetch step and stop; return the run-dir path + manifest summary so
  you can point your own agent at the dataset. Skips all report fan-out.
- **`--run-dir <path>`** — reuse an existing populated run directory (one that has
  `manifest.json`) instead of fetching. Lets you fan out more reports over data you already
  pulled, with no GitHub round-trip.
- **`--users`** — comma-separated logins, or a name to map (`hiagoradd`). Default: all users (team).
- **`--since YYYY-MM-DD` / `--days N`** — the window. Accept "last 30 days", "last 2 weeks", etc.
  Default: last 7 days.
- **`--repo owner/name`** — target repo. Default: the fetch script's default.
- **`--layout <path>`** — path-classification config for PR `type` / comment `layer`. Default:
  a `.prs-insights.json` in the working dir, else the bundled monorepo layout. See
  `docs/custom-reports.md` / `skills/prs.fetch/references/taxonomy.md`.
- **`--format <files|single|webpage>`** — how to deliver the selected reports. **Default: `files`**
  = one markdown file per report (the current behavior). `single` = also stitch them into one
  combined markdown document. `webpage` = also render them as a single self-contained, shareable
  **Artifact** web page. In every mode the per-report `.md` files under `reports/prs-insights/`
  are still written and remain the source of truth — `single`/`webpage` add a consolidated view on
  top. Governs presentation only (Step 3); it has no effect on fetch or on the report subagents.

`--users`, `--since`/`--days`, `--repo`, and `--layout` are passed through to `prs.fetch`
unchanged; they are ignored when `--run-dir` is given (the run dir's `manifest.json` already fixes
the window/scope/layout).

## Step 1 — Get the dataset

- If **`--run-dir`** was given: use it directly. Confirm it has `manifest.json` (if not, tell the
  user and stop). Read the one-line manifest summary from it. Do **not** fetch.
- Otherwise: invoke the **`prs.fetch`** skill with the parsed `--users` / window / `--repo`.
  Capture the **run-dir path** and the **one-line manifest summary** it returns. Do **not** read
  the dataset files yourself — the report subagents do that. Do not re-implement fetching (no
  direct `gh` calls here) — go through the skill so its conventions (stable run dir, enrichment,
  manifest) hold.

If **`--fetch-only`**: report the run-dir path + manifest summary, tell the user they can point
their own agent at it (schema in `docs/custom-reports.md`), and **stop here** — no report fan-out.

## Step 2 — Fan out report subagents (parallel)

Build the list of things to run: each `--reports` name, plus one entry for `--ask` if given.
Spawn **one subagent per entry** with the **Agent** tool, issuing all the Agent calls **in a
single message** so they run concurrently.

**Named report** (built-in or custom) — resolve name `X` ⇒ skill `prs-report.X` and use this
prompt shape:

> Follow the **`prs-report.<name>`** skill to generate its report. The `prs.fetch` run directory
> already exists at **`<run-dir-path>`** — use it directly, do not refetch. Manifest:
> `<one-line manifest summary>`. Write the report file as the skill specifies and **return only**
> the file path plus a 3–5 line headline summary — not the full report body.

The built-in registry (any `prs-report.*` skill works the same way):

| Report | Skill | Reads |
|---|---|---|
| Delivery KPIs | `prs-report.kpis` | `pulls.json`, `reviews.ndjson` |
| Review Collaboration | `prs-report.collab` | `reviews.ndjson`, `pulls.json` |
| Developer Coaching | `prs-report.dev` | comments + `pulls.json` (classifies theme/severity) |
| Executive Summary | `prs-report.exec` | `manifest.json` + light `pulls.json` pass |

`all` fans out only these four built-ins; custom reports are opt-in by name.

**Inline `--ask`** — spawn a generic report subagent with this prompt:

> Read the `prs.fetch` run directory at **`<run-dir-path>`** — do not refetch. Its schema is
> defined in **`docs/custom-reports.md`** (a `manifest.json` plus four enriched files; drop rows
> where `excluded == true`, and normalize cross-type comparisons by density, not raw counts).
> Using that dataset, answer / produce: **`<ask prompt>`**. Write the result to
> `reports/prs-insights/<since>_to_<until>_<scope>_<slug>.md` (derive `<slug>` from the question;
> read `since`/`until`/`scope` from `manifest.json`). **Return only** the file path plus a 3–5
> line headline — not the full body.

All reports are independent (the exec summary computes its own top-line and does **not** depend on
the sibling reports' output), so parallel fan-out is always safe.

## Step 3 — Present (honoring `--format`)

Collect each subagent's returned path + headline. The per-report `.md` files under
`reports/prs-insights/` are always written first and are the source of truth — `--format` only
decides what you additionally build and present.

- **`files`** (default) — present **one** consolidated message:
  - A short line per report: its headline + the file path (under `reports/prs-insights/`).
  - Note the run directory the dataset came from (so a rerun of one report — or a follow-up
    `--run-dir <path> --ask "…"` — can reuse it).
  - Then offer to circulate the set — a shareable **Artifact**, a GitHub issue, or a Linear doc.

- **`single`** or **`webpage`** — **don't read the report bodies here.** Spawn **one** subagent on
  the **`prs.compose`** skill (via the Agent tool), handing it: the `format` (`single`/`webpage`),
  the list of per-report file paths + their names, and the run-dir path + manifest one-liner. It
  reads those files, builds the combined document (and, for `webpage`, publishes a self-contained
  Artifact), and returns **only** the resulting path/URL + a headline. Present what it returns plus
  the run directory; note the per-report `.md` files remain the durable deliverable. Delegating
  keeps the report bodies out of this command's context (the orchestrator invariant).

Never paste full report bodies into the final chat message; link the files / Artifact.

## Step 4 — Offer to save a custom report (only if `--ask` was used)

If this run produced a custom **`--ask`** report (a one-off, not a named `prs-report.*` skill), ask
the user — once — whether they want to **keep it as a reusable report skill** so the same report can
be re-run later via `--reports <name>`. Built-in named reports are already skills, so skip the offer
for them.

If the user says yes, invoke the **`prs.report-scaffold`** skill, handing it the produced report's
file path, the original `--ask` prompt, and the run-dir path + manifest one-liner. It scaffolds a
`prs-report.<name>` skill (SKILL.md + `assets/report-template.md`) into the **user's own repo**
(`.claude/skills/`), following `docs/custom-reports.md`. Don't scaffold anything yourself here —
delegate to the skill. If the user declines, do nothing.

## Notes

- If `prs.fetch` errors, surface it and stop — check `gh auth status` first.
- Run only the reports the user selected; if none and no `--ask`, default to `all`.
- If a subagent fails, report which one and keep the others' results.
- **Unknown report name:** don't fail silently — say the name didn't resolve to a `prs-report.*`
  skill, and list the discoverable ones (`prs-report.kpis`, `.collab`, `.dev`, `.exec`, plus any
  custom skills present).
- Authoring your own report? See `docs/custom-reports.md` — drop a `prs-report.<name>` skill and
  it's instantly selectable via `--reports <name>`.

---
name: prs-insights-grill
description: >
  The guided "grill me" front-end to the PR-insights workflow. Instead of picking flags up front,
  it interviews you — what do you want to learn, whose work, over what window, any specific angle —
  then derives the right /prs-insights invocation (a subset of the built-in reports and/or a
  composed custom question), confirms it, and runs it. Use when you're not sure which report or
  flags you want. Triggers on: "grill me", "interview me", "guided pr insights", "help me build a
  PR report", "what report do I want", "ask me what to report".
metadata:
  category: workflow
  tags: [pr, insights, interactive, grill, guided, workflow]
  status: ready
  version: 1
allowed-tools: ["AskUserQuestion", "Bash", "Read", "Skill", "Agent"]
---

# /prs-insights-grill — the guided "grill me" workflow

This command holds **no fetch / fan-out / present logic of its own.** It *interviews* the user to
work out what they actually want, derives a `/prs-insights` invocation from the answers, confirms
it, then runs the **`/prs-insights`** workflow — which does the real work (fetch once, fan out the
selected reports + any `--ask` in parallel, present paths + headlines). Think of it as an
interactive sibling of the `/prs-full` / `/prs-coaching` presets: same delegation, but the params
are *asked for* instead of hardcoded.

Do **not** read the dataset or report bodies here. All of that stays in `/prs-insights` and the
report subagents.

## Step 1 — Core questions (one `AskUserQuestion` call)

Ask these four together. Seed defaults from `$ARGUMENTS` if the user already hinted at any (e.g.
"grill me about last month" → pre-fill the window; "put it on a webpage" → pre-fill output); still
confirm.

- **Goal** — *what do you want to learn?* (`multiSelect: true`)
  - *Leadership snapshot* → report `exec`
  - *Delivery numbers* → report `kpis`
  - *Review process / collaboration health* → report `collab`
  - *Coaching — what we keep getting wrong in review* → report `dev`
  - *A specific question of my own* → a custom `--ask`
  - *Everything* → `all` (the four built-ins)
- **Scope** — *whose work?* (single)
  - *Whole team* (default — omit `--users`) · *Specific people* · *Just me*
- **Window** — *over what period?* (single)
  - *Last 7 days* (`--days 7`, default) · *Last 30 days* (`--days 30`) ·
    *Last quarter* (`--days 90`) · *Custom* (ask for a date or day count)
- **Output** — *how do you want the results delivered?* (single) → maps to `--format`
  - *A file per report* (`--format files`, default) · *One combined document*
    (`--format single`) · *A shareable webpage* (`--format webpage`)

## Step 2 — Adaptive follow-ups (branch on the Step-1 answers)

Ask only the ones that apply. Keep each to one focused `AskUserQuestion`; combine when natural.

- **Goal includes Coaching (`dev`)** → *which themes matter most?* (`multiSelect`, from the fixed
  enums in `skills/prs-report.dev/references/classification.md`): correctness-bug · convention/style
  · architecture/layering · test-coverage · error-handling/observability · migration-hygiene ·
  pr-scope/hygiene · performance · security · a11y · naming/docs. A narrowing to specific themes
  becomes a composed `--ask` (see Step 3); "all themes" just runs `dev` as-is.
- **Goal includes Delivery (`kpis`)** → *which numbers matter most?* (`multiSelect`): throughput ·
  cycle time · merge rate · first-pass clean-merge · comment density · per-contributor. Emphasis
  only steers focus; the `kpis` report already covers these.
- **Goal includes Collaboration (`collab`)** → *which angle?* (`multiSelect`): reviewer load ·
  who-reviews-whom · review latency (time-to-first-review) · PRs merged without review · bus factor.
- **Goal includes A specific question** → have them type it (the free-text "Other" field). Capture
  the raw question verbatim for the `--ask` prompt.
- **Scope is Specific people / Just me** → capture the login(s) via free text. Map a plain name to a
  login if you can; for *Just me*, default to the current git user's login
  (`git config user.name` / the `gh` login) and confirm.
- **Window is Custom** → capture a `--since YYYY-MM-DD` or a `--days N`.

## Step 3 — Compose the `/prs-insights` request

Map the answers to args:

- **`--reports`** — the built-in names from the Goal selections (`exec` / `kpis` / `collab` /
  `dev`), joined with `,`; use `all` if *Everything* was chosen. Omit entirely if the **only** goal
  was a custom question.
- **`--ask "<prompt>"`** — include **only when** (a) the user asked a custom question, or (b) a
  Step-2 follow-up narrowed things beyond what the selected built-in already delivers (e.g. "just
  the convention/style + test-coverage themes, per FE file"). Compose **one** grounded prompt that
  names the concrete dataset fields it needs (schema in `docs/custom-reports.md`). Don't restate the
  drop-`excluded` / normalize-by-density rules — `/prs-insights`'s own `--ask` template already
  does. Combine multiple emphases into a single `--ask`; don't emit several.
- **`--users`** — from Scope (omit for whole team).
- **Window** — `--days` / `--since` from the Window answer.
- **`--format`** — from the Output answer (`files` / `single` / `webpage`). Omit when it's the
  default (`files`).
- If the user somehow selected nothing and gave no question, default to **`--reports all`**.

## Step 4 — Confirm before running

Show the derived one-liner and ask *Run it / Adjust* (`AskUserQuestion`). Example:

```
/prs-insights --reports dev --ask "Across FE files, which attract the most convention/style and
test-coverage review comments?" --users hiagoradd --days 30 --format webpage
```

On **Adjust**, revisit the relevant question and re-derive. On **Run it**, continue.

## Step 5 — Delegate & present

Run the **`/prs-insights`** workflow with the derived args (exactly as `/prs-coaching` and
`/prs-full` delegate to it), then present its consolidated result — the per-report headline + file
path lines, and the run directory — as `/prs-insights` normally would. Never paste full report
bodies; link the files.

If the interview produced a custom `--ask`, `/prs-insights` will (in its Step 4) offer to **save
that report as a reusable `prs-report.<name>` skill** in the user's repo via `prs.report-scaffold`,
so the grilled-out report can be re-run later with `--reports <name>`. That offer is inherited from
the delegation — don't duplicate it here.

## Notes

- This is a front-end, not an orchestrator: keep every fetch/report decision inside `/prs-insights`.
  If you find yourself fetching or reading `pulls.json` here, stop — hand the derived args off.
- A custom `--ask` can ride alongside built-in reports; `/prs-insights` fans them all out in one
  parallel batch.
- If the interview stalls or the user says "just run it", fall back to `--reports all` over the last
  7 days, team-wide.

---
name: prs.report-scaffold
description: >
  Turn a one-off custom PR report (produced by /prs-insights --ask, or by the grill workflow) into a
  reusable prs-report.<name> skill in the *user's own repo*, so the same report can be re-run any
  time via /prs-insights --reports <name>. Scaffolds SKILL.md + assets/report-template.md under
  .claude/skills/, following the toolkit's data contract. Use after a custom report the user wants to
  keep. Triggers on: "save this report", "make this report reusable", "turn this into a skill",
  "scaffold a report", "keep this report", "run this report again next time".
metadata:
  category: authoring
  tags: [pr, insights, report, skill, scaffold, custom, authoring]
  status: ready
---

# prs.report-scaffold — persist a custom report as a reusable skill

Promote a one-off `--ask` report into a durable `prs-report.<name>` skill **in the user's own
repository** (not this plugin). Once written, it's selectable via `/prs-insights --reports <name>`
with no command changes — the same name→skill resolution the built-ins use.

## Inputs

The caller (usually `/prs-insights` Step 4, or the grill workflow) hands you:

- **`report_path`** — the custom report `.md` that was just produced (under `reports/prs-insights/`).
- **`ask_prompt`** — the original free-form question / `--ask` text that generated it.
- **`run_dir` + manifest one-liner** — for window/scope/repo context.

If any are missing, ask the user. If you can't locate the produced report, ask for its path.

## Steps

1. **Pick a name.** Propose a short kebab-case `<name>` derived from `ask_prompt` (e.g. "which FE
   files attract the most style comments" → `fe-comment-hotspots`). Confirm it with the user. Reject
   names that collide with the built-ins (`kpis`, `collab`, `dev`, `exec`) or an existing
   `.claude/skills/prs-report.*` — ask for another until it's unique.

2. **Learn the report.** Read `report_path` to see exactly which sections, metrics, tables, and bars
   it contains, and read `ask_prompt` for intent. The generated skill must reproduce *this* report's
   shape on future data — so capture the concrete metrics it computed and the data files it used.

3. **Write the skill into the user's repo** at `.claude/skills/prs-report.<name>/` (relative to the
   user's current project root — create the dirs). Two files:

   **`SKILL.md`** — follow the toolkit's authoring contract. Keep it **self-contained** (embed the
   data-contract essentials inline, since the plugin's `docs/custom-reports.md` path won't resolve
   from the user's repo):

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

   ## Two rules (always)
   1. Drop `excluded == true` rows from comment counts (`excluded = is_bot OR is_self_reply`).
   2. Compare across PR types by **density** (per PR / per 100 LOC), never raw counts.

   ## Compute
   <the exact metrics this report needs — transcribed from what the one-off produced. Classify
   theme/severity yourself only if the report needs judgment fields (not in the dataset).>

   ## Render
   Fill `assets/report-template.md` and write
   `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`.

   ## Return
   Only the file path + a 3–5 line headline — never the full body. Read-only except that one file.
   ```

   **`assets/report-template.md`** — generalize the produced report into a fill-in template with
   `{{placeholder}}` tokens, preserving the house style: a `**Scope:** … · **Repo:** … ·
   **Window:** since → until` header, a `## Headline`, tables for anything countable, text bars like
   `████░░` for distributions, and a `## Notes / caveats` section. Every narrative number must trace
   to a table.

4. **Confirm & explain.** Report the two file paths you wrote and tell the user it's now selectable
   via `/prs-insights --reports <name>` (and can ride alongside built-ins, e.g.
   `--reports kpis,<name>`). Note that `--reports all` will **not** include it — custom reports are
   opt-in by name — and that a newly created project skill may only be discoverable after Claude Code
   reloads skills (e.g. next session).

## Boundaries

- Write **only** under `.claude/skills/prs-report.<name>/` in the user's project. Never modify this
  plugin, the dataset, or other files.
- Don't re-run any report or refetch data — you're authoring, not generating.

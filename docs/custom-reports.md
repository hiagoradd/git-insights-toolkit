# Authoring custom PR reports

The toolkit's report layer is an **open registry**. `prs.fetch` produces one shared, enriched
dataset; every report — the four built-ins and any you write — is just a consumer of that
dataset. This doc is the stable contract you code against, plus a scaffold for adding your own
report.

Two ways to add a report:

1. **A durable, reusable report** → author a `prs-report.<name>` skill (below). It's then
   selectable as `/prs-insights --reports <name>` with **no changes to the command**.
2. **A one-off question** → `/prs-insights --ask "your question"`. No skill needed; an ad-hoc
   agent reads the same contract and writes a single report file.

---

## The data contract (the public API)

### Run directory

`prs.fetch` writes a run directory keyed by window + scope:

```
<scratch>/prs-insights/<since>_to_<until>_<scope>/
```

`<scope>` is `team` (all users) or the `+`-joined logins. A run dir is **populated/reusable** iff
it contains `manifest.json`. **`manifest.json` is the source of truth** for window and scope — the
directory *name* is only cosmetic, so read `since` / `until` / `scope` from the manifest, never by
parsing the folder name.

Your report is handed this path (via `--run-dir` or by the workflow). If you're run standalone
with no run dir, run `prs.fetch` first, then proceed.

### `manifest.json`

```json
{
  "repo": "owner/name",
  "since": "YYYY-MM-DD",
  "until": "YYYY-MM-DD",
  "scope": "team",
  "users": ["…"],
  "layout": "monorepo (apps/* + packages/*)",
  "pr_count": 42,
  "files": {
    "pulls.json":             { "rows": 42, "note": "PR metadata; enriched with type + sublabels[]" },
    "reviews.ndjson":         { "rows": 88, "note": "…is_bot" },
    "review-comments.ndjson": { "rows": 210, "note": "…is_bot,is_self_reply,excluded,layer" },
    "issue-comments.ndjson":  { "rows": 61, "note": "…is_bot,is_self_reply,excluded" }
  }
}
```

### The four data files + their guaranteed enriched fields

| File | Shape | Enriched fields you can rely on |
|---|---|---|
| `pulls.json` | JSON array of PRs (`number, title, state, user, created_at, merged_at, closed_at, changed_files, additions, deletions, commits, labels[], base, head, files[]`) | **`type`** ∈ `front-end` / `back-end` / `full-stack` / `e2e-testing` / `misc`; **`sublabels[]`** (e.g. `["migration"]`) |
| `reviews.ndjson` | one review submission per line (`pr, user, state, submitted_at, body`) | **`is_bot`** |
| `review-comments.ndjson` | inline code comments (`pr, user, path, line, created_at, body`) | **`is_bot`**, **`is_self_reply`**, **`excluded`**, **`layer`** ∈ `FE` / `BE` / `test` / `migration` / `docs` / `infra` / `null` |
| `issue-comments.ndjson` | PR-body comments (`pr, user, created_at, body`) | **`is_bot`**, **`is_self_reply`**, **`excluded`** (no `layer` — no path available) |

All enrichment is **mechanical / zero-LLM**, defined in
`skills/prs.fetch/references/taxonomy.md`. `type` and `layer` are inferred from file **paths**,
not titles, via a **layout config** (bundled default `monorepo.json`, or a repo-local
`.prs-insights.json` / `--layout`). The default assumes a monorepo (`apps/web`, `apps/api`,
`packages/`, …); against a different layout the labels degrade to `misc` / `null` (quantitative
fields are unaffected) until you supply a matching config. `manifest.json.layout` records which
config produced the run.

### Optional derived judgment files (added by the shared skills)

`prs.fetch` writes only the four mechanical files above. Two **judgment** artifacts may also appear
in the run dir once the shared LLM skills have run — reuse them if present instead of recomputing:

| File | Written by | Contents |
|---|---|---|
| `classified-issues.ndjson` | `prs.classify` | one row per actionable comment: `pr, pr_type, source, user, path, line, layer, created_at, theme, severity, actionability, resolution, excerpt` (enums in `skills/prs.classify/references/classification.md`) |
| `reinforcement-proposals.json` | `prs.reinforce` | ranked `proposals[]`: `rank, theme, severity, recurrence, pr_refs[], already_covered, cheapest_layer, change_type, target_file, anchor, exact_text, applyable, rationale` |

These are **not** part of `prs.fetch`'s guaranteed output — they exist only after `prs.classify` /
`prs.reinforce` run. They stay separate files so `prs.fetch` remains zero-LLM.

### Two consumption rules (every report must follow)

1. **Drop `excluded == true` rows** from all comment counts. `excluded = is_bot OR is_self_reply`
   — bots and PR-author self-replies are noise for review analysis.
2. **Normalize cross-type comparisons by density** (comments per PR, per 100 LOC), never raw
   counts — otherwise larger/more-active buckets always "win".

### What is NOT in the dataset

Theme, severity, actionability, and resolution are **not** provided — they're judgment calls. If
your report needs them, run the shared **`prs.classify`** skill (it writes
`classified-issues.ndjson` into the run dir), or classify the comments yourself using the same enums
— they live in `skills/prs.classify/references/classification.md`.

---

## Authoring a `prs-report.<name>` skill

Create `skills/prs-report.<name>/SKILL.md`:

```markdown
---
name: prs-report.<name>
description: >
  Generate the <Your Report> for a window of PRs — <what it measures and answers>.
  Reads the shared prs.fetch run directory. Triggers on: "<phrase>", "<phrase>".
---

# <Your Report>

Input: a run-dir path if given, else run `prs.fetch` first.

1. Read `manifest.json` (window/scope) and the file(s) you need from the contract above.
2. Apply the two consumption rules: drop `excluded == true`; compare by density.
3. Compute your metrics. (Classify theme/severity yourself only if you need them.)
4. Fill in `assets/report-template.md` and write:
   `reports/prs-insights/<since>_to_<until>_<scope>_<name>.md`
5. Return **only** the file path + a 3–5 line headline — not the full body.
```

Add `assets/report-template.md` (a fill-in template; see the built-ins under
`skills/prs-report.*/assets/` for the house style — header line `Scope · Repo · Window`, every
narrative number traced to a table, text bars like `████░░`).

That's it. Your report is now selectable:

```
/prs-insights --reports <name>
/prs-insights --reports kpis,<name>        # alongside built-ins
```

`--reports all` runs only the four built-ins; custom reports are always opt-in by name.

### Where custom skills live

Author yours in **your own repo** at `.claude/skills/prs-report.<name>/` (project skills Claude
Code discovers), not inside this plugin. A freshly created project skill may only become selectable
after Claude Code reloads skills (e.g. next session).

---

## Save a one-off `--ask` as a reusable skill (assisted)

You don't have to hand-author. After `/prs-insights --ask "…"` (or the `/prs-insights-grill`
workflow) produces a custom report, the workflow **offers to keep it**: say yes and the
**`prs.report-scaffold`** skill scaffolds a `prs-report.<name>` skill (SKILL.md +
`assets/report-template.md`) into your repo's `.claude/skills/`, derived from the report that was
just produced and this same contract. It's then selectable via `/prs-insights --reports <name>`.
You can also trigger it directly — "save this report as a skill".

---

## Related files

- `skills/prs.fetch/SKILL.md` — the data producer.
- `skills/prs.fetch/references/taxonomy.md` — exact `type` / `layer` / exclusion rules.
- `skills/prs.classify/references/classification.md` — theme/severity enums (shared classification).
- `skills/prs.reinforce/references/reinforcement.md` — the recurring-pattern → guidance ladder.
- `commands/prs-insights.md` — the workflow that dispatches reports.

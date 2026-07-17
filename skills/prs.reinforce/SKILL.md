---
name: prs.reinforce
description: >
  Turn classified PR review feedback into concrete reinforcement proposals — cluster recurring
  themes, survey the target repo's standing-guidance surface (.claude/rules, every CLAUDE.md,
  skills & agents), detect "we already say this and still violate it", and map each recurring
  pattern to the cheapest enforcement layer with an exact file + text proposal. Returns a
  STRUCTURED proposals[] list (and persists it as reinforcement-proposals.json) so both the
  Developer Coaching report (renders it) and the /prs-reinforce workflow (applies it) share one
  implementation. Read-only — it PROPOSES, never edits. Triggers on: "reinforcement
  recommendations", "map feedback to rules", "what guidance should we add", "propose CLAUDE.md
  changes", "enforcement suggestions".
metadata:
  category: analysis
  tags: [pr, insights, reinforcement, guidance, claude-md, rules, shared]
  status: ready
---

# PR Insights — Reinforce

The reinforcement engine, extracted so there is **one** implementation of "recurring feedback →
cheapest guidance change." It reads the shared classified feedback and the target repo's standing
guidance, and returns a **structured `proposals[]`** list. It does **not** render a report and does
**not** edit any file — rendering belongs to the consumer (`prs-report.dev` draws a table;
`/prs-reinforce` applies the edits and opens a PR).

## Inputs

The caller (usually `/prs-reinforce` or `prs-report.dev`) hands you:

- **`run_dir`** — a `prs.fetch` run directory that already contains **`classified-issues.ndjson`**
  (produced by `prs.classify`). If that file is missing, run the **`prs.classify`** skill on the
  run dir first, then continue. Read `manifest.json` for window / scope / repo.
- **`repo_root`** (optional) — the local checkout whose `.claude` surface should be surveyed and
  whose files a downstream apply step could edit. **Default: the current working directory.** This
  matters for applyability (below).

## 1. Cluster recurring themes

Read `classified-issues.ndjson`. Drop `theme: praise` and `question`-only rows from the
recurrence count. Group the rest by **theme**. A theme is a **systemic pattern** when it recurs
**≥ 3 times** in the window (or across ≥ 2 runs once trends exist). Keep the contributing PR
numbers and a representative excerpt for each cluster — you'll cite them.

## 2. Survey the standing-guidance surface

For each recurring theme, survey everything that already tells the team — or their AI tools — how
to write code here, rooted at `repo_root`:

- `.claude/rules/*`
- every `CLAUDE.md` (root, `apps/*/`, `packages/*/`, …)
- **skills & agents** — `.claude/skills/**/SKILL.md`, `.claude/agents/*`, and any installed
  **plugin** skills/agents (their `SKILL.md` / agent frontmatter + body)

Grep the theme's vocabulary across that whole surface to detect **"we already say this and still
violate it"** — the highest-signal finding. Record the specific file (and line/section) that
already covers it, or `none`.

## 3. Map each pattern to the cheapest enforcement layer

Read `references/reinforcement.md` for the full ladder. In short, prefer, in order:

1. **Automation** (lint / CI / typecheck) — cannot be forgotten.
2. **Strengthen existing guidance that isn't landing** — a `.claude/rule`, a `CLAUDE.md` line, or a
   skill/agent that already covers the area but is too weak or ignored. A skill/agent that runs on
   every task is often the cheapest place to reinforce.
3. **New standing guidance** — a new `.claude/rule`, a `CLAUDE.md` line, or a line in the most
   relevant existing skill/agent.
4. **Process / PR-template** — only when a human gate is the only thing that can catch it.

## 4. Emit structured proposals

Return a JSON array, ranked by `recurrence × severity × preventability` (highest first). **Also
write it to `reinforcement-proposals.json` in the run dir** so `/prs-reinforce` can read it without
re-running you. Each proposal:

```json
{
  "rank": 1,
  "theme": "migration-hygiene",
  "severity": "blocker",
  "recurrence": 5,
  "pr_refs": [123, 130, 141],
  "already_covered": ".claude/rules/db.md (§ migrations) — present but ignored",
  "cheapest_layer": "strengthen-existing",
  "change_type": "modify",
  "target_file": ".claude/rules/db.md",
  "anchor": "## Migrations",
  "exact_text": "…the exact block to add or the replacement text…",
  "applyable": true,
  "rationale": "5 comments across 3 PRs; rule exists but lacks the concrete failure case"
}
```

Field notes:

- `cheapest_layer` ∈ `automation` / `strengthen-existing` / `new-guidance` / `process`.
- `change_type` ∈ `add` (new file, or appended block) / `modify` (in-place rewrite of existing
  prose). For `add` to a brand-new file, `anchor` is `null`.
- `exact_text` — the literal text to write. For `modify`, give enough surrounding context that an
  editor can locate the spot unambiguously (or describe the before → after).
- **`applyable`** — `true` only if `target_file` is a writable path **inside `repo_root`** (an
  existing repo file or a new file under it). Set `false` when the target is an **installed plugin**
  file (lives in a plugin cache, outside the checkout), a path outside `repo_root`, or a
  `process`-layer item with no file to edit. A downstream apply step commits only `applyable: true`
  proposals; the rest are surfaced as manual notes (e.g. in a PR body).

## Return

Report the **`reinforcement-proposals.json` path** and a short summary: how many systemic patterns,
how many map to guidance we **already have but isn't landing** vs. have **no guidance yet**, and how
many proposals are `applyable`. Return the structured array to the caller. Do **not** render a
report table or edit any file.

## Scope & boundaries

- **Read-only except one file** — `reinforcement-proposals.json` in the run dir. It **proposes**;
  applying edits and opening PRs is `/prs-reinforce`'s job, gated on user approval.
- Survey the full guidance surface (including installed plugins) so nothing is missed — but flag
  non-checkout targets `applyable: false` so the apply step never tries to commit outside the repo.
- Prioritize by `recurrence × severity × preventability`; "we already say this and still violate
  it" is the highest-signal class — surface it first.

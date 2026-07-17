# Reinforcement mapping — prs.reinforce

The **canonical** ladder for turning a recurring review pattern into the cheapest guidance change.
`prs.reinforce` applies it; `prs-report.dev` and `/prs-reinforce` consume the structured proposals
it produces. (Theme/severity enums live separately, in
`skills/prs.classify/references/classification.md` — this file assumes comments are already
classified.)

## When a pattern qualifies

A theme is a **systemic pattern** when it recurs **≥ 3 comments** in the window (or across ≥ 2 runs
once trends exist). Drop `praise` and pure `question` rows from the recurrence count. Below the
threshold, don't propose standing guidance — one-offs are noise, not policy.

## The standing-guidance surface to survey

Everything that already tells the team, or their AI tools, how to write code here — rooted at the
target repo (`repo_root`, default: the working directory):

- `.claude/rules/*`
- every `CLAUDE.md` (root, `apps/*/`, `packages/*/`, …)
- **skills & agents** — `.claude/skills/**/SKILL.md`, `.claude/agents/*`, and any installed
  **plugin** skills/agents (their `SKILL.md` / agent frontmatter + body)

Grep each recurring theme's vocabulary across that whole surface. Finding an existing rule that
covers a pattern the team **still** violates ("we already say this and still violate it") is the
highest-signal result — it means the gap is reach/strength, not absence.

## The cheapest-layer ladder (prefer earlier)

1. **Automation** (lint / CI / typecheck) — best, cannot be forgotten. Propose the concrete rule /
   config when a linter or type check could catch the pattern mechanically.
2. **Strengthen existing guidance that isn't landing** — a `.claude/rule`, a `CLAUDE.md` line, or a
   **skill/agent** that already covers the area but is too weak, buried, or ignored. Strengthen it
   in place: sharper example, move it earlier, add the missing case. A skill/agent that *runs on
   every task* is often the cheapest reinforcement point, above a passive rule.
3. **New standing guidance** — add it where the team already looks: a new `.claude/rule`, a
   `CLAUDE.md` line, or a line in the most relevant existing skill/agent. Author a brand-new skill
   only when a whole workflow is missing.
4. **Process / PR-template** — only when a human gate is the only thing that can catch it.

## Applyability (for the apply step downstream)

Mark each proposal `applyable: true` only when `target_file` is a writable path **inside
`repo_root`** — an existing repo file or a new file under it. Mark `applyable: false` for:

- **installed plugin** files (they live in a plugin cache, outside the checkout — cannot be PR'd to
  this repo),
- any path outside `repo_root`,
- `process`-layer items that have no file to edit.

The `/prs-reinforce` workflow commits only `applyable: true` proposals; it surfaces the rest as
manual notes (e.g. in the PR body) so the insight isn't lost.

## Output discipline

Emit a **concrete** proposal — the exact file and the text to add or change, and whether it
**modifies existing** guidance or **adds new** — never a vague "add a rule". Rank by
`recurrence × severity × preventability`, highest first.

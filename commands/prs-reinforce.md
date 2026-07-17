---
name: prs-reinforce
description: >
  The action arm of PR insights. Fetches the PR dataset (prs.fetch), classifies the review feedback
  once (prs.classify), maps recurring patterns to concrete guidance changes (prs.reinforce), then —
  after you pick which suggestions to tackle — APPLIES the chosen edits to the repo's .claude
  guidance, writes a reinforcement report, and opens a branch + PR with the diff. Unlike
  /prs-insights (read-only), this command mutates files and creates a PR, so it guards that the
  analyzed repo matches your local checkout and never pushes without an explicit diff-review
  confirmation. Team-wide over the last 7 days by default.
metadata:
  category: workflow
  tags: [pr, insights, reinforcement, guidance, apply, pr-create, mutating]
  status: ready
  version: 1
allowed-tools: ["Bash", "Read", "Edit", "Write", "Skill", "Agent", "AskUserQuestion"]
---

# /prs-reinforce — recurring review feedback → applied guidance changes + PR

The one **mutating** command in the toolkit. It reuses the same fetch/classify/reinforce pipeline
as the reports, then adds the action loop the read-only reports refuse to do: **select → apply →
diff → branch → PR.** `/prs-insights` stays read-only; this command is where edits happen.

Pipeline (default is **autonomous**; `--interactive true` adds the pick + diff-confirm gates):

```
prs.fetch → prs.classify → prs.reinforce → [repo guard]
   → default:      apply ALL applyable + report → branch → push → PR
   → interactive:  you pick → apply + report → show diff → confirm → branch → push → PR
```

## Arguments

`$ARGUMENTS` — all optional. Parse out:

- **`--users`** — comma-separated logins, or a name to map (`hiagoradd`). Default: all users (team).
- **`--since YYYY-MM-DD` / `--days N`** — the window. Accept "last 30 days", etc. **Default: last 7
  days.** (Note: durable guidance changes want recurrence ≥ 3; a single week is often thin — see
  Step 3.)
- **`--repo owner/name`** — target repo to analyze. Default: the fetch script's default (`gh`
  default repo). Must match the local checkout — see the guard in Step 4.
- **`--layout <path>`** — path-classification config, passed through to `prs.fetch`.
- **`--run-dir <path>`** — reuse an existing populated run directory instead of fetching.
- **`--interactive <true|false>`** — **Default: `false`.** Governs how much the user is in the loop
  for the apply/PR stage:
  - **`false` (default) — autonomous.** Apply **every** `applyable` proposal, write the
    reinforcement report, then commit → branch → push → open the PR **without stopping for a pick or
    a diff confirmation.** The PR itself is the review artifact.
  - **`true` — gated.** The full interactive flow: multi-select which proposals to tackle, then show
    the diff and require an explicit confirmation before pushing.

  Two guards are **always** in force regardless of this flag: the analyzed-repo == local-checkout
  guard (Step 4) and the "no systemic pattern → no PR" check (Step 3). `--interactive` only controls
  the *pick* and *diff-confirmation* gates, never those.

## Step 1 — Get the dataset

- If **`--run-dir`** was given: use it directly (confirm it has `manifest.json`; if not, stop).
- Otherwise: invoke the **`prs.fetch`** skill with the parsed `--users` / window / `--repo` /
  `--layout`. Capture the **run-dir path** and one-line manifest summary. Don't re-implement
  fetching or read the dataset yourself.

If `prs.fetch` errors, surface it and stop — check `gh auth status` first.

## Step 2 — Classify + reinforce

Run these two skills on the run dir, in order (each reuses the prior's output — safe to re-run):

1. **`prs.classify`** — writes `classified-issues.ndjson` into the run dir. If it already exists and
   is current, the skill reuses it.
2. **`prs.reinforce`** — reads `classified-issues.ndjson`, surveys the **local repo's** `.claude`
   guidance surface (pass `repo_root` = the working directory), and writes
   `reinforcement-proposals.json` into the run dir, returning the structured `proposals[]`. Capture
   that array.

Delegating to the skills keeps the raw dataset out of this command's context — it holds only the
structured proposals, paths, and headlines.

## Step 3 — Handle thin signal

If `prs.reinforce` found **no systemic pattern** (nothing recurring ≥ 3), don't manufacture a PR.
Report what was seen and suggest widening the window (e.g. `--days 30`), then stop. Durable guidance
edits need real recurrence; a near-empty PR is worse than none.

## Step 4 — Guard: analyzed repo must match the local checkout

The proposals edit the **analyzed repo's** `.claude` / `CLAUDE.md` files, so a branch + PR needs a
local checkout of that same repo. Before touching anything:

- Analyzed repo = `manifest.json.repo` (or `--repo`).
- Local repo = the working dir's `origin` (`gh repo view --json nameWithOwner -q .nameWithOwner`,
  falling back to parsing `git -C . remote get-url origin`).
- If they **diverge**, STOP with a clear message, e.g.:

  > Analyzed `owner/A` but this checkout is `owner/B`. Check out `owner/A` locally (or re-run with
  > `--repo owner/B`) so the edits land in the right repo. No files changed.

Also confirm the working tree is a git repo and note if it's dirty (uncommitted changes) — offer to
proceed on a fresh branch anyway or stop.

## Step 5 — Decide which proposals to tackle

Split the proposals into **applyable** (`applyable: true`) and **non-applyable** (`false` — targets
an installed plugin or a path outside the repo, or is a process-only item).

- **`--interactive false` (default):** select **all** `applyable` proposals automatically — no
  prompt. Non-applyable ones are still carried forward as PR-body notes.
- **`--interactive true`:** present a concise ranked view (rank · theme · severity · recurrence ·
  already-covered? · cheapest layer · target file), then use **`AskUserQuestion`** (multiSelect) to
  let the user choose which to tackle. Include the non-applyable ones in the list too, labelled
  clearly — if chosen they become PR-body notes, not file edits. If the user picks nothing, stop.

Either way, if there are **no `applyable` proposals at all**, don't open an edit-less PR — report
the non-applyable notes (if any) and stop.

## Step 6 — Apply the chosen edits

For each chosen **applyable** proposal, apply it to the working tree:

- `change_type: add` — create the new file, or append the `exact_text` block at/after the `anchor`
  (safe, additive).
- `change_type: modify` — apply the in-place rewrite as a best-effort **Edit** at the `anchor`. The
  mandatory diff review in Step 7 is the safety net for a bad rewrite — never skip it.

Then write a **reinforcement report** (evidence behind the changes) to
`reports/prs-insights/<since>_to_<until>_<scope>_reinforce.md` — filled from
`${CLAUDE_PLUGIN_ROOT}/skills/prs.reinforce/assets/report-template.md` using the structured
proposals + a short classified-feedback summary (severity split, top themes). This report is a
**local artifact only** — that path is gitignored — and becomes the **PR description** in Step 7.
Do **not** stage or commit it: the PR must contain only the guidance-file edits.

## Step 7 — Branch → (diff gate, if interactive) → PR

1. Create a branch off the repo's default branch: `prs-reinforce/<since>-to-<until>` (append
   `-<scope>` when scoped to specific users).
2. Stage **only** the applied guidance edits. Do **not** add the reinforcement report — it's
   gitignored and used as the PR body (Step 7.4), never committed.
3. **Diff confirmation — depends on `--interactive`:**
   - **`false` (default):** skip the confirmation. Print the `git diff --staged` to the output for
     the record, but proceed straight to committing and pushing. The PR is the review artifact.
   - **`true`:** show the **full `git diff --staged`** and **require an explicit confirmation**
     before pushing. If the user rejects, leave the branch/edits in place for manual review and stop
     — do not push.
4. Commit, push, and open the PR with `gh pr create` against the default branch, using the **full
   reinforcement report as the PR body**:
   `gh pr create --body-file reports/prs-insights/<since>_to_<until>_<scope>_reinforce.md`.
   The report already contains the "Applied changes" and "Not auto-applied — do manually" sections,
   so it is a complete, self-contained PR description — no separate summary to assemble.

## Step 8 — Report

Return the PR URL, the branch name, the run directory (so a rerun reuses the data), and the
reinforcement report path (a local, gitignored artifact — its content is the PR body). Note any
non-applyable items that were routed to the PR body.

## Notes & boundaries

- **This command mutates** — the only one that does. It writes to the working tree, commits,
  pushes, and opens a PR. By **default (`--interactive false`)** it does this **autonomously** —
  applying all `applyable` proposals and opening the PR without a pick or diff confirmation; the PR
  is the review surface. Use **`--interactive true`** to require the multi-select pick and an
  explicit diff-review confirmation before any push. The analyzed-repo == local-checkout guard and
  the "no pattern → no PR" check hold in **both** modes.
- It never edits installed-plugin files or anything outside the checkout — those proposals become PR
  notes (see `prs.reinforce` `applyable`).
- Reuses the exact same run dir / classified / proposals artifacts as the reports, so running
  `/prs-coaching` (or `/prs-insights --reports dev`) and `/prs-reinforce` on the same window shares
  work — neither re-classifies.
- If `prs.classify` or `prs.reinforce` fails, surface which one and stop before any edit.

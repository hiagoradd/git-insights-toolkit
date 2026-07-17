---
name: dev.ship
description: >
  Ship a change to git-insights-toolkit through the protected-main PR flow: pick the Conventional
  Commit PR title by impact (which drives the automated release-please version bump), verify doc
  coupling, confirm plugin.json version was NOT hand-edited, then branch + commit + push + open the
  PR. main is protected (no direct pushes), so this is the only path to land a change. Triggers on:
  "ship this", "open a PR for this", "land this change", "create the PR", "how do I merge this".
metadata:
  category: dev
  status: ready
---

# dev.ship — land a change via PR

`main` is branch-protected: **no direct pushes** — every change goes through a PR. Version bumps are
automated by release-please from Conventional Commit history, so the one thing that matters here is a
correct **PR title**. See `.claude/rules/versioning.md` for the full policy.

## 0. Permission

Committing and pushing require **explicit user permission** every time — never commit or push
without it. Present the plan (branch name, title, files) and wait for a go-ahead.

## 1. Pick the PR title (this sets the version bump)

Choose the type by the **largest-impact** change in the diff:

| Change | Title | Bump |
| --- | --- | --- |
| New report skill / command / preset / flag; additive data-contract field | `feat: …` | minor |
| Bug fix, taxonomy/enum tweak, wording with behavior impact | `fix: …` | patch |
| Removed/renamed command or skill; breaking run-dir data-contract change; changed flag meaning | `feat!: …` or `BREAKING CHANGE:` footer | major |
| Prose/docs only | `docs: …` | none |
| Internal refactor / chore / CI | `refactor:` `chore:` `ci:` | none |

The title type is a judgment call CI only checks for *format*, not correctness — pick it honestly.

## 2. Pre-flight

- Run **`dev.lint`** and resolve any FAIL.
- If the change touches the data contract, confirm the coupled files were updated together
  (taxonomy.md, manifest notes, `docs/custom-reports.md`, consuming reports).
- Confirm **`.claude-plugin/plugin.json` `version` was NOT hand-edited** — release-please owns it.
  `git diff` it against `main`; if it changed, revert that hunk.

## 3. Branch → commit → push → PR

Never work on `main` locally for the commit. Suggested flow (run only after step 0 approval):

```bash
git switch -c <type>/<short-slug>        # e.g. feat/churn-report
git add -A
git commit -m "<the Conventional title>"
git push -u origin HEAD
gh pr create --fill --title "<the Conventional title>" --base main
```

Use the PR template's checklist. Report the PR URL back to the user.

## 4. After merge

Merging a feature PR **accumulates**; it does not release. release-please keeps a standing release PR
open — merging *that* PR is what bumps `plugin.json`, updates `CHANGELOG.md`, and tags. Remind the
user they can batch several merged PRs into one release.

## Boundaries

This skill orchestrates git/gh only. It never edits the version, and never pushes to `main`
directly. Get explicit approval before any commit or push.

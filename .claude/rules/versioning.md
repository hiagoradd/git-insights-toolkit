# Versioning

This plugin has **one** version: the `version` field in `.claude-plugin/plugin.json`
(the only version Claude Code reads). Skills and commands do **not** carry their own
version — a change to any of them is a change to the plugin.

## Do not hand-bump the version

Version bumps are **automated** by [release-please](https://github.com/googleapis/release-please)
(`.github/workflows/release-please.yml`). It watches merged commits on `main`, keeps a
standing "release" PR open, and — when that PR is merged — stamps the new version into
`.claude-plugin/plugin.json`, updates `CHANGELOG.md`, and tags the release.

- **Do not** edit `.claude-plugin/plugin.json` `version` by hand in a feature PR.
  A CI guard (`version-guard.yml`) allows leaving it unchanged and only blocks a decrease.
- The bump size is derived from **Conventional Commit** history, which comes from squash-merged
  **PR titles** (enforced by `pr-title.yml`).

## Semver policy (what each change type means)

Choose the PR-title type by the largest-impact change in the PR:

- **major** — `feat!:` / `fix!:` or a `BREAKING CHANGE:` footer. Use for:
  - a breaking change to the run-dir **data contract** (`docs/custom-reports.md` schema — e.g. renaming/removing a field in `manifest.json`, `pulls.json`, or the `*.ndjson` files);
  - removing or renaming a command or a skill;
  - changing the meaning of an existing `/prs-insights` flag.
- **minor** — `feat:`. Use for:
  - a new report skill (`prs-report.*`), a new command/preset, or a new backward-compatible flag;
  - additive fields in the data contract.
- **patch** — `fix:`. Use for:
  - bug fixes, taxonomy/enum tweaks, wording/prose, and non-behavioral cleanup.
- **no release** — `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `build:` produce a
  changelog entry (where applicable) but no standalone version bump on their own.

## Cutting a release (maintainer)

Merge the open **release-please** PR. That is the release action — it performs the bump,
CHANGELOG, tag, and GitHub Release in one step. Time it to batch several merged PRs when you like.

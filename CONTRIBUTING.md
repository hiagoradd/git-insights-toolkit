# Contributing

Thanks for contributing to **git-insights-toolkit**!

## PR titles drive releases

We use [Conventional Commits](https://www.conventionalcommits.org/) on **PR titles**.
PRs are squash-merged, so the PR title becomes the commit message that our release
automation reads to compute the next version. A CI check (`pr-title`) enforces the format.

Format: `<type>: <summary>` — e.g. `feat: add prs-report.churn`, `fix: correct approve→merge timing`.

| Title type | Version effect | Use for |
| --- | --- | --- |
| `feat:` | **minor** | new report skill / command / flag, additive data-contract field |
| `fix:` | **patch** | bug fix, taxonomy tweak, wording |
| `feat!:` / `BREAKING CHANGE:` | **major** | removed/renamed command or skill, breaking run-dir data-contract change, changed flag meaning |
| `docs:` `chore:` `refactor:` `test:` `ci:` `build:` | none | supporting changes |

See [`.claude/rules/versioning.md`](.claude/rules/versioning.md) for the full policy.

## Do not bump the version yourself

Don't edit `version` in `.claude-plugin/plugin.json`. [release-please](https://github.com/googleapis/release-please)
keeps a release PR open and performs the bump, `CHANGELOG.md`, and tag automatically when the
maintainer merges it.

## Local sanity checks

There's no build or test suite — the plugin is Markdown skill/command definitions plus one Bash
fetch script. To debug the data layer directly:

```bash
bash skills/prs.fetch/scripts/fetch-pr-data.sh --out /tmp/run --days 7
```

Requires `gh` (authenticated, `repo` scope) and `jq`.

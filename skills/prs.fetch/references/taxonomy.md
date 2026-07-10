# Deterministic taxonomy — prs.fetch

These are the **mechanical** classification rules the fetch script applies (zero LLM), so
every report consumes the same, comparable derived fields. The judgment layers
(theme/severity/actionability/resolution) live in the `prs-report.dev` skill and are **not**
applied here.

## PR type (`type` on each `pulls.json` row — single primary value)

Classified from `files[]`. Paths win; the conventional-commit scope in the title
(`feat(web)`, `fix(api)`, `chore(deps)`, `test(e2e)`) only corroborates.

| Type | Rule |
|---|---|
| `front-end` | touches `apps/web/**` source, and no `apps/api`/`packages` source |
| `back-end` | touches `apps/api/**` or `packages/**` source, and no `apps/web` source |
| `full-stack` | touches `apps/web` **and** (`apps/api` or `packages`) source |
| `e2e-testing` | only `apps/web/e2e/**`, Playwright `*.spec.ts`, or `apps/api/test/integration/**` touched (no other product source) |
| `misc` | no product `src/**` touched — only `.github/**`, `infra/**`, root config, `docker/**`, `pnpm-lock.yaml`, docs; or author is `dependabot[bot]` |

`sublabels[]` carries `migration` when `packages/database/prisma/migrations/**` is touched
(does not change the primary `type`).

## Comment layer (`layer` on each `review-comments.ndjson` row)

Inline comments carry a `path`, so the layer is mechanical:

| Path prefix | `layer` |
|---|---|
| `apps/web/e2e/`, `*.spec.ts`, `apps/api/test/integration/` | `test` |
| `packages/database/prisma/migrations/` | `migration` |
| `apps/web/` | `FE` |
| `apps/api/`, `packages/` | `BE` |
| `docs/` | `docs` |
| `infra/`, `.github/`, `docker/` | `infra` |
| (no path / unmatched) | `null` |

`issue-comments.ndjson` rows have no `path`, so `layer` is left unset — a report that needs a
layer for them infers it from text itself (that inference is judgment, not done here).

## Exclusion flags (on every comment row)

- `is_bot` — `user` ends with `[bot]` (e.g. `linear-code[bot]`, `dependabot[bot]`).
- `is_self_reply` — `user` equals the PR author (used only to derive `resolution` downstream).
- `excluded` — `is_bot OR is_self_reply`. Reports must drop `excluded` rows from all comment
  counts. Bare praise / "LGTM" is **not** excluded here (it needs content judgment) — the
  `prs-report.dev` skill tallies that separately.

## Normalization rule (for every report)

All cross-type comparisons use **density** (comments per PR, and per 100 lines changed), never
raw counts — a large back-end PR naturally draws more comments than a small misc bump.

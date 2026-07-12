# Deterministic taxonomy — prs.fetch

These are the **mechanical** classification rules the fetch script applies (zero LLM), so
every report consumes the same, comparable derived fields. The judgment layers
(theme/severity/actionability/resolution) live in the `prs-report.dev` skill and are **not**
applied here.

## The layout config drives path classification

Both derived path fields — a PR's `type` and a comment's `layer` — come from a **layout config**:
an ordered list of `rules`, each mapping path patterns to a `role`, a `layer`, and an optional
`sublabel`. The script resolves the config in this order:

1. `--layout <path>` if passed;
2. a `.prs-insights.json` in the current working directory (run from your repo root);
3. the bundled default `references/layouts/monorepo.json` (documented below).

Each rule looks like:

```json
{ "match": ["^apps/web/"], "role": "frontend", "layer": "FE" }
```

- `match` — an array of regexes tested against each file/comment path.
- `role` — `frontend` / `backend` / `test` / `none`; feeds the PR-`type` derivation.
- `layer` — the comment-`layer` value emitted for a matching path.
- `sublabel` (optional) — added to a PR's `sublabels[]` when a matching file is touched.

**A path is classified by the FIRST rule (in list order) whose `match` hits it**, so ordering is
precedence — put the most specific rules (tests, migrations) before the general app/package ones.

To adapt to a different repo layout, copy `references/layouts/flat.json` to `.prs-insights.json`
in your repo and edit the patterns. Only these path labels change; every quantitative metric is
independent of the layout.

## PR type (`type` on each `pulls.json` row — single primary value)

Derived from `files[]`. Each file resolves to its first matching rule's `role`; the set of roles
across all files (ignoring `none`) then maps to one primary `type`. Paths win; the
conventional-commit title scope (`feat(web)`, `fix(api)`) is only corroboration.

| Type | Rule |
|---|---|
| `full-stack` | files hit **both** a `frontend` role and a `backend` role |
| `front-end` | at least one `frontend` role, no `backend` |
| `back-end` | at least one `backend` role, no `frontend` |
| `e2e-testing` | only `test` roles touched (no `frontend`/`backend` source) |
| `misc` | no classified role (only `none`/unmatched paths); or author is `dependabot[bot]` |

`sublabels[]` carries every `sublabel` from matched rules (e.g. `migration` in the default
config) — it does not change the primary `type`.

With the default `monorepo.json`, this reproduces the toolkit's original classification, with one
deliberate consistency fix: a PR touching **only** test files (e.g. a lone `*.spec.ts`) is
`e2e-testing` regardless of where the test lives (previously a backend-side unit-test-only PR was
labelled `back-end`).

## Comment layer (`layer` on each `review-comments.ndjson` row)

Inline comments carry a `path`, so the layer is mechanical: it is the `layer` of the first layout
rule whose `match` hits the path, or `null` if none match (or there is no path). With the default
`monorepo.json` the layers are `test` / `migration` / `FE` / `BE` / `docs` / `infra` / `null`.

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

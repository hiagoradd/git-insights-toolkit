---
name: dev.lint
description: >
  Validate the git-insights-toolkit plugin before opening a PR — checks SKILL.md frontmatter (name
  matches its directory, description present), that commands reference skills that actually exist,
  that every JSON config parses, that plugin.json and .release-please-manifest.json agree, and that
  each report skill has its template. Runs concrete shell checks and reports pass/fail. Use before
  committing or opening a PR. Triggers on: "lint the plugin", "pre-PR check", "validate the plugin",
  "check the skills", "is the plugin consistent".
metadata:
  category: dev
  status: ready
---

# dev.lint — pre-PR plugin validation

Run these checks from the repo root and report each as PASS/FAIL with the offending path. This is a
consistency linter, not a test suite (there is no runtime to test). Fix or surface every FAIL before
handing off to `dev.ship`.

## 1. JSON parses

Every JSON file must parse:

```bash
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json \
         release-please-config.json .release-please-manifest.json \
         skills/prs.fetch/references/layouts/*.json; do
  jq -e . "$f" >/dev/null && echo "ok  $f" || echo "FAIL $f"
done
```

## 2. Version sources agree

`plugin.json` `version` must equal the `.release-please-manifest.json` entry for `"."` (release-please
keeps them in lockstep; a mismatch means someone hand-edited one):

```bash
pv=$(jq -r '.version' .claude-plugin/plugin.json)
mv=$(jq -r '."."' .release-please-manifest.json)
[ "$pv" = "$mv" ] && echo "ok  version $pv" || echo "FAIL plugin.json=$pv manifest=$mv"
```

## 3. Skill frontmatter is valid

For every `skills/*/SKILL.md` **and** `.claude/skills/*/SKILL.md`: the frontmatter `name:` must
equal the directory name, and a non-empty `description:` must be present. Read each file's
frontmatter and compare `name` to `basename "$(dirname FILE)"`. Report any mismatch or missing
description.

## 4. Commands reference real skills

Report resolution is `name X ⇒ skill prs-report.X`. For each report named in `commands/*.md` (the
built-in registry in `commands/prs-insights.md`, and the fixed `--reports` values in the preset
commands `prs-full.md` / `prs-coaching.md`), confirm a matching `skills/prs-report.<name>/` dir
exists. Confirm the four built-ins (`kpis`, `collab`, `dev`, `exec`) all resolve.

## 5. Report skills have a template

Every `skills/prs-report.*/` must contain `assets/report-template.md`:

```bash
for d in skills/prs-report.*/; do
  [ -f "$d/assets/report-template.md" ] && echo "ok  $d" || echo "FAIL missing template: $d"
done
```

## 6. Data-contract coupling (warn)

If the current change touches `skills/prs.fetch/scripts/fetch-pr-data.sh` or the run-dir schema,
remind the author that `skills/prs.fetch/references/taxonomy.md`, the `manifest.json` field notes,
`docs/custom-reports.md`, and every consuming report skill must be updated **together** (per
CLAUDE.md). This is a judgment check, not a grep — flag it for review.

## Output

A short PASS/FAIL summary. If everything passes, say so and suggest `dev.ship`. This skill is
**read-only** — it reports problems, it does not fix them.

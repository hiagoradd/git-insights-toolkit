#!/usr/bin/env bash
# Fetch + deterministically enrich raw PR/review data for the prs-insights family.
# Collection + mechanical (zero-LLM) classification only — the report skills do the
# judgment work (theme/severity). Never touches source; the only output is the run dir.
#
# Usage:
#   fetch-pr-data.sh --out <dir> [--users "a,b,c"] [--since YYYY-MM-DD] [--days N] [--repo owner/name]
#
# Defaults: all users, last 7 days, repo = current gh default repo.
# Writes into <dir>: pulls.json (enriched: type, sublabels), reviews.ndjson (is_bot),
#   review-comments.ndjson (is_bot, is_self_reply, excluded, layer),
#   issue-comments.ndjson (is_bot, is_self_reply, excluded), manifest.json
set -euo pipefail

OUT=""; USERS=""; SINCE=""; DAYS="7"; REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)   OUT="$2"; shift 2;;
    --users) USERS="$2"; shift 2;;
    --since) SINCE="$2"; shift 2;;
    --days)  DAYS="$2"; shift 2;;
    --repo)  REPO="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[ -n "$OUT" ] || { echo "--out <dir> is required" >&2; exit 2; }
mkdir -p "$OUT"

# Portable "N days ago" (GNU date, then BSD/macOS date).
if [ -z "$SINCE" ]; then
  SINCE="$(date -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-"${DAYS}"d +%Y-%m-%d)"
fi
UNTIL="$(date +%Y-%m-%d)"

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

# Scope label for filenames/manifest: "team" for all-users, else sanitized joined logins.
if [ -z "$USERS" ]; then
  SCOPE="team"
else
  SCOPE="$(echo "$USERS" | tr -d '[:space:]' | tr ',' '+')"
fi

# Author filter: comma-separated users -> repeated --author flags (OR). Empty = all users.
AUTHOR_ARGS=()
if [ -n "$USERS" ]; then
  IFS=',' read -r -a _users <<< "$USERS"
  for u in "${_users[@]}"; do
    u="$(echo "$u" | tr -d '[:space:]')"
    [ -n "$u" ] && AUTHOR_ARGS+=(--author "$u")
  done
fi

echo "repo=$REPO since=$SINCE until=$UNTIL scope=$SCOPE users=${USERS:-<all>}" >&2

# 1) PR numbers in window (by creation date).
NUMBERS="$(gh search prs --repo "$REPO" --created ">=$SINCE" "${AUTHOR_ARGS[@]}" \
  --json number --limit 200 --jq '.[].number')"

# 2) Per-PR: metadata, reviews, review comments, issue comments.
# Per-PR fetch runs in parallel (the all-users window can be ~80 PRs x 4 calls).
# Each worker writes to its own part files so parallel writes never interleave.
PARTS="$OUT/parts"; rm -rf "$PARTS"; mkdir -p "$PARTS"
export REPO PARTS

fetch_one() {
  local pr="$1"
  local files
  files="$(gh api "repos/$REPO/pulls/$pr/files" --paginate --jq '[.[].filename]' 2>/dev/null || echo '[]')"
  gh api "repos/$REPO/pulls/$pr" --jq \
    "{number, title, state, user: .user.login, created_at, merged_at, closed_at,
      changed_files, additions, deletions, commits, labels: [.labels[].name],
      base: .base.ref, head: .head.ref, files: $files}" > "$PARTS/$pr.pull.json" 2>/dev/null || true
  gh api "repos/$REPO/pulls/$pr/reviews" --paginate --jq \
    ".[] | {pr: $pr, user: .user.login, state: .state, submitted_at, body}" \
    > "$PARTS/$pr.reviews.ndjson" 2>/dev/null || true
  gh api "repos/$REPO/pulls/$pr/comments" --paginate --jq \
    ".[] | {pr: $pr, user: .user.login, path, line, created_at, body}" \
    > "$PARTS/$pr.rc.ndjson" 2>/dev/null || true
  gh api "repos/$REPO/issues/$pr/comments" --paginate --jq \
    ".[] | {pr: $pr, user: .user.login, created_at, body}" \
    > "$PARTS/$pr.ic.ndjson" 2>/dev/null || true
}
export -f fetch_one

count="$(echo "$NUMBERS" | grep -c . || true)"
[ "${count:-0}" -gt 0 ] && echo "$NUMBERS" | xargs -P 10 -n 1 -I {} bash -c 'fetch_one "$@"' _ {}

# Assemble raw outputs from the parts, then remove the parts.
cat "$PARTS"/*.pull.json 2>/dev/null | jq -s '.' > "$OUT/pulls.raw.json" || echo '[]' > "$OUT/pulls.raw.json"
cat "$PARTS"/*.reviews.ndjson 2>/dev/null > "$OUT/reviews.raw.ndjson" || : > "$OUT/reviews.raw.ndjson"
cat "$PARTS"/*.rc.ndjson 2>/dev/null > "$OUT/rc.raw.ndjson" || : > "$OUT/rc.raw.ndjson"
cat "$PARTS"/*.ic.ndjson 2>/dev/null > "$OUT/ic.raw.ndjson" || : > "$OUT/ic.raw.ndjson"
[ -s "$OUT/pulls.raw.json" ] || echo '[]' > "$OUT/pulls.raw.json"
rm -rf "$PARTS"

# --- Deterministic enrichment (mechanical, no LLM) -------------------------------
# See references/taxonomy.md for the rules encoded below.

# 3) PR type + sublabels from files[]. Paths win (title scope is only corroboration).
jq '
  map(
    . as $p
    | (($p.files // [])) as $f
    | ([$f[] | select(test("^apps/web/e2e/") or test("\\.spec\\.ts$") or test("^apps/api/test/integration/"))] | length) as $e2e
    | ([$f[] | select(test("^apps/web/") and (test("^apps/web/e2e/")|not) and (test("\\.spec\\.ts$")|not))] | length) as $web
    | ([$f[] | select(test("^apps/api/") and (test("^apps/api/test/integration/")|not))] | length) as $api
    | ([$f[] | select(test("^packages/"))] | length) as $pkg
    | ([$f[] | select(test("^packages/database/prisma/migrations/"))] | length) as $mig
    | ($p.user == "dependabot[bot]") as $bot
    | (if $bot then "misc"
       elif ($web==0 and $api==0 and $pkg==0 and $e2e==0) then "misc"
       elif ($web==0 and $api==0 and $pkg==0 and $e2e>0) then "e2e-testing"
       elif ($web>0 and ($api>0 or $pkg>0)) then "full-stack"
       elif ($web>0) then "front-end"
       elif ($api>0 or $pkg>0) then "back-end"
       else "misc" end) as $type
    | $p + {type: $type, sublabels: (if $mig>0 then ["migration"] else [] end)}
  )
' "$OUT/pulls.raw.json" > "$OUT/pulls.json"

# Author map (pr number -> login) so comment enrichment can flag author self-replies.
AUTHORS="$(jq -c 'map({key:(.number|tostring), value:.user}) | from_entries' "$OUT/pulls.json")"

# 4) Review comments: is_bot, is_self_reply, excluded, layer (from path).
jq -c --argjson authors "$AUTHORS" '
  . as $c
  | ($c.user | test("\\[bot\\]$")) as $bot
  | ($authors[($c.pr|tostring)] // null) as $author
  | ($c.user == $author) as $self
  | (($c.path // "")) as $path
  | (if $path == "" then null
     elif ($path|test("^apps/web/e2e/")) or ($path|test("\\.spec\\.ts$")) or ($path|test("^apps/api/test/integration/")) then "test"
     elif ($path|test("^packages/database/prisma/migrations/")) then "migration"
     elif ($path|test("^apps/web/")) then "FE"
     elif ($path|test("^apps/api/")) or ($path|test("^packages/")) then "BE"
     elif ($path|test("^docs/")) then "docs"
     elif ($path|test("^(infra/|\\.github/|docker/)")) then "infra"
     else null end) as $layer
  | . + {is_bot:$bot, is_self_reply:$self, excluded:($bot or $self), layer:$layer}
' "$OUT/rc.raw.ndjson" > "$OUT/review-comments.ndjson" || : > "$OUT/review-comments.ndjson"

# 5) Issue comments: is_bot, is_self_reply, excluded (no path -> layer inferred later if needed).
jq -c --argjson authors "$AUTHORS" '
  . as $c
  | ($c.user | test("\\[bot\\]$")) as $bot
  | ($authors[($c.pr|tostring)] // null) as $author
  | ($c.user == $author) as $self
  | . + {is_bot:$bot, is_self_reply:$self, excluded:($bot or $self)}
' "$OUT/ic.raw.ndjson" > "$OUT/issue-comments.ndjson" || : > "$OUT/issue-comments.ndjson"

# 6) Reviews: is_bot (used to filter bot review submissions in KPI/collab reports).
jq -c '. + {is_bot: (.user | test("\\[bot\\]$"))}' \
  "$OUT/reviews.raw.ndjson" > "$OUT/reviews.ndjson" || : > "$OUT/reviews.ndjson"

rm -f "$OUT/pulls.raw.json" "$OUT/rc.raw.ndjson" "$OUT/ic.raw.ndjson" "$OUT/reviews.raw.ndjson"

# --- Manifest (source of truth for window/scope + row counts) --------------------
pr_count="$(jq 'length' "$OUT/pulls.json" 2>/dev/null || echo 0)"
rc_count="$(wc -l < "$OUT/review-comments.ndjson" | tr -d '[:space:]')"
ic_count="$(wc -l < "$OUT/issue-comments.ndjson" | tr -d '[:space:]')"
rv_count="$(wc -l < "$OUT/reviews.ndjson" | tr -d '[:space:]')"

jq -n \
  --arg repo "$REPO" --arg since "$SINCE" --arg until "$UNTIL" \
  --arg scope "$SCOPE" --arg users "${USERS:-all}" \
  --argjson prs "${pr_count:-0}" --argjson rc "${rc_count:-0}" \
  --argjson ic "${ic_count:-0}" --argjson rv "${rv_count:-0}" \
  '{
     repo:$repo, since:$since, until:$until, scope:$scope, users:$users,
     pr_count:$prs,
     files:{
       "pulls.json": {rows:$prs, note:"PR metadata; enriched with type + sublabels[]"},
       "reviews.ndjson": {rows:$rv, note:"review submissions; enriched with is_bot"},
       "review-comments.ndjson": {rows:$rc, note:"inline comments; enriched with is_bot,is_self_reply,excluded,layer"},
       "issue-comments.ndjson": {rows:$ic, note:"PR-body comments; enriched with is_bot,is_self_reply,excluded"}
     }
   }' > "$OUT/manifest.json"

echo "collected $pr_count PRs ($rc_count review-comments, $ic_count issue-comments, $rv_count reviews) -> $OUT" >&2

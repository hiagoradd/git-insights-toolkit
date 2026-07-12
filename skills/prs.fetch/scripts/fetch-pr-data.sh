#!/usr/bin/env bash
# Fetch + deterministically enrich raw PR/review data for the prs-insights family.
# Collection + mechanical (zero-LLM) classification only — the report skills do the
# judgment work (theme/severity). Never touches source; the only output is the run dir.
#
# Usage:
#   fetch-pr-data.sh --out <dir> [--users "a,b,c"] [--since YYYY-MM-DD] [--days N] [--repo owner/name] [--layout <path>]
#
# Defaults: all users, last 7 days, repo = current gh default repo.
# Writes into <dir>: pulls.json (enriched: type, sublabels), reviews.ndjson (is_bot),
#   review-comments.ndjson (is_bot, is_self_reply, excluded, layer),
#   issue-comments.ndjson (is_bot, is_self_reply, excluded), manifest.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUT=""; USERS=""; SINCE=""; DAYS="7"; REPO=""; LAYOUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)    OUT="$2"; shift 2;;
    --users)  USERS="$2"; shift 2;;
    --since)  SINCE="$2"; shift 2;;
    --days)   DAYS="$2"; shift 2;;
    --repo)   REPO="$2"; shift 2;;
    --layout) LAYOUT="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[ -n "$OUT" ] || { echo "--out <dir> is required" >&2; exit 2; }
mkdir -p "$OUT"

# Resolve the layout config that drives path-based type/layer classification:
#   1) explicit --layout <path>
#   2) a .prs-insights.json in the current working directory (run from your repo root)
#   3) the bundled monorepo default (reproduces the toolkit's original behavior)
if [ -z "$LAYOUT" ]; then
  if [ -f "./.prs-insights.json" ]; then
    LAYOUT="./.prs-insights.json"
  else
    LAYOUT="$SCRIPT_DIR/../references/layouts/monorepo.json"
  fi
fi
[ -f "$LAYOUT" ] || { echo "layout config not found: $LAYOUT" >&2; exit 2; }
LAYOUT_JSON="$(cat "$LAYOUT")"
jq -e '.rules and (.rules|type=="array")' >/dev/null 2>&1 <<<"$LAYOUT_JSON" \
  || { echo "layout config $LAYOUT has no .rules[] array" >&2; exit 2; }
LAYOUT_NAME="$(jq -r '.name // "custom"' <<<"$LAYOUT_JSON")"

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

echo "repo=$REPO since=$SINCE until=$UNTIL scope=$SCOPE users=${USERS:-<all>} layout=$LAYOUT_NAME" >&2

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
# Each file maps to the FIRST layout rule whose .match[] regex hits it; that rule's
# .role (frontend/backend/test/none) and optional .sublabel drive the primary type.
jq --argjson layout "$LAYOUT_JSON" '
  ($layout.rules) as $rules
  # first matching rule for a path (null if none match)
  | def matched($path): $rules | map(select(.match | map(. as $re | $path|test($re)) | any)) | .[0];
  map(
    . as $p
    | (($p.files // [])) as $f
    | ([$f[] | matched(.) | select(. != null)]) as $hits
    | ([$hits[].role] | map(select(. != "none")) | unique) as $roles
    | ([$hits[] | select(.sublabel != null) | .sublabel] | unique) as $subs
    | ($p.user == "dependabot[bot]") as $bot
    | (if $bot then "misc"
       elif (($roles | index("frontend")) and ($roles | index("backend"))) then "full-stack"
       elif ($roles | index("frontend")) then "front-end"
       elif ($roles | index("backend")) then "back-end"
       elif ($roles | index("test")) then "e2e-testing"
       else "misc" end) as $type
    | $p + {type: $type, sublabels: $subs}
  )
' "$OUT/pulls.raw.json" > "$OUT/pulls.json"

# Author map (pr number -> login) so comment enrichment can flag author self-replies.
AUTHORS="$(jq -c 'map({key:(.number|tostring), value:.user}) | from_entries' "$OUT/pulls.json")"

# 4) Review comments: is_bot, is_self_reply, excluded, layer (from path).
# layer = the .layer of the first matching layout rule (same rules as PR type above).
jq -c --argjson authors "$AUTHORS" --argjson layout "$LAYOUT_JSON" '
  ($layout.rules) as $rules
  | def matched($path): $rules | map(select(.match | map(. as $re | $path|test($re)) | any)) | .[0];
  . as $c
  | ($c.user | test("\\[bot\\]$")) as $bot
  | ($authors[($c.pr|tostring)] // null) as $author
  | ($c.user == $author) as $self
  | (($c.path // "")) as $path
  | (if $path == "" then null else (matched($path) | if . == null then null else .layer end) end) as $layer
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
  --arg scope "$SCOPE" --arg users "${USERS:-all}" --arg layout "$LAYOUT_NAME" \
  --argjson prs "${pr_count:-0}" --argjson rc "${rc_count:-0}" \
  --argjson ic "${ic_count:-0}" --argjson rv "${rv_count:-0}" \
  '{
     repo:$repo, since:$since, until:$until, scope:$scope, users:$users,
     layout:$layout, pr_count:$prs,
     files:{
       "pulls.json": {rows:$prs, note:"PR metadata; enriched with type + sublabels[]"},
       "reviews.ndjson": {rows:$rv, note:"review submissions; enriched with is_bot"},
       "review-comments.ndjson": {rows:$rc, note:"inline comments; enriched with is_bot,is_self_reply,excluded,layer"},
       "issue-comments.ndjson": {rows:$ic, note:"PR-body comments; enriched with is_bot,is_self_reply,excluded"}
     }
   }' > "$OUT/manifest.json"

echo "collected $pr_count PRs ($rc_count review-comments, $ic_count issue-comments, $rv_count reviews) -> $OUT" >&2

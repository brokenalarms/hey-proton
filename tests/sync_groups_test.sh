#!/bin/bash
# Tests for scripts/sync-groups.sh, using saved API responses in tests/fixtures.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SYNC="scripts/sync-groups.sh"
FIXTURES="tests/fixtures/sync-groups"
STATE_FIXTURES="tests/fixtures/sync-groups-state"
FAIL_FAST=0
[[ "${1:-}" == "--fail-fast" ]] && FAIL_FAST=1

pass=0; fail=0

ok()   { printf "PASS  %s\n" "$1"; pass=$((pass + 1)); }
fail() { printf "FAIL  %s\n" "$1"; fail=$((fail + 1)); (( FAIL_FAST )) && exit 1 || true; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ── write ─────────────────────────────────────────────────────────────────────

out="$tmp/contact-groups.txt"
state="$tmp/contact-group-pairs.json"
report=$(CONTACT_GROUPS_FILE="$out" CONTACT_GROUPS_STATE_FILE="$state" bash "$SYNC" --input-dir "$FIXTURES" 2>&1)

# 1. Only groups with a label of the same lowercased name are written, sorted
expected=$(printf "Newsletters\nTherapy\n")
[[ -f "$out" && "$(cat "$out")" == "$expected" ]] \
    && ok "writes mirrored groups only, sorted" \
    || fail "writes mirrored groups only, sorted (got: $(cat "$out" 2>/dev/null | tr '\n' ','))"

# 2. A group with no label gets a lowercased label, unless it is group-only
printf "%s" "$report" | grep -qE '^  apps  <-  Apps$' \
    && ok "reports a group with no label as a label to create, lowercased" \
    || fail "reports a group with no label as a label to create, lowercased"
printf "%s" "$report" | grep -qE '^  screened out  <-' \
    && fail "Screened Out must not get a label (group-only)" \
    || ok "does not create a label for a group-only group"
printf "%s" "$report" | sed -n '/^Group-only groups/,$p' | grep -qE '^  Screened Out$' \
    && ok "reports Screened Out as group-only" \
    || fail "reports Screened Out as group-only"

# 3. A label with no group and no fileinto in filters/ gets a title-cased group
printf "%s" "$report" | grep -qE '^  Orphan Label  <-  orphan label$' \
    && ok "reports a label with no group and no rule as a group to create, title-cased" \
    || fail "reports a label with no group and no rule as a group to create, title-cased"
printf "%s" "$report" | grep -qE '^Contact groups to create .* [(]1[)]:$' \
    && ok "counts the groups to create" \
    || fail "counts the groups to create"

# 4. A label set by a sieve rule does not get a group
printf "%s" "$report" | grep -qiE '^  receipts$' \
    && fail "receipts must not get a group (filters/ file into it)" \
    || ok "does not create a group for a label that filters/ file into"

# 5. The first sync records each pair by ID
expected_state='[{"Group":{"ID":"g3","Name":"Newsletters"},"Label":{"ID":"l2","Name":"newsletters"}},{"Group":{"ID":"g1","Name":"Therapy"},"Label":{"ID":"l1","Name":"therapy"}}]'
[[ "$(jq -c . "$state" 2>/dev/null)" == "$expected_state" ]] \
    && ok "records mirrored pairs by ID" \
    || fail "records mirrored pairs by ID (got: $(jq -c . "$state" 2>/dev/null))"

# 6. Re-running against up-to-date files reports no change
report2=$(CONTACT_GROUPS_FILE="$out" CONTACT_GROUPS_STATE_FILE="$state" bash "$SYNC" --input-dir "$FIXTURES" 2>&1)
[[ $(printf "%s" "$report2" | grep -c "already up to date") == 2 ]] \
    && ok "reports unchanged files as up to date" \
    || fail "reports unchanged files as up to date"

# ── renames and deletions against the last sync ──────────────────────────────

state_out="$tmp/state/contact-groups.txt"
state_pairs="$tmp/state/contact-group-pairs.json"
mkdir -p "$tmp/state"
cp "$STATE_FIXTURES/contact-group-pairs.json" "$state_pairs"
state_report=$(CONTACT_GROUPS_FILE="$state_out" CONTACT_GROUPS_STATE_FILE="$state_pairs" bash "$SYNC" --input-dir "$STATE_FIXTURES" < /dev/null 2>&1)

# 7. A rename on one side is made on the other
printf "%s" "$state_report" | grep -qE '^  label therapy  ->  counselling$' \
    && ok "renames the label when its group was renamed" \
    || fail "renames the label when its group was renamed"
printf "%s" "$state_report" | grep -qE '^  group Cycling  ->  Bikes$' \
    && ok "renames the group when its label was renamed, title-cased" \
    || fail "renames the group when its label was renamed, title-cased"

# 8. Both sides renamed apart is reported, not resolved
printf "%s" "$state_report" | grep -qE '^  group Law  /  label lawyers$' \
    && ok "reports a pair renamed apart on both sides" \
    || fail "reports a pair renamed apart on both sides"

# 9. A deletion on one side offers the other, but never unattended
printf "%s" "$state_report" | grep -qE '^  group Storage [(]its label storage was deleted[)]$' \
    && ok "offers the group whose label was deleted" \
    || fail "offers the group whose label was deleted"
printf "%s" "$state_report" | grep -qE '^  label music [(]its group Music was deleted[)]$' \
    && ok "offers the label whose group was deleted" \
    || fail "offers the label whose group was deleted"
printf "%s" "$state_report" | grep -q "Run interactively to confirm" \
    && ok "skips deletions when not interactive" \
    || fail "skips deletions when not interactive"

# 10. Tracked sides are not paired or created afresh
printf "%s" "$state_report" | grep -qE '^  (storage  <-  Storage|Music  <-  music)$' \
    && fail "a side whose partner was deleted must not get a new partner" \
    || ok "does not recreate the partner of a deleted side"
printf "%s" "$state_report" | grep -qE '^  employment  <-  Employment$' \
    && ok "still creates labels for untracked groups" \
    || fail "still creates labels for untracked groups"

# 11. Only pairs with both sides are mirrored, under their new names
expected=$(printf "Bikes\nCounselling\n")
[[ "$(cat "$state_out" 2>/dev/null)" == "$expected" ]] \
    && ok "mirrors renamed pairs, not conflicted or half-deleted ones" \
    || fail "mirrors renamed pairs, not conflicted or half-deleted ones (got: $(cat "$state_out" 2>/dev/null | tr '\n' ','))"

# 12. Skipped deletions and conflicts stay tracked; a pair gone on both sides is dropped
tracked=$(jq -r '[.[].Group.ID] | join(",")' "$state_pairs" 2>/dev/null)
[[ "$tracked" == "g2,g1,g6,g4,g3" ]] \
    && ok "keeps unresolved pairs tracked and drops fully deleted ones" \
    || fail "keeps unresolved pairs tracked and drops fully deleted ones (got: $tracked)"

# ── dry run ───────────────────────────────────────────────────────────────────

dry_out="$tmp/dry/contact-groups.txt"
dry_report=$(CONTACT_GROUPS_FILE="$dry_out" CONTACT_GROUPS_STATE_FILE="$tmp/dry/contact-group-pairs.json" bash "$SYNC" --dry-run --input-dir "$FIXTURES" 2>&1)

# 13. Dry run prints the list but writes nothing
[[ ! -e "$dry_out" ]] \
    && ok "dry run does not write the file" \
    || fail "dry run does not write the file"
printf "%s" "$dry_report" | grep -qE '^  Therapy$' \
    && ok "dry run still prints the mirrored list" \
    || fail "dry run still prints the mirrored list"

# ── summary ───────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed\n" "$pass" "$fail"
(( fail == 0 ))

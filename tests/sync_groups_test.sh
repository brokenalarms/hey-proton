#!/bin/bash
# Tests for scripts/sync-groups.sh, using saved API responses in tests/fixtures.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SYNC="scripts/sync-groups.sh"
FIXTURES="tests/fixtures/sync-groups"
FAIL_FAST=0
[[ "${1:-}" == "--fail-fast" ]] && FAIL_FAST=1

pass=0; fail=0

ok()   { printf "PASS  %s\n" "$1"; pass=$((pass + 1)); }
fail() { printf "FAIL  %s\n" "$1"; fail=$((fail + 1)); (( FAIL_FAST )) && exit 1 || true; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ── write ─────────────────────────────────────────────────────────────────────

out="$tmp/contact-groups.txt"
report=$(CONTACT_GROUPS_FILE="$out" bash "$SYNC" --input-dir "$FIXTURES" 2>&1)

# 1. Only groups with a label of the same lowercased name are written, sorted
expected=$(printf "Newsletters\nTherapy\n")
[[ -f "$out" && "$(cat "$out")" == "$expected" ]] \
    && ok "writes mirrored groups only, sorted" \
    || fail "writes mirrored groups only, sorted (got: $(cat "$out" 2>/dev/null | tr '\n' ','))"

# 2. Groups without a label are reported as not mirrored
printf "%s" "$report" | grep -qE '^  Apps$' \
    && ok "reports Apps as a group with no matching label" \
    || fail "reports Apps as a group with no matching label"
printf "%s" "$report" | grep -qE '^  Screened Out$' \
    && ok "reports Screened Out as a group with no matching label" \
    || fail "reports Screened Out as a group with no matching label"

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

# 5. Re-running against an up-to-date file reports no change
report2=$(CONTACT_GROUPS_FILE="$out" bash "$SYNC" --input-dir "$FIXTURES" 2>&1)
printf "%s" "$report2" | grep -q "already up to date" \
    && ok "reports an unchanged file as up to date" \
    || fail "reports an unchanged file as up to date"

# ── dry run ───────────────────────────────────────────────────────────────────

dry_out="$tmp/dry/contact-groups.txt"
dry_report=$(CONTACT_GROUPS_FILE="$dry_out" bash "$SYNC" --dry-run --input-dir "$FIXTURES" 2>&1)

# 6. Dry run prints the list but writes nothing
[[ ! -e "$dry_out" ]] \
    && ok "dry run does not write the file" \
    || fail "dry run does not write the file"
printf "%s" "$dry_report" | grep -qE '^  Therapy$' \
    && ok "dry run still prints the mirrored list" \
    || fail "dry run still prints the mirrored list"

# ── summary ───────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed\n" "$pass" "$fail"
(( fail == 0 ))

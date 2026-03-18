#!/bin/bash
# Tests for scripts/generate.sh

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

GENERATE="scripts/generate.sh"
DIST="dist"
FAIL_FAST=0
[[ "${1:-}" == "--fail-fast" ]] && FAIL_FAST=1

pass=0; fail=0

ok()   { printf "PASS  %s\n" "$1"; pass=$((pass + 1)); }
fail() { printf "FAIL  %s\n" "$1"; fail=$((fail + 1)); (( FAIL_FAST )) && exit 1 || true; }

# ── fixtures ──────────────────────────────────────────────────────────────────

NEEDS_CLEANUP=()

setup_fixtures() {
    for src_name in "contact-groups.txt" "alias-patterns.txt"; do
        if [[ ! -f "private/$src_name" ]]; then
            cp "private-examples/$src_name" "private/$src_name"
            NEEDS_CLEANUP+=("private/$src_name")
        fi
    done
    if [[ ! -f "private/address-patterns.txt" ]]; then
        printf "test@example\\.com\n" > "private/address-patterns.txt"
        NEEDS_CLEANUP+=("private/address-patterns.txt")
    fi
}

teardown() {
    for f in "${NEEDS_CLEANUP[@]+"${NEEDS_CLEANUP[@]}"}"; do
        rm -f "$f"
    done
    rm -f "$DIST"/hey-proton-*.sieve
}

trap teardown EXIT

setup_fixtures

# ── helper ────────────────────────────────────────────────────────────────────

# Pipe enough newlines to auto-advance past all interactive prompts
run_generate() {
    printf "\n\n\n\n\n\n\n\n\n" | bash "$GENERATE" > /dev/null 2>&1
}

run_generate_with_limit() {
    local limit="$1"
    local patched
    patched=$(mktemp)
    sed "s/^CHARACTER_LIMIT=.*/CHARACTER_LIMIT=$limit/" "$GENERATE" > "$patched"
    printf "\n\n\n\n\n\n\n\n\n" | bash "$patched" > /dev/null 2>&1 || true
    rm "$patched"
}

# ── tests ─────────────────────────────────────────────────────────────────────

run_generate

# 1. Always produces exactly one output file per source filter (02–08)
count=$(ls "$DIST"/hey-proton-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$count" -eq 7 ]] \
    && ok "produces exactly 7 output files (one per source filter)" \
    || fail "produces exactly 7 output files (one per source filter) (got $count)"

# 2. Setup prepended to each output: first line is the setup section header
setup_header="# hey-proton: 00 - setup (prepended to every filter)"
for f in "$DIST"/hey-proton-*.sieve; do
    first=$(head -1 "$f")
    [[ "$first" == "$setup_header" ]] \
        && ok "setup header present in $(basename "$f")" \
        || fail "setup header present in $(basename "$f")"
done

# 3. Filter 01 content is in hey-proton-01 (not hey-proton-02)
filter01_marker="spamtest :value"
grep -q "$filter01_marker" "$DIST/hey-proton-01 - spam & ignored.sieve" \
    && ok "filter 01 content in hey-proton-01 - spam & ignored" \
    || fail "filter 01 content in hey-proton-01 - spam & ignored"
grep -q "$filter01_marker" "$DIST/hey-proton-02 - screened out.sieve" 2>/dev/null \
    && fail "filter 01 content must not be in hey-proton-02 - screened out" \
    || ok "filter 01 content not in hey-proton-02 - screened out"

# 4. Filter 05 content is in hey-proton-05 (not hey-proton-01)
filter05_marker="PAPER TRAIL"
grep -q "$filter05_marker" "$DIST/hey-proton-05 - paper trail.sieve" \
    && ok "filter 05 content in hey-proton-05 - paper trail" \
    || fail "filter 05 content in hey-proton-05 - paper trail"
grep -q "$filter05_marker" "$DIST/hey-proton-01 - spam & ignored.sieve" 2>/dev/null \
    && fail "filter 05 content must not be in hey-proton-01 - spam & ignored" \
    || ok "filter 05 content not in hey-proton-01 - spam & ignored"

# 5. Stale output files are removed on re-run
touch "$DIST/hey-proton-99.sieve"
run_generate
[[ ! -f "$DIST/hey-proton-99.sieve" ]] \
    && ok "stale output files removed on re-run" \
    || fail "stale output files removed on re-run"

# 6. CHARACTER_LIMIT=0 (no warning check) still produces 7 output files
rm -f "$DIST"/hey-proton-*.sieve
run_generate_with_limit 0
nosplit_count=$(ls "$DIST"/hey-proton-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$nosplit_count" -eq 7 ]] \
    && ok "CHARACTER_LIMIT=0 still produces 7 output files" \
    || fail "CHARACTER_LIMIT=0 still produces 7 output files (got $nosplit_count)"

# 7. CHARACTER_LIMIT does not affect file count (warns but does not split)
rm -f "$DIST"/hey-proton-*.sieve
run_generate_with_limit 4000
warn_count=$(ls "$DIST"/hey-proton-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$warn_count" -eq 7 ]] \
    && ok "CHARACTER_LIMIT=4000 produces 7 output files (warns, does not split)" \
    || fail "CHARACTER_LIMIT=4000 produces 7 output files (warns, does not split) (got $warn_count)"

# 8. With any CHARACTER_LIMIT, each output file contains setup content
for f in "$DIST"/hey-proton-*.sieve; do
    first=$(head -1 "$f")
    [[ "$first" == "$setup_header" ]] \
        && ok "setup in $(basename "$f")" \
        || fail "setup in $(basename "$f")"
done

# 9. No output file is empty
for f in "$DIST"/hey-proton-*.sieve; do
    sz=$(wc -c < "$f")
    [[ $sz -gt 0 ]] \
        && ok "$(basename "$f") is non-empty" \
        || fail "$(basename "$f") is non-empty"
done

# ── summary ───────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed\n" "$pass" "$fail"
(( fail == 0 ))

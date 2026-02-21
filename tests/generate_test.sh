#!/bin/bash
# Tests for scripts/generate.sh

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

GENERATE="scripts/generate.sh"
DIST="dist"

pass=0; fail=0

ok()   { printf "PASS  %s\n" "$1"; pass=$((pass + 1)); }
fail() { printf "FAIL  %s\n" "$1"; fail=$((fail + 1)); }

# ── fixtures ──────────────────────────────────────────────────────────────────

NEEDS_CLEANUP=()

setup_fixtures() {
    for src_name in "contact groups.txt" "email alias regexes.txt"; do
        if [[ ! -f "private/$src_name" ]]; then
            cp "private-examples/$src_name" "private/$src_name"
            NEEDS_CLEANUP+=("private/$src_name")
        fi
    done
    if [[ ! -f "private/test address regexes.txt" ]]; then
        printf "test@example\\.com\n" > "private/test address regexes.txt"
        NEEDS_CLEANUP+=("private/test address regexes.txt")
    fi
}

teardown() {
    for f in "${NEEDS_CLEANUP[@]+"${NEEDS_CLEANUP[@]}"}"; do
        rm -f "$f"
    done
    rm -f "$DIST"/output-*.sieve
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
count=$(ls "$DIST"/output-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$count" -eq 7 ]] \
    && ok "produces exactly 7 output files (one per source filter)" \
    || fail "produces exactly 7 output files (one per source filter) (got $count)"

# 2. Setup prepended to each output: first line matches setup first line
setup_first=$(head -1 "filters/01 - setup.sieve")
for f in "$DIST"/output-*.sieve; do
    first=$(head -1 "$f")
    [[ "$first" == "$setup_first" ]] \
        && ok "setup first line present in $(basename "$f")" \
        || fail "setup first line present in $(basename "$f")"
done

# 3. Filter 02 content is in output-02 (not output-03)
filter02_marker="spamtest :value"
grep -q "$filter02_marker" "$DIST/output-02 - spam & ignored.sieve" \
    && ok "filter 02 content in output-02 - spam & ignored" \
    || fail "filter 02 content in output-02 - spam & ignored"
grep -q "$filter02_marker" "$DIST/output-03 - screened out.sieve" 2>/dev/null \
    && fail "filter 02 content must not be in output-03 - screened out" \
    || ok "filter 02 content not in output-03 - screened out"

# 4. Filter 06 content is in output-06 (not output-02)
filter06_marker="PAPER TRAIL"
grep -q "$filter06_marker" "$DIST/output-06 - paper trail.sieve" \
    && ok "filter 06 content in output-06 - paper trail" \
    || fail "filter 06 content in output-06 - paper trail"
grep -q "$filter06_marker" "$DIST/output-02 - spam & ignored.sieve" 2>/dev/null \
    && fail "filter 06 content must not be in output-02 - spam & ignored" \
    || ok "filter 06 content not in output-02 - spam & ignored"

# 5. Stale output files are removed on re-run
touch "$DIST/output-99.sieve"
run_generate
[[ ! -f "$DIST/output-99.sieve" ]] \
    && ok "stale output files removed on re-run" \
    || fail "stale output files removed on re-run"

# 6. CHARACTER_LIMIT=0 (no warning check) still produces 7 output files
rm -f "$DIST"/output-*.sieve
run_generate_with_limit 0
nosplit_count=$(ls "$DIST"/output-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$nosplit_count" -eq 7 ]] \
    && ok "CHARACTER_LIMIT=0 still produces 7 output files" \
    || fail "CHARACTER_LIMIT=0 still produces 7 output files (got $nosplit_count)"

# 7. CHARACTER_LIMIT does not affect file count (warns but does not split)
rm -f "$DIST"/output-*.sieve
run_generate_with_limit 4000
warn_count=$(ls "$DIST"/output-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$warn_count" -eq 7 ]] \
    && ok "CHARACTER_LIMIT=4000 produces 7 output files (warns, does not split)" \
    || fail "CHARACTER_LIMIT=4000 produces 7 output files (warns, does not split) (got $warn_count)"

# 8. With any CHARACTER_LIMIT, each output file contains setup content
for f in "$DIST"/output-*.sieve; do
    first=$(head -1 "$f")
    [[ "$first" == "$setup_first" ]] \
        && ok "setup in $(basename "$f")" \
        || fail "setup in $(basename "$f")"
done

# 9. No output file is empty
for f in "$DIST"/output-*.sieve; do
    sz=$(wc -c < "$f")
    [[ $sz -gt 0 ]] \
        && ok "$(basename "$f") is non-empty" \
        || fail "$(basename "$f") is non-empty"
done

# ── summary ───────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed\n" "$pass" "$fail"
(( fail == 0 ))

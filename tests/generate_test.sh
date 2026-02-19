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

# 1. Default split produces exactly 2 output files
count=$(ls "$DIST"/output-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$count" == "2" ]] \
    && ok "default split produces 2 output files" \
    || fail "default split produces 2 output files (got $count)"

# 2. Setup prepended to each output: first line matches setup first line
setup_first=$(head -1 "filters/01 - setup.sieve")
for f in "$DIST"/output-*.sieve; do
    first=$(head -1 "$f")
    [[ "$first" == "$setup_first" ]] \
        && ok "setup first line present in $(basename "$f")" \
        || fail "setup first line present in $(basename "$f")"
done

# 3. Filter 02 content is in output-01 (not output-02)
filter02_marker="spamtest :value"
grep -q "$filter02_marker" "$DIST/output-01.sieve" \
    && ok "filter 02 content in output-01" \
    || fail "filter 02 content in output-01"
grep -q "$filter02_marker" "$DIST/output-02.sieve" 2>/dev/null \
    && fail "filter 02 content must not be in output-02" \
    || ok "filter 02 content not in output-02"

# 4. Filter 06 content is in output-02 (not output-01)
filter06_marker="PAPER TRAIL"
grep -q "$filter06_marker" "$DIST/output-02.sieve" \
    && ok "filter 06 content in output-02" \
    || fail "filter 06 content in output-02"
grep -q "$filter06_marker" "$DIST/output-01.sieve" 2>/dev/null \
    && fail "filter 06 content must not be in output-01" \
    || ok "filter 06 content not in output-01"

# 5. Stale output files are removed on re-run
touch "$DIST/output-99.sieve"
run_generate
[[ ! -f "$DIST/output-99.sieve" ]] \
    && ok "stale output files removed on re-run" \
    || fail "stale output files removed on re-run"

# 6. Size-aware splitting: tight CHARACTER_LIMIT produces more than 2 files
rm -f "$DIST"/output-*.sieve
run_generate_with_limit 4000
split_count=$(ls "$DIST"/output-*.sieve 2>/dev/null | wc -l | tr -d ' ')
[[ "$split_count" -gt 2 ]] \
    && ok "CHARACTER_LIMIT=4000 produces more than 2 output files (got $split_count)" \
    || fail "CHARACTER_LIMIT=4000 produces more than 2 output files (got $split_count)"

# 7. With tight limit, each output file contains setup content
for f in "$DIST"/output-*.sieve; do
    first=$(head -1 "$f")
    [[ "$first" == "$setup_first" ]] \
        && ok "setup in $(basename "$f") under tight CHARACTER_LIMIT" \
        || fail "setup in $(basename "$f") under tight CHARACTER_LIMIT"
done

# 8. No output file is empty
for f in "$DIST"/output-*.sieve; do
    sz=$(wc -c < "$f")
    [[ $sz -gt 0 ]] \
        && ok "$(basename "$f") is non-empty" \
        || fail "$(basename "$f") is non-empty"
done

# ── summary ───────────────────────────────────────────────────────────────────
printf "\n%d passed, %d failed\n" "$pass" "$fail"
(( fail == 0 ))

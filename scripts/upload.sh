#!/bin/bash
# upload.sh — Upload generated Sieve filters to Proton Mail via the informal filter API.
#
# REQUIREMENTS:
#   - jq (JSON processor): brew install jq | apt install jq
#   - Session credentials: env vars (preferred) or private/proton-session.json
#     (see private-examples/proton-session.json and docs/proton-api.md)
#
# USAGE:
#   PROTON_UID=<uid> PROTON_COOKIE=<cookie-header-value> bash scripts/upload.sh [--dry-run] [hey-proton-NN.sieve ...]
#
#   Env vars take priority over private/proton-session.json.
#   With no file arguments, uploads all dist/hey-proton-*.sieve files.
#   --dry-run   Show what would be created/updated without making API calls.
#
# SECURITY: See docs/proton-api.md before using.
# CAUTION:  This operates on your live Proton account. Back up your existing
#           filters first via: curl ... GET /mail/v4/filters > backup.json

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

API_BASE="https://mail.proton.me/api"
session_file="private/proton-session.json"
dist_dir="dist"
dry_run=false
target_files=()

# ============================================================
# Argument parsing
# ============================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry_run=true; shift ;;
        --help|-h)
            sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        dist/hey-proton-*.sieve|hey-proton-*.sieve)
            # Accept bare filename or dist/-prefixed
            f="${1#dist/}"
            target_files+=("$dist_dir/$f")
            shift
            ;;
        *) printf "Unknown argument: %s\n" "$1" >&2; exit 1 ;;
    esac
done

# ============================================================
# Dependency check
# ============================================================

if ! command -v jq &>/dev/null; then
    printf "Error: jq is required. Install via: brew install jq | apt install jq\n" >&2
    exit 1
fi
if ! command -v curl &>/dev/null; then
    printf "Error: curl is required.\n" >&2
    exit 1
fi

# ============================================================
# Optionally refresh output files via generate.sh
# ============================================================

printf "Run generate.sh to refresh output files first? [y/N] "
read -r refresh
if [[ "$refresh" == [yY] ]]; then
    bash "$(dirname "$0")/generate.sh" --no-paste
fi

# ============================================================
# Load credentials (env vars take priority over JSON file)
# ============================================================

UID_VALUE="${PROTON_UID:-}"
COOKIE_VALUE="${PROTON_COOKIE:-}"

if [[ -z "$UID_VALUE" || -z "$COOKIE_VALUE" ]]; then
    if [[ ! -f "$session_file" ]]; then
        printf "Error: credentials required. Either set PROTON_UID and PROTON_COOKIE,\n" >&2
        printf "or create %s from private-examples/proton-session.json.\n" "$session_file" >&2
        printf "See docs/proton-api.md for instructions.\n" >&2
        exit 1
    fi
    [[ -z "$UID_VALUE" ]]    && UID_VALUE=$(jq -r '.UID // empty' "$session_file")
    [[ -z "$COOKIE_VALUE" ]] && COOKIE_VALUE=$(jq -r '.Cookie // empty' "$session_file")
fi

if [[ -z "$UID_VALUE" || -z "$COOKIE_VALUE" ]]; then
    printf "Error: UID and Cookie are required.\n" >&2
    printf "See docs/proton-api.md for how to obtain them from your browser.\n" >&2
    exit 1
fi

# ============================================================
# Resolve target files
# ============================================================

if [[ ${#target_files[@]} -eq 0 ]]; then
    while IFS= read -r -d '' f; do
        target_files+=("$f")
    done < <(find "$dist_dir" -name "hey-proton-*.sieve" -print0 | sort -z)
fi

if [[ ${#target_files[@]} -eq 0 ]]; then
    printf "No dist/hey-proton-*.sieve files found. Run scripts/generate.sh first.\n" >&2
    exit 1
fi

# ============================================================
# API helpers
# ============================================================

api_get() {
    local path="$1"
    curl -sS \
        -H "x-pm-uid: $UID_VALUE" \
        -H "Cookie: $COOKIE_VALUE" \
        -H "Content-Type: application/json" \
        -H "x-pm-appversion: Other" \
        "$API_BASE/$path"
}

api_post() {
    local path="$1"
    local body="$2"
    curl -sS -X POST \
        -H "x-pm-uid: $UID_VALUE" \
        -H "Cookie: $COOKIE_VALUE" \
        -H "Content-Type: application/json" \
        -H "x-pm-appversion: Other" \
        -d "$body" \
        "$API_BASE/$path"
}

api_put() {
    local path="$1"
    local body="$2"
    curl -sS -X PUT \
        -H "x-pm-uid: $UID_VALUE" \
        -H "Cookie: $COOKIE_VALUE" \
        -H "Content-Type: application/json" \
        -H "x-pm-appversion: Other" \
        -d "$body" \
        "$API_BASE/$path"
}

check_response_code() {
    local response="$1"
    local context="$2"
    local code
    code=$(printf "%s" "$response" | jq -r '.Code // 0')
    if [[ "$code" != "1000" ]]; then
        printf "Error in %s (Code: %s): %s\n" \
            "$context" "$code" \
            "$(printf "%s" "$response" | jq -r '.Error // "unknown error"')" >&2
        return 1
    fi
}

# ============================================================
# Fetch existing filters
# ============================================================

printf "Fetching existing Proton filters...\n"
filters_response=$(api_get "mail/v4/filters")

if ! check_response_code "$filters_response" "list filters"; then
    printf "Hint: your AccessToken may have expired. Re-extract from browser devtools.\n" >&2
    exit 1
fi

# Build a lookup: name → id
existing_ids=$(printf "%s" "$filters_response" | \
    jq -r '.Filters[] | [.Name, .ID] | @tsv')

lookup_id_by_name() {
    local name="$1"
    printf "%s" "$existing_ids" | awk -F'\t' -v n="$name" '$1 == n { print $2; exit }'
}

# ============================================================
# Upload each output file
# ============================================================

# ordered_ids: IDs of our filters in source file order, for the order call
ordered_ids=()

for f in "${target_files[@]}"; do
    if [[ ! -f "$f" ]]; then
        printf "Warning: %s not found, skipping.\n" "$f" >&2
        continue
    fi

    filter_name=$(basename "$f" .sieve)

    sieve_content=$(cat "$f")
    existing_id=$(lookup_id_by_name "$filter_name")

    body=$(jq -n \
        --arg name "$filter_name" \
        --arg sieve "$sieve_content" \
        '{"Name": $name, "Status": 1, "Version": 2, "Sieve": $sieve}')

    if [[ -n "$existing_id" ]]; then
        printf "Updating  %-40s (id: %s)\n" "$filter_name" "$existing_id"
        if [[ "$dry_run" == false ]]; then
            response=$(api_put "mail/v4/filters/$existing_id" "$body")
            check_response_code "$response" "update $filter_name"
        fi
        ordered_ids+=("$existing_id")
    else
        printf "Creating  %s\n" "$filter_name"
        if [[ "$dry_run" == false ]]; then
            response=$(api_post "mail/v4/filters" "$body")
            check_response_code "$response" "create $filter_name"
            new_id=$(printf "%s" "$response" | jq -r '.Filter.ID // empty')
            ordered_ids+=("$new_id")
        fi
    fi
done

# ============================================================
# Set filter execution order
# ============================================================

if [[ "$dry_run" == false && ${#ordered_ids[@]} -gt 0 ]]; then
    # Append IDs of any non-hey-proton filters so they are preserved
    other_ids=()
    while IFS= read -r id; do
        [[ -n "$id" ]] && other_ids+=("$id")
    done < <(printf "%s" "$filters_response" | \
        jq -r '.Filters[] | select(.Name | startswith("hey-proton-") | not) | .ID')

    all_ids=("${ordered_ids[@]}" "${other_ids[@]+"${other_ids[@]}"}")
    order_body=$(printf '%s\n' "${all_ids[@]}" | jq -R . | jq -s '{"FilterIDs": .}')
    order_response=$(api_put "mail/v4/filters/order" "$order_body")
    check_response_code "$order_response" "set filter order"
    printf "Filter order set.\n"
fi

if [[ "$dry_run" == true ]]; then
    printf "\n(dry run — no changes made)\n"
else
    printf "\nDone.\n"
fi

exit 0

#!/bin/bash
# upload.sh — Upload generated Sieve filters to Proton Mail via the informal filter API.
#
# REQUIREMENTS:
#   - jq (JSON processor): brew install jq | apt install jq
#   - Session credentials, loaded by scripts/lib/proton-api.sh (checked in order):
#     1. Clipboard: "Copy as cURL" from browser dev tools (always wins if present)
#     2. PROTON_UID + PROTON_COOKIE env vars
#     3. private/proton-session.json (override the path with PROTON_SESSION_FILE)
#     4. Interactive paste of a cURL command, ended by an empty line
#
# USAGE:
#   bash scripts/upload.sh [--dry-run] [--apply] [hey-proton-NN.sieve ...]
#
#   With no file arguments, uploads all dist/hey-proton-*.sieve files.
#   --dry-run   Show what would be created/updated without making API calls.
#   --apply     After uploading, apply the uploaded filters to existing messages
#               as a single server-side job that evaluates them in filter order.
#               Without this flag you are prompted whether to apply.
#
# SECURITY: See docs/proton-api.md before using.
# CAUTION:  This operates on your live Proton account. Back up your existing
#           filters first via: curl ... GET /mail/v4/filters > backup.json

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

source scripts/lib/proton-api.sh

# ============================================================
# Configuration
# ============================================================

dist_dir="dist"
dry_run=false
apply=false
target_files=()

# ============================================================
# Argument parsing
# ============================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry_run=true; shift ;;
        --apply) apply=true; shift ;;
        --help|-h)
            sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'
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

require_api_dependencies

# ============================================================
# Optionally refresh output files via generate.sh
# ============================================================

printf "Run generate.sh to refresh output files first? [y/N] "
read -r refresh
if [[ "$refresh" == [yY] ]]; then
    bash scripts/generate.sh --no-paste
fi

load_credentials

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

# ============================================================
# Apply to existing messages
# ============================================================

# One apply-filters call with every ID runs a single job that evaluates the
# filters in order per message, matching incoming-mail behaviour. Applying
# filters one at a time from the Proton UI submits independent jobs whose
# relative ordering is not guaranteed.
if [[ "$dry_run" == false && ${#ordered_ids[@]} -gt 0 ]]; then
    if [[ "$apply" == false ]]; then
        printf "\nApply the uploaded filters to existing messages? [y/N] "
        read -r apply_answer
        [[ "$apply_answer" == [yY] ]] && apply=true
    fi

    if [[ "$apply" == true ]]; then
        apply_body=$(printf '%s\n' "${ordered_ids[@]}" | jq -R . | jq -s '{"FilterIDs": .}')
        apply_response=$(api_post "mail/v4/messages/apply-filters" "$apply_body")
        if ! check_response_code "$apply_response" "apply filters to existing messages"; then
            if [[ "$(printf "%s" "$apply_response" | jq -r '.Code // empty' 2>/dev/null || true)" == "409" ]]; then
                printf "Proton only runs one apply job at a time and does not queue them.\n" >&2
                printf "A previous job (from the Proton UI or an earlier run) is still running.\n" >&2
                printf "The filters are uploaded; rerun with --apply once it finishes.\n" >&2
            fi
            exit 1
        fi
        printf "Filters are being applied to existing messages. This may take a few minutes.\n"
    fi
fi

if [[ "$dry_run" == true ]]; then
    printf "\n(dry run — no changes made)\n"
else
    printf "\nDone.\n"
fi

exit 0

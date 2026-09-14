#!/bin/bash
# sync-groups.sh — Mirror Proton contact groups into the list generate.sh expands.
#
# Contact groups only exist inside Proton, so rather than maintaining the list
# by hand this reads contact groups and labels from the Proton API and writes
# every group that has a label of the same lowercased name to
# filters/shared/contact-groups.txt. That file is committed as the backup and
# is what generate.sh reads, so generating never needs a live session.
#
# Groups with no matching label are not mirrored and are listed so they can
# be given one (behavioural groups such as Screened Out are expected here).
# Labels with neither a group nor a fileinto in filters/ are listed as orphans.
#
# REQUIREMENTS:
#   - jq, curl, and session credentials as for scripts/upload.sh
#
# USAGE:
#   bash scripts/sync-groups.sh [--dry-run] [--input-dir DIR]
#
#   --dry-run         Print the audit and the list without writing the file.
#   --input-dir DIR   Read DIR/groups.json and DIR/labels.json (saved responses
#                     from GET core/v4/labels?Type=2 and ?Type=1) instead of
#                     calling Proton. Used by the tests.
#
# The output path can be overridden with CONTACT_GROUPS_FILE.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

source scripts/lib/proton-api.sh

output_file="${CONTACT_GROUPS_FILE:-filters/shared/contact-groups.txt}"
filters_dir="filters"
dry_run=false
input_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) dry_run=true; shift ;;
        --input-dir) input_dir="$2"; shift 2 ;;
        --help|-h)
            sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) printf "Unknown argument: %s\n" "$1" >&2; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then
    printf "Error: jq is required. Install via: brew install jq | apt install jq\n" >&2
    exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# ============================================================
# Fetch contact groups and labels
# ============================================================

if [[ -n "$input_dir" ]]; then
    groups_json="$input_dir/groups.json"
    labels_json="$input_dir/labels.json"
else
    require_api_dependencies
    load_credentials
    groups_json="$tmp_dir/groups.json"
    labels_json="$tmp_dir/labels.json"

    printf "Fetching contact groups and labels from Proton...\n"
    api_get "core/v4/labels?Type=2" > "$groups_json"
    if ! check_response_code "$(cat "$groups_json")" "list contact groups"; then
        printf "Hint: your session may have expired. Re-extract from browser devtools.\n" >&2
        exit 1
    fi
    api_get "core/v4/labels?Type=1" > "$labels_json"
    check_response_code "$(cat "$labels_json")" "list labels" || exit 1
fi

# ============================================================
# Pair groups with labels
# ============================================================

names_in() {
    jq -r '.Labels[].Name' "$1" | LC_ALL=C sort
}

groups=$(names_in "$groups_json")
labels=$(names_in "$labels_json")

# generate.sh lowercases the group name for the fileinto, so a group is
# mirrored only when a label with exactly that lowercased name exists.
mirrored=$(jq -r --slurpfile labels "$labels_json" '
    [$labels[0].Labels[].Name] as $label_names
    | .Labels[].Name
    | (ascii_downcase) as $lower
    | select(any($label_names[]; . == $lower))
' "$groups_json" | LC_ALL=C sort)

unmirrored=$(LC_ALL=C comm -23 <(printf "%s\n" "$groups") <(printf "%s\n" "$mirrored") | sed '/^$/d')

grouped_lower=$(printf "%s\n" "$groups" | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u)

orphans=""
while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    if printf "%s\n" "$grouped_lower" | grep -qxF "$label"; then
        continue
    fi
    if grep -rqF "fileinto \"$label\"" "$filters_dir"; then
        continue
    fi
    orphans+="$label"$'\n'
done <<< "$labels"

# ============================================================
# Report
# ============================================================

count_lines() {
    printf "%s" "$1" | sed '/^$/d' | wc -l | tr -d ' '
}

printf "Mirrored groups (%s), each labelled with its lowercased name:\n" "$(count_lines "$mirrored")"
printf "%s\n" "$mirrored" | sed '/^$/d;s/^/  /'

printf "\nGroups with no matching label, not mirrored (%s):\n" "$(count_lines "$unmirrored")"
printf "%s\n" "$unmirrored" | sed '/^$/d;s/^/  /'

printf "\nLabels with no group and no rule in filters/ (%s), may still come from alias patterns:\n" "$(count_lines "$orphans")"
printf "%s" "$orphans" | sed '/^$/d;s/^/  /'

# ============================================================
# Write
# ============================================================

if [[ "$dry_run" == true ]]; then
    printf "\n(dry run — %s not written)\n" "$output_file"
    exit 0
fi

new_file="$tmp_dir/contact-groups.txt"
printf "%s\n" "$mirrored" | sed '/^$/d' > "$new_file"

if [[ -f "$output_file" ]] && cmp -s "$new_file" "$output_file"; then
    printf "\n%s is already up to date.\n" "$output_file"
else
    mkdir -p "$(dirname "$output_file")"
    cp "$new_file" "$output_file"
    printf "\nWrote %s. Review with git diff, then run scripts/generate.sh.\n" "$output_file"
fi

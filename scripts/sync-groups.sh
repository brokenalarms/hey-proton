#!/bin/bash
# sync-groups.sh — Mirror Proton labels into contact groups and write the list
# generate.sh expands.
#
# Labels are the source of truth. A label that nothing in filters/ files into
# is meant to come from a contact group of the same name, so this reads labels
# and contact groups from the Proton API, creates any such group that is
# missing (named from the label in title case, using the label's colour), and
# writes every group that has a label of the same lowercased name to
# filters/shared/contact-groups.txt. That file is committed as the backup and
# is what generate.sh reads, so generating never needs a live session.
#
# Groups with no matching label are not mirrored and are listed so they can
# be given one (behavioural groups such as Screened Out are expected here).
#
# REQUIREMENTS:
#   - jq, curl, and session credentials as for scripts/upload.sh
#
# USAGE:
#   bash scripts/sync-groups.sh [--dry-run] [--input-dir DIR]
#
#   --dry-run         Print the audit and the list without creating groups or
#                     writing the file.
#   --input-dir DIR   Read DIR/groups.json and DIR/labels.json (saved responses
#                     from GET core/v4/labels?Type=2 and ?Type=1) instead of
#                     calling Proton. Offline, so groups are reported rather
#                     than created. Used by the tests.
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

# A label with neither a group nor a fileinto in filters/ can only be meant
# for a contact group, so it gets one.
missing_groups=""
while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    if printf "%s\n" "$grouped_lower" | grep -qxF "$label"; then
        continue
    fi
    if grep -rqF "fileinto \"$label\"" "$filters_dir"; then
        continue
    fi
    missing_groups+="$label"$'\n'
done <<< "$labels"

# ============================================================
# Create missing groups
# ============================================================

count_lines() {
    printf "%s\n" "$1" | sed '/^$/d' | wc -l | tr -d ' '
}

title_case() {
    printf "%s" "$1" | awk '{
        for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)
    } 1'
}

label_color() {
    jq -r --arg name "$1" '.Labels[] | select(.Name == $name) | .Color // empty' "$labels_json"
}

# Proton requires a colour on every label; the group takes the label's so the
# two read as one thing in both UIs.
default_color="#8080FF"

create_group() {
    local label="$1" name="$2" color body response
    color=$(label_color "$label")
    body=$(jq -n --arg name "$name" --arg color "${color:-$default_color}" \
        '{"Name": $name, "Color": $color, "Type": 2}')
    response=$(api_post "core/v4/labels" "$body")
    check_response_code "$response" "create contact group $name"
}

created=""
if [[ -n "$missing_groups" ]]; then
    if [[ "$dry_run" == true || -n "$input_dir" ]]; then
        printf "Contact groups to create for labels with no group and no rule in filters/ (%s):\n" "$(count_lines "$missing_groups")"
    else
        printf "Creating contact groups for labels with no group and no rule in filters/ (%s):\n" "$(count_lines "$missing_groups")"
    fi
    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        name=$(title_case "$label")
        printf "  %s  <-  %s\n" "$name" "$label"
        if [[ "$dry_run" == false && -z "$input_dir" ]]; then
            create_group "$label" "$name"
            created+="$name"$'\n'
        fi
    done <<< "$missing_groups"
    printf "\n"
fi

# ============================================================
# Report
# ============================================================

printf "Mirrored groups (%s), each labelled with its lowercased name:\n" "$(count_lines "$mirrored")"
printf "%s\n" "$mirrored" | sed '/^$/d;s/^/  /'

printf "\nGroups with no matching label, not mirrored (%s):\n" "$(count_lines "$unmirrored")"
printf "%s\n" "$unmirrored" | sed '/^$/d;s/^/  /'

# ============================================================
# Write
# ============================================================

new_file="$tmp_dir/contact-groups.txt"
{ printf "%s\n" "$mirrored"; printf "%s" "$created"; } | sed '/^$/d' | LC_ALL=C sort > "$new_file"

if [[ "$dry_run" == true ]]; then
    printf "\n(dry run — %s not written)\n" "$output_file"
    exit 0
fi

if [[ -f "$output_file" ]] && cmp -s "$new_file" "$output_file"; then
    printf "\n%s is already up to date.\n" "$output_file"
else
    mkdir -p "$(dirname "$output_file")"
    cp "$new_file" "$output_file"
    printf "\nWrote %s. Review with git diff, then run scripts/generate.sh.\n" "$output_file"
fi

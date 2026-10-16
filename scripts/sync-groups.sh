#!/bin/bash
# sync-groups.sh — Keep Proton labels and contact groups in step as pairs and
# write the list generate.sh expands.
#
# Each topic label is paired with a contact group of the same name, the
# group's name lowercased being the label's. This reads both from the Proton
# API and, for every pair:
#   - a label with no group gets one, named in title case, unless filters/
#     file into that label;
#   - a group with no label gets one, named in lowercase;
#   - a rename on one side is made on the other;
#   - a deletion on one side is offered for the other, after confirmation.
# New entries take the colour of the side they are created from. Groups in
# filters/shared/group-only-groups.txt drive routing and never get a label.
#
# Renames and deletions are detected by ID against the pairs from the last
# sync, kept in filters/shared/contact-group-pairs.json. Every paired group
# is written to filters/shared/contact-groups.txt, which generate.sh reads,
# so generating never needs a live session. Commit both files.
#
# REQUIREMENTS:
#   - jq, curl, and session credentials as for scripts/upload.sh
#
# USAGE:
#   bash scripts/sync-groups.sh [--dry-run] [--input-dir DIR]
#
#   --dry-run         Print the plan without changing Proton or writing files.
#   --input-dir DIR   Read DIR/groups.json and DIR/labels.json (saved responses
#                     from GET core/v4/labels?Type=2 and ?Type=1) instead of
#                     calling Proton. Offline, so changes are reported rather
#                     than made. Used by the tests.
#
# Deletions are only made when run interactively; otherwise they are reported
# and offered again on the next run.
#
# The output paths can be overridden with CONTACT_GROUPS_FILE and
# CONTACT_GROUPS_STATE_FILE.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

source scripts/lib/proton-api.sh

output_file="${CONTACT_GROUPS_FILE:-filters/shared/contact-groups.txt}"
state_file="${CONTACT_GROUPS_STATE_FILE:-filters/shared/contact-group-pairs.json}"
group_only_file="filters/shared/group-only-groups.txt"
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

live=true
[[ "$dry_run" == true || -n "$input_dir" ]] && live=false

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
# Plan
# ============================================================

state_json="$tmp_dir/state.json"
if [[ -f "$state_file" ]]; then
    cp "$state_file" "$state_json"
else
    printf "[]\n" > "$state_json"
fi

group_only_json="$tmp_dir/group-only.json"
sed '/^$/d' "$group_only_file" | jq -R . | jq -s . > "$group_only_json"

filed_json="$tmp_dir/filed.json"
{ grep -rhoE 'fileinto "[^"]+"' "$filters_dir" || true; } \
    | sed -E 's/^fileinto "(.*)"$/\1/' | LC_ALL=C sort -u | jq -R . | jq -s . > "$filed_json"

plan_json="$tmp_dir/plan.json"
jq -n -f scripts/lib/sync-plan.jq \
    --slurpfile groups "$groups_json" \
    --slurpfile labels "$labels_json" \
    --slurpfile state "$state_json" \
    --slurpfile group_only "$group_only_json" \
    --slurpfile filed "$filed_json" > "$plan_json"

plan_count() { jq -r ".$1 | length" "$plan_json"; }
plan_items() { jq -c ".$1[]" "$plan_json"; }

# Pairs that end up in the state file. Planned pairs are written as they will
# be once renames are made; deletions declined or skipped keep their pair so
# they are offered again, and conflicts keep theirs until resolved.
# Only pairs whose two sides both exist are mirrored.
pairs_json="$tmp_dir/pairs.json"
mirrored_json="$tmp_dir/mirrored.json"
jq '.pairs + .kept' "$plan_json" > "$pairs_json"
jq '.pairs' "$plan_json" > "$mirrored_json"

append_pair() {
    jq --argjson pair "$2" '. + [$pair]' "$1" > "$1.new"
    mv "$1.new" "$1"
}

add_pair() {
    append_pair "$pairs_json" "$1"
    append_pair "$mirrored_json" "$1"
}

action_verb() {
    if [[ "$live" == true ]]; then printf "%s" "$1"; else printf "%s" "$2"; fi
}

# ============================================================
# Renames
# ============================================================

rename_entry() {
    local item="$1" id body response
    id=$(jq -r '.ID' <<< "$item")
    body=$(jq '{Name: .To, Color: .Color}' <<< "$item")
    response=$(api_put "core/v4/labels/$id" "$body")
    check_response_code "$response" "rename $(jq -r '"\(.Kind) \(.From)"' <<< "$item")"
}

if [[ $(plan_count renames) -gt 0 ]]; then
    printf "%s (%s):\n" "$(action_verb "Renaming to follow the other side of the pair" "To rename to follow the other side of the pair")" "$(plan_count renames)"
    while IFS= read -r item <&3; do
        jq -r '"  \(.Kind) \(.From)  ->  \(.To)"' <<< "$item"
        [[ "$live" == true ]] && rename_entry "$item"
    done 3< <(plan_items renames)
    printf "\n"
fi

if [[ $(plan_count conflicts) -gt 0 ]]; then
    printf "Pairs renamed on both sides to names that no longer match, left alone (%s):\n" "$(plan_count conflicts)"
    jq -r '.conflicts[] | "  group \(.Group)  /  label \(.Label)"' "$plan_json"
    printf "Rename one to match the other and rerun.\n\n"
fi

# ============================================================
# Deletions
# ============================================================

# Deleting a group loses its memberships and deleting a label strips it from
# every message, so each one is confirmed and never made unattended.
if [[ $(plan_count deletes) -gt 0 ]]; then
    printf "Pairs with one side deleted since the last sync (%s):\n" "$(plan_count deletes)"
    while IFS= read -r item <&3; do
        description=$(jq -r '"\(.Kind) \(.Name) (its \(.Gone) was deleted)"' <<< "$item")
        delete=false
        if [[ "$live" == true && -t 0 ]]; then
            printf "  Delete %s? [y/N] " "$description"
            read -r answer
            [[ "$answer" == [yY] ]] && delete=true
        else
            printf "  %s\n" "$description"
        fi
        if [[ "$delete" == true ]]; then
            response=$(api_delete "core/v4/labels/$(jq -r '.ID' <<< "$item")")
            check_response_code "$response" "delete $description"
        else
            append_pair "$pairs_json" "$(jq -c '.Pair' <<< "$item")"
        fi
    done 3< <(plan_items deletes)
    if [[ "$live" == false || ! -t 0 ]]; then
        printf "Run interactively to confirm deleting these.\n"
    fi
    printf "Kept sides are offered again on the next run. To keep a group without\n"
    printf "a label, add it to %s.\n\n" "$group_only_file"
fi

# ============================================================
# Creations
# ============================================================

create_entry() {
    local item="$1" type="$2" body response
    body=$(jq --argjson type "$type" --arg default_color "#8080FF" \
        '{Name, Color: (.Color // $default_color), Type: $type}' <<< "$item")
    response=$(api_post "core/v4/labels" "$body")
    check_response_code "$response" "create $(jq -r '.Name' <<< "$item")" || return 1
    jq -r '.Label.ID' <<< "$response"
}

if [[ $(plan_count create_labels) -gt 0 ]]; then
    printf "%s (%s):\n" "$(action_verb "Creating labels for groups with no label" "Labels to create for groups with no label")" "$(plan_count create_labels)"
    while IFS= read -r item <&3; do
        jq -r '"  \(.Name)  <-  \(.Group.Name)"' <<< "$item"
        if [[ "$live" == true ]]; then
            id=$(create_entry "$item" 1)
            add_pair "$(jq -c --arg id "$id" '{Group, Label: {ID: $id, Name}}' <<< "$item")"
        fi
    done 3< <(plan_items create_labels)
    printf "\n"
fi

if [[ $(plan_count create_groups) -gt 0 ]]; then
    printf "%s (%s):\n" "$(action_verb "Creating contact groups for labels with no group and no rule in filters/" "Contact groups to create for labels with no group and no rule in filters/")" "$(plan_count create_groups)"
    while IFS= read -r item <&3; do
        jq -r '"  \(.Name)  <-  \(.Label.Name)"' <<< "$item"
        if [[ "$live" == true ]]; then
            id=$(create_entry "$item" 2)
            add_pair "$(jq -c --arg id "$id" '{Group: {ID: $id, Name}, Label}' <<< "$item")"
        fi
    done 3< <(plan_items create_groups)
    printf "\n"
fi

# ============================================================
# Report
# ============================================================

mirrored=$(jq -r '.[].Group.Name' "$mirrored_json" | LC_ALL=C sort)

count_lines() {
    printf "%s\n" "$1" | sed '/^$/d' | wc -l | tr -d ' '
}

printf "Mirrored groups (%s), each labelled with its lowercased name:\n" "$(count_lines "$mirrored")"
printf "%s\n" "$mirrored" | sed '/^$/d;s/^/  /'

printf "\nGroup-only groups, never labelled (%s):\n" "$(plan_count group_only)"
jq -r '.group_only[] | "  \(.)"' "$plan_json"

# ============================================================
# Write
# ============================================================

if [[ "$dry_run" == true ]]; then
    printf "\n(dry run — %s and %s not written)\n" "$output_file" "$state_file"
    exit 0
fi

new_file="$tmp_dir/contact-groups.txt"
printf "%s\n" "$mirrored" | sed '/^$/d' > "$new_file"

new_state="$tmp_dir/contact-group-pairs.json"
jq 'unique_by(.Group.ID) | sort_by(.Group.Name)' "$pairs_json" > "$new_state"

write_if_changed() {
    local new="$1" path="$2"
    if [[ -f "$path" ]] && cmp -s "$new" "$path"; then
        printf "%s is already up to date.\n" "$path"
    else
        mkdir -p "$(dirname "$path")"
        cp "$new" "$path"
        printf "Wrote %s.\n" "$path"
    fi
}

printf "\n"
write_if_changed "$new_file" "$output_file"
write_if_changed "$new_state" "$state_file"

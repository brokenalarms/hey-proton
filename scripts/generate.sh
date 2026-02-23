#!/bin/bash

# ============================================================
# Configuration
# ============================================================

# Maximum characters per Proton Mail filter, as enforced by Proton.
# Filters are packed greedily to stay within this limit.
# To find your limit: paste a filter into Proton and note when it rejects it.
CHARACTER_LIMIT=32000

# Directory containing files to process
input_dir="filters"

# Setup file prepended to every output group
setup_file="$input_dir/00 - setup.sieve"

# All filter files in processing order (setup is handled separately)
filter_files=(
    "$input_dir/01 - spam & ignored.sieve"
    "$input_dir/02 - screened out.sieve"
    "$input_dir/03 - label decoration.sieve"
    "$input_dir/04 - alerts.sieve"
    "$input_dir/05 - paper trail.sieve"
    "$input_dir/06 - the feed.sieve"
    "$input_dir/07 - needs admin and archive.sieve"
)

# Private data files used for macro expansion
list_files=(
    "private/contact groups.txt"
    "private/contact groups.txt"
    "private/email alias regexes.txt"
    "private/test address regexes.txt"
)

# Array to store regex patterns
regex_patterns=(
    '\{\{contact groups\.txt list expansion( excluding (.*))?\}\}'
    '\{\{contact groups\.txt fileinto expansion( excluding (.*))?\}\}'
    '\{\{email alias regexes\.txt string expansion\}\}'
    '\{\{test address regexes\.txt string expansion\}\}'
)

# Array to store corresponding function names
expansion_functions=(
    "expand_contact_groups_list"
    "expand_contact_groups_fileinto"
    "expand_to_string_syntax"
    "expand_to_string_syntax"
)

# ============================================================
# Helper functions (unchanged)
# ============================================================

list_elements=()
exclude_elements=()

# Global variables to store leading whitespace and trimmed line
leading_whitespace=""
trimmed_line=""

read_list_elements() {
    local file="$1"
    local elements=()

    if [[ ! -f "$file" ]]; then
        printf "Error: List file not found at %s.\n" "$file" >&2
        exit 1
    fi

    # Read each line from the file into the elements array
    while IFS= read -r line || [[ -n "$line" ]]; do
        elements+=("$line")
    done < "$file"

    # Output each element on a new line to preserve lines with spaces
    printf "%s\n" "${elements[@]}"
}

get_trimmed_line_and_whitespace() {
    local line="$1"
    # Extract leading whitespace and trimmed content
    leading_whitespace=$(printf "%s" "$line" | sed -E 's/^([[:space:]]*).*/\1/')
    trimmed_line=$(printf "%s" "$line" | sed -E 's/^[[:space:]]+//')
}

print_and_clear_list_elements() {
    for element in "${list_elements[@]}"; do
        printf "%s%s\n" "$leading_whitespace" "$element"
    done

    # Clear the global list_elements array
    list_elements=()
}

generate_expanded_lines() {
    local line="$1"

    # Get the leading whitespace and trimmed content of the line
    get_trimmed_line_and_whitespace "$line"

    # Iterate over the regex patterns and corresponding expansion functions
    for i in "${!regex_patterns[@]}"; do
        if [[ $line =~ ${regex_patterns[$i]} ]]; then
            # Read the appropriate list elements into the global list_elements array
            list_elements=()
            local list_file="${list_files[$i]}"
            while IFS= read -r element; do
                list_elements+=("$element")
            done < <(read_list_elements "$list_file")

            # Extract exclusion elements if present into the global exclude_elements array
            exclude_elements=()
            if [[ -n "${BASH_REMATCH[2]}" ]]; then
                IFS=',' read -ra exclude_elements <<< "$(echo "${BASH_REMATCH[2]}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | sed -E 's/[[:space:]]*,[[:space:]]*/,/g')"
            fi

            # Output the opening HTML-like comment with calculated whitespace and trimmed line
            output_html_comment "<" ">"

            # Call the appropriate expansion function
            "${expansion_functions[$i]}"

            # Output the closing HTML-like comment
            output_html_comment "</" ">"
            return
        fi
    done

    # Output the original line with its existing whitespace
    printf "%s\n" "$line"
}

expand_to_string_syntax() {
    wrap_print_and_clear_list_elements "\""
}

expand_to_matches_syntax() {
    wrap_print_and_clear_list_elements "*" "\""
}

wrap_print_and_clear_list_elements() {
    local surrounding_chars=("$@")

    # Apply each surrounding character in sequence
    for char in "${surrounding_chars[@]}"; do
        for i in "${!list_elements[@]}"; do
            list_elements[$i]="${char}${list_elements[$i]}${char}"
        done
    done

    # Print and clear the list with leading whitespace
    print_and_clear_list_elements
}

output_html_comment() {
    local tag_start="$1"  # Start of the tag, e.g., "<" or "</"
    local tag_end="$2"    # End of the tag, typically ">"

    # Output the tag with the extracted leading whitespace and trimmed line
    printf "%s# %s%s%s\n" "$leading_whitespace" "$tag_start" "$trimmed_line" "$tag_end"
}

expand_contact_groups_list() {
    filter_excluded_elements

    # Format each element for output with a comma at the end (except the last)
    local total_elements=${#list_elements[@]}
    for i in "${!list_elements[@]}"; do
        local element="header :list \"from\" \":addrbook:personal?label=${list_elements[$i]}\""
        # Append a comma to all but the last element
        if [[ $i -lt $((total_elements - 1)) ]]; then
            element="${element},"
        fi
        list_elements[$i]="$element"
    done

    # Print the formatted elements with the leading whitespace from the parsed line
    print_and_clear_list_elements
}

expand_contact_groups_fileinto() {
    filter_excluded_elements

    # Format each element as a fileinto statement
    for i in "${!list_elements[@]}"; do
        local lowercase_element
        lowercase_element=$(printf "%s" "${list_elements[$i]}" | tr '[:upper:]' '[:lower:]')
        list_elements[$i]=$(printf "if header :list \"from\" \":addrbook:personal?label=%s\" {\n  fileinto \"%s\";\n}" "${list_elements[$i]}" "$lowercase_element")
    done

    # Print the formatted elements with the leading whitespace from the parsed line
    print_and_clear_list_elements
}

filter_excluded_elements() {
    local included_elements=()
    for element in "${list_elements[@]}"; do
        local excluded=false
        for exclude in "${exclude_elements[@]}"; do
            if [[ "$element" == "$exclude" ]]; then
                excluded=true
                break
            fi
        done
        if [[ $excluded == false ]]; then
            included_elements+=("$element")
        fi
    done
    list_elements=("${included_elements[@]}")
}

process_file() {
    local file="$1"
    local output="$2"
    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            generate_expanded_lines "$line" >> "$output"
        done < "$file"
    fi
}

# ============================================================
# Clipboard support
# ============================================================

copy_to_clipboard() {
    local file="$1"
    if command -v pbcopy &>/dev/null; then
        pbcopy < "$file"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$file"
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --input < "$file"
    else
        return 1
    fi
}

# ============================================================
# Build: expand all filters to temp files
# ============================================================

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

setup_tmp="$tmp_dir/setup"
> "$setup_tmp"
process_file "$setup_file" "$setup_tmp"
setup_size=$(wc -c < "$setup_tmp")

filter_tmps=()
filter_sizes=()
for file in "${filter_files[@]}"; do
    tmp="$tmp_dir/$(basename "$file")"
    > "$tmp"
    process_file "$file" "$tmp"
    filter_tmps+=("$tmp")
    filter_sizes+=("$(wc -c < "$tmp")")
done

# ============================================================
# Write output files (one per source filter)
# ============================================================

rm -f dist/output-*.sieve

output_files=()
for i in "${!filter_files[@]}"; do
    basename_f=$(basename "${filter_files[$i]}" .sieve)
    output="dist/output-${basename_f}.sieve"
    output_files+=("$output")
    printf "# hey-proton: 00 - setup (prepended to every filter)\n" > "$output"
    cat "$setup_tmp" >> "$output"
    printf "# hey-proton: %s\n" "$basename_f" >> "$output"
    cat "${filter_tmps[$i]}" >> "$output"
    if [[ $CHARACTER_LIMIT -gt 0 ]]; then
        combined=$((setup_size + filter_sizes[i]))
        if [[ $combined -gt $CHARACTER_LIMIT ]]; then
            printf "Warning: %s is %d chars, over the %d limit.\n" \
                "$output" "$combined" "$CHARACTER_LIMIT" >&2
        fi
    fi
done

# ============================================================
# Report and interactive guided paste
# ============================================================

total=${#output_files[@]}
printf "Generated %d filter file(s):\n" "$total"
for f in "${output_files[@]}"; do
    printf "  %s  (%d chars)\n" "$f" "$(wc -c < "$f")"
done
printf "\n"

for n in "${!output_files[@]}"; do
    file="${output_files[$n]}"
    num=$((n + 1))

    if copy_to_clipboard "$file"; then
        printf "Filter %d of %d copied to clipboard.\n" "$num" "$total"
    else
        printf "Filter %d of %d: clipboard unavailable — paste from %s\n" "$num" "$total" "$file"
    fi

    if [[ $num -lt $total ]]; then
        printf "Paste into Proton Mail, then press Enter for the next filter... "
        read -r
        printf "\n"
    else
        printf "Paste into Proton Mail. Done!\n"
    fi
done

exit 0

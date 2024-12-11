#!/bin/bash

# Directory containing files to process
input_dir="filters"  # Directory path
output_file="dist/output.sieve"  # Final concatenated output

# Array to store list file paths
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

# Clear or create the output file
> "$output_file"

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

# Process each file in the directory
for file in "$input_dir"/*.sieve; do
    if [[ -f "$file" ]]; then
        # Read each line from the file
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Use generate_expanded_lines to process each line
            generate_expanded_lines "$line" >> "$output_file"
        done < "$file"
    fi
done
# Copy the output file to the clipboard
pbcopy < "$output_file"
printf "Output saved to %s and copied to the clipboard\n" "$output_file"
exit 0
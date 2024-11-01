#!/bin/bash

# Directory containing files to process
input_dir="filters"  # Directory path
output_file="dist/output.sieve"  # Final concatenated output

# Array to store list file paths
list_files=(
    "private/contact groups.txt"
    "private/contact groups.txt"
    "private/email alias regexes.txt"
)

# Array to store regex patterns
regex_patterns=(
    '\{\{contact groups\.txt list expansion( excluding (.*))?\}\}'
    '\{\{contact groups\.txt fileinto expansion( excluding (.*))?\}\}'
    '\{\{email alias regexes\.txt list expansion\}\}'
)

# Array to store corresponding function names
expansion_functions=(
    "expand_contact_groups_list"
    "expand_contact_groups_fileinto"
    "expand_lines_as_strings"
)


# Clear or create the output file
> "$output_file"

list_elements=()
exclude_elements=()

read_list_elements() {
    local file="$1"
    local elements=()

    if [[ ! -f "$file" ]]; then
        echo "Error: List file not found at $file." >&2
        exit 1
    fi

    # Read each line from the file into the elements array
    while IFS= read -r line || [[ -n "$line" ]]; do
        elements+=("$line")
    done < "$file"

    # Output each element on a new line to preserve lines with spaces
    printf "%s\n" "${elements[@]}"
}

generate_expanded_lines() {
    local line="$1"

    # Iterate over the regex patterns and corresponding expansion functions
    for i in "${!regex_patterns[@]}"; do
        if [[ $line =~ ${regex_patterns[$i]} ]]; then
            # Read the appropriate list elements dynamically into the global list_elements array
            list_elements=()
            local list_file="${list_files[$i]}"
            while IFS= read -r element; do
                list_elements+=("$element")
            done < <(read_list_elements "$list_file")

            # Extract exclusion elements if present into the global exclude_elements array
            exclude_elements=()
            if [[ -n "${BASH_REMATCH[2]}" ]]; then
                IFS=',' read -ra exclude_elements <<< "${BASH_REMATCH[2]}"
            fi
            # Output the opening HTML-like comment
            printf "# <%s>\n" "$line"

            # Call the appropriate expansion function
            "${expansion_functions[$i]}"

            # Output the closing HTML-like comment
            printf "# </%s>\n" "$line"

            return
        fi
    done

    # Output the original line and append a newline
    printf "%s\n" "$line"
}

# Global arrays to store list and exclude elements

expand_contact_groups_list() {
    local included_elements=()

    # Check each element in list_elements and exclude if necessary
    for element in "${list_elements[@]}"; do
        local excluded=false

        # Check if the element should be excluded
        for exclude in "${exclude_elements[@]}"; do
            if [[ "$element" == "$exclude" ]]; then
                excluded=true
                break
            fi
        done

        # Add to included_elements if not excluded
        if [[ $excluded == false ]]; then
            included_elements+=("$element")
        fi
    done

    # Output the included elements in the desired format
    local total_included=${#included_elements[@]}
    for i in "${!included_elements[@]}"; do
        element="${included_elements[$i]}"
        printf "  header :list \"from\" \":addrbook:personal?label=%s\"" "$element"
        if [[ $i -lt $((total_included - 1)) ]]; then
            printf ","
        fi
        printf "\n"
    done
}

expand_lines_as_strings() {
    # Use the global list_elements array and clear it after use
    local total_elements=${#list_elements[@]}
    for i in "${!list_elements[@]}"; do
        local element="${list_elements[$i]}"
        printf "      \"%s\"" "$element"  # Surrounding with quotes
        if [[ $i -lt $((total_elements - 1)) ]]; then
            printf ","  # Add a comma if it's not the last element
        fi
        printf "\n"  # Newline after each element
    done

    # Clear the global list_elements array
    list_elements=()
}

expand_contact_groups_fileinto() {
    # Use the global list_elements and exclude_elements arrays
    for element in "${list_elements[@]}"; do
        if [[ ! " ${exclude_elements[@]} " =~ " $element " ]]; then
            local lowercase_element
            lowercase_element=$(echo "$element" | tr '[:upper:]' '[:lower:]')
            printf "if header :list \"from\" \":addrbook:personal?label=%s\" {\n" "$element"
            printf "  fileinto \"%s\";\n" "$lowercase_element"
            printf "}\n"
        fi
    done

    # Clear the global list_elements and exclude_elements arrays
    list_elements=()
    exclude_elements=()
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
echo "Output saved to $output_file and copied to the clipboard"
exit 0
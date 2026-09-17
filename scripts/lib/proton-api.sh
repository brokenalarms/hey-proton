#!/bin/bash
# proton-api.sh — Session loading and request helpers for the informal Proton
# Mail API, shared by scripts/upload.sh and scripts/sync-groups.sh.
#
# Source from a script that has already cd'd to the repository root:
#   source scripts/lib/proton-api.sh
#   require_api_dependencies
#   load_credentials
#   response=$(api_get "mail/v4/filters")
#
# Credentials are checked in order:
#   1. Clipboard: "Copy as cURL" from browser dev tools (always wins if present)
#   2. PROTON_UID + PROTON_COOKIE env vars
#   3. private/proton-session.json (override the path with PROTON_SESSION_FILE)
#   4. Interactive paste of a cURL command, ended by an empty line
#
# SECURITY: See docs/proton-api.md before using.

API_BASE="https://mail.proton.me/api"
session_file="${PROTON_SESSION_FILE:-private/proton-session.json}"
UID_VALUE=""
COOKIE_VALUE=""

require_api_dependencies() {
    if ! command -v jq &>/dev/null; then
        printf "Error: jq is required. Install via: brew install jq | apt install jq\n" >&2
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        printf "Error: curl is required.\n" >&2
        exit 1
    fi
}

parse_curl_command() {
    local curl_str="$1"
    UID_VALUE=$(printf "%s" "$curl_str" | grep -oiE "x-pm-uid: [^'\"]+" | head -1 | sed -E 's/[Xx]-[Pp][Mm]-[Uu][Ii][Dd]: //' || true)
    COOKIE_VALUE=$(printf "%s" "$curl_str" | grep -oiE "cookie: [^'\"]+" | head -1 | sed -E 's/[Cc]ookie: //' || true)
}

read_clipboard() {
    if command -v pbpaste &>/dev/null; then
        pbpaste 2>/dev/null || true
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard -o 2>/dev/null || true
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --output 2>/dev/null || true
    fi
}

save_session() {
    printf "Credentials extracted. Saving to %s for reuse.\n\n" "$session_file"
    mkdir -p "$(dirname "$session_file")"
    jq -n --arg uid "$UID_VALUE" --arg cookie "$COOKIE_VALUE" \
        '{"UID": $uid, "Cookie": $cookie}' > "$session_file"
}

# A "Copy as cURL" command never contains a blank line, so an empty line ends
# the paste; EOF (Ctrl+D) is accepted too.
read_pasted_curl() {
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        printf "%s\n" "$line"
    done
}

load_credentials() {
    local clipboard curl_input

    # 1. A curl command on the clipboard is the freshest source, so it wins
    #    over a saved session whose AUTH cookie may have rotated since.
    clipboard=$(read_clipboard)
    if [[ "$clipboard" == curl* ]]; then
        parse_curl_command "$clipboard"
        if [[ -n "$UID_VALUE" && -n "$COOKIE_VALUE" ]]; then
            save_session
        fi
    fi

    # 2. Env vars
    if [[ -z "$UID_VALUE" || -z "$COOKIE_VALUE" ]]; then
        UID_VALUE="${PROTON_UID:-}"
        COOKIE_VALUE="${PROTON_COOKIE:-}"
    fi

    # 3. Session file
    if [[ -z "$UID_VALUE" || -z "$COOKIE_VALUE" ]]; then
        if [[ -f "$session_file" ]]; then
            [[ -z "$UID_VALUE" ]]    && UID_VALUE=$(jq -r '.UID // empty' "$session_file")
            [[ -z "$COOKIE_VALUE" ]] && COOKIE_VALUE=$(jq -r '.Cookie // empty' "$session_file")
        fi
    fi

    # 4. Interactive paste
    if [[ -z "$UID_VALUE" || -z "$COOKIE_VALUE" ]]; then
        printf "No credentials found. To authenticate:\n"
        printf "  1. Open mail.proton.me → Cmd+Opt+I → Network tab\n"
        printf "  2. Right-click any mail.proton.me/api/ request → Copy as cURL\n\n"
        printf "Paste the cURL command below, then press Enter on an empty line:\n"
        curl_input=$(read_pasted_curl)
        parse_curl_command "$curl_input"

        if [[ -n "$UID_VALUE" && -n "$COOKIE_VALUE" ]]; then
            save_session
        else
            printf "Error: could not extract credentials.\n" >&2
            printf "Make sure you copied a cURL command for a mail.proton.me/api/ request.\n" >&2
            exit 1
        fi
    fi
}

api_request() {
    local method="$1"
    local path="$2"
    local body="${3:-}"
    local args=(
        -sS -X "$method"
        -H "x-pm-uid: $UID_VALUE"
        -H "Cookie: $COOKIE_VALUE"
        -H "Content-Type: application/json"
        -H "x-pm-appversion: Other"
    )
    if [[ -n "$body" ]]; then
        args+=(-d "$body")
    fi
    curl "${args[@]}" "${@:4}" "$API_BASE/$path"
}

api_get()  { api_request GET  "$1"; }
api_post() { api_request POST "$1" "$2"; }
api_put()  { api_request PUT  "$1" "$2"; }

# For endpoints whose success response is an empty object with no Code to inspect:
# prints the HTTP status and writes the response body to the file given as $3.
api_post_status() { api_request POST "$1" "$2" -o "$3" -w '%{http_code}'; }

check_response_code() {
    local response="$1"
    local context="$2"
    local code
    code=$(printf "%s" "$response" | jq -r '.Code // empty' 2>/dev/null || true)
    if [[ "$code" == "1000" ]]; then
        return 0
    fi
    if [[ -z "$code" ]]; then
        printf "Error in %s: unrecognised response:\n%s\n" \
            "$context" "$(printf "%s" "$response" | head -c 1000)" >&2
        return 1
    fi
    printf "Error in %s (Code: %s): %s\n" \
        "$context" "$code" \
        "$(printf "%s" "$response" | jq -r '.Error // "unknown error"')" >&2
    return 1
}

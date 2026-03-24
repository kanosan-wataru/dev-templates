#!/usr/bin/env bash
# Array utility helpers for bash
# Replaces zsh array operations: ${(Ie)}, ${(o)}, ${(s:...:)}

# Check if value exists in array
# Usage: array_contains "value" "${array[@]}"
# Returns: 0 if found, 1 if not
array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Sort array ascending (newline-safe)
# Usage: array_sort sorted_var "${array[@]}"
array_sort() {
    local -n _result="$1"
    shift
    readarray -t _result < <(printf '%s\n' "$@" | sort)
}

# Sort array descending
# Usage: array_sort_desc sorted_var "${array[@]}"
array_sort_desc() {
    local -n _result="$1"
    shift
    readarray -t _result < <(printf '%s\n' "$@" | sort -r)
}

# Split string by delimiter into array
# Usage: string_split result_var "delimiter" "string"
string_split() {
    local -n _result="$1"
    local delimiter="$2" string="$3"
    local old_ifs="$IFS"
    IFS="$delimiter" read -ra _result <<<"$string"
    IFS="$old_ifs"
}

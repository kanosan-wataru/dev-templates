#!/usr/bin/env bash
# Backup file helpers
# Replaces zsh glob qualifiers: *(N^/Om[1])

# Find the newest backup file matching a pattern
# Usage: find_newest_backup "/path/to/file.bak.*"
# Returns: path to newest backup (stdout), or empty + return 1
find_newest_backup() {
    local pattern="$1"
    local newest
    # Use ls -t for modification-time sort (newest first)
    # Redirect stderr to hide "no matches" errors
    # shellcheck disable=SC2086
    newest=$(ls -t $pattern 2>/dev/null | head -1 || true)
    if [[ -n "$newest" ]]; then
        printf '%s' "$newest"
        return 0
    fi
    return 1
}

# Create a timestamped backup of a file
# Usage: create_backup "/path/to/file"
# Returns: backup path (stdout)
create_backup() {
    local file="$1"
    local backup
    backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$file" "$backup"
    printf '%s' "$backup"
}

#!/usr/bin/env bats

# Backup restore sort order tests (regression for #59)

MODULES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../modules" && pwd)"

@test "no modules use om[1] (oldest-first) for backup restore" {
    for f in "$MODULES_DIR"/*.sh; do
        run grep -n 'om\[1\]' "$f"
        if [ "$status" -eq 0 ]; then
            echo "$(basename "$f") uses om[1] (oldest-first) instead of Om[1] (newest-first): $output" >&2
            return 1
        fi
    done
}

@test "modules using backup restore use Om[1] (newest-first)" {
    local found=0
    for f in "$MODULES_DIR"/*.sh; do
        if grep -q 'Om\[1\]' "$f"; then
            found=1
        fi
    done
    [ "$found" -eq 1 ] || skip "No modules use backup restore pattern"
}

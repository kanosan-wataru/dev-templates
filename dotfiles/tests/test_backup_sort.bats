#!/usr/bin/env bats

# Tests for find_newest_backup() in lib/backup.sh

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=../lib/backup.sh
    source "$PROJECT_ROOT/lib/backup.sh"
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ============================================================
# find_newest_backup() tests
# ============================================================

@test "find_newest_backup returns newest backup by modification time" {
    # Arrange: create backup files with different modification times
    touch "$TEST_TMPDIR/config.bak.20260101000000"
    touch "$TEST_TMPDIR/config.bak.20260301000000"
    touch "$TEST_TMPDIR/config.bak.20260201000000"
    # Ensure modification-time order matches name order
    touch -t 202601010000 "$TEST_TMPDIR/config.bak.20260101000000"
    touch -t 202603010000 "$TEST_TMPDIR/config.bak.20260301000000"
    touch -t 202602010000 "$TEST_TMPDIR/config.bak.20260201000000"

    # Act
    run find_newest_backup "$TEST_TMPDIR/config.bak.*"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"20260301000000"* ]]
}

@test "find_newest_backup returns 1 when no backups exist" {
    # Act
    run find_newest_backup "$TEST_TMPDIR/nonexistent.bak.*"

    # Assert
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "find_newest_backup handles single backup file" {
    # Arrange
    touch "$TEST_TMPDIR/config.bak.20260115120000"

    # Act
    run find_newest_backup "$TEST_TMPDIR/config.bak.*"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"20260115120000"* ]]
}

@test "find_newest_backup returns full path" {
    # Arrange
    touch "$TEST_TMPDIR/myfile.bak.20260501000000"

    # Act
    run find_newest_backup "$TEST_TMPDIR/myfile.bak.*"

    # Assert
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_TMPDIR/myfile.bak.20260501000000" ]
}

@test "find_newest_backup picks newest by mtime not by name" {
    # Arrange: name order differs from modification-time order
    touch "$TEST_TMPDIR/rc.bak.AAA"
    touch "$TEST_TMPDIR/rc.bak.ZZZ"
    # Make AAA newer by mtime even though ZZZ sorts later alphabetically
    touch -t 202601010000 "$TEST_TMPDIR/rc.bak.ZZZ"
    touch -t 202612010000 "$TEST_TMPDIR/rc.bak.AAA"

    # Act
    run find_newest_backup "$TEST_TMPDIR/rc.bak.*"

    # Assert: AAA is picked (newest mtime)
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc.bak.AAA" ]]
}

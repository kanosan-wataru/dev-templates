#!/usr/bin/env bats

# Behavior tests for --uninstall, --force, and --dry-run flags
# Verifies end-to-end flag behavior via setup.sh invocation
# and unit-level install_config behavior with flag combinations.

DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # Create isolated temp directories for each test
    TEST_TMPDIR="$(mktemp -d)"
    SRC_DIR="${TEST_TMPDIR}/src"
    DST_DIR="${TEST_TMPDIR}/dst"
    mkdir -p "$SRC_DIR" "$DST_DIR"

    # Source required libraries
    # shellcheck source=../lib/colors.sh
    source "${DOTFILES_DIR}/lib/colors.sh"
    # shellcheck source=../lib/array.sh
    source "${DOTFILES_DIR}/lib/array.sh"
    # shellcheck source=../lib/backup.sh
    source "${DOTFILES_DIR}/lib/backup.sh"
    _setup_colors

    # Default flags (overridden per test as needed)
    DRY_RUN=0
    FORCE=0
    BACKUP_SUFFIX=".backup.test"

    # Source shared helper functions (run_cmd, install_config, install_source_config)
    # shellcheck source=helpers/setup_functions.bash
    source "$BATS_TEST_DIRNAME/helpers/setup_functions.bash"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ============================================================
# --uninstall flag tests (end-to-end via setup.sh)
# ============================================================

@test "uninstall_dryrun_runs_without_error" {
    run bash "${DOTFILES_DIR}/setup.sh" --uninstall --dry-run
    [ "$status" -eq 0 ]
}

@test "uninstall_dryrun_shows_uninstall_message" {
    run bash "${DOTFILES_DIR}/setup.sh" --uninstall --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"アンインストール"* ]]
}

@test "uninstall_dryrun_shows_dryrun_mode" {
    run bash "${DOTFILES_DIR}/setup.sh" --uninstall --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

# ============================================================
# --force flag tests (unit-level via install_config)
# ============================================================

@test "force_dryrun_all_runs_without_error" {
    run bash "${DOTFILES_DIR}/setup.sh" --force --dry-run --all
    [ "$status" -eq 0 ]
}

@test "force_skips_diff_prompt" {
    # Arrange: source and destination differ, FORCE=1
    FORCE=1
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: no interactive prompt shown
    [ "$status" -eq 0 ]
    [[ "$output" != *"[y/N/d]"* ]]
}

@test "force_creates_backup_and_overwrites" {
    # Arrange: source and destination differ, FORCE=1
    FORCE=1
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: file overwritten and backup created
    [ "$status" -eq 0 ]
    [ "$(cat "${DST_DIR}/config")" = "new content" ]
    [ -f "${DST_DIR}/config${BACKUP_SUFFIX}" ]
    [ "$(cat "${DST_DIR}/config${BACKUP_SUFFIX}")" = "old content" ]
}

@test "no_force_noninteractive_skips_differing_file" {
    # NOTE: In non-interactive context (no TTY), install_config skips files
    # that differ when FORCE=0. The production version would show a diff prompt
    # in an interactive terminal.

    # Arrange: source and destination differ, FORCE=0 (default)
    FORCE=0
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: file NOT overwritten, skip message shown
    [ "$status" -eq 0 ]
    [ "$(cat "${DST_DIR}/config")" = "old content" ]
    [[ "$output" == *"スキップしました"* ]]
}

# ============================================================
# --dry-run flag tests (unit-level via install_config)
# ============================================================

@test "dryrun_does_not_create_new_files" {
    # Arrange: destination does not exist, DRY_RUN=1
    DRY_RUN=1
    printf 'test content\n' >"${SRC_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: destination file NOT created
    [ "$status" -eq 0 ]
    [ ! -f "${DST_DIR}/config" ]
}

@test "dryrun_does_not_modify_existing_files" {
    # Arrange: source and destination differ, DRY_RUN=1
    DRY_RUN=1
    printf 'original\n' >"${DST_DIR}/config"
    local original_hash
    original_hash=$(cksum "${DST_DIR}/config")

    printf 'modified\n' >"${SRC_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: file NOT modified
    [ "$status" -eq 0 ]
    local new_hash
    new_hash=$(cksum "${DST_DIR}/config")
    [ "$original_hash" = "$new_hash" ]
}

@test "dryrun_shows_update_preview_message" {
    # Arrange: source and destination differ, DRY_RUN=1
    DRY_RUN=1
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: dry-run message shown
    [ "$status" -eq 0 ]
    [[ "$output" == *"更新予定"* ]]
}

@test "dryrun_shows_dryrun_label_for_new_file" {
    # Arrange: destination does not exist, DRY_RUN=1
    DRY_RUN=1
    printf 'new content\n' >"${SRC_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: DRY-RUN label shown
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "force_dryrun_does_not_modify_files" {
    # Arrange: both flags active — DRY_RUN should take precedence
    FORCE=1
    DRY_RUN=1
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: file NOT modified (dry-run wins)
    [ "$status" -eq 0 ]
    [ "$(cat "${DST_DIR}/config")" = "old content" ]
    [[ "$output" == *"更新予定"* ]]
}

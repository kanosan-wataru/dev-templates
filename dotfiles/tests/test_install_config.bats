#!/usr/bin/env bats

# Tests for install_config() diff preview and install_source_config()
# Covers: new file deploy, idempotency, --force, --dry-run, source separation

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
# install_config() tests
# ============================================================

@test "test_install_config_new_file_deploys_without_prompt" {
    # Arrange: source file exists, destination does not
    printf 'hello world\n' >"${SRC_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: successful, file deployed
    [ "$status" -eq 0 ]
    [ -f "${DST_DIR}/config" ]
    [ "$(cat "${DST_DIR}/config")" = "hello world" ]
}

@test "test_install_config_same_content_skips" {
    # Arrange: source and destination have identical content
    printf 'identical content\n' >"${SRC_DIR}/config"
    printf 'identical content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: skipped (idempotent), output mentions skip
    [ "$status" -eq 0 ]
    [[ "$output" == *"スキップします"* ]]
}

@test "test_install_config_force_overwrites" {
    # Arrange: source and destination differ, FORCE=1
    FORCE=1
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: file overwritten, backup created
    [ "$status" -eq 0 ]
    [ "$(cat "${DST_DIR}/config")" = "new content" ]
    [ -f "${DST_DIR}/config${BACKUP_SUFFIX}" ]
    [ "$(cat "${DST_DIR}/config${BACKUP_SUFFIX}")" = "old content" ]
}

@test "test_install_config_dryrun_shows_message" {
    # Arrange: source and destination differ, DRY_RUN=1
    DRY_RUN=1
    printf 'new content\n' >"${SRC_DIR}/config"
    printf 'old content\n' >"${DST_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: dry-run message shown, file NOT modified
    [ "$status" -eq 0 ]
    [[ "$output" == *"更新予定"* ]]
    [ "$(cat "${DST_DIR}/config")" = "old content" ]
}

@test "test_install_config_dryrun_new_file_shows_message" {
    # Arrange: destination does not exist, DRY_RUN=1
    DRY_RUN=1
    printf 'new content\n' >"${SRC_DIR}/config"

    # Act
    run install_config "${SRC_DIR}/config" "${DST_DIR}/config" "test-config"

    # Assert: dry-run message shown (deploy), file NOT created
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [ ! -f "${DST_DIR}/config" ]
}

@test "test_install_config_missing_source_with_hint_warns" {
    # Arrange: source file does not exist, hint provided
    run install_config "${SRC_DIR}/nonexistent" "${DST_DIR}/config" "test-config" "ヒントメッセージ"

    # Assert: warning shown, no error exit
    [ "$status" -eq 0 ]
    [[ "$output" == *"見つかりません"* ]]
}

# ============================================================
# install_source_config() tests
# ============================================================

@test "test_install_source_config_creates_directory" {
    # Arrange: deploy dir does not exist
    local deploy_dir="${TEST_TMPDIR}/deploy_subdir"
    printf 'template content\n' >"${SRC_DIR}/template"
    printf '' >"${DST_DIR}/dotfile"

    # Act
    run install_source_config \
        "${SRC_DIR}/template" \
        "${DST_DIR}/dotfile" \
        "$deploy_dir" \
        "managed.sh" \
        "test-template"

    # Assert: directory created with correct permissions
    [ "$status" -eq 0 ]
    [ -d "$deploy_dir" ]
}

@test "test_install_source_config_deploys_template" {
    # Arrange
    local deploy_dir="${TEST_TMPDIR}/deploy"
    mkdir -p "$deploy_dir"
    printf 'template content\n' >"${SRC_DIR}/template"
    printf '' >"${DST_DIR}/dotfile"

    # Act
    run install_source_config \
        "${SRC_DIR}/template" \
        "${DST_DIR}/dotfile" \
        "$deploy_dir" \
        "managed.sh" \
        "test-template"

    # Assert: template deployed to deploy directory
    [ "$status" -eq 0 ]
    [ -f "${deploy_dir}/managed.sh" ]
    [ "$(cat "${deploy_dir}/managed.sh")" = "template content" ]
}

@test "test_install_source_config_adds_source_line" {
    # Arrange
    local deploy_dir="${TEST_TMPDIR}/deploy"
    mkdir -p "$deploy_dir"
    printf 'template content\n' >"${SRC_DIR}/template"
    printf '# existing config\n' >"${DST_DIR}/dotfile"

    # Act
    run install_source_config \
        "${SRC_DIR}/template" \
        "${DST_DIR}/dotfile" \
        "$deploy_dir" \
        "managed.sh" \
        "test-template"

    # Assert: source line appended to user's dotfile
    [ "$status" -eq 0 ]
    grep -qF "source \"${deploy_dir}/managed.sh\"" "${DST_DIR}/dotfile"
    grep -qF "dev-templates managed" "${DST_DIR}/dotfile"
}

@test "test_install_source_config_idempotent" {
    # Arrange: run once to set up initial state
    local deploy_dir="${TEST_TMPDIR}/deploy"
    mkdir -p "$deploy_dir"
    printf 'template content\n' >"${SRC_DIR}/template"
    printf '# existing config\n' >"${DST_DIR}/dotfile"

    # First run
    install_source_config \
        "${SRC_DIR}/template" \
        "${DST_DIR}/dotfile" \
        "$deploy_dir" \
        "managed.sh" \
        "test-template"

    local line_count_before
    line_count_before=$(grep -cF "source \"${deploy_dir}/managed.sh\"" "${DST_DIR}/dotfile")

    # Act: second run
    run install_source_config \
        "${SRC_DIR}/template" \
        "${DST_DIR}/dotfile" \
        "$deploy_dir" \
        "managed.sh" \
        "test-template"

    # Assert: source line NOT duplicated
    [ "$status" -eq 0 ]
    local line_count_after
    line_count_after=$(grep -cF "source \"${deploy_dir}/managed.sh\"" "${DST_DIR}/dotfile")
    [ "$line_count_before" -eq "$line_count_after" ]
    [[ "$output" == *"設定済み"* ]]
}

@test "test_install_source_config_dryrun" {
    # Arrange: DRY_RUN mode
    DRY_RUN=1
    local deploy_dir="${TEST_TMPDIR}/deploy_dry"
    printf 'template content\n' >"${SRC_DIR}/template"
    printf '# existing config\n' >"${DST_DIR}/dotfile"

    # Act
    run install_source_config \
        "${SRC_DIR}/template" \
        "${DST_DIR}/dotfile" \
        "$deploy_dir" \
        "managed.sh" \
        "test-template"

    # Assert: no files modified, dry-run message shown
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [ ! -d "$deploy_dir" ]
    # User's dotfile should not have source line
    ! grep -qF "source \"${deploy_dir}/managed.sh\"" "${DST_DIR}/dotfile"
}

# ============================================================
# --force / -f flag test
# ============================================================

@test "test_force_flag_sets_global" {
    # Verify --force and -f are parsed in setup.sh argument handling.
    # We test by grepping setup.sh for the flag pattern since we cannot
    # source setup.sh without triggering module loading side effects.
    local setup_sh="${DOTFILES_DIR}/setup.sh"

    # --force sets FORCE=1
    run grep -c '\-\-force.*\-f)' "$setup_sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    # FORCE=1 is the assigned value
    run grep -c 'FORCE=1' "$setup_sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    # FORCE defaults to 0
    run grep -c 'FORCE=0' "$setup_sh"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

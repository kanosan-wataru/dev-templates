#!/usr/bin/env bats

# --upgrade option behavior tests

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SETUP_SH="$PROJECT_ROOT/setup.sh"
}

# -- Behavior-based tests (replaces grep-based tests) --

@test "--upgrade flag is accepted without error" {
    run bash "$SETUP_SH" --upgrade --dry-run --all
    [ "$status" -eq 0 ]
}

@test "--upgrade --dry-run --all completes successfully" {
    run bash "$SETUP_SH" --upgrade --dry-run --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"アップグレード"* ]]
}

@test "without --upgrade, no upgrade messages appear" {
    run bash "$SETUP_SH" --dry-run --all
    [ "$status" -eq 0 ]
    [[ "$output" != *"アップグレードを実行します"* ]]
}

# -- Help text --

@test "--upgrade appears in help text" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--upgrade"* ]]
}

# -- Mutual exclusion --

@test "--upgrade and --uninstall are mutually exclusive" {
    run bash "$SETUP_SH" --upgrade --uninstall
    [ "$status" -ne 0 ]
    [[ "$output" == *"--upgrade"* ]]
    [[ "$output" == *"--uninstall"* ]]
}

@test "--uninstall and --upgrade (reversed order) are mutually exclusive" {
    run bash "$SETUP_SH" --uninstall --upgrade
    [ "$status" -ne 0 ]
    [[ "$output" == *"--upgrade"* ]]
}

# -- Selective upgrade --

@test "--upgrade --select with specific module works in dry-run" {
    run bash "$SETUP_SH" --upgrade --select git --dry-run
    [ "$status" -eq 0 ]
}

# -- Module UPGRADE reference check --

@test "all modules reference UPGRADE or document why not" {
    for f in "$PROJECT_ROOT/modules/"*.sh; do
        if ! grep -q -E 'UPGRADE|No upgrade path needed' "$f"; then
            echo "$(basename "$f") does not reference UPGRADE" >&2
            return 1
        fi
    done
}

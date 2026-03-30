#!/usr/bin/env bats

# --upgrade option tests

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SETUP_SH="$PROJECT_ROOT/setup.sh"
}

@test "--upgrade flag exists in setup.sh argument parsing" {
    run grep -q '\-\-upgrade)' "$SETUP_SH"
    [ "$status" -eq 0 ]
}

@test "UPGRADE variable is initialized to 0" {
    run grep -q 'UPGRADE=0' "$SETUP_SH"
    [ "$status" -eq 0 ]
}

@test "--upgrade sets UPGRADE=1" {
    run grep -q 'UPGRADE=1' "$SETUP_SH"
    [ "$status" -eq 0 ]
}

@test "--upgrade appears in help text" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--upgrade"* ]]
}

@test "--upgrade and --uninstall are mutually exclusive" {
    run bash "$SETUP_SH" --upgrade --uninstall
    [ "$status" -ne 0 ]
    [[ "$output" == *"--upgrade"* ]]
    [[ "$output" == *"--uninstall"* ]]
}

#!/usr/bin/env bats

# Positional argument tests for setup.sh

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SETUP_SH="$PROJECT_ROOT/setup.sh"
}

@test "positional arg selects module in dry-run" {
    run bash "$SETUP_SH" git --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git"* ]]
}

@test "multiple positional args select multiple modules" {
    run bash "$SETUP_SH" git zsh --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git"* ]]
    [[ "$output" == *"Zsh"* ]]
}

@test "positional args mixed with flags work" {
    run bash "$SETUP_SH" zsh --force --dry-run git
    [ "$status" -eq 0 ]
    [[ "$output" == *"Zsh"* ]]
    [[ "$output" == *"Git"* ]]
}

@test "invalid positional arg shows error" {
    run bash "$SETUP_SH" nonexistent --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"不明なモジュール"* ]]
}

@test "positional args and --select can be combined" {
    run bash "$SETUP_SH" git --select zsh --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git"* ]]
    [[ "$output" == *"Zsh"* ]]
}

@test "unknown --option still errors" {
    run bash "$SETUP_SH" --nonexistent
    [ "$status" -ne 0 ]
    [[ "$output" == *"不明なオプション"* ]]
}

@test "positional args appear in help text" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"MODULE"* ]]
}

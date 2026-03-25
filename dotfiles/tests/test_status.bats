#!/usr/bin/env bats

# --status option tests

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "--status option is recognized and exits 0" {
    run bash "$PROJECT_ROOT/setup.sh" --status
    [ "$status" -eq 0 ]
}

@test "--status shows header line with Module, Status, Version" {
    run bash "$PROJECT_ROOT/setup.sh" --status
    [[ "$output" == *"Module"* ]]
    [[ "$output" == *"Status"* ]]
    [[ "$output" == *"Version"* ]]
}

@test "--status shows all module IDs" {
    run bash "$PROJECT_ROOT/setup.sh" --status
    [[ "$output" == *"zsh"* ]]
    [[ "$output" == *"git"* ]]
    [[ "$output" == *"1password"* ]]
    [[ "$output" == *"modern-cli"* ]]
    [[ "$output" == *"node"* ]]
    [[ "$output" == *"docker"* ]]
    [[ "$output" == *"claude-code"* ]]
    [[ "$output" == *"python"* ]]
    [[ "$output" == *"gemini-cli"* ]]
    [[ "$output" == *"codex-cli"* ]]
}

@test "--status shows installed or not found for each module" {
    run bash "$PROJECT_ROOT/setup.sh" --status
    # Each module line should contain either "installed" or "not found"
    local module_lines
    module_lines=$(echo "$output" | grep -c -E '(installed|not found)')
    # At least 10 modules should be listed
    [ "$module_lines" -ge 10 ]
}

@test "all modules define module_status function" {
    local modules_dir="$PROJECT_ROOT/modules"
    for f in "$modules_dir"/*.sh; do
        run grep -q 'module_status()' "$f"
        if [ "$status" -ne 0 ]; then
            echo "$(basename "$f") is missing module_status()" >&2
            return 1
        fi
    done
}

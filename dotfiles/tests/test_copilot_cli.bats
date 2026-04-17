#!/usr/bin/env bats

# Tests for copilot-cli module (dotfiles/modules/copilot-cli.sh)

MODULES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../modules" && pwd)"
MODULE_FILE="$MODULES_DIR/copilot-cli.sh"

# ============================================================
# Metadata tests
# ============================================================

@test "copilot-cli: MODULE_ID is copilot-cli" {
    local id
    id=$(grep '^MODULE_ID=' "$MODULE_FILE" | head -1 | cut -d= -f2 | tr -d '"')
    [ "$id" = "copilot-cli" ]
}

@test "copilot-cli: MODULE_DEPS includes node" {
    local deps
    deps=$(grep '^MODULE_DEPS=' "$MODULE_FILE" | head -1 | cut -d= -f2 | tr -d '"')
    [[ "$deps" == *"node"* ]]
}

@test "copilot-cli: MODULE_ORDER is unique among all modules" {
    local copilot_order
    copilot_order=$(grep '^MODULE_ORDER=' "$MODULE_FILE" | head -1 | cut -d= -f2)

    for f in "$MODULES_DIR"/*.sh; do
        [ "$f" = "$MODULE_FILE" ] && continue
        local other_order
        other_order=$(grep '^MODULE_ORDER=' "$f" | head -1 | cut -d= -f2)
        if [ "$copilot_order" = "$other_order" ]; then
            echo "MODULE_ORDER=$copilot_order conflicts with $(basename "$f")" >&2
            return 1
        fi
    done
}

# ============================================================
# Function definition tests
# ============================================================

@test "copilot-cli: defines setup_copilot_cli function" {
    run grep -q '^setup_copilot_cli()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: defines module_status function" {
    run grep -q '^module_status()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: defines uninstall_copilot_cli function" {
    run grep -q '^uninstall_copilot_cli()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

# ============================================================
# Implementation correctness tests
# ============================================================

@test "copilot-cli: requires Node.js 22+" {
    run grep -q 'COPILOT_MOD_MIN_NODE_VERSION=22' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: uses ensure_node with min version" {
    run grep -q 'ensure_node "$COPILOT_MOD_MIN_NODE_VERSION"' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: installs @github/copilot via npm" {
    run grep -q '@github/copilot' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: uninstall uses npm uninstall -g" {
    run grep 'npm uninstall -g' "$MODULE_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *'$COPILOT_MOD_NPM_PACKAGE'* ]] || [[ "$output" == *'@github/copilot'* ]]
}

@test "copilot-cli: has idempotency check for copilot command" {
    run grep -q 'command -v copilot' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: supports UPGRADE flag" {
    run grep -q 'UPGRADE' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "copilot-cli: supports DRY_RUN flag" {
    run grep -q 'DRY_RUN' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}


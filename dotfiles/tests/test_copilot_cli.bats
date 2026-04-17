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

# ============================================================
# Dependency resolution integration test
# ============================================================

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=../lib/colors.sh
    source "$PROJECT_ROOT/lib/colors.sh"
    # shellcheck source=../lib/array.sh
    source "$PROJECT_ROOT/lib/array.sh"
    _setup_colors

    _define_resolve_module_deps
}

_define_resolve_module_deps() {
    resolve_module_deps() {
        local max_iterations=10
        local iteration=0
        local changed=1

        while ((changed)) && ((iteration < max_iterations)); do
            changed=0
            iteration=$((iteration + 1))
            local -a to_add=()

            for mod_id in "${selected_module_ids[@]}"; do
                local deps="${MODULE_DEPS_MAP[$mod_id]:-}"
                [[ -z "$deps" ]] && continue

                for dep in $deps; do
                    if ! array_contains "$dep" "${selected_module_ids[@]}"; then
                        if [[ -n "${MODULE_ID_SET[$dep]:-}" ]]; then
                            to_add+=("$dep")
                            changed=1
                        else
                            printf '  依存モジュールが見つかりません: %s (要求元: %s)\n' "$dep" "$mod_id" >&2
                        fi
                    fi
                done
            done

            for dep in "${to_add[@]}"; do
                if ! array_contains "$dep" "${selected_module_ids[@]}"; then
                    selected_module_ids+=("$dep")
                fi
            done
        done

        if ((${#selected_module_ids[@]} > 1)); then
            local -a sorted=()
            for entry in "${MODULES[@]}"; do
                local entry_id="${entry%%|*}"
                if array_contains "$entry_id" "${selected_module_ids[@]}"; then
                    sorted+=("$entry_id")
                fi
            done
            selected_module_ids=("${sorted[@]}")
        fi
    }
}

_setup_module_registry() {
    MODULES=()
    for entry in "$@"; do
        MODULES+=("$entry")
    done
}

@test "copilot-cli: dependency on node is resolved" {
    # Arrange: copilot-cli depends on node
    declare -A MODULE_DEPS_MAP=([copilot-cli]="node")
    declare -A MODULE_ID_SET=([node]=1 [copilot-cli]=1)
    _setup_module_registry "node|Node.js|desc|1" "copilot-cli|GitHub Copilot CLI|desc|0"
    selected_module_ids=(copilot-cli)

    # Act
    resolve_module_deps

    # Assert: node was auto-added
    array_contains "node" "${selected_module_ids[@]}"
    [ "${#selected_module_ids[@]}" -eq 2 ]
}

@test "copilot-cli: node comes before copilot-cli after dep resolution" {
    # Arrange
    declare -A MODULE_DEPS_MAP=([copilot-cli]="node")
    declare -A MODULE_ID_SET=([node]=1 [copilot-cli]=1)
    _setup_module_registry "node|Node.js|desc|1" "copilot-cli|GitHub Copilot CLI|desc|0"
    selected_module_ids=(copilot-cli)

    # Act
    resolve_module_deps

    # Assert: node is first
    [ "${selected_module_ids[0]}" = "node" ]
    [ "${selected_module_ids[1]}" = "copilot-cli" ]
}

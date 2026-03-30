#!/usr/bin/env bats

# Tests for ensure_node() and resolve_module_deps() from setup.sh
# These functions are extracted inline to avoid setup.sh side effects.

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=../lib/colors.sh
    source "$PROJECT_ROOT/lib/colors.sh"
    # shellcheck source=../lib/array.sh
    source "$PROJECT_ROOT/lib/array.sh"
    _setup_colors

    _define_ensure_node
    _define_resolve_module_deps
}

# Extract ensure_node from setup.sh without triggering side effects.
# NOTE: This is a verbatim copy of setup.sh ensure_node (lines ~263-298).
# If the production ensure_node changes, review and update this test version.
_define_ensure_node() {
    ensure_node() {
        local min_version="${1:-18}"

        if ! command -v node >/dev/null 2>&1; then
            msg_error "Node.js がインストールされていません。"
            printf '  nvm, fnm, volta 等で Node.js v%s 以上をインストールしてください。\n' "$min_version" >&2
            printf '  例: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash\n' >&2
            return 1
        fi

        local node_ver
        node_ver=$(node -v | sed 's/^v//' | cut -d. -f1)

        # Validate numeric values
        if [[ ! "$min_version" =~ ^[0-9]+$ ]]; then
            msg_error "ensure_node に不正な引数が渡されました: ${min_version}"
            return 1
        fi
        if [[ ! "$node_ver" =~ ^[0-9]+$ ]]; then
            msg_error "Node.js のバージョンを取得できませんでした。"
            return 1
        fi

        if ((node_ver < min_version)); then
            msg_error "Node.js v${min_version} 以上が必要です（現在: v${node_ver}）"
            printf '  Node.js をアップグレードしてください。\n' >&2
            return 1
        fi

        if ! command -v npm >/dev/null 2>&1; then
            msg_error "npm がインストールされていません。"
            printf '  Node.js に付属の npm が利用可能か確認してください。\n' >&2
            return 1
        fi

        return 0
    }
}

# Extract resolve_module_deps from setup.sh without triggering side effects.
# NOTE: This is a verbatim copy of setup.sh resolve_module_deps (lines ~512-563).
# If the production resolve_module_deps changes, review and update this test version.
_define_resolve_module_deps() {
    resolve_module_deps() {
        local -a added_deps=()
        local changed=1

        # Iterate until no more transitive dependencies are found
        while ((changed)); do
            changed=0
            for mod_id in "${selected_module_ids[@]}"; do
                local deps="${MODULE_DEPS_MAP[$mod_id]:-}"
                [[ -z "$deps" ]] && continue

                # MODULE_DEPS is a space-separated list
                read -ra _deps <<<"$deps"
                local dep
                for dep in "${_deps[@]}"; do
                    # Check if dep is already selected
                    if ! array_contains "$dep" "${selected_module_ids[@]}"; then
                        # O(1) existence check
                        if [[ -n "${MODULE_ID_SET[$dep]:-}" ]]; then
                            selected_module_ids+=("$dep")
                            added_deps+=("$dep")
                            changed=1
                        else
                            msg_warn "モジュール '${mod_id}' の依存先 '${dep}' が見つかりません。"
                        fi
                    fi
                done
            done
        done

        # Notify user of auto-added dependencies
        if ((${#added_deps[@]} > 0)); then
            printf '\n'
            color_print "$C_CYAN" "依存関係の自動解決:"
            for dep in "${added_deps[@]}"; do
                printf '  + %s (依存先として自動追加)\n' "$dep"
            done
            printf '\n'
        fi

        # Re-sort by MODULE_ORDER so dependencies are installed first
        if ((${#added_deps[@]} > 0)); then
            local -a sorted_ids=()
            local entry entry_id
            for entry in "${MODULES[@]}"; do
                entry_id="${entry%%|*}"
                if array_contains "$entry_id" "${selected_module_ids[@]}"; then
                    sorted_ids+=("$entry_id")
                fi
            done
            selected_module_ids=("${sorted_ids[@]}")
        fi
    }
}

# ============================================================
# ensure_node tests
# ============================================================

@test "ensure_node succeeds when node and npm are available" {
    # Skip if node or npm is not installed in the test environment
    command -v node >/dev/null 2>&1 || skip "node not installed"
    command -v npm >/dev/null 2>&1 || skip "npm not installed"

    run ensure_node
    [ "$status" -eq 0 ]
}

@test "ensure_node succeeds with explicit version below current" {
    command -v node >/dev/null 2>&1 || skip "node not installed"
    command -v npm >/dev/null 2>&1 || skip "npm not installed"

    # Require version 1 -- any installed node should satisfy this
    run ensure_node 1
    [ "$status" -eq 0 ]
}

@test "ensure_node fails when minimum version exceeds current" {
    command -v node >/dev/null 2>&1 || skip "node not installed"

    # Require version 999 -- no real node should satisfy this
    run ensure_node 999
    [ "$status" -eq 1 ]
    [[ "$output" == *"v999 以上が必要です"* ]]
}

@test "ensure_node rejects non-numeric min_version argument" {
    command -v node >/dev/null 2>&1 || skip "node not installed"

    run ensure_node "abc"
    [ "$status" -eq 1 ]
    [[ "$output" == *"不正な引数"* ]]
}

@test "ensure_node fails when node is not found" {
    # Stub node as a function that always fails
    node() { return 127; }
    export -f node
    # Override command -v to report node as missing
    command() {
        if [[ "$1" == "-v" && "$2" == "node" ]]; then
            return 1
        fi
        builtin command "$@"
    }

    run ensure_node
    [ "$status" -eq 1 ]
    [[ "$output" == *"Node.js がインストールされていません"* ]]
}

@test "ensure_node fails when npm is not found" {
    command -v node >/dev/null 2>&1 || skip "node not installed"

    # Create a temporary directory with a fake node but no npm
    local fake_bin
    fake_bin="$(mktemp -d)"
    local real_node real_sed real_cut
    real_node="$(command -v node)"
    real_sed="$(command -v sed)"
    real_cut="$(command -v cut)"
    ln -s "$real_node" "${fake_bin}/node"
    ln -s "$real_sed" "${fake_bin}/sed"
    ln -s "$real_cut" "${fake_bin}/cut"
    # Do NOT link npm

    local saved_path="$PATH"
    PATH="$fake_bin"
    run ensure_node
    PATH="$saved_path"

    [ "$status" -eq 1 ]
    [[ "$output" == *"npm がインストールされていません"* ]]

    rm -rf "$fake_bin"
}

# ============================================================
# resolve_module_deps tests
# ============================================================

# Helper: set up module registry for dependency tests.
# MODULES entries use the production format: "id|name|desc|default"
# (ORDER prefix is stripped by load_modules; entries are pre-sorted).
_setup_module_registry() {
    MODULES=()
    for entry in "$@"; do
        MODULES+=("$entry")
    done
}

@test "resolve_module_deps: no deps keeps selection unchanged" {
    # Arrange
    declare -A MODULE_DEPS_MAP=()
    declare -A MODULE_ID_SET=([zsh]=1 [git]=1)
    _setup_module_registry "zsh|Zsh|desc|1" "git|Git|desc|1"
    selected_module_ids=(zsh git)

    # Act (use run -- no variable mutation to check)
    run resolve_module_deps

    # Assert: no changes, no output
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "resolve_module_deps: direct dependency is auto-added" {
    # Arrange: claude-code depends on node
    declare -A MODULE_DEPS_MAP=([claude-code]="node")
    declare -A MODULE_ID_SET=([node]=1 [claude-code]=1)
    _setup_module_registry "node|Node.js|desc|1" "claude-code|Claude Code|desc|1"
    selected_module_ids=(claude-code)

    # Act (call directly so selected_module_ids is modified in this shell)
    resolve_module_deps

    # Assert: node was added
    array_contains "node" "${selected_module_ids[@]}"
}

@test "resolve_module_deps: direct dep is sorted by MODULE_ORDER" {
    # Arrange: claude-code depends on node; node appears first in MODULES
    declare -A MODULE_DEPS_MAP=([claude-code]="node")
    declare -A MODULE_ID_SET=([node]=1 [claude-code]=1)
    _setup_module_registry "node|Node.js|desc|1" "claude-code|Claude Code|desc|1"
    selected_module_ids=(claude-code)

    # Act
    resolve_module_deps

    # Assert: node comes before claude-code after re-sort
    [ "${selected_module_ids[0]}" = "node" ]
    [ "${selected_module_ids[1]}" = "claude-code" ]
}

@test "resolve_module_deps: transitive dependencies are resolved" {
    # Arrange: A depends on B, B depends on C
    declare -A MODULE_DEPS_MAP=([modA]="modB" [modB]="modC")
    declare -A MODULE_ID_SET=([modA]=1 [modB]=1 [modC]=1)
    _setup_module_registry "modC|Module C|desc|1" "modB|Module B|desc|1" "modA|Module A|desc|1"
    selected_module_ids=(modA)

    # Act
    resolve_module_deps

    # Assert: both modB and modC were added
    array_contains "modB" "${selected_module_ids[@]}"
    array_contains "modC" "${selected_module_ids[@]}"
}

@test "resolve_module_deps: transitive deps sorted by MODULE_ORDER" {
    # Arrange: A depends on B, B depends on C
    # MODULES order: C first, then B, then A (simulating ascending ORDER)
    declare -A MODULE_DEPS_MAP=([modA]="modB" [modB]="modC")
    declare -A MODULE_ID_SET=([modA]=1 [modB]=1 [modC]=1)
    _setup_module_registry "modC|Module C|desc|1" "modB|Module B|desc|1" "modA|Module A|desc|1"
    selected_module_ids=(modA)

    # Act
    resolve_module_deps

    # Assert: order is modC, modB, modA (follows MODULES order)
    [ "${selected_module_ids[0]}" = "modC" ]
    [ "${selected_module_ids[1]}" = "modB" ]
    [ "${selected_module_ids[2]}" = "modA" ]
}

@test "resolve_module_deps: already selected dep is not duplicated" {
    # Arrange: claude-code depends on node, but node is already selected
    declare -A MODULE_DEPS_MAP=([claude-code]="node")
    declare -A MODULE_ID_SET=([node]=1 [claude-code]=1)
    _setup_module_registry "node|Node.js|desc|1" "claude-code|Claude Code|desc|1"
    selected_module_ids=(node claude-code)

    # Act
    resolve_module_deps

    # Assert: no duplicate -- still exactly 2 entries
    [ "${#selected_module_ids[@]}" -eq 2 ]
}

@test "resolve_module_deps: multiple deps of one module are all added" {
    # Arrange: modA depends on both modB and modC
    declare -A MODULE_DEPS_MAP=([modA]="modB modC")
    declare -A MODULE_ID_SET=([modA]=1 [modB]=1 [modC]=1)
    _setup_module_registry "modB|Module B|desc|1" "modC|Module C|desc|1" "modA|Module A|desc|1"
    selected_module_ids=(modA)

    # Act
    resolve_module_deps

    # Assert: both added
    array_contains "modB" "${selected_module_ids[@]}"
    array_contains "modC" "${selected_module_ids[@]}"
    [ "${#selected_module_ids[@]}" -eq 3 ]
}

@test "resolve_module_deps: unknown dep warns but does not fail" {
    # Arrange: modA depends on nonexistent, which is not in MODULE_ID_SET
    declare -A MODULE_DEPS_MAP=([modA]="nonexistent")
    declare -A MODULE_ID_SET=([modA]=1)
    _setup_module_registry "modA|Module A|desc|1"
    selected_module_ids=(modA)

    # Act (use run to capture warning output)
    run resolve_module_deps

    # Assert: warning shown, no crash
    [ "$status" -eq 0 ]
    [[ "$output" == *"見つかりません"* ]]
}

@test "resolve_module_deps: diamond dependency resolved without duplicates" {
    # Arrange: modA -> modB, modA -> modC, modB -> modD, modC -> modD
    declare -A MODULE_DEPS_MAP=([modA]="modB modC" [modB]="modD" [modC]="modD")
    declare -A MODULE_ID_SET=([modA]=1 [modB]=1 [modC]=1 [modD]=1)
    _setup_module_registry "modD|Module D|desc|1" "modB|Module B|desc|1" "modC|Module C|desc|1" "modA|Module A|desc|1"
    selected_module_ids=(modA)

    # Act
    resolve_module_deps

    # Assert: all 4 modules present, no duplicates
    [ "${#selected_module_ids[@]}" -eq 4 ]
    array_contains "modD" "${selected_module_ids[@]}"
    # modD should come first (lowest in MODULES order)
    [ "${selected_module_ids[0]}" = "modD" ]
}

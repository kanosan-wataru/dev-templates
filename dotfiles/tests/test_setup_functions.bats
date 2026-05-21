#!/usr/bin/env bats

# Tests for ensure_node() and resolve_module_deps()
# 本番実装は lib/setup_helpers.sh に分離されているのでそれを直接 source
# (以前は verbatim copy を保持していたが silent drift の原因になっていた)。

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=../lib/colors.sh
    source "$PROJECT_ROOT/lib/colors.sh"
    # shellcheck source=../lib/array.sh
    source "$PROJECT_ROOT/lib/array.sh"
    _setup_colors

    # 本番実装をそのまま読み込む (drift 防止)
    # shellcheck source=../lib/setup_helpers.sh
    source "$PROJECT_ROOT/lib/setup_helpers.sh"
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

@test "resolve_module_deps: copilot-cli dependency on node is resolved" {
    # Arrange: copilot-cli depends on node
    declare -A MODULE_DEPS_MAP=([copilot-cli]="node")
    declare -A MODULE_ID_SET=([node]=1 [copilot-cli]=1)
    _setup_module_registry "node|Node.js|desc|1" "copilot-cli|GitHub Copilot CLI|desc|0"
    selected_module_ids=(copilot-cli)

    # Act
    resolve_module_deps

    # Assert: node was auto-added and comes before copilot-cli
    array_contains "node" "${selected_module_ids[@]}"
    [ "${#selected_module_ids[@]}" -eq 2 ]
    [ "${selected_module_ids[0]}" = "node" ]
    [ "${selected_module_ids[1]}" = "copilot-cli" ]
}

@test "resolve_module_deps: max_iter guard fires when loop fails to converge" {
    # array_contains を常に false にすると同じ dep が無限に追加され続け、
    # max_iter ガードに到達して exit 1 する。
    # 通常運用では trigger され得ないが、防御的上限の動作を確認するため
    # 異常系をシミュレートする。
    array_contains() { return 1; }

    declare -A MODULE_DEPS_MAP=([modA]="modB")
    declare -A MODULE_ID_SET=([modA]=1 [modB]=1)
    _setup_module_registry "modA|A|desc|1" "modB|B|desc|1"
    declare -a selected_module_ids=(modA)

    run resolve_module_deps
    [ "$status" -ne 0 ]
    [[ "$output" == *"循環依存または異常なメタデータ"* ]]
}

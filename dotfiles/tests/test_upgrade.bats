#!/usr/bin/env bats

# --upgrade option behavior tests

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SETUP_SH="$PROJECT_ROOT/setup.sh"
}

# -- Behavior-based tests (replaces grep-based tests) --

@test "--upgrade flag is accepted without error" {
    # NOTE: --all はバージョン要件を満たさないモジュール（copilot-cli: Node 22+ 等）で
    # 失敗しうるため、環境非依存の git モジュールで検証する
    run bash "$SETUP_SH" --upgrade --dry-run --select git
    [ "$status" -eq 0 ]
}

@test "--upgrade --dry-run completes successfully" {
    # NOTE: CI ではツールが未インストールのため「アップグレード」メッセージが
    # 出ない場合がある（新規インストール扱い）。DRY-RUN 完走を検証する。
    run bash "$SETUP_SH" --upgrade --dry-run --select git
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"dry-run"* ]]
}

@test "without --upgrade, no upgrade messages appear" {
    # NOTE: --all は環境依存で失敗しうるため --select で検証する
    run bash "$SETUP_SH" --dry-run --select git
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

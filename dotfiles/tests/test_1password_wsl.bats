#!/usr/bin/env bats

# WSL 1Password SSH エージェントブリッジ (npiperelay + socat) のテスト
# 対象: modules/1password.sh の npiperelay ヘルパー群と .shell/1password.sh の構文

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=../lib/colors.sh
    source "$PROJECT_ROOT/lib/colors.sh"
    # shellcheck source=../lib/array.sh
    source "$PROJECT_ROOT/lib/array.sh"
    _setup_colors
    # shellcheck source=../lib/setup_helpers.sh
    source "$PROJECT_ROOT/lib/setup_helpers.sh"
    # shellcheck source=../modules/1password.sh
    source "$PROJECT_ROOT/modules/1password.sh"

    # run_cmd は本番では setup.sh が定義する。テストでは未ロードのため最小スタブを置き、
    # 依存不足環境でも副作用 (apt 実行) なく動くようにする。
    run_cmd() {
        if ((${DRY_RUN:-0})); then return 0; fi
        "$@"
    }
}

@test "npiperelay version は vX.Y.Z 形式で固定されている" {
    [[ "$OP_MOD_NPIPERELAY_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "amd64 の SHA256 定数は 64 桁の 16 進数" {
    [[ "$OP_MOD_NPIPERELAY_SHA256_AMD64" =~ ^[0-9a-f]{64}$ ]]
}

@test "x86_64 では amd64 zip アセット名を返す" {
    uname() { echo x86_64; }
    run _1password_npiperelay_asset
    [ "$status" -eq 0 ]
    [ "$output" = "npiperelay_windows_amd64.zip" ]
}

@test "x86_64 では amd64 の SHA256 を返す" {
    uname() { echo x86_64; }
    run _1password_npiperelay_sha256
    [ "$output" = "$OP_MOD_NPIPERELAY_SHA256_AMD64" ]
}

@test "未対応アーキでは空のアセット名と空の SHA を返す" {
    uname() { echo riscv64; }
    run _1password_npiperelay_asset
    [ -z "$output" ]
    run _1password_npiperelay_sha256
    [ -z "$output" ]
}

@test "URL はバージョン固定の GitHub Releases を指す" {
    run _1password_npiperelay_url "npiperelay_windows_amd64.zip"
    [ "$output" = "https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip" ]
}

@test "DRY_RUN では npiperelay をダウンロード・配置しない" {
    # 隔離した一時ディレクトリを使い実ファイルを汚さない
    local tmp_home
    tmp_home="$(mktemp -d)"
    OP_MOD_NPIPERELAY_BIN_DIR="$tmp_home/.local/bin"
    OP_MOD_NPIPERELAY_BIN_PATH="$OP_MOD_NPIPERELAY_BIN_DIR/npiperelay.exe"
    uname() { echo x86_64; }
    DRY_RUN=1
    UPGRADE=0

    run _1password_setup_npiperelay_wsl
    [ "$status" -eq 0 ]
    [ ! -e "$OP_MOD_NPIPERELAY_BIN_PATH" ]

    rm -rf "$tmp_home"
}

@test ".shell/1password.sh は bash 構文として妥当" {
    run bash -n "$PROJECT_ROOT/.shell/1password.sh"
    [ "$status" -eq 0 ]
}

@test ".shell/1password.sh は zsh 構文として妥当" {
    command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
    run zsh -n "$PROJECT_ROOT/.shell/1password.sh"
    [ "$status" -eq 0 ]
}

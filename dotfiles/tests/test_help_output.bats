#!/usr/bin/env bats

# --help 出力の構造とコンテンツ検証
# UX 改善: 位置引数の使い方、--all 排他注意、デフォルト ON マーク

SETUP_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/setup.sh"

@test "help: shows positional args usage example" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"例: zsh git docker"* ]]
}

@test "help: shows --all + module exclusion notice" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"注意:"* ]]
    [[ "$output" == *"--all とモジュール指定"* ]]
}

@test "help: shows default-ON marker legend" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"* = デフォルト ON"* ]]
}

@test "help: marks default-ON modules with asterisk" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    # zsh は MODULE_DEFAULT=1 なので行頭 "  * zsh" 形式で出力されるはず
    # 行頭アンカーで grep し、description などに偶然 "* zsh" が混入しても
    # 誤検知しないようにする
    echo "$output" | grep -qE '^  \* zsh\b'
}

@test "help: marks non-default modules without asterisk" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    # docker は MODULE_DEFAULT=0。フォーマット '  %s %-14s' で mark=" " なので
    # 行頭 4 スペース + docker (= 2 leading + 1 mark space + 1 separator)
    # まず docker 行が一覧に存在することを保証 (行が消えただけで pass しないように)
    echo "$output" | grep -qE '^    docker\b'
    # 「* docker」形式でリストアップされていないこと
    ! echo "$output" | grep -qE '^  \* docker\b'
}

@test "help: example uses positional args (not deprecated form)" {
    run bash "$SETUP_SH" --help
    [ "$status" -eq 0 ]
    # 旧 example "bash setup.sh zsh claude-code" は "zsh git docker" に置換済み
    [[ "$output" == *"zsh git docker"* ]]
}

# ============================================================
# tput 不在時の確認プロンプト (regression / source-level)
# 動的呼出は </dev/tty を要するため、ここではコードパスの存在を確認する
# ============================================================

@test "tput-fallback: script defines [d] default / [a] all / [q] quit choices" {
    grep -q '\[d\] デフォルト' "$SETUP_SH"
    grep -q '\[a\] 全モジュール' "$SETUP_SH"
    grep -q '\[q\] 中止' "$SETUP_SH"
}

@test "tput-fallback: prompt reads from /dev/tty (works under stdin pipe)" {
    # tput 不在ブランチで stdin が pipe でも /dev/tty から読むこと
    grep -q 'read -r answer </dev/tty' "$SETUP_SH"
}

@test "tput-fallback: empty input (just Enter) is treated as quit" {
    # [qQ] | "" でマッチして exit 0 する設計を保証
    grep -qE '\[qQ\][^[:alnum:]].*""' "$SETUP_SH"
}

@test "tput-fallback: invalid input loops back to prompt" {
    # while true ... case ... *) re-prompt の構造を確認
    grep -q 'd / a / q のいずれか' "$SETUP_SH"
}

@test "tput-fallback: prompt shows module counts for visibility" {
    # MEDIUM 指摘: [a] は破壊的な選択なので、何個入るかは見せたい
    grep -q '_fallback_default_count' "$SETUP_SH"
    grep -q '_fallback_total_count' "$SETUP_SH"
    grep -qF '[d] デフォルトのモジュールのみ (%d 個)' "$SETUP_SH"
    grep -qF '[a] 全モジュール (%d 個、--all 相当)' "$SETUP_SH"
}

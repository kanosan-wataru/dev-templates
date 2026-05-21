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

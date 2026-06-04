#!/usr/bin/env bats

# Tests for the HISTFILE self-heal guard in .zshrc
#
# HISTFILE 自体が（空の）ディレクトリ化していると zsh は履歴を書けず
# 「failed to write history file ...: is a directory」エラーになる。
# Docker 等のバインドマウントが未存在パスをホスト側に空ディレクトリとして
# 作る既知の挙動が典型原因。.zshrc の自己修復ガードが空ディレクトリのみを
# 安全に除去し、履歴ファイルとして書けるようになることを検証する。
#
# NOTE: 逐語コピーではなく .zshrc から該当ブロックを抽出して zsh 上で実行する
#       （他のテストと同様に同期ずれを避ける）。zsh 必須。

setup() {
    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh が見つからないためスキップ"
    fi
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    ZSHRC="$PROJECT_ROOT/.zshrc"
    TEST_HOME="$(mktemp -d)"

    # .zshrc から HISTFILE 設定ブロック（HISTFILE= 行〜 export HISTSIZE= 直前）を抽出。
    # 親ディレクトリ作成・空ディレクトリ除去・フォールバック切替を含む。
    HISTFILE_BLOCK="$(awk '/^HISTFILE=/{f=1} /^export HISTSIZE=/{exit} f{print}' "$ZSHRC")"
    [ -n "$HISTFILE_BLOCK" ] || {
        echo "HISTFILE ブロックを .zshrc から抽出できませんでした" >&2
        return 1
    }
}

teardown() {
    if [ -n "${TEST_HOME:-}" ]; then
        chmod -R u+w "$TEST_HOME" 2>/dev/null || true
        rm -rf "$TEST_HOME"
    fi
}

# 抽出した HISTFILE ブロックを zsh 上で実行するヘルパ。
run_histfile_block() {
    run env HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -f -c "$HISTFILE_BLOCK; print -r -- \"\$HISTFILE\""
}

@test "removes empty directory that occupies the HISTFILE path" {
    mkdir -p "$TEST_HOME/.zsh/.zsh_history"
    run_histfile_block
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_HOME/.zsh/.zsh_history" ]
}

@test "zsh can write the history file after self-heal" {
    mkdir -p "$TEST_HOME/.zsh/.zsh_history"
    # 自己修復後に HISTFILE パスへファイルとして書き込めること（= zsh が履歴保存時に
    # 「is a directory」エラーを出さないこと）を、実際の書き込みで検証する。
    run env HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -f -c \
        "$HISTFILE_BLOCK"$'\n'"print -r -- ': 0:0;echo self-heal-test' >| \"\$HISTFILE\""
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.zsh/.zsh_history" ]
    grep -q "self-heal-test" "$TEST_HOME/.zsh/.zsh_history"
}

@test "without self-heal, writing to a directory HISTFILE fails (regression guard)" {
    # 自己修復行が無い場合は zsh が「is a directory」で失敗することを確認し、
    # ガードが本当に問題を解消しているという因果を担保する。
    mkdir -p "$TEST_HOME/.zsh/.zsh_history"
    run env HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -f -c \
        'HISTFILE="$HOME/.zsh/.zsh_history"; print -r -- "x" >| "$HISTFILE"'
    [ "$status" -ne 0 ]
    [[ "$output" == *"is a directory"* ]]
}

@test "preserves an existing regular HISTFILE" {
    command mkdir -p "$TEST_HOME/.zsh"
    printf ': 0:0;echo existing-entry\n' >"$TEST_HOME/.zsh/.zsh_history"
    run_histfile_block
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.zsh/.zsh_history" ]
    grep -q "existing-entry" "$TEST_HOME/.zsh/.zsh_history"
}

@test "leaves a non-empty directory intact (rmdir does not destroy data)" {
    # 空でないディレクトリは rmdir が失敗するため、実データは壊れない。
    mkdir -p "$TEST_HOME/.zsh/.zsh_history"
    echo "important" >"$TEST_HOME/.zsh/.zsh_history/keep.txt"
    run_histfile_block
    [ "$status" -eq 0 ]
    [ -d "$TEST_HOME/.zsh/.zsh_history" ]
    [ -f "$TEST_HOME/.zsh/.zsh_history/keep.txt" ]
}

@test "falls back to .local file when HISTFILE is a non-removable directory" {
    # rmdir 不可なディレクトリ（非空。アクティブなバインドマウントの代理）でも、
    # サイレントに失敗せずフォールバック先へ切り替え、警告を出し、書き込めること。
    mkdir -p "$TEST_HOME/.zsh/.zsh_history"
    echo "mounted" >"$TEST_HOME/.zsh/.zsh_history/keep.txt"
    run env HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -f -c \
        "$HISTFILE_BLOCK"$'\n'"print -r -- ': 0:0;echo fallback-test' >| \"\$HISTFILE\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"フォールバック"* ]]
    # 元ディレクトリとその中身は保持されている。
    [ -d "$TEST_HOME/.zsh/.zsh_history" ]
    [ -f "$TEST_HOME/.zsh/.zsh_history/keep.txt" ]
    # 書き込みはフォールバックファイルに行われている。
    [ -f "$TEST_HOME/.zsh/.zsh_history.local" ]
    grep -q "fallback-test" "$TEST_HOME/.zsh/.zsh_history.local"
}

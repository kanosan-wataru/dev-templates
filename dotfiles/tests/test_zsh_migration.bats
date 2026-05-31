#!/usr/bin/env bats

# Tests for _zsh_cleanup_legacy_dev_templates() from modules/zsh.sh
#
# 旧 source 分離方式（完全な .zshrc を .zshrc.d/dev-templates.zsh として配置し、.zshrc に
# source 行を追記する）から直接配置方式へ移行した後、孤立した旧ファイルを退避するロジック。
# .zshrc 本体の source 行除去は install_config の上書き配置が担うため、本関数は .zshrc を
# 編集しない。直接配置がスキップされ .zshrc がまだ source している場合は何もしない。
#
# NOTE: 逐語コピーではなく modules/zsh.sh を直接 source する（副作用が無く同期ずれを避ける）。

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT_DIR="$PROJECT_ROOT"
    TEST_HOME="$(mktemp -d)"

    # 依存スタブ（出力を抑制し関数ロジックのみ検証）
    msg_info() { :; }
    msg_warn() { :; }
    msg_dry_run() { :; }
    run_cmd() { "$@"; }
    DRY_RUN=0
    BACKUP_SUFFIX=".bak.test"

    # shellcheck source=../modules/zsh.sh disable=SC1091
    source "$PROJECT_ROOT/modules/zsh.sh"
    # source 時に実環境値が入るためテスト用 HOME に差し替える
    ZSH_MOD_BASE_DIR="$TEST_HOME"
    mkdir -p "$TEST_HOME/.zshrc.d"
}

teardown() {
    if [ -n "${TEST_HOME:-}" ]; then
        chmod -R u+w "$TEST_HOME" 2>/dev/null || true
        rm -rf "$TEST_HOME"
    fi
}

@test "retires orphaned dev-templates.zsh when .zshrc does not source it" {
    {
        printf '%s\n' '# managed zshrc'
        printf '%s\n' 'export FOO=1'
    } >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    # 孤児は退避され、バックアップ(.bak.test)が残る
    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
    [ -f "$TEST_HOME/.zshrc.d/dev-templates.zsh.bak.test" ]
    # .zshrc 本体は一切触らない
    run grep -c 'FOO=1' "$TEST_HOME/.zshrc"
    [ "$output" -eq 1 ]
}

@test "does NOT retire dev-templates.zsh while .zshrc still sources it" {
    {
        printf '%s\n' '# user zshrc'
        printf '%s\n' "source \"$TEST_HOME/.zshrc.d/dev-templates.zsh\""
    } >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh.bak.test" ]
}

@test "does NOT retire when .zshrc sources via dot (.) form" {
    # POSIX ドットコマンド形式の source も検出する（壊さない）
    {
        printf '%s\n' '# user zshrc'
        printf '%s\n' ". \"$TEST_HOME/.zshrc.d/dev-templates.zsh\""
    } >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
}

@test "is a no-op when no orphan exists" {
    printf '# clean zshrc\n' >"$TEST_HOME/.zshrc"

    run _zsh_cleanup_legacy_dev_templates
    [ "$status" -eq 0 ]
}

@test "is idempotent (second run is a no-op)" {
    printf '# managed zshrc\n' >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates
    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
    run _zsh_cleanup_legacy_dev_templates
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
}

@test "retires orphan when .zshrc only mentions dev-templates.zsh in a comment" {
    # コメント言及のみ（source 行ではない）+ 孤児あり → コメントを誤検出せず退避する
    {
        printf '%s\n' '# NOTE: dev-templates.zsh は除去済み'
        printf '%s\n' 'export KEEP=1'
    } >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
    [ -f "$TEST_HOME/.zshrc.d/dev-templates.zsh.bak.test" ]
    run grep -c 'KEEP' "$TEST_HOME/.zshrc"
    [ "$output" -eq 1 ]
}

@test "skips mv and leaves file in place when DRY_RUN=1" {
    DRY_RUN=1
    printf '# managed zshrc\n' >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh.bak.test" ]
}

@test "warns and leaves file when mv fails" {
    # 退避先の親が存在しないパスにして mv を確実に失敗させる（root 非依存）
    BACKUP_SUFFIX="/no/such/dir/bak"
    printf '# managed zshrc\n' >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"
    local warned=0
    msg_warn() { warned=1; }

    _zsh_cleanup_legacy_dev_templates

    # mv が失敗したので警告が出て、元ファイルは残る
    [ "$warned" -eq 1 ]
    [ -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
}

@test "retires orphan even when .zshrc does not exist" {
    # .zshrc 未作成（直接配置がまだ走っていない状態を想定）でも安全に退避
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
}

@test "does NOT retire a symlinked dev-templates.zsh" {
    # シンボリックリンクは意図的な配置の可能性があるため触らない
    printf '# managed zshrc\n' >"$TEST_HOME/.zshrc"
    printf '# real target\n' >"$TEST_HOME/real-template.zsh"
    ln -s "$TEST_HOME/real-template.zsh" "$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ -L "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
}

@test "retires orphan when .zshrc sources a differently-named -dev-templates.zsh" {
    # 別名ファイル(my-dev-templates.zsh)への source は本物の source とは見なさず退避する
    {
        printf '%s\n' '# user zshrc'
        printf '%s\n' 'source "/some/path/my-dev-templates.zsh"'
    } >"$TEST_HOME/.zshrc"
    printf '# old template\n' >"$TEST_HOME/.zshrc.d/dev-templates.zsh"

    _zsh_cleanup_legacy_dev_templates

    [ ! -f "$TEST_HOME/.zshrc.d/dev-templates.zsh" ]
}

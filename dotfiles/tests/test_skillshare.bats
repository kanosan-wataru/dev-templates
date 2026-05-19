#!/usr/bin/env bats

# Tests for skillshare module (dotfiles/modules/skillshare.sh) and shared
# helpers (dotfiles/lib/skillshare.sh).

DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MODULES_DIR="$DOTFILES_DIR/modules"
LIB_DIR="$DOTFILES_DIR/lib"
MODULE_FILE="$MODULES_DIR/skillshare.sh"
LIB_FILE="$LIB_DIR/skillshare.sh"
MODERN_CLI_FILE="$MODULES_DIR/modern-cli.sh"
SETUP_FILE="$DOTFILES_DIR/setup.sh"

# ============================================================
# Metadata tests
# ============================================================

@test "skillshare: MODULE_ID is skillshare" {
    local id
    id=$(grep '^MODULE_ID=' "$MODULE_FILE" | head -1 | cut -d= -f2 | tr -d '"')
    [ "$id" = "skillshare" ]
}

@test "skillshare: MODULE_DEFAULT is 1 (enabled by default)" {
    local default
    default=$(grep '^MODULE_DEFAULT=' "$MODULE_FILE" | head -1 | cut -d= -f2)
    [ "$default" = "1" ]
}

@test "skillshare: MODULE_ORDER is 40 (after AI CLI modules)" {
    local order
    order=$(grep '^MODULE_ORDER=' "$MODULE_FILE" | head -1 | cut -d= -f2)
    [ "$order" = "40" ]
}

@test "skillshare: MODULE_ORDER runs after every AI CLI module" {
    local order
    order=$(grep '^MODULE_ORDER=' "$MODULE_FILE" | head -1 | cut -d= -f2)
    # AI CLI モジュール: claude-code=20, gemini-cli=30, codex-cli=31,
    # copilot-cli=32, opencode=33。skillshare はそれら全てより後に走る。
    for ai_module in claude-code.sh gemini-cli.sh codex-cli.sh copilot-cli.sh opencode.sh; do
        local ai_order
        ai_order=$(grep '^MODULE_ORDER=' "$MODULES_DIR/$ai_module" | head -1 | cut -d= -f2)
        if [ "$order" -le "$ai_order" ]; then
            echo "skillshare ORDER=$order must be > $ai_module ORDER=$ai_order" >&2
            return 1
        fi
    done
}

@test "skillshare: has no MODULE_DEPS (detection-based)" {
    # MODULE_DEPS が空文字 (検出ベースなので静的依存は持たない)
    local deps
    deps=$(grep '^MODULE_DEPS=' "$MODULE_FILE" | head -1 | cut -d= -f2 | tr -d '"')
    [ -z "$deps" ]
}

# ============================================================
# Function definition tests (module)
# ============================================================

@test "skillshare: defines setup_skillshare function" {
    run grep -q '^setup_skillshare()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: defines module_status function" {
    run grep -q '^module_status()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: defines uninstall_skillshare function" {
    run grep -q '^uninstall_skillshare()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: defines _skillshare_mod_any_ai_cli_present detector" {
    run grep -q '^_skillshare_mod_any_ai_cli_present()' "$MODULE_FILE"
    [ "$status" -eq 0 ]
}

# ============================================================
# Function definition tests (lib)
# ============================================================

@test "lib/skillshare.sh: defines skillshare_install_cli" {
    run grep -q '^skillshare_install_cli()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "lib/skillshare.sh: defines skillshare_verify_sha256" {
    run grep -q '^skillshare_verify_sha256()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "lib/skillshare.sh: defines skillshare_render_config" {
    run grep -q '^skillshare_render_config()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "lib/skillshare.sh: defines skillshare_link_source" {
    run grep -q '^skillshare_link_source()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "lib/skillshare.sh: defines skillshare_register_targets" {
    run grep -q '^skillshare_register_targets()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "lib/skillshare.sh: defines skillshare_run_sync" {
    run grep -q '^skillshare_run_sync()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "lib/skillshare.sh: defines skillshare_convert_codex_agents" {
    run grep -q '^skillshare_convert_codex_agents()' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

# ============================================================
# Implementation correctness tests
# ============================================================

@test "skillshare: install version is tag-pinned (not main)" {
    # main ブランチ pin だと供給元が後から書き換わる可能性があるため、
    # 必ずタグ pin であることをチェックする (v0.x.y or v1.x.y 形式)
    run grep -E '^SKILLSHARE_VERSION=.*v[0-9]+\.[0-9]+\.[0-9]+' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: supports opt-in SHA256 verification" {
    run grep -q 'SKILLSHARE_INSTALLER_SHA256' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: uses sync --all --force flags" {
    run grep -q 'sync --all --force' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: excludes claude from sync targets (claude is source of truth)" {
    # register_targets が gemini/codex/opencode のみで claude を含まないこと
    run awk '/^skillshare_register_targets\(\)/{flag=1;next} /^\}/{if(flag){exit}} flag' "$LIB_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"gemini"* ]]
    [[ "$output" == *"codex"* ]]
    [[ "$output" == *"opencode"* ]]
    [[ "$output" != *'"claude|'* ]]
}

@test "skillshare: supports DRY_RUN flag" {
    run grep -q 'DRY_RUN' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

@test "skillshare: supports UPGRADE flag" {
    run grep -q 'UPGRADE' "$LIB_FILE"
    [ "$status" -eq 0 ]
}

# ============================================================
# Integration: setup.sh must source lib/skillshare.sh
# ============================================================

@test "setup.sh sources lib/skillshare.sh" {
    run grep -q 'source "${SCRIPT_DIR}/lib/skillshare.sh"' "$SETUP_FILE"
    [ "$status" -eq 0 ]
}

# ============================================================
# Regression: modern-cli.sh must NOT contain skillshare logic
# ============================================================

@test "modern-cli: no skillshare-related variables remain (regression guard)" {
    run grep -E 'MCLI_MOD_SKILLSHARE|_mcli_install_skillshare|_mcli_setup_skillshare|_mcli_skillshare_' "$MODERN_CLI_FILE"
    # grep が何も見つけなかった (status != 0) ことを期待
    [ "$status" -ne 0 ]
}

@test "modern-cli: MODULE_DESC no longer mentions skillshare" {
    local desc
    desc=$(grep '^MODULE_DESC=' "$MODERN_CLI_FILE" | head -1)
    [[ "$desc" != *"skillshare"* ]]
}

# ============================================================
# Behavior: _skillshare_mod_any_ai_cli_present
# AI CLI 検出ロジックの動作確認 (HOME を mock した上で実行)
# ============================================================

setup_detector() {
    # 一時的な HOME を作って各 AI CLI の有無を制御する
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # MODULE_ORDER 等の load_modules 副作用を回避するため変数だけリセットして source
    MODULE_ID="" MODULE_NAME="" MODULE_DESC="" MODULE_DEFAULT=0 MODULE_ORDER=50 MODULE_DEPS=""
    SCRIPT_DIR="$DOTFILES_DIR"
    # shellcheck disable=SC1090
    source "$MODULE_FILE"
}

@test "_skillshare_mod_any_ai_cli_present: returns 1 when no AI CLI is present" {
    setup_detector
    run _skillshare_mod_any_ai_cli_present
    [ "$status" -eq 1 ]
}

@test "_skillshare_mod_any_ai_cli_present: returns 0 when ~/.claude exists" {
    setup_detector
    mkdir -p "$HOME/.claude"
    run _skillshare_mod_any_ai_cli_present
    [ "$status" -eq 0 ]
}

@test "_skillshare_mod_any_ai_cli_present: returns 0 when ~/.codex exists (codex-only user)" {
    setup_detector
    mkdir -p "$HOME/.codex"
    run _skillshare_mod_any_ai_cli_present
    [ "$status" -eq 0 ]
}

@test "_skillshare_mod_any_ai_cli_present: returns 0 when ~/.gemini exists" {
    setup_detector
    mkdir -p "$HOME/.gemini"
    run _skillshare_mod_any_ai_cli_present
    [ "$status" -eq 0 ]
}

@test "_skillshare_mod_any_ai_cli_present: returns 0 when ~/.config/opencode exists" {
    setup_detector
    mkdir -p "$HOME/.config/opencode"
    run _skillshare_mod_any_ai_cli_present
    [ "$status" -eq 0 ]
}

# ============================================================
# Behavior: skillshare_verify_sha256
# msg_* 関数はテストでは no-op で十分なのでスタブする
# ============================================================

setup_sha256_test() {
    # msg_* スタブ
    msg_error() { :; }
    msg_success() { :; }
    # 一時的な SCRIPT_DIR を設定 (lib のロードに必要)
    SCRIPT_DIR="$DOTFILES_DIR"
    # shellcheck disable=SC1090
    source "$LIB_FILE"
}

@test "skillshare_verify_sha256: returns 0 on matching SHA256" {
    setup_sha256_test
    local file="$BATS_TEST_TMPDIR/sample.txt"
    printf 'hello' >"$file"
    # "hello" の SHA256: 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
    local expected="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    run skillshare_verify_sha256 "$file" "$expected"
    [ "$status" -eq 0 ]
}

@test "skillshare_verify_sha256: returns non-zero on mismatched SHA256" {
    setup_sha256_test
    local file="$BATS_TEST_TMPDIR/sample.txt"
    printf 'hello' >"$file"
    run skillshare_verify_sha256 "$file" "0000000000000000000000000000000000000000000000000000000000000000"
    [ "$status" -ne 0 ]
}

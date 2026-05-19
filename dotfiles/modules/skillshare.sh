# ---------------------------------------------
# モジュール: Skillshare
# AI CLI 間のスキル/エージェント同期 (Claude/Codex/Gemini/OpenCode)
#
# このモジュールは独立して動作するが、対象となる AI CLI が一つもインストール
# されていない場合は自動的にスキップする (検出ベース)。
#
# NOTE: UPGRADE フラグの扱いは lib/skillshare.sh の skillshare_install_cli() に
#       委譲する (skillshare CLI 自体の再インストール判定をそこで行う)。
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="skillshare"
MODULE_NAME="Skillshare"
MODULE_DESC="AI CLI 間スキル/エージェント同期 (Claude/Codex/Gemini/OpenCode)"
MODULE_DEFAULT=1
# AI CLI モジュール (claude-code=20, gemini-cli=30, codex-cli=31, copilot-cli=32,
# opencode=33) より後に走らせる必要があるため 40 を割り当てる。
MODULE_ORDER=40
MODULE_DEPS=""

# --- 設定値 (env で override 可能) ---
# NOTE: skillshare CLI は config.yaml の source: / agents_source: フィールドのみを
#       真実のソースとして参照する。setup.sh は config.yaml にこれら絶対パスを書き込む。
#       過去存在した ~/.config/skillshare/{skills,agents} 補助 symlink は廃止 (Docker
#       ビルドで一時パスを指して dangling になるため、lib 側で清掃のみ行う)。
SKILLSHARE_MOD_CONFIG_DIR="${HOME}/.config/skillshare"
SKILLSHARE_MOD_CONFIG_TEMPLATE="${SCRIPT_DIR}/.config/skillshare/config.yaml.template"
SKILLSHARE_MOD_SKILLS_SRC="${SCRIPT_DIR}/.claude/skills"
SKILLSHARE_MOD_AGENTS_SRC="${SCRIPT_DIR}/.claude/agents"
SKILLSHARE_MOD_CODEX_CONVERTER="${SCRIPT_DIR}/scripts/sync-codex-agents.py"

# --- ヘルパー: AI CLI が一つでも検出できるかを判定する ---
# claude/gemini/codex/opencode のいずれかの設定ディレクトリがあれば 0、なければ 1。
_skillshare_mod_any_ai_cli_present() {
    [[ -d "${HOME}/.claude" ]] && return 0
    [[ -d "${HOME}/.gemini" ]] && return 0
    [[ -d "${HOME}/.codex" ]] && return 0
    [[ -d "${HOME}/.config/opencode" ]] && return 0
    return 1
}

# --- セットアップ ---
setup_skillshare() {
    msg_header "Skillshare (AI CLI スキル同期)"
    print_separator

    # AI CLI が一つも検出されなければスキップ (検出ベース)
    if ! _skillshare_mod_any_ai_cli_present; then
        msg_info "対象となる AI CLI (claude/gemini/codex/opencode) が見つかりません。"
        msg_step "AI CLI モジュールを先にインストールしてください。skillshare セットアップをスキップします。"
        return 0
    fi

    local config_dir="$SKILLSHARE_MOD_CONFIG_DIR"
    local config_template="$SKILLSHARE_MOD_CONFIG_TEMPLATE"
    local skills_src="$SKILLSHARE_MOD_SKILLS_SRC"
    local agents_src="$SKILLSHARE_MOD_AGENTS_SRC"

    if [[ ! -d "$skills_src" ]]; then
        msg_warn "スキルソースが見つかりません: ${skills_src}"
        msg_step "dotfiles/.claude/skills/ にスキルを配置してください。skillshare のセットアップをスキップします。"
        return 0
    fi
    if [[ ! -f "$config_template" ]]; then
        msg_warn "config.yaml テンプレートが見つかりません: ${config_template}"
        return 0
    fi

    # skillshare CLI のインストール (lib/skillshare.sh)
    skillshare_install_cli || {
        msg_warn "skillshare CLI のインストールに失敗しました。スキル同期セットアップをスキップします。"
        return 0
    }
    if ! command -v skillshare >/dev/null 2>&1; then
        msg_warn "skillshare コマンドが利用できません。設定をスキップします。"
        return 0
    fi

    run_cmd mkdir -p "$config_dir" || return 1

    skillshare_render_config "${config_dir}/config.yaml" "$config_template" "$skills_src" "$agents_src" || return 1

    # 旧バージョンが残した補助 symlink を清掃 (現バージョンでは使わない)
    skillshare_cleanup_legacy_links

    skillshare_register_targets
    skillshare_run_sync
    skillshare_convert_codex_agents "$agents_src" "$SKILLSHARE_MOD_CODEX_CONVERTER" "${HOME}/.codex/agents"

    # Docker ビルド時に source が一時パス (/tmp/dotfiles) のままだと、
    # ビルド完了後に削除されて config.yaml が壊れる。env で恒久パスが指定
    # されていれば config.yaml をその値に書き換える (ローカル運用では no-op)。
    skillshare_remap_runtime_paths \
        "${config_dir}/config.yaml" \
        "${SKILLSHARE_RUNTIME_SKILLS_SRC:-}" \
        "${SKILLSHARE_RUNTIME_AGENTS_SRC:-}"

    msg_success "Skillshare セットアップが完了しました。"
}

# --- ステータス表示 ---
module_status() {
    if command -v skillshare &>/dev/null; then
        local version
        version=$(skillshare --version 2>/dev/null | head -1 | awk '{print $NF}')
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "skillshare ${version}"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
# NOTE: 各 AI CLI 側に同期されたスキル/エージェントは個別管理が必要なため、
#       自動削除はせず手順の表示のみとする (skillshare target remove で先に解除すべき)。
uninstall_skillshare() {
    printf '%s\n' "Skillshare のアンインストール手順:"
    msg_step "skillshare target list  # 登録済み target を確認"
    msg_step "skillshare target remove <name>  # 各 target を順に解除"
    msg_step "rm -f ${HOME}/.local/bin/skillshare"
    msg_step "rm -rf ${SKILLSHARE_MOD_CONFIG_DIR}"
    printf '\n'
    printf '%s\n' "NOTE: 各 AI CLI 側に同期済みのスキル/エージェントは、target remove で"
    printf '%s\n' "      symlink 解除した後、必要に応じて手動で確認・削除してください。"
}

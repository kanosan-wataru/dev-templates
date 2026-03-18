# ---------------------------------------------
# モジュール: Codex CLI
# OpenAI Codex CLI + 設定ファイル配置 (Node.js v18+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="codex-cli"
MODULE_NAME="Codex CLI"
MODULE_DESC="OpenAI Codex CLI (Node.js v18+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=31
MODULE_DEPS="node"

# --- Codex CLI 固有変数 ---
# NOTE: モジュール固有の変数には衝突回避のため CODEX_MOD_ プレフィックスを使用
CODEX_MOD_CONFIG_DIR="$HOME/.codex"
CODEX_MOD_RULES_DIR="$CODEX_MOD_CONFIG_DIR/rules"
CODEX_MOD_SKILLS_DIR="$CODEX_MOD_CONFIG_DIR/skills"

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
CODEX_MOD_MANAGED_FILES=(
    # config.toml (model and reasoning settings)
    "$SCRIPT_DIR/.codex/config.toml|$CODEX_MOD_CONFIG_DIR/config.toml|config.toml|"
    # rules/default.rules (sandbox allow/deny rules)
    "$SCRIPT_DIR/.codex/rules/default.rules|$CODEX_MOD_RULES_DIR/default.rules|rules/default.rules|"
    # AGENTS.md (agent identity and capabilities)
    "$SCRIPT_DIR/.codex/AGENTS.md|$CODEX_MOD_CONFIG_DIR/AGENTS.md|AGENTS.md|"
    # skills/context-loader (project context loading skill)
    "$SCRIPT_DIR/.codex/skills/context-loader/SKILL.md|$CODEX_MOD_SKILLS_DIR/context-loader/SKILL.md|skills/context-loader/SKILL.md|"
)

# 配置先ディレクトリのリスト（サブディレクトリを事前作成するため）
# NOTE: install_config は親ディレクトリの自動作成を行わないため、ここで明示的に列挙する
CODEX_MOD_REQUIRED_DIRS=(
    "$CODEX_MOD_CONFIG_DIR"
    "$CODEX_MOD_RULES_DIR"
    "$CODEX_MOD_SKILLS_DIR"
    "$CODEX_MOD_SKILLS_DIR/context-loader"
)

# --- セットアップ ---
setup_codex_cli() {
    msg_header "Codex CLI"
    print_separator

    # =========================================
    # CLI インストール
    # =========================================

    # べき等性チェック
    if command -v codex >/dev/null 2>&1; then
        local current_ver
        current_ver=$(codex --version 2>/dev/null || printf '%s' "unknown")
        msg_info "Codex CLI は既にインストールされています (${current_ver})。スキップします。"
    else
        # Node.js / npm の確認
        if ! ensure_node; then
            msg_warn "Codex CLI のインストールには Node.js v18+ が必要です。"
            return 1
        fi

        msg_info "Codex CLI をインストールします..."
        run_cmd npm install -g @openai/codex || {
            msg_error "Codex CLI のインストールに失敗しました。"
            msg_step "npm install -g の権限エラーの場合:" >&2
            msg_step "  npm config set prefix ~/.local" >&2
            msg_step "または nvm/fnm をお使いの場合は sudo 不要です。" >&2
            return 1
        }

        if (( DRY_RUN )); then
            msg_info "Codex CLI をインストール予定です（dry-run）。"
        else
            msg_success "Codex CLI のインストールが完了しました。"
            printf '\n'
            printf '%s\n' "初回セットアップ:"
            msg_step "export OPENAI_API_KEY=<your-api-key>"
            msg_step "codex  # 対話的に使用開始"
            msg_step "詳細: https://github.com/openai/codex"
        fi
    fi

    # =========================================
    # 設定ファイルの配置
    # =========================================
    printf '\n'
    msg_info "設定ファイルを配置します..."

    # 必要なディレクトリを事前作成（権限 700）
    for dir in "${CODEX_MOD_REQUIRED_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            run_cmd command mkdir -p "$dir" || {
                msg_error "${dir} の作成に失敗しました。"
                return 1
            }
            # NOTE: config may contain sensitive settings; restrict permissions
            run_cmd command chmod 700 "$dir" || {
                msg_error "${dir} の権限設定に失敗しました。"
                return 1
            }
            if (( DRY_RUN )); then
                msg_info "${dir} を作成予定です（dry-run）。"
            else
                msg_info "${dir} を作成しました。"
            fi
        fi
    done

    # 設定ファイルの配置
    for entry in "${CODEX_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<< "$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    msg_success "Codex CLI 設定ファイルの配置が完了しました。"
}

# --- アンインストール ---
uninstall_codex_cli() {
    local restored=0

    # =========================================
    # 設定ファイルの復元
    # =========================================
    for entry in "${CODEX_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<< "$entry"

        # find_newest_backup で最新のバックアップを検索
        local newest
        newest=$(find_newest_backup "${dst}.backup."'*') || true

        if [[ -n "$newest" ]]; then
            printf '%s\n' "復元: ${label} をバックアップ ($(basename "$newest")) から戻します。"
            run_cmd command mv "$newest" "$dst" || {
                msg_error "${label} の復元に失敗しました。"
                return 1
            }
            restored=1
        elif [[ -f "$dst" || -h "$dst" ]]; then
            msg_warn "${label} のバックアップが見つかりません。手動で確認してください: ${dst}"
        else
            msg_info "${label} は配置されていません。スキップします。"
        fi
    done

    if (( restored )); then
        msg_success "Codex CLI 設定ファイルのアンインストールが完了しました。"
    else
        msg_info "Codex CLI 設定ファイルの復元・削除対象はありませんでした。"
    fi

    # =========================================
    # CLI アンインストール
    # =========================================

    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v codex >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g @openai/codex >/dev/null 2>&1; }; then
            msg_info "Codex CLI はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        msg_warn "npm が見つからないため Codex CLI をアンインストールできません。"
        return 1
    fi

    msg_info "Codex CLI をアンインストールします..."
    run_cmd npm uninstall -g @openai/codex || {
        msg_error "Codex CLI のアンインストールに失敗しました。"
        return 1
    }
    msg_success "Codex CLI をアンインストールしました。"
    # NOTE: ~/.codex/ ディレクトリはユーザーデータ（セッション、メモリ等）を含むため削除しない
    printf '%s\n' "NOTE: ~/.codex/ ディレクトリはユーザーデータを含むため削除されていません。不要な場合は手動で削除してください:"
    msg_step "rm -rf ~/.codex/"
}

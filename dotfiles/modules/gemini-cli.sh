# ---------------------------------------------
# モジュール: Gemini CLI
# Google AI CLI (Node.js v20+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="gemini-cli"
MODULE_NAME="Gemini CLI"
MODULE_DESC="Google AI CLI (Node.js v20+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=30
MODULE_DEPS="node"

# --- Gemini CLI 固有変数 ---
# NOTE: モジュール固有の変数には衝突回避のため GEMINI_MOD_ プレフィックスを使用
GEMINI_MOD_CONFIG_DIR="$HOME/.gemini"
GEMINI_MOD_SKILLS_DIR="$GEMINI_MOD_CONFIG_DIR/skills"

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
GEMINI_MOD_MANAGED_FILES=(
    # settings.json (session retention settings)
    "$SCRIPT_DIR/.gemini/settings.json|$GEMINI_MOD_CONFIG_DIR/settings.json|settings.json|"
    # GEMINI.md (global custom instructions)
    "$SCRIPT_DIR/.gemini/GEMINI.md|$GEMINI_MOD_CONFIG_DIR/GEMINI.md|GEMINI.md|"
    # skills/context-loader (project context loading skill)
    "$SCRIPT_DIR/.gemini/skills/context-loader/SKILL.md|$GEMINI_MOD_SKILLS_DIR/context-loader/SKILL.md|skills/context-loader/SKILL.md|"
)

# 配置先ディレクトリのリスト（サブディレクトリを事前作成するため）
# NOTE: install_config は親ディレクトリの自動作成を行わないため、ここで明示的に列挙する
GEMINI_MOD_REQUIRED_DIRS=(
    "$GEMINI_MOD_CONFIG_DIR"
    "$GEMINI_MOD_SKILLS_DIR"
    "$GEMINI_MOD_SKILLS_DIR/context-loader"
)

# --- セットアップ ---
setup_gemini_cli() {
    msg_header "Gemini CLI"
    print_separator

    # =========================================
    # CLI インストール
    # =========================================

    # べき等性チェック
    if command -v gemini >/dev/null 2>&1 && ! ((UPGRADE)); then
        local current_ver
        current_ver=$(gemini --version 2>/dev/null || printf '%s' "unknown")
        msg_info "Gemini CLI は既にインストールされています (${current_ver})。スキップします。"
    else
        # Upgrade path: show info message when upgrading an existing installation
        if command -v gemini >/dev/null 2>&1 && ((UPGRADE)); then
            msg_info "Gemini CLI のアップグレードを実行します..."
        fi
        # Node.js / npm の確認
        if ! ensure_node 20; then
            msg_warn "Gemini CLI のインストールには Node.js v20+ が必要です。"
            return 1
        fi

        msg_info "Gemini CLI をインストールします..."
        run_cmd npm install -g @google/gemini-cli || {
            msg_error "Gemini CLI のインストールに失敗しました。"
            msg_step "npm install -g の権限エラーの場合:" >&2
            msg_step "  npm config set prefix ~/.local" >&2
            msg_step "または nvm/fnm をお使いの場合は sudo 不要です。" >&2
            return 1
        }

        if ((DRY_RUN)); then
            msg_info "Gemini CLI をインストール予定です（dry-run）。"
        else
            msg_success "Gemini CLI のインストールが完了しました。"
            printf '\n'
            printf '%s\n' "初回セットアップ:"
            msg_step "gemini  # Google アカウントで認証"
            msg_step "詳細: https://github.com/google-gemini/gemini-cli"
        fi
    fi

    # =========================================
    # 設定ファイルの配置
    # =========================================
    printf '\n'
    msg_info "設定ファイルを配置します..."

    # 必要なディレクトリを事前作成（権限 700）
    for dir in "${GEMINI_MOD_REQUIRED_DIRS[@]}"; do
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
            if ((DRY_RUN)); then
                msg_info "${dir} を作成予定です（dry-run）。"
            else
                msg_info "${dir} を作成しました。"
            fi
        fi
    done

    # 設定ファイルの配置
    for entry in "${GEMINI_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<<"$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done

    msg_success "Gemini CLI 設定ファイルの配置が完了しました。"
}

# --- ステータス表示 ---
module_status() {
    local status version
    if command -v gemini &>/dev/null; then
        version=$(gemini --version 2>/dev/null | head -1 || printf '%s' "installed")
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_gemini_cli() {
    local restored=0

    # =========================================
    # 設定ファイルの復元
    # =========================================
    for entry in "${GEMINI_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<<"$entry"

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
        elif [[ -f "$dst" || -L "$dst" ]]; then
            msg_warn "${label} のバックアップが見つかりません。手動で確認してください: ${dst}"
        else
            msg_info "${label} は配置されていません。スキップします。"
        fi
    done

    if ((restored)); then
        msg_success "Gemini CLI 設定ファイルのアンインストールが完了しました。"
    else
        msg_info "Gemini CLI 設定ファイルの復元・削除対象はありませんでした。"
    fi

    # =========================================
    # CLI アンインストール
    # =========================================

    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v gemini >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g @google/gemini-cli >/dev/null 2>&1; }; then
            msg_info "Gemini CLI はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        msg_warn "npm が見つからないため Gemini CLI をアンインストールできません。"
        return 1
    fi

    msg_info "Gemini CLI をアンインストールします..."
    run_cmd npm uninstall -g @google/gemini-cli || {
        msg_error "Gemini CLI のアンインストールに失敗しました。"
        return 1
    }
    msg_success "Gemini CLI をアンインストールしました。"
    # NOTE: ~/.gemini/ ディレクトリはユーザーデータ（セッション等）を含むため削除しない
    printf '%s\n' "NOTE: ~/.gemini/ ディレクトリはユーザーデータを含むため削除されていません。不要な場合は手動で削除してください:"
    msg_step "rm -rf ~/.gemini/"
}

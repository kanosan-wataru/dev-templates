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
CODEX_MOD_CONFIG_SRC="$SCRIPT_DIR/.codex"
CODEX_MOD_CONFIG_DIR="$HOME/.codex"

# --- セットアップ ---
setup_codex_cli() {
    msg_header "Codex CLI"
    print_separator

    # =========================================
    # CLI インストール
    # =========================================

    # べき等性チェック
    if command -v codex >/dev/null 2>&1 && ! ((UPGRADE)); then
        local current_ver
        current_ver=$(codex --version 2>/dev/null || printf '%s' "unknown")
        msg_info "Codex CLI は既にインストールされています (${current_ver})。スキップします。"
    else
        # Upgrade path: show info message when upgrading an existing installation
        if command -v codex >/dev/null 2>&1 && ((UPGRADE)); then
            msg_info "Codex CLI のアップグレードを実行します... (現在: $(codex --version 2>/dev/null || echo 'unknown'))"
        fi
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

        if ((DRY_RUN)); then
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

    # 機密設定保護: umask 077 で新規作成ディレクトリを 0700 にする
    # NOTE: trap は使わず明示 save/restore する。INT/TERM 中断時は setup.sh 自体が
    # 終了するため umask 漏洩の影響範囲は当該プロセスに限定される。
    local _old_umask _rc
    _old_umask=$(umask)
    umask 077
    install_tree \
        "$CODEX_MOD_CONFIG_SRC" \
        "$CODEX_MOD_CONFIG_DIR" \
        ".codex"
    _rc=$?
    umask "$_old_umask"
    if ((_rc != 0)); then
        msg_error "Codex CLI 設定ファイルの配置に失敗しました。"
        return 1
    fi

    msg_success "Codex CLI 設定ファイルの配置が完了しました。"
}

# --- ステータス表示 ---
module_status() {
    local status version
    if command -v codex &>/dev/null; then
        version=$(codex --version 2>/dev/null | head -1 || printf '%s' "installed")
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_codex_cli() {
    # =========================================
    # 設定ファイルの復元
    # =========================================
    CODEX_MOD_RESTORED_COUNT=0
    uninstall_tree \
        "$CODEX_MOD_CONFIG_SRC" \
        "$CODEX_MOD_CONFIG_DIR" \
        ".codex" \
        CODEX_MOD_RESTORED_COUNT || return 1

    if ((CODEX_MOD_RESTORED_COUNT > 0)); then
        msg_success "Codex CLI 設定ファイルのアンインストールが完了しました（復元: ${CODEX_MOD_RESTORED_COUNT} 件）。"
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

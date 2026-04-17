# ---------------------------------------------
# モジュール: GitHub Copilot CLI
# npm install -g @github/copilot (Node.js v22+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="copilot-cli"
MODULE_NAME="GitHub Copilot CLI"
MODULE_DESC="GitHub Copilot CLI (Node.js v22+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=32
MODULE_DEPS="node"

# --- Copilot CLI 固有変数 ---
# NOTE: モジュール固有の変数には衝突回避のため COPILOT_MOD_ プレフィックスを使用
COPILOT_MOD_NPM_PACKAGE="@github/copilot"
COPILOT_MOD_MIN_NODE_VERSION=22

# --- セットアップ ---
setup_copilot_cli() {
    msg_header "GitHub Copilot CLI"
    print_separator

    # べき等性チェック
    if command -v copilot >/dev/null 2>&1 && ! ((UPGRADE)); then
        local current_ver
        current_ver=$(copilot --version 2>/dev/null || printf '%s' "unknown")
        msg_info "GitHub Copilot CLI は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    # アップグレード時のメッセージ
    if command -v copilot >/dev/null 2>&1 && ((UPGRADE)); then
        msg_info "GitHub Copilot CLI のアップグレードを実行します... (現在: $(copilot --version 2>/dev/null || echo 'unknown'))"
    fi

    # Node.js / npm の確認（v22+ 必要）
    if ! ensure_node "$COPILOT_MOD_MIN_NODE_VERSION"; then
        msg_warn "GitHub Copilot CLI のインストールには Node.js v${COPILOT_MOD_MIN_NODE_VERSION}+ が必要です。"
        return 1
    fi

    msg_info "GitHub Copilot CLI をインストールします..."
    run_cmd npm install -g "$COPILOT_MOD_NPM_PACKAGE" || {
        msg_error "GitHub Copilot CLI のインストールに失敗しました。"
        msg_step "npm install -g の権限エラーの場合:" >&2
        msg_step "  npm config set prefix ~/.local" >&2
        msg_step "または nvm/fnm をお使いの場合は sudo 不要です。" >&2
        return 1
    }

    if ((DRY_RUN)); then
        msg_info "GitHub Copilot CLI をインストール予定です（dry-run）。"
    else
        msg_success "GitHub Copilot CLI のインストールが完了しました。"
        printf '\n'
        printf '%s\n' "初回セットアップ:"
        msg_step "copilot          # 起動後 /login で認証"
        msg_step "または GH_TOKEN 環境変数を設定"
        msg_step "詳細: https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli"
    fi
}

# --- ステータス表示 ---
module_status() {
    local status version
    if command -v copilot &>/dev/null; then
        version=$(copilot --version 2>/dev/null | head -1 || printf '%s' "installed")
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_copilot_cli() {
    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v copilot >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g "$COPILOT_MOD_NPM_PACKAGE" >/dev/null 2>&1; }; then
            msg_info "GitHub Copilot CLI はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        msg_warn "npm が見つからないため GitHub Copilot CLI をアンインストールできません。"
        return 1
    fi

    msg_info "GitHub Copilot CLI をアンインストールします..."
    run_cmd npm uninstall -g "$COPILOT_MOD_NPM_PACKAGE" || {
        msg_error "GitHub Copilot CLI のアンインストールに失敗しました。"
        return 1
    }
    msg_success "GitHub Copilot CLI をアンインストールしました。"
}

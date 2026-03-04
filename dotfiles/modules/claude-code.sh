# ---------------------------------------------
# モジュール: Claude Code
# Anthropic CLI (Node.js v18+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="claude-code"
MODULE_NAME="Claude Code"
MODULE_DESC="Anthropic CLI (Node.js v18+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=20

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[Claude Code]%b%f"
    print -P "---------------------------------------------"

    # べき等性チェック
    if command -v claude >/dev/null 2>&1; then
        local current_ver
        current_ver=$(claude --version 2>/dev/null || print "unknown")
        print -P "情報: Claude Code は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    # Node.js / npm の確認
    if ! ensure_node; then
        print -P "%F{220}スキップ: Claude Code のインストールには Node.js v18+ が必要です。%f"
        return 1
    fi

    print -P "Claude Code をインストールします..."
    run_cmd npm install -g @anthropic-ai/claude-code || {
        print -P "%F{160}エラー: Claude Code のインストールに失敗しました。%f" >&2
        print -P "  npm install -g の権限エラーの場合:" >&2
        print -P "    npm config set prefix ~/.local" >&2
        print -P "  または nvm/fnm をお使いの場合は sudo 不要です。" >&2
        return 1
    }

    if (( DRY_RUN )); then
        print -P "情報: Claude Code をインストール予定です（dry-run）。"
    else
        print -P "%F{34}Claude Code のインストールが完了しました。%f"
        print -P ""
        print -P "初回セットアップ:"
        print -P "  claude  # 対話的に API キーを設定"
        print -P "  詳細: https://docs.anthropic.com/en/docs/claude-code"
    fi
}

# --- アンインストール ---
module_uninstall() {
    # インストール状態を判定（コマンドの存在 or npm パッケージの存在）
    if ! command -v claude >/dev/null 2>&1; then
        if ! { command -v npm >/dev/null 2>&1 && npm ls -g @anthropic-ai/claude-code >/dev/null 2>&1 }; then
            print -P "情報: Claude Code はインストールされていません。スキップします。"
            return 0
        fi
    fi

    if ! command -v npm >/dev/null 2>&1; then
        print -P "%F{220}スキップ: npm が見つからないため Claude Code をアンインストールできません。%f"
        return 1
    fi

    print -P "Claude Code をアンインストールします..."
    run_cmd npm uninstall -g @anthropic-ai/claude-code || {
        print -P "%F{160}エラー: Claude Code のアンインストールに失敗しました。%f" >&2
        return 1
    }
    print -P "%F{34}Claude Code をアンインストールしました。%f"
}

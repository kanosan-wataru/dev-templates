# ---------------------------------------------
# モジュール: Gemini CLI
# Google AI CLI (Node.js v18+ 必要)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="gemini-cli"
MODULE_NAME="Gemini CLI"
MODULE_DESC="Google AI CLI (Node.js v18+ 必要)"
MODULE_DEFAULT=0
MODULE_ORDER=30

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[Gemini CLI]%b%f"
    print -P "---------------------------------------------"

    # べき等性チェック
    if command -v gemini >/dev/null 2>&1; then
        local current_ver
        current_ver=$(gemini --version 2>/dev/null || print "unknown")
        print -P "情報: Gemini CLI は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    # Node.js / npm の確認
    if ! ensure_node; then
        print -P "%F{220}スキップ: Gemini CLI のインストールには Node.js v18+ が必要です。%f"
        return 1
    fi

    print -P "Gemini CLI をインストールします..."
    run_cmd npm install -g @google/gemini-cli || {
        print -P "%F{160}エラー: Gemini CLI のインストールに失敗しました。%f" >&2
        print -P "  npm install -g の権限エラーの場合:" >&2
        print -P "    npm config set prefix ~/.local" >&2
        print -P "  または nvm/fnm をお使いの場合は sudo 不要です。" >&2
        return 1
    }

    if (( DRY_RUN )); then
        print -P "情報: Gemini CLI をインストール予定です（dry-run）。"
    else
        print -P "%F{34}Gemini CLI のインストールが完了しました。%f"
        print -P ""
        print -P "初回セットアップ:"
        print -P "  gemini  # Google アカウントで認証"
        print -P "  詳細: https://github.com/google-gemini/gemini-cli"
    fi
}

# --- アンインストール ---
module_uninstall() {
    if command -v gemini >/dev/null 2>&1; then
        if ! command -v npm >/dev/null 2>&1; then
            print -P "%F{220}スキップ: npm が見つからないため Gemini CLI をアンインストールできません。%f"
            return 1
        fi
        print -P "Gemini CLI をアンインストールします..."
        run_cmd npm uninstall -g @google/gemini-cli || {
            print -P "%F{160}エラー: Gemini CLI のアンインストールに失敗しました。%f" >&2
            return 1
        }
        print -P "%F{34}Gemini CLI をアンインストールしました。%f"
    elif command -v npm >/dev/null 2>&1 && npm ls -g @google/gemini-cli >/dev/null 2>&1; then
        print -P "Gemini CLI をアンインストールします..."
        run_cmd npm uninstall -g @google/gemini-cli || {
            print -P "%F{160}エラー: Gemini CLI のアンインストールに失敗しました。%f" >&2
            return 1
        }
        print -P "%F{34}Gemini CLI をアンインストールしました。%f"
    else
        print -P "情報: Gemini CLI はインストールされていません。スキップします。"
    fi
}

# ----------------------------
# .env ファイルの読み込み
# ----------------------------
# ~/.claude/.env から環境変数を読み込む（MCP サーバー設定等で使用）
# 無効化: export DISABLE_DOTENV=1 を .zshenv 等で設定
# ----------------------------
if [[ "${DISABLE_DOTENV:-0}" != "1" ]]; then
    if [[ -f "$HOME/.claude/.env" ]]; then
        set -a
        source "$HOME/.claude/.env"
        set +a
    fi
fi

# ----------------------------
# .env file loading
# ----------------------------
# Load environment variables from ~/.claude/.env (used for MCP server config, etc.)
# Disable: set export DISABLE_DOTENV=1 in .zshenv/.bashrc etc.
# ----------------------------
if [[ "${DISABLE_DOTENV:-0}" != "1" ]]; then
    if [[ -f "$HOME/.claude/.env" ]]; then
        set -a
        source "$HOME/.claude/.env"
        set +a
    fi
fi

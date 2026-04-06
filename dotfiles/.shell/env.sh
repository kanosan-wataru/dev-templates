# ----------------------------
# .env file loading
# ----------------------------
# Load environment variables from known .env locations.
# Disable: set export DISABLE_DOTENV=1 in .zshenv/.bashrc etc.
#
# Sources:
#   1. ~/.claude/.env        (MCP server config, etc.)
#   2. ~/.config/*/.env      (service tokens: op, etc.)
#
# NOTE: 1password.sh has its own validated loader for ~/.config/op/.env.
#       Generic loading here is a fallback for other services.
# ----------------------------
if [[ "${DISABLE_DOTENV:-0}" != "1" ]]; then
    # ~/.claude/.env
    if [[ -f "$HOME/.claude/.env" ]]; then
        set -a
        source "$HOME/.claude/.env"
        set +a
    fi

    # ~/.config/*/.env (skip files already handled by dedicated modules)
    for _dotenv_file in "$HOME"/.config/*/.env; do
        # No matches — skip
        [[ -e "$_dotenv_file" ]] || continue
        # Skip 1password token (handled by 1password.sh with validation)
        [[ "$_dotenv_file" == */op/.env ]] && continue
        if [[ -r "$_dotenv_file" ]]; then
            set -a
            source "$_dotenv_file"
            set +a
        fi
    done
    unset _dotenv_file
fi

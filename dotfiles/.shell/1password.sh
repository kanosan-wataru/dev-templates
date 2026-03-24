# ----------------------------
# 1Password SSH agent
# ----------------------------
# Auto-configure the 1Password SSH agent.
# Auto-detects WSL / native Linux / macOS and applies the appropriate settings.
#
# Default: OFF
# Enable: set export ENABLE_SSH_1PASSWORD=1 in .zshenv/.bashrc etc.
# ----------------------------

# --- 1Password Service Account Token ---
# NOTE: Independent of ENABLE_SSH_1PASSWORD -- always load if the file exists
if [[ -r "${HOME}/.config/op/.env" ]]; then
    # Validate file permissions (warn if not 600)
    _op_token_perms=$(command stat -c '%a' "${HOME}/.config/op/.env" 2>/dev/null ||
        command stat -f '%Lp' "${HOME}/.config/op/.env" 2>/dev/null)
    if [[ "$_op_token_perms" != "600" ]]; then
        printf '%s\n' "Warning: ${HOME}/.config/op/.env permissions are ${_op_token_perms} (recommended: 600)." >&2
    fi
    unset _op_token_perms
    # Validate file contains only the expected export line before sourcing
    _op_token_file="${HOME}/.config/op/.env"
    if grep -qxE "export OP_SERVICE_ACCOUNT_TOKEN='[A-Za-z0-9_+/=.-]+'" "$_op_token_file"; then
        # shellcheck disable=SC1090
        source "$_op_token_file"
    else
        printf '%s\n' "[1password] Token file content is invalid: $_op_token_file" >&2
    fi
    unset _op_token_file
fi

if [[ "${ENABLE_SSH_1PASSWORD:-0}" != "1" ]]; then
    return 0 2>/dev/null || true
fi

# --- WSL detection ---
_1password_is_wsl() {
    [[ -f /proc/version ]] && grep -qi 'microsoft' /proc/version 2>/dev/null
}

if _1password_is_wsl; then
    # -------------------------------------------------
    # WSL: Use Windows-side 1Password SSH agent
    # -------------------------------------------------
    if command -v ssh.exe >/dev/null 2>&1; then
        alias ssh='ssh.exe'
    fi
    if command -v ssh-add.exe >/dev/null 2>&1; then
        alias ssh-add='ssh-add.exe'
    fi

elif [[ "$OSTYPE" == darwin* ]]; then
    # -------------------------------------------------
    # macOS: Set 1Password SSH agent socket
    # -------------------------------------------------
    _op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [[ -S "$_op_sock" ]]; then
        export SSH_AUTH_SOCK="$_op_sock"
    fi
    unset _op_sock

elif [[ "$OSTYPE" == linux* ]]; then
    # -------------------------------------------------
    # Native Linux: Set 1Password SSH agent socket
    # -------------------------------------------------
    _op_sock="$HOME/.1password/agent.sock"
    if [[ -S "$_op_sock" ]]; then
        export SSH_AUTH_SOCK="$_op_sock"
    fi
    unset _op_sock
fi

# Clean up helper function
unset -f _1password_is_wsl 2>/dev/null

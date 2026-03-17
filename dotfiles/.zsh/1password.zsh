# ----------------------------
# 1Password SSH エージェント
# ----------------------------
# 1Password の SSH エージェントを自動設定する。
# WSL / ネイティブ Linux / macOS を自動判定し、環境に応じた設定を適用する。
#
# デフォルト: OFF
# 有効化: export ENABLE_SSH_1PASSWORD=1 を .zshenv 等で設定
# ----------------------------

if [[ "${ENABLE_SSH_1PASSWORD:-0}" != "1" ]]; then
    return 0 2>/dev/null || true
fi

# --- WSL 判定 ---
_1password_is_wsl() {
    [[ -f /proc/version ]] && grep -qi 'microsoft' /proc/version 2>/dev/null
}

if _1password_is_wsl; then
    # -------------------------------------------------
    # WSL: Windows 側の 1Password SSH エージェントを利用
    # -------------------------------------------------
    if command -v ssh.exe >/dev/null 2>&1; then
        alias ssh='ssh.exe'
    fi
    if command -v ssh-add.exe >/dev/null 2>&1; then
        alias ssh-add='ssh-add.exe'
    fi

elif [[ "$OSTYPE" == darwin* ]]; then
    # -------------------------------------------------
    # macOS: 1Password SSH エージェントソケットを設定
    # -------------------------------------------------
    local _op_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [[ -S "$_op_sock" ]]; then
        export SSH_AUTH_SOCK="$_op_sock"
    fi
    unset _op_sock

elif [[ "$OSTYPE" == linux* ]]; then
    # -------------------------------------------------
    # ネイティブ Linux: 1Password SSH エージェントソケットを設定
    # -------------------------------------------------
    local _op_sock="$HOME/.1password/agent.sock"
    if [[ -S "$_op_sock" ]]; then
        export SSH_AUTH_SOCK="$_op_sock"
    fi
    unset _op_sock
fi

# ヘルパー関数のクリーンアップ
unfunction _1password_is_wsl 2>/dev/null

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
    # WSL: Windows 側 1Password の SSH エージェントを利用する
    #   優先: npiperelay + socat で「名前付きパイプ」を WSL の UNIX ソケットへ
    #         ブリッジし、ネイティブ WSL の ssh / git / scp / rsync すべてを
    #         1Password 経由にする。
    #   退避: npiperelay/socat が無ければ ssh.exe / ssh-add.exe エイリアスへ。
    # NOTE: このファイルは bash / zsh の双方から source されるため、
    #       両対応の構文のみを使用する（zsh 専用の &! 等は使わない）。
    # -------------------------------------------------
    _op_sock="$HOME/.1password/agent.sock"
    _op_npiperelay="$HOME/.local/bin/npiperelay.exe"

    if [[ -x "$_op_npiperelay" ]] && command -v socat >/dev/null 2>&1; then
        # 既にブリッジ用リスナーが起動しているか確認（多重起動防止）
        # NOTE: grep -F でソケットパス中の "." 等をメタ文字として誤マッチさせない。
        _op_running=0
        if command -v ss >/dev/null 2>&1; then
            ss -lx 2>/dev/null | grep -qF "$_op_sock" && _op_running=1
        elif command -v ssh-add >/dev/null 2>&1; then
            # ss が無い環境: ソケットへ実際に接続できる (rc!=2) 場合のみ稼働中とみなす。
            # rc=2 は接続不可 = socat が落ちてソケットだけ残った stale 状態を含む。
            SSH_AUTH_SOCK="$_op_sock" ssh-add -l >/dev/null 2>&1
            [[ $? -ne 2 ]] && _op_running=1
        elif [[ -S "$_op_sock" ]]; then
            _op_running=1
        fi

        if [[ "$_op_running" -eq 0 ]]; then
            # 多ユーザー WSL でも他ユーザーに渡らないよう本人専用権限で作成する
            mkdir -p -m 700 "${_op_sock%/*}" 2>/dev/null
            chmod 700 "${_op_sock%/*}" 2>/dev/null
            rm -f "$_op_sock" 2>/dev/null
            # サブシェル + setsid でシェルから切り離してブリッジを常駐させる。
            # mode=0600 でソケットを本人のみアクセス可能にする。
            (setsid socat UNIX-LISTEN:"$_op_sock",fork,mode=0600 EXEC:"$_op_npiperelay -ei -s //./pipe/openssh-ssh-agent",nofork >/dev/null 2>&1 &) >/dev/null 2>&1
        fi
        export SSH_AUTH_SOCK="$_op_sock"
        unset _op_running
    else
        # フォールバック: Windows 側バイナリへ転送（対話的な ssh/ssh-add のみ）
        if command -v ssh.exe >/dev/null 2>&1; then
            alias ssh='ssh.exe'
        fi
        if command -v ssh-add.exe >/dev/null 2>&1; then
            alias ssh-add='ssh-add.exe'
        fi
    fi
    unset _op_sock _op_npiperelay

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

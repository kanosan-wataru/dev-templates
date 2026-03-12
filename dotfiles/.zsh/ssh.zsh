# ----------------------------
# 1Password SSH エージェント (WSL)
# ----------------------------
# Windows 側の 1Password SSH エージェントを WSL から利用するための設定
# デフォルト: OFF
# 有効化: export ENABLE_SSH_1PASSWORD=1 を .zshenv 等で設定
# ----------------------------
if [[ "${ENABLE_SSH_1PASSWORD:-0}" == "1" ]]; then
    alias ssh='ssh.exe'
    alias ssh-add='ssh-add.exe'
fi

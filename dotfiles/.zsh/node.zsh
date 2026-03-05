# fnm (Fast Node Manager) 設定
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd)"
fi

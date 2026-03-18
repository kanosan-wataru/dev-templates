# fnm (Fast Node Manager) configuration
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

if command -v fnm >/dev/null 2>&1; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        eval "$(fnm env --use-on-cd)"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        eval "$(fnm env --use-on-cd --shell bash)"
    fi
fi

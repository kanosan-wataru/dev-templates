# ----------------------------
# Basic aliases
# ----------------------------
alias ls='ls --color=auto'
alias la='ls -a'

# ----------------------------
# Modern CLI aliases (conditional)
# NOTE: Auto-skip when tool is not installed
# ----------------------------

# eza -> ls overrides
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias tree='eza --tree --icons'
fi

# bat -> cat override
# NOTE: On Ubuntu, bat is provided as batcat
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
elif command -v batcat >/dev/null 2>&1; then
    alias bat='batcat'
    alias cat='batcat --paging=never'
fi

# fd (provided as fdfind on Ubuntu)
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    alias fd='fdfind'
fi

# ----------------------------
# git aliases
# ----------------------------
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# ----------------------------
# docker aliases
# ----------------------------
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dps='docker ps'

# ----------------------------
# fzf integration functions
# ----------------------------

# Search git branches with fzf and checkout
gco_fzf() {
    command -v fzf >/dev/null 2>&1 || {
        echo "fzf is required" >&2
        return 1
    }
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        echo "Must be inside a git repository" >&2
        return 1
    }
    local branch
    branch=$(git branch --all --format='%(refname:short)' |
        grep -v '^origin/HEAD$' |
        fzf --height 40% --reverse --prompt="checkout> ") || return
    # Strip origin/ prefix for remote branches
    branch=${branch#origin/}
    git checkout "$branch"
}

# Search ghq repositories with fzf and cd
if command -v ghq >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
    ghq_fzf() {
        local dir
        dir=$(ghq list --full-path |
            fzf --height 40% --reverse --prompt="repo> ") || return
        cd "$dir" || return
    }
fi

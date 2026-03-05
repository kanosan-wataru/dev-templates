# ----------------------------
# 基本エイリアス
# ----------------------------
alias ls='ls --color=auto'
alias la='ls -a'

# ----------------------------
# モダン CLI エイリアス（条件付き）
# NOTE: ツール未インストール時は自動スキップ
# ----------------------------

# eza → ls 系の上書き
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias tree='eza --tree --icons'
fi

# bat → cat の上書き
# NOTE: Ubuntu では bat が batcat として提供される
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    alias bat='batcat'
fi
if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi

# fd (Ubuntu では fdfind として提供)
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    alias fd='fdfind'
fi

# ----------------------------
# git エイリアス
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
# docker エイリアス
# ----------------------------
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dps='docker ps'

# ----------------------------
# fzf 連携関数
# ----------------------------

# git ブランチを fzf で検索してチェックアウト
gco_fzf() {
    command -v fzf >/dev/null 2>&1 || {
        echo "fzf が必要です" >&2
        return 1
    }
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        echo "Git リポジトリ内で実行してください" >&2
        return 1
    }
    local branch
    branch=$(git branch --all --format='%(refname:short)' |
        grep -v '^origin/HEAD$' |
        fzf --height 40% --reverse --prompt="checkout> ") || return
    # リモートブランチの場合は origin/ プレフィックスを除去
    branch=${branch#origin/}
    git checkout "$branch"
}

# ghq リポジトリを fzf で検索して移動
if command -v ghq >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
    ghq_fzf() {
        local dir
        dir=$(ghq list --full-path |
            fzf --height 40% --reverse --prompt="repo> ") || return
        cd "$dir" || return
    }
fi

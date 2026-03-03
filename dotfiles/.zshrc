# ~/.zshrc

# Powerlevel10k の instant prompt を有効化
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------
# zsh_history (コマンド履歴)
# ----------------------------
# Zsh履歴ファイルのディレクトリ
_zsh_history_dir=~/.zsh

# ディレクトリが存在しない場合に作成
if [[ ! -d "$_zsh_history_dir" ]]; then
    mkdir -p "$_zsh_history_dir"
    chmod 700 "$_zsh_history_dir" # パーミッションを設定
fi

# 履歴設定
HISTFILE=$_zsh_history_dir/.zsh_history
export HISTSIZE=10000
export SAVEHIST=50000
# セッション間で履歴を即時共有
setopt INC_APPEND_HISTORY SHARE_HISTORY
# 同じコマンドが既に履歴にある場合、新しいものを追加しない
setopt HIST_IGNORE_ALL_DUPS
# 履歴保存時に重複を削除し、最新のタイムスタンプのものを残す
setopt HIST_SAVE_NO_DUPS
# スペース始まりのコマンドを履歴に残さない（機密情報の漏洩防止）
setopt HIST_IGNORE_SPACE


# ----------------------------
# Zinit (プラグインマネージャー) の読み込みとプラグイン設定
# ----------------------------
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    # Powerlevel10k テーマ
    zinit ice depth=1; zinit light romkatv/powerlevel10k
    # Powerlevel10k ユーザー設定ファイルが存在すれば source
    [[ ! -f "${ZDOTDIR:-$HOME}/.zsh/.p10k.zsh" ]] || source "${ZDOTDIR:-$HOME}/.zsh/.p10k.zsh"

    # コンプリーション (fpathに追加するため compinit より前に読み込む)
    zinit light zsh-users/zsh-completions

    # 補完システムの初期化（Zinit のキャッシュ最適化版を使用）
    autoload -Uz compinit
    zicompinit

    # オートサジェスチョン (compinit より後に読み込む)
    zinit light zsh-users/zsh-autosuggestions
    # 複数単語での履歴検索
    zinit load zdharma-continuum/history-search-multi-word
    # シンタックスハイライト (最後尾での読み込みが推奨)
    zinit light zsh-users/zsh-syntax-highlighting
else
    print -P "%F{160}Zinit が見つかりません。セットアップスクリプトを実行してください。%f"
fi

# ----------------------------
# 基本エイリアス
# ----------------------------
alias ls='ls --color=auto'
alias la='ls -a'
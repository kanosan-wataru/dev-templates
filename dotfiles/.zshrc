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


# ----------------------------
# Zinit (プラグインマネージャー) の読み込み
# ----------------------------
# Zinit スクリプトを source (setup.sh または手動でインストールされている前提)
if [[ -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
    source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit
else
    print -P "%F{160}Zinit が見つかりません。セットアップスクリプトを実行するか、手動でインストールしてください。%f"
fi

# ----------------------------
# Zinit プラグイン (Zinit経由で読み込み)
# ----------------------------
# zinit 関数が存在するか確認してから使用
if command -v zinit &> /dev/null; then

    # Powerlevel10k テーマ
    zinit ice depth=1; zinit light romkatv/powerlevel10k
    # Powerlevel10k ユーザー設定ファイルが存在すれば source
    [[ ! -f "${ZDOTDIR:-$HOME}/.zsh/.p10k.zsh" ]] || source "${ZDOTDIR:-$HOME}/.zsh/.p10k.zsh"

    # シンタックスハイライト
    zinit light zsh-users/zsh-syntax-highlighting
    # オートサジェスチョン (入力補完)
    zinit light zsh-users/zsh-autosuggestions
    # コンプリーション (補完機能強化)
    zinit light zsh-users/zsh-completions
    # 複数単語での履歴検索
    zinit load zdharma-continuum/history-search-multi-word

else
    print -P "%F{160}zinit コマンドが利用できないため、Zinit プラグインを読み込めません。%f"
fi

# ----------------------------
# 基本エイリアス
# ----------------------------
alias ls='ls --color=auto'
alias la='ls -a'

# ----------------------------
# trash-cli エイリアス (条件付き)
# ----------------------------
# trash-put コマンドが存在する場合のみ rm を trash-put にエイリアス
# 警告: trash-cli 開発者は挙動の違いからこの設定を推奨していません。
if command -v trash-put &> /dev/null; then
    alias rm='trash-put'
fi
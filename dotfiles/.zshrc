# ~/.zshrc

# Powerlevel10k の instant prompt を有効化
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------
# zsh_history (コマンド履歴)
# ----------------------------
# 履歴設定（${ZDOTDIR:-$HOME}/.zsh ディレクトリは setup.sh で作成済みの前提）
HISTFILE="${ZDOTDIR:-$HOME}/.zsh/.zsh_history"
# フェールセーフ: ディレクトリが存在しなければ作成
[[ -d "${HISTFILE:h}" ]] || command mkdir -p -m 700 "${HISTFILE:h}"
export HISTSIZE=50000
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
# モジュールの読み込み
# ----------------------------
# 設定ファイルの基準ディレクトリ
ZSH_CONFIG_DIR="${ZDOTDIR:-$HOME}/.zsh"

# プラグイン設定（Zinit + 各プラグインの読み込み）
[[ -f "$ZSH_CONFIG_DIR/plugins.zsh" ]] && source "$ZSH_CONFIG_DIR/plugins.zsh"

# エイリアス定義
[[ -f "$ZSH_CONFIG_DIR/aliases.zsh" ]] && source "$ZSH_CONFIG_DIR/aliases.zsh"

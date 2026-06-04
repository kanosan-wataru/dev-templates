# ~/.zshrc

# Guard: skip when sourced by a non-zsh shell (e.g., bash in Claude Code)
[[ -n "$ZSH_VERSION" ]] || return 0

# Powerlevel10k の instant prompt を有効化
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------
# zsh_history (コマンド履歴)
# ----------------------------
# 履歴設定（${ZDOTDIR:-$HOME}/.zsh ディレクトリは setup.sh で作成済みの前提）
HISTFILE="${ZDOTDIR:-$HOME}/.zsh/.zsh_history"
# 警告は Powerlevel10k の instant prompt（本ファイル冒頭で起動済み）に
# バッファされ隠れ得るため、即時 print せず最初のプロンプト確定後に一度だけ
# 表示する。$_histfile_warn が設定されていれば precmd フックが拾う。
autoload -Uz add-zsh-hook
_histfile_notify() {
    [[ -n "$_histfile_warn" ]] && print -ru2 -- "$_histfile_warn"
    add-zsh-hook -d precmd _histfile_notify
    unset _histfile_warn
    unfunction _histfile_notify
}
add-zsh-hook precmd _histfile_notify
# フェールセーフ: 親ディレクトリが無ければ作成（失敗も握り潰さず通知する）
if [[ ! -d "${HISTFILE:h}" ]]; then
    command mkdir -p -m 700 "${HISTFILE:h}" 2>/dev/null \
        || _histfile_warn="[zsh] 警告: ${HISTFILE:h} を作成できず、履歴が保存されない可能性があります。"
fi
# 自己修復: HISTFILE 自体がディレクトリ化していると zsh は履歴を書けず
# 「failed to write history file ...: is a directory」エラーになる。Docker 等の
# バインドマウントが未存在パスをホスト側に空ディレクトリとして作る既知の挙動が
# 典型原因。本ガードはこの「ディレクトリ化」のみを対象とする（FIFO 等は対象外）。
# rmdir は中身があれば失敗するため、実データは壊さない。
[[ -d "$HISTFILE" ]] && command rmdir "$HISTFILE" 2>/dev/null
if [[ -d "$HISTFILE" ]]; then
    # rmdir 不可（非空、またはアクティブなバインドマウント等）。隣接の
    # フォールバック先へ退避するが、そこも同じ要因でディレクトリ化し得るため
    # 再度自己修復を試み、それでも駄目なら「保存されない」と正直に通知する。
    _histfile_fallback="${HISTFILE}.local"
    [[ -d "$_histfile_fallback" ]] && command rmdir "$_histfile_fallback" 2>/dev/null
    if [[ -d "$_histfile_fallback" ]]; then
        _histfile_warn="[zsh] 警告: ${HISTFILE} と ${_histfile_fallback} が共にディレクトリのため、このセッションの履歴は保存されません。"
    else
        _histfile_warn="[zsh] 警告: ${HISTFILE} がディレクトリのため ${_histfile_fallback} にフォールバックしました。"
        HISTFILE="$_histfile_fallback"
    fi
    unset _histfile_fallback
fi
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

# Source shared configs (bash/zsh compatible)
SHELL_CONFIG_DIR="${HOME}/.shell"
if [[ -d "$SHELL_CONFIG_DIR" ]]; then
    for config_file in "$SHELL_CONFIG_DIR"/*.sh(N); do
        source "$config_file"
    done
fi

# Source zsh-specific configs
ZSH_CONFIG_DIR="${ZDOTDIR:-$HOME}/.zsh"

# プラグイン設定（Zinit + 各プラグインの読み込み）
# 未配置/破損時は最低限の補完システムだけ初期化する
if [[ -f "$ZSH_CONFIG_DIR/plugins.zsh" ]]; then
    if ! source "$ZSH_CONFIG_DIR/plugins.zsh"; then
        print -P "%F{220}警告: $ZSH_CONFIG_DIR/plugins.zsh の読み込みに失敗しました。最低限の補完のみ有効化します。%f"
        autoload -Uz compinit && compinit
    fi
else
    print -P "%F{220}警告: $ZSH_CONFIG_DIR/plugins.zsh が見つかりません。最低限の補完のみ有効化します。%f"
    autoload -Uz compinit && compinit
fi

# zsh-only module configs (plugins.zsh loaded above, .p10k.zsh loaded via Zinit)
for _zsh_config_file in "$ZSH_CONFIG_DIR"/*.zsh(N); do
    case "${_zsh_config_file:t}" in
        plugins.zsh|.p10k.zsh) continue ;;
        *) source "$_zsh_config_file" ;;
    esac
done
unset _zsh_config_file

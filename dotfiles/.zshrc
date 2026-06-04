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
# フェールセーフ: 親ディレクトリが存在しなければ作成
[[ -d "${HISTFILE:h}" ]] || command mkdir -p -m 700 "${HISTFILE:h}"
# 自己修復: HISTFILE 自体が（空の）ディレクトリ化していると zsh は履歴を書けず
# 「failed to write history file ...: is a directory」エラーになる。
# Docker 等のバインドマウントが未存在パスをホスト側に空ディレクトリとして
# 作ってしまう既知の挙動が典型原因。空ディレクトリのみ安全に除去する
# （rmdir は中身があれば失敗するため、実データを壊さない）。
[[ -d "$HISTFILE" ]] && command rmdir "$HISTFILE" 2>/dev/null
# それでもディレクトリのまま（非空、またはアクティブなバインドマウント等で
# rmdir 不可）の場合は、サイレントに同じエラーへ陥らないよう、隣接する
# フォールバック履歴ファイルへ切り替えて警告する（履歴機能自体は維持する）。
if [[ -d "$HISTFILE" ]]; then
    print -u2 "[zsh] 警告: ${HISTFILE} がディレクトリのため履歴を書き込めません。${HISTFILE}.local にフォールバックします。"
    HISTFILE="${HISTFILE}.local"
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

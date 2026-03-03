#!/usr/bin/env zsh

# ---------------------------------------------
# Zsh 環境セットアップスクリプト
# - 依存コマンドの確認 (git)
# - Zinit (プラグインマネージャー) のインストール
# - 設定ディレクトリの作成 (~/.zsh)
# - 設定ファイルの配置 (.zshrc, plugins.zsh, aliases.zsh, .p10k.zsh)
# ---------------------------------------------

print -P "Zsh環境のセットアップを開始します..."
print -P "---------------------------------------------"

# --- Zsh実行確認 ---
if [ -z "$ZSH_VERSION" ]; then
    print -P "%F{160}エラー: このスクリプトは Zsh で実行する必要があります。%f" >&2
    print -P "実行例: zsh $0" >&2
    exit 1
fi
print -P "情報: Zsh で実行されています (バージョン: $ZSH_VERSION)"
print -P "---------------------------------------------"


# --- 依存コマンドの確認 ---
if ! command -v git >/dev/null 2>&1; then
    print -P "%F{160}エラー: git コマンドが見つかりません。インストールしてください。%f" >&2
    exit 1
fi
print -P "情報: git が利用可能です ($(command git --version))"
print -P "---------------------------------------------"


# --- Zinit (プラグインマネージャー) のインストール ---
print -P "Zinit の状態を確認・インストールします..."
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    print -P "%F{33} %F{220}Zinit (%F{33}zdharma-continuum/zinit%F{220}) をインストール中...%f"
    # ディレクトリ作成（パーミッションは 700 に固定）
    if ! command mkdir -p -m 700 "$(dirname "$ZINIT_HOME")"; then
        print -P "%F{160}エラー: Zinit 用ディレクトリの作成に失敗しました。%f" >&2
        exit 1
    fi
    # git clone を実行（サプライチェーンリスク軽減のためタグをピン留め）
    ZINIT_VERSION="v3.14.0"
    if command git clone --branch "$ZINIT_VERSION" --depth 1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
        print -P "%F{33} %F{34}Zinit ${ZINIT_VERSION} のインストールに成功しました。%f"
    else
        print -P "%F{160}エラー: Zinit の git clone に失敗しました。%f" >&2
        exit 1
    fi
else
    print -P "情報: Zinit は既にインストールされています。"
fi
print -P "---------------------------------------------"


# --- Zsh 設定ディレクトリの作成 ---
ZSH_BASE_DIR="${ZDOTDIR:-$HOME}"
ZSH_CONFIG_DIR="$ZSH_BASE_DIR/.zsh"
if [[ ! -d "$ZSH_CONFIG_DIR" ]]; then
    if ! command mkdir -p -m 700 "$ZSH_CONFIG_DIR"; then
        print -P "%F{160}エラー: $ZSH_CONFIG_DIR の作成に失敗しました。%f" >&2
        exit 1
    fi
    print -P "情報: $ZSH_CONFIG_DIR を作成しました。"
else
    print -P "情報: $ZSH_CONFIG_DIR は既に存在します。"
fi
print -P "---------------------------------------------"


# --- 設定ファイルの配置 ---
print -P "設定ファイルを配置します..."
# スクリプト自身のディレクトリを取得
SCRIPT_DIR="${0:a:h}"

# バックアップ用タイムスタンプ
BACKUP_SUFFIX=".backup.$(command date +%Y%m%d%H%M%S)"

# .zshrc の配置（ZDOTDIR が設定されている場合はそちらに配置）
ZSHRC_DEST="$ZSH_BASE_DIR/.zshrc"
if [[ ! -f "$SCRIPT_DIR/.zshrc" ]]; then
    print -P "%F{160}エラー: 配布元の .zshrc が見つかりません: $SCRIPT_DIR/.zshrc%f" >&2
    exit 1
fi
# シンボリックリンクの場合もバックアップ対象（-h でリンク自体を検出）
if [[ -f "$ZSHRC_DEST" || -h "$ZSHRC_DEST" ]]; then
    if ! command mv "$ZSHRC_DEST" "${ZSHRC_DEST}${BACKUP_SUFFIX}"; then
        print -P "%F{160}エラー: .zshrc のバックアップに失敗しました。%f" >&2
        exit 1
    fi
    print -P "情報: 既存の .zshrc を ${ZSHRC_DEST}${BACKUP_SUFFIX} にバックアップしました。"
fi
if ! command cp -p "$SCRIPT_DIR/.zshrc" "$ZSHRC_DEST"; then
    print -P "%F{160}エラー: .zshrc の配置に失敗しました。%f" >&2
    exit 1
fi
print -P "情報: .zshrc を $ZSHRC_DEST に配置しました。"

# 共通: 設定ファイルのバックアップと配置を行うヘルパー
# 引数: $1=配布元パス $2=配置先パス $3=表示名 $4=未検出時の補足メッセージ
install_config() {
    local src="$1" dst="$2" label="$3" missing_hint="$4"
    if [[ -f "$src" ]]; then
        # シンボリックリンクの場合もバックアップ対象（-h でリンク自体を検出）
        if [[ -f "$dst" || -h "$dst" ]]; then
            if ! command mv "$dst" "${dst}${BACKUP_SUFFIX}"; then
                print -P "%F{160}エラー: ${label} のバックアップに失敗しました。%f" >&2
                exit 1
            fi
            print -P "情報: 既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップしました。"
        fi
        if ! command cp -p "$src" "$dst"; then
            print -P "%F{160}エラー: ${label} の配置に失敗しました。%f" >&2
            exit 1
        fi
        print -P "情報: ${label} を配置しました。"
    else
        print -P "%F{220}警告: ${label} が見つかりません。${missing_hint}%f"
    fi
}

install_config "$SCRIPT_DIR/.zsh/.p10k.zsh"   "$ZSH_CONFIG_DIR/.p10k.zsh"   ".p10k.zsh"   "Powerlevel10k のデフォルト設定が使用されます。"
install_config "$SCRIPT_DIR/.zsh/plugins.zsh"  "$ZSH_CONFIG_DIR/plugins.zsh" "plugins.zsh" "プラグインは手動で設定してください。"
install_config "$SCRIPT_DIR/.zsh/aliases.zsh"  "$ZSH_CONFIG_DIR/aliases.zsh" "aliases.zsh" "エイリアスは手動で設定してください。"
print -P "---------------------------------------------"


# --- 完了 ---
print -P "%F{34}セットアップスクリプトが正常に完了しました。%f"
print -P "全ての変更を有効にするために、Zsh シェルを%B再起動%bするか '%Bexec zsh%b' を実行してください。"
print -P "(source ~/.zshrc は環境が汚れる場合があるため、exec zsh を推奨します)"
print -P "---------------------------------------------"

exit 0

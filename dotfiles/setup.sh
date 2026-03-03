#!/usr/bin/env zsh

# ---------------------------------------------
# Zsh 環境セットアップスクリプト
# - 依存コマンドの確認 (git)
# - Zinit (プラグインマネージャー) のインストール
# - 設定ディレクトリの作成 (~/.zsh)
# - 設定ファイルの配置 (.zshrc, .p10k.zsh)
# ---------------------------------------------

echo "Zsh環境のセットアップを開始します..."
echo "---------------------------------------------"

# --- Zsh実行確認 ---
if [ -z "$ZSH_VERSION" ]; then
    echo "エラー: このスクリプトは Zsh で実行する必要があります。" >&2
    echo "実行例: zsh $0" >&2
    exit 1
fi
echo "情報: Zsh で実行されています (バージョン: $ZSH_VERSION)"
echo "---------------------------------------------"


# --- 依存コマンドの確認 ---
if ! command -v git >/dev/null 2>&1; then
    print -P "%F{160}エラー: git コマンドが見つかりません。インストールしてください。%f" >&2
    exit 1
fi
echo "情報: git が利用可能です ($(git --version))"
echo "---------------------------------------------"


# --- Zinit (プラグインマネージャー) のインストール ---
echo "Zinit の状態を確認・インストールします..."
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
    echo "情報: Zinit は既にインストールされています。"
fi
echo "---------------------------------------------"


# --- Zsh 設定ディレクトリの作成 ---
ZSH_CONFIG_DIR="$HOME/.zsh"
if [[ ! -d "$ZSH_CONFIG_DIR" ]]; then
    if ! command mkdir -p -m 700 "$ZSH_CONFIG_DIR"; then
        print -P "%F{160}エラー: $ZSH_CONFIG_DIR の作成に失敗しました。%f" >&2
        exit 1
    fi
    echo "情報: $ZSH_CONFIG_DIR を作成しました。"
else
    echo "情報: $ZSH_CONFIG_DIR は既に存在します。"
fi
echo "---------------------------------------------"


# --- 設定ファイルの配置 ---
echo "設定ファイルを配置します..."
# スクリプト自身のディレクトリを取得
SCRIPT_DIR="${0:a:h}"

# バックアップ用タイムスタンプ
BACKUP_SUFFIX=".backup.$(date +%Y%m%d%H%M%S)"

# .zshrc の配置
if [[ ! -f "$SCRIPT_DIR/.zshrc" ]]; then
    print -P "%F{160}エラー: 配布元の .zshrc が見つかりません: $SCRIPT_DIR/.zshrc%f" >&2
    exit 1
fi
if [[ -f "$HOME/.zshrc" ]]; then
    if ! cp -p "$HOME/.zshrc" "$HOME/.zshrc${BACKUP_SUFFIX}"; then
        print -P "%F{160}エラー: .zshrc のバックアップに失敗しました。%f" >&2
        exit 1
    fi
    echo "情報: 既存の .zshrc を .zshrc${BACKUP_SUFFIX} にバックアップしました。"
fi
if ! cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"; then
    print -P "%F{160}エラー: .zshrc の配置に失敗しました。%f" >&2
    exit 1
fi
echo "情報: .zshrc を配置しました。"

# .p10k.zsh の配置
if [[ -f "$SCRIPT_DIR/.zsh/.p10k.zsh" ]]; then
    if [[ -f "$ZSH_CONFIG_DIR/.p10k.zsh" ]]; then
        if ! cp -p "$ZSH_CONFIG_DIR/.p10k.zsh" "$ZSH_CONFIG_DIR/.p10k.zsh${BACKUP_SUFFIX}"; then
            print -P "%F{160}エラー: .p10k.zsh のバックアップに失敗しました。%f" >&2
            exit 1
        fi
        echo "情報: 既存の .p10k.zsh を .p10k.zsh${BACKUP_SUFFIX} にバックアップしました。"
    fi
    if ! cp "$SCRIPT_DIR/.zsh/.p10k.zsh" "$ZSH_CONFIG_DIR/.p10k.zsh"; then
        print -P "%F{160}エラー: .p10k.zsh の配置に失敗しました。%f" >&2
        exit 1
    fi
    echo "情報: .p10k.zsh を配置しました。"
else
    print -P "%F{220}警告: .p10k.zsh が見つかりません。Powerlevel10k のデフォルト設定が使用されます。%f"
fi
echo "---------------------------------------------"


# --- 完了 ---
echo "セットアップスクリプトが正常に完了しました。"
echo "全ての変更を有効にするために、Zsh シェルを**再起動**するか 'source ~/.zshrc' を実行してください。"
echo "(特に PATH の変更は再起動が確実です)"
echo "---------------------------------------------"

exit 0
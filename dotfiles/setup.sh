#!/usr/bin/env zsh

# ---------------------------------------------
# Zsh, Zinit, pipx, trash-cli セットアップスクリプト
# ---------------------------------------------

echo "Zsh環境のセットアップを開始します..."
echo "---------------------------------------------"

# --- Zsh実行確認 ---
if [[ -z "$ZSH_VERSION" ]]; then
    echo "エラー: このスクリプトは Zsh で実行する必要があります。" >&2
    echo "実行例: zsh $0" >&2
    exit 1
fi
echo "情報: Zsh で実行されています (バージョン: $ZSH_VERSION)"
echo "---------------------------------------------"


# --- Zinit (プラグインマネージャー) のインストール ---
echo "Zinit の状態を確認・インストールします..."
ZINIT_DIR="$HOME/.local/share/zinit/zinit.git"
if [[ ! -f "$ZINIT_DIR/zinit.zsh" ]]; then
    print -P "%F{33} %F{220}Zinit (%F{33}zdharma-continuum/zinit%F{220}) をインストール中...%f"
    # ディレクトリ作成と権限設定
    if ! command mkdir -p "$(dirname "$ZINIT_DIR")"; then
        print -P "%F{160}エラー: Zinit 用ディレクトリの作成に失敗しました。%f%b" >&2
        exit 1
    fi
    # git clone を実行
    if command git clone https://github.com/zdharma-continuum/zinit "$ZINIT_DIR"; then
        print -P "%F{33} %F{34}Zinit のインストールに成功しました。%f%b"
    else
        print -P "%F{160}エラー: Zinit の git clone に失敗しました。%f%b" >&2
        exit 1
    fi
else
    echo "情報: Zinit は既にインストールされています。"
fi
echo "---------------------------------------------"


# --- 完了 ---
echo "セットアップスクリプトが正常に完了しました。"
echo "全ての変更を有効にするために、Zsh シェルを**再起動**するか 'source ~/.zshrc' を実行してください。"
echo "(特に PATH の変更は再起動が確実です)"
echo "---------------------------------------------"

exit 0
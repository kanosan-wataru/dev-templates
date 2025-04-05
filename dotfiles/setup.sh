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


# --- pipx (Python CLIツールマネージャー) のインストール ---
echo "pipx の状態を確認・インストールします..."
if ! command -v pipx &> /dev/null; then
    echo "情報: pipx が見つかりません。pip を使用してインストールを試みます..."
    # Pythonとpipの存在確認
    if ! command -v python3 &> /dev/null; then
        echo "エラー: python3 が見つかりません。pipx をインストールできません。" >&2
        exit 1
    fi
    if ! python3 -m pip --version &> /dev/null; then
        echo "エラー: pip (python3 -m pip) が利用できません。'python3-pip' パッケージ等を確認してください。" >&2
        exit 1
    fi

    # pipxのインストール試行
    echo "情報: pip を使用して pipx をユーザー環境にインストールします..."
    if python3 -m pip install --user --upgrade pipx; then # --upgrade を追加
        echo "情報: pipx のインストール/アップグレードに成功しました。"

        # ensurepath の実行試行
        echo "情報: PATH設定のため 'pipx ensurepath' を実行します..."
        _pipx_cmd_path=$(python3 -m site --user-base)/bin/pipx
        if [[ ! -x "$_pipx_cmd_path" ]]; then _pipx_cmd_path="$HOME/.local/bin/pipx"; fi

        if [[ -x "$_pipx_cmd_path" ]]; then
            if "$_pipx_cmd_path" ensurepath; then
                echo "情報: 'pipx ensurepath' が完了しました。出力内容を確認してください。"
                echo "      シェルを再起動するか 'source ~/.zshrc' の実行が必要な場合があります。"
            else
                echo "警告: 'pipx ensurepath' コマンドの実行に失敗したか、手動操作が必要な可能性があります。" >&2
                # ensurepath の失敗は致命的ではない場合もあるので、ここでは exit しない
            fi
        else
            echo "警告: インストールされた pipx のパスを特定できませんでした。手動で 'pipx ensurepath' を実行してください。" >&2
        fi
    else
        echo "エラー: pip を使用した pipx のインストールに失敗しました。" >&2
        exit 1
    fi
else
    echo "情報: pipx は既にインストールされています。"
fi
echo "---------------------------------------------"


# --- trash-cli のインストール (pipxを使用) ---
echo "trash-cli の状態を確認・インストールします..."
# まずpipxが利用可能か再確認
if ! command -v pipx &> /dev/null; then
    echo "警告: pipx コマンドが見つからないため、trash-cli のインストールをスキップします。" >&2
else
    # trash-put コマンドが存在しない場合のみインストールを試みる
    if ! command -v trash-put &> /dev/null; then
        echo "情報: trash-cli (trash-put) が見つかりません。pipx を使用してインストールを試みます..."
        if pipx install trash-cli; then
            echo "情報: pipx を使用して trash-cli のインストールに成功しました。"
            # インストール直後の確認
            if ! command -v trash-put &> /dev/null; then
                echo "警告: インストール直後に trash-put コマンドがまだ見つかりません。シェル再起動後に確認してください。" >&2
            fi
        else
            echo "エラー: pipx を使用した trash-cli のインストールに失敗しました。" >&2
            exit 1 # trash-cliのインストール失敗はエラーとして終了
        fi
    else
        echo "情報: trash-cli (trash-put コマンド) は既に利用可能なようです。"
    fi
fi
echo "---------------------------------------------"


# --- 完了 ---
echo "セットアップスクリプトが正常に完了しました。"
echo "全ての変更を有効にするために、Zsh シェルを**再起動**するか 'source ~/.zshrc' を実行してください。"
echo "(特に PATH の変更は再起動が確実です)"
echo "---------------------------------------------"

exit 0
# ---------------------------------------------
# モジュール: Python 開発環境
# pyenv + pyenv-virtualenv (Python バージョン管理)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="python"
MODULE_NAME="Python 開発環境"
MODULE_DESC="pyenv + virtualenv (Python バージョン管理)"
MODULE_DEFAULT=0
MODULE_ORDER=25

# NOTE: モジュール固有の変数には衝突回避のため PY_MOD_ プレフィックスを使用

PY_MOD_PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
PY_MOD_PYENV_REPO="https://github.com/pyenv/pyenv.git"
PY_MOD_VIRTUALENV_REPO="https://github.com/pyenv/pyenv-virtualenv.git"

# Ubuntu/Debian 向けビルド依存パッケージ
PY_MOD_DEPS=(
    build-essential
    libssl-dev
    zlib1g-dev
    libbz2-dev
    libreadline-dev
    libsqlite3-dev
    curl
    git
    libncursesw5-dev
    xz-utils
    tk-dev
    libxml2-dev
    libxmlsec1-dev
    libffi-dev
    liblzma-dev
)

# 管理対象ファイル（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
PY_MOD_MANAGED_FILES=(
    "$SCRIPT_DIR/.zsh/python.zsh|${ZDOTDIR:-$HOME}/.zsh/python.zsh|python.zsh|"
)

# --- ヘルパー: OS 判定 ---
_py_detect_os() {
    case "$OSTYPE" in
        darwin*) print "macos" ;;
        linux*)  print "linux" ;;
        *)       print "unknown" ;;
    esac
}

# --- セットアップ ---
module_setup() {
    print -P ""
    print -P "%F{36}%B[Python 開発環境]%b%f"
    print -P "---------------------------------------------"

    # べき等性チェック
    if command -v pyenv >/dev/null 2>&1; then
        local current_ver
        current_ver=$(pyenv --version 2>/dev/null || print "unknown")
        print -P "情報: pyenv は既にインストールされています (${current_ver})。スキップします。"
        # 設定ファイルのみ更新確認
        _py_install_config
        return 0
    fi

    local os
    os=$(_py_detect_os)

    case "$os" in
        macos)
            _py_setup_macos
            ;;
        linux)
            _py_setup_linux
            ;;
        *)
            print -P "%F{160}エラー: 未対応の OS です (OSTYPE=${OSTYPE})。%f" >&2
            return 1
            ;;
    esac

    # 設定ファイルの配置
    _py_install_config

    if (( DRY_RUN )); then
        print -P "情報: Python 開発環境をセットアップ予定です（dry-run）。"
    else
        print -P "%F{34}Python 開発環境のセットアップが完了しました。%f"
        print -P ""
        print -P "次のステップ:"
        print -P "  exec zsh                    # シェルを再起動"
        print -P "  pyenv install 3.13.2        # Python をインストール"
        print -P "  pyenv global 3.13.2         # デフォルトバージョンを設定"
    fi
}

# --- macOS セットアップ ---
_py_setup_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        print -P "%F{160}エラー: Homebrew がインストールされていません。%f" >&2
        print -P "  インストール: https://brew.sh/" >&2
        return 1
    fi

    print -P "pyenv を Homebrew でインストールします..."
    run_cmd brew install pyenv || {
        print -P "%F{160}エラー: pyenv のインストールに失敗しました。%f" >&2
        return 1
    }

    print -P "pyenv-virtualenv を Homebrew でインストールします..."
    run_cmd brew install pyenv-virtualenv || {
        print -P "%F{220}警告: pyenv-virtualenv のインストールに失敗しました。pyenv 本体は利用可能です。%f"
    }
}

# --- Linux セットアップ ---
_py_setup_linux() {
    if ! command -v apt-get >/dev/null 2>&1; then
        print -P "%F{160}エラー: apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。%f" >&2
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        print -P "%F{160}エラー: git がインストールされていません。%f" >&2
        return 1
    fi

    # ビルド依存パッケージのインストール
    print -P "Python ビルド依存パッケージをインストールします..."
    run_cmd sudo apt-get update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。%f"
    }
    run_cmd sudo apt-get install -y "${PY_MOD_DEPS[@]}" || {
        print -P "%F{160}エラー: ビルド依存パッケージのインストールに失敗しました。%f" >&2
        return 1
    }

    # pyenv のインストール（git clone）
    if [[ -d "$PY_MOD_PYENV_ROOT" ]]; then
        print -P "情報: $PY_MOD_PYENV_ROOT は既に存在します。スキップします。"
    else
        print -P "pyenv を git clone でインストールします..."
        run_cmd git clone --depth 1 "$PY_MOD_PYENV_REPO" "$PY_MOD_PYENV_ROOT" || {
            print -P "%F{160}エラー: pyenv の git clone に失敗しました。%f" >&2
            return 1
        }
    fi

    # pyenv-virtualenv のインストール
    local virtualenv_dir="$PY_MOD_PYENV_ROOT/plugins/pyenv-virtualenv"
    if [[ -d "$virtualenv_dir" ]]; then
        print -P "情報: pyenv-virtualenv は既にインストールされています。スキップします。"
    else
        print -P "pyenv-virtualenv を git clone でインストールします..."
        run_cmd git clone --depth 1 "$PY_MOD_VIRTUALENV_REPO" "$virtualenv_dir" || {
            print -P "%F{220}警告: pyenv-virtualenv のインストールに失敗しました。pyenv 本体は利用可能です。%f"
        }
    fi
}

# --- 設定ファイル配置ヘルパー ---
_py_install_config() {
    print -P "設定ファイルを配置します..."
    for entry in "${PY_MOD_MANAGED_FILES[@]}"; do
        local src="${entry[(ws:|:)1]}"
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"
        local hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done
}

# --- アンインストール ---
module_uninstall() {
    local restored=0

    for entry in "${PY_MOD_MANAGED_FILES[@]}"; do
        local dst="${entry[(ws:|:)2]}"
        local label="${entry[(ws:|:)3]}"

        local -a latest_backup
        latest_backup=( "${dst}.backup."*(N^/om[1]) )

        if (( ${#latest_backup[@]} > 0 )); then
            print -P "復元: ${label} をバックアップ (${latest_backup[1]:t}) から戻します。"
            run_cmd command mv "${latest_backup[1]}" "$dst" || {
                print -P "%F{160}エラー: ${label} の復元に失敗しました。%f" >&2
                return 1
            }
            restored=1
        elif [[ -f "$dst" || -h "$dst" ]]; then
            print -P "削除: ${label} を削除します。"
            run_cmd command rm -f "$dst" || {
                print -P "%F{160}エラー: ${label} の削除に失敗しました。%f" >&2
                return 1
            }
            restored=1
        else
            print -P "情報: ${label} は配置されていません。スキップします。"
        fi
    done

    if (( restored )); then
        print -P "%F{34}Python 開発環境の設定を削除しました。%f"
    else
        print -P "情報: Python 開発環境の復元・削除対象はありませんでした。"
    fi

    print -P ""
    print -P "NOTE: pyenv 本体は削除されていません。不要な場合は以下を手動で削除してください:"
    print -P "  rm -rf ${PY_MOD_PYENV_ROOT}"
    if command -v brew >/dev/null 2>&1; then
        print -P "  # macOS の場合:"
        print -P "  brew uninstall pyenv pyenv-virtualenv"
    fi
}

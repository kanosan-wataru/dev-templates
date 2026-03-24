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
    "$SCRIPT_DIR/.shell/python.sh|${HOME}/.shell/python.sh|python.sh|"
)

# --- ヘルパー: OS 判定 ---
_py_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- セットアップ ---
setup_python() {
    msg_header "Python 開発環境"
    print_separator

    # べき等性チェック
    if command -v pyenv >/dev/null 2>&1; then
        local current_ver
        current_ver=$(pyenv --version 2>/dev/null || printf '%s' "unknown")
        msg_info "pyenv は既にインストールされています (${current_ver})。スキップします。"
        # 設定ファイルのみ更新確認
        _py_install_config
        return 0
    fi

    local os
    os=$(_py_detect_os)

    case "$os" in
    macos)
        _py_setup_macos || return 1
        ;;
    linux)
        _py_setup_linux || return 1
        ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac

    # 設定ファイルの配置
    _py_install_config

    if ((DRY_RUN)); then
        msg_info "Python 開発環境をセットアップ予定です（dry-run）。"
    else
        msg_success "Python 開発環境のセットアップが完了しました。"
        printf '\n'
        printf '%s\n' "次のステップ:"
        msg_step "exec zsh                    # シェルを再起動"
        msg_step "pyenv install 3.13.2        # Python をインストール"
        msg_step "pyenv global 3.13.2         # デフォルトバージョンを設定"
    fi
}

# --- macOS セットアップ ---
_py_setup_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        msg_error "Homebrew がインストールされていません。"
        msg_step "インストール: https://brew.sh/" >&2
        return 1
    fi

    msg_info "pyenv を Homebrew でインストールします..."
    run_cmd brew install pyenv || {
        msg_error "pyenv のインストールに失敗しました。"
        return 1
    }

    msg_info "pyenv-virtualenv を Homebrew でインストールします..."
    run_cmd brew install pyenv-virtualenv || {
        msg_warn "pyenv-virtualenv のインストールに失敗しました。pyenv 本体は利用可能です。"
    }
}

# --- Linux セットアップ ---
_py_setup_linux() {
    if ! command -v apt-get >/dev/null 2>&1; then
        msg_error "apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。"
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        msg_error "git がインストールされていません。"
        return 1
    fi

    # ビルド依存パッケージのインストール
    msg_info "Python ビルド依存パッケージをインストールします..."
    run_cmd sudo apt-get update -qq || {
        msg_warn "apt update に失敗しました。後続のパッケージインストールに失敗する可能性があります。"
    }
    run_cmd sudo apt-get install -y "${PY_MOD_DEPS[@]}" || {
        msg_error "ビルド依存パッケージのインストールに失敗しました。"
        return 1
    }

    # pyenv のインストール（git clone）
    if [[ -d "$PY_MOD_PYENV_ROOT" ]]; then
        # 不完全なクローンの検出（前回の git clone が途中で失敗した場合）
        if [[ ! -x "$PY_MOD_PYENV_ROOT/bin/pyenv" && ! -x "$PY_MOD_PYENV_ROOT/libexec/pyenv" ]]; then
            msg_warn "$PY_MOD_PYENV_ROOT は存在しますが不完全です。再インストールします。"
            run_cmd command rm -rf "$PY_MOD_PYENV_ROOT" || {
                msg_error "不完全な pyenv ディレクトリの削除に失敗しました。"
                msg_step "手動で削除してください: rm -rf $PY_MOD_PYENV_ROOT" >&2
                return 1
            }
        else
            msg_info "$PY_MOD_PYENV_ROOT は既に存在します。スキップします。"
        fi
    fi
    if [[ ! -d "$PY_MOD_PYENV_ROOT" ]]; then
        msg_info "pyenv を git clone でインストールします..."
        run_cmd git clone --depth 1 "$PY_MOD_PYENV_REPO" "$PY_MOD_PYENV_ROOT" || {
            msg_error "pyenv の git clone に失敗しました。"
            return 1
        }
    fi

    # pyenv-virtualenv のインストール
    local virtualenv_dir="$PY_MOD_PYENV_ROOT/plugins/pyenv-virtualenv"
    if [[ -d "$virtualenv_dir" ]]; then
        msg_info "pyenv-virtualenv は既にインストールされています。スキップします。"
    else
        msg_info "pyenv-virtualenv を git clone でインストールします..."
        run_cmd git clone --depth 1 "$PY_MOD_VIRTUALENV_REPO" "$virtualenv_dir" || {
            msg_warn "pyenv-virtualenv のインストールに失敗しました。pyenv 本体は利用可能です。"
        }
    fi
}

# --- 設定ファイル配置ヘルパー ---
_py_install_config() {
    msg_info "設定ファイルを配置します..."
    run_cmd mkdir -p "$HOME/.shell"
    for entry in "${PY_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r src dst label hint <<<"$entry"
        install_config "$src" "$dst" "$label" "$hint"
    done
}

# --- アンインストール ---
uninstall_python() {
    local restored=0

    for entry in "${PY_MOD_MANAGED_FILES[@]}"; do
        IFS='|' read -r _src dst label _hint <<<"$entry"

        local newest
        newest=$(find_newest_backup "${dst}.backup."'*') || true

        if [[ -n "$newest" ]]; then
            printf '%s\n' "復元: ${label} をバックアップ ($(basename "$newest")) から戻します。"
            run_cmd command mv "$newest" "$dst" || {
                msg_error "${label} の復元に失敗しました。"
                return 1
            }
            restored=1
        elif [[ -f "$dst" || -L "$dst" ]]; then
            printf '%s\n' "削除: ${label} を削除します。"
            run_cmd command rm -f "$dst" || {
                msg_error "${label} の削除に失敗しました。"
                return 1
            }
            restored=1
        else
            msg_info "${label} は配置されていません。スキップします。"
        fi
    done

    if ((restored)); then
        msg_success "Python 開発環境の設定を削除しました。"
    else
        msg_info "Python 開発環境の復元・削除対象はありませんでした。"
    fi

    printf '\n'
    printf '%s\n' "NOTE: pyenv 本体は削除されていません。不要な場合は以下を手動で削除してください:"
    msg_step "rm -rf ${PY_MOD_PYENV_ROOT}"
    if command -v brew >/dev/null 2>&1; then
        msg_step "# macOS の場合:"
        msg_step "brew uninstall pyenv pyenv-virtualenv"
    fi
}

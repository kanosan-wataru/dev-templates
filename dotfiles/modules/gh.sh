# ---------------------------------------------
# モジュール: GitHub CLI
# gh (GitHub CLI)
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="gh"
MODULE_NAME="GitHub CLI"
MODULE_DESC="gh (GitHub CLI)"
MODULE_DEFAULT=0
MODULE_ORDER=14

# --- ヘルパー: OS 判定 ---
_gh_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: インストール済みチェック ---
_gh_is_installed() {
    if ! command -v gh >/dev/null 2>&1; then
        return 1
    fi

    local gh_ver
    gh_ver=$(gh --version 2>/dev/null | head -1 || printf '%s' "unknown")

    if ((UPGRADE)); then
        msg_info "gh のアップグレードを実行します... (現在: ${gh_ver})"
        return 1
    fi

    msg_info "gh は既にインストールされています (${gh_ver})。スキップします。"
    return 0
}

# --- ヘルパー: Linux インストール (公式 apt リポジトリ) ---
_gh_install_linux() {
    # wget の確認とインストール
    if ! command -v wget >/dev/null 2>&1; then
        msg_step "wget をインストールします..."
        if ! command -v apt-get >/dev/null 2>&1; then
            msg_error "apt-get が見つかりません。wget を手動でインストールしてください。"
            return 1
        fi
        run_cmd sudo apt-get update -qq || {
            msg_warn "apt-get update に失敗しました。"
        }
        run_cmd sudo apt-get install -y wget || {
            msg_error "wget のインストールに失敗しました。"
            return 1
        }
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        msg_error "apt-get が見つかりません。gh を手動でインストールしてください。"
        return 1
    fi

    local keyring_dir="/etc/apt/keyrings"
    local keyring_file="${keyring_dir}/githubcli-archive-keyring.gpg"
    local sources_file="/etc/apt/sources.list.d/github-cli.list"
    local keyring_url="https://cli.github.com/packages/githubcli-archive-keyring.gpg"

    if ((DRY_RUN)); then
        msg_dry_run "sudo mkdir -p -m 755 ${keyring_dir}"
        msg_dry_run "wget -nv -O <tmpfile> ${keyring_url}"
        msg_dry_run "sudo tee ${keyring_file} < <tmpfile>"
        msg_dry_run "sudo chmod a+r ${keyring_file}"
        msg_dry_run "echo 'deb [arch=... signed-by=${keyring_file}] https://cli.github.com/packages stable main' | sudo tee ${sources_file}"
        msg_dry_run "sudo apt-get update -qq"
        msg_dry_run "sudo apt-get install -y gh"
        return 0
    fi

    # GPG キーリングディレクトリの作成
    sudo mkdir -p -m 755 "$keyring_dir" || {
        msg_error "キーリングディレクトリの作成に失敗しました。"
        return 1
    }

    # GPG 鍵のダウンロードと配置
    msg_step "GitHub CLI の GPG 鍵をダウンロードします..."
    local tmp_key
    tmp_key=$(mktemp /tmp/gh-keyring-XXXXXXXXXX.gpg) || {
        msg_error "一時ファイルの作成に失敗しました。"
        return 1
    }

    wget -nv -O "$tmp_key" "$keyring_url" || {
        msg_error "GPG 鍵のダウンロードに失敗しました。"
        rm -f "$tmp_key"
        return 1
    }

    cat "$tmp_key" | sudo tee "$keyring_file" >/dev/null || {
        msg_error "GPG 鍵の配置に失敗しました。"
        rm -f "$tmp_key"
        return 1
    }
    rm -f "$tmp_key"

    sudo chmod a+r "$keyring_file" || {
        msg_error "GPG 鍵のパーミッション設定に失敗しました。"
        return 1
    }

    # apt リポジトリの追加
    msg_step "apt リポジトリを追加します..."
    local arch
    arch=$(dpkg --print-architecture)
    echo "deb [arch=${arch} signed-by=${keyring_file}] https://cli.github.com/packages stable main" |
        sudo tee "$sources_file" >/dev/null || {
        msg_error "apt リポジトリの追加に失敗しました。"
        return 1
    }

    # インストール
    msg_step "gh をインストールします..."
    sudo apt-get update -qq || {
        msg_warn "apt-get update に失敗しました。古いパッケージインデックスのまま gh のインストールを試行します。"
    }
    sudo apt-get install -y gh || {
        msg_error "gh のインストールに失敗しました。"
        return 1
    }
}

# --- ヘルパー: macOS インストール ---
_gh_install_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        msg_error "Homebrew がインストールされていません。"
        msg_step "インストール: https://brew.sh/" >&2
        return 1
    fi

    if ((UPGRADE)); then
        msg_step "gh を Homebrew でアップグレードします..."
        run_cmd brew upgrade gh || {
            msg_warn "gh のアップグレードに失敗しました（既に最新の可能性があります）。"
        }
    else
        msg_step "gh を Homebrew でインストールします..."
        run_cmd brew install gh || {
            msg_error "gh のインストールに失敗しました。"
            return 1
        }
    fi
}

# --- ヘルパー: 認証状態チェック + ガイド表示 ---
_gh_show_auth_guide() {
    if ((DRY_RUN)); then
        msg_info "認証状態の確認は実行時に行います（dry-run）。"
        return 0
    fi

    # 認証済みチェック (output stored once to avoid duplicate calls)
    local gh_auth_output
    if gh_auth_output=$(gh auth status 2>&1); then
        local gh_user
        gh_user=$(printf '%s\n' "$gh_auth_output" | sed -n 's/.*Logged in to .* as \([^ ]*\).*/\1/p' | head -1)
        msg_info "GitHub CLI は既に認証済みです。"
        if [[ -n "$gh_user" ]]; then
            msg_step "ユーザー: ${gh_user}"
        fi
        return 0
    fi

    # 環境変数トークンチェック
    if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
        msg_info "環境変数トークンが検出されました（GH_TOKEN/GITHUB_TOKEN）。"
        return 0
    fi

    # 未認証 → ガイド表示
    printf '\n'
    msg_warn "NOTE: GitHub CLI が未認証です。以下のいずれかを実行してください:"
    msg_step "gh auth login                           # ブラウザ OAuth（推奨）"
    msg_step "gh auth login --with-token < token.txt  # トークンファイル"
    msg_step "export GH_TOKEN=<token>                 # 環境変数（CI 用）"
}

# --- セットアップ ---
setup_gh() {
    msg_header "GitHub CLI"
    print_separator

    # べき等性チェック
    if _gh_is_installed; then
        _gh_show_auth_guide
        return 0
    fi

    local os
    os=$(_gh_detect_os)

    case "$os" in
    linux) msg_info "環境を検出しました — Linux" ;;
    macos) msg_info "環境を検出しました — macOS" ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac

    # インストール
    msg_info "gh をインストールします..."
    case "$os" in
    linux)
        _gh_install_linux || return 1
        ;;
    macos)
        _gh_install_macos || return 1
        ;;
    esac

    # インストールの確認
    if ((!DRY_RUN)); then
        if command -v gh >/dev/null 2>&1; then
            local installed_ver
            installed_ver=$(gh --version 2>/dev/null | head -1 || printf '%s' "unknown")
            msg_success "gh のインストールが完了しました (${installed_ver})。"
        else
            msg_error "gh のインストール後にコマンドが見つかりません。"
            return 1
        fi
    fi

    # 認証ガイド
    _gh_show_auth_guide

    if ((DRY_RUN)); then
        msg_info "GitHub CLI をセットアップ予定です（dry-run）。"
    else
        msg_success "GitHub CLI のセットアップが完了しました。"
    fi
}

# --- ステータス表示 ---
module_status() {
    if command -v gh &>/dev/null; then
        local version
        version=$(gh --version 2>/dev/null | head -1)
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_gh() {
    local os
    os=$(_gh_detect_os)

    case "$os" in
    linux)
        msg_info "gh の手動アンインストール手順:"
        printf '\n'
        msg_step "sudo apt-get remove -y gh"
        msg_step "sudo rm /etc/apt/sources.list.d/github-cli.list"
        msg_step "sudo rm /etc/apt/keyrings/githubcli-archive-keyring.gpg"
        ;;
    macos)
        msg_info "gh の手動アンインストール手順:"
        printf '\n'
        msg_step "brew uninstall gh"
        ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac
}

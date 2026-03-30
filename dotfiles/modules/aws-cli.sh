# ---------------------------------------------
# モジュール: AWS CLI
# AWS Command Line Interface v2
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="aws-cli"
MODULE_NAME="AWS CLI"
MODULE_DESC="AWS Command Line Interface v2"
MODULE_DEFAULT=0
MODULE_ORDER=22

# --- ヘルパー: OS 判定 ---
_aws_detect_os() {
    case "$OSTYPE" in
    darwin*) printf '%s' "macos" ;;
    linux*) printf '%s' "linux" ;;
    *) printf '%s' "unknown" ;;
    esac
}

# --- ヘルパー: AWS CLI がインストール済みか確認 ---
_aws_is_installed() {
    if ! command -v aws >/dev/null 2>&1; then
        return 1
    fi

    local aws_ver
    aws_ver=$(aws --version 2>/dev/null || printf '%s' "unknown")

    # When UPGRADE=1, do not skip — proceed to upgrade
    if ((UPGRADE)); then
        msg_info "AWS CLI のアップグレードを実行します... (現在: ${aws_ver})"
        return 1
    fi

    msg_info "AWS CLI は既にインストールされています (${aws_ver})。スキップします。"
    return 0
}

# --- ヘルパー: Linux インストール ---
_aws_install_linux() {
    msg_step "AWS CLI v2 を Linux にインストールします..."

    # unzip の確認とインストール
    if ! command -v unzip >/dev/null 2>&1; then
        msg_step "unzip をインストールします..."
        if ! command -v apt-get >/dev/null 2>&1; then
            msg_error "apt-get が見つかりません。unzip を手動でインストールしてください。"
            return 1
        fi
        run_cmd sudo apt-get update -qq || {
            msg_warn "apt update に失敗しました。"
        }
        run_cmd sudo apt-get install -y unzip || {
            msg_error "unzip のインストールに失敗しました。"
            return 1
        }
    fi

    # curl の確認
    if ! command -v curl >/dev/null 2>&1; then
        msg_error "curl がインストールされていません。"
        return 1
    fi

    # アーキテクチャの検出
    local arch
    arch=$(uname -m)
    msg_step "アーキテクチャを検出しました: ${arch}"

    # ダウンロード
    local download_url="https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"
    msg_step "AWS CLI v2 をダウンロードします..."

    # Determine install flags (--update for upgrade)
    local install_flags=""
    if ((UPGRADE)); then
        install_flags="--update"
    fi

    if ((DRY_RUN)); then
        msg_dry_run "curl -fsSL ${download_url} -o /tmp/awscliv2.zip"
        msg_dry_run "unzip -q -o /tmp/awscliv2.zip -d /tmp"
        msg_dry_run "sudo /tmp/aws/install ${install_flags}"
        msg_dry_run "rm -rf /tmp/awscliv2.zip /tmp/aws"
        return 0
    fi

    curl -fsSL "$download_url" -o /tmp/awscliv2.zip || {
        msg_error "AWS CLI v2 のダウンロードに失敗しました。"
        return 1
    }

    # 展開とインストール
    msg_step "AWS CLI v2 をインストールします..."
    unzip -q -o /tmp/awscliv2.zip -d /tmp || {
        msg_error "AWS CLI v2 の展開に失敗しました。"
        rm -f /tmp/awscliv2.zip
        return 1
    }

    # shellcheck disable=SC2086
    sudo /tmp/aws/install ${install_flags} || {
        msg_error "AWS CLI v2 のインストールに失敗しました。"
        rm -rf /tmp/awscliv2.zip /tmp/aws
        return 1
    }

    # クリーンアップ
    rm -rf /tmp/awscliv2.zip /tmp/aws
}

# --- ヘルパー: macOS インストール ---
_aws_install_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        msg_error "Homebrew がインストールされていません。"
        msg_step "インストール: https://brew.sh/" >&2
        return 1
    fi

    if ((UPGRADE)); then
        msg_step "AWS CLI v2 を Homebrew でアップグレードします..."
        run_cmd brew upgrade awscli || {
            msg_warn "AWS CLI v2 のアップグレードに失敗しました（既に最新の可能性があります）。"
        }
    else
        msg_step "AWS CLI v2 を Homebrew でインストールします..."
        run_cmd brew install awscli || {
            msg_error "AWS CLI v2 のインストールに失敗しました。"
            return 1
        }
    fi
}

# --- セットアップ ---
setup_aws_cli() {
    msg_header "AWS CLI"
    print_separator

    # べき等性チェック
    if _aws_is_installed; then
        return 0
    fi

    local os
    os=$(_aws_detect_os)

    case "$os" in
    linux) msg_info "環境を検出しました — Linux" ;;
    macos) msg_info "環境を検出しました — macOS" ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac

    # インストール
    msg_info "AWS CLI v2 をインストールします..."
    case "$os" in
    linux)
        _aws_install_linux || return 1
        ;;
    macos)
        _aws_install_macos || return 1
        ;;
    esac

    # インストールの確認
    if ((!DRY_RUN)); then
        if command -v aws >/dev/null 2>&1; then
            local installed_ver
            installed_ver=$(aws --version 2>/dev/null || printf '%s' "unknown")
            msg_step "$(printf '%s%s%s' "${C_GREEN}" "AWS CLI v2 のインストールが完了しました (${installed_ver})。" "${C_RESET}")"
        else
            msg_error "AWS CLI v2 のインストール後にコマンドが見つかりません。"
            return 1
        fi
    fi

    # 完了メッセージ
    printf '\n'
    if ((DRY_RUN)); then
        msg_info "AWS CLI v2 をセットアップ予定です（dry-run）。"
    else
        msg_success "AWS CLI v2 のセットアップが完了しました。"
        printf '\n'
        printf '%s\n' "次のステップ:"
        msg_step "aws configure              # AWS 認証情報の設定"
        msg_step "aws sts get-caller-identity # 設定の確認"
    fi
}

# --- ステータス表示 ---
module_status() {
    if command -v aws &>/dev/null; then
        local version
        version=$(aws --version 2>/dev/null | head -1)
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_GREEN}" "✓ installed" "${C_RESET}" "$version"
    else
        printf '  %-14s %s%-18s%s %s\n' "$MODULE_ID" "${C_RED}" "✗ not found" "${C_RESET}" "-"
    fi
}

# --- アンインストール ---
uninstall_aws_cli() {
    local os
    os=$(_aws_detect_os)

    case "$os" in
    linux)
        msg_info "AWS CLI v2 の手動アンインストール手順:"
        printf '\n'
        msg_step "sudo rm -rf /usr/local/aws-cli"
        msg_step "sudo rm /usr/local/bin/aws /usr/local/bin/aws_completer"
        ;;
    macos)
        msg_info "AWS CLI v2 の手動アンインストール手順:"
        printf '\n'
        msg_step "brew uninstall awscli"
        ;;
    *)
        msg_error "未対応の OS です (OSTYPE=${OSTYPE})。"
        return 1
        ;;
    esac
}

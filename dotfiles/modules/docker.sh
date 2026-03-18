# ---------------------------------------------
# モジュール: Docker
# Docker Engine + Compose
# ---------------------------------------------

# --- メタデータ ---
MODULE_ID="docker"
MODULE_NAME="Docker"
MODULE_DESC="Docker Engine + Compose"
MODULE_DEFAULT=0
MODULE_ORDER=19

# NOTE: モジュール固有の変数には衝突回避のため DOCKER_MOD_ プレフィックスを使用

DOCKER_MOD_APT_SOURCE="/etc/apt/sources.list.d/docker.sources"
DOCKER_MOD_GPG_KEY="/etc/apt/keyrings/docker.asc"
DOCKER_MOD_APT_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

# --- ヘルパー: 環境判定 ---
# 戻り値: "macos" / "linux" / "unknown"
_docker_detect_env() {
    case "$OSTYPE" in
        darwin*) print "macos" ;;
        linux*)  print "linux" ;;
        *)       print "unknown" ;;
    esac
}

# --- ヘルパー: Docker がインストール済みか確認 ---
# 戻り値: Docker と Compose プラグインの両方がインストール済みなら 0、それ以外は 1
_docker_is_installed() {
    if ! command -v docker >/dev/null 2>&1; then
        return 1
    fi

    # Docker バイナリは存在する; Compose プラグインを確認
    if ! docker compose version >/dev/null 2>&1; then
        print -P "%F{220}警告: Docker はインストールされていますが、Compose プラグインが見つかりません。再インストールします。%f"
        return 1
    fi

    local docker_ver compose_ver
    docker_ver=$(docker --version 2>/dev/null || print "unknown")
    compose_ver=$(docker compose version 2>/dev/null || print "unknown")
    print -P "情報: Docker は既にインストールされています (${docker_ver}, ${compose_ver})。スキップします。"
    return 0
}

# --- ヘルパー: Docker Engine の apt インストール (Ubuntu/Debian) ---
_docker_install_apt() {
    print -P "  Docker Engine を apt でインストールします..."

    # ディストリビューションを検出 (ubuntu または debian)
    local distro
    distro=$(. /etc/os-release && echo "$ID")
    case "$distro" in
        ubuntu|debian) ;;
        *)
            print -P "%F{160}エラー: 未対応のディストリビューションです (${distro})。Ubuntu または Debian が必要です。%f" >&2
            return 1
            ;;
    esac

    # ステップ 1: 競合する旧パッケージの削除
    if (( ! DRY_RUN )); then
        local -a old_pkgs
        old_pkgs=($(dpkg --get-selections \
            docker.io docker-compose docker-compose-v2 \
            docker-doc podman-docker containerd runc \
            2>/dev/null | cut -f1))
        if (( ${#old_pkgs[@]} > 0 )); then
            print -P "  競合する旧パッケージを削除します: ${old_pkgs[*]}"
            run_cmd sudo apt-get remove -y "${old_pkgs[@]}" 2>/dev/null || true
        fi
    else
        print -P "%F{242}  [DRY-RUN] sudo apt-get remove (conflicting packages)%f"
    fi

    # ステップ 2: 前提パッケージのインストール
    run_cmd sudo apt-get update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。%f"
    }
    run_cmd sudo apt-get install -y ca-certificates curl || {
        print -P "%F{160}エラー: 前提パッケージのインストールに失敗しました。%f" >&2
        return 1
    }

    # ステップ 3: Docker GPG キーの追加
    run_cmd sudo install -m 0755 -d /etc/apt/keyrings || {
        print -P "%F{160}エラー: /etc/apt/keyrings の作成に失敗しました。%f" >&2
        return 1
    }

    if (( ! DRY_RUN )); then
        sudo curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
            -o "$DOCKER_MOD_GPG_KEY" || {
            print -P "%F{160}エラー: Docker の GPG キー取得に失敗しました。%f" >&2
            return 1
        }
        sudo chmod a+r "$DOCKER_MOD_GPG_KEY" || {
            print -P "%F{160}エラー: GPG キーのパーミッション設定に失敗しました。%f" >&2
            return 1
        }
    else
        print -P "%F{242}  [DRY-RUN] curl -fsSL https://download.docker.com/linux/${distro}/gpg -o ${DOCKER_MOD_GPG_KEY}%f"
    fi

    # ステップ 4: Docker APT リポジトリの追加 (DEB822 形式)
    if (( ! DRY_RUN )); then
        local codename
        codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
        if [[ -z "$codename" ]]; then
            print -P "%F{160}エラー: Ubuntu/Debian のコードネームを検出できませんでした。%f" >&2
            return 1
        fi

        local sources_content="Types: deb
URIs: https://download.docker.com/linux/${distro}
Suites: ${codename}
Components: stable
Signed-By: ${DOCKER_MOD_GPG_KEY}"

        print "$sources_content" | sudo tee "$DOCKER_MOD_APT_SOURCE" >/dev/null || {
            print -P "%F{160}エラー: Docker の apt ソース追加に失敗しました。%f" >&2
            return 1
        }
    else
        print -P "%F{242}  [DRY-RUN] sudo tee ${DOCKER_MOD_APT_SOURCE} (DEB822 format)%f"
    fi

    # ステップ 5: Docker Engine + Compose プラグインのインストール
    run_cmd sudo apt-get update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。%f"
    }
    run_cmd sudo apt-get install -y "${DOCKER_MOD_APT_PACKAGES[@]}" || {
        print -P "%F{160}エラー: Docker Engine のインストールに失敗しました。%f" >&2
        return 1
    }
}

# --- ヘルパー: Docker Desktop の Homebrew インストール (macOS) ---
_docker_install_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        print -P "%F{160}エラー: Homebrew がインストールされていません。%f" >&2
        print -P "  インストール: https://brew.sh/" >&2
        return 1
    fi

    print -P "  Docker Desktop を Homebrew でインストールします..."
    run_cmd brew install --cask docker || {
        print -P "%F{160}エラー: Docker Desktop のインストールに失敗しました。%f" >&2
        return 1
    }
}

# --- ヘルパー: Docker グループ設定 + systemd 自動起動 (Linux のみ) ---
_docker_setup_group() {
    # NOTE: sudo 実行時に $USER が "root" になるため、実際の呼び出しユーザーを解決
    local target_user="${SUDO_USER:-$(id -un)}"

    print -P ""
    print -P "Docker グループ設定:"

    # docker グループの作成（べき等: -f により既存でもエラーにならない）
    run_cmd sudo groupadd -f docker || {
        print -P "%F{160}エラー: docker グループの作成に失敗しました。%f" >&2
        return 1
    }

    # 現在のユーザーを docker グループに追加
    if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
        print -P "  情報: ユーザー ${target_user} は既に docker グループに所属しています。"
    else
        run_cmd sudo usermod -aG docker "$target_user" || {
            print -P "%F{160}エラー: ユーザーの docker グループ追加に失敗しました。%f" >&2
            return 1
        }
        print -P "  %F{220}NOTE: docker グループの変更を反映するには再ログインが必要です。%f"
    fi

    # systemd による自動起動の有効化（利用可能な場合）
    if command -v systemctl >/dev/null 2>&1; then
        print -P ""
        print -P "systemd サービスの有効化:"
        run_cmd sudo systemctl enable docker.service || {
            print -P "%F{220}警告: docker.service の有効化に失敗しました。%f"
        }
        run_cmd sudo systemctl enable containerd.service || {
            print -P "%F{220}警告: containerd.service の有効化に失敗しました。%f"
        }
    else
        print -P "  %F{220}NOTE: systemctl が見つかりません。Docker の自動起動は手動で設定してください。%f"
    fi
}

# --- セットアップ ---
setup_docker() {
    print -P ""
    print -P "%F{36}%B[Docker]%b%f"
    print -P "---------------------------------------------"

    local env
    env=$(_docker_detect_env)

    case "$env" in
        linux)  print -P "情報: 環境を検出しました — Linux" ;;
        macos)  print -P "情報: 環境を検出しました — macOS" ;;
        *)
            print -P "%F{160}エラー: 未対応の OS です (OSTYPE=${OSTYPE})。%f" >&2
            return 1
            ;;
    esac

    # --- 1. Docker のインストール（べき等） ---
    if _docker_is_installed; then
        # インストール済み; インストールをスキップ
        :
    else
        print -P "Docker をインストールします..."
        case "$env" in
            linux)
                if ! command -v apt-get >/dev/null 2>&1; then
                    print -P "%F{160}エラー: apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。%f" >&2
                    return 1
                fi
                _docker_install_apt || return 1
                ;;
            macos)
                _docker_install_macos || return 1
                ;;
        esac

        # インストールの確認
        if (( ! DRY_RUN )); then
            if command -v docker >/dev/null 2>&1; then
                print -P "  %F{34}Docker のインストールが完了しました ($(docker --version 2>/dev/null))。%f"
            else
                print -P "%F{160}エラー: Docker のインストール後にコマンドが見つかりません。%f" >&2
                return 1
            fi
        fi
    fi

    # --- 2. Docker グループ + systemd (Linux のみ) ---
    if [[ "$env" == "linux" ]]; then
        _docker_setup_group || return 1
    fi

    # --- 完了メッセージ ---
    print -P ""
    if (( DRY_RUN )); then
        print -P "情報: Docker セットアップ予定です（dry-run）。"
    else
        print -P "%F{34}Docker のセットアップが完了しました。%f"
        if command -v docker >/dev/null 2>&1; then
            print -P "  Docker: $(docker --version 2>/dev/null || print 'N/A')"
            # Compose バージョンの表示（利用可能な場合）
            local compose_ver
            compose_ver=$(docker compose version 2>/dev/null || true)
            [[ -n "$compose_ver" ]] && print -P "  Compose: ${compose_ver}"
        fi
    fi

    if [[ "$env" == "macos" ]]; then
        print -P ""
        print -P "NOTE: Docker Desktop を起動してセットアップを完了してください。"
    fi
}

# --- アンインストール ---
uninstall_docker() {
    local env
    env=$(_docker_detect_env)

    case "$env" in
        linux)
            if ! command -v apt-get >/dev/null 2>&1; then
                print -P "%F{160}エラー: apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。%f" >&2
                return 1
            fi
            print -P "Docker Engine を削除します..."

            # Docker パッケージの削除
            run_cmd sudo apt-get purge -y "${DOCKER_MOD_APT_PACKAGES[@]}" docker-ce-rootless-extras 2>/dev/null || {
                print -P "%F{220}警告: Docker パッケージの削除に失敗しました（既に削除済みの可能性があります）。%f"
            }

            run_cmd sudo apt-get autoremove -y 2>/dev/null || true

            # APT ソースと GPG キーの削除
            if [[ -f "$DOCKER_MOD_APT_SOURCE" ]]; then
                run_cmd sudo rm -f "$DOCKER_MOD_APT_SOURCE" || {
                    print -P "%F{220}警告: ${DOCKER_MOD_APT_SOURCE} の削除に失敗しました。%f"
                }
            fi

            if [[ -f "$DOCKER_MOD_GPG_KEY" ]]; then
                run_cmd sudo rm -f "$DOCKER_MOD_GPG_KEY" || {
                    print -P "%F{220}警告: ${DOCKER_MOD_GPG_KEY} の削除に失敗しました。%f"
                }
            fi

            print -P "%F{34}Docker Engine のアンインストールが完了しました。%f"
            print -P ""
            print -P "NOTE: Docker のデータ（イメージ、コンテナ、ボリューム等）は残っています。"
            print -P "  完全に削除する場合:"
            print -P "    sudo rm -rf /var/lib/docker"
            print -P "    sudo rm -rf /var/lib/containerd"
            ;;
        macos)
            print -P "Docker Desktop を削除します..."
            if ! command -v brew >/dev/null 2>&1; then
                print -P "%F{160}エラー: Homebrew が見つかりません。手動で削除してください。%f" >&2
                return 1
            fi

            run_cmd brew uninstall --cask docker || {
                print -P "%F{220}警告: Docker Desktop の削除に失敗しました（既に削除済みの可能性があります）。%f"
            }

            print -P "%F{34}Docker Desktop のアンインストールが完了しました。%f"
            ;;
        *)
            print -P "%F{160}エラー: 未対応の OS です (OSTYPE=${OSTYPE})。%f" >&2
            return 1
            ;;
    esac
}

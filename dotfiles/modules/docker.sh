# ---------------------------------------------
# Module: Docker
# Docker Engine + Compose
# ---------------------------------------------

# --- Metadata ---
MODULE_ID="docker"
MODULE_NAME="Docker"
MODULE_DESC="Docker Engine + Compose"
MODULE_DEFAULT=0
MODULE_ORDER=19

# NOTE: Module-specific variables use DOCKER_MOD_ prefix to avoid collisions

DOCKER_MOD_APT_SOURCE="/etc/apt/sources.list.d/docker.sources"
DOCKER_MOD_GPG_KEY="/etc/apt/keyrings/docker.asc"
DOCKER_MOD_APT_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

# --- Helper: Environment detection ---
# Returns: "macos" / "linux" / "unknown"
_docker_detect_env() {
    case "$OSTYPE" in
        darwin*) print "macos" ;;
        linux*)  print "linux" ;;
        *)       print "unknown" ;;
    esac
}

# --- Helper: Check if Docker is already installed ---
# Returns 0 if both Docker and Compose plugin are installed, 1 otherwise
_docker_is_installed() {
    if ! command -v docker >/dev/null 2>&1; then
        return 1
    fi

    # Docker binary exists; check Compose plugin
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

# --- Helper: Install Docker Engine via apt (Ubuntu/Debian) ---
_docker_install_apt() {
    print -P "  Docker Engine を apt でインストールします..."

    # Detect distro (ubuntu or debian)
    local distro
    distro=$(. /etc/os-release && echo "$ID")
    case "$distro" in
        ubuntu|debian) ;;
        *)
            print -P "%F{160}エラー: 未対応のディストリビューションです (${distro})。Ubuntu または Debian が必要です。%f" >&2
            return 1
            ;;
    esac

    # Step 1: Remove conflicting old packages
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

    # Step 2: Install prerequisites
    run_cmd sudo apt-get update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。%f"
    }
    run_cmd sudo apt-get install -y ca-certificates curl || {
        print -P "%F{160}エラー: 前提パッケージのインストールに失敗しました。%f" >&2
        return 1
    }

    # Step 3: Add Docker GPG key
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

    # Step 4: Add Docker APT repository (DEB822 format)
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

    # Step 5: Install Docker Engine + Compose plugin
    run_cmd sudo apt-get update -qq || {
        print -P "%F{220}警告: apt update に失敗しました。%f"
    }
    run_cmd sudo apt-get install -y "${DOCKER_MOD_APT_PACKAGES[@]}" || {
        print -P "%F{160}エラー: Docker Engine のインストールに失敗しました。%f" >&2
        return 1
    }
}

# --- Helper: Install Docker Desktop via Homebrew (macOS) ---
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

# --- Helper: Docker group setup + systemd auto-start (Linux only) ---
_docker_setup_group() {
    # NOTE: $USER becomes "root" under sudo; resolve the real invoking user
    local target_user="${SUDO_USER:-$(id -un)}"

    print -P ""
    print -P "Docker グループ設定:"

    # Add docker group (idempotent: -f does not fail if group exists)
    run_cmd sudo groupadd -f docker || {
        print -P "%F{160}エラー: docker グループの作成に失敗しました。%f" >&2
        return 1
    }

    # Add current user to docker group
    if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
        print -P "  情報: ユーザー ${target_user} は既に docker グループに所属しています。"
    else
        run_cmd sudo usermod -aG docker "$target_user" || {
            print -P "%F{160}エラー: ユーザーの docker グループ追加に失敗しました。%f" >&2
            return 1
        }
        print -P "  %F{220}NOTE: docker グループの変更を反映するには再ログインが必要です。%f"
    fi

    # Enable auto-start via systemd (if available)
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

# --- Setup ---
module_setup() {
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

    # --- 1. Docker installation (idempotent) ---
    if _docker_is_installed; then
        # Already installed; skip installation
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

        # Verify installation
        if (( ! DRY_RUN )); then
            if command -v docker >/dev/null 2>&1; then
                print -P "  %F{34}Docker のインストールが完了しました ($(docker --version 2>/dev/null))。%f"
            else
                print -P "%F{160}エラー: Docker のインストール後にコマンドが見つかりません。%f" >&2
                return 1
            fi
        fi
    fi

    # --- 2. Docker group + systemd (Linux only) ---
    if [[ "$env" == "linux" ]]; then
        _docker_setup_group || return 1
    fi

    # --- Completion message ---
    print -P ""
    if (( DRY_RUN )); then
        print -P "情報: Docker セットアップ予定です（dry-run）。"
    else
        print -P "%F{34}Docker のセットアップが完了しました。%f"
        if command -v docker >/dev/null 2>&1; then
            print -P "  Docker: $(docker --version 2>/dev/null || print 'N/A')"
            # Show Compose version if available
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

# --- Uninstall ---
module_uninstall() {
    local env
    env=$(_docker_detect_env)

    case "$env" in
        linux)
            if ! command -v apt-get >/dev/null 2>&1; then
                print -P "%F{160}エラー: apt-get が見つかりません。Debian/Ubuntu 系のみ対応しています。%f" >&2
                return 1
            fi
            print -P "Docker Engine を削除します..."

            # Remove Docker packages
            run_cmd sudo apt-get purge -y "${DOCKER_MOD_APT_PACKAGES[@]}" docker-ce-rootless-extras 2>/dev/null || {
                print -P "%F{220}警告: Docker パッケージの削除に失敗しました（既に削除済みの可能性があります）。%f"
            }

            run_cmd sudo apt-get autoremove -y 2>/dev/null || true

            # Remove APT source and GPG key
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

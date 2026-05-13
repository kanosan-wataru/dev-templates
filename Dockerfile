# syntax=docker/dockerfile:1.7
# ==============================================
# 開発環境コンテナ
# setup.sh で選択したモジュールをインストールした Zsh 環境
# ==============================================

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# BuildKit cache mount を使って apt 取得を高速化
# NOTE: docker-clean が cache を毎回消すためビルド中だけ退避し、最終イメージには元の挙動を復元する
#       (runtime で apt-get を使うユーザーが cache 蓄積に悩まないため)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    mv /etc/apt/apt.conf.d/docker-clean /tmp/docker-clean.bak \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        zsh git curl wget unzip sudo ca-certificates locales gpg jq \
        build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev \
        libxmlsec1-dev libffi-dev liblzma-dev \
    && locale-gen en_US.UTF-8 \
    && mv /tmp/docker-clean.bak /etc/apt/apt.conf.d/docker-clean

# 非 root ユーザー（パスワードなし sudo）
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /usr/bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME

# setup.sh で導入するモジュール
# Docker / AWS CLI / 1Password はコンテナ内で動作しないため既定で除外
# node モジュールが fnm + Node.js を multi-arch でインストールする
# 上書き方法:
#   1) Compose 経由 (推奨): SETUP_MODULES="..." docker compose build
#   2) 直接 build-arg:      docker compose build --build-arg SETUP_MODULES="..."
# 再現性のため FNM_VERSION / NODE_VERSION も同じ手順で固定可能
ARG SETUP_MODULES="zsh git modern-cli node python claude-code codex-cli gemini-cli gh copilot-cli"
ARG FNM_VERSION=""
ARG NODE_VERSION=""
ENV FNM_VERSION=${FNM_VERSION} \
    NODE_VERSION=${NODE_VERSION}
COPY --chown=$USERNAME:$USERNAME dotfiles/ /tmp/dotfiles/
# SETUP_MODULES 未指定で実行すると非 TTY フォールバックで --all 相当となり、
# 既定で除外しているはずの Docker / AWS / 1Password まで入ってしまう。明示的に弾く。
RUN if [ -z "${SETUP_MODULES// }" ]; then \
        echo "ERROR: SETUP_MODULES is empty. Specify modules explicitly or pass '--all'." >&2; \
        exit 1; \
    fi \
    && cd /tmp/dotfiles \
    && bash setup.sh $SETUP_MODULES --force \
    && rm -rf /tmp/dotfiles

WORKDIR /workspaces

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD command -v zsh >/dev/null && command -v git >/dev/null || exit 1

CMD ["zsh"]

# syntax=docker/dockerfile:1.7
# ==============================================
# 開発環境コンテナ
# setup.sh で選択したモジュールをインストールした Zsh 環境
# ==============================================

FROM ubuntu:24.04

# Ubuntu の既定 /bin/sh は dash で bash 拡張 (${var//pattern} 等) が使えないため
# 全 RUN ステップを bash で実行する。pipefail でパイプ途中失敗も拾う。
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
# ホストの UID/GID をビルド時に渡せるようにし、bind mount したファイルの所有を一致させる
#   docker compose build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN set -e \
    # root への昇格を防ぐため UID/GID 0 を明示的に拒否
    && if [[ "$USER_UID" == "0" || "$USER_GID" == "0" ]]; then \
        echo "ERROR: USER_UID / USER_GID must not be 0 (root)." >&2; exit 1; \
    fi \
    # 既存ユーザー (ubuntu:24.04 の ubuntu は UID 1000) と UID 衝突する場合は削除
    && existing_user=$(getent passwd "$USER_UID" | cut -d: -f1 || true) \
    && if [[ -n "$existing_user" && "$existing_user" != "$USERNAME" ]]; then \
        userdel -r "$existing_user" 2>/dev/null || true; \
    fi \
    # GID が既存グループ (例: ホスト GID 100 = users) と衝突する場合はそのグループを再利用
    && if ! getent group "$USER_GID" >/dev/null; then \
        groupadd --gid "$USER_GID" "$USERNAME"; \
    fi \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /usr/bin/zsh "$USERNAME" \
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
# SETUP_MODULES の検証:
# - 空文字 → 非 TTY フォールバックで --all 相当となり除外モジュールも入るため弾く
# - 不正文字 (シェルメタ文字) → unquoted 展開でインジェクションになるため弾く
#   許容: 英数字 / - / _ / 空白 のみ (例: "zsh node", "--all")
RUN if [[ -z "${SETUP_MODULES// /}" ]]; then \
        echo "ERROR: SETUP_MODULES is empty. Specify modules explicitly or pass '--all'." >&2; \
        exit 1; \
    fi \
    && if [[ ! "$SETUP_MODULES" =~ ^[A-Za-z0-9_[:space:]-]+$ ]]; then \
        echo "ERROR: SETUP_MODULES contains invalid characters. Allowed: [A-Za-z0-9_-] and spaces." >&2; \
        exit 1; \
    fi \
    && cd /tmp/dotfiles \
    && bash setup.sh $SETUP_MODULES --force \
    && rm -rf /tmp/dotfiles

WORKDIR /workspaces

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD command -v zsh >/dev/null && command -v git >/dev/null || exit 1

CMD ["zsh"]

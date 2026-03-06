# ==============================================
# 開発環境コンテナ
# setup.sh --all で全モジュールをプリインストールした Zsh 環境
# ==============================================

FROM ubuntu:24.04

# 対話的プロンプトを抑制
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo

# 全モジュールの前提パッケージを一括インストール
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基本ツール
    zsh \
    git \
    curl \
    wget \
    unzip \
    sudo \
    ca-certificates \
    locales \
    # modern-cli (eza) 用
    gpg \
    # Python ビルド依存パッケージ
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# ロケール設定
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# 非 root ユーザーの作成（パスワードなし sudo）
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /usr/bin/zsh $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# fnm + Node.js LTS を事前インストール
# NOTE: Docker ビルド内では GitHub リダイレクトが不安定なため、
#       setup.sh の node モジュールに頼らず直接インストールする
USER $USERNAME
ENV FNM_DIR="/home/${USERNAME}/.local/share/fnm"
RUN mkdir -p /home/${USERNAME}/.local/bin \
    && curl -fsSL https://fnm.vercel.app/install \
       | bash -s -- --install-dir /home/${USERNAME}/.local/bin --skip-shell \
    && export PATH="/home/${USERNAME}/.local/bin:$PATH" \
    && eval "$(fnm env)" \
    && fnm install --lts \
    && fnm default lts-latest
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"

# dotfiles をコピーして setup.sh を実行
WORKDIR /home/$USERNAME
COPY --chown=$USERNAME:$USERNAME dotfiles/ /tmp/dotfiles/
RUN cd /tmp/dotfiles && zsh setup.sh --all \
    && rm -rf /tmp/dotfiles

WORKDIR /workspaces
CMD ["zsh"]

# ---------------------------------------------
# lib/skillshare.sh
# AI CLI 間のスキル/エージェント同期ツール (skillshare) のセットアップヘルパー群。
#
# このファイルは setup.sh から source される。関数のみを提供し、モジュール本体
# (modules/skillshare.sh) からオーケストレーション目的で呼び出される。
#
# 関数命名規約: skillshare_<action>
# 変数命名規約: SKILLSHARE_<purpose> (env で override 可能)
# ---------------------------------------------

# --- skillshare CLI のインストール先・取得元 ---
# NOTE: install.sh は供給元固定のためリリースタグから取得する。main ブランチが
#       後から書き換わっても影響を受けないようにするため tag pin する。
SKILLSHARE_INSTALL_DIR="${SKILLSHARE_INSTALL_DIR:-${HOME}/.local/bin}"
SKILLSHARE_REPO="${SKILLSHARE_REPO:-runkids/skillshare}"
SKILLSHARE_VERSION="${SKILLSHARE_VERSION:-v0.19.12}"
# opt-in: install.sh の SHA256 期待値。空文字列なら検証スキップ。
# 上流の install.sh が改竄/差し替えされた場合の防御線として利用する。
SKILLSHARE_INSTALLER_SHA256="${SKILLSHARE_INSTALLER_SHA256:-}"

# --- ヘルパー: ファイルの SHA256 を期待値と照合する ---
# 戻り値: 0=一致 / 1=不一致 or 検証ツール無し。
# sha256sum (Linux) と shasum -a 256 (macOS) の両方をサポート。
skillshare_verify_sha256() {
    local file="$1" expected="$2" actual=""
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        msg_error "sha256sum / shasum が見つかりません。SHA256 検証を実行できません。"
        return 1
    fi
    if [[ "$actual" != "$expected" ]]; then
        msg_error "SHA256 不一致: actual=${actual} expected=${expected}"
        return 1
    fi
    msg_success "SHA256 検証成功 (${actual:0:12}...)"
}

# --- ヘルパー: skillshare CLI のインストール ---
# GitHub Releases から install.sh を取得して ~/.local/bin に配置する。
# NOTE: curl|sh は使わず、スクリプトをダウンロードしてから明示的に実行する。
skillshare_install_cli() {
    local install_dir="$SKILLSHARE_INSTALL_DIR"

    if command -v skillshare >/dev/null 2>&1 && ! ((UPGRADE)); then
        msg_info "skillshare は既にインストールされています ($(skillshare --version 2>/dev/null | head -1 || echo unknown))。"
        return 0
    fi

    local installer_url="https://raw.githubusercontent.com/${SKILLSHARE_REPO}/${SKILLSHARE_VERSION}/install.sh"

    if ((DRY_RUN)); then
        msg_dry_run "wget -qO /tmp/skillshare-install.sh ${installer_url}"
        msg_dry_run "INSTALL_DIR=${install_dir} sh /tmp/skillshare-install.sh"
        return 0
    fi

    run_cmd mkdir -p "$install_dir" || {
        msg_error "${install_dir} の作成に失敗しました。"
        return 1
    }

    local installer_path
    installer_path=$(mktemp /tmp/skillshare-install.XXXXXX.sh) || {
        msg_error "一時ファイルの作成に失敗しました。"
        return 1
    }

    msg_step "skillshare インストーラーをダウンロードします (${SKILLSHARE_VERSION})..."
    if ! wget -qO "$installer_path" "$installer_url"; then
        if ! curl -fsSL "$installer_url" -o "$installer_path"; then
            msg_error "skillshare インストーラーのダウンロードに失敗しました。"
            rm -f "$installer_path"
            return 1
        fi
    fi

    # opt-in: 期待値が設定されていればダウンロード後に SHA256 を照合する。
    if [[ -n "$SKILLSHARE_INSTALLER_SHA256" ]]; then
        if ! skillshare_verify_sha256 "$installer_path" "$SKILLSHARE_INSTALLER_SHA256"; then
            rm -f "$installer_path"
            return 1
        fi
    fi

    msg_step "skillshare をインストールします (${install_dir})..."
    if ! INSTALL_DIR="$install_dir" sh "$installer_path"; then
        msg_error "skillshare のインストールに失敗しました。"
        rm -f "$installer_path"
        return 1
    fi
    rm -f "$installer_path"

    if ! command -v skillshare >/dev/null 2>&1; then
        msg_warn "skillshare はインストール済みですが PATH に含まれていません。"
        msg_step "export PATH=\"\$HOME/.local/bin:\$PATH\" をシェル設定に追加してください。"
    fi
}

# --- ヘルパー: config.yaml をテンプレートから生成 ---
# sed -e "s|...|...|" だとパスに | & \ が含まれると壊れるため、bash の
# parameter expansion (${var//pattern/replacement}) を使う。これは sed と異なり
# 置換文字列内のメタ文字 (&, \) を特殊扱いしない安全なリテラル置換。
# 引数: $1=出力先 $2=テンプレート $3=skills ソース $4=agents ソース
skillshare_render_config() {
    local config_path="$1" template="$2" skills_src="$3" agents_src="$4"

    if [[ -f "$config_path" ]] && ! ((UPGRADE)) && ! ((FORCE)); then
        msg_info "skillshare config.yaml は既に存在します。スキップします。"
        return 0
    fi

    if ((DRY_RUN)); then
        msg_dry_run "config.yaml を ${template} から生成 (置換: __SKILLS_SOURCE__ / __AGENTS_SOURCE__ / __HOME__)"
        return 0
    fi

    msg_step "skillshare config.yaml を生成します..."
    local content
    content=$(<"$template") || {
        msg_error "config.yaml テンプレートの読み込みに失敗しました。"
        return 1
    }
    content="${content//__SKILLS_SOURCE__/$skills_src}"
    content="${content//__AGENTS_SOURCE__/$agents_src}"
    content="${content//__HOME__/$HOME}"
    printf '%s\n' "$content" >"$config_path" || {
        msg_error "config.yaml の生成に失敗しました。"
        return 1
    }
}

# --- ヘルパー: skillshare の source 配下に symlink を作成 ---
# 引数: $1=ソース(実体ディレクトリ) $2=symlinkを置くパス $3=ラベル(skills/agents)
# 既存 symlink が同じターゲットを指していればスキップ、別ターゲットなら更新、
# 実ディレクトリが存在する場合は警告のみ (破壊しない)。
skillshare_link_source() {
    local src="$1" link="$2" label="$3"

    if [[ -L "$link" ]]; then
        local current
        current=$(readlink "$link")
        if [[ "$current" == "$src" ]]; then
            msg_info "${link} -> ${src} は既に正しく設定されています (${label})。"
        else
            run_cmd ln -sfn "$src" "$link" || return 1
        fi
    elif [[ -d "$link" ]]; then
        msg_warn "${link} が既存ディレクトリです。${label} の symlink 化は手動で行ってください。"
        msg_step "  mv ${link} ${link}.bak && ln -sfn ${src} ${link}"
    else
        run_cmd ln -sfn "$src" "$link" || return 1
        msg_success "skillshare ${label} ソースを ${src} へ symlink しました。"
    fi
}

# --- ヘルパー: skillshare ターゲットを登録 ---
# AI CLI の設定ディレクトリが実在するものだけ target に追加する。
# claude は真実のソースなので意図的に除外する (循環同期の防止)。
skillshare_register_targets() {
    local -a targets=(
        "gemini|${HOME}/.gemini/skills"
        "codex|${HOME}/.codex/skills"
        "opencode|${HOME}/.config/opencode/skills"
    )
    local entry name path parent
    for entry in "${targets[@]}"; do
        IFS='|' read -r name path <<<"$entry"
        parent=$(dirname "$path")
        if [[ ! -d "$parent" ]]; then
            msg_info "${name} がインストールされていません。target を追加しません。"
            continue
        fi
        if skillshare target list 2>/dev/null | grep -qE "^  ${name}\b"; then
            msg_info "skillshare target '${name}' は既に登録済みです。"
            continue
        fi
        if ((DRY_RUN)); then
            msg_dry_run "skillshare target add ${name} ${path}"
        else
            run_cmd skillshare target add "$name" "$path" || msg_warn "${name} の target 追加に失敗しました。"
        fi
    done
}

# --- ヘルパー: skillshare sync を実行 ---
# `--force` で既存ファイル上書きを明示。skillshare CLI は --yes 系フラグを提供
# していないため、対話プロンプトが残る場合に備え stdin で "y" を流し込む。
skillshare_run_sync() {
    if ((DRY_RUN)); then
        msg_dry_run "skillshare sync --all --force"
        return 0
    fi
    msg_step "skillshare sync --all --force を実行します (skills + agents)..."
    printf "y\n" | skillshare sync --all --force >/dev/null 2>&1 \
        || msg_warn "skillshare sync に失敗しました (手動で 'skillshare sync --all' を実行してください)。"
}

# --- ヘルパー: Codex 用に .md エージェントを .toml に変換 ---
# Skillshare は .md のみ扱うため、TOML を要求する Codex には変換スクリプトで対応する。
# 引数: $1=agents ソース $2=変換スクリプトパス $3=Codex agents 出力先
skillshare_convert_codex_agents() {
    local agents_src="$1" converter="$2" codex_out="$3"

    if [[ ! -d "$agents_src" ]] || [[ ! -x "$converter" ]] || [[ ! -d "${HOME}/.codex" ]]; then
        return 0
    fi
    if ((DRY_RUN)); then
        msg_dry_run "python3 ${converter} ${agents_src} ${codex_out}"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        msg_warn "python3 が見つかりません。Codex agents 変換をスキップします。"
        return 0
    fi
    msg_step "Codex 用に .md → .toml 変換を実行します..."
    python3 "$converter" "$agents_src" "$codex_out" \
        || msg_warn "Codex agents の変換に失敗しました。"
}

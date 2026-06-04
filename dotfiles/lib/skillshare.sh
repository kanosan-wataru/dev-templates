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
SKILLSHARE_VERSION="${SKILLSHARE_VERSION:-v0.20.7}"
# install.sh の SHA256 期待値。download 後にこの値と照合し、不一致なら install を中断する。
# SKILLSHARE_VERSION (v0.20.7) に対応する install.sh のハッシュを pin することで、上流での
# タグ差し替え (git tag -f) による静かな内容差し替えを検知する。tag pin だけでは
# raw.githubusercontent.com の内容一意性は保証されないため、その弱点を塞ぐ supply-chain 防御線。
# NOTE: SKILLSHARE_VERSION を更新する際は、必ずこの値も新タグの install.sh のハッシュへ更新すること。
# NOTE: 検証を無効化したい場合は env で空文字列を明示する (例: SKILLSHARE_INSTALLER_SHA256= bash setup.sh)。
#       空文字での opt-out を効かせるため ${var-...} (コロンなし) を使う。${var:-...} だと
#       空文字でもデフォルト値に戻ってしまい無効化できない。
SKILLSHARE_INSTALLER_SHA256="${SKILLSHARE_INSTALLER_SHA256-47a67522d12ced431279d878f6f4568284bf250a85699d446f64d8a8df9deeed}"

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

# --- ヘルパー: config.yaml の source: / agents_source: をランタイムパスに書き換える ---
# Docker ビルド時に `SCRIPT_DIR=/tmp/dotfiles` で sync を完了させた後、
# `/tmp/dotfiles` がビルドステップ終了で削除されると config.yaml の source パスが
# 解決不能になる。ホストの bind-mount 先 (`/workspaces/<project>/...`) を
# 環境変数 SKILLSHARE_RUNTIME_SKILLS_SRC / SKILLSHARE_RUNTIME_AGENTS_SRC で渡せれば、
# ビルド完了後に config.yaml をその恒久パスへ書き換える。
# 両変数とも空ならスキップ (ローカル運用は SCRIPT_DIR が永続パスなので不要)。
skillshare_remap_runtime_paths() {
    local config_path="$1" runtime_skills="${2:-}" runtime_agents="${3:-}"
    [[ -f "$config_path" ]] || return 0
    [[ -z "$runtime_skills" && -z "$runtime_agents" ]] && return 0

    if ((DRY_RUN)); then
        [[ -n "$runtime_skills" ]] && msg_dry_run "config.yaml の source: を ${runtime_skills} に書き換え"
        [[ -n "$runtime_agents" ]] && msg_dry_run "config.yaml の agents_source: を ${runtime_agents} に書き換え"
        return 0
    fi

    # awk は OS 非依存で安全。BSD sed と GNU sed の -i 差分を回避する。
    # NOTE: awk の -v VAR=VALUE は値内の C エスケープ (\n 等) を解釈してしまうため、
    #       環境変数経由で渡して ENVIRON[] でリテラル参照する。
    local tmp
    tmp=$(mktemp "${config_path}.XXXXXX") || {
        msg_error "config.yaml 書き換え用の一時ファイル作成に失敗しました。"
        return 1
    }
    if ! NEW_SKILLS="$runtime_skills" NEW_AGENTS="$runtime_agents" awk '
        /^source: / && ENVIRON["NEW_SKILLS"] != ""        { print "source: " ENVIRON["NEW_SKILLS"]; next }
        /^agents_source: / && ENVIRON["NEW_AGENTS"] != "" { print "agents_source: " ENVIRON["NEW_AGENTS"]; next }
        { print }
    ' "$config_path" >"$tmp"; then
        rm -f "$tmp"
        msg_error "config.yaml のランタイムパス書き換えに失敗しました。"
        return 1
    fi
    # mktemp は 0600 で作るため、元の config.yaml のパーミッションを継承させる。
    # GNU/BSD chmod 両対応のため --reference を試し、失敗時は 644 にフォールバック。
    chmod --reference="$config_path" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    if ! mv "$tmp" "$config_path"; then
        rm -f "$tmp"
        msg_error "config.yaml の置換 (mv) に失敗しました。"
        return 1
    fi
    msg_info "config.yaml の source パスをランタイム値に更新しました。"
}

# --- ヘルパー: 過去に作成された ~/.config/skillshare/{skills,agents} の補助 symlink を掃除 ---
# 旧バージョンの dev-templates は設定ディレクトリ配下に補助 symlink を貼っていたが、
# skillshare CLI は config.yaml の source: / agents_source: のみを真実のソースとして
# 使うため冗長だった (検証済み)。さらに Docker ビルドで一時ディレクトリを指して
# dangling になる事故が起きたため恒久的に廃止し、過去の symlink は清掃する。
skillshare_cleanup_legacy_links() {
    local link
    for link in "${HOME}/.config/skillshare/skills" "${HOME}/.config/skillshare/agents"; do
        [[ -L "$link" ]] || continue
        if ((DRY_RUN)); then
            msg_dry_run "rm ${link}  # legacy aux symlink"
        else
            rm -f "$link" && msg_info "旧補助 symlink ${link} を削除しました。"
        fi
    done
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
    printf "y\n" | skillshare sync --all --force >/dev/null 2>&1 ||
        msg_warn "skillshare sync に失敗しました (手動で 'skillshare sync --all' を実行してください)。"
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
    python3 "$converter" "$agents_src" "$codex_out" ||
        msg_warn "Codex agents の変換に失敗しました。"
}

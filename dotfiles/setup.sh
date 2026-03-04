#!/usr/bin/env zsh

# ---------------------------------------------
# 開発環境セットアップスクリプト
#
# 使用法:
#   zsh setup.sh                  インタラクティブモード（モジュール選択）
#   zsh setup.sh --all            全モジュール一括インストール
#   zsh setup.sh --select zsh     特定モジュールを指定（複数可）
#   zsh setup.sh --dry-run        変更内容のプレビューのみ
#   zsh setup.sh --uninstall      バックアップから復元
#   zsh setup.sh --help           ヘルプ表示
#
# モジュール:
#   zsh          Zsh 設定一式 (Zinit + プラグイン + テーマ + エイリアス)
#   claude-code  Claude Code (Anthropic CLI)
#   gemini-cli   Gemini CLI (Google AI CLI)
# ---------------------------------------------

# --- Zsh実行確認 ---
if [ -z "$ZSH_VERSION" ]; then
    print -P "%F{160}エラー: このスクリプトは Zsh で実行する必要があります。%f" >&2
    print -P "実行例: zsh $0" >&2
    exit 1
fi


# ==============================================
# 引数パース
# ==============================================
DRY_RUN=0
UNINSTALL=0
ALL_FLAG=0
typeset -a SELECT_MODULES

while (( $# > 0 )); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --all)
            ALL_FLAG=1
            ;;
        --select)
            if (( $# < 2 )); then
                print -P "%F{160}エラー: --select にはモジュール名が必要です%f" >&2
                exit 1
            fi
            shift
            SELECT_MODULES+=("$1")
            ;;
        --help|-h)
            print -P "使用法: zsh $0 [オプション]"
            print -P ""
            print -P "オプション:"
            print -P "  --dry-run          変更内容のプレビューのみ（実際には変更しない）"
            print -P "  --uninstall        バックアップから元の状態に復元"
            print -P "  --all              全モジュールを一括インストール"
            print -P "  --select MODULE    特定モジュールを指定（複数指定可）"
            print -P "  --help, -h         このヘルプを表示"
            print -P ""
            print -P "モジュール:"
            print -P "  zsh          Zsh 設定一式 (Zinit + プラグイン + テーマ + エイリアス)"
            print -P "  claude-code  Claude Code (Anthropic CLI)"
            print -P "  gemini-cli   Gemini CLI (Google AI CLI)"
            print -P ""
            print -P "例:"
            print -P "  zsh $0                              インタラクティブ選択"
            print -P "  zsh $0 --all                        全モジュール一括"
            print -P "  zsh $0 --select zsh --select claude-code  複数指定"
            print -P "  zsh $0 --all --dry-run              全モジュールをプレビュー"
            exit 0
            ;;
        *)
            print -P "%F{160}エラー: 不明なオプション: $1%f" >&2
            print -P "ヘルプ: zsh $0 --help" >&2
            exit 1
            ;;
    esac
    shift
done


# ==============================================
# 共通変数
# ==============================================
SCRIPT_DIR="${0:a:h}"
ZSH_BASE_DIR="${ZDOTDIR:-$HOME}"
ZSH_CONFIG_DIR="$ZSH_BASE_DIR/.zsh"
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
ZINIT_VERSION="v3.14.0"
BACKUP_SUFFIX=".backup.$(command date +%Y%m%d%H%M%S)"

# 管理対象ファイルのリスト（配布元パス, 配置先パス, 表示名, 未検出時メッセージ）
# NOTE: 配列の各要素は "src|dst|label|hint" の形式
MANAGED_FILES=(
    "$SCRIPT_DIR/.zshrc|$ZSH_BASE_DIR/.zshrc|.zshrc|"
    "$SCRIPT_DIR/.zsh/.p10k.zsh|$ZSH_CONFIG_DIR/.p10k.zsh|.p10k.zsh|Powerlevel10k のデフォルト設定が使用されます。"
    "$SCRIPT_DIR/.zsh/plugins.zsh|$ZSH_CONFIG_DIR/plugins.zsh|plugins.zsh|プラグインは手動で設定してください。"
    "$SCRIPT_DIR/.zsh/aliases.zsh|$ZSH_CONFIG_DIR/aliases.zsh|aliases.zsh|エイリアスは手動で設定してください。"
)

# モジュール定義（ID|表示名|説明|デフォルト選択）
# NOTE: デフォルト選択 1=ON, 0=OFF
MODULES=(
    "zsh|Zsh 設定一式|Zinit + プラグイン + テーマ + エイリアス|1"
    "claude-code|Claude Code|Anthropic CLI (Node.js v18+ 必要)|0"
    "gemini-cli|Gemini CLI|Google AI CLI (Node.js v18+ 必要)|0"
)


# ==============================================
# ヘルパー関数
# ==============================================

# dry-run 対応の実行ラッパー
# DRY_RUN=1 の場合はコマンドを表示するだけで実行しない
run_cmd() {
    if (( DRY_RUN )); then
        print -P "%F{242}  [DRY-RUN] ${(q)@}%f"
    else
        "$@"
    fi
}

# 設定ファイルのバックアップと配置を行うヘルパー（べき等性対応）
# 引数: $1=配布元パス $2=配置先パス $3=表示名 $4=未検出時の補足メッセージ
install_config() {
    local src="$1" dst="$2" label="$3" missing_hint="$4"

    # 配布元が存在しない場合は警告のみ
    if [[ ! -f "$src" ]]; then
        if [[ -n "$missing_hint" ]]; then
            print -P "%F{220}警告: ${label} が見つかりません。${missing_hint}%f"
        else
            print -P "%F{160}エラー: 配布元の ${label} が見つかりません: ${src}%f" >&2
            exit 1
        fi
        return 0
    fi

    # べき等性チェック: シンボリックリンクでなく、内容が同一ならスキップ
    if [[ -f "$dst" && ! -h "$dst" ]] && cmp -s "$src" "$dst"; then
        print -P "情報: ${label} は既に最新の状態です。スキップします。"
        return 0
    fi

    # バックアップ処理（既存ファイルまたはシンボリックリンクがある場合）
    if [[ -f "$dst" || -h "$dst" ]]; then
        run_cmd command mv "$dst" "${dst}${BACKUP_SUFFIX}" || {
            print -P "%F{160}エラー: ${label} のバックアップに失敗しました。%f" >&2
            exit 1
        }
        if (( DRY_RUN )); then
            print -P "情報: 既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップします（予定）。"
        else
            print -P "情報: 既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップしました。"
        fi
    fi

    # 配置処理
    run_cmd command cp -p "$src" "$dst" || {
        print -P "%F{160}エラー: ${label} の配置に失敗しました。%f" >&2
        exit 1
    }
    if (( DRY_RUN )); then
        print -P "情報: ${label} を配置予定です（dry-run）。"
    else
        print -P "情報: ${label} を配置しました。"
    fi
}

# Node.js v18+ と npm の存在を確認するヘルパー
# 戻り値: 0=利用可能, 1=利用不可
ensure_node() {
    if ! command -v node >/dev/null 2>&1; then
        print -P "%F{160}エラー: Node.js がインストールされていません。%f" >&2
        print -P "  nvm, fnm, volta 等で Node.js v18 以上をインストールしてください。" >&2
        print -P "  例: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash" >&2
        return 1
    fi

    local node_ver
    node_ver=$(node -v | sed 's/^v//' | cut -d. -f1)
    if (( node_ver < 18 )); then
        print -P "%F{160}エラー: Node.js v18 以上が必要です（現在: v${node_ver}）%f" >&2
        print -P "  Node.js をアップグレードしてください。" >&2
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        print -P "%F{160}エラー: npm がインストールされていません。%f" >&2
        print -P "  Node.js に付属の npm が利用可能か確認してください。" >&2
        return 1
    fi

    return 0
}


# ==============================================
# チェックボックス選択UI（tput ベース + 再描画方式）
# ==============================================

# チェックボックスメニューを表示し、選択結果を返す
# 引数: メニュー項目の配列（"表示名|説明|デフォルト選択(0/1)" 形式）
# 出力: 選択されたインデックス（1始まり）をスペース区切りで stdout に出力
# 戻り値: 0=確定, 1=キャンセル
checkbox_menu() {
    local -a items=("$@")
    local item_count=${#items}
    local cursor=1
    local -a selected
    local -a labels
    local -a descs
    local redraw=0

    # メニュー項目をパース
    for i in {1..$item_count}; do
        labels[$i]="${items[$i][(ws:|:)1]}"
        descs[$i]="${items[$i][(ws:|:)2]}"
        selected[$i]="${items[$i][(ws:|:)3]}"
    done

    # ヘッダー行数（操作説明 + 空行）
    local header_lines=2
    # 合計描画行数（ヘッダー + メニュー項目）
    local total_lines=$(( header_lines + item_count ))

    # 端末状態の保護: 異常終了時にカーソルとリセットを復帰
    trap '_checkbox_cleanup' INT TERM QUIT
    tput civis 2>/dev/null  # カーソル非表示

    # 画面下部でのスクロールスペースを事前確保
    for i in {1..$total_lines}; do print ""; done
    for i in {1..$total_lines}; do tput cuu1; done

    # 描画ループ
    while true; do
        _checkbox_draw "$item_count" "$cursor" "$header_lines" "$redraw"
        redraw=1

        # キー入力待ち
        local key=""
        read -k 1 key

        case "$key" in
            $'\e')
                # ESC シーケンスの解析（矢印キー対応）
                local key2="" key3=""
                read -k 1 -t 0.05 key2 2>/dev/null
                if [[ "$key2" == "[" || "$key2" == "O" ]]; then
                    read -k 1 -t 0.05 key3 2>/dev/null
                    case "$key3" in
                        A) # 上矢印
                            (( cursor > 1 )) && (( cursor-- ))
                            ;;
                        B) # 下矢印
                            (( cursor < item_count )) && (( cursor++ ))
                            ;;
                    esac
                fi
                ;;
            k) # vim: 上移動
                (( cursor > 1 )) && (( cursor-- ))
                ;;
            j) # vim: 下移動
                (( cursor < item_count )) && (( cursor++ ))
                ;;
            ' ') # スペース: 選択トグル
                if (( selected[$cursor] )); then
                    selected[$cursor]=0
                else
                    selected[$cursor]=1
                fi
                ;;
            a) # 全選択/全解除トグル
                local all_selected=1
                for i in {1..$item_count}; do
                    if (( ! selected[$i] )); then
                        all_selected=0
                        break
                    fi
                done
                local new_val=$(( ! all_selected ))
                for i in {1..$item_count}; do
                    selected[$i]=$new_val
                done
                ;;
            $'\n') # Enter: 確定
                break
                ;;
        esac
    done

    # クリーンアップ
    tput cnorm 2>/dev/null  # カーソル表示復帰
    trap - INT TERM QUIT

    # 選択されたインデックスを出力
    local result=""
    for i in {1..$item_count}; do
        if (( selected[$i] )); then
            result+="$i "
        fi
    done
    print -n "$result"
    return 0
}

# チェックボックスメニューの描画（内部関数）
_checkbox_draw() {
    local item_count=$1 cursor=$2 header_lines=$3 redraw=$4
    local total_lines=$(( header_lines + item_count ))
    local max_width=${COLUMNS:-80}

    # 再描画時は描画開始位置に戻る
    if (( redraw )); then
        for i in {1..$total_lines}; do tput cuu1; done
    fi

    # ヘッダー
    tput el
    print -P "%F{36}%B インストールするモジュールを選択してください:%b%f"
    tput el
    print -P "%F{242} (↑↓/jk: 移動, スペース: 選択, a: 全選択, Enter: 確定)%f"

    # メニュー項目
    for i in {1..$item_count}; do
        tput el  # 行末クリア（前回描画の残りを消す）

        local prefix=" "
        local check="[ ]"
        local label_color=""
        local reset=""

        if (( selected[$i] )); then
            check="[x]"
        fi

        if (( i == cursor )); then
            # カーソル行: シアン太字
            tput bold 2>/dev/null
            tput setaf 6 2>/dev/null
            prefix=">"
        fi

        # 表示文字列を組み立て、端末幅に収める
        local line=" ${prefix} ${check} ${labels[$i]}  ${descs[$i]}"
        if (( ${#line} > max_width )); then
            line="${line[1,$((max_width - 1))]}"
        fi
        print "$line"

        if (( i == cursor )); then
            tput sgr0 2>/dev/null
        fi
    done
}

# チェックボックスUIの異常終了時クリーンアップ
_checkbox_cleanup() {
    tput cnorm 2>/dev/null  # カーソル表示復帰
    tput sgr0 2>/dev/null   # 装飾リセット
    print ""
    exit 130
}


# ==============================================
# モジュールセットアップ関数
# ==============================================

# --- Zsh 設定一式 ---
setup_zsh() {
    print -P ""
    print -P "%F{36}%B[Zsh 設定一式]%b%f"
    print -P "---------------------------------------------"

    # 依存コマンドの確認
    if ! command -v git >/dev/null 2>&1; then
        print -P "%F{160}エラー: git コマンドが見つかりません。インストールしてください。%f" >&2
        return 1
    fi
    print -P "情報: git が利用可能です ($(command git --version))"

    # Zinit のインストール
    print -P "Zinit の状態を確認・インストールします..."
    if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
        print -P "%F{33} %F{220}Zinit (%F{33}zdharma-continuum/zinit%F{220}) をインストール中...%f"
        run_cmd command mkdir -p -m 700 "$(dirname "$ZINIT_HOME")" || {
            print -P "%F{160}エラー: Zinit 用ディレクトリの作成に失敗しました。%f" >&2
            return 1
        }
        run_cmd command git clone --branch "$ZINIT_VERSION" --depth 1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" || {
            print -P "%F{160}エラー: Zinit の git clone に失敗しました。%f" >&2
            return 1
        }
        if (( DRY_RUN )); then
            print -P "情報: Zinit ${ZINIT_VERSION} をインストール予定です（dry-run）。"
        else
            print -P "%F{33} %F{34}Zinit ${ZINIT_VERSION} のインストールに成功しました。%f"
        fi
    else
        print -P "情報: Zinit は既にインストールされています。"
    fi

    # 設定ディレクトリの作成
    if [[ ! -d "$ZSH_CONFIG_DIR" ]]; then
        run_cmd command mkdir -p -m 700 "$ZSH_CONFIG_DIR" || {
            print -P "%F{160}エラー: $ZSH_CONFIG_DIR の作成に失敗しました。%f" >&2
            return 1
        }
        if (( DRY_RUN )); then
            print -P "情報: $ZSH_CONFIG_DIR を作成予定です（dry-run）。"
        else
            print -P "情報: $ZSH_CONFIG_DIR を作成しました。"
        fi
    else
        print -P "情報: $ZSH_CONFIG_DIR は既に存在します。"
    fi

    # 設定ファイルの配置
    print -P "設定ファイルを配置します..."
    for entry in "${MANAGED_FILES[@]}"; do
        src="${entry[(ws:|:)1]}"
        dst="${entry[(ws:|:)2]}"
        label="${entry[(ws:|:)3]}"
        hint="${entry[(ws:|:)4]}"
        install_config "$src" "$dst" "$label" "$hint"
    done

    print -P "%F{34}Zsh 設定一式のセットアップが完了しました。%f"
}

# Zsh 設定のアンインストール
uninstall_zsh() {
    local restored=0

    for entry in "${MANAGED_FILES[@]}"; do
        dst="${entry[(ws:|:)2]}"
        label="${entry[(ws:|:)3]}"

        # Zsh Glob 限定子で最新のバックアップを検索
        latest_backup=( "${dst}.backup."*(N.om[1].) )

        if (( ${#latest_backup[@]} > 0 )); then
            print -P "復元: ${label} をバックアップ (${latest_backup[1]:t}) から戻します。"
            run_cmd command mv "${latest_backup[1]}" "$dst" || {
                print -P "%F{160}エラー: ${label} の復元に失敗しました。%f" >&2
                return 1
            }
            restored=1
        elif [[ -f "$dst" || -h "$dst" ]]; then
            print -P "削除: ${label} を削除します（セットアップ前の状態に復元）。"
            run_cmd command rm -f "$dst" || {
                print -P "%F{160}エラー: ${label} の削除に失敗しました。%f" >&2
                return 1
            }
            restored=1
        else
            print -P "情報: ${label} は配置されていません。スキップします。"
        fi
    done

    if (( restored )); then
        print -P "%F{34}Zsh 設定のアンインストールが完了しました。%f"
    else
        print -P "情報: Zsh 設定の復元・削除対象はありませんでした。"
    fi
    print -P "NOTE: Zinit 本体は削除されていません。不要な場合は以下を手動で削除してください:"
    print -P "  rm -rf ${ZINIT_HOME:h}"
}

# --- Claude Code ---
setup_claude_code() {
    print -P ""
    print -P "%F{36}%B[Claude Code]%b%f"
    print -P "---------------------------------------------"

    # べき等性チェック
    if command -v claude >/dev/null 2>&1; then
        local current_ver
        current_ver=$(claude --version 2>/dev/null || print "unknown")
        print -P "情報: Claude Code は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    # Node.js / npm の確認
    if ! ensure_node; then
        print -P "%F{220}スキップ: Claude Code のインストールには Node.js v18+ が必要です。%f"
        return 1
    fi

    print -P "Claude Code をインストールします..."
    run_cmd npm install -g @anthropic-ai/claude-code || {
        print -P "%F{160}エラー: Claude Code のインストールに失敗しました。%f" >&2
        print -P "  npm install -g の権限エラーの場合:" >&2
        print -P "    npm config set prefix ~/.local" >&2
        print -P "  または nvm/fnm をお使いの場合は sudo 不要です。" >&2
        return 1
    }

    if (( DRY_RUN )); then
        print -P "情報: Claude Code をインストール予定です（dry-run）。"
    else
        print -P "%F{34}Claude Code のインストールが完了しました。%f"
        print -P ""
        print -P "初回セットアップ:"
        print -P "  claude  # 対話的に API キーを設定"
        print -P "  詳細: https://docs.anthropic.com/en/docs/claude-code"
    fi
}

# Claude Code のアンインストール
uninstall_claude_code() {
    if command -v claude >/dev/null 2>&1; then
        print -P "Claude Code をアンインストールします..."
        run_cmd npm uninstall -g @anthropic-ai/claude-code || {
            print -P "%F{160}エラー: Claude Code のアンインストールに失敗しました。%f" >&2
            return 1
        }
        print -P "%F{34}Claude Code をアンインストールしました。%f"
    elif npm ls -g @anthropic-ai/claude-code >/dev/null 2>&1; then
        print -P "Claude Code をアンインストールします..."
        run_cmd npm uninstall -g @anthropic-ai/claude-code || {
            print -P "%F{160}エラー: Claude Code のアンインストールに失敗しました。%f" >&2
            return 1
        }
        print -P "%F{34}Claude Code をアンインストールしました。%f"
    else
        print -P "情報: Claude Code はインストールされていません。スキップします。"
    fi
}

# --- Gemini CLI ---
setup_gemini_cli() {
    print -P ""
    print -P "%F{36}%B[Gemini CLI]%b%f"
    print -P "---------------------------------------------"

    # べき等性チェック
    if command -v gemini >/dev/null 2>&1; then
        local current_ver
        current_ver=$(gemini --version 2>/dev/null || print "unknown")
        print -P "情報: Gemini CLI は既にインストールされています (${current_ver})。スキップします。"
        return 0
    fi

    # Node.js / npm の確認
    if ! ensure_node; then
        print -P "%F{220}スキップ: Gemini CLI のインストールには Node.js v18+ が必要です。%f"
        return 1
    fi

    print -P "Gemini CLI をインストールします..."
    run_cmd npm install -g @google/gemini-cli || {
        print -P "%F{160}エラー: Gemini CLI のインストールに失敗しました。%f" >&2
        print -P "  npm install -g の権限エラーの場合:" >&2
        print -P "    npm config set prefix ~/.local" >&2
        print -P "  または nvm/fnm をお使いの場合は sudo 不要です。" >&2
        return 1
    }

    if (( DRY_RUN )); then
        print -P "情報: Gemini CLI をインストール予定です（dry-run）。"
    else
        print -P "%F{34}Gemini CLI のインストールが完了しました。%f"
        print -P ""
        print -P "初回セットアップ:"
        print -P "  gemini  # Google アカウントで認証"
        print -P "  詳細: https://github.com/google-gemini/gemini-cli"
    fi
}

# Gemini CLI のアンインストール
uninstall_gemini_cli() {
    if command -v gemini >/dev/null 2>&1; then
        print -P "Gemini CLI をアンインストールします..."
        run_cmd npm uninstall -g @google/gemini-cli || {
            print -P "%F{160}エラー: Gemini CLI のアンインストールに失敗しました。%f" >&2
            return 1
        }
        print -P "%F{34}Gemini CLI をアンインストールしました。%f"
    elif npm ls -g @google/gemini-cli >/dev/null 2>&1; then
        print -P "Gemini CLI をアンインストールします..."
        run_cmd npm uninstall -g @google/gemini-cli || {
            print -P "%F{160}エラー: Gemini CLI のアンインストールに失敗しました。%f" >&2
            return 1
        }
        print -P "%F{34}Gemini CLI をアンインストールしました。%f"
    else
        print -P "情報: Gemini CLI はインストールされていません。スキップします。"
    fi
}


# ==============================================
# モジュール実行ディスパッチ
# ==============================================

# モジュール ID からセットアップ関数を実行
run_module_setup() {
    local module_id="$1"
    case "$module_id" in
        zsh)         setup_zsh ;;
        claude-code) setup_claude_code ;;
        gemini-cli)  setup_gemini_cli ;;
        *)
            print -P "%F{160}エラー: 不明なモジュール: ${module_id}%f" >&2
            return 1
            ;;
    esac
}

# モジュール ID からアンインストール関数を実行
run_module_uninstall() {
    local module_id="$1"
    case "$module_id" in
        zsh)         uninstall_zsh ;;
        claude-code) uninstall_claude_code ;;
        gemini-cli)  uninstall_gemini_cli ;;
        *)
            print -P "%F{160}エラー: 不明なモジュール: ${module_id}%f" >&2
            return 1
            ;;
    esac
}


# ==============================================
# アンインストールモード
# ==============================================
if (( UNINSTALL )); then
    print -P "アンインストール（復元）を開始します..."
    print -P "============================================="

    if (( DRY_RUN )); then
        print -P "%F{33}[DRY-RUN モード] 実際には変更を行いません。%f"
        print -P "---------------------------------------------"
    fi

    for entry in "${MODULES[@]}"; do
        local mod_id="${entry[(ws:|:)1]}"
        local mod_name="${entry[(ws:|:)2]}"
        print -P ""
        print -P "%F{36}%B[${mod_name}]%b%f"
        print -P "---------------------------------------------"
        run_module_uninstall "$mod_id"
    done

    print -P ""
    print -P "============================================="
    print -P "%F{34}アンインストールが完了しました。%f"
    print -P "============================================="
    exit 0
fi


# ==============================================
# 通常セットアップモード
# ==============================================
print -P ""
print -P "%F{36}%B 開発環境セットアップ%b%f"
print -P "============================================="

if (( DRY_RUN )); then
    print -P "%F{33}[DRY-RUN モード] 実際には変更を行いません。%f"
    print -P "---------------------------------------------"
fi

print -P "情報: Zsh で実行されています (バージョン: $ZSH_VERSION)"
print -P "---------------------------------------------"

# --- モジュール選択 ---
typeset -a selected_module_ids

if (( ${#SELECT_MODULES[@]} > 0 )); then
    # --select で明示指定された場合
    selected_module_ids=("${SELECT_MODULES[@]}")

elif (( ALL_FLAG )); then
    # --all の場合: 全モジュールを選択
    for entry in "${MODULES[@]}"; do
        selected_module_ids+=("${entry[(ws:|:)1]}")
    done

elif [[ -t 0 ]]; then
    # TTY 環境: インタラクティブ選択（チェックボックスUI）
    print -P ""

    # チェックボックスメニュー用の項目を構築
    typeset -a menu_items
    for entry in "${MODULES[@]}"; do
        local mod_name="${entry[(ws:|:)2]}"
        local mod_desc="${entry[(ws:|:)3]}"
        local mod_default="${entry[(ws:|:)4]}"
        menu_items+=("${mod_name}|${mod_desc}|${mod_default}")
    done

    # チェックボックスメニュー表示
    local selection
    selection=$(checkbox_menu "${menu_items[@]}")

    if [[ -z "$selection" ]]; then
        print -P ""
        print -P "%F{220}モジュールが選択されませんでした。終了します。%f"
        exit 0
    fi

    # 選択されたインデックスからモジュール ID を取得
    for idx in ${(s: :)selection}; do
        selected_module_ids+=("${MODULES[$idx][(ws:|:)1]}")
    done

    print -P ""
else
    # 非 TTY 環境（CI / パイプ）: --all と同等
    print -P "情報: 非インタラクティブ環境を検出。全モジュールをインストールします。"
    for entry in "${MODULES[@]}"; do
        selected_module_ids+=("${entry[(ws:|:)1]}")
    done
fi

# 選択されたモジュールを表示
print -P ""
print -P "%F{36}選択されたモジュール:%f"
for mod_id in "${selected_module_ids[@]}"; do
    for entry in "${MODULES[@]}"; do
        if [[ "${entry[(ws:|:)1]}" == "$mod_id" ]]; then
            print -P "  - ${entry[(ws:|:)2]} (${entry[(ws:|:)3]})"
            break
        fi
    done
done
print -P "---------------------------------------------"

# --- 選択されたモジュールを順次セットアップ ---
for mod_id in "${selected_module_ids[@]}"; do
    run_module_setup "$mod_id"
done

# --- 完了 ---
print -P ""
print -P "============================================="
if (( DRY_RUN )); then
    print -P "%F{33}[DRY-RUN] 上記が実行される変更内容です。実際に適用するには --dry-run を外して再実行してください。%f"
else
    print -P "%F{34}セットアップが正常に完了しました。%f"

    # Zsh が選択されていた場合のみシェル再起動を案内
    for mod_id in "${selected_module_ids[@]}"; do
        if [[ "$mod_id" == "zsh" ]]; then
            print -P "全ての変更を有効にするために、Zsh シェルを%B再起動%bするか '%Bexec zsh%b' を実行してください。"
            print -P "(source ~/.zshrc は環境が汚れる場合があるため、exec zsh を推奨します)"
            break
        fi
    done
fi
print -P "============================================="

exit 0

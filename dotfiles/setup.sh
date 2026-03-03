#!/usr/bin/env zsh

# ---------------------------------------------
# Zsh 環境セットアップスクリプト
#
# 使用法:
#   zsh setup.sh              通常セットアップ（べき等）
#   zsh setup.sh --dry-run    変更内容のプレビューのみ
#   zsh setup.sh --uninstall  バックアップから復元
#   zsh setup.sh --help       ヘルプ表示
#
# 機能:
# - 依存コマンドの確認 (git)
# - Zinit (プラグインマネージャー) のインストール
# - 設定ディレクトリの作成 (~/.zsh)
# - 設定ファイルの配置 (.zshrc, plugins.zsh, aliases.zsh, .p10k.zsh)
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

while (( $# > 0 )); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --uninstall)
            UNINSTALL=1
            ;;
        --help|-h)
            print -P "使用法: zsh $0 [オプション]"
            print -P ""
            print -P "オプション:"
            print -P "  --dry-run    変更内容のプレビューのみ（実際には変更しない）"
            print -P "  --uninstall  バックアップから元の状態に復元"
            print -P "  --help, -h   このヘルプを表示"
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
        print -P "情報: 既存の ${label} を ${dst}${BACKUP_SUFFIX} にバックアップしました。"
    fi

    # 配置処理
    run_cmd command cp -p "$src" "$dst" || {
        print -P "%F{160}エラー: ${label} の配置に失敗しました。%f" >&2
        exit 1
    }
    print -P "情報: ${label} を配置しました。"
}


# ==============================================
# アンインストールモード
# ==============================================
if (( UNINSTALL )); then
    print -P "アンインストール（復元）を開始します..."
    print -P "---------------------------------------------"

    if (( DRY_RUN )); then
        print -P "%F{33}[DRY-RUN モード] 実際には変更を行いません。%f"
        print -P "---------------------------------------------"
    fi

    local restored=0

    for entry in "${MANAGED_FILES[@]}"; do
        # パイプ区切りでパース
        local dst="${${entry}[(ws:|:)2]}"
        local label="${${entry}[(ws:|:)3]}"

        # Zsh Glob 限定子で最新のバックアップを検索
        # (N): マッチなしでもエラーにしない, (.): 通常ファイル, (om): 更新日時の新しい順, [1]: 最初の1つ
        local latest_backup=( "${dst}.backup."*(N.om[1]) )

        if (( ${#latest_backup[@]} > 0 )); then
            # バックアップが存在する → 復元
            print -P "復元: ${label} をバックアップ (${latest_backup[1]:t}) から戻します。"
            run_cmd command mv "${latest_backup[1]}" "$dst" || {
                print -P "%F{160}エラー: ${label} の復元に失敗しました。%f" >&2
                exit 1
            }
            restored=1
        elif [[ -f "$dst" || -h "$dst" ]]; then
            # バックアップなし＝セットアップ前に存在しなかったファイル → 削除
            print -P "削除: ${label} を削除します（セットアップ前の状態に復元）。"
            run_cmd command rm -f "$dst" || {
                print -P "%F{160}エラー: ${label} の削除に失敗しました。%f" >&2
                exit 1
            }
            restored=1
        else
            print -P "情報: ${label} は配置されていません。スキップします。"
        fi
    done

    print -P "---------------------------------------------"
    if (( restored )); then
        print -P "%F{34}アンインストールが完了しました。%f"
    else
        print -P "情報: 復元・削除対象のファイルはありませんでした。"
    fi
    print -P "NOTE: Zinit 本体は削除されていません。不要な場合は以下を手動で削除してください:"
    print -P "  rm -rf ${ZINIT_HOME:h}"
    print -P "---------------------------------------------"
    exit 0
fi


# ==============================================
# 通常セットアップモード
# ==============================================
print -P "Zsh環境のセットアップを開始します..."
print -P "---------------------------------------------"

if (( DRY_RUN )); then
    print -P "%F{33}[DRY-RUN モード] 実際には変更を行いません。%f"
    print -P "---------------------------------------------"
fi

print -P "情報: Zsh で実行されています (バージョン: $ZSH_VERSION)"
print -P "---------------------------------------------"


# --- 依存コマンドの確認 ---
if ! command -v git >/dev/null 2>&1; then
    print -P "%F{160}エラー: git コマンドが見つかりません。インストールしてください。%f" >&2
    exit 1
fi
print -P "情報: git が利用可能です ($(command git --version))"
print -P "---------------------------------------------"


# --- Zinit (プラグインマネージャー) のインストール ---
print -P "Zinit の状態を確認・インストールします..."
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    print -P "%F{33} %F{220}Zinit (%F{33}zdharma-continuum/zinit%F{220}) をインストール中...%f"
    # ディレクトリ作成（パーミッションは 700 に固定）
    run_cmd command mkdir -p -m 700 "$(dirname "$ZINIT_HOME")" || {
        print -P "%F{160}エラー: Zinit 用ディレクトリの作成に失敗しました。%f" >&2
        exit 1
    }
    # git clone を実行（サプライチェーンリスク軽減のためタグをピン留め）
    run_cmd command git clone --branch "$ZINIT_VERSION" --depth 1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" || {
        if (( ! DRY_RUN )); then
            print -P "%F{160}エラー: Zinit の git clone に失敗しました。%f" >&2
            exit 1
        fi
    }
    if (( ! DRY_RUN )); then
        print -P "%F{33} %F{34}Zinit ${ZINIT_VERSION} のインストールに成功しました。%f"
    fi
else
    print -P "情報: Zinit は既にインストールされています。"
fi
print -P "---------------------------------------------"


# --- Zsh 設定ディレクトリの作成 ---
if [[ ! -d "$ZSH_CONFIG_DIR" ]]; then
    run_cmd command mkdir -p -m 700 "$ZSH_CONFIG_DIR" || {
        print -P "%F{160}エラー: $ZSH_CONFIG_DIR の作成に失敗しました。%f" >&2
        exit 1
    }
    print -P "情報: $ZSH_CONFIG_DIR を作成しました。"
else
    print -P "情報: $ZSH_CONFIG_DIR は既に存在します。"
fi
print -P "---------------------------------------------"


# --- 設定ファイルの配置 ---
print -P "設定ファイルを配置します..."

for entry in "${MANAGED_FILES[@]}"; do
    # パイプ区切りでパース
    local src="${${entry}[(ws:|:)1]}"
    local dst="${${entry}[(ws:|:)2]}"
    local label="${${entry}[(ws:|:)3]}"
    local hint="${${entry}[(ws:|:)4]}"
    install_config "$src" "$dst" "$label" "$hint"
done

print -P "---------------------------------------------"


# --- 完了 ---
if (( DRY_RUN )); then
    print -P "%F{33}[DRY-RUN] 上記が実行される変更内容です。実際に適用するには --dry-run を外して再実行してください。%f"
else
    print -P "%F{34}セットアップスクリプトが正常に完了しました。%f"
    print -P "全ての変更を有効にするために、Zsh シェルを%B再起動%bするか '%Bexec zsh%b' を実行してください。"
    print -P "(source ~/.zshrc は環境が汚れる場合があるため、exec zsh を推奨します)"
fi
print -P "---------------------------------------------"

exit 0

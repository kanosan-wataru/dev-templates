# ----------------------------
# Zinit (プラグインマネージャー) の読み込みとプラグイン設定
# ----------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"
fi

# zinit 関数が正常に定義されている場合のみプラグインを読み込む
# NOTE: shfmt 互換のため $+functions[] ではなく ${functions[]} で存在チェック
if [[ -n ${functions[zinit]} ]]; then

    # Powerlevel10k テーマ (v1.9.1)
    zinit ice depth=1 ver"v1.9.1"
    zinit light romkatv/powerlevel10k
    # Powerlevel10k ユーザー設定ファイルが存在すれば source
    [[ ! -f "${ZDOTDIR:-$HOME}/.zsh/.p10k.zsh" ]] || source "${ZDOTDIR:-$HOME}/.zsh/.p10k.zsh"

    # コンプリーション (fpathに追加するため compinit より前に読み込む) (0.9.0)
    zinit ice ver"0.9.0"
    zinit light zsh-users/zsh-completions

    # 補完システムの初期化（Zinit のキャッシュ最適化版を使用）
    autoload -Uz compinit
    zicompinit
    # compinit 前に intercept された compdef をリプレイ
    zicdreplay

    # zinit の補完を登録（compinit 後に行う必要がある）
    autoload -Uz _zinit
    compdef _zinit zinit

    # --- fzf (ファジーファインダー) ---
    # バージョンを変数で一元管理（バイナリと shell スクリプトの不整合を防止）
    FZF_VERSION="v0.70.0"
    FZF_RAW_URL="https://raw.githubusercontent.com/junegunn/fzf/${FZF_VERSION}/shell"
    # GitHub Releases からプラットフォーム固有のバイナリを自動インストール
    zinit ice from"gh-r" as"program" ver"${FZF_VERSION}"
    zinit light junegunn/fzf
    # fzf-tab: Tab 補完を fzf に置き換え (v1.2.0)
    # NOTE: compinit の後、かつ autosuggestions/syntax-highlighting より前に読み込む
    zinit ice ver"v1.2.0"
    zinit light Aloxaf/fzf-tab

    # --- Turbo mode（遅延読み込み）---
    # プロンプト表示後にバックグラウンドで読み込み、シェル起動を高速化

    # fzf キーバインディング (Ctrl-R: 履歴検索, Ctrl-T: ファイル検索, Alt-C: ディレクトリ移動)
    zinit ice wait lucid
    zinit snippet "${FZF_RAW_URL}/key-bindings.zsh"
    # fzf 補完 (** トリガー)
    zinit ice wait lucid
    zinit snippet "${FZF_RAW_URL}/completion.zsh"

    # オートサジェスチョン (v0.7.1)
    zinit ice wait lucid ver"v0.7.1"
    zinit light zsh-users/zsh-autosuggestions
    # シンタックスハイライト (プラグイン群の中で最後に読み込む) (0.8.0)
    zinit ice wait lucid ver"0.8.0"
    zinit light zsh-users/zsh-syntax-highlighting
else
    print -P "%F{160}Zinit が見つからない、または読み込みに失敗しました。セットアップスクリプトを確認してください。%f"
    # Zinit が使えなくても標準の補完システムだけは初期化しておく
    autoload -Uz compinit
    compinit
fi

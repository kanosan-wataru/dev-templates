# dev-templates

開発環境の設定ファイル（dotfiles）を管理するリポジトリです。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `dotfiles/.zshrc` | Zsh エントリーポイント（履歴設定、モジュール読み込み） |
| `dotfiles/.zsh/plugins.zsh` | Zinit プラグイン設定 |
| `dotfiles/.zsh/aliases.zsh` | エイリアス定義 |
| `dotfiles/.zsh/.p10k.zsh` | Powerlevel10k テーマ設定 |
| `dotfiles/setup.sh` | セットアップスクリプト（自動インストール・配置） |

## 動作要件

- **Zsh** (v5.0 以上)
- **Git**

## セットアップ

```bash
git clone https://github.com/kanosan-wataru/dev-templates.git
cd dev-templates
zsh dotfiles/setup.sh
```

セットアップスクリプトは以下を自動で行います:

1. Zsh / Git の存在確認
2. [Zinit](https://github.com/zdharma-continuum/zinit) プラグインマネージャーのインストール
3. `~/.zsh` ディレクトリの作成（パーミッション 700）
4. 設定ファイルの配置（`.zshrc`, `plugins.zsh`, `aliases.zsh`, `.p10k.zsh`）
   - 既存ファイルはタイムスタンプ付きでバックアップ

完了後、`exec zsh` でシェルを再起動してください。

## インストールされるプラグイン

| プラグイン | 説明 |
|-----------|------|
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | 高速・高機能なプロンプトテーマ |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | 追加の補完定義 |
| [fzf](https://github.com/junegunn/fzf) | ファジーファインダー（Ctrl-R: 履歴検索, Ctrl-T: ファイル検索, Alt-C: ディレクトリ移動） |
| [fzf-tab](https://github.com/Aloxaf/fzf-tab) | Tab 補完を fzf に置き換え（プレビュー付き補完メニュー） |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | 履歴ベースのコマンド候補表示 |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | コマンドラインのシンタックスハイライト |

## ディレクトリ構成

```
dev-templates/
├── dotfiles/
│   ├── .zsh/
│   │   ├── plugins.zsh    # Zinit プラグイン設定
│   │   ├── aliases.zsh    # エイリアス定義
│   │   └── .p10k.zsh      # Powerlevel10k 設定
│   ├── .zshrc              # エントリーポイント（履歴設定 + モジュール読み込み）
│   └── setup.sh            # セットアップスクリプト
├── .gitignore
└── README.md
```

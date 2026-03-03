# dev-templates

開発環境の設定ファイル（dotfiles）を管理するリポジトリです。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `dotfiles/.zshrc` | Zsh メイン設定（履歴、Zinit プラグイン、エイリアス） |
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
4. `.zshrc` / `.p10k.zsh` の配置（既存ファイルはタイムスタンプ付きでバックアップ）

完了後、`exec zsh` でシェルを再起動してください。

## インストールされるプラグイン

| プラグイン | 説明 |
|-----------|------|
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | 高速・高機能なプロンプトテーマ |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | 追加の補完定義 |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | 履歴ベースのコマンド候補表示 |
| [history-search-multi-word](https://github.com/zdharma-continuum/history-search-multi-word) | 複数単語での履歴検索 |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | コマンドラインのシンタックスハイライト |

## ディレクトリ構成

```
dev-templates/
├── dotfiles/
│   ├── .zsh/
│   │   └── .p10k.zsh      # Powerlevel10k 設定
│   ├── .zshrc              # Zsh メイン設定
│   └── setup.sh            # セットアップスクリプト
├── .gitignore
└── README.md
```

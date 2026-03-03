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

### オプション

| オプション | 説明 |
|-----------|------|
| `--dry-run` | 実際の変更を行わず、実行内容をプレビュー表示 |
| `--uninstall` | バックアップから設定ファイルを復元 |
| `--help`, `-h` | ヘルプを表示 |

```bash
# 変更内容を事前に確認
zsh dotfiles/setup.sh --dry-run

# 設定ファイルをバックアップから復元
zsh dotfiles/setup.sh --uninstall
```

### セットアップの流れ

スクリプトは以下を自動で行います:

1. Zsh で実行されていることの確認（`$ZSH_VERSION` チェック）
2. Git の存在確認
3. [Zinit](https://github.com/zdharma-continuum/zinit) プラグインマネージャーのインストール
4. `~/.zsh` ディレクトリの作成（パーミッション 700）
5. 設定ファイルの配置（`.zshrc`, `plugins.zsh`, `aliases.zsh`, `.p10k.zsh`）
   - 既存ファイルと内容が同一の場合はスキップ（べき等）
   - 内容が異なる場合はタイムスタンプ付きでバックアップ後に配置

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

## CI

`dotfiles/**` または `.github/workflows/**` に変更を含む Pull Request で、GitHub Actions によるチェックが自動実行されます:

- **Zsh 構文チェック** (`zsh -n`): `dotfiles/` 配下の `.zsh`, `.sh`, `.zshrc` ファイル（`.p10k.zsh` を除く）の構文エラーを検出

## ディレクトリ構成

```
dev-templates/
├── .github/workflows/
│   └── ci.yml              # CI: zsh -n 構文チェック
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

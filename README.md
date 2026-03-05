# dev-templates

開発環境の設定ファイル（dotfiles）と AI ツールを管理するリポジトリです。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `dotfiles/.zshrc` | Zsh エントリーポイント（履歴設定、モジュール読み込み） |
| `dotfiles/.zsh/plugins.zsh` | Zinit プラグイン設定 |
| `dotfiles/.zsh/aliases.zsh` | エイリアス定義 |
| `dotfiles/.zsh/.p10k.zsh` | Powerlevel10k テーマ設定 |
| `dotfiles/setup.sh` | セットアップスクリプト（インタラクティブ選択・自動インストール） |
| `dotfiles/modules/*.sh` | モジュール定義ファイル（各モジュールのセットアップ・アンインストール処理） |

## 動作要件

- **Zsh** (v5.0 以上)
- **Git**
- **Node.js** v18+ / **npm**（Claude Code / Gemini CLI を利用する場合）

## セットアップ

```bash
git clone https://github.com/kanosan-wataru/dev-templates.git
cd dev-templates
zsh dotfiles/setup.sh
```

実行すると、チェックボックスUIでインストールするモジュールを選択できます:

```
インストールするモジュールを選択してください:
（↑↓/jk: 移動, スペース: 選択, a: 全選択, Enter: 確定, q: キャンセル）

> [x] Zsh 設定一式       Zinit + プラグイン + テーマ + エイリアス
  [ ] モダン CLI ツール  eza / bat / fd / ripgrep
  [ ] Claude Code        Anthropic CLI (Node.js v18+ 必要)
  [ ] Gemini CLI         Google AI CLI (Node.js v18+ 必要)
```

### モジュール

| モジュール | 説明 | 依存 |
|-----------|------|------|
| **Zsh 設定一式** | Zinit + プラグイン + テーマ + エイリアス | Git |
| **モダン CLI ツール** | eza / bat / fd / ripgrep | Homebrew (macOS) or apt (Linux) |
| **Claude Code** | Anthropic の AI コーディングアシスタント CLI | Node.js v18+ |
| **Gemini CLI** | Google の AI CLI | Node.js v18+ |

### オプション

| オプション | 説明 |
|-----------|------|
| `--all` | 全モジュールを一括インストール（非インタラクティブ） |
| `--select MODULE` | 特定モジュールを指定（複数指定可） |
| `--dry-run` | 実際の変更を行わず、実行内容をプレビュー表示 |
| `--uninstall` | 全モジュールをアンインストール（バックアップから復元） |
| `--help`, `-h` | ヘルプを表示 |

```bash
# インタラクティブ選択（デフォルト）
zsh dotfiles/setup.sh

# 全モジュール一括インストール
zsh dotfiles/setup.sh --all

# 特定モジュールのみインストール
zsh dotfiles/setup.sh --select zsh --select claude-code

# 変更内容を事前に確認
zsh dotfiles/setup.sh --all --dry-run

# 設定ファイルをバックアップから復元・ツールをアンインストール
zsh dotfiles/setup.sh --uninstall
```

非 TTY 環境（CI / パイプ）では自動的に `--all` と同等の動作になります。
`tput` が利用できない TTY 環境では、デフォルト選択（Zsh 設定一式）のみインストールされます。

### セットアップの流れ

#### Zsh 設定一式
1. Zsh で実行されていることの確認（`$ZSH_VERSION` チェック）
2. Git の存在確認
3. [Zinit](https://github.com/zdharma-continuum/zinit) プラグインマネージャーのインストール
4. `~/.zsh` ディレクトリの作成（パーミッション 700）
5. 設定ファイルの配置（`.zshrc`, `plugins.zsh`, `aliases.zsh`, `.p10k.zsh`）
   - 既存ファイルと内容が同一の場合はスキップ（べき等）
   - 内容が異なる場合はタイムスタンプ付きでバックアップ後に配置

#### モダン CLI ツール
1. OS 判定（macOS: Homebrew / Linux: apt）
2. 各ツール（eza, bat, fd, ripgrep）を順次インストール（既にインストール済みならスキップ）
3. エイリアス（`ls` → eza, `cat` → bat 等）は `aliases.zsh` で条件付き設定済み

#### Claude Code
1. Node.js v18+ / npm の存在確認
2. `npm install -g @anthropic-ai/claude-code`（既にインストール済みならスキップ）

#### Gemini CLI
1. Node.js v18+ / npm の存在確認
2. `npm install -g @google/gemini-cli`（既にインストール済みならスキップ）

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
- **Setup Dry Run**: `setup.sh --all --dry-run` を実行し、セットアップスクリプトの動作を検証
- **Shell Format Check**: `shfmt` による `.zsh/*.zsh` ファイルのフォーマットチェック

構文チェックと dry-run は **Ubuntu** と **macOS** の両環境で実行されます。

## ディレクトリ構成

```
dev-templates/
├── .github/workflows/
│   └── ci.yml              # CI: 構文チェック + dry-run テスト（Ubuntu/macOS）
├── dotfiles/
│   ├── .zsh/
│   │   ├── plugins.zsh    # Zinit プラグイン設定
│   │   ├── aliases.zsh    # エイリアス定義
│   │   └── .p10k.zsh      # Powerlevel10k 設定
│   ├── modules/
│   │   ├── zsh.sh          # モジュール: Zsh 設定一式
│   │   ├── modern-cli.sh   # モジュール: モダン CLI ツール
│   │   ├── claude-code.sh  # モジュール: Claude Code
│   │   └── gemini-cli.sh   # モジュール: Gemini CLI
│   ├── .zshrc              # エントリーポイント（履歴設定 + モジュール読み込み）
│   └── setup.sh            # セットアップコア（UI + 共通関数 + モジュール動的読み込み）
├── .editorconfig              # エディタ設定（インデント・改行コード統一）
├── .gitignore
└── README.md
```

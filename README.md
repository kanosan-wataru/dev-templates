# dev-templates

開発環境の設定ファイル（dotfiles）と開発ツールを管理するリポジトリです。
Zsh ベースのモジュラー構成で、macOS / Linux に対応しています。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `dotfiles/.zshrc` | Zsh エントリーポイント（履歴設定、モジュール読み込み） |
| `dotfiles/.zsh/plugins.zsh` | Zinit プラグイン設定 |
| `dotfiles/.zsh/aliases.zsh` | エイリアス定義（git/docker エイリアス、fzf 連携関数） |
| `dotfiles/.zsh/node.zsh` | fnm (Fast Node Manager) 初期化 |
| `dotfiles/.zsh/python.zsh` | pyenv / pyenv-virtualenv 初期化 |
| `dotfiles/.zsh/ssh.zsh` | 1Password SSH エージェント設定（WSL 用） |
| `dotfiles/.zsh/env.zsh` | 環境変数読み込み（`~/.claude/.env` から MCP サーバー用等） |
| `dotfiles/.claude/` | Claude Code 設定テンプレート一式（CLAUDE.md, スキル, エージェント等） |
| `dotfiles/.codex/` | Codex CLI 設定テンプレート（モデル設定、サンドボックスルール） |
| `dotfiles/.gitconfig.shared` | Git 共有設定（include.path 経由で読み込み） |
| `dotfiles/.gitignore_global` | グローバル gitignore |
| `dotfiles/setup.sh` | セットアップスクリプト（インタラクティブ選択・自動インストール） |
| `dotfiles/modules/*.sh` | モジュール定義ファイル（各モジュールのセットアップ・アンインストール処理） |

## 動作要件

- **Zsh** (v5.0 以上)
- **Git**

## セットアップ

```bash
git clone https://github.com/kanosan-wataru/dev-templates.git
cd dev-templates
zsh dotfiles/setup.sh
```

実行すると、チェックボックス UI でインストールするモジュールを選択できます:

```
インストールするモジュールを選択してください:
（↑↓/jk: 移動, スペース: 選択, a: 全選択, Enter: 確定, q: キャンセル）

> [x] Zsh 設定一式         Zinit + プラグイン + テーマ + エイリアス
  [ ] Git グローバル設定    .gitconfig.shared + .gitignore_global
  [ ] モダン CLI ツール     eza / bat / fd / ripgrep
  [ ] Node.js 開発環境      fnm + Node.js LTS (バージョン管理)
  [ ] Claude Code           Anthropic CLI (Node.js v18+ 必要)
  [ ] Python 開発環境       pyenv + virtualenv (Python バージョン管理)
  [ ] Gemini CLI            Google AI CLI (Node.js v18+ 必要)
  [ ] Codex CLI              OpenAI CLI (Node.js v18+ 必要)
```

### モジュール

| モジュール | 説明 | 依存 |
|-----------|------|------|
| **Zsh 設定一式** | Zinit + プラグイン + テーマ + エイリアス | Git |
| **Git グローバル設定** | 共有 gitconfig + グローバル gitignore | Git |
| **モダン CLI ツール** | eza / bat / fd / ripgrep | Homebrew (macOS) / apt + wget + gpg (Linux) |
| **Node.js 開発環境** | fnm + Node.js LTS 自動インストール | Homebrew (macOS) / curl + unzip (Linux) |
| **Claude Code** | Anthropic の AI コーディングアシスタント CLI + 設定テンプレート | Node.js v18+ / jq（MCP マージ用、任意） |
| **Python 開発環境** | pyenv + pyenv-virtualenv | Git + ビルド依存パッケージ |
| **Gemini CLI** | Google の AI CLI | Node.js v18+ |
| **Codex CLI** | OpenAI の AI コーディングアシスタント CLI + 設定テンプレート | Node.js v18+ |

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
zsh dotfiles/setup.sh --select zsh --select node

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

#### Git グローバル設定
1. Git の存在確認
2. `.gitconfig.shared` と `.gitignore_global` を `$HOME` に配置
3. `include.path` で共有設定をリンク（既存の `.gitconfig` を上書きしない）
4. `core.excludesFile` でグローバル gitignore を紐付け
5. `user.name` / `user.email` の設定ガイドを表示

#### モダン CLI ツール
1. OS 判定（macOS: Homebrew / Linux: apt）
2. 各ツール（eza, bat, fd, ripgrep）を順次インストール（既にインストール済みならスキップ）
3. エイリアス（`ls` → eza, `cat` → bat 等）は `aliases.zsh` で条件付き設定済み

#### Node.js 開発環境
1. [fnm](https://github.com/Schniz/fnm) (Fast Node Manager) のインストール（macOS: Homebrew / Linux: GitHub Releases）
2. Node.js LTS の自動インストール + デフォルト設定
3. `node.zsh` の配置（fnm 初期化・`--use-on-cd` 対応）

#### Python 開発環境
1. ビルド依存パッケージのインストール（macOS: Homebrew / Linux: apt）
2. [pyenv](https://github.com/pyenv/pyenv) のインストール（macOS: Homebrew / Linux: git clone）
3. [pyenv-virtualenv](https://github.com/pyenv/pyenv-virtualenv) プラグインのインストール
4. `python.zsh` の配置（pyenv 初期化）

#### Claude Code
1. Node.js v18+ / npm の存在確認
2. `npm install -g @anthropic-ai/claude-code`（既にインストール済みならスキップ）
3. 設定ファイルの配置（CLAUDE.md, settings.json, hookify ルール, スキル, エージェント）
4. `env.zsh` の配置（`~/.claude/.env` からの環境変数読み込み）
5. MCP サーバー設定の `~/.claude.json` へのマージ（jq 使用、べき等。jq 未インストール時はスキップ）
6. `~/.claude/.env` に環境変数を設定するよう案内表示

#### Gemini CLI
1. Node.js v18+ / npm の存在確認
2. `npm install -g @google/gemini-cli`（既にインストール済みならスキップ）

#### Codex CLI
1. Node.js v18+ / npm の存在確認
2. `npm install -g @openai/codex`（既にインストール済みならスキップ）
3. 設定ファイルの配置（config.toml, rules/default.rules）

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

## Docker (Dev Containers)

Docker Compose + VS Code Dev Containers でコンテナ内に開発環境を構築できます。

- **Docker Compose v2.24+** が必要です（`env_file` の `required` オプションを使用）

### セットアップ

```bash
# .env ファイルを作成して API キーを設定
cp .env.example .env
# .env を編集して ANTHROPIC_API_KEY 等を設定

# コンテナをビルド
docker compose build

# コンテナを起動
docker compose up -d
docker compose exec devcontainer zsh
```

VS Code / Cursor から Dev Containers として接続する場合は、コマンドパレットから「Dev Containers: Reopen in Container」を実行してください。

### ホストファイルのマウント

コンテナ起動時にホストの設定ファイルが read-only でマウントされます:

| ホスト | コンテナ | 用途 |
|--------|----------|------|
| `~/.ssh` | `/home/dev/.ssh` | SSH 鍵（Git の SSH 接続等） |
| `~/.gitconfig` | `/home/dev/.gitconfig` | Git ユーザー設定 |

### 含まれるツール

コンテナイメージには `setup.sh --all` で全モジュールがプリインストールされています:

- Zsh + Zinit + Powerlevel10k
- Git グローバル設定
- モダン CLI ツール (eza, bat, fd, ripgrep)
- Node.js (fnm + LTS)
- Claude Code
- Python (pyenv)
- Gemini CLI
- Codex CLI

### API キーの設定

`.env` ファイルに API キーを記述すると、コンテナ内の環境変数として利用できます:

```bash
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=sk-...
```

## CI

`dotfiles/**` または `.github/workflows/**` に変更を含む Pull Request で、GitHub Actions によるチェックが自動実行されます:

- **Zsh 構文チェック** (`zsh -n`): `dotfiles/` 配下の `.zsh`, `.sh`, `.zshrc` ファイル（`.p10k.zsh` を除く）の構文エラーを検出
- **Setup Dry Run**: `setup.sh --all --dry-run` を実行し、セットアップスクリプトの動作を検証
- **Shell Format Check**: `shfmt` による `.zsh/*.zsh` ファイルのフォーマットチェック

構文チェックと dry-run は **Ubuntu** と **macOS** の両環境で実行されます。

## ディレクトリ構成

```
dev-templates/
├── .claude/
│   ├── docs/
│   │   └── claude-code-config.md  # Claude Code 設定リファレンス
│   └── rules/                     # コーディング・開発ルール
├── .devcontainer/
│   └── devcontainer.json     # VS Code Dev Containers 設定
├── .github/workflows/
│   └── ci.yml                # CI: 構文チェック + dry-run テスト（Ubuntu/macOS）
├── Dockerfile                 # 開発環境コンテナ定義
├── docker-compose.yml         # Docker Compose 設定
├── .dockerignore               # Docker ビルドコンテキスト除外設定
├── .env.example               # 環境変数テンプレート（API キー等）
├── dotfiles/
│   ├── .claude/
│   │   ├── CLAUDE.md            # グローバル Claude 設定
│   │   ├── settings.json        # 許可ツール・プラグイン設定
│   │   ├── mcp-servers.json     # MCP サーバー設定テンプレート
│   │   ├── hookify.*.local.md   # hookify ガードレール（3 ファイル）
│   │   ├── skills/              # スキル定義（7 スキル）
│   │   └── agents/              # エージェント定義（3 エージェント）
│   ├── .codex/
│   │   ├── config.toml          # Codex CLI モデル設定テンプレート
│   │   └── rules/
│   │       └── default.rules    # サンドボックス許可ルール
│   ├── .zsh/
│   │   ├── plugins.zsh      # Zinit プラグイン設定
│   │   ├── aliases.zsh      # エイリアス定義
│   │   ├── node.zsh         # fnm 初期化
│   │   ├── python.zsh       # pyenv 初期化
│   │   ├── ssh.zsh          # 1Password SSH エージェント（WSL 用）
│   │   └── env.zsh          # 環境変数読み込み（~/.claude/.env）
│   ├── modules/
│   │   ├── zsh.sh            # モジュール: Zsh 設定一式
│   │   ├── git.sh            # モジュール: Git グローバル設定
│   │   ├── modern-cli.sh     # モジュール: モダン CLI ツール
│   │   ├── node.sh           # モジュール: Node.js 開発環境
│   │   ├── claude-code.sh    # モジュール: Claude Code
│   │   ├── codex-cli.sh      # モジュール: Codex CLI
│   │   ├── python.sh         # モジュール: Python 開発環境
│   │   └── gemini-cli.sh     # モジュール: Gemini CLI
│   ├── .gitconfig.shared     # Git 共有設定（include.path 経由）
│   ├── .gitignore_global     # グローバル gitignore
│   ├── .zshrc                # エントリーポイント（履歴設定 + モジュール読み込み）
│   └── setup.sh              # セットアップコア（UI + 共通関数 + モジュール動的読み込み）
├── .editorconfig              # エディタ設定（インデント・改行コード統一）
├── .gitignore
└── README.md
```

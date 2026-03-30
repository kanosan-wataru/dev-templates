# dev-templates

開発環境の設定ファイル（dotfiles）と開発ツールを管理するリポジトリです。
Bash スクリプト（セットアップ）+ Zsh（対話シェル）のモジュラー構成で、macOS / Linux に対応しています。

## 含まれる設定

| ファイル | 説明 |
|---------|------|
| `dotfiles/setup.sh` | セットアップスクリプト（bash、インタラクティブ選択・自動インストール） |
| `dotfiles/lib/*.sh` | 共通ライブラリ（colors.sh, array.sh, backup.sh, tui.sh） |
| `dotfiles/modules/*.sh` | モジュール定義ファイル（各モジュールのセットアップ・アンインストール処理） |
| `dotfiles/.zshrc` | Zsh エントリーポイント（履歴設定、モジュール読み込み） |
| `dotfiles/.bashrc` | Bash エントリーポイント（`.shell/` の共有設定を読み込み） |
| `dotfiles/.zsh/plugins.zsh` | Zinit プラグイン設定 |
| `dotfiles/.zsh/.p10k.zsh` | Powerlevel10k テーマ設定 |
| `dotfiles/.shell/aliases.sh` | エイリアス定義（git/docker エイリアス、fzf 連携関数） |
| `dotfiles/.shell/env.sh` | 環境変数読み込み（`~/.claude/.env` から MCP サーバー用等） |
| `dotfiles/.shell/node.sh` | fnm (Fast Node Manager) 初期化 |
| `dotfiles/.shell/python.sh` | pyenv / uv 初期化 |
| `dotfiles/.shell/1password.sh` | 1Password SSH エージェント設定（WSL/Linux/macOS 自動判定） |
| `dotfiles/.claude/` | Claude Code 設定テンプレート一式（CLAUDE.md, スキル, エージェント等） |
| `dotfiles/.codex/` | Codex CLI 設定テンプレート（モデル設定、サンドボックスルール） |
| `dotfiles/.gemini/` | Gemini CLI 設定テンプレート（セッション設定、カスタム指示） |
| `dotfiles/.gitconfig.shared` | Git 共有設定（include.path 経由で読み込み） |
| `dotfiles/.gitignore_global` | グローバル gitignore |

## 動作要件

- **Bash** (v4.0 以上)
- **Git**

## セットアップ

```bash
git clone https://github.com/kanosan-wataru/dev-templates.git
cd dev-templates
bash dotfiles/setup.sh
```

実行すると、チェックボックス UI でインストールするモジュールを選択できます:

```
インストールするモジュールを選択してください:
（↑↓/jk: 移動, スペース: 選択, a: 全選択, Enter: 確定, q: キャンセル）

> [x] Zsh 設定一式         Zinit + プラグイン + テーマ + エイリアス
  [ ] Git グローバル設定    .gitconfig.shared + .gitignore_global
  [ ] 1Password            CLI + SSH エージェント + Git 署名
  [ ] モダン CLI ツール     eza / bat / fd / ripgrep
  [ ] Node.js 開発環境      fnm + Node.js LTS (バージョン管理)
  [ ] Docker                Docker Engine + Compose + NVIDIA GPU
  [ ] Claude Code           Anthropic CLI (Node.js v18+ 必要)
  [ ] AWS CLI               AWS CLI v2
  [ ] Python 開発環境       pyenv + uv (Python バージョン管理 + パッケージ管理)
  [ ] Gemini CLI            Google AI CLI (Node.js v20+ 必要)
  [ ] Codex CLI              OpenAI CLI (Node.js v18+ 必要)
```

### モジュール

| モジュール | 説明 | 依存 |
|-----------|------|------|
| **Zsh 設定一式** | Zinit + プラグイン + テーマ + エイリアス | Git |
| **Git グローバル設定** | 共有 gitconfig + グローバル gitignore | Git |
| **1Password** | 1Password CLI + SSH エージェント + Git 署名設定 | — |
| **モダン CLI ツール** | eza / bat / fd / ripgrep | Homebrew (macOS) / apt + wget + gpg (Linux) |
| **Node.js 開発環境** | fnm + Node.js LTS 自動インストール | Homebrew (macOS) / curl + unzip (Linux) |
| **Docker** | Docker Engine + Compose + NVIDIA GPU サポート | Homebrew (macOS) / apt + curl (Linux) |
| **Claude Code** | Anthropic の AI コーディングアシスタント CLI + 設定テンプレート | Node.js v18+ / jq（MCP マージ用、任意） |
| **AWS CLI** | AWS CLI v2 | curl + unzip (Linux) / Homebrew (macOS) |
| **Python 開発環境** | pyenv + Python + uv (パッケージマネージャー) | Git + ビルド依存パッケージ |
| **Gemini CLI** | Google の AI CLI | Node.js v20+ |
| **Codex CLI** | OpenAI の AI コーディングアシスタント CLI + 設定テンプレート | Node.js v18+ |

### オプション

| オプション | 説明 |
|-----------|------|
| `--all` | 全モジュールを一括インストール（非インタラクティブ） |
| `--select MODULE` | 特定モジュールを指定（複数指定可） |
| `--dry-run` | 実際の変更を行わず、実行内容をプレビュー表示 |
| `--uninstall` | 全モジュールをアンインストール（バックアップから復元） |
| `--status` | 各モジュールのインストール状態を一覧表示 |
| `--force`, `-f` | 差分確認・モジュール内プロンプトをスキップ（完全非対話） |
| `--upgrade` | インストール済みツールを最新バージョンに更新 |
| `--help`, `-h` | ヘルプを表示 |

```bash
# インタラクティブ選択（デフォルト）
bash dotfiles/setup.sh

# 全モジュール一括インストール
bash dotfiles/setup.sh --all

# 特定モジュールのみインストール（位置引数）
bash dotfiles/setup.sh zsh node docker

# 特定モジュールのみインストール（--select）
bash dotfiles/setup.sh --select zsh --select node

# 変更内容を事前に確認
bash dotfiles/setup.sh --all --dry-run

# インストール済みツールを最新版に更新
bash dotfiles/setup.sh --upgrade --all

# 完全非対話モード（CI 向け）
bash dotfiles/setup.sh zsh git --force

# 設定ファイルをバックアップから復元・ツールをアンインストール
bash dotfiles/setup.sh --uninstall
```

非 TTY 環境（CI / パイプ）では自動的に `--all` と同等の動作になります。
`tput` が利用できない TTY 環境では、デフォルト選択（Zsh 設定一式）のみインストールされます。

### セットアップの流れ

#### Zsh 設定一式
1. Git の存在確認
2. [Zinit](https://github.com/zdharma-continuum/zinit) プラグインマネージャーのインストール
3. `~/.zsh` / `~/.shell` ディレクトリの作成（パーミッション 700）
4. 設定ファイルの配置（`.zshrc`, `.bashrc`, `.zsh/plugins.zsh`, `.zsh/.p10k.zsh`, `.shell/*.sh`）
   - `.zshrc` / `.bashrc` は **source 分離方式**: 既存ファイルに `source` 行を追加するだけで、ユーザーのカスタマイズを保持
   - その他のファイルは差分プレビューを表示し、確認後に上書き（`--force` でスキップ可能）
   - 既存ファイルと内容が同一の場合はスキップ（べき等）
   - 内容が異なる場合はタイムスタンプ付きでバックアップ後に配置

#### Git グローバル設定
1. Git の存在確認
2. `.gitconfig.shared` と `.gitignore_global` を `$HOME` に配置
3. `include.path` で共有設定をリンク（既存の `.gitconfig` を上書きしない）
4. `core.excludesFile` でグローバル gitignore を紐付け
5. `user.name` / `user.email` の設定ガイドを表示

#### 1Password
1. 環境の自動判定（WSL / ネイティブ Linux / macOS）
2. 1Password CLI (`op`) のインストール（macOS: Homebrew / Linux: apt + GPG キー設定）
3. `1password.sh` の配置（`.shell/` に SSH エージェント設定・WSL リダイレクト対応）
4. SSH エージェントの設定案内（環境に応じたガイド表示）
5. Git コミット署名設定（`gpg.format=ssh` + `op-ssh-sign` の自動設定）

#### モダン CLI ツール
1. OS 判定（macOS: Homebrew / Linux: apt）
2. 各ツール（eza, bat, fd, ripgrep）を順次インストール（既にインストール済みならスキップ）
3. エイリアス（`ls` → eza, `cat` → bat 等）は `.shell/aliases.sh` で条件付き設定済み

#### Node.js 開発環境
1. [fnm](https://github.com/Schniz/fnm) (Fast Node Manager) のインストール（macOS: Homebrew / Linux: GitHub Releases）
2. Node.js LTS の自動インストール + デフォルト設定
3. `node.sh` の配置（`.shell/` に fnm 初期化・`--use-on-cd` 対応）

#### Docker
1. 環境の自動判定（Linux / macOS）
2. Docker Engine + Compose プラグインのインストール（Linux: apt + GPG キー設定 / macOS: Homebrew Cask で Docker Desktop）
3. docker グループへのユーザー追加（Linux のみ）
4. systemd サービスの自動起動設定（Linux のみ、systemctl 利用可能時）
5. NVIDIA Container Toolkit の自動インストール（NVIDIA GPU ドライバー検出時のみ）

#### AWS CLI
1. 環境の自動判定（Linux / macOS）
2. AWS CLI v2 のインストール（Linux: curl + unzip / macOS: Homebrew）

#### Python 開発環境
1. ビルド依存パッケージのインストール（macOS: Homebrew / Linux: apt）
2. [pyenv](https://github.com/pyenv/pyenv) のインストール（macOS: Homebrew / Linux: git clone）
3. [pyenv-virtualenv](https://github.com/pyenv/pyenv-virtualenv) プラグインのインストール
4. [uv](https://github.com/astral-sh/uv) パッケージマネージャーのインストール
5. `python.sh` の配置（`.shell/` に pyenv + uv 初期化）

#### Claude Code
1. Node.js v18+ / npm の存在確認
2. `npm install -g @anthropic-ai/claude-code`（既にインストール済みならスキップ）
3. 設定ファイルの配置（CLAUDE.md, settings.json, hookify ルール, スキル, エージェント）
4. `env.sh` の配置（`.shell/` に `~/.claude/.env` からの環境変数読み込み）
5. MCP サーバー設定の `~/.claude.json` へのマージ（jq 使用、べき等。jq 未インストール時はスキップ）
6. `~/.claude/.env` に環境変数を設定するよう案内表示

#### Gemini CLI
1. Node.js v20+ / npm の存在確認
2. `npm install -g @google/gemini-cli`（既にインストール済みならスキップ）
3. 設定ファイルの配置（settings.json, GEMINI.md, skills/）

#### Codex CLI
1. Node.js v18+ / npm の存在確認
2. `npm install -g @openai/codex`（既にインストール済みならスキップ）
3. 設定ファイルの配置（config.toml, rules/default.rules, AGENTS.md, skills/）

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
- 1Password CLI + SSH エージェント + Git 署名
- モダン CLI ツール (eza, bat, fd, ripgrep)
- Node.js (fnm + LTS)
- Docker Engine + Compose
- Claude Code
- AWS CLI v2
- Python (pyenv + uv)
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

| ジョブ | 内容 | 対象 |
|--------|------|------|
| **Zsh Syntax Check** | `zsh -n` による構文チェック | `.zsh` ファイル |
| **Shell Format Check** | `shfmt` によるフォーマットチェック | `.sh` / `.zsh` ファイル |
| **ShellCheck** | 静的解析（`shellcheck -s bash`、除外: SC1091, SC2034, SC2154, SC2317） | bash スクリプト |
| **BATS テスト** | `dotfiles/tests/*.bats` によるユニットテスト | テストファイル |
| **Setup Dry Run** | `setup.sh --all --dry-run` による統合テスト | セットアップ全体 |

Zsh Syntax Check と Setup Dry Run は **Ubuntu** と **macOS** の両環境で実行されます。

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
│   └── ci.yml                # CI: shfmt + shellcheck + BATS + dry-run（Ubuntu/macOS）
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
│   │   ├── AGENTS.md            # Codex CLI エージェント設定
│   │   ├── config.toml          # Codex CLI モデル設定テンプレート
│   │   ├── rules/
│   │   │   └── default.rules    # サンドボックス許可ルール
│   │   └── skills/
│   │       └── context-loader/  # コンテキストローダースキル
│   ├── .gemini/
│   │   ├── GEMINI.md            # グローバルカスタム指示テンプレート
│   │   ├── settings.json        # Gemini CLI セッション設定
│   │   └── skills/
│   │       └── context-loader/  # コンテキストローダースキル
│   ├── .zsh/
│   │   ├── .p10k.zsh        # Powerlevel10k テーマ設定
│   │   └── plugins.zsh      # Zinit プラグイン設定
│   ├── .shell/                  # 共有設定（bash / zsh 両対応）
│   │   ├── aliases.sh       # エイリアス定義
│   │   ├── env.sh           # 環境変数読み込み（~/.claude/.env）
│   │   ├── node.sh          # fnm 初期化
│   │   ├── python.sh        # pyenv 初期化
│   │   └── 1password.sh     # 1Password SSH エージェント（WSL/Linux/macOS）
│   ├── lib/                     # セットアップ共通ライブラリ
│   │   ├── colors.sh        # カラー出力ヘルパー
│   │   ├── array.sh         # 配列操作ユーティリティ
│   │   ├── backup.sh        # ファイルバックアップ・リストア
│   │   └── tui.sh           # TUI（チェックボックス UI 等）
│   ├── modules/
│   │   ├── zsh.sh            # モジュール: Zsh 設定一式
│   │   ├── git.sh            # モジュール: Git グローバル設定
│   │   ├── 1password.sh      # モジュール: 1Password CLI + SSH + Git 署名
│   │   ├── modern-cli.sh     # モジュール: モダン CLI ツール
│   │   ├── node.sh           # モジュール: Node.js 開発環境
│   │   ├── docker.sh         # モジュール: Docker + NVIDIA GPU
│   │   ├── claude-code.sh    # モジュール: Claude Code
│   │   ├── aws-cli.sh        # モジュール: AWS CLI v2
│   │   ├── codex-cli.sh      # モジュール: Codex CLI
│   │   ├── python.sh         # モジュール: Python 開発環境
│   │   └── gemini-cli.sh     # モジュール: Gemini CLI
│   ├── tests/
│   │   ├── helpers/
│   │   │   └── setup_functions.bash   # テストヘルパー: 共通セットアップ関数
│   │   ├── test_backup_sort.bats      # テスト: バックアップソート
│   │   ├── test_detect_env.bats       # テスト: 環境検出
│   │   ├── test_flag_behavior.bats    # テスト: フラグ動作
│   │   ├── test_install_config.bats   # テスト: インストール設定
│   │   ├── test_module_metadata.bats  # テスト: モジュールメタデータ
│   │   ├── test_positional_args.bats  # テスト: 位置引数
│   │   ├── test_setup_functions.bats  # テスト: セットアップ関数
│   │   ├── test_status.bats           # テスト: ステータス表示
│   │   └── test_upgrade.bats          # テスト: アップグレード
│   ├── .gitconfig.shared     # Git 共有設定（include.path 経由）
│   ├── .gitignore_global     # グローバル gitignore
│   ├── .bashrc                # Bash エントリーポイント（.shell/ 読み込み）
│   ├── .zshrc                # Zsh エントリーポイント（履歴設定 + モジュール読み込み）
│   └── setup.sh              # セットアップスクリプト（bash、モジュール動的読み込み）
├── .editorconfig              # エディタ設定（インデント・改行コード統一）
├── .gitignore
└── README.md
```

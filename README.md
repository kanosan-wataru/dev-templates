# dev-templates

開発環境の設定ファイル（dotfiles）と AI コーディング CLI の設定テンプレートを管理するリポジトリです。
Bash スクリプト（セットアップ）+ Zsh（対話シェル）のモジュラー構成で、macOS / Linux に対応しています。

このリポジトリは 2 つの役割を兼ねます:

- **dotfiles / モジュラーセットアップ** (`dotfiles/`) — `setup.sh` でローカルマシンに開発環境一式を配布
- **AI CLI 設定テンプレート** (`dotfiles/.claude`, `dotfiles/.codex`, `dotfiles/.gemini`) — Claude Code / Codex CLI / Gemini CLI の最小構成テンプレート
- **このリポジトリ自身の Claude Code / Copilot 設定** (`.claude/`, `.copilot/`) — リポジトリ作業で使う完全版の設定 (50 agents / 49 commands / 150 skills + hooks/scripts/runtime)

## 含まれる設定

| ファイル / ディレクトリ | 説明 |
|---------|------|
| `dotfiles/setup.sh` | セットアップスクリプト（bash、インタラクティブ選択・自動インストール） |
| `dotfiles/lib/*.sh` | 共通ライブラリ（colors.sh, array.sh, backup.sh, tui.sh） |
| `dotfiles/modules/*.sh` | モジュール定義ファイル（各モジュールのセットアップ・アンインストール処理） |
| `dotfiles/.zshrc` | Zsh エントリーポイント（履歴設定、モジュール読み込み） |
| `dotfiles/.bashrc` | Bash エントリーポイント（`.shell/` の共有設定を読み込み） |
| `dotfiles/.zsh/plugins.zsh` | Zinit プラグイン設定 |
| `dotfiles/.zsh/.p10k.zsh` | Powerlevel10k テーマ設定 |
| `dotfiles/.shell/aliases.sh` | エイリアス定義（git/docker エイリアス、fzf 連携関数） |
| `dotfiles/.shell/env.sh` | 環境変数読み込み（`~/.claude/.env` および `~/.config/*/.env` 一括読み込み） |
| `dotfiles/.shell/node.sh` | fnm (Fast Node Manager) 初期化 |
| `dotfiles/.shell/python.sh` | pyenv / uv 初期化 |
| `dotfiles/.shell/1password.sh` | 1Password SSH エージェント設定（WSL/Linux/macOS 自動判定） |
| `dotfiles/.claude/` | Claude Code 設定テンプレート（CLAUDE.md, hookify ルール, スキル, エージェント等） |
| `dotfiles/.codex/` | Codex CLI 設定テンプレート（config.toml, AGENTS.md, ルール, スキル） |
| `dotfiles/.gemini/` | Gemini CLI 設定テンプレート（settings.json, GEMINI.md, スキル） |
| `dotfiles/.gitconfig.shared` | Git 共有設定（include.path 経由で読み込み） |
| `dotfiles/.gitignore_global` | グローバル gitignore |
| `.claude/` | このリポジトリ自身の Claude Code 設定（agents/commands/skills/hooks/scripts/runtime 一式） |
| `.copilot/skills/` | GitHub Copilot CLI 用スキル（pptx, slidekit-create, slidekit-templ） |

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
  [ ] Codex CLI             OpenAI CLI (Node.js v18+ 必要)
  [ ] GitHub CLI            gh (GitHub CLI)
  [ ] GitHub Copilot CLI    Copilot CLI (Node.js v22+ 必要)
  [ ] opencode              SST opencode (AI coding agent, 単一バイナリ)
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
| **Gemini CLI** | Google の AI CLI + 設定テンプレート | Node.js v20+ |
| **Codex CLI** | OpenAI の AI コーディングアシスタント CLI + 設定テンプレート | Node.js v18+ |
| **GitHub CLI** | `gh` コマンド | Homebrew (macOS) / apt (Linux) |
| **GitHub Copilot CLI** | `copilot` コマンド | Node.js v22+ |
| **opencode** | SST opencode (AI coding agent) — GitHub Releases から単一バイナリで導入、Node 非依存 | curl + tar (Linux) / curl + unzip (macOS) |

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
4. `env.sh` の配置（`.shell/` に `~/.claude/.env` および `~/.config/*/.env` 一括読み込み）
5. MCP サーバー設定の `~/.claude.json` へのマージ（jq 使用、べき等。jq 未インストール時はスキップ）
6. `~/.claude/.env` に環境変数を設定するよう案内表示

#### Gemini CLI
1. Node.js v20+ / npm の存在確認
2. `npm install -g @google/gemini-cli`（既にインストール済みならスキップ）
3. 設定ファイルの配置（settings.json, GEMINI.md, skills/context-loader）

#### Codex CLI
1. Node.js v18+ / npm の存在確認
2. `npm install -g @openai/codex`（既にインストール済みならスキップ）
3. 設定ファイルの配置（config.toml, rules/default.rules, AGENTS.md, skills/context-loader）

#### GitHub CLI
1. 環境の自動判定（macOS: Homebrew / Linux: apt + 公式 GPG キー）
2. `gh` のインストール（既にインストール済みならスキップ）
3. `gh auth login` の案内表示

#### GitHub Copilot CLI
1. Node.js v22+ / npm の存在確認
2. `npm install -g @github/copilot`（既にインストール済みならスキップ）
3. 認証ガイドの表示（`copilot` 起動時に GitHub アカウントでログイン）

#### opencode
1. アーキテクチャ自動判定（`uname -m`: x86_64 / aarch64, OS: linux / darwin）
2. [sst/opencode](https://github.com/sst/opencode) の GitHub Releases から単一バイナリをダウンロード（既にインストール済みならスキップ）
3. 展開前にアーカイブエントリを検証（zip-slip / tar-slip 防御）し、`$HOME/.local/bin/opencode` に配置
4. バージョン固定可能: `OPENCODE_VERSION=v1.14.49 bash setup.sh opencode`（pre-release タグ `v1.0.0-rc.1` 形式も許容）
5. 認証ガイドの表示（`opencode auth login` でプロバイダ設定）
6. アンインストール時はバイナリに加えて `~/.local/share/opencode`、`~/.config/opencode`、`~/.cache/opencode` も完全削除

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

# コンテナをビルド (ホストの UID/GID を渡して bind mount の所有を一致させるのを推奨)
USER_UID=$(id -u) USER_GID=$(id -g) docker compose build

# コンテナを起動
docker compose up -d
docker compose exec devcontainer zsh
```

#### ホスト UID/GID の同期 (推奨)

リポジトリは `.:/workspaces/dev-templates` として bind mount されるため、
コンテナ内 `dev` ユーザーの UID/GID とホストユーザーが一致しないと、
コンテナ内で作成したファイルがホスト側で異なる所有者に見えて編集権限の不整合や
git の dubious ownership 警告を引き起こします (特にホスト UID が 1000 以外の場合)。

`USER_UID` / `USER_GID` 環境変数を渡すことで一致させられます (未指定時は `1000:1000`):

```bash
# 一時的に渡す
USER_UID=$(id -u) USER_GID=$(id -g) docker compose build

# .env に永続化
echo "USER_UID=$(id -u)" >> .env
echo "USER_GID=$(id -g)" >> .env
docker compose build
```

`.env` に書いておけば VS Code Dev Containers (Reopen in Container) でも同じビルド設定が使われます。

VS Code / Cursor から Dev Containers として接続する場合は、コマンドパレットから「Dev Containers: Reopen in Container」を実行してください。

### ホストファイルのマウント

コンテナ起動時にホストの設定ファイルが read-only でマウントされます:

| ホスト | コンテナ | 用途 |
|--------|----------|------|
| `~/.ssh` | `/home/dev/.ssh` | SSH 鍵（Git の SSH 接続等） |
| `~/.gitconfig` | `/home/dev/.gitconfig` | Git ユーザー設定 |

### 含まれるツール

コンテナイメージには、コンテナ内で動作するモジュールが既定でプリインストールされます:

- Zsh + Zinit + Powerlevel10k
- Git グローバル設定
- モダン CLI ツール (eza, bat, fd, ripgrep)
- Node.js (fnm + LTS)
- Python (pyenv + uv)
- Claude Code
- Codex CLI
- Gemini CLI
- GitHub CLI
- GitHub Copilot CLI

**既定で除外**されるモジュール (コンテナ内で動作しない / 不要なため):

- Docker Engine (Docker-in-Docker 用途は別途 socket マウントが必要)
- AWS CLI v2 (必要に応じて手動インストール)
- 1Password (ホストでの SSH エージェントが前提)
- opencode (オプトイン。必要な場合は `SETUP_MODULES` に `opencode` を追加)

#### モジュール選択のカスタマイズ

`SETUP_MODULES` 環境変数を指定するとビルド時のモジュールを上書きできます:

```bash
# 全モジュール入り (Docker は build 時にエラーになる可能性あり)
SETUP_MODULES="--all" docker compose build

# 最小構成 (Zsh + Node + Claude Code のみ)
SETUP_MODULES="zsh node claude-code" docker compose build
```

#### Multi-arch ビルド

`linux/amd64` と `linux/arm64` (Apple Silicon) に対応しています。`node` モジュールが `uname -m` を判定して fnm の適切なアセットを取得します (ubuntu:24.04 は `linux/arm/v7` 公式イメージが未提供のため arm32 は非対応)。

### API キーの設定

`.env` ファイルに API キーを記述すると、コンテナ内の環境変数として利用できます:

```bash
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=sk-...
GH_TOKEN=ghp_...
```

## このリポジトリ自身の AI CLI 設定

`dotfiles/` 配下とは別に、リポジトリのルートにこのリポジトリ自身で使う完全版の Claude Code / Copilot CLI 設定が格納されています。
`$CLAUDE_PROJECT_DIR/.claude/...` のように **プロジェクトローカル参照**で動作し、ホスト依存パスを含みません。

### `.claude/` (プロジェクトローカル Claude Code 設定)

| エントリ | 内容 |
|---------|------|
| `CLAUDE.md` / `CLAUDE.jp.md` | プロジェクト向けの Claude Code 指示書（英語 / 日本語） |
| `settings.json` | 言語・hooks・パーミッション設定 |
| `agents/` | 50 個のスペシャリストエージェント（reviewer / build-resolver / planner / explore 系） |
| `commands/` | 49 個のスラッシュコマンド（`/plan`, `/tdd`, `/verify`, `/code-review` 等） |
| `skills/` | 150 個のスキル（continuous-learning, verification-loop, security-review 等） |
| `hooks/` | hooks 補助ファイル |
| `scripts/hooks/` | settings.json から呼ばれる hooks 本体（Node.js） |
| `rules/` | 言語別ルール（common/typescript/python/golang/rust/web 他） |
| `lsps-runtime/` | LSP ランタイム（pyright, vtsls）と起動 hooks |
| `hookify-runtime/` | hookify ランタイム（Python） |
| `docs/` | 設定リファレンス・設計ドキュメント |

### `.copilot/skills/` (GitHub Copilot CLI 用スキル)

| スキル | 内容 |
|-------|------|
| `pptx/` | PowerPoint (OOXML) を pptxgenjs / unpack-pack 系スクリプトで編集するスキル |
| `slidekit-create/` | スライドキット作成補助 |
| `slidekit-templ/` | スライドテンプレート補助 |

## CI

`dotfiles/**` または `.github/workflows/**` に変更を含む Pull Request で、GitHub Actions によるチェックが自動実行されます:

| ジョブ | 内容 | 対象 |
|--------|------|------|
| **Zsh Syntax Check** | `zsh -n` による構文チェック | `.zsh` ファイル |
| **Shell Format Check** | `shfmt` によるフォーマットチェック | `.sh` / `.zsh` ファイル |
| **ShellCheck** | 静的解析（`shellcheck -s bash`、除外: SC1091, SC2034, SC2154, SC2317） | bash スクリプト |
| **BATS テスト** | `dotfiles/tests/*.bats` によるユニットテスト | テストファイル |
| **Setup Dry Run** | `setup.sh --all --dry-run` による統合テスト | セットアップ全体 |

Zsh Syntax Check と Setup Dry Run は **Ubuntu** と **macOS** の両環境で実行されます。Setup Dry Run と BATS テストは **Node.js 22** で実行されます。

## ディレクトリ構成

```
dev-templates/
├── .claude/                          # このリポジトリ自身の Claude Code 設定 (プロジェクトローカル)
│   ├── CLAUDE.md / CLAUDE.jp.md      # プロジェクト指示書 (英語 / 日本語)
│   ├── settings.json                 # 言語・hooks・パーミッション
│   ├── agents/                       # スペシャリストエージェント (50)
│   ├── commands/                     # スラッシュコマンド (49)
│   ├── skills/                       # スキル定義 (150)
│   ├── hooks/                        # hooks 補助ファイル
│   ├── scripts/hooks/                # settings.json から呼ばれる hooks 本体
│   ├── rules/                        # 言語別ルール (common/typescript/python/golang/rust/web/...)
│   ├── lsps-runtime/                 # pyright / vtsls 起動 hooks
│   ├── hookify-runtime/              # hookify ランタイム
│   └── docs/                         # 設定リファレンス・設計ドキュメント
├── .copilot/
│   └── skills/                       # GitHub Copilot CLI 用スキル (pptx / slidekit-*)
├── .devcontainer/
│   └── devcontainer.json             # VS Code Dev Containers 設定
├── .github/workflows/
│   └── ci.yml                        # CI: shfmt + shellcheck + BATS + dry-run (Ubuntu/macOS, Node 22)
├── Dockerfile                        # 開発環境コンテナ定義
├── docker-compose.yml                # Docker Compose 設定
├── .dockerignore                     # Docker ビルドコンテキスト除外設定
├── .env.example                      # 環境変数テンプレート (API キー等)
├── dotfiles/
│   ├── .claude/                      # Claude Code 設定テンプレート (~/.claude/ に配布)
│   │   ├── CLAUDE.md                 # グローバル指示書
│   │   ├── settings.json             # 許可ツール・プラグイン設定
│   │   ├── mcp-servers.json          # MCP サーバー設定テンプレート
│   │   ├── hookify.*.local.md        # hookify ガードレール (4 ファイル)
│   │   ├── skills/                   # スキル定義 (7 スキル)
│   │   ├── agents/                   # エージェント定義 (3 エージェント)
│   │   ├── rules/                    # 言語別ルール
│   │   ├── contexts/                 # コンテキスト定義
│   │   └── scripts/                  # 補助スクリプト
│   ├── .codex/                       # Codex CLI 設定テンプレート (~/.codex/ に配布)
│   │   ├── AGENTS.md                 # Codex CLI エージェント設定
│   │   ├── config.toml               # モデル設定テンプレート
│   │   ├── rules/default.rules       # サンドボックス許可ルール
│   │   └── skills/context-loader/    # コンテキストローダースキル
│   ├── .gemini/                      # Gemini CLI 設定テンプレート (~/.gemini/ に配布)
│   │   ├── GEMINI.md                 # グローバルカスタム指示
│   │   ├── settings.json             # セッション設定
│   │   └── skills/context-loader/    # コンテキストローダースキル
│   ├── .zsh/
│   │   ├── .p10k.zsh                 # Powerlevel10k テーマ設定
│   │   └── plugins.zsh               # Zinit プラグイン設定
│   ├── .shell/                       # 共有設定 (bash / zsh 両対応)
│   │   ├── aliases.sh                # エイリアス定義
│   │   ├── env.sh                    # 環境変数読み込み (~/.claude/.env + ~/.config/*/.env)
│   │   ├── node.sh                   # fnm 初期化
│   │   ├── python.sh                 # pyenv 初期化
│   │   └── 1password.sh              # 1Password SSH エージェント (WSL/Linux/macOS)
│   ├── lib/                          # セットアップ共通ライブラリ
│   │   ├── colors.sh                 # カラー出力ヘルパー
│   │   ├── array.sh                  # 配列操作ユーティリティ
│   │   ├── backup.sh                 # ファイルバックアップ・リストア
│   │   └── tui.sh                    # TUI (チェックボックス UI 等)
│   ├── modules/                      # モジュール定義 (14 モジュール)
│   │   ├── zsh.sh                    # Zsh 設定一式
│   │   ├── git.sh                    # Git グローバル設定
│   │   ├── 1password.sh              # 1Password CLI + SSH + Git 署名
│   │   ├── modern-cli.sh             # モダン CLI ツール
│   │   ├── node.sh                   # Node.js 開発環境
│   │   ├── docker.sh                 # Docker + NVIDIA GPU
│   │   ├── claude-code.sh            # Claude Code
│   │   ├── aws-cli.sh                # AWS CLI v2
│   │   ├── codex-cli.sh              # Codex CLI
│   │   ├── python.sh                 # Python 開発環境
│   │   ├── gemini-cli.sh             # Gemini CLI
│   │   ├── gh.sh                     # GitHub CLI
│   │   ├── copilot-cli.sh            # GitHub Copilot CLI
│   │   └── opencode.sh               # SST opencode (バイナリ DL)
│   ├── tests/                        # BATS ユニットテスト
│   │   ├── helpers/setup_functions.bash
│   │   ├── test_backup_sort.bats
│   │   ├── test_copilot_cli.bats
│   │   ├── test_detect_env.bats
│   │   ├── test_flag_behavior.bats
│   │   ├── test_install_config.bats
│   │   ├── test_module_metadata.bats
│   │   ├── test_positional_args.bats
│   │   ├── test_setup_functions.bats
│   │   ├── test_status.bats
│   │   └── test_upgrade.bats
│   ├── .gitconfig.shared             # Git 共有設定 (include.path 経由)
│   ├── .gitignore_global             # グローバル gitignore
│   ├── .bashrc                       # Bash エントリーポイント (.shell/ 読み込み)
│   ├── .zshrc                        # Zsh エントリーポイント (履歴設定 + モジュール読み込み)
│   └── setup.sh                      # セットアップスクリプト (bash、モジュール動的読み込み)
├── .editorconfig                     # エディタ設定 (インデント・改行コード統一)
├── .gitignore
└── README.md
```

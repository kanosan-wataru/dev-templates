# Claude Code 設定リファレンス

このドキュメントは `dev-templates` プロジェクトにおける Claude Code の設定内容を包括的にまとめたものである。各設定ファイルの詳細は原本を参照のこと。

---

## 1. 概要

本プロジェクトの Claude Code 設定は、**マルチエージェント・オーケストレーション**（Claude Code Orchestra）を基盤としている。Lead エージェント（Claude Code 本体）がオーケストレーターとして機能し、実装・調査・デバッグをサブエージェントに委譲することで、200K トークンのコンテキストを節約する設計。

主な特徴:

- **コンテキスト節約**が最優先原則。Lead は指揮者であり演奏者ではない
- **Scrum ベースの開発ワークフロー**をスキルで自動化
- **hookify によるガードレール**で危険な操作を自動ブロック
- **MCP サーバー**で GitHub、Gemini、Codex、Playwright 等と連携
- **セットアップスクリプト**（`claude-code.sh` モジュール）による自動デプロイ

---

## 2. 設定ファイル一覧

| ファイル | 配置先 | 役割 |
|---------|-------|------|
| `dotfiles/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | グローバル設定（全プロジェクト共通ルール） |
| `CLAUDE.md` (ルート) | プロジェクトルート | プロジェクト固有設定（Orchestra フレームワーク） |
| `dotfiles/.claude/settings.json` | `~/.claude/settings.json` | 許可ツール・プラグイン設定 |
| `dotfiles/.claude/mcp-servers.json` | `~/.claude.json` にマージ | MCP サーバー接続設定 |
| `dotfiles/.claude/hookify.*.local.md` | `~/.claude/` | hookify 自動ガードレール（3 ファイル） |
| `dotfiles/.claude/skills/*/SKILL.md` | `~/.claude/skills/` | スキル定義（7 スキル） |
| `dotfiles/.claude/agents/*.md` | `~/.claude/agents/` | サブエージェント定義（3 エージェント） |
| `.claude/rules/*.md` | プロジェクトルート | コーディング・開発ルール（7 ファイル） |
| `dotfiles/.zsh/env.zsh` | `~/.zsh/env.zsh` | `.env` ファイルからの環境変数読み込み |
| `dotfiles/.zsh/ssh.zsh` | `~/.zsh/ssh.zsh` | 1Password SSH エージェント（WSL 用）※ `claude-code.sh` の管理対象外（手動配置） |
| `dotfiles/modules/claude-code.sh` | setup.sh モジュール | インストール・アンインストール自動化 |

---

## 3. グローバル設定 (CLAUDE.md)

**ファイル**: `dotfiles/.claude/CLAUDE.md`（全プロジェクト共通で適用）

### コア原則

| 原則 | 内容 |
|------|------|
| 言語 | ユーザーへの応答は日本語。コードコメント・変数名・docstring は英語 |
| 調査優先 | 変更前に必ず対象ファイルと関連コードを読む |
| セキュリティ | `.env`・`credentials.json`・`*.pem` 等を読み書き・コミットしない |
| 自律性 | 可能な限り自律的に作業。破壊的変更や要件不明瞭時は確認 |

### 思考プロセス

複雑なタスクでは **Plan モード + Gemini クロスチェック** の 6 ステップを実行:
Plan モード → Claude 分析 → Gemini クロスチェック → 統合 → ユーザー承認 → 実装

### コーディングルール

- **共通**: 明確な命名、単一責任、シンプルさ優先
- **アノテーション**: `TODO` / `NOTE` / `FIXME` / `XXX` / `HACK`
- **Python**: PEP 8、型ヒント、ruff、f-string、pathlib
- **TypeScript**: ESLint / Prettier、型定義活用
- **品質**: テスト通過必須、デバッグコード除去、OWASP Top 10

### TDD & ローカル CI

- **TDD**: Red > Green > Refactor サイクル。`[TDD]` / `[Test-After]` / `[No-Test]` タグで戦略指定
- **CI パイプライン**: Lint → Type Check → Test → Security → Coverage の 5 ステージ

### 開発ワークフロー（Scrum ベース）

| フェーズ | スキル | 内容 |
|---------|--------|------|
| バックログ | `/create-issue` | Issue 作成・優先度設定 |
| スプリント計画 | `/start-work` | ブランチ作成・実装計画 |
| TDD 開発 | `/test` | Red > Green > Refactor |
| 保存 | `/commit` | Conventional Commits |
| レビュー | `/create-pr` | CI ゲート + PR 作成 |
| クリーンアップ | `/git-cleanup` | マージ済みブランチ削除 |

**Definition of Done**: テスト通過、Lint/型チェック通過、セキュリティスキャン 0 件、カバレッジ未低下、Conventional Commits 準拠

### hookify ガードレール

| ルール | アクション | トリガー |
|--------|-----------|---------|
| `block-force-push` | ブロック | `git push --force` / `-f` |
| `block-sensitive-files` | ブロック | `.env` / `credentials.json` / `*.pem` 等の編集 |
| `warn-git-add` | 警告 | `git add .` / `-A` / `--all` |

詳細は `dotfiles/.claude/CLAUDE.md` を参照。

---

## 4. プロジェクト設定 (CLAUDE.md)

**ファイル**: `CLAUDE.md`（プロジェクトルート）

### コア原則: Lead はオーケストレーター

Lead の 200K コンテキストは**希少な非再生リソース**。10 行超のコード実装、50 行超のファイル読み取り、Web 調査などは全てサブエージェントに委譲。

### 判断ルール

```
"このタスクは 10 行超の出力を生むか、50 行超の読み取りが必要か？"
  YES → サブエージェント（常に）
  NO  → Lead 直接実行（OK）
```

### サブエージェント実行パターン

| パターン | 用途 |
|---------|------|
| A: Background | 結果をすぐ不要な場合（fire-and-forget） |
| B: Foreground | 次のステップに結果が必要な場合 |
| C: Save to File | 20 行超の出力を `.claude/docs/` に保存 |
| D: Worktree | リスクのある大規模変更を隔離環境で実行 |

### タスクルーティング

```
マルチモーダルファイル？      → gemini-explore
コードベース分析？           → gemini-explore
外部リサーチ？              → gemini-explore
設計・プランニング？          → general-purpose → Codex
デバッグ？                  → codex-debugger
コード実装（10行超）？       → general-purpose
マルチファイル探索？          → Explore
10行未満の小変更？           → Lead 直接
```

### コンテキスト衛生ルール

1. Read より Grep を優先
2. Read 使用時は offset/limit で部分読み込み
3. サブエージェント出力をそのまま流さず要約
4. 大出力は `.claude/docs/` に保存
5. 「サブエージェントに任せられるか？」を常に自問

### テックスタック

- Python 3.11+ / uv（pip 直接使用禁止）
- ruff（lint + format）/ ty（型チェック）/ pytest
- `poe lint` / `poe test` / `poe all`

詳細は `CLAUDE.md` を参照。

---

## 5. MCP サーバー

**ファイル**: `dotfiles/.claude/mcp-servers.json`

| サーバー名 | 種類 | 役割 | 必要な環境変数 |
|-----------|------|------|---------------|
| `github` | HTTP | GitHub Copilot MCP（Issue、PR、コードレビュー等） | `GITHUB_COPILOT_TOKEN` |
| `playwright` | stdio | ブラウザ自動操作（headless Chromium） | なし |
| `context7` | stdio | ライブラリドキュメント検索（Context7） | なし |
| `brave-search` | stdio | Brave Search API による Web 検索 | `BRAVE_API_KEY` |
| `codex` | stdio | Codex CLI の MCP サーバーモード | なし |
| `gemini` | stdio | Gemini MCP ツール（Google Cloud 連携） | `GOOGLE_CLOUD_PROJECT` |

MCP サーバー設定は `~/.claude.json` の `mcpServers` キーにマージされる（`claude-code.sh` モジュールが `jq` を使って実行）。

環境変数は `~/.claude/.env` に定義し、`env.zsh` によってシェル起動時に自動読み込みされる。

環境変数のテンプレートとして `dotfiles/.claude/.env.example` が用意されている（`GITHUB_COPILOT_TOKEN`、`BRAVE_API_KEY`、`GOOGLE_CLOUD_PROJECT`）。セットアップ後、`cp ~/.claude/.env.example ~/.claude/.env` でコピーし、値を設定して使用する。

---

## 6. permissions (settings.json)

**ファイル**: `dotfiles/.claude/settings.json`

### 許可されたツール

| カテゴリ | 許可内容 |
|---------|---------|
| MCP: Gemini | `mcp__gemini`（全操作） |
| MCP: GitHub | 読み取り系（issue_read, list_issues, pull_request_read, search_* 等）+ 書き込み系（issue_write, add_issue_comment, add_reply_to_pull_request_comment, add_comment_to_pending_review, request_copilot_review 等） |
| MCP: Context7 | `resolve-library-id`, `query-docs` |
| Bash: Git | `git *`, `gh *` |
| Bash: Docker | `docker compose run/up/build/down/logs/ps`, `docker ps/images/build/run/exec/logs/stop/rm` |
| Bash: 開発 | `python *`, `python3 *`, `pytest *`, `make *` |
| Bash: システム | `ls *`, `sleep *`, `ps *`, `kill *`, `free *`, `df *`, `lsof *`, `ss *`, `find *`, `tree*` |

### 有効なプラグイン

| プラグイン | 用途 |
|-----------|------|
| `example-skills@anthropic-agent-skills` | スキルフレームワーク |
| `skill-creator@claude-plugins-official` | スキル作成支援 |
| `hookify@claude-plugins-official` | 自動ガードレール |
| `pr-review-toolkit@claude-plugins-official` | PR レビューエージェント群 |

### その他の設定

- `effortLevel`: `"high"`
- `skipDangerousModePermissionPrompt`: `true`

---

## 7. hookify ルール

### block-force-push

**ファイル**: `dotfiles/.claude/hookify.block-force-push.local.md`

- **アクション**: block
- **イベント**: bash
- **パターン**: `git push --force` / `-f`（`--force-with-lease` は許可）
- **目的**: リモート履歴の上書きを防止

### block-sensitive-files

**ファイル**: `dotfiles/.claude/hookify.block-sensitive-files.local.md`

- **アクション**: block
- **イベント**: file
- **パターン**: `.env`（`.env.example` は除外）、`credentials.json`、`*.pem`、`*.key`、`*.secret`
- **目的**: 機密ファイルへのアクセスをブロック

### warn-git-add

**ファイル**: `dotfiles/.claude/hookify.warn-git-add.local.md`

- **アクション**: warn
- **イベント**: bash
- **パターン**: `git add .` / `-A` / `--all`
- **目的**: ステージング前のセキュリティ・ファイルサイズチェックを促す

---

## 8. スキル一覧

全スキルは `dotfiles/.claude/skills/` に定義され、`~/.claude/skills/` にデプロイされる。

### /ci -- ローカル CI パイプライン

- **目的**: Lint → Type Check → Test → Security → Coverage の 5 ステージを一括実行
- **引数**: `<stages>`（省略時は全ステージ。例: `/ci lint,test`）
- **言語自動検出**: pyproject.toml / package.json / Cargo.toml / go.mod から判定
- **Docker 優先**: Dockerfile がある場合は Docker 経由で実行
- **カバレッジ評価**: `.coverage-baseline` ファイルとの比較で低下を検出

### /create-issue -- GitHub Issue 作成

- **目的**: 問題を分析し、構造化された GitHub Issue を作成
- **引数**: `<description>`（省略時は会話コンテキストから生成）
- **機能**: 重複チェック、自動ラベル付け、ユーザー確認後に作成

### /create-pr -- PR 作成 & レビュー対応

- **目的**: CI ゲート + PR 作成 + Copilot レビュー要求 + レビュー対応の統合ワークフロー
- **引数**: `<base>`（デフォルト: `main`）
- **フロー**: CI ゲート → code-simplifier によるコード整理 → pr-review-toolkit 品質チェック → PR 作成 → Copilot レビュー → レビュー対応 → Gemini クロスチェック → 完了報告
- **制約**: Co-Authored-By / Generated with クレジット行は**禁止**

### /commit -- コミットメッセージ生成

- **目的**: 変更を分析し、Conventional Commits 形式でコミット
- **引数**: `<hint>`（省略時は変更内容から自動生成）
- **形式**: `<type>: <日本語の簡潔な説明>`（70 文字以内）
- **制約**: Co-Authored-By / Generated with クレジット行は**禁止**
- **参照**: `references/format-guide.md`

### /start-work -- 作業開始

- **目的**: Issue 番号からブランチを自動生成し、TDD 戦略付き実装計画を作成
- **引数**: `<issue_number>`（必須）
- **ブランチ命名**: `fix/` / `feature/` / `refactor/` + Issue 番号 + タイトル要約
- **計画**: 各 TODO に `[TDD]` / `[Test-After]` / `[No-Test]` タグを付与

### /test -- テスト & Lint 実行

- **目的**: テストと Lint を実行。TDD の Red/Green/Refactor サイクルをサポート
- **引数**: `<target>`（省略時は全テスト + Lint）
- **特殊モード**: `--red`（TDD Red フェーズ: テスト失敗を期待）
- **Docker 対応**: `docker compose run --rm app <command>` で実行

### /git-cleanup -- ブランチクリーンアップ

- **目的**: マージ済みブランチの削除、リモート追跡ブランチの剪定、ターゲットブランチへの切り替え
- **引数**: `<target-branch>`（デフォルト: `main`）
- **安全策**: `-D`（強制削除）禁止。保護ブランチ（main/master/develop 等）の削除禁止

### チーム開発フロー（プロジェクト CLAUDE.md 定義）

プロジェクト CLAUDE.md で定義されたマルチエージェント協調フロー。グローバルスキルではなくプロジェクトレベルの設定。

| コマンド | 目的 |
|---------|------|
| `/startproject` | Gemini 分析 + 要件収集 → Agent Teams による並列調査・設計 → 実装計画 |
| `/team-implement` | Agent Teams によるモジュール単位の並列実装 |
| `/team-review` | Agent Teams による並列レビュー（セキュリティ・品質・テスト） |

---

## 9. エージェント定義

全エージェントは `dotfiles/.claude/agents/` に定義され、`~/.claude/agents/` にデプロイされる。

### general-purpose

- **モデル**: opus
- **ツール**: Read, Edit, Write, Bash, Grep, Glob, WebFetch, WebSearch
- **役割**: コード実装、Codex CLI への委譲、ファイル操作
- **Codex 呼び出し**: `codex exec --model gpt-5.3-codex --sandbox {read-only|workspace-write} --full-auto`
- **出力**: 簡潔なサマリー形式（Task / Result / Key Insights / Files Changed / Recommendations）

### gemini-explore

- **モデル**: opus
- **ツール**: Read, Bash, Grep, Glob, WebFetch, WebSearch
- **役割**: 大規模コードベース分析（1M コンテキスト）、外部リサーチ（Google Search grounding）、マルチモーダルファイル処理
- **Gemini 呼び出し**: `gemini -p "{prompt}" 2>/dev/null`
- **対応ファイル**: PDF / 動画 / 音声 / 画像
- **出力保存先**: `.claude/docs/research/` / `.claude/docs/libraries/`

### codex-debugger

- **モデル**: opus
- **ツール**: Read, Edit, Write, Bash, Grep, Glob
- **役割**: エラー分析、ルートコーズ特定、修正提案
- **フロー**: コンテキスト収集 → Codex CLI 呼び出し → 修正適用 → テスト検証
- **対象**: テスト失敗、ビルドエラー、ランタイムエラー、Lint エラー

---

## 10. コーディングルール

全ルールは `.claude/rules/` に配置され、プロジェクトレベルで適用される。

### coding-principles.md

- シンプルさ優先（読みやすさ > 複雑さ）
- 単一責任（1 関数 1 機能、ファイル 200-400 行目安）
- Early Return パターン
- 型ヒント必須
- 不変性（既存オブジェクトの変更より新規作成）
- マジックナンバー禁止

### security.md

- API キー・パスワードのハードコード禁止
- 環境変数からの取得を必須化
- 入力バリデーション（Pydantic 推奨）
- SQL インジェクション防止（パラメータ化クエリ）
- エラーメッセージの情報量制限

### testing.md

- TDD 推奨、カバレッジ目標 80%+
- AAA パターン（Arrange / Act / Assert）
- 命名規則: `test_{対象}_{条件}_{期待結果}`
- Happy path / 境界値 / エラーケース / エッジケースを網羅
- 外部依存はモック化、共通セットアップは `conftest.py`

### dev-environment.md

- パッケージ管理: **uv**（pip 直接使用禁止）
- Lint/Format: **ruff**（`ruff check` + `ruff format`）
- 型チェック: **ty**（Rust ベースの高速チェッカー）
- ノートブック: **marimo**（純 Python、リアクティブ）
- タスクランナー: **poe**（`poe lint` / `poe test` / `poe all`）

### codex-delegation.md

- Codex CLI の呼び出し基準（設計、複雑な実装、デバッグ、トレードオフ分析、コードレビュー）
- サンドボックスモード: `read-only`（分析）/ `workspace-write`（実装）
- Codex に任せないタスク: 単純編集、標準操作、ファイル検索、コードベース分析、外部情報取得

### gemini-delegation.md

- Gemini CLI の 3 つの役割: コードベース分析、外部リサーチ、マルチモーダル読み取り
- 対応ファイル: PDF / 動画（.mp4 等）/ 音声（.mp3 等）/ 画像（.png 等）
- Gemini に任せないタスク: 設計（Codex）、デバッグ（Codex）、コード実装（Claude）

### language.md

- 思考・推論: 英語
- コード（変数名、関数名、コメント、docstring）: 英語
- ユーザーコミュニケーション: 日本語
- 技術ドキュメント: 英語

---

## 11. デプロイ (claude-code.sh モジュール)

**ファイル**: `dotfiles/modules/claude-code.sh`

### モジュールメタデータ

| 項目 | 値 |
|------|-----|
| MODULE_ID | `claude-code` |
| MODULE_NAME | `Claude Code` |
| MODULE_DESC | `Anthropic CLI + 設定ファイル (Node.js v18+ 必要)` |
| MODULE_DEFAULT | `0`（デフォルト無効） |
| MODULE_ORDER | `20` |

### インストール (`module_setup`)

1. **CLI インストール**: `npm install -g @anthropic-ai/claude-code`（べき等: 既存時スキップ）
2. **ディレクトリ作成**: `~/.claude/skills/*/` および `~/.claude/agents/` 等を事前作成
3. **設定ファイル配置**: `CLAUDE_MOD_MANAGED_FILES` リストに基づき、`install_config` 関数でコピー（バックアップ付き）
4. **MCP サーバーマージ**: `mcp-servers.json` の内容を `~/.claude.json` に `jq` でマージ（べき等: 同一内容時スキップ）

### 管理対象ファイル

全 17 ファイルを管理:
- CLAUDE.md、settings.json
- hookify ルール 3 ファイル
- スキル 8 ファイル（7 スキル + format-guide.md）
- エージェント 3 ファイル
- zsh モジュール 1 ファイル（env.zsh）

### アンインストール (`module_uninstall`)

1. **MCP サーバー削除**: テンプレートに定義されたサーバー名を `~/.claude.json` から除去
2. **設定ファイル復元**: バックアップから復元（バックアップがない場合は警告）
3. **CLI アンインストール**: `npm uninstall -g @anthropic-ai/claude-code`

### 安全策

- 一時ファイル経由のアトミック書き込み
- JSON バリデーション（jq empty）
- バックアップ作成後にマージ/削除
- dry-run モード対応
- `~/.claude.json` 自体の削除はモジュール作成時のみ（他の設定保護）
- `jq` 未インストール時は MCP マージをスキップ（警告を表示）

---

## 12. zsh モジュール

### env.zsh

**ファイル**: `dotfiles/.zsh/env.zsh` → `~/.zsh/env.zsh`

- `~/.claude/.env` から環境変数を読み込む（`set -a` / `source` / `set +a`）
- MCP サーバーが必要とする環境変数（`GITHUB_COPILOT_TOKEN`、`BRAVE_API_KEY`、`GOOGLE_CLOUD_PROJECT` 等）の供給源
- 無効化: `export DISABLE_DOTENV=1` を `.zshenv` 等で設定

### ssh.zsh

**ファイル**: `dotfiles/.zsh/ssh.zsh` → `~/.zsh/ssh.zsh`

- Windows 側の 1Password SSH エージェントを WSL から利用するための設定
- デフォルト: OFF
- 有効化: `export ENABLE_SSH_1PASSWORD=1` を `.zshenv` 等で設定
- `ssh` / `ssh-add` を `.exe` 版にエイリアス

---

## 13. 既知の課題と改善候補

CLAUDE.md の三者クロスチェック分析（Claude × Codex × Gemini、2026-03-12 実施）で発見された課題。詳細は `~/.claude/projects/-home-wataru--claude/memory/technical-notes.md` を参照。

### 優先度: 高

| ID | 課題 | 提唱 | 概要 |
|----|------|------|------|
| A-1 | テスト方針の内部不整合 | Codex（三者合意） | DoD では「Tests pass」必須だが、Lightweight Path は `/ci lint` のみ許可、`[No-Test]` は lint-only。「新規テスト不要」と「既存テスト実行不要」が未区別 |
| A-2 | コンテキスト復元の仕組み不在 | Gemini | セッション切断時に Sprint/TODO の実行状態を復元する手順が未定義 |
| A-3 | CLAUDE.md と skill 間のポリシードリフト | Codex（Gemini 補強） | CLAUDE.md で CI 必須ゲートだが、skill 実装では `skip CI` で全バイパス可能 |

### 優先度: 中

| ID | 課題 | 提唱 | 概要 |
|----|------|------|------|
| A-4 | hookify セキュリティ対象の不足 | Codex | `id_rsa`, `.p12`, `.aws/credentials`, `.npmrc`, `.docker/config.json` 等が対象外 |
| A-5 | Gemini クロスチェックの裁定フロー未定義 | Gemini | Claude と Gemini の意見対立時のプロセスがない |
| A-6 | Sprint Retrospective の具体化不足 | Claude | Sprint end の定義と実施手順がない |

### 優先度: 低

| ID | 課題 | 提唱 | 概要 |
|----|------|------|------|
| A-7 | 言語別ルールの偏り | 三者合意 | Python 8項目 vs TypeScript/Rust/Go 各1行。主要言語が Python なら現状維持 |

### 設計思想レベルの指摘（Gemini）

> CLAUDE.md は「AI がどう動くか」には詳しいが、「AI が動けなくなった時（エラー、忘却、意見対立）にどう復帰するか」が弱点。

---

## 付録: ドキュメントマップ

| パス | 内容 |
|-----|------|
| `.claude/docs/DESIGN.md` | アーキテクチャ・設計判断 |
| `.claude/docs/research/` | サブエージェントの調査結果 |
| `.claude/docs/libraries/` | ライブラリ制約・ドキュメント |
| `.claude/logs/cli-tools.jsonl` | Codex/Gemini の I/O ログ |
| `.claude/docs/claude-code-config.md` | 本ドキュメント |

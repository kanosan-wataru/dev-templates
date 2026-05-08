---
name: gdrive-worklog
description: >
  Google Drive に本日の作業ログをMarkdownドキュメントとして作成するskill。
  Issue/PR対応、評価結果、学んだことをまとめてGoogle Docsに保存する。
  「ジャパンネクス > 作業ログ」フォルダ配下に `YYYY-MM-DD` 形式（日付のみ）で格納する。
  Use in scenarios such as: "本日の作業をDriveに記録", "作業ログを残して",
  "Google Driveに日報を作成", "MCPで作業内容を外部に保存".
---

# gdrive-worklog: Google Drive 作業ログ作成 Skill

Google Drive MCP (`mcp__claude_ai_Google_Drive__*`) を使って、
日々のエンジニアリング作業ログを Google Docs として保存するワークフロー。

## Critical Rules

- **Base64 エンコードは Python で行う**: `cat | base64` 形式は permission で拒否される可能性があるため、`python3 -c "import base64; ..."` を使う
- **Base64 は必ずファイル保存 + Read で読み込む**: Bash stdout から直接コピーすると途中で切り詰められ "not a valid base64 string" エラーになる (実測で発生)。`/tmp/worklog_<date>.b64` に保存し Read ツールで読み込んで、Read 結果の line 1 に含まれる完全な文字列を MCP call の `content` に貼り付ける
- **Base64 文字列は末尾の padding (`=` / `==`) まで完全にコピーする**: 切り詰められた base64 はエラーになる。貼り付け後、末尾が base64 文字 (`A-Za-z0-9+/=`) で終わっていることを確認する
- **コンテンツサイズの目安**: 4KB 以下の Markdown (base64 化で約 5-6KB) は1回のMCP callで成功する。それ以上になる場合は Markdown を簡潔化する
- **ファイル名は日付のみ**: `YYYY-MM-DD` 形式で固定（並び順が自然になり、後から Drive で手動 rename しやすくなるため、タイトルに作業内容を含めない）
- **text/plain を使う**: `application/vnd.google-apps.document` は直接作成時に content を受け付けないため、`text/plain` で送信し自動変換させる

## 前提条件

### MCP 接続

Google Drive MCP (`mcp__claude_ai_Google_Drive__*`) が接続済みで認証が有効であること。
トークンが期限切れの場合は、ユーザーに `/mcp` コマンドまたは claude.ai の Connectors 設定で再認証を依頼する。

### フォルダ構造（既定）

```
My Drive/
└── ジャパンネクス/          (フォルダID: 1eGSPmr7s1wexlD_fvRc0szVwOJRiGjsy)
    └── 作業ログ/            (フォルダID: 1s6dcnGzYBGlYcaVoTW-Ohafm1EP3IB0w)
        └── YYYY-MM-DD
```

別プロジェクトの場合はユーザーに確認して `parentId` を差し替える。

## 実行フロー

### ステップ 1: 親フォルダ確認

```
mcp__claude_ai_Google_Drive__search_files
  query: "title = '作業ログ' and mimeType = 'application/vnd.google-apps.folder'"
  pageSize: 3
```

見つからない場合は作成:

```
mcp__claude_ai_Google_Drive__create_file
  title: "作業ログ"
  mimeType: "application/vnd.google-apps.folder"
  parentId: <親フォルダID>
```

### ステップ 2: ログ本文を Markdown で準備

テンプレート（`references/template.md` を参照）:

- タイトル・プロジェクト・担当・対応Issue
- 概要（2-3行）
- 成果物（Issue/PR URL）
- 修正内容（ファイル別の変更点）
- 評価結果（メトリクス表）
- 学んだこと（箇条書き）
- 次のステップ

Write ツールで `/tmp/worklog_<date>.md` に保存する。

### ステップ 3: Base64 エンコードしてファイル保存

```bash
python3 -c "import base64; d=open('/tmp/worklog_<date>.md','rb').read(); e=base64.b64encode(d).decode(); open('/tmp/worklog_<date>.b64','w').write(e); print(f'bytes={len(d)}, b64_len={len(e)}')"
```

stdout にはサイズのみ出力。base64 本体は `.b64` ファイルに保存する。

### ステップ 3b: Base64 を Read ツールで context に読み込む

```
Read tool: /tmp/worklog_<date>.b64
```

Read 結果の line 1 に完全な base64 文字列が含まれる。これを次のMCP call にそのまま貼り付ける。

**注意**: 貼り付け時に中略しない。Read 結果の line 1 の末尾 (`=` または `==` パディング、あるいは base64 文字) までを完全にコピーすること。途中省略すると "not a valid base64 string" エラーになる。

### ステップ 4: Google Drive にアップロード

```
mcp__claude_ai_Google_Drive__create_file
  title: "YYYY-MM-DD"
  mimeType: "text/plain"
  parentId: <作業ログフォルダID>
  content: <base64 文字列>
```

**タイトルには作業内容を含めない**: 日付のみの固定形式にする。Google Drive MCP には rename 用ツールが無く、タイトルを後から直すには手動削除 + 再作成が必要になるため、最初から冗長な情報を入れない。

`text/plain` は自動的に Google Docs (`application/vnd.google-apps.document`) に変換される。

### ステップ 5: 作成URLをユーザーに報告

- ドキュメントID: `<id>`
- 閲覧URL: `https://docs.google.com/document/d/<id>/edit`

## トラブルシューティング

### "The file content is not a valid base64 string" エラー

- **最頻出原因**: base64 文字列を MCP call の `content` に貼り付ける際に途中で切り詰められた
- **確認方法**: 貼り付けた base64 の末尾が `A-Za-z0-9+/=` で終わっているか、元の `.b64` ファイルのサイズ (`b64_len`) と一致しているか
- **対応**:
  1. `/tmp/worklog_<date>.b64` を Read ツールで再読み込み
  2. Read 結果の line 1 全体をそのままコピー (中略せず末尾まで)
  3. MCP `create_file` call を再実行
- 別原因: Markdown に無効なバイト列が含まれる場合は `python3 -c "import base64; base64.b64decode(open('/tmp/worklog_<date>.b64').read())"` でラウンドトリップ検証

### "Stream closed" エラー

- 原因: コンテンツサイズが大きすぎる、またはタイムアウト
- 対応:
  1. Markdown の冗長な部分を削除し、簡潔版にする
  2. 評価結果の詳細は別ファイルに分割し、リンクのみ含める
  3. 再試行

### "token expired" エラー

- 原因: Google Drive MCP の認証トークン期限切れ
- 対応: ユーザーに `/mcp` → Google Drive → Reconnect を依頼

### フォルダが存在しない

- ユーザーにフォルダ名・場所を確認
- 必要に応じて親フォルダID を受け取り、新規作成する

## 参考情報

### 対応する類似ツール

本skillはGoogle Drive向けだが、他の外部ツールへの記録にも応用可能:

- **Gmail** (`mcp__claude_ai_Gmail__create_draft`): 作業報告メールの下書き
- **Google Calendar** (`mcp__claude_ai_Google_Calendar__create_event`): イベントの詳細欄に作業内容を記載
- **Canva** (`mcp__claude_ai_Canva__generate-design`): ビジュアルサマリーを作成

### Markdown テンプレート

`references/template.md` 参照。

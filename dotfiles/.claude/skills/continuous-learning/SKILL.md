---
name: continuous-learning
description: >
  セッションからの自動パターン学習 skill。セッション終了時にパターンを抽出し、
  再利用可能なインスティンクト（学習済み行動）として保存。
  /learn で手動実行、またはセッション終了フックで自動実行。
  「パターンを学習して」「このセッションから学んで」のような場面で使用。
---

# continuous-learning: セッションパターン学習 Skill

セッションから再利用可能なパターンを抽出し、プロジェクト別に保存する。

## Arguments

- `/learn` --- 現在のセッションからパターンを手動抽出
- `/learn status` --- 学習済みインスティンクトの一覧表示
- `/learn promote <id>` --- プロジェクト固有パターンをグローバルに昇格

## Instinct Model

インスティンクト = 小さな学習済み行動:

```yaml
id: prefer-functional-style
trigger: "新しい関数を書く時"
confidence: 0.7  # 0.3=tentative, 0.5=moderate, 0.7=strong, 0.9=near-certain
domain: code-style  # code-style/testing/git/debugging/workflow
scope: project  # project or global
```

## Execution Flow

### Step 1: Session Analysis

1. 現在のセッションの会話を分析。
2. 以下のパターンカテゴリを検出:
   - **ユーザー修正**: ユーザーがアプローチを修正した箇所
   - **エラー解決**: 特定のエラーの解決方法
   - **ワークアラウンド**: フレームワーク/ライブラリの回避策
   - **デバッグ手法**: 効果的なデバッグアプローチ
   - **プロジェクト固有規約**: このプロジェクト特有のパターン

### Step 2: Instinct Extraction

1. 検出されたパターンごとにインスティンクトを生成。
2. スコープを判定:
   - **project**: 言語/FW 固有、ファイル構造、コードスタイル
   - **global**: セキュリティ、一般的なベストプラクティス、ツールワークフロー
3. 信頼度を設定（初回は 0.5、繰り返し観測で上昇）。

### Step 3: Save

1. インスティンクトを `~/.claude/learned/<scope>/` に保存。
2. 既存インスティンクトと重複する場合は信頼度を更新。

### Step 4: Report

抽出結果を報告:

```
## 学習パターン (N件)

| ID | Trigger | Domain | Confidence | Scope |
|---|---|---|---|---|
| prefer-functional | 新しい関数を書く時 | code-style | 0.5 | project |
| always-validate | 外部入力を処理する時 | security | 0.7 | global |
```

## Confidence Evolution

- 繰り返し観測 --- 信頼度上昇
- ユーザーによる修正 --- 信頼度下降
- 長期間未観測 --- 信頼度減衰
- 2プロジェクト以上で観測 --- global 昇格候補

## File Structure

```
~/.claude/learned/
  global/          # グローバルインスティンクト
    always-validate.yaml
    grep-before-edit.yaml
  projects/
    <project-hash>/
      project.json    # プロジェクトメタデータ
      instincts/
        prefer-functional.yaml
        use-react-hooks.yaml
```

## Privacy

- 観測データはローカルマシンにのみ保存
- エクスポートはインスティンクト（パターン）のみ（生の会話は含まない）
- プロジェクト間は自動的に分離

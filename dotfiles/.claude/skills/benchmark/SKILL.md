---
name: benchmark
description: >
  パフォーマンスベースラインと回帰検出 skill。PR前後のパフォーマンス影響を測定。
  /benchmark で起動。パフォーマンス変更時、リリース前チェック時に使用。
  「パフォーマンスを測定して」「遅くなっていないか確認」のような場面で使用。
---

# benchmark: パフォーマンスベンチマーク Skill

パフォーマンスベースラインの設定と変更前後の比較を行う。

## Arguments

- `/benchmark` --- 現在のメトリクスを測定して表示
- `/benchmark baseline` --- 現在のメトリクスをベースラインとして保存
- `/benchmark compare` --- ベースラインと現在値を比較
- `/benchmark build` --- ビルドパフォーマンスのみ測定

## Execution Flow

### Mode 1: Build Performance

開発フィードバックループの測定:

| Metric | Command | Target |
|---|---|---|
| Cold build | `npm run build` / `cargo build` | < 30s |
| Hot reload | HMR 測定 | < 1s |
| Test suite | `npm test` / `pytest` | < 60s |
| Type check | `tsc --noEmit` / `mypy` | < 15s |
| Lint | `npm run lint` / `ruff` | < 10s |

### Mode 2: API Performance (該当する場合)

1. 各エンドポイントを N 回リクエスト。
2. 測定: p50, p95, p99 レイテンシ。
3. レスポンスサイズとステータスコードを記録。

### Mode 3: Before/After Comparison

```
/benchmark baseline    # 現在のメトリクスを保存
# ... 変更を実施 ...
/benchmark compare     # ベースラインと比較
```

出力:

```
| Metric | Before | After | Delta | Verdict |
|---|---|---|---|---|
| Build | 12s | 14s | +2s | WARN |
| Tests | 45s | 43s | -2s | BETTER |
| Bundle | 180KB | 175KB | -5KB | BETTER |
```

### Baseline Storage

ベースラインは `.benchmark-baseline.json` に保存（Git 追跡対象）:

```json
{
  "timestamp": "2026-04-01T12:00:00Z",
  "build_time_ms": 12000,
  "test_time_ms": 45000,
  "lint_time_ms": 3000,
  "bundle_size_kb": 180
}
```

## Verdict Rules

| Delta | Verdict |
|---|---|
| <= -5% | BETTER |
| -5% ~ +10% | OK |
| +10% ~ +25% | WARN |
| > +25% | REGRESSION |

## Safety Guards

- ベンチマーク実行はローカル環境のみ
- 本番 API へのベンチマークは明示的な許可が必要
- 結果に秘密情報を含めない

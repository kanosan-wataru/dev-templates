# Copilot Skills

GitHub Copilot CLI 用の skill 群。`~/.copilot/skills/` の内容をテンプレート化したもの。

## 同梱 skill

| Skill | 用途 | 出処・ライセンス |
|---|---|---|
| `pptx` | `.pptx` ファイルの読み取り・編集・生成 | Anthropic 由来。利用は Anthropic サービス利用契約の枠内に限る |
| `slidekit-create` | HTML スライド（1280x720px、Tailwind + Font Awesome）生成 | カスタム skill |
| `slidekit-templ` | PDF プレゼン → HTML スライドテンプレート変換 | カスタム skill |

## 利用方法

GitHub Copilot CLI は通常 `~/.copilot/skills/` を参照する。本リポジトリの skill を有効にするには、いずれかを行う:

### 方法 1: ホームへコピー（推奨）

```bash
rsync -av .copilot/skills/ ~/.copilot/skills/
```

### 方法 2: symlink

```bash
ln -sfn "$(pwd)/.copilot/skills/pptx" ~/.copilot/skills/pptx
ln -sfn "$(pwd)/.copilot/skills/slidekit-create" ~/.copilot/skills/slidekit-create
ln -sfn "$(pwd)/.copilot/skills/slidekit-templ" ~/.copilot/skills/slidekit-templ
```

## skill 別 前提条件

### pptx

- Python 3.11+、`markitdown`、`python-pptx`、`pptxgenjs`（Node）
- LibreOffice（`scripts/office/soffice.py` 利用時）

### slidekit-create / slidekit-templ

- Node + Tailwind CDN（オフライン時はローカル CDN 必要）
- slidekit-templ のみ `poppler`（`pdftoppm`）が必要

## 更新方法

`~/.copilot/skills/` 側で更新があった場合は、以下で再同期:

本リポジトリでは `imgen` skill を取り込み対象から除外している。再同期時にも除外すること:

```bash
rsync -av --delete \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='.DS_Store' \
  --exclude='imgen/' \
  ~/.copilot/skills/ \
  .copilot/skills/
```

## 除外対象

`.gitignore` のグローバル `__pycache__/` と `*.pyc` で対応済み。

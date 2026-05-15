#!/usr/bin/env python3
"""Claude/OpenCode/Gemini 形式の .md エージェントを Codex の .toml に変換する。

Claude の subagent ファイル (Markdown + YAML frontmatter) を読み、
Codex の TOML 形式 (name / description / developer_instructions) に変換して
出力ディレクトリに書き出す。

NOTE: PyYAML 等の外部依存はあえて使わず、frontmatter を簡易パーサで処理する。
      Claude/OpenCode の subagent frontmatter は単純な key: value のみで
      ネスト構造は使われないため stdlib のみで十分。

Usage:
    sync-codex-agents.py [SOURCE_DIR] [TARGET_DIR]

    SOURCE_DIR  読み込み元 (default: ~/.config/skillshare/agents)
    TARGET_DIR  書き出し先 (default: ~/.codex/agents)
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

# 出力ファイル名として安全な文字のみを許可 (パストラバーサル対策)
# 先頭文字を英数字に限定することで "." / ".." / ".hidden" 等を排除する。
_SAFE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.\-]*$")


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """先頭の `---` で囲まれた frontmatter を解析する。

    戻り値: (frontmatter dict, 本文 str)
    frontmatter が無い場合は dict={} と本文全体を返す。
    """
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        return {}, text

    front_end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            front_end = i
            break
    if front_end is None:
        return {}, text

    fm: dict[str, str] = {}
    for raw in lines[1:front_end]:
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        # YAML の "..." / '...' リテラルを軽く剥がす
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
            value = value[1:-1]
        # YAML 文字列の "\n" エスケープを実際の改行に戻す (description が長文の場合)
        value = value.replace("\\n", "\n")
        fm[key] = value

    body = "".join(lines[front_end + 1:]).lstrip("\n")
    return fm, body


def toml_escape_basic(s: str) -> str:
    """TOML basic string 用エスケープ (1行向け)。"""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def toml_multiline(s: str) -> str:
    # TOML literal multi-line string ('''...''') を使い、エスケープを完全に回避する。
    # 本文に ''' が含まれるとリテラル文字列内で表現できない (TOML 仕様)。
    # basic multi-line string にフォールバックする方式は境界ケース ("..." 末尾、3 連続 " など)
    # で破綻しうるため、安全側に倒して ValueError で reject する。実用上 agent 本文に '''
    # が現れることはほぼ無い。
    if "'''" in s:
        raise ValueError("body contains ''' which cannot be safely emitted as TOML literal string")
    return f"'''\n{s}\n'''"


def convert(md_path: Path, out_dir: Path) -> Path:
    """単一ファイルを変換し、書き出し先パスを返す。"""
    text = md_path.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(text)

    # name: frontmatter > ファイル名 (stem)
    # ファイル名生成に使うため、パストラバーサル等を防ぐべく文字種を制限する。
    name = fm.get("name") or md_path.stem
    if not _SAFE_NAME_RE.match(name):
        raise ValueError(f"unsafe agent name (not a plain identifier): {name!r}")
    description = fm.get("description", "").strip()
    developer_instructions = body.strip()

    lines = [
        "# Generated from Claude/Skillshare agents (.md). Do not edit manually.",
        f'name = "{toml_escape_basic(name)}"',
        f'description = {toml_multiline(description)}',
        f'developer_instructions = {toml_multiline(developer_instructions)}',
    ]

    # 任意項目を保持 (model のみ最小対応。Codex の値域と異なる場合は省略)
    model = fm.get("model", "").strip()
    if model:
        lines.append(f'model = "{toml_escape_basic(model)}"')

    out_path = out_dir / f"{name}.toml"
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return out_path


def main(argv: list[str]) -> int:
    home = Path(os.path.expanduser("~"))
    src = Path(argv[1]) if len(argv) > 1 else home / ".config" / "skillshare" / "agents"
    dst = Path(argv[2]) if len(argv) > 2 else home / ".codex" / "agents"

    if not src.is_dir():
        print(f"[sync-codex-agents] source not found: {src}", file=sys.stderr)
        return 1
    dst.mkdir(parents=True, exist_ok=True)

    md_files = sorted(p for p in src.iterdir() if p.is_file() and p.suffix == ".md")
    if not md_files:
        print(f"[sync-codex-agents] no .md files in {src}")
        return 0

    converted = 0
    failed: list[tuple[Path, Exception]] = []
    for md in md_files:
        try:
            convert(md, dst)
            converted += 1
        except Exception as exc:  # noqa: BLE001
            failed.append((md, exc))

    print(f"[sync-codex-agents] converted {converted}/{len(md_files)} -> {dst}")
    if failed:
        for path, exc in failed:
            print(f"  FAILED: {path.name}: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

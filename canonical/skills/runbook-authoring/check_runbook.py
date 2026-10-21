#!/usr/bin/env python3
"""手順書（ランブック）の形を検査する。

使い方:
  python3 check_runbook.py [--root <リポジトリの一番上>] <手順書の置き場か手順書のファイル>...

置き場（フォルダ）を渡すと、置き場の *.md（README.md を除く）を手順書として検査し、
README.md（一覧）との一致（R10）も見る。.md のファイルを渡すと、その手順書だけを検査する。
--root は、コマンドのブロックで呼ぶファイルを引くリポジトリの一番上で、省くと作業ディレクトリを使う。

終了コード: 0 誤りなし / 1 誤りあり / 2 検査ができない（読めない・呼び方の誤り）

Python 3.9 以上の標準ライブラリだけで動く。規則の意味は同じフォルダの SKILL.md の「検査」の節にある。
"""

import argparse
import os
import re
import shlex
import sys
from typing import Dict, List, NamedTuple, Optional, Set, Tuple
from urllib.parse import unquote

# SKILL.md の表と同じ一覧（検査がずれを見る）
SECTIONS = [
    "いつ使うか",
    "前提",
    "手順",
    "確かめ方",
    "止まったときに読む表",
    "失敗や中断のとき",
    "AI が実行するとき",
    "間違えやすい所",
]
PREREQ_LABELS = ["依存", "資格情報", "実行する場所", "1回だけの初期化"]
KINDS = ["ずっと使う", "一時的", "1回だけの初期化"]
KIND_LABEL = "種類"
REMOVE_LABEL = "消す条件"
STEP_LABELS = ["期待する出力", "外れたら"]
MAX_STEPS = 6
WARNING_MARKS = ["⚠", "❗", "❕", "‼", "⁉", "★", "☆", "🚨", "⛔", "🛑", "🔥", "❌"]

SHELL_LANGS = {"bash", "sh", "shell", "zsh"}
INTERPRETERS = {"bash", "sh", "zsh", "python", "python3", "node", "ruby", "perl"}
PREFIX_COMMANDS = {"env", "sudo", "time", "nice", "nohup", "exec", "command"}
OPERATORS = {"&&", "||", ";", "|"}
RULE_ORDER = ["R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "R10"]

FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
INLINE_CODE_RE = re.compile(r"(`+)(.+?)\1")
LINK_RE = re.compile(r"!?\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
LINK_TARGET_RE = re.compile(r"\]\([^)]*\)")
BARE_URL_RE = re.compile(r"https?://\S+")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
ISSUE_RES = [
    re.compile(r"(?<![\w&#/])#[0-9]+"),
    re.compile(r"/(?:issues|pull)/[0-9]+"),
]
DATE_RES = [
    re.compile(r"(?<!\d)\d{4}-\d{1,2}-\d{1,2}(?!\d)"),
    re.compile(r"(?<!\d)\d{4}/\d{1,2}/\d{1,2}(?!\d)"),
    re.compile(r"\d{4}年\d{1,2}月"),
]
NON_ASCII_AFTER_VAR_RE = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7f]")
ASSIGNMENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
LEAD_RE = re.compile(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)?")


class Finding(NamedTuple):
    path: str
    line: int
    rule: str
    message: str


class Block(NamedTuple):
    lang: str
    start: int  # 開きのフェンスの行番号（1から）
    lines: List[Tuple[int, str]]


class Doc:
    """手順書を行・コードのブロック・節に分けたもの。"""

    def __init__(self, path: str, text: str) -> None:
        self.path = path
        self.lines = text.splitlines()
        self.in_code: List[bool] = []
        self.blocks: List[Block] = []
        self._split_code()
        self.headings: List[Tuple[int, int, str]] = []  # (行番号, 段, 名前)
        for i, line in enumerate(self.lines):
            if self.in_code[i]:
                continue
            m = HEADING_RE.match(line)
            if m:
                self.headings.append((i + 1, len(m.group(1)), m.group(2).strip()))

    def _split_code(self) -> None:
        fence: Optional[str] = None
        current: Optional[Block] = None
        for i, line in enumerate(self.lines):
            m = FENCE_RE.match(line)
            if fence is None:
                if m:
                    fence = m.group(1)
                    info = m.group(2).strip().split()
                    current = Block(info[0].lower() if info else "", i + 1, [])
                    self.in_code.append(True)
                else:
                    self.in_code.append(False)
                continue
            self.in_code.append(True)
            closes = (
                m is not None
                and m.group(1)[0] == fence[0]
                and len(m.group(1)) >= len(fence)
                and m.group(2).strip() == ""
            )
            if closes:
                assert current is not None
                self.blocks.append(current)
                fence = None
                current = None
            else:
                assert current is not None
                current.lines.append((i + 1, line))
        if current is not None:
            self.blocks.append(current)

    def section_range(self, name: str) -> Optional[Tuple[int, int]]:
        """`##` の節の範囲（見出しの行番号, 次の `##` の行番号）。無ければ None。"""
        h2 = [(no, title) for no, level, title in self.headings if level == 2]
        for idx, (no, title) in enumerate(h2):
            if title == name:
                end = h2[idx + 1][0] if idx + 1 < len(h2) else len(self.lines) + 1
                return no, end
        return None

    def prose(self, start: int = 1, end: Optional[int] = None) -> List[Tuple[int, str]]:
        """コードの外の行（インラインのコードを除いたもの）。"""
        stop = len(self.lines) + 1 if end is None else end
        out = []
        for no in range(start, stop):
            if no - 1 >= len(self.lines) or self.in_code[no - 1]:
                continue
            out.append((no, INLINE_CODE_RE.sub("", self.lines[no - 1])))
        return out

    def shell_blocks(self, start: int = 1, end: Optional[int] = None) -> List[Block]:
        stop = len(self.lines) + 1 if end is None else end
        return [b for b in self.blocks if b.lang in SHELL_LANGS and start <= b.start < stop]


def normalized(line: str) -> str:
    """箇条書きの印・番号・太字を外した行。"""
    return LEAD_RE.sub("", line).replace("**", "").strip()


def labeled(line: str, label: str) -> Optional[str]:
    m = re.match(re.escape(label) + r"\s*[:：]\s*(.*)$", normalized(line))
    return m.group(1).strip() if m else None


def logical_lines(block: Block) -> List[Tuple[int, str]]:
    """行の末尾の `\\` でつないだ行を1つにし、空の行とコメントだけの行を除く。"""
    out: List[Tuple[int, str]] = []
    buf = ""
    first = 0
    for no, line in block.lines:
        if not buf:
            first = no
        if line.rstrip().endswith("\\"):
            buf += line.rstrip()[:-1] + " "
            continue
        buf += line
        text = buf.strip()
        buf = ""
        if text and not text.startswith("#"):
            out.append((first, text))
    if buf.strip() and not buf.strip().startswith("#"):
        out.append((first, buf.strip()))
    return out


def called_paths(text: str) -> List[str]:
    """コマンドの行で、呼んでいるファイルのパスらしい語。"""
    try:
        tokens = shlex.split(text, comments=True, posix=True)
    except ValueError:
        tokens = text.split()
    segments: List[List[str]] = [[]]
    for tok in tokens:
        if tok in OPERATORS:
            segments.append([])
        else:
            segments[-1].append(tok)
    found = []
    for seg in segments:
        i = 0
        while i < len(seg) and (ASSIGNMENT_RE.match(seg[i]) or seg[i] in PREFIX_COMMANDS):
            i += 1
            while i < len(seg) and seg[i].startswith("-"):
                i += 1
        if i >= len(seg):
            continue
        cand = seg[i]
        if cand in INTERPRETERS:
            i += 1
            while i < len(seg) and seg[i].startswith("-"):
                i += 1
            if i >= len(seg):
                continue
            cand = seg[i]
        if looks_relative_path(cand):
            found.append(cand)
    return found


def looks_relative_path(word: str) -> bool:
    if "/" not in word:
        return False
    if word.startswith(("/", "~", "$", "-", "<")) or SCHEME_RE.match(word):
        return False
    return not any(c in word for c in "$<>*?{}")


def is_shell_script(path: str) -> bool:
    if path.endswith(".sh"):
        return True
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            first = f.readline()
    except OSError:
        return False
    return first.startswith("#!") and bool(re.search(r"\b(bash|sh|zsh)\b", first))


def non_ascii_after_var(lines: List[Tuple[int, str]]) -> List[Tuple[int, str]]:
    out = []
    for no, line in lines:
        if line.strip().startswith("#"):
            continue
        m = NON_ASCII_AFTER_VAR_RE.search(line)
        if m:
            out.append((no, m.group(0)))
    return out


def check_runbook(doc: Doc, root: str, scripts: Dict[str, str]) -> List[Finding]:
    f: List[Finding] = []

    def add(line: int, rule: str, message: str) -> None:
        f.append(Finding(doc.path, line, rule, message))

    # R1 節の有無と順
    found: List[Tuple[int, str]] = []
    seen: Set[str] = set()
    for no, level, title in doc.headings:
        if level != 2 or title not in SECTIONS:
            continue
        if title in seen:
            add(no, "R1", "節が2回ある: " + title)
            continue
        seen.add(title)
        found.append((no, title))
    for name in SECTIONS:
        if name not in seen:
            add(1, "R1", "節が無い: " + name)
    expected = [name for name in SECTIONS if name in seen]
    for (no, title), want in zip(found, expected):
        if title != want:
            add(no, "R1", "節の順が違う: 「{}」の位置には「{}」を置く".format(title, want))
            break

    # R2 前提の型
    rng = doc.section_range("前提")
    if rng:
        prose = doc.prose(rng[0] + 1, rng[1])
        for label in PREREQ_LABELS:
            if not any(labeled(text, label) is not None for _, text in prose):
                add(rng[0], "R2", "前提の行が無い: {}:".format(label))

    # R3 種類
    rng = doc.section_range("いつ使うか")
    if rng:
        prose = doc.prose(rng[0] + 1, rng[1])
        kinds = [(no, labeled(text, KIND_LABEL)) for no, text in prose]
        kinds = [(no, v) for no, v in kinds if v is not None]
        if not kinds:
            add(rng[0], "R3", "{}: の行が無い".format(KIND_LABEL))
        else:
            no, value = kinds[0]
            kind = next(
                (k for k in KINDS if re.match(re.escape(k) + r"(?:$|[\s（(。、・])", value)), None
            )
            if kind is None:
                add(no, "R3", "種類が決まった値でない: {}（{} のどれか）".format(value, "・".join(KINDS)))
            elif kind == "一時的" and not any(
                labeled(text, REMOVE_LABEL) is not None for _, text in prose
            ):
                add(no, "R3", "一時的な手順書に {}: の行が無い".format(REMOVE_LABEL))

    # R4 手順の段
    rng = doc.section_range("手順")
    if rng:
        steps = [(no, title) for no, level, title in doc.headings if level == 3 and rng[0] < no < rng[1]]
        if not 1 <= len(steps) <= MAX_STEPS:
            add(rng[0], "R4", "手順の段（###）が {} 個ある（1〜{} にする）".format(len(steps), MAX_STEPS))
        for idx, (no, title) in enumerate(steps):
            end = steps[idx + 1][0] if idx + 1 < len(steps) else rng[1]
            blocks = doc.shell_blocks(no, end)
            if len(blocks) > 1:
                add(blocks[1].start, "R4", "段「{}」にコマンドのブロックが {} 個ある（1つにする）".format(title, len(blocks)))
            if blocks:
                texts = [normalized(text) for _, text in doc.prose(no + 1, end)]
                for label in STEP_LABELS:
                    if not any(t.startswith(label) for t in texts):
                        add(no, "R4", "段「{}」に「{}」の行が無い".format(title, label))

    # R5 参照の実在
    base = os.path.dirname(doc.path)
    for no, text in doc.prose():
        for m in LINK_RE.finditer(text):
            target = m.group(2)
            if target.startswith(("#", "/")) or SCHEME_RE.match(target):
                continue
            rel = unquote(target.split("#", 1)[0].split("?", 1)[0])
            if rel and not os.path.exists(os.path.join(base, rel)):
                add(no, "R5", "リンクの先が無い: " + target)
    for block in doc.shell_blocks():
        for no, text in logical_lines(block):
            for cand in called_paths(text):
                path = os.path.normpath(os.path.join(root, cand))
                if not os.path.exists(path):
                    add(no, "R5", "呼んでいるファイルが無い: {}（--root から引いた）".format(cand))
                elif os.path.isfile(path) and is_shell_script(path):
                    scripts.setdefault(path, doc.path)

    # R6 issue の番号・R7 日付・R8 警告の印
    pitfalls = doc.section_range("間違えやすい所")
    for no, text in doc.prose():
        scan6 = text
        if pitfalls and pitfalls[0] <= no < pitfalls[1]:
            scan6 = LINK_RE.sub("", text)
        for rx in ISSUE_RES:
            m = rx.search(scan6)
            if m:
                add(no, "R6", "本文に issue の番号がある: " + m.group(0))
                break
        scan7 = BARE_URL_RE.sub("", LINK_TARGET_RE.sub("]()", text))
        for rx in DATE_RES:
            m = rx.search(scan7)
            if m:
                add(no, "R7", "本文に日付がある: " + m.group(0))
                break
        marks = [c for c in WARNING_MARKS if c in text]
        if marks:
            add(no, "R8", "本文に警告の印がある: " + " ".join(marks))

    # R9 変数の直後の ASCII 以外の文字（手順書のコマンドのブロック）
    for block in doc.shell_blocks():
        for no, excerpt in non_ascii_after_var(block.lines):
            add(no, "R9", "変数の直後に ASCII 以外の文字がある（${…} で囲む）: " + excerpt)

    return f


def check_scripts(scripts: Dict[str, str]) -> List[Finding]:
    f: List[Finding] = []
    for path in sorted(scripts):
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = list(enumerate(fh.read().splitlines(), start=1))
        for no, excerpt in non_ascii_after_var(lines):
            f.append(
                Finding(
                    os.path.relpath(path),
                    no,
                    "R9",
                    "変数の直後に ASCII 以外の文字がある（${…} で囲む）: " + excerpt,
                )
            )
    return f


def check_index(folder: str, runbooks: List[str]) -> List[Finding]:
    readme = os.path.join(folder, "README.md")
    if not os.path.isfile(readme):
        return [Finding(folder, 0, "R10", "一覧（README.md）が無い")]
    doc = Doc(readme, read_text(readme))
    listed: Dict[str, int] = {}
    for no, text in doc.prose():
        for m in LINK_RE.finditer(text):
            target = m.group(2)
            if target.startswith(("#", "/")) or SCHEME_RE.match(target):
                continue
            rel = os.path.normpath(unquote(target.split("#", 1)[0]))
            if rel.endswith(".md") and os.sep not in rel and rel != "README.md":
                listed.setdefault(rel, no)
    present = {os.path.basename(p) for p in runbooks}
    f = []
    for name in sorted(present - set(listed)):
        f.append(Finding(readme, 1, "R10", "一覧に無い手順書: " + name))
    for name in sorted(set(listed) - present):
        f.append(Finding(readme, listed[name], "R10", "一覧が指す手順書が無い: " + name))
    return f


def read_text(path: str) -> str:
    with open(path, encoding="utf-8-sig") as fh:
        return fh.read()


class Unreadable(Exception):
    pass


def collect(paths: List[str]) -> Tuple[List[Tuple[str, List[str]]], List[str]]:
    """渡されたパスを、(置き場, 手順書の並び) と単独の手順書に分ける。"""
    folders: List[Tuple[str, List[str]]] = []
    singles: List[str] = []
    for p in paths:
        if os.path.isdir(p):
            names = sorted(
                n for n in os.listdir(p) if n.endswith(".md") and n != "README.md" and os.path.isfile(os.path.join(p, n))
            )
            folders.append((p, [os.path.join(p, n) for n in names]))
        elif os.path.isfile(p) and p.endswith(".md"):
            singles.append(p)
        elif os.path.exists(p):
            raise Unreadable("{}: .md のファイルでも置き場のフォルダでもない".format(p))
        else:
            raise Unreadable("{}: 無い".format(p))
    return folders, singles


def run(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="手順書（ランブック）の形を検査する。")
    parser.add_argument("--root", default=".", help="コマンドのブロックで呼ぶファイルを引くリポジトリの一番上（既定: 作業ディレクトリ）")
    parser.add_argument("paths", nargs="+", help="手順書の置き場か、手順書のファイル")
    args = parser.parse_args(argv)
    if not os.path.isdir(args.root):
        print("検査できない: --root {}: フォルダでない".format(args.root), file=sys.stderr)
        return 2
    try:
        folders, singles = collect(args.paths)
        findings: List[Finding] = []
        scripts: Dict[str, str] = {}
        targets = [rb for _, rbs in folders for rb in rbs] + singles
        for path in targets:
            try:
                doc = Doc(path, read_text(path))
            except (OSError, UnicodeDecodeError) as exc:
                raise Unreadable("{}: 読めない（{}）".format(path, exc.__class__.__name__))
            findings.extend(check_runbook(doc, args.root, scripts))
        for folder, runbooks in folders:
            try:
                findings.extend(check_index(folder, runbooks))
            except (OSError, UnicodeDecodeError) as exc:
                raise Unreadable("{}: 一覧を読めない（{}）".format(folder, exc.__class__.__name__))
        findings.extend(check_scripts(scripts))
    except Unreadable as exc:
        print("検査できない: {}".format(exc), file=sys.stderr)
        return 2
    order = {r: i for i, r in enumerate(RULE_ORDER)}
    seen_paths: List[str] = []
    for item in findings:
        if item.path not in seen_paths:
            seen_paths.append(item.path)
    findings.sort(key=lambda x: (seen_paths.index(x.path), x.line, order[x.rule]))
    for item in findings:
        print("{} {}:{} {}".format(item.rule, item.path, item.line, item.message))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(run(sys.argv[1:]))

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
SHELLS = {"bash", "sh", "zsh"}
INTERPRETERS = SHELLS | {"python", "python3", "node", "ruby", "perl"}
# 次の引数をソースの文字列として受け取る、シェルでない解釈器のオプション
INLINE_SOURCE_OPTIONS = {"-c", "-e", "-m", "-E", "--eval"}
# 前に付くコマンドと、値を1つ取るそのオプション
PREFIX_COMMANDS = {
    "env": {"-u", "-C", "-S"},
    "sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U"},
    "time": {"-o", "-f"},
    "nice": {"-n"},
    "nohup": set(),
    "exec": {"-a"},
    "command": set(),
}
SEPARATORS = {";", "&&", "||", "|", "&", "|&", ";;", "(", ")"}
REDIRECTS = {"<", ">", ">>", "<<", "<<<", "<>", ">|", "&>", "&>>", ">&", "<&"}
# 引用の外で演算子として読む文字の並び（長いものから試す）
OPERATORS = sorted(SEPARATORS | REDIRECTS, key=len, reverse=True)
RULE_ORDER = ["R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "R10"]

FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
INLINE_CODE_RE = re.compile(r"(`+)(.+?)\1")
# インラインのリンク [文字](先) と [文字](<空白を含む先>)
INLINE_LINK_RE = re.compile(r"!?\[([^\]]*)\]\(\s*(?:<([^>]+)>|([^)\s]+))(?:\s+\"[^\"]*\")?\s*\)")
# 参照の形のリンクの定義 [名前]: 先
REF_DEF_RE = re.compile(r"^\s{0,3}\[([^\]]+)\]:\s*(?:<([^>]+)>|(\S+))")
# 参照の形のリンクの使う側 [文字][名前]
REF_USE_RE = re.compile(r"\[([^\]]*)\]\[([^\]]*)\]")
# 参照の形のリンクの省略した使い方 [名前]（定義があるときだけリンクになる）
REF_SHORT_RE = re.compile(r"\[([^\]]+)\](?![\[(:])")
AUTOLINK_RE = re.compile(r"<[A-Za-z][A-Za-z0-9+.-]*:[^>\s]*>")
BARE_URL_RE = re.compile(r"https?://\S+")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
ISSUE_NUMBER_RE = re.compile(r"(?<![&#])#[0-9]+")
ISSUE_PATH_RE = re.compile(r"/(?:issues|pull)/[0-9]+")
DATE_RES = [
    re.compile(r"(?<!\d)\d{4}-\d{1,2}-\d{1,2}(?!\d)"),
    re.compile(r"(?<!\d)\d{4}/\d{1,2}/\d{1,2}(?!\d)"),
    re.compile(r"\d{4}年\d{1,2}月"),
]
VAR_NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
HEREDOC_RE = re.compile(r"<<(-?)\s*(\\?)(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\3")
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


class Unreadable(Exception):
    pass


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

    def ref_definitions(self) -> Dict[str, Tuple[int, str]]:
        """参照の形のリンクの定義。名前（小文字）から (行番号, 先)。"""
        defs: Dict[str, Tuple[int, str]] = {}
        for no, text in self.prose():
            m = REF_DEF_RE.match(text)
            if m:
                defs.setdefault(m.group(1).strip().lower(), (no, m.group(2) or m.group(3)))
        return defs

    def ref_uses(self, defs: Dict[str, Tuple[int, str]]) -> List[Tuple[int, str]]:
        """参照の形のリンクを使っている所。(行番号, 名前（小文字）)。定義の行は除く。"""
        out = []
        for no, text in self.prose():
            if REF_DEF_RE.match(text):
                continue
            rest = INLINE_LINK_RE.sub("", text)
            for m in REF_USE_RE.finditer(rest):
                name = (m.group(2) or m.group(1)).strip().lower()
                if name in defs:
                    out.append((no, name))
            for m in REF_SHORT_RE.finditer(REF_USE_RE.sub("", rest)):
                name = m.group(1).strip().lower()
                if name in defs:
                    out.append((no, name))
        return out

    def link_targets(self) -> List[Tuple[int, str]]:
        """本文のリンクの先（インラインの形と、参照の形の定義）。"""
        out = []
        for no, text in self.prose():
            m = REF_DEF_RE.match(text)
            if m:
                out.append((no, m.group(2) or m.group(3)))
                continue
            for m in INLINE_LINK_RE.finditer(text):
                out.append((no, m.group(2) or m.group(3)))
        return out


def local_target(target: str) -> Optional[str]:
    """リンクの先が手元のファイルなら、`#` と `?` を外したパスを返す。外の URL・ページの中・絶対のパスなら None。"""
    target = target.strip()
    if not target or target.startswith(("#", "/")) or SCHEME_RE.match(target):
        return None
    rel = unquote(target.split("#", 1)[0].split("?", 1)[0])
    return rel or None


def without_links(text: str) -> str:
    """インラインのリンク・参照の形のリンク・自動のリンクを外した文。"""
    text = INLINE_LINK_RE.sub("", text)
    text = REF_USE_RE.sub("", text)
    text = REF_SHORT_RE.sub("", text)
    return AUTOLINK_RE.sub("", text)


def without_targets(text: str) -> str:
    """リンクの文字は残し、リンクの先と URL を外した文。"""
    if REF_DEF_RE.match(text):
        return ""
    text = INLINE_LINK_RE.sub(lambda m: "[" + m.group(1) + "]", text)
    text = AUTOLINK_RE.sub("", text)
    return BARE_URL_RE.sub("", text)


def normalized(line: str) -> str:
    """箇条書きの印・番号・太字を外した行。"""
    return LEAD_RE.sub("", line).replace("**", "").strip()


def labeled(line: str, label: str) -> Optional[str]:
    m = re.match(re.escape(label) + r"\s*[:：]\s*(.*)$", normalized(line))
    return m.group(1).strip() if m else None


class ShellText(NamedTuple):
    code: List[Tuple[int, str, bool]]  # (行番号, 注釈を外したコマンドの行, 行の終わりで引用が開いているか)
    non_ascii: List[Tuple[int, str]]  # 展開される `$名前` の直後に ASCII 以外の文字が来る所（R9）


def scan_shell(lines: List[Tuple[int, str]]) -> ShellText:
    """シェルの行を、引用・注釈・ヒアドキュメントを追いながら1回読む。

    ヒアドキュメントの本文と終端の行はコマンドに入れない。区切りを引用した本文は展開されないので R9 も見ない。
    """
    code: List[Tuple[int, str, bool]] = []
    out: List[Tuple[int, str]] = []
    quote = ""  # "" / "'" / '"'（行をまたいで続く）
    heredoc: Optional[Tuple[str, bool, bool]] = None  # (区切り, 展開しない, 先頭のタブを外す)
    pending: List[Tuple[str, bool, bool]] = []
    for no, line in lines:
        if heredoc is not None:
            delim, literal, dash = heredoc
            if (line.lstrip("\t") if dash else line) == delim:
                heredoc = pending.pop(0) if pending else None
            elif not literal:
                check_dollars(no, line, out)
            continue
        i = 0
        cut = len(line)
        while i < len(line):
            c = line[i]
            if quote == "'":
                if c == "'":
                    quote = ""
                i += 1
                continue
            if c == "\\":
                i += 2
                continue
            if quote == '"':
                if c == '"':
                    quote = ""
                elif c == "$":
                    check_dollar(no, line, i, out)
                i += 1
                continue
            if c in "'\"":
                quote = c
            elif c == "#" and (i == 0 or line[i - 1] in " \t;&|()"):
                cut = i
                break
            elif c == "$":
                check_dollar(no, line, i, out)
            elif line.startswith("<<<", i):
                i += 3  # here-string はヒアドキュメントではない
                continue
            elif c == "<":
                m = HEREDOC_RE.match(line, i)
                if m:
                    pending.append((m.group(4), bool(m.group(2) or m.group(3)), m.group(1) == "-"))
                    i = m.end()
                    continue
            i += 1
        code.append((no, line[:cut], quote != ""))
        if pending and quote == "":
            heredoc = pending.pop(0)
    return ShellText(code, out)


def logical_lines(block: Block) -> List[Tuple[int, str]]:
    """コマンドの行を、行の末尾の `\\` と、行をまたぐ引用でつないで1つにする。空の行は除く。

    シェルは `\\` と改行を取り除くだけで空白を足さないので、ここでも空白を足さずにつなぐ。
    """
    out: List[Tuple[int, str]] = []
    buf = ""
    first = 0
    for no, code, quote_open in scan_shell(block.lines).code:
        if not buf:
            first = no
        if quote_open:
            buf += code + "\n"
            continue
        if code.endswith("\\") and not code.endswith("\\\\"):
            buf += code[:-1]
            continue
        buf += code
        if buf.strip():
            out.append((first, buf.strip()))
        buf = ""
    if buf.strip():
        out.append((first, buf.strip()))
    return out


def shell_words(text: str) -> List[Tuple[str, bool]]:
    """コマンドの行を語に分ける。(語, 演算子か)。引用とエスケープを外し、演算子は引用の外のものだけを演算子にする。"""
    words: List[Tuple[str, bool]] = []
    buf = ""
    started = False
    quote = ""
    i = 0

    def flush() -> None:
        nonlocal buf, started
        if started:
            words.append((buf, False))
        buf = ""
        started = False

    while i < len(text):
        c = text[i]
        if quote == "'":
            if c == "'":
                quote = ""
            else:
                buf += c
            i += 1
            continue
        if quote == '"':
            if c == '"':
                quote = ""
            elif c == "\\" and i + 1 < len(text) and text[i + 1] in '$`"\\':
                buf += text[i + 1]
                i += 1
            else:
                buf += c
            i += 1
            continue
        if c == "\\":
            if i + 1 < len(text):
                buf += text[i + 1]
                started = True
            i += 2
            continue
        if c in "'\"":
            quote = c
            started = True
            i += 1
            continue
        if c.isspace():
            flush()
            i += 1
            continue
        op = next((o for o in OPERATORS if text.startswith(o, i)), None)
        if op is not None:
            if op[0] in "<>" and started and buf.isdigit():
                buf = ""  # 2> のように番号の付いたリダイレクト
                started = False
            flush()
            words.append((op, True))
            i += len(op)
            continue
        buf += c
        started = True
        i += 1
    flush()
    return words


def called_paths(text: str) -> List[str]:
    """コマンドの行で、呼んでいるファイルのパスらしい語（`/` を含む相対のパス）。"""
    segments: List[List[str]] = [[]]
    skip_next = False
    for word, is_op in shell_words(text):
        if skip_next:
            skip_next = False
            continue
        if is_op and word in SEPARATORS:
            segments.append([])
        elif is_op:
            skip_next = True  # リダイレクトの先・元は呼ぶファイルではない
        else:
            segments[-1].append(word)
    found: List[str] = []
    for seg in segments:
        i = 0
        while i < len(seg):
            if ASSIGNMENT_RE.match(seg[i]):
                i += 1
            elif seg[i] in PREFIX_COMMANDS:
                takes_value = PREFIX_COMMANDS[seg[i]]
                i += 1
                while i < len(seg) and seg[i].startswith("-"):
                    i += 2 if seg[i] in takes_value else 1
            else:
                break
        if i >= len(seg):
            continue
        cand = seg[i]
        if cand in INTERPRETERS:
            shell = cand in SHELLS
            i += 1
            inline = False
            while i < len(seg) and seg[i].startswith("-"):
                opt = seg[i]
                if shell and not opt.startswith("--") and "c" in opt[1:]:
                    if i + 1 < len(seg):
                        found.extend(called_paths(seg[i + 1]))  # bash -c '…' の中はシェルのコマンド
                    inline = True
                    break
                if not shell and (opt in INLINE_SOURCE_OPTIONS or opt[:2] in INLINE_SOURCE_OPTIONS):
                    inline = True  # python3 -c '…' などの中はシェルではないので読まない
                    break
                i += 1
            if inline or i >= len(seg):
                continue
            cand = seg[i]
        if looks_relative_path(cand):
            found.append(cand)
    return found


def looks_relative_path(word: str) -> bool:
    if "/" not in word or any(c.isspace() for c in word):
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
    except OSError as exc:
        raise Unreadable("{}: 呼んでいるファイルを読めない（{}）".format(path, exc.__class__.__name__))
    return first.startswith("#!") and bool(re.search(r"\b(bash|sh|zsh)\b", first))


def non_ascii_after_var(lines: List[Tuple[int, str]]) -> List[Tuple[int, str]]:
    """展開される `$名前` の直後に ASCII 以外の文字が来る所（R9）。"""
    return scan_shell(lines).non_ascii


def check_dollars(no: int, line: str, out: List[Tuple[int, str]]) -> None:
    """展開する区切りのヒアドキュメントの行。引用符は文字なので、`\\$` だけを除いて見る。"""
    i = 0
    while i < len(line):
        if line[i] == "\\":
            i += 2
            continue
        if line[i] == "$":
            check_dollar(no, line, i, out)
        i += 1


def check_dollar(no: int, line: str, i: int, out: List[Tuple[int, str]]) -> None:
    m = VAR_NAME_RE.match(line, i + 1)
    if m and m.end() < len(line) and ord(line[m.end()]) > 0x7F:
        excerpt = line[i : m.end() + 1]
        if (no, excerpt) not in out:
            out.append((no, excerpt))


def check_runbook(doc: Doc, root: str, scripts: Dict[str, str]) -> List[Finding]:
    f: List[Finding] = []

    def add(line: int, rule: str, message: str) -> None:
        f.append(Finding(doc.path, line, rule, message))

    # R1 節の有無と順。節が無いときは、その節の中を見る規則（R2〜R4）を出さない
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
    for no, target in doc.link_targets():
        rel = local_target(target)
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
    # 参照の形のリンクは、定義の行でなく、使っている所の節で判定する
    pitfalls = doc.section_range("間違えやすい所")

    def in_pitfalls(no: int) -> bool:
        return bool(pitfalls and pitfalls[0] <= no < pitfalls[1])

    defs = doc.ref_definitions()
    uses = doc.ref_uses(defs)
    used = {name for _, name in uses}
    for no, name in uses:
        m = ISSUE_PATH_RE.search(defs[name][1])
        if m and not in_pitfalls(no):
            add(no, "R6", "参照の形のリンクの先に issue の番号がある: [{}] {}".format(name, m.group(0)))
    def_lines = {no: name for name, (no, _) in defs.items()}
    for no, text in doc.prose():
        if no in def_lines:
            m = ISSUE_PATH_RE.search(text) if def_lines[no] not in used else None
        else:
            scan = without_links(text) if in_pitfalls(no) else text
            m = ISSUE_NUMBER_RE.search(without_targets(scan)) or ISSUE_PATH_RE.search(scan)
        if m:
            add(no, "R6", "本文に issue の番号がある: " + m.group(0))
        clean = without_targets(text)
        for rx in DATE_RES:
            m = rx.search(clean)
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
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = list(enumerate(fh.read().splitlines(), start=1))
        except OSError as exc:
            raise Unreadable("{}: 呼んでいるファイルを読めない（{}）".format(path, exc.__class__.__name__))
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
    for no, target in doc.link_targets():
        rel = local_target(target)
        if rel is None:
            continue
        rel = os.path.normpath(rel)
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
    try:
        with open(path, encoding="utf-8-sig") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Unreadable("{}: 読めない（{}）".format(path, exc.__class__.__name__))


def collect(paths: List[str]) -> Tuple[List[Tuple[str, List[str]]], List[str]]:
    """渡されたパスを、(置き場, 手順書の並び) と単独の手順書に分ける。"""
    folders: List[Tuple[str, List[str]]] = []
    singles: List[str] = []
    for p in paths:
        if os.path.isdir(p):
            try:
                entries = os.listdir(p)
            except OSError as exc:
                raise Unreadable("{}: 置き場を読めない（{}）".format(p, exc.__class__.__name__))
            names = sorted(
                n for n in entries if n.endswith(".md") and n != "README.md" and os.path.isfile(os.path.join(p, n))
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
        for path in [rb for _, rbs in folders for rb in rbs] + singles:
            findings.extend(check_runbook(Doc(path, read_text(path)), args.root, scripts))
        for folder, runbooks in folders:
            findings.extend(check_index(folder, runbooks))
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

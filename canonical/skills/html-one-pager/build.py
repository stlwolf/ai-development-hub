#!/usr/bin/env python3
"""人に見せて読んでもらう・答えてもらうページを、データ（JSON）から作る。

使い方は同じフォルダの SKILL.md にある。前提は Python 3.9 以上で、標準ライブラリだけを使う。
このファイルは自分の置き場所から型・CSS・JS・用語集を読み、走らせたときの作業ディレクトリには頼らない。

終了コード:
  0  成功
  1  データに誤りがある（誤りを1件1行で標準エラーに出し、HTML は書かない）
  2  データの中身より前の失敗（ファイルが読めない・JSON として読めない・用語集が壊れている・使い方の誤り）
"""

import argparse
import html
import html.parser
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GLOSSARY = os.path.join(HERE, "glossary.md")

FORMAT_VERSION = 1
# ページの種別。種別は既存の部品の組み合わせの名前で、要る部品・置いてよい補足・並びを決める（SKILL.md の種別の表）。
# 型の data-purpose の属性には、種別から導いた値を出す（どこからも読まれていないが、出力を変えないために残す）。
PAGE_KINDS = ("confirm", "approve", "pick", "map", "bundle", "review", "board")
KIND_PURPOSE = {"confirm": "decide", "approve": "decide", "pick": "decide", "map": "grasp",
                "bundle": "decide", "review": "review", "board": "decide"}
# 表に番号の列（型 no）を置ける種別。承認と束でも、選び方のカードが名指した表（選ぶ表）には置ける。
ROW_NUMBER_KINDS = ("pick", "map", "board")
# 選び方（select）を置ける種別。一覧から選ぶページのほかは、select.tables で選ぶ表を名指す。
SELECT_KINDS = ("pick", "approve", "bundle", "board")
# --body の本文を置ける種別。本文は型の上でいつも部品の上に出るので、部品の上にあっても読む順を壊さない種別だけにする。
BODY_KINDS = ("approve", "map", "bundle", "review")
# ページの中の切り替え（タブ）を置ける種別。タブの key は URL の # の名前とパネルの id になるので、英小文字と数字だけにする。
# 描く要素の id はどれも hp- で始まり - を含むので、- を含まない key から作るパネルの id は、それらと重ならない。
TAB_KINDS = ("map", "board", "approve", "bundle")
TAB_KEY_RE = re.compile(r"[a-z][a-z0-9]{0,19}\Z")
TAB_ROW_MAX = 6
# 本文のタブのパネル。class で見分け、ブラウザが暗黙に閉じない要素（section・div）だけを使わせる。
TAB_PANEL_CLASS = "hp-tabpanel"
TAB_PANEL_TAGS = ("section", "div")
# 本文の一番外に、パネルのほかに置ける要素（中身を出さないもの）。
TAB_BODY_TOP_TAGS = ("style", "script")
# 空の要素（/> で閉じてよい要素）。ほかの要素を /> で閉じると、ブラウザは閉じずに開いたままにする。
VOID_TAGS = ("area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr")
# 種別ごとのページの中の識別子: (カードの札の接頭辞の key, 番号の列の接頭辞の key, 書かなければ番号を振るか)。
# key は用語集の「識別子の接頭辞」の表の key で、語は用語集が持つ。ここに無い種別は識別子を定義しない。
# 判断ボード（board）は、決まったカードをその番号のまま「決まったこと」の表へ移すので、カードと行が同じ接頭辞を使い、
# 番号は必ず書かせる（位置で振ると、カードを移すたびに残りの番号がずれ、本文の参照が別の問いを指す）。
KIND_IDS = {"approve": ("prefix.question", None, True),
            "pick": (None, "prefix.candidate", True),
            "map": (None, "prefix.item", True),
            "board": ("prefix.question", "prefix.question", False)}
# 別のリポジトリの issue（owner/repo#N）。オーナーは英数字で始まり英数字と - が続く39文字まで、
# リポジトリは英数字・.・_・- の100文字まで。#N の桁は本文の変換（LINK_RE）と同じ 1〜7 桁にそろえる。
XREPO = r"([A-Za-z0-9][A-Za-z0-9-]{0,38})/([A-Za-z0-9._-]{1,100})#(\d{1,7})"  # 括弧は3つの組だけ（本文の変換では組を外して使う）
# 認識合わせのカードの札は、確かめる対象の issue の形（#N・owner/repo#N）だけを受け付ける。
ISSUE_TAG_RE = re.compile(r"(?:#\d{1,7}|" + XREPO + r")\Z")
# レビューのページの「依頼したレビュー」の項目（どれも必須の、空でない文字列）。表に出す順でもある。
REQUEST_FIELDS = ("target", "type", "via", "focus", "why")
# 一覧から選ぶページの、行ごとに選ぶ答え。行の答えの key は <選び方のカードの key>--<行の番号の数字> で、
# choice は選んだら PICK_CHOICE、外したら null（保存の形は判定カードと同じ {key, choice, note, at}）。
PICK_CHOICE = "pick"
PICK_KEY_SEP = "--"
# 前の版で使っていた項目。知らない項目として止め、理由を添える。
REPLACED_FIELDS = {"purpose": "purpose は kind に置き換えた。kind を書く"}
STATUSES = ("awaiting", "answered", "live")
EVIDENCE = ("verified", "sourced", "guess")
SEVERITIES = ("high", "mid", "low")
ADOPTIONS = ("adopted", "partial", "rejected")
KINDS = ("go", "fix", "warn", "no")
SECTION_TYPES = ("decisions", "bundle", "findings", "table")
ANSWER_SECTION_TYPES = ("decisions", "bundle")
COLUMN_TYPES = ("text", "ref", "no")

# カードと選択肢の key。db の doc id が許す文字より狭い、このスキルの決まり。
# match（先頭から）で使い、終わりは \Z で固定する（$ は末尾の改行の前でも合うので使わない）。
KEY_RE = re.compile(r"[a-z][a-z0-9_-]{0,63}\Z")
URL_RE = re.compile(r"https?://\S+\Z")

# 外部の課題管理の ID は <接頭辞>-<数字> の形に固定する。接頭辞は送り元の trackers に登録したものだけを使う。
TRACKER_PREFIX_RE = re.compile(r"[A-Z][A-Z0-9]{0,9}\Z")
TRACKER_ID_PLACEHOLDER = "{id}"
# 表の識別子の列が受け付ける形。#N の桁は本文の変換（LINK_RE）と同じ 1〜7 桁にそろえる。
REF_ISSUE_RE = re.compile(r"(?:PR )?#(\d{1,7})\Z")
REF_XREPO_RE = re.compile(XREPO + r"\Z")
REF_TRACKER_RE = re.compile(r"([A-Z][A-Z0-9]{0,9})-(\d+)\Z")

# 用語集に要る key と、それぞれの言葉が持つ差し込み。受け付ける値の集まりはここが正本で、
# 用語集が持つのは表に出す言葉だけである。
GLOSSARY_KEYS = {
    "evidence.verified": (),
    "evidence.sourced": (),
    "evidence.guess": (),
    "status.awaiting": ("n",),
    "status.answered": (),
    "status.live": (),
    "severity.high": (),
    "severity.mid": (),
    "severity.low": (),
    "adopted.adopted": (),
    "adopted.partial": (),
    "adopted.rejected": (),
    "recommend": (),
    "text.version": ("time",),
    "text.head_repo": (),
    "text.head_tmux": (),
    "text.head_issue": (),
    "text.head_branch": (),
    "text.head_version": (),
    "text.head_status": (),
    "text.why": (),
    "text.links": (),
    "text.points": (),
    "text.reason": (),
    "text.note_placeholder": (),
    "text.unanswered": (),
    "text.all_recommended": (),
    "text.answered_notice": (),
    "text.store_connecting": (),
    "text.store_saving": (),
    "text.store_saved": (),
    "text.store_failed": (),
    "text.store_unavailable": (),
    "text.reply_title": (),
    "text.reply_heading": ("title", "time"),
    "text.reply_note": ("note",),
    "text.copy": (),
    "text.copied": (),
    "text.copy_failed": (),
    "text.lane": ("lane",),
    "text.col_text": (),
    "text.col_severity": (),
    "text.col_adopted": (),
    "text.col_reason": (),
    "text.req_title": (),
    "text.req_target": (),
    "text.req_type": (),
    "text.req_via": (),
    "text.req_focus": (),
    "text.req_why": (),
    "text.select_upto": ("max",),
    "text.select_between": ("min", "max"),
    "text.select_exact": ("max",),
    "text.select_chosen": ("n", "rows"),
    "text.select_none": (),
    "text.select_over": ("n",),
    "text.pick": (),
    "text.reply_rows": ("rows",),
    "text.folded_answer": ("label",),
    "text.unfold": (),
    "text.fold": (),
}
GLOSSARY_SECTION = "## 札の言葉と固定の文"
# 用語集の「識別子の接頭辞」の表に要る key。語は札と番号の列の値の形を決める（受け付ける値も変わる）。
# 「札の言葉と固定の文」の表とは分けて持つ。そちらの言葉は答える部品のあるページに丸ごと埋め込まれるので、
# ここの語を混ぜると既存のページの出力が変わり、JS が使わない語をページに持ち込むためである。
WORD_KEYS = ("prefix.question", "prefix.candidate", "prefix.item", "tag.approval")
WORDS_SECTION = "## 識別子の接頭辞"
# 用語集の「問いのカードの塊の題」の表に要る key。問いのカードの1つ目・2つ目・（置くなら）3つ目の塊の題の語（E-Q3）。
# 札の言葉と同じ理由で、「札の言葉と固定の文」の表とは分けて持つ（ページの埋め込みデータに入れない）。
BLOCK_KEYS = ("block.ask", "block.recommend", "block.alternatives")
BLOCKS_SECTION = "## 問いのカードの塊の題"
GLOSSARY_ROW_RE = re.compile(r"^\|\s*`([a-z][a-z0-9_.]*)`\s*\|\s*(.*?)\s*\|\s*$")
PLACEHOLDER_RE = re.compile(r"\{([a-z_]+)\}")


class LoadError(Exception):
    """データの中身より前の失敗。終了コード 2 にする。"""


# ---------------------------------------------------------------- 読み込み


def read_text(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (OSError, UnicodeDecodeError) as e:
        raise LoadError("%s（%s）を読めない: %s" % (what, path, e))


def _reject_duplicates(pairs):
    obj = {}
    for k, v in pairs:
        if k in obj:
            raise LoadError('同じ項目名 "%s" が1つのオブジェクトに2回ある（後ろの値で前の値が黙って消えるので弾く）' % k)
        obj[k] = v
    return obj


def _reject_constant(name):
    raise LoadError("JSON に %s がある（数として扱えないので弾く）" % name)


def parse_json(text, what):
    try:
        return json.loads(text, object_pairs_hook=_reject_duplicates, parse_constant=_reject_constant)
    except LoadError:
        raise
    except ValueError as e:
        raise LoadError("%s を JSON として読めない: %s" % (what, e))


def load_data(path):
    return parse_json(read_text(path, "データ"), "データ（%s）" % path)


def _glossary_table(path, section):
    """用語集の見出し section の下の表を読み、(key から言葉への辞書, 見つけた問題の並び) を返す。"""
    lines = read_text(path, "用語集").splitlines()
    try:
        start = lines.index(section)
    except ValueError:
        raise LoadError("用語集（%s）に見出し「%s」が無い" % (path, section[3:]))
    table = {}
    problems = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        m = GLOSSARY_ROW_RE.match(line)
        if not m:
            continue
        key, word = m.group(1), m.group(2)
        if key in table:
            problems.append('key "%s" が2回ある' % key)
            continue
        table[key] = word
    return table, problems


def load_glossary(path):
    """用語集の「札の言葉と固定の文」の表を読み、key から言葉への辞書を返す。"""
    labels, problems = _glossary_table(path, GLOSSARY_SECTION)
    for key in labels:
        if key not in GLOSSARY_KEYS:
            problems.append('知らない key "%s" がある' % key)
    for key, want in GLOSSARY_KEYS.items():
        if key not in labels:
            problems.append('key "%s" が無い' % key)
            continue
        word = labels[key]
        if not word.strip():
            problems.append('key "%s" の言葉が空' % key)
        got = PLACEHOLDER_RE.findall(word)
        if sorted(got) != sorted(want):
            problems.append('key "%s" の差し込みが %s であるべき所が %s である'
                            % (key, _braces(want), _braces(got)))
        rest = PLACEHOLDER_RE.sub("", word)
        if "{" in rest or "}" in rest:
            problems.append('key "%s" に差し込みの形でない波括弧がある' % key)
    if problems:
        raise LoadError("用語集（%s）が壊れている: %s" % (path, "; ".join(problems)))
    return labels


def _braces(names):
    return "（なし）" if not names else "・".join("{%s}" % n for n in names)


def load_words(path):
    """検証が使う語を読み、key から語への辞書を返す。「識別子の接頭辞」の表の語と、
    「問いのカードの塊の題」の表の語と、推奨の札の言葉（key recommend）を合わせて持つ。
    接頭辞の語は文字（英字・漢字・かな）だけからなり（末尾にだけ「:」を1つ置ける・ID:1 の形）、互いに重ならず、どれもほかの語の頭に当たらない。
    ほかの記号と数字を許さないので、ページの中の識別子（Q2・ID:1）は外部の課題管理の ID（OPS-41）・#N・PR #N と同じ文字列にならない。"""
    words, problems = _glossary_table(path, WORDS_SECTION)
    for key in words:
        if key not in WORD_KEYS:
            problems.append('知らない key "%s" がある' % key)
    for key in WORD_KEYS:
        if key not in words:
            problems.append('key "%s" が無い' % key)
        elif not words[key].rstrip(":") or not words[key][:-1 if words[key].endswith(":") else None].isalpha():
            problems.append('key "%s" の語 "%s" が文字だけからなっていない（数字・空白・記号を含めない。末尾の「:」だけは1つ置ける）' % (key, words[key]))
    found = [(k, words[k]) for k in WORD_KEYS if words.get(k)]
    for i, (ka, a) in enumerate(found):
        for kb, b in found[i + 1:]:
            if a.startswith(b) or b.startswith(a):
                problems.append('key "%s" の語 "%s" と key "%s" の語 "%s" が重なるか、片方がもう片方の頭に当たる' % (ka, a, kb, b))
    if problems:
        raise LoadError("用語集（%s）の識別子の接頭辞が壊れている: %s" % (path, "; ".join(problems)))
    words.update(_block_words(path))
    # 選択肢の名前の検査（E-Q2）は、推奨の札の言葉を使う。札の表そのものの検証は load_glossary が持つ。
    labels, _ = _glossary_table(path, GLOSSARY_SECTION)
    if not labels.get("recommend", "").strip():
        raise LoadError("用語集（%s）の「札の言葉と固定の文」に key \"recommend\" の言葉が無い" % path)
    words["recommend"] = labels["recommend"]
    return words


def _block_words(path):
    """用語集の「問いのカードの塊の題」の表を読む。語は空でなく、差し込みを持たず、互いに重ならない。"""
    blocks, problems = _glossary_table(path, BLOCKS_SECTION)
    for key in blocks:
        if key not in BLOCK_KEYS:
            problems.append('知らない key "%s" がある' % key)
    for key in BLOCK_KEYS:
        if key not in blocks:
            problems.append('key "%s" が無い' % key)
        elif not blocks[key].strip():
            problems.append('key "%s" の語が空' % key)
        elif "{" in blocks[key] or "}" in blocks[key]:
            problems.append('key "%s" の語に波括弧がある（差し込みを持たない）' % key)
    found = [blocks[k] for k in BLOCK_KEYS if blocks.get(k)]
    if len(set(found)) != len(found):
        problems.append("塊の題の語が重なる")
    if problems:
        raise LoadError("用語集（%s）の問いのカードの塊の題が壊れている: %s" % (path, "; ".join(problems)))
    return {k: blocks[k] for k in BLOCK_KEYS}


# ---------------------------------------------------------------- 検証


def type_name(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "真偽値"
    if isinstance(v, (int, float)):
        return "数"
    if isinstance(v, str):
        return "文字列"
    if isinstance(v, list):
        return "配列"
    if isinstance(v, dict):
        return "オブジェクト"
    return type(v).__name__


def is_int(v):
    # Python では True が 1 と等しく扱われるので、真偽値を先に除く。
    return isinstance(v, int) and not isinstance(v, bool)


def join(path, key):
    return key if path == "$" else "%s.%s" % (path, key)


# 括弧書き（全角の（…）と半角の (…)）。入れ子は内側から順に外す。対になっていない括弧は外さない。
_PAREN_RE = re.compile(r"（[^（）()]*）|\([^（）()]*\)")


def strip_parens(text):
    """文字列から括弧書きを除いた残りを返す（題の形と選択肢の名前の検査に使う）。"""
    prev = None
    while prev != text:
        prev = text
        text = _PAREN_RE.sub("", text)
    return text


def is_question(title):
    """題が問いの形か: 括弧書きと末尾の空白を除いて、「か」「？」「?」で終わる（E-Q1・表記の規則）。"""
    return strip_parens(title).rstrip().endswith(("か", "？", "?"))


class _BodyScan(html.parser.HTMLParser):
    """--body の本文から、タブのパネル（class hp-tabpanel の要素）と id を集め、パネルの判定がブラウザとずれる書き方を拾う。
    終わりの印は、同じ名前の開いた要素まで戻る形で読む（閉じ忘れた p のような正しい HTML を誤りにしない）。
    対応する開いた要素の無い終わりの印は、ブラウザと同じく無視する。属性が2回あるときは、ブラウザと同じく前の値を使う。"""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []     # 開いている要素の (名前, パネルか)
        self.panels = []    # 本文に書かれたパネルの (id か None, 要素の名前)。本文の並び
        self.ids = []       # 本文の要素の id（並び・重なりを含む）
        self.problems = []  # 誤りの文（タブのあるページでだけ使う）

    def _open(self, tag, attrs, closed):
        names = [k for k, _ in attrs]
        twice = sorted({k for k in names if names.count(k) > 1})
        if twice:
            # この要素はパネルか・id は何かが書き手の意図とずれうるので、ほかの判定には使わない（同じ原因の誤りを重ねない）
            self.problems.append("本文の要素 <%s> に同じ属性（%s）が2回ある（build.py とブラウザで、使う値が違う）" % (tag, "・".join(twice)))
            if tag not in VOID_TAGS:
                self.stack.append((tag, False))
            return
        a = {}
        for k, v in attrs:
            a.setdefault(k, v)
        if a.get("id") is not None:
            self.ids.append(a["id"])
        panel = TAB_PANEL_CLASS in (a.get("class") or "").split()
        if panel:
            label = '<%s id="%s">' % (tag, a.get("id") or "")
            if any(p for _, p in self.stack):
                self.problems.append("本文のパネル %s が、ほかのパネルの中にある（パネルを入れ子にしない）" % label)
            elif self.stack:
                self.problems.append("本文のパネル %s が、本文の一番外に無い（<%s> の中にある）" % (label, self.stack[-1][0]))
            if tag not in TAB_PANEL_TAGS:
                self.problems.append("本文のパネル %s は %s の要素にする（ほかの要素は、ブラウザが暗黙に閉じて中身がパネルの外に出うる）"
                                     % (label, "・".join(TAB_PANEL_TAGS)))
            self.panels.append((a.get("id"), tag))
        elif not self.stack and tag not in TAB_BODY_TOP_TAGS:
            self.problems.append("本文の一番外に、パネルでない要素 <%s> がある（タブのあるページでは、中身はパネルの中に書く）" % tag)
        if closed and tag not in VOID_TAGS:
            self.problems.append("本文の要素 <%s/> を /> で閉じている（空の要素でないので、ブラウザは閉じずに開いたままにする）" % tag)
        # ブラウザと同じく、空の要素でなければ /> で閉じても開いたままとして読む
        if tag not in VOID_TAGS:
            self.stack.append((tag, panel))

    def handle_starttag(self, tag, attrs):
        self._open(tag, attrs, False)

    def handle_startendtag(self, tag, attrs):
        self._open(tag, attrs, True)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        if not self.stack and data.strip():
            self.problems.append("本文の一番外に、パネルの外の文字（%s）がある（タブのあるページでは、中身はパネルの中に書く）"
                                 % json.dumps(data.strip()[:20], ensure_ascii=False))


def scan_body(body):
    """本文を読み、パネル・id・ずれる書き方を集めたもの（_BodyScan）を返す。"""
    s = _BodyScan()
    s.feed(body)
    s.close()
    return s


class Validator:
    """データの誤りを全部集める。1つの誤りから同じ原因の誤りを重ねて出さない。"""

    def __init__(self, has_body, words, body=None):
        # body は --body の本文の文字列（タブのパネルの検査に使う）。has_body だけを渡す呼び方も今のまま受け付ける。
        self.has_body = has_body or body is not None
        self.body = body
        self.words = words
        self.errors = []
        # タブを置いたページか（tabs があり、種別がタブを置ける）。束の部品の数の決まりが変わる。
        self.has_tabs = False
        self.card_paths = {}   # カードの key -> 最初に現れた場所
        self.card_options = {}  # カードの key -> 選択肢の key の並び
        # ページの送り元からリンクにできるもの（repo_url があるか・登録した接頭辞）。
        # 送り元に誤りがあれば None にし、表の識別子をリンクにできるかの判定（E-L1）を重ねて出さない。
        self.page_links = None
        # 束の group の表を見ているあいだは、その group の送り元からリンクにできるもの（描画と同じ送り元で見る）。
        self.in_group = False
        self.group_links = None
        # 表の部品の場所 -> 列の [(key, type)]。列に誤りがあれば None（種別の判定で番号の列を数えない）。
        self.tables = {}
        # 選び方（select）を書いたカード: [(カードの場所, カードの key か None, 形の誤りの無い select か None, 書いた select)]
        self.selects = []
        # 表の key -> 表の場所（ページの表と束の group の表。重なりは E-S3）
        self.table_keys = {}
        # 選び方のカードが名指した表（選ぶ表）の場所 -> 名指したカードの場所
        self.named = {}
        # 選び方のカードの場所 -> 選ぶ表の場所の並び（名指しに誤りがあれば None。表に頼る判定を省く）
        self.select_tables = {}
        # 一覧から選ぶ行: カードの key -> (選べる数の上限, 行の答えの key の並び)。回収した答えの上限の検査に使う。
        self.pick_limits = {}

    def add(self, code, path, msg):
        self.errors.append((code, path, msg))

    # 形の決まり --------------------------------------------------------

    def obj(self, path, val, required, optional=(), replaced=None):
        """オブジェクトかを見て、知らない項目と足りない項目を出す。型が違えば下を見ない。
        replaced は前の版で使っていた項目と、その理由の文。知らない項目として止め、理由を添える。"""
        if not isinstance(val, dict):
            self.add("E-F3", path, "オブジェクトであるべき所が%sである" % type_name(val))
            return False
        for k in val:
            if k not in required and k not in optional:
                if replaced and k in replaced:
                    self.add("E-F2", join(path, k), '知らない項目 "%s" がある（%s）' % (k, replaced[k]))
                else:
                    self.add("E-F2", join(path, k), '知らない項目 "%s" がある' % k)
        for k in required:
            if k not in val:
                self.add("E-F3", join(path, k), "必須の項目が無い")
        return True

    def array(self, path, val, empty_code, empty_msg):
        if not isinstance(val, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(val))
            return False
        if not val:
            self.add(empty_code, path, empty_msg)
            return False
        return True

    def text(self, path, val, code):
        """空でない文字列を求める。型が違えば E-F3、空（空白だけを含む）なら code。"""
        if not isinstance(val, str):
            self.add("E-F3", path, "文字列であるべき所が%sである" % type_name(val))
            return False
        if not val.strip():
            self.add(code, path, "空の文字列である（空白だけのものを含む）")
            return False
        return True

    def enum(self, path, val, allowed, code):
        if not isinstance(val, str):
            self.add("E-F3", path, "文字列であるべき所が%sである" % type_name(val))
            return False
        if val not in allowed:
            self.add(code, path, '"%s" は決まった値（%s）でない' % (val, ", ".join(allowed)))
            return False
        return True

    def url(self, path, val):
        if not isinstance(val, str):
            self.add("E-F3", path, "文字列であるべき所が%sである" % type_name(val))
            return
        if not URL_RE.match(val):
            self.add("E-H2", path, "http:// か https:// で始まる URL でない")

    # 部分ごとの決まり --------------------------------------------------

    def page(self, data):
        if not isinstance(data, dict):
            self.add("E-F3", "$", "ページのデータはオブジェクトであるべき所が%sである" % type_name(data))
            return
        fmt = data.get("format")
        if not (is_int(fmt) and fmt == FORMAT_VERSION):
            shown = "無い" if "format" not in data else json.dumps(fmt, ensure_ascii=False)
            self.add("E-F1", "format", "format は %d であるべき所が %s" % (FORMAT_VERSION, shown))
            return
        self.obj("$", data, ("format", "title", "kind", "status", "why", "source", "sections"),
                 ("links", "answers", "request", "tabs"), replaced=REPLACED_FIELDS)
        if "title" in data:
            self.text("title", data["title"], "E-H1")
        if "why" in data:
            self.text("why", data["why"], "E-H1")
        kind = None
        if "kind" in data and self.enum("kind", data["kind"], PAGE_KINDS, "E-H3"):
            kind = data["kind"]
        if "status" in data:
            self.enum("status", data["status"], STATUSES, "E-H3")
        # 依頼したレビューの情報は、レビューのページでは必須、ほかの種別では置けない。
        if "request" in data:
            if kind is not None and kind != "review":
                self.add("E-K2", "request", "request（依頼したレビュー）を置けるのはレビューのページだけである")
            else:
                self.request("request", data["request"])
        elif kind == "review":
            self.add("E-K1", "request", "レビューのページには、依頼したレビューの情報（request: %s）が要る" % "・".join(REQUEST_FIELDS))
        if "source" in data:
            before = len(self.errors)
            self.source("source", data["source"])
            if len(self.errors) == before:
                src = data["source"]
                self.page_links = ("repo_url" in src, {t["prefix"] for t in src.get("trackers", [])})
        if "links" in data:
            self.links("links", data["links"])
        # タブ。置けない種別では E-K2 だけを出し、中身は見ない（同じ原因の誤りを重ねない）。
        tab_keys = None  # 引けるタブの key -> tabs の中の位置（tabs が無い・配列でないときは None）
        tabs_checked = "tabs" not in data
        if "tabs" in data:
            if kind is not None and kind not in TAB_KINDS:
                self.add("E-K2", "tabs", "種別 %s のページにはタブ（tabs）を置かない（置けるのは %s）" % (kind, "・".join(TAB_KINDS)))
            else:
                tab_keys = self.tabs("tabs", data["tabs"])
                tabs_checked = tab_keys is not None
                self.has_tabs = tab_keys is not None
        has_answer_part = False
        # 部品を読めなかったとき（配列でない・知らない type）は、答える部品の有無を決められないので、
        # 同じ原因の誤りを重ねないよう「回答待ちなのに答える部品が無い」を出さない。
        sections_readable = False
        if "sections" in data:
            secs = data["sections"]
            if not isinstance(secs, list):
                self.add("E-F3", "sections", "配列であるべき所が%sである" % type_name(secs))
            else:
                sections_readable = True
                if not secs and not self.has_body:
                    self.add("E-S1", "sections", "部品が1つも無く、--body の本文も無い")
                for i, sec in enumerate(secs):
                    t = self.section("sections[%d]" % i, sec)
                    if t is None:
                        sections_readable = False
                    elif t in ANSWER_SECTION_TYPES:
                        has_answer_part = True
                # 選び方のカードが名指した表を先に解決する（種別の部品・識別子の判定が、選ぶ表かどうかを使う）。
                if kind is not None:
                    self.resolve_selects(kind, secs)
                # 種別の部品は、種別が決まった値で、部品がどれも読めたときだけ見る。
                # 部品も本文も無ければ E-S1 だけを出す（同じ原因の誤りを重ねない）。
                if kind is not None and sections_readable and (secs or self.has_body):
                    self.kind_parts(kind, secs)
                if kind is not None:
                    defined = self.identifiers(kind, secs)
                    if defined:
                        self.listed_numbers(kind, data, defined)
                    self.card_writing(kind, secs)
                if tabs_checked:
                    self.tab_contents(data.get("tabs"), tab_keys, secs)
        status = data.get("status")
        # 部品も本文も無いときは E-S1 だけを出し、状態の誤りを重ねない。
        no_parts = sections_readable and not data["sections"] and not self.has_body
        if status == "awaiting" and sections_readable and not has_answer_part and not no_parts:
            self.add("E-P2", "status", "awaiting（回答待ち）なのに、答える部品（decisions か bundle）が無い")
        if "answers" in data and status in STATUSES and status != "answered":
            self.add("E-P2", "answers", "answers があるのに、status が answered でない")
        if status == "answered" and "answers" not in data:
            self.add("E-P2", "answers", "status が answered なのに、回収した答え（answers）が無い")
        if "answers" in data:
            self.answers("answers", data["answers"])

    # 種別ごとの部品の決まり（E-K1〜E-K3）--------------------------------

    def kind_parts(self, kind, secs):
        """種別に要る部品・置いてよい補足・並びを見る。部品はどれもオブジェクトで、type は決まった値である。
        見るのは部品の数・種類・順と、種別が見る場所（カードの blocks・表の列の型）だけで、壊れた中身には触れない。"""
        types = [s["type"] for s in secs]
        paths = ["sections[%d]" % i for i in range(len(secs))]
        if self.has_body and kind not in BODY_KINDS:
            self.add("E-K2", "--body", "種別 %s のページには --body の本文を置かない" % kind)
        for i, t in enumerate(types):
            cols = self.tables.get(paths[i]) if t == "table" else None
            if not cols:
                continue
            nos = [j for j, (_, ct) in enumerate(cols) if ct == "no"]
            if nos and kind not in ROW_NUMBER_KINDS and paths[i] not in self.named:
                hint = "（選ぶ表なら、選び方の tables で名指す）" if kind in SELECT_KINDS else ""
                self.add("E-K2", "%s.columns[%d]" % (paths[i], nos[0]), "種別 %s の表には番号の列（type no）を置かない%s" % (kind, hint))
            elif len(nos) > 1:
                self.add("E-K2", "%s.columns[%d]" % (paths[i], nos[1]), "番号の列（type no）は1つの表に1列までにする")
        getattr(self, "kind_" + kind)(types, paths, secs)

    def select_runs(self, types, paths, secs, dec):
        """承認と判断ボード: 判定カードの節の直後に、その節の選び方のカードが名指した表を、カードの順・tables の順で続けて置く（E-K3）。
        名指しに誤りのあるカードの表は並びを見ない（E-C7 だけ）。"""
        for i in dec:
            cards = secs[i].get("cards") if isinstance(secs[i].get("cards"), list) else []
            cps = ["%s.cards[%d]" % (paths[i], j) for j in range(len(cards))]
            # 名指しに誤りのあるカードがある節は、どの表がどのカードのものかが決まらないので、並びを見ない
            if any(cp in self.select_tables and self.select_tables[cp] is None for cp in cps):
                continue
            expected = []
            for cp in cps:
                expected.extend(self.select_tables.get(cp) or [])
            got = paths[i + 1:i + 1 + len(expected)]
            for want, have in zip(expected, got + [None] * (len(expected) - len(got))):
                if want != have:
                    self.add("E-K3", want, "選ぶ表は、選び方のカードのある判定カードの節（%s）の直後に、カードの順・tables の順で続けて置く" % paths[i])
                    break

    def unnamed_tables_after_cards(self, types, paths, allowed, dec, msg):
        """選ぶ表でない表は、最後の判定カードの節のあとに置く（E-K3）。"""
        for i in allowed:
            if types[i] == "table" and paths[i] not in self.named and dec and i < dec[-1]:
                self.add("E-K3", paths[i], msg)

    def kind_allowed(self, kind, types, paths, allowed):
        """置けない部品を止め、置ける部品の位置の並びを返す（並びの判定は置ける部品だけで行い、誤りを重ねない）。"""
        for i, t in enumerate(types):
            if t not in allowed:
                self.add("E-K2", paths[i], "種別 %s のページには部品 %s を置かない（置けるのは %s）"
                         % (kind, t, "・".join(allowed)))
        return [i for i, t in enumerate(types) if t in allowed]

    def only_one(self, positions, paths, what):
        for i in positions[1:]:
            self.add("E-K2", paths[i], "%sは1つにする" % what)

    def has_number_table(self, positions, paths):
        """表の少なくとも1つが番号の列を持つか。列の読めない表があれば判定しない（None を返す）。"""
        found = False
        for i in positions:
            cols = self.tables.get(paths[i])
            if cols is None:
                return None
            found = found or any(ct == "no" for _, ct in cols)
        return found

    def kind_confirm(self, types, paths, secs):
        dec = self.kind_allowed("confirm", types, paths, ("decisions",))
        if not dec:
            self.add("E-K1", "sections", "認識合わせのページには判定カードの節（decisions）が1つ要る")
            return
        self.only_one(dec, paths, "判定カードの節")
        cards = secs[dec[0]].get("cards")
        if isinstance(cards, list):
            for j, c in enumerate(cards):
                if isinstance(c, dict) and "blocks" not in c:
                    self.add("E-K1", "%s.cards[%d]" % (paths[dec[0]], j),
                             "認識合わせのカードは塊（blocks）を持つ。平らな要点で足りる確かめは、承認（approve）の問いとして書く")

    def kind_approve(self, types, paths, secs):
        allowed = self.kind_allowed("approve", types, paths, ("decisions", "table"))
        dec = [i for i in allowed if types[i] == "decisions"]
        if not dec:
            self.add("E-K1", "sections", "承認のページには判定カードの節（decisions）が1つ以上要る")
            return
        self.unnamed_tables_after_cards(types, paths, allowed, dec, "表は判定カードの節のあとに置く")
        self.select_runs(types, paths, secs, dec)

    def kind_pick(self, types, paths, secs):
        allowed = self.kind_allowed("pick", types, paths, ("decisions", "table"))
        dec = [i for i in allowed if types[i] == "decisions"]
        tab = [i for i in allowed if types[i] == "table"]
        if not dec:
            self.add("E-K1", "sections", "一覧から選ぶページには、選び方のカードを1枚置いた判定カードの節（decisions）が1つ要る")
        else:
            if dec[0] != allowed[0]:
                self.add("E-K3", paths[dec[0]], "選び方のカードの節は部品の先頭（表の上）に置く")
            self.only_one(dec, paths, "判定カードの節")
            cards = secs[dec[0]].get("cards")
            if isinstance(cards, list) and len(cards) > 1:
                self.add("E-K2", "%s.cards[1]" % paths[dec[0]], "選び方のカードは1枚にする")
        if not tab:
            self.add("E-K1", "sections", "一覧から選ぶページには表（table）が1つ以上要る")
        elif self.has_number_table(tab, paths) is False:
            self.add("E-K1", "sections", "一覧から選ぶページには、番号の列（type no）を持つ表が1つ以上要る")

    def kind_map(self, types, paths, secs):
        self.kind_allowed("map", types, paths, ("table",))

    def kind_bundle(self, types, paths, secs):
        b = self.kind_allowed("bundle", types, paths, ("bundle",))
        if not b:
            self.add("E-K1", "sections", "束のページには判断待ちの束の部品（bundle）が1つ要る")
        if self.has_tabs:
            # タブで分けた束のページは、束の部品をタブごとに1つまで置ける（タブの単位を部品にそろえる）。
            # tab の無い部品・定義に無い tab は E-N3 で止めるので、ここでは文字列の tab だけを数える。
            seen = set()
            for i in b:
                t = secs[i].get("tab")
                if not isinstance(t, str):
                    continue
                if t in seen:
                    self.add("E-K2", paths[i], "タブ %s に判断待ちの束の部品が2つある（タブごとに1つまでにする）" % t)
                seen.add(t)
        else:
            self.only_one(b, paths, "判断待ちの束の部品")
        # group の表は選ぶ表だけを置け、group の中の選び方のカードの順・tables の順に並べる。key の無い表は E-F3 だけを出す
        for i in b:
            groups = secs[i].get("groups") if isinstance(secs[i].get("groups"), list) else []
            for g, grp in enumerate(groups):
                if not isinstance(grp, dict) or not isinstance(grp.get("tables"), list):
                    continue
                gp = "%s.groups[%d]" % (paths[i], g)
                tables = ["%s.tables[%d]" % (gp, t) for t, tb in enumerate(grp["tables"]) if isinstance(tb, dict) and "key" in tb]
                cards = grp.get("cards") if isinstance(grp.get("cards"), list) else []
                for t in tables:
                    # カードが無い group（E-S1）では、表を名指せるカードが無いので、名指されていないことを重ねて出さない
                    if t not in self.named and cards:
                        self.add("E-K2", t, "束の group には、同じ group の選び方のカードが tables で名指した表（選ぶ表）だけを置ける")
                    cols = self.tables.get(t) or []
                    nos = [j for j, (_, ct) in enumerate(cols) if ct == "no"]
                    if len(nos) > 1:
                        self.add("E-K2", "%s.columns[%d]" % (t, nos[1]), "番号の列（type no）は1つの表に1列までにする")
                cps = ["%s.cards[%d]" % (gp, j) for j in range(len(cards))]
                if any(cp in self.select_tables and self.select_tables[cp] is None for cp in cps):
                    continue
                expected = []
                for cp in cps:
                    expected.extend(self.select_tables.get(cp) or [])
                got = [t for t in tables if t in self.named]
                for want, have in zip(expected, got + [None] * (len(expected) - len(got))):
                    if want != have:
                        self.add("E-K3", want, "group の選ぶ表は、group の中の選び方のカードの順・tables の順に並べる")
                        break

    def kind_review(self, types, paths, secs):
        allowed = self.kind_allowed("review", types, paths, ("findings", "table", "decisions"))
        f = [i for i in allowed if types[i] == "findings"]
        if not f:
            self.add("E-K1", "sections", "レビューのページには指摘の一覧（findings）が1つ以上要る")
            return
        for i in allowed:
            if types[i] != "findings" and i < f[-1]:
                self.add("E-K3", paths[i], "指摘の一覧をすべて先に置き、表と判定カードはそのあとに置く")

    # ページの中の識別子（E-I1・E-I2 と、承認のカードの置き場所）-----------

    def identifiers(self, kind, secs):
        """札と番号の列の値が種別の形か（E-I1）、ページの中で重ならないか（E-I2）を見る。
        札は空でない文字列のものだけを見る（空なら E-C5・型が違えば E-F3 だけを出す）。
        番号の列は、列の定義に誤りの無い表の、文字列の値だけを見る。"""
        cards = []
        for i, sec in enumerate(secs):
            if isinstance(sec, dict) and sec.get("type") == "decisions" and isinstance(sec.get("cards"), list):
                cards.extend(("sections[%d].cards[%d]" % (i, j), c) for j, c in enumerate(sec["cards"]) if isinstance(c, dict))
        if kind == "confirm":
            for path, c in cards:
                t = c.get("tag")
                if isinstance(t, str) and t.strip() and not ISSUE_TAG_RE.match(t):
                    self.add("E-I1", join(path, "tag"), '認識合わせのカードの札 "%s" が issue の形（#N・owner/repo#N）でない' % t)
        card_key, row_key, auto = KIND_IDS.get(kind, (None, None, False))
        defined = {}  # 識別子 -> 定義した場所（振る番号を含む）
        if card_key:
            approval = self.words["tag.approval"] if kind == "approve" else None
            if approval:
                self.approval_card(cards, approval)
            items = []
            for path, c in cards:
                t = c.get("tag")
                if approval and t == approval:
                    continue
                if "tag" not in c:
                    items.append((join(path, "tag"), None))
                elif isinstance(t, str) and t.strip():
                    items.append((join(path, "tag"), t))
            self.numbered(items, self.words[card_key], auto, "問いのカードの札", defined)
        # 番号の列の値。種別と、選ぶ表かどうかで接頭辞と振り方が決まる（一覧から選ぶページと見取り図は今のとおり、
        # 承認・束・判断ボードの選ぶ表は候補で必ず書く、判断ボードの選ぶ表でない表は Q で必ず書く）。
        cand = self.words["prefix.candidate"]
        groups = []  # (表の場所の並び, 接頭辞, 振るか)
        number_tables = [p for p, _ in self.all_tables(secs) if any(ct == "no" for _, ct in (self.tables.get(p) or []))]
        if row_key and kind in ("pick", "map"):
            groups.append(([p for p in number_tables if "groups[" not in p], self.words[row_key], auto))
        elif kind == "board":
            groups.append(([p for p in number_tables if p not in self.named], self.words[row_key], False))
            groups.append(([p for p in number_tables if p in self.named], cand, False))
        elif kind in ("approve", "bundle"):
            groups.append(([p for p in number_tables if p in self.named], cand, False))
        secs_by_path = dict(self.all_tables(secs))
        for tables, prefix, numbering in groups:
            items = []
            for path in tables:
                sec = secs_by_path[path]
                no = [k for k, ct in self.tables[path] if ct == "no"]
                if not isinstance(sec.get("rows"), list):
                    continue
                for r, row in enumerate(sec["rows"]):
                    if not isinstance(row, dict):
                        continue
                    v = row.get(no[0], "")
                    if isinstance(v, str):
                        items.append(("%s.rows[%d].%s" % (path, r, no[0]), v or None))
            self.numbered(items, prefix, numbering, "番号の列の値", defined)
        self.select_rows(defined)
        return defined

    def all_tables(self, secs):
        """ページの表と束の group の表を、[(場所, 表)] で返す。形の崩れた所は飛ばす。"""
        out = []
        for i, sec in enumerate(secs):
            if not isinstance(sec, dict):
                continue
            if sec.get("type") == "table":
                out.append(("sections[%d]" % i, sec))
            elif sec.get("type") == "bundle" and isinstance(sec.get("groups"), list):
                for g, grp in enumerate(sec["groups"]):
                    if isinstance(grp, dict) and isinstance(grp.get("tables"), list):
                        out.extend(("sections[%d].groups[%d].tables[%d]" % (i, g, t), tb)
                                   for t, tb in enumerate(grp["tables"]) if isinstance(tb, dict))
        return out

    def resolve_selects(self, kind, secs):
        """選び方（select）を置ける種別かを見て（E-K2）、tables の名指しを表に解決する（E-C7）。
        一覧から選ぶページで tables を書かなければ、ページの番号の列のある表をすべて選ぶ表にする（今の書き方）。
        名指しに誤りのあるカードは、選ぶ表を None にし、表に頼る判定（推奨の行・選べる行の数・行の答えの key）を省く。"""
        page_number_tables = [p for p, _ in self.all_tables(secs)
                              if "groups[" not in p and any(ct == "no" for _, ct in (self.tables.get(p) or []))]
        for path, key, sel, raw in self.selects:
            if kind not in SELECT_KINDS:
                self.add("E-K2", join(path, "select"), "選び方（select）を置けるのは、一覧から選ぶページ・承認・束・判断ボードのカードだけである")
                continue
            if not isinstance(raw, dict):
                continue
            if "tables" not in raw:
                if kind == "pick":
                    self.select_tables[path] = list(page_number_tables)
                    for t in page_number_tables:
                        self.named.setdefault(t, path)
                else:
                    self.add("E-C7", join(path, "select"), "種別 %s の選び方には、選ぶ表を tables で名指す" % kind)
                    self.select_tables[path] = None
                continue
            names = raw["tables"] if isinstance(raw["tables"], list) else []
            # 形の誤り（空・重なり・文字列でない）は E-F3・E-C7 で出している。名指しの解決は読める名前でだけ続け、
            # 名指された表を「名指されていない表」として重ねて止めないようにする。表に頼る判定は省く（broken）。
            resolved, broken = [], not self.select_tables_ok(raw)
            group = re.match(r"sections\[\d+\]\.groups\[\d+\]", path)
            seen = set()
            for i, name in enumerate(names):
                if not isinstance(name, str) or name in seen:
                    continue
                seen.add(name)
                tp = "%s.select.tables[%d]" % (path, i)
                t = self.table_keys.get(name)
                if t is None:
                    self.add("E-C7", tp, '名指した表 "%s" がページに無い' % name)
                    broken = True
                    continue
                if kind == "bundle" and not (group and t.startswith(group.group(0) + ".tables[")):
                    if "groups[" in t:
                        self.add("E-C7", tp, '表 "%s" は別の group の表である（同じ group の表だけを名指す）' % name)
                    broken = True  # 束のページの部品の表は E-K2 で止めている
                    continue
                if t in self.named:
                    self.add("E-C7", tp, '表 "%s" は %s がすでに名指している（1つの表を名指せるのは1枚のカードだけ）' % (name, self.named[t]))
                    broken = True
                    continue
                self.named[t] = path
                cols = self.tables.get(t)
                if cols is None:
                    broken = True  # 列の誤りは E-S3 で出している
                    continue
                if not any(ct == "no" for _, ct in cols):
                    self.add("E-C7", tp, '名指した表 "%s" に番号の列（type no）が無い' % name)
                    broken = True
                    continue
                resolved.append(t)
            self.select_tables[path] = None if broken else resolved

    def select_rows(self, defined):
        """選び方のカードごとに、選ぶ表の行の番号から、推奨の行（E-I1）と選べる行の数（E-C6）を見て、
        行の答えの key（<カードの key>--<番号の数字>）を回収した答え（answers）の検査に登録する。
        行の答えの key がほかのカードの key と重なれば止める（E-C1・同じ保存先になるため）。
        選ぶ表が決まらないか、その表の番号を読めない（形・重なり・型の誤り）か、行が無いときは見ない（同じ原因の誤りを重ねない）。
        行の答えの key の重なりは選ぶ数に頼らないので、選ぶ数（select の数）に誤りがあっても見る（隠さない）。"""
        cand = self.words["prefix.candidate"]
        for path, key, sel, _ in self.selects:
            tables = self.select_tables.get(path)
            if key is None or not tables:
                continue
            if any(self.number_unreadable(t, code, p) for t in tables for code, p, _ in self.errors):
                continue
            rows = [ident for ident, p in defined.items()
                    if ident.startswith(cand) and ident[len(cand):].isdigit() and any(p.startswith(t + ".rows[") for t in tables)]
            if not rows:
                continue
            row_keys = [key + PICK_KEY_SEP + ident[len(cand):] for ident in rows]
            for rk in row_keys:
                if rk in self.card_paths:
                    self.add("E-C1", join(self.card_paths[rk], "key"),
                             'key "%s" が、選び方のカード %s の行の答えの key と重なる（同じ保存先になる）' % (rk, path))
                self.card_options[rk] = [PICK_CHOICE]
            if sel is None:
                continue
            for i, r in enumerate(sel.get("recommend", [])):
                if r not in rows:
                    self.add("E-I1", "%s.select.recommend[%d]" % (path, i), '推奨の行 "%s" が選ぶ表の番号の列で定義されていない' % r)
            if sel.get("min", 0) > len(rows):
                self.add("E-C6", join(path, "select"), "min（%d）が選べる行の数（%d）を超える" % (sel["min"], len(rows)))
            self.pick_limits[key] = (sel["max"], row_keys)

    def number_unreadable(self, table, code, path):
        """誤り (code, path) が、選ぶ表 table の番号を読めなくする誤りか（番号の形・重なり・型の誤りと、行がオブジェクトでない）。"""
        if not path.startswith(table + ".rows["):
            return False
        cols = self.tables.get(table) or []
        no = [k for k, ct in cols if ct == "no"]
        rest = path[len(table):]
        if code in ("E-I1", "E-I2"):
            return True
        return code == "E-F3" and (re.fullmatch(r"\.rows\[\d+\]", rest) is not None
                                   or bool(no) and re.fullmatch(r"\.rows\[\d+\]\.%s" % re.escape(no[0]), rest) is not None)

    def listed_numbers(self, kind, data, defined):
        """1つの接頭辞のあとに番号を3つ以上並べた書き方（候補43・41・49）を止める（E-I3）。
        並んだ番号に同じ接頭辞を付けた識別子が、すべてページで定義されているときだけ止める。
        番号が2つだけの形（Q2・3件）は普通の文と見分けられないので止めない。"""
        words = (self.words[k] for k in ("prefix.question", "prefix.candidate", "prefix.item"))
        prefixes = sorted({w for w in words if any(d.startswith(w) and d[len(w):].isdigit() for d in defined)})
        listed = re.compile(r"(?<![A-Za-z0-9_./#-])(%s)([1-9][0-9]*)((?:\s*[%s]\s*[0-9]+){2,})(?![0-9])"
                            % ("|".join(re.escape(x) for x in prefixes), LIST_SEPARATORS))
        for path, text in display_texts(data):
            # コードと URL の中は、描くときと同じ範囲で除く（URL は句点などの区切りで終わる）。
            text = _SKIP_FOR_LISTS_RE.sub(" ", text)
            for m in listed.finditer(text):
                nums = [m.group(2)] + re.findall(r"[0-9]+", m.group(3))
                if all(m.group(1) + n in defined for n in nums):
                    self.add("E-I3", path, '"%s" のように番号を並べている。%s%s のように番号ごとに接頭辞を書く'
                             % (m.group(0), m.group(1), nums[1]))
                    break

    def approval_card(self, cards, approval):
        """承認のページの全体の承認のカード（札が承認の語）は、ページの最後のカードに1枚だけ置く。"""
        found = [(p, c) for p, c in cards if c.get("tag") == approval]
        for p, _ in found[1:]:
            self.add("E-K2", p, "全体の承認のカード（札 %s）は1枚にする" % approval)
        if len(found) == 1 and found[0][1] is not cards[-1][1]:
            self.add("E-K3", found[0][0], "全体の承認のカード（札 %s）はページの最後のカードにする" % approval)

    def numbered(self, items, prefix, auto, what, defined):
        """items は [(値の場所, 書いた値か、省いたときの None)]。形（E-I1）と重なり（E-I2）を見る。
        書かなければ番号を振る種別では、書いたものと書かないものを混ぜると、振る番号が書いた番号と重なりうるので止める。"""
        pat = re.compile(re.escape(prefix) + r"[1-9][0-9]*\Z")
        written = [x for x in items if x[1] is not None]
        omitted = [x for x in items if x[1] is None]
        for path, v in written:
            if not pat.match(v):
                self.add("E-I1", path, '%s "%s" が %s<数字> の形でない' % (what, v, prefix))
        # 混ざっているかは、形の合った値だけで見る（形の誤りと同じ原因の誤りを重ねない）。
        good = [x for x in written if pat.match(x[1])]
        if omitted and not auto:
            for path, _ in omitted:
                self.add("E-I1", path, "%sを書く（%s<数字>。番号を動かさないため、自動では振らない）" % (what, prefix))
        elif omitted and good:
            first_written = items.index(good[0]) < items.index(omitted[0])
            self.add("E-I1", omitted[0][0] if first_written else good[0][0],
                     "%sを書いたものと書かないものが混ざっている（書くなら全部に書く）" % what)
        elif omitted and auto and not written:
            # 全部を書かなければ、順に振る番号を定義として数える（本文の参照をアンカーにする判定と同じ）。
            for n, (path, _) in enumerate(items, 1):
                defined["%s%d" % (prefix, n)] = path
        for path, v in good:
            if v in defined:
                self.add("E-I2", path, '識別子 "%s" が %s と重なる' % (v, defined[v]))
            else:
                defined[v] = path

    # 問いのカードの書き方（E-Q1・E-Q3。E-Q2 は種別に頼らないので選択肢の検査で見る）---------

    def card_writing(self, kind, secs):
        """題が問いの形か（E-Q1）と、問いのカードの塊（E-Q3）を見る。どちらも表記の規則で、中身の質は見ない。
        認識合わせのカードは見ない。全体の承認のカード（承認のページの札が承認の語のカード）は題だけを見る。
        抑止は親の値に頼る判定だけにする: 題が空でない文字列のときだけ題を、blocks が空でない配列のときだけ塊の題を、
        塊の題は位置ごとに、その位置の塊がオブジェクトで題が文字列のときだけ比べる。"""
        if kind == "confirm":
            return
        approval = self.words["tag.approval"] if kind == "approve" else None
        ask, rec, alt = (self.words[k] for k in BLOCK_KEYS)
        for path, c in self.all_cards(secs):
            t = c.get("title")
            if isinstance(t, str) and t.strip() and not is_question(t):
                self.add("E-Q1", join(path, "title"), '題 "%s" が問いの形でない（括弧書きを除いて「か」「？」で終わる形にする）' % t)
            if approval and c.get("tag") == approval:
                continue
            if "points" in c:
                self.add("E-Q3", join(path, "points"), "問いのカードには平らな要点（points）を置かない。中身は塊（blocks）に書く")
            if "blocks" not in c:
                self.add("E-Q3", path, "問いのカードは塊（blocks）を持つ。1つ目の題は「%s」、2つ目は「%s」にする" % (ask, rec))
                continue
            blocks = c["blocks"]
            if not isinstance(blocks, list) or not blocks:
                continue

            def title_at(i):
                b = blocks[i] if i < len(blocks) else None
                return b["title"] if isinstance(b, dict) and isinstance(b.get("title"), str) else None

            bp = join(path, "blocks")
            for i, want in ((0, ask), (1, rec)):
                if i >= len(blocks):
                    self.add("E-Q3", bp, "塊が %d つしかない。%d つ目の塊の題を「%s」にする" % (len(blocks), i + 1, want))
                elif title_at(i) is not None and title_at(i) != want:
                    self.add("E-Q3", "%s[%d].title" % (bp, i), '%d つ目の塊の題 "%s" が「%s」でない' % (i + 1, title_at(i), want))
            for i in range(3, len(blocks)):
                if title_at(i) == alt:
                    self.add("E-Q3", "%s[%d].title" % (bp, i), "「%s」の塊は3つ目に置く" % alt)
                    break

    def all_cards(self, secs):
        """判定カードの節と束の group のカードを、[(場所, カード)] で返す。形の崩れた所は飛ばす。"""
        out = []
        for i, sec in enumerate(secs):
            if not isinstance(sec, dict):
                continue
            sp = "sections[%d]" % i
            if sec.get("type") == "decisions" and isinstance(sec.get("cards"), list):
                out.extend(("%s.cards[%d]" % (sp, j), c) for j, c in enumerate(sec["cards"]) if isinstance(c, dict))
            elif sec.get("type") == "bundle" and isinstance(sec.get("groups"), list):
                for g, grp in enumerate(sec["groups"]):
                    if isinstance(grp, dict) and isinstance(grp.get("cards"), list):
                        out.extend(("%s.groups[%d].cards[%d]" % (sp, g, j), c) for j, c in enumerate(grp["cards"]) if isinstance(c, dict))
        return out

    def kind_board(self, types, paths, secs):
        """判断ボード: 判定カードの節（0以上）を先に、表（0以上）をあとに置く。判定カードが無いページ
        （開いた問いが0枚・決まったカードをすべて表へ移したページ）は、表が1つ以上あればよい。"""
        allowed = self.kind_allowed("board", types, paths, ("decisions", "table"))
        dec = [i for i in allowed if types[i] == "decisions"]
        tab = [i for i in allowed if types[i] == "table"]
        self.unnamed_tables_after_cards(types, paths, allowed, dec, "表は判定カードの節のあとに置く（いま決めることを上に置く）")
        self.select_runs(types, paths, secs, dec)
        # 開いた問いが0枚の判断ボードは、表だけで置ける（番号の列の無い作業の表だけでもよい）。
        if not dec and not tab:
            self.add("E-K1", "sections", "判断ボードのページには、判定カードの節か表が1つ以上要る")

    # タブ（E-N1〜E-N4）------------------------------------------------------

    def tabs(self, path, tabs):
        """タブの定義を見て（E-N1）、段を見て（E-N2）、引けるタブの key -> tabs の中の位置を返す。配列でなければ None を返す。
        引けるタブは、key が形に合い重ならないもの。label や row の誤りでは引けなくしない（部品の割り当ての誤りを重ねない）。
        key の形の誤りで引けないタブの key の文字列は self.tab_unresolved に残し、それを指す割り当てに「定義に無い」を重ねない。"""
        self.tab_unresolved = set()
        if not isinstance(tabs, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(tabs))
            return None
        if not tabs:
            # 空の tabs は中身との対応を見ない（部品の tab をすべて「定義に無い」と重ねて出さない）
            self.add("E-N1", path, "tabs が空である（タブを2つ以上書くか、tabs を消す）")
            return None
        if len(tabs) < 2:
            self.add("E-N1", path, "タブが1つしかない（2つ以上にする。1つだけのタブは何も分けない）")
        keys = {}
        rows = []  # 段の判定に使う (タブの場所, 段の名前・書いていなければ None・読めなければ False)
        for i, t in enumerate(tabs):
            tp = "%s[%d]" % (path, i)
            if not self.obj(tp, t, ("key", "label"), ("row",)):
                continue
            if "key" in t:
                k = t["key"]
                kp = join(tp, "key")
                if not isinstance(k, str):
                    self.add("E-F3", kp, "文字列であるべき所が%sである" % type_name(k))
                elif not TAB_KEY_RE.match(k):
                    self.add("E-N1", kp, 'タブの key "%s" が形に合わない（英小文字で始まり、英小文字と数字だけが続く20文字まで。- と _ は使えない）' % k)
                    self.tab_unresolved.add(k)
                elif k in keys:
                    self.add("E-N1", kp, 'タブの key "%s" が tabs[%d] と重なる' % (k, keys[k]))
                else:
                    keys[k] = i
            if "label" in t:
                self.text(join(tp, "label"), t["label"], "E-N1")
            row = None
            if "row" in t:
                row = t["row"] if self.text(join(tp, "row"), t["row"], "E-N1") else False
            rows.append((tp, row))
        self.tab_rows(path, rows)
        return keys

    def tab_rows(self, path, rows):
        """段の決まり（E-N2）。段の名前は全部のタブに書くか、どれにも書かない。書かなければ全体を1つの段として数える。
        同じ段の名前は続けて並べ、1つの段のタブは TAB_ROW_MAX まで。読めない段の名前（False）は、書いたものとして数えるが段には入れない。"""
        written = [(tp, r) for tp, r in rows if r is not None]
        if written and len(written) != len(rows):
            first = next(tp for tp, r in rows if (r is None) != (rows[0][1] is None))
            self.add("E-N2", join(first, "row"), "段の名前（row）を書いたタブと書かないタブが混ざっている（書くなら全部に書く）")
            return
        if not written:
            if len(rows) > TAB_ROW_MAX:
                self.add("E-N2", path, "段に分けずにタブが %d つある。1つの段は %d つまでにし、row で段に分ける" % (len(rows), TAB_ROW_MAX))
            return
        counts, order = {}, []
        for tp, r in written:
            if r is False:
                continue
            if order and order[-1] != r and r in counts:
                self.add("E-N2", join(tp, "row"), '段 "%s" が離れて現れる（同じ段のタブは続けて並べる）' % r)
                return
            if not order or order[-1] != r:
                order.append(r)
            counts[r] = counts.get(r, 0) + 1
            if counts[r] == TAB_ROW_MAX + 1:
                self.add("E-N2", join(tp, "row"), '段 "%s" のタブが %d つを超える（段を分ける）' % (r, TAB_ROW_MAX))

    def tab_contents(self, tabs, tab_keys, secs):
        """タブと中身の対応（E-N3）と、本文の id（E-N4）を見る。tab_keys が None なら、ページに tabs が無い。"""
        body = scan_body(self.body) if self.body is not None else None
        if tab_keys is None:
            for i, sec in enumerate(secs):
                if isinstance(sec, dict) and "tab" in sec:
                    self.add("E-N3", "sections[%d].tab" % i, "tabs の無いページの部品に tab がある（タブで分けるなら、ページに tabs を書く）")
            if body is not None and body.panels:
                self.add("E-N3", "--body", "本文に %s があるのに、ページに tabs が無い（タブで分けるなら、ページに tabs を書く）" % TAB_PANEL_CLASS)
            return
        # データの部品の側: 割り当てと、同じタブの部品を続けて並べること
        section_tab = {}  # 部品の位置 -> 引けるタブの key
        runs = []         # [(タブの key, 最初の部品の tab の場所)]（データの並びで、続いた部品をまとめたもの）
        for i, sec in enumerate(secs):
            if not isinstance(sec, dict):
                continue
            sp = "sections[%d]" % i
            if "tab" not in sec:
                self.add("E-N3", sp, "tabs のあるページでは、部品に tab（タブの key）を書く")
                continue
            t = sec["tab"]
            if not isinstance(t, str) or t in self.tab_unresolved:
                continue
            if t not in tab_keys:
                self.add("E-N3", join(sp, "tab"), 'タブ "%s" が tabs に無い' % t)
                continue
            section_tab[i] = t
            if runs and runs[-1][0] == t:
                continue
            if any(k == t for k, _ in runs):
                self.add("E-N3", join(sp, "tab"), "タブ %s の部品が離れている（同じタブの部品は続けて並べる）" % t)
                continue
            runs.append((t, join(sp, "tab")))
        # 選び方のカードと、名指した選ぶ表は同じタブに置く（問いと候補の一覧を別のタブに分けない）。
        # 束の group の選ぶ表は group の中にあるので、いつも同じ部品（同じタブ）にある。
        for card_path, tables in self.select_tables.items():
            a = section_tab.get(int(re.match(r"sections\[(\d+)\]", card_path).group(1)))
            for tp in tables or []:
                b = section_tab.get(int(re.match(r"sections\[(\d+)\]", tp).group(1)))
                if a is not None and b is not None and a != b:
                    self.add("E-N3", join(tp, "tab"), "選び方のカード %s と、名指した選ぶ表が別のタブにある（同じタブに置く）" % card_path)
        # 本文の側: パネルの形と、id
        panels = []  # [(タブの key, 場所)]（本文の並び）
        if body is not None:
            for msg in body.problems:
                self.add("E-N3", "--body", msg)
            seen = set()
            for pid, tag in body.panels:
                if pid is None:
                    self.add("E-N3", "--body", '本文のパネル <%s class="%s"> に id（タブの key）が無い' % (tag, TAB_PANEL_CLASS))
                elif pid in self.tab_unresolved:
                    continue
                elif pid not in tab_keys:
                    self.add("E-N3", "--body", '本文のパネルの id "%s" が tabs に無い' % pid)
                elif pid in seen:
                    self.add("E-N3", "--body", '本文のパネル "%s" が2つある（1つのタブのパネルは1つにする）' % pid)
                else:
                    seen.add(pid)
                    panels.append((pid, "--body"))
            counts = {}
            for v in body.ids:
                counts[v] = counts.get(v, 0) + 1
            for v in sorted(counts):
                # パネルの id の2回目はパネルの重なり（E-N3）で出しているので、id の重なりには数えない
                panel_n = sum(1 for pid, _ in body.panels if pid == v)
                if v.startswith("hp-"):
                    self.add("E-N4", "--body", '本文の id "%s" が hp- で始まる（hp- は build.py が描く要素の id の頭なので、本文には使わない）' % v)
                elif v in tab_keys and counts[v] > panel_n:
                    self.add("E-N4", "--body", '本文の id "%s" がタブの key と重なる（その名前は、タブのパネルの id と URL の # に使う）' % v)
                elif counts[v] > 1 and panel_n < 2:
                    self.add("E-N4", "--body", '本文の id "%s" が %d 回現れる' % (v, counts[v]))
        # 両方にまたがる決まり: 中身の無いタブ・本文とデータの両方を持つタブ・並び（本文のパネルが先で、tabs の順）
        data_keys = {k for k, _ in runs}
        body_keys = {k for k, _ in panels}
        for k, i in sorted(tab_keys.items(), key=lambda x: x[1]):
            tp = "tabs[%d]" % i
            if k in data_keys and k in body_keys:
                self.add("E-N3", tp, "タブ %s に、本文のパネルとデータの部品の両方がある（どちらか片方にする）" % k)
            elif k not in data_keys and k not in body_keys:
                hint = "" if self.body is not None else "。本文のパネルに置くなら、check に --body を付ける"
                self.add("E-N3", tp, "タブ %s の中身が無い（本文のパネルも、tab が %s の部品も無い%s）" % (k, k, hint))
        order = panels + [r for r in runs if r[0] not in body_keys]
        last = -1
        for k, where in order:
            if tab_keys[k] < last:
                self.add("E-N3", where, "タブ %s の中身の並びが tabs の順と違う（本文のパネルのタブを先に、データの部品のタブをあとに、tabs の順に並べる）" % k)
                break
            last = tab_keys[k]

    def request(self, path, req):
        if not self.obj(path, req, REQUEST_FIELDS):
            return
        for f in REQUEST_FIELDS:
            if f in req:
                self.text(join(path, f), req[f], "E-H1")

    def source(self, path, s):
        if not self.obj(path, s, ("repo",), ("repo_url", "issue", "branch", "tmux", "trackers")):
            return
        if "trackers" in s:
            self.trackers(join(path, "trackers"), s["trackers"])
        if "repo" in s:
            self.text(join(path, "repo"), s["repo"], "E-H2")
        if "repo_url" in s:
            self.url(join(path, "repo_url"), s["repo_url"])
        if "issue" in s and not (is_int(s["issue"]) and s["issue"] >= 1):
            self.add("E-H2", join(path, "issue"), "issue は1以上の整数であるべき所が %s"
                     % json.dumps(s["issue"], ensure_ascii=False))
        if "branch" in s:
            self.text(join(path, "branch"), s["branch"], "E-H2")
        if "tmux" in s:
            tp = join(path, "tmux")
            t = s["tmux"]
            if self.obj(tp, t, ("window", "pane", "name")):
                for f in ("window", "pane"):
                    if f in t and not (is_int(t[f]) and t[f] >= 0):
                        self.add("E-H2", join(tp, f), "%s は0以上の整数であるべき所が %s"
                                 % (f, json.dumps(t[f], ensure_ascii=False)))
                if "name" in t:
                    self.text(join(tp, "name"), t["name"], "E-H2")

    def trackers(self, path, trackers):
        if not isinstance(trackers, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(trackers))
            return
        seen = set()
        for i, t in enumerate(trackers):
            tp = "%s[%d]" % (path, i)
            if not self.obj(tp, t, ("prefix", "url")):
                continue
            if "prefix" in t:
                p = t["prefix"]
                pp = join(tp, "prefix")
                if not isinstance(p, str):
                    self.add("E-F3", pp, "文字列であるべき所が%sである" % type_name(p))
                elif not TRACKER_PREFIX_RE.match(p):
                    self.add("E-H2", pp, '接頭辞 "%s" が形に合わない（英大文字で始まり、英大文字と数字が続く10文字まで）' % p)
                elif p in seen:
                    self.add("E-H2", pp, '接頭辞 "%s" が重なる' % p)
                else:
                    seen.add(p)
            if "url" in t:
                u = t["url"]
                up = join(tp, "url")
                if not isinstance(u, str):
                    self.add("E-F3", up, "文字列であるべき所が%sである" % type_name(u))
                elif u.count(TRACKER_ID_PLACEHOLDER) != 1:
                    self.add("E-H2", up, "{id} をちょうど1つ含むべき所が %d 個ある" % u.count(TRACKER_ID_PLACEHOLDER))
                elif not URL_RE.match(u.replace(TRACKER_ID_PLACEHOLDER, "X-1")):
                    self.add("E-H2", up, "http:// か https:// で始まる URL でない")

    def links(self, path, links):
        if not isinstance(links, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(links))
            return
        for i, ln in enumerate(links):
            lp = "%s[%d]" % (path, i)
            if not self.obj(lp, ln, ("label", "url")):
                continue
            if "label" in ln:
                self.text(join(lp, "label"), ln["label"], "E-H1")
            if "url" in ln:
                self.url(join(lp, "url"), ln["url"])

    def section(self, path, sec, in_group=False):
        """部品を1つ見て、その type を返す。読めなかった（オブジェクトでない・知らない type）なら None を返す。
        ページの部品はタブの割り当て（tab）を持てる。束の group の表（in_group）は持てない（group は部品の中にある）。"""
        tab = () if in_group else ("tab",)
        if not isinstance(sec, dict):
            self.add("E-F3", path, "オブジェクトであるべき所が%sである" % type_name(sec))
            return None
        t = sec.get("type")
        if t not in SECTION_TYPES:
            shown = "無い" if "type" not in sec else json.dumps(t, ensure_ascii=False)
            self.add("E-S1", join(path, "type"), "部品の type は %s のどれかであるべき所が %s"
                     % ("・".join(SECTION_TYPES), shown))
            return None
        if t == "decisions":
            if self.obj(path, sec, ("type", "title", "cards"), tab):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                if "cards" in sec:
                    self.cards(join(path, "cards"), sec["cards"])
        elif t == "bundle":
            if self.obj(path, sec, ("type", "title", "groups"), tab):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                if "groups" in sec:
                    gp = join(path, "groups")
                    if self.array(gp, sec["groups"], "E-S1", "group が1つも無い"):
                        for i, g in enumerate(sec["groups"]):
                            self.group("%s[%d]" % (gp, i), g)
        elif t == "table":
            if self.obj(path, sec, ("type", "title", "columns", "rows"), ("key",) + tab):
                self.table_key(path, sec)
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                cols = self.columns(join(path, "columns"), sec["columns"]) if "columns" in sec else None
                self.tables[path] = cols
                if "rows" in sec:
                    self.rows(join(path, "rows"), sec["rows"], cols)
        else:
            if self.obj(path, sec, ("type", "title", "items"), ("lane",) + tab):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                if "lane" in sec:
                    self.text(join(path, "lane"), sec["lane"], "E-S2")
                if "items" in sec:
                    ip = join(path, "items")
                    if self.array(ip, sec["items"], "E-S1", "指摘が1件も無い"):
                        for i, it in enumerate(sec["items"]):
                            self.finding("%s[%d]" % (ip, i), it)
        if not in_group and "tab" in sec and not isinstance(sec["tab"], str):
            self.add("E-F3", join(path, "tab"), "文字列であるべき所が%sである" % type_name(sec["tab"]))
        return t

    def columns(self, path, cols):
        """表の列を見て、[(key, type)] を返す。列が読めなければ（1つでも誤りがあれば）None を返す。"""
        if not self.array(path, cols, "E-S1", "列が1つも無い"):
            return None
        before = len(self.errors)
        keys = []
        for i, c in enumerate(cols):
            cp = "%s[%d]" % (path, i)
            if not self.obj(cp, c, ("key", "label"), ("type",)):
                continue
            if "key" in c:
                k = c["key"]
                kp = join(cp, "key")
                if not isinstance(k, str):
                    self.add("E-F3", kp, "文字列であるべき所が%sである" % type_name(k))
                elif not KEY_RE.match(k):
                    self.add("E-S3", kp, '列の key "%s" が形に合わない（英小文字で始まり、英小文字・数字・_・- が続く64文字まで）' % k)
                elif k in keys:
                    self.add("E-S3", kp, '列の key "%s" が重なる' % k)
                else:
                    keys.append(k)
            if "label" in c:
                self.text(join(cp, "label"), c["label"], "E-S3")
            if "type" in c:
                self.enum(join(cp, "type"), c["type"], COLUMN_TYPES, "E-S3")
        if len(self.errors) != before:
            return None
        return [(c["key"], c.get("type", "text")) for c in cols]

    def rows(self, path, rows, cols):
        """表の行を見る。列が読めないとき（cols が None）は、行がオブジェクトかだけを見て、
        行の key と値は見ない（列の誤りと同じ原因の誤りを重ねない）。"""
        if not self.array(path, rows, "E-S1", "行が1つも無い"):
            return
        # 番号の列は、行の key を省いてよい唯一の列である（省けばスクリプトが番号を振る）。
        keys = tuple(k for k, kind in cols if kind != "no") if cols is not None else None
        optional = tuple(k for k, kind in cols if kind == "no") if cols is not None else ()
        for i, row in enumerate(rows):
            rp = "%s[%d]" % (path, i)
            if keys is None:
                if not isinstance(row, dict):
                    self.add("E-F3", rp, "オブジェクトであるべき所が%sである" % type_name(row))
                continue
            if not self.obj(rp, row, keys, optional):
                continue
            for k, kind in cols:
                if k in row:
                    self.cell(join(rp, k), row[k], kind)

    def cell(self, path, v, kind):
        if kind == "no":
            # 番号の列の値は文字列。接頭辞の形はページの中の識別子の検証で見る。
            if not isinstance(v, str):
                self.add("E-F3", path, "文字列であるべき所が%sである" % type_name(v))
        elif kind == "ref":
            if isinstance(v, str):
                self.ref(path, v)
            elif isinstance(v, list):
                for i, r in enumerate(v):
                    ip = "%s[%d]" % (path, i)
                    if isinstance(r, str):
                        self.ref(ip, r)
                    else:
                        self.add("E-F3", ip, "文字列であるべき所が%sである" % type_name(r))
            else:
                self.add("E-F3", path, "文字列か文字列の配列であるべき所が%sである" % type_name(v))
        elif isinstance(v, dict):
            if self.obj(path, v, ("text",), ("evidence",)):
                if "text" in v:
                    self.text(join(path, "text"), v["text"], "E-S3")
                if "evidence" in v:
                    self.enum(join(path, "evidence"), v["evidence"], EVIDENCE, "E-T1")
        elif not isinstance(v, str):
            self.add("E-F3", path, "文字列か {text, evidence} であるべき所が%sである" % type_name(v))

    def ref(self, path, r):
        """表の識別子の列の値1つが、リンクにできる識別子かを見る。
        形は送り元と関係なく見る。送り元に誤りがあれば、送り元に頼る判定（repo_url・接頭辞の登録）だけを省く。"""
        issue = REF_ISSUE_RE.match(r) or REF_XREPO_RE.match(r)
        tracker = None if issue else REF_TRACKER_RE.match(r)
        if not issue and not tracker:
            self.add("E-L1", path, '"%s" は識別子の形（#N・PR #N・owner/repo#N・<接頭辞>-<数字>）でない' % r)
            return
        links = self.group_links if self.in_group else self.page_links
        if links is None:
            return
        has_repo_url, prefixes = links
        if issue and not has_repo_url:
            self.add("E-L1", path, '"%s" をリンクにする repo_url が送り元に無い' % r)
        elif tracker and tracker.group(1) not in prefixes:
            self.add("E-L1", path, '"%s" の接頭辞 "%s" が送り元の trackers に無い' % (r, tracker.group(1)))

    def group(self, path, g):
        if not self.obj(path, g, ("source", "title", "cards"), ("why", "tables")):
            return
        links = None
        if "source" in g:
            before = len(self.errors)
            self.source(join(path, "source"), g["source"])
            if len(self.errors) == before:
                links = ("repo_url" in g["source"], {t["prefix"] for t in g["source"].get("trackers", [])})
        if "tables" in g:
            # group の表の識別子は、group の送り元でリンクにする（描画と同じ）。送り元に誤りがあれば、その group だけ省く
            self.in_group, self.group_links = True, links
            self.group_tables(join(path, "tables"), g["tables"])
            self.in_group, self.group_links = False, None
        if "title" in g:
            self.text(join(path, "title"), g["title"], "E-S1")
        if "why" in g:
            self.text(join(path, "why"), g["why"], "E-H1")
        if "cards" in g:
            self.cards(join(path, "cards"), g["cards"])

    def group_tables(self, path, tables):
        """束の group の表。表の部品と同じ形で、key を必ず持つ（選ぶ表として同じ group の選び方のカードが名指すため）。"""
        if not isinstance(tables, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(tables))
            return
        for i, tb in enumerate(tables):
            tp = "%s[%d]" % (path, i)
            if isinstance(tb, dict) and "type" in tb and tb["type"] != "table":
                self.add("E-S1", join(tp, "type"), 'group の tables に置ける部品の type は table であるべき所が %s'
                         % json.dumps(tb["type"], ensure_ascii=False))
                continue
            if self.section(tp, tb, in_group=True) == "table" and "key" not in tb:
                self.add("E-F3", join(tp, "key"), "group の表は key を持つ（同じ group の選び方のカードが tables で名指す）")

    def cards(self, path, cards):
        if self.array(path, cards, "E-S1", "カードが1枚も無い"):
            for i, c in enumerate(cards):
                self.card("%s[%d]" % (path, i), c)

    def card(self, path, c):
        if not self.obj(path, c, ("key", "title", "recommend", "options"),
                        ("reason", "tag", "points", "blocks", "evidence", "select")):
            return
        key = None
        if "key" in c:
            k = c["key"]
            kp = join(path, "key")
            if not isinstance(k, str):
                self.add("E-F3", kp, "文字列であるべき所が%sである" % type_name(k))
            elif not KEY_RE.match(k):
                self.add("E-C1", kp, 'key "%s" が形に合わない（英小文字で始まり、英小文字・数字・_・- が続く64文字まで）' % k)
            elif k in self.card_paths:
                self.add("E-C1", kp, 'key "%s" が %s と重なる' % (k, self.card_paths[k]))
            else:
                self.card_paths[k] = path
                key = k
        for f in ("title", "tag"):
            if f in c:
                self.text(join(path, f), c[f], "E-C5")
        if "reason" in c:
            self.text(join(path, "reason"), c["reason"], "E-C4")
        if "evidence" in c:
            self.enum(join(path, "evidence"), c["evidence"], EVIDENCE, "E-T1")
        if "points" in c:
            self.points(join(path, "points"), c["points"])
        if "blocks" in c:
            self.blocks(join(path, "blocks"), c["blocks"])
        option_keys = None
        if "options" in c:
            option_keys = self.options(join(path, "options"), c["options"])
        if "recommend" in c:
            r = c["recommend"]
            rp = join(path, "recommend")
            if not isinstance(r, str):
                self.add("E-F3", rp, "文字列であるべき所が%sである" % type_name(r))
            elif option_keys is not None and r not in option_keys:
                self.add("E-C3", rp, '推奨 "%s" が選択肢（%s）に無い' % (r, ", ".join(option_keys)))
        if key is not None:
            self.card_options[key] = option_keys or []
        if "select" in c:
            self.selects.append((path, key, self.select(join(path, "select"), c["select"]), c["select"]))

    def select(self, path, sel):
        """選び方のカードの、行を選ぶ数・推奨の行・選ぶ表。形が合えば sel を、誤りがあれば None を返す。
        max は必須の1以上の整数、min は任意の1以上の整数で max 以下、recommend は任意の識別子の並びで max 個まで、
        tables は任意の表の key の並び（1つ以上・重ねない）。tables の名指しの誤り（E-C7）は返す値に関わらない
        （名指しは表の解決で別に見るので、選ぶ数の判定を隠さない）。"""
        before = len(self.errors)  # 項目の欠け（E-F3）も形の誤りに数える
        if not self.obj(path, sel, ("max",), ("min", "recommend", "tables")):
            return None
        result = self.select_counts(path, sel, before)
        if "tables" in sel:
            tp = join(path, "tables")
            t = sel["tables"]
            if not isinstance(t, list):
                self.add("E-F3", tp, "配列であるべき所が%sである" % type_name(t))
            elif not t:
                self.add("E-C7", tp, "選ぶ表の名指しが空である（表の key を1つ以上書く）")
            else:
                seen = set()
                for i, name in enumerate(t):
                    if not isinstance(name, str):
                        self.add("E-F3", "%s[%d]" % (tp, i), "文字列であるべき所が%sである" % type_name(name))
                    elif name in seen:
                        self.add("E-C7", "%s[%d]" % (tp, i), '表 "%s" を2回名指している' % name)
                    else:
                        seen.add(name)
        return result

    @staticmethod
    def select_tables_ok(sel):
        """select の tables が、名指しの解決に使える形か（文字列の並びで、空でなく、重ならない）。"""
        t = sel.get("tables") if isinstance(sel, dict) else None
        return isinstance(t, list) and bool(t) and all(isinstance(x, str) for x in t) and len(set(t)) == len(t)

    def select_counts(self, path, sel, before):
        """選ぶ数と推奨の行の形と数の誤りを見て、誤りが無ければ sel を返す（tables は見ない）。"""
        for f in ("max", "min"):
            if f in sel and not (is_int(sel[f]) and sel[f] >= 1):
                self.add("E-F3", join(path, f), "%s は1以上の整数であるべき所が %s" % (f, json.dumps(sel[f], ensure_ascii=False)))
        rec = sel.get("recommend", [])
        if "recommend" in sel:
            if not isinstance(rec, list):
                self.add("E-F3", join(path, "recommend"), "配列であるべき所が%sである" % type_name(rec))
                rec = []
            else:
                for i, r in enumerate(rec):
                    if not isinstance(r, str) or not r.strip():
                        self.add("E-F3", "%s.recommend[%d]" % (path, i), "空でない文字列であるべき所が %s" % json.dumps(r, ensure_ascii=False))
        if len(self.errors) != before:
            return None
        mx = sel.get("max")
        if "min" in sel and mx is not None and sel["min"] > mx:
            self.add("E-C6", path, "min（%d）が max（%d）より大きい" % (sel["min"], mx))
        if mx is not None and len(rec) > mx:
            self.add("E-C6", join(path, "recommend"), "推奨の行が %d つで、選べる数（max %d）を超える" % (len(rec), mx))
        if len(set(rec)) != len(rec):
            self.add("E-C6", join(path, "recommend"), "推奨の行が重なる")
        return sel if len(self.errors) == before else None

    def table_key(self, path, sec):
        """表の key（任意）。形はカードの key と同じで、ページの表と束の group の表を合わせて重ねない。"""
        if "key" not in sec:
            return
        k = sec["key"]
        kp = join(path, "key")
        if not isinstance(k, str):
            self.add("E-F3", kp, "文字列であるべき所が%sである" % type_name(k))
        elif not KEY_RE.match(k):
            self.add("E-S3", kp, '表の key "%s" が形に合わない（英小文字で始まり、英小文字・数字・_・- が続く64文字まで）' % k)
        elif k in self.table_keys:
            self.add("E-S3", kp, '表の key "%s" が %s と重なる' % (k, self.table_keys[k]))
        else:
            self.table_keys[k] = path

    def points(self, path, points):
        if not isinstance(points, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(points))
            return
        for i, p in enumerate(points):
            pp = "%s[%d]" % (path, i)
            if isinstance(p, str):
                self.text(pp, p, "E-C5")
            elif isinstance(p, dict):
                if self.obj(pp, p, ("text",), ("evidence",)):
                    if "text" in p:
                        self.text(join(pp, "text"), p["text"], "E-C5")
                    if "evidence" in p:
                        self.enum(join(pp, "evidence"), p["evidence"], EVIDENCE, "E-T1")
            else:
                self.add("E-F3", pp, "文字列か {text, evidence} であるべき所が%sである" % type_name(p))

    def blocks(self, path, blocks):
        """カードの小見出し付きの要点の塊。塊は1つ以上、各塊の要点も1つ以上（見出しだけの塊は意味が無い）。"""
        if not self.array(path, blocks, "E-C5", "塊が1つも無い"):
            return
        for i, b in enumerate(blocks):
            bp = "%s[%d]" % (path, i)
            if not self.obj(bp, b, ("title", "points")):
                continue
            if "title" in b:
                self.text(join(bp, "title"), b["title"], "E-C5")
            if "points" in b:
                pp = join(bp, "points")
                if self.array(pp, b["points"], "E-C5", "要点が1つも無い"):
                    self.points(pp, b["points"])

    def options(self, path, opts):
        """選択肢を見て、形の合った key の並びを返す。2つ未満なら None を返す。"""
        if not isinstance(opts, list):
            self.add("E-F3", path, "配列であるべき所が%sである" % type_name(opts))
            return None
        if len(opts) < 2:
            self.add("E-C2", path, "選択肢が2つ未満である")
            return None
        keys = []
        for i, o in enumerate(opts):
            op = "%s[%d]" % (path, i)
            if not self.obj(op, o, ("key", "label"), ("kind",)):
                continue
            if "key" in o:
                k = o["key"]
                kp = join(op, "key")
                if not isinstance(k, str):
                    self.add("E-F3", kp, "文字列であるべき所が%sである" % type_name(k))
                elif not KEY_RE.match(k):
                    self.add("E-C2", kp, '選択肢の key "%s" が形に合わない（英小文字で始まり、英小文字・数字・_・- が続く64文字まで）' % k)
                elif k in keys:
                    self.add("E-C2", kp, '選択肢の key "%s" が重なる' % k)
                else:
                    keys.append(k)
            if "label" in o and self.text(join(op, "label"), o["label"], "E-C5"):
                # 選択肢の名前は中身を書く（E-Q2・表記の規則）。推奨のボタンには推奨の札が付くので、推奨の語で始めない。
                # 括弧書きの中は見ない（別のカードの推奨を指す書き方があるため）。
                rest = strip_parens(o["label"]).strip()
                if not rest:
                    self.add("E-Q2", join(op, "label"), '選択肢の名前 "%s" が括弧書きだけである。選んだら何をするかを書く' % o["label"])
                elif rest.startswith(self.words["recommend"]):
                    self.add("E-Q2", join(op, "label"), '選択肢の名前 "%s" が「%s」で始まる。選んだら何をするかを書く'
                             % (o["label"], self.words["recommend"]))
            if "kind" in o:
                self.enum(join(op, "kind"), o["kind"], KINDS, "E-T1")
        return keys

    def finding(self, path, it):
        if not self.obj(path, it, ("text", "severity", "adopted", "reason"), ("evidence",)):
            return
        for f in ("text", "reason"):
            if f in it:
                self.text(join(path, f), it[f], "E-S2")
        if "severity" in it:
            self.enum(join(path, "severity"), it["severity"], SEVERITIES, "E-T1")
        if "adopted" in it:
            self.enum(join(path, "adopted"), it["adopted"], ADOPTIONS, "E-T1")
        if "evidence" in it:
            self.enum(join(path, "evidence"), it["evidence"], EVIDENCE, "E-T1")

    def answers(self, path, ans):
        if not isinstance(ans, dict):
            self.add("E-F3", path, "オブジェクトであるべき所が%sである" % type_name(ans))
            return
        for k, a in ans.items():
            ap = join(path, k)
            if k not in self.card_options:
                self.add("E-A1", ap, 'key "%s" のカードが無い' % k)
                continue
            if not self.obj(ap, a, ("choice", "note", "at")):
                continue
            if "choice" in a:
                ch = a["choice"]
                if ch is not None and not (isinstance(ch, str) and ch in self.card_options[k]):
                    self.add("E-A1", join(ap, "choice"), "choice は null か、そのカードの選択肢（%s）のどれかであるべき所が %s"
                             % (", ".join(self.card_options[k]), json.dumps(ch, ensure_ascii=False)))
            for f in ("note", "at"):
                if f in a and not isinstance(a[f], str):
                    self.add("E-A1", join(ap, f), "%s は文字列であるべき所が%sである" % (f, type_name(a[f])))
        # 一覧から選ぶ行の答えは、選び方の上限を超えない（別の画面で選んだ行が重なると、ページでは超えうる）。
        for card_key, (mx, row_keys) in self.pick_limits.items():
            chosen = [rk for rk in row_keys if isinstance(ans.get(rk), dict) and ans[rk].get("choice") == PICK_CHOICE]
            if len(chosen) > mx:
                self.add("E-A1", path, "カード %s の選んだ行が %d つで、選べる数（max %d）を超える" % (card_key, len(chosen), mx))


LIST_SEPARATORS = "・、,，"


def display_texts(data):
    """表示の文を、[(場所, 文字列)] で返す（Renderer が inline に渡すものと同じ）。番号を並べる書き方（E-I3）の検査に使う。
    束の group の中の文も含める（リンクは group の送り元で作るが、group の選ぶ表の候補の番号はページの識別子である）。
    形の崩れた所は飛ばす。"""
    out = []

    def add(path, v):
        if isinstance(v, str):
            out.append((path, v))
        elif isinstance(v, dict) and isinstance(v.get("text"), str):
            out.append((join(path, "text"), v["text"]))

    def add_points(path, points):
        if isinstance(points, list):
            for k, pt in enumerate(points):
                add("%s[%d]" % (path, k), pt)

    def add_cards(path, cards):
        for j, c in enumerate(cards if isinstance(cards, list) else []):
            if not isinstance(c, dict):
                continue
            cp = "%s[%d]" % (path, j)
            for f in ("title", "reason"):
                add(join(cp, f), c.get(f))
            add_points(join(cp, "points"), c.get("points"))
            for k, b in enumerate(c.get("blocks") if isinstance(c.get("blocks"), list) else []):
                if isinstance(b, dict):
                    add("%s.blocks[%d].title" % (cp, k), b.get("title"))
                    add_points("%s.blocks[%d].points" % (cp, k), b.get("points"))
            # 推奨の選択肢の文は、カードの推奨の行で変換される（選択肢のボタンは変換しない）。
            for k, o in enumerate(c.get("options") if isinstance(c.get("options"), list) else []):
                if isinstance(o, dict) and o.get("key") == c.get("recommend"):
                    add("%s.options[%d].label" % (cp, k), o.get("label"))

    def add_table(path, sec):
        add(join(path, "title"), sec.get("title"))
        if isinstance(sec.get("columns"), list) and isinstance(sec.get("rows"), list):
            text_keys = [c.get("key") for c in sec["columns"] if isinstance(c, dict) and c.get("type", "text") == "text"]
            for j, row in enumerate(sec["rows"]):
                if isinstance(row, dict):
                    for k in text_keys:
                        if isinstance(k, str):
                            add("%s.rows[%d].%s" % (path, j, k), row.get(k))

    if not isinstance(data, dict):
        return out
    add("why", data.get("why"))
    if isinstance(data.get("request"), dict):
        for f in REQUEST_FIELDS:
            add(join("request", f), data["request"].get(f))
    secs = data.get("sections")
    for i, sec in enumerate(secs if isinstance(secs, list) else []):
        if not isinstance(sec, dict):
            continue
        sp = "sections[%d]" % i
        if sec.get("type") == "table":
            add_table(sp, sec)
            continue
        add(join(sp, "title"), sec.get("title"))
        if sec.get("type") == "decisions":
            add_cards(join(sp, "cards"), sec.get("cards"))
        elif sec.get("type") == "bundle" and isinstance(sec.get("groups"), list):
            for g, grp in enumerate(sec["groups"]):
                if not isinstance(grp, dict):
                    continue
                gp = "%s.groups[%d]" % (sp, g)
                add(join(gp, "title"), grp.get("title"))
                add(join(gp, "why"), grp.get("why"))
                add_cards(join(gp, "cards"), grp.get("cards"))
                for t, tb in enumerate(grp.get("tables") if isinstance(grp.get("tables"), list) else []):
                    if isinstance(tb, dict):
                        add_table("%s.tables[%d]" % (gp, t), tb)
        elif sec.get("type") == "findings" and isinstance(sec.get("items"), list):
            for j, it in enumerate(sec["items"]):
                if isinstance(it, dict):
                    for f in ("text", "reason"):
                        add("%s.items[%d].%s" % (sp, j, f), it.get(f))
    return out
    add("why", data.get("why"))
    if isinstance(data.get("request"), dict):
        for f in REQUEST_FIELDS:
            add(join("request", f), data["request"].get(f))
    secs = data.get("sections")
    for i, sec in enumerate(secs if isinstance(secs, list) else []):
        if not isinstance(sec, dict):
            continue
        sp = "sections[%d]" % i
        add(join(sp, "title"), sec.get("title"))
        if sec.get("type") == "decisions" and isinstance(sec.get("cards"), list):
            for j, c in enumerate(sec["cards"]):
                if not isinstance(c, dict):
                    continue
                cp = "%s.cards[%d]" % (sp, j)
                for f in ("title", "reason"):
                    add(join(cp, f), c.get(f))
                add_points(join(cp, "points"), c.get("points"))
                for k, b in enumerate(c.get("blocks") if isinstance(c.get("blocks"), list) else []):
                    if isinstance(b, dict):
                        add("%s.blocks[%d].title" % (cp, k), b.get("title"))
                        add_points("%s.blocks[%d].points" % (cp, k), b.get("points"))
                # 推奨の選択肢の文は、カードの推奨の行で変換される（選択肢のボタンは変換しない）。
                for k, o in enumerate(c.get("options") if isinstance(c.get("options"), list) else []):
                    if isinstance(o, dict) and o.get("key") == c.get("recommend"):
                        add("%s.options[%d].label" % (cp, k), o.get("label"))
        elif sec.get("type") == "findings" and isinstance(sec.get("items"), list):
            for j, it in enumerate(sec["items"]):
                if isinstance(it, dict):
                    for f in ("text", "reason"):
                        add("%s.items[%d].%s" % (sp, j, f), it.get(f))
        elif sec.get("type") == "table" and isinstance(sec.get("columns"), list) and isinstance(sec.get("rows"), list):
            text_keys = [c.get("key") for c in sec["columns"] if isinstance(c, dict) and c.get("type", "text") == "text"]
            for j, row in enumerate(sec["rows"]):
                if isinstance(row, dict):
                    for k in text_keys:
                        if isinstance(k, str):
                            add("%s.rows[%d].%s" % (sp, j, k), row.get(k))
    return out


def check_collected(data, collected, has_body=False, words=None, body=None):
    """回収した答え（保存先から読んだ文書を、answers と同じ形に写したもの）を、ページに当てる（check --answers）。
    ページにある key（カードと行の答え）は answers の検査（E-A1・選び方のカードごとの上限）で見て、
    ページに無い key（前の回収で表へ移したカードの答え・除いた表の行の答え）は見ずに数える。
    ページの状態に関係なく見る。返すのは (ページの誤りと渡した答えの誤りの並び, 見なかった key の数)。
    body は --body の本文の文字列で、validate と同じくタブのパネルの検査に使う。"""
    v = Validator(has_body, words if words is not None else load_words(DEFAULT_GLOSSARY), body)
    v.page(data)
    if not isinstance(collected, dict):
        v.add("E-F3", "--answers", "回収した答えはオブジェクトであるべき所が%sである" % type_name(collected))
        return v.errors, 0
    known = {k: a for k, a in collected.items() if k in v.card_options}
    v.answers("--answers", known)
    return v.errors, len(collected) - len(known)


def validate(data, has_body=False, words=None, body=None):
    """データを検証し、誤りの並び [(規則の番号, 場所, 理由)] を返す。空なら誤りは無い。
    words は用語集の識別子の接頭辞（load_words の結果）。省けば既定の用語集から読む。
    body は --body の本文の文字列で、タブのパネルの検査に使う（渡せば has_body も真とみなす）。"""
    v = Validator(has_body, words if words is not None else load_words(DEFAULT_GLOSSARY), body)
    v.page(data)
    return v.errors


def format_errors(errors):
    return ["%s %s: %s" % e for e in errors]


# ---------------------------------------------------------------- 描画

TEMPLATE = os.path.join(HERE, "template.html")
CSS = os.path.join(HERE, "page.css")
JS = os.path.join(HERE, "page.js")
TEMPLATE_SLOTS = ("title", "css", "purpose", "status", "header", "bar", "body", "sections", "reply", "scripts")
SLOT_RE = re.compile(r"\{\{([a-z]+)\}\}")

# 版の時刻は JST（UTC+9）で書く。時間帯の表に頼らないよう、固定の時差で直す。
JST = timezone(timedelta(hours=9), "JST")

# 本文の中で効く書式は4つだけ: `…` をコードに、https://… をリンクに、#N を issue へのリンクに、
# 送り元の trackers に登録した接頭辞の ID（OPS-41 など）を外部の課題管理へのリンクにする。
CODE_RE = re.compile(r"`([^`\n]+)`")
_URL_STOP = r"\s<>\"'`" + chr(0x3000) + "-" + chr(0x303F) + chr(0xFF01) + "-" + chr(0xFF60)
# 同じ位置から始まる候補は、URL → PR #N → owner/repo#N → #N の順に当てる（外部の課題管理の ID と
# ページの中の識別子は、そのあとに足す）。PR #N は前に英数字か _ が続くと PR #N として扱わない（XPR #3 は #3 だけ）。
# owner/repo#N は、前に英数字・_・.・/・- が続くもの（docs/a/b#3 の中の a/b#3）を扱わない。
LINK_PATTERN = (r"(?P<url>https?://[^" + _URL_STOP + r"]+)"
                r"|(?P<pr>(?<![A-Za-z0-9_])PR #(?P<prnum>\d{1,7})(?![A-Za-z0-9_]))"
                r"|(?P<xrepo>(?<![A-Za-z0-9_./-])" + XREPO.replace("(", "(?:") + r"(?![A-Za-z0-9_]))"
                r"|(?P<issue>(?<![A-Za-z0-9_])#(?P<num>\d{1,7})(?![A-Za-z0-9_]))")
LINK_RE = re.compile(LINK_PATTERN)
# 番号を並べる書き方（E-I3）を探すときに除く範囲。描くときのコードの書式と URL の範囲にそろえる。
_SKIP_FOR_LISTS_RE = re.compile(r"`[^`\n]+`|https?://[^" + _URL_STOP + r"]+")
TRACKER_PATTERN = r"|(?P<tracker>(?<![A-Za-z0-9_-])(?P<prefix>%s)-\d+(?![A-Za-z0-9_-]))"
# ページで定義した識別子（Q2・候補4）。前に英数字・_・.・/・#・- が続くもの（FAQ2・docs/Q2）、
# 後ろに英数字・_ が続くもの（候補43 の中の 候補4）と、. / - と英数字が続くもの（Q2.md・Q2-3）はリンクにしない。
ANCHOR_PATTERN = r"|(?P<anchor>(?<![A-Za-z0-9_./#-])(?:%s)(?![0-9A-Za-z_])(?![./-][A-Za-z0-9]))"
URL_TRAIL = ".,;:!?)]}"

# JSON をページに埋め込むとき、要素を閉じたり行を分けたりしうる文字を \u の形に置き換える。
_JSON_UNSAFE = ("<", ">", "&", chr(0x2028), chr(0x2029))


def esc(s):
    return html.escape(str(s), quote=True)


def link(url, text):
    return '<a href="%s" target="_blank" rel="noopener">%s</a>' % (esc(url), esc(text))


def issue_url(repo_url, num):
    return "%s/issues/%s" % (repo_url.rstrip("/"), num)


def pull_url(repo_url, num):
    return "%s/pull/%s" % (repo_url.rstrip("/"), num)


# repo_url の先頭の http(s)://<ホスト> の部分。検証は http(s):// で始まることしか見ないので、
# URL の部品に分ける処理（urlsplit）を使わず、形の崩れたホストでも例外にしない。
_URL_ORIGIN_RE = re.compile(r"https?://[^/?#]*")


def xrepo_url(repo_url, ident):
    """owner/repo#N を、送り元の repo_url と同じホストの、そのリポジトリの issue の URL にする。"""
    owner, name, num = REF_XREPO_RE.match(ident).groups()
    return "%s/%s/%s/issues/%s" % (_URL_ORIGIN_RE.match(repo_url).group(0), owner, name, num)


def branch_url(repo_url, branch):
    return "%s/tree/%s" % (repo_url.rstrip("/"), quote(branch, safe="/"))


class Refs:
    """文字列の中の #N・外部の課題管理の ID・ページの中の識別子をリンクにするための、いちばん近い送り元の情報。
    anchors はページで定義した識別子から、飛び先の要素の id への辞書（ページの送り元だけが持つ）。"""

    def __init__(self, src, anchors=None):
        self.repo_url = src.get("repo_url")
        self.trackers = {t["prefix"]: t["url"] for t in src.get("trackers", [])}
        self.anchors = anchors or {}
        pattern = LINK_PATTERN
        if self.trackers:
            # 長い接頭辞を先に置き、短い接頭辞が長い接頭辞の頭に当たらないようにする。
            names = sorted(self.trackers, key=lambda p: (-len(p), p))
            pattern += TRACKER_PATTERN % "|".join(re.escape(p) for p in names)
        if self.anchors:
            # 長い識別子を先に置き、Q12 の頭の Q1 に当たらないようにする。
            names = sorted(self.anchors, key=lambda a: (-len(a), a))
            pattern += ANCHOR_PATTERN % "|".join(re.escape(a) for a in names)
        self.link_re = re.compile(pattern)

    def tracker_url(self, ident, prefix):
        return self.trackers[prefix].replace(TRACKER_ID_PLACEHOLDER, quote(ident, safe=""))

    def ref_link(self, ref):
        """表の識別子の列の値1つ（検証を通ったもの）をリンクにする。表示の文字は書いたまま残す。"""
        m = REF_ISSUE_RE.match(ref)
        if m:
            url = pull_url if ref.startswith("PR ") else issue_url
            return link(url(self.repo_url, m.group(1)), ref)
        if REF_XREPO_RE.match(ref):
            return link(xrepo_url(self.repo_url, ref), ref)
        return link(self.tracker_url(ref, REF_TRACKER_RE.match(ref).group(1)), ref)


def inline(text, refs):
    """平文をエスケープし、コード・URL・#N・外部の課題管理の ID の書式だけを足した HTML を返す。"""
    out = []
    pos = 0
    for m in CODE_RE.finditer(text):
        out.append(_linkify(text[pos:m.start()], refs))
        out.append("<code>%s</code>" % esc(m.group(1)))
        pos = m.end()
    out.append(_linkify(text[pos:], refs))
    return "".join(out)


def _linkify(text, refs):
    # URL・#N・ID を1回の走査で左から見る。URL に当たった部分の中の #N や ID はリンクにしない。
    out = []
    pos = 0
    for m in refs.link_re.finditer(text):
        out.append(esc(text[pos:m.start()]))
        if m.group("url"):
            url = m.group("url")
            trail = ""
            while url and url[-1] in URL_TRAIL:
                trail = url[-1] + trail
                url = url[:-1]
            out.append(link(url, url) + esc(trail))
        elif m.group("pr") or m.group("xrepo"):
            # 近い送り元に repo_url が無ければ、#N と同じく文字のまま出す。
            ident = m.group(0)
            if not refs.repo_url:
                out.append(esc(ident))
            elif m.group("pr"):
                out.append(link(pull_url(refs.repo_url, m.group("prnum")), ident))
            else:
                out.append(link(xrepo_url(refs.repo_url, ident), ident))
        elif m.group("issue"):
            if refs.repo_url:
                out.append(link(issue_url(refs.repo_url, m.group("num")), m.group("issue")))
            else:
                out.append(esc(m.group("issue")))
        elif m.lastgroup == "anchor":
            # ページの中の行やカードへ飛ぶリンク。外へのリンクと違い、新しいタブを開かない。
            out.append('<a href="#%s">%s</a>' % (esc(refs.anchors[m.group("anchor")]), esc(m.group("anchor"))))
        else:
            out.append(link(refs.tracker_url(m.group("tracker"), m.group("prefix")), m.group("tracker")))
        pos = m.end()
    out.append(esc(text[pos:]))
    return "".join(out)


def embed_json(obj):
    s = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    for c in _JSON_UNSAFE:
        s = s.replace(c, chr(92) + "u%04x" % ord(c))
    return s


def fill(template, **values):
    return PLACEHOLDER_RE.sub(lambda m: str(values[m.group(1)]), template)


def format_time(now):
    return now.astimezone(JST).strftime("%Y-%m-%d %H:%M") + " JST"


def parse_now(value):
    if value is None:
        return datetime.now(timezone.utc)
    s = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        raise LoadError("--now の時刻（%s）を読めない。2026-10-19T09:05:00+00:00 の形で渡す" % value)
    if dt.tzinfo is None:
        raise LoadError("--now の時刻（%s）に時差が無い。+09:00 や +00:00 を付ける" % value)
    return dt


def tmux_from_env():
    """作ったセッションのペインの位置を引く。引けなければ (None, 理由) を返す。"""
    pane = os.environ.get("TMUX_PANE")
    if not pane:
        return None, "TMUX_PANE が無い（tmux の外で走らせた）"
    try:
        p = subprocess.run(["tmux", "display-message", "-p", "-t", pane,
                            "#{window_index}\t#{pane_index}\t#{window_name}"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=5)
    except (OSError, subprocess.SubprocessError) as e:
        return None, "tmux を呼べない（%s）" % e
    if p.returncode != 0:
        return None, "tmux が答えない（%s）" % p.stderr.strip()
    parts = p.stdout.rstrip("\n").split("\t")
    if len(parts) != 3 or not parts[0].isdigit() or not parts[1].isdigit():
        return None, "tmux の答え（%r）を読めない" % p.stdout
    return {"window": int(parts[0]), "pane": int(parts[1]), "name": parts[2]}, None


def meta_rows(src, tmux, L):
    """送り元の表の行 [(項目名, 値の HTML)]。リポジトリ・tmux・issue・ブランチの順で、無い項目は行ごと省く。"""
    repo_url = src.get("repo_url")
    rows = [(L["text.head_repo"], esc(src["repo"]))]
    if tmux:
        t = "%d.%d" % (tmux["window"], tmux["pane"])
        if tmux.get("name"):
            t += "（%s）" % tmux["name"]
        rows.append((L["text.head_tmux"], esc(t)))
    if "issue" in src:
        text = "#%d" % src["issue"]
        rows.append((L["text.head_issue"], link(issue_url(repo_url, src["issue"]), text) if repo_url else esc(text)))
    if "branch" in src:
        b = src["branch"]
        rows.append((L["text.head_branch"], link(branch_url(repo_url, b), b) if repo_url else esc(b)))
    return rows


def meta_table(rows):
    """項目名と値の表。幅の広い画面では2列に並び、狭い画面では縦に積む（page.css）。"""
    return '<dl class="hp-meta">%s</dl>' % "".join(
        '<div class="hp-meta-row"><dt>%s</dt><dd>%s</dd></div>' % (esc(k), v) for k, v in rows)


def page_tables(data):
    """検証を通ったデータの表を、[(表の位置, 表)] で返す。ページの表の位置は (部品の順,)、
    束の group の表の位置は (部品の順, group の順, 表の順) である。行の位置は、表の位置に行の順を足したもの。"""
    out = []
    for si, sec in enumerate(data["sections"]):
        if sec["type"] == "table":
            out.append(((si,), sec))
        elif sec["type"] == "bundle":
            for gi, g in enumerate(sec["groups"]):
                out.extend(((si, gi, ti), tb) for ti, tb in enumerate(g.get("tables", [])))
    return out


def row_id(pos):
    """行の位置から、飛び先の要素の id を作る（ページの表は hp-row-<部品>-<行>、group の表は hp-row-<部品>-g<group>-t<表>-<行>）。"""
    if len(pos) == 2:
        return "hp-row-%d-%d" % pos
    return "hp-row-%d-g%d-t%d-%d" % pos


def assign_numbers(data, words):
    """検証を通ったデータの、出す札（カードの key -> 札）と番号の列の値（行の位置 -> 値）を返す。
    一覧から選ぶページと見取り図は、書かれていなければ、種別の接頭辞とページの中の順（番号の列のある行の順）から振る。
    ほかの種別の番号の列（判断ボードの決まったこと・選ぶ表）は、検証が書いてあることを確かめている。"""
    card_key, row_key, _ = KIND_IDS.get(data["kind"], (None, None, False))
    tags, numbers = {}, {}
    if card_key:
        approval = words["tag.approval"] if data["kind"] == "approve" else None
        questions = [c for sec in data["sections"] if sec["type"] == "decisions" for c in sec["cards"]
                     if not (approval and c.get("tag") == approval)]
        for i, c in enumerate(questions, 1):
            tags[c["key"]] = c.get("tag") or "%s%d" % (words[card_key], i)
    n = 0
    for tpos, sec in page_tables(data):
        no = [c["key"] for c in sec["columns"] if c.get("type") == "no"]
        if not no:
            continue
        for ri, row in enumerate(sec["rows"]):
            n += 1
            numbers[tpos + (ri,)] = row.get(no[0]) or ("%s%d" % (words[row_key], n) if row_key else "")
    return tags, numbers


def picks_info(data, words, numbers):
    """選び方のカード（select のあるカード）ごとの、行の選択の情報の並び（カードの順）。
    rows は 行の位置 -> (行の答えの key, 番号)。選ぶ表は select の tables、書かなければ（一覧から選ぶページ）
    ページの番号の列のある表のすべてである。"""
    cand = words["prefix.candidate"]
    by_key = {sec["key"]: tpos for tpos, sec in page_tables(data) if "key" in sec}
    number_tables = [tpos for tpos, sec in page_tables(data)
                     if len(tpos) == 1 and any(c.get("type") == "no" for c in sec["columns"])]
    cards = []
    for sec in data["sections"]:
        if sec["type"] == "decisions":
            cards.extend(sec["cards"])
        elif sec["type"] == "bundle":
            cards.extend(c for g in sec["groups"] for c in g["cards"])
    out = []
    for card in cards:
        if "select" not in card:
            continue
        sel = card["select"]
        tables = [by_key[k] for k in sel["tables"]] if "tables" in sel else number_tables
        rows = {}
        for tpos in tables:
            for pos in sorted(p for p in numbers if p[:-1] == tpos):
                num = numbers[pos]
                rows[pos] = (card["key"] + PICK_KEY_SEP + num[len(cand):], num)
        out.append({"card": card["key"], "max": sel["max"], "min": sel.get("min"),
                    "recommend": list(sel.get("recommend", [])), "rows": rows})
    return out


class Renderer:
    def __init__(self, data, labels, now, tmux, words):
        self.data = data
        self.L = labels
        self.tags, self.numbers = assign_numbers(data, words)
        # ページで定義した識別子の飛び先。カードはいまある id、番号の列のある表の行には行の id を付ける。
        anchors = {tag: "hp-card-" + key for key, tag in self.tags.items()}
        anchors.update({num: row_id(pos) for pos, num in self.numbers.items()})
        self.anchors = anchors
        self.time = format_time(now)
        self.tmux = tmux
        self.page_refs = Refs(data["source"], anchors)
        self.answered = data["status"] == "answered"
        self.answers = data.get("answers") or {}
        self.cards = []   # JS に渡すカード
        self.groups = []  # JS に渡す group
        # 選び方のカードごとの行の選択（カードの key -> 情報）と、選ぶ表の行の位置 -> 情報。
        self.picks = picks_info(data, words, self.numbers)
        self.pick_of = {p["card"]: p for p in self.picks}
        self.row_pick = {pos: p for p in self.picks for pos in p["rows"]}

    def chip(self, cls, text):
        return '<span class="hp-chip %s">%s</span>' % (cls, esc(text))

    def evidence(self, value):
        return self.chip("hp-ev-" + value, self.L["evidence." + value]) if value else ""

    def open_count(self, cards):
        return sum(1 for c in cards if not (self.answers.get(c["key"]) or {}).get("choice"))

    def status_text(self):
        status = self.data["status"]
        if status == "awaiting":
            return fill(self.L["status.awaiting"], n=self.open_count(self.all_cards()))
        return self.L["status." + status]

    def all_cards(self):
        out = []
        for sec in self.data["sections"]:
            if sec["type"] == "decisions":
                out.extend(sec["cards"])
            elif sec["type"] == "bundle":
                for g in sec["groups"]:
                    out.extend(g["cards"])
        return out

    def has_answer_part(self):
        return any(sec["type"] in ANSWER_SECTION_TYPES for sec in self.data["sections"])

    # ヘッダー ------------------------------------------------------------

    def header(self):
        d = self.data
        h = ['<header class="hp-head">']
        rows = meta_rows(d["source"], self.tmux, self.L)
        rows.append((self.L["text.head_version"], esc(fill(self.L["text.version"], time=self.time))))
        rows.append((self.L["text.head_status"], '<span id="hp-status">%s</span>' % esc(self.status_text())))
        h.append(meta_table(rows))
        h.append('<h1 class="hp-title">%s</h1>' % esc(d["title"]))
        h.append('<section class="hp-why"><p class="hp-lbl">%s</p><p>%s</p></section>'
                 % (esc(self.L["text.why"]), inline(d["why"], self.page_refs)))
        if d.get("links"):
            items = "".join("<li>%s</li>" % link(ln["url"], ln["label"]) for ln in d["links"])
            h.append('<nav class="hp-links" aria-label="%s"><p class="hp-lbl">%s</p><ul>%s</ul></nav>'
                     % (esc(self.L["text.links"]), esc(self.L["text.links"]), items))
        # レビューのページの依頼したレビュー。指摘の一覧の前に、ヘッダーと同じ項目名と値の表で出す。
        if d.get("request"):
            req = d["request"]
            rows = [(self.L["text.req_" + f], inline(req[f], self.page_refs)) for f in REQUEST_FIELDS]
            h.append('<section class="hp-request"><p class="hp-lbl">%s</p>%s</section>'
                     % (esc(self.L["text.req_title"]), meta_table(rows)))
        h.append("</header>")
        return "\n".join(h)

    def bar(self):
        if not self.has_answer_part():
            return ""
        if self.answered:
            return '<p class="hp-notice">%s</p>' % esc(self.L["text.answered_notice"])
        return ('<div class="hp-bar"><p class="hp-allrec">%s</p><p class="hp-store" id="hp-store" aria-live="polite">%s</p></div>'
                % (esc(self.L["text.all_recommended"]), esc(self.L["text.store_connecting"])))

    def reply(self):
        if not self.has_answer_part() or self.answered:
            return ""
        return ('<section class="hp-reply" id="hp-reply" hidden>'
                '<h2 class="hp-sec-title">%s</h2>'
                '<textarea class="hp-reply-text" id="hp-reply-text" readonly aria-label="%s"></textarea>'
                '<div class="hp-reply-actions"><button type="button" class="hp-copy" id="hp-copy">%s</button>'
                '<span class="hp-copy-msg" id="hp-copy-msg" aria-live="polite"></span></div>'
                '</section>'
                % (esc(self.L["text.reply_title"]), esc(self.L["text.reply_title"]), esc(self.L["text.copy"])))

    # 部品 ------------------------------------------------------------------

    def sections(self):
        out = []
        for si, sec in enumerate(self.data["sections"]):
            if sec["type"] == "decisions":
                out.append(self.decisions(sec))
            elif sec["type"] == "bundle":
                out.append(self.bundle(sec, si))
            elif sec["type"] == "table":
                out.append(self.table(sec, (si,)))
            else:
                out.append(self.findings(sec))
        return "\n".join(out)

    def decisions(self, sec):
        cards = "\n".join(self.card(c, 3, self.page_refs) for c in sec["cards"])
        return ('<section class="hp-sec hp-decisions"><h2 class="hp-sec-title">%s</h2><div class="hp-cards">\n%s\n</div></section>'
                % (inline(sec["title"], self.page_refs), cards))

    def bundle(self, sec, si):
        out = ['<section class="hp-sec hp-bundle"><h2 class="hp-sec-title">%s</h2>' % inline(sec["title"], self.page_refs)]
        for gi, g in enumerate(sec["groups"]):
            gid = len(self.groups)
            src = g["source"]
            # group の中の #N と ID は group の送り元だけを使う。無ければページの送り元へは戻らない。
            # ページの中の識別子（group の選ぶ表の候補の番号）へのアンカーは、送り元に頼らないのでページのものを使う。
            refs = Refs(src, self.anchors)
            self.groups.append({"id": gid, "keys": [c["key"] for c in g["cards"]]})
            out.append('<section class="hp-group" id="hp-group-%d">' % gid)
            gs = self.L["status.answered"] if self.answered else fill(self.L["status.awaiting"], n=self.open_count(g["cards"]))
            rows = meta_rows(src, src.get("tmux"), self.L)
            rows.append((self.L["text.head_status"], '<span id="hp-group-status-%d">%s</span>' % (gid, esc(gs))))
            out.append('<h3 class="hp-group-title">%s</h3>' % inline(g["title"], refs))
            out.append(meta_table(rows))
            if "why" in g:
                out.append('<p class="hp-group-why">%s</p>' % inline(g["why"], refs))
            out.append('<div class="hp-cards">\n%s\n</div>' % "\n".join(self.card(c, 4, refs) for c in g["cards"]))
            for ti, tb in enumerate(g.get("tables", [])):
                out.append(self.table(tb, (si, gi, ti), refs, "h4"))
            out.append("</section>")
        out.append("</section>")
        return "\n".join(out)

    def card(self, c, level, refs):
        key = c["key"]
        L = self.L
        ans = self.answers.get(key) if self.answered else None
        choice = ans.get("choice") if ans else None
        note = ans.get("note", "") if ans else ""
        self.cards.append({"key": key, "options": [{"key": o["key"], "label": o["label"]} for o in c["options"]]})
        rec_label = next(o["label"] for o in c["options"] if o["key"] == c["recommend"])
        h = ['<article class="hp-card%s" id="hp-card-%s">' % (" is-locked" if self.answered else "", esc(key))]
        head = '<div class="hp-card-head">'
        tag = self.tags.get(key, c.get("tag"))
        if tag:
            head += '<span class="hp-tag">%s</span>' % esc(tag)
        head += '<h%d class="hp-card-title">%s</h%d>' % (level, inline(c["title"], refs), level)
        head += self.evidence(c.get("evidence")) + "</div>"
        h.append(head)
        # 頭（札・題）の下の中身を、ブラウザの開閉の要素で包む。開閉はブラウザが受け持ち、JS は持たない。
        # 回答済みのページでは、答えのあるカードを畳んで描く。開閉の行には、畳んだときだけ答えが見える。
        folded = self.answered and bool(choice)
        h.append('<details class="hp-fold" id="hp-fold-%s"%s><summary class="hp-fold-toggle">'
                 '<span class="hp-fold-ans" id="hp-fold-%s.ans">%s</span>'
                 '<span class="hp-fold-open">%s</span><span class="hp-fold-close">%s</span></summary>'
                 '<div class="hp-fold-body">'
                 % (esc(key), "" if folded else " open", esc(key), esc(self.folded_answer(c, choice)),
                    esc(L["text.unfold"]), esc(L["text.fold"])))
        h.append('<p class="hp-rec">%s<span class="hp-rec-choice">%s</span></p>'
                 % (self.chip("hp-chip-rec", L["recommend"]), inline(rec_label, refs)))
        # 根拠は任意。推奨に説明が要らないカードでは書かず、根拠の行も出さない。
        if "reason" in c:
            h.append('<p class="hp-reason"><span class="hp-lbl">%s</span>%s</p>' % (esc(L["text.reason"]), inline(c["reason"], refs)))
        if c.get("points"):
            h.append('<p class="hp-lbl">%s</p>%s' % (esc(L["text.points"]), self.point_list(c["points"], refs)))
        # 塊は要点の後に、カードの見出しより1段下の見出しを付けて並べる。
        for b in c.get("blocks", []):
            h.append('<div class="hp-block"><h%d class="hp-block-title">%s</h%d>%s</div>'
                     % (level + 1, inline(b["title"], refs), level + 1, self.point_list(b["points"], refs)))
        if key in self.pick_of:
            h.append(self.select_line(self.pick_of[key]))
        title_attr = esc(c["title"])
        buttons = []
        for o in c["options"]:
            pressed = "true" if choice == o["key"] else "false"
            rec = self.chip("hp-chip-rec", L["recommend"]) if o["key"] == c["recommend"] else ""
            buttons.append('<button type="button" class="hp-opt k-%s" id="hp-opt-%s.%s" aria-pressed="%s"%s>%s%s</button>'
                           % (o.get("kind", "plain"), esc(key), esc(o["key"]), pressed,
                              " disabled" if self.answered else "", esc(o["label"]), rec))
        h.append('<div class="hp-choose" role="group" aria-label="%s">%s</div>' % (title_attr, "".join(buttons)))
        if self.answered and not choice:
            h.append('<p class="hp-unanswered">%s</p>' % esc(L["text.unanswered"]))
        h.append('<textarea class="hp-note" id="hp-note-%s" placeholder="%s" aria-label="%s %s"%s>%s</textarea>'
                 % (esc(key), esc(L["text.note_placeholder"]), title_attr, esc(L["text.note_placeholder"]),
                    " disabled" if self.answered else "", esc(note)))
        h.append('<p class="hp-saved" id="hp-saved-%s" aria-live="polite"></p>' % esc(key))
        h.append("</div></details>")
        h.append("</article>")
        return "\n".join(h)

    def folded_answer(self, c, choice):
        """畳んだカードの開閉の行に出す答えの文。JS も同じ文を組み立てて書き換える（page.js の foldedAnswer）。"""
        L = self.L
        label = next((o["label"] for o in c["options"] if o["key"] == choice), L["text.unanswered"])
        text = fill(L["text.folded_answer"], label=label)
        if c["key"] in self.pick_of:
            chosen = self.chosen_rows(self.pick_of[c["key"]])
            text += "（%s）" % fill(L["text.reply_rows"], rows="、".join(chosen) if chosen else L["text.select_none"])
        return text

    def select_rule(self, p):
        L = self.L
        if p["min"] and p["min"] == p["max"]:
            return fill(L["text.select_exact"], max=p["max"])
        if p["min"]:
            return fill(L["text.select_between"], min=p["min"], max=p["max"])
        return fill(L["text.select_upto"], max=p["max"])

    def chosen_rows(self, p):
        """回答済みのページで選ばれている行の番号の並び（回答待ちのページでは空。JS が埋める）。"""
        if not self.answered:
            return []
        return [num for _, (rk, num) in sorted(p["rows"].items())
                if (self.answers.get(rk) or {}).get("choice") == PICK_CHOICE]

    def select_line(self, p):
        """選び方のカードの、選ぶ数と選んだ行の行。選んだ行は JS が書き換える。"""
        chosen = self.chosen_rows(p)
        text = fill(self.L["text.select_chosen"], n=len(chosen),
                    rows="、".join(chosen) if chosen else self.L["text.select_none"])
        return ('<p class="hp-select"><span class="hp-select-rule">%s</span>'
                '<span class="hp-select-chosen" id="hp-select-chosen-%s" aria-live="polite">%s</span></p>'
                % (esc(self.select_rule(p)), esc(p["card"]), esc(text)))

    def pick_cell(self, label, pos):
        """番号の列の欄に、行を選ぶチェックを付ける。推奨の行には推奨の札を付ける。
        行の保存の成否は、判定カードと同じ印（hp-saved-<行の key>）に JS が書く。"""
        p = self.row_pick[pos]
        rk, num = p["rows"][pos]
        checked = self.answered and (self.answers.get(rk) or {}).get("choice") == PICK_CHOICE
        rec = self.chip("hp-chip-rec", self.L["recommend"]) if num in p["recommend"] else ""
        return ('<td class="hp-no" data-label="%s"><label class="hp-pick">'
                '<input type="checkbox" class="hp-pick-box" id="hp-pick-%s" aria-label="%s %s"%s%s>'
                '<span class="hp-pick-id">%s</span></label>%s'
                '<span class="hp-saved" id="hp-saved-%s" aria-live="polite"></span></td>'
                % (esc(label), esc(rk), esc(num), esc(self.L["text.pick"]),
                   " checked" if checked else "", " disabled" if self.answered else "", esc(num), rec, esc(rk)))

    def point_list(self, points, refs):
        items = []
        for p in points:
            if isinstance(p, str):
                items.append("<li>%s</li>" % inline(p, refs))
            else:
                items.append("<li>%s%s</li>" % (inline(p["text"], refs), self.evidence(p.get("evidence"))))
        return '<ul class="hp-points">%s</ul>' % "".join(items)

    def findings(self, sec):
        L = self.L
        refs = self.page_refs
        out = ['<section class="hp-sec hp-findings"><h2 class="hp-sec-title">%s</h2>' % inline(sec["title"], refs)]
        if "lane" in sec:
            out.append('<p class="hp-lane">%s</p>' % esc(fill(L["text.lane"], lane=sec["lane"])))
        cols = (L["text.col_text"], L["text.col_severity"], L["text.col_adopted"], L["text.col_reason"])
        out.append('<div class="hp-table-wrap"><table class="hp-table"><thead><tr>%s</tr></thead><tbody>'
                   % "".join("<th>%s</th>" % esc(c) for c in cols))
        for it in sec["items"]:
            out.append('<tr><td data-label="%s">%s%s</td><td data-label="%s">%s</td><td data-label="%s">%s</td><td data-label="%s">%s</td></tr>'
                       % (esc(cols[0]), inline(it["text"], refs), self.evidence(it.get("evidence")),
                          esc(cols[1]), self.chip("hp-sev-" + it["severity"], L["severity." + it["severity"]]),
                          esc(cols[2]), self.chip("hp-ad-" + it["adopted"], L["adopted." + it["adopted"]]),
                          esc(cols[3]), inline(it["reason"], refs)))
        out.append("</tbody></table></div></section>")
        return "\n".join(out)

    def table(self, sec, tpos, refs=None, heading="h2"):
        """列と行をデータで書く表。指摘の一覧と同じ hp-table で描き、幅の狭い画面では行を積む。
        tpos は表の位置（ページの表は (部品の順,)、束の group の表は (部品の順, group の順, 表の順)）。"""
        refs = refs or self.page_refs
        cols = [(c["key"], c["label"], c.get("type", "text")) for c in sec["columns"]]
        out = ['<section class="hp-sec hp-tablesec"><%s class="hp-sec-title">%s</%s>' % (heading, inline(sec["title"], refs), heading)]
        out.append('<div class="hp-table-wrap"><table class="hp-table"><thead><tr>%s</tr></thead><tbody>'
                   % "".join("<th>%s</th>" % esc(label) for _, label, _ in cols))
        for ri, row in enumerate(sec["rows"]):
            pos = tpos + (ri,)
            cells = []
            for key, label, kind in cols:
                v = row.get(key, "")
                if kind == "no" and pos in self.row_pick:
                    cells.append(self.pick_cell(label, pos))
                elif kind == "no":
                    cells.append('<td class="hp-no" data-label="%s">%s</td>' % (esc(label), esc(self.numbers.get(pos, v))))
                elif kind == "ref":
                    items = [v] if isinstance(v, str) else v
                    body = ('<span class="hp-refs">%s</span>' % "".join(refs.ref_link(r) for r in items)) if items else ""
                    cells.append('<td class="hp-ref-cell" data-label="%s">%s</td>' % (esc(label), body))
                elif isinstance(v, dict):
                    cells.append('<td data-label="%s">%s%s</td>' % (esc(label), inline(v["text"], refs), self.evidence(v.get("evidence"))))
                else:
                    cells.append('<td data-label="%s">%s</td>' % (esc(label), inline(v, refs)))
            rid = ' id="%s"' % row_id(pos) if pos in self.numbers else ""
            out.append("<tr%s>%s</tr>" % (rid, "".join(cells)))
        out.append("</tbody></table></div></section>")
        return "\n".join(out)


def render(data, labels, now, tmux, body=None, words=None):
    """検証を通ったデータから、artifact に公開する断片を返す。words は validate と同じ識別子の接頭辞。"""
    template = read_text(TEMPLATE, "型（template.html）")
    for slot in TEMPLATE_SLOTS:
        if template.count("{{%s}}" % slot) != 1:
            raise LoadError("型（%s）に {{%s}} がちょうど1つあるべき所が %d 個ある"
                            % (TEMPLATE, slot, template.count("{{%s}}" % slot)))
    r = Renderer(data, labels, now, tmux, words if words is not None else load_words(DEFAULT_GLOSSARY))
    header = r.header()
    sections = r.sections()  # ここでカードと group を集める
    # 答える部品の無いページには、保存のコード（page.js）とそれが読むデータを入れない。
    # page.js はカードが無いと何もしないので振る舞いは変わらず、ページの中に保存先を使うコードが残らない。
    scripts = ""
    if r.has_answer_part():
        page_data = {
            "title": data["title"],
            "time": r.time,
            "status": data["status"],
            "labels": labels,
            "cards": r.cards,
            "groups": r.groups,
            "picks": [{"card": p["card"], "max": p["max"], "min": p["min"],
                       "rows": [{"key": rk, "id": num} for _, (rk, num) in sorted(p["rows"].items())]} for p in r.picks],
            "answers": data.get("answers") if r.answered else None,
        }
        scripts = ('<script type="application/json" id="hp-data">%s</script>\n<script>\n%s\n</script>'
                   % (embed_json(page_data), read_text(JS, "JS（page.js）").rstrip("\n")))
    values = {
        "title": esc(data["title"]),
        "css": read_text(CSS, "CSS（page.css）").rstrip("\n"),
        "purpose": esc(KIND_PURPOSE[data["kind"]]),
        "status": esc(data["status"]),
        "header": header,
        "bar": r.bar(),
        "body": (body or "").rstrip("\n"),
        "sections": sections,
        "reply": r.reply(),
        "scripts": scripts,
    }
    return SLOT_RE.sub(lambda m: values[m.group(1)], template)


STANDALONE_HEAD = ('<!doctype html>\n<html lang="ja">\n<head>\n<meta charset="utf-8">\n'
                   '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
                   '</head>\n<body>\n')
STANDALONE_TAIL = "</body>\n</html>\n"


def standalone(fragment):
    """断片を、手元のブラウザで開ける完全な文書で包む。中身は変えない。"""
    return STANDALONE_HEAD + fragment + STANDALONE_TAIL


# 完成した HTML の外部の読み込み。Google Fonts だけを許す（--body の断片から入ったものを含めて数える）。
# リンク（<a>・<area>）を除くすべての要素の、読み込みに使う属性と、CSS の中の絶対 URL を見る。
ALLOWED_LOADS = ("https://fonts.googleapis.com/", "https://fonts.gstatic.com/")
_TAG_RE = re.compile(r"""<([a-zA-Z][a-zA-Z0-9:-]*)\b((?:[^>"']|"[^"]*"|'[^']*')*)>""")
_NOT_LOADS = ("a", "area")
_LOAD_ATTR_RE = re.compile(r"""(?<![\w:-])(xlink:href|href|src|srcset|imagesrcset|data|poster|background)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))""", re.I)
_STYLE_BLOCK_RE = re.compile(r"<style\b[^>]*>(.*?)</style>", re.I | re.S)
_STYLE_ATTR_RE = re.compile(r"""(?<![\w:-])style\s*=\s*(?:"([^"]*)"|'([^']*)')""", re.I)
_CSS_URL_RE = re.compile(r"""https?://[^\s"'()<>;,]+|(?<![:/\w])//[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+[^\s"'()<>;,]*""", re.I)


def _external(url):
    u = html.unescape(url).strip().lower()
    if u.startswith("http://") or u.startswith("https://") or u.startswith("//"):
        return not u.startswith(ALLOWED_LOADS)
    return False


def _candidates(attr, value):
    if attr.lower() in ("srcset", "imagesrcset"):
        return [c.strip().split()[0] for c in html.unescape(value).split(",") if c.strip()]
    return [value]


def external_loads(fragment):
    """許していない外部の読み込みを並べる。[(規則, 場所, 理由)] の形で返す。"""
    found = []
    for m in _TAG_RE.finditer(fragment):
        tag = m.group(1).lower()
        if tag in _NOT_LOADS:
            continue
        for a in _LOAD_ATTR_RE.finditer(m.group(2)):
            value = next(g for g in a.groups()[1:] if g is not None)
            for url in _candidates(a.group(1), value):
                if _external(url):
                    found.append(("<%s %s>" % (tag, a.group(1).lower()), url))
    css = [m.group(1) for m in _STYLE_BLOCK_RE.finditer(fragment)]
    css += [m.group(1) or m.group(2) for m in _STYLE_ATTR_RE.finditer(fragment)]
    for block in css:
        for m in _CSS_URL_RE.finditer(html.unescape(block)):
            if _external(m.group(0)):
                found.append(("CSS の中の URL", m.group(0)))
    return [("E-B1", "html", "許していない外部の読み込みがある（%s: %s）。読み込めるのは Google Fonts だけである" % f)
            for f in found]


# ---------------------------------------------------------------- 送り元の補助


def _https_remote(url):
    url = url.strip()
    if url.endswith(".git"):
        url = url[:-4]
    m = re.match(r"^https?://(?:[^@/]+@)?([^/]+)/(.+)$", url)
    if m:
        return "https://%s/%s" % (m.group(1), m.group(2))
    m = re.match(r"^ssh://(?:[^@/]+@)?([^/:]+)(?::\d+)?/(.+)$", url)
    if m:
        return "https://%s/%s" % (m.group(1), m.group(2))
    m = re.match(r"^(?:[^@/]+@)?([^/:]+):(?!/)(.+)$", url)
    if m:
        return "https://%s/%s" % (m.group(1), m.group(2))
    return None


def _git(directory, *args):
    try:
        p = subprocess.run(["git", "-C", directory] + list(args), stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, universal_newlines=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    return p.stdout.strip() if p.returncode == 0 else None


def source_from_env(git_dir, use_tmux):
    """作ったセッションの送り元を引く。返すのは (送り元の辞書, 引けなかった理由の並び)。"""
    src = {}
    notes = []
    if git_dir:
        top = _git(git_dir, "rev-parse", "--show-toplevel")
        if top is None:
            notes.append("%s から git の作業ツリーを引けない" % git_dir)
        else:
            remote = _git(git_dir, "remote", "get-url", "origin")
            url = _https_remote(remote) if remote else None
            name = url.rstrip("/").rsplit("/", 1)[-1] if url else os.path.basename(top)
            src["repo"] = name
            if url:
                src["repo_url"] = url
            else:
                notes.append("origin の URL を https の形に直せないので repo_url を省いた")
            branch = _git(git_dir, "branch", "--show-current")
            if branch:
                src["branch"] = branch
            else:
                notes.append("いまのブランチを引けない（detached など）ので branch を省いた")
    if use_tmux:
        tmux, why = tmux_from_env()
        if tmux:
            src["tmux"] = tmux
        else:
            notes.append("tmux の項目を省いた: " + why)
    return src, notes


# ---------------------------------------------------------------- コマンド


def report(errors):
    for line in format_errors(errors):
        print(line, file=sys.stderr)
    print("誤りが %d 件ある。直してから作り直す。" % len(errors), file=sys.stderr)


def cmd_check(args):
    load_glossary(args.glossary)
    words = load_words(args.glossary)
    data = load_data(args.data)
    body = read_text(args.body, "--body の本文") if args.body else None
    if args.answers:
        collected = parse_json(read_text(args.answers, "回収した答え"), "回収した答え（%s）" % args.answers)
        errors, ignored = check_collected(data, collected, words=words, body=body)
        if ignored:
            print("ページに無い key %d 件は見なかった（前の回収で表へ移したカードの答えなど）" % ignored, file=sys.stderr)
    else:
        errors = validate(data, words=words, body=body)
    if errors:
        report(errors)
        return 1
    print("誤りは無い: %s" % args.data, file=sys.stderr)
    return 0


def cmd_build(args):
    labels = load_glossary(args.glossary)
    words = load_words(args.glossary)
    data = load_data(args.data)
    body = read_text(args.body, "--body の本文") if args.body else None
    now = parse_now(args.now)
    errors = validate(data, words=words, body=body)
    if errors:
        report(errors)
        return 1
    tmux = data["source"].get("tmux")
    if tmux is None and args.tmux == "auto":
        tmux, why = tmux_from_env()
        if tmux is None:
            print("送り元の tmux の項目を省いた: %s" % why, file=sys.stderr)
    fragment = render(data, labels, now, tmux, body, words)
    errors = external_loads(fragment)
    if errors:
        report(errors)
        return 1
    out = standalone(fragment) if args.standalone else fragment
    try:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(out)
    except OSError as e:
        raise LoadError("書き出し先（%s）に書けない: %s" % (args.out, e))
    print("書いた: %s（%d バイト・%s）" % (args.out, len(out.encode("utf-8")),
                                        "手元で開く完全な文書" if args.standalone else "artifact に公開する断片"),
          file=sys.stderr)
    return 0


def cmd_source(args):
    src, notes = source_from_env(args.git, args.tmux == "auto")
    for n in notes:
        print(n, file=sys.stderr)
    print(json.dumps(src, ensure_ascii=False, indent=2))
    return 0


def make_parser():
    ap = argparse.ArgumentParser(prog="build.py", description="データ（JSON）から人向けのページを作る。")
    sub = ap.add_subparsers(dest="cmd")
    pc = sub.add_parser("check", help="データを検証するだけで、HTML は書かない")
    pc.add_argument("data", help="ページのデータ（JSON）")
    pc.add_argument("--body", help="読み物の本文の HTML の断片（sections が空でよくなる）")
    pc.add_argument("--answers", help="回収した答えの JSON（保存先の文書を answers と同じ形に写したもの）。ページにある key を見て、ページに無い key は数だけを出す")
    pc.add_argument("--glossary", default=DEFAULT_GLOSSARY, help=argparse.SUPPRESS)
    pb = sub.add_parser("build", help="データを検証し、通ったときだけ HTML を書く")
    pb.add_argument("data", help="ページのデータ（JSON）")
    pb.add_argument("-o", "--out", required=True, help="書き出す HTML のパス")
    pb.add_argument("--standalone", action="store_true", help="手元のブラウザで開く完全な文書にする（既定は artifact に公開する断片）")
    pb.add_argument("--body", help="ヘッダーの下に差し込む本文の HTML の断片（信頼したコードとして扱う）")
    pb.add_argument("--tmux", choices=("auto", "off"), default="auto",
                    help="データに source.tmux が無いとき、作ったセッションのペインから引くか（既定 auto）")
    pb.add_argument("--now", help="版の時刻（時差つきの ISO 8601。既定は走らせた時刻）")
    pb.add_argument("--glossary", default=DEFAULT_GLOSSARY, help=argparse.SUPPRESS)
    ps = sub.add_parser("source", help="作ったセッションの送り元の JSON を出す")
    ps.add_argument("--git", help="repo・repo_url・branch を引く作業ツリーのディレクトリ")
    ps.add_argument("--tmux", choices=("auto", "off"), default="auto", help="tmux の項目を引くか（既定 auto）")
    return ap


def main(argv=None):
    ap = make_parser()
    args = ap.parse_args(argv)
    if not args.cmd:
        ap.print_help(sys.stderr)
        return 2
    commands = {"check": cmd_check, "build": cmd_build, "source": cmd_source}
    try:
        return commands[args.cmd](args)
    except LoadError as e:
        print("読み込めない: %s" % e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())

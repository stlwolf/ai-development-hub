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
PAGE_KINDS = ("confirm", "approve", "pick", "map", "bundle", "review")
KIND_PURPOSE = {"confirm": "decide", "approve": "decide", "pick": "decide", "map": "grasp",
                "bundle": "decide", "review": "review"}
# 表に番号の列（型 no）を置ける種別。
ROW_NUMBER_KINDS = ("pick", "map")
# --body の本文を置ける種別。本文は型の上でいつも部品の上に出るので、部品の上にあっても読む順を壊さない種別だけにする。
BODY_KINDS = ("approve", "map", "bundle", "review")
# 種別ごとのページの中の識別子: (カードの札の接頭辞の key, 番号の列の接頭辞の key, 書かなければ番号を振るか)。
# key は用語集の「識別子の接頭辞」の表の key で、語は用語集が持つ。ここに無い種別は識別子を定義しない。
KIND_IDS = {"approve": ("prefix.question", None, True),
            "pick": (None, "prefix.candidate", True),
            "map": (None, "prefix.item", True)}
# 認識合わせのカードの札は、確かめる対象の issue の形（#N・owner/repo#N）だけを受け付ける。
ISSUE_TAG_RE = re.compile(r"(?:#\d{1,7}|[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}#\d{1,7})\Z")
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
}
GLOSSARY_SECTION = "## 札の言葉と固定の文"
# 用語集の「識別子の接頭辞」の表に要る key。語は札と番号の列の値の形を決める（受け付ける値も変わる）。
# 「札の言葉と固定の文」の表とは分けて持つ。そちらの言葉は答える部品のあるページに丸ごと埋め込まれるので、
# ここの語を混ぜると既存のページの出力が変わり、JS が使わない語をページに持ち込むためである。
WORD_KEYS = ("prefix.question", "prefix.candidate", "prefix.item", "tag.approval")
WORDS_SECTION = "## 識別子の接頭辞"
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
    """用語集の「識別子の接頭辞」の表を読み、key から語への辞書を返す。
    語は文字（英字・漢字・かな）だけからなり、互いに重ならず、どれもほかの語の頭に当たらない。
    記号と数字を許さないので、ページの中の識別子（Q2）は外部の課題管理の ID（OPS-41）・#N・PR #N と同じ文字列にならない。"""
    words, problems = _glossary_table(path, WORDS_SECTION)
    for key in words:
        if key not in WORD_KEYS:
            problems.append('知らない key "%s" がある' % key)
    for key in WORD_KEYS:
        if key not in words:
            problems.append('key "%s" が無い' % key)
        elif not words[key] or not words[key].isalpha():
            problems.append('key "%s" の語 "%s" が文字だけからなっていない（数字・空白・記号を含めない）' % (key, words[key]))
    found = [(k, words[k]) for k in WORD_KEYS if words.get(k)]
    for i, (ka, a) in enumerate(found):
        for kb, b in found[i + 1:]:
            if a.startswith(b) or b.startswith(a):
                problems.append('key "%s" の語 "%s" と key "%s" の語 "%s" が重なるか、片方がもう片方の頭に当たる' % (ka, a, kb, b))
    if problems:
        raise LoadError("用語集（%s）の識別子の接頭辞が壊れている: %s" % (path, "; ".join(problems)))
    return words


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


class Validator:
    """データの誤りを全部集める。1つの誤りから同じ原因の誤りを重ねて出さない。"""

    def __init__(self, has_body, words):
        self.has_body = has_body
        self.words = words
        self.errors = []
        self.card_paths = {}   # カードの key -> 最初に現れた場所
        self.card_options = {}  # カードの key -> 選択肢の key の並び
        # ページの送り元からリンクにできるもの（repo_url があるか・登録した接頭辞）。
        # 送り元に誤りがあれば None にし、表の識別子をリンクにできるかの判定（E-L1）を重ねて出さない。
        self.page_links = None
        # 表の部品の場所 -> 列の [(key, type)]。列に誤りがあれば None（種別の判定で番号の列を数えない）。
        self.tables = {}

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
                 ("links", "answers"), replaced=REPLACED_FIELDS)
        if "title" in data:
            self.text("title", data["title"], "E-H1")
        if "why" in data:
            self.text("why", data["why"], "E-H1")
        kind = None
        if "kind" in data and self.enum("kind", data["kind"], PAGE_KINDS, "E-H3"):
            kind = data["kind"]
        if "status" in data:
            self.enum("status", data["status"], STATUSES, "E-H3")
        if "source" in data:
            before = len(self.errors)
            self.source("source", data["source"])
            if len(self.errors) == before:
                src = data["source"]
                self.page_links = ("repo_url" in src, {t["prefix"] for t in src.get("trackers", [])})
        if "links" in data:
            self.links("links", data["links"])
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
                # 種別の部品は、種別が決まった値で、部品がどれも読めたときだけ見る。
                # 部品も本文も無ければ E-S1 だけを出す（同じ原因の誤りを重ねない）。
                if kind is not None and sections_readable and (secs or self.has_body):
                    self.kind_parts(kind, secs)
                if kind is not None:
                    self.identifiers(kind, secs)
        status = data.get("status")
        if status == "awaiting" and sections_readable and not has_answer_part:
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
            if nos and kind not in ROW_NUMBER_KINDS:
                self.add("E-K2", "%s.columns[%d]" % (paths[i], nos[0]), "種別 %s の表には番号の列（type no）を置かない" % kind)
            elif len(nos) > 1:
                self.add("E-K2", "%s.columns[%d]" % (paths[i], nos[1]), "番号の列（type no）は1つの表に1列までにする")
        getattr(self, "kind_" + kind)(types, paths, secs)

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
        for i in allowed:
            if types[i] == "table" and i < dec[-1]:
                self.add("E-K3", paths[i], "表は判定カードの節のあとに置く")

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
        self.only_one(b, paths, "判断待ちの束の部品")

    def kind_review(self, types, paths, secs):
        allowed = self.kind_allowed("review", types, paths, ("findings", "table", "decisions"))
        f = [i for i in allowed if types[i] == "findings"]
        if not f:
            self.add("E-K1", "sections", "レビューのページには指摘の一覧（findings）が1つ以上要る")
        elif f[0] != allowed[0]:
            self.add("E-K3", paths[allowed[0]], "指摘の一覧を部品の先頭に置き、表と判定カードはそのあとに置く")

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
        defined = {}
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
        if row_key:
            items = []
            for i, sec in enumerate(secs):
                path = "sections[%d]" % i
                cols = self.tables.get(path) if isinstance(sec, dict) and sec.get("type") == "table" else None
                no = [k for k, ct in (cols or []) if ct == "no"]
                if not no or not isinstance(sec.get("rows"), list):
                    continue
                for r, row in enumerate(sec["rows"]):
                    if not isinstance(row, dict):
                        continue
                    v = row.get(no[0], "")
                    if isinstance(v, str):
                        items.append(("%s.rows[%d].%s" % (path, r, no[0]), v or None))
            self.numbered(items, self.words[row_key], auto, "番号の列の値", defined)

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
        for path, v in good:
            if v in defined:
                self.add("E-I2", path, '識別子 "%s" が %s と重なる' % (v, defined[v]))
            else:
                defined[v] = path

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

    def section(self, path, sec):
        """部品を1つ見て、その type を返す。読めなかった（オブジェクトでない・知らない type）なら None を返す。"""
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
            if self.obj(path, sec, ("type", "title", "cards")):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                if "cards" in sec:
                    self.cards(join(path, "cards"), sec["cards"])
        elif t == "bundle":
            if self.obj(path, sec, ("type", "title", "groups")):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                if "groups" in sec:
                    gp = join(path, "groups")
                    if self.array(gp, sec["groups"], "E-S1", "group が1つも無い"):
                        for i, g in enumerate(sec["groups"]):
                            self.group("%s[%d]" % (gp, i), g)
        elif t == "table":
            if self.obj(path, sec, ("type", "title", "columns", "rows")):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                cols = self.columns(join(path, "columns"), sec["columns"]) if "columns" in sec else None
                self.tables[path] = cols
                if "rows" in sec:
                    self.rows(join(path, "rows"), sec["rows"], cols)
        else:
            if self.obj(path, sec, ("type", "title", "items"), ("lane",)):
                if "title" in sec:
                    self.text(join(path, "title"), sec["title"], "E-S1")
                if "lane" in sec:
                    self.text(join(path, "lane"), sec["lane"], "E-S2")
                if "items" in sec:
                    ip = join(path, "items")
                    if self.array(ip, sec["items"], "E-S1", "指摘が1件も無い"):
                        for i, it in enumerate(sec["items"]):
                            self.finding("%s[%d]" % (ip, i), it)
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
        issue = REF_ISSUE_RE.match(r)
        tracker = None if issue else REF_TRACKER_RE.match(r)
        if not issue and not tracker:
            self.add("E-L1", path, '"%s" は識別子の形（#N・PR #N・<接頭辞>-<数字>）でない' % r)
            return
        if self.page_links is None:
            return
        has_repo_url, prefixes = self.page_links
        if issue and not has_repo_url:
            self.add("E-L1", path, '"%s" をリンクにする repo_url が送り元に無い' % r)
        elif tracker and tracker.group(1) not in prefixes:
            self.add("E-L1", path, '"%s" の接頭辞 "%s" が送り元の trackers に無い' % (r, tracker.group(1)))

    def group(self, path, g):
        if not self.obj(path, g, ("source", "title", "cards"), ("why",)):
            return
        if "source" in g:
            self.source(join(path, "source"), g["source"])
        if "title" in g:
            self.text(join(path, "title"), g["title"], "E-S1")
        if "why" in g:
            self.text(join(path, "why"), g["why"], "E-H1")
        if "cards" in g:
            self.cards(join(path, "cards"), g["cards"])

    def cards(self, path, cards):
        if self.array(path, cards, "E-S1", "カードが1枚も無い"):
            for i, c in enumerate(cards):
                self.card("%s[%d]" % (path, i), c)

    def card(self, path, c):
        if not self.obj(path, c, ("key", "title", "recommend", "options"),
                        ("reason", "tag", "points", "blocks", "evidence")):
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
            if "label" in o:
                self.text(join(op, "label"), o["label"], "E-C5")
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


def validate(data, has_body=False, words=None):
    """データを検証し、誤りの並び [(規則の番号, 場所, 理由)] を返す。空なら誤りは無い。
    words は用語集の識別子の接頭辞（load_words の結果）。省けば既定の用語集から読む。"""
    v = Validator(has_body, words if words is not None else load_words(DEFAULT_GLOSSARY))
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
LINK_PATTERN = r"(?P<url>https?://[^" + _URL_STOP + r"]+)|(?P<issue>(?<![A-Za-z0-9_])#(?P<num>\d{1,7})(?![A-Za-z0-9_]))"
LINK_RE = re.compile(LINK_PATTERN)
TRACKER_PATTERN = r"|(?P<tracker>(?<![A-Za-z0-9_-])(?P<prefix>%s)-\d+(?![A-Za-z0-9_-]))"
URL_TRAIL = ".,;:!?)]}"

# JSON をページに埋め込むとき、要素を閉じたり行を分けたりしうる文字を \u の形に置き換える。
_JSON_UNSAFE = ("<", ">", "&", chr(0x2028), chr(0x2029))


def esc(s):
    return html.escape(str(s), quote=True)


def link(url, text):
    return '<a href="%s" target="_blank" rel="noopener">%s</a>' % (esc(url), esc(text))


def issue_url(repo_url, num):
    return "%s/issues/%s" % (repo_url.rstrip("/"), num)


def branch_url(repo_url, branch):
    return "%s/tree/%s" % (repo_url.rstrip("/"), quote(branch, safe="/"))


class Refs:
    """文字列の中の #N と外部の課題管理の ID をリンクにするための、いちばん近い送り元の情報。"""

    def __init__(self, src):
        self.repo_url = src.get("repo_url")
        self.trackers = {t["prefix"]: t["url"] for t in src.get("trackers", [])}
        pattern = LINK_PATTERN
        if self.trackers:
            # 長い接頭辞を先に置き、短い接頭辞が長い接頭辞の頭に当たらないようにする。
            names = sorted(self.trackers, key=lambda p: (-len(p), p))
            pattern += TRACKER_PATTERN % "|".join(re.escape(p) for p in names)
        self.link_re = re.compile(pattern)

    def tracker_url(self, ident, prefix):
        return self.trackers[prefix].replace(TRACKER_ID_PLACEHOLDER, quote(ident, safe=""))

    def ref_link(self, ref):
        """表の識別子の列の値1つ（検証を通ったもの）をリンクにする。表示の文字は書いたまま残す。"""
        m = REF_ISSUE_RE.match(ref)
        if m:
            return link(issue_url(self.repo_url, m.group(1)), ref)
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
        elif m.group("issue"):
            if refs.repo_url:
                out.append(link(issue_url(refs.repo_url, m.group("num")), m.group("issue")))
            else:
                out.append(esc(m.group("issue")))
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


def assign_numbers(data, words):
    """検証を通ったデータの、出す札（カードの key -> 札）と番号の列の値（(部品の順, 行の順) -> 値）を返す。
    書かれていなければ、種別の接頭辞とページの中の順（問いのカードの順・番号の列のある行の順）から振る。"""
    card_key, row_key, _ = KIND_IDS.get(data["kind"], (None, None, False))
    tags, numbers = {}, {}
    if card_key:
        approval = words["tag.approval"] if data["kind"] == "approve" else None
        questions = [c for sec in data["sections"] if sec["type"] == "decisions" for c in sec["cards"]
                     if not (approval and c.get("tag") == approval)]
        for i, c in enumerate(questions, 1):
            tags[c["key"]] = c.get("tag") or "%s%d" % (words[card_key], i)
    if row_key:
        n = 0
        for si, sec in enumerate(data["sections"]):
            no = [c["key"] for c in sec["columns"] if c.get("type") == "no"] if sec["type"] == "table" else []
            if not no:
                continue
            for ri, row in enumerate(sec["rows"]):
                n += 1
                numbers[(si, ri)] = row.get(no[0]) or "%s%d" % (words[row_key], n)
    return tags, numbers


class Renderer:
    def __init__(self, data, labels, now, tmux, words):
        self.data = data
        self.L = labels
        self.tags, self.numbers = assign_numbers(data, words)
        self.time = format_time(now)
        self.tmux = tmux
        self.page_refs = Refs(data["source"])
        self.answered = data["status"] == "answered"
        self.answers = data.get("answers") or {}
        self.cards = []   # JS に渡すカード
        self.groups = []  # JS に渡す group

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
                out.append(self.bundle(sec))
            elif sec["type"] == "table":
                out.append(self.table(sec, si))
            else:
                out.append(self.findings(sec))
        return "\n".join(out)

    def decisions(self, sec):
        cards = "\n".join(self.card(c, 3, self.page_refs) for c in sec["cards"])
        return ('<section class="hp-sec hp-decisions"><h2 class="hp-sec-title">%s</h2><div class="hp-cards">\n%s\n</div></section>'
                % (inline(sec["title"], self.page_refs), cards))

    def bundle(self, sec):
        out = ['<section class="hp-sec hp-bundle"><h2 class="hp-sec-title">%s</h2>' % inline(sec["title"], self.page_refs)]
        for g in sec["groups"]:
            gid = len(self.groups)
            src = g["source"]
            # group の中の #N と ID は group の送り元だけを使う。無ければページの送り元へは戻らない。
            refs = Refs(src)
            self.groups.append({"id": gid, "keys": [c["key"] for c in g["cards"]]})
            out.append('<section class="hp-group" id="hp-group-%d">' % gid)
            gs = self.L["status.answered"] if self.answered else fill(self.L["status.awaiting"], n=self.open_count(g["cards"]))
            rows = meta_rows(src, src.get("tmux"), self.L)
            rows.append((self.L["text.head_status"], '<span id="hp-group-status-%d">%s</span>' % (gid, esc(gs))))
            out.append('<h3 class="hp-group-title">%s</h3>' % inline(g["title"], refs))
            out.append(meta_table(rows))
            if "why" in g:
                out.append('<p class="hp-group-why">%s</p>' % inline(g["why"], refs))
            out.append('<div class="hp-cards">\n%s\n</div></section>'
                       % "\n".join(self.card(c, 4, refs) for c in g["cards"]))
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
        h.append("</article>")
        return "\n".join(h)

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

    def table(self, sec, si):
        """列と行をデータで書く表。指摘の一覧と同じ hp-table で描き、幅の狭い画面では行を積む。"""
        refs = self.page_refs
        cols = [(c["key"], c["label"], c.get("type", "text")) for c in sec["columns"]]
        out = ['<section class="hp-sec hp-tablesec"><h2 class="hp-sec-title">%s</h2>' % inline(sec["title"], refs)]
        out.append('<div class="hp-table-wrap"><table class="hp-table"><thead><tr>%s</tr></thead><tbody>'
                   % "".join("<th>%s</th>" % esc(label) for _, label, _ in cols))
        for ri, row in enumerate(sec["rows"]):
            cells = []
            for key, label, kind in cols:
                v = row.get(key, "")
                if kind == "no":
                    cells.append('<td data-label="%s">%s</td>' % (esc(label), esc(self.numbers.get((si, ri), v))))
                elif kind == "ref":
                    items = [v] if isinstance(v, str) else v
                    body = ('<span class="hp-refs">%s</span>' % "".join(refs.ref_link(r) for r in items)) if items else ""
                    cells.append('<td class="hp-ref-cell" data-label="%s">%s</td>' % (esc(label), body))
                elif isinstance(v, dict):
                    cells.append('<td data-label="%s">%s%s</td>' % (esc(label), inline(v["text"], refs), self.evidence(v.get("evidence"))))
                else:
                    cells.append('<td data-label="%s">%s</td>' % (esc(label), inline(v, refs)))
            out.append("<tr>%s</tr>" % "".join(cells))
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
    if args.body:
        read_text(args.body, "--body の本文")
    errors = validate(data, has_body=bool(args.body), words=words)
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
    errors = validate(data, has_body=body is not None, words=words)
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

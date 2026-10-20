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
PURPOSES = ("decide", "grasp", "review")
STATUSES = ("awaiting", "answered", "live")
EVIDENCE = ("verified", "sourced", "guess")
SEVERITIES = ("high", "mid", "low")
ADOPTIONS = ("adopted", "partial", "rejected")
KINDS = ("go", "fix", "warn", "no")
SECTION_TYPES = ("decisions", "bundle", "findings", "table")
ANSWER_SECTION_TYPES = ("decisions", "bundle")
COLUMN_TYPES = ("text", "ref")

# カードと選択肢の key。db の doc id が許す文字より狭い、このスキルの決まり。
# match（先頭から）で使い、終わりは \Z で固定する（$ は末尾の改行の前でも合うので使わない）。
KEY_RE = re.compile(r"[a-z][a-z0-9_-]{0,63}\Z")
URL_RE = re.compile(r"https?://\S+\Z")

# 外部の課題管理の ID は <接頭辞>-<数字> の形に固定する。接頭辞は送り元の trackers に登録したものだけを使う。
TRACKER_PREFIX_RE = re.compile(r"[A-Z][A-Z0-9]{0,9}\Z")
TRACKER_ID_PLACEHOLDER = "{id}"
# 表の識別子の列が受け付ける形。#N の桁は本文の変換（LINK_RE）と同じ 1〜7 桁にそろえる。
REF_ISSUE_RE = re.compile(r"(?:PR )?#(\d{1,7})\Z")
REF_TRACKER_RE = re.compile(r"([A-Z][A-Z0-9]{0,9})-(\d{1,9})\Z")

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


def load_glossary(path):
    """用語集の「札の言葉と固定の文」の表を読み、key から言葉への辞書を返す。"""
    lines = read_text(path, "用語集").splitlines()
    try:
        start = lines.index(GLOSSARY_SECTION)
    except ValueError:
        raise LoadError("用語集（%s）に見出し「%s」が無い" % (path, GLOSSARY_SECTION[3:]))
    labels = {}
    problems = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        m = GLOSSARY_ROW_RE.match(line)
        if not m:
            continue
        key, word = m.group(1), m.group(2)
        if key in labels:
            problems.append('key "%s" が2回ある' % key)
            continue
        labels[key] = word
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

    def __init__(self, has_body):
        self.has_body = has_body
        self.errors = []
        self.card_paths = {}   # カードの key -> 最初に現れた場所
        self.card_options = {}  # カードの key -> 選択肢の key の並び
        # ページの送り元からリンクにできるもの（repo_url があるか・登録した接頭辞）。
        # 送り元に誤りがあれば None にし、表の識別子をリンクにできるかの判定（E-L1）を重ねて出さない。
        self.page_links = None

    def add(self, code, path, msg):
        self.errors.append((code, path, msg))

    # 形の決まり --------------------------------------------------------

    def obj(self, path, val, required, optional=()):
        """オブジェクトかを見て、知らない項目と足りない項目を出す。型が違えば下を見ない。"""
        if not isinstance(val, dict):
            self.add("E-F3", path, "オブジェクトであるべき所が%sである" % type_name(val))
            return False
        for k in val:
            if k not in required and k not in optional:
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
        self.obj("$", data, ("format", "title", "purpose", "status", "why", "source", "sections"),
                 ("links", "answers"))
        if "title" in data:
            self.text("title", data["title"], "E-H1")
        if "why" in data:
            self.text("why", data["why"], "E-H1")
        if "purpose" in data:
            self.enum("purpose", data["purpose"], PURPOSES, "E-H3")
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
                    kind = self.section("sections[%d]" % i, sec)
                    if kind is None:
                        sections_readable = False
                    elif kind in ANSWER_SECTION_TYPES:
                        has_answer_part = True
        status = data.get("status")
        if status == "awaiting" and sections_readable and not has_answer_part:
            self.add("E-P2", "status", "awaiting（回答待ち）なのに、答える部品（decisions か bundle）が無い")
        if "answers" in data and status in STATUSES and status != "answered":
            self.add("E-P2", "answers", "answers があるのに、status が answered でない")
        if status == "answered" and "answers" not in data:
            self.add("E-P2", "answers", "status が answered なのに、回収した答え（answers）が無い")
        if "answers" in data:
            self.answers("answers", data["answers"])

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
        """表の行を見る。列が読めないとき（cols が None）は、行の key と値を見ない（同じ原因の誤りを重ねない）。"""
        if not self.array(path, rows, "E-S1", "行が1つも無い") or cols is None:
            return
        keys = tuple(k for k, _ in cols)
        for i, row in enumerate(rows):
            rp = "%s[%d]" % (path, i)
            if not self.obj(rp, row, keys):
                continue
            for k, kind in cols:
                if k in row:
                    self.cell(join(rp, k), row[k], kind)

    def cell(self, path, v, kind):
        if kind == "ref":
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
        """表の識別子の列の値1つが、リンクにできる識別子かを見る。送り元に誤りがあれば判定しない。"""
        if self.page_links is None:
            return
        has_repo_url, prefixes = self.page_links
        if REF_ISSUE_RE.match(r):
            if not has_repo_url:
                self.add("E-L1", path, '"%s" をリンクにする repo_url が送り元に無い' % r)
            return
        m = REF_TRACKER_RE.match(r)
        if m:
            if m.group(1) not in prefixes:
                self.add("E-L1", path, '"%s" の接頭辞 "%s" が送り元の trackers に無い' % (r, m.group(1)))
            return
        self.add("E-L1", path, '"%s" は識別子の形（#N・PR #N・<接頭辞>-<数字>）でない' % r)

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
        if not self.obj(path, c, ("key", "title", "recommend", "reason", "options"),
                        ("tag", "points", "evidence")):
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


def validate(data, has_body=False):
    """データを検証し、誤りの並び [(規則の番号, 場所, 理由)] を返す。空なら誤りは無い。"""
    v = Validator(has_body)
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
TRACKER_PATTERN = r"|(?P<tracker>(?<![A-Za-z0-9_-])(?P<prefix>%s)-\d{1,9}(?![A-Za-z0-9_-]))"
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


class Renderer:
    def __init__(self, data, labels, now, tmux):
        self.data = data
        self.L = labels
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
        for sec in self.data["sections"]:
            if sec["type"] == "decisions":
                out.append(self.decisions(sec))
            elif sec["type"] == "bundle":
                out.append(self.bundle(sec))
            elif sec["type"] == "table":
                out.append(self.table(sec))
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
        if "tag" in c:
            head += '<span class="hp-tag">%s</span>' % esc(c["tag"])
        head += '<h%d class="hp-card-title">%s</h%d>' % (level, inline(c["title"], refs), level)
        head += self.evidence(c.get("evidence")) + "</div>"
        h.append(head)
        h.append('<p class="hp-rec">%s<span class="hp-rec-choice">%s</span></p>'
                 % (self.chip("hp-chip-rec", L["recommend"]), inline(rec_label, refs)))
        h.append('<p class="hp-reason"><span class="hp-lbl">%s</span>%s</p>' % (esc(L["text.reason"]), inline(c["reason"], refs)))
        if c.get("points"):
            items = []
            for p in c["points"]:
                if isinstance(p, str):
                    items.append("<li>%s</li>" % inline(p, refs))
                else:
                    items.append("<li>%s%s</li>" % (inline(p["text"], refs), self.evidence(p.get("evidence"))))
            h.append('<p class="hp-lbl">%s</p><ul class="hp-points">%s</ul>' % (esc(L["text.points"]), "".join(items)))
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

    def table(self, sec):
        """列と行をデータで書く表。指摘の一覧と同じ hp-table で描き、幅の狭い画面では行を積む。"""
        refs = self.page_refs
        cols = [(c["key"], c["label"], c.get("type", "text")) for c in sec["columns"]]
        out = ['<section class="hp-sec hp-tablesec"><h2 class="hp-sec-title">%s</h2>' % inline(sec["title"], refs)]
        out.append('<div class="hp-table-wrap"><table class="hp-table"><thead><tr>%s</tr></thead><tbody>'
                   % "".join("<th>%s</th>" % esc(label) for _, label, _ in cols))
        for row in sec["rows"]:
            cells = []
            for key, label, kind in cols:
                v = row[key]
                if kind == "ref":
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


def render(data, labels, now, tmux, body=None):
    """検証を通ったデータから、artifact に公開する断片を返す。"""
    template = read_text(TEMPLATE, "型（template.html）")
    for slot in TEMPLATE_SLOTS:
        if template.count("{{%s}}" % slot) != 1:
            raise LoadError("型（%s）に {{%s}} がちょうど1つあるべき所が %d 個ある"
                            % (TEMPLATE, slot, template.count("{{%s}}" % slot)))
    r = Renderer(data, labels, now, tmux)
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
        "purpose": esc(data["purpose"]),
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
    data = load_data(args.data)
    if args.body:
        read_text(args.body, "--body の本文")
    errors = validate(data, has_body=bool(args.body))
    if errors:
        report(errors)
        return 1
    print("誤りは無い: %s" % args.data, file=sys.stderr)
    return 0


def cmd_build(args):
    labels = load_glossary(args.glossary)
    data = load_data(args.data)
    body = read_text(args.body, "--body の本文") if args.body else None
    now = parse_now(args.now)
    errors = validate(data, has_body=body is not None)
    if errors:
        report(errors)
        return 1
    tmux = data["source"].get("tmux")
    if tmux is None and args.tmux == "auto":
        tmux, why = tmux_from_env()
        if tmux is None:
            print("送り元の tmux の項目を省いた: %s" % why, file=sys.stderr)
    fragment = render(data, labels, now, tmux, body)
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

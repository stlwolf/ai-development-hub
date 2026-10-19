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
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GLOSSARY = os.path.join(HERE, "glossary.md")

FORMAT_VERSION = 1
PURPOSES = ("decide", "grasp", "review")
STATUSES = ("awaiting", "answered", "live")
EVIDENCE = ("verified", "sourced", "guess")
SEVERITIES = ("high", "mid", "low")
ADOPTIONS = ("adopted", "partial", "rejected")
KINDS = ("go", "fix", "warn", "no")
SECTION_TYPES = ("decisions", "bundle", "findings")
ANSWER_SECTION_TYPES = ("decisions", "bundle")

# カードと選択肢の key。db の doc id が許す文字より狭い、このスキルの決まり。
KEY_RE = re.compile(r"^[a-z][a-z0-9_-]{0,63}$")
URL_RE = re.compile(r"^https?://\S+$")

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
            self.source("source", data["source"])
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
        if not self.obj(path, s, ("repo",), ("repo_url", "issue", "branch", "tmux")):
            return
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


# ---------------------------------------------------------------- コマンド


def cmd_check(args):
    load_glossary(args.glossary)
    data = load_data(args.data)
    if args.body:
        read_text(args.body, "--body の本文")
    errors = validate(data, has_body=bool(args.body))
    if errors:
        for line in format_errors(errors):
            print(line, file=sys.stderr)
        print("誤りが %d 件ある。直してから作り直す。" % len(errors), file=sys.stderr)
        return 1
    print("誤りは無い: %s" % args.data, file=sys.stderr)
    return 0


def make_parser():
    ap = argparse.ArgumentParser(prog="build.py", description="データ（JSON）から人向けのページを作る。")
    sub = ap.add_subparsers(dest="cmd")
    pc = sub.add_parser("check", help="データを検証するだけで、HTML は書かない")
    pc.add_argument("data", help="ページのデータ（JSON）")
    pc.add_argument("--body", help="読み物の本文の HTML の断片（sections が空でよくなる）")
    pc.add_argument("--glossary", default=DEFAULT_GLOSSARY, help=argparse.SUPPRESS)
    return ap


def main(argv=None):
    ap = make_parser()
    args = ap.parse_args(argv)
    if not args.cmd:
        ap.print_help(sys.stderr)
        return 2
    try:
        if args.cmd == "check":
            return cmd_check(args)
    except LoadError as e:
        print("読み込めない: %s" % e, file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())

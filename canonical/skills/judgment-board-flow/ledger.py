#!/usr/bin/env python3
"""判断ボードの台帳（1行1出来事の JSON Lines）を、検証して書き足す・検証する・問いごとに並べる。

使い方は同じフォルダの SKILL.md の「台帳」節にある。前提は Python 3.9 以上で、標準ライブラリだけを使う。
台帳を読んで出し忘れや取りこぼしを知らせることはしない（判定も知らせもしない）。

サブコマンド:
  add      1件の出来事を検証して書き足す（collected は collect で書く）
  collect  判断ボードのデータからカードの番号・題・推奨の中身・選んだ選択肢の名前を引いて、回収した出来事を書く
  check    台帳のすべての行を検証する
  trace    1つのカードの key に触れた出来事を、台帳の順に並べて出す（読むだけ）

終了コード:
  0  成功
  1  出来事か台帳に誤りがある（誤りを1件1行で標準エラーに出し、台帳には何も書かない）
  2  中身より前の失敗（ファイルが読めない・JSON として読めない・使い方の誤り）
"""

import argparse
import json
import os
import random
import re
import sys
import time
from datetime import datetime, timezone

KEY_RE = re.compile(r"^[a-z][a-z0-9_-]{0,63}$")
ID_RE = re.compile(r"^[0-9A-HJKMNP-TV-Z]{26}$")
NO_RE = re.compile(r"^Q[1-9][0-9]*$")
ROW_NO_RE = re.compile(r"^候補[1-9][0-9]*$")
URL_RE = re.compile(r"^https?://\S+$")
CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
RESERVED = ("id", "at", "type")
RECOMMEND_BLOCK = "推奨の中身"

# 項目の型の名前:
#   str   空でない文字列        text  文字列（空でもよい）       bool  真偽
#   int   1以上の整数           count 0以上の整数                url   http(s) の URL
#   key   カードの key           keys  カードの key の並び（空でもよい）
#   keys+ カードの key の並び（1つ以上）                         ref   台帳の別の出来事の id
#   pick  {key, label}           recommend {key, label, content}  rows  選んだ行の並び
#   counts {名前: 0以上の整数}
#   enum:a|b  決まった値のどれか
SCHEMA = {
    "asked": {
        "required": {"keys": "keys+", "from": "str", "file": "str", "stops": "bool",
                     "route": "enum:board|held|self|request"},
        "optional": {"hold": "enum:next_publish|threshold", "issue": "int", "step": "str", "gate": "int"},
    },
    "published": {
        "required": {"url": "url", "version": "str", "open": "keys", "added": "keys", "held": "keys"},
        "optional": {"counts": "counts"},
    },
    "announced": {
        "required": {"url": "url", "bulk": "keys", "added": "keys"},
        "optional": {},
    },
    "answered": {
        "required": {"where": "enum:page|conversation|child_pane", "words": "text", "keys": "keys"},
        "optional": {},
    },
    "read": {
        "required": {"round": "ref", "url": "url", "count": "count"},
        "optional": {},
    },
    "collected": {
        "required": {"round": "ref", "key": "key", "no": "str", "title": "str", "recommend": "recommend",
                     "choice": "pick", "note": "text", "via": "enum:page|conversation|bulk|child_pane"},
        "optional": {"words": "text", "rows": "rows"},
    },
    "sent": {
        "required": {"keys": "keys+", "kind": "enum:answer|correction|value", "to": "str", "ref": "str"},
        "optional": {"issue": "int", "step": "str", "round": "ref"},
    },
    "received": {
        "required": {"keys": "keys+", "sent": "text", "how": "enum:reply|receipt|direct"},
        "optional": {},
    },
    "recorded": {
        "required": {"keys": "keys+", "kind": "enum:approval|intake", "ref": "str"},
        "optional": {},
    },
    "withdrawn": {
        "required": {"key": "key", "reason": "str"},
        "optional": {},
    },
    "corrected": {
        "required": {"round": "ref", "key": "key", "choice": "pick", "words": "text"},
        "optional": {"rows": "rows"},
    },
}
# 出来事の中で、カードの key を持つ項目（trace がこれらを見る）。
KEY_FIELDS = ("key", "keys", "open", "added", "held", "bulk")


class Fail(Exception):
    """中身より前の失敗（終了コード 2）。"""


def new_id(taken):
    """時刻とでたらめな文字からなる26文字の識別子（ULID と同じ文字の並び）を、台帳の中で重ならないように振る。"""
    while True:
        ms = int(time.time() * 1000)
        head = "".join(CROCKFORD[(ms >> (45 - 5 * i)) & 31] for i in range(10))
        tail = "".join(random.choice(CROCKFORD) for _ in range(16))
        value = head + tail
        if value not in taken:
            return value


def now_text():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def read_ledger(path):
    """台帳を読み、(行番号, 出来事か None, 生の行) の並びを返す。ファイルが無ければ空の並び。"""
    if not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")
    except OSError as e:
        raise Fail("台帳を読めない: %s (%s)" % (path, e))
    out = []
    for i, raw in enumerate(lines, 1):
        if raw.strip() == "":
            continue
        try:
            obj = json.loads(raw)
        except ValueError:
            obj = None
        out.append((i, obj, raw))
    return out


def check_value(kind, value, where, errors):
    """1つの項目の値を型の名前で確かめ、誤りを errors に足す。"""
    def bad(reason):
        errors.append("E-F2 %s: %s" % (where, reason))

    if kind.startswith("enum:"):
        allowed = kind[5:].split("|")
        if value not in allowed:
            errors.append("E-V1 %s: %r は %s のどれでもない" % (where, value, "・".join(allowed)))
        return
    if kind == "str":
        if not isinstance(value, str) or value.strip() == "":
            bad("空でない文字列にする")
    elif kind == "text":
        if not isinstance(value, str):
            bad("文字列にする（空でもよい）")
    elif kind == "bool":
        if not isinstance(value, bool):
            bad("true か false にする")
    elif kind in ("int", "count"):
        low = 1 if kind == "int" else 0
        if isinstance(value, bool) or not isinstance(value, int) or value < low:
            bad("%d以上の整数にする" % low)
    elif kind == "url":
        if not isinstance(value, str) or not URL_RE.match(value):
            bad("https:// か http:// で始まる URL にする")
    elif kind == "key":
        if not isinstance(value, str) or not KEY_RE.match(value):
            errors.append("E-K1 %s: %r はカードの key の形でない（英小文字で始まり、英小文字・数字・_・- が続く64文字まで）"
                          % (where, value))
    elif kind in ("keys", "keys+"):
        if not isinstance(value, list):
            bad("カードの key の並びにする")
            return
        if kind == "keys+" and not value:
            bad("カードの key を1つ以上書く")
        for j, k in enumerate(value):
            check_value("key", k, "%s[%d]" % (where, j), errors)
        if len(set(v for v in value if isinstance(v, str))) != len(value):
            bad("同じ key を2回書いている")
    elif kind == "ref":
        if not isinstance(value, str) or not ID_RE.match(value):
            bad("台帳の出来事の id（26文字）にする")
    elif kind == "pick":
        if not isinstance(value, dict) or set(value) != {"key", "label"}:
            bad("{key, label} の形にする")
            return
        if not isinstance(value["key"], str) or value["key"].strip() == "":
            bad("key を空でない文字列にする")
        if not isinstance(value["label"], str) or value["label"].strip() == "":
            bad("label を空でない文字列にする")
    elif kind == "recommend":
        if not isinstance(value, dict) or set(value) != {"key", "label", "content"}:
            bad("{key, label, content} の形にする")
            return
        check_value("pick", {"key": value["key"], "label": value["label"]}, where, errors)
        content = value["content"]
        if not isinstance(content, list) or any(not isinstance(c, str) for c in content):
            bad("content を文字列の並びにする")
    elif kind == "rows":
        if not isinstance(value, list):
            bad("選んだ行を {no, content} の並びにする（行を選ばなかったときは空の並び）")
            return
        for j, row in enumerate(value):
            if not isinstance(row, dict) or set(row) != {"no", "content"}:
                bad("[%d] を {no, content} の形にする" % j)
                continue
            if not isinstance(row["no"], str) or not ROW_NO_RE.match(row["no"]):
                bad("[%d].no を 候補<数字> の形にする" % j)
            if not isinstance(row["content"], dict):
                bad("[%d].content を {列の名前: 値} の形にする" % j)
    elif kind == "counts":
        if not isinstance(value, dict) or any(
                not isinstance(v, int) or isinstance(v, bool) or v < 0 for v in value.values()):
            bad("{名前: 0以上の整数} の形にする")
    else:  # pragma: no cover - SCHEMA の書き間違い
        raise AssertionError(kind)


def check_event(ev, where, known, errors):
    """1件の出来事を確かめ、誤りが無ければ True を返す。known は、それより前の正しい行の {id: 出来事}。"""
    if not isinstance(ev, dict):
        errors.append("E-J1 %s: 行が JSON のオブジェクトでない" % where)
        return False
    start = len(errors)
    t = ev.get("type")
    if not isinstance(t, str) or t not in SCHEMA:
        errors.append("E-T1 %s.type: %r は知らない種類（%s）" % (where, t, "・".join(SCHEMA)))
        return False
    eid = ev.get("id")
    if not isinstance(eid, str) or not ID_RE.match(eid):
        errors.append("E-I1 %s.id: 26文字の id でない" % where)
    elif eid in known:
        errors.append("E-I1 %s.id: %s は前の行と重なる" % (where, eid))
    at = ev.get("at")
    if not isinstance(at, str) or at.strip() == "":
        errors.append("E-F2 %s.at: 時刻が無い" % where)
    spec = SCHEMA[t]
    allowed = set(RESERVED) | set(spec["required"]) | set(spec["optional"])
    for name in ev:
        if name not in allowed:
            errors.append("E-F1 %s.%s: %s の出来事に無い項目" % (where, name, t))
    for name, kind in spec["required"].items():
        if name not in ev:
            errors.append("E-F2 %s.%s: %s の出来事に要る項目が無い" % (where, name, t))
        else:
            check_value(kind, ev[name], "%s.%s" % (where, name), errors)
    for name, kind in spec["optional"].items():
        if name in ev:
            check_value(kind, ev[name], "%s.%s" % (where, name), errors)
    if len(errors) > start:
        return False  # 項目の型が崩れた出来事には、型に頼る規則を当てない
    check_rules(ev, where, known, errors)
    return len(errors) == start


def check_rules(ev, where, known, errors):
    """種類ごとの、項目どうしと前の行への参照の決まり。"""
    t = ev["type"]
    if t == "asked":
        route, hold = ev.get("route"), ev.get("hold")
        if route == "held" and hold is None:
            errors.append("E-F2 %s.hold: 待たせる問い（route が held）には、待たせる理由（next_publish か threshold）を書く"
                          % where)
        if route != "held" and hold is not None:
            errors.append("E-F1 %s.hold: route が held でない問いに、待たせる理由は書かない" % where)
        if "gate" in ev and isinstance(ev["gate"], int) and not 1 <= ev["gate"] <= 8:
            errors.append("E-F2 %s.gate: 判断の順の段は 1〜8" % where)
    if t == "published":
        opened, added = ev.get("open"), ev.get("added")
        if isinstance(opened, list) and isinstance(added, list):
            extra = [k for k in added if k not in opened]
            if extra:
                errors.append("E-F2 %s.added: 開いた問い（open）に無い key がある: %s" % (where, ", ".join(map(str, extra))))
    if t == "announced":
        bulk, added = ev.get("bulk"), ev.get("added")
        if isinstance(bulk, list) and isinstance(added, list):
            both = [k for k in added if k in bulk]
            if both:
                errors.append("E-F2 %s.bulk: 「追加」の問いを一括の答えの範囲に入れている: %s"
                              % (where, ", ".join(map(str, both))))
    if t == "announced":
        pub = next((e for e in reversed(list(known.values())) if e.get("type") == "published"), None)
        bulk, added = ev.get("bulk"), ev.get("added")
        if pub is not None and pub.get("url") == ev.get("url") and isinstance(bulk, list) and isinstance(added, list):
            expect_bulk = [k for k in pub.get("open", []) if k not in pub.get("added", [])]
            if sorted(bulk) != sorted(expect_bulk):
                errors.append("E-R2 %s.bulk: 直前の published の open から added を除いた key（%s）と合わない"
                              % (where, ", ".join(expect_bulk) or "なし"))
            if sorted(added) != sorted(pub.get("added", [])):
                errors.append("E-R2 %s.added: 直前の published の added（%s）と合わない" % (where, ", ".join(pub.get("added", [])) or "なし"))
    if t in ("read", "collected", "corrected") or (t == "sent" and "round" in ev):
        ref = ev.get("round")
        if isinstance(ref, str) and ID_RE.match(ref):
            target = known.get(ref)
            if target is None or target.get("type") != "answered":
                errors.append("E-R1 %s.round: %s は、それより前の行の answered（答えた）の出来事でない" % (where, ref))
    if t == "collected":
        no = ev.get("no")
        if isinstance(no, str) and no.strip() and not NO_RE.match(no):
            errors.append("E-F2 %s.no: 問いの番号は Q<数字> の形にする" % where)
    if t == "received":
        how, ref = ev.get("how"), ev.get("sent")
        if how in ("reply", "receipt"):
            target = known.get(ref) if isinstance(ref, str) else None
            if target is None or target.get("type") != "sent":
                errors.append("E-R1 %s.sent: %r は、それより前の行の sent（渡した）の出来事でない（受け取ったのがどの送信かを id で書く）"
                              % (where, ref))
            elif isinstance(ev.get("keys"), list):
                missing = [k for k in ev["keys"] if k not in target.get("keys", [])]
                if missing:
                    errors.append("E-R1 %s.keys: 指した送信に無い key がある: %s" % (where, ", ".join(map(str, missing))))
        elif how == "direct" and ref not in ("", None):
            target = known.get(ref) if isinstance(ref, str) else None
            if target is None or target.get("type") != "sent":
                errors.append("E-R1 %s.sent: %r は、それより前の行の sent の出来事でない（owner が子のペインに直接答えたときは空にしてよい）"
                              % (where, ref))


def check_ledger(entries):
    """台帳の行の並びを確かめ、(誤りの並び, {id: 出来事}) を返す。"""
    errors = []
    known = {}
    for lineno, obj, _raw in entries:
        where = "%d行目" % lineno
        if obj is None:
            errors.append("E-J1 %s: JSON として読めない" % where)
            continue
        if check_event(obj, where, known, errors):
            known[obj["id"]] = obj  # 誤りのある行は、あとの行の参照先にしない
    return errors, known


def append(path, ev):
    line = json.dumps(ev, ensure_ascii=False)
    try:
        need_newline = os.path.exists(path) and os.path.getsize(path) > 0 and not _ends_with_newline(path)
        with open(path, "a", encoding="utf-8") as f:
            if need_newline:
                f.write("\n")
            f.write(line + "\n")
    except OSError as e:
        raise Fail("台帳に書けない: %s (%s)" % (path, e))


def _ends_with_newline(path):
    with open(path, "rb") as f:
        f.seek(-1, os.SEEK_END)
        return f.read(1) == b"\n"


def write_event(path, ev, entries):
    """前の行を確かめ、出来事に id と時刻を付けて確かめてから書き足す。書いた出来事を返す。"""
    errors, known = check_ledger(entries)
    if errors:
        return None, ["台帳に誤りがあるので書き足さない（先に check で直す）"] + errors
    ev = dict(ev)
    ev = {"id": new_id(known), "at": now_text(), **ev}
    errs = []
    check_event(ev, "新しい出来事", known, errs)
    if errs:
        return None, errs
    append(path, ev)
    return ev, []


# ---- collect ---------------------------------------------------------------------------------------------

def text_of(value):
    """表の欄やカードの要点の値を、文字だけにする。"""
    if isinstance(value, dict):
        return str(value.get("text", ""))
    if isinstance(value, list):
        return "・".join(text_of(v) for v in value)
    return "" if value is None else str(value)


def find_card(page, key):
    """ページのデータから key のカードと、そのカードと同じ場所（ページか束の group）の表の並びを探す。"""
    sections = page.get("sections") if isinstance(page, dict) else None
    if not isinstance(sections, list):
        return None, []
    page_tables = [s for s in sections if isinstance(s, dict) and s.get("type") == "table"]
    for s in sections:
        if not isinstance(s, dict):
            continue
        if s.get("type") == "decisions":
            for c in s.get("cards") or []:
                if isinstance(c, dict) and c.get("key") == key:
                    return c, page_tables
        if s.get("type") == "bundle":
            for g in s.get("groups") or []:
                for c in (g.get("cards") or []) if isinstance(g, dict) else []:
                    if isinstance(c, dict) and c.get("key") == key:
                        return c, [t for t in (g.get("tables") or []) if isinstance(t, dict)]
    return None, []


def select_rows(card, tables, page_kind, wanted, errors):
    """選び方のカードが名指した表から、選んだ行の番号と中身を引く。"""
    sel = card.get("select") or {}
    names = sel.get("tables")
    if names:
        chosen = [t for t in tables if t.get("key") in names]
    elif page_kind == "pick":
        chosen = tables
    else:
        errors.append("E-B2 --rows: 選び方のカードが選ぶ表を名指していない（select.tables）")
        return []
    index = {}
    position = 0  # 一覧から選ぶページで番号を省いたとき、html-one-pager が振る番号（表をまたいで続く）
    for t in tables:
        cols = t.get("columns") or []
        no_cols = [c.get("key") for c in cols if isinstance(c, dict) and c.get("type") == "no"]
        if not no_cols:
            continue
        no_key = no_cols[0]
        for row in t.get("rows") or []:
            if not isinstance(row, dict):
                continue
            position += 1
            no = row.get(no_key)
            if not (isinstance(no, str) and no):
                if page_kind != "pick":
                    continue
                no = "候補%d" % position
            if t in chosen:
                index[no] = {c.get("label") or c.get("key"): text_of(row.get(c.get("key")))
                             for c in cols if isinstance(c, dict) and c.get("key") != no_key}
    rows = []
    for no in wanted:
        if no not in index:
            errors.append("E-B2 --rows: %s は、選び方のカードが名指した表の番号に無い" % no)
            continue
        rows.append({"no": no, "content": index[no]})
    if len(set(wanted)) != len(wanted):
        errors.append("E-B2 --rows: 同じ行を2回書いている")
    mx, mn = sel.get("max"), sel.get("min")
    if isinstance(mx, int) and len(wanted) > mx:
        errors.append("E-B2 --rows: 選んだ行が %d つで、選べる数（%d）を超える" % (len(wanted), mx))
    if isinstance(mn, int) and wanted and len(wanted) < mn:
        errors.append("E-B2 --rows: 選んだ行が %d つで、選ぶ数の下限（%d）に届かない" % (len(wanted), mn))
    return rows


def last_announced(entries):
    for _lineno, obj, _raw in reversed(entries):
        if isinstance(obj, dict) and obj.get("type") == "announced":
            return obj
    return None


def build_collected(page, args, entries):
    """collect の引数と判断ボードのデータから collected の出来事を組み立てる。(出来事, 誤りの並び) を返す。"""
    errors = []
    card, tables = find_card(page, args.key)
    if card is None:
        return None, ["E-B1 --key: %s のカードが判断ボードのデータに無い" % args.key]
    options = {o.get("key"): o.get("label") for o in card.get("options") or [] if isinstance(o, dict)}
    if args.choice not in options:
        errors.append("E-B1 --choice: %r は %s の選択肢（%s）に無い" % (args.choice, args.key, "・".join(map(str, options))))
    rec = card.get("recommend")
    blocks = [b for b in card.get("blocks") or [] if isinstance(b, dict)]
    rec_block = next((b for b in blocks if b.get("title") == RECOMMEND_BLOCK), None)
    content = [text_of(p) for p in (rec_block or {}).get("points") or []]
    no = args.no or card.get("tag")
    if args.no and card.get("tag") and args.no != card.get("tag"):
        errors.append("E-B1 --no: %s は、カードの札 %s と違う" % (args.no, card.get("tag")))
    if not no:
        errors.append("E-B1 --key: %s のカードに札（Q<数字>）が無い。--no で番号を渡す" % args.key)
    if args.via == "bulk":
        ann = last_announced(entries)
        if ann is None:
            errors.append("E-B3 --via bulk: 台帳に announced（版を伝えた）が無いので、一括の答えの範囲が決まらない")
        elif args.key not in (ann.get("bulk") or []):
            errors.append("E-B3 --via bulk: %s は、最後の announced の bulk（一括の答えを当ててよい問い）に無い" % args.key)
        if args.choice != rec:
            errors.append("E-B3 --via bulk: 一括の答えは推奨（%s）を選んだものとして写す。--choice が %r" % (rec, args.choice))
    rows = None
    wanted = [r.strip() for r in args.rows.split(",") if r.strip()] if args.rows else []
    if card.get("select"):
        if args.rows is None:
            errors.append("E-B2 --rows: 一覧から選ぶカード（select がある）では、選んだ行を --rows で書く"
                          "（行を選ばなかったときは --rows ''）")
        else:
            rows = select_rows(card, tables, page.get("kind"), wanted, errors)
    elif args.rows is not None:
        errors.append("E-B2 --rows: %s は一覧から選ぶカードでない（select が無い）" % args.key)
    if errors:
        return None, errors
    ev = {
        "type": "collected", "round": args.round, "key": args.key, "no": no, "title": card.get("title", ""),
        "recommend": {"key": rec, "label": options.get(rec, ""), "content": content},
        "choice": {"key": args.choice, "label": options[args.choice]},
        "note": args.note, "via": args.via,
    }
    if args.words is not None:
        ev["words"] = args.words
    if rows is not None:
        ev["rows"] = rows
    return ev, []


# ---- trace -----------------------------------------------------------------------------------------------

def mentions(ev, key):
    for name in KEY_FIELDS:
        v = ev.get(name)
        if v == key or (isinstance(v, list) and key in v):
            return True
    return False


def trace(entries, key):
    """key に触れた出来事と、それらが round で指す answered の出来事を、台帳の順に返す。"""
    events = [obj for _l, obj, _r in entries if isinstance(obj, dict)]
    hit = [i for i, obj in enumerate(events) if mentions(obj, key)]
    rounds = {events[i].get("round") for i in hit if isinstance(events[i].get("round"), str)}
    keep = set(hit) | {i for i, obj in enumerate(events) if obj.get("type") == "answered" and obj.get("id") in rounds}
    return [events[i] for i in sorted(keep)]


# ---- コマンド -----------------------------------------------------------------------------------------

def load_json_file(path, what):
    try:
        if path == "-":
            return json.loads(sys.stdin.read())
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except OSError as e:
        raise Fail("%sを読めない: %s (%s)" % (what, path, e))
    except ValueError as e:
        raise Fail("%sが JSON として読めない: %s (%s)" % (what, path, e))


def report(errors):
    for e in errors:
        print(e, file=sys.stderr)


def cmd_add(args):
    if args.type not in SCHEMA:
        report(["E-T1 type: %r は知らない種類（%s）" % (args.type, "・".join(SCHEMA))])
        return 1
    if args.type == "collected":
        report(["E-A1 type: collected（回収した）は collect で書く（判断ボードのデータから題と推奨の中身を引くため）"])
        return 1
    if (args.data is None) == (args.data_file is None):
        raise Fail("--data か --data-file のどちらか1つを渡す")
    if args.data is not None:
        try:
            data = json.loads(args.data)
        except ValueError as e:
            raise Fail("--data が JSON として読めない (%s)" % e)
    else:
        data = load_json_file(args.data_file, "--data-file ")
    if not isinstance(data, dict):
        raise Fail("--data は JSON のオブジェクトにする")
    clash = [k for k in RESERVED if k in data]
    if clash:
        report(["E-A1 --data: %s は台帳の道具が書く項目なので渡さない" % "・".join(clash)])
        return 1
    entries = read_ledger(args.ledger)
    ev, errors = write_event(args.ledger, {"type": args.type, **data}, entries)
    if errors:
        report(errors)
        return 1
    print(json.dumps(ev, ensure_ascii=False))
    return 0


def cmd_collect(args):
    page = load_json_file(args.board, "判断ボードのデータ")
    entries = read_ledger(args.ledger)
    ev, errors = build_collected(page, args, entries)
    if errors:
        report(errors)
        return 1
    ev, errors = write_event(args.ledger, ev, entries)
    if errors:
        report(errors)
        return 1
    print(json.dumps(ev, ensure_ascii=False))
    return 0


def cmd_check(args):
    if not os.path.exists(args.ledger):
        raise Fail("台帳が無い: %s" % args.ledger)
    entries = read_ledger(args.ledger)
    errors, known = check_ledger(entries)
    if errors:
        report(errors)
        return 1
    print("誤りは無い: %s（出来事 %d 件）" % (args.ledger, len(known)))
    return 0


def cmd_trace(args):
    if not os.path.exists(args.ledger):
        raise Fail("台帳が無い: %s" % args.ledger)
    for ev in trace(read_ledger(args.ledger), args.key):
        print(json.dumps(ev, ensure_ascii=False))
    return 0


def parser():
    p = argparse.ArgumentParser(prog="ledger.py", description="判断ボードの台帳を検証して書き足す・検証する・問いごとに並べる。")
    sub = p.add_subparsers(dest="cmd")
    a = sub.add_parser("add", help="1件の出来事を検証して書き足す")
    a.add_argument("ledger")
    a.add_argument("type")
    a.add_argument("--data", help="出来事の項目（JSON のオブジェクト）")
    a.add_argument("--data-file", help="出来事の項目を書いたファイル（- で標準入力）")
    c = sub.add_parser("collect", help="判断ボードのデータから回収した出来事を書く")
    c.add_argument("ledger")
    c.add_argument("--board", required=True, help="判断ボードのデータ（JSON）")
    c.add_argument("--key", required=True, help="カードの key")
    c.add_argument("--choice", required=True, help="選んだ選択肢の key")
    c.add_argument("--via", required=True, choices=("page", "conversation", "bulk", "child_pane"))
    c.add_argument("--round", required=True, help="この回収のきっかけの answered の id")
    c.add_argument("--note", default="", help="補足（owner の言葉を含む）")
    c.add_argument("--words", help="会話の答えなら owner の言葉のまま")
    c.add_argument("--rows", help="一覧から選ぶカードの選んだ行（候補2,候補5 のようにカンマで区切る。選ばなかったときは空の文字列）")
    c.add_argument("--no", help="カードに札が無いときの問いの番号（Q<数字>）")
    k = sub.add_parser("check", help="台帳のすべての行を検証する")
    k.add_argument("ledger")
    t = sub.add_parser("trace", help="1つのカードの key に触れた出来事を並べる")
    t.add_argument("ledger")
    t.add_argument("--key", required=True)
    return p


def main(argv=None):
    p = parser()
    args = p.parse_args(argv)
    if args.cmd is None:
        p.print_usage(sys.stderr)
        return 2
    try:
        return {"add": cmd_add, "collect": cmd_collect, "check": cmd_check, "trace": cmd_trace}[args.cmd](args)
    except Fail as e:
        print("ledger.py: %s" % e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())

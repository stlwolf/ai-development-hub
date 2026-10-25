#!/usr/bin/env python3
"""ledger.py の検査。標準の unittest だけを使う。

走らせ方: python3 tests/test_ledger.py （どの作業ディレクトリからでもよい）

誤りの検査は、出た誤りが「期待した規則の番号を含む」ことと、台帳に何も書かれていないことを確かめる。
落ちたことだけを見ると、別の理由で落ちたものを見逃すためである。
"""

import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest

TESTS = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(TESTS)
LEDGER_PY = os.path.join(SKILL, "ledger.py")

_spec = importlib.util.spec_from_file_location("judgment_board_ledger", LEDGER_PY)
ledger = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ledger)

URL = "https://claude.example/artifact/board"


def board():
    """判断ボードのデータの見本（問いのカード2枚と、一覧から選ぶカード1枚と選ぶ表）。"""
    return {
        "format": 1, "title": "統括の判断ボード", "kind": "board", "status": "live",
        "why": "検査の見本", "source": {"repo": "example"},
        "sections": [
            {"type": "decisions", "title": "いま決めること（#900・止まっている）", "cards": [
                {"key": "i900_lib", "tag": "Q41", "title": "どちらのライブラリにするか", "recommend": "a",
                 "blocks": [
                     {"title": "何を決めるか", "points": ["ライブラリを1つ選ぶ。"]},
                     {"title": "推奨の中身", "points": ["A を使う。", {"text": "保守が続いている。", "evidence": "verified"}]},
                     {"title": "ほかの案", "points": ["B は更新が止まっている。"]},
                 ],
                 "options": [{"key": "a", "label": "A を使う", "kind": "go"}, {"key": "b", "label": "B を使う", "kind": "warn"}]},
                {"key": "i900_add", "tag": "Q42", "title": "追加: 名前をどうするか", "recommend": "short",
                 "blocks": [
                     {"title": "何を決めるか", "points": ["名前を決める。"]},
                     {"title": "推奨の中身", "points": ["短い名前にする。"]},
                 ],
                 "options": [{"key": "short", "label": "短い名前にする", "kind": "go"}, {"key": "long", "label": "長い名前にする", "kind": "warn"}]},
                {"key": "i900_pick", "tag": "Q43", "title": "どの店で試すか", "recommend": "chosen",
                 "select": {"max": 2, "recommend": ["候補1"], "tables": ["i900_shops"]},
                 "blocks": [
                     {"title": "何を決めるか", "points": ["試す店を2つまで選ぶ。"]},
                     {"title": "推奨の中身", "points": ["候補1 で試す。"]},
                 ],
                 "options": [{"key": "chosen", "label": "選んだ店で試す", "kind": "go"}, {"key": "none", "label": "試さない", "kind": "no"}]},
            ]},
            {"type": "table", "title": "候補の店", "key": "i900_shops",
             "columns": [{"key": "no", "label": "番号", "type": "no"}, {"key": "name", "label": "店"},
                         {"key": "refs", "label": "issue", "type": "ref"}],
             "rows": [{"no": "候補1", "name": "駅前店", "refs": ["#900"]},
                      {"no": "候補2", "name": {"text": "アウトレット", "evidence": "guess"}, "refs": []},
                      {"no": "候補3", "name": "本店", "refs": []}]},
        ],
    }


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tmp.name, "board-ledger.jsonl")
        self.board_path = os.path.join(self.tmp.name, "board.json")
        with open(self.board_path, "w", encoding="utf-8") as f:
            json.dump(board(), f, ensure_ascii=False)

    def tearDown(self):
        self.tmp.cleanup()

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ledger.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def add(self, type_, data, expect=0):
        code, out, err = self.run_main("add", self.path, type_, "--data", json.dumps(data, ensure_ascii=False))
        self.assertEqual(code, expect, err)
        return json.loads(out) if code == 0 else err

    def lines(self):
        if not os.path.exists(self.path):
            return []
        with open(self.path, encoding="utf-8") as f:
            return [json.loads(l) for l in f.read().splitlines() if l.strip()]

    def collect(self, *extra):
        return self.run_main("collect", self.path, "--board", self.board_path, *extra)

    def answered(self, words="全部推奨。Q41 は別案"):
        return self.add("answered", {"where": "conversation", "words": words, "keys": []})["id"]

    def assert_rejected(self, err, rule, before):
        self.assertIn(rule, err)
        self.assertEqual(self.lines(), before, "誤りのときは台帳に何も書かない")


class AddTest(Base):
    def asked(self, **over):
        d = {"keys": ["i900_lib"], "from": "子 #900", "file": ".oe/question-900-1.json", "stops": True, "route": "board"}
        d.update(over)
        return d

    def test_asked_is_written_with_id_and_time(self):
        ev = self.add("asked", self.asked())
        self.assertEqual(ev["type"], "asked")
        self.assertRegex(ev["id"], r"^[0-9A-HJKMNP-TV-Z]{26}$")
        self.assertTrue(ev["at"].endswith("Z"))
        self.assertEqual(self.lines(), [ev])
        code, out, err = self.run_main("check", self.path)
        self.assertEqual(code, 0, err)

    def test_ids_do_not_repeat(self):
        ids = {self.add("asked", self.asked())["id"] for _ in range(20)}
        self.assertEqual(len(ids), 20)

    def test_unknown_type(self):
        self.assert_rejected(self.add("asked2", {}, expect=1), "E-T1", [])

    def test_unknown_field(self):
        self.assert_rejected(self.add("asked", self.asked(extra=1), expect=1), "E-F1", [])

    def test_missing_file(self):
        d = self.asked()
        del d["file"]
        self.assert_rejected(self.add("asked", d, expect=1), "E-F2", [])

    def test_held_needs_hold(self):
        self.assert_rejected(self.add("asked", self.asked(route="held"), expect=1), "E-F2", [])
        self.add("asked", self.asked(route="held", hold="next_publish"))
        self.add("asked", self.asked(route="held", hold="threshold"))

    def test_hold_only_when_held(self):
        self.assert_rejected(self.add("asked", self.asked(hold="threshold"), expect=1), "E-F1", [])

    def test_bad_enum_and_key(self):
        self.assert_rejected(self.add("asked", self.asked(route="later"), expect=1), "E-V1", [])
        self.assert_rejected(self.add("asked", self.asked(keys=["Bad Key"]), expect=1), "E-K1", [])
        self.assert_rejected(self.add("asked", self.asked(keys=[]), expect=1), "E-F2", [])

    def test_gate_range(self):
        self.assert_rejected(self.add("asked", self.asked(gate=9), expect=1), "E-F2", [])
        self.add("asked", self.asked(gate=7))

    def test_reserved_fields(self):
        self.assert_rejected(self.add("asked", self.asked(id="x"), expect=1), "E-A1", [])

    def test_collected_must_use_collect(self):
        self.assert_rejected(self.add("collected", {"key": "i900_lib"}, expect=1), "E-A1", [])

    def test_published_added_within_open(self):
        d = {"url": URL, "version": "2026-10-26 09:00 JST", "open": ["i900_lib"], "added": ["i900_add"], "held": []}
        self.assert_rejected(self.add("published", d, expect=1), "E-F2", [])
        d["open"].append("i900_add")
        self.add("published", d)

    def test_announced_bulk_excludes_added(self):
        d = {"url": URL, "bulk": ["i900_lib", "i900_add"], "added": ["i900_add"]}
        self.assert_rejected(self.add("announced", d, expect=1), "E-F2", [])
        d["bulk"] = ["i900_lib"]
        self.add("announced", d)

    def test_round_must_point_to_answered(self):
        other = self.add("asked", self.asked())["id"]
        before = self.lines()
        self.assert_rejected(self.add("read", {"round": other, "url": URL, "count": 2}, expect=1), "E-R1", before)
        rid = self.answered()
        self.add("read", {"round": rid, "url": URL, "count": 2})

    def test_received_points_to_sent(self):
        sent = self.add("sent", {"keys": ["i900_lib"], "kind": "answer", "to": "子 #900", "ref": "oe:01ABC"})
        before = self.lines()
        self.assert_rejected(self.add("received", {"keys": ["i900_lib"], "sent": "", "how": "reply"}, expect=1),
                             "E-R1", before)
        self.assert_rejected(self.add("received", {"keys": ["i900_add"], "sent": sent["id"], "how": "reply"}, expect=1),
                             "E-R1", before)
        self.add("received", {"keys": ["i900_lib"], "sent": sent["id"], "how": "receipt"})
        self.add("received", {"keys": ["i900_lib"], "sent": "", "how": "direct"})

    def test_recorded_needs_keys(self):
        self.assert_rejected(self.add("recorded", {"kind": "approval", "ref": ".oe/decision-900-gate3.md"}, expect=1),
                             "E-F2", [])
        self.add("recorded", {"keys": ["i900_lib"], "kind": "approval", "ref": ".oe/decision-900-gate3.md"})

    def test_corrected(self):
        rid = self.answered("Q41 はやっぱり B で")
        self.add("corrected", {"round": rid, "key": "i900_lib", "choice": {"key": "b", "label": "B を使う"},
                               "words": "Q41 はやっぱり B で"})

    def test_withdrawn(self):
        self.add("withdrawn", {"key": "i900_lib", "reason": "子の作業が取り消された"})

    def test_bad_data_json_is_exit_2(self):
        code, out, err = self.run_main("add", self.path, "asked", "--data", "{")
        self.assertEqual(code, 2)

    def test_data_file(self):
        p = os.path.join(self.tmp.name, "ev.json")
        with open(p, "w", encoding="utf-8") as f:
            json.dump(self.asked(), f, ensure_ascii=False)
        code, out, err = self.run_main("add", self.path, "asked", "--data-file", p)
        self.assertEqual(code, 0, err)

    def test_appends_newline_when_missing(self):
        ev = self.add("asked", self.asked())
        with open(self.path, "w", encoding="utf-8") as f:
            f.write(json.dumps(ev, ensure_ascii=False))  # 最後の改行を落とす
        self.add("asked", self.asked())
        self.assertEqual(len(self.lines()), 2)

    def test_add_refuses_on_broken_ledger(self):
        with open(self.path, "w", encoding="utf-8") as f:
            f.write("{broken\n")
        code, out, err = self.run_main("add", self.path, "asked", "--data", json.dumps(self.asked()))
        self.assertEqual(code, 1)
        self.assertIn("E-J1", err)
        with open(self.path, encoding="utf-8") as f:
            self.assertEqual(f.read(), "{broken\n")


class CollectTest(Base):
    def announce(self, bulk):
        self.add("announced", {"url": URL, "bulk": bulk, "added": []})

    def test_collect_from_board(self):
        rid = self.answered()
        code, out, err = self.collect("--key", "i900_lib", "--choice", "b", "--via", "conversation", "--round", rid,
                                      "--note", "Q41 は別案", "--words", "全部推奨。Q41 は別案")
        self.assertEqual(code, 0, err)
        ev = json.loads(out)
        self.assertEqual(ev["no"], "Q41")
        self.assertEqual(ev["title"], "どちらのライブラリにするか")
        self.assertEqual(ev["recommend"], {"key": "a", "label": "A を使う", "content": ["A を使う。", "保守が続いている。"]})
        self.assertEqual(ev["choice"], {"key": "b", "label": "B を使う"})
        self.assertEqual(ev["words"], "全部推奨。Q41 は別案")
        self.assertNotIn("rows", ev)
        code, out, err = self.run_main("check", self.path)
        self.assertEqual(code, 0, err)

    def test_unknown_key_and_choice(self):
        rid = self.answered()
        before = self.lines()
        code, out, err = self.collect("--key", "i900_zzz", "--choice", "a", "--via", "page", "--round", rid)
        self.assertEqual(code, 1)
        self.assert_rejected(err, "E-B1", before)
        code, out, err = self.collect("--key", "i900_lib", "--choice", "c", "--via", "page", "--round", rid)
        self.assertEqual(code, 1)
        self.assert_rejected(err, "E-B1", before)

    def test_select_card_needs_rows(self):
        rid = self.answered()
        before = self.lines()
        code, out, err = self.collect("--key", "i900_pick", "--choice", "chosen", "--via", "page", "--round", rid)
        self.assertEqual(code, 1)
        self.assert_rejected(err, "E-B2", before)

    def test_select_rows_content(self):
        rid = self.answered()
        code, out, err = self.collect("--key", "i900_pick", "--choice", "chosen", "--via", "page", "--round", rid,
                                      "--rows", "候補1,候補2")
        self.assertEqual(code, 0, err)
        rows = json.loads(out)["rows"]
        self.assertEqual(rows, [{"no": "候補1", "content": {"店": "駅前店", "issue": "#900"}},
                                {"no": "候補2", "content": {"店": "アウトレット", "issue": ""}}])

    def test_select_card_with_no_rows(self):
        rid = self.answered("Q43 はどれも試さない")
        code, out, err = self.collect("--key", "i900_pick", "--choice", "none", "--via", "conversation", "--round", rid,
                                      "--rows", "")
        self.assertEqual(code, 0, err)
        self.assertEqual(json.loads(out)["rows"], [])

    def test_rows_errors(self):
        rid = self.answered()
        before = self.lines()
        for rows in ("候補9", "候補1,候補2,候補3", "候補1,候補1"):
            code, out, err = self.collect("--key", "i900_pick", "--choice", "chosen", "--via", "page", "--round", rid,
                                          "--rows", rows)
            self.assertEqual(code, 1, rows)
            self.assert_rejected(err, "E-B2", before)
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "page", "--round", rid,
                                      "--rows", "候補1")
        self.assertEqual(code, 1)
        self.assert_rejected(err, "E-B2", before)

    def test_bulk_needs_announced_scope(self):
        rid = self.answered("全部推奨")
        before = self.lines()
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "bulk", "--round", rid)
        self.assertEqual(code, 1)
        self.assert_rejected(err, "E-B3", before)
        self.announce(["i900_lib"])
        before = self.lines()
        code, out, err = self.collect("--key", "i900_add", "--choice", "short", "--via", "bulk", "--round", rid)
        self.assertEqual(code, 1, "「追加」の問いは一括の答えの範囲に無い")
        self.assert_rejected(err, "E-B3", before)
        code, out, err = self.collect("--key", "i900_lib", "--choice", "b", "--via", "bulk", "--round", rid)
        self.assertEqual(code, 1, "一括の答えは推奨を選んだものとして写す")
        self.assert_rejected(err, "E-B3", before)
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "bulk", "--round", rid)
        self.assertEqual(code, 0, err)

    def test_bulk_uses_last_announced(self):
        rid = self.answered("全部推奨")
        self.announce([])
        self.announce(["i900_add"])  # 回収のあとの案内で「追加」の印が外れた
        code, out, err = self.collect("--key", "i900_add", "--choice", "short", "--via", "bulk", "--round", rid)
        self.assertEqual(code, 0, err)

    def test_card_without_tag(self):
        data = board()
        del data["sections"][0]["cards"][0]["tag"]
        with open(self.board_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        rid = self.answered()
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "page", "--round", rid)
        self.assertEqual(code, 1)
        self.assertIn("E-B1", err)
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "page", "--round", rid, "--no", "Q41")
        self.assertEqual(code, 0, err)

    def test_round_must_be_answered(self):
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "page", "--round",
                                      "01M5QPYJ0RXFEAS3FJCYF4S6NB")
        self.assertEqual(code, 1)
        self.assertIn("E-R1", err)
        self.assertEqual(self.lines(), [])

    def test_unreadable_board_is_exit_2(self):
        rid = self.answered()
        code, out, err = self.run_main("collect", self.path, "--board", os.path.join(self.tmp.name, "none.json"),
                                       "--key", "i900_lib", "--choice", "a", "--via", "page", "--round", rid)
        self.assertEqual(code, 2)


class CheckTest(Base):
    def write_raw(self, lines):
        with open(self.path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

    def test_broken_line(self):
        self.write_raw(["not json"])
        code, out, err = self.run_main("check", self.path)
        self.assertEqual(code, 1)
        self.assertIn("E-J1 1行目", err)

    def test_duplicate_id(self):
        ev = {"id": "01M5QPYJ0RXFEAS3FJCYF4S6NB", "at": "2026-10-26T00:00:00Z", "type": "withdrawn",
              "key": "i900_lib", "reason": "要らなくなった"}
        self.write_raw([json.dumps(ev, ensure_ascii=False)] * 2)
        code, out, err = self.run_main("check", self.path)
        self.assertEqual(code, 1)
        self.assertIn("E-I1 2行目", err)

    def test_reference_to_later_line(self):
        sent_id = "01M5QPYJ0RXFEAS3FJCYF4S6NC"
        rec = {"id": "01M5QPYJ0RXFEAS3FJCYF4S6NB", "at": "2026-10-26T00:00:00Z", "type": "received",
               "keys": ["i900_lib"], "sent": sent_id, "how": "reply"}
        sent = {"id": sent_id, "at": "2026-10-26T00:00:01Z", "type": "sent", "keys": ["i900_lib"],
                "kind": "answer", "to": "子", "ref": "oe:1"}
        self.write_raw([json.dumps(rec, ensure_ascii=False), json.dumps(sent, ensure_ascii=False)])
        code, out, err = self.run_main("check", self.path)
        self.assertEqual(code, 1, "受け取りは、それより前の送信だけを指せる")
        self.assertIn("E-R1 1行目", err)

    def test_missing_ledger_is_exit_2(self):
        code, out, err = self.run_main("check", self.path)
        self.assertEqual(code, 2)


class TraceTest(Base):
    def test_trace_lists_one_key(self):
        a = {"keys": ["i900_lib"], "from": "子 #900", "file": ".oe/question-900-1.json", "stops": True, "route": "board"}
        self.add("asked", a)
        self.add("asked", dict(a, keys=["i900_add"]))
        rid = self.answered()
        self.add("read", {"round": rid, "url": URL, "count": 3})
        code, out, err = self.collect("--key", "i900_lib", "--choice", "a", "--via", "page", "--round", rid)
        self.assertEqual(code, 0, err)
        self.add("asked", dict(a, keys=["i900_pick"]))  # 別の問いの出来事が挟まる
        sent = self.add("sent", {"keys": ["i900_lib"], "kind": "answer", "to": "子 #900", "ref": "oe:1"})
        self.add("received", {"keys": ["i900_lib"], "sent": sent["id"], "how": "reply"})
        code, out, err = self.run_main("trace", self.path, "--key", "i900_lib")
        self.assertEqual(code, 0, err)
        types = [json.loads(l)["type"] for l in out.splitlines()]
        self.assertEqual(types, ["asked", "answered", "collected", "sent", "received"])
        self.assertNotIn("i900_add", out)
        self.assertNotIn("i900_pick", out)


class CommandLineTest(Base):
    def test_runs_as_script(self):
        r = subprocess.run([sys.executable, LEDGER_PY, "add", self.path, "withdrawn", "--data",
                            json.dumps({"key": "i900_lib", "reason": "要らなくなった"}, ensure_ascii=False)],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        r = subprocess.run([sys.executable, LEDGER_PY, "check", self.path], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        r = subprocess.run([sys.executable, LEDGER_PY], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()

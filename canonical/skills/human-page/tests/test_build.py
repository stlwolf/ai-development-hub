#!/usr/bin/env python3
"""build.py の検査。標準の unittest だけを使う。

走らせ方: python3 tests/test_build.py （どの作業ディレクトリからでもよい）

壊したデータの検査は、見本のデータを1か所だけ壊し、出た誤りが「期待した規則と場所の1件だけ」で
あることを確かめる。落ちたことだけを見ると、別の理由で落ちたものを見逃すためである。
"""

import copy
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

TESTS = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(TESTS)
BUILD = os.path.join(SKILL, "build.py")
EXAMPLES = os.path.join(SKILL, "examples")

_spec = importlib.util.spec_from_file_location("human_page_build", BUILD)
build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(build)


def example(name):
    with open(os.path.join(EXAMPLES, name + ".json"), encoding="utf-8") as f:
        return json.load(f)


def at(d, path):
    for p in path:
        d = d[p]
    return d


def put(path, value):
    def f(d):
        at(d, path[:-1])[path[-1]] = value
    return f


def drop(path):
    def f(d):
        del at(d, path[:-1])[path[-1]]
    return f


def both(*fs):
    def f(d):
        for g in fs:
            g(d)
    return f


def run_cli(*args):
    p = subprocess.run([sys.executable, BUILD] + list(args), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, universal_newlines=True, encoding="utf-8")
    return p.returncode, p.stdout, p.stderr


CARD0 = ["sections", 0, "cards", 0]
CARD1 = ["sections", 0, "cards", 1]
GROUP0 = ["sections", 0, "groups", 0]
GROUP1 = ["sections", 0, "groups", 1]
ITEM0 = ["sections", 0, "items", 0]

# (名前, 見本, 壊し方, 期待する誤り [(規則, 場所)], --body があるか)
BROKEN = [
    # E-F1 format
    ("f1_format_2", "decide", put(["format"], 2), [("E-F1", "format")], False),
    ("f1_format_true", "decide", put(["format"], True), [("E-F1", "format")], False),
    ("f1_format_missing", "decide", drop(["format"]), [("E-F1", "format")], False),
    # E-F2 知らない項目
    ("f2_unknown_top", "decide", put(["titel"], "x"), [("E-F2", "titel")], False),
    ("f2_unknown_card", "decide", put(CARD0 + ["colour"], "red"), [("E-F2", "sections[0].cards[0].colour")], False),
    ("f2_unknown_source", "decide", put(["source", "owner"], "x"), [("E-F2", "source.owner")], False),
    ("f2_unknown_option", "decide", put(CARD0 + ["options", 0, "color"], "x"),
     [("E-F2", "sections[0].cards[0].options[0].color")], False),
    # E-F3 必須の項目と型
    ("f3_missing_why", "decide", drop(["why"]), [("E-F3", "why")], False),
    ("f3_title_number", "decide", put(["title"], 3), [("E-F3", "title")], False),
    ("f3_sections_object", "decide", put(["sections"], {}), [("E-F3", "sections")], False),
    ("f3_cards_string", "decide", put(["sections", 0, "cards"], "x"), [("E-F3", "sections[0].cards")], False),
    ("f3_source_string_stops_children", "decide", put(["source"], "shop"), [("E-F3", "source")], False),
    ("f3_missing_card_reason", "decide", drop(CARD0 + ["reason"]), [("E-F3", "sections[0].cards[0].reason")], False),
    # E-H1 ページの文字
    ("h1_title_blank", "decide", put(["title"], "   "), [("E-H1", "title")], False),
    ("h1_why_empty", "decide", put(["why"], ""), [("E-H1", "why")], False),
    ("h1_link_label_empty", "decide", put(["links", 0, "label"], ""), [("E-H1", "links[0].label")], False),
    ("h1_group_why_empty", "bundle", put(GROUP0 + ["why"], " "), [("E-H1", "sections[0].groups[0].why")], False),
    # E-H2 送り元とリンク
    ("h2_repo_empty", "decide", put(["source", "repo"], ""), [("E-H2", "source.repo")], False),
    ("h2_repo_blank", "decide", put(["source", "repo"], "  "), [("E-H2", "source.repo")], False),
    ("h2_issue_zero", "decide", put(["source", "issue"], 0), [("E-H2", "source.issue")], False),
    ("h2_issue_true", "decide", put(["source", "issue"], True), [("E-H2", "source.issue")], False),
    ("h2_issue_string", "decide", put(["source", "issue"], "212"), [("E-H2", "source.issue")], False),
    ("h2_repo_url_javascript", "decide", put(["source", "repo_url"], "javascript:alert(1)"),
     [("E-H2", "source.repo_url")], False),
    ("h2_link_url_relative", "decide", put(["links", 0, "url"], "docs/plan.md"), [("E-H2", "links[0].url")], False),
    ("h2_branch_empty", "decide", put(["source", "branch"], ""), [("E-H2", "source.branch")], False),
    ("h2_tmux_window_negative", "decide", put(["source", "tmux", "window"], -1), [("E-H2", "source.tmux.window")], False),
    ("h2_tmux_pane_true", "decide", put(["source", "tmux", "pane"], True), [("E-H2", "source.tmux.pane")], False),
    ("h2_tmux_name_empty", "decide", put(["source", "tmux", "name"], ""), [("E-H2", "source.tmux.name")], False),
    ("h2_group_repo_empty", "bundle", put(GROUP1 + ["source", "repo"], ""),
     [("E-H2", "sections[0].groups[1].source.repo")], False),
    # E-H3 決まった値
    ("h3_purpose", "decide", put(["purpose"], "decision"), [("E-H3", "purpose")], False),
    ("h3_status", "decide", put(["status"], "waiting"), [("E-H3", "status")], False),
    ("h3_purpose_number_is_f3", "decide", put(["purpose"], 3), [("E-F3", "purpose")], False),
    # E-P2 状態と部品・答え
    ("p2_awaiting_without_answer_part", "review", put(["status"], "awaiting"), [("E-P2", "status")], False),
    ("p2_answers_but_awaiting", "decide",
     put(["answers"], {"retry_policy": {"choice": "go", "note": "", "at": "2026-10-19T09:00:00Z"}}),
     [("E-P2", "answers")], False),
    ("p2_answered_without_answers", "decide", put(["status"], "answered"), [("E-P2", "answers")], False),
    # E-C1 カードの key
    ("c1_key_upper", "decide", put(CARD0 + ["key"], "Retry"), [("E-C1", "sections[0].cards[0].key")], False),
    ("c1_key_digit_first", "decide", put(CARD0 + ["key"], "1retry"), [("E-C1", "sections[0].cards[0].key")], False),
    ("c1_key_duplicate", "decide", put(CARD1 + ["key"], "retry_policy"), [("E-C1", "sections[0].cards[1].key")], False),
    ("c1_key_duplicate_across_groups", "bundle", put(GROUP1 + ["cards", 0, "key"], "pdf_engine"),
     [("E-C1", "sections[0].groups[1].cards[0].key")], False),
    # E-C2 選択肢
    ("c2_one_option", "decide", put(CARD0 + ["options"], [{"key": "go", "label": "進める"}]),
     [("E-C2", "sections[0].cards[0].options")], False),
    ("c2_option_key_duplicate", "decide", put(CARD0 + ["options", 1, "key"], "go"),
     [("E-C2", "sections[0].cards[0].options[1].key")], False),
    ("c2_option_key_shape", "decide", put(CARD0 + ["options", 1, "key"], "Fix!"),
     [("E-C2", "sections[0].cards[0].options[1].key")], False),
    # E-C3 推奨が選択肢に無い
    ("c3_recommend_missing_option", "decide", put(CARD0 + ["recommend"], "ok"),
     [("E-C3", "sections[0].cards[0].recommend")], False),
    # E-C4 根拠が空
    ("c4_reason_empty", "decide", put(CARD0 + ["reason"], " "), [("E-C4", "sections[0].cards[0].reason")], False),
    # E-C5 カードの文字
    ("c5_card_title_empty", "decide", put(CARD0 + ["title"], ""), [("E-C5", "sections[0].cards[0].title")], False),
    ("c5_point_empty", "decide", put(CARD0 + ["points", 0], ""), [("E-C5", "sections[0].cards[0].points[0]")], False),
    ("c5_point_text_empty", "decide", put(CARD0 + ["points", 1, "text"], ""),
     [("E-C5", "sections[0].cards[0].points[1].text")], False),
    ("c5_option_label_empty", "decide", put(CARD0 + ["options", 0, "label"], ""),
     [("E-C5", "sections[0].cards[0].options[0].label")], False),
    ("c5_tag_empty", "decide", put(CARD0 + ["tag"], ""), [("E-C5", "sections[0].cards[0].tag")], False),
    # E-T1 札の値
    ("t1_card_evidence", "decide", put(CARD0 + ["evidence"], "checked"), [("E-T1", "sections[0].cards[0].evidence")], False),
    ("t1_point_evidence", "decide", put(CARD0 + ["points", 1, "evidence"], "x"),
     [("E-T1", "sections[0].cards[0].points[1].evidence")], False),
    ("t1_option_kind", "decide", put(CARD0 + ["options", 0, "kind"], "danger"),
     [("E-T1", "sections[0].cards[0].options[0].kind")], False),
    ("t1_severity", "review", put(ITEM0 + ["severity"], "critical"), [("E-T1", "sections[0].items[0].severity")], False),
    ("t1_adopted", "review", put(ITEM0 + ["adopted"], "yes"), [("E-T1", "sections[0].items[0].adopted")], False),
    ("t1_finding_evidence", "review", put(ITEM0 + ["evidence"], "maybe"), [("E-T1", "sections[0].items[0].evidence")], False),
    # E-S1 部品
    ("s1_unknown_type", "decide", put(["sections", 0], {"type": "chart", "anything": [1, 2]}),
     [("E-S1", "sections[0].type")], False),
    ("s1_missing_type", "decide", drop(["sections", 0, "type"]), [("E-S1", "sections[0].type")], False),
    ("s1_no_cards", "decide", put(["sections", 0, "cards"], []), [("E-S1", "sections[0].cards")], False),
    ("s1_no_groups", "bundle", put(["sections", 0, "groups"], []), [("E-S1", "sections[0].groups")], False),
    ("s1_group_no_cards", "bundle", put(GROUP0 + ["cards"], []), [("E-S1", "sections[0].groups[0].cards")], False),
    ("s1_no_items", "review", put(["sections", 0, "items"], []), [("E-S1", "sections[0].items")], False),
    ("s1_no_sections_no_body", "grasp", lambda d: None, [("E-S1", "sections")], False),
    ("s1_section_title_empty", "decide", put(["sections", 0, "title"], ""), [("E-S1", "sections[0].title")], False),
    ("s1_group_title_empty", "bundle", put(GROUP0 + ["title"], ""), [("E-S1", "sections[0].groups[0].title")], False),
    # E-S2 指摘
    ("s2_finding_text_empty", "review", put(ITEM0 + ["text"], ""), [("E-S2", "sections[0].items[0].text")], False),
    ("s2_finding_reason_empty", "review", put(ITEM0 + ["reason"], "  "), [("E-S2", "sections[0].items[0].reason")], False),
    ("s2_lane_empty", "review", put(["sections", 0, "lane"], ""), [("E-S2", "sections[0].lane")], False),
    # E-A1 回収した答え
    ("a1_unknown_card", "decide",
     both(put(["status"], "answered"), put(["answers"], {"nope": {"choice": None, "note": "", "at": "2026-10-19T09:00:00Z"}})),
     [("E-A1", "answers.nope")], False),
    ("a1_choice_not_option", "decide",
     both(put(["status"], "answered"), put(["answers"], {"retry_policy": {"choice": "maybe", "note": "", "at": "2026-10-19T09:00:00Z"}})),
     [("E-A1", "answers.retry_policy.choice")], False),
    ("a1_note_number", "decide",
     both(put(["status"], "answered"), put(["answers"], {"retry_policy": {"choice": "go", "note": 3, "at": "2026-10-19T09:00:00Z"}})),
     [("E-A1", "answers.retry_policy.note")], False),
    ("a1_at_null", "decide",
     both(put(["status"], "answered"), put(["answers"], {"retry_policy": {"choice": "go", "note": "", "at": None}})),
     [("E-A1", "answers.retry_policy.at")], False),
    # 独立した誤り2つは2件とも出る
    ("two_independent_errors", "decide", both(put(["title"], ""), put(CARD0 + ["recommend"], "ok")),
     [("E-C3", "sections[0].cards[0].recommend"), ("E-H1", "title")], False),
]


class ExamplesPass(unittest.TestCase):
    def test_examples_have_no_errors(self):
        for name, has_body in (("decide", False), ("bundle", False), ("review", False), ("grasp", True)):
            with self.subTest(example=name):
                self.assertEqual(build.validate(example(name), has_body=has_body), [])

    def test_answered_with_null_choice_is_allowed(self):
        d = example("decide")
        d["status"] = "answered"
        d["answers"] = {"retry_policy": {"choice": None, "note": "まだ決めない", "at": "2026-10-19T09:00:00Z"},
                        "rollout": {"choice": "stage", "note": "", "at": "2026-10-19T09:01:00Z"}}
        self.assertEqual(build.validate(d), [])


class BrokenData(unittest.TestCase):
    """見本を1か所だけ壊したデータ。出た誤りが期待した規則と場所の1件だけであることを見る。"""


def _make_broken_test(base, mutate, expected, has_body):
    def test(self):
        d = copy.deepcopy(example(base))
        mutate(d)
        got = sorted((code, path) for code, path, _ in build.validate(d, has_body=has_body))
        self.assertEqual(got, sorted(expected))
    return test


for _name, _base, _mutate, _expected, _has_body in BROKEN:
    setattr(BrokenData, "test_" + _name, _make_broken_test(_base, _mutate, _expected, _has_body))


class EveryRuleIsCovered(unittest.TestCase):
    def test_every_rule_has_a_broken_case(self):
        rules = {"E-F1", "E-F2", "E-F3", "E-H1", "E-H2", "E-H3", "E-P2", "E-C1", "E-C2", "E-C3", "E-C4",
                 "E-C5", "E-T1", "E-S1", "E-S2", "E-A1"}
        covered = {code for _, _, _, expected, _ in BROKEN for code, _ in expected}
        self.assertEqual(rules - covered, set())


class LoadStage(unittest.TestCase):
    """データの中身より前の失敗は終了コード 2 と理由の文言で確かめる。"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, name, text):
        p = os.path.join(self.tmp, name)
        with open(p, "w", encoding="utf-8") as f:
            f.write(text)
        return p

    def test_example_check_exits_0(self):
        rc, _, err = run_cli("check", os.path.join(EXAMPLES, "decide.json"))
        self.assertEqual(rc, 0, err)

    def test_data_error_exits_1_with_rule_line(self):
        d = example("decide")
        d["sections"][0]["cards"][0]["recommend"] = "ok"
        rc, _, err = run_cli("check", self.write("d.json", json.dumps(d, ensure_ascii=False)))
        self.assertEqual(rc, 1)
        self.assertIn('E-C3 sections[0].cards[0].recommend: 推奨 "ok" が選択肢（go, fix）に無い', err)

    def test_invalid_json_exits_2(self):
        rc, _, err = run_cli("check", self.write("d.json", '{"format": 1,'))
        self.assertEqual(rc, 2)
        self.assertIn("JSON として読めない", err)

    def test_duplicate_key_exits_2(self):
        rc, _, err = run_cli("check", self.write("d.json", '{"format": 1, "title": "a", "title": "b"}'))
        self.assertEqual(rc, 2)
        self.assertIn('同じ項目名 "title" が1つのオブジェクトに2回ある', err)

    def test_missing_data_file_exits_2(self):
        rc, _, err = run_cli("check", os.path.join(self.tmp, "none.json"))
        self.assertEqual(rc, 2)
        self.assertIn("データ", err)
        self.assertIn("を読めない", err)

    def glossary_variant(self, old, new):
        with open(build.DEFAULT_GLOSSARY, encoding="utf-8") as f:
            text = f.read()
        self.assertEqual(text.count(old), 1, old)
        return self.write("glossary.md", text.replace(old, new))

    def check_glossary(self, path, expected):
        rc, _, err = run_cli("check", os.path.join(EXAMPLES, "decide.json"), "--glossary", path)
        self.assertEqual(rc, 2, err)
        self.assertIn("用語集", err)
        self.assertIn(expected, err)

    def test_glossary_missing_key_exits_2(self):
        self.check_glossary(self.glossary_variant("| `severity.low` | 低 |\n", ""), 'key "severity.low" が無い')

    def test_glossary_duplicate_key_exits_2(self):
        self.check_glossary(self.glossary_variant("| `severity.low` | 低 |\n", "| `severity.low` | 低 |\n| `severity.low` | 小 |\n"),
                            'key "severity.low" が2回ある')

    def test_glossary_unknown_key_exits_2(self):
        self.check_glossary(self.glossary_variant("| `severity.low` | 低 |\n", "| `severity.low` | 低 |\n| `severity.none` | なし |\n"),
                            '知らない key "severity.none" がある')

    def test_glossary_missing_placeholder_exits_2(self):
        self.check_glossary(self.glossary_variant("| `status.awaiting` | 回答待ち {n} 件 |", "| `status.awaiting` | 回答待ち |"),
                            'key "status.awaiting" の差し込みが {n} であるべき所が （なし） である')

    def test_glossary_extra_placeholder_exits_2(self):
        self.check_glossary(self.glossary_variant("| `status.live` | 随時更新 |", "| `status.live` | 随時更新 {n} |"),
                            'key "status.live" の差し込みが （なし） であるべき所が {n} である')


if __name__ == "__main__":
    unittest.main()

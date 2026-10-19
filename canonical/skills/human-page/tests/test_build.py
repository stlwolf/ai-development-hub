#!/usr/bin/env python3
"""build.py の検査。標準の unittest だけを使う。

走らせ方: python3 tests/test_build.py （どの作業ディレクトリからでもよい）

壊したデータの検査は、見本のデータを1か所だけ壊し、出た誤りが「期待した規則と場所の1件だけ」で
あることを確かめる。落ちたことだけを見ると、別の理由で落ちたものを見逃すためである。
"""

import copy
import html
import importlib.util
import json
import os
import re
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


def run_cli(*args, env=None):
    p = subprocess.run([sys.executable, BUILD] + list(args), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, universal_newlines=True, encoding="utf-8", env=env)
    return p.returncode, p.stdout, p.stderr


NOW = "2026-10-19T09:05:00+00:00"


def render_page(name, mutate=None, body=None, glossary=None, now=NOW):
    """見本を（必要なら壊さずに直してから）描く。tmux はデータに書いたものだけを使う（--tmux off と同じ）。"""
    d = copy.deepcopy(example(name))
    if mutate:
        mutate(d)
    errors = build.validate(d, has_body=body is not None)
    assert errors == [], errors
    labels = build.load_glossary(glossary or build.DEFAULT_GLOSSARY)
    return build.render(d, labels, build.parse_now(now), d["source"].get("tmux"), body)


def text_of(fragment, cls, nth=0):
    """class が cls の <p> の中身を、タグを除いて文字として返す。"""
    found = re.findall(r'<p class="%s"[^>]*>(.*?)</p>' % re.escape(cls), fragment, re.S)
    return html.unescape(re.sub(r"<[^>]+>", "", found[nth]))


def hrefs_of(fragment, cls, nth=0):
    found = re.findall(r'<p class="%s"[^>]*>(.*?)</p>' % re.escape(cls), fragment, re.S)
    return [html.unescape(h) for h in re.findall(r'href="([^"]*)"', found[nth])]


def embedded(fragment):
    m = re.search(r'<script type="application/json" id="hp-data">(.*?)</script>', fragment, re.S)
    return m.group(1)


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


class Header(unittest.TestCase):
    """ヘッダーの2行（送り元と、版と状態）。"""

    def test_two_lines(self):
        f = render_page("decide")
        self.assertEqual(text_of(f, "hp-src"), "shop ・ tmux 2.2「CC:shop」 ・ #212 ・ fix/#212_payment_retry")
        self.assertEqual(text_of(f, "hp-ver"), "版 2026-10-19 18:05 JST（最終更新） ・ 回答待ち 3 件")

    def test_source_links(self):
        self.assertEqual(hrefs_of(render_page("decide"), "hp-src"),
                         ["https://github.com/example-org/shop/issues/212",
                          "https://github.com/example-org/shop/tree/fix/%23212_payment_retry"])

    def test_missing_items_are_omitted_with_their_separators(self):
        cases = [
            (both(drop(["source", "issue"]), drop(["source", "branch"]), drop(["source", "tmux"])), "shop"),
            (drop(["source", "tmux"]), "shop ・ #212 ・ fix/#212_payment_retry"),
            (drop(["source", "issue"]), "shop ・ tmux 2.2「CC:shop」 ・ fix/#212_payment_retry"),
            (drop(["source", "branch"]), "shop ・ tmux 2.2「CC:shop」 ・ #212"),
        ]
        for mutate, want in cases:
            with self.subTest(want=want):
                self.assertEqual(text_of(render_page("decide", mutate), "hp-src"), want)

    def test_no_repo_url_means_no_links(self):
        f = render_page("decide", drop(["source", "repo_url"]))
        self.assertEqual(hrefs_of(f, "hp-src"), [])
        self.assertEqual(text_of(f, "hp-src"), "shop ・ tmux 2.2「CC:shop」 ・ #212 ・ fix/#212_payment_retry")

    def test_version_is_jst_whatever_the_offset(self):
        for now in ("2026-10-19T09:05:00+00:00", "2026-10-19T04:05:00-05:00", "2026-10-19T18:05:00+09:00",
                    "2026-10-19T09:05:00Z"):
            with self.subTest(now=now):
                self.assertTrue(text_of(render_page("decide", now=now), "hp-ver").startswith("版 2026-10-19 18:05 JST（最終更新）"))

    def test_status_labels(self):
        self.assertTrue(text_of(render_page("review"), "hp-ver").endswith(" ・ 随時更新"))
        answered = both(put(["status"], "answered"),
                        put(["answers"], {"retry_policy": {"choice": "go", "note": "", "at": "2026-10-19T09:00:00Z"}}))
        self.assertTrue(text_of(render_page("decide", answered), "hp-ver").endswith(" ・ 回答済み"))

    def test_tmux_is_omitted_outside_tmux(self):
        tmp = tempfile.mkdtemp()
        try:
            d = example("decide")
            del d["source"]["tmux"]
            data = os.path.join(tmp, "d.json")
            with open(data, "w", encoding="utf-8") as fh:
                json.dump(d, fh, ensure_ascii=False)
            env = dict(os.environ)
            env.pop("TMUX_PANE", None)
            out = os.path.join(tmp, "o.html")
            rc, _, err = run_cli("build", data, "-o", out, "--now", NOW, env=env)
            self.assertEqual(rc, 0, err)
            self.assertIn("送り元の tmux の項目を省いた: TMUX_PANE が無い", err)
            with open(out, encoding="utf-8") as fh:
                self.assertEqual(text_of(fh.read(), "hp-src"), "shop ・ #212 ・ fix/#212_payment_retry")
        finally:
            shutil.rmtree(tmp)


class Links(unittest.TestCase):
    def test_bundle_groups_link_to_their_own_repo(self):
        f = render_page("bundle")
        self.assertIn('href="https://github.com/example-org/billing/issues/28"', f)
        self.assertIn('href="https://github.com/example-org/billing/issues/31"', f)
        # repo_url の無い group（mobile）の #5 と #7 は、ページのリポジトリへ戻してリンクにしない。
        for n in (5, 7):
            self.assertNotIn("/issues/%d\"" % n, f)
        self.assertIn("#5 のコメント", f)

    def test_issue_ref_followed_by_word_char_is_not_linked(self):
        f = render_page("decide", put(CARD0 + ["points", 0], "feature/#212_x と #212 を見る。"))
        self.assertIn("feature/#212_x と ", f)
        self.assertIn('<a href="https://github.com/example-org/shop/issues/212" target="_blank" rel="noopener">#212</a> を見る。', f)

    def test_url_in_text_is_linked_without_trailing_punctuation(self):
        f = render_page("decide")
        self.assertIn('<a href="https://github.com/example-org/shop/blob/main/docs/rollout.md" target="_blank" '
                      'rel="noopener">https://github.com/example-org/shop/blob/main/docs/rollout.md</a> にある。', f)

    def test_code_span(self):
        self.assertIn("<code>charge</code>", render_page("decide"))


ATTACKS = ("</script><script>alert(1)</script>", "\"><img src=x onerror=alert(1)>", "`</code><b>`")


class Escaping(unittest.TestCase):
    """データと用語集の文字列は、要素にならず文字として出る。"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_attack_strings_stay_text(self):
        a, b, c = ATTACKS
        with open(build.DEFAULT_GLOSSARY, encoding="utf-8") as fh:
            g = fh.read().replace("| `text.why` | なぜこのページか |", "| `text.why` | <b>なぜ</b>" + a + " |")
        gpath = os.path.join(self.tmp, "glossary.md")
        with open(gpath, "w", encoding="utf-8") as fh:
            fh.write(g)
        mutate = both(put(["title"], a), put(["why"], b), put(CARD0 + ["points", 0], c + " " + a),
                      put(CARD0 + ["options", 1, "label"], b), put(["status"], "answered"),
                      put(["answers"], {"retry_policy": {"choice": "go", "note": a + b, "at": "2026-10-19T09:00:00Z"}}))
        f = render_page("decide", mutate, glossary=gpath)
        self.assertNotIn("<script>alert(1)", f)
        self.assertNotIn("<img src=x", f)
        self.assertNotIn("<b>", f)
        self.assertIn("&lt;/script&gt;&lt;script&gt;alert(1)&lt;/script&gt;", f)
        self.assertIn("<title>&lt;/script&gt;", f)
        self.assertIn("<code>&lt;/code&gt;&lt;b&gt;</code>", f)
        data = embedded(f)
        self.assertNotIn("<", data)
        self.assertIn(chr(92) + "u003c/script", data)
        self.assertEqual(json.loads(data)["title"], a)


class Contract(unittest.TestCase):
    """artifact の決まり（page contract）と、2つの出力の形。"""

    PAGES = (("decide", None), ("bundle", None), ("review", None), ("grasp", "grasp-body.html"))

    def pages(self):
        for name, body_file in self.PAGES:
            body = None
            if body_file:
                with open(os.path.join(EXAMPLES, body_file), encoding="utf-8") as fh:
                    body = fh.read()
            yield name, render_page(name, body=body)

    def test_fragment_has_no_document_skeleton(self):
        for name, f in self.pages():
            with self.subTest(page=name):
                self.assertIsNone(re.search(r"<!doctype|<html[\s>]|<head[\s>]|<body[\s>]", f, re.I))

    def test_title_is_in_first_8kb(self):
        for name, f in self.pages():
            with self.subTest(page=name):
                self.assertTrue(f.startswith("<title>"))
                self.assertLess(f.encode("utf-8").index(b"</title>"), 8192)

    def test_only_google_fonts_are_loaded(self):
        for name, f in self.pages():
            with self.subTest(page=name):
                loads = re.findall(r'<(?!a[\s>])[a-z]+\b[^>]*\b(?:src|href)\s*=\s*"([^"]*)"', f, re.I)
                self.assertTrue(loads)
                for u in loads:
                    self.assertTrue(u.startswith("https://fonts.googleapis.com/"), u)
                self.assertEqual(build.external_loads(f), [])

    def test_size_is_under_16mb(self):
        for name, f in self.pages():
            with self.subTest(page=name):
                self.assertLess(len(f.encode("utf-8")), 16 * 1024 * 1024)

    def test_standalone_only_wraps(self):
        for name, f in self.pages():
            with self.subTest(page=name):
                s = build.standalone(f)
                self.assertTrue(s.startswith(build.STANDALONE_HEAD))
                self.assertTrue(s.endswith(build.STANDALONE_TAIL))
                self.assertEqual(s[len(build.STANDALONE_HEAD):-len(build.STANDALONE_TAIL)], f)
                self.assertIn('<meta charset="utf-8">', build.STANDALONE_HEAD)

    def test_cli_outputs_differ_only_by_wrapping(self):
        tmp = tempfile.mkdtemp()
        try:
            a, b = os.path.join(tmp, "a.html"), os.path.join(tmp, "b.html")
            data = os.path.join(EXAMPLES, "decide.json")
            self.assertEqual(run_cli("build", data, "-o", a, "--now", NOW, "--tmux", "off")[0], 0)
            self.assertEqual(run_cli("build", data, "-o", b, "--now", NOW, "--tmux", "off", "--standalone")[0], 0)
            with open(a, encoding="utf-8") as fa, open(b, encoding="utf-8") as fb:
                self.assertEqual(build.standalone(fa.read()), fb.read())
        finally:
            shutil.rmtree(tmp)

    def test_theme_tokens(self):
        with open(build.CSS, encoding="utf-8") as fh:
            css = fh.read()
        root = re.search(r"^:root \{(.*?)^\}", css, re.S | re.M).group(1)
        defined = set(re.findall(r"(--[a-z0-9-]+):", root))
        dark_media = re.search(r'@media \(prefers-color-scheme: dark\) \{\s*:root:not\(\[data-theme="light"\]\) \{(.*?)\}', css, re.S)
        dark_attr = re.search(r':root\[data-theme="dark"\] \{(.*?)\}', css, re.S)
        self.assertIsNotNone(dark_media)
        self.assertIsNotNone(dark_attr)
        for block in (dark_media.group(1), dark_attr.group(1)):
            self.assertIn("color-scheme: dark", block)
            self.assertLessEqual(set(re.findall(r"(--[a-z0-9-]+):", block)), defined)
        self.assertEqual(set(re.findall(r"(--[a-z0-9-]+):", dark_media.group(1))),
                         set(re.findall(r"(--[a-z0-9-]+):", dark_attr.group(1))))
        body = re.search(r"^body \{(.*?)^\}", css, re.S | re.M).group(1)
        self.assertIn("background: var(--bg);", body)
        self.assertIn("padding-left: max(16px, env(safe-area-inset-left, 0px));", body)
        self.assertIn("padding-right: max(16px, env(safe-area-inset-right, 0px));", body)
        with open(os.path.join(EXAMPLES, "grasp-body.html"), encoding="utf-8") as fh:
            used = set(re.findall(r"var\((--[a-z0-9-]+)\)", css + fh.read()))
        self.assertEqual(used - defined, set())


class ExternalLoads(unittest.TestCase):
    """E-B1: 完成した HTML の外部の読み込み（--body から入ったものを含む）。"""

    def check(self, body, n):
        f = render_page("grasp", body=body)
        got = build.external_loads(f)
        self.assertEqual([(c, p) for c, p, _ in got], [("E-B1", "html")] * n, got)

    def test_external_script_in_body(self):
        self.check('<script src="https://evil.example/x.js"></script>', 1)

    def test_css_import_in_body(self):
        self.check('<style>@import "https://evil.example/x.css";</style>', 1)

    def test_css_url_in_style_attribute(self):
        self.check('<div style="background:url(https://evil.example/a.png)"></div>', 1)

    def test_allowed_loads(self):
        self.check('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">'
                   '<img src="data:image/png;base64,AAAA" alt="">', 0)

    def test_srcset_and_svg_images(self):
        self.check('<img srcset="data:image/png;base64,AAAA 1x, https://evil.example/a.png 2x" alt="">', 1)
        self.check('<link rel="preload" as="image" imagesrcset="https://evil.example/a.png 1x">', 1)
        self.check('<svg><image href="https://evil.example/a.svg"/></svg>', 1)
        self.check('<svg><image xlink:href="https://evil.example/a.svg"/></svg>', 1)
        self.check('<script src="//evil.example/x.js"></script>', 1)
        self.check('<base href="https://evil.example/">', 1)

    def test_css_urls_without_url_function(self):
        self.check('<style>.x { background-image: image-set("https://evil.example/a.png" 1x); }</style>', 1)
        self.check('<div style="background: url(//evil.example/a.png)"></div>', 1)

    def test_links_and_fragments_are_not_loads(self):
        self.check('<a href="https://evil.example/">リンク</a><svg><use href="#icon"/></svg>'
                   '<svg><image href="data:image/svg+xml;base64,AAAA"/></svg>', 0)

    def test_url_written_as_text_is_not_a_load(self):
        f = render_page("decide", put(["why"], "url(https://evil.example/a.png) と書いた文"))
        self.assertEqual(build.external_loads(f), [])

    def test_cli_refuses_to_write(self):
        tmp = tempfile.mkdtemp()
        try:
            body = os.path.join(tmp, "b.html")
            with open(body, "w", encoding="utf-8") as fh:
                fh.write('<script src="https://evil.example/x.js"></script>')
            out = os.path.join(tmp, "o.html")
            rc, _, err = run_cli("build", os.path.join(EXAMPLES, "grasp.json"), "--body", body, "-o", out, "--tmux", "off")
            self.assertEqual(rc, 1)
            self.assertIn("E-B1 html: 許していない外部の読み込みがある（<script src>: https://evil.example/x.js）", err)
            self.assertFalse(os.path.exists(out))
        finally:
            shutil.rmtree(tmp)


class GlossaryReachesEveryOutput(unittest.TestCase):
    """用語集の1行を直すと、静的に描く文字・JS が使う文字の両方が変わる。"""

    def test_changed_words(self):
        tmp = tempfile.mkdtemp()
        try:
            with open(build.DEFAULT_GLOSSARY, encoding="utf-8") as fh:
                g = fh.read()
            g = g.replace("| `status.awaiting` | 回答待ち {n} 件 |", "| `status.awaiting` | 答え待ち {n} 件 |")
            g = g.replace("| `evidence.verified` | 確かめた |", "| `evidence.verified` | 確認済み |")
            g = g.replace("| `text.reply_heading` | 「{title}」への答え（版 {time}） |",
                          "| `text.reply_heading` | 「{title}」の返事（{time}） |")
            path = os.path.join(tmp, "glossary.md")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(g)
            f = render_page("decide", glossary=path)
            self.assertTrue(text_of(f, "hp-ver").endswith(" ・ 答え待ち 3 件"))
            self.assertIn(">確認済み</span>", f)
            labels = json.loads(embedded(f))["labels"]
            self.assertEqual(labels["status.awaiting"], "答え待ち {n} 件")
            self.assertEqual(labels["text.reply_heading"], "「{title}」の返事（{time}）")
        finally:
            shutil.rmtree(tmp)


class ElementIds(unittest.TestCase):
    """カードと選択肢の key がどう組み合わさっても、要素の id は重ならない。"""

    def ids(self, f):
        return re.findall(r'\bid="([^"]*)"', f)

    def test_ids_are_unique_in_every_example(self):
        for name, body in (("decide", None), ("bundle", None), ("review", None)):
            with self.subTest(page=name):
                ids = self.ids(render_page(name, body=body))
                self.assertEqual(len(ids), len(set(ids)))

    def test_hyphenated_keys_do_not_collide(self):
        cards = [
            {"key": "a-b", "title": "1", "recommend": "c", "reason": "r",
             "options": [{"key": "c", "label": "C"}, {"key": "d", "label": "D"}]},
            {"key": "a", "title": "2", "recommend": "b-c", "reason": "r",
             "options": [{"key": "b-c", "label": "BC"}, {"key": "e", "label": "E"}]},
        ]
        f = render_page("decide", put(["sections", 0, "cards"], cards))
        ids = self.ids(f)
        self.assertEqual(len(ids), len(set(ids)), [i for i in ids if ids.count(i) > 1])
        self.assertIn('id="hp-opt-a-b.c"', f)
        self.assertIn('id="hp-opt-a.b-c"', f)


class AnsweredPage(unittest.TestCase):
    def render(self):
        return render_page("decide", both(put(["status"], "answered"), put(["answers"], {
            "retry_policy": {"choice": "go", "note": "上限は5回にしたい", "at": "2026-10-19T09:00:00Z"},
            "rollout": {"choice": "stage", "note": "", "at": "2026-10-19T09:01:00Z"}})))

    def test_inputs_are_locked_and_show_collected_answers(self):
        f = self.render()
        buttons = re.findall(r'<button type="button" class="hp-opt[^"]*" id="hp-opt-([a-z0-9_-]+)\.([a-z0-9_-]+)" aria-pressed="(true|false)"( disabled)?>', f)
        self.assertEqual(len(buttons), 7)
        self.assertTrue(all(b[3] == " disabled" for b in buttons))
        self.assertEqual(sorted((b[0], b[1]) for b in buttons if b[2] == "true"), [("retry_policy", "go"), ("rollout", "stage")])
        self.assertEqual(f.count('<p class="hp-unanswered">未回答</p>'), 1)
        self.assertRegex(f, r'<textarea class="hp-note" id="hp-note-retry_policy"[^>]* disabled>上限は5回にしたい</textarea>')
        self.assertIn('<p class="hp-notice">', f)
        self.assertNotIn('id="hp-store"', f)
        self.assertNotIn('id="hp-reply"', f)
        self.assertEqual(json.loads(embedded(f))["answers"]["retry_policy"]["choice"], "go")

    def test_awaiting_page_is_open(self):
        f = render_page("decide")
        self.assertNotIn(" disabled", f)
        self.assertIn('id="hp-store"', f)
        self.assertIn('id="hp-reply" hidden', f)
        self.assertIsNone(json.loads(embedded(f))["answers"])


class SourceCommand(unittest.TestCase):
    def test_remote_urls(self):
        cases = {
            "git@github.com:example-org/shop.git": "https://github.com/example-org/shop",
            "ssh://git@github.com/example-org/shop.git": "https://github.com/example-org/shop",
            "https://github.com/example-org/shop.git": "https://github.com/example-org/shop",
            "https://user@gitlab.example.com/group/shop": "https://gitlab.example.com/group/shop",
            "/srv/git/shop.git": None,
        }
        for remote, want in cases.items():
            with self.subTest(remote=remote):
                self.assertEqual(build._https_remote(remote), want)

    @unittest.skipIf(shutil.which("git") is None, "git が無い")
    def test_source_from_git(self):
        tmp = tempfile.mkdtemp()
        try:
            for args in (["init", "-q"], ["remote", "add", "origin", "git@github.com:example-org/shop.git"],
                         ["checkout", "-q", "-b", "fix/#212_payment_retry"]):
                subprocess.run(["git", "-C", tmp] + args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            rc, out, err = run_cli("source", "--git", tmp, "--tmux", "off")
            self.assertEqual(rc, 0, err)
            self.assertEqual(json.loads(out), {"repo": "shop", "repo_url": "https://github.com/example-org/shop",
                                               "branch": "fix/#212_payment_retry"})
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()

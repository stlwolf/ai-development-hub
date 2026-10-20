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

_spec = importlib.util.spec_from_file_location("html_one_pager_build", BUILD)
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


def meta_of(fragment, nth=0):
    """nth 番目の項目名と値の表を [(項目名, 値の文字)] で返す（0 はヘッダー、1 以降は束の group）。"""
    tables = re.findall(r'<dl class="hp-meta">(.*?)</dl>', fragment, re.S)
    rows = re.findall(r'<dt>(.*?)</dt><dd>(.*?)</dd>', tables[nth], re.S)
    return [(html.unescape(k), html.unescape(re.sub(r"<[^>]+>", "", v))) for k, v in rows]


def meta_hrefs(fragment, nth=0):
    tables = re.findall(r'<dl class="hp-meta">(.*?)</dl>', fragment, re.S)
    return [html.unescape(h) for h in re.findall(r'href="([^"]*)"', tables[nth])]


def embedded(fragment):
    m = re.search(r'<script type="application/json" id="hp-data">(.*?)</script>', fragment, re.S)
    return m.group(1)


CARD0 = ["sections", 0, "cards", 0]
CARD1 = ["sections", 0, "cards", 1]
GROUP0 = ["sections", 0, "groups", 0]
GROUP1 = ["sections", 0, "groups", 1]
ITEM0 = ["sections", 0, "items", 0]
COL0 = ["sections", 0, "columns", 0]
COL1 = ["sections", 0, "columns", 1]
ROW0 = ["sections", 0, "rows", 0]
TRACKER0 = ["source", "trackers", 0]
OPS = {"prefix": "OPS", "url": "https://tracker.example.com/browse/{id}"}
BLOCKS = ["sections", 0, "cards", 0, "blocks"]
BLOCK0 = BLOCKS + [0]

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
    ("f3_missing_card_recommend", "decide", drop(CARD0 + ["recommend"]), [("E-F3", "sections[0].cards[0].recommend")], False),
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
    ("h2_url_trailing_newline", "decide", put(["links", 0, "url"], "https://github.com/example-org/shop\n"),
     [("E-H2", "links[0].url")], False),
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
    ("c1_key_trailing_newline", "decide", put(CARD0 + ["key"], "retry_policy\n"), [("E-C1", "sections[0].cards[0].key")], False),
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
    ("c2_option_key_trailing_newline", "decide", put(CARD0 + ["options", 1, "key"], "fix\n"),
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
    # 表の部品（E-S1・E-S3・E-F2・E-F3・E-T1・E-L1）
    ("s1_table_no_columns", "table", put(["sections", 0, "columns"], []), [("E-S1", "sections[0].columns")], False),
    ("s1_table_no_rows", "table", put(["sections", 0, "rows"], []), [("E-S1", "sections[0].rows")], False),
    ("s1_table_title_empty", "table", put(["sections", 0, "title"], ""), [("E-S1", "sections[0].title")], False),
    # 列の定義が壊れていると、行の key（no）を照らさない。誤りは列の1件だけ
    ("s3_column_key_shape_stops_rows", "table", put(COL0 + ["key"], "No"), [("E-S3", "sections[0].columns[0].key")], False),
    ("s3_column_key_duplicate", "table", put(COL1 + ["key"], "no"), [("E-S3", "sections[0].columns[1].key")], False),
    ("s3_column_label_blank", "table", put(COL0 + ["label"], " "), [("E-S3", "sections[0].columns[0].label")], False),
    ("s3_column_type_unknown", "table", put(COL1 + ["type"], "link"), [("E-S3", "sections[0].columns[1].type")], False),
    ("s3_cell_text_empty", "table", put(ROW0 + ["what", "text"], ""), [("E-S3", "sections[0].rows[0].what.text")], False),
    ("f2_row_unknown_key", "table", put(ROW0 + ["extra"], "x"), [("E-F2", "sections[0].rows[0].extra")], False),
    ("f2_cell_unknown_item", "table", put(ROW0 + ["what", "colour"], "x"), [("E-F2", "sections[0].rows[0].what.colour")], False),
    ("f3_row_missing_key", "table", drop(ROW0 + ["result"]), [("E-F3", "sections[0].rows[0].result")], False),
    ("f3_text_cell_number", "table", put(ROW0 + ["no"], 1), [("E-F3", "sections[0].rows[0].no")], False),
    ("f3_ref_cell_object", "table", put(ROW0 + ["refs"], {"x": 1}), [("E-F3", "sections[0].rows[0].refs")], False),
    ("f3_ref_item_number", "table", put(ROW0 + ["refs"], ["#212", 215]), [("E-F3", "sections[0].rows[0].refs[1]")], False),
    ("t1_cell_evidence", "table", put(ROW0 + ["what", "evidence"], "checked"), [("E-T1", "sections[0].rows[0].what.evidence")], False),
    ("l1_number_and_id_in_one_cell", "table", put(ROW0 + ["refs"], ["A1 #212"]), [("E-L1", "sections[0].rows[0].refs[0]")], False),
    ("l1_empty_ref_string", "table", put(ROW0 + ["tracker"], ""), [("E-L1", "sections[0].rows[0].tracker")], False),
    ("l1_issue_number_too_long", "table", put(ROW0 + ["refs"], ["#12345678"]), [("E-L1", "sections[0].rows[0].refs[0]")], False),
    ("l1_unregistered_prefix", "table", put(ROW0 + ["tracker"], "ENG-3"), [("E-L1", "sections[0].rows[0].tracker")], False),
    ("l1_issue_without_repo_url", "table", drop(["source", "repo_url"]),
     [("E-L1", "sections[0].rows[0].refs[0]"), ("E-L1", "sections[0].rows[0].refs[1]"), ("E-L1", "sections[0].rows[1].refs[0]")], False),
    # 送り元の trackers（E-H2・E-F2・E-F3）。送り元が壊れていると、識別子をリンクにできるかは判定しない（E-L1 を重ねない）
    ("h2_tracker_prefix_lowercase_stops_l1", "table", put(TRACKER0 + ["prefix"], "ops"), [("E-H2", "source.trackers[0].prefix")], False),
    ("h2_tracker_prefix_duplicate", "table", put(["source", "trackers"], [OPS, dict(OPS)]), [("E-H2", "source.trackers[1].prefix")], False),
    ("h2_tracker_url_without_id", "table", put(TRACKER0 + ["url"], "https://tracker.example.com/browse/"),
     [("E-H2", "source.trackers[0].url")], False),
    ("h2_tracker_url_two_ids", "table", put(TRACKER0 + ["url"], "https://tracker.example.com/{id}/{id}"),
     [("E-H2", "source.trackers[0].url")], False),
    ("h2_tracker_url_javascript", "table", put(TRACKER0 + ["url"], "javascript:{id}"), [("E-H2", "source.trackers[0].url")], False),
    ("f2_tracker_unknown_item", "table", put(TRACKER0 + ["name"], "x"), [("E-F2", "source.trackers[0].name")], False),
    ("f3_trackers_object", "table", put(["source", "trackers"], {}), [("E-F3", "source.trackers")], False),
    ("h2_group_tracker_prefix", "bundle", put(GROUP0 + ["source", "trackers"], [{"prefix": "ops", "url": OPS["url"]}]),
     [("E-H2", "sections[0].groups[0].source.trackers[0].prefix")], False),
    # カードの塊（blocks）
    ("c5_blocks_empty", "confirm", put(BLOCKS, []), [("E-C5", "sections[0].cards[0].blocks")], False),
    ("c5_block_title_empty", "confirm", put(BLOCK0 + ["title"], ""), [("E-C5", "sections[0].cards[0].blocks[0].title")], False),
    ("c5_block_points_empty", "confirm", put(BLOCK0 + ["points"], []), [("E-C5", "sections[0].cards[0].blocks[0].points")], False),
    ("c5_block_point_empty", "confirm", put(BLOCK0 + ["points", 0], " "), [("E-C5", "sections[0].cards[0].blocks[0].points[0]")], False),
    ("f3_blocks_object", "confirm", put(BLOCKS, {}), [("E-F3", "sections[0].cards[0].blocks")], False),
    ("f3_block_missing_points", "confirm", drop(BLOCK0 + ["points"]), [("E-F3", "sections[0].cards[0].blocks[0].points")], False),
    ("f2_block_unknown_item", "confirm", put(BLOCK0 + ["heading"], "x"), [("E-F2", "sections[0].cards[0].blocks[0].heading")], False),
    ("t1_block_point_evidence", "confirm", put(["sections", 0, "cards", 0, "blocks", 1, "points", 0, "evidence"], "maybe"),
     [("E-T1", "sections[0].cards[0].blocks[1].points[0].evidence")], False),
    # 独立した誤り2つは2件とも出る
    ("two_independent_errors", "decide", both(put(["title"], ""), put(CARD0 + ["recommend"], "ok")),
     [("E-C3", "sections[0].cards[0].recommend"), ("E-H1", "title")], False),
]


class ExamplesPass(unittest.TestCase):
    def test_examples_have_no_errors(self):
        for name, has_body in (("decide", False), ("bundle", False), ("review", False), ("grasp", True), ("table", False), ("confirm", False)):
            with self.subTest(example=name):
                self.assertEqual(build.validate(example(name), has_body=has_body), [])

    def test_card_without_reason_is_allowed(self):
        # 根拠（reason）は任意。書いたのに空なら E-C4（BROKEN の c4_reason_empty）
        d = example("decide")
        del d["sections"][0]["cards"][0]["reason"]
        self.assertEqual(build.validate(d), [])

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
                 "E-C5", "E-T1", "E-S1", "E-S2", "E-S3", "E-L1", "E-A1"}
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

    def test_check_with_body_accepts_a_reading_page(self):
        # SKILL.md のコマンドの節に載せた check --body の形。--body が無ければ、部品も本文も無いページとして止まる
        data = os.path.join(EXAMPLES, "grasp.json")
        rc, _, err = run_cli("check", data, "--body", os.path.join(EXAMPLES, "grasp-body.html"))
        self.assertEqual(rc, 0, err)
        rc, _, err = run_cli("check", data)
        self.assertEqual(rc, 1)
        self.assertIn("E-S1 sections: 部品が1つも無く、--body の本文も無い", err)

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


FULL_META = [("リポジトリ", "shop"), ("tmux", "2.2（CC:shop）"), ("issue", "#212"),
             ("ブランチ", "fix/#212_payment_retry"), ("版", "2026-10-19 18:05 JST（最終更新）"), ("状態", "回答待ち 3 件")]


def without(rows, *labels):
    return [r for r in rows if r[0] not in labels]


class Header(unittest.TestCase):
    """ヘッダーの表（リポジトリ・tmux・issue・ブランチ・版・状態）。無い項目は行ごと省く。"""

    def test_six_rows(self):
        self.assertEqual(meta_of(render_page("decide")), FULL_META)

    def test_source_links(self):
        self.assertEqual(meta_hrefs(render_page("decide")),
                         ["https://github.com/example-org/shop/issues/212",
                          "https://github.com/example-org/shop/tree/fix/%23212_payment_retry"])

    def test_missing_items_are_omitted_as_rows(self):
        cases = [
            (both(drop(["source", "issue"]), drop(["source", "branch"]), drop(["source", "tmux"])),
             without(FULL_META, "tmux", "issue", "ブランチ")),
            (drop(["source", "tmux"]), without(FULL_META, "tmux")),
            (drop(["source", "issue"]), without(FULL_META, "issue")),
            (drop(["source", "branch"]), without(FULL_META, "ブランチ")),
        ]
        for mutate, want in cases:
            with self.subTest(want=[r[0] for r in want]):
                self.assertEqual(meta_of(render_page("decide", mutate)), want)

    def test_tmux_value_has_no_tmux_word(self):
        rows = dict(meta_of(render_page("decide")))
        self.assertEqual(rows["tmux"], "2.2（CC:shop）")
        self.assertNotIn("tmux", rows["tmux"])

    def test_no_repo_url_means_no_links(self):
        f = render_page("decide", drop(["source", "repo_url"]))
        self.assertEqual(meta_hrefs(f), [])
        self.assertEqual(meta_of(f), FULL_META)

    def test_version_is_jst_whatever_the_offset(self):
        for now in ("2026-10-19T09:05:00+00:00", "2026-10-19T04:05:00-05:00", "2026-10-19T18:05:00+09:00",
                    "2026-10-19T09:05:00Z"):
            with self.subTest(now=now):
                self.assertEqual(dict(meta_of(render_page("decide", now=now)))["版"], "2026-10-19 18:05 JST（最終更新）")

    def test_status_labels(self):
        self.assertEqual(dict(meta_of(render_page("review")))["状態"], "随時更新")
        answered = both(put(["status"], "answered"),
                        put(["answers"], {"retry_policy": {"choice": "go", "note": "", "at": "2026-10-19T09:00:00Z"}}))
        self.assertEqual(dict(meta_of(render_page("decide", answered)))["状態"], "回答済み")

    def test_purpose_label(self):
        f = render_page("decide")
        self.assertIn('<section class="hp-why"><p class="hp-lbl">目的</p>', f)

    def test_bundle_groups_use_the_same_table(self):
        f = render_page("bundle")
        self.assertEqual(meta_of(f, 1), [("リポジトリ", "billing"), ("tmux", "3.2（CC:billing）"), ("issue", "#31"),
                                         ("ブランチ", "feature/#31_invoice_pdf"), ("状態", "回答待ち 1 件")])
        self.assertEqual(meta_of(f, 2), [("リポジトリ", "mobile"), ("issue", "#7"), ("ブランチ", "fix/#7_login_loop"),
                                         ("状態", "回答待ち 1 件")])

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
                self.assertEqual(meta_of(fh.read()), without(FULL_META, "tmux"))
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


def a_tag(url, text):
    return '<a href="%s" target="_blank" rel="noopener">%s</a>' % (url, text)


TRACKER_URL = "https://tracker.example.com/browse/"


class TableAndTrackerLinks(unittest.TestCase):
    """表の識別子の列と、外部の課題管理の ID のリンク。"""

    def test_ref_cells_keep_their_text_and_link(self):
        f = render_page("table")
        self.assertIn(a_tag("https://github.com/example-org/shop/issues/212", "#212"), f)
        self.assertIn(a_tag("https://github.com/example-org/shop/issues/215", "PR #215"), f)
        self.assertIn(a_tag(TRACKER_URL + "OPS-42", "OPS-42") + a_tag(TRACKER_URL + "OPS-43", "OPS-43"), f)
        # 空の配列は空の欄になる
        self.assertIn('<td class="hp-ref-cell" data-label="外部の課題"></td>', f)
        self.assertIn('<td class="hp-ref-cell" data-label="issue / PR"></td>', f)

    def test_cells_are_labelled_for_narrow_screens(self):
        f = render_page("table")
        self.assertEqual(re.findall(r"<th>(.*?)</th>", f), ["番号", "issue / PR", "外部の課題", "中身", "結果"])
        self.assertEqual(f.count('data-label="番号"'), 3)
        self.assertIn('<td data-label="結果"></td>', f)

    def test_text_cells_use_the_same_conversion(self):
        f = render_page("table")
        self.assertIn("<code>charge</code>", f)
        self.assertIn(a_tag(TRACKER_URL + "OPS-41", "OPS-41") + " の記録を元にする。", f)
        self.assertIn('<span class="hp-chip hp-ev-sourced">出典あり・未確認</span>', f)

    def test_ids_in_text_are_linked_only_where_they_stand_alone(self):
        text = ("OPS-41 と `OPS-42` と https://x.example/OPS-43 と XOPS-44 と OPSX-45 と "
                "feature/OPS-46_x と ENG-47 と（OPS-48）。")
        f = render_page("decide", both(put(["source", "trackers"], [OPS]), put(CARD0 + ["points", 0], text)))
        point = re.search(r'<ul class="hp-points"><li>(.*?)</li>', f).group(1)
        self.assertEqual(re.findall(r'href="([^"]*)"', point),
                         [TRACKER_URL + "OPS-41", "https://x.example/OPS-43", TRACKER_URL + "OPS-48"])
        self.assertIn("<code>OPS-42</code>", point)
        for plain in ("XOPS-44", "OPSX-45", "feature/OPS-46_x", "ENG-47"):
            self.assertIn(" %s " % plain, point)

    def test_longer_prefix_is_not_cut_by_a_shorter_one(self):
        trackers = [{"prefix": "OP", "url": "https://a.example/{id}"}, {"prefix": "OPS", "url": "https://b.example/{id}"}]
        f = render_page("decide", both(put(["source", "trackers"], trackers), put(CARD0 + ["points", 0], "OP-1 と OPS-2")))
        self.assertIn(a_tag("https://a.example/OP-1", "OP-1") + " と " + a_tag("https://b.example/OPS-2", "OPS-2"), f)

    def test_groups_use_only_their_own_trackers(self):
        g0 = {"prefix": "OPS", "url": "https://billing.example/{id}"}
        mutate = both(put(["source", "trackers"], [OPS]), put(GROUP0 + ["source", "trackers"], [g0]),
                      put(GROUP0 + ["cards", 0, "points", 1], "OPS-1 を見る。"),
                      put(GROUP1 + ["cards", 0, "points", 0], "OPS-2 を見る。"))
        f = render_page("bundle", mutate)
        self.assertIn(a_tag("https://billing.example/OPS-1", "OPS-1"), f)
        # group の送り元に trackers が無ければ、ページの送り元へは戻らない
        self.assertIn("<li>OPS-2 を見る。", f)
        self.assertNotIn("OPS-2</a>", f)

    def test_titles_and_buttons_are_not_converted(self):
        mutate = both(put(["source", "trackers"], [OPS]), put(["title"], "OPS-41 の判断"),
                      put(CARD0 + ["options", 1, "label"], "OPS-41 に寄せる"))
        f = render_page("decide", mutate)
        self.assertIn("<title>OPS-41 の判断</title>", f)
        self.assertIn('<h1 class="hp-title">OPS-41 の判断</h1>', f)
        self.assertRegex(f, r'<button [^>]*>OPS-41 に寄せる</button>')

    def test_trackers_without_ids_change_nothing(self):
        self.assertEqual(render_page("decide", put(["source", "trackers"], [OPS])), render_page("decide"))


ATTACKS =("</script><script>alert(1)</script>", "\"><img src=x onerror=alert(1)>", "`</code><b>`")


class Escaping(unittest.TestCase):
    """データと用語集の文字列は、要素にならず文字として出る。"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_attack_strings_stay_text(self):
        a, b, c = ATTACKS
        with open(build.DEFAULT_GLOSSARY, encoding="utf-8") as fh:
            g = fh.read().replace("| `text.why` | 目的 |", "| `text.why` | <b>目的</b>" + a + " |")
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

    def test_table_strings_stay_text(self):
        # 列の見出し（th と data-label 属性）・欄の文字・trackers から作る URL（href 属性）
        a, b, c = ATTACKS
        mutate = both(put(["sections", 0, "columns", 3, "label"], b), put(ROW0 + ["what"], a),
                      put(["sections", 0, "rows", 1, "result"], c + " " + a),
                      put(TRACKER0 + ["url"], 'https://tracker.example.com/{id}"onmouseover="alert(1)'))
        f = render_page("table", mutate)
        self.assertNotIn("<script>alert(1)", f)
        self.assertNotIn("<img src=x", f)
        self.assertNotIn('"onmouseover="', f)
        self.assertIn("<th>&quot;&gt;&lt;img src=x onerror=alert(1)&gt;</th>", f)
        self.assertIn('data-label="&quot;&gt;&lt;img src=x onerror=alert(1)&gt;"', f)
        self.assertIn('href="https://tracker.example.com/OPS-41&quot;onmouseover=&quot;alert(1)"', f)
        self.assertIn("<code>&lt;/code&gt;&lt;b&gt;</code>", f)


class Contract(unittest.TestCase):
    """artifact の決まり（page contract）と、2つの出力の形。"""

    PAGES = (("decide", None), ("bundle", None), ("review", None), ("grasp", "grasp-body.html"), ("table", None), ("confirm", None))

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
        # artifact の外で開いたときも hidden が効く（部品の display が hidden を上書きしない）。
        self.assertIn("[hidden] { display: none !important; }", css)
        body = re.search(r"^body \{(.*?)^\}", css, re.S | re.M).group(1)
        self.assertIn("background: var(--bg);", body)
        self.assertIn("padding-left: max(16px, env(safe-area-inset-left, 0px));", body)
        self.assertIn("padding-right: max(16px, env(safe-area-inset-right, 0px));", body)
        with open(os.path.join(EXAMPLES, "grasp-body.html"), encoding="utf-8") as fh:
            used = set(re.findall(r"var\((--[a-z0-9-]+)\)", css + fh.read()))
        self.assertEqual(used - defined, set())


def main_of(fragment):
    """部品が描く <main class="hp-main"> の中身を返す。"""
    start = fragment.index('<main class="hp-main">') + len('<main class="hp-main">')
    return fragment[start:fragment.index("</main>")]


# 部品が描く要素のうち、本文の素の要素の規則に当たりうるもの
BARE_TAGS = ("section", "h2", "h3", "p", "ul", "ol", "table", "pre")
GENERATED_PAGES = ("decide", "bundle", "review", "table", "confirm")


class BodyLooks(unittest.TestCase):
    """本文（--body）の素の要素の見た目と、本文で使える class の一覧。"""

    def test_listed_classes_are_defined_in_css(self):
        with open(os.path.join(SKILL, "SKILL.md"), encoding="utf-8") as fh:
            text = fh.read()
        sec = re.search(r"^## 本文（`--body`）の見た目\n(.*?)^## ", text, re.S | re.M).group(1)
        listed = set(re.findall(r"`(hp-[a-z0-9-]+)`", sec))
        self.assertGreaterEqual(len(listed), 10)
        with open(build.CSS, encoding="utf-8") as fh:
            defined = set(re.findall(r"\.(hp-[a-z0-9-]+)", fh.read()))
        self.assertEqual(listed - defined, set())

    def test_bare_rules_only_touch_elements_without_class(self):
        # セレクター全体を :where() で包み（詳細度 0）、.hp-main の中の class を持たない要素だけに当てる。
        with open(build.CSS, encoding="utf-8") as fh:
            css = re.sub(r"/\*.*?\*/", "", fh.read(), flags=re.S)
        selectors = [s.strip() for s in re.findall(r"([^{}]*:not\(\[class\]\)[^{}]*)\{", css)]
        self.assertGreaterEqual(len(selectors), 9)
        part_re = r"^\.hp-main (%s):not\(\[class\]\)( (th|td))?$" % "|".join(BARE_TAGS)
        for sel in selectors:
            with self.subTest(selector=sel):
                self.assertTrue(sel.startswith(":where(") and sel.endswith(")"))
                for part in sel[len(":where("):-1].split(","):
                    self.assertRegex(part.strip(), part_re)

    def test_generated_parts_do_not_meet_bare_rules(self):
        # 部品が .hp-main の中に描く要素は class を持つので、素の要素の規則は部品に効かない。
        for name in GENERATED_PAGES:
            with self.subTest(page=name):
                found = re.findall(r"<(%s)\b([^>]*)>" % "|".join(BARE_TAGS), main_of(render_page(name)))
                self.assertTrue(found)
                for tag, attrs in found:
                    self.assertIn('class="', attrs, tag)


class SkillMdExamples(unittest.TestCase):
    """SKILL.md に載せた JSON の例は、載せた形のまま検証を通る（部品・カード・送り元・保存される答え）。"""

    def test_json_examples_validate(self):
        with open(os.path.join(SKILL, "SKILL.md"), encoding="utf-8") as fh:
            blocks = re.findall(r"^```json\n(.*?)^```", fh.read(), re.S | re.M)
        self.assertGreaterEqual(len(blocks), 3)
        for i, text in enumerate(blocks):
            with self.subTest(block=i, head=text[:40]):
                obj = json.loads(text)
                if "type" in obj:
                    d = example("table")
                    d["sections"] = [obj]
                elif "options" in obj:
                    d = example("decide")
                    d["sections"][0]["cards"] = [obj]
                elif "repo" in obj:
                    d = example("table")
                    d["source"] = obj
                elif "choice" in obj:
                    d = example("decide")
                    d["status"] = "answered"
                    d["answers"] = {obj["key"]: {k: obj[k] for k in ("choice", "note", "at")}}
                else:
                    self.fail("検査の知らない形の例である")
                self.assertEqual(build.validate(d), [])


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

    def test_quoted_greater_than_does_not_end_the_tag(self):
        self.check('<img alt=">" src="https://evil.example/a.png">', 1)
        self.check("<img alt='a>b' srcset='https://evil.example/a.png 1x'>", 1)

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
            self.assertEqual(dict(meta_of(f))["状態"], "答え待ち 3 件")
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
        for name, body in (("decide", None), ("bundle", None), ("review", None), ("table", None), ("confirm", None)):
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


class Reason(unittest.TestCase):
    """根拠を書かないカードには根拠の行が出ず、推奨の行と選択肢はそのまま出る。"""

    def test_card_without_reason_has_no_reason_line(self):
        f = render_page("decide", drop(CARD0 + ["reason"]))
        card = re.search(r'<article class="hp-card" id="hp-card-retry_policy">(.*?)</article>', f, re.S).group(1)
        self.assertNotIn("hp-reason", card)
        self.assertIn('<p class="hp-rec"><span class="hp-chip hp-chip-rec">推奨</span><span class="hp-rec-choice">この形で進める</span></p>', card)
        self.assertEqual(f.count('<p class="hp-reason">'), 2)

    def test_reply_and_saved_data_do_not_carry_reason(self):
        f = render_page("decide", drop(CARD0 + ["reason"]))
        self.assertEqual(json.loads(embedded(f))["cards"], json.loads(embedded(render_page("decide")))["cards"])


class Blocks(unittest.TestCase):
    """カードの小見出し付きの要点の塊。"""

    def test_blocks_follow_points_with_a_lower_heading(self):
        f = render_page("confirm")
        card = re.search(r'<article class="hp-card" id="hp-card-intake_216">(.*?)</article>', f, re.S).group(1)
        self.assertEqual(re.findall(r'<h4 class="hp-block-title">(.*?)</h4>', card),
                         ["この issue でやること", "issue に書いていないが要ること", "どの観点で見たか"])
        self.assertNotIn('<p class="hp-reason">', card)
        self.assertNotIn('<p class="hp-lbl">要点</p>', card)
        self.assertIn(a_tag(TRACKER_URL + "OPS-42", "OPS-42"), card)
        self.assertIn('<span class="hp-chip hp-ev-guess">推測</span>', card)

    def test_points_come_before_blocks(self):
        f = render_page("confirm", put(["sections", 0, "cards", 0, "points"], ["先に読む要点"]))
        card = re.search(r'<article class="hp-card" id="hp-card-intake_216">(.*?)</article>', f, re.S).group(1)
        self.assertLess(card.index("先に読む要点"), card.index('class="hp-block"'))

    def test_heading_level_follows_the_card_title_in_a_bundle(self):
        block = {"title": "やること", "points": ["#31 を見る"]}
        f = render_page("bundle", put(GROUP0 + ["cards", 0, "blocks"], [block]))
        self.assertIn('<h5 class="hp-block-title">やること</h5>', f)
        self.assertIn(a_tag("https://github.com/example-org/billing/issues/31", "#31") + " を見る", f)

    def test_block_strings_stay_text(self):
        a, b, c = ATTACKS
        f = render_page("confirm", both(put(BLOCK0 + ["title"], b), put(BLOCK0 + ["points", 0], c + " " + a)))
        self.assertNotIn("<script>alert(1)", f)
        self.assertNotIn("<img src=x", f)
        self.assertIn('<h4 class="hp-block-title">&quot;&gt;&lt;img src=x onerror=alert(1)&gt;</h4>', f)
        self.assertIn("<code>&lt;/code&gt;&lt;b&gt;</code>", f)

    def test_saved_data_does_not_carry_blocks(self):
        cards = json.loads(embedded(render_page("confirm")))["cards"]
        self.assertEqual([sorted(c) for c in cards], [["key", "options"], ["key", "options"]])


class SaveCode(unittest.TestCase):
    """保存のコード（page.js）と埋め込みのデータは、答える部品のあるページにだけ入る。"""

    def test_pages_with_answer_parts_carry_the_save_code(self):
        with open(build.JS, encoding="utf-8") as fh:
            js = fh.read().rstrip("\n")
        for name in ("decide", "bundle"):
            with self.subTest(page=name):
                f = render_page(name)
                self.assertEqual(f.count("<script"), 2)
                self.assertIn("<script>\n%s\n</script>" % js, f)
                self.assertIsInstance(json.loads(embedded(f))["cards"], list)

    def test_pages_without_answer_parts_have_no_scripts(self):
        with open(os.path.join(EXAMPLES, "grasp-body.html"), encoding="utf-8") as fh:
            body = fh.read()
        for name, b in (("review", None), ("grasp", body), ("table", None)):
            with self.subTest(page=name):
                f = render_page(name, body=b)
                self.assertNotIn("<script", f)
                self.assertNotIn("claude.use", f)
                self.assertNotIn('id="hp-data"', f)

    def test_a_card_added_to_a_reading_page_brings_the_save_code(self):
        card = example("decide")["sections"][0]
        f = render_page("review", lambda d: d["sections"].append(card))
        self.assertEqual(f.count("<script"), 2)
        self.assertIn("claude.use", f)


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

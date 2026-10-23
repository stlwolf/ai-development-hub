#!/usr/bin/env python3
"""build.py の検査。標準の unittest だけを使う。

走らせ方: python3 tests/test_build.py （どの作業ディレクトリからでもよい）

壊したデータの検査は、見本のデータを1か所だけ壊し、出た誤りが「期待した規則と場所の1件だけ」で
あることを確かめる。落ちたことだけを見ると、別の理由で落ちたものを見逃すためである。
"""

import copy
import html
import html.parser
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


def append(path, value):
    def f(d):
        at(d, path).append(copy.deepcopy(value))
    return f


# 種別の検査で足す部品。中身はどれも誤りの無い形にし、出る誤りが種別の規則だけになるようにする
TABLE_SEC = {"type": "table", "title": "補足", "columns": [{"key": "what", "label": "中身"}], "rows": [{"what": "補足の行"}]}
NUMBER_TABLE_SEC = {"type": "table", "title": "番号つきの補足", "columns": [{"key": "no", "label": "番号", "type": "no"},
                                                                     {"key": "what", "label": "中身"}],
                    "rows": [{"what": "補足の行"}]}
FINDINGS_SEC = {"type": "findings", "title": "指摘", "items": [{"text": "指摘の文", "severity": "low", "adopted": "adopted",
                                                               "reason": "採った理由"}]}
CONFIRM_CARD = {"key": "extra_card", "title": "足したカード", "recommend": "ok",
                "blocks": [{"title": "やること", "points": ["中身"]}],
                "options": [{"key": "ok", "label": "この内容で確定"}, {"key": "fix", "label": "直してほしい"}]}
CONFIRM_SEC = {"type": "decisions", "title": "足した節", "cards": [CONFIRM_CARD]}
REQUEST = {"target": "PR #215", "type": "実装のレビュー", "via": "Copilot", "focus": "再試行", "why": "マージの前に見たい"}
BUNDLE_SEC = {"type": "bundle", "title": "束", "groups": [{"source": {"repo": "billing"}, "title": "作業",
                                                          "cards": [dict(CONFIRM_CARD, key="bundle_card")]}]}

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
    # E-H3 決まった値。kind は前の版の purpose の値（decide）を受け付けない
    ("h3_kind", "decide", put(["kind"], "decide"), [("E-H3", "kind")], False),
    ("h3_status", "decide", put(["status"], "waiting"), [("E-H3", "status")], False),
    ("h3_kind_number_is_f3", "decide", put(["kind"], 3), [("E-F3", "kind")], False),
    # kind は必須。purpose は kind に置き換えた（知らない項目として理由つきで止める）
    ("f3_kind_missing", "decide", drop(["kind"]), [("E-F3", "kind")], False),
    ("f2_purpose_is_replaced_by_kind", "decide", put(["purpose"], "decide"), [("E-F2", "purpose")], False),
    # 前の版のデータ（kind が無く purpose がある）は、種別の検証をしないので、中身が種別に合わなくても2件だけ
    ("old_data_reports_only_kind_and_purpose", "confirm",
     both(drop(["kind"]), put(["purpose"], "decide"), drop(BLOCKS)), [("E-F3", "kind"), ("E-F2", "purpose")], False),
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
    # 回答待ちのページでも、部品も本文も無ければ E-S1 だけ（E-P2 を重ねない）
    ("s1_no_sections_awaiting_is_only_s1", "decide", put(["sections"], []), [("E-S1", "sections")], False),
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
    # 識別子の形は、送り元が壊れていても見る（送り元に頼る判定だけを省く）
    ("l1_shape_is_checked_even_if_source_is_broken", "table", both(put(["source", "repo"], ""), put(ROW0 + ["refs"], ["not-a-ref"])),
     [("E-H2", "source.repo"), ("E-L1", "sections[0].rows[0].refs[0]")], False),
    # 列が壊れていても、行がオブジェクトかは見る
    ("f3_row_not_object_even_if_columns_are_broken", "table",
     both(put(COL0 + ["label"], ""), put(["sections", 0, "rows", 1], 123)),
     [("E-S3", "sections[0].columns[0].label"), ("E-F3", "sections[0].rows[1]")], False),
    ("l1_issue_without_repo_url", "table", drop(["source", "repo_url"]),
     [("E-L1", "sections[0].rows[0].refs[0]"), ("E-L1", "sections[0].rows[0].refs[1]"), ("E-L1", "sections[0].rows[1].refs[0]")], False),
    # 別のリポジトリの番号は owner/repo#N で書く。repo_url が無ければリンクにできない
    ("l1_xrepo_without_repo_url", "table", both(drop(["source", "repo_url"]), put(ROW0 + ["refs"], []),
                                                put(["sections", 0, "rows", 1, "refs"], ["example-org/billing#31"])),
     [("E-L1", "sections[0].rows[1].refs[0]")], False),
    ("l1_repo_name_without_owner", "table", put(ROW0 + ["refs"], ["billing#31"]), [("E-L1", "sections[0].rows[0].refs[0]")], False),
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
    # 種別の部品（E-K1〜E-K3）。種別ごとに「要る部品が無い」「置けない部品がある」「並びが違う」を見る
    # 認識合わせ: 部品が判定カードの節1つだけなので、並びの誤りは起きない
    ("k1_confirm_card_without_blocks", "confirm", drop(BLOCKS), [("E-K1", "sections[0].cards[0]")], False),
    ("k2_confirm_table", "confirm", append(["sections"], TABLE_SEC), [("E-K2", "sections[1]")], False),
    ("k2_confirm_second_decisions", "confirm", append(["sections"], CONFIRM_SEC), [("E-K2", "sections[1]")], False),
    ("k2_confirm_body", "confirm", lambda d: None, [("E-K2", "--body")], True),
    # 判定カードの節を表に替えると、要る部品が無いことと置けない部品があることの2つになる
    ("k1_k2_confirm_decisions_replaced_by_table", "confirm", both(put(["status"], "live"), put(["sections"], [TABLE_SEC])),
     [("E-K1", "sections"), ("E-K2", "sections[0]")], False),
    # 承認
    ("k1_approve_without_decisions", "decide", both(put(["status"], "live"), put(["sections"], [TABLE_SEC])),
     [("E-K1", "sections")], False),
    ("k2_approve_findings", "decide", append(["sections"], FINDINGS_SEC), [("E-K2", "sections[1]")], False),
    ("k2_approve_number_column", "decide", append(["sections"], NUMBER_TABLE_SEC), [("E-K2", "sections[1].columns[0]")], False),
    ("k3_approve_table_before_cards", "decide", lambda d: d["sections"].insert(0, TABLE_SEC), [("E-K3", "sections[0]")], False),
    # 一覧から選ぶ
    ("k1_pick_without_card", "pick", both(put(["status"], "live"), lambda d: d["sections"].pop(0)), [("E-K1", "sections")], False),
    ("k1_pick_without_tables", "pick", lambda d: d["sections"].__delitem__(slice(1, None)), [("E-K1", "sections")], False),
    ("k1_pick_without_number_table", "pick", lambda d: d["sections"].__delitem__(slice(2, None)), [("E-K1", "sections")], False),
    ("k2_pick_second_card", "pick", append(["sections", 0, "cards"], CONFIRM_CARD), [("E-K2", "sections[0].cards[1]")], False),
    ("k2_pick_second_decisions", "pick", append(["sections"], CONFIRM_SEC), [("E-K2", "sections[4]")], False),
    ("k2_pick_findings", "pick", append(["sections"], FINDINGS_SEC), [("E-K2", "sections[4]")], False),
    ("k2_pick_body", "pick", lambda d: None, [("E-K2", "--body")], True),
    ("k2_pick_two_number_columns", "pick", append(["sections", 2, "columns"], {"key": "no2", "label": "番号2", "type": "no"}),
     [("E-K2", "sections[2].columns[4]")], False),
    ("k3_pick_card_after_tables", "pick", lambda d: d["sections"].append(d["sections"].pop(0)), [("E-K3", "sections[3]")], False),
    # 見取り図: 要る部品が無いときは E-S1（s1_no_sections_no_body）が受け持つ。部品は表だけなので並びの誤りは起きない
    ("k2_map_decisions", "table", append(["sections"], CONFIRM_SEC), [("E-K2", "sections[1]")], False),
    ("k2_map_findings", "table", append(["sections"], FINDINGS_SEC), [("E-K2", "sections[1]")], False),
    # 束: 部品は判断待ちの束1つだけなので並びの誤りは起きない
    ("k1_k2_bundle_replaced_by_table", "bundle", put(["sections"], [TABLE_SEC]),
     [("E-K1", "sections"), ("E-K2", "sections[0]")], False),
    ("k2_bundle_table", "bundle", append(["sections"], TABLE_SEC), [("E-K2", "sections[1]")], False),
    # レビュー
    ("k1_review_without_findings", "review", put(["sections"], [TABLE_SEC]), [("E-K1", "sections")], False),
    ("k2_review_bundle", "review", append(["sections"], BUNDLE_SEC), [("E-K2", "sections[2]")], False),
    ("k2_review_number_column", "review", append(["sections"], NUMBER_TABLE_SEC), [("E-K2", "sections[2].columns[0]")], False),
    ("k3_review_table_first", "review", lambda d: d["sections"].insert(0, TABLE_SEC), [("E-K3", "sections[0]")], False),
    ("k3_review_table_between_findings", "review", lambda d: d["sections"].insert(1, TABLE_SEC), [("E-K3", "sections[1]")], False),
    # ページの中の識別子（E-I1・E-I2）。承認の問いのカードの札は Q<数字>、全体の承認のカードの札は「承認」
    ("i1_approve_tag_from_another_document", "decide", put(CARD0 + ["tag"], "DJ-1"), [("E-I1", "sections[0].cards[0].tag")], False),
    ("i1_approve_tag_zero", "decide", put(CARD0 + ["tag"], "Q0"), [("E-I1", "sections[0].cards[0].tag")], False),
    ("i1_approve_tag_with_a_note", "decide", both(put(CARD0 + ["tag"], "Q1（足した問い）"), put(CARD1 + ["tag"], "Q2"),
                                                  put(["sections", 0, "cards", 2, "tag"], "Q3")),
     [("E-I1", "sections[0].cards[0].tag")], False),
    ("i1_approve_written_and_omitted_mixed", "decide", put(CARD0 + ["tag"], "Q1"), [("E-I1", "sections[0].cards[1].tag")], False),
    ("i2_approve_tag_duplicate", "decide", both(put(CARD0 + ["tag"], "Q1"), put(CARD1 + ["tag"], "Q1"),
                                                put(["sections", 0, "cards", 2, "tag"], "Q2")),
     [("E-I2", "sections[0].cards[1].tag")], False),
    # 空の札は E-C5 だけ（E-I1 を重ねない）
    ("c5_tag_empty_is_not_i1", "decide", both(put(CARD0 + ["tag"], ""), put(CARD1 + ["tag"], "Q2"),
                                              put(["sections", 0, "cards", 2, "tag"], "Q3")),
     [("E-C5", "sections[0].cards[0].tag")], False),
    ("k3_approve_approval_card_not_last", "decide", put(CARD0 + ["tag"], "承認"), [("E-K3", "sections[0].cards[0]")], False),
    ("k2_approve_two_approval_cards", "decide", both(put(CARD1 + ["tag"], "承認"), put(["sections", 0, "cards", 2, "tag"], "承認")),
     [("E-K2", "sections[0].cards[2]")], False),
    # 認識合わせの札は issue の形
    ("i1_confirm_tag_not_an_issue", "confirm", put(CARD0 + ["tag"], "intake-1"), [("E-I1", "sections[0].cards[0].tag")], False),
    # 番号の列の値は接頭辞の形で、書いたものと書かないものを混ぜない
    ("i1_pick_number_from_another_prefix", "pick", put(["sections", 2, "rows", 0, "no"], "A1"), [("E-I1", "sections[2].rows[0].no")], False),
    ("i1_pick_numbers_mixed", "pick", put(["sections", 2, "rows", 0, "no"], "候補1"), [("E-I1", "sections[2].rows[1].no")], False),
    ("i2_map_number_duplicate", "table", put(["sections", 0, "rows", 1, "no"], "ID:1"), [("E-I2", "sections[0].rows[1].no")], False),
    # 番号を並べる書き方（E-I3）。3つ以上並び、並んだ番号がすべて定義されているときだけ止める
    ("i3_pick_listed_numbers", "pick", put(["sections", 1, "rows", 0, "cands"], "候補1・2・3"),
     [("E-I3", "sections[1].rows[0].cands")], False),
    ("i3_listed_numbers_with_spaces", "pick", put(["sections", 1, "rows", 0, "cands"], "候補1 、 2 、 3 を比べる"),
     [("E-I3", "sections[1].rows[0].cands")], False),
    ("i3_approve_listed_numbers_with_a_unit", "decide", put(CARD0 + ["points", 0], "Q1・2・3件は先に決める"),
     [("E-I3", "sections[0].cards[0].points[0]")], False),
    # URL は句点で終わる（描くときと同じ範囲）ので、句点のすぐあとの並べる書き方も見る
    ("i3_listed_numbers_right_after_a_url", "decide", put(["why"], "https://x.example。Q1・2・3 を見る"), [("E-I3", "why")], False),
    # 判断ボード: カードの札と番号の列の値（決まったこと）は Q<数字> を必ず書く。表は判定カードの節のあと
    ("i1_board_tag_missing", "board", drop(CARD0 + ["tag"]), [("E-I1", "sections[0].cards[0].tag")], False),
    ("i1_board_number_missing", "board", drop(["sections", 2, "rows", 0, "no"]), [("E-I1", "sections[2].rows[0].no")], False),
    ("i2_board_card_and_row_share_a_number", "board", put(CARD0 + ["tag"], "Q1"), [("E-I2", "sections[2].rows[0].no")], False),
    ("k3_board_table_before_cards", "board", lambda d: d["sections"].insert(0, d["sections"].pop(2)), [("E-K3", "sections[0]")], False),
    ("k2_board_body", "board", lambda d: None, [("E-K2", "--body")], True),
    ("k2_board_findings", "board", append(["sections"], FINDINGS_SEC), [("E-K2", "sections[4]")], False),
    # 判定カードが無ければ、番号の列を持つ表（決まったこと）が要る
    ("k1_board_without_cards_or_decided_table", "board", lambda d: d["sections"].__delitem__(slice(0, 3)),
     [("E-K1", "sections")], False),
    # レビューのページの依頼したレビュー（request）。レビューでは必須、ほかの種別では置けない
    ("k1_review_without_request", "review", drop(["request"]), [("E-K1", "request")], False),
    ("k2_request_on_approve", "decide", put(["request"], REQUEST), [("E-K2", "request")], False),
    ("h1_request_field_empty", "review", put(["request", "why"], " "), [("E-H1", "request.why")], False),
    ("f3_request_field_missing", "review", drop(["request", "via"]), [("E-F3", "request.via")], False),
    ("f2_request_unknown_field", "review", put(["request", "lane"], "x"), [("E-F2", "request.lane")], False),
    # 一覧から選ぶ行の選択（select）。選び方のカードにだけ置ける・max は必須・数と推奨の行の誤り
    ("k2_select_on_approve", "decide", put(CARD0 + ["select"], {"max": 1}), [("E-K2", "sections[0].cards[0].select")], False),
    ("f3_select_max_missing", "pick", put(["sections", 0, "cards", 0, "select"], {"min": 1}), [("E-F3", "sections[0].cards[0].select.max")], False),
    ("f3_select_max_true", "pick", put(["sections", 0, "cards", 0, "select", "max"], True), [("E-F3", "sections[0].cards[0].select.max")], False),
    ("f2_select_unknown_item", "pick", put(["sections", 0, "cards", 0, "select", "count"], 2), [("E-F2", "sections[0].cards[0].select.count")], False),
    ("c6_select_min_over_max", "pick", put(["sections", 0, "cards", 0, "select", "min"], 3), [("E-C6", "sections[0].cards[0].select")], False),
    ("c6_select_recommend_over_max", "pick", put(["sections", 0, "cards", 0, "select", "max"], 1),
     [("E-C6", "sections[0].cards[0].select.recommend")], False),
    ("c6_select_min_over_rows", "pick", put(["sections", 0, "cards", 0, "select"], {"min": 7, "max": 7}), [("E-C6", "sections[0].cards[0].select")], False),
    ("i1_select_recommend_undefined", "pick", put(["sections", 0, "cards", 0, "select", "recommend"], ["候補2", "候補9"]),
     [("E-I1", "sections[0].cards[0].select.recommend[1]")], False),
    ("a1_pick_row_choice_not_pick", "pick",
     both(put(["status"], "answered"), put(["answers"], {"pick_tools--2": {"choice": "yes", "note": "", "at": "2026-10-23T09:00:00Z"}})),
     [("E-A1", "answers.pick_tools--2.choice")], False),
    ("a1_pick_rows_over_max", "pick",
     both(put(["status"], "answered"), put(["answers"], {"pick_tools--%d" % n: {"choice": "pick", "note": "", "at": "2026-10-23T09:00:00Z"} for n in (1, 2, 3)})),
     [("E-A1", "answers")], False),
    ("a1_pick_row_undefined", "pick",
     both(put(["status"], "answered"), put(["answers"], {"pick_tools--9": {"choice": "pick", "note": "", "at": "2026-10-23T09:00:00Z"}})),
     [("E-A1", "answers.pick_tools--9")], False),
    # 番号の列の値は文字列
    ("f3_number_cell_number", "pick", put(["sections", 2, "rows", 0, "no"], 1), [("E-F3", "sections[2].rows[0].no")], False),
    # 独立した誤り2つは2件とも出る
    ("two_independent_errors", "decide", both(put(["title"], ""), put(CARD0 + ["recommend"], "ok")),
     [("E-C3", "sections[0].cards[0].recommend"), ("E-H1", "title")], False),
]


class ExamplesPass(unittest.TestCase):
    def test_examples_have_no_errors(self):
        for name, has_body in (("decide", False), ("bundle", False), ("review", False), ("grasp", True), ("table", False),
                               ("confirm", False), ("pick", False), ("board", False), ("approve", False)):
            with self.subTest(example=name):
                self.assertEqual(build.validate(example(name), has_body=has_body), [])

    def test_every_kind_has_an_example(self):
        kinds = {example(n)["kind"] for n in ("decide", "bundle", "review", "grasp", "table", "confirm", "pick", "board", "approve")}
        self.assertEqual(kinds, set(build.PAGE_KINDS))

    def test_body_is_allowed_only_in_body_kinds(self):
        # 本文を置ける種別は、部品の上に本文があっても読む順を壊さないもの（承認・見取り図・束・レビュー）
        for name in ("decide", "table", "bundle", "review"):
            with self.subTest(example=name):
                self.assertIn(example(name)["kind"], build.BODY_KINDS)
                self.assertEqual(build.validate(example(name), has_body=True), [])

    def test_number_column_cells_may_be_omitted(self):
        # 番号の列は、行の key を省いてよい唯一の列である（ほかの列の key が足りなければ E-F3）
        d = example("table")
        d["sections"][0]["columns"][0]["type"] = "no"
        for row in d["sections"][0]["rows"]:
            del row["no"]
        self.assertEqual(build.validate(d), [])

    def test_purpose_message_says_it_was_replaced(self):
        d = example("decide")
        d["purpose"] = "decide"
        msgs = [m for code, path, m in build.validate(d) if path == "purpose"]
        self.assertEqual(len(msgs), 1)
        self.assertIn("kind に置き換えた", msgs[0])

    def test_data_purpose_attribute_is_derived_from_kind(self):
        for name, purpose in (("decide", "decide"), ("pick", "decide"), ("confirm", "decide"), ("bundle", "decide"),
                              ("table", "grasp"), ("review", "review")):
            with self.subTest(example=name):
                self.assertIn('data-purpose="%s"' % purpose, render_page(name))

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
                 "E-C5", "E-C6", "E-T1", "E-S1", "E-S2", "E-S3", "E-L1", "E-A1", "E-K1", "E-K2", "E-K3", "E-I1", "E-I2",
                 "E-I3"}
        covered = {code for _, _, _, expected, _ in BROKEN for code, _ in expected}
        self.assertEqual(rules - covered, set())


class PickRows(unittest.TestCase):
    """一覧から選ぶページの、行ごとに選ぶ答え。番号の欄にチェックが付き、選び方のカードに選ぶ数と選んだ行が出る。"""

    def test_rows_get_a_checkbox_and_recommended_rows_a_chip(self):
        f = render_page("pick")
        boxes = re.findall(r'<input type="checkbox" class="hp-pick-box" id="hp-pick-([a-z0-9_-]+)" aria-label="([^"]*)"( checked)?( disabled)?>', f)
        self.assertEqual([b[0] for b in boxes], ["pick_tools--%d" % i for i in range(1, 7)])
        self.assertEqual(boxes[1][1], "候補2 選ぶ")
        self.assertTrue(all(not b[2] and not b[3] for b in boxes))
        for n in (2, 5):
            self.assertRegex(f, r'<span class="hp-pick-id">候補%d</span></label><span class="hp-chip hp-chip-rec">推奨</span>' % n)
        self.assertNotRegex(f, r'<span class="hp-pick-id">候補1</span></label><span class="hp-chip')

    def test_select_line_shows_the_rule_and_the_chosen_rows(self):
        f = render_page("pick")
        self.assertIn('<span class="hp-select-rule">表の行を 2 つまで選ぶ</span>', f)
        self.assertIn('id="hp-select-chosen-pick_tools" aria-live="polite">選んだ行（0）: まだ選んでいない</span>', f)
        between = render_page("pick", put(["sections", 0, "cards", 0, "select", "min"], 1))
        self.assertIn("表の行を 1〜2 つ選ぶ", between)
        exact = render_page("pick", put(["sections", 0, "cards", 0, "select", "min"], 2))
        self.assertIn("表の行を 2 つ選ぶ", exact)

    def test_embedded_data_lists_the_rows(self):
        picks = json.loads(embedded(render_page("pick")))["picks"]
        self.assertEqual(picks[0]["card"], "pick_tools")
        self.assertEqual(picks[0]["max"], 2)
        self.assertEqual(picks[0]["rows"][4], {"key": "pick_tools--5", "id": "候補5"})
        # 回答待ちの件数に数えるカードは、選び方のカード1枚だけ
        self.assertEqual([c["key"] for c in json.loads(embedded(render_page("pick")))["cards"]], ["pick_tools"])
        self.assertEqual(dict(meta_of(render_page("pick")))["状態"], "回答待ち 1 件")

    def test_answered_page_shows_the_chosen_rows_locked(self):
        answers = {"pick_tools": {"choice": "chosen", "note": "", "at": "2026-10-23T09:00:00Z"},
                   "pick_tools--2": {"choice": "pick", "note": "", "at": "2026-10-23T09:00:01Z"},
                   "pick_tools--4": {"choice": "pick", "note": "", "at": "2026-10-23T09:00:02Z"},
                   "pick_tools--5": {"choice": None, "note": "", "at": "2026-10-23T09:00:03Z"}}
        f = render_page("pick", both(put(["status"], "answered"), put(["answers"], answers)))
        checked = re.findall(r'id="hp-pick-([a-z0-9_-]+)"[^>]* checked disabled>', f)
        self.assertEqual(checked, ["pick_tools--2", "pick_tools--4"])
        self.assertEqual(len(re.findall(r'class="hp-pick-box"[^>]* disabled>', f)), 6)
        self.assertIn("選んだ行（2）: 候補2、候補4", f)

    def test_row_keys_may_exceed_the_card_key_length(self):
        # 行の答えの key は、カードの key（64文字まで）に「--」と番号の数字を足したもので、64文字の決まりの外にある
        long_key = "p" * 64
        d = copy.deepcopy(example("pick"))
        d["sections"][0]["cards"][0]["key"] = long_key
        d["status"] = "answered"
        d["answers"] = {long_key + "--1": {"choice": "pick", "note": "", "at": "2026-10-23T09:00:00Z"}}
        self.assertEqual(build.validate(d), [])

    def test_every_row_has_a_save_mark(self):
        # 行の保存の成否を書く場所（判定カードと同じ hp-saved-<key>）。描かないと JS の知らせが消える
        f = render_page("pick")
        self.assertEqual(re.findall(r'<span class="hp-saved" id="hp-saved-(pick_tools--[0-9]+)" aria-live="polite"></span></td>', f),
                         ["pick_tools--%d" % i for i in range(1, 7)])

    def test_pages_without_select_have_no_checkboxes(self):
        self.assertNotIn("hp-pick-box", main_of(render_page("pick", drop(["sections", 0, "cards", 0, "select"]))))
        self.assertNotIn("hp-pick-box", main_of(render_page("table")))


class ReviewRequest(unittest.TestCase):
    """レビューのページの依頼したレビュー。ヘッダーの最後（指摘の一覧の前）に、項目名と値の表で出る。"""

    def test_request_table_comes_before_findings(self):
        f = render_page("review")
        self.assertLess(f.index('<section class="hp-request">'), f.index('class="hp-sec hp-findings"'))
        self.assertLess(f.index('class="hp-links"'), f.index('<section class="hp-request">'))
        rows = meta_of(f, 1)
        self.assertEqual([k for k, _ in rows], ["対象", "種類", "経由", "観点", "なぜ"])
        self.assertIn('<p class="hp-lbl">依頼したレビュー</p>', f)

    def test_request_values_use_the_same_conversion(self):
        self.assertIn(a_tag("https://github.com/example-org/shop/pull/215", "PR #215") + " の差分（決済の再試行）", render_page("review"))

    def test_request_strings_stay_text(self):
        a, b, c = ATTACKS
        f = render_page("review", both(put(["request", "via"], b), put(["request", "focus"], c + " " + a)))
        self.assertNotIn("<img src=x", f)
        self.assertNotIn("<script>alert(1)", f)


class Identifiers(unittest.TestCase):
    """札と番号の列の値。書かなければ、種別の接頭辞とページの中の順から振る。"""

    def tags(self, f):
        return re.findall(r'<span class="hp-tag">(.*?)</span>', f)

    def numbers(self, f):
        cells = re.findall(r'<td class="hp-no" data-label="番号">(.*?)</td>', f)
        return [html.unescape(re.sub(r"<[^>]+>", "", re.sub(r'<span class="hp-chip[^"]*">.*?</span>', "", v))) for v in cells]

    def test_question_cards_are_numbered_in_order(self):
        self.assertEqual(self.tags(render_page("decide")), ["Q1", "Q2", "Q3"])

    def test_written_tags_are_kept(self):
        mutate = both(put(CARD0 + ["tag"], "Q3"), put(CARD1 + ["tag"], "Q1"), put(["sections", 0, "cards", 2, "tag"], "Q2"))
        self.assertEqual(self.tags(render_page("decide", mutate)), ["Q3", "Q1", "Q2"])

    def test_approval_card_is_not_numbered(self):
        f = render_page("decide", put(["sections", 0, "cards", 2, "tag"], "承認"))
        self.assertEqual(self.tags(f), ["Q1", "Q2", "承認"])

    def test_rows_are_numbered_across_tables(self):
        self.assertEqual(self.numbers(render_page("pick")), ["候補%d" % i for i in range(1, 7)])

    def test_written_numbers_are_kept(self):
        self.assertEqual(self.numbers(render_page("table")), ["ID:1", "ID:2", "ID:3"])

    def test_board_keeps_written_numbers_and_links_to_decided_rows(self):
        f = render_page("board")
        self.assertEqual(self.tags(f), ["Q4", "Q5", "Q6"])
        self.assertEqual(self.numbers(f), ["Q1", "Q2", "Q3"])
        # 決まったことの表へ移した Q2 を本文で指すと、その行へ移る
        self.assertIn(anchor("hp-row-2-1", "Q2") + " で決めた日程", f)

    def test_board_with_every_card_moved_has_no_save_code(self):
        # 決まったカードをすべて表へ移したページは、答える部品の無いページとして描かれる
        d = example("board")
        del d["sections"][0:2]
        self.assertEqual(build.validate(d), [])
        f = render_page("board", lambda x: x["sections"].__delitem__(slice(0, 2)))
        self.assertNotIn("<script", f)

    def test_free_tags_stay_as_written(self):
        # 札が自由な種別（一覧から選ぶ・レビュー・束のカード）は、書いたまま出し、識別子にしない
        f = render_page("pick", put(["sections", 0, "cards", 0, "tag"], "選ぶ"))
        self.assertEqual(self.tags(f), ["選ぶ"])
        self.assertEqual(self.tags(render_page("confirm")), ["#216", "#218"])

    def test_number_cells_stay_text(self):
        a, b, c = ATTACKS
        d = copy.deepcopy(example("table"))
        d["sections"][0]["rows"][0]["no"] = b
        # 形の誤りで止まる値でも、描くときにエスケープされることを、検証を通さず描いて確かめる
        f = build.render(d, build.load_glossary(build.DEFAULT_GLOSSARY), build.parse_now(NOW), None)
        self.assertNotIn("<img src=x", f)
        self.assertIn("&quot;&gt;&lt;img src=x onerror=alert(1)&gt;", f)


def anchor(target, text):
    return '<a href="#%s">%s</a>' % (target, text)


class Anchors(unittest.TestCase):
    """ページで定義した識別子だけを、ページの中のアンカーにする。"""

    def point(self, text, name="decide"):
        f = render_page(name, put(CARD0 + ["points", 0], text))
        return re.search(r'<ul class="hp-points"><li>(.*?)</li>', f).group(1)

    def test_card_tags_link_to_the_card(self):
        self.assertEqual(self.point("Q2 を先に決める。"), anchor("hp-card-alert_rule", "Q2") + " を先に決める。")

    def test_approve_example_links_every_kind_of_number(self):
        f = render_page("approve")
        self.assertEqual(re.findall(r'<span class="hp-tag">(.*?)</span>', f), ["Q1", "Q2", "Q3", "承認"])
        self.assertIn(anchor("hp-card-alert_channel", "Q1") + " の通知の文に足す。", f)
        self.assertIn(a_tag("https://github.com/example-org/shop/pull/215", "PR #215"), f)
        self.assertIn(a_tag("https://github.com/example-org/billing/issues/31", "example-org/billing#31"), f)
        # 目的の文の Q2 もアンカーになる
        self.assertIn(anchor("hp-card-inquiry_number", "Q2") + " の答えで実装の順が変わる。", f)

    def test_numbers_link_to_the_row(self):
        f = render_page("pick")
        self.assertIn(anchor("hp-row-2-1", "候補2") + "・" + anchor("hp-row-3-1", "候補5"), f)
        self.assertIn('<tr id="hp-row-2-1">', f)
        self.assertIn('<tr id="hp-row-3-1">', f)

    def test_map_ids_with_a_colon_link_to_the_row(self):
        # 見取り図の番号は ID:1 の形（接頭辞の語の末尾の「:」）。本文の ID:2 はその行へのアンカーになり、ID:21 の中の ID:2 はならない
        f = render_page("table", put(["sections", 0, "rows", 2, "what", "text"], "ID:2 の続き。ID:21 は無い。"))
        self.assertIn(anchor("hp-row-0-1", "ID:2") + " の続き。ID:21 は無い。", f)

    def test_rows_without_a_number_column_have_no_id(self):
        f = render_page("pick")
        summary = re.search(r'<h2 class="hp-sec-title">上位の候補</h2>(.*?)</section>', f, re.S).group(1)
        self.assertNotIn("<tr id=", summary)
        self.assertEqual(render_page("review").count("<tr id="), 0)

    def test_targets_clear_the_sticky_bar(self):
        # 答える部品のあるページでは、上に貼り付く帯が飛んだ先を隠さないよう、帯の高さのぶん余白を足す
        with open(build.CSS, encoding="utf-8") as fh:
            css = fh.read()
        self.assertIn("position: sticky;", re.search(r"^\.hp-bar \{(.*?)^\}", css, re.S | re.M).group(1))
        rules = re.findall(r"\.hp:has\(\.hp-bar\) \.hp-card:target, \.hp:has\(\.hp-bar\) \.hp-table tr:target \{ scroll-margin-top: (\d+)px; \}", css)
        self.assertEqual(rules, ["104", "148"])

    def test_anchors_do_not_open_a_new_tab(self):
        f = render_page("pick")
        for a in re.findall(r'<a href="#[^"]*"[^>]*>', f):
            self.assertNotIn("target=", a)

    def test_undefined_identifiers_and_bare_numbers_stay_text(self):
        got = self.point("DJ-4 と Q9 と 2 と #hp-card-rollout を見る。")
        self.assertNotIn('href="#', got)

    def test_boundaries(self):
        cases = {
            "FAQ2": False, "docs/Q2": False, "feature/Q2": False, "x-Q2": False, "Q2.md": False, "Q2-3": False,
            "Q2/x": False, "Q2a": False, "Q21": False, "`Q2`": False, "https://x.example/Q2": False,
            "Q2を見る": True, "Q2。": True, "(Q2)": True, "Q2.": True, "Q2 と": True,
        }
        for text, linked in cases.items():
            with self.subTest(text=text):
                self.assertEqual('href="#hp-card-alert_rule"' in self.point(text), linked)

    def test_longer_number_is_not_cut(self):
        # 候補4 を定義していても、候補43 の中の 候補4 はリンクにしない
        f = render_page("pick", put(["sections", 1, "rows", 0, "why"], "候補43 は無い。候補4 はある。"))
        self.assertIn("候補43 は無い。" + anchor("hp-row-3-0", "候補4") + " はある。", f)

    def test_anchors_work_in_every_converted_place(self):
        f = render_page("decide", both(put(["why"], "Q1 から読む。"), put(CARD1 + ["reason"], "Q3 と同じ理由。"),
                                       put(["sections", 0, "title"], "Q1〜Q3")))
        for a in (anchor("hp-card-retry_policy", "Q1"), anchor("hp-card-rollout", "Q3")):
            self.assertIn(a, f)
        self.assertIn('<h2 class="hp-sec-title">' + anchor("hp-card-retry_policy", "Q1") + "〜" + anchor("hp-card-rollout", "Q3"), f)

    def test_titles_and_buttons_are_not_converted(self):
        f = render_page("decide", both(put(["title"], "Q1 の判断"), put(CARD0 + ["options", 1, "label"], "Q2 に寄せる")))
        self.assertIn("<title>Q1 の判断</title>", f)
        self.assertRegex(f, r'<button [^>]*>Q2 に寄せる</button>')

    def test_two_listed_numbers_are_not_stopped(self):
        # 番号が2つだけの形は、普通の文（Q2・3件）と見分けられないので止めない。後ろの数字は文字のまま
        for text in ("Q2・3件", "候補は Q1・2 の2つ"):
            with self.subTest(text=text):
                self.assertEqual(build.validate(put_copy("decide", CARD0 + ["points", 0], text)), [])
        self.assertEqual(build.validate(put_copy("pick", ["sections", 1, "rows", 0, "cands"], "候補1・2・9")), [])
        self.assertIn(anchor("hp-card-alert_rule", "Q2") + "・3件", self.point("Q2・3件"))


def put_copy(name, path, value):
    d = copy.deepcopy(example(name))
    put(path, value)(d)
    return d


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

    def test_words_broken_exit_2(self):
        cases = [
            ("| `prefix.item` | ID: |\n", "", 'key "prefix.item" が無い'),
            ("| `prefix.item` | ID: |", "| `prefix.item` | ID- |", '語 "ID-" が文字だけからなっていない'),
            ("| `prefix.item` | ID: |", "| `prefix.item` | I:D |", '語 "I:D" が文字だけからなっていない'),
            ("| `prefix.item` | ID: |", "| `prefix.item` | ID:: |", '語 "ID::" が文字だけからなっていない'),
            ("| `prefix.item` | ID: |", "| `prefix.item` | : |", '語 ":" が文字だけからなっていない'),
            ("| `prefix.item` | ID: |", "| `prefix.item` | A1 |", '語 "A1" が文字だけからなっていない'),
            ("| `prefix.item` | ID: |", "| `prefix.item` | QA |", '"QA"'),
            ("| `tag.approval` | 承認 |", "| `tag.approval` | 承認 |\n| `prefix.other` | 他 |", '知らない key "prefix.other" がある'),
        ]
        for old, new, expected in cases:
            with self.subTest(new=new):
                self.check_glossary(self.glossary_variant(old, new), expected)

    def test_changed_words_change_both_check_and_build(self):
        # 用語集の語を変えると、check と build の両方で、受け付ける札と振る番号が変わる
        path = self.glossary_variant("| `prefix.question` | Q |", "| `prefix.question` | 問い |")
        data = os.path.join(EXAMPLES, "decide.json")
        out = os.path.join(self.tmp, "o.html")
        self.assertEqual(run_cli("check", data, "--glossary", path)[0], 0)
        self.assertEqual(run_cli("build", data, "-o", out, "--tmux", "off", "--glossary", path)[0], 0)
        with open(out, encoding="utf-8") as fh:
            self.assertEqual(re.findall(r'<span class="hp-tag">(.*?)</span>', fh.read()), ["問い1", "問い2", "問い3"])
        d = example("decide")
        d["sections"][0]["cards"][0]["tag"] = "Q1"
        d["sections"][0]["cards"][1]["tag"] = "Q2"
        d["sections"][0]["cards"][2]["tag"] = "Q3"
        written = self.write("d.json", json.dumps(d, ensure_ascii=False))
        for cmd in (["check", written], ["build", written, "-o", out, "--tmux", "off"]):
            with self.subTest(cmd=cmd[0]):
                rc, _, err = run_cli(*(cmd + ["--glossary", path]))
                self.assertEqual(rc, 1)
                self.assertIn('E-I1 sections[0].cards[0].tag: 問いのカードの札 "Q1" が 問い<数字> の形でない', err)

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

    def point(self, text, mutate=None):
        f = render_page("decide", both(put(CARD0 + ["points", 0], text), mutate or (lambda d: None)))
        return re.search(r'<ul class="hp-points"><li>(.*?)</li>', f).group(1)

    def test_pr_links_to_the_pull_request(self):
        self.assertEqual(self.point("PR #215 と #212 を見る。"),
                         a_tag("https://github.com/example-org/shop/pull/215", "PR #215") + " と "
                         + a_tag("https://github.com/example-org/shop/issues/212", "#212") + " を見る。")

    def test_pr_needs_a_boundary_before_it(self):
        # XPR #3 は PR #N にならず、#3 だけが issue のリンクになる
        self.assertEqual(self.point("XPR #3"), "XPR " + a_tag("https://github.com/example-org/shop/issues/3", "#3"))

    def test_xrepo_links_to_that_repo_on_the_same_host(self):
        self.assertEqual(self.point("（example-org/billing#31）"),
                         "（" + a_tag("https://github.com/example-org/billing/issues/31", "example-org/billing#31") + "）")
        gitlab = put(["source", "repo_url"], "https://gitlab.example.com/group/shop")
        self.assertIn(a_tag("https://gitlab.example.com/other/repo/issues/3", "other/repo#3"), self.point("other/repo#3", gitlab))

    def test_paths_and_branches_are_not_xrepo(self):
        self.assertEqual(self.point("docs/a/b#3 と feature/#212_x"), "docs/a/b#3 と feature/#212_x")
        # feature/#212 の #212 は、いまと同じく issue のリンクになる（#N の境界は変えていない）
        self.assertEqual(self.point("feature/#212"), "feature/" + a_tag("https://github.com/example-org/shop/issues/212", "#212"))

    def test_broken_host_in_repo_url_does_not_break_rendering(self):
        # 検証は repo_url が http(s):// で始まることしか見ないので、形の崩れたホストでも描画が落ちない
        mutate = both(put(["source", "repo_url"], "https://[bad"), put(["why"], "a/b#3 を見る"))
        f = render_page("decide", mutate)
        self.assertIn(a_tag("https://[bad/a/b/issues/3", "a/b#3"), f)

    def test_without_repo_url_pr_and_xrepo_stay_text(self):
        self.assertEqual(self.point("PR #215 と a/b#3", drop(["source", "repo_url"])), "PR #215 と a/b#3")

    def test_bare_numbers_are_not_linked(self):
        self.assertEqual(self.point("3 と 212 番"), "3 と 212 番")


def a_tag(url, text):
    return '<a href="%s" target="_blank" rel="noopener">%s</a>' % (url, text)


TRACKER_URL = "https://tracker.example.com/browse/"


class TableAndTrackerLinks(unittest.TestCase):
    """表の識別子の列と、外部の課題管理の ID のリンク。"""

    def test_ref_cells_keep_their_text_and_link(self):
        f = render_page("table")
        self.assertIn(a_tag("https://github.com/example-org/shop/issues/212", "#212"), f)
        # PR #N は PR の URL（/pull/N）へ。表示の文字は書いたまま残す
        self.assertIn(a_tag("https://github.com/example-org/shop/pull/215", "PR #215"), f)
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

    def test_long_numbers_are_linked(self):
        # ID の数字の桁に上限は置かない（表の欄でも文字列でも）
        d = example("table")
        d["sections"][0]["rows"][0]["tracker"] = "OPS-1234567890"
        self.assertEqual(build.validate(d), [])
        f = render_page("decide", both(put(["source", "trackers"], [OPS]), put(CARD0 + ["points", 0], "OPS-1234567890 を見る")))
        self.assertIn(a_tag(TRACKER_URL + "OPS-1234567890", "OPS-1234567890"), f)

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

    def test_xrepo_ref_links_to_that_repo(self):
        f = render_page("table", put(ROW0 + ["refs"], ["example-org/billing#31", "#212"]))
        self.assertIn(a_tag("https://github.com/example-org/billing/issues/31", "example-org/billing#31")
                      + a_tag("https://github.com/example-org/shop/issues/212", "#212"), f)

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

    PAGES = (("decide", None), ("bundle", None), ("review", None), ("grasp", "grasp-body.html"), ("table", None), ("confirm", None),
             ("pick", None), ("board", None), ("approve", None))

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
GENERATED_PAGES = ("decide", "bundle", "review", "table", "confirm", "pick", "board", "approve")


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
        # 表のセルは、表とセルの両方が class を持たないときだけ（class の付いたセルにも効かない）
        part_re = r"^\.hp-main (%s):not\(\[class\]\)( (th|td):not\(\[class\]\))?$" % "|".join(BARE_TAGS)
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
                # 依頼したレビュー（request）は type の項目を持つので、部品の例より先に見分ける
                if "via" in obj:
                    d = example("review")
                    d["request"] = obj
                elif "type" in obj:
                    d = example("table")
                    d["sections"] = [obj]
                elif "options" in obj:
                    # 塊（blocks）を持つカードは認識合わせの見本に、選び方（select）を持つカードは一覧から選ぶ見本に、
                    # ほかは承認の見本に入れる（例の形に合った種別）
                    d = example("confirm" if "blocks" in obj else "pick" if "select" in obj else "decide")
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


class PrefixWordsAcrossTheFolder(unittest.TestCase):
    """書き方の決まり（札と番号の接頭辞）を、スキルのフォルダの見本と SKILL.md の例にも当てる。
    検査の壊したデータ（BROKEN）は、使わない書き方をわざと書いたものなので除く。"""

    def values(self, page):
        out = []
        for sec in page.get("sections", []):
            cards = sec.get("cards", []) + [c for g in sec.get("groups", []) for c in g["cards"]]
            out += [c["tag"] for c in cards if "tag" in c]
            no = [c["key"] for c in sec.get("columns", []) if c.get("type") == "no"]
            out += [r[no[0]] for r in sec.get("rows", []) if no and r.get(no[0])]
        return out

    def test_examples_and_skill_md_use_only_the_glossary_words(self):
        w = build.load_words(build.DEFAULT_GLOSSARY)
        prefixes = "|".join(re.escape(w[k]) for k in ("prefix.question", "prefix.candidate", "prefix.item"))
        ok = re.compile(r"(?:(?:%s)[1-9][0-9]*|%s)\Z" % (prefixes, re.escape(w["tag.approval"])))
        pages = [example(n) for n in sorted(f[:-5] for f in os.listdir(EXAMPLES) if f.endswith(".json"))]
        with open(os.path.join(SKILL, "SKILL.md"), encoding="utf-8") as fh:
            for text in re.findall(r"^```json\n(.*?)^```", fh.read(), re.S | re.M):
                obj = json.loads(text)
                if "via" in obj:
                    continue  # 依頼したレビューの例は札も番号も持たない
                pages.append({"sections": [obj] if "type" in obj else [{"cards": [obj]}] if "options" in obj else []})
        found = [v for page in pages for v in self.values(page)]
        self.assertTrue(found)
        for v in found:
            with self.subTest(value=v):
                self.assertTrue(ok.match(v) or build.ISSUE_TAG_RE.match(v), v)


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
        for name, body in (("decide", None), ("bundle", None), ("review", None), ("table", None), ("confirm", None), ("pick", None),
                           ("board", None), ("approve", None)):
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
        for name in ("decide", "bundle", "confirm", "pick", "board", "approve"):
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


class _Elements(html.parser.HTMLParser):
    """描いた断片から、id のある要素の初めの状態（隠す・押せる・チェック・class）を集める。"""

    def __init__(self):
        super().__init__()
        self.found = {}

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.found[a["id"]] = {"tag": tag, "className": a.get("class") or "", "hidden": "hidden" in a,
                                   "disabled": "disabled" in a, "checked": "checked" in a}


# page.js を node で走らせる台。document は getElementById だけを持つ偽物で、要素は描いた断片から作る。
# 保存先（window.claude）は検査ごとの setup が作り、after が操作して結果を返す。setup から after へ渡す値は global に置く。
PAGE_DRIVER = r"""
const input = JSON.parse(require("fs").readFileSync(0, "utf8"));
const els = {};
for (const [id, a] of Object.entries(input.elements)) {
  els[id] = { id: id, tagName: a.tag, className: a.className, hidden: a.hidden, disabled: a.disabled, checked: a.checked,
    textContent: "", value: "", attrs: {}, handlers: {},
    setAttribute(k, v) { this.attrs[k] = String(v); },
    addEventListener(t, f) { (this.handlers[t] = this.handlers[t] || []).push(f); },
    focus() {}, select() {},
    fire(t) { (this.handlers[t] || []).forEach(function (f) { f({}); }); } };
}
els["hp-data"].textContent = input.data;
global.window = global;
global.document = { getElementById: function (id) { return els[id] || null; }, activeElement: null };
const log = { writes: [] };
const tick = function (n) { let p = Promise.resolve(); for (let i = 0; i < (n || 20); i += 1) { p = p.then(function () { return new Promise(function (r) { setTimeout(r, 0); }); }); } return p; };
function fakeDb(subscribe, fail) {
  const col = {
    doc: function (k) { return {
      update: function (patch) { log.writes.push(k + " " + JSON.stringify(patch.choice)); const e = new Error("missing"); e.code = "invalid_argument"; return Promise.reject(e); },
      set: function (obj) { log.writes.push(k + " " + JSON.stringify(obj.choice)); return fail ? Promise.reject(new Error("down")) : Promise.resolve(); } }; },
    onSnapshot: function (onSnap, onErr) { return subscribe(onSnap, onErr); }
  };
  return { collection: function () { return col; } };
}
let openDb = null;
function useDb(subscribe, fail) {
  window.claude = { use: function () { return new Promise(function (r) { openDb = function () { r(fakeDb(subscribe, fail)); }; }); } };
}
(async function () {
  eval(input.setup);
  eval(input.js);
  const out = await (new (Object.getPrototypeOf(async function () {}).constructor)("els", "log", "tick", "openDb", input.after))(els, log, tick, function () { openDb(); });
  process.stdout.write(JSON.stringify(out));
  process.exit(0);
})().catch(function (e) { process.stderr.write(String(e && e.stack || e)); process.exit(1); });
"""


@unittest.skipUnless(shutil.which("node"), "node が無い環境では page.js の振る舞いを確かめない")
class PageScript(unittest.TestCase):
    """page.js の振る舞いを、偽物の document と保存先で確かめる。

    保存先の購読（onSnapshot）が投げるか、最初の答えより先に失敗を返すと、保存できない表示にして
    一覧の行のチェックを押せるようにし、書き込みを始めない。最初の答えのあとの失敗は今までどおり。
    行の保存の成否は、その行の印に出る。"""

    STATE = """
      const boxes = Object.keys(els).filter(function (k) { return k.indexOf("hp-pick-") === 0; });
      return { store: els["hp-store"] ? els["hp-store"].textContent : null,
               reply_hidden: els["hp-reply"].hidden,
               rows_locked: boxes.filter(function (k) { return els[k].disabled; }).length,
               rows: boxes.length, writes: log.writes,
               saved2: els["hp-saved-pick_tools--2"] ? [els["hp-saved-pick_tools--2"].textContent, els["hp-saved-pick_tools--2"].className] : null };
    """
    # 保存先が開く前にカードの選択肢を押しておく（開いたあとの書き込みの有無を見るため）
    BEFORE_OPEN = 'els["hp-opt-pick_tools.chosen"].fire("click"); openDb(); await tick();'

    def run_page(self, setup, after, name="pick"):
        f = render_page(name)
        parser = _Elements()
        parser.feed(f)
        with open(build.JS, encoding="utf-8") as fh:
            js = fh.read()
        payload = {"elements": parser.found, "data": html.unescape(embedded(f)), "js": js, "setup": setup, "after": after}
        p = subprocess.run(["node", "-e", PAGE_DRIVER], input=json.dumps(payload), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           universal_newlines=True, encoding="utf-8", timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        return json.loads(p.stdout)

    def labels(self):
        return build.load_glossary(build.DEFAULT_GLOSSARY)

    def assert_unavailable(self, out):
        self.assertEqual(out["store"], self.labels()["text.store_unavailable"])
        self.assertFalse(out["reply_hidden"])
        self.assertEqual((out["rows"], out["rows_locked"]), (6, 0))

    def test_rows_wait_for_the_first_answer_and_then_unlock(self):
        # 比べの元: 購読が答えを返すまでは押せず、返すと押せて、先に押したカードを書く
        out = self.run_page("useDb(function (onSnap) { global.deliver = onSnap; });",
                            self.BEFORE_OPEN + "const before = els['hp-pick-pick_tools--1'].disabled; deliver({docs: []}); await tick();"
                            + "const s = (function () {" + self.STATE + "})(); s.before = before; return s;")
        self.assertTrue(out["before"])
        self.assertEqual(out["rows_locked"], 0)
        self.assertEqual(out["store"], "")
        self.assertEqual(out["writes"], ['pick_tools "chosen"', 'pick_tools "chosen"'])

    def test_subscription_that_throws_shows_unavailable_and_writes_nothing(self):
        out = self.run_page('useDb(function () { throw new Error("blocked"); });', self.BEFORE_OPEN + self.STATE)
        self.assert_unavailable(out)
        self.assertEqual(out["writes"], [])

    def test_error_callback_before_the_first_answer_shows_unavailable_and_writes_nothing(self):
        out = self.run_page('useDb(function (onSnap, onErr) { onErr(new Error("denied")); });', self.BEFORE_OPEN + self.STATE)
        self.assert_unavailable(out)
        self.assertEqual(out["writes"], [])

    def test_late_error_callback_before_the_first_answer_unlocks_the_rows(self):
        # 購読がいったん返り、答えより先に失敗が届く。書き込みはすでに始まっているが、行は押せるようになる
        out = self.run_page('useDb(function (onSnap, onErr) { global.fail = onErr; });',
                            self.BEFORE_OPEN + "fail(new Error('denied')); await tick();" + self.STATE)
        self.assert_unavailable(out)

    def test_error_after_the_first_answer_keeps_saving(self):
        out = self.run_page('useDb(function (onSnap, onErr) { onSnap({docs: []}); global.fail = onErr; });',
                            "openDb(); await tick(); fail(new Error('lost')); await tick();"
                            "const b = els['hp-pick-pick_tools--2']; b.checked = true; b.fire('change'); await tick();" + self.STATE)
        self.assertEqual(out["store"], self.labels()["text.store_failed"])
        self.assertFalse(out["reply_hidden"])
        self.assertEqual(out["rows_locked"], 0)
        self.assertEqual(out["writes"], ['pick_tools--2 "pick"', 'pick_tools--2 "pick"'])

    def test_row_save_result_shows_on_the_row(self):
        L = self.labels()
        pick2 = "const b = els['hp-pick-pick_tools--2']; b.checked = true; b.fire('change'); await tick();"
        ok = self.run_page("useDb(function (onSnap) { onSnap({docs: []}); });", "openDb(); await tick();" + pick2 + self.STATE)
        self.assertEqual(ok["saved2"], [L["text.store_saved"], "hp-saved is-ok"])
        bad = self.run_page("useDb(function (onSnap) { onSnap({docs: []}); }, true);", "openDb(); await tick();" + pick2 + self.STATE)
        self.assertEqual(bad["saved2"], [L["text.store_failed"], "hp-saved is-bad"])
        self.assertFalse(bad["reply_hidden"])


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

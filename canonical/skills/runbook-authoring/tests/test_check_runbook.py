#!/usr/bin/env python3
"""check_runbook.py の検査。

どの作業ディレクトリからでも `python3 tests/test_check_runbook.py` で回せる。
Python 3.9 以上の標準ライブラリだけを使う。
"""

import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
CHECK = os.path.join(SKILL, "check_runbook.py")

# スキルのフォルダに __pycache__ を残さない
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("runbook_check", CHECK)
check_runbook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check_runbook)

VALID = """# 見本の手順書

## いつ使うか

- 種類: ずっと使う
- 使うとき: 試すとき。

## 前提

- 依存: bash。
- 資格情報: 要らない。
- 実行する場所: リポジトリの一番上。
- 1回だけの初期化: 要らない。

## 手順

1. 確かめる

### 1. 確かめる

```bash
scripts/run.sh check
```

期待する出力: 最後の行が次のとおり出る。

```text
OK
```

外れたら: 止まったときに読む表を引く。

## 確かめ方

- 期待どおりか。

## 止まったときに読む表

| 番号 | 意味 | 次の操作 |
|---|---|---|
| C1 | 無い | 入れる |

## 失敗や中断のとき

- 止まり方: その場で止まる。

## AI が実行するとき

- AI には実行させない（見本のため）。

## 間違えやすい所

- まだ無い。
"""

INDEX = """# 手順書の一覧

| 手順書 | 種類 |
|---|---|
| [見本](ok.md) | ずっと使う |
"""

SCRIPT = "#!/usr/bin/env bash\nset -euo pipefail\necho OK\n"


def replace_once(text, old, new):
    assert text.count(old) == 1, "置き換える文字列が1つでない: " + repr(old)
    return text.replace(old, new)


def step(n):
    return "### {0}. 段{0}\n\n```bash\nscripts/run.sh check\n```\n\n期待する出力: OK。\n\n外れたら: 止める。\n\n".format(n)


class Repo:
    """一時のリポジトリ（scripts/run.sh・docs/runbooks/README.md・docs/runbooks/ok.md）。"""

    def __init__(self, runbook=VALID, index=INDEX, script=SCRIPT):
        self.root = tempfile.mkdtemp(prefix="runbook-check-")
        self.folder = os.path.join(self.root, "docs", "runbooks")
        os.makedirs(self.folder)
        os.makedirs(os.path.join(self.root, "scripts"))
        self.write("scripts/run.sh", script)
        if index is not None:
            self.write("docs/runbooks/README.md", index)
        self.write("docs/runbooks/ok.md", runbook)

    def write(self, rel, text):
        with open(os.path.join(self.root, rel), "w", encoding="utf-8") as f:
            f.write(text)

    def check(self, *paths, root=None):
        args = [sys.executable, CHECK, "--root", root or "."] + list(paths or ["docs/runbooks"])
        p = subprocess.run(args, cwd=self.root, capture_output=True, text=True)
        return p.returncode, p.stdout, p.stderr

    def close(self):
        shutil.rmtree(self.root)


def rules_of(stdout):
    return {line.split()[0] for line in stdout.splitlines() if line.strip()}


class Base(unittest.TestCase):
    def run_case(self, runbook=VALID, index=INDEX, script=SCRIPT, extra=None):
        repo = Repo(runbook, index, script)
        try:
            for rel, text in (extra or {}).items():
                repo.write(rel, text)
            return repo.check()
        finally:
            repo.close()

    def expect(self, rules, **kw):
        rc, out, err = self.run_case(**kw)
        self.assertEqual(err, "")
        self.assertEqual(rules_of(out), set(rules), out)
        self.assertEqual(rc, 1 if rules else 0, out)


class Valid(Base):
    def test_valid_runbook_passes(self):
        rc, out, err = self.run_case()
        self.assertEqual((rc, out, err), (0, "", ""))

    def test_extra_headings_are_ignored(self):
        text = replace_once(VALID, "## 確かめ方\n", "## メモ\n\n- 何でも。\n\n## 確かめ方\n")
        self.expect([], runbook=text + "\n## 関連\n\n- 無い。\n")


class SectionsR1(Base):
    def test_missing_section(self):
        self.expect(["R1"], runbook=replace_once(VALID, "## 確かめ方\n\n- 期待どおりか。\n\n", ""))

    def test_missing_prerequisite_section_is_r1_only(self):
        text = VALID.split("## 前提\n")[0] + "## 手順\n" + VALID.split("## 手順\n")[1]
        self.expect(["R1"], runbook=text)

    def test_wrong_order(self):
        text = replace_once(VALID, "## 確かめ方\n\n- 期待どおりか。\n\n", "")
        text = replace_once(text, "## 失敗や中断のとき\n", "## 失敗や中断のとき\n\n## 確かめ方\n\n- 期待どおりか。\n\n")
        self.expect(["R1"], runbook=text)

    def test_duplicate_section(self):
        self.expect(["R1"], runbook=VALID + "\n## 確かめ方\n\n- もう一度。\n")


class PrerequisitesR2(Base):
    def test_missing_label(self):
        self.expect(["R2"], runbook=replace_once(VALID, "- 資格情報: 要らない。\n", ""))

    def test_full_width_colon_and_bold_are_accepted(self):
        text = replace_once(VALID, "- 資格情報: 要らない。", "- **資格情報**：要らない。")
        self.expect([], runbook=text)


class KindR3(Base):
    def test_missing_kind(self):
        self.expect(["R3"], runbook=replace_once(VALID, "- 種類: ずっと使う\n", ""))

    def test_unknown_kind(self):
        self.expect(["R3"], runbook=replace_once(VALID, "種類: ずっと使う", "種類: たまに使う"))

    def test_temporary_needs_remove_condition(self):
        self.expect(["R3"], runbook=replace_once(VALID, "種類: ずっと使う", "種類: 一時的"))

    def test_temporary_with_remove_condition(self):
        text = replace_once(VALID, "種類: ずっと使う", "種類: 一時的\n- 消す条件: CI ができたら消す。")
        self.expect([], runbook=text)

    def test_kind_with_note(self):
        self.expect([], runbook=replace_once(VALID, "種類: ずっと使う", "種類: 1回だけの初期化（構築の前に済ませる）"))


class StepsR4(Base):
    def test_seven_steps(self):
        steps = "".join(step(n) for n in range(2, 8))
        self.expect(["R4"], runbook=replace_once(VALID, "## 確かめ方\n", steps + "## 確かめ方\n"))

    def test_six_steps_pass(self):
        steps = "".join(step(n) for n in range(2, 7))
        self.expect([], runbook=replace_once(VALID, "## 確かめ方\n", steps + "## 確かめ方\n"))

    def test_no_steps(self):
        text = replace_once(VALID, "### 1. 確かめる\n", "")
        self.expect(["R4"], runbook=text)

    def test_two_command_blocks_in_a_step(self):
        text = replace_once(VALID, "期待する出力: 最後の", "```bash\nscripts/run.sh check\n```\n\n期待する出力: 最後の")
        self.expect(["R4"], runbook=text)

    def test_missing_label_in_a_step(self):
        self.expect(["R4"], runbook=replace_once(VALID, "外れたら: 止まったときに読む表を引く。\n", ""))

    def test_step_without_command_needs_no_labels(self):
        extra = "### 2. 画面で見る\n\n確かめ方の節のとおりに見る。\n\n"
        self.expect([], runbook=replace_once(VALID, "## 確かめ方\n", extra + "## 確かめ方\n"))


class ReferencesR5(Base):
    def test_missing_script(self):
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/missing.sh check"))

    def test_missing_script_after_interpreter(self):
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "bash scripts/missing.sh check"))

    def test_missing_script_after_assignment_and_operator(self):
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "cd . && FOO=1 scripts/missing.sh check"))

    def test_missing_link(self):
        self.expect(["R5"], runbook=replace_once(VALID, "- まだ無い。", "- [背景](missing.md) を読む。"))

    def test_existing_link_and_url_pass(self):
        text = replace_once(VALID, "- まだ無い。", "- [一覧](README.md#一覧) と [外](https://example.com/x) を読む。")
        self.expect([], runbook=text)

    def test_arguments_are_not_references(self):
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/run.sh check config/missing.conf"))


class IssueNumbersR6(Base):
    def test_issue_number_in_prose(self):
        self.expect(["R6"], runbook=replace_once(VALID, "使うとき: 試すとき。", "使うとき: 試すとき（#123）。"))

    def test_issue_url_outside_pitfalls(self):
        url = "[経緯](https://example.com/org/repo/issues/12)"
        self.expect(["R6"], runbook=replace_once(VALID, "- 期待どおりか。", "- 期待どおりか。" + url))

    def test_link_in_pitfalls_is_allowed(self):
        url = "- 前に詰まった（[#12](https://example.com/org/repo/issues/12)）。"
        self.expect([], runbook=replace_once(VALID, "- まだ無い。", url))

    def test_bare_number_in_pitfalls(self):
        self.expect(["R6"], runbook=replace_once(VALID, "- まだ無い。", "- 前に詰まった（#12）。"))

    def test_inline_code_and_blocks_are_ignored(self):
        text = replace_once(VALID, "使うとき: 試すとき。", "使うとき: `#123` を試すとき。")
        self.expect([], runbook=replace_once(text, "OK\n```", "OK #123\n```"))


class DatesR7(Base):
    def test_date_in_prose(self):
        self.expect(["R7"], runbook=replace_once(VALID, "使うとき: 試すとき。", "使うとき: 2026-01-31 から試すとき。"))

    def test_japanese_date(self):
        self.expect(["R7"], runbook=replace_once(VALID, "使うとき: 試すとき。", "使うとき: 2026年1月から試すとき。"))

    def test_link_target_and_code_are_ignored(self):
        extra = {"docs/2026-01-31-design.md": "# 設計\n"}
        text = replace_once(VALID, "- まだ無い。", "- [設計](../2026-01-31-design.md) を読む。")
        text = replace_once(text, "OK\n```", "2026-01-31T00:00:00Z OK\n```")
        self.expect([], runbook=text, extra=extra)


class WarningMarksR8(Base):
    def test_mark_in_prose(self):
        self.expect(["R8"], runbook=replace_once(VALID, "- 期待どおりか。", "- ⚠️ 期待どおりか。"))

    def test_mark_in_code_is_ignored(self):
        self.expect([], runbook=replace_once(VALID, "OK\n```", "OK ★\n```"))


class NonAsciiAfterVariableR9(Base):
    def test_in_runbook_block(self):
        self.expect(["R9"], runbook=replace_once(VALID, "scripts/run.sh check", 'scripts/run.sh check "$HOME（家）"'))

    def test_braced_is_fine(self):
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", 'scripts/run.sh check "${HOME}（家）"'))

    def test_in_called_script(self):
        rc, out, err = self.run_case(script=SCRIPT + 'c=1\necho "[$c（]"\n')
        self.assertEqual(rules_of(out), {"R9"}, out)
        self.assertIn(os.path.join("scripts", "run.sh") + ":5", out)
        self.assertEqual(rc, 1)

    def test_comment_line_is_ignored(self):
        self.expect([], script=SCRIPT + '# "$c（" は書かない\n')


class IndexR10(Base):
    def test_unlisted_runbook(self):
        self.expect(["R10"], extra={"docs/runbooks/other.md": VALID})

    def test_listed_but_missing(self):
        self.expect(["R10"], index=INDEX + "| [無い](missing.md) | ずっと使う |\n")

    def test_missing_index(self):
        self.expect(["R10"], index=None)

    def test_single_file_skips_index(self):
        repo = Repo(index=None)
        try:
            self.assertEqual(repo.check("docs/runbooks/ok.md"), (0, "", ""))
        finally:
            repo.close()


class ExitCodes(Base):
    def test_missing_path(self):
        repo = Repo()
        try:
            rc, out, err = repo.check("docs/nothing")
            self.assertEqual((rc, out), (2, ""))
            self.assertIn("検査できない", err)
        finally:
            repo.close()

    def test_not_markdown(self):
        repo = Repo()
        try:
            rc, out, err = repo.check("scripts/run.sh")
            self.assertEqual((rc, out), (2, ""))
        finally:
            repo.close()

    def test_root_not_a_folder(self):
        repo = Repo()
        try:
            rc, out, err = repo.check(root="nothing")
            self.assertEqual((rc, out), (2, ""))
        finally:
            repo.close()


def skill_text():
    with open(os.path.join(SKILL, "SKILL.md"), encoding="utf-8") as f:
        return f.read()


def section_of(text, heading):
    """見出しの行から、同じかより上の段の次の見出しまで。"""
    level = heading.split()[0]
    start = text.index(heading + "\n")
    rest = text[start + len(heading) + 1:]
    m = re.search(r"^#{1,%d} " % len(level), rest, re.M)
    return rest[: m.start()] if m else rest


class SkillMatchesScript(unittest.TestCase):
    """SKILL.md の表と、check_runbook.py の一覧が同じであること。"""

    def test_sections(self):
        rows = re.findall(r"^\|\s*\d+\s*\|\s*`([^`]+)`", section_of(skill_text(), "## 節の型"), re.M)
        self.assertEqual(rows, check_runbook.SECTIONS)

    def test_prerequisite_labels(self):
        rows = re.findall(r"^\|\s*`([^`]+?):`", section_of(skill_text(), "### 前提の型"), re.M)
        self.assertEqual(rows, check_runbook.PREREQ_LABELS)

    def test_kinds(self):
        rows = re.findall(r"^\|\s*`([^`]+)`\s*\|", section_of(skill_text(), "## 手順書の種類"), re.M)
        self.assertEqual(rows, check_runbook.KINDS)

    def test_warning_marks(self):
        m = re.search(r"^警告の印: (.+)$", skill_text(), re.M)
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1).split(), check_runbook.WARNING_MARKS)

    def test_rule_table(self):
        rows = re.findall(r"^\|\s*(R\d+)\s*\|", section_of(skill_text(), "### 機械が見る項目"), re.M)
        self.assertEqual(rows, check_runbook.RULE_ORDER)


if __name__ == "__main__":
    unittest.main(verbosity=1)

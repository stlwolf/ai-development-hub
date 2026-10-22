#!/usr/bin/env python3
"""check_runbook.py の検査。

どの作業ディレクトリからでも `python3 tests/test_check_runbook.py` で回せる。
Python 3.9 以上の標準ライブラリだけを使う。
"""

import importlib.util
import os
import pty
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
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

    def test_semicolon_is_an_operator(self):
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/run.sh; scripts/run.sh check"))

    def test_command_after_semicolon(self):
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/run.sh check; scripts/missing.sh check"))

    def test_prefix_command_with_option_value(self):
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "sudo -u root bash scripts/missing.sh"))

    def test_command_string_of_bash_c(self):
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "bash -c 'scripts/missing.sh check'"))
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "bash -c 'scripts/run.sh check'"))

    def test_redirect_target_and_comment(self):
        text = replace_once(VALID, "scripts/run.sh check", "scripts/run.sh check > out/missing.txt # 注釈 scripts/missing.sh")
        self.expect([], runbook=text)

    def test_hash_inside_a_path(self):
        extra = {"scripts/a#b.sh": SCRIPT}
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/a#b.sh check"), extra=extra)

    def test_heredoc_body_is_not_a_command(self):
        for opener in ["cat <<'EOF'", "cat <<EOF", "cat <<-EOF"]:
            text = replace_once(VALID, "scripts/run.sh check", opener + "\nscripts/not-a-command.sh\nEOF")
            self.expect([], runbook=text)
        text = replace_once(VALID, "scripts/run.sh check", "cat <<'EOF'\nx\nEOF\nscripts/missing.sh check")
        self.expect(["R5"], runbook=text)

    def test_backslash_newline_joins_without_space(self):
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/ru\\\nn.sh check"))
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/run.sh check \\\n  && scripts/missing.sh"))

    def test_quoted_operator_is_not_an_operator(self):
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "printf '%s\\n' '|' scripts/not-a-command.sh"))
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "scripts/run.sh check | scripts/missing.sh"))

    def test_inline_source_of_other_languages(self):
        self.expect([], runbook=replace_once(VALID, "scripts/run.sh check", "python3 -c 'print(\"docs/example\")'"))
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "bash -lc 'scripts/missing.sh'"))
        self.expect(["R5"], runbook=replace_once(VALID, "scripts/run.sh check", "python3 scripts/missing.py"))

    def test_reference_style_and_angle_links(self):
        self.expect(["R5"], runbook=replace_once(VALID, "- まだ無い。", "- [背景][b] を読む。\n\n[b]: missing.md"))
        self.expect(["R5"], runbook=replace_once(VALID, "- まだ無い。", "- [背景](<missing file.md>) を読む。"))
        extra = {"docs/a b.md": "x\n", "docs/c.md": "x\n"}
        text = replace_once(VALID, "- まだ無い。", "- [背景](<../a b.md>) と [別][c] を読む。\n\n[c]: ../c.md")
        self.expect([], runbook=text, extra=extra)


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

    def test_number_after_letters(self):
        self.expect(["R6"], runbook=replace_once(VALID, "使うとき: 試すとき。", "使うとき: issue#123 を試すとき。"))
        self.expect(["R6"], runbook=replace_once(VALID, "使うとき: 試すとき。", "使うとき: 対応#123 を試すとき。"))

    def test_url_fragment_and_entity_are_not_issue_numbers(self):
        text = replace_once(VALID, "使うとき: 試すとき。", "使うとき: https://example.com/doc#12 と &#123; を見るとき。")
        self.expect([], runbook=text)

    def test_reference_link_in_pitfalls(self):
        definition = "\n\n[past]: https://example.com/org/repo/issues/12"
        self.expect([], runbook=replace_once(VALID, "- まだ無い。", "- 前に詰まった（[経緯][past]）。" + definition))
        self.expect([], runbook=replace_once(VALID, "- まだ無い。", "- 前に詰まった（[past]）。" + definition))
        text = replace_once(VALID, "- 期待どおりか。", "- 期待どおりか（[経緯][past]）。")
        self.expect(["R6"], runbook=replace_once(text, "- まだ無い。", "- 前に詰まった（[経緯][past]）。" + definition))
        self.expect(["R6"], runbook=replace_once(VALID, "- まだ無い。", "- まだ無い。" + definition))

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

    def test_not_expanded_forms_are_ignored(self):
        body = "echo '$c（'\necho \\$c（\ncat <<'EOF'\n$c（\nEOF\ncat <<-\\END\n\t$c（\n\tEND\ncat <<<\"${c}（\"\n"
        self.expect([], script=SCRIPT + body)

    def test_expanded_forms_are_found(self):
        for body in ['echo "$c（"\n', "cat <<EOF\n$c（\nEOF\n", "echo 'a\nb' \"$c（\"\n", 'x=1 # 注釈\necho $c（\n']:
            rc, out, err = self.run_case(script=SCRIPT + body)
            self.assertEqual(rules_of(out), {"R9"}, body + out)


class IndexR10(Base):
    def test_unlisted_runbook(self):
        self.expect(["R10"], extra={"docs/runbooks/other.md": VALID})

    def test_listed_but_missing(self):
        self.expect(["R10"], index=INDEX + "| [無い](missing.md) | ずっと使う |\n")

    def test_missing_index(self):
        self.expect(["R10"], index=None)

    def test_query_and_fragment_in_index_links(self):
        self.expect([], index=replace_once(INDEX, "(ok.md)", "(ok.md?raw=1#いつ使うか)"))

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

    def test_unreadable_files(self):
        if hasattr(os, "geteuid") and os.geteuid() == 0:
            self.skipTest("root は権限に関係なく読める")
        for rel in ["docs/runbooks", "docs/runbooks/README.md", "docs/runbooks/ok.md", "scripts/run.sh"]:
            repo = Repo()
            target = os.path.join(repo.root, rel)
            os.chmod(target, 0)
            try:
                rc, out, err = repo.check()
                self.assertEqual((rc, out), (2, ""), rel)
                self.assertIn("検査できない", err, rel)
                self.assertNotIn("Traceback", err, rel)
            finally:
                os.chmod(target, 0o755)
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


EXAMPLES = os.path.join(SKILL, "examples")
EXAMPLE_RUNBOOK = os.path.join("docs", "runbooks", "shop-config-apply.md")
PROMPT_TAIL = "入力する: ".encode("utf-8")


class ExampleCopy:
    """見本のフォルダの写しと、毎回空の反映先。"""

    def __init__(self):
        self.tmp = tempfile.mkdtemp(prefix="runbook-example-")
        self.root = os.path.join(self.tmp, "repo")
        shutil.copytree(EXAMPLES, self.root)
        self.state = os.path.join(self.tmp, "state")
        self.env = dict(os.environ)
        self.env.update({"SHOP_STATE_DIR": self.state, "SHOP_TOKEN": "token-value-for-test-0123456789"})

    def path(self, rel):
        return os.path.join(self.root, rel)

    def read(self, rel):
        with open(self.path(rel), encoding="utf-8") as f:
            return f.read()

    def write(self, rel, text):
        with open(self.path(rel), "w", encoding="utf-8") as f:
            f.write(text)

    def check(self):
        args = [sys.executable, CHECK, "--root", self.root, os.path.join(self.root, "docs", "runbooks")]
        p = subprocess.run(args, capture_output=True, text=True)
        return p.returncode, p.stdout, p.stderr

    def run(self, cmd, cwd=None, env=None):
        """端末なしで実行する（新しいセッションにして、制御端末を持たせない）。"""
        p = subprocess.run(
            ["/bin/bash", "-c", cmd],
            cwd=cwd or self.root,
            env=env or self.env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            start_new_session=True,
        )
        return p.returncode, p.stdout + p.stderr

    def run_tty(self, cmd, answer="yes", timeout=60, before_answer=None):
        """端末つきで実行し、確認の問いが出たら answer を入力する（その前に before_answer を呼ぶ）。"""
        pid, fd = pty.fork()
        if pid == 0:
            try:
                os.chdir(self.root)
                os.execve("/bin/bash", ["/bin/bash", "-c", cmd], self.env)
            finally:
                os._exit(127)
        out = b""
        sent = False
        end = time.time() + timeout
        try:
            while True:
                if time.time() > end:
                    os.kill(pid, signal.SIGKILL)
                    raise AssertionError("時間内に終わらない: " + cmd)
                ready, _, _ = select.select([fd], [], [], 0.1)
                if not ready:
                    continue
                try:
                    data = os.read(fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                out += data
                if answer is not None and not sent and PROMPT_TAIL in out:
                    if before_answer is not None:
                        before_answer()
                    os.write(fd, (answer + "\n").encode("utf-8"))
                    sent = True
        finally:
            os.close(fd)
        _, status = os.waitpid(pid, 0)
        code = os.WEXITSTATUS(status) if os.WIFEXITED(status) else -1
        return code, out.decode("utf-8", "replace").replace("\r\n", "\n")

    def current(self):
        link = os.path.join(self.state, "current")
        return os.readlink(link) if os.path.islink(link) else None

    def snapshot(self):
        """反映先の全体（パス・種類・リンクの先・中身）。何も変えていないことを比べるのに使う。"""
        out = {}
        for top, dirs, files in os.walk(self.state):
            for name in dirs + files:
                p = os.path.join(top, name)
                rel = os.path.relpath(p, self.state)
                if os.path.islink(p):
                    out[rel] = ("link", os.readlink(p))
                elif os.path.isdir(p):
                    out[rel] = ("dir", None)
                else:
                    with open(p, "rb") as f:
                        out[rel] = ("file", f.read())
        return out

    def close(self):
        shutil.rmtree(self.tmp)


def blocks_of(text, section, title=None):
    """手順書の節（title を渡せば、その段）のコマンドのブロックを、書いてある文字のまま返す。"""
    doc = check_runbook.Doc("runbook.md", text)
    start, end = doc.section_range(section)
    if title is not None:
        steps = [no for no, level, t in doc.headings if level == 3 and start < no < end]
        named = [no for no, level, t in doc.headings if level == 3 and t == title]
        start = named[0]
        later = [no for no in steps if no > start]
        end = later[0] if later else end
    return ["\n".join(line for _, line in b.lines) for b in doc.shell_blocks(start, end)]


def step_titles(text):
    doc = check_runbook.Doc("runbook.md", text)
    start, end = doc.section_range("手順")
    return [t for no, level, t in doc.headings if level == 3 and start < no < end]


class Examples(unittest.TestCase):
    """見本が検査を通り、brief の4つの壊し方で落ちること（受入 A2・A4）。"""

    def setUp(self):
        self.ex = ExampleCopy()

    def tearDown(self):
        self.ex.close()

    def expect(self, rules):
        rc, out, err = self.ex.check()
        self.assertEqual(err, "")
        self.assertEqual(rules_of(out), set(rules), out)
        self.assertEqual(rc, 1 if rules else 0, out)

    def mutate(self, old, new, rel=EXAMPLE_RUNBOOK):
        self.ex.write(rel, replace_once(self.ex.read(rel), old, new))

    def test_examples_pass(self):
        self.assertEqual(self.ex.check(), (0, "", ""))

    def test_human_steps_are_four_to_six(self):
        self.assertTrue(4 <= len(step_titles(self.ex.read(EXAMPLE_RUNBOOK))) <= 6)

    def test_removed_section(self):
        text = self.ex.read(EXAMPLE_RUNBOOK)
        head, rest = text.split("## 確かめ方\n", 1)
        self.ex.write(EXAMPLE_RUNBOOK, head + "## 止まったときに読む表\n" + rest.split("## 止まったときに読む表\n", 1)[1])
        self.expect(["R1"])

    def test_missing_script(self):
        self.mutate("scripts/shop-config.sh verify", "scripts/shop-config-check.sh verify")
        self.expect(["R5"])

    def test_issue_number(self):
        self.mutate("- かかる時間の目安: 5分。", "- かかる時間の目安: 5分（#12 で測った）。")
        self.expect(["R6"])

    def test_full_width_after_variable(self):
        self.mutate("scripts/shop-config.sh status", 'scripts/shop-config.sh status "$SHOP_STATE_DIR（反映先）"')
        self.expect(["R9"])

    def test_full_width_after_variable_in_script(self):
        old = "printf '今の版: %s\\n'"
        self.mutate(old, 'echo "$STATE（反映先）"\n  ' + old, rel=os.path.join("scripts", "shop-config.sh"))
        self.expect(["R9"])


class ExampleScript(unittest.TestCase):
    """見本のスクリプトが、手順書に載せた形のまま動くこと（受入 A3）。"""

    def setUp(self):
        self.ex = ExampleCopy()
        self.text = self.ex.read(EXAMPLE_RUNBOOK)

    def tearDown(self):
        self.ex.close()

    def run_steps(self):
        outs = []
        for title in step_titles(self.text):
            for block in blocks_of(self.text, "手順", title):
                rc, out = self.ex.run_tty(block)
                self.assertEqual(rc, 0, block + "\n" + out)
                outs.append(out)
        return outs

    def test_runbook_blocks_as_written(self):
        # 1回目の反映（はじめて）
        outs = self.run_steps()
        self.assertIn("前提はすべて満たした", outs[0])
        self.assertIn("変わるキー:", outs[1])
        self.assertIn("反映した: 版", outs[2])
        self.assertIn("確かめた: すべて期待どおり", outs[3])
        self.assertRegex(outs[3], r"記録: shop の設定を反映した・版 [0-9a-f]{12}・.*・時刻 \d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ")
        first = self.ex.current()
        # 設定ファイルを直した2回目の反映
        self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
        outs = self.run_steps()
        self.assertIn("変わるキー: price.cake", outs[1])
        second = self.ex.current()
        self.assertNotEqual(first, second)
        # 止まったときに読む表（今の版を見る）
        for block in blocks_of(self.text, "止まったときに読む表"):
            rc, out = self.ex.run_tty(block)
            self.assertEqual(rc, 0, block + "\n" + out)
            self.assertIn("今の版: " + os.path.basename(second), out)
        # 失敗や中断のとき（前の版に戻す）
        for block in blocks_of(self.text, "失敗や中断のとき"):
            rc, out = self.ex.run_tty(block)
            self.assertEqual(rc, 0, block + "\n" + out)
        self.assertIn("戻した: 版", out)
        self.assertEqual(self.ex.current(), first)
        # AI が実行するとき（反映の dry-run と --yes、戻すの dry-run と --yes）
        expected = [first, second, second, first]
        blocks = blocks_of(self.text, "AI が実行するとき")
        self.assertEqual(len(blocks), len(expected), blocks)
        for block, want in zip(blocks, expected):
            rc, out = self.ex.run_tty(block, answer=None)
            self.assertEqual(rc, 0, block + "\n" + out)
            self.assertEqual(self.ex.current(), want, block)
        # 手順の3と4をやり直して、新しい版に戻す
        titles = step_titles(self.text)
        for title in titles[2:]:
            rc, out = self.ex.run_tty(blocks_of(self.text, "手順", title)[0])
            self.assertEqual(rc, 0, out)
        self.assertEqual(self.ex.current(), second)
        self.assertIn("確かめた: すべて期待どおり", out)

    def test_same_version_changes_nothing(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        before = self.ex.snapshot()
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
        self.assertEqual(rc, 0)
        self.assertIn("変わっていない:", out)
        self.assertNotIn("実行した:", out)
        self.assertEqual(self.ex.snapshot(), before)

    def test_refused_confirmation_changes_nothing(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
        before = self.ex.snapshot()
        rc, out = self.ex.run_tty("scripts/shop-config.sh apply", answer="no")
        self.assertEqual(rc, 1, out)
        self.assertIn("yes ではないので止めた", out)
        self.assertEqual(self.ex.snapshot(), before)

    def test_no_terminal_without_yes_changes_nothing(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
        before = self.ex.snapshot()
        for cmd in ["apply", "rollback"]:
            rc, out = self.ex.run("scripts/shop-config.sh " + cmd)
            self.assertIn(rc, (1, 2), out)
            self.assertEqual(self.ex.snapshot(), before, cmd)
        self.assertIn("端末が無いので", self.ex.run("scripts/shop-config.sh apply")[1])

    def test_config_changed_while_confirming(self):
        def change():
            self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
        rc, out = self.ex.run_tty("scripts/shop-config.sh apply", before_answer=change)
        self.assertEqual(rc, 1, out)
        self.assertIn("確認のあいだに設定ファイルが変わった", out)
        self.assertFalse(os.path.exists(self.ex.state))

    def test_dry_run_lines_match_real_run(self):
        for cmd in ["apply", "rollback"]:
            if cmd == "rollback":
                self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
                self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
            before = self.ex.snapshot() if os.path.exists(self.ex.state) else None
            rc, dry = self.ex.run("scripts/shop-config.sh {} --dry-run".format(cmd))
            self.assertEqual(rc, 0, dry)
            self.assertEqual(self.ex.snapshot() if before is not None else None, before)
            rc, real = self.ex.run("scripts/shop-config.sh {} --yes".format(cmd))
            self.assertEqual(rc, 0, real)
            planned = [line for line in dry.splitlines() if line.startswith("実行する: ")]
            self.assertTrue(planned, cmd)
            self.assertEqual(planned, [line for line in real.splitlines() if line.startswith("実行する: ")])
            done = [line.replace("実行した: ", "実行する: ", 1) for line in real.splitlines() if line.startswith("実行した: ")]
            self.assertEqual(planned, done)

    def test_missing_token_stops_before_changes(self):
        env = dict(self.ex.env)
        del env["SHOP_TOKEN"]
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes", env=env)
        self.assertEqual(rc, 2, out)
        self.assertIn("NG C2", out)
        self.assertFalse(os.path.exists(self.ex.state))

    def test_token_value_is_never_printed(self):
        token = self.ex.env["SHOP_TOKEN"]
        for cmd in ["check", "diff", "apply --yes", "verify", "status"]:
            rc, out = self.ex.run("scripts/shop-config.sh " + cmd)
            self.assertEqual(rc, 0, out)
            self.assertNotIn(token, out)
        self.assertIn("（{} 文字・値は出さない）".format(len(token)), self.ex.run("scripts/shop-config.sh check")[1])

    def test_broken_config_stops(self):
        self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.tea=430\n")
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
        self.assertEqual(rc, 1, out)
        self.assertIn("NG C4", out)
        self.assertIn("キー price.tea が重なっている", out)
        self.assertFalse(os.path.exists(self.ex.state))

    def test_changed_contents_are_found_and_repaired(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        with open(os.path.join(self.ex.state, "current", "shop.conf"), "a", encoding="utf-8") as f:
            f.write("price.water=100\n")
        rc, out = self.ex.run("scripts/shop-config.sh verify")
        self.assertEqual(rc, 1, out)
        self.assertIn("NG V2", out)
        self.assertNotIn("記録:", out)
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
        self.assertEqual(rc, 0, out)
        self.assertIn("中身を合わせ直した", out)
        self.assertEqual(self.ex.run("scripts/shop-config.sh verify")[0], 0)

    def test_missing_contents_are_restored(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        os.remove(os.path.join(self.ex.state, "current", "shop.conf"))
        rc, out = self.ex.run("scripts/shop-config.sh verify")
        self.assertEqual(rc, 1, out)
        self.assertIn("NG V2", out)
        rc, out = self.ex.run("scripts/shop-config.sh diff")
        self.assertEqual(rc, 0, out)
        self.assertIn("中身が無い", out)
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
        self.assertEqual(rc, 0, out)
        self.assertIn("中身を合わせ直した", out)
        self.assertEqual(self.ex.run("scripts/shop-config.sh verify")[0], 0)

    def test_rollback_without_previous(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        rc, out = self.ex.run("scripts/shop-config.sh rollback --yes")
        self.assertEqual(rc, 1, out)
        self.assertIn("NG B1", out)

    def test_rollback_twice_is_the_same_as_once(self):
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        first = self.ex.current()
        self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        self.assertEqual(self.ex.run("scripts/shop-config.sh rollback --yes")[0], 0)
        self.assertEqual(self.ex.current(), first)
        before = self.ex.snapshot()
        rc, out = self.ex.run("scripts/shop-config.sh rollback --yes")
        self.assertEqual(rc, 0, out)
        self.assertIn("変わっていない:", out)
        self.assertEqual(self.ex.snapshot(), before)

    def test_failure_midway_and_rerun(self):
        if hasattr(os, "geteuid") and os.geteuid() == 0:
            self.skipTest("root は権限に関係なく書ける")
        self.assertEqual(self.ex.run("scripts/shop-config.sh apply --yes")[0], 0)
        first = self.ex.current()
        self.ex.write("config/shop.conf", self.ex.read("config/shop.conf") + "price.cake=500\n")
        rc, dry = self.ex.run("scripts/shop-config.sh apply --dry-run")
        version = re.search(r"releases/([0-9a-f]{12})", dry.split("実行する: mkdir", 1)[1]).group(1)
        locked = os.path.join(self.ex.state, "releases", version)
        os.makedirs(locked)
        os.chmod(locked, 0o555)
        try:
            rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
            self.assertEqual(rc, 3, out)
            self.assertIn("変える途中で失敗した", out)
            self.assertEqual(self.ex.current(), first)
        finally:
            os.chmod(locked, 0o755)
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
        self.assertEqual(rc, 0, out)
        self.assertNotIn("実行した: mkdir", out)
        self.assertEqual(self.ex.current(), "releases/" + version)
        self.assertEqual(self.ex.run("scripts/shop-config.sh verify")[0], 0)

    def test_bad_state_dir_stops_before_changes(self):
        for value in ["/", "relative/state"]:
            env = dict(self.ex.env, SHOP_STATE_DIR=value)
            for cmd in ["check", "apply --yes", "status"]:
                rc, out = self.ex.run("scripts/shop-config.sh " + cmd, env=env)
                self.assertEqual(rc, 2, value + " " + cmd + "\n" + out)
                self.assertIn("NG C3", out)
        os.makedirs(os.path.join(self.ex.state, "current"))
        before = self.ex.snapshot()
        rc, out = self.ex.run("scripts/shop-config.sh apply --yes")
        self.assertEqual(rc, 2, out)
        self.assertIn("リンクでない", out)
        self.assertEqual(self.ex.snapshot(), before)

    def test_wrong_usage(self):
        for cmd in ["", "deploy", "check --yes", "apply --force"]:
            self.assertEqual(self.ex.run("scripts/shop-config.sh " + cmd)[0], 2, cmd)

    def test_runs_from_another_directory(self):
        rc, out = self.ex.run(os.path.join(self.ex.root, "scripts", "shop-config.sh") + " check", cwd=self.ex.tmp)
        self.assertEqual(rc, 0, out)

    def test_each_bash(self):
        """/bin/bash と PATH の bash のそれぞれで、名前を明示して動かす（macOS では 3.2 と新しい版）。"""
        shells = []
        for b in ["/bin/bash", shutil.which("bash")]:
            if b and os.path.exists(b) and os.path.realpath(b) not in [os.path.realpath(x) for x in shells]:
                shells.append(b)
        for b in shells:
            ex = ExampleCopy()
            try:
                for cmd in ["check", "diff", "apply --yes", "verify", "status"]:
                    rc, out = ex.run("{} scripts/shop-config.sh {}".format(b, cmd))
                    self.assertEqual(rc, 0, b + " " + cmd + "\n" + out)
                ex.write("config/shop.conf", ex.read("config/shop.conf") + "price.cake=500\n")
                for cmd in ["apply --yes", "rollback --yes", "rollback --yes"]:
                    rc, out = ex.run("{} scripts/shop-config.sh {}".format(b, cmd))
                    self.assertEqual(rc, 0, b + " " + cmd + "\n" + out)
            finally:
                ex.close()

    def test_shellcheck(self):
        tool = shutil.which("shellcheck")
        if tool is None:
            self.skipTest("shellcheck が無い")
        p = subprocess.run([tool, self.ex.path(os.path.join("scripts", "shop-config.sh"))], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)

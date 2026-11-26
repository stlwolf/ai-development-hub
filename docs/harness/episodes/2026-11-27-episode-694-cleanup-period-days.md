---
id: "01M8CRKYZ7D363XFARY8WKDWA8"
title: "#694 会話の記録の保存の期間（cleanupPeriodDays: 90）を hub の設定の宣言に入れる"
date: 2026-11-27
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/694"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "docs/harness/episodes/2026-10-08-episode-415-idle-compaction-off.md"
    reason: "同じ形の先例（値を settings.values.json に置き、宣言の項目とテストの場面を足す）"
  - type: reference
    ref: "https://code.claude.com/docs/en/settings-reference"
    reason: "cleanupPeriodDays の型・既定・スコープの扱いの一次情報"
tags: [claude-settings, cleanup-period-days, settings-harness, sync]
---

# #694 会話の記録の保存の期間（cleanupPeriodDays: 90）を hub の設定の宣言に入れる

## なぜこの作業が始まったか

Claude Code は会話の記録を既定で 30 日たつと消す（設定 `cleanupPeriodDays`）。会話の記録は、統括の交代の費用やセカンドオピニオンの指摘の採用を数える調査（#465・#652・#618）の元で、2026-11-27 の時点では毎日 1 日ぶんずつ消えていた。owner は 2026-11-27 に、保存の期間を 90 日にすると決めた。重要な設定は hub に正本を置いて sync で配る決まり（#359）なので、hub の宣言に入れる。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。owner が判断ボードで値を決めた小さな直しなので、認識合わせと plan は省く。設計SO も省き、実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテストは通す。
- 境界: 値は 90 で確定している。`desktopSessionCleanupPeriodDays` などほかのキーは足さない。`~/.claude/settings.json` を直接編集しない。sync を実物の家のディレクトリに対して実行しない。
- 注入された knowledge item: 統括の採用は0件。着手時に `knowledge-list --strict` を見て、次の4件が当たると判断して採用した。
  - `01KYMRE1NC7XX6N66RQ0MGGHF1`（上流の断定を自分の成果物へ書き写すとき）: issue 本文の「型は整数・最小 1・既定 30・0 は弾かれる」を、note に写す前に公式の文書へ当てる。
  - `01M2DRCP3QSG4NQWHNY6DSD3NJ`（変更そのものを見る受入の項目を書くとき）: 足した場面を変更前の正本で走らせ、落ちることを確かめる。
  - `01M54X75SV448T2R5Z7MR32E0G`（bash 3.2 でテストの合否を終了コードで読むとき）: 終了コードだけでなく、最後のまとめの行が出ていることと件数を両方の bash で比べる。
  - `01M579XZNAT7EXY4VPGRM9J8JW`（bash の文の中で変数の直後に日本語が来るとき）: テストの文言に変数を書いたら `${var}` で囲み、確かめのコマンドを当てる。

## 作業の記録

### Step 0: 着手（2026-11-27 05:24）

- baseline: `origin/master` `d398f1b`。
- worktree: `wt switch --create 'chore/#694_cleanup_period_days' --base origin/master --no-cd`。接頭辞は `branch-naming` の表の「設定変更」に当たる `chore/` で、brief の名前と同じ。
- 宣言の項目を列挙している README は無かった。`disableAgentView`・`idleCompaction`・`settings.values.json` を名前で書いているのは、宣言・値・known-keys・2本のテストと、過去の蒸留の文書だけである。過去の文書は当時の記録なので触らない。
- 変更前のテストの件数（bash 5.2.37 と `/bin/bash` 3.2.57 で同じ）: `test_apply_claude_settings.sh` PASS=269、`test_check_claude_settings.sh` PASS=94、`test_check_orphan_links.sh` PASS=87、`test_prune_orphan_links.sh` PASS=54、`test_sync_claude_statusline.sh` PASS=17、`test_sync_output_styles.sh` PASS=18。どれも FAIL=0。
- 件数の行の形は brief の `=== Results:` ではなく、`=== PASS=N FAIL=M ===`（statusline のテストだけ `=== RESULT: PASS=N FAIL=M ===`）だった。比べるのはこの行にする。

### Step 1: 上流の断定を公式の文書に当てた（2026-11-27 05:25）

issue 本文の「分かっていること」を note に写す前に、公式の文書を生の Markdown で取得して当てた（`curl -sSL https://code.claude.com/docs/en/settings-reference.md`・2026-11-26T20:24Z＝2026-11-27 05:24 JST・462,577 バイト）。手元の本体は `claude --version` で 2.1.332 である。

当たったもの:

- settings reference の `cleanupPeriodDays` の節に、`Type: number of days, a whole number, minimum 1` と `Default: 30` がある。同じ節に「`0` は検証で弾かれるので、長く残すなら `3650` のような大きな値にする」とある。issue の「整数・最小 1・既定 30・0 は弾かれる」は、そのまま裏が取れた。
- 同じ文書のスコープをまたぐときの表で、`cleanupPeriodDays` は「Every other key（値を持つ最上位のスコープの値を取る）」の例に挙がっている。宣言の `scope_behavior: override` はこれに合う。
- `claude-directory.md` の「Cleaned up automatically」節によると、同じ日数で会話の記録（`projects/<project>/<session>.jsonl`）のほか、subagent の記録・`tool-results/`・`file-history/`・`plans/`・`debug/`・`paste-cache/` なども消える。note にはこの事実を1文で入れた。

当てなかったもの:

- 「30 日で約 2GB、90 日で約 6GB」は issue の見積もりで、自分では測っていない。note には「#694 の時点の見積もり」と出どころを付けて書いた。
- Claude Desktop と Cowork で始めた会話は、v2.1.248 から既定でこの日数を過ぎても残る（別のキー `desktopSessionCleanupPeriodDays` の範囲）。brief の境界でほかのキーは足さないので、note にも入れていない。

### Step 2: 値・宣言・テストを直し、変更前の正本で落ちることを確かめた（2026-11-27 05:32）

直したもの:

- `canonical/claude/settings.values.json` に `"cleanupPeriodDays": 90` を足した。
- `canonical/claude/settings.harness.json` に `/cleanupPeriodDays` の項目を足した。形は `idleCompaction` と同じ `op: replace`・`scope_behavior: override`・値は `settings.values.json` から引く。note には、なぜ 90 日か（調査の元が既定の 30 日で消える・owner の裁定 2026-11-27）・公式の型と既定と `0` の扱い・スコープの扱い・ほかに消えるもの・容量の見積もり・30 日に戻す手順を書いた。戻す手順は、既存の2項目の note と同じ「項目を外すだけでは戻らない」の形にそろえた。
- `settings-known-keys.txt` は触らない。`cleanupPeriodDays` は取得日 2026-09-06 の一覧に既に載っている（56 行目）。
- `test_apply_claude_settings.sh` に [52] を足した。正本の値が 90 の数値であること、30 の settings が 90 に直ること、キーが無い settings に 90 が作られることを見る。[51] と同じく、正本から読まず値を直に見る。
- `test_check_claude_settings.sh` の `build_green` に `cleanupPeriodDays` を足し、[1] に一致の検査を足した。[28] で値だけ崩すとその項目だけが差分に出ること、[29] でキーが無いと「未適用」と出て「差分」とは言わないこと、[30] で公式の一覧にあるキーを「あります」と言い「ありません」とは言わないことを見る。[30] は idleCompaction の [27] の逆の場面である。

結果（bash 5.2.37 と `/bin/bash` 3.2.57 で件数の行が同じ）:

| 対象 | 変更前 | 変更後 | 変更前の正本に新しいテストだけ重ねた木 |
|------|--------|--------|------------------------------------|
| `test_apply_claude_settings.sh` | PASS=269 FAIL=0 | PASS=279 FAIL=0 | PASS=272 FAIL=5 |
| `test_check_claude_settings.sh` | PASS=94 FAIL=0 | PASS=106 FAIL=0 | PASS=100 FAIL=6 |
| `test_check_orphan_links.sh` | PASS=87 FAIL=0 | PASS=87 FAIL=0 | （触っていない） |
| `test_prune_orphan_links.sh` | PASS=54 FAIL=0 | PASS=54 FAIL=0 | （触っていない） |
| `test_sync_claude_statusline.sh` | PASS=17 FAIL=0 | PASS=17 FAIL=0 | （触っていない） |
| `test_sync_output_styles.sh` | PASS=18 FAIL=0 | PASS=18 FAIL=0 | （触っていない） |

- apply のテストの増分は 10 件で、足した [52] の 8 件のほかに、宣言から項目を導く既存の [22] の M1 と M6 が `/cleanupPeriodDays` のぶん 1 件ずつ増えた。check のテストの増分 12 件は、足した検査の数と同じである。
- 変更前の正本（`d398f1b` を `git archive` で展開した木）に新しい2本のテストだけを重ねると、足した節はどれも1つ以上落ちた。落ちなかった検査は、終了コードが 0 であること・個人層が無傷であること・ほかの項目が巻き込まれないこと（`ncc`）・「書いた値は数値」で、どれも見張りの役である。「書いた値は数値」は入力の 30 が既に数値なので変更前でも通る。文字列で配る誤りは、同じ節の「正本の値は数値」が止める。
- `shellcheck` は触った2本とも通った。変数の直後に日本語が来る位置の確かめ（`LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^[:space:] -~]'`）は当たりが無く、終了コード 1 だった。

実物に近い形での確かめ（読むだけ・実物の家のディレクトリでは sync しない）:

- 手元の `~/.claude/settings.json` を scratchpad に写し、worktree の宣言で apply してから check を当てた。手元には一時の措置として `90` が手で書いてあるので、apply は「変更はありません」で書かず、check は `一致 /cleanupPeriodDays` と「宣言どおり」を出して終了コード 0 だった。
- 写しから `cleanupPeriodDays` を消して（既定の 30 日で動いている形）apply すると、5 項目を当てて `90` を作った。宣言の外のキーは前後で変わっていない（`jq -S 'del(.cleanupPeriodDays)'` の比較で一致）。
- 実物の `~/.claude/settings.json` は、sha256 が前後で一致し、書き換えていない。
- issue の完了の条件「sync のあと `~/.claude/settings.json` の値が 90 になる」「`sync --check` が一致と出す」は、マージと sync のあとでなければ文面どおりには確かめられない。sync は統括の担当なので、写しへの apply と check で代わりに確かめた。

### Step 3: 実装SO（弱・Codex 1レーン）— 3件の指摘を3件とも採った（2026-11-27 05:35）

`so-compare --codex-only`（`SO_TIMEOUT=480`）を、worktree の未コミットの差分に当てた。依頼文には `.oe/` の中身とほかのリポジトリの名前を入れていない。Codex は `model_resolved=gpt-6.1-sol`（出所は config で、観測値ではない）・`cli_version=codex-cli 0.170.0`・78 秒・リトライなし・`tool_status=not_observed` で返った。出力は master の `tmp/694-cleanup-period-days/so-impl-r1/`（gitignored）にある。4つの観点のうち、宣言の項目の形と既存の項目・テストへの影響の2つは「問題なし」だった。

#### 指摘1: note の「30 日たつと黙って消える」は、対象と起算点が広すぎた（採った）

公式の `cleanupPeriodDays` の節は、消えるのを「保持期間より長く使っていないセッション」とし、Claude Desktop と Cowork で始めた会話（またはそこで最後に続けた会話）は既定でこの期間を過ぎても残す、と書いている。Step 1 でこの段落を読んでいて、別のキーの範囲だから note に入れないと決めていたが、その結果 note の文が「すべての会話の記録が 30 日で消える」と読める形になっていた。「最後に使ってから 30 日を過ぎた会話の記録が、セッションを起動したあとの裏の処理で消える」に直し、Desktop と Cowork の例外を1文足した。例外を扱う別のキーは足していない（brief の境界）。

#### 指摘2: check のテストに、文字列の "90" の場面が無かった（採った）

apply の [52] は正本と書いた値が数値であることを見るが、check の側には、settings が文字列の `"90"` を持つときに差分と出すかの場面が無かった。check が型を丸めて比べる形に変わると、公式の検証で弾かれうる値を「一致」と言うことになる。check の [31] として足した。

#### 指摘3: check のテストに、上位スコープの同名キーの場面が無かった（採った）

既存の [11] は hooks と statusLine で「マージされる項目」と「負ける項目」の文言の違いを見ているが、`cleanupPeriodDays` の項目について `scope_behavior` を見る場面は無かった。この項目を誤って `merge` に変えても、どのテストも落ちない。公式ではこのキーは最上位のスコープの値だけが効くので、プロジェクトの `.claude/settings.local.json` に同名のキーがあれば「上書き」と警告して終了コード 1 になるべきである。check の [32] として足した。

足したあとの結果（bash 5.2.37 と `/bin/bash` 3.2.57 で同じ）:

- `test_check_claude_settings.sh` は PASS=112 FAIL=0（Step 2 の 106 から 6 件増えた）。ほかの5本は Step 2 と同じ件数で FAIL=0 である。
- 変更前の正本に新しいテストを重ねた木では、check は PASS=102 FAIL=10 になり、[31] と [32] もそれぞれ2件ずつ落ちた。
- 宣言の写しで `/cleanupPeriodDays` の `scope_behavior` だけを `merge` に書き換えた木では、check は FAIL=3 で、落ちたのは [32] の3件だけだった。[32] がこの項目の `scope_behavior` を見ていることを確かめた。
- `shellcheck` と、変数の直後に日本語が来る位置の確かめは、Step 2 と同じく通った。

SO が「今回独立に確かめていない」とした「30 日ぶんで約 2GB」は、note に「#694 の時点の見積もり」と出どころを付けてあるので、そのままにした。

---
id: "01M4DT43Z3C9G18MQV2FT5HP00"
title: "#415 Claude Code のアイドル時の圧縮（idleCompaction）を hub の設定の宣言で止める"
date: 2026-10-08
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/415"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/415#issuecomment-6060507646"
    reason: "着手時の認識合わせ（確定版）。5項目に成果物で答える"
  - type: reference
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の設計（apply は宣言した項目にしか触らない・known-keys は警告どまり）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/pull/416"
    reason: "この単位の PR"
tags: [claude-settings, idle-compaction, settings-harness, sync]
promotion:
  - subject: "公式に載っていないキーを宣言で配るときの note には、本体の版と読み出し箇所と、実行中のセッションに効くかの確認状態を書く、という型"
    verdict: not-required
    ref: "本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）"
  - subject: "公式に無いキーは settings-known-keys.txt に載せず、check の警告を意図どおりとして残す"
    verdict: not-required
    ref: "本文: Step 2: known-keys に足さないと決めた（2026-10-08 22:12 頃）"
  - subject: "issue の前提『設定は起動時に読まれる』を写さず、note に未確認と書いた"
    verdict: not-required
    ref: "本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）"
---

# #415 Claude Code のアイドル時の圧縮（idleCompaction）を hub の設定の宣言で止める

## Context（なぜこの作業が始まったか）

Claude Code の「アイドル時の圧縮」で、約54分放ったセッションの会話が要約に置き換わる。止める設定キー `idleCompaction` は、手元で確かめた範囲では 2.1.291 から入っている（Step 1）。機能そのものはそれより前から動いていた（Step 4 の指摘2）。owner の裁定（2026-10-08）は「止める」。文脈の切れ目は引き継ぎと委譲で自分たちが決めている、という理由である。軽微修正扱いで plan は書かず、設計SO は省く（owner の了承 2026-10-08）。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテストは通す。

## Step 0: 着手（2026-10-08 22:00 頃）

- baseline: master `6021ddb`（`git fetch` 後の `origin/master` と一致）。
- worktree: `wt switch --create 'chore/#415_idle_compaction_off' --base master`。
- 先例: `disableAgentView` の項目（#338・PR #402）。値の置き場 `canonical/claude/settings.values.json` はそのとき新設されたもので、`test_sync_output_styles.sh` が使い捨ての木へ複写する一覧も宣言の `source.file` から導く形に直してある。同じファイルに値を足すだけなら、複写の一覧を触る必要はない。

## Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）

#415 本文と確定版コメントの断定を、note に写す前に一次情報へ当てた（注入 knowledge `01KYMRE1NC7XX6N66RQ0MGGHF1`）。

当たったもの:

- 手元の版は `claude --version` → `2.1.294 (Claude Code)`。
- 本体 `~/.local/share/claude/versions/2.1.294` の設定スキーマに `idleCompaction:()=>H().optional().describe("Set to false to stop Claude Code from compacting a long conversation while the session is idle. Setting it to true does not turn idle compaction on."` がある。`idleCompaction` の文字列は 2.1.280 に0件、2.1.291 に3件。
- 読み出しは `function kxt(){return os("idleCompaction",!0).value}`。既定値は true で、false を置くと判定関数が `idle_compaction_off` を返して圧縮しない。
- 判定関数の順序は、サーバー側の機能フラグ `tengu_sunny_locket` の mode が off → `disabled`、`autoCompactEnabled` が false → `compaction_off`、`idleCompaction` が false → `idle_compaction_off`、以下 prefix の変化・キャッシュ期間が1時間でない・期限切れ・トークン数が最小未満・新しいリクエストあり・使用量の上限近く、である。
- 発火の時点は「最後のやり取り＋（キャッシュの期限−最後のやり取り）×0.9」で、0.9 は機能フラグで 0.5〜0.95 の範囲に変えられる。タイマーを仕掛けるのは直前のリクエストのキャッシュ期間が `1h` のときだけである。
- 最小トークン数は `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS ?? フラグの minTokens` で、数値なら `max(100000, n)`、無ければ 200000。
- 公式の settings reference（2026-10-08 22:10 頃に取得）と CHANGELOG（2.1.290〜2.1.294 を含む）に `idleCompaction` もアイドル時の圧縮も載っていない。

当たらなかったもの・食い違ったもの:

- 「設定はセッション起動時に読まれ、いま動いているセッションには効かない」（#415 本文の「やらないこと」・確定版の「issue に書いていないが要ること」・brief の scope）は、一次情報で裏が取れなかった。公式の settings ページの「When edits take effect」節は、設定ファイルを監視して変更を読み直し、多くの項目を再起動なしで実行中のセッションに反映すると書いている。起動時だけ読む項目として挙がっているのは `model` と `effortLevel`・`modelSettings` などで、`idleCompaction` は公式に載っていないので挙がっていない。本体の側も、この設定を起動時ではなく、タイマーが発火した時点の判定（`kxt()`）で読んでいる。設定の読み出し `os()` は呼ばれるたびにスコープごとの設定を引き直す形である。ただし、読み直しがこのキーに及ぶことは実測していないので、未確認として扱う。note には「実行中のセッションに効くかは未確認。確実にしたいセッションは起動し直す」と書き、断定の強さを上げない。
- 「最小トークン数は環境変数で上げられる（下限 100,000）」は、正確には「環境変数で 100,000 以上の任意の値にできる」で、既定の 200,000 より下げることもできる。中間案の1行にはこの形で書く。

昇格の印: 公式に載っていないキーを宣言で配るときの note には、本体の版と読み出し箇所と、実行中のセッションに効くかの確認状態を書く、という型

## Step 2: known-keys に足さないと決めた（2026-10-08 22:12 頃）

`scripts/sync/check-claude-settings.sh` の (6)「宣言した項目名の綴り」節は、一覧に無いキーに `warn` を出すだけで、`has_diffs` にも終了コードにも効かない。一覧の用途は、ファイルの冒頭にあるとおり綴りの確認だけである。

選択肢は2つあった。

- 足す: 警告は消える。ただし check は一覧に載ったキーを「公式の一覧にあります」と印字するので、公式に無いキーについて事実と違うことを言う。区別して印字するには check 本体を直す必要があり、この単位の範囲を超える。
- 足さない（採った）: check は毎回「idleCompaction は公式の一覧にありません」と警告するが、これは事実どおりで、緑は妨げない。公式に載って一覧を取り直せば、自然に一覧へ入って警告が消える。

#415 本文の「一覧が検査に使われているなら足す」は、一覧に無いことが検査を止めるなら足す、という意味で読んだ。実際には止めないので、足す理由が無い。代わりに、一覧の冒頭に「宣言で使うが、ここに載せないキー」として `idleCompaction` と理由を3行のコメントで残した（check は `#` 行を読まない）。後から誰かが警告を消そうとして一覧に足すのを防ぐためである。宣言の note にも、この警告は意図どおりだと書いた。

## Step 3: 宣言・値・テストを直し、変更前の master で落ちることを確かめた

先例の形（`op: replace`・`scope_behavior: override`・値は `settings.values.json`）が `idleCompaction` にも成り立つかを確かめた（注入 knowledge `01KZVHE0KQ5VCX0SXH0F4SM14D`）。本体の設定の読み出し `os()` は、優先度の高いスコープから順に見て最初に見つかった値を返すので、スカラーとして上書きされるキーであり `override` が合う。値が `false` なので、apply が `false` を書き落とさないこと、check が「キーが無い」と「値が違う」を分けることを、テストで見た。先例との違い（公式の一覧に無いこと、`true` が既定に戻すだけで強制的に有効にしないこと）は note に書いた。

note に入れたもの（brief の6点との対応）:

- なぜ止めるか: owner の裁定（2026-10-08・#415）。
- 止めても残るもの: 通常の自動圧縮と手動の `/compact`。
- 失うもの: 1時間以上放ったセッションに戻った最初の応答が、会話全体をキャッシュなしで読み直すので重くなり、使用量も増える。
- 公式に無いキーでサーバー側のフラグで有効化される機能であること: 2026-10-08 時点で settings reference にも CHANGELOG にも無い。
- 起動時に読まれる点: Step 1 のとおり裏が取れなかったので、「実行中のセッションに効くかは未確認。確実に止めたいセッションは起動し直す」と書いた。brief の文面（起動時に読まれ、既存のセッションには効かない）からは意図して変えている。
- ON に戻す手順: `disableAgentView` の note と同じ形。

ほかに、check の警告が意図どおりであることと、中間案（環境変数 `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`）を1行ずつ入れた。

テストに足した検査:

- `test_apply_claude_settings.sh`: [4] と [17] の「宣言の項目だけ」を4項目にした。[51] で、正本の値が `false` であること、`true` の settings が `false` に直ること、キーが無い settings に `false`（`null` ではない）が作られることを見る。
- `test_check_claude_settings.sh`: `build_green` に `idleCompaction` を足し、[1] に一致の検査を足した。[25] で値だけ崩すとその項目だけが差分に出ること、[26] でキーが無いと「未適用」と出て「差分」とは言わないこと、[27] で公式の一覧に無いキーが警告だけで緑を妨げないことを見る。

結果（注入 knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ`）:

| 対象 | 変更後の枝 | 変更前の master `6021ddb` にテストだけ重ねた木 |
|------|-----------|------------------------------------------|
| `test_apply_claude_settings.sh` | PASS=221 FAIL=0（変更前 215） | PASS=215 FAIL=6 |
| `test_check_claude_settings.sh` | PASS=94 FAIL=0（変更前 83） | PASS=88 FAIL=6 |

master で通った追加の検査は、終了コードが 0 であることと、個人層が無傷であること、他の項目が巻き込まれないこと（`ncc`）で、どれも見張りの役である。変化を見分ける検査はすべての節に1つ以上あり、そのすべてが master で落ちた。shellcheck は2本とも通った。sync の起動テスト（`test_sync_claude_statusline.sh` 17 PASS、`test_sync_output_styles.sh` 18 PASS）も通った。後者は宣言の `source.file` から複写の一覧を導くので、値のファイルに1行足しただけでは複写の一覧を直す必要がなかった。

check の確かめ方:

- 手元の `~/.claude/settings.json` の写しに、枝の宣言で apply してから check を当てた。apply は4項目を適用して rc=0、check は rc=0 で「宣言どおり」になり、`idleCompaction` の綴りの警告だけが出た。宣言外のキーは apply の前後で変わっていない（`jq -S 'del(.idleCompaction)'` の比較で一致）。実物の `~/.claude/settings.json` は shasum が前後で一致し、書き換えていない。
- worktree から `./scripts/sync.sh --check claude` も走らせた（読むだけ）。rc=1 で、settings の節は既存3項目が一致し、`/idleCompaction` だけが「未適用」だった。sync はマージ後に統括が走らせるので、この時点では未適用が正しい。ほかに symlink のずれが 54 件出たが、これは worktree から走らせると比べる先が worktree のパスになるためで、この変更とは関係がない。brief の受入「`./scripts/sync.sh --check claude` が足した項目を含めて通る」は、マージと sync の前には文面どおりには満たせない。写しへの apply と check で代わりに確かめ、マージ後の sync のあとに統括が文面どおり確かめる形にした。

## Step 4: 実装SO（弱・Codex 1レーン）— 2件の指摘を2件とも採った（2026-10-08 22:18）

`so-compare --codex-only`（`SO_TIMEOUT=480`）を差分に当てた。Codex は `model_resolved=gpt-6-sol`（出所は config で、観測値ではない）、97秒・リトライなしで返った。出力は master の `tmp/415-idle-compaction-off/so-impl-r1/`（gitignored）にある。5つの観点のうち、宣言の項目と値・known-keys の判断・テストの3つは「問題なし」だった。

### 指摘1: note の「失うもの」が、常に起きる結果のように書かれていた（採った）

本体はサーバー側の機能フラグの mode が `off` ならアイドル時の圧縮をそもそも行わないので、そのときは設定を `false` にしても失うものは無い。Step 1 で自分でも判定関数の最初の分岐として読んでいたのに、note の「失うもの」に条件を付け忘れていた。「失うものが出るのは、機能がサーバー側で有効なときだけ」と条件を付けた。

### 指摘2: 「2.1.291 以降に入った」は、設定キーの有無からしか言えない（採った）

確かめたのは「設定キーの文字列が 2.1.291 にあり、2.1.280 に無い」までで、機能の導入版ではない。Codex が挙げた https://github.com/anthropics/claude-code/issues/98747 を開いて確かめた。題は「2.1.286 idle compaction silently discards working context ...; no opt-out」で、2.1.286 から動いていて止める手段が無い、という報告である（2026-10-01 起票、2026-10-06 に completed で閉じられた）。保守者の 2026-10-02 のコメントに「setting is coming. Currently it's doing this only for larger contexts (200k+)」とある。機能が先に入り、止める設定キーが後から入った、と読める。note と known-keys のコメントは「手元で確かめた本体 2.1.291〜2.1.294 の設定スキーマにあり、2.1.280 には無い」に直した。この episode の Context も直した。2.1.281〜2.1.290 の本体は手元に無く、確かめていない。

同じ issue のコメント（2026-10-02・10-03）に、2.1.287 ではアイドル時の圧縮の記録と PreCompact hook に `trigger: "manual"` が付く、という第三者の報告がある。#415 本文は「通常の自動圧縮と同じ `trigger: auto` が付く」としていて、食い違う。版で変わった可能性もあり、この単位では確かめていない。note にも確かめ方にも trigger の値は使っていないので、この変更には影響しない。報告で範囲外として伝える。

追記: PR #402 の本文に「`disableAgentView` は走っているペインにも効いている」という owner の確認がある。設定ファイルの読み直しが実行中のセッションに及ぶ実例の1つだが、別のキーなので、`idleCompaction` の「未確認」は変えない。

## Step 5: PR を作り、Copilot に1ラウンド依頼した（2026-10-08 22:20）

PR #416 を作り（`Refs #415`）、`gh pr edit 416 --add-reviewer @copilot` で依頼した。Copilot は 22:22 に `COMMENTED` で返し、概要は「Approval recommended・0 open findings」、行コメントは0件だった。未返信のスレッドは0件なので、返信するものは無い。再依頼はしていない。

## Closure（2026-10-08・マージ前）

### tier

heavy で閉じる。品質ゲートとして `so-compare` を意図的に起動し（`本文: Step 4: 実装SO（弱・Codex 1レーン）— 2件の指摘を2件とも採った（2026-10-08 22:18）`）、その指摘2件を採ってコードを直したので、heavy トリガと opt-out の失格条件の両方に当たる。brief は「closure は opt-out（1行）でよい」としていたが、opt-out の定型は「follow-up: なし」と書く形で、この単位には行き先のある follow-up が残るため、定型を書くと事実と違う。brief の許可は上限を緩めるものと読み、skill の tier 規則に従った。そのかわり各項目は短くし、本文への pointer で済ませる。

### closure gate checklist

- Context / なぜ: 冒頭にある（`本文: Context（なぜこの作業が始まったか）`）。
- 次の消費者: (1) 統括。報告と PR #416 を読んでマージと sync を判断する。(2) 次に、公式に載っていないキーを宣言で配る作業。known-keys の扱いと note の書き方の先例として、この単位の宣言と known-keys のコメントを読む。
- follow-up routing: 下の「follow-up routing」節。
- 昇格の判定: 下の「昇格の判定」節と frontmatter の `promotion`。
- status: `stable` に確定する。達成度は「達成」。ただし brief の受入のうち「`./scripts/sync.sh --check claude` が足した項目を含めて通る」は、マージと sync の前には文面どおりに満たせないので、写しへの apply と check で代わりに確かめ、文面どおりの確認はマージ後の統括の作業として残した（`本文: Step 3: 宣言・値・テストを直し、変更前の master で落ちることを確かめた`）。
- evidence anchor: 揮発しうる参照は実装SO の出力（master の `tmp/415-idle-compaction-off/so-impl-r1/`）で、要点（モデル・所要時間・指摘2件と採否）は Step 4 に写してある。
- SO 証跡リンク: 実装SO は Step 4、closure の外部チェックは下の「Step 4: 外部チェック（closure の品質）」節。
- 観測の書き戻し: brief の slot に載っていた4件（`01M2DRCP3QSG4NQWHNY6DSD3NJ` / `01KYMRE1NC7XX6N66RQ0MGGHF1` / `01KZVHE0KQ5VCX0SXH0F4SM14D` / `01M25B813S5ZD07QK92EF3D9PV`）に1レコードずつ足した。前の3件は `followed`、最後の1件は実測をしなかったので `no_opportunity` である。`01KYMRE1NC7XX6N66RQ0MGGHF1` の note には、issue の「2.1.291 以降に入った」を確かめずに写して実装SO に直された件も書いた。4件とも `validate-knowledge` が OK を返した。
- 認識合わせの抜け: 確定版に無かった要件は見つかっていない。確定版にあった前提（設定は起動時に読まれ、いま動いているセッションには効かない）が裏の取れないものだったのは、抜けではなく前提の誤りである。訂正は follow-up 1 で統括へ渡す。

### 受入の結果

| 受入（brief） | 結果 | 根拠 |
|---------------|------|------|
| `./scripts/sync.sh --check claude` が足した項目を含めて通る | 写しで満たした。文面どおりの確認はマージ後 | `本文: Step 3: 宣言・値・テストを直し、変更前の master で落ちることを確かめた` |
| テスト2本が通り、足した検査は変更前の master では落ちる | 満たした（221/0・94/0、master では6件ずつ落ちる） | 同上 |
| note に6点がある | 満たした。5点目（起動時に読まれる）は裏が取れず「未確認」と書いた | 同上、`本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）` |
| 確定版の5項目に成果物の中で答えがある | 満たした（下の表） | — |

| 確定版の項目 | 答えの置き場 |
|--------------|--------------|
| 起動時に読まれる点 | 宣言の note（未確認・確実にしたいなら起動し直す）と `本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）` |
| known-keys | `本文: Step 2: known-keys に足さないと決めた（2026-10-08 22:12 頃）`、known-keys の冒頭のコメント、宣言の note |
| ON に戻す手順 | 宣言の note（`disableAgentView` と同じ形。`true` は既定に戻すだけ） |
| 確かめ方 | 記録の上で、圧縮の直前の間隔が54〜56分のものが、設定のあとに起動したセッションで0件であること（PR #416 本文の「マージ後にすること」）。trigger の値には頼らない（`本文: Step 4: 実装SO（弱・Codex 1レーン）— 2件の指摘を2件とも採った（2026-10-08 22:18）` の食い違いのため） |
| 実測の条件 | 実測はしていない（owner: 任意）。するなら、2.1.291 以降・コンテキスト 200,000 トークン以上・自動圧縮が有効・キャッシュ期間が1時間のセッションで、処置ありと処置なしを比べる。処置なしの側が条件を満たしていることは、処置とは別の経路（本体の版と記録のトークン数）で確かめる |

### follow-up routing

1. #415 本文と確定版に、一次情報と合わない記述が3件ある。行き先は統括への報告（`.oe/report-415.md`）で、issue 本文や確定版コメントを直すか、別のリポジトリの統括へ伝える内容を直すかは統括が決める。成果物（note・known-keys のコメント・PR 本文）には正しい形を反映した。
   - 「設定は起動時に読まれ、いま動いているセッションには効かない」は裏が取れなかった（`本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）`）。PR #416 本文の「issue の前提から変えた点」にも書いた。
   - 「2.1.291 以降で入った『アイドル時の圧縮』」は、設定キーの版であって機能の版ではない。外部の報告では機能は 2.1.286 から動いている（`本文: Step 4: 実装SO（弱・Codex 1レーン）— 2件の指摘を2件とも採った（2026-10-08 22:18）`）。
   - 「最小トークン数は環境変数で上げられる（下限 100,000）」は、正確には「100,000 以上の任意の値にでき、既定の 200,000 より下げることもできる」である（`本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）`）。
2. 記録上の trigger の値が食い違っている（#415 本文は `auto`、外部の報告では 2.1.287 で `manual`）。行き先は統括への報告で、範囲外として伝える。確かめ方は trigger に依存しないので、この単位では追わない。
3. マージ後の `./scripts/sync.sh claude` と、`--check claude` での文面どおりの確認。行き先は統括（#415 本文の「やること」の最後の項）。
4. 止まっていることの実測（55分放置の対比較）。owner の判断で任意なので、この単位では追わない。条件は上の表の「実測の条件」にある。
5. 実行中のセッションに効くかの実測。追わない。確実にしたいセッションは起動し直す、で運用が足りる。統括への報告で伝える。
6. brief は opt-out を許していたが、skill の tier 規則では opt-out にならなかった。行き先は統括への報告で、brief の書き方の問題として1行伝える。

### 昇格の判定

1. 「公式に載っていないキーを宣言で配るときの note には、本体の版と読み出し箇所と、実行中のセッションに効くかの確認状態を書く、という型」— `not-required`。1段目で外れる。型は宣言の note そのものが先例として残り、次に宣言する人はその note を読めば使える。この単位が `disableAgentView` の note を先例として写したのと同じ経路である。比べて棄却した案も無い（Q1 に当たらない）。根拠: `本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）`。
2. 「公式に無いキーは settings-known-keys.txt に載せず、check の警告を意図どおりとして残す」— `not-required`。足す案と比べて棄却したので Q1 には当たる。ただし1段目で外れる。理由は `settings-known-keys.txt` の冒頭のコメントと宣言の note という、判断を見直す人が必ず開く正本に書いてあり、decision へ写しても読み手が得るものは増えない。覆すかどうかも、check が一覧に載ったキーを「公式の一覧にあります」と印字するという実物を見れば決まる、確認の側である（Q2 に当たらない）。check が区別して印字するよう直されれば前提が変わる（Q3）が、そのときは同じコメントを見直せばよい。根拠: `本文: Step 2: known-keys に足さないと決めた（2026-10-08 22:12 頃）`。
3. 「issue の前提『設定は起動時に読まれる』を写さず、note に未確認と書いた」— `not-required`。実測すれば決まる事実の扱いで、覆すのに議論は要らない（Q2 に当たらない）。根拠: `本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）`。

### 構造化 FB（出力型 × 消費チャネル）

- 事実・失敗: note の「失うもの」に、自分で読んでいた条件（機能がサーバー側で有効なとき）を付け忘れた。issue の「2.1.291 以降に入った」を、機能の版か設定キーの版かを確かめずに Context へ写した。どちらも実装SO に指摘されて直した（`本文: Step 4: 実装SO（弱・Codex 1レーン）— 2件の指摘を2件とも採った（2026-10-08 22:18）`）。上流の前提の食い違いは `本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）`。brief の受入「`./scripts/sync.sh --check claude` が足した項目を含めて通る」は、worktree から走らせると rc=1 で、マージと sync の前には文面どおり満たせなかった。settings の節で差分になったのは `/idleCompaction` の「未適用」だけで、ほかは worktree から走らせたことによる symlink のずれである（`本文: Step 3: 宣言・値・テストを直し、変更前の master で落ちることを確かめた`）。
- 決定と根拠: known-keys に足さない判断と、棄却した「足す」案は `本文: Step 2: known-keys に足さないと決めた（2026-10-08 22:12 頃）`。
- わかったこと: 本体の判定関数の順序、発火の時点、最小トークン数の式、設定の読み出しの形は `本文: Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）`。機能そのものは外部の報告で 2.1.286 から動いていて、止める設定キーが後から入った（`本文: Step 4: 実装SO（弱・Codex 1レーン）— 2件の指摘を2件とも採った（2026-10-08 22:18）`）。
- 原則: 新しい対構造は無い。文字列の有無から言えるのはその文字列の版であって機能の版ではない、という失敗は、注入された `01KYMRE1NC7XX6N66RQ0MGGHF1`（上流の断定の強さを上げない）の範囲に収まる。
- 蒸留シグナル: なし。knowledge store への収穫もしない（下の Step 5）。
- 残課題: 上の follow-up routing の6件。実行中のセッションに効くかと、止まっていることは、どちらも実測していない。

### Step 4: 外部チェック（closure の品質）

`so-compare --codex-only` で closure の4観点（選択的省略・routing・evidence anchor・back-propagation）を確かめた。Codex（`gpt-6-sol`・出所は config）は75秒で返った。出力は master の `tmp/415-idle-compaction-off/so-closure-r1/` にある。routing と evidence anchor は問題なしで、指摘2件は2件とも採った。

- 選択的省略: `sync.sh --check claude` が rc=1 で受入を文面どおり満たせなかったことが、受入の表にはあるのに事実・失敗の項目に無かった。事実・失敗に足した。
- back-propagation: issue 本文の誤りのうち、follow-up に行き先があったのは「起動時に読まれる」だけで、導入版と最小トークン数の2件が漏れていた。follow-up 1 を3件の形に直した。

### Step 5: negative knowledge の収穫

収穫なし。この単位の失敗は、注入された `01KYMRE1NC7XX6N66RQ0MGGHF1` の教訓がそのまま当てはまる形で起きたので、新しい item にすると重複になる。代わりに、その item の観測の note に失敗を書いた。

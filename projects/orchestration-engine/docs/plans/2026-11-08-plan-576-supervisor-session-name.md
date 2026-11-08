---
id: "01M6XFZCAV660AB61J36YACWYN"
title: "#576 統括のセッションに resume の一覧で見分けられる名前を付ける"
date: 2026-11-08
type: plan
status: draft   # ゲート3 の承認待ち
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/576"
    reason: "本 plan の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/576#issuecomment-6721086870"
    reason: "着手時の認識合わせの確定版（深掘りなし）。「要ること」の7項目はここから来た"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-08-episode-576-supervisor-session-name.md"
    reason: "この plan の作業の記録（P1 の案・公式ドキュメントで確かめたこと・設計SO の採否）"
  - type: reference
    ref: "projects/orchestration-engine/docs/plans/2026-11-06-plan-577-record-identity-key.md"
    reason: "統括の lease（session_id と generation を持つ記録）を入れた plan。要求の ID の材料"
tags: [orchestration, hooks, session-name, lease, supervisor, plan]
---

# #576 統括のセッションに resume の一覧で見分けられる名前を付ける

## 背景

統括は master で動くので、セッション名の hook（`canonical/hooks/scripts/session-name.sh`）の Path2 がリポジトリ名を付ける。`claude --resume` の一覧では、統括と、master で動くほかのセッションが同じ名前で並び、統括を探せない（2026-11-06・owner の指摘。hub の統括の会話6本がすべて `ai-development-hub` だった）。

## この plan の範囲

- 統括のセッション名の決まりを決める。
- 統括が席を取ったとき（`oe-handoff take`・`oe-register root`）に、手で `/rename` しなくても、次のプロンプトでその名前が付くようにする。
- 名前の記録は session_id を鍵にする。
- `session-name.sh` のほかの道（Path1 の `#<issue> <slug>`・Path2 のブランチ名とリポジトリ名・手で付けた名前を尊重する決まり）を変えない。hook のテストを新しく足して確かめる。
- 実物の `claude -r` の一覧で確かめ、episode に写す（業務のリポジトリの名前は伏せる）。

範囲の外: ペインを鍵にした記録の作り直し（#577）、子のセッション名、`--fork-session` で session_id が変わったときの名前の引き継ぎ（#355 で席を取り直す手順に乗る）。

## 上流の主張の確かめ（結果）

- `claude -r <語>` の範囲（verified・https://code.claude.com/docs/en/sessions.md 「Resume by session ID or name」「Where the session picker looks」）: 名前の resume は今のリポジトリとその worktree の中で探す。1件に完全一致すれば一覧を出さずに入り、そうでなければ語を入れた一覧を開く。一覧の既定の範囲は今の worktree で、`Ctrl+W` で同じリポジトリの worktree 全部、`Ctrl+A` で全プロジェクトに広がる。
- セッション名の置き場（verified・手元の会話の記録 `~/.claude/projects/<パス>/<session_id>.jsonl` の `"type":"custom-title"` の行）: hook が出した `sessionTitle` は、その会話の記録に残る。同じ session_id で resume すれば名前は残る。
- 統括の lease（verified・`projects/orchestration-engine/lib/lease.sh:17-19` の形と、手元の `~/.claude/state/oe-lease/` の記録）: hub の統括の lease は1本で `current_generation` は 1 である。board の「統括23代目」の代とは一致しない。
- take が代を決める所（verified・`projects/orchestration-engine/bin/oe-handoff:668-671`）: `--generation` か、board の「現統括: 統括N代目」に 1 を足した値。
- take と root が自分の session_id を知る経路（verified・`bin/oe-handoff:817` と `bin/oe-register:44`）: 環境変数 `CLAUDE_CODE_SESSION_ID`。

## 設計判断

### DJ-1 名前の決まり（GATE 3 の問い1）

`cockpit <リポジトリ名> <N>代目` にする（R1）。代が分からないとき（`oe-register root` で新しく統括を立てた・take で board から代を読めなかった）は `cockpit <リポジトリ名>` にする。

- リポジトリ名は、席を取ったプロセスの cwd の git のトップのディレクトリ名（`git rev-parse --show-toplevel` の basename）にする。git でなければ cwd の basename にする。いまの Path2 がリポジトリ名に落とすときと同じ材料である。
- 代を入れる理由は2つある。1つ目は、退任した統括と今の統括を一覧で見分けるためである。退任した統括の会話はもうプロンプトを受けないので、hook はその名前を変えられない。代が無いと、今の統括と同じ名前のまま残る。2つ目は、名前がリポジトリの中で1つに決まるので、`claude -r "cockpit ai-development-hub 23代目"` で一覧を通さずに直接入れることである。#355（復帰）で resume する id を探す工程が、名前を打つだけになる。
- ほかの案（R2: `cockpit <リポジトリ名>` だけ）は、上の2つがどちらもできないので採らない。

### DJ-2 記録の鍵と置き場（GATE 3 の問い2）

席を取る verb が、session_id ごとの「名前の要求」を `~/.claude/state/session-title/<session_id を英数字と _ に直したもの>.json` に書き、hook はそれを読むだけにする（K2）。

- 形は `{"format":1,"request_id":"<lease_id>:<generation>","name":"<名前>","requested_at":"<ISO 時刻>"}` である。
- hook は engine の lease の形を知らない。配布物の hook と engine のあいだの約束は、この小さな記録の形だけになる。engine を使わないリポジトリでは、この記録が無いので今の動きのままである。
- ほかの案: K1（hook が lease を直接読む）は、配布物の hook が lease の形と generation の決まりを知ることになり、代も取れないので採らない。K3（lease に名前のフィールドを足す）は、lease の形を変え、hook も lease を読む点が K1 と同じなので採らない。

### DJ-3 要求の ID と、いつ名前を付けるか

- `request_id` は `<lease_id>:<generation>` にする。同じ take の再試行では同じ ID になり、新しく席を取れば新しい ID になる。lease が無いとき（lease を作れなかった）は要求を書かず、take と root の報告に「していないこと」として出す（席を取ることは止めない）。
- hook は、要求の `request_id` が、session_id ごとの state（いまの `~/.claude/state/session-branch/<sid>.json`）に記録した `seat_request_id` と違うときだけ `sessionTitle` を出し、`seat_request_id` を書く。席を取ったという出来事で一度だけ改名し、そのあとの手動 `/rename` は次に席を取るまで尊重する。Path2 がブランチの変化で一度だけ改名するのと同じ考え方である（設計SO の指摘で、名前でなく ID で見ることにした。同じ名前で席を取り直したときも改名できる）。
- `request_id` が同じで、今の名前が要求の名前と同じなら何もしない。同じで名前が違うなら、手で付けた名前として尊重する。
- 名前は take や root を打ったターンの中では変わらず、次のプロンプト（`oe-send` で届く1行を含む）で付く。統括は席を取ったあとすぐに報告や指示のやり取りをするので、これで足りるとする。

### DJ-4 hook の中の順序（GATE 3 の問い2 に含む）

- 統括の道を Path1 より前に置く。要求があるセッションでは、統括の道で処理を終え、Path1 と Path2 に落とさない。Path1 はペインを鍵にするので、前の住人の記録が残っていると `#<issue>` の名前に戻してしまうためである（設計SO の指摘）。
- plan mode と `/` で始まるプロンプトでは、統括の道でも改名せず、`seat_request_id` も書かない（要求を消費しない）。次の普通のプロンプトで付く。
- 要求が無い・JSON として読めない・`request_id` か `name` が空のときは、統括の道に入らず、今の Path1 と Path2 のとおりに動く。
- 名前は、今の Path2 と同じく制御文字を除き、80 バイトで切り、UTF-8 として正しい形にしてから出す。

### DJ-5 書く側の部品

- `projects/orchestration-engine/lib/session-title.sh` に、要求を書く関数を1つ置く（`oe_session_title_request <session_id> <request_id> <name>`）。tmp に書いて mv で置き換える。take と root の両方から呼ぶ。
- take は、lease を進めて自分の session_id を登録したあと（`bin/oe-handoff` の (3.5) の後ろ）に呼ぶ。名前の代は take が決めた `GENERATION` を使う。
- root は、`lease_root_best_effort` で自分の lease が決まったあとに呼ぶ。代は分からないので `cockpit <リポジトリ名>` にする。ただし `--label` が `cockpit` のときだけ呼ぶ（統括でない root には名前を付けない）。
- どちらも、`CLAUDE_CODE_SESSION_ID` が無いときは書かず、報告に出す。

### DJ-6 GC

- 要求の記録は、hook が no-op のときにも触れて更新時刻を進める。30 日触れられなかった要求は、hook が改名するときに消す（今の `session-branch` の GC と同じ窓）。
- `seat_request_id` は今の `session-branch` の state に入るので、同じ 30 日の GC に乗る。要求と state の片方だけが消えると、要求だけが残った場合に一度改名し直す。これは席の名前を取り戻す向きなので害は小さいとし、対で消す仕組みは足さない。

### DJ-7 受け入れ基準の書き換え（GATE 3 の問い3）

確定版の受け入れ基準「`claude -r cockpit` で各リポジトリの統括が並ぶ」は、公式の挙動では満たせない。`claude -r cockpit` が開く一覧は今のリポジトリのセッションだけで、全リポジトリの統括を並べるには一覧で `Ctrl+A` を押す必要がある。名前の決め方では解けない。

次のように書き換えることを提案する。

- `claude -r cockpit` で、今のリポジトリの統括が代ごとに並ぶ。
- その一覧で `Ctrl+A` を押すと、ほかのリポジトリの統括も並ぶ。
- `claude -r "cockpit <リポジトリ名> <N>代目"` で、一覧を通さずにその統括に入れる。

## 打ち消す側

| # | 壊しうるもの | 守り方 | 確かめ方 |
|---|---|---|---|
| R1 | worktree の子の `#<issue> <slug>`（Path1） | 要求の無いセッションは今の Path1 のまま | hook のテスト T2 |
| R2 | ブランチ名・リポジトリ名の命名（Path2） | 要求の無いセッションは今の Path2 のまま | hook のテスト T3・T4 |
| R3 | 手で付けた名前の尊重（Path2） | 要求の無いセッションは今のまま。要求のあるセッションも、同じ要求の ID のあいだは手動の名前を尊重する | T5・T8 |
| R4 | UserPromptSubmit の stdout がモデルに入ること | 出すのは jq で組んだ `sessionTitle` の JSON だけ | 全テストで stdout が空か JSON 1つだけかを見る |
| R5 | engine を使わない環境 | 要求の記録が無ければ今の動き | T1 |
| R6 | take と root の既存の動き | 要求を書くのは席を取ったあとの追加の1手で、失敗しても席は動かす | 既存の `test_handoff_take.sh`・`test_oe_register.sh` が通る。新しい場合を足す |

## 確かめ方

hook のテストを `projects/orchestration-engine/tests/test_session_name.sh` に新しく置く（canonical の hook を engine の tests で確かめる前例: `test_hook_judgment.sh`・`test_hook_firing.sh`）。`HOME` を一時ディレクトリにし、`TMUX_PANE` と payload を変えて hook を走らせ、stdout を見る。

- T1: 要求が無い master のセッションは、今と同じくリポジトリ名になる。
- T2: ペインの記録（pane-issue）があるセッションは、今と同じく `#<issue> <slug>` になり、毎回取り戻す。
- T3: issue のブランチは `#<issue> <slug>`、それ以外のブランチはブランチ名になる。
- T4: ブランチが変わったら改名する。
- T5: 同じブランチで手で付けた名前は残る。
- T6: 要求があるセッションは、要求の名前になる（ペインの記録が残っていても Path1 に戻らない）。
- T7: 要求の名前を出したあと、同じ要求なら何もしない。
- T8: 同じ要求の ID のあいだは、手で付けた名前を残す。新しい要求の ID が来たら改名する。
- T9: plan mode と `/` で始まるプロンプトでは改名せず、次の普通のプロンプトで改名する。
- T10: 壊れた要求（JSON でない・`name` が空）は無視して、今の動きになる。
- T11: 名前の制御文字は除かれる。

T1〜T5 は今の hook でも通る形で先に書き、変更の前後で同じ結果になることを確かめる。T6〜T11 は変更の前は落ちることを確かめる。

実物の確かめ（I1-5）: hub の統括の席を変えずに、検証用の tmux のペインで `claude` を起こし、その中で `oe-register root --label cockpit` を打ち、次のプロンプトで名前が付くことと、別のペインで `claude -r cockpit` の一覧にその名前が出ることを見る。終わったら検証用の登記と lease を閉じる。今の統括の lease と registry には触らない。一覧の写しは episode に置き、業務のリポジトリの名前は伏せる。

## 受入

- A1: 統括が席を取ったあと、次のプロンプトで `cockpit <リポジトリ名> <N>代目`（代が分からなければ `cockpit <リポジトリ名>`）がセッション名に付く（T6 と I1-5）。
- A2: 受け入れ基準は GATE 3 の問い3 の答えで決める。推奨のとおりなら、`claude -r cockpit` で今のリポジトリの統括が並び、`Ctrl+A` でほかのリポジトリの統括も並ぶ（I1-5）。
- A3: worktree の子の `#<issue> <slug>`・ブランチ名・手で付けた名前が変わらない（T1〜T5 が変更の前後で同じ）。
- A4: 既存の engine のテストが通り、`shellcheck` が新しい警告を出さない。

## ステップ

### P0: worktree・認識合わせ（完了）

### P1: 名前の決まりと記録の鍵の案・設計SO（完了・結果は episode の P1）

### P2: plan を書き、draft PR に載せ、GATE 3 の問いを送って止まる

### GATE 3: owner の plan 承認

### I1-1: hook のテストの T1〜T5 を書き、今の hook で通ることを確かめる（1コミット）

### GATE I1-1: T1〜T5 が今の hook で通る

### I1-2: `lib/session-title.sh` と hook の統括の道（DJ-2〜DJ-4・DJ-6）と T6〜T11（1コミット）

### GATE I1-2: T6〜T11 が変更の前の hook で落ち、変更のあとで T1〜T11 がすべて通る。shellcheck

### I1-3: take と root から要求を書く（DJ-5）と、その場合のテストを `test_handoff_take.sh`・`test_oe_register.sh` に足す（1コミット）

### GATE I1-3: engine のテストがすべて通る

### I1-4: `canonical/hooks/README.md` の「session-name.sh + wt-pane-issue.sh」節に統括の道と記録の形を書く（1コミット）

### I1-5: 実物の確かめ（確かめ方の最後の段落）。結果を episode に写す

### GATE I1: A1〜A4 がすべて満たされている

### I2: 実装SO（弱・Codex 1レーン）・PR を ready にする・Copilot 1ラウンド

### GATE I2: 実装SO の採否が episode にあり、Copilot の未返信が0件である

### I3: episode を閉じ、報告して止まる（マージ・worktree の掃除・issue の close・sync はしない）

## GATE 3 の問い

1. 名前の決まりを `cockpit <リポジトリ名> <N>代目`（代が分からなければ `cockpit <リポジトリ名>`）にしてよいか（DJ-1）。
2. 記録を、席を取る verb が書く session_id ごとの名前の要求にし、hook は要求の ID が変わったときに一度だけ改名する形にしてよいか（DJ-2〜DJ-4）。
3. 受け入れ基準を DJ-7 のとおりに書き換えてよいか。
4. この plan で実装に進むか。

## ゲート3 のあとの変更

（まだ無い）

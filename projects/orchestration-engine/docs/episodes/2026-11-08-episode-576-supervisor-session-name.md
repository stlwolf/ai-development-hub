---
id: "01M6XCDSHJJWHCDRBTKDSM4FC3"
title: "#576 統括のセッションに resume の一覧で見分けられる名前を付ける"
date: 2026-11-08
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/576"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-06-episode-577-record-identity-key.md"
    reason: "統括の lease（session_id を持つ記録）を入れた直前の作業"
tags: [orchestration, hooks, session-name, lease]
---

# #576 統括のセッションに resume の一覧で見分けられる名前を付ける

## なぜこの作業が始まったか

2026-11-06 に owner が「resume の一覧で統括が上にいない時がある」「セッション名がほぼリポジトリ名だけ」と指摘した。統括が hub の直近15本の会話の題を見たところ、統括の会話6本はすべて `ai-development-hub` だった。セッション名の hook（`canonical/hooks/scripts/session-name.sh`）は master ではリポジトリ名に落ち、統括は master で動くためである。

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## この単位の入力

- brief: 統括（cockpit 23代目）が 2026-11-08 に発行した #576 の brief（作業層・消える）。終端は P2（plan を書き、ゲート3 の問いを送って止まる）。マージ・worktree の掃除・issue の close・sync はしない。
- 認識合わせ: 子が `issue-intake` を通し、統括へ渡して確定版を待つ（P0）。
- SO: 設計 weak（Codex 1レーン）・実装 weak（Codex 1レーン）+ Copilot 1ラウンド。
- 注入された negative knowledge: なし（brief の列挙で該当0件）。

## 作業の記録

### P0: 認識合わせ（2026-11-08）

- worktree を `feature/#576_supervisor_session_name` で master `df16c60` から作った。
- 着手時に読んだ事実（いまのリポジトリに当て直したもの）:
  - 統括の lease は1本で、`current_generation` は 1、`session_ids` は1件である。lease は #577 で作ったばかりなので、generation は board の「統括23代目」の代と一致しない。代を名前に入れるなら、lease の generation は材料にならない。
  - `session-name.sh` の hook のテストは、リポジトリに1本も無い。
  - `claude --help` の `-r, --resume [value]` は「session ID か名前で resume、または語で絞った picker を開く」と書いている。語が名前と完全に一致したときに picker を出さずに入るかどうかは、実物で確かめる必要がある。
- 別のモデル（Codex・gpt-6.1-sol・設定から解決）に漏れを問い合わせ、「漏れは無い」と返った。
- 3つの出力を `.oe/question-576-1.json` に書き、統括へ送って確定版を待つ。
- 統括から確定版（https://github.com/stlwolf/ai-development-hub/issues/576#issuecomment-6721086870 ・owner は「この内容で確定する」・深掘りなし）が届いた。issue-intake の 1-2 の照合で、最後の確定版の URL と一致した。

### P1: 名前の決まりと記録の鍵の案・設計SO（2026-11-08）

#### 出した案

- 名前の決まり: R1 `cockpit <リポジトリ名> <N>代目`（代が分からなければ `cockpit <リポジトリ名>`）と、R2 `cockpit <リポジトリ名>`（代を入れない）。
- 記録の鍵: K1 は hook が lease を直接読む案、K2 は席を取る verb が session_id ごとの「名前の要求」を書き hook はそれを読むだけにする案、K3 は lease に名前のフィールドを足す案である。

#### 公式のドキュメントで分かったこと（受け入れ基準に効く）

`claude -r` の挙動を https://code.claude.com/docs/en/sessions.md で確かめた。

- 名前での resume は、今のリポジトリとその worktree の中だけで探す。名前が1件に完全一致すれば一覧を出さずに入り、そうでなければ語を入れた一覧（picker）を開く。
- 一覧の既定の範囲は今の worktree のセッションである。`Ctrl+W` で同じリポジトリの worktree 全部、`Ctrl+A` でこの機械の全プロジェクトに広がる。

したがって、`claude -r cockpit` を打っただけでは**今のリポジトリの統括しか並ばない**。確定版の受け入れ基準「`claude -r cockpit` で各リポジトリの統括が並ぶ」は、`Ctrl+A` を押す手順を足さないと満たせない。これは名前の決め方では解けないので、受け入れ基準の書き換えとしてゲート3 で owner に聞く。

昇格の印: `claude -r <名前>` は今のリポジトリだけを探し、全リポジトリの一覧には picker の `Ctrl+A` が要る（統括の復帰の手順 #355 にも効く事実）

もう1つ分かったのは、R1 にすると名前がリポジトリの中で1つに決まるので、`claude -r "cockpit ai-development-hub 23代目"` で一覧を通さずに直接入れることである。R2 だと退任した統括と同じ名前になり、必ず一覧が開く。

#### 設計SO（弱・Codex gpt-6.1-sol・設定から解決・1レーン）

推奨は R1+K2 の修正版で、こちらの推奨と一致した。指摘は23件で、採否は次のとおりである。

- 採る: 要求の同一性を名前でなく要求の ID で見る（同じ名前で席を取り直したときに、手動の改名のあとでも改名できるようにするため）。ID は lease の `<lease_id>:<generation>` にし、同じ take の再試行では同じ ID、新しい席では新しい ID になるようにする。
- 採る: 要求があるセッションでは、統括の道で処理を終え、Path1 と Path2 に落とさない。Path1 はペインを鍵にするので、前の住人の記録が残っていると、次のプロンプトで `#<issue>` の名前に戻されるためである。
- 採る: plan mode と `/` で始まるプロンプトの除外は、要求を「適用済み」にする前に行う。
- 採る: 要求は、席を取る処理（lease を進め、session_id を登録する）が成功したあとに書き、書けなかったら take の報告に「していないこと」として出す。
- 採る: 要求の記録と適用済みの記録の GC を対で考える。どちらも 30 日触れられなければ消し、hook は no-op のときに両方に触れる。
- 採る: 要求が無い・壊れている・名前が空のときは、今の動きのまま何もしない。
- 採らない: SessionStart で要求を適用する案。名前は会話の記録に残るので、resume のときに付け直す必要が無い。
- 採らない: 同じ名前のリポジトリを `owner/repo` で見分ける案。一覧の既定の範囲がリポジトリの中なので、ぶつかるのは `Ctrl+A` で広げたときだけで、そのときは一覧にパスが出る。必要になったら足す。
- 範囲の外として残す: `--fork-session` で session_id が変わった統括の名前の引き継ぎ。新しい id には要求が無いので、席を取り直したときに付く。#355（復帰）で席を取り直す手順に乗る。
- 範囲の外として残す: 2つのプロセスが同じ session_id を持つ場合。lease 側で同じ session_id を2つの lease に登録できない（`oe_lease_register_session` の rc=8）ので、新しい対策は足さない。
- 残りの指摘（原子的な置き換え・壊れた JSON・id の検証など）は、今の hook がすでに使っている書き方（tmp に書いて mv・jq で読み失敗したら何もしない）で満たすので、plan の実装の決まりに書く。

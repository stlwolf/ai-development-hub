---
id: "01M6XKTEKAN7GVD987CYV9YS2F"
title: "統括のセッション名を cockpit <リポジトリ名> gen<代> にし、席を取る verb が session_id ごとに書く名前の要求から hook が一度だけ付ける"
date: 2026-11-08
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/576"
    reason: "本 decision が記録する owner の判定（ゲート3 の Q98〜Q101・2026-11-08）の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-08-plan-576-supervisor-session-name.md"
    reason: "判定の材料。設計判断 DJ-1〜DJ-7・ゲート3 のあとの補正 H1"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-08-episode-576-supervisor-session-name.md"
    reason: "作業の記録。設計SO・実装SO・Copilot の採否と実物の確かめ"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "統括の lease（session_id と generation を持つ記録）の決定。要求の ID の材料"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/355"
    reason: "統括の復帰。resume する id を探す工程を、名前で `claude -r` を打つだけにできる"
tags: [orchestration, hooks, session-name, supervisor, decision]
---

# 統括のセッション名を cockpit <リポジトリ名> gen<代> にし、席を取る verb が session_id ごとに書く名前の要求から hook が一度だけ付ける

## 背景

統括は既定のブランチで動くので、セッション名の hook（`canonical/hooks/scripts/session-name.sh`）がリポジトリ名を付け、`claude --resume` の一覧でほかの master のセッションと見分けられなかった（2026-11-06・hub の統括の会話6本がすべて `ai-development-hub`）。

## 決定

### 決定1 名前の形（Q98）

統括の名前は `cockpit <リポジトリ名> gen<代>` にする。代が分からないとき（`oe-register root` で新しく立てた・take で代を読めなかった）は `cockpit <リポジトリ名>` にする。

- 代を入れるのは、退任した統括の名前を hook が変えられない（退任した会話はもうプロンプトを受けない）ので、代が無いと今の統括と同じ名前が一覧に残るからである。名前がリポジトリの中で1つに決まるので、`claude -r "<名前>"` で一覧を通さずに入れる。
- 日本語の「代目」は使わない（owner の補足「代目の日本語はいらない。入れても gen？」）。`gen` と数字は続けて書き、1語として検索できるようにする。
- 棄却した案: `cockpit <リポジトリ名>` だけ（退任した統括と見分けられず、名前で直接入れない）。

### 決定2 記録の鍵と、hook と engine の境界（Q99）

名前の材料は、席を取る verb（`oe-handoff take`・`oe-register root --label cockpit`）が `~/.claude/state/session-title/<session_id>.json` に書く「名前の要求」にする。hook はこの記録の形だけを知り、engine の lease は読まない。

- 全リポジトリに配る hook と engine のあいだの約束を、小さな記録の形1つに絞るためである。engine を使わないリポジトリでは記録が無いので、hook は今の動きのままである。engine を独立したパッケージにしていく方向（#537）とも合う。
- 棄却した案: hook が lease を直接読む（配布物の hook が lease の形と generation の決まりを知ることになり、lease の generation は board の代と一致しないので代も取れない）。lease に名前のフィールドを足す（lease の形が変わり、hook が lease を読む点は前の案と同じ）。

### 決定3 一度だけ改名する決まり

要求の ID（`<lease_id>:<generation>`）が前に適用したものと違うときだけ一度改名し、同じ ID のあいだは手で付けた名前を残す。要求のあるセッションは、ペインを鍵にした worktree の名前（Path1）にも、ブランチの名前（Path2）にも落とさない。

- ブランチが変わったときに一度だけ改名する今の決まりと同じ考え方で、手で付けた名前を毎回奪わない。名前でなく ID で見るのは、同じ名前で席を取り直したときも改名できるようにするためである（設計SO の指摘）。
- Path1 に落とさないのは、ペインの記録が前の住人のものでありうるからである。

### 決定4 受け入れ基準の書き換え（Q100）

`claude -r <語>` が開く一覧は今のリポジトリのセッションだけである（公式ドキュメント https://code.claude.com/docs/en/sessions.md ）。そのため受け入れ基準を「`claude -r cockpit` で今のリポジトリの統括が並び、一覧に移ってから `Ctrl+A` を押すとほかのリポジトリの統括も並び、`claude -r "<名前>"` で直接入れる」にした。全リポジトリの統括を一度に並べる別の道具は作らない。

## 当時の前提（偽になったら見直す）

- `claude -r` の名前の resume と一覧の既定の範囲が、今のリポジトリとその worktree であること（Claude Code v2.1.319 で実測）。範囲が広がれば決定4 は要らなくなる。
- UserPromptSubmit の hook が `sessionTitle` で名前を変えられ、名前が会話の記録に残ること。
- take が代を知っている（`--generation` か board の「現統括」の行）こと。代の出どころが lease に移れば、名前の代の取り方を見直す。

---
id: "01KX7JPRJF7BW1QHYC7J6JSA72"
title: "#239 段階1 PR-B episode — oe-vitals consumer（設計SO + 実装SO が両方 refuted → reconcile）"
date: 2026-07-11
type: episode
status: stable
related:
  - type: plan
    ref: ../plans/2026-07-11-plan-239-pr-b-vitals-consumer.md
    reason: "本 episode の設計判断（DJ-1..6）と SO ゲート結果の正本"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "watchdog（producer=PR-A・consumer=PR-B）。多段のため keep-open"
  - type: pr
    ref: "https://github.com/stlwolf/ai-development-hub/pull/246"
    reason: "本 episode が記録する PR-B"
tags: [orchestration, watchdog, heartbeat, consumer, second-opinion, "issue-239", reconstructed]
---

# #239 段階1 PR-B episode — oe-vitals consumer

> **reconstructed**: リアルタイム追記でなく PR 作成後にまとめて執筆。追記ログと同じ証拠価値は持たない。

## Context / なぜ

cockpit 統括は使い捨て・state が正本（#238）。統括が context 肥大や crash で倒れたのを **自己申告に頼らず機械検知**したい。PR-A（statusLine 拍動 producer）が session 毎に sidecar へ `{ts, context_pct, pane}` を書くので、PR-B はそれを out-of-session cron から読んで統括の vital を判定し owner に ping する consumer を足す。親 `%158` からの委譲。

## 次の消費者

- **段階2 の watchdog 設計者**（observed projection / mode2 お見合い / seat 導入を判断する人）。本 episode の「board 突合の key-mismatch」節が Alt-A（board が session_id を declare）を検討する入口。
- **owner（cron 配備時）**: 運用前提（`OE_BOARD_FILE` 必須・pane 伝播依存）を deployment 時に読む。

## 決定と根拠（コード/diff から復元できない「なぜ」）

- **verb 名 `oe-vitals`**: 候補 `oe-heartbeat` を棄却した決め手は「読みやすさ」ではなく **namespace の物理衝突** — verb 固有 seen cache dir が producer の sidecar dir `~/.claude/state/oe-heartbeat/` と同一パスになる。命名が state レイアウトの衝突を生む具体例で、sister verb の分離は命名で担保した。
- **death 判定を「beat staleness」→「tmux 確定 gone」へ転回**（設計SO 起点）: kickoff は「beat-staleness＝プロセス死検知」と framing した（生存プロセスは refreshInterval の fixed timer で beat を撃ち続けるから）。だがこの premise は **PR-A 自身が「実機未検証」と記していた**。staleness に death を載せると、PR-B の death 信頼性が上流の未検証 premise を linchpin として継承する。設計SO がここを突いた（+ tmux 不在の `?` を `¬alive` と見なし cron で偽 crash ping する経路）。→ death を tmux が確定できる **hard signal（gone）**に移し、premise 依存と偽陽性を同時に断った。代償（tmux 不在時 death 不可）は偽陽性より安全側と判断。
- **succession を logic に使わない**: crash/handoff の判別は board 突合そのもの（handoff 後は `現統括` が後任へ進み前任は scope 外）に委ね、`succession` 値は human 注記に留めた。曖昧な declared 値で分岐を増やすより、scope 化に判別を吸収させる方が壊れにくい。

## わかったこと（W）

- **truth-table completeness ≠ implementation completeness**。4分岐の真理値表は「見た目」完備でも、`?`（tmux 不明）や境界の degrade セルが未規定/未テストのまま残り、そこで observer の中核契約（偽陽性ゼロ / exit 0）が破れた。設計SO・実装SO が拾ったのは全て **未テストの degrade / error セル**（`?×stale`・`現統括:` あり pane 無し・HOME 未設定）。
- read-only observer でも `set -euo pipefail` は罠を持つ: `grep` の no-match rc1 が pipeline→コマンド置換→`set -e` と伝播し「exit 常に 0」契約を静かに破る。producer が `${HOME:-}` で守っていた箇所を consumer で `${HOME}` に戻していた（既存パターンの踏襲漏れ）。

## 原則（Pattern / Anti-pattern）

- **Anti**: observer の安全性主張（「偽陽性を出さない」）を、上流の**未検証 premise**（refreshInterval-idle）に載せる。→ **Pattern**: 死活は「不明（`?`）」を死に倒さず、確定できる hard signal でのみ発火させる（不明は no-op・偽陽性回避を最優先）。
- **Anti**: declared 層（board）と observed 層（sidecar）を**異なる主キー**（pane vs session_id）で突合し、片方が best-effort（空になりうる）なのに単一 bridge にする → 静かに inert 化。→ **Pattern**: bridge が best-effort なら「解決不能」を明示 signal（warn）にして「異常なし」と区別する。恒久解は declared 側を安定キー（session_id）に寄せる（Alt-A）。

## 事実・失敗（選択的省略なし）

- **設計SO**（`oe-refute` exploration/3・audit `20260710165558WHKWV6XCJXXA`）: **refuted 3/3**。material 反証 M1（`?×stale`偽death・実バグ）/ M6（board 見出しの古い pane 誤 match・実バグ）を code fix、M3（gone×fresh 遅延）を解消、M2/M4/M5/M7/M8/M9/M10 を disclose。
- **実装SO**（`oe-review`/3・audit `20260711025400M3MK3ZMARMG3`）: **refuted 2/3**（cursor survived）。I1（pipefail 落ちで exit 0 契約違反）/ I2（`${HOME}` unbound）を code fix。
- 各 material 反証に回帰テストを追加。**77/77 green（bash 5.2.37 / 3.2.57・shellcheck clean）**。Copilot は 0 指摘（clean overview）。
- 詳細な反証×対応表は plan doc に durable 化（本 episode では非自明な接続のみ）。

## 蒸留シグナル

- **昇格候補あり**: **Alt-A（board が `session_id` を declare → consumer は `<sid>.json` を直 read）** は M2/M7 の構造依存を根から解く。board schema（PR-C）変更を伴うため PR-B scope 外だが、段階2 or watchdog 改善の **Issue / Decision 候補**。→ routing 下記。
- skill/rule 昇格: 今回の Anti/Pattern（不明を死に倒さない・best-effort bridge の明示 signal）は negative knowledge（#62）注入候補になりうるが、単発ゆえ今は episode 記録に留める。

## 残課題（routing）

- **Alt-A（board に session_id）**: → 段階2 watchdog 改善で Issue 化候補（owner 判断）。本 PR では disclose のみ。
- **context の再 ping / escalation interval**（現状 session×kind で 1回）: → 運用観測後に判断（decision-pacing）。追わない宣言はせず plan doc の follow-up に保持。
- **inert watchdog の config-health owner ping**（現状 stdout のみ）: → kickoff の no-op 方針を尊重し defer。owner が inert 可視化を望めば additive。
- **cron / launchd 実設置**: → deployment 手順（本 PR scope 外・README に例示済）。
- **マージ・worktree 掃除**: → 親/owner の HG（実装子は追わない）。

## status

**stable**・達成度: **達成**（PR-B の要件＝read-only 姉妹 verb + 真理値表 + board 突合 + 両 SO ゲート通過 を満たし PR #246 landing）。多段の一段ゆえ #239 は keep-open。

Step4 辞退: 別途の closure-quality SO は実施せず / 既存チェックで覆った観点: 省略チェック（失敗＝両 SO refutal を本文の headline に明示・選択的省略なし）・routing（全 follow-up に行き先付与）・evidence anchor（SO audit_id / verdict を本文と plan doc へ転記・揮発 tmp/ 依存を解消）・back-propagation（SO 反証は code + plan へ反映済）/ 未実施観点と判断: なし（4観点すべて低リスクで本文が自己完結）。

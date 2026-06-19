---
id: "01KVFJH8A1FZHJNA2M75WZK6BT"
title: "#188 オーケストレーション2基盤 identity 統一 — 設計判断 closure"
date: 2026-06-19
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/188"
    reason: "本 episode の対象タスク"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "本 episode が closure した設計判断の ADR（成果物）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-06-19-discussion-188-identity-unification.md"
    reason: "探索トレイル（調査・実機観測・設計SO）"
tags: [orchestration, identity, cockpit, episode, decision, closure]
---

# #188 オーケストレーション2基盤 identity 統一 — 設計判断 closure

## Context（なぜ）

`#177`（cockpit 観測UI）の設計SOで俯瞰の中核「生存ペイン × session 状態を `pane_id` でジョイン」案が構造破綻し、原因の identity 分裂を root-cause として `#188` を切り出した。本作業は #188 の設計判断（2基盤の identity をそもそも統一すべきか／方式）を disciplined フローで確定するもの。子セッション（親=cockpit `%32`）として実施。

## 経緯（時系列・方針転回を含む）

0. **（出自・方針転回）** #177 俯瞰の pane_id ジョインが設計SO で破綻 → identity 分裂を root-cause として #188 を切り出し（#177 当初 plan は撤回・削除）。
1. 一次情報直読（Explore 委譲）+ 実機 topology 観測 → 「engine=wez 整数 pane / delegate=tmux %N、別多重化レイヤで相互不可視」を確定。
2. 当初は Issue が挙げた A/B/C/D/F を「D（統一せず）vs F（session 層統一）」の二択に絞り、親 `%32` へ中間報告。
3. オーナーが gate を「設計判断は委任・PR 時 intent-check」に緩和 → autonomous フローへ。
4. 設計SO（`so-compare --with codex,cursor`・選択肢拡張つき）投入 → **方針転回**: codex/cursor が独立に「#177 は単一俯瞰を要求していない／F は category error + schema breaking で筋が悪い／pane でなく観測モデルの問題」と収束。D/F の外に query-side fusion・#177 スコープ分割・event bus が出た。
5. 収束を踏まえ DJ-188-1..5 を確定（ADR 化）。

## 事実・失敗（方針転回の記録）

監査追跡性のため転回を独立に明示（いずれも省略せず上の経緯に対応）:
- **転回1（出自）**: #177 の pane_id ジョイン設計が破綻 → #188 へ root-cause 切り出し（経緯 step 0）。
- **転回2（絞り込みの是正）**: 自分は当初 A/B/C/D/F を D vs F に絞ったが、設計SO が「#177 は単一俯瞰を要求していない／F は category error + schema breaking」と是正し、query-side fusion 等を再提示（経緯 step 4）。
- **誤見積もりの是正**: 案F を「registry に session_id 足すだけ」と過小評価していた点を SO が指摘（`pane_id: integer` 固定 schema の breaking change）。

## 決定と根拠（棄却理由つき）

- **確定**: identity を pane 層で統一しない（DJ-188-1）／ session-state を delegate に拡張する案 F を棄却（DJ-188-2）／ identity は基盤ごとに保持し相関は read 時（DJ-188-3）／ 永続横断観測が要れば event bus（DJ-188-4・deferred）／ read-only は観測者拘束（DJ-188-5）。
- **棄却の「なぜ」**（diff から復元不可）:
  - B/C = 物理的に不成立（engine 子は tmux 非所属で `%N` 無し／delegate 子は wez に個別表示されない）。
  - A = F に縮退（各 session は wez か tmux の片方の identity しか持たない）。
  - F = category error（対話子に完了 lifecycle が無く engine の `state` enum に押し込むと嘘）+ `pane_id: integer` 固定 schema の breaking change + ROI が Stage-B 繰延 + #114 で陳腐化。
- 詳細は ADR `../decisions/2026-06-19-decision-188-identity-unification.md`。

## わかったこと（W）

- 実機 topology: tmux は**単一 WezTerm ペインの内側**で動く（`TMUX_PANE=%33` かつ `WEZTERM_PANE=0`、`tmux list-panes -a`=5 / `wez pane list`=1）。engine の wez-split 子は tmux 外の WezTerm pane（tmux 不可視）、delegate の tmux 子は wez では親ペインに潰れる（wez 不可視）。
- `schemas/session-state.schema.json` と `audit-log.schema.json` が `pane_id: integer`（WezTerm）で固定 → F は両 schema の破壊変更を伴う（当初「registry に session_id 足すだけ」と過小評価していた点を SO が是正）。

## 原則（pattern / anti-pattern）

- **Anti-pattern**: 別々の多重化レイヤ（wez / tmux）の pane-ID を、pane 層で対応づけようとする。→ 対応する物理エンティティが存在せず不成立。
  **Pattern**: identity は多重化レイヤの**上位**（session_id / read 時投影）で扱うか、honest に基盤ごと分離する。
- **Anti-pattern**: 異質な lifecycle（自律 state vs 対話 liveness）を単一 state enum に押し込む（見た目の統一・意味論の非対称 = category error）。
  **Pattern**: `kind`/`mux` で型を分け、read 時に投影。完了イベントの無い対話子に `timeline:none` を正直に出す。

## 行動変更

- `session-state.schema.json` の `pane_id` description に identity 境界注記を追加（トリガ＝将来 F 方向の誤改修、機構＝schema description、着地先＝`session-state.schema.json`）。DJ-188-2 のコード面ガード。

## 蒸留シグナル

- **Decision 昇格＝実施済**（ADR `2026-06-19-decision-188-identity-unification.md` を作成）。topology 不変条件 + 「session-state を拡張せず event bus」原則は #177/#114/Stage-B に再利用される横断判断のため。

## closure gate

- **次の消費者**: #177（俯瞰の再設計。identity モデルが「基盤ごと・read 時相関・永続マップ無し」と確定したことが前提）。将来 Stage-B（event bus 方針 DJ-188-4）。
- **follow-up routing**:
  - #177 俯瞰の再設計（query-side fusion 単一ビュー or honest 2 ビュー）→ **#177**（ADR §帰結 + discussion §9 に handoff 記載・本 #188 はロックしない）。
  - query-side fusion の `oe-status --dry-run` 試作（両ソース同時読込で列定義が破綻しないかの検証）→ **#177**（俯瞰再設計の検証ステップ。discussion §7 由来）。
  - 永続横断観測（event bus）→ **deferred**（DJ-188-4・Stage-B 着手時）。
  - #114（クリーン出力チャネル）との相互参照 → **#114 設計時**に参照（ADR に記載）。
- **status**: stable / **達成**（設計判断確定 + ADR + schema ガード + #177 unblock）。
- **evidence anchor**: 設計SO 出力 `tmp/so-188-design/`（揮発・gitignore）→ 要点は discussion §7 + ADR §検討した選択肢 に転記済み。
- **SO 証跡**: 設計SO = discussion §7。Step 4 closure SO = §Step4 に記載。

## Step4（heavy tier 外部チェック）

closure 品質の focused check を so-compare（`--with codex,cursor`）で実施。出力 `tmp/so-188-closure/`（揮発・gitignore）。設計の是非でなく closure 品質（失敗の選択的省略 / routing 網羅 / 揮発パス / back-propagation）に限定。

**結果と対応**:
- 方針転回の選択的省略: **なし**（両者一致）。#177→#188 ピボット・D/F→再フレーム・案F過小評価是正はいずれも記録済みと確認。
- **back-propagation 漏れ（主要・両者指摘）**: #177 doc（`discussion-cockpit-observation-ui.md`）に #188 確定結果が未反映 → **#177 doc に §7 を追記し handoff を back-propagate、`related` に decision-188 を追加**（本コミットで対応済）。
- **follow-up routing 欠落（cursor 指摘）**: discussion §7 の `oe-status --dry-run` 試作が未 routing → **下記 follow-up に #177 として追加**（本コミットで対応済）。
- **discussion-188 status draft vs episode stable（軽微）**: discussion-188 を `stable` に確定、`related` に decision/episode を追加（本コミットで対応済）。
- 軽微（pivot が経緯 timeline に薄い / 事実・失敗 独立節なし）: 経緯 step 0 に pivot を明記し下記「事実・失敗」節で対応済。

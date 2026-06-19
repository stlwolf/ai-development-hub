---
id: "01KVFJ60BGS887DWGBSP7RC942"
title: "#188 オーケストレーション2基盤の identity は pane 層で統一しない — read 時相関 / 永続マップ不採用"
date: 2026-06-19
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/188"
    reason: "本 ADR の主スコープ（2基盤の identity 統一の設計判断）"
  - type: source_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/177"
    reason: "本 ADR の消費者（cockpit 観測UI）。出自であり handoff 先"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-06-19-discussion-188-identity-unification.md"
    reason: "本 ADR の探索トレイル（調査・実機観測・設計SO・DJ の経緯）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md"
    reason: "#177 設計探索。§6 で pane_id ジョイン破綻を捕捉し #188 へピボット"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-05-30-discussion-clean-output-channel-for-orchestration.md"
    reason: "#114 クリーン出力チャネル。F 投資の陳腐化リスク評価の根拠"
  - type: source_material
    ref: "projects/orchestration-engine/schemas/session-state.schema.json"
    reason: "pane_id を WezTerm integer に固定（F の breaking change 根拠）"
  - type: source_material
    ref: "projects/orchestration-engine/lib/spawn.sh"
    reason: "engine spawn = wez pane split（wez 整数 identity の一次根拠）"
  - type: source_material
    ref: "projects/orchestration-engine/lib/delegate-registry.sh"
    reason: "delegate registry = tmux %N（tmux identity の一次根拠）"
tags: [orchestration, identity, cockpit, observation, wez, tmux, decision, read-only]
---

# #188 オーケストレーション2基盤の identity は pane 層で統一しない — read 時相関 / 永続マップ不採用

## コンテキスト

`#177`（cockpit 観測UI）の設計SOで、俯瞰の中核「生存ペイン × session 状態を `pane_id` でジョイン」案が構造破綻した。原因は2つのオーケストレーション基盤が別々の identity 空間を持つこと。これを root-cause として `#188` を切り出し（[discussion #177 §6](../discussions/2026-06-19-discussion-cockpit-observation-ui.md)）、独立した設計判断として確定するのが本 ADR。

問いは「2基盤の identity をそもそも統一すべきか／するならどの方式か」であり、解決策は presume しなかった。探索は (1) read-only 調査（code/schema 直読）、(2) **実機観測**（runtime topology）、(3) **設計SO**（`so-compare --with codex,cursor`・選択肢拡張つき）で行い、経緯は [discussion #188](../discussions/2026-06-19-discussion-188-identity-unification.md) に記録した。

## 確定した事実（決定の前提）

| 項目 | 内容 | 根拠 | status |
|---|---|---|---|
| engine `oe` の identity | `wez pane split` の戻り値＝**wez 整数** pane_id。state KVS（完了時のみ）+ audit jsonl を **session_id 主キー**で書く | `lib/spawn.sh:12`、`schemas/session-state.schema.json:14` | verified |
| delegate（対話子）の identity | `tmux split-window` の **tmux `%N`**。registry のみ（`{pane,label,workspace,parent_pane,role}`）。**state/audit/session_id を持たない** | `bin/oe-delegate:124`、`lib/delegate-registry.sh:56` | verified |
| session_id の出自 | pane 非依存の ULID 生成 | `lib/session.sh:7` | verified |
| **runtime topology** | tmux は**単一の WezTerm ペインの内側**で動く。→ engine の wez-split 子は tmux の外の WezTerm pane で **tmux 不可視**、delegate の tmux 子は wez からは親ペインに潰れて **wez 不可視** | 実機観測（`TMUX_PANE=%33` かつ `WEZTERM_PANE=0`、`tmux list-panes -a`=5 / `wez pane list`=1） | verified（実機直接観測） |

→ **2つの pane-ID 空間（wez 整数／tmux `%N`）は別多重化レイヤの別物理エンティティを指し、橋渡すべき対応関係がそもそも存在しない。** これは現行2-spawn-path アーキテクチャ（engine=wez split／delegate=tmux split-window）の不変条件。

## 決定

issue 受入が「観測ツール(#177)が相関できる、**または**『相関しない（別建て観測）』と明示決定され #177 が再設計可能になる」を許容することに基づき、設計SO の収束を踏まえ以下を確定する。

- **DJ-188-1 — pane-ID 層で identity を統一しない。** 対応関係が物理的に存在しない（上記 topology）。pane を主キーに横断同定する案（後述 B/C）は不成立。
- **DJ-188-2 — engine の session-state/audit スキーマを delegate に拡張しない（案 F 棄却）。** 理由:
  - **category error**: 対話 delegate 子は success/blocked/timeout の完了 lifecycle を持たない。engine の `state` enum に押し込むと「見た目は統一・意味論は非対称」になる。
  - **schema breaking change**: `schemas/session-state.schema.json:14` と `schemas/audit-log.schema.json` が `pane_id: integer`（WezTerm）固定。`{mux,id}` 化は state + audit 両方の破壊変更で、「registry に session_id を足すだけ」では済まない。
  - **ROI 繰延**: 統一の便益は Stage-B 横断メトリクス（保留中）まで発生しない。
  - **#114 で陳腐化**: pane 属性は engine の tmux 化／file-redirect 化（[#114](../discussions/2026-05-30-discussion-clean-output-channel-for-orchestration.md)）で意味が変わる。
- **DJ-188-3 — identity は基盤ごとに保持し、相関が必要な場合は read 時に行う（永続マッピングを作らない）。** observer が両ソース（engine: wez 生存 + state/audit／delegate: tmux 生存 + registry）を読み取り時に投影する。issue 受入の「相関しないと明示決定」に該当する確定。
- **DJ-188-4 — 将来 Stage-B で永続的な横断観測が必要になった場合は、session-state 拡張でなく `session_id` 主キーの typed append-only event/activity bus を採る。** 本 issue では実装しない（deferred）。pane 非依存キーのため #114 後も残る。
- **DJ-188-5 — read-only 制約と書込経路の整合（受入3）。** 「read-only」は**観測者（#177）**を縛る制約であり、producer 側の既存書込（delegate spawn 時の registry `oe_reg_record`、engine 完了時の state/audit `oe_audit_emit`）は対象外。本決定は新規書込経路を一切導入しない。

## 検討した選択肢と評価

| 案 | 概要 | 評価 |
|---|---|---|
| **B** engine が tmux `%N` を併記（dual-key） | engine 子に tmux identity を持たせ突合 | ❌ 不成立。engine 子は WezTerm pane で tmux 非所属 → `%N` を持たない（取得対象が存在しない） |
| **C** wez-primary 俯瞰（`wez pane list` 整数で突合） | wez 側に寄せて整数 ID で一致 | ❌ delegate 子が `wez pane list` に個別 ID として現れない（親ペインに潰れる）。engine 子のみの俯瞰に縮退 |
| **A** spawn 時 `session_id↔wez↔tmux↔label` マッピング表 | 横断同定表を永続化 | ⚠️ F に縮退。各 session は wez か tmux の**片方の identity しか持たない** → 表は実質 `session_id → {mux, id}` の1対1属性。`label`/`workspace`/`parent_pane` は delegate registry にしかなく、横断キーは label でも張れない |
| **F** engine session-state/audit を delegate へ拡張 | session 層で統一・delegate も session レコードを書く | ❌ 採用せず（DJ-188-2）。category error + breaking schema + ROI 繰延 + #114 陳腐化 |
| **D** 統一しない・honest 2表 | engine 側と delegate 側を2つの別ビューで読む | ◯ 機能要件を満たす（受入1を基盤ごとに分解解釈、受入2は engine audit に限定）。本 ADR の DJ-188-3 は D を「read 時投影」に精緻化した形 |
| **query-side fusion（読取時融合・採用方向）** | 永続マップ無し。read 時に両ソースを読み `kind`/`mux` 列付き1テーブルに投影（join しない・delegate 行は `timeline:none`） | ◎ read-only 維持・単一 cockpit ビュー・非対称を正直に表示。設計SO の codex/cursor 両者が #177 に最も堅いと収束。**#177 の実装選択（DJ-188-3 が許容）** |
| **typed event/activity bus** | session_id 主キーの append-only event log。識別統一＝イベント型の統一 | △ deferred（DJ-188-4）。Stage-B 永続横断観測の本線候補 |
| 実行基盤収束（#114 駆動）/ parent-scoped hub | spawn を1 mux に寄せる / 観測起点を親ペインに置く | △ #114 と同一スレッドで評価すべき・別 issue 寄り。本 ADR の identity 判断には不要 |

## 帰結（本決定の影響範囲）

- **identity モデル**: コード変更なし。2-world topology を**アーキテクチャ不変条件**として本 ADR + schema 注記に明文化。
- **schema**: 構造変更なし。`session-state.schema.json` の `pane_id` description に「WezTerm 整数・delegate(tmux) 子は本 KVS の対象外（DJ-188-2）」を追記し、将来の F 方向の誤改修を予防（受入3 の明文化のコード面ガード）。
- **#177（消費者）**: identity モデルが「基盤ごと・read 時相関・永続マップ無し」と確定し **unblock**。俯瞰の再設計（query-side fusion 単一ビュー or honest 2 ビュー）は #177 の判断で、本 ADR はロックしない（推奨方向のみ申し送り）。#177 当初 DJ-1/4/5/6 は再開時も有効。
- **#114 / Stage-B**: 永続横断観測が要るとき event bus（DJ-188-4）を採る方針を申し送り。F に投資しないことで #114 との衝突を回避。
- **テスト**: なし（schema description 追記のみ・構造/バリデーション不変）。

## 代替案を採用しなかった理由（要点）

- **F（session 層統一）を本 issue で実装しない**: 便益（単一俯瞰の永続基盤）は Stage-B まで顕在化せず、対して category error と schema breaking change のコストが先行する。永続化が必要になった時点で event bus（DJ-188-4）の方が #114 と整合し陳腐化しにくい。
- **#177 をブロッカーのままにしない**: 破綻したのは #177 DJ-3 の pane_id ジョイン (a) であり、read 時投影／2表並置は topology 問題ではない。identity を「統一しない」と確定すること自体が #177 の unblock になる。

## 関連

- 探索トレイル（調査・実機観測・設計SO・DJ 経緯）: [discussion #188](../discussions/2026-06-19-discussion-188-identity-unification.md)
- 出自と消費者: [discussion #177 cockpit 観測UI](../discussions/2026-06-19-discussion-cockpit-observation-ui.md)
- 隣接 concern: [#114 クリーン出力チャネル](../discussions/2026-05-30-discussion-clean-output-channel-for-orchestration.md)
- Issue: [#188](https://github.com/stlwolf/ai-development-hub/issues/188) / [#177](https://github.com/stlwolf/ai-development-hub/issues/177) / [#114](https://github.com/stlwolf/ai-development-hub/issues/114)

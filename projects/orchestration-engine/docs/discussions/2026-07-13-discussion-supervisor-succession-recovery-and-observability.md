---
id: "01KXDMVX3NFXS424MWABH7V75V"
title: "統括 succession の頻出性・変換ミス・復旧と observability — 設計クラスタ（#238 の観測層）"
date: 2026-07-13
type: discussion
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/238"
    reason: "統括 succession を第一級概念に。本 doc はその observed 層（段階2 で defer 済み）を引く動機と設計"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/239"
    reason: "watchdog（liveness 監視）。succession event の tuning consumer"
  - type: related_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/247"
    reason: "pane 突合 → session_id 突合（pane-id 依存の根治）。resume 頻出が do-nothing 決定の再評価トリガ候補"
  - type: related_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/169"
    reason: "CLI cockpit viewer。succession を並列表示する消費者"
  - type: related_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/62"
    reason: "negative knowledge。※本 doc の主眼ではない（succession event は運用データで失敗注入ではない）— 区別のため参照"
  - type: decision
    ref: "projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md"
    reason: "lean 上位アーキ。declared（board）+ observed（event projection・段階2 defer）の2層観の正本"
tags: [orchestration, succession, watchdog, recovery, observability, topology, discussion]
---

# 統括 succession の頻出性・変換ミス・復旧と observability

## 1. なぜこの doc

2026-07-13、owner との会話で統括（supervisor）の succession（親の引き継ぎ）まわりの設計論点が3つ連続して surface した — (a) 誤操作でパネルごと閉じた後の**復旧方法**、(b) succession が registry 上で**親子（delegation）として歪んで表現される**問題、(c) succession が**頻出する前提での変換ミスのデータ化**。3点は同一クラスタなので設計材料として1本に束ねる。**実装はしない（設計を残すのが目的・owner 指示）**。#238「succession を第一級概念に」の **observed 層**（lean 決定で段階2 に defer 済み）を今引く動機データが揃った、という位置づけ。

## 2. 問題 — succession は頻出し、その「変換」が壊れる

- **succession は稀な事故でなく頻出の第一級オペ**: long orchestration では統括の context 枯渇が不可避 → refresh（新統括へ handoff）が構造的に必要 → 親の引き継ぎが繰り返し起きる。
- **各 handoff には「変換」がある**: 旧統括 → 新統括へ identity / role / topology を移す。この変換が壊れやすい:
  - 後継統括が、死んだ前任の**子（child）として表示される**（registry の `parent_pane` 焼き込み）。
  - succession board の `現統括:` が**旧 pane を指したまま**（張替漏れ）→ watchdog が inert or 偽 death ping。
  - resume 後の新 pane が**未登録**（viewer に出ない）。

### 2.1 具体例（汎化）

統括 A（親）→ B（A から succession で継承した後継統括）という系で、B が誤操作で tmux ごと閉じられ、resume で新 pane に復帰した。このとき:

- registry は B を「A の子（`role:child`, `parent_pane:A`）」として保持していた（A が B を spawn した名残）。論理的には B は A の**後継＝並列**なのに、**親子として現れる**。
- 復帰した B の実体は**新しい pane 番号**に移り、旧 pane は gone・新 pane は未登録。viewer には「B は gone」としか出ず、実際は生きている。
- **この歪みが、稼働中の別統括（AI）を「B は子だ」と誤誘導した** — succession が並列で表現されていないと、人間だけでなく AI も handoff を delegation と取り違える。#238 の主張の生きた実例。

## 3. root cause（コードで検証済み）

- identity は **tmux の pane id `%N` がキー**。生存判定は `tmux list-panes` メンバシップ（居れば alive・居なければ gone）[verified] `projects/orchestration-engine/bin/oe-tree`（liveness）/ `projects/orchestration-engine/lib/delegate-registry.sh`（`_oe_reg_key` = `<server_pid>_<pane_id>`・record と GC のみが writer）。
- `parent_pane` は **spawn 時に焼き込まれ書き換え機構がない** → succession（前任→後継）が「生きた親子エッジ」として残り、並列の継承として表現できない [verified] `delegate-registry.sh`（record のみ・rewrite 無し）。
- **relink/re-register/resume 復帰の機構はコードに存在しない**（engine 全体 grep でゼロ）[verified]。resume は新 pane を作り、旧 entry は次の spawn 時 GC まで gone のまま。
- 統括（supervisor）side は `oe-vitals` が succession board の `現統括:` pane を読み、sidecar（`session_id` キー・body に `pane`）と突合して liveness 判定。board が旧 pane を指したままだと、pane が一致しなければ inert（no-op）、一致して gone なら偽 death ping [verified] `projects/orchestration-engine/bin/oe-vitals`。
- 既存の観測資産: `oe-vitals` の cron.log（flat な liveness 観測・履歴でない）/ `oe-events.jsonl`（#220/#241・**typed append-only event 基盤が既にある**）/ succession board 冒頭の非構造な succession 履歴。

## 4. 設計原則（会話から抽出）

1. **succession は第一級・頻出のオペ**として扱う（手動 board 編集の都度作業ではなく、clean & 自動な変換を用意する）。
2. **succession は並列（peer 継承）で表現する** — 死んだ前任の下に再 parenting しない。外部の第一級ポインタ（succession board の `現統括:`）が succession の正であり、registry の親子はあくまで spawn の名残として扱う（board があればそちらが正）。
3. **復旧は succession-aware**: 誤 close + resume からの復帰は「後継 pane を supervisor ポインタへ張替 + 孤児 sidecar 掃除」で、死んだ親の下への再 parenting をしない。
4. **succession を event データとして残す（observed 層の最小形）**: 各 handoff を **typed event**（`from → to` / 理由=refresh / 変換完了フラグ）として既存の `oe-events.jsonl` に append する。**汎用の異常ログではなく succession に絞る**（crash 全般や #62 negative knowledge とは目的が違う — こちらは運用の観測）。

## 5. 提案する増分（do-less 起点・実装は本 doc の外）

- **(0) 手動 re-link 手順**（ワンタイムプロンプト）: 復帰統括が自分自身で board `現統括:` を新 pane へ張替 + 孤児掃除 + 検証。まず手動で回して validate（soft floor）。
- **(1) `oe-reseat`（仮）= 変換の自動化**: 上を1コマンド化（`$TMUX_PANE` を読んで board 張替・孤児 sidecar 掃除で偽 ping 停止）。**この verb が succession event を1本 emit する自然な hook** ＝ recovery と観測が同じ do-less で繋がる。
- **(2) succession event の typed 記録**: `oe-events.jsonl` に `supervisor-succession` / `supervisor-recovery` を typed append。変換未完（board stale / 新 pane 未登録）を「conversion incomplete」として検知可能に。
- **(3・段階2）observed projection + viewer 並列表示**: succession 鎖（A→B→C）を親子でなく並列継承として描く（#247 session_id 突合 / #169 viewer と束ねる）。

## 6. 決定（owner・2026-07-13）

- 統括の succession 復旧方法を**作る**（do-less から・実装は別途）。scope は当面 **統括 re-point helper**（`oe-reseat` 相当）から。
- succession は **並列表現**にする（親子歪みを断つ）— viewer 表現だけでなく変換そのものの要件。
- succession event を**データとして残す**（succession に絞る・既存 `oe-events` を再利用・汎用異常ログや #62 とは分ける）。
- **今は実装しない**。本 doc を設計材料として残し、着手は #238 の段階2 判断で。

## 7. open questions / deferred

- 各プロジェクトの cockpit が succession board を持つとは限らない（持たない場合 succession は registry の親子でしか表現されず、歪みの源になる）。board を succession の前提に置くか。
- succession event の schema（最小フィールド・変換完了フラグの定義）。
- `#247` session_id 突合の再評価: resume 頻出は pane-id 依存の弱点を突く。ただし #247 は「統括は常に tmux＝pane 確実 / session_id は `/clear` staleness を持ち込む」で do-nothing 決定済み（2026-07-12）。resume 事故が実運用で頻発するなら再評価トリガ（今回の一件は最初の実データ）。
- consumer 優先度（#239 tuning / #169 viewer / 変換ミス検知）— データの正当化に必要。

## 8. 検証メモ

- 本 doc の root cause（§3）は engine コードの一次読解に基づく（`delegate-registry.sh` / `oe-tree` / `oe-vitals` / 全体 grep）= `[verified]`。設計原則・提案（§4-§5）は会話由来の合意で、実装前ゆえ `[unverified-summary]`（＝方針であって検証済みの挙動ではない）。

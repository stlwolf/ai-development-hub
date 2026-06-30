---
id: "01KWC6K034H9NP0ENZB4S1WTT9"
title: "#114 orchestrate 対象のクリーン取得チャネルは非対話 one-shot の協調 file-redirect を正準とし、scrape を完了 acquisition から降格する"
date: 2026-06-30
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/114"
    reason: "本 ADR の主スコープ（クリーン取得チャネルの正準化・方針/ADR レベル）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/98"
    reason: "本方針の target 経路における具体実装（同 PR で実装）"
  - type: refines
    ref: ./2026-05-18-decision-reviewer-output-file-redirect.md
    reason: "reviewer を file-redirect 化した先行 ADR。本 ADR は target を同経路へ統一し『target 側は現状維持』を解消する"
  - type: source_material
    ref: ../../lib/capture.sh
    reason: "本決定の実装（_oe_scan_log_file / _oe_target_log_path）"
  - type: source_material
    ref: ../../lib/spawn.sh
    reason: "target 送信を file-redirect 形に統一（oe_spawn_send）"
  - type: source_material
    ref: ../../lib/monitor.sh
    reason: "target 監視を pane scrape から log 走査に切替"
  - type: episode
    ref: ../episodes/2026-06-30-episode-114-clean-output-channel.md
    reason: "本 ADR を生んだ実装エピソード（設計探索・設計SO・grounding・実装SO）"
  - type: prior_art
    ref: ../../../../docs/research/2026-05-31-agmsg-agent-messaging-patterns.md
    reason: "scrape 脱却→構造化バス／配送セマンティクス分離の同型先行事例（取得×配送軸の出典）"
tags: [orchestration, capture-channel, scrape, file-redirect, acquisition, delivery-semantics, decision, adr]
---

# #114 クリーン取得チャネルの正準化（scrape 脱却）

## コンテキスト

orchestration-engine は orchestrate 対象（target）と検証者（reviewer）の出力からマーカー（`@@OE_EXIT:N` / `@@OE_VERIFY:pass|fail|warn`）を読み取り、完了・結果を判定する。両者とも**非対話 one-shot** で起動済み（`cursor-agent --print` / `claude -p --output-format text`〔lib/spawn.sh:203,208〕）。しかし取得チャネルが非対称だった:

- reviewer: `( cmd 2>&1 ; printf @@OE_EXIT ) | tee /tmp/oe-{rsid}-reviewer.log` → `tail` で log 走査（[2026-05-18 ADR](./2026-05-18-decision-reviewer-output-file-redirect.md) で file-redirect 化済み）。
- target: `wez pane send` に生コマンド → `wez pane capture --lines 50`（WezTerm の **2D 描画グリッド**）を scrape〔lib/capture.sh:48〕。

`wez pane capture` は WezTerm が解釈・描画済みのグリッドを返すため本質的に脆い: ボックス装飾 `│ @@OE_EXIT:0 │`、行折返し、TUI 再描画、viewport-only。#112 で字下げ marker への regex 緩和（Part 1）を入れたが、上記は緩和ではカバーできない。「マーカーはどんな形であれ取れる」というオーケストレーションの前提を満たすには、scrape でなくクリーンな取得チャネルが要る。

非所有プロセスの stdout 直読は OS 的に原則不可で、クリーンに取る道は **(a) 所有（子を PTY 付きで起動）** か **(b) 協調（出力を file redirect させて読む）** の 2 つ。対話 TUI 出力は生ストリームを取れても制御コード列でクリーンでなく、クリーンテキストは print/構造化モード（`claude -p` 等）でのみ得られる。

## 決定

1. **正準取得チャネル**: orchestrate 対象の**完了/出力 acquisition** は「非対話 one-shot の `2>&1` transcript（stdout+stderr）を**協調 file-redirect**（per-session ログ）し、engine が `tail` で走査する」を正準ベースラインとする。target も reviewer と同じ経路へ統一する（#98）。
2. **scrape の降格スコープ**: `wez pane capture`（2D グリッド scrape）は**非対話 target の完了 acquisition から降格**する。ただし次は scrape を機械的に継続する（降格は acquisition 限定）:
   - spawn 前 readiness 判定（`oe_board_wait_ready` / `_wez_wait_pane_ready`〔lib/spawn.sh:102-106〕。出力の非空・安定のみを見る用途）。
   - 対話ペインへの attach（`bin/oe-capture`、#109。対話中ペインを壊さず viewport を読む独立入口）。
3. **記述軸**: 本チャネル選択を以下の軸で位置づけ、将来の進化余地を明示する（agmsg prior-art の軸）:
   - **取得 (how)**: scrape / file-redirect / 所有 subprocess / 構造化イベント。本決定は file-redirect。
   - **配送 (when)**: poll（現行・`tail` ポーリング）/ push（割込・将来）。本決定は poll 相当。
   - **制御/本文の分離**: 現行は制御信号（marker）が本文 transcript と**同居**。将来の分離（サイドカー/イベント化）の余地を残す。
   - **acquisition と recording の分離**: 本 ADR は acquisition（子→engine の結果取得）の正準化。engine の event-bus/audit JSONL〔lib/event-bus.sh / lib/audit.sh〕は engine が検知後に emit する **recording（downstream）** であり acquisition チャネルではない。両者を混同しない。
4. **対話 TUI orchestrate** は別チャネル課題（セッションログ / フック等）として **defer**（本サイクル対象外）。

## 実装（#98 = 案A の target 脚）

- `lib/capture.sh`: `_oe_scan_log_file <path> [lines]`（log 走査の共通コア＝reviewer/target 共有 primitive）と `_oe_target_log_path <session_id> <pane_id>`（target log の単一情報源 → `/tmp/oe-{sid}-{pane}-target.log`）を新設。
- `lib/spawn.sh:oe_spawn_send`: target 送信を `( cmd 2>&1 ; printf @@OE_EXIT ) | tee "$(_oe_target_log_path …)"` に統一。tee は pane TTY にも書くため**人間は引き続き pane で観察**できる。
- `lib/monitor.sh`: scan を `oe_capture_scan`（wez pane capture）→ `_oe_scan_log_file "$(_oe_target_log_path …)"` に切替。`OE_SCAN_MARKER_TYPE=EXIT` 消費部は不変（source が pane→file に変わるだけ）。
- `lib/verify.sh:_oe_verify_scan_log_file`: 共通コアへ委譲する薄いラッパに変更（reviewer 経路は不変）。
- `lib/cleanup.sh`: 変更不要（glob `/tmp/oe-{session_id}-*`〔cleanup.sh:55〕が target log を捕捉）。
- target log を `(session_id, pane_id)` で鍵付け（reviewer は単一で session 鍵で足りるが、target は #98 が動機に挙げた multi-pane 並走でログ衝突を避けるため）。spawn（tee 構築）と monitor（走査）が同関数を使い**パス書式の drift = #98 が警戒する非対称ハザードを構造的に排除**。

## 根拠

- reviewer で file-redirect が実証済み（[2026-05-18 ADR](./2026-05-18-decision-reviewer-output-file-redirect.md)）。target はその水平展開でデルタ最小・回帰リスク低。
- file 経路は OS ファイルシステム上で全ストリームを保証し、WezTerm の viewport-only / グリッド描画に非依存（長文・行折返し・装飾でも marker を取りこぼさない）。
- per-session ログ（`/tmp/oe-{sid}-{pane}-target.log`）は agmsg が踏んだ**共有テキストファイルの並行破損**とは無縁（セッション/ペイン別で衝突しない）。
- 「ランタイムは借りる・engine は協調プロトコルを提供する」という Phase 3 選択肢B と整合（所有 subprocess 化＝案B は逸脱）。

## 棄却・defer 案（確定前のゼロベース探索＋設計SO で外部化）

確定前に `oe-refute --claim … --rubric exploration`（設計SO・lanes=codex/cursor）を実行。verdict=**refuted**（audit_id `20260630094501F1333D1JNE4W`）で確定を保留し、指摘された第4カテゴリ群を一次情報で grounding した上で各案を以下に位置づけた。

| 案 | 差分軸 | 判定 | 理由 |
|---|---|---|---|
| **案A** file-redirect（採用） | 取得=file・marker 本文同居・poll | ✅ 採用 | reviewer 経路の水平展開。実証済み・デルタ最小・人間 pane 観察を保持 |
| **案B** engine 所有 subprocess + 構造化 JSON（pane なし） | 責務=所有・pane 無 | ❌ 棄却 | `cursor-agent`/`claude` とも `--output-format json` 対応は**一次確認済**（棄却根拠は「json 不明」ではない）。pane 喪失（人間観察不可）+ Phase 3「ランタイムは借りる」逸脱 + blast radius 大 |
| **案C** 構造化 status サイドカー（制御/本文分離・将来 push） | 制御信号を本文から分離 | ⏸ defer（進化経路） | #112 偽陽性を構造的に根絶しうるが、クラッシュ耐性ある atomic 書込ラッパ + 二重メンテが必要。現時点は YAGNI |
| **案D** producer-side typed event bus（既存 event-bus/audit） | 構造化イベント発行 | ⏸ defer（#188 と連結） | 既存 event-bus/audit は engine が検知後に emit する **recording・downstream であり acquisition でない**（[#206 ADR](./2026-06-22-decision-206-activity-log-self-contained-events.md)）。子が bus へ emit する「真の案D」は案C と #188 DJ-188-4 の合流＝将来 |
| get-text/scrollback（`wez pane capture --start-line` / `wezterm cli get-text --start-line`） | scrape の延命 | ❌ 棄却 | [2026-05-18 ADR](./2026-05-18-decision-reviewer-output-file-redirect.md) が Step4-4 スコープ外で棄却済を本決定で再分類。描画グリッド依存は残り scrape の本質的脆さを解消しない |
| #20 `wez agent` リッチ API 中間層 | プロトコル中間層 | ⏸ future | #20 Phase 3 で着手予定。pane scrape でも file-redirect でもない別カテゴリ |
| agmsg 型 SQLite-WAL バス | 構造化バス | ⏸ defer（Track-B） | research note の experiment/defer 対象。常駐購読プロセスのライフサイクル管理（agmsg #66-68）が同型の落とし穴 |
| 対話 TUI 用 別チャネル（セッション JSONL / フック） | 対話 orchestrate | ⏸ defer | #114 が明示的に切り出した別課題。本サイクル対象外 |

## 結果

- target/reviewer の取得チャネルが file-redirect に統一され、#98 の「経路の非対称＝将来 hazard」が解消。
- 完了 acquisition の正準が明文化され、scrape の正当な残存用途（readiness / 対話 attach）と区別された。
- 取得×配送×制御分離×(acquisition vs recording) の軸により、案C/案D/push 配送への将来拡張が記述上 open に保たれた。
- 全テスト 23 ファイル green / shellcheck clean。実装SO（`oe-review`）を PR 前に実施。

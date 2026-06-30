---
id: "01KWC6K04BKRM56PJZ6MCZ34K9"
title: "#114 クリーン出力チャネル統一(scrape脱却)ADR + #98 target file-redirect 実装"
date: 2026-06-30
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/114"
    reason: "方針/ADR レベル（クリーン取得チャネルの正準化）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/98"
    reason: "target 経路の具体実装（file-redirect 統一）"
  - type: decision
    ref: ../decisions/2026-06-30-decision-114-clean-output-channel.md
    reason: "本 episode が生んだ ADR"
  - type: refines
    ref: ../decisions/2026-05-18-decision-reviewer-output-file-redirect.md
    reason: "reviewer を file-redirect 化した先行 ADR。target 側を同経路へ統一して非対称を解消"
tags: [orchestration, capture-channel, scrape, file-redirect, adr, episode]
---

# #114 クリーン出力チャネル統一 + #98 target file-redirect 実装

委譲子セッション（親＝統括）。設計・実装は人間とこのペインで直接、完了確認のみ親へ。

## 設計フェーズ（discussion → predecision → 設計確定）

### 現状コードマップ（検証済み）

両系統とも**非対話 one-shot** で起動済み。差は取得チャネルのみ:

- target (cursor-agent/composer-2): `cursor-agent --print --force`〔lib/spawn.sh:203〕→ `wez pane send` 生コマンド〔spawn.sh:244-246〕→ `wez pane capture --lines 50`(2D グリッド scrape)〔capture.sh:48〕。
- reviewer (claude/sonnet-4-6): `claude -p --output-format text`〔spawn.sh:208〕→ `( cmd 2>&1; printf @@OE_EXIT ) | tee /tmp/oe-{rsid}-reviewer.log`〔verify.sh:274-279〕→ `tail -n 5000` でログ走査〔verify.sh:491〕。

→ 「非対話 claude -p」は既に両系統で成立。残ギャップは **target の取得チャネルが pane-scrape のまま**という非対称（#98 = その target 脚の実装）。

### predecision-exploration（ゼロベース代替＋設計SO）

初期案 A/B/C を外部化し、確定前に `oe-refute --rubric exploration`（設計SO）を実行。

- 設計SO: `oe-refute --claim claim-114.md --rubric exploration`、lanes=2(codex,cursor)
- verdict: **refuted**（2/2 material）/ audit_id `20260630094501F1333D1JNE4W`
- codex: 「既存 typed event/audit JSONL の producer-side channel と get-text/scrollback 代替が未評価。grounding 不足」
- cursor: 「event-bus/audit/wez-agent/oe-capture/readiness-scrape の第4カテゴリ未評価。2>&1 tee・二重マーカー・機械scrape残存」

規律どおり**確定を保留**し、指摘を一次情報で grounding:

- 案B 棄却根拠の修正: `cursor-agent --output-format json|stream-json`・`claude -p --output-format json` とも**サポートを一次確認**。棄却は「json不明」でなく pane喪失 + Phase3「ランタイムは借りる」逸脱 + blast radius に拠る。
- 案D(既存 event-bus/audit)は **acquisition 層でない**: `oe_audit_emit "session_end" … "$OE_CLASSIFY_STATE"`〔monitor.sh:123, attach.sh:45〕は engine が検知後に記録＝recording・downstream。→ ADR に **acquisition(子→engine) vs recording(engine→JSONL)** 軸を新設。
- 「scrape を人間補助に降格」は過大: scrape は readiness 判定〔spawn.sh:102-106〕と対話 attach `bin/oe-capture`(#109)で機械必須。降格スコープは「非対話 target の完了 acquisition」に限定。
- チャネルは "stdout" でなく `2>&1` transcript。per-session ログ `/tmp/oe-{sid}-*.log` で agmsg 共有ファイル破損とは無縁。

確定前証跡（探索木＋verdict/reason）: 別途記録し ADR 「棄却・defer 案」節へ蒸留。人間に再提示 → **これで確定** の承認を得た（収束 cutoff = 人間）。

### 確定した設計（= ADR）

acquisition チャネルの正準ベースライン = 非対話 one-shot の `2>&1` transcript を協調 file-redirect(per-session)。scrape は acquisition から降格（readiness/対話 attach では機械継続）。案A を #98 実装ベースラインに採用。詳細は ADR 参照。

## 実装フェーズ（#98 = 案A target 脚）

- ブランチ `feature/#114_clean_output_channel`（master 最新・issue起点）作成。
- `lib/capture.sh`: `_oe_target_log_path`（`/tmp/oe-{sid}-{pane}-target.log` の単一情報源）+ `_oe_scan_log_file`（log 走査の共通コア）を新設。
- `lib/verify.sh:_oe_verify_scan_log_file` を共通コアへ委譲する薄いラッパに（reviewer 呼び出し側不変）。
- `lib/spawn.sh:oe_spawn_send`: target 送信を `( cmd 2>&1 ; printf @@OE_EXIT ) | tee target.log` に統一。tee で pane TTY にも出るため人間の pane 観察を保持。
- `lib/monitor.sh`: scan を `oe_capture_scan`（pane scrape）→ `_oe_scan_log_file "$(_oe_target_log_path …)"` に切替。EXIT 消費部は不変。
- `lib/cleanup.sh`: 変更不要（glob が target log を捕捉）。
- 設計上の判断: target log は `(session_id, pane_id)` 鍵（#98 の multi-pane 動機でログ衝突回避）。spawn と monitor が同関数を使いパス書式 drift を排除。

### テスト

- `tests/test_monitor.sh`: monitor のループ制御を対象にするため scan 層（`_oe_scan_log_file`/`_oe_target_log_path`）をモック化（pane capture 廃止）。31 PASS。
- `tests/test_capture.sh`: `_oe_target_log_path`/`_oe_scan_log_file` の実ファイル単体テスト追加（不在 file 安全 / EXIT 検出 / 長文 tail / 字下げ正規化 / プロンプトエコー非検知）。112 PASS。
- `tests/test_e2e_smoke.sh`: wez mock の send に target tee 検知ブロック追加、capture-count assertion → tee-path assertion に更新。46 PASS。
- 全 23 テストファイル green / shellcheck clean（lib 4 + tests 3）。

### 検証ゲート

- 実装SO（`oe-review`・reviewed diff バインド・設計SO と別レンズ）: **refuted**（1/2 material・audit_id `202606301215340G0VFGFZW3R5`）。
  - codex(refuted): target transcript を権限制限なしの `tee /tmp/oe-{sid}-{pane}-target.log`（既定 umask 022 → 0644 world-readable）へ永続化。pane 表示のみ（ephemeral）だった target が共有 /tmp 上の読み取り可能ファイルに露出。秘密情報を含み得る。cleanup は best-effort で実行中/異常終了時を防げない。
  - cursor(survived): correctness/堅牢性に material 欠陥なし。
  - 注: reviewer 経路（verify.sh:277 の `tee …-reviewer.log`）も同じ露出を持つ**先行 issue**。本変更は同パターンを target へ水平展開した結果、target にも露出が及んだ。
  - 規律どおり PR を保留。修正方針（log 作成時に `umask 077` で 0600）と reviewer 同時是正の要否を人間と確認 → **target+reviewer 両方**を選択。
  - 修正: `( umask 077 ; ( cmd 2>&1 ; printf @@OE_EXIT ) | tee log )` に。tee はパイプライン側なので umask はパイプライン全体を囲う外側 subshell で設定（左 subshell 内では効かない＝/tmp で実証: 左のみ 0644 / 全体囲い 0600、exit code 捕捉も維持）。spawn.sh(target) + verify.sh(reviewer) 両方。e2e に umask 077 回帰アサーション追加。
  - 再 oe-review（同 diff）: （結果を追記）
  - 学び: 設計SO（oe-refute・breadth）を通過しても実装SO（oe-review・コード欠陥/到達可能性）が別レンズで material 欠陥を捕捉した。両 SO は代替不可（#192 の false-pass 回避の実例）。

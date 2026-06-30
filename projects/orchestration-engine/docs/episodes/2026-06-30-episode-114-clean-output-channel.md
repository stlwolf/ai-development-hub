---
id: "01KWC6K04BKRM56PJZ6MCZ34K9"
title: "#114 クリーン出力チャネル統一(scrape脱却)ADR + #98 target file-redirect 実装"
date: 2026-06-30
type: episode
status: stable
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
  - 再 oe-review（同 diff・audit_id `20260630122954FD9EF151FGHT`）: **survived**（2/2・codex が umask 077 の transcript 権限制限を実コードで確認、cursor も umask 0600・共通 scan primitive の一貫性を確認）。
  - 学び: 設計SO（oe-refute・breadth）を通過しても実装SO（oe-review・コード欠陥/到達可能性）が別レンズで material 欠陥を捕捉した。両 SO は代替不可（#192 の false-pass 回避の実例）。

## Closure（episode-retrospective・heavy tier）

tier: **heavy**（実行中に SO 2回 refuted→修正の方針反映 / 意図的外部レビュー2レーン[oe-refute, oe-review×2] / 非自明設計判断[A-D・acquisition vs recording 軸] / Decision 昇格あり）。

### closure gate checklist

- **Context / なぜ**: 冒頭に記載済（両系統とも非対話 one-shot 化済で残ギャップは target の取得チャネルが pane-scrape のまま＝非対称。#114 が方針、#98 が target 実装）。
- **次の消費者**: #98（target file-redirect 実装の親 issue・本 PR で close）/ 将来 push 配送・案C/案D を検討する engine 拡張（#188 typed event bus・#105 Phase5）/ scrape の正当残存用途（readiness・oe-capture #109）を触る作業。
- **follow-up routing**:
  - reviewer 経路の同露出 → **本 PR で同時是正済**（umask 077）。
  - ログ保存先を共有 `/tmp` → 専用ディレクトリ（`OE_DATA_DIR` 下 0700 等）へ移すハードニング → **defer・別 issue 候補**（reviewer 含む大きめ変更）。ADR 結果節に明記。
  - 案C（構造化 sidecar）/ 案D（子が typed event を emit）/ push 配送 → **defer・進化経路**として ADR に外部化（#188 / #105 と連結）。
  - 対話 TUI orchestrate の別チャネル → **defer**（#114 が明示的に切り出した別課題）。
- **status 確定**: draft → **stable**（達成: #114 ADR 確定 + #98 target 実装完了・全テスト green・両 SO クリア）。
- **evidence anchor**: 設計SO audit_id `20260630094501F1333D1JNE4W`、実装SO refuted `202606301215340G0VFGFZW3R5` / survived `20260630122954FD9EF151FGHT`。設計SO の探索木 trace は揮発 scratchpad（dj-114-tree.md）だったが**内容を ADR 棄却案節へ転記済**（パス依存を排除）。

### 事実・失敗

- 設計SO（oe-refute）が **refuted**（2/2）。第4カテゴリ（既存 event-bus/audit の producer-side channel・get-text/scrollback）未評価と grounding 不足を指摘 → 一次情報で grounding し ADR の幅・精度を是正（本文「設計フェーズ」§predecision 参照）。
- 実装SO（oe-review）が **refuted**（1/2 material）。transcript を /tmp に 0644 で露出するセキュリティ欠陥 → `umask 077`（0600）で是正、再 oe-review survived（本文「検証ゲート」参照）。
- いずれも選択的省略なし（両 refuted の audit_id・修正・再検証を上記に明記）。

### 決定と根拠（→ Decision 昇格済）

本 episode の設計判断は ADR `2026-06-30-decision-114-clean-output-channel.md` に蒸留（取得チャネル正準化・scrape 降格スコープ・取得×配送×制御分離×acquisition/recording 軸・棄却/defer 案）。

### わかったこと（W）

- target/reviewer は**既に両方とも非対話 one-shot**（`cursor-agent --print` / `claude -p`）。#114 の初期案「非対話 claude -p + file-redirect」のうち非対話部分は実現済で、残ギャップは取得チャネルのみだった（設計の最大の単純化点）。
- 既存 event-bus/audit JSONL は engine が**検知後に emit する recording・downstream** であり、acquisition チャネルではない（混同しやすい・設計SO が指摘）。
- `cursor-agent`/`claude` とも `--output-format json` を一次確認（案B 棄却根拠は「json 不明」でなく pane 喪失・Phase3 逸脱）。
- パイプライン `( cmd ) | tee` の umask は**外側 subshell で囲わないと tee に効かない**（/tmp で実証）。

### 原則（Pattern / Anti-pattern）

- Pattern: 取得経路を統一するとき**パス書式の単一情報源**（`_oe_target_log_path`）を spawn/monitor で共有 → 経路非対称ハザード（#98 が警戒）を構造的に排除。
- Anti-pattern: 取得チャネルを file-redirect 化する際、transcript を**共有 /tmp に既定 umask（0644）で**落とす → world-readable 露出。`( umask 077; … | tee )` で 0600 にする。チャネル統一は「機能」だけでなく**権限**も統一せよ。
- Pattern: 設計SO（breadth）と実装SO（コード欠陥）は**別レンズ・別ステップ**。設計SO 通過は実装SO の代替にならない（本 episode で実装SO のみが material セキュリティ欠陥を捕捉）。

### 蒸留シグナル

- Decision: **昇格済**（本 ADR）。
- skill/rule: なし（既存 episode-flow / predecision / SO 群で覆われる）。
- negative knowledge（#62）: 「file-redirect 化で /tmp 既定 umask 露出」は anti-pattern 候補として上記に記録。

### Step4 外部チェック

closure 品質（失敗の選択的省略 / routing 網羅 / evidence anchor / back-propagation）の focused check を `so-compare`（codex）で実施。出力: `tmp/so-20260630-213846/codex-stdout.txt`。

結果=部分合格。指摘と対応:
- 選択的省略なし（両 refuted は記録済）と確認。ただし機械確認用に `事実・失敗` 見出しが無い → **本 closure に追加**（上記）。
- follow-up routing は網羅と確認（漏れなし）。
- 揮発 scratchpad の要点は ADR 棄却案節へ転記済と確認。Step4 結果リンク未記入 → **本記述で充足**。
- **back-propagation 漏れ（valid）**: 先行 ADR `2026-05-18-decision-reviewer-output-file-redirect.md` が reviewer の旧 `tee` を accepted のまま載せ、umask 是正への前方参照が無い → 同 ADR に #114 ADR への補足参照を **1 行追記して是正**。

## Follow-up（2026-07-01・PR #216 受け入れレビュー対応・追記）

closure 後の追記（リアルタイム追記の延長・上記本体は overwrite しない）。親の受け入れレビューからの 2 件を 1 ラウンドで対応。

### Copilot レビュー対応（PR #216・1 ラウンド）

未返信 Copilot スレッド 2 件（spawn.sh:257 / verify.sh:281）。**同一の妥当な指摘**: `umask 077` は **新規作成時のみ** mode を決めるため、ログが既存（前回 run 残り等）だと `tee` が既存 mode を保持し 0600 保証が崩れる。

- 対応（valid・修正）: `tee` 直前に `rm -f "$log_path"` を追加し、必ず restrictive umask 下で作り直す。spawn.sh(target) + verify.sh(reviewer) 両方。/tmp で実証（stale 0644 + umask のみ→0644 / +rm -f→0600・exit code 捕捉維持）。e2e に rm -f 回帰アサーション 2 件追加。両スレッドへ返信済。
- 残（defer・既記載）: /tmp symlink 攻撃の完全対処は保存先を 0700 専用 dir へ移す別 issue 候補（rm -f は TOCTOU 残あり・現実的な stale 0644 ケースは解消）。
- 1 ラウンドで完結。再レビュー再依頼（`--add-reviewer @copilot`）はしない（ユーザー明示時のみ）。

### episode 訂正（親ファクトチェック反映）

本体の数値を残したまま訂正を追記（additive）:

- **e2e テスト数**: テスト節「`test_e2e_smoke` … 46 PASS」は誤り。umask アサーション追加で **48**、本 follow-up の rm -f アサーション追加で現在 **50 PASS**（`bash tests/test_e2e_smoke.sh` で確認）。
- **bash 3.2 失敗の明記（選択的省略の補完）**: 「全 23 テストファイル green」は **bash 5.2.37 での結果**。macOS 標準 `/bin/bash`（**3.2.57**）では `tests/test_*.sh` 23 件中 **21 green / 2 fail**（`test_monitor` 本 PR 変更・`test_cleanup` 未変更）。原因は **#193 の既存債務**（`declare -A` 連想配列＝bash 4+ 必須、`test_monitor.sh:37 line 37: declare: -A: invalid option`）。**master の同テストも 3.2 で同様に fail＝本変更の回帰ではない**（master 版を 3.2 で実行し確認）。bash 5.2 では 23 件全 green。
- **行番号ドリフト**: 上記「設計フェーズ」の `oe_audit_emit "session_end"` 参照 `monitor.sh:123` は master 時点の値。本変更でコメント追加により現在 **:128**（attach.sh:45 は不変）。

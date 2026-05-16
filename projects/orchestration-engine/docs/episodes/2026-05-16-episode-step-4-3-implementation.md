---
id: "01KRQA3H7WK03Y6TGN5ZZZBZG7"
title: "Step 4-3 検証ゲート v1 実装エピソード (元実装 + so-compare レビュー反映)"
date: 2026-05-16
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-3"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/89"
    reason: "Step 4-3 観測層 Issue (本エピソードの主スコープ)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-15-discussion-step-4-3-verification-gate.md"
    reason: "Step 4-3 Discussion (QDD 全 7 Q closed)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-15-kickoff-step-4-3-verification-gate.md"
    reason: "Step 4-3 KickOff (status: confirmed)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-15-plan-step-4-3-verification-gate.md"
    reason: "Step 4-3 Plan (5 Phase 構成、so-compare 初回レビュー F1-F8 反映済み)"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/90"
    reason: "Step 4-3 全成果物の PR (本エピソードの記録対象)"
  - type: source_material
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review プロンプト規約 (engine が use_skills 経由で参照)"
  - type: derived
    ref: "https://github.com/stlwolf/ai-development-hub/issues/91"
    reason: "F-SO-7 派生 Issue: Step 4-4 着手前必須の AI CLI 起動オプション修正"
  - type: derived
    ref: "https://github.com/stlwolf/ai-development-hub/issues/92"
    reason: "F-SO-8/9 派生 Issue: Step 4-5 候補の変更ファイル検出 + 完了報告充実"
  - type: derived
    ref: "https://github.com/stlwolf/ai-development-hub/issues/93"
    reason: "F-SO-10/11 派生 Issue: MVP 後拡張候補の一時ファイル掃除 + nonce マーカー"
tags: [orchestration, mvp, step-4-3, episode, implementation, so-compare, adversarial-review]
---

# Step 4-3 検証ゲート v1 実装エピソード

> Plan ([`2026-05-15-plan-step-4-3-verification-gate.md`](../plans/2026-05-15-plan-step-4-3-verification-gate.md)) に従って 5 Phase で実装を行い、完了後に `so-compare` (Codex + Claude) で実装レビューを実施した記録。本エピソードは **(A) 元実装フェーズの記録**、**(B) so-compare レビュー結果**、**(C) F-SO 修正反映後の実装記録** を明確に分離して残す。

## 概要

| フェーズ | 期間 | 主な成果物 |
|----------|------|-----------|
| (A) 元実装 (Phase A〜E) | 2026-05-15 22:51 〜 2026-05-16 02:43 (JST) | `lib/verify.sh` 新規 + schema 拡張 + capture/cleanup/bin/oe/test_e2e_smoke 更新、8 テストスイート 280 assertions |
| (B) so-compare 実装レビュー | 2026-05-16 02:52 〜 02:58 (JST) | Codex (133s) + Claude (344s) 並列、Critical 一致 3 件 + 高 Concern 多数 |
| (C) F-SO 修正反映 | 2026-05-16 03:00 〜 03:29 (JST) | F-SO-1〜6 + F-SO-12 を 1 コミット (`4a05fe8`)、test_verify 85 → 98、全 293 assertions |
| (D) 派生 Issue 起票 | 2026-05-16 (本エピソード作成時) | [#91](https://github.com/stlwolf/ai-development-hub/issues/91) / [#92](https://github.com/stlwolf/ai-development-hub/issues/92) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93) |

---

## (A) 元実装フェーズ — Phase A〜E

KickOff §進め方 + Plan §Phase 構造に従い 5 Phase で実装した。Plan の F1〜F8 (so-compare 初回レビュー、Plan ドキュメント段階) は実装着手前に反映済み。

### Phase A — スキーマ拡張 + validator (DI-5) — `d6d258a`

- `schemas/session-state.schema.json`: `verification` を **pane-keyed map** (target_pane_id をキー) として追加、`verification_summary` (集計) を追加。両方 optional
- `schemas/audit-log.schema.json`: event_type に `verification_started` / `verification_completed` を追加
- `scripts/validate-session-state.sh` 新規: jq ベース validator (必須フィールド + 型 + ULID パターン + verification map の構造 + summary 数値範囲)
- `tests/test_kvs.sh`: legacy KVS / 拡張 KVS / 不正値の 3 ケース追加 (10 → 13 assertions)

**設計判断:**
- `verification` を単一オブジェクトではなく pane-keyed map にしたのは Plan F5 反映 (so-compare 初回レビューで Codex 指摘) で確定済み。実装段階で再確認済み
- `validate-session-state.sh` は `validate-envelope.sh` をひな型にして対称性を維持

### Phase B — 検証 envelope 生成 + spawn (DI-3 + DI-7(a)) — `da4866a`

- `lib/verify.sh` 新規: `oe_verify_envelope_create()` + `oe_verify_spawn()`
- envelope の `task.use_skills: [adversarial-review]` で疎結合 (Plan F4 反映: engine に skill prompt の static copy を持たない)
- `task.exit_conditions.marker: "@@OE_VERIFY"` で engine プロトコルを envelope で指定
- `verification_started` audit イベントは `oe_verify_spawn` 内で emit (Plan F6: emit 責務を Phase B に固定)
- `tests/test_verify.sh` 新規 (32 assertions): wez モック経由で envelope 構造 + spawn フロー + audit emit を検証

### Phase C — プロンプト構築 (DI-4) — `8baab8e`

- `oe_verify_prompt_build()`: envelope の `task.description` + audit JSONL の最後の `state_change` + KVS の `outputs[]` から構造化マークダウン (3 セクション) を生成、`OE_VERIFY_PROMPT_PATH` でエクスポート
- `oe_verify_envelope_create` に optional 6 引数目 `verify_prompt_path` を追加し、指定時に `task.read_docs` の 5 件目として注入 (Phase B 既存テスト後方互換)
- `oe_verify_spawn` を `prompt_build` → `envelope_create (with prompt)` の順に統合
- `outputs[]` が空の場合 `git diff --name-only` フォールバック (Plan F7 反映: MVP では常に git パスが選ばれる旨を明示)
- test_verify.sh 拡張 (32 → 53 assertions): プロンプト構築 + フォールバック + envelope read_docs 5 件版

### Phase D — マーカーパース + KVS 書き込み + 集計 (DI-7(b) + DI-5(書き込み)) — `db2f9a1`

- `lib/constants.sh`: `OE_VERIFY_MARKER_RE='^@@OE_VERIFY:(pass|fail|warn)$'` を追加
- `lib/capture.sh`: 戻り値を二値保持 (`OE_SCAN_EXIT_CODE` + `OE_SCAN_VERIFY_RESULT`、Plan F3 反映) に拡張、既存 `OE_SCAN_MARKER_TYPE` / `OE_SCAN_VALUE` は後方互換
- `lib/verify.sh`: `oe_verify_write_kvs()` (pane-keyed map で per-pane 書き込み) + `oe_verify_summary_update()` (jq 集計 + awk fail_rate 3 桁丸め) + `oe_verify_emit_completed()` (Phase D 責務、Plan F6 反映)
- `tests/test_capture.sh` 拡張: VERIFY パース 22 ケース (pass/fail/warn / 不正値 / 行頭アンカー / VERIFY+EXIT 同時検出) → 45 → 67 assertions
- `tests/test_verify.sh` 拡張: KVS pane-keyed 書き込み + 集計 + emit_completed + F6 責務分離 → 53 → 85 assertions

### Phase E — 発火統合 + 通知 + E2E (DI-2 + DI-6) — `5c402fc`

- `lib/constants.sh`: `OE_VERIFY_MANAGED_PANES` / `OE_VERIFY_DONE_PANES` (Plan F2 反映: OE_MANAGED_PANES と分離) + `OE_VERIFY_PHASE_COMPLETED` フラグ
- `lib/verify.sh`: `_oe_verify_generate_session_id` (ULID 形式 reviewer_session_id 生成) + `oe_verify_run_phase()` (独立ポーリングループ、Plan F1 反映: monitor.sh の責務範囲を膨らませない)
- `bin/oe`: oe_monitor_loop 成功時のみ `oe_verify_run_phase` を呼ぶ (CB 発動時はスキップ)
- `lib/cleanup.sh`: OE_VERIFY_MANAGED_PANES も kill 対象、`OE_VERIFY_PHASE_COMPLETED=1` のとき `wez notify` で完了通知 (DI-6)
- `tests/test_e2e_smoke.sh` 拡張: wez モックを連番化 (target 777 / reviewer 888)、検証フェーズを含む 1 サイクル完走を確認 → 15 → 40 assertions

### Phase E 完了時点の統計

- 全 8 テストスイート 280 assertions PASS、shellcheck クリーン
- KickOff §完了条件 8 項目すべて mock 経由で達成
- 設計判断は Plan F1〜F8 反映方針に沿って着地

---

## (B) so-compare 実装レビュー (Codex + Claude 並列)

Phase E 完走後、user 提案 + 私の同意で **so-compare** (Codex + Claude 並列) を実施した。前回 (Plan ドキュメント段階) の so-compare で F1〜F8 を反映済みのため、**今回は実装段階の "前提条件" と "設計判断"** にスコープを絞ったプロンプトで実施。

### プロンプト設計

`/tmp/so_impl_review_prompt.txt` (永続化なし、`tmp/so-20260516-025239/prompt.txt` に保存) に以下を明示:

- 品質観点 (Bash 3.2 互換性の細部、命名、コード重複、shellcheck 警告等) はスコープ外、MVP のため
- **「前提条件」レビュー観点 (6 点)**: AI CLI prompt 最小性、skill path 解決、VERIFY/EXIT 同時検出、CB タイムアウト、shared_kvs_path 意味、F3 後方互換
- **「設計判断」レビュー観点**: 含む 6 観点の critical 部分
- **「ゼロベース観点での見落とし発見」**: 私が flag していない設計判断・前提条件で「これは見落としではないか」と感じる点をすべて列挙してほしい

### 結果概要

| Reviewer | 経過 | 出力サイズ | 判定 |
|----------|------|-----------|------|
| Codex | 133s | 9613 bytes | **Critical** — 設計の小さな手戻りが必要 |
| Claude | 344s | 15716 bytes | **Concern (条件付き)** — 設計判断レベルの手戻り不要、運用前ゲート 3 点必須 |

両者一致の **Critical 3 点**:

1. **AI CLI prompt の最小性**: `${ai_cli} --prompt` が実 CLI (`claude -p`, `codex -p`) と不整合。実 agent では起動エラー → silent failure
2. **`@@OE_VERIFY:` 検出時の `@@OE_EXIT:` 軽視**: F3 二値保持を実装したのに `oe_verify_run_phase` 内ループで EXIT_CODE をチェックしていない。`exit_code=124` (timeout) や `exit_code=1` (failure) が並んでも verify_result を盲信する設計欠落
3. **`Spec Compliant / Issues Found` → `@@OE_VERIFY:pass/fail/warn` マッピングが engine から検証 agent に伝達されない**: Discussion Q5 で決めたマッピングが task.description にも skill にも書かれていない

両者一致の **Concern 多数**:

- `context.shared_kvs_path` を target session の state ファイル (file path) に設定しているが、envelope schema の本来の意図 (UC-2 並列協調用ディレクトリパス) と乖離
- `oe_verify_run_phase` から `ai_cli` が伝播されない (cursor ハードコード) - Plan §「未解決の細部」項目 1 の未実装
- `MARKER_TYPE=VERIFY` (後方互換用) を将来 monitor.sh が誤って case で扱うリスク → コメントで明示すべき
- 検証ペインの `wez pane capture --lines 50` で verbose な review 出力が枠外に流れる可能性
- `task.description` で skill 規約を再記述する冗長性 (F4 と矛盾)

### so-compare 結果ファイル

- `tmp/so-20260516-025239/codex-stdout.txt`
- `tmp/so-20260516-025239/claude-stdout.txt`
- `tmp/so-20260516-025239/prompt.txt`

(gitignore 対象、ローカル参照のみ)

---

## (C) F-SO 修正反映後の実装 — `4a05fe8`

so-compare 結果を user と分類した結果、以下の振り分けで対応:

- **本 PR で対応 (A グループ)**: F-SO-1, 2, 3, 4, 5, 6 + F-SO-12 (F-SO-2 の延長)
- **派生 Issue 化 (B グループ)**: F-SO-7 (Step 4-4 必須) / F-SO-8, 9 (Step 4-5 候補) / F-SO-10, 11 (MVP 後拡張)

### A グループ 7 件の修正内容

| ID | 対応 | 影響箇所 |
|----|------|----------|
| **F-SO-1** | task.description に skill 出力 → @@OE_VERIFY マッピング明示 (`Spec Compliant → pass` / `Issues Found+Critical → fail` / `Spec Compliant+advisory → warn`) | `lib/verify.sh:oe_verify_envelope_create` |
| **F-SO-2** | `OE_SCAN_EXIT_CODE` 非 0 のとき `verification_protocol_error` 監査 + KVS に `exit_code` 併記 | `lib/verify.sh:oe_verify_run_phase`、`oe_verify_write_kvs` (8 引数化)、`schemas/session-state.schema.json` (exit_code optional)、`schemas/audit-log.schema.json` (新 event type) |
| **F-SO-3** | `context.shared_kvs_path` を `null` に (envelope schema 意図と整合)、KVS パスは `read_docs` のみで参照 | `lib/verify.sh:oe_verify_envelope_create` |
| **F-SO-4** | `oe_capture_scan` に optional `lines` 引数 (デフォルト 50、検証ペインから 200 を渡す) | `lib/capture.sh:oe_capture_scan`、`lib/verify.sh:oe_verify_run_phase` |
| **F-SO-5** | `capture.sh` コメントで `MARKER_TYPE=VERIFY` は検証専用、monitor.sh の case に追加しない旨を明示 | `lib/capture.sh:_oe_capture_scan_parse` (コメントのみ) |
| **F-SO-6** | `OE_VERIFY_AI_CLI` 環境変数で検証 agent CLI 選択可能化 | `lib/verify.sh:oe_verify_run_phase`、`oe_verify_spawn` (5 引数目に伝播) |
| **F-SO-12** | `oe_verify_summary_update` で `protocol_errors` を集計 (exit_code != 0 のエントリ数) | `lib/verify.sh:oe_verify_summary_update`、`schemas/session-state.schema.json` (protocol_errors optional)、`scripts/validate-session-state.sh` |

### テスト追加

- F-SO-1: task.description 内の `Spec Compliant` / `Issues Found` / `@@OE_VERIFY:pass|fail|warn` 各キーワード検証 (5 assertions)
- F-SO-2: exit_code 記録 + 未指定時の欠落 + protocol_errors 集計 + validate-session-state.sh PASS (5 assertions)
- F-SO-3: `context.shared_kvs_path = null` (1 assertion、既存「includes target session_id」を置き換え)
- F-SO-4: `oe_capture_scan "888"` / `oe_capture_scan "888" 200` で `wez --lines` の値が変わる (2 assertions、subshell 内記録が消える bug を file 経由で回避)

test_verify.sh: 85 → 98 assertions、全 PASS。全テストスイート 293 assertions PASS (回帰なし)。

### F-SO 修正後の判定見込み (再 so-compare せず、Plan の Review 履歴セクション流儀)

| 観点 | Codex 初回 | Claude 初回 | 修正後の見込み |
|------|-----------|-------------|---------------|
| (1) AI CLI prompt | Critical | Critical | **派生 Issue #91** で Step 4-4 着手前に対応 (本 PR スコープ外) |
| (2) skill path 解決 | Concern | Concern | MVP 許容、運用昇格時に再評価 |
| (3) VERIFY/EXIT 同時検出 | Critical | Concern | **F-SO-2 で解決** (Approved 見込み) |
| (4) CB タイムアウト | Concern | Approved (条件付き) | MVP 許容、`OE_VERIFY_AI_CLI` の hook で将来チューニング可 |
| (5) shared_kvs_path | Concern | Concern | **F-SO-3 で解決** (null に修正) |
| (6) MARKER_TYPE=VERIFY 後方互換 | Concern | Concern | **F-SO-5 で解決** (コメント明示) |

ゼロベース観点で発見された Critical:

- **A. `Spec Compliant / Issues Found` → `pass/fail/warn` マッピング欠落** → **F-SO-1 で解決**
- **B. AI CLI 命令が実 CLI 仕様と不整合** → **派生 Issue #91 で Step 4-4 着手前に対応**

---

## (D) 派生 Issue 起票 + Step 4-3 ロードマップ反映

A グループ修正後に 3 派生 Issue を起票:

| Issue | 内容 | スコープ | sub-issue of #19 |
|-------|------|---------|------|
| [#91](https://github.com/stlwolf/ai-development-hub/issues/91) | F-SO-7: AI CLI 起動オプションを実 CLI 仕様 (`claude -p` / `codex -p`) に修正 | **Step 4-4 着手前必須** | ✅ |
| [#92](https://github.com/stlwolf/ai-development-hub/issues/92) | F-SO-8/9: 変更ファイル検出 per-pane 化 + 完了報告内容の充実 | **Step 4-5 候補** | ✅ |
| [#93](https://github.com/stlwolf/ai-development-hub/issues/93) | F-SO-10/11: reviewer 一時ファイル掃除 + nonce 付きマーカー偽陽性対策 | **MVP 後拡張候補** | ❌ (Refs のみ) |

これにより、本 PR を merge する時点で **「実 agent 動作可能性に懸念がある箇所」** が #91 として明示的にスケジュール化され、Step 4-4 KickOff の前提インプットとなる。

---

## 教訓 / 学び

### 1. mock テストの限界 — 「mock では通るが実 agent では動かない」失敗モード

Step 4-3 の E2E スモークは wez 完全 mock で 40 assertions が PASS する。しかし so-compare が指摘した「AI CLI 起動オプションが実 CLI と不整合」「skill load → マーカー emit の連鎖が agent good behavior に依存」は mock では検出できない。**MVP 段階で実 CLI 1 種で実 agent を 1 サイクル動かす E2E を別経路で持つ**ことが、本来 Step 4-2 / 4-3 のどこかで必要だった (現状は Step 4-4 でようやく対応予定)。

### 2. 2 段階 so-compare (Plan ドキュメント段階 → 実装段階) の有効性

Plan ドキュメント段階の so-compare (F1〜F8) は「設計の手戻り防止」に効いた。実装段階の so-compare (F-SO-1〜12) は「設計判断と実装の乖離」「ドキュメントで言及されたが実装で漏れた事項」「ゼロベースで見落とした暗黙の前提」を洗い出すのに効いた。**各段階で焦点が異なる**ため、両方やる価値がある。

### 3. ゼロベース観点指示の有効性

so-compare プロンプトで「私が flag していない設計判断・前提条件で『見落としではないか』と感じる点をすべて列挙してください」と明示したことで、私が認識していなかった **Critical: skill 出力 → @@OE_VERIFY マッピング欠落** が両者から指摘された。**reviewer に独自の批判視点を許容するプロンプト設計**が、見落とし発見の鍵。

### 4. F1〜F8 (Plan 段階) と F-SO-1〜12 (実装段階) の独立性

Plan 段階で確定した修正方針 (F4: skill prompt static copy 撤回 / F5: pane-keyed map / F6: emit 責務分離) は実装で踏襲できた。しかし新たに発見された Critical (F-SO-1, 2, 3) は **Plan 段階では見えなかった実装詳細**に起因する。**Plan レビュー → 実装レビューの 2 段階体制**は今後も維持する。

### 5. ツール間引き継ぎ (Cursor → Claude Code) の dogfood 結果

本 Step は KickOff (Cursor で起草) → Claude Code で継続作業の最初のケース。**駆動層ドキュメント (Discussion / KickOff / Plan) だけで Claude Code が継続できる**ことが実証された (実装中の追加情報要求は 1 件のみ = adversarial-review skill 内容の確認)。orchestration-engine の dogfood として有効性が確認された。

---

## 残課題 (本 PR 後)

### 直近 (Step 4-4 着手前必須)

- [#91](https://github.com/stlwolf/ai-development-hub/issues/91) AI CLI 起動オプションを実 CLI 仕様に修正
- Step 4-4 のスコープ確定 (E2E 実 agent 1 サイクル完走を Discussion → KickOff → Plan で定義)

### Step 4-5 候補

- [#92](https://github.com/stlwolf/ai-development-hub/issues/92) 変更ファイル検出 per-pane 化 + 完了報告内容の充実
- architecture-sketch.md の更新 (Step 4-3 で確定した検証ゲート設計を反映)

### MVP 後拡張候補

- [#93](https://github.com/stlwolf/ai-development-hub/issues/93) reviewer 一時ファイル掃除 + nonce 付きマーカー偽陽性対策

---

## 参照

- 駆動層ドキュメント: [Discussion](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md) / [KickOff](../plans/2026-05-15-kickoff-step-4-3-verification-gate.md) / [Plan](../plans/2026-05-15-plan-step-4-3-verification-gate.md)
- ADR (本エピソードから蒸留): [`2026-05-16-decision-verification-gate-design.md`](../decisions/2026-05-16-decision-verification-gate-design.md)
- so-compare 結果: `tmp/so-20260516-025239/` (ローカル参照)
- 派生 Issue: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) / [#92](https://github.com/stlwolf/ai-development-hub/issues/92) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93)
- 関連スキル: [adversarial-review](../../../../canonical/skills/adversarial-review/SKILL.md) / [kickoff-to-plan](../../../../canonical/skills/kickoff-to-plan/SKILL.md) / [so-compare](../../../../canonical/skills/so-compare/SKILL.md)

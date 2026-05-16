---
id: "01KRQA3H7XP50TZXHEGYJYVXTR"
title: "Step 4-3: 検証ゲート v1 アーキテクチャ — Compliance Review only + 疎結合 skill 統合 + pane-keyed KVS"
date: 2026-05-16
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/89"
    reason: "Step 4-3 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-15-discussion-step-4-3-verification-gate.md"
    reason: "QDD で 7 Q closed、本 ADR の決定根拠の正本"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-15-kickoff-step-4-3-verification-gate.md"
    reason: "DI-1〜DI-7 (Step 4-3 ローカル番号) を確定した KickOff"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-15-plan-step-4-3-verification-gate.md"
    reason: "Plan + so-compare 初回レビュー F1-F8 反映済み"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-16-episode-step-4-3-implementation.md"
    reason: "実装 + so-compare 実装段階レビュー + F-SO-1〜12 反映の実行記録"
  - type: depends_on
    ref: "DI-13"
    reason: "MVP 権限分離方針 (Step 4-1)。本決定は検証 agent の権限境界に依存"
  - type: depends_on
    ref: "DI-14"
    reason: "クリーンアップ戦略 (Step 4-1)。本決定は検証ペインを OE_VERIFY_MANAGED_PANES として cleanup に統合"
tags: [orchestration, mvp, step-4-3, decision, verification-gate, adversarial-review, skill-integration]
---

# Step 4-3: 検証ゲート v1 アーキテクチャ — Compliance Review only + 疎結合 skill 統合 + pane-keyed KVS

## コンテキスト

Step 4-2 ([PR #88](https://github.com/stlwolf/ai-development-hub/pull/88)) で `bin/oe` + `lib/*.sh` の駆動エンジンが完成した。サブエージェントの spawn、マーカー検出、KVS 書き込み、監査ログ、クリーンアップが動作する状態。

Step 4-3 の主題は **「サブエージェントの出力を別エージェントが adversarial review する仕組み」** (KickOff §「主題」)。これは MVP の核心機能の 1 つだが、設計判断の自由度が大きく、以下の論点を解く必要があった:

- 検証はいつ・どこで実行するか? (発火タイミング、起動方式)
- 検証 agent には何を渡すか? (要件、完了報告、変更ファイル)
- 検証結果の表現と保存先は? (語彙、KVS / audit log)
- 不合格時のフローは? (リトライ、エスカレーション、記録のみ)
- 既存の `canonical/skills/adversarial-review` skill との統合方針は?

加えて、本 Step は **ツール間引き継ぎ (Cursor → Claude Code)** の dogfood ケースでもあり、駆動層ドキュメントだけで作業継続できるかの検証も兼ねていた。

## 検討した選択肢 (Discussion Q1〜Q7、KickOff DI-1〜DI-7、Plan F1〜F8、so-compare F-SO-1〜12)

主要な分岐点と検討した代替案:

### Q1/DI-1: 検証モードのスコープ

- A. Plan Review のみ (kickoff-to-plan 直後のドキュメント品質チェック)
- **B. Compliance Review のみ** ← 採用
- C. 両方

### Q2/DI-2: 発火タイミング

- A. 各タスク完了ごと (per-pane)
- **B. 全タスク完了後 (end-of-session)** ← 採用 + Q2 追加決定でセッション内 fail 率を記録
- C. ハイブリッド (envelope で指定)

### Q3/DI-3: 検証 agent 起動方法

- **A. 新ペイン spawn (`lib/spawn.sh` 再利用)** ← 採用
- B. 既存ペイン再利用
- C. 同期外部コマンド

### Q4/DI-4: プロンプト構成

- A. envelope の `task.description` のみ
- **B. envelope + audit ログ + KVS の 3 ソース統合** ← 採用
- C. 自由フォーマット

### Q5/DI-5: 検証結果の表現と保存

- A. 既存 6 値 (`partial`) に集約
- **B'. KVS スキーマを最小拡張 (`verification` map + `verification_summary`)** ← 採用、Plan F5 で **pane-keyed map** に確定
- C. audit ログのみ

### Q6/DI-6: 不合格時のフロー

- **A. 記録のみ + `wez notify` で完了通知** ← 採用
- B. 自動リトライ
- C. 人間エスカレーション

### Q7/DI-7: skill 統合方針

- A. engine に skill prompt を埋め込み
- **B. envelope の `use_skills` で指定 (疎結合)** ← 採用
- C. skill 側に engine 用 entry 追加

加えて、出力パース方式は (i) skill 出力に明示マーカーをバックポート / (ii) 既存テキストを正規表現抽出 / **(iii) engine が envelope で `@@OE_VERIFY:{result}` を要求** の 3 案から **(iii)** を採用 (既存 `@@OE_EXIT:{code}` パターンと整合)。

## 決定

検証ゲート v1 を以下のアーキテクチャで実装する:

### 1. 動作モード

**Compliance Review only** (skill `adversarial-review` の Compliance Review モード)。Plan Review は engine 統合せず、必要時は人間が skill を単独起動する。

### 2. 発火タイミング

`oe_monitor_loop` 終了後 (全 `OE_DONE_PANES` 完了時のみ、CB / interrupt 時はスキップ) に **end-of-session** で発火。逐次 (per-target-pane) に検証 agent を spawn し、検証完了後にセッション集計を行う。

### 3. 検証エージェント起動

- `lib/verify.sh:oe_verify_run_phase()` 内の **独立ポーリングループ** (F1 反映) で実行
- 通常ペイン管理配列 (`OE_MANAGED_PANES` / `OE_DONE_PANES`) と分離した **`OE_VERIFY_MANAGED_PANES` / `OE_VERIFY_DONE_PANES`** を使用 (F2 反映、意味の衝突回避)
- 検証 agent ペインは `lib/spawn.sh:oe_spawn_prepare_pane` を再利用して新規生成
- AI CLI は `OE_VERIFY_AI_CLI` 環境変数 (デフォルト `cursor`) で選択可能 (F-SO-6 反映)

### 4. プロンプト構成 (engine の責務 = 構造化入力の抽出のみ)

`oe_verify_envelope_create()` が検証 envelope を生成し、以下を `task.read_docs` に含める:

1. `canonical/skills/adversarial-review/SKILL.md` (skill 本文)
2. 被検証 envelope (`/tmp/oe-{target_session_id}-envelope.json`)
3. 監査ログ (`audit/{target_session_id}.jsonl`)
4. KVS (`state/{target_session_id}.state.json`)
5. 構造化された 3 入力ファイル (`/tmp/oe-{reviewer_session_id}-verify-inputs.md`、`oe_verify_prompt_build` が生成)

`task.use_skills: ["adversarial-review"]` で skill を疎結合指定 (F4 反映、engine に skill prompt の static copy を持たない)。`task.description` には **skill 出力 → `@@OE_VERIFY` マッピング** を明示 (F-SO-1 反映):

- Spec Compliant (critical issue なし) → `@@OE_VERIFY:pass`
- Issues Found + Critical → `@@OE_VERIFY:fail`
- Spec Compliant + 非自明な Recommendations / 軽微 Issues → `@@OE_VERIFY:warn`

### 5. マーカー検出 (二値保持)

`lib/capture.sh:_oe_capture_scan_parse` を **`OE_SCAN_EXIT_CODE` + `OE_SCAN_VERIFY_RESULT` の二値保持** (F3 反映) に拡張。`@@OE_VERIFY:` と shell が後置する `@@OE_EXIT:` が同一 capture に並ぶ前提で、両方を独立に保持する。

検証ペインは verbose 出力を扱うため、`oe_capture_scan` に optional `lines` 引数を追加し検証ループから `200` を渡す (F-SO-4 反映)。

### 6. 結果の永続化

`schemas/session-state.schema.json` を以下のように拡張 (DI-5 / F5 / F-SO-2):

```json
{
  "verification": {
    "<target_pane_id>": {
      "result": "pass" | "fail" | "warn",
      "reviewer_session_id": "<ULID>",
      "reviewer_pane_id": "<int>",
      "issues_count": <int>,
      "marker_raw": "@@OE_VERIFY:<result>",
      "completed_at": "<ISO 8601>",
      "exit_code": <int>  // F-SO-2: 非 0 の場合のみ記録 (protocol error)
    }
  },
  "verification_summary": {
    "total": <int>,
    "passed": <int>,
    "failed": <int>,
    "warned": <int>,
    "fail_rate": <number>,
    "protocol_errors": <int>  // F-SO-12: exit_code != 0 のエントリ数
  }
}
```

`schemas/audit-log.schema.json` に 3 イベント追加:

- `verification_started` — Phase B (`oe_verify_spawn`) で emit (F6 反映)
- `verification_completed` — Phase D (`oe_verify_emit_completed`) で emit (F6 反映)
- `verification_protocol_error` — F-SO-2 反映、`@@OE_VERIFY:` 検出時に `OE_SCAN_EXIT_CODE` が非 0 だった場合に追加 emit

### 7. 不合格時のフロー

不合格 (result=fail) でも engine は停止しない。CB / interrupt が発動しなかった場合のみ `cleanup.sh` 末尾で `wez notify "orchestration-engine session complete"` を呼び、本文に `session_id={} verification: pass={} fail={} warn={} fail_rate={}` を展開する (DI-6 + Q2 追加決定: fail 率を実運用データとして記録)。

### 8. スコープ外 (派生課題として記録)

以下は本 Step では対応せず、派生 Issue または後続 Step に委ねる:

- **AI CLI 起動オプションの実 CLI 整合** ([#91](https://github.com/stlwolf/ai-development-hub/issues/91), Step 4-4 着手前必須)
- **変更ファイル検出の per-pane 化 + 完了報告の充実** ([#92](https://github.com/stlwolf/ai-development-hub/issues/92), Step 4-5 候補)
- **reviewer 一時ファイル掃除 + nonce マーカー偽陽性対策** ([#93](https://github.com/stlwolf/ai-development-hub/issues/93), MVP 後拡張)
- **per-pane 発火への昇格、自動リトライ、人間エスカレーション** (Step 4-4 / 4-5 の運用フィードバックで判断)
- **`human_input` audit イベント** (必要時に追加)

## 根拠

### 設計判断の主軸

- **engine の責務を「駆動 + 構造化入力の組み立て」に純粋化**: skill 規約 (Compliance Review プロンプト) と engine プロトコル (`@@OE_VERIFY:` マーカー) を分離し、skill 改訂時の追従不要を実現。skill が orchestration 統合前提で使われる頻度が増えても、engine 側に skill 内容を抱えない設計に
- **既存資産の最大再利用**: Step 4-2 の `lib/spawn.sh` / `oe_capture_scan` / `oe_audit_emit` / `oe_cleanup` をそのまま再利用、新規実装は `lib/verify.sh` に集約。設計の手戻りリスクを最小化
- **observability ファースト**: fail 率の構造化記録 (Q2 追加決定) と verification_protocol_error (F-SO-2) で、実運用での問題検出を早期に可能に。MVP の単一 UC でも、Step 4-4 / 4-5 のフィードバックフェーズで意思決定に使えるデータを残す
- **mock では検出できない実 agent 失敗モードを認識**: so-compare 実装段階レビュー (F-SO-1, F-SO-7) が指摘した「CLI 不整合」「マッピング欠落」は wez 完全 mock テストでは絶対に出ない。Step 4-4 で実 CLI 1 種を必ず通すという運用前ゲートを #91 で明示化

### Compliance Review のみ採用の理由 (DI-1)

- engine の主用途は「サブエージェントを駆動して成果物を得る」こと。Plan Review は人間が `kickoff-to-plan` 直後に手動起動する性質が強く、engine 統合の価値が薄い
- Plan Review 統合は将来 Step (4-5 以降) で必要性が見えれば追加可能なパスを残す

### pane-keyed map の理由 (DI-5 / F5)

- 単一オブジェクトでは複数 target pane の per-pane 結果を保持できない
- Q2 で確定した「セッション内 fail 率を記録」要件には複数 pane を扱える構造が必須
- `additionalProperties` パターンで JSON Schema との整合性を維持

### `use_skills` 疎結合の理由 (DI-7 / F4)

- envelope schema には Step 4-1 段階で `task.use_skills` フィールドが存在し、Step 4-2 で実装ペインに渡している実績がある
- skill prompt の static copy を engine に持たない設計により、skill の改訂が engine 側のリリースサイクルから独立する
- skill が orchestration 前提で使われるなら、skill 側の改修方針も将来 engine 統合に揃えてよい (派生課題、Step 4-4 以降で判断)

## 結果 / トレードオフ

### 得たもの

- **設計の手戻り防止**: Plan 段階の so-compare (F1〜F8) で構造的な見落としを潰し、実装段階の so-compare (F-SO-1〜12) で実装詳細の見落としを潰す 2 段階レビュー体制
- **疎結合**: skill / engine / 検証 agent の 3 者責務境界が明確 — skill は規約を持ち、engine は構造化入力を組み、検証 agent は両方を読んで判定
- **テスト網羅性**: 8 テストスイート 293 assertions PASS (mock 経由)、shellcheck クリーン、validator で schema 整合性確保
- **dogfood 成功**: ツール間引き継ぎ (Cursor → Claude Code) で駆動層ドキュメントだけで作業継続できることを実証

### トレードオフ

- **mock の限界**: 実 agent での動作確認は Step 4-4 待ち。本 Step 単独では「マージ可だが、実 agent 動作未検証」という前提を明示しないと現場で混乱しうる。Episode と本 ADR、および [#91](https://github.com/stlwolf/ai-development-hub/issues/91) で明示化
- **scope creep の抑制と spec change の境界**: KickOff §「スコープ外」で「スキーマ変更は 4-5」と明記していたが、Q5 で `verification` / `verification_summary` の最小拡張を含めると user 確認で緩和。今後の Step でも、スコープ外条件は実装上の必要性で **明示的緩和** の意思決定を残すパターンを確立した
- **`MARKER_TYPE=VERIFY` の後方互換コスト**: 将来 monitor.sh が `case "$OE_SCAN_MARKER_TYPE"` に VERIFY を追加すると誤動作する。コメント明示 (F-SO-5) で対処したが、コードレベルの enforcement (`assert` 等) はしていない。技術的負債として認識
- **CLI ハードコード残存**: `OE_VERIFY_AI_CLI` env var で選択可能化したが、デフォルト `cursor` のままで実 CLI 起動オプションが不整合 ([#91](https://github.com/stlwolf/ai-development-hub/issues/91))。Step 4-4 着手前に必ず潰す

### 観測したリスク (将来発火する可能性あり)

- **`@@OE_VERIFY:` 偽陽性**: 検証 agent が応答テキスト中で `@@OE_VERIFY:pass` を単独行で引用した場合に誤検出 ([#93](https://github.com/stlwolf/ai-development-hub/issues/93))
- **検証ペイン capture の `--lines` 不足**: 200 行に拡張したが、verbose な review 出力が押し出されるケースは依然ある。`@@OE_VERIFY` 直後に shell が `@@OE_EXIT` を後置する間に他出力が紛れ込むリスク
- **長期運用での `/tmp` 蓄積**: cleanup.sh が reviewer 一時ファイルを掃除しないため、macOS の `/tmp` が再起動まで膨張 ([#93](https://github.com/stlwolf/ai-development-hub/issues/93))

## 参照

- 駆動層ドキュメント: [Discussion](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md) / [KickOff](../plans/2026-05-15-kickoff-step-4-3-verification-gate.md) / [Plan](../plans/2026-05-15-plan-step-4-3-verification-gate.md)
- 実装エピソード: [`2026-05-16-episode-step-4-3-implementation.md`](../episodes/2026-05-16-episode-step-4-3-implementation.md)
- Step 4-3 全成果物 PR: [#90](https://github.com/stlwolf/ai-development-hub/pull/90)
- 派生 Issue: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) / [#92](https://github.com/stlwolf/ai-development-hub/issues/92) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93)
- 関連 ADR: [DI-13 権限分離](2026-05-14-decision-permission-separation-mvp.md) / [DI-14 クリーンアップ戦略](2026-05-14-decision-cleanup-strategy.md)
- 関連 skill: [adversarial-review](../../../../canonical/skills/adversarial-review/SKILL.md) (本決定が `use_skills` 経由で参照)

---
id: "01KRX1A4E8ECF9G6VG3ZX4QHEF"
title: "Step 4-4: reviewer 出力経路を wez pane capture から file redirect に変更 + skill Status → @@OE_VERIFY mapping 表の確定"
date: 2026-05-18
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/95"
    reason: "Step 4-4 Issue (本 ADR の主スコープ)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "本 ADR の決定経緯を時系列で記録した Episode"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-16-plan-step-4-4-e2e-verification.md"
    reason: "Step 4-4 Plan (Phase C.5 セクション + Phase D check_cycle 仕様)"
  - type: source_material
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md"
    reason: "wez pane capture --lines セマンティクス (viewport-only + tail) の一次資料、本 ADR の前提"
  - type: source_material
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review skill 規約 (Status / Issues / Recommendations の出力構造)"
  - type: depends_on
    ref: "2026-05-16-decision-verification-gate-design.md"
    reason: "Step 4-3 検証ゲート v1 アーキテクチャ (本 ADR は reviewer 経路の詳細を追加決定)"
tags: [orchestration, mvp, step-4-4, decision, verification, reviewer-output, file-redirect, marker-mapping]
---

# Step 4-4: reviewer 出力経路を wez pane capture から file redirect に変更 + skill Status → @@OE_VERIFY mapping 表の確定

## コンテキスト

Step 4-3 ([2026-05-16-decision-verification-gate-design.md](2026-05-16-decision-verification-gate-design.md)) で検証ゲート v1 のアーキテクチャを確定した: Compliance Review only + 疎結合 skill 統合 + pane-keyed KVS + end-of-session 発火。

Step 4-4 で実 agent (target = cursor-agent / composer-2、reviewer = claude / sonnet-4-6) を起動して 1 サイクル E2E 検証したところ、初回 smoke で reviewer の `@@OE_VERIFY` marker が engine に拾えず `verification_protocol_error` (`exit_without_verify_marker`) が発生した。本 ADR は 2 つの設計決定を確定する:

1. **reviewer の出力経路を wez pane capture から file redirect に変更**
2. **adversarial-review skill の Status → engine marker (`@@OE_VERIFY:{pass\|fail\|warn}`) の mapping を ADR レベルで固定化** (so-compare iter2 で「task.description 依存だと運用ブレ要因」と指摘されたため)

## 決定 1: reviewer 出力経路を file redirect に変更

### 検討した経路

| 案 | 概要 | 経路 | 評価 |
|---|---|---|---|
| 現状 (Step 4-3) | reviewer pane に AI CLI を `wez pane send` で起動、engine は `wez pane capture --lines 200` で polling 監視 | terminal pane buffer (viewport) | ❌ viewport-only + tail で長文時に marker が押し出される |
| 案 X | `wez pane capture` に `--start-line` (scrollback 取得) 拡張を追加 | scrollback 含む terminal buffer | △ wezterm-ai-mode 側仕様変更、2 プロジェクト跨ぐ |
| 案 Y | engine から `wezterm cli get-text --start-line -N` を直接呼ぶ | scrollback 含む terminal buffer | △ wez ラッパー抽象を一部破る、wez ソケット解決を engine が再実装 |
| **案 Z (採用)** | reviewer 送信コマンドを `( cmd ; printf @@OE_EXIT ) \| tee /tmp/oe-{rsid}-reviewer.log` 形式に変更、engine は file を tail で走査 | OS file system | ◯ terminal 経路依存ゼロ、viewport/wrap/scrollback すべて回避 |

### 採用: 案 Z

#### 送信コマンドの形式 (so-compare iter1 codex+claude 両者一致の修正案)

```bash
local log_path="/tmp/oe-${reviewer_session_id}-reviewer.log"
local base_cli_command
base_cli_command="$(_oe_spawn_build_cli_command "$ai_cli" "$ai_model" "$OE_VERIFY_ENVELOPE_PATH" "$PROJECT_DIR")"
local cli_command
cli_command="( ${base_cli_command} 2>&1 ; printf '\\n@@OE_EXIT:%d\\n' \$? ) | tee \"${log_path}\""
wez pane send "$reviewer_pane_id" "$cli_command"
```

> **後続是正（#114 / 2026-06-30）**: 上記 `tee` は共有 `/tmp` 上で既定 umask（0644・world-readable）でログを作るため、transcript（秘密情報を含み得る）の露出面がある。[#114 ADR](./2026-06-30-decision-114-clean-output-channel.md) で target/reviewer 両経路を `( umask 077 ; … | tee … )`（0600）に是正済み。本節の現行コードはその形。

- サブシェル `( ... )` 内で `$?` を読むので claude/cursor の exit code が確定 → printf に渡る
- printf も tee を経由 → log file と pane TTY の両方に書かれる
- bash の PIPESTATUS 依存が消え、zsh / busybox tee でも動作 (pane 内 shell の柔軟性確保)
- pane TTY 経路は維持されるため、人間が pane で進捗を見ることもできる

#### scan 経路 (lib/verify.sh:`_oe_verify_scan_log_file`)

```bash
_oe_verify_scan_log_file(log_path, [lines=5000])
```

- `tail -n 5000 log_path` で末尾を取得 (claude review は markdown + diff 引用で千行になり得るため 200 では不足)
- ANSI 除去 (既存 `_oe_capture_scan_parse` と同じ正規表現を再利用)
- `_oe_capture_scan_parse` に流して二値 (`OE_SCAN_EXIT_CODE` / `OE_SCAN_VERIFY_RESULT`) を設定
- file 不在時は OE_SCAN_* を空のまま return 0 (cleanup と race しても無害に継続)

#### cleanup 統合

- `OE_VERIFY_REVIEWER_SESSION_IDS` 配列 (Step 4-3 派生 #93 前半で composer-2 が実装) に `reviewer_session_id` を追加
- `lib/cleanup.sh` の同配列 cleanup ループで `/tmp/oe-{rsid}-verify-{envelope.json,inputs.md}` に加えて `/tmp/oe-{rsid}-reviewer.log` も削除

### target 側の経路は現状維持

target (cursor-agent) は `@@OE_EXIT` 1 種類だけを末尾固定で emit するため、`wez pane capture --lines 50` で visible 範囲に収まる。target を file 経路に揃えると engine 全体の変更量が増え、Step 4-4 のスコープを超える。target 側 file 統一は **派生 Issue 候補** として明示し、本 ADR の対象外とする。

### 設計上の罠と回避策 (so-compare iter1 で発覚した致命的バグ)

私の元案: `${base_cli_command} 2>&1 | tee ${log_path} ; printf '\n@@OE_EXIT:%d\n' "${PIPESTATUS[0]}"`

- bash の `;` 演算子で **`printf` が tee の外** に出てしまい、log file には `@@OE_VERIFY` のみで `@@OE_EXIT` が書かれない
- engine の二値同時検出が永久に成立せず CB timeout (30 min) まで待つ致命的バグ
- so-compare の codex + claude が **両者一致**で発見、実装着手前に修正できた

サブシェル + tee 形式 (採用案) は両者の推奨に従う。

## 決定 2: skill Status → `@@OE_VERIFY` marker mapping 表の固定化

### 背景

`canonical/skills/adversarial-review/SKILL.md` の Compliance Review prompt 規約は `Status: Spec Compliant` / `Status: Issues Found` + `Issues` (Missing / Extra / Misunderstanding) + `Recommendations` の出力構造を要求する。一方 engine プロトコルは `@@OE_VERIFY:{pass\|fail\|warn}` の 3 値。

Step 4-3 では mapping を `lib/verify.sh:oe_verify_envelope_create()` の `task.description` 末尾文字列に hard-coded していた。so-compare iter2 (codex) で「task.description 依存だと運用ブレ要因」「ADR に独立節で固定化すべき」と指摘された。本 ADR で公式 mapping を確定する。

### 公式 mapping 表

| skill 出力 Status | Issues (Critical) | Recommendations | engine marker |
|---|---|---|---|
| `Spec Compliant` | なし | trivial (任意の minor 改善) | **`@@OE_VERIFY:pass`** |
| `Spec Compliant` | なし | non-trivial (運用に影響する改善余地、複数項目、または code/spec gap の指摘) | **`@@OE_VERIFY:warn`** |
| `Spec Compliant` | minor / advisory / non-blocking のみ | (任意) | **`@@OE_VERIFY:warn`** |
| `Issues Found` | 1 件以上の Critical (Missing requirement / Extra unneeded work / Misunderstanding が機能に影響) | (任意) | **`@@OE_VERIFY:fail`** |
| `Issues Found` | minor のみ (Critical なし、誤分類) | (任意) | **`@@OE_VERIFY:warn`** (skill 利用者の誤分類を engine 側で吸収) |

### 定義

- **Critical な Issue**: skill の `Issues (if any)` セクションで以下のいずれか:
  - `Missing requirement` (タスクで要求された機能が実装されていない)
  - `Extra unneeded work` (タスクスコープ外の変更で機能に影響)
  - `Misunderstandings that affect functionality` (仕様誤解で実装が機能しない)
- **Non-trivial な Recommendations**: 以下のいずれか (今回の smoke 2 回目で `warn` 判定された根拠):
  - 複数項目 (2 件以上) の改善提案
  - F7 のような known gap への新規言及
  - 周辺コード / spec / ドキュメントの矛盾の指摘
  - 将来の派生 Issue 化を提案する内容

### 実装上の反映

`lib/verify.sh:oe_verify_envelope_create()` の `task.description` 末尾に上記表の自然言語版を埋め込む (現状実装と整合):

```text
Emit exactly one of the following on a new line at the very end, immediately before exiting:
- @@OE_VERIFY:pass — Status: Spec Compliant かつ critical issue なし、Recommendations は trivial
- @@OE_VERIFY:fail — Status: Issues Found かつ 1 件以上の critical issue (Missing / Extra / Misunderstanding が機能影響)
- @@OE_VERIFY:warn — Status: Spec Compliant + non-trivial な Recommendations、もしくは Issues は minor / advisory / non-blocking のみ
```

実装変更は本 ADR 確定時点では不要 (既に同等の文言が hard-coded されている)。将来 mapping を変更する場合は本 ADR を更新し、それから `task.description` を同期する。

### 派生 Issue 候補

- **false-positive 抑制**: reviewer が markdown の引用やコードブロック外の例示で `@@OE_VERIFY:fail` の文字列をそのまま書いた場合、現状の strict regex (`^@@OE_VERIFY:(pass\|fail\|warn)$`) は誤検出する。skill プロンプト側で「marker は必ず最後の非空行」と制約強化、or engine 側で末尾 N 行に限定 scan する派生 Issue (so-compare iter1 claude M1 指摘)
- **mapping の運用ブレ計測**: 実機運用で skill 出力と marker が乖離するケースを Episode に蓄積し、mapping 表を改訂する派生 Issue

## 帰結 (本決定の影響範囲)

- **engine**: `lib/verify.sh` (`oe_verify_spawn` 送信コマンド + 新関数 `_oe_verify_scan_log_file` + `oe_verify_run_phase` polling)、`lib/cleanup.sh` (.log 削除)、`lib/constants.sh` (`OE_VERIFY_REVIEWER_SESSION_IDS` は Step 4-3 #93 前半で追加済み、本 ADR で再利用)
- **schema**: 変更なし (`session-state.schema.json` の `verification` map は Step 4-3 で確定済み、reviewer 経路変更で構造は変わらない)
- **テスト**: `test_cleanup.sh` (+2 assertions for .log)、`test_e2e_smoke.sh` (+1 assertion for tee path + wez mock の send 経路で reviewer log を書く挙動を追加)
- **smoke**: `tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh` (env vars + shim PATH)、`tests/e2e_real_agent/bin/wez` (notify shim 新設)
- **check 系**: `check_cycle_complete.sh` で 4 + 2 点判定 (1a/1b/2/3/3.5/4)
- **target 側経路**: 変更なし (派生 Issue 候補として明示)

## 代替案を採用しなかった理由

- 案 X (`wez pane capture --start-line` 拡張): wezterm-ai-mode 側の仕様変更が必要、本 Step スコープを超える。将来 wez 側の改善余地としては有効
- 案 Y (engine から `wezterm cli` 直接呼び): wez ラッパーの抽象を破ると `wez` shim や `OE_REAL_WEZ` 探索ロジックの恩恵を失う

## 関連

- 本決定の経緯と試行錯誤の時系列: [Episode 2026-05-18](../episodes/2026-05-18-episode-step-4-4-implementation.md)
- 上位アーキテクチャ: [Step 4-3 検証ゲート v1 ADR](2026-05-16-decision-verification-gate-design.md)
- wez pane capture の一次資料: [wezterm-ai-mode ADR-004](../../../wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md)
- skill 規約: [canonical/skills/adversarial-review/SKILL.md](../../../../canonical/skills/adversarial-review/SKILL.md)

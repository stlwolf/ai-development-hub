---
id: "01KRX1A4B46V6B2JCVQMN4YDA7"
title: "Step 4-4 E2E 検証 実装エピソード (元実装 + 実機 smoke 不具合 + so-compare iter1/iter2 反映)"
date: 2026-05-18
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-4"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/95"
    reason: "Step 4-4 Issue (本エピソードの主スコープ)"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/91"
    reason: "Step 4-3 F-SO-7 派生: Step 4-4 着手前必須の AI CLI 起動オプション修正 (本 PR で Closes)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md"
    reason: "Step 4-4 Discussion (Q1-Q8 closed)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-16-kickoff-step-4-4-e2e-verification.md"
    reason: "Step 4-4 KickOff (status: confirmed、DI-1〜DI-8)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-16-plan-step-4-4-e2e-verification.md"
    reason: "Step 4-4 Plan (Phase A〜E + Phase C.5 追加、so-compare iter1/iter2 反映)"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/96"
    reason: "Discussion / KickOff / Plan の docs PR (本 PR の前提、merged)"
  - type: source_material
    ref: "projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md"
    reason: "wez pane capture --lines セマンティクス (viewport-only + tail) の一次資料"
  - type: source_material
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review prompt 規約 (envelope.use_skills 経由で reviewer に渡る)"
  - type: derived
    ref: "projects/orchestration-engine/docs/decisions/2026-05-18-decision-reviewer-output-file-redirect.md"
    reason: "本エピソードから派生する ADR (reviewer 出力経路と marker mapping の決定)"
tags: [orchestration, mvp, step-4-4, episode, implementation, so-compare, real-agent, e2e]
---

# Step 4-4 E2E 検証 実装エピソード

> Plan ([`2026-05-16-plan-step-4-4-e2e-verification.md`](../plans/2026-05-16-plan-step-4-4-e2e-verification.md)) に従って 5 Phase で実装、Phase C 実機 smoke で発覚した engine bug を Phase C.5 として挿入修正、その後 Phase D / E まで完走した記録。本エピソードは **(A) 元実装フェーズ**、**(B) 実機 smoke 不具合発覚と切り分け**、**(C) so-compare iter1 (Phase C.5 設計レビュー) + 実装**、**(D) Phase D / E 整備 + so-compare iter2 (全体レビュー)** を分離して残す。

## 概要

| フェーズ | 期間 (UTC) | 主な成果物 |
|---|---|---|
| (A) 元実装 Phase A〜C | 2026-05-17 〜 2026-05-18 03:00 | CLI dispatcher / env vars / --task-file / probe_target / probe_verify / smoke / task description / check_phase_c / Phase C target task 完遂 |
| (B) 実機 smoke で protocol_error 発覚 | 2026-05-18 03:00 〜 09:00 | `verification_protocol_error` (`exit_without_verify_marker`) 観測、claude one-shot repro で claude 自体は marker emit OK と判明 |
| (C) so-compare iter1 (codex-only) + Phase C.5 修正 | 2026-05-18 10:00 〜 16:00 | 原因確定 (wez pane capture viewport-only)、案 Z 設計 (file redirect)、so-compare iter1 で Critical 修正 (`( cmd ; printf ) \| tee` の grouping)、engine 修正 + 再 smoke で `verification_completed` emit 確認 |
| (D) Phase D 構造判定 + Phase E 整備 + so-compare iter2 | 2026-05-18 16:00 〜 17:30 | `check_cycle_complete.sh` 4 点判定 / wez shim / README、so-compare iter2 (codex 完了、claude は org limit 不在) で F-H 格下げ + check_cycle 厳密化 |

---

## (A) 元実装フェーズ — Phase A〜C

### Phase A: CLI dispatcher + env vars + --task-file (4 コミット)

- `lib/spawn.sh:_oe_spawn_build_cli_command(ai_cli, ai_model, envelope_path, [workspace])` を新設し、CLI 固有の起動オプション知識を集中化:
  - cursor-agent: `cursor-agent --print --model ${ai_model} --workspace ${workspace} --force '<prompt>'`
  - claude: `claude -p '<prompt>' --model ${ai_model} --add-dir ${repo_root} --add-dir /tmp --output-format text --no-session-persistence --max-budget-usd 1.0`
- `lib/constants.sh`: `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` / `OE_VERIFY_AI_CLI` / `OE_VERIFY_AI_MODEL` の 4 env vars (デフォルト `cursor-agent` / `composer-2` / `claude` / `claude-sonnet-4-6`)
- `lib/spawn.sh`, `lib/verify.sh` の各 spawn 関数を dispatcher 経由に統一 (F-8)
- `bin/oe` に `--task-file <path>` オプションを追加 (Markdown shell expansion 破綻を回避、F-5)
- 物理前提実機確認で claude `--add-dir` (workspace 外 skill アクセス) + `--max-budget-usd 1.0` (system prompt + skill load + envelope read + Compliance Review 出力で約 $0.045 必要) を Plan に記載 (F-4 / F-7)

### Phase B: probe (実 agent 通電確認)

- `probe_target.sh`: cursor-agent + composer-2 で `@@OE_EXIT:0` emit 確認
- `probe_verify.sh`: claude + sonnet-4-6 の 2 段確認 (emit-only / skill load via --add-dir)、両方 PASS

### Phase C: target task + smoke + check_phase_c

- `task_description_dogfood_cleanup.md` で DI-1 確定タスク (#93 前半: `OE_VERIFY_REVIEWER_SESSION_IDS` 追跡) を target に指示
- `smoke_cursor_composer_claude_sonnet.sh` で 1 サイクル E2E 実行
- `check_phase_c.sh` で構造判定 (state=success + state_change/session_end audit)
- 実機実行: composer-2 (target) が task description 通りに 3 ファイル編集 + test_cleanup.sh assertion 追加を完遂 (`fa5a5bb`)

### Phase A〜C コミット

```
2256ebe docs: Phase A Step 1 物理前提実機確認結果を Plan に追記
4c9e12b feat: Phase A — CLI dispatcher + env var 拡張 + --task-file 追加 (#91 取り込み)
3fdaeeb feat: Phase B — 実 agent spawn 通電確認 (probe_target / probe_verify)
8471df1 feat: Phase C — task description + smoke + check_phase_c (実機実行前)
fa5a5bb feat: Phase C target task — OE_VERIFY_REVIEWER_SESSION_IDS 追跡 (composer-2 実機実行成果)
```

---

## (B) 実機 smoke で `verification_protocol_error` 発覚

### 観測 (smoke 1 回目、`.tmp_smoke_20260517-184129/`)

```
03:42:22 verification_started (reviewer=claude/sonnet-4-6, pane=5)
03:44:33 verification_protocol_error (reason: exit_without_verify_marker, exit_code=0)
03:44:33 cleanup
```

- target は state=success に到達 ✅
- engine は reviewer pane を spawn したが、131 秒後に `@@OE_EXIT:0` は拾えたが `@@OE_VERIFY` が見えないまま「exit したのに marker emit せず」と判定
- KVS verification_summary: `{ total: 0, timeouts: 1 }`

### 切り分け 1: CB 過剰トリガリスクの排除 (`58d34ab`)

初回試行で `OE_CB_MAX_TURNS=10` (=20s @ 2s poll) が短すぎて target 完了前に打ち切られていたため、`lib/constants.sh` の CB を env override 可能化、smoke で `OE_CB_MAX_TURNS=600` (=20min) 設定。これは別問題で、上記 protocol_error の原因ではない。

### 切り分け 2: claude one-shot repro (`6dd2f05`)

engine / wez を経由しない claude 単体での再現スクリプト `repro_verify_protocol_error.sh` を作成:

1. 既存 smoke の audit/state を流用
2. `oe_verify_envelope_create` / `oe_verify_prompt_build` を直接呼び reviewer envelope + verify-inputs.md を smoke 同等に再構築
3. `claude -p '...'` を同じ flags で one-shot 実行、stdout 全文を `.tmp_repro_verify/` に保存

結果:
- **claude exit_code = 0**
- **`@@OE_VERIFY:warn` を独立行で emit、strict regex `^@@OE_VERIFY:(pass|fail|warn)$` に一致**
- review 内容も妥当 (composer-2 の実装は Spec Compliant、verify-inputs の git diff 不在を warn 判定)

→ **claude 自体は正常動作**。問題は **claude → wez pane → oe_capture_scan の経路** にある。

---

## (C) so-compare iter1 (原因確定 + 設計レビュー) + Phase C.5 修正

### iter1 投入 1: 仮説評価 (codex-only)

claude (CLI) の org limit リスク考慮で codex-only で投入。6 仮説 (terminal wrap / `--lines` セマンティクス / prompt 装飾 / claude 出力経路差 / capture race / ANSI 除去副作用) を評価依頼。

codex 回答 (`tmp/so-20260518-102914/codex-stdout.txt`):

- **最有力 (ほぼ確定)**: 仮説 B = `wez pane capture --lines` セマンティクス誤認
  - 公式 `wezterm cli get-text` 既定は **non-scrollback の main terminal screen**
  - scrollback は `--start-line` 負数指定で取得
  - 本リポジトリの `wez pane capture --lines N` は `get-text` 結果に `tail -n N` (`projects/wezterm-ai-mode/lib/pane.sh:416,430`、ADR-004:65)
  - つまり長文 markdown では `@@OE_VERIFY` 行が viewport 外に押し出されて拾えない
- 次点: 仮説 A (wrap で row 消費増) + 仮説 E (race / 早期誤判定)
- 棄却寄り: C / D / F (EXIT が安定検出されている事実から)

対策候補:
- 案 X: wez pane.sh に `--start-line` 拡張 → 2 プロジェクト跨ぐ
- 案 Y: engine から `wezterm cli get-text --start-line -N` を直接呼ぶ → wez ラッパー抽象を一部破る
- **案 Z**: reviewer stdout を file に redirect、engine は file を tail で走査 → terminal 経路依存ゼロ、A/B/E すべて緩和

→ user 承認: **案 Z**

### iter1 投入 2: 案 Z 設計レビュー (codex + claude)

設計詳細 (送信コマンドの quoting / PIPESTATUS / tee buffering / cleanup race / scope 等) を so に投げる。codex + claude 両者完了 (`tmp/so-20260518-110314/`)。

**Critical (両者一致)**: 私の元案 `${base_cli_command} 2>&1 | tee ${log_path} ; printf '\n@@OE_EXIT:%d\n' "${PIPESTATUS[0]}"` は bash の `;` 演算子で **`printf` が tee の外** に出てしまい、log file には `@@OE_VERIFY` のみで `@@OE_EXIT` が書かれない。engine の二値同時検出が永久に成立せず CB timeout (30 min) まで待つ致命的バグ。

両者推奨の修正:

```bash
local log_path="/tmp/oe-${reviewer_session_id}-reviewer.log"
cli_command="( ${base_cli_command} 2>&1 ; printf '\\n@@OE_EXIT:%d\\n' \$? ) | tee \"${log_path}\""
```

- サブシェル `( ... )` 内で `$?` を読むので claude/cursor の exit code 確定 → printf に渡る
- printf も tee を経由 → log file と pane TTY の両方に書かれる
- PIPESTATUS / bash 5.2 依存が消える (zsh / busybox tee でも動作)

その他の指摘:
- claude I3: `tail -n 500` は不足、`-n 5000` に
- claude I1: `claude -p \| tee` で isatty 検出が変わる (marker 検出は維持、装飾は失われる)
- claude M1: false-positive (markdown 引用の marker) — 派生 Issue 候補
- claude M2: ANSI 除去ロジック共通化 — minor

### Phase C.5 実装 (`2b5d4a2`)

- `lib/verify.sh:oe_verify_spawn`: 送信コマンドを上記 sub-shell + tee 形式に変更
- `lib/verify.sh:_oe_verify_scan_log_file(log_path, [lines=5000])`: 新設、`tail -n` + ANSI 除去 + 既存 `_oe_capture_scan_parse` 再利用
- `lib/verify.sh:oe_verify_run_phase`: polling を `oe_capture_scan` から `_oe_verify_scan_log_file` に切替 (verify のみ、target/monitor は現状維持)
- `lib/cleanup.sh`: `OE_VERIFY_REVIEWER_SESSION_IDS` cleanup ループに `.log` 削除を追加
- `tests/test_cleanup.sh`: rsid_a/b の `.log` assertion を 2 件追加 (17 → 19 PASS)
- `tests/test_e2e_smoke.sh`: wez mock の `pane send` で payload の tee path 検知時に reviewer log を書く挙動を mock 再現 (43 → 44 PASS)

### smoke 再実行 (`.tmp_smoke_20260518-034228/`、smoke 2 回目)

```
03:42:33 session_start
03:43:31 state_change success      (target 58 秒で完走)
03:43:35 verification_started
03:45:22 verification_completed    (reviewer 1 分 47 秒で完走、marker_raw=@@OE_VERIFY:warn) ✅
03:45:23 cleanup
```

- KVS verification: `{ result: warn, marker_raw: @@OE_VERIFY:warn, issues_count: 0 }`
- verification_summary: `{ total: 1, warned: 1, protocol_errors: 0, timeouts: 0 }` ✅
- **`verification_protocol_error` = 0 件**: Phase C.5 修正で完全消失

---

## (D) Phase D 構造判定 + Phase E 整備 + so-compare iter2

### Phase D: `check_cycle_complete.sh` (`20527a4`)

Plan §Phase D Step 12 の jq クエリを実装した構造判定スクリプト。引数: `target_session_id target_pane_id [data_dir]`。

判定 4 点 (so-compare iter2 で 1 点増強):
1. (1a) target session_end.state == "success" + (1b) reviewer marker_raw が strict regex 一致
2. KVS validation (validate-session-state PASS + state=success + verification[pid].result 存在)
3. audit 必須 6 種類 + CB=0 + verification_protocol_error=0 (iter2 反映で WARN → FAIL)
4. (iter2 追加) verification_summary.protocol_errors==0 && timeouts==0 直接検証
5. wez notify 呼び出し (shim 経由のみ判定可、shim 不在時 WARN)

直近 smoke に対して全 PASS (verify_result=warn、(5) は shim 配置済みなので次回 smoke から PASS)。

### Phase E Step 13: wez shim + README (`5e42de2`)

- `tests/e2e_real_agent/bin/wez`: `wez notify` 呼び出しを `${OE_MOCK_LOG_DIR}/notify.log` に記録、他は実 wez (`/Users/eddy/bin/wez` / `/opt/homebrew/bin/wez` / `/usr/local/bin/wez` 順探索、`OE_REAL_WEZ` で override 可) に exec
- smoke に `export PATH="${SCRIPT_DIR}/bin:${PATH}"` を追加
- README: 環境前提 / 構成 / 実行手順 / Phase E スキップ条件 (limited-complete 判定) / 期待コスト / トラブルシュート

### so-compare iter2 全体レビュー (codex 完了、claude は org limit 不在、`tmp/so-20260518-163243/`)

6 観点 (Phase C.5 修正の妥当性 / Plan 実装整合 / check_cycle 網羅性 / 派生 Issue 分離 / Episode 前盲点 / skill 通電品質) で投入。codex の主要指摘 2 件:

1. **要修正**: Plan F-H (target stdout capture) が smoke 未実装で、Plan ↔ check_phase_c の挙動と不整合
2. **追加検討推奨**: check_cycle で `verification_protocol_error > 0` が WARN 止まり、`verification_summary.protocol_errors / timeouts == 0` の直接検証なし

その他追加検討:
- target 側 monitor を file 経路に統一 → 将来 Issue 化
- `bin/oe --task-file` 空ファイル挙動 → 仕様明記 or exit 2 (派生 Issue 候補)
- `_oe_verify_scan_log_file` 単体テスト不在 (E2E mock で間接検証済み) (派生 Issue 候補)
- skill Status → @@OE_VERIFY mapping を ADR に独立節で固定化 (ADR で対応)

### iter2 反映 (`e583128`)

- **Plan F-H 格下げ**: F-H を「MVP では best-effort、Phase D check_cycle で代替」に変更。target 実装の正当性は GATE で人手 (`git diff` + `bash tests/test_*.sh`) で担保。smoke は変更せず、`check_phase_c.sh:88` の現状動作 (stdout file 不在なら WARN) と整合
- **check_cycle 厳密化**: protocol_error > 0 を FAIL 化 + (3.5) 新項目で verification_summary.protocol_errors/timeouts 直接検証

---

## 観察と学び

### O1. 駆動層ドキュメントだけで作業継続できた dogfood

Discussion / KickOff / Plan の 3 文書を起点に、Phase A〜C.5 〜 D 〜 E まで一貫して進めた。Plan iter (F-1〜16、F-SO-*) で頂いた指摘を反映して文書を更新するサイクルが、Cursor → Claude Code の引き継ぎでも維持できた。

### O2. 実機 smoke が engine bug を検出した

mock テスト 8 suite (合計 306 assertions) は全て GREEN だったが、実 agent (cursor-agent / claude) を起動した瞬間に `verification_protocol_error` が発生した。mock の `wez pane capture` 返り値が固定文字列 (`review output\n@@OE_VERIFY:pass\n@@OE_EXIT:0`) で 80 行内に収まるため、viewport-only セマンティクスを再現できていなかった。**E2E smoke は mock テストでは捕捉できない設計バグを検出する** — Plan Step 4-4 の目的そのものが立証された。

### O3. so-compare を 2 回挟んだ効果

- iter1 (codex-only): 原因仮説 (viewport-only) の確定と一次資料 (ADR-004) の特定が即座だった。私が立てた 6 仮説のうち最有力を 1 つに絞れた
- iter1 (codex + claude): 設計レビューで私の元案 (Critical: `; printf` が tee の外) を両者一致で発見。実装前に修正できた
- iter2 (codex のみ): Plan/実装整合の最終チェック。F-H の宙ぶらりんと check_cycle の WARN 緩さを指摘してくれた

claude は org limit でしばしば不在になったが、codex は 3 回連続で価値ある指摘を出した。

### O4. composer-2 と claude/sonnet-4-6 の振る舞い差

| 観点 | composer-2 (target) | claude/sonnet-4-6 (reviewer) |
|---|---|---|
| 起動オプション | `cursor-agent --print --model composer-2 --workspace ... --force` | `claude -p --model claude-sonnet-4-6 --add-dir <repo> --add-dir /tmp --output-format text --no-session-persistence --max-budget-usd 1.0` |
| skill / external file access | `--workspace` 内のみ | `--add-dir` で workspace 外もアクセス可 |
| 出力長 | task description ベースの編集指示に従い簡潔 (~30 秒) | Compliance Review で markdown + diff 引用込み長文 (~1 分 47 秒) |
| token / cost | Cursor サブスク内 (CLI から取得不可、Episode に N/A 明記) | 1 サイクル ~$0.04〜$0.10 |
| marker emit | task.description 末尾指示で `@@OE_EXIT` は engine が shell 後置で付与 | task.description 末尾指示で `@@OE_VERIFY:{pass\|fail\|warn}` を独立行で emit、`@@OE_EXIT` は engine が shell 後置 |
| 出力経路 | wez pane capture (viewport で十分) | file redirect (tee) (viewport 外に押し出される問題を回避) |

reviewer 側だけ file 経路に切り替えた非対称設計は、現状の出力長差から正当化される。

### O5. so-compare で発覚した Critical 設計バグ

実装着手前の so で `( cmd ; printf @@OE_EXIT ) | tee log` の grouping ミスが発見できた。実装してから smoke で検出すると `@@OE_EXIT` が log に出ない問題に振り回されて根本原因切り分けに時間がかかったはず。**実装前の so 投入は時間効率が高い**。

---

## 派生 Issue 候補 (本 PR スコープ外)

| ID | 内容 | 出典 |
|---|---|---|
| 派生 1 | target 側 monitor も file redirect に統一 (現状の非対称を解消、multi-pane 長文出力の将来対応) | so-compare iter2 codex |
| 派生 2 | `bin/oe --task-file` 空ファイル / 不在 / 不正パスのエラー仕様明記 (or exit 2) | so-compare iter2 codex |
| 派生 3 | `_oe_verify_scan_log_file` の単体テスト追加 (現状は test_e2e_smoke での間接検証のみ) | so-compare iter2 codex |
| 派生 4 | reviewer が markdown 引用で `@@OE_VERIFY:pass` を書くと strict regex に偶然一致する false-positive 対策 (skill 制約強化 or 末尾近傍 scan) | so-compare iter1 claude M1 |
| 派生 5 | `_oe_capture_scan_parse` の ANSI 除去ロジックを `_oe_strip_ansi` として共通関数化 | so-compare iter1 claude M2 |

これらは MVP の核心ではないため Step 4-5 以降または独立 Issue として扱う。

---

## 関連リンク

- Plan: [`docs/plans/2026-05-16-plan-step-4-4-e2e-verification.md`](../plans/2026-05-16-plan-step-4-4-e2e-verification.md)
- KickOff: [`docs/plans/2026-05-16-kickoff-step-4-4-e2e-verification.md`](../plans/2026-05-16-kickoff-step-4-4-e2e-verification.md)
- Discussion: [`docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md`](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md)
- ADR (本エピソードから派生): [`docs/decisions/2026-05-18-decision-reviewer-output-file-redirect.md`](../decisions/2026-05-18-decision-reviewer-output-file-redirect.md)
- so-compare iter1 仮説評価: `tmp/so-20260518-102914/codex-stdout.txt`
- so-compare iter1 設計レビュー: `tmp/so-20260518-110314/{codex,claude}-stdout.txt`
- so-compare iter2 全体レビュー: `tmp/so-20260518-163243/codex-stdout.txt`
- 実機 smoke 証跡 (1 回目、protocol_error): `tests/e2e_real_agent/.tmp_smoke_20260517-184129/` (smoke 後 cleanup で /tmp は消えるが KVS/audit は残存)
- 実機 smoke 証跡 (2 回目、verification_completed): `tests/e2e_real_agent/.tmp_smoke_20260518-034228/`
- wezterm-ai-mode ADR-004 (`--lines = tail` 仕様): [`projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md`](../../../wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md)

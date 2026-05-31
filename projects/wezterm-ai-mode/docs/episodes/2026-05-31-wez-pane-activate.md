---
id: 01KSYJFT2B17G4AX883W0PJ214
title: "wez pane activate 実装エピソード（#111 フォーカス奪取対処）"
date: 2026-05-31
type: episode
status: stable
related:
  - type: implements
    ref: ../plans/2026-05-31-plan-wez-pane-activate.md
    reason: "本エピソードが実装したプラン"
  - type: depends_on
    ref: ../decisions/ADR-004-pane-design-decisions.md
    reason: "pane サブコマンドの引数規約・exit code 体系を踏襲"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/111"
    reason: "#111 の解決実装"
tags: [wez, cli, pane, activate, focus, bash, episode]
keywords: [wezterm, activate-pane, no-focus, split-pane, WEZTERM_PANE]
use_when:
  - "wez pane activate の設計判断・実装経緯を確認するとき"
  - "split 後のフォーカス制御の根拠を辿るとき"
---

# wez pane activate 実装エピソード（#111）

## 背景・目的

統括 Claude Code セッションのペインから `wez pane split` で捕捉用ペインを作ると、フォーカスが新ペインへ移り、ユーザーの許可プロンプト応答が新ペインへ流れてオーケストレーションが詰まる（[#111](https://github.com/stlwolf/ai-development-hub/issues/111)、#105 Phase 5 / #109 oe-capture dogfood で発見）。`wez pane activate <pane_id>` を追加し、`split → activate <元ペイン>` の合成でフォーカスを復帰できるようにする。

## 実装内容

- `lib/pane.sh`: `_wez_pane_activate`（`wezterm cli activate-pane --pane-id <ID>` の薄いラッパー）を追加。既存 `_wez_pane_kill` を 1:1 で模倣
- dispatcher `wez_cmd_pane` の `case` に `activate)` を配線、`_wez_pane_help` と `bin/wez` トップレベル help に `activate` を追記
- `README.md` に `wez pane activate` セクション + 使用例 + サブコマンド一覧を追記

## 設計判断

### DJ-A: pane-id 必須

`wezterm cli activate-pane` の native default は `WEZTERM_PANE` だが、既存 `send`/`capture`/`kill` がすべて pane-id 必須のため、一貫性を優先して **必須**にした。#111 のユースケース（split 後に元ペイン id を明示指定して戻す）は明示 id 指定なので支障なし。plan peer-ai-review で Codex も「呼び出し元の再現性が高い／本リポジトリに YAGNI 前例」として同意。

### DJ-B: 失敗時 exit code マッピング（実測で確定）

Step 0 で `wezterm cli activate-pane --pane-id 999999`（存在しない）を実測 → `exit 1` + stderr `Error: pane 999999 not found`。これを受け、`send`/`kill` 同型で「失敗時 `_wez_pane_exists` 再確認 → 無ければ `3 (PANE_NOT_FOUND)`、存在し操作失敗なら `5 (OP_FAILED)`」を採用。`wez pane activate 999999` で `exit 3` を確認済み。

### `--no-focus` 不採用と ADR 昇格判断

`wez pane split --no-focus` 案は採らなかった。理由:

- インストール済み `wezterm 20240203-110809-5046fc22` の `wezterm cli split-pane --help` に `--no-focus` native flag が**存在しない**（`--pane-id/--horizontal/--left/--right/--top/--bottom/--top-level/--cells/--percent/--cwd/--move-pane-id` のみ）。実測で確認。
- エミュレートするには split 内部で「split → 元ペインへ activate」を行う必要があり、focus flicker + split の単一責務違反を招く。
- `activate` を独立サブコマンドにすれば既存パターンと同型で、合成により同目的を達成できる（ADR-006「CLI 側で完結」方針とも整合）。

**ADR 昇格判断 → エピソード完結（ADR 化せず）。** CONVENTIONS の ADR 基準には「明示的にやらないと決めた → ADR」があり `--no-focus` 不採用は文言上触れるが、本件は upstream に native flag が無く実質強制された選択で、新規アルゴリズム・構造的トレードオフを持たない（既存 ADR-003/006 のような深さがない）。**「最初から ADR 化せずエピソード優先、非自明なフォークが出た場合のみ昇格」をユーザーと事前合意済み**。実装中に非自明なフォークは発生しなかったため、本エピソードで完結させる。

## peer-ai-review（gate）

- **プランレビュー（Stage 1）**: `tmp/peer-review-20260531-155929/`（so-compare `tmp/so-20260531-160031/`、Codex 84s / Claude 164s）。3者が方向性に同意。両 SO が一致して指摘した「Step 3 コードレビュー gate 条件の『手元 E2E pass』が Step 4(E2E) より前」という順序矛盾をプラン改訂（Step 3=E2E / Step 4=コードレビュー）で解消。
- **実装後コードレビュー（Step 4）**: so-compare `tmp/so-20260531-172444/`（Codex 38s / Claude 136s）。CRITICAL なし・出荷可能で合意。INFORMATIONAL 2件を修正:
  - `bin/wez` トップレベル help に `activate` 漏れ（Codex 指摘・grep 検証済み）→ 追記
  - activate help の "not both" 文言が順序依存の実装（兄弟コマンド共通）と食い違う（Claude 指摘）→ 文言を実態に合わせて緩和

## 検証結果

- `shellcheck lib/pane.sh bin/wez`: CLEAN（exit 0）
- 非 focus E2E（実機・live socket `gui-sock-38784`）: `wez pane --help`/`activate --help` 表示 ✓、非存在 id → `exit 3` ✓、`--socket` 経由（2段パース）→ `exit 3` ✓、pane-id 必須/too many args/invalid id → `exit 64` ✓
- **未実施（明示スキップ）**: split→activate の**フォーカス復帰の実機目視**、`--json` 成功出力、非 json 成功時の空 stdout。理由: 作業セッション中にライブ GUI のフォーカスを奪う操作を避けるため、ユーザー判断でスキップ。コアの focus 復帰は native `wezterm cli activate-pane` に委譲する薄いラッパーであり、成功パスのコードは `kill`（検証済み）と同一構造。残るリスクは VERIFICATION_MATRIX A-2-8 に PARTIAL として記録。

## 成功基準の突合（プラン）

| 成功基準 | 状態 |
|---------|------|
| `activate <pane-id>` がフォーカスを移す | コードは native 委譲・error path 検証済み（成功 path の実機 focus 目視は未実施） |
| `--pane-id <ID>` でも同動作 | ✓（引数パーサ共通） |
| 存在しない id → exit 3 | ✓ 実測 |
| `--json` 出力 | コード確認済み（実機成功出力は未実施） |
| split→activate でフォーカス復帰 | 未実機検証（スキップ・上記理由） |
| shellcheck 通過 | ✓ |
| `--help` に activate 表示 | ✓ |
| README 記載 | ✓ |

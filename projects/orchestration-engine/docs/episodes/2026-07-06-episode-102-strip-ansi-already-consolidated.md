---
id: "01KWTWVSCJRFF519SKB291E2FG"
title: "#102 _oe_strip_ansi 共通関数化は #114 で既に解消済み（実装対象消失・コード変更なしでクローズ）"
date: 2026-07-06
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/102"
    reason: "本 episode が closure する対象 Issue（保守性向上・DRY 化）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP（#102 の親）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-06-30-episode-114-clean-output-channel.md"
    reason: "#114 が scan を _oe_scan_log_file に一本化し重複を解消した（consolidation 元）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "Step 4-4（#97）で verify.sh に ANSI 除去がインライン複製され #102 が派生候補 5 として起票された起点"
---

# #102 の前提は #114 で消失していた

reconstructed（作業完了直後に締めで記述。リアルタイム追記ログではない）。

## Context / なぜ

#102 は「`lib/capture.sh` と `lib/verify.sh` に重複してインライン実装された ANSI エスケープ除去ロジックを共有関数 `_oe_strip_ansi` に抽出する（DRY 化）」という 1-PR 機械的リファクタとして起票された。実装に着手する前に kickoff の grounding 指示どおり「両ファイルの重複ブロックを grep で特定」したところ、**重複が既に存在しない**ことが判明した。

## わかったこと（W）

ANSI 除去の重複は、#102 とは別動機の後続 PR によって既に解消されていた。タイムライン:

1. **#97（Step 4-4）**: `lib/verify.sh:_oe_verify_scan_log_file` が新設され、`tail -n` + ANSI 除去 + `_oe_capture_scan_parse` 再利用を**インライン実装**した（→ `capture.sh` 側と同一の CSI 除去 sed が二重化）。出典: `projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md:176`
2. **#102 起票**: 上記の重複を DRY 化する「派生 Issue 候補 5」として起票。出典: 同 episode `:284`
3. **#114（クリーン取得チャネル一本化）**: log 走査の共通コア `lib/capture.sh:_oe_scan_log_file` を新設し、`_oe_verify_scan_log_file` を**共通コアへ委譲する薄いラッパ**に置換。出典: `projects/orchestration-engine/docs/episodes/2026-06-30-episode-114-clean-output-channel.md:63-64`

結果、現在の実体は以下（`[verified]`・コード直読）:

- ANSI 除去は `lib/capture.sh:29` の `_oe_normalize_capture_output()` **1 箇所のみ**（CR + CSI + 全角空白/NBSP を畳む）。
- capture 経路（`oe_capture_scan`, `capture.sh:51`）と verify 経路（`_oe_verify_scan_log_file` → `_oe_scan_log_file`, `verify.sh:572-574` → `capture.sh:98`）が**同一関数を通る**。
- `verify.sh` 自身にインライン ANSI 除去は**存在しない**。
- `tests/test_capture.sh:308-311` が `_oe_normalize_capture_output` の「ANSI 除去」「CR 除去」を既にカバー。

つまり #102 が挙げた risk「片方を直すと他方が古いまま」は、コピーが 1 本化されたことで**構造的に消滅済み**。DRY 目的は別名（`_oe_normalize_capture_output`）で既達。

## 決定と根拠

**決定: コード変更なしで #102 を obsolete（解消済み）としてクローズ。** ユーザー（本子セッションで直接確認）が選択。

棄却した代替案と理由:

- **リテラルに `_oe_strip_ansi` を新設**: caller は既に単一（`_oe_normalize_capture_output`）のため DRY 効果ゼロの cosmetic rename。むしろ統合済み関数を分割する退行になり、kickoff のゲート「挙動不変・機械的リファクタ」に反する。
- **DRY 対象を `capture.sh`(sed) ↔ `sanitize.sh`(jq) に再解釈**: 同一 CSI 正規表現 `\x1b\[[0-9;?]*[ -/]*[@-~]` が今も 2 ファイルに残るのは事実だが、sed と jq のエンジンをまたぐため単一 bash 関数へ抽出できない。`sanitize.sh`（#224）は多段 jq pipeline の 1 段（tag-neutralize/box/court/truncate）を単一パスで処理する設計であり、ANSI 段だけ外出しすると設計を崩す。「機械的・挙動不変」ではなく設計変更＝ #102 のスコープ外。

## 原則（Anti-pattern / Pattern 対）

- **Anti-pattern**: 起票時点で正確だった Issue/kickoff の前提を、着手時に現行ソースへ照合せず実装に入る。別動機の後続 PR（ここでは #114 の取得チャネル一本化）が対象を silent に消滅させていることがある。
- **Pattern**: 「1-PR 機械的リファクタ」でも、着手前に kickoff の grounding 指示（grep で対象特定）を必ず実行し、前提を現行ソースで再検証してから実装可否を判断する。前提消失は失敗ではなく正当な closure（no-op）として扱う。

## 蒸留シグナル

- 昇格候補: **negative knowledge**（→ #62 消費者側）候補あり — 「Issue 前提の drift を着手前 grounding で検出する」。ただし既存の `behavioral-rule §1 Evidence First` / `exhaustion-before-conclusion-rule` / kickoff の grounding 指示で実質カバーされており、新規 rule 化までは要さない（**昇格は保留・候補として記録のみ**）。
- Decision / skill 昇格: **なし**。

## 残課題（routing 付与）

- `capture.sh`(sed) と `sanitize.sh`(jq) に同一 CSI 正規表現が残存する件 → **別 follow-up 候補**（設計変更を伴うため #102 とは別 Issue が妥当）。本 episode では**実装しない・自動起票しない**。起票要否は人/親の判断に委ねる（Minimal Scope・委譲子はスコープ拡張しない）。
- 実装 SO（oe-review）省略判断: **実装が発生しなかったため moot**（レビュー対象コードなし）。kickoff の「省略判断を明記」要求を本行で充足。

## status 確定

- episode status: `stable`（確定した記録）。
- 達成度: **達成**（前提消失を確定し、コード変更不要と結論。#102 の DRY 目的は既達）。
- 対象 Issue #102 の扱い: obsolete（クローズは人/親が実施。本子はマージ・掃除・クローズをしない）。

## Step4 辞退（heavy tier・条件付き辞退）

Step4 辞退: 実装ゼロ・実行ログに失敗/撤回/指摘なし（選択的省略の対象が存在しない）。証拠は全て永続アンカー（`file:line` + Issue/PR番号 + episode パス）で `tmp/` 揮発参照なし。closure 品質 4 観点を既存グラウンディング（コード直読 + git log + #114/#step-4-4 episode）で機械確認可能と判断 / 既存チェックで覆った観点: routing / evidence anchor / 省略チェック / back-propagation（#102 クローズ自体が反映） / 未実施観点と判断: なし

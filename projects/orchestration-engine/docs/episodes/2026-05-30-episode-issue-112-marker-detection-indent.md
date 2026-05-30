---
id: "01KSWPBTE6F5JBHGNM0RJQ65KD"
title: "Issue #112 実装エピソード — マーカー検知の TUI 字下げ対応（regex 緩和 / Part 1）"
date: 2026-05-30
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/112"
    reason: "本 Episode の対象 Issue（Part 1 を実装し本 Issue をクローズ）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-26-episode-issue-109-oe-capture-attach.md"
    reason: "発見元の #109 ライブ dogfood（対話 Claude Code TUI 字下げで marker 取り逃し）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/issues/114"
    reason: "本 Issue Part 2（クリーン出力チャネル方針）を切り出した独立 Issue"
tags: [orchestration, phase-5, issue-112, episode, oe-capture, marker, regex, tui]
---

# Issue #112 実装エピソード — マーカー検知の TUI 字下げ対応（Part 1）

## 概要

#109 oe-capture のライブ dogfood（2026-05-26, #105 Phase 5）で、対話 Claude Code TUI への marker 検知が失敗していた。claude は `pong` + `@@OE_EXIT:0` を正しく出力したが、TUI が応答本文を字下げするため行が `  @@OE_EXIT:0`（先頭空白2）になり、行頭・行末完全一致の `OE_EXIT_MARKER_RE` が拾えなかった。本 Episode は Issue 本文の **Part 1（regex 緩和）** を実装し、観測された字下げケースを通せるようにした。**Part 2（クリーン出力チャネルによる scrape 脱却）は #114 として独立切り出し**、本 Issue はクローズ。

## 何を変えたか

| ファイル | 種別 | 内容 |
|---|---|---|
| `lib/constants.sh` | 改修 | `OE_EXIT_MARKER_RE` / `OE_VERIFY_MARKER_RE` を `^[[:space:]]*…[[:space:]]*$` に緩和（先頭/末尾空白許容、行末アンカー維持）。`@@OE_BLOCKED` の stale コメント訂正 |
| `lib/capture.sh` | 改修 | `@@OE_BLOCKED` regex を `^[[:space:]]*@@OE_BLOCKED([[:space:]]*$\|:.*$)` に緩和（末尾空白許容で EXIT/VERIFY と対称化、SO 指摘）。正規化を `_oe_normalize_capture_output()` に抽出し U+3000/NBSP→ASCII 空白の畳み込みを追加（ロケール依存解消、SO 指摘） |
| `lib/verify.sh` | 改修 | `_oe_verify_scan_log_file` の正規化を共通ヘルパー呼び出しに変更。log-file 経路だけ字下げ marker がロケール依存で残る取りこぼしを解消（Copilot 指摘） |
| `tests/test_capture.sh` | 改修 | #112 セクション追加。マッチ: 字下げ/タブ/末尾空白 EXIT・字下げ BLOCKED+EXIT・字下げ VERIFY・末尾空白 BLOCKED・CR+字下げフルパイプ・U+3000/NBSP 正規化。非マッチ: 字下げエコー・marker 後テキスト・引用/リスト glyph・ボックス装飾・コロン直後スペース・VERIFY エコー・後続英字 BLOCKED |

## 設計判断（確定）

- **行末アンカーを維持して誤検知を防ぐ**: 同じペインにはプロンプト文中のマーカー文字列もエコーされる（例「正確に `@@OE_EXIT:0` とだけ出力…」）。`[[:space:]]*$` で末尾は空白のみ許容＝「マーカー後に非空白テキストが続く行」は非マッチとなり、エコー行を除外できる。既存テスト「行途中のマーカーは無視」の延長で担保。
- **先頭は空白のみ許容（任意文字の prefix は許容しない）**: `^[[:space:]]*` に限定。`prefix @@OE_EXIT:0` のような行途中マーカーは引き続き非マッチ。観測された TUI 字下げ（空白・タブ）のみを救済する最小緩和。
- **regex 緩和は scrape 経路の小パッチという位置づけ**: ボックス装飾（`│ @@OE_EXIT:0 │`）・行折返し・viewport-only など screen-scrape の本質的脆さはこの緩和では救えない。根治は #114（クリーン出力チャネル）に委ねる。
- **全角空白 U+3000 / NBSP はロケール依存のため正規化で根治（SO 指摘）**: `[[:space:]]` のマルチバイト空白判定は環境依存（実機で `ja_JP.UTF-8`=MATCH / `LC_ALL=C`=NOMATCH を再現）。regex 側でなく正規化(sed)で U+3000/NBSP を ASCII 空白へ畳み、parse 前に環境差を消す。CR・ANSI 除去と同じ層に置く設計。
- **正規化を共通ヘルパー `_oe_normalize_capture_output()` に集約（Copilot 指摘）**: 正規化 sed が `oe_capture_scan`（capture 経路）と `_oe_verify_scan_log_file`（verify の log-file 経路）に複製されており、capture 側だけ U+3000/NBSP 畳みを足すと verify 経路に取り残しが残る。複製が今回のバグの根本原因のため、ヘルパーに集約して両経路から呼び、経路間ドリフトを防ぐ。
- **単独行マーカーのエコーは regex で区別不能（既知限界、トレードオフ明記）**: プロンプトが `@@OE_EXIT:0` を単独行で復唱すると本物と同形になりマッチする。先頭緩和でこの露出が「列0」→「字下げ込み」にわずかに拡大した。行末アンカーで「marker 後に非空白が続くインラインエコー」は除外できるが、単独行エコーは原理的に scrape では識別不能で #114（プロトコル側: 署名 / sentinel block / 直近N行限定等）の領域。

## ゲート結果

| ゲート | 内容 | 結果 |
|---|---|---|
| G1 | `shellcheck lib/constants.sh lib/capture.sh lib/verify.sh` | CLEAN |
| G2 | 全 mock suite（`tests/test_*.sh`） | ALL GREEN（capture=102 / verify=104 ほか FAIL=0） |
| G3 | ロケール非依存確認 `LC_ALL=C` で capture / verify | PASS 一致 / FAIL=0 |
| G4 | SO ゲート `so-compare`（Codex + Claude）→ 指摘反映・再検証 | BLOCKED 末尾空白取りこぼし修正 / U+3000 ロケール依存を正規化で根治 / コメント訂正 / 負例追加 |
| G5 | Copilot レビュー反映 | verify log-file 経路の正規化漏れを共通ヘルパー集約で根治（コミット 1ffb673） |

### G4 SO ゲートで検出・修正した穴（2者）

- **Codex**: `@@OE_BLOCKED   `（末尾空白のみ）が `($\|:.*$)` で取りこぼし＝EXIT/VERIFY と非対称。bash で再現確認し `([[:space:]]*$\|:.*$)` に修正。
- **Claude**: 全角空白 U+3000 字下げが `[[:space:]]` のロケール依存で割れる未定義動作。「スコープ外でなく #112 で定義を確定すべき」との指摘を受け、正規化で根治（上記設計判断）。あわせて「確実に除外」表現の過大さ（単独行エコー）・`capture.sh`/`constants.sh` の stale コメント・テスト負例不足を指摘。
- 反映済み: 上記2件の修正 + コメント正確化 + 負例テスト（glyph/引用・コロン直後スペース・VERIFY エコー・CR+字下げ・U+3000/NBSP）。
- #114 へ委譲（regex で解けない）: 単独行エコーの識別、glyph/引用/box プレフィックス、行折返し分断。

## スコープ外（本 Issue では未対応 → #114）

- ボックス装飾 `│ @@OE_EXIT:0 │`・行折返し・TUI 再描画・viewport-only に起因する取り逃し（regex 緩和では救えない）
- 非対話 `claude -p` + 構造化出力 + file-redirect を基本経路とする方針（Part 2）。#98（target 出力 file-redirect 統一）と方向一致

## 関連
- [Issue #112](https://github.com/stlwolf/ai-development-hub/issues/112)（本 Episode の対象、Part 1 でクローズ）
- [Issue #114](https://github.com/stlwolf/ai-development-hub/issues/114)（Part 2 独立切り出し）/ [Issue #98](https://github.com/stlwolf/ai-development-hub/issues/98)（file-redirect 統一）
- 発見元: #109 ライブ dogfood Episode `docs/episodes/2026-05-26-episode-issue-109-oe-capture-attach.md`
- Part 2 設計メモ: `docs/discussions/2026-05-30-discussion-clean-output-channel-for-orchestration.md`

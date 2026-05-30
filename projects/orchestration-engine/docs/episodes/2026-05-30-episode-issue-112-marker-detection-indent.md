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
| `lib/constants.sh` | 改修 | `OE_EXIT_MARKER_RE` / `OE_VERIFY_MARKER_RE` を `^[[:space:]]*…[[:space:]]*$` に緩和（先頭/末尾空白許容、行末アンカー維持） |
| `lib/capture.sh` | 改修 | `@@OE_BLOCKED` インライン regex を `^[[:space:]]*@@OE_BLOCKED($\|:.*$)` に緩和（理由テキストの後置は従来どおり許容） |
| `tests/test_capture.sh` | 改修 | #112 セクション追加（字下げ EXIT / タブ字下げ / 末尾空白 / 字下げ BLOCKED+EXIT / 字下げ VERIFY のマッチ、字下げエコー・marker 後テキストの非マッチ） |

## 設計判断（確定）

- **行末アンカーを維持して誤検知を防ぐ**: 同じペインにはプロンプト文中のマーカー文字列もエコーされる（例「正確に `@@OE_EXIT:0` とだけ出力…」）。`[[:space:]]*$` で末尾は空白のみ許容＝「マーカー後に非空白テキストが続く行」は非マッチとなり、エコー行を除外できる。既存テスト「行途中のマーカーは無視」の延長で担保。
- **先頭は空白のみ許容（任意文字の prefix は許容しない）**: `^[[:space:]]*` に限定。`prefix @@OE_EXIT:0` のような行途中マーカーは引き続き非マッチ。観測された TUI 字下げ（空白・タブ）のみを救済する最小緩和。
- **regex 緩和は scrape 経路の小パッチという位置づけ**: ボックス装飾（`│ @@OE_EXIT:0 │`）・行折返し・viewport-only など screen-scrape の本質的脆さはこの緩和では救えない。根治は #114（クリーン出力チャネル）に委ねる。

## ゲート結果

| ゲート | 内容 | 結果 |
|---|---|---|
| G1 | `shellcheck lib/constants.sh lib/capture.sh` | CLEAN |
| G2 | `bash tests/test_capture.sh`（#112 新規ケース + 既存回帰） | PASS=80 / FAIL=0 |

## スコープ外（本 Issue では未対応 → #114）

- ボックス装飾 `│ @@OE_EXIT:0 │`・行折返し・TUI 再描画・viewport-only に起因する取り逃し（regex 緩和では救えない）
- 非対話 `claude -p` + 構造化出力 + file-redirect を基本経路とする方針（Part 2）。#98（target 出力 file-redirect 統一）と方向一致

## 関連
- [Issue #112](https://github.com/stlwolf/ai-development-hub/issues/112)（本 Episode の対象、Part 1 でクローズ）
- [Issue #114](https://github.com/stlwolf/ai-development-hub/issues/114)（Part 2 独立切り出し）/ [Issue #98](https://github.com/stlwolf/ai-development-hub/issues/98)（file-redirect 統一）
- 発見元: #109 ライブ dogfood Episode `docs/episodes/2026-05-26-episode-issue-109-oe-capture-attach.md`
- Part 2 設計メモ: `docs/discussions/2026-05-30-discussion-clean-output-channel-for-orchestration.md`

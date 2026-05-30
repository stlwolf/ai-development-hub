---
id: "01KSWPBTEY6Y5S2CQ5F6KNDDK0"
title: "orchestrate 対象のクリーン出力チャネル統一方針（scrape 脱却）— 探索メモ"
date: 2026-05-30
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/114"
    reason: "本 Discussion を観測層で追跡する独立 Issue（Part 2）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/issues/112"
    reason: "発見元 Issue（Part 1=regex 緩和は実装・クローズ済み、本メモは Part 2）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/issues/98"
    reason: "target 出力 file-redirect 統一。本方針の target 経路における具体実装に当たる"
tags: [orchestration, phase-5, issue-114, discussion, capture, clean-channel, scrape, file-redirect]
---

# orchestrate 対象のクリーン出力チャネル統一方針（探索メモ）

> status: draft。本メモは #112 クローズ時に Part 2 を駆動層に残す**種**。実際の KickOff → Plan → 実装は別スレッドで立ち上げる前提。ADR には未昇格（大きな設計判断として確定したら昇格を検討）。

## 課題

`wez pane capture` による非所有ペインの覗き見は本質的に脆い。Part 1（regex 緩和, #112）は観測された TUI 字下げ `  @@OE_EXIT:0` には効くが、以下はいずれも救えない:

- ボックス装飾 `│ @@OE_EXIT:0 │`
- 行折返し / TUI 再描画 / viewport-only

「マーカーはどんな形であれ取れる」を満たすには、スクレイプでなくクリーンな出力チャネルが要る。

## なぜ scrape は本質的に脆いか

- **Cursor/Claude Code が確実な理由**: 親プロセスとして子の PTY/パイプを所有し生バイトストリームを源で読む。one-shot なら stdout はクリーンテキスト。
- **oe-capture が脆い理由**: 非所有ペインを `wez pane capture` で覗く＝WezTerm が解釈・描画済みの 2D グリッドを返す（生ストリームでない）。
- **OS API の壁**: 非所有プロセスの stdout 直読は原則不可。クリーンに取る道は (a) 所有（子として PTY 付き起動） か (b) 協調（出力を file redirect させて読む） の 2 つ。
- **対話 TUI の本質**: 生ストリームを取れても対話 TUI 出力は制御コード列でクリーンテキストでない。クリーンテキストは構造化/print モード（`claude -p --output-format`）でのみ得られる。対話 TUI は人間用で機械可読チャネルではない。

## 方針案

- orchestrate 対象タスクは **「非対話 `claude -p` + 構造化出力」を基本**とし、その stdout を **所有 or file-redirect してクリーンに取る**。
- TUI scrape は人間補助の補完に留める。
- engine の `claude -p` dispatch + file-redirect 経路の方向と一致。

## #98 / #114 との関係

- **#98**（target 出力を file redirect 経路に統一）= 本方針の **target 経路における具体実装**。reviewer は PR #97 で既に file-redirect 化済み、target 側が未統一で経路の非対称性が残る。
- **#114**（本メモの観測層 Issue）= 方針レベルのトラッキング。
- 別スレッドで駆動層を立ち上げる際の論点:
  - 非対話 + file-redirect を「基本経路」として明文化（ADR 化の検討タイミング）
  - 対話 Claude Code TUI を orchestrate する場合の残課題（別チャネル: セッションログ / フック等）の切り分け

## 関連
- [Issue #114](https://github.com/stlwolf/ai-development-hub/issues/114) / [Issue #112](https://github.com/stlwolf/ai-development-hub/issues/112) / [Issue #98](https://github.com/stlwolf/ai-development-hub/issues/98)
- Part 1 Episode: `docs/episodes/2026-05-30-episode-issue-112-marker-detection-indent.md`

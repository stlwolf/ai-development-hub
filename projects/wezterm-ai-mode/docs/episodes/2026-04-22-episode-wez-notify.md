---
id: "01KPT49WWP05M91AN9NRMGC4QS"
title: "wez notify サブコマンド実装（Issue #30）"
date: 2026-04-22
type: episode
status: draft
related:
  - type: implements
    ref: ../plans/2026-04-22-kickoff-wez-notify.md
    reason: "キックオフに基づく実装"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/30"
    reason: "feat(wez): notify サブコマンド + Lua 統合方針確定（1-3）"
  - type: spawns
    ref: ../../../../docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md
    reason: "事前検証の TTY 発見プロセスから仮説駆動探索の再現性 discussion を派生"
tags: [notify, implementation, so-compare, tty-direct-write, hypothesis-driven]
---

# wez notify サブコマンド実装（Issue #30）

## 概要

Issue #30 として `wez notify` サブコマンドを実装。OSC 1337 SetUserVar 経由で WezTerm にデスクトップ通知を送信する機能。Phase 1 は CLI のみ、Lua 統合は Phase 2 で dotfiles リポジトリに実装予定。

---

## 1. 事前検証（2026-04-22）

### 設計判断: 送信方式の選定

Issue の背景にあった PoC-04 は、`printf` コマンド文字列を `wezterm cli send-text` でペインに送り、シェルに実行させて OSC を発生させる方式（command string）。副作用として history 汚染・プロンプト状態依存がある。

初期フレーミングでは以下の2択で検討を開始:

| 選択肢 | 方式 | 想定 |
|--------|------|------|
| A | command string（PoC 踏襲） | 実績あり。副作用は Phase 2 で対処 |
| B | raw OSC を `send-text` で直接送信 | 副作用なし。未検証 |

### option B の実機検証 → NG

```bash
printf '\033]1337;SetUserVar=ai_notify=%s\007' "$(printf 'Test|Body|5000' | base64 | tr -d '\n')" \
  | wezterm cli send-text --pane-id 0 --no-paste
```

結果: ペインのシェルに `q1337;SetUserVar=...` が可視テキストとして入力され、`command not found` エラー。

原因: `send-text` は PTY **入力**（キーボード側）にバイトを書き込む。WezTerm のターミナルエミュレータが OSC を解釈するのは PTY **出力**（プロセスの stdout）のみ。ESC（`\033`）がシェルの readline に消費され、残りが通常のテキスト入力として処理された。

### option A での「確定」

option B が原理的に不可であることを確認し、option A（command string）で一旦確定。キックオフに検証結果を反映。

### SO ゼロベースレビュー → option C の発見

確定後に `so-compare` でキックオフ全体の設計レビューを実施。プロンプトで「ゼロベースで他の選択肢がないか検証して」と明示的に依頼。

Claude の回答から **option C: TTY 直接書き込み** が提案された。`wezterm cli list --format json` の `tty_name` フィールド（`/dev/ttysXXX`）に OSC バイト列を直接書き込む方式。

### option C の即時実機検証 → OK

```bash
TTY=$(wezterm cli list --format json | jq -r '.[0].tty_name')
printf '\033]1337;SetUserVar=ai_notify=%s\007' \
  "$(printf 'Test|Body|5000' | base64 | tr -d '\n')" > "$TTY"
```

結果: 成功。history 汚染なし、プロンプト状態非依存、ペイン表示への汚染なし。

原理: TTY slave デバイスへの書き込みは PTY master 側に転送され、WezTerm のターミナルエミュレータが OSC を直接解釈する。シェルの stdin を一切経由しない。

### 最終決定

| 選択肢 | 結果 | 採否 |
|--------|------|------|
| A: command string | OK | fallback（`tty_name` 取得不可時） |
| B: raw OSC via send-text | NG | 不可（原理的制約） |
| **C: TTY 直接書き込み** | **OK** | **primary** |

### メタ観察: 発見プロセスの再現性

option C は初期の選択肢セット（A/B）に含まれていなかった。発見には4つの条件が揃う必要があった:

1. **確定後のゼロベース再探索**: A に確定した後で、なお SO に「他に選択肢はないか」と聞いた
2. **反証可能なプロンプト**: 「この方式を確認して」ではなく「ゼロベースで検証して」
3. **提案の即時実機検証**: Claude の提案を「良さそう」で終わらせず、その場で検証コマンドを実行
4. **検証環境の即時利用可能性**: WezTerm が動いていて仮説をすぐに試せた

この発見プロセス自体の再現性を高める方法について、別途 [discussion: 仮説駆動探索の再現性](../../../../docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md) として議論を開始。

---

## 2. 実装（後で追記）

<!-- Issue #30 の実装記録をここに追記 -->

---

## 3. 振り返り（後で追記）

<!-- 実装完了後のレトロスペクティブをここに追記 -->

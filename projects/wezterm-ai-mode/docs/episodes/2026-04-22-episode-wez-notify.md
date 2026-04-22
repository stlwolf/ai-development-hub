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

## 2. 実装 + Peer Review（2026-04-22）

### 実装（Step 1）

`lib/notify.sh` を新規作成し、`bin/wez` にルーティングを追加。キックオフの Step 1-1〜1-4 を実行。

構成:

| 関数 | 責務 |
|------|------|
| `_wez_notify_resolve_pane(opt_pane_id)` | `--pane-id` 指定 or auto-detect。`wezterm cli list` から `pane_id` + `tty_name` を同時取得 |
| `_wez_notify_encode_payload(title, body, timeout)` | `title\|body\|timeout` を base64 エンコード（`tr -d '\n'`） |
| `_wez_notify_send_user_var(pane_id, var_name, encoded, tty_name)` | primary: TTY 直接書き込み、fallback: command string via `send-text --no-paste` |
| `wez_cmd_notify()` | メインディスパッチャ。ソケット探索 → バリデーション → ペイン解決 → 送信 → 出力 |

設計判断の実装状況:

- **DJ-1**: TTY direct write が primary。E2E で `--json` 出力の `"method": "tty"` を確認
- **DJ-2**: 2段階フォールバック（`--pane-id` 指定 → first pane auto-detect）
- **DJ-3**: `title|body|timeout` 形式、base64 + `tr -d '\n'`
- **DJ-5**: pipe 文字・改行禁止、timeout 範囲チェック（100-60000）

コミット: `88d0b01 feat(wez): add notify subcommand with TTY direct write`

### E2E 検証（Step 2）

12項目すべてパス:

| ケース | 結果 |
|--------|------|
| 通常送信（title + body） | exit 0 |
| body 省略 | exit 0 |
| `--pane-id` 指定 | exit 0 |
| `--timeout 8000` | exit 0 |
| `--json` 出力 | JSON + `method: "tty"` |
| title なし | exit 64 |
| pipe 文字入り title | exit 64 |
| timeout 範囲外（0） | exit 64 |
| timeout 非数値 | exit 64 |
| 存在しないペイン | exit 3 |
| `--help` | ヘルプ表示 |
| shellcheck | pass |

### Peer Review: so-compare（GATE）

E2E パス後、キックオフの必須停止 GATE に従い `so-compare` を実施。

**参加者**: Codex CLI (v0.121.0) + Claude Code。2者とも成功。

**検出事項:**

| # | 重大度 | 内容 | 発見者 | 対応 |
|---|--------|------|--------|------|
| Bug-1 | 🔴 | jq-less `--json` パスで title の `"` `\` が未エスケープ → 不正 JSON | Codex + Claude | 修正済み |
| Obs-1 | 🟡 | jq-less `pane_id` 抽出の grep がスペース入り JSON に非対応（pane.sh との不整合） | Claude | 修正済み |
| Obs-2 | 🟡 | `discover_socket` の exit code case が網羅的でない（pane.sh も同じ） | Claude | 許容 |
| Obs-3 | 🟡 | fallback 時のペイン汚染（設計上の受容事項） | Codex + Claude | 許容 |
| Obs-4 | 🟡 | `--pane-id` のペイン存在検証が遅延（pane.sh と同じパターン） | Claude + 自分 | 許容 |

**合意判定**: 3者合意。Bug-1 は修正必須、Obs-1 はついでに改善、残りは Phase 1 で許容。

**見落としの教訓**: pane.sh では JSON に user-controlled 文字列を含めていなかったため、jq-less パスのエスケープ問題が顕在化していなかった。notify は `title` を JSON に含めるため、この差異が新たなバグを生んだ。新規ファイル作成時は、既存ファイルとの「入力性質の差」を意識してレビューすべき。

修正コミット: `3e3ee9f fix(wez): escape title in jq-less JSON output + harden grep pattern`

レビューログ: `tmp/peer-review-20260422-201901/review-log.md`

---

## 3. 振り返り（後で追記）

<!-- 実装完了後のレトロスペクティブをここに追記 -->

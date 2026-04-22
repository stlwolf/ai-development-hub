---
title: "ADR-007: notify サブコマンドの設計判断集"
date: 2026-04-22
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-22-kickoff-wez-notify.md
    reason: "DJ-1〜DJ-5 の検証結果と採用判断を記録"
  - type: depends_on
    ref: ADR-004-pane-design-decisions.md
    reason: "exit code 体系、send-text パターンを踏襲"
  - type: depends_on
    ref: ADR-005-bash-shell-standards.md
    reason: "bash 3.2 互換ルール"
  - type: evidence_for
    ref: ../episodes/2026-04-22-episode-wez-notify.md
    reason: "DJ-1 の実機検証プロセスを記録"
tags: [notify, tty, osc1337, user-var, design-decision, base64]
---

# ADR-007: notify サブコマンドの設計判断集

## ステータス

Accepted

## DJ-1: 送信方式 — TTY 直接書き込み（primary）+ command string（fallback）

3方式を実機検証し、option C（TTY 直接書き込み）を primary として採用。

| 選択肢 | 検証結果 | history 汚染 | プロンプト依存 |
|--------|---------|-------------|-------------|
| A: command string（PoC 踏襲） | OK | あり | あり |
| B: raw OSC via send-text | **NG** | - | - |
| **C: TTY 直接書き込み** | **OK** | **なし** | **なし** |

**option B が NG の原理**: `send-text` は PTY 入力（キーボード側）に書き込む。WezTerm は PTY 出力のみで OSC を解釈するため、原理的に動作しない。

**option C の原理**: `wezterm cli list --format json` の `tty_name`（`/dev/ttysXXX`）に OSC バイト列を書き込む。TTY slave への書き込みは PTY master 経由で WezTerm のターミナルエミュレータに到達し、OSC を直接解釈する。

**fallback（option A）が必要なケース**: `tty_name` が JSON に含まれない旧バージョン、SSH セッション経由のペイン、TTY デバイスの書き込み権限がない場合。

**実装**: `_wez_notify_send_user_var()` で `tty_name` の存在と `-w` 権限を確認し、primary を試行。失敗時に fallback へ降格。`--json` 出力の `method` フィールド（`"tty"` / `"send-text"`）でどちらが使われたか判別可能。

**発見経緯**: option A に一旦確定した後の so-compare ゼロベースレビューで Claude が提案。即時実機検証で確認。詳細は [episode](../episodes/2026-04-22-episode-wez-notify.md) セクション1 に記録。

## DJ-2: ペイン選択のデフォルト挙動

2段階フォールバック:

1. `--pane-id <ID>`（明示指定）
2. `wezterm cli list --format json` の最初のペイン（auto-detect）

notify は「WezTerm ウィンドウへの通知」であり、`pane send`（特定ペインでコマンド実行）とは意味が異なる。`user-var-changed` イベントは window 単位で発火するため送信先の厳密さは不要。

`$WEZTERM_PANE` は Phase 1 では YAGNI として組み込まない。Cursor → WezTerm（外部）が primary use case であり、`$WEZTERM_PANE` は未設定。

## DJ-3: ペイロード区切り `|` の脆弱性対応

`title|body|timeout` 形式で base64 エンコード。Lua ハンドラの `gmatch('[^|]+')` は空セグメント消失の問題があるが、Phase 1 では Lua 未適用のため実害なし。

Phase 1: title/body に `|` を含む入力は `WEZ_EXIT_USAGE` で拒否。Phase 2 の Lua 統合時に区切り文字変更（`\x1f`）または JSON 化を検討。

## DJ-4: タイムアウトフラグの命名

`--timeout`（ミリ秒単位）を採用。help に `(milliseconds, default: 4000)` と明記。

`pane split --timeout`（秒単位、待機タイムアウト）とは用途が異なるため混同リスクは低いと判断。Phase 2 で `--timeout-ms` への変更が必要になれば、`--timeout` をエイリアスとして残す。

## DJ-5: base64 エンコーディングの改行対策

macOS の `base64` は 76 文字ごとに改行を挿入する。OSC シーケンス内に改行が入ると破損するため、`tr -d '\n'` で明示的にストリップ。PoC には対策なし（短い入力で発生しなかったため）。

## Peer Review で追加された修正

so-compare（Codex + Claude）のレビューで以下を検出・修正:

- **jq-less `--json` パスの JSON エスケープ**: title 内の `"` `\` が未エスケープだった。`${title//\\/\\\\}` + `${title//\"/\\\"}` で修正
- **jq-less grep パターンの堅牢化**: `"pane_id":[0-9]*` → `"pane_id":[[:space:]]*[0-9]+` でスペース入り JSON にも対応（pane.sh との一貫性）

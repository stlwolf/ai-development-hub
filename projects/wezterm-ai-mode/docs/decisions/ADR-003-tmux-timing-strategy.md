---
title: "ADR-003: tmux auto-attach タイミング対処方式"
date: 2026-04-20
type: decision
related:
  - type: implements
    ref: ../plans/2026-04-20-kickoff-wez-pane.md
    reason: "DJ-1 の判断を記録"
  - type: evidence_for
    ref: ../../../poc/wezterm-ai-mode/docs/episodes.md
    reason: "PoC-02 でタイミング問題を観測"
tags: [tmux, timing, polling, pane, design-decision]
---

# ADR-003: tmux auto-attach タイミング対処方式

## ステータス

Accepted

## コンテキスト

`wez pane split` で新ペインを作成すると、`.bashrc` の `tmux_automatically_attach_session` が実行される。シェル起動 → tmux 接続 → プロンプト表示まで数秒のラグがあり、その間 `send-text` / `get-text` が空応答を返す（PoC-02 で確認済み）。

## 選択肢

- **A**: 固定 sleep（sleep 2〜3s）
- **B**: get-text ポーリング（非空 + 安定判定）
- **C**: tmux auto-attach スキップ（AI Mode 専用ペイン）

## 判断

**B を採用**（`--wait-ready` オプション）。`_wez_wait_pane_ready` で以下のポーリングロジックを実装:

- 非空判定: `[[ "$curr" == *[!$' \t\n']* ]]`（純 bash、サブシェル不要）
- 安定判定: `tail -n 5` の出力が2回連続一致
- 間隔: 0.5s（整数ミリ秒管理、`bc` 非依存）
- タイムアウト: デフォルト10s、`--timeout` で変更可能
- タイムアウト時: pane_id を返しつつ exit 4（`WEZ_EXIT_TIMEOUT`）

A（固定 sleep）はフォールバックとして利用者側で `sleep 2 && wez pane send` とすれば実現可能。C は `.bashrc` の `is_ai_ide()` 拡張が必要で Phase 1 スコープ外。

## 結果

- `wez pane split --wait-ready` で呼び出し元がポーリング待機をオプトイン
- デフォルト（`--wait-ready` なし）は即座に pane_id を返す。タイミング制御は呼び出し元の責任
- so-compare レビューで `bc` 依存を指摘され、整数ミリ秒化で解決済み

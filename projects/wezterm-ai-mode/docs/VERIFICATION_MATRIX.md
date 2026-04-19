---
title: "検証マトリクス: wezterm-ai-mode（ツール + 開発プロセス）"
date: 2026-03-30
type: plan
related:
  - type: derived_from
    ref: ../../poc/wezterm-ai-mode/README.md
    reason: "PoC の成功基準を本マトリクス A 軸の土台とする"
tags: [verification, wezterm, process, cli, reproducibility]
keywords: [wezterm, wez, tmux, Cursor, shellcheck]
use_when:
  - "PoC 由来の項目と本 PJ 追加分の検証状態を追いたいとき"
  - "cursor-thread-tools と同型の Stage 1〜3 が再現できたか確認したいとき"
---

# 検証マトリクス

本プロジェクトは **A. ツール（WezTerm / `wez`）** と **B. 開発プロセス（CONVENTIONS + Stage 分離）** の2軸で検証する。スコープの正本は [Issue #20](https://github.com/stlwolf/ai-development-hub/issues/20)（Epic）。

---

## A. ツール実装の検証

### A-1. PoC 由来（凍結参照）

根拠: [`projects/poc/wezterm-ai-mode/`](../../poc/wezterm-ai-mode/README.md)、[`docs/episodes.md`](../../poc/wezterm-ai-mode/docs/episodes.md)。

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-1-1 | ソケット自動検出（`gui-sock-*`） | PoC 完了 | PASSED | PoC-01 |
| A-1-2 | ペイン操作（split / send / list / kill） | PoC 完了 | PASSED（タイミング制約あり） | PoC-02 |
| A-1-3 | 出力キャプチャ（`get-text`、tmux 内） | PoC 完了 | PASSED | PoC-03 |
| A-1-4 | 通知経路（user-var 送信 → Lua / toast） | PoC 部分 | PARTIAL（Lua 手動適用要） | PoC-04 |

### A-2. 本プロジェクト（`wez` 統合 CLI・Phase 1）

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-2-1 | `wez discover` 単体・全サブコマンド前提 | 実施済み | PASSED | Issue #28, E2E 9/9 パス |
| A-2-2 | `wez pane`（list / split / send / capture / kill） | 未実施 | - | 同上 |
| A-2-3 | `wez notify`（運用 Lua 統合方針確定後） | 未実施 | - | 同上 |
| A-2-4 | 複数 WezTerm インスタンス時のソケット選択 | 設計済み | DESIGNED | ADR-002: mtime+verify ハイブリッド方式。単一インスタンスで E2E 検証済み |
| A-2-5 | 新ペイン tmux auto-attach 後のコマンド送信（ポーリング等） | 未実施 | - | PoC-02 制約 |

---

## B. プロセス検証（cursor-thread-tools 同型フロー）

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| B-1 | Stage 1: Agent mode で plan MD 作成 + peer-ai-review | 未実施 | - | [CONVENTIONS.md](../CONVENTIONS.md) |
| B-2 | Stage 2: 確定プランを Plan mode に変換して実装 | 未実施 | - | 同上 |
| B-3 | Stage 3: episode + ADR + 本ファイル更新 + キックオフ突合 | 未実施 | - | 同上 |
| B-4 | plan と episode の分離が運用で守られたか | 未実施 | - | 同上 |
| B-5 | 実装後 `so-compare.sh` gate + `shellcheck` 前提のレビュー | 未実施 | - | CONVENTIONS「標準 gate」 |

---

## 更新方針

- フェーズ完了ごとに本ファイルの「状態」「結果」「根拠」を埋める
- Epic への依存は本文・コミットメッセージ・Issue 参照で追う。frontmatter の `related` はリポジトリ内の相対パスに統一する

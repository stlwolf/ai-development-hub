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
| A-2-2 | `wez pane`（list / split / send / capture / kill） | 実施済み | PASSED | Issue #29, E2E 12/12 パス |
| A-2-3 | `wez notify`（user-var 送信 + Lua 統合方針 ADR） | 実施済み | PASSED（CLI 層。toast は Phase 2） | Issue #30, E2E 12/12 パス, ADR-006/007 |
| A-2-4 | 複数 WezTerm インスタンス時のソケット選択 | 設計済み | DESIGNED | ADR-002: mtime+verify ハイブリッド方式。単一インスタンスで E2E 検証済み |
| A-2-5 | 新ペイン tmux auto-attach 後のコマンド送信（ポーリング等） | 実施済み | PASSED（--wait-ready） | ADR-003: ポーリング方式採用。E2E で send → capture 正常動作確認 |
| A-2-6 | 3ツール横断 7ステップ統合フロー（discover→kill） | 実施済み | PASSED | Issue #31, [E2E エピソード](episodes/2026-05-13-phase1-e2e.md), #20 コメント群（Cursor/CC/Codex 全成功） |
| A-2-7 | 空 title バリデーション（課題 E 修正） | 実施済み | PASSED | Issue #31, `fix(wez): reject empty title` |
| A-2-8 | `wez pane activate`（split 後のフォーカス復帰） | 実施済み | PASSED（shellcheck + so-compare + 実機 E2E。`is_active` で split→activate のフォーカス復帰 active 5→0 を確認、`--json` 成功出力も確認） | Issue #111, [episode](episodes/2026-05-31-wez-pane-activate.md) |

---

## B. プロセス検証（cursor-thread-tools 同型フロー）

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| B-1 | Stage 1: Agent mode で plan MD 作成 + peer-ai-review | スキップ | - | Phase 1 は Issue 駆動で進行。Stage 分離フローの本格検証は Phase 2 以降 |
| B-2 | Stage 2: 確定プランを Plan mode に変換して実装 | スキップ | - | 同上 |
| B-3 | Stage 3: episode + ADR + 本ファイル更新 + キックオフ突合 | スキップ | - | 同上 |
| B-4 | plan と episode の分離が運用で守られたか | 実施済み | PARTIAL | plans/ と episodes/ の分離は維持。ただし Stage 順序の厳格運用ではない |
| B-5 | 実装後 `so-compare.sh` gate + `shellcheck` 前提のレビュー | 実施済み | PASSED | Issue #31, [E2E エピソード](episodes/2026-05-13-phase1-e2e.md) §3。Codex+Claude 2者合意、medium 2件修正済み |
| B-6 | Stage 1〜3 + plan/実装の二段 peer-ai-review を1サイクル通す（#113 構造化振り返り検証） | 実施済み | PASSED | Issue #111, [episode クロージャ振り返り](episodes/2026-05-31-wez-pane-activate.md)。plan gate が Step 順序矛盾、code gate が help 漏れを各々検出。KPT + 構造化FB表を試用し #113 へ申し送り |

---

## 更新方針

- フェーズ完了ごとに本ファイルの「状態」「結果」「根拠」を埋める
- Epic への依存は本文・コミットメッセージ・Issue 参照で追う。frontmatter の `related` はリポジトリ内の相対パスに統一する

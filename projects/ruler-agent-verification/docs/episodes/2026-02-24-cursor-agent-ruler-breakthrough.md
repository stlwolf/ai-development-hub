---
title: "Cursor agent CLI 経由でルーラーエージェントのアクセスモデル問題を解決"
date: 2026-02-24
type: episode
related:
  - type: derived_from
    ref: 2026-02-21-gemini-cli-initial-verification.md
    reason: "初回検証でアクセスモデル問題を発見 → 本エピソードで解決"
  - type: depends_on
    ref: ../../prompts/ruler-v1.txt
    reason: "ルーラープロンプトテンプレート"
  - type: depends_on
    ref: ../../../arena-compare/arena-compare.sh
    reason: "Cursor agent CLI 実行パターンの元ネタ"
tags: [ruler-agent, cursor-agent, gemini-3.1-pro, access-model, breakthrough]
keywords: [cursor-agent, agent, cli-config.json, resource_exhausted, gmn, nohup, ruler.sh]
use_when:
  - "ルーラーエージェントを実行するとき"
  - "Gemini CLI のレートリミット/認証問題に遭遇したとき"
  - "Cursor agent CLI 経由で特定モデルを非インタラクティブ実行したいとき"
  - "agent コマンドと cursor-agent コマンドの違いを知りたいとき"
---

# Cursor agent CLI 経由でルーラーのアクセスモデル問題を解決

## 概要

初回検証（2026-02-21）で発見された「Gemini CLIのアクセスモデル（認証/レートリミット/コスト）が運用上の最大障壁」という問題を、Cursor agent CLI (`cursor-agent`) 経由での実行に切り替えることで解決した。追加コストなし、Cursorサブスク内で gemini-3.1-pro をルーラーとして実行可能。

## 前回からの経緯

初回検証（`2026-02-21-gemini-cli-initial-verification.md`）の結論:

- **技術的適性は高い**（幻覚なし、フォーマット遵守、関連判断の正確な特定）
- **アクセスモデルが最大の障壁**（OAuth personalのキャパ枯渇、API Key有料枠は従量課金）

## 検証1: gmn（Go版Gemini CLI）

[gmn](https://github.com/tomohiro-owada/gmn) — Gemini CLIのGo再実装（起動68倍高速化）をテスト。

| テスト | 結果 |
|---|---|
| インストール | 成功（v0.28.2, 6.0MB） |
| `--version` | 0.255秒（公式の約1/4） |
| 実行 | **ハング** — Token refreshでスタック |

**結論**: gmn は OAuth 認証のみ対応、API Key非対応。公式CLIと同じ `cloudcode-pa` のキャパシティ問題をそのまま引き継ぐ。ツールの問題ではなくGoogleのサーバー側の問題。

## 検証2: コスト試算

ルーラー1回あたりの実データ（入力~42K tokens, 出力~1.5K tokens）から:

| モデル | 1回あたり | 月150回 | 月300回 |
|---|---|---|---|
| gemini-2.5-pro | $0.068 | $10.2 | $20.4 |
| gemini-2.5-flash | $0.007 | $1.1 | $2.1 |

flashなら月$1-2。ただしCodex/Claudeは既存サブスクで追加コストなし。

## 検証3: Cursor agent CLI 経由（突破口）

arena-compare.sh が `cursor agent --model gemini-3.1-pro` でGeminiを使えていることに着目。同じパターンでルーラーを実行。

### `agent` vs `cursor-agent` の差異発見

| コマンド | バージョン | パス | Gemini 3.1 Pro |
|---|---|---|---|
| `agent` | 2026.02.13 | `~/.local/share/cursor-agent/` | `resource_exhausted` |
| `cursor-agent` | 2026.01.28 | Homebrew cask | **動作する** |

新しい `agent` バイナリ（2026.02.13）は Gemini で `resource_exhausted` を返すが、Homebrew版の `cursor-agent`（2026.01.28）は正常動作。

### Cursor統合ターミナルからの agent CLI 実行の制約

- 同一ターミナルでCursor Agentが動作中の場合、`agent` CLI が `cli-config.json` を競合して `Connection lost, reconnecting...` でハング
- arena-compare.sh のスタガー（2秒ずらし起動）はこの対策だが、Cursor統合ターミナルでは根本的にCursorプロセスと競合する
- **ローカルターミナルからの実行が安定**

### ruler.sh 作成と成功テスト

arena-compare.sh と同じ実行パターン（`create-chat` → `--resume=$CHAT_ID` → `nohup` → `timeout`）で `ruler.sh` を作成。

```bash
./projects/ruler-agent-verification/ruler.sh "タスク説明"
```

**テスト結果（gemini-3.1-pro via cursor-agent）**:

| 項目 | 値 |
|---|---|
| モデル | gemini-3.1-pro（Cursorサブスク内） |
| 追加コスト | **なし** |
| 応答時間 | 61秒 |
| 幻覚 | なし（全引用が実在） |
| フォーマット遵守 | 完全（5セクション全て） |
| 「該当なし」申告 | 正直に2領域を明示 |

## アクセスモデルの比較（最終版）

| 方式 | 追加コスト | Gemini 3.1 Pro | 安定性 |
|---|---|---|---|
| Gemini CLI（OAuth personal） | なし | キャパ枯渇頻発 | 低 |
| Gemini CLI（API Key無料枠） | なし | 5 req/min制限 | 低 |
| Gemini CLI（API Key有料枠） | 月$1-20 | 動作する | 中 |
| gmn（Go版） | なし | OAuthと同じ問題 | 低 |
| **cursor-agent 経由** | **なし** | **動作する** | **高（ローカルから）** |

## ナレッジ（追加分）

### K7: gmn は認証問題を解決しない

起動は68倍速いが、OAuth認証のみ対応でAPI Key非対応。cloudcode-pa のキャパシティ問題はツールではなくGoogle側の問題。

### K8: cursor-agent 経由がルーラーの最適解

Cursorサブスク内で gemini-3.1-pro を追加コストなしで使える。ヘッドレスモードの `-p` では404だったモデル名も `cursor-agent` 経由なら通る。

### K9: `agent` と `cursor-agent` はバージョンが異なるバイナリ

`agent`（~/.local/bin、自動更新版）と `cursor-agent`（Homebrew cask版）は異なるバージョン。新しい方が必ずしも安定とは限らない。

### K10: Cursor統合ターミナルからの agent CLI 実行は不安定

Cursorプロセスと `cli-config.json` が競合する。ローカルターミナルからの実行を推奨。

## 次回検証案（更新）

### V4（完了）: Cursor agent CLI 経由でのルーラー実行

→ 成功。gemini-3.1-pro がCursorサブスク内で動作確認済み。

### V2（次の優先）: ルーラー出力をSOに実際に渡す統合テスト

ruler.sh の出力を so-compare.sh のコンテキストとして渡し、ルーラーあり/なしでSO品質に差が出るか比較。

### V7: 実タスクでのルーラー運用

atteluの実際のdeprecationタスク等で ruler.sh を日常的に使い、精度と有用性のデータを蓄積。

## 成果物

| ファイル | 内容 |
|---|---|
| `ruler.sh` | Cursor agent CLI 経由のルーラー実行スクリプト |
| `tmp/ruler-20260224-105539/` | gemini-3.1-pro ルーラー出力（成功） |
| `tmp/ruler-20260224-032550/` | gemini-3.1-pro ルーラー出力（agent版、失敗） |

---

*作成日: 2026-02-24*

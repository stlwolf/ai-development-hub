---
id: "01KRJM78XPQFXQKZY5DXY30HV5"
title: "DI-7 + DI-12 Time Budgeting とサーキットブレーカー設計確定"
date: 2026-05-14
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-plan-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 Plan"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Discussion §12 サーキットブレーカー数値例示"
  - type: depends_on
    ref: "projects/orchestration-engine/docs/episodes/2026-05-14-episode-slo-baseline.md"
    reason: "DI-2 SLO 確定値に依存（時間上限 = サイクル完走上限）"
  - type: depends_on
    ref: "projects/orchestration-engine/docs/episodes/2026-05-14-episode-failure-taxonomy-schema.md"
    reason: "DI-4 Failure Taxonomy の timeout / blocked 値を使用"
tags: [orchestration, mvp, step-4-1, episode, circuit-breaker, time-budgeting, safety]
---

# DI-7 + DI-12 Time Budgeting とサーキットブレーカー設計確定

## 経緯・背景

Step 4-0 Discussion §12 で、自律サイクルの暴走防止メカニズムとして「サーキットブレーカー」が論点に挙がった。時間 30 分 / ターン 10 回 / ペイン 5 個 / コスト optional が例示された。

KickOff で DI-7（Time Budgeting）と DI-12（Resource Limit / Circuit Breaker）が別 Decision Item として設定されたが、Plan フェーズ 3 の検討で以下の理由から一体確定とした:

- 時間上限は DI-2 SLO のサイクル完走上限と同値（1800 秒）。分離すると二重管理になる
- ターン上限・ペイン上限も「サーキットブレーカー」の一部であり、監視・トリガー・後処理が共通
- 上限到達時の挙動（DI-4 の `timeout` / `blocked` への遷移）が全上限で統一される

## 検討した選択肢

### 時間上限

| 候補 | 評価 |
|---|---|
| 900 秒（15 分） | 短すぎ。複雑なタスク（マルチファイル変更 + テスト実行）で途中打ち切りのリスク |
| **1800 秒（30 分）** | Discussion §12 例示値。DI-2 SLO と整合。個人開発環境で妥当 |
| 3600 秒（60 分） | 暴走時の被害が大きい。MVP では保守的な値が適切 |

### 時間上限の監視手段

| 候補 | 評価 |
|---|---|
| **Bash `timeout` コマンド** | OS レベルで強制停止。実装不要。exit code 124 で `timeout` 状態にマッピング可能。Step 0 で動作確認済み |
| シェル内タイマー（`$SECONDS`） | ポーリングループ内で比較。`timeout` より柔軟だが、無限ループ時に到達しない可能性 |
| 外部 watchdog プロセス | 確実だが MVP では過剰な複雑性 |

→ Bash `timeout` を採用。ディスパッチャの最外殻で `timeout ${timeout_seconds} ${dispatcher_main}` として起動。

### ターン上限

| 候補 | 評価 |
|---|---|
| 5 回 | 単純タスクには十分だが、修正→テスト→再修正のサイクルで枯渇しやすい |
| **10 回** | Discussion §12 例示値。「要件理解 → 実装 → テスト → 修正」の 2-3 サイクルに相当 |
| 20 回 | 暴走の検知が遅れる。10 回で blocked なら人間判断が妥当 |

### 同時ペイン上限

| 候補 | 評価 |
|---|---|
| 3 個 | 最小構成（editor + terminal + test）で枯渇 |
| **5 個** | Discussion §12 例示値。並列テスト実行やログ監視を含めても余裕あり |
| 10 個 | macOS のターミナルリソース圧迫リスク。MVP では不要 |

### コスト上限

| 候補 | 評価 |
|---|---|
| トークン数ベース | CLI ツール（Cursor / Claude）のトークン使用量 API が不安定。推定精度が低い |
| 課金額ベース | リアルタイム課金情報の取得手段がない |
| **MVP では実装しない** | 不安定な推定値に基づく制御はかえって危険。時間 + ターン上限で間接的にコストを制約 |

## 確定内容

### 上限値

| 上限 | デフォルト値 | 注入経路 | 監視主体 |
|---|---|---|---|
| 時間上限 | **1800 秒（30 分）** | envelope `exit_conditions.timeout_seconds` | Bash `timeout` コマンド |
| ターン上限 | **10 回** | envelope `exit_conditions.max_turns` | ディスパッチャ内カウンタ |
| 同時ペイン上限 | **5 個** | envelope `constraints.max_panes` | `wez pane list` 行数チェック |
| コスト上限 | **MVP では実装しない** | — | — |

### 監視メカニズム

**時間上限（Bash `timeout`）:**

- ディスパッチャが `timeout ${timeout_seconds} ${cli_command}` でサブプロセスを起動
- timeout 超過 → exit code 124 → DI-4 `timeout` 状態
- Step 0 で `timeout` + `wez pane kill` の連携動作を確認済み

**ターン上限（ディスパッチャ内カウンタ）:**

- ポーリングループ内で `turn_count` をインクリメント
- 1 ターン = 1 ポーリングサイクルで「出力変化あり」を検知した回数
- `max_turns` 超過 → DI-4 `blocked` 状態 → 監査ログ記録 → 人間判断要求

**同時ペイン上限（`wez pane list`）:**

- ペイン spawn 前に `wez pane list | jq length` で現在数を確認
- 上限超過 → spawn 拒否 → DI-4 `blocked` 状態

### 上限到達時の共通挙動

1. DI-4 の `timeout` または `blocked` をエンベロープ `exit_state` に記録
2. 監査ログ（DI-11）に `circuit_breaker_triggered` イベントを記録（トリガー種別・到達値を含む）
3. `wez pane kill` で管理下ペインを停止
4. 親エージェントに通知（stdout メッセージ）
5. 人間が判断（再実行 / 中止 / パラメータ調整）

## 根拠

### Discussion 例示値との照合

| Discussion §12 例示値 | 確定値 | 差異 |
|---|---|---|
| 時間 30 分 | 1800 秒（30 分） | 一致 |
| ターン 10 回 | 10 回 | 一致 |
| ペイン 5 個 | 5 個 | 一致 |
| コスト optional | MVP では実装しない | 一致（optional → 不実装） |

### DI-2 SLO との整合

- サイクル完走上限（DI-2）= 時間上限（DI-7/DI-12）= 1800 秒。同一の値を `exit_conditions.timeout_seconds` で制御
- ポーリング間隔 2 秒（DI-2）× ターン上限 10 回 = 最短 20 秒で上限到達。実際にはターン間に CLI 実行時間が入るため、時間上限が先に効くケースが大半

### 実装コストの評価

- Bash `timeout`: 追加実装ゼロ。OS 標準コマンド
- ディスパッチャ内カウンタ: 変数インクリメント 1 行 + 条件分岐 3 行
- `wez pane list` チェック: spawn 前に 1 コマンド実行 + 条件分岐 3 行

## 影響・制約

- **DI-2（SLO）**: 時間上限がサイクル完走上限と同値。SLO 変更時はサーキットブレーカーも連動
- **DI-4（Failure Taxonomy）**: 上限到達時に `timeout` / `blocked` を使用。この 2 値の意味が「サーキットブレーカー発動」を包含
- **DI-5（Envelope）**: `exit_conditions.timeout_seconds` / `exit_conditions.max_turns` / `constraints.max_panes` の 3 フィールドがサーキットブレーカーの設定経路
- **DI-9（exit code マッピング）**: Bash `timeout` の exit code 124 → `timeout` マッピングが前提
- **DI-11（監査ログ）**: `circuit_breaker_triggered` イベント種別の追加が必要

## 将来の拡張ポイント

- **コスト上限の追加**: CLI ツールのトークン使用量 API が安定したら、`exit_conditions.max_cost` フィールドを追加。監視は監査ログのトークン累積値で実装
- **段階的制限（ソフト/ハード）**: 時間上限の 80% 到達で警告 → 100% で停止。ターン上限も同様に「残り 2 ターン」で通知
- **動的上限調整**: タスク複雑度に応じて上限を自動調整（例: ファイル数が多い場合にターン上限を引き上げ）
- **サーキットブレーカーの状態遷移**: half-open 状態の導入。一度トリガーされた後、人間の承認なしで制限付き再試行を許可
- **メモリ/ディスク使用量の監視**: リソース上限の拡張。`wez pane capture` 出力サイズの急増をアノマリ検知

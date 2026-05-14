---
id: "01KRJM76QEF6VCJ706QBXAARCY"
title: "DI-2 オープンループ自律サイクル最小 SLO 確定"
date: 2026-05-14
type: episode
status: draft
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
    reason: "Discussion §4 SLO 例示値、§12 サーキットブレーカー数値"
tags: [orchestration, mvp, step-4-1, episode, slo, observation-loop, polling]
---

# DI-2 オープンループ自律サイクル最小 SLO 確定

## 経緯・背景

Step 4-0 Discussion §4 で「オープンループ自律サイクル」の最小 SLO が論点として挙がり、例示値（状態変化検知 5 秒以内 / interrupt は次 heartbeat まで / サイクル完走上限 30 分）が提示された。KickOff DI-2 として「SLO 数値の確定」が Decision Item に設定された。

Step 4-1 Plan フェーズ 3 で以下の実測データを根拠に数値を確定する:

- Step 0 実測結果: `wez pane capture` 平均 76ms/回
- ポーリング間隔 2 秒で CPU 負荷は無視可能（capture 処理が間隔の 3.8%）
- DI-5（Envelope）の `exit_conditions` に `timeout_seconds` / `max_turns` フィールドが確定済み

## 検討した選択肢

### 状態変化検知の上限秒数

| 候補 | 評価 |
|---|---|
| 3 秒 | ポーリング間隔 2 秒 × 1 回 + capture 76ms ≈ 2.08 秒。1 回で検知できれば収まるが、タイミングによっては 2 回必要。マージン不足 |
| **5 秒** | 2 秒 × 2 回 + capture 76ms ≈ 4.15 秒。最悪ケースでも余裕あり |
| 10 秒 | 過剰。ユーザー体感として「何も起きていない」と感じる閾値を超える |

### ポーリング間隔

| 候補 | 評価 |
|---|---|
| 1 秒 | capture 76ms → 間隔の 7.6%。負荷は許容範囲だが、ターミナル装飾（プロンプト描画途中等）のノイズが増加 |
| **2 秒** | capture 76ms → 間隔の 3.8%。負荷無視可能。装飾ノイズも安定して排除される |
| 5 秒 | 状態変化検知 SLO 5 秒を満たせない（1 回のポーリングで 5 秒消費） |

### interrupt ack 上限

| 候補 | 評価 |
|---|---|
| 即時（割り込み式） | `wez pane send` による SIGINT 注入は即時だが、検知側がポーリングのため即時確認不可。割り込み検知用の別チャネルは MVP で過剰 |
| **次回ポーリングまで（最大 2 秒）** | ポーリング間隔と同期。実装が単純で予測可能 |
| 専用シグナルチャネル | MVP のスコープ外。将来 WebSocket / inotify 等で即時化可能 |

### サイクル完走上限

| 候補 | 評価 |
|---|---|
| 15 分 | 複雑なタスクで途中切断のリスク |
| **30 分** | Discussion §12 例示値。個人開発環境で「放置しても安全」な上限 |
| 60 分 | 暴走時のリソース消費が大きい。MVP では保守的な値が適切 |

## 確定内容

| SLO 軸 | 確定値 | 単位 |
|---|---|---|
| 状態変化検知の上限秒数 | **5** | 秒 |
| interrupt ack 上限 | **次回ポーリングまで（最大 2 秒）** | — |
| サイクル完走上限 | **1800**（30 分） | 秒 |
| ポーリング間隔 | **2** | 秒 |

補足:

- サイクル完走上限はデフォルト値。エンベロープの `exit_conditions.timeout_seconds` で上書き可能
- interrupt の「注入」自体は `wez pane send` で即時。SLO は「検知＝ディスパッチャが状態変化を認識する」までの上限

## 根拠

### 実測値との照合

- `wez pane capture` 平均 76ms/回（Step 0 実測）
- ポーリング間隔 2 秒での状態変化検知:
  - 最良ケース: capture 直後に状態変化 → 次ポーリングで検知 ≈ 2.08 秒
  - 最悪ケース: capture 直前に状態変化 → 2 ポーリング後に検知 ≈ 4.15 秒
  - SLO 5 秒は最悪ケースに対して約 0.85 秒のマージン

### Discussion 例示値との照合

| Discussion §4 例示値 | 確定値 | 差異 |
|---|---|---|
| 5 秒以内に状態変化検知 | 5 秒 | 一致 |
| interrupt は次 heartbeat まで | 次回ポーリングまで（最大 2 秒） | 一致（heartbeat = ポーリング） |
| サイクル完走上限 30 分 | 1800 秒（30 分） | 一致 |

## 影響・制約

- **DI-7 + DI-12（Time Budgeting + サーキットブレーカー）**: サイクル完走上限 1800 秒がサーキットブレーカーの時間上限と一致。整合性を保証
- **DI-5（Envelope）**: `exit_conditions.timeout_seconds` のデフォルト値として 1800 を使用
- **DI-9（exit code マッピング）**: timeout 超過時は Bash `timeout` コマンドの exit code 124 → `timeout` 状態にマッピング
- **DI-11（監査ログ）**: ポーリング間隔 2 秒は監査ログの時間粒度の下限を規定（2 秒未満の状態変化は記録できない場合がある）

## 将来の拡張ポイント

- **イベント駆動化**: ポーリングから `inotify` / `fswatch` / WebSocket への移行で、状態変化検知を sub-second に短縮可能。SLO 値は据え置きで内部実装のみ変更
- **適応的ポーリング間隔**: アイドル時は間隔を延長（5 秒）、アクティブ時は短縮（1 秒）する動的制御。SLO は最悪ケースの上限として維持
- **interrupt の即時化**: 専用シグナルチャネル（named pipe / Unix socket）で interrupt ack を即時化。現行のポーリング依存から脱却
- **SLO モニタリング**: 実際の検知レイテンシを監査ログに記録し、SLO 違反率を計測。数値の見直し根拠として活用

---
id: "01KRGEFCA3PV9CNMH0BS5JZ6JM"
title: "orchestration-engine の MVP スコープ・ゴール・docs 配置"
date: 2026-05-13
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-0 として実施"
  - type: sub_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/81"
    reason: "本 Discussion を成果物として持つ Step 4-0 サブ Issue"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "研究フェーズの正本（frozen）。Discussion の起点設計"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/37"
    reason: "Harness Engineering G1〜G7 ギャップ整理"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4298073225"
    reason: "3層モデルと Epic ゴール不鮮明問題の提起"
  - type: design_context
    ref: "docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md"
    reason: "CLIラッパー4層モデル"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4248077589"
    reason: "1.5段階 arena パターン（本 Discussion 作成手順の根拠）"
  - type: arena_result
    ref: "tmp/arena-20260513-200204/summary.md"
    reason: "本 Discussion の論点・UC 仕様を導出した arena ラウンド1 結果（gpt-5.5-medium + gemini-3.1-pro）"
tags: [orchestration, mvp, step-4-0, dogfood, 3-layer-model, open-loop, observability]
---

# orchestration-engine の MVP スコープ・ゴール・docs 配置

> [Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 着手にあたり、研究フェーズ起点以降に蓄積された設計入力を踏まえて MVP の方向性を確定する。

## 進め方の前提

- 本 Discussion はキックオフ相当のディスカッション。最終設計確定ではなく、論点の言語化と仮置きを行う
- [1.5段階 arena パターン](https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4248077589) を適用: arena ラウンド1（`gpt-5.5-medium + gemini-3.1-pro`）で論点漏れ指摘と UC 仮説を取得済み（`tmp/arena-20260513-200204/summary.md`）
- 各論点の最終確定は Discussion 完了後の KickOff / Plan / ADR に持ち越す

## arena ラウンド1 の反映

arena 結果から以下を採用:

- **論点 4 を書き換え**: 「閉セッション間リアルタイム双方向通信」→「オープンループ自律サイクル + 最小 SLO」（両モデル: MVP に過剰スコープ判定）
- **論点 6 を分割**: G4 最小分類 + G6 initializer envelope を MVP に取り込む。G1 / G6 完全版 / G7 は MVP 外
- **論点 5 を先に確定**: 依存関係を `5 → 9 → 3, 4` に修正（UC 駆動。両モデル: 仮置きの逆転）
- **論点 5 (UC) は案 Z ハイブリッド**: gemini の実用的実装（Bash 薄ラッパー前提、wez 物理 UI 活用）を基盤、gpt の観測性・状態語彙・監査ログを上乗せ
- **論点 7 と論点 4 の矛盾を明示**: CLIラッパー層までだと非同期イベントループの管理者が空白になる問題に対する整合方針を記述
- **新規論点 11〜15 を追加**: 観測性・監査ログ / 暴走防止サーキットブレーカー / 権限分離 / クリーンアップ戦略 / Schema-driven Boundaries

## 論点一覧（仮置き、KickOff で確定）

### 1. docs 配置の方針

**仮置き**: [`projects/wezterm-ai-mode/docs/`](../../../wezterm-ai-mode/docs/) の構造（`spec-card` 準拠）を踏襲する。

理由:

- 既存実績ツリーが `spec-card` 正式モデルと同型のため、新たな設計判断を入れる必要がない
- orchestration-engine は「構造化ドキュメントルーティングエンジン」なので、自プロジェクト docs が蒸留パイプライン準拠であること自体に dogfood の素地ができる
- MVP 完走後（4-5 フィードバック時点）に dogfood 化判断（論点 10 で再評価）

### 2. research との関係

**仮置き**: research は frozen、参照のみ。差分は engine 側の `docs/` に記述。

理由:

- [`projects/orchestration-research/README.md`](../../../orchestration-research/README.md) §状態に「Phase 1〜3 完了、MVP 実装は `projects/orchestration-engine/` として着手」と明記
- 二重メンテを回避

### 3. 3 層モデル

**仮置き**:

| 層 | 担当 | 状態 |
|----|------|------|
| 下半身（物理基盤） | `wez` CLI、ペイン = 仮想空間の器 | [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 1 完了 |
| 中間層（通信プロトコル） | 閉セッション間の状態取得・双方向通知・非同期 signal の CLI 表現 | [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 3 未着手 / 本 engine と共同設計 |
| 上半身（エージェント層） | エージェントチームのルーティング、状態管理、失敗処理、ledger | 本 engine（[#19](https://github.com/stlwolf/ai-development-hub/issues/19)） |

注: 論点 5 (UC) を先に確定し、そこから中間層プロトコル要件（論点 9）を導出してから 3 層の責務を確定する流れになる（arena: 依存関係逆転指摘）。

### 4. #19 ゴール定義（書き換え: オープンループ自律サイクル + 最小 SLO）

**仮置き**: Phase 4 完走時に以下が言える状態:

- メインエージェントがサブエージェントを spawn し、ポーリングベースで状態監視・割り込みできる（オープンループ自律サイクル）
- `spawn → liveness/progress取得 → completion/blocked検知 → interrupt可能 → artifact handoff` の 1 サイクルが、人間が常駐しなくても完走する
- 各 UC で「最小 SLO」を満たす（例: 5 秒以内に状態変化を検知 / interrupt は次 heartbeat までに ack）

**重要**: 「リアルタイム event-driven bus」は MVP では構築しない。listener 未着問題は中間層プロトコル要件として論点 9 で扱うが、MVP は capture ポーリング方式で成立する。完全なリアルタイム化は Phase 5 以降。

根拠（arena 両モデル一致）:

- [#20 issuecomment](https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4298073225) の現状: オープンループは実用可能、クローズドループ（event-driven）化には Lua hook / listener / `wez agent monitor` のいずれかが必要
- MVP は #20 現状の到達点で成立する設計に絞り、双方向通信は Phase 5 以降の課題に分離

### 5. ユースケース 3 本（案 Z ハイブリッド: 実用性 + 観測性）

**仮置き**: gemini の実用的実装基盤 + gpt の観測性・状態語彙・監査ログ上乗せ。

#### UC-1: メインエージェントによる調査サブエージェントの監視・軌道修正

- **シナリオ**: メインエージェントが調査タスクをサブエージェントに委譲し、別ペインで起動する。メインは定期ポーリングでサブの出力スナップショットを取得し、停滞・迷走・仕様逸脱を検知した場合、SIGINT または TTY への文字列直接注入で軌道修正する。人間は最初の承認と必要時の介入だけを行う
- **中間層プロトコル要件**:
  1. `session_id` と `pane_id` の安定対応（registry）
  2. ペイン直近出力の非同期ポーリング API（既存: `wez pane capture`）
  3. 実行中プロセスへの割り込み（SIGINT 等）と TTY 文字列注入 API（既存: `wez pane send`）
  4. ライフサイクル状態語彙の閉集合: `spawn / ready / progress / done / blocked`（gpt 上乗せ）
  5. 状態遷移の監査ログ（タイムスタンプ + state + 引き金イベント、gpt 上乗せ）
- **設計判断**:
  - リアルタイム streaming ではなくポーリングによるスナップショット（gemini: 実用的）
  - 状態遷移は閉集合語彙 + 監査ログで観測可能化（gpt: 観測性）

#### UC-2: 並列実装サブエージェント間のファイルベース非同期協調

- **シナリオ**: 複数の閉セッションが、同一 Epic 配下の別 Issue や別ファイル群を並列に処理する。各セッションは作業範囲・進捗・成果物候補・ブロッカーをファイルベース KVS に書き出す。メインは衝突可能性を検出し、マージ順や再実行順を決定する。必要に応じてセッション間のシグナル伝達を行う
- **中間層プロトコル要件**:
  1. ファイルベース軽量 KVS（JSON ファイル + lock or atomic write）
  2. 特定の状態（ファイル更新・特定キーの変化）を監視するブロッキング API（または短間隔ポーリング）
  3. 各サブエージェントの終了ステータス（exit code）の親への集約・伝播機構
  4. セッション registry + 共有 ledger / artifact index（gpt 上乗せ）
  5. 作業範囲 ownership 宣言とコンフリクト検出（gpt + [#47](https://github.com/stlwolf/ai-development-hub/issues/47) 並列セッション運用要件）
- **設計判断**:
  - 複雑な IPC ではなく「ファイルベースのシグナリング」で Bash 薄ラッパーでも実現（gemini: 実用的）
  - registry + ledger + ownership で「誰が何を変更中か」を構造化（gpt + #47: 観測性）

#### UC-3: 人間の俯瞰観測と TTY 直接割り込み（監査ログ付き）

- **シナリオ**: 複数のサブエージェントが自律稼働している様子を、人間が WezTerm のマルチペイン分割画面で俯瞰する。あるエージェントが破壊的操作の手前で確認プロンプトを出して停止した際、人間はメインエージェントを介さず、直接そのペインをアクティブにしてキーボードから `y/n` を入力し、処理を再開させる。割り込み内容は engine が監査ログとして記録する
- **中間層プロトコル要件**:
  1. ペインタブ名・ステータスラインの動的設定 API（人間が役割を直感判別できる）
  2. ユーザー入力待機状態の非同期通知 API（既存: `wez notify`）
  3. engine（自動制御）と人間（手動入力）の同一 TTY 操作の競合許容
  4. dashboard 向け状態取得 API（全セッションを一覧化）
  5. 人間の決定の監査ログ（pane_id + 入力内容 + タイムスタンプ、gpt 上乗せ）
- **設計判断**:
  - システム的なメッセージ通信ではなく WezTerm 物理 UI 特性を活用（gemini: 実用的）
  - 手入力でも監査可能な制御イベントとして記録（gpt: 観測性）

#### UC ハイブリッドの設計原則

- **基盤は gemini 案**: Bash 薄ラッパー前提、ファイルベース、ポーリング、TTY 直接操作。`wez` 既存 API を最大活用
- **gpt の上乗せ**: 状態語彙の閉集合 / registry / ledger / 監査ログ → 観測性を MVP から確保
- **MVP の到達点**: 3 UC それぞれが「人間が常駐せず 1 サイクル完走」を実証 + 監査ログで事後復元可能

### 6. MVP スコープ: G1〜G7 の扱い（書き換え）

**仮置き**:

| ギャップ | MVP 着手時の扱い |
|---|---|
| **G1 Negative Knowledge ledger** | MVP 外（4-5 で再評価）。**ただし失敗ログの粒度は後で ledger 化できる形式で記録**（gpt: G1 と G4 の循環） |
| **G3 State Semantics** | **MVP に部分含める**: skill / コマンドの `outputs:` 宣言と共有領域（KVS）の契約を最低限固定（gpt: 通信プロトコル以前の前提） |
| **G4 Failure Taxonomy 最小分類** | **MVP に含める**: `success / partial / retryable_failure / blocked / protocol_error / timeout` の 6 分類（両モデル一致） |
| **G6 Initializer Agent** | 完全版は MVP 外（4-5 で再評価）。**ただし initializer envelope（読む docs / 使う skill / 出力先 / 終了条件）は MVP に含める**（gpt: 人間常駐なしの成立条件） |
| **G5 Time budgeting** | **MVP に含める**（論点 12 に分離） |
| **G7 Orchestra** | MVP 外。設計研究段階 |

### 7. CLIラッパー4 層モデルとディスパッチャの責務範囲（論点 4 との整合）

**仮置き**: ディスパッチャは **CLI ラッパー層 + 最小限の解析ラッパー機能** を担う。

論点 4 との整合（arena: 矛盾指摘）:

- 論点 4 はオープンループ自律サイクル（ポーリング方式）に縮退したため、非同期 event-driven listener は MVP 不要
- ただし「ポーリングで取得した出力を構造化（装飾除去・状態抽出）」する処理は必要 → 解析ラッパー的責務の最小限版
- 汎用ツール（rtk 等）の導入はしない（個人開発環境での過剰統合回避、[#24 discussion](../../../../docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md)）

### 8. #22/#36 CLOSE 反映（4-3 検証ゲートの前提）

**仮置き**: 4-3 検証ゲートの前提として「exit code 契約」+ 論点 6 の **G4 最小分類** を組み合わせて使用。

- [#22](https://github.com/stlwolf/ai-development-hub/issues/22): so-compare.sh の exit code 分離（成功=0 / 部分成功=1 / 全失敗=2）
- [#36](https://github.com/stlwolf/ai-development-hub/issues/36): 多周制御の終了条件・ループ不変条件の仕様文書
- G4 最小分類 6 値とのマッピング: `0 → success`, `1 → partial`, `2 → retryable_failure or protocol_error`（タイムアウト・blocked は別軸で表現）

### 9. #20 Phase 2 との連携プロトコル

**仮置き**: concurrent（共同設計）推奨。

- 本 Discussion で UC 3 本と中間層プロトコル要件を確定（論点 5）
- [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 2 着手判断にこれらを共有
- 中間層プロトコルは 4-1 ディスパッチャ設計と [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 3 で合流
- 共同設計の成果物: 中間層プロトコル仕様（registry / KVS / 監査ログ / SLO）を engine 側 `decisions/` に ADR 化

### 10. MVP 完了後の dogfood 化判断基準

**仮置き**（4-5 で再評価）:

- 各論点（特に docs 配置）の運用ヒット率（実際に discussions/plans/episodes/decisions が活用されたか）
- 蒸留パイプラインの変更頻度（運用しながら必要な調整が出てきたか）
- engine 自身が「自プロジェクトの docs ルーティング」を制御できるか（dogfood 検証対象として成立するか）

### 11. 観測性・監査ログ・リプレイ可能性（新規、gpt 提起）

**仮置き**: MVP に含める。

- 人間が常駐しない MVP では、失敗時に「何が起きたか」を後から復元できないと運用不能（gpt: 事後復元）
- 監査ログの記録粒度: セッション registry の状態遷移 + UC ごとの主要イベント + 失敗分類（G4 最小分類）+ 人間割り込み
- リプレイ可能性: 監査ログから 1 サイクルの再構成ができる粒度を担保（コマンド単位の完全再現は MVP 外）
- 実装方針: JSON Lines を engine が `audit/` 配下に追記

### 12. 暴走防止・サーキットブレーカー（新規、gpt + gemini 共通）

**仮置き**: MVP に含める。

- セッション / タスク単位での絶対上限を MVP から導入:
  - **時間上限**: タスク開始から N 分（例: 30 分）
  - **ターン上限**: メインからの再投入回数 N 回（例: 10 回）
  - **ペイン数上限**: 同時稼働セッション N 個（例: 5 個）
  - **コスト上限**: optional、トークン推定値の累計上限
- 上限到達時の挙動: G4 最小分類の `timeout / blocked` で停止 → 人間判断要求 → 監査ログに記録（論点 11 と接続）

### 13. 権限分離・セキュリティ境界（新規、gemini 提起）

**仮置き**: MVP では「設計方針を ADR 化のみ」。実装は Phase 5 以降。

- spawn 時にサブエージェントへ破壊的操作の権限を引き継ぐかの境界設計
- MVP 範囲: 全サブが親と同等権限（個人開発環境前提）。ADR で「将来的に ReadOnly 制約や sandbox 化が必要になる前提条件」を明文化
- 実装トリガー: 共同開発 / チーム運用が始まったら Phase 5 以降で実装

### 14. クリーンアップ戦略・ゾンビペイン対応（新規、gemini 提起）

**仮置き**: MVP に含める。

- 親エージェント / engine がクラッシュ・タイムアウトした際の orphaned ペイン破棄
- 実装方針:
  - engine 起動時に `trap EXIT INT TERM` で全管理下ペインの kill を予約
  - registry から「engine の PID と紐づくペイン一覧」を取得し、engine 終了時に一括 `wez pane kill`
  - 異常終了時は監査ログに「クリーンアップ実行」を記録（論点 11 と接続）

### 15. Schema-driven Boundaries / Fail-fast（新規、gemini 提起）

**仮置き**: MVP に含める。

- エンベロープ構築時（4-1）および成果物パース時（4-2）に、`jq` 等による厳格スキーマ検証
- 検証失敗時は「即座に元エージェントに差し戻し」する fail-fast 設計
- 形式の揺れ（LLM 特有の余言、コードブロック囲み漏れ、YAML 不整合等）を後続プロセスに伝播させない
- 実装方針: 各エンベロープ・各成果物に JSON Schema を定義し、CI / 4-3 検証ゲートで `ajv` または `jq --exit-status` 相当でバリデーション

## 論点間の依存関係（arena 反映後）

```
5 (UC 3 本)  ← 起点。中間層要件を導出
  └→ 9 (#20 連携、中間層プロトコル要件確定)
       └→ 3 (3 層モデル責務確定)
            └→ 4 (#19 ゴール: オープンループ自律サイクル + 最小 SLO)

1 (docs 配置)
  └→ 1 → G3 → G6 → 10 (dogfood 化判断)

2 (research との関係) — 独立

6 (G1〜G7)
  ├→ G4 最小分類 → 8 (#22/#36 + 4-3 検証ゲート)
  ├→ G3 → 11 (観測性)、15 (Schema)
  └→ G5 → 12 (サーキットブレーカー)

7 (CLI ラッパー 4 層) — 4 (#19 ゴール) と整合。論点 4 縮退で矛盾解消

11 (観測性) — 12, 14 と接続
12 (サーキットブレーカー) — 11 と接続
13 (権限分離) — MVP は ADR のみ
14 (クリーンアップ) — 11 と接続
15 (Schema-driven) — 4-1, 4-2 の前提
```

## MVP に含むもの・含まないもの（まとめ）

### MVP に含む

- **UC 3 本** すべて（論点 5、ハイブリッド設計）
- **オープンループ自律サイクル + 最小 SLO**（論点 4）
- **G4 Failure Taxonomy 最小分類** 6 値（論点 6）
- **G6 Initializer Envelope**（読む docs / 使う skill / 出力先 / 終了条件、論点 6）
- **G3 State Semantics 部分**（`outputs:` 宣言 + 共有 KVS 契約、論点 6）
- **観測性・監査ログ**（論点 11）
- **暴走防止サーキットブレーカー**（論点 12、時間 / ターン / ペイン数）
- **クリーンアップ戦略**（論点 14、`trap` + registry）
- **Schema-driven Boundaries / Fail-fast**（論点 15）

### MVP に含まない（Phase 5 以降）

- リアルタイム event-driven bus（論点 4）
- G1 Negative Knowledge ledger 完全版（論点 6）
- G6 Initializer Agent 完全版（CATALOG 自動選択、論点 6）
- G7 Orchestra（論点 6）
- 権限分離・sandbox 化（論点 13、ADR のみ MVP）
- 解析ラッパー汎用化（rtk 相当、論点 7）

## arena ラウンド1 補足（モデル独自視点）

- **gpt**: 型安全性より先にイベント語彙の閉集合化が重要 → UC-1 の状態語彙 `spawn / ready / progress / done / blocked` に反映
- **gpt**: MVP に「リアルタイム」を入れるなら最小 SLO 必須 → 論点 4 に「最小 SLO」明記で反映
- **gemini**: Schema-driven Boundaries で fail-fast → 論点 15 に独立分離

## 次のステップ

1. Step 4-1（エンベロープ + ディスパッチャの骨格）の **KickOff** を `plans/` に作成
2. KickOff から `kickoff-to-plan` で Plan に展開
3. Plan 実行 → Episode に記録 → 設計判断は ADR に蒸留

なお Step 4-1 以降は本リポジトリの **観測層 vs 駆動層** 運用方針（[`projects/orchestration-engine/README.md`](../../README.md) §「観測層と駆動層の分離」参照）に従い、ドキュメント駆動で進める。Issue / コメントは外部観測（プロジェクト進捗の俯瞰）のための記録に留め、開発サイクル自体は本 docs 配下で完結させる。

## Appendix A: arena ラウンド1 結果サマリ

`tmp/arena-20260513-200204/summary.md` の主要結果を本 Discussion に永続化（`tmp/` は gitignore 対象のため）。

### 実行条件

- ツール: `arena-compare -w "$(pwd)" --mode plan -f /tmp/arena-prompt-4-0.txt`
- モデル: `gpt-5.5-medium` (113 秒) + `gemini-3.1-pro` (210 秒)
- 出力: gpt 71 行 / 9634 bytes、gemini 53 行 / 8932 bytes

### gpt-5.5-medium の主要指摘

- **State Semantics / 共有状態の契約**: 通信プロトコル以前に、どの状態を誰が生成・永続化し、次セッションが何を読めるかの契約が必要（G3 未カバー）
- **観測性・監査ログ・リプレイ可能性**: 人間が常駐しない MVP では事後復元できないと運用不能
- **Resource / Time budgeting**: 終了条件だけでなく時間・ターン・コスト・ペイン数の上限が必要（G5 未カバー）
- **通信プロトコルの信頼性契約**: message id / ack / 順序 / 重複 / タイムアウト / 再送 / interrupt 優先度を中間層に
- **依存関係 `5 → 9 → 4`**: UC が中間層プロトコル要件を決める入力。仮置きと逆転
- **論点 7 と論点 9 の衝突**: ディスパッチャを CLI ラッパー層までと限定すると、中間層が listener / ack / 構造化イベントを要求した時に矛盾
- **G1 と G4 の循環**: 失敗蓄積には分類が必要、分類育成には実行ログが必要
- **G4 最小版を MVP に**: `success / partial / retryable_failure / blocked / protocol_error / timeout` 程度の 6 分類
- **G6 完全版不要だが initializer envelope は必要**: 読む docs / 使う skill / 出力先 / 終了条件を固定
- **リアルタイム双方向通信は MVP に過剰**: `spawn → liveness/progress取得 → completion/blocked検知 → interrupt可能 → artifact handoff` で十分
- **独自視点**: 型安全性より先にイベント語彙の閉集合化が重要。MVP に「リアルタイム」を入れるなら最小 SLO を明記

### gemini-3.1-pro の主要指摘

- **ゾンビペイン問題**: 親エージェントクラッシュ時の子プロセス放置リスク。`trap` フックによる orphaned ペイン破棄が必要
- **権限分離・セキュリティ境界**: spawn 時にサブへ破壊的操作の権限を引き継ぐかの境界設計が抜けている
- **暴走ループ防止・サーキットブレーカー**: セッション/タスク単位での絶対的な実行回数・トークン上限
- **依存関係 `5 → 9 → 3, 4`**: gpt と同じ指摘
- **論点 4 と論点 7 の矛盾**: 「リアルタイム双方向」と「CLI ラッパー層まで」が強結合衝突
- **G4 除外のリスク**: 「リトライ可能/不可能」程度の最小限分類は MVP に不可欠
- **論点 4 過剰スコープ**: オープンループ（capture ポーリング方式）で十分自律サイクルは回せる、完全 event-driven は Phase 5 以降
- **独自視点**: Schema-driven Boundaries（jq 厳格検証 + fail-fast）を MVP 最優先要件に

### 採用済み（本 Discussion 反映）

- 論点 4 書き換え → §4 オープンループ自律サイクル + 最小 SLO
- 論点 6 分割 → §6 G4 最小分類 + G6 envelope + G3 部分 + G5 を MVP に
- 依存関係修正 → §「論点間の依存関係」グラフ
- 論点 5 UC ハイブリッド → §5 gemini ベース + gpt 観測性上乗せ
- 論点 7 と 4 の整合 → §7 ディスパッチャは CLI ラッパー + 最小解析
- 論点 11〜15 新規追加 → §11 観測性 / §12 サーキットブレーカー / §13 権限分離 / §14 クリーンアップ / §15 Schema-driven

### UC ハイブリッドのモデル別出典

| UC | 基盤（gemini） | 上乗せ（gpt） |
|---|---|---|
| UC-1 監督ループ | SIGINT + プロンプト注入、ポーリング監視 | 状態語彙閉集合 `spawn/ready/progress/done/blocked` + 監査ログ |
| UC-2 並列協調 | ファイルベース KVS + ブロッキング監視 | registry + ledger + ownership 宣言 + コンフリクト検出（#47 反映） |
| UC-3 人間俯瞰 | WezTerm 物理 UI + 直接 TTY 入力 + `wez notify` | dashboard API + 人間決定の監査ログ |

## 関連

- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19)
- Sub Issue: [#81](https://github.com/stlwolf/ai-development-hub/issues/81)
- 起点設計: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)
- 3 層モデル提起: [#20 issuecomment-4298073225](https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4298073225)
- arena 設計知見: [#20 issuecomment-4248077589](https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4248077589)
- arena ラウンド1 結果: `tmp/arena-20260513-200204/summary.md`
- CLI ラッパー 4 層: [`docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md`](../../../../docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md)
- Harness ギャップ: [#37](https://github.com/stlwolf/ai-development-hub/issues/37)
- 並列セッション要件: [#47](https://github.com/stlwolf/ai-development-hub/issues/47)

# Event & Reaction — イベント・リアクション

> **外部イベントにどう反応するか** を定める概念群。イベント駆動アーキテクチャ、Hooks、スケジューリングを扱う。

## この領域の問い

- エージェントの実行中に発生するイベントをどう記録・伝播するか
- 外部イベント（CI結果、PRレビュー等）にどう自動反応するか
- 特定のタイミングにカスタム処理をどう注入するか
- 定期実行をどう実現するか

## 核となる概念

### EventStream（イベントストリーム）

エージェントの全アクションと結果をappend-onlyログとして記録し、Pub/Subで配信する基盤。

| ツール | 用語 | 特徴 |
|---|---|---|
| OpenHands | `EventStream` | append-onlyイベントログ + Pub/Sub。スレッドセーフ。FileStore永続化。シークレット自動マスキング |
| OpenHands | `Action` / `Observation` | Action 10種、Observation 6種の型安全イベント |
| AutoGen | Topic-based Pub/Sub | `@event`（一方向通知）、`@rpc`（リクエスト/レスポンス） |
| MetaGPT | `Environment` | Pub/Subパターンでメッセージルーティング |
| Google ADK | AsyncGeneratorストリーム | イベント駆動アーキテクチャ |
| CrewAI | `EventBus` | オブザーバビリティ用イベントバス |
| BeeAI | `Emitter` | すべての実行にイベント発行 |

**EventStreamは最も汎用的なイベント基盤。** OpenHandsの実装（Action/Observation型、シークレットマスキング、FileStore永続化）が最も成熟している。

### Reactions（リアクション）

外部イベントに対する自動応答ルール。イベント→条件判定→アクション のパイプライン。

| ツール | 用語 | 特徴 |
|---|---|---|
| Agent Orchestrator | `Reactions` | 33種のイベントタイプ（session.*, pr.*, ci.*, review.*, merge.*, reaction.*）+ 4段階優先度（urgent/action/warning/info）。CI失敗→自動修正、レビュー→自動対応 |

**Agent OrchestratorのReactionsパターンは独自性が高い。** 33種のイベント×4段階優先度の組み合わせでCIパイプライン全体を自動化する設計。

### Hooks（フック）

エージェントのライフサイクルの特定タイミングにカスタム処理を注入するメカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| oh-my-claudecode | Hooks | `UserPromptSubmit`, `Stop`, `PostToolUse` 等のライフサイクルイベント |
| o-m-cc | Hooks (11イベント) | `Stop`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `SessionStart`, `TeammateIdle`, `TaskCompleted` 等 |
| Aider | `Watch Mode` | ファイル監視。`AI!` / `AI?` コメントで任意IDEから指示 |

### Scheduling（スケジューリング）

定期実行・条件付き実行のメカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| CAO | `Flow` | cron式スケジュール実行 + 条件付きスクリプト |
| TAKT | `Arpeggio` | データ駆動バッチ処理。音楽メタファの一部 |
| TAKT | `Task Queue` | `takt add` → `takt run` でキューイング→バッチ実行 |
| Agent Orchestrator | `Batch Spawn` | 複数issueを一括spawn |

### Messaging（メッセージング）

エージェント間の非同期メッセージ受け渡し。

| ツール | 用語 | 特徴 |
|---|---|---|
| CAO | `Inbox` / `Watchdog` | 非同期メッセージキューイング。IDLE検知で自動配信 |
| MetaGPT | `Message` / `cause_by` | メッセージの生成元Action型がルーティングキーになる |
| Agent Orchestrator | Event Priority (4段階) | urgent / action / warning / info |

## パターン・バリエーション

### イベント駆動の層構造

```
EventStream（基盤層）
    ↑
Reactions / Hooks（反応層）
    ↑
Scheduling / Messaging（配信層）
```

- **EventStream** がすべてのイベントを記録する基盤
- **Reactions/Hooks** がイベントに反応するルールを定義
- **Scheduling/Messaging** が配信タイミングと経路を制御

### Push vs Pull

- **Push（イベント駆動）**: Agent Orchestrator Reactions, o-m-cc Hooks。イベント発生時に自動実行
- **Pull（ポーリング）**: CAO Flow (cron)。定期的にチェック

### イベントの粒度

- **粗粒度（タスク単位）**: CrewAI EventBus, o-m-cc TaskCompleted
- **中粒度（ツール呼び出し単位）**: o-m-cc PreToolUse/PostToolUse
- **細粒度（Action/Observation）**: OpenHands EventStream（16種の型安全イベント）

## 独自レイヤーとの接点

- **コンテキスト・エンベロープ**: original_intent + trajectory + payload のJSON構造は、EventStreamの上位抽象として機能する。OpenHandsのEventStream設計が最も近い参考
- この領域は [05 State & Memory](./05-state-memory.md) と連携する。EventStreamの永続化がメモリの一部となる

# Human Interaction — 人間介入

> エージェントの実行フローに **人間がどこで・どう関与するか** を定める概念群。

## この領域の問い

- エージェントの実行をどのタイミングで一時停止できるか
- 人間の承認をどう求め、結果をどうフローに反映するか
- 中断した実行をどう再開・巻き戻しするか

## 核となる概念

### Interrupt / Suspend（中断 / 一時停止）

エージェントの実行を任意のポイントで一時停止する。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | `interrupt` | グラフの任意ノードで実行を停止。状態はCheckpointに保存 |
| Mastra | `suspend` | ステップ単位の一時停止 |
| CrewAI | `Flow Persistence` | フロー状態を永続化して一時停止 |

### Approval（承認）

特定のアクションやツール呼び出しの前に人間の承認を求める。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | Approval パターン | `interrupt` + `Command` で承認フローを実装 |
| PydanticAI | `ToolApproved` / `ToolDenied` | ツール実行前の承認フロー |
| BeeAI | `AskPermissionRequirement` | 宣言的制約として承認を要求 |
| OpenAI Agents SDK | ツール実行前承認 | ツール呼び出し前に人間の確認を挟む |
| CrewAI | `human_input=True` | エージェントレベルで人間入力を有効化 |

### Resume / Continue（再開 / 続行）

中断した実行を再開する。人間のフィードバックを反映して続行する場合を含む。

| ツール | 用語 | 特徴 |
|---|---|---|
| LangGraph | `Command` | 状態更新 + ノード遷移指示 + resume値を1オブジェクトで表現 |
| Mastra | `resume` | 一時停止からの再開 |
| CrewAI | `flow/human_feedback` | 人間のフィードバックを受けて続行 |

**LangGraphの `Command` は最も洗練された再開メカニズム。** 単なる「続行」ではなく、状態の書き換えとルーティング変更を同時に行える。

### Rewind（巻き戻し）

過去の実行ポイントに戻り、異なる選択でやり直す。

| ツール | 用語 | 特徴 |
|---|---|---|
| Google ADK | `Session Rewind` | 指定invocation IDまで巻き戻し。状態・アーティファクトも復元 |
| LangGraph | `Time Travel` | チェックポイント履歴を遡り、任意の地点から実行をフォーク |

**Rewindは「やり直し」を可能にする拡張。** 単なるUndo（1ステップ戻る）ではなく、任意の時点への巻き戻し + 分岐が可能。

### Human-as-Agent（人間をエージェントとして扱う）

人間をマルチエージェントシステムの一員として参加させるパターン。

| ツール | 用語 | 特徴 |
|---|---|---|
| AutoGen | `UserProxyAgent` | 人間の代理として会話に参加するエージェント |
| ControlFlow | `Turn Strategy: Moderated` | 人間がモデレーターとして次の発言者を選択 |

## パターン・バリエーション

### 介入の基本フロー

```
Interrupt → Approve/Deny → Resume (with feedback)
    │            │               │
    LangGraph    PydanticAI      LangGraph Command
    Mastra       BeeAI           Mastra resume
    CrewAI       OpenAI SDK      CrewAI feedback
```

ほとんどのツールがこの **Interrupt → Approve → Resume** パターンを共有する。差異は各ステップの実装粒度。

### 介入ポイントの粒度

- **ノード/ステップ単位**: LangGraph, Mastra。任意のグラフノードで中断可能
- **ツール呼び出し単位**: PydanticAI, OpenAI SDK。危険なツール実行前に承認
- **タスク完了単位**: CrewAI。タスク結果に対してフィードバック
- **フロー全体**: CrewAI Flow Persistence。フロー状態ごと永続化して後日再開

### 能動的 vs 受動的

- **受動的介入**: エージェントが承認を要求し、人間が応答する（多くのツール）
- **能動的介入**: 人間がいつでもフローに割り込める（LangGraph Time Travel, Google ADK Session Rewind）

## 独自レイヤーとの接点

- **認知協調（セカンドオピニオン）**: Human Interactionの拡張。人間ではなく「別のエージェント」に判断を求める点が異なるが、Interrupt → Review → Resume のフロー構造は同じ
- この領域は [06 Feedback & Validation](./06-feedback-validation.md) と密接に関連する。人間介入は「最も信頼性の高いフィードバックメカニズム」

---
name: ControlFlow
repo: PrefectHQ/ControlFlow
last_reviewed: 2026-02-22
category: framework
---

## ControlFlow (Prefect) 調査結果

### 基本情報
- **リポジトリ:** https://github.com/PrefectHQ/ControlFlow
- **言語:** Python
- **最終更新:** 2025-08-22（アーカイブ日）
- **規模:** 1,388 stars / 115 forks / 20 contributors / v0.12.1
- **ライセンス:** Apache 2.0
- **主要作者:** Jeremiah Lowin (Prefect CEO)
- **一言で:** Prefect 3.0上に構築された、タスク中心のPythonic AIエージェントワークフローフレームワーク

> **重要:** ControlFlowは**2025年8月にアーカイブ**され、次世代エンジンが [Marvin 3.0](https://github.com/prefecthq/marvin) に統合された。現在は読み取り専用。

### これは何か・何を解決するのか

「LLMエージェントを既存のPythonコードに自然に埋め込む」ためのフレームワーク。従来の「エージェントファースト」設計に対し、**「タスクファースト」**のアプローチを取る。

**解決する問題:**
1. **制御と信頼:** エージェントに自律性を与えつつ、開発者が介入できるポイントを維持
2. **可観測性:** LLMの意思決定プロセスを追跡・デバッグ可能にする（Prefect 3.0基盤を活用）
3. **オーケストレーション:** 複数AIエージェントが動的にタスクを生成・実行する複雑なワークフローの管理

### 設計思想・アーキテクチャ

**コア抽象は3つ:**

| 概念 | 役割 |
|------|------|
| **Task** | 「何をすべきか」の離散的な単位。型安全な結果を持つ |
| **Agent** | 「どうやるか」を決めるLLMエンティティ |
| **Flow** | タスクとエージェントを束ねる上位コンテナ |

**設計哲学:**
- `@cf.flow` デコレータで通常のPython関数をAIワークフロー化。AI処理と非AI処理を自由に混在可能
- タスクの成功/失敗はLLMの「tool call」として実装（`mark_task_{id}_successful` / `mark_task_{id}_failed`）
- Pydantic-nativeの型安全性。`result_type` で出力を自動バリデーション
- v0.9でイベントベースのオーケストレーターに書き直し

**ディレクトリ構造:**

```
src/controlflow/
├── agents/           # Agent定義
├── events/           # イベントシステム（base, history, message_compiler, task_events）
├── flows/            # Flow定義
├── handlers/         # イベントハンドラー（print, callback, queue）
├── llm/              # LLMモデル管理、モデル固有ルール
├── memory/           # ベクトルDBメモリ（Chroma, LanceDB, Postgres）
├── orchestration/    # オーケストレーター、ターン戦略、終了条件
├── planning/         # LLMベースの自動プラン生成
├── tasks/            # Task定義（status, depends_on, parent/subtask）
├── tools/            # ツール定義
├── tui/              # 実験的TUI（textual）
├── decorators.py     # @flow, @task
├── instructions.py   # コンテキストマネージャベースの動的指示
├── plan.py           # cf.plan()
├── run.py            # cf.run(), cf.run_tasks()
└── settings.py       # pydantic-settings
```

**依存スタック:** `prefect>=3.0`, `langchain_core>=0.3`, `pydantic>=2`, `jinja2`, `textual`, `tiktoken`

### 機能一覧

#### コア機能

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Task定義と実行** | `cf.run()`で1行タスク実行、`cf.Task()`で明示的オブジェクト。`result_type`で型安全 | `tasks/task.py`, `run.py` | コア |
| **Agent定義** | 名前・instructions・ツール・モデル。`interactive=True`でユーザー対話可能 | `agents/agent.py` | コア |
| **Flow管理** | `@cf.flow`デコレータ。会話履歴・スレッドの共有コンテキスト | `flows/flow.py` | コア |
| **タスク依存関係** | `depends_on=[task_a]`で明示的依存。`parent`でサブタスク階層 | `tasks/task.py` | コア |
| **マルチエージェント・ターン戦略** | Popcorn, RoundRobin, Random, MostBusy, Moderated, SingleAgent の6戦略 | `orchestration/turn_strategies.py` | コア |
| **実行終了条件** | AllComplete, AnyComplete, AnyFailed, MaxLLMCalls, MaxAgentTurns。`|` `&`で合成可能 | `orchestration/conditions.py` | コア |

#### 差別化機能

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Prefect統合可観測性** | 全cf.flowがPrefectフローとして実行。LLM呼び出しごとにMarkdownアーティファクト生成 | `utilities/prefect.py` | 差別化 |
| **LLMベース自動プラン生成** | `cf.plan()`が目的から依存関係付きタスクリストを自動生成 | `plan.py` | 差別化 |
| **構造化結果 + カスタムバリデーション** | `result_type=MyPydanticModel` + `result_validator`でカスタム検証 | `tasks/task.py` | 差別化 |
| **Labels（選択肢）** | `result_type=["option_a", "option_b"]`でLLMに選択を強制 | `tasks/task.py` | 差別化 |
| **ベクトルDBメモリ** | Chroma（ephemeral/persistent/cloud）、LanceDB、Postgres | `memory/` | 差別化 |
| **動的instructions** | `with cf.instructions("日本語で回答"):`でスコープ内の全タスクに追加指示注入 | `instructions.py` | 差別化 |
| **completion_agents** | タスクを完了可能なエージェントを制限 | `tasks/task.py` | 差別化 |

#### ユーティリティ

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **ストリーミング** | `stream=True`でイベントイテレータ | `stream.py` | ユーティリティ |
| **非同期サポート** | `cf.run_async()` | `run.py` | ユーティリティ |
| **イベントハンドラー** | PrintHandler, CallbackHandler, QueueHandler | `handlers/` | ユーティリティ |
| **ネストフロー** | 子フローが親のイベント履歴を継承 | `flows/flow.py` | ユーティリティ |
| **マルチLLM** | OpenAI, Anthropic, Google Gemini, Groq, Ollama（LangChain経由） | `llm/` | ユーティリティ |
| **実験的TUI** | textualベースのターミナルUI | `tui/` | ユーティリティ |

### 特徴的な点・注目ポイント

**1. タスクとしてのtool call完了メカニズム**

最もユニークな設計。タスクの成功/失敗をLLMのtool callとして実装。各タスクに `mark_task_{id}_successful(result: ResultType)` と `mark_task_{id}_failed(reason: str)` のツールが自動生成される。`result_type`がPydantic BaseModelならプロパティがkwargsに、Labelsならインデックス選択に変換。

**2. Prefectによるネイティブ可観測性**

`@prefect_task`デコレータにより全LLM呼び出しがPrefect task runとして記録。各呼び出しでMarkdownアーティファクト生成。Prefect UIで閲覧・デバッグ可能。

**3. 合成可能な実行終了条件**

`|`（OR）と `&`（AND）演算子をサポート。`AllComplete() | MaxLLMCalls(100)` のように条件を合成。カスタム関数条件も `FnCondition` で追加可能。

**4. 既存Pythonコードとのシームレスな混在**

`@cf.flow`内で通常Python関数とAIタスクを自由に混在可能。「AIを呼ぶための専用DSL」ではなく「既存コードにAIを埋め込む」思想。

### 使い方・典型的なワークフロー

```python
import controlflow as cf

# 最小構成
result = cf.run("Write a short poem about AI")

# 構造化出力 + 依存関係
@cf.flow
def analysis_flow(data: str):
    summary = cf.run("Summarize the data", context=dict(data=data))
    analysis = cf.run(
        "Perform detailed analysis",
        result_type=Analysis,
        depends_on=[summary],
    )
    return analysis

# マルチエージェント
from controlflow.orchestration.turn_strategies import Moderated

@cf.flow
def report_flow(topic: str):
    research = cf.run("Research", agents=[analyst])
    report = cf.run(
        "Write report",
        agents=[writer, analyst],
        turn_strategy=Moderated(moderator=supervisor),
        depends_on=[research],
    )
    return report
```

### エコシステム・実利用状況

- **採用事例:** Prefect社内での利用が主。公開プロダクション事例は確認できず
- **盛り上がりの文脈:** Prefect 3.0と同時期に公開。Prefectの知名度の後押しで注目されたが、独立プロジェクトとしての採用拡大前にMarvinへ統合
- **コミュニティ:** Prefect Slackが主チャネル。40件のオープンIssueがアーカイブ時に残存。日本語圏での言及はほぼなし
- **周辺ツール:** Marvin 3.0が後継。構造化出力ユーティリティとエージェントエンジンが統合
- **評判:**
  - 肯定的: 「Pythonコードに自然にAIを埋め込める」「Prefectの可観測性が強力」「タスク中心設計が直感的」
  - 否定的: 「LangChain依存が重い」「Prefect 3.0前提でスタンドアロン利用困難」「アーカイブ済みでlong-term support不明」

### 他ツールとの比較・ポジショニング

| 観点 | ControlFlow | LangGraph |
|------|-------------|-----------|
| コア抽象 | Task/Agent/Flow（タスク中心） | Graph/State/Node/Edge（グラフ中心） |
| 設計思想 | 既存Pythonコードにエージェントを埋め込む | 状態遷移グラフで制御フローを明示定義 |
| 制御粒度 | タスク依存 + ターン戦略で間接制御 | ノード・エッジ・条件分岐で直接記述 |
| 可観測性 | Prefect 3.0ネイティブ（UI/Cloud） | LangSmith（有料Cloud） |
| 学習曲線 | 低い（Python関数 + デコレータ） | 中〜高（グラフ定義要） |
| 成熟度 | v0.12.1 → **アーカイブ済み** | v1.0.9、活発に開発 |

### 制約・注意点

1. **アーカイブ済み（最重要）:** バグ修正やセキュリティパッチの提供なし。Marvin 3.0検討推奨
2. **LangChain依存:** `langchain_core>=0.3` が必須
3. **Prefect 3.0前提:** 可観測性にはPrefect Server/Cloudの運用が必要
4. **Marvin 3.0への移行パス:** `@cf.flow` → `marvin.Thread` 等。APIは類似だが完全互換ではない
5. **本番事例の不足**
6. **40件のオープンIssue:** ストリーミング不整合、Prefectとのログ問題等が未解決

### 深掘り候補（コードリーディング対象）

| パス | 読む価値 |
|------|---------|
| `orchestration/orchestrator.py` | メインループ。タスク選択→エージェント割当→LLM呼び出し→イベント処理 |
| `tasks/task.py` L616-L769 | `get_success_tool()` — 型に応じた完了ツール動的生成 |
| `orchestration/prompt_templates.py` | プロンプト構築ロジック |
| `events/message_compiler.py` | イベント履歴→LLMメッセージのコンパイル |
| `plan.py` | LLMによる自動プラン生成のプロンプトエンジニアリング |
| `memory/providers/` | ベクトルDB統合（Chroma, LanceDB, Postgres） |
| `llm/rules.py` | モデル固有のルール推論ロジック |

# orchestration-research

エージェントオーケストレーション・並列エージェントツール群のランドスケープ調査プロジェクト。

## 目的

既存OSSのオーケストレーションツールを体系的に調査し、設計パターン・概念・実装方式を抽出する。抽出した要素を自分の検証知見（認知協調・知識永続化）と合成し、自前のオーケストレーションツール構築の設計基盤とする。

## 背景

- ideas/ と projects/ で蓄積してきた独自の概念（セカンドオピニオン、ルーラーエージェント、4層コンテキストモデル、正準エージェント定義等）は、OSSが手を付けていない「セマンティック層」に位置する
- 一方、OSSが厚く実装している「インフラ層」（ワークスペース隔離、プロセス管理、イベント駆動フィードバック）は自前で書く必要がない
- OSSのインフラ層の設計パターンを抽出し、自分のセマンティック層と組み合わせることで、検証に使える自前ツールの構築を目指す

## 構成

```
orchestration-research/
├── README.md              # このファイル
├── landscape/             # OSSリサーチの集約（ツール単位）
├── concepts/              # 抽出した共通パターン・概念
└── synthesis/             # 自分の構想との統合設計ノート
```

### landscape/

各OSSツールの調査結果を統一フォーマットで記録。横断比較を可能にする。

統一フォーマット:

```markdown
---
name: <ツール名>
repo: <owner/repo>
last_reviewed: <YYYY-MM-DD>
category: <orchestrator | framework | agent-runtime>
---

## 概要
（1-2行の要約）

## アーキテクチャ
（主要コンポーネントと接続関係）

## 主要概念
（このツール固有の設計判断・パターン）

## 自分の構想との対応
（どの要素が使えるか、何が足りないか）
```

### concepts/

複数のOSSに共通して見られるパターンを抽出・整理。ツール非依存の概念として記録する。

### synthesis/

OSSから抽出した要素と、自分の独自レイヤー（認知協調・知識永続化）を統合する設計ノート。ここが最終的に自前ツール構築の設計文書になる。

## 調査対象（候補）

### タスクディスパッチ型

| ツール | repo | 特徴 |
|--------|------|------|
| agent-orchestrator | ComposioHQ/agent-orchestrator | プラグインアーキテクチャ、worktree隔離、reactionsパターン |
| Claude Code /task | （組み込み） | Cursor/Claude Codeのサブエージェント機能 |

### ワークフロー/状態管理型

| ツール | repo | 特徴 |
|--------|------|------|
| LangGraph | langchain-ai/langgraph | グラフベース状態遷移、チェックポイント/リジューム |
| Mastra | mastra-ai/mastra | MCP統合、TypeScript native |

### 役割ベース型

| ツール | repo | 特徴 |
|--------|------|------|
| CrewAI | crewAIInc/crewAI | role/goal/backstory モデル、タスク依存関係 |
| AutoGen | microsoft/autogen | 会話ベース協調、メッセージパッシング |

### 自律コーディング型

| ツール | repo | 特徴 |
|--------|------|------|
| SWE-agent | princeton-nlp/SWE-agent | 観察→仮説→実行→検証ループ |
| OpenHands | All-Hands-AI/OpenHands | ブラウザ統合、サンドボックス実行 |
| Aider | Aider-AI/aider | git統合、差分ベースの編集 |

## 自分の独自レイヤー（OSSにないもの）

調査時の比較軸として。OSSがこれらをどの程度カバーしているかを各 landscape/ で評価する。

- **認知協調**: セカンドオピニオン、ルーラーエージェント（判断履歴ナビゲーション）
- **知識永続化**: 4層コンテキストモデル、昇格フロー（episodes → decisions → context）
- **ドキュメント設計**: write:read比率による構造化判断、目的指示 vs 手段指示
- **エージェント定義**: 正準フォーマット（ツール非依存）、ルール分割粒度
- **コンテキスト・エンベロープ**: original_intent + trajectory + payload のJSON構造

## 関連資料

| 資料 | 関係 |
|------|------|
| [ideas/20260204/ai-agent-orchestration.md](../../ideas/20260204/ai-agent-orchestration.md) | CLI連携の初期検証。マルチエージェントの本質分析 |
| [ideas/20260208/ai-orchestration-synthesis-next-steps.md](../../ideas/20260208/ai-orchestration-synthesis-next-steps.md) | 棚卸しと次の一手。「契約で固定、ツール名で固定しない」原則 |
| [ideas/20260212/hypothesis-canonical-agent-definition-format.md](../../ideas/20260212/hypothesis-canonical-agent-definition-format.md) | 正準エージェント定義フォーマットの仮説 |
| [ideas/20260220/context-persistence-4layer-model.md](../../ideas/20260220/context-persistence-4layer-model.md) | 4層コンテキスト永続化モデル |
| [ideas/20260221/document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) | ドキュメントフォーマット設計原則 |
| [ideas/20260222/orchestration-tool-building-approach.md](../../ideas/20260222/orchestration-tool-building-approach.md) | このプロジェクトの着想（OSSリサーチ→要素抽出→自前構築のアプローチ） |
| [projects/agent-rule-decomposition/](../agent-rule-decomposition/) | ルール分割検証。エージェントへのルール配布の設計に関連 |
| [projects/ruler-agent-verification/](../ruler-agent-verification/) | ルーラーエージェント検証。認知協調レイヤーの実装に関連 |

## 状態

ひな形作成段階。landscape/ への調査ドキュメント追加から開始予定。

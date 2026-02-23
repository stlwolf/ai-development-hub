# Cost Optimization — コスト最適化パターン

> LLM利用コスト（トークン消費・API呼び出し）を最適化する設計パターン群。

**横断する領域**: [01 Agent Definition](../domain/01-agent-definition.md)（モデル選択）+ [02 Routing & Delegation](../domain/02-routing-delegation.md)（タスク別モデルルーティング）+ [05 State & Memory](../domain/05-state-memory.md)（コンテキスト圧縮）

## なぜ横断的か

コスト最適化は「どのモデルを使うか」（01）、「どのタスクに高いモデルを割り当てるか」（02）、「コンテキストをどう圧縮するか」（05）を横断して設計する必要がある。

## パターン

### Model Routing by Cost（コスト意識型モデルルーティング）

タスクの種類や重要度に応じて、異なるコストのモデルを使い分ける。

| ツール | 方式 | 特徴 |
|---|---|---|
| oh-my-claude-code | `COST_LEVELS` | FREE → CHEAP → EXPENSIVE の段階的エスカレーション（haiku → sonnet → opus） |
| TAKT | `Persona Providers` | ペルソナ単位でプロバイダー/モデルを切り替え（coder=Codex, reviewer=Claude） |
| TAKT | `Provider Profiles` | プロバイダー別の5段階優先度解決 |

**oh-my-claude-codeの段階的エスカレーション**:
```
1. FREE (haiku): 単純なフォーマット変換、分類
2. CHEAP (sonnet): 標準的なコード生成、レビュー
3. EXPENSIVE (opus): 複雑な推論、アーキテクチャ判断
```

**洞察**: タスク種別による自動エスカレーションは、ルーティング（02）の設計とセットで考える必要がある。

### Context Compression（コンテキスト圧縮）

コンテキストウィンドウの使用量を減らし、トークンコストを削減する。

| ツール | 方式 | 特徴 |
|---|---|---|
| o-m-cc | Progressive Disclosure | frontmatter→本文→参照ファイルの3段階。**-33%トークン削減** |
| Aider | Repository Map | PageRank + tree-sitterでコードベースの重要部分のみ選択。`max_map_tokens` 内で二分探索 |
| OpenHands | Memory / Condenser | LLM要約によるコンテキスト圧縮 |
| SWE-agent | HistoryProcessor | LLMコンテキスト窓を最大活用する履歴圧縮 |
| PentAGI | Summarizer | チェイン要約（コンテキストオーバーフロー防止） |
| BeeAI | メモリ戦略 (4種) | Unconstrained / Sliding Window / Summarize / Token-based |

**圧縮戦略の比較**:

| 戦略 | コスト | 精度 | 代表 |
|---|---|---|---|
| ウィンドウ制限 | なし | 低（古い情報喪失） | BeeAI Sliding Window |
| 構造的選択 | なし | 中（重要部分のみ） | Aider Repository Map |
| 段階的開示 | なし | 中〜高（必要時に展開） | o-m-cc Progressive Disclosure |
| LLM要約 | 要約にLLMコスト | 高（意味を保持） | OpenHands Condenser |

### Token Budget Management（トークン予算管理）

実行全体のトークン使用量に上限を設け、予算内で最適化する。

| ツール | 方式 | 特徴 |
|---|---|---|
| SWE-agent | `per_instance_cost_limit` | インスタンスあたりのコスト上限 |
| AutoGen | `TokenUsage` 終了条件 | トークン使用量での実行終了 |
| Aider | `max_map_tokens` | Repository Mapのトークン予算。二分探索で予算内に収める |

### Caching（キャッシュ）

同一入力への重複呼び出しを回避する。

| ツール | 方式 | 特徴 |
|---|---|---|
| LangGraph | `CachePolicy` | タスク結果のキャッシュ。TTL設定可能 |

## コスト最適化の3レイヤー

```
Layer 1: Model Selection（モデル選択）
  - タスク種別に応じたモデル割り当て
  - 段階的エスカレーション

Layer 2: Context Management（コンテキスト管理）
  - 圧縮（要約、ウィンドウ制限）
  - 選択（構造的選択、段階的開示）

Layer 3: Execution Control（実行制御）
  - トークン予算上限
  - キャッシュ
  - 終了条件による早期停止
```

## 独自レイヤーとの接点

- **4層コンテキストモデル**: episodes → decisions → context の昇格フローは、本質的にコンテキスト圧縮パターン。「何を覚えておくか」の判断がコスト最適化に直結
- **ドキュメント設計原則**: write:read比率に基づく構造化は、Progressive Disclosureと同じ設計哲学。読み手（LLM）にとっての最適な情報量を制御する

# Context Foundation — コンテキスト基盤の統合設計ノート

> 独自概念「4層コンテキストモデル」とOSSの State & Memory パターンを突き合わせ、自前ツールのコンテキスト基盤を設計する。

## 方針決めの合意事項

- **最優先概念**: コンテキスト基盤。他の独自概念（認知協調、ルーラーエージェント等）の土台
- **構築アプローチ**: 未定だが、重いフレームワーク依存とベンダーロックインは避ける
- **ターゲット**: 個人→チーム→OSS化も視野。スケーラブルな自律開発フロー
- **過去検証の知見を統合する**

## 1. 現状の4層モデル（ideas/20260220 より）

```
層1: 即時参照（GitHub Issue 本文 / コメント）
  - エージェントが gh api で即取得
  - 「契約書」: what（本文）、how（コメント）、learned（FB）

層2: 構造化ナレッジ（独自ドキュメントシステム）
  - レトロスペクティブ、プランテンプレート、エピソード記録
  - 再利用頻度の高い知見。AI ツールのコンテキスト設定とは独立

層3: 生ログ（SO stdout、会話エクスポート）
  - 抽出パイプラインがないと死蔵する
  - 「なぜその判断に至ったか」はここにしかない
  - 抽出後は破棄可能

層4: コード + コミット履歴
  - 「何を変えたか」はここにある。「なぜ変えたか」はない
  - Refs # による Issue リンクが層1への参照として機能
```

### 現時点の制約（元ドキュメントより）

- 層3の抽出パイプラインは未実装
- 実働しているのは層1（Issue）+ 層2（手動作成）+ 層4（コード）の3層
- 層3の自動化は将来構築

## 2. OSSが実装しているパターン（concepts/05-state-memory.md より）

| OSSパターン | 4層モデルとの対応 | ギャップ |
|---|---|---|
| **Checkpoint** (LangGraph) | 該当なし | 4層モデルは「実行状態の保存」を扱っていない。実行の再開・巻き戻しの概念が欠如 |
| **Working Memory** (Mastra) | 層1に近い | 層1はIssue固定だが、Working Memoryは汎用的なスクラッチパッド |
| **Long-term Memory** (CrewAI, Mastra) | 層2に近い | 層2は手動昇格だが、OSSは自動圧縮（Observational Memory）を持つ |
| **Context Compression** (OpenHands, BeeAI) | 層3→層2の昇格に対応 | OSSは「圧縮」、4層モデルは「昇格」。方向は同じだが設計思想が異なる |
| **Knowledge/RAG** (Aider, PentAGI) | 層2の参照メカニズム | 4層モデルにRAG/ベクトル検索の概念がない |
| **VCS-based Knowledge** (o-m-cc, Aider) | 層4に直接対応 | o-m-ccのHANDOVER.mdが層4の知見活用として参考 |
| **Session Management** (Google ADK, OpenAI SDK) | 層1のセッション版 | 4層モデルはセッション管理を扱っていない |

### 4層モデルに足りないもの

1. **実行状態（Checkpoint）**: タスクの「どこまでやったか」の保存・復元。並列エージェントの状態管理に必須
2. **自動昇格メカニズム**: 層3→層2の「昇格ルール」は定義されているが、実装パスがない。Mastra Observational Memory（Observer/Reflector自動圧縮）が参考
3. **検索・参照メカニズム**: RAG / ベクトル検索 / グラフ検索。PentAGIのGraphiti（6種検索）が最も体系的
4. **セッション管理**: エージェントの実行コンテキストのライフサイクル

## 3. 関連プロジェクトの知見

### ruler-agent-verification（ルーラーエージェント検証）

- ルーラーは「過去の判断履歴から関連コンテキストを自動選定する」エージェント
- **コンテキスト基盤への要求**: ルーラーが機能するには、層2（構造化ナレッジ）の検索・参照メカニズムが必須
- 現在はGeminiに `--include-directories` で丸ごと渡している → スケールしない
- **示唆**: 「何を添付すべきか」の動的判断 = コンテキスト基盤の検索API

### agent-rule-decomposition（ルール分割検証）

- ルールの「どの役割にどの粒度で渡すか」問題
- Agent Orchestratorの知見: 分割軸は「関心」であって「重要度」ではない。重複ゼロ
- **コンテキスト基盤への要求**: エージェントの役割に応じてコンテキストを動的に選択・フィルタする仕組み
- **示唆**: PydanticAIのToolset合成（Filter, Prefix, Rename）と同じ設計が、コンテキスト配布にも必要

### orchestration-tool-building-approach（全体構想）

- セマンティック層（独自）× インフラ層（OSS）の非対称性を活かす
- **「Runログと決定の分離」**: 自動生成のRunログ（層3）と人間レビュー済みのSSOT（層2）を分ける
- **GUI構想の「昇格操作」**: Runから決定に昇格 = 層3→層2の昇格フローのUI化

## 4. 再設計: コンテキスト基盤の関心事分離

4層モデルの「層」は実はデータの保管場所による分類。しかしオーケストレーションツールとしてのコンテキスト基盤には、**保管場所とは直交する関心事**がある。

### 関心事A: コンテキストの種類（What）

元の4層を種類で再整理すると:

| 種類 | 説明 | 元の4層 | OSSでの呼称 |
|---|---|---|---|
| **Task Context** | 今のタスクの入力・指示・制約 | 層1（Issue） | Working Memory |
| **Decision Record** | 過去の意思決定とその根拠 | 層2（構造化ナレッジ） | Long-term Memory |
| **Execution Trace** | エージェントの行動ログ・会話ログ | 層3（生ログ） | Trajectory / EventStream |
| **Codebase Knowledge** | コードの構造・変更履歴 | 層4（コード） | Repository Map / VCS Knowledge |
| **Run State** | タスクの実行状態（どこまでやったか） | （欠如） | Checkpoint / Session |

### 関心事B: コンテキストのライフサイクル（When）

| フェーズ | 操作 | 設計判断 |
|---|---|---|
| **生成** | タスク開始時、実行中に生成される | 自動 vs 手動 |
| **保存** | どこに、どのフォーマットで | ファイル / DB / VCS |
| **検索・参照** | 必要なコンテキストをどう見つけるか | 全文検索 / RAG / グラフ / frontmatter索引 |
| **昇格・圧縮** | 生ログ→構造化ナレッジ | 自動要約 / 人間レビュー / ハイブリッド |
| **配布** | どのエージェントにどの粒度で渡すか | 静的割り当て / 動的選択 / Progressive Disclosure |
| **失効・アーカイブ** | 古くなったコンテキストの扱い | TTL / バージョニング / 手動レビュー |

### 関心事C: コンテキストのスコープ（Who）

| スコープ | 説明 | 例 |
|---|---|---|
| **タスクスコープ** | 1つのタスク内で閉じる | Issue本文、タスク指示 |
| **セッションスコープ** | 1つの実行セッション内 | 会話履歴、Working Memory |
| **プロジェクトスコープ** | プロジェクト全体で共有 | CONVENTIONS.md、ADR、エピソード |
| **グローバルスコープ** | プロジェクトを跨いで共有 | ユーザールール、汎用テンプレート |

## 5. 設計判断（要議論）

### Q1: 保存フォーマット

| 選択肢 | 利点 | 制約 | OSSでの採用 |
|---|---|---|---|
| **Markdown + frontmatter** | 人間が読める、git管理可能、CLI親和性 | 構造化検索が弱い | o-m-cc (HANDOVER.md) |
| **JSONL** | 構造化、パース容易、append-only | 人間が読みにくい | OpenHands (EventStream) |
| **SQLite** | クエリ柔軟、単一ファイル | git diffが効かない | OpenAI SDK (Session), PydanticAI |
| **ハイブリッド** | 種類に応じて使い分け | 複雑性が増す | — |

**暫定判断**: ハイブリッド。Decision Record/Codebase Knowledge はMarkdown + frontmatter（人間レビュー対象）。Execution Trace/Run State はJSONL（機械処理対象）。全体構想の「SSOTはCLI/ファイルに置く」原則と合致。

### Q2: 検索・参照メカニズム

| 選択肢 | 用途 | コスト | OSSでの採用 |
|---|---|---|---|
| **frontmatter索引** | Decision Recordの分類・フィルタ | 低 | o-m-cc |
| **全文検索 (rg/grep)** | コードベース・ドキュメント内検索 | 低 | Aider, SWE-agent |
| **tree-sitter + PageRank** | コード構造マップ | 中 | Aider (Repository Map) |
| **RAG (ベクトル検索)** | 意味的類似度による検索 | 高（embedding生成コスト） | PentAGI (Graphiti), CrewAI |
| **知識グラフ** | エンティティ関係の探索 | 高（Neo4j等の外部依存） | PentAGI (Graphiti) |

**暫定判断**: MVP段階では frontmatter索引 + 全文検索。ルーラーエージェントが必要とする「関連コンテキスト自動選定」は、まず単純な手法（frontmatter tags + rg）で検証し、精度が不足すればRAGを追加する段階的アプローチ。

### Q3: 昇格メカニズム（層3→層2）

| 選択肢 | 品質 | コスト | OSSでの採用 |
|---|---|---|---|
| **手動（人間レビュー）** | 高 | 人的コスト高 | 現状の運用 |
| **自動要約（LLM）** | 中 | LLMコスト | OpenHands (Condenser), PentAGI (Summarizer) |
| **Observer/Reflector** | 中〜高 | LLMコスト + 設計複雑 | Mastra (Observational Memory) |
| **テンプレート抽出** | 中 | 低（パターンマッチ） | — |

**暫定判断**: テンプレート抽出（構造化された部分の自動抽出）+ 人間レビュー のハイブリッド。cursor-thread-tools のエクスポート機能が層3→層2の抽出パイプラインの原型として使える可能性。

### Q4: コンテキスト配布戦略

| 選択肢 | 特徴 | OSSでの採用 |
|---|---|---|
| **静的割り当て** | 役割別にルールセットを固定 | Agent Orchestrator (CLAUDE.md / CLAUDE.orchestrator.md) |
| **動的選択** | タスク内容に応じてコンテキストを自動選択 | ルーラーエージェント構想 |
| **Progressive Disclosure** | 段階的に必要分だけ展開 | o-m-cc (-33%トークン) |

**暫定判断**: 静的割り当て（agent-rule-decomposition の知見: 分割軸は「関心」）をベースに、Progressive Disclosure で粒度を制御。動的選択（ルーラー）は後段で追加。

## 6. MVP定義

コンテキスト基盤のMVPとして、以下を最小セットとする:

```
Context Foundation MVP
├── Task Context     → Markdown (Issue/タスク定義)
├── Decision Record  → Markdown + frontmatter (ADR/エピソード)
├── Execution Trace  → JSONL (エージェント実行ログ)
├── Codebase Knowledge → 既存ツール活用 (git log, rg, tree-sitter)
├── Run State        → JSONL (チェックポイント)
│
├── 検索: frontmatter索引 + rg
├── 昇格: テンプレート抽出 + 人間レビュー
├── 配布: 静的割り当て + Progressive Disclosure
└── 保存: ファイルベース (git管理)
```

### MVPで検証すること

- [ ] 5種類のコンテキストがファイルベースで管理できるか
- [ ] frontmatter索引 + rg で「関連コンテキストの発見」が実用的か
- [ ] 静的割り当て + Progressive Disclosure でトークン効率が改善するか
- [ ] このMVP上でルーラーエージェントのプロトタイプが動くか

### MVPで検証しないこと（後回し）

- RAG / ベクトル検索 / 知識グラフ
- 自動昇格（LLM要約）
- 動的コンテキスト選択
- GUI（管理コンソール / エディタ）

## 7. 蒸留（Distillation）の重要性

### 生ログとステートの区別

生ログ（Execution Trace）とRun State（Checkpoint）は種類として分ける価値がある。LLMの出力は確率的であり、同じCheckpointから再開しても同じ結果にはならない。しかしCheckpointの本質は「再現」ではなく **「再開と分岐」** — 「ここに戻ってやり直せるポイントがある」という選択肢の提供。生ログは「何が起きたかの記録」であり、「ここから続きをやれる状態」ではない。

### 蒸留精度 = コンテキスト基盤の価値

生ログは最も量が多く、無意味な情報も含まれる。コンテキスト基盤の価値は「どれだけ生ログを蒸留できるか」に帰着する。

```
生ログ（100%） → episode（要点抽出） → decisions（判断と根拠のみ）
```

OSSの圧縮戦略を蒸留精度の観点で比較:

| 戦略 | 蒸留率 | 残るもの | 失われるもの | 代表 |
|---|---|---|---|---|
| Sliding Window | 低 | 直近N件 | 古い文脈すべて | BeeAI |
| LLM要約 | 中 | LLMが判断した要点 | LLMが重要としなかったもの | OpenHands Condenser |
| Progressive Disclosure | — | 全部残し見せ方を制御 | 失われない（コスト問題は残る） | o-m-cc |
| 構造的選択 (PageRank) | 高 | 構造的に重要な部分 | 末端・参照されないもの | Aider Repository Map |
| 人間レビュー昇格 | 最高 | 人間が価値を認めたもの | — | 現行の手動運用 |

### MVPでの蒸留戦略

「テンプレート抽出 + 人間レビュー」を選択した理由は蒸留精度の安定性。LLM自動要約は精度が不安定なため、まずは:
1. 構造化テンプレートで機械的に抽出できる部分を拾う（cursor-thread-toolsのエクスポートが原型）
2. 判断が必要な部分は人間が昇格判断

MVPの先では蒸留の自動化度を段階的に上げる。Mastra Observational Memory（Observer/Reflectorパターン）が「自動蒸留」の最も参考になる設計。

### 実践パターンとの対応

現行の手動ワークフロー（キックオフ→設計→実装→レトロスペクティブ）のドキュメント分類は、コンテキスト基盤の種類と対応する:

| 手動ワークフローの分類 | コンテキスト基盤の種類 | 蒸留の方向 |
|---|---|---|
| raw-logs（スレッド生データ） | Execution Trace | 蒸留の入力 |
| plan（kickoff, plan） | Task Context | タスク開始時に生成 |
| episode（実行時の記録） | Decision Record への昇格候補 | テンプレート抽出 → 人間レビュー |
| decisions（ADR） | Decision Record | 蒸留の出力（最終成果） |

オーケストレーションツールはこの手動パターンの「フォーマット固定 + 蒸留自動化 + ガードレール強制」を実現するもの。

## 8. 次のアクション

- [ ] MVPの具体的なファイル構造・スキーマ定義
- [ ] 既存のideas/・projects/のドキュメントをMVPスキーマにマッピングする試行
- [ ] ルーラーエージェントがこの基盤上で動くかの検証設計
- [ ] 他の独自概念（認知協調、正準エージェント定義等）のsynthesis/ 作成

## ソース

- [ideas/20260220/context-persistence-4layer-model.md](../../ideas/20260220/context-persistence-4layer-model.md) — 4層モデルの原型
- [ideas/20260222/orchestration-tool-building-approach.md](../../ideas/20260222/orchestration-tool-building-approach.md) — 全体構想（GUI含む）
- [concepts/domain/05-state-memory.md](../concepts/domain/05-state-memory.md) — OSSのState & Memoryパターン
- [concepts/cross-cutting/cost-optimization.md](../concepts/cross-cutting/cost-optimization.md) — コスト最適化パターン
- [projects/ruler-agent-verification/](../../ruler-agent-verification/) — ルーラーエージェント検証
- [projects/agent-rule-decomposition/](../../agent-rule-decomposition/) — ルール分割検証

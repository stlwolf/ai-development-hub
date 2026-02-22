---
name: MetaGPT
repo: geekan/MetaGPT
last_reviewed: 2026-02-22
category: framework
---

## MetaGPT 調査結果

### 基本情報
- **リポジトリ:** https://github.com/geekan/MetaGPT (→ FoundationAgents/MetaGPT)
- **言語:** Python
- **規模:** 64,300+ stars / 8,100+ forks / MIT
- **学術:** ICLR 2024採択、AFlow = ICLR 2025 oral (top 1.8%)
- **主要著者:** Sirui Hong, DeepWisdom社
- **一言で:** SOPを体現した仮想ソフトウェア会社型マルチエージェントフレームワーク

### これは何か・何を解決するのか

「ソフトウェア会社をマルチエージェントシステムとしてシミュレートする」フレームワーク。1行の要件からPM→Architect→PM→Engineer→QAがSOP文書を受け渡し、実行可能なコードリポジトリを生成。

**核心:** 構造化ドキュメントによるハルシネーションの連鎖抑制。各エージェントにJSONスキーマ準拠の構造化出力を強制し、中間成果物のバリデーションを可能にする。

**コア哲学:** `Code = SOP(Team)`

### 設計思想・アーキテクチャ

**4つの主要抽象:**

1. **Role** — エージェント基底クラス。`_observe → _think → _act` サイクル
2. **Action** — 個別の作業単位（WritePRD, WriteDesign, WriteCode等）。構造化ActionNodeを出力
3. **Message** — エージェント間通信。`cause_by`（生成元Action型）がルーティングキー
4. **Environment** — Pub/Subパターンでメッセージルーティング

**SOP Document-Passing チェーン:**

```
UserRequirement
  ↓ (cause_by = UserRequirement)
ProductManager._watch([UserRequirement])
  → WritePRD → PRD (JSON) + 競合分析チャート
  ↓ (cause_by = WritePRD)
Architect._watch([WritePRD])
  → WriteDesign → System Design (JSON) + クラス図 + シーケンス図
  ↓ (cause_by = WriteDesign)
ProjectManager._watch([WriteDesign])
  → WriteTasks → タスク分解書 (JSON)
  ↓ (cause_by = WriteTasks)
Engineer._watch([WriteTasks])
  → WriteCode + WriteCodeReview + DebugError → ソースコード
  ↓ (cause_by = WriteCode/SummarizeCode)
QAEngineer._watch([SummarizeCode])
  → WriteTest + RunCode → テストコード
```

**ルーティングの仕組み:** 各Roleは`_watch()`で関心のあるAction型を登録。Environmentがブロードキャスト、各Roleの`_observe()`がcause_byでフィルタ。**明示的パイプライン接続なしに**、Action型をキーとした暗黙的ドキュメントフローが成立。

**3つの反応モード:**
- **REACT:** think-actループ。LLMが動的にAction選択
- **BY_ORDER:** 定義順に順次実行（固定SOP用）
- **PLAN_AND_ACT:** Plan生成→Plan内Task順次実行（Data Interpreter用）

### 機能一覧

#### コア

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Software Company SOP** | PM→Architect→PM→Engineer→QAパイプライン | `roles/`, `actions/` | コア |
| **Role-Action-Message** | cause_byベースの暗黙的Pub/Subルーティング | `roles/role.py`, `schema.py` | コア |
| **ActionNode** | LLM出力の構造化スキーマ定義と検証 | `actions/action_node.py` | コア |
| **Team Orchestration** | ラウンドベース実行、予算管理、シリアライズ | `team.py` | コア |
| **ProjectRepo / Git統合** | 成果物のGitリポジトリ管理、増分更新 | `utils/project_repo.py` | コア |

#### 差別化

| 機能 | 概要 | 場所 | 分類 |
|------|------|------|------|
| **Data Interpreter** | PLAN_AND_ACTモードでデータ分析・可視化 | `roles/di/data_interpreter.py` | 差別化 |
| **RoleZero / MGX** | 動的ツール実行マップ、TeamLeaderによるタスク委任 | `roles/di/role_zero.py`, `team_leader.py` | 差別化 |
| **AFlow** | ワークフロー自動生成（ICLR 2025 oral） | `examples/aflow/` | 差別化 |
| **SPO** | 自己対戦によるプロンプト最適化 | `examples/spo/` | 差別化 |
| **Experience Pool** | 過去の実行経験の蓄積と再利用 | `exp_pool/` | 差別化 |
| **Incremental Development** | 既存リポジトリへの追加要件対応 | `actions/write_prd.py` | 差別化 |

#### ユーティリティ

| 機能 | 概要 | 分類 |
|------|------|------|
| RAG | Retrieval-Augmented Generation | ユーティリティ |
| Multi-Environment | Android / Minecraft / Stanford Town / Werewolf | ユーティリティ |
| Researcher | ウェブ検索ベースのリサーチ | ユーティリティ |
| Mermaid図表生成 | クラス図・シーケンス図・競合分析チャート | ユーティリティ |
| マルチLLMプロバイダ | OpenAI / Azure / Ollama / Groq / Anthropic / Google 等10+ | ユーティリティ |
| Serialization / Recovery | 実行状態JSON保存と復元 | ユーティリティ |

### 特徴的な点

**1. cause_byベースの暗黙的ルーティング**

最も特徴的な設計。メッセージの内容ではなく**Action型**をルーティングキーにしたPub/Sub。新Roleの追加が既存Roleに影響しない拡張性の高さ。

```python
self._watch({WritePRD})  # ArchitectはWritePRDの出力だけを拾う
```

**2. 構造化ドキュメントによるハルシネーション抑制**

ActionNodeがJSONスキーマ準拠の出力を強制。下流エージェントが必要情報を確実に受け取れ、LLM出力を検証可能にし、ドキュメント間の参照整合性を維持。

**3. Fixed SOP → Dynamic Orchestration進化**

初期版はBY_ORDERモード中心。MGX世代ではTeamLeaderが動的にタスク委任、RoleZeroがツール実行マップで柔軟にAction/Toolを使用。切り替え可能。

**4. 複数の実行環境**

Stanford Town（社会シミュレーション）、Werewolf Game、Minecraft、Androidアシスタントなど多様な環境。

### 使い方

```bash
pip install --upgrade metagpt
metagpt --init-config
metagpt "Create a 2048 game"  # → ./workspace/ にリポジトリ生成
```

1行の要件から: PRD→システム設計書→タスク分解書→クラス図/シーケンス図→ソースコード→テストコード が生成される。

### エコシステム

- **商用版MGX.dev**: Product Huntで日間・週間1位（4.9/5）
- **ICLR 2024 + 2025 oral**の学術的裏付け
- **セキュリティ脆弱性**: eval()経由のRCE、コマンドインジェクション等が報告済み

### 他ツールとの比較

| 観点 | MetaGPT | CrewAI | AutoGen |
|------|---------|--------|---------|
| 設計思想 | SOPベースの仮想組織 | ロール+タスク+ツール委任 | 会話ベース協調 |
| 協調パターン | cause_by Pub/Sub + 構造化文書 | Sequential/Hierarchical | GroupChat |
| 中間成果物 | 構造化JSON（PRD, 設計書等）→Gitリポジトリ | タスク出力（テキスト中心） | 会話履歴 |
| ハルシネーション対策 | ActionNodeスキーマ強制 + 文書検証 | Output schema | 限定的 |
| 学術的裏付け | ICLR 2024 + 2025 oral | なし | NeurIPS 2023 workshop |

### 制約

1. **セキュリティ脆弱性**: RCE, コマンドインジェクション等。プロダクション環境に直接置くのは危険
2. LLM互換性: Ollama等ローカルLLMが不安定
3. コスト: GPT-4クラスで1プロジェクト数ドル
4. 概念が多い（学習曲線がCrewAIより急）
5. 依存80+パッケージと重い
6. 複雑なプロジェクトでは手動修正が必要

### 深掘り候補

- `roles/di/role_zero.py` — MGX世代の新ロールベースクラス
- `actions/action_node.py` — 構造化スキーマのパース・バリデーション
- `environment/mgx/mgx_env.py` — MGX環境のメッセージルーティング
- `strategy/planner.py` — Plan-and-Act戦略のタスク分解
- `exp_pool/` — 経験プールの蓄積・検索・再利用
- `memory/memory.py` — `get_by_actions()` によるAction型ベースフィルタリング

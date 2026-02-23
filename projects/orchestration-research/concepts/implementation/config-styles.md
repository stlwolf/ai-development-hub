# Configuration Styles — 設定スタイル

> ツールの定義・設定をどのフォーマット・スタイルで記述するかの分類。自前ツール構築時のDX（開発者体験）設計に直結する。

## 分類

### YAML宣言型

ワークフロー・エージェント定義をYAMLファイルで宣言する。プログラミング不要で定義可能。

| ツール | 設定対象 | 特徴 |
|---|---|---|
| TAKT | Piece定義 (ワークフロー全体) | Persona/Movement/Outputをすべて1つのYAMLで定義。`~/.takt/config.yaml` でグローバル設定 |
| Agent Orchestrator | `agent-orchestrator.yaml` | Zodで実行時バリデーション。エージェント・ワークスペース・通知等をYAMLで宣言 |
| SWE-agent | `config/*.yaml` | テンプレート、ツール、パーサー、履歴処理をすべてYAML設定 |
| Aider | `.aider.conf.yml` | モデル、edit format、git設定等 |

**利点**: ノンプログラマーでも編集可能、静的解析・バリデーション可能、diff差分が読みやすい
**制約**: 複雑なロジック（条件分岐、動的生成）の表現が困難

### Code-first

プログラミング言語のコード自体がエージェント/ワークフロー定義となる。

| ツール | 言語 | 特徴 |
|---|---|---|
| LangGraph | Python / TS | StateGraph APIまたはFunctional APIでグラフ構築 |
| OpenAI Agents SDK | Python / TS | `Agent()` コンストラクタで定義。最小プリミティブ |
| PydanticAI | Python | `Agent[DepsType, OutputType]` ジェネリクスで型安全定義 |
| Google ADK | Python / Go / Java / TS | Pydantic BaseModelでスキーマ定義 |
| BeeAI | TypeScript / Python | コードでエージェント構成 |
| AutoGen | Python | `AssistantAgent()` 等のコンストラクタ |
| Mastra | TypeScript | TypeScript + Zodスキーマ |

**利点**: IDE補完、型チェック、リファクタリング、テスト統合、任意のロジック表現
**制約**: プログラミング知識が必須、非エンジニアとの共有が困難

### YAML + Code ハイブリッド

宣言部分をYAMLに、ロジック部分をコードに分離するスタイル。

| ツール | YAML部分 | コード部分 | 特徴 |
|---|---|---|---|
| CrewAI | Role/Goal/Backstory、タスク定義 | カスタムツール、Flows (`@start`/`@listen`/`@router`) | `crewai create` でYAMLテンプレート生成 |
| MetaGPT | `config.yaml` (LLMプロバイダ設定) | Role/Action定義はPythonコード | 設定と定義を明確に分離 |
| CAO | Markdown + YAML frontmatter (agent profiles) | FastAPI/FastMCPサーバーロジック | エージェントプロファイルをドキュメント形式で定義 |

### Markdown / Template

Markdown frontmatterやテンプレートエンジンで設定する。ドキュメントと設定が一体化。

| ツール | フォーマット | 特徴 |
|---|---|---|
| o-m-cc | Markdown frontmatter | エージェント定義がそのままドキュメント。Progressive Disclosureで段階的に読み込み |
| oh-my-claude-code | YAML frontmatter | エージェント定義のメタデータ |
| PentAGI | `.tmpl` (Go template) | 35種のプロンプトテンプレート。Handlebarsライクな変数埋め込み |
| Orca | Handlebars templates | パイプライン内のプロンプトテンプレーティング |

**利点**: ドキュメントと設定の一体化、人間が読みやすい、LLMが直接生成・編集しやすい
**制約**: 構造的な検証が弱い、複雑な定義には不向き

## パターン・傾向

### 設定スタイルの軸

```
宣言的（何を）──────────────────── 手続き的（どうやって）
    │                                      │
    YAML                                  Code-first
    (TAKT, SWE-agent)                    (LangGraph, PydanticAI)
         │
    Markdown/Template                Hybrid
    (o-m-cc, PentAGI)              (CrewAI, MetaGPT)
```

### ツールカテゴリとの相関

- **ワークフロー定義型**: YAML宣言型が主流（TAKT, Agent Orchestrator, CAO）
- **フレームワーク型**: Code-firstが主流（LangGraph, OpenAI SDK, PydanticAI）
- **コーディングエージェント型**: YAML設定（SWE-agent, Aider）
- **CLIラッパー型**: Markdown/Template（o-m-cc, oh-my-claude-code, PentAGI）

### バリデーション手法

| スタイル | バリデーション | 代表ツール |
|---|---|---|
| YAML | Zodスキーマ（実行時） | Agent Orchestrator |
| YAML | JSON Schema | TAKT |
| Code | 静的型検査（コンパイル時） | PydanticAI, LangGraph (TypeScript) |
| Code | Pydantic BaseModel（実行時） | Google ADK, CrewAI |
| Template | なし（文字列置換のみ） | PentAGI, Orca |

### 自前ツール構築への示唆

- **エージェント定義**: YAML宣言型が適切。TAKTのFaceted Prompting形式が参考になる。Zodでバリデーション
- **ワークフロー定義**: 単純フローはYAML、複雑フローはCode-firstのハイブリッドが現実的（CrewAI方式）
- **プロンプトテンプレート**: Markdown/Template方式。o-m-ccのProgressive Disclosure（frontmatter→本文→参照）が参考
- **LLM設定**: config.yamlで外出し（MetaGPT方式）。環境ごとの切り替えが容易

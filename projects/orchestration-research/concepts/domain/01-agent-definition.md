# Agent Definition — エージェント定義

> エージェントが **何者か・何ができるか** を宣言する概念群。

## この領域の問い

- エージェントの役割・性格をどう表現するか
- 利用可能なツール・スキルをどう宣言するか
- 行動規範・制約をどう注入するか
- 出力の形式・型をどう規定するか

## 核となる概念

### Identity / Persona（アイデンティティ / ペルソナ）

エージェントが「誰であるか」の定義。名前、役割、性格、専門性を含む。

| ツール | 用語 | 特徴 |
|---|---|---|
| CrewAI | `Role` / `Goal` / `Backstory` | 3属性セットで人格を定義。Backstoryがコンテキストを補完 |
| TAKT | `Persona` | 音楽メタファ。ペルソナ単位でプロバイダー/モデルも切り替え可能 |
| MetaGPT | `Role` | エージェント基底クラスそのもの。`_observe → _think → _act` サイクルを内包 |
| Agent Orchestrator | Agent定義 | YAMLで名前・説明・ルールを宣言 |

**設計判断の分岐点**: ペルソナを「属性の組み合わせ」で表現するか（CrewAI）、「基底クラスの継承」で表現するか（MetaGPT）。前者は宣言的、後者は手続き的。

### Capability Declaration（能力宣言）

エージェントが利用可能なツール・スキル・機能の宣言。

| ツール | 用語 | 特徴 |
|---|---|---|
| PydanticAI | `Agent[DepsType, OutputType]` | ジェネリック型でツールと出力型を静的に宣言 |
| Google ADK | `AgentCard` (A2A) | エージェント発見のための標準化カード。他システムから参照可能 |
| BeeAI | `tools` / `HandoffTool` | ツールリスト + 他エージェントへの委譲ツール |
| OpenAI Agents SDK | `tools` / `handoffs` | ツールとHandoff先を明示的にリスト |
| o-m-cc | Skills | `/o-m-cc:init`, `/o-m-cc:plan` 等のスラッシュコマンドで能力を公開 |

**設計判断の分岐点**: 静的型付け（PydanticAI）vs 動的リスト（CrewAI）vs プロトコルベース発見（Google ADK A2A）。

### Instruction / Policy（指示 / ポリシー）

エージェントの行動規範、制約、動的指示の注入メカニズム。

| ツール | 用語 | 特徴 |
|---|---|---|
| TAKT | Faceted Prompting | 5つの関心事に分離: **Persona**, **Policy**, **Instruction**, **Knowledge**, **Output Contract** |
| OpenAI Agents SDK | `instructions` | 文字列または `Callable[RunContextWrapper, str]` で動的生成 |
| Agent Orchestrator | `Agent Rules` | プロジェクトごとのルールをインライン or ファイルで注入 |
| ControlFlow | `Dynamic Instructions` | `with cf.instructions("日本語で回答"):` でスコープ付き注入 |
| PentAGI | Authorization Framework | 全プロンプトに `AUTHORIZATION FRAMEWORK` セクションを強制注入 |

**注目**: TAKTの **Faceted Prompting** は、プロンプトの関心事分離を最も明示的に設計した例。5ファセットの分割はエージェント定義の構造化に直接参考になる。

### Output Contract（出力契約）

エージェントの出力形式・型・バリデーションルールの規定。

| ツール | 用語 | 特徴 |
|---|---|---|
| PydanticAI | `OutputSpec` (4モード) | `ToolOutput`, `NativeOutput`, `PromptedOutput`, `TextOutput` |
| TAKT | `Output Contract` | Faceted Promptingの1ファセット。YAML内で出力形式を宣言 |
| MetaGPT | `ActionNode` | JSONスキーマ準拠の構造化出力。バリデーション付き |
| OpenAI Agents SDK | `output_type` | Pydantic / dataclass で型指定 |
| CrewAI | `output_json` / `output_pydantic` | タスク単位で出力形式を指定 |
| ControlFlow | `result_type` / `Result Validator` | 型安全な結果型 + カスタムバリデーション |

**設計判断の分岐点**: 出力型をエージェントレベルで固定するか（PydanticAI）、タスクレベルで指定するか（CrewAI, ControlFlow）。

## パターン・バリエーション

### 宣言型 vs コード型

- **宣言型（YAML/JSON）**: TAKT, Agent Orchestrator, CrewAI（部分）。ノンプログラマーにもアクセス可能。静的解析・可視化しやすい
- **コード型**: PydanticAI, LangGraph, OpenAI SDK。型安全性、IDE補完、テスト容易性

### エージェント定義の粒度

- **モノリシック**: 1つのクラス/オブジェクトに全属性を格納（多くのフレームワーク）
- **分離型**: TAKTのFaceted Promptingのように、Persona/Policy/Instruction/Knowledge/Output Contractを個別ファイルに分割。合成して1つのプロンプトにする

### 定義のポータビリティ

- **ツール固有形式**: 大多数のOSS。フレームワーク間でエージェント定義を移植できない
- **標準化の試み**: Google ADK の AgentCard（A2Aプロトコル）。エージェント発見と能力記述の標準化

## 独自レイヤーとの接点

- **正準エージェント定義フォーマット**: ツール非依存でエージェントを定義する構想。TAKTのFaceted Prompting（5関心事分離）と Google ADK の AgentCard（A2A標準）が最も近い設計参考
- **ドキュメント設計原則**: Instruction/Policy層の構造化手法。write:read比率による構造化判断は、この領域の拡張

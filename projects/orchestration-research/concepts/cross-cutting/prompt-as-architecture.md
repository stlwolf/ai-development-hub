# Prompt as Architecture — プロンプト設計をアーキテクチャとして扱う

> プロンプトを単なるテキストではなく、構造化された設計成果物として扱うパターン群。

**横断する領域**: [01 Agent Definition](../domain/01-agent-definition.md)（Instruction/Policy）+ [02 Routing & Delegation](../domain/02-routing-delegation.md)（プロンプトベースルーティング）+ [06 Feedback & Validation](../domain/06-feedback-validation.md)（宣言的制約）

## なぜ横断的か

プロンプト設計は「エージェントの行動定義」（01）だが、その構造がルーティング判断（02）やフィードバック制御（06）にも影響する。プロンプトの構造化・分離・テンプレート化は、オーケストレーション全体のアーキテクチャ判断。

## パターン

### Faceted Prompting（関心の分離）

**代表**: TAKT

プロンプトを5つの関心事（ファセット）に分離し、独立して管理・合成する。

```
┌─────────────────────────────────┐
│ System Message                  │
│  ├── Persona    (誰であるか)    │
│  ├── Policy     (何を守るか)    │
│  └── Knowledge  (何を参照するか)│
├─────────────────────────────────┤
│ User Message                    │
│  ├── Instruction (何をするか)   │
│  └── Output Contract (出力形式) │
└─────────────────────────────────┘
```

**設計ポイント**:
- System Message / User Message の配置を厳密に制御
- **Recency Effect** を活用: Policyを末尾に配置し、遵守率を高める
- 各ファセットを個別ファイルに分割可能 → 再利用性・テスト容易性

**洞察**: 5ファセットの分離は、正準エージェント定義フォーマット（独自概念）の構造設計に直接参考になる。

### Progressive Disclosure（段階的開示）

**代表**: o-m-cc

コンテキストを必要に応じて段階的に展開し、トークン消費を最小化する。

```
Stage 1: frontmatter （メタ情報のみ）
    ↓ 必要なら
Stage 2: 本文 （詳細指示）
    ↓ 必要なら
Stage 3: 参照ファイル （外部ドキュメント）
```

**効果**: -33% トークン削減（o-m-cc測定）

**洞察**: ドキュメント設計原則（独自概念）の write:read 比率による構造化判断と通じる。「読み手が必要とする粒度」でコンテキストを制御する。

### Template-based Prompt Engineering（テンプレートベース）

**代表**: PentAGI, Orca

プロンプトをテンプレートとして管理し、変数埋め込みで動的生成する。

| ツール | テンプレート数 | 形式 | 特徴 |
|---|---|---|---|
| PentAGI | 35種 | Go `.tmpl` | 全エージェントのプロンプトをテンプレート化。`AUTHORIZATION FRAMEWORK` セクションを全テンプレートに強制注入 |
| Orca | 多数 | Handlebars | パイプライン内のプロンプトテンプレーティング |

**注目**: PentAGIの **Summarization Awareness Protocol** — 過去の要約の模倣・コピーを防止するメタプロンプト。プロンプトの品質劣化を構造的に防ぐ。

### Declarative Constraint Injection（宣言的制約注入）

**代表**: BeeAI, ControlFlow

プロンプトに制約を宣言的に注入し、実行パスを制御する。

| ツール | 方式 | 特徴 |
|---|---|---|
| BeeAI | `RequirementAgent` | `force_at_step`, `max_invocations` 等の宣言的ルールでLLMの行動を制約 |
| ControlFlow | `Dynamic Instructions` | `with cf.instructions("日本語で回答"):` でスコープ内の全タスクに追加指示注入 |
| TAKT | `Policy` ファセット | 「何を守るか」を独立したファセットとして分離 |

**洞察**: プロンプトへの制約注入は、[06 Feedback & Validation](../domain/06-feedback-validation.md) の Guardrail とは異なるアプローチ。Guardrailは「出力を検査」するが、制約注入は「入力を構造化」する。事前防止 vs 事前制御。

### Prompt-based Routing（プロンプトベースルーティング）

**代表**: oh-my-claudecode, MetaGPT

プロンプトやメッセージの構造自体がルーティングのキーとなる。

| ツール | 方式 | 特徴 |
|---|---|---|
| oh-my-claudecode | Intent Gate | ユーザー入力を分類して適切なエージェントに振り分け |
| MetaGPT | `cause_by` | メッセージの生成元Action型がルーティングキー。`_watch()` で関心のあるAction型を登録 |

**洞察**: MetaGPTの `cause_by` はルーティングをプロンプト/メッセージの構造に埋め込む。明示的なルーティングテーブルが不要。分散型オーケストレーションに適する。

## パターン間の関係

```
Faceted Prompting ──→ テンプレート化可能 ──→ Template-based
      │                                         │
      ↓                                         ↓
Progressive Disclosure                  Constraint Injection
(読み手に応じた粒度制御)                (制約をプロンプトに埋め込む)
      │                                         │
      └──────────── Prompt-based Routing ────────┘
                  (構造がルーティングを決定)
```

## 未整理パターン: Intent Refinement（意図精錬）

> synthesis/ フェーズで検討すべき追加パターン。

上記5パターンはいずれも「入力の構造化」に焦点を当てているが、**「能動的に質問して曖昧な入力を明確化する」** パターンはまだ独立した概念として扱えていない。

### 関連事例

- **claude-code-prompt-improver** ([severity1/claude-code-prompt-improver](https://github.com/severity1/claude-code-prompt-improver)): UserPromptSubmitフックでプロンプトの曖昧さを評価し、曖昧なら1〜6の質問で明確化してから実行。クリアなプロンプトはゼロオーバーヘッドで通過
- **ラクス 平川氏 発表**（2025/10 レバテックLAB）: バックログ→概要設計のAI化。「AIに質問させる」+「テンプレート埋め込み」+「レビュー・指摘」の3段階。4〜6割そのまま使用
- **スマートバンク 井谷氏 発表**（2025/10）: 仕様書駆動開発。仕様書を小さく分割することでAIの自律性改善。Spec Workflow MCPで承認フロー管理。3-5並列実現

### 洞察

- [06 Feedback & Validation](../domain/06-feedback-validation.md) は主に **出力品質** の保証に焦点。しかし **出力品質の上限は入力品質で決まる**
- 「曖昧な入力→長いやりとり」より「最初に質問で明確化→一発で正しい出力」の方がトータルコスト低（[Cost Optimization](./cost-optimization.md) との接点）
- 入力精錬はタスクの曖昧度に応じて段階的に適用すべき（prompt-improverの「クリアならスキップ」設計）
- 仕様書分割（井谷氏）はタスク粒度を小さくすることで曖昧さを構造的に排除するアプローチ — [03 Flow Control](../domain/03-flow-control.md) のタスク分解と同根

## 独自レイヤーとの接点

- **正準エージェント定義フォーマット**: Faceted Promptingの5関心事分離が構造設計の基盤
- **ドキュメント設計原則**: Progressive Disclosureの段階的開示と、write:read比率の構造化判断は同じ設計哲学
- **認知協調**: Constraint Injection（BeeAI RequirementAgent）の `force_at_step` が「セカンドオピニオンを強制挿入」のメカニズムとして使える

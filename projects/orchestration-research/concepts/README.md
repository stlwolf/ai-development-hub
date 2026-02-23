# Concepts — オーケストレーション・ドメイン概念マップ

21のOSSツール調査（[landscape/](../landscape/)）から横断的に抽出したドメイン概念・パターン・実装特性の集約。

## 目的

- 個別ツールの調査結果を **ツール非依存の概念** として整理する
- 自前ツール構築時の設計語彙（ドメイン用語集）を確立する
- 独自レイヤー（認知協調・知識永続化等）がドメイン全体のどこに位置するかを明確にする

## 構成

```
concepts/
├── README.md                  # このファイル
├── domain/                    # ドメイン概念（10領域）
│   ├── 01-agent-definition.md
│   ├── 02-routing-delegation.md
│   ├── 03-flow-control.md
│   ├── 04-execution-runtime.md
│   ├── 05-state-memory.md
│   ├── 06-feedback-validation.md
│   ├── 07-human-interaction.md
│   ├── 08-event-reaction.md
│   ├── 09-tooling-integration.md
│   └── 10-observability.md
├── implementation/            # 実装特性（技術分類、ドメイン非依存）
│   ├── landscape-matrix.md    #   21ツール全体の実装特性マトリクス
│   ├── interface-types.md     #   インターフェース型分析（Library/CLI/Web UI/Plugin/GUI）
│   ├── wrapper-vs-standalone.md #   ラッパー vs スタンドアロン + LLM抽象レイヤー
│   └── config-styles.md       #   設定スタイル（YAML宣言/Code-first/Hybrid/Template）
└── cross-cutting/             # 横断的テーマ（複数領域にまたがる概念）
    ├── README.md              #   選定基準・domain/との関係整理
    ├── llm-abstraction-patterns.md #   LLMプロバイダー抽象化（litellm/langchain/Vercel AI SDK/直接）
    ├── prompt-as-architecture.md   #   プロンプト設計をアーキテクチャとして扱う
    ├── cost-optimization.md        #   コスト最適化（モデルルーティング/圧縮/予算管理）
    └── coordination-topologies.md  #   マルチエージェント協調トポロジー（中央集権/P2P/ハイブリッド/Swarm）
```

## 10のドメイン概念領域

21ツールに繰り返し登場する概念を抽象化すると、以下の10領域に整理できる。

| # | 領域 | 問い | 概要 |
|---|------|------|------|
| 01 | [Agent Definition](./domain/01-agent-definition.md) | **何者か・何ができるか** | ペルソナ、能力宣言、指示・制約、出力契約 |
| 02 | [Routing & Delegation](./domain/02-routing-delegation.md) | **誰がやるか** | Handoff、Agent-as-Tool、意図分類、階層委任 |
| 03 | [Flow Control](./domain/03-flow-control.md) | **どんな順序で実行するか** | Sequential、Parallel、条件分岐、ループ、グラフ |
| 04 | [Execution & Runtime](./domain/04-execution-runtime.md) | **どこで・どう動かすか** | サンドボックス、ワークスペース隔離、ランタイムプロバイダー |
| 05 | [State & Memory](./domain/05-state-memory.md) | **何を覚えているか** | チェックポイント、Working/Long-term Memory、コンテキスト圧縮 |
| 06 | [Feedback & Validation](./domain/06-feedback-validation.md) | **品質をどう保証するか** | ガードレール、宣言的制約、ループ検出、レビュー、評価 |
| 07 | [Human Interaction](./domain/07-human-interaction.md) | **人間がどう関与するか** | Interrupt、承認、Resume、Rewind |
| 08 | [Event & Reaction](./domain/08-event-reaction.md) | **外部イベントにどう反応するか** | EventStream、Reactions、Hooks、スケジューリング |
| 09 | [Tooling & Integration](./domain/09-tooling-integration.md) | **外部世界とどうつながるか** | MCP、A2A、プラグインスロット、SCM/Tracker統合 |
| 10 | [Observability](./domain/10-observability.md) | **何が起きているかをどう把握するか** | トレーシング、可視化、Trajectory、ストリーミング |

## レイヤー構造

10領域を積み上げると以下のようになる。下層ほどインフラ寄り、上層ほどセマンティック寄り。

```
┌─────────────────────────────────────────────────┐
│  10. Observability                              │  横断的関心事
├─────────────────────────────────────────────────┤
│  07. Human Interaction                          │  外部介入
│  06. Feedback & Validation                      │  品質保証
├─────────────────────────────────────────────────┤
│  08. Event & Reaction                           │  イベント駆動
│  03. Flow Control                               │  実行フロー
│  02. Routing & Delegation                       │  振り分け
├─────────────────────────────────────────────────┤
│  05. State & Memory                             │  永続化
│  04. Execution & Runtime                        │  実行基盤
├─────────────────────────────────────────────────┤
│  09. Tooling & Integration                      │  外部接続
│  01. Agent Definition                           │  定義
└─────────────────────────────────────────────────┘
```

- **下層（01, 09, 04, 05）**: OSSが厚く実装している「インフラ層」。自前で書く必要が薄い
- **中層（02, 03, 08）**: オーケストレーションの核。ツールごとに設計判断が大きく分かれる
- **上層（06, 07）**: 品質・安全性レイヤー。独自概念（認知協調・ルーラーエージェント）はここに位置する
- **横断（10）**: すべての層にまたがる可観測性

## 独自レイヤーの位置づけ

> 詳細は `../synthesis/` に別途作成予定。以下は概要マッピング。

| 独自概念 | 主な領域 | OSSのカバー度 |
|---|---|---|
| 認知協調（セカンドオピニオン） | 06 Feedback + 07 Human | 部分的（BeeAI RequirementAgent、TAKT レビューループ） |
| ルーラーエージェント | 02 Routing + 06 Feedback | 概念のみ（OSSに実装なし） |
| 4層コンテキストモデル | 05 State & Memory | インフラ層のみ（Mastra 4層Memory） |
| 正準エージェント定義 | 01 Agent Definition | 構造のみ（PydanticAI型定義、TAKT YAML piece） |
| コンテキスト・エンベロープ | 05 State + 08 Event | 概念的に近い（OpenHands EventStream） |
| ドキュメント設計原則 | 01 Agent Definition | 部分的（MetaGPT SOP受け渡し） |

## 各ファイルの記述規約

`domain/` 配下の各ファイルは以下の構造で統一する:

```markdown
# [領域名]

> 一言定義

## この領域の問い

（この領域が答える中心的な問い）

## 核となる概念

（概念ごとにサブセクション。定義 + 21ツールでの登場例）

## パターン・バリエーション

（概念同士の関係、設計判断の分岐点）

## 独自レイヤーとの接点

（この領域に関連する独自概念）
```

## 調査ソース

- [landscape/INDEX.md](../landscape/INDEX.md) — 21ツール調査のカテゴリ別一覧
- [landscape/](../landscape/) — 各ツールの個別調査結果

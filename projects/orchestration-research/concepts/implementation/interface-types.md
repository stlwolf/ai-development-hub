# Interface Types — インターフェース型

> ツールが外部に提供するインターフェースの分類。自前ツール構築時の「ユーザーにどう触らせるか」の設計判断に関わる。

## 分類

### Library / SDK

コードに組み込んで使うライブラリ。最も多い形態。

| ツール | 言語 | 特徴 |
|---|---|---|
| LangGraph | Python / TS | Graph API + Functional API の2スタイル |
| Agent Squad | Python / TS | 両言語で完全実装 |
| OpenAI Agents SDK | Python / TS | 最小プリミティブ主義。5プリミティブで全てを表現 |
| Google ADK | Python / Go / Java / TS | 4言語対応。最大のマルチ言語カバレッジ |
| PydanticAI | Python | ジェネリック型による型安全エージェント定義 |
| BeeAI | TypeScript / Python | Serve Moduleでプロトコル公開も可能 |
| AutoGen | Python (.NET) | AutoGen Studioで非コーダー向けGUIも提供 |
| CrewAI | Python | CLI (`crewai create/run`) も提供 |
| Mastra | TypeScript | CLI (`mastra dev`) + Mastra Studio (Web UI) も提供 |
| MetaGPT | Python | CLI (`metagpt "Create..."`) も提供 |
| Orca | Rust | crates.io未公開。ライブラリのみ |

**利点**: 型安全性、IDE補完、テスト統合、既存アプリへの組み込み
**制約**: プログラミング知識が必須。言語ロックイン

### CLI Tool

ターミナルから直接実行するコマンドラインツール。

| ツール | 特徴 |
|---|---|
| TAKT | `takt run piece.yaml` でワークフロー実行。対話モードあり |
| Aider | `aider` でリポジトリ内のAIペアプログラミング開始 |
| SWE-agent | `sweagent run --config config.yaml` で実行 |
| CAO | API Server（FastAPI）だがCLIからも操作可能 |

**利点**: スクリプト統合が容易、CI/CDパイプラインに組み込み可能
**制約**: 対話的なフィードバックが難しい（TUIを作らない限り）

### CLI + Web UI

CLIをメインにしつつWebダッシュボードも提供する。

| ツール | Web UI | 特徴 |
|---|---|---|
| Agent Orchestrator | Next.js 15 | SSEリアルタイム更新。セッション管理・ログ表示 |
| OpenHands | React | セッション管理、ファイルブラウザ、ターミナル |
| PentAGI | 組み込みWeb UI | GraphQL API経由 |
| Mastra | Mastra Studio | エージェント・ワークフローの視覚的操作 |
| Google ADK | ADK Web (Dev UI) | 開発用対話UI |

**利点**: CLI（自動化）とWeb UI（対話・可視化）の両立
**制約**: 2つのインターフェースのメンテナンスコスト

### Plugin（既存ツール拡張）

既存エージェントCLI（主にClaude Code）のプラグインシステム上で動作する。

| ツール | ホスト | 特徴 |
|---|---|---|
| oh-my-claudecode | Claude Code | Hooks駆動。中央オーケストレーター型 |
| o-m-cc | Claude Code | Hooks + Agent Teams。分散P2P型。ビルドシステムなし |

**利点**: 既存エコシステムの活用、軽量
**制約**: ホストツールへの完全依存。ホストの更新で破壊されるリスク

### GUI

グラフィカルUIを主インターフェースとするもの。

| ツール | 特徴 |
|---|---|
| AutoGen Studio | ノーコードGUI。ドラッグ&ドロップでエージェント定義・実行 |
| LangGraph Studio / Platform | WebベースIDE。グラフの可視化・デバッグ |

**利点**: ノンプログラマーでもアクセス可能
**制約**: 複雑なカスタマイズが困難。Library/CLIとの機能ギャップが生じがち

## パターン・傾向

### 主要な組み合わせパターン

1. **Library only**: 最もシンプル。フレームワークとしての純度が高い（LangGraph, OpenAI SDK, PydanticAI）
2. **Library + CLI**: ライブラリの上に薄いCLIを被せる（CrewAI, MetaGPT, SWE-agent）
3. **Library + CLI + Web UI**: フルスタック。開発体験は良いがメンテナンスコスト大（Mastra, Google ADK）
4. **CLI-first**: ワークフローオーケストレーターに多い（TAKT, Aider）
5. **Plugin**: 既存ツールの拡張。最も軽量だが依存リスク（oh-my-claudecode, o-m-cc）

### 言語とIF型の相関

- **Python**: Library中心。エージェントフレームワークの事実上の標準言語
- **TypeScript**: Library + CLI + Web UI を1つのモノレポで提供する傾向（Mastra, Agent Orchestrator）
- **Bash/Shell**: Plugin型のみ（o-m-cc）。最軽量だが拡張性に限界

### 自前ツール構築への示唆

- **検証段階**: CLI-firstが最も素早い（TAKT, Aider方式）
- **チーム利用**: Library + CLI の組み合わせが汎用的
- **Web UI**: 後付けで追加可能。初期段階では不要

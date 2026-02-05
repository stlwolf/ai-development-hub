# マルチエージェント・オーケストレーション調査

AIエージェントのマルチエージェント運用、並列実行、オーケストレーションに関するトレンド調査。

## 目的

- 現在のエコシステムで利用可能なツール・フレームワークの把握
- ベストプラクティスの収集
- 自身のアプローチとの比較・改善点の特定

---

## Cursor/Claude調査（2026-02-05）

### 主要フレームワーク

#### 1. LangGraph

- **提供元**: LangChain
- **特徴**: グラフベースのワークフロー定義、状態管理、条件分岐
- **用途**: 複雑なエージェントフローの構築
- **リンク**: https://github.com/langchain-ai/langgraph

#### 2. CrewAI

- **特徴**: 役割ベースのマルチエージェント協調
- **用途**: チーム構成でタスクを分担
- **リンク**: https://github.com/joaomdmoura/crewAI

#### 3. AutoGen (Microsoft)

- **特徴**: 会話ベースのマルチエージェントフレームワーク
- **用途**: エージェント間の対話による問題解決
- **リンク**: https://github.com/microsoft/autogen

#### 4. AWS Agent-Squad (旧 Multi-Agent Orchestrator)

- **提供元**: AWS Labs
- **特徴**: AWS統合、スケーラブル
- **リンク**: https://github.com/awslabs/agent-squad

---

### 注目ツール

#### takt（タクト）

- **作者**: nrs（成瀬允宣）
- **リポジトリ**: https://github.com/nrslib/takt
- **記事**: https://zenn.dev/nrs/articles/c6842288a526d7

##### 核心思想

> **AIに「お願い」するのではなく、「強制的に」実行させる**

サブエージェントやSkillを「AIの判断で使わせる」アプローチではうまくいかなかった経験から、**ワークフローとして強制する**設計。

##### 主な機能

| 機能 | 説明 |
|------|------|
| YAMLワークフロー | ステップ→遷移ルールを定義、AIの気まぐれを排除 |
| ビルトインエージェント | coder, architect, supervisor, planner, security等 |
| カスタムエージェント | Markdownファイルで定義（既存の.claude/Skillも流用可） |
| Claude Code / Codex両対応 | ステップごとにモデル切り替え可能 |
| タスクバッチ実行 | `takt run` / `takt watch` で監視モード |
| セッション継続 | 中断しても再開可能 |
| MAGIシステム | 3ペルソナ（Scientist/Nurturer/Pragmatist）による多角的審議 |

##### ワークフロー例

```yaml
name: code-review
steps:
  - name: write-code
    agent: ../agents/default/coder.md
    rules:
      - condition: 実装完了
        next: review

  - name: review
    agent: ../agents/default/supervisor.md
    rules:
      - condition: 問題なし
        next: COMPLETE
      - condition: 改善が必要
        next: write-code
```

##### インストール

```bash
npm install -g takt
```

---

### MCP関連ツール

| ツール | 説明 | リンク |
|--------|------|--------|
| mcp-eval | MCPサーバーの評価・テストフレームワーク | - |
| mmcp | 複数MCPサーバーの統合管理 | - |

---

### その他のツール

| ツール | 説明 |
|--------|------|
| Ralph TUI | ターミナルUIでのエージェント管理 |
| toolkit-cli | CLIベースのエージェントツールキット |
| Agent TARS | ByteDance製マルチモーダルエージェント |

---

### ベストプラクティス

#### 1. シンプルに始める

- 最初から複雑なオーケストレーションを構築しない
- 単一エージェント → 2エージェント協調 → 複雑なワークフロー と段階的に

#### 2. 強制力のあるワークフロー

- AIの「判断」に任せると、やってほしいことをスキップされる
- ワークフローとして「必ず実行される」仕組みを構築

#### 3. コンテキストの明示的な受け渡し

- エージェント間で暗黙的なコンテキスト共有に頼らない
- 前のステップの出力を明示的に次のステップに渡す

#### 4. 状態管理の外部化

- エージェントのメモリに頼らない
- ファイル（STATUS.md, MEMORY.md等）やログで状態を永続化

#### 5. エラーハンドリングの設計

- 各ステップで失敗した場合の遷移先を定義
- 最大イテレーション数を設定し、無限ループを防止

---

### 自身のアプローチとの比較

| 観点 | 現在のアプローチ | takt | 評価 |
|------|------------------|------|------|
| ワークフロー定義 | ドキュメント（暗黙的） | YAML（明示的） | taktの方が再現性高い |
| 強制力 | なし（将来構想） | あり（実装済み） | 参考にすべき |
| エージェント定義 | - | Markdownファイル | シンプルで良い |
| 状態管理 | STATUS.md | NDJSONログ | 両方有効 |
| プロバイダー | Cursor/Claude固有 | Claude Code/Codex両対応 | taktの方が柔軟 |

### 結論

- 現在のアプローチは**ベストプラクティスに沿っている**（シンプルに始める、状態の外部化）
- taktの「強制力のあるワークフロー」概念は取り入れる価値あり
- 車輪の再発明ではないが、**既存ツールとの統合・参考**を検討

---

## Claude Code調査（2026-02-06）

### 主要フレームワーク比較（2025-2026トレンド）

| フレームワーク | 設計思想 | 得意領域 | 学習曲線 |
|---------------|---------|---------|---------|
| **LangGraph** | グラフベース、状態管理 | 複雑な分岐ワークフロー | 急（グラフ思考必要） |
| **CrewAI** | ロールベース、チーム協調 | 役割分担タスク | 緩（直感的） |
| **AutoGen** | 会話ベース、非同期 | 対話型問題解決 | 中程度 |

> 参考: [DataCamp - CrewAI vs LangGraph vs AutoGen](https://www.datacamp.com/tutorial/crewai-vs-langgraph-vs-autogen)

### 重要な知見

#### フレームワークの限界

> "All three top open source agentic frameworks are exceptional at **prototyping**, but **dangerously incomplete for production**. The cost isn't in the code; it's in the **security, governance, and deployment layer** you have to custom-build."

→ 認証情報の扱い（`.session`, `.token`）を自前で制御している現在のアプローチは、この点で価値がある。

#### LangGraphが2026年の業界標準

> "For projects requiring high precision and state management, LangGraph is the industry standard in 2026."

ただし、単一エージェント + ツール呼び出しの構成なら、フレームワークなしでも十分。

---

### Claude Code / Agent SDK の機能

#### Task tool による並列実行

- **最大7エージェント同時実行可能**
- サブエージェント: Explore, Bash, general-purpose 等
- 参考: [Claude Code Task Tool System](https://dev.to/bhaidar/the-task-tool-claude-codes-agent-orchestration-system-4bf2)

```
Claude Code:
  ├── Task (API Agent) ──→ api_call.sh 実行
  ├── Task (Sentry確認) ──→ curl + jq
  └── Task (Explore) ──→ コードベース探索
```

#### Tasks（緑機能）- セッション間調整

- タスク間の依存関係（DAG）管理
- `blockedBy` で「Task 1が完了するまでTask 3は開始しない」を定義可能
- 参考: [VentureBeat - Claude Code's Tasks update](https://venturebeat.com/orchestration/claude-codes-tasks-update-lets-agents-work-longer-and-coordinate-across)

#### 実運用例

| ユースケース | 構成 |
|-------------|------|
| 大規模リファクタリング | メインエージェントがgrepで対象特定 → 各ファイルにサブエージェント |
| インシデント分析 | 3サブエージェントがログ並列分析 → メインが統合レポート |
| CI/CD統合 | cronジョブでClaudeセッション起動、TaskListで進捗追跡 |

---

### QA/テスト自動化のトレンド

#### Agentic QAの4フェーズモデル

```
Analyst → Architect → Engineer → Sentinel
(コード分析) (テスト計画) (テスト実装) (品質監査)
```

- 参考: [Autonomous QA Testing with AI Agents](https://openobserve.ai/blog/autonomous-qa-testing-ai-agents-claude-code/)

#### 現場の採用状況

- 2025年: 81%のチームがAIをテストに活用
- 2026-2027年: 25%→50%の企業がAIエージェントをデプロイ予定
- 参考: [Momentic - AI Agents in QA Testing](https://momentic.ai/blog/ai-agents-in-qa-testing)

---

### 自身のアプローチとの比較

| 観点 | トレンド | 現在のアプローチ | 評価 |
|------|---------|-----------------|------|
| フレームワーク | LangGraph/CrewAI依存 | **フレームワークなし** | 軽量で良い、必要時に導入 |
| 言語 | Python中心 | **Bash + curl + jq** | 依存少なく運用しやすい |
| 認証 | フレームワーク任せ | **自前で制御** | セキュリティ面で優位 |
| 並列実行 | FW機能利用 | 未実装 | **Claude Code Task活用を推奨** |
| 状態管理 | FWの状態管理 | STATUS.md/ドキュメント | FWと同等の思想 |

### 結論

1. **車輪の再開発ではない**: フレームワークなしのアプローチには独自の価値（軽量、セキュリティ制御）
2. **トレンドとは異なる**: ただしそれは差別化要因でもある
3. **改善余地**: Claude Code Task toolの活用で並列実行を強化可能
4. **研究価値**: 「フレームワーク導入の境界線」を明らかにする実験として有効

---

## 設計方針: ロックイン回避

### 背景

- AIオーケストレーションのデファクトは未確立（2026年時点）
- エコシステムは日進月歩で変化
- 特定FWへのロックインはリスク

### アプローチ

**スクリプト/CLI層での抽象化**を採用:

```
[ドキュメント] → [スクリプト (bash/curl/jq)] → [AIプロバイダー]
                        ↑
                  この層を自分で制御
```

- AIプロバイダー（Cursor, Claude Code, Codex等）は差し替え可能
- ワークフローはドキュメント + スクリプトで定義
- FW固有の概念を学ぶコストを回避

### メリット

| 観点 | 効果 |
|------|------|
| 変化対応 | プロバイダー変更時もスクリプト改修で対応 |
| チーム展開 | ドキュメント + スクリプト配布で再現可能 |
| デバッグ | 処理が透明（bash, curl, jq） |
| 段階的自動化 | 手動 → 半自動 → 自動 と進められる |

### 運用構成例

| 役割 | ツール | 理由 |
|------|--------|------|
| メイン | Cursor | コスト（会社負担）、IDE統合 |
| サブ | Claude Code | CLI/API直接利用、特定タスク |
| 将来検討 | takt等 | ワークフロー強制が必要になった場合 |

---

### 参考リンク

- [DataCamp - CrewAI vs LangGraph vs AutoGen](https://www.datacamp.com/tutorial/crewai-vs-langgraph-vs-autogen)
- [Top AI Agent Frameworks 2025-2026](https://o-mega.ai/articles/langgraph-vs-crewai-vs-autogen-top-10-agent-frameworks-2026)
- [Claude Code Task Tool System](https://dev.to/bhaidar/the-task-tool-claude-codes-agent-orchestration-system-4bf2)
- [Claude Code Subagents](https://zachwills.net/how-to-use-claude-code-subagents-to-parallelize-development/)
- [Autonomous QA with AI Agents](https://openobserve.ai/blog/autonomous-qa-testing-ai-agents-claude-code/)
- [AI Agents in QA Testing 2026](https://momentic.ai/blog/ai-agents-in-qa-testing)
- [Anthropic - Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)

---

## 参考リンク

- [takt - GitHub](https://github.com/nrslib/takt)
- [AIの見張り番をやめよう - taktを公開しました](https://zenn.dev/nrs/articles/c6842288a526d7)
- [LangGraph](https://github.com/langchain-ai/langgraph)
- [CrewAI](https://github.com/joaomdmoura/crewAI)
- [AutoGen](https://github.com/microsoft/autogen)
- [AWS Agent-Squad](https://github.com/awslabs/agent-squad)

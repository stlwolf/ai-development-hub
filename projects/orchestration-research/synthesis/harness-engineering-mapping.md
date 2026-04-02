# Harness Engineering Mapping — ハーネス概念と自設計の対応

> ハーネスエンジニアリング（`docs/research/harness-engineering/`）の主要概念と、orchestration-research の設計・Epic #10 の成果物への対応を整理する。

## ハーネスの定義（記事群の合意点）

- **Prompt Engineering**: 何を聞くか
- **Context Engineering**: モデルに何を見せるか
- **Harness Engineering**: システム全体がどう動くか（ツール、権限、状態、検証、ガードレール、フィードバックループ）

「モデルは CPU、コンテキストウィンドウは RAM、ハーネスは OS」（Schmid #11, Bouchard #8）

## 自設計との対応

| ハーネス概念 | 自設計での対応物 | 状態 |
|---|---|---|
| **OS としてのハーネス** | 「構造化ドキュメントルーティングエンジン」（orchestration 全体設計） | 構想段階 |
| **Progressive Disclosure** | 4層→5型コンテキストモデルの「即時参照を目次に、構造化ナレッジを漸進読み込み」 | context-foundation.md に記述済み |
| **Doc-gardening agent** | 「生成→保存→昇格→失効」パイプライン | context-foundation.md に概念記述。未実装 |
| **Self-verification loop** | Adversarial Spec Review（Epic #10 A-2）+ pre-completion check（フック候補） | Issue #11 + #17 |
| **カスタムリンターのエラーメッセージ＝修復プロンプト** | pr-review チェックリスト（Epic #10 A-1）の設計原則 | Issue #13 |
| **Loop detection** | doom loop 検出（フック `afterFileEdit`） | #17 の次フェーズ |
| **「ミスしたら環境改善」** | Negative Knowledge 昇格（context-foundation.md で議論済み）+ Implementer 契約の BLOCKED 処理 | Issue #12, コマンド化は今後 |
| **AGENTS.md は目次** | CLAUDE.md / AGENTS.md を ~100行に維持 + canonical/ への分離 | 実践中 |
| **Trace → harness 改善ループ** | control-loop-challenges.md の「状態判定→再投入→エスカレーション」 | 構想段階 |
| **Build to Delete** | 「薄いシェル」方針。Manus 5回リファクタ、Vercel ツール80%削除が裏付け | 方針として合意済み |
| **Reasoning sandwich** | arena-compare / so-compare の「いつ高コストモデルを使うか」 | skills-level-patterns.md に関連記述 |
| **フック機構** | Cursor `.cursor/hooks.json` + Claude Code `hooks` | **Epic #10 #17 で基盤整備** |

## NLAH（Natural-Language Agent Harnesses）との対応

> 清華大学・ハルビン工業大学 (arXiv:2603.25723, 2026-03)。ハーネスの制御ロジックを自然言語の統一フォーマットで記述する提案。コードベースのハーネスを NLAH に移行しただけで OSWorld 30.4 → 47.2（+16.8pt）。canonical の「Markdown ドキュメント駆動」アプローチの正当性を裏付ける。
>
> 参照: [Zenn 解説記事](https://zenn.dev/knowledgesense/articles/22eac0ba8cada3) / [arXiv 論文](https://arxiv.org/abs/2603.25723)

| NLAH コア要素 | 意味 | 自設計での対応物 | 充足度 |
|---|---|---|---|
| **Contracts** | 出力制約と停止ルール | implementer-contract のステータス enum + self-review | 部分的。停止ルールは人間依存 |
| **Roles** | 各ステージのロール定義 | agents/（oss-researcher, vendor-inspector 等） | ✅ |
| **Stage Structure** | ワークフロー構造 | commands/（issue-debug, peer-ai-review 等の手順） | ✅ だが宣言的ループ構文なし |
| **Adapters & Scripts** | 決定論的処理 | hooks/scripts/、so-compare.sh 等 | ✅ |
| **State Semantics** | ステップ間の永続化宣言 | なし（暗黙的） | **不在** |
| **Failure Taxonomy** | 失敗分類 → リカバリ方法 | implementer-contract の BLOCKED + エスカレーション | 部分的。分類が粗い（3値） |

### NLAH から導出される設計課題

- **State Semantics の明示化**: 各スキル/コマンドの frontmatter に `outputs:` フィールドを追加し「何がファイルとして残るか」を宣言する。オーケストレーションツールのエンベロープ設計と直結
- **Failure Taxonomy の細粒度化**: implementer-contract の SUCCESS/PARTIAL/BLOCKED を拡張。`format_error → retry once`、`test_failure → fix and retry`、`timeout → escalate` のような失敗種別ごとのリカバリパス定義

## ハーネス記事群にあって自設計に未反映のもの

| # | 概念 | 意味 | 対処方針 |
|---|---|---|---|
| 1 | **リンターのエラーメッセージ＝プロンプト** | チェック違反時の出力にエージェント向け修復手順を埋め込む | A-1 チェックリスト各項目の設計原則として採用 |
| 2 | **Doc-gardening agent** | 知識ベースの陳腐化自動検出・PR化 | context-foundation のパイプライン設計時に詳細化 |
| 3 | **Time budgeting** | サブエージェントに残り時間を注入 | A-5 implementer 契約に時間意識を追加 |
| 4 | **Observability のエージェント直接露出** | ログ・メトリクスをエージェントがクエリ可能に | Sentry investigation が部分カバー。汎用化は observability レイヤーで |
| 5 | **Negative Knowledge ledger** | 失敗事例の構造化蓄積・次サイクルへの自動注入 | Decision Ledger（ideas/20260329）が構想。Issue 未作成 |
| 6 | **Knowledge freshness** | コンテキスト・ドキュメントの陳腐化検出 | Doc-gardening の前提。Issue 未作成 |

## キーインサイト

### 「ルールで祈る」から「フックで強制する」への転換

ハーネス記事群に共通する最も実践的な教訓: **ルール（AGENTS.md の散文）は遵守率 ~80%。機械的チェック（リンター、フック、CI）は 100%。** 業界がこの方向に収束している。

自設計の canonical ルールのうち、機械的に判定可能なものは Cursor / Claude Code のフック機構で強制すべき。これが Epic #10 #17（フック基盤整備）の背景。

この原則をコミットフローに具体適用した検討が [`docs/draft/commit-gate-and-rule-observability.md`](../../../docs/draft/commit-gate-and-rule-observability.md) にある。ルールが向くもの（文脈依存の判断、例外が自然に発生）とゲートが向くもの（二値判定、スキップ理由の構造化）の仕分け原則を導出している。

### 「ハーネス = 自分が作ろうとしているもの」

orchestration-research で設計しようとしている「構造化ドキュメントルーティングエンジン」は、ハーネスの語彙で言えば **コーディングエージェント特化ではない汎用ハーネス** に相当する。OpenAI や LangChain のハーネスはコーディング特化だが、構造は同型:

- コンテキスト管理（何を見せるか）
- ツール管理（何ができるか）
- 検証ループ（出力が正しいか）
- フィードバックループ（失敗を環境改善に変える）
- 人間ゲート（どこで人間が介入するか）

## 参照

- `docs/research/harness-engineering/README.md` — 全33本の記事インデックス
- `docs/research/harness-engineering/current-state-assessment.md` — 現状評価・ギャップ分析・Issue カバレッジマップ
- [Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) — OSS パターン取り込み
- [Issue #17](https://github.com/stlwolf/ai-development-hub/issues/17) — フック基盤整備
- [Issue #24](https://github.com/stlwolf/ai-development-hub/issues/24) — フック拡充エピック（H-1〜）
- [Issue #19](https://github.com/stlwolf/ai-development-hub/issues/19) — オーケストレーションツール MVP
- `synthesis/context-foundation.md` — コンテキスト基盤設計ノート
- `docs/draft/orchestration-control-loop-challenges.md` — 制御ループ課題
- [Epic #37](https://github.com/stlwolf/ai-development-hub/issues/37) — Harness Engineering 基盤整備（ギャップ追跡エピック）
- [NLAH 論文](https://arxiv.org/abs/2603.25723) — Natural-Language Agent Harnesses（清華大学・ハルビン工業大学, 2026-03）

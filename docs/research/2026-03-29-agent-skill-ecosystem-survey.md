---
title: "Agent Skill Ecosystem 調査: gstack / specre / superpowers"
date: 2026-03-29
status: research-complete
tags: [agent-skills, claude-code, workflow-comparison, ecosystem]
sources:
  - https://github.com/garrytan/gstack
  - https://github.com/yoshiakist/specre
  - https://github.com/obra/superpowers
next_step: 流用候補アイデアの優先度判断 → 個別スキル/ルール設計
---

# Agent Skill Ecosystem 調査: gstack / specre / superpowers

## 動機

2026年3月時点で話題になっている3つのエージェントスキル/ワークフロー系リポジトリを調査し、自分のワークフロー（ai-development-hub）との類似・相違・統合可能性を整理する。

## 調査対象サマリ

| 項目 | gstack | specre | superpowers |
|------|--------|--------|-------------|
| **リポジトリ** | [garrytan/gstack](https://github.com/garrytan/gstack) | [yoshiakist/specre](https://github.com/yoshiakist/specre) | [obra/superpowers](https://github.com/obra/superpowers) |
| **言語** | TypeScript (Bun) | Rust | Shell / Markdown |
| **Stars** | ~46,800 | 21 | ~112,200 |
| **最新版** | v0.11.18.2 | v0.4.0 | v5.0.5 |
| **公開日** | 2026-03-11 | 2026-02-13 | 2025-10 |
| **作者** | Garry Tan (YC CEO) | yoshiakist | Jesse Vincent |
| **一言** | 役割別28+スキル群 + 常駐ブラウザ | 1挙動=1Markdown の仕様駆動開発 | Claude公式プラグイン、プロセス強制スキル群 |

## 個別調査結果

### gstack

**概要:** Claude Code向けの「仮想エンジニアリングチーム」。CEO/EM/デザイナー/QA/SRE等の役割に対応するスキル群と、Playwright+Bunによる常駐ヘッドレスブラウザデーモンを一体配布する。

**スキル体系:**

- Think: `/office-hours`（前提を問い直し設計ドキュメント化）
- Plan: `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`（多角度レビュー）
- Build: `/design-consultation`（デザインシステム）
- Review: `/review`（本番破壊検出）, `/investigate`（原因調査）, `/design-review`（デザイン監査）
- QA: `/qa`, `/qa-only`（実ブラウザ検証）
- Security: `/cso`（OWASP+STRIDE）
- Ship: `/ship`（テスト・カバレッジ・PR）, `/land-and-deploy`（CI/デプロイ確認）
- Monitor: `/canary`（デプロイ後監視ループ）
- Meta: `/autoplan`（レビューパイプライン化）, `/codex`（セカンドオピニオン）

**設計思想:**

- `ETHOS.md`（"Boil the Lake" / "Search Before Building"）を全スキルに自動注入
- MCP不採用（HTTP+プレーンテキスト志向、デバッグ性重視）
- テレメトリはデフォルトOFF、スキーマ公開

**制約:**

- macOS Keychain前提のクッキー復号（Linux/Windows未実装）
- iframe未対応
- Bun必須（WindowsはNodeフォールバック）
- オピニオン強め（カバレッジ閾値・プラン完了ゲート等を強制）

**情報源:** [README](https://github.com/garrytan/gstack/blob/main/README.md), [ARCHITECTURE.md](https://github.com/garrytan/gstack/blob/main/ARCHITECTURE.md), [ETHOS.md](https://github.com/garrytan/gstack/blob/main/ETHOS.md), [CHANGELOG](https://github.com/garrytan/gstack/blob/main/CHANGELOG.md), [docs/skills.md](https://github.com/garrytan/gstack/blob/main/docs/skills.md)

---

### specre

**概要:** Spec-Driven Development向けの最小仕様フォーマットとRust製CLI。各仕様カードは「1挙動 = 1 Markdown」（YAMLフロントマター + ULID）で管理し、CLIとMCPサーバで仕様↔実装の双方向トレーサビリティを提供する。

**コア概念:**

- 仕様カード: YAMLフロントマター（`id`, `title`, `status`, `last_verified`, `Related Files`）+ Markdown本文
- トレーサビリティ: 仕様側は `Related Files`、コード側は `@specre <ULID>` コメント
- `index.json`: キャッシュ（仕様ファイルが真実の源泉）

**CLI機能:**

| コマンド | 用途 |
|----------|------|
| `init` / `new` | プロジェクト初期化・仕様カード作成 |
| `index` / `status` | インデックス再構築・ステータス一覧 |
| `trace` / `orphans` | 双方向リンク検証・孤立検出 |
| `coverage` | ソース内の `@specre` タグ付き率 |
| `health-check` | 仕様群の健全性判定（エージェントルーティングに使用） |
| `search` | フィルタ・AND/OR・glossaryヒント付き検索 |
| `mcp` | stdio MCPサーバ（Claude Code / Cursor等に接続） |

**設計思想:**

- LLMのコンテキストウィンドウ意識（小さな仕様カードに分割）
- プロセス非依存のデータ層（ツール・エンジンに縛られない）
- エージェントファースト: `health-check` で信頼度判定 → 健全なら仕様を第一探索手段に
- 段階的採用: Strategy A/B/C + アンチパターン（[adoption-strategy.md](https://github.com/yoshiakist/specre/blob/main/docs/guides/adoption-strategy.md)）

**制約:**

- v0.4時点で `drift`（ドリフト検出）/ `ci`（CI連携）は未実装
- `coverage` は `@specre` タグ付き率であり、挙動網羅率やテスト成功率ではない
- Rust 1.85+必須

**情報源:** [README](https://github.com/yoshiakist/specre/blob/main/README.md), [START-SPECRE.md](https://github.com/yoshiakist/specre/blob/main/docs/guides/START-SPECRE.md), [ROADMAP](https://github.com/yoshiakist/specre/blob/main/docs/project/ROADMAP.md), [CHANGELOG](https://github.com/yoshiakist/specre/blob/main/CHANGELOG.md), [adoption-strategy.md](https://github.com/yoshiakist/specre/blob/main/docs/guides/adoption-strategy.md), [Cargo.toml](https://github.com/yoshiakist/specre/blob/main/Cargo.toml)

---

### superpowers

**概要:** コーディングエージェント向けのコンポーザブルなスキルフレームワーク。Claude Code公式プラグインとして配布（Install 233K+）。brainstorm → 計画 → TDD → レビュー → ブランチ完了までを「強制ワークフロー」としてスキルで制御する。

**スキル体系:**

- Testing: `test-driven-development`
- Debugging: `systematic-debugging`, `verification-before-completion`
- Collaboration: `brainstorming`, `writing-plans`, `executing-plans`, `dispatching-parallel-agents`, `requesting-code-review`, `receiving-code-review`, `using-git-worktrees`, `finishing-a-development-branch`, `subagent-driven-development`
- Meta: `writing-skills`, `using-superpowers`

**ワークフロー（7フェーズ）:**

1. `brainstorming` — 意図の抽出、Visual Brainstorming（ローカルHTML）
2. `using-git-worktrees` — ブランチ分離
3. `writing-plans` — 設計・計画書
4. `subagent-driven-development` / `executing-plans` — サブエージェント実装
5. `test-driven-development` — TDD
6. `requesting-code-review` — レビュー依頼
7. `finishing-a-development-branch` — ブランチ完了

**設計思想:**

- "Mandatory workflows, not suggestions"（スキルは自動トリガー）
- "すぐコードを書かせない"（brainstormが始まれば成功のスモークテスト）
- ユーザー / CLAUDE.md / AGENTS.md をSuperpowers内部指示より優先
- v5でサブエージェントがadversarialにSpec Reviewする機能追加

**マルチプラットフォーム:** Claude Code / Cursor / Codex / Gemini CLI / OpenCode

**制約:**

- Visual Brainstormingはトークン消費大
- サブエージェント非対応ハーネスではベストエフォート
- v5でスラッシュコマンド非推奨化（将来削除予定）

**情報源:** [README](https://github.com/obra/superpowers/blob/main/README.md), [CHANGELOG](https://github.com/obra/superpowers/blob/main/CHANGELOG.md), [作者ブログ 2025-10](https://blog.fsck.com/2025/10/09/superpowers/), [v5ブログ](https://blog.fsck.com/2026/03/09/superpowers-5/), [Claude公式プラグイン](https://claude.com/plugins/superpowers)

---

## 自分のワークフローとの比較

### 自分のスタックの特徴

| 特徴 | 実装 |
|------|------|
| 人間ゲート | `implementation-gate-rule`（Plan mode必須）、`decision-pacing-rule`（報告≠対処決定） |
| 多モデル品質ループ | `so-compare`（Codex+Claude）、`arena-compare`（3+モデル並列）、`/peer-ai-review` |
| 役割別サブエージェント | `oss-researcher` / `vendor-inspector` / `playwright-agent` + カスタムエージェント優先ルール |
| ドキュメント媒介 | Kickoff → `kickoff-to-plan` → Plan → Episode → Decision/ADR |
| 薄いシェル層 | Bash + Markdown + CLI、重いFW・ベンダーロックイン回避 |
| コンテキスト予算 | サブエージェントで分離、`-w`でワークスペース参照、スキルは遅延ロード |
| MCP活用 | Playwright MCP優先 |

### 類似点の整理

#### gstack と共通する設計

- **役割別スキル**: gstack の CEO/EM/QA ≒ 自分の `oss-researcher`/`vendor-inspector`/`playwright-agent`
- **スプリント全体カバー**: gstack の `/office-hours` → `/ship` ≒ Kickoff → Plan → peer-review → PR conventions
- **品質ゲート**: gstack の `/review` + カバレッジゲート ≒ `/peer-ai-review` + `so-compare` 3者合意

#### specre と共通する設計

- **ドキュメント媒介**: 「1挙動 = 1 Markdown」≒ `context-foundation.md` の「構造化ナレッジ = frontmatter + Markdown」
- **エージェントファースト**: `health-check` → `search` ≒ サブエージェントに `persistent-exploration` を注入してまず探索
- **ライフサイクル管理**: `status` + `last_verified` ≒ 「生成→保存→検索→昇格→失効」
- **MCP**: stdio MCP ≒ Playwright MCP と同じ方向

#### superpowers と共通する設計

- **「すぐコードを書かせない」**: brainstorm開始 = 成功 ≒ `implementation-gate-rule`（**最も思想が近い**）
- **スキル = 強制ワークフロー**: "Mandatory workflows" ≒ ユーザールール群の always-apply
- **サブエージェント活用**: `subagent-driven-development` ≒ `subagent-strategy-rule`

### 相違点の整理

| 観点 | gstack | specre | superpowers | 自分 |
|------|--------|--------|-------------|------|
| **ゲート主体** | スキルが自動判定 | health-checkが判定 | スキルが自動トリガー | **人間がペースを握る** |
| **品質検証** | 単一モデル内ロール切替 | N/A | サブエージェントadversarial | **マルチモデル並列** |
| **ブラウザ** | 内蔵Chromiumデーモン | なし | Visual Brainstormingのみ | Playwright MCP |
| **MCP** | 不採用 | 対応 | プラグインシステム | 活用 |
| **配布** | git clone + setup | cargo install / installer | プラグインマーケット | symlink sync scripts |
| **成熟度** | v0.11（2週間） | v0.4（1.5ヶ月） | v5.0（5ヶ月） | 継続進化中 |

---

## 統合・流用可能性の分析

### 自分のワークフローに取り込める可能性があるアイデア

#### A. Adversarial Spec Review（出典: superpowers）

- **概要:** Plan/仕様を書いた後、サブエージェントに「この計画の穴」を探させるステップ
- **接続先:** `kickoff-to-plan` 後の新ステップ
- **自分との差分:** 現在の `so-compare` は「別モデルに同じ問題を解かせる」。adversarial review は「同じモデルに反論者をやらせる」のでコストが安い
- **難易度:** 低（サブエージェントに反論者プロンプトを注入するだけ）

#### B. ULID双方向トレース（出典: specre）

- **概要:** Decision Record / Episode / ADRにULIDを振り、コード側に `@specre` 的なアノテーションを入れる
- **接続先:** `context-foundation.md` のトレーサビリティ設計、`orchestration-control-loop-challenges.md` のドリフト問題
- **自分との差分:** 現在はIssue番号でのゆるい紐づけのみ。ULID双方向リンクは未実装
- **難易度:** 中（フォーマット設計 + コードアノテーション規約の策定が必要）

#### C. health-check → 自律度ルーティング（出典: specre）

- **概要:** コンテキストの健全性を自動判定し、健全なら自律実行を許可、不健全なら人間ゲート強制
- **接続先:** `context-foundation.md` の「ガードレールの時間変化」研究
- **自分との差分:** 現在は `implementation-gate-rule` で一律に人間ゲート。状態に応じた動的ゲートはない
- **難易度:** 中（判定基準の設計が肝。何をもって「健全」とするか）

#### D. Visual Brainstorming（出典: superpowers）

- **概要:** Kickoff/Planフェーズで設計の視覚化（ローカルHTML生成）
- **接続先:** Kickoff → Plan の間
- **自分との差分:** 現在はテキストベースのみ
- **難易度:** 低（Cursor の browser MCP / canvas 機能と組み合わせ可能）

#### E. レビューパイプライン自動化（出典: gstack `/autoplan`）

- **概要:** CEO → Design → Eng のレビューを自動チェーンする
- **接続先:** `kickoff-to-plan` + `peer-ai-review` の間をスキルで接続
- **自分との差分:** 現在はPlan生成とレビューが手動トリガー
- **難易度:** 中（スキルチェーンの設計、どこまで自動化するか人間ゲートとの折り合い）

#### F. デプロイ後監視ループ（出典: gstack `/canary`）

- **概要:** マージ後のCI/デプロイ確認 → 異常検出 → 自動対処
- **接続先:** `orchestration-control-loop-challenges.md` の「状態判定→再投入」
- **自分との差分:** 現在のワークフローはPR作成で終了
- **難易度:** 高（インフラ依存、プロジェクト固有のモニタリング設定が必要）

#### G. 用語辞書（glossary）（出典: specre）

- **概要:** ドメイン用語をTOML/YAMLで管理し、スキルやベースプロンプトに注入
- **接続先:** `context-foundation.md` の「Codebase Knowledge」層
- **自分との差分:** 現在はCLAUDE.md/AGENTS.md内に手動記述
- **難易度:** 低（ファイルフォーマットとスキルへの読み込み手順を決めるだけ）

#### H. セッション開始時の自動診断（出典: superpowers hooks）

- **概要:** セッション開始時にスキル検索・状態チェックを自動実行
- **接続先:** ユーザールール / CLAUDE.md
- **自分との差分:** 現在のルールは宣言的（常時適用）だが、起動時の能動的な診断はない
- **難易度:** 低〜中（Cursorのフック仕様に依存）

### 優先度判断の材料

| アイデア | コスト | 既存研究との接続 | 日常の痛み解消 |
|----------|--------|------------------|----------------|
| A. Adversarial Review | 低 | kickoff-to-plan | 高（計画の穴を事前発見） |
| B. ULID双方向トレース | 中 | context-foundation | 中（ドリフト検出が未来課題） |
| C. health-check ルーティング | 中 | ガードレール研究 | 中（動的ゲートの実験） |
| D. Visual Brainstorming | 低 | - | 低〜中（テキストで十分な場合が多い） |
| E. レビューパイプライン | 中 | peer-ai-review | 中（手動でも回っている） |
| F. デプロイ後監視 | 高 | control-loop研究 | 低（プロジェクト固有） |
| G. 用語辞書 | 低 | context-foundation | 低（CLAUDE.mdで間に合っている） |
| H. セッション自動診断 | 低〜中 | - | 低（ルールの宣言的適用で十分） |

---

## 調査メモ

### gstack の話題性について

公開から約2週間で~47K Starsという異常な初動。YC CEO（Garry Tan）のネットワーク効果 + AIエージェントコーディングへの関心の高さが背景。READMEの「60日で60万行」等の生産性主張は作者自己申告であり、第三者検証は未確認。

### specre の日本語圏での位置づけ

日本人作者（yoshiakist）。README日本語版あり。dev.toでForemコードベースからの挙動抽出実験を記事にしている（[記事](https://dev.to/yoshiakist/what-if-we-extracted-literally-every-behavior-of-devto-into-markdown-an-ai-agent-experiment-2k7l)）。Star数は小規模だが、「仕様をエージェントが機械的に辿れる」というニーズはAIコーディングの文脈で拡大中。

### superpowers のエコシステム影響

Claude Code公式プラグインとして233K+ Installは大きい。Jesse Vincentのブログで設計判断が詳細に公開されており、skills/pluginの設計パターンとして参考価値が高い。HNで複数回議論されている（[例1](https://news.ycombinator.com/item?id=45547344), [例2](https://news.ycombinator.com/item?id=47341827)）。

### 3プロジェクトに共通する傾向

- 「エージェントにすぐコードを書かせない」= 計画フェーズの強制
- Skills/SKILL.md 形式の標準化が進行中
- マルチIDE対応（Claude Code + Cursor + Codex + Gemini CLI）が前提
- ドキュメント（Markdown）がエージェント間の通信プロトコルとして機能

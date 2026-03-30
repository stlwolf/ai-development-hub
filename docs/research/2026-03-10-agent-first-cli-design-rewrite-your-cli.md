---
title: "Agent-First CLI 設計: You Need to Rewrite Your CLI for AI Agents"
date: 2026-03-10
status: research-complete
tags: [agent-dx, cli-design, mcp, context-window, input-hardening, agent-skills]
sources:
  - https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/
  - https://justin.poehnelt.com/posts/mcp-abstraction-tax/
related_ideas:
  - ideas/20260130/ai-native-interface-concept.md
  - ideas/20260130/ai-middleware-cli-concept.md
  - ideas/20260204/ai-agent-orchestration.md
  - ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md
  - ideas/20260212/hypothesis-canonical-agent-definition-format.md
  - ideas/20260215/ai-readable-code-organic-understanding-synthesis.md
  - ideas/20260218/hypothesis-inference-ratio-certainty-model.md
  - ideas/20260220/context-persistence-4layer-model.md
  - ideas/20260224/hypothesis-json-schema-aggregation-orchestration.md
next_step: so-compare / arena-compare の Agent DX 改善検討、MCP Abstraction Tax 続編の調査
---

# Agent-First CLI 設計: You Need to Rewrite Your CLI for AI Agents

## 動機

Justin Poehnelt（Google Senior DevRel）が2026-03-04に公開した記事 [You Need to Rewrite Your CLI for AI Agents](https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/) を発見。Google Workspace CLI（`gws`）をエージェントファーストで設計した実践知が、自分が1〜2月に `ideas/` で構想していた方向性とほぼ一致していた。記事の知見と、自分のアイデア群との対応関係・流用可能性を記録する。

## 記事の要旨

**中心主張:** Human DX（発見可能性・寛容さ）と Agent DX（予測可能性・多層防御）は直交する設計軸であり、人間向けCLIをエージェント用に後付けするのは負け戦。

### 8つの設計原則

| # | 原則 | 要点 |
|---|------|------|
| 1 | **Raw JSON > Bespoke Flags** | `--json` でAPIペイロードをそのまま受け渡し。フラグ群はネスト構造を表現できない |
| 2 | **Schema Introspection** | `gws schema <method>` で実行時にスキーマ取得。静的ドキュメントはトークン浪費かつ陳腐化 |
| 3 | **Context Window Discipline** | field masks で返却フィールド限定、NDJSON pagination でストリーム処理 |
| 4 | **Input Hardening** | パストラバーサル・ダブルエンコーディング・制御文字・ID内クエリパラメータの拒否。「エージェントは信頼されたオペレーターではない」 |
| 5 | **Agent Skills** | 100+ `SKILL.md` を同梱。`--help` では伝わらない不変条件（dry-run推奨、field masks必須等）を明示 |
| 6 | **Multi-Surface** | CLI / MCP stdio / Gemini Extension / 環境変数の4面を同一バイナリで提供。Discovery Document が単一の真実源泉 |
| 7 | **Dry-Run** | `--dry-run` でAPIを叩かずにリクエストを検証。ハルシネーションしたパラメータのコストはデータ損失 |
| 8 | **Response Sanitization** | Google Cloud Model Armor で応答を消毒。APIレスポンス内のプロンプトインジェクション対策 |

### 著者の推奨導入順序

1. `--output json`
2. 入力バリデーション
3. `--describe` / schema コマンド
4. field masks / `--fields`
5. `--dry-run`
6. `CONTEXT.md` / skill files
7. MCP surface

---

## 自分のアイデアとの対応マップ

### 1. Agent-First CLI（JSON出力・機械可読性）

- **記事:** `--json` でAPIペイロードをそのまま渡す
- **自分:** `ai-native-interface-concept.md`（1/30）で「人間向けCLIとAI向けインターフェースの分離」、`ai-agent-orchestration.md`（2/4）で `--output-format json` やコンテキスト・エンベロープを提案
- **差分:** 記事はAPIラッパーCLIの文脈。自分はオーケストレーション間通信としてのJSON構造化が主眼

### 2. Schema Introspection

- **記事:** `gws schema` で Discovery Document からメソッドシグネチャを実行時取得
- **自分:** `hypothesis-canonical-agent-definition-format.md`（2/12）で正準エージェント定義フォーマット、`hypothesis-json-schema-aggregation-orchestration.md`（2/24）で共通レポートスキーマによる親子スレッド間契約
- **差分:** 記事はAPI仕様のランタイム参照。自分はエージェント定義・タスク出力の構造化スキーマ。対象は違うが「スキーマが文書を置き換える」という思想は同一

### 3. Context Window Discipline

- **記事:** field masks + NDJSON pagination
- **自分:** `ai-middleware-cli-concept.md`（1/30）でコンテキスト純度と `--limit`/`--summarize`/`--compress`、`hypothesis-intentional-compression-and-promotion-flow.md`（2/8）で三層構造＋昇格フロー、`context-persistence-4layer-model.md`（2/20）で4層モデル＋TTL、`hypothesis-inference-ratio-certainty-model.md`（2/18）で「切り落としの精度がボトルネック」
- **差分:** 記事はCLI出力のサイズ制限に閉じている。自分の構想はコンテキスト管理の全体体系（即時参照/構造化ナレッジ/生ログ/コード）まで射程が広い

### 4. Input Hardening

- **記事:** パストラバーサル・制御文字・ダブルエンコーディングのバリデーション。「エージェントは信頼されたオペレーターではない」
- **自分:** `human-input-formatting.md`（2/20）で人間→AI入力の品質標準化、`hypothesis-json-schema-aggregation-orchestration.md`（2/24）で出力の厳格JSONスキーマバリデーション＋プロンプトインジェクション対策
- **差分:** 記事は「エージェントの入力を信頼しない」（defensive）。自分は「入力品質をプロセスとして上げる仕組み」（constructive）も含む。両方必要

### 5. Agent Skills

- **記事:** 100+ `SKILL.md` を同梱、YAML frontmatter + Markdown
- **自分:** `hypothesis-canonical-agent-definition-format.md`（2/12）でツール横断の正準フォーマットを提案。実装面では `~/.cursor/skills/` に十数個配置済み
- **差分:** 記事は自社CLI向けスキル。自分はClaude Code / Cursor / Codex 横断の汎用フォーマット。記事の SKILL.md と superpowers の SKILL.md、自分のスキルシステムが同時期に同形式で収束しているのは注目に値する

### 6. Multi-Surface

- **記事:** CLI / MCP stdio / Gemini Extension / 環境変数の4面
- **自分:** `ai-middleware-cli-concept.md`（1/30）で CLI層 / MCP tools / AIネイティブプロトコルのシナリオ整理、`orchestration-design-principles-bath-brainstorm.md`（2/24）で MCP / Agent-to-Agent Protocol による差し替え可能性
- **差分:** 記事は「同一バイナリから複数surface」。自分は「surface間の抽象化と差し替え可能性」。続編 [The MCP Abstraction Tax](https://justin.poehnelt.com/posts/mcp-abstraction-tax/) がこの点をさらに掘り下げている

### 7. Safety Rails

- **記事:** `--dry-run` + Model Armor によるレスポンス消毒
- **自分:** `hypothesis-second-opinion-review-flow.md`（2/8）で反証担当固定のセカンドオピニオン、`ai-agent-orchestration.md`（2/4）で「CLI連携 = 認知的多様性の強制」
- **差分:** 記事は個別コマンド単位の安全装置。自分はワークフロー全体の構造的安全性（権限極小化、マルチモデル合意、人間ゲート）

### 8. Agent DX vs Human DX

- **記事:** 「Human DXは発見可能性と寛容さ、Agent DXは予測可能性と多層防御。直交する」
- **自分:** `ai-native-interface-concept.md`（1/30）で分離を提案、`ai-readable-code-*`（2/15）群で「可読性の対象が人間→AIにシフト」「AIが正しく説明できる形が正義になる」
- **差分:** 記事はCLIのI/O設計に限定。自分はコード・ドキュメント・ワークフロー全体のAgent DXまで射程を広げている

---

## 自分の構想が先行・深掘りしている領域

| 領域 | 記事 | 自分 |
|------|------|------|
| コンテキスト管理 | field masks（出力サイズ制限） | 4層モデル・昇格フロー・TTL・推測比率モデル |
| 入力品質 | バリデーション（拒否） | 拒否 + フォーマット提示による品質向上プロセス |
| 安全性 | dry-run + sanitize（個別防御） | セカンドオピニオン・権限極小化・スキーマバリデーション（構造的防御） |
| スキル標準化 | 自社CLI向け SKILL.md | ツール横断の正準フォーマット |
| 可読性の再定義 | 言及なし | AI-Readable Code 概念（2/15の議論群） |

---

## 自分のツールへの流用可能性

### A. `so-compare` / `arena-compare` の Agent DX 改善

記事の推奨導入順序をそのまま適用できる候補。

| 項目 | 現状 | 改善案 | 優先度 |
|------|------|--------|--------|
| `--output json` | テキスト出力のみ | 構造化JSON出力モード | 中 |
| 入力バリデーション | プロンプトをそのまま渡す | ワークスペースパス検証、制御文字除去 | 低 |
| `--dry-run` | なし | パラメータ確認のみで実行しないモード | 低 |
| field masks 的な出力制限 | `--codex-only` 等はある | 出力セクション選択（diff-only, summary-only） | 中 |

### B. SKILL.md のメタデータ充実

記事の `gws` スキルが YAML frontmatter に `requires.bins` を含むパターンは、自分のスキルシステムにも適用可能。現在のスキルには前提条件の機械可読な宣言がない。

```yaml
metadata:
  requires:
    bins: ["so-compare", "arena-compare"]
    mcp: ["user-playwright-mcp"]
```

### C. MCP surface の検討

`so-compare` / `arena-compare` をMCP toolとして公開すれば、エージェントがシェルエスケープなしで呼び出せる。ただし続編 [The MCP Abstraction Tax](https://justin.poehnelt.com/posts/mcp-abstraction-tax/) でMCP化のコスト（ツール数爆発、スキーマ変換ロス等）が議論されており、先にそちらを読んでから判断すべき。

### D. `claude-safe` の堅牢化

記事の Input Hardening パターンは `claude-safe`（Cursor統合ターミナル用Claude CLIラッパー）に直接適用できる。エージェントから呼ばれるケースでは、プロンプト内の制御文字・パストラバーサルの除去が安全策になる。

---

## 調査メモ

### 著者について

Justin Poehnelt は Google の Senior Developer Relations Engineer。Google Workspace CLI（`gws`）をRustで実装。エージェントファーストを Day One から設計に組み込んだ実践者。[OpenClaw](https://openclaw.org/) コントリビュータでもあり、Agent Skills の標準化にも関与。

### 記事のコンテキスト

- 公開日: 2026-03-04
- 続編 [The MCP Abstraction Tax](https://justin.poehnelt.com/posts/mcp-abstraction-tax/) が 2026-03-06 に公開。CLIの上にMCPを乗せることのコスト（ツール数爆発、型変換ロス、デバッグ困難）を論じている
- `gws` はオープンソース。Google Discovery Document をランタイムのスキーマ源泉として使う設計が特徴的

### `ideas/` との時系列

- 2026-01-30: `ai-native-interface-concept.md`, `ai-middleware-cli-concept.md` — Agent DX / Human DX 分離、コンテキスト純度
- 2026-02-04: `ai-agent-orchestration.md` — `--output-format json`、コンテキスト・エンベロープ
- 2026-02-08: 圧縮・昇格フロー、セカンドオピニオンフロー
- 2026-02-12: 正準エージェント定義フォーマット
- 2026-02-15: AI-Readable Code 議論群
- 2026-02-18: 推測比率・確実性モデル
- 2026-02-20: 4層コンテキストモデル、入力品質標準化
- 2026-02-24: JSON Schema集約オーケストレーション
- **2026-03-04: 記事公開** ← 自分のアイデア群の1〜2ヶ月後

1月末〜2月にかけての構想が、3月にGoogleの実装者から実践ベースで裏付けられた形。方向性の妥当性を示す外部エビデンスとして価値がある。

### 未読・次に確認すべきもの

- [The MCP Abstraction Tax](https://justin.poehnelt.com/posts/mcp-abstraction-tax/)（2026-03-06）: MCP化の判断材料
- `gws` リポジトリのSKILL.md群: スキルフォーマットの実例
- OpenClaw: Agent Skills 標準化の動向

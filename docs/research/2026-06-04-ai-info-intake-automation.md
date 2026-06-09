---
title: "AI情報収集の自動化 — TOKIUM実装事例と「気になる情報→Issue化」フローの前史"
date: 2026-06-04
status: research-complete
tags: [research-intake, info-collection, pipeline, automation, schedule, feedback-loop]
sources:
  - https://zenn.dev/tokium_dev/articles/20260427_ai_tech_researcher
  - https://app.notion.com/p/9e36e367b18e46a684e3c173b47f9a48
related_ideas:
  - ideas/20260329/metadata-layer-mirror-repo-synthesis.md
next_step:
  trigger: "research-intake の定期自動化を検討するとき（Issue 作成済み）、または research-intake コマンド自体の改善を着手するとき"
  actions: "新規 Issue（research-intake 定期自動化）の設計フェーズで、TOKIUM の『レポート採用率ベース評価』とフィードバックループ設計を参照する。/schedule スキルで research-intake を定期起動するか、cron+SKILL.md の TOKIUM 方式に近い実装を検討する。採用率評価を research-intake の next_step 記述ルールに組み込む余地もある（どのノートが後続 Issue/PR で参照されたかをトラック）。"
  referenced_by: "research-intake コマンド改善タスク全般 / 新規 Issue: research-intake 定期自動化"
---

## 概要

2 つの情報源を統合した research-intake セッションの記録。

1. **TOKIUM ブログ記事**（2026-05-07）: 育休中の情報断絶を防ぐため構築した AI 情報収集基盤。自動進化する情報源管理が特徴。
2. **Notion「気になる情報から実際のissueまで作成するフロー」**（2026-04-06, AI議論倉庫, Status: 未着手）: ChatGPT との壁打ちで「外部情報→本質抽出→Issue化」のフローを設計した議論。**これが research-intake コマンドの前史にあたる。**

最大の発見: Notion 議論（前史）と TOKIUM 実装（外部実証）が同じ構造を別の文脈で実現しており、**research-intake の手動フローを cron/schedule で自動化する**という方向性が裏付けられた。

---

## 記事情報

### TOKIUM ブログ

- **タイトル**: 1年間の育休に備えて「勝手に賢くなる」AI情報収集基盤を作った
- **URL**: https://zenn.dev/tokium_dev/articles/20260427_ai_tech_researcher
- **著者/組織**: sk / TOKIUM
- **公開日**: 2026年5月7日
- **種別**: ブログ記事
- **要約**: TOKIUMのEMが育休中の技術情報断絶を防ぐため構築した自動収集・レポート生成基盤。Zenn/Qiita/Slack から AI が情報収集し日次・週次・月次レポートを Google Drive に自動保存。情報源を SQLite で管理し「レポートへの実採用実績」で昇格/降格を制御する自動進化メカニズムが核。SKILL.md にタスク手順を記述し Claude Code が自律実行する構造。約3週間で日次15本・週次3本を自動生成、自動進化も正常稼働。

### Notion 議論（前史）

- **タイトル**: 気になる情報から実際のissueまで作成するフロー
- **URL**: https://app.notion.com/p/9e36e367b18e46a684e3c173b47f9a48
- **日付**: 2026-04-06
- **AI**: ChatGPT
- **Status**: 未着手（アイデア化未実施）
- **要旨**: RSS スター/Twitter バズ/GitHub 等から情報を検知→AI スコアリング（relevance/novelty/actionability 等）→本質抽出→Issue化 という4段階フローを設計。「収集」ではなく「吸収」中心の設計を推奨。固定出力テンプレート（Summary/Why it matters/Reusable essence/Concrete candidates/Suggested action）を提案。この構造は research-intake.md の出力形式と構造同型であり、**research-intake.md がこの議論の形式化した成果物**にあたる。

---

## 本質的パターンと詳細

| # | パターン名 | 本質 | 種別 | 検証/根拠 |
|---|-----------|------|------|----------|
| 1 | レポート採用率ベース評価 | 情報源の質を「取得できたか」でなく「最終レポートに実際に採用されたか」で評価。ノイズを構造的に除去 | 評価手法 | `unverified-summary`（記事の主張） |
| 2 | 4軸独立進化収集 | キーワード/Webソース/Slackチャンネル/Slackユーザーが独立してライフサイクルを持つ。各軸の盲点を相互補完 | 設計原則 | `unverified-summary`（記事の主張） |
| 3 | SQLite-driven Source Lifecycle | SQLite で情報源を一元管理し、候補→昇格（14日以内）→降格の3段階を採用実績で制御 | 実装パターン | `unverified-summary`（記事の主張。スキーマ詳細は非公開） |
| 4 | SKILL.md駆動パイプライン | タスク手順を Markdown の SKILL.md に記述し Claude Code が自律実行。シェルスクリプトが実行順序を制御するレイヤー分離 | ワークフロー | `unverified-summary`（記事の主張） |
| 5 | 堅牢パイプライン4要素 | 並列実行・部分失敗許容・暴走防止・冪等性を明示的に設計。一部失敗してもパイプライン全体は継続 | 設計原則 | `unverified-summary`（記事の主張） |
| 6 | フィードバックループ全体設計 | 「収集→評価→昇格/降格→次回収集」の閉ループで情報源を継続的に改善する自己進化パターン | ワークフロー | `unverified-summary`（記事の主張） |

### パターン詳細

- **#1 レポート採用率ベース評価**: 単なる「取得できたか（hit数）」ではなく「最終成果物に採用されたか」を品質評価基準にする。これは research-intake にも応用できる — 保存したリサーチノートが後続 Issue/PR で実際に参照されたかをトラックする仕組みがあれば、ノートの質評価が可能になる。
- **#3 SQLite Source Lifecycle**: 新しいキーワード（例: Mastra）が複数ソースで出現し始めると14日以内に検索対象に昇格、逆に一定期間成果なしが続くと降格する。廃れた情報源に引きずられず、トレンドに追従できる。ideas/20260329/metadata-layer-mirror-repo-synthesis.md の Decision Ledger と構造同型（採用実績 = promotion の評価基準）。
- **#4 SKILL.md駆動パイプライン**: このリポジトリの canonical/skills/ と同じ SKILL.md パターンを cron で定期実行している。「手順の記述場所（Markdown）」と「実行タイミングの制御（cron+shell）」を分離する設計。
- **#5 堅牢パイプライン4要素**: 部分失敗許容（一部の情報源が失敗してもパイプライン全体は継続）・冪等性（同じ実行を繰り返しても重複が出ない）・暴走防止（無限ループ/コスト爆発の抑制）・並列実行（複数ソース同時処理）。orchestration-engine Issue #105/#108 が目指す設計要素の動作実績あり参照事例。

---

## 資産マッピング結果

### トラックA: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ/新規知見 |
|---------|--------|-----------|-----------------|
| SKILL.md駆動パイプライン | canonical/skills/ 体系 + Notion discussion | 補強 | **Notion議論が research-intake の前身**。cron定期実行は未実装 |
| 堅牢パイプライン4要素 | Issue #105/#108 (Phase 5 パイプライン駆動) | 補強 | TOKIUM実装が動作実績のある実装参照事例 |
| フィードバックループ全体 | Issue #62 (失敗の構造化蓄積・次サイクル注入) | 構造同型 | 対象が違う（外部情報源 vs 内部失敗知識）がパターンは同型 |
| SQLite Source Lifecycle | ideas/20260329/metadata-layer-mirror-repo-synthesis.md | 構造同型 | Decision Ledger と「採用実績で昇格/降格」の構造が一致 |
| 4軸独立進化 | ideas/20260414/harness-architecture-layer-separation-control-loop.md | 構造同型 | 非決定的探索（複数軸独立進化）→決定的統合（レポート生成）が determinism boundary と同型 |

### トラックB: 新規導入候補

| パターン | 導入形態 | 備考 |
|---------|---------|------|
| 外部情報の定期自動収集 | `create-issue`（実施済み） | /schedule スキルで research-intake を定期起動するか、cron+SKILL.md パターンで実装 |
| レポート採用率ベース評価 | `defer` | research-intake フィードバック拡張として記録。next_step 参照 |

---

## アクション判定

| # | パターン | アクション | 理由 |
|---|---------|-----------|------|
| 1 | 外部情報定期自動収集 | `create-issue` | Notion前史 + TOKIUM実証で裏付けが揃った。/schedule 連携の実験価値あり |
| 2 | SKILL.md駆動パイプライン | `archive-note` | 既存資産の補強。新規アクション不要 |
| 3 | 堅牢パイプライン4要素 | `archive-note` | Issue #105/#108 の参照事例として記録。直接コメントは不要 |
| 4 | レポート採用率ベース評価 | `defer` | research-intake フィードバック拡張として将来検討 |
| 5 | Notion前史 | `archive-note` | research-intake.md が形式化成果物。追加のアイデア化は不要 |

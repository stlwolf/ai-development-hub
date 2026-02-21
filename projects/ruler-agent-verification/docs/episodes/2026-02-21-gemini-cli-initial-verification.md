---
title: "Gemini CLI ルーラーエージェント検証"
date: 2026-02-21
type: report
participants:
  - Eddy
  - Cursor Agent (Claude Opus 4.6, Primary)
  - Codex CLI (セカンドオピニオン)
  - Claude Code (セカンドオピニオン)
  - Gemini CLI (検証対象: gemini-2.5-pro, gemini-3-flash-preview)
related:
  - type: derived_from
    ref: ../../../ideas/20260218/hypothesis-inference-ratio-certainty-model.md
    reason: "ルーラーエージェント構想の検証"
  - type: derived_from
    ref: ../../../ideas/20260218/discussion-log-inference-ratio-domain-boundaries.md
    reason: "ルーラーエージェント構想の原型"
  - type: derived_from
    ref: ../../../ideas/connections.md
    reason: "ルーラーエージェント構想セクション"
  - type: depends_on
    ref: ../../second-opinion-verification/docs/episodes/2026-02-14-sentry-fix-codex-second-opinion.md
    reason: "ルーラーテストのタスク再現元"
  - type: depends_on
    ref: ../../second-opinion-verification/docs/plans/2026-02-14-codex-cli-verification-prompt.md
    reason: "Phase 1 の検証パターン元"
tags: [gemini-cli, ruler-agent, guide-agent, verification, access-model, rate-limit]
keywords: [gemini-3-flash-preview, gemini-2.5-pro, cloudcode-pa, oauth-personal, GEMINI_API_KEY, include-directories, ruler-prompt]
use_when:
  - "ルーラーエージェントの実現方法を検討するとき"
  - "Gemini CLI を自動化ワークフローに組み込むとき"
  - "AI CLI ツールのアクセスモデル（認証・レートリミット・コスト）を比較するとき"
  - "セカンドオピニオンの前段にコンテキスト自動選定を入れたいとき"
---

# Gemini CLI ルーラーエージェント検証

## 概要

ルーラーエージェント（判断履歴のナビゲーター）の実現可能性をGemini CLIで検証した。技術的には高い適性を確認したが、アクセスモデル（認証・レートリミット・コスト）が運用上の最大の障壁であることが判明した。

## 背景

20260218の仮説「推測比率と確実性の構造モデル」で提唱されたルーラーエージェントは、確実性の構造式（`情報の量 × 切り落としの精度 × 解釈能力 × 言語化の質`）における「切り落としの精度」を担う存在。

- 役割: 新規方針は提案しない。過去の判断の引用と適用候補提示に限定
- 位置づけ: `Cursor実装 → [Ruler: Gemini] → SO/Peer Review (Codex + Claude) → 3者合意`
- Gemini適性仮説: 1Mトークンコンテキスト + 低コスト + 推論強化がルーラーと相性がいい

## 検証結果

### Phase 0: corpus計測

| 指標 | 値 |
|---|---|
| ideas/ + SO docs/ ファイル数 | 約40ファイル |
| 単語数 | 18,263語 |
| バイト数 | 約300KB |
| トークン概算（日英混合 ×2.0） | 約36,500 tokens |
| Gemini 1Mコンテキストに対する使用率 | 約3.7% |

**結論**: 1M制約に対して余裕あり。全量投入が妥当。

### Phase 1: Gemini CLI基本検証

| テスト | モデル | 結果 | 所要時間 |
|---|---|---|---|
| 非インタラクティブ (`-p`) | 各種 | 動作 | 9-29秒 |
| JSON出力 (`--output-format json`) | 2.5-pro / 3-pro-preview | 動作 | 85秒/109秒 |
| AGENTS.md認識 | 3-pro-preview | `list_directory` + `read_file` で自律読み込み | 109秒 |
| パイプ入力 (`cat \| gemini -p`) | 3-pro-preview | 動作 | 84秒 |
| `--include-directories` | 3-pro-preview | 動作 | 73秒 |

**重要な発見**:

- Codexと異なり、AGENTS.mdを自動読み込みしない。ツール（`read_file`）で自律的に読む
- TTY問題なし（`claude-safe`ラッパー不要）
- `--include-directories ideas,projects/...` でcorpusを丸ごとコンテキスト注入可能
- ヘッドレスモード（`-p`）で使えるモデル名は `*-preview` サフィックス付きのみ。インタラクティブモードとモデル名解決が異なる

### Phase 1: モデル可用性

| モデル名 | ヘッドレスモード | 備考 |
|---|---|---|
| `gemini-3-pro-preview` | 動作（キャパ枯渇しやすい） | UA上はpro |
| `gemini-3-flash-preview` | 動作（キャパ枯渇しやすい） | UA上はflash |
| `gemini-2.5-pro` | 動作（間欠的に429） | |
| `gemini-2.5-flash` | 動作（最安定） | |
| `gemini-3.0`, `gemini-3-pro`, `gemini-3.1-*` 等 | 全て404 | ヘッドレスモード非対応 |

### Phase 1: レートリミット問題（最大の運用リスク）

| 認証方式 | エンドポイント | 制限 | 実用性 |
|---|---|---|---|
| OAuth personal（デフォルト） | `cloudcode-pa.googleapis.com` | サーバーキャパ枯渇で429頻発 | ルーラー運用に耐えない |
| API Key 無料枠 | `generativelanguage.googleapis.com` | 5 req/min, 100 req/day | テストには使えるが運用は厳しい |
| API Key 有料枠 | 同上 | 150 req/min（従量課金） | 使えるが追加コスト |
| Google Workspace | `cloudcode-pa` + GCPプロジェクト | 要設定 | セットアップが重い |

**Codex CLI / Claude Codeは既存サブスクに含まれ追加コスト不要。Gemini CLIだけ追加課金が必要。**

Google Workspace認証への切り替えにはGCPプロジェクトの連携が必要（`GOOGLE_CLOUD_PROJECT` 環境変数 + Gemini for Cloud APIの有効化 + IAM設定）。

### Phase 2: ルーラー機能プロトタイプ

同一のルーラープロンプト（`tmp/ruler-prototype-prompt.txt`）で2モデルを比較:

**テストタスク**: 「CakePHP 4のdeprecation対応で、PHP 8.1の型に関する非推奨警告（strtolowerにnullを渡しているケース等）を修正する方針を検討している」

| 観点 | gemini-2.5-pro | gemini-3-flash-preview |
|---|---|---|
| 応答時間 | 38秒 | 51秒 |
| 特定した判断数 | 2件 | 3件（+認証ライフサイクル知見） |
| 境界分析 | 2つ | 3つ（+CakePHP Lifecycle境界） |
| SOコンテキスト候補 | 3ファイル | 3ファイル（deep-dive再現フロー追加） |
| 制約条件 | 2つ | 3つ（+スタイル準拠、複数Agent検証） |
| 幻覚 | なし | **なし**（全引用が実在を確認済み） |
| 深さ | 妥当だが表面的 | より具体的（修正パターン候補の言及） |
| 出力フォーマット遵守 | 完全 | 完全 |
| 「該当なし」の申告 | 正直に2領域を申告 | 正直に2領域を申告（CakePHP固有知見なしを追加） |

**3-flash-previewが2.5-proより深い分析を提供。** 2.5-proが見つけなかった `SECOND_OPINION_CLAUDE_CODE.md` の「認証エラー時にinitialize()が呼ばれる」知見を正しく引用した。

### セカンドオピニオン結果

Codex CLI / Claude Codeに検証計画をレビュー依頼。両者とも「条件付き推奨」。

**3者が合意した指摘（計画に反映済み）**:

- Phase 0（corpus計測）の追加
- 成功基準の強化（幻覚観察の追加）
- ルーラー定義の修正（「新規判断しない」→「新規方針は提案しない、引用と候補提示に限定」）
- 判断の陳腐化リスクの認識

**棚上げした指摘**: Precision/Recall指標、RAG/ベクトルDB代替、A/B運用、運用ガバナンス（探索段階では過剰）

## ナレッジ（確立された知見）

### K1: Gemini CLIはルーラーとして技術的に適性が高い

- 指定フォーマットに忠実に従う
- 幻覚なし（2モデルとも全引用が実在）
- 「該当なし」を正直に申告する
- `--include-directories` でcorpus丸ごと注入できる
- ツール（`read_file`, `list_directory`）を自律的に使ってドキュメントを検索する

### K2: Gemini CLIのアクセスモデルはAI CLIツール中で最も厳しい

- 無料枠: OAuth personalはキャパ枯渇頻発、API Key無料枠は5 req/min
- 有料枠: 従量課金が必要（Codex/Claudeは既存サブスク内）
- Google Workspace: GCPプロジェクト連携のセットアップコストが高い

### K3: ヘッドレスモードとインタラクティブモードでモデル名解決が異なる

- インタラクティブ: `gemini-3.0` が通る（CLI内部で解決）
- ヘッドレス（`-p`）: `gemini-3-pro-preview` / `gemini-3-flash-preview` のようなAPI名が必要
- 3系安定版のモデル名はヘッドレスモードで404

### K4: 3-flash-previewは2.5-proよりルーラー性能が高い

- 同一プロンプトで、より多くの関連判断を特定
- より具体的な境界分析（CakePHPライフサイクル境界の識別）
- 2.5-proが見落としたドキュメントを正しく引用

### K5: ルーラープロンプトの「該当なし」セクションが重要

- 両モデルとも「該当する過去判断がない領域」を正直に申告した
- これはSOに「ここは過去判断なしで判断すべき」と伝える情報として有用
- 幻覚抑制にも効果がある（「ないなら作り出すな」という指示として機能）

### K6: SO（Codex + Claude）のプランレビューは過剰設計寄りのバイアスがある

- 探索的な検証実験に対して本番品質の評価指標を要求する傾向
- 「とりあえず動かして知見を得る」段階では、SOの指摘を全て反映するのではなく選別が必要

## 次回検証案

### V1: Google Workspace認証の設定とレートリミット改善

- GCPプロジェクト連携による `google-workspace` 認証タイプへの切り替え
- `GOOGLE_CLOUD_PROJECT` 設定後のレートリミット実測
- **目的**: アクセスモデルの障壁が技術的設定で解消できるか確認

### V2: ルーラー出力をSOに実際に渡す統合テスト

- ルーラー出力を `so-compare.sh -c` のコンテキストとして添付
- ルーラーあり/なしでSOの回答品質・収束速度に差が出るか比較
- **目的**: ルーラーのROIを実務レベルで検証

### V3: 実タスク（別プロダクト）でのルーラー検証

- ai-development-hubのideas/ではなく、別プロダクト向けリポジトリでの実際のdeprecationタスクで実行
- AGENTS.md + 過去のPR/Issue + SO結果をcorpusとして使用
- **目的**: 実プロダクトでのルーラーの有用性を検証

### V4: Codex/Claudeでのルーラー機能比較

- 同じルーラープロンプトをCodex exec / claude-safe に投げる
- Geminiとの品質・速度・コスト比較
- **目的**: ルーラーに最適なツールの選定。Geminiのアクセスモデル問題を回避できるか

### V5: 判断台帳（Decision Ledger）の構造化

- `decision_id/date/context/decision/rationale/superseded_by` の最小スキーマでideas/の判断を構造化
- 構造化データをルーラーに渡した場合の品質改善を測定
- **目的**: SOが指摘した「構造化すればgrepでかなり解決する」仮説の検証

### V6: ルーラー出力のキャッシュ/再利用

- 同一corpusに対するルーラー出力をキャッシュし、類似タスクでの再利用可能性を検証
- **目的**: レートリミット/コスト問題の緩和策

## 成果物一覧

| ファイル | 内容 |
|---|---|
| `tmp/ruler-prototype-prompt.txt` | ルーラーエージェントプロンプト |
| `tmp/peer-review-20260220-213555/ruler-output-gemini25-pro.txt` | gemini-2.5-pro のルーラー出力 |
| `tmp/peer-review-20260220-213555/ruler-output-gemini3-flash-preview.txt` | gemini-3-flash-preview のルーラー出力 |
| `tmp/peer-review-20260220-213555/so-output/` | SOプランレビュー結果（Codex + Claude） |
| `tmp/peer-review-20260220-213555/review-log.md` | peer-ai-reviewログ |
| `tmp/peer-review-20260220-213555/so-prompt.txt` | SOに投げたプランレビュープロンプト |

---

*作成日: 2026-02-21*
*作成方法: Cursor Agent (Claude Opus 4.6) によるセッション統合記録*

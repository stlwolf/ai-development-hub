# 仮説: 子スレッド出力のJSONスキーマ統一 + 親スレッド集約クエリ

- 日付: 2026-02-24
- 性質: 仮説。未検証。Claude/ChatGPT議論 + steipeteツイート分析から導出。
- derived_from:
  - [ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md](../20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 昇格フローのJSON実装形態
  - [ideas/20260222/orchestration-tool-building-approach.md](../20260222/orchestration-tool-building-approach.md) — 自前オーケストレーションツール構築
  - [ideas/20260224/orchestration-design-principles-bath-brainstorm.md](orchestration-design-principles-bath-brainstorm.md) — 原則2（直列プリミティブ合成）の中間表現
- related_project: [projects/orchestration-research/](../../projects/orchestration-research/)

---

## 着想: steipeteの「50並列Codex → JSONレポート」ツイート

steipete（Peter Steinberger）が大量PRの処理について投稿した内容が着想元:

> Been wrangling a lot of time how to deal with the onslaught of PRs, none of the solutions that are out there seem made for our scale.
> I spun up 50 codex in parallel, let them analyze the PR and generate a JSON report with various signals, comparing with vision, intent (much higher signal than any of the text), risk and various other signals.
> Then I can ingest all reports into one session and run AI queries/de-dupe/auto-close/merge as needed on it.
> Same for Issues. Prompt Requests really are just issues with additional metadata.
> Don't even need a vector db. Was thinking way too complex for a while.

---

## ツイートの本質: 並列ETLとしてのAI活用

ChatGPTの分析が鋭かった。このツイートの核心は「AIを"賢いレビュアー"として使うのではなく、**並列ETLでPRを"問い合わせ可能なデータ"に変換する**」こと。

### 示唆1: 構造化シグナル処理

PRを「チャットで読む」発想だとコンテキストが膨らみ続けて破綻する。突破は:

1. 並列エージェント = **抽出器**として働かせる
2. 出力は自然文ではなく**JSON（機械が扱える中間表現）**
3. 人間/親エージェントは「PR本文」ではなく「JSONの集合」を相手にする

### 示唆2: intent > text

PR本文やdescriptionはブレる（雑・短い・テンプレ・AI生成でノイズ増加）。しかし「何を変えようとしているか（目的/意図）」は、diff・ファイル変更・依存関係・テスト影響から推定できる。レビューの最小単位は「diff → intent → risk → 採否」になる。

### 示唆3: RAGの前にETL

ベクタDB不要。「近傍検索」より先に「全件を構造化して取り込み、集約して問い合わせる」方が効く。重複判定、クラスタリング、リスク閾値での自動処理。

### 示唆4: チケットモデルの統一

> Prompt Requests really are just issues with additional metadata.

PR / Issue / Prompt Request を別物として扱うとツール側の分岐が増えて持続性が落ちる。「チケット」として統一すれば、解析スキーマ・重複排除・優先度・リスク評価を共通化できる。

---

## 転用: オーケストレーションツールの親子スレッド構造への適用

steipeteのパターンを自前オーケストレーションツールに転用する。

**現状**: 子スレッドの成果物 = ドキュメント（自然文） / Issue
**提案**: 子スレッドの成果物 = **共通JSONスキーマのレポート** + 成果物（コード/ドキュメント）

### 構造の対応関係

| steipeteのPRレビュー | オーケストレーションツール |
|---------------------|------------------------|
| 50 Codex並列 | N子スレッド並列 |
| PR → JSONレポート（intent/risk/vision） | タスク → JSONレポート（intent/risk/gates） |
| 1セッションに集約 | 親スレッドに集約 |
| AIでクエリ/重複排除/auto-close/merge | 集約クエリ/重複検出/MERGE/CLOSE |
| ベクタDB不要、構造化データで十分 | ドキュメント検索より構造化レポートの集約 |

本質的に同じパターン: **並列で構造化抽出 → 集約 → 判断**（ETLパイプライン）。

---

## 共通レポートスキーマ案

```jsonc
{
  // === 識別 ===
  "thread_id": "impl-user-settings-page",
  "parent_thread_id": "epic-settings-redesign",
  "type": "implementation",  // kickoff | plan | implementation | review | design-check

  // === Intent（最重要シグナル）===
  "intent": {
    "summary": "ユーザー設定画面の新規実装",
    "scope": ["pages/settings/**", "api/v2/user-settings/**"],
    "domain_decisions": [
      "通知設定はワークスペース単位に変更",
      "プラン管理はStripe Billing Portalへの外部遷移に統一"
    ]
  },

  // === Status ===
  "status": "completed",  // in-progress | blocked | completed | failed
  "completion": {
    "planned_tasks": 5,
    "completed_tasks": 5,
    "blocked_tasks": 0
  },

  // === Quality Gates（Pass/Fail）===
  "gates": {
    "type_check": { "pass": true },
    "lint": { "pass": true },
    "tests": { "pass": true, "coverage_delta": "+3.2%" },
    "second_opinion": {
      "pass": true,
      "model": "claude-opus-4-5-20250929",
      "concerns": []
    },
    "design_token_compliance": { "pass": true, "violations": 0 },
    "a11y": { "pass": false, "violations": 2, "details": [
      { "rule": "color-contrast", "element": ".plan-badge", "severity": "serious" }
    ]}
  },

  // === Risk ===
  "risk": {
    "level": "medium",  // low | medium | high | critical
    "factors": [
      "既存の /api/v1/settings との後方互換性を破る変更あり"
    ],
    "breaking_changes": true,
    "new_dependencies": ["@stripe/stripe-js@4.x"]
  },

  // === Artifacts（成果物の参照）===
  "artifacts": {
    "commits": ["abc1234", "def5678"],
    "files_changed": 12,
    "episode_log": "docs/episodes/impl-user-settings-page.md",
    "decisions": [
      { "id": "ADR-042", "title": "通知設定のスコープ変更" }
    ]
  },

  // === Promotion（親スレッドへ昇格すべき情報）===
  "promotion": {
    "should_promote": true,
    "items": [
      {
        "type": "decision",
        "summary": "通知設定をワークスペース単位に変更。他の設定画面にも波及する可能性あり",
        "urgency": "high"
      },
      {
        "type": "blocker",
        "summary": "a11yのcolor-contrast違反。デザイントークンの.plan-badgeの背景色を変更する必要あり",
        "urgency": "medium"
      }
    ]
  }
}
```

---

## 親スレッドの集約クエリパターン

親スレッドが全子スレッドのJSONレポートを取り込んだ後に実行する「問い合わせ」:

1. **ステータス概観**: 全子スレッドのstatus一覧。blockedがあれば理由も
2. **リスク集約**: risk.levelがmedium以上を高い順に。breaking_changesフラグ付き
3. **ゲート失敗の集約**: gatesでFailがある子スレッドをseverity順。同一原因はグルーピング
4. **重複検出**: intent.scopeが重複している子スレッド。コンフリクト候補の検出
5. **Promotion集約**: 全子スレッドのpromotion.itemsをurgency順に。他の子スレッドに波及するdecisionをハイライト → そのままレトロスペクティブの議題に

---

## Ralph制御トークンの拡張

steipeteのRalphが使うCONTINUE / SEND / RESTARTの3トークンに、JSONレポートベースの制御トークンを追加:

| トークン | 意味 | 例 |
|---------|------|-----|
| `CONTINUE` | 子スレッド続行 | 問題なし、次のタスクへ |
| `SEND:<message>` | 子スレッドへ指示送信 | `SEND:a11y違反を修正してからgates再実行` |
| `RESTART` | 子スレッド再起動 | コンテキスト破損、やり直し |
| `PROMOTE:<item>` | 情報を親スレッドへ昇格 | `PROMOTE:ADR-042を全子スレッドに共有` |
| `GATE:human` | 人間ゲート要求 | `GATE:human デザイントークン違反の目視確認` |
| `MERGE` | 子スレッド成果を統合 | 全ゲートPass、マージ可 |
| `CLOSE` | 子スレッド終了（不採用） | 重複検出、クローズ |

---

## フロー全体像

```
親スレッド
  |
  +-- kickoff（intent定義、タスク分割）
  |
  +-- 子スレッド A --> JSONレポート A
  +-- 子スレッド B --> JSONレポート B
  +-- 子スレッド C --> JSONレポート C
  |         :
  |   （各子スレッドは直列プリミティブ: plan -> impl -> gates -> report）
  |
  +-- 集約フェーズ
  |     +-- レポート群を取り込み
  |     +-- クエリ実行（ステータス/リスク/重複/ゲート失敗）
  |     +-- 自動処理（全Pass -> MERGE、重複 -> CLOSE）
  |     +-- 人間エスカレーション（Fail -> GATE:human）
  |
  +-- レトロスペクティブ
        +-- promotion.items の集約レビュー
        +-- 波及するdecisionsの全体反映
        +-- 次のイテレーションへのフィードバック
```

---

## セキュリティ上の注意

ChatGPTがHacker Newsの議論を引いて指摘: PRレビュー系のシグナル抽出は**プロンプトインジェクション/セマンティック汚染**のリスクがある。

対策:

- 抽出エージェントは**ツール権限を極小**（読むだけ、外部送信なし）
- 出力を**厳格JSONスキーマ**でバリデーション
- PR本文の指示は基本無視し、diffとメタ情報を主入力にする

---

## AI議論の裏付け

### ChatGPTの分析（特に鋭い部分）

- 「このtweetの一番の示唆 = AIを"賢いレビュアー"として使うのではなく、並列ETLでPRを"問い合わせ可能なデータ"に変換する」
- 「RAGの前にETL」— 検索ではなく構造化+集約が先
- intent > textの指摘はデザイン領域にも転用可能（「この画面変更のintentは何か」をまず抽出）
- PR/Issue/Prompt Requestの統一チケットモデル

### Claude側の分析

- steipeteのRalph（supervisor loop）との接続: 3トークン制御を拡張してPROMOTE/GATE:human/MERGE/CLOSEを追加する設計案
- 親スレッドが「レポート群への問い合わせ」として機能する構造は、キックオフ→FB→レトロスペクティブのサイクルに対応
- 昇格フロー（意図的圧縮の三層）のJSON実装形態としてpromotionフィールドが機能

---

## 検証するなら

- 2〜3子スレッドの小規模エピックで、JSONレポートスキーマを手動で書いてみて、親スレッドの集約クエリが有用かを確認
- スキーマの必須フィールドと任意フィールドの境界を実践で決める
- 既存のドキュメント橋渡し（Markdown/Issue）とJSON橋渡しの併用が現実的かどうかを検証

---

## 優先度

中。直列プリミティブの最小実装と並行して、レポートスキーマの設計を進められる。ただしスキーマを先に固めすぎると柔軟性を失うため、最初は最小フィールド（intent/status/gates/promotion）から始めて拡張していく。

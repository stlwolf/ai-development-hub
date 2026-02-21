# ドキュメント規約

本プロジェクトのドキュメント管理規約。`second-opinion-verification/docs/DOCUMENT_CONVENTION.md` (v0) から派生。

新しいスレッドで作業を開始するエージェントは、キックオフドキュメントと合わせて本ファイルを参照すること。

## フォルダ構成

```
docs/
├── VERIFICATION_MATRIX.md    # 検証マトリクス（A: ツール / B: プロセス）
├── plans/                    # 計画・キックオフ（type: plan）
├── episodes/                 # 作業記録・議論経緯（type: episode）
├── decisions/                # 確定した判断 ADR形式（type: decision）
└── raw-logs/                 # 生ログ 層3（gitignore対象、一時保管）
```

## ファイル命名規則

| type | 配置先 | 命名パターン | 例 |
|------|--------|------------|-----|
| `plan` | `plans/` | `YYYY-MM-DD-{kickoff\|plan}-topic.md` | `2026-02-20-kickoff-phase1-db-foundation.md` |
| `episode` | `episodes/` | `YYYY-MM-DD-topic.md` | `2026-02-20-phase1-db-foundation.md` |
| `decision` | `decisions/` | `ADR-NNN-topic.md` | `ADR-001-sqlite-library.md` |
| (生ログ) | `raw-logs/` | 任意 | SpecStory出力そのまま等 |

### plan のサブタイプ

| サブタイプ | 命名内の識別子 | 用途 |
|-----------|-------------|------|
| kickoff | `kickoff` を含める | スレッドの開始プロンプト。前スレッドの議論を圧縮した初期コンテキスト |
| plan | `plan` を含める | 具体的な実装プラン、検証計画 |

`impl-plan` や `detail-plan` のような独自識別子は使わない。`plan` に統一する。

## YAML Frontmatter（必須）

全ドキュメントに以下の frontmatter を付与する。

```yaml
---
title: "ドキュメントのタイトル"
date: YYYY-MM-DD
type: episode | decision | plan
related:
  - type: derived_from | depends_on | supersedes | evidence_for | implements
    ref: 相対パス
    reason: "関連の理由"
tags: [3-8個のカテゴリタグ]
---
```

### 必須フィールド

| フィールド | 説明 |
|-----------|------|
| `title` | ドキュメントのタイトル |
| `date` | 作成日（YYYY-MM-DD） |
| `type` | ドキュメント種別（`episode` / `decision` / `plan`） |

### 推奨フィールド

| フィールド | 説明 |
|-----------|------|
| `related` | 関連ドキュメント（type + ref + reason） |
| `tags` | カテゴリベースの分類 |
| `keywords` | 固有名詞・技術用語での精密検索用 |
| `use_when` | 意図ベース検索用（「〇〇のとき」形式） |

### 関係タイプ（related.type）

| type | 意味 |
|------|------|
| `derived_from` | ここから派生した |
| `depends_on` | これに依存している |
| `supersedes` | これを置き換えた |
| `evidence_for` | これの根拠になる |
| `implements` | これを実装した |

## スレッド分化時のドキュメントフロー

```
スレッド N（議論・ブレスト）
  │
  ├── [raw-log] SpecStory出力 → raw-logs/ に一時保管
  │
  └── [plan/kickoff] 次スレッドの開始プロンプト
        → plans/YYYY-MM-DD-kickoff-{topic}.md
            │
            スレッド N+1（実装・検証）
              │
              ├── [episode] 作業記録
              ├── [decision] 確定した判断（ADR）
              └── [plan/kickoff] さらに次のスレッドへ...
```

キックオフは**前スレッドの議論を圧縮したスタートプロンプト**。スレッドが分化するたびに `plans/` に蓄積される。

## plan と episode の分離ルール

- `plan` は**実行前の状態を保持する**。実行結果を plan に追記しない
- 実行結果・発見・変更点はすべて `episode` に記録する
- plan に追記してよいのは frontmatter のタイトルに `（実行完了）` を付与する程度

## ADR 作成基準

以下のいずれかに該当する判断は `decisions/ADR-NNN-topic.md` に記録する:

- 2つ以上の選択肢を比較して1つを選んだ
- 外部依存を追加・変更・削除した
- プラン記載のアプローチを実装時に変更した
- 「やらない」と明示的に決めた

ADR は短くてよい（10行でも可）。エピソードに埋もれるより、独立ファイルとして検索可能にすることが目的。

## 運用ルール

- 上書き禁止。更新は `supersedes` で新ファイルを作り、旧版を残す
- Decision（ADR）は確定後に変更しない
- `raw-logs/` は gitignore 対象。抽出（episodes/decisions への昇格）後は破棄可（TTL: 30〜90日目安）
- frontmatter が不完全でも本文があれば価値はある。完璧を目指さない

## 関連プロジェクトの成果物

| ファイル | 配置先 | 関連 |
|---------|--------|------|
| [DOCUMENT_CONVENTION.md](../second-opinion-verification/docs/DOCUMENT_CONVENTION.md) | second-opinion-verification | 本規約の派生元 |
| [context-persistence-4layer-model.md](../../ideas/20260220/context-persistence-4layer-model.md) | ideas/ | 4層モデル（本プロジェクトは層3パイプライン） |
| [peer-ai-review.md](../../cursor/command/verification/peer-ai-review.md) | cursor/command | 設計判断のピアレビュー用コマンド |
| [BACKLOG #2](https://github.com/stlwolf/ai-development-hub/issues/2) | GitHub | 「会話ログ保存の仕組み構築」Issue |

## ガードレール（将来検討）

現状はこのファイルがエージェント・人間共通の参照先。将来的に以下を検討:

- バリデーションスクリプト（ファイル名 + frontmatter 整合性チェック）
- 正準ドキュメント → ツール固有ルールへの自動変換（CONVENTIONS.md → .cursor/rules/ 等）
- 別プロジェクトへのポータブルテンプレート化

# docs/research/

外部記事・OSS 調査の成果を蓄積するディレクトリ。

## ディレクトリ構成

| パス | 生成元 | 内容 |
|------|--------|------|
| `docs/research/YYYY-MM-DD-<slug>.md` | `research-intake` コマンド | 記事/論文の分析ノート |
| `docs/research/oss-sessions/` | `oss-research-session` スキル | OSS/ライブラリ調査レポート |

---

## research-intake 出力仕様

`canonical/commands/investigation/research-intake.md` で定義されたコマンドが生成するリサーチノートの固有フィールド・語彙の説明。

### フロントマター

```yaml
---
title: "分析テーマ"
date: YYYY-MM-DD
status: research-complete
tags: [research-intake, ...]
sources:
  - https://example.com/article
related_ideas:
  - ideas/YYYYMMDD/filename.md
next_step:
  trigger: "再訪のきっかけ"
  actions: "再訪時に何をするか"
  referenced_by: "このノートが引かれる文脈"
---
```

| フィールド | 説明 |
|-----------|------|
| `status` | 常に `research-complete`。research-intake の全 Gate を通過し、保存された状態を示す |
| `tags` | 先頭に `research-intake` を含む。以降はトピック固有のタグ |
| `sources` | 分析対象の URL リスト（入力として与えられた記事/論文） |
| `related_ideas` | `ideas/` ディレクトリ内の関連ドキュメントへのパス。ideas/ は frozen snapshot のため参照のみ |
| `next_step.trigger` | いつ・どういうきっかけでこのノートを再訪するか（日付 or 条件） |
| `next_step.actions` | 再訪時に具体的に何をするか。接続先の資産に対するアクションを記述 |
| `next_step.referenced_by` | このノートがどの作業・Epic・プロジェクトから参照されるか。他の作業からの導線 |

### アクション種別

各パターンに対して判定される処理区分。ノート本文の「アクション判定」テーブルで使用される。

| 種別 | 意味 |
|------|------|
| `discard` | 有用性が低い。記録しない |
| `archive-note` | 参考情報としてリサーチノートに記録して完了 |
| `defer` | 今は判断できない / 追加情報が必要。`next_step` に再訪条件を設定 |
| `enrich-existing` | 既存 Issue / ドキュメントにコメント・更新を追加 |
| `create-issue` | 行動可能なタスクとして Issue 化 |
| `create-component` | 新規スキル / エージェント / CLI / プロジェクトの設計検討 |
| `experiment` | 小規模な検証を先に行う |

`archive-note` と `defer` の違い: `archive-note` は保存して完了、`defer` は後で再評価する意図がある（`next_step` が必須）。

### 資産マッピング（トラックA / トラックB）

本文中の「資産マッピング」セクションで使用される2トラック構造。

| トラック | 対象 | 列 |
|---------|------|-----|
| **トラックA: 既存資産への接続** | 抽出パターンと既存の Issue / スキル / ドキュメント / ideas との対応 | パターン, 接続先, 接続の性質（補強/修正/拡張）, ギャップ/新規知見 |
| **トラックB: 新規導入候補** | 既存環境に対応物がないパターンの導入検討 | パターン, 既存対応物, 導入形態（新規スキル/エージェント/CLI等）, 実現可能性メモ |

### パターン種別

本文中の「本質的パターン」テーブルで使用される分類。

| 種別 | 対象 |
|------|------|
| 設計原則 | 責務分割、制約、トレードオフの判断基準 |
| ワークフロー | 手順の順序、フェーズ遷移、ゲートの設計 |
| 実装パターン | コードレベルで再利用可能な構造 |
| ツール | CLIツール、ライブラリ、フレームワークの利用パターン |
| 評価手法 | 測定方法、ベンチマーク、品質基準 |

---

## 検証規律（evidence-verification-rule）

`docs/research/` の成果（research-intake ノート / oss-sessions レポート）は [`canonical/rules/evidence-verification-rule.md`](../../canonical/rules/evidence-verification-rule.md) に従う。

- 各非自明な主張は **検証ステータス**（`verified` 一次確認済み / `unverified-summary` AI要約のみ / `speculation` 推測）と **根拠**（URL or `file:line`）を持つ
- `verified` は外部ソース実体への照合が要件。AI の自己申告・要約だけで `verified` としない
- 数値・性能・事実主張は特に厳密に。未確認は `unverified-summary` のまま残す
- 消費側（親エージェント / レビュア）はリスク比例で spot-check する（`oss-research-session` の親チェックリスト参照）

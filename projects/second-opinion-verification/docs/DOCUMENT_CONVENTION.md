# ドキュメント規約 (v0)

- 日付: 2026-02-12
- 性質: 仮制定。運用しながら更新する前提。
- 参考: [Claude Codeのドキュメント検索を極力さぼれるようにした話 (SIOS Tech Lab)](https://tech-lab.sios.jp/archives/51281)

---

## 1. 適用範囲

`projects/second-opinion-verification/docs/` 配下のドキュメントに適用する。
他プロジェクトへの展開は、ここでの運用結果を見てから判断。

---

## 2. ヘッダメタデータ（YAML Frontmatter）

原則として、ドキュメントは冒頭に以下の YAML Frontmatter を持つ。既存ファイルへの適用は段階的に行う（セクション5参照）。

```yaml
---
title: "ドキュメントのタイトル"
date: 2026-02-09
type: episode          # episode | decision | plan | report
participants:          # 該当する場合のみ
  - Cascade (Primary)
  - Claude Code (Second)
related:               # 関連ドキュメントへの参照
  - type: derived_from # derived_from | depends_on | supersedes | evidence_for
    ref: ../decisions/ADR-001-shell-timeout-pattern.md
    reason: "設計レビューから昇格した判断"
tags: [claude-safe, timeout, shell]
keywords: [watchdog, SIGTERM, nohup, macOS]  # 固有名詞・技術用語
use_when:              # 意図ベース検索用（「いつ参照すべきか」）
  - "シェルスクリプトでタイムアウトを実装するとき"
  - "claude-safe のプロセス管理で問題が起きたとき"
---
```

### フィールド定義

| フィールド | 必須 | 用途 |
|-----------|------|------|
| `title` | 必須 | ドキュメントのタイトル |
| `date` | 必須 | 作成日（YYYY-MM-DD） |
| `type` | 必須 | ドキュメント種別（下記参照） |
| `participants` | 任意 | AI/人間の参加者と役割 |
| `related` | 任意 | 関連ドキュメント（type + ref + reason） |
| `tags` | 推奨 | カテゴリベースの分類（3-8個） |
| `keywords` | 任意 | 固有名詞・技術用語での精密検索用 |
| `use_when` | 推奨 | 意図ベース検索用。「〇〇のとき」「〇〇に直面したとき」の形式 |

### ドキュメント種別（type）

| type | 配置先 | 性質 | 更新頻度 |
|------|--------|------|----------|
| `episode` | `episodes/` | 作業記録・議論経緯 | 高（作業中随時） |
| `decision` | `decisions/` | 確定した判断（ADR形式） | 低（確定時のみ） |
| `plan` | `plans/` | 検証計画・実施方針 | 中（計画変更時） |
| `report` | `episodes/` | 検証レポート・結果まとめ | 低（検証完了時） |

### 関係タイプ（related.type）

| type | 意味 | 例 |
|------|------|-----|
| `derived_from` | ここから派生した | Episode → Decision への昇格 |
| `depends_on` | これに依存している | 実装が設計判断に依存 |
| `supersedes` | これを置き換えた | v2 が v1 を更新 |
| `evidence_for` | これの根拠になる | 検証結果が仮説の根拠 |

---

## 3. 本文構造

**本文の構造は縛らない。** 種別ごとに自然に異なる形になってよい。

ただし、以下のパターンが既に定着しているものはそのまま踏襲する:

- **Decision (ADR)**: Context → Decision → Consequences（標準ADR形式）
- **Episode**: 背景 → 指摘/議論 → 結論/次のアクション
- **Report**: 概要 → 結果 → 発見した問題 → 教訓

---

## 4. ファイル命名

```
YYYY-MM-DD-topic-name.md
```

- 日付プレフィックスで時系列ソート可能にする
- Decision は `ADR-NNN-topic-name.md` 形式を継続

---

## 5. 運用ルール

- 上書き禁止。更新は `supersedes` で新ファイルを作り、旧版を残す
- Frontmatter はドキュメント作成時に付与。既存ファイルへの遡及適用は段階的に行う
- `use_when` は「自分が後で検索するとき、何と聞くか」を想像して書く
- 完璧を目指さない。メタデータが不完全でも本文があれば価値はある

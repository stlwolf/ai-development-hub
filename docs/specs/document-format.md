---
id: "01KNCK58PTF85AVQD4M9BFYV99"
title: "蒸留パイプライン ドキュメントフォーマット定義"
date: 2026-04-05
type: decision
status: draft                # #19 MVP での実運用検証を経て stable に昇格予定
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/15"
    reason: "Issue #15: Spec Card フォーマット定義（C-14）"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/10"
    reason: "Epic #10 Tier 2"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "§5 MVP 構成（エンベロープ・パーサー・ゲート）、§6 蒸留パイプライン"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/context-foundation.md"
    reason: "§4 コンテキスト種類の再設計、§5 Q1 保存フォーマットの暫定判断"
  - type: source_material
    ref: "ideas/20260221/document-format-design-principles.md"
    reason: "write:read 比率、フォーマット目的分類、ハイブリッド構成の原則"
  - type: source_material
    ref: "https://github.com/yoshiakist/specre"
    reason: "ULID・status enum・仕様カードの参考"
  - type: integration_target
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "#19 MVP 4-1 envelope / 4-2 output parse / 4-3 validation gate の入力契約"
tags: [spec-card, format, ulid, epic-10, tier-2]
---

# 蒸留パイプライン ドキュメントフォーマット定義

## 1. 目的

蒸留パイプライン（Discussion → KickOff → Plan → Episode → Decision）の各段階で生成されるドキュメントのフォーマットを統一する。

- [#19 MVP](https://github.com/stlwolf/ai-development-hub/issues/19) の 4-1（エンベロープ）/ 4-2（成果物パース）/ 4-3（検証ゲート）が消費する入力契約
- `frontmatter 索引 + rg` による検索戦略（context-foundation.md §5 Q2 暫定判断）の実現基盤
- ドキュメント間の参照追跡を ULID で機械的に行えるようにする

## 2. 蒸留パイプラインと文書型

[document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) の write:read 比率に基づき、フォーマット深度に差をつける。

| 段階 | type 値 | write:read | フォーマット深度 | 目的 |
|------|---------|-----------|----------------|------|
| Discussion | `discussion` | 低（書く≒読む） | 最小: frontmatter のみ | 探索的。構造化されていない |
| KickOff | `kickoff` | 中〜高 | 重い: frontmatter + セクションテンプレート | スコープ確定、方針の言語化 |
| Plan | `plan` | 中 | 重い: frontmatter + セクションテンプレート | 実行可能な粒度まで分解 |
| Episode | `episode` | 中（読む方が多い） | 中間: frontmatter + 性質ガイド | 実行記録。本文はフリーフォーム |
| Decision/ADR | `decision` | 高（読むが圧倒的に多い） | 重い: frontmatter + セクションテンプレート | 蒸留の最終成果 |

## 3. 共通フロントマター

### 必須フィールド

全文書型で必須。

```yaml
---
id: "<ULID>"           # 機械追跡用の一意識別子
title: "<タイトル>"     # 人間可読なタイトル
date: YYYY-MM-DD       # 作成日（ISO 8601）
type: <文書型>          # discussion | kickoff | plan | episode | decision
status: <ステータス>    # draft | in-development | stable | deprecated
---
```

### 任意フィールド

文書型に応じて使用。

```yaml
source: "<出典>"                        # 起点となる Epic / Issue（kickoff で使用）
scope: canonical | <project-name>       # 影響範囲（kickoff で使用）
related:                                # 型付き参照配列（§6 参照）
  - type: <関係型>
    ref: "<パスまたは URL>"
    reason: "<関係の説明>"
tags: [tag1, tag2]                      # 検索・フィルタ用タグ
```

## 4. ULID 規約

### フォーマット

[ULID (Universally Unique Lexicographically Sortable Identifier)](https://github.com/ulid/spec) — 26文字、Crockford Base32。先頭10文字がミリ秒精度のタイムスタンプ、末尾16文字がランダム。

例: `01KNCK58PTF85AVQD4M9BFYV99`

### 生成方法

```bash
python3 -c "
import time, random
t = int(time.time() * 1000)
c = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
ts = ''.join(c[(t >> (45 - 5*i)) & 31] for i in range(10))
rand = ''.join(random.choice(c) for _ in range(16))
print(ts + rand)
"
```

`ulid` パッケージが利用可能な環境では `python3 -c "import ulid; print(ulid.new())"` を推奨（公式仕様に厳密準拠）。上記の手書きスニペットはタイムスタンプエンコーディングが簡易実装のため、厳密な ULID パーサーとの互換性は保証しない。

**バリデーション方針**: MVP（#19 4-3）では「26文字・Crockford Base32 文字集合」のフォーマットチェックのみ。タイムスタンプの正確性やモノトニック性の検証は将来拡張とする。

### ファイル命名との共存

- **ULID**: frontmatter の `id` フィールドに格納。機械追跡用
- **ファイル名**: `YYYY-MM-DD-{type}-{topic}.md` を維持。人間ナビゲーション用
  - 例: `2026-04-05-decision-quality-gate-skip-prevention.md`
  - ADR は `ADR-NNN-{topic}.md` も許容（既存プロジェクト互換）

ULID はファイル名に含めない。理由: ファイル名が長くなり人間可読性が下がる。`rg "^id:" docs/` で ULID → ファイルの逆引きは十分に高速。

### 将来拡張: 双方向トレーサビリティ（スコープ外）

specre の `@specre <ULID>` パターン — ソースコード中にマーカーを配置し、ドキュメント↔コード間の参照を追跡する。本定義では規約のみ記載し、ツール実装は #19 MVP 以降で検討。

```ruby
# @doc 01KNCK58PTF85AVQD4M9BFYV99
class SomeClass
```

## 5. Status ライフサイクル

specre の status enum を採用。

```
draft → in-development → stable → deprecated
  ^          |
  └──────────┘  （要件変更時に逆行可）
```

| status | 意味 | 遷移トリガー |
|--------|------|-------------|
| `draft` | 初期状態。作成中・レビュー前 | ドキュメント作成時 |
| `in-development` | 内容に基づく作業が進行中 | 実装着手時 |
| `stable` | 確定・受理済み。後続タスクの参照として信頼できる | レビュー完了・合意時 |
| `deprecated` | 陳腐化。後継があるか不要になった | 後継ドキュメントがある場合は `related` に `type: supersedes` で逆方向リンクを張る |

遷移は強制しない。スキップ・逆行を許容する（specre と同方針）。

## 6. Related 型の語彙

`related[]` 配列の `type` フィールドに使える値。既存の kickoff/ADR ドキュメントで使用されている型を棚卸しして明文化。

| type | 意味 | 使用例 |
|------|------|--------|
| `parent_issue` | 対象 Issue | kickoff → Issue |
| `parent_epic` | 所属 Epic | kickoff → Epic |
| `source_material` | 出典・参考資料 | OSS リポ、調査ドキュメント |
| `design_context` | 設計判断の背景 | architecture-sketch, context-foundation |
| `integration_target` | 統合・参照先 | 既存スキル、コマンド |
| `future_hook` | 将来の接続点 | 未着手の Issue、構想段階の機能 |
| `derived_from` | 派生元 | ADR が別の ADR から派生 |
| `supersedes` | 置き換え対象 | 新 ADR → 旧 ADR |
| `sibling` | 同列の成果物 | 同一 Epic 内の別 Issue |
| `evidence_for` | 根拠を提供 | 失敗事例 → 設計要件 |
| `modification_target` | 変更対象ファイル | kickoff → 既存ファイル |
| `reference` | 汎用参照 | 上記に当てはまらない参照 |

新しい型が必要な場合は追加してよい。ただし既存の型で表現できるなら既存を使う。

## 7. 文書型別テンプレート

### Discussion

最小フォーマット。本文はフリーフォーム。

```yaml
---
id: "<ULID>"
title: "<探索テーマ>"
date: YYYY-MM-DD
type: discussion
status: draft
tags: [topic-tags]
---
```

### KickOff

既存パターン（`docs/plans/issue#10/*.md`）を明文化。

```yaml
---
id: "<ULID>"
title: "<作業タイトル>"
date: YYYY-MM-DD
type: kickoff
status: draft
source: "<Epic / Issue>"
scope: canonical | <project-name>
related:
  - type: parent_issue
    ref: "<URL>"
    reason: "<説明>"
  - type: parent_epic
    ref: "<URL>"
    reason: "<説明>"
tags: [tags]
---

# <タイトル>

## 背景
## スコープ
## 成果物
## 完了条件
## ステップ
## リスク・未確認事項
## セカンドオピニオン検証（任意）
```

### Plan

`kickoff-to-plan` スキルの出力形式と整合。frontmatter は KickOff と同構造。

```yaml
---
id: "<ULID>"
title: "<プランタイトル>"
date: YYYY-MM-DD
type: plan
status: draft
related:
  - type: derived_from
    ref: "<kickoff ファイルパス>"
    reason: "<説明>"
tags: [tags]
---
```

本文は `kickoff-to-plan` SKILL.md の出力フォーマット定義に従う（TODO 項目 + Gate + Context）。

### Episode

frontmatter + 性質ガイド。本文はフリーフォーム（ハイブリッド構成）。

```yaml
---
id: "<ULID>"
title: "<エピソードタイトル>"
date: YYYY-MM-DD
type: episode
status: draft
related:
  - type: derived_from
    ref: "<plan ファイルパス>"
    reason: "<説明>"
tags: [tags]
---
```

性質ガイド（本文の書き方指針）:

> 冒頭に「なぜこの作業が始まったか」を 1〜2 文で自己完結して書く（Context / なぜ。リンク先参照のみにしない）。各 Step の記録は、後から読んだ人がやりとりの流れを追跡できるように書く。特に問題発生→原因特定→対処の連鎖は省略しない。羅列で終わらせず、転用可能な知見・教訓があれば節を立てて残す。

構造化 FB セクション（Episode 末尾、任意）:

```markdown
## フィードバック
- 想定外だった点:
- 規約遵守状況:
- ADR 昇格候補:
- 次の消費者（誰が / どのタスクで読むか）:
- follow-up の行き先（Issue / ADR / 別doc / 追わない宣言）:
```

うち「次の消費者」「follow-up の行き先」は closure 時の必須項目（他は該当時のみ。空欄の機械的穴埋めはしない）。closure（status 確定・振り返り）の手順は `episode-retrospective` skill を参照。

### Decision / ADR

蒸留の最終成果。最も重いフォーマット。

```yaml
---
id: "<ULID>"
title: "<判断の1行要約>"
date: YYYY-MM-DD
type: decision
status: stable
related:
  - type: evidence_for
    ref: "<根拠となるドキュメントやログ>"
    reason: "<説明>"
tags: [tags]
---

# <タイトル>

## コンテキスト
何が起きていたか / 何を検討していたか

## 決定
何を決めたか（1-3行）

## 根拠
なぜそう決めたか（比較した選択肢含む）

## 結果
この決定により何が変わるか / 注意点
```

## 8. ファイル命名規約

```
YYYY-MM-DD-{type}-{topic}.md
```

- `{type}`: `discussion`, `kickoff`, `plan`, `episode`, `decision` のいずれか
- `{topic}`: ハイフン区切りの英語スラッグ（例: `quality-gate-skip-prevention`）
- ADR 形式 `ADR-NNN-{topic}.md` はプロジェクト固有の decisions/ で引き続き使用可

配置先:

| 種別 | パス |
|------|------|
| プロジェクト横断の Decision | `docs/decisions/` |
| プロジェクト固有の Decision | `projects/{name}/docs/decisions/` |
| KickOff / Plan | `docs/plans/{issue-or-epic}/` |
| プロジェクト横断の Episode | `docs/episodes/` |
| プロジェクト固有の Episode | プロジェクト固有ディレクトリ（規約は各プロジェクト） |
| Discussion | `docs/draft/` または `ideas/` |

## 9. #19 MVP との接続

### 4-2 パーサーが期待するもの

- YAML frontmatter ブロック（`---` で囲まれた先頭領域）
- 必須フィールド 5つ（`id`, `title`, `date`, `type`, `status`）が存在すること
- `type` の値が定義済み enum に含まれること

### 4-3 検証ゲートが検証するもの

- 必須フィールドの存在と型
- `status` の値が定義済み enum に含まれること
- `id` が ULID 形式（26文字・Crockford Base32 文字集合）を満たすこと（MVP では §4「バリデーション方針」のとおり構文チェックのみ。厳密なタイムスタンプ検証は将来拡張）
- `related[].ref` が解決可能であること（ファイルパスの場合は存在確認、URL の場合はスキップ可）

## 10. 将来拡張（スコープ外）

- **`@doc <ULID>` 双方向トレーサビリティ**: specre の `@specre` パターンを流用し、ソースコード↔ドキュメント間の参照を追跡
- **ハーネス自動強制**: フック（#24）でドキュメント生成時にフォーマット準拠を検証 → reject
- **`outputs:` フィールド**: NLAH State Semantics 対応。ドキュメントが生成する成果物の宣言
- **index.json 自動生成**: specre の `specre index` 相当。frontmatter を集約した索引ファイル
- **既存ドキュメントの段階的移行**: 既存の kickoff/ADR に `id`(ULID) / `status` を遡及追加（必要性が出たら）

## ソース

- [specre](https://github.com/yoshiakist/specre) — ULID・status enum・仕様カードの参考（MIT License）
- [document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) — write:read 比率、フォーマット目的分類
- [context-foundation.md](../../projects/orchestration-research/synthesis/context-foundation.md) — コンテキスト種類と保存フォーマット
- [architecture-sketch.md](../../projects/orchestration-research/synthesis/architecture-sketch.md) — MVP 構成と蒸留パイプライン

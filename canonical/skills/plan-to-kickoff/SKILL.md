---
name: plan-to-kickoff
description: Cursor Plan / プランMDをKickoff Document形式に変換する。セカンドオピニオン投入・リポジトリアーカイブ・ピアレビュー共有時に使用する。命名規約・frontmatter・セクション構造をKickoff形式に整える。
---

# Plan to Kickoff — 逆変換スキル

## いつ使うか

- Cursor Plan (`~/.cursor/plans/*.plan.md`) をセカンドオピニオン（so-compare等）に渡す前に、共有可能なKickoff形式に変換するとき
- Plan Mode / Agent Mode で作成されたプランを `docs/plans/` にアーカイブするとき
- プランをピアレビュー（peer-ai-review等）に出す前に、自己完結型の文書にしたいとき

**注意: このスキルは「変換」専用。変換中にStepの実行やコードの調査は行わない。まず変換を完了させ、利用は変換後に行う。**

## 入力ソース

| ソース | パスパターン | 特徴 |
|--------|-------------|------|
| **Cursor Plan** | `~/.cursor/plans/<slug>_<hex>.plan.md` | YAML frontmatter に `name`, `overview`, `todos[]`, `isProject` あり。Cursor Plan Mode が生成 |
| **リポジトリのプランMD** | `docs/plans/**/*-plan-*.md` | YAML frontmatter に `related[]`, `tags` あり。`kickoff-to-plan` 等が生成 |

## 出力形式

`YYYY-MM-DD-kickoff-<topic>.md` — Kickoff Document 形式のMarkdownファイル。

配置先は用途により選択:

| 用途 | 配置先 |
|------|--------|
| リポジトリにアーカイブ | `docs/plans/<project>/` |
| セカンドオピニオン / レビュー用一時ファイル | `tmp/` または任意 |

## 変換の原則

### 基本方針

1. **内容保持優先**: プラン本文の表現をそのまま維持する。意訳・言い換えしない
2. **構造補完**: プランに不足するKickoffセクション（背景、成果物等）は、Context注記やfrontmatterから復元する。復元不可能な情報は空セクションに `（プランから復元不可 — 必要に応じて加筆）` と明記
3. **最小変換**: ファイル名・frontmatter・セクション見出しの変換が主。本文の書き換えは最小限

### ファイル命名規則

| ソース形式 | 変換ルール | 例 |
|-----------|-----------|-----|
| `<slug>_<hex>.plan.md` | `YYYY-MM-DD-kickoff-<slug>.md`（`_` → `-`、hex除去） | `adversarial-review_skill_plan_981ae49b.plan.md` → `2026-03-30-kickoff-adversarial-review-skill-plan.md` |
| `YYYY-MM-DD-plan-<topic>.md` | `YYYY-MM-DD-kickoff-<topic>.md`（`plan` → `kickoff`） | `2026-02-23-plan-phase5-export-enhancements.md` → `2026-02-23-kickoff-phase5-export-enhancements.md` |

日付の決定順序:
1. ソースファイル名に日付があればそれを使う
2. なければ今日の日付（`YYYY-MM-DD`）

### frontmatter 変換

**Cursor Plan → Kickoff:**

```yaml
# --- 入力（Cursor Plan） ---
name: "adversarial-review skill plan"
overview: "Kickoff Document「...」を忠実に変換した実行プラン。..."
todos:
  - id: step-0-license
    content: "Step 0: ライセンス確認"
    status: completed
isProject: false

# --- 出力（Kickoff Document） ---
title: "Adversarial Spec Review スキル整備（A-2）"  # H1 または Context の Kickoff: リンクから復元
date: 2026-03-30
type: kickoff
source: "Cursor Plan Mode から変換"
scope: canonical  # Context 内の記述から推測。不可なら省略
related:
  - type: derived_from
    ref: "~/.cursor/plans/adversarial-review_skill_plan_981ae49b.plan.md"
    reason: "変換元プラン"
tags: []  # 推測禁止。明示的なタグ情報がある場合のみ
```

| 入力フィールド | 出力フィールド | 変換ルール |
|--------------|--------------|-----------|
| `name` | `title` | 以下の優先順で決定: (1) 本文 H1 の正式タイトル、(2) Context 内の `Kickoff:` リンクから元キックオフの title を復元、(3) `overview` 冒頭の正式名称、(4) `name` を Title Case に変換（最終手段） |
| `overview` | _(削除)_ | `## 背景` の素材として本文に移動 |
| `todos[]` | _(削除)_ | 本文のStep構造に情報は含まれている |
| `isProject` | _(削除)_ | Kickoff には不要 |
| _(新規)_ | `date` | ファイル命名規則に従って決定 |
| _(新規)_ | `type: kickoff` | 固定値 |
| _(新規)_ | `source` | `"Cursor Plan Mode から変換"` |
| _(新規)_ | `scope` | Context 内の記述から推測（例: `canonical` スキル関連なら `canonical`）。推測不可な場合は省略（フィールド自体を出力しない） |
| _(新規)_ | `related[]` | Context セクションのURL・パスを構造化。不明な場合は `derived_from` のみ |
| _(新規)_ | `tags` | 推測禁止。ソースに明示的なタグ情報がある場合のみ使用。不明な場合は空配列 `[]` |

**リポジトリのプランMD → Kickoff:**

`related[]`, `tags`, `scope`, `source` が既にある場合はそのまま保持。`type` を `plan` → `kickoff` に変更。既存フィールドは原則そのまま維持し、上書きしない。

### セクションマッピング

| プランのセクション | Kickoff のセクション | 変換ルール |
|-------------------|---------------------|-----------|
| `## Context` | `## 背景` + frontmatter `related` | URLは `related[]` に構造化。散文は `## 背景` に展開。`overview` もここに統合 |
| `## Pre-Implementation` / READ系項目 | `## 事前準備` | Step 0 の前に配置。READ TODO 等を箇条書きに戻す |
| `## Step 0〜N` | `## 実装計画` > `### Step 0〜N` | 各Stepを `## 実装計画` の子セクション（`###`）に配置 |
| `## GATE: ...` / `!! GATE: ...` | `## 実装計画` 内 | Step直後にそのまま配置。`!! GATE:` 記法はキックオフ慣例に合わせてそのまま保持。`### GATE:` 見出しの場合も可 |
| `## STOP: ...` | `## 実装計画` 内（Stage 境界） | Stage 間の停止指示として保持。`← ここで停止` の表現に戻す |
| `## HG-N: ...` | `## 実装計画` 内 | Human Gate として保持。ユーザー作業内容を含める |
| `## REVIEW: ...` | `## 実装計画` 内 | peer-ai-review 実施ポイントとして保持 |
| `## ADR: ...` | `## 実装計画` 内 | ADR 作成チェックリスト項目として保持。対応Stepの直後に配置 |
| `## 最終検証` | `## 完了条件` | 見出し変更。箇条書きを `- [ ]` チェックボックス形式に変換（キックオフ慣例） |
| `## スコープ外` | `## スコープ外` | そのまま |
| _(存在しない)_ | `## 成果物` | Context や Step 内容から推測して生成。推測不可なら「（プランから復元不可 — 必要に応じて加筆）」 |
| _(存在しない)_ | `## リスクと対処` | Step 内の「リスク:」記述を集約して独立セクション化。なければ省略可 |
| **上記に該当しないセクション** | **そのまま保持** | `## 参照`, `## ライセンス` 等、マッピング表にないセクションは見出し・内容をそのまま保持する |

### `todos[]` の扱い

Cursor Plan の `todos[]` はStep/Gateの進捗追跡用であり、本文のStep記述と重複する。**変換時は `todos[]` を frontmatter から削除し、本文のStep記述を正とする。**

ただし、`todos[]` の ID 粒度は本文の Step 粒度より細かいことが多い（例: 本文は `## Step 1` だが、todos には `step-1-1`, `step-1-2` がある）。**変換前に `todos[]` の全項目が本文に対応するか照合し、本文に対応がない項目は `## 実装計画` の末尾に「### 補足（TODOリストのみに記載）」として追加する。**

### `related[]` の生成

`## Context` セクション内のURL・ファイルパスの参照を `related[]` に構造化する。

```yaml
# Context に以下の記述がある場合:
#   - 対象Issue: [Issue #11](https://github.com/.../issues/11)（Epic #10）
#   - 出典: [superpowers](https://github.com/obra/superpowers)（MIT License）
#   - 設計コンテキスト: `architecture-sketch.md` §3

related:
  - type: parent_issue
    ref: "https://github.com/.../issues/11"
    reason: "対象Issue"
  - type: source_material
    ref: "https://github.com/obra/superpowers"
    reason: "出典（MIT License）"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "設計コンテキスト §3"
```

`type` の推測ガイド:

| Context の記述パターン | `type` |
|-----------------------|--------|
| Issue / Epic リンク | `parent_issue` / `parent_epic` |
| 出典 / 参考 | `source_material` |
| 設計 / アーキテクチャ | `design_context` |
| 統合先 / 連携 | `integration_target` |
| 将来 / フック | `future_hook` |
| 上記に該当しない | `reference` |

## 変換手順

### Step 1: ソースファイルの読み込みと判別

プランファイルを全文読み込み、ソース種別を判別する:

- frontmatter に `todos[]` がある → **Cursor Plan**
- frontmatter に `related[]` がある → **リポジトリのプランMD**
- frontmatter はあるが上記いずれにも該当しない → **非標準プラン**（本文構造から推測して変換）
- frontmatter がない → **非標準プラン**（本文のみから変換。H1 を `title`、Step の有無で構造を判別）

### Step 2: frontmatter 変換

「frontmatter 変換」ルールに従って新しいfrontmatterを生成する。

### Step 3: セクション変換

1. `## Context` を分割:
   - URL・ファイルパスの参照 → frontmatter `related[]` に構造化（「`related[]` の生成」参照）
   - `overview` + 散文の説明 → `## 背景` セクションに展開
2. Pre-Implementation / READ 系項目を `## 事前準備` として Step 0 の前に配置
3. Step / Gate / STOP / HG / REVIEW / ADR を `## 実装計画` 配下に移動（見出しレベルを `###` に調整）。STOP は Stage 境界として配置
4. `## 最終検証` → `## 完了条件` に見出し変更。箇条書きは `- [ ]` チェックボックス形式に変換
5. `## スコープ外` はそのまま
6. 不足セクション（`## 成果物`, `## リスクと対処`）を補完可能なら補完
7. マッピング表にないセクション（`## 参照`, `## ライセンス` 等）はそのまま保持

### Step 4: ファイル命名と出力

「ファイル命名規則」に従ってファイル名を決定し、ユーザー指定の配置先に出力する。

### Step 5: チェック

```
## 必須チェック
- [ ] frontmatter に title, date, type: kickoff が含まれている
- [ ] プランの全Stepが「## 実装計画」配下に含まれている
- [ ] プランの全GATEが含まれている
- [ ] プランの全STOP（Stage境界）が含まれている
- [ ] プランの「最終検証」項目が「完了条件」に含まれている
- [ ] ファイル名が YYYY-MM-DD-kickoff-<topic>.md 形式になっている

## 件数突合（推奨）
- [ ] Step数: プラン N件 → キックオフ N件
- [ ] GATE数: プラン N件 → キックオフ N件
- [ ] STOP数: プラン N件 → キックオフ N件
- [ ] HG数: プラン N件 → キックオフ N件
- [ ] REVIEW数: プラン N件 → キックオフ N件
- [ ] ADR数: プラン N件 → キックオフ N件
- [ ] 最終検証/完了条件 項目数: プラン N件 → キックオフ N件
- [ ] Context内のURLが related[] に構造化されている（Cursor Planの場合）
- [ ] todos[] にのみ存在する項目が「補足」セクションに含まれている（該当がある場合）
```

## アンチパターン

| NG パターン | なぜNG | 正しい対応 |
|---|---|---|
| Step本文を要約・圧縮する | 内容が失われ、セカンドオピニオンの精度が下がる | そのまま保持 |
| `todos[]` の `status` をKickoff本文に反映する | Kickoffは「これからやること」の定義。完了状態の持ち込みは混乱の元 | `todos[]` は削除 |
| Context の散文をそのまま frontmatter に詰め込む | frontmatter は構造化参照のみ。散文は `## 背景` | URL/パスのみ `related[]` に |
| 存在しないセクションを無理に創作する | 推測で情報を追加すると誤解を招く | 「（プランから復元不可 — 必要に応じて加筆）」 |
| ファイル名の hex suffix を残す | Cursor内部IDであり、共有・アーカイブには不適 | 除去してslugのみ使用 |
| 変換中にStepの実行やコード調査を始める | 変換が中断される | 変換を完了させてから利用 |
| STOP/HG/REVIEW/ADR を無視して Step と GATE だけ変換する | Stage 境界・Human Gate・レビューポイントが失われ、ラウンドトリップで構造が崩れる | セクションマッピング表に従い全gate系要素を保持 |
| `tags` をプラン内容から推測して生成する | 誤タグ混入リスク。最小変換方針と矛盾 | 推測禁止。明示的なタグ情報がある場合のみ使用 |
| リポジトリプランMD の既存 frontmatter フィールドを上書きする | 元の `source`, `scope`, `related[]` が失われる | 既存フィールドはそのまま保持 |

## `kickoff-to-plan` との関係

| 方向 | スキル | 目的 | 厳密さ |
|------|--------|------|--------|
| Kickoff → Plan | `kickoff-to-plan` | 実行可能なTODOリストに変換 | 高（省略禁止・要約禁止・完全性チェック必須） |
| Plan → Kickoff | **本スキル** | 共有可能な文書に変換 | 中（内容保持・構造補完・簡易チェック） |

厳密さのレベルが異なるのは用途の違いによる:

- **Kickoff → Plan**: 1項目でも落とすと実行時に漏れる（実行目的）
- **Plan → Kickoff**: 元の情報を失わなければ十分（アーカイブ・共有目的）

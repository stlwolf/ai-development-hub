---
title: "アーカイブ済みスレッドの一覧ソート優先度を下げる"
date: 2026-03-29
type: discussion
related:
  - type: depends_on
    ref: ../../REQUIREMENTS.md
    reason: "FR-1 一覧、FR-8 最終活動時刻ソートと同一の並びロジックに乗せる想定"
  - type: derived_from
    ref: ../../plans/2026-02-26-kickoff-sort-by-last-activity.md
    reason: "最終活動ソート実装時にまとめて設計すると一貫しやすい"
tags: [sort, ux, list, archive, composerData, vscode-extension, cli]
keywords: [archived, archive, lastUpdatedAt, createdAt, ソート]
use_when:
  - "アーカイブ済みスレッドを一覧で下に寄せたいとき"
  - "FR-8 と合わせたソートキー設計を検討するとき"
---

# アーカイブ済みスレッドの一覧ソート優先度を下げる

## 背景

Cursor Composer ではスレッドをアーカイブできる。一覧（拡張機能の list / export QuickPick / CLI list）では、アーカイブ済みも活動時刻や作成時刻で並ぶと、**意図的にしまったスレッドが上位に残り**、アクティブなスレッドの発見性が下がることがある。

## 提案

**デフォルトの並び**で、アーカイブ済みスレッドを **非アーカイブより常に下** に寄せる。

### ソートキーの案（FR-8 との併用）

FR-8 確定後の並びを前提にする場合の一例:

- 第1キー: **アーカイブでない**（`false` を先、`true` を後）
- 第2キー: `lastUpdatedAt` 降順（なければ `createdAt` 降順）

別案: 「アーカイブは一覧末尾にまとめる」だけを満たすなら、第1キーを bool の昇順（`false` < `true`）にすればよい。

### ユーザー制御（任意・後追い可）

- `--include-archived` の逆で **`--active-only`** のようにアーカイブを隠す、は別要件になりうる。本 discussion のスコープは **優先度下げ** に限定する。

## 調査ポイント

- **`composerData` JSON にアーカイブ状態を表すフィールドがあるか**（例: `isArchived`, `archivedAt` 等）。現状の extension では未参照のため、**state.vscdb 上の実データで要確認**。
- フィールドが無い・不安定な場合: 別テーブルやキーにフラグがあるか、または **実装不可・スコープ外** と切る必要がある。

## 優先度の所感

| 条件 | 見立て |
|------|--------|
| フィールドが安定して取れる | 実装コストは低〜中（ソート比較にキー1段追加 + 型・CLI 表示の検討） |
| フィールドが取れない | 本件は保留。仕様調査タスクに落とす |

FR-8 のキックオフ実装に着手するタイミングで、**同じ PR / 同一プラン内**に取り込むか、別 Step に分割するかを決めるとよい。

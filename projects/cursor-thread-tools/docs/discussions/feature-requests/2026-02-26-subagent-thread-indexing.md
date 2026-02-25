---
title: "サブエージェントスレッドの索引付きエクスポートとフィルタリング"
date: 2026-02-26
type: discussion
related:
  - type: derived_from
    ref: ../../episodes/2026-02-21-phase4-packaging.md
    reason: "Phase 4 でサブエージェントスレッド（task-toolu_* 形式）の存在を発見"
  - type: derived_from
    ref: ../../episodes/2026-02-21-retrospective-project-complete.md
    reason: "レトロスペクティブで「サブエージェントスレッドのフィルタ」を中優先度で記録"
  - type: depends_on
    ref: ../../REQUIREMENTS.md
    reason: "FR-2 エクスポート機能の拡張"
tags: [subagent, export, indexing, filter, parent-child, tool-call, protobuf]
keywords: [task-toolu_, composerId, tool_call, so-compare.sh, サブエージェント]
use_when:
  - "サブエージェントスレッドの扱いを検討するとき"
  - "エクスポートの親子関係を設計するとき"
  - "tool_call protobuf のパース拡張を検討するとき"
---

# サブエージェントスレッドの索引付きエクスポートとフィルタリング

## 背景

サブエージェント（Task tool）の活用が増えている。調査・探索タスクを委譲するパターンが定着し、1つの親スレッドから複数のサブエージェントが起動されるのが日常的になった。

現状の課題:

- 親スレッドのエクスポートにはサブエージェントの調査結果が含まれない（tool_call ステップはテキスト未抽出）
- サブエージェントのスレッドは個別にエクスポート可能だが、親スレッドとの紐付けがない
- キックオフ等にまとめる際、サブエージェントの調査結果は圧縮され情報ロスが発生する
- 一方で、サブエージェントのスレッドも thread list に混在しており、一覧が煩雑になる

## 既存の発見事項

Phase 4 エピソードで確認済み:

- サブエージェントの `composerId` は `task-toolu_*` 形式
- Cursor は親スレッドと同じ `composerData` テーブルにサブエージェントのデータを格納している
- `toolu_*` 部分は Anthropic の tool use ID で、親スレッドの tool_call にも同じ ID が含まれる可能性が高い

## 提案

3つの独立した機能として整理する。それぞれ単独でも価値がある。

### 提案1: サブエージェントスレッドのフィルタリング（既存案）

一覧表示時にサブエージェントを除外/抽出する `--filter` オプション。

```bash
cursor-thread-tools list --filter main        # 親スレッドのみ
cursor-thread-tools list --filter subagent    # サブエージェントのみ
```

composerId のパターン（`task-toolu_*`）で判別可能。実装は軽量。

### 提案2: 索引付きエクスポート（新規）

親スレッドのエクスポート時に、関連するサブエージェントスレッドへの索引セクションを生成する。

期待する出力イメージ:

```markdown
## Subagent Threads

| # | Name | Messages | Exported |
|---|------|----------|----------|
| 1 | Cursor state vscdb database queries | 4 msgs | [Cursor_state_vscdb_database_queries_2026-02-25.md](./Cursor_state_vscdb_database_queries_2026-02-25.md) |
| 2 | Cursor state lastUpdatedAt check | 2 msgs | [Cursor_state_lastUpdatedAt_check_2026-02-25.md](./Cursor_state_lastUpdatedAt_check_2026-02-25.md) |
```

### 提案3: サブエージェントスレッドの同時エクスポート（新規）

`--include-subagents` オプションで、親スレッドのエクスポート時にサブエージェントも自動エクスポートし、索引に含める。

```bash
cursor-thread-tools export <id> --include-subagents
```

## 技術的な調査ポイント

索引付きエクスポート（提案2/3）の実現可否は、**1点の調査**でほぼ決まる:

**tool_call protobuf の内部構造にサブエージェントの composerId 参照があるか**

現状の decoder は tool_call を検出するが中身をパースしていない:

```typescript
// proto/decoder.ts
const toolCallField = getField(fields, 2);
if (toolCallField) {
  return { type: 'tool_call', text: '' };
}
```

`toolCallField.data` の protobuf を解析すれば、`task-toolu_*` composerId やリクエスト ID が含まれているか確認できる。

**フォールバック案**: protobuf 内に参照がなくても、`createdAt` のタイムスタンプ範囲 + `task-toolu_*` パターンマッチで近似的な親子関係は推定可能。ただし精度は落ちる。

## ユースケース

- キックオフ作成時: 親スレッドのエクスポートからサブエージェントの調査ログを辿り、圧縮で落ちた情報を回収
- 生ログの資産化: 調査時点のスナップショット（DB構造、クエリ結果等）を親子セットで永続化
- スレッド一覧の整理: サブエージェントをフィルタして親スレッドだけ表示

## 優先度の所感

| 提案 | 実装コスト | 価値 |
|------|-----------|------|
| 提案1: フィルタリング | 低（composerId パターンマッチのみ） | 中（一覧の視認性改善） |
| 提案2: 索引付きエクスポート | 中（tool_call パース調査 + markdown 生成） | 高（親子の追跡可能性） |
| 提案3: 同時エクスポート | 低（提案2 ができれば追加コスト小） | 高（ワンコマンドで完結） |

提案1 は独立して先に実装可能。提案2/3 は tool_call protobuf の調査結果に依存する。

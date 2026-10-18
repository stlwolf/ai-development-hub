---
title: "スレッド一覧の最終活動時刻ソート"
date: 2026-02-26
type: plan
related:
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約（命名規則・ADR昇格基準・gate運用・plan/episode分離・フェーズ実行フロー）"
  - type: depends_on
    ref: ../REQUIREMENTS.md
    reason: "FR-1 スレッド一覧表示の拡張"
  - type: derived_from
    ref: ../episodes/2026-02-21-retrospective-project-complete.md
    reason: "Phase 1〜4 完了後の UX 改善"
tags: [sort, ux, list, cli, vscode-extension, composerData]
keywords: [lastUpdatedAt, createdAt, sort order, thread list]
use_when:
  - "スレッド一覧のソート順改善に着手するとき（このファイルが最初のプロンプト）"
  - "lastUpdatedAt の仕様・制約を確認したいとき"
---

# スレッド一覧の最終活動時刻ソート

**作業開始前に必ず以下を読むこと:**
- **`CONVENTIONS.md`**（プロジェクトルート）: ファイル命名規則、ADR 昇格基準、ADR フロー組み込み、plan/episode 分離ルール、gate 運用、事実検証粒度、プラン構成ガイドライン、**フェーズ実行フロー**
- **`docs/REQUIREMENTS.md`**: FR-1（スレッド一覧表示）

## 実行フロー

CONVENTIONS.md の「フェーズ実行フロー」に従う（3段階構成）:

### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + 既存コード（`extension/src/core/threads.ts`, `extension/src/commands/list.ts`, `extension/src/commands/export.ts`, `extension/src/cli.ts`）
2. **プラン作成**: Agent mode で `docs/plans/2026-02-26-plan-sort-by-last-activity.md` に直接作成（Step 0 必須、概算時間、ADR TODO 独立配置、gate TODO 独立配置）
3. **peer-ai-review**: `/peer-ai-review` でプランの3者合意を取得
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告

**← Stage 1 完了後、ここで停止してユーザーに報告する。** ユーザーが Plan mode に切り替えてから Stage 2 に進む。

### Stage 2: 実装（Plan mode）

5. **プラン変換**: 確定済みプラン MD を Plan mode のプランに変換
6. **ビルド実行**: Plan mode の TODO に従って実装。gate は TODO 項目として実行

### Stage 3: 成果物記録（Agent mode）

7. **成果物記録**: エピソード + ADR（該当する場合）+ VERIFICATION_MATRIX 更新
8. **キックオフ突合**: 本キックオフの成功基準・完了条件と結果を突合

## 1. 目的

スレッド一覧（list / export の QuickPick / CLI list）のソート順を改善し、**直近でメッセージをやり取りしたスレッドが上に来る**ようにする。

現状は `createdAt`（スレッド作成時刻）降順のため、古いスレッドでも活発にやり取りしていれば下の方に埋もれる。インクリメンタル検索はあるが、自動生成タイトルが英語で似通っているケースでは探しにくい。

## 2. 調査結果（事前調査済み）

### composerData の lastUpdatedAt フィールド

Cursor の `state.vscdb` → `composerData:*` JSON に `lastUpdatedAt` フィールドが存在することを確認済み。

| 項目 | 値 |
|------|------|
| フィールド名 | `lastUpdatedAt` |
| 型 | `number`（epoch ms、`createdAt` と同形式） |
| カバレッジ | 382 スレッド中 132 件（35%）に存在 |
| 未設定の理由 | Cursor が途中のバージョンからこのフィールドを記録し始めたため、古いスレッドには無い |

### bubbleId エントリのタイムスタンプ

`bubbleId:<composerId>:<bubbleId>` エントリにも `createdAt`（ISO 8601 文字列）が存在する。ただし27,111件のエントリを全走査する必要があり、パフォーマンスコストが高い。

### ソート方針

- **第1ソートキー**: `lastUpdatedAt`（存在する場合）
- **第2ソートキー（フォールバック）**: `createdAt`（従来通り）
- `lastUpdatedAt` がないスレッド（65%）は `createdAt` フォールバックで下方に自然配置される。古いスレッドなので実用上問題なし

## 3. 変更対象

| ファイル | 変更内容 |
|---------|---------|
| `extension/src/core/threads.ts` | `ComposerMeta` に `lastUpdatedAt?: number` 追加、`parseComposerData` でパース、`listAllThreads` のソートキー変更 |
| `extension/src/commands/list.ts` | detail 表示で `lastUpdatedAt` を参照（`createdAt` の代わりに「最終活動日時」を表示） |
| `extension/src/commands/export.ts` | detail 表示で `lastUpdatedAt` を参照 |
| `extension/src/cli.ts` | テキスト出力 / JSON 出力に `lastUpdatedAt` 追加。`--since` フィルタの基準も `lastUpdatedAt` 優先に |

## 4. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| `lastUpdatedAt` が新しい Cursor バージョンでフィールド名変更 | ソートが `createdAt` フォールバックに戻る | NFR-5「薄く作って壊れたら直す」方針。フォールバックがあるため機能停止しない |
| `lastUpdatedAt` の更新タイミングが不明確 | 実際の最終メッセージ時刻とずれる可能性 | Step 0 で実データを検証。ずれが大きい場合は bubbleId フォールバックを検討 |
| `--since` フィルタの基準変更 | 既存の CLI ワークフローで結果が変わる | 「since はアクティビティベース」の方が自然。破壊的変更だが改善方向 |

## 5. 成功基準

- [ ] list / export の QuickPick で、直近メッセージのあるスレッドが上位に表示される
- [ ] `lastUpdatedAt` がないスレッドは `createdAt` フォールバックで下方に配置される
- [ ] CLI の `list` / `list --json` で `lastUpdatedAt` が出力に含まれる
- [ ] 既存のエクスポートフロー（手動エクスポート・自動保存・CLI export）に回帰がない

## 6. ADR 作成チェックリスト

- [ ] `--since` フィルタの基準を `lastUpdatedAt` に変更する場合（既存動作の変更）
- [ ] bubbleId フォールバック（全走査）を採用する場合（パフォーマンスとのトレードオフ）

## 7. peer-ai-review 実施ポイント

**以下は実装プラン作成時に TODO 項目として独立登録すること。**

1. **前提調査の完了後**: `lastUpdatedAt` の実データ検証結果が出揃い、ソート方針（第1/第2ソートキー）が確定した時点。前提が崩れた場合はプラン自体を修正する
2. **実装後コードレビュー（必須）**: 全実装が完了しビルドが通る状態で、`so-compare.sh` によるコードレビューを実施。既存パターンとの整合性、フォールバック処理の妥当性を検証する（CONVENTIONS.md「標準 gate: 実装後コードレビュー」に準拠）

## 8. 完了条件

- [ ] ソート順が `lastUpdatedAt` 優先になった拡張 + CLI コード
- [ ] VERIFICATION_MATRIX 更新（該当する場合）
- [ ] エピソード作成
- [ ] 該当する ADR（必要な場合のみ）

## 9. スコープ外

| 機能 | 理由 |
|------|------|
| bubbleId 全走査による正確な最終メッセージ時刻 | パフォーマンスコストが高い。`lastUpdatedAt` で十分 |
| ソート順の設定オプション（ユーザー切替） | 現段階では不要。将来の feature request として記録 |
| スレッド名の日本語化・カスタム命名 | 本件とは独立した改善 |

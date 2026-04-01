---
name: issue-conventions
description: Issue作成の規約を適用する。Issue作成、gh issue create 時に使用する。テンプレート選択、Epic時のラベル、CLI制約のルールを含む。
---

# Issue 作成規約

## 基本ルール

- `--assignee @me` で自分をアサインする (MUST)
- 新しいタスクに着手する前に、まず Issue を作成する

## Epic Issue

会話で「Epic として作成」「親 Issue」「大項目の Issue」など、Epic 扱いで作成する指示がある場合:

- リポジトリに `Epic` ラベルが存在するなら、`gh issue create` に `--label Epic` を付ける (MUST)
- 事前に `gh label list`（または `gh api repos/:owner/:repo/labels`）で `Epic` の有無を確認する。存在しない場合はラベル付与をスキップし、ユーザーにラベル未整備である旨を伝える（誤って `gh` が失敗しないようにする）
- プロジェクトで Epic の表記が別名（例: `epic`, `type:epic`）に統一されている場合は、そのリポジトリの慣習を優先する

## テンプレート選択

`.github/ISSUE_TEMPLATE/` が存在する場合、適切なテンプレートを選択する:

| テンプレート | 用途 |
|---|---|
| `bug_report.md` | 動作不具合、実装ミス |
| `feature_request.md` | 新機能追加・改修 |
| `other_task.md` | 上記以外（技術的対応、基盤作業等） |

### テンプレート参照フロー

1. `ls .github/ISSUE_TEMPLATE/` でテンプレート一覧確認
2. 適切なテンプレートを `cat` で確認
3. テンプレートの全セクションを埋める（（必須）項目は必ず）
4. `gh issue create --body-file` で作成

テンプレートが存在しない場合は、目的・作業内容を本文に記述する。

## CLI 制約

- `--body` に複数行のマークダウンを直接渡さない
- 一時ファイル（`/tmp/issue_body.md`）に書き出して `--body-file` を使用
- 一時ファイルは `write` ツールで作成する

## コマンド例

```bash
gh issue create --assignee @me --body-file /tmp/issue_body.md --title "タスクタイトル"
# Epic 指示があり、ラベル Epic が存在する場合
gh issue create --assignee @me --body-file /tmp/issue_body.md --title "タスクタイトル" --label Epic
```

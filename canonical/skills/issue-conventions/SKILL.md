---
name: issue-conventions
description: Issue作成の規約を適用する。Issue作成、gh issue create 時に使用する。Issueタイトル（CCプレフィックスなし）、テンプレート選択、Epic時のラベル、CLI制約を含む。
---

# Issue 作成規約

## 基本ルール

- `--assignee @me` で自分をアサインする (MUST)
- 新しいタスクに着手する前に、まず Issue を作成する

## Issue タイトル

PR タイトル（Conventional Commits 形）と混同しないよう、次に揃える (MUST)。

- **先頭に `feat:` / `fix:` / `chore:` 等の CC 型プレフィックスは付けない**（種別はラベル・テンプレート・本文で表す）。PR 作成時にエージェントが `type` を付与する
- 1行の短い要約に限定する（目安 60 文字以内）(SHOULD)
- 文末の句点は付けない (SHOULD)
- 先頭の `[WIP]` は使わない（必要なら本文で状態を書く）

Issue から PR を作るときの対応: Issue タイトルは「何の作業か」が分かればよく、PR タイトルは `pr-conventions` の CC 形に **別途** 整形する（Issue タイトルのコピペを PR タイトルにしない）。

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

## サブ Issue（GitHub ネイティブ sub-issue）

「サブ Issue」「子 Issue」「Epic のサブ」等の指示がある場合、GitHub ネイティブの sub-issue 機能を使う (MUST)。本文中の `Refs #N` やテキストテーブルだけでは親子関係は成立しない。

### 手順

1. 子 Issue を `gh issue create` で作成（通常どおり）
2. 作成後に返される Issue 番号（または ID）を取得
3. `gh api` で親 Issue に紐づける:

```bash
# 子 Issue の ID を取得
CHILD_ID=$(gh api repos/:owner/:repo/issues/<child_number> --jq '.id')

# 親 Issue に sub-issue として追加
gh api repos/:owner/:repo/issues/<parent_number>/sub_issues \
  --method POST \
  --field sub_issue_id="$CHILD_ID"
```

### 注意

- `Refs #<parent>` を本文に書くのは参照リンクとしては有用だが、ネイティブ sub-issue 関係は作らない
- Epic 本文のサブ Issue テーブル（テキスト）は人間向けの索引として併用してよい
- 親 Issue が存在しない場合や、サブ Issue 機能が無効なリポジトリではエラーになる。その場合はテキスト参照にフォールバックし、ユーザーに通知する

## CLI 制約

- `--body` に複数行のマークダウンを直接渡さない
- 一時ファイル（`/tmp/issue_body.md`）に書き出して `--body-file` を使用
- 一時ファイルは `write` ツールで作成する

## コマンド例

```bash
gh issue create --assignee @me --body-file /tmp/issue_body.md --title "ログインエラー時にメッセージを表示する"
# Epic 指示があり、ラベル Epic が存在する場合
gh issue create --assignee @me --body-file /tmp/issue_body.md --title "ログインエラー時にメッセージを表示する" --label Epic

# サブ Issue を親に紐づける
CHILD_ID=$(gh api repos/:owner/:repo/issues/76 --jq '.id')
gh api repos/:owner/:repo/issues/35/sub_issues --method POST --field sub_issue_id="$CHILD_ID"
```

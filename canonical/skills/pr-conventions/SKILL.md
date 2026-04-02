---
name: pr-conventions
description: PR作成の規約を適用する。PR作成、gh pr create、プルリクエスト作成時に使用する。PRタイトル正規化（CC形・Issue起点時の再構成）、テンプレート参照、CLI制約、Issue連携を含む。
---

# PR 作成規約

## 基本ルール

- `--assignee @me` で自分をアサインする (MUST)
- PR タイトルは **下記「PR タイトル」に従う**（Conventional Commits の型は `conventional-commits` スキルの型表に合わせる）(MUST)
- PR 作成前に最新の master を取り込む（`git fetch origin && git rebase origin/master` 推奨）

## PR タイトル

一貫性のため、次の形に **正規化** する (MUST)。

- 形式: `<type>: <要約>` または `<type>(<scope>): <要約>`（`<type>` または `)` の直後のコロンは1つだけ、その直後は半角スペース1つ）(MUST)
  - 例: `fix: ログインエラー時のメッセージ表示`
  - 例: `feat(api): セッション検証エンドポイントを追加`
- `<type>` / `<scope>` は英小文字・ハイフン区切り（スコープは省略可）
- 要約は命令形・現在形で短く（末尾の句点は付けない）(SHOULD)
- Issue 起点の PR でも **Issue タイトルをそのまま PR タイトルにしない**。Issue は `type:` なしの要約が前提のため、作業内容に合う `type`（と必要なら `scope`）を選び、要約文は意味が対応すればよい（コピペではなく再構成）(MUST)
- 次は避ける (MUST): タイトル先頭の `[WIP]` / `WIP:`（下書きは Draft PR）、タイトルだけの `Refs #123` / `#123`（参照は本文の `Refs #xxx`）、複数行

## Issue 連携（タイトル）

- Issue 番号や背景の詳細は **本文** の `Refs #xxx` に書き、PR タイトルは変更の要約に専念する

## テンプレート参照フロー

1. `.github/PULL_REQUEST_TEMPLATE.md` が存在するか確認
2. 存在する場合、`cat` でテンプレートの内容を確認
3. テンプレートの全セクションを埋める（（必須）とある項目は必ず）
4. `gh pr create --body-file` で作成

テンプレートが存在しない場合は、変更の目的・内容・影響範囲を本文に記述する。

## CLI 制約

- `--body` に複数行のマークダウンを直接渡さない（ターミナルが固まる原因）
- 一時ファイル（`/tmp/pr_body.md`）に書き出して `--body-file` を使用
- 一時ファイルは `write` ツールで作成する（`cat << EOF` はシェル問題を起こしやすい）

## Issue 連携（本文）

- Issue 参照は `Refs #xxx` を使用（`Closes` / `Fixes` は使わない）
- `Closes` はマージ時に Issue が自動クローズされるため、スプリント運用に合わない
- Issue のクローズはデプロイ後に手動で行う

## WIP

- 作業途中の PR は Draft pull request で作成する
- レビュー可能になったら Ready for review に変更する

## コマンド例

```bash
# 通常
gh pr create --assignee @me --body-file /tmp/pr_body.md --title "fix: 説明"

# Draft
gh pr create --assignee @me --body-file /tmp/pr_body.md --title "fix: 説明" --draft
```

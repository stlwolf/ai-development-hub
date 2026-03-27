---
name: pr-conventions
description: PR作成の規約を適用する。PR作成、gh pr create、プルリクエスト作成時に使用する。テンプレート参照、CLI制約、Issue連携のルールを含む。
---

# PR 作成規約

## 基本ルール

- `--assignee @me` で自分をアサインする (MUST)
- PR タイトルは Conventional Commits 形式に従う
- PR 作成前に最新の master を取り込む（`git fetch origin && git rebase origin/master` 推奨）

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

## Issue 連携

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

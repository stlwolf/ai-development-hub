---
name: worktrunk-worktrees
description: Worktrunk (wt) ベースの worktree 運用。作成・一覧・マージ・掃除・エージェント開始前チェックを含む。Cursor の worktree UI は使用せず wt CLI を正本とする。
depends:
  - skill: branch-naming
  - cli: wt
---

# Worktrunk Worktree 運用

## いつ使うか

- worktree の作成・切り替え・掃除
- エージェント並列作業の開始時
- ブランチ間の移動（`git checkout` の代わり）

## 前提条件

- `wt` CLI がインストール済みであること（`which wt` で確認）
- シェル統合が設定済みであること（`wt config shell install`）

## 作成

branch-naming スキルの命名規則に従ったブランチ名で worktree を作成する。

```bash
# デフォルトブランチから作成（--base 省略時）
wt switch --create feature/#123_add_export

# ベースブランチを明示指定
wt switch --create fix/#456_token_validation --base master
wt switch --create fix/#456_token_validation --base main
```

- `--base` 省略時はデフォルトブランチ（master または main）の最新版から作成される
- ブランチ名のフォーマット: `{prefix}/#{issue番号}_{簡潔な説明}`（branch-naming スキル参照）

## 一覧

```bash
# 全 worktree の状態確認
wt list

# JSON 出力（スクリプト向け）
wt list --format=json

# CI ステータス・行差分・サマリも表示
wt list --full

# worktree がないブランチも含める
wt list --branches
```

## 切り替え

```bash
# 既存 worktree に切り替え
wt switch feature/#123_add_export

# 前回の worktree に戻る（cd - のように）
wt switch -

# デフォルトブランチの worktree に戻る
wt switch ^

# GitHub PR のブランチに切り替え
wt switch pr:123
```

## マージ・掃除

```bash
# デフォルトブランチにマージ（squash + rebase + FF + worktree 削除）
wt merge

# コミット履歴を保持してマージ
wt merge --no-squash

# マージせず worktree のみ削除（ブランチはマージ済みなら削除）
wt remove

# untracked files がある worktree を削除
wt remove --force

# 未マージブランチを強制削除
wt remove -D
```

### squash と Conventional Commits の整合

`wt merge` のデフォルト動作は squash（複数コミットを1つに結合）。

- squash 時のコミットメッセージは Conventional Commits 形式で書き直すこと（`wt merge` が生成するデフォルトメッセージをそのまま使わない）
- 複数の独立した論理変更を含むブランチでは `--no-squash` を検討する
- conventional-commits スキルを参照

## エージェント開始前チェック

新しいエージェントセッションや並列タスクを開始する前に、以下を確認する:

- [ ] `wt list` で正しい worktree にいるか確認
- [ ] デフォルトブランチの worktree で直接作業していないか確認（ブランチを切ること）
- [ ] `git status` で前タスクの未コミット変更が残っていないか確認

## Cursor で worktree パスを開く方法

```bash
# ターミナルから Cursor で worktree を開く
cursor <worktree-path>

# または Cursor の File > Open Folder で worktree ディレクトリを指定
```

Cursor の built-in Git Worktrees UI（Source Control パネル）は使用しない（次項参照）。

## Cursor worktree UI 回避

worktree の操作は全て `wt` CLI 経由で行う。Cursor の Git Worktrees UI は使用しない。

理由: `wt` CLI とCursor の worktree UI が同じ worktree を異なる方法で管理すると、状態の不整合が起きる可能性がある。`wt` を正本（single source of truth）とすることで、人間・エージェントともに同じ CLI で操作し、把握漏れを防ぐ。

## master/main の扱い

- デフォルトブランチ名はリポジトリにより `master` または `main`
- `wt switch ^` でデフォルトブランチを抽象的に参照できる（名前を覚える必要がない）
- `--base` 指定時は実際のデフォルトブランチ名を使う（`--base master` or `--base main`）
- master/main への直接 push は禁止（branch-naming スキルの運用ルール）

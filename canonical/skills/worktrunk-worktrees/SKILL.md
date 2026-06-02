---
name: worktrunk-worktrees
description: worktreeを作成・切り替え・掃除し、並列作業を開始する。wt switch --create、wt merge、wt list、Issue起点のブランチ作成時に使用する。エージェント開始前チェック、ブランチ作成フローを含む。
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

### 作成後の位置確認

`wt switch --create` は worktree 作成と切り替えをまとめて行うが、実行環境によっては worktree は作成されても、呼び出し元の現在位置が意図した worktree に移らない場合がある。

作成直後は、続行前に以下を確認する。

```bash
pwd
wt list
```

- `pwd` が意図した worktree を指していれば、そのまま作業を続けてよい
- `wt list` に新しい worktree が見えているのに `pwd` が想定外なら、「作成は成功したが現在位置だけがずれている」状態として扱う
- この状態で `wt switch --create` を再実行しない。まず既存 worktree を再利用する

#### Claude Code での挙動（cwd は追従しない）

Claude Code セッションでは、`wt switch` してもセッションの cwd は worktree に**移らない**（シェルの `cd` が親プロセス＝Claude に消費されないため。`!pwd` はリポジトリルートのまま）。これは異常ではなく、ファイル操作は**絶対パス**で行われるため編集は正しく worktree に落ちる（cwd は表示上の話）。worktrunk 本来の「セッション re-root」は `EnterWorktree`（`/wt-switch-create`）経由のときだけ起きる。

cwd が追従しない結果、cwd ベースでは「今どの worktree か」を識別できない。並列セッションの識別は **セッション命名フック**（`canonical/hooks/`、Issue #124）が担う: `wt switch` のたびに `post-switch` hook が `#<issue> <slug>` を記録し、セッション名（→ tmux pane title）へ反映する。設定は `canonical/hooks/README.md` の「session-name.sh」節を参照。

### 既存 worktree の再利用

作成後に現在位置がずれていた場合や、fallback で別の worktree 進入手段を使いたい場合は、先に既存 worktree の有無を確認する。

```bash
wt list
git worktree list
```

```bash
# 既存 worktree へ再入場
wt switch <branch>
```

- 同じ Issue / ブランチ向けの worktree が既に存在すれば、それを再利用する
- 再利用時は `wt switch <branch>` を優先し、パスが明確な場合のみ `cd <worktree-path>` を使う
- 新規作成は「該当 worktree が存在しない」と確認できた場合だけ行う
- fallback は「新規作成」ではなく「既存 worktree への再入場」として扱う

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

# commit/squash をスキップ（rebase は通常どおり継続）
wt merge --no-commit

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

- `wt merge` では squash 時にエディタが開くので、その場でコミットメッセージを Conventional Commits 形式に書き直すこと（`wt merge` が生成するデフォルトメッセージをそのまま使わない）
- `wt merge --no-commit` は commit/squash をスキップするが、rebase は `--no-rebase` を付けない限り継続する。clean working tree が必要
- `wt merge --no-commit` はカスタム squash メッセージを自分で付けたいときの用途ではない。手動でコミット準備を済ませた後の特殊用途として扱う
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

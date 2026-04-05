---
name: branch-finish
description: ブランチ完了判定フロー。テスト検証→4択（マージ/PR/保留/破棄）→実行→クリーンアップ。実装完了後のブランチ処理に使用する。
depends:
  - skill: worktrunk-worktrees
  - skill: pr-conventions
  - skill: conventional-commits
---

# ブランチ完了判定フロー

## いつ使うか

- 実装完了後、ブランチの処理方法を決める時点
- `wt` CLI + worktree 運用が前提（未導入時は本スキル対象外）

## フロー

1. 検証（テスト・動作確認）
2. 4択提示
3. 選択肢の実行

## Step 1: 検証

テストスイートがある場合:

```bash
# プロジェクトのテストスイートを実行
npm test / cargo test / pytest / go test ./... / shellcheck <script>
```

テストが失敗した場合は先に進まない。修正してから再実行する。

テストスイートがない場合:
- 動作確認が完了しているかユーザーに確認する
- 未確認なら確認を促し、完了後に Step 2 に進む

ベース同期は `wt merge` が rebase で処理するため、このステップでの手動同期は不要。

## Step 2: 4択提示

以下を簡潔に提示する。説明は付けない。

```
実装が完了しました。どうしますか？

1. wt merge でデフォルトブランチにマージ
2. Push して PR 作成
3. ブランチ・worktree をそのまま保持
4. 作業を破棄
```

## Step 3: 選択肢の実行

### Option 1: マージ

```bash
# squash + rebase + FF + worktree 削除
wt merge

# コミット履歴を保持する場合
wt merge --no-squash
```

- `wt merge` はベース同期（rebase + FF）を含む
- squash 時のコミットメッセージは Conventional Commits 形式で書き直す（conventional-commits スキル参照）
- 複数の独立した論理変更を含むブランチでは `--no-squash` を検討

### Option 2: PR 作成

```bash
git push -u origin <branch>
```

PR 作成は pr-conventions スキルに従う。worktree は残す（レビュー中の修正対応のため）。

### Option 3: 保留

現状を報告して終了。ブランチ・worktree はそのまま維持する。

```
ブランチ <name> を保持します。worktree: <path>
```

### Option 4: 破棄

実行前に削除対象を提示し、ユーザーの明示的な確認を得る。

```
以下を削除します:
- ブランチ: <name>
- コミット: <commit-list>
- worktree: <path>

続行しますか？
```

確認後:

```bash
wt remove -D
```

## pr-conventions との役割分担

branch-finish = 完了フロー全体のオーケストレーション、pr-conventions = PR 作成の規約詳細。Option 2 で pr-conventions に委譲する。

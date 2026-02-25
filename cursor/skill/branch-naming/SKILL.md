---
name: branch-naming
description: ブランチ命名規則を適用する。ブランチ作成、git checkout -b、git switch -c 時に使用する。prefix選択、Issue番号、命名フォーマットのルールを含む。
---

# ブランチ命名規則

## フォーマット

```
{prefix}/#{issue番号}_{簡潔な説明}
```

## 前提

- ブランチ作成前に対応する Issue を作成すること
- master（デフォルトブランチ）から切る際は最新版から切る（`git pull origin master` 後に `git checkout -b`）

## prefix の選択

ブランチの主な作業内容に対応する prefix を使用する。Conventional Commits の型と対応させる。

| prefix | 用途 | コミット型との対応 |
|---|---|---|
| `feature/` | 新機能開発 | `feat` |
| `fix/` | 機能修正・不具合修正 | `fix` |
| `ui/` | UI・表示に関わる変更 | `ui` |
| `refactor/` | リファクタリング | `refactor` |
| `style/` | コードスタイル変更（フォーマット等） | `style` |
| `test/` | テスト追加・修正 | `test` |
| `docs/` | ドキュメント変更 | `docs` |
| `revert/` | コミットの取り消し | `revert` |
| `ci/` | CI/CD変更 | `ci` |
| `infra/` | インフラ変更 | `infra` |
| `chore/` | ライブラリ更新・設定変更等 | `chore` |
| `local/` | ローカル環境のみに影響する変更 | `local` |

複数コミットを含むブランチの場合、最も比率の高いコミット型に合わせる。1コミットの場合はそのコミットの型に合わせる。

## 運用ルール

- 1ブランチ = 1 Issue（タスク）に対応 (MUST)
- master への直接 push は禁止

## 例

```
feature/#1234_add_survey_export
fix/#567_reply_token_validation
refactor/#890_service_cleanup
```

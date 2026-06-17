---
name: issue-debug
description: Issue / Sentryエラーの調査・分析・修正を行う。情報取得、関連コード特定、原因分析、Arena検証、セカンドオピニオンレビュー、PR作成までのフローを含む。
depends:
  - skill: sentry-investigation
  - skill: persistent-exploration
  - skill: branch-naming
  - skill: conventional-commits
  - skill: pr-conventions
  - command: arena-perspectives
  - command: peer-ai-review
---

# Issue Debug

Issue / Sentry エラーの調査・分析・修正を行う。

## 入力形式

- GitHub Issue: `https://github.com/owner/repo/issues/123` / `#123` / `123`
- Sentry: `https://sentry.io/organizations/.../issues/12345/` / 数値ID / Short ID

## Step 1: 情報取得

### GitHub Issue

```bash
gh issue view "$ISSUE_NUM" --json number,title,state,body,labels,assignees,author,createdAt,comments
```

以下の形式で要約:
- **Issue**: #[number] [title]
- **状態**: [state]
- **作成者**: [author.login]
- **ラベル**: [labels]
- **内容サマリ**: [body の要約]

### Sentry エラーの検知

Issue 本文に Sentry リンクが含まれている場合、または入力が Sentry 形式の場合:
→ `sentry-investigation` スキルを読み込んで Sentry データを取得する。

```
Read ~/.cursor/skills/sentry-investigation/SKILL.md
```

スキルに従い、Issue 概要・スタックトレース・リクエスト情報を取得する。

## Step 2: Issue 分析

Issue の本文とコメントから以下を抽出し、構造化する。

**バグ報告の場合:**
- 再現手順
- 期待される動作
- 実際の動作
- エラーメッセージ / スタックトレース
- 環境情報

**機能要望の場合:**
- 要望の概要
- ユースケース
- 受け入れ条件

**質問の場合:**
- 質問内容
- 関連するコード / 機能

## Step 3: 関連コードの特定（サブエージェント委譲）

Issue 内容から抽出したキーワード・関数名・エラーメッセージを使い、Task tool (explore subagent) でコードベースを探索する。

**委譲プロンプトに含める情報:**
- Issue の要約（タイトル + 本文から抽出した技術的キーワード）
- エラーメッセージ / スタックトレース（あれば）
- 探索の目的（原因特定 / 影響範囲調査 / 再現手順の確立）

**難航時:**
調査が難航した場合（再現できない、原因が特定できない）、`persistent-exploration` スキルの行動制約テンプレートをサブエージェントのプロンプトに注入する。

外部要因（インフラ差異・環境等）の結論に傾く前は `code-path-exhaustion` を適用する（入力→出力のコードパスを読み切り、仮説を `tmp/hypothesis-NNN.md` に外部化してから外部要因へ。`hypothesis-gate` フックが N=3 で advisory 誘導）。

```
Read ~/.cursor/skills/persistent-exploration/SKILL.md
```

## Step 4: 原因分析

バグの場合、以下の観点で分析する:
- **直接的な原因**: どの処理が問題を引き起こしているか
- **根本原因**: なぜその問題が発生するか
- **影響範囲**: 他の機能への影響はあるか

分析結果をもとに修正方針の素案を作成する。

## Arena: 修正方針の検証

`/arena-perspectives` で修正方針の素案を複数モデルに投げ、妥当性を検証する。

- **入力**: 原因分析の結果 + 修正方針の素案 + 関連コードのコンテキスト
- **確認観点**: 方針の妥当性、見落としているエッジケース、より良い代替案の有無

## Gate: 修正方針の確認

- 原因分析 + アリーナ検証の結果をまとめてユーザーに提示
- Plan mode への切り替えを提案
- ユーザーが明示的に承認した場合のみ次に進む

## Step 5: 修正実施

承認後にファイルを修正し、変更内容のサマリーを提示する。

## Gate: セカンドオピニオンレビュー

修正実施後、PR 作成前に `/peer-ai-review` でセカンドオピニオンを取得する。
3 者合意（Cursor + Codex/Claude）が得られるまでイテレーションを回す。
合意が得られたら PR 作成に進む。

## Step 6: PR 作成（明示指示時のみ）

以下のスキルに従って実施:
- ブランチ作成: `branch-naming` スキル
- コミット: `conventional-commits` スキル
- PR 作成: `pr-conventions` スキル

## 安全規律

- read-only（情報取得・分析）→ 変更系（修正・PR 作成）の順で進める
- 破壊的操作（merge / close / delete / force push 等）はコマンド提示 + 影響説明で停止
- 明示指示がある場合のみ実行

---
title: "Phase 3 キックオフ: thread-done（完了報告生成・投稿）"
date: 2026-02-21
type: plan
participants:
  - Eddy
  - Cursor Agent (Primary)
related:
  - type: derived_from
    ref: ../episodes/2026-02-21-phase2-markdown-export.md
    reason: "Phase 2 エピソードの「Phase 3 への引き継ぎ」セクションが入力"
  - type: derived_from
    ref: ../plans/2026-02-20-kickoff-cursor-thread-tools.md
    reason: "プロジェクトキックオフの Phase 3 スコープ（threadTools.done）"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約（命名規則・ADR昇格基準・gate運用・plan/episode分離）"
  - type: depends_on
    ref: ../VERIFICATION_MATRIX.md
    reason: "検証項目 A-3-1 〜 A-3-3 に対応"
tags: [phase3, thread-done, git-diff, gh-issue, completion-report, vscode-extension]
keywords: [threadTools.done, git diff, git log, gh issue comment, body-file, judgment-extraction]
use_when:
  - "Phase 3 子スレッドを開始するとき（このファイルが最初のプロンプト）"
  - "thread-done 機能の設計判断を確認したいとき"
---

# Phase 3 キックオフ: thread-done（完了報告生成・投稿）

**作業開始前に必ず `CONVENTIONS.md`（プロジェクトルート）を読むこと。** ファイル命名規則、ADR 昇格基準、plan/episode 分離ルール、peer-ai-review gate 運用が定義されている。

## 1. 目的

スレッド完了時に `git diff` + `git log` で変更内容を要約し、定型フォーマットで GitHub Issue にコメント投稿する `threadTools.done` コマンドを実装する。

### Phase 3 の成功基準

- [ ] コマンドパレットから `threadTools.done` を実行し、Issue番号を入力すると完了報告が生成される
- [ ] `git diff` + `git log` による変更サマリが自動生成される
- [ ] `gh issue comment --body-file` で GitHub Issue にコメント投稿される
- [ ] エクスポートしたトランスクリプトから判断経緯の抽出がオプションで動作する

---

## 2. Phase 2 からの引き継ぎ

### 解決済み（Phase 1 + 2 で確認済み）

- better-sqlite3@12.6.2 で Cursor Electron 39 環境での動作確認済み（F5 実機テスト成功）
- `threadTools.list` + `threadTools.export` が動作
- raw protobuf パーサーで会話テキスト抽出成功
- conversationState のエンコード解明（base64 "~" prefix / hex）

### Phase 3 の主要課題

1. **`git diff` + `git log` による変更サマリ生成**
2. **定型フォーマットの完了報告テンプレート**
3. **`gh issue comment --body-file` による Issue 投稿**
4. **（オプション）トランスクリプトからの判断経緯抽出**

### Phase 2 の残課題（Phase 3 前処理 or スコープ外）

- 新フォーマットスレッド（`conversationState: "~"`）への対応 — Phase 3 ではスコープ外。export 機能の改善として別途対応
- SpecStory 出力との完全突合 — Phase 3 ではスコープ外

---

## 3. 実施計画

### Step 0: 前提調査（データパス調査）

Phase 2 の教訓: プランには必ず前提調査 Step を入れる。

- `git diff` / `git log` の出力フォーマットと、VS Code 拡張からの `child_process` 実行の制約を確認
- `gh` CLI の利用可否確認（PATH、認証状態）
- 完了報告の投稿先 Issue の特定方法を検討（ブランチ名から推定? ユーザー入力?）

### Step 1: git diff + git log による変更サマリ生成

```typescript
// child_process.execSync で git コマンドを実行
// ワークスペースルートをcwdに設定
const diff = execSync('git diff --stat HEAD~1', { cwd: workspaceRoot });
const log = execSync('git log --oneline -10', { cwd: workspaceRoot });
```

考慮事項:
- `HEAD~1` ではなくブランチの分岐点からの差分が適切か
- ファイル数が多い場合の要約方法
- コミットされていない変更の扱い

### Step 2: 完了報告テンプレート

プロジェクトキックオフの設計案（raw-logs の議論）を参考に:

```markdown
## 作業完了報告

### 変更内容
- [git log/diff から自動生成した変更サマリ]

### 対象ファイル
- `path/to/changed-file`

### 検証結果
- [テスト実行結果やコマンド出力]

### 判断経緯（オプション）
- [トランスクリプトから抽出した判断のサマリ]

### 残課題
- [あれば記載]
```

### Step 3: gh issue comment による投稿

```typescript
// 一時ファイルに書き出して --body-file で投稿（プロダクト向け PR ルール準拠）
writeFileSync(tmpBodyPath, reportMarkdown);
execSync(`gh issue comment ${issueNumber} --body-file ${tmpBodyPath}`, { cwd: workspaceRoot });
```

- Issue 番号はユーザー入力（InputBox）
- `gh` CLI の存在チェック + 認証状態チェックを preflight で実施
- 投稿前にプレビュー表示（エディタで開く → 確認 → 投稿）

### Step 4: トランスクリプトからの判断経緯抽出（オプション）

- `threadTools.export` で現在のスレッドをエクスポート
- エクスポートした Markdown から判断に関するキーワード（「選定」「採用」「棄却」「決定」等）を含む段落を抽出
- 完了報告の「判断経緯」セクションに追加

### Step 5: 検証

- `threadTools.done` の E2E テスト（実際の Issue にテストコメント投稿）
- git diff 出力の正確性確認
- gh CLI 未インストール時のエラーハンドリング

---

## 4. 検証マトリクス対応

| 検証項目 | ID | 本 Phase での検証内容 |
|---------|----|--------------------|
| `git diff` + `git log` による変更要約生成 | A-3-1 | Step 1 + Step 2 |
| `gh issue comment --body-file` による定型報告投稿 | A-3-2 | Step 3 |
| トランスクリプトからの判断経緯抽出 | A-3-3 | Step 4（オプション） |

---

## 5. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| `gh` CLI 未インストール | Issue 投稿不可 | preflight チェック + エラーメッセージでインストール案内 |
| git diff が巨大（大規模変更） | 報告が冗長 | `--stat` で要約 + ファイル数制限 |
| Issue 番号の特定が困難 | ユーザー操作が煩雑 | ブランチ名からの推定をオプション提供 |
| トランスクリプト抽出の精度 | 判断経緯が不正確 | オプション機能に留める。手動編集を前提 |

---

## 6. peer-ai-review 実施ポイント

**以下は実装プラン作成時に TODO 項目として独立登録すること。**
**gate をスキップする場合はエピソードにスキップ理由を明記すること。**（CONVENTIONS.md 準拠）

1. **Step 0 完了時**: 前提調査の結果確認（git/gh の制約が設計に影響する場合）
2. **Step 3 完了時**: コマンド全体のコードレビュー

---

## 7. ADR 作成チェックリスト

CONVENTIONS.md の ADR 昇格基準に基づき、以下のタイミングで ADR 作成を検討:

- [ ] 完了報告テンプレートのフォーマット選定（2つ以上の選択肢を比較した場合）
- [ ] git diff の範囲指定方法（HEAD~1 vs ブランチ分岐点 vs ユーザー指定）
- [ ] トランスクリプト抽出の方法（キーワードベース vs LLM 要約 vs 手動）

---

## 8. 完了条件

Phase 3 完了時に統合ハブスレッドに持ち帰るもの:

- [ ] `threadTools.done` が動作する拡張コード
- [ ] 完了報告テンプレートの設計（episodes/ に記録）
- [ ] VERIFICATION_MATRIX の A-3-1〜A-3-3 更新
- [ ] Phase 4（パッケージング）キックオフに必要な情報の整理
- [ ] 該当する ADR の作成

---

## 9. B-2-1 検証: キックオフで立ち上がりが速まるか

Phase 2 の教訓を反映し、本キックオフの冒頭に CONVENTIONS.md への参照を太字で記載した。Phase 3 子スレッド開始時に「このキックオフ + CONVENTIONS.md で文脈が復元できるか」を評価し、エピソードに記録すること。

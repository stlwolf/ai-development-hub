---
name: delegate-task
description: 親子 Claude Code セッション間の委譲操作を行う。kick（子を起動してタスクを渡す）と report（子→親への申し送り・レビュー依頼・完了報告）を自然言語の意図から判断して実行する。tmux 環境前提。
---

# delegate-task — 親子スレッド委譲操作

## いつ使うか

- 別 Claude Code セッション（子）に作業を委譲したいとき
- 子セッションから親セッションへ申し送り・レビュー依頼・完了報告を送るとき

## 前提

- tmux 環境（`$TMUX_PANE` が設定されていること）
- `projects/orchestration-engine/bin/oe-delegate` と `oe-report` が実行可能なこと
- スクリプトは絶対パスで呼ぶ（`~/work/repos/.../projects/orchestration-engine/bin/oe-delegate`）か、PATH に入っていること

---

## 実行コンテキストの確認（最初に判断する）

このスキルを呼んだのが **親セッション** か **子セッション** かによって操作が変わる。

| 現在地 | 可能な操作 |
|--------|-----------|
| **親セッション**（ユーザーが直接操作しているセッション） | **kick のみ**。子を起動してタスクを渡す |
| **子セッション**（oe-delegate で起動されたセッション） | **report のみ**。親へ申し送り・レビュー依頼・完了報告を送る |

判断できない場合は「現在のセッションは親ですか、子ですか？」と確認する。

---

## 意図の判断

コンテキスト確認後、自然言語から操作を推定する。

| 意図のキーワード | 操作 |
|----------------|------|
| 「委譲して」「任せて」「子に渡して」「#N を進めて」「別ペインで」| **kick**（親セッションのみ） |
| 「完了した」「申し送りして」「報告して」「進捗を伝えて」 | **report 通常**（子セッションのみ） |
| 「レビューしてほしい」「確認依頼」「レビュー依頼」 | **report --review**（子セッションのみ） |

**曖昧なケースは確認する:**
- 「レビューして」→ 親が子にレビュー作業を **kick** するのか、子が親に **report --review** するのか
- 「#N を進めて」と言ったのがユーザー（親）なら kick、Claude 自身（子）が言っているなら文脈エラー
- 「報告して」と言ったのが子 Claude なら report、親ユーザーなら kick（子に作業完了後の報告を促す kick）

---

## kick（親 → 子の委譲）

子 Claude Code セッションを起動し、タスクをキックする。

### kick パターン一覧

| パターン | 使いどころ |
|---------|-----------|
| **issue 番号あり** | issue が存在し、子に調べさせる | 
| **issue 番号あり + implementer-contract** | 実装タスクを委譲する場合（推奨） |
| **調査・レビュー委譲** | ファイル・PR・コードを調べてほしい場合 |
| **issue なし（タスク直渡し）** | 軽量な指示や issue 化不要のタスク |

### パターン別コマンド例

**issue 番号あり（基本）**

```bash
REPO="$(pwd)"
BIN="$REPO/projects/orchestration-engine/bin"
"$BIN/oe-delegate" -w "$REPO" "Issue #N の内容を gh issue view N で確認して作業を進めて。リポジトリ: $REPO"
```

**issue 番号あり + implementer-contract（実装委譲時の推奨）**

```bash
REPO="$(pwd)"
BIN="$REPO/projects/orchestration-engine/bin"
"$BIN/oe-delegate" -w "$REPO" "Issue #N の内容を gh issue view N で確認して実装を進めて。リポジトリ: $REPO。実装規律は $REPO/canonical/skills/implementer-contract/SKILL.md を読んで従うこと"
```

**調査・レビュー委譲**

```bash
"$BIN/oe-delegate" -w "$REPO" "以下の調査をして結果を申し送りして。<調査内容を1行で>"

# PR レビュー委譲
"$BIN/oe-delegate" -w "$REPO" "PR #N を gh pr diff N で確認してレビュー結果を申し送りして。リポジトリ: $REPO"
```

**issue なし（タスク直渡し）**

```bash
"$BIN/oe-delegate" -w "$REPO" "<タスク内容を1行・改行なしで>"
```

### 改行制約

- `oe-delegate` のタスク引数に **改行バイトを含めない**。`tmux send-keys -l` が改行をそのまま端末に送り、Claude Code プロンプトが途中で送信される
- 制約は「1文」ではなく「**1行・1引数（改行を含まない複数文は可）**」。句点・セミコロンで区切れば複数文を渡せる
- 改行が必要な長文は **issue/plan のパスや番号を渡して子に取得させる**（直接文字列で渡さない）

### 自動付記（スキル側での追記は不要）

`oe-delegate` は以下をプロンプト末尾に自動で付記する:

```
完了後は <path>/oe-report "サマリー" を実行して申し送りを送ること。レビュー依頼は <path>/oe-report --review "サマリー"。
```

---

## report（子 → 親への報告）

**子セッション専用。** 親 Claude Code プロンプトへテキストを注入する。

### 通常報告（完了・中間申し送り）

```bash
BIN="$REPO/projects/orchestration-engine/bin"
"$BIN/oe-report" "<1行サマリー>"
```

親プロンプトに `申し送り: <サマリー>` が届き、Enter が発火する。

### レビュー依頼

```bash
"$BIN/oe-report" --review "<確認してほしい内容を1行で>"
```

親プロンプトに `レビュー依頼: <内容>` が届く。

### エラー時のリカバリー

`oe-report` が `parent pane not found` で失敗した場合（セッション切断・再アタッチ後など）、手動で送信する:

```bash
tmux send-keys -l -t '<親ペインID>' '申し送り: <メッセージ>'
tmux send-keys -t '<親ペインID>' Enter
```

親ペイン ID が不明な場合は `tmux list-panes -a` で確認する。

---

## 関連

- `projects/orchestration-engine/bin/oe-delegate` — 子ペイン起動 + キック実装
- `projects/orchestration-engine/bin/oe-report` — 親への報告実装（`OE_DELEGATE_WAIT_SEC` で起動待ち秒数を上書き可）
- `implementer-contract` スキル — 実装委譲時に kick プロンプトへ組み込む契約定義
- #137（PoC）/ #138（実装）— 背景と設計決定

---
name: delegate-task
description: 親子 Claude Code セッション間の委譲操作を行う。delegate（子を起動してキック）、send（既存ペインへ1行/キックオフ送信・誤送信防止つき）、list（宛先確認）、report（子→親の申し送り）を自然言語の意図から判断して実行する。tmux 環境前提。
---

# delegate-task — 親子スレッド委譲操作

## いつ使うか

- 別 Claude Code セッション（子）に作業を委譲したいとき（**delegate**）
- 既に動いている別ペインへ追加指示・キックオフ・関連の薄い会話を投げたいとき（**send**）
- どのペインに何を任せているか宛先候補を確認したいとき（**list**）
- 子セッションから親へ申し送り・レビュー依頼・完了報告を送るとき（**report**）

## 前提

- tmux 環境（`$TMUX_PANE` が設定されていること）
- `projects/orchestration-engine/bin/` の `oe-delegate` / `oe-send` / `oe-list` / `oe-report` が実行可能なこと
- `jq` が PATH にあること（アドレッシング解決に使用）
- スクリプトは絶対パスで呼ぶ（`~/work/repos/.../projects/orchestration-engine/bin/oe-delegate`）か、PATH に入っていること

---

## コマンド全体像

| コマンド | 方向 | 役割 |
|---------|------|------|
| `oe-delegate` | 親 → 子 | 子ペインを起動（spawn）し、最初のキックを送る。registry に登録 |
| `oe-send` | 任意 → 任意 | 既存ペインへ 1 行 / キックオフを送る汎用入口。宛先はラベル or `%N` |
| `oe-list` | — | 宛先候補を source 列付きで一覧（誤送信防止） |
| `oe-report` | 子 → 親 | （legacy）子→親の申し送り。**戻しは oe-send に一本化**（論点E で整理） |

`oe-delegate` = spawn + `oe-send`（キック）の合成。送信の実体は `oe-send` に集約されている。

---

## delegate（親 → 子の委譲）

子 Claude Code セッションを起動し、最初のタスクをキックする。

```bash
REPO="$(pwd)"
BIN="$REPO/projects/orchestration-engine/bin"
```

### パターン別コマンド例

**issue 番号あり（基本）** — `--label` で後から `oe-send #N` で指せるようにする

```bash
"$BIN/oe-delegate" -w "$REPO" --label "#N" "Issue #N の内容を gh issue view N で確認して作業を進めて。リポジトリ: $REPO"
```

**キックオフ doc を渡す（4層ドキュメント方式 / リッチな事前情報）**

```bash
"$BIN/oe-delegate" -w "$REPO" --label "#N" --kickoff "$REPO/path/to/kickoff.md" "補足の要望があればここに1行で"
```

- `--kickoff <path>` は子へ `"<path> を読んで進めて。"` を付加し、子が読めるよう doc のディレクトリを `--add-dir` で開示する
- doc が無い軽いケースは、親で組み立てた内容を **workspace 配下**（例 `<workspace>/.oe/kickoff-*.md`）に書いてから `--kickoff` で渡す（`/tmp` は対話型 claude が読めないので避ける）

**実装委譲（implementer-contract 併用）**

```bash
"$BIN/oe-delegate" -w "$REPO" --label "#N" "Issue #N を実装して。リポジトリ: $REPO。実装規律は $REPO/canonical/skills/implementer-contract/SKILL.md を読んで従うこと"
```

### 改行制約

- タスク引数・ad-hoc に **改行バイトを含めない**（`oe_send_line` が改行を検出すると送信を拒否する）。複数文は句点・セミコロンで区切る
- 改行が必要な長文は **issue/plan のパスや番号を渡して子に取得させる**か、`--kickoff` でパス渡しする

### delegate は report を内包しない

`oe-delegate` は spawn + キックに専念し、戻し（report）を一切焼き付けない（Unix 哲学・単機能）。
子に報告させたいなら、その指示は **task / kickoff の本文に自分で書く**。戻しの送信自体は子が
汎用の `oe-send "$PARENT_TMUX_PANE" "..."` で行う（下記「戻し」）。

---

## send（既存ペインへの送信）

`oe-delegate` で起動した子に限らず、**既に動いているペイン**へ 1 行やキックオフを送る。親→子の追加指示、関連の薄い側道会話、（必要なら）子→親の返しにも使える汎用入口。

```bash
# ラベルで送る（registry / pane-issue で解決）
"$BIN/oe-send" "#142" "テストは pytest で。失敗ケースも足して"

# 生のペインIDで送る（ラベルが無いペイン・側道会話）
"$BIN/oe-send" "%37" "さっきの設計の続きだけど、TTL は 24h で合ってる？"

# キックオフ doc を既存ペインに読ませる
"$BIN/oe-send" --kickoff "$REPO/path/to/kickoff.md" "#142" "前提が変わったので読み直して"

# Enter を撃たずに投入だけ（人間が読んでから送る／セッションを汚さない）
"$BIN/oe-send" --no-enter "%37" "確認してほしい下書き"
```

### 誤送信を防ぐ

宛先を間違えやすいときは、まず `oe-list` で候補を確認してからラベル / `%N` を選ぶ。

```bash
"$BIN/oe-list"
# PANE     SOURCE         LABEL
# %37      pane-issue     #142 oe-delegate redesign
# %41      spawn-registry my-task
# %44      pane-title     ai-development-hub
```

- 同じラベルが複数ペインに一致する場合、`oe-send` は曖昧エラーで止まる → `%N` で明示する
- ラベルは現在の親（`$TMUX_PANE`）が起動した子にスコープされる。別の親の子には誤って届かない

---

## 戻し（子 → 親）

delegate は report を内包しないので、**戻しは汎用の `oe-send` で行う**。子に渡っている
`PARENT_TMUX_PANE`（親ペイン ID）へ送るだけ:

```bash
"$BIN/oe-send" "$PARENT_TMUX_PANE" "実装完了。PR #150 を作成した"
"$BIN/oe-send" --no-enter "$PARENT_TMUX_PANE" "親が読んでから送りたい下書き"
```

`PARENT_TMUX_PANE` が未設定（手動委譲・再アタッチ後など）なら、親ペインを `oe-list` で確認して
`%N` を直接指定する。

### oe-report（legacy）

`oe-report "..."` / `oe-report --review "..."` は従来の子→親専用コマンド。delegate された子では
`PARENT_TMUX_PANE` env から親を解決して一応動くが、**戻しは上記 oe-send に一本化**する方針
（oe-report 自体の整理＝薄い alias 化／廃止は論点E）。

---

## アドレッシングの仕組み（参考）

`oe-send` / `oe-list` のラベル解決は 2 ソースの union:

- **spawn レジストリ**（`~/.claude/state/oe-delegate/`）— `oe-delegate` が登録した子。`--label` の値で指す。ゼロベース調査期の仮ラベルもここ
- **pane-issue state**（`~/.claude/state/pane-issue/`）— `wt switch` 済みペインの `#N`。`scripts/wt/wt-pane-issue.sh` が書く

注意点:

- `#N` 解決は **`wt switch` 経由が前提**。素の `git checkout` で issue ブランチに入った子は pane-issue が無いので、`--label` の仮ラベルか `%N` で指す
- 関連の薄い側道会話用ペイン（`master` / リポ名命名）は `#N` を持たない → `%N` で指す
- 同一ペインに spawn ラベルと pane-issue の両方があれば **pane-issue（現在の #N）を優先**

### 2 系統の send を混同しない

- `oe-send`（本スキル）= **対話セッション**へ `tmux send-keys` で注入する transport（`lib/delegate-send.sh`）
- `lib/spawn.sh` の `oe_spawn_send` = engine の **非対話** `claude -p`・wez・envelope 系。別サブシステムであり、統合しない

---

## 関連

- `projects/orchestration-engine/bin/oe-delegate` — 子ペイン起動 + キック（spawn + send）
- `projects/orchestration-engine/bin/oe-send` — 既存ペインへの汎用送信
- `projects/orchestration-engine/bin/oe-list` — 宛先候補の一覧
- `projects/orchestration-engine/bin/oe-report` — 子→親の報告（legacy。戻しは oe-send に一本化）
- `projects/orchestration-engine/lib/delegate-send.sh` — 改行拒否の 1 行 safe-send
- `projects/orchestration-engine/lib/delegate-registry.sh` — アドレッシング（record/resolve/list/gc）
- `implementer-contract` スキル — 実装委譲時に kick プロンプトへ組み込む契約定義
- `projects/orchestration-engine/docs/plans/2026-06-08-plan-oe-delegate-redesign.md` — 本再設計の plan doc
- #137（PoC）/ #138（旧設計）/ #142（本再設計）— 背景と設計決定

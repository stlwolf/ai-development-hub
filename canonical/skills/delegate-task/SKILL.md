---
name: delegate-task
description: 親子 Claude Code セッション間の委譲操作を行う。delegate（子を起動してキック）、send（既存ペインへ1行/キックオフ送信・誤送信防止つき）、list（宛先確認）、report（子→親の申し送り）を自然言語の意図から判断して実行する。tmux 環境前提。
---

# delegate-task — 親子スレッド委譲操作

## いつ使うか

- 別 Claude Code セッション（子）に作業を委譲したいとき（**delegate**）
- 既に動いている別ペインへ追加指示・brief・関連の薄い会話を投げたいとき（**send**）
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
| `oe-send` | 任意 → 任意 | 既存ペインへ 1 行 / brief を送る汎用入口。宛先はラベル or `%N` |
| `oe-list` | — | 宛先候補を source 列付きで一覧（誤送信防止） |
| `oe-register` | — | 手動起動 pane を登記（`root`=自己 root / `link %N`=相手を自分の下に）。spawn を経ない pane を oe-tree / cockpit に現す |
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

**子 Claude に起動オプションを渡す** — 自律調査で権限プロンプト停止を避けたい場合

```bash
"$BIN/oe-delegate" -w "$REPO" --label "#N" --claude-arg --permission-mode --claude-arg auto "Issue #N の内容を確認して調査して。リポジトリ: $REPO"
```

**brief doc（委譲指示書）を渡す（4層ドキュメント方式 / リッチな事前情報）**

```bash
"$BIN/oe-delegate" -w "$REPO" --label "#N" --brief "$REPO/path/to/brief.md" "補足の要望があればここに1行で"
```

- `--brief <path>` は子へ `"<path> を読んで進めて。"` を付加し、子が読めるよう doc のディレクトリを `--add-dir` で開示する（旧 `--kickoff` は deprecated alias として存続・#255。新規は `--brief` を使う）
- doc が無い軽いケースは、親で組み立てた内容を **workspace 配下**（例 `<workspace>/.oe/brief-*.md`）に書いてから `--brief` で渡す（`/tmp` は対話型 claude が読めないので避ける）。`.oe/` はこのリポジトリでは gitignore 済み。

**実装委譲（implementer-contract 併用）**

```bash
"$BIN/oe-delegate" -w "$REPO" --label "#N" "Issue #N を実装して。リポジトリ: $REPO。実装規律は $REPO/canonical/skills/implementer-contract/SKILL.md を読んで従うこと"
```

**統括（並列 root）を spawn する場合** — brief 冒頭で `doc-flow-guardrail` の cold-start ロードを明示する（実装子と違い固定節でなくフロー全体が要るため）。

### 改行制約

- タスク引数・ad-hoc に **改行バイトを含めない**（`oe_send_line` が改行を検出すると送信を拒否する）。複数文は句点・セミコロンで区切る
- 改行が必要な長文は **issue/plan のパスや番号を渡して子に取得させる**か、`--brief` でパス渡しする

### delegate は report を内包しない

`oe-delegate` は spawn + キックに専念し、戻し（report）を一切焼き付けない（Unix 哲学・単機能）。
子に報告させたいなら、その指示は **task / brief の本文に自分で書く**。戻しの送信自体は子が
汎用の `oe-send "$PARENT_TMUX_PANE" "..."` で行う（下記「戻し」）。

### worktree 作成分担（子が自作・統括は hands-off）

委譲では **worktree を作るのは子**で、統括（親）は作らない。誰が作るかを取り違えると統括の pane が迷子になる。

- **子が自分の worktree を作る**: 子は自分の pane で `wt switch --create <branch>` を実行する（`wt switch` がそのペインの pane-issue state＝`#N` を書き、以後 `oe-send "#N"` で指せる。issue 起点でも同じ）。並列委譲でも**各子がそれぞれ自分の分を作る**。
- **統括（親）は事前作成しない・hands-off**: 親が `wt switch --create` すると親自身のペインの pane-issue state（`#N`）が張り替わり、親ペイン自身が迷子になる（`oe-send` の宛先解決もずれる）。**hands-off が統括の条件**。親がどうしても worktree を用意する稀な場合だけ、pane-issue state を書き換えない `git worktree add`（`wt switch` による pane-issue 更新を避ける）を使う。
- **per-issue は end-to-end で子へ**: 各 issue の §0 洗い出し以降（設計 SO / 調査 / 実装）を統括が自分の会話で巻き取らず、issue ごとに子スレッドへ一気通貫で委譲する（親 lean）。§0 の一括 read-only 洗い出しだけは親 or 使い捨て subagent が担ってよい。
- **マージ・worktree 掃除は親 / 人間（Human Gate、HG）**: 子は完了報告のみ行い、マージも worktree 掃除もしない。

### elevated 子 spawn の owner 承認ハンドシェイク（#262）

**いつ発火するか（限定）**: 子が **elevated**（`bypassPermissions`、または本番 / 機微アクセスを持つタスク）のときだけ。通常のローカル auto 委譲は対象外で従来どおり（ハンドシェイクを掛けない）。

**なぜ要るか**: 親が elevated 子を spawn しようとすると、ハーネスの auto-mode classifier が**親の spawn tool-call を評価して block** する（解除は owner の直接アクションのみ・安全機構として正しい）。分類器は繰り返し block された後にしか in-TUI プロンプトを出さないので、親が叩き直すと #262 の「混乱した往復」になる。これを、owner が 1 アクションで判断できる**整形済み承認パッケージを spawn 前に先出し**することで断つ。**分類器は尊重する（変えない・迂回しない）**。

**手順（3 ステップ）**:

本番 / 機微アクセスの auto 子は `--elevated` を**必ず宣言する**（engine は本番アクセスを自動検知できないため。`--elevated` を付けると実 spawn は承認済みダイジェストを必須にする。`bypassPermissions` 子は宣言せずとも elevated 扱い）。

```bash
# 1. spawn せず承認パッケージ + ダイジェストを印字（print は子を作らないので classifier に block されない）
"$BIN/oe-delegate" -w "$REPO" --label "#N" --elevated \
  --claude-arg --permission-mode --claude-arg auto \
  --reason "本番隣接の非対話 deploy が要る" \
  --print-approval "タスク1行"
# → owner 向けパッケージ（要求権限モード / elevated 宣言 / 対象子 / 理由 / 作業ディレクトリ /
#    blast radius / 承認ダイジェスト）と、そのまま実行できる実 spawn コマンド（--approved-digest 付き）を印字。

# 2. owner が 1 アクションで承認（表示された実 spawn を承認する / owner が自分で実行する）。

# 3. 実 spawn（同じ引数 + 承認ダイジェスト）。oe-delegate が引数から digest を再計算して照合し、
#    承認後にコマンドが変わっていれば拒否（exit 3）＝承認↔実行の binding。--elevated 宣言も digest に
#    束縛されるので、非 elevated の承認に後から --elevated を付けて escalation することはできない。
"$BIN/oe-delegate" -w "$REPO" --label "#N" --elevated \
  --claude-arg --permission-mode --claude-arg auto \
  --reason "本番隣接の非対話 deploy が要る" \
  --approved-digest "<step1 のダイジェスト>" "タスク1行"
```

- **binding**: `--print-approval` が出すダイジェストは workspace 絶対パス / label / claude 引数 / brief 絶対パス + 内容 hash / task / elevated 宣言 から決定論計算する（`--reason` は注記なので含めない）。実 spawn 時に不一致なら spawn せず exit 3。親（モデル）が承認済みと違うコマンド（属性含む）を走らせる drift を機構で捕まえる。
- **classifier は迂回しない**: 実 spawn 自体は従来どおり owner ゲート（分類器）を通る。ハンドシェイクは「owner が 1 アクションで判断するための情報とタイミング」を標準化するだけ。
- **audit**: elevated spawn は `child_spawned` イベントに `permission_mode` + `elevated` を焼き込む（auto でも elevated 宣言の有無で通常 spawn と事後区別できる・registry は変更しない）。
- **v0 の限界（plan §8・意図的な defer）**:
  - ダイジェストは公開入力からの決定論チェックサムで、**owner 承認の暗号的証明ではない**（nonce / 期限 / 消費状態を持たない）。**authZ の実体はハーネスの分類器**（agent は elevated spawn の block を自己解除できない）で、ダイジェストは「owner が見た内容 = 実行内容」を保証する drift-guard。両者は別レイヤー。
  - brief は承認時に内容 hash を束縛するが、spawn 後に子が読むまでの差し替え（read-time TOCTOU）までは束縛しない。
  - `permission_mode` は CLI 引数からの best-effort 推定（継承 config は反映しない）。enforcement は明示 `--elevated` を主ゲートにするので本番ケースは mode 推定に依存しない。
- 規範（なぜ owner 承認が要るか）は `orchestration-toolkit`、ゲート位置は `doc-flow-guardrail` の routing 表、engine フラグの詳細は `oe-delegate -h` を参照（3軸分離）。

---

## send（既存ペインへの送信）

`oe-delegate` で起動した子に限らず、**既に動いているペイン**へ 1 行や brief を送る。親→子の追加指示、関連の薄い側道会話、（必要なら）子→親の返しにも使える汎用入口。

```bash
# ラベルで送る（registry / pane-issue で解決）
"$BIN/oe-send" "#142" "テストは pytest で。失敗ケースも足して"

# 生のペインIDで送る（ラベルが無いペイン・側道会話）
"$BIN/oe-send" "%37" "さっきの設計の続きだけど、TTL は 24h で合ってる？"

# brief doc を既存ペインに読ませる
"$BIN/oe-send" --brief "$REPO/path/to/brief.md" "#142" "前提が変わったので読み直して"

# Enter を撃たずに投入だけ（人間が読んでから送る／セッションを汚さない）
"$BIN/oe-send" --no-enter "%37" "確認してほしい下書き"
```

> `--brief` のパスは **対象ペインの可読ルート内**（cwd / `--add-dir` 済みの場所）に置く。
> 稼働中ペインには後付けで `--add-dir` できないため、ルート外だと子が権限プロンプトで止まる。
> （`oe-delegate --brief` は起動時に doc dir を `--add-dir` 開示するので問題ない）

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
- **custom ラベル（任意名）**は現在の親（`$TMUX_PANE`）が起動した子にスコープされ、別親の同名には届かない。一方 **`#N` は issue の大域同定**（pane-issue 由来）で親スコープ外 — 同一サーバの別親が起動した `#N` 子にも解決されうる

---

## register（手動起動 pane を登記・#259）

`oe-delegate` を経ずに手動起動した pane は spawn registry に出ないため、`oe-tree` / cockpit（`oe-select` / `--pick`）に現れず、委譲関係も登記されない。`oe-register` で登記する。

```bash
# 手動起動した統括 pane を自分自身で root 登記（oe-tree に root として現す）
"$BIN/oe-register" root --label "#N"

# 既存の相手ペイン %N を自分の下に子として登記（spawn を経ない委譲の登記）
"$BIN/oe-register" link "%37" --label "#150"
```

- `link` の guard: target 非生存 / `%self` / 生存する別親の子 → 拒否（他人の子の横取り防止・`--force` で reparent）。orphan（親 gone）は引き取り可・既に自分の子は冪等
- `root` の guard: 生きた親を持つ委譲子の自己 root 化（cold-start 手順の誤実行など）は拒否（detach 防止・`--force` で明示 re-root）
- 登記後は `oe-send "#N"` / `oe-list` / `oe-tree` が通常どおり解決する（registry の record を書くだけ・既存挙動は不変）

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

### malform を持ち込まない（生 capture を貼らない）

戻し・追加指示で子ペインの生出力（tool-call タグ列・box-drawing・制御文字）を **そのまま貼らない**。
要約するか path（ファイル/ログの場所）で渡す。生貼付は親の自己回帰模倣で tool-call malform を
連鎖させる（#233 の主題）。full な規律は `orchestration-toolkit` の「malform hygiene」節。

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
- 同一ペインに spawn ラベルと pane-issue の両方があれば **pane-issue（現在の #N）を優先**（子が `wt switch` すると元の custom ラベルは以後解決されなくなる＝ドリフト吸収の帰結。以後は `#N` で指す）

### 2 系統の send を混同しない

- `oe-send`（本スキル）= **対話セッション**へ `tmux send-keys` で注入する transport（`lib/delegate-send.sh`）
- `lib/spawn.sh` の `oe_spawn_send` = engine の **非対話** `claude -p`・wez・envelope 系。別サブシステムであり、統合しない

---

## 関連

- `projects/orchestration-engine/bin/oe-delegate` — 子ペイン起動 + キック（spawn + send）
- `projects/orchestration-engine/bin/oe-send` — 既存ペインへの汎用送信
- `projects/orchestration-engine/bin/oe-list` — 宛先候補の一覧
- `projects/orchestration-engine/bin/oe-register` — 手動起動 pane の登記（自己 root / 既存 pane の委譲 link・#259）
- `projects/orchestration-engine/bin/oe-report` — 子→親の報告（legacy。戻しは oe-send に一本化）
- `projects/orchestration-engine/lib/delegate-send.sh` — 改行拒否の 1 行 safe-send
- `projects/orchestration-engine/lib/delegate-registry.sh` — アドレッシング（record/resolve/list/gc）
- `implementer-contract` スキル — 実装委譲時に kick プロンプトへ組み込む契約定義
- `projects/orchestration-engine/docs/plans/2026-06-08-plan-oe-delegate-redesign.md` — 本再設計の plan doc
- #137（PoC）/ #138（旧設計）/ #142（本再設計）— 背景と設計決定

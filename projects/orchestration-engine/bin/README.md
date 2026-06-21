# bin/ — スクリプト索引

orchestration-engine の実行可能エントリの簡易リファレンス（AI エージェント / 人間向け）。背景は親 [`../README.md`](../README.md)、詳細は各スクリプト冒頭のコメントと `docs/` を参照。

scripts は 2 系統に分かれる（[`../README.md`](../README.md) 「2 系統」節）:

- **本体エンジン**: `oe`（+ 補助 `oe-capture`）
- **親子委譲 CLI（delegate-task 系）**: `oe-delegate` / `oe-kick` / `oe-send` / `oe-list` / `oe-select` / `oe-report` / `oe-jump`（通知→ペインへ focus）
- **観測（cockpit・read-only）**: `oe-status`（engine state/audit + delegate liveness の俯瞰） / `oe-ident`（ペイン識別子を border へ read 時投影）

---

## oe — 本体エンジン（自律オーケストレーション）

1 サイクルの自律ループ（envelope→spawn→capture→verify→monitor）。非対話・wez + `claude -p`。

```bash
bash bin/oe "タスク記述"
bash bin/oe --task-file <path>
```

関連 lib: `envelope.sh` / `spawn.sh` / `capture.sh` / `verify.sh` / `monitor.sh` / `audit.sh` / `cleanup.sh` / `constants.sh`

## oe-capture — ペイン capture（本体エンジン補助）

既存（対話中）ペインに attach し、終端マーカーを読み取って分類・KVS/audit に記録。

```bash
oe-capture <pane_id> [--session-id <id>] [--lines <N>]
```

関連 lib: `attach.sh` / `capture.sh` / `audit.sh` / `session.sh`

## oe-refute — 確定前の同期反証 verb（#183 / Stage A）

確定（設計判断・根拠断定・外部仮説ジャンプ）の前に、独立した反証レーンを N 体立てて claim を反証させ、共有 verdict エンベロープ `{verdict, reason}` を同期で返す。バックエンドは `so-compare`（codex/cursor/claude マルチプロバイダ並列）を wrap する薄いラッパー。

```bash
oe-refute --claim <doc> [--lanes N] [--rubric consensus|exploration]
```

- `--claim <doc>` … 反証対象の claim doc（markdown）。**必須**。先頭の YAML frontmatter（`---`〜`---`）から `claim`（必須・1 行）/ `rubric`（`exploration`|`consensus`）/ `domain`（任意・無視可）のみパース。閉じ `---` 以降の **body は不透明**に反証レーンへ素通し（ドメイン非依存）
- `--lanes N` … 反証レーン数（既定 `2`）。`2`→`codex,cursor` / `3`→`codex,claude,cursor`。それ以外は exit 2
- `--rubric R` … 評価レンズ。`exploration`（breadth=軸5 / grounding=軸3 を第一級）/ `consensus`（問題認識/方針/リスク）。指定時 frontmatter を上書き。どちらも無ければ `exploration`
- 出力（stdout JSON）: `{verdict, reason, rubric, lanes, dissent:[{lane,verdict,note}], output_dir, audit_id}`。`output_dir` は so-compare 生出力のパス（確定時証跡のアンカー用）、`audit_id` は ULID
- 集約は **conservative**: 1 レーンでも material に refuted → 全体 refuted。全レーン survived のときのみ survived。verdict を取れないレーンは survived 扱いにせず `error` とし、dissent に記録した上で survived 確定を阻む（保守側）
- exit: `survived`→0 / `refuted`→3（**Stage A は advisory**・JSON が正本）
- 最小 audit を `<OE_DATA_DIR|project>/audit/oe-refute.jsonl` に 1 行追記

関連 lib: `session.sh`（`oe_generate_session_id`）。バックエンド: `so-compare`（`OE_REFUTE_SO_COMPARE` で実体を上書き可）

## oe-review — 実装SO（コード欠陥レビュー）の diff バインド artifact verb (#194 / L2)

実装後・PR 前に、現ブランチの reviewed diff（`base...HEAD`）に対して独立レビューレーンを N 体立て、コード欠陥／品質／到達可能性を検出させる**実装SO** verb。設計SO（`oe-refute` の exploration/consensus）と**構造的に識別可能**・**reviewed diff にバインド**した独立アーティファクトを emit する（将来の PR-create hard gate=#24 の前提物）。

```bash
oe-review [--lanes N] [--base <ref>] [--context <doc>]
```

- `--lanes N` … レビューレーン数（既定 `2`）。`2`→`codex,cursor` / `3`→`codex,claude,cursor`。既定で実装者 Claude を抜き多様性担保（設計SO=`oe-refute` と同方針）
- `--base <ref>` … diff の base ref（`base...HEAD` をレビュー対象に）。省略時は自動解決: `OE_REVIEW_BASE` > `origin/HEAD` > `master` > `main`。解決不能/不在/差分ゼロは exit 2
- `--context <doc>` … 追加コンテキスト（issue 要件等）を反証プロンプトに inline するファイル
- 出力（stdout JSON）: `{verdict, reason, lens:"impl", lanes, dissent:[{lane,verdict,note}], reviewed_sha, diff_base, diff_hash, changed_files_count, output_dir, audit_id}`
- **diff バインド**: `reviewed_sha`(HEAD) / `diff_base` / `diff_hash`(=`base...HEAD` 内容の `git hash-object`) を JSON と audit に記録。将来ゲートが「**現 HEAD diff に対する**実装SO が在るか」を機械判定でき、stale-SO false-pass（古い版に実行済→その後コード変更）を防ぐ
- **設計SO との識別**: 別 verb・別 audit stream（`oe-review.jsonl`）・`event_type=oe_review`・`lens=impl`・diff バインドの有無で構造的に識別可能（`oe-refute` の `oe_refute` / rubric とは別物）
- **diff 注入**: reviewed diff を反証プロンプトに注入（`OE_REVIEW_DIFF_MAX_BYTES`=既定 30000 以内なら inline、超過時は changed-files＋base ref＋「`git diff <base>...HEAD` をレビューせよ」指示で workspace フォールバック）
- 集約は **conservative**（`oe-refute` と同様）: 1 レーンでも material な欠陥検出→全体 refuted。verdict を取れないレーンは `error` とし survived 確定を阻む
- exit: `survived`→0 / `refuted`→3（**advisory**・JSON が正本）
- 最小 audit を `<OE_DATA_DIR|project>/audit/oe-review.jsonl` に 1 行追記
- 限界: 「レーンが実 diff を読んだ」ことは機械検証できない（どの SO 経路でも同じ）。本 verb は stale 検知の binding を残すのが役割で、レビュー品質の保証は Copilot/人が担う

関連 lib: `session.sh`（`oe_generate_session_id`）。バックエンド: `so-compare`（`OE_REVIEW_SO_COMPARE` で実体を上書き可）。VERDICT 抽出・集約は `oe-refute` から意図的に複製（共有 lib 化は follow-up）

---

## oe-delegate — 子セッション起動 + キック（親子委譲）

子 Claude を `tmux split-window` で起動し、タスク（または kickoff doc）をキック（spawn + send の合成）。

```bash
oe-delegate [-w WORKSPACE] [--kickoff <path>] [--label <#N|name>] [--claude-arg <arg>] [--] <task>
```

- `--kickoff <path>` … `"<path> を読んで進めて。"` を送り、doc のディレクトリを `--add-dir` で子に開示
- `--label <#N|name>` … registry 登録ラベル（後で `oe-send <label>` で指す）
- `--claude-arg <arg>` … 子 Claude 起動時に追加引数を渡す（repeatable）。例: `--claude-arg --permission-mode --claude-arg auto`
- tmux 内必須（`TMUX_PANE` から親ペイン取得、`PARENT_TMUX_PANE` を子へ継承）
- 子ペインは**親ペイン基準で split** する（`tmux split-window -t "$TMUX_PANE"`）。親が別ウィンドウを active にしている間に委譲しても、子は親のウィンドウに生える（`-d` は focus 移動の抑止のみ・#203）

関連 lib: `delegate-registry.sh`（キック注入は `oe-send` 経由）

## oe-kick — kickoff/issue 参照からのワンショット委譲ラッパー（#178）

`oe-delegate` の薄いワンショットラッパー。`#N`（or 素の番号）か kickoff パスを 1 引数で受け、妥当なフラグ列へ展開する（毎回フラグを組む手間を省く）。

```bash
oe-kick [-w WORKSPACE] [--claude-arg <arg>] [--] <#N|kickoff-path> [ad-hoc...]
```

- 既存ファイル → `--kickoff <path>` で渡し、ファイル名の `kickoff-<N>` から `--label '#N'` を自動導出（不検出はラベル無し）
- `#N` / `N`（数字のみ） → Issue 参照。`--label '#N'` 自動付与 + `"gh issue view N で確認して進めて"` の task を組む
- それ以外（非ファイル・非数値） → 曖昧回避のため明示エラー（exit 2）
- 末尾 ad-hoc（任意・1行） … issue 時は既定 task に連結、kickoff 時は task として渡す
- `-w WORKSPACE` 既定はカレント。tmux 内必須（`TMUX_PANE` 未設定は明示エラー）
- 注意: 番号名ファイル（例 `./178`）は file 優先で kickoff 扱い。Issue を指すなら `#178`

関連: `oe-delegate`（実体。`OE_DELEGATE_BIN` で差し替え可＝テスト seam）

## oe-send — 既存ペインへ 1 行を汎用送信

親→子の追送、子→親の戻し、関連の薄い側道会話を一手に担う送信口。

```bash
oe-send [--kickoff <path>] [--no-enter] [--] <target> [ad-hoc...]
```

- `<target>` … 生ペインID（`%N`）または ラベル（`#N` / 任意名。registry で解決）
- `--no-enter` … 投入のみ（ステージ＝人間が読んで Enter）
- 子→親の戻し: `oe-send "$PARENT_TMUX_PANE" "申し送り..."`
- payload は 1 行保証（改行は fail-fast で拒否）。自動 Enter 後に観測ベース finalize（`OE_SEND_FINALIZE=0` で無効）

関連 lib: `delegate-send.sh`（`oe_send_line`）/ `delegate-registry.sh`

## oe-list — 宛先候補の一覧

現サーバの生存ペインを source 列（pane-issue / spawn-registry / pane-title）付きで表示。`oe-send <target>` に渡すラベル / ペインID の確認用。

```bash
oe-list
```

関連 lib: `delegate-registry.sh`

## oe-select — 宛先をインタラクティブに選んで送信

`oe-list` と同一ソースの候補から fzf（無ければ番号 read）で 1 件選び、pane id を抽出して `oe-send` へ素通しする。既定で自ペインを候補から除外する。

```bash
oe-select [--print|-p] [--no-enter] [--include-self] [--kickoff <path>] [--] [ad-hoc...]
```

- `--print`, `-p` … 選んだ pane id を stdout に出して終了（送信しない）。`message` / `--no-enter` / `--kickoff` とは併用不可。例: `target="$(oe-select -p)" && oe-send "$target" "..."`
- `--include-self` … 自ペイン（`$TMUX_PANE`）も候補に含める（既定は除外）
- `--no-enter` / `--kickoff <path>` … `oe-send` へ素通し
- `ad-hoc...` … 送信メッセージ（無ければ端末から 1 行 read）。`--kickoff` 指定時は省略可
- 選択キャンセル（ESC / Ctrl-C / 空入力）は exit 130（送信も出力もしない）

関連 lib: `delegate-registry.sh`（送信は `oe-send` 経由）

## oe-jump — 通知/ラベルから対象 tmux ペインへ focus（#179）

`wez notify` の通知から、入力待ちの子ペインへ**ワンアクションで focus（activate）**する導線。**tmux substrate 専用**（#188: engine=wez 整数 / delegate=tmux `%N` の identity 分裂に対応）。`oe_reg_resolve` は常に tmux `%N` を返すので focus も tmux 経路（`select-pane` 系）に固定し、tmux 子へ `wez pane activate` を投げる誤ターゲットを構造的に排除する。wez（engine）ペインの focus は既存の `wez pane activate <id>` を使う（oe-jump の責務外）。

```bash
oe-jump [--print|-p] [--] [<target>]   # focus（target 省略時は直近 --record を replay）
oe-jump --record [--] <target>         # target を記録するだけ（通知連携・focus しない）
```

- `<target>` … tmux ペイン/ラベルを指す単一トークン:
  - `%N` … tmux ペイン（素通し）→ `tmux switch-client`/`select-window`/`select-pane`（ID 系 target）
  - `#N` / 任意名 … ラベル（`oe_reg_resolve` で tmux `%N` に解決。候補は `oe-list`）
  - 裸の整数（例 `5`）や `wez:N` は wez（engine）ペイン指しとみなして**拒否**し、`%N`(tmux) か `wez pane activate N`(wez) を案内する（silent な誤 focus を出さない）
- `--record <target>` … target を state（`~/.claude/state/oe-jump/last-target`・最後の1件・上書き）に記録。**通知連携規約（scope item 1）**の実装: 通知を撃つ側が記録し、人間は `oe-jump`（無引数）で直近の target へ飛ぶ＝真の 1 アクション。記録は token の**形だけ検証**し解決はしない（記録時に tmux/生存ペインを要求しない・解決は jump 時）。記録した token をそのまま解決するので「トースト表示文字列」と「解決契約」がズレない。
- `--print`, `-p` … 解決した tmux pane id（`%N`）を stdout に出して終了（focus しない・dry-run/検査用）
- exit: 0 成功 / 1 未解決・曖昧・ペイン無し・focus 失敗・replay 対象なし / 2 usage・環境エラー（tmux 不在）
- 通知発火そのもの（誰が・いつ撃つか）は #179 スコープ外（状態検出による自動発火 = #P2/agent-deck）。`wez notify` は前提・不改変。WezTerm のトーストはクリックで url を開くのみ＝コマンド直接起動は不可のため、focus は本コマンド経由（issue の「コマンド経由フォールバック」）。
- 既知制約: spawn-registry の任意名ラベルは spawn した親ペインからのみ解決可（`oe_reg_resolve` の parent スコープ）。pane-issue ラベル（`#N`）と `%N` 直接トークンはスコープ非依存。

設計の正本: [`../docs/discussions/2026-06-21-discussion-179-notify-pane-jump.md`](../docs/discussions/2026-06-21-discussion-179-notify-pane-jump.md)。関連 lib: `delegate-registry.sh`（`oe_reg_resolve`）/ 関連: [`../docs/decisions/2026-06-19-decision-188-identity-unification.md`](../docs/decisions/2026-06-19-decision-188-identity-unification.md)。

## oe-report — 親へ申し送り（legacy）

親ペインへ申し送り / レビュー依頼を送る。**legacy**: 戻しは `oe-send "$PARENT_TMUX_PANE"` に一本化が方針。

```bash
oe-report [--review] <message>
```

関連 lib: `delegate-send.sh`

---

## oe-status — cockpit 観測UI（read-only 俯瞰 + 監査ログ閲覧）(#177)

2 つの identity 空間（#188: engine=wez 整数 / delegate=tmux `%N`）を **join せず read 時に投影**する単一コマンド・typed sections の観測ツール。`oe-status` 1 回で 2 区画を出す:

- `=== ENGINE (wez · state/audit) ===`: engine session を **audit-terminal reducer** 由来の STATE 付きで一覧。STATE は `audit/{sid}.jsonl` の終端シグナルを **severity-max** で reduce する（末尾行ではない。`cleanup`/`verification_*` は除外）。**CB timeout は audit のみ・KVS 未書込のため audit から導く**（KVS だけだと取りこぼす）。state file があれば outputs/blockers を補足。
- `=== DELEGATE (tmux · liveness) ===`: `oe_reg_list` の生存ペインを **liveness のみ**で一覧（state/audit を持たない＝timeline:none）。tmux 不在時は degrade（engine 区画は出す）。

```bash
oe-status                       # 俯瞰（typed sections・既定・プレーン）
oe-status <session_id>          # 1 セッションの監査ログを時系列表示（start→end）
oe-status -i | --interactive    # fzf で行を選び preview（ENGINE=timeline / DELEGATE=meta）
oe-status -h | --help
```

- STATE 導出（precedence・severity-max worst 勝ち）: `circuit_breaker_triggered` reason=`timeout`/`verification_timeout`→`timeout`（verification_timeout は session 終端に寄与せず注記のみ） / reason=`max_turns`/`max_panes`→`blocked`（DI-4。`limit_type` フォールバックあり） / `session_end.state` / `interrupt`→`interrupted` / 終端無し+`session_start`→`running?` / それ以外→`?`。multi-pane でも blocked/timeout が success に隠れない。
- **read-only / 非検出**: 触れるのは (1) state/audit ファイル (2) tmux/wez ペイン存在（mux query）のみ。**ペイン出力は読まない**（polling 常駐・capture マーカー走査＝検出をしない）。preview は ENGINE=audit timeline 表示 / DELEGATE=registry メタのみ。
- DJ-4: `oe-refute.jsonl` / `oe-review.jsonl`（別スキーマ）は ULID 不一致で session 行に出ない（v1 対象外）。
- データ源は `OE_DATA_DIR`（または `OE_AUDIT_DIR` / `OE_STATE_DIR`）で上書き可。

設計の正本: [`../docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md`](../docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md) §8 / [`../docs/decisions/2026-06-19-decision-188-identity-unification.md`](../docs/decisions/2026-06-19-decision-188-identity-unification.md)。関連 lib: `delegate-registry.sh`（`oe_reg_list`）。

## oe-ident — ペインの識別子を read 時に投影（#202）

`pane-border-format` の `#()` から呼ばれ、指定ペインの**オーケストレーション識別子**を 1 行で返す read-only 表示用ヘルパ。`@oe_id` のような stored 状態を作らず、既存ソース（pane-issue / spawn-registry）を**読み取り時に投影**する（#188 の read 時相関・永続マップ不採用に整合・新規 write path 無し）。`oe_reg_list` / `oe_reg_resolve` の宛先解決契約には一切触れない。

```bash
oe-ident <pane_id> [server_pid]
```

- `<pane_id>` … 対象ペイン `%N`。不正/欠落でも **空出力・exit 0**（border を壊さない）
- `[server_pid]` … state キーの名前空間（tmux server pid）。省略時は `$TMUX` から導出。`#()` で TMUX env 不在に備え `#{pid}` を明示渡しできる
- 出力 `<role> <label>`: `role`=`parent`（子を spawn した）/`child`（自身が被 spawn）は spawn 関係がある時のみ前置。`label`=pane-issue の `#N slug` 優先 → spawn registry の label。識別情報の無いペインは **空行**（honest）
- 例: `parent #202 pane-identity` / `child #179` / `#204 toolkit`（spawn 関係なし） / （空）

**表示の有効化は dotfiles 側で opt-in**（hub は強制しない・責務境界）。推奨スニペット（`~/.tmux.conf` 等）:

```tmux
set -g pane-border-status top
set -g pane-border-format '#[align=left] #(/path/to/repo/projects/orchestration-engine/bin/oe-ident #{pane_id} #{pid}) '
```

- `#()` は tmux が**非同期実行しキャッシュ**（初回空・以降 `status-interval` 毎に更新）＝表示用途で問題なし。コマンドは小ファイル読みのみで高速。
- pane_title（Claude セッション名が書く所）は**無傷**＝二重 writer の奪い合いが起きない。

関連 lib: `delegate-registry.sh`（`_oe_reg_key` / pane-issue・spawn-registry の読取を共有）。設計経緯: [`../docs/discussions/2026-06-21-discussion-202-pane-identity.md`](../docs/discussions/2026-06-21-discussion-202-pane-identity.md)。

---

## 主要な環境変数

| 変数 | 用途 | 既定 |
|------|------|------|
| `OE_SEND_ENTER_DELAY` | 送信: リテラル送信 → Enter の小休止（秒） | `0.3` |
| `OE_SEND_FINALIZE` | 送信後 finalize の有効/無効（`0` で無効） | 有効 |
| `OE_SEND_FINALIZE_TIMEOUT` / `_INTERVAL` / `_STABLE` | finalize の settle 窓 / poll 間隔 / 終端安定回数 | `3` / `0.3` / `3` |
| `OE_SEND_SIGNAL_MISS` | oe-send: 未着候補（stage miss）検出時に rc4 へ昇格し手動フォールバックを表示（opt-in） | 無効（`0`） |
| `OE_DELEGATE_WAIT_SEC` | oe-delegate: 子 claude 起動待ち（秒） | `4` |
| `PARENT_TMUX_PANE` | oe-delegate が子へ渡す親ペイン（戻し用） | （自動） |
| `OE_JUMP_STATE_DIR` | oe-jump: `--record`/replay の state 置き場 | `~/.claude/state/oe-jump` |

本体エンジン側（`OE_POLL_INTERVAL` / `OE_CB_*` / `OE_TARGET_AI_*` / `OE_VERIFY_AI_*` 等）は [`../lib/constants.sh`](../lib/constants.sh) を参照。

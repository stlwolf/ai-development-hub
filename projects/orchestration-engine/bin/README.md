# bin/ — スクリプト索引

orchestration-engine の実行可能エントリの簡易リファレンス（AI エージェント / 人間向け）。背景は親 [`../README.md`](../README.md)、詳細は各スクリプト冒頭のコメントと `docs/` を参照。

scripts は役割別に次の 22 本（`bin/` 直下の実行可能エントリの全数。verb を足したらこの索引にも足す。本体エンジン と 親子委譲 CLI の 2 系統という切り口は [`../README.md`](../README.md) 「2 系統」節）:

- **本体エンジン**: `oe`（+ 補助 `oe-capture`）
- **SO ゲート**: `oe-refute`（設計SO・確定前の同期反証・#183） / `oe-review`（実装SO・reviewed diff にバインドしたコード欠陥レビュー・#195）
- **親子委譲 CLI（delegate-task 系）**: `oe-delegate` / `oe-kick` / `oe-send` / `oe-list` / `oe-register`（手動起動ペインの登記・#259） / `oe-select` / `oe-report` / `oe-ack`（受領印・#206A） / `oe-jump`（通知→ペインへ focus）
- **観測（cockpit・read-only）**: `oe-status`（engine state/audit + delegate liveness の俯瞰） / `oe-ident`（ペイン識別子を border へ read 時投影） / `oe-activity`（親子活動ログ `oe-events.jsonl` を read 時投影・report inbox（PENDING=未受領数）/ timeline・#206） / `oe-tree`（spawn トポロジの罫線ツリー・`--watch` live / `--pick` 対話ナビ・#221/#223/#227） / `oe-undelivered`（報告未達検知 watchdog・未ack 報告 × 時間窓・cron 可・#239 段階0） / `oe-vitals`（統括 vital 監視 watchdog・拍動鮮度 + context% 閾値・cron 可・#239 段階1） / `oe-selfcheck`（版に固定された前提の点検・3値判定・#299 P3） / `oe-hookfire`（止める側のフックの発火記録を読む・3値判定・#309）
- **doc 表示**: `oe-view`（md → viewer ペインで `glow` / 非 md → `open`・#210）

---

## oe — 本体エンジン（自律オーケストレーション）

1 サイクルの自律ループ（envelope→spawn→capture→verify→monitor）。非対話・wez + `claude -p`。

```bash
bash bin/oe "タスク記述"
bash bin/oe --task-file <path>
```

- `--task-file <path>` の異常系は暗黙にフォールバックせず、明示エラーを stderr に出して **exit 2**（usage エラー）で弾く（#99）。対象: パス未指定 / 不在パス / ディレクトリ / 非通常ファイル / 読めない（権限）/ **空ファイル**（空は既定タスクへ暗黙フォールバックしていた挙動を廃止）。

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

子 Claude を `tmux split-window` で起動し、タスク（または brief doc）をキック（spawn + send の合成）。

```bash
oe-delegate [-w WORKSPACE] [--brief <path>] [--label <#N|name>] [--claude-arg <arg>] [--] <task>
```

- `--brief <path>` … `"<path> を読んで進めて。"` を送り、doc のディレクトリを `--add-dir` で子に開示
- `--kickoff <path>` … `--brief` の deprecated alias（後方互換・#255）。新規は `--brief` を使う
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
oe-send [--brief <path>] [--no-enter] [--] <target> [ad-hoc...]
```

- `<target>` … 生ペインID（`%N`）または ラベル（`#N` / 任意名。registry で解決）
- `--brief <path>` … `"<path> を読んで進めて。"` を payload 先頭に付ける（旧 `--kickoff` は deprecated alias・#255）
- `--no-enter` … 投入のみ（ステージ＝人間が読んで Enter）
- 子→親の戻し: `oe-send "$PARENT_TMUX_PANE" "申し送り..."`
- payload は 1 行保証（改行は fail-fast で拒否）。自動 Enter 後に観測ベース finalize（`OE_SEND_FINALIZE=0` で無効）

### 到達の確認（#299）

送信のたびに相関 ID（nonce）を payload 末尾へ `[oe:<ULID>]` として載せる（`OE_SEND_NONCE=0` で無効）。受け手のセッションでは `UserPromptSubmit` hook（`canonical/hooks/scripts/oe-prompt-receipt.sh`）が、それを 1 ターンとして取り込んだ瞬間に `prompt_received` を追記する。**送信と受領を nonce で突き合わせる。** 鍵は送信ごとに一意なので原理的には 1 対 1 だが、**そう言えるのは read 側が nonce と宛先ペインの両方を見る場合に限る**（`oe-undelivered` はそうしている）。nonce だけを見ると、別のペインが同じタグを submit しただけで受領扱いになる。

- 受領印は**受け手の `$TMUX_PANE` に束縛される**。ただし取り違えが防げるのは、read 側がその束縛を照合する場合だけである。送信側の画面 scrape は使わない（実測で逆を指していた・#299 P0）。
- 言えるのは「そのセッションが 1 ターンとして取り込んだ」までである。読んだ・実行した、ではない（それは `report_received` / `oe-ack` の層）。
- **これは Claude Code の hook 契約への依存である。免疫があるとは言わない — 壊れ方がましだと言っている。** 失効した画面の目印は静かに嘘の値を出し続けたが、hook 契約が壊れた場合は印が出なくなる。
- **「ましだ」が成り立つ条件を書く。** (a) `oe-selfcheck` が**実行されること**（定期実行は未配線・下記）、(b) read 側が宛先ペインまで照合すること、(c) `.prompt` が取れない契約変更が診断へ残ること。いずれも実装してあるが、(a) は人が打つまで動かない。**そこが埋まるまで「marker よりまし」は条件付きの主張である。**
- **`oe-selfcheck` 自身に定期実行の配線が無い。** 壊れたことに気づく仕掛けを、気づかれないまま放置できてしまう。cron / launchd への登録は owner 環境依存なので本 issue では行わない（surface のみ）。
- `--no-enter`（ステージのみ）には nonce を載せない（`message_sent` を emit しないため、突き合わせ先の無い受領印を作らないため）。
- **副作用として payload が約 32 文字伸びる。** 長文はもともと入力欄で折り返すと finalize の照合が外れる（#299 で判明した機構）ので、境界付近の送信がわずかに折返し側へ寄る。P2-b（折返し対応）は owner 判断で採っていない。

**これで transport 凍結の再判定に必要な材料が揃う。** 2026-06-09 の「transport 据え置き」は「clean 環境で症状を再現できない → 比較計測が不能 → 賭けない」という三段の理由で決まった（`docs/plans/2026-06-09-plan-oe-send-ingestion-rootfix.md` §2〜§3）。受領印は実トラフィックでの取り込み率を出すので、**当時の三段目（比較計測が不能）の前提が崩れる。**

**前後比較に使う測定器はリポジトリに置いてある。** `scripts/measure-delivery-arrival.py` である。**前後比較は同一の測定器でなければ成立しない**（別々に書き直すと方法が変わって比較できなくなる）ので、方法をコードとして残してある。受領印は #299 以降の送信にしか付かないので、**transport 変更の「前」のベースラインを取れるのはこの測定器だけ**である（transcript が残っている限り過去へ遡れる）。使い方・環境依存・秘匿の境界はスクリプト冒頭の docstring に書いた。

**ただし「前後比較ができる」とまでは言わない。** 成立条件が3つある。(a) 旧 transport 側の受領印ベースラインが存在しない（「前」が無い。これから貯める必要がある）。(b) 受領印の欠落は transport 未達だけでなく、hook 未発火・契約変更・書き込み失敗・rotation・nonce 生成失敗とも混同する。(c) タグで payload が約 32 文字伸びるので、計測の導入自体が対象の挙動をわずかに変える。**替えるかどうかの判断は #299 の範囲外**（owner 判断で P1 の後）。

関連 lib: `delegate-send.sh`（`oe_send_line` / `_oe_send_nonce`）/ `delegate-registry.sh`

## oe-list — 宛先候補の一覧

現サーバの生存ペインを source 列（pane-issue / spawn-registry / pane-title）付きで表示。`oe-send <target>` に渡すラベル / ペインID の確認用。

```bash
oe-list
```

関連 lib: `delegate-registry.sh`

## oe-register — 自己 root 登記 / 既存 pane の委譲 link（#259）

手動起動した pane（spawn を経ないため registry に出ない）を登記し `oe-tree` / cockpit に現す。`root` で自分を root として、`link %N` で相手 %N を自分の下の子として登記する。

```bash
oe-register root [--label <#N|name>] [-w WORKSPACE] [--force]
oe-register link <%N> [--label <#N|name>] [-w WORKSPACE] [--force]
```

- `root` … 自ペイン（`$TMUX_PANE`）を `parent_pane=""` の root entry として登記（手動起動の統括を可視化）
- `link <%N>` … 相手 %N を自分の下の子として登記（spawn を経ない委譲関係の登記）
- guard（verb 側・横取り/事故防止）: `link` は target 非生存 / `%self`（self-cycle）/ 生存する別親の子 → 拒否（`--force` で reparent）・orphan は引き取り可・既に自分の子は冪等。`root` は生きた親を持つ委譲子の自己 root 化を拒否（`--force` で明示 re-root）
- `--label` は LF/CR を fail-fast 拒否。tmux 内必須（`TMUX_PANE`）・jq 必須
- 既存 verb・lib の write path（`oe_reg_record`）は無変更。本 verb はそれを呼ぶだけ（additive）

関連 lib: `delegate-registry.sh`（record/GC）。読取側 `oe-ident` / `event-bus.sh` の role 導出は「自 entry かつ parent_pane 非空」＝自己 root を `child` と誤導出しない（#259）

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

## oe-view — 生成 doc のクリッカブル md ビューア（#210）

パス（plan/kickoff/episode 等）から Finder/手動ペイン操作なしで即ビューする入口。**md（`*.md`・拡張子/大小無視）→ viewer ペインを解決して `glow` で描画 / 非 md → `open -- <path>`**。クリック層（WezTerm の `hyperlink_rules` + `open-uri`・dotfiles 別 PR）に**非依存で単体動作**する（`--here`/手動で即有用）。

配置（DJ-1）の根拠は **cockpit UX glue**（`wez pane` + `open` + 種別ディスパッチ）であり、`wez` は下層プリミティブのまま使う（ADR-001/004 の wez=下層方針を守る・上方依存を作らない）。viewer 解決ロジックは [`../lib/oe-viewer.sh`](../lib/oe-viewer.sh) に切り出す。

```bash
oe-view [--here] [--from-link] [--json] [--] <path>   # 既定: md→glow viewer / 非md→open
oe-view --help
```

- `<path>` … 表示対象のファイル（必須）。実体存在 + 通常ファイルを常に確認する。
- `--here` … 分割せず現ペインのページャで表示（md は `glow -p`、無ければ `bat`）。**degrade 本線**（tmux 非 wez / Cursor 統合ターミナル / dotfiles 未反映時）。
- `--from-link` … クリック経由フラグ。**allowlist 強制・非 md 拒否（md のみ）**を有効化（直叩きより厳格）。クリック経由で任意アプリ/スクリプト起動（非 md `open`）を許さない。
- `--json` … 結果を JSON で出力: `{status, kind:"md"|"other", action:"glow"|"open", pane_id?}`。
- viewer ペイン（DJ-4・argv-spawn replace モデル・§11） … **ペインのプログラムとして `glow` を直接起動**する（`wez pane split … -- glow -p -- <path>`・シェル/tmux 非経由）。実機検証で旧「split したシェルへ glow をタイプ送信」モデルが破綻（新規 wez ペインのシェル rc が tmux 自動アタッチしタイプ送信が実行されず描画されない）したため確定した方式。再利用は **replace**: state（`~/.claude/state/oe-view/viewer-pane-id`・`OE_VIEW_STATE_DIR` で隔離可）の viewer が生存（`wez pane list`）なら **kill → 新 glow ペインを spawn → state 更新** / stale・無しなら **spawn + state 更新**（glow `-p` はページャ＝シェルでないため send 再利用不可）。spawn 後は `wez pane activate <source>` で**作業ペインへ focus を戻す**（#111）。
- セキュリティ（§5・P0） … (1) **シェル注入面の構造的解消**: viewer 起動は `wez pane send`（受信シェルへタイプ→再トークナイズ）を廃し、path を `wez pane split … -- glow -p -- <path>` の **argv 要素**として渡す（シェルを一切経由しない）。再トークナイズが起きないため `printf %q` 不要・注入面が消滅（実在ファイル名 `a$(whoami).md` でも安全）。`glow -p` と `<path>` の間に `--` を置きパスがオプション解釈されないようにする。(2) **allowlist**: `--from-link` 時に `realpath` 正規化後 `OE_VIEW_ROOTS` 配下 prefix を判定（`..`/symlink トラバーサル対策）。(3) **入力サニタイズ**: 改行・CR・制御文字を含むパスを拒否。
- exit: `0` 成功 / `1` 対象不在・allowlist 外・サニタイズ違反・`--from-link` で非 md・glow/open 失敗 / `2` usage・**環境エラー（wez 不在・glow 不在を含む。依存不足は独立コードにせず `2` に統一し導入案内を出す）**。

3 段の degrade（環境に応じた表示経路）:

| 環境 | 表示経路 | 備考 |
|------|----------|------|
| WezTerm + `wez` + `glow`（dotfiles 反映済） | クリック or `oe-view <md>` → viewer ペインのプログラムとして `glow` を argv-spawn（replace モデル・focus は作業ペイン維持） | 本線。クリック層は dotfiles 別 PR |
| tmux 非 wez / Cursor 統合ターミナル / dotfiles 未反映 | `oe-view --here <md>` → 現ペイン `glow -p` | 手動・分割しない degrade 本線 |
| `glow` 未導入 | `oe-view --here <md>` → 現ペイン `bat` | bat フォールバック。両方不在は exit 2 + 導入案内 |

設計の正本: [`../docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md`](../docs/plans/2026-06-21-plan-210-oe-view-clickable-md.md)。関連 lib: [`../lib/oe-viewer.sh`](../lib/oe-viewer.sh)（viewer 解決・argv-spawn replace）/ 下層: [`../../wezterm-ai-mode/lib/pane.sh`](../../wezterm-ai-mode/lib/pane.sh)（`wez pane split`（trailing `-- PROG` パススルー）`/kill/activate`・`_wez_pane_exists`）。クリック層（`wezterm.lua` の `hyperlink_rules` + `open-uri`）は dotfiles 側の別 PR（hub は手順 doc のみ・lua 本体は置かない）。

## oe-report — 親へ申し送り（legacy）

親ペインへ申し送り / レビュー依頼を送る。**legacy**: 戻しは `oe-send "$PARENT_TMUX_PANE"` に一本化が方針。

```bash
oe-report [--review] <message>
```

送信は `oe_send_line`（`delegate-send.sh`）経由（#206A で生 `send-keys` から載せ替え・#142 の部分前倒し）。1 行保証・死ペイン検知・copy-mode 解除・finalize・`message_sent` emit が `oe-send` と同じに揃う — 載せ替え前はこの経路の報告が活動ログに載らず、inbox / 受領印（`report_received`）ループの盲点だった。

関連 lib: `delegate-send.sh`

---

## oe-ack — 自分宛て報告への受領印（#206A）

自分（`$TMUX_PANE`）宛てに届いた報告（`message_sent`）へ**受領印**（`report_received`）を打つ actor verb。viewer（`oe-activity`）は read-only 規律で emit できないため、「読んだ」の印は**受領した側のアクター**（AI が report 処理時 / 人間が inbox 確認時に `!` 経由）が明示的に打つ。

```bash
oe-ack <target>     # 相手（%N / ラベル。oe-send と同じ union 解決）からの自分宛て報告に受領印
oe-ack --all        # 自分宛て未受領のある相手すべてに per-relation で受領印
```

- **意味論（frontier snapshot）**: emit する `report_received` に `covers_count`（相手→自分宛て message の累計数）と `covers_last_ts`（カバーする最終 message の ts）を焼き込む自己完結レコード。viewer は `K = min(covers_count, |ts ≤ covers_last_ts|)` の先頭 K 件を received と投影（複数 ack は max・巻き戻りなし・同秒割込みは count cap で除外）
- **層分離**: ログ read・covers 計算・echo は本 verb（`oe-activity` と同じ read クラス）。`lib/event-bus.sh` の `oe_event_report_received` は引数のみの純 emit（emit primitive はログを読まない規約を維持）
- 未受領分が無ければ **no-op**（emit しない・exit 0）。emit 後は stderr に `acked N 件（累計 M）/ 最終: <ts> <preview>` を echo — **ack 直前に割り込んだ新着**が frontier に入るレース残余は防止せず、この echo で acker が即検証できる形で開示する
- 誤 ack の訂正手段は増分Aには無い（訂正 event は vocab additive で将来可能・影響は表示限定）。`oe-*` を通らない生 `send-keys` の報告は emit が無いため観測不能（既知の限界）
- ガード: `$TMUX_PANE` 必須（受領印は受領者ペインから）・自分自身への ack は拒否・jq 必須

関連: `lib/event-bus.sh`（純 emit）/ `schemas/oe-events.schema.json`（`covers_*` は `report_received` のみ必須）/ 表示は `oe-activity --inbox`（PENDING 列）・`--timeline`（ack 行）。

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

## oe-activity — 親子活動ログの read 時投影ビュー（#206 増分1+2+A）

`lib/event-bus.sh` が best-effort 追記する永続 append-only 活動ログ（`oe-events.jsonl`）を **read 時に投影**する read-only ビュー。各イベントは `from`/`to` の `{pane,role,label}` を emit 時に焼き込む自己完結レコードで、`session_id` を主キーにせず registry の生存にも依存しない（GC 後・子が消えた後も残る＝departed children も可視）。新規 write path は持たない（#188 read 時相関の思想に整合。受領印の emit は `oe-ack`）。

```bash
oe-activity            # 俯瞰: 親子関係ごとに 往復 / 配送 / 直近 preview / 子(送信元)生存
oe-activity --inbox    # report inbox: 自分(=$TMUX_PANE)宛の報告を送信元(子)ごとに（PENDING=未受領数）
oe-activity --timeline # 時系列: 関係内の各送信を turn 順に 1 行ずつ（kick も出る・受領印 ack 行を interleave）
```

- 出す情報は 5 つだけ（**lifecycle-end / stall は推論しない** ＝ DJ-188-2 尊重）:
  - `TRIPS` … 関係内の `message_sent` 数（往復回数）
  - `DELIVERY` … 直近 message の `delivery_signal`（`unknown`|`none`・`delivered` は名乗らない）
  - **【#299 注意】`MISS` 列と `suspected_miss` を未着の根拠に使わないこと。** 実測でこの値は配送失敗と**逆**を指していた（最も厳しい突合で `suspected_miss` 側 244/250=97.6% が到達確認・`none` 側 162/217=74.7%）。#299 P0 で書き込みは止めたが、**過去レコードには 342 件残っており本ビューはそれを数え続ける。** 到達を見るなら `oe-undelivered`（受領印基準・#299 P4）を使う。この列の是正は #299 のスコープ外（surface のみ）
  - `PREVIEW` … 直近 message 先頭 ~100 字
  - `LIVE` … 子(worker)ペインの mux 存在 query（`alive`|`gone`|`?`）。report の送信元＝子なので「報告者がまだ居るか」を honest に示す。ended/stalled の分類はしない（在る=alive / 無い=gone / tmux 不在=?）
  - `PENDING`（inbox・#206A） … 自分宛て message のうち**未受領**の数（0=すべて受領済み）。`report_received` の frontier snapshot（`covers_count`/`covers_last_ts`）から read 時導出: `K = min(covers_count, |ts ≤ covers_last_ts|)` の先頭 K 件が received・複数 ack は max K（単調・巻き戻りなし）。受領は推論しない — actor が `oe-ack` で打った印だけを数える
- モード: 既定の俯瞰と `--inbox` は **1 関係 = 1 行のサマリ**（直近 message + 往復数）。`--timeline`（#206 増分2）は **1 送信 = 1 行の時系列**で、関係内の各 `message_sent` を `TURN`（関係内の read 時導出位置）/ `TS` / `DIR`（`report`=子→親 / `kick`=親→子）/ `DELIVERY` / `RELATION` / `PREVIEW` で並べる（kick も含む・全体は古→新）。増分A で受領印（`report_received`）も `TURN="-"` / `DIR=ack` の 1 行として interleave する（preview に `covers=N ≤ frontier`）。turn はスキーマに焼かず read 時に `ts` 順で導出する。lifecycle-end / stall は推論しない点は俯瞰と同じ
- read-only / 非検出: 触れるのは `oe-events.jsonl` と tmux ペイン存在（mux query）のみ。ペイン出力は読まない（capture / polling しない）・書込なし
- degrade: `jq` 不在は件数のみ表示・`tmux` 不在は `LIVE=?`・ログ空は明示メッセージ（いずれも exit 0）
- 既知の制約（増分1）: liveness は現サーバの `tmux list-panes -a` 突合で別サーバのペイン ID は `gone` と出る。イベントは server pid を持たず **pane を関係キー**にするため、同一サーバで `%N` が再利用（pane 破棄後の再割当）されると別関係が同一 `%N` に混線し得る（TRIPS 過大・親/inbox 取り違え）。server-pid キー化は後続増分（DJ-188-4 拡張）へ defer。壊れた JSONL 行は read 時に黙ってスキップ（degrade）
- 既知の残余（増分A・受領印）: ack 直前に割り込んだ新着が frontier に入り得る（`oe-ack` の echo で開示）・誤 ack の訂正 event は未実装（additive で将来）・log rotation 導入時は ack/frontier 整合の保存が制約（rotation 増分へ申し送り）

関連: `lib/event-bus.sh`（emit プリミティブ・`oe-delegate` が `child_spawned` / `oe_send_line` が `message_sent` / `oe-ack` が `report_received` を発火）、`schemas/oe-events.schema.json`（レコードスキーマ・audit-log とは別系統）。設計判断は #188 DJ-188-4 を delegate 現実（session_id 不在）へ精緻化したもの。

## oe-tree — spawn トポロジの read-only ツリー表示 + live 表示 + 対話ナビ（#221 / #223 / #227）

spawn registry（`~/.claude/state/oe-delegate/`）の現 tmux server 分を走査し、`parent_pane` 連鎖から森林を再構成して罫線ツリーで表示する。`oe-list` が flat な宛先候補（自分の直下の子に scoping）なのに対し、oe-tree は「何が何を立てたか」「どのペインが孫か」を**現 server 全域**で描く観測ビュー（`oe-status` / `oe-activity` と同クラス）。`--watch` で poll 再描画の live 表示（tmux popup からの常用を想定・#223）。`--pick` でトポロジからノードを選び、そのペインへジャンプ + 最大化する対話ナビ（#227）。

```bash
oe-tree                      # 現 server の spawn 森林を罫線ツリーで表示（一発スナップショット）
oe-tree --watch              # live 表示（2s poll 再描画・q / Esc / C-c で終了）
oe-tree --watch --interval 5 # 更新間隔を変更（秒・正整数）
oe-tree --pick               # 対話ナビ: ノードを fzf で選び jump + 最大化（fzf 非在時は番号選択）
oe-tree -h                   # ヘルプ
```

出力例（各ノード: `<座標 win.pane|-> <pane> <liveness> <label> [~workspace] [(you)]`）:

```text
1.1   %124   alive  demo-infra
└─ 1.2   %125   alive  #901-topo ~demo-infra.docs-#901_demo-a
3.1   %119   alive  #206 increment2-timeline
└─ 3.2   %120   alive  #223 live-topology-viewer ~ai-development-hub (you)
-     %83    gone   ?
├─ 1.3   %94    alive  #36 ~demo-infra.infra-#901_demo-b
└─ 1.4   %85    alive  #902 ~demo-org.902-demo
```

- **スナップショット意味論**: 本ビューは「現在の登記」であり歴史ではない。gone entry は次の `oe_reg_record` 時の GC まで表示される（read-only ではデータ源の性質を変えられない）。spawn の**歴史**フローは `oe-activity`（event log・`child_spawned`）の領分（レイヤ分離）
- **座標の併記（DJ-223-11 + hg-2）**: 人間の導線 = tmux 座標（`window.pane`）を先頭列に置き、`%N` は `oe-send` / `oe-jump` / `oe-list` との**突合キー**として併記維持する。`session:` は **live ペインが複数セッションにまたがる時だけ自動で前置**（単一セッション運用では省く — 適応表示）。座標は liveness と同じ 1 回の `tmux list-panes -a` コールの format 拡張で取る（追加コストなし）。gone / 取得不能は `-`（tmux 上に存在しない pane に座標は無い — honest）
- **並び順（hg-2）**: root・兄弟とも**画面配置順**（session→window→pane の昇順）。座標を持たないノード（gone / query 不能）は末尾に pane 番号昇順 — gone root は子が alive でも座標が無いため末尾に回る（スナップショット意味論の帰結・正直な制約）
- **root 合成**: root 親は registry に entry を持たない（`parent_pane` 参照としてのみ現れる）ため合成する。ラベルは pane-issue > `pane_title`（alive のみ）> `?`（honest — 無い物を捏造しない。`oe-ident` と同方針）。子のラベルは pane-issue(.name) > registry(.label)（`oe_reg_list` と同優先順位）
- **role 列は持たない**: ツリーは関係そのものを描くため parent/child は木の形が搬送する（`oe-ident` が role を前置するのは単一ペインの孤立表示だから）
- **read-only / 非検出**: 触れるのは registry / pane-issue の state ファイルと tmux のペイン存在・座標・pane_title（mux query）のみ。`oe_reg_gc` 等の write path は呼ばない（#177 / #188 の read-only 観測規律）
- **出力 sanitize**: label / workspace / 座標の制御文字（C0 全域 + DEL + C1 = U+0000-001F / 007F / 0080-009F）を codepoint レベルで空白へ畳む。人間向け cockpit 表示のため ESC/CSI/OSC による偽行・画面消去・視覚偽装を遮断する（`oe_reg_list` の LF/CR 防御より広い — 表示ツールの脅威モデル）
- degrade / exit: liveness query 失敗は `?` で継続。`$TMUX` 不在は scoping も liveness も成立しない（部分価値を残す degrade が構造的に無い）ため stderr note + exit 2（`oe_reg_list` / `oe_reg_resolve` の rc=2 規約と一致。`--watch` 中は popup(-E) 即閉じ対策で TTY のときだけ 3s hold してから exit）。異 server の stale entry は非表示 + footer で件数開示。現 server の読めない/不正/重複 entry も無言で捨てず footer で skip 件数を開示（全滅時は `(no readable spawn entries ...)` — 「登記なし」と偽らない）。純粋 cycle（pane-id 再利用の理論ケース）は擬似 root で描画し `[cycle]` で打ち切り

### --watch（live 表示・#223）

tick ごとに自分自身（snapshot モード）を re-exec し、alt screen 上に `\e[H` + 本文 + `\e[J` で再描画する（全画面 clear のフリッカーなし・各フレームは一発実行と厳密に同一のコードパス）。終了は `q` / `Esc` / `C-c`。

- **read セットは snapshot と同一**: poll が反復するのは registry / pane-issue / ペイン存在・座標・pane_title の read だけで、「何を読むか」の線は動かさない（capture 走査・自動反応=検出には踏み込まない — `oe-status` DJ-1(c) が守った非検出境界との整合。将来の watch 系追加もこの線を参照点にする）
- **kill の反映**: alive→gone の遷移として数秒で映る。**ノードがツリーから消えるのは次 spawn の GC 時**（スナップショット意味論のまま — watch はデータ源の性質を変えない）
- **配置は非依存**: `--watch` はただの CLI なので popup / 常設ペイン / 専用 window のどこでも動く。推奨は floating popup（レイアウト面積を恒久消費しない）
- ループは逐次実行なので、登記が増えて 1 tick が interval を超えても遅延は累積しない（実効更新周期が伸びるだけ・バックログや暴走は構造的に起きない）。大規模時は `--interval` を伸ばす
- `(you)` マーカー: popup 内では `TMUX_PANE` が unset のため、watch 開始時に active pane（= popup を開いたペイン）を 1 回だけ解決して固定する。下記スニペットの `-e 'TMUX_PANE=#{pane_id}'` を使えば opener が正確に注入される（`run-shell` 経由のときだけ format が展開される点に注意 — `display-popup` 直書きでは展開されない）

**popup キーバインドは dotfiles 側で opt-in**（hub は強制しない・責務境界 = `oe-ident` #202 と同型）。推奨スニペット（`~/.tmux.conf` 等）:

```tmux
# oe topology live popup（例: prefix + T。キーは環境の空きに合わせる — tmux list-keys で衝突確認。
# 例の T は tmux 既定で未割当だが、picker 等の自前 bind と衝突しないキーを選ぶこと）
bind-key T run-shell "tmux display-popup -e 'TMUX_PANE=#{pane_id}' -E -x C -y C -w 70% -h 60% -T ' oe topology ' '/path/to/repo/projects/orchestration-engine/bin/oe-tree --watch'"
```

- `-x C -y C` は popup 枠を画面中央に置く明示指定（省略時も概ね中央 — 明示しておくと環境差の切り分けが楽）
- **中身はパネル中央に描画**（TTY 時のみ）: 描画ブロックの縦横を毎 tick 測り、パネル内の中央に置く（左上張り付きの是正 — hg-2）。パネルサイズは `stty size < /dev/tty` を一次にする（tmux popup 内では `tput cols` が実 pty を引けず 80×24 の fallback を返すため — 実測。stty は実サイズを返す）・失敗時のみ tput に fallback。幅は近似 wcwidth（ASCII / 罫線 = 1・その他 = 2）のため非 ASCII 記号混在ではやや左寄りになり得る。非 TTY（テスト・パイプ）は無加工・サイズ取得不能は pad 0 に degrade

- oe-tree は PATH 登録前提にしない（絶対パスで書く。PATH に通している環境は `oe-tree --watch` で可）。dotfiles にパスを書く運用コスト（リポジトリ移動で陳腐化）は #202 と同型の受容
- **toggle の意味論**: popup 表示中のキーは popup 内プログラムへ渡るため、tmux bind による「同キーで開閉」は構造的に不成立。開く=bind 1 キー / 閉じる=`q` or `Esc` 1 キーの 2 キー完結（hg-1 受入済み）。`display-popup -C` は別ペイン/スクリプトからの強制 close（rescue）。`-EE`（成功時のみ自動 close）は代替として存在するが、エラー保持は tool 側の 3s hold が配置非依存に同じ役割を果たすため既定にしない

### --pick（対話ナビ・#227）

トポロジ表示から**ノードを選んで、そのペインへジャンプ + 最大化**する（`prefix+g` の session picker のトポロジ版 + 最大化）。`--watch` が「見る」なら `--pick` は「見て飛ぶ」導線。**別コンポーネントを作らず oe-tree 自体に足す**（森構築/描画は既存ロジックの単一ソースのまま・jump は `oe-jump` 再利用・新規は fzf 選択 + `resize-pane -Z` だけ）。

```bash
oe-tree --pick   # 森ツリーを fzf に流す → 選択 → oe-jump で focus → 対象 window を最大化
                 # enter: jump+zoom / ctrl-r: refresh（森を取り直す）/ esc: cancel
```

- **候補生成**: 内部モード `--pick-list` が既存 render 経路そのままに `%N<TAB>表示行` を emit（森ロジックを複製しない・`--watch` の re-exec と同じ「一発実行と同一コードパス」）。`--pick` は自身を `--pick-list` で再帰起動して候補を取る。fzf は `--with-nth 2` で 2 列目（ツリー行）だけを見せ、`%N` は隠しキー。`ctrl-r` は `--pick-list` を再実行して森を取り直す
- **jump は `oe-jump` 再利用**: 選んだ `%N` を `oe-jump -- %N` に渡す（`switch-client`/`select-window`/`select-pane` 権威・別 window/session 跨ぎ対応）。jump ロジックは複製しない
- **zoom（新規）**: jump 成功後、対象 window が未 zoom のときだけ `resize-pane -Z -t <pane>` で最大化する（**対象ペイン指定** — 無指定だと popup / 現 window を掴む）。既に zoom 済み（`#{window_zoomed_flag}`=1）なら**再 `-Z` しない**（トグルで解除される事故を防ぐ・冪等）。単一 pane window は `-Z` が無害な no-op
- **read-only は維持**: jump/zoom は registry / トポロジ**データを編集しない**（#221/#223 のデータ read-only 不変条件は保たれる）。jump+zoom は**ユーザーが明示的に命じるナビ**＝受動検出でも自動作用でもなく、`prefix+g` picker が `select-pane` するのと同カテゴリ（非検出境界の本旨に反しない）。純ビュー（引数なし / `--watch`）はデフォルトで温存
- **gone / jump 失敗**: 候補には残す（ビューと一貫・gone 表示自体が情報）。選んで `oe-jump` が失敗（gone/未解決）すると、理由を一瞬出して（TTY のとき 3s hold）**picker に戻る**（exit せずループ・#227 hg 追修正）。失敗のたびに popup が閉じないので別ノードを選び直せる。候補は戻るたび取り直す（最新化）
- **fzf 非在**: 番号フォールバック（`oe-select` 同型 — 候補を番号付きで出し `/dev/tty` から番号 read。木の形は番号前置で保つ）。空入力 / EOF = cancel(130)・非数値 / 範囲外 = 2
- degrade / exit: 0=jump+zoom 成功 / 1=候補なし（空森）・zoom 失敗（jump 済みで部分成功を偽らない）/ 2=usage・fzf 自体のエラー・番号 fallback の不正入力 / 130=cancel（Esc・空・EOF）。**jump 失敗（gone/未解決）は exit せず picker に戻る（ループ）**。`--pick` と `--watch` は併用不可

**popup キーバインドは dotfiles 側で opt-in**（hub は強制しない・責務境界 = `oe-ident` #202 / `--watch` の bind と同型）。`--watch`（観測）を別キー、`--pick`（ナビ）を別キーに割り当てる想定。推奨スニペット（`~/.tmux.conf` 等）:

```tmux
# oe topology pick popup（例: prefix + v。キーは環境の空きに合わせる — tmux list-keys で衝突確認）
# fzf を popup 内で動かすため -E。選択後は jump+zoom して自然クローズ。
# 直 display-popup（run-shell を使わない）: run-shell はコマンド出力を別ビューで表示するため、失敗系
# （Esc/gone で非 0 exit や stderr）で余計なペインが一瞬出る（#227 hg で実測・撤去）。TMUX_PANE は
# oe-tree が popup 内で display-message から自己解決するので -e 注入も不要。
bind-key v display-popup -E -x C -y C -w 70% -h 60% -T ' oe pick ' '/path/to/repo/projects/orchestration-engine/bin/oe-tree --pick'
```

- `(you)` マーカーは oe-tree が popup 内で `display-message` から active pane を自己解決する（`--watch` と同じ・#223）。run-shell + `-e` 注入は失敗系で別ビュー表示を招くため使わない（#227 hg）
- bind の実適用は本 PR 外（dotfiles / 環境側）。hub は推奨スニペットを doc で示すに留める（#202/#223 と同じ hub/dotfiles 分界）

- follow-up（未実装・surface のみ）: `--json` 出力 / gone root ラベルの event-log 補完 / ラベル解決の共通 read ヘルパ化 / 汎用 `oe-watch` verb（他の観測 view の live 化）/ status-line 向け要約（`--summary`）/ **`--watch` から 1 キーで `--pick` を起動する glance→pick 統合（設計SO 由来・popup 相互作用が絡むため `--pick` を土台に additive に足す別 concern）**

関連 lib: `delegate-registry.sh`（`_oe_reg_server_pid` / `_oe_reg_key`・read ヘルパのみ使用）。隣接 verb: `oe-jump`（jump 再利用先）/ `oe-select`（fzf・番号 fallback の同型元）。

---

## oe-undelivered — 報告未達検知 watchdog（#239 段階0・read-only・cron 可）

子→親の報告（`message_sent`）のうち、親が受領印（`report_received`・#220/#206A）を打っておらず（未ack）、かつ最古の未ack報告が**時間窓 W を越えた**ものを検出し、owner に ping する read-only 観測 verb。統括死亡 / send 無言失敗で報告が虚空へ消える経路（#239 mode3・チャネル脆弱）を、**#220 の frontier（未ack）＋時間次元**で決定論的に拾う（ペイン出力は capture しない）。

```bash
oe-undelivered                        # 既定: shadow（通知しない）・gone も出す・窓 30 分
oe-undelivered --window 3600          # 窓を 1 時間へ
oe-undelivered --notify               # owner へ ping する（既定は撃たない）
oe-undelivered --alive-only           # 相手が生存している行だけに絞る
oe-undelivered --start-after now      # この実行だけ起点を今に置く
oe-undelivered --set-start-after now  # 起点を保存する（過去は消さない・0 で全期間に戻る）
oe-undelivered -h | --help
```

**#299 で判定と単位を変えた。** 変更点は4つある。

- **判定を受領印基準にした（P4-3）。** 「未ack」だけでなく「受け手側の取り込み印（`prompt_received`）が無い」を見る。nonce を載せていない送信は判定できないので `RECEIPT=判定不可` と出し、**未着とは呼ばない。**
- **単位を関係からメッセージへ移した（P4-4）。** 旧実装の抑止キーは `<child>|<parent>|<最古未ackのts>` で、ack が来ない限りこの ts が動かないため、**同じ関係で新しく未達が起きても通知が出なかった。** メッセージ単位にした。**ただし「再飽和しない」と言えるのは、ログが安定していて（rotate されず）単一実行の間だけ**である。抑止キーはログ内の index を含むので、rotate 後は同じメッセージの index が変わりうる。並行実行の排他も無い。
- **既定を shadow にした（P4-2）。** stdout には出すが owner へは通知しない。何が鳴るかを先に見てから `--notify` を足す。
- **相手が消えている行は既定で出す（P4-5 は実装時に判断を変えた）。** plan は「生存している相手だけに絞る」と書いていたが、**それはこの verb の主目的を隠す**。検出したいのは「統括が死んで報告が虚空へ消えた」経路（#239 mode3）で、そこでは親ペインがまさに gone になるからである（実装SO codex 指摘）。ノイズ制御は起点（`--start-after`）で行い、狭く見たいときだけ `--alive-only` を打つ。liveness が判定できない（tmux 不在）行は落とさない。
- **観測の起点を持てるようにした（P4-1）。** 過去のイベントは消さず、`start-after` の目印だけを置く。`--start-after 0` でいつでも全期間へ戻せる。
- **`MISS` 列を廃止した。** `suspected_miss` は実測で配送失敗と逆を指していたので、判定にも表示にも使わない。

**`判定不可` は owner ping に載せない。** 未着と呼ばないと決めた対象を鳴らすと、また判別力の無い警報になる（stdout には出す）。

**依然として捕まらないもの（開示）**: 親→子の kick は対象外である（判定が報告方向に限定されている）。ゲートの母集団も見ない。これは #299 のスコープ外で、plan がそう決めている。

- **検知（2条件）**: `pending>0`（未ack）かつ `age = now - 最古未ack報告の ts > W`。`$TMUX_PANE` に依存せず**全 (child→parent) ペアを横断**する（`oe-activity --inbox` の self 中心と違う）。親子の向きは `child_spawned` / `report_received` / role / known-parent の複合で解決し、departed で role 空になる子（mode3 主対象）も取りこぼさない。
- **frontier**: `oe-ack` / `oe-activity` と**同一の read 規則**（`K = min(covers_count, |ts ≤ covers_last_ts|)`・複数 ack は max・巻き戻りなし）。ack ループ本体は再構築しない（`report_received` を consume）。
- **出力**: stdout に全件（cron ログ / 手動確認の durable signal）。owner ping は `--notify` 指定時のみ `wez notify`（best-effort）。**二重通知抑止**: verb 固有の seen cache（`${OE_EVENT_DIR}/oe-undelivered/seen`・キー `<child>|<parent>|<ts>|<idx>`＝**メッセージ単位**）に無い新規キーのみ notify。cache は verb 自身の bookkeeping で engine state ではない。
- **read-only / 非検出**: 触れるのは `oe-events.jsonl` と tmux ペイン存在（mux query）のみ。engine state（events/registry/session-state）は mutate しない。exit は常に 0（observer）・usage エラーのみ 2。
- **cron 例**（登録は owner 環境依存・自動化しない）: `*/15 * * * * /path/to/oe-undelivered >> "$HOME/.claude/state/oe-undelivered/cron.log" 2>&1`。cron 間隔と W は独立に調律する。
- **注記**: `wez notify` の cron（no TTY / mux socket）到達性は未検証 → stdout が durable な signal。frontier read 規則は `oe-ack` / `oe-activity` に続く3つ目の copy（共有 lib 統合は follow-up）。

関連: `schemas/oe-events.schema.json`（`report_received` の `covers_*`）/ `bin/oe-ack`（受領印の writer・`_ack_scan`）/ `bin/oe-activity`（PENDING の reader・`received_of`）。

---

## oe-selfcheck — 版に固定された前提の点検（#299 P3・read-only）

外部の版に固定された前提が今も成り立つかを見る read-only 検査。何も書き換えない。

**なぜ要るか。** #144 は「処理中の画面に `esc to interrupt` が出る」ことを 2026-06-09 の実機 capture で確かめ `verified` として計画書に記録した。ところが claude の更新でこの文字列は消え、**判定は静かに嘘の値を出し続けた。** #299 で実測するまで約2か月、誰も気づかなかった。同じ形の依存を一覧にして、崩れたら気づけるようにする。

```bash
oe-selfcheck          # 表形式（broken が1つでもあれば exit 1）
oe-selfcheck --json   # 機械可読
```

**判定は3値である。** ここが本 verb の肝で、`ok` / `broken` に加えて **`indeterminate`（検査自体が成立しなかった。`ok` ではない）** を持つ。「0 件だったから異常なし」と読ませないためである。各検査は**同じ経路で陽性を1つ示せるか**を先に見て、示せないときは `ok` を名乗らない。

| 検査 | 見るもの | 陽性対照 |
|---|---|---|
| `screen-marker` | 処理中の目印が finalize の走査窓（画面下3行）に入りうるか | 入力欄を持つ生存ペインが1枚以上。目印は入力欄より上に描かれるので、入力欄が下3行に在れば idle/busy に依らず「届かない」と決定論的に言える |
| `hook-contract` | 受領印 hook が配線され、実際に印を出しているか | nonce 付きの送信が1件以上。送信が無ければ受領印 0 件を異常と読めない |
| `transcript-format` | 受け手の記録から `promptSource=typed` を取り出せるか | 最新 transcript から1件以上 |
| `pane-session-bridge` | heartbeat sidecar が pane を持つか | sidecar が1件以上 |
| `retention-horizon` | 受け手側の記録をどこまで遡れるか | 値の報告のみ（良し悪しを判定しない） |

**この検査は「気づく」だけで「直す」ことはしない。** また検査自体も同じ版依存を持つので、免疫があるとは言わない。

関連: `canonical/hooks/scripts/oe-prompt-receipt.sh`（受領印 hook）/ `bin/oe-undelivered`（受領印を消費する側）/ `lib/delegate-send.sh`（nonce の払い出し）。

---

## oe-hookfire — 止める側のフックの発火記録を読む（#309・read-only）

止める側のフック3本（`block-destructive` / `block-force-push` / `cc-lint`）が直近の窓で発火したかを見る read-only 検査。何も書き換えない。

**なぜ要るか。** この3本は発火したことを1行も記録していなかった。そのため強制点が本当に効いたかを当事者以外が確かめる手段が無かった。3本が tally を書くようになったので、本 verb はそれを読んで判定する。

```bash
oe-hookfire              # 表形式
oe-hookfire --days 30    # 窓を 30 日へ（既定 7）
oe-hookfire --json       # 機械可読
```

**判定は3値である**（`oe-selfcheck` と同じ契約）。`ok` / `broken` に加えて **`indeterminate`（検査自体が成立しなかった。`ok` ではない）** を持ち、判定ではなく値を報告する行は `info` で出る。

- **累計で `ok` を出さない。** tally は「1バイト以上あり、かつ mtime が窓の中」のときだけ `ok` にする。サイズ 0 を発火と読むと touch / truncate で緑になるためである。`deny.jsonl` と `diag.jsonl` は**行の ts** で窓を切る（ファイルの mtime で切ると、大昔の1件が今日の別イベントで蘇る）。
- **「記録が 0 件」を「発火しなかった」と読まない。** 未配備・エージェントが Bash を使っていない・trust されず silent skip、のどれでも 0 になる。区別できるのは意図的に撃つプローブだけなので、陽性対照の手順と併せて読む。
- 記録先は `HOOK_FIRING_DIR`（既定 `~/.claude/state/hook-firing`）。期待するツール軸は `OE_HOOKFIRE_TOOLS`（既定 `claude cursor codex`）で、軸が丸ごと欠けた場合を `indeterminate` として出す。窓の既定日数は `OE_HOOKFIRE_DAYS`。
- exit は `broken` が1つでもあれば 1 / `broken` は無いが `indeterminate` が在れば 2 / 全部 `ok` なら 0。**`indeterminate` を exit 0 にしない。**
- **前回との比較（サイズ後退の検出）は行わない。** それには読み出しが状態を持つ必要があり、本 verb は read-only を保つ側に倒した。単発で分かるのはサイズ 0 までである。
- **この台帳の値打ちは、読み手が実際に走ることに条件付けられている。** 定期実行の配線は #301 で未着手で、人が打つまで動かない。bin sync の配布対象には入れたので、sync 実行後は `oe-hookfire` の名前で打てる。

関連: `canonical/hooks/README.md`（3本の記録契約と陽性対照の手順）/ `bin/oe-selfcheck`（同じ3値契約の姉妹 verb）。

---

## oe-vitals — 統括 vital 監視 watchdog（#239 段階1・read-only・cron 可）

statusLine 拍動 producer（PR-A・`canonical/claude/statusline/statusline-oe-heartbeat.sh`）が session 毎に書く sidecar（拍動 = `{ts, context_pct, pane}`）を **out-of-session cron から読み**、統括 session の **context% 肥大接近**（mode1 context 肥大死＝#238 中核）と **プロセス死**（pane 消滅）を検知して owner に ping する read-only 観測 verb。段階0 `oe-undelivered` の family（seen cache dedup / `wez notify` best-effort + stdout durable / exit 0 / `--window` + env + `NOW_EPOCH`）を踏襲する。**入力面は別**（`oe-undelivered` は oe-events.jsonl の frontier、本 verb は sidecar dir）。

```bash
oe-vitals                          # 既定 W=1800s / T=85% で統括 vital を判定し owner ping
oe-vitals --window 3600            # 拍動 staleness 窓 W を 1 時間へ
oe-vitals --threshold 90           # context% 閾値 T を 90 へ
oe-vitals -h | --help
```

- **2 検知器**: (1) **context**（`beat fresh + pane ¬gone + context_pct > T` → handoff 促し・#238 中核）(2) **death**（`pane が tmux 確定 gone` のときのみ・beat 鮮度非依存 → crash 疑い）。`alive/? × stale` は no-op（生存/不明を死に化かさない・hang 誤検知を実装しない）。**tmux 不在時は death 検知不可・context のみ degrade 動作**（偽陽性を出すより安全側）。
- **統括スコープ化（board 突合）**: sidecar dir には statusLine を持つ全 session の beat が入るため、board（declared 層・PR-C）の `現統括` pane（`現統括:` 宣言行の最初の `%NNN`・見出し併記は除外）と sidecar の `pane` を突合し、現統括の sidecar だけを判定する。board path は `OE_BOARD_FILE` で与える（machine-local・既定なし）。**未設定 / 未解決 / 現統括 pane の sidecar 不在 → no-op**（未設定を「死」に化かさない）。orderly handoff 後は board の `現統括` が後任へ進み前任は scope 外＝想定内 handoff は ping しない（`gone × declared` のみ crash 疑い）。
- **出力**: stdout に FLAG（cron ログ / 手動確認の durable signal）。owner ping は `wez notify`（best-effort）。**二重通知抑止**: verb 固有 seen cache（`${OE_EVENT_DIR}/oe-vitals/seen`・キー `<kind>|<session_id>`・通知成功時のみ追記。producer の sidecar dir `oe-heartbeat/` とは別 namespace）。
- **read-only / 非検出**: 触れるのは sidecar dir / board / tmux ペイン存在（mux query）のみ。producer の sidecar は **GC しない**（削除しない＝read-only 観測姿勢）。exit は常に 0（observer）・usage エラーのみ 2。
- **cron 配線**（登録は owner 環境依存・自動化しない）: verb 単体では回らない。周期実行の crontab / launchd エントリ設置は deployment 手順で、段階0 `oe-undelivered` と同じ out-of-session cron に相乗りする。`OE_BOARD_FILE` を必ず設定すること（board 突合の前提）。例:

  ```
  */15 * * * * OE_BOARD_FILE="$HOME/path/to/.oe/START-HERE-board.md" /path/to/oe-vitals >> "$HOME/.claude/state/oe-vitals/cron.log" 2>&1
  ```

- **既知の制約 / 運用前提**（開示）: board 突合は sidecar の `pane` が埋まっている前提（producer の `$TMUX_PANE` 伝播依存・PR-A は session_id 主キーで pane は best-effort）。未伝播なら scope できず no-op（sidecar が全て pane 空なら明示 warn）。実 board は PR-C schema へ未 migrate でも現行 freeform 行に対応。`wez notify` の cron 到達性は未検証 → stdout が durable signal。follow-up: board が `session_id` を declare（pane 非依存化）/ context の再 ping interval / inert 時の config-health ping。

関連: producer `../../../canonical/claude/statusline/statusline-oe-heartbeat.sh`（sidecar 契約の正本）/ board schema `../scripts/validate-board.sh`・`../docs/decisions/2026-07-10-decision-238-board-schema.md`（`現統括` declared 層）/ template `bin/oe-undelivered`（read-only 観測 family）。

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
| `OE_VIEW_ROOTS` | oe-view: allowlist 許可ルート（コロン区切り。`--from-link` 時に強制） | 各プロジェクトの `projects/*/docs` のみ（クリック境界を doc に限定。該当無しなら空＝fail-closed） |
| `OE_VIEW_STATE_DIR` | oe-view: viewer pane id の state 置き場 | `~/.claude/state/oe-view` |
| `OE_EVENT_DIR` | 活動ログ（#206）の置き場（`oe-events.jsonl`）。emit / oe-activity / oe-ack 共通 | `~/.claude/state` |
| `OE_EVENT_LOG` | 活動ログ emit の有効/無効（`0` で kill-switch） | 有効 |
| `OE_EVENT_PREVIEW_MAX` | message_sent の preview 切り詰め codepoint 数 | `100` |
| `OE_UNDELIVERED_WINDOW_SEC` | oe-undelivered: 報告未達とみなす時間窓 W（秒）。`--window` が優先 | `1800`（30分） |
| `OE_UNDELIVERED_NOW_EPOCH` | oe-undelivered: now（epoch 秒）の上書き。主にテストの age 決定論化用 | （`date +%s`） |
| `OE_VITALS_WINDOW_SEC` | oe-vitals: 拍動 staleness 窓 W（秒）。`--window` が優先 | `1800`（30分） |
| `OE_VITALS_CONTEXT_THRESHOLD` | oe-vitals: context% 閾値 T（0-100 整数）。`--threshold` が優先 | `85` |
| `OE_VITALS_NOW_EPOCH` | oe-vitals: now（epoch 秒）の上書き。主にテストの鮮度決定論化用 | （`date +%s`） |
| `OE_BOARD_FILE` | oe-vitals: 統括スコープ化に使う board（`現統括` pane を含む）の path。未設定なら scope 不能で no-op | （なし） |
| `OE_HEARTBEAT_DIR` | oe-vitals が読む sidecar dir（**producer PR-A と共有**の env ノブ） | `~/.claude/state/oe-heartbeat` |

本体エンジン側（`OE_POLL_INTERVAL` / `OE_CB_*` / `OE_TARGET_AI_*` / `OE_VERIFY_AI_*` 等）は [`../lib/constants.sh`](../lib/constants.sh) を参照。

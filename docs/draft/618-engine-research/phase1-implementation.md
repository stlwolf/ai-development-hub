# issue #618 フェーズ1 事前リサーチ: orchestration-engine の実装の現在地

- 調査日: 2026-11-10。対象は作業ツリーの現物（リポジトリは shallow clone で、履歴からの裏取りはしていない）
- リポジトリは変更していない。テストは実行した（一時ディレクトリと偽の HOME の中で動き、実行後の `git status` は空）
- パスの書き方: 接頭辞なしは `projects/orchestration-engine/` からの相対。`canonical/` と `scripts/sync/` はリポジトリ直下から
- 「推測」と書いた行は、コードやコメントから直接は確かめていない読み

## 0. 先に結論（見取り図に効く5点）

1. engine は README の言う「2系統」ではなく、実質 **3つの世代が同居** している。(a) wez + 非対話 CLI の本体エンジン（`oe run`・2026-05 の MVP）、(b) tmux `send-keys` の親子委譲と、その上に積んだ観測・見張り、(c) lease の記録による identity（#577・移行中）。(a) は (b)(c) と lib をほぼ共有しない
2. 行数の重心は「委譲そのもの」ではなく **統括の交代・復帰・lease**（bin 2,284 行 + lib 1,738 行）と **到達確認・見張り**（bin 2,414 行）にある。送る本体（`oe-send` 152 行 + `lib/delegate-send.sh` 322 行）は小さい
3. identity の正本が **registry（ペイン番号）と lease（自前 ID）の二重書き** のまま止まっている。読む側は lease を先に引き、引けなければ registry に落ちる。既定の表示の切替は未実施（`bin/README.md:635`）
4. 見張り3本（`oe-confirm` / `oe-undelivered` / `oe-vitals`）と点検2本（`oe-selfcheck` / `oe-hookfire`）は **定期実行の配線がリポジトリに無い**。launchd のテンプレートがあるのは `oe-confirm` だけで、導入は手作業5手順。残りは「人が打つまで動かない」と自分で書いている
5. 環境への縛りは強い。tmux・WezTerm・Claude Code の hook 契約と TUI の画面文字列・macOS（launchd / BSD stat / bash 3.2）・jq。この Linux の sandbox でテスト 53 本中 9 本が赤になる（原因の大半は root 実行と GNU/BSD 差）

## 1. 機能の地図

### 1.1 verb ごとの表（29 本・行数は `wc -l` の実測）

テスト列の数字は、今回この環境で実行したときの assertion の PASS/FAIL。

| verb | 行数 | 何をするか | source する lib | 対応テスト |
| --- | --- | --- | --- | --- |
| `oe` | 160 | 入口。`oe <verb>` を同じディレクトリの `oe-<verb>` に `exec`（`bin/oe:2`） | なし | `test_oe_entry.sh`（108/0）・`test_oe_entry_identity.sh`（15/1） |
| `oe-run` | 149 | 本体エンジン。envelope→spawn→monitor→verify の1サイクル（`bin/oe-run:122-146`） | constants / session / envelope / spawn / capture / audit / verify / monitor / cleanup（`bin/oe-run:11-27`） | 専用なし。`test_e2e_smoke.sh`（56/0）・`test_oe_task_file.sh`（18/0） |
| `oe-capture` | 114 | 既存ペインに attach して終端マーカーを読む | constants / session / capture / audit / attach（`bin/oe-capture:21-29`） | 専用なし。`test_attach.sh`（31/0） |
| `oe-delegate` | 432 | 子 claude を `tmux split-window` で起こし、`oe-send` でキック。elevated 承認ダイジェスト（#262）も持つ | delegate-registry / event-bus / lease（`bin/oe-delegate:26-34`） | `test_oe_delegate.sh`（61/0） |
| `oe-kick` | 119 | `#N` か kickoff パスを `oe-delegate` の引数へ展開 | なし（`oe-delegate` を呼ぶ） | `test_oe_kick.sh`（29/0） |
| `oe-send` | 152 | 既存ペインへ1行送る。`--to-parent`・lease から宛先を引いて本人確認 | delegate-send / delegate-registry / lease / target-resolve（`bin/oe-send:21-27`） | 専用なし。`test_delegate_send.sh`（54/0）・`test_target_resolve.sh`（53/0） |
| `oe-report` | 64 | 親へ申し送り（legacy・`PARENT_TMUX_PANE` だけから引く） | delegate-send | `test_oe_report.sh`（19/0） |
| `oe-ack` | 194 | 自分宛て報告への受領印 `report_received` を打つ | event-bus / delegate-registry | `test_oe_ack.sh`（46/0） |
| `oe-list` | 21 | 宛先候補の一覧 | delegate-registry | 専用なし。`test_delegate_registry.sh`（38/0） |
| `oe-select` | 210 | fzf で宛先を選んで `oe-send` へ | delegate-registry / lease | `test_oe_select.sh`（35/0） |
| `oe-jump` | 221 | ラベルや lease から tmux ペインへ focus。`--record` で直近 target を保存 | delegate-registry / lease / target-resolve | `test_oe_jump.sh`（38/0） |
| `oe-register` | 303 | 手動起動ペインの root 登記 / 既存ペインの link | delegate-registry / lease / event-bus / session-title | `test_oe_register.sh`（48/0） |
| `oe-lease` | 259 | lease の create / bind / whoami / resolve / show / close / gc / adopt | lease / delegate-registry / event-bus | 専用なし。`test_lease.sh`（136/0）・`test_lease_writers.sh`（52/0）・`test_lease_observe.sh`（25/2） |
| `oe-handoff` | 1,410 | 統括の計画的な交代（prepare / start / take / retire） | handoff-state / seat / event-bus / lease / session-title（`bin/oe-handoff:35-44`） | `test_handoff_prepare.sh`（79/2）・`_start`（9/0）・`_take`（143/0）・`_retire`（200/0）・`test_lease_handoff.sh`（78/0） |
| `oe-recover` | 615 | 応答しない統括が resume 後に打つ復帰。`hint` は読むだけ | lease / seat / delegate-registry / event-bus | `test_oe_recover.sh`（122/3） |
| `oe-tree` | 804 | spawn の木（registry）・`--watch`・`--pick`・`--lease` | delegate-registry・`--lease` のときだけ lease（`bin/oe-tree:80,157`） | `test_oe_tree.sh`（87/1） |
| `oe-threads` | 298 | 生存ペインごとのモデル名と context% | delegate-registry / heartbeat-resolve | `test_oe_threads.sh`（68/4） |
| `oe-status` | 314 | ENGINE（audit の終端状態）と DELEGATE（生存）の俯瞰 | delegate-registry | `test_oe_status.sh`（27/0） |
| `oe-ident` | 91 | tmux の `pane-border-format` 用の1行識別子 | delegate-registry | `test_oe_ident.sh`（14/0） |
| `oe-activity` | 288 | `oe-events.jsonl` の read-only 投影（俯瞰 / inbox / timeline） | なし（自前の jq） | `test_oe_activity.sh`（101/0） |
| `oe-confirm` | 621 | 送信1件ごとの到達照合（nonce と宛先ペイン）＋ペイン消滅＋report 新規。常駐可 | なし | `test_oe_confirm.sh`（79/0） |
| `oe-undelivered` | 419 | 子→親の報告が未 ack のまま窓を越えたものを検知 | なし | `test_oe_undelivered.sh`（80/0） |
| `oe-vitals` | 474 | 統括の context% 超過とプロセス死を検知 | seat（`bin/oe-vitals:86`） | `test_oe_vitals.sh`（77/0） |
| `oe-selfcheck` | 389 | バージョンに縛られた前提6件の点検（3値判定） | なし | 専用なし。`test_prompt_receipt.sh`・`test_oe_confirm.sh` などが呼ぶ |
| `oe-hookfire` | 415 | 止める側の hook 3本の発火記録を読む | なし | 専用なし。`test_home_unset.sh` と `test_oe_entry.sh` が `--help` 等を触るだけ |
| `oe-refute` | 303 | 設計SO。`so-compare` を包んで verdict を集約 | session / so-verdict | `test_oe_refute.sh`（72/0） |
| `oe-review` | 280 | 実装SO。`base...HEAD` の diff にバインド | session / so-verdict | `test_oe_review.sh`（73/0） |
| `oe-lane-explain` | 529 | SO のレーンが返らなかった理由を過去の出力から分類 | なし | `test_oe_lane_explain.sh`（67/0） |
| `oe-view` | 271 | md を wez の viewer ペインで glow 表示 / 非 md は `open` | oe-viewer | `test_oe_view.sh`（64/0） |

専用のテストファイルが無い verb は `oe-run` / `oe-capture` / `oe-send` / `oe-list` / `oe-lease` / `oe-selfcheck` / `oe-hookfire` の7本。このうち `oe-hookfire`（415 行）と `oe-selfcheck`（389 行）は、判定ロジックそのものを見るテストが見当たらない（`tests/` を verb 名で grep した結果）。

### 1.2 lib の表（23 本・4,808 行）

| lib | 行数 | 役割 | 使う verb | テスト |
| --- | --- | --- | --- | --- |
| `verify.sh` | 755 | 検証ゲート v1（reviewer を spawn してマーカーを読む） | `oe-run` | `test_verify.sh`（144/0） |
| `lease.sh` | 554 | lease の記録の読み書き・ロック・epoch の compare-and-swap（`lib/lease.sh:1-43`） | delegate / register / lease / handoff / recover / send / jump / select / tree | `test_lease*.sh` |
| `event-bus.sh` | 417 | `oe-events.jsonl` への追記（8種のイベント） | ack / delegate / handoff / lease / recover / register・`delegate-send.sh` 経由で send / report | `test_event_bus.sh`（95/0） |
| `handoff-state.sh` | 346 | 交代のとき機械で取れる状態の収集（read-only） | handoff | `test_handoff_prepare.sh` |
| `delegate-send.sh` | 322 | 1行送信・nonce・画面を見る finalize | send / report | `test_delegate_send.sh` |
| `spawn.sh` | 303 | `wez layout apply`・`wez pane split`・CLI ディスパッチ | `oe-run` | `test_spawn_board.sh`（16/0） |
| `delegate-registry.sh` | 280 | spawn registry と pane-issue の union 解決・GC | 12 本 | `test_delegate_registry.sh` |
| `capture.sh` | 209 | マーカー検出と KVS 書き込み | run / capture | `test_capture.sh`（112/0）・`test_kvs.sh` |
| `monitor.sh` | 189 | ポーリングとサーキットブレーカー | run | `test_monitor.sh`（31/0） |
| `seat.sh` | 182 | board の `現統括:` 行を読む・張り替える | handoff / recover / vitals | `test_handoff_take.sh` など |
| `target-resolve.sh` | 175 | 宛先を lease から引き本人確認、だめなら legacy へ | send / jump | `test_target_resolve.sh` |
| `so-verdict.sh` | 173 | VERDICT の抽出と保守的な集約 | refute / review | `test_so_verdict.sh`（33/0） |
| `heartbeat-resolve.sh` | 128 | heartbeat sidecar からペインと session を引く規則 | threads・lease 経由 | `test_lease.sh` |
| `oe-viewer.sh` | 128 | viewer ペインの解決 | view | `test_oe_view.sh` |
| `cleanup.sh` | 114 | trap でペイン kill と `/tmp` 掃除 | run | `test_cleanup.sh`（19/0） |
| `tmux-pane-identity.sh` | 113 | ペインのフォアグラウンドのプロセスと binding の照合（`ps -o lstart=`） | lease 経由 | `test_lease.sh` |
| `constants.sh` | 92 | 本体エンジンの定数 | run / capture | 各テスト |
| `session-title.sh` | 85 | 統括のセッション名の要求を書く | handoff / register | `test_session_name.sh`（35/0） |
| `envelope.sh` | 63 | envelope JSON の生成 | run | `test_envelope.sh`（21/0） |
| `sanitize.sh` | 62 | 会話に載る文字列の無害化 | event-bus 経由 | `test_sanitize.sh`（31/0） |
| `audit.sh` | 50 | 監査ログ JSONL の追記 | run / capture | `test_audit.sh`（11/0） |
| `attach.sh` | 48 | 既存ペインへの attach | capture | `test_attach.sh` |
| `session.sh` | 20 | 26 文字の ID 生成 | run / capture / refute / review・lease | 専用なし |

### 1.3 機能のまとまり（実物に合わせて束ねた）

| まとまり | verb | bin 行数 | 主な lib | 性格 |
| --- | --- | --- | --- | --- |
| A. 入口 | `oe` | 160 | なし | #605 で追加。`~/bin` に配るのはこれ |
| B. 本体エンジン（wez・非対話） | `oe-run` / `oe-capture` | 263 | constants / envelope / spawn / capture / monitor / verify / audit / cleanup / attach（計 1,823 行） | 2026-05 の MVP。他のまとまりと lib を共有するのは `session.sh` だけ |
| C. 委譲と送受信 | `oe-delegate` / `oe-kick` / `oe-send` / `oe-report` / `oe-ack` | 961 | delegate-send / delegate-registry / event-bus | 日々の主経路 |
| D. 登記・宛先・木 | `oe-list` / `oe-select` / `oe-jump` / `oe-register` / `oe-tree` / `oe-ident` | 1,650 | delegate-registry / target-resolve | cockpit の表示とナビ。`oe-tree` が 804 行 |
| E. lease と交代と復帰 | `oe-lease` / `oe-handoff` / `oe-recover` | 2,284 | lease / seat / handoff-state / tmux-pane-identity / heartbeat-resolve / session-title | 最大のまとまり。`oe-handoff` 単体で 1,410 行 |
| F. 到達確認と見張り | `oe-confirm` / `oe-undelivered` / `oe-vitals` / `oe-activity` / `oe-threads` / `oe-status` | 2,414 | ほぼ lib なし（自前の jq） | read-only。cron / launchd 前提のものを含む |
| G. 前提の点検 | `oe-selfcheck` / `oe-hookfire` | 804 | なし | 3値判定。定期実行は未配線 |
| H. SO のゲート | `oe-refute` / `oe-review` / `oe-lane-explain` | 1,112 | so-verdict / session | `so-compare` の包み。engine の他の部分と状態を共有しない |
| I. doc 表示 | `oe-view` | 271 | oe-viewer | wez と glow に依存 |

- `bin/README.md:7-12` の分類は「入口 / 本体エンジン / SO ゲート / 親子委譲 CLI / 観測 / doc 表示」。`oe-handoff`・`oe-lease`・`oe-recover` を「親子委譲 CLI」に入れているが、行数でも依存 lib でも別のまとまりである
- `README.md:124-131` は「2系統」と書くが、`README.md:5-13` の冒頭の表は5面である。README の中で切り方が2つある

## 2. 状態の置き場

### 2.1 `~/.claude/state/` 配下（engine の外・マシンごと）

| 置き場 | 中身 | 書く側 | 読む側 | 根拠 |
| --- | --- | --- | --- | --- |
| `oe-delegate/<server_pid>_<pane>.json` | spawn registry。`{pane,label,workspace,parent_pane,role}` | `oe_reg_record`（`oe-delegate` / `oe-register` / `oe-recover` / `oe-lease adopt`）。書くたびに `oe_reg_gc` が生存ペインに無い分を削除 | `oe-list` / `oe-send`（legacy 経路）/ `oe-tree` / `oe-ident` / `oe-status` / `oe-ack` / event-bus の role 導出 / handoff-state | `lib/delegate-registry.sh:59-80,237-280` |
| `pane-issue/` | `wt switch` 済みペインの `#N slug` | `scripts/wt/wt-pane-issue.sh`（engine の外） | delegate-registry / event-bus / `oe-ident` / `oe-tree` / hook `session-name.sh` | `lib/delegate-registry.sh:4-9`・`canonical/hooks/scripts/session-name.sh:46` |
| `oe-lease/<lease_id>.json` | lease の記録（generation・binding・rebinds・epoch） | `lib/lease.sh`（`oe-lease` / `oe-delegate` / `oe-register` / `oe-handoff take` / `oe-recover`）。lease ごとの `mkdir` ロック | target-resolve（send / jump / select）/ `oe-tree --lease` / `oe-vitals` / `oe-recover hint` | `lib/lease.sh:16-34`・`schemas/oe-lease.schema.json` |
| `oe-events.jsonl` | 活動ログ（append-only）。型は `child_spawned` / `message_sent` / `report_received` / `prompt_received` / `supervisor_succession` / `lease_bound` / `supervisor_recovery` / `delivery_held` の8種 | `lib/event-bus.sh` と、hook `oe-prompt-receipt.sh`（lib を使わず自前で1行組む） | `oe-activity` / `oe-ack` / `oe-confirm` / `oe-undelivered` / `oe-selfcheck` / `oe-recover` / `scripts/measure-delivery-arrival.py` | `lib/event-bus.sh:116-161`・`schemas/oe-events.schema.json`・`canonical/hooks/scripts/oe-prompt-receipt.sh:36-41,58-59` |
| `oe-receipt-diag.jsonl` | 受領印 hook が「印を書けなかった」診断 | hook `oe-prompt-receipt.sh` | `oe-confirm`（`cannot-confirm` の判定） | `canonical/hooks/scripts/oe-prompt-receipt.sh:59`・`bin/README.md:700` |
| `oe-heartbeat/<session_id>.json` | 拍動 sidecar `{ts,context_pct,pane,server_pid,model}` | statusLine の `statusline-oe-heartbeat.sh`（10 秒間隔の refresh でも走る） | `oe-vitals` / `oe-threads` / `oe-tree` / handoff-state / lease（候補選び）/ `oe-selfcheck`。掃除は `oe-lease gc` だけ | `canonical/claude/statusline/statusline-oe-heartbeat.sh:8-30`・`canonical/claude/statusline/claude.statusline.json`・`bin/README.md:287` |
| `oe-confirm/{seen,start-after,reports-state,latest.json,cron.log}` | 通知済みの記録・観測の起点・report の走査状態・最終走査時刻 | `oe-confirm`（`cron.log` は launchd） | `oe-confirm` 自身・`latest.json` は `oe-selfcheck` の `watchdog-freshness` | `bin/oe-confirm:166-173`・`bin/oe-selfcheck:340-361` |
| `oe-undelivered/{seen,start-after,cron.log}` | 同上 | `oe-undelivered` | 自身 | `bin/README.md:744-746` |
| `oe-vitals/{seen,cron.log}` | 同上 | `oe-vitals` | 自身 | `bin/README.md:861` |
| `session-title/<session_id>.json` | 統括のセッション名の要求 | `lib/session-title.sh`（`oe-handoff take` / `oe-register root`） | hook `session-name.sh`・`oe-recover hint` | `lib/session-title.sh:8-13` |
| `oe-jump/last-target` | 直近の jump 先 | `oe-jump --record` | `oe-jump`（無引数） | `bin/README.md:352` |
| `oe-view/viewer-pane-id` | viewer の wez ペイン ID | `lib/oe-viewer.sh` | 同 | `bin/README.md:375` |
| `hook-firing/` | 止める側 hook の発火 tally と `deny.jsonl` / `diag.jsonl` | hook `block-destructive.sh` / `block-force-push.sh` / `cc-lint.sh` / `notify.sh` | `oe-hookfire` | `bin/README.md:798-800` |

`~/.claude/projects/`（Claude Code の transcript）も読む。`lib/handoff-state.sh`（resume できるかの鮮度）と `oe-selfcheck` の `transcript-format`（`promptSource=typed` を取り出せるか）が使う（`lib/handoff-state.sh:25`・`bin/oe-selfcheck:259-289`）。

### 2.2 リポジトリの中・作業ツリーの中

| 置き場 | 中身 | 書く側 | 読む側 | 根拠 |
| --- | --- | --- | --- | --- |
| `audit/<session_id>.jsonl` | 本体エンジンの監査ログ | `lib/audit.sh`（`oe-run` / `oe-capture`） | `oe-status` | `lib/constants.sh:50-53`・`.gitignore:44` |
| `audit/oe-refute.jsonl`・`audit/oe-review.jsonl` | SO の最小 audit（別スキーマ） | `oe-refute` / `oe-review` | 読む verb は無い（`oe-status` は対象外と明記） | `bin/README.md:74,96,438` |
| `state/<session_id>.state.json` | 本体エンジンの KVS | `lib/capture.sh` / `lib/verify.sh` | `oe-status` | `lib/constants.sh:50`・`.gitignore:45` |
| `<workspace>/.oe/`（gitignore） | board（`START-HERE-board.md` など）・引き継ぎ文書・子の `report-*.md` | board は人と統括。`現統括:` 行だけ `lib/seat.sh` が張り替える（`oe-handoff take` / `oe-recover`）。引き継ぎ文書は機械の節を `oe-handoff prepare`、残りは人。report は子 | `oe-vitals`（`OE_BOARD_FILE`）/ `oe-handoff` / `oe-recover` / `oe-confirm --reports` / `scripts/validate-board.sh` | `.gitignore:41`・`lib/seat.sh:1-17`・`templates/handoff.md.template`・`bin/oe-confirm:446` |
| `<workspace>/tmp/oe-refute-*`・`tmp/oe-review-*`・`tmp/so-*` | `so-compare` のレーン別出力 | `so-compare`（`oe-refute` / `oe-review` 経由） | `oe-lane-explain` | `bin/README.md:814-818` |
| `/tmp/oe-<session_id>-envelope.json` ほか | 本体エンジンの envelope・reviewer のログ | `lib/envelope.sh` / `lib/verify.sh` | `lib/spawn.sh` / `lib/capture.sh`。`lib/cleanup.sh` が消す | `lib/envelope.sh`・`lib/verify.sh`・`lib/cleanup.sh` |

### 2.3 プロセスの環境変数として持つ状態

- `PARENT_TMUX_PANE`: `oe-delegate` が子へ渡す親ペイン。張り替えられない（`bin/README.md:245`）
- `OE_LEASE_ID` / `OE_GENERATION`: 子と、resume した統括が自分の lease を名乗る鍵（`bin/README.md:285,306`）
- `CLAUDE_PID` / `CLAUDE_CODE_SESSION_ID`: Claude Code が Bash に渡す値。lease の binding と session の登録に使う（`bin/README.md:283`）
- `TMUX` / `TMUX_PANE`: registry のキー（server pid とペイン）と、受領印の束縛先

### 2.4 状態の置き場から見える点

- 「誰が誰か」を持つ場所が4つある。registry（ペイン番号）・lease（自前 ID）・board の `現統括:` 行（宣言）・heartbeat sidecar（session_id とペイン）。`oe-recover` は lease から board と registry を作り直す（`bin/README.md:314`）ので、lease が正本になりつつある
- `oe-events.jsonl` に rotation が無い。`oe-undelivered` の抑止キーはログ内の index を含むので、rotate すると壊れると自分で書いている（`bin/README.md:732`）。heartbeat sidecar は同じペインに何日分も溜まる（`bin/README.md:658-659`）
- `audit/oe-refute.jsonl` と `audit/oe-review.jsonl` は書かれるだけで、読む verb が engine の中に無い。README は「将来の PR-create hard gate の前提物」と書く（`bin/README.md:80`）

## 3. 外部への依存

| 依存先 | どこが使うか | 縛りの強さ | 根拠 |
| --- | --- | --- | --- |
| tmux | 委譲・送信・登記・木・交代・復帰のすべて。`send-keys -l` → sleep → `Enter`、`capture-pane` で入力欄を読む、`split-window -t`、`list-panes -a`、`display-popup`、`#{pid}`（2.1+）、DCS passthrough（3.3+ と `allow-passthrough on`） | 最も強い。transport そのもの | `lib/delegate-send.sh:61-110`・`lib/delegate-registry.sh:252`・`canonical/hooks/scripts/notify.sh:9`・`bin/oe-confirm:460-461` |
| WezTerm と `wez` CLI（`projects/wezterm-ai-mode`） | 本体エンジンの全部（`wez layout apply` / `pane split` / `pane send` / `pane capture` / `pane kill`）・`oe-view`・通知（`wez notify` と OSC 777） | 本体エンジンと `oe-view` は wez 無しで動かない。見張りの通知は stdout に落ちる | `lib/spawn.sh:42,159,275`・`lib/verify.sh:371`・`lib/cleanup.sh:44,109`・`lib/oe-viewer.sh:14` |
| Claude Code の hook 契約 | `UserPromptSubmit` の stdin の `.prompt` と、hook の env への `$TMUX_PANE` 伝播（受領印）。`hookSpecificOutput.sessionTitle`（セッション名）。`statusLine` の stdin の `.session_id` / `.context_window.used_percentage` / `.model`（拍動） | 到達確認と vital 監視の土台。契約が変わると印が出なくなる、と hook 自身が書く | `canonical/hooks/claude.hooks.json`（`UserPromptSubmit` に2本）・`canonical/hooks/scripts/oe-prompt-receipt.sh:24-35`・`canonical/hooks/scripts/session-name.sh:34-37`・`canonical/claude/statusline/statusline-oe-heartbeat.sh:14-27` |
| Claude Code の TUI の画面文字列 | finalize が入力欄の `❯`、プレースホルダの `Try "`、処理中の目印 `esc to interrupt` を画面から読む | 版で消える。`esc to interrupt` は実際に消えて約2か月誰も気づかなかった、と `oe-selfcheck` が書く。コードにはまだ残る | `lib/delegate-send.sh:35-51,66,221`・`bin/README.md:757`・`bin/oe-selfcheck:51,105-168` |
| Claude Code の CLI と transcript | `claude --resume <session_id>` / `claude -r '<名前>'`（復帰）・`claude -p … --no-session-persistence --max-budget-usd`（本体エンジン）・`~/.claude/projects` の JSONL の `promptSource=typed` | 復帰と点検が依存 | `bin/README.md:306`・`lib/spawn.sh:208`・`bin/oe-selfcheck:263-289` |
| プロセスの見え方 | `ps -o lstart= -p`（開始時刻で本人確認）・`ps -o comm=`（コマンド名が `claude` か）・`#{pane_pid}`・`kill -0` | lease の binding の根拠。コマンド名が `claude` でない起こし方（シェルの中で手で起動）では「確かめられない」に倒れる | `lib/tmux-pane-identity.sh:35-80`・`bin/README.md:259` |
| macOS | launchd（`launchctl list` で見張りの登録を見る・plist テンプレート）・`open`・BSD `stat -f`・`/opt/homebrew/bin`・stock の bash 3.2（連想配列・nameref・`mapfile`・`readlink -f` を使わない） | 配備と一部のコードが macOS 前提。Linux では見張りの登録状態が `unknown launchctl-not-found` になる | `lib/handoff-state.sh:285-293`・`launchd/com.stlwolf.oe-confirm.plist.template`・`bin/oe-view:213`・`bin/oe-handoff:396`・`lib/seat.sh:168`・`lib/delegate-registry.sh:12`・`bin/oe-tree:332` |
| jq | ほぼ全 verb（bin + lib で `jq ` が 442 箇所）。無いと exit 2 か no-op | 必須 | 実測。`lib/event-bus.sh:118`・`bin/README.md:836` |
| `so-compare`（`scripts/so-compare.sh`・1,624 行）と codex / cursor-agent / claude | `oe-refute` / `oe-review`。既定のレーンは `codex,cursor` | SO のゲートは外部の3つの CLI の使用量上限や認証に左右される。その分類のために `oe-lane-explain` がある | `bin/README.md:61-68,825`・`tests/fixtures/so-lane-failures/` |
| cursor-agent | 本体エンジンの既定の target（`composer-2`）。reviewer は `claude-sonnet-4-6` | モデル名が `lib/constants.sh` に直書き | `lib/constants.sh:73-76` |
| fzf / glow / bat / gh / git / yq / python3 | fzf は select / tree --pick / status -i（番号選択に degrade）・glow と bat は view・gh は handoff の open PR・yq は knowledge のスクリプト・python3 は測定器 | 任意か degrade あり。yq は mikefarah 版の書き方（`-p=yaml -o=json`） | `bin/README.md:324,385`・`lib/handoff-state.sh:342`・`scripts/validate-knowledge.sh:184` |
| dotfiles（リポジトリの外） | `.tmux.conf` の `pane-border-format`（`oe-ident`）・popup の bind（`oe-tree --watch` / `--pick`）・`wezterm.lua` の `hyperlink_rules`（`oe-view` のクリック） | cockpit の見た目と導線は hub の外で opt-in。hub は推奨スニペットだけ持つ | `bin/README.md:456-461,539-545,570-582,387` |
| 配布（`scripts/sync/`） | `sync-bin.sh` が `~/bin` に張るのは `oe`・`oe-tree`・`oe-hookfire` の3本。hook と statusLine は `sync-claude.sh` 側が `~/.claude/hooks/` と `~/.claude/statusline/` へ | verb は repo の作業コピーへの symlink。hook は engine の lib が見えないので自己完結で書かれている | `scripts/sync/sync-bin.sh:66-78`・`canonical/hooks/scripts/oe-prompt-receipt.sh:36-41` |

この sandbox（Linux・root・bash 5.2）でテストを回した結果が、縛りの実測になる。53 本中 44 本が緑、9 本が赤。

- 「読めない置き場」「書けない board」を chmod で作るテストが root では成立しない: `test_lease_observe.sh`（2）・`test_oe_threads.sh`（4）・`test_oe_tree.sh`（1）・`test_oe_recover.sh`（3）・`test_handoff_prepare.sh`（1）。root 実行が原因という読みは推測（`id -u` が 0 であることと失敗メッセージからの推定）
- `test_handoff_prepare.sh` の「新規作成は 600」は、テストが BSD の `stat -f` を先に試し、GNU では別の出力で成功してしまう形。`lib/handoff-state.sh:263` が同じ罠を避けているのに、`bin/oe-handoff:396` と `lib/seat.sh:168` とテストには BSD 先行の形が残る
- `test_validate_knowledge.sh`（146）と `test_knowledge_list.sh`（102）は、この環境の `yq` が別実装（`yq 0.0.0`）で frontmatter を読めないため
- `test_home_unset.sh`（1）は `oe-register --help` が tmux の外で exit 1 になるため（下の 6.9）。`test_oe_entry_identity.sh`（1）は `test_oe_recover.sh` を入口越しに回して同じ赤を拾ったもの

## 4. 人が手を動かしている所

### 4.1 導入時に一度だけ人がやること

- `./scripts/sync.sh` を打って `~/bin` と `~/.claude/` へ配る。`oe-selfcheck` の `hook-contract` は「配線はあるが実行可能でない（sync 未実行の可能性）」を別に出す（`bin/oe-selfcheck:192`）
- `oe-confirm` の常駐。plist テンプレートのプレースホルダ3つを `sed` で置換し、ログの置き場を先に `mkdir` し、`plutil -lint`、`launchctl load`、`oe-selfcheck` で確認、の5手順。worktree のパスを焼くと静かに失敗する（`launchd/com.stlwolf.oe-confirm.plist.template:10-38`）
- `oe-undelivered` と `oe-vitals` の cron 登録。「登録は owner 環境依存・自動化しない」。`oe-vitals` は `OE_BOARD_FILE` を渡さないと no-op（`bin/README.md:746,863-866`）
- `.tmux.conf` に border と popup のスニペットを書く。リポジトリの絶対パスを書くので、移動すると陳腐化する（`bin/README.md:550`）
- `oe-lease adopt` を一度打つ（registry の記録から lease を作る取り込み）（`bin/README.md:288`）

### 4.2 日々の運用で人か統括がやること

- 手で起こした統括は `oe register root`（または `oe lease create --root`）で自分を登記する。spawn を経ないと木に出ない（`bin/README.md:189-196,283`・`canonical/skills/doc-flow-guardrail/SKILL.md:144`）
- 報告を読んだら `oe-ack` を打つ。導入から約6週間で1件しか打たれていない、と verb 自身が書く（`bin/oe-ack:33-37`）。`oe-undelivered` はこの印を前提にしている
- elevated な子の spawn は、`--print-approval` で出た承認パッケージを owner が見て、`--approved-digest` 付きのコマンドを承認する（`bin/oe-delegate:7-14,325`）
- 見張りと点検を打つ。`oe-selfcheck` と `oe-hookfire` は定期実行が無く「人が打つまで動かない」（`bin/README.md:164-165,806`・`bin/oe-hookfire:30`・`bin/oe-selfcheck:338`）。自動化は #301 で、コード内の記述は「park 中」（`bin/oe-confirm:65`）
- `oe-selfcheck` / `oe-hookfire` の exit 2 は「判定できない」と「呼び方の誤り」が相乗りしている。README は「2 を見て自動で再試行しないこと」と人に注意を預けている（`bin/README.md:768,803-804`）

### 4.3 統括の交代（`oe-handoff`）で人が持つ所

- 引き継ぎ文書の「人が書く節」。前任の自己申告の表に、項目ごとの処分（`済んだ` / `引き継ぐ` / `取り消す`）を書く。`retire` はこの表の行だけを見て、処分が付いていなければ閉じない（`templates/handoff.md.template:13-25`・`bin/README.md:228`）
- 後継が各子へ「報告の宛先は後継のペインである」と明示して伝える。`PARENT_TMUX_PANE` は張り替えられないので、`OE_LEASE_ID` を持たない古い子と `oe-report` を使う子ではこの穴が残る（`bin/README.md:245-246`）
- 交代のあと、子を `oe-register link` でつけかえる。子が0体のときは前任の root 登記が残るので `oe-register root` を打ち直す（`bin/README.md:251`）
- `retire --execute` が触るのは前任のペインだけ。登記の掃除・worktree の掃除・issue の close は「人のゲートのまま残す」（`bin/README.md:229`）
- board の系譜の散文は機械が触らない。席のペインと日付だけ張り替える（`lib/seat.sh:14-17`）
- `start` が引き継ぎ文書のパスを送れなかったら「手で貼ってください」と出す（`bin/oe-handoff:494,502`）。セッション名の要求を書けなかったら「手で /rename する」（`bin/oe-handoff:840`）
- シェルの中で手で起動した claude のペインは、pid がシェルのものになるので `retire` が閉じない。停止は人の判断に残る（`bin/README.md:259`）

### 4.4 復帰（`oe-recover`）で人が持つ所

- 手順5つのうち1〜3は owner が打つ。気づく → 普通のシェルで `oe recover hint` → 出た1行を新しいペインで打って「復帰して」と頼む（`bin/README.md:303-309`）
- 止まったときの案内は、ほぼすべて「owner が `ps -p … -o pid,lstart,command` で確かめる」「owner がどちらの持ち場かを決める」「owner が `tmux kill-pane` で閉じる」の形（`bin/oe-recover:134,226,235,287,339-351`）。verb は前の claude を閉じない
- 統括の lease を会話の記録から名乗るときは `--owner-confirmed` が要る（`bin/README.md:284`）

### 4.5 「暫定」「移行中」「未配線」と自分で書いている所

- lease への移行（#577）。registry と lease の二重書き（`bin/oe-delegate:32`・`bin/oe-register:38`）。宛先の解決は `label-legacy` / `parent-legacy` に落ちる（`lib/target-resolve.sh:131-137,173`）。`oe-vitals` は lease が決まらなければ board で判定する「移行のあいだの逃げ道」（`bin/oe-vitals:75,87`）。`oe-recover` は registry を「移行のあいだだけ」作り直す（`bin/oe-recover:464`）。`oe-tree` の既定を lease に切り替えるのは未実施（`bin/README.md:635`）
- `oe-report` は legacy。消すのは #603（`bin/README.md:391`・`canonical/skills/delegate-task/SKILL.md:249`）
- `--kickoff` は `--brief` の deprecated alias（`bin/oe-delegate:46`・`bin/oe-send:43`）
- `oe-activity` の `DELIVERY` / `MISS` 列は、実測で逆を指していた値を過去の 342 件分数え続ける。是正はスコープ外（`bin/README.md:482-483`）
- `oe-threads` を `oe-tree` と統合するかは未判断（`bin/README.md:639-642`）
- `oe-tree` の follow-up（`--json`・`--summary`・汎用の `oe-watch` など）は未実装（`bin/README.md:584`）
- frontier の read 規則は3つ目の copy で、共有 lib への統合は follow-up（`bin/oe-undelivered:47`）
- `wez notify` が cron から届くかは未検証（`bin/oe-vitals:68`・`bin/README.md:747`）
- `oe-vitals` 自身の最終走査は記録が無く確かめられない。`watchdog-freshness` が見るのは `oe-confirm` だけ（`bin/README.md:256`）
- 本体エンジンの codex ディスパッチは「スタブ（動作確認なし）」（`lib/spawn.sh:177`）。reviewer の nonce marker（#93）は open（`README.md:243`・`lib/verify.sh:583`）
- Phase 5 の方向感メモは `status: draft` のまま（`README.md:228`）
- `README.md:222` は蒸留パイプラインの soft floor の正本を「このリポジトリの外のファイルで、hub には無い」と書く

## 5. 規模の数字（すべて実測）

| 項目 | 値 |
| --- | --- |
| bin の実行可能エントリ | 29 本・9,919 行（うち行頭コメント 2,467 行＝約 25%） |
| lib | 23 本・4,808 行（うち行頭コメント 1,574 行＝約 33%） |
| bin + lib | 14,727 行 |
| `bin/README.md` / `README.md` | 899 行 / 250 行 |
| tests | `test_*.sh` 53 本・16,556 行（bin + lib の約 1.12 倍） |
| tests/e2e_real_agent | シェル 894 行（実 agent を使う手動の E2E。`bin/wez` の差し替えを含む） |
| assertion の数（この環境で実行） | 3,532（PASS 3,270・FAIL 262）。緑 44 本・赤 9 本。赤のうち 248 件は yq 差の2本 |
| scripts | 2,672 行（`validate-*.sh` 5本・`knowledge-list.sh`・測定の Python 7本） |
| schemas | 7 本・824 行 |
| launchd / templates | 80 行 / 49 行 |
| 最大の verb | `oe-handoff` 1,410 行。次が `oe-tree` 804・`oe-confirm` 621・`oe-recover` 615・`oe-lane-explain` 529 |
| 最大のテスト | `test_handoff_retire.sh` 1,187 行（200 assertion） |
| `TODO` / `FIXME` / `HACK` | 0 件（`XXXX` は `mktemp` のテンプレートだけ） |
| 「暫定」 | 0 件。代わりの語: 「移行のあいだ」bin 4・lib 2、「legacy」bin 3・lib 4、「deprecated」bin 4、「未検証」bin 4、「未配線」bin 2、「follow-up」bin 1・lib 3、「既知の制約」bin 3、「best-effort」bin 24・lib 35 |
| `OE_*` の変数名（bin + lib の distinct） | 153 |
| 参照している issue 番号（bin + lib の distinct） | 80。多い順に #577（53 箇所）・#322（36）・#299（30）・#224（15）・#355（14） |
| `jq ` の呼び出し（bin + lib） | 442 箇所 |
| イベントの型 | 8 種（`schemas/oe-events.schema.json`） |
| docs | decisions 24・discussions 26・episodes 118・plans 40・knowledge 2（件数だけ。中身は読んでいない） |
| 関連するハーネス側 | hook `oe-prompt-receipt.sh` 182 行・`session-name.sh` 238 行・`notify.sh` 165 行・statusLine `statusline-oe-heartbeat.sh` 164 行。skill `delegate-task` 346 行・`doc-flow-guardrail` 220 行・`judgment-board-flow` 398 行・`orchestration-toolkit` 54 行 |
| CI | `.github/` が無い。テストを一括で回すランナーも `tests/` に無い（1本ずつ `bash tests/test_x.sh`） |

`TODO` が0件なのは、未了の事項をコード内の散文（「正直に書く」調のコメント）と README に書く流儀のためで、未了が無いという意味ではない。未了の量は 4.5 の語の件数のほうが近い。

## 6. 構造上の歪み

1. **本体エンジン（B）が孤立している。** `oe-run` の lib 9本（1,823 行）は、他のまとまりと `session.sh` しか共有しない。substrate も違う（wez の整数ペイン対 tmux の `%N`）。README は ADR で「pane 層で統一しない」と決めたと書く（`README.md:223`）。日々の委譲（C〜F）は本体エンジンを通らない。`oe-run` がいまも使われているかはコードからは分からない（推測: 2026-05 の MVP 以降、開発の重心は C〜G に移っている。issue 参照の上位が #577・#322・#299 で、本体エンジン由来の #175 は 10 箇所にとどまる）
2. **identity の二重管理。** registry はペイン番号がキーで tmux を起こし直すと失われ、lease は自前 ID で残る。書く側は両方に書き、読む側は lease → registry の順に落ちる。`OE_TARGET_HOW` に `label-legacy` / `parent-legacy` という値がある（`lib/target-resolve.sh:28`）。`oe-list`・`oe-ident`・`oe-status`・`oe-ack`・`oe-tree` の既定は registry のまま。board の `現統括:` 行と heartbeat sidecar も「誰か」を持つので、同じ事実の置き場が4つある
3. **子から親への戻しの経路が3本ある。** `oe send --to-parent`（lease 経由）・`oe-send "$PARENT_TMUX_PANE"`（素のペイン）・`oe-report`（legacy）。`bin/oe-delegate:19` の冒頭コメントはいまも `oe-send "$PARENT_TMUX_PANE"` で返せると書いており、README と skill の「`--to-parent` に一本化」と食い違う
4. **「届いた」を見る仕組みが4層に積まれている。** (a) finalize の画面読み（`delivery_signal`・実測で逆を指して書き込み停止）、(b) 受領印 `prompt_received`（hook・nonce）、(c) 受領印 `report_received`（`oe-ack`・手動・ほぼ未使用）、(d) それらを読む `oe-confirm` / `oe-undelivered` / `oe-activity`。古い層を消さずに新しい層を足している。`oe-undelivered` は (c) の未 ack を起点にするので、(c) がほぼ打たれない現状では窓を越えた報告の大半が該当する（推測: 既定を shadow にし `--start-after` を足した経緯と整合する・`bin/README.md:733-735`）
5. **失効が分かっている前提がコードに残る。** finalize は `esc to interrupt` をいまも既定の目印にしている（`lib/delegate-send.sh:66,221`）。`oe-selfcheck` の `screen-marker` は、その目印が走査窓に入らないことを検出するための検査である（`bin/oe-selfcheck:105-168`）。壊れた前提を直す代わりに、壊れていることを検出する verb を足した形になっている。finalize の「staged のまま残ったら Enter を1回撃つ」回復は、目印が見えなければ `proc=0` のまま条件を通るので動き続ける。効かなくなっているのは「処理中なら撃たない」という抑止の側である（`lib/delegate-send.sh:84,108-112`）
6. **lib を使わない verb が同じ処理を持つ。** `oe-activity` / `oe-confirm` / `oe-undelivered` / `oe-selfcheck` / `oe-hookfire` / `oe-lane-explain` / `oe-threads` の一部は lib を source しない。`_oe_home_usable` は bin 7本と lib 7本と hook 1本の計 15 箇所に定義がある（「全箇所で byte 一致させる」とコメントで管理・`lib/event-bus.sh:52-54`）。frontier の規則は `oe-ack` / `oe-activity` / `oe-undelivered` の3箇所。出力の無害化は `oe-tree:703` の `sanitize_out`・`oe-delegate:233` の `_strip_cntrl`・`lib/sanitize.sh` の3系統。26 文字 ID の生成は `lib/session.sh:7`・`lib/delegate-send.sh:140`・`lib/verify.sh:595` の3つ。symlink を1段ずつたどる処理は `bin/oe`・`bin/oe-tree`・`bin/oe-view` の3つ。tmux server pid の導出は `lib/delegate-registry.sh:30`・`lib/handoff-state.sh:50`・statusLine の3つ。hook が自己完結でなければならない事情（配備先から lib が見えない）は理由として書かれているが、bin どうしの重複には当てはまらない
7. **見張りの family が3本とも別々の state と別々の配線を持つ。** `oe-confirm`（launchd・5分）・`oe-undelivered`（cron 例・15分）・`oe-vitals`（cron 例・15分）。seen cache・`start-after`・通知の経路（`oe-confirm` は OSC 777 → `wez notify`、他の2本は `wez notify`）がそれぞれにある。見張りが黙ったことを拾えるのは `oe-confirm` だけで、拾う側の `oe-selfcheck` は人が打つ
8. **`oe-handoff` に責務が集まっている。** 4つの subcommand は走るセッションが違い（前任 / 後継）、1,410 行で lib 5本を使い、テストは5ファイル 2,567 行。`bin/README.md` の該当節（`bin/README.md:204-262`）は owner 裁定の履歴と訂正の経緯を含み、仕様と経緯が同じ場所にある
9. **小さな不整合（実物で確かめたもの）。**
   - `oe --help` で `capture` の説明が空になる。入口は各ファイルの2行目の `# oe-<verb> — …` から説明を取るが、`bin/oe-capture` の2行目は `set -euo pipefail`
   - `oe-register --help` は tmux の外で exit 1 になる。`TMUX_PANE` の検査（`bin/oe-register:138`）が `--help` の処理（`:146`）より前にある。`test_home_unset.sh` はこれを rc=0 と期待しており、tmux の中で回したときだけ緑になる
   - `bin/README.md:770-776` の `oe-selfcheck` の検査表は5行だが、実装は6つ（`watchdog-freshness` が表に無い・`bin/oe-selfcheck:366-371`）
   - `bin/README.md:5` は「29 本」、`README.md:100` は「JSON Schema 7 件」で実物と一致。`CLAUDE.md` の「CLI 9件」も `sync-bin.sh:66` の `CMD_NAMES` と一致
   - `bin/README.md:306` は「`oe-*` は PATH に無いことがあるので `readlink ~/bin/oe-tree` の隣から呼ぶ」と書く。#605 で入口 `oe` を配るようになったあとの `doc-flow-guardrail` の「verb 解決規約」（`command -v oe` を先に見る）と手順が2通りある
   - `scripts/register-metrics/` は「会話面の応答レジスタ」の測定で、registry とも `oe-register` とも無関係。名前が紛らわしい（`README.md:111`）。`scripts/validate-knowledge.sh` と `knowledge-list.sh`（計 1,007 行・テスト 1,615 行）も委譲エンジンの機能ではなく、negative knowledge の道具が engine の下に置かれている
   - 名前の不統一: registry のディレクトリは `oe-delegate/`、変数は `OE_DELEGATE_STATE_DIR`、関数は `oe_reg_*`、文書では「登記」「spawn registry」。heartbeat は「拍動」「sidecar」「beat」。board は「盤面」「判断ボード」「declared 層」
10. **テストは厚いが、実環境との接点は手動。** 単体はすべて偽の `tmux` / `ps` / `wez` を PATH に差し込む形で、実 tmux と実 Claude Code を通るのは `tests/e2e_real_agent/`（本体エンジン用・手動）だけ。委譲・交代・復帰の実機での確認は自動化されていない（推測: README の「実地で踏んだ」「実測」の記述が、実機の確認が運用の中で行われていることを示す）。CI が無いので、赤になっても気づく仕組みはリポジトリには無い

## 7. 読んでいないもの・確かめていないもの

- `docs/` 配下（decisions / discussions / episodes / plans）は件数だけ。別の担当の範囲
- `bin/oe-handoff`・`bin/oe-recover`・`bin/oe-confirm`・`bin/oe-tree`・`bin/oe-lane-explain` の本文は、冒頭コメントと `bin/README.md` の該当節、grep で拾った行までしか読んでいない。全行は通読していない
- `lib/verify.sh`・`lib/monitor.sh`・`lib/capture.sh` は冒頭と関数一覧だけ
- `canonical/skills/` は verb の出現回数と、戻しの経路・verb 解決規約の行だけ。`judgment-board-flow`（398 行）の board の運用は読んでいない
- 実機（macOS・tmux・WezTerm・Claude Code）での動作は確かめていない。`~/.claude/state/` の実データも無い環境である
- 各 verb の実際の利用頻度は、コードからは分からない。`oe-events.jsonl` の実データがあれば測れる

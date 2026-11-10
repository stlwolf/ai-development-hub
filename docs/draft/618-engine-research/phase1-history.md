# orchestration-engine の経緯と判断 — issue #618 事前リサーチ（phase 1・履歴）

調査日: 2026-11-10。読むだけで、リポジトリは変更していない。

## 0. 調べ方と限界

- 対象は `projects/orchestration-engine/docs/`（以下 `E/` と略す）の decisions / discussions / episodes / plans / knowledge、`projects/orchestration-engine/audit/`、`projects/orchestration-engine/README.md`、root の `docs/orchestration-engine/`、`docs/harness/`（engine に関わるものだけ）、`docs/draft/`。
- 進め方: 全ファイルの frontmatter（title / status）と行数を機械で一覧化 → decision は 24 本すべての「決定」節を読んだ → discussion / plan / episode は題名から選んで冒頭〜要所を読んだ（episode は 118 本中およそ 20 本を本文まで、残りは題名と status のみ）。
- 限界（先に書く）:
  - git の履歴は shallow（50 commit・2026-10-18 以降）なので、日付は commit ではなく**文書のファイル名と本文の日付**による。
  - `projects/orchestration-engine/audit/` は `.gitkeep` 1 個だけで中身が無い。実行時の監査ログ（`audit/*.jsonl`）は `.gitignore:43-45` で除外されている。したがって「監査ログから読む」ことはできなかった。
  - 3 節の「件数」は、文書が自分で書いている数字（出どころを付けた）と、キーワードを含むファイル数（言及数であって事故の件数ではない）を分けて書いた。
  - issue #618 を指す文書は 3 つの木のどこにも無い（grep 0 件）。GitHub の issue 本文は読んでいない。

## 1. 年表

日付は文書の日付。根拠は各行の末尾。

### 1.1 前史と Phase 4 MVP（2026-05）

| 日付 | 節目 | 根拠 |
|---|---|---|
| 2026-05-13 | Step 4-0。MVP のスコープとゴールを仮置き（3 層モデル・UC 3 本・「オープンループ自律サイクル + 最小 SLO」） | `E/discussions/2026-05-13-discussion-engine-scope-and-goals.md` |
| 2026-05-14 | Step 4-1。envelope とディスパッチャ骨格。DI-10 / DI-13 / DI-14 の ADR、監査ログ（JSON Lines）スキーマ、failure taxonomy 6 値、サーキットブレーカー | `E/decisions/2026-05-14-*.md`、`E/episodes/2026-05-14-episode-audit-log-schema.md` ほか同日 13 本 |
| 2026-05-16 | Step 4-3。検証ゲート v1（別エージェントによる Compliance Review） | `E/decisions/2026-05-16-decision-verification-gate-design.md` |
| 2026-05-18 | Step 4-4 / 4-5。実 agent で 1 サイクル E2E 完走を 1 回実証。reviewer の出力を file redirect に変更。Epic #19 close | `E/decisions/2026-05-18-decision-reviewer-output-file-redirect.md`、`projects/orchestration-engine/README.md` の「状態」節 |
| 2026-05-19 | Phase 4 直後の振り返り。「daily driver ではなく specialized instrument」。target case（EC2 → ECS + IaC 化）が出て Phase 5 方針（Epic #105・パイプライン駆動）へ | `E/episodes/2026-05-19-retrospective-post-phase-4-baseline-vs-engine-and-target-case.md`、`E/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md` |
| 2026-05-26 | `oe-capture`（既存ペインへの attach）。「#105 Phase 5 dogfood の Slice A」と書かれた唯一の実装 | `E/episodes/2026-05-26-episode-issue-109-oe-capture-attach.md` |

### 1.2 親子委譲と cockpit への転回（2026-06）

| 日付 | 節目 | 根拠 |
|---|---|---|
| 2026-06-04 | 本体エンジン（WezTerm の `oe`）の state ファイルはこの日が最後。以後 0 件 | `E/discussions/2026-11-06-discussion-577-record-identity-key.md` §2.1（[verified] と記載） |
| 2026-06-08 | **委譲**。`oe-delegate` を再設計（#137 PoC → #138 → PR #143）。spawn + kick に純化、送信はパスポインタ 1 行、戻しは汎用 `oe-send` | `E/episodes/2026-06-08-episode-oe-delegate-redesign.md` |
| 2026-06-09 | 送信信頼化（#144）。Enter 吸収への観測ベース finalize | `E/episodes/2026-06-09-episode-oe-send-finalize-ingestion.md` |
| 2026-06-16 | copy-mode ガード（#154）。間欠不達の主トリガを確定 | `E/episodes/2026-06-16-episode-oe-send-copymode-guard.md` |
| 2026-06-17〜21 | **cockpit** の最小 UI。`oe-select`、`oe-status`（#177）、`oe-kick`（#178）、`oe-jump`（#179）、`oe-ident`（#202）、盤面の wez layout 化（#175） | `E/episodes/2026-06-17-episode-oe-select.md`、`2026-06-20-episode-177-oe-status.md` ほか |
| 2026-06-18〜20 | SO ゲートの verb。`oe-refute`（設計 SO・#183）、`oe-review`（実装 SO・#194/#195） | `E/episodes/2026-06-18-episode-oe-refute.md`、`2026-06-20-episode-194-impl-so-artifact.md` |
| 2026-06-19 | decision #188。2 基盤（WezTerm の `oe` と tmux の `oe-delegate`）の identity をペイン層で統一しない | `E/decisions/2026-06-19-decision-188-identity-unification.md` |
| 2026-06-22 | 親子活動ログ `oe-events.jsonl` と `oe-activity`（#206） | `E/decisions/2026-06-22-decision-206-activity-log-self-contained-events.md` |
| 2026-06-30 | 取得チャネルを file-redirect に正準化、scrape を降格（#114） | `E/decisions/2026-06-30-decision-114-clean-output-channel.md` |

### 1.3 受領・見張り・文書フロー（2026-07）

| 日付 | 節目 | 根拠 |
|---|---|---|
| 2026-07-01 | 検証ゲートの入力を commit 範囲に（#92） | `E/decisions/2026-07-01-decision-92-commit-range-verify-inputs.md` |
| 2026-07-02 | **受領の印（1 代目）**。`oe-ack`＝受けた側が明示的に打つ `report_received`（#206A） | `E/decisions/2026-07-02-decision-206A-report-received-ack.md` |
| 2026-07-03〜05 | `oe-tree`（spawn ツリー・--watch・--pick） | `E/episodes/2026-07-03-episode-221-spawn-tree-view.md` ほか |
| 2026-07-09 | 報告未達の見張り `oe-undelivered`（#239 段階 0）。統括 succession / watchdog を「lean」に決定（seat は先送り）。この時点で統括は 3〜4 代 | `E/episodes/2026-07-09-episode-239-report-undelivered-watchdog.md`、`E/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md` |
| 2026-07-10〜11 | statusLine の拍動 producer、`oe-vitals`（統括の vital 監視）、board schema（draft のまま） | `E/episodes/2026-07-10-episode-239-statusline-heartbeat-producer.md`、`E/decisions/2026-07-10-decision-238-board-schema.md` |
| 2026-07-12〜14 | 文書フロー棚卸し → `document-format.md` v2（作業層 `.oe/` を公認・昇格義務）→ `doc-flow-guardrail` スキル v0 | `E/discussions/2026-07-12-discussion-doc-flow-stocktake.md`、`E/episodes/2026-07-13-episode-249-document-format-v2.md`、`2026-07-14-episode-248-doc-flow-guardrail.md` |
| 2026-07-13 | 統括の復旧と succession の観測を設計材料として残す（実装しないと決定） | `E/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md` §6 |
| 2026-07-16 | **登記**。`oe-register`（手動起動ペインの自己 root 登記・委譲 link・#259） | `E/episodes/2026-07-16-episode-259-oe-register.md` |
| 2026-07-17 | spawn 段の owner 承認ハンドシェイク v0（#262） | `E/decisions/2026-07-17-decision-spawn-permission-handshake.md` |
| 2026-07-21〜25 | negative knowledge ループ（収穫 store・brief への注入・観測）#272〜#274 | `E/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`、`E/episodes/2026-07-23..25-*` |
| 2026-07-28 | episode の本文層と振り返り層を read/write 契約で分離（#284） | `E/decisions/2026-07-28-decision-episode-layer-read-write-contract.md` |

### 1.4 検知の作り直しと運用の穴埋め（2026-08）

| 日付 | 節目 | 根拠 |
|---|---|---|
| 2026-08-03 | **受領の印（2 代目）**。配送シグナルが逆を指していたので、受け手側の `prompt_received`（hook が打つ）へ置き換え（#299）。`oe-selfcheck` もこの単位（#299 P3） | `E/episodes/2026-08-03-episode-299-delivery-receipt.md` |
| 2026-08-08〜12 | フックの発火記録 `oe-hookfire`（#309）と exit code の帯の整理 | `E/episodes/2026-08-08-episode-309-hook-firing-record.md` ほか |
| 2026-08-10 | 子の状態を親が判定するレシピ。「画面から承認を読まない」規範 | `E/episodes/2026-08-10-episode-239-child-liveness-recipe.md` |
| 2026-08-11〜13 | `oe-selfcheck` の定期実行配線は park（#301） | `E/plans/2026-08-11-plan-301-selfcheck-scheduling.md` 冒頭 |
| 2026-08-14 | registry GC の全消しを修正（#270・運用中 3 回発生） | `E/episodes/2026-08-14-episode-270-registry-gc-wipe.md` |
| 2026-08-27〜30 | `oe-threads`、`oe-tree` にモデル名と context% を表示（#327） | `E/episodes/2026-08-28-episode-327-session-model-ctx.md` ほか |

### 1.5 到達・交代（2026-09）

| 日付 | 節目 | 根拠 |
|---|---|---|
| 2026-09-07 | SO レーンの空返しの分類（#303 / #344）。`oe-lane-explain` | `E/plans/2026-09-07-plan-303-so-lane-failure-classification.md` |
| 2026-09-11 | 到達の照合 `oe-confirm` と launchd 常駐（#336）。「見張りは session の外に置く」decision。owner が cockpit の改善順序を「1. 通信経路を手厚く → 2. 交代と復帰」と裁定 | `E/episodes/2026-09-11-episode-336-delivery-receipt.md`、`E/decisions/2026-09-11-decision-watchdog-outside-session.md`、`E/episodes/2026-09-11-episode-390-supervisor-planned-succession.md` |
| 2026-09-11〜13 | **handoff**。`oe-handoff`（prepare / start / take / retire・#390・PR 4 本）。この頃の統括は 13〜15 代目 | `E/plans/2026-09-11-plan-390-supervisor-planned-succession.md` ほか 3 本 |
| 2026-09-14〜10-12 | engine の木に episode が 1 本も無い空白（約 1 か月）。理由は文書からは分からない（推測: 作業が `docs/harness/` と別リポジトリに寄っていた。`docs/harness/episodes/` にはこの期間 3 本ある） | `E/episodes/` の一覧、`docs/harness/episodes/2026-09-25-*`・`2026-10-07-*`・`2026-10-08-*` |

### 1.6 判断ボード・lease・recover・入口（2026-10〜11）

| 日付 | 節目 | 根拠 |
|---|---|---|
| 2026-10-05〜06 | 統括が owner の承認を `oe-send` で中継したとき、auto モードの判定器が送信を 2 回止めた → `oe-*` の allow は配らないと決定（#407・10-20） | `docs/harness/decisions/2026-10-20-decision-407-oe-allow-rules-distribution.md` |
| 2026-10-07 | 枝の作業から出た昇格は同じ PR に入れる（#411） | `E/decisions/2026-10-07-decision-411-branch-promotion-in-same-pr.md` |
| 2026-10-18 | 承認後の plan の変化を 3 級（記録・補正・変更）に分ける（#391） | `E/decisions/2026-10-18-decision-391-post-approval-plan-change-classes.md` |
| 2026-10-19〜29 | 人向けページ `html-one-pager`（#428 ほか・harness 側） | `docs/harness/decisions/2026-10-19-decision-428-human-page-format.md` ほか |
| 2026-10-24〜29 | **判断ボード**。統括ごとに 1 枚で owner への問いを受けて回収（#466 → #538 → #545 → #550）。スキル `judgment-board-flow` と台帳 `ledger.py` | `E/decisions/2026-10-24-decision-466-page-lifecycle-in-flow.md`、`2026-10-25-decision-538-*`、`2026-10-29-decision-545-*` |
| 2026-10-27 | 統括が落ちて子 3 本の宛先が切れた（#577 が lean 決定を覆す引き金と読んだ出来事） | `E/decisions/2026-11-06-decision-577-record-identity-key.md` の「decision #188・#206・#238/#239 との関係」表 |
| 2026-11-06〜09 | **lease**。「誰か」を `lease_id` + `generation` の記録で持ち、ペインは属性にする（#577・I0〜I6）。統括は 23 代目（gen23） | `E/decisions/2026-11-06-decision-577-record-identity-key.md`、`E/plans/2026-11-06-plan-577-record-identity-key.md` |
| 2026-11-08 | **recover**。`oe-recover`（応答しない統括の復帰・#355・クラッシュ drill 1 回）。統括のセッション名 `cockpit <repo> gen<代>`（#576） | `E/decisions/2026-11-08-decision-355-supervisor-recovery.md`、`2026-11-08-decision-576-supervisor-session-name.md` |
| 2026-11-10 | **入口 `oe` の 1 本化**（#605・PR #617）。旧 `bin/oe`（1 サイクル本体）は `oe run` へ | `E/decisions/2026-11-10-decision-605-single-entry-command.md` |

### 1.7 統括の代の進み（文書に出てくる代の表記から）

| 文書の日付 | 代 | 根拠（その表記が出る文書の日付範囲） |
|---|---|---|
| 2026-07-09 | 3〜4 代 | `E/decisions/2026-07-09-decision-238-239-*`「統括3代→4代」 |
| 2026-07-14 頃 | 7 代目 | grep「7代目」の最初の文書 |
| 2026-09-11〜13 | 13〜15 代目 | `E/episodes/2026-09-11..13-episode-390-*` |
| 2026-10-18〜24 | 19 代目 | grep「19代目」 |
| 2026-10-27〜29 | 21 代目 | grep「21代目」 |
| 2026-11-06〜08 | 23 代目（gen23） | grep「23代目\|gen23」 |

4 か月で約 20 回の交代。ならすと 6 日に 1 回ほどになる（割り算は筆者の計算。代の数え方が途中で変わっていないかは確かめていない）。

## 2. decision の一覧

### 2.1 engine の木（24 本）

status の列は frontmatter のまま。`accepted` と `stable` が混ざっているのは時期の違い（〜07-09 は `accepted`、07-17 以降は `stable`、#577 だけ `accepted`）で、意味の違いは文書からは読み取れなかった。

| # | 日付 | 題（短縮） | status | 一言の中身 | いまの効き方（筆者の見立て） |
|---|---|---|---|---|---|
| DI-14 | 05-14 | クリーンアップ戦略 | accepted | `trap` + `wez pane kill` で一括停止。専用 registry は作らない | 本体 `oe run` の範囲だけ。本体は 06-04 以降使われていない |
| DI-10 | 05-14 | #20 Phase 2 合流点 | accepted | Step 4-1 完了後に wez の Phase 3 へ | 歴史 |
| DI-13 | 05-14 | 権限分離は MVP で実装しない | accepted | 子は親と同じ権限。前提は「個人開発環境での単独利用」 | **柱として残る**（07-17 の handshake は別軸と明記） |
| 4-3 | 05-16 | 検証ゲート v1 | accepted | Compliance Review のみ・end-of-session 発火・pane-keyed KVS | 本体の範囲だけ |
| 4-4 | 05-18 | reviewer 出力を file redirect | accepted | `tee` でログに落として tail で走査 | #114 で target にも拡張 |
| #188 | 06-19 | identity を pane 層で統一しない | accepted | 永続マップを作らず read 時に相関 | **部分的に上書き**（DJ-188-4 は #206、DJ-188-3 の tmux 部分は #577） |
| #206 | 06-22 | 活動ログは自己完結イベント | accepted | emit 時に from/to を焼き込む append-only。終了や stall は推論しない | **柱**（#577 が snapshot に `lease_id` を足すだけ） |
| #114 | 06-30 | クリーン取得チャネル | accepted | 非対話 one-shot の file-redirect が正準。scrape は降格 | 本体の範囲。対話 TUI は defer のまま |
| #92 | 07-01 | 検証入力は commit 範囲 | accepted | `baseline..end` を評価。worker-commit 契約 | 本体の範囲 |
| #206A | 07-02 | 受領印は `oe-ack` | accepted | 受けた側が明示的に打つ。frontier snapshot | 残るが、到達の確認は #299 の `prompt_received` が主になった（位置づけの見直しは `E/episodes/2026-08-03-episode-299-delivery-receipt.md`） |
| #238/#239 | 07-09 | succession / watchdog は lean | accepted | 新しい engine state を作らない。board schema + statusLine 拍動 + session 外 cron。seat は先送り | **identity について #577 が覆した**。declared / observed / producer の形は残る |
| #238 board | 07-10 | board schema | **draft** | START HERE board に frontmatter と必須節 | **未適用**。§9（09-11）で「実 board は legacy の自由記述を続ける」、§10 で「`現統括` は表示、正本は lease」 |
| handshake | 07-17 | spawn 段の owner 承認 | stable | 判定器は迂回しない。`--print-approval` と digest で承認と実行を束縛 | **柱**（承認の成立条件は常時ロードの規範層に置く、も追記） |
| #284 | 07-28 | episode の 2 層を契約で分離 | stable | closure は pointer でよい（再掲を求めない） | 文書規約 |
| watchdog | 09-11 | 見張りは session の外 | stable | launchd に置き、沈黙は別主体が検知。出口は閉じていないと明記 | **柱** |
| #411 | 10-07 | 昇格は同じ PR に | stable | マージ前に着地 | 文書規約 |
| #391 | 10-18 | 承認後の plan 変化の 3 級 | stable | 再承認は「変更」だけ | 文書規約 |
| #466 | 10-24 | 判断ボード 1 枚 | stable | 決定 25 個。owner への問いは統括ごとに 1 枚 | **柱**（一部を #538・#545 が具体化・追補） |
| #538 | 10-25 | 判断ボードの流れはスキルに | stable | `judgment-board-flow` は engine の部品。台帳 `ledger.py` | 効いている |
| #545 | 10-29 | 会話で聞いてよい例外 | stable | 生きた子が 0 か、owner が始めた問答だけ | #538 の決定 7 の一部を置き換え |
| #577 | 11-06 | 「誰か」は lease の記録 | accepted | `lease_id` + `generation`、`binding`、`epoch` の CAS。transport は tmux の send-keys のまま | **いまの中心の柱**。移行の負債は #603 |
| #355 | 11-08 | 統括の復帰 | stable | generation を進めず binding だけ張り替え、派生記録は lease から作り直す | 効いている |
| #576 | 11-08 | 統括のセッション名 | stable | `cockpit <repo> gen<代>` | 効いている |
| #605 | 11-10 | 入口 `oe` 1 本 | stable | verb は平らに並べる。入口は振り分けるだけ | 最新 |

根拠はすべて `E/decisions/<日付>-decision-*.md` の「決定」節。

### 2.2 上書き・矛盾の関係

- **#188 → #206**: DJ-188-4（`session_id` 主キーの event bus）を、自己完結イベントへ精緻化。`E/decisions/2026-06-22-decision-206-*.md`「これにより DJ-188-4 を部分的に supersede」。
- **#188 → #577**: DJ-188-3（永続マップを作らない）を tmux の子と統括について置き換え。理由は前提の変化で、#577 は「いま使っているのは `oe-delegate`（tmux）だけ」と書く。`E/decisions/2026-11-06-decision-577-*.md`「前提の変化」。
- **#238/#239 lean → #577**: 「新しい engine state を作らない・seat は先送り」を identity について覆した。#577 自身が「`lease` は新しい engine state であり、#238/#239 が…退けたものに当たる」と書いている。4 か月で逆向きに振れた、いちばん大きい転回。
- **plan-390 のゲート3 回答1 → #577**: 「席に lease と fencing を入れない」を、lease の記録への書き込みに限って更新（CAS は入れるが本格的な fencing は入れない）。`E/decisions/2026-11-06-decision-577-*.md`「plan-390 のゲート3 の回答1 との関係」。
- **board schema §9 → §10**: 「移行後は frontmatter の `現統括` が正本」を「表示であり、正本は lease」に上書き。`E/decisions/2026-07-10-decision-238-board-schema.md` §9・§10。
- **#538 決定 7 → #545**: 会話で聞いてよい例外の当て方を、見える条件に置き換え。
- **#206A の `oe-ack` と #299 の `prompt_received`**: 受領の印が 2 種類ある（actor が打つ印と hook が打つ印）。decision にはなっておらず episode にある。`oe-report` は 06-08 に legacy と呼ばれ、11-09 の時点でもまだ消せていない（`E/decisions/2026-11-06-decision-577-*.md` D19 の追記）。
- 矛盾として残っているもの（筆者の見立て）:
  - README の「目的」節は「構造化ドキュメントのルーティングエンジン」のままで、冒頭の説明（統括と子を動かす CLI 群）と合っていない（5 節）。
  - #564（用語集）の改名案は `lib/seat.sh` を正本の名前にするが、#577 でその lib は表示の書き手に下がった。どちらを先にするかは未決（`E/decisions/2026-11-06-decision-577-*.md`「#564 との関係」）。

### 2.3 いまも効いている設計の柱（筆者のまとめ）

1. Bash + jq の薄い verb、常駐の管理プロセスを持たない（05-13 discussion 論点 7、#577「検討した選択肢」で常駐を不採用）。
2. transport は tmux の send-keys のまま、Claude Code への依存は文書化された環境変数だけ（#577 D10）。
3. 記録は自己完結の append-only イベント、観測者は read-only（#206、#188 DJ-188-5）。
4. 見張りは session の外、沈黙の検知は別主体（09-11 watchdog）。1 枚の画面から状態を決めない（07-09 decision の追記節）。
5. 安全機構（auto モードの判定器）を迂回しない。承認は「受け取った経路」だけ（07-17 handshake、harness #407）。
6. 「誰か」は lease の記録、ペインは属性（#577）。
7. owner への問いは判断ボード 1 枚（#466）。
8. 権限分離はしない（DI-13）。

### 2.4 engine の木の外にある関係する decision

- `docs/orchestration-engine/decisions/2026-03-30-decision-quality-gate-skip-prevention.md`、`2026-04-05-decision-no-promote-master-push-ban.md`: engine より前（03〜04 月）の品質ゲートの決定 2 本。
- `docs/harness/decisions/2026-10-20-decision-407-oe-allow-rules-distribution.md`: `oe-*` の allow を配らない。
- `docs/harness/decisions/2026-10-19-decision-428-*`、`2026-10-23-decision-478-*`、`2026-10-24-decision-536-*`、`2026-10-29-decision-558-*`: 判断ボードが載る `html-one-pager` の決定。

## 3. 繰り返し出てくる失敗・痛み

言及ファイル数は `E/` の 4 つの型を grep した数で、事故の回数ではない。

### 3.1 配送の取りこぼし（いちばん長く続いている）

- 言及: episode 45 / plan 21 / discussion 12 / decision 10（「不達・届かな・未達・取りこぼ」など）。
- 対策の単位が少なくとも 6 回ある。#144（06-09）→ #154（06-16）→ #239 段階 0（07-09）→ #299（08-03）→ #336（09-11）→ #577 D6・D14 と #355 D3 の `delivery_held`（11 月）。
- 代表例と数字:
  - 06-09: 自動 Enter が間欠的に「吸収」される。clean な環境では再現不能（12/12・20/20 成功）で「機構は論証で選ぶしかない」。`E/episodes/2026-06-09-episode-oe-send-finalize-ingestion.md`
  - 06-16: exit 0 を返すのに届かない。主トリガは受け手の tmux copy-mode。`E/episodes/2026-06-16-episode-oe-send-copymode-guard.md`
  - 08-03: 入れた検知器（`delivery_signal`）が逆を指していた。`suspected_miss` の 244/250（97.6%）が実は到達。`E/episodes/2026-08-03-episode-299-delivery-receipt.md`
  - 09-11: nonce 付き送信 927 件のうち受領印なしが 210 件。うち 142 件は受け手が印を書けなかっただけ。素朴な 2 値判定だと「およそ 4 件に 1 件が偽陽性」。計装済みの統括宛ての間欠不達は 18 件中 2 件。`E/episodes/2026-09-11-episode-336-delivery-receipt.md`
- 型: 「届かない」そのものより、**届いたかを確かめる仕組みが外れる**ことが繰り返されている（#144 の finalize は silent、#206 の signal は反転、#336 で 3 値に）。

### 3.2 統括の context 枯渇と交代

- 言及: 「succession・交代・handoff」episode 31 / plan 15 / discussion 11 / decision 11。
- 代は 07-09 の 3〜4 代から 11-06 の 23 代へ（1.7 節）。
- 07-09 の時点で故障モード 4 つ（context 肥大死・お見合い・チャネル脆弱・state 乖離）。`E/decisions/2026-07-09-decision-238-239-*.md` コンテキスト。
- 交代の手間: 「立ち上げプロンプト 36 行と引き継ぎ brief 50 行を毎回人が手で書き」。`E/episodes/2026-09-11-episode-390-supervisor-planned-succession.md`
- 復帰: 「2026-09-09 から 10-30 までの5回の復帰では、そのたびに統括が手で3〜4つの直し」。`E/plans/2026-11-08-plan-355-supervisor-recovery.md:34`（[unverified-summary] と記載）
- 外部化 state である succession board 自体が膨らんだ: 389,999 バイト、`現統括:` の 1 行だけで 5,831 バイト・ペイン表記 42 個。`E/decisions/2026-07-10-decision-238-board-schema.md` §9

### 3.3 ペイン番号の取り違え・キーの寿命

- 言及: episode 15 / plan 11 / discussion 4 / decision 4。
- 代表例:
  - 07-13: 後継の統括が、死んだ前任の「子」として表示され、稼働中の別の統括（AI）を誤誘導した。`E/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md` §2.1
  - 08-14: registry GC が生きている全 entry を消す。運用中に 3 回、うち 1 回は別ツリーの cockpit も巻き添え。`E/episodes/2026-08-14-episode-270-registry-gc-wipe.md`
  - 10-27: 統括が落ちて子 3 本の宛先が切れた。`E/decisions/2026-11-06-decision-577-*.md`
  - 11-06 の棚卸し: ペインを「誰か」のキーに兼ねている箇所は「統括が数えた36本より多い」（外に 7 本）。`E/discussions/2026-11-06-discussion-577-record-identity-key.md` §3
- #188（06-19）で「永続マップを作らない」と決め、#247 で do-nothing と決め（07-12・`E/discussions/2026-07-13-*` §7）、#577（11-06）で覆した。同じ痛みに対して 3 回判断している。

### 3.4 判定器・承認まわりで止まる

- 言及: episode 5 / plan 2 / decision 2 と少ないが、決定は重い。
- 07-17: elevated な子の spawn を auto-mode classifier が止め「混乱した往復」。`E/episodes/2026-07-17-episode-262-permission-handshake.md`
- 08-10: 補完のゴーストテキストが、待っている承認の文面に見える。`E/decisions/2026-07-17-decision-spawn-permission-handshake.md` の追記節「当時の前提」
- 10-05〜06: 承認の中継を判定器が 2 回止めた。`docs/harness/decisions/2026-10-20-decision-407-*.md`
- 11-08: 閉じるコマンドを判定器が止めるか「実機で分からず」、verb には持たせなかった。`E/decisions/2026-11-08-decision-355-supervisor-recovery.md` D4

### 3.5 画面を読んで誤判定する（scrape の系譜）

- 05-18: viewport-only で marker を取りこぼし、初回 smoke が失敗。`E/decisions/2026-05-18-decision-reviewer-output-file-redirect.md`
- 05-30（#112）・07-06（#101）: 字下げ・markdown 引用との偶然一致。
- 07-05（#224）・07-09（#233）・10-13（#242）: 生 capture の貼り付けで会話が malform。言及 episode 11。
- 08-10: 「画面 1 枚・CPU 累積・入力欄表示で子の状態を判定するな」が negative knowledge に（観測 4 件）。`E/knowledge/items/01KZKWJM1KTAFN22XK0WP0F96J.md`

### 3.6 owner の判断待ちが流れる・重なる

- 10-24: 「10-17〜10-23 に owner に判定を求めたページは15枚」「14枚のうち12枚で、会話が答えの経路に入っていた」。`E/decisions/2026-10-24-decision-466-*.md` コンテキスト
- 10-27: 生きた子 3 体の状態で会話で聞き、約 30 分で割り込み 6 件以上、同じ問いを 5 回書き直した。`E/decisions/2026-10-29-decision-545-*.md`
- 10-27〜28: アカウント切り替えで判断ボードが読めなくなり「2日で3回作り直し」。`E/episodes/2026-10-29-episode-550-board-recreate-on-account-switch.md`
- 判断ボードの問いの通し番号は 10-24 の Q1 から 11-10 の Q105 まで進んでいる（18 日で約 105 問。`E/decisions/2026-11-10-decision-605-*.md` の Q103〜Q105）。

### 3.7 SO（セカンドオピニオン）ゲートの重さと不安定

- 「refuted」に言及する episode は 53 本。SO レーンの空返し・未返却は episode 17 本。
- 07-09: 実装 SO を 2 周回して両方 refuted のまま、指摘はテストで確証して閉じた。`E/episodes/2026-07-09-episode-239-report-undelivered-watchdog.md`
- 06-09: 1 つの送信修正に so-gate を 5 回（各タイムアウト 600 秒）。`E/episodes/2026-06-09-episode-oe-send-finalize-ingestion.md`
- 空返しの原因分類が独立の単位になった（#303 / #344・09-07）。

### 3.8 同じ小さな型の直しが issue を分けて続く

- jq / awk の失敗の握り潰しを exit 2 にそろえる: #283 → #424 → #427 → #442（10-13〜17）。4 本の episode で計 931 行。`E/episodes/2026-10-13-episode-283-*`・`-424-*`・`2026-10-16-episode-427-*`・`2026-10-17-episode-442-*`
- exit code の帯: #309 の本体と残件 3 本と #309 取り残し（08-08〜12）。
- bash 3.2 / BSD / ロケール: 言及 episode 39 本（#193・#419・#313・#340・#343 など）。
- 「握り潰し・黙って」: 言及 episode 41 本。negative knowledge でも観測 8 件（`01KYA7C9NN…`）。

### 3.9 AI の作業規律の失敗（knowledge store から）

- knowledge item は 69 件。観測が多い順に: 上流の断定を自分の成果物へ書き写す（観測 21）、「漏れがないこと」を保証する述語の設計（10）、「実績が 1 件でもあれば ok」という健全性チェック（10）、先例の作法の引き写し（10）、受入項目の書き方（10）。`E/knowledge/items/` の `observations` の数。
- 69 件のうち観測 0 件が 23 件（収穫したが再発が観測されていない、または観測の書き戻しが行われていない。どちらかは文書からは分からない）。
- engine の機構の失敗より、**委譲された子の作業の質**についての item が大半を占める。

## 4. 決めたのに実装されていない・途中で止まっている計画

### 4.1 止まっている・先送りのもの

| 項目 | 状態 | 根拠 |
|---|---|---|
| Phase 5（Epic #105・パイプライン駆動・`oe discuss / kickoff / plan …` のサブコマンド体系・ECS target case） | discussion は `draft`、open questions 6 個が未チェックのまま。実装は Slice A（`oe-capture`・05-26）だけ。以後の文書に続きが無い | `E/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md` §9・§12、`E/plans/2026-05-18-kickoff-phase-5-direction.md`（履歴アーカイブと明記） |
| 本体エンジン `oe run`（1 サイクル自律） | 06-04 以降の実行記録なし。派生 issue #93（nonce marker）は open、#92 の multi-pane 帰属は残 | `E/discussions/2026-11-06-discussion-577-*.md` §2.1、`projects/orchestration-engine/README.md` 派生 Issue 表 |
| board schema の実 board への適用 | decision は `draft`。「当面は移行せず legacy の自由記述を続ける」 | `E/decisions/2026-07-10-decision-238-board-schema.md` §9 |
| #239 段階 2（pane-capture heuristic）・succession の observed 層 | 制約だけ決めて未実装。07-13 に「今は実装しない」 | `E/decisions/2026-07-09-decision-238-239-*.md`「段階2 以降」、`E/discussions/2026-07-13-*` §6 |
| #301 `oe-selfcheck` の定期実行 | park（08-13）。理由は「`broken` の読み手（出口）が未確定」。再開条件は可視化（#281 / #169）の着地 | `E/plans/2026-08-11-plan-301-selfcheck-scheduling.md` 冒頭 |
| #289 / #291 報告を発火させる機構 | #289 は park、#291 の plan は `halted-unconverged` で破棄、親側の検知 1 点だけ設計単位で閉じた | `E/episodes/2026-08-10-episode-291-parent-side-detection.md` |
| #303 SO 空返しの分類を消費者へ届ける（I-2） | plan は `in-development`。「I-2 の確定版はその後の裁定で決める」。episode 3 本が `draft` | `E/plans/2026-09-07-plan-303-so-lane-failure-classification.md:184,324` |
| 見張りの「出口」（誰が検査を走らせ誰が読むか） | 「本決定では閉じない」 | `E/decisions/2026-09-11-decision-watchdog-outside-session.md` 決定 4 |
| #577 の移行の後片付け（registry の両方書き・`oe-lease adopt`・`PARENT_TMUX_PANE`・`oe-report`） | #603 へ。lease を持たない統括 3 つと古い子 5 つが生きていたので外せなかった | `E/decisions/2026-11-06-decision-577-*.md` D11・D19 の追記、`E/plans/2026-11-06-plan-577-*.md` |
| #355 の残り（別の会話が持ち場を引き取る口・報告の受け箱・SessionStart hook による自動復帰・サスペンドに近い形） | 「決めていないこと」 | `E/decisions/2026-11-08-decision-355-supervisor-recovery.md` |
| 判断ボードの U2（#539 作業の表）・U4（#540 出し忘れを知らせる hook と verb）・U3（SO のまとめ・#329） | スキルに「まだ決めていないこと」と残る。SO のまとめは owner が保留 | `canonical/skills/judgment-board-flow/SKILL.md:395`、`E/decisions/2026-10-24-decision-466-*.md` 決定 21・25 |
| #537 engine を独立したパッケージにする | 複数の decision が「見越して」設計しているが、engine の木に #537 自体の plan / decision は無い | `E/decisions/2026-10-25-decision-538-*.md` 決定 1、`2026-11-08-decision-576-*.md`、`2026-11-10-decision-605-*.md` |
| #609 復帰のコマンドの名前、#564 用語集の改名 | 未決 | `E/decisions/2026-11-10-decision-605-*.md` 決定 2、`2026-11-06-decision-577-*.md` |
| 権限分離（DI-13）、対話 TUI の取得チャネル（#114 決定 4）、raw log の機械強制（#185） | 再開の条件つきで defer のまま | 各 decision |

### 4.2 status が実態と合っていないもの（注意）

- plan 40 本のうち status が `draft` のものが 17 本あるが、対応する episode が `stable` で verb も `bin/` にあるものが大半（例: `E/plans/2026-09-11-plan-336-delivery-receipt.md` は `draft` だが `oe-confirm` と launchd の plist がある。`2026-08-14-plan-270-*`、`2026-08-27-plan-327-*`、`2026-07-11-plan-239-pr-b-*` も同じ）。
- 10-18 以降の plan は status の行にコメントで「実装完了（日付・PR 番号）」を書くようになり、ここからは信用できる。
- したがって **plan の status だけでは「止まっている計画」は判定できない**。4.1 は本文から拾った。
- 06-10 の episode 品質監査も「『後で追記』型の先送りは観測範囲で 100% 不履行」と書いている。`docs/research/2026-06-10-episode-quality-audit.md` §0

## 5. 「engine は何を目指すツールか」の記述と、その変化

### 5.1 時期ごとの原文

- **2026-05-13（MVP の定義）** `E/discussions/2026-05-13-discussion-engine-scope-and-goals.md` 論点 4
  > メインエージェントがサブエージェントを spawn し、ポーリングベースで状態監視・割り込みできる（オープンループ自律サイクル）
  > `spawn → liveness/progress取得 → completion/blocked検知 → interrupt可能 → artifact handoff` の 1 サイクルが、人間が常駐しなくても完走する
  - 非目的: 「『リアルタイム event-driven bus』は MVP では構築しない」「汎用ツール（rtk 等）の導入はしない」
  - 想定利用者: 「MVP のスコープは **個人開発環境での単独利用**」（`E/decisions/2026-05-14-decision-permission-separation-mvp.md`）
- **README の「目的」節（いまも残る）** `projects/orchestration-engine/README.md`
  > 構造化ドキュメントのルーティングエンジンを Bash + jq で薄く実装し、AI コーディングエージェント間のタスク・コンテキスト受け渡しを自動化する。
- **2026-05-19（MVP 直後の自己評価）** `E/episodes/2026-05-19-retrospective-post-phase-4-baseline-vs-engine-and-target-case.md` §3
  > baseline 単体で 80% は足りる、残り 20% の "独立 adversarial review が必須" な用途に特化した instrument
  > engine は **「daily driver」ではなく「specialized instrument」** に近い。
- **2026-05-19（Phase 5 方針）** `E/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md` §1.3・§2.2・§8
  > engine を daily driver ではなく **パイプライン上の特定ステージで起動される道具** として再定位する。
  > ツール完成度ではなく、**実際のワークフローが回るかどうか** で判断する
  > **コンテキストが本質**。…ツールレイヤーは薄く保ち、不要になったら捨てられる（Build to Delete）。
  - target case（owner）: 「サービス開発で想定している EC2 の ECS 化および IaC 化のようなものを最初のディスカッションで半自動的にやり、必要な Human in the Loop を挟みながら、最終的にコードベースは全て実装を任せる」
- **2026-06-08（委譲への転回）** `E/episodes/2026-06-08-episode-oe-delegate-redesign.md`
  > トポロジは **統括スレッド（親・作業しない）→ 子 N 個（2-3 並列）のスター型**。孫委譲は無い
  > 「ワンラリー（kick→report の1往復閉ループ）にするなら、それは Claude 組み込み subagent の劣化版でしかない」。delegate の価値は *開いた・並列・人間が覗ける対話セッションへのキック* にあり
- **2026-07-09（統括の扱い）** `E/decisions/2026-07-09-decision-238-239-*.md`、`2026-07-10-decision-238-board-schema.md`
  > owner が反復して明示したのは **過剰設計注意** — gap は「**構造と鮮度**」であって succession 機構の存在ではない。
  > 統括は使い捨てで state が正本
- **2026-08-13（優先度）** `E/plans/2026-08-11-plan-301-selfcheck-scheduling.md`
  > **本当に優先度が高いのは cockpit の可視化**（#281 / #169。何をやり取りし、何回やり取りし、今どういう状態かの把握）。
- **2026-09-11（owner）** `E/episodes/2026-09-11-episode-390-supervisor-planned-succession.md`
  > 「統括自体をシームレスに復活できる仕組み・あまりプロンプトを使わないでできる形」
  - 改善の順序: 「1. 通信経路を手厚く → 2. 交代と復帰」
- **2026-10-24（owner・第一目的）** `E/decisions/2026-10-24-decision-466-page-lifecycle-in-flow.md`
  > 本質的に求めたいのは、そのいっぱい複数あって並列で動いてるタスクに迷わない、対応することを迷わない認知負荷が減るっていうのが第一目的なんで
- **2026-11-06（依存の線）** `E/decisions/2026-11-06-decision-577-*.md` D10
  > Claude Code への依存を深めないので、セッション間の文を送る機能には乗らず
- **2026-10〜11（配布の方向）** #537「engine を挙動を変えずに独立したパッケージにしていく」（`E/discussions/2026-10-24-discussion-466-*.md` の注、`E/decisions/2026-11-10-decision-605-*.md`「#537 で engine を外に出すときに見直す」）
- **いまの README 冒頭**
  > 複数の AI コーディングエージェント（Claude Code・Cursor・Codex）のセッションを、統括（親）と子に分けて動かすための Bash + jq の CLI 群。人間は WezTerm + tmux の画面（cockpit）で全体を見て介入し、統括のセッションが子へ作業を渡し、報告を受け、交代する。

### 5.2 変化のまとめ（筆者の読み）

| 時期 | engine とは | 人の位置 |
|---|---|---|
| 05 月 | 非対話で 1 サイクルを自律に回すルーティングエンジン（異 CLI・異モデルのレビュー付き） | 常駐しない |
| 05-19 | 特定ステージで起動される専用の道具。多段パイプラインへ広げる構想 | ゲートで承認 |
| 06 月〜 | 人が覗ける対話セッションを並列に起こして渡す委譲の道具 + cockpit | 画面を見て介入する |
| 07〜09 月 | 長く走る統括を見張り、交代させる仕組み | 異変に気づく役から外したい |
| 10〜11 月 | owner の判断を 1 枚に集め、統括が落ちても持ち場が続く記録（lease）を持つ道具。独立パッケージ化の方向 | 判断だけを返す |

- 05-19 に定めた「パイプライン駆動」の方針を明示的に取り下げた文書は見つからなかった。06-08 の委譲の再設計から実際の重心が移り、README の構成表だけが書き換わった（推測: 取り下げたのではなく、dogfood の必要から委譲と cockpit が先に育った）。
- 想定利用者は一貫して owner 1 人。ただし「別リポジトリの統括」が 08-10・10-27・11-09 に出てきて、hub の外でも使われている。`E/episodes/2026-08-10-episode-239-child-liveness-recipe.md`、`E/decisions/2026-10-29-decision-545-*.md`
- 非目的として明文で残っているもの: リアルタイム bus（05-13）、権限分離（DI-13）、対話子の lifecycle を完了 enum に押し込むこと（#188 DJ-188-2）、常駐の管理プロセス・本格的な fencing・Claude Code の cross-session messaging（#577）、`oe-*` の allow の配布（#407）。

## 6. 文書の量と、文書体系が負担になっている兆候

### 6.1 実測（2026-11-10・`*.md` のみ）

| 木 | decision | discussion | episode | plan | knowledge |
|---|---|---|---|---|---|
| `projects/orchestration-engine/docs/` | 24 本 / 2,634 行 | 26 本 / 6,615 行 | 118 本 / 23,101 行 | 40 本 / 12,748 行 | 70 本 / 2,945 行 |
| `docs/orchestration-engine/` | 2 / 104 | 0 | 9 / 2,685 | 4 / 2,730 | 7 / 265 |
| `docs/harness/`（参考） | 10 / 810 | 4 / 1,366 | 28 / 10,327 | 20 / 9,680 | 24 / 799 |

- engine の木の合計は 278 本・48,043 行・約 5.7MB。
- 日付の範囲は 2026-05-13〜2026-11-10（root の `docs/orchestration-engine/decisions/` だけ 03-30・04-05）。
- status の分布（engine の木と root の木の 300 本）: stable 165 / active 77（knowledge item）/ draft 29 / accepted 12 / in-development 6 / closed 4 / ready 3 / confirmed 3 / 無し 1。
- コードとの比: `bin/` 10,818 行 + `lib/` 4,808 行 = 15,626 行、`tests/` 17,986 行。蒸留文書はコード本体の約 3 倍（割り算は筆者）。
- 配っているスキルのうち engine の運用を縛るもの 7 本で 1,881 行（`doc-flow-guardrail` 220・`delegate-task` 346・`judgment-board-flow` 398 など）。

### 6.2 1 本あたりの長さの変化（engine の木）

| 月 | episode の本数 | 平均行数 | plan の本数 | 平均行数 |
|---|---|---|---|---|
| 05 | 20 | 128 | 12 | 344 |
| 06 | 20 | 101 | 4 | 124 |
| 07 | 30 | 117 | 2 | 137 |
| 08 | 16 | 366 | 7 | 358 |
| 09 | 10 | 449 | 6 | 369 |
| 10 | 15 | 203 | 3 | 681 |
| 11 | 7 | 224 | 6 | 180 |

- 08 月から episode が 3〜4 倍に伸びた（07-14 の `doc-flow-guardrail`、07-28 の episode 層の契約のあと）。最長は `E/episodes/2026-09-12-episode-390-retire-and-docs.md` の 1,259 行。
- plan の最長は `E/plans/2026-10-18-plan-391-post-approval-baseline.md` の 1,035 行で、中身は「承認のあとに plan が変わったときの扱い」という規則の文面である。

### 6.3 負担の兆候（根拠つき）

1. **文書フローそのものを直す作業が、engine の木の大きな割合を占める。** 題名から数えると、07-12 以降の decision 12 本のうち 6 本が機構ではなく文書と手順の決まり（#284・#411・#391・#466・#538・#545）。episode でも #248・#249・#250・#263・#284（2 本）・#288（2 本）・#289・#290・#293・#319・#391 が文書・ゲートの単位。
2. **二重執筆が実測されている。** 「二重執筆は 6/6 で再現した」。原因は closure の外部チェックの合格条件だった。`E/decisions/2026-07-28-decision-episode-layer-read-write-contract.md`「実データで見えた本当の欠陥」
3. **小さな直しにも重い記録が付く。** jq の exit 2 そろえ 4 件で episode 931 行（3.8 節）。`validate-knowledge` の引数 1 件の直しで 71〜74 行（`E/episodes/2026-10-29-episode-531-*`・`-532-*`）。
4. **status が保守されていない。** plan の `draft` 17 本の大半は実装済み（4.2 節）。Step 4-2 の episode 1 本は frontmatter が無い（`E/episodes/2026-05-15-episode-step-4-2-phase-e-integration-validation.md`）。`document-format.md` 自身も 3 か月 draft だった（`E/discussions/2026-07-12-*` G6）。
5. **人が全体を見渡せないことが、早くから問題として書かれている。** 05-31 の時点で「層が深く分散していて、全体像…が一望できない」「Issue が 30 件超フラットに溜まり」。`docs/draft/orchestration-engine-human-facing-summary-brief.md` §1。この brief 自体が `draft` のまま。
6. **昇格と転記の手間。** episode → decision の相互リンク率は 13〜19%（07-12）。設計級の文書が git の外に滞留（proposal 27k / 32k）。後追いの昇格が繰り返される（`E/episodes/2026-07-28-episode-284-decision-backfill.md`、`E/episodes/2026-09-11-episode-336-*.md`「昇格（後追い・owner の指摘を受けて）」）。「reconstructed・後追い」に言及する episode は 61 本。
7. **規則が増えるたびに、それを検査する規則が要る。** negative knowledge に「規範を新設・改訂し、同時にそれを検査するゲートを…」（観測 9）、「漏れがないことを保証する述語」（観測 10）。`E/knowledge/items/01KYJ76D7C…`・`01KYJ76D83…`
8. **決定の読み手が決定を読み違える。** 「既存の decision の決定を前提にして…要約の名前で…」（観測 4）。`E/knowledge/items/01M5PKRS6W…`。#577 の decision は、前の決定 6 つとの関係表を自分で持たないと書けなかった。
9. **owner 自身の言葉。** 第一目的は「認知負荷が減る」こと（10-24）、「過去の判断は別に残さなくていい」（#466 決定 4 の根拠）、「過剰設計注意」（07-09）。
10. **外部化した state も膨らむ。** succession board 390KB（3.2 節）。

- 逆向きの材料（負担だけではない）: 07-12 の棚卸しは「committed 蒸留5段の後半（plan → episode → decision）は機能している」と評価している。#577 の設計は過去の decision と episode を引いて前提の変化を特定できている。したがって「文書が役に立っていない」とは言えず、**書く量と保守の手間が、読む人（owner）の利得に対して大きい**という形の兆候である（この一文は筆者の評価）。

## 7. 見取り図を作るときに効きそうな論点（筆者の整理・推測を含む）

- engine の名前の下に、性質の違うものが 3 つ入っている: (a) 06-04 以降使われていない 1 サイクル本体（`oe run`・検証ゲート・監査ログ）、(b) 毎日使われている委譲と cockpit と lease、(c) 文書フローと判断ボードの手順（スキル）。README の「目的」は (a) の言葉、冒頭は (b) の言葉で書かれている。
- 4 か月の実装の大半は「tmux の send-keys で対話セッションへ文を送る」ことの信頼性と、「長く走る統括が落ちる」ことへの手当てに使われている。どちらも #577 で「transport は変えない・Claude Code に寄らない」と選び直した直後である。
- 05-19 の「specialized instrument」「Build to Delete」と、10〜11 月の「独立したパッケージ」は向きが違う。どちらが今の意図かを書いた文書は無い。
- 可視化（#281 / #169）は 08-13 に「本当に優先度が高い」とされ、#301 の再開条件にもなっているが、engine の木にその plan は無い（判断ボードが一部を担った、と読める。推測）。

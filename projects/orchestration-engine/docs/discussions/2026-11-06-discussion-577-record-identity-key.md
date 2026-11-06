---
id: "01M6PD1RG4MAY08XKJHFAQZNZ2"
title: "#577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする — 棚卸しと設計の判断"
date: 2026-11-06
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577"
    reason: "本 discussion の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577#issuecomment-6664844569"
    reason: "着手時の認識合わせの確定版。棚卸しの出発点（36本）と、別モデルが挙げた3件（ID が何を指すか・取り合わない決まり・送る前の確かめ）はここから来た"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "一部を置き換える前の決定（pane の層で統一しない・永続の対応表を作らない）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-22-decision-206-activity-log-self-contained-events.md"
    reason: "events を自己完結の snapshot にした決定。この設計は snapshot に `lease_id` を足す"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md"
    reason: "seat を薄い pointer として先送りした決定。再開の条件（報告の宛先が切れることの再発）がこの issue の動機に当たる"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md"
    reason: "交代を並列の継承として表す原則（§4）と、張り替えの手順の候補（§5）"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-06-episode-577-record-identity-key.md"
    reason: "作業の記録。網羅の確かめの経緯と、実機と公式の文書で確かめた事実"
  - type: reference
    ref: "projects/orchestration-engine/docs/plans/2026-11-06-plan-577-record-identity-key.md"
    reason: "この設計を実装に分けた plan"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "この設計の decision の案（proposed）"
tags: [orchestration, registry, identity, supervisor, delegation, design, discussion]
---

# #577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする — 棚卸しと設計の判断

## 1. この文書の位置づけ

#577 の設計までの委譲で書いた、棚卸しと設計の判断の記録である。棚卸しの表（§3）と設計の判断（§5）が主で、決まったことは decision の案に、実装の分け方は plan に移す。作業の経緯（何をどの順で確かめたか）は episode にある。

verification status のタグは `evidence-verification-rule` の意味で使う。`[verified]` は筆者が一次の実体（ファイルの行・公式の文書の行・実機の出力）を開いて確かめたもの、`[unverified-summary]` は出典はあるが筆者が行まで当てていないもの、`[speculation]` は根拠の無い見立てである。

## 2. 前提の変化

### 2.1 decision #188 の前提は、いまの使い方と合っていない

- decision #188（2026-06-19）は、WezTerm のペインで子を起こす engine の `oe`と、tmux のペインで子を起こす `oe-delegate`が並んでいた時期の決定である。2つのペインの番号の世界には対応が物理的に無いので、ペインの層で統一しない（DJ-188-1）、永続の対応表を作らず読むときに突き合わせる（DJ-188-3）と決めた [verified]（`projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md` の「決定」節）。
- いま使っているのは `oe-delegate`（tmux）だけである。engine の `oe`（WezTerm）の state は 2026-06-04 のファイルが最後で、それより新しいものは0件である [verified]（`projects/orchestration-engine/state/` を列挙した・2026-11-06）。tmux で子を起こした event（`child_spawned`）は 431 件あり、最新は 2026-11-05 UTC である [verified]（`~/.claude/state/oe-events.jsonl` を読むだけで数えた）。
- したがって「2つの番号の世界を揃えない」は今も正しいが、「永続の対応表を作らない」の理由（揃える相手がいない・#114 で意味が変わる）は、tmux の子と統括については当たらなくなった。この設計が置き換えるのはその部分である（§6）。

### 2.2 セッションは自分の session_id と pid を知っている

- 確定版と #355 は「いまの Claude Code には、セッションが自分の session_id を名乗る経路が無い」を前提にしていた。`lib/handoff-state.sh` の `oe_hs_session_for_pane` の注記も同じことを書いている [verified]（同ファイルの「残る穴」の注記）。
- 公式の文書では、`CLAUDE_CODE_SESSION_ID` が Bash と hook の子プロセスに入り、hook の入力の `session_id` と一致し、`/clear` で更新され、`--resume <session-id>` では resume した id が入る。`--continue` と id を付けない `--resume` で「起動したときの id が入ることがある」と書かれているのは、stdio の MCP server の子プロセスについての文の続きで、その前の文が「`--resume <session-id>` では resume した id が入り、hook と Bash と一致する」と比べている [verified]（https://code.claude.com/docs/en/env-vars.md の `CLAUDE_CODE_SESSION_ID` の行）。つまり Bash と hook では、id を付けない resume でもいまの session_id が入ると読める。ただし id を付けない resume で実際にそうなるかは確かめていない [unverified-summary]（plan の R1 で確かめる）。この行の読みは、最初は「id を付けない resume では Bash と hook にも起動したときの id が入りうる」と取り違えていて、統括の指摘（2026-11-06）で直した（episode の「訂正」）。
- `CLAUDE_PID` は Claude Code 自身の pid で、Bash と hook の子プロセスに入る（v2.1.214 以降）[verified]（同じ表の `CLAUDE_PID` の行）。
- この子のセッション（2.1.318）で、`CLAUDE_CODE_SESSION_ID` の名前の heartbeat の sidecar の pane が自分の `TMUX_PANE` と一致し、`CLAUDE_PID` がペインの端末のフォアグラウンドのプロセスグループの番号と一致した [verified]（episode の「実機で確かめた2つの観測」）。
- 同じマシンのセッションどうしが tmux を通らずに文を送る機能（cross-session messaging）がある（v2.1.224 以降）[verified]（https://code.claude.com/docs/en/cross-session-messaging.md）。この issue で transport に採るかは owner に聞いた（§5 の DJ-10）。

## 3. 棚卸し — ペインを何に使っているか

### 3.1 分け方

ペインの番号（と tmux server の pid）の使い方を、次の4つに分ける。

- **キー**: 記録のファイル名・JSON のキー・重複を除くキーなど、「誰か」を決めるのにペインを使っている。ペインが消えるか番号が使い回されると、誰かが分からなくなるか、別人と取り違える。
- **宛先**: 文を送る・画面を読む・閉じる・選ぶ、の操作の相手としてペインを使っている。この使い方は残る（owner の言う「疎通のところ」）。
- **本人確認**: そのペインにいまいるのが誰か、生きているかを確かめるのにペインを使っている。
- **表示**: 人に見せるだけ。

表の行の多くは、棚卸しの調査（engine の `bin/`・`lib/` と、それ以外の hook・scripts・スキルの文を2つに分けて、読むだけで行番号まで洗った）の報告から写した。そのため、とくに断らない行は `[unverified-summary]` である。筆者が行を開いて確かめたものには `[verified]` を付けた。行番号は 2026-11-06 の `0662dab` のものである。

### 3.2 ペインか tmux server の pid を持つ記録

| 記録 | ペインの使い方 | 書く側 | 読む側 | この設計での扱い |
|---|---|---|---|---|
| registry `~/.claude/state/oe-delegate/<server_pid>_<pane>.json`（`{pane,label,workspace,parent_pane,role}`） | キー（ファイル名）・キー（`parent_pane` は server の pid を持たない `%N`） [verified]（`lib/delegate-registry.sh` の `_oe_reg_key`・`oe_reg_record`） | `oe_reg_record`（`oe-delegate`・`oe-register`・`oe-handoff take`） | `oe_reg_resolve`・`oe_reg_list`（`oe-send`・`oe-list`・`oe-select`・`oe-status`・`oe-ack`・`oe-jump`）・`lib/event-bus.sh`・`oe-ident`・`oe-tree`・`oe-register`・`lib/handoff-state.sh` | 移行のあいだは複製として書き続け、キーの役目を `lease` の記録へ移す（DJ-11） |
| current_supervisor（succession board の `現統括:` の行） | キー（server の pid も `generation` も持たない `%N`） [verified]（`lib/seat.sh` の `oe_seat_resolve`） | `lib/seat.sh` の `oe_seat_rewrite`（`oe-handoff take`） | `oe_seat_resolve`（`oe-vitals`・`oe-handoff take`・`retire`） | 正本を `lease` の記録へ移し、行は表示として書き続ける（DJ-12） |
| 子の環境変数 `PARENT_TMUX_PANE` | 宛先（起動時に焼き込み・あとから変わらない） [verified]（`bin/oe-delegate` の `cmd="PARENT_TMUX_PANE=... claude"`） | `oe-delegate` | `oe-report`・子が読むスキルの文（`oe-send "$PARENT_TMUX_PANE"`） | `OE_LEASE_ID` を足し、親の `lease` から引く（DJ-15） |
| `/tmp/oe-parent-<N>`（ペインの番号の数字だけ） | キー（server の pid を持たない） [verified]（`bin/oe-report` の `PARENT_FILE`） | engine の中には書く側が無い（手で置く） | `oe-report` | `lease` の記録で引くので要らなくなる。実装の段階で消すかを決める |
| heartbeat `~/.claude/state/oe-heartbeat/<session_id>.json`（`{ts,context_pct,pane,server_pid,model}`） | 本人確認（ペインと session_id をつなぐ唯一の観測） | `canonical/claude/statusline/statusline-oe-heartbeat.sh` | `lib/handoff-state.sh`（ペインと server の両方で絞る）・`oe-tree` と `oe-threads`（server が空でも受ける）・`oe-vitals`（ペインだけで絞る [verified]（`bin/oe-vitals` の `[[ "$p_pane" == "$SUP" ]]`））・`oe-selfcheck`・`scripts/measure-delivery-arrival.py`（ペインだけ） | 観測として残し、`lease_id` と `generation` を足す（DJ-3）。読む側の絞り方を1つの関数にそろえる（§7 の採った指摘） |
| pane-issue `~/.claude/state/pane-issue/<server_pid>_<pane>`（`{name}`） | キー（ファイル名）・表示（セッション名） | `scripts/wt/wt-pane-issue.sh`（worktrunk の post-switch）・`canonical/hooks/scripts/session-name.sh` | `oe_reg_resolve`（ラベルを先にここから引く）・`lib/event-bus.sh`・`oe-ident`・`oe-tree`・`oe-threads`・`oe-prompt-receipt.sh` | 表示の用途だけ残し、宛先を決める用途から外す（DJ-15） |
| event `~/.claude/state/oe-events.jsonl` | キー（from と to の `{pane,role,label}`。server の pid を持つのは `supervisor_succession` だけ [verified]（`schemas/oe-events.schema.json` の `server_pid` の説明）） | `lib/event-bus.sh`（`oe-send`・`oe-delegate`・`oe-ack`・`oe-handoff`）・`oe-prompt-receipt.sh` | `oe-ack`・`oe-activity`・`oe-confirm`・`oe-undelivered`・`oe-selfcheck`・`lib/event-bus.sh` の `oe_event_succession_recorded` | snapshot に `lease_id` と `generation` を足す（DJ-13） |
| 受領の診断 `~/.claude/state/oe-receipt-diag.jsonl`（`{nonce,pane}`） | キー（nonce とペインの組で照合） | `oe-prompt-receipt.sh` | `oe-confirm` | 変えない（nonce が主のキーで、ペインは照合の補助） |
| `oe-confirm` の `seen` の記録 `~/.claude/state/oe-confirm/seen`（`pane\|%N`・`delivery\|nonce\|%to`） | キー（server の pid を持たない） [verified]（`bin/oe-confirm` の `notify_hits+=("pane\|${pane}")`） | `oe-confirm` | `oe-confirm` | キーに `lease_id` か server の pid を足す。tmux を起こし直して番号が使い回されると、別の子が消えたことを知らせない |
| `oe-undelivered` の `seen` の記録（`%c\|%p\|ts\|idx`） | キー（server の pid を持たない） | `oe-undelivered` | `oe-undelivered` | 同上 |
| `oe-jump` の最後の宛先 `~/.claude/state/oe-jump/last-target` | 宛先（`%N` を後で使い直す） | `oe-jump --record` | `oe-jump` | `lease_id` を書けるようにする。優先は低い |
| 引き継ぎ文書の機械の節 `<workspace>/.oe/handoff.md` | 本人確認（前任のペイン・server の pid・`pane_pid` とコマンド名・session_id を1組で持ち、閉じる直前に照らす。全部の組を持って照らし直す唯一の記録） | `oe-handoff prepare` | `oe-handoff retire` | `lease` の記録の `generation` の `binding` を正本にし、機械の節は複製にする（DJ-9） |
| `oe-vitals` の `seen` の記録（`kind\|session_id`） | ペインを持たない | `oe-vitals` | `oe-vitals` | 変えない |
| engine の `oe` の記録（`audit/<sid>.jsonl`・`state/<sid>.state.json`・`/tmp/oe-<sid>-*`・`oe-view/viewer-pane-id`） | キー（WezTerm の整数のペイン。session_id の中に閉じている） | `lib/spawn.sh` ほか | `lib/verify.sh`・`oe-status` | 範囲の外（DJ-14） |

### 3.3 verb とスクリプトごとの使い方

| ファイル | キー | 宛先 | 本人確認 | 表示 | 36本に入るか |
|---|---|---|---|---|---|
| `lib/delegate-registry.sh` | registry と pane-issue のキーを作る・掃除で消す | 生の `%N` を確かめずに通す（`oe_reg_resolve`） | 生きたペインの一覧・server の世代 | `oe_reg_list` | 入る |
| `lib/seat.sh` | board の current_supervisor を読み書きする（compare-and-swap あり） | — | — | — | **入らない** |
| `lib/handoff-state.sh` | heartbeat から session_id を逆引きする | — | `pane_pid` とそのコマンド名・ペインの生死 | 子の一覧 | 入る |
| `lib/event-bus.sh` | event の snapshot を書く・registry から role と label を焼き込む | — | 交代の event を server の pid で照らす | — | 入る |
| `lib/delegate-send.sh` | `message_sent` を書く | 文を送る・画面を読む（確かめ）・Enter を送り直す | ペインの生死 | — | 入る |
| `bin/oe-send` | `oe_reg_resolve` で宛先を決める | 文を送る | — | 送った宛先 | **入らない** |
| `bin/oe-list`・`bin/oe-status` | `oe_reg_list` | — | — | 一覧 | **入らない** |
| `bin/oe-delegate` | registry・event・`PARENT_TMUX_PANE` | ペインを分けて子を起こす・最初の1行を送る | 起動の確かめ | — | 入る |
| `bin/oe-register` | registry（root・link） | — | 保存された親のペインの生死 | — | 入る |
| `bin/oe-handoff` | `lease`・registry・引き継ぎ文書・event | 後継を起こす・前任を閉じる | 前任の組（ペイン・server・`pane_pid`・コマンド名・session_id） | 案内 | 入る |
| `bin/oe-report` | `/tmp/oe-parent-<N>` | 親へ送る | — | — | 入る |
| `bin/oe-tree` | registry の親子の辺・heartbeat の束ね方 | `oe-jump` | ペインの生死・観測側の server の pid | 木 | 入る |
| `bin/oe-vitals` | board の current_supervisor・heartbeat（ペインだけで絞る） | 知らせる | current_supervisor のペインの生死で「死」を決める | 知らせの文 | 入る |
| `bin/oe-confirm`・`bin/oe-undelivered`・`bin/oe-ack`・`bin/oe-activity` | event の from と to のペインで照らす・`seen` の記録 | 知らせる | ペインの生死 | 一覧 | 入る |
| `bin/oe-threads`・`bin/oe-ident`・`bin/oe-jump`・`bin/oe-select`・`bin/oe-selfcheck`・`bin/oe-kick` | heartbeat・pane-issue・registry | 選ぶ・画面を読む・送る | ペインの生死 | 表示 | 入る |
| `canonical/claude/statusline/statusline-oe-heartbeat.sh` | heartbeat の sidecar を書く | — | — | — | **入らない**（36本の走査の外のディレクトリ） |
| `canonical/hooks/scripts/oe-prompt-receipt.sh` | 受領の event と診断を書く | — | — | — | 入る |
| `canonical/hooks/scripts/session-name.sh`・`scripts/wt/wt-pane-issue.sh` | pane-issue を読み書きする | — | — | セッション名 | 入る |
| `canonical/hooks/scripts/notify.sh` | — | 知らせを自分のペインの端末へ書く | — | 知らせの文 | 入る |
| `scripts/measure-delivery-arrival.py` | heartbeat のペインと event の `to.pane` を突き合わせる（server の pid を見ない） | — | — | — | **入らない** |
| `scripts/validate-board.sh` | board の `現統括` のキーがあるか | — | — | — | **入らない** |
| engine の `oe`（`bin/oe`・`oe-capture`・`oe-view`・`lib/spawn.sh` ほか） | WezTerm の整数のペイン | WezTerm のペイン | — | — | 一部が入る（範囲の外） |

ペインを使わないファイルは、`bin/oe-hookfire`・`oe-refute`・`oe-review`・`oe-lane-explain`、`lib/sanitize.sh`・`session.sh`・`so-verdict.sh` である。

### 3.4 配布しているスキルの文

| スキル | ペインに頼っている指示 | この設計での扱い |
|---|---|---|
| `delegate-task` | 宛先は label か `%N`・`oe-register link %N`・子の報告は `oe-send "$PARENT_TMUX_PANE"`・`#{pane_pid}` で生死を見る・宛先は registry と pane-issue の合わせ | `lease_id` と label で送る形と、親の `lease` へ送る形を書き足す。`%N` の形はフォールバックとして残す |
| `doc-flow-guardrail` | 委譲固定節「報告の宛先」（明示 → `$PARENT_TMUX_PANE`・交代のあとは `oe-report` を使わない）・brief の「報告の宛先: %N」・交代の後継が子を `%N` で付け替える・復帰で board の `現統括:` を新しいペインへ張り替える | 「報告の宛先」を、`OE_LEASE_ID` のある子では親の `lease` へ送る形に置き換える。付け替えの手順は要らなくなる |
| `orchestration-toolkit` | verb の概観が、ペインで宛てる送信・移動・registry を前提にしている | 概観を直す |
| `judgment-board-flow`（と `ledger.py`） | 答えを報告の宛先（ペイン）へ `oe-send` で送る・台帳にペインの番号を書いてよい | 宛先の決め方は `doc-flow-guardrail` に従うので、そちらを直せば足りる。台帳は作業層なので変えない |
| `issue-intake` | 子が依頼元のペインへ `oe-send` で送る | 同上 |
| `canonical/orchestration-spec/document-format.md`・`implementer-contract`・`doc-flow-guardrail` の衛生の節 | ペインの番号は揮発的なので、共有される成果物に焼き込まない | 変えない（`lease_id` は揮発的でないので、成果物に書いてよいかは実装の段階で決める） |

`canonical/rules/`・`canonical/agents/`・`canonical/codex/`・`canonical/commands/` には、ペインに頼る指示は無い。

## 4. 網羅の確かめ

統括が数えた36本は、`TMUX_PANE|pane_id|#\{pane` の1つのパターンから出したものである。negative knowledge `01M07QDKE73BTK0Q3K90FE4G9T` のとおり、同じパターンから選んだ対照はそのパターンの盲点を共有する。そこで、パターンの外から2つの対照を選んだ。

- **記録の置き場から逆にたどる**: `~/.claude/state/` にある記録の置き場の名前（`oe-delegate`・`pane-issue`・`oe-heartbeat`・`oe-events` など12個）と、board と引き継ぎ文書の目印（`現統括`・`handoff.md`）で、コードのファイルを逆に引いた。36本に入らないのに記録を読み書きするファイルとして、`bin/oe-send`・`bin/oe-list`・`lib/seat.sh`・`canonical/claude/statusline/statusline-oe-heartbeat.sh`・`scripts/measure-delivery-arrival.py`・`scripts/validate-board.sh`・`bin/oe-status` が出た [verified]（episode の「網羅の確かめ」）。どれも行を開いてペインの使い方を確かめた。
- **event の型の一覧から逆にたどる**: `oe-events.jsonl` の型（`message_sent`・`prompt_received`・`child_spawned`・`report_received`・`supervisor_succession` の5つ）の書く側と読む側を洗い、from と to のペインで照らしている箇所を表に入れた。

網羅の主張は、次の範囲に限る。上の2つの対照と、36本の走査と、2つの調査が使った語（`server_pid`・`現統括`・`%[0-9]`・`pane-issue`・`oe-heartbeat`・`oe-send`・`pane`・`ペイン` など）で走査した範囲では、表の外にペインを「誰か」のキーに使う箇所は見つかっていない。テスト（`projects/orchestration-engine/tests/`）は、どの振る舞いをペインで固定しているかだけを見て、表には入れていない（plan の実装の段階で直す対象になる）。

## 5. 設計の判断

各判断は、選択肢・推奨・理由と、owner に聞いたものは owner の答えを持つ。owner に聞いたのは DJ-1・DJ-7・DJ-10・DJ-11・DJ-17 で、問いは統括のワークスペースの根の作業層の `.oe/question-577-1.json`（DJ-7 の問いは統括が置き換えた）と `.oe/question-577-2.json`（DJ-17）に置いた（答えは統括から届く）。

### 5.0 言葉

新しい概念の名前は、#564 の決まりの案（用語はそのままプログラムの識別子として書ける名前にし、日本語は説明にだけ使う）に合わせる [verified]（https://github.com/stlwolf/ai-development-hub/issues/564 の「決まり（案）」）。既存の識別子は、そのまま使う（`registry`・`heartbeat`・`events`・`receipt`・`pane`・`session_id`・`current_supervisor`・`parent_pane`・`succession`・`transport`）。`transport` は、文を相手のセッションへ届ける手段のことで、いまは tmux の send-keys である（`lib/delegate-send.sh` の冒頭の注記「tmux send-keys で注入する transport」[verified]）。日本語の「道」は名前に使わない。手段や手順の意味では「方法」と書く。

- **`lease`**（人が入れ替わっても続く持ち場）: 「hub の統括」や「#577 の委譲」がそれである。統括の `lease` は交代をまたいで1つ続き、委譲は1件に1つの `lease` を持つ。ID の項目は `lease_id`（ULID）、置き場は `~/.claude/state/oe-lease/<lease_id>.json`、verb は `oe-lease`、環境変数は `OE_LEASE_ID` と `OE_GENERATION` である。名前は Kubernetes の Lease に合わせた（DJ-17・owner の答え Q71）。Kubernetes の Lease と違い、この設計の `lease` は時間で期限切れにならず、持ち主のプロセスの生死で決める（DJ-9）。
- **`generation`**（その `lease` に座った1つの会話）: 既存の識別子である（`oe-handoff --generation` と、events の `supervisor_succession` の `generation`）[verified]（`schemas/oe-events.schema.json` の `generation`）。同じ会話を別のプロセスで resume しても、同じ `generation` のままである。別の会話が `lease` を引き継ぐと（交代）、`generation` が1つ進む。hub の統括の「22代目」が `generation` の 22 である。
- **`binding`**（`generation` と、いまその会話を動かしているプロセスの結び付き）: 項目は claude の pid と開始時刻である。resume でプロセスが替わると、`binding` を張り替える。
- **`epoch`**（`binding` か `generation` が変わるたびに1つ増える番号）: compare-and-swap で比べる値である（DJ-5）。
- **`delivery_held`**（送れなかったことを残す events の型）: DJ-16。owner の答え（Q80）で、この issue から外した（#355 へ回す）。
- **`current_supervisor`**: いまの統括を指す既存の概念で、いまは succession board の `現統括:` の行と `lib/seat.sh` が持つ。この設計では、統括の `lease` のいまの `generation` が current_supervisor の機械の正本になる（DJ-12）。#564 は `lib/seat.sh` を `lib/current-supervisor.sh` に直す案を持っていて、`seat` を current_supervisor の意味から外す方向なので、新しい概念に `seat` を使わない。
- owner が答えている途中の問い（判断ボードの Q65〜Q67 と Q69）は、「席」と「代」の言葉で書いてある。答えは、席を `lease`、代を `generation` に読み替えて入れる。

### DJ-1 ID が何を指すか（owner に聞いた）

- 選択肢:
  - (a) `lease_id` と `generation` の記録の2段にする。宛先は `lease_id`、本人確認は `generation` の記録で行う。
  - (b) `generation` ごとに ID を作り、後任へのつなぎを記録する。
  - (c) `lease` だけに ID を作り、`generation` を区別しない。
- 推奨: (a)。
- 理由: 子の報告を `lease` に宛てれば、統括が交代しても子の宛先を付け替えずに済む。いまは交代と復帰のたびに子を1本ずつ `oe-register link` で付け替えている（#355 の見取り図の実例の 09-09 と 10-27）[verified]（統括のワークスペースの根の `.oe/map-355-recovery-body.html` の「実例」の表を読むだけで確かめた）。(b) は子の宛先が前任の `generation` を指したまま残り、つなぎを1つでもたどれないと届かない。(c) は退任した前任と現任を見分けられず、owner が答えた「退任した統括を誤って resume する件は、記録に持たせる情報を足せば済む」（#577 の本文）を記録で満たせない。
- owner の答え（2026-11-06・判断ボードの Q65）: (a) を選んだ。補足は「一意に決まるものを区別して2つのリレーションで持つ。1つの ID に2つの意味を持たせない」。
- 答えの当て方: `lease_id` は持ち場だけを指し、1つの `generation` は (`lease_id`, `generation`) の組で一意に決まる。持ち場と `generation` は、それぞれ自分のキーを持つ2つのリレーションとして扱う。置き場（DJ-2）は、ロックを持ち場ごとに取るために1つのファイルに並べるが、その中でも2つを別の表として持ち、1つの項目に2つの意味を持たせない。ファイルを2つに分けるかは、この読みで足りるかをゲート3 で owner に確かめる。

### DJ-2 ID の形と置き場

- **owner の答え（判断ボードの Q73・2026-11-06 22:00 回収）**: 1つのファイルの中の2つの表にする。補足は「意味的に結合して使っているので1つでよい。役割分化が進んだら分けることも考える」。下の (a) で確定した。

- 選択肢:
  - (a) `lease_id` は ULID。記録は `~/.claude/state/oe-lease/<lease_id>.json` に `lease` ごとに1ファイルで置き、`generation` はその中に並べる。
  - (b) `lease` と `generation` を別のディレクトリの別のファイルにする。
  - (c) 1つの JSON Lines に追記していく（イベントの記録として持つ）。
- 推奨: (a)。
- 理由: 書き手は verb だけで、書く回数は `lease` を作るとき・`generation` が替わるとき・`binding` を張り替えるとき・閉じるときに限られる（heartbeat では書かない・DJ-3）。`lease` ごとに1ファイルにすれば、ロックも `lease` ごとに取れる（`lib/seat.sh` の `mkdir` のロックと compare-and-swap の形をそのまま使える [verified]（`lib/seat.sh` の `oe_seat_rewrite`））。hub の統括は22 `generation` なので、`generation` を1ファイルに並べても小さい。(c) は読むたびに畳み込みが要り、「いまの `generation`」を1回の読みで決められない。ULID にするのは、engine がすでに session_id に ULID を使っていて（`lib/session.sh`）、時刻の順に並ぶためである。
- 置き場を `~/.claude/state/` にするのは、いまの registry・heartbeat・event と同じ層（マシンに1つ・リポジトリをまたぐ）に置くためである。ほかのリポジトリの統括も同じ置き場を読む。

### DJ-3 属性と観測の決まり

- 選択肢:
  - (a) `lease` と `generation` の記録には、長く変わらないもの（`lease` の label・workspace・親の `lease`・`generation`・`generation` の状態・その `generation` の session_id の並び・`binding` した claude の pid と開始時刻）だけを持つ。ペインと tmux server の pid は、いままでどおり heartbeat の sidecar に観測として残し、読むときに突き合わせる。heartbeat の sidecar には、環境変数から分かるときだけ `lease_id` と `generation` を書き足す。
  - (b) heartbeat のたびに、`generation` の記録のペインと server の pid を書き換える。
- 推奨: (a)。
- 理由: (b) は statusLine の heartbeat（10秒ごと）と verb の書き込みが同じファイルを取り合い、ロックの待ちが heartbeat の write path に入る。(a) なら書き手が分かれる。sidecar を書くのは producer だけ、`lease` の記録を書くのは verb だけである。属性を読むときの突き合わせは decision #188 の DJ-188-3（読むときに突き合わせる）の形を残す。
- 観測の決まり:
  - ペインと server の pid は、sidecar の `ts` を見た時刻として持つ。読むときは、いまの tmux server の pid と一致し、鮮度の窓の中のものだけを候補にする（いまの `oe_hs_session_for_pane` と同じ絞り方）。
  - 候補のペインは、使う直前に本人確認をしてから使う（DJ-6）。sidecar に書かれていることだけでは使わない。
  - （**owner の答え Q76 で外した**・2026-11-06 22:00 回収）tmux server を、pid だけでなく開始時刻でも区別する案。マシンを起こし直すと同じ pid の別の server がありうる、というゲート1 の Codex の指摘から足したものだった。owner の補足は「復元情報が揃っていればリスクは下がっている。安定性を重視する段階になったら検討する」。server は、いままでどおり pid で区別する。
  - heartbeat からペインを引く規則を、いまは読む側がそれぞれに持っていて、絞り方が違う（`lib/handoff-state.sh` はペインと server の両方、`oe-tree` と `oe-threads` は server が空でも受け、`oe-vitals` はペインだけ）。これを lib の1つの関数にまとめ、読む側は全部それを使う（ゲート1 の Codex の指摘）。ただし、計測の道具 `scripts/measure-delivery-arrival.py` は、この共通化から外し、古い引き方（heartbeat のペインだけで引く）のまま残す（owner の答え Q83「残していて」）。#299 で測った到達率（`suspected_miss` 側 244/250=97.6%・`none` 側 162/217=74.7%・`projects/orchestration-engine/docs/episodes/2026-08-03-episode-299-delivery-receipt.md`）と比べる物差しを変えないためである。
  - `/clear` は、同じプロセスの中で会話を替える。この設計では、`/clear` は `generation` を進めず、`generation` の session_id の並びに新しい id を足すだけにする。宛先は `lease` なので、`/clear` のあとの会話がそのまま `lease` の持ち主として受け取る。統括が `/clear` を使うことはふつう無いが、子では起こりうる。
  - （**owner の答え Q76 で外した**・2026-11-06 22:00 回収。DJ-18 で verb だけで `binding` を書けるようにしたので要らない）プロセスの観測（pid と開始時刻）は、hook でも書ける。公式の文書では `CLAUDE_PID` は hook の子プロセスに入り、SessionStart の hook は `source`（startup・resume・clear・compact・fork）を受け取る [unverified-summary]（文書の確認に出した道具の報告・https://code.claude.com/docs/en/hooks.md）。`lease` の記録を書くのは verb だけのままにし、hook は session_id を名前にした観測のファイルに pid と開始時刻を書くだけにする（ゲート1 の Cursor の案H を一部採った）。hook を土台にしないという #355 の線（「後の砂糖」）は守り、hook が無くても verb だけで `binding` できる形にする。
  - heartbeat の sidecar の候補にするのは、sidecar の session_id が `generation` の session_id の並びにあるか、sidecar の `lease_id` と `generation` がいまの `generation` と一致するものである。どちらも候補を選ぶための手がかりで、使う前には必ず DJ-6 の 4（フォアグラウンドのプロセス）で確かめる。`lease_id` が sidecar に載らない環境（statusLine が環境を受け継がない場合）でも、session_id の並びで絞れる（ゲート2 の Cursor の指摘。statusLine が `OE_LEASE_ID` を受け継ぐことは未検証で、plan の R2 で確かめる）。
  - heartbeat の sidecar に `lease_id` と `generation` を書くのは、producer の環境に `OE_LEASE_ID` と `OE_GENERATION` があるときだけである。環境変数は claude のプロセスごとに持つので、同じプロセスの中の `/clear` で session_id が変わっても、`lease` との結び付きは切れない。statusLine のスクリプトが claude の環境を受け継ぐことは、いまの producer が `TMUX_PANE` を環境から読んでいることから分かる [verified]（`canonical/claude/statusline/statusline-oe-heartbeat.sh` の `pane="${TMUX_PANE:-}"`）。

### DJ-4 掃除の決まり

- **owner の答え（判断ボードの Q78・2026-11-06 22:00 回収）**: 分ける。`oe-lease gc` が消すのは、閉じた `lease` と、heartbeat の sidecar だけにする。書き込みの途中の一時ファイル（`.hb.*`）が残る漏れは、heartbeat を書く側（statusLine の producer）の直しとして別 issue にする（統括が起票）。gc を走らせる契機は、`oe-handoff take` のついでとする。補足は「不要ファイルのクリーンアップ全般は考える必要があるが、今のタイミングでなくてよい」。下の「一時ファイル」の部分は、この答えで外れる。

- 選択肢:
  - (a) `lease` と `generation` は、tmux server の世代やペインの生死では消さない。消すのは、閉じた `lease`（委譲が終わった・統括が `lease` を畳んだ）を、閉じてから一定の日数が過ぎたあとに、明示の掃除（`oe-lease gc`）で消すときだけにする。write path では掃除しない。
  - (b) いまの registry と同じく、書き込みのたびに掃除する。
- 推奨: (a)。
- 理由: いまの `oe_reg_gc` は、書き込みのたびに、いまの server の pid で始まらない記録と、生きていないペインの記録を消す [verified]（`lib/delegate-registry.sh` の `oe_reg_gc`）。そのため tmux を起こし直すと、最初の書き込みで前の server の分がまとめて消え、統括のペインが消えると、次の書き込みでその記録が消える。この issue の目的（ペインが消えても誰が統括で誰がその子かが残る）と正面から食い違う。
- heartbeat の sidecar の掃除も決める。いまは誰も消さず、2026-11-06 の時点で sidecar が約600件と、書き込みの途中の一時ファイル（`.hb.*`）が約1,075件残っている [verified]（`~/.claude/state/oe-heartbeat/` を数えた・読むだけ）。決まりは、開いた `lease` のいまの `generation` の session_id に当たらず、一定の日数より古い sidecar と、1日より古い一時ファイルを、同じ明示の掃除（`oe-lease gc`）で消す、とする。日数は運用の値で、実装の段階で決める。
- registry（`oe-delegate/`）は、移行のあいだは今の掃除のまま残す。誰かの正本でなくなれば、消えても困らない（DJ-11）。

### DJ-5 ID を取り合わない決まり

- **owner の答え（2026-11-06・判断ボードの Q72）**: `epoch` と compare-and-swap は入れるが、効かせるのは `lease` の記録への書き込みだけにする。古い `generation` の送信やファイルの編集まで止める本格的な fencing は入れない。#390 の plan のゲート3 の回答1（「席に排他制御（lease と fencing）を入れない。停止を fencing の代わりに使う」）は、`lease` の記録への書き込みに限って更新する [verified]（`projects/orchestration-engine/docs/plans/2026-09-11-plan-390-supervisor-planned-succession.md` の「ゲート3 — owner の裁定」）。関係は decision の案の「plan-390 のゲート3 の回答1 との関係」にある。

- 決まり:
  - `generation` の `binding` を張り替える（resume したプロセスが `lease` に戻る）・`generation` を進める（交代）は、どちらも `lease` のファイルのロックの中で、期待する値と比べてから書く（compare-and-swap）。期待する値は、下の `epoch` 1つである。`binding` か `generation` が変わるたびに番号が増えるので、番号が同じなら `generation` も `binding` も読んだときのままである（ゲート2 の指摘で、`generation` と `binding` と番号の3つを比べる形から番号1つに寄せた）。
  - `binding` を張り替えてよいのは、いまの `binding` のプロセスが生きていないと機械で確かめられたとき（DJ-9）か、張り替えるプロセスがいまの `binding` のプロセスそのものであるときだけである。生きているか分からないときは張り替えず、人の判断に回す。
  - `generation` を進めてよいのは、前の `generation` が退任を申告したとき（計画的な交代の `oe-handoff take`）か、前の `generation` の `binding` のプロセスが生きていないと機械で確かめられたとき（復帰）だけである。
- 2つの resume が同時に同じ `lease` を取ろうとしたときは、ロックの中で先に書いた側が `binding` を変えるので、あとの側は期待する値と合わずに失敗する。
- この決まりが保証するのは「正本の `binding` が1つになる」までである。復帰のコマンドは先に `claude --resume` を起こし、その会話があとで `oe-lease bind` を打つので、2つ起こせば、compare-and-swap の勝ち負けが決まる前に同じ会話のプロセスが2つ動く。負けた側は bind で失敗して統括の操作に進まない、までを保証の範囲とする（ゲート2 の Codex のやり直しの指摘）。
- 遅れて届いた前任の heartbeat は、`lease` のファイルを書かない（DJ-3）。読む側は、sidecar の `lease` と `generation` と session_id が、いまの `generation` と `binding` に合うものだけを使う。古い `generation` の sidecar は候補から外れる。
- 確定版の［別モデル］の「取ったことを1つに確定し、古い `generation` からの書き換えを拒む決まり」はこれで満たす。
- `lease` の記録には、`binding` か `generation` が変わるたびに1つ増える番号（`epoch`）を持つ。verb が `lease` の記録を書くときも、読んだときの番号と書く直前の番号が同じであることを確かめる（ゲート1 の Codex の指摘）。
- 交代（`oe-handoff take`）は、いまは自己の registry・board の張り替え・交代の event の3つを順に書き、全体は原子的でない [verified]（`bin/oe-handoff` の take の節）。この設計では、`lease` の記録の1回の書き込みを commit point にし、board の行・registry の複製・event は、`lease` の記録から作り直せる派生の記録にする。途中で止まったら、同じ verb をもう一度走らせると、`lease` の記録に合わせて派生の記録を直す（ゲート1 の Codex の指摘）。
- 1つの session_id は、開いた `lease` の `generation` の session_id の並びのうち、1か所にしか入らない。`binding` の verb は、自分の session_id がほかの開いた `lease` にすでに入っていれば、`binding` せずに止まる（ゲート2 の Cursor の指摘。この並びが2か所に入ると、DJ-7 の 2 の照合がどちらの `lease` か決められない）。
- この一意性は、`lease` ごとのロックだけでは守れない。別々の `lease` に同時に bind する2つが、互いの書きかけを見ずに両方成功しうる。session_id を登録する操作（bind と、DJ-18 の登録）は、すべての `lease` に共通の1つのロックの中で、ほかの開いた `lease` の並びを確かめてから書く（ゲート2 の Codex のやり直しの指摘）。
- 親の `lease` を書き換える（子を自分の下に付ける）ときも `epoch` を増やす。増やさないと、2つの付け替えが同じ `epoch` を読み、順に両方成功する（ゲート2 の Codex のやり直しの指摘）。
- 子を自分の下に付ける registry（`oe-register link`）は、いまは読む・確かめる・書くが原子的でない [verified]（`bin/oe-register` の冒頭の注記「限界（TOCTOU）」）。`lease` の記録では、子の `lease` の親を書き換えるときも、子の `lease` のファイルのロックの中で比べてから書く（ゲート1 の Cursor の指摘）。

### DJ-6 送る前の確かめ

- 決まり: `lease` から送るときは、次の順で引き、どれかで外れたら送らない。
  1. `lease` のファイルから、いまの `generation` と `binding`（pid と開始時刻）を読む。
  2. heartbeat の sidecar から、その `generation` の候補のペインを1つ選ぶ（DJ-3 の絞り方。候補が0件か、同じ時刻で2件なら外れ）。
  3. そのペインが `tmux list-panes -a` に現れることを確かめる（`display-message` は不在のペインにも空を返すので使わない [verified]（`lib/handoff-state.sh` の `oe_hs_pane_alive` の注記））。
  4. そのペインの端末のフォアグラウンドのプロセスグループの番号（`ps -t <tty> -o pid,tpgid` の、pid と tpgid が一致する行）が、`binding` の pid と一致し、そのプロセスの開始時刻が `binding` の開始時刻と一致することを確かめる。
- 4 が、いまのコードの穴（`lib/handoff-state.sh` の注記「ペインが短い間に再利用され、新しいセッションがまだ一度も heartbeat を書いていないあいだは、旧世代の session_id を返す」）を閉じる。heartbeat ではなく、tmux と OS が持っているプロセスで確かめるので、heartbeat の遅れに左右されない。
- 外れたときの終了コードは、宛先が無い（1）と分け、「宛先の本人を確かめられない」として返す。番号は実装の段階で、`oe-send` のいまの割り当て（0・1・2・4）とぶつからないものを選ぶ。
- `binding` の pid が記録に無い `lease`（移行の前に作られた `lease` など）は、4 を飛ばさず、確かめられないとして外れにする。外れたときの案内には、生のペインの番号で送るフォールバック（いまの `oe-send %N`）を出す。
- 確定版の［別モデル］の「ID から引いたペインに、操作する時点でも同じ相手がいるかの確かめ。対応を確かめられないときに止める決まり」はこれで満たす。
- （**owner の答え Q76 で外した**・2026-11-06 22:00 回収）Enter の前に 4 の確かめをもう一度行う案。外したので、確かめと Enter のあいだの窓は receipt で後から見つけるだけになる。
- 残る穴: いまの送り方は、文字を入れる・待つ・Enter を送る・場合によって Enter を送り直す、の複数の操作である [verified]（`lib/delegate-send.sh` の `oe_send_line`）。確かめたあと、Enter を送るまでのあいだにペインの中身が替わる窓は閉じられない（ゲート1 の Codex の指摘）。（Enter の前の確かめ直しは owner の答え Q76 で外した。）残る取り違えは、receipt（送った1行の nonce と、受け取ったペインの組）で後から見つける。完全に防ぐとは書かない。
- この窓の取り違えのうち、確かめたあとに同じペインの中で会話が替わった場合（`/clear` や、同じペインでの claude の起こし直し）は、受け取ったペインと nonce が一致するので、いまの receipt では見つけられない。receipt で見つけられるのは、別のペインに届いた場合までである（ゲート2 の Codex のやり直しの指摘）。
- background への fork（#338）でプロセスが替わると、フォアグラウンドのプロセスが `binding` と合わなくなるので、送らずに外れる。fork 先を自動で `lease` の持ち主にはしない（ゲート1 の2つのレーンの指摘）。hub の設定はすでに background への行き来を止めている [unverified-summary]（`canonical/claude/settings.harness.json` の `disableAgentView` の注記・棚卸しの調査の報告による）。

### DJ-7 resume したセッションが自分の ID を知る方法（owner に聞いた）

- 方法は3つあり、上から順に使う。
  1. 環境変数 `OE_LEASE_ID` と `OE_GENERATION`。`oe-delegate` が子を起こすときに入れる（いまの `PARENT_TMUX_PANE` と同じ入れ方 [verified]（`bin/oe-delegate` の `cmd="PARENT_TMUX_PANE=... claude"`））。resume のときは、復帰の手順が出すコマンド（`OE_LEASE_ID=<lease_id> OE_GENERATION=<generation> claude --resume <session_id>`）で入る。
  2. 自分の `CLAUDE_CODE_SESSION_ID` が、ある `generation` の session_id の並びに入っていること。`--resume <id>` では resume した id が入るので、これで決まる。id を付けない resume でも、公式の文書の読みでは Bash と hook にいまの session_id が入るので決まるはずだが、確かめていない（§2.2・plan の R1）。
  3. 会話の記録（brief・引き継ぎ文書）に書いてある `lease_id` を、セッション自身が読み、`oe-lease bind` に渡す。verb は、2 の照合か、いまの `binding` のプロセスが生きていないことの確かめ（DJ-9）が通ったときだけ `binding` を張り替える。2 の照合が通らずに 3 だけで名乗るときは、`lease` の workspace が自分の workspace と一致することを確かめ、統括の `lease` なら owner の確かめを1回求めてから張り替える。ULID を読み違えた `lease` の前の `binding` が、たまたま生きていなければ、機械の確かめだけでは別の `lease` を取ってしまうためである（ゲート2 の Cursor の指摘）。復帰はもともと owner が「復帰して」と頼んで始まるので、確かめはその流れの中で取れる。
  - 1〜3 の方法は「どの `lease` と `generation` か」を決めるだけで、`binding` を張り替えてよいかは、どの方法でも必ず DJ-5 の決まり（前の `binding` のプロセスが生きていないと機械で確かめられたか、本人か）を通す。session_id が一致しても、同じ会話を2つ resume した別のプロセスは本人の `binding` ではないためである（ゲート2 の Codex のやり直しの指摘）。
- 推奨: **resume の打ち方の決まりは、この設計では確定しない（owner の答えで、計測のあとに決める）。** 最初の推奨（id を付けた resume を決まりにする）は、公式の文書の行を取り違えた前提に立っていた（§2.2）。統括は問いを取り下げ、「実機で確かめてから決まりにするかを決める」を推奨にした問いに置き換えた（2026-11-06）。この discussion の側の見立ては、次のとおりである。1 の環境変数を入れるには、どのみち復帰の手順が出すコマンドを写して打つことになるので、そのコマンドに id を付けておく費用は小さい。id を付けない resume で 2 が成り立つかは、R1 の実機で確かめてから決めればよい。
- 確定版は「自分のペインの heartbeat から session_id を引き、ID の記録に照らせば決まる見込み」と書いていた。この方法は、ペインが使い回されて新しいセッションがまだ heartbeat を書いていないあいだに、別の `generation` を自分と取り違えうる（DJ-6 の穴と同じ）。上の 1 と 2 は、セッションの内側の値（環境変数）なので、この穴を持たない。
- owner の答え（2026-11-06・判断ボードの Q69）: 「実機で確かめてから決まりにするかを決める」を選んだ。補足は「一次情報に当たろう。推測するな計測せよ」。
- 答えの当て方: resume の打ち方の決まりは、この設計では決めない。plan の I0（実装の最初の段階）で、id を付けた `--resume`・id を付けない `--resume`・`--continue` のそれぞれで、Bash の `CLAUDE_CODE_SESSION_ID` が何になるかを計測し、その結果で決まりにするかを決める。1〜3 の方法の順は、計測の結果に依らずに残す。

### DJ-8 退任した統括の見分け

- 決まり: `generation` の記録に状態（在任・退任）と、退任した時刻と、後任の `generation` を持つ。`oe-handoff take` が `generation` を進めるときに、前の `generation` を退任にする。
- 退任した `generation` のセッションを誤って resume しても、`oe-lease bind` が自分の `generation` の状態を読み、退任なら「この `generation` は退任している。いまの `generation` は N で、後任はそちら」と返して、統括の操作（`lease` を取る・子へ指示する）に進まない。
- owner の答え（2026-11-06・#577 の本文）の「記録に持たせる情報を足せば済む」を、この状態の項目で満たす。

### DJ-9 生きていないことの機械の確かめ

- 決まり: `generation` の `binding` のプロセス（pid と、`LC_ALL=C ps -o lstart=` の開始時刻）が無ければ、生きていない。同じ pid で開始時刻が違うプロセスは、別のプロセスとして扱う。プロセスがあれば、ペインがあるかどうかに関係なく生きている。
- heartbeat の古さは、生きていないことの根拠にしない。heartbeat はプロセスが生きているあいだは止まらず（decision #238/#239 の「正直な残余」）、逆にプロセスが止まっても sidecar は残る。heartbeat の古さは「生きているが描き直していない」の候補を出すまでに使う。
- negative knowledge `01KZKWJM1KTAFN22XK0WP0F96J` の外れ方を当てた。1つ目（累積 CPU 時間の変化量）と2つ目（1枚の画面）は使っていない。3つ目（`capture-pane` の既定が属性を落とし、補完の薄い文字を実入力と取り違える）も、画面を読まないので当たらない。この決まりが言えるのは「プロセスが生きているか」までで、「入力を待っている」「止まっている」は言えない。owner の答え（#577 の本文）の「同じセッションを2か所で開く件は、生きていないことを機械で確かめてから走らせればよい」は、この確かめを DJ-5 の張り替えの前提に置くことで満たす。
- `binding` するときに、その pid のプロセスのコマンドが claude であることを確かめ、そうでなければ `binding` しない。シェルの pid を誤って `binding` すると、シェルが残るかぎり「生きている」と判定し続け、張り替えられなくなるためである（ゲート2 の Cursor の指摘。いまの `oe-handoff retire` もコマンド名で claude を求めている [verified]（`bin/oe-handoff` の retire の `oe_hs_pid_command` の照合））。`binding` したあとの生死は pid と開始時刻で見る（同じ pid と開始時刻のプロセスのコマンドは変わらない）。
- `binding` の pid が記録に無い `generation` は、生きているか分からないとして扱い、張り替えない（人の判断に回す）。
- プロセスの問い合わせ（`ps`）が失敗したときや出力が取れなかったときは、「生きていない」に畳まず「分からない」として張り替えない。判定は、ある・無い・分からない、の3つで返す（ゲート2 の Codex のやり直しの指摘）。
- この決まりは、`oe-handoff retire` の「シェルで始まるペインの前任を閉じられない」も解く。閉じる直前に、ペインの端末のフォアグラウンドのプロセスが前任の `generation` の `binding` の pid と開始時刻に一致すれば、そのペインにいまいるのは前任本人である。`#{pane_pid}` がシェルでも判定できる。#355 の 2026-11-05 のコメントの「判定の案」の 2 と同じ形で、記録する場所が引き継ぎ文書の機械の節でなく `lease` の記録になる。

### DJ-10 transport を何にするか（owner に聞いた）

- 選択肢:
  - (a) この issue では tmux の send-keys のままにする。
  - (b) この issue で、transport もセッション間の文を送る機能に替える。
- 推奨: (a)。
- 理由: セッション間の文を送る機能は、届いた文が受け手の側の制御（`crossSessionInbound`）を通り、受け手の会話に「ほかのセッションからの文」として入る [verified]（https://code.claude.com/docs/en/cross-session-messaging.md の「How a session treats an incoming message」と「Control inbound messages」）。いまの receipt は、UserPromptSubmit の hook（`oe-prompt-receipt.sh`）が、送った1行の末尾の印を読んで書く。その hook がこの transport で走るかは確かめていない [speculation]。記録のキーの変更と混ぜると、どちらが効いたかを切り分けられない。
- owner の答え（2026-11-06・判断ボードの Q67）: (a) を選んだ。補足は「Claude Code への依存を深めないので乗らない。issue にするまでもない」。別の issue は起こさない。機能の説明は、統括が owner にする。
- 答えの当て方: 最初の推奨にあった「`generation` の記録に inbox socket を持てる形にしておく」も、Claude Code への依存を深める準備なので外した。この設計が Claude Code に頼るのは、文書化された環境変数（`CLAUDE_CODE_SESSION_ID`・`CLAUDE_PID`）だけで、どちらも無いときは DJ-7 の 3 の方法と人の判断に落ちる。

- 参考（owner・2026-11-06）: この機能は採らないが、受け取る側の制御の仕組みは、将来 transport を替えるときの参考になる。原文は https://code.claude.com/docs/en/cross-session-messaging.md で、2026-11-06 に取り直して当てた [verified]（節の名前を括弧に書いた）。
  1. 宛先はペインではなく、セッションごとの inbox socket である（「The session's inbox socket」）。tmux を通らない。
  2. 受け取る側が、届いた文を accept（渡す）・hold（渡さずに知らせを出し、あとで accept が当たれば渡す）・refuse（捨てる）のどれにするかを `crossSessionInbound` で選べる（「Control inbound messages」）。値が無いときは、両方のセッションの permission mode の組で決まる。
  3. 届いた文は命令として実行されず、承認の代わりにもならない（「Commands don't run: a command in the message's text, such as `/compact`, arrives as plain text. Claude Code never executes it.」「It can't approve anything」・「How a session treats an incoming message」）。いまの transport（tmux の send-keys）は入力欄に文字を打つので、送った1行が `/clear` で始まれば実行されうる [speculation]（統括と owner の指摘・確かめていない）。
  4. 相手の状態で届け方を変える。作業中なら道具の呼び出しの合間に読み、動いている道具を止めない。待機中なら新しいターンを始める（「The receiving Claude reads the message between tool calls during an active turn, so a running tool is never interrupted. When the receiving session is idle, Claude Code starts a new turn with the message.」・「Message delivery」）。いまの transport は相手の状態に関係なく打ち込み、Enter が吸収されることがあるので、送ったあとに画面を見て Enter を送り直す（#144・`lib/delegate-send.sh` の冒頭の注記 [verified]）。比べる材料になる。
  5. 送り合いが止まらなくなるのを防ぐ上限がある。受け取る側が送り手ごとに回数を絞り、短いあいだの同じ文を捨て、渡す待ちを50件までにする（「Message loops are throttled」・「Limitations」）。hold した文は100件までで、超えると古いものから捨てる（「Control inbound messages」）。送る側も、短いあいだに送りすぎると送る前に断る（「Rapid bursts to one session are refused at the sender」）。
  6. 届いたことを送り手へ自動で知らせる仕組みは、原文に書かれていない。書かれているのは、受け手の Claude が `SendMessage` で返事をできること（「Message delivery」）と、非対話のセッションで保留が期限を過ぎて捨てられたときに、届けられる送り手へ「expired」を返すこと（「Past the deadline: Claude Code drops the message and reports it as expired to a sender it can reach.」・「Non-interactive sessions」）だけである。engine には、受け手の hook が送った1行の nonce を取り込みの印として書く受領印（receipt・#336）がすでにあり、この点では engine のほうが先にある。
  - 統括の見立て（2026-11-06）: transport を替えるときは、届ける前の制御（accept・hold・refuse・回数の上限・重複の破棄・相手の状態を見て届ける）と、対話中のエージェントへの最後の一歩（端末に打ち込む・道具の受け口）を分けて設計する。記録の正本はテキストのまま（報告のファイル）にする。
  - この参考が transport を替えるときに埋もれないように、transport の唯一の入口 `lib/delegate-send.sh` の冒頭の説明から、この節を指す1行を置く。engine と hook と scripts のコードで `tmux send-keys` を呼ぶのはこのファイルだけである [verified]（`grep -rn 'send-keys'`・2026-11-06。`bin/oe-send` の2行は、手でフォールバックするときの案内の文）（plan の N11・PR-3。owner の指摘「参考に残しても transport を替えるときに埋もれる」）。
  - 別の issue は起こさない（owner の答え）。

### DJ-11 移行の段取り（owner に聞いた）

- 選択肢:
  - (a) しばらくは新しい記録と今の registry を両方書き、読む側を1つずつ切り替える。進行中の委譲は、一度だけの取り込み（`oe-lease adopt`）で引き取る。すでに起きている子は、焼き込まれたペインの番号の宛先のまま終わらせてよい。ほかのリポジトリの統括には、sync の前に知らせる。
  - (b) 全統括を止めて一度に切り替える。
  - (c) 新しい委譲からだけ使い、取り込まない。
- 推奨: (a)。
- 理由: registry と heartbeat の hook は、hub のほかに3つのリポジトリの統括と、その子が使っている（2026-11-06 の `oe-tree` で、hub を含む4つの root が生きていた [verified]（`oe-tree` の出力を読んだ））。(b) は全員の手を止める。(c) は2つの仕組みが長く混ざる。
- `oe-lease adopt` は、いま生きている registry と heartbeat から `lease` と `generation` を作る。`binding` の pid は、そのペインの端末のフォアグラウンドのプロセスから取る（DJ-6 の 4 と同じ取り方）。取り込んだ `lease` の `generation` の session_id は、heartbeat から引けたときだけ入れ、引けなければ空にする（推し量って入れない）。
- owner の答え（2026-11-06・判断ボードの Q66）: (a) を選んだ。補足は「復帰のテストのときに一気に切り替えてもよい。それまでは両方書く。ローカルなのでどちらでもよいが本番ならこの方式」。
- 答えの当て方: 両方書く期間は、復帰のテスト（#355 の drill）までとする。読む側を1つずつ切り替える PR の並びは残し、registry を「誰か」のキーとして読むのをやめる最後の切り替えは、復帰のテストの時に一度に行ってよい（plan の PR-5）。

### DJ-12 current_supervisor（統括の `lease` のいまの `generation`）の正本

- 決まり: 統括の `lease` の「いまの `generation`」と `binding` を、`lease` の記録が機械の正本として持つ。succession board の `現統括:` の行は、`oe-handoff take` が `lease` の記録を書いたあとに、人が読むための表示として書き続ける。`oe-vitals` は `lease` の記録を読む側に切り替える。
- 理由: decision #238 の board schema の §9 は、board の `現統括` を正本にするなら「読み手（`oe-vitals`）と書き手（#390 の verb）を同時に切り替える」作業として切れ、と書いている [verified]（`projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md` の §9「移行するときに何が起きるか」）。この設計は正本を board の外に移すので、読み手と書き手を同じ PR で切り替える（plan の PR 分け）。board の散文の形は変えない（§9 の「当面は legacy の自由記述を続ける」を守る）。
- 三者同期を避ける、とは、三者が常に一致することではなく、一致していなくても機械の判断が1つに決まることである。board の行の書き換えに失敗しても、確定した `lease` の記録を巻き戻したり取り直したりしない（ゲート2 の Codex のやり直しの指摘）。
- decision #238/#239 は seat を「新正本にすると board/seat/registry の三者同期が生じる」として先送りした [verified]（同 decision の「lean を選び seat-keystone を却下した理由」）。この設計では、board の行は表示、registry は移行のあいだの複製、`lease` の記録が正本、と役割を分けるので、三者のどれが正しいかを読み手が選ぶことはない。先送りの再開の条件「報告 stranding が再発したら」は、10-27 の「別のリポジトリはペインが消えて子3本の宛先が切れた」で当たっている [verified]（#355 の見取り図の「実例」の表）。

### DJ-13 events

- 決まり: event の from と to の snapshot に、`lease_id` と `generation` を足す（いまの `{pane, role, label}` は残す）。decision #206 の DJ-206-3（語彙は足すだけで壊さない）に従う。`binding` を張り替えたこと（復帰）を新しい event の型として足す。
- 理由: いまの snapshot はペインだけで、tmux server の名前空間を持たない。`server_pid` を持つのは `supervisor_succession` だけである [unverified-summary]（棚卸しの調査の報告による・`schemas/oe-events.schema.json`）。tmux を起こし直すとペインの番号は `%0` から振り直されるので、snapshot の `%N` だけでは前の server の同じ番号と見分けられない（decision #206 の訂正の節）。`lease_id` を足せば、ペインが変わっても同じ相手だと分かる。

### DJ-14 範囲の外

- engine の `oe`（WezTerm）。DJ-188-1 と DJ-188-2 はそのまま残る。
- 復帰のスキル（#355）・統括のセッション名（#576）・全統括をまとめて戻す形。
- board の frontmatter への移行（board schema の §9 のまま）。
- transport をセッション間の文を送る機能（cross-session messaging）に替えること（DJ-10・owner は採らなかった）。
- pane-issue（セッション名の表示に使う、ペインをキーにした記録）は、表示の用途では残す。`oe-send "#N"` のラベルの引き方は `lease` の記録へ移すので、宛先を決める用途からは外す（DJ-15）。

### DJ-15 送る側の引き方

- **owner の答え（判断ボードの Q77・2026-11-06 22:00 回収）**: 移行のあいだは、`#N` のラベルを `lease` の記録で引けなければ、古い引き方（pane-issue と registry）に落とす。補足は「移行期や互換性を保つときは可能な限りフォールバックを準備する」。
- **owner の答え（判断ボードの Q76・2026-11-06 22:00 回収）**: 下の「古い子も親の `lease` へ送れるようにする」項目は外した。DJ-11 の「`PARENT_TMUX_PANE` しか持たない古い子は、古い宛先のまま終わらせる」を正とする。

- 決まり:
  - `oe-send` の宛先に、`lease_id` と、`lease` の label（`#577` など）を受け付ける。label は `lease` の記録から引き、引けたときは pane-issue を見ない（引けないときは、移行のあいだだけ古い引き方に落とす・Q77）（いまの `oe_reg_resolve` は pane-issue を先に見る [verified]（`lib/delegate-registry.sh` の `oe_reg_resolve`））。生のペインの番号（`%N`）は、いままでどおり受け付ける（移行とフォールバックのため）。
  - 子の報告は、`oe-send --to-parent`（名前は実装の段階で決める）で、自分の `lease`（`OE_LEASE_ID`）の親の `lease` の、いまの `generation` のペインへ送る。統括が交代していても、親の `lease` が同じなら届く。
  - （**owner の答え Q76 で外した**）`OE_LEASE_ID` を持たない子（移行の前に起きた子）でも、親の `lease` へ送る形を使えるようにする。一度だけの取り込み（DJ-11）が子の `lease` に親の `lease` を入れておけば、子は自分の `TMUX_PANE` と server の pid から自分の `lease` を引き、`CLAUDE_PID` が `lease` の `binding` と一致することを確かめてから、親の `lease` へ送れる。自分のペインはその子にとって確かな値なので、他人のペインを引くのとは違って使い回しの穴が無い。これで、移行のあいだに旧い子が交代した統括の前任のペインへ報告を送る取り違えを減らせる（ゲート2 の Cursor の指摘）。
  - `doc-flow-guardrail` の委譲固定節「報告の宛先」の規則（明示の宛先 → `$PARENT_TMUX_PANE`・交代のあとは `oe-report` を使わない）は、`OE_LEASE_ID` がある子では「親の `lease` へ送る」に置き換える。`OE_LEASE_ID` の無い子（移行の前に起きた子）には今の規則を残す。
- ペインを使う操作は、送る・画面を読む・閉じる・選ぶ（`oe-jump`・`oe-select`）の宛先だけになる。どれも、`lease` から引いたペインを使う直前に DJ-6 の確かめを通す。

### DJ-16 送れないときは保留して、`lease` の次の `generation` が拾う（owner の答え Q80 で #355 へ回した）

- **owner の答え（判断ボードの Q80・2026-11-06 22:00 回収）**: この DJ は、`delivery_held` の event と、送れないときに止めて保留する動きの両方ごと、#355（復帰）へ回す。この issue では決めず、実装もしない。補足は「どう拾うかを決めないと後戻りが起きうる。いま必要なくリスクも低いならここで決めない」。DJ-6 の確かめで外れたときは、いまの `oe-send` と同じく、送らずに失敗の終了コードで返すだけにする。
- #355 への申し送り: 送れなかった報告のポインタを残す形（下の案）と、それを誰がどう拾うかを、#355 で一緒に決める。

- 決まり: 子が親の `lease` へ送ろうとして DJ-6 の確かめで外れたとき（親の統括が落ちている・交代の途中）は、送らずに保留の event（型は `delivery_held`）を残して、子は「親の `lease` へ届けられなかった。報告のファイルは置いた」と返す。報告の本体はいままでどおりファイル（`.oe/report-<issue>.md`）に置くので、失われない。`lease` に新しい `generation` が `binding` されたら（復帰か交代）、その `generation` は自分の `lease` あての保留を一覧で拾う。
- 理由: いまの報告は「ファイルが正本、`oe-send` の1行はポインタ」の2段構えで、ファイルは残っている。失われるのはポインタだけである。ゲート1 の Codex の案E（報告を仕事ごとの郵便受けにして、担当が取りに来る）の、「報告を成立させるのに、いまの統括の所在を知らなくてよい」という点だけを採った。郵便受けを新しく作るのではなく、`delivery_held` の event と既存の報告のファイルで足りる。
- 拾う道具は、いまの `oe-confirm`（報告のファイルの走査）と `oe-undelivered`（未着の検知）がある [unverified-summary]（#355 の見取り図の「まだ無いもの」）。どちらを広げるかは、#355（復帰）の側で決める。この issue が決めるのは、`delivery_held` の event を `lease` あてに残すところまでである。

### DJ-17 持ち場の識別子の名前（owner に聞いた）

- 1回目（統括のワークスペースの根の作業層 `.oe/question-577-2.json`・判断ボードの Q70）: 候補を `lineage`（推奨）・`post`・`identity` として聞いた。owner はどれも選ばず、問いは取り下げになった。補足は「lineage は日本人には馴染みが無く一般的でない。一般的か・デファクトかが大きい」。1回目は、既存のコードの識別子とぶつからないかだけで候補を絞っていて、分野で一般に使われているかを調べていなかった。
- 2回目（`.oe/question-577-3.json`）: 分野で一般に使われる呼び方を、各プロジェクトの公式の文書で調べ、出現の根拠つきで出し直した。引用はどれも原文を取って当てた [verified]（下の URL・2026-11-06）。
  - (a) `lease`（推奨）。Kubernetes の Lease の API は「holderIdentity contains the identity of the holder of a current lease.」「leaseTransitions is the number of transitions of a lease between holders.」と書く（https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/lease-v1/）。持ち主が入れ替わっても Lease は1つで、入れ替わった回数を数える。この設計の `generation` が leaseTransitions に当たる。Leases の説明は「New instances of kube-apiserver that use the same hostname will take over existing Leases using a new holder identity, as opposed to instantiating new Lease objects.」と書き（https://kubernetes.io/docs/concepts/architecture/leases/）、日本語版も「既存のLeaseを新しいインスタンスのアイデンティティーを利用して引き継ぎます」と書く（https://kubernetes.io/ja/docs/concepts/architecture/leases/）。用途は「component-level leader election」と「to ensure only one instance of a component is running at any given time」である。弱いところは、Kubernetes の Lease は更新が止まると期限で切れるが、この設計は時間で切らず、持ち主のプロセスの生死で決めること（DJ-9）である。
  - (b) `agent`。AutoGen は「Agent ID uniquely identifies an agent instance within an agent runtime」「It is the “address” of the agent instance for receiving messages」と書き、届けるときに実体が無ければ作る（「it either fetches the instance, or creates it if it does not exist」）（https://microsoft.github.io/autogen/stable/user-guide/core-user-guide/core-concepts/agent-identity-and-lifecycle.html）。宛先が残り実体が替わる形は同じである。弱いところは、Claude Code がセッション間の文を送る機能で1つのセッションを agent と呼び（`ListAgents`）、hub にも `canonical/agents/` があることで、同じ語が3つの意味になる。
  - (c) `actor`。Orleans は「Actors are purely logical entities that always exist, virtually」と、持ち場の側を actor と呼ぶ（https://learn.microsoft.com/en-us/dotnet/orleans/overview）。Akka は名前の側を actor path と呼び（「the path itself does not have a life-cycle, it never becomes invalid」）、作り直したものを「The newly created actor is a new incarnation of the actor」と、実体の側を actor と呼ぶ（https://doc.akka.io/libraries/akka-core/current/general/addressing.html）。実装によって指すものが逆になる。
- 推奨: (a) `lease`。ID の項目は `lease_id`、verb は `oe-lease` になる。
- owner の答え（2026-11-06・判断ボードの Q71）: (a) `lease` を選んだ。補足は「Kubernetes で使っているならデファクト感がある。リースは日本語としても一般的。統括も一通り終われば閉じて立て直すので、永続でない点も合う」。
- 答えの当て方: 文書の仮の名前 `lineage` を `lease` に置き換えた（ID の項目は `lease_id`・verb は `oe-lease`・置き場は `~/.claude/state/oe-lease/`・環境変数は `OE_LEASE_ID`）。この節の1回目の経緯と、episode の 04:09 より前の記録は、そのときの名前 `lineage` のまま残す。

### DJ-18 最初の `binding` と、あとから増える session_id を誰がいつ書くか（P4・分身レビューの指摘）

- 何を決めるか: DJ-5 と DJ-7 は、復帰のときに本人が `oe-lease bind` で束縛を張り替える方法しか書いていなかった。新しく起こした子と、手で立てた統括の最初の `binding`（pid と開始時刻）と session_id を、誰がいつ書くかが抜けていた。`/clear` のあとの新しい session_id を誰が足すかも同じ問いである。
- 選択肢:
  - (a) 起こした側の verb が書く。`oe-delegate`（と `oe-handoff start`）は、子のペインの生存を確かめる時点で、そのペインの端末のフォアグラウンドのプロセスの pid と開始時刻を読み、コマンドが claude であることを確かめて `binding` に書く。
  - (b) 子が brief を読んで、自分で `oe-lease bind` を打つ。
  - (c) SessionStart の hook が書く。
- 推奨: 起こした子と後継の `binding` は (a)、手で立てた統括は本人が `oe-lease create --root`（いまの `oe-register root` に当たる）を Bash で打つ形にする。session_id を正本に登録するのは、本人が動かす `oe-lease` の verb（create・bind・送信）だけにする。その verb は、自分の `CLAUDE_PID` が `binding` の pid と一致するときに、自分の `CLAUDE_CODE_SESSION_ID` を登録する。最初の1つも `/clear` のあとのものも同じである。heartbeat の sidecar の `lease_id` と `generation` は、候補のペインを探す手がかりにだけ使い、session_id の登録の根拠にはしない。session_id を足しても所有は変わらないので、`epoch` は増やさない（P4 では sidecar から足す形にしていたが、ゲート2 の Codex のやり直しで2つの穴が分かって直した。手で立てた統括は環境に `OE_LEASE_ID` を持たないので sidecar に `lease_id` が載らず、最初の session_id が登録されない。sidecar にはプロセスの識別子が無いので、遅れて届いた古いプロセスの sidecar からも足してしまう）。
- 理由:
  - (a) は、機械が決まった時点で書く。`oe-delegate` は claude をペインのコマンドとして起こし、4秒待ってからペインの生存を確かめている [verified]（`bin/oe-delegate` の `build_child_command` と「子ペインの生存確認」の節）。そのため、その時点のペインの最初のプロセスもフォアグラウンドのプロセスも claude である。この子のペイン（`oe-delegate` が起こした）でも、`#{pane_pid}` と端末のフォアグラウンドのプロセスグループの番号が `CLAUDE_PID` と一致した [verified]（episode の「実機で確かめた2つの観測」）。ただし、4秒のあいだに claude がまだ起動の途中である場合の値は確かめていない。PR-2 で確かめる（plan の R4）。
  - (b) はモデルが brief を守るかに頼る。守らなければ、`binding` の無い `lease` が残り、DJ-9 で「生きているか分からない」に倒れ続ける。
  - (c) は、hook を土台にしないという #355 の線と、Claude Code への依存を深めないという owner の答え（Q67）に反する。
  - 手で立てた統括は、起こした側がいないので本人が打つしかない。本人の Bash には `CLAUDE_PID` と `CLAUDE_CODE_SESSION_ID` が入っているので、推し量らずに書ける。
  - 本人の verb が自分の環境の値で登録する形なら、推し量りが入らない。子は報告のときに必ず `oe-send --to-parent` を打つので、最初の報告で session_id が登録される。`/clear` のあとも、次に本人が verb を打った時点で足される。観測者（`oe-tree` など）は登録をしないので、decision #188 の DJ-188-5（観測者は読むだけ）とも食い違わない。
  - 起動の確かめの時点で claude を確かめられなければ（R4 で外れたとき）、`binding` を未確定のまま止める。「4秒経ったから claude だ」とは決めない。
- 確定版に無い判断として plan の N12 にした。

### DJ-19 ペインの本人確認を1つの関数にし、どこに置くか（P4・分身レビューの指摘）

- 何を決めるか: DJ-6 の 4（ペインの端末のフォアグラウンドのプロセスが `binding` の pid と開始時刻に一致するか）を使う側は、adopt・送信・retire・`oe-jump`・`oe-select` の5つある。それぞれに書くと、DJ-3 の heartbeat の引き方と同じく、絞り方がずれていく。
- 選択肢:
  - (a) `lib/delegate-send.sh` に置く。transport の唯一の入口なので、transport を替えるときに一緒に見直せる。
  - (b) tmux に固有の確かめだけを集めた小さな lib（`lib/tmux-pane-identity.sh` など）に置き、`lib/delegate-send.sh` と、adopt・retire・`oe-jump`・`oe-select` がそれを読み込む。
  - (c) `lib/handoff-state.sh` に置く。`pane_pid` とそのコマンド名を引く関数が、すでにここにある。
- 推奨: (b)。PR-1 で作る。
- adopt の使い方は、ほかの4つと違う。ほかの4つは既にある `binding` との照合で、adopt は `binding` が無いところから最初の `binding` を見つける。同じ関数の中で、照合の成功と、発見の成功を分けて返す（ゲート2 の Codex のやり直しの指摘）。
- 理由: 確かめ自体は tmux に固有（ペインから端末を引く）なので、transport を替えるときに一緒に替わる。その点では (a) と同じ向きである。ただし retire・`oe-jump`・adopt は文を送らないので、(a) にすると送る処理の lib ごと読み込むことになる。(c) は交代の lib で、送信や `oe-select` から読むと役割が混ざる。(b) なら、tmux に固有の部分がひとまとまりになり、`lib/delegate-send.sh` の冒頭の説明（N11 の1行）から、この lib も指せる。
- 確定版に無い判断として plan の N13 にした。

### DJ-20 子から親への報告の入口を1本にするか（P4・分身レビューの指摘）

- 何を決めるか: この設計で、子から親への報告の入口が `oe-report`（`PARENT_TMUX_PANE` か `/tmp/oe-parent-<N>` から宛先を引く）と `oe-send --to-parent`（親の `lease` から引く）の2本になる。
- 選択肢:
  - (a) `oe-report` を、`oe-send --to-parent` を呼ぶだけの薄い入口にする。
  - (b) `oe-report` を廃止し、`oe-send --to-parent` に一本化する。
- 推奨: (b)。ただし消すのは、移行の片付け（PR-6）で、`oe-report` を呼びうる古い子が残っていないと確かめてからにする。PR-3 では、配っているスキルの文を `oe-send --to-parent` に替えるところまでにする。起動済みの子の会話や brief に `oe-report` の呼び出しが残っていると、PR-3 で消したとたんに失敗するためである（ゲート2 の Codex のやり直しの指摘）。`/tmp/oe-parent-<N>`（N9）も同じ PR-6 で消す。
- 理由: 配布しているスキル（`delegate-task`）の方針はすでに `oe-send` への一本化で、委譲固定節も「交代のあとは `oe-report` を使わない」と書いている [unverified-summary]（棚卸しの §3.4）。入口が2本あると、古い入口だけが古い宛先を引く、という今の取り違えが残る。(a) にしても、呼ぶ人が `oe-report` と `oe-send --to-parent` のどちらを選ぶかの迷いは残る。
- 確定版に無い判断として plan の N14 にした。

## 6. decision #188・#206・#238/#239 との関係

decision の案に書く内容の下書きである。

- **#188**:
  - DJ-188-1（ペインの層で identity を統一しない）は残す。この設計は、ペインを統一するのではなく、ペインの外に ID を作る。
  - DJ-188-2（engine の session-state の schema を delegate に広げない）は残す。`lease` の記録は engine の `oe` の state とは別の系統である。
  - DJ-188-3（永続の対応表を作らず、読むときに突き合わせる）は、tmux の子と統括について置き換える。「誰か」（`lease` と `generation`）は永続の記録にする。ただし属性（ペインと server）は、いままでどおり読むときに heartbeat と突き合わせる（DJ-3）。
  - DJ-188-4（#206 で精緻化済み）は残す。event は自己完結の snapshot のままで、snapshot に `lease_id` を足す（DJ-13）。
  - DJ-188-5（read-only は観測者を縛る）は残す。この設計は producer の側（verb）に新しい write path を足す。観測者（`oe-tree` など）は読むだけのままである。DJ-188-5 の「本決定は新規書込経路を一切導入しない」は #188 自身の範囲を言った文で、のちの決定を縛るものではないが、#188 の frontmatter は「DJ-188-1/2/3/5 は不変」と書いている。この decision が確定したら、frontmatter に「DJ-188-3 の `oe-delegate`（tmux）の部分を #577 で置き換えた。DJ-188-5 の観測者の線は残る」を足す（ゲート2 の Cursor の指摘）。
- **#206**: DJ-206-1（自己完結の snapshot）と DJ-206-3（語彙は足すだけ）に従う。#206 が後回しにした「server の pid を記録に含めない現状では、同じ server の `%N` の再利用で別の関係が混ざりうる」は、`lease_id` を snapshot に足すことで、足したあとの新しい event について解く。足す前の、`%N` だけの event は、後から確実には見分けられない（ゲート2 の Codex のやり直しの指摘）。
- **board schema の §9**: §9 は「移行後は frontmatter の `現統括` が正本になる」と、将来の board の正本を書いている [verified]（`projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md` の §9「移行するときに何が起きるか」）。この設計は機械の正本を `lease` の記録に置くので、その将来の前提と食い違う。decision の案で、§9 の前提を「board の `現統括` は、frontmatter に移しても表示であり、機械の正本は `lease` の記録である」に上書きすると明記する。§9 の「読み手と書き手を同時に切り替える」の原則は、この設計の切り替え（PR-4）にもそのまま当てる。`scripts/validate-board.sh` が `現統括` のキーを見ることは、表示の行があるかの検査として残す（ゲート2 の Cursor の指摘）。
- **#238/#239**: lean の決定（新しい engine state を作らない・seat は薄い pointer として先送り）を、identity（誰か）について覆す（P4 で「先送りを始める」から言い直した。`lease` は #238/#239 が退けた新しい正本そのものなので、「始める」では覆していることが見えない）。先送りの再開の条件に当たっているかは HG の判断なので、ゲート3 で owner に見せる。先送りの理由だった三者同期（board・seat・registry）は、役割を分けて避ける（DJ-12）。declared の層（board）は人が書く表示として残り、observed の層（watchdog・`oe-vitals`）は `lease` の記録を読む。statusline の heartbeat（producer）と sidecar の形は変えず、項目を足すだけにする。

- **plan-390 のゲート3 の回答1 との関係（Q72 までの経緯・decision の案から移した）**:
  - **この設計で近いところ**: `lease` という新しい正本を作り、`epoch`（世代と束縛が変わるたびに増える番号）で compare-and-swap する（D2・D5）。棄却した案の「compare-and-swap・世代番号」と同じ部品を持つ。
  - **この設計で違うところ**（筆者の見立て・owner の答えで確かめる）: 新しい正本を作ること自体は、#577 の本文の方向（こちらで作る ID を鍵にし、ペインを属性にする）と、owner の答え Q65（2つのリレーションで持つ）で決まっている。棄却した案のうち「consumer が token を検査して、旧世代の操作を機械的に失効させる」は、この設計には入れていない。この設計の `epoch` が守るのは `lease` の記録への書き込みの取り合いだけで、退任した `generation` が委譲や board の更新を続けることは、名乗るとき（`oe-lease bind`・`whoami`）に退任と分かれば止まる（D8）という自己申告に頼る。前任のプロセスを閉じることを fencing の代わりにする #390 の DJ-7 は、そのまま残す。
  - **owner に確かめていること**（判断ボードの Q72・統括が載せた）: この設計の `epoch` と compare-and-swap を、#390 の回答1 の範囲（lean の決定を維持・停止を fencing の代わり）の中のものとして入れてよいか。答えによって、D5 と、decision #238/#239 との関係の表の扱いを直す。
  - owner の答え（2026-11-06・判断ボードの Q72）: 「`epoch` と compare-and-swap は入れるが、効かせるのは `lease` の記録への書き込みだけ。古い `generation` の送信やファイルの編集まで止める本格的な fencing は入れない」。

## 7. ゲート1 — ゼロベースの代替探索

- 道具: `so-compare --with codex,cursor`（選択肢拡張つき）。プロンプトと出力は、統括のワークスペースの根の `tmp/577-record-identity/gate1-prompt.md` と `tmp/577-record-identity/so-gate1/` にある（git の対象外の作業層）。
- レーン: Codex（`gpt-6.1-sol`・設定から解決・170秒・初回で返った）、Cursor（`composer-2.5`・指定・86秒・初回で返った）。2レーンとも返った。
- 渡した初期案: 案A（`lease` と `generation` の2段・この discussion の推奨）・案B（`generation` ごとの ID）・案C（ID を作らず、registry の掃除を直して張り替えの verb を足すだけ）と、暗黙の前提5つ。

```text
DJ 全体: 記録の「誰か」のキーをどう持つか
├── 案A（初期・`lease` と `generation` の2段） → 採用。ゲート1 の指摘で、`epoch`・ commit point を `lease` の記録1つにすること・server の開始時刻・heartbeat の引き方の一本化・/clear の定義・Enter の前の確かめ直しを足した
├── 案B（初期・`generation` ごとの ID） → 不採用。子の宛先が前任の `generation` を指して残る（DJ-1）
├── 案C（初期・掃除を直して張り替えの verb を足す） → 不採用。下の「案C の境目」
├── 案D（Codex・Cursor の両方: 配送を Claude Code のセッション間の文を送る機能へ移す） → owner に聞き、採らなかった（DJ-10・Claude Code への依存を深めない）。Codex の「この機能は `lease` や後継を決めない」により、案D を採っても `lease` の記録は要る
├── 案E（Codex: 仕事ごとの郵便受け・取りに来る形） → 一部を採用（DJ-16 の保留）。郵便受けは新しく作らない
├── 案F（Codex: 会話より長く生きる管理のプロセスが `lease` を持つ） → 不採用。常駐の配備と見張りが増え、#238/#239 の lean の線（新しい常駐を増やさない）に反する。Codex 自身も「今回の規模では過剰になりうる」と書いた
├── 案E'（Cursor: events を再生して、いまの統括を決める） → 不採用。event の書き込みは best-effort で（decision #206）、1件落ちると「いま」が狂う。`lease` の記録の compare-and-swap のほうが単純である。event は派生の記録として残す（DJ-13）
├── 案F'（Cursor: `lease` の記録をワークスペースの `.oe/` に置く） → 不採用。ワークスペースをまたぐ委譲（子が別のリポジトリの worktree で動く）と、全リポジトリの木を1つで見る `oe-tree` が成り立たない（DJ-2）
├── 案G（Cursor: resume しない長寿の中継のセッションを1つ置く） → 不採用。統括は context を使い切って交代する前提（#238 の故障の型1）で、長寿の中継も同じく使い切る
└── 案H（Cursor: hook が session_id を名前にした `binding` の観測を書き、engine は読むだけ） → 一部を採用（DJ-3 の hook の観測）したが、owner の答え Q76 で外した。`lease` の記録を書くのは verb だけのままにする
```

### 案C の境目（案A が過剰でないか）

Codex は、案C で足りる条件を「復帰中は送信を止める・同じ `lease` への同時の resume を運用で許さない・前任の記録を明示して復帰する・復帰の verb を途中から再実行できる・子の自発の報告は送るときに宛先を引くか、復帰のあとに明示で知らせる・`/clear` と fork を対象の外にする」と書いた。Cursor は、案C で足りない理由として、board と registry が `%N` のままであること・`PARENT_TMUX_PANE` が焼き込まれたままであること・heartbeat の逆引きの穴が残ることを挙げた。

この issue の望む結果は「ペインが消えても tmux を起こし直しても、誰が統括で誰がその子かが記録に残り、復帰は属性を書き換えるだけの作業になっている」（確定版）である。子の宛先を付け替えずに済むことは、案C の条件の「子の自発の報告は送るときに宛先を引く」そのもので、それには `lease` のような送り先の名前が要る。owner の答えの「同じセッションを2か所で開く件は、生きていないことを機械で確かめてから走らせればよい」も、案C の「運用で許さない」ではなく機械の確かめを求めている。したがって案C では望む結果に届かない、と判断した。

## 8. ゲート2 — 設計SO（弱・Codex と Cursor の2レーンの予定・Cursor の1レーンで返った）

- 道具: `so-compare --with codex,cursor`。プロンプトと出力は、統括のワークスペースの根の `tmp/577-record-identity/gate2-prompt.md` と `tmp/577-record-identity/so-gate2/` にある。
- レーン: **Codex は返らなかった**（`timeout_status=error`・10秒・stderr の末尾に「You've hit your usage limit ... try again at 4:41 AM」の行があった）。Cursor（`composer-2.5`・指定・111秒）は初回で返った。brief の決まり（片方が返らなければ1レーンで進めてよく、そのことを plan に書く）により、Cursor の1レーンで進めた。実返却が1レーンあるので、弱 SO の「0 はなし」には当たらない。
- 渡した検証点は7つ（取り合いと生死・送る前の確かめ・書き手の分け方・名乗る方法・三者同期・移行の混ざり・#188 の置き換えの範囲）である。

| 重さ | 指摘 | 採否 | 直したところ |
|---|---|---|---|
| 高 | #188 の frontmatter が「DJ-188-1/2/3/5 は不変」と書いていて、§6 の範囲の書き方では足りない | 採った | §6 の DJ-188-5 の行と、decision の案の関係の表 |
| 高 | board schema の §9 が将来の正本を frontmatter の `現統括` に置いていて、DJ-12 と食い違う | 採った | §6 の board schema の行と、decision の案の関係の表 |
| 中 | DJ-9 にコマンド名の確かめが無く、シェルの pid を誤って `binding` すると張り替えられなくなる | 採った | DJ-9（`binding` するときに claude であることを確かめる） |
| 中 | statusLine が `OE_LEASE_ID` を受け継ぐことは未検証で、載らないと絞り込みが崩れうる | 採った | DJ-3（sidecar の `lease` の項目は手がかりに下げ、session_id の並びでも絞る）・plan の R2 |
| 中 | フォアグラウンドのプロセスグループの番号が claude を指すのは、入力待ちの1例でしか確かめていない | 採った | plan の R3（道具を動かしているあいだにも確かめる）。外れたときは送らない側に倒れる |
| 中 | 移行のあいだ、`PARENT_TMUX_PANE` しか持たない子は DJ-6 の外で、交代した統括の前任へ報告を送りうる | 採った | DJ-15（旧い子も自分のペインから自分の `lease` を引いて、親の `lease` へ送れるようにする） |
| 中 | registry の link の読む・確かめる・書くは、移行のあいだも原子的でない | 採らなかった（直さない） | registry は移行のあいだの複製で、正本ではない。`lease` の記録の側は DJ-5 で原子的にしている |
| 中（DJ-7 の表から） | 3 の方法（会話の記録の `lease_id`）だけで名乗ると、ULID を読み違えた `lease` を取りうる | 採った | DJ-7（3 だけのときは workspace の一致と、統括の `lease` なら owner の確かめ） |
| 中（DJ-7 の表から） | 同じ session_id が2つの `lease` の並びに入ると、2 の照合が決まらない | 採った | DJ-5（1つの session_id は1か所にしか入らない） |
| 低 | `epoch` と、`generation` と `binding` の比べが二重になっている | 採った | DJ-5（比べは番号1つに寄せた） |
| 低 | 確かめと Enter のあいだの窓・heartbeat の sidecar の掃除 | 採らなかった（すでに書いてある） | DJ-6・DJ-4 |

- 指摘が無かった点: `lease_id` あての送り方と取り合いの compare-and-swap・heartbeat の古さを死の根拠にしないこと・`/clear` で `generation` を進めないこと・engine の `oe`（WezTerm）を範囲の外に置くこと・event の snapshot に足すだけにすること。
- Codex のレーンは、利用上限が戻る時刻（04:41）のあとに同じプロンプトでやり直せる。やり直すかは統括が決める（plan の「設計SO」の節）。

### Codex でのやり直し（owner の答え Q74・2026-11-06）

- 道具: `so-compare --codex-only`。プロンプトと出力は、統括のワークスペースの根の `tmp/577-record-identity/gate2-codex-prompt.md` と `tmp/577-record-identity/so-gate2-codex/` にある。前のプロンプトを、owner の答えと P4 の新しい DJ（DJ-18〜DJ-20）に合わせて直し、owner がすでに決めたことは覆さず、その中で崩れる場面を挙げるよう頼んだ。各指摘に、重さ・起きる確実さ・被害の大きさを分けて書かせた。
- レーン: Codex（`gpt-6.1-sol`・設定から解決・322秒・初回で返った）。
- 採否の基準: owner の補足（「些事や低リスク〈発生頻度を含む〉のところまで無理に取り入れる回し方はしない」）に従い、重さが高のものはすべて採り、起きる確実さと被害がどちらも低か、どちらかが低で直しに設計の判断を足すものは採らなかった。文の言い過ぎを直すだけで済むものは、確実さが低くても採った。

| 重さ（確実さ・被害） | 指摘 | 採否 | 直したところ・採らない理由 |
|---|---|---|---|
| 高（高・高） | 手で立てた統括は環境に `OE_LEASE_ID` を持たないので、sidecar からだけ session_id を足す DJ-18 では、最初の session_id が登録されない | 採った | DJ-18: session_id を正本に登録するのは本人が動かす verb だけにし、自分の `CLAUDE_PID` が `binding` と一致するときに自分の `CLAUDE_CODE_SESSION_ID` を登録する |
| 中（中・中） | sidecar にプロセスの識別子が無いので、遅れた古いプロセスの sidecar からも session_id を足してしまう | 採った | DJ-18: sidecar は候補を探す手がかりにだけ使い、登録の根拠にしない（上と同じ直しで消えた） |
| —（指摘なし・注意） | 起動の確かめで claude を確かめられなければ、`binding` を未確定で止める | 採った | DJ-18 に1行足した |
| —（注意） | adopt は照合でなく最初の発見なので、成功の条件を分ける | 採った | DJ-19 に1行足した |
| 中（低・中） | `oe-report` を PR-3 で消すと、起動済みの子の呼び出しが失敗する | 採った | DJ-20: 消すのを PR-6（古い子が残っていないと確かめてから）に移した。直しが置き場の移動だけで、設計の判断を足さないので採った |
| 高（低・高） | `ps` の失敗を「プロセスなし」に畳むと、生きた `binding` を死と誤判定する | 採った | DJ-9: ある・無い・分からない、の3つで返す。DJ-5 の「分からなければ張り替えない」をそのまま実装に当てる文にした |
| 中（中・中） | compare-and-swap は二重の起動までは防がない（resume を先に起こすので） | 採った（言い過ぎの直し） | DJ-5: 保証の範囲を「正本の `binding` が1つ・負けた側は統括の操作に進まない」までと書いた |
| 高（中・高） | session_id の一意性は、`lease` ごとのロックでは守れない | 採った | DJ-5: session_id を登録する操作は、すべての `lease` に共通の1つのロックの中で行う |
| 中（中・中） | 親の書き換えで `epoch` が増えないと、2つの付け替えが両方成功する | 採った | DJ-5: 親の書き換えでも `epoch` を増やす |
| 中（中・高） | 確かめたあとに同じペインの中で会話が替わると、receipt では見つけられない | 採った（言い過ぎの直し） | DJ-6: receipt で見つけられるのは別のペインに届いた場合まで、と限定した。窓を残す owner の答え（Q76）は変えない |
| 低（中・低） | 新しい拍動のあとに古いプロセスの拍動が届くと、一時的に送れない | 採らない | 誤送信ではなく一時的な不達で、被害が低い。送る側は失敗で返るので、送り直せば届く |
| 高（中・高） | 名乗る方法3は、DJ-5 の張り替えの条件を飛ばして読める | 採った | DJ-7: 1〜3 の方法は「どの `lease` か」を決めるだけで、張り替えは必ず DJ-5 を通す、と書いた |
| 中（低・中） | 方法3で、同じワークスペースの別の子の `lease` を取り違えうる | 採らない | 起きるには、ULID を読み違え、しかも取り違えた先の前の `binding` が死んでいる必要があり、確実さが低い。防ぐには新しい仕組みが要る。Codex 自身も「追加機構を必須にするほど高いリスクとは判断しない」と書いた |
| —（指摘なし・注意） | board の行の書き換えに失敗しても、確定した `lease` を巻き戻さない | 採った | DJ-12 に1行足した |
| 高（中・高） | PR-3 で `lease` あての送信を始めても、交代で `generation` を進めるのは PR-4 なので、そのあいだの交代で子の報告が前任へ向く | 採った | plan の並べ方: PR-4（統括の `lease`）を PR-3（送る側）の前に入れる |
| 中（中・高） | 古い子は、親の交代後に前任へ送るか、`%N` の使い回しで別人へ送りうる | 採らない | owner が決めた範囲（古い子は古い宛先のまま終わらせる・Q76）の残りで、新しい直しではない。discussion の DJ-11 の範囲のまま、移行のあいだの残る穴として decision の案の「帰結」に書いた |
| 中（低・中） | 観測者が session_id の登録を起こすと、DJ-188-5（観測者は読むだけ）に食い違う | 採った（上の直しで消えた） | DJ-18 で登録を本人の verb だけにしたので、観測者は登録しない |
| 低（高・低） | #206 の制約は、ID を足したあとの新しい event についてだけ解ける | 採った（言い過ぎの直し） | §6 の #206 の行を限定した |

---
id: "01M78B553R0EF3B63TKBGJKGP6"
title: "#562 Codex CLI を、統括の子として tmux のペインで対話的に動かす"
date: 2026-11-13
type: plan
status: draft
so:
  design: weak
  impl: weak
  reason: "設計の範囲は広いが、ゲート3 で owner が設計判断を見る。engine の変更は委譲の起動と lease の検査に限り、Claude の子の経路は検査で固定する。設計SO は Codex の1レーン（返らなければ Cursor に1回だけ）、実装SO は1レーンと Copilot の1ラウンド（brief の指定）"
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562"
    reason: "本 plan の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562#issuecomment-6830128252"
    reason: "着手時の認識合わせの確定版（2026-11-13）。この plan はその各項目を網羅する（「確定版の項目との対応」の表）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562#issuecomment-6789391162"
    reason: "ソースの調査（0.166.0）。この plan は主張の印の強さを保って写し、設計の前提に使うものは 0.167.1 で確かめ直した"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562#issuecomment-6798867414"
    reason: "11-11 の実機の確かめ（6項目）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/564"
    reason: "用語の決まり。新しい名前はプログラムの識別子として書けるものにする"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/603"
    reason: "registry と PARENT_TMUX_PANE の古い仕組みを外す条件。Codex の子が lease と heartbeat を持たないと、外す条件を満たせなくなる"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/537"
    reason: "engine の独立。エージェントごとの差を engine の1か所に寄せる動機"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-13-episode-562-codex-child.md"
    reason: "実行記録"
tags: [codex, delegation, agent-neutral, hooks, lease]
---

# #562 Codex CLI を、統括の子として tmux のペインで対話的に動かす

## 背景

2026-11-01 の大会の作業で、owner が Codex を直接開いて対話で使ったところ、Claude と Codex のあいだで人が文を写す作業が復活した。engine の委譲（`oe delegate`・`oe send`）は tmux のペインで対話型のエージェントを動かし、報告はファイルと1行の送信で受けるので、大部分は中で動くエージェントに依らない。ただし Claude Code に固定された箇所が少なくとも7か所ある（確定版の認識合わせ）。この plan は、その7か所それぞれを Codex でどう代えるかと、代えられないときに無しで動く形を決め、委譲ごとにエージェントを指定できる形にする。

## この plan の範囲

- やる: `oe delegate` にエージェントの指定を足し、Codex の子を `exec codex --no-daemon …` の形で起こす。lease のコマンド名の検査を広げる。入力欄の判定に Codex の行頭を足す。受領の印と拍動を Codex の hook で書く配線と、その hook の信頼を登録する手順を決める。Codex の子が `oe send` と `git commit` を承認の画面で止まらずに打てる許可の規則を配る。復帰の案内の文をエージェントで出し分ける。委譲の書面を Claude のスキルの読み込みに頼らず渡す形を決める。Claude の子への委譲が変わらないことを検査で固定する。
- やらない: owner が自分で開く Codex の既定（`~/.codex/config.toml` の承認・sandbox・model）。Cursor など3つ目のエージェントへの対応（設計が特定のエージェントに閉じないかは DJ-1 で見るが、実装しない）。クラウドのエージェント（#631）。Codex を統括にすること（lease の `supervisor` の種類・`oe-handoff`・`oe-register root` の Codex 対応）。SO の Codex のレーンと子としての Codex の使い分け、どの作業から Codex の子に任せるか（issue の「決めること」の後ろ2つ。実機で1回回したあとに owner が決める材料が出るので、episode の follow-up に残す）。

## 前提（読んで確かめた事実）

Codex の行番号は、手元の版 `codex-cli 0.167.1` に合うタグ `rust-v0.167.1`（コミット `0a94398`）の `codex-rs/` からの相対である。engine の行番号は `projects/orchestration-engine/` からの相対で、`origin/master` の `5ddbdc1` で読んだ。

### Codex の側

- hook の種類は14で、`UserPromptSubmit`・`PreModelRequest`・`PostModelRequest`・`SessionStart`・`Stop` を含む [verified]（`hooks/src/lib.rs:30-44`）。公式の文書も同じ14を挙げるが、対話の画面で発火するかは書いていない [verified]（https://learn.chatgpt.com/docs/hooks ・2026-11-13）。`Stop` が対話で発火しない報告（openai/codex#17532）は open のままで、対象はリポジトリ直下の `.codex/config.toml` に書いた hook である [verified]（`gh issue view 17532 -R openai/codex`）。
- `UserPromptSubmit` の hook の標準入力は `session_id`・`transcript_path`・`cwd`・`prompt`・`turn_id`・`model`・`permission_mode` を必須で持つ [verified]（`hooks/schema/generated/user-prompt-submit.command.input.schema.json`）。`PostModelRequest` は `session_id`・`transcript_path`・`cwd`・`turn_id`・`model` を持つ [verified]（同 `model-request.command.input.schema.json`）。
- hook が exit 0 で標準出力に素の文字列を出すと、その文字列がモデルの文脈に足される。JSON なら `hookSpecificOutput.additionalContext` が足される。exit 2 と stderr の理由で止められる [verified]（`hooks/src/events/user_prompt_submit.rs:154-247`）。hub の受領の印の hook は標準出力に何も出さないので、Codex でもモデルの文脈を汚さない。
- hook に渡る環境変数は、hook の engine が自分のプロセスの環境を `std::env::vars_os()` で写したもの [verified]（`hooks/src/registry.rs:83`）に hook ごとの上書きを足したもので [verified]（`hooks/src/engine/command_runner.rs:486-495`）、除外されるのは認証の token 系の6変数だけ [verified]（`protocol/src/shell_environment.rs:14-21`）。`TMUX_PANE` は除外されない。既定の起動は共有の daemon につなぎ、`--no-daemon` なら TUI に埋め込んだ app server を使う [verified]（`tui/src/lib.rs:1073-1110`）。11-11 の実機で、既定の起動では子のコマンドに届く `TMUX_PANE` が daemon を最初に起こしたペインの値になり、`--no-daemon` なら自分のペインの値になった（6項目の2つ）。hook も同じ engine で走るので、`--no-daemon` なら hook に届く `TMUX_PANE` も自分のペインの値になる見込みである [unverified-summary]（ソースの構造からの読み。実機の確かめ C2）。
- hook は、内容の hash を信頼として登録しないと走らない。登録は `~/.codex/config.toml` の `[hooks.state."<hooks.json のパス>:<イベント名の snake_case>:<組の番号>:<hook の番号>"]` に `trusted_hash = "sha256:…"` として書かれる [verified]（手元の `~/.codex/config.toml` に `pre_tool_use:0:0`〜`0:2` と `permission_request:0:0` の4件がある）。書くのは TUI の `/hooks` で [verified]（`tui/src/hooks_rpc.rs:66-98`・公式の文書）、CLI の `--dangerously-bypass-hook-trust` でその起動だけ登録なしに走らせられる [verified]（`codex --help`）。hub は `~/.codex/hooks.json` を `canonical/hooks/codex.hooks.json` への symlink で配っている [verified]（`scripts/sync/sync-codex.sh:294`・手元の `ls -l ~/.codex/hooks.json`）。
- `--approve-for-me` は `approvals_reviewer="auto_review"`・`approval_policy="on-request"`・`sandbox_mode="workspace-write"` の3つの上書きに展開される [verified]（`cli/src/main.rs:3246-3263` の検査）。auto_review は承認の要求を別のレビュアーのモデルに回す仕組みで、sandbox の外で走らせる要求・ネットワークの要求・書ける範囲の外への書き込みを扱い、否認が3回続くとターンが止まる [verified]（https://learn.chatgpt.com/docs/sandboxing/auto-review ・2026-11-13）。公式の文書は「決定論的な保証ではない」と書く。
- 実行ポリシーの規則は `~/.codex/rules/` の下の `.rules` ファイルで、`prefix_rule(pattern=[…], decision="allow")` の `allow` は「承認なしで sandbox の外で走らせる」[verified]（https://learn.chatgpt.com/docs/agent-configuration/rules ・2026-11-13）。ソースでは、全部の区間が allow に当たるときだけ sandbox を外す [verified]（`core/src/exec_policy.rs:466-470`）。リポジトリ直下の `.codex/rules/` は、そのプロジェクトの層を信頼したときだけ読まれる [verified]（同文書）。手元の `~/.codex/rules/default.rules` には owner がほかの作業で許可した行が入っている（hub には写さない）。
- 子が打つコマンドには `CODEX_THREAD_ID`・`CODEX_SESSION_ID`・`CODEX_VERSION` が入る [verified]（`core/src/exec_env.rs:33-50`・`protocol/src/shell_environment.rs:6-8`）。11-11 の実機で `CODEX_THREAD_ID` が届くことは確かめている。環境変数の継承の既定は `inherit = all` [verified]（`protocol/src/config_types.rs:261-265`）。Claude の `CLAUDE_PID` に当たるものは無い [verified]（同ファイルに pid の変数は無い）。
- 会話の記録は `~/.codex/sessions/YYYY/MM/DD/rollout-<時刻>-<id>.jsonl` で、1行目の `session_meta` に `id`・`cwd`・`cli_version` があり、`token_count` の行に `info.total_token_usage.total_tokens` と `info.model_context_window` がある [verified]（手元の 0.167.1 の `codex exec` の記録1件を読んだ。対話の画面の記録でも同じ形かは C3 で確かめる）。セッション名は `~/.codex/session_index.jsonl` に `{id, thread_name, updated_at}` の形で入る [verified]（手元）。
- `codex resume <UUID か名前>` は `--no-daemon`・`--approve-for-me`・`-s`・`-a`・`--add-dir`・`-C` を受け付ける [verified]（`codex resume --help`）。同じ記録に追記することは 11-11 の実機で「前の依頼を覚えていた・会話の ID も同じ」まで確かめている。記録のファイルに追記されるかは [unverified-summary]（調査のコメントの `[sub]`）。
- 入力欄の行頭は `›` [verified]（`tui/src/bottom_pane/chat_composer.rs:4967-4981`）、作業中の表示は `Working (0s • esc to interrupt)` [verified]（`tui/src/status_indicator_widget.rs:457`）で、作業中の目印の文字列 `esc to interrupt` は Claude と同じである。空の入力欄の補完の文は `Ask Codex to do anything` [verified]（同 `chat_composer.rs:5157`）。
- 既定のモードでは、Codex は選択肢で尋ねる道具を使えない [unverified-summary]（調査のコメントの `[verified]`・`tools/src/tool_config.rs:6-15`。0.167.1 では開き直していない）。問いをファイルに書いて親へ送る運用がそのまま合う。
- 文中の `$スキル名` を見つけると SKILL.md の本文をそのターンに差し込む [unverified-summary]（調査のコメントの `[verified]`・`core/src/session/turn.rs:1177`。0.167.1 では開き直していない）。効き目がそのターンに限ることは [unverified-summary]（`[sub]`）。hub は `canonical/skills/` を `~/.codex/skills/` に配っている [verified]（`scripts/sync/sync-codex.sh:274`）。
- 手元の `codex` は native のバイナリ（`/opt/homebrew/Caskroom/codex/0.167.1/bin/codex`）で、プロセスのコマンド名は `codex` になる [verified]（`ls -l $(command -v codex)`）。共有の daemon は 0.167.2 のバイナリで動いていて、CLI と版がずれている [verified]（`ps -axo pid,comm`）。
- 文を送る口として `codex queue --thread <ID> --message <文>` がある [verified]（`cli/src/queue_cmd.rs:14-24`）。daemon か remote の app server に対して queue し、動いている画面にどう届くかは確かめていない [unverified-summary]。

### engine と配布物の側

- `oe-delegate` は子のコマンドを `PARENT_TMUX_PANE=… [OE_LEASE_ID=… OE_GENERATION=1] claude <引数…> [--add-dir <brief の dir>]` の1行に組み、`tmux split-window -c <workspace>` に渡す [verified]（`bin/oe-delegate:202-220,364-367`）。`exec` は書いていないが、tmux が bash の `-c` で起こす最後の単純コマンドは bash が exec で置き換えるので、前面のプロセスは claude になる [verified]（自分のペインで `ps -t <tty> -o pid=,tpgid=,comm=` の pid と tpgid が一致する行が `claude`）。検査は子のコマンドの文字列を固定で見ている [verified]（`tests/test_oe_delegate.sh:219` の `PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'`）。
- 承認のダイジェストは workspace・label・brief のパスと内容の hash・task・elevated 宣言・`claude_args` から計算する [verified]（`bin/oe-delegate:250-277`）。権限のモードは `--permission-mode` と `--dangerously-skip-permissions` から読む [verified]（同 `235-247`）。
- lease の binding は、コマンド名に `claude` を含むことを `oe_lease_bind`・`oe_lease_claim`・`oe_lease_advance` の3か所で求め、含まなければ rc 6 で止まる [verified]（`lib/lease.sh:161,258,319`）。`oe-lease adopt` も同じ検査をする [verified]（`bin/oe-lease:224`）。`oe-delegate` は起動のあと、子のペインの前面のプロセスを読んで binding を書く [verified]（`bin/oe-delegate:393-415`）。
- 送る側の入力欄の判定は行頭の `❯` [verified]（`lib/delegate-send.sh:33-36`）、空の入力欄の補完の判定は `Try "` [verified]（同 `41-50`）、作業中の目印は `esc to interrupt` [verified]（同 `66,221`）。
- `oe-lease`（`create --root`・`bind`・`whoami`）・`oe-register`・`oe-recover`・`oe-handoff` は `CLAUDE_PID` と `CLAUDE_CODE_SESSION_ID` を読む [verified]（`bin/oe-lease:52-58,81,118`・`bin/oe-register:52`・`bin/oe-recover:192`）。`oe-send --to-parent` は `OE_LEASE_ID` だけで親を引く [verified]（`lib/target-resolve.sh:22-26`）。
- 拍動の sidecar は `~/.claude/state/oe-heartbeat/<session_id>.json` に `{ts, context_pct, pane, server_pid, model, lease_id, generation}` の形で書かれ [verified]（`canonical/claude/statusline/statusline-oe-heartbeat.sh:61-124`）、読むのは `oe-tree`（装飾・900秒の窓）・`oe-threads`・`oe-vitals`・`oe-selfcheck`（pane の橋）・`lib/heartbeat-resolve.sh` である [verified]（`bin/oe-tree:531-690`・`bin/oe-selfcheck:292-310`）。lease からペインを引くときは、sidecar の候補を取ってから前面のプロセスで確かめる [verified]（`lib/lease.sh:514-517`）。sidecar が無い lease は、ペインを引けず、ラベルの宛先は registry に落ちる（#603 で外す予定の経路）。
- 受領の印の hook は `.prompt` と `TMUX_PANE` しか読まず、標準出力に何も出さない [verified]（`canonical/hooks/scripts/oe-prompt-receipt.sh`）。Codex 向けの配線は `canonical/hooks/codex.hooks.json` に `PreToolUse` の3本だけがある [verified]。
- `canonical/codex/AGENTS.md` には engine への言及が無い [verified]。復帰の案内は `claude --resume <sid>` の文で出る [verified]（`bin/oe-recover:111-130`・`bin/oe-handoff:1299,1398`）。

## 設計判断

owner に聞くものは「GATE 3 の問い」に出し、ここには推奨を書く。印の無いものは自分で決めた。確かめの結果で分かれるものは「実機の確かめ」節に分かれ方を書く。

### DJ-1 委譲ごとのエージェントの指定（自分で決めた）

- `oe delegate --agent <claude|codex>` を足す。指定が無いときは `claude` で、子のコマンドの文字列は今と1文字も変えない（受入 A-1）。
- 名前は `agent`（値は CLI の実行ファイルの名前そのもの）。候補は `--agent`・`--runner`・`--cli` で、`agent` は issue の本文と #564 の役割の語（統括・子・エージェント）に合い、値がそのまま `command -v` に渡せる識別子になるので採る。`--claude-arg` は `--agent-arg` に改名し、`--claude-arg` は alias として残す（今の呼び出し元 `oe-kick`・`delegate-task` の文が壊れない）。
- エージェントごとの差（起動の引数・権限のモードの読み方・コマンド名の照合・復帰の案内の文）は `lib/agent.sh` の1か所に寄せ、verb はそこを引く。3つ目のエージェントを足すときに触る場所をこのファイルに限る（#537）。
- registry の記録と lease の記録に `agent` の項目を足す（無ければ `claude` と読む）。読む側（`oe-tree`・`oe-recover hint`）が復帰の案内と表示に使う。schema（`schemas/oe-lease.schema.json`）に任意の項目として足す。
- 承認のダイジェストには `agent` を常に入れ、`claude_args` の鍵の名前は `agent_args` に変える。claude の承認で codex を起こす差し替えを照合で落とすためである。ダイジェストの値は起こすたびに計算し直すので、既存の承認には影響しない。検査は値を固定していない（`tests/test_oe_delegate.sh:212-233` は形と一致だけを見る）。

### DJ-2 Codex の子を起こす1行（自分で決めた・C6 で確かめる）

- `PARENT_TMUX_PANE=… OE_LEASE_ID=… OE_GENERATION=1 codex --no-daemon <承認のモードの引数> [--add-dir <brief の dir>]` を、Claude と同じ形で `tmux split-window -c <workspace>` に渡す。`exec` を明示するかは C6 の結果で決める（前面が `codex` にならなければ `exec` を書く。書くなら Claude の1行も同じにそろえ、受入 A-1 の文字列を更新する）。
- `--no-daemon` は固定で付ける（11-11 の実機）。版のずれた共有の daemon を避ける効果もある。
- `--add-dir` は、brief の置き場（統括のワークスペースの `.oe/`）が子の workspace（worktree）の外にあるとき、子が `.oe/question-*.json` と `.oe/report-*.md` を書けるようにするために付ける。Codex の `--add-dir` は書ける範囲を広げる引数で [verified]（`codex --help`）、Claude の `--add-dir`（読める範囲）とは意味が違うが、必要な効果（読める・書ける）は同じになる。読めることは C7 で確かめる。

### DJ-3 子の Codex を起こすときの承認のモードの既定（owner に聞く・Q1）

- 推奨: **`--approve-for-me` を既定にし、engine の verb と git の commit を実行ポリシーの `allow` の規則で sandbox の外に出す。** 規則は hub が `canonical/codex/rules/oe-child.rules` として持ち、`sync-codex.sh` が `~/.codex/rules/oe-child.rules` に symlink で配る。中身は `prefix_rule(pattern=["oe"], decision="allow")`・`prefix_rule(pattern=["git", "commit"], decision="allow")`・`prefix_rule(pattern=["git", "push"], decision="allow")`・`prefix_rule(pattern=["gh"], decision="allow")` の4行（強制 push は hub の `block-force-push.sh` の hook が止める）。
- 理由: Claude の auto mode に近い（承認の要求を機械が裁く・破壊的な操作は hub の hook が止める）。auto_review はモデルが裁くので、報告の `oe send` のように毎回必ず通したいものは規則で決定論にする。`allow` は sandbox の外で走るので、tmux のソケットにつなげない問題（11-11 の実機）も消える。`~/.codex/rules/` に置くのは owner の手元の設定に見えるが、Codex の実行ポリシーは user 層にしか置けない（プロジェクト層は信頼したリポジトリでだけ読まれる）ので、hub が別名のファイルで配り、owner の `default.rules` には触らない。
- ほかの案:
  - `-a never -s workspace-write` と同じ規則。レビュアーのモデルを使わないので止まらないが、規則に無いコマンド（`curl`・`npm publish` など）は sandbox の中で失敗してモデルに返るだけで、人にも機械にも聞く道が無い。
  - `--dangerously-bypass-approvals-and-sandbox`。Claude の `bypassPermissions` に当たり、engine では elevated として owner の承認のダイジェストを必須にする（`extract_permission_mode` の対応表に足す）。既定にはせず、owner が明示したときだけ使える形で残す。
  - 規則を配らず auto_review に任せる。報告の送信がモデルの裁きに依り、否認が続くとターンが止まる。
- 引数は `--agent-arg` で上書きできる（Claude の `--permission-mode` と同じ扱い）。既定の引数は `lib/agent.sh` に置く。

### DJ-4 受領の印 `[oe:…]` の扱い（owner に聞く・Q2）

- 推奨: **印は今のまま付け、`canonical/codex/AGENTS.md` に「文末の `[oe:<26文字>]` は配送の受領印で、依頼の一部ではない。写さず、コマンドに含めない」の1行を足す。** 同じ文を `doc-flow-guardrail` の委譲の固定節（brief に貼る規律）にも足し、Claude の子にも同じ決まりが見えるようにする。
- 理由: 印を外すと受領の突き合わせ（`oe-confirm`・`oe-undelivered`）が Codex の子で使えなくなる。AGENTS.md は全部のセッションに常時効き、hub の正本で、1行で済む。
- ほかの案:
  - Codex 向けの `UserPromptSubmit` の hook が、印のある prompt のときだけ `hookSpecificOutput.additionalContext` で「末尾の印は受領印」とモデルに伝える。決定論で、AGENTS.md を触らない。ただし hook が対話で発火すること（C1）に依る。C1 が通ったあとの追加として残す。
  - 宛先が Codex のときは印を付けない（`OE_SEND_NONCE=0`）。送る側が宛先のエージェントを知る必要があり、受領の突き合わせも失う。

### DJ-5 lease のコマンド名の検査の広げ方（owner に聞く・Q3）

- 推奨: **検査を「許す名前の集合」にし、集合は `lib/agent.sh` の定数（`claude`・`codex`）で持つ。** `oe_lease_bind`・`oe_lease_claim`・`oe_lease_advance`・`oe-lease adopt` の4か所が同じ関数を呼ぶ。lease の記録には `agent` を別に書く（DJ-1）が、検査には使わない。
- 理由: 検査の目的は、前面のプロセスが wrapper のシェルになっていないことを見ることで（knowledge `01M6XN85N408CMMERA12QR1C3F`）、エージェントの種類の一致まで求める必要は無い。lease の記録の `agent` と突き合わせる形は厳しいが、`agent` の無い古い記録の扱いが要り、交代（`oe_lease_advance`）でエージェントが変わる場面（将来）も縛る。
- ほかの案:
  - lease の記録の `agent` と突き合わせる。上のとおり厳しいが、古い記録と将来の交代の扱いが増える。
  - 検査を外す。wrapper のシェルに binding する事故（#355 の drill）を再び許す。

### DJ-6 拍動の statusLine の代わり（自分で決めた・C3 で分かれる）

- Codex には外部コマンドを呼ぶ statusLine が無い [verified]（`config/src/types.rs:968-972`）。代わりに、`PostModelRequest` と `UserPromptSubmit` の hook で同じ sidecar を書く。書き手は新しい hook のスクリプト `canonical/hooks/scripts/oe-heartbeat-hook.sh`（名前は「hook で書く拍動」の意味で、エージェントの名前を入れない。Claude 向けの `statusline-oe-heartbeat.sh` と対になる）。
- 書く中身は同じ schema で、`session_id` は標準入力の `session_id`、`pane` は `TMUX_PANE`、`model` は標準入力の `model`、`context_pct` は `transcript_path` の記録の最後の `token_count` の `total_tokens / model_context_window`、`lease_id`・`generation` は環境変数から取る。記録を読めないときは `context_pct` を 0 にして書く（Claude の書き手と同じく欠落を飲む）。
- 定期的には走らず、プロンプトの受け取りとモデルへの要求のたびに走る。`oe-tree` の窓（900秒）を超えて黙っている子は拍動なしで表示される。Claude の statusLine も活動のたびに更新されるので、見え方は同じである。
- 無しで動く形: hook が発火しなければ、`oe-tree` は model と context% を出さずに子を表示し（拍動は装飾）、lease からペインを引けないのでラベルの宛先は registry に落ちる。#603 が registry を外すまでは動く。外したあとは Codex の子にラベルで送れなくなるので、C3 が通らなければ #603 に条件を足す。

### DJ-7 受け取りの印の hook（自分で決めた・C1 で分かれる）

- `canonical/hooks/scripts/oe-prompt-receipt.sh` をそのまま使い、`codex.hooks.json` の `UserPromptSubmit` に配線する。スクリプトは `.prompt` と `TMUX_PANE` しか読まないので変更は要らない。Codex の `session_id` は読まない（Claude でも読んでいない）。
- セッション名の hook（`session-name.sh`）は Claude 固有の出力なので Codex には配らない。Codex のセッション名は `/rename` で付けられるが [verified]（`tui/src/slash_command.rs:32,102`）、engine から機械で付ける口は無い。無しで動く（`codex resume` は UUID でも開ける）ので、この issue では付けない。
- 無しで動く形: 発火しなければ受領の印が出ず、`oe-confirm` は「確認できていない」を出す（断定しない決まりはそのまま）。統括は子の返事で受け取りを確かめる。

### DJ-8 会話の ID と自分のプロセス（自分で決めた）

- 子の側で自分を名乗る verb（`oe-lease bind`・`oe-lease whoami`・`oe-recover`）は、`lib/agent.sh` の `oe_agent_self` で (agent, pid, session_id) を引く。Claude は `CLAUDE_PID`・`CLAUDE_CODE_SESSION_ID`（今のまま）。Codex は session_id を `CODEX_THREAD_ID` から取り、pid は自分の親を `ps -o ppid=` でたどってコマンド名が `codex` の最初のプロセスを採る（pid の環境変数が無いため）。たどれなければ今と同じ文言で止まる。
- `oe-register root`・`oe-handoff` は統括の verb で、Codex を統括にするのは範囲の外なので触らない。`oe-recover` は子の復帰にも使うので対応する。

### DJ-9 resume の案内（自分で決めた・C5 で確かめる）

- `oe-recover hint` と `oe-handoff` が出す案内の文を、lease の `agent` で出し分ける。Codex は `cd <ws> && OE_LEASE_ID=… OE_GENERATION=… codex --no-daemon resume <sid>`。`agent` の無い記録は claude とする。engine は自動では再開しないので、変更は文だけである。
- 一覧から探す案内（`claude -r cockpit …`）は統括向けなので変えない。

### DJ-10 入力欄の判定（自分で決めた・C8 で確かめる）

- `_oe_send_inputline` の正規表現を `^[[:space:]]*[❯›]` にし、空の入力欄の補完の判定に `Ask Codex to do anything` を足す。作業中の目印 `esc to interrupt` は Codex も同じ文字列なので変えない。
- 送る側は宛先のエージェントを知らない（`%N` で送れる）ので、判定は両方の行頭を受ける形にする。Claude の画面に `›` が行頭に出ることは確かめていないが、`tail -n 1` で最後の1行だけを見るので誤りの範囲は入力欄の行に限られる。

### DJ-11 委譲の書面の渡し方（自分で決めた）

- 書面は自己完結のファイルにし、従う手順はスキルの名前でなく SKILL.md のパスで指す。送る1行は今のまま「`<brief のパス>` を読んで進めて。」にする。`doc-flow-guardrail` の「spec 解決規約」と並べて「skill 解決規約」を足す: スキルは `<設定ルート>/skills/<名前>/SKILL.md`（`~/.claude/…`・`~/.codex/…`・`~/.cursor/…`）で解決し、hub のワークスペースなら `canonical/skills/<名前>/SKILL.md`。brief の固定節で名前だけ書いてあるスキル（`implementer-contract`・`episode-retrospective`・`judgment-board-flow` など）は、この規約で読めると固定節の冒頭に1行書く。
- `$スキル名` を送る1行に足す案は、Codex だけの書き方で効き目がそのターンに限る [unverified-summary] ので採らない。エージェントごとに書面を作り分ける案は固定節を2通り持つことになるので採らない。
- スキルの本文に残る Claude 固有の記述（選択肢で尋ねる道具を前提にした文など）は、この issue では直さない。Codex の子が踏んだものを episode の follow-up に残す。

### DJ-12 hook の信頼の登録と配り直し（自分で決めた）

- `codex.hooks.json` に `UserPromptSubmit` と `PostModelRequest` の組を足すと、Codex はその hook を未登録として黙って飛ばす。登録は owner が Codex の対話の画面で `/hooks` を開いて1回行う。`PreToolUse` の既存の3本の鍵（`pre_tool_use:0:0`〜`0:2`）は別のイベントなので番号がずれず、登録し直しは要らない。
- 手順は `canonical/hooks/README.md` の Codex の節に書く（sync のあと `/hooks` で新しい2本を信頼する・スクリプトの内容を変えたときも同じ）。`--dangerously-bypass-hook-trust` を子の起動に付ける案は、hub の止める側の hook の信頼も外すので採らない。
- 登録されているかを機械で見る検査（`oe-selfcheck` が `[hooks.state]` の鍵の有無を見る）は、hash を再計算できないので「登録の有無」までしか言えない。この issue では README の手順と、実機の確かめの2段階目（Codex の画面から受領の印が出ること）で代える。

### DJ-13 `AGENTS.md` への追記（自分で決めた・Q2 の答えで中身が変わる）

- `canonical/codex/AGENTS.md` に「委譲された子として動くとき」の短い節を足す。受領の印の扱い（DJ-4）・報告は `oe send --to-parent` で返す・問いはファイルに書いて送る（対話の選択肢を使わない）・書面の固定節が正本、の4行以内にする。AGENTS.md は常時の原則だけを置く決まりなので、手順は書かず、brief と `doc-flow-guardrail` を指す。
- `scripts/check-codex-guardrails.sh` の整合の検査が通ることを確かめる。

### DJ-14 PR の単位（owner に聞く・Q4）

- 推奨: **2つに分ける。** PR-1 は engine と配るスキル（`oe-delegate --agent`・`lib/agent.sh`・lease の検査・入力欄の判定・`oe-lease`/`oe-recover` の自分の読み方・案内の文・engine の検査・`delegate-task`/`doc-flow-guardrail` の文・plan と episode）。PR-2 は Codex の配布物（`codex.hooks.json` の配線・`oe-heartbeat-hook.sh`・`canonical/codex/rules/oe-child.rules`・`sync-codex.sh`・`AGENTS.md`・hooks の README）。
- 理由: PR-1 は engine の検査（bash 5 と 3.2）で閉じ、Claude の子への委譲が変わらないことを機械で確かめられる。PR-2 は owner が `/hooks` で信頼を登録する手作業を含み、着地のあとに owner の手が要る。境目は #537 の engine と配布物の境目と同じである。4つ以上にはならない見込みで、issue を分ける案は出さない。
- ほかの案: 1つにまとめる。差分が engine・hooks・スキル・AGENTS.md にまたがり、Copilot の1ラウンドと実装SO の範囲が広くなる。

### DJ-15 名前（自分で決めた・#564 の決まり）

- 足す名前: `agent`（委譲ごとのエージェント。値は `claude`・`codex`）・`agent_args`（起動の追加引数。`--agent-arg`）・`lib/agent.sh`（エージェントごとの差を置く lib）・`oe-heartbeat-hook.sh`（hook で書く拍動）・`oe-child.rules`（子の Codex の実行ポリシー）。どれもプログラムの識別子として書け、日本語の言い換えを作らない。
- 変えない名前: `heartbeat`・`receipt`・`registry`・`lease`（#564 の表のとおり）。

## 7か所の対応表

| Claude Code に固定された箇所 | Codex での代え | 代えられないときに無しで動く形 | 確かめ |
|---|---|---|---|
| 拍動の statusLine | `PostModelRequest`・`UserPromptSubmit` の hook で同じ sidecar を書く（DJ-6） | `oe-tree` は model と context% なしで表示。lease からペインを引けず、ラベルの宛先は registry に落ちる | C3 |
| 受け取りの印の hook | `UserPromptSubmit` に同じスクリプトを配線（DJ-7） | 受領の印なし。`oe-confirm` は「確認できていない」。統括は子の返事で確かめる | C1・C2 |
| 会話の ID | `CODEX_THREAD_ID`（DJ-8） | （代えられる） | 11-11 済み |
| resume | `codex --no-daemon resume <sid>` の案内（DJ-9） | （代えられる。engine は自動で再開しない） | C5 |
| 起動のコマンド | `codex --no-daemon <承認の引数>`（DJ-2・DJ-3） | （代えられる） | C4・C6・C7 |
| lease のコマンド名の検査 | 許す名前の集合（DJ-5） | （代えられる） | C6 |
| 入力欄の判定 | 行頭 `›` と補完の文を足す（DJ-10） | finalize が働かず、Enter が吸われたときの打ち直しが無い。送信そのものは 11-11 で通っている | C8 |

## 確定版の項目との対応

| 確定版の項目 | 扱い | 場所 |
|---|---|---|
| lease の binding の検査 | 決める | DJ-5・Q3 |
| hook の信頼を配り直すたびに登録する手順 | 決める | DJ-12 |
| `exec codex --no-daemon …` の形で起こす | 決める・確かめる | DJ-2・C6 |
| `oe send` と git commit を承認なしに打てる規則 | 決める・確かめる | DJ-3・Q1・C4 |
| 承認のモードの既定 | 決める | DJ-3・Q1 |
| 受領の印をコマンドに写す件 | 決める | DJ-4・Q2 |
| `UserPromptSubmit` が対話で発火するか | 確かめる（最初のステップ） | C1 |
| 達成を何の数で見るか | 決める | 「達成を見る数の測り方」 |
| 1つの PR に収まらない見込みなら issue を分けるか | 決める | DJ-14・Q4（分けない。PR は2つ） |
| ［別モデル］同じ子との往復を続ける手順 | 範囲の外（既存の `oe send %N` と `oe send --to-parent` で変わらない。Codex 固有の手順が要るかは実機で1回回したあとに見る） | episode の follow-up |
| ［別モデル］途中で終わったときや利用上限のときの再開と再委譲 | 決める（再開は DJ-9 の案内。再委譲は今の `oe delegate` の打ち直しで、Codex 固有の手順は無い） | DJ-9 |
| ［別モデル］委譲ごとのエージェントの指定と、Claude の子が変わらないことの確かめ | 決める | DJ-1・受入 A-1・T-1 |

## ゼロベースの代替（ゲート1）

設計を固める前に、いまの形（tmux のペインで対話型の Codex を起こし、`send-keys` で送り、hook で印と拍動を書く）を前提にせずに考えた代替を4つ挙げ、採らない理由を書く。

- 非対話の `codex exec` をサンドイッチの実装の層に使う（`lib/spawn.sh` の `claude -p` と同じ系）。往復（問い・答え・直しの依頼）が1回ごとに新しいプロセスになり、issue の「対話で動かす」に合わない。SO のレーンと同じ形に戻るだけである。
- engine の読む側が Codex の記録（rollout）を直接読み、hook を使わない。拍動を書く側が要らなくなるが、engine が Codex のファイルの置き場と形を知ることになり、Claude の経路（sidecar を読む）と二重になる。hook で同じ sidecar を書けば読む側は1つのままなので、こちらを採る。
- 送る口を `tmux send-keys` でなく `codex queue --thread <ID> --message` にする。入力欄の判定と Enter の吸収の問題が消えるが、daemon か app server への接続が前提で、`--no-daemon` と両立するか・動いている画面にどう届くかを確かめていない。`send-keys` は 11-11 の実機で通っているので、この issue では変えず、follow-up に残す。
- エージェントごとに委譲の固定節を作り分ける。Claude 固有の記述を Codex の書面から消せるが、固定節が2通りになり、直すたびに両方を合わせる負債になる。パスで指す1通りの書面にし、Claude 固有の記述は踏んだときに直す。

## 設計SO（ゲート2・弱・Codex の1レーン）

P2 で埋める。

## 実装の分け方（PR の単位）

DJ-14 のとおり2つ（Q4）。PR-1 が engine と配るスキル、PR-2 が Codex の配布物。plan・episode・knowledge は PR-1 に載せる。PR-2 は PR-1 の着地のあとに ready にする（`lib/agent.sh` の既定の引数が規則のファイル名を指すため）。

## 達成を見る数の測り方

- M-1: 統括のペインから `oe delegate --agent codex --brief <書面>` で起こした Codex の子が、書面を読んで `oe send --to-parent` で報告を返すまでに、人が文を写した回数が 0、承認の画面で止まった回数が 0（I6 で1回回して数える。止まった回数は子のペインの capture の承認の表示を数える）。
- M-2: 同じ往復で、`oe-events.jsonl` に `prompt_received`（nonce と pane が送信と一致）が 1 件以上、heartbeat の sidecar が子の session_id で 1 件以上ある（`oe confirm` と `oe tree` で見る）。C1・C3 が通らなかったときは、この数は「無しで動く形」の確認（`oe-confirm` が「確認できていない」を出す・`oe-tree` に子が出る）に置き換え、置き換えたことを episode に書く。
- M-3: Claude の子への委譲が変わらないこと。engine の既存の検査が bash 5 と bash 3.2 で全件 exit 0、`tests/test_oe_delegate.sh` の子のコマンドの文字列の検査が変更前と同じ値で通る（T-1）。
- M-4: 7か所それぞれに、Codex での代えか「無しで動く形」が plan と実装に書かれている（上の表の行数 7 が、実装後の README の節と一致する）。

## 実機の確かめ（I1・ゲート3 のあとの最初のステップ）

`~/.codex` は owner の手元の設定なので、plan の段階では触らない。実機の確かめは、リポジトリの外の使い捨ての git リポジトリ（`<tmp>/oe-codex-probe`）を workspace にし、hook と規則はそのリポジトリ直下の `.codex/` に置く。`~/.codex` に残るのは次の2つだけで、終わったら消す。

- 使い捨てのリポジトリを信頼したときに `~/.codex/config.toml` に書かれる `[projects."<tmp>/oe-codex-probe"]` の表。消し方: その表を手で消す（`python3 -c 'import tomllib'` で読めることを確かめてから）。
- 対話で作った会話の記録（`~/.codex/sessions/<日付>/rollout-*.jsonl` と `session_index.jsonl` の行）。消し方: `codex delete <id>`。

hook の信頼は、1段階目は `--dangerously-bypass-hook-trust` を付けて起こし（`~/.codex` に何も書かない）、2段階目は `/hooks` で登録して `[hooks.state]` に鍵が書かれることと消し方を確かめる。鍵は hooks.json のパスを含むので、使い捨てのリポジトリの鍵だけを消せる。

| # | 確かめること | 足すもの | 分かれ方 |
|---|---|---|---|
| C1 | `UserPromptSubmit` の hook が対話の画面で発火し、標準入力に `prompt` が入る | `.codex/hooks.json` に、標準入力と環境を一時ファイルへ書くだけの hook（`<tmp>/probe-hook.sh`） | 発火しなければ DJ-7 は「無しで動く形」になり、`codex.hooks.json` には `UserPromptSubmit` を足さない |
| C2 | `--no-daemon` で起こしたとき、hook の環境の `TMUX_PANE` が自分のペインの値になる | C1 と同じ hook | ずれるなら受領の印は pane 無しで書かれ、`oe-undelivered` が突き合わせられない。送る側が `--to-parent` の経路で印を補う案（統括が子の返事で確かめる）に落とす |
| C3 | `PostModelRequest` の hook が対話で発火し、`transcript_path` の記録に `token_count` がある | C1 と同じ hook を `PostModelRequest` にも配線 | 発火しなければ DJ-6 は `UserPromptSubmit` だけで書く。それも無ければ「無しで動く形」で、#603 に条件を足す |
| C4 | `--approve-for-me` と `.codex/rules/` の `allow` の規則で、子が `oe send <統括のペイン>` と `git commit` を承認の画面で止まらずに打てる。規則の無い `curl` が auto_review に回ることも見る | 使い捨てのリポジトリの `.codex/rules/oe-child.rules`（DJ-3 の4行） | `allow` でも sandbox の外に出なければ DJ-3 の推奨を `-a never -s danger-full-access` に差し替え、Q1 を聞き直す |
| C5 | `codex --no-daemon resume <id>` で開き直した会話で、子のコマンドに同じ `CODEX_THREAD_ID` が届き、記録のファイルに追記される | なし | 追記されなければ DJ-9 の案内に「記録は新しいファイルになる」と添える |
| C6 | `tmux split-window -c <ws> "PARENT_TMUX_PANE=… codex --no-daemon …"` で起こしたペインの前面のプロセスのコマンド名が `codex` になる | なし | `codex` にならなければ1行に `exec` を書く（Claude も同じにそろえる） |
| C7 | workspace の外にある brief のパスを、`--add-dir` の有無それぞれで読めるか・`.oe/` に書けるか | なし | `--add-dir` 無しで読めないなら、brief を子の workspace の中へ写す形に変える |
| C8 | `oe send` の finalize が Codex の画面で働く（行頭 `›` を入力欄と判定し、Enter が吸われたときに打ち直す・吸われなかったときに二重に打たない） | なし | 働かなければ、Codex の宛先では finalize を切る（`OE_SEND_FINALIZE=0` を `lib/agent.sh` に置く） |

確かめた結果は、1項目ずつ（版・起動の形・経路）を episode に書き、plan の対応する DJ に結果の行を足す（記録の級）。

## テスト

新しい検査は `tests/test_agent.sh`（`lib/agent.sh`）に置き、既存の検査（`test_oe_delegate.sh`・`test_lease.sh`・`test_delegate_send.sh`・`test_oe_recover.sh`・`test_prompt_receipt.sh`）に節を足す。bash 5（`bash tests/<file>`）と bash 3.2（`/bin/bash tests/<file>`）の両方で回す。実 tmux と実 Codex は起動せず、PATH の先頭の mock で記録する（既存の流儀）。

- T-1（Claude の不変）: `--agent` 無しの `oe delegate` が組む子のコマンドの文字列が、変更前と同じ `PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'` である。既存の検査の値を変えない。
- T-2: `--agent codex` で `codex --no-daemon` と既定の承認の引数が入り、`--agent-arg` で上書きできる。`--agent` に知らない名前を渡すと exit 2。`--claude-arg` が `--agent-arg` の alias として動く。
- T-3: 承認のダイジェストが `agent` を含み、`--agent claude` と `--agent codex` で値が違う。`--reason` の違いでは変わらない（既存）。
- T-4: lease の検査が `codex` を許し、`bash` を rc 6 で断る（`oe_lease_bind`・`oe_lease_claim`・`oe_lease_advance`・`adopt`）。
- T-5: `_oe_send_inputline` が `›` の行を入力欄と判定し、`Ask Codex to do anything` を空として扱う。`❯` の既存の検査は変えない。
- T-6: `oe_agent_self` が `CLAUDE_PID`・`CLAUDE_CODE_SESSION_ID` のときと `CODEX_THREAD_ID` のときでそれぞれ (agent, pid, session_id) を返し、どちらも無いときは今と同じ文言で止まる。pid は mock の `ps` でたどる。
- T-7: `oe-recover hint` が lease の `agent` で案内の文を出し分け、`agent` の無い記録では `claude --resume` を出す。
- T-8: `oe-heartbeat-hook.sh` が、標準入力の `session_id`・`model`・`transcript_path` と環境の `TMUX_PANE`・`OE_LEASE_ID` から、Claude の書き手と同じ鍵の sidecar を書く。記録に `token_count` が無いときは `context_pct` を 0 にする。標準出力に何も出さない。
- T-9: `oe-prompt-receipt.sh` に Codex の形の標準入力（`session_id`・`turn_id` 付き）を渡しても同じ印が出る。
- T-10: `scripts/check-codex-guardrails.sh` が通る。`shellcheck` が新しいスクリプトと変えたスクリプトで通る。

## 受入

- A-1: `--agent` を指定しない `oe delegate` の子のコマンドの文字列と、承認パッケージの表示の項目が、変更前と同じである（T-1。`agent_args` の鍵の改名はダイジェストの中だけ）。
- A-2: 7か所それぞれに Codex での代えか「無しで動く形」が実装と README にある（M-4）。
- A-3: 実機の確かめ C1〜C8 の結果が、版・起動の形・経路を1項目ずつ episode に書かれている。
- A-4: 統括から Codex の子へ書面を渡し、報告を受けるまでを、人が文を写さず、承認の画面で止まらずに1回回せた（M-1）。
- A-5: engine の既存の検査と新しい検査が bash 5 と bash 3.2 で全件 exit 0（M-3）。
- A-6: hook の信頼を登録する手順が `canonical/hooks/README.md` にあり、実機で1回たどって受領の印が出た（DJ-12 の2段階目）。

## ステップ

### P1: worktree・参照の読み・一次情報での確かめ直し・設計判断の洗い出し（完了）

### P2: 設計SO（弱・Codex の1レーン）を plan の案に当て、採否を episode に書く

### P3: plan を draft PR に載せ、ゲート3 の問いを `.oe/question-562-1.json` に書いて `build.py check` を通し、`.oe/report-562-p3.md` を書いて報告の宛先へ1行送り、止まる

### GATE 3: owner の plan 承認（承認の記録 `.oe/decision-562-gate3.md` が届いてから I に進む）

### I1: 実機の確かめ C1〜C8（使い捨てのリポジトリ・結果を episode と plan に書く・`~/.codex` に残したものを消す）

### I2: `lib/agent.sh` と `oe delegate --agent`（DJ-1・DJ-2・DJ-3 の既定の引数）・registry と lease の `agent`・ダイジェスト・T-1〜T-3

### I3: lease の検査の集合（DJ-5）・入力欄の判定（DJ-10）・T-4・T-5

### I4: `oe_agent_self`（DJ-8）と `oe-lease`/`oe-recover` の読み替え・復帰の案内（DJ-9）・T-6・T-7

### I5: `delegate-task`（`--agent`）と `doc-flow-guardrail`（skill 解決規約・受領の印の1行）の文・`bin/README.md`・engine の README

### CHECK-1: T-1〜T-7 と既存の検査を bash 5 と bash 3.2 で回し、shellcheck を通す（PR-1）

### I6: Codex の配布物（PR-2）: `oe-heartbeat-hook.sh`（DJ-6）・`codex.hooks.json` の配線（DJ-7）・`canonical/codex/rules/oe-child.rules` と `sync-codex.sh`・`AGENTS.md`（DJ-13）・hooks の README（DJ-12）・T-8〜T-10

### CHECK-2: sync を一時ディレクトリで確かめ（worktree からの sync は `~/.claude` のリンクを張り替えるので避ける・#605 の I4 と同じ）、owner が `/hooks` で登録してから、統括から Codex の子へ1回回して M-1・M-2 を数える

### GATE 4: 実装SO（弱・1レーン）と Copilot の1ラウンド（PR ごと）

### I7: episode を closure し、knowledge の観測を5件書き戻し、報告して止まる（マージ・worktree の掃除・issue の close はしない）

## GATE 3 の問い

- Q1（DJ-3）: 子の Codex を起こすときの承認のモードの既定。推奨は `--approve-for-me` と、hub が配る `allow` の規則4行。
- Q2（DJ-4）: 受領の印 `[oe:…]` の扱い。推奨は印を残し、`AGENTS.md` と委譲の固定節に1行足す。
- Q3（DJ-5）: lease のコマンド名の検査の広げ方。推奨は許す名前の集合。
- Q4（DJ-14）: PR の数。推奨は2つ（engine と配るスキル／Codex の配布物）。
- Q5: この plan で実装に進むか。

## ゲート3 のあとの変更

（まだ無い）

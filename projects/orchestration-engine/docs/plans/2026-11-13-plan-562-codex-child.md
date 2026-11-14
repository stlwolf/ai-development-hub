---
id: "01M78B553R0EF3B63TKBGJKGP6"
title: "#562 Codex CLI を、統括の子として tmux のペインで対話的に動かす"
date: 2026-11-13
type: plan
status: stable
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
    ref: "https://github.com/stlwolf/ai-development-hub/issues/549"
    reason: "子の報告の届け方。設計SO が挙げた outbox と broker の案はこの issue の方向に近いので、follow-up として接続する"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-13-episode-562-codex-child.md"
    reason: "実行記録"
tags: [codex, delegation, agent-neutral, hooks, lease]
---

# #562 Codex CLI を、統括の子として tmux のペインで対話的に動かす

## 背景

2026-11-01 の大会の作業で、owner が Codex を直接開いて対話で使ったところ、Claude と Codex のあいだで人が文を写す作業が復活した。engine の委譲（`oe delegate`・`oe send`）は tmux のペインで対話型のエージェントを動かし、報告はファイルと1行の送信で受けるので、大部分は中で動くエージェントに依らない。ただし Claude Code に固定された箇所が少なくとも7か所ある（確定版の認識合わせ）。この plan は、その7か所それぞれを Codex でどう代えるかと、代えられないときに無しで動く形を決め、委譲ごとにエージェントを指定できる形にする。

## この plan の範囲

- やる: `oe delegate` にエージェントの指定を足し、Codex の子を `codex --no-daemon …` の形で起こす。lease のコマンド名の検査と schema を広げる。入力欄の判定に Codex の行頭を足す。受領の印と拍動を Codex の hook で書く配線と、その hook の信頼を登録する手順を決める。hook が無くても lease からペインを引ける拍動の床（spawn のときと verb のたびに書く sidecar）を engine に足す。Codex の子が `oe send` と `git commit` を承認の画面で止まらずに打てる実行ポリシーの規則を配る。復帰の案内の文をエージェントで出し分ける。委譲の書面を Claude のスキルの読み込みに頼らず渡す形を決める。Claude の子への委譲が変わらないことを検査で固定する。
- やらない: owner が自分で開く Codex の既定（`~/.codex/config.toml` の承認・sandbox・model）。ただし実行ポリシーの規則は user 層にしか置けず、owner の Codex にも効く（DJ-3）ので、その効き方は owner に見せて決めてもらう。Cursor など3つ目のエージェントへの対応（設計が特定のエージェントに閉じないかは DJ-1 で見るが、実装しない）。クラウドのエージェント（#631）。Codex を統括にすること（lease の `supervisor` の種類・`oe-handoff`・`oe-register root` の Codex 対応）。`oe-kick` への `--agent` の追加（入口は `oe delegate` に限る。`oe-kick` は今までどおり Claude の子だけを起こす）。`oe-selfcheck` の Claude 前提の検査（入力欄の `❯`・Claude の settings の配線・transcript の形）を Codex に広げること（follow-up に残す）。SO の Codex のレーンと子としての Codex の使い分け、どの作業から Codex の子に任せるか（issue の「決めること」の後ろ2つ。実機で1回回したあとに owner が決める材料が出るので、episode の follow-up に残す）。

## 前提（読んで確かめた事実）

Codex の行番号は、タグ `rust-v0.167.1`（コミット `0a94398`）の `codex-rs/` からの相対で読んだ。I1 の途中で手元の版が `codex-cli 0.167.2` に上がった（episode の I1）。`rust-v0.167.2` との差分は7ファイル（`Cargo.toml`・`config.schema.json`・`core/src/session/step_context.rs`・`features/src/lib.rs`・tests 3本）で、この plan が行番号で引いたファイルはどれも変わっていないので、行番号は 0.167.2 でも同じである [verified]（`git diff --stat rust-v0.167.1 rust-v0.167.2`）。engine の行番号は `projects/orchestration-engine/` からの相対で、`origin/master` の `5ddbdc1` で読んだ。設計SO（Codex の1レーン・2026-11-13）が指した行は、書き手が開き直して確かめたものだけを `[verified]` にした。

### Codex の側

- hook の種類は14で、`UserPromptSubmit`・`PreModelRequest`・`PostModelRequest`・`SessionStart`・`Stop` を含む [verified]（`hooks/src/lib.rs:30-44`）。公式の文書も同じ14を挙げるが、対話の画面で発火するかは書いていない [verified]（https://learn.chatgpt.com/docs/hooks ・2026-11-13）。`Stop` が対話で発火しない報告（openai/codex#17532）は open のままで、対象はリポジトリ直下の `.codex/config.toml` に書いた hook である [verified]（`gh issue view 17532 -R openai/codex`）。
- `UserPromptSubmit` の hook の標準入力は `session_id`・`transcript_path`・`cwd`・`prompt`・`turn_id`・`model`・`permission_mode` を必須で持つ [verified]（`hooks/schema/generated/user-prompt-submit.command.input.schema.json`）。`PostModelRequest` は `session_id`・`transcript_path`・`cwd`・`turn_id`・`model` に加えて、その要求の `token_usage`（必須・null になりうる）と `status` を持つ [verified]（`hooks/src/events/model_request.rs:19-31,66-80`）。`model` は文字列である [verified]（同 `75`）。
- hook が exit 0 で標準出力に素の文字列を出すと、その文字列がモデルの文脈に足される。JSON なら `hookSpecificOutput.additionalContext` が足される。exit 2 と stderr の理由で止められる [verified]（`hooks/src/events/user_prompt_submit.rs:154-247`）。hub の受領の印の hook は標準出力に何も出さないので、Codex でもモデルの文脈を汚さない。
- hook に渡る環境変数は、hook の engine が自分のプロセスの環境を `std::env::vars_os()` で写したもの [verified]（`hooks/src/registry.rs:83`）に hook ごとの上書きを足したもので [verified]（`hooks/src/engine/command_runner.rs:486-495`）、除外されるのは認証の token 系の6変数だけ [verified]（`protocol/src/shell_environment.rs:14-21`）。`TMUX_PANE` は除外されない。既定の起動は共有の daemon につなぎ、`--no-daemon` なら TUI に埋め込んだ app server を使う [verified]（`tui/src/lib.rs:1073-1110`）。11-11 の実機で、既定の起動では子のコマンドに届く `TMUX_PANE` が daemon を最初に起こしたペインの値になり、`--no-daemon` なら自分のペインの値になった（6項目の2つ）。hook も同じ engine で走るので、`--no-daemon` なら hook に届く `TMUX_PANE` も自分のペインの値になる見込みである [unverified-summary]（ソースの構造からの読み。実機の確かめ C2）。
- 同期の hook は後続の処理を待たせる [unverified-summary]（設計SO が `core/src/session/turn.rs:2788-2814` を指した。書き手は開いていない）。
- hook は、hook の定義の hash を信頼として登録しないと走らない。hash は hook の定義（イベント・matcher・組・command の文字列）から作られ、呼び先のスクリプトの本文は含まない [verified]（`hooks/src/engine/discovery.rs:836-843`・設計SO の指摘12）。登録は `~/.codex/config.toml` の `[hooks.state."<hooks.json のパス>:<イベント名の snake_case>:<組の番号>:<hook の番号>"]` に `trusted_hash = "sha256:…"` として書かれる [verified]（手元の `~/.codex/config.toml` に `pre_tool_use:0:0`〜`0:2` と `permission_request:0:0` の4件がある）。書くのは TUI の `/hooks` で [verified]（`tui/src/hooks_rpc.rs:66-98`・公式の文書）、CLI の `--dangerously-bypass-hook-trust` は、未登録でも有効な hook をその起動だけ走らせる [verified]（`codex --help`）。hub は `~/.codex/hooks.json` を `canonical/hooks/codex.hooks.json` への symlink で配っている [verified]（`scripts/sync/sync-codex.sh:294`・手元の `ls -l ~/.codex/hooks.json`）。
- `--approve-for-me` は `approvals_reviewer="auto_review"`・`approval_policy="on-request"`・`sandbox_mode="workspace-write"` の3つの上書きに展開される [verified]（`cli/src/main.rs:3246-3263` の検査）。`--approve-for-me` は `--sandbox` と `--dangerously-bypass-approvals-and-sandbox` と同時に指定できず、対話の画面では `--ask-for-approval` とも同時に指定できない [verified]（`utils/cli/src/shared_options.rs:43-50`・`tui/src/cli.rs:148-152`）。`--dangerously-bypass-approvals-and-sandbox` には alias `--yolo` がある [verified]（同 `shared_options.rs:52-58`）。auto_review は承認の要求を別のレビュアーのモデルに回す仕組みで、sandbox の外で走らせる要求・ネットワークの要求・書ける範囲の外への書き込みを扱い、否認が3回続くとターンが止まる [verified]（https://learn.chatgpt.com/docs/sandboxing/auto-review ・2026-11-13）。公式の文書は「決定論的な保証ではない」と書く。
- 実行ポリシーの規則は `rules/` の下の `.rules` ファイルで、`prefix_rule(pattern=[…], decision="allow")` の `allow` は「承認なしで sandbox の外で走らせる」[verified]（https://learn.chatgpt.com/docs/agent-configuration/rules ・2026-11-13）。ソースでは、全部の区間が allow に当たるときだけ sandbox を外す [verified]（`core/src/exec_policy.rs:466-470`）。規則は user 層（`~/.codex/rules/`）と、信頼したプロジェクトの層（`<repo>/.codex/rules/`）の両方から読む [verified]（`core/src/exec_policy.rs:688-709`・同文書）。読み込みは `DirEntry::file_type()` が通常のファイルであることを求め、symlink は読まれない [verified]（`core/src/exec_policy.rs:1201-1215`・設計SO の指摘1）。user 層の規則は owner が自分で開く Codex にも効く（子だけに効く置き場は無い）。手元の `~/.codex/rules/default.rules` には owner がほかの作業で許可した行が入っている（hub には写さない）。
- 子が打つコマンドには `CODEX_THREAD_ID`・`CODEX_SESSION_ID`・`CODEX_VERSION` が入る [verified]（`core/src/exec_env.rs:33-50`・`protocol/src/shell_environment.rs:6-8`）。11-11 の実機で `CODEX_THREAD_ID` が届くことは確かめている。環境変数の継承の既定は `inherit = all` [verified]（`protocol/src/config_types.rs:261-265`）。Claude の `CLAUDE_PID` に当たるものは無い [verified]（同ファイルに pid の変数は無い）。シェルのコマンドは bash なら `-lc` か `-c` で起こされる [unverified-summary]（設計SO が `core/src/shell.rs:24-32` を指した。書き手は開いていない）。
- 記録の `token_count` の `total_token_usage` は要求ごとの使用量を足した累積値で、いまの文脈の使用量ではない。TUI は `last_token_usage` から残量を出す [verified]（`protocol/src/protocol.rs:2545-2547`・`tui/src/chatwidget.rs:1161-1165`・設計SO の指摘5）。会話の記録は `~/.codex/sessions/YYYY/MM/DD/rollout-<時刻>-<id>.jsonl` で、1行目の `session_meta` に `id`・`cwd`・`cli_version` がある [verified]（手元の 0.167.1 の記録1件）。セッション名は `~/.codex/session_index.jsonl` に `{id, thread_name, updated_at}` の形で入る [verified]（手元）。
- `codex resume <UUID か名前>` は `--no-daemon`・`--approve-for-me`・`-s`・`-a`・`--add-dir`・`-C` を受け付ける [verified]（`codex resume --help`）。同じ記録に追記することは 11-11 の実機で「前の依頼を覚えていた・会話の ID も同じ」まで確かめている。記録のファイルに追記されるかは [unverified-summary]（調査のコメントの `[sub]`）。
- 入力欄の行頭は `›` で、reasoning effort が ultra のときだけ `»` になる [verified]（`tui/src/bottom_pane/chat_composer.rs:4967-4981`・`tui/src/bottom_pane/effort_ignition.rs:105-109`）。作業中の表示は `Working (0s • esc to interrupt)` [verified]（`tui/src/status_indicator_widget.rs:457`）で、作業中の目印の文字列 `esc to interrupt` は Claude と同じである。空の入力欄の補完の文は `Ask Codex to do anything` [verified]（同 `chat_composer.rs:5157`）。
- `CODEX_HOME` で `~/.codex` の置き場を変えられる [verified]（`core/src/config/mod.rs:999`・`codex --help` の `-p` の説明）。入力の履歴（`history.jsonl`）・SQLite の状態・shell の snapshot も `~/.codex` に書かれる [unverified-summary]（設計SO の指摘16。書き手は `ls ~/.codex` で `history.jsonl`・`*.sqlite`・`shell_snapshots/` があることだけ見た）。
- 設定の鍵 `developer_instructions` は「`developer` の役割のメッセージとして差し込む指示」で [verified]（`config/src/config_toml.rs:253-256`）、`-c 'developer_instructions="…"'` で起動のときに上書きできる（`-c` は設定の層のいちばん上 `SessionFlags` に入る [verified]（`config/src/state.rs:581`）。値は文字列の上書きで、利用者の `config.toml` に同じ鍵があればその子の中でだけ置き換わる）。turn の文脈は `config.developer_instructions` を持ち [verified]（`core/src/session/mod.rs:959`）、最初の文脈を組むときに developer のメッセージとして描かれる [verified]（同 `4803-4807`）。圧縮のあとの文脈も同じ関数（`build_initial_context_with_world_state`）で組む [verified]（`core/src/compact.rs:91`）ので、圧縮のあとも残る見込みである [unverified-summary]（呼び出しの構造からの読み。実機の確かめ C9）。resume で同じ `-c` を渡したときに効くかは、resume の経路を開いていない [unverified-summary]（統括が Codex に調べさせた答え〔作業層〕も「引数なしで再開した場合の自動保持は保証しない」と書いていた。実機の結果は C9）。
- 既定のモードでは、Codex は選択肢で尋ねる道具を使えない [unverified-summary]（調査のコメントの `[verified]`・`tools/src/tool_config.rs:6-15`。0.167.1 では開き直していない）。問いをファイルに書いて親へ送る運用がそのまま合う。
- 文中の `$スキル名` を見つけると SKILL.md の本文をそのターンに差し込む [unverified-summary]（調査のコメントの `[verified]`・`core/src/session/turn.rs:1177`）。差し込んだ本文は会話の項目として残る [unverified-summary]（設計SO の指摘14・`core/src/session/turn.rs:1230-1264`。調査のコメントの「効き目がそのターンに限る」は、これと食い違うので採らない）。Codex は `$CODEX_HOME/skills` を user のスキルの置き場として読む [unverified-summary]（設計SO の指摘14・`ext/skills/src/host_roots.rs:104-141`）。hub は `canonical/skills/` を `~/.codex/skills/` に配っている [verified]（`scripts/sync/sync-codex.sh:274`）。
- 手元の `codex` は native のバイナリ（`/opt/homebrew/Caskroom/codex/0.167.1/bin/codex`）で、プロセスのコマンド名は `codex` になる [verified]（`ls -l $(command -v codex)`）。共有の daemon は 0.167.2 のバイナリで動いていて、CLI と版がずれている [verified]（`ps -axo pid,comm`）。
- 文を送る口として `codex queue --thread <ID> --message <文>` がある [verified]（`cli/src/queue_cmd.rs:14-24`）。daemon か remote の app server に対して queue し、動いている画面にどう届くかは確かめていない [unverified-summary]。

### engine と配布物の側

- `oe-delegate` は子のコマンドを `PARENT_TMUX_PANE=… [OE_LEASE_ID=… OE_GENERATION=1] claude <引数…> [--add-dir <brief の dir>]` の1行に組み、`tmux split-window -c <workspace>` に渡す [verified]（`bin/oe-delegate:202-220,364-367`）。`exec` は書いていないが、tmux が bash の `-c` で起こす最後の単純コマンドは bash が exec で置き換えるので、前面のプロセスは claude になる [verified]（自分のペインで `ps -t <tty> -o pid=,tpgid=,comm=` の pid と tpgid が一致する行が `claude`）。検査は子のコマンドの文字列を固定で見ている [verified]（`tests/test_oe_delegate.sh:219` の `PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'`）。
- 承認のダイジェストは workspace・label・brief のパスと内容の hash・task・elevated 宣言・`claude_args` から計算する [verified]（`bin/oe-delegate:250-277`）。権限のモードは `--permission-mode` と `--dangerously-skip-permissions` から読む [verified]（同 `235-247`）。
- lease の binding は、コマンド名に `claude` を含むことを `oe_lease_bind`・`oe_lease_claim`・`oe_lease_advance` の3か所で求め、含まなければ rc 6 で止まる [verified]（`lib/lease.sh:161,258,319`）。`oe-lease adopt` も同じ検査をする [verified]（`bin/oe-lease:224`）。lease の schema も `binding.comm` と `rebinds[].comm` に `"pattern": "claude"` を持つ [verified]（`schemas/oe-lease.schema.json:45,61`・設計SO の指摘6）。`oe_tpi_proc_comm` が返すのは basename である [unverified-summary]（設計SO の指摘10・`lib/tmux-pane-identity.sh:45-52`）。`oe-delegate` は起動のあと、子のペインの前面のプロセスを読んで binding を書く [verified]（`bin/oe-delegate:393-415`）。
- lease からペインを引くときは、heartbeat の sidecar の候補を取ってから前面のプロセスで確かめる [verified]（`lib/lease.sh:514-517`）。ラベルで送るとき、ラベルが合い binding のある lease が1件あれば lease の経路に入り、sidecar が無くても registry には落ちず、送信は保留（`delivery_held`）になる。registry に落ちるのは binding のある候補が無いときだけである [verified]（`lib/target-resolve.sh:119-137`・設計SO の指摘4）。
- `oe_lease_whoami` は `OE_LEASE_ID` が無いとき `CLAUDE_CODE_SESSION_ID` だけで自分の lease を探す [verified]（`lib/lease.sh:482-483`）。`oe-lease`（`create --root`・`bind`）・`oe-register`・`oe-recover`・`oe-handoff` は `CLAUDE_PID` と `CLAUDE_CODE_SESSION_ID` を読む [verified]（`bin/oe-lease:52-58,81,118`・`bin/oe-register:52`・`bin/oe-recover:192`）。`oe-send --to-parent` は `OE_LEASE_ID` だけで親を引く [verified]（`lib/target-resolve.sh:22-26`）。
- 送る側の入力欄の判定は、画面全体から行頭 `❯` の行を集めて最後の1行を採る [verified]（`lib/delegate-send.sh:33-36`）。入力欄に内容があるかは `${1#*❯}` で記号を外してから見る [verified]（同 `41-50`）。空の入力欄の補完の判定は `Try "` [verified]（同 `46-48`）、作業中の目印は `esc to interrupt` [verified]（同 `66,221`）。finalize を切る環境変数 `OE_SEND_FINALIZE` は送る側のプロセスで読む [verified]（同 `219`）。
- 拍動の sidecar は `~/.claude/state/oe-heartbeat/<session_id>.json` に `{ts, context_pct, pane, server_pid, model: {id, display_name}, lease_id, generation}` の形で書かれ [verified]（`canonical/claude/statusline/statusline-oe-heartbeat.sh:61-124`）、読む側は `model.display_name` を使う [verified]（`bin/oe-tree:591`）。読むのは `oe-tree`（装飾・900秒の窓）・`oe-threads`・`oe-vitals`・`oe-selfcheck`（pane の橋）・`lib/heartbeat-resolve.sh` である [verified]（`bin/oe-tree:531-690`・`bin/oe-selfcheck:292-310`）。`lib/heartbeat-resolve.sh` は、sidecar の `lease_id` と `generation` が一致するか、`session_id` が渡した並びにあるものを候補にする [verified]（同ファイルの冒頭の説明）。
- 受領の印の hook は `.prompt` と `TMUX_PANE` しか読まず、標準出力に何も出さない [verified]（`canonical/hooks/scripts/oe-prompt-receipt.sh`）。Codex 向けの配線は `canonical/hooks/codex.hooks.json` に `PreToolUse` の3本だけがある [verified]。`block-force-push.sh` が見るのは `git push` の引数だけで、`gh` の操作は見ない [verified]（`canonical/hooks/scripts/block-force-push.sh:884-890`）。
- `oe-selfcheck` は入力欄を `❯` で探し、hook の配線は Claude の settings と配備パスで見る [verified]（`bin/oe-selfcheck:136,179-187`）。`oe-kick` は `--claude-arg` だけを受ける [verified]（`bin/oe-kick:61-73`）。
- `canonical/codex/AGENTS.md` には engine への言及が無い [verified]。復帰の案内は `claude --resume <sid>` の文で出る [verified]（`bin/oe-recover:111-130`・`bin/oe-handoff:1299,1398`）。

## 設計判断

owner に聞くものは「GATE 3 の問い」に出し、ここには推奨を書く。印の無いものは自分で決めた。確かめの結果で分かれるものは「実機の確かめ」節に分かれ方を書く。設計SO で直した箇所は、各 DJ の末尾に「SO」で始まる行で示す。

### DJ-1 委譲ごとのエージェントの指定（自分で決めた）

- `oe delegate --agent <claude|codex>` を足す。指定が無いときは `claude` で、子のコマンドの文字列は今と1文字も変えない（受入 A-1）。
- 名前は `agent`（値は CLI の実行ファイルの名前そのもの）。候補は `--agent`・`--runner`・`--cli` で、`agent` は issue の本文と #564 の役割の語（統括・子・エージェント）に合い、値がそのまま `command -v` に渡せる識別子になるので採る。`--claude-arg` は `--agent-arg` に改名し、`--claude-arg` は alias として残す（今の呼び出し元 `oe-kick`・`delegate-task` の文が壊れない）。
- エージェントごとの差のうち engine の中のもの（起動の引数・権限のモードの読み方・コマンド名の集合・自分の pid と session_id の読み方・復帰の案内の文・送る側の finalize の既定）は `lib/agent.sh` の1か所に寄せ、verb はそこを引く。hook のスクリプト・配布物・表示までは1か所に寄らないので、「3つ目のエージェントを足すときに触るのはこのファイルだけ」とは言わない（#537）。
- registry の記録と lease の記録に `agent` の項目を足す（無ければ `claude` と読む）。読む側（`oe-tree`・`oe-recover hint`）が復帰の案内と表示に使う。schema（`schemas/oe-lease.schema.json`）に任意の項目として足す。
- 承認のダイジェストには `agent` を常に入れ、`claude_args` の鍵の名前は `agent_args` に変える。claude の承認で codex を起こす差し替えを照合で落とすためである。鍵が変わるので、**更新の前に `--print-approval` で取り、更新のあとに実行する承認は不一致で止まる**（取り直せば済む。安全側）。検査は値を固定していない（`tests/test_oe_delegate.sh:212-233` は形と一致だけを見る）。
- SO: 「このファイルだけ」の言い切りと「既存の承認には影響しない」を直した（指摘9）。

### DJ-2 Codex の子を起こす1行（自分で決めた・C6 で確かめる）

- `PARENT_TMUX_PANE=… OE_LEASE_ID=… OE_GENERATION=1 codex --no-daemon <承認のモードの引数> [--add-dir <brief の dir>]` を、Claude と同じ形で `tmux split-window -c <workspace>` に渡す。C6 で前面のプロセスが `codex` にならなければ、**Codex の分岐だけ**に `exec` を書く。Claude の1行は変えない（受入 A-1）。
- `--no-daemon` は固定で付ける（11-11 の実機）。版のずれた共有の daemon を避ける効果もある。
- `-c check_for_update_on_startup=false` も固定で付ける（補正 H1）。起動の直後に出る更新の確認の画面を出さないためで、I1 でこの画面に送った1行の Enter が「Update now」を選んで `brew upgrade --cask codex` が走った（episode の I1）。鍵は `config/src/config_toml.rs:533`、効き方は `tui/src/updates.rs:28,153` [verified]。無しで動く形は無い（画面が出れば最初の1行が選択肢に流れる）。残る危険として、フォルダの信頼の確認（新しい workspace を初めて開くとき）と hook の確認（未登録の hook があるとき）も起動の直後に出る。前者は worktree ごとに出るので、`oe-delegate` は Codex の子を起こしたあと、最初の1行を送る前に画面に `Trust this folder?` が出ていれば、もとのリポジトリを owner が信頼済みのときだけ Enter を1回送る（H8・owner の答え Q113。文言は実機で見たもので、版が変われば効かなくなるので `lib/agent.sh` の定数にし、README に書く）。後者は owner が `/hooks` で登録するまで出続けるので、README の手順で済ませる。
- C6 の結果: `exec` を書かなくても前面のプロセスは `codex` になった（Claude と同じ）。`exec` は書かない。
- `--add-dir` は、brief の置き場（統括のワークスペースの `.oe/`）が子の workspace（worktree）の外にあるとき、子が `.oe/question-*.json` と `.oe/report-*.md` を書けるようにするために付ける。Codex の `--add-dir` は書ける範囲を広げる引数で [verified]（`codex --help`）、Claude の `--add-dir`（読める範囲）とは意味が違うが、必要な効果（読める・書ける）は同じになる。読めることは C7 で確かめる。
- SO: Claude の1行に `exec` を足す案を取り下げた（指摘9）。

### DJ-3 子の Codex を起こすときの承認のモードの既定（owner に聞く・Q1）

（2026-11-13 に H10 で置き換えた。規則は `oe` の1行だけにし、git と状態の置き場と tmux は起こす1行で渡す。下の「ゲート3 のあとの変更」の H10 を見る。）

- 推奨: **`--approve-for-me` を既定にし、engine の verb と git の commit を実行ポリシーの `allow` の規則で sandbox の外に出す。** 規則は hub が `canonical/codex/rules/oe-child.rules` として持ち、`sync-codex.sh` が `~/.codex/rules/oe-child.rules` に**通常のファイルとして写す**（symlink は読まれない。hook のスクリプトと同じく内容を比べて更新する）。中身は `prefix_rule(pattern=["oe"], decision="allow")` と `prefix_rule(pattern=["git", "commit"], decision="allow")` の2行にとどめる。
- **この規則は owner が自分で開く Codex にも効く。** 実行ポリシーの規則は user 層（と信頼したプロジェクトの層）にしか置けず、子だけに効く置き場は無い。`oe` と `git commit` は owner の Codex でも承認なしで走ることを、owner に見せて決めてもらう（Q1 の「何を決めるか」に書く）。
- C4 の結果: `oe send`・`git commit` は承認の画面に止まらずに通った。規則の無いコマンドが sandbox の中で失敗したとき（`curl`・`tmux`）、モデルは sandbox の外で走らせる要求を出さず、失敗をそのまま報告した（auto_review は呼ばれなかった）。つまり `git push`・`gh` は「レビュアーが裁く」より「失敗してモデルに返る」ほうが起きやすい。子が PR を作るとき、push は統括が子の画面で承認する代わりに、子が失敗を報告したら統括が自分で push する運びになりうる。規則に足すかは実機で1回回したあとに owner が決める（follow-up・変わらず）。
- `git push` と `gh` は規則に入れない。`gh` を allow にすると GitHub 上の変更の操作（issue・PR の作成と編集）まで承認なしになり、`block-force-push.sh` は `git push` の引数しか見ない。子が PR を作るときの `git push` と `gh pr create` は auto_review に回る（決定論ではないが、止まったら統括が子の画面で承認する。M-1 の「承認の画面で止まった回数」はこの2つを別に数える）。規則に足すかは、実機で1回回したあとに owner が決める（follow-up）。
- 理由: Claude の auto mode に近い（承認の要求を機械が裁く・破壊的な操作は hub の hook が止める）。auto_review はモデルが裁くので、報告の `oe send` のように毎回必ず通したいものは規則で決定論にする。`allow` は sandbox の外で走るので、tmux のソケットにつなげない問題（11-11 の実機）も消える。
- 引数の組み立て: `lib/agent.sh` が既定の承認の引数（`--approve-for-me`）を持ち、`--agent-arg` に `-s`・`--sandbox`・`-a`・`--ask-for-approval`・`--dangerously-bypass-approvals-and-sandbox`・`--yolo`・`--approve-for-me` のどれかがあれば**既定の承認の引数を外してから**並べる（`--approve-for-me` は `-s`・`-a`・bypass と同時に指定できないため）。
- elevated の判定: Claude の `bypassPermissions` に当たるものとして、`--dangerously-bypass-approvals-and-sandbox`・`--yolo`・`-s danger-full-access`・`--sandbox danger-full-access` を elevated と読む。`-a never` だけなら elevated ではない（sandbox は残る）。`extract_permission_mode` を `lib/agent.sh` に移し、エージェントごとの表にする。
- ほかの案:
  - `-a never -s workspace-write` と同じ規則。レビュアーのモデルを使わないので止まらないが、規則に無いコマンド（`curl`・`npm publish` など）は sandbox の中で失敗してモデルに返るだけで、人にも機械にも聞く道が無い。
  - `--dangerously-bypass-approvals-and-sandbox` を既定にする。engine では elevated として owner の承認のダイジェストを必須にする。既定にはせず、owner が明示したときだけ使える形で残す。
  - 規則を配らず auto_review に任せる。報告の送信がモデルの裁きに依り、否認が続くとターンが止まる。
  - 子に tmux のソケットを開かせず、子は workspace の中の outbox に報告を書き、ホスト側の broker が `oe send` と受領の記録を担う（設計SO の案A）。`oe` の allow が要らなくなるが、常駐の処理と重複配送の扱いが要る。#549（子の報告の届け方）の方向に近いので、この issue では採らず #549 の材料として episode の follow-up に残す。
- SO: symlink を通常のファイルに、規則の効く範囲を owner に見せる形に、`gh`・`git push` を規則から外す形に、引数の上書きの規則と elevated の表を足した（指摘2・3）。

### DJ-4 受領の印 `[oe:…]` の扱い（owner が決めた・Q2 → Q112・2026-11-13）

- 決定: **印は今のまま付け、受領の印の決まり（「文末の `[oe:<26文字>]` は配送の受領印で、依頼の一部ではない。写さず、コマンドに含めない」）は、子を起こす1行の `-c developer_instructions="…"` と、委譲の書面の固定節で伝える。`canonical/codex/AGENTS.md` には engine の約束ごとを書かない。** これは指示であって、モデルが絶対に写さない保証ではない（写した印は害にならず、見つけたら直す）。
- 理由（owner・統括）: engine を独立したパッケージにしたとき（#537）、`AGENTS.md` は付いてこない。`-c developer_instructions` は起こした側がその1つのセッションにだけ持ち込める指示で、developer の役割のメッセージとして文脈に入り、圧縮のあとも最初の文脈を組む関数で入り直す見込み（前提の節）。利用者が自分で開いた Codex には効かない。
- 組み立て: 決まりの本文は `lib/agent.sh` が持ち、`oe-delegate` は `--agent codex` のとき1行に `-c developer_instructions="<本文>"` を足す。本文は TOML の文字列として1引数に収め、改行と二重引用符を含めない（`shell_quote` で囲む）。報告の返し方（`oe send --to-parent`）と問いの書き方（ファイルに書いて送る・対話の選択肢を使わない）も同じ本文に入れる（engine の約束ごとはここに集める）。Claude の子へ送る1行は変えない（受入 A-1）。
- 上書きの扱い: `developer_instructions` は文字列の上書きなので、利用者が `~/.codex/config.toml` に同じ鍵を持っていると、その子の中でだけ利用者の値が engine の本文に置き換わる。`oe-delegate` は `--agent codex` のとき `codex` の設定に同じ鍵があるかを `$CODEX_HOME/config.toml` で見て、あれば stderr に「利用者の `developer_instructions` はこの子の中では engine の本文に置き換わる」と1行出す（止めない。足し合わせる口は 0.167.1 の文字列の鍵には無い）。
- resume: `oe-recover hint` が出す Codex の案内の1行にも同じ `-c developer_instructions="…"` を含める（DJ-9）。
- C9 の結果: 子は印をコマンドに写さなかった。`/compact` のあとも写さず、圧縮の履歴に developer のメッセージが残った。同じ `-c` を付けた resume のあとも、`-c` 無しの resume のあとも（圧縮の履歴に残っているため）、モデルは決まりを言えた。`codex debug prompt-input -c 'developer_instructions="…"'` で、モデルに見える入力に developer のメッセージとして入ることをモデルを呼ばずに確かめられる（T-2 に足す・補正 H3）。
- 圧縮と resume のあとに効くかは実機で確かめる（C9）。効かなければ、`SessionStart` の hook（matcher `compact|resume`）で `additionalContext` として入れ直す形に落とし、それも発火しなければ、子へ送る最初の1行に決まりの文を添える形（1回だけ）に落とす。
- ほかの案（取り下げ）: `AGENTS.md` に1行足す（hub の中でだけ効き、独立したときに付いてこない）。`UserPromptSubmit` に説明用の handler を足して印のある prompt にだけ `additionalContext` で伝える（C1 に依る。C9 で `developer_instructions` が足りなければ候補に戻す）。宛先が Codex のときは印を付けない（受領の突き合わせを失う）。
- 根拠の出どころ: 統括が Codex に調べさせた答え（`.oe/so-562-q112-codex-answer.md`・作業層）。そこに書かれた主張のうち設計に使うもの（鍵の意味・`-c` の層・最初の文脈と圧縮の経路）は、書き手が 0.167.1 のソースを開いて確かめ、前提の節に行番号で書いた。resume の経路は確かめていない。
- SO: 「保証ではない」と、説明用の handler を既存の hook と分けることを書いた（指摘13）。

### DJ-5 lease のコマンド名の検査の広げ方（owner に聞く・Q3）

- 推奨: **検査を「許す名前の集合」にし、集合は `lib/agent.sh` の定数（`claude`・`codex`）で持ち、basename の完全一致で見る。** `oe_lease_bind`・`oe_lease_claim`・`oe_lease_advance`・`oe-lease adopt` の4か所が同じ関数を呼ぶ。schema の `binding.comm` と `rebinds[].comm` の `pattern` も `^(claude|codex)$` に広げる。lease の記録には `agent` を別に書く（DJ-1）が、検査には使わない。
- 理由: 検査の目的は、前面のプロセスが wrapper のシェルになっていないことを見ることで（knowledge `01M6XN85N408CMMERA12QR1C3F`）、本人の確認は pid と開始時刻の照合が担う。エージェントの種類の一致まで求める必要は無い。`agent` を表示と案内の材料と割り切るので、復帰の案内と実際のプロセスが食い違うことはありうる（交代でエージェントが変わるときは `agent` を更新する契約にする。将来の作業）。
- ほかの案:
  - lease の記録の `agent` と突き合わせる。厳しいが、`agent` の無い古い記録の扱いが要る。
  - 検査を外す。wrapper のシェルに binding する事故（#355 の drill）を再び許す。
- SO: 完全一致・schema の修正・`agent` と実際の食い違いの許容を書いた（指摘6・10）。

### DJ-6 拍動の statusLine の代わり（自分で決めた・C3 で分かれる）

- Codex には外部コマンドを呼ぶ statusLine が無い [verified]（`config/src/types.rs:968-972`）。代わりを2段で作る。
- **床（engine・hook に依らない）**: (1) `oe-delegate` は子を起こして binding を書いたあと、`<lease_id>.json` の名前で sidecar を1件書く（`ts`・`pane`・`server_pid`・`lease_id`・`generation`・`context_pct: 0`・`model: {}`・`agent`）。`lib/heartbeat-resolve.sh` は `lease_id` と `generation` の一致で候補を選ぶので、session_id を知らなくても lease からペインを引ける。(2) 子が `oe send` を打つたびに、`OE_LEASE_ID` と `TMUX_PANE` があれば同じ sidecar を書き直す（床の更新）。どちらもエージェントに依らず、Claude の子にも効く（Claude では statusLine の sidecar と並ぶだけで、読む側はいちばん新しいものを選ぶ）。
- **hook（Codex）**: `PostModelRequest` と `UserPromptSubmit` の hook で、新しいスクリプト `canonical/hooks/scripts/oe-heartbeat-hook.sh` が `<session_id>.json` の sidecar を書く（名前は「hook で書く拍動」の意味で、エージェントの名前を入れない）。`session_id` は標準入力の `session_id`、`pane` は `TMUX_PANE`、`server_pid` は `$TMUX` から（Claude の書き手と同じ導出）、`model` は標準入力の `model`（文字列）を `{id: <文字列>, display_name: <文字列>}` に直して書く（読む側が `display_name` を使うため）、`context_pct` は `PostModelRequest` の標準入力の `token_usage` の `total_tokens`（文脈の中のトークン数。`input_tokens` は cached を含むので足し合わせない・H7）を `model_context_window` で割って出す。`model_context_window` は標準入力に無いので、`transcript_path` の記録を**末尾から上限付き**（最後の 200 行）で読んで `token_count` の `model_context_window` を取り、取れなければ `context_pct: 0` にする。`UserPromptSubmit` では `context_pct` を前の sidecar の値のまま残す。記録の `total_token_usage`（累積）は使わない。
- hook は同期で後続を待たせるので、記録の全件走査をせず、`tail` の上限と `timeout 2` を置く。実行時間は C3 で測って episode に書く。
- 無しで動く形: hook が発火しなければ、床だけで動く。`oe-tree` は model と context% を出さずに子を表示し、lease からペインを引く経路は床の sidecar で通る。床の更新は子が `oe send` を打ったときだけなので、900秒の窓を超えて黙っている子は、`oe-tree` には registry から出るが、ラベルでの送信は保留になる（生のペイン番号と lease_id では送れる）。これは Claude の子が statusLine を切っているときと同じ振る舞いである。
- SO: 床を足し、`context_pct` の出し方を `token_usage` と `last` 系の値に、`model` を object に、読み方を上限付きにし、「registry に落ちる」の誤りを直した（指摘4・5・17）。

### DJ-7 受け取りの印の hook（自分で決めた・C1 で分かれる）

- `canonical/hooks/scripts/oe-prompt-receipt.sh` をそのまま使い、`codex.hooks.json` の `UserPromptSubmit` に配線する。スクリプトは `.prompt` と `TMUX_PANE` しか読まないので変更は要らない。
- セッション名の hook（`session-name.sh`）は Claude 固有の出力なので Codex には配らない。Codex のセッション名は `/rename` で付けられるが [verified]（`tui/src/slash_command.rs:32,102`）、engine から機械で付ける口は無い。無しで動く（`codex resume` は UUID でも開ける）ので、この issue では付けない。
- 無しで動く形: 発火しなければ受領の印が出ず、`oe-confirm` は「確認できていない」を出す（断定しない決まりはそのまま）。統括は子の返事で受け取りを確かめる。

### DJ-8 会話の ID と自分のプロセス（自分で決めた・C6 で確かめる）

- C6 の結果（補正 H2）: Codex の sandbox の中では `ps` が `Operation not permitted` で失敗する。`$PPID` をたどる処理は、規則で sandbox の外に出る `oe` の verb の中でだけ動く。子が `oe lease …`・`oe recover` を打つ分には規則の `oe` に当たるので動くが、README に「`oe` の規則が無いと自分の pid を読めない」と書く。
- 子の側で自分を名乗る経路（`oe-lease bind`・`oe-lease whoami` の実体 `oe_lease_whoami`・`oe-recover`）は、`lib/agent.sh` の `oe_agent_self` で (agent, pid, session_id) を引く。Claude は `CLAUDE_PID`・`CLAUDE_CODE_SESSION_ID`（今のまま）。Codex は session_id を `CODEX_THREAD_ID` から取り、pid は自分の親を `ps -o ppid=` でたどってコマンド名が `codex` の最初のプロセスを採り、**そのペイン（`TMUX_PANE`）の前面のプロセスの pid と開始時刻に一致することまで確かめる**（別の Codex を拾う誤りを弾く）。たどれなければ今と同じ文言で止まる。`oe_lease_whoami` の `CLAUDE_CODE_SESSION_ID` だけの fallback も、`oe_agent_self` の session_id に替える。
- `oe-register root`・`oe-handoff` は統括の verb で、Codex を統括にするのは範囲の外なので触らない。
- SO: lib の `oe_lease_whoami` の経路と、前面のプロセスとの突き合わせを足した（指摘7・11）。

### DJ-9 resume の案内（自分で決めた・C5 で確かめる）

- `oe-recover hint` と `oe-handoff` が出す案内の文を、lease の `agent` で出し分ける。Codex は `cd <ws> && OE_LEASE_ID=… OE_GENERATION=… codex --no-daemon -c developer_instructions="<本文>" resume <sid>`（本文は `lib/agent.sh` の同じものを `shell_quote` で囲む。DJ-4）。`agent` の無い記録は claude とする。engine は自動では再開しないので、変更は文だけである。
- 一覧から探す案内（`claude -r cockpit …`）は統括向けなので変えない。

### DJ-10 入力欄の判定（自分で決めた・C8 で確かめる）

- 入力欄の行頭の記号を `lib/agent.sh` の定数（`❯`・`›`・`»`）にし、`_oe_send_inputline` の正規表現を `^[[:space:]]*[❯›»]` に、`_oe_send_has_content` の記号を外す処理を同じ集合にする（`${1#*❯}` のままだと空の `›` が内容ありと判定され、finalize が切れる）。空の入力欄の補完の判定に `Ask Codex to do anything` を足す。作業中の目印 `esc to interrupt` は Codex も同じ文字列なので変えない。
- 判定は画面全体の一致する行の最後を採るので、Claude の本文やコードに `›` や `»` の行があり入力欄が見えない条件では、その行を拾いうる。送る側は宛先のエージェントを registry か lease の `agent` で引けるので、Codex の宛先にだけ `›`・`»` を足す形にし、Claude の宛先は今のまま `❯` だけにする。
- C8 の fallback（Codex の宛先で finalize を切る）は、**送る側**で `lib/agent.sh` の「エージェントごとの finalize の既定」を読む形にする（子の環境に置いても送る側には効かない）。
- SO: `_oe_send_has_content`・`»`・宛先ごとの判定・送る側で切る形を足した（指摘8）。

### DJ-11 委譲の書面の渡し方（自分で決めた）

- 書面は自己完結のファイルにし、従う手順はスキルの名前でなく SKILL.md のパスで指す。送る1行は今のまま「`<brief のパス>` を読んで進めて。」にする。`doc-flow-guardrail` の「spec 解決規約」と並べて「skill 解決規約」を足す: スキルは `<設定ルート>/skills/<名前>/SKILL.md`（`~/.claude/…`・`$CODEX_HOME`（既定 `~/.codex`）`/…`・`~/.cursor/…`）で解決し、hub のワークスペースなら `canonical/skills/<名前>/SKILL.md`。**読む前にファイルの有無を確かめ、無ければ依頼元に聞く**（配られていない環境のため）。brief の固定節で名前だけ書いてあるスキルは、この規約で読めると固定節の冒頭に1行書く。
- `$スキル名` を送る1行に足す案は、Codex だけの書き方なので採らない（「効き目がそのターンに限る」は根拠にしない。前提の節を見よ）。エージェントごとに書面を作り分ける案は固定節を2通り持つことになるので採らない。
- スキルの本文に残る Claude 固有の記述（選択肢で尋ねる道具を前提にした文など）は、この issue では直さない。Codex の子が踏んだものを episode の follow-up に残す。
- SO: `$スキル名` を採らない理由と、有無の確かめを直した（指摘14）。

### DJ-12 hook の信頼の登録と配り直し（自分で決めた）

- `codex.hooks.json` に `UserPromptSubmit` と `PostModelRequest` の組を足すと、Codex はその hook を未登録として黙って飛ばす。登録は owner が Codex の対話の画面で `/hooks` を開いて1回行う。`PreToolUse` の既存の3本の鍵（`pre_tool_use:0:0`〜`0:2`）は別のイベントなので番号がずれず、登録し直しは要らない。
- 信頼の hash は hook の**定義**（イベント・matcher・command の文字列）から作られ、呼び先のスクリプトの本文は含まない。つまり `hooks.json` の定義を変えたときだけ登録し直しが要り、スクリプトの中身だけを変えたときは要らない（その代わり、スクリプトの差し替えは信頼の仕組みでは止まらない）。手順は `canonical/hooks/README.md` の Codex の節にこの区別で書く。
- `--dangerously-bypass-hook-trust` を子の起動に付ける案は採らない。この flag は未登録の hook を全部走らせるもので、hub の止める側の hook を含めて「登録して走らせる」という前提を外すことになる。
- 登録されているかを機械で見る検査（`oe-selfcheck` が `[hooks.state]` の鍵の有無を見る）は、hash を再計算できないので「登録の有無」までしか言えない。この issue では README の手順と、実機の確かめの2段階目（Codex の画面から受領の印が出ること）で代える。
- SO: hash の対象と bypass の意味を直した（指摘12）。

### DJ-13 `AGENTS.md` への追記（owner が決めた・Q112 の答えで縮めた）

- `canonical/codex/AGENTS.md` に足すのは「委譲された子として起こされたら、渡された書面（brief）の固定節に従う」の1行だけにする。engine の約束ごと（受領の印・報告の返し方・問いの書き方）は AGENTS.md に書かず、`-c developer_instructions` と書面の固定節で伝える（DJ-4）。
- `scripts/check-codex-guardrails.sh` の整合の検査が通ることを確かめる。

### DJ-14 PR の単位（owner に聞く・Q4）

- 推奨: **2つに分ける。** PR-1 は engine と配るスキル（`oe-delegate --agent`・`lib/agent.sh`・lease の検査と schema・拍動の床・入力欄の判定・`oe-lease`/`oe-recover` の自分の読み方・案内の文・engine の検査・`delegate-task`/`doc-flow-guardrail` の文・plan と episode）。PR-2 は Codex の配布物（`codex.hooks.json` の配線・`oe-heartbeat-hook.sh`・`canonical/codex/rules/oe-child.rules`・`sync-codex.sh`・`AGENTS.md`・hooks の README）。
- PR-1 だけが着地した状態の使い方: `--agent codex` は動くが、拍動は床（spawn のときと `oe send` のたび）だけ、受領の印は無し（`oe-confirm` は「確認できていない」）、承認は auto_review だけ（規則が無いので `oe send` は承認の要求に回る）。`oe-delegate` は `--agent codex` のとき `$CODEX_HOME/rules/oe-child.rules` が無ければ stderr に「規則が無いので報告の送信が承認に回る」と1行出して続ける（止めない）。この制限は `bin/README.md` に書く。
- 理由: PR-1 は engine の検査（bash 5 と 3.2）で閉じ、Claude の子への委譲が変わらないことを機械で確かめられる。PR-2 は owner が `/hooks` で信頼を登録する手作業を含み、着地のあとに owner の手が要る。境目は #537 の engine と配布物の境目と同じである。4つ以上にはならない見込みで、issue を分ける案は出さない。
- ほかの案: 1つにまとめる。差分が engine・hooks・スキル・AGENTS.md にまたがり、Copilot の1ラウンドと実装SO の範囲が広くなる。
- SO: PR-1 だけの状態の使い方を書いた（指摘15）。

### DJ-15 名前（自分で決めた・#564 の決まり）

- 足す名前: `agent`（委譲ごとのエージェント。値は `claude`・`codex`）・`agent_args`（起動の追加引数。`--agent-arg`）・`lib/agent.sh`（エージェントごとの差を置く lib）・`oe-heartbeat-hook.sh`（hook で書く拍動）・`oe-child.rules`（子の Codex の実行ポリシー）。どれもプログラムの識別子として書け、日本語の言い換えを作らない。
- 変えない名前: `heartbeat`・`receipt`・`registry`・`lease`（#564 の表のとおり）。

## 7か所の対応表

| Claude Code に固定された箇所 | Codex での代え | 代えられないときに無しで動く形 | 確かめ |
|---|---|---|---|
| 拍動の statusLine | `PostModelRequest`・`UserPromptSubmit` の hook で同じ sidecar を書く。床として spawn のときと `oe send` のたびに engine が書く（DJ-6） | 床だけで動く。`oe-tree` は model と context% なし。900秒を超えて黙る子はラベルでの送信が保留になる | C3 |
| 受け取りの印の hook | `UserPromptSubmit` に同じスクリプトを配線（DJ-7）。印の決まりは `-c developer_instructions` と書面の固定節で伝える（DJ-4） | 受領の印なし。`oe-confirm` は「確認できていない」。統括は子の返事で確かめる | C1・C2・C9 |
| 会話の ID | `CODEX_THREAD_ID`。`oe_lease_whoami` の fallback も読み替える（DJ-8） | （代えられる） | 11-11 済み |
| resume | `codex --no-daemon resume <sid>` の案内（DJ-9） | （代えられる。engine は自動で再開しない） | C5 |
| 起動のコマンド | `codex --no-daemon <承認の引数>`（DJ-2・DJ-3） | （代えられる） | C4・C6・C7 |
| lease のコマンド名の検査 | 許す名前の集合と schema の pattern（DJ-5） | （代えられる） | C6 |
| 入力欄の判定 | 宛先が Codex のとき行頭 `›`・`»` と補完の文を足す（DJ-10） | finalize を切る。Enter が吸われたときの打ち直しが無いが、送信そのものは 11-11 で通っている | C8 |

7か所の外で Claude に固定されていて、この issue で扱わないもの（範囲の外・follow-up）: `oe-selfcheck` の入力欄の `❯`・hook の配線と transcript の検査（Claude の settings と置き場に固定）、`oe-kick`（`--claude-arg` だけ）、`session-name.sh`（Claude の出力の形）、`oe-register root`・`oe-handoff`（統括の verb）。

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

設計を固める前に、いまの形（tmux のペインで対話型の Codex を起こし、`send-keys` で送り、hook で印と拍動を書く）を前提にせずに考えた代替を挙げ、採らない理由を書く。最初の4つは書き手が挙げ、あとの2つは設計SO が挙げた。

- 非対話の `codex exec` をサンドイッチの実装の層に使う（`lib/spawn.sh` の `claude -p` と同じ系）。往復（問い・答え・直しの依頼）が1回ごとに新しいプロセスになり、issue の「対話で動かす」に合わない。SO のレーンと同じ形に戻るだけである。
- engine の読む側が Codex の記録（rollout）を直接読み、hook を使わない。拍動を書く側が要らなくなるが、engine が Codex のファイルの置き場と形を知ることになり、Claude の経路（sidecar を読む）と二重になる。hook と床で同じ sidecar を書けば読む側は1つのままなので、こちらを採る。
- 送る口を `tmux send-keys` でなく `codex queue --thread <ID> --message` にする。入力欄の判定と Enter の吸収の問題が消えるが、daemon か app server への接続が前提で、`--no-daemon` と両立するか・動いている画面にどう届くかを確かめていない。`send-keys` は 11-11 の実機で通っているので、この issue では変えず、follow-up に残す。
- エージェントごとに委譲の固定節を作り分ける。Claude 固有の記述を Codex の書面から消せるが、固定節が2通りになり、直すたびに両方を合わせる負債になる。パスで指す1通りの書面にし、Claude 固有の記述は踏んだときに直す。
- 子に tmux のソケットを開かせず、子は workspace の中の outbox に報告と配送の要求を書き、ホスト側の broker が lease と宛先と nonce を確かめて `oe send` と受領の記録を担う（設計SO の案A）。差分の軸は「配送の権限をモデルのシェルから engine の常駐の処理へ移す」。成立の条件は、常駐の処理と、要求の重複・宛先の制限・再起動後の再配送を決められること。`oe` の allow の規則が要らなくなる。隠れていた前提は「報告する子自身が `oe send` を打つ」。#549（子の報告の届け方を見直す）の方向に近く、この issue の範囲（engine の起動と送信の部分）を超えるので採らず、#549 の材料として episode の follow-up に残す。
- 通信と観測を MCP の道具として子に渡す（設計SO の案B）。ホスト側の MCP の server が `report_to_parent` のような限定の道具を提供し、子のシェルには `oe` の allow を与えない。差分の軸は「CLI の prefix の許可から、用途別の構造化された能力へ境界を移す」。成立の条件は、子の Codex に MCP の接続を配備し、道具の承認と server の寿命を管理できること。隠れていた前提は「エージェント共通の口はシェルのコマンドである」。Claude と Codex の両方に MCP の口があるので筋はよいが、配備と承認の仕組みが新しく要り、この issue の範囲を超える。案A と同じく #549 の材料にする。

## 設計SO（ゲート2・弱・Codex の1レーン）

- 実施: 2026-11-13・`so-compare --codex-only`・gpt-6.1-sol（`model_resolved_source=config`・観測値ではない）・`codex-cli 0.167.1`・1回目で返った（517秒・`tool_status=not_observed`）。依頼文は plan のパスと検証してほしい点12件と選択肢の拡張で、`.oe/` の中身とほかのリポジトリの情報は入れていない。
- 判定: `VERDICT: refuted`（must 10・should 8）。must はすべて書き手がソースを開き直して確かめ、18件すべてを採った。採り方は次のとおり。

| # | 級 | 指摘 | 採否と反映 |
|---|---|---|---|
| 1 | must | `.rules` の symlink は読まれない（`exec_policy.rs:1201-1215`） | 採る。通常のファイルとして写す（DJ-3） |
| 2 | must | user 層の規則は owner の Codex にも効く。`gh` の allow は GitHub 上の変更まで通す | 採る。効く範囲を Q1 に書き、`gh`・`git push` を規則から外した（DJ-3） |
| 3 | must | `--approve-for-me` は `-s`・`-a`・bypass と競合し、追記では上書きできない。elevated の表が足りない | 採る。既定を外してから並べる規則と elevated の表（DJ-3） |
| 4 | must | binding のある lease は sidecar が無くても registry に落ちず保留になる（`target-resolve.sh:119-137`） | 採る。床の sidecar を足し、「無しで動く形」を書き直した（DJ-6・対応表） |
| 5 | must | `total_token_usage` は累積。`PostModelRequest` の入力に `token_usage` がある。hook は同期 | 採る。`token_usage` から出し、記録の読みを上限付きに（DJ-6） |
| 6 | must | lease の schema の `comm` が `claude` 固定 | 採る。schema の pattern を広げる（DJ-5） |
| 7 | must | `oe_lease_whoami` の fallback が `CLAUDE_CODE_SESSION_ID` だけ | 採る（DJ-8） |
| 8 | must | `_oe_send_has_content` の記号の除去・`»`・画面全体の最後の行・fallback は送る側 | 採る（DJ-10） |
| 9 | should | 「このファイルだけ」と「既存の承認に影響しない」と Claude への `exec` 追加 | 採る（DJ-1・DJ-2） |
| 10 | should | 集合は basename の完全一致で足りる。`agent` と実際の食い違いを許容すると書く | 採る（DJ-5） |
| 11 | should | 祖先の探索は成立しうるが、前面のプロセスとの突き合わせを足す | 採る（DJ-8） |
| 12 | should | 信頼の hash は定義のもので、スクリプトの本文は含まない。bypass の意味 | 採る（DJ-12） |
| 13 | should | AGENTS.md の説明は保証ではない。説明用の handler は既存の hook と分ける | 採る（DJ-4） |
| 14 | should | `$スキル名` の本文は会話に残る。有無の確かめと `CODEX_HOME` | 採る（DJ-11） |
| 15 | should | PR-1 だけの状態の使い方を決める | 採る（DJ-14） |
| 16 | must | `~/.codex` に残るものは2つでない。`CODEX_HOME` で隔離する。プロジェクト層の確かめは user 層の symlink の確かめにならない | 採る。実機の確かめを `CODEX_HOME` の隔離に書き直した |
| 17 | should | `oe-selfcheck`・`oe-kick`・`model` の object・`server_pid` | 採る。範囲の外を明記し、書き手の仕様に足した（DJ-6・対応表） |
| 18 | should | outbox と broker（案A）・MCP の能力（案B） | 採る。ゼロベースの代替に記録し、#549 の材料にする |

- 確かめた範囲: 指摘1〜8・16 の根拠の行は書き手が 0.167.1 のソースと engine のファイルを開いた。指摘11 の `core/src/shell.rs`・`exec-server` と、指摘16 の `message-history`・`shell_snapshot` は開いていない（前提の節で `[unverified-summary]`）。

## 実装の分け方（PR の単位）

DJ-14 のとおり2つ（Q4）。PR-1 が engine と配るスキル、PR-2 が Codex の配布物。plan・episode・knowledge は PR-1 に載せる。PR-2 は PR-1 の着地のあとに ready にする。

## 達成を見る数の測り方

- M-1: 統括のペインから `oe delegate --agent codex --brief <書面>` で起こした Codex の子が、書面を読んで `oe send --to-parent` で報告を返すまでに、人が文を写した回数が 0、承認の画面で止まった回数が 0（I6 で1回回して数える。`git push` と `gh` で止まった回数は別に数えて episode に書く）。
- M-2: 同じ往復で、`oe-events.jsonl` に `prompt_received`（nonce と pane が送信と一致）が 1 件以上、heartbeat の sidecar が子の session_id で 1 件以上ある（`oe confirm` と `oe tree` で見る）。C1・C3 が通らなかったときは、この数は「無しで動く形」の確認（`oe-confirm` が「確認できていない」を出す・床の sidecar で `oe send #<label>` が子に届く）に置き換え、置き換えたことを episode に書く。
- M-3: Claude の子への委譲が変わらないこと。engine の既存の検査が bash 5 と bash 3.2 で全件 exit 0、`tests/test_oe_delegate.sh` の子のコマンドの文字列の検査が変更前と同じ値で通る（T-1）。
- M-4: 7か所それぞれに、Codex での代えか「無しで動く形」が plan と実装に書かれている。対応表の7行に加えて、表の下の「範囲の外」の5つが `bin/README.md` に同じ言葉で書かれている（行数の一致だけでは見落としを拾えないので、名前で突き合わせる）。

## 実機の確かめ（I1・ゲート3 のあとの最初のステップ）

`~/.codex` は owner の手元の設定なので触らない。確かめは **`CODEX_HOME` を使い捨てのディレクトリ（`<tmp>/codex-home`）に向けて**行い、Codex が書くもの（設定・hook の信頼・規則・会話の記録・入力の履歴・SQLite・shell の snapshot・ログ）をすべてそこに閉じ込める。workspace はリポジトリの外の使い捨ての git リポジトリ（`<tmp>/oe-codex-probe`）にする。

- 足すもの: `<tmp>/codex-home/config.toml`（手元の `~/.codex/config.toml` から `model` と `[features] hooks = true` だけを写す）・`<tmp>/codex-home/auth.json`（手元の `~/.codex/auth.json` の写し・権限 600。owner の資格情報なので、写してよいかをゲート3 で聞き、owner は「写して終わったら消す」を選んだ（2026-11-13）。写した事実と消した事実は episode に書く）・`<tmp>/codex-home/hooks.json`（通常のファイル。標準入力と環境を一時ファイルへ書くだけの hook `<tmp>/probe-hook.sh` を `UserPromptSubmit` と `PostModelRequest` に配線）・`<tmp>/codex-home/rules/oe-child.rules`（通常のファイルと、別名の symlink の両方を置いて、読まれる側を確かめる）。
- 消し方: `<tmp>` をまるごと消す。`~/.codex` には何も書かないので、消すものが無いことを `find ~/.codex -newer <tmp>/started -type f` で確かめる（会話の記録は `CODEX_HOME` の下に書かれるので `~/.codex/sessions` には増えない）。`CODEX_HOME` の外を読む経路（`$HOME/.agents/skills` など）は読むだけで書かない。
- hook の信頼: 1段階目は `--dangerously-bypass-hook-trust` を付けて起こし、発火と標準入力の形を見る。2段階目は flag を外し、`/hooks` で登録して `<tmp>/codex-home/config.toml` の `[hooks.state]` に鍵が書かれることと、鍵の形（パス・イベント名・番号）を見る。user 層の hooks.json（`CODEX_HOME` 直下）で確かめるので、symlink の配布の確かめにもなる（hooks.json は hub では symlink で配っているので、symlink でも読まれるかを同じ段で見る）。

| # | 確かめること | 分かれ方 |
|---|---|---|
| C1 | `UserPromptSubmit` の hook が対話の画面で発火し、標準入力に `prompt` が入る | 発火しなければ DJ-7 は「無しで動く形」になり、`codex.hooks.json` には `UserPromptSubmit` を足さない |
| C2 | `--no-daemon` で起こしたとき、hook の環境の `TMUX_PANE` が自分のペインの値になる | ずれるなら受領の印は pane 無しで書かれ、`oe-undelivered` が突き合わせられない。統括は子の返事で確かめる形に落とす |
| C3 | `PostModelRequest` の hook が対話で発火し、標準入力に `token_usage` が入る。`transcript_path` の記録に `model_context_window` がある。hook の実行時間（`time`）を測る | 発火しなければ DJ-6 は床だけになる。`UserPromptSubmit` だけ発火するなら、そちらで `context_pct` 無しの sidecar を書く |
| C4 | `--approve-for-me` と `rules/oe-child.rules`（通常のファイル）で、子が `oe send <統括のペイン>` と `git commit` を承認の画面で止まらずに打てる。symlink の規則は読まれないことも見る。規則の無い `curl` と `git push` が auto_review に回ることも見る | `allow` でも sandbox の外に出なければ DJ-3 の推奨を `-a never -s danger-full-access` に差し替え、Q1 を聞き直す |
| C5 | `codex --no-daemon resume <id>` で開き直した会話で、子のコマンドに同じ `CODEX_THREAD_ID` が届き、記録のファイルに追記される | 追記されなければ DJ-9 の案内に「記録は新しいファイルになる」と添える |
| C6 | `tmux split-window -c <ws> "PARENT_TMUX_PANE=… codex --no-daemon …"` で起こしたペインの前面のプロセスのコマンド名が `codex` になり、子のコマンドから `$PPID` をたどった `codex` の pid が前面の pid と一致する | `codex` にならなければ Codex の分岐だけに `exec` を書く。pid が一致しなければ DJ-8 を「前面のプロセスを自分とする」に替える |
| C7 | workspace の外にある brief のパスを、`--add-dir` の有無それぞれで読めるか・`.oe/` に書けるか | `--add-dir` 無しで読めないなら、brief を子の workspace の中へ写す形に変える |
| C8 | `oe send` の finalize が Codex の画面で働く（行頭 `›` を入力欄と判定し、Enter が吸われたときに打ち直す・吸われなかったときに二重に打たない） | 働かなければ、Codex の宛先では送る側が finalize を切る（DJ-10） |
| C9 | `-c developer_instructions="…"` で起こした子に、印の付いた1行を送り、(1) 子が印をコマンドに写さない、(2) `/compact` で圧縮したあとも同じ、(3) `codex --no-daemon -c developer_instructions="…" resume <id>` で開き直したあとも同じ、(4) `-c` 無しで resume したときはどうなるか、を見る。記録（rollout）に developer のメッセージが入る位置も見る | (2) で消えるなら `SessionStart` の hook（matcher `compact`）で入れ直す形に落とす。(3) で効かないなら resume の案内の `-c` を外し、`SessionStart`（matcher `resume`）に落とす。hook も発火しなければ、子へ送る最初の1行に決まりの文を添える（1回だけ） |

確かめた結果は、1項目ずつ（版・起動の形・経路）を episode に書き、plan の対応する DJ に結果の行を足す（記録の級）。

結果（2026-11-13・詳細は episode の I1）: C1 発火した。C2 自分のペインの値。C3 発火し `token_usage` が入る。C4 `oe send`・`git commit` は止まらない（symlink の規則は版の変更のあとの道具の障害で未確認）。C5 同じ記録に追記される。C6 `exec` は要らない（`ps` は sandbox の中で失敗）。C7 読める・書けない（`--add-dir` 付きは未確認）。C8 送信は通るが finalize は Codex の入力欄を見ていない。C9 写さない・圧縮と resume のあとも残る。hook の信頼は `/hooks` の `t` で3件登録された。分かれ方のどれにも入らず、設計は変えない。未確認の4点（symlink の規則・`CODEX_THREAD_ID` の一致・pid の一致・`--add-dir`）は CHECK-2 の実機で見る。設計が分かれ方のとおりに変わるときは補正として申告し、分かれ方に無い変わり方は変更として照会する。

## テスト

新しい検査は `tests/test_agent.sh`（`lib/agent.sh`）に置き、既存の検査（`test_oe_delegate.sh`・`test_lease.sh`・`test_lease_writers.sh`・`test_delegate_send.sh`・`test_oe_recover.sh`・`test_prompt_receipt.sh`）に節を足す。bash 5（`bash tests/<file>`）と bash 3.2（`/bin/bash tests/<file>`）の両方で回す。実 tmux と実 Codex は起動せず、PATH の先頭の mock で記録する（既存の流儀）。

- T-1（Claude の不変）: `--agent` 無しの `oe delegate` が組む子のコマンドの文字列が、変更前と同じ `PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'` である。既存の検査の値を変えない。
- T-2: `--agent codex` で `codex --no-daemon --approve-for-me -c developer_instructions="…"` が入り（本文は `lib/agent.sh` のものと一致し、改行と二重引用符を含まない）、`--agent-arg` に `-a`・`-s`・bypass・`--yolo` があれば既定の `--approve-for-me` が外れる。`$CODEX_HOME/config.toml` に `developer_instructions` があるときは stderr に1行出る。`--agent` に知らない名前を渡すと exit 2。`--claude-arg` が `--agent-arg` の alias として動く。
- T-3: 承認のダイジェストが `agent` を含み、`--agent claude` と `--agent codex` で値が違う。`--reason` の違いでは変わらない（既存）。elevated の判定が `--yolo`・`-s danger-full-access` を elevated と読み、`-a never` だけは読まない。
- T-4: lease の検査が `codex` を許し、`bash`・`codexd`（部分一致）を rc 6 で断る（`oe_lease_bind`・`oe_lease_claim`・`oe_lease_advance`・`adopt`）。`validate-lease` が `comm: codex` の記録を通す。
- T-5: 宛先が Codex のとき `_oe_send_inputline` が `›`・`»` の行を入力欄と判定し、`_oe_send_has_content` が空の `›` を空と、`Ask Codex to do anything` を空と扱う。宛先が Claude のときは `›` の行を拾わない。`❯` の既存の検査は変えない。
- T-6: `oe_agent_self` が `CLAUDE_PID`・`CLAUDE_CODE_SESSION_ID` のときと `CODEX_THREAD_ID` のときでそれぞれ (agent, pid, session_id) を返し、どちらも無いときは今と同じ文言で止まる。pid は mock の `ps` でたどり、前面のプロセスと一致しないときは止まる。`oe_lease_whoami` が `CODEX_THREAD_ID` の session_id で lease を引く。
- T-7: `oe-recover hint` が lease の `agent` で案内の文を出し分け、`agent` の無い記録では `claude --resume` を出す。
- T-8: 床の sidecar。`oe-delegate` が binding のあとに `<lease_id>.json` を書き、`oe_hb_pane_for` がそれで候補を返す。`oe send` が `OE_LEASE_ID` と `TMUX_PANE` のあるときに同じ sidecar を書き直し、無いときは書かない。
- T-9: `oe-heartbeat-hook.sh` が、`PostModelRequest` の標準入力（`session_id`・`model`・`token_usage`・`transcript_path`）と環境の `TMUX_PANE`・`TMUX`・`OE_LEASE_ID` から、Claude の書き手と同じ鍵の sidecar を書く。`model` が object になる。記録に `model_context_window` が無いときは `context_pct` を 0 にする。標準出力に何も出さない。`UserPromptSubmit` の標準入力では `context_pct` を前の値のまま残す。
- T-10: `oe-prompt-receipt.sh` に Codex の形の標準入力（`session_id`・`turn_id` 付き）を渡しても同じ印が出る。
- T-11: `scripts/check-codex-guardrails.sh` が通る。`shellcheck` が新しいスクリプトと変えたスクリプトで通る。`sync-codex.sh` が `oe-child.rules` を通常のファイルとして写し、内容が同じなら書き直さない（一時ディレクトリで）。

## 受入

- A-1: `--agent` を指定しない `oe delegate` の子のコマンドの文字列と、承認パッケージの表示の項目が、変更前と同じである（T-1。`agent_args` の鍵の改名はダイジェストの中だけ）。
- A-2: 7か所それぞれに Codex での代えか「無しで動く形」が実装と README にあり、「範囲の外」の5つも README に名前で書かれている（M-4）。
- A-3: 実機の確かめ C1〜C8 の結果が、版・起動の形・経路を1項目ずつ episode に書かれ、`~/.codex` に何も残っていないことを確かめた記録がある。
- A-4: 統括から Codex の子へ書面を渡し、報告を受けるまでを、人が文を写さず、`oe send` と `git commit` で承認の画面に止まらずに1回回せた（M-1）。
- A-5: engine の既存の検査と新しい検査が bash 5 と bash 3.2 で全件 exit 0（M-3）。
- A-6: hook の信頼を登録する手順が `canonical/hooks/README.md` に、定義の変更とスクリプトの変更を分けて書かれ、実機で1回たどって受領の印が出た（DJ-12 の2段階目）。
- A-7: PR-1 だけが着地した状態で `--agent codex` を打ったときの制限が `bin/README.md` に書かれ、規則が無いときの1行が出る（DJ-14）。

## ステップ

### P1: worktree・参照の読み・一次情報での確かめ直し・設計判断の洗い出し（完了）

### P2: 設計SO（弱・Codex の1レーン）を plan の案に当て、採否を episode に書く（完了・18件をすべて採った）

### P3: plan を draft PR に載せ、ゲート3 の問いを `.oe/question-562-1.json` に書いて `build.py check` を通し、`.oe/report-562-p3.md` を書いて報告の宛先へ1行送り、止まる

### GATE 3: owner の plan 承認（承認の記録 `.oe/decision-562-gate3.md` が届いてから I に進む）

### I1: 実機の確かめ C1〜C9（`CODEX_HOME` を使い捨てに向ける・結果を episode と plan に書く・`~/.codex` に何も残っていないことを確かめる）（完了・2026-11-13・未確認4点は CHECK-2 へ）

### I2: `lib/agent.sh` と `oe delegate --agent`（DJ-1・DJ-2・DJ-3 の既定の引数と elevated の表）・registry と lease の `agent`・ダイジェスト・床の sidecar（DJ-6 の (1)）・T-1〜T-3・T-8（完了・`557ab05`）

### I3: lease の検査の集合と schema（DJ-5）・入力欄の判定と送る側の finalize（DJ-10）・`oe send` の床の更新（DJ-6 の (2)）・T-4・T-5（完了・`df995c8`）

### I4: `oe_agent_self`（DJ-8）と `oe-lease`/`oe_lease_whoami`/`oe-recover` の読み替え・復帰の案内（DJ-9）・T-6・T-7（完了・`acf4b2d`・`oe-handoff` は補正 H4 で外した）

### I5: `delegate-task`（`--agent`）と `doc-flow-guardrail`（skill 解決規約・受領の印の1行）の文・`bin/README.md`（PR-1 だけの状態の制限と「範囲の外」の5つ）・engine の README（完了・`1bbc38d`）

### CHECK-1: T-1〜T-8 と既存の検査を bash 5 と bash 3.2 で回し、shellcheck を通す（PR-1）（完了・2026-11-13・`tests/test_*.sh` 54本 × bash 5.2.37 と 3.2.57 = 108 回がすべて exit 0。shellcheck は変えたスクリプトで master と同じ info のみ）

### I6: Codex の配布物（PR-2）: `oe-heartbeat-hook.sh`（DJ-6）・`codex.hooks.json` の配線（DJ-7）・`canonical/codex/rules/oe-child.rules` と `sync-codex.sh`（通常のファイルとして写す）・`AGENTS.md`（DJ-13）・hooks の README（DJ-12）・T-9〜T-11（完了・ブランチ `feature/#562_codex_dist`・PR-2 の最初の commit（題「Codex の子のための hook の配線・拍動の hook・実行ポリシーの規則を配る」）・PR #645 draft・PR #644 の上に重ねる）

### CHECK-2: sync を一時ディレクトリで確かめ（worktree からの sync は `~/.claude` のリンクを張り替えるので避ける・#605 の I4 と同じ）、owner が `/hooks` で登録してから、統括から Codex の子へ1回回して M-1・M-2 を数える（完了・2026-11-13。1回目は止まった（書面の commit の文・つないだ `oe` が sandbox の中で走った）→ H10。2回目は PR-1 `edc9236`・PR-2 の H10 の commit（題「#562 の規則を oe の1行にし…（H9・H10）」）で通った: M-1 は写し 0・承認の画面 0・push と gh 0、M-2 は受領 1・hook の sidecar 1・床 1、`oe tree` に model と context%。子は git を sandbox の中で打って commit `0094ed0` を作り、`oe send --to-parent` を単独で打った。マージ前なので確かめは使い捨ての `CODEX_HOME` と PR の worktree の `oe` で行い、子の `oe` は master の版だった）

### GATE 4: 実装SO（弱・1レーン）と Copilot の1ラウンド（PR ごと）（PR-1 の SO は完了・H5。Codex のレーンは道具の障害で判定なし・Cursor のレーンで `survived`。PR-1 の Copilot の1ラウンドは完了・H6・3件に返信済み。PR-2 の SO は完了・H7・Claude のレーンで `refuted` → must 2 を直した。PR-2 の Copilot は PR-1 の着地のあと ready にしてから）

### I7: episode を closure し、knowledge の観測を5件書き戻し、報告して止まる（マージ・worktree の掃除・issue の close はしない）

## GATE 3 の問いと答え（2026-11-13・判断ボード Q106〜Q112）

| 問い | 答え | 反映 |
|---|---|---|
| Q1（DJ-3・Q106）: 子の Codex を起こすときの承認のモードの既定 | `--approve-for-me` と、hub が配る `allow` の規則2行（`oe`・`git commit`）。推奨どおり。規則は owner が自分で開く Codex にも効く | DJ-3 |
| Q2（DJ-4・Q107 → Q112）: 受領の印 `[oe:…]` の扱い | 決まりは子を起こす1行の `-c developer_instructions` と書面の固定節で伝え、`canonical/codex/AGENTS.md` には engine の約束ごとを書かない（DJ-13 は「書面に従う」の1行だけ）。圧縮と resume のあとに効くかは C9 で確かめる | DJ-4・DJ-9・DJ-13・C9 |
| Q3（DJ-5・Q108）: lease のコマンド名の検査の広げ方 | 許す名前の集合（basename の完全一致）。推奨どおり | DJ-5 |
| Q4（DJ-14・Q109）: PR の数 | 2つ（engine と配るスキル／Codex の配布物）。推奨どおり | DJ-14 |
| Q110: 実機の確かめで使い捨ての `CODEX_HOME` に `auth.json` を写してよいか | 写して、終わったら消す。推奨どおり | 実機の確かめ |
| Q5（Q111）: この plan で実装に進むか | 進む（上の答えを入れた plan について） | 承認の記録 `.oe/decision-562-gate3.md` は統括が書く |

## ゲート3 のあとの変更

### H1（補正・2026-11-13・I1）: Codex の1行に `-c check_for_update_on_startup=false` を足し、フォルダの信頼の確認に Enter を1回送る

- 出どころ: I1 で更新の確認の画面に送った1行の Enter が「Update now」を選び、手元の codex が 0.167.2 に上がった（統括の指示で DJ-2 に足す）。
- 変更前 `8a6f7e7` → 変更後はこの節を含む commit。
- 8項目: (1) step の見出しは消えていない。(2) 要件は弱めていない（起動の引数が2つ増える）。(3) ゲートは変わらない。(4) 終端は同じ。(5) 受入は減っていない（A-1 の Claude の1行は変えない）。(6) owner の決定は変わらない。(7) 範囲は変わらない。(8) 新しい設計判断は足していない（起動の引数の既定の中身）。

### H2（補正・2026-11-13・I1）: `$PPID` をたどる処理は `oe` の verb の中でだけ動くと DJ-8 に書き、README に書く義務を足した

- 出どころ: C6 で sandbox の中の `ps` が `Operation not permitted` だった。
- 8項目: DJ-8 の結論は変わらず、動く条件を1行足しただけ。README の1行は I5 の既存の義務の中。

### H3（補正・2026-11-13・I1）: T-2 に `codex debug prompt-input` での確かめを足した

- 出どころ: C9 で、モデルを呼ばずに developer のメッセージの有無を見られる口が見つかった。
- 8項目: 承認済みの結果を確かめる検査を強めるもの（確かめる対象は増えない）。

### H4（補正・2026-11-13・I4）: DJ-9 の対象から `oe-handoff` を外し、`oe-recover hint` だけにした

- 出どころ: `oe-handoff` は統括の verb で、Codex を統括にするのは「この plan の範囲」の「やらない」に入っている。DJ-9 が両方を挙げていたのは範囲と食い違っていた。
- 8項目: (1) step は消えていない。(2) 要件は、範囲の外と宣言済みのものを文から外しただけ（codex の統括の案内は、どの受入も求めていない）。(3)〜(5) 変わらない。(6) owner の決定に関わらない。(7) 範囲内の項目を範囲外へ移してはいない（もともと範囲外）。(8) 追加なし。迷ったら重い側、の決まりに従い、統括に判定を任せる。

### H5（補正・2026-11-13・GATE 4・PR-1）: 実装SO の指摘8件（should）を直した

- 出どころ: 実装SO。Codex のレーンは `tool_status=degraded`（`timed out negotiating with the code-mode host`・0.167.2 の道具の障害）で判定なしに終わり、Cursor のレーン（composer-2.5・指定）で回し直した。判定は `survived`（must 0・should 8）。8件すべてを採った（`e19bdf2`）。
- 中身: (1) 承認パッケージのエージェントの行を claude 以外のときだけ出す（A-1 の「表示の項目が変更前と同じ」を文字どおりにする）。(2) `-c sandbox_mode=`・`approval_policy=`・`approvals_reviewer=` の指定も承認のモードの上書きと見る（既定の `--approve-for-me` と衝突して起動が失敗する経路を塞ぐ）。(3) `oe_agent_self` がたどった codex の pid を自分のペインの前面のプロセスと突き合わせる（DJ-8 に書いてあったが実装が抜けていた）。(4) lease の schema の top-level `agent`（最初の編集が通っていなかった）。(5) `oe_lease_gc` が開いた lease の床を残す。(6) `oe-recover` の文言。(7) developer の指示の本文にバックスラッシュと制御文字が無いことを検査で固定。(8) T-6 の検査を前面の突き合わせまで広げた。
- 8項目: step・要件・ゲート・終端・受入・owner の決定・範囲は変わらない。(2) と (5) は承認済みの結果を確かめる検査と細部の訂正で、新しい対応範囲ではない。

### H6（補正・2026-11-13・GATE 4・PR-1 の Copilot の1ラウンド）: 指摘3件を直した（`3fc8768`）

- 出どころ: Copilot のレビュー（Changes recommended・3件）。3件とも採った。
- 中身: (1) 権限のモードの判定が `-c` / `--config` の `sandbox_mode`・`approval_policy` も読み、`danger-full-access` は指定の形によらず elevated（承認ダイジェスト必須）にする。(2) 拍動の床に `floor: true` を付け、`oe-tree`・`oe-threads` の表示と `oe_hb_session_for_pane` の逆引きからは床を外す（同じペインの拍動が2件に数えられて model / context% が隠れる・床が会話の ID の代わりに返る、を防ぐ）。lease からペインを引く `oe_hb_pane_for` は床を使う。(3) lease の binding・claim・advance は記録に残す `comm` を basename に正規化してから検査する（schema と `validate-lease` の完全一致に合わせる）。
- 8項目: step・要件・ゲート・終端・受入・owner の決定・範囲は変わらない。(1) は elevated の判定の抜けを塞ぐ細部の訂正、(2) は DJ-6 の床の設計を読む側に通す訂正、(3) は DJ-5 の検査の整合。新しい対応範囲ではない。

### H7（補正・2026-11-13・GATE 4・PR-2）: 実装SO の指摘（must 2・should 9）を直した（PR-2 の GATE 4 の commit（題「実装SO の指摘を直す（#562 GATE 4・PR-2）」））

- 出どころ: PR-2 の実装SO。Codex のレーンは道具の障害、Cursor のレーンは時間切れ（1350秒・空）で、Claude のレーン（`so-compare --claude-only --claude-model opus --claude-effort high`・`claude-opus-5-5`・543秒）で回した。書き手と同じ会社のモデルなので、弱い SO として扱う。判定は `refuted`（must 2）。
- 中身: (must 1) context% の分子が cached のトークンを二重に数えていた（`input_tokens` は cached を含む）。`total_tokens`（Codex の `tokens_in_context_window`・`protocol/src/protocol.rs:2679-2681`）を使い、無ければ `input + output`。DJ-6 の式も直す。(must 2) 床と hook の sidecar が同じペインに並び `oe-tree`・`oe-threads` が ambiguous で model / context% を隠す。PR-1 の H6（`floor: true`・読む側で床を外す）で直した。(should) 取り消した要求（`token_usage: null`）で 0 に戻さず前の値を残す。記録を1行ずつ読み、書きかけの最終行で窓を取り損ねない。`PostModelRequest` の配線を `async: true`・`timeout: 10` にして道具の実行を待たせない。hub に無くなった `oe-*.rules` を写し先から消す。README の hash の元に `timeout`・`async` なども入ると書く。検査の関数の切り出しを `sync_rules` だけにし、`set -euo pipefail` の下でも通ることを見る。
- owner に聞くもの（補正ではなく問い・`.oe/question-562-2.json`）: 規則 `oe` が engine のすべての verb を sandbox の外に出すこと（絞るか）、`git commit` の allow が workspace の中の commit の hook も外で走らせること（外すか）。どちらも推奨は「決めたまま」。
- 8項目: step・要件・ゲート・終端・受入・owner の決定・範囲は変わらない。context% の式は DJ-6 の細部の訂正で、結果（sidecar の形）は同じ。`async`・`timeout` は hook の定義の細部で、登録の手順は変わらない。

### H8（変更・再承認済み・2026-11-13・Q113・承認の記録の entry 3）: フォルダの信頼の確認に、engine が条件つきで Enter を1回送る

- 出どころ: H1 のうち「`Trust this folder?` に Enter を1回送る」を統括が変更と判定し、owner が判断ボード Q113 で決めた。
- owner の決定: workspace のもとのリポジトリ（main の作業ツリー）を owner が Codex で信頼済みのときだけ、engine が Enter を1回送って進める。信頼済みかは `$CODEX_HOME/config.toml` を読んで確かめ、書き換えない。信頼されていないときと、画面の文言を読めないときは、Enter も最初の1行も送らずに止まって案内を出す。
- 実装: `lib/agent.sh` の `oe_agent_codex_main_worktree`（`git rev-parse --git-common-dir` の親）と `oe_agent_codex_trusted`（`[projects."<path>"]` の `trust_level = "trusted"` を awk で読む）。`bin/oe-delegate` は Codex の子を起こして生存を確かめたあと、画面を `capture-pane` で読み、確認の文言があれば信頼済みのときだけ Enter を送って `OE_DELEGATE_TRUST_WAIT_SEC`（既定 2 秒）待ち、確認が消えたら最初の1行を送る。消えない・信頼されていない・config.toml を読めない・画面を読めない、のどれかなら exit 4 で止まる（ペインは残す。案内は stderr）。claude の子では画面を読まない（A-1）。
- 検査: `tests/test_oe_delegate.sh` [A11]（信頼済みで Enter → 消えれば1行・消えなければ止まる／信頼されていない／config.toml が読めない／画面が読めない／確認が無い／claude は読まない）。
- 8項目: step・ゲート・終端・受入は変わらない。要件は owner の決定で1つ増えた（変更・再承認済み）。範囲内。

### H9（補正・2026-11-13・CHECK-2 の1回目）: hooks の README の信頼の手順に、起動の画面の「2. Trust all and continue」を足す

- 出どころ: CHECK-2 の1回目で、0.167.2 の起動の直後の画面が「1. Review hooks / 2. Trust all and continue / 3. Continue without trusting」だった（統括の観測）。README は「`/hooks` で `t`」とだけ書いていた。
- 直し: PR-2 の `canonical/hooks/README.md` の Codex の信頼の節に、起動の画面の 2 で済むことを足す。実機の文言に合わせる訂正で、新しい義務は無い。
- 8項目: 変わらない。

### H10（変更・再承認済み・2026-11-13・Q118・承認の記録の entry 4）: 権限は起こす1行で渡し、規則は `oe` の1行だけにする（DJ-3 を置き換える）

- 出どころ: CHECK-2 の1回目で、子が `mkdir` とつないで打った `oe send` が sandbox の中で走って届かなかった。Codex は、スクリプトを分けた部分のすべてが allow の規則に当たるときだけ sandbox の外で走らせる（`core/src/exec_policy.rs:466-480`）。`git add` は `.git` が sandbox の中で読み取り専用なので必ず失敗した。統括が Codex の権限の仕組みを Codex に調べさせ、子が実機で5点を確かめた（打ったコマンドと出力の要点は episode の「確かめの5点と H10（Q118・2026-11-13）」の節）。owner は Q115〜Q117 を取り下げた Q118 で推奨どおりと答えた。
- owner の決定:
  - git の書き込みと状態の置き場と tmux のソケットは、engine が子を起こす1行で渡す（そのセッションにだけ効く・owner の設定に書かない）。
  - allow の規則は `oe` の1行だけにする。`git commit` の規則はやめ、`git add` も足さない。`git push` と `gh` は開かない（子は commit まで）。
  - `oe` がほかのコマンドとつないで打たれたときに単独で打ち直すと返す検知（`CODEX_SANDBOX`）を入れ、決まりの文に1文足す。`--to-parent` は sandbox の中で `ps` が動かず、権限を足しても届かないため（確かめの 5）。
  - フォルダの信頼は `-c` で渡さない（owner が本体のリポジトリを信頼する）。
- 実装（PR-1）:
  - `lib/agent.sh` に `oe_agent_codex_sandbox_args <workspace>` を足す。起こす前に、本体の `.git`（`git rev-parse --git-common-dir`）・worktree の gitdir（`--git-dir`。本体と同じなら1つ）・状態の置き場（`~/.claude/state`）を実体のパス（`pwd -P`）で解決して `--add-dir` で渡す。tmux のソケットは `tmux display-message -p '#{socket_path}'` を実体のパスに直し、`-c sandbox_workspace_write.network_access=true`・`-c features.network_proxy.enabled=true`・`-c 'features.network_proxy.unix_sockets={"<ソケット>"="allow"}'` の3つで渡す（sandbox の中のプロセスの直接の通信は閉じたまま・確かめの 3。tmux のソケットの先は sandbox の外なので、子は外への通信を親と同じだけ使える。H13 を見る）。git でない workspace では git の分を、tmux の外では tmux の分を足さない。
  - 書ける場所の渡し方は `-c sandbox_workspace_write.writable_roots` でなく `--add-dir` にする。`writable_roots` は owner の設定が名前付きの権限のプロファイルを選んでいると足されないが、`--add-dir` は必ず足される（`core/src/config/mod.rs:3762-3788`）。実機の確かめは `writable_roots` で行い（確かめの 1・2）、ソースでは両方が同じ並びに入るので、`--add-dir` での通しは CHECK-2 の2回目で見る。
  - `bin/oe` の入口で、`CODEX_SANDBOX` が空でなければ何もせずに exit 2 で止まり、「`oe` で始まる1つのコマンドとして、ほかのコマンドとつながずに打ち直す」と stderr に出す。
  - 決まりの文（`OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS`）に「`oe` は、ほかのコマンドとつながず、それだけで1つのコマンドとして打つ。」を足す。
  - 検査: `test_agent.sh` に sandbox の引数（普通のリポジトリ・worktree・git でない・tmux の外）、`oe` の入口の検知の検査を足す。`test_oe_delegate.sh` は Codex の1行に `--add-dir` と `-c` が並ぶことを見る。
- 実装（PR-2）: `canonical/codex/rules/oe-child.rules` から `git commit` の行を外し、`oe` の1行だけにする。hooks の README と `sync-codex.sh` の説明と `test_codex_dist.sh` を合わせる。
- H8 の Enter を送る分岐は縮めない。owner が本体のリポジトリを信頼していれば確認は出ない（確かめの 4 の T3）ので、この分岐はほとんど通らないが、縮めると owner の Q113 の答えを変えることになる（変更）。迷ったら残す、の指示に従う。
- 置き換える箇所: DJ-3 の推奨の規則2行と「`allow` は sandbox の外で走るので、tmux のソケットにつなげない問題も消える」の理由、7か所の対応表の「起動のコマンド」の行、確定版の項目との対応の「`oe send` と git commit を承認なしに打てる規則」の行、GATE 3 の答えの Q1（Q106）の行。承認済みの節は書き換えず、この H10 が上書きする。
- 8項目: step 集合・ゲート・終端は変わらない。要件は変わる（規則2行 → 1行・起動の1行に権限を足す・検知を足す）。受入は「子が承認の画面で止まらずに `oe send` と `git commit` を打てる」の確かめ方が変わる（規則でなく起動の権限で）。設計判断 DJ-3 の結論が変わる。owner の再承認済み（entry 4）。

### H11（補正・2026-11-13・GATE 4 を H10 の差分に当て直した）: 実装SO の指摘（must 2・should 1）を直した

- 出どころ: H10 は PR-1・PR-2 の実装SO（H5・H7）のあとに入ったので、GATE 4 の決まり（実装SO・弱・1レーン）を H10 の2つの commit（`edc9236`・PR-2 の規則の commit）に当て直した。承認済みのゲートを承認済みの変更に当てるだけで、新しい義務は足していない。Codex のレーン（`gpt-6.1-sol`・`tool_status=not_observed`・251秒）の判定は `refuted`。
- must 1: ソケットのパスを TOML の文字列に逃がさずに埋めていた（`"`・`\` を含むパスで設定が壊れる）。`\` と `"` を逃がし、制御文字を含むパスでは tmux の分を出さない。
- must 2: 利用者が `--agent-arg -c features.network_proxy.enabled=false` を渡すと、engine の `network_access=true` だけが残り外への通信が全部開く。利用者の引数がネットワークの設定に触れていれば、tmux の分の3つを出さない（`oe_agent_codex_user_sets_network`）。
- should: 検査が文字列の比較だけだった。TOML として解析して元のパスに戻ること・利用者の引数があるときに出さないこと・委譲の終了コードを見る検査を足した（`test_agent.sh`・`test_oe_delegate.sh` の [A12]）。
- 採らなかった観察: 入口の検知は環境変数だけで判定するので、変数を引き継いだ sandbox の外では止めすぎ、変数を消した sandbox の中では見逃す。Codex が入れる変数で見分けるのは H10 の決定どおりで、偽陽性は「単独で打ち直す」で抜けられるので変えない。
- Copilot: PR-1 への再依頼は owner の明示の指示があるときだけ行う運用なので行わない。PR-2 の Copilot の1ラウンドは、PR-1 の着地のあと PR-2 を ready にしてから行う（変わらず）。
- 8項目: step・ゲート・終端・受入・設計判断の結論・範囲は変わらない。追加の義務は無い（must 2 の扱いは H10 の「sandbox の中のプロセスの直接の通信は閉じたまま」を守るための細部）。

### H12（補正・2026-11-14・マージ前のレビュー）: Codex の引数の判定がつなげた書き方を拾わない誤りと、信頼の確認の読み取りの失敗を素通りする誤りを直した

- 出どころ: owner が Codex に PR #644・#645 をレビューさせ、統括がコードを読んで誤りと確かめた2件。
- 1件目: `oe_agent_codex_user_sets_network` が `-cfeatures.network_proxy.enabled=false`（`-c` と値をつなげた形）や `-c=…` を拾わず、engine の `network_access=true` だけが残って外への通信が全部開いた（H11 の直しの抜け）。Codex が受け付ける値つきの書き方（`-cKEY=V`・`-c=KEY=V`・`--config=KEY=V`・`-sV`・`-s=V`・`--sandbox=V`・`-aV`・`-a=V`・`--ask-for-approval=V`）を、選択肢と値の2語に分ける `_oe_agent_codex_norm` を足し、ネットワークの判定・承認のモードの判定（`oe_agent_has_mode_override`）・権限のモードの読み方（`oe_agent_permission_mode`）の3つがどれもそれを通るようにした。鍵の前後の空白は Codex と同じく落として読む（`_oe_agent_kv_key`）。同じ抜けで `-sdanger-full-access` が elevated と読まれていなかったのも、同じ箇所なので一緒に直した。
- 2件目: `oe-delegate` が信頼の確認に Enter を送ったあと、2回目の `capture-pane` が失敗すると止まらずに最初の1行を送っていた。Enter の `send-keys` の失敗も見ていなかった。Q113 の「読めないときは止まる」に合わせ、Enter の失敗と2回目の読み取りの失敗をそれぞれ exit 4 にした。
- 検査: `test_agent.sh` につなげた書き方と鍵の空白の検査、`test_oe_delegate.sh` の [A13]（Enter の失敗・2回目の読み取りの失敗）。
- 範囲: レビューのほかの指摘（tmux のソケット・`.git`・状態の置き場・規則 `oe` の広さ）は設計の話で、owner に判断ボードの Q119 で聞いている。ここでは触らない。
- 8項目: step・要件・ゲート・終端・受入・設計判断の結論・範囲は変わらない。H10・H11・Q113 で決めた振る舞いを、決めたとおりに働かせる直しである。

### H13（変更・再承認済み・2026-11-14・Q119・承認の記録の entry 8）: Codex の sandbox を安全の境界にしないことを文書に書いてマージし、作り直しは別の issue にする

- 出どころ: owner が Codex に PR #644・#645 をレビューさせ、tmux のソケット・本体の `.git`・`~/.claude/state` に子が届くことで、sandbox の外で操作できると指された（マージ前に直すべきとされた4件）。owner は判断ボードの Q119 で「誤り2件を直し（H12）、境界でないことを文書に書いてマージし、作り直しは別の issue にする」と決めた。
- 書く中身: engine の安全の考え方（子は親と同じだけ信頼する・守りは hook と人の承認のゲートと Claude の子では auto mode の判定器）。Codex の sandbox は事故を防ぐもので境界ではないこと。Codex の子は3つに届き、Claude の子も同じ3つに届いていて、違いは判定器の有無であること。運用の注意（外から来た文を読ませる作業を Codex の子に任せない）。親の側が報告を配る形は範囲の外・follow-up（#549 とつなぐ）。
- 置き場: decision の決定4・`bin/README.md`・`delegate-task` のスキル（PR-1）、hooks の README と規則のファイルの注記（PR-2）。
- 言いすぎの訂正: Q118 のカードの説明のうち「外への通信は閉じたまま」と「`git commit` の規則をやめたので commit の hook の心配が消える」を、plan・episode・decision で「Claude の子と同じ状態になる」の言い方に直した。
- コードは変えない（`lib/agent.sh` の注釈の「外への通信は閉じたまま」は、sandbox の中のプロセスの直接の通信の話としては正しいので残す）。
- 8項目: step・ゲート・終端は変わらない。受入と設計判断の結論は、owner の決定で「sandbox を境界にしない」と明記する形に変わった。範囲は、作り直しを範囲の外へ出した（変更・再承認済み）。

### 記録（2026-11-13・I1）: ソースの参照の版の注記・C1〜C9 の結果・DJ-2/DJ-3/DJ-4/DJ-8 の結果の行

- 手元の版が 0.167.2 に上がったが、引いたファイルは変わっていないので行番号は据え置き（前提の節に注記）。

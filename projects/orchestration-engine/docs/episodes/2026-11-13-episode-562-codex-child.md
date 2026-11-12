---
id: "01M78B552HSWHVVR1KT7XDJAM4"
title: "#562 Codex CLI を、統括の子として tmux のペインで対話的に動かす"
date: 2026-11-13
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562"
    reason: "作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562#issuecomment-6830128252"
    reason: "着手時の認識合わせの確定版（2026-11-13）"
  - type: plan
    ref: "projects/orchestration-engine/docs/plans/2026-11-13-plan-562-codex-child.md"
    reason: "設計と実装の計画"
tags: [codex, delegation, agent-neutral]
---

# #562 Codex CLI を、統括の子として tmux のペインで対話的に動かす

## なぜこの作業が始まったか

2026-11-01 の大会の作業で、owner が Codex を直接開いて対話で使ったところ、Claude と Codex のあいだで人が文を写す作業が復活した（issue の本文の背景）。統括（cockpit）から plan-first で委譲された。認識合わせは issue の確定版コメント（2026-11-13）があり、書面の「認識合わせ:」欄の URL と、issue のコメントを機械で引いた最後の確定版の URL が一致することを確かめた（見出し4つ）。

## 着手時の状態（P1）

- 起点は `origin/master` の `5ddbdc1`（#640 のマージ後）。worktree はブランチ `feature/#562_codex_child`。
- 手元の Codex CLI は `codex-cli 0.167.1`。bash は PATH の先頭が 5.2.37、`/bin/bash` が 3.2.57。
- 子のセッションは Claude（Opus 5.5）で、lease を持つ（`OE_LEASE_ID` がある）。

## negative knowledge の採用

brief の5件をすべて採用する。ID と中身は一致していた（brief の要約と item の trigger を突き合わせた）。使った場面は closure の観測の記録に書く。

- `01M6XN85N408CMMERA12QR1C3F`（`exec` の形）: 自分のペインで確かめると、`ps -t <tty> -o pid=,tpgid=,comm=` で pid と tpgid が一致する行は `claude` だった。`oe-delegate` が渡す1行（`PARENT_TMUX_PANE=… claude …`）は `exec` を書いていないが、tmux が bash の `-c` で起こす最後の単純コマンドは bash が exec で置き換えるので、前面のプロセスは claude になる。Codex でも同じ形の1行にし、前面が `codex` になることを実機の確かめ（C6）に入れた。
- `01KYMRE1NC7XX6N66RQ0MGGHF1`（印の強さを保つ）: 調査のコメントの `[sub]` のうち設計の前提に使う3件（`codex resume` が同じ記録に追記する・sandbox の既定でネットワークが無効・`$スキル名` の効き目がそのターンに限る）は、plan では `[unverified-summary]` のまま写し、最初の2件は実機の確かめに入れた。

## 作業の記録

### P1: 参照の読みと、一次情報での確かめ直し

Codex のソースは、手元の版（`codex-cli 0.167.1`）に合うタグ `rust-v0.167.1`（コミット `0a94398`）を疎な checkout で取り、`codex-rs/` を読んだ。調査のコメントが読んだ 0.166.0 と、設計に効く箇所の違いは見つからなかった。確かめた事実の一覧は plan の「前提」節にあり、ここには plan に書かなかった読みの経緯だけを書く。

- hook に渡る環境変数の出どころを追った。hook の engine は `std::env::vars_os()`（`hooks/src/registry.rs:83`）で自分のプロセスの環境をまるごと写し、そこへ hook ごとの上書きを足す（`hooks/src/engine/command_runner.rs:486-495`）。除外されるのは認証の token 系の6変数だけで（`protocol/src/shell_environment.rs:14-21`）、`TMUX_PANE` は除外されない。11-11 の実機で、既定の起動では daemon を最初に起こしたペインの値が子のコマンドに入った理由はこれで、hook も同じ engine で走るので同じ値になる見込みである。`--no-daemon` なら TUI の中の app server が hook を走らせるので、ペインの値は正しくなる。
- 承認の `--approve-for-me` は、`approvals_reviewer="auto_review"`・`approval_policy="on-request"`・`sandbox_mode="workspace-write"` の3つの上書きに展開される（`cli/src/main.rs:3246-3263` の検査）。auto_review は別のレビュアーのモデルに承認の要求を回す仕組みで、公式の文書は「決定論的な保証ではない」と書く。engine の verb の送信のように毎回必ず通したいものは、レビュアーに任せず実行ポリシーの `allow` の規則で sandbox の外に出す（`core/src/exec_policy.rs:466-470` で、全部の区間が allow のときだけ sandbox を外す）。
- 公式の文書の URL は `developers.openai.com/codex/...` から `learn.chatgpt.com/docs/...` へ転送されていた（2026-11-13）。hooks の文書は hook の種類を14種類と書くが、対話の画面で発火するかは書いていない。`Stop` が対話で発火しない報告（openai/codex#17532）は open のままで、対象はリポジトリ直下の `.codex/config.toml` に書いた hook である。user 層の `hooks.json` で発火するかは確かめていない。
- Codex の入力欄の行頭は `›`（`tui/src/bottom_pane/chat_composer.rs:4967`）、作業中の表示は `Working (0s • esc to interrupt)`（`tui/src/status_indicator_widget.rs:457`）で、作業中の目印の文字列は Claude と同じだった。空の入力欄の補完の文は `Ask Codex to do anything`（同 `chat_composer.rs:5157`）。
- 手元の `codex` は Homebrew の cask が置く native のバイナリ（`/opt/homebrew/Caskroom/codex/0.167.1/bin/codex`）で、プロセスのコマンド名は `codex` になる。共有の daemon は `~/.codex/packages/app-server-daemon/releases/0.167.2-…` のバイナリで動いていて、CLI の 0.167.1 と版がずれている（調査のコメントのときと同じ構図）。
- 手元の `~/.codex/rules/default.rules` には owner がほかの作業で許可した行が入っているので、hub には写さない。hub が配る規則は別のファイル名にする。

昇格の印: hook に渡る環境変数は hook を走らせるプロセスの環境の写しで、daemon を介すとペインの値がずれる（`hooks/src/registry.rs:83`）。Codex に限らず、別のプロセスで hook を走らせる作りのエージェントで繰り返しうる。

### P1: 設計判断の洗い出し

設計判断（DJ）は plan の「設計判断」節に書いた。owner に聞くものは、brief が指定した4つ（承認のモードの既定・受領の印の扱い・lease のコマンド名の検査の広げ方・PR の数）と「この plan で実装に進むか」で、ほかは自分で決めた。自分で決めたもののうち、確かめの結果で分かれるもの（拍動の hook・受領の印の hook）は、plan の「実機の確かめ」節に分かれ方を書いた。

### P2: 設計SO（Codex の1レーン）と採否

`so-compare --codex-only`（gpt-6.1-sol・`codex-cli 0.167.1`）を1回通し、517秒で返った（`tool_status=not_observed`）。判定は `refuted` で、must 10・should 8 の18件だった。must はすべてソースを開き直して確かめ、18件すべてを plan に入れた（採否の表は plan の「設計SO」節）。plan の下書きの commit は `0fc715a`、直したあとの commit はこの節の下に書く。

設計の前提を崩した指摘が3つあり、どれも書き手が「読んだ範囲より1段広い言葉で結論を書いていた」形だった（knowledge `01KZVHE0KFDPXMY6EED80RN9ZR` の型）。

- 「sidecar が無い lease はラベルの宛先が registry に落ちる」と書いたが、`lib/target-resolve.sh:119-137` では binding のある lease が1件あれば registry には落ちず、送信が保留になる。読んだのは `lib/lease.sh` の候補の選び方までで、その先の分岐を読んでいなかった。直しとして、hook に依らない拍動の床（`oe-delegate` が spawn のときに `<lease_id>.json` を書き、子の `oe send` が書き直す）を engine に足した。
- 「`~/.codex/rules/` に別名のファイルを symlink で配る」と書いたが、規則の読み込みは `DirEntry::file_type().is_file()` で symlink を読まない（`core/src/exec_policy.rs:1201-1215`）。さらに user 層の規則は owner の Codex にも効く。配り方を通常のファイルの写しに変え、効く範囲を owner に見せる問いにし、`gh`・`git push` を規則から外した。
- 「`context_pct` は記録の最後の `token_count` の `total_token_usage` から出す」と書いたが、それは累積値で、TUI は `last_token_usage` を使う。`PostModelRequest` の hook の標準入力にその要求の `token_usage` が入るので、そちらから出す形に変えた。

昇格の印: Codex の `PostModelRequest` の hook は、その要求の `token_usage` を標準入力に持つ。記録の `total_token_usage` は累積で、文脈の使用量ではない（`protocol/src/protocol.rs:2545-2547`）。拍動を hook で書く設計で繰り返し踏みうる。

設計SO が挙げたゼロベースの案（outbox と broker・MCP の能力として子に渡す）は、この issue では採らず、#549（子の報告の届け方）の材料として plan の「ゼロベースの代替」に残した。

### P3 のあと: ゲート3 の答えの途中経過（2026-11-13）

統括から、owner の答えが3件届いたと知らせがあった。承認のモードの既定（`--approve-for-me` と allow の規則2行）・lease のコマンド名の検査（許す名前の集合）・実機の確かめの `auth.json`（写して終わったら消す）は、いずれも推奨どおり。受領の印の扱い・PR の数・plan の承認は未回答で、owner は受領の印について「engine が独立したときに AGENTS.md に頼る形でどう担保するかを考えたい」と書いている。実装には進まず待つ。

統括はその材料を受けて受領の印の問いを置き換え（起こしの最初の1行で伝える案を選択肢に入れ、統括の推奨は「最初の1行と固定節で伝え、`AGENTS.md` には engine の約束ごとを書かない」、書き手の見立て「`AGENTS.md` も重ねる」は別の選択肢）、owner の答えを待っている。plan は答えが出るまで直さない。

owner の問いに答える材料として、engine だけで担保する形を3つ整理して統括へ送った（`.oe/report-562-p3-q107.md`）。

### GATE 3: 承認（2026-11-13 03:18）

owner が6つの問いすべてに答え（承認のモード・lease の検査・PR の数・`auth.json`・plan の承認は推奨どおり、受領の印は `-c developer_instructions` と書面の固定節で伝える形）、統括が答えを写した plan（`8a6f7e7`）と照らして承認の記録 `.oe/decision-562-gate3.md` を書いた。

### I1: 実機の確かめ（2026-11-13 03:24〜03:46）

使い捨ての `CODEX_HOME`（scratchpad の `probe/codex-home`）と使い捨ての git リポジトリ（同 `probe/ws`）で行った。`~/.codex` の `config.toml` から `model` と `[features] hooks = true` だけを写し、`auth.json` を権限 600 で写した（owner の答え Q110）。hook は標準入力と環境を1行ずつ記録ファイルに書くだけの `probe-hook.sh` を `UserPromptSubmit`・`PostModelRequest`・`SessionStart` に配線した `hooks.json`（`CODEX_HOME` 直下に symlink で置いた）。規則は `rules/oe-child.rules`（通常のファイル・`oe` と `git commit` の2行）と `rules/oe-link.rules`（symlink・`tmux` の1行）。起こす1行は `oe-delegate` と同じ形で、`CODEX_HOME=… PARENT_TMUX_PANE=%<自分> codex --no-daemon --approve-for-me [--dangerously-bypass-hook-trust] -c 'developer_instructions="…"'` を `tmux split-window -d -c <ws>` に渡した。

**途中で版が変わった。** 1回目の resume の起動で Codex が「Update now（`brew upgrade --cask codex` を走らせる）／Skip」の画面を出し、そこへ送った1行の Enter が「Update now」に入って、手元の `codex` が 0.167.1 から 0.167.2 に上がった（03:32・owner の環境の変更）。統括に知らせ、統括は「戻さず 0.167.2 で進め、ソースの参照を 0.167.2 に当て直す」と決めた（owner には統括から知らせる）。起きた手順は次のとおり: `codex --no-daemon … resume <id>` を新しいペインで起こす → 画面に更新の確認が出る（選ばれている行は「1. Update now」）→ 10秒後に `oe send` で1行を送る → 1行は選択肢の画面に流れ、末尾の Enter が「Update now」を選ぶ → `brew upgrade --cask codex` が走り、ペインが閉じる。2つのタグの差分は7ファイル（`Cargo.toml`・`config.schema.json`・`core/src/session/step_context.rs`・`features/src/lib.rs`・tests 3本）で、plan が行番号で引いたファイルはどれも変わっていない（`git diff --stat rust-v0.167.1 rust-v0.167.2`）。更新の確認は設定の鍵 `check_for_update_on_startup = false` で出なくなる（`tui/src/updates.rs:28,153`・`config/src/config_toml.rs:533`）ので、engine の1行に `-c check_for_update_on_startup=false` を足す（plan の DJ-2・補正 H1）。

結果を1項目ずつ書く。「版」は Codex のバイナリの版、「経路」は起動の形である。

- C1 `UserPromptSubmit` の発火: **発火した。** 版 0.167.1（1回目のセッション）と 0.167.2（信頼を登録したあとのセッション）の両方。経路は `--no-daemon` の対話の画面。標準入力に `prompt`（受領の印を含む）・`session_id`・`turn_id`・`transcript_path`・`cwd` が入った。9回の送信で9回。
- C2 hook の環境の `TMUX_PANE`: **自分のペインの値だった**（`%704` など、起こしたペインと一致）。`TMUX` も入る。`CODEX_THREAD_ID` は hook の環境には入らない（子のコマンドにだけ入る）。版 0.167.1 と 0.167.2・`--no-daemon`。
- C3 `PostModelRequest` の発火: **発火した。** モデルへの要求のたびに走り（1ターンに3〜5回）、標準入力に `token_usage`（`input_tokens`・`cached_input_tokens`・`output_tokens`・`total_tokens`）・`status`・`model`（文字列）・`transcript_path` が入った。記録の `token_count` に `model_context_window: 475000` があった。`SessionStart` も `source` が `startup`・`compact`・`resume` のそれぞれで発火した。hook の実行時間は測っていない（記録の時刻は秒単位で、ターンの長さ 20〜24 秒の中に収まっていた）。
- C4 承認のモードと規則: **`oe send <統括のペイン>` と `oe send --to-parent` と `git commit --allow-empty` は、承認の画面に止まらずに通った**（版 0.167.1・`--approve-for-me`・通常のファイルの規則）。`oe send` は sandbox の外で走り、tmux のソケットにつなげた。規則の無い `curl -sI https://example.com` は sandbox の中で失敗（`Could not resolve host`）し、規則の無い `tmux display-message` も失敗（`Operation not permitted`）したが、**モデルは sandbox の外で走らせる要求を出さず、失敗をそのまま報告した**（auto_review は呼ばれなかった）。symlink の規則（`tmux`）が読まれるかは、確かめる前に版が変わり、0.167.2 のセッションではコマンドの道具が `timed out negotiating with the code-mode host` で動かなくなった（下記）ので、実機では確かめられていない（ソースの `is_file()` の読みのまま）。
- C5 resume: **`codex --no-daemon … resume <id>` で同じ記録のファイルに追記された**（120行 → 136行 → 149行）。`SessionStart` が `source: resume` で発火し、`session_id` は同じ。`CODEX_THREAD_ID` が同じ値で届くことは、0.167.2 のセッションでコマンドの道具が動かず確かめられなかった（11-11 の実機で確かめ済み）。
- C6 `exec` の形: **1行に `exec` を書かなくても、ペインの前面のプロセスは `codex` だった**（`ps -t <tty> -o pid=,tpgid=,comm=` で pid と tpgid が一致する行が `codex`。版 0.167.1 と 0.167.2）。Claude と同じで、`exec` は要らない。`$PPID` をたどる案は、**sandbox の中では `ps` が `Operation not permitted` で失敗する**ので、`oe` の verb（規則で sandbox の外に出る）の中で走らせる必要がある（plan の DJ-8 に補正 H2）。前面の pid との一致は、同じ理由で確かめられなかった。
- C7 workspace の外の読み書き: **読める（`--add-dir` 無し・`$HOME` の下のファイル）。書けない（`Operation not permitted`）。** `/private/tmp` の下は system temp として書けるので、最初の確かめ（scratchpad の中）は無効で、`$HOME` の下の `tmp/562-probe/` で確かめ直した。`--add-dir` を付けた確かめは、版の変更のあとコマンドの道具が動かず、行えていない。
- C8 入力欄と finalize: `oe send` は9回とも1回の Enter で送信された（二重に送ることも、Enter が吸われることも無かった）。ただし、いまの `_oe_send_inputline` は `❯` しか見ないので Codex の入力欄を見つけられず、finalize は何も判定していない（打ち直しも起きない）。`›` を足す変更が要ることは変わらない。
- C9 `developer_instructions`: **(1) 子は印をコマンドに写さなかった**（記録の全コマンドに `[oe:` が無い。版 0.167.1）。記録では developer の役割のメッセージとして ordinal 4 に入っていた。**(2) `/compact` のあとも写さず**、圧縮の `replacement_history` の中に同じ developer のメッセージが残っていた。**(3) 同じ `-c` を付けた resume のあと**、モデルは決まりを1文で言えた（道具は動かなかったが、答えは道具なしで返った）。**(4) `-c` 無しの resume のあとも**、「developer の指示がある」と答え、文を引用した（圧縮の履歴に残っているため）。圧縮を経ていない会話を `-c` 無しで開いたときは確かめていない。`codex debug prompt-input -c 'developer_instructions="…"'` で、モデルに見える入力の一覧に developer のメッセージとして入ること（`-c` 無しでは入らないこと）を、モデルを呼ばずに確かめられた（T-2 の検査に使える）。
- hook の信頼（DJ-12 の2段階目）: `--dangerously-bypass-hook-trust` を外して起こすと、起動時に「Review hooks」の確認が出て、hook は走らない（記録に増えない）。`/hooks` を開いて `t`（trust all）を押すと、`config.toml` に `[hooks.state."<CODEX_HOME>/hooks.json:<イベント>:0:0"]` が3件書かれ（鍵のパスは symlink の側）、以後 hook が走った。symlink の `hooks.json` は読まれる。

**0.167.2 で起きた道具の障害。** 更新のあとに起こしたセッション（resume も新規も）では、モデルのコマンドの道具が `timed out negotiating with the code-mode host` で毎回失敗し、`--disable code_mode_host` を付けると `code-mode host is disabled` で失敗した。0.167.1 のセッションでは同じ `CODEX_HOME` で動いていた。#448 と同じ型の障害で、使い捨ての `CODEX_HOME` に足りないもの（`packages/` など）があるのか、版の問題かは切り分けていない。この障害のため、C4 の symlink の規則・C5 の `CODEX_THREAD_ID`・C6 の pid の一致・C7 の `--add-dir` は実機で確かめられていない。

**残ったもの。** `~/.codex` に書かれたのは `models_cache.json`（モデルの一覧の cache・無害）と、brew の更新に伴う `app-server-daemon/daemon-updater.stderr.log`・`packages/app-server-daemon/auto-update-version`・`tmp/arg0-macos/…/.lock` で、設定・信頼・記録は増えていない（`find ~/.codex -newer <開始の印>`）。`auth.json` の写しは消した。`$HOME` の下の `tmp/562-probe/` は消した。scratchpad の `probe/codex-home`（会話の記録・history・SQLite）は、`rm -rf` が hub の hook に止められたので残っている（資格情報は含まない。scratchpad は3日で消える）。Homebrew の cask の 0.167.1 → 0.167.2 は戻していない。

### I1 のあと: 統括の判定と Q113

統括は H2・H3 と、H1 のうち `-c check_for_update_on_startup=false` を補正として受け付け（承認の記録の entry 1）、H1 のうち「`Trust this folder?` に Enter を1回送る」は変更と判定した（engine が owner に代わって workspace を信頼する新しい振る舞いで、画面の文言を読んで分岐するため）。この部分は実装せず、owner の答え（判断ボード Q113）を待つ。統括の求めで、起動の `-c` で信頼を渡せるかを確かめた: `-c 'projects."<path>".trust_level="trusted"'` を付けても確認の画面は出た（実機・0.167.2・使い捨ての `CODEX_HOME`）。信頼は読み込んだ設定の `projects` の表から cwd と git の根のパスで引き（`core/src/config/mod.rs:3636-3645`・`config/src/config_toml.rs:930-942`）、worktree は git の根が自身なので worktree ごとに要る。engine が取れる形4つ（Enter を送る・`config.toml` に書く・何もしない・確認が出ていたら送らずに止まって知らせる）を `.oe/report-562-i1-trust.md` に書いて送った。I2 以降は、確認が出ていても engine は答えず、README とスキルに「人が子のペインで答えてから最初の1行を送り直す」と書いた。

### I2〜I5: engine と配るスキル（PR-1 の中身）

- I2（`557ab05`）: `lib/agent.sh` を足し、`oe delegate --agent <claude|codex>` と `--agent-arg`（`--claude-arg` は alias）を実装した。claude の1行は変えず（`tests/test_oe_delegate.sh` の [1][2] と [A1] が同じ値で通る）、codex は `--no-daemon -c check_for_update_on_startup=false --approve-for-me -c developer_instructions="…"` の既定を付ける。registry と lease の記録に `agent`、schema と `validate-lease` を `claude|codex` に広げた。承認のダイジェストに `agent` を入れ、鍵を `agent_args` に変えた。拍動の床（`oe_hb_write_floor`）を `oe-delegate` が起こしたあとに書く。`tests/test_agent.sh`（70件）を足した。
- I3（`df995c8`）: lease の binding・claim・advance と `oe-lease adopt` の検査を許す名前の集合（basename の完全一致）に、`oe_lease_whoami` の fallback を `oe_agent_self` の会話の ID にした。`lib/delegate-send.sh` は宛先のエージェント（`OE_SEND_TARGET_AGENT`・`oe-send` が lease か registry から引く）で入力欄の記号（`❯›»`）と補完の文を切り替え、宛先が分からなければ今までどおり `❯` だけを見る。`oe-send` は lease を持つ子が送るたびに床を書き直す。
- I4（`acf4b2d`）: `oe-recover hint` が lease の `agent` で resume の1行を出し分け、`oe-recover` 本体が自分の pid と会話の ID を `oe_agent_self` で読む。`oe-handoff` の案内（`claude --resume`）は統括の verb で、Codex を統括にするのは範囲の外なので変えていない（plan の DJ-9 は「`oe-recover hint` と `oe-handoff`」と書いていたので、`oe-handoff` を外す補正 H4 として申告する）。
- I5（`1bbc38d`）: `delegate-task`・`doc-flow-guardrail`（skill 解決規約・受領の印の1行）・`bin/README.md`（7か所の対応表・PR-2 が無い状態の制限・範囲の外の5つ）・`orchestration-toolkit`・engine の README。
- 検査は各段で bash 5 と `/bin/bash` 3.2 の両方で回し、全件 exit 0（CHECK-1 で全部を回す）。

`oe_agent_self` は `CODEX_THREAD_ID` を `CLAUDE_*` より先に見る。Codex は自分の打つコマンドにだけ `CODEX_THREAD_ID` を入れる一方、`CLAUDE_*` は tmux のセッションの環境から子に引き継がれうるためで、検査（`test_agent.sh` の [9]）で固定した。最初の版は逆の順で、このセッションの環境を引き継いだ検査が claude と答えて見つかった。

昇格の印: Codex の対話の画面は、起動の直後に更新の確認の画面を出すことがあり、そこへ送った1行の Enter が「Update now」を選んで `brew upgrade` を走らせる。engine が起こす1行には `-c check_for_update_on_startup=false` を付ける。起動の直後に別の確認（フォルダの信頼・hook の確認）が出ることもあるので、起こしてから最初の1行を送るまでに画面を確かめる口があるとよい（この issue では付けない）。要点は、受領の印の説明を hub の `AGENTS.md` に置くのは「常時の原則」の層で、engine が独立したときは engine 自身が起こしのときに1回だけ伝える（`oe-delegate` が最初の1行に説明を添える）か、engine が配る hook が印のある prompt にだけ `additionalContext` で伝えるかで代えられる、ということである。


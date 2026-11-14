---
id: "01M78B552HSWHVVR1KT7XDJAM4"
title: "#562 Codex CLI を、統括の子として tmux のペインで対話的に動かす"
date: 2026-11-13
type: episode
status: stable
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
  - type: decision
    ref: "projects/orchestration-engine/docs/decisions/2026-11-13-decision-562-codex-child-launch.md"
    reason: "closure で昇格した判断（H10・Q112・Q113）"
tags: [codex, delegation, agent-neutral]
promotion:
  - subject: "hook の環境は走らせるプロセスの写し（daemon を介すとペインがずれる）"
    verdict: not-required
    ref: "本文: P1: 参照の読みと、一次情報での確かめ直し"
  - subject: "PostModelRequest の token_usage は要求ごと・記録の合計は累積"
    verdict: not-required
    ref: "本文: P2: 設計SO（Codex の1レーン）と採否"
  - subject: "道具の障害のレーンは「返った」と「読めた」を分けて見る"
    verdict: not-required
    ref: "本文: GATE 4: PR-1 の実装SO（2026-11-13）"
  - subject: "input_tokens は cached を含む"
    verdict: not-required
    ref: "本文: GATE 4: PR-2 の実装SO（2026-11-13）"
  - subject: "起動の直後の確認の画面に最初の1行を流さない（更新の確認）"
    verdict: not-required
    ref: "本文: GATE 4: PR-2 の実装SO（2026-11-13）"
  - subject: "engine の約束ごとを AGENTS.md でなく起こす1行で持ち込む（Q112）"
    verdict: required
    ref: "本文: GATE 4: PR-2 の実装SO（2026-11-13）"
  - subject: "実機の確かめは、モデルが普段どおりに打つ形で行う"
    verdict: not-required
    ref: "本文: CHECK-2 の1回目（2026-11-13 18:00 ごろ・統括 gen25 が起こした・使い捨ての `CODEX_HOME`）"
  - subject: "tmux の宛先が空だといまのペインを指す"
    verdict: required
    ref: "本文: 確かめの5点と H10（Q118・2026-11-13）"
  - subject: "Codex の -c の鍵の形"
    verdict: required
    ref: "本文: 確かめの5点と H10（Q118・2026-11-13）"
  - subject: "権限を起こす1行で渡し、規則は oe の1行だけ（H10・Q118）"
    verdict: required
    ref: "本文: 確かめの5点と H10（Q118・2026-11-13）"
  - subject: "フォルダの信頼の確認に条件つきで Enter を送る（H8・Q113）"
    verdict: required
    ref: "本文: H8: フォルダの信頼の確認（owner の答え Q113・`dae6bca`）"
  - subject: "Codex の sandbox を安全の境界にしない（Q119）"
    verdict: required
    ref: "本文: Q119: sandbox を安全の境界にしない（2026-11-14）"
  - subject: "sandbox の権限の足し先が sandbox の外の権限を持つ相手かを見る"
    verdict: not-required
    ref: "本文: Q119: sandbox を安全の境界にしない（2026-11-14）"
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

CHECK-1（`38dabdb`）: `tests/test_*.sh` 54本を bash 5.2.37 と `/bin/bash` 3.2.57 で回し、108回がすべて exit 0。

### I6: Codex の配布物（PR-2・ブランチ `feature/#562_codex_dist`・PR #645）

PR-1 の上に重ねた。`codex.hooks.json` に `UserPromptSubmit`（取り込み印と拍動）と `PostModelRequest`（拍動）を配線し、`oe-heartbeat-hook.sh` を新しく書いた（`PostModelRequest` の `token_usage` と記録の `model_context_window` から context%・標準出力に何も出さない・記録は末尾から上限付き）。規則 `canonical/codex/rules/oe-child.rules`（`oe`・`git commit`）は `sync-codex.sh` の `sync_rules` が通常のファイルとして写す（symlink は Codex が読まないため・設計SO の指摘1）。`AGENTS.md` は「委譲の子は書面の固定節に従う」の節だけ。hooks の README に信頼の登録と登録し直しの条件を書いた。検査は `test_heartbeat_hook.sh`（23）・`test_codex_dist.sh`（17）・`test_prompt_receipt.sh` の [7b] で、bash 5 と 3.2 で exit 0。CHECK-2（sync を一時ディレクトリで確かめ、owner が `/hooks` で登録してから1回回す）は owner の手が要るので、統括に時期を聞く。

### GATE 4: PR-1 の実装SO（2026-11-13）

`so-compare --codex-only` は 158 秒で返ったが `tool_status=degraded`（`timed out negotiating with the code-mode host`）で、レビュアーは差分を読めずに「判定できない」と答えた。I1 で使い捨ての `CODEX_HOME` で見たのと同じ障害で、手元の codex が 0.167.2 に上がったあとは owner の `~/.codex` でも起きる（統括が `codex exec` で同じ障害を確かめ、owner に進め方を聞いている・Q114。切り分けは統括が受け持ち、子は Codex の版や設定を触らない）。degraded は SO の実施に数えないので、Cursor のレーン（`so-compare --cursor-only`・composer-2.5・指定・116 秒）で回し直した。判定は `survived`・must 0・should 8 で、8件すべてを採って直した（plan の H5・`e19bdf2`）。レビュアーが指した「schema に top-level の `agent` が無い」は、I2 の最初の編集の一括が途中で失敗していて、schema だけ取り残されていた（検査は jq の `validate-lease` を通っていたので気づかなかった）。

昇格の印: 道具の障害（`tool_status=degraded`）は、レーンが「返った」ことと「読めた」ことを分けて見ないと通してしまう。so-compare の meta を読む決まりはあるが、版の更新の直後は特に疑う。

### GATE 4: PR-1 の Copilot の1ラウンド（2026-11-13）

PR #644 を ready にして Copilot に依頼し、3件の指摘が付いた（plan の H6・`3fc8768`・3件とも返信済み）。(1) `-c sandbox_mode=danger-full-access` が既定の `--approve-for-me` を外す一方で権限の判定は読まず、sandbox を外した子を承認ダイジェスト無しで起こせた。実装SO の指摘2を「既定を外す」側だけで直し、「判定」側を忘れていた。(2) 床の sidecar を通常の sidecar と区別していなかったので、同じペインの拍動が2件に数えられ `oe-tree` が model / context% を隠し、`oe_hb_session_for_pane` が lease_id を会話の ID として返しうる。床に `floor: true` を付け、読む側で分けた。(3) `comm` の検査は basename で通るのに記録には元の値が残り、schema の完全一致と食い違う。検査の前に正規化した。2つ目は設計SO の指摘4（床を足す）に対する追加の読む側の変更で、SO の2周目に当たる欠陥だった。

### GATE 4: PR-2 の実装SO（2026-11-13）

Codex のレーンは道具の障害、Cursor のレーンは 1350 秒（延長の再試行を含む）で空のまま時間切れだった。弱い SO の「0 はなし」の決まりで、Claude のレーン（`--claude-only --claude-model opus --claude-effort high`・`claude-opus-5-5`・543秒）で回した。書き手と同じ会社のモデルなので、別の会社のレーンより弱い裏付けとして扱う。判定は `refuted`（must 2・should 9）。must の1つ目は context% の分子で cached のトークンを二重に数えていたことで、Codex の `TokenUsage` では `input_tokens` が cached を含む（`protocol/src/protocol.rs:2670-2681`・レビュアーが hook を実際に走らせて 25.25% のところ 47.8% を再現した）。plan の DJ-6 の式が最初から誤っていて、設計SO も実装SO（PR-1）も通り抜けた。2つ目は床と hook の sidecar が同じペインに並ぶことで、PR-1 の Copilot の指摘（H6）と同じ欠陥を別のレーンが独立に指した。should 9件は、取り消した要求で 0 に戻さない・記録を1行ずつ読む・`PostModelRequest` を async と timeout 付きで配線する・古い規則の掃除・README・検査の切り出し、と、owner に聞く2件（規則 `oe` の広さ・`git commit` と commit の hook）。11件すべてを採り、2件は問い `.oe/question-562-2.json` にした（plan の H7・PR-2 の GATE 4 の commit（題「実装SO の指摘を直す（#562 GATE 4・PR-2）」））。

昇格の印: Codex の `token_usage.input_tokens` は cached のトークンを含む。文脈の使用量は `total_tokens`（`tokens_in_context_window`）で、`input + cached + output` と足すと cache の当たりが多い長いセッションほど大きく見積もる。

`oe_agent_self` は `CODEX_THREAD_ID` を `CLAUDE_*` より先に見る。Codex は自分の打つコマンドにだけ `CODEX_THREAD_ID` を入れる一方、`CLAUDE_*` は tmux のセッションの環境から子に引き継がれうるためで、検査（`test_agent.sh` の [9]）で固定した。最初の版は逆の順で、このセッションの環境を引き継いだ検査が claude と答えて見つかった。

昇格の印: Codex の対話の画面は、起動の直後に更新の確認の画面を出すことがあり、そこへ送った1行の Enter が「Update now」を選んで `brew upgrade` を走らせる。engine が起こす1行には `-c check_for_update_on_startup=false` を付ける。起動の直後に別の確認（フォルダの信頼・hook の確認）が出ることもあるので、起こしてから最初の1行を送るまでに画面を確かめる口があるとよい（この issue では付けない）。要点は、受領の印の説明を hub の `AGENTS.md` に置くのは「常時の原則」の層で、engine が独立したときは engine 自身が起こしのときに1回だけ伝える（`oe-delegate` が最初の1行に説明を添える）か、engine が配る hook が印のある prompt にだけ `additionalContext` で伝えるかで代えられる、ということである。


### H8: フォルダの信頼の確認（owner の答え Q113・`dae6bca`）

（実装のあと、CHECK-2 の1回目の原因を調べてから追記した。）owner は「もとのリポジトリを Codex で信頼済みのときだけ engine が Enter を1回送る。`config.toml` は読むだけ。信頼されていない・画面を読めないときは最初の1行も送らずに止まる」と決めた（承認の記録の entry 3）。`oe-delegate` は Codex の子を起こしたあと画面を読み、確認の文言があれば `$CODEX_HOME/config.toml` の `[projects."<main の作業ツリー>"]` を読んで分かれる。I1 の昇格の印に書いた「起こしてから最初の1行を送るまでに画面を確かめる口」は、この形でこの issue に入った。

### CHECK-2 の1回目（2026-11-13 18:00 ごろ・統括 gen25 が起こした・使い捨ての `CODEX_HOME`）

子の報告は統括に届かず、2か所で止まった。受領の印はコマンドに写されず、`prompt_received` 1・hook の sidecar 1・床 1 は取れた。承認の画面は出なかった。

- 試しの書面の commit の文 `add hello.txt` を hub の `cc-lint.sh`（PreToolUse）が止めた。書面を書いた子の誤りで、hook は Codex の子のコマンドにも効いた。
- 子は `mkdir -p .oe`・ヒアドキュメント・`oe send --to-parent` を1つのスクリプトにして打ち、`oe send` は exit 5（宛先の本人を確かめられない）で、event bus への書き込みは `Operation not permitted` だった。Codex は、スクリプトを分けた部分のすべてが allow の規則に当たるときだけ sandbox の外で走らせる（`core/src/exec_policy.rs:466-480`）。sandbox の中では tmux のソケットにつなげず、`~/.claude/state` に書けない（`codex sandbox -c 'sandbox_mode="workspace-write"' -- …` で確かめた）。統括の lease は sandbox の外では統括のペインに引け、中では引けない。
- 調べる途中で、`git add` も sandbox の中で必ず失敗することが分かった。workspace-write の sandbox は `.git` を読み取り専用にし（`protocol/src/permissions.rs:860`）、worktree の index は本体の `.git/worktrees/` にある。規則は `oe` と `git commit` の2行なので、子は新しいファイルを commit できない。
- 起動の直後の hook の確認の画面は、0.167.2 では「1. Review hooks / 2. Trust all and continue / 3. Continue without trusting」で、手順書の「`/hooks` で `t`」と違った。
- `~/bin/oe` は master の engine で、床を知らないので `oe tree` が子の行を `ambiguous(2)` と出した。子のコマンドの `oe` も master の版だった（マージ前の確かめの限界）。

直し方は `.oe/report-562-check2-run1.md` に書いた。試しの書面と手順書（作業層）は直し、engine の検知（`CODEX_SANDBOX`）・決まりの文・規則 `git add` の3つは plan の変更なので、問い `.oe/question-562-3.json` で owner に聞く。

昇格の印: I1 の C4 で `oe send` と `git commit` が通ったのは、子に打たせる1行を単独の形で渡したからだった。Codex は自分で複数のコマンドを1つのスクリプトにまとめるので、規則で外に出す設計は、モデルが普段どおりに打つ形で確かめないと抜ける。実機の確かめでは、打つコマンドの形を渡さずに作業だけを渡す。

### 確かめの5点と H10（Q118・2026-11-13）

統括が Codex の権限の仕組みを Codex に調べさせ、その主張のうち5点を子が `codex sandbox` と使い捨ての `CODEX_HOME` で確かめた。打ったコマンドと出力の要点は次のとおり（版 0.167.2・`codex sandbox -c 'sandbox_mode="workspace-write"' -- …`・使い捨ての `CODEX_HOME` と worktree）。

- 状態の置き場: 既定では `~/.claude/state` への書き込みが `Operation not permitted`、`-c 'sandbox_workspace_write.writable_roots=["<state>"]'` を足すと書けた。
- worktree の git: 既定では `git add` が `…/.git/worktrees/<名前>/index.lock: Operation not permitted`。gitdir だけを足すと `unable to create temporary file`、本体の `.git` だけでは index.lock で失敗し、両方を足すと `git add` と `git commit` が rc 0。
- tmux: 既定では `error connecting to /private/tmp/tmux-501/default (Operation not permitted)`。`network_access=true` だけでつながるが `curl https://example.com` が 200（外へ全部開く）。`network_access=true`・`network_proxy.enabled=true`・`unix_sockets` の3つでつながり、`curl` は `CONNECT tunnel failed, response 403`。
- フォルダの信頼: `-c 'projects."<path>".trust_level="trusted"'` では確認が出た。`-c 'projects={"<path>"={trust_level="trusted"}}'` では出ず、worktree は鍵が本体のリポジトリでも worktree でも出なかった。鍵が `/tmp/…` で cwd が実体の `/private/tmp/…` のときは出た。
- `oe`: 全部を足した sandbox の中で、生のペイン番号への `oe send` は `mkdir` とつないでも届いた。`ps` は `execvp() of 'ps' failed: Operation not permitted`、`pgrep` は `Cannot get process list` で、`oe lease resolve`（`--to-parent` の経路）は引けなかった。

確かめの全文は作業層にあり、要点を上に書いた。書ける場所（`writable_roots`）・`.git` の保護（本体の `.git` と gitdir の両方を明示すると外れる）・tmux のソケット（`network_access`・プロキシ・`unix_sockets` の3つで、sandbox の中のプロセスの直接の通信を閉じたまま開く）は主張どおりだった。フォルダの信頼の `-c 'projects."<path>".trust_level=…'` は効かず、値の形 `-c 'projects={"<path>"={…}}'` なら効いた。`-c` の鍵は `.` で単純に分けられ（`config/src/overrides.rs:22`）、引用符が鍵に残るためで、I1 で「`-c` では出さずに済まない」と結論したのはこの形の誤りだった。worktree は本体のリポジトリの鍵でも確認が出なかった。`oe send --to-parent` は、権限を足しても sandbox の中では通らない（`ps` が起動できず、`pgrep` も一覧を取れない）。

途中で、試しのスクリプトの `tmux split-window` が `no space for new pane` で失敗し、空の変数で打った `tmux kill-pane -t ""` が統括のペインと子のペインを閉じた。`oe recover` で張り直し、以後は試しのペインを別のウィンドウに作り、宛先が空・自分・統括でないことを確かめてから閉じた。

owner は Q118 で「git と状態の置き場と tmux は起こす1行で渡し、規則は `oe` の1行だけ」と決めた（plan の H10・承認の記録の entry 4）。PR-1 `edc9236`・PR-2 の H10 の commit（題「#562 の規則を oe の1行にし…（H9・H10）」）。

昇格の印: tmux の宛先を変数で受けるコマンド（`kill-pane`・`send-keys`・`capture-pane`）は、変数が空だと「いまのペイン」を指す。試しのペインを作るコマンドが失敗したときに、作ったつもりのペインでなく自分や統括のペインを閉じる。宛先が空でないこと・自分と統括でないことを確かめてから打つ。

昇格の印: Codex の `-c` の鍵は `.` で単純に分けられるので、`projects."<path>"` や `hooks.state."<鍵>"` のように引用符で囲んだ鍵は効かない。表を値として渡す（`-c 'projects={"<path>"={trust_level="trusted"}}'`）。

### CHECK-2 の2回目（2026-11-13 22:48・統括 gen25 が起こした）

子の報告の1行が統括に届き、`0094ed0 chore: add hello.txt` ができた（統括の観測 `.oe/check2-run2-observation.md`）。M-1 は写し 0・承認の画面 0・`git push` と `gh` 0。M-2 は受領 1・hook の sidecar 1・床 1 で、PR の `oe tree` が子の行に `gpt-6.1-sol 3%` を出した。

子の会話の記録（使い捨ての `CODEX_HOME` の `rollout-2026-11-13T22-47-58-…jsonl`）では、子は `printf … > hello.txt`・`git add hello.txt`・`git commit -m 'chore: add hello.txt'`・`git log --oneline -1` を1つのスクリプトにして打ち、exit 0 だった。規則は `oe` の1行だけなので、この git は sandbox の中で走り、`--add-dir` で渡した `.git` に書けた（実機の確かめは `writable_roots` だったので、`--add-dir` の効きはここで初めて確かめた）。`oe send --to-parent` は単独のコマンドとして打たれ、`sent to <統括のペイン>（lease … generation 3）` で返った。子の `oe` は `~/bin/oe`（master）なので入口の `CODEX_SANDBOX` の検知は動いていない。単独で打ったのが決まりの文の1文によるものかは、この1回からは言えない（1回目は書面だけで、決まりの文にこの1文は無かった）。

### GATE 4: H10 の実装SO（2026-11-13）

H10 は PR ごとの実装SO（H5・H7）のあとに入ったので、GATE 4 を H10 の差分に当て直した（plan の H11・補正）。Codex のレーン（`gpt-6.1-sol`・道具の障害は観測されず・251秒）で `refuted`（must 2・should 1）。ソケットのパスを TOML の文字列に逃がさずに埋めていたこと、利用者がプロキシだけを外すと engine の `network_access=true` が残って外への通信が全部開くこと、検査が文字列の比較だけだったことを指された。3件とも直し、TOML として解析して元のパスに戻る検査と、利用者の引数があるときにネットワークの指定を出さない検査を足した。足した検査のラベルで `$ua` の直後に全角の括弧を置き、bash が変数名に食べて止まった（`${ua}` で囲んで直した）。Copilot の再依頼は owner の明示の指示があるときだけ行う運用なので、PR-1 には出していない。

### マージ前のレビュー（2026-11-14）

closure のあと、owner が Codex に PR #644・#645 をレビューさせた。統括がコードを読んで誤りと確かめた2件を直した（plan の H12）: ネットワークの判定が `-c` と値をつなげた書き方を拾わず、H11 の直しをすり抜けて外への通信が開くこと（同じ抜けで `-sdanger-full-access` が elevated と読まれていなかった）と、信頼の確認で Enter のあとの2回目の読み取りと Enter の送信の失敗を素通りしていたこと。H11 の実装SO の直しは `-c KEY=V` と `--config=KEY=V` の形だけを検査していて、Codex の CLI が受け付けるほかの書き方を数え上げていなかった。レビューのほかの指摘（tmux のソケットからサーバー側の権限で操作できる・共通の `.git` に hook を仕込める・状態の置き場を書き換えられる・規則 `oe` が広い）は設計の話で、owner に判断ボードで聞いている。

### Q119: sandbox を安全の境界にしない（2026-11-14）

マージ前のレビューが「マージ前に必ず直す」とした4件（tmux のソケットから親の tmux サーバーの権限で操作できる・共通の `.git` に hook を仕込める・`~/.claude/state` の記録を書き換えられる・規則 `oe` が広い）について、owner は Q119 で「誤り2件を直し（H12）、境界でないことを文書に書いてマージし、作り直しは別の issue にする」と決めた（plan の H13・承認の記録の entry 8）。engine の安全の考え方は「子は親と同じだけ信頼する。守りは hook と人の承認のゲートと、Claude の子では auto mode の判定器で持つ」で、Codex の sandbox は事故を防ぐものであって境界ではない。Claude の子も同じ3つに届いていて、違いは Codex の子の sandbox の中の操作を裁く判定器が無いことである。decision の決定4・bin/README・delegate-task のスキル・hooks の README・規則のファイルの注記に書いた。言いすぎだった2点（外への通信は閉じたまま・commit の hook の心配が消える）を直した。

昇格の印: sandbox の権限を足す設計を書くときは、足した先（tmux のソケット・共有の記録・共通の `.git`）が sandbox の外の権限を持つ相手かを見る。ソケットや共有のファイルの先にいるプロセスは sandbox の外で動くので、そこに届く時点で「閉じたまま」とは言えない。

## closure

tier: heavy（方針の転回が2回あった〔H8・H10〕・意図して起動した外部レビュー〔設計SO・実装SO〕・選択肢を比べて棄却した設計判断・decision と knowledge への昇格がある）。

### 事実・失敗

- 設計SO が `refuted` を返し、plan の案のうち「読んだ範囲より広い結論」（sidecar と registry・symlink の規則・`context_pct`）など 18 件を直した。`本文: P2: 設計SO（Codex の1レーン）と採否`
- I2 の最初の一括の編集が途中で失敗し、lease の schema の top-level の `agent` だけが取り残された。jq の `validate-lease` は通っていたので、PR-1 の実装SO が指すまで気づかなかった。`本文: GATE 4: PR-1 の実装SO（2026-11-13）`
- PR-1 の Copilot が3件を指した。うち1件は、`-c sandbox_mode=danger-full-access` で sandbox を外した子を承認ダイジェスト無しで起こせた実装の漏れだった（設定の鍵での指定も elevated と読むように直した・H6）。`本文: GATE 4: PR-1 の Copilot の1ラウンド（2026-11-13）`
- PR-2 の実装SO の must 2件目は、床と hook の sidecar が同じペインに並んで二重に数えられること（PR-1 の Copilot の指摘と同じ欠陥）。`oe_agent_self` が `CLAUDE_*` を先に見ていて、検査が claude と答えたことも見つかった。`本文: GATE 4: PR-2 の実装SO（2026-11-13）`
- 版の更新の事故: resume の起動の直後の更新の確認に送った1行の Enter が「Update now」を選び、owner の Codex が 0.167.1 から 0.167.2 に上がった。`本文: I1: 実機の確かめ（2026-11-13 03:24〜03:46）`
- 0.167.2 で Codex の道具が `timed out negotiating with the code-mode host` で止まり、実装SO の Codex のレーンが2回とも判定なしになった（統括の Q114 は取り下げ・原因は未確定）。`本文: GATE 4: PR-1 の実装SO（2026-11-13）`
- DJ-6 の context% の式が cached を二重に数えていて、設計SO と PR-1 の実装SO を通り抜け、PR-2 の実装SO で見つかった。`本文: GATE 4: PR-2 の実装SO（2026-11-13）`
- 規則で外に出す設計（DJ-3）は、I1 の C4 で単独のコマンドの形だけを測って根拠にしていた。CHECK-2 の1回目で、子がつないで打った `oe send` が sandbox の中で走って届かず、`git add` も通らないと分かり、H10 で設計を変えた。試しの書面の commit の文が hub の hook に止められたのは子の書き手の誤り。`本文: CHECK-2 の1回目（2026-11-13 18:00 ごろ・統括 gen25 が起こした・使い捨ての `CODEX_HOME`）`
- I1 で「`-c` ではフォルダの信頼を渡せない」と結論したのは、鍵の形の誤りだった（引用符が鍵に残る）。その結論の上で H1・H8 の Enter を送る案が組まれた。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- マージ前のレビューが、tmux のソケット・共通の `.git`・`~/.claude/state` を通じて子が sandbox の外の権限で操作できることを実測で示した。owner は境界でないことを書いてマージすると決めた（Q119）。`本文: Q119: sandbox を安全の境界にしない（2026-11-14）`
- マージ前のレビューで、H11 の直しが `-c` と値をつなげた書き方を拾わず外への通信が開くことと、信頼の確認の読み取りの失敗を素通りしていたことが見つかった（plan の H12）。`本文: マージ前のレビュー（2026-11-14）`
- H10 の実装SO が must 2 件を指した（ソケットのパスの TOML の逃がし忘れ・利用者がプロキシを外すと外への通信が開く）。`本文: GATE 4: H10 の実装SO（2026-11-13）`
- 確かめのスクリプトの空の変数で `tmux kill-pane -t ""` を打ち、統括のペインと自分のペインを閉じた。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- master の engine の拍動の照合に時刻の競合がある（走査の初めに取った now より新しい拍動を捨てる）。CHECK-2 の1回目で子が受け取った rc 1 はこれだった。`本文なし: 確かめの報告 .oe/report-562-sandbox-verify.md の 5 に書き、episode の本文には書いていなかったので、ここで要点を書き起こした（trace で [ 1794563928 -le 1794563925 ] → continue）`

### 決定と根拠

- 権限と engine の約束ごとの持ち込み方（H10・Q112・Q113）は decision に昇格した: `projects/orchestration-engine/docs/decisions/2026-11-13-decision-562-codex-child-launch.md`。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- PR を2つに分けた（PR-1 engine・PR-2 Codex の配布物・Q109）。`本文: GATE 3: 承認（2026-11-13 03:18）`

### わかったこと

- Codex は、つないだコマンドのすべての部分が allow の規則に当たるときだけ sandbox の外で走らせ、モデルは普段からコマンドをつなぐ。`本文: CHECK-2 の1回目（2026-11-13 18:00 ごろ・統括 gen25 が起こした・使い捨ての `CODEX_HOME`）`
- sandbox の中では `ps` が起動できず、`pgrep` も一覧を取れない。`--add-dir` で本体の `.git` と gitdir を足せば `git add`・`git commit` が sandbox の中で通る。`本文: 確かめの5点と H10（Q118・2026-11-13）`・`本文: CHECK-2 の2回目（2026-11-13 22:48・統括 gen25 が起こした）`

### 蒸留シグナル

- decision: 上の1件（決定1〜3）。
- knowledge: 2件を収穫した。`01M7AJWRFGR2KDN87B7YDQ787V`（tmux の宛先が空だといまのペインを指す・guard-candidate）、`01M7AJWRG7H6QBDC7V45VMJEE0`（Codex の `-c` の鍵は `.` で単純に分けられる）。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- skill / rule: なし（engine の手順は `delegate-task` と bin/README に入れた）。

### 昇格の判定

frontmatter の `promotion` に1件ずつ置いた。理由は次のとおり。

- hook の環境は走らせるプロセスの写し（daemon を介すとペインがずれる）: not-required。DJ-2 と `lib/agent.sh` の `--no-daemon` の注記に着地し、Codex の正本（ソース）を読めば決まる確認の話である。`本文: P1: 参照の読みと、一次情報での確かめ直し`
- `PostModelRequest` の `token_usage` は要求ごと・記録の合計は累積: not-required。`oe-heartbeat-hook.sh` の注記と検査（T-9）が正本である。`本文: P2: 設計SO（Codex の1レーン）と採否`
- 道具の障害のレーンは「返った」と「読めた」を分けて見る: not-required。so-compare のスキルの「Codex の道具の障害」節に着地済み。`本文: GATE 4: PR-1 の実装SO（2026-11-13）`
- `input_tokens` は cached を含む: not-required。hook の式と検査が正本で、実物を見れば決まる確認の話である。`本文: GATE 4: PR-2 の実装SO（2026-11-13）`
- 起動の直後の確認の画面に最初の1行を流さない（更新の確認）: not-required。`-c check_for_update_on_startup=false` が engine の1行に入った。`本文: GATE 4: PR-2 の実装SO（2026-11-13）`
- engine の約束ごとを `AGENTS.md` でなく起こす1行で持ち込む（Q112）: required。decision の決定2 として実行した。`本文: GATE 4: PR-2 の実装SO（2026-11-13）`
- 実機の確かめは、モデルが普段どおりに打つ形で行う: not-required。既存の knowledge `01KZVHE0KFDPXMY6EED80RN9ZR`（測ったのは鎖の途中まで）に同じ教訓が着地済みで、観測を `externally_verified` で足した。`本文: CHECK-2 の1回目（2026-11-13 18:00 ごろ・統括 gen25 が起こした・使い捨ての `CODEX_HOME`）`
- tmux の宛先が空だといまのペインを指す: required。knowledge に収穫した。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- Codex の `-c` の鍵の形: required。knowledge に収穫した。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- 権限を起こす1行で渡し、規則は `oe` の1行だけ（H10・Q118）: required。decision の決定1 として実行した（印は付けていなかった・closure で拾った）。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- フォルダの信頼の確認に条件つきで Enter を送る（H8・Q113）: required。decision の決定3 として実行した。
- Codex の sandbox を安全の境界にしない（Q119）: required。decision の決定4 として実行した。`本文: Q119: sandbox を安全の境界にしない（2026-11-14）`
- sandbox の権限の足し先が sandbox の外の権限を持つ相手かを見る: not-required。同じ中身（tmux のソケット・共通の `.git`・共有の記録の先は sandbox の外）が decision の決定4 に書いてあり、Codex の子の設計を見直す別の issue がそれを読む。`本文: Q119: sandbox を安全の境界にしない（2026-11-14）``本文: H8: フォルダの信頼の確認（owner の答え Q113・`dae6bca`）`

### 観測の書き戻し

注入された5件（`01M6XN85N408CMMERA12QR1C3F`・`01M57SY06E1870RP6NQEXEF532`・`01KZKWJM1KTAFN22XK0WP0F96J`・`01KZVHE0KFDPXMY6EED80RN9ZR`・`01KYMRE1NC7XX6N66RQ0MGGHF1`）に1レコードずつ足した（followed 3・externally_verified 1・no_opportunity 1）。`本文: negative knowledge の採用`

### 残課題と行き先

- master の engine の拍動の照合の時刻の競合: 統括へ（起票の判断）。#562 の変更ではなく `lib/heartbeat-resolve.sh` の既存の不具合である。plan には書かない（plan の範囲の外のため）。
- master の `oe send` が、event bus への書き込みに失敗しても「delivery_held として残しました」と出す: 統括へ（起票の判断）。
- 入口の `CODEX_SANDBOX` の検知と決まりの文の1文の通し: マージのあとの CHECK-2 で、統括と owner が確かめる（手順は plan の CHECK-2 の節。作業層の手順書は `.oe/runbook-562-check2.md`）。2回目は子の `oe` が master の版だったので見えていない。
- I1 で未確認のまま残った2点（resume のあとの `CODEX_THREAD_ID` で自分を引けるか・pid の照合）: マージのあとの CHECK-2 で、統括が子に `oe lease bind` と `oe recover` を打たせて確かめる。確かめなければ、`oe recover` を Codex の子で初めて使うときに分かる。
- PR-2 の Copilot の1ラウンド: PR-1 の着地のあと、PR-2 を ready にしてから（plan の GATE 4 のとおり）。PR-1 の H10 の分への Copilot の再依頼は、owner の明示の指示があるときだけ行う運用なので、ここでは行わない。
- sandbox を安全の境界にする作り直し（子に tmux と共有の記録を渡さず親の側が報告を配る・子に別のリポジトリで commit させる・規則 `oe` を絞る）: 別の issue（統括が起票し、#549 とつなぐ）。`本文: Q119: sandbox を安全の境界にしない（2026-11-14）`
- plan の「やらない」の項目（`oe-selfcheck` と `oe-kick` の Codex 対応・どの作業を Codex の子に任せるか・子の報告をホスト側で配る案）: 追わない。必要になったら起票する。報告を配る案は #549 の材料として plan の DJ-3 に残っている。
- hook の信頼を `-c` の値の形で渡す形は試していない: 追わない（engine は hook の信頼を肩代わりしない）。
- 前に出した問いの決着: `question-562-2` の2枚のうち、規則 `oe` の広さ（`i562_oe_rule_scope`）は Q106 のまま `oe` で決まっている。`git commit` と commit の hook（`i562_git_commit_hooks`）は、H10 で `git commit` の規則をやめたのでカードとしては無くなったが、心配は消えていない。子は共通の `.git` に hook を書け、親が後で sandbox の外で commit するとその hook が走る。Claude の子と同じ状態で、owner は Q119 でそれを受け入れて文書に書くと決めた（decision の決定4）。`question-562-3` の2枚（Q116・Q117）は統括が取り下げ、Q118 にまとめ直した。どれも行き先は不要。`本文: 確かめの5点と H10（Q118・2026-11-13）`
- I1 で未確認だった symlink の規則の読み込み: 追わない。配布は通常のファイルの写しにした（DJ-3・設計SO の指摘1）ので、symlink を読むかどうかに依らない。`--add-dir` の効きは CHECK-2 の2回目で確かめた。`本文: CHECK-2 の2回目（2026-11-13 22:48・統括 gen25 が起こした）`

### 外部チェック（Step 4）

closure の4点（失敗の選択的な省略・残課題の行き先・揮発するパス・他の文書への書き戻し）を、書き手と別の会社のレーンで1回見た（`so-compare --cursor-only`・composer-2.5・指定・59秒）。判定は `refuted`（must 2・should 6）。must は、事実・失敗の節が本文の失敗の一部（設計SO の 18 件・Copilot の3件・PR-2 の SO の2件目など）を落としていたことと、前に出した問い2枚の決着を残課題に書いていなかったこと。should は、symlink の規則の行き先・plan の CHECK-2 の節への pointer・decision に H6（設定の鍵での指定も elevated と読む）が無いこと・拍動の競合を plan に書くか。plan に拍動の競合を書く1件だけを「plan の範囲の外」として採らず、ほかはすべて直した。出力は作業層（scratchpad の `so-closure-cursor/`）にあり、要点はここに書いた。

### status

stable。達成度: 達成（Codex の子が人の写しなしに commit と報告まで通った・CHECK-2 の2回目）。

### 形式メモ

チャネル骨格で、失敗（版の更新・`kill-pane`）と決定（H10）を分けて拾えた。印の無かった判断（H10・H8）は closure で拾った。皮（KPT）は使っていない。摩擦は、印の数が多く、1件ずつの判定に時間がかかったこと。

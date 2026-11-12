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

owner の問いに答える材料として、engine だけで担保する形を3つ整理して統括へ送った（`.oe/report-562-p3-q107.md`）。要点は、受領の印の説明を hub の `AGENTS.md` に置くのは「常時の原則」の層で、engine が独立したときは engine 自身が起こしのときに1回だけ伝える（`oe-delegate` が最初の1行に説明を添える）か、engine が配る hook が印のある prompt にだけ `additionalContext` で伝えるかで代えられる、ということである。


---
id: "01M7AJVJX1FAMSY3V1H54EZKHF"
title: "Codex の子には、権限と engine の約束ごとを起こす1行で持ち込み、owner の設定に頼るのは規則 oe の1行だけにする"
date: 2026-11-13
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/562"
    reason: "本 decision が記録する owner の判定（Q106・Q112・Q113・Q118・2026-11-13）の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-13-plan-562-codex-child.md"
    reason: "判定の材料。設計判断 DJ-2・DJ-3・DJ-4・DJ-13 と、ゲート3 のあとの変更 H8・H10"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-13-episode-562-codex-child.md"
    reason: "作業の記録。実機の確かめ C1〜C9・CHECK-2 の2回・権限の5点の確かめ"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/537"
    reason: "engine を独立したパッケージにしていく大目標。hub の AGENTS.md と owner の設定に頼らない形はその前提で選んだ"
tags: [orchestration, codex, delegation, sandbox, decision]
---

# Codex の子には、権限と engine の約束ごとを起こす1行で持ち込み、owner の設定に頼るのは規則 oe の1行だけにする

## 背景

engine（`oe delegate`）は Claude Code の子だけを起こしていた。#562 で Codex CLI（0.167）を子として起こせるようにしたとき、Codex の子が親へ報告を返す（`oe send --to-parent`）・commit する・engine の約束ごと（受領の印・問いの書き方）を守るのに要るものを、どこから渡すかが分かれ道になった。置き場の候補は、owner の Codex の設定（`~/.codex/config.toml`・`~/.codex/rules/`）、hub が配る `AGENTS.md`、委譲の書面（brief）、engine が子を起こす1行の4つである。

## 決定

### 決定1 書ける場所と tmux のソケットは、起こす1行でそのセッションにだけ渡す。規則は `oe` の1行だけ（Q118・Q106 を置き換えた）

- engine は起こす前に、本体の `.git`・worktree の gitdir・engine の状態の置き場を実体のパスで解決して `--add-dir` で渡し、tmux のソケットを `network_access`・`network_proxy`・`unix_sockets` の3つの `-c` で渡す。外への通信は閉じたままにする。
- owner の user 層に置く実行ポリシーの規則は `prefix_rule(pattern=["oe"], decision="allow")` の1行だけにする。`git push` と `gh` は開かない（子は commit まで）。
- `oe` の入口は、Codex の sandbox の中（`CODEX_SANDBOX`）で呼ばれたら何もせずに止まり、単独で打ち直すよう返す。
- 利用者が `--agent-arg` で承認や sandbox のモードを変える（`-s`・`-a`・bypass・`--yolo`、`-c sandbox_mode=…` などの設定の鍵の形も含む）と、engine は既定の `--approve-for-me` を外し、sandbox を外す指定は elevated（owner の承認のダイジェストが要る）と読む。設定の鍵の形を読み落として、ダイジェスト無しに sandbox を外した子を起こせた実装の漏れを PR-1 の Copilot が指した（plan の H6）。利用者の引数がネットワークの設定に触れていれば、engine はネットワークの指定を出さない（plan の H11）。
- 棄却した案:
  - 規則で外に出す（`oe` と `git commit` の2行・Q106 の最初の決定）。Codex は、つないだコマンドのすべての部分が allow に当たるときだけ sandbox の外で走らせ、モデルは普段からコマンドをつなぐので、CHECK-2 の1回目で `mkdir … && oe send …` が sandbox の中で走って届かなかった。`git add` も規則に無ければ sandbox の中で必ず失敗する。規則を足していく形は、つなぎ方の数だけ穴が残る。
  - 規則を増やす（`git add` を足す・Q117 の案）。owner が自分で開く Codex にも効き、つないだコマンドの穴は残る。
  - granular の承認（`sandbox_approval=true`）で、sandbox の失敗を自動の再試行に回す。sandbox の拒否として認識された失敗だけが対象で、モデルが要求を出さないと動かず、決定論にならない。
  - sandbox を外す（`--dangerously-bypass-approvals-and-sandbox`）。owner の承認のダイジェストが要る elevated の扱いで、既定にはしない。
- 選んだ理由: 起こす1行の権限は、その子のセッションにだけ効き、つないだコマンドでも効く（CHECK-2 の2回目で、つないだ `git add` と `git commit` が sandbox の中で通った）。`oe` だけを規則に残すのは、親の本人確認に使う `ps` が sandbox の中では起動できず、権限を足しても `--to-parent` が通らないためである。

### 決定2 engine の約束ごとは `-c developer_instructions` と brief の固定節で持ち込み、`AGENTS.md` には「書面に従う」の1行だけを置く（Q112・Q107 を置き換えた）

- 受領の印の扱い・報告の返し方・問いの書き方・`oe` を単独で打つことは、engine が起こす1行の `-c developer_instructions="…"` に入れる（`lib/agent.sh` の `OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS`）。compaction と resume のあとも残ることを実機で確かめた（C9）。
- hub の `canonical/codex/AGENTS.md` には「委譲の子として起こされたら書面の固定節に従う」の節だけを置き、engine の約束ごとは書かない。
- 棄却した案:
  - `AGENTS.md` に受領の印の説明を書く（Q107 の最初の案）。hub の配布物に engine の約束ごとが入り、engine を hub から切り出したときに置き場が無くなる。
  - hook（`UserPromptSubmit`）の `additionalContext` で印のある prompt にだけ伝える。owner が hook の信頼を登録するまで動かず、登録の前の子に約束ごとが届かない。
- 選んだ理由: 起こす1行は engine だけが持つ場所で、hub にも owner の設定にも頼らない。

### 決定3 フォルダの信頼の確認には、本体のリポジトリが信頼済みのときだけ engine が Enter を1回送る。信頼を `-c` で渡すことはしない（Q113・Q118）

- `oe delegate` は Codex の子を起こしたあと画面を読み、`Trust this folder?` が出ていれば、本体のリポジトリが `$CODEX_HOME/config.toml` で信頼済みのときだけ Enter を1回送る。`config.toml` は読むだけで書かない。それ以外は最初の1行も送らずに止まる。
- owner が本体のリポジトリを信頼していれば、worktree でも確認は出ない（0.167.2 の実機）ので、この分岐はほとんど通らない。分岐は Q113 の答えのまま残した。
- 信頼を `-c 'projects={"<path>"={trust_level="trusted"}}'` で渡せば確認は出ないが、owner の信頼の判断を engine が肩代わりすることになるので採らない（Q118）。
- 棄却した案: `config.toml` に engine が信頼を書く（owner の設定を engine が書き換える）。何もせず人が答える（最初の1行が確認の画面に流れて消える）。

## 当時の前提（偽になったら見直す）

- Codex CLI 0.167.2 の sandbox（macOS の seatbelt）が、`--add-dir` で足した場所への書き込みを、`.git` の既定の保護より優先して許すこと。`network_proxy` の `unix_sockets` で、外への通信を閉じたまま特定のソケットだけを開けること。Codex の版が上がったら、CHECK-2 の手順で確かめ直す。
- sandbox の中で `ps` が起動できないこと。起動できるようになれば、規則 `oe` の1行も要らなくなりうる。
- 親の本人確認を `ps`（pid と開始時刻）で行っていること。確かめ方が変われば、決定1 の「`oe` だけを外に出す」理由は見直す。
- Codex の `-c` の鍵が `.` で単純に分けられること（引用符で囲んだ鍵が効かない）。直れば、`-c` で渡せるものの範囲が変わる。

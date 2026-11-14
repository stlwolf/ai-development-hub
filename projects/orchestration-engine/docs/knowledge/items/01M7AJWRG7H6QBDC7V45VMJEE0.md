---
id: "01M7AJWRG7H6QBDC7V45VMJEE0"
type: knowledge
status: active
date: 2026-11-13
trigger: "Codex CLI の起動の -c / --config で、鍵に引用符で囲んだ部分を含む設定を渡すとき（projects.\"<パス>\".trust_level・hooks.state.\"<hooks.json のパス>:…\".trusted_hash など）。または、その形で渡して効かなかった結果から「-c では渡せない」と結論しそうなとき"
prediction: "TOML の書き方どおりに -c 'projects.\"/abs/path\".trust_level=\"trusted\"' と書くと、Codex は鍵を . で単純に分けるので、引用符が鍵の文字として残り（鍵が \"/abs/path\"）、パスと一致しない。値は TOML として受け付けられ誤りも出ないので、効かなかった理由が見えず、「-c ではこの設定を渡せない」と誤って結論する。パスに . があれば鍵がさらに割れる"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-11-13-episode-562-codex-child.md"
landing: nl
observations: []
---

Codex（0.167）の `-c` は、鍵を `path.split('.')` で分ける（`config/src/overrides.rs:22`）。引用符で囲んだ鍵を含む設定は、表を値として渡す: `-c 'projects={"/abs/path"={trust_level="trusted"}}'`。こうすれば鍵に引用符も `.` の分割も入らない（0.167.2 の実機でフォルダの信頼の確認が出なくなった）。

#562 では、I1 で前者の形を試して確認の画面が出たため「`-c` ではフォルダの信頼を渡せない」と結論し、その結論の上で engine が画面に Enter を送る案（H1・H8）が組み立てられた。統括が Codex 自身に調べさせた答えも、同じ前者の形を「渡せる」と書いていて、実機で確かめるまで食い違いの原因が分からなかった。パスは実体のパス（`pwd -P`）で書く。鍵が `/tmp/…` の形だと、cwd が実体（`/private/tmp/…`）のとき一致しなかった。

---
id: "01M7AJWRFGR2KDN87B7YDQ787V"
type: knowledge
status: active
date: 2026-11-13
trigger: "試しのペインを tmux で作り、あとで閉じる・読む・送るスクリプトを書くとき（split-window や new-window の出力のペイン番号を変数に受けて、kill-pane・send-keys・capture-pane の -t に渡すとき）"
prediction: "ペインを作るコマンドが失敗して（no space for new pane など）変数が空になっても、続く kill-pane -t \"\" や send-keys -t \"\" は誤りにならず、tmux の「いまのペイン」を指す。試しのペインのつもりで、自分のペインや統括のペインを閉じたり、そこへ文を送ったりする。失敗したスクリプト自身も道連れで消えるので、原因が記録に残りにくい"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-11-13-episode-562-codex-child.md"
landing: guard-candidate
observations: []
---

tmux の `-t` は、空の文字列を「宛先なし」として誤りにせず、いまのペインに読み替える。宛先を変数で受けるときは、打つ前に次の3つを確かめる。値が `%数字` の形であること。自分（`$TMUX_PANE`）と統括のペインでないこと。`tmux list-panes -a` に実在すること。試しのペインは自分のウィンドウを割らず、`tmux new-window -d -P -F '#{pane_id}'` で別のウィンドウに作る（割る場所が足りずに失敗することもなくなる）。

#562 では、Codex の信頼の画面を確かめるスクリプトの `split-window` が `no space for new pane` で失敗し、空の変数で打った `kill-pane` が T0 で統括のペインを、T1 で自分のペインを閉じた。統括は別のペインで復帰し、子は `oe recover` で lease を張り直した。

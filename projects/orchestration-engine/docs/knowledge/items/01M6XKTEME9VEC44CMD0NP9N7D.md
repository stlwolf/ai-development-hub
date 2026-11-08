---
id: "01M6XKTEME9VEC44CMD0NP9N7D"
type: knowledge
status: active
date: 2026-11-08
trigger: "engine の verb に、~/.claude/state の下へ書く新しい記録を足すとき。とくにその verb を呼ぶ既存のテストがある場合"
prediction: "新しい記録の置き場の env（テスト用の差し替えの口）を足しても、既存のテストはその env を知らない。HOME を本物のまま、session_id や pid を偽の値にして verb を走らせる既存のテストは、新しい記録を本物の置き場へ書く。テストは通るので気づかず、本物の記録に偽の session_id の行が残る"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-11-08-episode-576-supervisor-session-name.md"
landing: nl
observations: []
exclusions:
  - "既存のテストがすべて HOME を一時ディレクトリにしている場合"
  - "新しい記録を書く条件に、テストが外している環境変数（CLAUDE_CODE_SESSION_ID など）が必要で、どのテストもそれを設定しない場合"
---

**~/.claude/state に書く記録を verb に足したら、その verb を呼ぶ既存のテストを grep し、HOME を一時ディレクトリにしていないものに新しい置き場の env を足す。**

#576 で踏みかけた。`oe-handoff take` にセッション名の要求を書く処理を足したところ、`test_handoff_take.sh` と `test_handoff_retire.sh` は HOME を本物のままにし、`CLAUDE_CODE_SESSION_ID=sid-succ` を設定して take を走らせていた。lease の置き場（`OE_LEASE_DIR`）だけは #577 で一時ディレクトリに向けてあったが、新しい置き場（`OE_SESSION_TITLE_DIR`）はどのテストも知らない。そのままだと、テストを回すたびに本物の `~/.claude/state/session-title/sid_succ.json` ができていた。

**非自明なのは、前の単位で同じ穴を塞いだ形跡が、次の単位を安心させること。** テストの頭に「本物の置き場へ書かない」とコメントがあり、lease の env も外してあるので、隔離は済んでいるように見える。実際に隔離されているのは、そのコメントを書いた時点の置き場だけである。

次にどう行動を変えるか。新しい置き場の env を足したら、`grep -l '<verb の名前>' tests/*.sh` で呼び出し元のテストを列挙し、それぞれについて (1) HOME を一時ディレクトリにしているか (2) そうでなければ verb が書く条件の環境変数を設定しているか、を見る。(2) に当たるテストには新しい env の1行を足し、全体を回したあとに本物の置き場が作られていないことを `ls` で確かめる。

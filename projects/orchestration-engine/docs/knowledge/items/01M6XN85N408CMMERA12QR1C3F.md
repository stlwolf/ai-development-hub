---
id: "01M6XN85N408CMMERA12QR1C3F"
type: knowledge
status: active
date: 2026-11-08
trigger: "tmux のペインで claude を起こすコマンドを書くとき（drill やテストの足場・新しい verb・tmux new-window や split-window に渡す1行）。とくに、環境の準備と claude の起動を1つの文字列にまとめて渡すとき"
prediction: "「cd … && . env && claude …; exec bash」のように、非対話の bash -c の中で claude を子として起こすと、claude は bash と同じプロセスグループに入り、ペインの端末の前面のプロセスは bash になる。前面のプロセスの pid と開始時刻で本人を確かめる仕組み（lease の binding・送る前の確かめ・retire の判定・oe-recover の自分の確かめ）は claude を見つけられず、binding できない・送れない・止まる"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-11-08-episode-355-supervisor-recovery.md"
landing: nl
observations:
  - date: 2026-11-09
    ref: "#577"
    state: no_opportunity
    note: "PR-6 では tmux のペインで claude を起こすコマンドを書かなかった。教訓の中身は decision #577 の帰結に、D6 と retire の本人確認の前提として書き足した（適用ではなく記述）"
  - date: 2026-11-10
    ref: "#605"
    state: followed
    note: "入口 bin/oe は verb を exec で呼び、プロセスを1段も挟まない形にした。T-3 で verb の pid が呼び出し元のシェルの pid と同じであることを確かめ、T-9 で oe-recover と oe-handoff の本人確認を入口越しに回した（tests/test_oe_entry.sh・tests/test_oe_entry_identity.sh）"
exclusions:
  - "人が対話のシェルで claude を打つ場合（シェルがジョブ制御で claude を別のプロセスグループに置くので、前面のプロセスは claude になる）"
  - "claude を exec で起こす場合（ペインの最初のプロセスも前面のプロセスも claude になる）"
---

**tmux のペインに渡す1行で claude を起こすときは、`exec claude …` の形にする。非対話の `bash -c` の中で claude を子として起こすと、ペインの前面のプロセスは bash になり、lease の本人確認が claude を見つけられない。**

#355 のクラッシュ drill で、使い捨ての統括と子を `tmux new-window` に「`cd … && . env.sh && OE_LEASE_ID=… claude …; exec bash`」を渡して立てた。2つの claude を lease の binding に結び付ける段で、`oe_lease_bind` が rc 6（コマンドが claude でない）を返して止まった。統括が `bash -x` で確かめると、ペインの前面のプロセス（`ps -t <tty> -o pid,tpgid` で pid と tpgid が一致する行）が、その1行を走らせている bash だった。

非対話の bash はジョブ制御を持たないので、子として起こした claude を自分と同じプロセスグループに入れる。前面のプロセスグループの長は bash のままになる。対話のシェルで人が claude を打つと、シェルがジョブ制御で claude を別のプロセスグループに置くので、この問題は起きない。`oe-delegate` と `oe-handoff start` は `exec` の形で claude を起こしているので当たらない。

## なぜ非自明か

画面には claude が動いて見え、`ps` にも claude のプロセスがある。前面のプロセスが bash であることは、tpgid を見ないと分からない。手で打つと起きないので、手元で試したときには再現しない。足場の文字列は、環境を読み込んでから起こす、終わったらシェルに戻す、という便利な形に寄りやすく、その形がちょうどこの問題を作る。

## 次にどうするか

- tmux に渡す1行で claude を起こすときは、最後を `exec claude …` にする（`VAR=値 exec claude …` の形でも環境変数は渡る）。終わったあとにシェルを残したい理由があっても、本人確認を使う場面では残さない。
- 起こしたあとに、`ps -t <tty> -o pid,tpgid,comm` で pid と tpgid が一致する行が claude であることを確かめてから、lease に結び付ける。
- 本人確認が rc 6（claude でない）で止まったら、まず前面のプロセスが wrapper のシェルになっていないかを疑う。

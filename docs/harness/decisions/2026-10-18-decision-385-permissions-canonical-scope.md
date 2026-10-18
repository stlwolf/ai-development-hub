---
id: "01M57SGRBRR0AD3CXWEF12K54H"
title: "許可規則の allow は hub の正本に置かない — 危ない形は sync --check の警告で知らせ、実行の直前に止める hook は別に決める（Claude Code と Codex）"
date: 2026-10-19
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/385"
    reason: "本 decision が記録する owner の判定（2026-10-18〜19）の issue"
  - type: derived_from
    ref: "docs/harness/discussions/2026-10-18-discussion-385-permissions-canonical-scope.md"
    reason: "判定の材料。比べる基準・本体の仕様の表（C1〜C25・X1〜X12）・試験（T0〜T5・R1〜R3）・論点ごとの選択肢と、ゲート1・2 の採否。本 decision は判定と理由に絞り、細部はこちらを指す"
  - type: reference
    ref: "docs/harness/episodes/2026-10-18-episode-385-permissions-canonical-scope.md"
    reason: "上流の断定の裏取り、#359 の記録の探索、試験の手順、SO の指摘と採否の経緯"
  - type: design_context
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の設定適用。union-array を permissions.allow を想定して足し、permissions は宣言に入れないと書いたが、理由は書かなかった"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/460"
    reason: "sync --check に危ない形の許可規則の警告を足す（Claude Code と Codex）。本 decision の決定3・4 の実装"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/461"
    reason: "危ない形のコマンドを実行の直前に確認へ回す hook を3つのツールで決める。本 decision の決定5 の方向を受けて、採否と作りを決める"
tags: [harness, settings, permissions, codex, decision]
---

# 許可規則の allow は hub の正本に置かない — 危ない形は警告で知らせ、実行の直前に止める hook は別に決める

## コンテキスト

2026-09-10、Claude Code 本体が起動時に、hub の `.claude/settings.local.json` にある Bash の allow 規則4件を警告し、owner が手で消した。4件は、`*` が末尾でない位置にあり、そこに挿し込まれた任意のオプションまで確認なしで通す形だった。許可規則は hub の正本の外にあり、`sync.sh --check` にも掛からないので、危ない形が入っても hub の仕組みでは見つからない。#385 は、許可規則を hub の正本に含めるかを、5つの論点（層の切り分け・書き込みの衝突・検査だけ先に入れる案・別リポジトリへの届き方・本体の検査で足りるか）について決める issue である。

#359 の宣言駆動の設定適用は、配列を扱う `union-array` を `permissions.allow` を想定して作ったうえで、「`permissions` は今回の宣言には入れない」と書いた。外した理由は、plan・episode・issue のコメント・PR #370・#372・#374 の本文とレビューのどこにも書かれていない。

材料を集めると、上流の断定と合わない事実が出た。本体の警告が入ったのは issue 本文の書く 2.1.265 ではなく 2.1.246 だった（CHANGELOG と公式の errors のページ）。また、警告は `*` の位置しか見ず、末尾の `*` の広い規則（`Bash(git:*)` など）には出ない。hub の手元の層には、警告を受けて4件を消したあとも、そうした広い規則が少なくとも5件残っていた。

2026-10-19、owner の判断で Codex もこの判定に含めた。owner の観察は「Codex は、壊す操作は無いが、想定していなかった操作をしたことにあとで気づく場面が増えている」である。Codex の allow の規則は、sandbox の外で確認なしに動く意味を持ち、永続の承認を選ぶとユーザー層の `~/.codex/rules/default.rules` に書かれる。

## 決定

owner は判定ページ（統括が作った claude.ai の artifact・2026-10-18〜19）で、discussion の推奨どおり次の8件を判定した（owner の言葉は「とりあえず推奨で問題なさそう」）。Codex を含めることは、そのあとに owner が決めた。

1. **allow は hub の正本に置かない（論点1・1B）。** `canonical/claude/settings.harness.json` に `permissions` の項目は足さない。Codex の `~/.codex/rules/default.rules` も hub の正本にしない。
2. **本体の検査だけでは足りないと認める（論点5）。** Claude Code については、本体の警告が広い規則に出ないことを試して確かめたので「足りない」と判定する。Codex については、広い規則を警告する仕組みを文書から確認できなかったので、「本体だけで足りるとする根拠が無いので、予防として hub の検査を足す」と判定する。
3. **`sync.sh --check` に許可規則の形の検査を足す（論点3・3A と 3B）。** Claude Code では、hub の3ファイル（手元の層・共有の層・ユーザー層）の規則について、Bash の全体を許す形（裸の `Bash`・`Bash(*)`）・`*` が末尾でない形・任意の実行や書き込みのできるプログラムに付いた末尾の `*` の前方一致の3種を見る。Codex では、`~/.codex/rules/*.rules` の短い前方一致の allow（たとえば `["git","push"]`）を見る。ほかのリポジトリの手元の層は、明示したときだけ数え、出力は手元の端末だけにする。実装は #460。
4. **検査は警告にとどめ、終了コードを赤にしない（論点3）。** 出た警告は、sync を回した統括が owner への報告に含め、直すかは owner が決める。
5. **実行の直前に確認へ回す仕組みは別の issue（#461）にし、本命を PreToolUse hook にする（論点4・4B）。** ここで決めたのは方向だけで、採るかどうか・3つのツールでの作り・代わりの方式は #461 で決める。Codex のいまの PreToolUse は `"ask"` に対応していないので、Codex で「確認へ回す」という目的をどう果たすかも #461 の論点になる（結果の節）。
6. **狭める側の規則（ask・deny、Codex の `prompt`・`forbidden`）を配ることになったら、外した項目は知らせて手で消す（論点2・2B'）。** 自動では消さない。出どころが分からない項目は残す。Codex では `default.rules` と別のファイルを同じ `rules/` に置く。
7. **検査と hook が入るまで、残っている広い規則はそのままにする。** hub と別のリポジトリの手元の層、Codex の `default.rules` の広い規則は、#460 の警告が出てから owner が個別に決める。Bash の sandbox（5E・5E'）は、試す場所を作れたら検討する候補として残す。
8. **hub の `.claude/settings.local.json` の top-level の `defaultMode` を消す。** 統括が 2026-10-18 に消した。消す前の写しと比べて、変わったのはこの1キーだけだった。このキーは公式の `permissions.defaultMode` ではなく、しかも `auto` は手元の層からは効かない。

正本に含めるものと、その形は次のとおりである。

- **allow（Claude Code の `permissions.allow` と、Codex の `prefix_rule` の `allow`）は、hub の正本に含めない**（決定1）。
- **狭める側の規則（ask・deny、Codex の `prompt`・`forbidden`）を正本に含めるかは、決めていない。** 配ることになった場合の外し方だけを決めた（決定6）。
- **hub の正本に加わることが決まったのは、#460 の検査（危ない形の一覧と、それを当てる手順）である。** #461 の hook は、#461 で採ると決まれば加わる。どちらも hub がいま持つ経路（`sync.sh --check` と、3ツールへ配る `canonical/hooks/`）に載せ、新しい配布の経路は作らない。

## 根拠

- **allow を正本に置かない理由（今回初めて書く理由）。** ユーザー層に置いた allow は、この機種のすべてのリポジトリで確認なしになる（公式の settings のページ）。hub の手元の層で、どこでも同じ形の前方一致の allow 24 件のうち、読み取りだけのものは3件で、そのうち `ls` は本体が最初から通す。残りの 21 件は書き込みか任意の実行ができる（`gh pr *` は `gh pr merge` を、`gh api *` は POST を含む）。読み取りだけに選び直すことはできるが、得るものはまだ測れていない。owner は auto モードで動かしており、本体が読み取りと見なす操作は、規則が無くても確認なしで通る（サーバー側の判定が有効なセッションでは、読み取りのシェルのコマンドもその判定を待つ）。一方、選び直しの誤りの害はすべてのリポジトリに及ぶ。本体の `/doctor` も同じ理由で、提案する allow をユーザー層には書かない。加えて `union-array` は足すだけで、配った項目を個別に消せない。Codex では、allow の規則は sandbox の外で確認なしに動き、`default.rules` は Codex 自身が永続の承認のたびに書くファイルなので、hub が持つと取り合いになり、業務のリポジトリに固有の規則も正本に入る。
- **#359 の判断との関係。** #359 が理由を書かずに外した判断は、今回の理由で裏付けられる。記録から読める当時の事情（ユーザー層に `permissions` が無かったこと、hub の許可規則が配布先と別の手元の層にあったこと）はいまも成り立つが、理由として書かれたものではないので推測にとどめる。
- **本体の検査で足りないと判定した理由。** Claude Code では、`Bash(git:*)` が `git -c <設定> commit …` を確認なしで通し、起動時の警告も出ないことを、使い捨てのリポジトリで `claude -p --permission-mode dontAsk` を回して確かめた（discussion の 3.3 節の T1・T4・T5）。`-c` で git が任意のプログラムを動かせることは公式の文書の文による。Codex では、`default.rules` の2語の git の規則が `git push --force`・`git fetch --upload-pack=…`・`git rebase -i`・`git commit --no-verify` を allow と判定する（`codex execpolicy check`・実行はしない）。
- **検査を警告にとどめる理由。** 対象のファイルは hub の正本ではなく、owner と各ツールが書く手元のファイルである。#359 の HG-D でも drift は報告だけと決め、綴りの検査も警告にしている。赤にすると、owner が規則を直すまで `--check` が赤のままになり、ほかの差分が見えにくくなる。`--check` は読むだけで、赤にしても適用は止まらない。
- **hook を本命にする理由**（方向として。採否は #461）。ユーザー層の hook は、どのファイルのどの規則が許したかに関係なく、実行の直前にコマンドを見られる。Claude Code では、hook が `"ask"` を返すと同じ allow があっても確認に回った（3.3 節の T2）。Codex では、allow の規則に当たる `git push --force` を、いま配っている `block-force-push.sh` の deny が止めた（下記）。hub はすでに同じ経路で3ツールへ hook を配っている。規則の前方一致（ユーザー層の ask）は軽い代わりになるが、`git -C . -c x diff` のような並べ替えを取りこぼす。
- **外した項目を手で消す理由。** 自動で個別に消すには、配った項目と owner が自分で足した同じ文字列の項目を見分ける手段が要る。ask・deny を消すとその分だけ許可が広がる向きに働くので、勝手に消さない方が安全である。

### Codex での試験の結果（C2）

配っている `block-force-push.sh` が、allow の規則に当たった `git push --force` を止めるかを、`codex exec`（codex-cli 0.163.0・ユーザー層の設定を読む形・`-s workspace-write`）で試した。push 先は使い捨てのリポジトリの中の bare リポジトリで、本物のリポジトリと GitHub には触れていない。判定は push 先の ref と hook の記録と Codex の stderr の記録で行い、モデルの返答では判定していない。

- hook を有効にした `git push --force` は、push 先が動かず、hook の deny が記録され、stderr に「Command blocked by PreToolUse hook」が出た。
- hook を有効にした `--force-with-lease` は push 先が動き、hook の allow が記録された（push が通る場の対照）。
- hook を切った `git push --force` は push 先が動き、記録は無かった（止めたのが hook であることの対照）。

したがって、allow の規則に当たるコマンドを、hub の hook の deny が Codex でも止めた。モデルは最後の返答で、止めた仕組みを「Automatic approval review」と取り違えていた。

この試験が示さないことは次のとおりで、#461 に申し送る。

- 対話のセッション（承認 `on-request`）での振る舞い。試したのは `codex exec` だけである。
- push が通るのに allow の規則が要ったかと、sandbox の外で動いたか。push 先は作業ディレクトリの中にあり、`workspace-write` の sandbox の中でも書ける。したがって、sandbox の外で動く allow と hook の順序までは確かめていない。
- `git push origin +main` のような別の書き方の強制 push や、`git fetch --upload-pack`・`git rebase -i` のような allow に当たるほかの形を、hub の hook が止めるか。

## 結果

- hub の宣言（`settings.harness.json`）は変わらない。許可規則は、これまでどおり各ツールと owner が手元とユーザー層に書く。
- #460 で、`sync.sh --check` が Claude Code の3種の形と Codex の短い前方一致の allow を警告するようになる。警告は統括が owner への報告に含める。いまの hub の手元の層では、少なくとも5件（`Bash(git:*)`・`Bash(curl:*)`・`Bash(gh api:*)`・`Bash(python3:*)`・`Bash(bash -c ':*)`）が出るはずである。Codex の `default.rules` では2語の git の4件が出るはずである。Codex の検査に `codex execpolicy check` を使うなら、この道具は渡された引数の並びをそのまま当てるだけで、実行のときの `bash -lc` の分け方は再現しないことに注意する（discussion の論点3）。
- #461 で、実行の直前に確認へ回す hook を3つのツールで決める。決めるときの前提として次を申し送る。
  - **Codex のいまの PreToolUse は `"ask"` に対応していない。** 返すと hook の失敗として扱われ、コマンドはそのまま続く（Codex の公式の hooks の文書）。#461 の題の「確認へ回す」は、Codex の PreToolUse では、そのままの形では果たせない。PreToolUse でその呼び出しを止めるなら deny か exit 2 になり、正当な使い方をその場で通す道が無いので、誤って止める例の重さが Claude Code より大きい。確認という目的を Codex でどう果たすか（ほかの仕組みを含む）と、採るかどうかは #461 で決める。
  - **Codex の hook は、新しく足したものと定義を変えたものは、owner が `/hooks` で信頼し直すまで動かない**（公式の hooks の文書）。起動時に警告は出るが、そのあいだその守りは抜ける。信頼し直しが要るのは変えた項目だけで、ほかの項目の信頼は残る、という読みは `openai/codex` の main のソースによるもので、手元の版では確かめていない。
  - **Codex では、すでに動いている実行のセッションへ `write_stdin` で送った入力に PreToolUse が動き直さない。**
  - Claude Code では、ユーザー層の hook はリポジトリの設定の `disableAllHooks: true` で切られ、入れた mod は managed でない hook の止めを置き換えられる。hook はどのツールでも、破れない境界ではなく、通常の運用での守りである。
  - Cursor の hook が確認を求められるか、既存の規則より先に効くかは確かめていない。
  - discussion の 3.3 節（T0〜T5）と 3.5 節（R1〜R3）の試験は、本体を上げたときに前提が変わっていないかを見る回帰の試験として使える。
- 検査と hook が入るまでのあいだ、残っている広い規則による危険は owner が受け入れる（決定7）。
- 本 decision は、#385 の枝の PR に discussion・episode と一緒に入り、マージ前に着地する。

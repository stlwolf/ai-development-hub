---
id: "01M5C1J5BTMJTMPKK12W98EF39"
title: "#407 oe の verb の許可規則を hub の宣言で配るかを決める（判定の材料と decision）"
date: 2026-10-20
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/407"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/407#issuecomment-6285147692"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）。この単位はこれを前提にする"
  - type: relates_to
    ref: "docs/harness/discussions/2026-10-20-discussion-407-oe-allow-rules-distribution.md"
    reason: "この単位の成果物の1つ目。owner が判定するための材料"
  - type: design_context
    ref: "docs/harness/decisions/2026-10-18-decision-385-permissions-canonical-scope.md"
    reason: "「allow は hub の正本に置かない」と決めた decision。この issue はその例外を問う"
  - type: design_context
    ref: "docs/harness/discussions/2026-10-18-discussion-385-permissions-canonical-scope.md"
    reason: "比べる基準 K1〜K3、本体の仕様の表（C1〜C25）、論点1 の 1B と論点2 の 2B"
tags: [harness, settings, permissions, orchestration-engine, judgment-materials]
knowledge_observations:
  - "01KZK26GQZ39WCFV5MYKQMRHWE"
  - "01KYMRE1NC7XX6N66RQ0MGGHF1"
  - "01M57SY07J7C076F3765J55PEH"
---

# #407 oe の verb の許可規則を hub の宣言で配るかを決める

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

2026-10-06、統括のセッションが子のセッションへ `oe-send` で owner の承認を中継したとき、Claude Code の auto モードの判定器が、その送信そのものを「Protected-Scope IaC Apply」として止めた。子が IaC の変更を適用する段の直前だった。回避は、owner が子のペインに直接打つか、リポジトリごとの手元の設定に `oe-*` の allow 規則を手で足すかの2つで、どちらも hub は配っていない。#407 は、`oe-*` の allow 規則を hub の宣言で配るかを決める issue である。ただし #385（2026-10-19 マージ）が「allow は hub の正本に置かない」と決めたので、この単位では「`oe-*` をその決定の例外として配るか」を問う形にする。

## この単位の入力

- brief: 統括（cockpit 19代目）が 2026-10-20 に発行した `.oe/brief-407-oe-allow-rules-distribution.md`（作業層・消える）。この単位は実装をしない。最初の終端は D3（discussion を報告して止まる）、委譲全体の終端は D6（PR を作って報告する）。マージ・worktree の掃除・issue の close はしない。baseline は master `02a6c29`。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/407#issuecomment-6285147692 （深掘りなし）。
- scope: 6つの論点（#385 の例外として配るか・消す手段・規則の形・対象の verb と分け方・許可の境界・判定器の仕様の残りの調査）について、owner が判定できる材料を discussion に書く。比べる基準は #385 の K1〜K3。コードと設定ファイルは変えない。`~/.claude/settings.json` と hub の `.claude/settings.local.json` は読むだけにする。公開の文書に別のリポジトリの名前や中身を書かない。
- SO: 設計 weak・実装 weak。discussion に Codex 1レーン（ゲート2）、decision に Codex 1レーン（ゲート4）と Copilot 1ラウンド。Codex が返らなければ Cursor のレーンに1回だけ切り替えてよい。ゼロベースの代替探索（ゲート1）は discussion の中で通す。
- 注入された negative knowledge: 3件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### D1: worktree・確定版の照合・宛先の確認（2026-10-20）

- worktree `docs/#407_oe_allow_rules_distribution` を `wt switch --create --base master` で作った。起点は `02a6c29` で、`git fetch` のあとの `origin/master` と同じである。
- 認識合わせは `issue-intake` の 1-2 の手順で確かめた。最後の行は `confirmed`・見出し4つで、URL は brief の「認識合わせ:」欄と文字列として一致した。確定版を前提にし、自分では通し直さない。
- 報告の宛先の統括は `oe-tree` に root `cockpit` として生きて出ていた。委譲子の自分はその子として出ており、`$PARENT_TMUX_PANE` も同じ統括を指していた。
- 読んだもの: #407 の本文と確定版。#385 の decision と discussion と episode の構成。#359 の plan の DJ-3。#262 の本文。`canonical/claude/settings.harness.json`・`settings.values.json`。`scripts/sync/apply-claude-settings.sh` と `check-claude-settings.sh`（op ごとの適用と判定）。`scripts/sync/sync-bin.sh` の配布対象。engine の `bin/oe-send`・`bin/oe-delegate`・`lib/delegate-send.sh`・`lib/delegate-registry.sh`。Claude Code の公式の文書（permissions・permission-modes・auto-mode-config・hooks・settings）と CHANGELOG。`claude auto-mode defaults` の出力（本体 2.1.302 と 2.1.304）。手元の層とユーザー層の設定（読むだけ）。

### D1: #385 が allow を置かないとした理由を、`oe-*` に当て直した（2026-10-20）

knowledge item `01KZK26GQZ39WCFV5MYKQMRHWE` の教訓どおり、欠落を埋める前に外した判断の一次記録（#385 の decision の「根拠」と discussion の論点1・2）を読み、理由ごとに `oe-*` に当てはまるかを見た。

- 「ユーザー層の allow はすべてのリポジトリで確認なしになる」: `oe-*` は hub が配る道具で、どのリポジトリでも統括と子が使うので、全リポジトリに届くこと自体は意図に合う。この理由は `oe-*` では弱まる。
- 「共通の形の allow のほとんどが書き込みか任意の実行をできる」: `oe-send` は、生きているどの tmux のペインにも1行と Enter を送れる。宛先がシェルなら任意のコマンドになり、宛先が自分のペインなら判定器の「Tmux Self Drive」の検査を飛ばす。`oe-delegate` は `--claude-arg` で権限を切った子を起動できる。この理由は `oe-send` と `oe-delegate` では強く当てはまる。
- 「`union-array` は足すだけで消せない」: そのまま当てはまる。#385 は、消す手段（2B）が無いまま allow を配ってはいけないと決めている。
- 「本体の `/doctor` も allow をユーザー層に書かない」: そのまま当てはまる。

昇格の印: `oe-send` の allow は、判定器の Tmux Self Drive の検査と、中継された承認を owner の発話と照らす唯一の検査を、まとめて飛ばす

### D1: 上流の断定を一次情報と会話記録に当てた（2026-10-20）

knowledge item `01KYMRE1NC7XX6N66RQ0MGGHF1` の教訓どおり、issue 本文の断定を書き写す前に裏を取った。

- 「宣言は3項目」は古い。いまは4項目（`hooks`・`statusLine`・`disableAgentView`・`idleCompaction`）である。確定版もそう書いている。
- 「`~/.claude/settings.json` に `permissions` キーが無い」は、いまも成り立つ。ただし `autoMode.environment` がユーザー層にあり、hub は管理していない。
- 「hub に `oe-delegate` の規則が1件、別のリポジトリに登記と送信の verb の規則が2件」は、いまも成り立つ。3件とも hub の master の checkout の engine の `bin/` の絶対パスで書かれている。
- 「2回以降は2回とも止まった」「止まったペインは 2.1.289」: この機種の会話記録（`~/.claude/projects/` の jsonl・10月4日以降）で、判定器の拒否の結果を `tool_use_id` で呼び出しのコマンドに結び付けて数えた。`oe-send` を含む呼び出しが「Protected-Scope IaC Apply」で止まったのは2件で、2件とも本体 2.1.289 だった。そのあと 10月20日までに `oe-send` の拒否は無い。同じ理由の拒否は 2.1.292 と 2.1.296 にもあるが、どちらも `oe-send` を含まない呼び出しだった。したがって「2.1.289 で何かが変わった」とは言えない。「通ったペインは 2.1.285 と 2.1.286」は、通った記録を拾っていないので確かめていない。
- 同じ期間（10月1日以降）の Bash の呼び出しで、コマンドの先頭に置かれた `oe-send` は 779 件あった。止まったのはそのうち2件である。

### D1: 公式の文書と本体の出力で、判定器の仕様を確かめた（2026-10-20）

- `claude auto-mode defaults` を本体 2.1.302 と 2.1.304 で出し、2つが同じであることを確かめた。「Protected-Scope IaC Apply」の定義は「保護された IaC の範囲に当たる資源への apply・destroy は、利用者が具体的な変更を名指す必要がある」で、範囲の既定は「IAM・RBAC・ネットワーク・quota・node-pool と、名前に prod を含むもの」である。2.1.289 の本体は手元に無く、比べられなかった。
- 公式の permission-modes の文書（2.1.304 の時点）で、allow・ask・deny の規則に当たる操作は判定器より先に決まる、という #385 の C15 が変わっていないことを確かめた。
- 判定器は、委譲した別の agent の出力（`<teammate-message>`）を利用者の同意として扱わない、と既定の規則に書いてある。一方、`oe-send` の文は子の入力欄に打ち込まれるので、子のセッションでは利用者の発話として届く。この子のセッション自身が、統括の `oe-send` の文を利用者の発話として受け取っている。
- CHANGELOG の 2.1.286〜2.1.304 に、中継・tmux・この規則を名指す項目は無かった。2.1.281 で「拒否は結果そのものを覆う」と Claude に伝える文に変わり、2.1.293 でそれが取り消されている。issue 本文の「同じ結果を後の turn で追わない」という拒否の文は、2.1.281〜2.1.292 のあいだの文と合う。

### D1: 規則の形がどの呼び方に当たるかを試した（2026-10-20）

使い捨てのリポジトリで、`claude -p --model haiku --setting-sources project --permission-mode dontAsk --tools Bash --settings '<その場の JSON>'` を回し、副作用の無い `oe-tree --help` で試した（本体 2.1.304）。打たれたコマンドは stream-json の記録で確かめた。記録は master の作業層 `tmp/407-oe-allow-rules-distribution/407-perm-test/` にある。

- master の絶対パスの規則は、絶対パスそのもの・`"$HOME/…"`・同じコマンドの中で代入した変数（`B=…; "$B/oe-tree"`）に当たった。規則の無い対照ではどれも拒否された。
- 同じ規則は、worktree の絶対パスと、コマンド置換で引いた変数（`oe_bin="$(dirname "$(readlink …)")"; "$oe_bin/oe-tree"`）には当たらなかった。後者は `doc-flow-guardrail` の「verb 解決規約」が書く呼び方である。
- `~/bin/oe-tree` の規則は、`~/bin/oe-tree` と書いたときだけ当たり、展開した絶対パスには当たらなかった。

文書からは「変数の形には当たらない」と読んでいたが、試すと当たった。確かめる前の読みを discussion に書かずに済んだ。

### D1: 判定器が中継を止める場面を再現しようとしたが、再現できなかった（2026-10-20）

使い捨てのリポジトリに、引数をファイルに書くだけの偽の `oe-send` を置き、`claude -p --model sonnet --permission-mode auto` で、本番の IaC の変更の実行を子へ中継させた（本体 2.1.304・3回）。owner が中継の文を指定した回、曖昧に「進めて」と言った回、CLAUDE.md に「この口座は本番」と書いて Claude に中継の文を組ませた回のどれも、判定器は止めなかった。止まるかどうかは文脈に強く依るので、この試験からは、止める条件も、例外の文や hook で止まらなくなるかも言えない。記録は master の作業層 `tmp/407-oe-allow-rules-distribution/` にある。これ以上の再現は追わない。決める材料のうち「allow の規則は判定器より先に決まる」は文書で確かめてあり、再現の成否に依らないからである。

### D2: discussion の草稿を書いた（2026-10-20）

6つの論点に、選択肢・推奨・K1〜K3 の比較を書いた。仮の推奨は「`oe-*` の allow は配らない。止まったときは親のペインで通し直す手順を文書化し、判定器の例外の文（1D）を本命、宛先を絞る hook（1F）を代わりとして、試してから別の issue で決める」とした。草稿の時点では、推奨の柱を「親の側の判定器が、中継を owner の発話と照らす唯一の検査である」に置いていた。

### D2: ゲート1（ゼロベースの代替探索・Codex 1レーン）を回した（2026-10-20）

`so-compare --codex-only` に、初期の選択肢7つと暗黙の前提5つを並べ、`so-compare` の「選択肢拡張」の型で初期案の外の代替を問うた。追加の問いとして、推奨のうち事実から言えないものと、K1〜K3 の評価の甘さ・厳しさも問うた。返したのは Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.163.0）で、157 秒・初回で返った。依頼文と出力は master の作業層 `tmp/407-oe-allow-rules-distribution/so-gate1-prompt.md` と `so-gate1/` にある。

新しい種類の代替は3つ出た。

- G: owner が承認を会話の外の記録に直接登録し、実行する側がその記録と照らす。親は承認を運ばない。隠れていた前提は「承認は owner → 統括 → 子 と文章で流れる」だった。
- H: 子は変更案の作成までにし、owner がいる親のセッションが本番の操作を実行する。子へ承認を送り返す段が無くなる。隠れていた前提は「本番の操作は子が行う」だった。
- I: agent どうしの連絡を、owner の入力と区別される経路に移す。隠れていた前提は「tmux の入力欄への打ち込みを保つ」だった。

採否は、G と H を #262 の論点として申し送る候補にし、I は engine の送り方の論点として記録だけにした。G と H は、承認の運び方と本番の操作の実行者を変える案で、#407 の問い（allow を配るか）の外にあり、#262 が扱う「狭い permission 機構」と同じ層にあるからである。H は、統括は作業に手を出さないという固定節の規律（brief の「統括は hands-off」）とぶつかるので、owner の判断が要ることを書く。I は、中継の文を owner の同意として扱わせない方向の変更で、承認の中継そのものの代わりにはならない（Codex 自身もそう書いた）。

追加の問いへの指摘は11件で、根拠を一次情報と手元の記録に当て、11件とも採った。重いものは3つである。

- 「親の側の判定器は、中継を owner の発話と照らす唯一の検査である」は言い過ぎだった。判定器が owner の発話を読めること（P5）は、照らす保証ではない。4.4 節でも、曖昧な「進めて」から Claude が組んだ具体的な中継の文が通っている。推奨の柱を、5.1 節の「どのペインにも判定器を通さずに打ち込める」に移し、親の側の判定器は「照らす機会が残る」の強さに下げた。
- 「中継の許可は、仕組みの上では子の承認の代わりになりうる」は、確かめた範囲を超えていた。言えるのは「中継の文は利用者の発話として届き、owner の直接の入力との出どころの区別が無い。そのため、子で承認として扱われる可能性を排除できない」までである。
- 779 件は、判定器が中継を検査した母数に使えない。拒否を数えた期間（10月4日以降）と総数の期間（10月1日以降）が違い、別のリポジトリでは `oe-send` の allow があるので判定器に回っていない送信も含む。2件と 779 件を別々の観測として書き、率は出さない。

昇格の印: 判定器が owner の発話を「読める」ことと「照らす」ことは別で、推奨の柱を読める側に置くと言い過ぎになる

暫定の停止条件: ゲート1 で新しい種類の案が3つ出た。どれも 6節に位置を与えて採否を決めたので、2回目のゼロベースの問いは回さない。新しい種類がさらに出続けるかは、ゲート2 の設計SO で抜けとして問う。

### D2: 設計SO（ゲート2・弱・Codex 1レーン）を回した（2026-10-20）

ゲート1 の採否を反映した discussion に、`so-compare --codex-only` で9点（基準の当て方・推奨の根拠・2B・3A・verb の分類・CHANGELOG の読み方・9節の問いの立て方・公開の文書の衛生・抜け）を問うた。返したのは Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.163.0）で、264 秒・初回で返った。依頼文と出力は master の作業層 `tmp/407-oe-allow-rules-distribution/so-gate2-prompt.md` と `so-gate2/` にある。

結論は「直してから出す」で、指摘は10件（高3・中7）だった。公式の文書とコードに当て、10件とも採った。採否の表は discussion の8節にある。判断の経緯として残すのは次の3つである。

- **hook も会話記録を読める。** 草稿は「owner の発話と中継の文を読めるのは親の側の判定器だけ」と書いていた。公式の hooks の文書で、PreToolUse hook が `transcript_path` を受け取ることを確かめた（記録は非同期に書かれ、遅れることがある）。これで、宛先だけを見る 1F と別に、中身も照らす 1F' が成り立つ。1F は、論点1 で置いた採る条件（承認していない・書き換えた中継を通さない）を作りの上で満たせないので、代わりの候補を 1F' に移した。ゲート1 で「照らす役は親の側の判定器」と書き直した段落を、ここでもう一度直したことになる。
- **読み取りの verb にも状態を書く引数がある。** `oe-confirm` は `--set-start-after` や `--write-latest` で状態のファイルを書き、`oe-tree --pick` は tmux の焦点を変える。冒頭の説明の「read-only」を verb 全体の性質として写していた。knowledge item `01KYMRE1NC7XX6N66RQ0MGGHF1` と同じ形の失敗で、上流（ここではコードの冒頭の説明）の断定を、引数の扱いまで確かめずに書き写していた。
- **別のリポジトリの規則の中身を書いていた。** 0節で「名前と中身は書かない」と書いたのに、別のリポジトリの手元の規則を文字列のまま書いていた。issue 本文（公開）に同じ文字列があるが、自分で置いた方針と合わせ、件数と verb の種類だけに直した。episode も同じく直した。

昇格の印: verb の冒頭の「read-only」は verb 全体の性質ではない。許可の対象にするときは引数の単位で確かめる

指摘の無かった点は5つで、1A をはずす主な理由とその強さ、3A の試験の読み方と DJ-4 との両立、起動の verb を外す向き、拒否の文の変更と取り消しの読み方、個人の情報とペインの番号が入っていないことである。新しい種類の代替は、ゲート2 では 1F'（hook が会話記録で照らす）が出た。これは 1F の変形として 6節に位置を与えたので、ゼロベースの問いはこれ以上回さない。

### D3: commit・push して統括へ報告し、止まった（2026-10-20）

- discussion と episode を commit して push した（`80b4032`・PR はまだ作っていない）。
- 報告の前に、統括が `oe-tree` に root `cockpit` として生きて出ていることを確かめ直した。
- engine の `bin/oe-send` で、discussion のパスと推奨の要点を1行で統括へ送った。exit code は 0 だった（0 は配送の成功を意味しない）。
- owner の判定が統括から届くまで、decision（D4）には進まない。

### D4: owner の判定を受け、decision を書いた（2026-10-20）

- 統括から `oe-send` で判定が届いた。前半10問はすべて推奨どおりで、後半6問は「配らない」を選んだので答えていない。記録は統括の作業層 `.oe/decision-407-judgment.md`（gitignored）にある。owner の言葉は「基本推奨でよくて、issue にするやつは一つでいいや、一旦。2つ来てたやつは一つにまとめる」で、1D と 1F' は1つの issue（#471）にまとめられた。
- 統括の指示は2つで、decision に #471 の番号を書くことと、暫定の手当て（q02）を書く場所の提案を入れることだった（場所は統括が決める）。
- knowledge item `01M57SY07J7C076F3765J55PEH` の教訓どおり、決定の文は判定の記録に1文ずつ当て直して書いた。後半6問と、#471 で何を採るかと、q08 の結果を issue に書く担当は、「決めていないこと」として分けて書いた。
- 手当てを書く場所は、`canonical/skills/delegate-task/SKILL.md` の send の節の「追加指示・承認の書き方」の直後を推奨にし、`orchestration-toolkit` に規範の1行と参照を置く案を併せて書いた。読むのが中継を打つ統括で、#262 の承認の手順と同じ3軸の分け方（規範は toolkit・手順は delegate-task）になるからである。
- q09 の結果は、hub の手元の層の allow が 124 件で、`oe-*` を指す規則が無いことを読んで確かめた。#471 が開いていることも確かめた。
- #471 の本文は、1D を「判定器に渡す環境の説明」に書く形で書いているが、discussion の 1D は環境の説明（`autoMode.environment`）ではなく、soft_deny の例外（`autoMode.allow`）である。decision の「結果」の #471 への申し送りに、2つが別の配列であることを書き、統括への報告にも書く。

### D4: 判定の記録を読んだあとに記録が更新され、古い内容で書いていた（2026-10-20）

decision を書く前に判定の記録を一度読み、その内容で決定8 を「統括がそのリポジトリの統括に依頼した」と書いた。記録はその直後（1分後）に統括が更新しており、「消した報告を受けた・手元で `oe-*` の規則が0件になったことを確かめた」になっていた。ゲート4 の SO には、SO を回す時点の記録を写して渡したので、Codex が食い違いを見つけた。決定8 と「結果」を直し、この機種の手元の層に engine の `oe-*` を指す allow が0件であることを、自分でも読んで確かめた。

統括が並行して動いている記録は、読んだあとに変わりうる。決定の文を書き終えたら、もう一度、原文の更新時刻か中身を確かめてから閉じる。

昇格の印: 並行して更新される判定の記録から decision を書くときは、書き終えた時点で原文を読み直す（読んだ時点の写しで閉じない）

### D4: ゲート4（decision への SO・弱・Codex 1レーン）の結果と採否（2026-10-20）

decision に対して、`so-compare --codex-only` で、決定の文と判定の原文の対応・根拠の強さ・手順を書く場所の提案・結果の節・公開の文書の衛生・抜けを問うた。判定の原文はワークスペースの外にあるので、判定ページの URL とバックアップの置き場を伏せて依頼文に写した。返したのは Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.163.0）で、86 秒・初回で返った。依頼文と出力は master の作業層 `tmp/407-oe-allow-rules-distribution/so-gate4-prompt.md` と `so-gate4/` にある。

結論は「直してから進む」で、指摘は4件（中3・低1）だった。4件とも採った。

| # | 重さ | 指摘 | 採否と直し |
|---|---|---|---|
| 1 | 中 | 決定8 と「結果」が、別のリポジトリの2件を依頼しただけのように書いている。原文では削除と確認まで済んでいる | 採った。原文が読んだあとに更新されていたことが原因だった（上の節）。決定8 と「結果」を、削除と確認が済んだ形に直した |
| 2 | 中 | 手順の提案の3項目目（通し直しが効かなければ子のペインへ直接打つ）は、原文にも discussion の 1B にも無い | 採った。「それ以上は自分で手を打たず owner に報告して扱いを決めてもらう。子のペインへの直接の入力を既定の手当てにしない」に直した |
| 3 | 中 | #471 への申し送りから、会話記録を読めても承認の出どころの証明にはならないという限界が落ちている | 採った。申し送りに足した |
| 4 | 低 | 保護された IaC の範囲の既定を「名前に prod を含むもの」と縮め、タグが落ちている | 採った。P3 と同じ表現に直した |

指摘の無かった点は、決定1〜7 と「決めていないこと」の各文と原文の対応、根拠の節の強さ、手順を書く場所の提案（3軸の分け方に合う）、q08 の結果の書き方（タグの1点を除く）、公開の文書の衛生である。

---
id: "01M4AEC4F5E4MXEVSY4SXFGTJE"
title: "#411 枝の作業から出た decision の昇格を、同じ PR でマージ前に行う形へそろえる"
date: 2026-10-07
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/411"
    reason: "本 episode の作業対象"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-07-plan-411-promotion-timing-in-pr.md"
    reason: "この episode が記録する作業の計画"
tags: [doc-flow, promotion, decision, gate-5, gate-6, document-format, doc-flow-guardrail]
# promotion: [...]   # closure で埋める（document-format.md「昇格の判定」節）
---

# #411 枝の作業から出た decision の昇格を、同じ PR でマージ前に行う形へそろえる

**この記録はリアルタイム追記である。** 着手時に枠を作り、判断・撤回・棄却をその場で書いている。closure はマージ前。

## Context（なぜこの作業が始まったか）

仕様（`document-format.md`）とスキルの文面が「昇格の実行はマージ後（ゲート6）」と読めるため、枝の作業から出た decision だけをマージ後に別 PR で入れる形が繰り返し生まれていた。owner は 2026-10-07 に「枝の作業から出た decision は、その枝の PR に入れてマージ前に着地させるのが正式な形で、分けると意味がない」と裁定した。この単位は、その裁定に合わせて canonical の文面を2種類の昇格（枝の作業から出たもの／作業層に残ったもの）で書き分ける。

## 置き場の選択（plan と episode を `docs/harness/` に置いた理由）

- hub の `CLAUDE.md`「文脈の置き場（蒸留の文書）」節は、issue が触る場所に対応する木を読めと書く。この単位が触るのは canonical の配布物（`canonical/orchestration-spec/` と `canonical/skills/`）である。
- canonical の配布物を直した最近の単位は `docs/harness/` に plan と episode を置いている（#307・#347・#348・#359・#403）。#403 は同じ `document-format.md` と `doc-flow-guardrail` を触っている。brief もここを候補に挙げている。
- 一方、#288（`episode-retrospective` の昇格の判定）は `docs/orchestration-engine/` に置かれている。canonical を触る単位が2つの木に分かれているのは既にある状態で、この単位では直さない。
- 裁定の記録（decision）だけは別の木に置く案を plan に書いた（DJ-1）。直す対象の DJ-8 が `projects/orchestration-engine/docs/discussions/` にあり、doc-flow の decision もそこに並んでいるためである。

## Step 0: 着手（2026-10-07 14:30 頃）

- brief は `.oe/brief-411-promotion-timing.md`（作業層・統括の17代目が発行・baseline は master `2a659a8`）。終端は P3（plan を書いて報告して止まる）。
- 認識合わせは `issue-intake` の 1-2 の手順で確かめた。最後の行は `confirmed`・見出し4・URL は brief の「認識合わせ:」欄と一致した（https://github.com/stlwolf/ai-development-hub/issues/411#issuecomment-6031727964）。確定版を前提にし、自分では通し直していない。
- worktree は `wt switch --create 'docs/#411_promotion_timing_in_pr' --base master` で作った。origin/master も `2a659a8` で、brief の baseline と一致した。

## Step 1: 上流の断定の裏取り

#411 本文・確定版・brief が断定していることを一次情報に当てた。結果の強さは plan の「上流の断定の裏取り」節にも写す。

- 「DJ-8 がゲート6 に昇格判定を置いた」は**確認済み**。棚卸し discussion（`projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md`）の DJ-8 の (6) が「merge 後 = issue close 判断（keep-open 明示）+ worktree 掃除（親）+ 昇格判定」である。
- 「(2) の元の動機は作業層の滞留」は**確認済み**。同じ discussion の §5「実害」(1) が「作業層に落ちた設計級コンテンツ（proposal 27k/32k 等）が昇格されず git の外に滞留」で、DJ-2 がその昇格義務を規約化した。仕様の §13 の冒頭も「git の外にこれらが滞留する唯一の実害（棚卸し §5）を塞ぐ」と書く。
- 「(2) は v2（#249・2026-07-13）からある」は**確認済み**。`git log -S` で、`**昇格の実行**は §11 ゲート6` を入れたのは `f112d75`（2026-07-13・PR #254）だった。
- 「hub で1回起きた」は**確認済み**。#288 の 2026-09-11 のコメント（https://github.com/stlwolf/ai-development-hub/issues/288#issuecomment-5628399099）が、#336 の子が「判定までが closure の担当で、実行はゲート 6」と書いて decision を PR #387 に入れず、マージと worktree の掃除のあとで owner に指摘された経緯を記録している。是正の decision は `projects/orchestration-engine/docs/decisions/2026-09-11-decision-watchdog-outside-session.md` として別に入っている。
- 「別リポジトリで2回」は**未確認**。統括からの申し送りだけが出所で、この単位からは別リポジトリを見ていない（見るべきでもない）。plan には「統括の申し送り」として写す。
- 「#288 の判断（2026-08-07）は『実行は定義上マージ後』を前提にしていた」は**確認済み**。`docs/orchestration-engine/episodes/2026-08-07-episode-288-promotion-slot.md` の「`required` に行き先フィールドを足す案（DJ-7）を退けた」の段落が、理由の1つ目にそう書いている。ただし退けた理由は3つあり（実行は定義上マージ後／値域を閉じられない／消費者が未決なのに消費者に依存する欄を足す自己矛盾）、前提が崩れるのは1つ目だけである。見直しの推奨はこの3つを分けて書く（plan の5項目の (3)）。
- 「掃除はマージ後」は**確認済み**。仕様の §11 の表の行6 が「merge 後」に「worktree 掃除（親）」を置いている。
- `episode-retrospective` が「判定まで」を担う分担は**確認済み**。#288 の 2026-08-04 の episode が「owner は実行主体を #305 へ切り出している」と書き、#288 の 2026-08-05 のコメント（https://github.com/stlwolf/ai-development-hub/issues/288#issuecomment-5187925329・PR #306 の着地）が「扱えるのは『判定』までである。昇格の実行は本節の外にある」と記録している。brief の「2026-08-05 の裁定」はこの着地を指している。

## Step 2: canonical 全体の洗い出し（10か所で足りるか）

採用した negative knowledge（`01M486Z2ND07GQWV1GHS1SVB0J`）に従い、#411 本文の10か所で足りると決めてかからずに canonical 全体を探した。`昇格` を含むファイルは canonical に10本あり、昇格の時点を述べているのは4本（`document-format.md`・`doc-flow-guardrail`・`episode-retrospective`・`unmet-gate-check`）だけだった。ほかの6本は無関係の「昇格」（権限の昇格・検証ステータスの昇格など）か、時点を述べていない（`spec-card`）。

10か所の外で、同じ変更で直すべきものが3つ見つかった。

- `document-format.md` §11 の表の行5（PR → merge）。行6 から昇格を (b) に絞ると、表のどこにも「枝の作業から出た昇格」が現れなくなる。ゲート5 の行に最後の確認として置かないと、表だけ読む人には居場所が無い。
- `doc-flow-guardrail` の routing 表の行5。仕様の表と 1:1 の索引なので、行5 を直すならこちらも直す。
- `episode-retrospective`「昇格の判定」節の `required` の処分の行（「実行は本スキルの外である（negative knowledge だけは Step 5 が in-PR で実行する）」）。「だけ」が「in-PR なのは knowledge だけ」と読める。
- `unmet-gate-check` の due の表は、#411 本文が挙げた行（merge 後）のほかに、行「PR → merge のゲート（closure・昇格候補の洗い出し）」も直す必要がある。規範が枝の作業から出た昇格に課す締め切り（マージ前）を、検査の側がどの行で due と見るかを別に書いて突き合わせるためである（採用した negative knowledge `01KYJ76D7CS7EBY3WDYY1NS9Y2`）。これは #411 本文の項目9 の中に数える。

`#289` の事例2-b も一次情報に当てた。`unmet-gate-check` の「事故の実例」（マージ後に due な昇格確認が「該当しない」と扱われる）の出所は、#284 の一連で統括がゲート6 の昇格確認を飛ばし、探索木を昇格せずに worktree を破棄して別 PR（#287）が要った件である（#289 本文の事例2）。新しい書き分けでは、探索木は枝の作業から出たものなので、本来はマージ前に同じ PR に入るべきだった。ゲート6 の拾い上げは、作業層に残ったものの本来の置き場であると同時に、枝の作業から出た昇格の取りこぼしを拾う最後の網でもある。

昇格の印: ゲート6 の拾い上げは、作業層に残ったものの置き場であると同時に、枝の作業から出た昇格の取りこぼしを掃除の前に拾う最後の網である

## Step 3: 受入の grep を変更前の master で確かめた

採用した negative knowledge（`01M2DRCP3QSG4NQWHNY6DSD3NJ`）に従い、受入の grep を書いた時点で `2a659a8` に当てた。`git grep` で master の版を直接読んだ。

- 全体の検査（「昇格の実行」とマージ後・ゲート6 を結ぶ文など、7つの言い回しをまとめた正規表現）は、`2a659a8` で4ファイル8行に当たった。変更後に0行になることを受入にする。
- 箇所ごとの検査（直す前の文の固定文字列12本）は、`2a659a8` でどれも1件以上当たった。「同じ枝で作った episode・knowledge もその枝の PR に載せる」だけは2件（仕様と固定節の両方）である。
- コマンドと結果の全体は plan の「受入」節に置いた。

## Step 4: 裁定の内容（plan を書く前に固定したこと）

昇格の印: 枝の作業から出た昇格は同じ PR に入れてマージ前に着地させ、DJ-8 の (6) の昇格は作業層に残ったものに絞る

- owner の裁定の原文は #411 本文に引用されている（2026-10-07・別リポジトリの統括のセッションへの直接入力）。
- この単位の設計は owner の裁定そのもので、設計SO（ゲート2）は owner の了承で省いた（brief の「この委譲で加える規律」節）。実装SO（ゲート4）は省かない。
- plan で下した小さな判断（裁定の記録の置き場・実行者を書く場所・名前の付け方）は、どれも文面の置き方で、戻すのが容易である。ゲート1（ゼロベース探索の SO）は回さず、探索木を plan に書いて owner のゲート3 で見てもらう形にした。理由は plan の「ゲート1 を SO で回さない理由」節に書いた。

## Step 5: plan の文面を、plan 自身の受入に当てた（2026-10-07 14:53）

plan に書いた「直した後」の文面が、plan の受入を本当に通るかを、実装の前に確かめた。受入の文字列と提案の文面を別々に書いたので、両者が食い違っていれば I1 で初めて分かり、plan を直すことになるためである。

- `2a659a8` の canonical を作業ツリーの外（scratchpad）へ `git archive` で写し、提案の文面を固定文字列の置き換えで当てた。置き換え14件はどれも元の文字列にちょうど1回当たった。
- 結果: 29項目と全体の検査 `G` がすべて PASS（exit 0）。番兵（「closure で昇格／実行」）は0件。差分は4ファイル・16行の置き換えだった。
- 枝の canonical には触っていない（実装はゲート3 の後）。置き換えに使ったスクリプトは `tmp/411-promotion-timing/dryrun-apply.py`（gitignored）に残した。

## Step 6: plan と episode をコミットして報告する（P2・P3）

- plan: `docs/harness/plans/2026-10-07-plan-411-promotion-timing-in-pr.md`。
- 報告は `.oe/report-411.md`（作業層）。宛先は brief の「報告の宛先」の統括で、`oe-tree` に生きた root として出ることを確かめてから送る。
- ここで止まり、統括の「実装へ」を待つ。
- commit `ad7c9db` を push し、報告を送った（`oe-send` exit 0）。

## Step 7: ゲート3 の扱いが変わり、計画外を数え直した（2026-10-07）

- 報告を送ったあとに、統括から owner の裁定が届いた。plan 承認（ゲート3）は挟まない。owner の原文は「特に計画外のことが起きなければそのまま」で、統括が plan を確かめ、計画外が無ければ baseline の digest を記録して「実装へ」を送る。計画外があれば統括が owner に上げる。終端は P3 のまま変わらない。
- 指示矛盾ガードに当てた。終端の再定義ではなく、未達の step を飛び越す指示でもない。ゲート3 の要件は弱まるが、弱めたのは owner 自身の裁定で、記録が作業層にある（統括の発行）。自分の次の動き（P3 で止まって待つ）は変わらないので、確認を挟まずに従った。
- 統括が挙げた4つの型（確定版の範囲を外れる判断・10か所の外を直す必要・#288 の判断の見直し・owner への問い）で plan を数え直し、6項目を plan の「計画外」節に書いた。
- **数え直しで、DJ-7 が #411 本文から外れていることに気づいた。** 本文の「直す方向」は、枝の作業から出たものを「knowledge の in-PR 相乗りと同じ扱いにする」と書く。knowledge には別 PR に分けてよい3つの条件がある。plan は DJ-7 でこれを写さず、owner の明示の裁定だけにした。棄却した案として「knowledge と同じ3つの例外」を書いていたので、判断そのものは意識して下していたが、本文の文言から外れることを報告で目立たせていなかった。最初の報告の「ゲート3 で見てほしいところ」にも入れていなかった。これを計画外の1番目にし、owner の判断が要る項目として報告の冒頭に置いた。
- 最初の報告は、統括の新しい指示の前に送ったもので、計画外の見出しを持たない。報告を書き直して送り直す。

昇格の印: plan 承認（ゲート3）を、計画外が無ければ統括の確認で代え、計画外があるときだけ owner に上げる運用（この単位で owner が裁定した・記録は作業層にだけある）

## Step 8: 「実装へ」が届き、plan は承認された版に戻した（2026-10-07）

- 計画外の一覧を plan に足している途中で、統括から「実装へ」が届いた。統括は最初の報告と plan（commit `ad7c9db`）を確かめ、**計画外は無いと判断して**、baseline の digest を作業層の裁定の文書に記録していた。
- 統括の判断の中身: 10か所の外の3か所（ゲート表の行5・routing 表の行5・`required` の行）は同じ書き分けの裏側で、#411 の受入がそもそも全数を求めているので計画内として扱う（統括が本文に書いた「全数10か所」は数え漏れだった）。DJ-6 と DJ-7 は owner の裁定（「分離したら意味なくね」）と「アンカーは多い方がよい」の範囲内。#288 は推奨にとどめているので計画外ではない。
- 自分で数え直した6項目を、統括の判断に突き合わせた。6項目はどれも `ad7c9db` の plan に書いてあったもので、統括はその版を読んで判断している。

  | # | 項目 | `ad7c9db` の plan での置き場 | 統括の扱い |
  |---|---|---|---|
  | 1 | 別 PR に分けてよい条件を owner の明示の裁定だけにした（#411 本文の「knowledge と同じ扱い」から外れる） | DJ-7（棄却した案に「knowledge と同じ3つの例外」） | owner の裁定の範囲内 |
  | 2 | 10か所の外（行5×2・`required` の行・`unmet-gate-check` の「PR → merge」の行・記録を3つにしたこと） | 1b・7b・8b・9・DJ-1 | 計画内 |
  | 3 | 作業層に残った昇格に、取りこぼしを含めた | DJ-6 | owner の裁定の範囲内 |
  | 4 | #288 の判断の見直しを推奨した | 確定版の5項目の (3) | 推奨にとどめているので計画外ではない |
  | 5 | ゲート1 の SO を子の判断で回さなかった | 「ゲート1 を SO で回さない理由」節 | 個別の言及は無い。plan の全体を読んで計画外なしと判断している |
  | 6 | `so.design: omitted`（値域の外） | frontmatter | 個別の言及は無い（同上） |

  1 について、最初の報告で「本文の文言から外れる」と目立たせていなかったのは自分の落ちである。統括は DJ-7 を名指しして範囲内と判断しているので、判断の材料は届いていた。
- 指示矛盾ガードに当てた。「実装へ」は終端（P3）を越えて I1 以降へ進めるもので、brief が「統括から『実装へ』が届いたら I1 以降へ進む」と書いている位置への指示である。未達の step の飛び越しも、要件の弱体化も無い。矛盾は無いので従う。
- **plan に足しかけた編集は戻した。** 「計画外」節の追加と GATE 3 の書き換えは、承認された版のステップ節を変える。統括は `ad7c9db` の plan の全文とステップ節の digest を baseline として記録しているので、ここで plan を変えると完了前の照合で食い違う。`git restore --source=HEAD` で plan を戻し、全文の digest（`status:` 行を除く・`33890fe8…`）とステップ節の digest（`8fa584d8…`）が統括の記録と一致することを確かめた。戻した差分は `tmp/411-promotion-timing/plan-unapproved-edits.diff`（gitignored）に残した。計画外の数え直しは上の表としてこの episode に残す。
- 統括は「別リポジトリで2回」を先方の PR の中身で確かめた。1回はマージの後に decision を入れるための別 PR が立ったもの、もう1回は是正されて本体の PR に decision が入ったもの。decision には「統括が確かめた」と書いてよく、番号とリポジトリ名は書かない。plan の「上流の断定の裏取り」の表で「未確認」としていた行は、これで確認済み（統括による）になった。

## I1-0: baseline の確認

- 統括へ「実装へ」の受領を `oe-send` で返した（exit 0）。
- `git fetch` のあと、`2a659a8..origin/master` で直す4ファイルに触れた commit は0件だった。origin/master は `2a659a8` のままである。plan どおり進める。

## I1-1: 裁定の記録を書いた

- decision: `projects/orchestration-engine/docs/decisions/2026-10-07-decision-411-branch-promotion-in-same-pr.md`。plan の DJ-1 の骨子どおり、コンテキスト・決定・根拠（棄却した3案を含む）・結果を書いた。「別リポジトリで2回」は「統括が先方の PR の中身で確かめた」と書き、番号とリポジトリ名は書いていない。owner の原文は #411 本文で公開済みのものをそのまま引用した。
- 棚卸し discussion の末尾に「## 9. 追補（2026-10-07・#411）」を足した。DJ-8 の本文は書き換えていない。
- 仕様の `related` に `derived_from` で decision を1行足した。
- 検査: `related` のリポジトリ内パス（decision・仕様・episode・plan）はすべて実在した。frontmatter は ruby の YAML で3本とも読めた。制御文字は無かった。
- decision の「結果」節の最後に「本 decision は自分自身に当てた」と書いた。この単位が直す規則を、この単位の記録に当てた形である。

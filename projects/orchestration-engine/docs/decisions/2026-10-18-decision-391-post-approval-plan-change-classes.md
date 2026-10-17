---
id: "01M55N4GET6Q0HT4FYGB5BV6Y0"
title: "承認のあとの plan の変化は効果で3つの級に分け、owner の再承認は「変更」だけに求める — baseline は承認時の commit で固定し、一致は変化の検知にだけ使う"
date: 2026-10-18
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/391"
    reason: "本 decision が記録する owner の裁定（2026-10-18・ゲート3）と、4つのスキルの文面をそろえた単位"
  - type: derived_from
    ref: "docs/harness/discussions/2026-09-11-discussion-347-approval-baseline-drift.md"
    reason: "構造を最初に踏んだ #347 の記録と、扱い方の4案（A〜D）。本 decision はそのうち B と digest の組み合わせを採り、3つの級を足した"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-29-discussion-289-completion-gate-firing-position.md"
    reason: "baseline を導入した #289 の設計判断。枠には記録の義務だけを置き、照合の手順はスキル側に置いた責務分割を本 decision も保つ"
  - type: reference
    ref: "docs/harness/plans/2026-10-18-plan-391-post-approval-baseline.md"
    reason: "設計判断 DJ-1〜DJ-11・実例12件の分類の表・棄却した案の理由・4ファイル9か所の前後の文面と受入。本 decision は durable な判断に絞り、細部はこちらを指す"
  - type: reference
    ref: "docs/harness/episodes/2026-10-18-episode-391-post-approval-baseline.md"
    reason: "設計SO・実装SO・Copilot の指摘と採否、撤回の経緯"
  - type: modification_target
    ref: "canonical/skills/unmet-gate-check/SKILL.md"
    reason: "baseline の節・渡すものの表・起動テンプレ"
  - type: modification_target
    ref: "canonical/skills/doc-flow-guardrail/SKILL.md"
    reason: "委譲固定節の項目と gate 3 の baseline 記録の注記"
  - type: modification_target
    ref: "canonical/skills/implementer-contract/SKILL.md"
    reason: "「承認のあとに plan が変わるときの扱い」節（3つの級の表・申告の形・8項目）とプロンプトテンプレート"
  - type: modification_target
    ref: "canonical/skills/delegate-task/SKILL.md"
    reason: "「追加指示・承認の書き方」節の末尾の1文"
  - type: evidence_for
    ref: "projects/orchestration-engine/docs/episodes/2026-09-11-episode-390-supervisor-planned-succession.md"
    reason: "baseline を守る規律が進捗の記録まで止めた実例。「記録」の級を子だけで進めてよいとする根拠"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/291"
    reason: "起動を保証する層。Alt-7（承認時の義務コンパイル）の前提が「張り直しごとに再コンパイル」に変わること、観測項目の変化、設計SO の案I（型付きの契約から plan を生成する）を統括がコメントする"
tags: [doc-flow, gate-3, baseline, delegation, unmet-gate-check, decision]
---

# 承認のあとの plan の変化は効果で3つの級に分け、owner の再承認は「変更」だけに求める

## コンテキスト

委譲の plan を owner が承認するとき（ゲート3）、統括は完了前の照合（`unmet-gate-check`）のために baseline を承認の記録に残す。対象は plan・委譲時の書面・ゲート表の版の3つで、2026-10-18 までは sha256 の digest で固定していた。承認のあとに plan を直すと digest が動く。#347（2026-09-11）では owner の裁定「採らない理由を plan に1行残せ」に従うだけで動いた。その後は、裁定より、実装SO・Copilot・完了前の照合の指摘で plan を直したときと、進捗の記録（済み印・実測値・status）で動くことのほうが多かった。10-08 以降だけで取り直しが7回（#429 で4回・#412 で3回）、owner への再承認の依頼が3回（#412）あった。

逆向きの害も出ていた。#390 では「digest が動いたら申告せよ」の規律を子が凍結の指示と読み、実装が2本進んでも plan の済み印と status を動かさなかった。#411 では子が承認のあとに plan へ足しかけた節を baseline と食い違うので戻した。凍結を守る規律と、進んだことを書く規律が同じ対象の上で衝突していた。

規範の文「plan の更新 → 再承認 → baseline の再記録を1単位にする」は canonical の3か所（`unmet-gate-check`・`implementer-contract`・`delegate-task`）にあり、plan の内容が変わるたびに owner の再承認が要ると読めた。discussion（#347）は扱い方を4案（A 明文化・B コミットで固定・C 編集禁止・D 機械通知）に整理し、B が本筋と見立てて決めずに止めていた。

## 決定

owner が 2026-10-18 のゲート3 で、統括の推奨どおり次を承認した（補足なし）。

1. **baseline の plan は承認時の commit で固定する。** plan の内容は git が commit ごとに持つので digest を別に計算しない。内容の一致（git の blob）は「記録された版から変わったか」の検知にだけ使う。委譲時の書面は作業層にあって commit できないので全体の digest で、ゲート表はその版が入っている commit で固定する。作業層にあって commit できない plan は書面と同じく digest で固定する。
2. **承認のあとの plan の変わり方を効果で3つの級に分ける。** 記録（済み印・結果・status。承認した内容そのものは変わらない）・補正（承認の母集団〔step 集合・要件・ゲート・終端〕と owner が決めたことを変えず、新しい結果・対応範囲・作業義務・設計判断も足さない直し）・変更（step を削る・要件を弱める・ゲートを飛ばす・終端を書き換える・新しい作業義務や設計判断や対応範囲を足す）。級は出どころ（裁定・SO・Copilot・照合）ではなく効果で決める。判定の順序は、記録だけの更新を先に除き、残りはまず変更に当たるかを見て、当たらないものを補正とする。1つの直しに級が混じるなら分けて見て重い側で扱い、迷ったら重い側に置く。
3. **owner の再承認を求めるのは「変更」だけ。** 記録は子が自分で動かしてよく、申告も受け付けも要らない。補正は子が申告して進めてよく、統括が次の報告で差分を8項目（step 集合・各 step の要件・ゲートの項目・終端 step・受入・設計判断の結論・範囲・追加）で確かめて受け付ける。owner には完了の報告で受け付けた一覧を見せ、統括の判定の誤りはそこで owner が捕まえる。
4. **受け付けた版は張り直しの entry として承認の記録に足す。** entry は対象・変更前後の版・級・出どころ・8項目それぞれの結果・受け付けた主体を持ち、級が変更なら owner の再承認の参照も持つ。有効な版は対象ごとに、その対象を更新した最後の entry の変更後の版（無ければ承認時の版）。entry は承認時の版から途切れずつなげ、書面を変えるときは変える前の全文の写しを残す。
5. **照合役（`unmet-gate-check`）は級を判定しない。** 見るのは、いまの内容が有効な版と一致するかと、承認時の版から辿った entry の形式と連続性だけである。途中の entry に不備があれば `invalid-baseline`。規範が当たる範囲（3つの級すべて）と照合役が検査する範囲は一致せず、それを本文に明文で書く。旧い形の記録（digest だけ）は記録のアルゴリズムで比べ、取り直しを求めない。
6. **置き場は4つのスキル**（`unmet-gate-check`・`doc-flow-guardrail`・`implementer-contract`・`delegate-task`）。`document-format.md`「ゲート配置」節は触らない。ゲート3 そのもの（plan → 実装の owner HG）の性質は変えない。進行中の委譲には遡及しない。

細部（直した文面・受入・DJ-1〜DJ-11）は plan が持つ。

## 根拠

- **統括が実際に行っていた判断は差分に対するもので、digest はその入口だった。** #347・#390・#412・#429 の承認の記録を読むと、張り直しのたびに統括は承認時の commit との diff を見て「step の削除と要件の弱体化が無い」と確かめ、digest は結果を書く欄になっていた。commit で固定すれば、plan の内容は git が持ち、算術と、子が計算していない値を書く穴（#390）が消える。
- **実例12件のうち、owner が決めたことや母集団を変えたのは3件で、どれも owner が決めていた。** 残り8件の直し（#390 進捗は直しでなく失敗の例）は母集団を変えず、統括が受け付けた5件のほかに owner に聞いた2件（#412 の受入の延長とペイン番号）は聞かなくても同じ結果になる種類だった。3つの級は、この分布をそのまま写している。2つの級（禁止と必要）だけでは、この中間の8件がどちらにも入らず owner に戻る。
- **補正は申告して進めてよい**としたのは、統括の受け付けを待たせると往復が1回増え、望む結果（統括と owner の手間が減る）に逆行するからである。補正は定義上、母集団と owner の決定を変えない小さな直しなので、統括が変更と判定したときの戻り作業は限られる。
- **棄却した案**: A（今の形の明文化）は digest の計算と統括の目の判定と線引きの無さが残る。C（編集禁止）は済み印と status が plan の型にあるので凍結が規範になり、#347 では追補だけに置くと plan だけを読む人が裁定へ到達できなかった。D（機械通知）は扱いが決まらず規範が先に要り、仕掛けは #291 の領分。E（plan を不変にし追補に置く）は C の committed 版で読む場所が割れる。F（ステップ節だけを固定）は受入の節の弱体化を見逃す。G（委譲ごとに owner が選ぶ）は裁定で言えば足り欄が増える。H（記録を正規化して照合役が通す）は正規化できない記録があり、照合役が内容を判断する側に寄る。I（型付きの契約を正本にして plan を生成する・設計SO）は4スキルの文面の改訂を越え、#291 の Alt-7 と同じ方向の将来案として残す。
- **照合役に級を判定させない**のは、`unmet-gate-check` の射程「照合であって判断ではない」を崩さないためである。級の判定は統括が照合の前に済ませ、entry に残す。entry の形式と連続性は級の妥当性を判断せずに検査できる（Copilot の指摘で、最後の entry だけでは途中の不備をあとの entry で覆えることが分かり、承認時の版から辿る形にした）。

## 結果

- 統括は digest を計算しない。受け付けのたびに entry を1つ足す。owner に戻るのは変更の級だけで、#412 の例なら3回が1回になる。
- この規範が閉じないもの: 統括が差分を見ずに entry を書く虚偽と、誤った級での受け付けは照合では捕まらない。受け皿は owner が完了の報告で entry の一覧を見ることで、機械で閉じるのは #291 の層である。
- 実物の確かめは、次の plan-first の委譲で承認のあとに plan が変わったとき、統括が #391 に1回記録する（件数と級の内訳・owner に戻した回数・補正として受け付けたもののうち owner が異を唱えた件数・digest を計算した回数）。異を唱えた件数が 0 でなければ、級の線引きを見直す材料になる。
- #291 の前提が変わる。Alt-7 の義務コンパイルは承認時に1回ではなく張り直しごとに再コンパイルになり、観測項目「digest 不一致の発生頻度」は「張り直しの回数と級の内訳」になる。設計SO の案I は Alt-7 と同じ方向にある。統括がゲート6 で #291 にコメントする。
- 進行中の委譲（brief が古い固定節を持つもの）には遡及しない。旧い形の承認の記録は、記録のアルゴリズムで digest を比べる経路で照合する。本 decision を作った単位（#391）自身がこの経路で照合される。
- 本 decision は、それが直した規則どおり、生まれた枝の PR（#451）に入ってマージ前に着地している。

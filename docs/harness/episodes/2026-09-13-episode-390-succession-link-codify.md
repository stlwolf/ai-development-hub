---
id: "01M2D54AA82BZZ339Q9AQV8AZK"
title: "#390 交代の直後に踏む工程をガードレールのスキルへ書く"
date: 2026-09-13
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/390"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "docs/harness/plans/2026-09-13-plan-390-succession-link-codify.md"
    reason: "この episode が記録する作業の計画"
  - type: relates_to
    ref: "projects/orchestration-engine/docs/episodes/2026-09-12-episode-390-retire-and-docs.md"
    reason: "前の単位。follow-up の表と受入の境界がこの単位の入力になっている"
tags: [orchestration, succession, doc-flow-guardrail, skill, handoff]
promotion: []
knowledge_observations: []
---

# #390 交代の直後に踏む工程をガードレールのスキルへ書く

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

前の単位（PR #394）の closure が、follow-up のうち3件を次の単位へ割り当てた。対象は `canonical/skills/doc-flow-guardrail/SKILL.md` の3点で、受入の境界も closure が明示している。詳細は plan の「背景」と「受け入れの境界」に書いた。

## 作業の記録

### ブリーフの断定を当て直した（2026-09-13）

統括のブリーフが挙げた前提8件を merged master で確かめた。**5件は一致し、3件は食い違った。** 内訳は plan の「ブリーフの断定を当て直した結果」に書いた。

食い違いのうち2件は、そのまま作業の中身を変える。

- **直す行は1箇所ではなく2箇所だった**（`SKILL.md:71` と `:72`）。ブリーフは1箇所として書いていた。
- **negative knowledge item `01M1TK0A7AX20V0XKWYNAR5WM5` の置き場が違った。** ブリーフが書いた `docs/harness/knowledge/items/` には無く、実在するのは engine 木のほうである。**closure の観測はこちらへ書き戻す。**

3件目は作業を変えないが、主張の強さを変える。ブリーフは「あなたの `PARENT_TMUX_PANE` が何を指していても」と書いていたが、**この子の環境変数は正しい宛先を指していた。** 交代のあとに起きた子だからである。**確かめられたのは「交代前に起きた子では古くなる」ことまでで、「常に古い」ことではない。**

### 順序が結果を変えることが分かった（2026-09-13）

`bin/oe-register:185-190` の guard を読んで、`oe-register link` が前任の生死で分岐することが分かった。**前任が停止済みなら orphan の引き取りとして `--force` 無しで通り、生きていると拒否される。** つけかえを `retire --execute` の前に置くか後ろに置くかで、必要な引数も、GC が前任の root 登記を掃くかどうかも変わる。

**ブリーフはこの分岐に触れていない。** 「交代の直後に踏む工程」としか書いていないので、順序は自分で決める必要があった。plan の DJ-2 に理由を書いた。

### 後継がスキルを読む導線が無いことが分かった（2026-09-13）

`templates/handoff.md.template` と実物の引き継ぎ文書（112行）のどちらにも、`doc-flow-guardrail` / `oe-register` / `cold-start` の3語が1つも出てこない。**この単位でスキルに工程を書いても、後継が引き継ぎ文書だけで進めば読まれない。**

昇格の印: 工程を書く場所と、その場所が読まれる経路は別に決まる。前の単位の判定6（verb のあいだの工程が落ちると完走しない）は、書く場所を決めただけでは閉じない。

範囲外なので実装せず、plan の「範囲外」と「owner に預ける判断」に surface した。

### 昇格判定6 の実行先がブリーフから落ちていた（2026-09-13）

前の単位の closure は判定6 を `required`・置き場は decision とし、**実行の置き場をこの単位に指定している。** ブリーフの scope は `SKILL.md` の3点だけで、decision に触れていない。**明示的に「decision は立てない」を選んだのか、判定6 が落ちたのかが読み取れない。** plan の「owner に預ける判断」に案A / 案B として出した。

### 設計SO（ゲート2・弱・2レーン）で plan を書き直した（2026-09-13）

`so-compare` を既定の2レーン（codex と claude）で1回回した。**2レーンとも「要修正」で返り、指摘を実物で当て直した結果、反証できたものは1件も無かった。** 変更の内訳は plan の「設計SO で変えたこと」の表に書いた。証跡は `tmp/so-design-20260913-193652/`（揮発するので表のほうが正本）。

**いちばん重い指摘は検算が空振りすることだった。** 初稿は「`cockpit` の root が1本であること」を検算に書いていたが、`bin/oe-tree:641-654` を読み直すと root は「parent 参照のうち entry が無い pane」と「parent が空の entry」の和である。前任の登記が GC で消えると、まだつけかえていない子が居てもラベルが `?` に変わるので、**子が1体も付いていない状態でも「`cockpit` の root は1本」が真になる。** 検算を「前任の pane が木に現れないこと」と「件数の一致」へ書き直した。

**2番目は受入が変更を見ていなかったことである。** owner が明示した3項はコマンドの存在・引数・出力だけを見るので、`SKILL.md` を1文字も編集しなくても全部通る。**境界（実運用の交代までは求めない）は動かさず、静的な受入6項を足した。**

昇格の印: owner が定めた受入の境界は「どこまで確かめるか」を決めるもので、「変更そのものを見なくてよい」とは別である。境界をそのまま写すと、変更を見ない受入ができあがる。

**3番目は前提そのものの誤りである。** 初稿は「子が0体の交代では書き込みの契機が無いので root が2本並ぶ姿は残る」と書いていた。これは前の単位の episode の記述をそのまま写したものだが、`bin/oe-register:158-162` を読むと `oe-register root` は冪等に再登記でき、その書き込みが GC を呼ぶ。**契機は作れるので、記述を撤回した。**

昇格の印: 前の単位が「残る」と書いた制約を、当て直さずに次の単位の設計へ写した。上流が断定していたのは前の単位の自分たちである。

### ゲート3 を通過し、scope が5点になった（2026-09-13）

owner が「推奨で go」を出し、4件とも推奨どおりに裁定された（`.oe/addendum-390-guardrail-hg-go.md`）。**scope は `SKILL.md` の3点から5点になった** — cold-start の入口条件（120行目）と、既存の素の `oe-register` の呼び方（127行目）が加わった。増えたのは同じ節の中の数行である。

**統括から訂正を1件受け、こちらの誤りだと確認した。** plan の「食い違ったもの」に書いた「negative knowledge item の置き場がブリーフと違う」は誤りである。ブリーフの `item:` は engine 木のパスを書いており、実在もそちらである。`docs/harness/` なのは `source:`（収穫元 episode）のほうで、**item と source を取り違えて、harness 側のパスを自分で組み立てたうえで「実在しない」と判定していた。**

昇格の印: 「ブリーフの断定を当て直す」工程そのものが、当て直しの対象を取り違える形で外れた。検索が0件を返したとき、パターンではなく**自分が組み立てた対象パス**のほうを疑う必要があった。

**確かめ直した結果、残った事実はある。** item の置き場（engine 木）と `source.ref`（harness 木）は実際に別の蒸留木であり、本スキルが定める「item は `source.ref` と同じ木」と食い違う。**範囲外の記述をこの範囲だけに絞り直した。**

### 実装とゲートを通した（2026-09-13）

`canonical/skills/doc-flow-guardrail/SKILL.md` に5点の編集を入れ、ゲートを4本通した。

**GATE 1-a（受入 1・2・3）。** `oe-register --help` の口が手順の記述と一致する。guard（`bin/oe-register:185-193`）は「対象の子の親が非空・自分でない・生存」の3条件で拒否し、gone なら orphan として素通りする。`root` の冪等再登記（同 `:158-165`）は `record_or_die` を通り、その先で GC が走る（`lib/delegate-registry.sh:78`）。`oe-tree` を実行し、親子と自分の位置が読める形で出ることを確認した。root 合成の規則（`bin/oe-tree:641`）と、entry も `pane_title` も引けないときラベルが `?` になること（同 `:634-639`）も読み直した。

**GATE 2-3（受入 2・3）。** `oe-send [--brief <path>] [--] <target> [ad-hoc...]` の口と、書いた例の並びが一致する。空の target を実際に渡すと `oe-send: target is required` で exit 2 になった（`<報告先>` を使う根拠）。`%N` が登記を通さず素通しすることと、`oe-report` が `PARENT_TMUX_PANE` を先に読むことも実物で確認した。

**GATE 4-a（受入 1）。** #355 は OPEN、`bin/` に `oe-reseat` は0本、129行目が指す discussion は実在、#238 と #239 はどちらも OPEN。

**GATE 5（静的受入・設計SO で足した8項）。** 8項すべて OK。あわせて3つの設定ルートの `skills/doc-flow-guardrail` を `readlink` で照合し、いずれも hub の同じディレクトリを指していることを確認した（sync は実行していない）。

## closure（ゲート5・マージ前）

（実装後に書く）

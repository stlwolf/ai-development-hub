---
id: "01M4AEC4E0C62DXVSQHF7ZJ18P"
title: "#411 枝の作業から出た decision の昇格を、同じ PR でマージ前に行う形へそろえる"
date: 2026-10-07
type: plan
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/411"
    reason: "owner の裁定（2026-10-07）と、そろえる箇所10か所の出所。認識合わせの確定版はこの issue のコメントにある"
  - type: reference
    ref: "docs/harness/episodes/2026-10-07-episode-411-promotion-timing-in-pr.md"
    reason: "上流の断定の裏取りと、10か所の外の洗い出しの記録"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md"
    reason: "DJ-2（作業層の昇格義務）と DJ-8 の (6)（merge 後の昇格判定）。この単位は DJ-8 の (6) の昇格を作業層に残ったものに絞る"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/305"
    reason: "作業層に残った昇格と catch-all の実行主体の置き場。この単位では決めない"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/288"
    reason: "2026-08-07 の判断（required に行き先を足す案の棄却）の前提が、枝の作業から出た昇格について崩れる。見直しの推奨だけをここに書く"
tags: [doc-flow, promotion, decision, gate-5, gate-6, document-format, doc-flow-guardrail, unmet-gate-check]
so:
  design: omitted   # 「SO モード」節〔§4.1〕の値域（weak / strong）の外。owner が 2026-10-07 にこの単位の設計SO を省くと了承した（brief）
  impl: weak
  reason: "配布物の文言の変更で、実行時の挙動を持つコードは無く可逆。owner の裁定がそのまま設計なので設計SO は owner の了承で省く。常時ロードされる仕様と委譲の固定節を触るので、実装SO（Codex 1レーン）と Copilot は通す"
---

# #411 枝の作業から出た decision の昇格を、同じ PR でマージ前に行う形へそろえる

## 背景

仕様 `document-format.md`「昇格義務」節〔§13.1〕の判定タイミング (2) は「昇格の実行は §11 ゲート6（merge 後の後始末）＝ worktree 掃除の前に行う」と書いている。この文は、どの PR にも紐づかずに作業層に残った設計級のものを、掃除で消える前に拾うために書かれた（棚卸し discussion の DJ-2 と §5 の「実害」(1)）。枝の作業から出た decision をいつ PR に入れるかは決めていなかった。ところが字面は「昇格の実行はマージ後」なので、枝から出た decision にもそう読める。その結果、decision だけをマージ後に別 PR で入れる形が、hub で1回（#336・PR #387 の後）、別リポジトリで2回起きた（別リポジトリの2回は統括の申し送りで、この単位では確かめていない）。

owner は 2026-10-07 に、枝の作業から出た decision はその枝の PR に入れてマージ前に着地させるのが正式な形だと裁定した（原文は #411 本文）。**この plan は owner の裁定をそのまま設計として扱い、覆さない。** 決めるのは、裁定を canonical の文面へ落とす形と、認識合わせの確定版が挙げた5項目への答えである。

## この plan の範囲

- 直すもの: #411 本文の10か所と、洗い出しで見つかった10か所の外の3か所（下の「直す箇所と直し方」）。ファイルは4本（`document-format.md`・`doc-flow-guardrail`・`episode-retrospective`・`unmet-gate-check`）。
- 作るもの: この裁定の記録（decision 1本）と、棚卸し discussion への追補1節と、仕様の `related` への1行（DJ-1）。
- 範囲外: 作業層に残った昇格の実行主体の置き場（#305）、`episode-retrospective` の closure が判定までを担う分担（#288・2026-08-05 に着地）、過去の discussion・episode の本文の書き換え（歴史の記録は追記で扱う）、engine（`oe-*`）の変更。#288 の 2026-08-07 の判断は見直しの推奨を書くだけで、見直しそのものはしない。

## 上流の断定の裏取り（結果と強さ）

#411 本文・確定版・brief の断定を、master `2a659a8` と GitHub の一次情報に当てた。経緯は episode の「Step 1: 上流の断定の裏取り」節にある。

| 断定 | 結果 | 一次情報 |
|---|---|---|
| DJ-8 がゲート6 に昇格判定を置いた | 確認済み | 棚卸し discussion の DJ-8 の (6) |
| (2) の元の動機は作業層の滞留 | 確認済み | 同 discussion の §5「実害」(1)・DJ-2。仕様の §13 の冒頭 |
| (2) は v2（#249・2026-07-13）からある | 確認済み | `git log -S` で `f112d75`（2026-07-13・PR #254） |
| hub で1回起きた | 確認済み | #288 の 2026-09-11 のコメント（issuecomment-5628399099） |
| 別リポジトリで2回起きた | 未確認 | 統括の申し送りだけが出所 |
| #288 の 2026-08-07 の判断は「実行は定義上マージ後」を前提にしていた | 確認済み（ただし前提は3つのうちの1つ） | `docs/orchestration-engine/episodes/2026-08-07-episode-288-promotion-slot.md` の「行き先フィールドを足す案を退けた」段落 |
| 掃除はマージ後 | 確認済み | 仕様 §11 の表の行6 |
| closure は判定までという分担（2026-08-05） | 確認済み | #288 の 2026-08-05 のコメント（PR #306 の着地） |
| 10か所で全数 | **足りなかった**。同じ変更で直すべき箇所が3つ増えた | 下の「直す箇所と直し方」の 1b・7b・8b |

## 2種類の昇格の定義（全箇所で使う名前）

全箇所で次の2つの名前をそのまま使う。読み手が箇所をまたいで同じものだと分かるように、言い換えない（DJ-3）。仕様の §13.1 の番号 (1)(2)(3) は残す（`episode-retrospective` が「判定タイミング (2)」「(3)」で指しているため）。

- **枝の作業から出た昇格**（仕様 §13.1 の (1)）: その枝の作業（plan・episode・closure と、枝の作業で使った作業層の文書や `tmp/` の証跡）から出た設計級 / durable なもの。**遅くともマージ前に、同じ PR に入れる。** 一次の錨は判断が生まれたその場に置く印で、その場で昇格先の文書を書いてよい。closure（ゲート5）の昇格の判定は最後の確認である。実行するのはその枝の担当（委譲なら子）。別 PR に分けてよいのは owner が明示的にそう裁定したときだけ。
- **作業層に残った昇格**（仕様 §13.1 の (2)）: どの PR にも紐づかずに作業層（`.oe/`・`tmp/`）に残ったもの。枝を持たない作業で生まれたものと、枝の作業から出た昇格の取りこぼしがここに入る。ゲート6 で worktree 掃除の前に拾う。取りこぼしをここで拾ったときは、それ自体が逸脱で、昇格は別 PR になる。実行主体の置き場は未決（#305）。

## 確定版の5項目への答え

### (1) 枝の作業から出た昇格を実行するのは誰か

**その枝の担当である。委譲なら子である。** closure のチェックリストは判定までのまま変えない（#288 の 2026-08-05 の分担）。担当は closure の判定で `required` にしたものを、同じ枝で昇格先に書き、同じ PR に入れる。

書く場所は4か所で、正本は仕様の §13.1 の (1) に置く（DJ-2）。

- 仕様 §13.1 の (1)（正本）。
- 委譲の固定節の「昇格規則」。子は正本を開かずに固定節だけで動くことがあるため、ここにも実行者と締め切りを書く（#288 の 2026-08-07 の episode の判定表が、この前提を「子は正本を開かないことがある」と記録している）。
- `episode-retrospective`「昇格の判定」節の対象外の行と `required` の行。closure をする人が読む場所なので、「実行は本スキルの外」のままで、実行者がだれかを1文で示す。
- `unmet-gate-check` の due の表の「PR → merge」の行。owner は「実行側」で、due は「マージされるまで」である。

### (2) 締め切りは「遅くともマージ前」で、closure は最後の確認であること

**「closure で行う」とは書かない。** 新しい文面は全箇所で「遅くともマージ前に」「closure の判定は最後の確認」と書く。一次の錨は §12 の「昇格の印」のまま（判断が生まれたその場に印を置き、その場で書いてよい）である。closure に実行を寄せると、印を置いた時点で書く動機が弱まり、closure まで先送りされる。closure 側の義務（判定）は変えないので、最後のアンカーの役目もそのまま残る。

番兵として、新しい文面に「closure で昇格する」「closure で実行する」と読める文が入っていないことを I1 のゲートで確かめる（変更前にも0件なので受入ではなく番兵である）。

### (3) #288 の 2026-08-07 の判断（`required` に行き先を足す案の棄却）を見直すか

**見直す価値がある、と推奨する。見直しそのものはこの単位でやらず、#288（と #305）の側に渡す。**

2026-08-07 の episode は、行き先フィールドを退けた理由を3つ書いている。

1. 実行は定義上マージ後なので、closure 時点の `required` は常に未着地であり、機械で問うと設計上まだ着地しないものを不備として鳴らす。
2. 値域を閉じられない（当時の `required` 3件の行き先は issue 参照2件とリポジトリ相対パス1件で、既存の閉じた許可リストは後者を弾く）。
3. 「消費者が未決だから待つ」案を退けながら、消費者に依存する欄を足そうとしており、自己矛盾していた。

この単位の後では、枝の作業から出た昇格について理由1が成り立たなくなる。closure の時点で `required` は「同じ PR に入っている」か「マージ前に入る」かのどちらかで、入っていなければ不備である。これは #336 で3つのゲートがどれも止めなかった欠落を、機械で捕まえうる形である。理由2は弱まる（行き先は同じ PR の中のリポジトリ相対パスに限られる）。理由3は残る。

見直しで問うべきことは「`required` の枝の作業から出た昇格について、同じ PR の差分に昇格先があるかを確かめる検査を置くか。置くならフロントマターの欄か、PR の差分の検査か」である。作業層に残った昇格（理由1がまだ成り立つ側）には当てない。

### (4) この裁定の記録をこの PR に入れる（置き場と理由）

**decision を1本書き、棚卸し discussion に追補を1節足し、仕様の `related` に1行足す。** 3つともこの枝の PR に入れる。直す規則をこの PR 自身に当てる形になる（brief の「この委譲で加える規律」節）。

- decision の置き場: `projects/orchestration-engine/docs/decisions/2026-10-07-decision-411-branch-promotion-in-same-pr.md`（ULID は `01M4AEC4GBWY16MKCRRVDMRKZ9` を予約した）。
- 理由と棄却した案は DJ-1 に書いた。

### (5) 進行中の委譲への影響

**統括がマージ後に扱う。** この単位では、渡すことを下の「マージ後に統括へ渡すこと」節に書くだけにする。

## 設計判断

### DJ-1 裁定の記録は decision 1本・棚卸し discussion への追補1節・仕様の `related` 1行にする

- **decision にする理由**: `episode-retrospective`「置き場の判定」節は、確定した判断を decision に置く。2段目の4つの問いにも当たる。Q1（複数の解釈が live だった）: 「decision はマージ後に別 PR」と「同じ PR でマージ前」の2つの読みが実際に3回ぶつかった。Q2（覆すのに議論が要る）: 覆すには「PR を何の単位と見るか」という価値判断を戦わせ直す必要があり、実物を見ても決まらない。Q3（前提が将来偽になりうる）: 前提は「作業は PR の単位で着地する」で、PR を経ない流れになれば偽になる。Q4（同じ分岐が再訪される）: 枝の作業で decision が生まれるたびに同じ分岐に立つ。
- **木の選び方**: 直す対象の DJ-8 が `projects/orchestration-engine/docs/discussions/` にあり、doc-flow の decision（#284 の read/write 契約・#336 の見張り）も同じ木の `decisions/` に並んでいる。plan と episode を置く `docs/harness/` には `decisions/` がまだ無い。
- **追補と `related` を足す理由**: decision だけだと、DJ-8 を読んだ人は (6) が絞られたことに気づかない。discussion の追補だけだと、仕様から根拠へたどる道が無い。追補は DJ-8 の本文を書き換えず、末尾に新しい節として足す（範囲外の「過去の discussion の書き換え」には当たらず、brief の「歴史の記録は追記で扱う」に従う）。
- **棄却した案**:
  - discussion への追補だけにする。上の Q1〜Q4 に当たる確定した判断を discussion に置くと、`episode-retrospective` の置き場の判定と食い違う。
  - decision を `docs/harness/decisions/` に新しく作る。doc-flow の decision が2つの木に分かれ、読む人が探す場所が増える。
  - PR 本文だけに残す。PR 本文は蒸留の層ではなく、仕様の `related` から張れない。

decision の骨子（I1-1 で書く）:

- コンテキスト: (2) の字面と元の動機のずれ。hub の1回（#336・PR #387 の後の別 PR）と、統括の申し送りによる別リポジトリの2回。
- 決定: 枝の作業から出た昇格は同じ PR に入れてマージ前に着地させる。実行はその枝の担当で、closure の判定は最後の確認。DJ-8 の (6) の昇格は、作業層に残った昇格（取りこぼしの最後の網を含む）に絞る。分けてよいのは owner の明示の裁定だけ。
- 根拠: owner の原文の引用（#411 本文に公開済み・識別子を含まない）。PR は判断と根拠を一緒に着地させる単位で、分けると PR が根拠を欠いたまま着地する。knowledge は既に in-PR が既定である。(2) の元の動機は作業層の滞留で、それは (2) に残す。棄却した案（マージ後のままゲート6 に「decision の PR を立てる」工程を足す／「closure で行う」と書く／knowledge と同じ3つの例外を与える）。
- 結果: 変わる箇所の一覧。#288 の 2026-08-07 の判断の理由1が枝の作業から出た昇格について崩れること（見直しの推奨）。#305 の論点は作業層に残った昇格と catch-all に縮むこと。進行中の委譲は古い固定節を持っていること。

### DJ-2 実行者は仕様 §13.1 を正本にし、読む人ごとの3か所へ同じ内容を短く写す

- 採る形: 上の (1) のとおり。
- 棄却した案: 正本だけに書き、ほかはポインタにする。子は固定節だけで動くことがあり、#336 の子は固定節を読んだうえで「実行はゲート6」と書いた。ポインタだけでは同じ読み違いが残る。
- 棄却した案: `episode-retrospective` の closure のチェックリストに「実行したか」の項目を足す。2026-08-05 の分担（closure は判定まで）を変えることになり、範囲外である。見直しが要るなら (3) の #288 の側で扱う。

### DJ-3 2種類に名前を付け、全箇所で同じ名前を使う

- 採る形: 「枝の作業から出た昇格」と「作業層に残った昇格」。仕様の §13.1 の番号 (1)(2)(3) は残す。
- 棄却した案: #411 本文の (a)(b) を記号として canonical に持ち込む。§13.1 の (1)(2)(3) と並ぶと対応を取り違えやすく、記号は grep で拾いにくい。
- 棄却した案: 箇所ごとに読みやすい言い換えをする。同じものだと分からなくなり、受入の grep でも一致を見られなくなる。

### DJ-4 仕様のゲート表の行5 と routing 表の行5 に、枝の作業から出た昇格の最後の確認を置く（10か所の外）

- 採る形: 行5 の「ゲート」欄に「枝の作業から出た昇格が同じ PR に入っているかの最後の確認を含む」を足し、routing 欄に `§13` を足す。
- 棄却した案: 行6 だけを直す。行6 から昇格を作業層に残ったものに絞ると、ゲート表のどこにも枝の作業から出た昇格が現れない。表だけ読む人（routing 表は表がすべて）には居場所が無くなる。

### DJ-5 `unmet-gate-check` の例は、作業層に残った昇格の例として言い換えて残す

- 採る形: 「マージ後に due な、作業層に残った昇格の拾い上げが、完了境界で『該当しない』と扱われれば…」。
- 理由: 例の出所は #289 の事例2（#284 の一連でゲート6 の昇格確認を飛ばし、探索木を昇格せずに worktree を破棄して別 PR #287 が要った件）である。新しい定義では、その探索木は枝の作業から出たものの取りこぼしで、ゲート6 の拾い上げが最後の網だった。例が言いたいこと（not-yet-due を not-applicable に畳むと、後で確かめる主体が居なくなる）は、ゲート6 の拾い上げについて今も正しい。
- 棄却した案: 枝の作業から出た昇格の例に変える。こちらはマージ前に due なので、子の完了境界では not-yet-due にならず、例として成り立たない。
- 棄却した案: 例を消す。畳んだときの害を具体で示す役目が消える。

### DJ-6 作業層に残った昇格に、枝の作業から出た昇格の取りこぼしを含める

- 採る形: 仕様 §13.1 の (2) に「枝を持たない作業で生まれたものと、(1) の取りこぼしがここに入る。取りこぼしをここで拾ったときは、それ自体が逸脱で、昇格は別 PR になる」と書く。
- 理由: DJ-2 の動機（掃除で git の外に消えるのを防ぐ）は、取りこぼしについても同じく要る。#289 の事例2 がその実例である。
- 棄却した案: (2) を「枝を持たない作業で生まれたもの」だけに定義する。取りこぼしの行き場が定義から消え、掃除で消える経路が開く。

### DJ-7 枝の作業から出た昇格を別 PR に分けてよいのは、owner の明示の裁定だけにする

- 採る形: plan の着地先と同じ条件にする。
- 参照した先例: knowledge の収穫フローは「heavy で単独のレビューを要する／当該 PR の scope から明確に外れる／owner が明示的に defer を指示した」の3つで分けてよい。knowledge の in-PR の規律が成り立っている前提（採用した negative knowledge `01KZVHE0KQ5VCX0SXH0F4SM14D`）を decision について確かめた結果は次のとおりである。保存の人間ゲートを owner のマージで通す前提は decision にもある。収穫の実行者（Step 5）にあたるものは decision には無かったので、DJ-2 で書く。別 PR に分ける条件は、そのまま写さない。
- 棄却した案: knowledge と同じ3つの例外を与える。owner の裁定は「分けたら意味がない」であり、「heavy だから分ける」余地を残すと同じ分離がまた起きる。「scope から外れる」ものは、定義上その枝の判断ではないので、枝の作業から出た昇格に当たらない（範囲外として surface し、issue にする）。

## ゲート1 を SO で回さない理由

`predecision-exploration` は、設計を確定する前にゼロベースの SO を1回回すことを求める。この単位では回さない。理由は3つである。

- 設計の中心は owner の裁定で、owner はこの単位の設計SO（ゲート2）を「owner の裁定がそのまま設計」として省いた。
- plan で下した判断（DJ-1〜DJ-7）は、文面と記録の置き場の選び方で、戻すのが容易である。`predecision-exploration` の「いつ使わないか」（小さく低リスクで後戻りコストの低い判断）に当たる。
- 実装SO（ゲート4）が書いた文面そのものを外部のモデルで見る。

代わりに探索木を下に置く。owner がゲート3 で SO を求めるなら、I1 の前に `so-compare --codex-only` で回す。

```text
裁定を canonical へ落とす形
├── 案A: (2) を書き換えて「昇格はマージ前」だけにする → ❌ 作業層に残ったものの拾い上げ（DJ-2 の動機）が消える
├── 案B: (2) はそのまま、(1) に「枝の作業から出たものはマージ前」を足す → ❌ 字面の衝突（(2) が「昇格の実行はゲート6」のまま）が残り、#336 と同じ読みが続く
├── 案C: 2種類に名前を付けて (1)(2) を書き分け、10か所＋3か所を同じ名前でそろえる → ✅ 採用（DJ-3・DJ-4・DJ-6）
├── 案D: 実行を closure のチェックリストに移す → ❌ 2026-08-05 の分担を変える（範囲外）。一次の錨が closure に寄る（確定版の (2)）
└── 未探索: 機械の検査（PR の差分に昇格先があるか）で強制する形 → #288 / #305 の側（(3) の推奨）。この単位は文面の整合まで
```

## 直す箇所と直し方

番号は #411 本文の「そろえる箇所」の番号である。1b・7b・8b は洗い出しで足した10か所の外の箇所で、9 には #411 本文が挙げた行のほかに「PR → merge」の行を含める。各箇所の確かめ方は、下の「受入」節の検査 ID（`1-old` など）で指す。変更前の `2a659a8` では全項目が落ちることを確かめた。

### 1. 仕様 §11 ゲート表の行6

- いま: `| 6 | merge 後 | issue close 判断（keep-open 明示）+ worktree 掃除（親）+ 昇格判定（§13） | \`branch-finish\` + §13 |`
- 直した後: `| 6 | merge 後 | issue close 判断（keep-open 明示）+ 作業層に残った昇格の拾い上げ（worktree 掃除の前・§13.1 の (2)）+ worktree 掃除（親） | \`branch-finish\` + §13 |`
- 拾い上げを掃除の前に並べ、実行の順に合わせる。拾い上げの実行主体は書かない（#305）。
- 確かめ方: `1-old`・`1-new`。

### 1b. 仕様 §11 ゲート表の行5（10か所の外・DJ-4）

- いま: `| 5 | PR → merge | episode closure（マージ前・後追いは \`reconstructed\` 明示）→ owner マージ（HG） | \`episode-retrospective\` |`
- 直した後: `| 5 | PR → merge | episode closure（マージ前・後追いは \`reconstructed\` 明示。枝の作業から出た昇格が同じ PR に入っているかの最後の確認を含む・§13.1 の (1)）→ owner マージ（HG） | \`episode-retrospective\` + §13 |`
- 確かめ方: `1b-new`。

### 2. 仕様 §11「plan の着地先」段落

- いま: 「同じ枝で作った episode・knowledge もその枝の PR に載せる（knowledge を別 PR に分けてよい条件は `episode-retrospective` の収穫フローが持ち、そちらは owner の裁定を別途要さない）。」
- 直した後: 「同じ枝で作った episode・knowledge と、枝の作業から出た昇格（decision・discussion への追記・§13.1 の (1)）もその枝の PR に載せる。knowledge を別 PR に分けてよい条件は `episode-retrospective` の収穫フローが持ち、そちらは owner の裁定を別途要さない。枝の作業から出た昇格を別 PR に分けてよいのは、plan と同じく owner が明示的にそう裁定したときだけである。」
- 確かめ方: `2-old`・`2-new`。

### 3. 仕様 §13.1 判定タイミング (1)(2)

- いま:
  - (1) episode closure 時（§11 ゲート5・マージ前）＝ 昇格候補の洗い出し（episode の「蒸留シグナル / 昇格候補」節）。
  - (2) 昇格の実行は §11 ゲート6（merge 後の後始末）＝ worktree 掃除の前に行う（掃除で git の外に消えるのを防ぐ）。
- 直した後（(3) の catch-all は変えない）:

  ```markdown
  - **判定タイミング**: 昇格は出どころで2種類に分け、それぞれに締め切りと拾う位置を置く。
    - (1) **枝の作業から出た昇格**: その枝の作業（plan・episode・closure と、枝の作業で使った作業層の文書や `tmp/` の証跡）から出た設計級 / durable なもの。**遅くともマージ前に、同じ PR に入れる**（枝の作業の中で生まれた判断は、その PR の一部として着地させる。分けると PR が判断の根拠を欠いたまま着地する）。一次の錨は判断が生まれたその場に置く印（§12）で、その場で昇格先の文書を書いてよい。episode closure（§11 ゲート5）の昇格の判定は**最後の確認**にあたる。closure の担当は判定までで（`episode-retrospective`）、**実行するのはその枝の担当**（委譲なら子）である。別 PR に分けてよいのは、owner が明示的にそう裁定したときだけである。
    - (2) **作業層に残った昇格**: どの PR にも紐づかずに作業層（`.oe/`・`tmp/`）に残ったもの。枝を持たない作業で生まれたものと、(1) の取りこぼしがここに入る。§11 ゲート6（merge 後の後始末）で **worktree 掃除の前**に拾う（掃除で git の外に消えるのを防ぐ）。(1) の取りこぼしをここで拾ったときは、それ自体が逸脱であり、昇格は別 PR になる。実行主体の置き場は未決である。
    - (3) （変更なし）
  ```

- 確かめ方: `3-old1`・`3-old2`・`3-new1`・`3-new2`。

### 4. 仕様 §13.6 の1行版

- いま: 「設計級コンテンツは closure / 掃除の前に discussion / decision へ昇格し、committed→working の参照は昇格先へ張り替える（grep で substance の実在を確認）。収穫基準を満たす…（以下同じ）」
- 直した後: 「枝の作業から出た昇格（設計級コンテンツ）は、遅くともマージ前に同じ PR で discussion / decision へ入れる（実行はその枝の担当で、closure の判定は最後の確認）。作業層に残った昇格は worktree 掃除の前に拾う。committed→working の参照は昇格先へ張り替える（grep で substance の実在を確認）。収穫基準を満たす…（以下同じ）」
- 確かめ方: `4-old`・`4-new`。

### 5. 固定節 plan-first

- いま: 「同じ枝で作った episode・knowledge もその枝の PR に載せる（別 PR に分けてよい条件は `episode-retrospective` の収穫フローが持ち、そちらは owner の裁定を別途要さない）。」
- 直した後: 「同じ枝で作った episode・knowledge と、枝の作業から出た昇格（decision・discussion への追記）もその枝の PR に載せる（knowledge を別 PR に分けてよい条件は `episode-retrospective` の収穫フローが持ち、そちらは owner の裁定を別途要さない。枝の作業から出た昇格を別 PR に分けてよいのは、owner が明示的に裁定したときだけ）。」
- 確かめ方: `5-old`・`5-new`。

### 6. 固定節 昇格規則

- いま: 「**昇格規則**: 設計級 / durable な知見は closure・worktree 掃除の前に discussion / decision へ昇格し、committed→working の参照は昇格先へ張り替える（詳細 …〔§13〕・1行版〔§13.6〕）。」
- 直した後: 「**昇格規則**: 枝の作業から出た昇格（設計級 / durable な知見）は、**遅くともマージ前に** discussion / decision へ昇格して**この枝の PR に入れる**。**実行するのは枝の担当（委譲なら子）**で、closure の昇格の判定は最後の確認である（`required` と判定したものを「実行はゲート6」として残さない）。作業層に残った昇格は、ゲート6 で worktree 掃除の前に拾う。committed→working の参照は昇格先へ張り替える（詳細 …〔§13〕・1行版〔§13.6〕）。」
- 確かめ方: `6-old`・`6-new`。

### 7. routing 表の行6

- 仕様 §11 の表と 1:1 の索引なので、1 と同じ文面にする（routing 欄は今のまま `branch-finish` + `document-format.md`〔§13〕）。
- 確かめ方: `7-old`・`7-new`。

### 7b. routing 表の行5（10か所の外・DJ-4）

- 1b と同じ文面にする。routing 欄は `episode-retrospective` + `document-format.md`〔§13〕。
- 確かめ方: `7b-new`。

### 8. `episode-retrospective`「昇格の判定」節の対象外

- いま: 「**対象外**: **昇格の実行**（`document-format.md`「昇格義務」節の判定タイミング (2) が merge 後に置いている）／作業層 doc だけに在る設計級コンテンツの昇格（同節が §13 全体で扱う）／closure を通らない滞留経路の catch-all（同 (3)）。**これらの実行主体は本スキルではなく、置き場は未決である。**」
- 直した後: 「**対象外**: **昇格の実行**（`document-format.md`「昇格義務」節の判定タイミングが、出どころで2種類に分けて置いている。枝の作業から出た昇格は、その枝の担当が遅くともマージ前に同じ PR で行い、本節の判定はその最後の確認にあたる。作業層に残った昇格は、ゲート6 で worktree 掃除の前に拾う）／作業層 doc だけに在る設計級コンテンツの昇格（同節が §13 全体で扱う）／closure を通らない滞留経路の catch-all（同 (3)）。**枝の作業から出た昇格の実行主体はその枝の担当である。それ以外の実行主体は本スキルではなく、置き場は未決である。**」
- 「判定まで」という分担そのものは変えない（範囲外）。直すのは実行の時点を指している理由の部分だけである。
- canonical のスキルなので、hub 固有の issue 番号やパスを足さない。
- 確かめ方: `8-old`・`8-new`。

### 8b. `episode-retrospective`「昇格の判定」節の `required` の行（10か所の外）

- いま: 「**`required`** — 昇格が要る。**層は下記「置き場の判定」で選ぶ。実行は本スキルの外である**（negative knowledge だけは Step 5 が in-PR で実行する）。」
- 直した後: 「**`required`** — 昇格が要る。**層は下記「置き場の判定」で選ぶ。実行は本スキルの外である**（枝の作業から出た昇格は、その枝の担当が遅くともマージ前に同じ PR へ入れる。negative knowledge だけは Step 5 が in-PR で実行する）。」
- 理由: 「negative knowledge だけは … in-PR」が「in-PR なのは knowledge だけ」と読める。
- 確かめ方: `8b-old`・`8b-new`。

### 9. `unmet-gate-check` の due の表

規範が枝の作業から出た昇格に課す締め切りと、検査の側がそれを due と見る位置を、別々に書いて突き合わせる（採用した negative knowledge `01KYJ76D7CS7EBY3WDYY1NS9Y2`）。

| | 規範（仕様 §13.1） | 検査（due の表） | 突き合わせ |
|---|---|---|---|
| 枝の作業から出た昇格 | 遅くともマージ前・実行は枝の担当 | 行「PR → merge」・owner 実行側・due「マージされるまで」 | 一致する |
| 作業層に残った昇格 | ゲート6・worktree 掃除の前 | 行「merge 後」・owner 依頼側 / 人間の承認者・due「マージより後」 | 一致する |

- 行「PR → merge」 いま: `| PR → merge のゲート（closure・昇格候補の洗い出し） | 実行側 | マージされるまで |` → 直した後: `| PR → merge のゲート（closure・昇格の判定・枝の作業から出た昇格の実行） | 実行側 | マージされるまで |`
- 行「merge 後」 いま: `| **merge 後のゲート**（issue の close 判断・掃除・昇格の実行） | …` → 直した後: `| **merge 後のゲート**（issue の close 判断・作業層に残った昇格の拾い上げ・掃除） | …`（owner と due の欄は変えない）
- 検査の表に合わせて規範を書き換えない。規範を先に決め、表をそれに合わせる。
- 確かめ方: `9-old1`・`9-old2`・`9-new1`・`9-new2`。

### 10. `unmet-gate-check` の判定規則の例

- いま: 「（**事故の実例がここにある**——マージ後に due な昇格確認が、完了境界で「該当しない」と扱われれば、その後に確かめる主体が居なくなる）」
- 直した後: 「（**事故の実例がここにある**——マージ後に due な、作業層に残った昇格の拾い上げが、完了境界で「該当しない」と扱われれば、その後に確かめる主体が居なくなる）」
- 決めたこと: 作業層に残った昇格の例として残す（DJ-5）。
- 確かめ方: `10-old`・`10-new`。

### 記録（DJ-1）

- decision を新しく書く（上の骨子）。
- 棚卸し discussion の末尾に「## 9. 追補（2026-10-07・#411）」を足す。中身は「DJ-8 の (6) の昇格判定は、作業層に残った昇格の拾い上げに絞った。枝の作業から出た昇格は、ゲート5 の closure を最後の確認にして、同じ PR でマージ前に着地させる。裁定と根拠は decision（パス）にある。DJ-8 の本文は当時の合意として書き換えない。」の3文程度。
- 仕様の `related` に `derived_from` で decision を1行足す（reason は「『昇格義務』節の判定タイミングを出どころで2種類に分けた裁定」）。

## 受入

### 受入の項目

- [ ] 10か所と10か所の外の3か所が、2種類の名前で同じ向きを指している。検査 `1-*`〜`10-*` が全て PASS。変更前の `2a659a8` では29項目すべてが FAIL することを確かめ済み（episode の「Step 3: 受入の grep を変更前の master で確かめた」節）。
- [ ] 枝の作業から出た昇格を「マージ後」と読める文が canonical に残っていない。検査 `G` が PASS（変更前は8行に当たって FAIL）。
- [ ] 確定版の5項目それぞれに、この plan の「確定版の5項目への答え」節か成果物の中で答えがある。(1)(2) は成果物の文面、(3)(5) はこの plan、(4) は decision・追補・`related` の3つ。
- [ ] この裁定の記録（decision・追補・`related`）が、この枝の PR に入っている。`git diff --name-only origin/master...HEAD` に decision のパスと棚卸し discussion のパスが出る。
- [ ] sync の起動テストが通る。`projects/orchestration-engine/tests/test_sync_claude_statusline.sh` と `test_sync_output_styles.sh` の2本。
- [ ] 番兵（受入ではない）: 新しい文面に「closure で昇格」「closure で実行」と読める文が無い（`git grep -n -E 'closure ?(で|に) ?(昇格|実行)' -- canonical` が0件）。

### 検査のスクリプト

作業層の `tmp/411-promotion-timing/check.sh`（gitignored）に置いた。中身はここに写しておく。新しい文面を実装SO や Copilot の指摘で変えたときは、このスクリプトの新しい側の文字列を同じ変更で直し、episode に記録する。

```bash
#!/usr/bin/env bash
# #411 の受入の検査。repo root で実行する。
#   引数なし: 作業ツリー（変更後）を検査する
#   引数あり: その commit を検査する（変更前は 2a659a8）
# 全項目が PASS なら exit 0、1つでも FAIL なら exit 1。
set -u
ref="${1:-}"

count() { # count <file> <fixed-string>
  if [ -n "$ref" ]; then
    git show "$ref:$1" | grep -c -F -- "$2"
  else
    grep -c -F -- "$2" "$1"
  fi
}

DF=canonical/orchestration-spec/document-format.md
GR=canonical/skills/doc-flow-guardrail/SKILL.md
ER=canonical/skills/episode-retrospective/SKILL.md
UG=canonical/skills/unmet-gate-check/SKILL.md

fail=0
check() { # check <id> <file> <expected-count> <fixed-string>
  local n
  n=$(count "$2" "$4")
  if [ "$n" -eq "$3" ]; then
    printf 'PASS\t%s\t%s=%s\n' "$1" "$n" "$3"
  else
    printf 'FAIL\t%s\t%s!=%s\t%s\n' "$1" "$n" "$3" "$4"
    fail=1
  fi
}

check 1-old  "$DF" 0 '掃除（親）+ 昇格判定（§13）'
check 1-new  "$DF" 1 '作業層に残った昇格の拾い上げ（worktree 掃除の前'
check 1b-new "$DF" 1 '枝の作業から出た昇格が同じ PR に入っているかの最後の確認'
check 2-old  "$DF" 0 '同じ枝で作った episode・knowledge もその枝の PR に載せる'
check 2-new  "$DF" 1 '枝の作業から出た昇格（decision・discussion への追記'
check 3-old1 "$DF" 0 '昇格**候補の洗い出し**（episode の'
check 3-old2 "$DF" 0 '**昇格の実行**は §11 ゲート6'
check 3-new1 "$DF" 1 '(1) **枝の作業から出た昇格**'
check 3-new2 "$DF" 1 '(2) **作業層に残った昇格**'
check 4-old  "$DF" 0 '設計級コンテンツは closure / 掃除の前に'
check 4-new  "$DF" 1 '> 枝の作業から出た昇格（設計級コンテンツ）は、遅くともマージ前に'
check 5-old  "$GR" 0 '同じ枝で作った episode・knowledge もその枝の PR に載せる'
check 5-new  "$GR" 1 '枝の作業から出た昇格（decision・discussion への追記'
check 6-old  "$GR" 0 '設計級 / durable な知見は closure・worktree 掃除の前に'
check 6-new  "$GR" 1 '**昇格規則**: 枝の作業から出た昇格'
check 7-old  "$GR" 0 '掃除（親）+ 昇格判定 |'
check 7-new  "$GR" 1 '作業層に残った昇格の拾い上げ（worktree 掃除の前'
check 7b-new "$GR" 1 '枝の作業から出た昇格が同じ PR に入っているかの最後の確認'
check 8-old  "$ER" 0 '判定タイミング (2) が merge 後に置いている'
check 8-new  "$ER" 1 '枝の作業から出た昇格の実行主体はその枝の担当である'
check 8b-old "$ER" 0 '実行は本スキルの外である**（negative knowledge だけは'
check 8b-new "$ER" 1 '枝の作業から出た昇格は、その枝の担当が遅くともマージ前に同じ PR へ入れる'
check 9-old1 "$UG" 0 '（issue の close 判断・掃除・昇格の実行）'
check 9-old2 "$UG" 0 '（closure・昇格候補の洗い出し）'
check 9-new1 "$UG" 1 '（issue の close 判断・作業層に残った昇格の拾い上げ・掃除）'
check 9-new2 "$UG" 1 '（closure・昇格の判定・枝の作業から出た昇格の実行）'
check 10-old "$UG" 0 'マージ後に due な昇格確認が'
check 10-new "$UG" 1 'マージ後に due な、作業層に残った昇格の拾い上げが'

re='昇格の実行[^。|]*(merge 後|マージ後|ゲート ?6)|(merge 後|マージ後)[^。|]*昇格の実行|merge 後に置いている|closure ?[/・] ?(worktree )?掃除の前に|昇格判定（§13）|掃除（親）\+ 昇格判定|マージ後に due な昇格確認'
if [ -n "$ref" ]; then
  g=$(git grep -n -E -e "$re" "$ref" -- canonical | wc -l | tr -d ' ')
else
  g=$(git grep -n -E -e "$re" -- canonical | wc -l | tr -d ' ')
fi
if [ "$g" -eq 0 ]; then printf 'PASS\tG\t%s=0\n' "$g"; else printf 'FAIL\tG\t%s!=0\n' "$g"; fail=1; fi

exit "$fail"
```

変更前の結果（2026-10-07・`bash tmp/411-promotion-timing/check.sh 2a659a8`）: 29項目すべて FAIL・exit 1。`shellcheck` は警告なし。

plan の文面の試し当て（2026-10-07）: `2a659a8` の canonical を作業ツリーの外に写し、この plan の「直す箇所と直し方」の「直した後」の文面をそのまま置き換えて検査した。29項目と `G` がすべて PASS・exit 0、番兵は0件、差分は4ファイル・16行の置き換えだった。置き換えに使ったスクリプトは `tmp/411-promotion-timing/dryrun-apply.py`（gitignored）にある。I1 の編集は Edit で行い、このスクリプトは突き合わせにだけ使う。

## ステップ

**I1 以降は、統括から「実装へ」が届いてから進む。** P1〜P3 はこの委譲の終端までの工程である。

### P1: worktree・episode の枠・plan（完了）

- worktree: `docs/#411_promotion_timing_in_pr`（`2a659a8` から）。
- episode: `docs/harness/episodes/2026-10-07-episode-411-promotion-timing-in-pr.md`。
- plan: この文書。

### P2: plan と episode をこの枝にコミットして push する

```bash
git -C '<worktree>' add docs/harness/plans/2026-10-07-plan-411-promotion-timing-in-pr.md docs/harness/episodes/2026-10-07-episode-411-promotion-timing-in-pr.md
git -C '<worktree>' commit -m 'docs(harness): #411 の plan と episode の枠を置く'
git -C '<worktree>' push -u origin 'docs/#411_promotion_timing_in_pr'
```

PR はまだ作らない。

### P3: 報告して止まる

- `.oe/report-411.md` に報告を書き、報告の宛先へ `oe-send` で1行送り、exit code を確かめて止まる。

### GATE 3: owner の plan 承認（統括から「実装へ」が届くまで待つ）

### I1-0: baseline の確認

```bash
git -C '<worktree>' fetch origin
git -C '<worktree>' log --oneline 2a659a8..origin/master -- canonical/orchestration-spec/document-format.md canonical/skills/doc-flow-guardrail canonical/skills/episode-retrospective canonical/skills/unmet-gate-check
```

- 出力が空なら進む。4ファイルのどれかが master で動いていたら、止まって統括へ報告する（rebase してから直すか、plan を直すかは統括が決める）。

### I1-1: 裁定の記録を書く（1コミット）

- decision（`projects/orchestration-engine/docs/decisions/2026-10-07-decision-411-branch-promotion-in-same-pr.md`・ULID `01M4AEC4GBWY16MKCRRVDMRKZ9`）を `spec-card` の形で書く。
- 棚卸し discussion の末尾に追補の節を足す。
- 仕様の `related` に1行足す。
- コミット: `docs(orchestration): #411 枝の作業から出た昇格を同じ PR に入れる裁定を記録する`

### I1-2: canonical の4ファイルを書き分ける（1コミット）

- 上の「直す箇所と直し方」の 1・1b・2・3・4（仕様）、5・6・7・7b（固定節と routing 表）、8・8b（`episode-retrospective`）、9・10（`unmet-gate-check`）。
- 編集は箇所ごとに Edit で行う（日本語の文書なので heredoc では追記しない）。
- コミット: `docs(spec): #411 昇格を枝の作業から出たものと作業層に残ったものに書き分ける`

### GATE I1: 受入の検査と差分の範囲

```bash
cd '<worktree>' && bash tmp/411-promotion-timing/check.sh; echo "exit=$?"
cd '<worktree>' && git grep -n -E 'closure ?(で|に) ?(昇格|実行)' -- canonical; echo "exit=$?"
git -C '<worktree>' diff --name-only origin/master...HEAD
```

- 1本目は exit 0（全 PASS）。2本目は一致0件（exit 1）。3本目に出るのは plan・episode・decision・棚卸し discussion と canonical の4ファイルだけ。
- 結果を episode に追記する。

### I2-1: sync の起動テスト

```bash
cd '<worktree>' && bash projects/orchestration-engine/tests/test_sync_claude_statusline.sh; echo "exit=$?"
cd '<worktree>' && bash projects/orchestration-engine/tests/test_sync_output_styles.sh; echo "exit=$?"
```

- worktree から `./scripts/sync.sh` は実行しない（`~/.claude` のリンクが worktree を指して、掃除のあとに切れる）。

### I2-2: 実装SO（弱・Codex 1レーン）

- プロンプトを `tmp/411-promotion-timing/so-impl-prompt.md` に書く。見てもらう観点は4つ: (1) 10か所と3か所が2種類の名前で同じ向きを指しているか、(2) 枝の作業から出た昇格を「マージ後」と読める文が残っていないか、(3) 作業層に残った昇格の実行主体（#305）や closure の分担（判定まで）に踏み込んでいないか、(4) canonical のスキルに hub 固有のパスや issue 番号を足していないか。
- 実行:

  ```bash
  cd '<worktree>' && SO_TIMEOUT=300 so-compare -w "$(pwd)" -f tmp/411-promotion-timing/so-impl-prompt.md -o tmp/411-promotion-timing/so-impl --codex-only; echo "exit=$?"
  ```

- 実返却が0なら弱 SO の「0 はなし」に当たるので、再試行してもだめなら止まって統括へ報告する。
- 採否を episode に書く。直したら GATE I1 の検査を回し直す。

### I2-3: PR を作り、Copilot のレビューを依頼する

- `pr-conventions` に従う。本文に plan・episode・decision へのリンクと、受入の結果を書く。`Closes` ではなく `Refs #411`（issue の close は統括の判断）。
- `gh pr edit <PR> --add-reviewer @copilot` でレビューを依頼する。

### I2-4: Copilot の指摘に1ラウンド応える

- `copilot-review-response` に従い、未返信のスレッドだけを扱う。再依頼はしない（統括の明示の指示があるときだけ）。
- 直したら GATE I1 の検査を回し直す。

### I3: episode の closure（マージ前）

- `episode-retrospective` に従う。tier は実装SO を明示起動するので heavy になる見込みで、Step 4 は外部チェックか辞退の定型を残す。
- `promotion` を1判定1エントリで埋める。この単位の裁定の decision が同じ PR に入っていること（直した規則を自分に当てた結果）を確かめる。
- Step 6: brief の negative knowledge の6件すべてに観測を1レコードずつ書き戻し、`validate-knowledge` を通す。注入された id を episode に1行残す。
- 報告して止まる。マージ・worktree の掃除・issue の close はしない。

## マージ後に統括へ渡すこと

この単位では扱わず、マージ後に統括が扱うものである。報告と PR 本文に同じ一覧を書く。

1. **進行中の委譲への周知。** hub と別リポジトリで走っている子は、古い固定節（昇格規則と plan-first の文）を brief に持ったまま動いている。そのままだと「実行はゲート6」と読みうる。新しい昇格規則（枝の作業から出た昇格は自分が同じ PR でマージ前に入れる）を伝える。
2. **完了前の照合の baseline。** 承認時に固定節とゲート表の版の digest を記録した委譲で、完了前の照合（`unmet-gate-check`）を新しい版で回すと `invalid-baseline` になる。古い版のまま照合するか、新しい規則を伝えたうえで再承認して baseline を記録し直すかを決める（同スキルの「意図的に方針を変えるとき」）。
3. **配布。** マージ後に master から `./scripts/sync.sh` を実行する（owner か統括・ゲート6）。仕様は sync で3ツールへ配られ、スキルは master の作業ツリーへの symlink なので、マージで反映される。
4. **#305 への申し送り。** 枝の作業から出た昇格の実行主体はこの単位で決まった（その枝の担当）。#305 の論点は、作業層に残った昇格と catch-all の実行主体に縮んだ。
5. **#288 への申し送り。** 2026-08-07 の判断の理由1が、枝の作業から出た昇格について成り立たなくなった。見直しの推奨は上の (3) にある。
6. **#411 の close の判断。**

## 範囲外で気づいたこと（実装しない）

- 「SO モード」節〔§4.1〕の `so.design` には、owner がゲート2 を省いたときの値が無い（値域は weak / strong だけ）。この plan は `omitted` と書き、値域の外であることを注記した。検査する仕組みは今のところ無いので実害は無いが、同じ形の単位が続くなら値域に足すかを決める必要がある。行き先は統括の判断に委ねる。
- canonical の配布物を直す単位の plan と episode が、`docs/harness/` と `docs/orchestration-engine/` の2つの木に分かれている（#288 は後者、#403 は前者）。この単位では直さない。

## リスク・未確認事項

- 別リポジトリの2回は未確認である。decision の「コンテキスト」には統括の申し送りとして書く。
- 新しい名前（「枝の作業から出た昇格」「作業層に残った昇格」）は長い。表の欄が読みにくくなる場合は、Copilot や実装SO の指摘を受けて短くする。そのときは名前を全箇所で同じに変え、検査のスクリプトも同じ変更で直す。
- 固定節は統括が brief に貼るたびに写されるので、マージ前に組まれた brief には古い文が残る（「マージ後に統括へ渡すこと」の1）。

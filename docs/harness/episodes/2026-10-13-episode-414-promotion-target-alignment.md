---
id: "01M4SV5Y4WSHK4KSFD2X4604MW"
title: "#414 委譲の固定節と1行版の昇格先を、仕様の選び方にそろえる"
date: 2026-10-13
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/414"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/414#issuecomment-6138328567"
    reason: "着手時の認識合わせの確定版（統括が投稿）"
  - type: relates_to
    ref: "docs/harness/episodes/2026-10-07-episode-411-promotion-timing-in-pr.md"
    reason: "このずれを実装SO と Copilot が指摘した出どころ"
tags: [doc-flow, promotion, document-format, doc-flow-guardrail]
---

# #414 委譲の固定節と1行版の昇格先を、仕様の選び方にそろえる

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

委譲の固定節（`doc-flow-guardrail` の「昇格規則」）と、仕様の「昇格義務」節の1行版（§13.6）は、昇格先を discussion と decision の2つに限って書いていた。仕様の「昇格先の型選択」節（§13.3）は内容の種類で選ぶ（discussion・decision・episode・knowledge store）。固定節は以後のすべての委譲の brief にそのまま貼られるので、短い版だけを読む子は、episode や knowledge store へ置くべきものまで discussion か decision に押し込みうる。#411 の実装SO と Copilot が別々にこのずれを指摘し、#411 の範囲外として分けられた。

統括の brief（軽微修正4件の束の U3）。認識合わせは統括が通した確定版（related の2件目）を前提にする。確定版の要点は次のとおり。

- 4つを短く並べたうえで、正本の節を指す。§13.3 の本文は変えない。
- 短い版では「第3の昇格先」のような番号を使わない。
- 固定節の plan-first の項と、仕様の「plan の着地先」の段落は直さない（同じ文の中で episode と knowledge を別に挙げているため）。
- 配布物の変更なので、マージ後に統括が sync を回す。

owner の承認（2026-10-13）により、plan と設計SO（ゲート2）は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドは省かない。

## 作業の記録

### 確定版の照合と、brief・issue の断定の当て直し（2026-10-13）

- issue-intake の 1-2 の手順で、#414 の認識合わせのコメントを全件から探した。最後の1件は `confirmed`・見出し4つで、URL は統括が送った確定版と文字列として一致した。自分では認識合わせを通し直さない。
- 短い版の2か所（`canonical/skills/doc-flow-guardrail/SKILL.md:93`・`canonical/orchestration-spec/document-format.md:744`）は、master `a8e8726` で issue と brief のとおり「discussion / decision」と書いていた。
- **1行版は knowledge store に別の文で触れていて、そこで「第3経路」と番号を使っていた。** issue は「knowledge store は別の文で触れている」とだけ書き、番号には触れていない。確定版の「短い版では番号を使わない」に従い、4つを並べる形にするときにこの番号も外す。
- 配布物（`canonical/`）で「discussion / decision」と書くのは、この2か所のほかに §13.3 の中の「作業層 plan の扱い」（`document-format.md:725`）だけだった。これは正本の §13.3 の本文で、plan に残る設計級部分の行き先を述べた文である。確定版の「§13.3 の本文は変えない」に従い触らない。
- 固定節の文面を機械で照合している仕組みは無かった（`bin/`・`lib/`・`scripts/`・hooks・tests を grep した）。
- brief が挙げた手本の言い方（`canonical/skills/episode-retrospective/SKILL.md:145`）は「探索の軌跡は discussion / 確定した判断は decision / 実行記録は episode / 再発する失敗の型は knowledge item（Step 5）」で、§13.3 の「durable な証拠・知見」の行を持たない。

### 2か所を書き換え、§13.3 と1語ずつ突き合わせた（2026-10-13）

固定節と1行版のどちらも、「discussion / decision へ」をやめ、「昇格先は内容の種類で選ぶ」と書いたうえで、§13.3 の各行を同じ順で短く並べた。固定節は正本の節を節タイトルと番号で指し（`document-format.md`「昇格先の型選択」節〔§13.3〕）、1行版は同じ文書の中なので `§13.3` で指す。1行版の最後にあった knowledge store の文は列挙の中へ移し、番号（「第3経路」）を外した。置き場（`knowledge/items/`・§3.4）と、別 PR に分けてよい条件の参照はそのまま残した。

negative knowledge `01KZKASNHQ2WSJ3RM9XG435S2F`（まとめた一文は群の中で最も強い主張に引きずられる）に従い、短い版が §13.3 より強いことや狭いことを言っていないかを行ごとに見た。

| §13.3 の行 | 短い版（固定節・1行版とも同じ言い方） | 判定 |
|---|---|---|
| 昇格先は内容の種類で選ぶ（昇格元の型は問わない） | 昇格先は内容の種類で選ぶ | 括弧の補足を落としただけで、主張は同じ |
| 探索・却下・軌跡が主 → discussion | 探索・却下・軌跡が主なら discussion | 同じ |
| 確定した判断 → decision | 確定した判断なら decision | 同じ |
| 実行記録 → episode | 実行記録なら episode | 同じ |
| durable な証拠・知見（監査・再現条件）→ 文脈により episode / decision | durable な証拠・知見は文脈により episode か decision | 例示を落としただけで同じ |
| negative knowledge で収穫基準（非自明・再発しうる・行動を変える）を満たすもの → 型付き knowledge store へ収穫 | 収穫基準を満たす negative knowledge は型付き knowledge store（1行版は「へ収穫する」） | 基準の中身は名前で指すだけで、範囲は同じ。最初は固定節で「型付き」を落としていたので、§13.3 の呼び方に合わせて足した |
| 基準を満たさない negative knowledge は episode 本文に残す | （書いていない） | 書いていないだけで、反対のことは言っていない。正本の節を指しているので、そこで読める |
| これが第3の昇格先 | （書いていない） | 確定版の「短い版では番号を使わない」に従った |

短い版の主語の括弧書き（固定節は「設計級 / durable な知見」、1行版は「設計級 / durable なもの」）と、1行版の置き場の言い方（「蒸留木ルート直下」）は、変更前からの文で、昇格先の書き方とは別なので触っていない。

### 受け入れの検査を、変更前で落ちるものに絞った（2026-10-13）

検査は、2か所の短い版の行を取り出して語を数える形にした。変更後と、変更前の master `a8e8726` の両方に当てた。

| 検査 | 変更前 | 変更後 |
|---|---|---|
| 配布物で「discussion / decision」と書く行 | 3（§13.3 の 725 行・1行版・固定節） | 1（§13.3 の 725 行だけ） |
| 1行版の「第3」 | 1 | 0 |
| 「探索・却下・軌跡」が短い版にあるか（固定節・1行版） | 0・0 | 1・1 |
| 「文脈により episode か decision」が短い版にあるか（固定節・1行版） | 0・0 | 1・1 |

最初は「episode」「knowledge store」「§13.3」の語があるかも数えていた。変更前に当てると、固定節は「episode の follow-up」で episode が、1行版は別の文で knowledge store と §13.3 が、すでに出てくる。つまり変更前でも通ってしまい、変更そのものを見る検査にならない。negative knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ` に従い、受け入れの検査からは外した。

### 同じ型を横に探した（2026-10-13）

言い回しの順序や接続の違う形（「decision / discussion」「discussion・decision」「discussion か decision」など）まで広げて `canonical/` を探した。一致したのは、確定版が直さないと決めた固定節の plan-first の項と仕様の「plan の着地先」の段落、文書の型を並べただけの `spec-card` の説明文だけだった。昇格先を2つに限る短い版は、この2か所のほかに残っていない。

**brief が「§13.3 にそろえた短い言い方」として挙げた `episode-retrospective` の 145 行は、§13.3 と完全には合っていなかった。** 「再発する失敗の型は knowledge item」は、§13.3 の「収穫基準（非自明・再発しうる・行動を変える）を満たす negative knowledge」のうち「再発しうる」だけを言っており、その1文だけを読むとほかの2つの基準を落としたぶん広く読める。（後注: 実装SO の指摘で、同じスキルの 141 行が正本を優先すると明記し、145 行が指す Step 5 に3つの基準がそろっていると分かった。スキル全体として収穫の範囲が広がっているとまでは言えない。「広い」はこの1文だけの評価である。）また「durable な証拠・知見は文脈により episode / decision」の行を持たない。negative knowledge `01KYMRE1NC7XX6N66RQ0MGGHF1` に従い、brief の断定はそのまま写さず、この単位の手本には §13.3 そのものを使った。145 行は確定版の範囲（2か所）の外なので直さず、統括への報告に書く。

昇格の印: 短い版を正本にそろえるときは、手本とされた別の短い版ではなく正本そのものと突き合わせる（手本の短い版も正本からずれていることがある）

### 実装SO（ゲート4・弱・Codex 1レーン）で、範囲外の短い言い方がもう1か所見つかった（2026-10-13）

依頼文は `tmp/414/so-impl-prompt.md`（作業層・gitignore）で、5つの仮定（§13.3 との食い違いが無い・確定版の各項目に答えがある・他の部分の意味が変わらない・2か所のほかに短い版が残っていない・番号を外しても本文と矛盾しない）の反証を求めた。Codex は 129 秒で返した（`timeout_status=success`・リトライなし）。

- 仮定1・2・3・5は「成り立つ」だった。仮定3では、固定節の「入るのは」以降が変更前と文字列として一致し、1行版も担当・closure・関係ない判断・掃除前の拾い上げ・張り替え・別 PR の条件の各文を保っていると確かめられた。
- **仮定4は成り立たない（重大度 低・変更前からあり・差分の外）。** 仕様の「方向転換の記録」節（§14・`document-format.md:753`）が「既存の昇格ゲート（episode closure → decision・§13）」と書いており、その文だけを読むと、却下の軌跡も decision に寄せる読み方ができる。
  - **採否: 直さず、統括への報告と PR 本文に書く。** 確定版の範囲は2か所で、この文は方向転換の記録の長期価値の判定を昇格ゲートに任せる文である。§13 への参照は付いている。この単位で直すと確定版の範囲を広げることになる。
- **`episode-retrospective` の 145 行への自分の評価が強すぎた。** 同じスキルの 141 行が正本を優先すると明記し、Step 5 に3つの基準がそろっているので、スキル全体として収穫の範囲が広がっているとは言えない。
  - **採否: 採った。** 本文の評価を「その1文だけを読むと広く読める」に弱め、後注を付けた（`本文: 同じ型を横に探した（2026-10-13）`）。

変更した2行に欠陥は見つからなかったので、差分は変えていない。

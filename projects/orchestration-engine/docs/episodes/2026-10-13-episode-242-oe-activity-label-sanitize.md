---
id: "01M4SSP018X3037Q7MC99A384V"
title: "#242 oe-activity の label を会話到達面で無害化する"
date: 2026-10-13
type: episode
status: stable
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/242"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/pull/421"
    reason: "この episode が記録する作業の PR"
tags: [orchestration, oe-activity, oe-ack, sanitize, malform-hygiene]
promotion:
  - subject: "制御文字の畳みを jq の値へ足すときは、型が文字列でない値で投影全体が落ちないかを見る"
    verdict: required
    ref: "本文: 手本の形をそのまま写すと、数値の label で表示全体が落ちる（2026-10-13）"
  - subject: "oe-ack は label を出す経路が無いので変えない"
    verdict: not-required
    ref: "本文: brief と issue の断定を当て直した（2026-10-13）"
  - subject: "無害化の核の規則を label にもそのまま当てる"
    verdict: not-required
    ref: "本文: 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）"
  - subject: "jq 側の畳みを最後の join の直前に置く"
    verdict: not-required
    ref: "本文: 直し方（2026-10-13）"
knowledge_observations:
  - "01M2DRCP3QSG4NQWHNY6DSD3NJ"
  - "01KZ3MHMEQN5XEJGV9809QPH2A"
  - "01KZVHE0KQ5VCX0SXH0F4SM14D"
---

# #242 oe-activity の label を会話到達面で無害化する

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

`oe-activity` は、イベントログ由来の preview は無害化しているのに、同じ行に出す label（spawn registry や pane-issue から来る文字列）は素通しにしていた。label に ESC や制御文字が混ざると、端末での見た目の偽装や制御の注入の余地になる。`oe-undelivered`（#241）では対処済みで、同じ抜けを `oe-activity` でも塞ぐ。`oe-ack` は、label を出す経路があれば同じく対処する。

統括の brief（軽微修正4件の束の U2）。owner の承認（2026-10-13）により、plan・設計SO（ゲート2）・issue-intake は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテストは省かない。

## 作業の記録

### brief と issue の断定を当て直した（2026-10-13）

- `oe-activity` の label の流れを読んだ。label の出どころは3つある。spawn の記録（`$clabel` / `$plabel`）、message の記録（`clab_m` / `plab_m`）、受領印の記録（`rlab` / `olab`、timeline の ack 行だけ）である。どれも最後に俯瞰・inbox の列（`.clab` / `.plab`）か timeline の列（`.clab_m` / `.plab_m`）へ集まり、US 区切りで join される。preview は jq で制御文字を畳み、bash の2つのループで `oe_sanitize_conversation` を通しているが、label はどちらも通っていない。issue の「確認済み」と一致した。
- 手本の `oe-undelivered` は、jq の最後の投影で label を `gsub("[[:cntrl:]]"; " ")` で畳み（`bin/oe-undelivered:315-316`）、bash 側で `oe_sanitize_conversation` を通している（`:355-356`）。issue の記述と一致した。
- **`oe-ack` には label を出す経路が無かった。** 出力は stderr への echo だけで、表示名 `disp` は利用者がコマンドに渡した `<target>` かペイン ID である（`bin/oe-ack:152-164` と末尾の解決部）。ラベル解決の `oe_reg_resolve` もエラーで出すのは利用者の入力とペイン ID だけで、registry の label は出さない（`lib/delegate-registry.sh:134-140`）。統括の subagent の監査と一致したので、`oe-ack` は変えない。
- issue にコメントは無かった（brief は「本文とコメント」を参照に挙げていた）。

### 手本の形をそのまま写すと、数値の label で表示全体が落ちる（2026-10-13）

手本の `oe-undelivered` は label に無条件で `gsub` をかけている。jq 1.8.0 で確かめると、`gsub` は文字列以外を受けると失敗する（`42 | gsub(...)` は exit 5）。一方、いまの `oe-activity` は label をそのまま `join` に渡しており、`join` は数値や真偽値を文字にして通す（`[1,"a",null,true] | join("|")` は `1|a||true`）。

イベントログは event-bus が `--arg` で書くので、label は通常は文字列である。ただし `oe-activity` は壊れた行を飛ばして表示を続ける作り（`fromjson? // empty`）で、壊れた記録や手で直した記録にも耐えることを目指している。手本の形を写すと、数値の label が1つあるだけで投影全体が失敗し、「failed to project」で exit 1 になる。いまは表示できているので、これは退行である。

そこで、**文字列のときだけ畳み、それ以外はそのまま `join` に渡す**形にする。数値や真偽値の見え方は変えない。オブジェクトの label は、いまも `join` で失敗しており、それも変えない。

negative knowledge `01KZVHE0KQ5VCX0SXH0F4SM14D` の「先例の形が成り立つ前提が移植先にも在るか」に当たる。手本の `oe-undelivered` にも同じ形の弱さがあるが、#242 の範囲外なので直さずに報告する。

昇格の印: 制御文字の畳みを jq の値へ足すときは、型が文字列でない値で投影全体が落ちないかを見る（`join` は数値を通すが `gsub` は通さない）

手本の弱さは実際に確かめた。`oe-undelivered` に、子の label が文字列 `"c"` の記録を与えると表示し（exit 0）、数値 `42` の記録を与えると「failed to project」で exit 1 になった。

### 直し方（2026-10-13）

- jq 側: 投影の最後で label を join する直前に `fold_cntrl`（文字列のときだけ制御文字を空白へ畳む）を当てた。当てる場所は俯瞰・inbox の列（`.clab` / `.plab`）と timeline の列（`.clab_m` / `.plab_m`）の2か所で、3つの出どころ（spawn・message・受領印）はすべてここを通る。出どころごとに当てるより漏れにくい。
- bash 側: 2つのループ（timeline と、俯瞰・inbox）で、preview と同じく `clab` と `plab` に `oe_sanitize_conversation` を通した。
- `lib/sanitize.sh` が読めないときは、手本と同じく bash 側が素通しに縮退し、jq 側の畳みだけが効く。読み込み方（`dirname "$0"` から辿る）は変えていない。

### 変更前の master では、label の US で表示全体が消えていた（2026-10-13）

足した検査を変更前の master に当てると、テストは FAIL を数える前に [23] の途中で止まった。追うと、変更前の `oe-activity` は、label に US（列の区切り文字）があると見出しだけを出して exit 1 で終わり、エラーも出していなかった。

原因は、US で列がずれて MISS 列に文字列（`none`）が入り、`[[ "${miss:-0}" -gt 0 ]] 2>/dev/null` の算術評価が `none` を変数名として読み、`set -u` で未定義として落ちることだった（stderr を捨てているので何も出ない）。issue は端末での見た目の偽装を挙げていたが、俯瞰と inbox では表示が丸ごと消える。timeline はこの比較を持たないので落ちず、ESC と `<invoke` が生のまま出ていた。

テストは、表示が落ちても FAIL として数えるよう、各表示の終了コードを受け止める形に直した。

### 足した検査が、変更前で落ち、守りを1つずつ外しても狙った理由で落ちることを確かめた（2026-10-13）

足した検査は [23]（ESC・US・OSC・BEL・`<invoke` を含む label を、俯瞰・inbox・timeline の3表示で見る）と [24]（数値の label でも表示を続ける）である。

| 対象 | 結果 | 落ちた検査 |
|---|---|---|
| 変更後 | 101 件・失敗 0 | なし |
| 変更前の master | 失敗 13 | 俯瞰と inbox の exit 1・列のずれ、timeline の生の ESC と `<invoke` |
| jq 側の畳みを外した写し | 失敗 10 | 俯瞰と inbox の exit 1・列のずれ（US が列を割る） |
| bash 側の無害化を外した写し | 失敗 6 | 3表示すべての `<invoke`（jq の畳みでは消えない） |
| 型の守りを外した写し（無条件 `gsub`） | 失敗 4 | [24] の俯瞰と timeline の exit 1 |

[24] は変更前の master では通る。この単位で入れた型の守りが退行しないための検査で、受け入れの錨ではない（negative knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ`）。錨は [23] で、変更前で 13 件落ちる。

テストは外側を `/bin/bash`（3.2）と bash 5 の両方で回して通した。ただし `oe-activity` 自身はテストの中で PATH の `bash`（この環境では 5.2）で起動されるので、`oe-activity` を bash 3.2 で動かしたことにはならない。`shellcheck` は `bin/oe-activity` と `tests/test_oe_activity.sh` で警告 0。

### 同じ型を横に探した（2026-10-13）

negative knowledge `01KZ3MHMEQN5XEJGV9809QPH2A` に従い、名指しされた label 以外に、イベントログ由来の文字列を無害化せずに会話到達面へ出している箇所を探した。直さずに報告する。

- `oe-activity` のペイン ID（`.c` / `.p`）・ts・DELIVERY 列（`delivery_signal`）は、どれもイベントログの文字列をそのまま出している。brief が範囲外に挙げたペイン ID に加え、ts と `delivery_signal` も同じ型である。
- `oe-undelivered` も、ペイン ID と ts をそのまま出している（brief の指摘と同じ）。
- `oe-undelivered` の label の jq 側の畳みは無条件の `gsub` で、数値の label で投影全体が落ちる（上の「手本の形をそのまま写すと」の節）。

### 正常な label の見え方を確かめた（2026-10-13）

`oe_sanitize_conversation` に、`#206 impl`・`cockpit`・`統括 18代目`・`a  b`（空白2つ）・空文字・`x<div>y`・`#419 bash32-whitespace-check` を通すと、どれもそのまま返った。**変わったのは label がちょうど `court` の1語のときだけで、`[court]` になった。** 無害化の核が持つ「行全体が court だけの行を無害化する」規則（`lib/sanitize.sh` の段階3）によるもので、手本の `oe-undelivered` でも同じになる。issue の「正常な label の見た目は変えない」から外れるが、核の規則を label のためだけに曲げる理由は無いので、そのまま受け入れて PR 本文に書く。

### 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）

依頼文は `tmp/242/so-impl-prompt.md`（作業層・gitignore）で、5つの仮定（3表示・3出どころの網羅・正常な label の不変・文字列以外の扱いの不変・`oe-ack` の経路なし・検査の効き）の反証を求めた。Codex は 193 秒で返した（`timeout_status=success`・リトライなし・`model_resolved=gpt-6.1-sol` は設定からの値）。

- 仮定1（網羅）・仮定3（文字列以外の扱い）・仮定4（`oe-ack` に経路なし）は「成り立つ」だった。仮定3では、Codex が旧版と新版を比べ、3表示とも `42`・`true`・`false`・`null` は exit 0、オブジェクトは exit 1 で一致したと報告した。
- **仮定2は成り立たない（重大度 低・2件）。** (1) 4000 文字を超える label は、無害化の核の上限で「先頭 4000 文字＋`…`」に切り詰められる。label の長さを縛る規則は schema にも委譲の入力検査にも無い。(2) label がちょうど `court` のとき `[court]` に変わる（自分でも先に見つけていた。`本文: 正常な label の見え方を確かめた（2026-10-13）`）。
  - **採否: どちらも受け入れて PR 本文に書く。** どちらも無害化の核の規則で、手本の `oe-undelivered` でも同じになる。4000 文字を超える label を1行の表示に全文出す意味は無く、上限は会話到達面を守るためにある。核の規則を label のためだけに曲げると、同じ核を通す他の表示と振る舞いが分かれる。
- **仮定5は判断できない（テストの環境依存）。** 無害化の上限 `OE_SANITIZE_MAX_CP` は呼び出し元の環境から継承されるので、小さい値を継承すると、全文を期待する検査が正しい実装でも落ちる。jq は 1.8.0 でしか確かめていない。
  - **採否: 上限の継承は直した。** テストの冒頭で `OE_SANITIZE_MAX_CP` を `unset` し、既定へ戻す。直す前は `OE_SANITIZE_MAX_CP=3` で既存の [3] から落ちて止まり、直したあとは通る。jq の版は直していない。`gsub("[[:cntrl:]]"; " ")` と `type` は既存のコードがすでに使っている機能で、この単位で新しい依存は足していない。

直したあと、テストを bash 3.2 / 5 × `ja_JP.UTF-8` / `C` × 上限の継承あり（3）・なしの8通りで回し、すべて 101 件・失敗 0 だった。

### PR を作り、Copilot のレビューを1ラウンド受けた（2026-10-13）

PR #421 を作り、Copilot に1回依頼した。結果は「Approval recommended・0 open findings」で、行コメントは 0 件だった。未返信のスレッドは 0 件である。

## closure（2026-10-13）

tier は heavy である。意図して起動した外部レビュー（実装SO）があり、選択肢を比べて棄却した設計判断（手本の無条件 `gsub` を写さない）があり、テストが変更前で FAIL を数えずに止まるという失敗と、その直しがあったため。

### 次の消費者

- `oe-activity` / `oe-undelivered` / `oe-ack` の表示を触る将来の作業（とくに、範囲外として報告したペイン ID・ts・DELIVERY 列の無害化や、`oe-undelivered` の数値 label での失敗を直す作業）。
- jq の投影に文字列の関数を後付けする作業。収穫した negative knowledge `01M4STTT9HQBG97EQ6W6M2AVKD` が注入の候補になる。

### 事実・失敗

- 手本の形をそのまま写すと、数値の label で投影全体が落ちると分かり、写す前に止めた。`本文: 手本の形をそのまま写すと、数値の label で表示全体が落ちる（2026-10-13）`
- 変更前の master では label の US で俯瞰と inbox が見出しだけで exit 1 になっていた。足したテストは最初これを FAIL として数えずに途中で止まり、終了コードを受け止める形に直した。`本文: 変更前の master では、label の US で表示全体が消えていた（2026-10-13）`
- 正常な label でも、`court` の1語と 4000 文字超では見え方が変わる（前者は自分で、後者は実装SO が見つけた）。`本文: 正常な label の見え方を確かめた（2026-10-13）`・`本文: 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）`
- テストが無害化の上限 `OE_SANITIZE_MAX_CP` を継承して、小さい値で既存の検査から落ちていた（実装SO の指摘）。`本文: 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）`
- 名指しされた label のほかに、同じ型（イベントログの文字列を無害化せずに会話到達面へ出す）が `oe-activity` のペイン ID・ts・DELIVERY 列と、`oe-undelivered` のペイン ID・ts に残っている。手本の `oe-undelivered` は数値の label で落ちる。どれも直していない。`本文: 同じ型を横に探した（2026-10-13）`
- 守りを外した写しを作るコマンドに `rm -rf "$d"` を入れ、安全確認で止められた。まだ存在しない新しいディレクトリへ作る形に変え、削除は使わなかった。`本文なし: 検証の足場の作り方の出来事で、判断には影響しないため本文に節を立てなかった`

### 決定と根拠

- jq 側の畳みは文字列のときだけに当てる。手本の無条件 `gsub` は棄却した。`本文: 手本の形をそのまま写すと、数値の label で表示全体が落ちる（2026-10-13）`
- jq 側の畳みは、出どころごとではなく最後の join の直前の2か所に置く。`本文: 直し方（2026-10-13）`
- `oe-ack` は変えない（label を出す経路が無い）。`本文: brief と issue の断定を当て直した（2026-10-13）`
- 無害化の核の規則（`court`・4000 文字の上限）を label にもそのまま当てる。`本文: 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）`

### わかったこと

- 変更前の `oe-activity` は、label の US で列がずれると、`set -u` の下の算術比較で何も出さずに落ちていた。これは既存の negative knowledge `01M19CPRGERDEV1CFWXQ40XVPT`（値の中の区切り文字がレコード境界を壊す）と同じ型の再発である。この item は brief に注入されていなかったので、観測は書き戻していない。`本文: 変更前の master では、label の US で表示全体が消えていた（2026-10-13）`

### 蒸留シグナル

- negative knowledge を1件収穫した（`01M4STTT9HQBG97EQ6W6M2AVKD`・jq の文字列の関数は文字列以外で投影全体を落とす）。decision / skill / rule への昇格候補はない。

### 昇格の判定

本文の印は1件で、印の無い判断を3件足した。

1. **制御文字の畳みを jq の値へ足すときは、型が文字列でない値で投影全体が落ちないかを見る** — `required`（negative knowledge）。非自明（`join` は通すのに `gsub` は通さない差は、コードを読んでも気づきにくい）・再発しうる（手本の `oe-undelivered` が実際にこの形で落ちる）・行動を変える（型で守る）の3つを満たし、既存の item に同旨は無かった。Step 5 で `01M4STTT9HQBG97EQ6W6M2AVKD` として収穫し、この PR に入れた。参照した材料は `本文: 手本の形をそのまま写すと、数値の label で表示全体が落ちる（2026-10-13）`。
2. **`oe-ack` は label を出す経路が無いので変えない**（印なし） — `not-required`。監査の結果で、解釈が分かれた判断ではない。実物を読めば決まる確認である（Q2 に当たらない）。結果は PR 本文に書いた。参照した材料は `本文: brief と issue の断定を当て直した（2026-10-13）`。
3. **無害化の核の規則を label にもそのまま当てる**（印なし） — `not-required`。会話到達面へ出す文字列は同じ無害化の核を通すという方針は、#224 で `lib/sanitize.sh` を共有のチョークポイントとして作ったときに決まっており、ファイルの冒頭に書かれている。この単位はそれに従っただけで、新しい判断ではない。参照した材料は `本文: 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）` と `lib/sanitize.sh` の冒頭。
4. **jq 側の畳みを最後の join の直前に置く**（印なし） — `not-required`。実装の局所的な選択で、理由はスクリプトのコメントに併設した。参照した材料は `本文: 直し方（2026-10-13）`。

### 注入された negative knowledge への観測

brief がこの単位に割り当てた item は3件で、3件とも観測を書き戻した（`ref: "#242"`）。

- `01M2DRCP3QSG4NQWHNY6DSD3NJ` — `followed`（[23] を変更前で落として錨にし、変更前でも通る [24] を錨から外した）
- `01KZ3MHMEQN5XEJGV9809QPH2A` — `followed`（同じ型を横に探し、範囲外を直さずに報告した）
- `01KZVHE0KQ5VCX0SXH0F4SM14D` — `followed`（手本の前提が移植先に無いことを写す前に確かめ、違いを書いた）

`01M2DRCP3QSG4NQWHNY6DSD3NJ` には U1 の PR #420 も同じ位置に1件足している。2本目がマージされるときに衝突するので、両方の記録を残して解消する（追記だけの台帳なので、どちらも落とさない）。

### follow-up

- `oe-activity` のペイン ID・ts・DELIVERY 列、`oe-undelivered` のペイン ID・ts の無害化 → **PR #421 本文の「範囲外で見つけたもの」節に記録し、統括への報告（`.oe/report-242.md` の Out-of-scope findings）で issue にするかの判断を渡す**（brief がペイン ID を範囲外としていた。ts と DELIVERY 列はこの単位で見つけた同じ型）。
- `oe-undelivered` の label の畳みが数値の label で落ちる → **PR #421 本文の「範囲外で見つけたもの」節に記録し、統括への報告で issue にするかの判断を渡す**（手本の弱さ。#242 の範囲外）。
- 正常な label の見え方が変わる2件（`court`・4000 文字超）→ **追わない**。無害化の核の規則で、PR 本文に書いた。
- issue #242 の「`oe-undelivered` の label 無害化をそのまま踏襲」という指示 → **issue 本文は訂正しない**。issue は着手時の依頼の記録で、着地のあと統括が close する。型の守りを足した理由は、PR #421 本文の「変更」節とスクリプトのコメントに書いた（closure の外部チェックの指摘を受けて行き先を明記した）。
- jq の版を 1.8.0 でしか確かめていない → **追わない**。使った機能（`gsub` と `[[:cntrl:]]`・`type`）は既存のコードがすでに使っている。
- U1 と U2 の knowledge item への追記の衝突 → **PR #421 本文の「episode と knowledge」節と統括への報告に書く**（マージする側が両方の記録を残して解消する）。

### 証跡の置き場

実装SO の依頼文と出力は `tmp/242/`（作業層・gitignore）にあり消える。要点（仮定ごとの判定・指摘2件・採否・再検証の数字）は `本文: 実装SO（ゲート4・弱・Codex 1レーン）で、正常な label が変わる場合とテストの環境依存が出た（2026-10-13）` に写した。closure の外部チェック（Step 4・Codex 1レーン・100 秒）も同じ置き場で、4点のうち3点が問題あり（同じ型の見落としが事実・失敗に無い・follow-up の行き先が具体的でない・issue の指示の扱いが無い）だった。上の事実・失敗と follow-up の該当行がその反映である。

### status

`stable`・達成。

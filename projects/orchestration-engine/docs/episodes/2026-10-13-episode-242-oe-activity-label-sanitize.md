---
id: "01M4SSP018X3037Q7MC99A384V"
title: "#242 oe-activity の label を会話到達面で無害化する"
date: 2026-10-13
type: episode
status: in-development
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/242"
    reason: "本 episode の作業対象"
tags: [orchestration, oe-activity, oe-ack, sanitize, malform-hygiene]
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

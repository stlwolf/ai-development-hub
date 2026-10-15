---
id: "01M50CDJXQ8JSFZPVWZGBD01CV"
title: "#427 knowledge-list に残る jq 失敗の握り潰しを exit 2 にそろえる"
date: 2026-10-16
type: episode
status: in-development
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/427"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "projects/orchestration-engine/docs/episodes/2026-10-13-episode-424-knowledge-jq-exit2-rest.md"
    reason: "前の単位。同じ直し方の先例で、この単位の対象はその範囲外の節で見つかった"
tags: [orchestration, knowledge, knowledge-list, exit-code, jq]
---

# #427 knowledge-list に残る jq 失敗の握り潰しを exit 2 にそろえる

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

#424（PR #425）で、`knowledge-list.sh` の frontmatter root の型を読む jq の評価失敗は、ERROR を出して exit 2（環境エラー）で止まる形になった。同じスクリプトには、jq が失敗したときに何も出さずに exit 5 で終わる箇所と、失敗を空として後段へ流し、出力の一部が黙って消える箇所が残っている。#424 の episode の「表の外の同じ型を洗い出した」節が見つけ、#427 に起票された。

統括の brief（`.oe/brief-small-fixes-1016.md`・作業層）の単位 U1。owner の指示（2026-10-16）により plan と設計SO（ゲート2）と issue-intake は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドと、テスト（bash 3.2 と 5 の両系）は省かない。master `00cf5a3` から切った。

## 作業の記録

### 変更前の master で、jq の呼び出しを全部1つずつ失敗させて結果を確かめた（2026-10-16）

negative knowledge `01KZRTSJ2VP8BZR0MF7QZRNYH7`（exit code は実行経路の性質なので、各経路を実際に通して確かめよ）と `01KZ3MHMEQN5XEJGV9809QPH2A`（名指しされた箇所を直した緑は、その型が消えた証拠ではない）に従い、issue の表を写さずに、`00cf5a3` の `knowledge-list.sh` で jq を呼ぶ行を `grep` で全部拾った。jq の評価は12か所ある。そのうち frontmatter root の型を読む1か所（254 行）は #424 で exit 2 の形になっており、残る11か所を [34] と同じ stub（`STUB_JQ_FAIL` に合う引数を持つ呼び出しだけを exit 5 で失敗させ、`STUB_JQ_LOG` に記録する）で1つずつ通した。

使った store は2つである。1つは正常な item 1件（`status: active` で `harmful` の観測を1件持つので、制御候補になる）、もう1つは壊れた item だけの store（非 ULID 名・閉じ `---` 欠落・空の frontmatter・root が配列の4件）である。

| 箇所（`00cf5a3` の行） | issue の表 | jq が失敗したときの結果 |
|---|---|---|
| 218 行（非 ULID 名の MALFORMED の行を組む `jq -n`） | あり | 何も出さずに exit 5 |
| 235 行（閉じ `---` 欠落の MALFORMED の行） | あり | 何も出さずに exit 5 |
| 243 行（空の frontmatter の MALFORMED の行） | あり | 何も出さずに exit 5 |
| 260 行（malformed YAML の MALFORMED の行） | あり | 何も出さずに exit 5 |
| 276 行（item の JSON を組む代入） | あり | 何も出さずに exit 5 |
| 308 行（集計用のフラグを `read <<<"$(jq ...)"` で読む） | あり | 止まらずに進み、item の行には「control-candidate: harmful」が出るのに、末尾から「control-candidates: 1」が消える。exit 0 |
| 384 行（`--json` で items を配列にまとめる `jq -s '.'`） | 「確かめていない」 | 何も出さずに exit 5 |
| 385 行（`--json` で MALFORMED の行を配列にまとめる `jq -s '.'`） | 「確かめていない」 | 何も出さずに exit 5 |
| 389 行（`--json` の出力を組む `jq -s`） | 「確かめていない」 | 何も出さずに exit 5 |
| 401 行（人向けの出力で item を描く `jq -r`） | 「確かめていない」 | 何も出さずに exit 5 |
| 428 行（人向けの出力で MALFORMED の行を描く `jq -r`） | 「確かめていない」 | 何も出さずに exit 5 |

- 表の行番号は、issue（`069b65b`）と `00cf5a3` で同じだった。
- **issue が「確かめていない」とした5か所は、どれも何も出さずに exit 5 で終わる。** 384・385 行は `[[ ... ]] && x="$(...)"` の形で、`&&` の最後の代入が失敗するので `set -e` が効く。401・428 行はパイプで、`pipefail` で jq の終了コードが出る。どれも実際に通して確かめた。
- stub の記録は、どの箇所も狙ったプログラム1つだった。276・389・401 行は記録の行数が1より多いが、これはプログラムが複数行の文字列だからで、各プログラムにしか無い行（`observations_by_state: $counts`・`schema_version:1`・`"    excerpt:    "`）が記録に1回だけ出ることで、呼び出しが1回であることを確かめた。384 と 385 は引数がどちらも `-s .` で区別できないので、items だけの store と MALFORMED だけの store に分けて、片方しか呼ばれない形で当てた。
- 作業層の試しのスクリプトは scratchpad に置いた（消える）。結果は上の表に写した。

### 表の外の同じ型（jq 以外）を当たった（2026-10-16）

同じ `01KZ3MHMEQN5XEJGV9809QPH2A` に従い、jq 以外で失敗を空へ丸めている箇所も見た。

- repo root を求める `git rev-parse --show-toplevel 2>/dev/null || true` は、git の外で動かすという正当な状態を空で表すものである。空のときは、git-head と `--include-uncommitted` のモードでは後段が exit 2 で止まり、explicit モードではパスを渡されたまま使う。丸めではない。
- frontmatter を読む yq の失敗は、#424 で「item の不備なので MALFORMED」と決めた扱いで、変えない。
- `excerpt_of` と本文を切り出す awk は `x="$(awk ...)"` の代入で、awk が失敗すれば `set -e` で何も出さずに awk の終了コードで止まる（読みだけで、通していない）。jq ではないので、この issue の範囲外として報告する。

### 握り潰しを外す前に、正当な空や false がどこから来るかを確かめた（2026-10-16）

negative knowledge `01KYA7C9NN4VDM7H2NYXZB2PSX`（失敗と正当な値を分けよ。正当に空や false になる経路が無いかを確かめてから exit 2 に寄せよ）に従った。

- **11か所とも、jq に渡すのはこのスクリプト自身が組んだ値である。** MALFORMED の行の4か所は `jq -n` で入力を読まず、引数は path と固定の理由と ULID の文字列だけである。item の JSON を組む箇所は、root の型を読めた同じ `$json`（object と確かめ済み）を読む。フラグを読む箇所と出力の5か所は、jq が組んだ JSON を読む。
- **item の JSON を組むプログラムは、どんな object に対しても失敗しない形である。** 型を確かめてから読む（`exclusions` は配列のときだけ、`source.ref` は `source` が object のときだけ、観測の要素は `obs_valid` が先に型を見る）。jq の `and` が左が false のときに右を評価しないことを `jq -n '1 as $o | (($o|type)=="object") and ($o|has("x"))'` で確かめ（`false`・終了コード 0）、`observations` に数値・文字列・null・型の違う object・配列を混ぜた object と、object の `id`・`status`、文字列の `exclusions`・`source` を通して、終了コード 0 で `invalid` に数えられることを見た。
- **フラグの2つの値は、item の JSON を組むプログラムがいつも真偽値で入れる**（`$cand` と `$malformed` はどちらも比較と `and`・`or` の結果）。正当な空が来る経路は無い。
- jq が正当な空や false を返すときの終了コードは 0 である（`-e` は使っていない）。直し方は「終了コードが 0 でないときだけ exit 2」なので、正当な値はこれまでどおり流れる。これを実物で確かめたのは、既存のテスト（壊れた観測・配列でない観測・allow-list 外の ref・null の note などの item を通す [24]〜[33]）が変更後も全部通ったことと、下の「変更前と出力が同じか」の比べ方である。

### 直し方（2026-10-16）

- 11か所を、#424 の root の型と同じ `if ! x="$(jq ... 2>/dev/null)"; then echo "ERROR: ..." >&2; exit 2; fi` の形にした。stdout へ直接書く3か所（`--json` の出力・人向けの item・人向けの MALFORMED の行）は、`if ! printf ... | jq ... 2>/dev/null; then` の形で、`pipefail` により jq の終了コードを見る。
- MALFORMED の行の4か所は、`MALFORMED_JSON+=("$(jq ...)")` を、いったん `row` に受けてから積む形にした。配列への追加の中の `$(...)` は終了コードを見られないためである。
- フラグを読む箇所は、`read <<<"$(jq ...)"` を、`flags` に受けて終了コードを見てから `read <<<"$flags"` で分ける形にした。
- `--json` の2つの `[[ ... ]] && x="$(...)"` は、`if` の入れ子に直した。
- ERROR の文言は、どこで落ちたかが分かるように箇所ごとに分けた（`build the MALFORMED row`・`build the item JSON`・`read the control-candidate and integrity flags`・`collect the items into a JSON array`・`collect the MALFORMED rows into a JSON array`・`build the --json output`・`render the item list`・`render the MALFORMED rows`）。item を処理している箇所では path を入れた。
- 理由のコメントは `process_item` の冒頭と出力の節の頭に1つずつ置き、root の型の直前にあった「この形にそろえたのはこの1か所だけ」の但し書きを外した。スクリプト冒頭の exit 2 の説明は `--help` が 3〜18 行を表示するので、1行のまま「frontmatter root の型を読む jq の評価失敗」を「jq の評価失敗」に書き換えた。`docs/knowledge/README.md` の exit の表も同じに直し、表の下の段落をそろえた範囲の説明に書き換えた。
- 共通の関数にはまとめず、同じ形で書き下した。理由は #424 の episode の「共通の関数にまとめず、11か所を同じ形で書き下した」節と同じで、brief が先例と同じ形を指定していることと、`grep` で全部が同じ形かを確かめられることである。

### 人向けの出力は、ためずに item ごとに書き出す形を残した（2026-10-16）

人向けの出力の jq（item と MALFORMED の行）は、item ごとに stdout へ書き出している。2件目以降で jq が失敗すると、それまでの item の行が stdout に出たあとで ERROR と exit 2 になる。

- 考えた案: 出力を変数か一時ファイルにためて、全部組めたときだけ書き出す。こうすると「exit 2 のとき stdout は空」がどのモードでも成り立つ。
- 採らなかった理由: 変数にためると `$(...)` が末尾の改行を落とすので、`source.ref` が改行で終わる item のように、ブロックの末尾の空行の数が変わる場合がある（いまの出力とバイト単位で同じに保てない）。`source_ref` が `"a\n\n"` の item で、直接書き出すと `a` のあとに改行が4つ、`$(...)` に受けてから `printf '%s\n\n'` で戻すと2つになることを `od -c` で確かめた。一時ファイルにためるなら同じに保てるが、`mktemp` と `trap` の掃除をもう1つ足すことになり、この単位の小さな直しを越える。exit 2 と ERROR が出るので「黙って」はおらず、末尾の `listed:` の行が出ないことで、完全な一覧でないことも見分けられる。
- この振る舞いは、スクリプトの出力の節のコメントと README に書いた。`--json` は最後の jq が値を組み終えてから書き出すので、失敗したときの stdout は空である。

### テストと、足した検査が変更前で落ちること（2026-10-16）

negative knowledge `01M00KCCHNMFPHP5HAGX2DZ1MK`（期待した色が期待した理由で出たかを見よ）と `01M2DRCP3QSG4NQWHNY6DSD3NJ`（判定の錨が変更そのものに在るかを見よ）に従った。

- `test_knowledge_list.sh` に [35] を足した。[34] の stub をそのまま使い、11か所それぞれで、exit 2・その箇所の ERROR・stdout が空・stub が狙ったプログラムで1回落としたことを見る。記録の照合は、1行の引数（MALFORMED の理由・フラグのプログラム・`.`・MALFORMED の行を描くプログラム）は全文と、複数行のプログラム（item の JSON・`--json` の出力・人向けの item）はそのプログラムにしか無い行が記録にちょうど1行あることで見る。対照として、stub を外すと正常な store の footer に `control-candidates: 1` が出ることと、壊れた store の4件が skip されることを見る。
- 変更前と出力が同じかは、実物の store（この repo の3つの木・72 件）と、正常な item と4種の壊れた item と配列でない観測の item を混ぜた store で、既定・`--json`・`--strict`（実物は `--include-uncommitted` も）を bash 3.2 と 5 で回し、stdout・stderr・終了コードが変更前のスクリプトとバイト単位で同じことを `cmp` で確かめた。

| 対象 | `test_knowledge_list.sh` | `test_validate_knowledge.sh` |
|---|---|---|
| 変更後・bash 3.2.57（`/bin/bash`） | 194 件・失敗 0 | 260 件・失敗 0 |
| 変更後・bash 5.2.37 | 194 件・失敗 0 | 260 件・失敗 0 |
| 変更前のスクリプト（`00cf5a3`）に新しいテストを重ねたもの・bash 5 | 失敗 23 | （変えていない） |

- 変更前で落ちた 23 件は、11か所それぞれの exit 2 と ERROR の2件ずつ（22 件）と、フラグの箇所の「stdout は空」の1件である。フラグの箇所は、変更前は止まらずに item の行を出して exit 0 で終わっていた。
- **stub の当たりの検査（11 件）と、exit 5 で終わっていた10か所の「stdout は空」（10 件）と、対照（4 件）は、変更前でも通った。** 変更前も stub は狙った呼び出しを失敗させており、何も出さずに終わっていたためである。これらは錨に数えない。
- `shellcheck` は変更したスクリプトとテストで警告 0（テストの `$counts` を単一引用で渡す行には、[34] と同じ理由の `disable=SC2016` を置いた）。

---
id: "01M54TZQS78FYY4CHCVGCNT53C"
title: "#442 knowledge-list の awk の失敗が握り潰される2か所を exit 2 にそろえる"
date: 2026-10-17
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/442"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "projects/orchestration-engine/docs/episodes/2026-10-16-episode-427-knowledge-list-jq-exit2.md"
    reason: "前の単位。同じ直し方の先例で、この単位の対象はその実装SO の節で見つかった"
tags: [orchestration, knowledge, knowledge-list, exit-code, awk]
---

# #442 knowledge-list の awk の失敗が握り潰される2か所を exit 2 にそろえる

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

#427（PR #441）で `knowledge-list.sh` の jq の呼び出しすべてを、失敗したら ERROR を出して exit 2（環境エラー）で止まる形にそろえた。その実装SO の指摘で、jq 以外にも失敗が握り潰される箇所が2つ見つかった。`excerpt_of` の awk は、コマンド置換の中で呼んだ関数には `set -e` が効かないため、失敗しても excerpt が空のまま進んで exit 0 で終わる。本文を切り出す awk は、何も出さずに awk の終了コードで止まる。#427 の episode の「実装SO（ゲート4・弱・Codex 1レーン）は5つの仮定を「成り立つ」とし、指摘2件を出した」節が見つけ、#442 に起票された。

統括の brief（`.oe/brief-442-knowledge-list-awk.md`・作業層）の単位。owner の指示（2026-10-13）により plan と設計SO（ゲート2）と issue-intake は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドと、テスト（bash 3.2 と 5 の両系）は省かない。master `a9c180e` から切った。

## 作業の記録

### 変更前の master で、awk の呼び出しを全部1つずつ失敗させて結果を確かめた（2026-10-17）

negative knowledge `01KZRTSJ2VP8BZR0MF7QZRNYH7`（exit code は実行経路の性質なので、各経路を実際に通して確かめよ）と `01KZ3MHMEQN5XEJGV9809QPH2A`（名指しされた箇所を直した緑は、その型が消えた証拠ではない）に従い、issue の表を写さずに、`a9c180e` の `knowledge-list.sh` で awk を呼ぶ行を `grep` で全部拾った。awk の呼び出しは3つある。PATH に awk の stub（`STUB_AWK_FAIL` の case パターンに合う引数を持つ呼び出しだけを exit 5 で失敗させ、その引数を `STUB_AWK_LOG` に記録する。ほかは実 awk に渡す）を置き、正常な item 1件の store で、既定と `--json` を bash 3.2.57 と 5.2.37 で回した。両方の bash で結果は同じだった。

| 箇所（`a9c180e` の行） | issue の表 | awk が失敗したときの結果 |
|---|---|---|
| 189 行（`excerpt_of` の awk。`excerpt="$(excerpt_of "$body")"` の中で呼ばれる） | あり | 止まらずに進み、`--json` の `excerpt` が空のまま exit 0 |
| 287 行（本文を切り出す awk。`body="$(printf ... \| awk ...)"`） | あり | 何も出さずに exit 5（stub の値）で止まる |
| 238 行（frontmatter を切り出す awk。`if ! fm="$(awk ...)"`） | **なし** | 正常な item が「frontmatter delimiter block not found」の MALFORMED として skip され、exit 0（`--strict` なら exit 1） |

- 名指しの2か所は、issue の表のとおりだった。
- **3つ目は issue に無かった。** 閉じ `---` が無いことを awk のプログラム自身が `exit 1` で知らせる作りで、`if !` が awk の終了コードの 0 以外をすべて「区切りが無い」として扱う。そのため awk 自体の失敗（環境エラー）が item の不備（データ）に誤分類される。#424 で直した「root の型を読む jq の失敗を MALFORMED に丸めない」と同じ形である。#427 の episode が範囲外の awk を当たったときは名指しの2つだけを見ており、`if !` で受けているこの箇所は扱われているように読めるので、見落とされていた。
- stub の記録は、どの箇所も狙ったプログラム1つだった（`excerpt_of` は14行、frontmatter は6行のプログラムなので記録もその行数になり、本文の切り出しは1行）。
- 作業層の試しのスクリプトは scratchpad に置いた（消える）。結果は上の表に写した。

### 3つ目の awk もこの単位で直すと統括が決めた（2026-10-17）

issue と brief の scope は「2か所」と書いているので、3つ目を直すかを統括に問うた（`.oe/question-442-1.md`・作業層）。推奨は「直す」で、理由は、同じファイルの中で issue の題（awk の失敗が握り潰される）と同じ型であること、brief の scope が「この単位で直すのは `knowledge-list.sh` の中だけ」としていること、直さないと README とスクリプト冒頭の exit 2 の説明に3つ目だけ除く但し書きが要ることである。棄却した案は「直さずに範囲外として報告し、issue を分けるかを統括に渡す」である。

統括の答えは A（この単位で直す）だった（2026-10-17）。あわせて、分け方の限界を episode に書くよう指示を受けた。分け方は「awk の終了コードが 1 なら区切りが無い（MALFORMED）、それ以外の 0 でない値なら exit 2」である。

- macOS の awk（version 20200816）は、自分の失敗（構文エラー・0 での除算・入力ファイルが開けない・出力先が開けない・`-f` のファイルが無い）で exit 2 を返すことを確かめた。
- **ただし、awk の実装によっては自分の失敗で 1 を返しうる。その場合は、いまと同じ扱い（MALFORMED として skip）に落ちる。** 誤分類が消えるのは、awk が自分の失敗で 1 以外を返すときだけである。この限界はスクリプトのコメントと README にも書く。

### `excerpt_of` の awk は、本文の不正なバイトというデータでも exit 2 で失敗する（2026-10-17）

negative knowledge `01KYA7C9NN4VDM7H2NYXZB2PSX`（失敗と正当な値を分けよ。丸めを外す前に、データ由来で失敗する経路が無いかを確かめよ）に従い、3つの awk のプログラムに、データだけで失敗を起こしうる入力（3MB の1行・20万行・UTF-8 として不正なバイト・CR・バックスラッシュ）を、`en_US.UTF-8`・`ja_JP.UTF-8`・`C` のロケールで与えた。

- **`excerpt_of` の awk だけが、UTF-8 ロケールで不正なバイトの入力に exit 2 を返した**（stderr は「`awk: towc: multibyte conversion failure`」）。正規表現の `sub` が文字に変換できないためである。`C` ロケールでは同じ入力で exit 0 だった。
- 変更前の master のスクリプトで end-to-end に通すと、本文の**先頭の内容行**に `\xff` がある item は、excerpt が空のまま列挙され、exit 0 で、awk のメッセージが stderr にそのまま出た（bash 3.2 と 5 で同じ）。2行目以降の不正なバイトは、先頭の内容行を見つけたあと（`found { next }`）は正規表現を当てないので失敗しない。
- 環境の失敗でも awk は exit 2 を返す（上の節）ので、**終了コードではデータと環境を分けられない。** issue のとおり「失敗したら exit 2」にすると、不正なバイトの item が1件あるだけで、列挙全体が「環境エラー」で止まる。
- 本文の切り出しと frontmatter の切り出しは、文字列の比較と連結と出力だけで正規表現を使わず、どの入力・どのロケールでも失敗しなかった。この2つは終了コードだけで分けてよい。
- 「いつも `LC_ALL=C` で走らせればデータで失敗しなくなる」案を確かめるため、Unicode の空白14種を行頭に置いて2つのロケールの結果を比べた。13種は同じだったが、**NBSP（U+00A0）は UTF-8 ロケールでは空白として剥がされ、`C` では残った。** いつも `C` にすると、その入力の出力が変わる。

この分け方は brief の想定（「awk の失敗を ERROR と exit 2 にそろえる」）を変えるので、統括に問うた（`.oe/question-442-2.md`・作業層）。推奨は「失敗したときだけ同じプログラムを `LC_ALL=C` でもう1回走らせ、`C` でも失敗すれば環境エラー、`C` で成功すればデータの不備としていまと同じ扱いを保つ」である。

昇格の印: 「awk の正規表現はロケールによってデータで失敗し、その終了コードは環境の失敗と同じ 2 である」は、awk の失敗を exit 2 に寄せるときに、終了コードだけでは分けられない経路である。

統括の答えは A（失敗したときだけ `LC_ALL=C` でもう1回走らせて分ける）だった（2026-10-17）。棄却した案と理由は次のとおりである。

- `C` で走らせた結果を excerpt に使う案（preview が空にならない）と、いつも `C` で走らせる案（データで失敗する経路そのものが消える）は、どちらも出力が変わるので、この単位では採らない。後者は上の NBSP の入力で出力が変わる。
- issue のとおり失敗をすべて exit 2 にする案は、データの不備を環境エラーと誤分類するので採らない。
- データの不備を excerpt を空のまま黙って通すいまの振る舞いは、範囲外として報告に並べる。

### 直し方（2026-10-17）

- **frontmatter の awk**: `if ! fm="$(awk ...)"` を、`fm="$(awk ...)" || fm_rc=$?` で終了コードを受ける形にした。1 は従来どおり「frontmatter delimiter block not found」の MALFORMED、それ以外の 0 でない値は「failed to extract the frontmatter with awk」の ERROR と exit 2 にした。`if !` の中では `$?` が否定の結果になって awk の終了コードを取れないので、この形にした。
- **本文の awk**: `body="$(printf ... | awk ...)"` を `if ! body="$(...)"; then` にし、「failed to extract the body with awk」の ERROR と exit 2 にした。`pipefail` により awk の終了コードを見る。
- **excerpt の awk**: プログラムを変数 `prog` に移し、`if ! line="$(awk "$prog" ...)"` で失敗したときだけ `LC_ALL=C awk "$prog"` をもう1回走らせ、そちらも失敗したら `excerpt_of` が 1 を返すようにした。呼び出し側は `if ! excerpt="$(excerpt_of "$body")"; then` で「failed to extract the excerpt with awk」の ERROR と exit 2 にする。`C` で成功したときは、失敗した awk の出力（空）をそのまま使うので、変更前と同じ出力になる。2回目の awk の stdout と stderr は捨てる（1回目のメッセージは変更前と同じく stderr に出る）。
- ERROR の文言は、#427 の jq の箇所と同じく、どこで落ちたかが分かるように箇所ごとに分け、item の path を入れた。
- 理由のコメントは、`process_item` の冒頭（jq の段落の続き）と各箇所に置いた。スクリプト冒頭の exit 2 の説明は `--help` の表示範囲（3〜18 行）を変えずに、1行の中に「awk の失敗」を足した。`docs/knowledge/README.md` の exit の表にも同じ語を足し、表の下に awk の段落を足した（frontmatter の 1 の扱いと、excerpt の `LC_ALL=C` での分け方）。

### 依存の検査に awk を足さなかった（2026-10-17）

brief の scope は、依存の検査（いまは jq と yq だけを見る）に awk を足すかを決め、理由を書くよう求めている。足さないことにした。

- **変更後は、awk が無いと最初の item で ERROR と exit 2 になる。** jq・yq・git などは置き awk だけを抜いた PATH で、変更前と変更後のスクリプトを bash 3.2 と 5 で回した。変更前は、bash の「awk: command not found」のあとで、正常な item が「frontmatter delimiter block not found」の MALFORMED として skip され、exit 0 だった（awk の終了コード 127 を `if !` が「区切りが無い」と読んでいた）。変更後は、同じ「command not found」のあとで「failed to extract the frontmatter with awk」の ERROR と exit 2 になった。依存の検査を足さなくても、awk が無いことは環境エラーとして見える。
- 依存の検査が見ているのは、別に入れる必要がある jq と yq である。awk は、検査していない sed・find・cat・mktemp と同じく POSIX の基本のコマンドである。
- 対になる `validate-knowledge.sh` も、jq と yq だけを検査して awk を使っている。片方だけに足すと、README が「`validate-knowledge` との整合」として並べている2つのスクリプトの扱いがずれる。
- 棄却した案: 依存の検査に awk を足す。利点は、item を読む前に「awk is not installed」と出ることだが、上の3点から、この単位では足さない。

### テストと、足した検査が変更前で落ちること（2026-10-17）

negative knowledge `01M00KCCHNMFPHP5HAGX2DZ1MK`（期待した色が期待した理由で出たかを見よ）と `01M2DRCP3QSG4NQWHNY6DSD3NJ`（判定の錨が変更そのものに在るかを見よ）に従った。

- `test_knowledge_list.sh` に [36] を足した。[34] の jq の stub を awk に写し、`STUB_AWK_FAIL` に合う呼び出しだけを exit 5 で失敗させて、引数を `STUB_AWK_LOG` に、そのときの `LC_ALL` を `STUB_AWK_ENVLOG` に記録する。3か所それぞれで、exit 2・その箇所の ERROR・stdout が空・stub が狙ったプログラムで落としたことを見る。frontmatter では MALFORMED に丸めていないことも見る。excerpt では stub が2回落としたこと（1回目と `C` での再実行）と、2回目の `LC_ALL` が `C` であることを見て、分ける経路を通ったことを確かめる。
- 対照として、本文の先頭の内容行に `\377` がある item と正常な item の store を、UTF-8 ロケールで `--json` で回し、exit 0・ERROR を出さない・2件とも列挙・不正なバイトの item の excerpt は空・ほかの item の excerpt は従来どおり、を見る。ロケールは `C.UTF-8`・`en_US.UTF-8`・`ja_JP.UTF-8` の順に、その awk が不正なバイトで実際に失敗するものを選ぶ。どれでも失敗しない awk（データで失敗する経路が無い）では、この対照は SKIP と出して見ない。
- stub を外したときの出力は、実物の store（3つの木・73 件）と、正常な item と、見出しや引用で始まる本文・先頭の内容行の不正なバイト・行頭の NBSP・空の本文・配列でない観測・制御候補・5000 字の行と2行目の不正なバイト・壊れた item 6 種（非 ULID 名・閉じ `---` 欠落・空の frontmatter・root が配列・1行目の前の不正なバイト・frontmatter の不正なバイト）を混ぜた store で、既定・`--json`・`--strict`・`--include-uncommitted` を bash 3.2 と 5 で回し、stdout・stderr・終了コードが変更前とバイト単位で同じことを `cmp` で確かめた（16 通り・差分 0）。

| 対象 | `test_knowledge_list.sh` | `test_validate_knowledge.sh` |
|---|---|---|
| 変更後・bash 3.2.57（`/bin/bash`） | 213 件・失敗 0 | 260 件・失敗 0 |
| 変更後・bash 5.2.37 | 213 件・失敗 0 | 260 件・失敗 0 |
| 変更前のスクリプト（`a9c180e`）に新しいテストを重ねたもの・bash 3.2 と 5 | 失敗 11（両方で同じ11件） | （変えていない） |
| excerpt の `LC_ALL=C` の再実行を外した変異体に新しいテストを重ねたもの・bash 3.2 と 5 | 失敗 6 | （変えていない） |

- 変更前で落ちた 11 件は、frontmatter の4件（exit 2・ERROR・stdout が空・MALFORMED に丸めていない）、本文の2件（exit 2・ERROR）、excerpt の5件（exit 2・ERROR・stdout が空・2回落とした・2回目が `C`）である。
- **変更前でも通った8件は錨に数えない。** frontmatter の stub の当たり（変更前も stub は狙った呼び出しを1回落としていた）、本文の stdout が空と stub の当たり（変更前は何も出さずに exit 5 で終わっていた）、対照の5件（変更前も exit 0 で excerpt は空だった）である。
- 変異体（excerpt で `C` の再実行をせず、失敗したらすぐ 1 を返す）で落ちた6件は、excerpt の「2回落とした」「2回目が `C`」と、対照の4件（exit 0・ERROR を出さない・2件とも列挙・ほかの item の excerpt）である。対照は、分ける経路を外す退行を捕まえる。対照の「不正なバイトの item の excerpt は空」は、出力が空でも空を返すので、変異体でも通った。
- `shellcheck` は変更したスクリプトとテストで警告 0（awk のプログラムを単一引用で渡す行に、既存の jq の行と同じ理由の `disable=SC2016` を置いた）。

### テストを回す中で、bash 3.2 の終了コードが 0 のまま止まる形を踏んだ（2026-10-17）

最初に [36] を回したとき、テストのラベル `"対照（$_LOC36）: exit 0"` で、変数名の直後に全角の括弧を置いたため、bash 3.2 と 5 のどちらも括弧の先頭バイトを変数名に含めて読み、`set -u` の「unbound variable」でテストが途中で止まった。`${_LOC36}` で囲んで直した。

- **bash 3.2 では、途中で止まったテストの終了コードが 0 だった**（bash 5 は 1）。`set -euo pipefail` と EXIT の trap（`rm -rf`）を持つスクリプトで「unbound variable」が起きると、bash 3.2 は trap の終了コード（0）で終わることを、最小の再現（`/bin/bash -c 'set -euo pipefail; trap "rm -rf /nonexistent" EXIT; echo "$undefined"'` が 0）で確かめた。trap が無いときと、trap が `false` のときは 1 だった。終了コードだけを見ると、bash 3.2 では途中で止まったテストを通ったと読み違える。今回は `=== Results:` の行が無いことで気づいた。
- これはテストの仕組みの既存の性質で、この単位では直さない。範囲外として報告に並べる。

昇格の印: 「bash 3.2 は、EXIT の trap を持つスクリプトが set -u で止まると trap の終了コード（0）で終わる」は、テストの合否を終了コードだけで読む運用で、途中で止まったテストを緑と読み違える経路である。

## closure

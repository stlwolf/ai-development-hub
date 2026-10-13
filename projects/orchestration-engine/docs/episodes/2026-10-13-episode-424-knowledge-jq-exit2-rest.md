---
id: "01M4TS0EW6SSSXWTX67KZX35XY"
title: "#424 validate-knowledge と knowledge-list に残る jq 失敗の丸めを exit 2 へそろえる"
date: 2026-10-13
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/424"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "projects/orchestration-engine/docs/episodes/2026-10-13-episode-283-validate-knowledge-jq-exit2.md"
    reason: "前の単位。同じ直し方の先例で、この単位の対象はその範囲外の節で見つかった"
tags: [orchestration, knowledge, validate-knowledge, knowledge-list, exit-code, jq]
---

# #424 validate-knowledge と knowledge-list に残る jq 失敗の丸めを exit 2 へそろえる

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

#283（PR #423）で、`validate-knowledge.sh` の型を読む4か所は、jq の評価が失敗したら ERROR を出して exit 2（環境エラー）で止まる形になった。同じスクリプトには、jq の失敗を item の不備（WARN・exit 1）へ丸める箇所・検査を飛ばして OK を返す箇所・何も出さずに exit 5 で終わる箇所が残っている。`knowledge-list.sh` にも、root の型を読む jq の失敗を `|| true` で空へ丸め、MALFORMED として skip する箇所がある。

統括の brief（`.oe/brief-424-knowledge-jq-exit2-rest.md`・作業層）。owner の承認（2026-10-13）により、plan・設計SO（ゲート2）・issue-intake は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテスト（bash 3.2 と 5 の両系）は省かない。master `3288b1b` から切った。

## 作業の記録

### brief と issue の断定を当て直した（2026-10-13）

- 行番号は、`3288b1b` の `validate-knowledge.sh` で issue の表のとおりだった（`has(key)` 196 行・`== null` 198 行・`// empty` の代入 205・212・220・230・288 行・`has("exclusions")` 356 行・exclusions の要素の型 364 行）。`knowledge-list.sh` の root の型の `|| true` も 249 行にある。
- **issue の表は、#283 の episode の範囲外の表より2か所少ない。** #283 の表の「代入」の行は 7 か所（`8b9138f` からの変更後の 203・210・218・228・250・266・286 行）を挙げていた。issue はそのうち `// empty` で読む5か所だけを写し、`trigger` / `prediction` を読む代入（`3288b1b` の 252 行）と `source.ref` を読む代入（268 行）が落ちている。どちらも `// empty` は使っていないが、`x="$(jq ...)"` の代入で、jq が失敗すると `set -e` で exit 5 になる同じ型である。扱いは下の「表の外の同じ型を洗い出した」節で決める。

### 変更前の master で、jq の呼び出しを1つずつ失敗させて結果を確かめた（2026-10-13）

negative knowledge `01KZRTSJ2VP8BZR0MF7QZRNYH7`（exit code は実行経路の性質なので、各経路を実際に通して確かめよ）に従い、issue の表を写さずに、`3288b1b` のスクリプトを #283 の [8c] と同じ stub（`STUB_JQ_FAIL` に合う引数の呼び出しだけを exit 5 で失敗させ、`STUB_JQ_LOG` に記録する）で通した。stub の記録は、どの行も1件（狙ったプログラム）だった。

| 箇所（`3288b1b` の行） | 使った item | jq が失敗したときの結果 |
|---|---|---|
| `validate-knowledge.sh` 196 行 `has("id")` | 正常な item | 「missing required key: id」の WARN・exit 1 |
| 198 行 `."id" == null` | `id: null` の item | 「required key is null: id」の WARN が消え、ULID の WARN だけで exit 1 |
| 205・212・220・230・288 行（`.type`・`.status`・`.id`・`.date`・`.landing` の `// empty`） | 正常な item | 何も出さずに exit 5 |
| 252 行（`trigger` / `prediction` を読む代入）・268 行（`source.ref` を読む代入） | 正常な item | 何も出さずに exit 5（issue の表に無い2か所） |
| 356 行 `has("exclusions")` | exclusions に数値 `42` を持つ item | 「OK」・exit 0（不正な item が通る） |
| 364 行（exclusions の要素の型） | 正常な item | 「exclusions elements must all be strings」の WARN・exit 1 |
| `knowledge-list.sh` 249 行（root の型） | 正常な item（explicit・単一ファイル・ディレクトリ） | 「malformed YAML frontmatter」の MALFORMED として skip。既定で exit 0、`--strict` で exit 1、`--json` でも malformed に入る |

issue の表で「確かめていない」とされていた `knowledge-list.sh` 249 行は、正常な item を壊れた item として報告していた。

### 表の外の同じ型を洗い出した（2026-10-13）

negative knowledge `01KZ3MHMEQN5XEJGV9809QPH2A`（名指しされた箇所を直した緑は、その型が消えた証拠ではない）に従い、2本のスクリプトの jq の呼び出しを全部当たった。

- **`validate-knowledge.sh` は、`validate_item` の中に jq の評価が17か所ある。** 6か所（root・`source`・`observations`・`exclusions` の型、日付の暦チェック、observations の要素スキーマ）はすでに exit 2 の形で、残る11か所が issue の表の9か所と、表に無い2か所（252・268 行）である。2か所はこの単位で直す。issue の題は「validate-knowledge に残る jq 失敗の丸めと握り潰し」で、2か所はその型にそのまま当たり、#283 の episode の範囲外の表でも「代入」の行に入っていた。直すと、`validate-knowledge` の jq の評価はすべて同じ形になり、README の説明から「ほかの呼び出しはまだそろっていない」という但し書きを外せる。
- **`knowledge-list.sh` は、249 行のほかにも jq の失敗を丸めたり exit 5 で終わったりする箇所がある。** stub で次の3つを確かめた。
  - item の JSON を組む代入（266 行）は、何も出さずに exit 5 で終わる。
  - 足し上げ用のフラグを読む `read <<<"$(jq ...)"`（297 行）は、jq が失敗しても止まらず、フラグが空のまま進む。`harmful` の観測を持つ active の item で通すと、item の行には「control-candidate: harmful」が出るのに、人向けの出力の末尾から「control-candidates: 1」が消え、exit 0 だった。
  - MALFORMED の行を組む `jq -n`（210 行ほか）は、何も出さずに exit 5 で終わる。
  - 出力を組む jq（`--json` と人向け）は試していない。`set -e` と `pipefail` で exit 5 になると読んでいるが、通してはいない。

  これらは**範囲外として報告する**。brief と issue は `knowledge-list.sh` を 249 行に限っており、残りは item の型を読む箇所ではなく、出力と集計を組む箇所である。直すなら、列挙側の exit の決まり（冒頭のコメントと README の表）に「jq の評価失敗」をどう書くかも一緒に決める必要があり、この単位の小さな直しを越える。

### 握り潰しを外す前に、正当な空や false がどこから来るかを確かめた（2026-10-13）

negative knowledge `01KYA7C9NN4VDM7H2NYXZB2PSX`（失敗と正当な値を分けよ。正当に空や false になる経路が無いかを確かめてから exit 2 に寄せよ）に従った。

- **正当な空や false は、どれも jq の終了コード 0 で来る。** `// empty` はキーが無いときや値が null・false のときに何も出さないが、終了コードは 0 である。`has(...)` と `== null` は true か false を返す。直し方は「jq の終了コードが 0 でないときだけ exit 2」なので、正当な空や false はこれまでどおり WARN の判定に流れる。
- **データから jq が失敗する経路は、最初の root の型の jq で切れている。** 以降の11か所は、root の型を読めた同じ `$json` を読む。プログラムはどれも map の root に対して失敗しない形で、型を確かめてから読む2か所（`source.ref` は `source` が map のときだけ、要素の型は `exclusions` が配列のときだけ）も分岐の内側にある。#283 が確かめきれなかった jq の深さの上限の経路は、起きるとしても root の型の jq で起き、今回の11か所には届かない。
- これを実物で確かめたのは、既存のテストである。キーの欠落・null・scalar の `source`・scalar の `exclusions`・数値の要素などの item を通す既存の検査が、変更後も全部 exit 1 のまま通った（データの不備が exit 2 に化けていない）。

### 直し方とテスト（2026-10-13）

- `validate-knowledge.sh` の11か所を、#283 の4か所と同じ `if ! x="$(jq ... 2>/dev/null)"; then echo "ERROR: ..." >&2; exit 2; fi` の形にした。`[[ "$(jq ...)" ... ]]` の中で終了コードを捨てていた箇所（必須キーの `has` と `== null`、`has("exclusions")`、要素の型）は、いったん変数に受けてから比べる形にした。必須キーの `elif` は、`has` が false なら WARN を出して次のキーへ進む `continue` に変えた（`== null` を読むのは `has` が true のときだけ、という元の順序は変えていない）。
- ERROR の文言は、どこで落ちたかが分かるように箇所ごとに分けた（`whether the required key '<key>' exists`・`whether the required key '<key>' is null`・`the value of '<key>'`・`whether the optional key 'exclusions' exists`・`the element types of 'exclusions'`）。
- これで `validate_item` の jq の評価17か所が、すべて同じ形になった。`grep` で、jq を呼ぶ行がすべて `if ! x="$(jq` の形であることを確かめた。理由のコメントは root の型の直前に1つだけ置き、「4か所」と限っていた書き方を「この関数の jq の呼び出しはすべて」に直した。スクリプト冒頭と `docs/knowledge/README.md` の exit 2 の説明からも、「ほかの jq の呼び出しはまだそろっていない」という但し書きを外した。
- `knowledge-list.sh` の 249 行は、yq の成功と root の型の jq を分けた。yq が失敗したときと型が object でないときは、従来どおり MALFORMED（理由は「malformed YAML frontmatter」のまま）。root の型の jq が失敗したときは、item の path を入れた ERROR を出して exit 2 にした。スクリプト冒頭の exit 2 と README の表に「frontmatter root の型を読む jq の評価失敗」を足し、README には、ほかの jq の呼び出しはまだそろっていないことを書いた。冒頭の exit の説明は `--help` が 3〜18 行を表示するので、1行のまま書き足して行数を変えていない。
- テストは、`test_validate_knowledge.sh` に [8e] を足した。[8d] と同じ stub で12か所を1つずつ失敗させ、exit 2・その箇所の ERROR・丸めたときに出る文字列（WARN か「OK:」）が出ないこと・stub が狙ったプログラムで落としたことを見る。要素の型のプログラムは角括弧を含むので、#283 の episode の注意どおり `*all(. == "string")*` をパターンに渡し、記録はプログラムの全文と照合した。`has("exclusions")` は、exclusions に数値を持つ item で通し、stub なしなら要素の型の WARN・exit 1 になることも対照として見た。
- `test_knowledge_list.sh` に [34] を足した。同じ stub を置き、既定・`--strict`・`--json` の3通りで、exit 2・ERROR・MALFORMED が出ないこと・stub の当たりを見る。対照として、yq が失敗する item と root が配列の item が、従来どおり MALFORMED で skip されることを見る。

### 足した検査が変更前で落ちることを確かめた（2026-10-13）

negative knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ`（判定の錨が変更そのものに在るかを見よ）と `01M00KCCHNMFPHP5HAGX2DZ1MK`（期待した色が期待した理由で出たかを見よ）に従った。

| 対象 | `test_validate_knowledge.sh` | `test_knowledge_list.sh` |
|---|---|---|
| 変更後・bash 3.2.57（`/bin/bash`） | 260 件・失敗 0 | 146 件・失敗 0 |
| 変更後・bash 5.2.37 | 260 件・失敗 0 | 146 件・失敗 0 |
| 変更前のスクリプト（`3288b1b`）に新しいテストを重ねたもの・bash 5 | 失敗 28 | 失敗 9 |

- 変更前で落ちた 28 件は、12か所それぞれの exit 2 と ERROR の2件ずつ（24 件）と、丸めの文字列が出た4件（`has("source")` の missing・`== null` と `has("exclusions")` の OK・要素の型の WARN）である。何も出さずに exit 5 で終わっていた8か所は、もともと WARN を出さないので「丸めていない」の検査は変更前でも通る。この8か所の錨は exit 2 と ERROR の2件である。
- 変更前で落ちた 9 件は、3通りそれぞれの exit 2・ERROR・MALFORMED が出ないことの3件ずつである。
- **stub の当たりの検査（validate 側 12 件・list 側 3 件）と対照（validate 側 2 件・list 側 4 件）は、変更前でも通った。** 変更前も stub は狙った呼び出しを失敗させており、その失敗が丸められていた。これらは錨に数えない。
- 実物の knowledge store 3つ（`docs/harness`・`docs/orchestration-engine`・`projects/orchestration-engine/docs` の `knowledge/items`）は、変更後の `validate-knowledge` でどれも OK だった。`knowledge-list --strict` は 70 件・skipped 0・exit 0 で、brief の列挙と同じだった。
- `shellcheck` は変更した4ファイル（スクリプト2本・テスト2本）で警告 0。
- テストを1回のコマンドで両方の bash に回そうとしたところ、Claude Code の安全確認（テストの後始末の `rm -rf` を中身まで確かめられないという理由）で止められた。1本ずつ回し直して通した。

### 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）

依頼文は `tmp/424/so-impl-prompt.md`（作業層・gitignore）で、6つの仮定（データ由来の失敗が無い・item の不備への振る舞いが変わらない・knowledge-list は jq の失敗時以外変わらない・テストの照準と bash 3.2・ドキュメントの説明・範囲外の判断）の反証を求めた。Codex は初回で返った（`attempt=1`・307 秒・`timeout_status=success`・`model_resolved=gpt-6.1-sol`（`config` 由来で観測値ではない）・`codex-cli 0.159.2`）。

- **6つとも「成り立つ」だった。** 仮定1について、Codex は自分で 145 件の JSON の境界値を jq に通し、どれも終了コード 0 だったと書いている。件数の数え方について、変更は「11の呼び出し箇所・12のプログラム」（`trigger` と `prediction` が同じループを使う）で、episode とテストの数が食い違って見えても矛盾ではない、と補足した。
- **低い指摘: stub が実 jq のパスを引用していない。** `printf 'exec %s "$@"\n' "$_REAL_JQ"` は、jq の置き場に空白があると転送先が複数の語に分かれ、狙っていない呼び出しまで失敗させる。この環境（`/opt/homebrew/bin/jq`）では起きない。validate 側は #283 が書いた既存の行で、list 側はこの単位でそれを写した行である。
  - **採否: 採った。** 両方の行を `%q` に変えた。validate 側は既存の行だが、同じ stub の2つの写しが食い違うほうが後で困るので、そろえて直した。`/bin/bash`（3.2）の `printf %q` が空白を含むパスを1語に引用することを確かめ、両方のテストを bash 3.2 と 5 で回し直して、260 件と 146 件・失敗 0 のままだった。
- **既存の中程度の問題として、`knowledge-list.sh` のフラグを読む `read <<<"$(jq ...)"` が jq の終了コードを捨てていることを挙げた。** この単位で範囲外として報告すると決めたもの（「表の外の同じ型を洗い出した」の節）と同じで、今回の変更の正しさは崩さない、という判定だった。採否: 範囲外のまま報告する（変えない）。

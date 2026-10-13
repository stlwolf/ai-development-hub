---
id: "01M4TS0EW6SSSXWTX67KZX35XY"
title: "#424 validate-knowledge と knowledge-list に残る jq 失敗の丸めを exit 2 へそろえる"
date: 2026-10-13
type: episode
status: stable
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/424"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "projects/orchestration-engine/docs/episodes/2026-10-13-episode-283-validate-knowledge-jq-exit2.md"
    reason: "前の単位。同じ直し方の先例で、この単位の対象はその範囲外の節で見つかった"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/pull/425"
    reason: "この episode が記録する作業の PR"
tags: [orchestration, knowledge, validate-knowledge, knowledge-list, exit-code, jq]
promotion:
  - subject: "表の外の同じ型のうち validate-knowledge の2か所は直し、knowledge-list の残りは範囲外として報告する"
    verdict: not-required
    ref: "本文: 表の外の同じ型を洗い出した（2026-10-13）"
  - subject: "jq の失敗の扱いを共通の関数にまとめず、同じ形で書き下す"
    verdict: not-required
    ref: "本文: 共通の関数にまとめず、11か所を同じ形で書き下した（2026-10-13）"
  - subject: "実装SO の stub の指摘を、この単位で写した行だけでなく #283 の既存の行にも当てる"
    verdict: not-required
    ref: "本文: 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）"
knowledge_observations:
  - "01KYA7C9NN4VDM7H2NYXZB2PSX"
  - "01KZRTSJ2VP8BZR0MF7QZRNYH7"
  - "01M00KCCHNMFPHP5HAGX2DZ1MK"
  - "01M2DRCP3QSG4NQWHNY6DSD3NJ"
  - "01KZ3MHMEQN5XEJGV9809QPH2A"
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

### 共通の関数にまとめず、11か所を同じ形で書き下した（2026-10-13）

この節は closure の時点で書いた。実装中に検討したが、その場では本文に書いていなかった。

17か所が同じ4行の形になるので、`jq_read <変数名> <説明> <jq の引数...>` のような関数（`printf -v` で呼び出し側の変数に入れ、失敗したら ERROR と exit 2）にまとめる案を考えた。`$(...)` の中で `exit 2` しても subshell しか終わらないので、関数にするなら `printf -v` で値を返す形になる（bash 3.2 でも使える）。

採らなかった。brief が「#283 でそろえた4か所と同じ形にする」と指定しており、関数にするなら #283 の4か所と日付・observations の2か所も書き換えることになり、この単位の小さな直しを越える。同じ形を書き下しておけば、`grep` で「jq を呼ぶ行がすべて `if ! x="$(jq` の形か」を確かめられる（「直し方とテスト」の節で使った確かめ方）。

### PR を作り、Copilot のレビューを1ラウンド受けた（2026-10-13）

PR #425 を作り、Copilot に1回依頼した（timeline に `review_requested Copilot` が出ることで登録を確かめた）。結果は「Approval recommended・0 open findings」で、行コメントは無く、未返信のスレッドは 0 件である。再依頼はしていない。

## closure（2026-10-13）

tier は heavy である。意図して起動した外部レビュー（実装SO）があるため。失敗や撤回は小さなものに限られ、方針の転回は無かった。

### 次の消費者

- `knowledge-list.sh` の残りの jq の呼び出し（item の JSON を組む代入・フラグを読む `read`・MALFORMED の行を組む `jq -n`・出力を組む jq）を直す作業。stub で通した結果と、試していない箇所は `本文: 表の外の同じ型を洗い出した（2026-10-13）` にある。直すなら、`test_knowledge_list.sh` の [34] の stub をそのまま使える。
- `validate-knowledge` と `knowledge-list` の exit code を読む呼び出し側（hook や統括の確認）。`validate-knowledge` は item を読むすべての jq の評価失敗で exit 2 を返し、`knowledge-list` は root の型を読む jq の評価失敗で exit 2 を返すようになった。`本文: 直し方とテスト（2026-10-13）`

### 事実・失敗

- issue の表は、#283 の episode の範囲外の表から2か所（`trigger` / `prediction` と `source.ref` の代入）を落としていた。`本文: brief と issue の断定を当て直した（2026-10-13）`
- 範囲外の確かめで、制御候補の件数が少なく出るという文を、通す前に読みだけで書いた。書いた直後に `harmful` の観測を持つ item で通し、確かめた結果の文に置き換えた。`本文なし: 書いた直後に置き換えたので、本文には確かめたあとの文だけが残っている`
- 変更前の確かめに使った作業層の試しのコマンドで、item を置くディレクトリを作る前に書き込もうとして1回エラーが出た。同じコマンドの中で作り直して続けた。`本文なし: 作業層の試しの手順の誤りで、本文の表の結果には影響しないため`
- テストを1回のコマンドで両方の bash に回そうとして、Claude Code の安全確認に止められた。1本ずつ回し直した。`本文: 足した検査が変更前で落ちることを確かめた（2026-10-13）`
- 実装SO が、stub が実 jq のパスを引用していないことを指摘した（低）。#283 の既存の行と、この単位で写した行の両方にあった。`本文: 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）`
- 共通の関数にまとめる案を実装中に検討したが、その場で本文に書いていなかった。closure の時点で節を立てて書いた。`本文: 共通の関数にまとめず、11か所を同じ形で書き下した（2026-10-13）`
- 実装SO が、`knowledge-list.sh` のフラグを読む `read <<<"$(jq ...)"` が jq の終了コードを捨てていることを、既存の中程度の問題として挙げた。この単位で範囲外として報告すると決めたものと同じで、変えていない。`本文: 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）`
- closure のコミットの前に回した検査（frontmatter が読めるか・本文への pointer が一意の見出しを指すか）が、yq の式の書き間違いで最初の段で止まり、`&&` でつないだ残りの検査を飛ばしたままコミットまで進んだ。コミットのあとで検査を正しく回し直し、frontmatter が読めることと、pointer がすべて一意の見出しを指すことを確かめた。`本文なし: closure を書いたあとの手順の誤りで、本文の節が扱う作業より後に起きたため`

### 決定と根拠

- 表の外の2か所はこの単位で直し、`knowledge-list.sh` の残りは範囲外として報告した。`本文: 表の外の同じ型を洗い出した（2026-10-13）`
- 握り潰しは、jq の終了コードが 0 でないときだけ exit 2 にする形で外した（正当な空や false は終了コード 0 で来る）。`本文: 握り潰しを外す前に、正当な空や false がどこから来るかを確かめた（2026-10-13）`
- `knowledge-list.sh` では、yq が失敗したときに root の型を空のままにして、MALFORMED を出す箇所を1つに保った。冒頭の exit の説明は `--help` の表示範囲を変えないよう1行のまま書き足した。`本文: 直し方とテスト（2026-10-13）`
- 共通の関数にまとめず、同じ形で書き下した。`本文: 共通の関数にまとめず、11か所を同じ形で書き下した（2026-10-13）`
- 実装SO の stub の指摘は、既存の行にも当てて2つの写しをそろえた。`本文: 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）`

### 蒸留シグナル

- decision / skill / rule への昇格候補はない。negative knowledge の収穫もしない（下の昇格の判定を見よ）。`本文なし: 判定の結果をまとめた行で、根拠は下の昇格の判定の各項目が本文を指す`

### 昇格の判定

本文に `昇格の印:` は置かなかった。印の無い判断を3件挙げて判定した。

1. **表の外の同じ型のうち validate-knowledge の2か所は直し、knowledge-list の残りは範囲外として報告する** — `not-required`。この単位の範囲の判断で、覆すのは「直すかどうか」を見れば決まる確認であって議論ではない（Q2 に当たらない）。横に探して範囲内か範囲外かを決めて書く、という振る舞いは negative knowledge `01KZ3MHMEQN5XEJGV9809QPH2A` に着地している。参照した材料は `本文: 表の外の同じ型を洗い出した（2026-10-13）`。
2. **jq の失敗の扱いを共通の関数にまとめず、同じ形で書き下す** — `not-required`。理由は brief の指定とこの単位の範囲で、どちらもこの単位にしか効かない。将来まとめる作業は17か所を一度に書き換えれば済み、この判断を覆すのに設計原則の議論は要らない。参照した材料は `本文: 共通の関数にまとめず、11か所を同じ形で書き下した（2026-10-13）`。
3. **実装SO の stub の指摘を、この単位で写した行だけでなく #283 の既存の行にも当てる** — `not-required`。2つの写しをそろえるだけの直しで、別の解釈が実際に争われたわけではない（Q1 に当たらない）。参照した材料は `本文: 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）`。

negative knowledge の収穫候補として「上流の表を写すと、写すときの絞り込みで項目が落ちる」を考えたが、収穫しない。同旨は brief の規律（上流の断定は使う前に実在を確かめる）と `01KZ3MHMEQN5XEJGV9809QPH2A` に着地しており、未着地の確認を満たさない。`本文: brief と issue の断定を当て直した（2026-10-13）`

### 注入された negative knowledge への観測

brief がこの単位に割り当てた item は5件で、5件とも観測を書き戻した（`ref: "#424"`・すべて `followed`）。

- `01KYA7C9NN4VDM7H2NYXZB2PSX`（正当な空や false が終了コード 0 で来ることと、データ由来の経路が root の型で切れることを確かめてから外した）`本文: 握り潰しを外す前に、正当な空や false がどこから来るかを確かめた（2026-10-13）`
- `01KZRTSJ2VP8BZR0MF7QZRNYH7`（issue の表を写さず、変更前のスクリプトを stub で通してから表を書いた）`本文: 変更前の master で、jq の呼び出しを1つずつ失敗させて結果を確かめた（2026-10-13）`
- `01M00KCCHNMFPHP5HAGX2DZ1MK`（stub の記録で当たりを見た。角括弧を含むプログラムはパターンを * で囲み、全文と照合した）`本文: 直し方とテスト（2026-10-13）`
- `01M2DRCP3QSG4NQWHNY6DSD3NJ`（変更前に重ねて 28 件・9 件落ちることを確かめ、変更前でも通る検査は錨に数えなかった）`本文: 足した検査が変更前で落ちることを確かめた（2026-10-13）`
- `01KZ3MHMEQN5XEJGV9809QPH2A`（jq の呼び出しを全部当たり、表の外の2か所を直し、残りを範囲外として報告した）`本文: 表の外の同じ型を洗い出した（2026-10-13）`

### follow-up

- `knowledge-list.sh` の残りの jq の呼び出し（試していない出力の jq を含む） → **PR #425 本文の「範囲外で見つけたもの」節に記録し、統括への報告（`.oe/report-424.md` の Out-of-scope findings）で issue にするかの判断を渡す**。`本文: 表の外の同じ型を洗い出した（2026-10-13）`
- issue #424 本文の表から2か所が落ちていたこと → **追わない**。この PR で直し、PR 本文の変更の表と episode に記録した。issue 本文は書き換えない。`本文: brief と issue の断定を当て直した（2026-10-13）`

### 証跡の置き場

実装SO の依頼文と出力は `tmp/424/`（作業層・gitignore）にあり消える。要点（仮定ごとの判定・指摘・採否・所要時間とモデル）は `本文: 実装SO（ゲート4・弱・Codex 1レーン）は6つの仮定を「成り立つ」とし、低い指摘1件を出した（2026-10-13）` に写した。変更前の stub の試しは scratchpad で行い、結果は `本文: 変更前の master で、jq の呼び出しを1つずつ失敗させて結果を確かめた（2026-10-13）` の表に写した。

closure の外部チェック（Step 4・Codex 1レーン・95 秒・初回で返った）は、同じく `tmp/424/` に置いた。4点のうち、routing・揮発パス・back-propagation の3点は問題なし、選択的省略の1点が問題あり（中）だった。実装SO が挙げた `knowledge-list.sh` の既存の中程度の問題が、本文と PR 本文と follow-up には在るのに、事実・失敗に項目として出ていなかった。採って、上の事実・失敗に足した。同じ機会に、closure のコミット前の検査を飛ばした件も足した。

### status

`stable`・達成。

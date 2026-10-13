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

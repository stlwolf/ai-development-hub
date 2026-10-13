---
id: "01M4SWMDMMZ6TEBDNQETN70JPN"
title: "#283 validate-knowledge の型読み4か所の jq 失敗握り潰しを exit 2 へそろえる"
date: 2026-10-13
type: episode
status: in-development
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/283"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "projects/orchestration-engine/docs/episodes/2026-10-13-episode-419-bash32-whitespace-check.md"
    reason: "前の単位。この単位は #419 のマージ後の master から切り、両系ゲートを前提にする"
tags: [orchestration, knowledge, validate-knowledge, exit-code, jq]
---

# #283 validate-knowledge の型読み4か所の jq 失敗握り潰しを exit 2 へそろえる

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

`validate-knowledge.sh` は、frontmatter の root・`source`・`observations`・`exclusions` の型を `jq -r ... | type` で読み、その失敗を `2>/dev/null || true` で握り潰して空へ丸めていた。jq の評価が失敗する（環境の問題）と、空が「型が違う」と読まれて WARN・exit 1 になり、呼び出し側は item を直そうとする。#282（#274）で日付の暦チェックの同じ丸めを ERROR・exit 2 へ直したが、この4か所は範囲外として残っていた。exit code の契約（1 は item の不備、2 は環境エラー）をそろえる hygiene である。

統括の brief（軽微修正4件の束の U4）。#419（PR #420）のマージ後の master `8b9138f` から切った。owner の承認（2026-10-13）により、plan・設計SO（ゲート2）・issue-intake は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテスト（bash 3.2 と 5 の両系）は省かない。

## 作業の記録

### brief と issue の断定を当て直した（2026-10-13）

- 4か所は、`8b9138f` では 175・247・284・339 行にある。brief の 169・241・278・333 行は `a8e8726` での番号で、#419 でこの単位より前にコメントを6行足した分だけずれている。中身は brief のとおり `jq -r ... type ... 2>/dev/null || true` だった。
- 手本の日付チェック（`8b9138f` では 227 行付近）は、`if ! out="$(jq ... 2>/dev/null)"; then echo "ERROR: ..." >&2; exit 2; fi` の形である。observations の要素スキーマのフィルタ（326 行付近）も同じ形をとっている。
- issue は「失敗はほぼ理論上のみ」と書いていた。

### 握り潰しを外す前に、データから同じ失敗が来る経路が無いかを確かめた（2026-10-13）

negative knowledge `01KYA7C9NN4VDM7H2NYXZB2PSX`（失敗と正当に空な出力を分けよ。握り潰しを外す前に、空が正当な値として来る経路を確かめよ）に従った。4か所の jq が失敗しうるのは、入力 `$json` が JSON として読めないときと、jq そのものが動かないときである。前者がデータ（item の YAML）から来るなら、握り潰しを外すと item の不備が「環境エラー」に化ける。

yq（v4.45.4）に、JSON にしにくい YAML を19通り与えて確かめた（`.inf`・`-.inf`・`+.inf`・`.nan`・`!!float 1e400`・不正な Unicode・`!!binary`・時刻・30桁の整数・16進と8進・コメントだけ・空・アンカー・`!!set`・独自タグ・配列）。**yq が JSON として壊れた出力を返した例は無かった。** JSON にできない値（無限大・NaN・不正な Unicode）は、どれも yq 自体が失敗した。yq の失敗は手前の 171 行で「malformed YAML frontmatter」の WARN・exit 1 になり、4か所へは届かない。コメントだけや空の YAML は `null` になり、root の型の検査で「not a map」の WARN になる（jq は失敗しない）。

したがって4か所の jq が失敗するのは環境の問題に限られ、exit 2 に寄せてよい。ただし、19通りで全部を言い切ったわけではない（yq が終了コード 0 で壊れた JSON を返す入力は、見つからなかったというだけである）。

### 直し方とテスト（2026-10-13）

- 4か所を、手本の日付チェックと同じ `if ! x="$(jq ... 2>/dev/null)"; then echo "ERROR: ..." >&2; exit 2; fi` の形にした。ERROR の文言は箇所ごとに `failed to evaluate the <frontmatter root|source|observations|exclusions> type with jq (environment error, not an item defect)` とし、どの箇所で落ちたかが分かるようにした。型の不一致の WARN と exit 1 は変えていない。理由は root の判定の直前に1つだけコメントで書き、残り3か所は同じ形にそろえた。
- 任意とされていた exit 2 の説明（スクリプト冒頭と `docs/knowledge/README.md`）に「jq の評価失敗」を足した。日付チェックと observations の要素スキーマはすでに jq の評価失敗で exit 2 を返していたのに、説明には無かった。
- テストは、[8c] の PATH の stub を「`STUB_JQ_FAIL`（case のパターン）に合う引数を持つ呼び出しだけを失敗させ、その引数を `STUB_JQ_LOG` に記録する」形に広げた。[8c] は `STUB_JQ_FAIL='*cal_ok*'` を渡して従来と同じ動きにした。新しい [8d] は4か所のプログラムを1つずつ失敗させ、exit 2・その箇所の ERROR・その箇所の WARN が出ないこと・stub が狙ったプログラムで落としたこと（記録がそのプログラムの1行だけであること）を見る。

### 足した検査が変更前で落ち、落ちた理由が狙った呼び出しであることを確かめた（2026-10-13）

| 対象 | `test_validate_knowledge.sh` |
|---|---|
| 変更後・bash 3.2.57 | 210 件・失敗 0（19 秒） |
| 変更後・bash 5.2.37 | 210 件・失敗 0（19 秒） |
| 変更前のスクリプト（`8b9138f`）に新しいテストを重ねたもの・bash 5 | 失敗 12 |

変更前で落ちた 12 件は、4か所それぞれの「exit 2」「ERROR の文言」「WARN が出ない」の3件ずつである。**「stub が狙ったプログラムで落とした」の4件は変更前でも通った。** つまり変更前も stub は狙った呼び出しを失敗させており、その失敗が WARN・exit 1 に丸められていた。negative knowledge `01M00KCCHNMFPHP5HAGX2DZ1MK`（期待した色が期待した理由で出たかを見よ）と `01M2DRCP3QSG4NQWHNY6DSD3NJ`（足した検査の錨が変更にあるかを見よ）の両方に当たる確かめ方である。

`test_knowledge_list.sh`（検証スクリプトを呼ぶ検査を含む）も、bash 3.2 と 5 の両方で 130 件・失敗 0 だった。`shellcheck` は変更した2ファイルで警告 0。

### stub のパターンは glob なので、角括弧を含むプログラムは文字列として一致しない（2026-10-13）

範囲外の箇所を試したとき、`[.exclusions[] | type] | all(. == "string")` をそのまま `STUB_JQ_FAIL` に渡すと、stub が当たらずに「OK」が返った。case のパターンとして読まれるので、`[` と `]` が文字の範囲指定になる。最初はそれを「失敗しても検査を通ってしまう」と読みかけたが、記録が空であることから stub が当たっていないと分かった。パターンを `*all(. == "string")*` にすると当たった。[8d] の4つのプログラムは glob の文字を含まないので、この問題は起きない（記録の照合で当たったことも確かめている）。stub のコメントには「case のパターン」と書いた。

昇格の印: PATH の stub に失敗させる対象をパターンで渡すときは、当たったことを記録で確かめる（glob の文字を含むと黙って外れ、「失敗しても通る」と誤読する）

### 範囲外の同じ型を通して確かめた（2026-10-13）

negative knowledge `01KZRTSJ2VP8BZR0MF7QZRNYH7`（exit code は実行経路の性質なので、各経路を実際に通して確かめよ）と `01KZ3MHMEQN5XEJGV9809QPH2A`（同じ型を横に探せ）に従い、brief が範囲外に挙げた箇所と、残る jq の呼び出しを、変更後のスクリプトで stub を使って1つずつ失敗させた。直さずに報告する。

| 箇所（`8b9138f` からの変更後の行） | jq が失敗したときの結果 | brief |
|---|---|---|
| `has("exclusions")`（354 行） | exclusions の検査が飛ばされる。文字列でない要素を持つ item が「OK」・exit 0 になる | 挙げていた |
| 代入（`.type`・`.status`・`.id` の `// empty` など、203・210・218・228・250・266・286 行） | 何も出さずに exit 5 で終わる（`set -e`）。契約の 0・1・2 のどれでもない | 挙げていた |
| 必須キーの `has(key)` と `== null`（194・196 行） | 「missing required key」の WARN・exit 1（データの不備に化ける） | 無かった |
| exclusions の要素の型（362 行） | 正常な item に「exclusions elements must all be strings」の WARN・exit 1 | 無かった |
| `scripts/knowledge-list.sh` の root の型（249 行・`|| true`） | 試していない（同じ形の握り潰しがあることだけ確かめた） | 挙げていた（247 行は `a8e8726` での番号） |

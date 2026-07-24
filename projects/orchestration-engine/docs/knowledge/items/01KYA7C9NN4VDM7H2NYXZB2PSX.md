---
id: "01KYA7C9NN4VDM7H2NYXZB2PSX"
type: knowledge
status: active
date: 2026-07-24
trigger: "外部コマンド（git show / cat 等）の失敗を `|| true` や `2>/dev/null` で握り潰し、空出力をそのまま後段に流すとき"
prediction: "IO / 環境の失敗（object 欠損・権限・partial clone・ファイル消失）が『空 ＝ 壊れたデータ』に誤分類され、環境エラー用の exit（例 exit 2）でなくデータ不備の経路に落ちる。呼び出し側は修復アクション（git fetch 等）を誤り、不完全な結果を成功扱いしうる"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-07-24-episode-273-nk-match-inject.md"
landing: nl
observations: []
exclusions:
  - "失敗と空出力が意味的に等価で、区別する必要がないケース"
---

`content="$(git show HEAD:$path 2>/dev/null || true)"` のように失敗を握り潰すと、コマンドの**失敗（環境エラー）**と**正当に空な出力（データ）**が区別できなくなる。後段が「空 ＝ 壊れた／欠けたデータ」と解釈すると、本来 exit 2（環境エラー・要 `git fetch` 等）で止めるべきものが、malformed/skip といったデータ不備の経路に落ちる。呼び出し側は誤った修復（frontmatter を直す等）に誘導され、しかも不完全な集合を「列挙成功」と誤認する。

非自明なのは、**失敗と空データは exit code でしか区別できない**点である。失敗した `git show` は exit≠0、正当に空な blob は exit 0 + 空出力。`|| true` はこの唯一の判別材料（exit code）を捨てている。

次にどう行動を変えるか: 握り潰さず**コマンドの exit code を検査**し、環境/IO 失敗は環境エラー（exit 2 等）として区別して即停止する。空出力は exit 0 のときだけ「正当に空なデータ」として扱う。列挙・集計系では「一部が読めなかった」を成功に混ぜない（完全性を別途 surface する）。

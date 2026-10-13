---
id: "01M4STTT9HQBG97EQ6W6M2AVKD"
type: knowledge
status: active
date: 2026-10-13
trigger: "壊れた記録にも耐える jq の投影で、表示する値に gsub・test・ascii_downcase などの文字列の関数を足すとき（無害化の畳みを後付けするときが典型）"
prediction: "文字列以外の値（数値・真偽値）が1つ来ただけで jq 全体がエラーになり、投影が丸ごと失敗する。足す前は join が数値や真偽値を文字にして通していたので表示できており、退行になる"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-10-13-episode-242-oe-activity-label-sanitize.md"
landing: nl
observations: []
---

**jq の文字列の関数は、文字列以外を受けると投影全体を落とす。足す前に、その値が文字列でない形で来うるかを見て、来うるなら `if type == "string" then ... else . end` で守る。**

#242 で起きかけた。`oe-activity` の label に、手本の `oe-undelivered` と同じ `gsub("[[:cntrl:]]"; " ")` を足そうとした。label は通常は文字列だが、`oe-activity` は壊れた行を飛ばして表示を続ける作りで、手で直した記録や古い記録にも耐えることを目指している。jq 1.8.0 で確かめると、`42 | gsub(...)` はエラーで終わる。一方、足す前の `join` は `[1,"a",null,true] | join("|")` を `1|a||true` にして通す。**そのまま写すと、数値の label が1つあるだけで「failed to project」になり、いま表示できている記録が見えなくなる。**

手本の `oe-undelivered` は実際にこの形で、数値の label の記録を与えると exit 1 になった（#242 で再現・範囲外として報告）。手本が動いているのは、event-bus が `--arg` で label を必ず文字列として書くからで、壊れた記録を想定していないからではない。**手本の正しさは、その手本が受ける入力の範囲でしか保証されない。**

見分け方は、足す関数の型の要求と、足す場所の前段が値の型を揃えているかである。`fromjson? // empty` のように壊れた行を黙って飛ばす前段は、JSON として読める行なら型を問わず通すので、型は揃っていない。`// ""` は null と false を空文字にするが、数値は通す。

守った形のテストは、数値の label を与えて表示が続くことを見る。この検査は変更前でも通る（足す前は join が通していたので）。変更そのものの錨ではなく、守りを外した写しで落ちることを確かめて置く検査である。

#!/usr/bin/env bash
# 対比較の一括投入。組ごとに両腕を1本ずつ流す。
# usage: run-fork-batch.sh <RUN> [対照の設定文名] [処置の設定文名]
#
# 対照の腕も設定文の名前を明示する（本文の無い空の設定文）。
# 「指定しない」は対照にならない。理由は run-fork.sh の冒頭にある。
set -uo pipefail
RUN="$1"
CONTROL_STYLE="${2:-oe348-empty}"
TREAT_STYLE="${3:-readable-conversation}"
python3 - "$RUN" "$CONTROL_STYLE" "$TREAT_STYLE" > "$RUN/fork/joblist.txt" <<'PYEOF'
import io, json, os, sys
run, control, treat = sys.argv[1], sys.argv[2], sys.argv[3]
pairs = json.load(io.open(os.path.join(run, 'fork-pairs.json'), encoding='utf-8'))
# 全組の両腕を必ず出す。「もう流した」を理由に間引かない。間引くと、きれいな
# 出力先から回したときに対が片方だけ欠けたまま揃わない（#348 で組4が欠けた）。
# 流し直したくない run があるなら、投入する側で joblist から外す。
for i, p in enumerate(pairs):
    for st in (control, treat):
        print("%02d\t%s\t%s" % (i, p['sess'], st))
PYEOF
n=0
while IFS=$'\t' read -r idx sess st; do
  [[ -z "${idx:-}" ]] && continue
  "$RUN/run-fork.sh" "$idx" "$sess" "$st" "$RUN/fork/prompts/p${idx}.txt" "$RUN/fork" &
  n=$((n+1))
  if (( n % 3 == 0 )); then wait; fi
done < "$RUN/fork/joblist.txt"
wait
total="$(wc -l < "$RUN/fork/joblist.txt" | tr -d ' ')"
failed="$(awk -F'\t' '$7=="failed"' "$RUN/fork/fork-manifest.tsv" 2>/dev/null | wc -l | tr -d ' ')"
echo "fork batch done: ${total} jobs / failed=${failed}"
[[ "$failed" -eq 0 ]] || exit 1

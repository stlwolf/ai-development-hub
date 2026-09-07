#!/usr/bin/env bash
set -uo pipefail
RUN="$1"
python3 - "$RUN" > "$RUN/fork/joblist.txt" <<'PY'
import io,json,os,sys
run=sys.argv[1]
pairs=json.load(io.open(os.path.join(run,'fork-pairs.json'),encoding='utf-8'))
for i,p in enumerate(pairs):
    for st in ('none','readable-conversation'):
        if i==4 and st=='none':   # 配線確認で実施済み
            continue
        print(f"{i:02d}\t{p['sess']}\t{st}")
PY
n=0
while IFS=$'\t' read -r idx sess st; do
  [[ -z "${idx:-}" ]] && continue
  "$RUN/run-fork.sh" "$idx" "$sess" "$st" "$RUN/fork/prompts/p${idx}.txt" "$RUN/fork" &
  n=$((n+1))
  if (( n % 3 == 0 )); then wait; fi
done < "$RUN/fork/joblist.txt"
wait
echo "fork batch done: $(wc -l < "$RUN/fork/joblist.txt") jobs"

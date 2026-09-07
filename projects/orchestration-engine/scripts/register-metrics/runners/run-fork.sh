#!/usr/bin/env bash
# R-1'' 実文脈 fork 対比。--fork-session を必ず付け、元のセッションに書き足さない。
# usage: run-fork.sh <idx> <sess> <style|none> <promptfile> <outdir>
# 転記の置き場は PROJECT_DIR で渡す（既定は cwd から Claude Code が作る slug）。
set -uo pipefail
idx="$1"; sess="$2"; style="$3"; pf="$4"; outdir="$5"
tag="fork-${idx}-${sess}-${style}"
mkdir -p "$outdir"
proj_dir="${PROJECT_DIR:-$HOME/.claude/projects/$(pwd | sed 's|/|-|g')}"
if [[ ! -d "$proj_dir" ]]; then
  echo "PROJECT_DIR が見つからない: $proj_dir" >&2
  exit 2
fi
sid=""
for f in "$proj_dir/${sess}"*.jsonl; do
  [[ -e "$f" ]] || continue
  sid="$(basename "$f" .jsonl)"
  break
done
if [[ -z "$sid" ]]; then
  echo "セッションが見つからない: ${sess} in $proj_dir" >&2
  exit 2
fi
args=(-p --model opus --output-format json --resume "$sid" --fork-session)
if [[ "$style" != "none" ]]; then
  args+=(--settings "{\"outputStyle\":\"${style}\"}")
fi
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
timeout 900 claude "${args[@]}" "$(cat "$pf")" < /dev/null > "$outdir/${tag}.json" 2>"$outdir/${tag}.err"
rc=$?
python3 - "$outdir/${tag}.json" "$outdir/${tag}.txt" "$outdir/${tag}.sid" <<'PY'
import json,sys,io
try:
    d=json.load(io.open(sys.argv[1],encoding='utf-8'))
    io.open(sys.argv[2],'w',encoding='utf-8').write(d.get('result') or '')
    io.open(sys.argv[3],'w',encoding='utf-8').write(d.get('session_id') or '')
except Exception:
    io.open(sys.argv[2],'w',encoding='utf-8').write('')
    io.open(sys.argv[3],'w',encoding='utf-8').write('')
PY
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$tag" "$sess" "$style" "$sid" "$(cat "$outdir/${tag}.sid" 2>/dev/null)" "$started" >> "$outdir/fork-manifest.tsv"
echo "[fork] $tag rc=$rc newsid=$(cat "$outdir/${tag}.sid" 2>/dev/null) chars=$(python3 -c "import io;print(len(io.open('$outdir/${tag}.txt',encoding='utf-8').read()))")"

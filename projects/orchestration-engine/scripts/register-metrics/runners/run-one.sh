#!/usr/bin/env bash
# 1 run = 1 条件 × 1 題 × 1 反復。結果と実行環境の記録を JSON で保存する。
# usage: run-one.sh <cond> <style|none> <prompt_file> <rep> <outdir> [extra_env]
set -uo pipefail
cond="$1"; style="$2"; pfile="$3"; rep="$4"; outdir="$5"; extra="${6:-}"; label="${7:-}"
tag="${cond}-${label:-$(basename "$pfile" .txt)}-r${rep}"
pname="${label:-$(basename "$pfile" .txt)}"
mkdir -p "$outdir"
prompt="$(cat "$pfile")"
args=(-p --model opus --output-format json)
# NORULES=1 で操作者の設定を全部落とす。project,local では project の CLAUDE.md が残るので
# 「指示がまったく無い floor」にならない（計画 §7）。空文字列で user / project / local を落とす。
if [[ "${NORULES:-}" == "1" ]]; then args+=(--setting-sources ""); fi
if [[ "$style" != "none" ]]; then
  args+=(--settings "{\"outputStyle\":\"${style}\"}")
fi
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cliver="$(claude --version 2>/dev/null | head -1)"
if [[ -n "$extra" ]]; then
  env "$extra" timeout 900 claude "${args[@]}" "$prompt" < /dev/null > "$outdir/${tag}.json" 2>"$outdir/${tag}.err"
else
  timeout 900 claude "${args[@]}" "$prompt" < /dev/null > "$outdir/${tag}.json" 2>"$outdir/${tag}.err"
fi
rc=$?
ended="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# 応答本文を取り出す
python3 - "$outdir/${tag}.json" "$outdir/${tag}.txt" <<'PY'
import json,sys,io
try:
    d=json.load(io.open(sys.argv[1],encoding='utf-8'))
    txt=d.get('result') or ''
except Exception as e:
    txt=''
io.open(sys.argv[2],'w',encoding='utf-8').write(txt)
PY
model="$(python3 -c "
import json,io,sys
try:
    d=json.load(io.open('$outdir/${tag}.json',encoding='utf-8'))
    mu=d.get('modelUsage') or {}
    print(','.join(mu.keys()) or d.get('model','?'))
except Exception: print('?')
")"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$tag" "$cond" "$style" "$pname" "$rep" "$started" "$ended" "$model" "$cliver" >> "$outdir/manifest.tsv"
echo "[done] $tag rc=$rc model=$model chars=$(python3 -c "import io;print(len(io.open('$outdir/${tag}.txt',encoding='utf-8').read()))")"

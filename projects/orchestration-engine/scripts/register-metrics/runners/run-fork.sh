#!/usr/bin/env bash
# R-1'' 実文脈 fork 対比。--fork-session を必ず付け、元のセッションに書き足さない。
# usage: run-fork.sh <idx> <sess> <style> <promptfile> <outdir>
#
# 対照の腕も設定文の名前を明示すること（本文の無い空の設定文を使う）。
# 「指定しない」は対照にならない。--settings を省くと live の outputStyle を
# 受け継ぐので、両腕が同じ設定文になる。#348 の R-4b はこれで無効になった。
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
if [[ "$style" == "none" ]]; then
  cat >&2 <<'MSG'
style に none は使えない。対照の腕も設定文の名前を明示すること。
--settings を省くと live の outputStyle を受け継ぐので、両腕が同じ設定文になり
対比較が成立しない（#348 R-4b はこれで無効になった）。
本文の無い空の設定文を ~/.claude/output-styles/ に置いて、その名前を渡すこと。
雛形: projects/orchestration-engine/scripts/register-metrics/fixtures/oe348-empty.md
MSG
  exit 2
fi
args=(-p --model opus --output-format json --resume "$sid" --fork-session
      --settings "{\"outputStyle\":\"${style}\"}")
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
# 成否は応答ファイルの有無では見えない。上限で落ちた run も 55 文字程度の
# 正常な JSON として存在する。is_error と rc を読み、manifest の末尾に残す。
is_error="$(python3 -c "
import json,io
try:
    d=json.load(io.open('$outdir/${tag}.json',encoding='utf-8'))
    print('1' if d.get('is_error') else '0')
except Exception: print('1')
")"
chars="$(python3 -c "import io;print(len(io.open('$outdir/${tag}.txt',encoding='utf-8').read()))")"
if [[ "$rc" -ne 0 || "$is_error" == "1" ]]; then status=failed; else status=ok; fi
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$tag" "$sess" "$style" "$sid" "$(cat "$outdir/${tag}.sid" 2>/dev/null)" "$started" "$status" "$rc" "$is_error" >> "$outdir/fork-manifest.tsv"
echo "[fork] $tag status=$status rc=$rc is_error=$is_error newsid=$(cat "$outdir/${tag}.sid" 2>/dev/null) chars=$chars"
[[ "$status" == "ok" ]] || exit 1

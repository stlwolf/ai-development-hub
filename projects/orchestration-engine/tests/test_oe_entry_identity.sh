#!/usr/bin/env bash
set -uo pipefail

# test_oe_entry_identity.sh — 入口 bin/oe 越しに、oe-recover と oe-handoff の本人確認が通ることを見る（#605 の T-9）
#
# 本人確認を持つ既存の検査3本を、OE_TEST_VIA_ENTRY=1 で回し直す。各検査は tests/fixtures/via-entry.sh の口で、
# verb を「入口を exec で呼ぶだけの小さなスクリプト」に差し替え、入口越しに呼んだ回数が0でないことを自分で確かめる。
#   test_oe_recover.sh     oe-recover: 本人と一致する（復帰が済む）・自分のペインや ps を確かめられない（何も書かずに止まる）
#   test_lease_handoff.sh  oe-handoff take: 本人と一致する（lease を作って進む）・前任のペインのプロセスが claude でない・
#                          CLAUDE_PID が無い（lease も board も動かさない）
#   test_handoff_take.sh   oe-handoff take / start の席の張替（入口越しの回では HOME も一時ディレクトリに向ける）
# 各検査は偽の ps・tmux と一時ディレクトリの置き場を使い、本物に届く経路が無いことを自分の最後で確かめている。
# ここでは、それぞれが緑で終わることと、本人確認の場面の行が PASS で出たことを見る（場面が黙って飛ばされて
# 緑になるのを見分けるため）。
#
# 既存の検査の流儀に合わせ、内側の検査は PATH の先頭の bash で回す。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0
ck()    { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
cksub() { case "$3" in *"$2"*) echo "  PASS: $1"; PASS=$((PASS+1)) ;; *) echo "  FAIL: $1 (missing=[$2])"; FAIL=$((FAIL+1)) ;; esac; }

run_via_entry() {  # run_via_entry <検査のファイル名> — 出力を OUT に、終了コードを RC に入れる
  RC=0
  OUT="$(OE_TEST_VIA_ENTRY=1 bash "$SCRIPT_DIR/$1" 2>&1 < /dev/null)" || RC=$?
}

echo "[T-9] oe-recover（test_oe_recover.sh を入口越しに）"
run_via_entry test_oe_recover.sh
ck    "緑で終わる" "0" "$RC"
cksub "入口越しに呼んだ" "PASS: verb を入口越しに呼んだ回数が0でない" "$OUT"
cksub "本人と一致する: binding が自分になる" "PASS: binding は自分（201）" "$OUT"
cksub "本人と一致する: board が自分を指す" "PASS: board は自分を指す" "$OUT"
cksub "自分のペインを確かめられない: 何も書かずに止まる" "PASS: 自分のペインを確かめられなければ何も書かずに止まる" "$OUT"
cksub "問い合わせに失敗する（ps）: 何も書かずに止まる" "PASS: ps が失敗したとき: 何も書かず止まる" "$OUT"
cksub "偽の ps と tmux を通った" "PASS: 偽の ps と tmux が呼ばれた" "$OUT"

echo "[T-9] oe-handoff take（test_lease_handoff.sh を入口越しに）"
run_via_entry test_lease_handoff.sh
ck    "緑で終わる" "0" "$RC"
cksub "入口越しに呼んだ" "PASS: verb を入口越しに呼んだ回数が0でない" "$OUT"
cksub "本人と一致する: 統括の lease ができる" "PASS: 統括の lease ができた" "$OUT"
cksub "CLAUDE_PID が無い: lease を作らない" "PASS: (1) lease を作らない" "$OUT"
cksub "前任が claude でない: 止まる" "PASS: (2) 前任のペインのプロセスが claude でなければ 1" "$OUT"
cksub "前任が claude でない: board を変えない" "PASS: (2) board を変えない" "$OUT"

echo "[T-9] oe-handoff take / start（test_handoff_take.sh を入口越しに・HOME も隔離）"
run_via_entry test_handoff_take.sh
ck    "緑で終わる" "0" "$RC"
cksub "入口越しに呼んだ" "PASS: verb を入口越しに呼んだ回数が0でない" "$OUT"

echo ""
echo "RESULT: pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]

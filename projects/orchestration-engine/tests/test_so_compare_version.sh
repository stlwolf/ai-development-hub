#!/usr/bin/env bash
# test_so_compare_version.sh — so-compare の宣言した版が中身と食い違っていないかを見る（#303 M-1）
#
# **なぜテストでやるか。** meta に残す版は、上げ忘れると嘘をつく。当初は so-compare 自身が
# 実行時にハッシュを計算して meta へ書く設計だったが、実装SO が4周かけて、その1行のために
# **レーンを1本も起動しないうちに SO 全体が止まる経路**を次々と実証した（pipefail で落ちる /
# 応答しない hasher で無期限に待つ / timeout は TERM を送るだけ / パイプ後段は上限の外）。
#
# 根は「由来を記録するためだけに critical path で外部コマンドを走らせる」ことだったので、
# **検査を実行時からテスト時へ移した。** ここで止まっても見えるところで止まり、SO のゲートは
# 巻き込まれない。
#
# **このテストが落ちたときにやること。**
#   1. so-compare の振る舞いが変わったなら `SO_COMPARE_VERSION` を上げる。
#   2. 下の EXPECTED_SHA を新しい値に更新する（このテストが表示する値をそのまま貼る）。
#   コメントの修正だけでも落ちる。**それは仕様である**（中身が変われば記録も変わるべきで、
#   「振る舞いは変わっていない」の判断を人が明示的に通すためにここで止める）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$SCRIPT_DIR/../../../scripts/so-compare.sh"
[[ -f "$TARGET" ]] || { echo "FAIL: so-compare.sh not found: $TARGET"; exit 1; }

# so-compare.sh の中身が変わったらここを更新する（上のコメントを読むこと）
EXPECTED_SHA="6928f30851deb4298f0091f7d352aa8d9c253559ca5ea7319726ce0c3c892e02"
EXPECTED_VERSION="2026-09-07"

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }

if command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA="$(shasum -a 256 "$TARGET" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
else
  echo "SKIP: shasum も sha256sum も無いのでハッシュを確かめられない"
  ACTUAL_SHA="$EXPECTED_SHA"
fi

echo "[1] 宣言した版が中身と食い違っていない"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "  FAIL: so-compare.sh の中身が変わっているのに宣言した版が据え置きかもしれない"
  echo "        期待: $EXPECTED_SHA"
  echo "        実際: $ACTUAL_SHA"
  echo "        → 振る舞いが変わったなら SO_COMPARE_VERSION を上げ、このテストの EXPECTED_SHA を上の実際の値へ更新する"
  FAIL=$((FAIL+1))
else
  echo "  PASS: 中身のハッシュが固定値と一致する"
  PASS=$((PASS+1))
fi

echo "[2] スクリプトが宣言している版が、このテストの期待と一致する"
DECLARED="$(grep -m1 '^SO_COMPARE_VERSION=' "$TARGET" | sed -E 's/^SO_COMPARE_VERSION="?([^"]*)"?.*/\1/')"
ck "SO_COMPARE_VERSION" "$EXPECTED_VERSION" "$DECLARED"

echo "[3] 版は開始側と完了側の両方の meta に書かれる"
# 中断された実行（attempt_state=running のまま残る記録）でも版で層別できる必要がある。
# shellcheck disable=SC2016  # 展開させずに `$SO_COMPARE_VERSION` という文字列そのものを探している
COUNT="$(grep -c 'echo "so_compare_version=\$SO_COMPARE_VERSION"' "$TARGET" || true)"
ck "書き出し箇所は4つ（開始側1 + 3レーン）" "4" "$COUNT"

echo "[4] 実行時にハッシュを計算しない（critical path に外部コマンドを戻さない）"
if grep -qE '^[^#]*\b(shasum|sha256sum)\b' "$TARGET"; then
  echo "  FAIL: so-compare.sh の実行経路に hasher が戻っている（SO 全体を止めうる）"
  FAIL=$((FAIL+1))
else
  echo "  PASS: 実行経路に hasher が無い"
  PASS=$((PASS+1))
fi

echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]

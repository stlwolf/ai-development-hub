#!/usr/bin/env bash
# seat.sh — board（declared 層）の「現統括」の席を読む・張り替える・検算する（#390 PR-2）
#
# 席の宣言は board の `現統括:` 行にある。**読み取りの規則は oe-vitals の実装が正本**で、
# ここはそれを関数に切り出したものである（挙動を変えない）。復帰側（#355）からも使えるように
# lib に置く。
#
# 提供する関数:
#   oe_seat_resolve <board>                     — 宣言された現統括の pane（無ければ空）
#   oe_seat_rewrite <board> <new> <gen> <date> [<old>] — 席を <new> へ張り替える
#   oe_seat_verify  <board> <expect>            — 張替後に同じ規則で読み直して一致を見る
#
# **この lib は board の系譜の散文を書き換えない。** 触るのは席の pane と鮮度の日付だけで、
# 系譜（誰がいつ何を回して退いたか）は人が書くものとして残す。機械が散文を畳むと、
# 復元できない形で情報が消える。
#
# シェルオプションに正しさを依存させない（`pipefail` の有無で結果が変わる書き方をしない）。

# 宣言された現統括の pane を返す。**規則は oe-vitals と同じ**:
#   (1) `現統括:`（colon 必須）を含む最初の行を取る
#       colon を必須にするのは、見出しの併記（`## in-flight（現統括 %144 の担当）`）に
#       含まれる stale な pane を誤って拾わないためである。
#   (2) その行の**最後の** `現統括` より後ろを見る（greedy）
#   (3) そこに現れる最初の `%NNN` を返す
# board 不在 / marker 不在 / pane 不在は空を返す（無い物を捏造しない）。
oe_seat_resolve() {
  local bf="${1:-}" line
  if [ -z "$bf" ] || [ ! -r "$bf" ]; then printf ''; return 0; fi
  line="$(grep -m1 -- '現統括:' "$bf" 2>/dev/null)" || line=""
  [ -n "$line" ] || { printf ''; return 0; }
  printf '%s' "${line##*現統括}" | grep -oE '%[0-9]+' | head -1 || true
}

# 席を <new> へ張り替える。
#   oe_seat_rewrite <board> <new_pane> <generation> <date> [<old_pane>]
#
# 書き換えるのは2つだけである。
#   - 宣言行の「最後の `現統括` より後ろに現れる最初の `%NNN`」を <new_pane> にする
#   - 同じ行の `鮮度: YYYY-MM-DD` を <date> にする（在れば）
# そのうえで、<old_pane> が渡されていれば **新しい pane の直後に**「退任申告済み・停止待ち」の
# 註を挿す。**直後に置くのが肝である。** 読み取りの規則は「最後の marker より後ろの最初の
# `%NNN`」なので、前任の pane が後継より先に来ると席が前任へ戻る（DJ-8）。
#
# rc: 0 書き換えた / 1 既に <new_pane> を指していて何もしなかった / 2 書き換えられない
oe_seat_rewrite() {
  local bf="${1:-}" new="${2:-}" gen="${3:-}" date="${4:-}" old="${5:-}"
  if [ -z "$bf" ] || [ ! -r "$bf" ] || [ ! -w "$bf" ]; then return 2; fi
  case "$new" in %[0-9]*) ;; *) return 2 ;; esac
  local ln line head tail_part cur
  ln="$(grep -n -m1 -- '現統括:' "$bf" 2>/dev/null | cut -d: -f1)" || ln=""
  [ -n "$ln" ] || return 2
  line="$(sed -n "${ln}p" "$bf")" || return 2
  head="${line%現統括*}現統括"
  tail_part="${line##*現統括}"
  cur="$(printf '%s' "$tail_part" | grep -oE '%[0-9]+' | head -1)" || cur=""
  [ -n "$cur" ] || return 2
  [ "$cur" != "$new" ] || return 1

  local note="" new_tail
  if [ -n "$old" ]; then
    note="（統括${gen}代目・${date} 着任。前任 \`${old}\` は退任申告済み・停止待ち）"
  elif [ -n "$gen" ]; then
    note="（統括${gen}代目・${date} 着任）"
  fi
  # 最初の1件だけ差し替える。sed の置換は行内で最初の一致に当たる。
  new_tail="$(printf '%s' "$tail_part" | sed -E "s/%[0-9]+/${new}/")" || return 2
  if [ -n "$note" ]; then
    new_tail="$(printf '%s' "$new_tail" | sed -E "s/(${new}\`?)/\\1${note}/")" || return 2
  fi
  local new_line="${head}${new_tail}"
  if [ -n "$date" ]; then
    new_line="$(printf '%s' "$new_line" | sed -E "s/鮮度: [0-9]{4}-[0-9]{2}-[0-9]{2}/鮮度: ${date}/")" || return 2
  fi

  local tmp="${bf}.seat.$$"
  # 元の権限を持ち込む（board は machine-local だが、mv で umask に緩ませない）。
  ( umask 077; : >"$tmp" ) || return 2
  if ! awk -v n="$ln" -v repl="$new_line" 'NR==n { print repl; next } { print }' "$bf" >"$tmp"; then
    rm -f "$tmp" 2>/dev/null
    return 2
  fi
  # 書き換えた行が1行だけで、行数が変わっていないことを被せる前に確かめる。
  if [ "$(wc -l <"$tmp" | tr -d ' ')" != "$(wc -l <"$bf" | tr -d ' ')" ]; then
    rm -f "$tmp" 2>/dev/null
    return 2
  fi
  chmod --reference="$bf" "$tmp" 2>/dev/null \
    || chmod "$(stat -f %Lp "$bf" 2>/dev/null || printf '644')" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$bf" || { rm -f "$tmp" 2>/dev/null; return 2; }
  return 0
}

# 張替後に同じ規則で読み直し、期待した pane が返ることを確かめる。
# **張り替えた本人が別の規則で確かめても意味がない**ので、読み取りは oe_seat_resolve を使う。
# rc: 0 一致 / 1 不一致（解決結果を stdout に出す）
oe_seat_verify() {
  local bf="${1:-}" expect="${2:-}" got
  got="$(oe_seat_resolve "$bf")"
  if [ "$got" = "$expect" ]; then return 0; fi
  printf '%s' "$got"
  return 1
}

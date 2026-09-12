#!/usr/bin/env bash
# seat.sh — board（declared 層）の「現統括」の席を読む・張り替える・検算する（#390 PR-2）
#
# 席の宣言は board の `現統括:` 行にある。**読み取りの規則は oe-vitals の実装が正本**で、
# ここはそれを関数に切り出したものである（挙動を変えない）。復帰側（#355）からも使えるように
# lib に置く。
#
# 提供する関数:
#   oe_seat_resolve <board>                     — 宣言された現統括の pane（無ければ空）
#   oe_seat_rewrite <board> <new> <gen> <date> [<old>] [<expect>] — 席を <new> へ張り替える
#       <expect> を省くと compare-and-swap が外れる（安全装置が黙って無くなるので、署名に出す）
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
#   oe_seat_rewrite <board> <new_pane> <generation> <date> [<old_pane>] [<expect_pane>]
#
# 書き換えるのは2つだけである。
#   - 宣言行の「最後の `現統括` より後ろに現れる最初の `%NNN`」を <new_pane> にする
#   - 同じ行の `鮮度: YYYY-MM-DD` を <date> にする（在れば）
# そのうえで、<old_pane> が渡されていれば **新しい pane の直後に**「退任申告済み・停止待ち」の
# 註を挿す。**直後に置くのが肝である。** 読み取りの規則は「最後の marker より後ろの最初の
# `%NNN`」なので、前任の pane が後継より先に来ると席が前任へ戻る（DJ-8）。
#
# <expect_pane> を渡すと、**書き換える直前に board が本当にそれを指しているか**を確かめる
# （compare-and-swap）。確かめないと、検査した相手と書き換える相手がずれる。
#   - 検査から書き換えの間に別の後継が席を取っていた場合、それを黙って上書きする
#   - `--predecessor` で古い pane を渡された場合、その pane の子と session を検査したうえで
#     現在の席を上書きする
#
# rc: 0 書き換えた / 1 既に <new_pane> を指していて何もしなかった / 2 書き換えられない
#     3 board が <expect_pane> を指していない（席が動いている）
#     4 いま別のプロセスが同じ board を書き換えている
#
# **確認と書き込みのあいだを他のプロセスに割り込ませない。** 確認だけでは足りない:
# 2つの後継が同時に走ると、両方が同じ前任を見て両方が書き、あとの `mv` が先の席を消す。
# 検算も順序次第で両方通り、交代イベントが2本残る。ロックは `mkdir` で取る（POSIX で原子的）。
oe_seat_rewrite() {
  local bf="${1:-}" lock rc i=0 owner
  [ -n "$bf" ] || return 2
  lock="${bf}.lock"
  while ! mkdir "$lock" 2>/dev/null; do
    # **置き去りのロックで board を永久に塞がない。** 途中で落ちた（電源・SIGKILL・
    # 端末ごと消えた）場合、ロックだけが残る。持ち主が生きているかを見て、居なければ引き取る。
    owner="$(cat "${lock}/pid" 2>/dev/null)" || owner=""
    # **引き取りは「退かす」のでなく「自分の名前で持ち去る」。**
    # そのまま rmdir すると、同じく置き去りと判断した別のプロセスが先に mkdir で取った
    # ロックを、こちらの rmdir が消しうる。rename なら成功するのは1つだけなので、
    # 持ち去れた側だけが片づける。
    if { [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; } \
       || { [ -z "$owner" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin "+${OE_SEAT_LOCK_STALE_MIN:-10}" 2>/dev/null)" ]; }; then
      if mv "$lock" "${lock}.stale.$$" 2>/dev/null; then
        rm -rf "${lock}.stale.$$" 2>/dev/null
      fi
      continue
    fi
    i=$((i + 1))
    if [ "$i" -ge "${OE_SEAT_LOCK_RETRY:-20}" ]; then return 4; fi
    sleep 0.1 2>/dev/null || sleep 1
  done
  printf '%s' "$$" > "${lock}/pid" 2>/dev/null || true
  # 割り込みで落ちてもロックを残さない。subshell の EXIT は正常終了も signal も拾うので、
  # **解放はここ1箇所だけにする。**
  #
  # 外側でもう一度 rmdir してはいけない。trap が外した**あと**、待っている別のプロセスが
  # mkdir で取りうる。そこへ外側の rmdir が届くと**他人のロックを消す**ので、2つのプロセスが
  # 同時に board を書き換える——ロックが防ぐために在る状態そのものになる。
  (
    trap 'rm -f "${lock}/pid" 2>/dev/null; rmdir "$lock" 2>/dev/null' EXIT HUP INT TERM
    _oe_seat_rewrite_locked "$@"
  )
  rc=$?
  return "$rc"
}

_oe_seat_rewrite_locked() {
  local bf="${1:-}" new="${2:-}" gen="${3:-}" date="${4:-}" old="${5:-}" expect="${6:-}"
  if [ -z "$bf" ] || [ ! -r "$bf" ] || [ ! -w "$bf" ]; then return 2; fi
  # new だけでなく old / expect も検証する。**この lib は復帰側（#355）からの再利用を前提に
  # 書いてある**ので、呼び出し側に同じガードがあることを当てにしない。old は註の文字列として
  # board へ入り、sed の置換テキストにもなる。
  case "$new" in %[0-9]*) ;; *) return 2 ;; esac
  if [ -n "$old" ];    then case "$old"    in %[0-9]*) ;; *) return 2 ;; esac; fi
  if [ -n "$expect" ]; then case "$expect" in %[0-9]*) ;; *) return 2 ;; esac; fi
  local ln line head tail_part cur
  ln="$(grep -n -m1 -- '現統括:' "$bf" 2>/dev/null | cut -d: -f1)" || ln=""
  [ -n "$ln" ] || return 2
  line="$(sed -n "${ln}p" "$bf")" || return 2
  head="${line%現統括*}現統括"
  tail_part="${line##*現統括}"
  cur="$(printf '%s' "$tail_part" | grep -oE '%[0-9]+' | head -1)" || cur=""
  [ -n "$cur" ] || return 2
  [ "$cur" != "$new" ] || return 1
  if [ -n "$expect" ] && [ "$cur" != "$expect" ]; then return 3; fi

  # 世代が分からないときに「統括代目」と書かない。世代不明のまま席を取る経路は許して
  # あるので、その経路が board の散文を壊さないようにする。
  local note="" who=""
  [ -z "$gen" ] || who="統括${gen}代目・"
  local new_tail
  if [ -n "$old" ]; then
    # **この行より後ろが過去の記録であることを、人に分かる形で書く。**
    # 註を新しい pane の直後に挿すので、そのすぐ後ろには前任の parenthetical がそのまま続く。
    # 印が無いと、同じ1行が2つの世代を続けて名乗り、**後継がいちばん最初に読む行が矛盾する。**
    # 前任の散文を書き換えずに済ませたいので、消さずに「ここから後ろは過去」と宣言する。
    note="（${who}${date} 着任。前任 \`${old}\` は退任申告済み・停止待ち。**これより後ろは前任までの記録である**）"
  elif [ -n "$who" ]; then
    note="（${who}${date} 着任）"
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
  # **awk の -v は値の中のバックスラッシュをエスケープとして再解釈する。**
  # board の自由記述に `\t` や `\\` が入っていると、席と日付以外の散文が静かに変質する。
  # 行数は変わらないので後続の検査も素通りする。ENVIRON 経由なら再解釈されない。
  if ! OE_SEAT_REPL="$new_line" awk -v n="$ln" 'NR==n { print ENVIRON["OE_SEAT_REPL"]; next } { print }' "$bf" >"$tmp"; then
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

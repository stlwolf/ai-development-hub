# shellcheck shell=bash
# fake-proc.sh — lib/tmux-pane-identity.sh が呼ぶ ps・tmux・kill の偽物を作る（テスト用・source して使う・#577 PR-4）
#
# 本物のプロセスとペインに届かないように、OE_TPI_PS・OE_TPI_TMUX・OE_TPI_KILL を偽物へ向ける。
# 偽物は次の2つの表だけを読む。
#   <dir>/ps.table  1行1プロセス: pid|lstart|comm|tty|tpgid（tty は ttys010 の形）
#   <dir>/panes     1行1ペイン:   %N /dev/ttysNNN
#
#   fake_proc_setup <dir>                         偽物を <dir>/bin に作って OE_TPI_* を向ける（表は空で始める）
#   fake_proc_add <pid> <lstart> <comm> <tty> <tpgid>
#   fake_proc_del <pid>                           プロセスが終わった形にする
#   fake_pane_add <pane> <tty>
#   FAKE_PROC_LOG=<file>                          在れば、偽の ps と tmux が呼ばれた引数を1行ずつ足す（呼ぶ順を見るため）
#
# フォアグラウンドのプロセスは、その tty の行のうち pid と tpgid が一致する行である（lib と同じ決まり）。

fake_proc_setup() {
  FAKE_PROC_DIR="${1:?}"
  mkdir -p "$FAKE_PROC_DIR/bin"
  : > "$FAKE_PROC_DIR/ps.table"; : > "$FAKE_PROC_DIR/panes"
  cat > "$FAKE_PROC_DIR/bin/ps" <<EOF
#!/usr/bin/env bash
T="$FAKE_PROC_DIR/ps.table"
[ -z "\${FAKE_PROC_LOG:-}" ] || printf 'tpi-ps %s\n' "\$*" >> "\$FAKE_PROC_LOG"
mode=""; pid=""; tty=""
while [ \$# -gt 0 ]; do
  case "\$1" in -o) mode="\$2"; shift 2 ;; -p) pid="\$2"; shift 2 ;; -t) tty="\$2"; shift 2 ;; *) shift ;; esac
done
if [ -n "\$tty" ]; then awk -F '|' -v t="\$tty" '\$4==t {print \$1" "\$5}' "\$T"; exit 0; fi
row="\$(awk -F '|' -v p="\$pid" '\$1==p' "\$T")"
[ -n "\$row" ] || exit 1
case "\$mode" in
  lstart=) printf '%s\n' "\$(printf '%s' "\$row" | cut -d'|' -f2)" ;;
  comm=)   printf '%s\n' "\$(printf '%s' "\$row" | cut -d'|' -f3)" ;;
esac
EOF
  cat > "$FAKE_PROC_DIR/bin/tmux" <<EOF
#!/usr/bin/env bash
[ -z "\${FAKE_PROC_LOG:-}" ] || printf 'tpi-tmux %s\n' "\$*" >> "\$FAKE_PROC_LOG"
case "\${1:-}" in
  list-panes) cat "$FAKE_PROC_DIR/panes"; exit 0 ;;
esac
exit 0
EOF
  cat > "$FAKE_PROC_DIR/bin/kill" <<EOF
#!/usr/bin/env bash
awk -F '|' -v p="\${2:-}" '\$1==p {f=1} END {exit f?0:1}' "$FAKE_PROC_DIR/ps.table" && exit 0
echo "kill: (\${2:-}) - No such process" >&2; exit 1
EOF
  chmod +x "$FAKE_PROC_DIR/bin/ps" "$FAKE_PROC_DIR/bin/tmux" "$FAKE_PROC_DIR/bin/kill"
  export OE_TPI_PS="$FAKE_PROC_DIR/bin/ps" OE_TPI_TMUX="$FAKE_PROC_DIR/bin/tmux" OE_TPI_KILL="$FAKE_PROC_DIR/bin/kill"
}

fake_proc_add() { printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" >> "$FAKE_PROC_DIR/ps.table"; }
fake_proc_del() { awk -F '|' -v p="$1" '$1!=p' "$FAKE_PROC_DIR/ps.table" > "$FAKE_PROC_DIR/ps.table.new" && mv "$FAKE_PROC_DIR/ps.table.new" "$FAKE_PROC_DIR/ps.table"; }
fake_pane_add() { printf '%s %s\n' "$1" "$2" >> "$FAKE_PROC_DIR/panes"; }

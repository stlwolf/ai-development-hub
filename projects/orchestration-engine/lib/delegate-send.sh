# shellcheck shell=bash
# delegate-send.sh — 親子委譲の 1 行安全送信プリミティブ（source 専用）
#
# tmux send-keys -l は改行をそのまま端末へ流すため、複数行を送ると Claude Code
# プロンプトが途中で送信される。本 lib は「1 行であること」を保証する単一の送信口。
#
# 既存 lib/spawn.sh の oe_spawn_send（wez・claude -p・非対話・envelope 経由）とは
# 別系統。こちらは対話セッションへ tmux send-keys で注入する transport。
# bin/oe-send / bin/oe-delegate が使う。将来 bin/oe-report も無改修で乗れるよう独立。
#
# 送信信頼化（Issue #144）: tmux send-keys → Claude Code TUI の取り込みは間欠的に
# 不安定で、自動 Enter が「吸収」され submit されないことがある（dogfood で確認）。
# transport（send-keys -l → sleep → Enter）は据え置き、送信後に「観測ベースの finalize」を
# 後段で走らせ、入力欄に payload が staged のまま残る吸収を after-the-fact で1回だけ回復する。
# finalize は Claude TUI の screen scrape ベースの best-effort・保守的判定で、transport の
# rc を一切変えない。設計経緯は docs/plans/2026-06-09-plan-oe-send-ingestion-rootfix.md。

# --- finalize 内部ヘルパー（source 専用・oe_ 接頭辞でネームスペース汚染を最小化） ---

# _oe_send_inputline <capture-text>
#   capture-pane の出力から入力欄行（最下部の `❯` 行）を1行返す。
#   送信済みメッセージの echo も `❯` で始まるが画面上方に出るため tail -1 が入力欄。
_oe_send_inputline() {
  # 入力欄プロンプトは行頭（先頭空白許容）の `❯`。行中に現れる `❯` を誤って拾わない（Copilot 指摘）。
  printf '%s\n' "$1" | grep '^[[:space:]]*❯' | tail -n 1
}

# _oe_send_has_content <input-line>
#   入力欄行にプレースホルダでない既存内容があれば 0。空 or `Try "..."`（候補表示）は 1。
#   plain capture では色が落ちるためプレースホルダ判定はヒューリスティック（best-effort）。
_oe_send_has_content() {
  local line="${1#*❯}"
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -n "$line" ]] || return 1
  case "$line" in
    'Try "'*) return 1 ;;  # 空入力時のプレースホルダ候補 → 内容なし扱い
  esac
  return 0
}

# _oe_send_finalize <pane> <payload> <base_proc> <base_staged>
#   自動送信（Enter 発火）後に呼ぶ。入力欄に payload が staged のまま残る Enter 吸収を
#   settle 窓終端まで観測し、なお staged なら Enter を1回だけ再送して回復する。
#   - settle 窓 = 中心安全パラメータ。遅延配送の Enter は窓内に着弾→submitted 判定で撃たない。
#   - 受け手状態に依存する best-effort。二重 submit を「確実に」防ぐとは主張しない（窓 < 遅延の
#     病的負荷下では残存）。常に 0 を返し transport の rc を変えない（誤再送→二重 submit 防止）。
_oe_send_finalize() {
  local pane="$1" payload="$2" base_proc="$3" base_staged="$4"
  local interval="${OE_SEND_FINALIZE_INTERVAL:-0.3}"
  local stable_need="${OE_SEND_FINALIZE_STABLE:-3}"
  local timeout="${OE_SEND_FINALIZE_TIMEOUT:-3}"
  local marker="${OE_SEND_PROC_MARKER:-esc to interrupt}"

  # payload 空（直呼び等）は literal 一致が全マッチになり誤発火するため撃たない。
  [[ -z "$payload" ]] && return 0
  # 送信前から入力欄に内容あり = 元 Enter が既存内容ごと submit し得る（transport レベルの
  # 既存条件で finalize では防げない）。finalize による「追加の」誤 submit を足さないため撃たない。
  [[ "$base_staged" == "1" ]] && return 0

  local max_iter
  max_iter="$(awk -v t="$timeout" -v i="$interval" 'BEGIN{ if(i+0<=0) i=0.3; n=int((t+0)/(i+0)); if(n<1)n=1; print n }')"

  local i cap input proc staged norm prev="" stable=0 saw_staged=0
  for ((i=0; i<max_iter; i++)); do
    cap="$(tmux capture-pane -p -t "$pane" 2>/dev/null)" || return 0  # capture 失敗 = unknown → 撃たない
    input="$(_oe_send_inputline "$cap")"
    if printf '%s\n' "$cap" | tail -n 3 | grep -qF -- "$marker"; then proc=1; else proc=0; fi
    if printf '%s' "$input" | grep -qF -- "$payload"; then staged=1; else staged=0; fi
    [[ "$staged" == "1" ]] && saw_staged=1

    # submit 確証 → 早期 exit（撃たない）: payload が staged 観測後に消えた / 処理が edge で開始
    [[ "$saw_staged" == "1" && "$staged" == "0" ]] && return 0
    [[ "$proc" == "1" && "$base_proc" == "0" ]] && return 0

    # quiescence（入力欄の末尾揮発を正規化して連続不変を数える）。staged_idle は窓終端まで待つ。
    norm="$(printf '%s' "$input" | sed 's/[[:space:]]*$//')"
    if [[ "$norm" == "$prev" ]]; then stable=$((stable+1)); else stable=1; fi
    prev="$norm"
    sleep "$interval"
  done

  # 窓終端の最終判定（再 capture）。終端 capture も stable 連鎖に含める＝終端で入力欄が
  # 変化していたら「終端安定」とみなさない（直前まで stable でも staged_idle 発火しない・Copilot 指摘）。
  cap="$(tmux capture-pane -p -t "$pane" 2>/dev/null)" || return 0
  input="$(_oe_send_inputline "$cap")"
  if printf '%s\n' "$cap" | tail -n 3 | grep -qF -- "$marker"; then proc=1; else proc=0; fi
  if printf '%s' "$input" | grep -qF -- "$payload"; then staged=1; else staged=0; fi
  [[ "$staged" == "1" ]] && saw_staged=1
  norm="$(printf '%s' "$input" | sed 's/[[:space:]]*$//')"
  if [[ "$norm" == "$prev" ]]; then stable=$((stable+1)); else stable=1; fi

  # staged_idle: 窓終端までなお staged・processing でない・baseline idle・終端安定 → 1回撃つ
  if [[ "$staged" == "1" && "$proc" == "0" && "$base_proc" == "0" && "$stable" -ge "$stable_need" ]]; then
    tmux send-keys -t "$pane" Enter
    return 0
  fi
  # stage_miss_suspect: 一度も staged 観測せず、入力欄が空のとき → warn のみ（観測補助・rc は変えない）。
  # 入力欄に内容が残る（折返し/省略で payload と完全一致しない）ケースは unknown 扱いで warn しない（Copilot 指摘）。
  if [[ "$saw_staged" == "0" && "$staged" == "0" ]] && ! _oe_send_has_content "$input"; then
    echo "oe_send_line: finalize: payload not observed staged or submitted on ${pane} (possible stage miss / fast submit)" >&2
    return 0
  fi
  # それ以外（base_proc=1・非安定・折返し等）= unknown → 撃たない
  return 0
}

# oe_send_line <pane_id> <text> [send_enter]
#   <text> に改行（LF / CR）が含まれていれば送信せず非 0 で失敗する（途中送信の根本封じ）。
#   対象ペインが存在しなければ非 0 で失敗する（死んだペインへの無言送信を防ぐ）。
#   send_enter（既定 "1"）が "0" のときは Enter を発火せずテキスト投入のみ（ステージ）。
#   成功時は tmux send-keys -l でリテラル注入し、既定では続けて Enter を発火する。
#   自動送信時は送信後に観測ベース finalize（Enter 吸収の after-the-fact 回復）を走らせる
#   （`OE_SEND_FINALIZE=0` で無効化可。finalize は rc を変えない best-effort）。
oe_send_line() {
  local pane="${1:-}"
  local text="${2:-}"
  local send_enter="${3:-1}"

  if [[ -z "$pane" ]]; then
    echo "oe_send_line: pane_id is required" >&2
    return 2
  fi
  # 改行（LF / CR）を含む payload は送信前に拒否する。今回の再設計の根本原因なので
  # 除去ではなく fail-fast にして、呼び出し側に 1 行化を強制する。
  if [[ "$text" == *$'\n'* || "$text" == *$'\r'* ]]; then
    echo "oe_send_line: refusing to send multi-line text (contains newline) to ${pane}" >&2
    return 2
  fi
  # tmux 不在は環境エラー（exit 2）として「ペイン無し (exit 1)」と区別する。
  # これが無いと list-panes の失敗が握りつぶされ「target pane not found」と誤表示する。
  if ! command -v tmux >/dev/null 2>&1; then
    echo "oe_send_line: tmux not found in PATH (required to send to a pane)" >&2
    return 2
  fi
  # 対象ペインの生存確認。list-panes 自体の失敗（サーバ未起動/接続不可）は
  # 「ペイン無し (exit 1)」と区別し、環境エラー (exit 2) で落とす（原因調査のため）。
  local live rc
  live="$(tmux list-panes -a -F '#{pane_id}' 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "oe_send_line: tmux list-panes failed (rc=${rc}): ${live}" >&2
    return 2
  fi
  if ! printf '%s\n' "$live" | grep -qxF "$pane"; then
    echo "oe_send_line: target pane not found: ${pane}" >&2
    return 1
  fi

  # finalize 用の送信前 baseline（自動送信 かつ finalize 有効時のみ）。
  # base_proc: 送信前から処理中か（子がビジー）／ base_staged: 入力欄に既存内容があるか。
  local fin_on=0 base_proc=0 base_staged=0
  if [[ "$send_enter" != "0" && "${OE_SEND_FINALIZE:-1}" != "0" ]]; then
    fin_on=1
    local bcap binput brc bmarker="${OE_SEND_PROC_MARKER:-esc to interrupt}"
    bcap="$(tmux capture-pane -p -t "$pane" 2>/dev/null)"; brc=$?
    if [[ "$brc" -ne 0 ]]; then
      # baseline が取れない＝送信前状態が不明 → finalize 無効化（idle と誤認して撃つのを防ぐ・Copilot 指摘）。
      fin_on=0
    else
      if printf '%s\n' "$bcap" | tail -n 3 | grep -qF -- "$bmarker"; then base_proc=1; fi
      binput="$(_oe_send_inputline "$bcap")"
      if _oe_send_has_content "$binput"; then base_staged=1; fi
    fi
  fi

  # -- で text のオプション誤解釈を防ぐ。-l はリテラル送信。Enter は別途発火（任意）。
  # transport は据え置き（#144: 機構未確定ゆえ送信経路は賭けない）。
  tmux send-keys -l -t "$pane" -- "$text"
  if [[ "$send_enter" != "0" ]]; then
    # リテラル送信の直後に Enter を撃つと、Claude Code TUI の paste 検知で Enter が
    # 「paste 内の改行」として吸収され submit されないことがある（dogfood で間欠確認）。
    # 小休止で paste 検知窓を閉じてから Enter を撃つ。OE_SEND_ENTER_DELAY で上書き可。
    sleep "${OE_SEND_ENTER_DELAY:-0.3}"
    tmux send-keys -t "$pane" Enter
    # 観測ベース finalize（best-effort・rc を変えない）。Enter 吸収の after-the-fact 回復。
    if [[ "$fin_on" == "1" ]]; then
      _oe_send_finalize "$pane" "$text" "$base_proc" "$base_staged" || true
    fi
  fi
}

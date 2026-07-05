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
#
# 活動ログ（#206）: 送信成功時に message_sent を best-effort emit する（永続 append-only・
# read 時 viewer 用）。event-bus.sh は delegate-registry.sh を必要に応じ自前で source する。
# 失敗しても oe_send_line の rc は変えない（emit は常に return 0）。
# shellcheck source=event-bus.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/event-bus.sh" 2>/dev/null || true

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
#     病的負荷下では残存）。原則 0 を返し transport の rc を変えない（誤再送→二重 submit 防止）。
#     例外: 未着候補（suspected miss / stage miss）のときだけ rc=3 を返す。呼び出し側が opt-in
#     （OE_SEND_SIGNAL_MISS=1）のときだけ非0へ昇格する（既定は rc 不変・#154）。
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

  # ceil(timeout/interval)。floor だと割り切れない時に総待機が TIMEOUT 未満になり安全窓を
  # 満たさない（例 timeout=1/interval=0.3 → 0.9s）。最低 TIMEOUT は待つ（Copilot 指摘）。
  local max_iter
  max_iter="$(awk -v t="$timeout" -v i="$interval" 'BEGIN{ if(i+0<=0) i=0.3; n=int((t+0)/(i+0)); if(n*(i+0) < (t+0)) n++; if(n<1)n=1; print n }')"

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
  # stage_miss_suspect: 一度も staged 観測せず、入力欄が空のとき → 未着候補（suspected miss）。warn を出し
  # rc=3（suspected-miss sentinel）を返す。呼び出し側が OE_SEND_SIGNAL_MISS=1 のときだけ非0へ昇格
  # する（既定は rc 不変・#154）。fast submit を未着と誤判定し得るため opt-in（二重 submit 回避）。
  # 入力欄に内容が残る（折返し/省略で payload と完全一致しない）ケースは unknown 扱いで warn しない（Copilot 指摘）。
  if [[ "$saw_staged" == "0" && "$staged" == "0" ]] && ! _oe_send_has_content "$input"; then
    # #224: 既定（signal-miss opt-out）では warn を出さない。suspected-miss は fast-submit の
    # 誤検知を多く含み既定では rc も変えない（no-op）ため、既定パスの warn は純ノイズになる。
    # genuine な失敗シグナルは opt-in（OE_SEND_SIGNAL_MISS=1）側で warn + rc=4（oe_send_line）
    # として残す。state machine（return 3）は不変＝echo だけを opt-in にゲートする。
    if [[ "${OE_SEND_SIGNAL_MISS:-0}" == "1" ]]; then
      echo "oe_send_line: finalize: payload not observed staged or submitted on ${pane} (possible stage miss / fast submit)" >&2
    fi
    return 3
  fi
  # それ以外（base_proc=1・非安定・折返し等）= unknown → 撃たない
  return 0
}

# oe_send_line <pane_id> <text> [send_enter]
#   <text> に改行（LF / CR）が含まれていれば送信せず非 0 で失敗する（途中送信の根本封じ）。
#   対象ペインが存在しなければ非 0 で失敗する（死んだペインへの無言送信を防ぐ）。
#   send_enter（既定 "1"）が "0" のときは Enter を発火せずテキスト投入のみ（ステージ）。
#   送信前に受け手が copy-mode なら解除する（copy-mode 吸収による不達の防止・#154）。
#   成功時は tmux send-keys -l でリテラル注入し、既定では続けて Enter を発火する。
#   自動送信時は送信後に観測ベース finalize（Enter 吸収の after-the-fact 回復）を走らせる
#   （`OE_SEND_FINALIZE=0` で無効化可。finalize は既定では rc を変えない best-effort）。
#   `OE_SEND_SIGNAL_MISS=1` のときのみ、finalize が未着候補（suspected miss / stage miss）を観測したら
#   rc=4 を返す（呼び出し側のフォールバック/リトライ用。既定 off は二重 submit 回避のため・#154）。
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

  # 受け手ペインが copy-mode（trackpad スクロール等で意図せず混入）だと、send-keys -l /
  # Enter がコピーモードのキーテーブルで吸収されプロンプトに届かない（#154 の間欠不達の主因）。
  # 送信前に #{pane_in_mode} を確認し、何らかの mode（主因は copy-mode）のときだけ解除する。
  # baseline capture より前に抜けることで baseline が settled な画面を反映する。
  # in_mode=0 で無条件に -X cancel を撃つと `not in a mode` が出るため、必ず条件付き（#154）。
  local in_mode
  in_mode="$(tmux display-message -p -t "$pane" '#{pane_in_mode}' 2>/dev/null)" || in_mode=""
  if [[ "$in_mode" == "1" ]]; then
    tmux send-keys -t "$pane" -X cancel 2>/dev/null || true
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
  # 呼び出し側が `oe_send_line ... || rc=$?` で受けると関数内 set -e が無効化されるため、
  # transport 失敗（送信中の pane 死など）は errexit に頼らず明示伝播する（silent 化防止・#154 SO 指摘）。
  if ! tmux send-keys -l -t "$pane" -- "$text"; then
    echo "oe_send_line: tmux send-keys (literal) failed on ${pane}" >&2
    return 2
  fi
  if [[ "$send_enter" != "0" ]]; then
    # リテラル送信の直後に Enter を撃つと、Claude Code TUI の paste 検知で Enter が
    # 「paste 内の改行」として吸収され submit されないことがある（dogfood で間欠確認）。
    # 小休止で paste 検知窓を閉じてから Enter を撃つ。OE_SEND_ENTER_DELAY で上書き可。
    sleep "${OE_SEND_ENTER_DELAY:-0.3}"
    if ! tmux send-keys -t "$pane" Enter; then
      echo "oe_send_line: tmux send-keys Enter failed on ${pane}" >&2
      return 2
    fi
    # 観測ベース finalize（best-effort）。Enter 吸収の after-the-fact 回復。
    # finalize は未着候補（suspected miss / stage miss）で rc=3 を返す。OE_SEND_SIGNAL_MISS=1 のときだけ
    # それを rc=4（suspected non-delivery / stage miss）へ昇格し、呼び出し側のフォールバック/
    # リトライを可能にする（既定は従来どおり rc を変えない・#154）。「confirmed」ではなく「suspected」
    # なのは fast-submit を未着と誤判定し得るため（SO 指摘）。
    local delivery_signal="none"
    if [[ "$fin_on" == "1" ]]; then
      local fin_rc=0
      _oe_send_finalize "$pane" "$text" "$base_proc" "$base_staged" || fin_rc=$?
      [[ "$fin_rc" == "3" ]] && delivery_signal="suspected_miss"
      # 活動ログ（#206）: 送信を message_sent として best-effort emit（rc は不変・常に成功扱い）。
      if declare -F oe_event_message_sent >/dev/null 2>&1; then
        oe_event_message_sent "${TMUX_PANE:-}" "$pane" "$text" "$delivery_signal" || true
      fi
      if [[ "$fin_rc" == "3" && "${OE_SEND_SIGNAL_MISS:-0}" == "1" ]]; then
        echo "oe_send_line: signaling suspected non-delivery (stage miss) on ${pane} (rc=4; OE_SEND_SIGNAL_MISS=1)" >&2
        return 4
      fi
    else
      # finalize 無効時は配送を観測しないため none（未着シグナル無し ＝ delivered の確証ではない）。
      if declare -F oe_event_message_sent >/dev/null 2>&1; then
        oe_event_message_sent "${TMUX_PANE:-}" "$pane" "$text" "$delivery_signal" || true
      fi
    fi
  fi
}

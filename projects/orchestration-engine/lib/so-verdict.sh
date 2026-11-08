# shellcheck shell=bash
# shellcheck disable=SC2034  # SO_VERDICT_* は source 元 verb が読む global-return 値（envelope.sh と同方式）
# so-verdict.sh — SO レーン verdict の抽出/集約/dissent 構築/exit code（source 専用）
#
# oe-refute（設計SO）と oe-review（実装SO）が共有する VERDICT ロジックを一元化する。
# 両 verb は so-compare のレーン別 stdout（<provider>-stdout.txt）から VERDICT/REASON を
# 抽出し、conservative に集約（1 レーンでも refuted → 全体 refuted。verdict を取れない
# レーンは survived 扱いにせず error とし survived 確定を阻む保守側）して dissent JSON を
# 組み、verdict で exit する。この4処理を共有し、verb 固有なのは集約 REASON の文言のみ
# （so_verdict_aggregate の phrase 引数で渡す）。
#
# 由来: #196。PR #195（#194）で oe-review が oe-refute から複製したロジック（#184 Fix 1 の
# VERDICT token 切り出し堅牢化を含む）を共有化し drift risk を解消する純リファクタ。
#
# bash 3.2/5.2 両対応: 連想配列・nameref（local -n）を使わず、文書化したグローバル変数で
# 戻り値を返す（lib/envelope.sh と同じ global-return 規約）。呼び出し側は set -euo pipefail
# 前提（各抽出は grep 不一致を `|| true` で吸収する）。

# #515: 有効なVERDICTが1件の場合だけ、その判定と続く最初のREASONを採る。
# 認識するtokenは従来のgrepと同じ。awk -vには行番号だけを渡すことで、
# 理由のバックスラッシュ等をawkに再解釈させない。placeholderは件数に含めず、
# 次のVERDICTラベル（未記入の例も含む）が出たら理由を読む範囲を閉じる。
_so_verdict_extract() {
  local f="$1" field="$2" numbers result
  numbers=""
  if [[ -s "$f" ]]; then
    numbers="$(grep -niE '^[[:space:]]*VERDICT:[[:space:]]*(refuted|survived)\b' "$f" | cut -d: -f1 | tr '\n' ' ' || true)"
  fi
  if [[ -s "$f" ]] && result="$(awk -v lines="$numbers" -v field="$field" '
      BEGIN {
        count = lines ~ /^ *$/ ? 0 : split(lines, positions, " ")
        target = positions[1] + 0
      }
      { lower = tolower($0) }
      NR == target {
        match(lower, /^[[:space:]]*verdict:[[:space:]]*/)
        verdict = substr(lower, RLENGTH + 1)
        sub(/[^a-z].*$/, "", verdict)
        in_result = 1
        next
      }
      in_result && lower ~ /^[[:space:]]*verdict:/ { in_result = 0 }
      in_result && !found && match(lower, /^[[:space:]]*reason:[[:space:]]*/) {
        reason = substr($0, RLENGTH + 1)
        found = 1
      }
      END {
        if (field == "verdict") print (count == 1 ? verdict : "unknown")
        else if (field == "reason" && count == 1) printf "%s", reason
        else if (field == "error") {
          if (count > 1) printf "VERDICT 行が複数あります（%d件）。判定不能のため通常SOには数えません", count
          else printf "VERDICT 行を取得できませんでした（レーン出力なし/形式不正）"
        }
      }
    ' "$f")"; then
    printf '%s' "$result"
  else
    case "$field" in
      verdict) printf 'unknown' ;;
      error) printf 'VERDICT 行を取得できませんでした（レーン出力なし/形式不正）' ;;
    esac
  fi
}

# stdout: refuted | survived | unknown。複数の有効な判定は同値でもunknown。
so_verdict_extract_verdict() { _so_verdict_extract "$1" verdict; }

# 一意な判定の後、次のVERDICTラベルまでにある最初のREASON（無ければ空）。
so_verdict_extract_reason() { _so_verdict_extract "$1" reason; }

# so_verdict_collect_lanes <output_dir> <providers_csv>
#   <output_dir>/<provider>-stdout.txt をレーンとして回し、以下のグローバルを populate する
#   （本関数が呼び出しごとに初期化する）。Bash 3.2 互換: 連想配列を使わず並行配列で扱う。
#     SO_VERDICT_LANE_NAMES[]    レーン名（= provider 名）
#     SO_VERDICT_LANE_VERDICTS[] refuted | survived | error
#     SO_VERDICT_LANE_NOTES[]    各レーンの REASON（error は固定文言）
#     SO_VERDICT_REFUTED_COUNT / SO_VERDICT_SURVIVED_COUNT / SO_VERDICT_ERROR_COUNT
#     SO_VERDICT_TOTAL_LANES
#   verdict を取れないレーンは error 扱いとし、survived にしない（保守側に倒す）。
so_verdict_collect_lanes() {
  local output_dir="$1" providers_csv="$2"
  local _providers prov stdout_file v note tool_status
  SO_VERDICT_LANE_NAMES=()
  SO_VERDICT_LANE_VERDICTS=()
  SO_VERDICT_LANE_NOTES=()
  SO_VERDICT_REFUTED_COUNT=0
  SO_VERDICT_SURVIVED_COUNT=0
  SO_VERDICT_ERROR_COUNT=0
  IFS=',' read -r -a _providers <<< "$providers_csv"
  for prov in ${_providers[@]+"${_providers[@]}"}; do
    stdout_file="${output_dir}/${prov}-stdout.txt"
    # #448: metaの劣化を本文のVERDICTで上書きしない。新しい観測キーだけを
    # 消費し、キーの無い旧metaの一般的な判定は変えない（#516は別件）。
    tool_status=""
    if [[ -f "${output_dir}/${prov}-meta.txt" ]]; then
      tool_status="$(sed -n 's/^tool_status=//p' "${output_dir}/${prov}-meta.txt")"
    fi
    if [[ -n "$tool_status" && "$tool_status" != "not_observed" ]]; then
      v="error"
    else
      v="$(so_verdict_extract_verdict "$stdout_file")"
    fi
    case "$v" in
      refuted)  note="$(so_verdict_extract_reason "$stdout_file")"; SO_VERDICT_REFUTED_COUNT=$((SO_VERDICT_REFUTED_COUNT + 1)) ;;
      survived) note="$(so_verdict_extract_reason "$stdout_file")"; SO_VERDICT_SURVIVED_COUNT=$((SO_VERDICT_SURVIVED_COUNT + 1)) ;;
      *)
        v="error"
        if [[ -n "$tool_status" && "$tool_status" != "not_observed" ]]; then
          note="道具の障害または観測不能のため通常SOには数えません"
        else
          note="$(_so_verdict_extract "$stdout_file" error)"
        fi
        SO_VERDICT_ERROR_COUNT=$((SO_VERDICT_ERROR_COUNT + 1)) ;;
    esac
    SO_VERDICT_LANE_NAMES+=("$prov")
    SO_VERDICT_LANE_VERDICTS+=("$v")
    SO_VERDICT_LANE_NOTES+=("$note")
  done
  SO_VERDICT_TOTAL_LANES=${#SO_VERDICT_LANE_NAMES[@]}
}

# so_verdict_aggregate <refuted_phrase> <survived_phrase>
#   so_verdict_collect_lanes 後の count グローバルから conservative 集約し、以下を設定する:
#     SO_VERDICT_VERDICT  refuted | survived
#     SO_VERDICT_REASON   集約理由（1 行）
#   exploration 既定: 1 レーンでも refuted → 全体 refuted。survived は全レーン survived のとき
#   のみ。error/unknown が 1 つでもあれば survived 確定不可 → conservative に refuted へ倒す。
#   verb 固有の文言だけ phrase 引数で渡す（refuted/survived 句。error 句は両 verb 共通で固定）。
so_verdict_aggregate() {
  local refuted_phrase="$1" survived_phrase="$2"
  if [[ "$SO_VERDICT_REFUTED_COUNT" -gt 0 ]]; then
    SO_VERDICT_VERDICT="refuted"
    SO_VERDICT_REASON="${SO_VERDICT_REFUTED_COUNT}/${SO_VERDICT_TOTAL_LANES} レーンが ${refuted_phrase}（conservative 集約: 1 レーン refuted で全体 refuted）"
  elif [[ "$SO_VERDICT_SURVIVED_COUNT" -eq "$SO_VERDICT_TOTAL_LANES" && "$SO_VERDICT_TOTAL_LANES" -gt 0 ]]; then
    SO_VERDICT_VERDICT="survived"
    SO_VERDICT_REASON="全 ${SO_VERDICT_TOTAL_LANES} レーンが${survived_phrase}"
  else
    SO_VERDICT_VERDICT="refuted"
    SO_VERDICT_REASON="verdict 未確定のレーンあり（refuted=${SO_VERDICT_REFUTED_COUNT} survived=${SO_VERDICT_SURVIVED_COUNT} error=${SO_VERDICT_ERROR_COUNT}）。survived を確定できないため conservative に refuted"
  fi
}

# so_verdict_dissent_json
#   so_verdict_collect_lanes 後の並行配列から dissent JSON 配列を stdout に出力する。
#   [{lane,verdict,note}, ...]。Bash 3.2 互換に並行配列を jq の --arg へ渡す。
so_verdict_dissent_json() {
  local args=() i=0 jq_prog
  while [[ "$i" -lt "$SO_VERDICT_TOTAL_LANES" ]]; do
    args+=(--arg "lane${i}" "${SO_VERDICT_LANE_NAMES[$i]}")
    args+=(--arg "verdict${i}" "${SO_VERDICT_LANE_VERDICTS[$i]}")
    args+=(--arg "note${i}" "${SO_VERDICT_LANE_NOTES[$i]}")
    i=$((i + 1))
  done
  jq_prog="["
  i=0
  while [[ "$i" -lt "$SO_VERDICT_TOTAL_LANES" ]]; do
    [[ "$i" -eq 0 ]] || jq_prog="${jq_prog},"
    jq_prog="${jq_prog}{lane:\$lane${i},verdict:\$verdict${i},note:\$note${i}}"
    i=$((i + 1))
  done
  jq_prog="${jq_prog}]"
  jq -cn ${args[@]+"${args[@]}"} "$jq_prog"
}

# so_verdict_exit
#   SO_VERDICT_VERDICT を見て exit する（advisory: refuted→3 / else→0。stdout JSON が正本）。
#   source 元スクリプトの最終行で呼ぶ（同一プロセスなので exit が伝播する）。
so_verdict_exit() {
  if [[ "$SO_VERDICT_VERDICT" == "refuted" ]]; then
    exit 3
  fi
  exit 0
}

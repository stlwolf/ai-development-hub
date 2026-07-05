# shellcheck shell=bash
# sanitize.sh — 会話到達面向けの capture/preview サニタイズ（source 専用・#224）
#
# 長寿命・ツール密な orchestration 統括セッションで、子ペインの壊れた出力（生の
# tool-call タグ列・box-drawing・制御文字）が会話コンテキストへ注入され、親が自己回帰で
# 模倣して tool-call malform が連鎖する経路を断つための共有チョークポイント。
# 「会話に載る文字列」を保存/投影する側が本 helper を通す（#224 は write-time 側＝
# event-bus.sh:oe_event_message_sent が preview 保存前に通す）。
#
# 実装形態は oe-tree:sanitize_out と同型: jq を主エンジンにし、jq 不在時のみ tr へ縮退する。
#
# 除去 vs neutralize（DJ-2）: タグ列/court は「削除」でなく「無害化」する。削除は文脈を
# 飛ばし隣接テキストを誤結合させ、誤爆（正当テキストの巻き込み）時の被害も大きい。
# 無害化はトークンを壊して tool-call として解釈されない形にしつつ文脈を残す。

# 会話へ載せる文字数の上限（codepoint）。0 で truncate 無効（明示的なエスケープハッチ）。
# 負数・非数値は typo とみなし安全側の既定 4000 へ coerce する（下の guard 参照）＝無効化はしない。
OE_SANITIZE_MAX_CP="${OE_SANITIZE_MAX_CP:-4000}"

# oe_sanitize_conversation <text>
#   会話到達面へ載せる前の無害化結果を stdout へ返す。段階（順序に意味あり）:
#     1. ANSI/CSI エスケープ列の除去（ESC 起点。cntrl 畳みより前＝ESC を潰す前に列ごと消す）
#     2. tool-call タグ列の neutralize: "<" 直後に空白を挿入し、tool-call トークンとして連続
#        しない形へ壊す（DJ-2）。対象は open/close 両方かつ短形・antml 名前空間形の両方:
#          <invoke / </invoke / <function_calls / </function_calls / <… / </antml…
#        issue 列挙の <invoke・<function_calls・</antml に加え、observed の短形 open と実構文の
#        名前空間形をまとめて捕捉する（実装SO cursor 指摘の under-capture を塞ぐ）。<div> 等は不介入。
#     3. 行頭孤立トークン court の neutralize: 行全体が court の行のみ [court] へ（DJ-3）。
#        mid-sentence / 複数語行 / 識別子（"The court ruled" 等）は不介入＝正当テキストの誤爆防止。
#        cntrl 畳みより前＝行境界(\n)が生きているうちに (?m) で判定する。
#     4. box-drawing（U+2500–257F）の除去。
#     5. 残る制御文字を空白へ（[[:cntrl:]]: ESC/US/CR/TAB/NL/DEL 等）。read 側の US 区切り
#        protocol 防御（oe-activity/oe-ack の同 gsub）とは層が別（こちらは write-time の無害化）。
#     6. codepoint 上限で truncate（超過時のみ末尾へ …）。
#   jq 不在時は tr で制御文字のみ空白化する best-effort（タグ/box/court/truncate は無処理）。
#   主消費者（event-bus.sh）は jq 必須経路なので、tr fallback は他所からの直呼び用の安全網。
oe_sanitize_conversation() {
  local max="${OE_SANITIZE_MAX_CP:-4000}"
  # OE_SANITIZE_MAX_CP が非数値/空だと `jq --argjson max` が失敗 → jq 全体が失敗 → tag/box/court
  # 無害化ごと tr fallback へ silent bypass し、raw preview が素通りする（実装SO=oe-review 検出）。
  # env typo で主防御が丸ごと無効化されるのを防ぐため、非数値は安全側の既定へ coerce する
  # （event-bus.sh の OE_EVENT_PREVIEW_MAX ガードと同方針・fail-open でなく fail-safe）。
  case "$max" in ''|*[!0-9]*) max=4000 ;; esac
  # 先頭ゼロ（例 05・007）は数字のみガードを通るが、RFC 8259 が JSON 数値の先頭ゼロを禁じるため
  # `jq --argjson max 05` は jq 版によっては parse 失敗し jq 経路ごと tr fallback へ縮退＝主防御が
  # bypass されうる（Copilot 指摘）。10 進正規化して jq 版に依らず確実に数値を渡す（fail-safe 貫徹）。
  max=$((10#$max))
  if command -v jq >/dev/null 2>&1; then
    if printf '%s' "$1" | jq -Rrs --argjson max "$max" '
        gsub("\\x1b\\[[0-9;?]*[ -/]*[@-~]"; "")
        | gsub("<(?=antml:|/antml|/?invoke|/?function_calls)"; "< ")
        | gsub("(?m)^[ \t]*court[ \t]*$"; "[court]")
        | gsub("[\\x{2500}-\\x{257f}]"; "")
        | gsub("[[:cntrl:]]"; " ")
        | if ($max > 0 and (length > $max)) then (.[0:$max] + "…") else . end
      ' 2>/dev/null; then
      return 0
    fi
    # jq 実行失敗（想定外入力等）は tr fallback へ落ちる。
  fi
  printf '%s' "$1" | LC_ALL=C tr '\000-\037\177' ' '
}

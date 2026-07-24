#!/usr/bin/env bash
set -euo pipefail

# knowledge-list.sh — negative knowledge store item の列挙（read-only・段3 突合・#273）
#
# 使い方:
#   knowledge-list                         # 既定: git HEAD tree から committed item を蒸留木横断で列挙
#   knowledge-list --json                  # JSON オブジェクト（メタ + items + malformed）
#   knowledge-list --strict                # skipped>0 なら exit 1（段3 手順は常に --strict）
#   knowledge-list --include-uncommitted   # disk（未 commit 含む）を filesystem find で列挙
#   knowledge-list <items-dir | item.md>   # 明示指定（テスト・単一木・disk 読み）
#   OE_KNOWLEDGE_REPO_ROOT=/path ...       # repo root（発見の基点）を上書き（テスト決定化）
#
# Exit codes:
#   0 = 列挙成功（skipped があっても既定は 0）
#   1 = --strict かつ skipped > 0（malformed / 非 ULID を検出。段3 の完全性信号）
#   2 = 環境エラー（git 非在 / HEAD 不成立 / jq・yq 未導入 / usage / repo root 不明）
#
# 位置づけ:
#   negative knowledge ループ 段3（突合）の read-only 列挙 verb。統括が brief を組む時に候補を
#   一望するためのもので、検証は別コマンド validate-knowledge が担う（本 verb は validator ではない）。
#   既定は「committed 状態 store」の意味に合わせ HEAD tree snapshot を列挙する（index/working-tree
#   でなく commit tree ＝ staged-but-uncommitted は含めない）。設計正本は
#   projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md、
#   確定版 plan は .oe/plan-273-nk-match-inject.md §9（gate 2 設計SO 後）。
#
# 発見と可搬性:
#   item の置き場は関係で解く（収穫元 episode と同じ蒸留木の knowledge/items/ ＝ source.ref と同木）。
#   repo 固有パスは焼かず、repo root 下の knowledge/items/ 直下 ULID item を横断列挙する。列挙対象は
#   厳密 regex `(^|/)knowledge/items/[^/]+\.md$` かつ basename が ULID の .md のみ（items/ 直下・非再帰）。
#   これは validate-knowledge の directory mode（非再帰・items/ 直下）と対象集合を一致させるため。
#
# malformed の扱い（黙って落とさない）:
#   frontmatter が壊れた / 非 ULID 名の item は stdout に flagged row（status=MALFORMED・path・
#   ULID ファイル名から復元した id）で surface し skipped に数える。stderr のみに出さないのは、
#   stdout を消費するモデル統括に見落としを可視化するため（段3 の false-negative-zero 方針）。

JSON=0
STRICT=0
INCLUDE_UNCOMMITTED=0
VERBOSE=0
POSITIONAL=()

for arg in "$@"; do
  case "$arg" in
    --json) JSON=1 ;;
    --strict) STRICT=1 ;;
    --include-uncommitted) INCLUDE_UNCOMMITTED=1 ;;
    --verbose) VERBOSE=1 ;;
    -h|--help)
      sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Usage: $0 [--json] [--strict] [--include-uncommitted] [--verbose] [<items-dir | item.md> ...]" >&2
      exit 2
      ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

log() { if [[ "$VERBOSE" -eq 1 ]]; then echo "[knowledge-list] $*" >&2; fi; }

for dep in jq yq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: $dep is not installed" >&2
    exit 2
  fi
done

ULID_RE='^[0-9A-HJKMNP-TV-Z]{26}$'                  # 26字・Crockford Base32（§5 準拠）
ITEM_PATH_RE='(^|/)knowledge/items/[^/]+\.md$'      # items/ 直下の .md（非再帰・厳密）

# --- repo root（発見の基点）---
REPO_ROOT="${OE_KNOWLEDGE_REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || true)"
fi
# 末尾スラッシュを剥がす。残すと "${abs#"$REPO_ROOT"/}" の prefix 除去が失敗し item_ref が絶対パスに
# なって漏れる（repo 相対パス契約・可搬性を破る・実装SO 指摘）。
REPO_ROOT="${REPO_ROOT%/}"

# 発見モードの決定と source ラベル
MODE=""
if [[ "${#POSITIONAL[@]}" -gt 0 ]]; then
  MODE="explicit"
  SOURCE_LABEL="explicit-paths"
elif [[ "$INCLUDE_UNCOMMITTED" -eq 1 ]]; then
  MODE="disk"
  SOURCE_LABEL="worktree"
else
  MODE="git-head"
  SOURCE_LABEL="git-head"
fi

# 既定（git-head）は git repo と HEAD を必須にする（案A へ暗黙 fallback しない・§9 DJ-C）。
# HEAD は実行開始時に具体 SHA へ固定する（列挙と blob 読み出しで同一 snapshot を保証・
# 実行中に HEAD が動いても旧 tree のパスと新 tree の内容が混ざらない・実装SO 指摘）。
HEAD_SHA=""
if [[ "$MODE" == "git-head" ]]; then
  if [[ -z "$REPO_ROOT" ]]; then
    echo "ERROR: not inside a git repository (use --include-uncommitted or pass explicit paths)" >&2
    exit 2
  fi
  if ! HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD 2>/dev/null)"; then
    echo "ERROR: HEAD is not resolvable in $REPO_ROOT (no commits yet?)" >&2
    exit 2
  fi
fi
if [[ "$MODE" == "disk" && -z "$REPO_ROOT" ]]; then
  echo "ERROR: repo root unknown for --include-uncommitted (set OE_KNOWLEDGE_REPO_ROOT or run inside a git repo)" >&2
  exit 2
fi

# --- 出力アキュムレータ ---
ITEMS_JSON=()      # 正常 item の JSON オブジェクト
MALFORMED_JSON=()  # 崩れ item の JSON オブジェクト
LISTED=0
SKIPPED=0

# excerpt: 本文の先頭「内容行」を返す（見出しは skip・引用/箇条書き marker は剥がす・意味要約ではない）。
# 文字数上限で必ず切り詰める（空白の有無に依らず）。無制限だと巨大 1 行が jq の argv 上限を超え
# `Argument list too long` で exit code 契約を破る DoS になるため（実装SO 指摘）。UTF-8 ロケール前提で
# `${line:0:max}` は文字境界で切る（多バイト文字を割らない → jq の UTF-8 破損を避ける）。
# v0 の既知の限界（意図的 defer・実装SO 指摘）: `LC_ALL=C` 等の非 UTF-8 ロケールでは `${line:0:max}` が
# バイト境界で切り、切詰め時のみ末尾の 1 文字が jq で U+FFFD に置換されうる（crash や exit 契約違反は
# 起きない・excerpt は preview で正本は item 本体）。配備ロケールは UTF-8。
excerpt_of() {
  local body="$1" line max=200
  # 入力を最後まで読み切り（早期 exit しない）先頭の「内容行」を END で返す。早期 exit すると
  # 巨大 body で producer が SIGPIPE を受け pipefail を誤発火させるため（実装SO 指摘）。
  line="$(awk '
    found { next }
    { l=$0
      sub(/^[[:space:]]+/,"",l)
      if (l=="") next
      if (l ~ /^#{1,6}[[:space:]]/) next
      sub(/^>[[:space:]]?/,"",l)
      sub(/^[-*+][[:space:]]+/,"",l)
      sub(/^[0-9]+\.[[:space:]]+/,"",l)
      sub(/^[[:space:]]+/,"",l)
      if (l=="") next
      result=l; found=1 }
    END { print result }
  ' <<<"$body")"
  if [[ "${#line}" -gt "$max" ]]; then
    line="${line:0:max} …"
  fi
  printf '%s' "$line"
}

# process_item <item_ref> <content> — 1 件を解析し ITEMS/MALFORMED に積む。
process_item() {
  local item_ref="$1" content="$2"
  local bn id_from_name
  bn="${item_ref##*/}"
  id_from_name="${bn%.md}"

  # 非 ULID 名は items/ の型付き store 規約に反する → flagged（黙って落とさない）
  if [[ ! "$id_from_name" =~ $ULID_RE ]]; then
    MALFORMED_JSON+=("$(jq -n --arg ref "$item_ref" --arg reason "non-ULID filename in knowledge/items/" \
      '{item_ref:$ref, status:"MALFORMED", reason:$reason, id:null}')")
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  # frontmatter block を 1 パスで抽出 + delimiter 検査（1行目 '---' + 閉じ '---'）。入力を最後まで
  # 読み切る（早期 exit しない）ため、巨大 body でも producer が SIGPIPE で pipefail を誤発火させない
  # （実装SO 指摘）。閉じ '---' 欠落を「EOF まで全部 frontmatter」と誤解釈して valid 扱いする偽成功も
  # ここで防ぐ（validator と整合）。
  local fm json
  if ! fm="$(awk '
      NR==1 { if ($0!="---") bad=1; next }
      !closed && $0=="---" { closed=1; next }
      !closed { fm = fm $0 "\n" }
      END { if (bad || !closed) exit 1; printf "%s", fm }
    ' <<<"$content")"; then
    MALFORMED_JSON+=("$(jq -n --arg ref "$item_ref" --arg id "$id_from_name" --arg reason "frontmatter delimiter block not found (opening/closing '---')" \
      '{item_ref:$ref, status:"MALFORMED", reason:$reason, id:$id}')")
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  if [[ -z "${fm//[[:space:]]/}" ]]; then
    MALFORMED_JSON+=("$(jq -n --arg ref "$item_ref" --arg id "$id_from_name" --arg reason "missing or empty frontmatter" \
      '{item_ref:$ref, status:"MALFORMED", reason:$reason, id:$id}')")
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  if ! json="$(printf '%s\n' "$fm" | yq -p=yaml -o=json '.' 2>/dev/null)" \
     || [[ "$(jq -r 'type' <<<"$json" 2>/dev/null || true)" != "object" ]]; then
    MALFORMED_JSON+=("$(jq -n --arg ref "$item_ref" --arg id "$id_from_name" --arg reason "malformed YAML frontmatter" \
      '{item_ref:$ref, status:"MALFORMED", reason:$reason, id:$id}')")
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  local body excerpt
  body="$(printf '%s\n' "$content" | awk 'NR==1&&$0=="---"{f=1;next} f==1&&$0=="---"{f=2;next} f==2{print}')"
  excerpt="$(excerpt_of "$body")"

  # フィールド抽出（欠落は null・list はそのまま）。id は frontmatter 優先・無ければ filename。
  # frontmatter JSON は stdin（here-string）で渡す。argv（--argjson）で渡すと巨大 frontmatter
  # （例 2MB の prediction）で ARG_MAX を超え exit 126 になり exit 契約を破るため（実装SO 指摘）。
  ITEMS_JSON+=("$(jq \
    --arg ref "$item_ref" \
    --arg id_name "$id_from_name" \
    --arg excerpt "$excerpt" \
    '{
      id: ((.id // $id_name) | tostring),
      item_ref: $ref,
      status: (.status // null),
      landing: (.landing // null),
      date: (.date // null),
      trigger: (.trigger // null),
      prediction: (.prediction // null),
      exclusions: (if (.exclusions|type)=="array" then (.exclusions|map(tostring)) else [] end),
      excerpt: $excerpt,
      source_ref: (if ((.source)|type)=="object" then (.source.ref // null) else null end)
    }' <<<"$json")")
  LISTED=$((LISTED + 1))
}

# --- 候補 item path の収集とコンテンツ取得（モード別）---
# 発見結果は NUL 区切りで temp file に落とす。command substitution は NUL を保持できず、
# producer（ls-tree / find）の exit code も検査できないため、temp file 経由で producer 失敗を
# exit 2（環境エラー）として顕在化する（実装SO 指摘・列挙を黙って空にしない）。
TREE_FILE=""
trap 'if [[ -n "$TREE_FILE" ]]; then rm -f "$TREE_FILE"; fi' EXIT

case "$MODE" in
  git-head)
    log "mode=git-head root=$REPO_ROOT head=$HEAD_SHA"
    TREE_FILE="$(mktemp)" || { echo "ERROR: mktemp failed" >&2; exit 2; }
    if ! git -C "$REPO_ROOT" ls-tree -rz --name-only "$HEAD_SHA" >"$TREE_FILE"; then
      echo "ERROR: git ls-tree failed at $HEAD_SHA in $REPO_ROOT" >&2
      exit 2
    fi
    while IFS= read -r -d '' path; do
      [[ "$path" =~ $ITEM_PATH_RE ]] || continue
      # blob 読み出しの失敗（object 欠損/破損・partial clone・権限）は環境エラー = exit 2。
      # frontmatter が空でも valid な item（git show は exit0 + 空出力）とは区別する（|| true で握り潰さない）。
      if ! content="$(git -C "$REPO_ROOT" show "$HEAD_SHA:$path" 2>/dev/null)"; then
        echo "ERROR: failed to read blob at $HEAD_SHA:$path (missing/corrupt object? try 'git fetch')" >&2
        exit 2
      fi
      process_item "$path" "$content"
    done <"$TREE_FILE"
    ;;
  disk)
    log "mode=disk root=$REPO_ROOT"
    TREE_FILE="$(mktemp)" || { echo "ERROR: mktemp failed" >&2; exit 2; }
    if ! find "$REPO_ROOT" \
      \( -name .git -o -name node_modules -o -name .oe -o -name tmp \) -prune -o \
      -type f -path '*knowledge/items/*.md' -print0 >"$TREE_FILE"; then
      echo "ERROR: find failed under $REPO_ROOT" >&2
      exit 2
    fi
    while IFS= read -r -d '' abs; do
      rel="${abs#"$REPO_ROOT"/}"
      [[ "$rel" =~ $ITEM_PATH_RE ]] || continue
      if ! content="$(cat "$abs")"; then
        echo "ERROR: cannot read $abs" >&2
        exit 2
      fi
      process_item "$rel" "$content"
    done <"$TREE_FILE"
    ;;
  explicit)
    log "mode=explicit args=${#POSITIONAL[@]}"
    for target in "${POSITIONAL[@]}"; do
      if [[ -d "$target" ]]; then
        shopt -s nullglob
        for f in "$target"/*.md; do
          ref="$f"; [[ -n "$REPO_ROOT" ]] && ref="${f#"$REPO_ROOT"/}"
          if ! content="$(cat "$f")"; then echo "ERROR: cannot read $f" >&2; exit 2; fi
          process_item "$ref" "$content"
        done
        shopt -u nullglob
      elif [[ -f "$target" ]]; then
        ref="$target"; [[ -n "$REPO_ROOT" ]] && ref="${target#"$REPO_ROOT"/}"
        if ! content="$(cat "$target")"; then echo "ERROR: cannot read $target" >&2; exit 2; fi
        process_item "$ref" "$content"
      else
        echo "ERROR: file or directory not found: $target" >&2
        exit 2
      fi
    done
    ;;
esac

# --- 出力 ---
if [[ "$JSON" -eq 1 ]]; then
  items_arr="[]"; [[ "${#ITEMS_JSON[@]}" -gt 0 ]] && items_arr="$(printf '%s\n' "${ITEMS_JSON[@]}" | jq -s '.')"
  mal_arr="[]"; [[ "${#MALFORMED_JSON[@]}" -gt 0 ]] && mal_arr="$(printf '%s\n' "${MALFORMED_JSON[@]}" | jq -s '.')"
  # items / malformed 配列は stdin（printf は builtin ＝ ARG_MAX 非対象）で jq へ渡す。argv（--argjson）
  # で渡すと巨大 item を含む配列で `Argument list too long`（exit 126）になり exit 契約を破るため（実装SO 指摘）。
  # jq -s が 2 値を配列 . に slurp する（.[0]=items, .[1]=malformed）。小さいメタは --arg で渡す。
  printf '%s\n%s\n' "$items_arr" "$mal_arr" | jq -s \
    --arg source "$SOURCE_LABEL" \
    --arg head "$HEAD_SHA" \
    --argjson listed "$LISTED" \
    --argjson skipped "$SKIPPED" \
    '{schema_version:1, source:$source, head:(if $head=="" then null else $head end), listed:$listed, skipped:$skipped, items:.[0], malformed:.[1]}'
else
  if [[ "${#ITEMS_JSON[@]}" -gt 0 ]]; then
    for obj in "${ITEMS_JSON[@]}"; do
      printf '%s\n' "$obj" | jq -r '
        "- " + (.id|tostring),
        "    item:       " + (.item_ref|tostring),
        "    status:     " + ((.status // "-")|tostring) + "   landing: " + ((.landing // "-")|tostring) + "   date: " + ((.date // "-")|tostring),
        "    trigger:    " + ((.trigger // "-")|tostring),
        "    prediction: " + ((.prediction // "-")|tostring),
        (if ((.exclusions // [])|length) > 0 then "    exclusions: " + ((.exclusions|map(tostring))|join("; ")) else empty end),
        "    excerpt:    " + ((.excerpt // "-")|tostring),
        "    source:     " + ((.source_ref // "-")|tostring),
        ""'
    done
  fi
  if [[ "${#MALFORMED_JSON[@]}" -gt 0 ]]; then
    for obj in "${MALFORMED_JSON[@]}"; do
      printf '%s\n' "$obj" | jq -r '"! MALFORMED " + (.id // "?") + "  (" + .reason + ")  item: " + .item_ref'
    done
    echo ""
  fi
  if [[ -n "$HEAD_SHA" ]]; then
    echo "listed: $LISTED / skipped: $SKIPPED / source: $SOURCE_LABEL @ $HEAD_SHA"
  else
    echo "listed: $LISTED / skipped: $SKIPPED / source: $SOURCE_LABEL"
  fi
fi

# --- exit ---
if [[ "$STRICT" -eq 1 && "$SKIPPED" -gt 0 ]]; then
  exit 1
fi
exit 0

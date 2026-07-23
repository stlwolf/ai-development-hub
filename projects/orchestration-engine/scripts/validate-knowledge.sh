#!/usr/bin/env bash
set -euo pipefail

# validate-knowledge.sh — negative knowledge store item のスキーマ検証（advisory・#272 段2）
#
# 使用例:
#   ./scripts/validate-knowledge.sh docs/knowledge/items/<ULID>.md         # 単一 item
#   ./scripts/validate-knowledge.sh docs/knowledge/items                   # directory mode（直下 *.md 全件）
#   ./scripts/validate-knowledge.sh path/to/item.md --verbose
#   OE_KNOWLEDGE_REPO_ROOT=/path/to/repo ./scripts/validate-knowledge.sh item.md  # source.ref 存在確認の基点上書き（テスト決定化）
#
# Exit codes:
#   0 = valid（全 item が全 check を満たす）
#   1 = invalid（1件以上の schema 違反。frontmatter/本文が knowledge item スキーマに反する。
#       malformed YAML もここ＝item の不備であり環境障害ではない）
#   2 = 環境エラー（file/dir not found / jq・yq 未導入 / usage）
#
# 位置づけ:
#   #272 の negative knowledge ループ 段2（保存）の機械検証。設計正本は
#   projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md。
#   検証対象は knowledge item ファイルのみ（episode 本文は解析しない）。markdown + 型付き frontmatter を
#   検証する点で scripts/validate-board.sh と同型だが、frontmatter がネスト（source.ref）・配列
#   （observations/exclusions）・enum を持つため YAML パーサ（yq）で JSON 化してから jq で検査する。
#   スキーマの正本は canonical/orchestration-spec/document-format.md の knowledge サブ節。
#
# advisory（warn・非ブロッキング）:
#   #78 advisory-hook 前例・validate-board.sh に整合し、本 validator は何もブロックしない。問題は
#   WARN 行として stderr に出す。exit 1 は「flag された（commit 前に直せ）」を programmatic に伝える信号。
#   fail-fast はせず 1 回の実行で全 WARN を出す（どこが崩れているか一望できる）。
#
# yq/jq の用途:
#   frontmatter（YAML）→ JSON 変換に yq（mikefarah）を使い、フィールド検査は jq。date のカレンダー
#   妥当性チェックに jq strptime|mktime を使う（BSD/GNU date のパース差を避ける可搬な方法）。

VERBOSE=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    -*)
      echo "Usage: $0 <item.md | items-dir> [--verbose]" >&2
      exit 2
      ;;
    *)
      if [[ -z "$TARGET" ]]; then TARGET="$arg"; fi
      ;;
  esac
done

log() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[validate-knowledge] $*" >&2
  fi
}

TOTAL_WARN=0
warn() {
  echo "WARN [$1]: $2" >&2
  TOTAL_WARN=$((TOTAL_WARN + 1))
}

for dep in jq yq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: $dep is not installed" >&2
    exit 2
  fi
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <item.md | items-dir> [--verbose]" >&2
  exit 2
fi

# source.ref（repo-root 相対の committed path）の存在確認の基点 = item が属する repo の root。
# 既定は TARGET の位置から git toplevel を引く。in-repo 実行でも、~/bin へ配布された
# `validate-knowledge` コマンドとして別リポジトリで実行した場合でも、item の repo を正しく取れる
# （スクリプト位置から逆算すると symlink 配布時に誤る）。git 外なら空のままにし存在確認をスキップする。
# テストは OE_KNOWLEDGE_REPO_ROOT で上書きして決定化する。
REPO_ROOT="${OE_KNOWLEDGE_REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  _rr_base="$TARGET"
  [[ -f "$TARGET" ]] && _rr_base="$(dirname "$TARGET")"
  REPO_ROOT="$(git -C "$_rr_base" rev-parse --show-toplevel 2>/dev/null || true)"
fi

ULID_RE='^[0-9A-HJKMNP-TV-Z]{26}$'   # 26字・Crockford Base32（§5 準拠: charset+length のみ）
DATE_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

# validate_item <file> — 1 件の knowledge item を検査し WARN を積む。
validate_item() {
  local file="$1"
  local base
  base="$(basename "$file")"
  log "checking $file"

  # --- frontmatter block の存在（1行目 '---' + 閉じ '---'）---
  if ! { [[ "$(sed -n '1p' "$file")" == "---" ]] && sed -n '2,$p' "$file" | grep -qxF -- '---'; }; then
    warn "$file" "frontmatter block not found (1行目 '---' + 閉じ '---' が必要)"
    return
  fi

  local fm
  fm="$(awk 'NR==1 && $0=="---"{f=1; next} f==1 && $0=="---"{exit} f==1{print}' "$file")"
  if [[ -z "${fm//[[:space:]]/}" ]]; then
    warn "$file" "empty frontmatter block (--- のみは valid にしない)"
    return
  fi

  # --- YAML -> JSON（parse 失敗 = schema 違反 = exit 1）---
  local json
  if ! json="$(printf '%s\n' "$fm" | yq -p=yaml -o=json '.' 2>/dev/null)"; then
    warn "$file" "malformed YAML frontmatter (yq parse failed)"
    return
  fi
  if [[ "$(jq -r 'type' <<<"$json" 2>/dev/null || true)" != "object" ]]; then
    warn "$file" "frontmatter root is not a map"
    return
  fi

  # --- 必須キーの存在（null は欠落扱い）---
  local key
  for key in id type status date trigger prediction source landing observations; do
    if [[ "$(jq "has(\"$key\")" <<<"$json")" != "true" ]]; then
      warn "$file" "missing required key: $key"
    elif [[ "$(jq -r ".\"$key\" == null" <<<"$json")" == "true" ]]; then
      warn "$file" "required key is null: $key"
    fi
  done

  # --- type ---
  local tv
  tv="$(jq -r '.type // empty' <<<"$json")"
  if [[ "$tv" != "knowledge" ]]; then
    warn "$file" "type must be 'knowledge' (got: ${tv:-<none>})"
  fi

  # --- status enum ---
  local sv
  sv="$(jq -r '.status // empty' <<<"$json")"
  case "$sv" in
    active|disabled|superseded|retired) ;;
    *) warn "$file" "status not in enum (active|disabled|superseded|retired): ${sv:-<none>}" ;;
  esac

  # --- id (ULID) + ファイル名一致（DJ-E: basename == <id>.md）---
  local id
  id="$(jq -r '.id // empty' <<<"$json")"
  if [[ ! "$id" =~ $ULID_RE ]]; then
    warn "$file" "id is not a valid ULID (26-char Crockford Base32): ${id:-<none>}"
  fi
  if [[ -n "$id" && "$base" != "$id.md" ]]; then
    warn "$file" "filename must be <id>.md (id=$id, file=$base)"
  fi

  # --- date (YYYY-MM-DD + カレンダー妥当性・不変=収穫日) ---
  local dv
  dv="$(jq -r '.date // empty' <<<"$json")"
  if [[ ! "$dv" =~ $DATE_RE ]]; then
    warn "$file" "date must be YYYY-MM-DD: ${dv:-<none>}"
  elif ! jq -n --arg d "$dv" '$d | strptime("%Y-%m-%d") | mktime' >/dev/null 2>&1; then
    warn "$file" "date is not a parseable calendar date: $dv"
  fi

  # --- trigger / prediction: 非空 string ---
  for key in trigger prediction; do
    local v
    v="$(jq -r "if (.\"$key\"|type)==\"string\" then .\"$key\" else \"\" end" <<<"$json")"
    if [[ -z "${v//[[:space:]]/}" ]]; then
      warn "$file" "$key must be a non-empty string"
    fi
  done

  # --- source: map + ref（非空 string・揮発/絶対パス拒否・local path は存在確認）---
  local st
  st="$(jq -r '.source | type' <<<"$json" 2>/dev/null || true)"
  if [[ "$st" != "object" ]]; then
    warn "$file" "source must be a map with a 'ref' key"
  else
    local ref
    ref="$(jq -r 'if (.source.ref|type)=="string" then .source.ref else "" end' <<<"$json")"
    if [[ -z "${ref//[[:space:]]/}" ]]; then
      warn "$file" "source.ref must be a non-empty string"
    elif [[ "$ref" == *"://"* ]]; then
      : # URL は存在検査対象外（§13.4/§15 と同型）
    elif [[ "$ref" == /* ]]; then
      warn "$file" "source.ref must not be an absolute path: $ref"
    elif [[ "$ref" == .oe/* || "$ref" == tmp/* || "$ref" == */.oe/* || "$ref" == */tmp/* ]]; then
      warn "$file" "source.ref must not point into a volatile working layer (.oe/ or tmp/): $ref"
    elif [[ "$ref" == ".." || "$ref" == ../* || "$ref" == */../* || "$ref" == */.. ]]; then
      warn "$file" "source.ref must not contain '..' path segments (repo escape): $ref"
    elif [[ -z "$REPO_ROOT" ]]; then
      : # repo root 不明（git 外）→ local path の存在確認はスキップ（string チェックは実施済み）
    elif [[ ! -e "$REPO_ROOT/$ref" ]]; then
      warn "$file" "source.ref (repo-relative committed path) does not exist: $ref"
    fi
  fi

  # --- landing enum ---
  local lv
  lv="$(jq -r '.landing // empty' <<<"$json")"
  case "$lv" in
    nl|guard-candidate) ;;
    *) warn "$file" "landing not in enum (nl|guard-candidate): ${lv:-<none>}" ;;
  esac

  # --- observations: 空配列 [] 必須（v0 予約・中身は #274）---
  local ot
  ot="$(jq -r '.observations | type' <<<"$json" 2>/dev/null || true)"
  if [[ "$ot" != "array" ]]; then
    warn "$file" "observations must be an array"
  elif [[ "$(jq -r '.observations | length' <<<"$json")" != "0" ]]; then
    warn "$file" "observations must be empty [] in v0 (contents are #274 scope)"
  fi

  # --- exclusions（任意）: 存在時は list ---
  if [[ "$(jq 'has("exclusions")' <<<"$json")" == "true" ]]; then
    local et
    et="$(jq -r '.exclusions | type' <<<"$json" 2>/dev/null || true)"
    if [[ "$et" != "array" ]]; then
      warn "$file" "exclusions, if present, must be an array (list of strings)"
    elif [[ "$(jq -r '[.exclusions[] | type] | all(. == "string")' <<<"$json")" != "true" ]]; then
      warn "$file" "exclusions elements must all be strings"
    fi
  fi

  # --- 本文 prose: 空白トリム後に可視文字 >=1 ---
  local body
  body="$(awk 'NR==1 && $0=="---"{f=1; next} f==1 && $0=="---"{f=2; next} f==2{print}' "$file")"
  if [[ -z "${body//[[:space:]]/}" ]]; then
    warn "$file" "body prose is empty (the lesson must be written after the frontmatter)"
  fi
}

# --- 入力の解決（単一ファイル / directory mode）---
if [[ -d "$TARGET" ]]; then
  # directory mode: 直下 *.md のうち ULID 名の item のみ検証（非再帰）。
  # README.md 等の非 item ファイルは store dir に同居しうるため skip する（item はファイル名 = ULID）。
  log "directory mode: $TARGET/*.md (non-recursive・ULID 名の item のみ検証)"
  shopt -s nullglob
  files=("$TARGET"/*.md)
  for f in "${files[@]}"; do
    _b="$(basename "$f")"; _b="${_b%.md}"
    if [[ ! "$_b" =~ $ULID_RE ]]; then
      log "skip non-item file (basename is not a ULID): $f"
      continue
    fi
    validate_item "$f"
  done
elif [[ -f "$TARGET" ]]; then
  validate_item "$TARGET"
else
  echo "ERROR: file or directory not found: $TARGET" >&2
  exit 2
fi

# --- 結果 ---
if [[ "$TOTAL_WARN" -eq 0 ]]; then
  echo "OK: $TARGET"
  exit 0
else
  echo "INVALID: $TARGET (${TOTAL_WARN} issue(s); advisory)" >&2
  exit 1
fi

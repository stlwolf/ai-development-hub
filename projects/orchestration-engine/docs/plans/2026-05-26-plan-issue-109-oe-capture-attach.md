---
id: "01KSFZFHXNZZXMV1AM06TXQAAR"
title: "Issue #109 Plan: 既存ペイン attach 入口 oe-capture（capture グルー）"
date: 2026-05-26
type: plan
status: ready
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/109"
    reason: "本 Plan の対象 Issue（attach グルー実装 + 自己検証）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/105"
    reason: "Phase 5 dogfood（本作業はその Slice A）"
  - type: integration_target
    ref: "https://github.com/stlwolf/ai-development-hub/issues/108"
    reason: "--workspace 外部出力は #108 側（相補関係、本 Plan スコープ外）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "wez pane capture viewport-only セマンティクスの一次資料（Step 4-4）"
tags: [orchestration, phase-5, issue-109, plan, oe-capture, attach, capture-glue]
---

# Issue #109 Plan: 既存ペイン attach 入口 oe-capture（capture グルー）

> 統括スレッドからのハンドオフ + so-compare（Codex + Claude）セカンドオピニオンを反映した実行計画。
> harness plan（承認済み）と同等。実装着手前に Issue #109 へ viewport スコープ契約をコメントする（option 2）。

## Context

orchestration-engine の `bin/oe` は spawn 専用フロー（新ペイン生成 → CLI 送信 → monitor → verify）で、
**既にある対話中のペインに attach して結果を読み取る**経路を持たない。#105 Phase 5 の dogfood として、
「対話セッションの末尾に人間/エージェントが終端マーカー（`@@OE_EXIT:0`）を出す → engine が読み取る」
最小経路を検証したい（[Issue #109](https://github.com/stlwolf/ai-development-hub/issues/109)）。

これは `lib/spawn.sh:97` が自動注入している `; printf '\n@@OE_EXIT:%d\n' $?` の**手動版**であり、既存設計と整合する。
既存 capture は pane_id + マーカーベースで「ペインがどう生まれたか」を問わないため、薄いグルーを足すだけで成立する。

**ゴール（#109 = Slice A のみ）**: 読み取り専用の薄い入口 `bin/oe-capture <pane_id>` を新設し、
`oe_capture_scan → oe_capture_classify → audit emit → oe_capture_write_kvs` を1ショットで実行する。
既存 capture/classify/KVS は**無改変**、mock suite（306 assertions）GREEN 維持。

**スコープ外**: 実 target case への適用（Slice B dogfood）は別途。`--workspace` 外部出力は #108 側。

## 開発フロー（spec-card パイプライン準拠）

- Discussion: Issue #109 本文で充足（新規 Discussion doc 不要）
- KickOff: ハンドオフ + 本 Plan で代替
- **Plan → 実装 → Episode** を `projects/orchestration-engine/docs/` に残す
- ブランチ: `branch-naming`（`feature/#109_oe_capture_attach`）/ コミット: `conventional-commits` / PR: `pr-conventions`
- **セカンドオピニオン（so-compare）を2箇所のゲートに**:
  - Plan 確定前（実施済み: `tmp/so-20260526-003703`）
  - 実装完了後・PR 前（**G6**、後述）

## 設計判断（確定済み）

| 項目 | 決定 | 根拠 |
|---|---|---|
| 入口名 | `bin/oe-capture <pane_id>` | Issue 提案。`bin/oe` と並列の薄い entry |
| session_id 生成 | `lib/session.sh` に抽出し `bin/oe` と共有 | DRY。`bin/oe` ローカル定義を移設（挙動不変、`test_e2e_smoke` で回帰カバー）。`lib/verify.sh` の重複解消は #109 スコープ外 |
| グルー配置 | 新規 `lib/attach.sh` の `oe_capture_attach()` | `capture.sh` を純粋（audit 非依存）なまま維持し新ロジックを隔離。`test_capture.sh` の source 前提を崩さない |
| audit 粒度 | `session_end`（`payload={source:"attach"}`）のみ emit | spawn 無しのため `session_start`/`state_change` は出さない。schema は1行単位検証で違反なし（SO 両者一致）。timeline 再構成上も正直な記録 |
| no-marker 時 | stderr 警告 + exit 1、KVS 書かない | 「まだ完了マーカー無し」を success/error と誤記録しない |
| VERIFY 単独 | EXIT 無しは「未完了」扱いで exit 1 | `monitor.sh` が EXIT のみで動く設計と整合（VERIFY は検証ゲート専用経路） |
| viewport-only（SO最重要） | **読める pane の条件を契約として明文化**（option 2）。`--lines`（既定 50）で末尾行数制御 | `wez pane capture --lines N` = viewport の `tail -n N`。**スクロールアウトしたマーカーは `--lines` 拡大でも回収不能**（verify.sh が tee log に逃げた制約と同一）。詳細は下記「viewport スコープ契約」 |
| pane_id 検証 | `^(0\|[1-9][0-9]*)$`（非負整数・先頭ゼロ不可） | `jq --argjson pane_id` は先頭ゼロ(`07`)で `Invalid numeric literal`（RFC 8259）。schema は `minimum:0`（SO 両者一致で強化） |
| --session-id 検証 | ① ULID 形式必須 `^[0-9A-HJKMNP-TV-Z]{26}$` ② 既存 state ファイルとの衝突は exit 2 で拒否 | 非 ULID は downstream `validate-session-state.sh` が落ちる。衝突時 `oe_capture_write_kvs` の `mv -f` が既存 verification map を黙って破壊（SO 両者指摘の新規欠落） |
| wez 不在 | 入口で `command -v wez` → exit 2 | 環境エラーを「未完了(exit1)」と区別（Claude Q7） |
| 入口の安全性 | spawn/monitor/cleanup/trap を source しない | 読み取り専用。ペインを kill しない（対話中ペインを壊さない） |
| PROJECT_DIR / mkdir | entry 冒頭で `PROJECT_DIR` export（constants.sh source 前）+ 書き込み前に `mkdir -p` | `set -u` 下で `constants.sh` の `${PROJECT_DIR}` ネスト展開が unbound だと abort（SO 両者指摘）。`bin/oe` と同初期化 |

### viewport スコープ契約（option 2 — Issue #109 にコメントで残す）

`oe-capture` が読めるのは対象 pane の **現在の viewport 末尾 N 行（既定 50）** のみ。成立条件:

- `@@OE_EXIT:{code}` が **末尾近傍に単独行**で存在する pane
- 想定: 「マーカー規約でコマンドを流し、**直前に完了**し、まだ追加出力でマーカーが流れていない pane」
  - **#109 self-verify**: マーカー送出 → 即読み取り = 必ず viewport 内 → 成立（制約に当たらない）
  - **dogfood (Slice B)**: 作業の終端で `@@OE_EXIT` を末尾単独行として出す運用。読み取りまでに大量出力を挟まない
- 非対応（incomplete = exit 1）: マーカーがスクロールアウト / 未出力 / 単独行でない
  - スクロールアウトは原理的に回収不能（`--lines` 拡大でも viewport 外は返らない）→ 回復策は「マーカーを末尾に再出力して再 capture」
- この契約を `usage` / `README` / Episode に明記し、Issue #109 にスコープコメントとして残す（S0.5）

## 実装ステップ（最小粒度・ゲート interleave）

### S0. ブランチ/worktree + Plan doc
- `wt switch --create feature/#109_oe_capture_attach`（worktrunk、master 最新から）
- 本 Plan doc を `docs/plans/2026-05-26-plan-issue-109-oe-capture-attach.md` に保存

### S0.5. Issue #109 に viewport スコープ契約コメント（option 2、着手前）
- 上記「viewport スコープ契約」を Issue #109 にコメント投稿し、attach が現実に読める pane の条件を明文化・合意化（Claude SO 最重要提言）

### S1. `lib/session.sh` 新設（session_id 生成の抽出）

```bash
# shellcheck shell=bash
# session.sh — セッション ID 生成（source 専用）

# oe_generate_session_id — 26 文字 ULID 風 ID を stdout に出力
# 先頭 14 = 数字（時刻部 YYYYMMDDHHMMSS）、残り 12 = Crockford base32（I/L/O/U 除外）
#
# Copilot #4 反映: tr の出力を head -c で早期 close すると tr に SIGPIPE が飛び、
# set -o pipefail 環境下で assignment が失敗する。固定バイト数を先に読んでから tr で
# filter する形に変更（パイプの早期 close を回避）。
oe_generate_session_id() {
  local ts raw rand
  ts="$(date -u +%Y%m%d%H%M%S)"
  raw="$(LC_ALL=C head -c 4096 /dev/urandom | LC_ALL=C tr -dc '0-9A-HJKMNP-TV-Z')"
  rand="${raw:0:12}"
  printf '%s%s\n' "$ts" "$rand"
}
```

### S2. `bin/oe` 改修（抽出に伴う最小変更・挙動不変）
- `oe_generate_session_id()` のローカル定義を削除（lib/session.sh に移設）
- source ブロックに `source "${LIB_DIR}/session.sh"` を追加（`constants.sh` の直後）
- **[gate] G1**: `bash tests/test_e2e_smoke.sh` GREEN（`bin/oe` 抽出の回帰確認）

### S3. `lib/attach.sh` 新設（グルー本体）

```bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# attach.sh — 既存（対話中）ペインに attach して capture→classify→audit/KVS（source 専用）
# 前提: constants.sh / capture.sh / audit.sh が source 済み（呼び出し側 entry が保証）

OE_ATTACH_STATE=""

# oe_capture_attach — pane を1回 scan し、EXIT マーカー検出時に classify→audit→KVS
# 引数: session_id pane_id [lines=50]
# 戻り値: 0=検出（OE_ATTACH_STATE 設定 + audit/KVS 書込済）, 1=未検出（書かない）
oe_capture_attach() {
  local session_id="$1"
  local pane_id="$2"
  local lines="${3:-50}"

  OE_ATTACH_STATE=""

  oe_capture_scan "$pane_id" "$lines"

  # EXIT マーカー未検出（VERIFY 単独 / マーカー無し含む）は未完了扱い
  if [[ "$OE_SCAN_MARKER_TYPE" != "EXIT" ]]; then
    return 1
  fi

  oe_capture_classify "$OE_SCAN_VALUE" "$OE_SCAN_BLOCKED"
  OE_ATTACH_STATE="$OE_CLASSIFY_STATE"

  local payload
  payload="$(jq -cn '{source:"attach"}')"
  oe_audit_emit "session_end" "$session_id" "$pane_id" "$OE_CLASSIFY_STATE" "$payload"
  oe_capture_write_kvs "$session_id" "$pane_id" "$OE_CLASSIFY_STATE"
  return 0
}
```

### S4. `bin/oe-capture` 新設（入口）

```bash
#!/usr/bin/env bash
set -euo pipefail

# oe-capture — 既存（対話中）ペインに attach して終端マーカーを読み取り、KVS/audit に記録
#
# usage: oe-capture <pane_id> [--session-id <id>] [--lines <N>]
#
# 読み取り専用: ペインの kill / cleanup は行わない（対話中ペインを壊さない）。
# spawn フローとは独立した最小入口（Issue #109 / Slice A）。

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="${PROJECT_DIR}/lib"
export PROJECT_DIR

# 必要な lib のみ source（spawn/monitor/verify/cleanup は不要）
# shellcheck source=../lib/constants.sh
source "${LIB_DIR}/constants.sh"
# shellcheck source=../lib/session.sh
source "${LIB_DIR}/session.sh"
# shellcheck source=../lib/capture.sh
source "${LIB_DIR}/capture.sh"
# shellcheck source=../lib/audit.sh
source "${LIB_DIR}/audit.sh"
# shellcheck source=../lib/attach.sh
source "${LIB_DIR}/attach.sh"

oe_capture_usage() {
  cat >&2 <<'USAGE'
usage: oe-capture <pane_id> [--session-id <id>] [--lines <N>]
  <pane_id>      WezTerm ペイン ID（整数、必須）
  --session-id   KVS/audit のセッション ID（省略時は自動生成）
  --lines        capture する末尾行数（既定 50。viewport-only 制約: マーカーは末尾単独行）
USAGE
}

oe_capture_cli() {
  local pane_id="" session_id="" lines=50 session_id_supplied=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session-id) session_id="${2:-}"; session_id_supplied=1; shift 2 ;;
      --lines)      lines="${2:-}"; shift 2 ;;
      -h|--help)    oe_capture_usage; return 0 ;;
      -*)           echo "oe-capture: unknown option: $1" >&2; oe_capture_usage; return 2 ;;
      *)
        if [[ -z "$pane_id" ]]; then
          pane_id="$1"; shift
        else
          echo "oe-capture: unexpected argument: $1" >&2; return 2
        fi
        ;;
    esac
  done

  # wez 不在は環境エラー（exit 2）として「未完了(exit1)」と区別
  if ! command -v wez >/dev/null 2>&1; then
    echo "oe-capture: 'wez' not found in PATH (required to capture pane output)" >&2; return 2
  fi

  if [[ -z "$pane_id" ]]; then
    echo "oe-capture: pane_id is required" >&2; oe_capture_usage; return 2
  fi
  # jq --argjson の数値リテラル制約（先頭ゼロ不可・RFC 8259）+ schema minimum:0
  if [[ ! "$pane_id" =~ ^(0|[1-9][0-9]*)$ ]]; then
    echo "oe-capture: pane_id must be a non-negative integer without leading zeros (got: '$pane_id')" >&2; return 2
  fi
  if [[ ! "$lines" =~ ^[1-9][0-9]*$ ]]; then
    echo "oe-capture: --lines must be a positive integer (got: '$lines')" >&2; return 2
  fi

  # user 指定 session_id は ULID 形式必須（downstream validate-session-state.sh 整合）
  if [[ "$session_id_supplied" -eq 1 && ! "$session_id" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
    echo "oe-capture: --session-id must be a 26-char ULID (Crockford base32, excl. I/L/O/U)" >&2; return 2
  fi

  mkdir -p "${OE_STATE_DIR}" "${OE_AUDIT_DIR}"

  session_id="${session_id:-$(oe_generate_session_id)}"

  # 衝突拒否: 既存 state があると oe_capture_write_kvs の mv -f が verification map を破壊するため拒否
  if [[ "$session_id_supplied" -eq 1 && -e "${OE_STATE_DIR}/${session_id}.state.json" ]]; then
    echo "oe-capture: state file already exists for session-id '${session_id}' (refusing to overwrite); use a fresh id" >&2
    return 2
  fi

  if oe_capture_attach "$session_id" "$pane_id" "$lines"; then
    printf 'session_id=%s pane_id=%s state=%s\n' "$session_id" "$pane_id" "$OE_ATTACH_STATE"
    printf 'kvs=%s\n'   "${OE_STATE_DIR}/${session_id}.state.json"
    printf 'audit=%s\n' "${OE_AUDIT_DIR}/${session_id}.jsonl"
    return 0
  else
    echo "oe-capture: no @@OE_EXIT marker in last ${lines} lines of pane ${pane_id} (not finished, or marker scrolled out of viewport)" >&2
    return 1
  fi
}

oe_capture_cli "$@"
```

### S5. `tests/test_attach.sh` 新設（mock hermetic、suite に加算）

`test_capture.sh` / `test_kvs.sh` のパターン踏襲（`OE_DATA_DIR` を temp に、`wez` を関数 mock）。検証ケース:

- `@@OE_EXIT:0` 末尾 → return 0 / `OE_ATTACH_STATE=success` / KVS `.state=success` / audit に `session_end` + `.payload.source=="attach"`
- `@@OE_BLOCKED` + `@@OE_EXIT:2` → `OE_ATTACH_STATE=blocked` / KVS `.blockers=["@@OE_BLOCKED"]`
- マーカー無し → return 1 / KVS ファイル未生成
- `@@OE_VERIFY:pass` 単独（EXIT 無し）→ return 1（未完了扱い）
- 入口バリデーション（`oe_capture_cli` を source して直接呼ぶ）: pane_id 先頭ゼロ `07`/非整数/未指定 → exit 2、`--session-id` 非 ULID/衝突 → exit 2、`--lines` 非正整数 → exit 2

- **[gate] G2**: `bash tests/test_attach.sh` GREEN
- **[gate] G3**: 全 mock suite 再実行 → 既存 **306 維持** + 新規分加算（`for f in ./tests/test_*.sh; do bash "$f"; done`）
- **[gate] G4**: `shellcheck bin/oe-capture bin/oe lib/session.sh lib/attach.sh tests/test_attach.sh` クリーン

### S6. `tests/e2e_real_agent/self_verify_attach.sh` 新設（実wez, local-only）+ 実機実行

使い捨てペインを split → 末尾に `@@OE_EXIT:0` を独立行で送出 → `bin/oe-capture` 実行 → `state=success` 確認 → pane kill。
`OE_DATA_DIR` を temp に向けてリポジトリ `state/`・`audit/` を汚さない。

- **[gate] G5**: `self_verify_attach.sh` を**この作業内で実機実行**し `state=success` + audit emit 確認（`wez` 在: `/Users/eddy/bin/wez`）

### S7. Episode + コミット分割
- `docs/episodes/2026-05-26-episode-issue-109-oe-capture-attach.md` を spec-card で作成（設計判断・self-verify 結果・viewport-only 対処を記録）
- コミット分割（conventional-commits、1コミット1論理変更）:
  1. `refactor(orchestration-engine): oe_generate_session_id を lib/session.sh に抽出`（S1+S2）
  2. `feat(orchestration-engine): 既存ペイン attach 入口 oe-capture を追加`（S3+S4+S5）
  3. `test(orchestration-engine): oe-capture の実wez self-verify スクリプト追加`（S6）
  4. `docs(orchestration-engine): #109 Plan/Episode を追加`（S0 doc + S7）

### S8. SO ゲート（実装 diff にセカンドオピニオン）→ PR
- **[gate] G6 (SO)**: 実装完了後・PR 前に、ブランチ diff に対し `so-compare` でセカンドオピニオンを取得し、実装の正当性・既存への回帰・規約逸脱・SO 反映漏れを検証。指摘は反映してから次へ（必要なら追コミット）
- PR は `pr-conventions`（Issue #109 連携、test plan = G1〜G6 の結果を本文に記載）

## 検証（end-to-end）

| ゲート | コマンド | 期待 |
|---|---|---|
| G1 | `bash tests/test_e2e_smoke.sh` | PASS（bin/oe 抽出の回帰なし） |
| G2 | `bash tests/test_attach.sh` | PASS（新規） |
| G3 | `for f in ./tests/test_*.sh; do bash "$f"; done` | 既存 306 維持 + 新規加算、FAIL=0 |
| G4 | `shellcheck bin/oe-capture bin/oe lib/session.sh lib/attach.sh tests/test_attach.sh` | 警告なし |
| G5 | `bash tests/e2e_real_agent/self_verify_attach.sh`（実wez） | `state=success`、KVS `.state==success`、audit に `session_end`/`source=="attach"` |
| G6 (SO) | `so-compare -w "$(pwd)" "<実装 diff の検証プロンプト>"` | 重大な未解決指摘なし（あれば反映後に再判定） |

## セカンドオピニオン（so-compare）

- **Plan 確定前**（実施済み）: `tmp/so-20260526-003703`（Codex + Claude、両者成功）。反映:
  - pane_id regex 強化 `^(0|[1-9][0-9]*)$`（先頭ゼロで jq 落ち）
  - `--session-id` 衝突拒否 + ULID 形式検証（既存 verification map 破壊防止 + downstream validator 整合）
  - wez 不在チェック / PROJECT_DIR・mkdir 必須前提の明記 / Copilot SIGPIPE コメント移植
  - viewport スコープ契約を明文化し Issue #109 にコメント（option 2）
- **実装完了後**（G6）: 実装 diff に対し再度 so-compare（上記参照）

## Open questions / リスク

- audit 粒度 `session_end` のみ: SO 両者「schema 違反なし」確認済み。`payload.source="attach"` で monitor 由来と区別（妥当と評価）。`state_change` 併発は任意 → 今回は出さない
- `bin/oe` 抽出はリスク低（挙動保存・G1 でカバー）。capture.sh/classify/KVS は一切触らない
- `lib/verify.sh` の session_id 生成は3個目の重複として残る → #109 スコープ外（明示）。寄せるなら別 Issue
- viewport-only: スクロールアウトしたマーカーは原理的に回収不能（capture.sh の `wez pane capture` viewport 経路を再利用、tee log 代替は持たない）→ スコープ契約で明文化。OSC 7/133 エスケープ未除去リスクは capture.sh 側（無改変方針のためスコープ外、認識のみ）

## 関連
- [Issue #109](https://github.com/stlwolf/ai-development-hub/issues/109)
- `lib/capture.sh`（scan/classify/KVS）/ `lib/spawn.sh:97`（marker emit 自動注入の手動版）/ `lib/audit.sh` / `lib/monitor.sh`
- Step 4-4 episode（viewport-only / `wez pane capture --lines` = tail）: `docs/episodes/2026-05-18-episode-step-4-4-implementation.md`
- wezterm-ai-mode ADR-004（`--lines = tail` 仕様）

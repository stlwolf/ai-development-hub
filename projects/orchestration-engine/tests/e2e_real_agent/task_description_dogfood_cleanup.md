# Task: orchestration-engine の reviewer 一時ファイル掃除を追加 (#93 前半)

あなたは orchestration-engine の改修担当エージェントです。以下の要件に従って **3 ファイルだけ** を編集し、完了報告に必要な検証結果を含めてください。

## 要件 (具体ファイル位置 + 関数名ピンポイント)

`OE_VERIFY_REVIEWER_SESSION_IDS` 配列で reviewer セッション ID を追跡し、`oe_cleanup` 時に対応する一時ファイル (`/tmp/oe-{rsid}-verify-envelope.json` と `/tmp/oe-{rsid}-verify-inputs.md`) を削除する仕組みを追加します。

### 編集 (1) `projects/orchestration-engine/lib/constants.sh`

ファイル末尾 (既存 `OE_VERIFY_AI_MODEL="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"` の直後) に以下を追加:

```bash

# Step 4-4 Phase C: reviewer 一時ファイル掃除用配列 (派生 Issue #93 前半)
# oe_verify_run_phase で reviewer ULID 生成時に append、oe_cleanup で対応する /tmp/oe-{rsid}-verify-* を削除
OE_VERIFY_REVIEWER_SESSION_IDS=()
```

### 編集 (2) `projects/orchestration-engine/lib/verify.sh`

`oe_verify_run_phase` 関数内の `for target_pane_id in "$@"; do` ループ内で、`reviewer_session_id="$(_oe_verify_generate_session_id)"` の **直後の行** に以下を 1 行追加:

```bash
    OE_VERIFY_REVIEWER_SESSION_IDS+=("$reviewer_session_id")
```

(インデントは既存コードに合わせて 4 スペース。`local reviewer_session_id` 宣言行と `oe_verify_spawn \` 呼び出しの間)

### 編集 (3) `projects/orchestration-engine/lib/cleanup.sh`

`oe_cleanup()` 関数内の audit emit (`oe_audit_emit "cleanup" ...`) の **直後**、`return 0` の前に以下のブロックを追加 (reviewer 一時ファイル削除ロジック):

```bash
  # Step 4-4 Phase C: reviewer 一時ファイル削除 (派生 #93 前半)
  # OE_VERIFY_REVIEWER_SESSION_IDS の各 ID について /tmp/oe-{rsid}-verify-* を削除
  declare -p OE_VERIFY_REVIEWER_SESSION_IDS >/dev/null 2>&1 || OE_VERIFY_REVIEWER_SESSION_IDS=()
  local rsid
  for rsid in "${OE_VERIFY_REVIEWER_SESSION_IDS[@]}"; do
    [[ -n "$rsid" ]] || continue
    rm -f "/tmp/oe-${rsid}-verify-envelope.json" 2>/dev/null || true
    rm -f "/tmp/oe-${rsid}-verify-inputs.md" 2>/dev/null || true
  done
```

## スコープ制約 (必ず守ること)

- `OE_VERIFY_MARKER_RE` (`lib/constants.sh`) は **変更禁止** (派生 #93 後半 nonce マーカーは MVP 後拡張)
- `oe_verify_run_phase` の polling 構造 (二値保持判定、CB タイムアウト) は **変更禁止**
- `bin/oe` は **変更禁止**
- `schemas/` / `bin/` / `tests/e2e_real_agent/` 以下の他ファイルは **変更禁止**
- `oe_verify_spawn` / `_oe_verify_generate_session_id` の本体 (`reviewer_session_id="..."` 行) は **変更禁止**
- 編集は上記 (1)(2)(3) の **追加のみ** (既存行の削除や置き換えはしない、コメント以外)
- 既存 mock テスト全 8 スイートの assertion を **変更してはならない**

## 完了条件 (必ず完了報告 stdout に含めること)

1. **shellcheck**: 以下を `projects/orchestration-engine` ディレクトリで実行し、各コマンドの stdout 全文 (または "no warnings" 文字列) を完了報告に含めること:
   ```bash
   shellcheck ./lib/constants.sh
   shellcheck ./lib/verify.sh
   shellcheck ./lib/cleanup.sh
   ```

2. **既存 mock テスト全 PASS**: 以下を実行し、各テストスイートの結果行 (`=== Results: PASS=N FAIL=M ===`) を完了報告に含めること:
   ```bash
   for f in ./tests/test_*.sh; do bash "$f" 2>&1 | tail -3; done
   ```
   全スクリプトで `FAIL=0` であること。

3. **テスト追加**: `tests/test_cleanup.sh` の最終行 `if [[ "$FAIL" -gt 0 ]]; then exit 1; fi` の **直前** に以下のブロックを追加:
   ```bash

   # ---- Step 4-4 Phase C: OE_VERIFY_REVIEWER_SESSION_IDS 経由の reviewer 一時ファイル削除 ----
   _MOCK_KILL_CALLS=()
   _MOCK_AUDIT_CALLS=0
   _MOCK_LAST_CLEANUP_PAYLOAD=""

   OE_MANAGED_PANES=("701" "702")
   OE_CURRENT_SESSION_ID="TESTRVRCLEAN"
   OE_CLEANUP_DONE=""

   # ダミー reviewer 一時ファイルを作成
   rsid_a="01TESTRSIDA0000000000000A0"
   rsid_b="01TESTRSIDB0000000000000B0"
   OE_VERIFY_REVIEWER_SESSION_IDS=("$rsid_a" "$rsid_b")
   touch "/tmp/oe-${rsid_a}-verify-envelope.json"
   touch "/tmp/oe-${rsid_a}-verify-inputs.md"
   touch "/tmp/oe-${rsid_b}-verify-envelope.json"
   touch "/tmp/oe-${rsid_b}-verify-inputs.md"

   oe_cleanup

   assert_eq "reviewer rsid_a envelope removed" "false" "$( [[ -e "/tmp/oe-${rsid_a}-verify-envelope.json" ]] && echo true || echo false )"
   assert_eq "reviewer rsid_a inputs removed"   "false" "$( [[ -e "/tmp/oe-${rsid_a}-verify-inputs.md" ]] && echo true || echo false )"
   assert_eq "reviewer rsid_b envelope removed" "false" "$( [[ -e "/tmp/oe-${rsid_b}-verify-envelope.json" ]] && echo true || echo false )"
   assert_eq "reviewer rsid_b inputs removed"   "false" "$( [[ -e "/tmp/oe-${rsid_b}-verify-inputs.md" ]] && echo true || echo false )"
   ```
   そして `bash tests/test_cleanup.sh` で 17 件 PASS (既存 13 + 新規 4) を確認、結果行を完了報告に含める。

4. **完了報告フォーマット**: 上記 1〜3 の検証結果を以下の構造で stdout に出力:
   ```
   ## shellcheck 結果
   (各コマンドの stdout)

   ## mock テスト結果
   (各スクリプトの Results 行)

   ## 追加した cleanup テスト結果
   (test_cleanup.sh の最終 Results 行)

   ## 編集ファイル
   (3 ファイルのパス、git diff --name-only の結果)
   ```

## 注意事項

- Bash 3.2 互換 (macOS デフォルト)、`declare -A` (連想配列) 使用禁止、平行配列 OK
- `set -euo pipefail` 環境で動作するコードのみ
- ファイル末尾には改行を 1 つ入れる (POSIX 規約)
- 既存コードのインデントスタイル (スペース 2 / 4 が混在) は触らない、追加分は周辺コードに合わせる
- 編集 (3) で `declare -p OE_VERIFY_REVIEWER_SESSION_IDS >/dev/null 2>&1 || OE_VERIFY_REVIEWER_SESSION_IDS=()` を含むのは `test_cleanup.sh` 単独実行時 (constants.sh が source されていない可能性) への防御 (Step 4-3 cleanup.sh の同パターンと整合)

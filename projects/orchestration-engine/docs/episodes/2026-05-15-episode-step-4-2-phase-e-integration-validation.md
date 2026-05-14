# Step 4-2 Phase E 統合検証（STOP E）

実施日: 2026-05-15

## 完了条件 8 項目チェック

1. ✅ `bin/oe` が envelope を受け取りサブエージェントを spawn できる  
   - 根拠コマンド: `bash ./tests/test_e2e_smoke.sh`  
   - 根拠ファイル: `bin/oe`, `lib/envelope.sh`, `lib/spawn.sh`  
   - 観測: `send.log` に `Read /tmp/oe-<session>-envelope.json and execute the task` を記録し、`session_start` を監査ログへ出力

2. ✅ `@@OE_EXIT:{code}` 検出と 6 値分類  
   - 根拠コマンド: `bash ./tests/test_capture.sh`, `bash ./tests/test_monitor.sh`, `bash ./tests/test_e2e_smoke.sh`  
   - 根拠ファイル: `lib/capture.sh`, `lib/monitor.sh`  
   - 観測: EXIT マーカー検出、`success/partial/retryable_failure/blocked/timeout/protocol_error` 分類を検証

3. ✅ 2s ポーリングで管理ペイン巡回  
   - 根拠コマンド: `bash ./tests/test_monitor.sh`  
   - 根拠ファイル: `lib/monitor.sh`, `lib/constants.sh`  
   - 観測: `OE_POLL_INTERVAL=2` の `while` ループで全管理ペインを巡回し、完了ペインを除外

4. ✅ CB 違反時に `circuit_breaker_triggered` を emit して停止  
   - 根拠コマンド: `bash ./tests/test_monitor.sh`  
   - 根拠ファイル: `lib/monitor.sh`, `lib/audit.sh`  
   - 観測: `timeout/max_turns/max_panes` の 3 条件で emit + kill + 終了を検証

5. ✅ KVS に完了状態を atomic write  
   - 根拠コマンド: `bash ./tests/test_kvs.sh`, `bash ./tests/test_e2e_smoke.sh`  
   - 根拠ファイル: `lib/capture.sh`  
   - 観測: `state/{session_id}.state.json` 生成、隠し tmp ファイル経由の `mv -f` で更新

6. ⚠️ Audit log 7 種イベント JSONL 出力  
   - 根拠コマンド: `bash ./tests/test_audit.sh`, `bash ./tests/test_monitor.sh`, `bash ./tests/test_e2e_smoke.sh`  
   - 根拠ファイル: `lib/audit.sh`, `lib/monitor.sh`, `lib/cleanup.sh`, `lib/spawn.sh`  
   - 観測: `session_start/state_change/interrupt/circuit_breaker_triggered/cleanup/session_end` は実出力確認済み。`human_input` は呼び出し実装・検証が未追加

7. ✅ trap EXIT でペイン kill + 一時ファイル削除  
   - 根拠コマンド: `bash ./tests/test_cleanup.sh`, `bash ./tests/test_e2e_smoke.sh`  
   - 根拠ファイル: `lib/cleanup.sh`, `bin/oe`  
   - 観測: `trap oe_cleanup EXIT INT TERM` により kill と `/tmp/oe-{session_id}-*` 掃除、`cleanup` 監査記録を確認

8. ✅ shellcheck pass  
   - 根拠コマンド: `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh`  
   - 根拠ファイル: `bin/oe`, `lib/*.sh`, `tests/*.sh`  
   - 観測: エラー/警告とも 0（実行済み）

## 実行コマンド

```bash
shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh
bash ./tests/test_capture.sh
bash ./tests/test_monitor.sh
bash ./tests/test_envelope.sh
bash ./tests/test_audit.sh
bash ./tests/test_kvs.sh
bash ./tests/test_cleanup.sh
bash ./tests/test_e2e_smoke.sh
```

## 未達・懸念

- 完了条件 6 の「7 種イベント実出力」は一部未達。`human_input` の emit 経路（および検証）を追加すると完全充足になる。

## 追記: Phase D ハードニング (2026-05-15)

so-compare レビューの指摘を受け、Phase D / E の結線に関する以下の修正（ハードニング）を実施した上で、全テストをパスさせた。

- `session_id` を ULID 文字集合（Crockford base32）に正規化
- `session_start` イベントの `state` を `null` に固定
- `cleanup` イベントの payload に `killed_pane_ids` を追加
- `monitor.sh` 終了後に `bin/oe` で `trap oe_cleanup EXIT INT TERM` を再設定
- `spawn.sh` を2段階API（`prepare_pane` と `send`）に分割（`pane_id` 依存解消）
- `capture.sh` で `\r` と ANSI エスケープを除去する前処理を追加
- 監査ログ `payload` が JSON Object であることを `jq` で事前検証
- `interrupt` イベント: `monitor.sh` が SIGINT/SIGTERM 検知時に `payload.method` を付与して emit

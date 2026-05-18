# tests/e2e_real_agent/

Step 4-4 で導入した実 agent (cursor-agent / claude) を起動する E2E 検証スクリプト群。MVP の orchestration-engine が 1 サイクル (target 完走 → 検証 → cleanup) を実機で完走することを実証する。

## 環境前提

| 要件 | 詳細 |
|---|---|
| `wez` CLI | WezTerm AI Mode CLI が PATH 上にあること (実 wez のパスは `/Users/eddy/bin/wez` または `/opt/homebrew/bin/wez` を shim が自動探索、`OE_REAL_WEZ` で override 可) |
| WezTerm 起動中 | wez pane split/send/capture/kill が動作する状態 |
| `cursor-agent` CLI | target 用。`composer-2` モデルが利用可能 (Cursor Pro / Business サブスク内) |
| `claude` CLI | reviewer 用。`claude-sonnet-4-6` モデルが利用可能 (OAuth ログイン済み) |
| `jq` | KVS / audit の検査に使用 |
| `bash` | 5.x 推奨。pane 内 shell の `${PIPESTATUS[*]}` を使わないため 3.2 でも動作するが、5.x を前提に検証済み |

## 構成

```
tests/e2e_real_agent/
├── README.md                                   # 本ファイル
├── .gitignore                                  # .tmp_* (probe / smoke の一時ログを除外)
├── bin/
│   └── wez                                     # wez shim (notify を notify.log に記録、他は実 wez に exec)
├── probe_target.sh                             # Phase B: cursor-agent / composer-2 の通電確認
├── probe_verify.sh                             # Phase B: claude / sonnet-4-6 の通電確認 (2 段: emit + skill load)
├── task_description_dogfood_cleanup.md         # Phase C: target に渡す task description (DI-1 確定)
├── smoke_cursor_composer_claude_sonnet.sh      # Phase C/D 共通 E2E スモーク
├── check_phase_c.sh                            # Phase C 構造判定 ((a) state=success (b) state_change+session_end)
├── check_cycle_complete.sh                     # Phase D 構造判定 4 点 (target EXIT / reviewer VERIFY / KVS / audit / notify)
└── repro_verify_protocol_error.sh              # Phase C.5 調査用 (engine/wez を経由しない claude one-shot 再現)
```

## 実行手順

```bash
# 1. 通電確認 (本実行の前提を満たすか)
bash projects/orchestration-engine/tests/e2e_real_agent/probe_target.sh
bash projects/orchestration-engine/tests/e2e_real_agent/probe_verify.sh

# 2. E2E スモーク (target → verify → cleanup の 1 サイクル)
bash projects/orchestration-engine/tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh
```

smoke 完走時の最終行は `[smoke] PASS (Phase C + D 構造判定)`。出力ログ・state・audit は `.tmp_smoke_<timestamp>/` に保存される (gitignore 対象)。

## Phase E スキップ条件 (limited-complete 判定)

cursor-agent / claude の片方または両方が手元に無い開発者環境では、本ディレクトリの実行は skip 可。その場合 mock テスト (`projects/orchestration-engine/tests/test_*.sh`) のみで Phase A〜D の構造的整合性を確認 (= limited-complete)。本ディレクトリでの 1 回完走実証 (= full-complete) は別の開発者 / CI で別途実施。

## 期待コスト (Plan F-14)

- `claude-sonnet-4-6` (reviewer): 1 サイクルあたり概ね $0.04〜$0.10 (envelope + verify-inputs + skill 読み込み + Compliance Review 出力)
- `cursor-agent` (composer-2、target): Cursor Pro / Business サブスク内のため CLI から token / cost を取得不可。Episode には **N/A** と明記

## 想定実行頻度

- MVP では 1 回完走を実証すれば十分
- Step 4-5 以降で CI 上の定期実行 (例: nightly) を検討

## トラブルシュート

- `verification_protocol_error` (`exit_without_verify_marker`) が出る場合: reviewer が `@@OE_VERIFY:{pass|fail|warn}` を独立行で emit していない、または engine の scan 経路 (`lib/verify.sh:_oe_verify_scan_log_file`) が log file を読めていない可能性。`/tmp/oe-{reviewer_session_id}-reviewer.log` の中身を確認 (cleanup で削除されるので smoke 実行中に別シェルで確認)。
- `circuit_breaker_triggered` (reason: max_turns) が出る場合: `OE_CB_MAX_TURNS` が小さすぎる可能性。smoke スクリプトは 600 (= 20 min @ 2s poll) を設定済み。
- `claude: budget exceeded` 等: `--max-budget-usd 1.0` でも不足する場合は `lib/spawn.sh:_oe_spawn_build_cli_command` を確認。

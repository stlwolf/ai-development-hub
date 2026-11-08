---
id: "01M6XJGTFHY25MG9JQYRX1RARC"
title: "#448 Codexの道具の障害の検知とSO集計"
date: 2026-11-08
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/448"
    reason: "作業対象"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-08-plan-448-codex-tool-degradation.md"
    reason: "実装計画"
tags: [so-compare, codex, verification]
---

# #448 Codexの道具の障害の検知とSO集計

## なぜこの作業が始まったか

#442でcode-mode hostのタイムアウト中もCodexが終了コード0で回答し、metaだけを読めばSO成功に見えた。#448の認識合わせと計画案をownerが了承し、実装に進んだ。

## S1: 調査と設計の補足

Codex CLI 0.163.0の `--json` と `--output-last-message` を確認した。公開JSONLの診断と最終回答を分けるだけの初案を試したが、code-modeの失敗が `FunctionCallError::RespondToModel` を経てモデルへの返答だけに入る経路があるため、それだけでは不足すると分かった。そのthread IDに一致する保存記録も読み、対応するexec/waitの呼び出しIDから直接のエラー返答を確認する形へ補った。

確認した一次資料（いずれも `openai/codex` の `rust-v0.163.0`）:

- `codex-rs/code-mode/src/remote_session/connection.rs`: hostとのhandshakeのタイムアウトの文言。
- `codex-rs/core/src/tools/code_mode/execute_handler.rs`: 失敗をRespondToModelとして返す経路。
- `codex-rs/core/src/stream_events_utils.rs`: エラーを道具の返答として記録する経路。
- `codex-rs/exec/src/event_processor_with_jsonl_output.rs` と `exec_events.rs`: 公開JSONLの項目と、写す項目の範囲。
- `codex-rs/history/src/rollout_payload.rs`、`codex-rs/rollout/src/policy.rs`・`recorder.rs`: 保存記録の形式・対象・ファイル名。

実機の同じ障害は確認していない。テストのイベントと保存記録は、上のソースを基に構成したものである。

## S2: 実装と失敗の記録

`timeout_status` とCLIの `exit_code` はそのまま残し、`tool_status` を追加した。`degraded` / `unknown` は表示・成功数・so-verdictの集計で通常SOから外す。旧metaにキーが無い場合の一般的な扱いは変えていない。

新しい回帰テストを先に追加した時点ではPASS=9・FAIL=21だった。JSONLのparserでjqのraw出力指定を付け忘れ、最初の修正後も状態に引用符が付き、正常ケースが落ちた。raw出力に直した。既存テストには古い平文CLIスタブが複数あり、新しいJSONL・最終回答・保存記録のインターフェースに合わせた。公開JSONLだけでは不足することが分かり保存記録を加えた後、thread.startedを2つ出すテストfixtureが観測不能になった。そのfixtureをturn.startedに直した。

## S3: 別モデルの確認の試行

ClaudeとCursorのCLI・接続ツールは無い。Codexの別モデル（gpt-6-astraを指定）への問い合わせを試したが、最初はCLIの保存先が読み取り専用で初期化できなかった。既存のCLI設定と認証ファイルを権限600で一時ディレクトリに用意して再度試し、今度はアカウントの認証失効で終了した。JSONLには「access token could not be refreshed」「Please sign in again」とある。回答は無く、SO実返却0件・未実施である。認証情報そのものは出力もcommitもしていない。

この制約のため設計SO・実装SOは完了と呼ばない。問い合わせのプロンプト・JSONL・stderrの一時パスは `/tmp/issue-448-so/` で、消える。結論と失敗理由は上の本文に残した。

## 検証と残り

関連7スイートで398項目が成功した。内訳は、道具の障害60・read-only契約14・入力拒否120・版の整合4・oe-refute63・oe-review64・oe-lane-explain73である。ShellCheck 0.11.0、bash -n、git diff --checkも成功した。Bash 3.2、実環境のcode-mode障害、別モデルの実装レビューは未確認。レビューゲートが未完了のため、episodeは閉じない。


## レビューへ渡す状態

実環境の同じcode-mode障害での確認と、別モデルの実装SOが未完了である。通常のSOとして数えられる外部回答は0件。`document-format.md` §4.1の「0はなし」により、レビューを完了したとは扱わず、下書きPRとして渡す。

検証中に、RespondToModelの返答のcall_idが空になる経路もソースで見つけた。対応するexec/waitを特定できない直接の障害返答は、正常とせずunknownにするテストと処理を追加した。別の呼び出しの出力をexecの障害と断定せず、関連付け不能と区別する。

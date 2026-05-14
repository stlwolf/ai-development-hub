---
id: "01KRJMNT7BF43RBNC146JMVG4C"
title: "DI-14: クリーンアップ戦略 — trap + wez pane kill 一括停止"
date: 2026-05-14
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-plan-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 Plan"
  - type: depends_on
    ref: "DI-11"
    reason: "監査ログの cleanup イベント定義"
tags: [orchestration, mvp, step-4-1, decision, cleanup, trap, wezterm, reliability]
---

# DI-14: クリーンアップ戦略 — trap + wez pane kill 一括停止

## コンテキスト

ディスパッチャは `wez pane split` でサブエージェント用ペインを作成し、タスク完了後に回収する。正常終了時のペイン回収は実装が自明だが、ディスパッチャ自体がクラッシュ・シグナル中断した場合に **orphaned ペイン**（親プロセスを失ったサブエージェントペイン）が残る。

orphaned ペインは以下のリスクを持つ:

- リソース消費（ターミナルセッション、CPU、メモリ）
- サブエージェントが無制御状態で動作継続（DI-7 の SLO サーキットブレーカーはディスパッチャ側の判定なので、ディスパッチャ停止時は効かない）
- 次回ディスパッチャ起動時のペイン ID 衝突・状態不整合

## 検討した選択肢

- **案 A — 専用 registry ファイル + 外部 watchdog**: `pane_registry.json` に全ペインを登録し、別プロセスの watchdog が死活監視
- **案 B — trap + wez pane kill 一括停止**: ディスパッチャスクリプト内の `trap` で管理下ペインを一括停止
- **案 C — session-state KVS + 起動時クリーンアップ**: KVS にペイン状態を記録し、次回起動時に前回の orphaned ペインを検知・停止

## 決定

**案 B を採用**: ディスパッチャスクリプト単独の `trap EXIT INT TERM` で管理下ペインを一括停止する。

### クリーンアップフロー

1. ディスパッチャ起動時に `trap cleanup_handler EXIT INT TERM` を設定
2. サブエージェント spawn 時に `pane_id` を配列変数に追加
3. 正常終了 / シグナル受信時に `cleanup_handler` が発火:
   - 管理下 `pane_id` リストを走査し `wez pane kill $pane_id` で一括停止
   - 監査ログに `cleanup` イベントを記録（DI-11 の `event_type: cleanup`）
   - `wez pane kill` の失敗（既に終了済み等）は警告ログのみで続行

### Registry 方針

- MVP では専用 registry ファイルを作成しない
- ペイン一覧の確認は `wez pane list` を都度実行する方式で代替
- session-state KVS（`{session_id}.state.json`）にペイン状態が記録されるため、KVS と `wez pane list` の突合で orphaned ペインの手動確認が可能

## 根拠

- **単純性**: `trap` は Bash の標準機能であり、外部プロセスや追加ファイルが不要。ディスパッチャスクリプト単体で完結する
- **専用 registry 不要**: `wez pane list` が現在のペイン一覧を返すため、「真の状態」は常に WezTerm 側にある。registry ファイルは二重管理になりかえって不整合リスクを生む
- **`wez pane kill` の信頼性**: Step 0 で exit 0 を確認済み。既に終了済みのペインに対しても安全に動作する
- **案 A の過剰性**: 外部 watchdog は MVP の複雑さを大幅に増加させる。個人開発環境でプロセス監視デーモンを運用するコストは不釣り合い
- **案 C との併用可能性**: KVS による状態記録は案 B と直交する。将来的に起動時クリーンアップを追加する場合も、trap 方式はそのまま維持できる

## 影響・制約

- **trap が効かないケース**: `kill -9`（SIGKILL）はトラップ不可。この場合 orphaned ペインが残る
- **手動確認の必要性**: クラッシュ後の orphaned ペイン検知は `wez pane list` による手動確認。自動検知は Phase 5 以降の課題
- **ペイン上限との関係**: DI-7 のサーキットブレーカー（ペイン 5 上限）はディスパッチャ動作中のみ有効。クラッシュ後の orphaned ペインはこの制限の対象外
- **cleanup イベントのログ**: DI-11 で定義済みの `event_type: cleanup` を使用。正常終了・異常終了いずれでもログが記録される

## 将来の変更トリガー

- **SIGKILL 対策が必要になった場合**: 起動時クリーンアップ（案 C）を追加。KVS と `wez pane list` の差分から orphaned ペインを自動検知・停止
- **長時間セッションの安定性要件**: 外部 watchdog（案 A）の導入を検討。ただし Phase 5 以降で engine の信頼性要件が明確化してから
- **マルチセッション同時実行**: 複数ディスパッチャが同時動作する場合、ペインの所有権管理が必要になり registry 方式の再評価が必要

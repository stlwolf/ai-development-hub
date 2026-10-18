---
title: "ADR-004: スコープ変更 — thread-done を外し、データ抽出・エクスポートに集中"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: supersedes
    ref: ../plans/2026-02-21-kickoff-phase3-thread-done.md
    reason: "Phase 3 キックオフ（thread-done）を差し替え"
  - type: derived_from
    ref: ../plans/2026-02-20-kickoff-cursor-thread-tools.md
    reason: "プロジェクトキックオフのスコープ定義を修正"
tags: [scope, architecture, thread-done, cli, auto-save]
---

# ADR-004: スコープ変更 — thread-done を外し、データ抽出・エクスポートに集中

## 状態

Accepted

## コンテキスト

プロジェクトキックオフで `threadTools.done`（git diff + gh issue comment による完了報告投稿）を Phase 3 のスコープとして定義していた。Phase 2 完了後の振り返りで、機能の性質を分類した結果、thread-done は本プラグインのコア（Cursor 内部データアクセス + エクスポート）とは独立した関心であることが判明した。

## 決定

**`threadTools.done` を本プラグインのスコープから外す。** 代わりに Phase 3 のスコープを以下に変更:

- 自動保存（バックグラウンド定期実行）
- CLI エントリポイント（ターミナルからの実行）
- export のカスタマイズ（出力フォーマット、thinking 含む/含まない等）

thread-done の機能（git diff + gh issue comment）は、以下のいずれかとして別途実装:

- `cursor/command/workflow/thread-done.md`（Cursor コマンド、プロンプトベース）
- 独立した CLI ツール
- 本プラグイン完成後の拡張機能

## 根拠

| 観点 | thread-done（C層） | export/auto-save/CLI（A+B層） |
|------|-------------------|-------------------------------|
| Cursor 内部データ依存 | なし（git/gh のみ） | あり（state.vscdb 必須） |
| 外部ツール依存 | git, gh CLI | なし |
| テスト容易性 | 低（外部コマンド実行） | 高（純粋な変換処理） |
| プラグイン以外でも実現可能か | はい（Cursor コマンドで可） | いいえ（DB アクセスが必要） |

## 影響

- Phase 3 キックオフを書き直し（thread-done → 自動保存 + CLI + カスタマイズ）
- VERIFICATION_MATRIX A-3（thread-done 統合）の検証項目を差し替え
- README.md の機能表を更新
- Phase 1, 2 のコード・ドキュメントへの影響はなし

---
title: "ADR-006: 自動保存デフォルトインターバル — 無効（オプトイン）"
date: 2026-02-21
type: decision
status: accepted
related:
  - type: derived_from
    ref: ../plans/2026-02-21-plan-phase3-auto-save-cli.md
    reason: "Phase 3 Step 0-c の決定事項"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-3-1 自動保存検証の設計基盤"
tags: [auto-save, default-config, opt-in]
---

# ADR-006: 自動保存デフォルトインターバル — 無効（オプトイン）

## 状態

Accepted

## コンテキスト

Phase 3 で自動保存機能を追加するにあたり、デフォルトインターバルを決定する必要があった。キックオフでは「無効 or 30分」が候補として挙げられていた。

## 決定

**デフォルト無効（`cursorThreadTools.autoSave.intervalMinutes = 0`）。ユーザーが明示的に有効化するオプトイン方式。**

## 根拠

| 候補 | 棄却理由 |
|------|---------|
| デフォルト 30分 | 予期しないバックグラウンドのファイル生成はユーザーへの驚き（principle of least surprise）。`.thread-exports/` がワークスペースに作られると `.gitignore` 設定が必要。センシティブな会話が自動保存される可能性 |
| デフォルト 60分 | 同上。頻度は低いが根本的な問題は変わらない |

オプトイン方式の利点:
- SpecStory との二重保存を回避
- DB への定期アクセスの影響を回避（Cursor パフォーマンスへの懸念）
- `contributes.configuration` の description に「0 = disabled」を明記済み
- peer-ai-review で Codex / Claude とも「適切」と合意

## 影響

- `package.json` の `cursorThreadTools.autoSave.intervalMinutes` デフォルト値: `0`
- `extension.ts` の `setupAutoSave()` は interval <= 0 で即 return
- `activationEvents` に `onStartupFinished` を追加済み（設定が 0 でもアクティベートはされるがタイマーは起動しない）

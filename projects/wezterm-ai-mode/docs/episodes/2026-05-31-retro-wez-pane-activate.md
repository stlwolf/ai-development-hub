---
id: 01KSYJPC0950BJ0PV8J636Z87G
title: "振り返り: #111 wez pane activate 1サイクル（#113 構造化振り返りテンプレ検証）"
date: 2026-05-31
type: episode
status: stable
related:
  - type: derived_from
    ref: ./2026-05-31-wez-pane-activate.md
    reason: "本サイクルの実装エピソードから抽出"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/113"
    reason: "構造化振り返りテンプレ（KPT + 構造化フィードバック表）の検証ケース"
  - type: depends_on
    ref: ./2026-04-20-retro-phase1-1-2.md
    reason: "既存の横断振り返り体裁（目的→事実→分析→適用）を踏襲しつつ #113 構造を上乗せ"
tags: [retrospective, kpt, process, peer-ai-review, gate, phase2, issue-113]
keywords: [retrospective, KPT, handoff-gate, peer-ai-review, copilot, focus-e2e]
use_when:
  - "#113 の構造化振り返りテンプレの実適用例を確認するとき"
  - "Stage 1〜3 + gate 運用の改善点を辿るとき"
---

# 振り返り: #111 wez pane activate 1サイクル

## 目的

[#111](https://github.com/stlwolf/ai-development-hub/issues/111) の `wez pane activate` 実装を、CONVENTIONS の Stage 1〜3（plan MD + peer-ai-review → 実装 + gate → 成果物記録）で1サイクル回した。本振り返りは [#113](https://github.com/stlwolf/ai-development-hub/issues/113) が提案する **構造化振り返りテンプレ（KPT + 構造化フィードバック表）の検証ケース**を兼ねる。VERIFICATION_MATRIX B に1件追加する（B-1〜B-3 が Phase 1 でスキップだったプロセス検証の、初の実適用）。

## 構造化フィードバック表（#113 提案フォーマットの試用）

| # | handoff-gate（受け渡し点） | finding（観測） | 振り返り手法 | target（改善対象） |
|---|---------------------------|----------------|------------|------------------|
| 1 | 方向確認（AskUserQuestion: A activate vs B --no-focus） | 一次情報（`wezterm cli --help` 実測）で B が native 非対応と判明し、選択が事実上 A に確定。推測でなく実測が分岐を締めた | Keep | 設計分岐前の primary-source 確認 |
| 2 | ADR 粒度のユーザー指摘 | 「2択比較=ADR」を機械適用しかけたが、既存 ADR-003/006 と粒度比較した結果エピソード完結が妥当と判断。昇格フロー定義の揺らぎが顕在化 | Problem→Try | ADR 昇格基準の粒度判定（#113 と別軸） |
| 3 | plan MD レビュー（ユーザーが branch/PR/copilot/retro 追加を後出し） | プランを MD 化した後に process step が追加された。plan mode 中で MD 直接編集ができず harness plan と二重管理になった | Problem | plan mode と プロジェクト plan MD の二重管理 |
| 4 | プラン peer-ai-review gate | Codex/Claude 揃って「Step 3 gate 条件の手元 E2E pass が Step 4(E2E) より前」の順序矛盾を指摘。プラン改訂で解消 | Keep | gate 条件の前後整合（SO が機械的に拾えた） |
| 5 | 実装後コードレビュー gate | Codex が `bin/wez` トップレベル help の activate 漏れを発見（私と Claude は pane.sh help のみ確認し見落とし）。Claude は help 文言の過剰約束を指摘 | Keep→Try | 「help は2箇所（サブ + トップレベル）」をチェックリスト化 |
| 6 | focus E2E の実行判断 | ライブ GUI のフォーカスを奪う E2E をユーザー判断でスキップ。成功パスは検証済み kill と同一構造のため PARTIAL で受容 | Try | dogfood 用の隔離ウィンドウ/workspace 標準化（#111 回避策と同根） |
| 7 | Copilot レビュー依頼 | `gh pr edit --add-reviewer Copilot` は `'Copilot' not found` で失敗。`gh api .../requested_reviewers -f 'reviewers[]=copilot-pull-request-reviewer[bot]'` で成功 | Problem→Try | Copilot レビュー依頼の正規手順が未文書（skill 化候補） |

## KPT（#113 提案の締めフォーマット）

### Keep（続ける）

- 設計分岐の前に一次情報を実測（gate 1）。`--no-focus` 不在の実測が方向を確定させた
- gate を独立 TODO として実行（peer-ai-review / コードレビュー）。両 gate がそれぞれ別の実欠陥を検出（順序矛盾 / help 漏れ）
- 薄いラッパーは既存（`kill`）の 1:1 模倣で実装し、レビューも「差分が kill と同型か」に集中できた

### Problem（問題）

- ADR 昇格フローの定義が緩く、毎回その場判断になっている（gate 2）
- plan mode 中はプロジェクト plan MD を直接編集できず、harness plan と二重管理になった（gate 3）
- Copilot レビュー依頼の CLI 手順が未文書で、`gh pr edit` の失敗→`gh api` フォールバックを都度試行した（gate 7）

### Try（次に試す）

- Copilot レビュー依頼手順を `pr-conventions` または `copilot-review-response` skill に追記（`gh api .../requested_reviewers` + bot slug `copilot-pull-request-reviewer[bot]`）
- help 追記の二重チェック（サブコマンド help + トップレベル `wez help`）を pane 系変更のチェック項目に
- dogfood は専用 WezTerm window/workspace で行う運用を明文化し、focus を奪う E2E を分離（#111 回避策の常設化）
- ADR 昇格の粒度判定ガイドを #113 側で具体化（「upstream 制約による実質強制」「新規アルゴリズム不在」は episode 完結の目安）

### Open Questions

- #113 の構造化振り返りテンプレに「timestamp」列は必要か。本サイクルでは handoff-gate の順序で十分追跡でき、正確な時刻は冗長に感じた → #113 へフィードバック
- plan mode と project plan MD の二重管理は、運用ルール（先に MD 確定 → plan mode は参照のみ）で回避すべきか

## #113 への申し送り（テンプレ検証結果）

- **有効だった**: KPT + 構造化フィードバック表（handoff-gate 軸）は、gate ごとの finding を粒度そろえて拾えた。特に「finding → 振り返り手法(KPT) → target」の3列が、観測を改善アクションへ機械的に橋渡しできた
- **冗長だった**: timestamp 列。handoff-gate の通し番号 + 名前で順序は追えるため、時刻は任意でよい
- **不足**: 「誰が見落とし / 誰が発見したか」（自分 / Codex / Claude）の発見者列があると、SO の価値とカバレッジギャップが定量化できる（gate 5 で Codex のみ help 漏れを発見した、等）

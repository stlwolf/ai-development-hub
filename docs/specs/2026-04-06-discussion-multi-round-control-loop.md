---
id: "01KNHHH28SJCSAYQ8M1908506"
title: "so-compare 多周制御 — 終了条件・ループ不変条件・観測の仕様整理"
date: 2026-04-06
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/36"
    reason: "Issue #36: so-compare 多周制御（終了条件・観測）の仕様整理と #22 との役割分担"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/35"
    reason: "Epic #35: so-compare / セカンドオピニオン改善"
  - type: sibling
    ref: "https://github.com/stlwolf/ai-development-hub/issues/22"
    reason: "#22: 単発ランの観測（exit code, タイムアウト回復, 部分成功検知）"
  - type: source_material
    ref: "docs/research/oss-sessions/2026-04-01-rigg.md"
    reason: "Rigg review.yaml の loop/max/until パターン、構造化 findings、directive"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/harness-engineering-mapping.md"
    reason: "NLAH State Semantics / Failure Taxonomy との接続"
  - type: design_context
    ref: "docs/draft/orchestration-control-loop-challenges.md"
    reason: "制御ループの課題構想（状態判定・再投入・エスカレーション）"
  - type: integration_target
    ref: "canonical/commands/verification/peer-ai-review.md"
    reason: "多周制御の主な消費者。findings 構造化・directive の追記先候補"
tags: [so-compare, multi-round, loop-control, peer-ai-review, epic-35]
---

# so-compare 多周制御 — 終了条件・ループ不変条件・観測の仕様整理

## 1. 目的

so-compare / peer-ai-review を複数周回す際の **終了条件** と **ループ不変条件** を構造化し、「いつ止めるか」「何を次周に持ち越すか」を明示する。

現行の peer-ai-review.md は「最大3イテレーション、3者合意」を散文で定めているが、以下が不在:

- findings の構造化（件数ベースの終了判定）
- 各周で何が保存・縮小されるか（ループ不変条件）
- 単発ランの観測結果（#22）との接続仕様
- オシレーション（振り子修正）の検出

## 2. 役割分担 — #22 と #36 の境界

> **#22** は「1回の so-compare 実行が成功/部分成功/失敗のどれかを機械的に判定する」層。
> **#36** は「その判定結果を受けて多周ループをいつ止めるか・何を次周に持ち越すかを定義する」層。

| 責務 | 担当 | 備考 |
|------|------|------|
| exit code 分離 (0 = 全成功 / 1 = 部分成功 / 2 = 全失敗) | #22 | so-compare.sh の変更 |
| 部分成功検知（片方のみ応答） | #22 | stdout 有無の判定 |
| タイムアウト後のリトライ判断 | #22 | 部分応答 vs 完全無応答 |
| 終了条件の定義（いつループを止めるか） | #36 | 本ドキュメント |
| ループ不変条件（何を持ち越すか） | #36 | 本ドキュメント |
| findings 縮小セットの管理 | #36 | 本ドキュメント |
| オシレーション検出 | #36 | 本ドキュメント |

**接続点**: #36 の終了条件モデルは #22 が提供する exit code を前提条件として消費する。#22 が未実装の間は、現行の exit 0 のみで動作し、異常終了条件が機能しない（graceful degradation）。

## 3. 終了条件モデル

peer-ai-review の「3者合意 or 上限到達」を4つの終了パターンに構造化する。

### 3.1 終了パターン

| パターン | 条件 | 結果 |
|---------|------|------|
| **正常終了** | `open_findings == 0`（全指摘が resolved or dismissed） | 修正実行へ進む |
| **合意終了** | 3者の修正方針が一致（peer-ai-review 合意判定基準を満たす） | 修正実行へ進む |
| **上限終了** | `iteration >= max_iterations`（デフォルト: 3） | 残存差異を明示してユーザーに判断を委ねる |
| **異常終了** | #22 の exit code が連続2回以上全失敗（exit 2） | ループを中断しユーザーに報告 |

### 3.2 終了判定の評価順序

```
1. 異常終了チェック（#22 exit code）
   └─ 連続全失敗 → 中断
2. 上限チェック
   └─ iteration >= max_iterations → 上限終了
3. findings チェック
   └─ open_findings == 0 → 正常終了
4. 合意チェック（peer-ai-review 合意判定基準）
   └─ 3者一致 → 合意終了
   └─ 不一致 → 次イテレーションへ
```

異常終了を最優先で評価する理由: プロバイダが応答しない状態で合意判定を行っても意味がない。

### 3.3 Rigg `review.yaml` との対応

| Rigg の構成要素 | Hub での対応 |
|----------------|-------------|
| `type: loop` + `max: 6` | peer-ai-review の `max_iterations`（デフォルト 3） |
| `until: findings.length == 0` | `open_findings == 0`（正常終了条件） |
| ステップ間の `${{ }}` 式 | レビューログ内の findings リスト（手動参照） |
| headless JSON stdout | so-compare の出力ファイル（`codex-stdout.txt`, `claude-stdout.txt`） |

## 4. ループ不変条件

各イテレーションで **保存・引き継ぐもの** と **そのフォーマット** を定義する。

### 4.1 findings リスト

各周の SO 出力から抽出された指摘を構造化する。

```markdown
## Findings

| # | severity | file | description | status | directive |
|---|----------|------|-------------|--------|-----------|
| 1 | critical | `src/foo.ts:42` | XSS: 未エスケープ出力 | open | — |
| 2 | major | `src/bar.ts:15` | AuthN チェック欠落 | resolved | — |
| 3 | minor | `src/baz.ts:8` | 変数名の typo | dismissed | reason: cosmetic |
```

フィールド定義:

- **severity**: `critical` / `major` / `minor` / `informational`
  - peer-ai-review の比較テーブルと pr-review-checklist の CRITICAL/INFORMATIONAL 分類を接続
- **status**: `open` / `resolved` / `dismissed`
  - `open`: 未対処。次周に持ち越す
  - `resolved`: 修正済み。次周の SO で再検証される
  - `dismissed`: 却下（理由を directive に記録）
- **directive**: 振り子止め拘束やステータス変更の理由（後述 §5）

### 4.2 縮小後集合

各イテレーションの SO プロンプトには、**open な findings のみ** を含める。resolved / dismissed は除外する。

```
open_findings(N) = findings(N-1).filter(f => f.status == "open")
                 + new_findings(N)
```

これにより:
- SO の注意を未解決の指摘に集中させる
- 解決済みの指摘の再指摘（ノイズ）を抑制する
- findings の単調減少を期待できる（正常系では）

### 4.3 イテレーション履歴

レビューログに各周の状態遷移を記録する:

```markdown
### イテレーション N サマリ

- **findings**: 総数 X → open Y / resolved Z / dismissed W
- **新規 findings**: N 件
- **severity 分布**: critical A / major B / minor C / informational D
- **オシレーション**: なし / 検出（詳細は §5）
- **判定**: 合意 / 不一致（差異: ...） / 上限到達
```

## 5. オシレーション検出

### 5.1 定義

オシレーション（振り子修正）とは、**同一の finding が resolved → open → resolved を繰り返す** パターン。Rigg/Zenn 文脈では「修正 A を入れる → 別の SO が A を戻す指摘をする → A を戻す → 最初の SO が A を再指摘する」という往復。

### 5.2 検出条件

以下のいずれかに該当する場合、オシレーションとして検出する:

1. **同一 finding のステータス往復**: `resolved → open` が同一 finding で発生（finding の `#` と `file` で同定）
2. **同一ファイル・同一行への修正往復**: git diff で同一行が2周以上にわたって変更・復元されている

### 5.3 対処: directive の付与

オシレーションが検出された finding には **directive** を付与し、次周の SO プロンプトに拘束として注入する。

```markdown
| # | severity | file | description | status | directive |
|---|----------|------|-------------|--------|-----------|
| 1 | major | `src/foo.ts:42` | エスケープ方式の選択 | open | LOCK: イテレーション 2 で `encodeURIComponent` に決定。戻さないこと |
```

directive の種類:

- **LOCK**: 「この修正は戻さない」。合意済みの判断を固定する
- **SCOPE**: 「この指摘はスコープ外」。cosmetic / nice-to-have を除外する
- **DEFER**: 「この指摘は別 Issue で対処」。現在のレビューサイクルから切り離す

### 5.4 Rigg `review.yaml` との対応

Rigg の fix ステップでは triage 済み findings に directive を付与して Codex に渡す（`review.yaml` `steps.remediation.steps.fix`）。Hub では SO プロンプトの `--prev` コンテキストに directive 付き findings テーブルを含めることで同等の効果を得る。

## 6. 観測ポイント

各周で記録すべきメトリクス。レビューログのイテレーションサマリ（§4.3）に含める。

| メトリクス | 目的 | 正常系の期待 |
|-----------|------|-------------|
| `open_findings` 数 | 収束の確認 | 単調減少 |
| `new_findings` 数 | 新規指摘の発生率 | 周を重ねるごとに減少 |
| severity 分布 | 残存リスクの可視化 | critical が早期に 0 になる |
| オシレーション件数 | 振り子の検出 | 0 が理想 |
| #22 exit code | 単発ランの健全性 | 0（全プロバイダ成功） |

**異常シグナル**: `open_findings` が増加傾向にある場合、修正が新たな問題を導入している可能性がある。2周連続で増加した場合は上限到達を待たず、ユーザーにエスカレーションを検討する。

## 7. Rigg パターンの Hub 適用判断

### 採用するもの

| パターン | 理由 |
|---------|------|
| 構造化 findings → 終了条件 | 「findings が 0 になったら止める」は機械的に判定可能。散文合意より明確 |
| directive（オシレーション防止） | LOCK/SCOPE/DEFER の3種で実用上十分。プロンプト注入で実現可能 |
| severity 分類 | pr-review-checklist の CRITICAL/INFORMATIONAL と整合 |

### 採用しないもの

| パターン | 理由 |
|---------|------|
| Rigg ランナー自体の導入 | Hub は Bash+Markdown 薄型方針（CLAUDE.md）。Bun バイナリ + `.rigg/` ディレクトリの必須化は方針に反する |
| `${{ }}` 式によるステップ間データ連携 | Hub のスキル/コマンドはエージェントが読む Markdown。テンプレート式は不要 |
| headless JSON 出力のパース自動化 | so-compare の出力は人間/エージェントがテキストとして読む設計。JSON パーサーの導入は over-engineering |

### 保留

| パターン | 理由 |
|---------|------|
| 宣言的ループ構文（YAML）の導入 | orchestration-research [#19](https://github.com/stlwolf/ai-development-hub/issues/19) のスコープ。本 Issue では仕様のみ整理し、実装形態は #19 に委ねる |

## 8. peer-ai-review への接続（実装提案）

本ドキュメントの仕様を peer-ai-review.md に反映するための変更提案。**実装は別 Issue/PR で行う。**

### 8.1 レビューログテンプレートへの追加

現行のレビューログに以下を追加:

1. **Findings テーブル**（§4.1 のフォーマット）をイテレーションごとに記録
2. **イテレーションサマリ**（§4.3 のフォーマット）を各周の末尾に追記
3. **Directive セクション** — オシレーション検出時に LOCK/SCOPE/DEFER を記録

### 8.2 SO プロンプトへの findings 注入

イテレーション 2 以降の SO プロンプト構成（peer-ai-review Step 2.5）に以下を追加:

```
## 前回の findings（open のみ）

| # | severity | file | description | directive |
|---|----------|------|-------------|-----------|
| ... | ... | ... | ... | ... |

上記の findings に対して:
1. 解決済みかどうかを検証してください
2. LOCK directive が付いた項目は修正を戻さないでください
3. 新規の findings があれば追加してください
```

## 9. NLAH との接続

harness-engineering-mapping.md で「不在」と評価された **State Semantics** の一部を本仕様が埋める:

| NLAH コア要素 | 本仕様での対応 |
|---|---|
| State Semantics（ステップ間の永続化宣言） | findings リスト + directive + イテレーション履歴がループ内の状態として明示化される |
| Failure Taxonomy（失敗分類 → リカバリ） | 終了条件モデルの4パターン（正常/合意/上限/異常）が失敗時の分岐を定義 |
| Contracts（停止ルール） | 終了条件の評価順序（§3.2）が停止ルールとして機能 |

## 10. 未解決事項

- **findings の自動抽出**: SO 出力からの findings テーブル自動生成は実現可能か。現状はエージェントが手動で抽出する想定
- **severity の判定基準**: pr-review-checklist の基準をそのまま使うか、多周制御用に調整が必要か
- **max_iterations の妥当性**: peer-ai-review のデフォルト 3 は Rigg の 6 より少ない。実運用データに基づく調整が必要
- **#43 との関係**: Cursor CLI ピア追加（#43）により3者→4者になった場合、合意判定基準の調整が必要

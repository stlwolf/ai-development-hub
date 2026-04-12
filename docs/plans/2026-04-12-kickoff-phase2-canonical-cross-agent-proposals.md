---
id: 01KP0QT9PB65VVBAAQY5F1F21R
title: "Phase 2: canonical cross-agent 改修提案"
date: 2026-04-12
type: kickoff
status: draft
scope: canonical
related:
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/38"
    reason: "Epic: canonical cross-agent optimization"
  - type: design_context
    ref: "docs/research/2026-04-02-canonical-cross-agent-optimization-framework.md"
    reason: "基準文書: 2x3 マトリクス・判定ルール・実行順序"
  - type: source_material
    ref: "docs/plans/issue#63/2026-04-12-rules-verification-results.md"
    reason: "Phase 1 動的検証結果（3ツール × 3シナリオ）"
  - type: source_material
    ref: "docs/plans/issue#63/2026-04-12-rules-verification-scenarios.md"
    reason: "Phase 1 動的検証シナリオ定義"
  - type: source_material
    ref: "docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md"
    reason: "Phase 0 成果: 3ツール仕様比較調査"
  - type: source_material
    ref: "docs/research/harness-engineering/current-state-assessment.md"
    reason: "ハーネス現状評価（ギャップ分析）"
  - type: completed_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/63"
    reason: "Phase 1 Core Canonical（close 済み）"
  - type: open_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/64"
    reason: "Phase 1 スキル/コマンドロード検証（未着手）"
tags: [canonical, cross-agent, phase2, proposals]
---

# Phase 2: canonical cross-agent 改修提案

## 背景

[Epic #38](https://github.com/stlwolf/ai-development-hub/issues/38) の Phase 1 × Core Canonical（[#63](https://github.com/stlwolf/ai-development-hub/issues/63)）が完了した。静的整理（[PR #65](https://github.com/stlwolf/ai-development-hub/pull/65)）と動的検証（3ツール × 3シナリオ）を通じて、canonical/rules の品質改善とルール層の構造的限界が明らかになった。

Phase 2 は基準文書の定義に従い、Phase 1 の findings をもとに「ファイル単位で最小差分の改善案を作る」段階である。各提案は [判定ルール](docs/research/2026-04-02-canonical-cross-agent-optimization-framework.md)（Core Canonical → Agent Adapter → Automation Surface の順で検討）に基づいて行き先を判定する。

### Phase 1 が確立した前提

1. **ルールの認識 vs 遵守にギャップがある**: 3ツールとも全ルールを認識するが、遵守度はツール・文脈で異なる
2. **ルール（文書）の強制力には上限がある**: 到達度は平均 60-70%。フック層・オーケストレーション層なしに 100% は到達困難
3. **Codex の Default mode は canonical/rules と構造的に衝突する**: ルールを認識しても、システム指示（即実行前提）が優先される
4. **例外条件はモデルに「抜け道」を提供する**: implementation-gate の軽微修正例外を3ツールとも自ら援用
5. **「計画フェーズ」文言がツール側の Plan mode トリガーを弱めた可能性がある**

### Phase 1 で未実施の診断

- [#64](https://github.com/stlwolf/ai-development-hub/issues/64): スキル/コマンドのロード・発見性検証（Phase 1 × Core Canonical の残）
- Phase 1 × Agent Adapter: 各ツール展開先の配置・メタデータ診断、Codex 権限レイヤー設計
- Automation Surface の診断: hooks / sync / mcp の非対称診断

Phase 2 着手前に #64 を完了させるか、Phase 2 と並行するかは判断が必要。

## 目的

Phase 1 の findings に対して、具体的な改修案を minimal diff で提示する。各提案について Core Canonical / Agent Adapter / Automation Surface のいずれで対処すべきかを判定し、実行可能な Issue に分解する。

## スコープ

### In Scope

Phase 1 の申し送り 6 項目を改修提案レベルに具体化する:

1. `implementation-gate` の例外条件再設計
2. 「計画フェーズ」vs `Plan mode` の文言問題
3. Codex Agent Adapter の設計
4. 行動原則系ルールの強制力補完
5. Minimal Scope の遵守度差異の切り分け
6. フック・オーケストレーション層の厚み不足への対応

### Out of Scope

- オーケストレーションツール（[#19](https://github.com/stlwolf/ai-development-hub/issues/19)）の設計・実装: 制御ループ本体は別 Epic
- リポジトリ固有の AGENTS.md / CLAUDE.md の改修: Phase 1 で対象外と確定
- MCP サーバの新規開発
- モデル選択・Fine-tuning

## 事前準備

Phase 2 に入る前に確認・完了すべき項目:

- [ ] [#64](https://github.com/stlwolf/ai-development-hub/issues/64)（スキル/コマンドロード検証）の完了 or 並行判断
- [ ] `canonical/rules/` の最新状態の確認（PR #65 マージ後の変更有無）
- [ ] Phase 1 動的検証結果の再確認: `docs/plans/issue#63/2026-04-12-rules-verification-results.md`
- [ ] Phase 0 の設計制約の再確認: Codex 32 KiB / Claude Code コンパクト生存 / Cursor alwaysApply

## 実装計画

### Stage 1: Core Canonical 改修

Phase 1 findings のうち、正本で解決すべきものを minimal diff で修正する。

#### Step 1: implementation-gate の例外条件再設計

**問題**: 3ツールとも「1ファイル数行の軽微な修正で、ユーザーが明示的に『そのまま直して』と指示した場合」の例外条件のうち、後半（明示的指示）を無視して前半（軽微な修正）だけで例外を援用する。

**検討する選択肢**:

| 選択肢 | 内容 | リスク |
|--------|------|--------|
| A. 例外の削除 | 例外条件自体を除去し、計画フェーズを常に要求 | 軽微な修正でも計画提案が走り、ユーザー体験が悪化 |
| B. 例外条件の厳格化 | 「ユーザーが『計画不要』と明示した場合のみ」に限定 | 文面の強化だけで遵守されるか未知 |
| C. フック層での補完 | pre-edit フックで「計画フェーズを経たか」を確認 | フック基盤の拡充が前提（Automation Surface 依存） |
| D. 段階的アプローチ | まず B を適用し、動的検証で改善しなければ C に進む | 二段階のコスト |

**判定**: まず Core Canonical（B）で解けるか検証。不十分なら Automation Surface（C）。

#### Step 2: 「計画フェーズ」文言の再設計

**問題**: 静的整理で `Plan mode` → `計画フェーズ` に変更したが、各ツールの Plan mode 切り替えトリガーを弱めた可能性がある。

**検討する選択肢**:

| 選択肢 | 内容 | リスク |
|--------|------|--------|
| A. 正本を `Plan mode` に戻す | ツール固有名詞がルールに混入 |
| B. 正本は「計画フェーズ」のまま + Agent Adapter で紐づけ | 各ツールの adapter に `計画フェーズ = Plan mode` と明記 |
| C. 正本に括弧注記を追加 | `計画フェーズ（各ツールの Plan mode 相当）` | 文面の冗長化 |

**判定**: Core Canonical のツール非依存性を維持する方針上、B（Agent Adapter）が筋。

#### Step 3: Minimal Scope の遵守度差異分析

**問題**: Claude Code が最も厳格で「ついで」を拒否、Cursor は寛容に含める。ルール文面の問題か、モデル/ツール特性差かの切り分けが必要。

**アプローチ**:
- 同一プロンプトで文面微調整（「ついで」の強調度変更）による感度分析
- Claude Code の厳格さがルールの意図に合致しているなら、文面強化ではなく Cursor / Codex 側の adapter で補完

!! GATE: Stage 1 の各 Step の選択肢を決定してから Stage 2 に進む

### Stage 2: Agent Adapter 設計

Phase 1 findings のうち、ツール固有の問題を adapter で吸収する。

#### Step 4: Codex Agent Adapter の設計

**問題**: Codex の Default mode（即実行前提）が canonical/rules のワークフロー制御系ルール（implementation-gate, decision-pacing）と構造的に衝突する。

**検討する選択肢**:

| 選択肢 | 内容 | リスク |
|--------|------|--------|
| A. AGENTS.md にモード指定を追加 | `collaboration_mode: plan` を推奨/強制する記述 | Codex がモード指定を尊重するか未検証 |
| B. ワークフロー制御ルールの Codex 向けリフレーズ | Default mode の語彙に合わせて「実行前に必ず確認を表示」と直接指示 | 正本との乖離を adapter で管理するコスト |
| C. Codex 向け別ルールセット | ワークフロー制御系のみ Codex 用に特殊化 | 正本 vs adapter の二重管理リスク |
| D. 権限レイヤーとの統合 | Epic #38 コメント（2026-04-07）の権限レイヤー設計と合わせて検討 | スコープ拡大 |

**関連**: Epic #38 コメント「Codex 権限レイヤーに関する方向性メモ」で行動原則と権限を分離する方針が示されている。

#### Step 5: 「計画フェーズ = Plan mode」の Agent Adapter 紐づけ

Step 2 で B を採用した場合、各ツールの adapter に以下を追加:

- **Cursor**: User Rules またはルール前文に `計画フェーズ → Plan mode への切り替えを意味する` を明記
- **Claude Code**: `.claude/rules/` 内の adapter ルールで Plan mode トリガーの補助
- **Codex**: AGENTS.md 内に `計画フェーズ → plan collaboration_mode での応答を意味する` を明記

#### Step 6: スキル/コマンドの Codex 向け発見性改善

[#64](https://github.com/stlwolf/ai-development-hub/issues/64) の結果に依存。ロード検証の結果を踏まえて:

- Codex が AGENTS.md 経由でスキルを発見できるか
- rulesync の Simulated Features パターン（AGENTS.md にコマンド・スキルを命令として埋め込む）の適用可否
- Epic #38 コメントの既知問題（コミットログ英語化、リンク形式の不備等）への対処

!! GATE: Stage 2 の各 Step の方針をレビューしてから Stage 3 に進む

### Stage 3: Automation Surface の強化検討

ルール層・adapter 層では解決しきれない問題に対する仕組みでの補完。

#### Step 7: 行動原則系ルールの強制力を補完するフック設計

**問題**: Evidence First の深度、探索の粘り強さ等の「連続値」系ルールはルール文面だけでは検証・強制が困難。

**検討する仕組み**:

| 仕組み | 対象ルール | 実現可能性 |
|--------|-----------|-----------|
| pre-edit フック: 「Read 系コマンドの実行有無」を確認 | Evidence First, execution-policy | Cursor hooks で実装可能。Claude Code / Codex は hooks 仕様が異なる |
| task-complete フック: 「計画フェーズを経たか」のチェック | implementation-gate | [#24](https://github.com/stlwolf/ai-development-hub/issues/24) H-7 と連携 |
| advisory フック: 「スコープ拡大の警告」 | Minimal Scope | notification 型で非ブロック |

**依存**: [#24](https://github.com/stlwolf/ai-development-hub/issues/24)（フック拡充エピック）の進捗。3ツール間のフック仕様差異（Phase 0 調査済み）を考慮。

#### Step 8: sync.sh の改善検討

Epic #38 の rulesync 調査で抽出した設計パターンの適用:

| パターン | 概要 | 適用検討 |
|---------|------|---------|
| frontmatter ルーティング | `.md` の YAML frontmatter で配置先を制御 | sync.sh で1ファイル → 複数ターゲット出し分け |
| `--check` モード | 展開結果が最新か diff チェック | `sync.sh --check` で CI/手動検証 |
| Simulated Features | ネイティブ未対応ツールにルール埋め込みで疑似実装 | Codex AGENTS.md にスキル/コマンドの疑似実装を自動生成 |

!! GATE: Automation Surface の設計方針と #24 / #19 との依存関係を確認

### Stage 4: 検証と Issue 分解

#### Step 9: 改修案の動的検証

Phase 1 で使用した3シナリオ（`docs/plans/issue#63/2026-04-12-rules-verification-scenarios.md`）を改修適用後に再実行し、遵守度の変化を測定する。

- 検証環境は Phase 1 と同一（`/tmp/rules-test-project/`）
- シナリオ追加が必要な場合は設計してから実行
- 改修前後の比較表を作成

#### Step 10: 実行 Issue の起票

Stage 1-3 の確定した改修案を、ファイル単位またはテーマ単位の Issue に分解して起票する。各 Issue に:

- 対象ファイル
- 変更内容（minimal diff の方向）
- 行き先判定（Core Canonical / Agent Adapter / Automation Surface）
- 検証方法

## 成果物

- [ ] Core Canonical の改修 PR（implementation-gate 再設計 + 文面改善）
- [ ] Agent Adapter の設計ドキュメント（少なくとも Codex adapter）
- [ ] Automation Surface の改善提案（フック設計 + sync.sh 改善案）
- [ ] 改修後の動的検証結果
- [ ] 実行 Issue の起票（必要分）

## 完了条件

- [ ] Phase 1 申し送り 6 項目すべてに対して、改修案 or 「対処しない」判断が出ている
- [ ] 各改修案に行き先判定（Core Canonical / Agent Adapter / Automation Surface）がある
- [ ] 動的検証で改修前後の遵守度比較ができている
- [ ] 実行 Issue が起票されている（改修案のうち採用されたもの）
- [ ] Epic #38 に Phase 2 完了報告がコメントされている

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| implementation-gate の文面強化だけでは効かない | 到達度が変わらず Phase 3（フック層）に持ち越し | Step 1 で段階的アプローチ（D）を採用し、検証で判断 |
| Codex の Default mode が adapter でも制御不能 | Codex のみ到達度が低いまま | 権限レイヤー + collaboration_mode 強制を合わせて検証。最悪はオーケストレーション層（#19）依存 |
| #64 の結果が Stage 2 の前提を変える | Step 6 の設計やり直し | #64 を先行 or 並行で進め、結果を Stage 2 GATE で統合 |
| フック基盤が3ツールで非対称 | Step 7 の適用範囲が Cursor に偏る | 共通で使える仕組み（sync --check 等）を優先し、ツール固有フックは adapter で個別対応 |

## スコープ外

- オーケストレーションツール本体の設計・実装（[#19](https://github.com/stlwolf/ai-development-hub/issues/19)）
- canonical/rules に新規ルールを追加する作業（既存ルールの改修のみ）
- 3ツール以外（opencode 等）への展開
- Phase 0 / Phase 1 のやり直し

## 参照

- [基準文書](docs/research/2026-04-02-canonical-cross-agent-optimization-framework.md): 2x3 マトリクス・判定ルール・実行順序
- [Phase 0 調査](docs/research/2026-04-12-cross-agent-rules-skills-config-survey.md): 3ツール仕様比較
- [Phase 1 検証結果](docs/plans/issue#63/2026-04-12-rules-verification-results.md): 動的検証の findings
- [ハーネス現状評価](docs/research/harness-engineering/current-state-assessment.md): ギャップ分析
- [Epic #38 コメント](https://github.com/stlwolf/ai-development-hub/issues/38): rulesync 知見・Codex 権限メモ・Phase 1 議論
- [#24](https://github.com/stlwolf/ai-development-hub/issues/24): フック拡充エピック
- [#19](https://github.com/stlwolf/ai-development-hub/issues/19): オーケストレーションツール MVP

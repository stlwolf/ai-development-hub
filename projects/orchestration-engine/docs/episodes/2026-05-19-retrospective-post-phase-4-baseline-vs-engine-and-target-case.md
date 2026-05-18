---
id: "01KRY2HZ2XJZ3T8S8W6JNTATQ9"
title: "Post-Phase 4 振り返り — baseline vs engine 実運用レベル比較 + target case (EC2→ECS / IaC 化) 検討"
date: 2026-05-19
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 完了直後の振り返り (本 Episode は Step 単位ではなくイベント単位の記録)"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/104"
    reason: "Step 4-5 PR (本振り返りの直前に merge、Epic #19 close の節目)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md"
    reason: "Phase 5 direction KickOff (status: draft、本振り返りの content を Phase 5 Discussion 起草時の入力資料として再利用予定)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-5-implementation.md"
    reason: "Step 4-5 Episode (Phase 4 全体振り返りを含む、本振り返りはその後続イベント記録)"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "Phase 4 完了報告 §11 (本振り返りの設計判断は §11.4 派生 Issue + §11.3 観察事実と連動)"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "Step 4-4 Episode (実機 smoke の唯一の成功例、本振り返り §2 で参照)"
tags: [orchestration, post-phase-4, retrospective, baseline-comparison, target-case, ec2-ecs, iac, single-agent-vs-multi-agent]
---

# Post-Phase 4 振り返り — baseline vs engine 実運用レベル比較 + target case 検討

> Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 MVP 完了 ([PR #104](https://github.com/stlwolf/ai-development-hub/pull/104) merge) の直後 (2026-05-19) に発生した、orchestration-engine の実運用レベルと next phase の方向感に関する追加議論の記録。Step 単位ではなくイベント単位の Episode (Step 4-1 の `2026-05-14-episode-so-compare-step-4-1-design-review.md` と同パターン)。

> **本振り返りの位置付け**: Phase 5 direction KickOff (`status: draft`) の §6 「ゴール / 用途の具体化」を **さらに掘り下げる入力資料**。Phase 5 着手時の Discussion 起草で参照される想定。

## 文脈

- Step 4-5 PR #104 merge 完了、Epic #19 close 直後
- Phase 4 MVP は実機 smoke (2026-05-18 `.tmp_smoke_20260518-034228`) で 1 サイクル E2E 完走を 1 回だけ実証
- Phase 5 direction KickOff (draft) で「ゴール / 用途未確定」「Path α' (実運用を見越した MVP 拡張) が暫定意向」「派生 Issue は本質性で仕分け」が記録されたが、**具体的な target case が見えていない** 状態だった
- 本振り返りで **target case = サービス開発での EC2 → ECS + IaC 化** が user から示され、必要な engine 拡張の輪郭が見えた

## 1. 実サイクルの精度所感

### 構造判定面: ほぼ完璧

- audit 6 種類全 emit、verification_summary `protocol_errors=0 / timeouts=0`、check_cycle 4+2 全 PASS
- 1 サイクル所要 ~3 分 (target 58s + reviewer 1m47s + engine overhead 数秒)
- ただし「mock では捕捉できない設計バグ」(viewport-only) は 1 回目 smoke で初検出、**実機検証なしには成立しなかった完成度**

### target 精度 (cursor-agent / composer-2): 高い、ただし指示の具体性依存

- task description どおり 4 ファイル編集を完全に完遂 (shellcheck PASS、test_cleanup +4 assertion)
- composer-2 が "engine 自身のコード改修を engine 経由で行う" という dogfood ケースを完走できた
- ただし指示が **「ファイル名 + 関数名 + 行レベルの位置指示」まで具体化されていた** のが効いている。抽象指示で同じ精度が出るかは未検証

### reviewer 精度 (claude / sonnet-4-6): 概ね妥当だが warn 寄りに傾く

- 結果は `@@OE_VERIFY:warn` で strict regex 適合
- review 内容は的確 (Spec Compliant 判定 + F7 known gap = verify-inputs に shellcheck 証跡が無い問題を指摘)
- ただし target は task description どおり完遂しているのに warn 判定。Step 4-4 ADR の mapping 表「Spec Compliant + non-trivial Recommendations → warn」仕様どおりだが、**運用上 warn 連発リスクあり**

### 観察された精度の弱点 = 派生 Issue とほぼ 1:1

| 観察 | 関連派生 Issue |
|---|---|
| viewport-only な capture | (Phase C.5 で修正済) + 長文化対応 [#98](https://github.com/stlwolf/ai-development-hub/issues/98) (target 側統一) |
| outputs[] が空で reviewer が「証跡不足」と warn 判定 | [#92](https://github.com/stlwolf/ai-development-hub/issues/92) (KVS outputs[] 拡張) |
| reviewer が markdown 引用で marker 文字列偶然一致 | [#101](https://github.com/stlwolf/ai-development-hub/issues/101) (false-positive 抑制) |
| scan_log_file の boundary case | [#100](https://github.com/stlwolf/ai-development-hub/issues/100) (単体テスト追加) |
| `_oe_strip_ansi` 重複 | [#102](https://github.com/stlwolf/ai-development-hub/issues/102) (共通化) |

## 2. 単一 agent + tool 割り振りの 3 モデル評価

orchestration-engine が採用する multi-agent + 別 process 設計を **単一 agent + tool 割り振り** で代替できるかの評価。

### 現状 (multi-agent + 別 process) が確保しているもの

- **Cross-CLI independence**: cursor vs claude で実装 / レビューが物理的に分離
- **Cross-model independence**: 異なるモデルで adversarial 性を担保
- **Structural assertion**: engine 側の audit / KVS / circuit breaker が agent の自由度と独立
- **Reproducibility**: marker + audit log でサイクル再現可能
- **Cleanup safety**: pane kill + tmp 削除を engine が確実実行 (agent の trap に依存しない)

### 3 モデル評価

| モデル | 概要 | 強み | 弱み | 運用可能性 |
|---|---|---|---|---|
| **M1: Single agent + Bash tool** | 1 agent が Bash でファイル編集 + shellcheck + test + self-review を全部 | シンプル、低 cost、ネイティブ機能で完結 | **self-review bias**、context 圧迫、独立性ゼロ | 簡単な構造的チェックには十分、adversarial review としては機能不全 |
| **M2: Single agent + subagent invocation** | 親 agent が `Agent` tool で別モデルを呼んで review させる | 親が dispatch logic を持つ、subagent で独立性確保 | 親 context が爆発、失敗ハンドリング不安、再現性低 | engine 級の構造保証は捨てるが MVP 軽量化はできる |
| **M3: Single agent + skill switching** | 1 agent が skill を切り替えて role を変える | 最もシンプル、1 process 完結 | M1 + self-review bias、独立視点ゼロ | adversarial review の本質を失う、MVP 以下 |

**結論**: 単一 agent + tool は補完としては機能するが、orchestration-engine の核心目的 (adversarial review + 構造的保証 + 長期記憶) は失われる。

## 3. baseline (Claude Code / Cursor 単体) vs engine の実運用レベル比較

### 実機 smoke で実証したタスクでの直接比較

| 観点 | Claude Code / Cursor 単体 | orchestration-engine |
|---|---|---|
| 所要時間 | ~1-2 分 (user との対話含む) | ~3 分 (target 58s + reviewer 1m47s + overhead) |
| user 介入 | 必須 (実行中に user が確認 / 軌道修正) | ゼロ (`bin/oe --task-file` 起動後は完全自動) |
| レビューの独立性 | 同一 agent (self-review bias) or user が手動 | cursor (composer-2) vs claude (sonnet-4-6) で物理的に分離 |
| 構造化記録 | チャット履歴のみ (検索性低、再現性なし) | audit JSONL + KVS state + ADR / Episode (jq で検索可、再現可能) |
| 失敗ハンドリング | user が気づく | engine の circuit breaker + cleanup が自動 |
| セットアップコスト | ゼロ (Claude Code 起動) | 高 (WezTerm + wez + Bash + 駆動層 doc 準備) |
| コスト (実行 1 回) | claude ~$0.05 程度 (依存) | claude ~$0.05 + cursor サブスク内 (実質変わらず) |
| 複雑な作業 (探索的) | 強み (対話で軌道修正) | 弱み (1-shot task description のみ) |

### Honest assessment

**baseline が勝つ場面**:
- 単発の修正 (「このバグ直して」)
- 探索的タスク (要件が固まっていない、対話で詰める)
- 直接編集 + 即時実行 (オーバーヘッド許容できない)
- **開発者の日常作業の 80〜90% はここに該当**

**engine が勝つ場面**:
- task description が事前に固まっている (バッチ的に書ける)
- 独立した adversarial レビューが要件 (例: 信頼性が高い系の改修、PR 前ゲート)
- 再現性 / 構造化記録が要件 (audit trail、後から再実行・分析)
- 多サイクル運用 (例: 「派生 Issue 1 件ずつ engine で処理する」)
- dogfood (自分の orchestration ツールを自分で使う / 改修する)

### 1 行サマリ

> **baseline 単体で 80% は足りる、残り 20% の "独立 adversarial review が必須" な用途に特化した instrument** という位置付けに収まる。MVP として動くことは実証したが、daily driver にはならない。

engine は **「daily driver」ではなく「specialized instrument」** に近い。Cursor / Claude Code の代替としてではなく、**研究機器** or **特定用途の自動化バッチ処理ツール** として運用するのが現実的。

## 4. Target case の登場 — EC2 → ECS + IaC 化

user から示された target case (= 当面のターゲット対象):

> サービス開発で想定している EC2 の ECS 化および IaC 化のようなものを最初のディスカッションで半自動的にやり、必要な Human in the Loop を挟みながら、最終的にコードベースは全て実装を任せる

### Target case の特性 (orchestration 観点)

- **多段ワークフロー**: 現状把握 → 設計 → 移行計画 → 段階的実装 → 検証 → 本番化
- **複数の HitL 判断ポイント**: IaC ツール選択 (CDK/Terraform/CFn)、移行戦略 (blue-green / rolling / big-bang)、cost 試算、secret 管理方針、rollback 計画
- **長期実行**: 数日〜週単位、session 跨ぎで再開可能性が必要
- **段階的 commit**: 一気に全部やらず Phase 分けで、各 phase で確認
- **production リスク**: 失敗時の影響大、adversarial review が真に必要
- **multi-tool**: AWS CLI、Docker、Terraform / CDK、CloudFormation、kubectl 等の操作
- **コンテキスト膨張**: 既存 EC2 構成、過去 ADR、stage env の差分、関連 commit 履歴

### 現状 MVP との gap

| 要件 | 現状 MVP | gap | 関連 architecture-sketch 議論 |
|---|---|---|---|
| 多段サイクル | 1 cycle (target → review → cleanup) | chain / DAG 対応必要 | §5 で「MVP に含めない: タスクグラフ」と明示 |
| HitL マーカー | 完全自動 (user 介入ゼロ) | `@@OE_NEEDS_HUMAN` 的な停止 + 入力待ち + 再開機構が必要 | §1 ハーネス語彙の「人間ゲート」、§5 で「後のフェーズ」扱い |
| 永続化 / resume | session 単位、wez pane 死亡で終わり | audit / KVS をベースに resume 可能性 | §6 蒸留パイプラインに寄与 |
| コンテキスト管理 | envelope の read_docs を渡すだけ | 既存コードベース全体の構造把握、過去判断の蒸留 | §6「ファイルベース構造化、蒸留パイプライン」が直接対応 |
| 複数 tool 連携 | cursor-agent / claude の sandbox 内のみ | AWS account 操作の安全性 (read-only → 確認後 execute) | §1「ツール管理 / ディスパッチャ」拡張、Step 4-1 ADR `permission-separation` 関連 |
| 検証ループ | 1 reviewer の Compliance Review | deploy 後の動作確認、metric / log 検証、rollback トリガ | §3 adversarial review の本格化 (Plan Review C 完了時) |

**5/6 が「MVP では後のフェーズ」と Phase 3 時点で既に意識されていた**。target case が明確化されたことで、これらの拡張の優先順位が逆算できる。

## 5. Phase 5 ゴール候補との接続 + 拡張ロードマップ

### Phase 5 KickOff §6 のゴール候補 (a〜e) との対応関係 (再評価)

| ゴール候補 | target case との関係 | engine 路線の妥当性 |
|---|---|---|
| (a) 本リポジトリ内 dogfood | △ baseline でも成立、engine の優位性は限定的 | engine 路線の妥当性が弱い |
| (b) 他プロジェクトでの利用 | ◎ target case がここに該当、具体化 = **(b')** | engine 路線の本命 |
| (c) Harness Engineering 寄与 | ◯ engine 自体が「multi-agent orchestration の実験道具」として価値 | 研究成果として |
| (d) Negative Knowledge 基盤 | ◎ engine の audit JSONL は外部記憶として再利用しやすい | baseline には無い構造化記録 |
| (e) その他 | (未明確化) | — |

→ **target case が見えた瞬間、(b') = 「(b) のうち、自身のサービス開発プロジェクト (EC2 → ECS + IaC 化等の大きなタスク) を engine で半自動化する」 がゴール (b) の具体化として浮上**。これが確定すれば、Phase 5 の最重要課題は「(b') を実現するために engine をどう拡張するか」になる。

### 拡張ロードマップの輪郭 (target case を満たすための優先順位)

| 優先 | 拡張項目 | 関連派生 Issue / Step |
|---|---|---|
| 高 | 多段サイクル orchestration (Discussion → Plan → 実装 → 検証 の chain) | engine 拡張、Step 4-4 の 1-cycle を multi-cycle に |
| 高 | HitL マーカー + 永続化 (`@@OE_NEEDS_HUMAN` + resume) | engine 拡張、新規 |
| 高 | コンテキスト蒸留パイプライン (Discussion → KickOff → Plan → Episode → ADR を実際に走らせる) | architecture-sketch §6 と直接対応、Step 4-1 envelope 拡張 |
| 中 | adversarial review v2 (Plan Review 追加、複数 reviewer) | [#92](https://github.com/stlwolf/ai-development-hub/issues/92) と関連 |
| 中 | tool 連携拡張 (AWS / Terraform / Docker 等の dispatcher 拡張) | Step 4-1 ADR `permission-separation` の拡張 |
| 低 | 個別品質改善 | [#98](https://github.com/stlwolf/ai-development-hub/issues/98) / [#99](https://github.com/stlwolf/ai-development-hub/issues/99) / [#100](https://github.com/stlwolf/ai-development-hub/issues/100) / [#101](https://github.com/stlwolf/ai-development-hub/issues/101) / [#102](https://github.com/stlwolf/ai-development-hub/issues/102) |

### 派生 Issue 7 件の本質性仕分けへの影響

target case = EC2 → ECS + IaC 化 を前提とすると:

- **本質寄り (優先度↑)**: [#92](https://github.com/stlwolf/ai-development-hub/issues/92) (検証ゲート v2、reviewer の役割増加対応)、[#98](https://github.com/stlwolf/ai-development-hub/issues/98) (target file redirect 統一、長文化対応)、[#101](https://github.com/stlwolf/ai-development-hub/issues/101) (false-positive marker 抑制、production リスク直結)
- **本質性低 (後回し)**: [#99](https://github.com/stlwolf/ai-development-hub/issues/99) (--task-file 異常系)、[#100](https://github.com/stlwolf/ai-development-hub/issues/100) (scan_log_file 単体テスト)、[#102](https://github.com/stlwolf/ai-development-hub/issues/102) (ANSI 共通化) — 内向きブラッシュアップ
- **中間**: [#93](https://github.com/stlwolf/ai-development-hub/issues/93) 後半 (nonce marker、MVP 後拡張のまま)

Phase 5 direction KickOff §6.2 で「本質的課題から着手」と書いたポリシーが具体化された形。

## 6. 次アクション

本振り返りを Phase 5 着手時の入力資料として、以下の順序で進めることを推奨:

1. **ゴール (b') を Phase 5 Discussion で正式確定** (現状は draft KickOff §6 のスナップショット + 本振り返り §5)
2. (b') 確定後に **派生 Issue 仕分け** (#92 / #98 / #101 を先、残り後回し)
3. **多段サイクル + HitL の Discussion 起草** (engine の根幹拡張、新 Discussion / KickOff / Plan を engine 配下に)
4. 並行して **target case 自体の Discussion (現状把握 + 設計判断) を engine の駆動層 doc サイクルで開始** (= dogfood しながら拡張、最も自然な経路)

特に 4 (= 「target case 自体の Discussion を engine の駆動層 doc で書きながら、engine 不足機能を実装で埋める」) は **dogfood の理想形**。MVP を実運用に近づけるための最も自然な経路。

## 7. 本振り返りの位置付け (将来参照用)

- **時点**: Phase 4 完了 + Step 4-5 PR #104 merge 直後 (2026-05-19)
- **役割**: Phase 5 着手判断時の入力資料 (確定文書ではなく、その時点のスナップショット)
- **再評価のタイミング**: Phase 5 Discussion 起草時に本振り返りを読み返し、当時の認識と現状の乖離を点検

確定 (= status: stable) はあくまで「議論時点での記録として確定」の意味。**結論は Phase 5 Discussion で再評価される前提**。

## 関連リンク

- Phase 5 direction KickOff (本振り返りの主要参照先): [`docs/plans/2026-05-18-kickoff-phase-5-direction.md`](../plans/2026-05-18-kickoff-phase-5-direction.md) (status: draft)
- Step 4-5 Episode (Phase 4 全体振り返り): [`2026-05-18-episode-step-4-5-implementation.md`](2026-05-18-episode-step-4-5-implementation.md)
- Step 4-4 Episode (実機 smoke 唯一の成功事例): [`2026-05-18-episode-step-4-4-implementation.md`](2026-05-18-episode-step-4-4-implementation.md)
- Phase 4 完了報告 (architecture-sketch §11): [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)
- 派生 Issue 7 件 (open): [#92](https://github.com/stlwolf/ai-development-hub/issues/92) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93) / [#98](https://github.com/stlwolf/ai-development-hub/issues/98) / [#99](https://github.com/stlwolf/ai-development-hub/issues/99) / [#100](https://github.com/stlwolf/ai-development-hub/issues/100) / [#101](https://github.com/stlwolf/ai-development-hub/issues/101) / [#102](https://github.com/stlwolf/ai-development-hub/issues/102)
- Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) (Phase 4 完了で closed)
- 関連 Epic (target case 周辺): [#20](https://github.com/stlwolf/ai-development-hub/issues/20) wezterm-ai-mode / [#37](https://github.com/stlwolf/ai-development-hub/issues/37) Harness Engineering / [#62](https://github.com/stlwolf/ai-development-hub/issues/62) Negative Knowledge

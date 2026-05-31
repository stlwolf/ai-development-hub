---
title: "orchestration-engine 経緯の人間用まとめ — 引き継ぎ brief"
date: 2026-05-31
status: draft
purpose: "別スレッド（or Notion 作業）で、orchestration-engine プロジェクトの経緯を人間用に体系化・可視化するための自己完結 brief"
---

## このドキュメントは何か

orchestration-engine の経緯を **人間（＝オーナー本人）確認用** に体系化・可視化する作業の引き継ぎ brief。
別スレッドはこの 1 枚 ＋ `projects/orchestration-engine/README.md` を読めば、前スレッドの会話履歴なしで作業に入れることを意図する（これ自体が engine の dogfood① ＝ 駆動層ドキュメントによるコンテキスト引き継ぎの実践）。

成果物の置き場（Notion / repo doc）と公開範囲は §7 の open decisions で本人が決める。

## 1. なぜ今これをやるか（背景）

- engine は `README.md` で **観測層（Issue/PR）= 人間のスプリント管理・可視化** と役割定義しているが、実際は Issue が 30 件超フラットに溜まり、開発用で**人間が経緯を俯瞰できる状態になっていない**。
- 個々の Discussion / Plan / Episode / ADR で**明文化はされている**が、層が深く分散していて、全体像（どのPhaseで何を決め、今どこにいるか）が一望できない。
- → 欠けているのは「人間向けに機能する観測層」。本作業はそれを Notion 等で作る。

## 2. 成果物イメージ

orchestration-engine の「経緯 + 現在地 + 用語 + Issue 地図」を 1 つの体系化ビューにまとめる。
最低限、次の 5 ブロックを持つ（§4 に目次案）:

1. 経緯 / timeline（Phase 1→4→5）
2. 用語の地図（glossary）← **本 brief §5 に核を転記済み。最優先で価値が高い**
3. アーキテクチャ（観測層/駆動層・3層モデル・選択肢B）
4. Issue マップ（フラットな open issue をテーマ別グルーピング）
5. 検証済み / 未検証 + open questions

## 3. 一番効くのはどこか

- **glossary（§5）と Issue マップ（§6）** が最も欠けていて効く。
- glossary の核は前スレッドで作成済み（§5 に全文）。Issue マップは §6 にドラフトのグルーピング種がある（要精査）。
- 残り（timeline / アーキ / 検証状況）は既存 docs の転記＋再編成が主体。ゼロからではない。

## 4. Notion ページ目次案（たたき台）

```text
orchestration-engine — 経緯と現在地（人間用）
├── 0. 一言サマリ（何を解決する道具で、今どの段階か）
├── 1. Timeline
│     ├── Phase 1–3（自前オーケストレーション構想〜選択肢B確定）
│     ├── Phase 4 MVP（Step 4-0〜4-5、Epic #19 close）← 状態表は README から転記
│     └── Phase 5（パイプライン駆動 + ECS target case、進行中）
├── 2. 用語の地図（glossary）← 本 brief §5 をそのまま
│     ├── dogfood ①②③
│     └── Phase A/B/C（名前空間の衝突）
├── 3. アーキテクチャ
│     ├── 観測層 / 駆動層 の分離
│     ├── 3層コンポーネントモデル（Phase / Component / Role）
│     └── 設計方針（選択肢B / 2リポジトリ分離 / Build to Delete）
├── 4. Issue マップ（テーマ別、§6 のグルーピングを精査して）
├── 5. 検証済み / 未検証（Phase5 discussion §1.1 / §1.2）
└── 6. Open questions と次の一手
```

## 5. 用語の地図（glossary）— 前スレッドで確定済み、そのまま転記可

### 5.1 「dogfood」は 3 つの別物

| 呼称 | 意味 | 主体 | 状態 | 根拠 |
|---|---|---|---|---|
| **① 駆動層 dogfood（プロセス）** | engine 自身の開発を構造化ドキュメント（Discussion→KickOff→Plan→Episode→ADR）の引き継ぎで回す。「新スレッドが docs だけ読んで続行できるか」の検証 | 人間＋CLIエージェント（`oe` は動いてない） | Step 4-0 から常時稼働中 | `README.md` 「観測層と駆動層の分離」「Dogfood 視点」 |
| **② engine-improves-engine dogfood（コード）** | 動いている `oe` で engine 自身のコード改修を駆動する | `oe` バイナリ | 1 回成功済（#109 plan「Phase 5 dogfood の Slice A」） | `docs/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md` §1.1 |
| **③ target-case dogfood（外部）** | `oe` を外部サービスrepo（ECS化）の実作業に使う | `oe` ×別repo | 未着手・Phase 5 の主目標 | #105「target case で dogfood が先」 |

注意点: 「dogfood してる?」の答えは ①YES / ②1回だけ / ③まだ、と三段で返るので矛盾に見える。**別物**として分けること。

### 5.2 「Phase」は 3 つの名前空間が重なっている

| 呼称 | 例 |
|---|---|
| **A. engine ロードマップの Phase** | Phase 4=MVP完了 / Phase 5=パイプライン駆動。さらに 5.1（ドキュメント生成）/ 5.2（インフラコード）に分裂予定 |
| **B. 3層モデルの "Phase" レイヤ**（ランタイム概念） | Design / Implementation / Test / Apply |
| **C. target case（ECS移行）の Phase** | Phase 1設計 / 2ステージング / 3本番 |

#105 の本文内に A・B・C が全部「Phase」として同居している。可視化時は **必ず接頭辞で区別**（例: ロードマップPhase / ランタイムPhase / targetPhase）。

### 5.3 関係性の一行整理

- **Phase 5 = 作るもの（WHAT）**: パイプライン駆動 + 制御ループ（リトライ/エスカレーション/HitLゲート）
- **dogfood②③ = 作り方の方法（HOW）**: 薄く作る→実作業に `oe` を使う→痛んだ所が次に作るコンポーネント（#108）を教える
- **target case（ECS）= 流し込む実作業（FUEL）**: 別repoに隔離
- retrospective §4 推奨経路 = 「Step 5-6（外部workspace）を前倒しして target case を早く触る ＝ dogfood しながら engine 拡張」

## 6. Issue マップ（ドラフトのグルーピング種 — 要精査）

> 2026-05-31 時点の open issue を機械的にテーマ分類した**たたき台**。番号・所属は新スレッドで `gh issue list` を引き直して検証すること。orchestration-engine 本体と canonical 基盤が混在している点が、フラットだと見えない最大の問題。

- **A. orchestration-engine 本体（Phase 5 + 運用品質）**
  - Phase 5: #105（Epic）/ #108（コンポーネント）
  - 通信路 / 出力チャネル: #114（クリーン出力チャネル統一）/ #98（file redirect統一）/ #101（marker偽陽性）/ #102（_oe_strip_ansi共通化）
  - 品質・テスト: #100（_oe_verify単体テスト）/ #99（--task-file異常系）/ #93（reviewer掃除+nonce）/ #92（検証ゲートv2）
  - 実行環境: #111（wez pane フォーカス奪取）
  - 運用隣接: #113（Episode closure 振り返りスキル）
- **B. canonical 基盤 / Harness Engineering**
  - Epic: #37（Harness基盤）/ #38（cross-agent最適化）/ #26（メタデータ基盤）/ #24（フック拡充）/ #35（so-compare改善）
  - 原則・スキル: #75（Exhaustion Before Conclusion）/ #78（コードパス網羅の仮説外部化）/ #77（確定前ゼロベース探索）/ #74（マージ戦略）/ #61（永続化宣言）/ #60（失敗分類）/ #49（テスト戦略）/ #56（質問駆動）/ #76（so-compare選択肢拡張）/ #116（C4図化スキル）
- **C. 他プロジェクト / 環境**
  - #20（wezterm-ai-mode Epic）/ #21（ターミナル環境 Epic）/ #86（Phase 2 dotfiles統合）
- **D. 横断 / アーカイブ**
  - #2（会話ログ保存）

## 7. 新スレッドで本人が決める open decisions

- **置き場**: Notion（本 brief の前提）/ repo doc / 両方。Notion MCP はセッションから利用可（外部書き込みは実行前に確認する運用）。
- **スコープ**: orchestration-engine 本体だけ / canonical 基盤を含む ai-development-hub 全体。§6 のグルーピングは後者寄りで切ってある。
- **公開範囲**: 本人確認用のみ / チーム共有。共有なら表現を整える必要。
- **可視化の手段**: timeline（Phase別）/ 層構造図（観測層・駆動層・3層モデル）/ Issue グルーピング図。図化は #116（C4アーキテクチャ図化スキル）と接続できる。

## 8. 素材マップ（source material）

新スレッドが転記元にすべき一次情報。

- **状態 / ロードマップ**
  - `projects/orchestration-engine/README.md` — 観測層/駆動層、Dogfood 視点、Phase 4 状態表（Step 4-0〜4-5）、Phase 5 方向感
  - `projects/orchestration-research/synthesis/architecture-sketch.md` §11 — Phase 4 完了報告（frozen）
- **Discussion（7件）**: `projects/orchestration-engine/docs/discussions/`
  - 特に `2026-05-13-...engine-scope-and-goals.md`（スコープ・ゴール・論点10=dogfood化判断）、`2026-05-19-...phase-5-pipeline-driven-ecs-target.md`（§1.1/1.2 検証済/未検証、§10 Step分解、§4推奨経路）、`2026-05-30-...clean-output-channel...md`（通信路、#114系）
- **Plan / KickOff**: `projects/orchestration-engine/docs/plans/`（Step 4-1〜4-5 + `2026-05-18-kickoff-phase-5-direction.md` + `2026-05-26-plan-issue-109-oe-capture-attach.md`）
- **ADR（5件）**: `projects/orchestration-engine/docs/decisions/`（cleanup-strategy / issue-20-phase-convergence / permission-separation-mvp / verification-gate-design / reviewer-output-file-redirect）
- **Episode（約20件）**: `projects/orchestration-engine/docs/episodes/`（特に `2026-05-19-retrospective-post-phase-4-baseline-vs-engine-and-target-case.md`）
- **制御ループの課題（3月時点）**: `docs/draft/orchestration-control-loop-challenges.md`
- **直近の通信路スレッド（本日分の関連）**: `docs/research/oss-sessions/2026-05-31-agmsg.md` / `docs/research/2026-05-31-agmsg-agent-messaging-patterns.md`（agmsg と #114 の構造同型・配送セマンティクス軸。#105/#114 にコメント済み）

## 9. 進め方メモ（新スレッド向け）

1. まず `projects/orchestration-engine/README.md` ＋ 本 brief を読む。これだけで全体像に入れる想定。
2. §7 の open decisions を先に確定（置き場・スコープ・公開範囲）。
3. §4 目次案をベースに、§5 glossary をそのまま据える → §6 Issue マップを `gh issue list` で検証 → §8 素材から timeline / アーキ / 検証状況を転記。
4. 図化が要るなら #116（C4図化スキル）を参照。
5. engine の駆動層規律（`feedback_engine_driving_layer_flow`: Episode必須 + so-compareゲート）に照らすと、この「人間用まとめ」は観測層側の成果物。engine コード変更は伴わないので Episode 化は任意。

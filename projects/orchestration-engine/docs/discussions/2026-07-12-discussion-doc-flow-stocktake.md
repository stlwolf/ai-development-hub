---
id: "01KXANZWQ7C5Z85YZ54AFJ2JKX"
title: "ドキュメントフロー棚卸し — 蒸留5段の当初想定 vs 実態、作業層の公認とガードレール枠"
date: 2026-07-12
type: discussion
status: stable
related:
  - type: spec
    ref: ../../../../docs/specs/document-format.md
    reason: "棚卸し対象の正本定義（蒸留5段）。本 discussion の DJ-2 が v2 改訂の入力になる"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/217"
    reason: "episode コンテンツ基準 — 本棚卸しの episode 品質軸が合流する既存 issue"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/194"
    reason: "実装SO の artifact 化 — 棚卸しで oe-review ログ 0 件（G7）を確認し実証された既存 issue"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/185"
    reason: "episode lifecycle 機械制御 — raw log を curated と別レイヤーとする方針の置き場"
tags: [doc-flow, distillation, guardrail, stocktake, question-driven-design]
---

# ドキュメントフロー棚卸し — 当初想定 vs 実態、作業層の公認とガードレール枠

cockpit 統括セッション上で owner と question-driven-design により実施（2026-07-12）。事実インベントリは Explore 子のリポジトリ全域走査 + 統括の直接確認に基づく（件数は走査時点）。

## 1. 背景 / 問い

4層（実際は5段）ドキュメントフローを運用して約2ヶ月。個別フォーマットの矯正スキル（spec-card / kickoff-to-plan / episode-retrospective 等）は揃ってきたが、**フロー全体を制御・強制する仕組みが無い**。現状は統括（親セッション）が委譲のたびに手書きの kick 文書へフロー規律を埋め込むことで擬似的に矯正している。並列セッション・複数サービス開発へスケールする前に、(a) 当初想定どおり動いている部分、(b) 後から出た課題、(c) 改善点を全体で棚卸しし、フロー制御の「枠」を外部化する設計判断を行う。

## 2. 当初想定（正本定義）

- `docs/specs/document-format.md` が正本。**蒸留5段** discussion → kickoff → plan → episode → decision(ADR)、全て committed。frontmatter 必須5項（id/title/date/type/status）+ ULID + 命名規約 + status enum。
- raw log 層は**正本に未定義**（projects 側の `docs/raw-logs/` は .gitignore で実体除外の運用が既にある）。
- 正本自体が `status: draft` のまま約3ヶ月（「MVP 検証後 stable 昇格予定」の記載のまま）。

## 3. 実態（インベントリ・2026-07-12 走査）

### 3.1 committed 側（engine が主戦場）— 蒸留5段は機能している

| 層 | 件数 | 日付範囲 | 所見 |
|---|---|---|---|
| discussion | 15 | 05-13〜06-29 | 継続。rally-log 1本（46k）が committed raw log 相当の唯一の例外 |
| kickoff | 6 | 05-13〜**05-18 で停止** | 以降の kickoff は `.oe/` へ移住（G3） |
| plan | 12 | 05-13〜07-11 | 継続 |
| episode | 53 | 05-14〜07-11 | 最多層・安定稼働 |
| decision | 12 | 05-14〜07-10 | 蒸留の最終成果。episode→decision の相互 related リンク率はざっくり 13〜19%（G4） |

### 3.2 uncommitted 側 — 「作業層」が自然発生

- メイン worktree `.oe/`: 36 md。kickoff(委譲用) 13 / handoff 5 / issue 下書き 5 / so-prompt 2 / plan 1 / claim 1 / 監査ワークベンチ 8 / succession board 1。**frontmatter 付きは 3本のみ**（G5）。
- 別 worktree（#238 設計）`.oe/`: proposal 2本（27k/32k の設計級文書）/ plan-stage1（35k）/ report / SO 結果 — **git の外に置かれたまま**。
- `tmp/`: oe-refute ログ 11 dir / so-compare 系 26 / arena 25。**oe-review ログは 0 件**（G7 → #194 の実証）。

## 4. 乖離と発見

| # | 発見 | 内容 |
|---|---|---|
| G1 | raw log 層が定義に無い | committed 実体は rally-log 1本のみ。raw-logs/ は gitignore 運用。#185 の「raw-log は curated と別レイヤー」方針が受け皿 |
| G2 | 定義に無い型が実在 | report / proposal / claim / handoff / board / so-prompt — すべて `.oe/`（作業層）に繁殖 |
| G3 | kickoff の生成場所が定義と乖離 | 05-18 以降 committed に kickoff が作られず `.oe/` に 13本。配置先表と実運用の不一致 |
| G4 | episode→decision 昇格率 13〜19% | 全昇格が正ではないが、昇格判断の痕跡が無い episode が多数 |
| G5 | 作業層は format 規律の外 | `.oe/` 36本中 frontmatter 3本。spec-card の射程外で運用されている |
| G6 | 正本が draft のまま | document-format.md が3ヶ月 status: draft |
| G7 | 実装SO の痕跡が残らない | oe-review ログ 0 件（oe-refute は 11）。#194（diff バインドの識別可能アーティファクト化）の実証 |
| N1 | **「kickoff」の名前被り**（owner 指摘） | (a) 蒸留フローの kickoff 層（設計文書・committed。plan 相当の内容を持つ個体もあり層境界が曖昧）と (b) 委譲用 kick 文書（子への引き渡し指示書・`.oe/`）は**別物が同名を共有**している。G3 の「移住」の実態は大半が (b) であり、型を分離しないと棚卸しも規約も混線する |
| N2 | フロー全体の強制系が無い | 遷移ごとの個別スキルと統括の行儀のみ。rule / hook にフロー強制は存在しない（本棚卸しの動機） |

## 5. 評価（当初想定 vs 実態の判定）

- **機能しているもの**: committed 蒸留5段の後半（plan → episode → decision）。episode 53本は capture 層として安定。個別フォーマットスキルも効いている。
- **合理的進化（欠陥ではない）**: 作業層（`.oe/`）の自然発生。委譲 kick・report・board は machine-local な使い捨て情報（pane 番号・絶対パス）を含み、全 commit はノイズと手間。**分化そのものは正しい**。
- **実害（課題）**: (1) 作業層に落ちた**設計級コンテンツ（proposal 27k/32k 等）が昇格されず git の外に滞留**。(2) 名前被り（N1）による混線。(3) フロー全体を見張る仕組みが無く、規律が統括の記憶と行儀に依存 — 統括は使い捨て（#238）なのに、フロー制御が統括の暗黙知に載っている矛盾。

## 6. 決定事項（owner 合意・2026-07-12）

- **DJ-1**: 本棚卸しの正本はこの discussion doc として commit する（issue 群はここを参照する薄い単位に）。
- **DJ-2**: **2層構造を公認**する。committed 蒸留5段 + machine-local 作業層（`.oe/`）。作業層の型名は蒸留フローと**分離**（委譲文書を「kickoff」と呼ばない — 改名は v2 改訂で確定）。**設計級コンテンツが作業層に生まれたら蒸留フローへ昇格して commit する義務**を規約化する。
- **DJ-3**: **ガードレール枠 v0 = スキル + 固定テンプレ**。内容: フロー全体地図（5段+作業層+昇格規則）/ 委譲 kick 文書に必ず入れる固定節（plan-first・episode 義務・昇格規則・参照ポインタ）のテンプレ / 新 repo cold-start 手順。まず soft で運用し、効いた節だけ oe-delegate の機械注入 → hook へ段階 hard 化（エンジンへの本組み込みは将来）。
- **DJ-4**: issue 分割は新規3本 + 既存接続（#217 / #194 / #185）。

## 6.1 追補: フロー詳細規定の合意（同日・第2ラウンド QDD）

棚卸し後、owner から「フロー自体をもっと細かく規定したい」との方向が出たため、同セッションで QDD を継続。以下を #249（v2 改訂）への owner 承認スケルトンとして確定した。

- **DJ-5（置き場）**: 遷移規則・ゲート配置・ライフサイクル規範は **document-format.md v2 に統合**（format + process の1本。層定義と遷移規則は密結合であり、spec の本数を増やさない）。
- **DJ-6（遷移規則）**: タスク種別 → 入口層の表 + **省略条件の明文化**を v2 に置く。骨格: 設計判断が多い→discussion から（QDD 併用）/ スコープ確定済み実装→plan から / 軽微修正→層なし直実装（episode opt-out 1行可）/ 調査・研究→research ノート or discussion。
- **DJ-7（kickoff 層の去就）**: **kickoff は元々オプションが本来の意図**（文脈上発生したら作る・必ずしも無い）— 規約が明文化していなかっただけであり、v2 で「オプション層 + 使う条件（対話でスコープ確定できない大型 / SO・外部共有への投入時の plan-to-kickoff 変換）」を明文化する。**plan は必須**（実装系タスク。kickoff 経由でも直生成でもよい）。層の廃止はしない（既存 kickoff doc と plan-to-kickoff スキルは壊さない）。
- **DJ-8（ゲート配置）**: フロー上の位置を v2 で図式化する6点 — (1) 設計判断確定前 = predecision-exploration（ゼロベース1回）(2) plan 確定前 = 設計SO（`so.design`）(3) plan→実装 = owner HG（implementation-gate）(4) 実装→PR = 実装SO + テスト実行 + Copilot (5) PR→merge = episode closure（マージ前・後追いは reconstructed 明示）→ owner マージ（HG）(6) merge 後 = issue close 判断（keep-open 明示）+ worktree 掃除（親）+ 昇格判定。ガードレール枠（#248）の固定節はこの配置図を参照する。
- **DJ-9（ライフサイクル）**: 規範（episode はタスク着手時に枠作成・リアルタイム追記原則・closure はマージ前・tier は痕跡価値）は v2 spec に置き、**機械強制（hook・oe 結合）は #185 に残す**（規範と機構の分離）。
- **DJ-10（方向転換の記録）**: 調査で前提が覆った時の記録は**新しい層・義務を作らず**、「覆した先の文書（plan/episode）に discard 記録の1節（何を捨てたか + なぜ）を置く」規範のみとする（reframe-on-stall の reconcile 原則と同一。実践例 = #247 plan §2.1、wez notify episode）。その転換に長期価値があるかの判定は既存の昇格ゲート（episode closure → decision）に任せ、記録時点で判断を迫らない。
- **DJ-11（ガードレールと個別スキルの責務分離・二層構造）**: ガードレール（#248）が持つのは **(a) 要素ドキュメントごとの大原則1行**（plan 必須 / plan は実行可能粒度＝コマンドレベルまで / episode は着手時に枠・リアルタイム追記・closure はマージ前、等）と **(b) 遷移・ゲートごとの「必ず通すスキル」ルーティング表**のみ。**中身の品質基準は個別スキルに委ねる**（spec-card / kickoff-to-plan / adversarial-review / episode-retrospective / predecision-exploration / implementer-contract — 表はほぼ既存スキルで埋まる）。これによりガードレールは薄く安定し、基準は各スキルで独立にイテレートできる。**唯一の穴 = plan 直書き時の本文基準スキル**（kickoff オプション化〔DJ-7〕により plan 直書きが主経路になったため）だが、**今は作らない** — 大原則1行を guardrail 固定節に直書きして運用し、1行で足りないとドッグフードで実証されたら plan-authoring スキルを切る（do-less・#247 と同じ判断構造）。

## 7. 分割 issue

- ガードレール枠 v0 スキル（DJ-3 の実装）→ #248
- document-format.md v2 改訂（DJ-2 の規約化: 作業層公認・型名分離・昇格義務・raw log 位置づけ・draft→stable）→ #249
- 昇格漏れの掃除（#238 proposal 群を discussion へ蒸留 commit → docs/#238 worktree 掃除）→ #250
- 既存接続: episode 品質基準 = #217（owner の追加 issue も合流予定）/ 実装SO artifact 化 = #194（G7 が実証）/ raw log レイヤー = #185

## 8. 保留・未解決

- 委譲文書の新名称（kick / brief / task 等）— v2 改訂（#249）で確定。
- ~~kickoff 層と plan 層の境界曖昧~~ — **解決済（DJ-7・§6.1）**: kickoff はオプション層・plan は必須。
- G4（昇格率）の適正水準 — 全昇格は非目標。episode-retrospective の昇格判定を通す運用が先（#217/#185 側）。
- 強制の hard 化（hook）— v0 スキルの運用実績で「効いた節」を特定してから（#24 hook epic と接続）。
- second-opinion-verification の旧規約（DOCUMENT_CONVENTION v0・report 型）の統一 — v2 改訂の scope 判断に委ねる（優先度低）。

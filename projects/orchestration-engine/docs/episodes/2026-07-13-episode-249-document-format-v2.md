---
id: "01KXBQB8P71EMSA29HCQ65ZQ5B"
title: "#249 episode（heavy）— document-format.md v2 改訂（作業層公認・型名分離 brief・昇格義務・設計SO で肉付けの穴を是正）"
date: 2026-07-13
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/249"
    reason: "本 episode が記録する v2 改訂タスク"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/254"
    reason: "v2 改訂の PR"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md"
    reason: "設計ブリーフ（DJ-2 / DJ-5〜11）。v2 はこのスケルトンの肉付け"
  - type: sibling
    ref: "projects/orchestration-engine/docs/episodes/2026-07-12-episode-250-distill-238-proposals.md"
    reason: "昇格規則の初回実地例（#250）。本 v2 の §13 判定基準の一次材料"
tags: [orchestration, doc-flow, document-format, promotion, rename, brief, design-so, episode, closure, reconstructed, heavy]
---

# #249 episode（heavy）— document-format.md v2 改訂

> **reconstructed**: 本 episode はリアルタイム追記でなく、作業完了後（PR #254 作成後・マージ前）に再構成した。追記ログと同じ証拠価値は持たない。

## Context / なぜ

ドキュメントフロー棚卸し（`2026-07-12-discussion-doc-flow-stocktake.md`・DJ-2）で、実運用が「committed 蒸留5段」と「machine-local 作業層（`.oe/`・gitignored）」の2層に分化したのに正本 `docs/specs/document-format.md` は前者しか定義していない、と確認した。#249 はその乖離を埋める v2 改訂 — 2層構造の公認・委譲文書の型名分離・昇格義務の規約化・遷移/ゲート/ライフサイクル規範の追加・draft→stable。plan-first ゲート付きで親統括 `%173` から委譲された（DJ-5〜11 は owner 承認済み＝肉付けするだけで再議しない）。

## 次の消費者

- **#248（ガードレール枠 v0）の実装者**: v2 の昇格規則1行版（§13.6）・型名分離（brief）・ゲート配置図（§11）を固定節が参照する。
- **フローを回す統括セッション（自分含む）**: §10 遷移規則の判定順と §13 昇格義務が日々の入口選択・closure 判断の根拠になる。
- **engine flag 整合の follow-up 担当**: `--kickoff` flag と `brief` 型名の齟齬（後述 routing）。

## 何が起きたか（事実・失敗・是正）

- **plan-first**: v1 + スケルトン §6/§6.1 + `gh issue view 249` + #250 episode 2本（昇格判断の基準・dead-pointer）+ 実 `.oe/` 使用実態 + SOV 旧規約を読み、`.oe/plan-249-v2.md` に「16節構成案 / 改名候補 / 昇格規則ドラフト / 遷移・ゲート骨子 / scope 判断」を書いて STOP・親へ NEEDS_CONTEXT 報告 → owner 承認（改名=brief 確定）。
- **実装**: v1（382行）を v2（16節）へ改訂。format 機構は残し、frame（§2 2層）を前段・process 規範（§10-14）を後段に追加。id 据え置き・title を format+process 形へ・status draft→stable。
- **設計SO で肉付けの穴を捕捉（是正）**: 弱 `oe-refute --rubric exploration --lanes 3`（audit `20260712174148Z4ADQMYP5GJC`）が **refuted**（3/3 レーン実返却・partial なし・0 なし）。反証対象は肉付けの穴のみ（DJ-5〜11 アーキは範囲外）と claim doc で制約し、全レーンが遵守した。最も刺さった指摘:
  - **ゲート番号の内部不整合**（codex）: §13.1 が「episode closure 時（§11 ゲート6）」と書いていたが、§11 では closure=ゲート5・昇格判定=ゲート6。実行タイミングが merge 前後どちらか読めない**事実誤り**を修正（closure=5 候補洗い出し / 実行=6 掃除前）。
  - **型判定 vs 内容判定の矛盾**（claude/codex/cursor 3社一致）: §13 が対象を内容で、非対象を型名（report/board/handoff）で定義していた。設計級が board/report に混入すると衝突 → 「判定は型でなく内容・混合文書は該当ブロック抽出」へ書き直し。
  - **catch-all trigger の欠落**（3社）: 昇格判定が closure/掃除に錨付き、放棄作業・pane 終了・メイン `.oe/` 未掃除・複数 worktree 分散で発火しない滞留経路。棚卸し自身が #238 proposal 滞留で実害を観測済み → handoff/pane 終了 + 定期棚卸しを catch-all に追加（機械強制は #185）。
  - 他: durable な証拠・知見（negative knowledge）を昇格対象へ拡張 / grep 既出判定の意味的限界と「疑わしきは残す」/ 軽微修正を plan 必須の例外に / 判定順で軸直交を解消 / research ノートの位置づけ / tmp 層の明示。
  - 弱SO ゆえ **1周で reconcile・iterate せず**。material を反映し、意図的 defer は disclose（下記「決定と根拠」）。

## 決定と根拠（棄却した案と棄却理由）

- **委譲文書の型名 = brief**（owner 決定）: ゼロベース探索木で kick / brief / task に加え「語尾修飾で残す」「dispatch/assignment」も列挙。**推奨を brief に**した決め手は、voice 入力（本環境は多用）での弁別が毎日効く恒久コストが、一回性の移行コストに勝る点。kick は移行最小だが音・字面が kickoff に近く N1 を半解決に留める。task は generic すぎ issue/plan と概念衝突。「語尾修飾で残す」は owner が DJ-2/7 で分離を確定済みゆえ除外。→ owner が brief を確定。
- **設計SO の refuted を「1周反映 + defer disclose」で畳んだ**（棄却＝iterate して全穴を潰す）: 弱SO は1周が終了条件。全穴の網羅的解消（例: 全タスク種別の決定表）は DJ-6 が §10 を**骨格**とスコープした範囲を超える → 判定順（5ステップ・迷ったら重い側）で代替し、網羅的決定表は defer と明示。過剰解消はスコープ膨張 + 骨格の意図に反する。
- **意図的 defer（disclose）**: (1) 全タスク種別の網羅的決定表（骨格スコープ・判定順で代替）(2) トリガー・checkpoint の機械強制（#185 / #24）(3) SOV 旧規約統一（§16・別 issue）(4) engine flag 整合（別 issue）。

## わかったこと（W）

- **設計SO は「肉付けの解像度」に効く**: アーキ（DJ）を範囲外に固定した上で穴だけ突かせると、事実誤り（ゲート番号）と起草矛盾（型 vs 内容）という、アーキ論争を持ち込まずに成立する欠陥が3社一致で出た。claim doc で反証範囲を明示的に絞るのが効いた。
- **catch-all の必要性は棚卸しが既に実証していた**: #238 proposal 滞留は「closure/掃除に錨付く trigger では捕捉できない経路」の実例。SO はそれを昇格規則の穴として言語化した＝棚卸しの観測と設計SO が同じ結論に収束（reconcile）。

## 蒸留シグナル（昇格候補）

- Decision 昇格: なし（v2 spec 自体が正本。DJ は承認済み discussion に既出）。
- skill/rule 昇格候補: なし（本件は spec 改訂で、規律は spec に着地済み。#248 が固定節化する）。
- negative knowledge（#62）候補: 「昇格 trigger を closure/掃除だけに錨付けると滞留経路が残る」は転用可能な anti-pattern だが、§13.1 catch-all として spec に着地済み（重複注入を避け routing 先＝spec とする）。

## 残課題 / follow-up routing

- **engine flag 整合**（`oe-delegate` / `oe-send` の `--kickoff` を `brief` 型名へ）: 行き先 = **#255**（surface 済み）。本 PR では移行注記のみ（§3.3 / §16）。子（本タスク）は engine コードを触らない。
- **SOV 旧規約統一**（`DOCUMENT_CONVENTION.md` v0 の canonical 吸収 or deprecate）: 行き先 = **別 issue（優先度低・§16）**。
- **トリガー/checkpoint の機械強制**: 行き先 = **#185 / #24**（規範は v2 spec に着地・機構は defer）。
- **マージ・worktree 掃除**: 行き先 = **親/owner（HG）**。子はやらない。
- 「追わない」宣言: なし（全 follow-up に行き先を付与済み）。

## status

- **stable** / 達成度: **達成**（16節 v2 を実装・改名 brief 確定・弱設計SO 通過（refuted を1周反映）・PR #254 landing）。#249 の core（定義が実態を説明する・型名分離・昇格規則の参照粒度）は達成。マージは親/owner の残アクション（keep-open 判断も owner・HG）。

## Step4（heavy tier 外部チェック）

Step4 辞退: 本サイクルで既に意図的な設計SO（`oe-refute` 3レーン）を doc に当て、その refutal・反映・partial なし・意図的 defer を本 episode と PR #254 に選択的省略なく記録した / 既存チェックで覆った観点: 省略チェック（SO refuted を「何が起きたか」に明示・3社の主要指摘を転記）・routing 網羅（flag/SOV/機械強制/マージ掃除に全て行き先）・evidence anchor（audit id `20260712174148Z4ADQMYP5GJC` を本文 + PR に転記・揮発 tmp/ 依存なし）・back-propagation（SO 指摘を doc 本体へ反映＝反映そのものが back-prop）/ 未実施観点と判断: なし（4観点が本文で自己完結・低リスク。closure 品質の追加 so-compare は同サイクル設計SO と重複ゆえ辞退）。最終的な external eyes は親 `%173` の HG レビューが担う。

## 形式メモ（効果測定・#113）

- チャネル骨格で拾えたもの: 「決定と根拠（棄却案）」に改名の探索木と SO の1周判断が自然に埋まった。「わかったこと」に SO と棚卸しの reconcile が入った。
- 拾えなかったもの: 特になし。
- 皮（KPT/YWT）: 使わず（出力型セクションで足りた）。
- 摩擦: 中。SO 反映で doc 9箇所編集 + episode 再構成。heavy の Step4 辞退定型で摩擦を抑えた（#250 と同じ判断構造）。

---
title: "LLM 検証ディシプリンの方法論的裏付け（CoVe / ALCE / GLEAN ほか）"
date: 2026-06-03
status: research-complete
tags: [research, verification, hallucination, evidence-discipline, llm, citations]
sources:
  - https://arxiv.org/abs/2309.11495
  - https://arxiv.org/abs/2305.14627
  - https://arxiv.org/abs/2210.08726
  - https://arxiv.org/pdf/2603.02798
  - https://arxiv.org/abs/2310.01798
  - https://arxiv.org/pdf/2601.14691
  - https://arxiv.org/abs/2303.17651
  - https://arxiv.org/pdf/2303.11366
  - https://arxiv.org/abs/2203.11171
  - https://elicit.com/solutions/systematic-review
related_ideas:
  - ideas/20260218/hypothesis-inference-ratio-certainty-model.md
next_step:
  trigger: "Issue #128 のルール設計時（evidence-verification-rule 起草）"
  actions: "本ノートの『ルール構成要素の候補』を rule 本文に落とす。特に (1) 検証ステータス3値の ALCE 整合定義、(2) verified=外部ソース照合必須（自己評価で昇格不可）、(3) spot-check は GLEAN 式リスク比例（固定 N は運用ヒューリスティックと明記）、(4) 最終ゲートはソース実体照合（LLM judge 任せ不可）"
  referenced_by: "Issue #128、evidence-verification-rule（新設予定）、docs/research/2026-06-03-research-skill-evidence-discipline.md"
---

# LLM 検証ディシプリンの方法論的裏付け（CoVe / ALCE / GLEAN ほか）

## 動機

リサーチ系スキルの成果に「検証ステータス + 根拠リンク」を導入する [Issue #128](https://github.com/stlwolf/ai-development-hub/issues/128) を、2スキル局所改修ではなく **Evidence First（behavioral-rule §1）を具体化する canonical ルール** へ昇格させる方向の裏付けを、論文・実務事例から収集した。`careful-operations-rule` が Safe Operations を具体化する先例と同型。

> メタ注記（本ノート自身のディシプリン適用）: 以下は委譲リサーチ（general-purpose subagent）の成果を転記したもの。各主張は一次ソース URL 付きだが、**本ノート作成者による独立再検証は未実施**（＝検証ステータスは「ソース提示済み・要 spot-check」）。原文 PDF 値の未確認箇所は明記する。

## 結論

提案中の検証プロトコル（出力側＝主張ごとに検証ステータス+根拠リンク / 消費側＝N件 spot-check）は4観点すべてで一次文献の裏付けがある。特に「主張レベルのソース紐づけ」と「選択的検証」は ALCE・GLEAN・自己訂正の限界研究が直接支持する。一方で「自己検証のみで完結させる」設計には反証があり、外部根拠/オラクルが必要という留保が強く効く。

## 観点1: LLM 自己検証・ハルシネーション抑制

| 名称 | 本質 | プロトコルをどう補強するか | ソース | 鮮度 |
|---|---|---|---|---|
| Chain-of-Verification (CoVe) | 初回ドラフト→検証質問→他文脈に依存せず独立に回答→統合。MultiSpanQA で F1 0.39→0.48 | 「生成」と「事実検証」を分離する設計原理。検証ステータス付与＝この分離のプロトコル化 | https://arxiv.org/abs/2309.11495 | as of 2023-09 |
| Self-Refine | 単一 LLM が自己フィードバックで反復改善。7タスク平均約20pt改善、追加学習不要 | 「出力→自己批評→改訂」ループ。ただし外部根拠なしの self-feedback は留保 | https://arxiv.org/abs/2303.17651 | as of 2023-03 |
| Reflexion | 軌跡と報酬から言語的フィードバックを生成し次試行に反映。重み更新なし | フィードバックを言語化して構造的に残す先行例 | https://arxiv.org/pdf/2303.11366 | as of 2023-03 |
| Self-Consistency | 多様な推論パスをサンプリングし多数決。GSM8K +17.9% 等 | 一致度を信頼度シグナルにする＝spot-check を1件で打ち切らない根拠 | https://arxiv.org/abs/2203.11171 | as of 2022-03 |

未確認: CoVe の Wikidata list-question precision / longform FactScore 具体値は二次解説からは取得できず（本文 PDF 要確認）。確定値は MultiSpanQA F1 +23pt のみ。

## 観点2: 主張レベルの帰属・引用グラウンディング

| 名称 | 本質 | プロトコルをどう補強するか | ソース | 鮮度 |
|---|---|---|---|---|
| ALCE (EMNLP 2023) | 引用付き生成の自動ベンチ。Citation Recall=各 statement が引用に entail されるか / Citation Precision=無関係引用へのペナルティ。最良モデルでも ELI5 の約50%が完全な引用支持を欠く | statement 単位で根拠を貼り recall/precision 二軸で測る発想がそのまま流用可能。`AI要約のみ` は recall<1 に対応 | https://arxiv.org/abs/2305.14627 / https://github.com/princeton-nlp/ALCE | as of 2023-05 |
| RARR (ACL 2023) | 既存出力に主張ごとの根拠を後付け検索→矛盾箇所のみ原文を最小編集して整合 | 検証ステータスを後付けで埋めるワークフローの先例。`一次確認済み`/`Speculation` を機械的に付ける手続き | https://arxiv.org/abs/2210.08726 | as of 2022-10 改訂2023 |

核心 insight: 「引用がある」だけでは不十分で、(a) 引用が主張を entail するか（recall）と (b) 無関係引用で水増ししていないか（precision）を分けて測る。

## 観点3: verifier/critic パターン + リスクベース選択的検証

| 名称 | 本質 | プロトコルをどう補強するか | ソース | 鮮度 |
|---|---|---|---|---|
| GLEAN | 高ステークス検証。推定不確実性が active verification をトリガし、不確実なケースにだけ追加根拠収集（選択的検証） | 選択的検証の正当化の一次根拠。「全件検証は非現実的かつ不要、検証資源を不確実性/ステークスに比例配分」＝spot-check を N件/重要主張に絞る設計 | https://arxiv.org/pdf/2603.02798 | 2026-03 |
| LLM-as-a-judge (groundedness) | 別 LLM が各 assertion をソースに照合し捏造/矛盾を検出 | 消費側 spot-check の運用形。検証者を生成者と分離する原則を支持 | https://www.evidentlyai.com/llm-guide/llm-as-a-judge | as of 2025（二次） |
| 判定者の脆弱性 (Gaming the Judge) | unfaithful な CoT が judge を欺きうる。judge 自体が攻撃面 | 「検証の検証問題」。spot-check をソース実体（URL/file:line）に当てる設計が judge 任せより堅牢 | https://arxiv.org/pdf/2601.14691 | 2026-01 |

## 観点4: 実務事例（production の evidence 強制）

| 名称 | 具体メカニズム | プロトコルをどう補強するか | ソース | 鮮度 |
|---|---|---|---|---|
| Elicit | 全主張に sentence-level citation。体系的レビューは PRISMA-auditable（除外理由・根拠引用を保持）。抽出精度81.4% vs 人間86.7%（有意差なし） | 文単位の根拠紐づけ + 「監査可能」な根拠保持の実例。200論文横断でも主張ごと引用を維持 | https://elicit.com/solutions/systematic-review / https://pmc.ncbi.nlm.nih.gov/articles/PMC11921719/ | as of 2025 |
| Perplexity | RAG でライブ検索、各 statement に番号付き inline citation、ソース矛盾を解消 | 生成と同時に主張へソース紐づけする UX の実運用例 | https://ziptie.dev/blog/how-perplexity-ai-answers-work/（二次） | as of 2026 |
| Attribution Gradients | 引用を段階展開してユーザに批判的精査を促す研究 | 「citation の存在 ≠ 検証の実施」。消費側 spot-check 義務の必要性 | https://arxiv.org/pdf/2510.00361 | as of 2025-10 |

未確認: Perplexity 内部機構のベンダー一次ソースは未取得（事実水準は複数二次で一致）。

## ルール構成要素の候補（evidence-verification-rule 起草用）

### (a) 検証ステータスの語彙設計（ALCE 二軸を畳む）

- `verified（一次確認済み）` ≒ citation recall=1 かつ根拠が statement を entail
- `unverified-summary（AI要約のみ）` ≒ recall<1。ソースは挙がるが entailment 未確認。最良モデルでも約50%がここに落ちる事実が、**デフォルトをこのステータスに置く根拠**
- `speculation` ≒ 根拠ソースなし（RARR の attribution 不能＝編集対象）
- 任意の第4値 `contradicted（要編集）` を RARR に倣い「ソースと矛盾」用に追加余地
- 補強原則（CoVe）: 検証は生成と独立に行う（同一文脈で自己確証しない）

### (b) spot-check の比率/件数

- 文献に普遍的な「N件 / X%」の数値根拠は**存在しない（未確認）**
- 文献が支持するのは決め方の原理: GLEAN＝不確実性/ステークスに比例配分（固定 N でなく「重要主張は必ず + 不確実主張を優先」）、Self-Consistency＝1件で打ち切らない
- 固定比率を置くなら「文献根拠ではなく運用ヒューリスティック」と明記（Evidence First の自己適用）

### (c) 主張-ソース紐づけフォーマット

- statement 単位（段落単位は粗すぎる。ALCE・Elicit とも文単位）
- 各主張に `[ステータス] + 根拠（URL or file:line）`
- precision 観点: 無関係根拠の水増しもペナルティ対象（根拠は多ければ良いではない）

### (d) 選択的検証（部分受容）の正当化

- GLEAN が直接根拠: 全件検証は非現実的かつ不要、検証資源を (1) 不確実性が高い (2) ステークスが高い 主張に比例配分。「部分受容」は手抜きでなくリスクベース資源配分として妥当

## 反証 / 留保

1. **自己検証のみでは劣化しうる（最重要）**: 『LLMs Cannot Self-Correct Reasoning Yet』(Huang+, ICLR'24)。外部フィードバック/オラクルなしの intrinsic self-correction は性能がしばしば劣化。https://arxiv.org/abs/2310.01798 → `verified` は外部ソース実体（URL/file:line）照合を要件にし、自己評価で昇格させない
2. **検証の検証問題（judge が攻撃面）**: 『Gaming the Judge』。https://arxiv.org/pdf/2601.14691 → 消費側 spot-check を別 LLM ジャッジだけにしない。最終ゲートにソース実体への直接照合（人間 or 決定的チェック）を残す
3. **コスト/オーバーヘッド**: CoVe・Self-Refine・Self-Consistency はいずれも追加生成コスト前提。全件一律適用はトークン/レイテンシで割に合わない → (d) 選択的検証がコストへの直接回答
4. **過剰検証の機会費用（Speculation）**: 探索/ドラフト段階に厳格適用すると発散を阻害。文献の直接根拠はないが、成熟度に応じてプロトコル適用を段階化する設計余地を残すのが妥当（decision-pacing 整合）

## 関連リンク

- 取り込み元ノート: docs/research/2026-06-03-research-skill-evidence-discipline.md
- Issue: https://github.com/stlwolf/ai-development-hub/issues/128

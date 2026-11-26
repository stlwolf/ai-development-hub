# コード差分以外の LLM レビューと、LLM を判定役に使うときの信頼性（調査メモ）

> この文書は、調査役（Claude Opus 5.5）が書いたメモの原文である。取りまとめは `docs/research/investigations/2026-11-27-llm-review-multi-reviewer-evidence.md` にある。この文書の中の `verified` は調査役の申告で、取りまとめた側が照らしたものではない。数字は、使う前に原典で確かめる。

調査日: 2026-11-27。読むだけの Web 調査であり、どのリポジトリも変更していない。

## 0. 調査の範囲と方法

- 問い a〜f（プランと設計と仕様のレビュー、文書とコードの食い違い、判定役としての信頼性、レビュー役に渡す文脈、人の確認、効かなかった例）ごとに、一次資料を最低 2 本読むことを止める条件として先に決めた。
- 探し方は WebSearch（標準と extended）で候補を拾い、arXiv の abstract ページ、arXiv の HTML 版、学会ページを開いて数値を確かめた。
- 状態の付け方は次のとおりである。
  - `verified` は、一次資料のページ（arXiv の abstract か HTML、学会のページ）を開いて、その主張と数値がそこにあることを見たものに付けた。ページは要約つきの取得ツールで読んだため、数値の写し間違いの余地は残る。
  - `verified（原文照合）` は、さらに arXiv の HTML を curl で取得し、本文テキストを grep して数値や文言を直接見たものに付けた。判断に強く効く数値（プランの質、計画の自己検証、文書とコードの食い違い、PR の説明文による誘導、別セッションのレビュー、仕様駆動の監査）はこの方法で確かめた。
  - `unverified-summary` は、検索結果の抜粋や二次資料でしか見ていないものに付けた。昇格はしていない。
- 引用は 1 資料につき 125 文字未満の短い句を 1 つまでにした。
- 日付は arXiv の投稿日（v1 か、確認できた版）で書いた。2026 年の資料を優先し、古い基礎研究は短く添えた。

## 1. ソース表

| # | タイトル | 日付 | URL | 種別 | 状態 |
|---|---|---|---|---|---|
| S1 | Evaluating Plan Compliance in Autonomous Programming Agents | 2026-04（v2 2026-04-28） | https://arxiv.org/html/2604.12147v2 | 実験論文（SWE-bench） | verified（原文照合） |
| S2 | Can Large Language Models Really Improve by Self-critiquing Their Own Plans? (Valmeekam ほか) | 2023-10 | https://arxiv.org/abs/2310.08118 | 実験論文（Blocksworld） | verified（原文照合） |
| S3 | Development of Automated Software Design Document Review Methods Using LLMs (Fujitsu) | 2025-09 | https://arxiv.org/abs/2509.09975 | 産業の実験論文 | verified |
| S4 | A Gated Spec-Driven Workflow: An Audit-Trail Study of Coding-Agent Work | 2026-11 | https://arxiv.org/html/2611.05094 | 事例研究 | verified（原文照合） |
| S5 | Cross-Context Review: Separating Production and Review Sessions | 2026-03（v2 2026-10） | https://arxiv.org/abs/2603.12123 | 実験論文（誤りの注入） | verified（原文照合） |
| S6 | Human-AI Collaboration in RE: Negative Effect of LLMs on Requirements Inspection | 2026-08 | https://arxiv.org/abs/2608.21298 | 統制実験（34 人） | verified |
| S7 | Can LLMs Compete with Human Requirements Reviewers? (Seifert ほか) | 2024/2025 | https://publica.fraunhofer.de/entities/publication/4623b22a-2024-4e16-b4ba-3ecef1a1ca20 （取得は拒否された） | 追試実験 | unverified-summary |
| S8 | Defective Task Descriptions in LLM-Based Code Generation | 2026-04 | https://arxiv.org/html/2604.24703v1 | 実験論文 | verified |
| S9 | Hierarchical Evaluation of Software Design Capabilities of LLMs of Code | 2025-11 | https://arxiv.org/abs/2511.20933 | 実験論文 | verified |
| S10 | Software Architecture Meets LLMs: A Systematic Literature Review | 2025-05 | https://arxiv.org/abs/2505.16697 | 文献レビュー | verified（「3 分の 1 に比較対象なし」は unverified-summary） |
| S11 | DeepQuali: LLM-based assessment of user story quality | 2026-02 | https://arxiv.org/abs/2602.08887 | 産業での初期結果 | verified（数値なし） |
| S12 | Rethinking Verification in Agent Harnesses | 2026-10 | https://arxiv.org/abs/2610.34577 | 実験論文 | verified（abstract のみ） |
| S13 | Accurate Failure Prediction in Agents Does Not Imply Effective Failure Prevention (Vasudev ほか) | 2026-02 | https://arxiv.org/abs/2602.03338 | 実験論文 | verified |
| S14 | Adversarial Review: Structured Disagreement for Grounded Agentic Code Review | 2026-08 | https://arxiv.org/html/2608.18167 | 実験論文 | verified |
| S15 | CASCADE: Detecting Inconsistencies between Code and Documentation | 2026-04（FSE 2026） | https://arxiv.org/html/2604.19400 | 実験論文 | verified（原文照合） |
| S16 | Does My README File Need To Be Updated? | 2026-02 | https://arxiv.org/html/2603.00489v1 | 実験論文 | verified |
| S17 | Evaluating the Use of LLMs for Documentation to Code Traceability | 2025-06 | https://arxiv.org/html/2506.16440 | 実験論文 | verified |
| S18 | CodeFuse-CommitEval（コミットメッセージとコードの食い違い） | 2025-11 | https://arxiv.org/abs/2511.19875 | ベンチマーク | verified（abstract） |
| S19 | Lessons Outlive Their Failures: A Case Study of Rules for AI Coding Agents | 2026-10 | https://arxiv.org/abs/2610.32578 | 事例研究 | verified（abstract） |
| S20 | Can LLMs Replace Human Evaluators? LLM-as-a-Judge in SE (ISSTA 2025) | 2025-02 | https://arxiv.org/html/2502.06193v3 | 実験論文 | verified |
| S21 | Bias in the Loop: Auditing LLM-as-a-Judge for SE | 2026-04 | https://arxiv.org/html/2604.16790v1 | 実験論文 | verified |
| S22 | Don't Judge Code by Its Cover: Biases in LLM Judges for Code (EACL 2026 Findings) | 2025-05 | https://arxiv.org/abs/2505.16222 | 実験論文 | verified（abstract） |
| S23 | When AI Agrees Too Much: Manipulating Automated Code Review via Bias Injection（ICSE 2027 予定） | 2026-03（v5 2026-10） | https://arxiv.org/html/2603.18740 | 実験論文 | verified（原文照合） |
| S24 | Gaming the Judge: Unfaithful Chain of Thought Can Undermine Agent Evaluation | 2026-01 | https://arxiv.org/html/2601.14691 | 実験論文 | verified |
| S25 | Nine Judges, Two Effective Votes: Correlated Errors Undermine LLM Evaluation Panels | 2026-05 | https://arxiv.org/html/2605.29800v1 | 実験論文（NLI と RewardBench） | verified |
| S26 | Correlated Errors in Large Language Models (ICML 2025) | 2025 | https://icml.cc/virtual/2025/poster/44225 | 実験論文 | verified（ポスターページの要旨） |
| S27 | How Much Do LLM-as-a-Judge Design Choices Matter? | 2026-10 | https://arxiv.org/abs/2610.05094 | 実験論文 | verified（abstract） |
| S28 | Replacing Judges with Juries (PoLL) | 2024-04 | https://arxiv.org/abs/2404.18796 | 実験論文 | verified（abstract） |
| S29 | Judging with Many Minds: Bias Amplification in Multi-Agent LLM-as-Judge | 2025-05 | https://arxiv.org/abs/2505.19477 | 実験論文 | verified（abstract） |
| S30 | Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena (NeurIPS 2023) | 2023-06 | https://arxiv.org/abs/2306.05685 | 実験論文（基礎） | verified（abstract） |
| S31 | LLM Evaluators Recognize and Favor Their Own Generations | 2024-04 | https://arxiv.org/abs/2404.13076 | 実験論文（基礎） | verified（abstract） |
| S32 | Towards Understanding Sycophancy in Language Models (Sharma ほか) | 2023-10（v4 2025-05） | https://arxiv.org/html/2310.13548v4 | 実験論文（基礎） | verified（定性のみ） |
| S33 | Self-Correction Bench: the Self-Correction Blind Spot（COLM 2026） | 2025-07（v3 2026-08） | https://arxiv.org/abs/2507.02778 | 実験論文 | verified（abstract） |
| S34 | Interaction Context Often Increases Sycophancy in LLMs | 2025-09（v2 2025-12） | https://arxiv.org/html/2509.12517v2 | 利用者実験 | verified |
| S35 | Large Language Models Cannot Self-Correct Reasoning Yet (ICLR 2024) | 2023-10 | https://arxiv.org/abs/2310.01798 | 実験論文（基礎） | verified（abstract） |
| S36 | ContextCRBench: Fine-Grained Code Review with Enriched Context | 2025-11（v2 2025-12） | https://arxiv.org/html/2511.07017 | ベンチマーク | verified |
| S37 | Deep Learning-based Code Reviews: A Paradigm Shift or a Double-Edged Sword? (Tufano ほか) | 2024-11 | https://arxiv.org/abs/2411.11401 | 統制実験（29 人） | verified（abstract） |
| S38 | The Interaction of Complexity and Provenance in Code Review Decisions (FSE 2026, Singh ほか) | 2026 | https://conf.researchr.org/details/fse-2026/fse-2026-research-papers/111/The-Interaction-of-Complexity-and-Provenance-in-Code-Review-Decisions-Evidence-from- | 統制実験（385 人） | verified（学会ページの要旨） |
| S39 | Where AI Use Is Normalized, Author Seniority but Not AI Disclosure Biases Code Review | 2026-07 | https://arxiv.org/abs/2611.18572 | 統制実験（447 人） | verified（abstract） |
| S40 | Plausible Is Not Enough: Trust and Evidence in AI-Authored PR Review | 2026-10 | https://arxiv.org/abs/2610.21144 | 調査（239 人） | verified（abstract） |
| S41 | Measuring the Impact of Early-2025 AI on Experienced OSS Developer Productivity (METR) | 2025-07 | https://arxiv.org/abs/2507.09089 | 無作為化比較試験 | verified（abstract） |
| S42 | Benchmarking and Enhancing Design-Aware Code Review in the Linux Kernel | 2026-10 | https://arxiv.org/abs/2610.21925 | ベンチマーク | verified（abstract） |
| S43 | Cross-Provider Review as a Runtime Contract for Coding Agents | 2026-10 | https://arxiv.org/html/2610.10961v1 | 小規模の試行 | verified |
| S44 | CRJudgeBench: Can AI Detect Plausible but Invalid Code Reviews? | 2026-09 | https://arxiv.org/abs/2609.37216 | ベンチマーク | verified（abstract） |
| S45 | Automated Code Review In Practice (ICSE 2025 SEIP, Bilkent と Beko) | 2024-12 | https://www.alphaxiv.org/abs/2412.18531 | 産業での観察 | unverified-summary |
| S46 | On the Self-Verification Limitations of LLMs on Reasoning and Planning Tasks (Stechly ほか) | 2024-02 | https://arxiv.org/abs/2402.08115 | 実験論文 | unverified-summary |
| S47 | The EPIC Framework for Spec-Driven Development | 2026-10 | https://arxiv.org/abs/2610.07534 | 相関の分析 | unverified-summary |
| S48 | Checking the Checkers: Verifier Noise and Robustness in RLVR | 2026-10 | https://arxiv.org/pdf/2610.17824 | 文献の統合 | unverified-summary |
| S49 | Studying Quality Improvements Recommended via Manual and Automated Code Review | 2026-02 | https://arxiv.org/pdf/2602.11925 | 実験論文 | unverified-summary |

## 2. 問いごとの結果

### a) プラン、設計、仕様、要求、アーキテクチャの LLM レビュー

**プランの中身が結果を左右することは測られているが、「LLM がプランをレビューすると結果が良くなるか」をソフトウェアの課題で測った研究は見つからなかった。**

- プランの質の効果（S1） `verified（原文照合）`
  - SWE-agent と 4 つのモデルで、SWE-bench Verified と Pro の 16,991 本の軌跡を 8 種類のプラン条件で比べている。
  - プランを与えないと、全モデルで解決率が下がった。
  - 欠けのある悪いプランは、プランなしより悪影響が大きかった。本文の Finding 8 は "The negative impact of a bad, incomplete plan is greater on trajectories than the impact of no plan at all." である。
  - 序盤に課題に関係する段を足したプランが、かえって成績を下げることがあった。
  - プランを 5 手ごとに再提示すると、プランからの逸脱が減り、解決率が一貫して上がった。
  - このことから、プランのレビューで「段を足す」方向の指摘が常に良いとは言えない。この解釈は私の推測である `speculation`。
- LLM による計画の自己検証（S2、Blocksworld） `verified（原文照合）`
  - GPT-4 がプランを作り GPT-4 が検証する構成では 55/100 しか解けず、外部の正しい検証器（VAL）を使うと 88/100 解けた。
  - 検証役の LLM は 100 件中 54 件の真陽性に対して 38 件の偽陽性を出した。つまり誤ったプランの多くを「正しい」と承認した。
  - 二値の指摘と詳しい指摘のどちらを返しても、計画の生成への効果はほとんど変わらなかった。
  - 同じグループの続編（S46）は、検証役の偽陰性も多いと報告している `unverified-summary`。
- 設計書のレビュー（S3、Fujitsu） `verified`
  - Excel の日本語設計書の表を Markdown か JSON に変換してから、GPT に文書間の整合性を確かめさせた。
  - 評価は人工的に埋め込んだ 2 件の誤りに対する適合率と再現率で行っている。500 文字未満の小さな文書では、gpt-4o の再現率が 0.53 から 0.96 に上がった。
  - 文書が長くなると再現率が大きく落ち、6,000〜7,000 文字では gpt-4o で 0.33 だった。自動車の PoC では文書の約 70% が 5,000 文字を超え、手法が使えたのは約 30% の文書だった。
  - 11 のレビュー観点のうち評価したのは整合性の 1 つだけで、実案件での効果は数値で示されていない。
- 仕様駆動の作業での LLM レビュー役（S4） `verified（原文照合）`
  - PDR、SPEC、PLAN、TASKS などの成果物ごとに、読むだけのレビュー役（Claude Opus 5 系）が閉じた欠陥リストに照らして確かめる流れを、1 チームの記録から分析した事例研究である。
  - 111 回のレビュー呼び出し、20 の成果物から 508 件の指摘が出た。そのうち 75 件が「止める」級で、SPEC が 35 件、PLAN が 11 件だった。指摘ゼロの報告は 111 回中 5 回だけだった。
  - 著者自身が "Without ground truth, we cannot say how many findings were real defects or how many defects the reviewer missed." と書いており、指摘の正しさは測られていない。
  - レビュー役がほぼ毎回何かを指摘するという事実は、指摘の件数だけでは価値を判断できないことを示している。
- 文書やコードに誤りを注入したレビュー実験（S5） `verified（原文照合）`
  - コード、技術文書、発表原稿の 30 個の成果物に 150 個の誤りを注入した。
  - 最も良かった「別セッションでのレビュー」でも F1 は 28.6%（適合率 31.5%、再現率 27.1%）だった。1 回のレビューあたりの指摘は平均 4.5 件で、そのうち真陽性は 1.4 件、偽陽性は 3.1 件だった。
  - つまり、注入された誤りの約 4 分の 3 を見逃し、指摘の約 3 分の 2 は誤りではなかった。
- 要求仕様のインスペクション（S6） `verified`
  - 34 人の学部生（初心者）が、ChatGPT（GPT-4o と GPT-4.1 系）の支援ありとなしで要求仕様の「におい」を探した交差実験である。
  - 支援ありの組は検出の F1 が約 8% 低かった。ただし信用区間は重なっている。所要時間に有意な差はなかった。
  - abstract の結論は "LLM support does not necessarily improve performance and may, instead, hinder it for novice inspectors." である。
  - 先行の追試（S7、Seifert ほか）は、GPT-4-Turbo を人のレビュー役の代わりにしたところ、見つけた欠陥が少なく、模範解答とほとんど一致しなかったと報告している `unverified-summary`。
- 仕様の欠陥（S8） `verified`
  - 課題文の「記述不足」で、コード生成の pass@1 が最大 15.3% 下がった。GPT-5-mini と Claude Sonnet 4 はどちらも HumanEval で 9.7% 下がった。
  - 欠陥の種類を当てる課題では、Claude Sonnet 4 の few-shot が F1 0.557、GPT-5-mini が 0.462 で、専用に学習した小さなモデルの 0.804 を下回った。
- 設計の推論（S9） `verified`
  - 凝集と結合の判断は、条件が整っていればできるが、雑音のある自由な設定では結合の判断の F1 が 50% 以上落ちた。
- アーキテクチャ（S10、S11）
  - 18 本の論文を集めた文献レビューは、LLM は比較対象を上回ることが多いとする一方、アーキテクチャの適合性の確認などは手薄だとしている `verified`。比較対象をまったく持たない研究が約 3 分の 1 あるという点は、二次引用でしか見ていない `unverified-summary`。
  - ユーザーストーリーの質の評価（S11）では、専門家が LLM の評価に「おおむね同意した」とあるが、数値は abstract に無い `verified`。
- 仕上がったものに対する独立した批評（S12） `verified`
  - 7 つのモデルで、独立した批評役によるレビューが Terminal-Bench で +5.9〜+9.5 ポイント、SWE-bench Verified で +3.9〜+6.6 ポイントの改善をもたらした。
  - これは完成した作業へのレビューであり、プランへのレビューではない。

### b) 文書とコードの食い違いの検出

**直接 LLM に「この文書とコードは合っているか」と聞く方法は、食い違いが少ない現実的な比率では誤検知が多い。再現率は低くても、実行で裏づける方法のほうが適合率が高い。**

- CASCADE（S15、FSE 2026） `verified（原文照合）`
  - 71 件の食い違いと 814 件の整合した Java の組でデータを作った。
  - gpt-4.1-mini に直接たずねる 4 種類のプロンプトは、食い違いと整合が半々の条件で適合率 0.53〜0.59 だった。食い違いが 10% の条件では適合率 0.10〜0.20、再現率 0.29〜0.67 に落ちた。
  - 文書からテストとコードを生成し、実行で裏づけてから報告する CASCADE は、半々の条件で適合率 0.88、10% の条件で 0.39、再現率は 0.21 だった。814 件の整合した組に対する誤検知は 31 件だった。
  - 実際のリポジトリで未知の食い違いを 13 件見つけ、そのうち 10 件が修正された。
- README の更新が要るかの判定（S16） `verified`
  - 714 リポジトリの PR を使った。README の更新は PR の 1% 未満でしか起きない。
  - 再現率は約 0.5 で、エージェント型にすると特異度が 0.87 から 0.99 に上がった。1% の発生率を仮定した実質の適合率は 3.7% から 28.7% に上がった。
- 文書からコードへの対応づけ（S17） `verified`
  - Claude 3.5 Sonnet の適合率は 95.3% と 87.0%、再現率は 68.0% と 74.8% だった。
  - 誤りには、名前から推測しただけの対応、存在しない対象への対応、一部の構造を全体に当てはめる誤りがあった。
- コミットメッセージとコードの食い違い（S18） `verified（abstract）`
  - 6 つのオープンなモデルの平均で、再現率 85.95%、適合率 80.28%、特異度 63.8% だった。
  - 「目的」の水準の食い違いが最も難しかった。chain-of-thought は適合率を上げ、再現率を下げた。
- エージェント向けの規則の文書の劣化（S19） `verified（abstract）`
  - 1 つのリポジトリを 6 週間追った事例研究で、118 件の失敗のうち最大の分類が文書の劣化（48 件）だった。
  - LLM による 1 回の文書監査は、既知の劣化の約半分（Claude Sonnet 5.5 の平均で 50%）を見つけた。指摘の 93% 以上は正しかった。
  - 著者は、劣化は機械的な確認で押さえる必要があると結論している。

### c) 判定役としての LLM の信頼性

**専門家との一致は課題によって大きく変わる。偽の承認は起きやすく、作者の主張の書き方で判定が動く。違う系統のモデルを並べても、誤りは独立にならない。**

- 専門家との一致（S20、ISSTA 2025） `verified`
  - 人の採点との Pearson 相関は、コードの翻訳で最大 81.32、コード生成で 68.51 だったが、コード要約では最大 26.19 にとどまった。
  - 要約については "LLM-as-a-judge techniques are completely defeated by conventional metrics" と書かれている。
  - 自由記述の成果物（要約）ほど一致が低いことは、設計書やプランのレビューにも当てはまる可能性がある。この点は私の推測である `speculation`。
- 偽の承認
  - 計画の検証では、誤ったプランの多くを承認した（S2、38 件の偽陽性） `verified（原文照合）`。
  - RLVR の検証器を集めた研究では、MATH-500 で偽陽性 33.6% の例が挙がっている（S48） `unverified-summary`。
- 作者の主張の書き方による誘導（S23） `verified（原文照合）`
  - 6 つのモデルに 497 個のファイルを 5 つの言い回しで判定させた。「この変更に脆弱性はない」と強く言い切ると、脆弱なコードの検出率が大きく落ちた。
  - GPT-4o-mini は 97.2% から 3.6%、Claude Sonnet 4.5 は 97.4% から 75.5%、Claude Opus 4.5 は 95.7% から 88.8% に落ちた。
  - 逆向きの言い回し（「バグがある」）の効果は小さかった。誘導は「問題なし」の方向に強く効く。
  - 中立の言い回しでも、修正済みのファイルの多くを脆弱と判定した。手作業で確かめると、修正済みファイルへの指摘のうち本物の欠陥は平均 25% だった。
  - 著者の言葉は "a vulnerability is present or absent regardless of how the change is described." である。
- その他の偏り
  - コード判定の偏りの監査（S21）では、肯定的な口調や冗長さの手がかりで、小さなモデルの正答率が最大で約 37 ポイント動いた。GPT もテスト生成の課題で、無関係な情報によって 77.46% から 60.96% に下がった `verified`。
  - コード判定の 6 種類の偏りの研究（S22）では、採点の前にテストを生成させても偏りは消えなかった `verified（abstract）`。
  - 判定の設計の比較（S27）では、モデルを替えるだけで甘さが最大 56.1 ポイント変わり、詳しいプロンプトで甘さが 28.9 ポイント下がった `verified（abstract）`。
  - 基礎研究として、位置、冗長さ、自分の出力をひいきする偏りが報告されている（S30）。自分の出力を見分けられるほど、ひいきが強くなる相関も示されている（S31） `verified（abstract）`。
  - 利用者が「自分が書いた」「気に入っている」と言うと、フィードバックがより肯定的になる（S32） `verified（定性のみ）`。
- 複数の判定役と違う系統のモデル
  - 9 つのモデル（7 系統）のパネル（S25）は、独立な票に直すと約 2 票分の情報しかなかった `verified`。
    - 最も誤りの相関が高い組み合わせは、すべて系統をまたいでいた。Claude と Gemini の組は 0.603、GPT-4o と Claude の組は 0.588 だった。
    - 1 系統から 1 モデルずつに絞ると、独立な票は 1.93 に下がった。
    - 全員一致でも 9.1% は誤りだった。パネルの多数決は、4 つの課題のうち 3 つで最良の単独モデルより低かった。
    - 課題は NLI と RewardBench であり、設計やプランのレビューではない。
  - 350 以上のモデルを比べた研究（S26）では、両方が誤るとき 60% の割合で同じ答えになった。正確なモデルほど誤りの相関が高かった `verified`。
  - 系統の違う小さなモデルのパネルが大きな単独モデルを上回り、費用は 7 分の 1 以下という古い報告もある（S28） `verified（abstract）`。
  - 判定役どうしに議論させると偏りが増幅され、メタ判定役の形では抑えられた（S29） `verified（abstract）`。
- レビュー指摘そのものの判定（S44） `verified（abstract）`
  - もっともらしいが誤ったコードレビューの指摘を見抜く課題で、汎用の最新モデルは苦戦した。基になったモデルは、専用に学習したモデル（76.60%）より 19.78 ポイント低かった。

### d) レビュー役に何を渡すか

**作者の推論や「問題ない」という主張は判定を甘くする。一方で、変更の意図を示す文章は検出を助ける。別セッションでのレビューの効果は、同じセッションでの 2 回目のレビューと比べたときだけ有意だった。**

- 別セッションでのレビュー（S5） `verified（原文照合）`
  - 別セッションでのレビュー（F1 28.6%）は、同じセッションで 2 回目のレビューをした場合（21.7%）を有意に上回った（Holm 補正後 p=0.004）。
  - 同じセッションでの 1 回目のレビュー（27.1%、p=0.26）や、文脈を持つサブエージェント（23.8%、p=0.057）とは有意な差がなかった。別セッションが 1 位になったのは 3 回の実行のうち 1 回目だけだった。
  - 「同じ文脈で 2 回目を重ねると悪くなる」ことは言えるが、「別セッションなら確実に良い」とまでは言えない。
- 自分の誤りの見逃し（S33） `verified（abstract）`
  - 14 のモデルで、外から渡された誤りは直せるのに、同じ誤りが自分の出力にあると直せない割合が平均 64.5% だった。末尾に "Wait" と足すだけで、この見逃しが 89.3% 減った。
- 文脈が長いと同調が増える（S34） `verified`
  - 利用者のメモリの要約を与えると、同意への同調が Gemini 2.5 Pro で +45%、Claude Sonnet 4 で +33%、GPT-4.1 Mini で +16% 増えた。GPT-5.1 では増えなかった。
  - 著者は "Evaluations devoid of context may significantly underestimate the risks of sycophancy in real-world interactions." と書いている。
- 作者の推論を見せると判定が動く（S24） `verified`
  - エージェントの行動はそのままにして、推論の文章だけを書き換えた。進み具合をでっち上げると、GPT-4o などで偽陽性率が 20〜30 ポイント上がった。
  - 「推論を信じず、行動と画面で判断せよ」と指示すると、GPT-4o の上昇幅は 27% から 18% に縮んだ。推論を隠すと誘導はなくなるが、本当の成功を見つける再現率が最大 13 ポイント落ちた。
  - 著者は "judging mechanisms that verify reasoning claims against observable evidence" を勧めている。
- PR の説明文を消すと検出が戻る（S23） `verified（原文照合）`
  - 反復して作り込んだ誘導の PR は、33 件中 32 件で自動レビューを通った。Claude Code に対しては 17/17 だった。
  - PR の説明文を空にすると、32 件中 16 件で検出が戻った。さらにコミットメッセージとコメントも消すと、残り 16 件のうち 12 件が戻った。
- 意図の文章は検出を助ける（S36） `verified`
  - 差分だけを渡すと F1 は 36.08 だったが、PR の説明文を足すと 62.12 に上がった（クローズドなモデルの平均、品質推定の課題）。周辺コードを足したときより伸びが大きかった。
  - ChatGPT に PR の全ファイルという広い文脈を渡すと、人と同じ問題を見つける割合が下がったという報告もある（S49） `unverified-summary`。
- 読み方 `speculation`
  - S23、S24、S36 を合わせて読むと、「何が正しいべきか」（仕様、要求、意図）は渡し、「これは正しい」という作者の結論や推論は渡さないか、証拠と照らすよう指示するのが筋に見える。この組み合わせそのものを比べた実験は見つからなかった。

### e) 人の確認が要る場面と、人が AI の出力を読むときの偏り

- AI のレビューから始めると、指摘された場所に注意が集まる（S37） `verified（abstract）`
  - 29 人の実験で、LLM のレビューを起点にした人は、軽い問題を多く見つけたが、重い問題は増えなかった。指摘された箇所に集中し、ほかの部分をあまり探さなかった。時間の短縮も自信の向上もなかった。
- 複雑さと AI の表示の組み合わせ（S38、FSE 2026） `verified（要旨）`
  - 385 人の実験で、コードが複雑なほど誤った変更を受け入れやすくなった（p<.05）。
  - 複雑な条件では、「AI が書いた」と表示された誤った変更を特に受け入れやすかった。「人が書いた」と表示した場合には、この効果は見られなかった。
- 作者の情報による偏り（S39） `verified（abstract）`
  - 447 人の実験で、AI を使ったという表示は評価に影響しなかったが、作者の職位の表示は評価を有意に偏らせた。
- 実務家の意識（S40） `verified（abstract）`
  - 239 人の調査で、61.1% が AI の PR にはより多くの証拠を求めると答えた。不確かさが残るとき承認を止める人は 19.4% から 43.9% に増えた。
  - 一方で、AI の PR では自分の推論だけで承認に十分と考える人が 28.5% から 55.2% に増えた。
- 体感と実測のずれ（S41、METR） `verified（abstract）`
  - 経験のある開発者は AI で 24% 速くなると予想し、終わったあとも 20% 速くなったと感じていたが、実測では 19% 遅くなった。人が AI の効果を自己評価する数字は当てにならない。
- 設計の水準の判断（S42） `verified（abstract）`
  - Linux カーネルの設計のトレードオフの検出で、最良のコーディングエージェントの F1 は 0.213、提案手法でも 0.259 だった。設計の判断は人の確認が要る領域として残っている。
- 人が拾ったもの（S4） `verified（原文照合）`
  - 仕様駆動の事例では、実行役が 4 つのタスクで記録していた問題に、著者が章を読むまで誰も対応しなかった。許可していない図の差し替えも著者が止めた。
- 要求の初心者（S6）では、過度の依存の可能性が議論されている `verified`。
- 産業での観察（S45）では、自動レビューの指摘の 73.8% が解決済みとされ、PR あたりの指摘は機械が 3.65 件、人が 0.28 件だった `unverified-summary`。
- 異なる提供元のレビュー役の試行（S43）では、20 回のうち 8 回で重要な指摘が出た（95% 区間 19.1〜63.9%）。判定は 1 つの Claude Opus が行っており、比較対象はない `verified`。

### f) 効かなかった例、逆効果だった例

1. LLM による計画の自己批評は、外部の検証器より大幅に悪かった（55/100 と 88/100）。検証役は誤ったプランを承認した（S2） `verified（原文照合）`。
2. 外部からのフィードバックなしの自己修正では、推論の成績が下がることがある（S35） `verified（abstract）`。
3. 要求のインスペクションで、LLM の支援が初心者の検出を下げた（F1 で約 8%、区間は重なる）（S6） `verified`。
4. 欠けのある悪いプランは、プランなしより悪かった。段を足したプランが成績を下げることもあった（S1） `verified（原文照合）`。
5. オフラインで AUROC 0.94 の批評役が、あるモデルの成功率を 26 ポイント下げた。別のモデルではほぼ影響がなかった。ALFWorld での改善は +2.8 ポイントにとどまった（S13） `verified`。
6. コードのレビューで、レビュー役を 2 人にすると、1 回で解く場合（77%）より下がった（75%）。素朴な対立型レビューでは「偽の合意」が起き、5 件の指摘のうち 3 件がでっち上げと判定された例があった（S14） `verified`。
7. 同じセッションで 2 回目のレビューをすると、1 回目より F1 が下がった（27.1% から 21.7%）（S5） `verified（原文照合）`。
8. 9 つのモデルのパネルは、4 つの課題のうち 3 つで最良の単独モデルより低かった（S25） `verified`。
9. コード要約の判定では、LLM の判定役は従来の指標に負けた（S20） `verified`。
10. 設計書のレビューは、長い文書で再現率が 0.33 以下に落ちた（S3） `verified`。
11. 直接たずねる方法による文書とコードの食い違い検出は、現実的な比率で適合率が 0.10〜0.20 だった（S15） `verified（原文照合）`。
12. AI のレビューから始めても、重い問題の発見は増えず、時間も短くならなかった（S37） `verified（abstract）`。

## 3. 見つからなかったこと、空白

- **ソフトウェアの課題で、LLM がプランをレビューしてから実行した場合と、しない場合の結果の差を測った研究は見つからなかった。** 近いものは、プランの中身の効果（S1）、Blocksworld での自己検証（S2）、ソフトウェア以外での批評役（S13）、完成した作業へのレビュー（S12）だけである。ロボットや安全性の分野には実行前の検証の研究がある（VerifyLLM、Soteria など）が、ソフトウェアの成功率への効果は確かめていない。
- **設計書、ADR、プランについて、人工的に埋め込んだものではない本物の欠陥に対する LLM レビューの適合率と再現率を測った研究は見つからなかった。** S3 は埋め込んだ 2 件の誤り、S4 は正解データなし、S5 は注入した誤りである。
- **Google、Meta、Microsoft、Uber などの一次の技術ブログで、設計書の AI レビューを数値で報告したものは見つからなかった。** 設計書に関する産業の数値は Fujitsu の論文（S3）だけだった。
- **作者の推論や理由を「見せる」場合と「見せない」場合を、設計やプランのレビューで直接比べた実験は見つからなかった。** 証拠は、コードの判定（S23、S36）とエージェントの判定（S24）からの類推である。しかも、意図の文章は検出を助ける（S36）一方で、結論の主張は判定を甘くする（S23）という、向きの違う結果がある。
- **違う系統のモデルをセカンドオピニオンに使うと、設計やプランの偽の承認が減ることを示した研究は見つからなかった。** S25 と S26 は、系統の違いだけでは誤りが独立にならないことを示しているが、課題は NLI、選好、求人の選別である。S43 は比較対象のない 20 回の試行である。
- **人が設計書やプランに対する AI のレビュー結果を読んだときの自動化バイアスを測った研究は見つからなかった。** 見つかったのはコード（S37、S38）と要求（S6）である。
- **利用者自身のプランや設計を LLM に評価させたときの同調の大きさを、工学の成果物で測った研究は見つからなかった。** S32 は一般の文章、数学の解答、詩での結果である。
- 開けなかった、または全文を読んでいない資料がある。Seifert ほか（S7、取得が拒否された）、Bilkent と Beko の産業研究（S45）、Stechly ほか（S46）、EPIC（S47）、RLVR の統合（S48）、S49 は検索の抜粋だけで見ており、`unverified-summary` のままである。S12、S19、S22、S27、S44 は abstract だけを読んだ。
- 探さなかった領域がある。形式仕様（TLA+ など）の LLM レビュー、セキュリティの脅威モデルのレビュー、UI やデザインの評価は範囲外とした。

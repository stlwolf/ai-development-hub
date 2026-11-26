# 複数の LLM レビュアーは 1 本のレビューより良いか（測定値の調査）

> この文書は、調査役（Claude Opus 5.5）が書いたメモの原文である。取りまとめは `docs/research/investigations/2026-11-27-llm-review-multi-reviewer-evidence.md` にある。この文書の中の `verified` は調査役の申告で、取りまとめた側が照らしたものではない。数字は、使う前に原典で確かめる。

調査日: 2026-11-27。読むだけの Web 調査で、リポジトリには何も書き込んでいない。

## 結論（1 行）

効いているのは「独立に複数回レビューして、指摘を絞り込む（多数決・検証役・実行による確認）」部分であり、「合意するまで議論や往復を重ねる」部分は、測定ではほぼ上積みが無いか、悪化することが多い。

## 調べ方と確かめた度合い

- 探した範囲: arXiv の論文（2026 年 4〜11 月を優先し、次に 2025 年、土台になる古いものを少し）と、開発元の一次の技術記事（Anthropic・OpenAI・Cursor）。数値の無い宣伝記事は外した。
- 止める条件（調査前に決めたもの）: 小問 a〜d のそれぞれに、一次資料で数値を確かめた出典が 3 本以上あり、肯定側と否定側の両方が入っていること。
- 状態の札:
  - `verified` は、一次資料のページを開いて数値や文を見たもの。確かめ方を 2 段に分けた。
    - 「raw」: ページを curl で取得し、本文の文字列を grep で直接照合した（9 本）。
    - 「WebFetch」: WebFetch でページを開いたが、抜き出しは要約用の小さなモデルが行った。数値の取り違えの余地が少し残る。
  - `unverified-summary` は、検索結果の要約や二次資料だけで、一次資料で数値を確かめていないもの。
- 多くの論文は abstract のページしか読んでいない。本文の表まで読んだものは表の「範囲」欄に書いた。

## 出典一覧

| ID | タイトル | 日付 | URL | 種類 | 状態（確かめ方・読んだ範囲） |
|---|---|---|---|---|---|
| S1 | Bigger Isn't Always Better: A Comparative Evaluation of LLMs for Automated Code Review | 2026-04 | https://arxiv.org/html/2606.15689v1 | 論文（preprint） | verified（raw・本文） |
| S2 | SWR-Bench: Assessing LLM Performance in Real-World Code Review Comment Generation | v1 2025-09 / v2 2026-06（FSE 2026） | https://arxiv.org/html/2509.01494v2 | 論文 | verified（raw・本文） |
| S3 | Cross-Model LLM Code Review: Should you use Claude to review Codex or vice versa? | 2026-07 | https://arxiv.org/html/2607.21656v1 | 論文（Agentic SE @ KDD'26） | verified（raw・本文） |
| S4 | A Single LLM Is an Incomplete Code Reviewer（Zenodo preprint、単著、1 組織の事例） | 2026-06 | https://zenodo.org/records/20519585 | preprint | verified（raw・abstract） |
| S5 | Greptile「Models are worse at reviewing their own code」 | 2026-07-21 | https://www.greptile.com/blog/model-inversion | ベンダーの研究記事 | 方向は verified（WebFetch）。個々の数値は unverified-summary（図の値と条件の対応が取れなかった） |
| S6 | Cursor「Building a better Bugbot」 | 2026-01-15 | https://cursor.com/blog/building-bugbot | 一次の技術記事 | verified（raw） |
| S7 | Anthropic「Bringing Code Review to Claude Code」 | 2026-03-09 | https://claude.com/blog/code-review | 一次の技術記事 | verified（raw） |
| S8 | OpenAI「A Practical Approach to Verifying Code at Scale」 | 2025-12-01 | https://openai.com/safety-alignment/scaling-code-verification/ | 一次の技術記事 | verified（WebFetch） |
| S9 | OpenCodeReview: Determinism over Non-Determinism for Cost-Effective Agent-Based Code Review | 2026-08 | https://arxiv.org/abs/2608.09290 | 論文 | verified（WebFetch・abstract） |
| S10 | Strategic Heterogeneous Multi-Agent Architecture for Cost-Effective Code Vulnerability Detection | 2026-04（AAMAS 2026） | https://arxiv.org/html/2604.21282v1 | 論文 | verified（raw・本文） |
| S11 | MultiVer: Zero-Shot Multi-Agent Vulnerability Detection | 2026-02 | https://arxiv.org/html/2602.17875v1 | 論文 | verified（WebFetch・本文） |
| S12 | Diverse LLMs vs. Vulnerabilities: Who Detects and Fixes Them Better? | 2025-12 | https://arxiv.org/html/2512.12536v1 | 論文 | verified（WebFetch・本文） |
| S13 | Refute-or-Promote: Adversarial Stage-Gated Multi-Agent Review | 2026-04 | https://arxiv.org/abs/2604.19049 | 論文（単著） | verified（WebFetch・abstract） |
| S14 | Debate or Vote: Which Yields Better Decisions in Multi-Agent LLMs? | 2025-08（NeurIPS 2025） | https://arxiv.org/html/2508.17536v2 | 論文 | verified（raw・本文） |
| S15 | Talk Isn't Always Cheap: Understanding Failure Modes in Multi-Agent Debate | 2025-09 | https://arxiv.org/abs/2509.05396 | 論文（workshop） | verified（WebFetch・abstract） |
| S16 | Stop Overvaluing Multi-Agent Debate（旧題 If MAD is the answer…） | 2025-02 / v3 2025-06 | https://arxiv.org/abs/2502.08788 | 論文 | verified（WebFetch・abstract） |
| S17 | PACE: More Agents, More Samples, or More Thinking? | 2026-11 | https://arxiv.org/abs/2611.17610 | 論文 | verified（WebFetch・abstract） |
| S18 | Think More or Read More? A Token-Budget Theory of Reasoning with Shared Context | 2026-10 | https://arxiv.org/abs/2610.23246 | 論文 | verified（WebFetch・abstract） |
| S19 | The Cost of Consensus: Isolated Self-Correction Prevails Over Unguided Homogeneous MAD | 2026-04 | https://arxiv.org/abs/2605.00914 | 論文 | verified（WebFetch・abstract） |
| S20 | Multi-Agent Reasoning Improves Compute Efficiency: Pareto-Optimal Test-Time Scaling | 2026-05（ACL SRW 2026） | https://arxiv.org/abs/2605.01566 | 論文（反対側の証拠） | verified（WebFetch・abstract） |
| S21 | Statistical Scouting Finds Debate-Safe but Not Debate-Useful Cases | 2026-05 | https://arxiv.org/abs/2605.09618 | 論文 | verified（WebFetch・abstract） |
| S22 | Correlated Errors in Large Language Models | 2025-06（ICML 2025） | https://arxiv.org/abs/2506.07962 | 論文 | verified（WebFetch・abstract） |
| S23 | Great Models Think Alike and this Undermines AI Oversight | 2025-02（ICML 2025） | https://arxiv.org/abs/2502.04313 | 論文 | verified（WebFetch・abstract） |
| S24 | Don't Always Pick the Highest-Performing Model: LLM Ensemble Selection | 2026-02 | https://arxiv.org/abs/2602.08003 | 論文 | verified（WebFetch・abstract）。数値なし |
| S25 | Are More LLM Calls All You Need? Towards Scaling Laws of Compound Inference Systems | 2024-03 | https://arxiv.org/abs/2403.02419 | 論文（土台） | verified（WebFetch・abstract） |
| S26 | Large Language Models Cannot Self-Correct Reasoning Yet | 2023-10（ICLR 2024） | https://arxiv.org/html/2310.01798v2 | 論文（土台） | verified（WebFetch・本文 §4） |
| S27 | Is Self-Repair a Silver Bullet for Code Generation? | 2023-06（ICLR 2024） | https://arxiv.org/abs/2306.09896 | 論文（土台） | verified（WebFetch・abstract） |
| S28 | How Many Tries Does It Take? Iterative Self-Repair Across Model Scales | 2026-04 | https://arxiv.org/abs/2604.10508 | 論文 | verified（WebFetch・abstract） |
| S29 | Iterative Audit Convergence in LLM-Managed Multi-Agent Systems | 2026-05 | https://arxiv.org/abs/2605.12280 | 論文（単著の事例） | verified（WebFetch・abstract） |
| S30 | LLM Consortium for Software Design Refinement: Multi-Agent Collaboration Topologies | 2026-05 | https://arxiv.org/html/2606.01490v1 | 論文 | verified（raw・本文） |
| S31 | A Universal Cliff and a Design Fingerprint: Cross-Section Defect Detection Under LLM Orchestration | 2026-05 | https://arxiv.org/abs/2605.26174 | 論文（単著） | verified（WebFetch・abstract） |
| S32 | ReviewerToo: Should AI Join The Program Committee? | 2025-10 | https://arxiv.org/html/2510.08867 | 論文 | verified（WebFetch・本文 Table 1） |
| S33 | Replacing Judges with Juries (PoLL) | 2024-04 | https://arxiv.org/abs/2404.18796 | 論文（土台） | verified（WebFetch・abstract） |
| S34 | Anthropic「How we built our multi-agent research system」 | 2025-06-13 | https://www.anthropic.com/engineering/multi-agent-research-system | 一次の技術記事 | verified（WebFetch） |
| S35 | SWE-PRBench: Benchmarking AI Code Review Quality Against PR Feedback | 2026-03 | https://arxiv.org/abs/2603.26130 | 論文（単著） | verified（WebFetch・abstract） |
| S36 | (When) Should a Software Factory be Lights-off? Benchmarking Code Review Agents on Bug Detection | 2026-10 | https://arxiv.org/abs/2610.13668 | 論文 | verified（WebFetch・abstract） |
| S37 | Can Agentic Code Review Catch Vulnerabilities Before They Are Merged? (SecPRBench) | 2026-10 | https://arxiv.org/abs/2610.33509 | 論文 | verified（WebFetch・abstract） |
| S38 | Beyond Passing Tests: Systematic Review and Controlled Re-evaluation | 2026-10 | https://arxiv.org/abs/2610.38977 | 論文 | verified（WebFetch・abstract） |
| S39 | Rethinking the Bounds of LLM Reasoning: Are Multi-Agent Discussions the Key? | 2024-02 | https://arxiv.org/abs/2402.18272 | 論文（土台） | verified（WebFetch・abstract） |
| S40 | Beyond ChatGPT: Enhancing SQA Tasks with Diverse LLMs and Validation Techniques | 2024-09 | https://arxiv.org/abs/2409.01001 | 論文 | verified（WebFetch・abstract） |
| S41 | When and Why Does Multi-Agent Debate Fail and Does It Really Underperform? | NeurIPS 2026 | https://neurips.cc/virtual/2026/poster/153203 | 論文（ポスターのページ） | verified（WebFetch・abstract）。数値なし |
| S42 | The AI Scientist（レビューの ensemble の効果） | 2024-08 | https://arxiv.org/abs/2408.06292 | 論文 | unverified-summary（abstract に記載なし。検索結果の要約だけ） |

## 小問 a: 複数レビュアー・投票・検証役・同じモデルの複数回サンプリングの効果

### 効いた測定

- 同じモデルで独立にレビューを n 本作り、別の 1 回の呼び出しで統合すると、F1 が上がった。Gemini-2.5-Flash は n=10 で F1 15.25 から 21.91（+43.67%）、recall は +118.83% だった。Gemini-2.5-Pro は n=5 で F1 19.38 から 23.84（+23.01%）だった。統合後の precision は報告されていない。 `[verified]` (S2)
  - S2 の引用: 「performance gains exhibit diminishing returns beyond n=5, while costs continue to scale linearly」
- 1 組織の 18 件の成果物・154 件の確定した欠陥で、8 つのモデル版（5 社）を比べた事例では、56.5%（87/154）の欠陥を 1 つのモデルだけが見つけた。別の会社のモデルを 2 本目に足すと、検出の範囲は 33.6% から 57.1% に広がり、3 本目からは伸びが小さくなった。precision は報告されていない。 `[verified]` (S4)
  - 同じ事例で、同じモデルを繰り返し回しても結果が変わるとは示せなかったと書いている（S4 の引用: 「We could not establish that repeated passes vary」）。
- Cursor の Bugbot は、diff の並び順を変えた 8 本のパスを並列に回し、1 本のパスでしか出なかった指摘を多数決で落とし、最後に検証役のモデルで誤検知を除いていた。これを初期の最も効いた改善の 1 つと書いている。ただし後の最大の改善は、固定のパスをやめてエージェント型にしたことだった。解決率（指摘が実際に直された割合）は 40 回の実験を通じて 52% から 70% 超に上がったが、多数決だけの寄与は公開されていない。 `[verified]` (S6)
  - S6 の引用: 「Run eight parallel passes with randomized diff order」
- Anthropic の Code Review は、複数のエージェントが並列に探し、検証の段で誤検知を除く構成である。実質的な指摘が付く PR は 16% から 54% に増え、エンジニアが誤りと印を付けた指摘は 1% 未満だった。 `[verified]` (S7) この 1% 未満は利用者が明示的に印を付けた数なので、無視された指摘は数えていない可能性がある。 `[speculation]`
- 脆弱性検出で、役割の違う 3 つのエージェントに検証役を 1 つ足すと、F1 は単独の .714 から .772 に上がった（p<10⁻⁵）。 `[verified]` (S10)
- 論文の採否判定（コードではない）では、単独のペルソナの正解率 67.6〜71.9% に対し、全員の多数決が 75.1%、全員の意見をまとめる meta-reviewer が 81.8% だった。人間の平均は 83.9% だった。 `[verified]` (S32)
- 異なる系統の小さめのモデルを並べた審査団は、大きなモデル 1 つの審査より良く、費用は 7 分の 1 以下だった。 `[verified]` (S33)
- 2024 年の研究では、複数の LLM の投票で GPT-3.5 単独より 10% 超良くなり、別の LLM の答えを検証させる方法で最良の単独モデルより 4% 良くなった。 `[verified]` (S40)
- OpenAI のレビューでは、推論の予算を増やすと主に較正が良くなり、誤検知が減った。検証役は生成側のトークンのごく一部でも、既知の重大な問題の多くを捕まえた。 `[verified]` (S8)

### 効かなかった・悪化した測定

- 5 つのモデルの比較で、Haiku 4.5 の指摘に別のモデルの指摘を和集合で足すと、F1 は 0.365 から 0.304〜0.333 に下がった。precision は 0.486 から 0.627〜0.694 に上がり、recall は 0.293 から 0.195〜0.226 に下がったと報告されている。和集合で recall が下がるのは計算上おかしく、論文に説明は無い。著者は、どのモデルも大体同じバグを見つけ、2 本目は誤検知を増やすだけだったと書いている。150 件中 19 件は、5 モデルのどれも見つけられなかった。 `[verified]` (S1)
  - S1 の引用: 「Ensembles hurt F1. The models largely detect the same bugs」
- 検証役なしで 3 つのエージェントを合わせると、precision は .526 で、単独の .555 より低かった。問題の無いコードの 91.5% を脆弱と判定した。検証役を足して初めて単独より良くなった。 `[verified]` (S10)
- 4 つのエージェントの指摘を和集合で採ると、recall は 82.7% だったが、誤検知率は 85.0% だった。重み付きで採ると recall 37.7%、誤検知率 35.3% だった。F1 は 61.4% で、fine-tune した GPT-3.5 の 71.6% より低かった。 `[verified]` (S11)
- 10 個のオープンモデルの投票は、モデルの平均よりは良かったが、最良の単独モデルにはいくつかの条件で負けた。検出の課題では 10 モデル中 7〜9 モデルに負けた。 `[verified]` (S12)
- 敵対的に反証させる段を重ねた方式では、候補の約 79%（171 件中）を開示前に捨てた。存在しない脆弱性を 10 のレビュアーが全員一致で支持し、1 回の実行による確認でやっと消えた例が報告されている。著者は、系統の違うモデルのレビューは同じ系統では見逃す偏りを捕まえうると主張しているが、数値の比較は abstract には無い。 `[verified]` (S13)
- 350 を超える LLM で、両方が間違えたときに同じ誤答を選ぶ割合は、ある leaderboard のデータで 60% だった。大きく正確なモデルほど、会社や構造が違っても誤りの相関が高かった。 `[verified]` (S22)
- 能力が上がるほど、モデル同士の間違い方が似てきている。LLM の判定役は自分に似たモデルを高く評価する。 `[verified]` (S23)
- 議論（multi-agent debate）の上積みは、ほとんどが議論の前の多数決で説明できる。Qwen2.5-7B では、単独 0.7205、最良の議論 0.7377、多数決 0.7691 だった。 `[verified]` (S14)
  - S14 の引用: 「in most cases, majority voting performs on par with MAD」
- 同じ回答数で比べると、議論は単純な self-consistency（多数決）に負けた。GSM8K で、9 回答の議論 83.0 に対し self-consistency 88.2 だった。 `[verified]` (S26)
- 5 つの議論方式と 9 つのベンチマークで、議論は推論の計算量をかなり多く使っても、CoT や self-consistency をしばしば超えなかった。モデルを異種にすることは一貫して効いた。 `[verified]` (S16)
- 9 本の既存研究を再集計すると、比較相手の単独モデルにサンプリングや同じ予算を与えた場合、マルチエージェントの優位は平均 −0.042 になった。統制実験では、同じトークン数の self-consistency に対し議論は −0.015 だった。 `[verified]` (S17)
- 980 の条件のうち 93% で、self-consistency は議論と同等以上だった。 `[verified]` (S18)
- 反対側の証拠として、同じ計算量で議論が self-consistency を 1.3 点、mixture-of-agents が 2.7 点上回ったという報告がある。self-consistency は早く頭打ちになり、マルチエージェントの上積みは難しい課題で残ったという。 `[verified]` (S20)
- コード生成の品質では、同じ予算で比べると、レビュー役のエージェントも自己改善も、best-of-n と順位付けに勝たなかった。66 の手法のうち best-of-n に有意に勝ったのは 1 つで、偶然と同程度の割合だった。 `[verified]` (S38)
- 文書を分担して複数のエージェントに読ませ、最後にまとめる構成では、離れた節どうしの矛盾の検出が、試した 10 モデルすべてで 3 分の 2 以上落ちた。強いモデルでも直らなかった。 `[verified]` (S31)

## 小問 b: 合意や収束まで回すか、1〜2 回で止めるか

- 議論の回数を増やすと、平均の正解率は下がった。Qwen2.5-7B の分散型の議論で、2 回 0.7377、3 回 0.7112、5 回 0.7050 だった。Llama3.1-8B でも 0.6929、0.6788、0.6761 と下がった。著者は、議論だけでは期待される正しさは上がらない（martingale）と理論で示している。正しい答えを固定する工夫を入れると改善した。 `[verified]` (S14)
- 議論を続けると正解率が時間とともに下がることがある。モデルは仲間の推論を見て、正しい答えから誤った答えに乗り換えることが多く、反論より同意を選ぶ。弱いエージェントが混ざると、強いエージェントの成績が崩れる。 `[verified]` (S15)
- 同じモデル 10 体で 3 回議論させると、多数派の答えにそのまま合わせる割合が最大 85.5% になった。仲間の理由づけを見て正しかった推論が崩れる割合は最大 70.0% だった。多数決で、候補の中にあった正解を捨てる差は最大 32.3 点だった。 `[verified]` (S19)
  - S19 の引用: 「uncritically adopt majority answers」
- 合意を目指す議論は、情報を持つ食い違いを早すぎる合意で捨ててしまう。 `[verified]` (S41)
- 議論が役に立った例の 66%（47 件中 31 件）は、投票が全員一致で間違っていた場合だった。全員一致は、議論が要らない場面を示さない。 `[verified]` (S21)
  - S21 の引用: 「vote entropy predicts where debate is safe, not where debate is needed」
- 10 のレビュアーが全員一致で誤った指摘を支持した例がある（a に記載）。合意は正しさの証拠にならない。 `[verified]` (S13)
- 仕様書を 9 回監査した事例では、回ごとの指摘数が 15、8、12、2、8、1、4、1、0 だった。減り方は単調でなく、修正が連鎖したことと監査の範囲が広がったことが原因と考えられている。 `[verified]` (S29)
- コードの自己修復では、改善の大部分が最初の 2 回で出た。 `[verified]` (S28)
- 自己修復は、費用を考えると改善が小さく、データによっては無かった。律速は自分のコードへのフィードバックの質で、強いモデルのフィードバックを使うと改善が大きくなった。 `[verified]` (S27)
- 外部からのフィードバックが無い自己修正では、推論の成績がむしろ下がった。 `[verified]` (S26)
- 設計文書の改善では、同じモデルの 3 回の自己改善（4.503、$0.33）は 1 回だけの生成（4.514、$0.08）を超えなかった。同じモデルのレビュー（4.493、$0.42）も同じだった。別のモデルのレビュー（4.606、$0.27）と、構造化した敵対的レビュー（4.637、$0.43）は上回った。議論（4.353）と複数案の統合（3.655〜4.326）は基準より悪かった。採点はすべて LLM で、上位の方式どうしでは採点者の一致度が低い（α 0.42）。 `[verified]` (S30)

## 小問 c: モデルの強さ・課題の難しさ・diff の大きさとの関係

### モデルの強さ

- 書き手とレビュアーの組み合わせで結果が逆になった。Claude Opus 4.7 が GPT-5.5 の下書きをレビューすると合格率は 71.6% から 89.7% に上がった（26 件直して 5 件壊した）。GPT-5.5 が Opus 4.7 の下書きをレビューすると 91.4% から 82.8% に下がった（3 件直して 13 件壊した）。Opus 4.7 の自己レビューは 91.4% のままだった。レビュアーは必ず最終のプログラムを出す決まりで、「直さない」を選びにくい設計である。著者は、下書きが弱いときにレビューが役立つとまとめている。 `[verified]` (S3)
  - S3 の引用: 「handing Claude Opus 4.7's draft to Codex GPT-5.5 actually drops it to 82.8%」
- 統合の上積みは弱いモデルほど大きく見える。Flash は +43.67%（n=10）、Pro は +23.01%（n=5）だった。ただし n が違うので、この比較は私の読みである。Flash の n=5（F1 20.48）は Pro の 1 回（19.38）を、より安い費用で上回った。 `[verified]` の数値と `[speculation]` の解釈 (S2)
- 小さいモデルの Haiku 4.5（F1 0.365、$0.003）が Sonnet 4.6（0.343、$0.010）を上回った。強いモデルを和集合で足しても F1 は下がった。 `[verified]` (S1)
- 大きく正確なモデルほど誤りの相関が高い（S22）。能力が上がるほど間違い方が似る（S23）。したがって、最先端のモデルどうしを並べるほど、多様性による上積みは小さくなると考えられる。 `[verified]` の事実と `[speculation]` の推論 (S22, S23)
- 32B のモデルでも、多数決は議論と同等だった。 `[verified]` (S14)
- 弱いエージェントが混ざると強いエージェントの成績が崩れる。 `[verified]` (S15)
- 同じ会社のモデルが書いたコードは、そのモデルが見逃しやすいという方向の結果がある。Claude Code の PR では GPT が Opus より多く重大なバグを捕まえ、Codex の PR ではその逆だった。 方向は `[verified]`、個々の数値（53.7%・60.0% など）は `[unverified-summary]` (S5)

### 課題の難しさ

- 呼び出し回数を増やした投票は、易しい問いでは成績を上げ、難しい問いでは下げる。そのため全体の成績は、回数とともにいったん上がってから下がることがある。 `[verified]` (S25)
- 逆に、マルチエージェントの上積みは難しい課題でより残ったという報告もある。 `[verified]` (S20)
- レビューのエージェントは、複雑な変更や、離れた場所を合わせて考える必要のあるバグに弱い。 `[verified]` (S36)
- セキュリティのレビューで見逃した例の 68% は、欠陥のあるファイルを指しながら、別の仕組みを論じていた。recall は 8 モデルで 32.5〜78.1% だった。 `[verified]` (S37)

### diff の大きさ

- Anthropic の社内の測定では、1,000 行を超える PR の 84% に指摘が付き、平均 7.5 件だった。50 行未満の PR では 31%、平均 0.5 件だった。大きい変更にはエージェントを多く割り当てる。 `[verified]` (S7)
- Haiku 4.5 の F1 は、10 行未満の diff で 0.657、10〜50 行で 0.800、50 行を超えると 0.043〜0.070 に落ちた。人工のバグでは F1 0.847 だったが、実際の PR では 0.066 だった（92% 減）。 `[verified]` (S1)
- 8 つの最先端モデルは、diff だけで人間の指摘の 15〜31% を見つけた。ファイルの中身や全体の文脈を足すと、8 モデルすべてで成績が単調に下がった。 `[verified]` (S35)

## 小問 d: 費用の倍率

| 出典 | 構成 | 費用の倍率・額 | 状態 |
|---|---|---|---|
| S34 | エージェントとマルチエージェント（調査用途） | チャットに比べ、エージェントは約 4 倍、マルチエージェントは約 15 倍のトークン。BrowseComp では成績のばらつきの 80% をトークン量で説明できた。コーディングは並列にできる部分が少ないと明記 | verified |
| S7 | Anthropic Code Review | 1 回のレビューは平均 $15〜25、約 20 分 | verified |
| S2 | 同じモデルの n 本の統合 | 費用は n に比例。n=5 を超えると上積みが小さくなる | verified |
| S3 | 1 回のレビューを足す | 1 課題あたり、書き手だけ $0.19〜0.23 に対し、レビュー付きは $0.31〜0.44（約 1.6〜2.3 倍）。時間も 1.4〜2.9 倍 | verified |
| S10 | 3 エージェント＋検証役 | 単独の約 3.5 倍（$0.0021 と $0.0006）。待ち時間は 68.1 秒と 14.1 秒 | verified |
| S11 | 4 エージェント＋self-consistency | 1 件 $0.46（LLM 1 回は $0.13）。self-consistency だけで約 $0.26 | verified |
| S19 | 議論と自己修正 | 議論は 2.1〜3.4 倍のトークンで、正解率は同等以下 | verified |
| S20 | 議論・mixture-of-agents | CoT より最大 +7.1 点だが、計算量は約 20 倍 | verified |
| S30 | 設計レビューの方式 | 1 回の生成 $0.08、別モデルのレビュー $0.27、敵対的レビュー $0.43、自己改善 3 回 $0.33 | verified |
| S9 | 決まった手順に絞ったレビュー | Claude Code や Codex の汎用エージェントより 5〜15 倍少ないトークンで、SEM-F1 は 25.10% と 11.57% | verified |
| S33 | 小さいモデルの審査団 | 大きなモデル 1 つより 7 倍以上安い | verified |
| S36 | 探索を促す prompt | 成績 +5.8% に対し費用 +10% | verified |
| S16 | 議論全般 | 単独の基準よりかなり多い計算量を使っても勝てないことが多い | verified |

## 手元の構成（2〜3 社のレーン、ときに合意まで往復）への含意

以下は上の測定からの私の推論であり、手元の構成で測ったものではない。 `[speculation]`

1. お金を払う価値があるのは、レーンを独立に回して指摘を集める部分である。往復や議論で合意させる部分は、測定上の上積みがほぼ無く、同調によって正しい指摘が消える危険がある（S14, S15, S19, S41）。
2. レーンを足すなら、指摘を絞る段を必ず付ける。和集合のままだと誤検知が増え、単独より悪くなることがある（S1, S10, S11）。絞り方は、複数レーンの一致、検証役、実行やテストによる確認のどれかになる（S6, S7, S10, S13）。
3. 全レーンの一致を正しさの証拠として扱わない。重要な指摘は、再現やテストのような外の確かめで裏を取る（S13, S21, S22）。
4. 2 本目のレーンには「直さない・指摘なし」と答える道を残す。必ず何かを出させると、別のモデルが正しいものを壊すことがある（S3）。
5. 往復は 1〜2 回で止めるのが測定と合う。ただし範囲を広げると新しい指摘がまた出るので、件数が 0 になるまで回す止め方は収束しないことがある（S28, S29）。
6. 会社の違う 2 本目のレーンは、検出の範囲を広げる見込みが一番大きい。3 本目からの伸びは小さい（S4）。最先端のモデルどうしは誤り方が似てきているので、この伸びは今後縮む可能性がある（S22, S23）。
7. 複数レーンを使う価値は、大きい diff や重要な変更で高い（S7, S1）。小さい diff では単独でも当たりが少なく、増やしても得るものが少ない。
8. レーンをファイルや節で分担させると、離れた箇所どうしの矛盾を見逃しやすくなる（S31）。各レーンには変更全体を見せる方がよい。

## 見つからなかったもの

- 最先端のモデル 1 本と、会社の違う最先端のモデル 2〜3 本を、同じ実際の PR の集合で比べ、precision・recall・費用をそろえて測った研究は見つからなかった。近いものは S4（precision なし・1 組織）、S1（小さめのモデル・和集合の recall に計算上の矛盾）、S5（ベンダーの記事・数値の対応が取れない）だけである。
- 「レビュアーのレーンが合意するまで往復する」方式を、コードレビューで最先端のモデルを使って測った研究は見つからなかった。何回で収束するか、収束しない割合はどれくらいか、についての数値も見つからなかった。近いものは議論の研究（S14, S15, S19、主に 7〜32B のオープンモデル）と、1 件の監査の事例（S29）である。
- 同じモデルで同じ PR を何度もレビューしたときの、指摘のばらつきを測った研究は見つからなかった。S4 は変わることを示せなかったと書き、S5 は 3 回の平均を使っているが、ばらつきの値は出していない。
- 計画や設計の批評を複数の LLM で行い、人間が判定した研究は見つからなかった。S30 は LLM の採点だけで、モデルの組み合わせも 1 通りである。
- o3・GPT-5・Claude のような閉じた最先端のモデルで、議論と多数決を予算をそろえて比べた研究は見つからなかった。S17・S19・S21 などはオープンモデルである。
- Cursor の多数決そのものの効果の数値と、SWR-Bench の統合後の precision は公開されていない。
- S42（The AI Scientist で 5 本の ensemble は正解率を変えず、ばらつきだけ減らした、という主張）は、abstract に記載が無く、一次資料で確かめられなかった。

## 読んだ範囲と読み残した範囲

- 読んだもの: 上の 42 本。そのうち 9 本は本文の文字列を直接照合した（S1, S2, S3, S4, S6, S7, S10, S14, S30）。残りは WebFetch で abstract か本文を読んだ。
- 読み残したもの: abstract しか読んでいない論文の本文の表（S9, S13, S15, S17〜S21, S29, S31, S35〜S38）。Greptile の図の数値の対応。CodeRabbit・Qodo・Martian などのベンダーのベンチマーク（数値の出し方が検証しにくいので外した）。ICSE・FSE 2026 の論文集の網羅的な検索。日本語や中国語の資料。

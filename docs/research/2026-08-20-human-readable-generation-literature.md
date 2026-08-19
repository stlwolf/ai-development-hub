---
title: "生成文章の人間可読性 — 会話面の自由文を読める形にするための文献調査"
date: 2026-08-20
status: research-complete
tags: [research, readability, register, conversation-surface, output-styles, human-interface]
sources:
  - https://arxiv.org/html/2510.03178
  - https://arxiv.org/html/2604.03616
  - https://arxiv.org/html/2607.17063v2
  - https://arxiv.org/pdf/2506.02739
  - https://arxiv.org/html/2511.20639v1
  - https://arxiv.org/pdf/2605.31170
  - https://arxiv.org/pdf/2605.29676
  - https://arxiv.org/abs/2401.16380
  - https://github.com/conorbronsdon/avoid-ai-writing/blob/main/SKILL.md
  - https://blog.ploeh.dk/2026/03/30/programming-languages-for-ai/
  - https://jacobdesforges.com/i-dont-want-to-read-your-llm-output/
  - https://code.claude.com/docs/en/output-styles
related_research:
  - docs/research/2026-07-16-register-portability-eval.md（#263 段階1実測の正本。読者(b)他モデル軸。本ノートは読者(c)人間軸で、所見5で突合する）
  - docs/research/2026-07-27-ai-slop-design-process.md（ルール集だけでは品質を守れない、という反証側の論点）
  - docs/research/2026-06-03-llm-verification-discipline-literature.md（本ノートの検証ステータス規約の根拠）
related_ideas:
  - ideas/20260820/human-readable-generation-discussion.md（本調査を生んだ議論の現在地と再開点）
related_issues: [263, 329, 281]
next_step:
  trigger: "output styles 検証 issue の着手時 / #263 段階2（規範化判断）/ #329（SO 人間層）の設計時"
  actions: "所見4（生成と読解の非対称）を制御点の置き場の判断に使う。所見5の突合（外部文献と段階1実測の張力）を #263 段階2 の判断材料に足す。所見6（意味の層は自然言語）を for-AI 最適化の限界線として使う"
  referenced_by: "ideas/20260820/human-readable-generation-discussion.md、output styles 検証 issue、#263、#329"
---

# 生成文章の人間可読性 — 会話面の自由文を読める形にするための文献調査

## 中心の問い

AI の会話面（チャット応答）の自由文が人間に読みづらい。生成結果の応答は人間しか読まないので、ここは人間専用のインターフェースである。フォーマット節（output-format-rule の枠）は外から順序を強制するので保たれるが、自由文には枠がなく、生成した順のまま出てくる。この読みづらさがどこから来て、何で直せるのかの証拠を集めた。

読者(b)（他モデル）の軸は `docs/research/2026-07-16-register-portability-eval.md` が実測済みで、本ノートの守備範囲ではない。本ノートは読者(c)（人間）の軸と、両者の境界線を扱う。

> メタ注記（本ノート自身への適用）: ソースの本文確認は WebFetch（取得器の要約を介する）で行った。`[verified]` は本文を取得して主張を確認したもの、`[unverified-summary]` は検索結果の要約止まりのもの、`[speculation]` は本ノートの推論。また本ノート自身を「平易な散文 + 事実は表」のレジスタで書いている。この形が人間と AI の両方に効くという収束仮説は未検証で、#263 段階2 の判断対象である。

## 結論

- 読みづらさは2軸に分解できる。順序（導出順で書かれ、読者が必要な順ではない）と、表面の癖（記号圧縮・体言止め・対句・rule-of-three）。悩みは普遍的で対策スキルの市場があるが、ほぼすべて後編集（editor 型）に収束しており、生成時に効かせる型は見当たらない。
- 生成側と読解側の最適は非対称である（所見4）。生成中に形式を課すと推論精度が落ち、自由に生成してから整形すると回復する。会話面の改善は「生成を縛る」より「後段で直す・枠を与える」が筋。
- 電報体（記号圧縮・体言止め）は読み手ではなく書き手に最適化された形式である（所見5からの推論）。読み手が AI でも人間でも、圧縮の利得は確認されない。ただし当リポジトリの段階1実測は「内容の明示事実は電報体でも可搬」を示しており、外部文献の外挿とは張力がある。層が違う（明示事実の取り出し vs 意図の要約）と読むのが現時点で最も整合的。
- AI 同士の専用チャネル（latent 通信）は実在するが同一モデル系列限定で、モデルをまたぐ意味の層は自然言語に残る（所見6）。会話面を for-AI に最適化する理由は階層のどこにもない。
- ハーネス上の未使用の制御点として Claude Code の output styles がある。会話面（main conversation）だけに効き、subagent には効かないので、agent-to-agent チャネルを汚さずに会話面のレジスタを制御できる位置にある。

## 所見1: 悩みは普遍、対策は editor 型に収束

「AI っぽくて読みづらい」への対策スキルは市場に多数ある。エンジニア界に限らない。

| 名前 | 狙い | 状態 |
|---|---|---|
| De-Slop / Stop Slop / Humanizer | puffery・rule-of-three・前置き・em dash・単調構造の除去 | [unverified-summary]（検索要約のみ） |
| Anti-AI Writing Engine | 相関構文・hedge の禁止、SUCKS フレームワーク | [unverified-summary] |
| Prose Writing & Style Guide | Strunk & White を editor として強制 | [unverified-summary] |
| avoid-ai-writing | 表面の癖に加えて順序と情報密度も検査 | [verified]（SKILL.md 本文確認） |

avoid-ai-writing は順序を明示的に検査項目にしている [verified]: 段落を並べ替えても気づかれないなら接続が無い（bridge sentence を足す）、claim の前で止まる前置きを弾く、前提の言い換えだけで前進しない段落を treadmill effect として検出する。

全部が editor 型（書いた後に直す）である点が重要で、これは「生成時点では結論がまだ無い」という自己回帰生成の構造要因と整合する [speculation]。日本語圏の対策記事は逆に「体言止めや倒置を適度に使え」と勧めるものが多い [unverified-summary]。目的が違う（AI 判定の回避 vs 一読可能性）ためで、「AIっぽさ」という同じ語が別問題を指している。

## 所見2: 読みづらさの計測 — over-answering

LLM の回答を core とそれ以外に分解して測った研究がある（HDL の QA ドメイン）[verified]:

| 指標 | LLM | 人間の専門家 |
|---|---|---|
| 重複した代替案を含む回答 | 65.7% | 4.4% |
| 余分な padding を含む回答 | 69.1% | 5.8% |

重複には multi-agent debate、padding には task-aware compression と、長さと構造を別問題として別の対処を当てている [verified]。ドメイン限定のため数値の一般化は不可だが、「長さと順序は別の欠陥」という分解は本ノートの2軸分解を支持する。

## 所見3: 順序の先行技術は AI の外にある

結論を最初の一文に置く BLUF（米陸軍 AR 25-50、1988）と Minto の Pyramid Principle が、読み手の負荷を下げる目的で順序を規定した先行技術 [unverified-summary]。自己回帰モデルは結論を先に出すことを構造的に嫌うので逆順を強制する必要がある、という説明が prompt engineering 界にあるが、ブログ記事レベルの根拠にとどまる [unverified-summary]。

## 所見4: 生成と読解の非対称（format tax）

生成中に構造化形式を課すと推論精度が落ちる。The Format Tax の測定 [verified]:

| 測定 | 値 |
|---|---|
| open-weight モデルの平均劣化 | -3.9pp |
| MATH-500 の形式平均 | -9.9pp |
| LaTeX 指定時の文章品質 | -7〜-18.6pp |
| 有意な劣化のうちプロンプト指示だけで発生する割合 | 92%（39件中） |
| decoder 制約が追加で足す劣化 | -1.6pp |
| 自由生成→後整形（2ターン）の回復 | +6.8pp |
| 思考を先に走らせる方式の回復 | +9.2pp |
| closed-weight モデル（Claude 等）の劣化 | ほぼゼロか正 |

帰結: 検証可能性の最適化は「生成を縛る」ことではなく「生成の後ろに検証・整形層を置く」ことになる。ハーネスで言えば hook と機械検査と後編集の側であって、生成時の書き方規約の側ではない [speculation]。ただし測定対象は JSON や LaTeX などの構造化形式であり、レジスタ指示（結論先出し・語彙）が同じ税を課すかは未測定 [speculation]。closed-weight でほぼゼロである点は、Opus 系ではプロンプト側指示のコストが小さい可能性も残す [unverified-summary]。

## 所見5: 読解側は言葉に強く依存する — 電報体は書き手最適化

読解側の測定。プログラムの構造と挙動を保ったまま識別子名だけを潰すと、LLM の理解が大きく落ちる（When Names Disappear）[verified]:

| タスク | 落ち幅 |
|---|---|
| コード要約（ClassEval・クラス単位・GPT-4o） | 87.3 → 58.7（-28.6pt） |
| 実行予測（ClassEval・DeepSeek・曖昧識別子） | 90.0% → 69.3% |
| 実行予測（LiveCodeBench・Llama・曖昧識別子） | 80.2% → 56.4% |

同論文の解釈では、識別子は理解の助けというより記憶した型を引き出す検索キーとして働いている [verified]。どちらの解釈でも「言葉を削ると AI も読めなくなる」という結果は同じ。一方、入力形式（JSON/YAML/XML/Markdown/TOON）の違いは理解精度をあまり動かさず、動くのはトークンコストである [unverified-summary]（複数ベンチの検索要約。11モデル4形式の SQL 生成では集計で有意差なし）。

推論: 記号圧縮は名前のついた関係を名前の無い記号に置き換える操作、体言止めは述語を落とす操作で、識別子を潰す操作と構造的に同型。よって電報体は読み手（人間・AI とも）に高くつき、買っているのはトークン節約＝書き手側の利得だけ [speculation]。

**段階1実測との突合（重要な張力）**: 当リポジトリの `2026-07-16-register-portability-eval.md` は、電報体の doc でも内容プローブ（決定・status・チェーン等の明示事実）が全レーン正答だったことを示している。外部文献の外挿（言葉を削ると落ちる）と一見矛盾するが、(1) 段階1のコストは記号 decode と file:line 参照の狭い層に出た、(2) 段階1の内容プローブは明示事実の取り出しで、names-disappear が落ちを観測したのは意図の要約（summarization）である、(3) 段階1には正解キー参照可能性と ceiling の caveat が明記されている、の3点から「測っている層が違う」と読むのが現時点で整合的 [speculation]。段階1自身も「体言止め・高密度・入れ子は未検証のまま」と結論している [verified]。

## 所見6: AI 側の境界 — 意味の層は自然言語に残る

会話面を for-AI に最適化すべきかの境界確定として、AI 同士の通信の証拠を置く。

- latent 通信（LatentMAS）は実在し強い: 出力トークン -70.8〜83.7%、text ベース多エージェント比で精度最大 +4.6%、4〜4.3倍速 [verified]。ただし実験は Qwen3 同一系列のみで、KV cache の層連結はアーキテクチャが違うモデル間では成立しない [verified]。
- 「なぜ自然言語か」を正面から扱った論文は、一時的な事故ではなく構造的と結論する [verified]。理由は3つ: 学習コーパスが人間言語（母語）、独立に訓練されたエージェント間の共通基盤、人間が監視・介入できること。
- エージェント集団に言語を進化させるとトークン効率は上がるが人間が読めなくなり、副題どおり oversight evasion に向かう [verified]。エージェント自作プロトコルは構成性が乏しく脆いという報告もある [unverified-summary]。
- 実運用の protocol（A2A/MCP）は「routing する部分は schema、意味を運ぶ部分は自然言語」で線を引いている [unverified-summary]。

帰結の3層分割: transport と envelope は schema でよい（既に for AI）。意味の層は自然言語が最適（3つの独立な理由）。モデル内部は latent が強いが同一系列限定。会話面は意味の層の、さらに人間専用の端にあり、for-AI 最適化の圧をかける理由が階層のどこにもない。

補足: 学習しやすい形式の研究（WRAP）は、web テキストを整った文章に書き換えてから学習させると事前学習が約3倍速くなることを示す [unverified-summary]。書き換え先に選ばれたのは機械向け形式ではなく整った人間の文章（Wikipedia 風）である点が示唆的だが、学習時の知見であり読解への直接転用は推論。

## ハーネスへの帰結

| 対象 | 帰結 | 行き先 |
|---|---|---|
| 会話面（チャット応答） | 人間専用インターフェース。output styles が未使用の制御点（main conversation のみ・subagent 非適用・keep-coding-instructions で SWE 挙動保持可）[verified・公式 doc] | output styles 検証 issue |
| 4層ドキュメント | 収束仮説（平易散文 + 機械が解ける構造）は本調査でも独立に導かれたが未検証。段階1の「内容は可搬・規範化の緊急度は低い」と併読して段階2で判断 | #263 |
| SO 出力 | 機械層と人間層の分離・併産の方向を所見4（two-step の回復）が外部から支持 | #329 |
| 生成規律一般 | 生成を縛るより後段に検証・整形層を置く（所見4）。ただしレジスタ指示への外挿は未測定 | 全般 |

## 未確認のまま残ること

- latent 通信の異機種間拡張を扱う論文（arXiv 2606.05711）は PDF から本文を取り出せず未読。
- WRAP・入力形式比較・BLUF・A2A・日本語圏対策記事は検索要約止まり（本文未確認）。
- format tax の測定は数学・構造化形式であり、会話面のレジスタ指示への外挿は本ノートの推論。
- 収束仮説（1つのレジスタが人間と AI の両方に効く）は未検証。#263 段階2 の判断対象。

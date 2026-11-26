# AI コードレビューの集約とチューニング：一次資料の調査

> この文書は、調査役（Claude Opus 5.5）が書いたメモの原文である。取りまとめは `docs/research/investigations/2026-11-27-llm-review-multi-reviewer-evidence.md` にある。この文書の中の `verified` は調査役の申告で、取りまとめた側が照らしたものではない。数字は、使う前に原典で確かめる。

調査日: 2026-11-27

## 0. この文書について

- 目的: 2〜3 本の LLM レビューのレーン（セカンドオピニオン）を回す小さなチームが、役に立つ指摘を増やしつつ費用を減らすための実践を集める。ここでいう費用は、ノイズ、食い違う指摘の統合、収束しない往復、細かすぎる指摘、リスクの見積もり違いを指す。数字か、作った人による技術的な詳細の裏付けがあるものに限った。
- 方法: WebSearch で候補を探し、一次資料（技術ブログ、論文、公式 docs、ソースコード）を WebFetch で開いた。GitHub 上の README とソースは `gh api` で直接読んだ。Anthropic の 2 本（claude.dev）は依頼どおり基準線としてだけ使った。
- 状態の札の意味は次のとおり。
  - `[verified]`: この調査で一次資料を開き、取り出した内容が主張を支えたもの。
  - `[unverified-summary]`: 検索結果や二次資料の要約に頼ったもので、一次資料での裏付けを取っていないもの。
  - `[speculation]`: 出典のない推論。
- 注意 1: WebFetch は小さなモデルが本文を要約して返す。数字を写し間違えている余地は残るので、判断に使う数字は原文で確かめることを勧める。引用句も WebFetch が返した文字列なので、逐語であるとまでは言えない。
- 注意 2: 多くの数字はベンダー自身の計測である。addressed / resolved / accepted の定義はベンダーごとに違うので、数字を横に並べて優劣を決めてはいけない。

## 1. ソース一覧

| # | タイトル | 日付 | URL | 種別 | 状態 |
|---|---|---|---|---|---|
| S1 | Solving code review at Anthropic（基準線） | 2026-10-15 | https://claude.dev/blog/solving-code-review-at-anthropic/ | 一次・技術ブログ | verified |
| S2 | How the Claude Code team thinks about verification（基準線） | 2026-11-16 | https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ | 一次・技術ブログ | verified |
| S3 | Bringing Code Review to Claude Code | 2026-03-09 | https://claude.com/blog/code-review | 一次・製品ブログ | verified |
| S4 | Claude Code docs: Code Review | 閲覧 2026-11-27 | https://code.claude.com/docs/en/code-review | 公式 docs | verified |
| S5 | Claude Code docs: Code Review costs and usage | 閲覧 2026-11-27 | https://code.claude.com/docs/en/code-review-costs | 公式 docs | verified |
| S6 | Building a better Bugbot (Cursor) | 2026-01-15 | https://cursor.com/blog/building-bugbot | 一次・技術ブログ | verified |
| S7 | Bugbot now self-improves with learned rules (Cursor) | 2026-04-08 | https://cursor.com/blog/bugbot-learning | 一次・技術ブログ | verified |
| S8 | Cursor docs: Bugbot | 閲覧 2026-11-27 | https://cursor.com/docs/bugbot | 公式 docs | verified |
| S9 | 60 million Copilot code reviews and counting (GitHub) | 2026-03-05 | https://github.blog/ai-and-ml/github-copilot/60-million-copilot-code-reviews-and-counting/ | 一次・技術ブログ | verified |
| S10 | ReviewBench: An open benchmark for AI code review (GitHub) | 2026-10-05 | https://github.blog/ai-and-ml/github-copilot/reviewbench-an-open-benchmark-for-ai-code-review/ | 一次・技術ブログ | verified |
| S11 | Copilot code review: new configurations and controls | 2026-06-12 | https://github.blog/changelog/2026-06-12-copilot-code-review-new-configurations-and-controls/ | changelog | verified |
| S12 | Auto-resolution and analysis updates in Copilot code review | 2026-09-11 | https://github.blog/changelog/2026-09-11-auto-resolution-and-analysis-updates-in-copilot-code-review | changelog | verified |
| S13 | Copilot code review: an improved review experience | 2026-09-18 | https://github.blog/changelog/2026-09-18-copilot-code-review-an-improved-review-experience | changelog | verified |
| S14 | Copilot code review will start consuming Actions minutes | 2026-04-27 | https://github.blog/changelog/2026-04-27-github-copilot-code-review-will-start-consuming-github-actions-minutes-on-june-1-2026/ | changelog | verified |
| S15 | Unlocking the full power of Copilot code review: instructions files | 2025-11-14（2026-04-17 更新） | https://github.blog/ai-and-ml/github-copilot/unlocking-the-full-power-of-copilot-code-review-master-your-instructions-files/ | 一次・ブログ | verified |
| S16 | Community discussion #189767（Copilot の再レビューが終わらない） | 2026-03-16 | https://github.com/orgs/community/discussions/189767 | 利用者の報告 | verified（報告として） |
| S17 | How to Make LLMs Shut Up (Greptile) | 2024-12-18 | https://www.greptile.com/blog/make-llms-shut-up | 一次・技術ブログ | verified |
| S18 | Greptile v4 + New Pricing | 2026-03-05 | https://www.greptile.com/blog/greptile-v4 | 一次・製品ブログ | verified |
| S19 | Greptile v5 | 2026-08-05 | https://www.greptile.com/blog/greptile-v5 | 一次・製品ブログ | verified |
| S20 | Accurate AI Code Reviews on Massive Codebases (CodeRabbit) | 2025-09-05 | https://www.coderabbit.ai/blog/how-coderabbit-delivers-accurate-ai-code-reviews-on-massive-codebases | 一次・技術ブログ | verified |
| S21 | CodeRabbit docs: Learnings | 閲覧 2026-11-27 | https://docs.coderabbit.ai/guides/learnings | 公式 docs | verified |
| S22 | CodeRabbit docs: Reduce noise | 閲覧 2026-11-27 | https://docs.coderabbit.ai/configuration/guides/reduce-noise | 公式 docs | verified |
| S23 | Introducing Qodo 2.0 | 2026-02-04 | https://www.qodo.ai/blog/introducing-qodo-2-0-agentic-code-review/ | 一次・製品ブログ | verified |
| S24 | How we built a real-world benchmark for AI code review (Qodo) | 2026-02-04 | https://qodo.ai/blog/how-we-built-a-real-world-benchmark-for-ai-code-review | 一次・技術ブログ | verified |
| S25 | PR-Agent `pr_agent/settings/configuration.toml`（commit 19366db, 2026-11-26） | 2026-11-26 | https://github.com/qodo-ai/pr-agent/blob/19366dbb635d3da1d058e5fee56c8e2ef580f08c/pr_agent/settings/configuration.toml | ソースコード | verified |
| S26 | Qodo docs: Auto best practices | 不明 | https://docs.qodo.ai/qodo-documentation/qodo-merge/pr-agent/core-abilities/auto_best_practices | 公式 docs | unverified-summary |
| S27 | Braintrust: Graphite の評価の仕組み | 不明 | https://www.braintrust.dev/blog/graphite | 提携先の事例 | verified |
| S28 | Graphite docs: AI review comments | 閲覧 2026-11-27 | https://graphite.com/docs/ai-review-comments | 公式 docs | verified |
| S29 | Graphite customer story (Claude) | 不明 | https://claude.com/customers/graphite | ベンダー事例 | verified（ベンダーの主張として） |
| S30 | Tomas Reimers 講演ページ (AI Engineer World's Fair 2025) | 2025 | https://ai.engineer/talks/H6MrR5NbTZA-dont-get-one-shotted-use-ai-test | 講演の要約ページ | unverified-summary |
| S31 | Enhancing Code Quality at Scale with AI-Powered Code Reviews (Microsoft) | 2025-07-14 | https://devblogs.microsoft.com/engineering-at-microsoft/enhancing-code-quality-at-scale-with-ai-powered-code-reviews/ | 一次・技術ブログ | verified |
| S32 | AI-Assisted Assessment of Coding Practices in Modern Code Review（Google, AutoCommenter, AIware'24） | 2024-05 | https://arxiv.org/html/2405.13565v1 | 論文 | verified |
| S33 | Lessons from building Sashiko, an agentic code review system (Google Cloud) | 2026-11-19 | https://cloud.google.com/blog/products/application-development/lessons-from-building-sashiko-an-agentic-code-review-system | 一次・技術ブログ | verified |
| S34 | AI-Assisted Fixes to Code Review Comments at Scale（Meta, MetaMateCR） | 2025-07 | https://arxiv.org/abs/2507.13499 | 論文 | verified（abstract） |
| S35 | Diff Risk Score (Meta) | 2025-08-06 | https://engineering.fb.com/2025/08/06/developer-tools/diff-risk-score-drs-ai-risk-aware-software-development-meta/ | 一次・技術ブログ | verified |
| S36 | Moving Faster and Reducing Risk: Using LLMs in Release Deployment（Meta） | 2024-10 | https://arxiv.org/abs/2410.06351 | 論文 | verified（abstract） |
| S37 | uReview (Uber) | 2025-08-12 | https://www.uber.com/blog/ureview/ | 一次・技術ブログ | verified |
| S38 | RovoDev Code Reviewer（Atlassian, ICSE-SEIP'26） | 2026-01 | https://arxiv.org/html/2601.01129v2 | 論文 | verified |
| S39 | What types of code review comments do developers most frequently resolve (Atlassian) | 2025-11-10 | https://www.atlassian.com/blog/atlassian-engineering/atlassian-rovo-dev-research-what-types-of-code-review-comments-do-developers-most-frequently-resolve | 一次・ブログ | verified |
| S40 | BitsAI-CR（ByteDance, FSE'25 industry） | 2025-01 | https://arxiv.org/html/2501.15134v1 | 論文 | verified |
| S41 | Benchmarking LLMs for Fine-Grained Code Review with Enriched Context (ContextCRBench) | 2025-11 | https://arxiv.org/abs/2511.07017 | 論文 | verified（abstract） |
| S42 | Automated Code Review In Practice（ICSE-SEIP'25） | 2024-12 | https://arxiv.org/abs/2412.18531 | 論文 | verified（abstract） |
| S43 | Does AI Code Review Lead to Code Changes? A Case Study of GitHub Actions | 2025-08（v2 2026-04） | https://arxiv.org/html/2508.18771v2 | 論文 | verified |
| S44 | "Go Home Copilot, You're Drunk": Developer Responses to Agent-Generated Review Comments | 2026-07-24 | https://arxiv.org/html/2607.21997v1 | 論文 | verified |
| S45 | SWR-Bench | 2025-09（v2 2026-06） | https://arxiv.org/html/2509.01494v2 | 論文 | verified |
| S46 | SWE-PRBench | 2026-03-27 | https://arxiv.org/abs/2603.26130 | 論文 | verified（abstract） |
| S47 | Code Review Agent Benchmark (c-CRAB) | 2026-03（v3 2026-04） | https://arxiv.org/abs/2603.23448 | 論文 | verified（abstract） |
| S48 | CR-Bench-v2 | 2026-11-02 | https://arxiv.org/html/2611.02566 | 論文 | verified |
| S49 | AACR-Bench | 2026-01 | https://arxiv.org/abs/2601.19494 | 論文 | verified（abstract） |
| S50 | OpenCodeReview: Determinism over Non-Determinism | 2026-08 | https://arxiv.org/abs/2608.09290 | 論文 | verified（abstract） |
| S51 | Bigger Isn't Always Better: LLMs for Automated Code Review | 2026-04 | https://arxiv.org/abs/2606.15689 | 論文 | verified（abstract） |
| S52 | Martian Code Review Bench README | 閲覧 2026-11-27 | https://github.com/withmartian/code-review-benchmark | OSS ベンチマーク | verified（gh api） |
| S53 | Every AI code review vendor benchmarks itself, and wins (DeepSource) | 2026-02-26 | https://deepsource.com/blog/ai-code-review-benchmarks | ベンダーによる批評 | verified |
| S54 | We compared the public AI code review benchmarks from 2026 | 2026 | https://medium.com/@codzee.io/we-compared-the-public-ai-code-review-benchmarks-from-2026-methodology-datasets-metrics-and-269dd35637a6 | 二次資料 | unverified-summary |

## 2. 調査結果

### a) 本番の AI レビューの構成

#### 共通する骨格

公開されている構成は、ほぼ同じ骨格を持つ。候補を並列に作り、別の段で検証して誤りを落とし、重複をまとめ、重大度で並べてから投稿する。投稿後の反応（直されたか、反対票か）を次の調整に戻す。

| システム | 候補の作り方 | 検証・フィルタ | 重複の扱い | 重大度・上限 | 出典 |
|---|---|---|---|---|---|
| Anthropic（基準線） | 複数エージェントが並列にバグを探す | 別のエージェント群が指摘ごとに投票し、十分に合意したものだけ投稿する。style / cleanup だけの指摘は落とす | 既に投稿した指摘は繰り返さない（仕組みは非公開） | Important / Nit / Pre-existing の札 | [verified] S1 |
| Claude Code Review | 複数エージェントが diff と周辺コードを並列に読む | verification 段が候補をコードと照合して偽陽性を落とす | 重複を除いてから重大度で順位付け | 重大度順。既定は正しさの問題に絞る | [verified] S4 |
| Cursor Bugbot（初期） | 8 本の並列パスを、それぞれ diff の順序を乱して回す | 1 本のパスだけが見つけたバグを多数決で落とす。コンパイラ警告や文書の誤りなどの区分を落とす。validator モデルで偽陽性を落とす | 似た指摘をまとめて 1 つの説明に統合し、過去の実行と突き合わせて重複を除く | 記述なし | [verified] S6 |
| Cursor Bugbot（現行） | 固定の段の代わりにエージェントが自分で調べる先を決める | 記述は少ない。エージェント版は慎重すぎたので、プロンプトを攻めの方向に直した | 既存の PR コメントを読んで重複を避ける | 記述なし | [verified] S6, S8 |
| GitHub Copilot | tool calling のエージェントがリポジトリを探索し、linked issue / PR も読む。レビューの計画を先に立てる | 記述は少ない。「沈黙はノイズより良い」を方針にしている | 同じ型の誤りを 1 単位にまとめる。過去のレビューの文脈を再利用する | 指摘ごとに重大度を表示する（S13）。尺度は非公開 | [verified] S9, S13 |
| Greptile v5 | 「1 エージェント = 1 つのバグ仮説」の群れで探す | 記述なし | 記述なし | 記述なし | [verified] S19 |
| CodeRabbit | code graph、埋め込み索引、チームのルール、linter の結果を文脈に入れる | エージェントが grep / ast-grep のチェックを自分で書き、前提を確かめてから投稿する | 記述なし | 5 段の重大度（critical〜informational）と profile による切り捨て（S22） | [verified] S20, S22 |
| Qodo 2.0 | 専門分野ごとのエージェントが別々の文脈を持つ | judge エージェントが衝突を解き、重複を除き、確信度と関連度の閾値を超えたものだけ残す | judge が除く | 種類（バグ、ルール違反、要件の抜け）と重大度で並べる | [verified] S23 |
| PR-Agent（OSS） | 単一の呼び出しが基本。大きい diff は分割して最大 3 回呼ぶ | `min_finding_confidence`（0〜10、既定 0 で無効） | 前回の指摘を最大 8000 文字ぶん文脈に入れ、言い換えての再指摘を防ぐ | 指摘は最大 6 件（`num_max_findings = 6`） | [verified] S25 L207-233 |
| Graphite | 作業を小さな段に分ける | 投票、推論の連鎖、自己批判で質の高い指摘だけ残す | 記述なし | 客観的なバグに絞り、主観的な提案を避ける | [verified]（ベンダーの主張） S29 |
| Uber uReview | 3 種のアシスタント（一般のバグ、社内の慣行、AppSec）が別々のプロンプトで作る | 別のプロンプトが質と確信度を採点する。閾値はアシスタント、言語、区分ごとに決める | 意味の近さのフィルタで重なりをまとめる | 過去に価値が低かった区分（可読性の nit、細かいログ、効果の小さい性能、style）を区分分類器で抑える | [verified] S37 |
| Atlassian RovoDev | Claude 3.5 Sonnet が zero-shot で作る | gpt-4o-mini の judge が事実の正しさを 2 値で判定する。ModernBERT の分類器が「コード変更につながるか」を判定する | 記述なし | 記述なし | [verified] S38 |
| ByteDance BitsAI-CR | LoRA で調整した RuleChecker が 219 のルールで検出する | 別に調整した ReviewFilter が指摘ごとに yes/no を返す | 512 次元の埋め込みの cosine 類似でまとめ、群から 1 件だけ残す | 41 区分（security / defect / maintainability / performance） | [verified] S40 |
| Google Sashiko（Linux kernel） | 計画役が最大 7 本の専門セッションを選び、推論の予算を配る。1 レビューで平均およそ 100 回の git ツール呼び出し | 主検証役が仕分け、明白なバグは通し、証明された却下は落とす。争いのあるものと根拠の弱い自己却下は、バグごとに別の検証エージェントへ回す | 記述なし | 報告はメンテナが問いかける形で書く | [verified] S33 |
| Microsoft（社内） | PR 作成時に自動で走り、diff の行にコメントする | 記述なし | 記述なし | 区分（例外処理、null チェック、機密データ）を付ける。重大度は記述なし | [verified] S31 |

補足:

- Sashiko は「却下の判断」にも証明を求める。却下の根拠が弱いものを落とさず、深い検証へ回す設計である [verified] S33。検証段が本物のバグを落とす事故を避ける工夫として、2〜3 レーンの統合にも当てはまる。
- Uber は 1 回のプロンプトでは幻覚と重複が出たため、「生成 → 採点 → フィルタ」の連鎖に移した [verified] S37。
- Greptile は、LLM 自身に 1〜10 の重大度を付けさせて 7 未満を落とす方法を試したが、評価はほぼでたらめで、呼び出しが 1 回増えて遅くなっただけだったと書いている [verified] S17。
- Cursor は初期の 8 本並列＋多数決から、エージェントが自分で調べる形へ移った [verified] S6。多数決は後継の設計では表に出ていない。

#### レビュアーに与える文脈

| システム | diff | リポジトリ全体の取得 | PR の意図（説明、issue） | 規約ファイル | 出典 |
|---|---|---|---|---|---|
| Anthropic（基準線） | あり | あり | PR に書かれた意図を読む | CLAUDE.md、REVIEW.md | [verified] S1 |
| Claude Code Review | あり | 周辺コードを読む。build や実行はしない | 記述なし | REVIEW.md は base / default ブランチから読み、PR 自身の変更からは読まない | [verified] S4 |
| Copilot | あり | エージェントが探索する | linked issue / PR を読む | copilot-instructions.md、`*.instructions.md`、AGENTS.md | [verified] S9, S15 / [unverified-summary] AGENTS.md の対応（検索結果） |
| Bugbot | あり | エージェントが動的に取りに行く | 記述なし | `.cursor/BUGBOT.md`（base ブランチから読む）、team rules、learned rules | [verified] S6, S8 |
| CodeRabbit | あり | code graph（定義と参照、同時に変わるファイル）、埋め込み索引（関数、テスト、過去の PR） | 記述は少ない | coding guidelines、path instructions、learnings | [verified] S20, S21 |
| Qodo 2.0 | あり | コードベース全体 | 過去の PR とレビューの反応を参照する推薦エージェント | 組織の標準 | [verified] S23 |
| RovoDev | あり | なし | PR のタイトルと説明、Jira の要約と説明 | レビューのガイドライン | [verified] S38 |
| Uber | あり | 近くの関数、クラス定義、import | 記述なし | 社内の style ルール集 | [verified] S37 |
| Sashiko | あり | 変更された関数、構造体、直接の呼び出し元、サブシステムのガイド | commit の意図を専門セッションの 1 つが見る | サブシステムのガイド | [verified] S33 |

文脈を足した効果の測定:

- Copilot はエージェント型の構成に変えただけで、肯定的な反応が当初 8.1% 増えた。推論の強いモデルに替えると肯定的な反応は 6% 増えたが、待ち時間が 16% 延びた [verified] S9。
- RovoDev のオフライン ablation では、プロンプトからレビューのガイドラインを抜くと人間の指摘との一致（%HAC LocationOnly）が 5 ポイント下がった。persona、chain-of-thought、PR 情報、Jira 情報を抜いた影響は 1〜3 ポイントにとどまった [verified] S38。
- SWE-PRBench（350 PR、8 モデル）では、diff だけから全文脈に増やすと 8 モデルすべての成績が下がった。2,000 トークンの「diff＋要約」の方が、2,500 トークンの全文脈より全モデルで良かった。著者は長いプロンプトで注意が薄まることを原因に挙げている [verified] S46。
- ContextCRBench は、コードの文脈より文章の文脈（issue や PR の説明）の方が成績を大きく上げると報告している。数値は abstract に無い [verified] S41。
- AACR-Bench は、文脈の粒度と取得方法の選び方が成績を大きく左右すると述べるが、abstract に数値は無い [verified] S49。
- 実地の調査では、解決されなかったエージェントの指摘を 470 件抜き出して分類すると、23.8% が「意図した設計」、14.3% が「誤った提案」だった。著者は設計の根拠や規約、レビュー履歴を文脈に入れることを勧めている [verified] S44。

### b) ノイズと精度

#### 測られた採用率（定義が違うので横に並べて比べない）

| システム | 数字 | 定義 | 出典 |
|---|---|---|---|
| Cursor Bugbot | resolution rate 52% →（2026-01）70% 超 →（2026-04）78.13% | 指摘されたバグが merge 時点の最終 diff で直っているかを LLM が判定 | [verified] S6, S7 |
| Cursor Bugbot | 1 回あたりの指摘 0.4 → 0.7 件、解決された指摘 0.2 → 0.5 件/PR | 同上 | [verified] S6 |
| Cursor による他社の測定 | Greptile 63.49% | Cursor が公開リポジトリだけで測った値 | [verified]（Cursor の主張として） S7 |
| Greptile（2024） | address rate 19% → 55% 超（埋め込みフィルタ導入後 2 週間） | merge 前に開発者が対応した割合。後続 commit の diff を走査して判定 | [verified] S17 |
| Greptile v3 → v4 | 30% → 43%、対応された指摘 0.92 → 1.60 件/PR | LLM が対応の有無を判定 | [verified] S18 |
| Greptile v4 → v5 | 52% → 66% | 約 1 か月、100 万 PR 超の A/B | [verified] S19 |
| Copilot | レビューの 71% で対応すべき指摘が出る。残り 29% は何も書かない。平均 5.1 件/レビュー | 「actionable」の定義は無い | [verified] S9 |
| Uber uReview | 「役に立つ」75%、対応された 65%。人間の指摘は 51% | 最終 commit で uReview を 5 回走らせ、どの回にも同じ意味の指摘が出なければ対応済みとみなす | [verified] S37 |
| Atlassian RovoDev | 38.70%（人間の指摘は 44.45%） | コードの変更につながった割合。54,000 件超、2,000 リポジトリ超 | [verified] S38 |
| Atlassian RovoDev | 種類別では可読性、バグ、保守性が 36〜43% で高い。設計の指摘は低い | 同上 | [verified] S39 |
| Google AutoCommenter | resolution 推定 約 40%（50% × 80%）。明示の反応は 10% にしか付かない。useful ratio 54% → 66%（開発者）、60% → 74%（評価者）、のちに 80% 超 | AST で行を対応づけ、40 件を人手で確かめた推定 | [verified] S32 |
| ByteDance BitsAI-CR | precision の最高 75%。Outdated Rate（指摘行が後で変わる割合）26.7%、人間は 35〜46% | 1 週間の窓で測る | [verified] S40 |
| ICSE-SEIP'25 の事例（PR-Agent ベース） | 73.8% が resolved。PR を閉じるまでの平均時間は 5 時間 52 分から 8 時間 20 分に延びた | 開発者のラベル | [verified] S42 |
| GitHub Actions の 16 ツール | 有効な AI 指摘の対応率 0.9〜19.2%。人間の指摘は 60.0% | LLM 2 段で判定（人手 150 件で 91.5% 一致） | [verified] S43 |
| 公開リポジトリのエージェント（54,713 件） | スレッドの resolve 率 Copilot 72.9%、Cursor 67.2%、Codex 54.8% | GitHub 上でスレッドを resolve した割合。コードが直ったかは問わない | [verified] S44 |
| Graphite | 実装率 67%、肯定的な反応 96% | ベンダー事例の数字 | [verified]（ベンダーの主張） S29 |
| Graphite | 採用率 約 52%（人間は 45〜50%）、反対票 4% 未満 | 講演の要約 | [unverified-summary] S30 |
| Anthropic | 人が誤りとした指摘は 1% 未満。1,000 行超の PR の 84% に指摘（平均 7.5 件）、50 行未満は 31%（平均 0.5 件） | 自社内 | [verified] S3 |

#### ノイズを減らして役立ち度を上げた手段（測定つき）

- 過去の反対票との近さで落とす（Greptile）: チームごとに過去の指摘を埋め込み、反対票の付いた 3 件以上と似ていれば落とし、賛成票 3 件と似ていれば通す。address rate が 2 週間で 19% から 55% 超に上がった。プロンプトの調整と few-shot は効かず、LLM の自己採点もほぼでたらめだった [verified] S17。引用: "most nits can be placed into a small number of clusters"。
- 区分と規則の単位で止める（Google、ByteDance、Uber）:
  - Google は評価者の調査で「対応のしようがない」17 の規則 URL を見つけて止め、似た 5 つも止めた。止め方は正規表現の条件で、再学習なしにすぐ反映できた。useful ratio は 54% から 66%（開発者）、60% から 74%（評価者）に上がった [verified] S32。
  - Google は全体で 1 つの確信度の閾値（0.98）から、規則 URL ごとの閾値に切り替えた。全体の閾値の下で落としていた予測の約 80% が実は正しかったためである [verified] S32。
  - ByteDance は 14 日の窓で precision 約 65% ±5%、Outdated Rate 約 25% ±5% を目安にし、成績の悪い規則を外した。RuleChecker 単体の precision は 27.9% から 62.6% に、ReviewFilter 後は 35.6% から最高 75% に上がった [verified] S40。
  - Uber は可読性の nit、細かいログ、効果の小さい性能、style の区分を抑えた。正しさのバグ、エラー処理の抜け、慣行の違反は評価が高かった [verified] S37。
- 「変更につながるか」の分類器（Atlassian）: 5 か月分 50,000 件超のコメントを「コード変更につながったか」でラベルづけし、ModernBERT を調整した。オフラインで人間の指摘との一致が 15〜20 ポイント上がった。事実の正しさを見る LLM judge の効果は小さかった [verified] S38。
- 生成と別の採点役（Uber）: 金の評価セットで F1 が最も高かったのは、生成に Claude-4-Sonnet、採点に o4-mini-high を使う組み合わせだった。採点役を GPT-4.1 にすると 4.5 ポイント下がった [verified] S37。
- 細かく見る単位（GitHub Actions の研究）: hunk 単位のツールは対応率 6.5〜19.2%、ファイル単位のツールは 0.9〜4.2% だった [verified] S43。

#### コメントの形と採用率

- コードの割合が高いコメントほど対応された（相関 ρ = 0.89）。コードの割合が 0 だと 4.2%、0.52 を超えると 23.2% だった。文章の長さは弱い負の相関（ρ = −0.24）だった [verified] S43。
- インラインのコード提案は resolve を最もよく予測した（オッズ比 1.62）。長さは小さな負の効果（オッズ比 0.93）だった。採用されなかったコメントは平均 807 文字、役に立ったものは 617 文字だった [verified] S44。
- 大量のコメントが来ると開発者は全部を無視しがちになる、と ByteDance は書いている [verified] S40。引用: "developers tend to ignore review comments entirely when faced with numerous comments"。

#### 重大度の札の使われ方

- CodeRabbit の profile は、重大度で投稿を切る構造的な手段である。`quiet` は critical と major だけをインラインに出し、残りは要約に畳む。`chill`（既定）は minor まで最大 20 件に絞り、超えた分は minor、major の順に畳む。`assertive` は全部出す。docs は、指示ファイルは文面を導くだけで、件数を決めるのは profile だと明記している [verified] S22。
- Copilot の Lite の ensemble は、重大度ごとに効果が違った。対応された指摘は high で 47%、medium で 31%、low で 11% 増え、費用は約 8% 減った [verified] S12。
- ReviewBench は Critical / Medium / Low と区分（Correctness、Security、Reliability、Maintainability、Testing）を付け、重大度と区分ごとに結果を切って見ることを勧めている。オフラインでは critical の指摘が 227% 増えると予測し、本番では 262% 増えた [verified] S10。
- Sashiko の本番 7 か月では、critical の警告が出たのに merge されたパッチは 60 日以内に修正が要った割合が 7.6% で、指摘なしのパッチの 0.9% の約 8 倍（パッチの大きさで補正すると 6.3 倍）だった。指摘なしのパッチの 0.9% は、過去の基準 3.4% より低い [verified] S33。重大度の札が実際のリスクと結びついている根拠になる。
- Anthropic（基準線）は Pre-existing の札で、PR が持ち込んでいない既存のバグを作者の責任にしないようにしている [verified] S1。Copilot も overview に「Previously missed」（新しい commit が入れていない既存の問題）の区分を持つ [verified] S13。
- 変更単位のリスク予測（Meta DRS）: 素朴な回帰モデルでも、リスクの高い上位 5% の diff を止めると SEV の 18.7%、上位 10% で 27.9%、上位 50% で 84.6% を捕まえた [verified] S36。LLM 版の倍率は abstract の記述から対応が読み取れなかった。本番ではフリーズ期間中に、以前は出せなかった 10,000 件超の変更を、本番への影響を小さく抑えて出した [verified] S35。

### c) 収束と往復

- Anthropic（基準線）: 往復は 3 回で打ち切る。最初の数回のあとは diff だけを見直す。1 行ごとでなくバグの型で指摘する。同じ指摘を繰り返さない。1 回のレビューと修正で通る割合は 65% から 78%、5 回以上かかる PR は 8.9% から 1.5%、通るまでのレビュー回数の平均は 2.08 から 1.32 になった [verified] S1。3 回で通らなければ人に渡す。レビュー結果は調べた commit にだけ有効とする [verified] S2。
- Bugbot: 既定は増分レビューで、前回の Bugbot レビュー以降の変更だけを見る。既存のトップレベルとインラインのコメントを読んで重複を避ける。CI の成功には、前回までの未解決の Bugbot コメントが残っていないことが必要になる。`oncePerPr` で 1 回だけにもできる。Autofix は既存ブランチへの commit を PR あたり 3 回までに制限する [verified] S8。
- CodeRabbit: 増分レビューが既定で、レビューした commit が 5 つに達すると自動レビューを止める。活発な PR の例として、この値を 2 にする設定が挙がっている [verified] S22。
- PR-Agent: `persistent_finding_state` で過去の指摘の状態を保つ。前回までの指摘を最大 8000 文字ぶん文脈に入れ、同じ指摘を言い換えて出し直すのを防ぐ。PR-Agent 以外の人が resolve したスレッドの指摘は飛ばす。要約の先頭に「前回から」の区分（対応済み、再発、未対応、新規）を出す [verified] S25 L207-213。
- Copilot: 後の push で直った指摘は再レビュー時に自動で resolve する [verified] S12。overview は Open、Resolved since last review、Previously missed に分け、新しい commit や再依頼をまたいで進み具合を保つ。後の commit を見て「Won't Fix」や「Incorrect」として resolve することもある [verified] S13。push の度に自動で再レビューするかは、ruleset の設定次第である [unverified-summary]（検索結果の要約）。
- 収束しない例: Copilot の利用者が、push の度に diff 全体を読み直し、前に指摘していなかったコードに新しい指摘が出ると報告している。ある PR では 5 回の往復で 10、6、4、2、2 件（計約 24 件）が出て、役に立ったのは約 3 件だった。GitHub の担当者からの回答は無い [verified] S16。引用: "every push to a PR triggers a full re-scan of the diff"。
- Claude Code Review: 自分の過去のスレッドを resolve する。push によっては前回の結果をそのまま使う。実行の時機は「PR 作成時に 1 回」「push の度」「手動」から選べ、「push の度」は push の回数だけ費用が増える [verified] S4, S5。
- Cursor（初期）: 過去の実行と突き合わせて重複を除く段を持っていた [verified] S6。
- Google Jules の critic: 生成したパッチを敵対的に見直し、問題が残る限り差し戻す。いまの版は 1 回で評価する形で、回数の数字は無い [verified] https://developers.googleblog.com/en/meet-jules-sharpest-critic-and-most-valuable-ally/（2025-08-12）。

### d) レビュアーへの指示のチューニング

#### リポジトリごとの指示ファイル

- Copilot: 短く焦点を絞り、小さく始めるよう勧めている。見出しと箇条書き、短い命令形の規則、良い例と悪い例のコードを使う。外部リンクは辿らないので中身を写す。「もっと正確に」「すべての問題を見つけよ」のような曖昧な指示はノイズを増やす。約 1,000 行を超えると振る舞いが不安定になりうる [verified] S15。読み込みの上限 4,000 文字は 2026-06-12 に撤廃された [verified] S11。
- Bugbot: `.cursor/BUGBOT.md` を base ブランチから読むので、PR が自分のレビュー規則を変えられない。規則 1 つは 30,000 文字まで、合計 100,000 文字まで。優先順は team rules、BUGBOT.md、learned rules、手動の規則 [verified] S8。
- Claude Code Review: REVIEW.md を base / default ブランチから読み、PR の変更からは読まない [verified] S4。Anthropic（基準線）の REVIEW.md は、そのリポジトリでの「失敗」を定義し、nit の数に上限を設け、飛ばすパスを並べ、ファイルと行の根拠を求める [verified] S1。
- CodeRabbit: path instructions は文面を導くだけで、件数を決めるのは profile である [verified] S22。
- Microsoft: チームがリポジトリごとの指針とプロンプトを渡せる。例として、過去のクラッシュの型に基づく後退の確認や、flight と change gate の確認を挙げている [verified] S31。

#### 過去の見逃しや人の指摘から規則を学ぶ

- Bugbot の learned rules: 反応（反対票）、開発者の返信、Bugbot が見逃したバグを人が指摘したコメント、の 3 つから候補の規則を作る。候補は届いた PR で試し、信号がたまると有効にする。有効な規則に否定的な信号が続くと無効にする。11 万を超えるリポジトリで有効化され、44,000 を超える規則ができた。resolution rate は 52% から 78.13% に上がったが、learned rules だけの寄与は分けて示されていない [verified] S7。引用: "each review is a natural experiment"。
- CodeRabbit の learnings: 返信や `@coderabbitai` への指示から好みを保存し、コメントを出す前に範囲に合うものを読み込む。管理者の承認待ちにも設定できる。1 PR が読む最新の learnings は 20 件までである [verified] S21。
- Qodo の auto best practices: 採用された提案を毎月まとめて、リポジトリ固有の慣行を作る。数値は無い [unverified-summary] S26。
- Google AutoCommenter: 人間のレビューで参照された慣行の URL から学ぶ。330 の URL に対して指摘を出し、慣行 URL を含む過去の人間のコメントの 68% を覆う [verified] S32。
- Anthropic（基準線）: 人のコメントや revert から型を掘る場合、2 件以上の PR に現れ、diff から検出できることを条件にする。3 つのエージェントが反証を試み、人が PR で承認する。既知の障害に結びつく PR に 3 本のバグ探索役を当て、2 本以上が見つければ「検出できる」とみなす [verified] S2。
- ByteDance（ContextCRBench を使った自己進化型のレビュー）: 本番で 61.98% 改善したとあるが、基準と指標は abstract に無い [verified] S41。

#### 測られた効果

- 指示ファイルの効果を単独で測った公開の数字は、RovoDev の ablation（ガイドラインを抜くと 5 ポイント低下）しか見つからなかった [verified] S38。
- 規則を止める、閾値を規則ごとにする、区分を抑える、という「減らす方向」の調整には測定がある（b を参照）。Google、ByteDance、Greptile の数字がそれに当たる。

### e) レビュアーの評価方法

#### 公開されているベンチマーク

| 名前 | 規模 | 作り方 | 指標 | 主な結果 | 出典 |
|---|---|---|---|---|---|
| ReviewBench（GitHub） | 187 リポジトリの 219 PR、19 言語 | 人のレビュー、後続 commit から推した問題、静的解析、複数の LLM から候補を集め、意味で重複を除き、LLM が 1 つの基準で判定 | grounded / augmented の precision、recall、F1、Fβ | 独立した上級エンジニアの再ラベルと 96.6% 一致。オフラインの予測と本番の向きが一致した例を示す | [verified] S10 |
| Martian Code Review Bench（offline） | 5 リポジトリの 50 PR、正解コメント 173 件 | 人が確かめた正解コメントに重大度と区分を付ける。3 つの judge モデルで評価 | precision、recall、F-beta、区分の profile（Strict / Core / All） | 3 つの judge で上位 5 ツールは同じ | [verified] S52 |
| Martian Code Review Bench（online） | 継続的に新しい PR を採る | bot の指摘と、その後の開発者の修正を LLM が対応づける | 「行動された指摘」を precision の代わりに使う | 学習データへの漏れを避ける | [verified] S52 |
| SWR-Bench | 1,000 PR（変更のある 500＋問題のない 500） | 問題のない PR は大きさを合わせて抽出し、SZZ で見逃された欠陥を除く。そこへの指摘は偽陽性として数える | LLM judge による F1。人との一致 約 90% | 最良の単発で F1 約 19〜21%。同じモデルで 10 回のレビューを集約すると F1 が相対 43.67%、recall が相対 118.83% 上がった | [verified] S45 |
| CR-Bench / CR-Bench-Verified | 584 件 / 174 件 | SWE-Bench の issue を PR レビューの課題に作り直す | KDDR（既知の欠陥の検出率）、Usefulness Rate | 最良でも KDDR 約 33%。Gemini Code Assist は有用率 78.0% だが KDDR 8.1%。自己批判（Reflexion）は KDDR を 2.9〜12.6 ポイント上げた。judge は 3 つで、順位の向きは合うが絶対値は合わない | [verified] S48 |
| SWE-PRBench | 350 PR | 人が指摘した問題との一致 | LLM judge（κ = 0.75） | diff だけで人の指摘の 15〜31% を検出。文脈を増やすと全モデルで低下 | [verified] S46 |
| c-CRAB | 不明 | 人のレビューから作り、生成したテストで確かめる | 解けた課題の割合 | 既存のエージェント全部合わせても約 40% | [verified] S47 |
| AACR-Bench | 200 PR、1,505 件（S50 による） | AI 支援＋専門家の確認で、元の PR が見逃した欠陥も拾う | — | 欠陥の網羅が 285% 増えた | [verified] S49, S50 |
| Qodo benchmark | 100 PR、580 件、7 言語 | 実際に merge された PR（revert や直後の修正が無いもの）に、LLM でルール違反と 1〜3 個の機能バグを注入 | LLM judge。ファイルと行が合い、内容が正しいときだけ命中 | Qodo の F1 60.1%。他社の値は図だけ | [verified] S24 |
| Sashiko の内部ベンチマーク | 約 1,000 件の kernel のバグ | 人のレビューを通って mainline に入り、後で直されたバグ | 人が見逃したバグの検出率 | 75.8% | [verified] S33 |
| Cursor BugBench | 不明 | 実際の diff に人がバグを注記 | オフライン評価用 | 規模は非公開 | [verified] S6 |

#### 評価の作り方で数字が裏付けられているもの

- 正解の作り方として、障害や revert、後の修正から作る方法が繰り返し使われている。Anthropic（基準線）は障害や revert を起こした PR と修正を集め、毎日回す [verified] S1。Sashiko は後で直された kernel のバグ約 1,000 件を使う [verified] S33。SWR-Bench と CR-Bench も同じ系統である [verified] S45, S48。
- 問題のない変更の対照群を持つと偽陽性を数えられる。SWR-Bench は問題のない PR を 500 件、大きさを合わせて入れている [verified] S45。Anthropic（基準線）は merge されて安定した変更を対照に使い、大きさを合わせた問題なしの部分集合も追う [verified] S2。Sashiko は本番で、指摘なしのパッチが 60 日以内に修正された割合（0.9%、過去は 3.4%）を見ている [verified] S33。
- 段ごとの recall を分けて測るのは、Anthropic（基準線）の「生の候補、検証後、最終」の 3 段だけで、数値の公開は無い [verified] S2。RovoDev は段ごとの ablation をオフラインの一致率で示している [verified] S38。BitsAI-CR は RuleChecker 単体と ReviewFilter 後の precision を分けて示している [verified] S40。
- 合成のバグと実際のバグの差は大きい。最良のモデルでも合成のサンプルで F1 0.847、実際の PR で 0.066 だった。diff が 10 行未満なら F1 0.657、150 行を超えると 0.043 だった [verified] S51。同じ論文で、小さく安い Haiku 4.5 が Sonnet 4.6 より F1 が高く（0.365 対 0.343）、recall が 18% 高く、費用は 3.2 分の 1 だった [verified] S51。
- judge の扱いについては、CR-Bench-v2 が judge どうしで絶対値が合わないことを示し、同じ judge の中で対にして比べることを勧めている [verified] S48。Martian は judge ごとに結果を保存し、どの judge を使ったかを記録する [verified] S52。
- ベンダーの自社ベンチマークには偏りがある。Greptile が自社で示した 82% の recall は、Augment が同じリポジトリで測ると 45% だった。DeepSource は 100 件未満のベンチマークを疑うよう勧めている。これは経験則で、根拠のある閾値ではない [verified] S53。引用: "Each vendor runs their own benchmark, on their own dataset, and wins."
- オフラインとオンラインのずれ: Martian はオフラインの結果が実地とずれたので、オンラインを主な指標にした [unverified-summary]（検索結果の要約）。README は 2 つで互いを確かめる設計だと述べる [verified] S52。GitHub は、オフラインの結果が本番と同じ向きを指し続けたと書いている [verified] S10。
- 対応率の測り方:
  - Uber は最終 commit で 5 回走らせて再現しないものを対応済みとした。5 回は見逃しをほぼ無くせる最小の回数として選んだ [verified] S37。
  - Cursor は LLM の判定を作者への聞き取りで抜き取り確認し、ほぼ全部正しかったとしている [verified] S6。
  - GitHub Actions の研究は人手 150 件で 91.5% の一致を確かめた [verified] S43。
  - Google は明示の反応が 10% にしか付かないので、反応ボタンだけに頼らない推定を作った [verified] S32。

### f) コストと待ち時間

| システム | 費用 | 待ち時間 | 出典 |
|---|---|---|---|
| Claude Code Review | 平均 15〜25 ドル/レビュー（2026-03 時点）。docs では定額なしで、レベル、変更の大きさ、周辺コードの複雑さ、検証が要る候補の数で変わる。「push の度」は push の回数だけ増える | 平均約 20 分（2026-03 時点） | [verified] S3, S5 |
| Copilot | 2026-06-01 から AI Credits と Actions minutes（private リポジトリ）で課金。推論の強いモデルへの切り替えで待ち時間が 16% 延びた。ensemble の A/B で 1 レビューあたりの費用が 8% 減った | 記述なし | [verified] S14, S9, S10 |
| Bugbot | 使用量で課金。effort が高いほど高い。大きすぎる PR は飛ばし、その分は課金しない | 記述なし | [verified] S8 |
| Greptile | 1 開発者あたり月 30 ドルで 50 レビュー込み、超過は 1 レビュー 1 ドル | v5 で中央値 5:04 → 2:25（単位の表記がページで曖昧） | [verified] S18, S19 |
| Uber uReview | 一般的な外部ツールより 1 桁安い（絶対値なし） | 中央値 4 分 | [verified] S37 |
| BitsAI-CR | 記述なし | 結論を先に出す形で 1 件 1.7 秒、推論を先に出す形で 31.0 秒 | [verified] S40 |
| Graphite | 記述なし | 1 時間から 90 秒へ | [verified]（ベンダーの主張） S29 |
| Sashiko | 運営者が負担。深いレビューには大きなトークン予算が要る | 記述なし。1 日約 1,200 レビュー | [verified] S33 |
| OpenCodeReview | エージェント型の基準よりトークンが 5〜15 分の 1 | 記述なし | [verified] S50 |
| SWR-Bench の集約 | 回数 n に比例して呼び出しが増える。n = 5 で F1 20.48%、n = 10 で 21.91%（同じモデル） | — | [verified] S45 |

## 3. 2〜3 レーン構成で採れる実践（根拠つき）

1. レーンは候補を作る役に限り、統合したあとに指摘ごとの検証段を別に置く。採るかどうかをレーン間の多数決で決めない。
   - 根拠: Anthropic（基準線）、Claude Code Review、Cursor 初期、Sashiko、BitsAI-CR、RovoDev、Uber は、どれも生成と検証を分けている（S1, S4, S6, S33, S40, S38, S37）。同じモデルで回数を重ねると recall が大きく上がり（10 回で相対 118.83%）、precision の改善は残課題になった（S45）。Copilot の多モデル ensemble は recall +13.6%、対応率 +8.0% だったが、コメント量も +61% になった（S10）。
   - 2〜3 本で多数決をとると、1 本だけが見つけた本物のバグが消える [speculation]。Cursor の多数決は 8 本のときの設計だった（S6）。Sashiko は争いのある指摘を落とさず、指摘ごとの深い検証へ回す（S33）。
   - 反対の根拠もある。Anthropic（基準線）は、レビュアーを重ねるより 1 本を調整する方が良いことが多いと書いている（S2）。レーンを増やす前に、1 本の調整で足りるかを測る価値がある。
2. 統合では、意味の近さで重複を除き、同じ型の指摘を 1 件にまとめる。
   - 根拠: BitsAI-CR は 512 次元の埋め込みで cosine 類似をとり、群から 1 件だけ残す（S40）。Uber は意味の近さのフィルタを使う（S37）。Copilot は同じ型の誤りを 1 単位にまとめる（S9）。Anthropic（基準線）は 1 行ずつでなくバグの型で指摘する（S1）。
3. 検証役は生成役と別のモデルにし、却下の判断にも根拠を求める。
   - 根拠: Uber では生成 Claude-4-Sonnet、採点 o4-mini-high の組み合わせが F1 最良で、別の採点役より 4.5 ポイント高かった（S37）。Sashiko は根拠の弱い自己却下を深い検証へ回す（S33）。OpenCodeReview は、探索の経過を見せずに diff だけを渡す反省役を置き、自己強化の偏りを避けている（S50）。
4. LLM 自身に付けさせた重大度の点数だけで切らない。区分や規則の単位で、過去の対応率をもとに止める。
   - 根拠: Greptile の自己採点による切り捨てはほぼでたらめだった（S17）。区分や規則の単位で止めたものは測定で効いた。Google は 54% から 66%（S32）、ByteDance は precision が 27.9% から 62.6%、ReviewFilter 後は 75%（S40）、Greptile は 19% から 55%（S17）、Uber は nit の区分を抑えた（S37）。
5. 重大度ごとに見せ方を変え、件数に上限を設ける。nit は畳むか要約にまとめる。
   - 根拠: CodeRabbit の `chill` は 20 件まで、`quiet` は critical と major だけをインラインに出す（S22）。PR-Agent の既定は最大 6 件（S25）。ByteDance は、大量のコメントで全部が無視されると報告している（S40）。Copilot の ensemble の効果は high で +47%、low で +11% と、重大度で大きく違った（S12）。
6. 往復は増分で見直し、回数に上限を設け、前回の指摘を文脈に入れる。
   - 根拠: Anthropic（基準線）は 3 回で打ち切り、diff だけを見直し、繰り返さない。5 回以上かかる PR が 8.9% から 1.5% に減った（S1）。Bugbot は前回以降の差分だけを見て、既存のコメントを読む（S8）。CodeRabbit は 5 commit で止まり、2 にする例も載せている（S22）。PR-Agent は前回の指摘を 8000 文字まで入れて、言い換えての再指摘を防ぐ（S25）。この仕組みが無い場合の失敗例が S16 で、5 回の往復で約 24 件出て、役に立ったのは約 3 件だった。
7. 「既存の問題」「前回見逃した問題」を別の札にして、PR の作者に負わせない。
   - 根拠: Anthropic の Pre-existing（S1）、Copilot の Previously missed（S13）。
8. 指示ファイルは base ブランチから読み、短い命令形と良い例・悪い例で書く。数を絞る仕組みは指示とは別に持つ。
   - 根拠: Bugbot と Claude Code Review は base から読む（S8, S4）。Copilot の書き方の指針（S15）。CodeRabbit は、指示は文面を導くだけで、件数は profile が決めると明記している（S22）。
9. 文脈は多ければ良いわけではない。意図（PR の説明、issue、設計の根拠）を優先し、コードの全文は要約して渡す。
   - 根拠: SWE-PRBench では diff と要約の方が全文脈より良かった（S46）。ContextCRBench では文章の文脈の方が効いた（S41）。未解決の指摘の 23.8% は「意図した設計」だった（S44）。RovoDev ではガイドラインの寄与（5 ポイント）が PR や Jira の情報（1〜3 ポイント）より大きかった（S38）。
10. 指摘はコードの提案つきで、短く、hunk 単位で書かせる。
    - 根拠: コードの割合と対応率の相関は ρ = 0.89（S43）。インライン提案のオッズ比は 1.62（S44）。hunk 単位とファイル単位で対応率に差がある（S43）。
11. レーンと区分ごとに「対応率」を記録する。反応ボタンだけに頼らない。
    - 根拠: 明示の反応は 10% にしか付かない（S32）。最終 diff を LLM が判定する方法（S6, S17, S43）や、最終 commit で再実行して再現しない指摘を対応済みとみなす方法（Uber は 5 回、S37）が使われている。小さなチームでは、merge 時に「各レーンの指摘のうち最終 diff で直ったもの」を LLM に判定させるだけでも、レーンごと・区分ごとの対応率が出せる [speculation]。
12. 評価セットは過去の revert や障害の修正から作り、大きさを合わせた問題なしの変更を対照に入れる。judge は 1 つに固定して、対で比べる。
    - 根拠: S1, S2, S33, S45（問題なし 500 件）、S48（judge 間で絶対値が合わない）。合成のバグでは成績が過大に出る（S51、0.847 対 0.066）。
13. 重大度の札は後から答え合わせができる。重大な指摘を残したまま merge したものの後の修正率を追う。
    - 根拠: Sashiko では 7.6% 対 0.9% で、約 8 倍の差があった（S33）。ReviewBench の予測 227% と本番 262% の比較（S10）。変更単位のリスク予測は Meta の DRS（S35, S36）。
14. 費用は、実行の時機（PR ごとに 1 回か push の度か）と深さで制御する。小さいモデルが勝つことがある。
    - 根拠: Claude Code Review の「push の度」は push の回数だけ費用が増える（S5）。Haiku 4.5 は Sonnet 4.6 より F1 が高く、費用は 3.2 分の 1 だった（S51）。決まった手順の部分を固定するとトークンが 5〜15 分の 1 になった（S50）。

## 4. 見つからなかったもの

- 主要ベンダー（CodeRabbit、Copilot、Bugbot）が、同じ基準で測った偽陽性率を公開した一次資料は見つからなかった。CodeRabbit は自社の採用率も一次資料では見つからなかった。
- Graphite の技術ブログで数字つきのものは見つからなかった。数字は講演の要約ページ（S30）とベンダー事例（S29）、提携先のページ（S27）にしか無い。
- Microsoft の社内レビュアーの採用率、偽陽性率、評価セットは公開されていない（S31 は PR 完了時間の 10〜20% 改善と規模だけ）。ReviewBench に Microsoft が関わったという記述は二次資料にしか無く、その記事は 403 で開けなかった。
- Google の Critique で動く LLM レビュアーについて、AutoCommenter（2024、S32）と Sashiko（2026-11、kernel 向け、S33）以外の 2025〜2026 年の一次資料は見つからなかった。
- Meta は、レビューコメントを生成する AI の採用率を公開していない。見つかったのは、指摘への修正パッチ（MetaMateCR、S34）とリスク予測（DRS、S35, S36）だけである。
- 段ごとの recall（生成、検証後、最終）を数値で公開した例は見つからなかった。Anthropic（S2）は方法を書くだけで、数値は出していない。
- 異なるモデルどうしを集約した結果（SWR-Bench の Multi-Agg）は図にしか無く、本文に数値が無かった（S45）。
- 往復の回数の上限を変えたときの効果を、Anthropic（S1）以外で測った資料は見つからなかった。
- 指示ファイル（REVIEW.md や copilot-instructions.md など）の有無で precision がどう変わるかを、RovoDev の ablation（S38）以外で測った資料は見つからなかった。
- Copilot、Bugbot、CodeRabbit の 1 レビューあたりの金額は見つからなかった。料金体系の記述だけである。
- Qodo の benchmark で他社の precision と recall の値は図だけにあった。Precise モードで 74.5% / 44.2%、Exhaustive モードで 63.8% / 56.7% という数字は二次資料（S54）にしか無い [unverified-summary]。
- Martian のオンライン順位（CodeRabbit の F1 51.2%、Greptile の F1 60.8% など）はベンダーの主張としてしか確認できなかった [unverified-summary]。
- 調べなかった範囲: Augment、Macroscope、Propel、Entelligence、Baz、CodeAnt の自社ベンチマークの一次資料、Google の ML-suggested edits（2023）、学術の古いベンチマーク（CodeReviewer 2022 など）。

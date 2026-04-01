---
title: Harness engineering research notes
date: 2026-03-28
status: in-progress
reading_list: https://x.com/shodaiiiiii/status/2037407745704362112
---

# Harness engineering research

Files under [`category-1/`](./category-1/) and [`category-2/`](./category-2/) are **snapshots of primary articles** produced by dropping **HTML→markdown captures** (mostly **Cursor WebFetch**; some URLs used **`r.jina.ai/http…`** where noted in `note:`) into the repo. There is **no translation** and **no manual summarization** of the thesis; only YAML metadata is prepended (`source_url`, `fetched_at`, `capture`).

## Regenerating captures

When a page changes or fetch quality drifts, re-run the same URL through WebFetch (or another HTML→markdown pipeline), replace the body, and bump `fetched_at`. Optional: strip site chrome (newsletter blocks, duplicate nav) if it clutters agent context—note that in frontmatter `note:` if you do.

## Reading list master index（全33本）

Source: [@shodaiiiiii / X](https://x.com/shodaiiiiii/status/2037407745704362112) (2026-03-27). Summaries below follow that post (notebook-style). Rows **#1–19** have repo snapshots under `category-1/` and `category-2/`; **#20–33** are link-only (no Markdown capture here; see **Category 3・4 policy** below).

### 1. 英語の一次情報・重要記事（7本）

| 番号 | タイトル | 概要 | URL | Snapshot |
|---|---------|------|-----|----------|
| 1 | Harness engineering: leveraging Codex in an agent-first world (Ryan Lopopolo / OpenAI, 2026/2/11) | **最重要記事**。人間が1行もコードを書かない制約で5ヶ月・100万行のプロダクト構築。AGENTS.md設計、カスタムリンター、ドキュメントガーデニング等の具体的構成要素を詳述 | https://openai.com/index/harness-engineering/ | [`category-1/01`](./category-1/01-openai-harness-engineering.md) |
| 2 | Harness Engineering (Birgitta Böckeler / Martin Fowler, 2026/2/17) | OpenAI記事の批評的考察。ハーネスが将来のサービステンプレートになる可能性、テックスタックの収束、既存コードベースへの適用の難しさを論じる | https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html | [`category-1/02`](./category-1/02-martin-fowler-harness-engineering.md) |
| 3 | Harness design for long-running application development (Prithvi Rajasekaran / Anthropic, 2026/3/24) | GANに着想を得た「ジェネレーター＋エバリュエーター」のマルチエージェント構造。フロントエンドデザインの主観的品質評価と長期実行エージェントの設計を解説 | https://www.anthropic.com/engineering/harness-design-long-running-apps | [`category-1/03`](./category-1/03-anthropic-harness-design-long-running-apps.md) |
| 4 | Effective harnesses for long-running agents (Anthropic, 2025/11/26) | ハーネス設計の初期の記事。イニシャライザーエージェントとコーディングサブエージェントの分離、コンテキストウィンドウ管理の手法を紹介 | https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents | [`category-1/04`](./category-1/04-anthropic-effective-harnesses-long-running-agents.md) |
| 5 | My AI Adoption Journey (Mitchell Hashimoto, 2026/2/5) | AI導入の段階的なジャーニーを語り、「エージェントがミスしたら二度と繰り返さない仕組みを作る」というハーネスの本質を提唱 | https://mitchellh.com/writing/my-ai-adoption-journey | [`category-1/05`](./category-1/05-mitchell-hashimoto-ai-adoption-journey.md) |
| 6 | The Emerging "Harness Engineering" Playbook (Charlie Guo / Artificial Ignorance, 2026/2/22) | プロンプト→コンテキスト→ハーネスへの進化の歴史と、現在のプレイブックを俯瞰的にまとめた良記事 | https://www.ignorance.ai/p/the-emerging-harness-engineering | [`category-1/06`](./category-1/06-charlie-guo-emerging-harness-playbook.md) |
| 7 | Improving Deep Agents with harness engineering (LangChain, 2026/2/17) | LangChainのコーディングエージェントがハーネス改善だけでTerminal Bench 2.0のTop 30からTop 5に躍進した事例。数値でハーネスの実効性を示す | https://blog.langchain.com/improving-deep-agents-with-harness-engineering/ | [`category-1/07`](./category-1/07-langchain-improving-deep-agents-harness.md) |

### 2. 英語の補足記事・深掘りリソース（12本）

| 番号 | タイトル | 概要 | URL | Snapshot |
|---|---------|------|-----|----------|
| 8 | Harness Engineering: The Missing Layer Behind AI Agents (Louis-François Bouchard, 2026/3/25) | Prompt / Context / Harness Engineeringの違いを最も分かりやすく整理した記事 | https://www.louisbouchard.ai/harness-engineering/ | [`category-2/01`](./category-2/01-louis-bouchard-harness-engineering-missing-layer.md) |
| 9 | The Rise of AI Harness Engineering (Cobus Greyling / Medium, 2026/3/12) | ハーネスをAIエージェントがプロダクション環境で実際に動くかを決定する「欠けたアーキテクチャレイヤー」として位置づけ | https://cobusgreyling.medium.com/the-rise-of-ai-harness-engineering-5f5220de393e | [`category-2/02`](./category-2/02-cobus-greyling-rise-of-ai-harness-engineering.md) |
| 10 | Skill Issue: Harness Engineering for Coding Agents (HumanLayer, 2026/3/12) | AGENTS.mdを小さく保つこと、カスタムツールの厳選、skillsやプラグインの活用など実践的Tipsが豊富 | https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents | [`category-2/03`](./category-2/03-humanlayer-skill-issue-harness-engineering-coding-agents.md) |
| 11 | The importance of Agent Harness in 2026 (Philipp Schmid, 2026/1/5) | 「Agent HarnessはOSである」という比喩でハーネスの重要性を早期に予見した先見的記事 | https://www.philschmid.de/agent-harness-2026 | [`category-2/04`](./category-2/04-philipp-schmid-agent-harness-2026.md) |
| 12 | Harness Engineering vs Context Engineering (Rick Hightower / Medium, 2026/3) | 「モデルはCPU、ハーネスはOS」というアナロジーで両者の違いを明快に解説 | https://medium.com/@richardhightower/harness-engineering-vs-context-engineering-the-model-is-the-cpu-the-harness-is-the-os-51b28c5bddbb | [`category-2/05`](./category-2/05-rick-hightower-harness-vs-context-engineering.md) |
| 13 | What Is Harness Engineering? Complete Guide (nxcode.io, 2026/3/26) | ツールやフレームワークを含む2026年時点のエコシステム全体を網羅した包括的ガイド | https://www.nxcode.io/resources/news/what-is-harness-engineering-complete-guide-2026 | [`category-2/06`](./category-2/06-nxcode-harness-engineering-complete-guide-2026.md) |
| 14 | How I think about Codex (Simon Willison, 2026/2/22) | ハーネスを「指示とツールの集合体」として捉え、OpenAIのCodexリポジトリのオープンソース実装を分析 | https://simonwillison.net/2026/Feb/22/how-i-think-about-codex/ | [`category-2/07`](./category-2/07-simon-willison-how-i-think-about-codex.md) |
| 15 | Beyond the AI Coding Hangover (Spillwave Solutions / Medium, 2026/3) | AI生成コードの「二日酔い」（品質低下・障害）をハーネスで防ぐ戦略を解説 | https://medium.com/spillwave-solutions/beyond-the-ai-coding-hangover-how-harness-engineering-prevents-the-next-outage-e6fae5fe4d3b | [`category-2/08`](./category-2/08-rick-hightower-beyond-ai-coding-hangover.md) |
| 16 | Humans and Agents in Software Engineering Loops (Birgitta Böckeler / Martin Fowler, 2026/3/4) | ハーネスの構築・維持を「on the loop」の仕事として位置づけ、人間とエージェントの役割分担を論じた続編 | https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html | [`category-2/09`](./category-2/09-martin-fowler-humans-and-agents-in-software-engineering-loops.md) |
| 17 | Context Engineering for Coding Agents (Martin Fowler, 2026) | ハーネスの中核をなすコンテキストエンジニアリングの実践を、Markdownファイルベースのプロンプト設計の観点から解説 | https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html | [`category-2/10`](./category-2/10-martin-fowler-context-engineering-coding-agents.md) |
| 18 | Unlocking the Codex harness: how we built the App Server (OpenAI, 2026/2/4) | Codexエージェントを組み込むためのApp Server（双方向JSON-RPC API）の技術的詳細 | https://openai.com/index/unlocking-the-codex-harness/ | [`category-2/11`](./category-2/11-openai-unlocking-the-codex-harness-app-server.md) |
| 19 | Why Harness Engineering Replaced Prompting in 2026 (Epsilla, 2026/3/26) | プロンプト→コンテキスト→ハーネスへの進化を時系列で整理 | https://www.epsilla.com/blogs/harness-engineering-evolution-prompt-context-autonomous-agents | [`category-2/12`](./category-2/12-epsilla-harness-engineering-evolution-prompt-context-2026.md) |

### 3. 日本語の解説記事・ブログ（11本）

| 番号 | タイトル | 概要 | URL |
|---|---------|------|-----|
| 20 | ハーネスエンジニアリング入門 ── CLAUDE.mdの次に来るAI駆動開発の基本 (Qiita, 2026/3/24) | 概念、構成要素、導入方法を実運用の経験を交えて分かりやすく解説した入門記事 | https://qiita.com/nogataka/items/d1b3fcf355c630cd7fc8 |
| 21 | 「人間はコードを1行も書かない」という縛りで5ヶ月間プロダクト開発した話 (Qiita, 2026/3/2) | OpenAIの事例をベースに、馬具の比喩を用いてハーネスの概念を分かりやすく紹介 | https://qiita.com/nogataka/items/43c01957fa1e54d9a079 |
| 22 | Claude Code / Codex ユーザーのためのHarness Engineeringベストプラクティス (nyosegawa, 2026/3/9) | 2026年3月時点での実践的ベストプラクティスが体系的にまとめられた良記事 | https://nyosegawa.com/posts/harness-engineering-best-practices-2026/ |
| 23 | ハーネスエンジニアリング × ローカルオーケストレーターでAIエージェントを飼い慣らす (Zenn, 2026/3/24) | ローカル環境でのオーケストレーターと組み合わせた実践的アプローチ | https://zenn.dev/explaza/articles/6c976d79c094dc |
| 24 | OpenAIが実践するAgent-First時代の開発アプローチ (Zenn, 2026/2/27) | OpenAIの記事を丁寧に翻訳・解説し、日本語で理解するのに最適な記事 | https://zenn.dev/jiro526/articles/harness-engineering |
| 25 | OpenAIの提唱する「ハーネス・エンジニアリング」とは何か (blog.est, 2026/3/11) | 従来のソフトウェアエンジニアリングの定石との共通点を指摘し、冷静な視点で概念を整理 | https://blog.est.co.jp/20260311/ |
| 26 | OpenAIが実践する「Harness Engineering」という新しい開発手法 (note, 2026/2) | OpenAIのブログの要点を日本語で分かりやすくまとめた解説記事 | https://note.com/aiedgerunner/n/na1b2d51b21d8 |
| 27 | ハーネスエンジニアリング（Harness Engineering） (はてなブログ, 2026/3/16) | 定義、分類、上位概念・下位概念を体系的に整理した概要記事 | https://kaeken.hatenablog.com/entry/2026/03/16/000000 |
| 28 | ハーネスエンジニアリング - Martin Fowlerの批評から再考する (Qiita, 2026/3/25) | Martin Fowlerの批評的視点を踏まえ、ハーネスの構成要素を再整理 | https://qiita.com/Aochan0604/items/306bde3e138ce071f7b2 |
| 29 | Claude Codeのハーネスをより深く理解するための人間向けガイド (note, 2026/3) | Claude Codeのskills機能を中心にハーネスの実装を解説 | https://note.com/m2ai_jp/n/ne40d6318a477 |
| 30 | 5カ月でコード100万行を生成してソフトウェア構築 (@IT, 2026/3/19) | OpenAIの事例を日本のITメディアが取り上げた解説記事 | https://atmarkit.itmedia.co.jp/ait/articles/2603/19/news064.html |

### 4. スライド・発表資料（3本）

| 番号 | タイトル | 概要 | URL |
|---|---------|------|-----|
| 31 | コンテキスト・ハーネスエンジニアリングの現在 (Speaker Deck, 2026/3/18) | コンテキストエンジニアリングとハーネスエンジニアリングの発展の歴史と位置づけを簡潔にまとめた登壇資料 | https://speakerdeck.com/hirosatogamo/kontekisutohanesuenziniaringunoxian-zai |
| 32 | 実践ハーネスエンジニアリング #MOSHTech (Speaker Deck, 2026/3/26) | LLMの性能を最大限引き出すための環境設計について実践的に解説した最新スライド | https://speakerdeck.com/kajitack/implementing-herness-engineering |
| 33 | ハーネスエンジニアリング (Speaker Deck, 2026/3) | 概念の全体像を俯瞰するスライド | https://speakerdeck.com/abenben/hanesuenziniaringu |

NotebookLM 等へ投げる場合は各 URL をソースに直接追加すればよい。Speaker Deck（31–33）はスライドのためテキスト抽出精度は落ちる可能性あり。

## Index — category 1 (English primary)

Quick links to captured files only (same as rows **#1–7** above).

| # | Source | File |
|---|--------|------|
| 1 | OpenAI | [`category-1/01-openai-harness-engineering.md`](./category-1/01-openai-harness-engineering.md) |
| 2 | Martin Fowler | [`category-1/02-martin-fowler-harness-engineering.md`](./category-1/02-martin-fowler-harness-engineering.md) |
| 3 | Anthropic (long-running app design) | [`category-1/03-anthropic-harness-design-long-running-apps.md`](./category-1/03-anthropic-harness-design-long-running-apps.md) |
| 4 | Anthropic (effective harnesses) | [`category-1/04-anthropic-effective-harnesses-long-running-agents.md`](./category-1/04-anthropic-effective-harnesses-long-running-agents.md) |
| 5 | Mitchell Hashimoto | [`category-1/05-mitchell-hashimoto-ai-adoption-journey.md`](./category-1/05-mitchell-hashimoto-ai-adoption-journey.md) |
| 6 | Charlie Guo | [`category-1/06-charlie-guo-emerging-harness-playbook.md`](./category-1/06-charlie-guo-emerging-harness-playbook.md) |
| 7 | LangChain | [`category-1/07-langchain-improving-deep-agents-harness.md`](./category-1/07-langchain-improving-deep-agents-harness.md) |

## Index — category 2 (English supplementary / deep dives)

Quick links to captured files only (same as rows **#8–19** above).

| # | Source | File |
|---|--------|------|
| 1 | Louis-François Bouchard | [`category-2/01-louis-bouchard-harness-engineering-missing-layer.md`](./category-2/01-louis-bouchard-harness-engineering-missing-layer.md) |
| 2 | Cobus Greyling (Medium) | [`category-2/02-cobus-greyling-rise-of-ai-harness-engineering.md`](./category-2/02-cobus-greyling-rise-of-ai-harness-engineering.md) |
| 3 | HumanLayer | [`category-2/03-humanlayer-skill-issue-harness-engineering-coding-agents.md`](./category-2/03-humanlayer-skill-issue-harness-engineering-coding-agents.md) |
| 4 | Philipp Schmid | [`category-2/04-philipp-schmid-agent-harness-2026.md`](./category-2/04-philipp-schmid-agent-harness-2026.md) |
| 5 | Rick Hightower (Medium; paywalled preview) | [`category-2/05-rick-hightower-harness-vs-context-engineering.md`](./category-2/05-rick-hightower-harness-vs-context-engineering.md) |
| 6 | nxcode.io | [`category-2/06-nxcode-harness-engineering-complete-guide-2026.md`](./category-2/06-nxcode-harness-engineering-complete-guide-2026.md) |
| 7 | Simon Willison (link post) | [`category-2/07-simon-willison-how-i-think-about-codex.md`](./category-2/07-simon-willison-how-i-think-about-codex.md) |
| 8 | Rick Hightower / Spillwave (Medium; paywalled preview) | [`category-2/08-rick-hightower-beyond-ai-coding-hangover.md`](./category-2/08-rick-hightower-beyond-ai-coding-hangover.md) |
| 9 | Martin Fowler (humans and agents) | [`category-2/09-martin-fowler-humans-and-agents-in-software-engineering-loops.md`](./category-2/09-martin-fowler-humans-and-agents-in-software-engineering-loops.md) |
| 10 | Martin Fowler (context engineering) | [`category-2/10-martin-fowler-context-engineering-coding-agents.md`](./category-2/10-martin-fowler-context-engineering-coding-agents.md) |
| 11 | OpenAI (Codex App Server) | [`category-2/11-openai-unlocking-the-codex-harness-app-server.md`](./category-2/11-openai-unlocking-the-codex-harness-app-server.md) |
| 12 | Epsilla | [`category-2/12-epsilla-harness-engineering-evolution-prompt-context-2026.md`](./category-2/12-epsilla-harness-engineering-evolution-prompt-context-2026.md) |

## Category 3・4 policy

カテゴリ3（日本語解説）・カテゴリ4（スライド）は**一次情報がカテゴリ1・2で網羅済み**のため、このリポジトリでは Markdown キャプチャを作っていない。詳細な一覧・概要はこの README 冒頭のマスター表（セクション3および4）を参照。

## Analysis

- [`current-state-assessment.md`](./current-state-assessment.md) — 現状評価・ギャップ分析・Issue カバレッジマップ（2026-04-01）
- 概念マッピング（自設計との対応）: [`harness-engineering-mapping.md`](../../projects/orchestration-research/synthesis/harness-engineering-mapping.md)

## Disclaimer

Copyright remains with each publisher. These files support research and agent context only; prefer the live URL for authoritative text and licensing.

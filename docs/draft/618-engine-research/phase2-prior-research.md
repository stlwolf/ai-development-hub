# #618 フェーズ2 事前リサーチ: 2026-02 の調査と #605 の調べものの要約

- 作成日: 2026-11-10
- 読んだもの: `projects/orchestration-research/`（README・`landscape/INDEX.md`・`concepts/` 全体の骨子・`synthesis/` 4本・近縁4ツールの個票）、`projects/orchestration-engine/README.md`、#605 の discussion と decision、起点の `ideas/20260222/` 2本、`docs/draft/zenn/orchestration-landscape.md`、Phase 5 discussion の一部
- 読んでいないもの: `landscape/` の個票のうち近縁4件（agent-orchestrator・CAO・Agent Teams・TAKT）以外の本文、`landscape/steipete-ecosystem/` の個票本文、`landscape/orchestration-oss-landscapes.md`（元データ）。これらは INDEX と concepts 経由の把握にとどまる
- 以下、パスはすべてリポジトリ `/home/user/ai-development-hub/` からの相対パス。「推測」と書いた箇所は文書に書かれていない、私の読みである

## 0. 先に押さえる3点

- 2026-02 の調査は「OSS はインフラ層が厚く、自分はセマンティック層が厚い」という非対称を前提に、インフラ層は借りてセマンティック層を自前で作る、という結論だった（`projects/orchestration-research/README.md`「背景」、`ideas/20260222/orchestration-tool-building-approach.md`「核となる認識」）。
- いまの engine の README が挙げる5つの面のうち、4つ（親子の委譲・cockpit の観測と見張り・統括の交代と lease・SO のゲート）は Phase 4 MVP のあとに足されたものである（`projects/orchestration-engine/README.md` 冒頭の表と「Phase 4 後の追加」）。このうち委譲・観測・lease は、調査が「インフラ層」と呼んだ領域（プロセス管理・セッション制御）に当たる。この対応づけは推測。
- #605 の調べものは、CLI の入口とサブコマンドの配り方の調査であり、機能の比較ではない。agent-of-empires と claude-squad について書かれているのは、PATH に置く名前・CLI フレームワーク・verb の並べ方だけである（`projects/orchestration-engine/docs/discussions/2026-11-09-discussion-605-single-entry-command.md` 2節）。機能面で engine とどう違うかは、リポジトリ内のどの文書にも書かれていない（`grep -ril "agent-of-empires\|claude-squad"` の該当は discussion と decision の2ファイルだけ）。

## 1. 2026-02 の調査の枠組み

### 1.1 進め方

- 調査日は 2026-02-22。`oss-researcher` サブエージェントの4並列 × 5バッチで集めた（`projects/orchestration-research/README.md`「調査対象」、`landscape/INDEX.md` 冒頭）。Agent Teams の個票だけ `last_reviewed: 2026-02-25`（`landscape/claude-code-agent-teams.md` frontmatter）。
- 3段構成: `landscape/`（ツール単位の個票）→ `concepts/`（ツール非依存の概念）→ `synthesis/`（自前の構想との統合）（`projects/orchestration-research/README.md`「構成」）。
- 個票の統一フォーマット: 基本情報／何を解決するか／設計思想／機能一覧（Core・Differentiator・Utility）／特徴／使い方／エコシステム／他ツール比較／制約／深掘り候補（同 README「landscape/」）。
- プロジェクトは Phase 1〜3 完了でクローズし frozen。以降は `projects/orchestration-engine/docs/` が正本（同 README「状態」、`projects/orchestration-engine/README.md`「研究フェーズとの関係」）。

### 1.2 「21ツール」の数え方の揺れ

文書ごとに数え方が違う。見取り図で数を引くときは注意がいる。

| 文書 | 内訳 |
|---|---|
| `projects/orchestration-research/README.md`「調査対象」 | 6カテゴリ・20行（oh-my-claude-code/o-m-cc と PentAGI/Orca を各1行に束ねる） |
| `concepts/implementation/landscape-matrix.md` | 22行（Claude Flow・oh-my-claudecode・o-m-cc・PentAGI・Orca を個別に数える） |
| `landscape/INDEX.md` | 上に Agent Teams・oh-my-claudecode・oh-my-opencode と、番外の steipete 5件（agent-scripts・Oracle・mcporter・Peekaboo・OpenClaw）を加える |
| `docs/draft/zenn/orchestration-landscape.md` | 21行（Claude Flow をモック実装のため除外） |

### 1.3 ツールの類型化（カテゴリ別）

出典は `landscape/INDEX.md`「カテゴリ別一覧」と `projects/orchestration-research/README.md`「調査対象」。Stars は 2026-02-22 時点。

| カテゴリ | ツール | 当時の一言 |
|---|---|---|
| 1. ワークフロー定義・タスクオーケストレーション型 | TAKT（424） | YAML 定義ワークフロー + Faceted Prompting。「強制力」の設計哲学 |
| | agent-orchestrator / ComposioHQ（710） | 8スロットのプラグイン + Reactions。30並列 |
| | CAO / awslabs（254） | tmux + MCP + ANSI パース。Handoff・Assign・SendMessage の3モード + Flow |
| | Agent Squad / awslabs（7,452） | LLM のインテント分類によるルーティング |
| 2. グラフ・状態管理型フレームワーク | LangGraph（24,933） | Pregel 着想のグラフランタイム。チェックポイント + Time Travel |
| | Mastra（21,283） | Agent + Workflow + RAG + Memory + MCP の統合 |
| | ControlFlow（1,388） | アーカイブ済み（Marvin 3.0 へ） |
| 3. マルチエージェント協調フレームワーク | AutoGen（54,713） | メンテナンスモード（Agent Framework へ） |
| | CrewAI（44,400） | Role/Goal/Backstory + Flows |
| | OpenAI Agents SDK（19,068） | Handoff と Agent-as-Tool。Guardrails |
| | Google ADK（17,802） | A2A プロトコル。LLM の動的ルーティング |
| | MetaGPT（64,300） | 仮想ソフトウェア会社の SOP。cause_by ルーティング |
| | BeeAI（3,113） | RequirementAgent（宣言的なルール制御） |
| | PydanticAI（15,000） | 型安全なエージェント定義 |
| 4. 自律コーディング・サンドボックス型 | OpenHands（68,060） | Docker 隔離 + EventStream + StuckDetector |
| | SWE-agent（18,528） | ACI（Agent-Computer Interface） |
| | Aider（40,835） | Repository Map（PageRank + tree-sitter）。git 統合 |
| 5. Claude Code / IDE 特化型 | Claude Code Agent Teams | 内蔵。ファイルベースの mailbox。当時は実験的機能 |
| | oh-my-claudecode（7,800+） | Claude Code のプラグイン。32エージェント・Team Mode |
| | oh-my-opencode（35,600+） | OpenCode 用プラグイン |
| | o-m-cc（4） | 分散 P2P 型。HANDOVER.md・Progressive Disclosure |
| | Claude Flow（14,337） | MCP ツールの85%がモック実装 |
| 6. ドメイン特化・低レベル基盤 | PentAGI / Orca（6,592 / 284） | ペンテスト特化 / Rust の LLM パイプライン（停止） |
| 7. 個人開発者ツールキット（番外） | steipete の agent-scripts・Oracle・mcporter・Peekaboo・OpenClaw | 小さな単機能 CLI の組み合わせ |

### 1.4 比較軸と概念の分類

| 種類 | 中身 | 出典 |
|---|---|---|
| ドメイン概念10領域 | 01 Agent Definition／02 Routing & Delegation／03 Flow Control／04 Execution & Runtime／05 State & Memory／06 Feedback & Validation／07 Human Interaction／08 Event & Reaction／09 Tooling & Integration／10 Observability | `concepts/README.md`「10のドメイン概念領域」 |
| レイヤー構造 | 下層（01・09・04・05）は OSS が厚いインフラ層で「自前で書く必要が薄い」。中層（02・03・08）はオーケストレーションの核。上層（06・07）は品質と安全で、独自概念はここ。10 は横断 | 同「レイヤー構造」 |
| 実装特性の6軸 | 言語／インターフェース型／デプロイ／ラッパー分類／設定スタイル／外部依存 | `concepts/implementation/landscape-matrix.md` |
| ラッパー分類 | スタンドアロン／CLI ラッパー（単一対象）／CLI ラッパー（複数対象）。ラップの深さは薄い（Hooks で設定注入）から厚い（プロセス管理と出力パース）まで | `concepts/implementation/wrapper-vs-standalone.md` |
| 協調トポロジー4種 | 中央集権（Hub-and-Spoke）／分散 P2P／ハイブリッド（Council + Pipeline）／Swarm（Handoff） | `concepts/cross-cutting/coordination-topologies.md` |
| 設計思想の2軸 | 重量（フレームワーク）対 軽量（CLI の組み合わせ）、内蔵（特定ツール依存）対 独立 | `landscape/INDEX.md`「設計思想の2軸」 |
| Claude Code まわりの4層 | L1 手動 CLI（steipete）／L2 内蔵（Agent Teams・Subagents）／L3 プラグイン（oh-my-claudecode ほか）／L4 フレームワーク（agent-orchestrator・CAO・TAKT） | 同「Claude Code エコシステムの階層」 |
| 独自概念という比較軸 | 認知協調／知識永続化／ドキュメント設計／正準エージェント定義／コンテキスト・エンベロープ。各 OSS に「あるか無いか」を見る | `projects/orchestration-research/README.md`「自分の独自レイヤー」、`ideas/20260222/orchestration-tool-building-approach.md`「比較軸」 |
| Skills/Rules レベルの5パターン | 知識注入／複数インスタンス協調／単一会話マルチロール／フック駆動の状態機械／ドキュメント媒介ハンドオフ | `synthesis/skills-level-patterns.md` |
| 開発特化 対 汎用フレームワーク | 開発特化8件と汎用10件の2分類（下書き記事での再整理） | `docs/draft/zenn/orchestration-landscape.md`「まず大きく2つに分かれる」 |

## 2. その時点の結論

### 2.1 synthesis が勧めたこと

| 勧めたこと | 出典 |
|---|---|
| 作るものは「構造化ドキュメントのルーティングエンジン」。入力ドキュメントをエージェント（CLI プロセス）に渡し、出力を受け取って次に渡す。その間のフォーマット・フロー・検証のプロトコル | `synthesis/architecture-sketch.md` §1、`synthesis/skills-level-patterns.md`「不変のアトム」 |
| 選択肢 B: CLI ランタイムは借り、協調プロトコルとコンテキスト設計に集中する | `synthesis/skills-level-patterns.md`「自前ツールの位置づけ」、`architecture-sketch.md` §2 |
| 薄いシェル（Bash + jq）。重いフレームワークとベンダーロックインを避ける | `architecture-sketch.md` §2、`synthesis/README.md`「方針」 |
| 状態管理はファイルベース。ストレージ技術ではなく構造化設計の問題 | `architecture-sketch.md` §6 |
| ネイティブ仕様（フック・Skills・Subagents・Rules）に準拠し、独自フォーマットを発明しない | `architecture-sketch.md` §2 原則3 |
| Build to Delete。ガードレールは取り外せるように作る | `architecture-sketch.md` §2、`synthesis/context-foundation.md`「ガードレールの時間的変化」 |
| 認知協調（arena-compare・peer-ai-review・so-compare・adversarial review）はコア機能。検証ゲートの主な実装にする | `architecture-sketch.md` §3 |
| 「ルールで祈る」から「フックで強制する」へ。ゲートは実行の証跡を構造化データで残す | `synthesis/harness-engineering-mapping.md`「キーインサイト」、`architecture-sketch.md` §8 |
| 蒸留のパイプライン（Discussion → KickOff → Plan → Episode → Decision）を主なデータフローにする | `architecture-sketch.md` §6、`context-foundation.md` §7 |
| コンテキスト基盤の MVP は Markdown + frontmatter と JSONL、検索は frontmatter 索引 + rg、昇格はテンプレート抽出 + 人間のレビュー | `context-foundation.md` §5・§6 |
| MVP の構成は エンベロープ → ディスパッチャ → CLI プロセス → 成果物パース → 検証ゲート → 状態更新 | `architecture-sketch.md` §5 |

### 2.2 捨てたこと・後回しにしたこと

| 捨てた・後回し | 理由として書かれていること | 出典 |
|---|---|---|
| 選択肢 A（ランタイムから自前）と C（Agent Teams をそのまま使う） | 独自の価値は協調プロトコルとコンテキスト設計にある | `skills-level-patterns.md`「自前ツールの位置づけ」 |
| LangGraph などのフレームワークへの依存 | ライブラリの陳腐化リスク。本質はコンテキストの構造化 | `architecture-sketch.md` §2、`projects/orchestration-engine/docs/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md` §8 |
| タスクグラフ | 最初は1タスクか手動のチェーンで足りる | `architecture-sketch.md` §5「MVP に含めないもの」 |
| 人間ゲート | 人間が CLI の前にいるので暗黙に存在する | 同上 |
| ルール注入 | `canonical/` + sync が機能している | 同上 |
| RAG・ベクトル検索・知識グラフ、LLM による自動昇格、動的なコンテキスト選択、GUI | MVP では検証しない | `context-foundation.md` §6 |
| SQLite などの DB | ファイルベースで足りる | `architecture-sketch.md` §6 |
| 認知協調と正準エージェント定義の個別の設計文書 | 実装が先行している。MVP で経験的に固める | `architecture-sketch.md` §9、`synthesis/README.md` |

concepts の段階では「YAML 宣言 + Zod」「litellm などの LLM 抽象層」「8スロット式のプラグイン」「プロダクション段階ではスタンドアロン化」が示唆として挙がっていた（`concepts/implementation/config-styles.md`・`concepts/cross-cutting/llm-abstraction-patterns.md`・`concepts/implementation/wrapper-vs-standalone.md` の各「示唆」節）。synthesis はこれらを採らず、Bash + jq で CLI を借りる側に倒した。採らなかった理由を直接書いた箇所は見当たらない。「選択肢 B」と「薄いシェル」からの帰結と読むのは推測。

### 2.3 architecture-sketch の構想と、いまの engine（README）

一致している点:

| 項目 | sketch | いまの README |
|---|---|---|
| 実装の言語 | Bash + jq の薄いシェル（§2） | 「Bash + jq の CLI 群」（冒頭・「目的」） |
| 1サイクルの流れ | エンベロープ → ディスパッチャ → CLI → パース → 検証 → 状態更新（§5） | `oe run` が envelope → spawn → capture → verify → monitor を回す（冒頭の表） |
| CLI ランタイムを借りる | Cursor・Claude Code・Codex（§1） | `lib/spawn.sh` が cursor-agent・claude・codex へディスパッチ（「構成」） |
| ファイルベースの状態 | JSON ファイル（§5・§6） | `audit/` の JSONL、`state/` の KVS、`schemas/` 7件（「構成」） |
| 認知協調がコア | SO と adversarial review をゲートに（§3） | `oe-refute`（設計 SO）と `oe-review`（実装 SO）が verb（冒頭の表） |
| ゲートの実行証跡 | 構造化データで残す（§8） | `verification_completed` などの audit、reviewed-diff に結びつけた独立の artifact（sketch §3 追記、README「Phase 4 後の追加」） |
| 蒸留のパイプライン | Discussion → … → Decision（§6） | `docs/` の5ディレクトリ、「観測層と駆動層の分離」節 |
| 作るものの定義 | 構造化ドキュメントのルーティングエンジン（§1） | 「目的」節に同じ文言が残る |

ずれている点（README の記述と sketch の記述の差。「なぜずれたか」は推測を含む）:

| 項目 | sketch | いまの README | 補足 |
|---|---|---|---|
| 重心 | 非対話の1サイクルが全体 | 5つの面のうち1つが `oe run`。残りは対話セッション間の委譲・観測・交代・SO | README は「2系統」と明記。README 冒頭の定義は「統括（親）と子に分けて動かすための CLI 群」で、「目的」節の「ルーティングエンジン」と並んで残っている |
| プロセス管理 | 「借りるもの」（§1 の表） | spawn レジストリ、送信の finalize（#144）、着信の照合 `oe-confirm`（#336）、lease（#577）、heartbeat、`tmux-pane-identity.sh` を自前で持つ | 調査が「自前で書く必要が薄い」とした領域（`concepts/README.md`「レイヤー構造」、`concepts/domain/04-execution-runtime.md`）に実装が増えた、と読める。推測 |
| 人間の位置 | 人間ゲートは MVP の外。暗黙に存在（§5） | 人間が cockpit で全体を見て介入するのが本線（「cockpit 本線」節、#169） | |
| 端末の基盤 | WezTerm の `wez` CLI（§7） | WezTerm + tmux。engine は wez の整数ペイン、委譲は tmux の `%N` で、別の多重化レイヤとして統一しない（#188） | |
| 司令塔 | Cursor から `wez` を叩く前提が残る | Cursor は補助。README 自身が旧文言の上書きを注記 | 「cockpit 本線」節の注 |
| 協調の形 | 1タスクの直列（target → reviewer） | 統括と子のスター型の委譲。統括の計画的な交代と復帰（#390・#355） | sketch に統括の交代や lease の構想は無い |
| Observability | MVP に入れるかは保留（§7） | `oe-tree`・`oe-activity`・`oe-threads`・`oe-status`・`oe-vitals`・`oe-undelivered`・`oe-confirm` が1つの面 | |
| タスクグラフ | 後のフェーズ | README に記述なし | Phase 5 の discussion（2026-05-19）にパイプライン駆動の構想はあるが、kickoff は `status: draft` |
| 正準エージェント定義・ルーラーエージェント・動的なコンテキスト選択 | 未決定のまま MVP で固める（§4）、`context-foundation.md` で後段 | README に記述なし | engine の外（`canonical/`）で扱っている可能性はある。未確認 |
| 入口 | `bin/oe` が本体 | 入口 `oe` が `oe-<verb>` を `exec` するだけ。本体は `oe run`（#605） | `projects/orchestration-engine/docs/decisions/2026-11-10-decision-605-single-entry-command.md` |

## 3. #605 の調べものの中身

出典は `projects/orchestration-engine/docs/discussions/2026-11-09-discussion-605-single-entry-command.md`（調査日 2026-11-09、各リポジトリのその日の HEAD）と `projects/orchestration-engine/docs/decisions/2026-11-10-decision-605-single-entry-command.md`。

### 3.1 問いと信頼度の札

- 問いは2つ。代表的な CLI と bash の振り分け役がサブコマンドをどう配っているか。最近（2026-05〜11）のオーケストレーション系・コーディングエージェントの CLI が入口とサブコマンドをどう作っているか（discussion「何を知りたかったか」）。
- 札は `[verified]`（書き手が開いて確かめた）と `[unverified-summary]`（サブエージェントの報告で、書き手は開き直していない）。`[verified]` は rbenv・kubectl・codex の `package.json`・aoe の `Cargo.toml`・Yocto の `oe-*` の5点。discussion は「結論は verified の4件だけでも支えられる」と書く（discussion「調べていないこと」）。

### 3.2 挙がったツール（エージェント系）

| ツール | PATH の名前 | 作り | verb の並べ方 | 札 |
|---|---|---|---|---|
| Claude Code | `claude` | 1つのバイナリ | 平らな verb と、`auth`・`mcp`・`plugin` の束 | unverified-summary |
| Codex CLI（rust-v0.167.0） | `codex` | clap | 平らな `exec`・`review`・`resume` と、`mcp`・`plugin`・`sandbox` の束 | bin 名は verified |
| Gemini CLI（v0.67.0） | `gemini` | yargs | `extensions`・`mcp`・`hooks` の束 | unverified-summary |
| Cursor CLI | `agent` | 1つのバイナリ | 平らな `login`・`ls`・`resume` と、`mcp`・`worker` の束 | unverified-summary |
| Goose（v1.57.0） | `goose` | clap | 平らな `run`・`doctor` と、`session`・`recipe`・`plugin` の束 | unverified-summary |
| agent-of-empires（v1.22.3） | `aoe` | clap 4.6（Rust） | 平らな `add`・`list`・`send`・`status`・`stop` と、`session`・`worktree`・`tmux` など約18の束 | bin 名と clap は verified |
| claude-squad（v1.0.20） | `cs`（brew では `claude-squad`） | cobra（Go） | 引数なしで TUI。verb は `reset`・`debug`・`version` だけ | unverified-summary |
| ccmanager・vibe-kanban・OpenHands CLI・Amp | それぞれ1本 | meow・cac・Python の entry point など | フラグ中心か、数個の verb | unverified-summary |

汎用の CLI（git・kubectl・docker・gh・cargo）と bash の振り分け役（rbenv・pyenv・basecamp/sub）も調べている（discussion 1節）。Conductor・Antigravity CLI・Nimbalyst は確かめていない（discussion「調べていないこと」）。

### 3.3 engine との関係として書かれていること

- aoe は「tmux と worktree で複数のエージェントを並べる」ツールで、「engine に一番近い」。aoe も `aoe send`・`aoe list` を平らに置き、`aoe session …` を束ねる（discussion 2節「分かったこと」）。
- エージェント系の CLI で、PATH の `<ツール>-<verb>` を探して呼ぶものは無かった。拡張はスキル・MCP サーバ・フックを `<ツール> plugin …` で扱う（同）。
- engine は bash のスクリプトの集まりなので、作りは rbenv・sub の型（実体のディレクトリを解く → 隣の `oe-<verb>` を確かめる → `exec`）が一番近い（discussion 3節）。
- 他のエージェント系 CLI は1つのバイナリ（clap・cobra・yargs）で、engine は verb ごとの bash ファイルである。decision はこれを「当時の前提」に置き、1つのバイナリにまとめるなら見直すと書く（decision「当時の前提」）。
- `oe` の名前は Yocto の `oe-*` と前置きが重なる。素の `oe` は無いが、#537 で外に出すときに見直す（discussion 3節、decision「当時の前提」）。

### 3.4 書かれていないこと

- aoe・claude-squad・ccmanager・vibe-kanban が何をするか（セッション管理・worktree の切り方・状態検知・通知など）の比較は無い。engine の委譲・観測・lease と機能がどこまで重なるかは、どの文書にも無い。フェーズ2で新しく調べる必要がある所である。
- 2026-02 の調査に、tmux + worktree で並べる型として入っているのは agent-orchestrator と CAO である（`landscape/agent-orchestrator-composio.md`・`landscape/cao-aws.md`）。agent-orchestrator の個票の比較表には workmux（Rust・git worktree・エージェント非依存）が、TAKT の個票には multi-agent-shogun（tmux 直接制御）が名前だけ出るが、個票は無い。

## 4. いま（2026-11）読むと古くなっていそうな所

この節は、文書内に手がかりがあるものを除き、すべて推測である。現在の各ツールの状態は確かめていない。

| 古くなっていそうな所 | 手がかり | 出典 |
|---|---|---|
| 対象ツールの顔ぶれ。tmux + worktree で並べる型（aoe・claude-squad・ccmanager・vibe-kanban・Conductor）と、Goose・Gemini CLI・Amp が 2026-02 の調査に無い | #605 の discussion がこれらを 2026-11 の対象に挙げる。文書内の手がかりあり | discussion 2節、`landscape/INDEX.md` |
| agent-orchestrator と TAKT の成熟度の評価 | 当時は公開10日目・コントリビューター1名、v0.22 で1か月。9か月たっている | `landscape/agent-orchestrator-composio.md`「制約」、`landscape/takt.md`「制約」 |
| Agent Teams を「実験的・環境変数で有効化・コスト2倍・セッション再開に制限」とした評価 | 当時のリリース直後（2026-02-05）の状態。選択肢 C を捨てた根拠の一部 | `landscape/claude-code-agent-teams.md`、`synthesis/skills-level-patterns.md` |
| 「インフラ層は借りる。プロセス管理は自前で書かない」という前提 | README を見ると engine 側にセッション管理の実装が増えている。前提が実態と合っているかの再確認がいる | `architecture-sketch.md` §1、`projects/orchestration-engine/README.md`「構成」 |
| 「オーケストレーターは薄くなる方向」「ガードレールはモデルの進化で不要になる」 | steipete が Ralph などを削除した、という 2026-02〜03 の観察に依る。engine は逆に見張りと照合を足している | `context-foundation.md`「ガードレールの時間的変化」「2026-03-18時点のメモ」 |
| 「ルールの遵守率は約80%、フックは100%」 | 2026-03 ごろの記事群の合意。モデルの世代が変わっている | `synthesis/harness-engineering-mapping.md`「キーインサイト」 |
| 「最適ワーカー数は2〜3。10以上の並列はオーバーヘッドが上回る」 | 出典の時期が 2026-02 ごろ | `synthesis/skills-level-patterns.md`「企業レベルの実態」 |
| 「OSS に無い」とした独自概念（昇格フロー、判断履歴のナビゲーション、セカンドオピニオン） | 2026-02-22 時点の21ツールでの確認。ネイティブのメモリ機能やレビュー機能が増えていれば差は縮む | `concepts/README.md`「独自レイヤーの位置づけ」、`landscape/INDEX.md`「自分の独自レイヤーとの対応」 |
| 「MCP 不要論・CLI ファースト」 | 2026-03-18 時点の動向メモ。#605 の調査では各 CLI が `mcp`・`plugin` の束を持つ | `context-foundation.md`「2026-03-18時点のメモ」、discussion 2節 |
| Stars、メンテナンス状態、モデル名（Opus 4.6・Sonnet 4.6・composer-2） | 調査時点の値 | `landscape/INDEX.md`、`architecture-sketch.md` §5 |
| Cursor の CLI の名前 | README は `cursor-agent`、#605 の discussion は `agent`（unverified-summary） | `projects/orchestration-engine/README.md`、discussion 2節 |
| 薄い個票 | BeeAI・ControlFlow などは補完するかの判断が未了のまま。INDEX の「調査」列の KB 数とファイルサイズが合わない行がある | `landscape/INDEX.md`「次のステップ」 |

調査自体が当時から認めていたリスク: 「OSS の進化が速く、調査結果がすぐ陳腐化する。概念レベルの抽出に集中する」「自前構築の必要性自体が不明確。既存 OSS のフォークや拡張で済むかもしれない」（`ideas/20260222/orchestration-tool-building-approach.md`「リスク・未知数」）。後者は Phase 2 で判断するとされたが、フォークや拡張を具体的に検討した記録は synthesis に見当たらない。

## 5. 独自性の主張と、代替できると認めている点

### 5.1 独自性として文書が主張している点

| 主張 | 最も近い OSS と、当時のカバー度 | 出典 |
|---|---|---|
| 認知協調（セカンドオピニオン）。スコアリングではなく別の視点の判断を求める | TAKT のレビューループ、BeeAI の RequirementAgent。部分的 | `concepts/README.md`、`concepts/domain/06-feedback-validation.md` |
| ルーラーエージェント（判断履歴のナビゲーション） | 「OSS に実装なし」。Claude Flow の Trust System はモック | `landscape/INDEX.md`、`concepts/domain/02-routing-delegation.md` |
| 4層コンテキストモデルと昇格フロー | Mastra の Observational Memory が最も近いが、「昇格」の概念は OSS に無い | `concepts/domain/05-state-memory.md` |
| 正準エージェント定義（ツール非依存） | PydanticAI・TAKT・CrewAI は構造のみ | `concepts/README.md` |
| コンテキスト・エンベロープ | OpenHands の EventStream が概念的に近い | 同上 |
| ドキュメント設計の原則 | MetaGPT の SOP 受け渡しが部分的 | 同上 |
| agent-orchestrator に無いもの: ドキュメントのガバナンス、知識の蓄積と昇格、フェーズ横断の因果追跡、オーケストレーション内の peer review | — | `ideas/20260222/oss-orchestrator-analysis-agent-orchestrator.md`「このツールにないもの」 |
| コンテキストが本質で、ツールの層は薄く保つ | — | `projects/orchestration-engine/docs/discussions/2026-05-19-discussion-phase-5-pipeline-driven-ecs-target.md` §8 |
| ゲートが実行されたかを構造で証明する | — | `architecture-sketch.md` §8・§3 追記 |
| 閉じたセッションの間を、ドキュメントだけで引き継ぐ（dogfood） | — | `projects/orchestration-engine/README.md`「Dogfood 視点」 |

独自性の主張はすべてセマンティック層（文書・判断・検証）についてである。委譲・観測・lease といった、いまの engine の実装の大半を占める面について「他に無い」と主張する文書は見つからなかった。README は委譲 CLI について「ワンラリーに焼き付けると Claude 組み込み subagent の劣化版になる」と書き、subagent との差を疎結合（戻しを汎用の `oe-send` にする）に置いている（`projects/orchestration-engine/README.md`「設計上のポイント」）。

### 5.2 他のツールで代替できると文書が認めている点

| 認めている点 | 出典 |
|---|---|
| インフラ層（ワークスペース隔離、プロセス管理、イベント駆動のフィードバック）は「自前で書く必要がない」 | `projects/orchestration-research/README.md`「背景」 |
| 04 Execution & Runtime は OSS が最も厚い。自前で書く必要性は低い | `concepts/domain/04-execution-runtime.md` |
| 03 Flow Control は独自レイヤーの主な対象ではない | `concepts/domain/03-flow-control.md` |
| プロセス管理・ツール実行・フック仕様は「借りるもの」 | `architecture-sketch.md` §1 |
| 独自仕様は「ドキュメント運用ルールのガードレール」でしかない。別のオーケストレーションツールに載せ替えても、コンテキスト（ドキュメント）は再利用できる | Phase 5 discussion §8 |
| Build to Delete。不要になった層は捨てる前提 | `architecture-sketch.md` §2 |
| 既存 OSS のフォークや拡張で済むかもしれない | `ideas/20260222/orchestration-tool-building-approach.md`「リスク・未知数」 |
| Cursor のリッチ表示（一覧・ナビ・履歴）は合成 UI で、fzf や自作の list で置き換えられる | `projects/orchestration-engine/README.md`「cockpit 本線」 |
| 外部イベント駆動の watchdog（CAO 型の端末 IDLE 監視）は代替案として挙がり、競合ではなく「監視は out-of-session で行う」という制約に還元された | `projects/orchestration-engine/docs/discussions/2026-07-12-discussion-238-239-succession-watchdog-design-rationale.md` §2 の Alt-γ |

## 6. 見取り図に向けて、文書から言えること・言えないこと

- 言えること: 2026-02 の枠組み（10領域・インフラ層とセマンティック層・ラッパー分類・4トポロジー）は、いまの engine を置く座標としてそのまま使える。engine は「CLI ラッパー（複数対象）・厚いラップ・中央集権型」の位置に来ており、当時この位置にいたのは agent-orchestrator と CAO である（`concepts/implementation/wrapper-vs-standalone.md`、`concepts/cross-cutting/coordination-topologies.md`。engine をこの位置に置くのは推測）。
- 言えないこと: tmux + worktree で並べる今のツール群（aoe・claude-squad など）と engine の機能の重なり。文書には CLI の形しか無い。
- 言えないこと: Claude Code の内蔵機能（Agent Teams・subagent）が 2026-11 時点でどこまで engine の委譲・観測を覆うか。2026-02 の個票しか無い。
- 確かめる順の案: (1) aoe・claude-squad・agent-orchestrator・CAO の現在の機能を10領域で取り直す。(2) Agent Teams の現状を取り直す。(3) そのうえで、engine の5面それぞれを「独自」「代替可」に仕分ける。

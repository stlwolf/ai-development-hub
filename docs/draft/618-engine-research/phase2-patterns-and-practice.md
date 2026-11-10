# Phase 2 設計パターンと実践者の動向（横断調査）

- 調査日: 2026-11-10
- 目的: tmux の send-keys で子セッションへ委譲する自作オーケストレーションエンジンについて、年内に方向性を決めるための材料として、**設計のパターン** と **実践者が実際にどうしているか** を痛みの種類ごとに横断で調べる。個々のツール紹介は `phase2-external.md` に任せ、重複は避けた
- 方法: WebSearch（一部 extended モード）と WebFetch。重要な記事は本文を開いた。検索語と外部リクエストに利用者の名前・メール・リポジトリ名は入れていない
- 検証ステータスの読み方
  - `[verified]`: 自分で一次ソースのページを開いて確かめた
  - `[unverified-summary]`: 検索結果の要約や二次情報のみ
  - `[speculation]`: この調査担当の推測・解釈
- 注意: WebFetch は小さなモデルがページを要約して返す仕組みである。`[verified]` は「一次ページを開いて要約と短い引用を得た」という意味で、引用文の一字一句までは保証しない。重要な引用を文書へ転記する前には原文を確認してほしい

## 0. 取得できなかったもの

| 対象 | 状況 |
| --- | --- |
| OpenAI「Harness engineering: leveraging Codex in an agent-first world」（2026-02-11 とされる） | `openai.com` が 403。ミラーも 404。二次情報のみ |
| Steve Yegge「Gas Town: from Clown Show to v1.0」「Gas Town Emergency User Manual」 | `medium.com` が 403。「Welcome to Gas Town」は `yegge.ai` のミラーで開けた |
| Gas Town `docs/design/watchdog-chain.md` | 404（ファイル名が違う）。代わりに `dog-infrastructure.md` を開けた |
| Geoffrey Huntley の 2026 年の記事 | 検索で一次記事を特定できず。2025-07-14 の原典のみ開いた |
| HumanLayer、LangChain の agent inbox の一次ページ | 開いていない。二次情報のみ |
| Amp が後に自動 compaction を戻したという話 | Product Hunt の投稿に基づく二次情報のみ。未確認 |
| Codex の compaction についての OpenAI の一次発表 | 未取得。二次ブログのみ |
| Simon Willison の「並列エージェントの統括」そのものを扱う 2026 年の記事 | 見つからず。関連するリンク投稿（2026-03-25）のみ開いた |
| OpenAI Symphony の発表記事 | 未取得。仕様書 `SPEC.md` は開けた |

## 1. 長く走る統括の文脈をどう保つか

### 1.1 方式ごとの整理

| 方式 | 採っている主体 | 効いたと言っていること | 効かなかった・注意と言っていること | 状態 |
| --- | --- | --- | --- | --- |
| 世代交代（文脈をリセットし、構造化した成果物で引き継ぐ） | Anthropic（Sonnet 4.5 世代のハーネス）、Gas Town（`gt handoff`）、Amp（Handoff）、ralph（毎ループ新しい文脈） | compaction は連続性を保つが「clean slate」を与えない。リセットは「context anxiety」（上限が近いと思い込んで早じまいする）を消す | 「orchestration complexity, token overhead, and latency」が増える。**Opus 4.5 では不要になり、1 本の連続セッション + 自動 compaction に戻した**。Managed Agents の記事はリセットを「dead weight」になったと書く | `[verified]` |
| 成果物・台帳への外部化（進捗ファイル、機能リスト、課題台帳） | Anthropic（`claude-progress.txt`、JSON の機能リスト、git ログ）、Beads / Gas Town、OpenAI（実行計画を repo に置く）、Carlini の C コンパイラ | 新しいセッションが「作業ディレクトリ確認 → git ログと進捗ノートを読む → 未完の最優先を選ぶ」で立ち上がれる。JSON は Markdown より壊されにくい | 進捗があるのを見て「もう終わった」と宣言する失敗がある。台帳への書き込みは無料ではない（Gas Town は mail 1 通が Dolt の 1 コミットになり、雑談で 1 日 100 コミット超になると警告） | `[verified]`（OpenAI 分のみ `[unverified-summary]`） |
| 統括の会話を薄く保つ（計画をスクリプト・外部ログへ出す） | Anthropic Managed Agents（session ログを文脈の外に置く）、Claude Code の dynamic workflows と Projects（前回メモ 5.1）、ralph（主文脈は scheduler に徹する）、OpenAI Symphony（統括は LLM ではなくデーモン） | 「nothing in the harness needs to survive a crash」。統括が死んでも `wake(sessionId)` でログから再開できる | 実行途中に人が口を挟めない（workflows、前回メモ）。計画が固定される | `[verified]` |
| subagent へ逃がす | Anthropic の研究システム、Claude Code、Cognition（2026 年に方針を一部変更） | 調査の汚れを主文脈に入れない。成果物を外部に書かせ、軽い参照だけ返すと「game of telephone」が減る | 統括が情報のボトルネックになる。子は親へ自発的に報告を書かない（Cognition）。トークンはチャットの約 15 倍（Anthropic、2025 年時点の数字） | `[verified]` |
| compaction 頼み | Anthropic（Opus 4.5 以降のハーネス）、Codex（二次情報）、Claude Code Projects | モデルが十分強ければ足場なしで連続運転できる | Amp は「lossy」「長くだらだらしたスレッドを助長する」として一度廃止。compaction が安全上の制約を落とすという研究の要約あり | Anthropic と Amp は `[verified]`、Codex と研究は `[unverified-summary]` |

### 1.2 一次情報の要点

- **Anthropic「Harness design for long-running application development」**（2026-03-24、Prithvi Rajasekaran）`[verified]` https://www.anthropic.com/engineering/harness-design-long-running-apps
  - リセットは「clearing the context window entirely and starting a fresh agent」と構造化した引き継ぎの組。Sonnet 4.5 では必須だった
  - Opus 4.5 でリセットをやめ、Opus 4.6 では sprint という分解の単位も外した。planner と evaluator は残した（planner を外すと作業範囲が小さくなりすぎた）
  - 原則: 「every component in a harness encodes an assumption about what the model can't do on its own」。その仮定はモデル更新で古くなる。ただし「the space of interesting harness combinations doesn't shrink as models improve. Instead, it moves.」
  - エージェント間の連絡はファイル（片方が書き、もう片方が読んで応じる）
  - コスト: 単独 20 分 9 ドルに対し、フルハーネス 6 時間 200 ドル
- **Anthropic「Effective harnesses for long-running agents」**（2025-11-26、Justin Young）`[verified]` https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
  - 2 つの失敗: やりすぎて文脈が尽き、半端な状態を残す。進捗を見て早すぎる完了宣言をする
  - 対策: 初回だけの initializer、以後は毎回「少し進めて、次の番のために明確な成果物を残す」coding agent。「compaction isn't sufficient」
  - 依頼文にあった「長時間エージェントのハーネスに関する 2026 年の記事」は、この 2025-11 の記事と上の 2026-03 の記事、下の Managed Agents の記事が該当すると判断した
- **Anthropic「Scaling Managed Agents: Decoupling the brain from the hands」**（2026-04-08）`[verified]` https://www.anthropic.com/engineering/managed-agents
  - brain（Claude + ハーネス）、hands（サンドボックスと道具）、session（イベントログ）を分離。session は「文脈の窓の外にある文脈オブジェクト」で、brain は `getEvents()` で必要な範囲を読み直す
  - ハーネスは使い捨て（cattle）。落ちたら新しいハーネスが `wake(sessionId)` で続きから
  - **利用者の「統括の世代交代」に最も近い公式の設計思想**。世代交代を特別な儀式にせず、「統括はいつ死んでもよい。状態はログにある」とする `[speculation]`
- **Anthropic「Effective context engineering for AI agents」**（2025-09-29）`[verified]` https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
  - 長い仕事の 3 手法: compaction（往復の多い仕事向き。やりすぎると微妙だが重要な文脈が落ちる）、structured note-taking（節目が明確な反復開発向き）、sub-agent（並列探索が効く調査向き）
- **Anthropic「How we built our multi-agent research system」**（2025-06-13）`[verified]` https://www.anthropic.com/engineering/multi-agent-research-system
  - lead は計画を Memory に保存する。上限が近づいたら新しい subagent を起こして引き継ぐ。エラー時はゼロからやり直さず、止まった場所から再開する仕組みと定期チェックポイントを持つ
- **Anthropic「The components of agent memory」**（2026-11-06、Lance Martin）`[verified]` https://www.anthropic.com/engineering/components-of-agent-memory
  - 記憶の層: transcript、memory notes、表現（wiki など）、毎回注入する最上層、dreaming（オフラインでログを見直してノートを直す処理）。「the top layer of the memory hierarchy has to stay relatively small」
  - **書きすぎは害**: Pokémon の実験で Sonnet 3.7 は 413 ファイルを書いてバッジ 1 個、Fable 5 は 9 ファイル + `global.md` でバッジ 4 個。古いモデルは整理に手番を浪費した
  - 記憶の用途は伝えるが使い方は指定しない。「失敗だけ記録せよ」のような固定ルールは効果を下げた
  - 並列エージェントが 1 つの表に書くと 57 件中 41 件しか残らず、1 件 1 ページにすると 57 件全部残った
  - Claude Code は `MEMORY.md` の先頭 200 行または 25 KB しかセッション開始時に読まない
- **Cognition「Don't Build Multi-Agents」**（2025-06-12、Walden Yan）`[verified]` https://cognition.com/blog/dont-build-multi-agents
  - 原則 2 つ: 文脈は個々のメッセージではなく全トレースごと共有する。行動は暗黙の決定を含み、食い違う決定は悪い結果を生む
- **Cognition「Multi-Agents: What's Actually Working」**（2026-04-22、Walden Yan）`[verified]` https://cognition.com/blog/multi-agents-working
  - 並列に書き込む群れは今も不採用。効くのは **書き込みを単線に保ち、他のエージェントは知恵だけ出す** 形: 白紙の文脈のレビュー役、強いモデルを道具として呼ぶ「smart friend」、manager が子を起こして内部 MCP で進捗を追う map-reduce
  - 未解決: manager が細かく指示しすぎる。子が「親と状態を共有している」と思い込む。子が自発的に報告しない。子の発見を兄弟へ伝える方法
- **Cursor「Scaling long-running autonomous coding」**（2026-01-14、Wilson Lin）`[verified]` https://cursor.com/blog/scaling-agents
  - planner / worker / judge。judge が周期の終わりに続行を判断し、**次の周期は白紙から始める**。drift と視野狭窄への対策として定期的な fresh start は今も必要
  - 「Many of our improvements came from removing complexity rather than adding it.」統合役（integrator）は「解決するより多くのボトルネックを生んだ」ので外した
- **Amp「Handoff (No More Compaction)」**（2025-10-23）`[verified]` https://ampcode.com/news/handoff
  - compaction を廃止し、次のスレッドの目的を人が指定 → Amp が現スレッドを分析して開始プロンプトと関連ファイル一覧を下書きとして出す。人が編集してから送る
  - **引き継ぎを「全部の要約」ではなく「次の目的に必要な分の抽出」にする** 点が、5 万トークンに膨らんだ引き継ぎ文書への直接の示唆になる `[speculation]`
- **Steve Yegge「Welcome to Gas Town」**（2026-01-01）`[verified]` https://yegge.ai/essays/welcome-to-gas-town/
  - 「In Gas Town, an agent is not a session.」identity（役割と作業履歴）は台帳に永続し、セッションは使い捨て。`gt handoff` で同じ席のまま新しいセッションへ。`gt seance` で前任のセッションを `/resume` して聞ける
  - 「handoff は毎タスクのあとに気軽に」という運用の勧めは Emergency User Manual 由来 `[unverified-summary]`
  - handoff mail の本文は Context / Status / Next の 3 節 `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/mail-protocol.md
- **Geoffrey Huntley「Ralph」**（2025-07-14）`[verified]` https://ghuntley.com/ralph/
  - 1 ループ 1 件、毎回新しい文脈。主文脈は scheduler として使い、重い仕事は subagent へ。理由はプロンプト側に書く（次のループは経緯を覚えていないため）。計画ファイルはよく捨てて作り直す
- **Carlini「Building a C compiler with a team of parallel Claudes」**（2026-02-05）`[verified]` https://www.anthropic.com/engineering/building-c-compiler
  - 統括エージェントなし。Bash のループが終わるたびに次を起こす。文脈ゼロから始まる前提で README と進捗ファイルを厚くする。テスト出力は数行に絞り、詳細はファイルへ
- **OpenAI「Harness engineering」**（2026-02-11 とされる）`[unverified-summary]`
  - AGENTS.md は約 100 行の目次に留め、`docs/` を記録の正本にする。実行計画は進行中と完了を別ディレクトリに置く。1 回の Codex 実行が 6 時間超。二次情報 https://codex.danielvaughan.com/2026/04/19/the-execplan-pattern-structuring-long-codex-sessions-with-plans-md/

### 1.3 読み取れること

- 世代交代は「モデルが弱かった時期の足場」として導入され、**Anthropic 自身は Opus 4.5 で外した**。一方で Cursor と Gas Town は「drift 対策としての fresh start」を今も使う。分かれ目は、統括が人と長く対話するか（文脈が雑多に溜まる）、機械的な周期で回るか `[speculation]`
- 世代交代を続ける人たちの共通点は、**引き継ぎを小さく保つ** こと。Gas Town は 3 節の mail、Amp は目的に絞った抽出、日本の実践（8 節の crandim）は上書き型のスナップショット。引き継ぎ文書が育ち続ける形は外には見当たらない `[speculation]`
- 4 か月で約 20 回という世代交代の頻度は、Gas Town の運用（毎タスクのあと）に比べればむしろ少ない。問題は回数ではなく、1 回あたりの重さと、統括が状態を自分の会話に抱えていること `[speculation]`

## 2. 「統括は 1 人」の排他と、複数の統括

| 実装・実践 | 排他の仕方 | 教訓 | 状態 |
| --- | --- | --- | --- |
| Cursor（初期の方式） | 共有ファイル + ロックで作業を claim | 「Twenty agents would slow down to the effective throughput of two or three.」ロックを持ちすぎる・放さないエージェントが出た。楽観的並行制御に替えたが、階層なしでは皆が安全な小変更に逃げた。最終的に役割の階層（planner / worker / judge）へ | `[verified]` https://cursor.com/blog/scaling-agents |
| Carlini の C コンパイラ | `current_tasks/` にテキストファイルを書いて claim。競合は git の同期が弾く | 統括なしでも回る。ただし全員が同じバグに群がる問題は、ロックではなく **仕事の切り方**（GCC を oracle にして別々のバグへ散らす）で解いた | `[verified]` https://www.anthropic.com/engineering/building-c-compiler |
| OpenAI Symphony（仕様 v0.1） | 統括は LLM ではなく 1 個のデーモン。スケジュール状態を変えるのは統括だけ。Unclaimed / Claimed / Running / RetryQueued / Released | 二重起動の防止は「単一の権威」で担保。永続 DB なしで、再起動後は tracker とファイルシステムから状態を導き直す | `[verified]` https://github.com/openai/symphony/blob/main/SPEC.md |
| MCP Agent Mail | ファイル・glob への advisory な予約（TTL つき、exclusive 指定可）。重なりは衝突として報告されるが許可は通る。任意の pre-commit フックで強制 | lease は強制ではなく意思表示として使う。期限切れは `doctor` が掃除 | `[verified]` https://github.com/Dicklesworthstone/mcp_agent_mail （Python 版は deprecated、Rust 版が後継と README に明記） |
| Beads | `bd update <id> --claim` が担当設定と in_progress 化を原子的に行う | 複数エージェント・複数ブランチで **連番 ID が衝突した** ため、短いハッシュ ID へ移行した | claim とハッシュ ID の目的は `[verified]` https://github.com/gastownhall/beads 、連番からの移行の経緯は `[unverified-summary]` |
| Gas Town | Mayor、Deacon、Boot は town に 1 つの singleton で、ID は `hq-mayor` のように固定。identity は環境変数（`BD_ACTOR`、`GT_ROLE`）で spawn 時に与える | 「Mayor が同時に 2 つ起きたらどうなるか」の記述は見つからなかった。**席は名前で一意にし、セッションは使い捨て** という形で、lease を持たずに済ませている。Boot には二重起動防止のマーカーファイル（TTL 5 分）がある | `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/architecture.md 、https://github.com/gastownhall/gastown/blob/main/docs/concepts/identity.md 、https://github.com/gastownhall/gastown/blob/main/docs/design/dog-infrastructure.md |
| Anthropic の社内ソース管理（Scion） | ロックなし。ref の移動は 1 行の compare-and-swap。マージキューの全体ロックは再現できず、マージ後のテストと Claude による修復に倒した | エージェント規模では「全員が合意する全体状態」を減らす方向 | `[verified]` https://www.anthropic.com/engineering/redesigning-source-control （2026-10-13） |
| lease 型の leader election を skill として配る小規模リポジトリ | heartbeat つき lease で主担当を 1 つに | 中身は未確認 | `[unverified-summary]` https://github.com/Alpha-Park/genpark-agent-distributed-leader-election-consensus-skill |

### 複数の統括・複数の人

- **ai-orchestrator**（個人リポジトリ、issue は 2026-11-08）: 1 人が最大 5 つの manager セッションを同時に動かす前提で設計。manager ごとのチャットではなく **全 manager 共通の 1 本の Action items キュー** に問いを集める。区別は run（実行）単位 `[verified]` https://github.com/nickderobertis/ai-orchestrator/issues/2408
- **Gas Town**: 「currently operates as a single-town system」。複数 town の連合（federation）は計画段階。人は email で全体に一意、エージェントは town 内で一意。「Agents execute. Humans own.」git の author name にエージェント、author email に所有者の人を入れて帰属を分ける。人ごとの常駐作業場は `crew/<name>/`（worktree ではなく完全な clone） `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/why-these-features.md 、同 `identity.md`
- **MCP Agent Mail**: プロジェクトをまたぐ連絡は `request_contact` / `respond_contact` で承認された相手だけ `[verified]`
- **Claude Code agent teams**: 1 セッション 1 チーム、lead 固定（前回メモ 2.2）

### 読み取れること

- 「統括の座」そのものに lease を張る公開実装は、今回も実質的に見つからなかった。外の主流は (a) 統括を LLM ではなく単一のデーモンにする（Symphony）、(b) 席を固定名で一意にしてセッションは使い捨てにする（Gas Town）、のどちらかで、**排他が要る状況を作らない** 方向 `[speculation]`
- ロックで作業を配る方式は Cursor が明確に失敗を報告している。一方、Beads や Agent Mail のように「原子的な claim」「期限つきの意思表示」に留める lease は生き残っている `[speculation]`
- 複数の統括を置く実践はまだ少なく、置く場合は「統括ごとの区別」より「人から見た面を 1 つにする」（共通キュー、帰属の記録）ほうへ設計が向かっている `[speculation]`

## 3. エージェント間の配送と受領確認

### 3.1 方式の比較

| 方式 | 実例 | 届いたことの確かめ方 | 読んで着手したことの確かめ方 | 弱点 | 状態 |
| --- | --- | --- | --- | --- | --- |
| tmux send-keys で本文を打ち込む | 初期の multi-agent-shogun、多数の自作 | 終了コードだけでは分からない。pane を読んで入力欄に残っていないか確かめる | なし | 入力衝突、貼り付け判定で Enter が改行になる、補完に Enter を奪われる、思考中の割り込み | `[verified]`（3.2） |
| ファイルの受信箱 + 短い起床合図 | multi-agent-shogun v3.8 以降（YAML の inbox、`flock`、`inotifywait`、Stop フック）、Claude Code agent teams の mailbox | 書き込み成功 | 受け手自身がフックで未読を処理する。busy / idle は受け手がフラグファイルで自己申告 | アイドル中はフックが発火しない。起動直後のデッドロック | `[verified]` https://zenn.dev/shio_shoppaize/articles/shogun-hook-revolution 、https://github.com/yohey-w/multi-agent-shogun/blob/main/README_ja.md |
| MCP の mail サーバー（git + SQLite） | MCP Agent Mail | 受信者ごとに保存 | **read と ack のタイムスタンプを受信者ごとに別々に持つ**。送信時に `ack_required`、受け手が `acknowledge_message` | 通知は基本ポーリング（`fetch_inbox` の `unread_only`）。push の記述は見当たらず | `[verified]` https://github.com/Dicklesworthstone/mcp_agent_mail |
| 課題台帳 + mail + nudge | Gas Town（Beads / Dolt） | mail は bead として永続 | `gt mail read` と `gt mail ack`。完了は `POLECAT_DONE` などの型つきメッセージ。次のセッションは mail ではなく bead から作業状態を知る | mail 1 通 = 1 コミット。既定は nudge にし、mail は「相手が再起動しても要るか」で使い分ける | `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/mail-protocol.md |
| ソケット | Claude Code の cross-session messaging（前回メモ 2.2）、cmux、herdr | Delivered / Held / Refused | 仕様に無い | 同一ベンダー内に閉じる | 前回メモ参照 |
| tmux wait-for（合図だけ）+ 結果はファイル | GENDA の実践 | キー入力を使わないので衝突しない | 完了の合図のみ。子が合図を送らないと親は待ち続ける | Codex のサンドボックスが tmux ソケットを塞ぐ。親が死ぬと合図が空振り | `[verified]` https://zenn.dev/genda_jp/articles/cfcaeeb51d23e7 （2026-03-23） |
| git（lock ファイル、ブランチ、コミット） | Carlini の C コンパイラ | push の成否 | claim ファイルの存在 | マージ競合が頻発（Claude が自力で解いた） | `[verified]` |
| 内部 MCP で manager が子を追う | Devin の manager / child | 未公開 | 子は既定では親へ報告を書かない、と明記 | 訓練環境に無い振る舞いは出にくい | `[verified]` https://cognition.com/blog/multi-agents-working |

### 3.2 tmux send-keys の信頼性についての他の実践者の報告

- **macf issue #1442**（2026-10-16）`[verified]` https://github.com/groundnuty/macf/issues/1442
  - Claude Code 2.1.300 で、長い文（約 650 文字）を Enter と同じ送信に含めると貼り付けと判定され、Enter が改行になる。追い打ちの Enter も 1 秒後・3 秒後とも効かない（時間の問題ではない）
  - **helper は終了コード 0 を返し、呼び出し側は `tmux_wake_delivered` と記録していた**。「届いたつもり」の典型
  - 採った修正: `send-keys -l --` で本文だけ打つ → pane が変化しなくなるまで待つ（上限約 3 秒）→ Enter を 1 回 → 入力行に本文の先頭約 30 文字が残っていないか検証 → 残っていれば Enter を最大 2 回再送 → だめなら非ゼロで終了。入力行が見つからなければ Enter を送らず別の終了コード
  - 追補: 入力欄に薄く出るプロンプト候補（dim 表示）を「未送信の本文」と誤認するため、dim の範囲を検証から除く修正が続いた
  - bracketed paste（`paste-buffer -p`）+ Enter も試験では通った
- **anthropics/claude-code issue #15553**（2025-12-28 起票、open、公式の回答なし）`[verified]` https://github.com/anthropics/claude-code/issues/15553
  - 対話モードへのプログラム的な入力送信を求める要望。10 エージェントの運用者が「Enter が補完・プロンプト候補に奪われる。`/clear` などのコマンドも通らない」と報告し、本文 → 0.3 秒 → Escape → 0.1 秒 → Enter の回避策を示した。`CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` では直らないとも
  - 提案の 1 つが「セッションごとの Unix ソケット」。その後 cross-session messaging として実装された形になる（前回メモ 2.2） `[speculation]`
- **Gas Town**: `gt nudge` は「`tmux send-keys` の debounce の問題」を回避するための専用コマンド。GUPP（hook に仕事があれば自分で走れ）は Claude Code が入力を待ってしまうため単独では当てにならず、起動 30〜60 秒後に nudge する仕組みを重ねている `[verified]` https://yegge.ai/essays/welcome-to-gas-town/
- **multi-agent-shogun**: send-keys の入力衝突に **48 回の修正** を重ねたが根本解決にならず、v3.8 で Stop フック + フラグファイルへ移行した。教訓は「状態を外から推測せず、エージェント自身に報告させる」。README は「メッセージ本文は tmux を通さない。通すのは短い起床合図だけ」と定める `[verified]`
- そのほかの回避策（`C-m` ではなく名前つきの `Enter` を送る、本文中の `Enter` などの語がキー名として解釈されるので `-l` を使う、長文はファイルに書いて「これを読め」とだけ送る）`[unverified-summary]` https://getcodeman.com/guides/claude-code-enter-key-ignored-tmux 、https://github.com/mvschwarz/openrig/issues/496

### 3.3 読み取れること

- 外の実践者は同じ穴に落ち、同じ順で抜けている: 本文を send-keys で送る → Enter を分ける → 待ちと再送を足す → **本文はファイルか台帳へ、tmux は起床合図だけ** → さらにフック・ソケット・wait-for へ移り、tmux への入力をやめる `[speculation]`
- 「届いた」と「読んで着手した」を分けている公開実装は、MCP Agent Mail（read と ack を別に記録）と Gas Town（mail の ack、型つきの完了メッセージ、stale の再エスカレーション）の 2 つ。ほかは配送層の結果までで、着手の確認は「状態を台帳で見る」に任せている `[speculation]`
- Gas Town の設計メモは「下流が正本を自分でポーリングしているなら、合図は遅延を縮めるだけでよい。合図を落としても 1 周期遅れるだけ」と整理している。**配送を完璧にするより、落ちても困らない構造にする** という方向 `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/polecat-self-managed-completion.md

## 4. 人の判断を集める面

### 4.1 実装例

| 実装 | 何を集めるか | 選択肢・推奨の扱い | 人への届け方 | 状態 |
| --- | --- | --- | --- | --- |
| ai-orchestrator の Action items（2026-11-08 の設計 issue） | 「人への問いはすべて item」。manager のチャットだけで聞くことを禁じる | 選択肢は最大 6 個（id、80 文字以内の題、説明）。自由記述は常に可 | Web ページ（スマホから操作する前提）、CLI、API。**複数の回答を 1 回で送る batch**（1〜50 件）。manager は答え 1 件ごとではなく batch 1 回につき 1 度だけ起こされる | `[verified]` https://github.com/nickderobertis/ai-orchestrator/issues/2408 |
| decisions（MCP サーバー + TUI、スター 1 の個人作） | 複数セッションの問いを 1 本のキューへ | `ask_user` に選択肢と **推奨** と文脈。選択肢は利用者の視点で書かせ、「I」「we」を含むものは弾く | 端末のカードの束。数字キーで選ぶ、メモ、自由回答、聞き返し。Telegram モード。問いはディスクに残り、待ちは既定 50 秒で pending を返して後から `wait_for_answer("D-7")` | `[verified]` https://github.com/whitel1ght/decisions |
| Gas Town の escalation | 行き詰まりと障害 | 選択肢・推奨の欄は無い。「複数の妥当な道があり選択が要る」ための `decision` カテゴリは **計画中で未実装** | 重大度で経路が変わる: MEDIUM は bead + Mayor への mail、HIGH は + 人へ email、CRITICAL は + SMS。ack が無いまま 4 時間で stale になり、重大度を上げて再送（最大 2 回） | `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/escalation.md |
| MCP Agent Mail の Human Overseer | 人 → エージェントの指示 | なし | Web UI から「HumanOverseer」名義の高重要度メッセージ。「今の作業を止めて優先し、終わったら元の計画へ戻れ」という前置きが付く | `[verified]` |
| 通知フック → 1 本のログ | 権限プロンプトと入力待ち | なし（どのセッションが待っているかの行だけ） | `Notification` フックで `~/inbox.log` に追記し、個別の通知は切る | `[verified]` https://dev.to/gabrielanhaia/stop-letting-five-coding-agents-ping-you-answer-them-in-batches-from-one-inbox-2in3 （11 月 3 日。年はページに無いが内容から 2026 年と読める） |
| QUESTIONS ファイル + 通し番号（日本の実践） | 未解決の問いが 5 個以上になったらセッションごとのファイルへ | 接頭辞つきの通し番号（Q = 質問、P = 前提、T = タスク、O = 選択肢）。番号は再利用しない | 人が回答欄に直接書き込む。「T62 done」「Q58 先送り」と短く返せる | `[verified]` https://zenn.dev/crandim_r_and_d/articles/260822_a10_handoff_questions_workflow （URL から 2026-08-22） |
| multi-agent-shogun の `dashboard.md` | 進捗と承認待ち | 将軍が選択肢を出し、人は選ぶ・承認する・却下する | 家老だけが更新する 1 枚の Markdown を人がプレビューで眺める | `[verified]` https://zenn.dev/shio_shoppaize/articles/5fee11d03a11a1 |
| HumanLayer（`require_approval`、`human_as_tool`、Slack / email） | 危険な関数呼び出しの承認、人への問い | 未確認 | Slack、SMS、email | `[unverified-summary]` https://humanlayer.dev/docs |
| Claude Code agent view / Projects / channels | 待っているセッションの一覧 | なし | 前回メモ 5.3 | 前回メモ参照 |

### 4.2 人がボトルネックになる問題についての 2026 年の議論

- **承認疲れの数字**: Claude Code の利用者は権限プロンプトの 93% を承認している。「Over time that leads to approval fatigue, where people stop paying close attention to what they're approving.」対策として分類器に判断を委ねる auto mode を作った。分類器の見逃し率 17% を「the honest number」として公表 `[verified]` https://www.anthropic.com/engineering/claude-code-auto-mode （2026-03-25）
- **監督には容量がある**: 人の疲労がエスカレーションの量とともに増えると仮定すると、安全性は逆 U 字になり、「more human oversight can make a system less safe」。最も安全な方針は「全部を上げる」より少ない。ただしモデル上の結果で、人を使った実験ではないと著者が断っている `[verified]` https://arxiv.org/abs/2606.08919 （2026-06-08、Emre Turan）
- **監督の負荷の逃がし方**: 経験ある開発者 19 人の観察から、負荷の管理の仕方を 3 つに整理: 計画段階に力を集める、監督の仕事を別のエージェントに委ねる、繰り返す指示を再利用できる資産にする `[verified]` https://arxiv.org/abs/2609.24234 （2026-09-21、Park ほか、査読中）
- **割り込みをやめて節目でまとめて答える**: 個別通知を切り、待ちはキューに溜め、自分の作業の節目（コミット後、テスト後）に古い順に片づける。上限は約 25 分。差分レビューは別の時間枠にする。根拠は割り込み研究（Mark 2005 ほか）で、コーディングエージェントを直接調べたものではないと著者が断っている `[verified]`（上の dev.to 記事）
- **人は誤りの速度を抑える栓でもある**: Mario Zechner「A human is a bottleneck. A human cannot shit out 20,000 lines of code in a few hours.」エージェントの群れはその栓を外すので、小さな誤りが持続不能な速さで積み上がる。1 日に生成させる量に上限を置け、と勧める。Willison も「コードを打つことはもうボトルネックではない」と同意 `[verified]` https://simonwillison.net/2026/Mar/25/thoughts-on-slowing-the-fuck-down/ （2026-03-25）
- **設計が律速になる**: Gas Town は実装計画を速く消化するので、人が設計と計画を大量に供給し続けないと止まる。Mayor は「Claude のタブを絶えず切り替える」注意のコストを下げる `[verified]` https://maggieappleton.com/gastown （ページ表示は「10 か月前」。2026-01 頃）
- Yegge の「AI Vampire」（エージェント作業は 1 日 4 時間が現実的という主張）`[unverified-summary]`

### 4.3 読み取れること

- 「どのセッションが待っているか」を並べるところまでが主流。**問いを第一級の項目にし、選択肢と推奨を付け、1 か所に集めてまとめて答える** 実装は、個人作の小さなものが 2026 年後半に出始めた段階で、いずれも採用は小さい `[speculation]`
- 利用者の判断ボードは、この少数派の設計とほぼ同じ形（問いは必ず項目化、選択肢と根拠、通し番号）で、時期としては先に着いている `[speculation]`
- 外の議論が足しているのは 2 点。(1) **上げる量そのものを減らす**（逆 U 字、分類器への委譲、計画段階への前倒し）。問いが 100 件を超えたこと自体を指標として見る。(2) **答えを束で返し、統括を 1 回だけ起こす**（batch と節目）`[speculation]`

## 5. 見張りと復帰

### 5.1 実装例

- **Gas Town の watchdog の連鎖** `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/dog-infrastructure.md
  - 最下層は Go のデーモン（LLM ではない「dumb transport」）。3 分ごとに tick。その上に Boot（毎 tick 起こされる短命の AI。Deacon を起こすべきかだけ判断する）、Deacon（巡回を続ける AI）、rig ごとの Witness
  - 理由: 「hung した Deacon は自分の hang を検出できない」。だから外側の観察者として Boot を置く
  - Deacon は巡回のたびに `heartbeat.json` を書く。5 分未満は新鮮、5〜15 分は stale（mail が溜まっていれば nudge）、15 分超は起こす、セッションが死んでいればデーモンが起動
  - 多段の逃げ道: Boot の判断 → デーモンの heartbeat 確認 → tmux からの発見 → 人への mail。tmux が無い縮退時は Boot が純粋な Go の閾値判定で動く
  - 教訓: 「tmux セッションがあること」と「中のプロセスが生きていること」は別。ゾンビは再起動前に殺す。エージェントの状態は台帳に持たず tmux から導く（二重管理でずれるため）。観測できない状態（stuck など）だけ台帳に持つ
  - マシン再起動後の復元は、このページでは扱っていない
- **Gas Town: 監督を主経路から外す** `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/polecat-self-managed-completion.md
  - 作業者の完了を Witness が 1 件ずつ処理していたため、同時完了が詰まって数分待ち、Witness が単一障害点になった。作業者が自分で idle へ遷移する形に変え、Witness は異常（ゾンビ、stuck、汚れた作業場、古いマージ要求）だけ見る観察者にした
  - 「Self-recycling is preferred. Mechanical intervention is the safety net, not the primary mechanism.」
- **OpenAI Symphony** `[verified]` https://github.com/openai/symphony/blob/main/SPEC.md
  - stall 検出: 最後のエージェントイベントからの経過が `codex.stall_timeout_ms`（既定 300000）を超えたら worker を殺して再試行に回す
  - 毎 tick、配る前に照合（reconciliation）を走らせる。再起動後は再試行タイマーや実行中の状態を復元せず、tracker を読み直して配り直す
- **multi-agent-shogun** `[verified]`（README_ja）
  - 無応答時の段階: 0〜2 分は通常の nudge、2〜4 分は CLI によって Escape や Ctrl-C を挟む、4 分以上で文脈リセット（`/clear`。5 分に最大 1 回）。`/clear` 後の復帰コストは約 6,800 トークンと記載
  - 安全装置の初期化漏れで「強制 nudge が一度も動いていなかった」ことが、家老の停止で初めて分かった。テスト用のモック CLI が実機より賢く、バグを隠した（`shogun-hook-revolution`）
- **macf**: 起床の helper が終了コード 0 を返すので「delivered」と記録され、未送信が気づかれなかった。**見張りの記録が成功の検証ではなく実行の事実を書いていた** 例（3.2）`[verified]`
- **Claude Code auto mode**: 連続 3 回または合計 20 回の拒否で止めて人へ上げる、という打ち切りの形 `[verified]`
- **Claude Code agent view の supervisor**: 予期せぬ終了は再起動、supervisor 自体が止まると約 1 分で子も止まる、マシン再起動後は手動再開（前回メモ 2.2）

### 5.2 マシン再起動のあとの復元

| 実装 | 方法 | 限界 | 状態 |
| --- | --- | --- | --- |
| tmux-agent-resume（スター 0 の個人作） | フック（SessionStart / UserPromptSubmit / Stop）で pane ごとの会話 ID と「ターンの途中だったか」を記録。systemd timer が 5 分ごとにスナップショット。復元時に `claude --resume <uuid>` / `codex resume <uuid>` と起動オプションを戻す。続行の合図は既定で送らず人を待つ | 一意に決まらない pane は推測せず復元しない。busy 判定は画面の末尾 20 行。Codex の内部 DB に依存 | `[verified]` https://github.com/martinfrancois/tmux-agent-resume |
| AgentsMonitoring（スター 0 の個人作） | cron の `@reboot` と毎分の keepalive が最外層。tmux の各 pane のプロセス木を見て、エージェントが死んでいれば `claude --resume <id>` で再起動 | stuck（生きているが進まない）の検出は無い。cron 自体を見張るものは無い。会話の持ち主が曖昧なら新しい会話で始めて警告 | `[verified]` https://github.com/h0nz1k/AgentsMonitoring |
| tmux-assistant-resurrect | tmux-resurrect に乗り、5 分周期で会話 ID を保存 | 二重起動の注意あり | `[unverified-summary]` https://github.com/timvw/tmux-assistant-resurrect |

- resume は会話を戻すだけで、落ちた瞬間に走っていたツールは完了も再実行もされない。`--settings` や `--mcp-config` などのフラグも戻らない `[unverified-summary]` https://github.com/TonyHeadband/fleet-manager/issues/113

### 5.3 読み取れること

- 「見張りの見張り」の定石は 3 つ。(1) **最下層は LLM でない機械的な仕組み**（cron、systemd、Go のデーモン）にする。(2) 見張られる側が **heartbeat を自分で書き**、見張る側は鮮度だけを閾値で判定する（黙ったこと = 古くなったこと、として検出できる）。(3) 見張りの記録は「送った」ではなく「結果を検証した」を書く `[speculation]`
- 監督エージェントを全イベントの通り道に置くと詰まる。Gas Town はそれを経験して、監督を例外検出に下げた `[verified]`
- マシン再起動後の「関係ごとの復元」を公式・主要ツールが解いていない点は前回メモのとおりで、今回見つかったのも個人作の小さな道具だけ。Symphony のように「状態を持たず、正本から導き直す」のが最も壊れにくい `[speculation]`

## 6. 異種モデルのセカンドオピニオン

### 6.1 仕組みの実例

| 実例 | 形 | 要点 | 状態 |
| --- | --- | --- | --- |
| OpenAI 公式「Codex plugin for Claude Code」（`openai/codex-plugin-cc`、2026-03-30 または 31 公開、約 35.0k スター） | Claude Code のプラグイン。ローカルの Codex CLI と app server を呼ぶ薄い包み | `/codex:review`（読み取り専用レビュー）、`/codex:adversarial-review`（設計・前提へ挑むレビュー。焦点を指定可）、`/codex:rescue`（作業の委譲）、`/codex:transfer`、`/codex:status` / `result` / `cancel`、`--background`。**review gate**（Stop フックで Claude の応答を Codex がレビューし、問題があれば停止を差し戻す）は「長い Claude / Codex のループを作り、利用枠を速く使い切りうる」と警告つきで、見張っているときだけ有効にせよと書く | スター数とコマンドは `[verified]` https://github.com/openai/codex-plugin-cc 、公開日は `[unverified-summary]` https://gihyo.jp/article/2026/03/codex-plugin-cc |
| PAL MCP（旧 Zen MCP、約 11.8k スター） | MCP サーバー | `consensus`（複数モデルの意見を立場つきで集める）、`codereview`、`challenge`（反射的な同意を避ける）、`clink`（CLI から別の CLI を呼ぶ橋。隔離した CLI を subagent として起こし、最終結果だけ返す） | `[verified]` https://github.com/BeehiveInnovations/pal-mcp-server |
| Devin Review と「smart friend」 | 製品内 | 白紙の文脈のレビュー役が Devin の PR 1 本あたり約 2 件のバグを見つけ、約 58% が重大。レビュー役には仕様を渡さず diff だけ見せる。指摘は利用者の指示と突き合わせて絞る橋を通す（ループと範囲外作業の防止）。smart friend は主役が弱いと効かず、最前線のモデル同士で「得意なほうへ回す」形で効いた | `[verified]` https://cognition.com/blog/multi-agents-working |
| Cursor の役割別モデル | 製品内 | 長い自律作業は GPT-5.2 が良く、Opus 4.5 は早く止まり近道しがち。1 つのモデルに全部させず役割で割り当てる | `[verified]` https://cursor.com/blog/scaling-agents |
| tmux で別 pane の Codex にレビューを頼む（日本の実践） | skill + send-keys | Claude → Codex は自動で実行されるが、Codex → Claude は入力欄に届くだけで手動の実行が要る | `[verified]` https://zenn.dev/tokium_dev/articles/0ef3f807d67e7c （2026-01-30） |

### 6.2 効果についての報告

- **対照実験**: 150 個の誤りを埋めた 30 件の成果物、900 回のレビュー、2 社 3 モデル `[verified]` https://arxiv.org/abs/2610.01471 （2026-10-01、Tae-Eun Song、単著のプレプリント）
  - 最上位の別モデルによるレビューは、**同じモデルの新しいセッションによるレビューと F1 で有意差なし**（同等とまでは言えないと著者）
  - ただし見つける誤りは部分的に違う（重なりは Jaccard で 41.2%）
  - 2 回レビューするなら、同モデル 1 回 + 別モデル 1 回は、同モデル 2 回より多く見つけた（56.7% 対 42.7%）。一方で最上位の別モデル 2 回には勝てず、**「モデルの違い」と「レビュー役の能力」は切り分けられない**
  - 軽量な別モデルは同モデルのレビューより良くならない
- 実践者の報告（逸話）: 「Claude が見落としたエッジケースを Codex が指摘した」「同じ AI に聞き直すより多角的」。限界として「両方が同じ見落としをする」「複雑な業務ロジックの誤りは見抜けない」（tokium）`[verified]`。「Claude は設計の問題、Codex は正確性の問題を拾いやすい」`[unverified-summary]`

### 6.3 読み取れること

- 効くのは「別ベンダーであること」より **白紙の文脈であること** と **レビュー役が十分強いこと**。別モデルは「2 回目のレビュー」として足すと上積みがある `[speculation]`
- 自動で往復させる形（review gate）は公式自身が暴走と枠の消費を警告している。指摘を元の指示と突き合わせて絞る段を挟むのが Cognition の解 `[verified]`
- 2026-03 以降、Claude Code から Codex を呼ぶ道は公式プラグインで足りる。自作の `so-compare` に当たる層は、外から見ると「公式へ寄せられる」側に入った `[speculation]`

## 7. ハーネスを軽くする動き

### 7.1 議論

| 出典 | 日付 | 主張 | 状態 |
| --- | --- | --- | --- |
| Anthropic「Harness design…」 | 2026-03-24 | 部品はモデルの弱さについての仮定。モデル更新のたびに外して確かめる。ただし面白い組み合わせの空間は縮まず「動く」 | `[verified]` |
| Anthropic「Managed Agents」 | 2026-04-08 | context anxiety 対策のリセットは Opus 4.5 で「dead weight」になった。だからハーネスを差し替えられる境界で区切る | `[verified]` |
| Cursor「Scaling agents」 | 2026-01-14 | 改善の多くは複雑さを足すのではなく外すことから来た。「The harness and models matter, but the prompts matter more.」 | `[verified]` |
| Phil Schmid「The importance of Agent Harness in 2026」 | 2026-01-05 | 「Build to delete」: 新しいモデルがロジックを置き換えるので、消せるように作る。Manus は 6 か月で 5 回作り直し、Vercel は道具の 80% を削った（後者 2 つは記事内の二次引用） | `[verified]` https://www.philschmid.de/agent-harness-2026 |
| Han-Chung Lee「Hidden Technical Debt of AI Systems: Agent Harness」 | 2026-05-08 | ハーネスのコードの多くは一時的な足場。「The model ate the harness.」処方は「thin harness, fat skills」。**各部品の外しやすさを測る: 外すのに 1 時間なら選択肢、1 週間なら負債**。アプリ側の足場は「90 日の成果物」と見なす。長持ちするのはデータ、評価、環境。自社ハーネスで訓練されたモデルは他社製ハーネスでは分布外で動く（train / prod skew） | `[verified]` https://leehanchung.github.io/blogs/2026/05/08/hidden-technical-debt-agent-harness/ |
| Cognition（Latent Space の対談） | 2026-05 頃 | Sonnet 3.7 の登場で Devin の以前の足場を外した。Devin に他の Devin を起こす MCP を与えたら混沌とした（後者は対談相手の発言） | `[verified]` https://www.latent.space/p/cognition |
| 反対側の指摘 | 2026 | 自作の足場は、伸びる部分（モデル）から伸びない部分へ複雑さを移す「逆向きの bitter lesson」になりがち | `[unverified-summary]` https://x.com/buckeyevn/status/2014171253045960803 |

### 7.2 自作をやめて寄せた人・続けている人

| 誰 | 何をしたか | 理由 | 状態 |
| --- | --- | --- | --- |
| imudak（Zenn、2026-02-15） | multi-agent-shogun の fork を約 2 週間で中断し、Claude Code の agent teams + OpenClaw のセッション管理へ | 公式の機能が将軍・家老・足軽の役割をほぼ吸収した。両方を保つ理由がなくなった。「移行判断は早いほうがよかった」。ただし移行先は環境固有の要素が多く再現性が低い、という対価も書く | `[verified]` https://zenn.dev/imudak/articles/multi-agent-orchestration-comparison |
| infohiroki（2026-02-07） | 10 体 → 5 体（2 階層）へ自作を縮小して **継続** | 10 体は認知負荷が高い。3 階層は伝言ゲーム。同時に動くのは半分。公式のほうが安定と認めつつ、通信設計・pane 管理・コスト最適化の学びに価値を置く | `[verified]` https://infohiroki.com/blog/2026-02-07-claude-code-multi-agent-orchestration |
| multi-agent-shogun 本体（v5.1.0） | **継続**。ただし send-keys をやめてフック + ファイルへ、対応 CLI を 7 種へ | 異種 CLI をまたぐ階層は公式に無い | `[verified]` |
| Gas Town | **継続しつつ土台を公式へ寄せる計画**。Witness を Claude Code agent teams の team lead にし、tmux のセッション管理・`gt nudge`・ゾンビ検出を置き換える設計書がある（未実装、Phase 1 は条件つき go）。「The transport changes. The ledger endures.」デーモン、Boot、Deacon は agent teams に障害復旧が無いので残す | 台帳への同時書き込みの負荷を 80〜90% 減らす見込み。指示頼みの規則を構造で強制できる | `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/witness-at-team-lead.md |
| Steve Yegge 本人 | Gas Town を Gas City の人々とコミュニティ保守へ引き渡し、本人はコンサルへ重心 | 「非常に成功した実験」。Gas City は役割・構成・パターンを宣言的な pack にした SDK | `[unverified-summary]` https://yegge-ai.pages.dev/history 、https://devops.com/gas-town-builder-all-ai-software-factories-are-bespoke |
| GENDA（2026-03-23） | agent teams の公開後も tmux の自作を **継続**（wait-for へ改良） | 設計・調査は Codex のほうが良いと感じており、Claude Code 以外も使いたい | `[verified]` |
| Cursor | 自社ハーネスから統合役を **削除** | ボトルネックを増やした | `[verified]` |

### 7.3 文書の手順が重くなる問題

- **Birgitta Böckeler**（2025-10-15、martinfowler.com）: spec-kit は「a LOT of markdown files」を生み、「I'd rather review code than all these markdown files.」小さなバグ修正に対しては「like using a sledgehammer to crack a nut」。細かく書いてもエージェントが全部には従わない（統制の錯覚）`[verified]` https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- **Roman Stranghöner（INNOQ）**（2026-04-08）: 短いストーリーが 1,070 行の Markdown に膨らみ、「building turns into documenting」。長く整った仕様は「a well-organized illusion of safety」。処方: 考える段階の仕様は薄く。計画は作業用文書として扱い、残さない。**決定は仕様から分けて ADR に**。繰り返す問題は文書ではなくハーネス（テスト、linter、構造ルール）へ移す。「Minimize Output, Maximize Outcome & Impact」`[verified]` https://www.innoq.com/en/blog/2026/04/versteckte-kosten-spec-driven-development/
- **Anthropic の記憶の記事**（2026-11-06）: 書く量が少ないモデルのほうが成績が良い。wiki が元資料の 1.77 倍に膨らんだ例は「effectively abstracted nothing」。最上層は小さく保つ `[verified]`
- **OpenAI の harness engineering**: 大きな AGENTS.md は失敗し、短い目次 + 構造化した `docs/` + 機械的な鮮度チェックへ `[unverified-summary]`
- **crandim**: HANDOFF は追記ログではなく上書きのスナップショット。HANDOFF にしか無い知識は作らない `[verified]`
- 古い仕様が残ると、後のエージェントが古い意図を現行として扱う（spec drift）`[unverified-summary]`

### 7.4 読み取れること

- 「やめた」人の理由はほぼ 1 つ: **公式が同じ役割を吸収し、両方を保つ理由が消えた**。「続ける」人の理由は 3 つ: 異種 CLI を使いたい、公式に無い層（障害復旧、台帳）がある、学びとして価値がある `[speculation]`
- 続ける人も **輸送の層は公式へ寄せ、台帳と規律の層を残す** 方向へ動いている（Gas Town の設計書が最も明確）`[speculation]`
- 文書については、外の処方はそろって「量を減らす」「決定だけを分けて残す」「繰り返す注意は文書ではなく検査へ移す」。蒸留文書がコードの 3 倍という状態は、外の議論では警告の対象にあたる `[speculation]`

## 8. 日本語圏の実践

| # | 記事 | 日付 | 何を自作したか | 何に困ったか | 何へ移ったか | 状態 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | shio_shoppaize「Claude Code で『AI 部下 10 人』を作ったら…」https://zenn.dev/shio_shoppaize/articles/5fee11d03a11a1 | 2026 年初頭（ページから日付を取れず） | 将軍 → 家老 → 足軽 8 の 3 階層。YAML ファイル + send-keys の起床。`dashboard.md` | ポーリングは API を食うので却下。send-keys は本文と Enter を分けないと効かず、家老自身が規則を破って全足軽が停止。タスクを 1 ファイルにまとめたら 1 人が全員分を実行 | イベント駆動、足軽ごとのタスクファイル。Max ×20 へ | `[verified]`（日付は未確認） |
| 2 | 同「tmux send-keys を殺して Hook に統一したら家老が永眠した…」https://zenn.dev/shio_shoppaize/articles/shogun-hook-revolution | 2026-02-28（更新 2026-08-15） | Stop フック + フラグファイルによる配送と busy 判定 | send-keys の入力衝突に 48 回の修正。思考中の割り込み。`capture-pane` では busy を判定できない。移行翌日に起動直後のデッドロック | 「外から推測」から「自己申告」へ。実機を再現する E2E 回帰テスト | `[verified]` |
| 3 | imudak「マルチエージェント AI 開発の現実」https://zenn.dev/imudak/articles/multi-agent-orchestration-comparison | 2026-02-15 | shogun の fork を約 2 週間 | send-keys の不安定、対話型ゆえ「待機」できない、ファイル競合、3 層のエラー伝播 | agent teams + OpenClaw。常駐 10 → 1 | `[verified]` |
| 4 | infohiroki「10 体 → 5 体へ、そして公式 Swarm へ」https://infohiroki.com/blog/2026-02-07-claude-code-multi-agent-orchestration | 2026-02-07（URL より） | 2 階層 5 体の「kinoko」。Markdown の指示・報告ファイル | pane の index は分割のたびに振り直される。Enter が権限プロンプトに吸われる | **不変の pane ID + カスタム属性の名前** で追跡。自作は継続 | `[verified]` |
| 5 | GENDA 奥山「tmux wait-for が AI 同士のオーケストレーションで便利だった」https://zenn.dev/genda_jp/articles/cfcaeeb51d23e7 | 2026-03-23 | Claude Code から別 pane の Codex へ委譲 | 子の返信が send-keys で届くと、親で入力途中の文が強制送信される | `tmux wait-for` + `run_in_background`、結果はファイル。未解決: 合図が来ないとき、親が死んだとき | `[verified]` |
| 6 | TOKIUM「実装は Claude、レビューは Codex ─ tmux で繋ぐ開発フロー」https://zenn.dev/tokium_dev/articles/0ef3f807d67e7c | 2026-01-30 | tmux-sender skill で相互レビュー | Codex → Claude は自動実行されない | 人の最終レビューを前提に運用 | `[verified]` |
| 7 | ZAICO「Claude Code の Hooks をハックして自律駆動するマルチエージェントを作った」https://zenn.dev/zaico/articles/d6b882c78fe4b3 | 未確認 | 4 つのフックの出力を文脈へ注入、`task_stack.json` などで状態継続 | 長いセッションで CLAUDE.md の規則が守られなくなる。compaction で初期の前提が落ちる。注入した指示に従うかは確率的。サーキットブレイカーが無い | 実験段階のまま。65 日で API 換算約 15,400 ドル（定額プランで実施） | `[verified]`（日付は未確認） |
| 8 | crandim「セッション引き継ぎは『現在地スナップショット』で回す」https://zenn.dev/crandim_r_and_d/articles/260822_a10_handoff_questions_workflow | 2026-08-22（URL より） | HANDOFF / QUESTIONS / 通し番号の運用の型 | 追記ログの肥大、チャットだけに出した問いの消失と番号の振り直し | 上書きスナップショット、問いのファイル化、再利用しない番号 | `[verified]` |
| 9 | koki_n22「tmux から Herdr に乗り換えてみた」https://zenn.dev/koki_n22/articles/642898def7a5de | 2026-08 頃（検索結果の表示より） | 2〜4 セッションの並列 | 各 pane の状態を見て回る手間、どこに何があるかの認知コスト | Herdr（状態の一覧と完了音）。使用 2〜3 日の暫定評価 | `[verified]`（日付は `[unverified-summary]`） |
| 10 | Oikon「Claude Code で最近使っている Tips【2026/11】」https://zenn.dev/oikon/articles/claude-code-recipe | 2026-11 | 自作はせず公式機能の組み合わせ | — | Orchestrator-Subagent、agent teams、Remote Control + セッション間メッセージ、Herdr。「見張らなくてもよいハーネスを組みやすくなった」 | `[verified]` |
| 11 | bokuwalily「Claude Code × Codex を並列スウォーム化する」https://zenn.dev/bokuwalily/articles/codex-worktree-swarm | 未確認 | tmux + worktree、各 worker の `handoff.md` を Claude がまとめてレビュー | 未確認 | 未確認 | `[unverified-summary]` |

- Oikon の記事が引く Anthropic の協調パターン 5 種（Generator-Verifier、Orchestrator-Subagent、Agent Teams、Message Bus、Shared State）は原典を開いた。まず Orchestrator-Subagent から始めよ、と勧める。Message Bus の失敗の形は「router が取りこぼすと、落ちるのではなく黙って失敗する」`[verified]` https://claude.com/blog/multi-agent-coordination-patterns （日付は取れず）

### 読み取れること

- 日本語圏の tmux 系の自作は shogun の系譜が中心で、困りごとは利用者の痛みとほぼ同じ並び（send-keys、pane の取り違え、待機、認知負荷、コスト）`[speculation]`
- 2026-02 の agent teams 公開を境に、(a) 公式へ移る、(b) 縮小して続ける、(c) 異種 CLI のために続ける、に分かれた。8 月以降の記事は Herdr と公式のセッション間メッセージが前提になっている `[speculation]`
- 統括の世代交代、lease、判断ボードに当たるものを日本語圏で公開している記事は、crandim の運用の型を除いて見つからなかった `[speculation]`

## 9. まとめ

### 9.1 利用者の 6 つの痛みと外の位置

位置の判定はすべて調査担当の解釈である `[speculation]`。根拠は各節の `[verified]` の項目。

| 痛み | 外の主流の解き方 | 少数派の解き方 | 利用者の今の解き方の位置 |
| --- | --- | --- | --- |
| 配送（届かない・届いたか分からない） | 本文はファイルか台帳へ置き、tmux は起床合図だけ。さらにフック・ソケット・wait-for へ移って tmux への入力をやめる。受け手が状態を自己申告する。落としても正本のポーリングで拾える構造にする | send-keys を続け、pane を読んで送信を検証・再送する（macf）。read と ack を別に記録する（MCP Agent Mail） | **遠回りしている**。6 回の作り直しは shogun の「48 回の修正」と同じ道で、外はその先で輸送を替えた。ただし「届いた」と「着手した」を分ける考え方は少数派の先頭と **並んでいる** |
| 統括の文脈が尽きる | 状態を統括の会話に持たせない（session ログ、台帳、進捗ファイル、スクリプト）。統括は使い捨てにして、いつ死んでも正本から立ち上がる。強いモデルでは compaction に任せる | 明示的な世代交代を高頻度に行う（Gas Town、ralph、Cursor の周期ごとの fresh start）。引き継ぎは目的に絞った抽出や 3 節の mail | 世代交代そのものは **並んでいる**。引き継ぎ文書が約 5 万トークンに育った点は **遠回りしている**（外は上書きのスナップショットか、目的に絞った抽出で小さく保つ） |
| 識別（pane 番号の取り違え・座の排他） | 環境変数で与える固定の名前・ID、tmux のセッション名や不変の pane ID、会話の UUID。座は名前で一意にし、セッションは使い捨て。あるいは統括を単一のデーモンにして排他の問題を作らない | 原子的な claim、TTL つきの advisory な lease（Beads、Agent Mail） | pane 番号をキーにした点は **遠回りしている**（既知の落とし穴）。統括の座の lease は公開実装がほぼ無く **先行している** が、外は「lease が要らない構造」で済ませている点に注意 |
| 人への問い（流れる・重なる） | 「どのセッションが待っているか」の一覧と通知（agent view、Projects、Herdr など）。権限は分類器へ委譲 | 問いを項目化し、選択肢と推奨を付けて 1 本のキューへ。束で答えて統括を 1 回だけ起こす（ai-orchestrator、decisions、crandim）。Gas Town の `decision` カテゴリは未実装 | **先行している**。同じ形の公開実装は 2026 年後半に個人作で出始めた段階。外が足しているのは「上げる量を減らす」と「束で返す」 |
| 見張りの見張り | 最下層を LLM でない機械（cron、systemd、デーモン）にする。見張られる側が heartbeat を書き、鮮度の閾値で沈黙を検出する。外側に短命の観察者を置く。監督は主経路から外して例外検出に徹する | 状態を持たず毎 tick 正本と照合する（Symphony）。公式の supervisor に任せる | 問題の認識は **並んでいる**。解は外に定石があり、利用者の現状（沈黙に気づけない）はその手前にある |
| 文書（コードの 3 倍） | 短い目次 + 正本の `docs/` + 機械的な鮮度検査。決定だけ ADR に分ける。計画と作業ログは残さない。繰り返す注意は検査へ移す。記憶の最上層は小さく | 仕様を正本にして厚く書く（spec-kit 型）。記憶をオフラインで整理し直す（dreaming） | 決定を記録する規律は **並んでいる**。量は **遠回りしている**（外の議論では警告の対象） |

### 9.2 「続ける」と「寄せる」を分ける判断の軸（外の実践者が挙げているもの）

- **その部品は、モデルの弱さについてのどの仮定を埋めているか。仮定は今も成り立つか**（Anthropic 2026-03-24、2026-04-08）。確かめ方は、外して比べること。目安として「外すのに 1 時間なら選択肢、1 週間なら負債」（Han-Chung Lee 2026-05-08）`[verified]`
- **輸送か、台帳か**。輸送・制御の層は公式が吸収しやすく、置き換えが前提。台帳・評価・規律は残る。「The transport changes. The ledger endures.」（Gas Town の設計書）、「長持ちするのはデータ、評価、環境」（Lee）`[verified]`
- **公式が同じ役割を持ったか。持たない領域か**。持ったなら両方を保つ理由は無い（imudak）。異種 CLI、障害復旧、世代交代は公式に無いので続ける理由になる（GENDA、Gas Town、前回メモ 7.2）`[verified]`
- **人の注意を減らしているか、増やしているか**。監督には容量があり、上げすぎは安全性も下げる（Turan）。エージェントを増やすと認知負荷と費用が先に尽きる（infohiroki、Appleton）。Yegge は「cognition を節約するソフトウェアが残る」と言う（この 1 点は `[unverified-summary]`）
- **汎用で再現できるか、強力だが属人的か。そして学びとしての価値**（imudak、infohiroki）。公式側が preview 段階であるリスクもこの軸に入る（前回メモ 7.3）`[verified]`

### 9.3 本文を読む価値がある上位 10 本

| # | 資料 | 日付 | 読む理由 |
| --- | --- | --- | --- |
| 1 | Anthropic「Harness design for long-running application development」https://www.anthropic.com/engineering/harness-design-long-running-apps | 2026-03-24 | 世代交代（リセット）を入れた理由と、モデル更新で外した経緯が 1 本で読める。棚卸しの手本 |
| 2 | Anthropic「Scaling Managed Agents: Decoupling the brain from the hands」https://www.anthropic.com/engineering/managed-agents | 2026-04-08 | 「統括は使い捨て、状態は文脈の外のログ」という設計。世代交代と引き継ぎ文書の膨張への別解 |
| 3 | Gas Town 設計書「polecat-self-managed-completion」https://github.com/gastownhall/gastown/blob/main/docs/design/polecat-self-managed-completion.md | 日付未確認（現行の main） | 監督を主経路に置いて詰まった実例と、合図を落としても困らない構造への直し方。配送と見張りの両方に効く |
| 4 | Gas Town 設計書「witness-at-team-lead」https://github.com/gastownhall/gastown/blob/main/docs/design/witness-at-team-lead.md | 日付未確認（現行の main） | 最も近い先行者が「tmux の輸送を公式へ寄せ、台帳を残す」計画を、利点・危険・戻し方つきで書いている。年内の判断にそのまま使える |
| 5 | Gas Town 設計書「dog-infrastructure」と「mail-protocol」https://github.com/gastownhall/gastown/blob/main/docs/design/dog-infrastructure.md | 日付未確認（現行の main） | 見張りの見張りの定石（機械のデーモン、heartbeat の鮮度、外側の観察者）と、mail と nudge の使い分け |
| 6 | shio_shoppaize「tmux send-keys を殺して Hook に統一したら家老が永眠した…」https://zenn.dev/shio_shoppaize/articles/shogun-hook-revolution | 2026-02-28 | 同じ send-keys の泥沼（48 回の修正）から抜けた記録と、抜けた直後のデッドロック。日本語で読める |
| 7 | macf issue #1442 https://github.com/groundnuty/macf/issues/1442 | 2026-10-16 | 「終了コード 0 = 届いた」と記録していた失敗と、送信を検証する手順の試験表。send-keys を残すなら必読 |
| 8 | ai-orchestrator issue #2408 https://github.com/nickderobertis/ai-orchestrator/issues/2408 | 2026-11-08 | 判断ボードとほぼ同じ発想の設計書。選択肢、束での回答、複数の統括に共通の 1 本のキュー。差分を見るのに最適 |
| 9 | Cognition「Multi-Agents: What's Actually Working」https://cognition.com/blog/multi-agents-working | 2026-04-22 | 「書き込みは単線、知恵だけ複数」の整理。白紙の文脈のレビュー、manager と子の連絡の未解決点、異種モデルの使いどころ |
| 10 | Anthropic「The components of agent memory」https://www.anthropic.com/engineering/components-of-agent-memory | 2026-11-06 | 書きすぎた記憶が成績を下げる実験。蒸留文書と引き継ぎ文書の量を決める根拠になる |

- 次点: Cursor「Scaling long-running autonomous coding」（2026-01-14、ロックの失敗と役割の階層）、Han-Chung Lee「Hidden Technical Debt of AI Systems: Agent Harness」（2026-05-08、外しやすさの測り方）、INNOQ「The Right Kind of Hard」（2026-04-08、文書の量への処方）、crandim の HANDOFF / QUESTIONS の記事（2026-08-22）、arXiv 2610.01471（2026-10-01、別モデルのレビューの効果）

## 10. 未確認事項（追加調査の候補）

- OpenAI「Harness engineering」と Symphony の発表記事の本文（`openai.com` が 403）
- Yegge の「Gas Town: from Clown Show to v1.0」と Emergency User Manual の本文（`medium.com` が 403）。Gas City の実体
- Gas Town で Mayor が二重に起動した場合の扱い（ソースか issue を読む必要がある）
- Beads が連番 ID からハッシュ ID へ移った経緯の一次記述
- Amp が自動 compaction を戻したかどうか、戻したならその理由
- HumanLayer / CodeLayer と LangChain の agent inbox の現行の設計（選択肢・推奨の扱い）
- Codex の compaction についての OpenAI の一次情報と、compaction が制約を落とすという研究の原論文
- arXiv の 3 本（2610.01471、2606.08919、2609.24234）は要旨のみ読んだ。本文の方法と限界は未確認
- 8 節の記事 1、7、9、11 の正確な公開日

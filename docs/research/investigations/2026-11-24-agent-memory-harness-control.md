# Claude Code と Codex の記憶の仕組みと、ハーネスに入れられる調整と制御 — 調査メモ

- 作成: 2026-11-24（調べたのは 2026-11-24〜25）
- 状態: 調査中（追記前提）
- 関連 issue: [#650](https://github.com/stlwolf/ai-development-hub/issues/650)（[確定版の認識合わせ](https://github.com/stlwolf/ai-development-hub/issues/650#issuecomment-7134862521)）
- 対象: Claude Code（2.1.331）と Codex CLI（0.170.0）の、会話をまたいで残る記憶（エージェントが自分で書く記録）。ハーネスの層だけを扱う。engine で記憶をどう扱うかは別の issue にする。
- 書いた順: Claude Code の側（この文書の書き手）が両方を先に書き、そのあと Codex が確かめて埋める。Codex が直した行と足した行は「Codex による確かめの記録」の節にある。
- 根拠の札:
  - `[verified]` 公式の文書かリポジトリの実体を開いて確かめた。公式の文書は 2026-11-25 に取得した。
  - `[verified-local]` 手元で実際に実行して確かめた（版と日付を添える）。
  - `[record]` 過去の記録にそう書いてある。いまも同じかは確かめていない（日付と版を添える）。
  - `[unverified-summary]` 二次の情報か、確かめていない要約。
  - `[speculation]` 根拠が無い推測。見た資料と、分からなかった理由を添える。
- 記憶の中身は写していない。書いたのは、置き場・ファイルの名前の形・件数・大きさ・更新時刻・設定の鍵の名前だけである。

出典の略称:

| 略称 | URL |
|---|---|
| CC-memory | https://code.claude.com/docs/en/memory |
| CC-settings | https://code.claude.com/docs/en/settings-reference |
| CC-env | https://code.claude.com/docs/en/env-vars |
| CX-memories | https://learn.chatgpt.com/docs/customization/memories?surface=app （https://developers.openai.com/codex/memories から移った先） |
| CX-config | https://learn.chatgpt.com/docs/config-file/config-reference |
| CX-exec-help | `codex exec --help`（codex-cli 0.170.0） |
| CX-source | [公式公開ソース（固定コミット `44308610ef5c`）](https://github.com/openai/codex/tree/44308610ef5cbc03d149707735878b0c8743b2df)。以下の `read` は `codex-rs/ext/memories/src/`、`write` は `codex-rs/memories/write/src/` を指す。 |
| CX-local | 2026-11-25・CLI 0.170.0 の `--version`・`exec --help`、設定の記憶に関する鍵、ファイルのメタデータ、SQLite のスキーマと集計値を読み取りで確認した。 |

CX-source の参照先（いずれも同じ固定コミット）:

- [読み込みと上限](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/ext/memories/src/prompts.rs)。
- [上限の定数](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/ext/memories/src/lib.rs)。
- [注入と有効化の条件](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/ext/memories/src/extension.rs)。
- [裏の処理の起動条件](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/src/start.rs)。
- [抽出候補の選び方](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/src/phase1.rs)。
- [許可する source](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/rollout/src/lib.rs)。
- [整理と内部エージェントの設定](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/src/phase2.rs)。
- [利用回数と整理対象の選択](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/state/src/runtime/memories.rs)。
- [引用から利用回数を記録する経路](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/core/src/stream_events_utils.rs)。
- [git の基準の更新](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/git-utils/src/baseline.rs)。
- [extensions の初期配置](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/src/extensions/ad_hoc.rs)。
- [extensions の整理への案内](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/src/prompts.rs)。
- [extensions の入力の扱い](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/templates/extensions/ad_hoc/instructions.md)。
- [抽出する内容と出どころの扱い](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/templates/memories/stage_one_system.md)。
- [整理のプロンプト](https://github.com/openai/codex/blob/44308610ef5cbc03d149707735878b0c8743b2df/codex-rs/memories/write/templates/memories/consolidation.md)。

## 1. 目的と範囲

- 目的は、ハーネスとして記憶に何を入れられて何を入れられないかを、出典つきで1つの文書から分かるようにすることである。何を入れるかは決めない。
- 「調整」は、何を書くかを文で導くものを指す。効くかどうかはモデル次第である（例: 決まりの文・`CLAUDE.md`・`AGENTS.md`）。
- 「制御」は、設定・hook・権限で機械的に止めたり絞ったりするものを指す（例: 記憶を書かせない設定の鍵、記憶のフォルダへの書き込みを止める hook）。
- 範囲の外: engine の子の記憶をどう扱うか（engine の層）、いまある記憶の棚卸しと整理、何を入れるかの決定。

検証の範囲（Codex による追記）:

- 2026-11-25 に Codex の記述を公式資料・公開ソース・手元の読み取りで確かめ直した。公開ソースの固定コミットと手元の CLI 0.170.0 のビルドが一致することは確かめていない。ソースで確認した動作を、この CLI での実測とは扱わない。
- Claude Code の側の札は、Claude が 2026-11-25 に付けたものである。公式の文書は `curl` で原文を取って `grep` で当て、試しと件数は手元で実行して確かめた。Codex は確かめの段でこれらを再実行・再検証せず、札をいったん `[record]` と `[unverified-summary]` に弱めた。Claude の確かめは原文と実行に当てたものなので、Codex の確かめのあとに Claude が元の札に戻した（Claude による追記・2026-11-25）。
- 以下の「実装」は CX-source の固定コミットだけを指す。調整と制御の候補は採用の決定ではない。

## 2. 比べた表

| 項目 | Claude Code | Codex |
|---|---|---|
| 書き手と時機 | モデル自身が会話の途中で書く。何を残すかはモデルが決め、頼まれたときも書く `[verified]`（CC-memory）。自動の記憶も、モデルが通常のファイルの道具（`Write`）で書く。入れ子の非対話の `claude -p` に頼んだときも、そう書いた `[verified-local]`（2.1.331・2026-11-25・節 3.1） | 裏の処理が対象の過去の会話から抽出して整理する `[verified]`（CX-memories）。実装では非 ephemeral の root 会話の開始時に非同期で起動する。既定6時間の無活動は材料になる条件であり、6時間ごとの実行周期ではない `[verified]`（CX-source・`write/start.rs`・`write/phase1.rs`）。 |
| 範囲 | リポジトリごと。worktree とサブディレクトリは同じフォルダを共有する `[verified]`（CC-memory）。hub の worktree のフォルダに記憶は無かった `[verified-local]`（2026-11-25） | Codex のホーム（既定 `~/.codex`）で共有する。実装はホームから記憶の版のフォルダを選び、リポジトリごとの読み込みフィルターは置かない `[verified]`（CX-memories・CX-source の `read/prompts.rs`）。手元には v1・v2 の両方がある `[verified-local]`（CX-local）。 |
| 読み込まれ方 | 会話の始まりに `MEMORY.md` の先頭 200 行か 25KB のどちらか少ないほう。個別のファイルは必要なときに読む `[verified]`（CC-memory）。hub の索引（79 行・25,397 バイト）は最後の行まで読み込まれていた `[verified-local]`（2026-11-25） | `features.memories` と `use_memories` が有効なら、実装は `memory_summary.md` を最大2,500トークン相当へ切って読むための指示とともに developer の文脈へ入れる。`MEMORY.md` はその初期注入に含めず、必要なときに検索する `[verified]`（CX-source・`read/prompts.rs`・`read/lib.rs`・`read/extension.rs`）。Codex の確かめの会話にも summary と読む指示が届いた `[verified-local]`（2026-11-25）。 |
| 人が手を入れる口 | 中身はファイルで、読む・直す・消すができる。`autoMemoryEnabled` で読み書きを止め、環境変数で会話1回ぶんだけ止められる `[verified]`（CC-settings・CC-env）。止めた回では記憶のフォルダができなかった `[verified-local]`（節 3.1） | 鍵は `features.memories`・`memories.generate_memories`・`memories.use_memories` ほか `[verified]`（CX-config）。会話ごとの切り替えは対話の `/memories`。手で直すことは主な制御の手段にしないよう書かれている `[verified]`（CX-memories）。参照した公式ページには CLI の削除コマンドの記載は無く、手元の `codex --help` と `codex debug --help` にも記憶の削除は表示されなかった `[verified-local]`（CLI 0.170.0・2026-11-25）。全経路に存在しないという断定はしない |
| ほかのエージェントに起こされた会話 | サブエージェントには親の記憶を読み込まない（fork は除く） `[verified]`（CC-memory）。Bash から起こした入れ子の `claude -p` でも書いた `[verified-local]`（節 3.1）。tmux で起こした会話は入れ子として扱わない `[verified]`（CC-env の `CLAUDE_CODE_FORCE_SESSION_PERSISTENCE`） | 実装の材料候補は `cli`・`vscode`・`atlas`・`chatgpt`。通常の `exec` とサブエージェントの source は含めない。ただし `exec` も別の会話を材料にする裏の処理を起動しうる `[verified]`（CX-source・`write/start.rs`・`write/phase1.rs`・`codex-rs/rollout/src/lib.rs`）。アプリの全会話が対象という意味ではない。 |
| 外へ出る道 | 記憶は会話の文脈として読み込まれ、強制される設定ではない `[verified]`（CC-memory）。読み込まれた記憶を、モデルが文書や commit に写す道は塞がれていない `[speculation]`（見た資料: CC-memory。分からなかった理由: 写すことを防ぐ仕組みの記述が無い） | 実装はホーム共通の summary を注入するため、別の作業から得た記憶も文脈に入りうる `[verified]`（CX-source・`read/prompts.rs`）。Codex の確かめの会話にも summary が渡された `[verified-local]`（内容は転記しない）。生成する記憶の秘密の値は伏せると公式は書くが、識別子をすべて伏せる保証ではない `[verified]`（CX-memories）。 |

## 3. 項目ごとの詳しい内容

### 3.1 Claude Code

**書き手と時機**

- 公式の文書の表では、自動の記憶を書くのは Claude である `[verified]`（CC-memory の表「Who writes it」）。何を残すかは、あとの会話で役立つかでモデルが決め、毎回書くわけではない `[verified]`（CC-memory「Auto memory」節）。コードから分かることと、`CLAUDE.md` に書いてあることは残さない、と書かれている `[verified]`（同）。
- 何を書くかの細かい指示は、harness の system prompt の記憶の節にある。Claude が調べた会話（デスクトップ版・2.1.331）に渡された指示では、記憶を user・feedback・project・reference の4つの型に分け、リポジトリに記録されていることと、その会話の中だけで要ることは残さない `[verified-local]`（2026-11-25・Claude が調べた会話の system prompt）。hub はこの文を書き換えられず、足すことだけができる。
- 試しA（2026-11-25・2.1.331）: リポジトリの外の一時ディレクトリで、Bash から `claude -p` に「合言葉を覚えて」と頼んだ。`~/.claude/projects/<一時ディレクトリから作った名前>/memory/` に、個別のファイルと `MEMORY.md` の2つができた。会話の記録では、どちらも `Write` の道具で書いていた `[verified-local]`。

**範囲**

- `<project>` は git のリポジトリから決まり、worktree とサブディレクトリは1つの記憶のフォルダを共有する。git の外ではプロジェクトの根を使う `[verified]`（CC-memory「Storage location」）。
- `autoMemoryDirectory` で置き場を変えられ、どの設定の層（user・project・local・policy・`--settings`）からでも読む `[verified]`（CC-memory・CC-settings）。`CLAUDE_CODE_PROJECT_DIR_NAME` を `CLAUDE_CONFIG_DIR` と一緒に置くと、どのリポジトリで起こしても1つのフォルダを共有する `[verified]`（CC-memory。v2.1.234 以降）。
- 記憶はその機械の中だけにある `[verified]`（CC-memory）。
- 手元: `~/.claude/projects/` の下に 163 のフォルダがあり、`memory/` を持つのは 64 だった。hub の記憶は 79 件・索引 25,397 バイト・79 行で、hub の worktree の3つのフォルダには `memory/` が無かった `[verified-local]`（2026-11-25）。
- engine の Claude の子は、委譲の書面の決まりで、自分で worktree を作って動く `[verified]`（`canonical/skills/doc-flow-guardrail/SKILL.md` の委譲の固定節「worktree は子が自作」）。worktree は本体のリポジトリの記憶のフォルダを共有する（上の1つ目）。この2つから、子の書いた記憶は hub の記憶のフォルダに入ると見ている `[speculation]`（分からなかった理由: 子が実際に書いたかを、会話の記録で数えていない）。

**読み込まれ方**

- 会話の始まりに `MEMORY.md` の先頭 200 行か 25KB のどちらか少ないほうを読み込む。個別のファイルは始まりでは読まず、必要なときに読む `[verified]`（CC-memory「How it works」）。
- 上限を超えても書き込みは通るが、Claude Code が Claude に索引を書き直すよう返し、上限を超えた部分は次の読み込みで落ちる。上限に近いと短くするよう促す `[verified]`（同）。
- `CLAUDE.md` は 4 MiB までなら全部を読み込み、記憶の索引の上限はかからない `[verified]`（同の注記）。
- hub の索引は 25,397 バイトで、Claude が調べた会話の文脈には最後の行まで入っていた `[verified-local]`（2026-11-25）。25,000 バイトで切ると最後の数行が落ちるので、この版の 25KB は 25,397 バイトより大きい。25,600 バイト（25 KiB）か、ほかの数え方かは確かめていない。

**人が手を入れる口**

| 口 | できるか | 根拠 |
|---|---|---|
| 読む・直す・消す | できる。中身は Markdown のファイルで、`/memory` からフォルダを開ける | `[verified]`（CC-memory） |
| 書かせない（全体） | `autoMemoryEnabled: false`。読み書きの両方を止める。既定は `true`。どの設定ファイルにも置ける | `[verified]`（CC-settings の `autoMemoryEnabled`） |
| 書かせない（リポジトリ1つ） | そのリポジトリの設定に `autoMemoryEnabled: false` を置く | `[verified]`（CC-memory） |
| 書かせない（会話1回） | `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`。`0` なら、設定や `--bare` で止まる場面でも有効にする | `[verified]`（CC-env・CC-settings の「Per-session overrides」） |
| ほかに止まる場面 | `--bare`・安全モード | `[verified]`（CC-settings の `autoMemoryEnabled` の型の説明） |
| `/memory` の切り替え | 利用者の設定（`~/.claude/settings.json`）に `autoMemoryEnabled` を書く。裏の会話と、ほかの Claude Code の会話が起こした会話では、切り替えで有効に戻せない | `[verified]`（CC-memory） |
| hook | 試しAの記憶は `Write` の道具で書かれた `[verified-local]`。`PreToolUse` の hook は道具の名前で当たるので、記憶の書き込みにも当たる見込みである。実際に止まるかは試していない | `[speculation]`（見た資料: 試しAの会話の記録。分からなかった理由: hook で止める試しをしていない） |
| 権限 | 作業ディレクトリの外への書き込みを止める設定でも、自動の記憶の `.md` は書ける | `[verified]`（CC-settings の `permissions.blockWritesOutsideWorkingDirectories`） |

- 公式の文書は、`CLAUDE.md` と自動の記憶は文脈で、強制される設定ではないと書き、Claude の判断に依らずに止めたいなら `PreToolUse` の hook を使うよう書いている `[verified]`（CC-memory「CLAUDE.md vs auto memory」節）。
- 試しB（2026-11-25・2.1.331）: 試しAと別の一時ディレクトリで、`--settings '{"autoMemoryEnabled": false}'` を付けて同じことを頼んだ。記憶のフォルダはできず、Claude は「会話をまたいで記憶を持ち越す仕組みが無い」と答えて、`CLAUDE.md` に書く案を挙げた `[verified-local]`。試しAで書かれ、試しBで書かれなかったので、この条件では設定を切ると書かれなかった。書かれなかったことは、機械的に禁じられていることの証明ではない。

**ほかのエージェントに起こされた会話**

- サブエージェントには、親の会話の記憶を読み込まない。fork は親の会話と system prompt を受け継ぐので例外である。サブエージェントは `memory` の項目で自分の記憶を別のフォルダに持てる `[verified]`（CC-memory）。
- Claude Code が Bash などから起こした子のプロセスには `CLAUDE_CODE_CHILD_SESSION=1` が入る。入れ子の `claude -p` の会話は保存される `[verified]`（CC-env）。試しAはこの条件（入れ子・`-p`）で記憶を書いた `[verified-local]`。
- tmux の中で起こした会話は、受け継いだ入れ子の印を無視する（v2.1.178 以降） `[verified]`（CC-env の `CLAUDE_CODE_FORCE_SESSION_PERSISTENCE`）。engine の子は tmux のペインで起こすので、入れ子ではない普通の会話として扱われる見込みである `[speculation]`（見た資料: CC-env。分からなかった理由: engine の子で確かめていない）。

**外へ出る道**

- 既定の配置では、自動の記憶はリポジトリごとに分かれる。ただし `autoMemoryDirectory` や `CLAUDE_CODE_PROJECT_DIR_NAME` による共有先の指定は別である `[verified]`（CC-memory「Storage location」）。
- ただし、hub の会話の中で書いた記憶は hub の索引に入る。hub の索引には、ほかのリポジトリを名指しする行がある `[verified-local]`（2026-11-25・名前は写さない）。索引は毎回の会話の文脈に入るので、モデルがその名前を公開の文書や commit に写す道は、文で禁じているだけである（`CLAUDE.md` の「公開リポジトリとしての決まり」） `[speculation]`（見た資料: CC-memory・hub の `CLAUDE.md`。分からなかった理由: 写したことがあるかは数えていない）。

### 3.2 Codex

**書き手と時機**

- 記憶を有効にすると、Codex は対象になる過去の会話から役に立つ文脈を取り出し、手元のファイルにする。公式資料は動いている会話と短い会話を飛ばし、裏で更新すると書く `[verified]`（CX-memories）。実装は非 ephemeral の root 会話の開始をきっかけに抽出と整理を起動し、6時間を無活動の既定条件として使う `[verified]`（CX-source・`write/start.rs`・`write/phase1.rs`）。短さの境界値をこの調査では確定していない。
- 会話がどれだけ動かなければ材料になるかは `memories.min_rollout_idle_hours`（既定 6・1〜48）、どれだけ古い会話まで見るかは `memories.max_rollout_age_days`（既定 30） `[verified]`（CX-config）。
- 取り出し（会話ごと）と整理（全体）に別のモデルを指定できる（`memories.extract_model`・`memories.consolidation_model`） `[verified]`（CX-config）。
- 2026-11-15 に、engine の Codex の子のペインで、整理の会話が子の画面と同じプロセスの中で走り、会話の記録を残さなかった。その会話は子の起動の1行の `-c developer_instructions` と子の環境を受け継いでいた `[record]`（PR #648 の本文・#562 の decision・Codex CLI 0.167.2）。

**範囲**

- 記憶は Codex のホーム（既定 `~/.codex`）の下に置く。新しいホームでは `memories_v2/` を使い、`memories/` が既にあれば `memories/` を使い続ける `[verified]`（CX-memories・CX-config の `memories.version`）。移行のあいだは、新しい会話が `memories/` を読んで両方に書くことがある `[verified]`（CX-memories）。
- 実装の読み込み先は `CODEX_HOME` と記憶の版で決まり、作業リポジトリで絞らない `[verified]`（CX-source・`read/prompts.rs`）。ホームを分ければ読み込み先は分かれるが、認証・設定を含めた実運用の分離は試していない `[speculation]`（見た資料: CX-memories と読み込み実装。分からなかった理由: 別ホームで起動する試しをしていない）。
- 手元（2026-11-25・CLI 0.170.0）: `memories/` は `MEMORY.md` 36,547 バイト・370行、`memory_summary.md` 6,789 バイト・97行、`raw_memories.md` 53,635 バイト、会話ごとの要約10件だった。`memories_v2/` は summary 6,011 バイト・65行と要約7件だった。中身と個別の要約名は転記していない `[verified-local]`（CX-local）。
- どちらのフォルダも git の commit は1件だった `[verified-local]`（CX-local）。実装では git は前の整理の成功時点との差分を作る基準である。整理が成功すると `.git` を置き換え、親の無い1 commit の基準を作る。通常の変更履歴を蓄積する用途ではない `[verified]`（CX-source・`write/workspace.rs`・`codex-rs/git-utils/src/baseline.rs`）。commit の件名と作者は転記しない。

**読み込まれ方**

- `memories.use_memories` が偽なら、既存の記憶をあとの会話に入れない（既定は真） `[verified]`（CX-config）。
- 実装は `memory_summary.md` を trim して最大2,500トークン相当へ切り、記憶を読むための指示に埋めて developer の文脈へ加える。これは summary 部分の上限で、読むための指示の量を含まない。`MEMORY.md`・個別の要約・記憶の skill の本文を初期注入で全件読み込む処理ではない `[verified]`（CX-source・`read/prompts.rs`・`read/lib.rs`・`read/extension.rs`）。実装上の `TruncationPolicy::Tokens` の値であり、モデルの tokenizer で正確に2,500トークンになることは確認していない。
- v2 の文脈は1片8,900バイト以内に分けて渡す。これは全 summary の上限ではなく、各片の上限である `[verified]`（CX-source・`read/extension.rs`・`codex-rs/core/src/context/memory.rs`）。Codex の確かめの会話には v1 の summary と読むための指示が渡されており、`MEMORY.md` 全文は初期注入には見えなかった `[verified-local]`（2026-11-25・Codex の確かめの会話に渡された指示）。
- 整理へ渡す生の記憶の上限は既定256件（最大4,096件）、未使用の期間の上限は既定30日である `[verified]`（CX-config）。実装は `last_usage`、未使用なら `source_updated_at` で期間を判定し、`usage_count` の多いものから選ぶ。「最近の256件」だけで選ぶ説明は正確ではない `[verified]`（CX-source・`codex-rs/state/src/runtime/memories.rs` の `get_phase2_input_selection`）。

**人が手を入れる口**

| 口 | できるか | 根拠 |
|---|---|---|
| 読む | できる。困ったときやホームを人に渡す前に見てよい | `[verified]`（CX-memories） |
| 直す | ファイルは「作られた状態」として扱い、手で直すことを主な制御の手段にしないよう書かれている | `[verified]`（CX-memories） |
| 消す | デスクトップの「Delete Codex memories」で選んだ機械の記憶をリセットする。Computer History が使える場合はそれも消す | `[verified]`（CX-memories）。CLI 0.170.0 の通常と debug の help に記憶の削除は表示されなかった `[verified-local]`（2026-11-25）。削除は実行していない |
| 機能ごと切る | `features.memories`（既定は切） | `[verified]`（CX-config・CX-memories） |
| 書かせない（全体） | `memories.generate_memories = false` で、新しい会話を材料にしない | `[verified]`（CX-config） |
| 読ませない（全体） | `memories.use_memories = false` | `[verified]`（CX-config） |
| 外の文脈を使った会話だけ外す | `memories.disable_on_external_context = true` で、MCP の道具・Web 検索などを使った会話を材料から外す | `[verified]`（CX-config） |
| 書かせない（会話1回・対話） | 対話の画面の `/memories` で、その会話が記憶を使うか・材料になるかを決める。全体の設定は変わらない | `[verified]`（CX-memories） |
| 書かせない（会話1回・`exec`） | `-c memories.generate_memories=false` はその起動の設定を上書きし、新しい会話を材料として保存しない。既存の別の会話の整理まで止める設定ではない | 設定の意味と上書きは `[verified]`（CX-config・CX-exec-help）。この条件での生成の比較試験はしていない |
| 会話の記録を残さない | `codex exec --ephemeral` は会話ファイルを保存しない。実装では、その起動をきっかけにする記憶の裏の処理も起動しない | `[verified]`（CX-exec-help・CX-source の `write/start.rs`）。既存の記憶の読み込みを止める設定とは別である |

- 手元の設定（2026-11-25・CLI 0.170.0）は、`features.memories = true`・`memories.generate_memories = true`・`memories.use_memories = true` だった `[verified-local]`（CX-local）。既定は機能が無効である `[verified]`（CX-config）。誰が有効にしたかは、この設定だけでは分からない。
- sync の実装は通知の管理区間を丸ごと書き直さず、既存の通知の鍵があると追加を飛ばす。ただし旧 hook 鍵の移行では既存行も書き換えるため、「無い鍵を足すだけ」は厳密には誤りである `[verified]`（`scripts/sync/apply-codex-notify-config.sh`）。手元の `~/.codex/config.toml` では、hub の sync が印を付けた区間（tui-notify）の中に、`[memories]` などの表が入っていた `[verified-local]`（Claude・2026-11-24）。誰がそこへ書いたか（Codex 自身か、手で書いたか）は確かめていない `[speculation]`（分からなかった理由: 書いた時点の記録が無い）。区間の中にあっても sync が書き直さないので、いまは壊れていない。

**ほかのエージェントに起こされた会話**

- 実装の抽出候補は state DB の `source` を `cli`・`vscode`・`atlas`・`chatgpt` に絞り、`memory_mode = enabled` と期間などの条件を満たすものから選ぶ。通常の `codex exec` は `Exec` の source なので候補に含めず、サブエージェントもこの許可一覧に含めない `[verified]`（CX-source・`write/phase1.rs`・`codex-rs/rollout/src/lib.rs`・`codex-rs/state/src/runtime/memories.rs`・`codex-rs/exec/src/lib.rs`）。アプリという画面名だけでは、実際の source と保存先を判定できない。
- 材料になることと、裏の処理を起動することは別である。`exec` は非 ephemeral の root なら、対象になる別の過去の会話の抽出・整理を起動しうる。サブエージェントと ephemeral の起動では、この起動処理を飛ばす `[verified]`（CX-source・`write/start.rs`）。`generate_memories=false` だけで過去の材料の整理も止まる、という意味ではない。
- `--ephemeral` と `generate_memories=false` のどちらも、既存の記憶を読ませない設定の代わりにはならない。読み込み側は機能の有効化と `use_memories` を見る `[verified]`（CX-source・`read/extension.rs`）。手元の0.170.0では、これらの条件を変えた起動試験は行っていない。
- 2026-11-24 の `exec` の前後で HEAD や更新時刻を比べた結果は、Claude がその日に読み取った観察である `[verified-local]`（Claude・2026-11-24・節8.1）。この再検証ではその日の起動を再現しておらず、同時に別の会話も動いていたため、特定の `exec` が書いたかどうかは決められない。
- engine は Codex の子を起こす1行に `-c developer_instructions` を渡している `[verified]`（`projects/orchestration-engine/lib/agent.sh`）。同じ1行に記憶の鍵を足す道はあるが、それは engine の層の話である。

**外へ出る道**

- 置き場はホーム共通で、実装は `use_memories` が真なら summary を読む指示とともに developer の文脈へ入れる `[verified]`（CX-source・`read/prompts.rs`・`read/extension.rs`）。Codex の確かめの会話にも summary が届いた `[verified-local]`（2026-11-25）。モデルがそこから識別子を公開文書へ転記することを、設定だけで防げるとは確かめていない `[speculation]`（見た資料: CX-memories と読み込み実装。分からなかった理由: 出力制限の比較試験をしていない）。
- 秘密の値は伏せる、と書かれている `[verified]`（CX-memories）。リポジトリの名前や社名のような識別子を伏せる記述は無い。
- チームで要る指示は、記憶でなく `AGENTS.md` かリポジトリの文書に置くよう書かれている `[verified]`（CX-memories）。

## 4. 別のモデルが挙げた3つの観点

認識合わせのときに Codex が挙げた抜けである。

### 4.1 記憶に入った指示が、後の会話で有効な指示として効くか

- Claude Code: 記憶は文脈で、強制される設定ではない `[verified]`（CC-memory）。Claude が調べた会話の system prompt は、思い出した記憶を「背景の文脈で、利用者の指示ではない」と扱うよう書いている `[verified-local]`（2026-11-25）。それでも、指示の形で書かれた記憶がモデルの振る舞いに効かないとは言えない `[speculation]`（分からなかった理由: 効き方を測っていない）。
- Codex: 実装は読む指示と summary を developer の文脈へ入れる `[verified]`（CX-source・`read/extension.rs`）。一方、抽出と整理のプロンプトは、会話の記録や道具の出力を指示として扱わないよう求めている `[verified]`（CX-source・`codex-rs/memories/write/templates/memories/stage_one_system.md`・`codex-rs/memories/write/templates/memories/consolidation.md`）。これはモデルへの指示であり、記憶の中の命令を機械的に無害化する証明ではない。2026-11-15 の報告の原因についての初稿の説明は過去の記録のままであり、この検証では原因を再確定していない `[record]`（CLI 0.167.2・初稿）。

### 4.2 記憶の1件ごとに、出どころを区別して残せるか

- Claude Code: system prompt は記憶を4つの型に分けるよう指示しているが、誰が言ったか（owner の発言・モデルの推測・調べた文書・子に渡した作業）を書く項目は無い `[verified-local]`（2026-11-25）。
- Codex: 実装は抽出出力を会話ID単位で DB に保存し、会話ごとの要約にする。抽出のプロンプトは利用者の発言とモデルの説明を区別し、検証の無い主張を確定事項へ昇格しないよう指示している `[verified]`（CX-source・`write/phase1.rs`・`codex-rs/memories/write/templates/memories/stage_one_system.md`）。出どころを残す指示はあるが、すべての知識の1件ごとに強制する型検証ではない。手元の記憶本文の分類監査はしていない。

### 4.3 消したあとに作り直されるか・写しが残るか

- Claude Code: 記憶はファイルで、消せば読み込まれない。裏で作り直す処理の記述は無い `[verified]`（CC-memory に裏の処理の記述が無い）。会話の記録（`~/.claude/projects/<project>/` の `.jsonl`）は残るので、同じ内容をモデルがまた書くことはありうる `[speculation]`。
- Codex: 公式の削除は機械の記憶の置き場のリセットで、Computer History が使える機械ではそれも消す `[verified]`（CX-memories）。`MEMORY.md` だけの手動削除は DB の抽出結果の削除と同じではない。実装の整理は DB から生の記憶と要約を作り、モデルに上位のファイルを更新させる `[verified]`（CX-source・`write/phase2.rs`・整理プロンプト）。そのため作り直されうるが、手動削除の再現試験はしていない `[speculation]`。git の基準は成功後に作り直すが、それだけで DB や元の会話の記録まで消えるわけではない `[verified]`（CX-source・`write/workspace.rs`・`codex-rs/git-utils/src/baseline.rs`）。手元には2つの版がある `[verified-local]`（CX-local）。

## 5. ハーネスに入れられる候補

hub から配る場所は4つある。決まりの文（`canonical/rules/`・`CLAUDE.md`・`canonical/codex/AGENTS.md`）、Claude の設定の harness 層（`canonical/claude/settings.harness.json` を sync で当てる・#359）、hook（`canonical/hooks/`）、Codex の設定に鍵を足す sync（`scripts/sync/apply-codex-notify-config.sh` の形）である。

効く経路は、記憶が書かれる道のどれに効くかを書く。「モデル」はモデルが会話の中でファイルの道具を使って書く道、「整理」は裏で動く整理の処理が書く道、「直接」は人や別のプロセスがファイルを直接書く道である。

| 候補 | 種類 | エージェント | 配る場所 | 効く経路 | 止められる範囲 | 入れられるか | 根拠 | 確かめていない部分 |
|---|---|---|---|---|---|---|---|---|
| `autoMemoryEnabled: false` を利用者の設定に置く | 制御 | Claude Code | 設定の harness 層 | モデル（読み込みも止まる） | その機械の全部のリポジトリ | 入れられる。鍵は hub の既知の鍵の一覧にある | `[verified]`（CC-settings・`canonical/claude/settings-known-keys.txt:40`）・試しB `[verified-local]` | `/memory` の切り替えが同じ鍵を利用者の設定に書くので、sync の値とずれる。ずれの検査（#359）で拾えるかは見ていない。試しは入れ子の `claude -p` で `--settings` から渡した形だけで、利用者の設定に置いた形と対話の会話では試していない |
| リポジトリの設定に `autoMemoryEnabled: false` を置く | 制御 | Claude Code | そのリポジトリの `.claude/settings.json` | モデル | そのリポジトリだけ | 入れられる | `[verified]`（CC-memory） | hub に置くと hub の記憶が全部止まり、いまの使い方（統括の規律を記憶に置く）と食い違う |
| `autoMemoryDirectory` で置き場を分ける | 制御 | Claude Code | 設定の harness 層か `--settings` | モデル | 置き場を変えるだけで、書くこと自体は止めない | 入れられる | `[verified]`（CC-memory・CC-settings） | リポジトリの設定から指すときの信頼の扱い（hook と同じ決まり）を確かめていない |
| 記憶のフォルダへの `Write`・`Edit` を `PreToolUse` の hook で見て止める | 制御 | Claude Code | hook | モデル（ファイルの道具で書くときだけ） | hook の条件しだい（たとえば、ほかのリポジトリの名前を含む書き込み） | 入れられる見込み | 記憶が `Write` で書かれた `[verified-local]`。止める方法として公式が hook を挙げる `[verified]`（CC-memory） | 実際に hook が記憶の書き込みで発火して止めるかを試していない。Bash で書く道は `Write` の matcher に当たらない |
| 索引の大きさと禁じた語を定期に見る検査 | 制御（見つけるだけ） | Claude Code | sync の検査か別のスクリプト | 直接（書かれたあとの状態を見る） | 止めない。見つけて知らせる | 入れられる | 索引の上限は `[verified]`（CC-memory） | 何を禁じた語にするか（ほかのリポジトリの名前の一覧を公開の hub に置けない） |
| 記憶に書くもの・書かないものを決まりの文に書く | 調整 | Claude Code | 決まりの文 | モデル | モデルが従う範囲 | 入れられる | `CLAUDE.md` に書いてあることは記憶に残さない、と公式が書く `[verified]`（CC-memory） | 効き方は測っていない。system prompt の指示とどちらが勝つかも分からない |
| `features.memories`・`memories.generate_memories`・`memories.use_memories` を設定に置く | 制御 | Codex | 設定に鍵を足す sync | 新しい会話の材料化・既存の記憶の読み込み | 設定を継承する起動。会話や起動ごとの上書きは別に確認する | 鍵を配る実装は可能だが、この調査では実装・採用をしない | `[verified]`（CX-config・通知 sync の実装） | `generate_memories=false` だけでは既存の材料の整理やファイルの直接編集は止めない。通知 sync は記憶の鍵をまだ配らない |
| `memories.disable_on_external_context = true` | 制御 | Codex | 同上 | 会話の材料化 | MCP・Web検索・tool search など外の文脈を使った会話 | 設定の候補になる | `[verified]`（CX-config） | 外の文脈を使わない会話は除外しない。手元の比較試験はしていない |
| hub の道具が打つ `codex exec` に `-c memories.generate_memories=false` か `--ephemeral` を付ける | 制御 | Codex | hub の起動コマンド | 材料化、または起動時の裏の処理 | `generate_memories=false` は新しい会話の材料化。`--ephemeral` は会話ファイルの保存とその起動からの裏の処理 | 異なる作用の候補として入れられる | `[verified]`（CX-config・CX-exec-help・CX-source の `write/start.rs`） | 通常の `exec` 自体は実装の抽出候補外である。どちらも既存記憶の読み込みは別で、`use_memories=false` が要る。0.170.0の比較試験はしていない |
| Codex のホームを用途ごとに分ける | 制御 | Codex | 起動の環境 | 整理・読み込み | 分けたホームの会話 | 入れられる見込み | ホームの下に置くことは `[verified]`（CX-memories） | 認証・設定・hook もホームごとに分かれる。重い |
| 整理の会話の道具の呼び出しを hook で見る | 制御 | Codex | hook | 整理（整理の会話が道具を使うときだけ） | 不明 | 分からない | 2026-11-15 に、整理の会話でも hook が走った `[record]`（PR #648 の本文） | いまの版でも走るか、止める判定ができるかを確かめていない |
| チームで要る指示は `AGENTS.md` に置き、記憶だけに頼らない | 調整 | Codex | 決まりの文 | 利用者向けの会話の文脈 | モデルが従う範囲 | 入れられる | `[verified]`（CX-memories） | この方針だけで、抽出や整理の出力内容を機械的に制約できるとは確認していない |

- `extensions/` は整理の入力を拡張する仕組みで、実装は `ad_hoc/instructions.md` を初期配置し、整理のプロンプトへ extensions の説明と主な入力の案内を加える `[verified]`（CX-source・`write/extensions/ad_hoc.rs`・`write/prompts.rs`）。手元の両方の版にも `extensions/ad_hoc/instructions.md` が1件ずつある `[verified-local]`（CX-local）。
- `extensions/ad_hoc/notes/<timestamp>-<slug>.md` に追記・訂正・削除の要望を置く入口がある。Codex の確かめの会話に渡された読む指示も、利用者から直接頼まれたときだけそこへ書くよう求めている `[verified-local]`（2026-11-25・指示の経路だけを確認した）。公開の初期配置テンプレートにも、notes を整理へ反映し、notes の本文を実行指示にはしないよう書かれている `[verified]`（CX-source・`codex-rs/memories/write/templates/extensions/ad_hoc/instructions.md`）。これはモデルへの調整であり、内容の採否を機械的に強制する設定ではない。今回は notes の作成も整理の試験もしていない。

## 6. 効き目と止めたときの影響

記憶がどの程度効いているか、いま止めたらどういう影響が出るかを見る。使われ方の数は、2つで物差しが違う。Claude Code は直近 30 日の会話の記録で数えた道具の呼び出しの回数、Codex は DB に残っている行の累積の利用回数で、並べて比べられない。Claude Code は hub での数である。Codex はホーム共通なので、ホーム全体の集計と、作業ディレクトリを hub に絞った集計を区別する。

### 6.1 Claude Code（hub の記憶）

**毎回の会話にかかる量**

- hub の索引 `MEMORY.md` は 79 行・25,397 バイトで、hub のすべての会話の始まりに読み込まれる `[verified-local]`（2026-11-25）。上限は 200 行か 25KB のどちらか少ないほうなので `[verified]`（CC-memory）、大きさはほぼ上限に届いている。上限を超えると、超えた部分は次の会話で落ちる `[verified]`（同）。

**中身の内訳**

| 型（記憶のファイルの `metadata.type`） | 件数 |
|---|---|
| feedback（作業のしかたへの指摘） | 44 |
| project（進行中の作業の状態） | 22 |
| reference（道具の落とし穴・外の場所の指し先） | 12 |
| user（owner について） | 1 |

- 数え方: 79 件のファイルの frontmatter の `metadata.type` を数えた `[verified-local]`（2026-11-25）。
- 索引の行のうち、「決まりやスキルに入った・記憶は由来だけ」と書き手が書いた行は 7 行、「終わった（消化済み）」と書いた行は 1 行だった `[verified-local]`（2026-11-25）。
  - 数え方: 索引の行を「正本」「codify」「に入った」「由来のみ」「消化済み」の語で拾い（12 行）、1行ずつ読んで、決まりかスキルに入ったと書いた行だけを残した。「正本」を方針の言葉として使っている行（決まりに入ったことを言っていない行）は外した。
  - 印が無くても、中身が決まりやスキルに入っている記憶はありうる。7 件は下限で、残りの 71 件が「記憶にしか無い」とは言い切れない。

**使われ方（直近 30 日）**

- 数えた範囲: hub とその worktree の会話の記録（`~/.claude/projects/` の下の `.jsonl`）115 本。記録の日付は 2026-10-26〜11-25 で、それより古い記録は残っていなかった。サブエージェントの記録は数えていない（サブエージェントは親の記憶を読み込まないため・CC-memory）。

| 道具 | 回数 | 記憶のファイルの数（索引を除く） |
|---|---|---|
| `Read` で開いた | 4 | 3 |
| `Write` で書いた | 16 | 19（`Write` と `Edit` を合わせて） |
| `Edit` で直した | 24 | （同上） |

- 数え方: 会話の記録のうち、道具の呼び出しの `file_path` が hub の記憶のフォルダを指すものを `jq` で数えた `[verified-local]`（2026-11-25）。
- Bash（`cat` など）で記憶のフォルダに触れた呼び出しもある。ただし、記憶の整理の作業とこの調査の呼び出しが混じっていて、作業のために読んだ回と分けられないので、表には入れていない。
- 読み取れること: 個別のファイルは書かれる一方で、`Read` ではほとんど開かれていない。効いているのは主に、毎回読み込まれる索引の1行の要約だと見ている `[speculation]`（分からなかった理由: どの記憶がどの判断に効いたかは記録に残らない）。

**いま止めたとき（`autoMemoryEnabled: false`）**

| | 内容 | 根拠 |
|---|---|---|
| 失うもの（feedback） | 決まりやスキルにまだ入っていない、作業のしかたへの指摘。その振る舞いは、決まりの文に無ければ元に戻りうる | `[speculation]`（分からなかった理由: 記憶を切って同じ作業をさせる試しをしていない） |
| 失うもの（project） | 会話をまたいで持ち越している作業の状態（観察中の試し・試し入れ中の道具など）。owner が説明し直すことになる | `[speculation]`（同上） |
| 失うもの（reference） | 道具の落とし穴。同じ穴をまた踏みうる | `[speculation]`（同上） |
| 得るもの | 毎回の会話で、約 25KB の文脈が空く。engine の Claude の子の作業が hub の記憶に入らなくなる | 量は `[verified-local]`。子の分は節 3.1 の「範囲」の見立て（`[speculation]`）から |
| 戻せるか | 設定は記憶の読み書きを止めるもので、ファイルを消すとは書かれていない。戻せば元の記憶がまた読み込まれる見込み | 止める範囲は `[verified]`（CC-settings）。戻ることは `[speculation]`（分からなかった理由: 戻す試しをしていない） |
| 変わらないもの | サブエージェントは、もともと親の記憶を読み込まない | `[verified]`（CC-memory） |

### 6.2 Codex

**会話へ入る量**

- 手元の v1 の summary は6,789バイト・97行だった。`MEMORY.md` は36,547バイト・370行だが、初期注入で全量が入るわけではない `[verified-local]`（2026-11-25・CX-local）。実装の初期注入の対象と上限は節3.2のとおりである。ファイルのバイト数は、実際に消費するトークン数ではない。

**利用の記録と件数**

- 置き場は `$CODEX_HOME/memories_1.sqlite` と `$CODEX_HOME/memories_v2_1.sqlite` の `stage1_outputs` で、`usage_count` と `last_usage` がある `[verified-local]`（2026-11-25・CLI 0.170.0環境・スキーマを読み取りで確認した）。実装の `record_stage1_output_usage` は引用された会話IDごとに回数を1増やして最終利用時刻を記録する `[verified]`（CX-source・`codex-rs/state/src/runtime/memories.rs`）。assistant のメッセージに含まれる記憶の引用から会話IDを取り出し、選択中の版の DB へ加算する経路まで確認した `[verified]`（CX-source・`codex-rs/core/src/stream_events_utils.rs`・`codex-rs/memories/read/src/citations.rs`）。これは引用による記録であり、単なるファイルの読み取り回数ではない。

| 対象 | 抽出結果の件数 | 利用が記録された件数 | 回数の合計 | 0回の件数 |
|---|---|---|---|---|
| v1 のホーム全体 | 10 | 4 | 18 | 6 |
| v2 のホーム全体 | 7 | 0 | 0 | 7 |
| v1 のうち作業ディレクトリが hub のもの | 0 | 0 | 0 | 0 |
| v2 のうち作業ディレクトリが hub のもの | 0 | 0 | 0 | 0 |

- 数え方: 読み取り専用で `COUNT(*)`、`SUM(COALESCE(usage_count,0))`、正の回数の行数を集計した。未設定の回数は0として数えた。v1 の内訳は0回が6件、1回・2回・4回・11回が各1件である。`last_usage` の範囲は2026-11-07 03:38:47〜11-16 03:03:15（JST）、v2 は全件未設定だった `[verified-local]`（2026-11-25の読み取り時点）。直近30日の利用回数ではなく、残っている行の累積値である。日ごとの履歴を持たないので、この表から直近30日の回数は出さない。
- hub の数え方: `stage1_outputs.thread_id = state_5.sqlite` の `threads.id` で結び、`cwd` が hub の根と一致するもの、根の配下、根に `.` が続く兄弟 worktree に絞った。両方とも0件だった。別の作業ディレクトリから hub の話をした会話はこの条件で拾えない。これを「hub で記憶が使われていない」という証拠にはしない。記憶の本文による分類はしていない。
- `usage_count` は上の引用に基づく記録なので、summary の注入回数やファイルを開いた回数と同一視できない `[verified]`（CX-source・引用の加算経路）。判断に役立った回数も分からない `[speculation]`（見た資料: 引用の解析・DB の加算処理。分からなかった理由: 効果を追跡する比較試験をしていない）。v1 と v2 を足して17件の独立した知識としては扱わない。
- この集計の後、同じ DB を `mode=ro` で開き直すと `unable to open database file` になった。原因は確定しておらず、上の値は先に成功した読み取りの時点の値として残した。DB の中身を転記せず、設定・記憶・DB は変更していない。

**止めたときの影響**

| 設定 | 失うもの | 得るもの・止まる範囲 | 止まらないもの・限界 | 根拠 |
|---|---|---|---|---|
| `use_memories=false` | 既存の summary の注入と、そこから過去の記録を探す案内が無くなる | その注入の文脈を使わなくなる | 新しい会話の材料化や、裏の抽出・整理は別である。通常のファイルの道具で直接読む経路を禁じるものではない | `[verified]`（CX-config・CX-source の `read/extension.rs`・`write/start.rs`） |
| `generate_memories=false` | 新しい会話から将来の記憶を作る材料が追加されなくなる | 新しい会話を記憶の材料として保存しない | 既存記憶の利用は別である。既存の材料による整理の起動も、実装ではこの鍵だけを条件に止めない | `[verified]`（CX-config・CX-source の `write/start.rs`） |
| 両方を `false` | 既存の記憶の注入と新しい会話の材料化を両方失う | 上の2つを同時に止める | 過去の材料・既存ファイルの削除ではなく、全ファイルの読み書きを禁じる権限でもない | `[verified]`（同上） |
| `features.memories=false` | 機能の読み込みと起動時の抽出・整理を失う | 実装の読み込みと起動時の抽出・整理を止める | ファイルを消す操作や、直接の読み書きの禁止とは別である | `[verified]`（CX-source の `read/extension.rs`・`write/start.rs`） |

**型と、決まりとの重なり**

- Codex の記憶には、Claude Code の feedback・project のような型の区分が無い。数えられるのは抽出結果の件数（v1 10件・v2 7件）までである `[verified-local]`（2026-11-25・CX-local）。
- 決まりや `AGENTS.md` にも入っている記憶の件数は数えていない。数えるには記憶の本文を読んで分類する必要があり、この調査では本文を読まない形にしたためである（見た資料: DB のスキーマと件数だけ）。

**戻せるか**

- 鍵を `true` に戻したときに、止めていたあいだの会話が材料に戻るか、既存の記憶がそのまま読み込まれるかは試していない `[speculation]`（見た資料: CX-config と読み込みの実装。分からなかった理由: 戻す試しをしていない）。鍵はファイルを消す設定ではない `[verified]`（上の表の「止まらないもの・限界」の列）。

- どの設定でも、失う振る舞いや品質を件数から推定していない。設定を切って同じ作業をさせる比較試験は節6.3のとおり今回の範囲外である。生成のモデル利用量がどれだけ減るかも測っていない。設定を戻す試験もしていないため、戻した後の再開時機と件数は未確認である。

### 6.3 この issue では行わない試し

- 記憶を切った会話と入れた会話で同じ作業をさせて、振る舞いの差を比べる試し。止めたときに失うものを件数でなく振る舞いで確かめられるが、重いので、何を入れるかを決める issue の候補として書き留める。

## 7. Codex による確かめの記録

- 2026-11-25 02:27〜04:30 に、Codex（CLI 0.170.0）が文書を確かめて直した。Codex の数え方では、58 行を直し、48 行を足した。行ごとの差は、この調査メモの git の履歴（Codex の確かめを入れた commit）で読める。ここには中身の大きい直しだけを書く。
- 「Claude の確かめ」の列は、Codex のあとに Claude が出典の原文を開いて当てたかを書く。公開ソースは固定コミット `44308610ef5c` のファイルを GitHub から取って当てた。

| 節 | 何が変わったか | Codex が確かめた出典 | Claude の確かめ |
|---|---|---|---|
| 2・3.2 書き手と時機 | 初稿は「会話が6時間動かなくなってから書く」とだけ書いていた。実装では、root の会話を始めたときに裏の抽出と整理が起動し、6時間は材料になる無活動の条件である、と直した | CX-source の `write/start.rs`・`write/phase1.rs` | `write/start.rs` の原文で、起動の関数と条件を確かめた |
| 2・3.2 読み込まれ方 | 初稿は「量の記述が無い」だった。`memory_summary.md` を最大 2,500 トークン相当に切って入れ、`MEMORY.md` は初期注入しない、と埋めた | CX-source の `read/prompts.rs`・`read/lib.rs`・`read/extension.rs` | `read/prompts.rs` と `read/lib.rs` の原文で、上限の定数と切る処理を確かめた |
| 2・3.2 ほかのエージェントに起こされた会話 | 初稿は「記述が無い」だった。材料になる会話は `cli`・`vscode`・`atlas`・`chatgpt` で、`exec` とサブエージェントは材料にならない。ただし `exec` も裏の処理を起動しうる、と埋めた | CX-source の `codex-rs/rollout/src/lib.rs`・`write/phase1.rs`・`write/start.rs` | 3つの原文で、許可する会話の種類の一覧と、起動を飛ばす条件（ephemeral・機能が無効・サブエージェント）を確かめた |
| 3.2 人が手を入れる口 | `--ephemeral` は起動時の裏の処理も起動しない。`generate_memories=false` は新しい会話の材料化を止めるだけで、既存の材料の整理は止めない、と直した | CX-config・CX-exec-help・CX-source の `write/start.rs` | `write/start.rs` の原文で、起動を飛ばす条件に ephemeral はあり、`generate_memories` は無いことを確かめた |
| 3.2 範囲 | 記憶のフォルダの git は、前の整理が成功した時点との差分を作る基準で、整理が成功すると作り直す、と埋めた | CX-source の `write/workspace.rs`・`codex-rs/git-utils/src/baseline.rs` | 確かめていない |
| 3.2 読み込まれ方 | 整理の対象は「最近の 256 件」ではなく、使われた日と回数で選ぶ、と直した | CX-source の `codex-rs/state/src/runtime/memories.rs` | 確かめていない |
| 3.2 sync | 初稿の「無い鍵を足すだけ」は誤りで、旧 hook の鍵を移すときは既存の行を書き換える、と直した | `scripts/sync/apply-codex-notify-config.sh` | 原文で確かめた（`codex_hooks` を `hooks` に書き換える処理がある） |
| 3.1 外へ出る道 | 「リポジトリごと」は既定の配置のときで、`autoMemoryDirectory` などで共有先を指したときは別、と限定を足した | CC-memory | 原文で確かめた（「Storage location」節） |
| 4.1・4.2 | 抽出と整理のプロンプトが、記録の中の指示を指示として扱わないよう求め、利用者の発言とモデルの説明を区別するよう求めている、と埋めた | CX-source のプロンプトの2つのテンプレート | 確かめていない |
| 5 extensions | `extensions/` は整理の入力を広げる仕組みで、`ad_hoc/notes/` に足す・直す・消すの要望を置く入口がある、と埋めた | CX-source の `write/extensions/ad_hoc.rs`・`write/prompts.rs`・テンプレート | 確かめていない |
| 6.2 | 使われ方の記録（DB の `usage_count` と `last_usage`）と件数、設定ごとに止めたときの影響を足した | DB のスキーマと集計・CX-source の `codex-rs/state/src/runtime/memories.rs`・`codex-rs/core/src/stream_events_utils.rs` | 確かめていない。DB は Codex が読み取った |
| 札 | Claude Code の側の札を `[record]` と `[unverified-summary]` に弱めた | なし（再検証しなかったため） | Claude が元の札に戻した（節 1 の「検証の範囲」） |

- Codex の行単位の一覧と、取ってきたソース・集計の記録は、作業の置き場（git の対象外）に残してある。
- Codex は推敲の道具（yomiyasu）でも文を直していて、道具は意味が変わる恐れのある箇所を多く挙げていた。Claude は上の表の直しを読んだが、推敲で変わったすべての文を元の文と照らしてはいない。表の「確かめていない」行は、Codex の確かめだけに拠っている。

## 8. 観察の記録

### 8.1 Codex の記憶の置き場の前後

| 時点 | git の commit の数と HEAD | 作業ツリーの変更 | 主なファイルの更新時刻 |
|---|---|---|---|
| 2026-11-24 13:4x（認識合わせの `codex exec` の前） | 1件・`c3d9b18` | 0件 | `MEMORY.md` 11-21 02:15・`raw_memories.md` 11-21 15:04 |
| 2026-11-24 13:4x（同じ `codex exec` の直後） | 1件・`c3d9b18` | 0件 | 変わらず |
| 2026-11-24 23:4x（設計SO の `codex exec` の直後） | 1件・`c3d9b18` | 0件 | `raw_memories.md` と要約の2件が 11-24 20:33、大きさは同じ |
| Codex に確かめを渡す前（2026-11-25 02:27・初稿側の記録） | v1 は1件。確認後との比較では HEAD が変わった。v2 は1件で変わらなかった | 両方0件 | v1 の `MEMORY.md` は11-21 02:15、summary は11-21 02:16。v2 の summary は11-15 21:09 |
| Codex の読み取り時点（2026-11-25） | 両方1件。v1 は前の控えから HEAD が変わり、v2 は変わらなかった | 両方0件 | v1 の `MEMORY.md` は11-25 02:36、summary は11-25 02:36、`raw_memories.md` は11-25 02:35。v2 の summary は変わらず |
| Codex の確かめのあと（2026-11-25 04:34） | v1 は1件で、渡す前と HEAD が違う。v2 は1件で同じ | 両方0件 | v1 の `MEMORY.md` 30,891→36,547 バイト、`memory_summary.md` 5,817→6,789 バイト、`raw_memories.md` 49,021→53,635 バイト、会話ごとの要約 9→10 件。v2 は変わらず |

- 1〜4行目と最後の行は Claude が、5行目は Codex が、それぞれその時点で読み取った `[verified-local]`。記憶の本文・commit の件名・要約の名前は転記していない。
- v1 の更新は 02:35〜02:36 で、Codex が確かめの会話を始めてから10分以内だった。公開ソースでは、対話の root の会話を始めると裏の抽出と整理が起動する `[verified]`（CX-source・`write/start.rs`）ので、時刻は合う。ただし同じ時間に owner のほかの Codex の会話が動いていたかは確かめておらず、どの会話の開始が起動したかは決められない。増えた要約の中身も読んでいない。
- 2026-11-24 には、owner の別の Codex の会話もいくつも動いていた。前後の差は、どの会話が書いたかの証拠にしない。

### 8.2 Claude Code の試し

- 2026-11-25・Claude Code 2.1.331・デスクトップ版の会話の Bash から起こした入れ子の `claude -p`（`CLAUDE_CODE_CHILD_SESSION=1`）。
- 試しの前とあとに `~/.claude/projects/` の下のフォルダの一覧を控え、増えたフォルダだけを試しが作ったものとした。試しAで1つ、試しBで1つ増えた。
- 試しA（設定をそのまま）: 増えたフォルダの下の `memory/` に2つのファイルができた。
- 試しB（`autoMemoryEnabled: false`）: 増えたフォルダに `memory/` はできなかった。
- 判定（plan の DJ-6 の3つの場合のうち）: 試しAで書かれ、試しBで書かれなかったので、「比べられる場合」に当たる。この条件（入れ子の `claude -p`・`--settings` で渡す）では、設定を切ると書かれなかった。書かれなかったことは、機械的に禁じられていることの証明にはしない。
- 試しが作った2つのフォルダは、消さずに作業の一時の置き場へ移した。一覧は試しの前と同じに戻った。

## 9. つながりうるもの

- hub の knowledge item（`docs/harness/knowledge/items/`）。記憶と同じく会話をまたいで残る知識の置き場で、効く状況（trigger）と観測の記録を持つ。記憶との役割の分け方は、何を入れるかを決める issue の材料になる。
- engine の negative knowledge loop の設計（`projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`）。何をきっかけに書き（trigger）、どこに残し（store）、どう会話に入れるか（inject）の3つで、Cursor Memories（保存の前に人の承認がある）などを比べている。この文書の候補の表は、この3つのうち「書く」と「入れる」の口に当たる。
- engine の層の issue（未起票）。engine が起こす子の記憶を、エージェントに依らない形でどう制御するか。この文書の Claude Code の環境変数・設定と、Codex の `-c` が材料になる。
- [#649](https://github.com/stlwolf/ai-development-hub/issues/649)（Codex の sandbox と権限の既定）。Codex の記憶の設定を決める場が重なる。

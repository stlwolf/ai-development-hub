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

## 1. 目的と範囲

- 目的は、ハーネスとして記憶に何を入れられて何を入れられないかを、出典つきで1つの文書から分かるようにすることである。何を入れるかは決めない。
- 「調整」は、何を書くかを文で導くものを指す。効くかどうかはモデル次第である（例: 決まりの文・`CLAUDE.md`・`AGENTS.md`）。
- 「制御」は、設定・hook・権限で機械的に止めたり絞ったりするものを指す（例: 記憶を書かせない設定の鍵、記憶のフォルダへの書き込みを止める hook）。
- 範囲の外: engine の子の記憶をどう扱うか（engine の層）、いまある記憶の棚卸しと整理、何を入れるかの決定。

## 2. 比べた表

| 項目 | Claude Code | Codex |
|---|---|---|
| 書き手と時機 | モデル自身が会話の途中で書く。何を残すかはモデルが決め、頼まれたときも書く `[verified]`（CC-memory）。非対話の `claude -p` でも、頼むと通常のファイルの道具（`Write`）で書いた `[verified-local]`（2.1.331・2026-11-25・節 3.1） | 裏で動く処理が、会話のあとにまとめて書く。会話がしばらく動かなくなってから（既定 6 時間）、対象になる会話を材料にする `[verified]`（CX-memories・CX-config の `memories.min_rollout_idle_hours`） |
| 範囲 | リポジトリごと。worktree とサブディレクトリは同じフォルダを共有する `[verified]`（CC-memory）。hub の worktree のフォルダに記憶は無かった `[verified-local]`（2026-11-25） | Codex のホーム（既定 `~/.codex`）の下に1つ。リポジトリごとに分ける記述は無い `[verified]`（CX-memories）。手元の置き場には、複数のリポジトリの作業の要約が並んでいた `[verified-local]`（2026-11-25・件数のみ確認） |
| 読み込まれ方 | 会話の始まりに `MEMORY.md` の先頭 200 行か 25KB のどちらか少ないほう。個別のファイルは必要なときに読む `[verified]`（CC-memory）。hub の索引（79 行・25,397 バイト）は最後の行まで読み込まれていた `[verified-local]`（2026-11-25） | `use_memories` が真なら、あとの会話に既存の記憶を入れる `[verified]`（CX-config）。どれだけ入るか・上限は公式の文書に無い（見た資料: CX-memories・CX-config。分からなかった理由: 量の記述が無い） |
| 人が手を入れる口 | 中身はファイルで、読む・直す・消すができる。`autoMemoryEnabled` で読み書きを止め、環境変数で会話1回ぶんだけ止められる `[verified]`（CC-settings・CC-env）。止めた回では記憶のフォルダができなかった `[verified-local]`（節 3.1） | 鍵は `features.memories`・`memories.generate_memories`・`memories.use_memories` ほか `[verified]`（CX-config）。会話ごとの切り替えは対話の `/memories`。手で直すことは主な制御の手段にしないよう書かれている `[verified]`（CX-memories）。CLI で消すコマンドの記述は無い（デスクトップの「Delete Codex memories」だけ） `[verified]`（CX-memories） |
| ほかのエージェントに起こされた会話 | サブエージェントには親の記憶を読み込まない（fork は除く） `[verified]`（CC-memory）。Bash から起こした入れ子の `claude -p` でも書いた `[verified-local]`（節 3.1）。tmux で起こした会話は入れ子として扱わない `[verified]`（CC-env の `CLAUDE_CODE_FORCE_SESSION_PERSISTENCE`） | 対話・`exec`・サブエージェントのどれが材料になるかの記述は無い（見た資料: CX-memories・CX-config・CX-exec-help。分からなかった理由: 会話の種類で分ける記述が無い）。2026-11-15 に、engine の Codex の子のプロセスの中で整理の会話が走った `[record]`（PR #648 の本文・Codex CLI 0.167.2） |
| 外へ出る道 | 記憶は会話の文脈として読み込まれ、強制される設定ではない `[verified]`（CC-memory）。読み込まれた記憶を、モデルが文書や commit に写す道は塞がれていない `[speculation]`（見た資料: CC-memory。分からなかった理由: 写すことを防ぐ仕組みの記述が無い） | 置き場が全部のリポジトリで共通で、あとの会話に入る（上の2行）ので、hub の会話の文脈に、ほかのリポジトリの作業の要約が入りうる `[speculation]`（仕組みは `[verified]`、実際に入ったかは確かめていない）。秘密の値は伏せられる `[verified]`（CX-memories）が、リポジトリの名前のような識別子を伏せるとは書かれていない |

## 3. 項目ごとの詳しい内容

### 3.1 Claude Code

**書き手と時機**

- 公式の文書の表では、自動の記憶を書くのは Claude である `[verified]`（CC-memory の表「Who writes it」）。何を残すかは、あとの会話で役立つかでモデルが決め、毎回書くわけではない `[verified]`（CC-memory「Auto memory」節）。コードから分かることと、`CLAUDE.md` に書いてあることは残さない、と書かれている `[verified]`（同）。
- 何を書くかの細かい指示は、harness の system prompt の記憶の節にある。この会話（デスクトップ版・2.1.331）に渡された指示では、記憶を user・feedback・project・reference の4つの型に分け、リポジトリに記録されていることと、その会話の中だけで要ることは残さない `[verified-local]`（2026-11-25・この会話の system prompt）。hub はこの文を書き換えられず、足すことだけができる。
- 試しA（2026-11-25・2.1.331）: リポジトリの外の一時ディレクトリで、Bash から `claude -p` に「合言葉を覚えて」と頼んだ。`~/.claude/projects/<一時ディレクトリから作った名前>/memory/` に、個別のファイルと `MEMORY.md` の2つができた。会話の記録では、どちらも `Write` の道具で書いていた `[verified-local]`。

**範囲**

- `<project>` は git のリポジトリから決まり、worktree とサブディレクトリは1つの記憶のフォルダを共有する。git の外ではプロジェクトの根を使う `[verified]`（CC-memory「Storage location」）。
- `autoMemoryDirectory` で置き場を変えられ、どの設定の層（user・project・local・policy・`--settings`）からでも読む `[verified]`（CC-memory・CC-settings）。`CLAUDE_CODE_PROJECT_DIR_NAME` を `CLAUDE_CONFIG_DIR` と一緒に置くと、どのリポジトリで起こしても1つのフォルダを共有する `[verified]`（CC-memory。v2.1.234 以降）。
- 記憶はその機械の中だけにある `[verified]`（CC-memory）。
- 手元: `~/.claude/projects/` の下に 163 のフォルダがあり、`memory/` を持つのは 64 だった。hub の記憶は 79 件・索引 25,397 バイト・79 行で、hub の worktree の3つのフォルダには `memory/` が無かった `[verified-local]`（2026-11-25）。
- engine の Claude の子は hub の worktree で動くので、子の書いた記憶は hub の記憶のフォルダに入る `[verified]`（CC-memory の worktree の共有と、子が worktree で動くことから）。実際に子が書いた件数は数えていない。

**読み込まれ方**

- 会話の始まりに `MEMORY.md` の先頭 200 行か 25KB のどちらか少ないほうを読み込む。個別のファイルは始まりでは読まず、必要なときに読む `[verified]`（CC-memory「How it works」）。
- 上限を超えても書き込みは通るが、Claude Code が Claude に索引を書き直すよう返し、上限を超えた部分は次の読み込みで落ちる。上限に近いと短くするよう促す `[verified]`（同）。
- `CLAUDE.md` は 4 MiB までなら全部を読み込み、記憶の索引の上限はかからない `[verified]`（同の注記）。
- hub の索引は 25,397 バイトで、この会話の文脈には最後の行まで入っていた `[verified-local]`（2026-11-25）。25,000 バイトで切ると最後の数行が落ちるので、この版の 25KB は 25,397 バイトより大きい。25,600 バイト（25 KiB）か、ほかの数え方かは確かめていない。

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

- 自動の記憶はリポジトリごとなので、ほかのリポジトリの自動の記憶は hub の会話に読み込まれない `[verified]`（CC-memory の範囲）。
- ただし、hub の会話の中で書いた記憶は hub の索引に入る。hub の索引には、ほかのリポジトリを名指しする行がある `[verified-local]`（2026-11-25・名前は写さない）。索引は毎回の会話の文脈に入るので、モデルがその名前を公開の文書や commit に写す道は、文で禁じているだけである（`CLAUDE.md` の「公開リポジトリとしての決まり」） `[speculation]`（見た資料: CC-memory・hub の `CLAUDE.md`。分からなかった理由: 写したことがあるかは数えていない）。

### 3.2 Codex

**書き手と時機**

- 記憶を有効にすると、Codex は対象になる過去の会話から役に立つ文脈を取り出し、手元の記憶のファイルにする。動いている会話と短い会話は飛ばし、会話が終わるたびでなく裏でまとめて書く `[verified]`（CX-memories「How local Codex memories work」）。
- 会話がどれだけ動かなければ材料になるかは `memories.min_rollout_idle_hours`（既定 6・1〜48）、どれだけ古い会話まで見るかは `memories.max_rollout_age_days`（既定 30） `[verified]`（CX-config）。
- 取り出し（会話ごと）と整理（全体）に別のモデルを指定できる（`memories.extract_model`・`memories.consolidation_model`） `[verified]`（CX-config）。
- 2026-11-15 に、engine の Codex の子のペインで、整理の会話が子の画面と同じプロセスの中で走り、会話の記録を残さなかった。その会話は子の起動の1行の `-c developer_instructions` と子の環境を受け継いでいた `[record]`（PR #648 の本文・#562 の decision・Codex CLI 0.167.2）。

**範囲**

- 記憶は Codex のホーム（既定 `~/.codex`）の下に置く。新しいホームでは `memories_v2/` を使い、`memories/` が既にあれば `memories/` を使い続ける `[verified]`（CX-memories・CX-config の `memories.version`）。移行のあいだは、新しい会話が `memories/` を読んで両方に書くことがある `[verified]`（CX-memories）。
- リポジトリごとに分ける記述は無い `[verified]`（CX-memories・CX-config に無い）。分けたければ Codex のホームごと分けることになる `[speculation]`（見た資料: CX-memories。分からなかった理由: ホームを分けたときの記憶の扱いの記述が無い）。
- 手元（2026-11-25）: `~/.codex/memories/` と `~/.codex/memories_v2/` の両方がある。`memories/` には `MEMORY.md`（30,891 バイト）・`memory_summary.md`・`raw_memories.md`・`rollout_summaries/` の9件などがあり、`memories_v2/` には `memory_summary.md` と `rollout_summaries/` の7件などがある。要約は会話ごとの1ファイルで、複数のリポジトリの作業のものが並んでいた（名前は写さない） `[verified-local]`。
- どちらのフォルダも git のリポジトリで、commit は1件だけ、作者は「Codex」、日時は最後の整理のころだった `[verified-local]`（2026-11-25）。履歴を残さず、整理のたびに基準の commit を作り直している見込みである `[speculation]`（見た資料: 2つのフォルダの git の履歴。分からなかった理由: 公式の文書に git の記述が無い）。

**読み込まれ方**

- `memories.use_memories` が偽なら、既存の記憶をあとの会話に入れない（既定は真） `[verified]`（CX-config）。
- 何をどれだけ入れるか・上限は、公式の文書に無い（見た資料: CX-memories・CX-config。分からなかった理由: 量の記述が無い）。
- 大きくなったときに効くのは整理の側の上限で、整理に使う生の記憶は最近の 256 件まで、30 日使われなかった記憶は整理の対象から外れる `[verified]`（CX-config の `memories.max_raw_memories_for_consolidation`・`memories.max_unused_days`）。

**人が手を入れる口**

| 口 | できるか | 根拠 |
|---|---|---|
| 読む | できる。困ったときやホームを人に渡す前に見てよい | `[verified]`（CX-memories） |
| 直す | ファイルは「作られた状態」として扱い、手で直すことを主な制御の手段にしないよう書かれている | `[verified]`（CX-memories） |
| 消す | デスクトップの設定の「Delete Codex memories」で、その機械の記憶の置き場を消す。CLI で消すコマンドの記述は無い | `[verified]`（CX-memories） |
| 機能ごと切る | `features.memories`（既定は切） | `[verified]`（CX-config・CX-memories） |
| 書かせない（全体） | `memories.generate_memories = false` で、新しい会話を材料にしない | `[verified]`（CX-config） |
| 読ませない（全体） | `memories.use_memories = false` | `[verified]`（CX-config） |
| 外の文脈を使った会話だけ外す | `memories.disable_on_external_context = true` で、MCP の道具・Web 検索などを使った会話を材料から外す | `[verified]`（CX-config） |
| 書かせない（会話1回・対話） | 対話の画面の `/memories` で、その会話が記憶を使うか・材料になるかを決める。全体の設定は変わらない | `[verified]`（CX-memories） |
| 書かせない（会話1回・`exec`） | `-c` で設定の値を1回だけ上書きできるので、`-c memories.generate_memories=false` が考えられる。効くかは試していない | `-c` の仕組みは `[verified]`（CX-exec-help）。記憶への効き目は `[speculation]`（分からなかった理由: 試していない） |
| 会話の記録を残さない | `codex exec --ephemeral` は会話のファイルを保存しない | `[verified]`（CX-exec-help）。材料から外れるかは `[speculation]`（分からなかった理由: 記録が無い会話を材料にしないという記述が無い） |

- 手元の設定（2026-11-25）は、`features.memories = true`・`memories.generate_memories = true`・`memories.use_memories = true` だった `[verified-local]`。公式の既定は「切」なので、owner が有効にしている。
- 手元の `~/.codex/config.toml` では、hub の sync が印を付けた範囲の中に、Codex 自身が書いた `[memories]` などの表が入り込んでいた `[verified-local]`。hub の sync（`scripts/sync/apply-codex-notify-config.sh`）は、無い鍵を足すだけで範囲を書き直さないので、いまは壊れていない。

**ほかのエージェントに起こされた会話**

- 対話・`exec`・サブエージェント・アプリのどの会話が材料になるかは、公式の文書に無い。書かれているのは「対象になる過去の会話」と「動いている会話と短い会話は飛ばす」だけである（見た資料: CX-memories・CX-config・CX-exec-help）。
- 2026-11-24 に、認識合わせのために `codex exec`（so-compare の Codex のレーン）を1回打った直後は、`~/.codex/memories` の git の HEAD と主なファイルの更新時刻は変わらなかった。同じ日の 20:33 に `raw_memories.md` と要約の2件の更新時刻が変わったが、git の作業ツリーの変更は0件で、大きさも同じだった。同じ日に owner の別の Codex の会話がいくつも動いていたので、どの会話が何をしたかは決められない `[verified-local]`（観察の記録の節）。
- engine は Codex の子を起こす1行に `-c developer_instructions` を渡している `[verified]`（`projects/orchestration-engine/lib/agent.sh`）。同じ1行に記憶の鍵を足す道はあるが、それは engine の層の話である。

**外へ出る道**

- 置き場は1つで、`use_memories` が真ならあとの会話に入る。そのため、hub の会話の文脈に、ほかのリポジトリの作業から作られた記憶が入りうる。仕組みは `[verified]`（上の範囲と読み込まれ方）、実際に入ったかは `[speculation]`（分からなかった理由: どの記憶が会話に入ったかを見る口を確かめていない）。
- 秘密の値は伏せる、と書かれている `[verified]`（CX-memories）。リポジトリの名前や社名のような識別子を伏せる記述は無い。
- チームで要る指示は、記憶でなく `AGENTS.md` かリポジトリの文書に置くよう書かれている `[verified]`（CX-memories）。

## 4. 別のモデルが挙げた3つの観点

認識合わせのときに Codex が挙げた抜けである。

### 4.1 記憶に入った指示が、後の会話で有効な指示として効くか

- Claude Code: 記憶は文脈で、強制される設定ではない `[verified]`（CC-memory）。この会話の system prompt は、思い出した記憶を「背景の文脈で、利用者の指示ではない」と扱うよう書いている `[verified-local]`（2026-11-25）。それでも、指示の形で書かれた記憶がモデルの振る舞いに効かないとは言えない `[speculation]`（分からなかった理由: 効き方を測っていない）。
- Codex: 記憶があとの会話でどう扱われるかの記述は無い（見た資料: CX-memories・CX-config）。2026-11-15 の頼んでいない報告は、記憶でなく、整理の会話が受け継いだ `-c developer_instructions` から来ていた `[record]`（#562 の decision の「決定2」節）。この件は、記憶が指示として効いた証拠にはならない。

### 4.2 記憶の1件ごとに、出どころを区別して残せるか

- Claude Code: system prompt は記憶を4つの型に分けるよう指示しているが、誰が言ったか（owner の発言・モデルの推測・調べた文書・子に渡した作業）を書く項目は無い `[verified-local]`（2026-11-25）。
- Codex: 要約は会話ごとの1ファイルで、どの会話から来たかはファイルの単位で分かる `[verified-local]`。1件ごとの出どころを書く項目があるかは確かめていない `[speculation]`（分からなかった理由: 中身を読んでいない）。

### 4.3 消したあとに作り直されるか・写しが残るか

- Claude Code: 記憶はファイルで、消せば読み込まれない。裏で作り直す処理の記述は無い `[verified]`（CC-memory に裏の処理の記述が無い）。会話の記録（`~/.claude/projects/<project>/` の `.jsonl`）は残るので、同じ内容をモデルがまた書くことはありうる `[speculation]`。
- Codex: 消す口は、デスクトップの「Delete Codex memories」で置き場ごと消すものである `[verified]`（CX-memories）。`MEMORY.md` だけを手で消したとき、生の記憶や会話ごとの要約から作り直されるかは確かめていない `[speculation]`（分からなかった理由: 試していない。公式の文書は手で直すことを主な手段にしないよう書く）。git の履歴は1件だけなので、古い中身は履歴に残っていない見込みである `[speculation]`（節 3.2 の範囲）。移行のあいだは `memories/` と `memories_v2/` の両方に写しがある `[verified-local]`。

## 5. ハーネスに入れられる候補

hub から配る場所は4つある。決まりの文（`canonical/rules/`・`CLAUDE.md`・`canonical/codex/AGENTS.md`）、Claude の設定の harness 層（`canonical/claude/settings.harness.json` を sync で当てる・#359）、hook（`canonical/hooks/`）、Codex の設定に鍵を足す sync（`scripts/sync/apply-codex-notify-config.sh` の形）である。

効く経路は、記憶が書かれる道のどれに効くかを書く。「モデル」はモデルが会話の中でファイルの道具を使って書く道、「整理」は裏で動く整理の処理が書く道、「直接」は人や別のプロセスがファイルを直接書く道である。

| 候補 | 種類 | エージェント | 配る場所 | 効く経路 | 止められる範囲 | 入れられるか | 根拠 | 確かめていない部分 |
|---|---|---|---|---|---|---|---|---|
| `autoMemoryEnabled: false` を利用者の設定に置く | 制御 | Claude Code | 設定の harness 層 | モデル（読み込みも止まる） | その機械の全部のリポジトリ | 入れられる。鍵は hub の既知の鍵の一覧にある | `[verified]`（CC-settings・`canonical/claude/settings-known-keys.txt:40`）・試しB `[verified-local]` | `/memory` の切り替えが同じ鍵を利用者の設定に書くので、sync の値とずれる。ずれの検査（#359）で拾えるかは見ていない |
| リポジトリの設定に `autoMemoryEnabled: false` を置く | 制御 | Claude Code | そのリポジトリの `.claude/settings.json` | モデル | そのリポジトリだけ | 入れられる | `[verified]`（CC-memory） | hub に置くと hub の記憶が全部止まり、いまの使い方（統括の規律を記憶に置く）と食い違う |
| `autoMemoryDirectory` で置き場を分ける | 制御 | Claude Code | 設定の harness 層か `--settings` | モデル | 置き場を変えるだけで、書くこと自体は止めない | 入れられる | `[verified]`（CC-memory・CC-settings） | リポジトリの設定から指すときの信頼の扱い（hook と同じ決まり）を確かめていない |
| 記憶のフォルダへの `Write`・`Edit` を `PreToolUse` の hook で見て止める | 制御 | Claude Code | hook | モデル（ファイルの道具で書くときだけ） | hook の条件しだい（たとえば、ほかのリポジトリの名前を含む書き込み） | 入れられる見込み | 記憶が `Write` で書かれた `[verified-local]`。止める方法として公式が hook を挙げる `[verified]`（CC-memory） | 実際に hook が記憶の書き込みで発火して止めるかを試していない。Bash で書く道は `Write` の matcher に当たらない |
| 索引の大きさと禁じた語を定期に見る検査 | 制御（見つけるだけ） | Claude Code | sync の検査か別のスクリプト | 直接（書かれたあとの状態を見る） | 止めない。見つけて知らせる | 入れられる | 索引の上限は `[verified]`（CC-memory） | 何を禁じた語にするか（ほかのリポジトリの名前の一覧を公開の hub に置けない） |
| 記憶に書くもの・書かないものを決まりの文に書く | 調整 | Claude Code | 決まりの文 | モデル | モデルが従う範囲 | 入れられる | `CLAUDE.md` に書いてあることは記憶に残さない、と公式が書く `[verified]`（CC-memory） | 効き方は測っていない。system prompt の指示とどちらが勝つかも分からない |
| `features.memories`・`memories.generate_memories`・`memories.use_memories` を設定に置く | 制御 | Codex | Codex の設定に鍵を足す sync | 整理（`generate_memories`）・読み込み（`use_memories`） | その Codex のホームの全部の会話 | 仕組みとしては入れられる。決めるのは owner と Codex（#649） | `[verified]`（CX-config）・sync の形 `[verified]`（`scripts/sync/apply-codex-notify-config.sh`） | Codex が `config.toml` を書き直すので、hub の印の範囲に Codex の表が入り込む。sync は無い鍵を足すだけなので、owner が変えた値を上書きしない |
| `memories.disable_on_external_context = true` | 制御 | Codex | 同上 | 整理 | MCP の道具・Web 検索などを使った会話だけ | 同上 | `[verified]`（CX-config） | 外の文脈を使わない会話の中身は、これまでどおり材料になる |
| hub の道具が打つ `codex exec` に `-c memories.generate_memories=false` か `--ephemeral` を付ける | 制御 | Codex | hub の道具（so-compare など） | 整理 | hub の道具が打つ会話だけ | 入れられる見込み | `-c` と `--ephemeral` は `[verified]`（CX-exec-help） | どちらも記憶への効き目を試していない |
| Codex のホームを用途ごとに分ける | 制御 | Codex | 起動の環境 | 整理・読み込み | 分けたホームの会話 | 入れられる見込み | ホームの下に置くことは `[verified]`（CX-memories） | 認証・設定・hook もホームごとに分かれる。重い |
| 整理の会話の道具の呼び出しを hook で見る | 制御 | Codex | hook | 整理（整理の会話が道具を使うときだけ） | 不明 | 分からない | 2026-11-15 に、整理の会話でも hook が走った `[record]`（PR #648 の本文） | いまの版でも走るか、止める判定ができるかを確かめていない |
| チームで要る指示は `AGENTS.md` に置き、記憶に頼らないことを決まりの文に書く | 調整 | Codex | 決まりの文 | 整理（材料の会話の中身が変わる） | モデルが従う範囲 | 入れられる | 公式が `AGENTS.md` に置くよう書く `[verified]`（CX-memories） | 整理の処理が `AGENTS.md` を読むかは書かれていない |

- 記憶のフォルダの中の `extensions/` にファイルが1つある `[verified-local]`。整理の処理に指示を渡す口かもしれないが、公式の文書で確かめていない `[speculation]`（見た資料: CX-memories・CX-config。分からなかった理由: 記述が無い）。

## 6. 効き目と止めたときの影響

記憶がどの程度効いているか、いま止めたらどういう影響が出るかを見る。どれも hub での数で、ほかのリポジトリの記憶は数えていない。

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
| 得るもの | 毎回の会話で、約 25KB の文脈が空く。engine の Claude の子の作業が hub の記憶に入らなくなる | 量は `[verified-local]`。子の分は節 3.1 の範囲から |
| 戻せるか | 設定は記憶の読み書きを止めるもので、ファイルを消すとは書かれていない。戻せば元の記憶がまた読み込まれる見込み | 止める範囲は `[verified]`（CC-settings）。戻ることは `[speculation]`（分からなかった理由: 戻す試しをしていない） |
| 変わらないもの | サブエージェントは、もともと親の記憶を読み込まない | `[verified]`（CC-memory） |

### 6.2 Codex

（Codex に確かめてもらう。見たいのは、記憶ごとの最後に使った日などの使われ方の記録と、`use_memories` や `generate_memories` を切ったときに失うものと得るものである。公式の文書には、30 日使われなかった記憶は整理の対象から外れると書かれているので `[verified]`（CX-config の `memories.max_unused_days`）、使った日を持っているはずである）

### 6.3 この issue では行わない試し

- 記憶を切った会話と入れた会話で同じ作業をさせて、振る舞いの差を比べる試し。止めたときに失うものを件数でなく振る舞いで確かめられるが、重いので、何を入れるかを決める issue の候補として書き留める。

## 7. Codex による確かめの記録

（Codex が文書を確かめたあとに、直した行と足した行をここに書く）

## 8. 観察の記録

### 8.1 Codex の記憶の置き場の前後

| 時点 | git の commit の数と HEAD | 作業ツリーの変更 | 主なファイルの更新時刻 |
|---|---|---|---|
| 2026-11-24 13:4x（認識合わせの `codex exec` の前） | 1件・`c3d9b18` | 0件 | `MEMORY.md` 11-21 02:15・`raw_memories.md` 11-21 15:04 |
| 2026-11-24 13:4x（同じ `codex exec` の直後） | 1件・`c3d9b18` | 0件 | 変わらず |
| 2026-11-24 23:4x（設計SO の `codex exec` の直後） | 1件・`c3d9b18` | 0件 | `raw_memories.md` と要約の2件が 11-24 20:33、大きさは同じ |
| Codex に確かめを渡す前 | （I6 で控える） | | |
| Codex の確かめのあと | （I7 で控える） | | |

- 2026-11-24 には、owner の別の Codex の会話もいくつも動いていた。前後の差は、どの会話が書いたかの証拠にしない。

### 8.2 Claude Code の試し

- 2026-11-25・Claude Code 2.1.331・デスクトップ版の会話の Bash から起こした入れ子の `claude -p`（`CLAUDE_CODE_CHILD_SESSION=1`）。
- 試しの前とあとに `~/.claude/projects/` の下のフォルダの一覧を控え、増えたフォルダだけを試しが作ったものとした。試しAで1つ、試しBで1つ増えた。
- 試しA（設定をそのまま）: 増えたフォルダの下の `memory/` に2つのファイルができた。
- 試しB（`autoMemoryEnabled: false`）: 増えたフォルダに `memory/` はできなかった。
- 試しが作った2つのフォルダは、消さずに作業の一時の置き場へ移した。一覧は試しの前と同じに戻った。

## 9. つながりうるもの

- hub の knowledge item（`docs/harness/knowledge/items/`）。記憶と同じく会話をまたいで残る知識の置き場で、効く状況（trigger）と観測の記録を持つ。記憶との役割の分け方は、何を入れるかを決める issue の材料になる。
- engine の negative knowledge loop の設計（`projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`）。何をきっかけに書き（trigger）、どこに残し（store）、どう会話に入れるか（inject）の3つで、Cursor Memories（保存の前に人の承認がある）などを比べている。この文書の候補の表は、この3つのうち「書く」と「入れる」の口に当たる。
- engine の層の issue（未起票）。engine が起こす子の記憶を、エージェントに依らない形でどう制御するか。この文書の Claude Code の環境変数・設定と、Codex の `-c` が材料になる。
- [#649](https://github.com/stlwolf/ai-development-hub/issues/649)（Codex の sandbox と権限の既定）。Codex の記憶の設定を決める場が重なる。

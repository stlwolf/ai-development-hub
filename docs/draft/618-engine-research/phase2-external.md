# Phase 2 外部状況調査メモ（2026-02 以降〜2026-11-10）

- 調査日: 2026-11-10
- 目的: tmux 上の子セッションへ委譲する自作オーケストレーションエンジンについて、「自作を続ける価値がある部分」と「既製・公式機能に任せられる部分」を判断する材料を集める
- 方法: WebSearch / WebFetch。一次情報（公式ドキュメント、リポジトリの README・Releases・コミット履歴）を優先
- 検索語・外部リクエストに利用者の個人情報やリポジトリ名は含めていない

## 0. 調査上の制約（先に読むこと）

- このセッションのネットワーク許可外で **取得できなかった一次情報サイト** がある。該当項目は検索結果の要約（二次情報）に頼っており、本文中で「二次情報」「未確認」と明記した
  - `developers.openai.com`（Codex 公式ドキュメント）
  - `cursor.com`（Cursor 公式ドキュメント・changelog）
  - `geminicli.com`（Gemini CLI 公式サイト。GitHub 上の同ドキュメントは取得できた）
  - `modelcontextprotocol.io`（MCP 仕様）
  - `agents.md`、`agentclientprotocol.com`、`a2a-protocol.org`、`gastown.dev`
- GitHub API（`gh api`）はこのセッションでは使えず、スター数などは GitHub の HTML ページから読んだ値（取得日 2026-11-10、概数）
- GitHub ページの「Releases」欄が空で取れたものが多い。最終リリースは Releases ページかコミット履歴を別途開けたものだけ日付を書き、ほかは「未確認」とした
- 一次情報として最も厚く取れたのは Claude Code 公式ドキュメント（`code.claude.com/docs`）。ここは全文を直接読んでいる

## 1. tmux + git worktree で複数エージェントを並べる系のツール

### 1.1 一覧

| ツール | 何をするか | 親子の委譲・監視 | セッション復帰 | 複数 CLI 対応 | 活発さ（2026-11-10 取得） | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| Agent of Empires (`aoe`) | tmux セッション + git worktree を束ねる TUI / Web ダッシュボード / CLI / HTTP API。Docker・Podman・Apple Containers のサンドボックス、状態検出、通知、diff レビュー | 親子委譲の記述なし（「orchestrator」はトピックタグのみ）。状態検出と通知はある | 各エージェントが tmux セッションなので TUI を閉じても SSH が切れても生存。`aoe` 再起動で表示復元。会話の resume コマンドは README に記述なし | Claude Code、OpenCode、Mistral Vibe、Codex CLI、Gemini CLI、Pi.dev、Copilot CLI、Factory Droid ほか（`aoe agents` で確認） | 約 4.0k スター、3,159 コミット、最新リリース v1.22.3（2026-11-08）。ほぼ週次でリリース。MIT。リポジトリは `agent-of-empires/agent-of-empires` に移っている | https://github.com/agent-of-empires/agent-of-empires 、https://github.com/agent-of-empires/agent-of-empires/releases |
| Claude Squad (`cs`) | tmux + worktree でエージェントごとに隔離したセッションを 1 つの TUI で管理。`-y/--autoyes`（実験的）、pause（commit して停止）/ resume | なし。独立したピアを並べるだけ | pause / resume あり。2026-08-20 に「tmux サーバーごと死んだインスタンスを復旧する」修正（#322） | Claude Code（既定）、Codex、Gemini、Aider、OpenCode、Amp。`-p` で任意のプログラム | 約 8.8k スター、222 コミット。直近コミットは 2026-08-20（v1.0.20）、その前は 2026-07-30、2026-06-17。更新頻度は低い。AGPL-3.0 | https://github.com/smtg-ai/claude-squad 、https://github.com/smtg-ai/claude-squad/commits/main |
| Gas Town (`gt`) | Go 製のマルチエージェント統括。Mayor（統括）、Polecat（作業者）、Witness（rig ごとの監視）、Deacon（横断パトロール）、Refinery（マージキュー）、Convoy（作業束）。Beads（git / Dolt 裏付けの課題台帳）に状態を置く | **あり**。Mayor が委譲、Witness が stuck 検出と回復（nudge または handoff）、Go デーモンが 3 分ごとに heartbeat、Deacon がパトロール。`gt escalate -s HIGH` で人へ段階的にエスカレーション | **あり**。hook（worktree 裏付けの永続領域）が crash / restart を越える。`gt handoff`（文脈リフレッシュ）、`gt prime`（文脈回復）、Seance（前任セッションの `.events.jsonl` を引く） | claude、gemini、codex、kiro、cursor、auggie、amp、opencode、copilot、pi、omp のプリセット | 約 18.8k スター、7,779 コミット、issue 394 / PR 129。最新リリース v1.2.1（6 月 6 日。年はページに無いが v1.x 系列と前後関係から 2026 年と読める）。MIT。リポジトリは `gastownhall/gastown` | https://github.com/gastownhall/gastown 、https://github.com/gastownhall/gastown/releases |
| CCManager | 複数 worktree / プロジェクトをまたぐセッション管理 CLI。**tmux を使わず PTY で自前管理**。状態検出（Idle / Busy / Waiting）、状態変化フック、Haiku による自動承認（実験的）、devcontainer 連携 | なし。並べて監視するのみ | 再起動後にセッションを復元（コマンドの再実行であり会話の復元ではない）。Claude Code のセッションデータを worktree 間でコピー可 | Claude Code、Gemini CLI、Codex CLI、Cursor Agent、Copilot CLI、Cline CLI、OpenCode、Kimi、MiniMax、Grok Build | 約 1.3k スター、788 コミット。最終リリース日は未確認。MIT | https://github.com/kbwo/ccmanager |
| uzi | tmux + worktree で同一プロンプトを多数エージェントへ。`uzi prompt --agents claude:3,codex:2`、`broadcast`、`checkpoint`（rebase して取り込み）、`auto`（確認プロンプト自動応答） | 一斉投入と一斉送信のみ。親子・監視はなし | 記述なし | claude、codex、aider、cursor ほか任意 CLI | 583 スター、63 コミット。最終コミット日は未確認（小規模で停滞気味に見えるが断定できない）。MIT | https://github.com/devflowinc/uzi |
| container-use | MCP サーバー（CLI としても可）。エージェントごとにコンテナ環境 + git ブランチを与える（Dagger 製） | なし（隔離環境の提供のみ） | 記述なし | Claude Code、Cursor、Goose、VS Code ほか MCP 対応なら可 | 約 4.1k スター、331 コミット。README に「early development」「stability-experimental」。最終リリース日は未確認。Apache-2.0 | https://github.com/dagger/container-use |
| cmux | Ghostty ベースの macOS ネイティブ端末。エージェントが注意を要するとペインに青リング・通知パネル。**CLI と Unix ソケット API でエージェント自身がペイン分割・入力送信・画面読取り** 。`cmux claude-teams` で Claude Code の teammate を tmux の代わりにネイティブ分割へ | 委譲の仕組み自体はなく、エージェントに制御 API を渡す形 | レイアウト・cwd・スクロールバック（best effort）を復元 | 任意の CLI（端末なので） | 約 28.7k スター。GPL-3.0-or-later（サーバー部は BSL 1.1）。macOS のみ。最終リリース日は未確認 | https://github.com/manaflow-ai/cmux |
| herdr | 「tmux をエージェント向けに作り直した」単一 Rust バイナリ。各エージェントに実端末、サイドバーに blocked / working / done / idle。バックグラウンドサーバーで detach 後も生存。ローカル Unix ソケット + CLI でエージェントがワークスペース作成・ペイン操作・出力読取り・**状態変化の購読** | 「エージェントが helper を spawn して herdr をソケット API 経由で操る」と明記。hook 不要の状態検出（プロセス名 + 出力ヒューリスティック） | detach / reattach、SSH 越しも可 | Pi、Claude Code、Codex、Droid、Amp、OpenCode、Cursor Agent、Copilot CLI ほか多数（Gemini CLI は「検出するが未検証」） | 本家のスター数は未確認（開けたのはフォーク）。AGPL-3.0-or-later + 商用ライセンス。Linux / macOS、Windows はベータ | https://github.com/Suor/herdr （`herdrdev/herdr` のフォーク） |
| Conductor | macOS アプリ。Claude Code / Codex / Cursor を worktree で並列、自動コードレビュー | 未確認 | 未確認 | Claude Code、Codex、Cursor（二次情報） | プロプライエタリ。稼働中（二次情報）。公式ページは未取得 | https://www.morphllm.com/comparisons/superset-vs-conductor-vs-emdash （二次情報） |
| Superset | エージェント非依存のワークスペース。バックグラウンドデーモンがセッションを保持し、アプリ再起動を越える | 未確認 | デーモン保持（二次情報、ベンダー自身の比較ページ） | テキスト入出力の CLI なら可（二次情報） | 未確認 | https://superset.sh/compare/conductor-alternative （ベンダーの比較ページ） |

### 1.2 除外・注意（停止または縮退）

- **Vibe Kanban**: README 冒頭に「Vibe Kanban is sunsetting.」と明記。約 28.6k スター、Apache-2.0。二次情報では運営会社が 2026-04 に停止しコミュニティ保守へ移行。新規採用の対象から外す
  - https://github.com/BloopAI/vibe-kanban
  - https://agentsroom.dev/blog/best-multi-agent-coding-tools （二次情報）
- **Crystal**: README に「2026-02 で deprecated、後継は Nimbalyst」と明記（約 3.1k スター、MIT）。二次情報では Nimbalyst は有償のクローズドソース
  - https://github.com/stravu/crystal
- **Gas City**: 二次情報では Gas Town の後継 SDK として 2026-04-24 に発表。一次情報は未取得（`gastown.dev` が許可外）。Gas Town 本体のリリースが 6 月 6 日の v1.2.1 で止まって見える点と合わせ、開発の重心が移った可能性があるが **未確認**

### 1.3 この群から読めること

- 「tmux + worktree で並べて状態を見る」層は完全にコモディティ化した。AoE（週次リリース）、Claude Squad、CCManager、cmux、herdr が状態検出・通知・復元まで揃えている
- 一方で **親子の委譲・監視・世代交代まで持つのは Gas Town だけ**。ほかは「人が各セッションを操る前提の並列ランチャー」
- cmux と herdr は「エージェント自身が叩けるソケット API」を出しており、`tmux send-keys` + `capture-pane` による自前の送受信の代替候補になる。herdr は状態変化の購読（subscribe）を持つ
- CCManager が Claude Code 起動時に `--teammate-mode in-process` を注入している、cmux が `claude-teams` を持つ、など **各ツールが Claude Code 公式の agent teams と衝突しないよう追従している**。公式機能が土台を動かしている証拠

## 2. Claude Code 公式のマルチエージェント機能の現状

出典はすべて Claude Code 公式ドキュメント。最新版は v2.1.322（2026-11-10）。

- https://code.claude.com/docs/en/agents （並列手段の比較）
- https://code.claude.com/docs/en/whats-new （週次ダイジェスト。Week 13 = 2026-03-23 以降のみ掲載）
- https://code.claude.com/docs/en/changelog

### 2.1 2026-02 以降に加わったもの（時系列）

| 時期 | 機能 | 状態 | 出典 |
| --- | --- | --- | --- |
| 2026-02 頃 | Agent teams（lead + teammates、共有タスクリスト、mailbox、tmux / iTerm2 分割ペイン）。v2.1.32 以降とする記述は二次情報、公開日は未確認 | **実験的・既定で無効**（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`） | https://code.claude.com/docs/en/agent-teams |
| 2026-03-23 週（Week 13） | Auto mode（分類器が許可判断）、条件付き `if` フック | research preview として登場、2026-08-14 から Pro / Max / Team の新規セッションで既定 | https://code.claude.com/docs/en/whats-new |
| 2026-04-06 週（Week 15） | Monitor ツール（バックグラウンドのイベントを会話へ流す）、`/loop` の自己ペース | 提供中 | 同上 |
| 2026-04-13 週（Week 16） | Routines（クラウドのスケジュール実行。現在の名称は cloud scheduled tasks）、モバイル push 通知 | research preview | https://code.claude.com/docs/en/routines |
| 2026-05-11 週（Week 20） | **Agent view**（`claude agents`、`claude --bg`、バックグラウンドセッション、supervisor）。v2.1.139 で導入 | research preview | https://code.claude.com/docs/en/agent-view |
| 2026-05-25 週（Week 22） | **Dynamic workflows**（Claude が書いた JS スクリプトが数十〜数百の subagent を統括）、`ultracode` | 全有料プランで提供 | https://code.claude.com/docs/en/workflows |
| 2026-06-08 週（Week 24） | subagent が subagent を spawn 可能（ネスト） | 提供中。現行ドキュメントでは既定で 3 層まで | https://code.claude.com/docs/en/sub-agents |
| 2026-06-29 週（Week 27） | subagent が既定でバックグラウンド実行 | 提供中 | https://code.claude.com/docs/en/whats-new |
| 2026-07-13 週（Week 29） | `/fork`（会話を新しいバックグラウンドセッションへコピー） | 提供中 | 同上 |
| 2026-08-03 週（Week 32） | **Cross-session messaging**（`SendMessage` / `ListAgents` で自分の別セッションへ送信）。v2.1.224 以降 | 既定で有効（macOS / Linux。Windows は v2.1.234 以降） | https://code.claude.com/docs/en/cross-session-messaging |
| 2026-08-10 週（Week 33） | fork mode 既定化、`@セッション名` メンション | 提供中 | https://code.claude.com/docs/en/whats-new |
| 時期未確認 | **Projects**（1 本の継続会話が thread = クラウドセッションを起こして束ねる。Remote Control 経由でローカル実行も可） | public beta（Pro / Max / Ultra、段階展開。Team / Enterprise は未提供） | https://code.claude.com/docs/en/claude-projects |
| 時期未確認 | Channels（MCP サーバーが実行中セッションへイベントを push。Telegram / Discord / iMessage、権限プロンプトの中継） | research preview | https://code.claude.com/docs/en/channels |
| 時期未確認 | Mods（ペイン・コマンド・ツール呼び出しルールを足す拡張。「他セッションへメッセージ」も API にある） | 提供中 | https://code.claude.com/docs/llms.txt |

### 2.2 自作エンジンに直接関係する仕様の要点

#### Cross-session messaging（セッション間メッセージ）

- 同一マシンでは **セッションごとの Unix ドメインソケット** で配送し、Anthropic のサーバーを通らない。他マシン・クラウドセッションへは Remote Control 経由
- 配送タイミング: 受信側が稼働中なら **ツール呼び出しの合間** に読む。アイドルなら **新しいターンを開始** する。`tmux send-keys` でプロンプトに打ち込む方式が抱える「入力欄の状態に依存する」問題が無い
- 配送結果は Delivered / Held / Refused の 3 つ。送信側の `SendMessage` 結果に `Not sent` と理由が返る場合がある。ただし **「受信側が内容を読んで受領した」という応用レベルの ACK は仕様に無い**（配送層の結果まで）
- `notify_when_idle`: 相手セッションが次にアイドルになるか終了したときに 1 回だけ通知を受ける。購読は相手側でトークンを使わない。12 時間で失効。**メイン会話の Claude だけが、同一マシンのセッションに対して** 購読できる
- **ソケットはスクリプトやフックからも投函できる**。パスは `/status` の `Peer address` 行と、環境変数 `CLAUDE_CODE_MESSAGING_SOCKET`（フック・Bash に export）。トークンは `CLAUDE_CODE_MESSAGING_TOKEN`。`{"type":"auth","token":"<token>"}` を 1 行目に送る（macOS / Linux では任意）
  - macOS では「投函したプロセスが既に終了していると自セッションの子と検証できない」ため、トークン付き auth 行が検証手段になる、と明記されている。**macOS で Bash から叩く場合に効く注意点**
- 受信メッセージは「利用者ではなく別セッションから来た」と受信側 Claude に伝えられ、権限プロンプトへの同意にはならず、設定変更の指示にも従わない。`/compact` などのコマンドは文字列として届くだけで実行されない
- `claude -p` の非対話セッションもソケットを bind する（bare mode は除く）。無人で受けるには `--settings` で `crossSessionInbound: "accept"`
- 制限: プレーンテキストのみ、約 100 万文字上限、バースト拒否、ループ抑止（送信者ごとのレート制限、最大 50 件キュー）、保留は最大 100 件
- コンテナ内とホストのセッションは互いに届かない

#### Agent view とバックグラウンドセッション（生存監視・復帰・cockpit）

- `claude agents` が 1 画面で全バックグラウンドセッションを表示。状態は Working / Needs input / Idle / Completed / Failed / Stopped。グループは Pinned / Ready for review / Needs input / Working / Completed
- **supervisor プロセス** が各セッションを別プロセスとして保持。予期せず終了したセッションは supervisor が再起動する。応答しなくなったセッションはプロセスを再起動して中断した応答を続ける
- 1 時間ほど未接続で待機中のセッションはプロセスを止めて資源を解放（会話はディスクに残り、接続か返信で再開）。`Ctrl+T` でピン留めすると止まらない
- スリープは越える。**シャットダウン・再起動では止まる**。入力待ちだったものは Needs input に残り、それ以外は 48 時間以内なら Failed、超えると Stopped として表示され、保存済み会話から再開できる
- supervisor 自体が止まると、約 1 分以内に新しい supervisor が接続しない限りセッションも止まる
- 状態は `~/.claude/daemon/roster.json`、`~/.claude/jobs/<id>/state.json` にあるが **安定インターフェースではない** と明記。機械可読には `claude agents --json` を使う
- 編集前にセッションを `.claude/worktrees/` 配下の worktree へ自動で移す。完了時は commit・push・draft PR まで行い、`main` への push や force-push はしない
- Peek（`Space`）で質問・結果・状況を見て、その場で返信できる。権限プロンプトは attach して答える
- 通知: Needs input / 完了 / 失敗で端末通知。`Notification` フックが `agent_needs_input` / `agent_completed` で発火
- シェルから `claude attach` / `logs` / `stop` / `respawn` / `rm`、`claude daemon status`
- 制限: research preview、セッションはローカル、10 並列なら枠を約 10 倍の速さで消費

#### Agent teams

- lead がチームを作り、teammate は独立した Claude Code セッション。mailbox は `~/.claude/teams/{team-name}/inboxes/{agent-name}.json`。**書き込みが成功したときだけ「送信済み」と報告** し、失敗時は送信側にエラー
- タスクの claim はファイルロックで競合回避。teammate がアイドルになると lead へ自動通知（最終回答つき）。API エラーで終わった場合は失敗として通知
- フック: `TeammateIdle`、`TaskCreated`、`TaskCompleted`（exit 2 で差し戻し）
- 明記されている制限（自作エンジンとの差がここに出る）
  - **in-process teammate は `/resume` / `/rewind` で復元されない**
  - **1 セッション 1 チーム**、セッションをまたいで共有できない
  - **ネスト不可**（teammate は teammate を spawn できない）
  - **Lead is fixed**（teammate を lead に昇格できず、leadership を移譲できない）
  - タスク状態が遅れることがある、shutdown が遅い
  - 分割ペインは tmux か iTerm2 が必要。VS Code 統合ターミナル、Windows Terminal、Ghostty は非対応（WezTerm は記載なし = 未確認）
  - teammate は worktree で隔離されない（ファイルの担当分けが必要）
  - `-p` や Agent SDK のセッションは teammate を spawn しない

#### Subagents

- 既定でバックグラウンド。`isolation: worktree`、`memory`（user / project / local の永続ディレクトリ）、`autoCompactWindow`（v2.1.296 以降）、`background`、`maxTurns`、`permissionMode`、`hooks` などの frontmatter
- 完了した subagent へ `SendMessage` で再開でき、履歴を保つ。トランスクリプトは `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl` にあり、**メイン会話の compaction の影響を受けない**
- ネストは既定で 3 層まで（`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`）

#### Dynamic workflows

- Claude が書く JavaScript スクリプトが `agent()` / `pipeline()` / `parallel()` で subagent を統括。**中間結果はスクリプト変数に置かれ、Claude の文脈には最終結果しか入らない**
- 同時 16 エージェント（1〜256 に変更可）、1 回 1,000 エージェントまで、`parallel()` は 4,096 項目まで
- 停滞したエージェントは同じプロンプトで自動再起動（最大 5 回）。停止・失敗後は保存結果から再開（完了分はキャッシュを返す）
- **実行途中の利用者入力は不可**。段階ごとの承認が要るなら段階ごとに別 workflow にする、と明記
- `Date.now()` / `Math.random()` はスクリプト内で例外になる（再実行の決定性のため）

#### Worktrees と Hooks

- `claude --worktree`、`.worktreeinclude`、`worktree.baseRef`、`WorktreeCreate` / `WorktreeRemove` フック（git 以外の VCS 用）。実行中は `git worktree lock` を保持
- フックイベントは 33 種に増えた。自作エンジンに効きそうなもの: `SessionStart`、`SessionEnd`、`Stop`、**`StopFailure`**（API エラーでターン終了）、`SubagentStart` / `SubagentStop`、`TeammateIdle`、`TaskCreated` / `TaskCompleted`、`PreCompact` / **`PostCompact`**、`Notification`、`PermissionRequest` / `PermissionDenied`、`FileChanged`、`CwdChanged`、`ConfigChange`、`InstructionsLoaded`
- ハンドラ種別は command / http / mcp_tool / prompt / agent（agent は実験的）。command は `"async": true` と **`"asyncRewake": true`**（バックグラウンドで走り、exit 2 で Claude を起こす）を持つ
  - https://code.claude.com/docs/en/hooks

#### Projects（クラウド側の「統括」）

- 1 本の継続会話が thread（通常はクラウドセッション）を起こす。「Waiting on you」で人の判断待ちを一覧
- 文脈の扱いが明記されている: 「You don't manage context windows in a project. Threads compact automatically, and the conversation works from recent messages, recent threads, and project memory rather than its full history, so it keeps going for as long as the project runs.」
- thread への承認はその thread の中で答える必要があり、project 会話で「進めてよい」と言っても届かない
- 1 日 500 thread の上限。プラン枠を速く消費する

### 2.3 「tmux で自前の親子委譲を組む必要」はどこまで減ったか

- **減った部分（子が Claude Code である限り）**
  - 送信: `SendMessage` がソケット経由で届き、アイドルなら起こし、稼働中ならツールの合間に読ませる。配送の成否も返る
  - 生存監視と再起動: supervisor が担う。状態は `claude agents --json` で取れる
  - 完了通知: `notify_when_idle`、`Notification` フック、teammate の idle 通知
  - worktree 隔離とクリーンアップ: 公式が担う
  - cockpit: agent view
- **減っていない部分**
  - 子が Codex など他 CLI の場合。公式は「In every approach the workers are Claude sessions. To involve a different tool, expose it to Claude as an MCP server.」と明記
  - 統括の世代交代。agent teams は「Lead is fixed」。ローカルでは公式の解がない
  - 任意の親子木の登記（agent teams はネスト不可・1 セッション 1 チーム、cross-session messaging は平坦なピア）
  - マシン再起動をまたぐ自動復帰（agent view は停止し、手動再開）
  - 応用レベルの受領確認
- **注意**: agent view は research preview、agent teams は実験的、Projects は public beta、channels と cloud scheduled tasks は research preview。仕様とキー操作は変わりうると各ページに書かれている。agent view の内部ファイルは「安定インターフェースではない」

## 3. 他社 CLI の公式マルチエージェント機能

### 3.1 OpenAI Codex CLI

- 一次情報として取れたのは GitHub のリポジトリと Releases のみ。公式ドキュメント（`developers.openai.com`）は取得不可
- リポジトリは約 134.6k スター。最新リリース **0.167.0（2026-11-06）**。プレリリース 0.169.0-alpha.7（2026-11-09）
  - https://github.com/openai/codex 、https://github.com/openai/codex/releases
- 0.167.0 のリリースノートから確認できたこと
  - `codex agents --no-daemon` で **agent command center** が開く（#58238、#58239）
  - subagent の親子関係を子ストレージ作成前に保存（#58129）、ホスト管理の子起動に親の文脈を渡す（#58390）
  - PreToolUse フックが Guardian のレビュー方針チェックの前に走る（#58368）。フック機構が存在する
  - resume ピッカーの改善（#57862、#58280）
  - **「message-board tools」の MCP アダプタ追加（#58341）**。エージェント間の掲示板的な連絡手段に見えるが詳細は未確認
  - 自動 compaction の改善（#58404）
- 二次情報（公式ドキュメントの検索要約）
  - subagent は `.codex/agents/` の TOML で定義、`[agents]` に `max_threads`（既定 6）、`max_depth`（既定 1）。`/agent` でスレッド切替
  - 「現行リリースでは既定で有効」とするページと「実験的で明示有効化が必要」とするページがあり **矛盾**。キー名が `max_concurrent_threads_per_session` に変わったとする記事（2026-10 時点の版に基づくと称する）もあるが未確認
  - https://developers.openai.com/codex/subagents （未取得）、https://developers.openai.com/codex/multi-agent （未取得）
- Codex app（デスクトップ）: 2026-02-02 に macOS 版、2026-03-04 に Windows 版。スレッドごとの worktree、クラウドタスク、automations。いずれも二次情報
  - https://openai.com/index/introducing-the-codex-app/ （未取得）

### 3.2 Cursor（CLI / cloud agents）

- 公式ドキュメント・changelog は取得不可。以下はすべて二次情報で、版数と日付は出典間で揺れがある
  - 非同期 subagent（2026-02 頃）、subagent のネスト
  - Cursor 3.2（2026-04-24）で Agents Window に `/multitask`、バックグラウンドエージェントが worktree で隔離
  - CLI に `-w` / `--worktree`
  - cloud agents（旧 background agents）。`/in-cloud` でクラウド subagent、`/babysit` で PR 準備。GitHub / Slack / Linear / タイマーのイベントを待って同じ会話で再開（最長 180 日とする記事あり）
  - CLI の jobs 一覧に実行中の作業・subagent が出る（2026-06-26 のミラー）
  - https://cursor.com/docs/cli/changelog.md （未取得）、https://www.dsebastien.net/cursors-last-six-months-from-editor-to-agent-workspace/ （二次情報）

### 3.3 Gemini CLI

- GitHub 上の公式ドキュメントを取得できた
  - https://github.com/google-gemini/gemini-cli/blob/main/docs/core/subagents.md
- subagent は `.gemini/agents/*.md`（YAML frontmatter）。`experimental.enableAgents` の下にあるが「Subagents are enabled by default.」
- 組み込み: `codebase_investigator`、`cli_help`、`generalist`、`browser_agent`（既定で無効）
- 「Each subagent runs in its own isolated context loop.」
- **subagent は他の subagent を呼べない**（ネスト不可）
- 並列実行についての記述はこのページに無い（未確認）
- **remote subagents**: 「Gemini CLI can also delegate tasks to remote subagents using the Agent-to-Agent (A2A) protocol.」。二次情報では `agent_card_url` を指定し、実験的設定で有効化
- 二次情報では subagent の発表は 2026-04-15

### 3.4 この群から読めること

- 3 社とも「1 セッション内の subagent」は標準装備になった。worktree 隔離とクラウド実行も揃いつつある
- **どの公式機能も自社エージェント同士の委譲に閉じている**。Claude が Codex を、Codex が Claude を子として監視する公式の道は、MCP サーバーとして相手を露出する方法か、A2A（Gemini のみ明記）に限られる
- 自作エンジンの「将来は Codex なども子に」という方針は、公式機能では代替されない領域のまま

## 4. プロトコル・共通化の動き

| 動き | 現状 | 自作エンジンへの含意 | 根拠 |
| --- | --- | --- | --- |
| A2A（Agent2Agent） | Linux Foundation 傘下。2026-04-09 の LF 発表で 150 超の組織が支持。v1.0 の時期は 2026-03-12 とする記事と 2026-04 とする記事があり未確認。2026-08 に Agentic AI Foundation の Growth Stage になったとする記事あり（未確認） | Task のライフサイクル（input-required を含む）と Agent Card の考え方は「登記」「判断待ち」の語彙として参考になる。ただし HTTP サーバー前提で、ローカルの tmux ペイン間には重い。実装済みのコーディング CLI は Gemini CLI の remote subagents のみ確認 | https://linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year （検索結果経由）、仕様サイトは未取得 |
| MCP 2026-07-28 版 | 2026-07-28 に確定。プロトコルレベルのセッションを廃して stateless 化、Tasks（長時間処理）、MCP Apps、OAuth 整合の強化、とする記事多数。一次の仕様ページは未取得 | 「他 CLI を MCP サーバーとして露出して子にする」道の土台。Tasks が長時間委譲の標準的な受け皿になる可能性。Claude Code 側は「v2 クライアントランタイムで 2026-07-28 をネゴシエートする channel サーバーは登録しない」と書いており、移行期の非互換がある | https://modelcontextprotocol.io/specification/2026-07-28 （未取得）、https://code.claude.com/docs/en/channels |
| ACP（Agent Client Protocol） | エディタ ↔ エージェントの標準。二次情報では Registry が 2026-03-09 に stable、session resume が 2026-04-22 に安定化、25 超のエージェントが対応（2026-03 時点）。AoE のリリースノートに「acp switch-account」が出ており、並列ランチャー側も使い始めている | 端末の画面を読む代わりに **構造化されたセッション制御（一覧・再開・入力）** を得る経路になりうる。Codex などを子にするとき、`tmux capture-pane` のヒューリスティックより堅い可能性。各 CLI の対応状況は未確認 | https://agentclientprotocol.com/updates.md （未取得）、https://github.com/agent-of-empires/agent-of-empires/releases |
| AGENTS.md | 2025-12-09 に Linux Foundation が Agentic AI Foundation を設立し、MCP、goose と並ぶ創設プロジェクト。採用数は 4 万とする記事と 6 万超とする記事があり未確認 | Claude Code 公式ドキュメント索引に「Persistent instructions via CLAUDE.md or AGENTS.md」とある。子が異種 CLI でも共通の指示書を 1 つにできる | https://code.claude.com/docs/llms.txt 、https://aaif.io/news/linux-foundation-announces-formation-of-aaif （検索結果経由） |
| Claude Code のソケット投函 | 公式仕様として文書化済み（2.2 参照） | 標準プロトコルではないが、Claude Code を子にする限り最も直接的な送信経路 | https://code.claude.com/docs/en/cross-session-messaging |

## 5. 長時間統括の文脈膨張・世代交代・判断待ちの見せ方

### 5.1 文脈が膨らむ問題

- **Claude Code Projects**: 統括会話は全履歴ではなく「recent messages, recent threads, and project memory」から動く。捨てたくないものは project memory（`MEMORY.md` を索引とするファイル群）へ置く。thread は自動 compaction。**世代交代を起こさず、統括の文脈を構造的に小さく保つ** 設計
  - https://code.claude.com/docs/en/claude-projects
- **Dynamic workflows**: 計画をスクリプトへ移し、中間結果をスクリプト変数に置く。「Claude's context holds only the final answer」
  - https://code.claude.com/docs/en/workflows
- **Subagents**: トランスクリプトがメイン会話と独立。`autoCompactWindow` で subagent ごとに compaction の窓を下げられる
- **アイドル compaction**: 20 万トークン以上の会話を放置すると要約される（v2.1.314、VS Code と Desktop）。`PreCompact` / `PostCompact` フックで前後に処理を挟める
  - https://code.claude.com/docs/en/changelog
- **Anthropic Engineering「Harness design for long-running application development」**（二次情報では 2026-03-24）: compaction だけでは足りず、**文脈をリセットして新しいエージェントを起こし、構造化した成果物で引き継ぐ** 方式を採ったとされる。生成役と評価役を分ける。モデル更新後に部品を 1 つずつ外して「まだ効いているか」を確かめ、ハーネスを簡素化した、とも報じられている。本文は未取得
  - https://anthropic.com/engineering/harness-design-long-running-apps （未取得）、https://infoq.com/news/2026/04/anthropic-three-agent-harness-ai/ （二次情報）

### 5.2 世代交代・引き継ぎ

- **公式（ローカル）には無い**。agent teams は「Lead is fixed: the main session is the lead for its lifetime. You can't promote a teammate to lead or transfer leadership.」
- `/fork` は会話を丸ごと新しいバックグラウンドセッションへコピーするもので、文脈を軽くする世代交代ではない
- **Gas Town**: `gt handoff` で新しいセッションへ切り替え、hook に留めた作業と handoff mail で続行。Seance で前任の判断を引く。Witness が stuck を見て「nudge or handoff」を起こす。v1.2.1 のリリースノートに「handoff の respawn がプリセット環境を完全にマージ」「handoff の前に hook された mail bead を閉じる」とあり、現役で保守されている
  - nudge はセッションが死ぬと失われ、mail はセッションの死を越える、という使い分けは二次情報
  - https://github.com/gastownhall/gastown 、https://github.com/gastownhall/gastown/releases
- **lease（統括が同時に 1 つであることの排他）** に相当する公開実装は見当たらなかった。Claude Code は worktree に `git worktree lock`、タスクの claim にファイルロック、supervisor に `daemon.lock` を使うが、いずれも「統括の座」の排他ではない。Codex 0.167.0 の「per-chat leases」は共有 MCP 接続の話で別物
- コミュニティの実践は「handoff 文書を書いて新セッションを起こす」「進捗ファイルと git コミットをチェックポイントにする」に収束している（二次情報）
  - https://mer.vin/2026/04/managing-handoffs-in-multi-agent-coding-sessions-fresh-context-without-losing-continuity/ 、https://zylos.ai/research/2026-08-31-context-rotation-session-handoff-long-running-agents

### 5.3 人の判断待ちの見せ方

- **Agent view**: 「Needs input」グループ、行に状態語と分類器が書いた見出し、Peek で質問そのものを表示して返信。通常セッションのフッターに `← 2 agents` のように待ち件数。端末タブのタイトルにも件数
- **Projects**: Overview の「Waiting on you」。デスクトップ通知。thread の承認はその thread 内で
- **モバイル push 通知**（2026-04）、**Channels の権限中継**（Telegram などから承認・拒否）
- **cross-session messaging の Held**: 保留されたメッセージは承認ダイアログになり、バックグラウンドセッションなら agent view の Needs input 行に「approve message from」と出る
- **Gas Town**: `gt escalate -s HIGH`、重大度（CRITICAL / HIGH / MEDIUM）で Deacon → Mayor → Overseer（人）へ段階的に上げる。`gt feed --problems` が GUPP Violation / Stalled / Zombie / Working / Idle に分類
- **cmux / herdr / AoE / CCManager**: 「注意が要るペイン」を色・通知・サイドバーで示す
- 共通点は **「どのセッションが止まっているか」を並べる** ところまで。「統括が判断事項を整理し、選択肢と根拠を付けて 1 枚にまとめる」ものは見当たらなかった（Gas Town の escalation が最も近いが、選択肢提示ではなく課題の起票）

## 6. 自作エンジンの機能ごとの対照表

判定は「ある / 部分的にある / 見当たらない」。「ある」は同等の働きを外に任せられる水準、「部分的」は条件付き（Claude Code 限定、実験的、粒度が違う等）。

| 自作エンジンの機能 | 外の同等物 | 判定 | 何が足り、何が足りないか | 根拠 URL |
| --- | --- | --- | --- | --- |
| 委譲と送受信（受領確認つき） | Claude Code cross-session messaging（`SendMessage` / `ListAgents`、ソケット投函）、agent teams の mailbox、subagents、Gas Town の mail / nudge、cmux・herdr のソケット API | **部分的にある** | 子が Claude Code なら配送・アイドル起床・配送結果（Delivered / Held / Refused、`Not sent`）まで公式で足りる。足りないのは (1) 受信側が読んで受領したという応用レベルの ACK、(2) Codex など他 CLI への送信（公式は MCP 経由のみ） | https://code.claude.com/docs/en/cross-session-messaging 、https://code.claude.com/docs/en/agent-teams 、https://code.claude.com/docs/en/agents 、https://github.com/gastownhall/gastown |
| 登記と木構造 | agent view の roster（`claude agents --json`）、agent teams の `config.json` の `members`、subagent の 3 層ネスト、Codex の subagent 親子関係保存、Gas Town の役割階層 | **部分的にある** | 「誰が生きているか」の一覧は公式にある。任意の深さの親子木をセッションをまたいで登記するものは無い（agent teams はネスト不可・1 セッション 1 チーム、cross-session messaging は平坦）。Gas Town は階層を持つが役割が固定 | https://code.claude.com/docs/en/agent-view 、https://code.claude.com/docs/en/agent-teams 、https://code.claude.com/docs/en/sub-agents 、https://github.com/openai/codex/releases |
| 生存監視 | agent view の supervisor（異常終了の再起動、状態 6 種）、workflows の停滞検出と自動再試行、`notify_when_idle`、`Notification` / `StopFailure` フック、Gas Town の Witness / Deacon / 3 分 heartbeat、AoE・CCManager・herdr の状態検出 | **ある**（Claude Code の子に限る） | Claude Code の子は公式で足りる。他 CLI の子は herdr・AoE・CCManager の画面ヒューリスティックか Gas Town。supervisor 自体が止まると約 1 分で子も止まる点は要注意 | https://code.claude.com/docs/en/agent-view 、https://code.claude.com/docs/en/workflows 、https://code.claude.com/docs/en/hooks 、https://github.com/gastownhall/gastown |
| 世代交代と lease | Gas Town の `gt handoff` / Seance、Claude Code Projects（世代交代を不要にする文脈設計、クラウド・ベータ） | **見当たらない**（lease）／**部分的にある**（handoff） | 公式ローカル機能は「Lead is fixed」と明記。統括の座の排他（lease）は公開実装を確認できず。handoff の実践は Gas Town と handoff 文書方式のみ | https://code.claude.com/docs/en/agent-teams 、https://code.claude.com/docs/en/claude-projects 、https://github.com/gastownhall/gastown/releases |
| 復帰（障害から） | agent view（スリープ越え、異常終了の再起動、保存会話からの再開、`claude respawn`）、workflows の再開、worktree セッションの resume、Gas Town の hook と recovery、Claude Squad の tmux サーバー死からの復旧 | **部分的にある** | 個々のセッションの復帰は公式で足りる。足りないのは (1) マシン再起動後の自動再開（Failed / Stopped 表示から手動）、(2) agent teams の in-process teammate は復元不可、(3) 統括と子の関係ごとの復元 | https://code.claude.com/docs/en/agent-view 、https://code.claude.com/docs/en/workflows 、https://code.claude.com/docs/en/worktrees 、https://github.com/smtg-ai/claude-squad/commits/main |
| レビューのセカンドオピニオン | Claude Code の `/code-review`（バックグラウンド subagent）、`/ultrareview`（クラウドのバグ探索エージェント群）、workflows の相互検証、agent teams の並列レビュー、Conductor の自動レビュー（二次情報） | **部分的にある** | 同一モデル系での多視点レビューは公式で足りる。**別ベンダーのモデル（Codex）に見せる** 仕組みは公式に無い（MCP で露出する必要がある） | https://code.claude.com/docs/en/whats-new 、https://code.claude.com/docs/en/workflows 、https://code.claude.com/docs/en/agents |
| cockpit 表示 | agent view、`/tasks`、`/workflows`、Desktop、Projects の Overview、AoE（TUI + Web）、cmux、herdr、Gas Town の `gt dashboard` / `gt feed`、Codex の `codex agents`、Cursor の Agents Window（二次情報） | **ある** | 最も代替しやすい。自作の価値が残るとすれば、木構造や lease など自作固有の状態を映す部分だけ | https://code.claude.com/docs/en/agent-view 、https://github.com/agent-of-empires/agent-of-empires 、https://github.com/manaflow-ai/cmux 、https://github.com/gastownhall/gastown |
| 判断ボード | agent view の Needs input + Peek、Projects の「Waiting on you」、モバイル push、channels の権限中継、Gas Town の `gt escalate` | **部分的にある** | 「誰が人を待っているか」の一覧と個別返信は公式にある。**統括が判断事項を選択肢・根拠つきで 1 枚に整理して出す** ものは見当たらない | https://code.claude.com/docs/en/agent-view 、https://code.claude.com/docs/en/claude-projects 、https://code.claude.com/docs/en/channels 、https://github.com/gastownhall/gastown |

## 7. 判断材料としてのまとめ

### 7.1 既製・公式へ寄せやすい部分

- cockpit 表示（agent view や AoE などで足りる）
- Claude Code の子の生存監視と再起動（supervisor）
- Claude Code の子への送信（ソケット投函は `tmux send-keys` より状態依存が少ない。Bash から叩ける）
- worktree の作成・隔離・掃除
- 完了・入力待ちの検知（`notify_when_idle`、`Notification` フック、`claude agents --json`）

### 7.2 自作の価値が残る部分

- 統括の世代交代と lease（公式は lead 固定。Gas Town 以外に同等物なし）
- 異種 CLI（Codex など）を子にする委譲・監視と、別ベンダーモデルによるセカンドオピニオン
- 任意の親子木の登記
- 判断ボード（選択肢・根拠つきの整理）
- 応用レベルの受領確認
- マシン再起動後の関係ごとの復帰

### 7.3 リスクと留意点

- 公式側の該当機能はほぼ全部が preview 段階（agent view = research preview、agent teams = 実験的、Projects = public beta）。agent view は 2026-05 の導入から半年で約 60 版の仕様変更が版履歴に並ぶ。**土台として依存するなら `claude agents --json` や文書化されたソケットなど、公開された接点に限る** のが安全
- 並列セッションはプラン枠を並列数に比例して消費する（公式に明記）
- 自作エンジンが hook に依存している点は、hook イベントが 33 種に増え `asyncRewake` も加わったことで、むしろ選択肢が広がっている
- Anthropic 自身が「モデル更新のたびにハーネスの部品を外して、まだ効いているか確かめる」姿勢を取っていると報じられている（二次情報）。自作部分にも同じ棚卸しが当てはまる

### 7.4 未確認事項（追加調査の候補）

- Codex 公式ドキュメントの現行の subagent 仕様（既定有効か、設定キー名、`codex agents` の中身、message-board tools）
- Cursor CLI / cloud agents の現行仕様（すべて二次情報）
- Gas City の実体と Gas Town との関係、Gas Town の handoff / mail / nudge の一次仕様
- MCP 2026-07-28 の Tasks の仕様、ACP の各 CLI 対応状況、A2A v1.0 の正確な日付
- Anthropic Engineering の記事本文
- Agent teams の公開日と、WezTerm での分割ペイン動作（ドキュメントは tmux / iTerm2 のみ記載）
- Conductor、Superset の一次情報、herdr 本家のスター数、uzi の最終コミット日
- Claude Code の Channels、Projects、Remote Control の初出時期（週次ダイジェストは 2026-03-23 以降しか載っていない）

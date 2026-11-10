# Phase 2 追加調査: 各社コーディング CLI の「外から束ねる口」とプロトコル（一次情報版）

- 調査日: 2026-11-10（版・日付・スター数はすべてこの日の取得値）
- 目的: 自作オーケストレーションエンジンの「エージェントごとに差し替える層」を設計するため、Claude Code に固有の4つの口（statusLine の拍動、UserPromptSubmit の hook、`CLAUDE_CODE_SESSION_ID`、`claude --resume`）が他社 CLI でどう置き換えられるかを一次情報で確かめる。前回メモ `docs/draft/618-engine-research/phase2-external.md` の3節・4節・7.4節の「未取得」を埋める
- 方法: WebFetch で公式ドキュメントと GitHub のページを直接開いた。WebSearch は入口探しと補助にだけ使った。検索語・外部リクエストに利用者の個人情報やリポジトリ名は入れていない
- 検証ステータスの意味
  - `[verified]`: 自分で一次ソースのページを開いて確かめた（URL つき）
  - `[unverified-summary]`: 検索結果の要約や二次情報（URL つき）
  - `[speculation]`: 推測
- 読み方の注意
  - WebFetch は「ページ本文を小さなモデルが要約して返す」道具である。`[verified]` は「該当ページを開き、その要約に当該の記述があった」という意味で、原文の全文を目視したわけではない。設計に使う前に、要となる箇所（とくに 2.1 の Codex）は実機の `--help` で突き合わせるのがよい
  - 長いページは先頭 10 万字までしか読めないものがあった（Codex の app-server・CLI リファレンス・設定リファレンスは続きも読んだ。Copilot CLI のコマンドリファレンスは 44 万字あり、後半は読めていない）

## 0. 取得できたもの・できなかったもの

| 対象 | 結果 |
| --- | --- |
| Codex 公式ドキュメント | 取得できた。`developers.openai.com/codex/*` は `learn.chatgpt.com/docs/*` へ 308 で転送されるようになっており、転送先を開けば読める（前回「取得不可」だった原因はこの転送とみられる `[speculation]`） |
| Cursor 公式ドキュメント（`cursor.com/docs/cli/*`、`cursor.com/changelog`） | 取得できた。ただし CLI 専用の changelog（`cursor.com/docs/cli/changelog.md`）は 404 |
| Gemini CLI 公式サイト（`geminicli.com`） | 取得できた |
| ACP（`agentclientprotocol.com`）、MCP（`modelcontextprotocol.io`）、A2A（`a2a-protocol.org`、GitHub Releases）、`agents.md` | 取得できた |
| GitHub Copilot CLI | hooks・ACP・プログラム実行の各ページと Releases は取得。**起動オプション（`--resume`、`--session-id` など）の定義本文は未確認**（コマンドリファレンスの後半が読めなかった） |
| Amp | ドキュメントは取得。**CLI の版番号は未確認** |
| Kiro CLI | **hooks のページが取れず未確認**（`kiro.dev/docs/cli/hooks` は転送の告知だけ、推測した別 URL は 404）。ACP 対応エージェントの一覧に名前があることだけ確認 |
| Goose | CLI コマンドのページと Releases は取得。hooks の仕様ページは未確認 |
| Pi | README と RPC の概要は取得。RPC のコマンド一覧・版番号は未確認 |
| Codex の `CODEX_THREAD_ID` | 公式の環境変数ページには載っていない。SDK の README の例に名前が出るだけ（後述） |

## A. 各 CLI の「外から束ねるための口」

### A.1 OpenAI Codex CLI（最も厚く）

#### 版

- 最新の安定版は **0.167.0（2026-11-06）**。プレリリースは 0.169.0-alpha.7（2026-11-09） `[verified]` https://github.com/openai/codex/releases

#### 前回メモからの訂正（重要）

| 前回の記述 | 今回わかったこと | 根拠 |
| --- | --- | --- |
| subagent が「既定で有効」か「実験的」か矛盾 | **既定で有効・stable**。「Current Codex releases enable subagent workflows by default.」。設定リファレンスでも `features.multi_agent` は「stable; on by default」 | `[verified]` https://learn.chatgpt.com/docs/agent-configuration/subagents 、 https://learn.chatgpt.com/docs/config-file/config-reference |
| `[agents]` の `max_threads`（既定 6）、`max_depth`（既定 1） | 現行のキーは **`agents.max_concurrent_threads_per_session`**。`agents.max_threads` は「legacy alias」。既定の数値はページに無く「When unset, Codex chooses the default」。`max_depth` は subagents ページにも設定リファレンス（読めた範囲）にも**出てこない** | 同上 `[verified]` |
| `/agent` でスレッド切替 | 現行は **`/subagents`**（「inspect and switch between agent threads while they run」） | `[verified]` https://learn.chatgpt.com/docs/agent-configuration/subagents |
| `codex mcp-server` で Codex を MCP サーバーとして露出できる | **削除済み**。「The `codex mcp-server` command and standalone `codex-mcp-server` binary have been removed.」「Use the Codex app server instead.」。CLI リファレンスと SDK ページの両方に同じ告知がある。削除された版は未確認 | `[verified]` https://learn.chatgpt.com/docs/cli/reference 、 https://learn.chatgpt.com/docs/codex-sdk |

#### マルチエージェント機能

| 機能 | 現行仕様 | 安定度 | 根拠 |
| --- | --- | --- | --- |
| subagent | 既定で有効。並列に走らせて結果をまとめて返す（「Codex waits until all requested results are available, then returns a consolidated response」）。ツールは `spawn_agent`、`send_input`、`resume_agent`、`wait_agent`、`close_agent` | stable・既定で有効 | `[verified]` 上記 2 ページ |
| カスタムエージェント | 1 エージェント 1 TOML。個人は `~/.codex/agents/`、プロジェクトは `.codex/agents/`。必須は `name`、`description`、`developer_instructions`。組み込みは `default`、`worker`、`explorer` | 記載なし | `[verified]` subagents ページ |
| subagent の権限 | 親の sandbox と権限モードを継ぐ。対話では非アクティブなスレッドからの承認要求も出る。**非対話では新しい承認が要る操作は失敗する**（「In non-interactive flows, ... an action that needs new approval fails.」） | — | `[verified]` 同上 |
| ネストの深さ | 未確認（ページに記述なし） | — | — |
| `codex agents` | 「Open the agent command center on a shared local or remote server.」。CLI リファレンスの成熟度は **Stable**。`--remote <URL>` で遠隔のサーバーへ、`--cd <DIR>` で新規タスクの作業場所 | Stable（表記） | `[verified]` https://learn.chatgpt.com/docs/cli/reference |
| 共有の背景サーバー（daemon） | 対話 CLI は既定で「shared background server」を使う。`--no-daemon` で使わずに走る。`/daemon` で再起動できる（0.163.0、2026-10-15） | 定義の説明は薄い | `[verified]` CLI リファレンス、 https://learn.chatgpt.com/docs/changelog |
| message board | 0.164.0（2026-10-23）「Add storage namespaces for local message boards」「Allow consumers to select message-board tools」、0.165.0（2026-10-27）「Add silent append support」、0.166.0（2026-10-29）「Add channel upserts to message boards」、0.167.0「Add an MCP adapter for message-board tools」。**利用者向けのドキュメントは見つからない**。changelog の PR 題名だけである | 未文書化（内部実装が進行中とみられる `[speculation]`） | `[verified]` changelog（PR 題名のみ） |
| エージェント間メッセージの hook | 0.164.0「Add lifecycle hooks for inter-agent messages」（#55657）。hooks ページの 14 イベントには対応する名前が無く、詳細は未確認 | 未確認 | `[verified]` changelog |
| クラウド実行 | `codex cloud`（別名 `cloud-tasks`）で Cloud のチャットを端末から閲覧・実行。`codex apply` でクラウドの差分を手元へ適用 | `codex cloud` は Experimental | `[verified]` CLI リファレンス |

- **文書同士の食い違い**: CLI リファレンスは「`codex agents` doesn't support `--no-daemon`」と書くが、0.167.0 のリリースノートは「Open the agent command center with `codex agents --no-daemon`」と書く。リリースノートのほうが新しいので、ドキュメントの更新遅れとみられる `[speculation]`。**この周辺（daemon、command center、message board）は 2026-10 以降ほぼ毎週変わっており、依存先としては不安定**である

#### hook

- 既定で有効。「Hooks are enabled by default.」。切るには `[features] hooks = false` `[verified]` https://learn.chatgpt.com/docs/hooks
- 置き場所: `~/.codex/hooks.json`、`~/.codex/config.toml` の `[hooks]`、`<repo>/.codex/hooks.json`、`<repo>/.codex/config.toml`。プロジェクト側は `.codex/` が信頼済みのときだけ読まれる `[verified]`
- イベントは 14 種: `SessionStart`、`SessionEnd`、`PreToolUse`、`PermissionRequest`、`PostToolUse`、`PreModelRequest`、`PostModelRequest`、`PreCompact`、`PostCompact`、`UserPromptSubmit`、`SubagentStart`、`SubagentStop`、`Stop`、`Interrupt` `[verified]`
- 標準入力の共通フィールド: `session_id`、`transcript_path`、`cwd`、`hook_event_name`、`model`。ターン単位のものは `turn_id` も `[verified]`
- ハンドラは `command` と `mcp_tool` だけが動く（「`prompt` and `agent` handlers are parsed but skipped」）。`async: true` で裏で走らせられる。既定のタイムアウトは 600 秒（`SessionEnd` と `Interrupt` は 1 秒、最大 3 秒） `[verified]`
- **形が Claude Code とほぼ同じ**である（イベント名、標準入力の JSON、`decision: "block"`、`additionalContext`）。プラグインの hook には `CLAUDE_PLUGIN_ROOT` まで互換のために設定される `[verified]`
- hook が `codex exec` や app-server 経由でも走るかは、ページに明記が無く未確認

| Claude Code | Codex | 受け取れるもの | 備考 |
| --- | --- | --- | --- |
| UserPromptSubmit | `UserPromptSubmit` | `prompt`、`session_id`、`turn_id` | 標準出力は開発者向け文脈として追加。`decision: "block"` も可 |
| Stop | `Stop` | `last_assistant_message`、`stop_hook_active` | `decision: "block"` は「続行させる」意味 |
| SessionStart | `SessionStart` | `source` は `startup` / `resume` / `clear` / `compact` / `fork` | — |
| SessionEnd | `SessionEnd` | `reason`（ページ上は `other` のみ） | 助言のみで舵は切れない。タイムアウト 1 秒 |
| Notification | **hook には無い** | — | 別系統の設定 `notify`（「Command invoked for notifications; receives a JSON payload from Codex.」）と、承認要求を拾う `PermissionRequest` hook で代える |
| SubagentStop | `SubagentStop`（`SubagentStart` もある） | — | — |

#### セッションの識別子と再開

- ID の取り方
  - hook の標準入力の `session_id`（文書化済み） `[verified]` hooks ページ
  - `codex exec --json` の最初の行 `{"type":"thread.started","thread_id":"..."}` `[verified]` https://learn.chatgpt.com/docs/non-interactive-mode
  - 環境変数: 公式の環境変数ページは「Codex が読む変数」だけを載せ、`CODEX_THREAD_ID` は**載っていない** `[verified]` https://learn.chatgpt.com/docs/config-file/environment-variables 。TypeScript SDK の README の再開例に `process.env.CODEX_THREAD_ID` が出るが、誰がいつ設定するかの説明は無い `[verified]` https://github.com/openai/codex/blob/main/sdk/typescript/README.md 。「2026-02 のコミット #10096 で端末の環境へ注入されるようになった」という話は検索要約だけである `[unverified-summary]`（同検索）。**`CLAUDE_CODE_SESSION_ID` の代わりとして当てにするなら実機確認が要る**
- 再開
  - 対話: `codex resume <SESSION_ID>`、`codex resume --last`（現在の作業ディレクトリの最新）、`--all`（ディレクトリをまたぐ）、`--include-non-interactive` `[verified]` CLI リファレンス
  - 非対話: `codex exec resume --last "..."`、`codex exec resume <SESSION_ID>`、`codex exec fork <SESSION_ID>` `[verified]` 非対話ページ、CLI リファレンス
  - 分岐: `codex fork <SESSION_ID> --worktree` で管理下の git worktree へ分岐できる `[verified]` CLI リファレンス
- 保存場所: `CODEX_HOME`（既定 `~/.codex`）の下。スレッドは `~/.codex/sessions` に JSONL で保存（SDK README「Threads are persisted in `~/.codex/sessions`」、app-server ページ「stored as a JSONL file on disk」） `[verified]`。再開可能な実行時状態は SQLite（`sqlite_home`、既定は `CODEX_HOME`） `[verified]` 設定リファレンス

#### 状態を外から読む口

| 口 | 内容 | 根拠 |
| --- | --- | --- |
| statusline 相当 | `tui.status_line` は「Ordered list of TUI footer status-line item identifiers」。**組み込み項目の並び替えであり、外部コマンドを走らせる仕組みではない**（読めた範囲に外部コマンドの記述なし）。`/statusline`、`/title` で切り替え | `[verified]` 設定リファレンス、changelog |
| 端末タイトル | `tui.terminal_title`、既定は `["spinner", "project"]`。**tmux からは pane のタイトルとして読める**ので、動作中かどうかの弱い手がかりになる `[speculation]` | `[verified]` 設定リファレンス |
| JSON の出力 | `codex exec --json` が JSONL を出す。イベントは `thread.started`、`turn.started`、`turn.completed`、`turn.failed`、`item.*`、`error` | `[verified]` 非対話ページ |
| app-server | JSON-RPC。通知は `turn/started`、`turn/completed`、`item/started`、`item/completed`、`item/agentMessage/delta`、`thread/status/changed` など。状態は `notLoaded` / `idle` / `systemError` / `active`（`activeFlags` に `waitingOnApproval` の例） | `[verified]` https://learn.chatgpt.com/docs/app-server |
| SDK | TypeScript（`@openai/codex-sdk`、「It spawns the CLI and exchanges JSONL events over stdin/stdout」）と Python（`openai-codex`、「controls the local Codex app-server over JSON-RPC」、stable と明記） | `[verified]` SDK ページ、SDK README |
| transcript | hook の `transcript_path` と `~/.codex/sessions` の JSONL を直接読む | `[verified]` |

#### 外から入力を送る口（打鍵以外に 3 つある）

| 口 | 内容 | 安定度 | 根拠 |
| --- | --- | --- | --- |
| **`codex queue`** | `codex queue --thread <SESSION_ID> --message "..."`。既存のセッションへ文字のメッセージを積む。`--thread` は UUID かセッション名。`--resume` を付けると、読み込まれていないセッションを起こす（「Resuming requires a running local daemon or a server selected with `--remote`」）。再開できなくても警告だけで正常終了する | CLI リファレンスの表記は Stable。ただし `--resume` は 0.166.0（2026-10-29）で入ったばかり | `[verified]` CLI リファレンス、changelog |
| **app-server の `turn/start` / `turn/steer`** | `turn/steer` は「append user input to the active in-flight turn」。`expectedTurnId` が要る。承認は `item/commandExecution/requestApproval` と `item/fileChange/requestApproval` がサーバーから届き、`accept` / `acceptForSession` / `decline` / `cancel` で答える | `codex app-server` は Experimental。WebSocket は「experimental and unsupported」。stdio が既定 | `[verified]` app-server ページ |
| **`codex --remote`** | `codex app-server --listen ws://127.0.0.1:4500` を立て、別の端末から `codex --remote ws://127.0.0.1:4500` で TUI をつなぐ。`--remote` は `codex`、`agents`、`queue`、`resume`、`fork` などで使える。`unix://` も可 | 同上 | `[verified]` app-server ページ、CLI リファレンス |

- `codex queue` で積んだメッセージが「いつ届くか」「相手が動作中のときどう扱われるか」はページに書かれておらず未確認。0.165.0 に「Prevented queued agent messages from restarting work after an interrupt or a switch to Plan mode」とあり、挙動はまだ調整中である `[verified]` changelog
- 1 つのスレッドに複数のクライアントが同時につなげるかは明記なし。`thread/unsubscribe` が「現在の接続の購読を外す」、「最後の購読者が外れるとスレッドを下ろす」（`thread_unload_delay_secs`、既定 60 秒）とあるので、複数購読を想定した作りに見える `[speculation]`
- `codex remote-control` は Experimental。「they aren't a replacement for `codex app-server --listen` when you're building a local protocol client」とあり、自作クライアントの土台には app-server を使えと明記されている `[verified]` CLI リファレンス
- ACP: Codex 自体は ACP を話さない。アダプタ経由である。`zed-industries/codex-acp` は 2026-07-22 に archive され、「Development has moved to agentclientprotocol/codex-acp」「built on the new Codex App Server」「Use `@agentclientprotocol/codex-acp` for new installs」 `[verified]` https://github.com/zed-industries/codex-acp

#### 非対話の実行

- `codex exec "..."`。進捗は標準エラー、最終メッセージだけ標準出力 `[verified]` 非対話ページ
- `--json` で JSONL、`-o <path>`（`--output-last-message`）で最終メッセージをファイルへ、`--output-schema <schema.json>` で JSON Schema に沿った最終応答 `[verified]`

```jsonl
{"type":"thread.started","thread_id":"0199a213-81c0-7800-8aa1-bbab2a035a53"}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"Repo contains docs, sdk, and examples directories."}}
{"type":"turn.completed","usage":{"input_tokens":24763,"cached_input_tokens":24448,"output_tokens":122,"reasoning_output_tokens":0}}
```

#### AGENTS.md

- 全体は `~/.codex/AGENTS.override.md` → `~/.codex/AGENTS.md`。プロジェクトは git のルートから現在地まで各階層で `AGENTS.override.md` → `AGENTS.md` → `project_doc_fallback_filenames`。上限は `project_doc_max_bytes`（既定 32 KiB） `[verified]` https://learn.chatgpt.com/docs/agent-configuration/agents-md

### A.2 Gemini CLI（と Antigravity CLI）

- **前提の変化**: 2026-05-19 の Google の告知で、Gemini CLI は 2026-06-18 に Google AI Pro / Ultra と無料枠への提供を止め、後継の **Antigravity CLI** へ移った。有償の API キーと企業向けライセンスでは引き続き使える（「Gemini CLI will remain accessible via paid Gemini and Gemini Enterprise Agent Platform API keys」）。Antigravity CLI は「Agent Skills, Hooks, Subagents, and Extensions (now as Antigravity plugins)」を引き継ぐが「won't be 1:1 feature parity right out of the gate」 `[verified]` https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
- Antigravity CLI の一次仕様は今回開いていない。コマンド名が `agy`、ACP の stdio モードが出荷時に無い、という話は二次情報である `[unverified-summary]`（検索要約。https://amux.io/guides/gemini-cli-to-antigravity-cli/ ほか）
- 版: v0.67.0（2026-11-04、Latest）。プレビューは v0.68.0-preview.0 `[verified]` https://github.com/google-gemini/gemini-cli/releases 。リポジトリは開発が続いている

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| マルチエージェント | subagent は既定で有効、ネスト不可、A2A の remote subagents あり（前回確認済み）。v0.68.0-preview.0 で `SubagentStop` hook の対応づけが入る | 前回メモ 3.3、`[verified]` Releases |
| hook | 11 種: `SessionStart`、`SessionEnd`、`BeforeAgent`、`AfterAgent`、`BeforeModel`、`AfterModel`、`BeforeToolSelection`、`BeforeTool`、`AfterTool`、`PreCompress`、`Notification`。共通入力は `session_id`、`transcript_path`、`cwd`、`hook_event_name`、`timestamp`。既定で有効かはページに記述なし（未確認） | `[verified]` https://geminicli.com/docs/hooks/reference/ |
| セッション ID | hook の `session_id`、`stream-json` の `init` イベント。環境変数は hook リファレンスに記述なし（未確認） | `[verified]` 同上、 https://geminicli.com/docs/cli/headless/ |
| 再開 | `gemini --resume`（最新）、`--resume <番号>`、`--resume <UUID>`、`--list-sessions`、`/resume` | `[verified]` https://geminicli.com/docs/cli/session-management/ |
| 保存場所 | `~/.gemini/tmp/<project_hash>/chats/`。既定で 30 日保持 | `[verified]` 同上 |
| 非対話 | `-p` または TTY でない環境。`--output-format` で JSON（`response`、`stats`、`error`）か JSONL のストリーム（`init`、`message`、`tool_use`、`tool_result`、`error`、`result`）。終了コード 0 / 1 / 42 / 53 | `[verified]` headless ページ |
| 外から入力 | `gemini --acp` で ACP サーバー（`initialize`、`authenticate`、`newSession`、`loadSession`、`prompt`、`cancel`、`setSessionMode`）。ページの最終更新は 2026-04-10。対話 TUI へ後から入れる口は見つからず、**端末への打鍵しか無い** | `[verified]` https://geminicli.com/docs/cli/acp-mode/ |
| statusline 相当 | 未確認 | — |
| AGENTS.md | `agents.md` の対応一覧に Gemini CLI がある（既定は `GEMINI.md`） | `[verified]` https://agents.md/ |

| Claude Code | Gemini CLI |
| --- | --- |
| UserPromptSubmit | `BeforeAgent`（`prompt`） |
| Stop | `AfterAgent`（`prompt`、`prompt_response`、`stop_hook_active`） |
| Notification | `Notification`（`notification_type: "ToolPermission"`、`message`、`details`） |
| SessionStart / SessionEnd | `SessionStart` / `SessionEnd` |

### A.3 Cursor CLI（`agent` / `cursor-agent`）

- 版: CLI の版番号と日付は未確認（CLI 専用 changelog が 404）。製品全体の changelog の直近は 2026-11-06（Voice Chat）、2026-10-20（Agent SDK） `[verified]` https://cursor.com/changelog

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| マルチエージェント | CLI の `-w, --worktree [name]`（`~/.cursor/worktrees/<reponame>/<name>`）、`worker`（private cloud worker）。hook に `subagentStart` / `subagentStop` がある。CLI から subagent を並べる仕様の詳細は未確認 | `[verified]` https://cursor.com/docs/cli/reference/parameters 、 https://cursor.com/docs/agent/hooks |
| hook | `sessionStart`、`sessionEnd`、`preToolUse`、`postToolUse`、`postToolUseFailure`、`subagentStart`、`subagentStop`、`beforeShellExecution`、`afterShellExecution`、`beforeMCPExecution`、`afterMCPExecution`、`beforeReadFile`、`afterFileEdit`、`beforeSubmitPrompt`、`preCompact`、`stop`、`afterAgentResponse`、`afterAgentThought`。置き場所は `.cursor/hooks.json` と `~/.cursor/hooks.json` | `[verified]` hooks ページ |
| hook が CLI で動くか | **ページが CLI を明記するのは `workspaceOpen` だけ**（「Runs in the Cursor desktop app and CLI」）。ほかのイベントが `agent` CLI で発火するかは未確認。設計に使う前に実機確認が要る | `[verified]` 同上 |
| セッション ID | hook の `conversation_id`（`session_id` は `sessionStart` / `sessionEnd` にだけあり「same as `conversation_id`」）。`-p --output-format json` の結果と `stream-json` の全イベントに `session_id`。`create-chat` は空のチャットを作って ID を返す | `[verified]` hooks ページ、 https://cursor.com/docs/cli/reference/output-format 、parameters ページ |
| hook に渡る環境変数 | `CURSOR_PROJECT_DIR`、`CURSOR_VERSION`、`CURSOR_TRANSCRIPT_PATH`、`CLAUDE_PROJECT_DIR`（別名）など。セッション ID の環境変数は無い | `[verified]` hooks ページ |
| 再開 | `--resume [chatId]`、`--continue`（`--resume=-1` の別名）、`resume`（最新）、`ls`（一覧から選ぶ） | `[verified]` parameters ページ |
| 保存場所 | 未確認 | — |
| 非対話 | `-p` と `--output-format text|json|stream-json`、`--stream-partial-output`。イベントは `system`（init）、`user`、`assistant`、`tool_call`、`result`。`--force` が無いと変更は提案どまり | `[verified]` https://cursor.com/docs/cli/headless 、output-format ページ |
| 外から入力 | `agent acp`（stdio の JSON-RPC。`session/new`、`session/load`、`session/prompt`、`session/request_permission`、`session/cancel`）。「advanced, hidden command」。対話 TUI へ後から入れる口は見つからず、**端末への打鍵しか無い** | `[verified]` https://cursor.com/docs/cli/acp 、parameters ページ |
| statusline 相当 | 未確認 | — |
| AGENTS.md | 対応一覧に Cursor がある | `[verified]` https://agents.md/ |

### A.4 GitHub Copilot CLI

- 版: v1.0.108（2026-11-09）。プレリリース v1.0.109-1 `[verified]` https://github.com/github/copilot-cli/releases

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| マルチエージェント | `/fleet [PROMPT]`（「Enable parallel subagent execution of parts of a task」）、`/delegate`（クラウドへ委譲して PR）、`/tasks`、`/subagents`。設定 `subagents.maxConcurrency`、`subagents.maxDepth`（従量課金でないプランでは無視）。ネストした subagent あり | `[verified]` https://docs.github.com/en/copilot/reference/cli-command-reference 、Releases |
| hook | 14 種: `sessionStart`、`sessionEnd`、`userPromptSubmitted`、`userPromptTransformed`、`preToolUse`、`permissionRequest`、`postToolUse`、`postToolUseFailure`、`agentStop`、`subagentStart`、`subagentStop`、`errorOccurred`、`notification`、`preCompact`。「All hook events described in this article are supported by the CLI.」。置き場所は `.github/hooks/*.json`、`~/.copilot/hooks/`、`settings.json` の `hooks` | `[verified]` https://docs.github.com/en/copilot/reference/hooks-configuration |
| セッション ID | hook の全ペイロードに `sessionId`、`timestamp`、`cwd`。環境変数は未確認 | `[verified]` 同上 |
| 再開 | `--resume`、`--continue`、`--session-id` というオプションが存在する（別の記述の中で名前が出る）。`/resume [SESSION-ID]`。**各オプションの定義本文は未確認** | `[verified]`（存在のみ） https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference |
| 保存場所 | `~/.copilot`（`COPILOT_HOME` で変更）。セッションの細かい置き場所は未確認 | `[verified]` 同上 |
| 非対話 | `-p PROMPT`、`-s`（応答だけ）、`--output-format=text|json`（JSONL）、`--allow-all-tools`、`--no-ask-user`、`--share=PATH` | `[verified]` 同上 |
| 外から入力 | `copilot --acp`（stdio が既定、`--port <n>` で TCP、`127.0.0.1` に bind）。用途に「Multi-agent systems: Coordinate Copilot with other AI agents using a standard protocol」と明記。**public preview**。組み込み SDK サーバーもある（詳細は未確認） | `[verified]` https://docs.github.com/en/copilot/reference/copilot-cli-reference/acp-server 、Releases |
| statusline 相当 | `/statusline` がある（項目の切り替え）。外部コマンドを走らせられるかは未確認 | `[verified]` Releases |
| AGENTS.md | 対応一覧に「Coding agent (GitHub Copilot)」 | `[verified]` https://agents.md/ |

| Claude Code | Copilot CLI |
| --- | --- |
| UserPromptSubmit | `userPromptSubmitted`（`prompt`。設定ファイルの hook の出力は捨てられる。受け取るだけなら十分） |
| Stop | `agentStop`（`transcriptPath`、`stopReason`。`decision: "block"` で続行） |
| Notification | `notification`（CLI だけで発火） |
| SessionStart / SessionEnd | `sessionStart` / `sessionEnd` |

### A.5 OpenCode

- 版: v2.2.7（2026-11-10）。リポジトリは `anomalyco/opencode` `[verified]` https://github.com/sst/opencode/releases （転送先）
- v1 から v2 へ移っており、ドキュメントに v1 向けと v2 向けが混ざっている。以下は開いたページに書かれていた内容である

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| 構造 | 「When you run `opencode` it starts a TUI and a server. Where the TUI is the client that talks to the server.」。**TUI がサーバーのクライアントである**ことが、今回の対象の中で最も束ねやすい作り | `[verified]` https://opencode.ai/docs/server/ |
| マルチエージェント | `mode: subagent` のエージェントを `subagent` ツールで子セッションとして起こす（「fresh context in foreground or background child sessions」）。安定度の表記なし | `[verified]` https://opencode.ai/docs/agents/ |
| hook | **シェルスクリプトの hook は無い**。JS / TS のプラグインだけ。サーバープラグインの hook は `prompt`、`context`、`compaction`、`tools.execute.before` / `after`、`permissions.evaluate` など。v2.2.1 に実験的な `experimental.idle` | `[verified]` https://opencode.ai/docs/build/plugins/server/ 、Releases |
| 状態を読む | `GET /event`（SSE。「First event is `server.connected`, then bus events」）、`GET /session`、`GET /session/:id`、`GET /session/:id/children`。OpenAPI 3.1 の仕様が `/doc` に出る | `[verified]` server ページ |
| 外から入力 | `POST /session/:id/message`（待つ）、`POST /session/:id/prompt_async`（待たない）、`POST /session/:id/abort`、`POST /session/:id/permissions/:permissionID`、さらに **`POST /tui/append-prompt`、`POST /tui/submit-prompt`**（TUI を動かす）。`opencode --server <URL>` で既存のサーバーへつなぐ | `[verified]` server ページ、 https://opencode.ai/docs/cli/ |
| セッション ID・再開 | ID は `ses_...`。`opencode run --session <id>`、`--continue`。`opencode session list --max-count 20 --format json`、`session export`、`session import` | `[verified]` https://opencode.ai/docs/cli/commands/ |
| 保存場所 | SQLite のデータベース。`opencode debug paths db` で場所が出る（`OPENCODE_DB` で変更） | `[verified]` https://opencode.ai/docs/cli/ |
| 非対話 | `opencode run "..."`、`--format json`（JSONL）、`--archived`、`-w`（worktree）。v2.2.6 から、起こした背景ジョブと subagent が終わるまで待つ（時間制限なし） | `[verified]` commands ページ、Releases |
| ACP | `opencode acp`（stdio） | `[verified]` https://opencode.ai/docs/acp/ |
| AGENTS.md | 対応（ACP ページに「Project rules from `AGENTS.md`」） | `[verified]` 同上 |

### A.6 Amp

- 版: CLI の版番号は未確認

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| マルチエージェント | Task subagent、プラグインから `amp.createAgent(...)` でカスタム subagent。`stream-json` の init に `subagents`、背景 subagent が止まると `system` / `subagent_finished`。orb（スレッドごとにクラウドに作る機械）で「Send a prompt, close your laptop, and the agent keeps working」 | `[verified]` https://ampcode.com/docs/customize/plugins 、 https://ampcode.com/docs/cli/streaming-json 、 https://ampcode.com/manual |
| hook | **シェルスクリプトの hook は無い**。TS / JS のプラグイン（`.amp/plugins/`、`~/.config/amp/plugins/`）。イベントは `session.start`、`agent.start`（プロンプト送信時）、`tool.call`、`tool.result`、`agent.end`（ターン終了。`continue` を返せる）。プラグインの中からシェルを呼べる（`amp.$`） | `[verified]` plugins ページ |
| セッション ID | スレッド ID（`T-...`）。プラグインの `event.thread.id`、`stream-json` の `session_id` | `[verified]` 同上 |
| 再開 | `amp threads continue`（`--execute` と併用可）。ID 指定の書式は未確認 | `[verified]` streaming-json ページ |
| 非対話 | `amp -x "..."`（最終メッセージだけ出力）。`--stream-json`（Claude Code 互換の形）。**`--stream-json-input` で標準入力から後続のユーザーメッセージを流し込める**。動作中なら積まれ、`steer: true` で次の割り込み点で処理 | `[verified]` https://ampcode.com/docs/cli/execute-mode 、streaming-json ページ |
| 外から入力（対話） | Cross-client access: 動いている CLI のスレッドを ampcode.com の web から続けられる。**ローカルの別プロセスから入れる公式の口は見つからない**（端末への打鍵か web 経由） | `[verified]` https://ampcode.com/docs/cli/remote-control |
| statusline 相当 | `amp.experimental?.createStatusItem()`（実験的。CLI のステータス行へ項目を足す） | `[verified]` plugins ページ |
| ACP | ACP 対応エージェントの一覧に **Amp は無い** | `[verified]` https://agentclientprotocol.com/get-started/agents |
| AGENTS.md | 対応 | `[verified]` https://agents.md/ |

### A.7 Goose

- 版: v1.58.1（2026-11-10）。リポジトリは `aaif-goose/goose`（Agentic AI Foundation へ移管） `[verified]` https://github.com/block/goose/releases （転送先）

| 項目 | 内容 | 根拠 |
| --- | --- | --- |
| マルチエージェント | delegate による subagent。v1.56.0 で失敗・中断した subagent の再開、`GOOSE_MAX_CONCURRENT_SUBAGENTS`。**v1.55.0 で「Background subagents and the orchestrator were removed」**（縮小の方向） | `[verified]` Releases |
| hook | hook は存在する（v1.55.0「subagent が親の hook を継ぐ」）。イベントの一覧は未確認 | `[verified]`（存在のみ） |
| セッション ID・再開 | `goose session --resume`、`-n <name>`、`--session-id <id>`（例 `20251108_1`）。`goose session list --format json`。v1.57.0 で呼び出し側が ID を指定可、v1.58.0 で `/status` に ID 表示 | `[verified]` https://goose-docs.ai/docs/guides/goose-cli-commands 、Releases |
| 保存場所 | v1.10.0 以降は SQLite（`sessions.db`） | `[verified]` 同上 |
| 非対話 | `goose run -t "..."`、`--output-format text|json|stream-json`、`--no-session`、`-r` | `[verified]` 同上 |
| 外から入力 | `goose acp`（stdio）と **`goose serve`（ACP を HTTP と WebSocket で。既定は 127.0.0.1:3284、`GOOSE_SERVER__SECRET_KEY` が要る）** | `[verified]` 同上 |
| AGENTS.md | 対応 | `[verified]` https://agents.md/ |

### A.8 その他（薄く）

| CLI | わかったこと | 根拠 |
| --- | --- | --- |
| Factory Droid | `droid exec [options] [prompt]`。`-o text|json|stream-json|stream-jsonrpc|acp`。多ターンは `--input-format stream-jsonrpc`。`-s, --session-id <id>` で継続、`--fork <id>`。既定は読み取り専用、`--auto low|medium|high`。SDK は `@factory/droid-sdk`（TS）と `droid-sdk`（Python）。hook は未確認 | `[verified]` https://docs.factory.com/cli/droid-exec/overview |
| Qwen Code | `-p`、`--output-format text|json|stream-json`、`--input-format stream-json`（工事中の表記）、`--continue`、`--resume [sessionId]`。保存は `~/.qwen/projects/<sanitized-cwd>/chats` の JSONL。hook は目次に項目があるだけで未確認 | `[verified]` https://qwenlm.github.io/qwen-code-docs/en/users/features/headless/ |
| Pi | 「skips features like sub-agents and plan mode」。`pi --mode rpc` で RPC（`prompt`、`get_state`。イベントに `agent_end`、`agent_settled`、`message_update`）。リポジトリは `earendil-works/pi` へ移っている。ACP は `pi-acp` アダプタ経由 | `[verified]` https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md 、同 `docs/rpc.md`、ACP の agents 一覧 |
| Kiro CLI | ACP 対応エージェントの一覧に名前がある。hook・再開・非対話は未確認 | `[verified]` ACP の agents 一覧 |

### A.9 対応表: Claude Code の4つの口を各 CLI でどう差し替えるか

- 記号: ○ 同等あり / △ 部分的・要実機確認 / × 無し / ? 未確認
- 「拍動」は「一定間隔で外部スクリプトが呼ばれ、生きていることと現在の状態を書き出せる口」とした。Claude Code の statusLine のように **外部コマンドを周期的に呼ぶ口は、調べた範囲ではどの CLI にも無かった**。代わりは「イベントの hook を拍の代用にする」か「サーバーやストリームを購読する」かである

| CLI | 拍動（statusLine） | プロンプト受領の hook | セッション ID | resume | 根拠 |
| --- | --- | --- | --- | --- | --- |
| Codex | △ `tui.status_line` は組み込み項目だけ。代用は hook の `PreToolUse` / `PostToolUse`（ツール実行のたびに拍）、`PreModelRequest`（観測専用）、または app-server の `thread/status/changed` | ○ `UserPromptSubmit`（形もほぼ同じ） | △ hook の `session_id` と `exec --json` の `thread_id` は確実。環境変数 `CODEX_THREAD_ID` は公式ページに無く要実機確認 | ○ `codex resume <ID>`、`codex exec resume <ID>` | https://learn.chatgpt.com/docs/hooks 、 https://learn.chatgpt.com/docs/cli/reference 、 https://learn.chatgpt.com/docs/config-file/config-reference |
| Gemini CLI | △ 代用は `BeforeTool` / `AfterTool` / `BeforeModel` の hook | ○ `BeforeAgent` | △ hook の `session_id`。環境変数は未確認 | ○ `gemini --resume <UUID>` | https://geminicli.com/docs/hooks/reference/ 、 https://geminicli.com/docs/cli/session-management/ |
| Cursor CLI | ? CLI で hook が発火するか未確認。確実なのは `-p --output-format stream-json` の購読 | △ `beforeSubmitPrompt` はあるが CLI での発火は未確認 | △ `stream-json` の `session_id`、hook の `conversation_id`、`create-chat` の戻り値。環境変数は無い | ○ `--resume [chatId]` | https://cursor.com/docs/agent/hooks 、 https://cursor.com/docs/cli/reference/parameters 、 https://cursor.com/docs/cli/reference/output-format |
| Copilot CLI | △ 代用は `preToolUse` / `postToolUse` の hook。`/statusline` は項目の切り替え | ○ `userPromptSubmitted` | △ hook の `sessionId`。環境変数は未確認 | △ `--resume` / `--session-id` は存在するが定義は未確認 | https://docs.github.com/en/copilot/reference/hooks-configuration 、 https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference |
| OpenCode | ○（別の形）`GET /event` の SSE を購読すれば拍動より細かい | △ シェルの hook は無い。SSE の購読か JS プラグインの `prompt` hook | ○ `ses_...`。`session list --format json` と API | ○ `opencode run --session <id>`、`--continue` | https://opencode.ai/docs/server/ 、 https://opencode.ai/docs/cli/commands/ 、 https://opencode.ai/docs/build/plugins/server/ |
| Amp | △ 実験的な `createStatusItem()`、または `tool.call` プラグイン | △ シェルの hook は無い。TS プラグインの `agent.start`（中からシェルを呼べる） | ○ `event.thread.id`、`stream-json` の `session_id` | △ `amp threads continue`（ID 指定の書式は未確認） | https://ampcode.com/docs/customize/plugins 、 https://ampcode.com/docs/cli/streaming-json |
| Goose | ? | ? hook はあるがイベント一覧は未確認 | ○ `--session-id`、`session list --format json`、呼び出し側が ID を指定可 | ○ `goose session --resume --session-id <id>` | https://goose-docs.ai/docs/guides/goose-cli-commands 、 https://github.com/block/goose/releases |
| Droid | ? | ? | ○ JSON 出力の `session_id` | ○ `droid exec -s <id>` | https://docs.factory.com/cli/droid-exec/overview |
| Qwen Code | ? | ? | ? | ○ `--resume [sessionId]` | https://qwenlm.github.io/qwen-code-docs/en/users/features/headless/ |

- 読み取れること
  - **プロンプト受領の hook とセッション ID（hook の標準入力経由）と resume は、Codex・Gemini・Copilot でほぼそのまま移せる**。3 社とも Claude Code の hook の形（標準入力に JSON、`session_id`、`transcript_path`、`cwd`）に寄せてきている
  - **拍動だけは移せない**。差し替え層では「拍動」を「statusLine」ではなく「生存と状態の信号を得る手段」という抽象にして、Claude は statusLine、Codex は hook の連打か app-server の購読、OpenCode は SSE、と実装を分けるのがよい `[speculation]`
  - **セッション ID を環境変数で渡す口は Claude Code に固有**と考えたほうが安全である。他は「hook の標準入力から取ってファイルへ書く」か「起動時に `exec --json` の最初の行から取る」に寄せる `[speculation]`

## B. プロトコル

### B.1 ACP（Agent Client Protocol）

- 仕様の範囲（現行の v1）

| 機能 | メソッド | 状態 | 根拠 |
| --- | --- | --- | --- |
| セッション作成 | `session/new`（`cwd`、`mcpServers` → `sessionId`） | stable | `[verified]` https://agentclientprotocol.com/protocol/session-setup |
| 履歴つきの再読込 | `session/load`（`agentCapabilities.loadSession` が要る。履歴を再生して返す） | stable | 同上 |
| 再開 | `session/resume`（`sessionCapabilities.resume`。履歴は再生しない） | 2026-04-22 に安定化 | `[verified]` https://agentclientprotocol.com/updates.md |
| 一覧 | `session/list` | 2026-02-18 に安定化 | 同上 |
| 終了 | `session/close`（進行中の作業も止める） | 2026-04-23 に安定化 | 同上 |
| プロンプト送信 | `session/prompt`。応答に停止理由（`end_turn`、`max_tokens`、`max_turn_requests`、`refusal`、`cancelled`） | stable | `[verified]` https://agentclientprotocol.com/protocol/prompt-turn |
| 状態の通知 | `session/update`（`agent_message_chunk`、`agent_thought_chunk`、`tool_call`、`tool_call_update`、`plan`、`current_mode_update`、`session_info_update`、`usage_update`、`notice`、`compaction_update` など） | stable | 同上 |
| 権限の要求 | `session/request_permission`（エージェント → クライアント） | stable | 同上 |
| 中断 | `session/cancel` | stable | 同上 |

- その他の時系列: ACP Registry 公開 2026-03-09、Transports Working Group 発足 2026-04-22（「standardize remote agent transports like WebSockets and HTTP」）、**ACP v2 が 2026-07-20 に Draft で公開** `[verified]` updates ページ
- 仕様に無いもの
  - **ターンの途中で 2 通目を入れること（キューや steer）は規定されていない**。「Once a prompt turn completes, the Client may send another `session/prompt`」とあるだけ `[verified]` prompt-turn ページ。キューは acpx などクライアント側の実装である
  - 1 つのセッションへ複数のクライアントが同時につなぐことも、このページには規定が無い
  - 標準の輸送路は実質 stdio（子プロセスとして起こす）。HTTP / WebSocket は作業部会で標準化の途中。Goose の `goose serve` と Copilot の `--port` は各社の先行実装 `[verified]` 各ページ
- 対応エージェント（公式の一覧、51 件、2026-11-10 時点）のうち、今回の対象
  - 一覧にある: Codex CLI（「via ACP's adapter」）、Claude Agent（「via Zed's SDK adapter」）、Cursor、Gemini CLI、GitHub Copilot（public preview）、Goose、OpenCode、Factory Droid、Kiro CLI、Qwen Code、Pi（`pi-acp` アダプタ経由）、Cline、OpenHands、Junie、Mistral Vibe ほか `[verified]` https://agentclientprotocol.com/get-started/agents
  - 一覧に無い: **Amp**、Antigravity CLI `[verified]` 同上
- 対応クライアント: エディタは Zed、JetBrains、neovim（CodeCompanion、avante.nvim ほか）、Emacs（agent-shell.el）、VS Code の拡張など。**CLI / TUI の区分に acpx、Toad、Hydra、Orca CLI、acp-runner など**。フレームワークに LangChain / LangGraph、Mastra、fast-agent など `[verified]` https://agentclientprotocol.com/get-started/clients
- 複数エージェントを ACP で束ねる OSS の実例
  - **acpx**（`openclaw/acpx`、約 3.4k スター）: 「a headless command-line client for the Agent Client Protocol」。`acpx codex sessions new --name backend`、`acpx codex -s backend "..."`、`acpx codex exec "..."` のように **どのエージェントも同じ形のコマンドで扱う**。組み込みの起動プロファイルが 30（Codex、Claude Code、Gemini CLI、Cursor、Copilot、Droid、Goose、OpenCode、Qwen Code、Pi ほか）。永続セッションは「queue follow-up prompts when a turn is already running」。`--format json` で ACP イベントの NDJSON。状態は `~/.acpx/`。**「pre-1.0. Treat its CLI and runtime interfaces as evolving」**。Node.js 22.13 以上 `[verified]` https://github.com/openclaw/acpx
  - **OpenClaw**: 外部のハーネス（Claude Code、Gemini CLI、Codex）を「through an ACP backend plugin」（`@openclaw/acpx`）で子として起こす。入口は `/acp spawn` と `sessions_spawn`（`runtime: "acp"`）。セッションキーは `agent:<agentId>:acp:<uuid>`。ただし「For Codex, ACP is the external-harness path, not the default Codex path」 `[verified]` https://docs.openclaw.ai/tools/acp-agents
  - Agent of Empires が ACP を使い始めていることは前回メモのとおり（今回は追加確認なし）
- 「端末の画面を読む代わりに ACP で子を操る」ことは現実的か
  - **送る・状態を読む・承認に答える・再開する、は構造化されていて現実的**である。`tmux capture-pane` で画面を推し量る必要が無くなる
  - **失うものは「人が途中で覗いて介入する」こと**である。ACP の子は親の子プロセスとして stdio でつながり、TUI を持たない。人が見るには、クライアント側が画面を用意するか、同じセッションを後で CLI の `resume` で開き直すしかない（同時には見られない） `[speculation]`
  - Codex に限れば、ACP アダプタは app-server の上に載っているので、ACP を挟むより app-server を直接使うほうが層が 1 つ少ない `[speculation]`（根拠は codex-acp の README）
  - Bash + jq のエンジンから stdio の双方向 JSON-RPC を直接扱うのは重い。使うなら acpx のような CLI を間に置く形になる `[speculation]`

### B.2 MCP

- 2026-07-28 版の要点（前の版 2025-11-25 からの変更） `[verified]` https://modelcontextprotocol.io/specification/2026-07-28/changelog
  - **プロトコルレベルのセッションを廃止**（`Mcp-Session-Id` を削除）。呼び出しをまたぐ状態は、サーバーが発行するハンドルを通常のツール引数として渡す
  - **stateless 化**: `initialize` の握手を廃止。毎回のリクエストの `_meta` に版と能力を載せる。`server/discover` を新設
  - 通知の購読は `subscriptions/listen` に一本化。`ping`、`logging/setLevel` などを削除
  - **Tasks は core から外れ、公式の拡張（`io.modelcontextprotocol/tasks`）へ**。ブロックする `tasks/result` をやめ、`tasks/get` のポーリングと、クライアントから入力を返す `tasks/update` に。`tasks/list` は削除
  - サーバーからクライアントへ要求を送る方式をやめ、**Multi Round-Trip Requests**（結果に `resultType: "input_required"` と `inputRequests` を返し、クライアントが再試行で答える）へ
  - Roots、Sampling、Logging は非推奨。最低 12 か月の非推奨期間という方針を新設
- Tasks 拡張の中身 `[verified]` https://modelcontextprotocol.io/extensions/tasks/overview
  - サーバーが長くかかると判断したら `CreateTaskResult`（`resultType: "task"`、`taskId`、`ttlMs`、`pollIntervalMs`）を返す。状態は `working`、`input_required`、`completed`、`failed`、`cancelled`
  - `input_required` のとき `tasks/get` の応答に `inputRequests` が載り、`tasks/update` で答える。`tasks/cancel` は協調的（止まる保証は無い）
  - 「Host support varies by client」。**クライアントとサーバーの双方が明示的に対応して初めて使える**
- 「他の CLI を MCP サーバーとして露出して子にする」実例と制約

| CLI | 口 | 実際に露出されるもの | 制約 | 根拠 |
| --- | --- | --- | --- | --- |
| Codex | `codex mcp-server` | — | **削除済み**。app-server を使えと案内 | `[verified]` https://learn.chatgpt.com/docs/cli/reference |
| Claude Code | `claude mcp serve`（stdio） | 「This MCP server only exposes Claude Code's tools to your MCP client」。**エージェントのループではなく、Read や Bash などの道具だけ** | 確認の実装はクライアントの責任（「your own client is responsible for implementing user confirmation」）。つまり「Claude を子エージェントにする」用途には使えない | `[verified]` https://code.claude.com/docs/en/mcp |
| Codex | message-board tools の MCP アダプタ（0.167.0） | 未文書化 | 詳細は未確認 | `[verified]` changelog（PR 題名のみ） |

- 含意: **「相手の CLI を MCP サーバーとして子にする」道は、2026-11 時点で公式には細っている**。Codex は口を削り、Claude Code はもともと道具しか出さない。残るのは「自分で薄い MCP サーバーを書き、その中で `codex exec` や app-server を呼ぶ」形であり、そのとき Tasks 拡張が長時間の受け皿になる。ただしホスト側の Tasks 対応はまちまちである `[speculation]`

### B.3 A2A

- **v1.0.0 は 2026-03-12**（「Major release with breaking changes」）。最新は v1.0.1（2026-05-28）。それより新しい版は Releases の 1 ページ目に無い `[verified]` https://github.com/a2aproject/A2A/releases 。前回メモで割れていた「2026-03-12 か 2026-04 か」は 03-12 で確定
- 統治: 「originally developed by Google and donated to the Linux Foundation」。Technical Steering Committee は AWS、Cisco、Google、IBM Research、Microsoft、Salesforce、SAP、ServiceNow。**Agentic AI Foundation へ参加**（告知の URL の日付は 2026-08-27） `[verified]` https://a2a-protocol.org/latest/
- コーディング CLI での採用: 確認できたのは引き続き Gemini CLI だけ（remote subagents。v0.67.0 のリリースノートにも A2A の修正が並ぶ） `[verified]` https://github.com/google-gemini/gemini-cli/releases 。Codex、Cursor、Copilot、OpenCode、Amp、Goose の今回開いたページに A2A の記述は無かった
- ローカルの複数セッション間で使う実例: 見つからなかった（未確認）。ACP のクライアント一覧に `a2acode` というコネクタ名はあるが中身は開いていない

### B.4 共通化（数行）

- AGENTS.md: 「used by over 60k open-source projects」「stewarded by the Agentic AI Foundation under the Linux Foundation」。対応一覧に Codex、Cursor、Gemini CLI、Copilot の coding agent、opencode、Amp、goose、Factory、Zed、Devin、Junie、Windsurf ほか `[verified]` https://agents.md/ 。前回の「4 万か 6 万超か」は公式サイトの表記で 6 万超
- Agent Skills: Antigravity CLI が Gemini CLI から「Agent Skills, Hooks, Subagents」を引き継ぐと明記 `[verified]`（Google の告知）。Codex は `skills/list` を app-server に持つ `[verified]`（app-server ページ）。規格そのもののページは今回開いていない（未確認）
- hook の形: 規格は無いが、**Codex・Gemini・Copilot・Cursor が Claude Code の形へ事実上そろってきた**（Codex は `CLAUDE_PLUGIN_ROOT`、Cursor は `CLAUDE_PROJECT_DIR` を互換のために設定し、Gemini CLI には Claude の hook の移行処理がある） `[verified]` 各 hooks ページと Gemini CLI の Releases

## C. まとめ

### C.1 「異種の CLI を子にする」運び方の比較

| 運び方 | 到達の確かさ | 状態の読みやすさ | 人が途中で覗いて介入できるか | 実装の重さ（Bash + jq 前提） | 向く相手 |
| --- | --- | --- | --- | --- | --- |
| tmux の打鍵 | 低〜中。入力欄の状態・貼り付けの扱い・確認ダイアログに左右される。届いたかどうかは hook で裏取りする必要がある | 低（画面の読み取り）。hook を併用すれば中 | **◎ そのまま見られ、打てる** | 軽い（既にある）。ただし CLI ごとに画面の癖を覚える必要がある | すべての CLI。最後の手段としても残る |
| 非対話の exec を都度起こす | **高**。終了コードと JSONL で結果が確定する | **高**（`--json` / `stream-json`）。ID も最初の行で取れる | × 走っている間は見られない。後から `resume` で対話に開き直すことはできる | **軽い**（jq で足りる） | Codex、Gemini、Cursor、Copilot、OpenCode、Amp、Goose、Droid、Qwen（全部にある） |
| 対話 TUI + 公式の投函口 | 中〜高。Codex の `codex queue`、OpenCode の HTTP API、Claude Code のソケット | 中〜高。hook や SSE と組み合わせる | **○ TUI はそのまま見られる** | 中。CLI ごとに口が違う | Codex（`queue`）、OpenCode（`/session/:id/prompt_async`、`/tui/*`）、Claude Code |
| app-server / SDK / サーバーモード | 高。JSON-RPC や HTTP で応答が返る | **最高**（ターン・項目・承認・状態の通知） | △ Codex は `codex --remote` で同じサーバーへ TUI をつなげる。OpenCode は TUI 自体がクライアント | **重い**。双方向の JSON-RPC を Bash で持つのは無理があり、常駐の小さな仲介（Node や Python）が要る | Codex（app-server）、OpenCode（serve）、Goose（serve）、Copilot（SDK） |
| ACP | 高（stable な範囲で） | 高（`session/update`） | × 子は TUI を持たない。後で CLI から開き直す | 中〜重。acpx を間に置けば CLI 1 本で済むが pre-1.0 | Gemini、Cursor、Copilot、OpenCode、Goose、Droid、Qwen は自前で対応。Codex・Claude・Pi はアダプタ。Amp は不可 |
| MCP サーバーとして露出 | 低（公式の口が細っている） | 低〜中（Tasks 拡張に両側が対応すれば中） | × | 重い（自分でサーバーを書く） | 現状は勧めにくい |

- 読み取れること
  - 「人が覗いて介入できる」と「構造化されて確実」を**両立する口を公式に持つのは、Codex（app-server + `--remote`、または `queue`）と OpenCode（TUI がサーバーのクライアント）だけ**である。ほかは二者択一になる
  - どの CLI にも非対話の exec と resume があるので、**「exec で仕事を進め、人が見たいときだけ同じ ID を対話で開き直す」は全 CLI 共通の最小公約数**になる

### C.2 Codex を子にする場合の構成案

#### 案 1: 対話 TUI + hook + `codex queue`（いまのエンジンに最も近い）

- 構成
  - 子は tmux の pane で `codex` を対話で起こす（人がそのまま覗ける）
  - 状態は hook で受ける。`SessionStart`（`session_id` を登記）、`UserPromptSubmit`（受領の確認）、`Stop`（ターン終了と `last_assistant_message`）、`PermissionRequest`（判断待ち）、`PreToolUse` / `PostToolUse`（拍動の代用）。形が Claude Code とほぼ同じなので、既存の hook スクリプトを薄い変換で使い回せる
  - 送信は `codex queue --thread <SESSION_ID> --message "..."` を第一に、`tmux send-keys` を控えに置く
  - 復帰は `codex resume <SESSION_ID>`
- 根拠: hook は既定で有効で 14 イベント、`codex queue` と `codex resume` は CLI リファレンスで Stable 表記 `[verified]`
- 弱点
  - `codex queue` が動作中のセッションにどう届くかは未文書。daemon が前提（`--no-daemon` で起こした子には届かないとみられる `[speculation]`）。この周辺は 2026-10 以降ほぼ毎週変わっている
  - 拍動は「ツール実行のたび」になり、長い思考中は拍が途切れる。`PreModelRequest`（観測専用）を足すと埋まる可能性がある `[speculation]`
  - セッション ID を環境変数で子の中へ渡す口が不確か（`CODEX_THREAD_ID` は要実機確認）
- 着手前に実機で確かめること: `codex queue` の届き方（待機中 / 動作中 / 承認待ち）、hook が `--no-daemon` でも走るか、`CODEX_THREAD_ID` が hook やシェルの環境に入るか

#### 案 2: 非対話の `codex exec --json` を都度起こす（最も確実で軽い）

- 構成
  - 委譲 1 回 = `codex exec --json -o <結果ファイル> "<指示>"` を 1 プロセス。最初の行の `thread_id` を登記する
  - 追加の指示は `codex exec resume <SESSION_ID> "..."`。結果は `turn.completed` / `turn.failed` と終了コードで確定する
  - 人が覗きたいときは `codex resume <SESSION_ID>` で対話に開き直す。走っている最中は JSONL を `tail` で流して見せる
  - 拍動は JSONL の行が流れてくること自体で代える
- 根拠: `codex exec` は Stable。イベントの型と resume の書式は公式ページに明記 `[verified]`。利用者の既存の `so-compare` が Codex を非対話で呼んでいるのと同じ系統である
- 弱点
  - 走っている最中に人が口を挟めない（止めるならプロセスを殺す）
  - 「新しい承認が要る操作は失敗する」ので、sandbox と承認の方針を起動時に決め切る必要がある `[verified]` subagents ページ
  - hook が exec でも走るかは未確認（走らなくても JSONL で足りる）

#### 案 3: `codex app-server` を常駐させ、薄い仲介を挟む（最も構造化されるが重い）

- 構成
  - `codex app-server --listen unix://<パス>`（または `ws://127.0.0.1:<port>`）を 1 つ立てる
  - 小さな仲介（Node か Python。Python SDK の `openai-codex` が app-server を JSON-RPC で操る）が `thread/start`、`turn/start`、`turn/steer`、承認への応答を受け持ち、エンジンには CLI として見せる
  - 状態は `thread/status/changed`（`idle` / `active` と `waitingOnApproval`）と `turn/completed` をファイルへ落とし、エンジンは jq で読む
  - 人は `codex --remote unix://<パス>` で同じサーバーへ TUI をつなぐ、または `codex agents --remote` で一覧を見る
- 根拠: メソッドと通知、`--remote`、承認の流れは公式ページに明記 `[verified]`。ACP の Codex アダプタもこの app-server の上に載っており、**Codex 側が「外から操る正規の口」と位置づけているのはここ**である（`codex mcp-server` を削って app-server を案内している）
- 弱点
  - `codex app-server` は Experimental、WebSocket は「experimental and unsupported」。一部のメソッドは `experimentalApi` が要る
  - Bash + jq だけでは持てず、常駐プロセスが増える
  - 同じスレッドへ仲介と TUI が同時につながったときの挙動は未文書

#### 並べると

| 観点 | 案 1 TUI + hook + queue | 案 2 exec を都度 | 案 3 app-server |
| --- | --- | --- | --- |
| 既存エンジンからの距離 | 近い（hook をほぼ流用） | 近い（`so-compare` と同系統） | 遠い（仲介が要る） |
| 到達の確かさ | 中（`queue` の挙動が未文書） | 高 | 高 |
| 人の介入 | ◎ | △（後から開き直す） | ○（`--remote`） |
| 依存する口の安定度 | hook は既定で有効、`queue` は Stable 表記だが新しい | Stable | Experimental |
| 差し替え層への一般化 | Gemini・Copilot にも同じ形で広げやすい（hook が似ている） | 全 CLI に広げられる | Codex 専用（OpenCode・Goose は別の API） |

- 進め方の見立て `[speculation]`
  - **まず案 2 を「全 CLI 共通の最小の子」として差し替え層の基準にし、Codex には案 1 を重ねる**のが、年内に方向を決めるうえで手戻りが少ない。案 2 は口が Stable で、Gemini・Cursor・Copilot・OpenCode にも同じ形（非対話 + JSONL + resume）で通る。案 1 は hook の形が Claude Code に寄っているので、既存の 4 つの口のうち 3 つ（プロンプト受領・ID・resume）をほぼそのまま移せる
  - 案 3 と ACP は「Codex の daemon / command center / message board が落ち着いたら再評価」に回すのが安全である。この領域は 2026-10 以降の動きが速く、いま土台にすると作り直しになりやすい
  - 差し替え層の抽象は、口の名前（statusLine、UserPromptSubmit など）ではなく役割で切るのがよい。たとえば「起動する」「送る」「受領を確かめる」「生存と状態を得る」「ID を得る」「復帰する」「判断待ちを知る」の 7 つで、CLI ごとに実装を割り当てる

## 未確認事項（次に調べるなら）

- Codex: `codex queue` の届き方、`CODEX_THREAD_ID` の実在と範囲、hook が `codex exec` / app-server / `--no-daemon` で走るか、message board の利用者向け仕様、subagent のネストの深さ、`codex mcp-server` が削除された版
- Cursor CLI: hook が `agent` CLI で発火するか、CLI の版、セッションの保存場所
- Copilot CLI: `--resume` / `--session-id` / `--continue` の定義、セッションの保存場所、組み込み SDK サーバーの仕様
- Antigravity CLI: 一次仕様の全部（hook、非対話、ACP、再開）
- Gemini CLI: hook が既定で有効か、セッション ID の環境変数
- Goose の hook のイベント一覧、Kiro CLI の全項目、Pi の RPC コマンド一覧、Amp の版と `threads continue` の ID 指定
- ACP v2（Draft）の変更点、ACP で複数クライアントが 1 セッションへつなぐ規定の有無
- A2A をローカルの複数セッション間で使う実例

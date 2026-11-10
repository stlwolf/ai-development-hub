# Phase 2 追跡調査: 2026-02 の21ツールは9か月でどうなったか（2026-11-10）

- 調査日: 2026-11-10
- 目的: 2026-02-22 の landscape 調査（`projects/orchestration-research/landscape/` の21ツールと steipete の番外）が、その後の約9か月でどう変わったかを追い、自作エンジンの方向性を決める材料にする
- 方法
  - まず `INDEX.md` と近縁ツールの個票（`takt.md`、`agent-orchestrator-composio.md`、`cao-aws.md`、`oh-my-claudecode.md`、`oh-my-opencode.md`、`oh-my-claude-code-and-o-m-cc.md`、`claude-flow.md`、`claude-code-agent-teams.md`、`steipete-ecosystem/INDEX.md`）を本文まで読み、2026-02 時点の値を基準にした
  - WebFetch で各リポジトリのトップ、Releases、CHANGELOG、コミット履歴、公式ドキュメントを開いた。WebSearch は経緯の補足に2回だけ使った
  - 検索語と外部リクエストに、利用者の名前・メール・リポジトリ名は入れていない
- 検証ステータスの読み方
  - `[verified]`: 書き手が一次ソースのページを WebFetch で開いて確かめた。ただし WebFetch はページを小さなモデルが要約して返す仕組みなので、原文を一字ずつ見たわけではない。数字や版は要約が返した値である
  - `[unverified-summary]`: 検索結果の要約や二次情報
  - `[speculation]`: 書き手の推測・解釈
- 取得できなかったもの
  - スター数は GitHub の HTML に出る概数（「1.4k」など）で、正確な値は取れていない。取得日はすべて 2026-11-10
  - リポジトリのトップページでは Releases 欄が空で返ることが多く、版と日付は Releases ページか CHANGELOG を別に開いて取った。開けなかったものは「未確認」とした
  - GitHub の Releases ページは日付に年を出さないことがある。年をページのフッター（© 2026）や前後の版から読んだものは「年は推定」と書いた
  - TAKT の `CHANGELOG.md` は 32 万字あり、3回に分けて読んだ。0.60.0〜0.74.0 は版ごとに読み、それより前は「改名の時期」と「プロバイダーが加わった版」だけを拾った。0.23〜0.59 のほかの変更は読んでいない
  - CAO の `CHANGELOG.md` も先頭 10 万字（Unreleased 節が中心）までしか読めていない。v1.0.2 → v2.3.0 の間の版ごとの変更は未確認
  - agent-orchestrator が ComposioHQ から別の組織へ移った時期と理由は、一次情報で見つからなかった
  - OpenClaw の最新版（2026.11.2）のリリースノート本文は外部リンクで、開いていない
  - OpenHands の SDK のリポジトリ（`OpenHands/software-agent-sdk`）は README だけ開いた。サブエージェントの委譲の記述は無く、SDK の文書サイト（`docs.openhands.dev/sdk`）は開いていない
  - TAKT の manager / director の設計文書は、推測したパス（`docs/manager.md`）が 404 で、README の説明までしか取れていない
  - Claude Code 公式機能の時系列と仕様の要点は、同じディレクトリの `phase2-external.md` の2章が扱っている。本書では、各ツールが公式機能へどう追従したかを見るのに必要な範囲だけを確かめた

## 1. 一覧（まず全体を見る）

スター数は概数、取得日は 2026-11-10。2026-02 の値は landscape の `INDEX.md` と個票から取った。

### 1.1 近縁（コーディング CLI を束ねる系）

| ツール | 2026-02 のスター | 現在のスター | 最新の版と日付 | 生死 | 一言 |
| --- | --- | --- | --- | --- | --- |
| TAKT（`nrslib/takt`） | 424 | 約 1.4k | 0.74.0（2026-11-02） | 活発 | 既定が Claude Agent SDK に。対応プロバイダー11種。常駐の manager / director が加わった |
| agent-orchestrator | 約 710 | 約 14.4k | v0.14.11-nightly（2026-11-10、nightly のみ確認） | 活発・組織移転 | `ComposioHQ/` の URL は `OrchestratorInc/agent-orchestrator` へ転送される。Go のデーモン + デスクトップアプリ + スマホアプリへ作り替え |
| CAO（`awslabs/cli-agent-orchestrator`） | 254 | 約 1.5k | v2.5.3（10月8日、年は推定で 2026） | 活発 | tmux を保ったまま、状態検出を「描画した画面のモデル」へ、配送をイベント駆動へ。プロバイダー12種 |
| oh-my-claudecode | 約 7.8k | 約 40.7k | v5.8.4（2026-11-10、年は推定） | 活発 | `/team`（公式 agent teams）と `omc team`（tmux で他社 CLI）の二本立てを維持。MCP ブリッジは削除 |
| oh-my-opencode → oh-my-openagent | 約 35.6k | 約 70.8k | v5.1.66（2026-11-10、年は推定） | 活発・改名・方針転換 | OpenCode のプラグインから、自前エンジン（senpi）で動く単独の CLI `omo` へ |
| o-m-cc（`kok1eee/o-m-cc`） | 4 | 6 | v0.63.0（最終コミット 2026-06-09） | 凍結・後継へ移行 | README で凍結を宣言。後継は同じ作者の flywheel |
| Claude Flow → Ruflo（`ruvnet/ruflo`） | 約 14.3k | 約 81.4k | v3.75.0（2026-11-10、年は推定） | 活発・改名 | 「Claude Code と Codex の meta-harness」を名乗る。実装の中身への疑義は 2026-04 にも出ている |
| OpenHands | 約 68.1k | 約 93.1k | v1.38.0（2026-11-10） | 活発・方針転換 | README の主役が「Agent Canvas」（コーディングエージェントの管制画面）に。ACP 対応エージェントを動かせる |
| Aider | 約 40.8k | 約 50.0k | v0.86.0（2025-08-09、年は推定） | 低調 | リリースは1年以上なし。最終コミットは 2026-05-22 |
| SWE-agent | 約 18.5k | 約 20.8k | v1.1.0（5月22日、年は曖昧） | 後継へ移行 | README が mini-swe-agent への移行を勧める。最終コミットは 2026-07-16 |
| mini-swe-agent | —（個票なし） | 約 9.5k | v2.4.6（7月23日、年は推定で 2026） | 活発（小さく保守） | bash だけ・履歴は一直線、という最小構成を維持 |

### 1.2 steipete の番外

| ツール | 2026-02 のスター | 現在のスター | 最新の版と日付 | 生死 | 一言 |
| --- | --- | --- | --- | --- | --- |
| agent-scripts | 349 | 約 7.5k | リリースなし（最終コミット日は未確認） | 活発 | 中心が「共有スキルの置き場」に。AGENTS.MD ポインターと docs-list は現役 |
| Oracle | 約 1.5k | 約 4.1k | v0.23.0（11月5日、年は推定で 2026） | 活発 | セカンドオピニオンの CLI + MCP。複数モデルのパネル、セッション保存、ブラウザ操作を維持 |
| mcporter | 約 2.1k | 約 5.1k | 未確認 | 活発・組織移転 | `openclaw/mcporter` へ移った |
| Peekaboo | 約 2.3k | 約 5.5k | 4.9.8（日付は未確認） | 活発・組織移転 | `openclaw/Peekaboo` へ移った |
| OpenClaw | 224k+ | 約 394k | 2026.11.2（2026-11-08） | 活発 | 財団（501(c)(3)）が開発。サブエージェントと、Claude CLI・Codex を差し替え可能な「harness」として扱う |

### 1.3 汎用フレームワーク

| ツール | 2026-02 のスター | 現在のスター | 最新の版と日付 | 生死 |
| --- | --- | --- | --- | --- |
| LangGraph | 約 24.9k | 約 44.8k | langgraph 1.2.20（11月5日、年は推定で 2026） | 活発 |
| Mastra | 約 21.3k | 約 29.4k | @mastra/core 1.82.0（2026-11-04） | 活発 |
| ControlFlow | 約 1.4k | 約 1.4k | —（アーカイブ） | 停止（アーカイブ） |
| Marvin | —（ControlFlow の移行先） | 約 6.2k | 3.2.10（10月27日、年は推定で 2026） | 活発（小さく保守） |
| AutoGen | 約 54.7k | 約 61.8k | —（アーカイブ） | 停止（アーカイブ） |
| Microsoft Agent Framework | —（AutoGen の移行先） | 約 14.6k | python-1.25.0（2026-11-07）、dotnet-1.28.0（2026-11-06） | 活発 |
| CrewAI | 約 44.4k | 約 60.7k | 1.15.39（11月9日、年は推定で 2026） | 活発 |
| OpenAI Agents SDK（Python） | 約 19.1k | 約 30.6k | v0.24.0（2026-10-15） | 活発 |
| Google ADK（Python） | 約 17.8k | 約 22.2k | v2.14.0（2026-11-07） | 活発 |
| MetaGPT | 約 64.3k | 約 71.2k | v0.8.1（4月22日、年は曖昧） | 停止に近い |
| BeeAI | 約 3.1k | 約 3.5k | typescript_v0.1.32（11月2日、年は推定で 2026） | 活発（小さい） |
| PydanticAI | 約 15.0k | 約 21.1k | v2.66.0（2026-11-04） | 活発 |
| Agent Squad | 約 7.5k | 約 7.8k | TypeScript 1.1.5（9月23日、年は曖昧） | 低調・組織移転 |
| PentAGI | 約 6.6k | 約 33.9k | 2.2.0（10月5日、年は推定で 2026） | 活発 |

## 2. 近縁ツールの個別の追跡

観点は依頼のとおり、親子の委譲、メッセージの運び方、状態・登記、監視と復帰、世代交代、人の判断待ち、複数ベンダー対応、Claude Code 公式機能への追従である。

### 2.1 TAKT（`nrslib/takt`）

- 現状
  - スター約 1.4k、フォーク 119、コミット 2,255 `[verified]` https://github.com/nrslib/takt
  - 最新版は 0.74.0（2026-11-02）。0.60.0（2026-08-18）から 0.74.0 まで、ほぼ週1回のリリースが続いている `[verified]` https://raw.githubusercontent.com/nrslib/takt/refs/heads/main/CHANGELOG.md
  - GitHub の Releases 機能は使っておらず（「There aren't any releases here」）、版は CHANGELOG とタグで追う `[verified]` https://github.com/nrslib/takt/releases
- 2026-02 から変わったこと

| 観点 | 2026-02（v0.22） | 現在（v0.74） | 根拠 |
| --- | --- | --- | --- |
| 用語 | piece / movement（音楽の比喩） | workflow / step に統一。0.34.0（2026-04-03）で改名を破壊的変更として入れ（旧キーは互換の別名として残した）、0.36.0（2026-04-15）で旧用語を完全に廃止した。`workflows/` が正式なディレクトリ名 | `[verified]` CHANGELOG、README |
| 複数ベンダー | Claude Code / Codex / OpenCode の3種 | 11種。SDK 系が `claude-sdk`・`codex`・`opencode`・`pi`・`deepseek-harness`、CLI 系が `claude-headless`・`claude-terminal`・`copilot`・`cursor`・`kiro`・`devin`。加わった版は cursor が 0.27.0（2026-02-27）、copilot が 0.28.0（2026-03-02）、claude-terminal が 0.42.0（2026-05-20）、kiro が 0.44.0（2026-06-03）、pi が 0.58.0（2026-08-11）、deepseek-harness が 0.60.0（2026-08-18）、devin が 0.74.0（2026-11-02） | `[verified]` CHANGELOG、README |
| Claude の動かし方 | Claude Code SDK | 0.68.0（2026-10-03）で `claude-sdk`（Claude Agent SDK）が既定に。ヘッドレス CLI は `claude-headless` に改名。`claude-terminal` は「対話の端末セッションで Claude Code を動かす。tmux が要る」とだけ説明がある | `[verified]` CHANGELOG、README |
| 依存の持ち方 | 同梱 | 0.71.0（2026-10-15）でプロバイダーの SDK を同梱しなくなり、`takt install <provider>` で入れる | `[verified]` CHANGELOG |
| 常駐の統括 | なし（`takt watch` がキューを見るだけ） | 0.73.0（2026-10-27）で `takt manager`（目標について会話する TUI。裏で常駐デーモンが動く。AI の権限判定つき）。0.74.0 で `takt director`（複数の manager をまたいで目標と未回答の問いを見回り、人に知らせる）と Slack 連携。README は実験的と明記 | `[verified]` CHANGELOG、README |
| 人の判断待ち | レビューの強制と対話モード | manager が人への「inquiry（問い）」を持ち、TUI では Ctrl+R で扱う。director は未回答の問いを見て人に通知する。README は「Human decisions remain with the human」と書き、director はマージ依頼を中継するが自分ではマージしない | `[verified]` README |
| 走行中の介入 | Instruct / Retry | 0.65.0（2026-09-11）で `/tell`（走行中の worktree タスクへ追加の指示）。0.67.0 で `/requeue`・`/retry`。`takt list` に stop・force-fail・instruct | `[verified]` CHANGELOG、README |
| 状態 | `.takt/runs/` の NDJSON | `.takt/runs/<run>/` に実行のメタ情報・セッション・トレース・レポートを普通のファイルで置く。デーモンのイベントと目標の記録も保存。0.65.0 でタスク状態を MCP ツールでも出す | `[verified]` README、CHANGELOG |
| 復帰・再計画 | ループ検出 | 0.66.0 で `fix-replan`・`reimplement` の step。0.66.1 で「プロバイダーのエラーは新しいセッションで1回だけ再試行」。README は「resume と requeue は実行状態とレポートを保つ」と書く | `[verified]` CHANGELOG、README |
| 周辺 | — | `takt merge`（レビュー → 修正 → マージ）、`takt caccia`（CodeRabbit のレビューループ）、`takt make`（ワークフローを対話で作る）、`/verify`（Quint と Alloy の形式仕様）、実験的な `takt ui`（ローカルの Web UI） | `[verified]` CHANGELOG |

- Claude Code 公式機能との関係
  - README は agent teams や subagents に触れていない。Claude Code は「プロバイダーの一つ」として扱い、束ねる側の仕組み（ワークフロー、キュー、manager）は自前で持つ `[verified]` README
  - Team Leader（タスクを分解して並列に流す）は `takt-default-team` という組み込みワークフローとして残り、0.62.0 で Companion レビューが付いた `[verified]`
- 読み方 `[speculation]`
  - TAKT は「決定的なワークフローで強制する」という核を保ったまま、キュー実行器から「常駐の統括 + 人への問いの窓口」へ広がった。manager と director の二段は、利用者のエンジンの「統括 + 判断ボード」に9か月遅れで近づいてきた形に見える
  - 一方で対話セッションを tmux で動かす経路（`claude-terminal`）は脇役で、主経路は SDK である

### 2.2 agent-orchestrator（ComposioHQ → OrchestratorInc）

- 現状
  - `https://github.com/ComposioHQ/agent-orchestrator` を開くと、ページ上のパスは `OrchestratorInc/agent-orchestrator` になっている。スター約 14.4k、フォーク約 2.0k、コミット 3,974 `[verified]` https://github.com/ComposioHQ/agent-orchestrator
  - README は製品名を「Orchestrator.inc」と書き、ライセンスは Apache-2.0。ComposioHQ からの経緯は README に書かれていない `[verified]` https://github.com/OrchestratorInc/agent-orchestrator/blob/main/README.md
  - 移転の時期と理由は未確認。二次情報では、npm の `@composio/ao-cli` や ComposioHQ 名義の導入手順がまだ残っている `[unverified-summary]` https://packages.ecosyste.ms/api/v1/registries/npmjs.org/packages/@composio%2Fao-cli
  - Releases ページで確認できた直近8件はすべて v0.14.11 系の nightly で、1日に2〜3回出ている（2026-11-07〜11-10）。安定版の最新は未確認 `[verified]` https://github.com/OrchestratorInc/agent-orchestrator/releases
- 2026-02 から変わったこと

| 観点 | 2026-02 | 現在 | 根拠 |
| --- | --- | --- | --- |
| 形 | TypeScript の CLI（`ao`）+ Next.js のダッシュボード | デスクトップアプリ（macOS / Windows / Linux）+ iPhone・Android のアプリ。「デスクトップアプリがデーモンを起こすので CLI は不要」 | `[verified]` README |
| 実行基盤 | tmux が既定の Runtime | デーモンは Go。TUI モードは PTY（Windows は ConPTY）でエージェントを動かす。tmux は「legacy または fallback」。Chat モードは端末を使わず、プロトコルで直接つなぐ（Codex と ACP のプロセスはセッションごとの独立したホストプロセス） | `[verified]` https://github.com/OrchestratorInc/agent-orchestrator/blob/main/docs/architecture.md |
| 状態・登記 | DB なし。`key=value` のフラットファイルと JSONL | SQLite。トリガーが全変更を `change_log` 表に追記し、ポーラーが購読者（ダッシュボードの SSE など）へ流す。保存するのは最小限の事実（活動状態、終了、制御モード、PR の事実）だけで、「表示用のステータスは保存せず、読むときに計算する」 | `[verified]` 同上 |
| メッセージの運び方 | `ao send`（tmux へ送る） | TUI のセッションへは実行基盤のハンドル経由。Chat のセッションでは、ターンの途中に来たメッセージを SQLite にためて、ターンが終わったら1つにまとめて渡す。steer（割り込み）は走行中のターンに足す。blocked の間は自動送信を止める | `[verified]` 同上 |
| 状態の検出 | Claude Code の JSONL を直接読む | Claude Code と Codex の TUI セッションでは hook の事実（親のターンと、ネイティブのサブエージェントの ID）を使う。5秒ごとに実行基盤の生死を確かめ、30秒ごとに GitHub / GitLab を見る。終了と判定するのは、実行基盤とプロセスの両方が明らかに死んでいて、直近の活動と矛盾しないときだけ | `[verified]` 同上 |
| 復帰 | `ao session restore` | デーモンやアプリを入れ替えても、独立ホストの Codex / ACP は走行中のターンを続ける。起動時に、中断した制御の引き継ぎを突き合わせ、最後に確定したモードの制御へ戻す。引き継ぎの隙間に来たメッセージは永続の outbox に置いて再送する。ネイティブの履歴が無ければ TUI は新規開始に落ちる | `[verified]` 同上 |
| 親子の委譲 | `ao start` で統括エージェントを起こす | プロジェクトの「main agent」が依頼を受け、計画し、作業ごとに worker を worktree つきで起こし、「人が要るときだけ戻ってくる」。失敗したチェック・レビューコメント・マージ衝突は、そのブランチを持つ worker へ戻す。worker が親へ報告する仕組みの詳細は README に無い | `[verified]` README |
| 人の判断待ち | Attention Zones と通知ルーティング | かんばんに Working / Needs you / In review / Ready to merge のレーン。エージェントが問いや承認待ちになるとスマホへ push 通知が飛び、スマホから返信・承認・端末を開くことができる。内部では `waiting_input`（承認待ち・入力待ち・再認証）と `blocked`（TUI の権限判断待ち）を `needs_input` という表示に束ねる | `[verified]` README、architecture.md |
| 複数ベンダー | Claude Code / Codex / Aider / OpenCode | 約36種（Claude Code、Codex、Cursor、opencode、Aider、Copilot、Gemini CLI、Cline、Goose、Devin、Kiro、OpenHands など）。worker・chat・reviewer のどれに使えるかはエージェントごとに違う | `[verified]` README |
| クラウド | なし | Cloud Agents（ホストされた作業場で worker を動かす。ノート PC を閉じても続く） | `[verified]` README |

- 細部で目についたもの `[verified]` Releases
  - 「Subagent sessions are kept out of parent identity」「The orchestrator session is labeled "Orchestrator"」「Unread orchestrator replies appear on its buttons」: 統括セッションを特別扱いし、ネイティブのサブエージェントを親と混同しないための手当てが直近に入っている
  - 「Compacted Claude sessions can switch from Terminal to Chat」: compaction をまたいだ表示モードの切り替えに対応している
- 読み方 `[speculation]`
  - 9か月でいちばん形が変わったツールである。bash 由来の「DB なし・フラットファイル・tmux」をすべて捨て、SQLite と変更ログ、PTY とプロトコル制御、常駐デーモンへ移った。利用者のエンジンが今いる場所（bash + jq + tmux + hook）は、このツールが出発した場所に近い
  - 「表示用のステータスは保存しない」「終了判定は二重に確かめる」「blocked の間は自動送信しない」は、登記と監視を自作し続ける場合にそのまま借りられる規律である

### 2.3 CAO（`awslabs/cli-agent-orchestrator`）

- 現状
  - スター約 1.5k、フォーク 318、コミット 709 `[verified]` https://github.com/awslabs/cli-agent-orchestrator
  - 最新版は v2.5.3（10月8日）。Releases ページは年を出していないが、2026-02 に v1.0.2 だったので 2026 年と読める（推定）。v2.5.1 と v2.5.2 はタグだけで PyPI には出ておらず、v2.5.3 が v2.5.0 以来の PyPI 公開。2026-02 の個票にあった「PyPI 未公開」は解消している `[verified]` https://github.com/awslabs/cli-agent-orchestrator/releases
- 2026-02 から変わったこと

| 観点 | 2026-02（v1.0.2） | 現在（v2.5.3） | 根拠 |
| --- | --- | --- | --- |
| 実行基盤 | tmux | tmux 3.3 以上が前提のまま。v2.3.0 で herdr のバックエンドも足された | `[verified]` README、Releases |
| 状態の検出 | 端末の生の出力を ANSI 正規表現で読む | v2.3.0（7月12日）で「描画した画面のモデル」（pyte）に変更。生バッファの正規表現はやめた。その後も版ごとに各 CLI の画面変更へ追従する修正が続く（v2.5.0 で Codex、v2.5.2 で Copilot・Kiro・Grok、v2.5.3 で「止まらないスピナーを idle と読まない」など）。hook を使うという記述は Releases に無い | `[verified]` Releases |
| メッセージの運び方 | Inbox + Watchdog（ログを監視して IDLE で配送） | v2.3.0 でイベント駆動に変え、inbox 配送からポーリングを除いた。未リリース分では、TUI が Enter を飲んだときに素の Enter を送り直す「送信確認」と、「Claude Code の質問ダイアログが開いている間は配送を保留する」が入っている | `[verified]` Releases、CHANGELOG（Unreleased 節） |
| 親子の委譲 | Handoff（同期）/ Assign（非同期）/ Send Message の3モード | 3つとも残っている。未リリース分で `--message-file` 入力、assign と handoff から使い捨てのエージェントを起こす機能、handoff の作成を1つの冪等キーで再試行する処理が入った | `[verified]` CHANGELOG（Unreleased 節） |
| 委譲の耐久性 | — | v2.5.2 で「handoff の結果を永続に保存し、通信のタイムアウトを越えて残す」。MCP の通信が先に切れると `pending=true` と `job_id` が返り、あとで `get_handoff_result` で取れる | `[verified]` Releases、https://github.com/awslabs/cli-agent-orchestrator/blob/main/docs/api.md |
| 状態・登記 | SQLite（terminals / inbox / flows の3表） | SQLite を保ったまま、サーバーの単一インスタンスロック、起動の記録、初回配送の永続状態が加わった | `[verified]` CHANGELOG（Unreleased 節） |
| ワークフロー | Flow（cron + 条件スクリプト） | Flow に加えて `cao workflow`（v2.3.0。スクリプト層のエンジン、永続のジャーナルと resume）。v2.5.0 でイベントログと再生、決定的なリプレイ、凍結した実行マニフェスト。v2.5.2 で記録済みの1ステップだけ再生 | `[verified]` Releases |
| 人の判断待ち | tmux に attach して直接指示 | ワークフローの承認が既定で有効になり、各プランの初回実行に `cao workflow approve` が要る | `[verified]` CHANGELOG（Unreleased 節） |
| 複数ベンダー | Amazon Q CLI / Kiro CLI / Claude Code / Codex CLI | 12種: Kiro CLI、Claude Code、Codex CLI、Antigravity CLI、Hermes、Kimi CLI、MiniMax Code、Copilot CLI、OpenCode CLI、Oh My Pi、Cursor CLI、Grok Build CLI。v2.3.0 で Amazon Q CLI と Gemini CLI は外された | `[verified]` README、Releases |
| 記憶 | なし | セッションをまたぐ記憶（v2.3.0 でプロジェクト横断、v2.4.1 で型つきの関係と知識グラフ、v2.5.2 で Obsidian の vault を正本にできる）。ワークフローの結果を教訓に変える自己学習はオプトイン | `[verified]` Releases、README |
| 画面 | REST API のみ | `http://localhost:9889` の Web UI、MCP Apps によるホスト側描画の一覧画面、Profiles タブ | `[verified]` README、Releases |
| 配備 | ローカルのみ | Kubernetes / EKS への配備の選択肢 | `[verified]` README、Releases |

- Claude Code 公式機能との関係
  - README は、worker は各社 CLI のプロセスそのもので、認証もそれぞれが持つと説明している。公式の agent teams や cross-session messaging に乗る記述は見当たらない `[verified]` README
- 読み方 `[speculation]`
  - CAO は利用者のエンジンにいちばん構造が近いまま生き残った例である（tmux、supervisor と worker、inbox）。2026-02 の個票が弱点に挙げた「ANSI 正規表現の脆さ」には、hook へ移るのではなく「画面を端末エミュレータで描画してから読む」ことで答えた。それでも版ごとに各 CLI の画面変更を追う修正が並んでおり、画面読みの保守費は消えていない
  - 「Enter が飲まれたら送り直す」「質問ダイアログが開いている間は配送しない」は、send-keys で委譲する側が必ず踏む問題であり、利用者のエンジンの受領の印（hook）と突き合わせて見る価値がある

### 2.4 oh-my-claudecode（OMC）

- 現状
  - スター約 40.7k、フォーク約 3.6k、コミット 6,330 `[verified]` https://github.com/Yeachan-Heo/oh-my-claudecode
  - 最新版は v5.8.4（11月10日、年は推定で 2026）。直近は1日1回に近い間隔で出ている `[verified]` https://github.com/Yeachan-Heo/oh-my-claudecode/releases
- 2026-02 から変わったこと

| 観点 | 2026-02（v4.5.1） | 現在（v5.8.4） | 根拠 |
| --- | --- | --- | --- |
| 親子の委譲 | Team が正式。swarm / ultrapilot は Team への窓口 | 二本立てを明記。「`omc team` は tmux の CLI worker を起こす。`/team` はセッション内のネイティブ team を使う」。`swarm` の別名は削除 | `[verified]` README |
| 公式 agent teams への依存 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が要る | `/team` は今もこの設定が要る。ネイティブ team の worker に worktree を与える機能は、オプトインの設定の裏で追加中 | `[verified]` README |
| 複数ベンダー | tmux で Codex / Gemini | `omc team N:<provider>` の対象が codex、gemini、antigravity、grok、cursor、claude に。Gemini CLI は Antigravity（`agy`）に置き換わりつつある | `[verified]` README |
| MCP で包む経路 | v4.4.0 で Codex / Gemini の MCP サーバーを廃止 | v5.8.0（11月8日）で、使われていなかった `team` の MCP ブリッジも削除（破壊的変更）。team スキルか `omc team` を使うよう案内 | `[verified]` Releases |
| 状態 | `.omc/state/` | `.omc/state/agent-replay-*.jsonl` のリプレイログ。`.omc/` に plans、logs、handoffs、research notes。v5.8.3 でチェックポイントのスナップショット | `[verified]` README、Releases |
| 監視と復帰 | heartbeat、worker-health | v5.8.0 で「孤児になった claim の回収」と「確認待ちの実行をクラッシュ扱いしない」修正 | `[verified]` Releases |
| 判断の外出し | キーワードと複雑度のヒューリスティック | Jev（外部の判断サービス。スキルの発火、モデルの選択、ループの継続、文脈の刈り込み、タスクの大きさ、完了の判定を問い合わせる。shadow / active / off の3モード。API キーが要り、失敗時はヒューリスティックへ戻る） | `[verified]` https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/README.md |
| 人への通知 | Telegram / Discord / Slack | 同じ（+ webhook）。停止時のコールバックでセッション要約を送り、誰をタグ付けするか設定できる | `[verified]` 同上 |
| 周辺 | — | `omc lookout scan`（着手前の危険スキャン）、`omc session friction report`（文脈の肥大と操作の摩擦の集計）、複数リポジトリの作業場（`.omc-workspace`）、名前つきの autopilot ステージ（Linux の `flock` が要る） | `[verified]` README |

- Claude Code 公式機能との関係 `[verified]` README
  - README には agent view、バックグラウンドセッション、cross-session messaging、dynamic workflows、ultracode のどれも出てこない。使っている公式機能は agent teams（`/team`）だけである
  - 兄弟プロジェクトの oh-my-codex（Codex CLI 用）はスター約 33.8k で、`omx team` が tmux と専用の git worktree で worker を束ねる https://github.com/Yeachan-Heo/oh-my-codex
- 読み方 `[speculation]`
  - OMC は公式の agent teams に乗る部分と、公式が扱わない部分（他社 CLI を tmux で起こす）をはっきり分けて残した。「公式の workers は Claude だけ」という公式側の線引き（3章）と噛み合っている
  - 判断を外部サービス（Jev）へ出したのは、プラグイン層の価値が「エージェントの数」から「いつ・どれを・どこまで」の判断へ移ったことを示すように見える

### 2.5 oh-my-opencode → oh-my-openagent（OmO）

- 現状
  - `code-yeongyu/oh-my-opencode` を開くと `code-yeongyu/oh-my-openagent` のページになる。スター約 70.8k、フォーク約 5.8k、`dev` ブランチに 29,863 コミット。ライセンスは SUL-1.0 のまま `[verified]` https://github.com/code-yeongyu/oh-my-opencode
  - 最新版は v5.1.66（11月10日、年は推定で 2026）。ほぼ毎日出ている `[verified]` https://github.com/code-yeongyu/oh-my-openagent/releases
  - 改名は v3.11.0 のときで、npm は当面 `oh-my-opencode` と `oh-my-openagent` の両方で出していた、という説明がある `[unverified-summary]` https://horadecodar.com.br/oh-my-openagent/
- 2026-02 から変わったこと

| 観点 | 2026-02（v3.9.0） | 現在（v5.1.66） | 根拠 |
| --- | --- | --- | --- |
| 立ち位置 | OpenCode のプラグイン | 単独の CLI `omo`。「senpi」（pi のフォークと説明されている）の上で動く。README は OmO 5.0 として記憶システム、CodeMode、Anthropic のサブスクリプション対応を挙げる。OpenCode 版と LazyCodex からの移行は `omo setup` | `[verified]` https://github.com/code-yeongyu/oh-my-openagent |
| 複数ベンダー | OpenCode 経由で多数 | `/login` で Claude、ChatGPT、Kimi、GLM のサブスクリプションにサインインして混ぜる | `[verified]` 同上 |
| 親子の委譲 | Sisyphus → Atlas → Junior の3層 | 「mass ulw」が大きな仕事をエージェントのグラフに割り、別々のモデルで並列に流す。委譲した子のモデル連鎖に接続済みのプロバイダーが無いと、原因を1通で示して失敗する（v5.1.63） | `[verified]` README、Releases |
| メッセージの運び方 | 同一プロセス内 | 「忙しいスレッドへのメッセージは、既定で走行中のターンを steer する。キューに入るのは、呼び手が頼んだときか、ターンが steer を受けられないときだけ」（v5.1.66）。メッセージの連鎖が5ホップや64通で止まる制限を撤廃（v5.1.61） | `[verified]` Releases |
| 端末をまたぐ | なし | `omo remote` で別の端末のセッションを開く・送る・モデルを替える・割り込む・閉じる（v5.1.65）。端末をまたぐメッセージにも、同じ送り手の行と「権限の注意書き」を付ける | `[verified]` Releases |
| 監視 | Todo Enforcer、Ralph Loop | サブエージェントの「最初のプロンプト」の見張りを 90 秒から 300 秒に延長（立ち上がりの遅いモデルを打ち切らないため） | `[verified]` Releases |
| 記憶・引き継ぎ | `.sisyphus/` の notepad と boulder.json、`/handoff` | Kibitzer（git リポジトリに Markdown で置く記憶。小さなモデルが、同じ失敗の繰り返しを本体に警告する）。端末間の記憶同期。記憶の実行ディレクトリは 2 GiB で上限 | `[verified]` README、Releases |
| 他ホストとの関係 | Claude Code の hooks・skills・agents を読み込む互換層 | スキルの監査で、OpenCode 専用のエージェントやツールを senpi の等価物に置き換え。「共有スキルは OpenCode と Codex で同じに読める」 | `[verified]` Releases |

- 読み方 `[speculation]`
  - 他人のホスト（OpenCode）のプラグインであることをやめ、エンジンごと自前で持つ方向へ出た。2026-02 の個票が背景に挙げた「Anthropic による OpenCode の制限」と同じ種類の依存リスクを、自前化で避けた形である
  - 「steer が既定、キューは例外」「送り手の行と権限の注意書きを付ける」は、公式の cross-session messaging（3章）とほぼ同じ設計に収束している

### 2.6 o-m-cc（`kok1eee/o-m-cc`）

- 現状
  - スター 6、フォーク 0、コミット 430。README の冒頭で、2026-06-09 から能動的な開発を凍結し、保守だけにすると宣言している。最後のコミット（2026-06-09）の題は「docs: o-m-cc を凍結（FROZEN）— loop/設計駆動は後継 flywheel に移行」 `[verified]` https://github.com/kok1eee/o-m-cc 、https://github.com/kok1eee/o-m-cc/commits/main
  - 凍結時の版は v0.63.0。2026-02 の v0.17.1 から46版ぶん進んだあとで止まった `[verified]`
- 凍結までに変わったこと `[verified]` README
  - 2026-02 に注目した HANDOVER.md（VCS の履歴を知識の置き場にする）は、v0.42.0 で `/o-m-cc:handoff` に置き換わった。`.claude/journal.md` に Recap と Next Actions を追記し、VCS で同期する。用途は「別のマシン（EC2 など）へ作業を移す」ことが主になった
  - `code-reviewer` エージェントは v0.58.0 で削除し、Claude Code 組み込みの `code-review` スキルに任せた
  - 2026-02 にあった `teammate-idle.sh` と `task-completed.sh`（agent teams のイベントで残タスクを割り振る hook）は、現在の hook 一覧に見当たらない。Stop 時の stop-guard に相当するものも一覧に無く、SubagentStop（サブエージェントの出力検証）が入っている
  - agent teams はプラグインの `settings.json` で自動的に有効にしており、Discovery Council（researcher・analyst・scout の対等な議論）は残っている
- 後継の flywheel `[verified]` https://github.com/kok1eee/flywheel
  - スター 0、v0.8.47。設計書が検証を通るまで実装系のツールを hook で止め、そのあと「実装 → 評価コマンド → 落ちている間は停止を拒否 → 通ったら磨く」のループを回す Claude Code プラグイン
  - 調べものと反論は入れ子のサブエージェントに委ね（Claude Code 2.1.172 以降）、`ultrawork` スキルは公式の Workflow スクリプトで合議（計画 → 生成 → 判定 → 統合）を回す
- 読み方 `[speculation]`
  - 2026-02 に「設計が洗練されている」と評価した P2P の協調と HANDOVER.md は、どちらも作者自身の手で縮んだ。残ったのは「設計が通るまで実装させない」「評価が通るまで止めさせない」という hook の強制で、協調の部分は公式の subagents と workflows に任せている
  - 小さな個人プラグインが、公式機能の拡充を受けて「協調の仕組み」を手放し「強制の仕組み」だけを持つ、という縮み方の実例である

### 2.7 Claude Flow → Ruflo（`ruvnet/ruflo`）

- 現状
  - `ruvnet/claude-flow` は `ruvnet/ruflo` になり、README に「Claude Flow is now Ruflo」とある。スター約 81.4k、フォーク約 9.6k、コミット 10,379 `[verified]` https://github.com/ruvnet/claude-flow
  - 最新版は v3.75.0（11月10日、年は推定で 2026）。2026-02 の v3.1.0-alpha から alpha が取れ、数日おきに出ている `[verified]` https://github.com/ruvnet/ruflo/releases
- 現在の主張 `[verified]` README
  - 「Claude Code と Codex のための agent meta-harness」。`npx ruflo init` でエージェント、hook、記憶、MCP サーバーをプロジェクトに入れる
  - Claude Code のネイティブプラグイン48個と同梱の npm プラグイン14個、Codex 用プラグイン（`@claude-flow/codex`）、`npx ruflo init --grok`（Grok Build）、Web コンソール、TUI、マシン間の「federation」
  - README は agent teams に触れず、公式機能との比較は「Claude Code With vs Without Ruflo」という自前の表だけである
- 実装の中身への疑義は続いている
  - 2026-04-04 に v3.5.51 を対象にした独立監査（個人の gist）が、「本物は約10個で、残りは実行の裏付けが無い JSON 状態のスタブ」と主張した。2026-05-03 には、プロジェクト側が6エージェントの検証でツール群を「機能する / しない」に分類した自己監査（ADR-093）を出した、という説明がある。どちらも二次情報で、スタブが直ったかどうかは確認できていない `[unverified-summary]` https://gist.icoder.workers.dev/roman-rr/ed603b676af019b8740423d2bb8e4bf6 、https://agentwiki.org/adr_093_may_audit
  - 直近のリリースノートは、書き込みの原子性、入力検証、パスの制限、テレメトリのオプトイン化など、足回りとセキュリティの修正が中心である `[verified]` Releases
- 読み方 `[speculation]`
  - スター数は9か月で約5.7倍になったが、2026-02 に確認した「主張と実装のずれ」が解消した証拠は取れていない。設計の参考にするなら、主張ではなくコードを開いて確かめる前提が要る。2026-02 の評価（プロダクション利用は推奨しない）を変える材料は無い

### 2.8 OpenHands

- 現状
  - リポジトリは `OpenHands/OpenHands`。スター約 93.1k、フォーク約 12.4k、コミット 9,033 `[verified]` https://github.com/All-Hands-AI/OpenHands
  - 最新版は v1.38.0（2026-11-10）。数日おきに出ている `[verified]` https://github.com/OpenHands/OpenHands/releases
- 2026-02 から変わったこと `[verified]` README、Releases
  - README の主役が「Agent Canvas」になった。「コーディングエージェントと自動化のための、自前でホストする開発者の管制センター」という位置づけで、Web の画面と裏側の統括からなる
  - 既定では OpenHands 自身のエージェントを動かすが、ACP 対応のエージェントも動かせる。README は Claude Code、Codex、Gemini CLI、Pi、OpenCode を挙げる
  - Automations（スケジュールや webhook で起動するワークフロー。Slack、GitHub、Linear、Notion、Datadog と連携）が、直近のリリースでいちばん手が入っている領域である
  - リポジトリは4つ（OpenHands、software-agent-sdk、typescript-client、automation）に分かれ、Agent Server の API は SDK 側にある
  - サブエージェントの委譲は README と直近4件のリリースノートに出てこない。SDK のリポジトリ（スター約 1.4k）の README にも、委譲・ACP・会話の永続化・stuck 検出・人の確認の記述は無い（文書サイトは未確認） `[verified]` https://github.com/OpenHands/software-agent-sdk
- 読み方 `[speculation]`
  - 「自分のエージェントをサンドボックスで動かす」製品から、「他社の CLI も ACP で受け入れる管制画面」へ重心が移った。agent-orchestrator と同じ方向である

### 2.9 Aider

- スター約 50.0k、フォーク約 5.2k。アーカイブや保守終了の告知は無い `[verified]` https://github.com/Aider-AI/aider
- 最新のリリースは v0.86.0（8月9日。添付画像の日付などから 2025 年と読める）。それ以降のリリースは Releases ページに無い `[verified]` https://github.com/Aider-AI/aider/releases
- `main` の最終コミットは 2026-05-22（Anthropic のモデル名の一覧を足すだけの変更） `[verified]` https://github.com/Aider-AI/aider/commits/main
- README はいまも「Claude 3.7 Sonnet、DeepSeek R1、o1、o3-mini、GPT-4o で最もよく動く」と書いており、更新が止まっている `[verified]`
- 読み方 `[speculation]`: スターは増えているが、開発は実質止まっている。Repository Map などの知見は残るが、束ねる対象の CLI としては細っていく側にある

### 2.10 SWE-agent / mini-swe-agent

- SWE-agent: スター約 20.8k。README に警告があり、「Most of our current development effort is on mini-swe-agent, which has superseded SWE-agent.」「Our general recommendation is to use mini-SWE-agent instead of SWE-agent going forward.」と書いている。最新のリリースは v1.1.0（5月22日、年はページに無い）。最終コミットは 2026-07-16 で、小さな修正が続いている `[verified]` https://github.com/SWE-agent/SWE-agent 、https://github.com/SWE-agent/SWE-agent/commits/main
- mini-swe-agent: スター約 9.5k、コミット 1,022。最新は v2.4.6（7月23日、年は推定で 2026）。道具は bash だけ、履歴は一直線に足すだけ、行動は `subprocess.run` で状態を持たない、という最小構成。README は SWE-bench Verified で 74% 超と自己申告している `[verified]` https://github.com/SWE-agent/mini-swe-agent 、https://github.com/SWE-agent/mini-swe-agent/releases
- 読み方 `[speculation]`: 2026-02 の個票が見出しに書いた「→ mini-SWE-agent」が確定した。ACI（エージェント専用の道具の設計）という学術的な貢献を出した本家が、「道具は bash だけでほぼ同じに動く」側へ移ったことは、steipete の「必要な囲いはモデルの能力で変わる」（agent-scripts の Ralph 削除）と同じ向きである

### 2.11 steipete のツール群と OpenClaw

- agent-scripts（スター約 7.5k、コミット 708） `[verified]` https://github.com/steipete/agent-scripts
  - README の自己紹介が「共有のエージェント規則・スキル・小さな補助スクリプトの正本の置き場」になった。中心は `skills/<name>/SKILL.md` と、それを Codex と Claude Code の両方へ機械ごとにリンクする `scripts/sync-skills`
  - 2026-02 に現役と書いた AGENTS.MD のポインター方式と `docs-list.ts`（`summary` と `read_when` の front matter）は残っている。committer は今回の README の要約には出てこなかった（有無は未確認）
- Oracle（スター約 4.1k、v0.23.0） `[verified]` https://github.com/steipete/oracle 、https://github.com/steipete/oracle/releases
  - 「Bring a second brain, not a second briefing」。プロンプトと選んだファイルを束にしてモデルへ送り、結果をセッションとして `~/.oracle/sessions` に残す CLI + MCP サーバー
  - エンジンは API、ブラウザ（ChatGPT の Chrome 自動操作と、Cookie を使う Gemini クライアント）、render（束をローカルで作るだけ）の3つ。`--models` で複数モデルのパネルを回し、モデルごとの使用量・費用・出力・部分的な失敗を1セッションに記録する
  - 裏で完走させて、あとから状態確認・再接続・再実行・追い質問ができる。v0.23.0 は「孤児になったセッションをすぐ失敗として報告する」修正を含む
- mcporter と Peekaboo は `openclaw` 組織へ移った（`steipete/` の URL から転送される）。mcporter は MCP の 2026-07-28 版への対応、暗号化した OAuth の保管庫、`record` / `replay` を足した。Peekaboo は 4.9.8 `[verified]` https://github.com/steipete/mcporter 、https://github.com/steipete/Peekaboo
- OpenClaw（スター約 394k、フォーク約 82.9k、コミット 127,328） `[verified]` https://github.com/openclaw/openclaw 、https://github.com/openclaw/openclaw/releases
  - 開発主体は OpenClaw Foundation（独立の 501(c)(3)）。README は「OpenAI は寄付者であって所有者ではない」と明記している
  - README は Claude や Codex などの「agent harness」を差し替え可能なプラグインとして説明する
  - 2026.11.1（2026-11-05）のリリースノート: サブエージェントへの追い指示がモデルやセッションの変更をまたいで残る。子の承認要求が親セッションへ届く。Claude CLI については「ネイティブの Agent と Workflow の統括はオプトインの設定で、既定はオフ」。compaction をまたいでも「いま生きている人の依頼」を保つ
- 読み方 `[speculation]`
  - 2026-02 に「小さな単機能 CLI を tmux で手で束ねる」と書いた実践は、スキルの配布（agent-scripts）とセカンドオピニオン（Oracle）に絞られて伸びた。手動の tmux 統括そのものを支える道具は増えていない
  - Oracle は利用者のエンジンの (4)（別ベンダーのセカンドオピニオン）にいちばん近い既製品で、9か月たっても同じ形（束を作る → 複数モデルへ投げる → セッションとして残す）を保っている
  - OpenClaw が Claude CLI の「ネイティブの Agent と Workflow の統括」を既定オフのオプトインにしているのは、外側の統括と内側の公式統括が二重になるのを避ける判断に見える。利用者のエンジンでも同じ二重化の問題が起こり得る

## 3. Claude Code 公式機能の現在地（追従を測るための物差し）

詳しい時系列と仕様は `phase2-external.md` の2章にある。ここでは、上の各ツールが「公式に乗ったか、乗らなかったか」を読むために必要な点だけを、公式ドキュメントで確かめて並べる。

| 機能 | 現在の位置づけ | 追跡に関係する要点 | 根拠 |
| --- | --- | --- | --- |
| Subagents | 一般提供 | 1セッションの中の委譲。Claude が名前を付けたサブエージェント同士はメッセージできる | `[verified]` https://code.claude.com/docs/en/agent-teams |
| Agent teams | いまも実験的で既定は無効（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`） | mailbox は `~/.claude/teams/{team-name}/inboxes/{agent-name}.json`。制限として「Lead is fixed（リードは替えられない）」「1セッション1チーム」「入れ子のチームなし」「`/resume` でインプロセスの teammate は戻らない」。`-p` と Agent SDK では teammate を起こせない | `[verified]` 同上 |
| Cross-session messaging | v2.1.224 以降は設定なしで有効 | 自分の別セッションを `ListAgents` で見つけ `SendMessage` で送る。同じマシンではセッションごとの Unix ソケットで運び、Anthropic のサーバーを通らない。受け手は走行中ならツール呼び出しの合間に読み、idle なら新しいターンが始まる。メッセージは人の同意の代わりにならず、設定も変えられない。平文のみ。ソケットのパスは hook と Bash に `CLAUDE_CODE_MESSAGING_SOCKET` として渡され、スクリプトから自分のセッションへ書ける。相手が idle になったら1回知らせる `notify_when_idle` がある | `[verified]` https://code.claude.com/docs/en/cross-session-messaging |
| Agent view（バックグラウンドセッション） | research preview | `claude agents` の1画面で、裏で走るセッションを出す・見る。状態は Working / Needs input / Idle / Completed / Failed / Stopped。別プロセスの supervisor がセッションを走らせ、端末を閉じても続く。落ちたプロセスは supervisor が再起動する。状態はディスクに残る。Needs input になると `Notification` hook が `agent_needs_input` で発火する。マシンを止めればセッションも止まる | `[verified]` https://code.claude.com/docs/en/agent-view |
| Dynamic workflows | 有料プランで利用可 | 計画を JavaScript のスクリプトが持ち、ランタイムが多数のサブエージェントを裏で回す。既定で同時16、1回の実行で合計 1,000 まで。「実行の途中で人の入力は取れない。段の間で承認が要るなら段ごとに別のワークフローにする」。同じセッション内なら resume できる | `[verified]` https://code.claude.com/docs/en/workflows |
| 5つの並べ方の比較 | — | 公式は「どの方式でも worker は Claude のセッションである。別のツールを巻き込むなら MCP サーバーとして Claude に見せる」と書く | `[verified]` https://code.claude.com/docs/en/agents |

公式のドキュメント索引には、handoff（世代交代）を題にしたページが無い。compaction と checkpointing（編集の巻き戻し）のページはある `[verified]` https://code.claude.com/docs/llms.txt

## 4. 汎用フレームワークの追跡（薄く）

| ツール | 状態 | 9か月の変化 | 根拠 |
| --- | --- | --- | --- |
| LangGraph | 活発。約 44.8k、langgraph 1.2.20 | 1.x 系に入った。README は「状態を持つエージェントのための低レベルの統括フレームワーク」と書き、計画とサブエージェントを使う上位パッケージ Deep Agents へ誘導する。直近の版は `interrupt()` ごとに ID を与え、古い割り込み回答を拒む厳格な resume を足した | `[verified]` https://github.com/langchain-ai/langgraph 、https://github.com/langchain-ai/langgraph/releases |
| Mastra | 活発。約 29.4k、@mastra/core 1.82.0 | 1.x 系。README は人の介在による suspend / resume を前面に出す。直近は「API の再起動をまたいで走り続ける durable agents」「再開できるバックグラウンドタスク」。リポジトリに `mastracode` ディレクトリがある（中身は未確認） | `[verified]` https://github.com/mastra-ai/mastra 、https://github.com/mastra-ai/mastra/releases |
| ControlFlow | 停止。約 1.4k | アーカイブ済み。ページの告知は「archived by the owner on Mar 19, 2026」で、次世代のエンジンは Marvin に統合したと書く。2026-02 の個票は「2025年8月にアーカイブ」としており、日付が食い違う（どちらが正しいかは未確認） | `[verified]` https://github.com/PrefectHQ/ControlFlow |
| Marvin | 小さく保守。約 6.2k、3.2.10 | 3.2 系の小刻みな更新が続く。ページに保守状況の告知は無い | `[verified]` https://github.com/PrefectHQ/marvin 、https://github.com/PrefectHQ/marvin/releases |
| AutoGen | 停止。約 61.8k | アーカイブ済み。「Project archived and no longer maintained」「バグ修正もセキュリティ修正も提供しない」。新規は Microsoft Agent Framework から始めるよう案内。2026-02 の「メンテナンスモード」から一段進んだ | `[verified]` https://github.com/microsoft/autogen |
| Microsoft Agent Framework | 活発。約 14.6k、python-1.25.0 / dotnet-1.28.0 | 1.x 系で .NET と Python の両方を週次に近い間隔で更新。直近は MCP の承認ポリシーや A2A まわり | `[verified]` https://github.com/microsoft/agent-framework 、https://github.com/microsoft/agent-framework/releases |
| CrewAI | 活発。約 60.7k、1.15.39 | 1.x 系。Crews（役割ベースの自律チーム）と Flows（イベント駆動の制御）の二本立ては変わらない | `[verified]` https://github.com/crewAIInc/crewAI 、https://github.com/crewAIInc/crewAI/releases |
| OpenAI Agents SDK | 活発。約 30.6k、v0.24.0 | README に、コンテナで長い仕事を回す sandbox agents、実行をまたぐ sessions、人の介在の仕組みが加わった。handoff と agents-as-tools は変わらず | `[verified]` https://github.com/openai/openai-agents-python 、https://github.com/openai/openai-agents-python/releases |
| Google ADK | 活発。約 22.2k、v2.14.0 | 「ADK 2.0」を掲げ、グラフベースの Workflow Runtime と、エージェント間の委譲のための Task API を前面に出す。直近の版で sandbox・A2A・評価のモジュールを安定化 | `[verified]` https://github.com/google/adk-python 、https://github.com/google/adk-python/releases |
| MetaGPT | 停止に近い。約 71.2k | 最新のリリースは v0.8.1（4月22日。年はページに無く、内容から 2024 年と推定）。`main` の最終コミットは 2026-01-21、その前は 2025-11-12。README の最新ニュースは 2025-03-10。商用の MGX へ誘導している | `[verified]` https://github.com/FoundationAgents/MetaGPT 、https://github.com/FoundationAgents/MetaGPT/commits/main |
| BeeAI | 小さく活発。約 3.5k、typescript_v0.1.32 | 「本番で使えるマルチエージェントを Python か TypeScript で」。大きな方針転換は見えない | `[verified]` https://github.com/i-am-bee/beeai-framework 、https://github.com/i-am-bee/beeai-framework/releases |
| PydanticAI | 活発。約 21.1k、v2.66.0 | 2.x 系。README は「the Python AI SDK」を名乗り、9種のエンジンでの durable execution、Pydantic Graph、記憶やサブエージェントを足す Pydantic AI Harness を挙げる | `[verified]` https://github.com/pydantic/pydantic-ai 、https://github.com/pydantic/pydantic-ai/releases |
| Agent Squad | 低調。約 7.8k、TypeScript 1.1.5 | `awslabs/agent-squad` から `2FastLabs/agent-squad` へ移った（「New home」の告知）。最終コミットは 2026-10-02。スターはほぼ横ばい | `[verified]` https://github.com/awslabs/agent-squad 、https://github.com/2FastLabs/agent-squad/commits/main |
| PentAGI | 活発。約 33.9k、2.2.0 | スターが約5倍。2.2.0 はサンドボックス隔離の作り直し（CVE 対応）、Web 検索ツールの統合など | `[verified]` https://github.com/vxcontrol/pentagi 、https://github.com/vxcontrol/pentagi/releases |

PentAGI と同じ個票にあった Orca（`santiagomed/orca`、Rust の LLM パイプライン）は、スター 286、最終コミットが 2024-03-14 で、2026-02 の「開発停止」のままである `[verified]` https://github.com/santiagomed/orca/commits/main

汎用フレームワークの群に共通する動き `[speculation]`

- 「途中で止めて、あとで続きから」が各社の看板になった（LangGraph の厳格な resume、Mastra の durable agents、PydanticAI の durable execution、OpenAI の sessions と sandbox agents）
- 2026-02 に移行中だった2件（AutoGen、ControlFlow）はどちらもアーカイブで決着した
- 役割を演じさせる系の古参（MetaGPT）は止まり、グラフやスクリプトで流れを固定する系（LangGraph、ADK 2.0 の Workflow Runtime）が伸びた

## 5. この群から読めること（10項目）

以下は 1〜4 章の事実からの読み取りであり、すべて `[speculation]` である。各項目に、もとにした事実の節を添える。

1. 近縁ツールは一つも消えておらず、スターは数倍から20倍になった。ただし「同じ形のまま伸びた」ものは少ない
   - 止まったのは o-m-cc（凍結）、Aider（リリース1年なし）、SWE-agent（後継へ）、AutoGen と ControlFlow（アーカイブ）、MetaGPT である
   - 伸びたものの多くは改名・移転・作り直しを伴っている（agent-orchestrator、oh-my-openagent、Ruflo、OpenHands の Agent Canvas）。この分野では9か月で土台ごと替わるのが普通で、利用者のエンジンが形を変えること自体は特別ではない（2.2、2.5、2.7、2.8）
2. 「tmux の画面を生の正規表現で読む」設計は消えた。tmux そのものは残った
   - agent-orchestrator は tmux を legacy に下げ、PTY とプロトコル制御（Chat モード、ACP）へ移った。CAO は tmux を保ったまま、端末エミュレータで描画した画面を読む方式に替えた。TAKT は SDK が主で、tmux は `claude-terminal` という脇の経路である。OMC は他社 CLI を起こす用途で tmux を使い続けている（2.1〜2.4）
   - 利用者のエンジンは受領の印を hook で取っており、画面読みに頼る度合いは CAO より低い。hook の事実を使う方向は agent-orchestrator と同じである
3. メッセージの運び方は「キューにためて、ターンの切れ目にまとめて渡す。割り込みは別扱い」に収束した。ここは公式へ寄せられる第一候補である
   - agent-orchestrator（ターン終了時にまとめて配送、steer は別）、OmO（steer が既定、キューは例外）、CAO（イベント駆動の inbox、質問ダイアログ中は保留）、公式の cross-session messaging（ツール呼び出しの合間に読む、idle なら新しいターン）が同じ形をしている（2.2、2.3、2.5、3章）
   - 公式はセッションごとのソケットを hook と Bash に渡しており、スクリプトから書ける。send-keys と受領の印を置き換えられる可能性がある。ただし平文のみで、メッセージは人の同意の代わりにならず、相手は Claude Code のセッションに限られる
4. 状態と登記は、フラットファイルから「SQLite + 変更の追記ログ」か「永続のジャーナル」へ移った
   - agent-orchestrator は bash 版との互換のために持っていた `key=value` と JSONL を捨てた。CAO はワークフローにジャーナルと決定的なリプレイを足した（2.2、2.3）
   - 借りられる規律は3つある。表示用の状態は保存せず読むときに計算する。終了の判定は実行基盤とプロセスの両方で確かめる。確認待ちをクラッシュと取り違えない（OMC v5.8.0 も同じ修正をしている）
5. 監視と復帰は「常駐の supervisor が子を走らせ、落ちたら保存済みの会話から起こし直す」が標準になり、公式にも入った
   - 公式の agent view の supervisor、agent-orchestrator の Go デーモン、TAKT の manager デーモン、CAO のサーバー（単一インスタンスロックつき）が同じ役を持つ（2.1〜2.3、3章）
   - 子の生存監視と再起動は、公式の agent view に寄せられる候補である。ただし research preview であり、マシンを止めれば止まる
6. 統括の座の排他（lease）と、文脈が尽きたときの統括の世代交代は、この群のどこにも無い。独自に残る
   - 公式の agent teams は「リードは替えられない」と明記し、公式の索引に handoff のページは無い。外部ツールで近いのは、o-m-cc の `/handoff`（別マシンへ移すための日誌）、TAKT の「エラー時は新しいセッションで1回再試行」、OpenClaw の「compaction をまたいで人の依頼を保つ」で、どれも統括の交代ではない（2.1、2.6、2.11、3章）
   - 外部ツールの多くは、統括を「長く生きる1つの対話セッション」にしないことで問題を避けている。agent-orchestrator と TAKT は状態を DB やファイルに置き、統括の会話は取り替えのきくものとして扱う。世代交代を磨き続けるか、統括の持つ文脈を登記へ逃がして交代を軽くするかは、方向を決めるときの分かれ目になる
   - 21ツールの外では Gas Town が `gt handoff` を持つ（`phase2-external.md` の1章）
7. 人の判断待ちは「Needs you のレーン + 通知」までが標準になった。選択肢と根拠を付けて1枚に集める形は見当たらない
   - agent-orchestrator のかんばんとスマホ通知、公式 agent view の Needs input、OpenHands の Agent Canvas、CAO の `cao workflow approve` は、どれも「どのセッションが止まっているか」を見せるもので、問いは各セッションの中にある（2.2、2.3、2.8、3章）
   - いちばん近いのは TAKT の director（複数の manager の未回答の問いを見回って人に知らせる）だが、実験的で、選択肢や根拠の型は README からは読めない（2.1）
   - 判断ボードは独自に残る。ただし「止まっているセッションの検知」は公式の `Notification` hook（`agent_needs_input`）や Needs input の状態を入力に使える
8. 外部の統括ツールの差別化は「他社の CLI を束ねられること」に寄った。公式はここを扱わない
   - 対応数は agent-orchestrator 約36、CAO 12、TAKT 11、OMC 6。公式は「worker は Claude のセッション。別のツールは MCP で」と線を引いている（2.1〜2.4、3章）
   - 利用者のエンジンの (4)（Codex によるセカンドオピニオン）は公式に吸収されない領域で、Oracle が同じ形のまま伸びていることが裏づけになる。OMC の `omc team` と TAKT のペルソナ単位のプロバイダー割り当ては、委譲先そのものを他社 CLI にする方向の参考になる
9. 公式に吸収されたのは、プラグイン層がやっていた「Claude 同士の協調」である。プラグインは協調を手放し、強制と判断へ退いた
   - o-m-cc は凍結し、後継の flywheel は協調を公式の subagents と workflows に任せて「設計が通るまで実装させない」hook だけを持つ。OMC は MCP ブリッジを消し、判断を外部サービス（Jev）へ出した。OpenClaw は Claude CLI のネイティブな統括をオプトインで使う（2.4、2.6、2.11）
   - 消えた設計は、中央を置かない P2P の協調（o-m-cc）、他社 CLI を MCP サーバーで包む経路（OMC）、他人のホストのプラグインとして生きること（OmO）、役割を演じさせる合議（MetaGPT）である
   - 伸びた設計は「計画をモデルの気分ではなくスクリプトやワークフロー定義が持つ」ことである（TAKT、CAO の workflow、公式の dynamic workflows、ADK 2.0、flywheel）。ただし公式の workflows は実行の途中で人の入力を取れないので、判断待ちを挟む流れには別の仕組みが要る
10. 利用者のエンジンへの示唆をまとめると、寄せる所は配送・生存監視・検知、残す所は座の排他・世代交代・判断ボード・別ベンダーの意見である
    - 寄せられる所: 子への配送と受領（公式のソケットと `SendMessage`）、子の生存監視と再起動（agent view の supervisor）、止まっている子の検知（Needs input と `Notification` hook）、作業場の隔離（worktree）
    - 独自に残る所: 統括の座の lease と世代交代、判断ボード（選択肢と根拠つきの1枚）、Codex のセカンドオピニオン、tmux で人が子をそのまま覗ける運用
    - 寄せるときの注意: 公式の該当機能は research preview（agent view）や実験的（agent teams）が多く、要件の版も v2.1.224 から v2.1.319 まで細かく動いている。外部ツールが公式に深く乗らず（OMC は agent teams だけ、TAKT と CAO は乗っていない）、自前の層を保っているのは、この動きの速さへの備えにも見える。寄せるなら薄い差し替え口を挟み、Bash + jq の規模で保てる範囲にとどめるのが安全である
    - 作り替えるなら見る先: 構造が近いまま進んだ CAO（tmux + inbox + SQLite + ワークフローの承認）と、同じ出発点から作り替えた agent-orchestrator（デーモン + SQLite + 変更ログ）の2つが、行き先の両端を示している

## 6. 追加で調べる候補

- TAKT の `takt manager` / `takt director` の inquiry の型（選択肢や根拠を持つか）。判断ボードとの比較に要る。README の該当節とソースを開く
- CAO の「Enter の送り直し」と「質問ダイアログ中の保留」の実装（`CHANGELOG.md` の Unreleased 節と `clients/tmux.py`）。send-keys の受領確認の比較に要る
- agent-orchestrator の移転の経緯と、安定版の最新。`docs/architecture.md` の「controller handoff」の節（制御の引き継ぎを起動時に突き合わせる処理）は、世代交代の実装の参考になるかもしれない
- 公式の cross-session messaging のソケットへ hook から書く経路を、利用者のエンジンの受領の印の代わりに使えるかの実機確認（`phase2-external.md` の 2.2 と合わせて）
- OpenHands の SDK の文書サイトにあるサブエージェント委譲の仕様（今回は README までで、記述は見つからなかった）

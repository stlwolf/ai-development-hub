# Phase 2 外部状況調査メモ: セッション管理層とエージェント向け端末基盤（2026-11-10）

- 調査日: 2026-11-10（数字はすべてこの日に取得した概数）
- 目的: 「複数のコーディングエージェントのセッションを並べ、状態を見て、入力を送る」層の OSS と、エージェント向けの端末・セッション基盤の現状を横断的に把握し、自作エンジン（tmux の send-keys / capture-pane / hook / cockpit）の今後を決める材料にする
- 対象外: 統括が子へ委譲する階層型オーケストレータ（Gas Town など）は別担当。境目のもの（agent-deck の conductor、hcom、Cyclops など）は入れた
- 方法: WebSearch と WebFetch。リポジトリの README・docs・Releases を優先して開いた。検索語と外部リクエストに利用者の名前・メール・リポジトリ名は入れていない
- 前回メモ `docs/draft/618-engine-research/phase2-external.md` の 1 節を前提とし、そこで扱ったツールは更新点と未確認の埋め直しだけを書く

## 0. 検証ステータスの読み方と、取得できなかったもの

### 0.1 ステータス

- `[verified]`: 自分で一次ソースのページを開いて確かめた（URL つき）。ただし WebFetch は「ページを小さなモデルが要約した結果」を返すので、原文の一字一句までは保証しない
- `[unverified-summary]`: 検索結果の要約や awesome リストなど二次情報（URL つき）
- `[speculation]`: 推測
- 表では、行の末尾の「根拠」列の URL を開いて確かめた内容を既定で `[verified]` とし、そうでないセルだけ個別に印を付ける

### 0.2 取得できなかったもの・制約

- GitHub のリポジトリページは「Releases」「Languages」欄が空で返ることが多い。最新リリースは Releases ページを別に開けたものだけ日付を書いた
- Releases ページの日付は「07 Nov」のように **年が出ない** ものが多い。前後関係から 2026 年と読んだものはその旨を書いた。container-use だけは 2025 年の可能性が残る（後述）
- リポジトリの **作成日** はページから取れない。「2026 年 6 月以降の新顔」は、最古のタグや可視範囲の最古コミットで裏づけたものと、裏づけられなかったものを分けて書いた（4 節）
- 404 などで開けなかったページ
  - `github.com/herdrdev/herdr/blob/master/docs/socket-api.md`（`herdr.dev/docs/socket-api` は開けた）
  - `www.conductor.build/docs/reference/api`（Conductor の API リファレンス）
  - `www.agent-of-empires.com/docs/guides/status-detection/`（AoE の tmux モードの状態検出の方式は未確認のまま）
  - `github.com/manaflow-ai/cmux/blob/main/CHANGELOG.md`（途中で切れた。`cmux.com/docs/changelog` は開けた）
- README が 10 万文字を超え、後半を読んでいないもの: workmux、agent-deck、awesome-cli-coding-agents
- 一次情報を開いていないもの: Ghostty のリリースノート、Warp のサードパーティエージェント対応の詳細、Happy の内部構成、VS Code の Agent Host の設計記事、Zenn の crmux 以外の記事の多く
- Qiita は有用な記事に当たらなかった（Zenn は 2 本開いた）

## 1. 先に結論（要約）

- **状態の検出は「各 CLI の hook による自己申告」が主流になった**。画面読みは「hook を持たない CLI の代替」と「hook では取れない承認ダイアログの検出」に役割が縮んだ。ただし完全には置き換わっておらず、herdr は 2026-10 に Codex の hook を外して画面検出へ戻している
- **入力の送信は「端末へ打ち込む」ままのツールが多数派**。変わったのは打ち込みの外側で、(1) ソケット / HTTP の API にして応答を返す、(2) 送信と「状態が変わるまで待つ」を 1 回の要求にまとめる、(3) hook イベントの発生で「受け取られた」ことを確かめる、の 3 点が 2026 年後半に出そろった
- **「届いたか」を正面から定義しているのは少数**。Cyclops（4 段階の配送状態）、Superset の `terminals send --wait`（10 秒以内に hook イベントが出なければ失敗）、herdr の `agent.prompt` + `wait`、agent-deck の送信まわりの修正群が参考になる
- **構造化プロトコル（ACP）で端末を介さず動かす道** は AoE の「structured view」が実装した。ただしエージェントごとの対応差が大きく、端末表示と併用の位置づけ
- 利用者のエンジンに近いのは「tmux の上に薄く乗る」群（agent-deck、workmux、AoE、Cyclops、tmux-agent-sidebar）。「tmux ごと置き換える」群（herdr、tuios、pando、cmux）は API が最も整っているが、乗り換えの代償が大きい

## 2. 前回の未確認の埋め直し

| 項目 | 前回 | 今回わかったこと | 根拠 |
| --- | --- | --- | --- |
| herdr 本家のスター数と活発さ | 未確認（フォークしか開けず） | 約 49.9k スター、フォーク 4.0k、1,880 コミット、issue 446 / PR 26。最新は v0.9.5（10 月 14 日、年は出ないが 2026 と読める）で、9〜10 月に v0.9.2〜v0.9.5 とプレビュー版が続く。活発 | https://github.com/herdrdev/herdr 、https://github.com/herdrdev/herdr/releases |
| herdr のライセンス | AGPL-3.0-or-later + 商用（フォークの記述） | 本家の `LICENSE` は **Apache-2.0**。商用ライセンスの記述は見当たらない。フォーク時点から変わった可能性がある `[speculation]` | https://github.com/herdrdev/herdr/blob/master/LICENSE |
| cmux の最終リリース | 未確認 | 安定版 0.65.2.2（2026-10-27）、0.65.2（2026-10-14）、0.65.1（2026-10-12）。GitHub の Releases は nightly と FFI ビルドが 11 月 10 日まで並ぶ。約 28.8k スター | https://cmux.com/docs/changelog 、https://github.com/manaflow-ai/cmux/releases |
| CCManager の最終リリース | 未確認 | v4.4.11（10 月 27 日。年は出ないが Grok Build 対応などから 2026 と読める）。10 月だけで v4.4.7〜v4.4.11。活発 | https://github.com/kbwo/ccmanager/releases |
| uzi の最終コミット | 未確認 | **2025-06-04** が最新。1 年以上止まっている。新規採用の対象から外してよい | https://github.com/devflowinc/uzi/commits/main |
| container-use の最終リリース | 未確認 | v0.4.2（8 月 19 日、年は出ない）。総コミット 331 と少なく、2025 年 8 月の可能性がある `[speculation]`。年は未確認 | https://github.com/dagger/container-use/releases |
| Conductor の一次情報 | 二次情報のみ | 公式 docs を開けた。Mac で動かす。Claude Code、Codex、Cursor、OpenCode を並列実行し、タスクごとに「workspace, branch, files, terminal, diff, and review path」。「Conductor API」のリファレンスへのリンクがあるが中身は開けず。価格、ライセンス、状態検出、復帰は未確認 | https://www.conductor.build/docs/ |
| Superset の一次情報 | 二次情報のみ | リポジトリを開けた。約 16.2k スター、MIT、5,519 コミット。**製品名が Paradev に変わっている**（docs が `docs.paradev.com` へ転送され、README も Paradev 表記。CLI のコマンド名は `superset` のまま）。詳細は 3.2 | https://github.com/superset-sh/superset 、https://docs.paradev.com/ |
| Vibe Kanban の終了後 | 「sunsetting」と二次情報 | 運営会社 bloop は **2026-04-10 に停止**。リモートサービスは 30 日後に終了し、完全ローカル構成へ移行。「open source and community maintained」として続けると明記。README は今も冒頭に sunsetting と書く。約 28.6k スター。その後のコミット日とコミュニティ版のロードマップは未確認 | https://vibekanban.com/blog/shutdown 、https://github.com/BloopAI/vibe-kanban |
| Crystal → Nimbalyst | 「Nimbalyst は有償のクローズドソース」（二次情報） | **誤りだった**。Nimbalyst は MIT のオープンソースで、リポジトリが公開されている（約 2.1k スター、6,818 コミット）。Crystal は 2026-02 に deprecated のまま | https://github.com/stravu/crystal 、https://github.com/Nimbalyst/nimbalyst |
| AoE の更新 | v1.22.3、ACP の気配 | HTTP API と CLI の送信・待機、ACP の structured view の中身を確かめた。詳細は 3.1 | https://www.agent-of-empires.com/docs/api/ |

## 3. ツール別の調査

### 3.1 tmux の上に乗る群

#### 基本情報

| ツール | スター（2026-11-10） | 言語 / ライセンス | 最新リリース・活発さ | 土台と隔離 | 対応 CLI | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| Agent of Empires（AoE） | 約 4.0k | Rust / MIT | v1.22.3（2026-11-08、前回メモ）。ほぼ週次 | エージェントごとに tmux セッション + worktree。ACP 対応エージェントは tmux を使わない structured view も選べる | Claude、Codex、OpenCode、Gemini、Vibe、Pi ほか | https://github.com/agent-of-empires/agent-of-empires |
| agent-deck | 約 1.2k | Go / MIT | v1.16.38（11 月 7 日、年は 2026 と読める）。4,559 コミット。非常に活発 | tmux。専用の tmux サーバー（`socket_name`）に分離できる。`--worktree` | Claude Code、Gemini、OpenCode、Codex、Copilot、Cursor、pi ほか 13 種 + 任意 | https://github.com/asheshgoplani/agent-deck 、https://github.com/asheshgoplani/agent-deck/releases |
| workmux | 約 3.0k | Rust / MIT | v0.1.281（11 月 8 日、2026 と読める）。2,508 コミット。ほぼ毎日リリース | tmux が基本。**kitty、WezTerm、Zellij も backend に選べる**。タスクごとに worktree + window | Claude Code、OpenCode、Codex、Copilot CLI、Pi、Gemini、Grok ほか | https://github.com/raine/workmux 、https://github.com/raine/workmux/releases |
| dmux | 約 1.8k | TypeScript `[speculation]` / MIT | リリース日は未確認。747 コミット | tmux 3.0 以上 + ペインごとに worktree | Claude Code、Codex、OpenCode、Gemini、Cursor ほか 11 種 | https://github.com/standardagents/dmux |
| amux（mixpeek） | 約 557 | Rust（サーバー）/ MIT + Commons Clause | リリース日は未確認。9,524 コミット | tmux 3.2 以上。Web ダッシュボードと iOS アプリ | Claude Code、Codex、Gemini、OpenCode、Ollama | https://github.com/mixpeek/amux |
| Cyclops | 14 | 未確認 / MIT | v1.1.0（2026-09-05）。最古のタグは 2026-08-01。952 コミット | tmux。デーモン `cyclopsd` が mailbox と配送を持つ | 実機で測定済みは Claude Code、Codex、Antigravity、Cursor Agent、Kimi の 5 種。47 種は「unverified」と明記 | https://github.com/cyclops-team/cyclops 、https://github.com/cyclops-team/cyclops/tags |
| thurbox | 約 117 | Rust `[speculation]` / MIT | v2.83.6（2026-11-05）。1 日に複数回リリース。1,790 コミット | tmux 3.2 以上（Windows は psmux）。SSH 越しのリモートセッション | Claude Code、Codex、Antigravity、opencode、aider、任意 | https://github.com/Thurbeen/thurbox 、https://github.com/Thurbeen/thurbox/releases |
| Claude Squad | 約 8.8k（前回） | Go / AGPL-3.0 | 2026-08-20 以降の更新は今回確認していない | tmux + worktree | 前回のとおり | 前回メモ |

#### 状態の検出・入力の送信・復帰

| ツール | 状態の検出 | 入力を送る口と到達確認 | 復帰・resume | エージェント間・親子 |
| --- | --- | --- | --- | --- |
| AoE | tmux モードの方式は未確認（説明ページが 404）。デーモンが状態を持ち、購読者がいれば 500 ms、いなければ 2 秒ごとにサンプリング。状態は `Starting` / `Running` / `Waiting` / `Idle` / `Error` / `Stopped` ほか。structured view では ACP のイベントで状態が届く | `aoe send <id> <msg>` と `POST /api/sessions/{id}/send`。応答 `{"sent": true}` は **「tmux ペインへキーを届けた」まで** の意味と明記。その後は `aoe session wait --until idle` か `GET /api/sessions` のポーリング、または `callback_url` への POST で確かめる。ACP 側は `aoe acp prompt` / `approve` / `cancel` / `tail`（JSON lines） | tmux セッションが残るので再接続で元どおり。`aoe send` は死んだセッションを既定で起こし直す（`--no-revive` で抑止）。`session set-session-id` で resume 先を指定、`add --fork-from` で会話を分岐 | なし。ただし docs は「送信 → Idle までポーリング → 出力を読む」を「subagent として駆動する手順」として示す |
| agent-deck | 混在。Codex は notify hook、pi は拡張で turn イベントを報告。hook が無いと「read from the pane, which is slower and occasionally wrong」と作者が書く。v1.16.37 に「Codex のホーム画面ロゴ（点字アート）をスピナーと誤認していたのを除外」 | `agent-deck session send <name> --message-file task.md`。リリースノートが送信の失敗例の一覧になっている: Enter 前の待ち時間の拡大、「composer に残った recovery turn は Enter を再送」、「止まった Claude のキューを delivered と報告していたのを修正」、OpenCode 2 は「unconfirmed delivery」を再送せず報告 | fork（各 CLI のネイティブ fork）、archive して会話を保持、`R` で再開 | **あり**。conductor（ほかのセッションを監視・指揮する常駐セッション、`--parent`）。standing orders（監視コマンドの出力が変わったときだけ conductor を起こす）。Telegram / Slack / Discord 連携 |
| workmux | `workmux setup` が各 CLI に **status hook を入れる**。tmux の window 名にアイコン（working / waiting / done）。working のまま 10 秒ペイン出力が無いと「interrupted」と見なす | 生成時にプロンプトを注入（`workmux add -p`）、追記は `workmux open --continue -p`、ダッシュボードの入力モード。独立した send コマンドと到達確認は README の読んだ範囲に無い。`workmux status --json`、`add --wait` | `workmux resurrect` が、クラッシュ前にエージェントが動いていた worktree を `--continue` で開き直す | メッセージ機能は無い。`/worktree` スキルで worktree エージェントへ委譲、fan-out（`-n`、`--foreach`、`--max-concurrent`） |
| dmux | 方式は README に無い。LLM による「pane analysis」（任意）と、落ち着いて人を待つペインの通知がある | 初期プロンプトのみ記載。追送の口は未確認 | ペイン再作成時に対応エージェントの会話を resume | 未確認 |
| amux | 未確認 | REST API の記載は README に無い。使用量上限に当たると配送を保留し、リセット時刻に再開 | サーバーはクラッシュしたエージェントを再起動しない。任意の macOS 用 `scripts/tmux-watchdog.sh` が Claude の worker だけ再起動。macOS では再起動後に会話を resume | **あり**。エージェント同士が質問・引き継ぎのメッセージを送る。タスクカードの claim は atomic |
| Cyclops | `resources/manifests/` の manifest が「端末の見た目（chrome）をデータとして」記述。状態は idle / working / gating / blocked / failed。**「Agent activity and the composer are separate questions」** とし、composer（入力欄）の検査で doorbell を待たせるか決める | **配送状態を 4 段階に分ける**: Accepted（journal に fsync 済み）→ Notified（doorbell を書き込み submit した）→ Claimed（受信側が本文を取り出した）→ Completed（受信側の明示的な返信）。ペインへ打つのは 1 行の要約と claim コマンドだけで、本文は mailbox に置く。不確かな結果は `submitted_unverified` / `attention_required` として記録し、タイマーでの再送はしない | 未確認（journal は append-only） | **あり**（mailbox そのもの） |
| thurbox | 未確認 | ヘッドレスの `thurbox-cli` がセッションの作成・駆動・capture・破棄を行う。エージェント非依存の mailbox で「相手の端末を scrape せずに」受け渡す | セッションは multiplexer に残り、再実行で再接続。「survive crashes, restarts and reboots」 | **あり**（mailbox と `thurbox-sessions` スキル） |

- 根拠（上の表）
  - AoE: https://www.agent-of-empires.com/docs/api/ 、https://www.agent-of-empires.com/docs/cli/reference/ 、https://www.agent-of-empires.com/docs/structured-view/
  - agent-deck、workmux、dmux、amux、Cyclops、thurbox: 基本情報の表の URL

#### AoE の structured view（ACP）についての補足 `[verified]`

- 「AoE is the client of the Agent Client Protocol (ACP), and the agent is the server.」
- ACP で動くのは Claude（`claude-agent-acp`）、Codex（`codex-acp`）、OpenCode（`opencode acp`）、Gemini（`gemini --acp`、非推奨）、Vibe、Pi、Kimi ほか。Aider、Cursor、Copilot、Droid、Hermes、Kiro は端末表示のみ
- 明記された制限
  - Node.js 22 以上が要る。無ければ端末表示へ落ちる
  - Claude 以外は、structured と端末を切り替えると **会話が新しく始まる**
  - sandbox 内の Claude の `Workflow` 実行は追跡されず、「エージェントが動いているのに idle と出る」ことがある
  - アダプタごとに使える操作が違う（Codex に Plan モードの経路が無い、など）
  - `POST /api/sessions/{id}/send` は structured view のセッションに対して `400 acp_mode_unsupported` を返す。**tmux 用の口と ACP 用の口は別**
- 出典: https://www.agent-of-empires.com/docs/structured-view/ 、https://www.agent-of-empires.com/docs/api/

### 3.2 tmux を使わず、自前の PTY とデーモンを持つ群（端末の中で動くもの）

| ツール | スター / 言語 / ライセンス | 最新・活発さ | 状態の検出 | 入力を送る口と到達確認 | 復帰 | 対応 CLI・ほか | 根拠 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| herdr | 約 49.9k / Rust / Apache-2.0 | v0.9.5（10 月 14 日）。活発 | **自己申告と画面検出の二本立て**。統合（integration）が `pane.report_agent` で状態を申告。画面検出の規則は agent manifest にあり、`agent.explain` が「どの規則に当たったか、idle に落ちた理由」を返す。「a full lifecycle hook authority makes screen rules non-authoritative」。一方 v0.9.5 で **「Herdr no longer installs Codex turn hooks. Codex status comes from screen detection again.」** | Unix ソケット（Windows は named pipe）上の改行区切り JSON。`pane.send_text` / `pane.send_keys` / `pane.send_input`、`agent.prompt`（`wait` を付けて送信と待機を 1 要求にでき、競合を避ける）、`agent.wait`（「server-owned and event-driven」、対象ペインの占有者を固定）、`pane.read`（`detection` ソースで検出に使った画面を読める）、`events.subscribe`（`pane.agent_status_changed` など）。到達確認は **「acknowledge queue admission, not command execution」** と明記 | バックグラウンドサーバーが端末を保持。サーバーやマシンの再起動では「the original processes do not survive」だが、レイアウトを復元し、対応エージェントの会話を resume する。v0.9.2 で「エージェントが自分の resume コマンドを申告できる」、v0.9.4 で「Mac の再起動前にセッションを保存」 | Claude Code、Codex、Cursor、OpenCode、Grok、Antigravity、Pi ほか。「エージェントが CLI とソケット API で herdr を操り、互いに prompt し、相手が本当に blocked になるまで待てる」。Linux / macOS、Windows はベータ | https://github.com/herdrdev/herdr 、https://herdr.dev/docs/socket-api 、https://github.com/herdrdev/herdr/releases |
| tuios | 約 6.5k / Go / MIT | v0.12.1（10 月 31 日、2026 と読める）。6,458 コミット | **両方**。「`tuios integration install` wires 19 harnesses」（hook での申告）と「detects 24 agent CLIs by their process and screen」。**OSC 7501（Program Status protocol）** で任意のプログラムが状態を申告できる。v0.12.0 で「working と申告したまま 10 分無音なら `state: unknown`、`reason: silent`」 | JSON の Control Protocol（`tuios call`）、`tuios mcp`（既定で読み取り専用）、`tuios send-agent-message` / `ask-agent`。**「never types into a pane waiting on a prompt」**。v0.12.1 で `queue-prompt` に `client_id` が付き「再送しても 1 回だけキューに入る」（冪等化）。herdr 互換 API（`agent.prompt`）も持つ | デーモン。「Sessions come back after a daemon restart or reboot with their structure and working directories」。再起動後に Inbox が会話の resume を提案 | Inbox（承認・質問・メール・エラー・完了を全セッション横断で一覧）。エージェント向け機能は v0.10.1（2026-10-17）以降のリリースノートに集中 | https://github.com/Gaurav-Gosain/tuios 、https://github.com/Gaurav-Gosain/tuios/releases |
| CCManager | 約 1.3k（前回）/ TypeScript / MIT | v4.4.11（10 月 27 日） | **画面の文字列の規則**。v4.4.9 が「opencode の質問プロンプトを waiting_input と検出」「Cursor の『Ready to build?』を waiting_input と検出」と、CLI の画面が変わるたびに規則を足している | 前回のとおり（TUI からの操作。API は未確認） | 前回のとおり | 前回 + Grok Build | https://github.com/kbwo/ccmanager/releases |
| pando | 8 / Go / Apache-2.0 | v0.10.0（2026-11-06）。v0.1.0 は 2026-09-19 | 方式は未確認（working / waiting / done を表示） | 「One daemon owns the sessions; the TUI and the CLI are its clients」。Unix ソケット上の JSON。herdr の設計を借りたと明記 | デーモン再起動後に「every session comes back and its agent continues the same conversation」 | Claude、Codex、任意のシェル。worktree | https://github.com/xseman/pando 、https://github.com/xseman/pando/tags |
| nsq（neurosquad-cli） | 90 / 未確認 / MIT | 0.1.0 preview。可視範囲のコミットは 2026-10-09〜10-13、計 66 コミット | **hook のみ**。「Working / needs you / finished comes from each CLI's own hooks, not from guessing at the screen.」hook が鳴らない場合の保険として、画面が 5 分変わらなければ「quiet」 | `nsq send <agent> "prompt" [--when-done]`（ターン終了時に送る予約）、`nsq answer <agent> yes\|always\|no`（承認への回答） | ユーザーごとのデーモンが端末を持つ。`nsq down` / `nsq up`、再起動後も同じセッションで再開 | Claude Code、Codex、OpenCode。「herdr status protocol」に対応した CLI（Crush、Kiro CLI など）も可 | https://github.com/glmn-ai/neurosquad-cli 、https://github.com/glmn-ai/neurosquad-cli/commits/main |
| graith | 6 / Go / MIT | リリース日は未確認。2,798 コミット | 未確認 | 「a daemon owns the PTYs」。`type`、`logs`。エージェント間は pub/sub | 端末を閉じても、デーモン再起動でも、SSH が切れても残る | Claude、Codex、OpenCode、Cursor、Agy | https://github.com/d0ugal/graith |
| agent-console（buhuipao） | 38 / Rust / Apache-2.0 または MIT | 可視範囲のコミットは 2026-08-19〜10-14、計 61 コミット | 混在。Codex は hook、pi は拡張。**承認などのブロッキングダイアログは「画面から読む。transcript に出ないから」** | ブラウザの Conversation ビューからプロンプト送信、ダイアログの回答をボタンで | PTY デーモン。「自分が起動したプロセスにしか再接続できない。ほかのタブで始めたセッションは保存済み transcript から resume」 | Codex、Claude Code、pi | https://github.com/buhuipao/agent-console 、https://github.com/buhuipao/agent-console/commits/main |

### 3.3 デスクトップアプリ・独自端末の群

| ツール | スター / ライセンス | 最新・活発さ | 土台・対応 OS | 状態の検出 | 入力を送る口と到達確認 | 復帰・モバイル | 根拠 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cmux | 約 28.8k / GPL-3.0-or-later（サーバー部は BSL 1.1） | 0.65.2.2（2026-10-27） | Swift + AppKit、libghostty。**macOS のみ**。iOS の companion はベータ | 3 経路。(1) OSC 9 / 99 / 777 の通知シーケンス、(2) `cmux notify` を hook に配線、(3) `cmux hooks setup` が対応エージェントへ hook を入れる。0.65.1 で **OSC 7501** による idle / working / blocked / done / error の申告と、`cmux-events` ストリームの `program_status.changed`。0.65.2 に「Stop hook が届かなくても Running / Idle を正しく保つ」 | Unix ソケット（`/tmp/cmux.sock`、改行区切り JSON）と CLI。`cmux send` / `surface.send_text`、`cmux send-key` / `surface.send_key`、`cmux notify`、`cmux set-status`。**既定では cmux の端末内で起動されたプロセスしか接続できない**（`CMUX_SOCKET_MODE=allowAll` で解除）。応答は `{"id":…,"ok":true,"result":{…}}`。send の到達確認の記述は無い | レイアウト、cwd、スクロールバック（best effort）を復元。「cmux does not checkpoint arbitrary live process state.」hook を入れた対応エージェントは保存したセッション ID から resume。live の detach / reattach は任意の `cmux local-tmux` / `cmux local-zellij` | https://github.com/manaflow-ai/cmux 、https://cmux.com/docs/api 、https://cmux.com/docs/changelog |
| Superset（現 Paradev） | 約 16.2k / MIT | リリース日は未確認。5,519 コミット | Electron。macOS が主、Linux は実験的な AppImage、Windows は未対応。タスクごとに worktree + branch + 端末 | **hook のみ**。「Paradev installs lifecycle hooks and command wrappers into each agent's config.」Paradev から起動したエージェントでしか効かない。「待ち」の信号を出さない CLI は完了通知だけ。強制終了すると running のまま残ることがあり、手動の「Clear Status」が要る | CLI（`superset terminals send --text … --wait`、`--keys esc`、`--no-submit`）、TypeScript SDK、MCP サーバー。**`--wait` 付きの送信は検証される**: 「A text send must cause a new hook event, and fails after 10s with none (a prompt left in the input box).」ほかに `terminals read`、`agents read`（保存済み transcript）、`agents wait --until settled`、`snapshot --json`、`agents explain --json`（なぜその状態か） | 「persistent sessions that survive restarts」。iPhone / iPad アプリ（有償の Pro と Remote Access が要る） | https://github.com/superset-sh/superset 、https://docs.paradev.com/agent-status 、https://docs.paradev.com/cli/cli-reference |
| Conductor | 非公開 / ライセンス未確認 | 未確認 | Mac | 未確認 | 「Conductor API」があるが中身は未確認 | 未確認 | https://www.conductor.build/docs/ |
| emdash | 約 6.2k / Apache-2.0 | v1.2.11（2026-11-06）。週次。10,642 コミット | デスクトップアプリ（macOS / Windows / Linux）。タスクごとに worktree。SSH / SFTP でリモート。v1.2.10 に「New tmux tasks」の記述があり、tmux を土台に選べる | **hook**。lifecycle hook を持つエージェントのユーザー設定に印つきの項目を足し、状態・通知・resume 可能なセッションを追う。Emdash の外で動かすと「silently do nothing」 | README に記載なし。v1.2.7 に ACP のセッション回復の記述がある（中身は未確認） | hook が追う「resumable sessions」。モバイルの記載なし | https://github.com/generalaction/emdash 、https://github.com/generalaction/emdash/releases |
| Nimbalyst | 約 2.1k / MIT | リリース日は未確認。6,818 コミット | Electron。セッションごとに worktree、kanban 表示 | デスクトップ側の方式は README に無い | 公開 API の記載なし（MCP クライアントとして動く） | セッションの検索と resume。iOS アプリ（`packages/ios`） | https://github.com/Nimbalyst/nimbalyst |
| Sculptor（Imbue） | 246 / MIT | リリース日は未確認。2,167 コミット。「experimental research preview」 | デスクトップアプリ（Mac Apple Silicon、Linux）。workspace は「an isolated copy of your code」。コンテナ backend は実験的 | 未確認 | チャット入力と workspace 内の端末。API の記載なし | 未確認 | https://github.com/imbue-ai/sculptor |
| schaltwerk | 287 / MIT | リリース日は未確認。2,471 コミット | Tauri（Rust + React）、自前の PTY。macOS、Windows、Linux（ベータ）。セッションごとに worktree | 方式は README に無い | **MCP サーバー** があり「one terminal agent to orchestrate multiple others」。API の仕様は README に無い | 対応エージェントの session resumption | https://github.com/2mawi2/schaltwerk |
| parallel-code | 約 1.1k / MIT | リリース日は未確認。2,021 コミット | Electron + SolidJS。macOS / Linux。タスクごとに worktree | 方式は README に無い（Needs you / Stopped / Working / In pull request の板） | diff へのコメントをエージェントへ送り返す。API の記載なし | QR コードで電話のブラウザ UI と Android アプリから見て答える（Wi-Fi か Tailscale） | https://github.com/johannesjo/parallel-code |
| Orca（Stably） | 約 121.1k / MIT | リリース日は未確認。20,548 コミット | Electron `[speculation]`。macOS / Windows / Linux。worktree。リモートサーバー、SSH、worktree ごとのクラウド VM | 未確認 | 「Anything you can do in Orca, your agents can do too」という CLI（例 `orca worktree create`）。入力送信の API は未確認 | iOS / Android アプリ | https://github.com/stablyai/orca |
| agterm | 約 739 / MIT | 0.41.1（11 月 7 日、年は未確認）。1,323 コミット | SwiftUI / AppKit。macOS 14 以上（Apple Silicon）。Linux 向けは remote server と第三者の移植 | **自己申告のみ**。「Status is not inferred from the terminal.」hook をメニューから入れる | `agtermctl`（ローカル Unix ソケット）。`session type`、`session text --lines`。**「Terminal output is not streamed」** のでスクリプトはポーリング | live mode（zsh か fish が要る）で、終了・再起動を越えてプロセスが残る | https://github.com/umputun/agterm 、https://github.com/umputun/agterm/releases |
| Calyx | 362 / MIT | v0.50.1（10 月 23 日、年は 2026 と読める） | Swift + libghostty。**macOS 26 以上、Apple Silicon のみ** | hook 連携（方式の詳細は README に無い）。working / blocked / idle / done | 組み込みの **MCP サーバー** で、別ペインのエージェント同士が `register_peer` / `list_peers` / `send_message` / `broadcast` / `receive_messages` / `get_peer_status`。「Each message is delivered once.」アイドルの Claude Code ペインを起こす wake は既定で無効。承認を 1 か所に集める approval inbox | 任意のデーモン裏付け端末がアプリ終了・クラッシュを越える。レイアウト復元 | https://github.com/yuuichieguchi/Calyx 、https://github.com/yuuichieguchi/Calyx/releases |
| Paseo | 約 23.7k / Apache-2.0 | リリース日は未確認。6,457 コミット | ローカルのデーモン + デスクトップ / モバイル / Web / CLI。worktree。エージェントの動かし方（ACP / SDK / PTY）は README に無い | 未確認 | `paseo send <id> "…"`、`paseo attach <id>`、WebSocket API、MCP サーバー、SDK（`agent.waitForFinish()`）。「Agents in Paseo can … launch other agents, and talk to them, across providers.」 | iOS / Android のネイティブアプリ。relay が暗号化 | https://github.com/getpaseo/paseo |

- 補足
  - Superset の製品名変更は、docs の転送と README の表記から読んだもので、告知文は見つけていない。awesome リストには `ParadevAI/Paradev`（「Code editor built to run many agents at once」）が別の行として載っており、関係は未確認 `[unverified-summary]`（https://github.com/andyrewlee/awesome-agent-orchestrators ）
  - Orca のスター数は GitHub ページの表示のまま。awesome-cli-coding-agents でも 120k と一致している

### 3.4 状態表示だけを足す小さなプラグイン（tmux / WezTerm / Zellij）

| ツール | 対象 | スター / ライセンス | 状態の検出 | 入力送信 | 補足 | 根拠 |
| --- | --- | --- | --- | --- | --- | --- |
| tmux-agent-indicator | tmux | 101 / MIT、41 コミット | **hook が主**: `UserPromptSubmit` → running、`PermissionRequest` → needs-input、`Stop` → done。OpenCode はプラグインのイベント。hook が無い CLI は **プロセス名の検出へ fallback**（既定 `claude,codex,aider,cursor,opencode`）。任意のエージェントは `agent-state.sh` を直接呼べる | なし | ペインの枠・window タイトルの色、ステータスバーのアイコン。Claude と Codex のレート制限の残りも表示 | https://github.com/accessd/tmux-agent-indicator |
| tmux-agent-sidebar | tmux 3.0 以上 | 569 / MIT、267 コミット | hook（Claude Code はプラグイン登録、Codex は設定の貼り付け、OpenCode はローカルのブリッジ） | なし | 全セッション・全 window の Claude Code / Codex / OpenCode ペインを 1 本のサイドバーに。**subagent の木を表示**。サイドバーから worktree の生成と片づけ | https://github.com/hiroppy/tmux-agent-sidebar |
| crmux | tmux | 未確認 | **状態は tmux のペイン情報の監視**（Running / Idle / 承認待ち）。hook は状態ではなく、tmux から見えないメタデータ（セッション ID、モデル名）を補う用途。`SessionStart` hook → `crmux notify session-start` → Unix ソケット `/tmp/crmux-{uid}.sock` へ MessagePack-RPC の一方向通知 | 記事には無い | 作者は tmux 監視だけでは「取れる情報に限界がある」と書く | https://zenn.dev/maedana/articles/9f72d4f0cad458 |
| wez-sidebar | **WezTerm** | 6 / MIT、52 コミット | **hook → ファイル → ファイル監視**。`PreToolUse` / `PostToolUse` / `Notification` / `Stop` / `UserPromptSubmit` が `wez-sidebar hook <event>` を呼び、`sessions.json` に書く。「no CPU wasted on polling」 | なし（生成時の `--prompt` のみ） | `wezterm cli list` / `get-text` / `activate-pane` でペインへジャンプ。Claude Code 専用。WezTerm が「replaces tmux entirely」という立場 | https://github.com/kok1eee/wez-sidebar |
| wezterm-agent-deck | **WezTerm**（Lua プラグイン） | 75 / MIT、28 コミット | ペインの文字列の Lua パターン（`status_patterns` に `working = { 'thinking' }`、`waiting = { 'y/n' }` など）と読める `[speculation]` | なし | タブに状態の点、待ちの通知。OpenCode、Claude Code、Gemini、Codex、Aider | https://github.com/Eric162/wezterm-agent-deck |
| zellij-project-sidebar | Zellij（WASM プラグイン） | 34 / MIT、54 コミット | Claude Code の hook が状態ファイルを書き、Zellij の pipe メッセージでも即時通知。サイドバーは約 10 秒ごとにファイルも読む。**「hook はツール使用でしか鳴らないので、テキストだけの応答や思考中は反映されない」** と作者が書く | なし | 任意のツールが同じディレクトリへ書けば統合できる | https://github.com/AndrewBeniston/zellij-project-sidebar |
| workmux の Zellij / WezTerm backend | Zellij、WezTerm、kitty | 3.1 参照 | hook | 3.1 参照 | v0.1.281（11 月 8 日）で Zellij のサイドバーに対応 | https://github.com/raine/workmux/releases |

- 開いていない候補 `[unverified-summary]`: tmux-overmind（プロセス名・ペインタイトル・ペイン内容で検出）、tmux-pane-tree、ilmari、agent-status（crate）、wezam（WezTerm 用 TUI）、wezterm-agent-cards、zelligent（Zellij のタブ + worktree）、opencode-zellij、agent-dashboard（bjornjee、tmux）
  - 出典は検索結果の一覧（awesome.ecosyste.ms、docs.rs、github.com の各ページ名）で、中身は確かめていない

### 3.5 端末アプリ本体のエージェント向け機能

| 端末 | わかったこと | ステータス | 根拠 |
| --- | --- | --- | --- |
| iTerm2 | 最新安定版は 3.7.7（2026-11-03、macOS 13 以上）。リリースノートに「The hook program for Claude Code and Codex is now `it2 handle-agent-hook`.」「The Claude Code integration can now be installed on a host reached through SSH Integration.」「`it2 session set-status` has a new --progress option.」iOS の companion「iTerm2 Buddy」。**hook でセッション状態を取り、`it2` CLI で状態を外から設定できる** | `[verified]` | https://iterm2.com/downloads.html |
| iTerm2（続き） | 3.7.0（2026-09）で Claude Code 連携、Session Status（working / waiting / idle、3.7.5 から done / error）、全セッションを見渡して iTerm2 を操作する AI チャット「orchestration」、タブグループが入った | `[unverified-summary]` | https://alternativeto.net/news/2026/9/iterm2-3-7-released-with-ios-companion-app-claude-code-integration-tab-groups-and-more/ |
| Warp | 公式 docs に、Claude Code / Codex / OpenCode などのサードパーティ CLI エージェントへ「rich input, agent notifications, inline code review, and remote session control」を提供すると書かれている。親エージェントが子を起こす orchestration、CLI / API / SDK の Automation Platform もある。状態検出の方式と、サードパーティエージェントへ入力を送る API は docs の当該ページに無い | `[verified]`（範囲は左記のみ） | https://docs.warp.dev/agents/ |
| Warp（続き） | 2026-04-28 にクライアントを AGPL で公開、スター約 6.5 万 | `[unverified-summary]` | https://latent.space/wiki/warp-3041b44f/ |
| Ghostty | 1.3.0（2026-03）で AppleScript により window / tab / split / terminal を操作可能に。通知は OSC 9 / 777。ソケットや HTTP の API は無い、とする記事が 1 本ある。1.4.0 の時期は未確認 | `[unverified-summary]` | https://news.lavx.hu/article/ghostty-1-3-0-the-terminal-emulator-that-listens-to-its-users 、https://garywu.github.io/posts/ghostty-tmux-ai-integration |
| WezTerm | 本体のエージェント向け機能の新情報は見つけていない。コミュニティのプラグイン（3.4）と、workmux・hcom が WezTerm を backend / 起動先として扱う | `[verified]`（workmux、hcom の README） | https://github.com/raine/workmux 、https://github.com/aannoo/hcom |
| Zellij | 本体の新機能は未確認。プラグイン（3.4）と、cmux の `cmux local-zellij`、workmux の backend | `[verified]`（各 README） | https://github.com/manaflow-ai/cmux |

### 3.6 VS Code 系

- 公式 docs（「Manage agent sessions in VS Code」）`[verified]`
  - セッション一覧に、ローカルのハーネス、Copilot CLI、**Claude Code、Codex** のセッションが並び、状態・ハーネス・ファイル変更が出る。Codex は「requires the experimental Agent Host integration」
  - リモート（SSH、dev tunnels）、クラウド（実験的）のセッションもある
  - 既定では会話同士でファイル変更を隔離しない。「New Worktree」を選ぶと分かれる。worktree セッションを archive すると、未コミットの変更をセッション用 branch へ commit してからフォルダを消す
  - 出典: https://code.visualstudio.com/docs/agents/run/sessions/manage-sessions
- VS Code 1.109（2026-02 頃）で Agent Sessions view に Claude と Codex が入った `[unverified-summary]`
  - https://code.visualstudio.com/blogs/2026/02/05/multi-agent-development
- 拡張の例: Lookout for VS Code（全セッションを 1 枚の板に、MIT）`[unverified-summary]`
  - https://github.com/andyrewlee/awesome-agent-orchestrators
- 自作エンジンとの関係: VS Code のセッション一覧は「エディタの中の一覧」で、外のスクリプトから入力を送る口は docs の当該ページに無い。端末側の代替にはならない `[speculation]`

### 3.7 opencode の並列・サーバー機能 `[verified]`

- `opencode serve` がヘッドレスの HTTP サーバー（既定 `127.0.0.1:4096`、OpenAPI 3.1 の仕様は `/doc`）。TUI 自身もこのサーバーのクライアント
- 送信と状態
  - `POST /session/:id/message`: 送って **応答を待つ**。返るのはアシスタントの返信そのもの
  - `POST /session/:id/prompt_async`: 待たずに送る。`204 No Content` が返るだけ
  - `GET /session/status`: 全セッションの状態の map
  - `GET /event`: SSE のイベントストリーム（最初に `server.connected`）
  - `POST /session/:id/abort`
- TUI を外から操る口: `/tui/append-prompt`、`/tui/submit-prompt`、`/tui/clear-prompt`、`/tui/execute-command`、`/tui/control/next` と `/tui/control/response`
- 認証: `OPENCODE_SERVER_PASSWORD` で basic 認証
- 含意: opencode を子にする場合、**端末へ打ち込まずに HTTP で送り、SSE で状態を受ける** ことができる。`prompt_async` の 204 は「サーバーが受け付けた」までの確認
- 出典: https://opencode.ai/docs/server/

### 3.8 モバイル・リモートから見るもの

| ツール | スター / ライセンス | 仕組み | わかったこと | 根拠 |
| --- | --- | --- | --- | --- |
| Happy（happy-coder） | 約 24.6k / MIT | CLI（npm の `happy`）が Claude Code と Codex のハーネスを包み、relay サーバー（`happy-server`）経由で iOS（Swift）/ Android（Kotlin）アプリと E2E 暗号で同期。push は Cloudflare Worker から APNs / FCM | 最新は CLI v1.2.5（9 月 22 日）、v1.2.6-beta.1（10 月 9 日）。リリースノートに「Updated the Agent SDK to 0.3.295」とあり、**端末を読むのではなく Agent SDK でセッションを持つ** と読める。「OpenCode or any Agent Client Protocol agent」も harness にできる。v1.2.5 に「デーモンの状態が失われたあとに resumable なセッションを回復」「message acceptance、queue metadata を共有ランタイムに追加」 | https://github.com/slopus/happy 、https://github.com/slopus/happy/releases |
| Omnara | 約 3.4k / Apache-2.0 | **方向が変わっている**。現在の README は、自前のエージェントループを任意のモデルで動かす基盤（API、Postgres のイベントログ、stateless な worker、各マシンの `omnarad` デーモン）と説明する。Claude Code や Codex は「比較対象」として出るだけ | 「Claude Code を電話から見る」ツールとしての候補からは外れる。リリース日・最終コミット日は未確認 | https://github.com/omnara-ai/omnara |
| Paseo | 3.3 参照 | デーモン + ネイティブのモバイルアプリ | 3.3 参照 | https://github.com/getpaseo/paseo |
| AoE の `aoe serve` | 3.1 参照 | Web ダッシュボード。電話では structured view | TCP の口は Bearer トークンなどの認証が要る。`--read-only` あり | https://www.agent-of-empires.com/docs/api/ |
| agent-deck | 3.1 参照 | `agent-deck web`（`127.0.0.1:8420`）と、conductor を操る Telegram ボット | 3.1 参照 | https://github.com/asheshgoplani/agent-deck |
| Roamgate | 324 / MIT | herdr のためのブラウザ / PWA クライアント。herdr のサーバーと bridge が動いている必要がある | herdr との接続方式は README に無い。`roamgate url --qr`。ループバックでもログイン必須 | https://github.com/powerfooI/roamgate |
| parallel-code、amux、Superset、cmux、Nimbalyst、Orca、iTerm2 Buddy | 各節参照 | それぞれ電話用の UI かアプリを持つ | 「モバイルから見て答える」は 2026 年後半には標準装備に近い | 各節 |
| Claude Code 公式 | 前回メモ 2 節 | Remote Control、モバイル push、Channels | 前回のとおり | 前回メモ |

### 3.9 境目のもの: hcom（エージェント間メッセージの配送層）`[verified]`

- 約 651 スター、MIT。Rust / Python / TypeScript の混在と読める `[speculation]`
- **配送は hook**: 「Hooks record activity to a local SQLite database and deliver messages from it.」メッセージは「arrive mid-turn (after tool calls) or wake idle agents immediately」
- hook が効くのは `hcom` を前に付けて起動したエージェントだけ。それ以外は `hcom start` か `hcom listen`
- 端末の起動先を選べる: `--terminal` のプリセットに **kitty、wezterm、tmux、zellij、waveterm、cmux、herdr**。`--headless` はバックグラウンドの PTY
- `hcom term` で相手の PTY の画面を見て注入もできる。状態の変化を購読できる
- 対応: Claude Code、Gemini CLI、Codex CLI、Antigravity、OpenCode、Pi、Cursor CLI、Copilot CLI、Grok Build ほか
- 到達確認の記述は README に無い
- 出典: https://github.com/aannoo/hcom

## 4. 2026 年の新顔（前回にも依頼の列挙にも無いもの）

「初出の裏づけ」は、最古のタグか可視範囲の最古コミットで確かめた範囲。リポジトリの作成日はどれも直接は取れていない。

| # | ツール | 何か | 初出の裏づけ | 利用者のエンジンにとっての見どころ | 根拠 |
| --- | --- | --- | --- | --- | --- |
| 1 | Cyclops | tmux 上のエージェント間の「durable mailbox」 | 最古のタグが 2026-08-01、v1.1.0 が 2026-09-05 `[verified]` | 配送状態の 4 段階、composer の検査、「不確かなら成功扱いにしない」方針。3.1 参照 | https://github.com/cyclops-team/cyclops/tags |
| 2 | pando | Go のデーモン + TUI。セッションは worktree 内の PTY | v0.1.0 が 2026-09-19、v0.10.0 が 2026-11-06 `[verified]` | herdr 型（デーモン + ソケット API）の小さな実装。読みやすい規模 | https://github.com/xseman/pando/tags |
| 3 | nsq（neurosquad-cli） | hook だけで状態を出す並列端末 + keep-alive デーモン | 0.1.0 preview、© 2026、可視コミットは 2026-10-09 以降（全 66 コミット。2 ページ目は見ていない）`[verified]` | 「画面を推測しない」設計と、hook が鳴らないときの「quiet」保険。`send --when-done` | https://github.com/glmn-ai/neurosquad-cli/commits/main |
| 4 | agent-console（buhuipao） | tmux なしで Codex / Claude Code / pi のセッションを resume する Rust の TUI + PTY デーモン | 可視コミットは 2026-08-19〜10-14（全 61 コミット。2 ページ目は見ていない）`[verified]` | 「承認ダイアログだけは画面から読む」という hook と画面読みの分担 | https://github.com/buhuipao/agent-console/commits/main |
| 5 | tuios のエージェント機能 | 端末ウィンドウマネージャに Inbox、エージェント間メッセージ、Control Protocol、MCP が入った | 本体は以前からある。エージェント機能は v0.10.1（2026-10-17）〜v0.12.1（10-31）のリリースノートに集中 `[verified]` | `queue-prompt` の冪等化（`client_id`）、「待ちのペインへは打たない」、無音 10 分で `unknown` | https://github.com/Gaurav-Gosain/tuios/releases |
| 6 | iTerm2 3.7 系 | 端末本体に Claude Code / Codex の hook 連携と Session Status | 3.7.0 は 2026-09 `[unverified-summary]`、3.7.7 は 2026-11-03 `[verified]` | 端末アプリ側が hook を受ける公式の口（`it2 handle-agent-hook`、`it2 session set-status`）を持った例 | https://iterm2.com/downloads.html |
| 7 | OSC 7501（Program Status） | 任意のプログラムが idle / working / blocked / done / error を端末へ申告するエスケープシーケンス | cmux 0.65.1（2026-10-12）と tuios が実装 `[verified]`。提唱元と仕様の所在は未確認 | hook → 端末への申告を、ファイルやソケットではなく **端末のデータ経路そのもの** で行う方式。tmux を挟んだときの通過可否は未確認 | https://cmux.com/docs/changelog 、https://github.com/Gaurav-Gosain/tuios |
| 8 | Calyx | libghostty の macOS 端末。approval inbox と、ペイン間メッセージ用の組み込み MCP | 可視リリースは v0.45.0（9 月 26 日）〜v0.50.1（10 月 23 日）。年は 2026 と読める。初出は未確認 | 承認を 1 か所に集める inbox の設計。日本語圏の作者 `[speculation]` | https://github.com/yuuichieguchi/Calyx/releases |
| 9 | agterm | macOS のネイティブ端末 + `agtermctl` | 可視リリースは 0.35.1（10 月 5 日）〜0.41.1（11 月 7 日）。年と初出は未確認 | 「状態は端末から推測しない」「出力はストリームしない」という割り切り | https://github.com/umputun/agterm/releases |
| 10 | thurbox | tmux 上の TUI + mailbox + リモート SSH | v2.83.6（2026-11-05）。リリース一覧が 95 ページあり、初出は未確認 | 「相手の端末を scrape しない受け渡し」を tmux の上で実装 | https://github.com/Thurbeen/thurbox/releases |
| 11 | graith | Go のデーモンが PTY を持ち、エージェント間は pub/sub | 初出は未確認 | 小さい（6 スター）が 2,798 コミット | https://github.com/d0ugal/graith |
| 12 | Roamgate | herdr 用のブラウザ / PWA クライアント | 初出は未確認 | herdr のソケット API の上に第三者のクライアントが育っている例 | https://github.com/powerfooI/roamgate |
| 13 | Paseo、Orca | デーモン + 多クライアント型の大物 | 初出は未確認（6 月より前の可能性が高い `[speculation]`） | スター数では最大級。端末の読み書きより「エージェントが CLI で基盤を操る」方向 | https://github.com/getpaseo/paseo 、https://github.com/stablyai/orca |

- 「2026 年 6 月以降に初出」と一次情報で裏づけられたのは **1〜4 の 4 件**（うち 3 と 4 は 2 ページ目のコミットを見ていないので、6 月より前に始まっている可能性は残る）。5〜7 は「既存のものに 6 月以降に入った機能」。8〜13 は実在と現状は確かめたが、初出の時期は未確認
- awesome リストにだけあり、開いていない候補 `[unverified-summary]`（https://github.com/andyrewlee/awesome-agent-orchestrators 、https://github.com/bradAGI/awesome-cli-coding-agents ）
  - tmux 系: agent-manager、agent-session-manager（ntfy の push）、ai-devkit、Craig、repomon、ntm、tmuxlet、run-kit（電話向けの tmux コンソール）、vibepanel、dev-3.0
  - デーモン + PTY 系: Termio、pohunek（NetBird / Tailscale 越し）、Skiff、Tortie、tlbx、Open Walnut
  - 端末アプリ: termany、Prowl、Polter（Ghostty のフォークで 1 つのエージェントがタブをまたいで他を率いる）、herduck（herdr の派生、early alpha）、wmux、muxel、Vigil
  - 状態・履歴の閲覧: Agent Sessions、showagent、Claudescope、Perch（macOS のノッチに通知）、iris
  - プロトコル型: Orkas（「each tool's protocol」で駆動と紹介されるが、README では方式を確認できなかった `[verified]` https://github.com/Orkas-AI/Orkas ）、Toad（ACP のクライアント TUI、AGPL-3.0、約 3.5k スター `[verified]` https://github.com/batrachianai/toad ）、Nuphos（ACP）
  - リストの規模そのものが情報: awesome-agent-orchestrators の「Parallel Coding Agents」だけで端末系 37 件、デスクトップ / Web 系 130 件超が載っている

## 5. 類型と流れ

### 5.1 状態の検出の方式

| 方式 | 仕組み | 採っているもの | 強み | 弱み（作者の言及・issue・リリースノートから） |
| --- | --- | --- | --- | --- |
| A. 画面の文字列の規則 | ペインの内容を定期的に読み、スピナーや確認文言のパターンに当てる | CCManager、wezterm-agent-deck、crmux、herdr（fallback）、tuios（fallback）、agent-deck（hook の無い CLI）、Cyclops（manifest）、自作エンジンの capture-pane | hook の無い CLI でも動く。導入に設定が要らない | CLI の画面が変わるたびに規則の追加が要る（CCManager v4.4.9）。誤認（agent-deck v1.16.37「点字アートのロゴをスピナーと誤認」）。作者自身が「slower and occasionally wrong」（agent-deck） |
| B. プロセス名・プロセス木 | ペインの前面プロセスや子プロセスを見る | tmux-agent-indicator（fallback）、tuios、herdr、wez-sidebar（yolo モードの判定） | 「何の CLI が動いているか」は確実 | 「動いているか / 待っているか」は分からない |
| C. 各 CLI の hook による自己申告 | hook がファイル・ソケット・CLI コマンドへ状態を書く | workmux、Superset、nsq、emdash、cmux、agterm、tmux-agent-indicator、tmux-agent-sidebar、wez-sidebar、zellij-project-sidebar、iTerm2、herdr（integration）、tuios（integration）、hcom | CLI 自身が言うので意味が確か。ポーリングが要らない | (1) そのツールから起動したエージェントでしか効かない（Superset、hcom、emdash）。(2) hook が鳴らない場面がある: 強制終了で running が残る（Superset）、Stop が届かない（cmux 0.65.2 の修正）、ツール使用以外は反映されない（zellij-project-sidebar）、承認ダイアログは transcript に出ない（agent-console）。(3) CLI 側の信頼確認が要る（Codex の `/hooks`）。(4) CLI ごとに取れる状態が違う（「待ち」を出さない CLI がある） |
| D. 端末のエスケープシーケンスでの申告 | OSC 9 / 99 / 777（通知）、OSC 7501（状態） | cmux、tuios、Ghostty（通知のみ） | hook の出力先が端末のデータ経路なので、ファイルやソケットの置き場所を決めなくてよい | 端末側の対応が要る。多重化（tmux）を挟んだときの通過は未確認 |
| E. 構造化プロトコル | ACP のセッションイベント、opencode の SSE、Agent SDK のイベント | AoE の structured view、Toad、Happy（Agent SDK と ACP）、opencode `serve`、VS Code の Agent Host | 画面を介さない。承認も構造化された要求として届く | 端末の対話画面と両立しにくい（AoE: 切り替えで会話が新規になる）。アダプタごとの差（AoE: Codex に Plan 経路なし、Workflow 実行中に idle と出る） |
| F. CLI 公式の機械可読出力 | `claude agents --json` など | Claude Code 公式（前回メモ） | 公式の接点 | その CLI に閉じる |
| 併用（C + A + 無音の見張り） | hook を第一の根拠とし、hook が黙ったときに画面か時間で補う | herdr、tuios（無音 10 分で `unknown`）、nsq（5 分変化なしで quiet）、workmux（10 秒出力なしで interrupted）、agent-console | 実運用の落としどころ | 「どちらを信じるか」の規則が要る。herdr は `agent.explain` で根拠を見せる |

### 5.2 入力の送信の方式

| 方式 | 仕組み | 採っているもの | 「届いたか」について返すもの |
| --- | --- | --- | --- |
| 1. tmux の send-keys 相当 | ペインへ文字と Enter を打つ | AoE（tmux モード）、agent-deck、workmux、Cyclops（doorbell のみ）、thurbox、自作エンジン | AoE: `{"sent": true}` =「ペインへキーを届けた」まで。agent-deck: 内部で再送や「unconfirmed delivery」の報告 |
| 2. 自前の PTY への書き込みを、ソケット API で包む | デーモンが PTY を持ち、JSON の要求で書き込む | herdr、tuios、pando、nsq、graith、cmux、agterm、Superset | herdr: 「queue admission, not command execution」。Superset: `--wait` で hook イベントの発生を確認。cmux・agterm: 記述なし |
| 3. 送信 + 状態の待機を 1 要求に | 送ったあと「working になった」「idle に戻った」まで同じ要求で待つ | herdr（`agent.prompt` の `wait`）、Superset（`--wait --until`）、Paseo の SDK（`waitForFinish()`）、AoE（`send` と `session wait` は別コマンド） | 状態遷移そのものが受領の証拠になる |
| 4. hook による配送（受信側が取りに行く） | メッセージを DB やファイルに置き、受信側の hook がターンの合間に差し込む | hcom、Claude Code 公式の mailbox（前回メモ）、Cyclops（claim コマンド） | hcom: 記述なし。Cyclops: Claimed（本文を取り出した）と Completed（返信）を区別 |
| 5. MCP | エージェントが MCP のツールとして送受信する | Calyx、Superset、schaltwerk、Paseo、tuios（`tuios mcp`） | Calyx: 「Each message is delivered once」。受信は相手が `receive_messages` を呼んだとき |
| 6. HTTP / WebSocket | サーバーへ要求を送る | opencode `serve`、AoE（`aoe serve`）、Paseo、Omnara | opencode: 同期なら返信そのもの、非同期なら 204 |
| 7. ACP | `session/prompt` を送る | AoE の `aoe acp prompt`、Toad、Happy | プロトコルの応答とイベント |
| 8. CLI 公式のソケット | Claude Code の cross-session messaging | Claude Code 公式（前回メモ） | Delivered / Held / Refused |

### 5.3 2026-02 から 11 月にかけての流れ

- **状態検出: 画面読み → hook への移行は起きたが、置き換えではなく「hook を主、画面読みを従」の併用に落ち着いた**
  - 新しく出たものほど hook だけに寄る（nsq「not from guessing at the screen」、agterm「Status is not inferred from the terminal」、Superset）`[verified]`
  - 大きいものは二本立てにし、どちらが根拠かを説明できるようにした（herdr の `agent.explain`、Superset の `agents explain`）`[verified]`
  - 逆向きの動きもある。herdr v0.9.5（10 月 14 日）は Codex の turn hook の導入をやめて画面検出へ戻した。理由はリリースノートに無い `[verified]`（https://github.com/herdrdev/herdr/releases ）。hook は CLI 側の仕様変更や信頼確認の影響を受ける、という含意がある `[speculation]`
  - 画面読みだけのツール（CCManager）は、10 月になっても CLI ごとの文言を規則に足し続けている `[verified]`
- **hook の弱点への対処として「無音の見張り」が共通の部品になった**（10 秒、5 分、10 分と閾値はまちまち）`[verified]`
- **状態の申告先が共通化しはじめた**。OSC 7501 を cmux と tuios が実装し、nsq は「herdr status protocol」に対応した CLI を受け入れ、tuios は herdr 互換 API を持つ。herdr の方式が事実上の参照実装になりつつある `[speculation]`（個々の実装は `[verified]`）
- **送信: send-keys 型は残っているが、外側に「応答を返す API」と「状態遷移で確かめる」が付いた**
  - 2 月時点の代表（Claude Squad、uzi）は打ち込むだけだった。11 月時点では AoE・herdr・Superset・tuios が API と待機を持つ
  - 「届いたか」を仕様として書いたのは 2026 年後半のもの: Superset の `--wait`、herdr の「queue admission, not command execution」、Cyclops の 4 段階、tuios の冪等な `queue-prompt`
- **ACP は「並べる層」にも入ったが、主役ではない**。AoE は Web の既定表示を ACP にしたが、切り替えで会話が切れるなど端末表示との両立に制限を残す。Happy、Toad は ACP を harness の 1 つとして扱う `[verified]`
- **端末アプリ本体が hook の受け口を持ちはじめた**（iTerm2 3.7、cmux、agterm、Calyx）。いずれも macOS 専用 `[verified]`
- **エージェント間メッセージは「並べる層」の標準機能になりつつある**（agent-deck、amux、thurbox、Calyx、tuios、graith、Paseo、hcom、Cyclops）。前回メモの「親子の委譲・監視まで持つのは Gas Town だけ」は、監視と世代交代については今も近いが、**メッセージの配送に限れば多くのツールが持つ** ようになった `[verified]`（各 README）

## 6. 利用者のエンジンの部品ごとの対照

前提: 利用者は WezTerm の上で tmux を使い、Bash + jq で組んでいる。子は対話型の Claude Code。

### 6.1 send-keys での送信と到達確認

| 区分 | 候補 | 内容 | 乗り換えの障害 |
| --- | --- | --- | --- |
| 土台として乗り換え | herdr | `agent.prompt` + `wait` で送信と待機を 1 要求に。`agent.wait` はサーバー側のイベント駆動。Apache-2.0。Bash からは CLI（`herdr agent wait w1:p1 --until done` など）で叩ける | tmux の代わりに herdr がペインを持つ形になる。tmux の中で併用できるかは未確認。WezTerm の中では「whatever terminal you already use」で動く。確認は「キューに入った」まで |
| 土台として乗り換え | Claude Code 公式のソケット（前回メモ） | 子が Claude Code である限り最も直接的。Delivered / Held / Refused | Claude Code に閉じる。応用レベルの受領確認は無い |
| 部品として借りる | AoE の `aoe send` + `aoe session wait` | tmux のままで使える。HTTP API と `callback_url` もある。MIT | セッションを AoE の管理下に置く必要がある（既存の tmux ペインを後から登録できるかは未確認）。`sent: true` はペイン到達まで |
| 部品として借りる | agent-deck の `session send` | tmux のまま。専用の tmux サーバーに分けられるので、手元の tmux を汚さない。MIT | 同上（agent-deck が作ったセッションが対象） |
| 部品として借りる | hcom | hook で配送するので入力欄の状態に依存しない。tmux / WezTerm を起動先に選べる。MIT | `hcom` 経由で起動したエージェントが対象。到達確認の仕様は未確認 |
| 参考になる実装 | Cyclops | Accepted / Notified / Claimed / Completed の区別、composer の検査、不確かな結果を成功扱いにしない方針、ペインへは 1 行の doorbell だけ打って本文は mailbox に置く設計。**自作エンジンの「送ったのに届かない・届いたか分からない」に最も直接に対応する** | 14 スターの小規模。実機で検証済みの CLI は 5 種 |
| 参考になる実装 | Superset の `terminals send --wait` | 「送信後 10 秒以内に新しい hook イベントが出なければ失敗（入力欄に残ったと見なす）」。**`UserPromptSubmit` hook を受領の証拠に使う** 考え方は、Bash + hook の自作エンジンへそのまま移せる | 実装は Electron アプリの中。借りるのは考え方 |
| 参考になる実装 | agent-deck のリリースノート | Enter 前の待ち、Enter の再送、「キューに積まれただけなのに delivered と報告」の修正など、send-keys の失敗例の実録 | なし（読むだけ） |
| 参考になる実装 | tuios の `queue-prompt` + `client_id` | 再送しても 1 回だけ入る冪等化。「待ちのペインへは打たない」 | 実装は tuios のデーモンの中 |

### 6.2 capture-pane での状態読み

| 区分 | 候補 | 内容 | 乗り換えの障害 |
| --- | --- | --- | --- |
| 土台として乗り換え | hook による自己申告（方式 C）へ寄せる | 子は Claude Code なので、`UserPromptSubmit` / `PermissionRequest` / `Notification` / `Stop` / `StopFailure` で状態の大半が取れる。画面読みは「hook が黙ったとき」と「承認ダイアログ」に限る | hook が鳴らない場面の保険（無音の見張り）を自分で持つ必要がある |
| 部品として借りる | tmux-agent-indicator | hook → tmux の表示、の最小実装（41 コミット、MIT）。`agent-state.sh` を任意のエージェントが呼べる | 状態を tmux の表示に出すだけで、機械可読な口は未確認 |
| 部品として借りる | workmux の status hook | `workmux setup` が hook を入れ、`workmux status --json` で読める。**WezTerm と tmux の両方を backend にできる** | worktree と window の作り方を workmux の流儀に合わせる必要がある |
| 部品として借りる | herdr の `pane.report_agent` / `agent.explain` | 申告と画面検出の二本立て、根拠の説明つき | herdr への乗り換えが前提 |
| 参考になる実装 | herdr の agent manifest と Cyclops の manifest | 画面検出の規則を「データ」として CLI ごと・版ごとに持つ。Cyclops は `version_tested = "unverified"` を明示 | なし |
| 参考になる実装 | nsq、tuios、workmux の無音の見張り | 5 分 / 10 分 / 10 秒。hook を主とするときの保険の置き方 | なし |
| 参考になる実装 | agent-console | 「承認ダイアログは transcript に出ないので画面から読む」という分担 | なし |
| 参考になる実装 | wez-sidebar、zellij-project-sidebar | hook → 状態ファイル → ファイル監視、という Bash でも組める最小構成。後者は hook の限界を README に書いている | どちらも小規模（6 / 34 スター） |

### 6.3 cockpit の一覧・木・ジャンプ

| 区分 | 候補 | 内容 | 乗り換えの障害 |
| --- | --- | --- | --- |
| 土台として乗り換え | Claude Code の agent view（前回メモ） | 公式。子が Claude Code なら足りる | research preview。自作の木構造は映らない |
| 土台として乗り換え | AoE の TUI / Web | tmux のまま。一覧、状態、diff、電話用の表示 | 親子の木は持たない |
| 部品として借りる | tmux-agent-sidebar | **全 tmux セッション・window をまたぐサイドバーに subagent の木を出す**。MIT、Rust | 木は Claude Code の subagent の木で、自作エンジンの「セッション間の親子」ではない。表示の元データを差し替えられるかは未確認 |
| 部品として借りる | agent-deck | conductor（`--parent`）で親子を持ち、tmux のステータスバーに待ちを出し、`Ctrl+b` + 数字でジャンプ | agent-deck の管理下に置く必要がある |
| 部品として借りる | wez-sidebar | `wezterm cli activate-pane` でのジャンプ。WezTerm の上で動く | Claude Code 専用、WezTerm のペインが対象（tmux の中のペインではない） |
| 参考になる実装 | tuios の Inbox、Calyx の approval inbox | 「待ち」を全セッション横断で 1 か所に集め、その場で答える | tuios は tmux の代替、Calyx は macOS 26 以上 |
| 参考になる実装 | Superset の `snapshot --json`、herdr の `session.snapshot` + `events.subscribe` | 一覧の取得と差分の購読を分ける。herdr は「取りこぼしたら `events_lost` を返し、snapshot で突き合わせ直す」と仕様に書く | なし |

### 6.4 生存監視

| 区分 | 候補 | 内容 | 乗り換えの障害 |
| --- | --- | --- | --- |
| 土台として乗り換え | Claude Code の supervisor（前回メモ） | 異常終了の再起動、`claude agents --json` | マシン再起動後は手動 |
| 土台として乗り換え | herdr / tuios / pando / nsq のデーモン | デーモンが PTY を持ち、再起動後にレイアウトを戻して会話を resume。herdr v0.9.4 は「Mac の再起動前に保存」 | tmux をやめることになる |
| 部品として借りる | workmux の `resurrect` | クラッシュ前にエージェントが動いていた worktree を `--continue` で開き直す。`--dry-run` あり | workmux の管理下 |
| 部品として借りる | AoE の `aoe send`（既定で死んだセッションを起こす）と `session restart` | tmux のまま | AoE の管理下 |
| 参考になる実装 | Claude Squad #322（tmux サーバーごと死んだインスタンスの復旧、前回メモ）、amux の `tmux-watchdog.sh`（クラッシュを繰り返す worker は hold する） | tmux サーバーの死と、再起動ループの抑止 | amux は MIT + Commons Clause |
| 参考になる実装 | herdr v0.9.2「エージェントが自分の resume コマンドを申告」、AoE の `session set-session-id` | resume 先を「推測」ではなく「申告」で持つ | なし |

### 6.5 乗り換えの障害の一覧

| 障害 | 当たるもの |
| --- | --- |
| macOS 専用 | cmux、Conductor、agterm（14 以上、Apple Silicon）、Calyx（macOS 26 以上、Apple Silicon）、iTerm2。Superset は macOS が主で Linux は実験的 |
| ライセンス | cmux（GPL-3.0-or-later、サーバー部は BSL 1.1）、Claude Squad と Toad（AGPL-3.0）、amux（MIT + Commons Clause）、Conductor（非公開）。herdr は本家が Apache-2.0（前回メモの AGPL はフォークの記述） |
| tmux と併用できない・tmux を置き換える | herdr、tuios、pando、nsq、graith、cmux、agterm、Calyx、Superset、emdash（既定）。併用できるのは AoE、agent-deck、workmux、dmux、amux、Cyclops、thurbox、tmux-agent-indicator、tmux-agent-sidebar |
| そのツールから起動したセッションしか見えない | Superset、hcom、emdash、cmux のソケット（既定は cmux 内のプロセスのみ）、agent-console（再接続）、AoE・agent-deck・workmux も基本は自分が作ったセッションが対象 `[speculation]` |
| Bash から叩きにくい | MCP だけを口にするもの（Calyx、schaltwerk）。CLI を持つもの（herdr、AoE、agent-deck、workmux、Superset、tuios、nsq）は問題ない |
| 規模・持続性 | Cyclops（14）、pando（8）、graith（6）、wez-sidebar（6）、nsq（90、0.1.0 preview）は個人開発の初期段階。uzi は停止、Vibe Kanban は会社が終了しコミュニティ保守 |
| 版の動きが速い | workmux（ほぼ毎日）、thurbox（1 日に複数回）、agent-deck（数日おき）、herdr（月に数回）。API の互換を前提にしにくい |

## 7. 中身を読む価値がある順（上位 5 件）

| 順 | 対象 | 読む場所 | 理由 |
| --- | --- | --- | --- |
| 1 | Cyclops | README の配送状態と composer 検査の節、`resources/manifests/` | 利用者の悩み（tmux へ打ったものが届いたか分からない、画面の文字列で状態を誤る）と **同じ土台（tmux）で、同じ問題を正面から設計している**。配送を 4 段階に分け、活動状態と入力欄の状態を別の問いとし、不確かな結果を成功にしない。小さい（952 コミット、MIT）ので読み切れる。採用ではなく設計の語彙を借りる対象 |
| 2 | herdr | `herdr.dev/docs/socket-api`、Releases の v0.9.2〜v0.9.5 | この層の事実上の参照実装（約 49.9k スター、Apache-2.0）。送信 + 待機の一体化、申告と画面検出の優先規則、`agent.explain`、購読の取りこぼしの扱いまで仕様に書いてある。乗り換えないとしても、**自作エンジンの API を設計し直すときの見本** になる。Codex の hook を外した v0.9.5 は hook 依存の危うさの実例 |
| 3 | agent-deck | Releases（直近 10 件ほど）、`session send` と conductor の節 | **tmux の上で send-keys を使い続けた場合に何が起きるかの実録**。Enter 前の待ち、再送、誤った delivered 報告、スピナーの誤認など、利用者が踏んだはずの失敗が修正履歴として並ぶ。Go / MIT で、専用 tmux サーバーに分離でき、親子（conductor）も持つので、部品を借りる候補でもある |
| 4 | Superset（Paradev）の CLI リファレンスと agent-status | `docs.paradev.com/cli/cli-reference`、`/agent-status` | アプリ自体は Electron で乗り換え先ではないが、**「送信後に hook イベントが出たかで受領を確かめる」** と **「なぜその状態かを返す `agents explain`」** は、Bash + hook の自作エンジンへそのまま持ち込める。hook だけに寄せたときの制限（強制終了で running が残る、など）も正直に書いてある |
| 5 | workmux | README の status hook と backend の節、`resurrect` | **tmux と WezTerm の両方を backend にできる** 唯一級の実用ツール（約 3.0k スター、MIT、ほぼ毎日リリース）。hook で状態を取り、`status --json` で読め、クラッシュ後の `resurrect` を持つ。利用者の環境（WezTerm の上の tmux）に最も素直に乗る。送信の到達確認は弱いので、1 と 4 の考え方で補う前提 |

- 次点
  - AoE: tmux モードと ACP モードを併せ持ち、HTTP API と `callback_url` がある。ACP へ寄せる道を試すならここ。tmux モードの状態検出の方式を確かめられなかったので順位を下げた
  - hcom: hook による配送（ターンの合間に差し込む、アイドルなら起こす）を、tmux / WezTerm のどちらの上でも使える。統括と子のメッセージ層を別担当の調査と突き合わせる対象
  - tmux-agent-sidebar: cockpit の木の表示を借りるなら最初に読む
  - nsq: hook だけで組む最小の設計の見本（66 コミット）

## 8. 残った未確認事項

- AoE の tmux モードの状態検出の方式（画面読みか hook か）
- herdr を tmux の中で併用できるか、Codex の hook を外した理由、ライセンスが AGPL から Apache-2.0 へ変わった時期
- OSC 7501 の提唱元と仕様、tmux を挟んだときに通るか
- Cyclops の実装の中身（tmux へ打つ部分の実際、再起動後の扱い）
- Superset から Paradev への改名の経緯、`ParadevAI/Paradev` との関係
- Conductor の API・価格・状態検出、Warp のサードパーティエージェントの状態検出、Ghostty 1.4 の内容
- container-use の v0.4.2 の年、Vibe Kanban のコミュニティ版のその後
- workmux と agent-deck の README 後半（10 万文字以降）
- 各新顔のリポジトリ作成日（4 節の 8〜13）
- Happy がセッションを持つ方式の詳細（Agent SDK と読んだが、設計文書は開いていない）

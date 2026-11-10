# Phase 2 追加調査: 統括が子へ委譲し監視し続ける型の OSS 横断

- 調査日: 2026-11-10（数字はすべてこの日に GitHub の HTML ページから読んだ概数である）
- 目的: 前回メモ `docs/draft/618-engine-research/phase2-external.md` の結論「親子の委譲・監視・世代交代まで持つのは Gas Town だけ」を検証し、同じ型の OSS を広く洗い出して、自作エンジンの方向性を決める材料にする
- 対象: 統括（親）が子のコーディングエージェントへ委譲し、監視し、長時間走り続ける型。人が並べて操るだけのランチャー（Agent of Empires、claude-squad、CCManager など）は別担当のため対象外
- 方法: WebSearch と WebFetch。一次情報（リポジトリの README、`docs/`、Releases、コミット履歴、公式ドキュメントサイト）を優先した。検索語と外部リクエストに利用者の名前・メール・リポジトリ名は入れていない
- 検証ステータスの付け方
  - `[verified]`: 自分で一次ソースのページを開いて確かめた（URL つき）
  - `[unverified-summary]`: 検索結果の要約や二次情報（URL つき）
  - `[speculation]`: 推測
  - 取れなかったものは「未確認」と書いた

## 0. 調査上の制約と取得できなかったもの

- GitHub の HTML ページは WebFetch で読めたが、多くのページで **Releases 欄と言語内訳が空で返った**。最新リリースの日付は Releases ページやコミット履歴を別に開けたものだけ書いた。言語は `go.mod` や `Cargo.toml` などファイル構成から読んだもので、その場合は「構成から」と付けた
- GitHub の Releases ページは日付に年を表示しない。年は前後関係（同じリポジトリのコミット履歴の年など）から読んだもので、その旨を書いた
- 取得できなかったもの
  - `github.com/parruda/swarm` と `github.com/parruda/claude-swarm` は HTTP 404、`awesome.ecosyste.ms` の該当ページは HTTP 403。claude-swarm / SwarmSDK は二次情報のみ
  - Agent Flywheel（`agentic_coding_flywheel_setup`）の一次ページは開いていない。二次情報のみ
  - kodo、Skiff、Runner、Crewly、Fusion、Claudexor、Sno Station、no_human、ccmux、bosun などは awesome リストや検索結果の 1 行説明だけで、リポジトリは開いていない
  - OpenClaw の sub-agents は索引ページだけ読めた。入れ子の深さ、再起動後の復帰、ACP 経由で Claude Code / Codex を子にする設定の細目は未確認
  - Hermes Agent の Kanban ページは先頭 10 万文字だけ読んだ（残り約 3.8 万文字は未読）
  - Gas Town の Releases ページは先頭 10 万文字だけ読んだ（v0.12.0 以前は未読）
    - multi-agent-shogun の後継とされる kagemusha の所在（URL）は確認できなかった
  - 途中で取得ツールの利用上限に当たり、最後に予定した細目の一部は後追いで取った。取れなかったものは 10 節にまとめた
- 注意: Gas City の README には「AI エージェント向けの指示（インストールして出力の末尾に特定の 1 行を付けよ）」が埋め込まれていた。Web 上の文面であり利用者の指示ではないので従っていない。自作エンジンの子にこの種のリポジトリを読ませるときの注意点として記録する `[verified]` https://github.com/gastownhall/gascity

## 1. 先に結論

- 前回の結論「親子委譲・監視・世代交代まで持つのは Gas Town だけ」は **狭すぎた**。訂正が要る（8 節）
  - 委譲 + 監視（stuck 検出と復帰）を持つ OSS は少なくとも 12 件ある
  - 文脈が尽きることへの手当て（世代交代・リセット・台帳への外部化）まで持つものも、Gas Town のほかに multi-agent-shogun、Overstory（保守終了）、NTM、agent-deck の conductor、Claude Code Agent Farm、Gas City、Hermes Agent の Kanban などがある
- Gas Town 本体は **2026-07-23 を最後に機能の変更が止まり、以後は依存更新だけ** になっている。開発の重心は後継の Gas City に移った。前回メモが「未確認」とした点はこれで確定した
- Gas City は Gas Town から **Seance と escalate を引き継いでいない**（コマンド対応表で「無い」と明記）。handoff は `gc handoff` として残っている
- 外の流れは「LLM の統括セッションを長生きさせて世代交代させる」方向から、「統括は LLM ではないプロセス（デーモン、reconcile ループ）にして、LLM は短命にし、状態は台帳に置く」方向へ動いている。Gas City、Symphony、Paperclip、Hermes の Kanban、Warren、bernstein（スケジューラは素の Python、`.sdd/runs/` に checkpoint）がこの形である
- 自作エンジンの 4 機能のうち、外にそのまま当たる実装が見つからなかったのは次の 2 つである
  - **LLM の統括セッションの座の lease と、後任への世代交代の組**
  - **選択肢と根拠つきで 1 枚にまとめる判断ボード**
- 逆に、配送と受領確認は Cyclops、異種 CLI の子は多数、別ベンダーのレビューは metaswarm などに近い実装がある

## 2. 一覧（基本情報）

スター数は 2026-11-10 取得の概数。「活発さ」はコミット履歴か Releases を開けたものだけ日付を書いた。

### 2.1 依頼で挙がった候補

| ツール | URL | スター | 言語 | ライセンス | 最新リリース / 最終コミット | 活発さ | 検証 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gas Town (`gt`) | https://github.com/gastownhall/gastown | 18.8k | Go（構成から） | MIT | 最新リリース v1.2.1（6 月 6 日。年は非表示、コミット履歴から 2026 年と読める）。最終コミット 2026-11-10 | 2026-07-23 の PR マージを最後に、2026-10-20 以降は依存更新とビルド修正だけ。**保守モード** に見える | `[verified]` リポジトリ、https://github.com/gastownhall/gastown/releases 、https://github.com/gastownhall/gastown/commits/main |
| Gas City (`gc`) | https://github.com/gastownhall/gascity | 1.5k | Go（構成から） | MIT | v1.5.1（10 月 24 日。年は非表示、2026 年と読める）。最終コミット 2026-11-10 に 7 件以上 | **非常に活発**。7,774 コミット、PR 番号は 9,000 番台 | `[verified]` リポジトリ、https://github.com/gastownhall/gascity/releases 、https://github.com/gastownhall/gascity/commits/main |
| Beads (`bd`) | https://github.com/gastownhall/beads （旧 `steveyegge/beads` から移動） | 28.6k | Go（構成から） | MIT | 「v1.3.2 より後のリリース」への言及あり。日付は未確認 | 11,578 コミット、issue 1.1k、PR 685 | `[verified]` リポジトリ |
| multi-agent-shogun | https://github.com/yohey-w/multi-agent-shogun | 1.4k | Bash | MIT | v5.1.0（日付は未確認） | 372 コミット。作者自身は 10 体構成から 1 体へ縮小したと README に書いている | `[verified]` リポジトリ |
| claude-swarm / SwarmSDK | https://github.com/parruda/swarm （404 で開けず） | 約 1.7k | Ruby | MIT | `swarm_sdk` gem は 2.7.9 まで確認。最終 push は 2026-02-17 とする記述あり | 未確認（出典間で日付が揺れている） | `[unverified-summary]` https://rubygems.org/gems/swarm_sdk/versions/2.6.1?locale=ja 、https://gittrend.io/repo/parruda/swarm |
| ccswarm | https://github.com/nwiizo/ccswarm | 156 | Rust（構成から） | MIT | v0.11.0 への言及あり。日付は未確認 | 170 コミット、未マージ PR 16 | `[verified]` リポジトリ |
| claude-code-by-agents（Agentrooms） | https://github.com/baryhuang/claude-code-by-agents | 895 | Swift（v0.2.x で全面書き直し） | MIT | v0.2.6 への言及あり | `main` は 8 コミット（書き直し後） | `[verified]` リポジトリ |
| OpenAI Symphony | https://github.com/openai/symphony | 28.0k | Elixir（参照実装） | Apache-2.0 | リリースなし | 47 コミット。「low-key engineering preview」 | `[verified]` リポジトリ、https://github.com/openai/symphony/blob/main/SPEC.md |
| Paperclip | https://github.com/paperclipai/paperclip | 112.8k | TypeScript（構成から） | MIT | 未確認 | 7,338 コミット、issue 約 3.6k、PR 約 3k | `[verified]` リポジトリ |
| ralph-orchestrator | https://github.com/mikeyobrien/ralph-orchestrator | 3.2k | Rust + TypeScript（構成から） | MIT | 未確認 | 544 コミット | `[verified]` リポジトリ |
| Claude Task Master | https://github.com/eyaltoledano/claude-task-master | 28.3k | JavaScript / TypeScript（構成から） | MIT + Commons Clause | 未確認 | 1,216 コミット | `[verified]` リポジトリ |
| BMAD-METHOD | https://github.com/bmad-code-org/BMAD-METHOD | 55.2k | 未確認 | MIT | 安定版 v6.12、v7 は alpha（v7 は 2026-11 中旬の見込みと記載） | 2,367 コミット | `[verified]` リポジトリ |
| metaswarm | https://github.com/dsifry/metaswarm | 428 | 未確認 | MIT | 未確認 | 143 コミット | `[verified]` リポジトリ |
| Overstory | https://github.com/jayminwest/overstory | 1.3k | TypeScript（Bun） | MIT | 未確認 | **2026-05-28 にアーカイブ**（読み取り専用）。後継は Warren と記載 | `[verified]` リポジトリ |
| Antfarm | https://github.com/snarktank/antfarm | 2.5k | TypeScript | MIT | v0.5.1 への言及あり | 221 コミット。awesome リストは 2026-07-28 時点で「休止」に分類 | `[verified]` リポジトリ、https://github.com/andyrewlee/awesome-agent-orchestrators |
| ClawTeam | https://github.com/HKUDS/ClawTeam | 5.6k | Python | MIT | v0.2.0（2026-03-23） | 217 コミット | `[verified]` リポジトリ |
| Hermes Agent | https://github.com/NousResearch/hermes-agent | 262.3k | Python ほか（構成から） | MIT | 未確認 | 66,246 コミット | `[verified]` リポジトリ |
| OpenClaw | https://github.com/openclaw/openclaw | 未確認 | 未確認 | 未確認 | 未確認 | 未確認（リポジトリは開いていない） | `[verified]` 索引ページのみ https://docs.openclaw.ai/tools/subagents |
| mcp_agent_mail（Python 版） | https://github.com/Dicklesworthstone/mcp_agent_mail | 2.2k | Python | 未確認 | 未確認 | 890 コミット。**非推奨**。Rust 版に置き換えと README に明記 | `[verified]` リポジトリ |
| mcp_agent_mail_rust | https://github.com/Dicklesworthstone/mcp_agent_mail_rust | 242 | Rust | MIT（OpenAI / Anthropic 向けの付帯条項つき） | v0.3.39 への言及あり | 6,145 コミット | `[verified]` リポジトリ |
| NTM（Agent Flywheel の一部） | https://github.com/Dicklesworthstone/ntm | 464 | Go | MIT（バッジ） | v1.31.0 があるとする二次情報 | 5,627 コミット | `[verified]` リポジトリ。版は `[unverified-summary]` https://newreleases.io/project/github/Dicklesworthstone/ntm/release/v1.31.0 |
| agent-deck（conductor 機能） | https://github.com/asheshgoplani/agent-deck | 1.2k | Go | MIT | v1.16.38（11 月 7 日。年は非表示、2026 年と読める）。直前は v1.16.37（11 月 7 日）、v1.16.36（11 月 2 日）、v1.16.35（10 月 31 日） | **活発**。数日おきにリリース、conductor の修正が続いている。4,559 コミット | `[verified]` リポジトリ、https://github.com/asheshgoplani/agent-deck/releases |
| amux（mixpeek） | https://github.com/mixpeek/amux | 557 | Rust + SQLite | MIT + Commons Clause | 未確認 | 9,524 コミット | `[verified]` リポジトリ |
| Tmux-Orchestrator | https://github.com/Jedward23/Tmux-Orchestrator | 1.8k | シェル + Python（構成から） | MIT | 未確認 | 10 コミット。実質は雛形と手順書 | `[verified]` リポジトリ |
| oh-my-claudecode（agent teams を使う周辺） | https://github.com/Yeachan-Heo/oh-my-claudecode | 40.7k | TypeScript（構成から） | MIT | 未確認 | 6,330 コミット | `[verified]` リポジトリ |

### 2.2 候補になかった物（新顔と見落とし）

依頼の「最低 8 件」に対し、リポジトリを開いて確かめたのは次の 17 件である。作成日は GitHub のページに出ないため、「2026 年 6 月以降の登場」と確定できたものはない。手掛かりがあるものだけ注記した。

| ツール | URL | スター | 言語 | ライセンス | 活発さ・時期の手掛かり | 検証 |
| --- | --- | --- | --- | --- | --- | --- |
| CLI Agent Orchestrator（CAO、AWS Labs） | https://github.com/awslabs/cli-agent-orchestrator | 約 1.5k | Python | Apache-2.0 | 709 コミット | `[verified]` リポジトリ、https://github.com/awslabs/cli-agent-orchestrator/blob/main/CODEBASE.md 、https://github.com/awslabs/cli-agent-orchestrator/blob/main/docs/inbox-delivery.md |
| OpenRig | https://github.com/mvschwarz/openrig | 8.8k | TypeScript（Node.js デーモン） | Apache-2.0 | 5,110 コミット、v0.7.5 への言及。Show HN あり | `[verified]` リポジトリ。Show HN は `[unverified-summary]` https://hn.svelte.dev/item/47772935 |
| Cyclops | https://github.com/cyclops-team/cyclops | 14 | Rust（構成から） | MIT | 952 コミット、v1.1.0、ベンチマークの日付が 2026-09-05。**2026 年後半の新顔と読める** `[speculation]` | `[verified]` リポジトリ |
| hcom | https://github.com/aannoo/hcom | 651 | Rust + Python + TypeScript（構成から） | MIT | 662 コミット | `[verified]` リポジトリ |
| Vigil | https://github.com/butterlatte-zhang/vigil | 28 | Swift（macOS） | GPL-3.0-or-later + 商用 | 15 コミット。新しい小規模な物 `[speculation]` | `[verified]` リポジトリ |
| pohunek | https://github.com/zajca/pohunek | 8 | Rust + TypeScript | MIT | 3,995 コミット、pre-1.0 | `[verified]` リポジトリ |
| 5dive | https://github.com/5dive-ai/5dive | 113 | Bash + systemd + SQLite | MIT | 2,702 コミット | `[verified]` リポジトリ |
| AGX | https://github.com/ramarlina/agx | 33 | TypeScript（Node.js） | MIT | 707 コミット | `[verified]` リポジトリ |
| agent-swarm（desplega） | https://github.com/desplega-ai/agent-swarm | 約 1.0k | 未確認 | MIT | 3,487 コミット。「毎日更新」と記載 | `[verified]` リポジトリ |
| Scion（Google Cloud） | https://github.com/GoogleCloudPlatform/scion | 2.1k | Go + TypeScript（構成から） | Apache-2.0 | 7,248 コミット、pre-1.0。Google の公式サポート製品ではない | `[verified]` リポジトリ |
| Orchestrator.inc の agent-orchestrator（旧 `ComposioHQ/agent-orchestrator`） | https://github.com/OrchestratorInc/agent-orchestrator | 14.4k | 未確認 | Apache-2.0 | 3,974 コミット。旧 URL から転送された | `[verified]` リポジトリ |
| codex-orchestrator | https://github.com/kingbootoshi/codex-orchestrator | 361 | 未確認 | MIT | 23 コミット | `[verified]` リポジトリ |
| Warren（Overstory の後継） | https://github.com/jayminwest/warren | 514 | TypeScript（Bun） | MIT | 2,776 コミット、v0.19.3。**「No longer maintained (Nov 2026)」** と記載 | `[verified]` リポジトリ |
| Claude Code Agent Farm | https://github.com/Dicklesworthstone/claude_code_agent_farm | 922 | Python | MIT（付帯条項つき） | 50 コミット | `[verified]` リポジトリ |
| bernstein | https://github.com/sipyourdrink-ltd/bernstein | 1.2k | Python（バッジから） | Apache-2.0 | 6,119 コミット。beta、1 人で保守と記載 | `[verified]` リポジトリ |
| tmux-ide | https://github.com/wavyrai/tmux-ide | 566 | 未確認 | MIT | 3,835 コミット | `[verified]` リポジトリ |
| Mercury CLI | https://github.com/Whq02/MercuryCLI | 30 | 未確認 | Apache-2.0 | 12,939 コミット、公開リリース 53 回と自称 | `[verified]` リポジトリ |

リストや検索結果で名前と 1 行説明だけ確認し、リポジトリは開いていない物（すべて `[unverified-summary]`）。

| ツール | URL | 1 行説明（出典の言い方） | 出典 |
| --- | --- | --- | --- |
| kodo | https://github.com/ikamensh/kodo | Claude Code・Codex・Gemini CLI を作業サイクルで動かし、別のエージェントが各サイクルの結果を独立に検証する | https://github.com/andyrewlee/awesome-agent-orchestrators 、https://pypi.org/project/kodo-agent/ |
| agentproto | https://github.com/agentproto/ts | ローカルデーモン。supervisor が子を spawn でき、深さと子の数に上限。コミットは人の確認の後ろに置く | https://dev.to/agentiknet/9-coding-agent-orchestrators-honestly-compared-dated-sourced-and-one-of-them-is-mine-3kpk （作者自身の比較記事、2026-07-14） |
| Skiff | https://github.com/solutionscay/skiff | skipper エージェントが他セッションへタスクを渡す。mission control の木 | awesome-agent-orchestrators |
| Runner | https://github.com/yicheng47/runner | CLI エージェントを 1 つの任務に lead つきの crew として載せる | 同上 |
| Crewly | https://github.com/stevehuang0115/crewly | Claude Code・Codex・Gemini CLI の役割別チーム。委譲と共有メモリ | 同上、https://raw.githubusercontent.com/Agent-Analytics/awesome-multi-agent-orchestrators/main/README.md |
| Fusion | https://github.com/Runfusion/Fusion | 複数ノードの統括。計画ゲートと階層つきミッション | awesome-agent-orchestrators |
| ccmux | https://github.com/epilande/ccmux | tmux 上のエージェント間で応答を handoff。相手がアイドルのときだけ打ち込み、最中ならキューに積む | 検索結果の要約 |
| bosun | https://github.com/yetidevworks/bosun | tmux ネイティブのエージェントセッション統括（Rust + ratatui） | 検索結果の要約 |
| Claudexor | https://github.com/razzant/claudexor | 既存エージェントの上のローカル制御面。best-of-N と別モデルによるレビュー | awesome-multi-agent-orchestrators |
| Sno Station | https://github.com/sno-ai/sno-station | 共有メモリと mailbox、別ベンダーによるレビュー | awesome-agent-orchestrators |
| no_human | https://github.com/no-human-ai/no_human | チケットからレビュー済み PR まで。各 diff を第 2 のモデルがレビュー | 同上 |
| claude-orchestrator-mvp（日本発、WIP） | https://github.com/rikeda71/claude-orchestrator-mvp | 複数の Claude Code インスタンスを協調させる MVP | 検索結果の要約 |

日本語圏の記事で確認できた流れ（いずれも `[unverified-summary]`、本文は開いていない）。

- multi-agent-shogun を起点に、tmux の手動統括から「Claude Code 組み込みの統括 + OpenClaw のセッション管理」へ移った体験記 https://zenn.dev/imudak/articles/multi-agent-orchestration-comparison
- 自作の tmux + Markdown 方式を 10 体から 5 体へ減らし、公式の仕組みへ寄せた体験記 https://infohiroki.com/blog/2026-02-07-claude-code-multi-agent-orchestration
- shogun の派生として `kawagutt/multi-agent-shogun`（3 体の「MAGI」による品質レビューを足したとされる） https://dev.to/maymay5692/--2e13

## 3. 設計の比較（主要な物）

「統括」は親、「子」は作業者。空欄に当たる所は「記述なし」と書いた。記述なしは「無い」ことの証明ではなく、開いたページに書かれていなかったという意味である。

### 3.1 構造・送信・状態

| ツール | 統括と子の構造 | 子への送信と、届いたかの確かめ方 | 状態と登記の置き場 | 統括の座の排他 |
| --- | --- | --- | --- | --- |
| Gas Town | 役割固定の多層。町: Mayor / Deacon / Boot / Dogs、rig: Witness / Refinery / Polecat / Crew | mail は Beads の `type=message` の bead（Dolt に永続、セッションの死を越える）。nudge は相手の tmux セッションへ直接送り、bead を作らず、相手が死んでいれば失われる。受領は `gt mail read` と `gt mail ack` を受信側が手で打つ。配送の受領証は無い | Beads（町ごとに 1 つの Dolt SQL Server、`~/gt/.dolt-data/`）、`~/gt/daemon/`、`~/gt/mayor/`。エージェントごとに agent bead と `hook_bead` | 開いた設計文書には **記述なし**（architecture、identity、heartbeats のどれにも singleton や lock の説明が無い） |
| Gas City | 役割は固定せず設定で作る。統括は LLM ではなく「orchestrator」が設定と実セッションを reconcile する。Gas Town の役割は「Gastown pack」として同梱 | mail は bead。毎ターン hook が `gc mail check --inject` を走らせ、未読が system reminder として現れる。nudge（`gc session nudge`）は端末入力経由の撃ちっ放しで、クラッシュを越えない。受領証は無い（4.2 節）。v1.5.1 で「権限プロンプトが出ているセッションには文字を打ち込まない」検出が入った | すべて bead（タスク・mail・セッション・convoy は `type` が違うだけ）。Dolt、またはファイル型の store（`GC_BEADS=file`）。追記型のイベント列（連番つき、再生可） | **あり（ただし LLM ではなく制御プロセスの座）**。リリースノートに「`gc stop` は store の停止まで controller lock を保持する」「別の gc インストールの supervisor へ city を渡すことを拒否する」 |
| multi-agent-shogun | 固定 4 役: 将軍 → 家老 → 足軽 7 体、別に軍師 | エージェントごとの YAML inbox（`queue/inbox/ashigaru3.yaml`）へ `flock` つきで書く。`inotifywait` の監視役が変更を検知。**本文は tmux に流さず**、「mail あり」の短い nudge だけ送る。起こす順は自己監視 → Stop hook → `tmux send-keys`。処理後に inbox 内で既読にする | YAML キュー、`dashboard.md`（家老だけが書く）、Memory MCP、`config/settings.yaml` | 記述なし（役とペインが 1 対 1 で固定） |
| Overstory（保守終了） | Orchestrator → Coordinator → Supervisor / Lead → Scout / Builder / Reviewer / Merger。Lead だけが子を作れる | SQLite（WAL）の mail、8 種の型つきメッセージ、`@all` などの一斉送信。`ov nudge` は走行中セッションへ文字を送る。既読とスレッド返信はある。受領確認の記述なし | SQLite（mail、マージキュー、メトリクス）、`.overstory/` の設定と manifest、エージェントごとの identity、checkpoint、NDJSON ログ、worktree | 記述なし |
| CAO | supervisor が専門エージェントへ並列または直列に委譲。単発の ephemeral エージェントを別のエージェントが作れる | 各エージェントは独立した tmux セッション、`cao-server` が束ねる。MCP サーバーが supervisor / worker 用のツールを出す。`send_message` は DB のキューに保存し、相手の端末へ bracketed paste で貼る。**既定では相手が IDLE か COMPLETED のときだけ届ける**。経路は即時、5 秒ごとのログ監視、30 秒ごとの reconcile の 3 つ。貼った後 8 秒以内に処理開始の証拠が無ければ Enter だけ送り直す（最大 2 回、ダイアログが開いている間は送らない）。状態は PENDING / DELIVERED で、**貼れた時点で DELIVERED**（相手が送信しなくても）。人向けの質問が開いている所へは届けない | SQLite（sessions、terminals、inbox messages） | 記述なし |
| OpenRig | YAML の RigSpec で pod と seat を定義。lead が専門 seat へ委譲。seat は「安定した役割と宛先」 | `rig send`、`rig broadcast`、`rig chatroom`、キュー（`rig queue list`）。`rig send --verify` の例がある（仕組みの説明は無い）。人が打鍵中の seat への自動送信は止める | SQLite + tmux + ランタイムアダプタ。`OPENRIG_HOME` | 記述なし |
| Cyclops | 階層の記述なし（配送層に特化） | **追記型ジャーナルに fsync してから送信を受理**。本文は mailbox に置き、相手のペインには 1 行の「呼び鈴」（要約と claim コマンド）だけ書く。メッセージは accepted → notified → claimed → completed と進む。**完了は明示の返信が要り、アイドルから推測しない**。不確かな結果は `submitted_unverified` と記録し、時間で再送しない | 追記型ジャーナル（再起動時に mailbox 状態を再構成） | 記述なし。送信者の身元はソケット接続から取る |
| agent-deck の conductor | conductor（常駐のエージェントセッション）が他のセッションを監視・統括。1 プロファイルに複数置ける | `agent-deck session send`。状態遷移の通知デーモンが、子が running から waiting / error / idle に変わると親の conductor へ nudge | conductor ごとのディレクトリに `CLAUDE.md` または `AGENTS.md`、`meta.json`、`state.json`、`task-log.md`。共有の `POLICY.md`、`LEARNINGS.md` | 記述なし |
| NTM | 階層は固定しない。tmux のペイン群を束ねる制御面 | `ntm send`（全ペインまたは個別、割り込みも可）。Agent Mail と連携 | checkpoint、sessions、timeline、audit。REST / SSE / WebSocket の API | 記述なし。ファイル予約は commit 時の guard で強制 |
| mcp_agent_mail_rust | 階層なし（対等な mailbox） | MCP ツール。`send_message` に `ack_required`、受信側は `acknowledge_message`、`mark_message_read`、`get_message_delivery_receipt`。`am acks` に pending / remind / overdue | プロジェクトごとの git アーカイブ（人が読めるファイル）+ SQLite | ファイル予約は `ttl_seconds` と `exclusive` を持つ **勧告的な lease**（自動失効、更新、解放、強制解放）。build slot も同じ形 |
| Symphony | 単一の orchestrator（LLM ではないサービス）が issue ごとにエージェントを 1 つ走らせる。階層なし | `codex app-server` を stdio で起動して話す。イベントが来ない時間で stall を測る | **DB なし**。スケジューラの状態はメモリ上。ワークスペースはディスクに残る。真実は issue トラッカー | 「orchestrator だけがスケジュール状態を変える」単一権限。claimed / running の集合で二重 dispatch を防ぐ。プロセス間の lease ではない |
| Paperclip | 組織図（役職、上下関係、権限、予算）。委譲は上下に流れる | DB に載った wakeup キュー（合流あり）→ アダプタが各 CLI を起こす（heartbeat） | 組み込み PostgreSQL。タスク・コメント・文書 | タスクの atomic checkout と実行ロック。統括の座の排他ではない |
| Hermes Agent の Kanban | orchestrator プロファイルが分解し、worker プロファイルが実行する（慣習であり強制ではない） | dispatcher が 60 秒ごとに回り、タスクを atomic に claim して `hermes -p <担当>` を新しいプロセスで起こす。worker は `kanban_show()` で自分のタスクとコメントを読む | board ごとの SQLite | **タスクの claim に TTL がある**。worker は `kanban_heartbeat` で延長。「2 つの dispatcher を同じ DB に向けると claim を競う」と注意書き。dispatcher 自体の排他は記述なし |
| ClawTeam | leader が `clawteam spawn` で worker を作る。worker ごとに worktree と tmux ウィンドウ | 既定はファイルの JSON inbox。任意で ZeroMQ の P2P（ファイルへフォールバック）。`inbox receive` は消費、`inbox peek` は覗くだけ。受領確認の記述なし | `~/.clawteam/` の JSON。一時ファイルへ書いて rename | 記述なし |
| hcom | 中央の統括なし（対等）。イベントの連鎖とスクリプトで組む | hook が SQLite に書き、hook が相手へ届ける。ツール呼び出しの後で途中に届くか、アイドルなら即起こす。配送保証・ack・再送の記述なし | `~/.hcom/` の SQLite。機器間は MQTT リレー | 記述なし |
| 5dive | 組織図（`5dive org tree`） | 共有 SQLite キューと CLI（`agent ask`、`agent send`、`task add --assignee`）。「仕事が待っているときだけ起きる」 | SQLite。Bash + systemd | 記述なし |
| Vigil | root manager → worker または sub-manager の木。経路は単一の親、木をまたぐ通信は最小共通祖先を通す | spawn / send / kill / report を MCP ツールとして出し、アプリが実行。役ごとに使えるツールを絞る | アプリ内の単一の `SessionStore` | 記述なし |
| codex-orchestrator | Claude Code（親）→ Codex（子）。1 層 | tmux の切り離しセッションで Codex を起こしプロンプトを送る。`send <id> <msg>` で走行中の子を向け直す。`--wait`、`--notify-on-complete` | `~/.codex-agent/jobs/` に `<jobId>.json` / `.prompt` / `.log` | 記述なし |

出典（すべて `[verified]`）: 各リポジトリの README（2 節の URL）。Gas Town は加えて https://github.com/gastownhall/gastown/blob/main/docs/design/architecture.md 、https://github.com/gastownhall/gastown/blob/main/docs/design/mail-protocol.md 、https://github.com/gastownhall/gastown/blob/main/docs/concepts/identity.md 。Gas City は https://docs.gascity.com/getting-started/how-gas-city-works.md 、https://github.com/gastownhall/gascity/releases 。Symphony は `SPEC.md`。Hermes は https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban 。

### 3.2 監視・復帰・文脈・人・CLI

| ツール | 監視（stuck の検出）と復帰 | 統括の文脈が尽きることへの手当て | 人の判断待ちの出し方 | 対応 CLI と別ベンダーのレビュー | Claude Code 公式機能との関係 |
| --- | --- | --- | --- | --- | --- |
| Gas Town | Go デーモンが 3 分ごとに tick。hook があるのに約 30 分進まないと GUPP 違反、tmux 出力が 30 分無いと hung、同じ step で 3 回落ちると crash loop。Witness が polecat を再起動、Deacon が Witness を再起動、Boot が Deacon を 5 分ごとに見る。「機械的に stuck と断じない、判断は AI の Witness に任せる」方針 | `gt handoff`（`/handoff`）で新しいセッションへ。PreCompact hook で状態を保存。続きは git・Beads・`hook_bead` が運び、**「明示の handoff 文面は要らない。Beads の状態がそのまま handoff である」**。新セッションは `gt prime --hook` → `bd mol current` → `bd show`。HANDOFF mail は Context / Status / Next を持つが、常用は反パターン扱い。Seance で前任セッションに問い合わせる | `gt escalate -s <重大度>`。Deacon → Mayor → Overseer（人）。経路は bead、mail、email、SMS、Slack、log。4 時間 ack が無いと重大度を上げて再通知（最大 2 回）。**選択肢を並べる仕組みは無い**。「decision」カテゴリは設計にあるが CLI フラグとして未実装 | claude、gemini、codex、kiro、cursor、auggie、amp、opencode、copilot、pi、omp のプリセット。別ベンダーのレビューは記述なし | 避けている。agent teams に Witness を lead として載せる設計文書（2026-02-08）はあるが「NOT YET IMPLEMENTED」のまま。hook（`.claude/settings.json`）には乗っている |
| Gas City | orchestrator の health patrol（order の一種）。セッションの異常終了はイベント（`session.crashed`）になる。再起動時は生きているセッションを作り直さず引き取る。失敗は再試行 | 統括が LLM でないため、統括の文脈は尽きない。仕事は bead にあり、エージェントが死んでも bead は開いたままで、新しいエージェントが拾う。`gc handoff` は残っている。`gc session reset` でエージェントを再起動。**Seance に当たるコマンドは無い** | ダッシュボード（`http://127.0.0.1:8372/`）とイベント。**`gt escalate` に当たるコマンドは無い**（bead・mail・order・pack 側の手順で組む） | Claude Code、Codex、Gemini ほか。セッションの土台は tmux（既定）、subprocess、ACP、Kubernetes、herdr | 避けている（自前のセッション層）。ACP を土台の 1 つに持つ |
| multi-agent-shogun | ペインの表示から CLI ごとの busy / idle を推定。応答が無いと 3 段階: 通常の nudge → 追加のキー送信（約 2〜4 分）→ **文脈リセット（4 分超、5 分に 1 回まで）** | `/clear` の手順で文脈を捨て、指示書・`@agent_id`・Memory MCP・自分のタスク YAML を読み直して復帰（約 6,800 トークンと自称）。永続の状態はすべてファイル側 | `dashboard.md` に家老が集約。ntfy の push（「Action needed」）。足軽が出すスキル候補を人が承認 | Claude Code、Codex、Copilot、Kimi Code、OpenCode、Cursor、Antigravity を役ごとに割り当て。軍師がレビューと原因分析を持つ（別ベンダー固定ではない） | 避けている。README で Task ツールと agent teams を比べ、YAML + tmux の側を選ぶ理由（複数 CLI、調整に API 費用がかからない）を述べている |
| Overstory（保守終了） | 3 層の watchdog: 層 0 は機械的なデーモン（tmux / PID の生存）、層 1 は AI による失敗の仕分け、層 2 は巡回する Monitor エージェント。`ov sling --recover` で新しい lead を閉じたタスクへ再投入 | checkpoint の保存と復元（compaction を越える狙い）、handoff による復帰、`ov prime` で文脈を読み込む | `escalation` 型のメッセージ、Web UI（`ov serve`）、`tmux attach` | Claude Code と Sapling が安定、Pi・Copilot・Cursor・Codex・Gemini・Aider・Goose・Amp・OpenCode は実験的 | 新規プロジェクトでは Claude Code を **headless が既定**、tmux は任意。agent teams への言及なし |
| CAO | プロバイダごとのアダプタが状態を検出。stuck 検出と復帰は記述なし（終わった子を 1 分ごとに片付ける reaper はある） | 記述なし。任意の「self-learning」で結果を教訓にする | Web UI、tmux attach。承認ゲートの記述なし | Kiro CLI（既定）、Claude Code、Codex、Antigravity、Hermes、Kimi、Copilot CLI、OpenCode、Cursor CLI、Grok Build ほか | 避けている（tmux または herdr の上に自前） |
| OpenRig | `rig ps` が認証・信頼・権限のプロンプトで止まった seat を示す。`rig down --snapshot` と `rig up <名前>` で復元し、seat ごとに resumed / fresh-primed / awaiting-decision / attention_required / failed を報告 | seat の「会話は入れ替わっても、身元と書き込んだ文脈は残る」。Claude の文脈使用量を `state/context-usage` に集める。compaction や交代の手順は記述なし | lead が「人の注意が要る結果と判断」を持ってくる、とされる。人の seat やキューは記述なし | Claude Code、Codex、Pi、Oh My Pi、端末ノード。Claude Code と Codex を交互に並べる雛形がある | 避けている（tmux + 自前デーモン） |
| Cyclops | エージェントが idle / working / gating / blocked / failed を申告。モーダル、権限プロンプト、利用上限の画面、死んだペイン、copy-mode のときは配送を止める。再起動時はジャーナルを再生し、配送途中だったものを `attention_required` にする。`cyclops requeue` で出し直し | 本文をペインに流さないので文脈を汚しにくい。文脈窓の管理は記述なし | `attention_required`、gate で止めた後の 1 回だけの管理者 ping、`cyclops status`（「何が人を待っているか」） | Claude Code、Codex CLI、Antigravity CLI、Cursor Agent CLI、Kimi Code CLI を実機で検証済みと記載 | 避けている |
| agent-deck の conductor | 通知デーモンの状態遷移 + 既定 15 分の heartbeat。任意の watchdog（自動再起動）。`ORDERS.md` の安い shell チェックを毎分走らせ、出力が変わったときだけ conductor を起こす（1 日の起床回数に上限） | `clear_on_compact` で先回りの `/clear`。状態は `state.json` と `task-log.md`、教訓は `LEARNINGS.md` に外へ出す | conductor が自信のあるものは自分で答え、無いものを人へ上げる。返信の行頭で仕分け: `NEED:` と `[urgent]` は Telegram / Slack へ即時、`[info]` はまとめて、`[STATUS]` と `AUTO:` はローカルのみ。Discord、Mattermost も可 | conductor は Claude Code が主、`--agent codex` で Codex。子は Claude Code、Codex、Gemini、OpenCode | 避けている（tmux のセッション管理の上に自前） |
| NTM | `ntm health`、`ntm activity`。再起動と respawn の経路あり | **context rotation**: 保留中の交代を確認でき、「後任が handoff を受け取ってから古いペインを退かせる」。spawn 時に直近の handoff を復元。交代中の自動再起動を止める柵がある | `ntm approve`、`ntm policy`、`ntm safety`（破壊的操作や強制解放のゲート） | Claude Code、Codex、Antigravity CLI、Oh My Pi、Grok Build、OpenCode（Gemini CLI は legacy 扱い） | 避けている |
| Claude Code Agent Farm | heartbeat ファイルが 2 分より古い・エラー・アイドルのエージェントを自動再起動（指数バックオフ、上限 5 分）。エラー回数が上限に達すると無効化 | 各エージェントの文脈残量を画面から読み、既定 20% を切ると `/clear` | ダッシュボード（tmux の制御ウィンドウ）、終了時の HTML レポート | Claude Code のみ | 避けている（tmux + lock ファイル。2 時間で stale） |
| Symphony | イベントが 5 分無いと stall として kill し再試行。失敗時は指数バックオフ（上限 5 分）。毎 tick で走行中の issue をトラッカーと突き合わせる。**再起動後はタイマーも走行中セッションも戻さず**、ポーリングし直して再 dispatch | 統括は LLM でないので尽きない。子は 1 issue につき最大 20 ターン、続きのターンは続行の指示だけ送る | ワークフローが決める引き渡し状態（例: `Human Review`）。issue が active の集合から外れると止まる | 仕様は Codex の app-server プロトコル前提 | 無関係（Codex 側の仕組み） |
| Paperclip | 「bounded recovery」。それ以外は人へ出す。watchdog と自動復帰はロードマップ | アダプタが対応していれば保存済みセッションを run をまたいで再開。run ごとにログ・使用量・セッション状態を保存 | board の承認フロー、採用の承認ゲート、予算の警告と hard stop、設定の版管理 | OpenClaw、Claude Code、Codex、Cursor、Gemini CLI、OpenCode、Pi、Hermes、Grok Build、Kimi Code | アダプタで Claude Code を起こすだけ |
| Hermes Agent の Kanban | dispatcher が毎 tick で stale な claim（既定 4 時間）を回収、PID が消えた worker を crash として回収。起動失敗が続くと自動で blocked（既定 2 回）。同じ原因で再ブロックが続くと triage へ | タスクごとに新しいプロセス。文脈はタスクの本文・親の引き継ぎ・過去の試行・コメントから読む | `kanban_block` に理由の種別（`needs_input`、`capability`、`transient` は人へ、`dependency` は親待ち）。人か orchestrator が `unblock`。発端のチャットへ完了・block・crash を通知 | worker は Hermes のプロファイル。Claude Code や Codex を worker にできるかは未確認 | 無関係 |
| ralph-orchestrator | `LOOP_COMPLETE` か反復上限で止まる。テスト・lint・型検査の「backpressure」。stuck 検出の記述なし | ループ型。memories と tasks を永続化 | エージェントが `human.interact` イベントを出して返事かタイムアウトまで止まる。Telegram から途中で指示も送れる | Claude Code、Kiro、Gemini CLI、Codex、Amp、Copilot CLI、OpenCode、Pi ほか | 避けている |
| metaswarm | orchestrator が検証を自分で走らせ直す（子の自己申告を信じない）。レビューは 10 回で打ち切り | 承認済みの計画と実行状態を Beads でディスクへ。SessionStart と PreCompact の hook | 計画済みの確認点、再発・係争中の blocker、レビュー上限、曖昧な判断で人へ | Claude Code、Gemini CLI、Codex CLI。**「書き手は必ず別のモデルがレビューする」** と図にある（本文では「任意」とも書かれ、揺れている） | 乗っている（`.claude/agents/` の定義と hook。Task ツールかどうかは明記なし） |
| oh-my-claudecode | `omc wait` が利用上限の解除後に自動再開。ほかの stuck 検出は記述なし | `.omc/` に sessions、replay ログ、plans、handoffs | 停止時のまとめを Telegram / Discord / Slack へ | `/team` は Claude Code 内。`omc team N:<provider>` で codex、gemini、antigravity、grok、cursor、claude を tmux ペインの実プロセスとして起こす。`/ask <provider>` と 3 モデルの助言役 | **乗っている**。`/team` は公式 agent teams（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`）を使い、無効なら別経路へ落ちる |
| ccswarm | NDJSON のイベント記録。レート制限時は Claude へフォールバック。checkpoint からの復帰は「次の設計」で未出荷 | 段ごとにプロンプトを組み立てる。文脈窓の管理は記述なし | `queue drain` が commit と PR の前に y/n。`approve plan`。Herdr 上の live 段は質問で止まる | Claude（全面）、Codex（`codex exec`、読み取り専用の段はサンドボックス）、Copilot は不可。Sangha という quorum レビュー（承認数を数えるだけと自己申告） | Herdr のタブか headless（`claude -p`）。A2A の REST も持つ |

出典（すべて `[verified]`）: 各リポジトリの README。Gas Town は加えて https://github.com/gastownhall/gastown/blob/main/docs/design/polecat-lifecycle-patrol.md 、https://github.com/gastownhall/gastown/blob/main/docs/concepts/heartbeats.md 、https://github.com/gastownhall/gastown/blob/main/docs/design/escalation.md 、https://github.com/gastownhall/gastown/blob/main/docs/glossary.md 、https://github.com/gastownhall/gastown/blob/main/docs/design/witness-at-team-lead.md 。

## 4. Gas Town・Gas City・Beads の一次仕様

前回は一次の仕様が取れていなかった。今回 `docs/` を直接読めたので、まとめて書く。

### 4.1 Gas Town

- **mail と nudge の使い分け** `[verified]` https://github.com/gastownhall/gastown/blob/main/docs/design/mail-protocol.md
  - `gt nudge`: 相手の tmux セッションへ送る。bead も Dolt コミットも作らない。相手の文脈には system reminder として現れる。**相手のセッションが死んでいれば失われる**。日常の連絡はこちらが推奨
  - `gt mail send`: bead と Dolt コミットを作り、セッションの死を越える。使うのは handoff、プロトコルのメッセージ、エスカレーション、HELP だけ
  - 判定の決め方: 「相手のセッションが死んで再起動した後もそのメッセージが要るか。要るなら mail、要らないなら nudge」
  - 役ごとの予算: Polecat は 1 セッションに mail 0〜1 通、Dogs は mail なしで nudge で報告、Mayor は戦略的な調整だけ
  - mail を絞る理由は「mail 1 通ごとに永続の Dolt コミットが増え、履歴が膨らむ」ため
  - メッセージ型: POLECAT_DONE、MERGE_READY、MERGED、MERGE_FAILED、REWORK_REQUEST、RECOVERED_BEAD、RECOVERY_NEEDED、HELP、HANDOFF
  - 件名は大文字の型名で始め、本文は 1 行 1 組の key-value の後に自由文
  - 宛先はグループ（全員へ）、キュー（1 通を 1 人が claim）、チャネル（pub/sub、保持数か保持期間つき）も持つ
  - 受領: 配送の受領証は書かれていない。受信側が `gt mail read <id>` で読み、`gt mail ack <id>` で処理済みにする
- **nudge の配送モード** `[unverified-summary]` https://gastown-guide.pages.dev/
  - 「tmux send-keys へ直接、またはファイルのキュー」「wait-idle（既定）/ queue / immediate の 3 モード」とするコミュニティの手引きがある。一次の設計文書では配送の仕組みまで確かめられなかった
  - リリースノートに「Codex の経路は、キュー済みの nudge を流す前にアイドルを待つ」（v0.13.0）とあり、キューとアイドル待ちが実在することは裏づけられる `[verified]` https://github.com/gastownhall/gastown/releases
- **handoff** `[verified]` 用語集、mail-protocol.md、polecat-lifecycle-patrol.md
  - 用語集の定義: 「Agent session refresh via `/handoff`」。文脈が埋まったときや仕切り直したいときに、作業状態を新しいセッションへ移す
  - セッションが替わるきっかけは `gt handoff`、自動 compaction（PreCompact hook が状態を保存）、クラッシュの 3 つ
  - 引き継ぎの中身は git の状態、Beads の状態、agent bead の `hook_bead`。**「明示の handoff 文面は要らない。Beads の状態が handoff の役をする」**
  - 新セッションの立ち上がり: `gt prime --hook` → `bd mol current`（次の step を見つける）→ `bd show`（指示を読む）
  - HANDOFF mail の本文: `attached_molecule`、`attached_at`、Context（後任への自由記述）、Status、Next
  - リリースノート: v1.2.1 で handoff の respawn にエージェントプリセットの環境を完全にマージ。v0.13.0 でセッション再起動の前に利用者へ確認。v0.6.0 に PreCompact 用の `--auto` があるとする二次情報 `[unverified-summary]` https://newreleases.io/project/github/gastownhall/gastown/release/v0.6.0
- **Seance** `[verified]` README、用語集
  - 「Discovers previous agent sessions via `.events.jsonl` logs」。`gt seance` で前任の一覧、`gt seance --talk <id>` で問い合わせ
  - 前任セッションをどう読み、どう答えさせるかの内部は一次では未確認。リリースノートに Seance の変更は出てこない
- **Witness** `[verified]` README、polecat-lifecycle-patrol.md
  - rig ごとの巡回役。Polecat を見て、stuck を見つけ、復帰（nudge または handoff）を起こし、セッションを片付ける。自分では実装せず委譲する
  - 検出の閾値はわざと広い。誤って kill した過去のバグが文書に書かれている。「考え込んでいる」と「固まっている」を機械で見分けるのは誤りやすいので、最終判断は AI の Witness にさせる
  - zombie の確認は `detectedAt` を記録し、破壊的な操作の前にもう一度確かめる
  - 同じ step で 3 回落ちたら respawn をやめ、バグの bead を起こし、Mayor へ mail
- **Deacon と Boot、デーモン** `[verified]` heartbeats.md、architecture.md、用語集
  - Deacon は rig をまたぐ巡回役。Witness が死んでいれば再起動、古ければ nudge
  - Boot は「Deacon を 5 分ごとに確かめる特別な Dog」
  - heartbeat の置き場は 3 つ: Deacon の `heartbeat.json`（デーモンが読み、5 分で stale、20 分で very stale として poke）、セッションごとの自己申告（`gt heartbeat --state=working|idle|exiting|stuck`、Witness が読む）、agent bead のラベル（Witness が Deacon を見る「見張りを誰が見張るか」）
  - 規則: **1 つの置き場だけで stuck と断じない**。tmux セッションは生きているのに記録が古いのは「heartbeat の書き込みのずれ」であって stuck ではない
  - 方針: 私的な状態に頼らず、巡回のたびに Beads・git・tmux から状態を導き直す
- **身元とセッションの分離** `[verified]` identity.md
  - 身元（agent bead、経歴、作業履歴）は永続、セッション（Claude のインスタンスと文脈窓）と sandbox（worktree とブランチ）は短命
  - 身元は環境変数 `BD_ACTOR`（例: `{rig}/polecats/{name}`）で渡す
  - **2 つのセッションが同じ身元を名乗るのを防ぐ lock の記述は無い**
- **エスカレーション** `[verified]` escalation.md
  - 重大度と既定の経路: CRITICAL は bead + mail + email + SMS、HIGH は bead + mail + email、MEDIUM は bead + Mayor への mail
  - 4 時間 ack が無いと stale。`gt escalate stale` が重大度を 1 段上げて経路を実行し直す（最大 2 回）。Deacon の巡回が定期的に走らせる
  - 人は `gt escalate ack` で受け取りを示し、`gt escalate close` で閉じる。Mayor の起動時（`gt prime`）に未処理のものが重大度別に並ぶ
  - 「decision（複数の妥当な道があり選択が要る）」というカテゴリは設計に書かれているが、CLI フラグとしては未実装。**選択肢を並べて選ばせる仕組みは無く、本文に書くしかない**
- **agent teams への乗り換え案** `[verified]` witness-at-team-lead.md
  - 2026-02-08 付の Phase 1 仕様。tmux による Polecat の管理を Claude Code の agent teams に置き換え、Witness を lead にする案。「Future architecture — NOT YET IMPLEMENTED」のまま
  - 挙げている利点: Dolt への書き込みを 8〜9 割減らせる見込み、lead から実装ツールを外せる
  - 挙げている限界: teammate ごとの作業ディレクトリが無い、teammate のセッションは再開できない、トークンが 1 体あたり約 7 倍、実験的機能、1 セッション 1 チーム、agent teams の状態はチームと一緒に消えるので Beads が永続の台帳として残る

### 4.2 Gas City

- **Gas Town との関係** `[verified]` https://docs.gascity.com/getting-started/coming-from-gastown.md
  - 「Gas City is the successor platform」。Gas Town の仕掛けを取り出したもので、orchestrator は役割を 1 つもハードコードしない。役割はすべて、基本部品から作る設定である
  - Gas Town の役割は「Gastown pack」として同梱される（プラットフォームの型ではなく、運用モデルの 1 例）
  - 2 つを並べて動かせるかは書かれていない
  - 発表は 2026-04-24 とする二次情報 `[unverified-summary]` https://www.dsebastien.net/tag/news/page/7/
- **役割の対応** `[verified]` 同上

| Gas Town の役割 | Gas City での姿 |
| --- | --- |
| Mayor | 調整用のプロンプトを持つ設定済みエージェント。`gc session attach mayor` |
| Deacon | orchestrator の health patrol と設定の閾値。任意でエージェントにもできる |
| Witness | イベント、wait、formula、セッション数の設定。「witness」を置くのは pack 側の任意の振る舞い |
| Polecat | 増減する短命のエージェント設定（`min` / `max_active_sessions` の pool） |
| Refinery | 設定済みエージェント + formula か order の後処理。常駐の役ではなく手順の 1 段 |
| Crew | 永続の名前つきエージェント設定 |
| Dog | LLM の要らない仕事は core pack の exec order。エージェントが要る分だけ Gastown pack の `dog` pool |

- **捨てたもの・変えたもの** `[verified]` 同上
  - 捨てた: `~/gt/...` の決まったディレクトリ、パスから導く身元、コード中の役割名、order で足りる plugin、実体は shell コマンドである仕事のための補助エージェント、ラベルやメタデータで足りるのに Beads の外に置いていた永続状態
  - 変えた: Deacon の見張りは orchestrator の health patrol と reconcile に、Witness の追跡は wait・formula・イベントに
  - **自作エンジンへの含意**: Gas Town の作者自身が「LLM の見張り役を重ねる」構成を、非 LLM の制御ループと設定へ畳んだ
- **基本部品と状態** `[verified]` https://docs.gascity.com/getting-started/how-gas-city-works.md 、https://docs.gascity.com/
  - 部品: Agent、Bead、Formula、Rig、Pack、Event
  - 永続の仕事はすべて bead store に置く。タスク、mail、セッション、convoy は `type` が違うだけ
  - イベントは変更不可・追記のみで、単調増加の連番を持ち、どこからでも再生できる（例: `bead.created`、`session.crashed`、`order.fired`）
  - orchestrator はセッションを呼び戻さず、bead store とイベント列から進み具合を読む
  - 再起動時、orchestrator は生きているセッションを作り直さずに引き取り、それぞれにセッションの bead を作る
- **リリースノートから読める配送と排他の現状** `[verified]` https://github.com/gastownhall/gascity/releases
  - v1.5.1: 「Claude のセッションへ送った文字が権限プロンプトを承認してしまうことが無くなった」。gc がプロンプトを検出し、打ち込みを拒む。**`tmux send-keys` 型の送信が抱える事故を、作者自身が安全性の修正として扱っている**
  - v1.5.1: `gc stop` は store の停止まで controller lock を保持する。別の gc インストールの supervisor へ city を渡すことを拒む
  - v1.5.1: pool の孤児掃除は、city が保証できない claim を解放しない
  - v1.5.0: claim と close に同じ身元を使う。孤児掃除・死骸の片付け・`gc session kill` が、生きている、または再開できるセッションを殺さない・閉じない
  - v1.5.0: 試験版の SQLite 台帳（任意）に nudge のキューとメッセージングを置ける
  - README: セッションの土台は tmux（既定）、subprocess、ACP、Kubernetes。herdr は任意の代替
- **Gas Town のコマンドの行き先** `[verified]` https://docs.gascity.com/reference/gastown-command-map.md

| `gt` のコマンド | Gas City で最も近いもの | 注記 |
| --- | --- | --- |
| `gt handoff` | `gc handoff` | ほぼそのまま |
| `gt seance` | **無い** | resume とセッションのメタデータはあるが、seance のコマンドは無い |
| `gt nudge` | `gc session nudge` | 生きているセッションへ送る。`gc nudge` は遅延配送の操作（drain、drop、status、poll）だけ |
| `gt mail` | `gc mail` | 最上位だけ対応が書かれている |
| `gt prime` | `gc prime` | そのまま |
| `gt escalate` | **無い** | bead、mail、order、pack 側の手順で組む |
| `gt hook` | `gc hook` | 範囲は狭い（仕事の問い合わせと hook への注入） |
| `gt sling` | `gc sling` | そのまま |
| `gt done` | 単一の対応は無い | bead の close、メタデータの遷移、formula の 1 段など |
| `gt deacon` / `gt witness` | Gastown pack の同名エージェント + `gc session`、`gc status` | 仕事の多くは orchestrator / supervisor の振る舞いへ移った |
| `gt feed` | `gc events` | |

- **mail と nudge の実際** `[verified]` https://docs.gascity.com/tutorials/04-communication.md
  - mail: `gc mail send <宛先> -s <件名> -m <本文>`。bead として保存され、クラッシュを越える。**走行中のセッションへは、毎ターン hook が `gc mail check --inject` を走らせ、未読が system reminder として文脈に現れる**（エージェントは inbox を自分で見に行かない）
  - 既読: 明示の受領証は無い。エージェントが処理したら既読になる（「処理されるまで未読のまま」）
  - mail だけでは相手は起きない。`--notify` を付けるとターンを要求し、管理下の city では眠っている相手を起こせる
  - nudge: `gc session nudge <セッション> "<文>"`。端末入力を通る、撃ちっ放し、件名なし、クラッシュを越えない。相手を起こして新しいターンを始めるが、mail は運ばない（mail は hook 経由）
  - 出力は「Nudged」か「Queued nudge」。キューに積まれた nudge は、セッション開始時とターンの前に hook が流す
  - 仕事の投入: `gc sling <rig>/<agent> "<task>"` は **セッションではなくエージェントの雛形に宛てた bead** を作る。眠っていれば起こし、複数あれば空いているセッションへ回す
  - **自作エンジンへの含意**: 「本文は hook が注入し、端末入力は起こす合図だけ」という分け方は multi-agent-shogun、Cyclops と同じである。3 つの独立した実装が同じ形に収束している

### 4.3 Beads

- 「Distributed graph issue tracker for AI agents, powered by Dolt」 `[verified]` https://github.com/gastownhall/beads
- 置き場は Dolt（版管理つき SQL データベース）。組み込みモード（既定、単一の書き手、`.beads/embeddeddolt/`）とサーバーモード（複数の書き手）。SQLite への言及は無い。`.beads/issues.jsonl` は閲覧と交換用の書き出しで、正本ではない
- `bd update <id> --claim` は **atomic な claim**（担当者を設定し進行中へ）。HTTP 越しの `bd ready --claim` は現行サーバーでは 1 トランザクション
- ID はハッシュ由来（例: `bd-a1b2`）で、複数のエージェントやブランチでの衝突を避ける
- メッセージ用の issue 型（スレッド、短命のライフサイクル）と mail の委譲設定（例に `gt mail`）
- 「semantic memory decay」: 閉じた古いタスクを要約して文脈窓を節約する
- 文書サイトは beads.gascity.com。組織は `gastownhall`

## 5. そのほかの個別メモ

### 5.1 依頼で挙がった候補のうち、型が違ったもの

- **Claude Task Master**: 統括から子への委譲も、長時間走るエージェントの監視も README に無い。MCP と CLI から叩く **タスク台帳**（`.taskmaster/`、MCP ツール最大 36 個）である。「Loop Command」が自動化の項にあるが中身は未確認 `[verified]` https://github.com/eyaltoledano/claude-task-master
- **BMAD-METHOD**: AI コーディングツールに入れる「skill」の集まりで、製品・設計・UX・開発・テストの視点を手順として回す **仕様書駆動の方法論**。別プロセスの子を走らせて監視するかは書かれていない。「BMad Loop」という無人実行のモジュールはあるが仕組みは未確認 `[verified]` https://github.com/bmad-code-org/BMAD-METHOD
- **claude-code-by-agents**: v0.2.x で Swift のネイティブアプリへ全面書き直し。`@エージェント名` で宛先を指す **人が起点のチャット部屋** で、エージェントは対等。HTTPS のポーリング（SSE や WebSocket は使わない）。Claude Code が第一級、Codex は「使えるようになり次第」 `[verified]` https://github.com/baryhuang/claude-code-by-agents
- **Antfarm**: OpenClaw（v2026.2.9 以降）の上で動く。YAML と Markdown で決めた多段の手順を、役ごとのエージェントが cron のポーリングで拾う。SQLite に run と step の状態。**各 step は新しいセッション** で、続きは git 履歴と進捗ファイル（Ralph ループ由来）。再試行が尽きると人へ。awesome リストでは 2026-07-28 時点で休止 `[verified]` https://github.com/snarktank/antfarm
- **claude-swarm / SwarmSDK**: リポジトリは 404 で開けなかった。二次情報では、v1（claude-swarm）は Claude Code のインスタンスを MCP でつなぐ多プロセス構成、v2（SwarmSDK）は RubyLLM を使い **全エージェントを 1 プロセス内で動かす** 書き直しで、Claude Code に依存しなくなった。つまり v2 は「コーディング CLI の子を統括する」型から外れた `[unverified-summary]` https://rubygems.org/gems/swarm_sdk/versions/2.6.1?locale=ja
- **OpenClaw の multi-agent**: `sessions_spawn` で背景の sub-agent を起こし、結果は「announce の連鎖」で依頼元へ返る。子は既定で自分の文脈を持ち、`context: "fork"` で依頼元の記録を引き継ぐ。入れ子の深さや再起動後の復帰は別ページで未確認 `[verified]` https://docs.openclaw.ai/tools/subagents
- **Agent Flywheel**: 新しいサーバーを一式の環境にするインストーラ（ACFS）と、NTM、Agent Mail、Beads / Beads Viewer などの道具の束だとされる。束そのものに統括の仕組みがあるわけではなく、NTM が tmux の制御面、Agent Mail が連絡と予約、Beads が台帳を受け持つ `[unverified-summary]` https://acfs-web.vercel.app/flywheel
- **Tmux-Orchestrator**: Orchestrator → Project Manager → Engineer の 3 層。`send-claude-message.sh` で送り、`schedule_with_note.sh` で **自分の次回の見回りを自分で予約** する。状態は git（30 分ごとのコミット）と `LEARNINGS.md`。コードは 10 コミットで、実体は手順書に近い `[verified]` https://github.com/Jedward23/Tmux-Orchestrator
- **amux（mixpeek）**: Rust の単一バイナリ + SQLite。共有タスクボードの claim は atomic。エージェント同士が人を介さず「尋ね、渡し、詰まりを解く」。利用上限に当たると配送を保留し、解除時に再開。**クラッシュした子の再起動はサーバーの仕事ではなく**、任意の `scripts/tmux-watchdog.sh`（Claude の worker だけ）に任せる `[verified]` https://github.com/mixpeek/amux

- **tmux-ide**: 自分で「エージェントを見せてつなぐ物で、統括はしない」と書いている。Claude Code の lead が公式 agent teams で作った teammate を名前と状態つきで表示する。異種の組み合わせでは `tmux-ide send %2 "..."` と `tmux-ide wait agent-status api --status done` という部品で、lead から Codex のペインへ渡して完了を待てる。状態は tmux のペインオプション `@agent_state`（working / blocked / done / idle）に置き、Claude Code は hook で正確に、ほかは自己申告か画面読みで取る `[verified]` https://github.com/wavyrai/tmux-ide
- **bernstein**: スケジューラは素の Python で、計画を再生すると同じタスクグラフになる。エージェントはタスクごとの worktree で走り、「janitor」がテスト・lint・型などの具体的な信号を確かめてからマージする。状態は `.sdd/runs/<run_id>/` に checkpoint。54 のアダプタを自称 `[verified]` https://github.com/sipyourdrink-ltd/bernstein

### 5.2 multi-agent-shogun の追記

- 技術の土台（Bash、tmux、ファイルの mailbox、hook）が自作エンジンに最も近い `[verified]` https://github.com/yohey-w/multi-agent-shogun
- 設計上の決め事で参考になる点
  - 本文をファイルに置き、tmux には「mail あり」の合図だけ流す。合図は自己監視 → Stop hook → `tmux send-keys` の順で、後ろほど最後の手段
  - `dashboard.md` を書くのは家老だけ（単一の書き手で競合を無くす）
  - 応答しない相手への 3 段階のエスカレーションと、最後の手段としての文脈リセット
  - v3.4 で「inbox 配送のための Stop hook」を入れ、Claude Code 向けには Escape を送るエスカレーションを止めた
- **作者の後日談**: README に「作者自身は 10 体構成を 1 体に減らした。後継の kagemusha はエージェントの数ではなく『判断ループ』に重心を置く。multi-agent-shogun はこのままでも動く」という趣旨の注記がある。kagemusha の URL は確認できなかった
- 版の日付は README に無く、未確認

### 5.3 Overstory と Warren（同じ作者の 2 作）

- Overstory は Gas Town に最も近い構成（coordinator、SQLite の mail、3 層の watchdog、checkpoint と handoff）を持っていたが、**2026-05-28 にアーカイブ** された `[verified]` https://github.com/jayminwest/overstory
- 後継の Warren は方向を変え、「実行は端末セッションではなく workload であるべき」として、隔離された実行（bwrap / sandbox-exec、Docker、Kubernetes）、費用と並列数の上限、介入、復帰、git への配送を持つ **制御面** になった。エージェント間のメッセージングや階層は README に無い。こちらも「No longer maintained (Nov 2026)」 `[verified]` https://github.com/jayminwest/warren
- 2 作とも止まったこと自体が、個人でこの層を保守し続ける重さを示す材料である `[speculation]`

## 6. 設計の類型

| 類型 | 中身 | 該当 | 統括の文脈への手当て | 自作エンジンとの距離 |
| --- | --- | --- | --- | --- |
| 台帳中心型 | 仕事と状態を課題台帳に置き、セッションは短命で入れ替え可能にする。引き継ぎは台帳そのもの | Gas Town、Gas City、Beads、metaswarm、Hermes の Kanban、Paperclip、amux、5dive、AGX、Claude Task Master（台帳だけ） | 台帳への外部化。世代交代は「新しいセッションが台帳を読む」だけ | 中。自作エンジンは対話セッションを主に置くので、台帳の厚みが違う |
| メールボックス型 | 対等または緩い階層のエージェントが、永続の mailbox で連絡する。受領確認や予約（lease）を持つ | mcp_agent_mail（Python / Rust）、Cyclops、hcom、ClawTeam、Overstory の mail、Sno Station（未確認） | 本文を端末に流さないので文脈を汚しにくい。交代は扱わない | 配送と受領確認の面で近い |
| tmux 階層型 | 役を決めた親子を tmux のペインに並べ、ファイルと `send-keys` でつなぐ | multi-agent-shogun、Tmux-Orchestrator、Claude Code Agent Farm、codex-orchestrator、CAO、OpenRig、NTM、agent-deck の conductor | `/clear` と読み直し、context rotation、`clear_on_compact` | **最も近い**。土台（Bash、tmux、hook）まで同じなのは multi-agent-shogun |
| 制御ループ型（統括が LLM でない） | デーモンや reconcile ループが dispatch・再試行・片付けをする。LLM は子だけ | Symphony、Gas City の orchestrator、Hermes の dispatcher、Paperclip の heartbeat、Warren、bernstein、Scion | 統括に文脈が無いので問題にならない | 遠いが、流れはこちらへ向いている |
| ループ型 | 同じ指示を新しい文脈で繰り返し、ファイルと git で続きを運ぶ | ralph-orchestrator、ralph 系（ralph-claude-code、ralph-tui、ralphex は未確認）、Antfarm、kodo（未確認） | 反復ごとの新しい文脈 | 遠い |
| 仕様書駆動型 | 役割の視点と手順を文書で定め、1 つのセッション内か少数の subagent で回す | BMAD-METHOD、metaswarm の 9 段、ccswarm の flow | 計画と状態を文書へ | 遠い |
| 公式機能に乗る型 | Claude Code の agent teams や subagents を土台にして、手順と別 CLI の呼び出しを足す | oh-my-claudecode、metaswarm、（案のまま）Gas Town の witness-at-team-lead | 公式の compaction に任せる | 方針しだい |
| 部屋・組織図型 | チャットの部屋や組織図にエージェントを置き、人やチャネルから仕事を入れる | claude-code-by-agents、Paperclip、agent-swarm、Scion、5dive | サービス側の永続メモリ | 遠い |

## 7. 自作エンジンの 4 機能と、外で最も近い実装

### 7.1 統括の lease と世代交代

- **最も近い実装: Gas Town の handoff + Seance（世代交代）、Gas City の controller lock（排他）、NTM の context rotation（交代の手順）**。ただし 3 つを 1 つで満たす物は無い
- 同じ所
  - Gas Town: 文脈が埋まったら `gt handoff` で新しいセッションに替え、PreCompact hook で状態を残し、後任が `gt prime` で立ち上がる。前任への問い合わせ（Seance）まである
  - NTM: 「後任が handoff を受け取ってから古いペインを退かせる」という順序の保証と、交代中の自動再起動を止める柵
  - multi-agent-shogun と Claude Code Agent Farm: 文脈の残量や無応答をきっかけに `/clear` し、ファイルから読み直す
  - agent-deck の conductor: 統括セッション自身に `clear_on_compact` を持たせ、状態を `state.json` へ出す
- 違う所
  - **LLM の統括セッションの座を lease で排他する実装は、開いた範囲では見つからなかった**。Gas Town の設計文書には Mayor や Deacon の singleton 保証の記述が無い。Gas City の controller lock は Go の制御プロセスの座であり、LLM のセッションではない
  - タスクやファイルの lease は広く普及している: Hermes の Kanban（claim に TTL と heartbeat）、mcp_agent_mail（`ttl_seconds` つきのファイル予約、build slot）、Beads（atomic claim）、Paperclip（atomic checkout）、amux（atomic claim）、Claude Code Agent Farm（2 時間で stale の lock）。**TTL と heartbeat で延長する形は Hermes の Kanban が自作の lease に最も近い**。対象がタスクか統括の座かが違う
  - 後継の Gas City は handoff を残したが Seance を落とした。前任セッションへの問い合わせは、作者自身が次の版に持ち越さなかった機能である
  - Gas Town は「明示の handoff 文面は要らない、台帳の状態が handoff である」と割り切り、HANDOFF mail の常用を反パターンとしている。handoff 文書を主に置く方式とは逆の立場である
  - 外の主流は、世代交代を上手にやる方向ではなく、統括を非 LLM にして世代交代そのものを無くす方向（Gas City、Symphony、Hermes、Paperclip）
- 前回メモの「lease に相当する公開実装は見当たらなかった」は、**統括の座については今回も同じ結論**、タスクとファイルについては訂正（多数ある）

### 7.2 配送と受領確認

- **最も近い実装: Cyclops**。次点が CAO の inbox、mcp_agent_mail_rust、multi-agent-shogun
- 同じ所
  - Cyclops: tmux のペインへ打ち込む方式のまま、受領を段階で持つ（accepted → notified → claimed → completed）。相手が権限プロンプトやモーダルを出しているときは配送を止める。再起動後は途中のものを `attention_required` にする
  - multi-agent-shogun: hook（Stop）で受け取り、`tmux send-keys` は最後の手段。処理後に inbox で既読にする
  - mcp_agent_mail_rust: `ack_required` と `acknowledge_message`、未 ack の一覧と催促（`am acks pending / remind / overdue`）、配送の受領証（`get_message_delivery_receipt`）
- 違う所
  - Cyclops と multi-agent-shogun は **本文を端末に流さない**（合図だけ流し、本文は mailbox から claim させる）。`send-keys` で本文を運ぶ方式より、入力欄の状態への依存と文脈の汚れが小さい
  - Cyclops は「完了はアイドルから推測せず、明示の返信を要する」「不確かなら `submitted_unverified` と記録し、時間で再送しない」。hook で受領の印を取る方式は notified か claimed の段に当たり、completed の段は別に要る
  - Gas City は v1.5.1 で「送った文字が権限プロンプトを承認してしまう」事故を塞いだ。`send-keys` 型の送信には同じ穴がありうる
  - Gas Town の nudge は受領確認を持たない（失われてよいものだけを流す、という割り切り）。確実に届けたいものは mail に分ける
  - CAO は「相手が IDLE か COMPLETED のときだけ届ける」を既定にし、貼った後に処理開始の証拠を 8 秒待って、無ければ Enter を送り直す。ただし状態は貼れた時点で DELIVERED になり、受信側の受領までは追わない。**`send-keys` 型のまま堅くする手順としては最も具体的** である `[verified]` https://github.com/awslabs/cli-agent-orchestrator/blob/main/docs/inbox-delivery.md
  - ccmux（未確認）と Gas Town の Codex 経路も「相手がアイドルになるまで待ってから流す」
  - Gas City、multi-agent-shogun、Cyclops はそろって「本文は hook か mailbox、端末入力は合図だけ」に分けている
- Claude Code が子である限りは、前回メモのとおり公式の cross-session messaging（ソケット投函）が `send-keys` の代わりになる。ここに挙げた OSS はどれもそれに乗っておらず、tmux か自前の mailbox を使っている

### 7.3 判断ボード

- **最も近い実装: multi-agent-shogun の `dashboard.md`、agent-deck の conductor の仕分け、Gas Town の escalation**。ただし「選択肢と根拠つきで 1 枚」に当たる物は、開いた範囲では見つからなかった
- 同じ所
  - multi-agent-shogun: 家老 1 人が全員の報告を `dashboard.md` に集約する。人が見る 1 枚、書き手は 1 人という構図が同じ
  - agent-deck の conductor: 統括が「自分で答えてよいもの」と「人へ上げるもの」を分け、`NEED:` / `[urgent]` / `[info]` で通知の強さを変える
  - Gas Town: エスカレーションを bead として残し、重大度と経路を設定で決め、放置されると重大度を上げて再通知する。人は ack と close で応える
  - 5dive の `5dive inbox`（「何が自分を待っているか」）、Cyclops の `cyclops status`、Hermes の Kanban の `needs_input` での block、ralph-orchestrator の `human.interact`、OpenRig の lead
- 違う所
  - どれも「誰が、何で人を待っているか」を並べる所までで、**統括が判断事項を整理し、選択肢と根拠を付ける** 仕組みは無い。Gas Town は「decision」カテゴリを設計に書いたが未実装で、選択肢は本文に書くしかない
  - Gas City は `gt escalate` を引き継がず、エスカレーションは bead・mail・order で各自が組むものになった
  - mcp_agent_mail の Human Overseer は逆向き（人からエージェントへの優先メッセージ）で、判断待ちの集約ではない
  - 放置時の再通知（Gas Town の stale → 重大度を上げる）と、通知の強さの仕分け（agent-deck）は、判断ボードに足す値打ちのある部品である `[speculation]`
- 前回メモの「選択肢と根拠つきで 1 枚にまとめる物は見当たらなかった」は **今回も維持**

### 7.4 異種 CLI の子とセカンドオピニオン

- **最も近い実装: 異種 CLI の子は multi-agent-shogun と Gas Town、Claude から Codex への委譲は codex-orchestrator、別ベンダーのレビューは metaswarm**
- 同じ所
  - 異種 CLI を子にすること自体は **もはや普通** である。Gas Town（11 のプリセット）、multi-agent-shogun（7 種を役ごとに割り当て）、CAO（12 種以上）、OpenRig、Cyclops、hcom、NTM、Paperclip、Overstory、oh-my-claudecode（`omc team N:codex`）、Scion、agent-swarm、5dive がみな対応している
  - codex-orchestrator は方向まで同じ: Claude Code が親で、tmux の中の Codex を子として起こし、途中で向け直し、完了を待つ
  - metaswarm は「書き手は必ず別のモデルがレビューする」を掲げ、Codex CLI と Gemini CLI を敵対的レビューに使う。oh-my-claudecode は `/ask <provider>` と 3 モデルの助言役、ccswarm は Codex を読み取り専用の段に置く、kodo（未確認）は各サイクルを別のエージェントが検証する
- 違う所
  - 多くは「子として使える」までで、CLI ごとの違い（hook が無い、アイドルの見分け方が違う）は個別に吸収している。Gas Town は hook の無いランタイムに `gt mail check --inject` と起動時の nudge で代替し、multi-agent-shogun は CLI ごとの画面の型で busy / idle を見分け、Cyclops は 5 種だけを「実機で検証済み」と区別している。**異種 CLI は対応数より、検証済みの数を見るべきである**
  - 別ベンダーのレビューを **手順に組み込んで必須にしている** のは metaswarm くらいで、ほかは呼べる道具を置くだけ。ただし metaswarm の README は「必ず」と「任意」の両方を書いており、実際の強制の度合いは未確認
  - ccswarm の quorum レビューは「承認の数を数えるだけで、異論の解消はしない」と自己申告している。多数決型のレビューの限界として参考になる
- 前回メモの「公式機能では代替されない領域」はそのとおりだが、「自作でないと無い」わけではない。OSS 側には広く実装がある

## 8. 前回の結論の検証

対象の一文: 「親子の委譲・監視・世代交代まで持つのは Gas Town だけ。ほかは『人が各セッションを操る前提の並列ランチャー』」

- **判定: 誤り（探した範囲が tmux + worktree のランチャー群に限られていたため）**。次のとおり訂正する

| 持っているもの | 該当（今回 `[verified]` で確かめた物） |
| --- | --- |
| 親子の委譲 + 監視（stuck の検出と復帰） + 文脈が尽きることへの手当て | Gas Town、Gas City、multi-agent-shogun、Overstory（2026-05-28 にアーカイブ）、NTM、agent-deck の conductor、Hermes Agent の Kanban、Claude Code Agent Farm（子の `/clear`。統括は Python で LLM ではない） |
| 親子の委譲 + 監視。文脈の手当ては「統括が LLM でない」か「台帳に置く」ことで済ませている | Symphony、Paperclip、metaswarm、Antfarm、AGX |
| 親子の委譲はある。監視や復帰は薄い、または記述なし | CAO、OpenRig、ClawTeam、Vigil、codex-orchestrator、Tmux-Orchestrator、Scion、agent-swarm、5dive、amux、oh-my-claudecode |

- 訂正の具体
  - 「Gas Town だけ」→「**LLM の統括セッションを handoff で世代交代させ、前任への問い合わせ（Seance）まで持つ** のは Gas Town だけ。委譲 + 監視 + 文脈の手当てを持つ物は少なくとも 8 件ある」
  - 「Gas Town は現役で保守されている」（前回 5.2 節）→「**Gas Town 本体は 2026-07-23 を最後に機能の変更が止まり、依存更新だけ。後継は Gas City（v1.5.1、2026-10-24、毎日コミット）**。Gas City は役割を固定せず、Deacon と Witness の見張りを非 LLM の orchestrator に畳んだ」
  - 「Gas City は二次情報のみで未確認」→ 確定。公式文書が「Gas City is the successor platform」と書いている。なお Gas City には Seance も escalate も無く、**「handoff + Seance + 段階的エスカレーション」の組は、機能の変更が止まった Gas Town にしか無い**
  - 「nudge はセッションが死ぬと失われ、mail は越える（二次情報）」→ 一次で確認（`mail-protocol.md`）
  - 「lease に相当する公開実装は見当たらなかった」→ 統括の座については維持。タスクとファイルの lease は多数ある（7.1 節）。Gas City には制御プロセスの controller lock がある
  - 「Gas Town の escalation が判断ボードに最も近いが、選択肢提示ではなく課題の起票」→ 維持。加えて「decision」カテゴリが設計にあるが未実装であることを確認
  - 「ほかは人が各セッションを操る前提の並列ランチャー」→ 前回の表にあった物（AoE、Claude Squad、CCManager など）についてはそのとおり。ただし表の外に、統括型の OSS の層が厚くある
- 維持してよい点
  - 公式の Claude Code 機能（agent teams は lead 固定）では統括の世代交代は代替されない
  - 統括の座の lease と、選択肢つきの判断ボードは、外に同等物が見当たらない

## 9. 読む価値がある順の上位 5 件

1. **Gas Town の設計文書**（コードではなく `docs/`）
  - 理由: 自作エンジンと同じ問題（統括の交代、見張りの見張り、誤検出、送信の使い分け）を最も長く運用し、失敗も含めて文書に残している。機能の変更は止まったが、設計の記録としての値打ちは変わらない
  - 読む順: `docs/design/mail-protocol.md`（nudge と mail の使い分け、「再起動後も要るなら mail」）→ `docs/design/polecat-lifecycle-patrol.md`（閾値、誤 kill の教訓、「台帳の状態が handoff」）→ `docs/concepts/heartbeats.md`（1 つの記録で stuck と断じない）→ `docs/design/escalation.md` → `docs/design/witness-at-team-lead.md`（agent teams へ乗る案と、その限界の見積もり）
  - https://github.com/gastownhall/gastown/tree/main/docs
2. **Cyclops**
  - 理由: 「tmux のペインへ打ち込む」方式のまま、受領確認を段階（accepted / notified / claimed / completed）として設計し直している。合図だけ端末に流して本文は claim させる、権限プロンプトが出ていれば止める、不確かなら再送せず記録する、という決め方が、配送と受領確認の機能にそのまま当たる。小さく（スター 14）新しいので、将来の保守には頼れない。読むのは設計である
  - https://github.com/cyclops-team/cyclops
3. **multi-agent-shogun**
  - 理由: 土台が Bash + tmux + ファイル + hook で、自作エンジンと同じ。YAML inbox と `flock`、`inotifywait`、Stop hook での受け取り、単一の書き手による `dashboard.md`、3 段階のエスカレーションと `/clear` からの復帰を、そのまま読み比べられる。加えて、作者が 10 体から 1 体へ縮小し「判断ループ」へ重心を移したという後日談は、方向性を決める上での直接の材料である
  - https://github.com/yohey-w/multi-agent-shogun
4. **agent-deck の conductor**
  - 理由: 「長く走る統括の対話セッションが子を見張り、自分で答えるか人へ上げるかを決める」という形が、自作の統括と判断ボードの組に最も近い。通知デーモン + heartbeat の二重の見張り、`ORDERS.md` の「安い shell チェックで変化があったときだけ統括を起こす」節約、`NEED:` などの仕分け、`clear_on_compact` と `state.json` への外部化が参考になる
  - https://github.com/asheshgoplani/agent-deck
5. **Gas City**
  - 理由: Gas Town の作者が出した「次の答え」であり、年内の方向性の判断に効く。役割を設定に落とし、見張りを非 LLM の reconcile ループに畳み、すべてを bead とイベント列に置く。リリースノートは `send-keys` 型の送信と claim の事故の修正が並んでおり、同じ穴を先に知る資料になる。README に AI エージェント向けの指示が埋め込まれている点は注意
  - 読む順: `coming-from-gastown.md` → `how-gas-city-works.md` → Releases の v1.5.0 と v1.5.1 → コマンド対応表
  - https://docs.gascity.com/getting-started/coming-from-gastown.md 、https://github.com/gastownhall/gascity/releases

次点（目的が合えば）

- **NTM**: 統括ではなく制御面だが、context rotation の順序の保証（後任が handoff を受けてから前任を退かせる）が世代交代の手順として最も具体的 https://github.com/Dicklesworthstone/ntm
- **Hermes Agent の Kanban**: claim の TTL と heartbeat、stale の回収、crash の見分け（PID の再利用まで考慮）、再ブロックが続くと triage へ、という lease と復帰の作り込み https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban
- **Symphony の `SPEC.md`**: 「DB を持たず、トラッカーを真実として再起動後はポーリングし直す」という最小の復帰設計 https://github.com/openai/symphony/blob/main/SPEC.md
- **mcp_agent_mail_rust**: `ack_required` と未 ack の催促、TTL つきの勧告的な lease https://github.com/Dicklesworthstone/mcp_agent_mail_rust

## 10. 未確認事項（追加調査の候補）

- Gas City の `gc handoff` の中身（何を残し、後任をどう起こすか）
- Gas Town の nudge の実装（`tmux send-keys` か、キューか）と Seance の内部、Mayor の singleton 保証の有無（ソースを読む必要がある）
- CAO の handoff / assign の意味（`send_message` だけ確認した）
- agent-deck の `documentation/WATCHDOG.md`
- multi-agent-shogun の版ごとの日付、kagemusha の所在
- claude-swarm / SwarmSDK の現状（リポジトリが 404）
- OpenClaw の入れ子の深さ、再起動後の復帰、ACP 経由の Claude Code / Codex
- Hermes の Kanban で Claude Code や Codex を worker にできるか（「Codex App-Server Runtime」というページがある）
- 2.2 節の「リポジトリを開いていない物」全部（kodo、agentproto、Skiff、Runner、Crewly、Fusion、ccmux、bosun、Claudexor、Sno Station、no_human）
- 各リポジトリの作成日（「2026 年 6 月以降の新顔」の確定に要る。GitHub の HTML ページには出ない）
- 日本語圏の個人開発の OSS は、検索では multi-agent-shogun とその派生、claude-orchestrator-mvp しか拾えなかった。Zenn / Qiita を直接たどる追加の探索が要る

---
title: "agmsg に学ぶエージェント間通信パターン — スクレイプ脱却・配送セマンティクス・常駐プロセス管理"
date: 2026-05-31
status: research-complete
tags: [research-intake, orchestration-engine, agent-messaging, channel-design, sqlite]
sources:
  - https://dev.to/fujibee/i-built-agmsg-so-claude-code-and-codex-could-stop-using-me-as-a-copy-paste-relay-m42
  - https://github.com/fujibee/agmsg
related_ideas:
  - docs/research/oss-sessions/2026-05-31-agmsg.md
next_step:
  trigger: "orchestration-engine Phase 5（Issue #105 / #108）着手時、またはチャネル統一方針（#114）の ADR 化検討時"
  actions: "配送セマンティクス（push=割込 / poll=ターン間）をチャネル選択と分離する設計軸を engine に持ち込む。具体的には #108 の engine コンポーネント設計時に『取得方法』と『取得タイミング』を別レイヤとして整理し、現行 file-redirect（poll相当）に将来 push 型を足せる余地を残す。常駐購読型チャネルを検討する場合は agmsg #66/#67/#68 を先行事例としてライフサイクル管理（親セッション終了時の後始末・重複起動防止）を設計要件に含める。"
  referenced_by: "orchestration-engine Phase 5 Epic #105 / engine コンポーネント #108 / クリーン出力チャネル統一 #114（本ノートのコメントから逆参照）/ file-redirect 統一 #98"
---

## 概要

外部記事（著者 fujibee の DEV.to 解説）と OSS 本体調査（`docs/research/oss-sessions/2026-05-31-agmsg.md`）を起点に、agmsg のエージェント間通信設計から orchestration-engine に再利用可能なパターンを抽出した research-intake セッションの記録。

最大の発見は、**agmsg の「スクレイプ脱却 → 構造化バス」が orchestration-engine の通信路課題（Issue #114 / #98 / #101 / #115）と構造同型** であること。engine は現在「TUI スクレイプの脆さ」と格闘しており、agmsg は「テキストファイル方式の破損 → SQLite-WAL バス + 配送モード分離」で同型問題を先に解決している。マッピングは engine 接続を主軸に絞った（connections.md 系の弱い接続は archive 扱い）。

## 記事情報

- **タイトル**: I built agmsg so Claude Code and Codex could stop using me as a copy-paste relay
- **URL**: https://dev.to/fujibee/i-built-agmsg-so-claude-code-and-codex-could-stop-using-me-as-a-copy-paste-relay-m42
- **著者/組織**: fujibee（個人）
- **公開日**: 2026-05-28
- **種別**: ブログ記事（OSS 本体は `oss-research-session` で深掘り済み）
- **要約**: 複数 CLI エージェント併用時に人間が「コピペ中継役（copy-paste relay）」になる問題を、共有 SQLite DB 経由の直接メッセージングで解消する。配送セマンティクス（monitor/turn/both/off）と最小依存（bash + sqlite3 のみ、デーモン・ネットワーク不要）が設計の核。「2 つの Claude に三目並べを人間ゼロ介入で完走させた」デモが象徴的。

## 本質的パターンと詳細

| # | パターン名 | 本質 | 種別 |
|---|-----------|------|------|
| 1 | スクレイプ脱却→構造化バス | 非構造な共有テキストを覗き見/読み書きする方式は並行アクセスで破損する。構造化ストア（SQLite WAL）を共有バスにして堅牢化 | 設計原則 |
| 2 | 配送セマンティクスの軸 | 機能より「配送方法」が有用性を決める。push(割込)・poll(ターン間)・両用・手動を選択肢として分離 | 設計原則 |
| 3 | 3軸ドライバモデル | storage / agent / delivery を独立に差替可能にし、bash の source 可能な関数群＋プロトコルで抽象化 | 実装パターン |
| 4 | アイデンティティとメタデータの分離 | エージェントの本質的同一性は `(name, team)`、プロジェクトパス/type は登録メタデータ | 設計原則 |
| 5 | 最小依存・デーモンレス | python/node/常駐/ネットワークを意図的に排除し導入ハードルを最小化 | 設計原則 |
| 6 | 排他ロックによるマルチロール | `actas` で 1 プロジェクト複数役割を切替。ロール宛購読の漏洩を排他ロックで防止 | 実装パターン |
| 7 | 常駐購読プロセスのライフサイクル課題 | monitor 用 watch プロセスがセッション終了後も生存/重複リーク（反面教師） | 設計原則 |

### パターン詳細（なぜ有効か・どう使うか）

- **#1 スクレイプ脱却→構造化バス**: agmsg は当初プレーンテキストファイル方式を採ったが並行アクセスで破損した。SQLite の WAL モード（単一 writer + 複数 reader + トランザクション耐久性）に移行し、並行安全性とメッセージ履歴を同時に得た。engine の「2D グリッド scrape の脆さ」とは破損要因が異なるが、「**非構造な共有テキストに依存する方式は脆い**」という同じ結論に到達している点が再利用価値の核。
- **#2 配送セマンティクスの軸**: `monitor`（SQLite 常時購読＝push/割込、約5秒）/ `turn`（Stop フックでターン間 poll、Codex デフォルト）/ `both`（monitor 主＋turn 保険）/ `off`（手動）。著者は「monitor が toy→useful の分岐点だった」と述べ、**「クリーンに取れること」と「いつ取るか」を別問題として設計**している。これが engine の「マーカーはどんな形でも取れる前提」を満たす実装パターンとして直接参考になる。
- **#3 3軸ドライバモデル**: ARCHITECTURE.md / ADR 0001 が定義。ドライバは bash の source 可能な関数群として `<axis>_check` / `<axis>_describe` 等のプロトコルを実装。新規書き込みは append-only イベントログ（UUIDv7）へ向かい、既存整数 ID テーブルは後方互換のため opaque string として維持。ベンダー非依存を bash で実装した具体事例。
- **#4 アイデンティティ/メタデータ分離**: `(name, team)` を Immutable な核、プロジェクトパス/type を Mutable なメタデータとして分離。同一名エージェントを複数プロジェクトから join しても重複しない。
- **#7 常駐購読プロセスのライフサイクル課題**: monitor 用 `watch.sh` が所有 CC セッション終了後も生存、複数 monitor 起動で watcher 重複リーク等の未解決 Issue（agmsg #66/#67/#68）。常駐購読プロセスのライフサイクル管理が agmsg 現状の弱点であり、engine が file-redirect 以外に「常時購読型チャネル」を検討する場合の**同型の落とし穴**として参照価値がある。

## 実装参照候補

| # | 対象 | リポジトリ | ライセンス | 確認元 | 流用形態 |
|---|------|-----------|-----------|--------|---------|
| 1 | SQLite-WAL バス + delivery driver の bash 実装 | [fujibee/agmsg](https://github.com/fujibee/agmsg) | MIT | OSS 調査ノート（リポジトリ LICENSE） | パターンのみ参照（直接取り込みではなく設計参照） |

ライセンスは MIT で copyleft/unknown フラグなし。直接取り込みではなくパターン参照に留めるため互換性問題は発生しない。

## 資産マッピング結果（engine 主軸）

### トラックA: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ/新規知見 |
|---------|--------|-----------|-----------------|
| #1 スクレイプ脱却→構造化バス | Issue #114（scrape 脱却・出力チャネル統一）、#98（file redirect 統一）、#101/#115（マーカー偽陽性・TUI 字下げ緩和） | 補強 | engine の現行課題と構造同型。agmsg は「ファイル方式破損→SQLite-WAL」を先に踏破した代替通信路の先行事例 |
| #2 配送セマンティクスの軸 | `docs/draft/orchestration-control-loop-challenges.md`「進捗共有＝ハブ機能」、Phase5 Epic #105 / #108 | 拡張 | engine に「push(割込) vs poll(ターン間)」配送軸が未整理。monitor/turn の二択を engine の状態共有設計に流用可 |
| #7 常駐プロセス・ライフサイクル | Issue #111（wez pane フォーカス奪取）、engine の watch/pane プロセス管理 | 補強（反面教師） | agmsg #66/#67/#68 の watcher 生存/重複リークは engine の常駐プロセス管理と同型課題 |

### トラックB: 新規導入候補（archive 扱い）

| パターン | 既存対応物 | 導入形態 | 実現可能性メモ |
|---------|-----------|---------|-------------|
| #2+#1 agmsg 型バスを engine の pane 間通信路として検討 | engine は現状 TUI スクレイプ | experiment / 記録 | 大きめのアーキ判断。今すぐの実装ではなく defer 対象（next_step 参照） |
| #6 排他ロックによるマルチロール | engine に明示的対応物なし | archive-note | 並列 reviewer 複数役割化の将来検討材料 |

### archive 扱いに落とした弱い接続（engine 主軸の判断）

- #3 3軸ドライバモデル ↔ connections.md「契約で固定、ツール名で固定しない」原則: ベンダー非依存設計の参照事例として記録のみ。
- #4 アイデンティティ/メタデータ分離 ↔ connections.md「コンテキスト・エンベロープ Immutable/Mutable 分離」: 構造の類似を記録のみ。

## アクション判定

| # | パターン | アクション | 理由 |
|---|---------|-----------|------|
| #1 | スクレイプ脱却→構造化バス | enrich-existing #114 | #114 と構造同型で、ADR 化検討に直接効く prior-art。参照コメントを投稿（実施済み） |
| #2 | 配送セマンティクスの軸 | defer | Phase5 #105/#108 着手時に push/poll 配送軸を engine 設計へ。本ノート `next_step` に記録 |
| #7 | 常駐プロセス・ライフサイクル | archive-note | engine watch/pane 管理の反面教師として記録 |
| #3/#4/#6 + TrackB | 弱い接続 | archive-note | engine 主軸のため深掘りせず記録のみ |

## 関連リンク

- [OSS 調査ノート: agmsg](oss-sessions/2026-05-31-agmsg.md)
- [GitHub: fujibee/agmsg](https://github.com/fujibee/agmsg)
- [著者解説記事（DEV.to, 2026-05-28）](https://dev.to/fujibee/i-built-agmsg-so-claude-code-and-codex-could-stop-using-me-as-a-copy-paste-relay-m42)
- [Issue #114: クリーン出力チャネル統一方針（scrape 脱却）](https://github.com/stlwolf/ai-development-hub/issues/114)
- [Issue #105: 自前オーケストレーション Phase 5](https://github.com/stlwolf/ai-development-hub/issues/105)
- [Issue #108: Phase 5 engine コンポーネント](https://github.com/stlwolf/ai-development-hub/issues/108)

# 全体アーキテクチャ素描 — 自前オーケストレーションツール

> Q&A 形式の設計議論（Issue #18）を経て、確定した判断・未決定事項・MVP 構成を1枚にまとめる。

> **文書ステータス (2026-05 更新)**
>
> 本文書は Phase 3 Synthesis 完了時点の素案 (§1〜§10) に、Phase 4 MVP 完了報告 (§11、2026-05) を加えた **2 層構造の frozen 文書**。以降の orchestration-engine の設計判断は [`projects/orchestration-engine/docs/decisions/`](../../orchestration-engine/docs/decisions/) 配下の ADR を正本とし、本文書には追記しない。
>
> Phase 4 完了時点の engine の使い方 / 構成は [`projects/orchestration-engine/README.md`](../../orchestration-engine/README.md)、Step ごとの経緯は [`projects/orchestration-engine/docs/episodes/`](../../orchestration-engine/docs/episodes/) を参照。

## 1. ポジショニング

### 何を作るか

**構造化ドキュメントのルーティングエンジン。** 入力ドキュメント → 適切なエージェント（CLI プロセス）に渡す → 出力ドキュメントを受取る → 次のエージェントに渡す。その間のフォーマット・フロー・検証のプロトコル。

### 何を借りるか

| 層 | 借りるもの |
|----|----------|
| プロセス管理 | Cursor / Claude Code / Codex |
| ツール実行 | 各 CLI のネイティブ機能 |
| フック仕様 | 各ツールの標準フック（PreToolUse / PostToolUse）|

### ハーネス語彙との対応

> 「モデルは CPU、コンテキストウィンドウは RAM、ハーネスは OS」

このツールは**コーディングエージェント特化ではない汎用ハーネス**に相当する。構造は同型:

| ハーネス概念 | 自設計での対応 |
|---|---|
| コンテキスト管理 | コンテキスト・エンベロープ + 蒸留パイプライン |
| ツール管理 | ディスパッチャ（CLI 呼び出し） |
| 検証ループ | 検証ゲート（adversarial review + 照合スクリプト）|
| フィードバックループ | Negative Knowledge 昇格 + 状態管理 |
| 人間ゲート | ワークフロー段階間の承認ポイント |

## 2. 設計原則

### 確定した原則

1. **薄いシェル**: Bash + jq。重い FW・ベンダーロックイン回避
2. **ドキュメント駆動**: 状態管理はファイルベース。構造化（ツリー・フォーマット・要約）が本質
3. **ネイティブ仕様 = 共通インターフェース**: フックに限らず、Skills / Subagents / Rules 等の AI コーディングツールが提供する仕様全般について、自前実装でもネイティブフォーマットに準拠する。独自フォーマットを発明しない
4. **選択肢 B**: CLI ランタイムは借りて、独自の価値は協調プロトコルとコンテキスト設計に集中
5. **Build to Delete**: 薄く作り、不要になった層は捨てる前提

### 小さい単位 × 明確な境界 × 低レイヤチェック

context-foundation.md の議論から導出された基本ガードレール:

- エージェントが1回にやることを小さくする
- 各単位の境界（入出力スキーマ）を明確にする
- 低レイヤ（API スキーマ、フィールド整合性）のチェックを最初と最後に入れる

## 3. 認知協調層

### 現状の3機能

| 機能 | ツール | 役割 |
|------|--------|------|
| **入力の多様化** | arena-compare | 設計段階で複数モデルの並列意見を取得（発散）|
| **承認ゲート** | peer-ai-review + so-compare | 実装方針の3者合意（収束）|
| **スキル運用** | 「SO」で自然起動 | 定着済み |

### ギャップ: 修正後の再検証 + 完了時の網羅性チェック

現状、親エージェントが fix-loop の結果に十分に懐疑的でない。人間が最終段階で抜けに気づいて戻すパターンが繰り返し発生。

### adversarial review の段階導入（優先度順）

| 優先度 | タイミング | 何をするか |
|--------|-----------|-----------|
| **B: 最優先** | 各タスク完了後 | 実装者の報告を疑い、実コードを読んで Plan/仕様と照合するレビュアー |
| **A: 2番目** | Plan 完了後 | 既存コードがある場合は暗黙的にスキップされている制約を洗い出す。既存コードがない場合でも、AI モデルが持つ一般的な開発のデファクトスタンダード・既知のナレッジから導出できる抜け漏れをチェックする |
| **C: 3番目** | 全体完了時 | 成功条件（ドキュメント駆動テスト）との照合で人間の負担を軽減 |

### 認知協調のアーキテクチャ上の位置づけ

- **コア機能**（オプショナルではない）
- Arena = 上流（設計の発散）、Peer Review = ゲート（収束）、Adversarial Review = 検証（自己回帰）
- adversarial review は**検証ゲート（MVP #5）の主要実装**として組み込む

### Phase 4 確定事項 (2026-05 追記)

- **「ゲートが実行されたか」問題** (§8 で指摘) は Step 4-3 で `verification_completed` audit イベント + `verification_summary` 集計 + `circuit_breaker_triggered` の組み合わせで構造的に証明する形に確定 ([ADR: `2026-05-16-decision-verification-gate-design.md`](../../orchestration-engine/docs/decisions/2026-05-16-decision-verification-gate-design.md))
- **検証 agent の出力経路** は Step 4-4 で `tee /tmp/oe-{rsid}-reviewer.log` への file redirect に確定 (wez pane capture が viewport-only でスクロールアウトする問題への対応、[ADR: `2026-05-18-decision-reviewer-output-file-redirect.md`](../../orchestration-engine/docs/decisions/2026-05-18-decision-reviewer-output-file-redirect.md))
- skill (`canonical/skills/adversarial-review/SKILL.md`) の Status → engine marker (`@@OE_VERIFY:pass/fail/warn`) の mapping を ADR で正式化 (同上 ADR)

## 4. 正準エージェント定義

### 現状

canonical/ の構造（rules / skills / agents / commands）が**1エージェントの基盤として機能している**。

### 未決定事項（MVP 実装で固める）

| 論点 | 暫定方針 |
|------|---------|
| ロールのパッケージ方式 | adversarial reviewer を1体作る中で経験的に決定 |
| ルール注入メカニズム | フック基盤（#17）実装で決定 |
| frontmatter の具体フィールド | 複雑なスキルが必要になった時に拡張 |

### リサーチからの共通構造抽出（検討課題）

landscape/ の21ツール + skills-level-patterns の5パターンにおいて、エージェント定義は表現形式（YAML / Python クラス / Markdown）が異なるが、**本質的に同じ属性**を持っている可能性がある。MVP 前に、リサーチ資料からツール横断で共通する属性（Role/Goal/Constraints/Tools/Output Contract 等）を抽出し、canonical の正準フォーマットの基礎候補とする余地がある。

### 2層 frontmatter 構造

```
canonical 正本（フル属性）
  → sync 時に各ツール向け出力（対応分のみ）
```

正本には最大限のフィールドを持ち、sync スクリプトが Cursor / Claude Code / Codex それぞれに対応した形式で出力する。

### Phase 4 確定事項 (2026-05 追記)

Phase 4 MVP 実装で確定したスキーマ成果物の場所:

| スキーマ | パス | 主要用途 |
|---|---|---|
| envelope schema | [`projects/orchestration-engine/schemas/envelope.schema.json`](../../orchestration-engine/schemas/envelope.schema.json) | engine ↔ AI CLI 間の入力契約 (target / reviewer 両用) |
| audit log schema | [`projects/orchestration-engine/schemas/audit-log.schema.json`](../../orchestration-engine/schemas/audit-log.schema.json) | engine が出力する監査ログ (session_start / state_change / verification_* / cleanup 等) |
| session state schema | [`projects/orchestration-engine/schemas/session-state.schema.json`](../../orchestration-engine/schemas/session-state.schema.json) | KVS (per-session state、pane-keyed verification map、verification_summary 含む) |

「未決定事項」表 (上記) の現状:

- **ロールのパッケージ方式**: Phase 4 で「envelope の `use_skills` フィールドで skill を疎結合に指定する」形に経験的確定 (Step 4-3 ADR `verification-gate-design.md`)
- **ルール注入メカニズム**: フック基盤 [#17](https://github.com/stlwolf/ai-development-hub/issues/17) は本 Step 時点でも進行中、orchestration-engine 内では未着手 (派生 Issue / Phase 5 候補)
- **frontmatter の具体フィールド**: Phase 4 では Discussion / KickOff / Plan / Episode / Decision の 5 種類の frontmatter スキーマが経験的に固まった ([engine の各 doc](../../orchestration-engine/docs/) を正本)

## 5. MVP 構成

### 構成要素

```
[エンベロープ] → [ディスパッチャ] → [CLIプロセス] → [成果物パース]
                                                        ↓
                                                  [検証ゲート]
                                                        ↓
                                                  [状態更新]
```

| # | 構成要素 | 実装 | 備考 |
|---|---------|------|------|
| 2 | **ディスパッチャ** | Bash スクリプト | CLI 呼び出しの薄いラッパー |
| 3 | **コンテキスト・エンベロープ** | Markdown/JSON テンプレート | intent + 前段出力 + ルール |
| 4 | **成果物パース** | Bash + jq | stdout → 構造化ファイル |
| 5 | **検証ゲート** | 自前構築（OSS 情報を援用） | adversarial review + 照合スクリプト |
| 6 | **状態管理** | JSON ファイルベース | 構造化設計が本質 |

### MVP に含めないもの（後のフェーズ）

| # | 構成要素 | 理由 |
|---|---------|------|
| 1 | タスクグラフ | 最初は1タスク or 手動チェーンで十分 |
| 7 | 人間ゲート | 今は人間が CLI の前にいるので暗黙的に存在 |
| 8 | ルール注入 | canonical/ + sync が既に機能 |

### 最初のユースケース

- **対象**: ai-development-hub 内のツール改善タスク（例: Cursor スレッド出力ツール改善）
- **選定基準**: 安全（壊しても被害小）、実務利用中、1サイクル完結
- **検証すること**: 1サイクルが自律的 + 自己回帰的に回り、検証ループ含めて動作すること
- **Phase 4 結果 (2026-05 追記)**: Step 4-4 で **target = cursor-agent (composer-2) + reviewer = claude (sonnet-4-6)** の組み合わせで実機 1 サイクル完走を実証 ([PR #97](https://github.com/stlwolf/ai-development-hub/pull/97)、実機 smoke 2 回目で `verification_completed` emit + `protocol_errors=0 / timeouts=0` 確認、`check_cycle_complete.sh` 構造判定 4+2 点全 PASS)

## 6. 構造化の設計課題（状態管理・長期記憶）

> 問題は「ストレージ技術」ではなく「構造化設計」

- SQLite もドキュメントも本質は同じ — コンテキストの蓄積と取り出し
- ファイルベースで十分。注力すべきはディレクトリツリー構造、フォーマット標準、コンテキストを小さく保つ要約の仕組み
- context-foundation.md の「蒸留」テーマ（Discussion → KickOff → Plan → Episode → Decision/ADR）がそのまま構造化の指針

### ワークフロー段階と蒸留

```
Discussion（探索） → KickOff（方針） → Plan（計画） → Episode（実行） → Decision/ADR（永続化）
```

各段階で情報が蒸留され、コンテキストが小さくなる。この蒸留パイプライン自体がルーティングエンジンの主要なデータフロー。

## 7. landscape 読み込みからの追加メモ（2026-03-29）

Q&A 後に landscape/ の残りドキュメントを読み込んだ際のメモ。素描への統合は未実施だが、忘れないよう記録。

### 素描の既存セクションに影響するもの

| 項目 | 接続先 | メモ |
|------|--------|------|
| **Ralph Loop の再認識** | §3 認知協調 + §5 検証ゲート | hooks があれば比較的簡単に実現可能。検証ゲートの制御ループ実装候補。「不屈」「夜通し実行」と呼ばれるものの実態 |
| **ロール = スキルセットの動的選択** | §4 正準エージェント定義 | 任せる側がタスクに応じてどのスキルセットをロードするか自己判定する。ロールは固定ではなく動的選択というパターン |
| **ルーティングにおけるプロンプトのカテゴリ分け** | §5 ディスパッチャ | 複数 OSS で採用。Intent Classification 層を将来追加する候補 |
| **Observability を MVP から入れる可能性** | §5 MVP 構成 | 動作・フローの確実性・盲点の洗い出しに有用。リッチ CLI 表示 + ログ。steipete-ecosystem も強い。ただし MVP スコープ膨張リスクあり |
| **圧縮戦略 / Decision Ledger** | §6 構造化の設計課題 | ideas/20260329 の Decision Ledger（post-commit hook + LLM で判断だけ自動抽出 → JSONL）が context-foundation の「蒸留パイプライン未実装」に対する具体的実装パス |
| **Intent Refinement** | §3 adversarial A | 曖昧さの自動回避、多角的観点の獲得。A のチェックに「入力の曖昧さを AI が自ら検出・明確化する」ステップを追加する可能性 |

### 関連プロジェクト・アイデア（別トラックだが接点あり）

| 項目 | 関係 |
|------|------|
| **OpenHands の Docker 環境** | オーケストレーションとは別にサービス開発でも模索中。将来的にディスパッチャの実行環境として Docker 隔離を選択肢に入れられる |
| **WezTerm AI Mode PoC → `wez` CLI** | `projects/poc/wezterm-ai-mode/`。ディスパッチャが wezterm cli 経由でペイン分割 + エージェント起動、monitor で完了監視。**Ralph Loop の物理実装基盤**になりうる。**並行して開発を進める想定** |
| **自前 AI for CLI コマンドの並行開発** | Agent 向け CLI 記事との方向性一致。Agent DX を意識した自前 CLI がそのままディスパッチャの呼び出し先になる |
| **Mirror Repo / プラグイン的ジョイント** | ideas/20260329。OSS のスキル群を canonical にプラグイン的に取り込む配布モデルの可能性。長期記憶の外部情報配置問題とも直結 |

### 未解答の問い

- 実際の人間の開発フローやチーム運用を AI でどこまで模倣する必要があるのか？
- 大規模スキルセット系 OSS（gstack 28+、superpowers 20+）は実際どこまで使えるのか？
- beeAI の RequirementAgent（宣言的ルール制約）とスキル組み合わせによるロール構成の違いは？
- takt の Faceted Prompting、steipete の agent-scripts から具体的に何を流用するか？
- Mastra の Observational Memory（Reflector / 自動圧縮）はポストコンプリート/レトロスペクティブと同じ概念か？

### 並行進行の状況

- **オーケストレーションツール MVP**: 本素描に基づき Phase 4 で着手
- **WezTerm `wez` CLI**: 並行開発。Execution & Runtime 層の自前実装。Ralph Loop の物理基盤候補
- **Decision Ledger**: ideas/20260329 で構想。蒸留パイプラインの具体実装候補として MVP に合流する可能性

## 8. Epic #10 Tier 1 実装からの申し送り（2026-03-30）

canonical の skills/commands を整備する中（[Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) Tier 1: #11, #12, #13）で、**品質ゲートが「意図どおり実行されない」失敗モード**が観測された。MVP の検証ゲート設計に直接影響する。

### 観測された失敗モード

[Issue #13 コメント](https://github.com/stlwolf/ai-development-hub/issues/13) より:

- `so-compare` を `--codex-only` で誤実行 → 1者レビューだけで進めそうになった
- 2者で再実行したところ、1者では検出できなかった構造的問題（XSS 誤配置、AuthN/AuthZ 欠落等）が合意ベースで確認できた
- **レールを敷いても（スキル・チェックリスト・SO レビュー手順）、エージェントがレールを踏み外すケースは残る**

### 含意: 検証ゲート（§5）の「実行されたか」問題

architecture-sketch §3 で「親エージェントが fix-loop の結果に十分に懐疑的でない」を課題として記録していたが、問題はさらに手前にある:

- **品質ゲートをスキップする**: SO レビューの手順があるのに実行しない
- **品質ゲートを不完全に実行する**: 2者必要なのに1者で済ませる
- **品質ゲートの結果を無視する**: 指摘があるのに対処せずに進む

これらは「ルールで祈る」問題の変種。ルールをスキルに昇格させても、スキルの参照・実行自体がスキップされうる。

### MVP への設計入力

| 要件 | 根拠 |
|------|------|
| **検証ゲートの実行証跡**: ゲートが実行されたか・結果はどうだったかを構造化データとして残す | 「実行されたか」の事後検証が今は人間の目視に依存 |
| **ゲート実行の自動トリガー**: stop / subagentStop フックで検証を自動起動する | 手動起動だとスキップされる。#17（フック基盤）で部分対応 |
| **ゲート結果の健全性チェック**: SO の場合「2者が回ったか」「結果が非空か」を機械的に検証 | タイムアウト・片方空・0行出力でも exit=0 で通過しうる |
| **失敗時の回復パス**: ゲートが不完全だった場合にリトライを促す or 自動リトライする | 現状は人間が気づいて手動で再実行するしかない |

### so-compare 固有の改善候補

- タイムアウト後のリトライ判断（応答が遅いだけなのか止まっているのかの状況判断）
- 出力サマリに「期待プロバイダ数 vs 実プロバイダ数」を常に表示
- 片方が空/タイムアウトの場合の exit code 分離（成功=0 / 部分成功=1 / 全失敗=2 等）

これらは MVP のスコープというよりスクリプト単体の改善だが、MVP の検証ゲート設計の前提になる。

## 9. フェーズ計画

> §8 の申し送りにより、Phase 4 の 4-3（検証ゲート v1）は「ゲートが実行されたか」の健全性チェックを含むスコープに拡張する。

### Phase 3 完了条件（Synthesis）

- [x] context-foundation.md
- [x] skills-level-patterns.md
- [x] harness-engineering-mapping.md
- [x] Q&A による認知協調・正準定義の未解決点整理
- [x] **architecture-sketch.md（このファイル）**
- [ ] 認知協調の設計文書 → 不要と判断。実装が先行しており、素描に統合済み
- [ ] 正準エージェント定義の設計文書 → 不要と判断。MVP で経験的に固める

### Phase 4: MVP 実装（完了、2026-05）

| ステップ | 内容 | 成果物 | 状態 |
|---------|------|--------|------|
| 4-1 | エンベロープ + ディスパッチャの骨格 | `projects/orchestration-engine/` にスクリプト | ✅ 完了 (2026-05) |
| 4-2 | 成果物パース + 状態管理 | JSON スキーマ + パーサー | ✅ 完了 (2026-05) |
| 4-3 | 検証ゲート v1（adversarial review 相当） | 照合スクリプト + レビュープロンプト | ✅ 完了 (2026-05) |
| 4-4 | スレッド出力ツール改善を通した E2E 検証 | 1サイクル完走の実証 | ✅ 完了 (2026-05、[PR #97](https://github.com/stlwolf/ai-development-hub/pull/97)) |
| 4-5 | フィードバック → 設計修正 | architecture-sketch.md 更新 (本セクション + §11) | ✅ 完了 (2026-05、本 PR) |

### Phase 5 以降 (2026-05 追記)

Phase 5 (もしあれば) のスコープは本 Step (= Phase 4 完了時点) では未定。orchestration-engine の MVP 後拡張は派生 Issue 群 ([#92](https://github.com/stlwolf/ai-development-hub/issues/92) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93) / [#98](https://github.com/stlwolf/ai-development-hub/issues/98)〜[#102](https://github.com/stlwolf/ai-development-hub/issues/102)、計 7 件) で個別管理。次の大きなフェーズが必要になった時点で別 Epic として起票する。

Phase 5 の方向感メモは [`projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md`](../../orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md) (status: draft) に独立 doc として記録 (Step 4-5 で起草)。

### 作業管理

- 設計文書: orchestration-research/synthesis/ に集約
- 作業タスク: GitHub Issue ベースで管理
- MVP 実装のエピック: Phase 4 開始時に切り出す

## 10. 参照

- [Issue #18](https://github.com/stlwolf/ai-development-hub/issues/18) — Q&A → アーキテクチャ素描
- [Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) — OSS パターン取り込み
- [#17](https://github.com/stlwolf/ai-development-hub/issues/17) — フック基盤整備
- `synthesis/context-foundation.md` — コンテキスト基盤設計
- `synthesis/skills-level-patterns.md` — Skills/Rules レベルのパターン
- `synthesis/harness-engineering-mapping.md` — ハーネス概念マッピング
- `docs/draft/orchestration-control-loop-challenges.md` — 制御ループ課題
- `ideas/20260329/metadata-layer-mirror-repo-synthesis.md` — Decision Ledger / Mirror Repo 構想
- `projects/poc/wezterm-ai-mode/README.md` — WezTerm AI Mode PoC
- `.thread-exports/Agent向けCLI記事とideasの方向性検証_2026-03-29.md` — Agent 向け CLI 方向性検証

## 11. Phase 4 完了報告 (2026-05)

> Step 4-5 で追記 ([PR #TBD](https://github.com/stlwolf/ai-development-hub/issues/103))。Phase 4 全 5 Step (4-1〜4-5) 完了時点での到達点・設計判断・観察事実・派生 Issue・文書ステータスを集約。本文書はここで frozen とする。

### 11.1 到達点

Phase 4 で `projects/orchestration-engine/` 配下に Bash + jq + WezTerm + wez CLI で構築した orchestration-engine が、以下の状態に到達:

- **engine 実装**: `bin/oe` をエントリポイントに、`lib/{constants,envelope,spawn,capture,audit,verify,monitor,cleanup}.sh` の 8 モジュール構成。`schemas/` 配下に envelope / audit-log / session-state の 3 スキーマ
- **検証ゲート v1**: Compliance Review only、`@@OE_VERIFY:(pass\|fail\|warn)` marker、pane-keyed verification map、circuit breaker、verification_summary 集計
- **テスト**: mock 8 suite 合計 306 assertions GREEN + 実機 smoke (target = cursor-agent / composer-2、reviewer = claude / sonnet-4-6) で 1 サイクル E2E 完走実証 (`check_cycle_complete.sh` 4+2 点全 PASS)
- **駆動層 doc**: Discussion / KickOff / Plan / Episode / Decision (ADR) の 5 種類で Step 4-1〜4-5 を一貫管理

### 11.2 設計判断の集約 — ADR 5 件

Phase 4 で確定した主要な設計判断。詳細は engine 配下の ADR を参照。

| ADR | テーマ |
|---|---|
| [`2026-05-14-decision-cleanup-strategy.md`](../../orchestration-engine/docs/decisions/2026-05-14-decision-cleanup-strategy.md) | クリーンアップ戦略 (trap ハンドラ、pane kill、/tmp 削除、wez notify) |
| [`2026-05-14-decision-permission-separation-mvp.md`](../../orchestration-engine/docs/decisions/2026-05-14-decision-permission-separation-mvp.md) | MVP の権限分離方針 (検証 agent の権限境界) |
| [`2026-05-14-decision-issue-20-phase-convergence.md`](../../orchestration-engine/docs/decisions/2026-05-14-decision-issue-20-phase-convergence.md) | Issue #20 (wezterm-ai-mode) との Phase 収束方針 |
| [`2026-05-16-decision-verification-gate-design.md`](../../orchestration-engine/docs/decisions/2026-05-16-decision-verification-gate-design.md) | 検証ゲート v1 アーキテクチャ (Compliance Review only + 疎結合 skill 統合 + pane-keyed KVS) |
| [`2026-05-18-decision-reviewer-output-file-redirect.md`](../../orchestration-engine/docs/decisions/2026-05-18-decision-reviewer-output-file-redirect.md) | reviewer 出力経路 (file redirect、`tee /tmp/oe-{rsid}-reviewer.log`) + skill Status → @@OE_VERIFY mapping 表 |

### 11.3 観察された設計事実

Phase 4 全実装を通じて経験的に確認された設計に関する観察 (4 件):

- **mock 限界 — 実機 smoke が viewport-only バグを検出** (Step 4-4): mock 306 assertions は GREEN だったが、実 agent 起動時に reviewer marker が `wez pane capture` の viewport 範囲外にスクロールアウトする問題が発覚。E2E smoke は mock では捕捉できない設計バグを検出する位置付けと判明 ([Episode `2026-05-18-episode-step-4-4-implementation.md`](../../orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md))
- **駆動層 doc サイクルでの dogfood 成立** (Step 4-3 / 4-4): Discussion → KickOff → Plan → Episode → ADR の 5 段階を 5 Step 連続で完走、Cursor → Claude Code のツール間引き継ぎも駆動層 doc のみで成立。doc 主導の作業継続性が実証された
- **so-compare 2 段階レビューの有効性** (Step 4-3 / 4-4): 実装前 (Plan stage) と実装後 (Implementation stage) で so-compare (codex + claude) を 2 回投入することで、(a) 実装前 Critical 設計バグの早期発見 (例: Step 4-4 の grouping ミス)、(b) 実装後の品質チェック、の両輪が機能。所要時間は各回 3〜10 分
- **target / reviewer の出力経路非対称性** (Step 4-4): target は短文 (`@@OE_EXIT` 1 種類で末尾固定) のため `wez pane capture` で十分、reviewer は長文 markdown (review 本文 + verdict marker) のため file redirect 必須。同じ pane capture API が出力長で違う結果を生む

### 11.4 派生 Issue (MVP 後拡張候補)

Phase 4 で起票された open Issue 7 件 (本文書 frozen 時点)。MVP 後拡張として個別管理。

| Issue | 内容 |
|---|---|
| [#92](https://github.com/stlwolf/ai-development-hub/issues/92) | 検証ゲート v2 検討候補: 変更ファイル検出 per-pane 化 + 完了報告内容の充実 |
| [#93](https://github.com/stlwolf/ai-development-hub/issues/93) | reviewer 一時ファイル掃除 (前半は Phase 4 で対応済) + nonce marker (後半 = MVP 後拡張) |
| [#98](https://github.com/stlwolf/ai-development-hub/issues/98) | target ペイン出力を file redirect 経路に統一 (現状 reviewer のみ) |
| [#99](https://github.com/stlwolf/ai-development-hub/issues/99) | `bin/oe --task-file` の異常系 (空 / 不在 / 不正パス) の仕様明示 |
| [#100](https://github.com/stlwolf/ai-development-hub/issues/100) | `_oe_verify_scan_log_file` の単体テスト追加 |
| [#101](https://github.com/stlwolf/ai-development-hub/issues/101) | reviewer marker の false-positive 抑制 (markdown 引用との偶然一致) |
| [#102](https://github.com/stlwolf/ai-development-hub/issues/102) | `_oe_strip_ansi` 共通関数化 (capture.sh + verify.sh の重複解消) |

### 11.5 文書ステータス更新

本文書はここで frozen とする。Phase 5 以降 (もしあれば) の orchestration-engine の進化は別 Epic + engine 配下の Discussion/KickOff/Plan/Episode/ADR で記録する。Phase 5 着手前の方向感メモは [`projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md`](../../orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md) (status: draft) を参照。

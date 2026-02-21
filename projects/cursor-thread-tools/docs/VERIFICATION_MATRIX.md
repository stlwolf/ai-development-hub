---
title: "検証マトリクス: cursor-thread-tools 開発を通じたAI駆動開発フロー検証"
date: 2026-02-20
type: plan
related:
  - type: derived_from
    ref: plans/2026-02-20-kickoff-cursor-thread-tools.md
    reason: "キックオフの検証計画をさらに具体化"
  - type: derived_from
    ref: ../../../ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md
    reason: "意図的圧縮仮説の検証基準を採用"
  - type: derived_from
    ref: ../../../ideas/20260220/context-persistence-4layer-model.md
    reason: "4層モデルの運用検証"
tags: [verification, process, zero-base, reproducibility]
keywords: [検証マトリクス, 再現性, ゼロベース, フロー検証]
use_when:
  - "このプロジェクトの検証進捗を確認したいとき"
  - "次のゼロベースプロジェクトで同じフローを適用したいとき"
  - "どの仮説が検証済みかを知りたいとき"
---

# 検証マトリクス

本プロジェクト（cursor-thread-tools）の開発を通じて、**AI駆動ゼロベースプロジェクト開発のフロー全体**を検証する。ツール実装の検証と、開発プロセス自体の検証の2軸がある。

---

## A. ツール実装の検証

VS Code拡張としての技術的な実現可能性と実用性。

### A-1. DB読み取り基盤

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-1-1 | `better-sqlite3` で `state.vscdb` をread-only読み取り | 有効 | 動作確認 | Phase 1 で Node.js テスト実施。N-API prebuild で ABI 互換性あり。206 スレッド読み取り成功 |
| A-1-2 | Cursor起動中の同時アクセスでエラーが出ないか | 条件付き有効 | 動作確認 | Cursor 起動中に `readonly + busy_timeout=3000` で読み取り成功。WAL 3ファイルコピーフォールバックも実装済み |
| A-1-3 | `composerData` からスレッドメタデータ取得 | 有効 | 動作確認 | `json_extract` で `name`, `createdAt`, `isAgentic`, `fullConversationHeadersOnly`（bubble数）を取得。206件確認 |
| A-1-4 | `bubbleId` からユーザー発言テキスト取得 | 部分検証 | 有効 | `bubbleId:<composerId>:<bubbleId>` に JSON メタデータ格納。`type` 1=HUMAN, 2=ASSISTANT。テキストはメタデータ内または `agentKv:blob` 経由 |
| A-1-5 | `agentKv:blob` からアシスタント応答テキスト取得 | 有効 | テキスト抽出成功 | Phase 1: rg 局所抽出でマッピング解明（SHA-256 content-addressed）。Phase 2: raw protobuf パーサーで end-to-end テキスト抽出成功（5スレッド検証、user text 100%）。暗号化は現環境で非適用を確認。**仮説棄却**: `composer.content.*` はファイル差分用で会話テキストマッピングとは無関係 |
| A-1-6 | ~~`sql.js`（WASM）へのフォールバック~~ | 撤回 | - | peer-ai-review で3者合意: sql.js は本番経路に置かない（全量メモリロードでクラッシュリスク） |

### A-2. Markdownエクスポート

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-2-1 | ユーザー発言 + アシスタント回答の結合出力 | 有効 | 動作確認 | Phase 2 統合テスト: 5スレッドで user/assistant/thinking テキスト抽出成功。raw protobuf パーサーで ConversationStateStructure → turns → UserMessage.text / AssistantMessage.text を復元。conversationState 文字列のエンコード（base64 "~" prefix / hex）も解明 |
| A-2-2 | SpecStory出力との情報過不足比較 | 検証中 | 部分有効 | テキスト本文の抽出は成功。SpecStory との完全突合は Extension Development Host での E2E テスト後に実施予定。thinking_message は `<details>` タグで含める実装済み |
| A-2-3 | 大規模スレッド（400+ bubbles）での性能 | 有効 | 動作確認 | 75 turns / 3ms（25,000 turns/sec）。Markdown 生成含め 4ms。目標 5秒以内を大幅にクリア。400+ bubbles のスレッドは conversationState に含まれる turn 数が多くても同等の性能 |
| A-2-4 | コマンドパレットからの実行 | 有効 | 動作確認 | Extension Development Host で F5 実機テスト成功。`threadTools.export` → QuickPick → Markdown 生成・表示の E2E フロー確認。better-sqlite3@12.6.2 + Electron 39.4.0 + `@electron/rebuild` でネイティブモジュールロード成功。2スレッドで動作確認 |

### A-3. 自動保存 + CLI + カスタマイズ（ADR-004 でスコープ変更）

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-3-1 | 自動保存のバックグラウンド動作 | 有効 | 動作確認 | `setInterval` + `bubbleCount` 差分検知 + `onStartupFinished` でバックグラウンド動作。handle 管理 + dispose 登録 + mutex で重複実行防止。デフォルト無効（オプトイン）。peer-ai-review で `activationEvents` 不足・`createdAt` 不十分を修正 |
| A-3-2 | CLI からのスレッド一覧・エクスポート | 有効 | 動作確認 | `node out/cli.js list` / `export --all --since 24h` でターミナルから実行確認。12スレッド中11件エクスポート成功。`util.parseArgs()` でゼロ外部依存。JSON 出力対応。tmpDb クリーンアップ（SIGINT/SIGTERM）実装済み |
| A-3-3 | エクスポートオプションの設定 | 有効 | 動作確認 | `--no-thinking` / `--output-dir` / `--format` CLI 引数 + VS Code `contributes.configuration` で設定可能。`ExportConfig` 共通型で CLI/拡張の仕様一致を保証 |
| A-3-4 | 新フォーマットスレッド対応 | 条件付き有効 | 調査完了 | `conversationState: "~"` は空の base64 状態（長さ1で `extractCsString` が null 返却）。空スレッドまたは別データパスのスレッド。現在のコードは安全にスキップ（ワーニングメッセージ表示）。対応不能ケースは明示エラーで処理 |

### A-4. パッケージング・配布

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-4-1 | esbuild バンドリングで Extension + CLI が動作するか | 有効 | 動作確認 | `external: ['vscode', 'better-sqlite3']` で 22kb/19kb にバンドル。F5 デバッグ + `node out/cli.js list` で動作確認。shebang は `banner` で付与（ソース側を削除して重複解消） |
| A-4-2 | `.vsix` ファイルが生成でき、必要なファイルが含まれるか | 有効 | 動作確認 | `vsce package` で 8.08MB / 98 files。`.vscodeignore` ホワイトリスト型で `out/` + `better-sqlite3` + `bindings` + `file-uri-to-path` のみ含む。`--no-dependencies` は node_modules を除外するため使用不可（実検証で確認） |
| A-4-3 | CLI が `npm link` + `bin` フィールドで実行できるか | 有効 | 動作確認 | `cursor-thread-tools list`（104 threads）、`cursor-thread-tools export --all --since 24h`（13 threads、0 failed）で動作確認。npm link/unlink 正常 |
| A-4-4 | クロスプラットフォームパス（macOS / Windows / Linux） | 条件付き有効 | macOS で動作確認 | `getStateDbPath()` を `platform()` switch 文に変更。macOS で既存動作の回帰確認済み。Windows / Linux はコードレベル対応のみ（実環境テストなし） |
| A-4-5 | `@electron/rebuild` の自動化 | 有効 | スクリプト作成 | `scripts/install.sh` で npm install → esbuild → @electron/rebuild を一括実行。Electron バージョンは環境変数 > 引数 > デフォルト 39.4.0 の優先順 |
| A-4-6 | ドメイン固有情報の排除 | 有効 | 確認済み | `grep -r` で extension/src/ をスキャンし、ドメイン固有ハードコード値がないことを確認 |

---

## B. 開発プロセスの検証

「ゼロベースプロジェクトをAI駆動で開発する」フロー自体の検証。次のプロジェクトで再現するための知見を抽出する。

### B-1. コンテキスト永続化（4層モデル）

| ID | 検証項目 | 仮説 | 状態 | 判断基準 |
|----|---------|------|------|---------|
| B-1-1 | 層3（生ログ）→ 層2（構造化）の抽出パイプラインは機能するか | raw-logs/ → episodes/ への手動抽出で、判断経緯が復元可能になる | 有効 | Phase 1〜3 で計3回実施。Phase 3 エピソードの「コンテキスト復元性能」で評価: キックオフ + 既存ソースで十分にスタートでき、生ログを掘り返す必要なし。Phase 2 エピソードの「2系統のデータモデル」も構造化されていたため検索コスト低 |
| B-1-2 | 層1（Issue）への自動投稿は有意義か | thread-doneで投稿した完了報告が、次のタスクで参照される | 未検証 | 投稿した報告を実際に参照する場面が発生するか |
| B-1-3 | 層3のTTL（30〜90日削除）は現実的か | 抽出済み生ログの削除に心理的抵抗がないか | 未検証 | 削除後に「あの生ログが欲しかった」となるケースが発生するか |

### B-2. 意図的圧縮と昇格フロー

| ID | 検証項目 | 仮説 | 状態 | 判断基準 |
|----|---------|------|------|---------|
| B-2-1 | キックオフドキュメントで次スレッドの立ち上がりが速まるか | 前スレッドの議論を圧縮したキックオフがあれば、同じ説明を繰り返さない | 有効 | Phase 1〜3 で検証。Phase 2 教訓（CONVENTIONS.md 参照漏れ）を Phase 3 キックオフ冒頭に太字で反映 → Phase 3 エピソード: 「冒頭の指示で参照でき、Phase 2 の教訓が活きている」。条件克服済み |
| B-2-2 | Episode → ADR への昇格が自然に起きるか | 開発中に確定した判断がADRとして書き出される場面が発生する | 条件付き有効 | Phase 3 で ADR 3件作成（ADR-005〜007）。CONVENTIONS.md の昇格基準が機能。ただし3件ともフロー中ではなくポストコンプリーションで作成漏れ発覚。3フェーズ一貫して「ADR 作成がフロー中に漏れる」パターン。条件: ADR 作成を Step の TODO に独立配置 |
| B-2-3 | スレッド分化のたびにキックオフが蓄積されるか | 分化パターンが `plans/` の時系列で追跡可能になる | 有効 | plans/ にキックオフ3件 + 実装プラン3件が蓄積。Phase 1→2→3 の分化パターンが時系列で追跡可能 |
| B-2-4 | 構造維持の負荷が作業の邪魔にならないか | ドキュメント整理に使う時間が作業時間の10%以下に収まる | 条件付き有効 | Phase 3 で改善: Gate 1 が実施された（Phase 1,2 では全 gate 脱落）。plan/episode 分離ルール遵守。命名規則遵守。ただし ADR 作成はフロー中に漏れた（3フェーズ一貫）。peer-ai-review の事実検証精度にも課題（--no-thinking）。ルール + 最低限の gate 実施で運用可能だが、ADR フロー組み込みが残課題 |

### B-3. ゼロベース開発の再現性

| ID | 検証項目 | 仮説 | 状態 | 判断基準 |
|----|---------|------|------|---------|
| B-3-1 | ブレスト → キックオフ → 実装のフローが定型化できるか | 本プロジェクトで確立したフローが、次のゼロベースプロジェクトでそのまま使えるか | 条件付き有効 | Phase 1〜3 でフローを3回完走。各フェーズでプロセス改善が蓄積（Phase 2: plan/episode 分離、ADR 昇格基準。Phase 3: gate 実施、エピソード構造化）。フロー自体は定型化に成功。ガードレール（ADR フロー組み込み、事実検証粒度）の仕組み化が次プロジェクトへの展開条件 |
| B-3-2 | SpecStory + raw-logs で議論の文脈を完全に残せるか | 生ログがあれば、数週間後でも「なぜその判断に至ったか」を復元できる | 未検証 | 2週間後にraw-logを読んで判断経緯を復元できるか |
| B-3-3 | 検証マトリクス自体がフィードバックループとして機能するか | この表を定期的に更新することで、未検証項目の見落としを防げる | 有効 | Phase 1 完了時に A-1-1〜A-1-5 を更新、Phase 1 フィードバック時に B 系列を更新。参照・更新のサイクルが機能している |

---

## 検証の進め方

### 更新ルール

- 各検証項目の「状態」は作業の進行に応じて更新する
- 状態: `未検証` → `検証中` → `有効` / `無効` / `条件付き有効`
- 「根拠」欄にはエピソード/ADRへのリンクを記載し、トレーサビリティを確保する
- 新たな検証項目が見つかったら行を追加する（削除はしない）

### 状態の定義

| 状態 | 意味 |
|------|------|
| 未検証 | まだ着手していない |
| 検証中 | 実施中だが結論が出ていない |
| 有効 | 仮説が支持された / 機能が動作した |
| 無効 | 仮説が棄却された / 機能が実現不可 |
| 条件付き有効 | 特定条件下でのみ有効（条件を根拠に記載） |

### フィードバック先

- A系列（ツール）の結果 → `episodes/` に作業記録、確定判断は `decisions/` にADR
- B系列（プロセス）の結果 → `episodes/` にセッション記録、再現性の知見は `ideas/` に還元
- 全体の傾向 → 本ドキュメントの更新

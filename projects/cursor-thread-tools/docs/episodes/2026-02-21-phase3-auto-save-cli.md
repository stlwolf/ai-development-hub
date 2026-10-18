---
title: "Phase 3 自動保存 + CLI + カスタマイズ: コア層分離と3方向拡張"
date: 2026-02-21
type: episode
related:
  - type: implements
    ref: ../plans/2026-02-21-plan-phase3-auto-save-cli.md
    reason: "Phase 3 実装プランの実行"
  - type: implements
    ref: ../plans/2026-02-21-kickoff-phase3-auto-save-cli.md
    reason: "Phase 3 キックオフの実装"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-3-1〜A-3-4 の検証結果"
tags: [phase3, auto-save, cli, export-customization, core-refactor, util-parseArgs]
keywords: [core/threads.ts, cli.ts, util.parseArgs, setInterval, bubbleCount, onStartupFinished, ExportConfig]
---

# Phase 3 自動保存 + CLI + カスタマイズ: 作業記録

## 概要

Phase 2 の Markdown エクスポートを3方向に拡張: (1) コア層を VS Code 非依存にリファクタリング、(2) CLI エントリポイント、(3) エクスポートカスタマイズ + バックグラウンド自動保存。

## Step 0: 前提調査

### 新フォーマットスレッド

- `conversationState: "~"` は空の base64 状態（長さ1で `extractCsString` の `raw.length > 10` チェックで null 返却）
- 空スレッドまたは別データパスのスレッド。現在のコードで安全にスキップ済み
- Gate 0 スキップ: プラン peer-ai-review で3者合意済みの結論と同一のため

### CLI 方式

- Node.js ビルトイン `util.parseArgs()` を採用（外部依存ゼロ）
- `--no-thinking` の negation 処理も自動対応

### 自動保存デフォルト

- デフォルト無効（0分）、オプトイン方式

## Step 1: コア層リファクタリング

### 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `db/reader.ts` | `import * as vscode` 除去、`DbPathOptions` パラメータ化 |
| `core/threads.ts` | 新規。`ComposerMeta`, `parseComposerData`, `listAllThreads`, `extractThreadContent`, `resolveFileName`, `ExportConfig` |
| `commands/list.ts` | `core/threads.ts` から import、重複コード除去 |
| `commands/export.ts` | `core/threads.ts` から import、`readExportConfig()` で VS Code settings 読み取り |

### 設計判断

- `core/exporter.ts` → `core/threads.ts` に命名変更（listing も含むため、Claude 指摘）
- `ComposerMeta` は `export.ts` 側の完全な定義（`headers`, `rawJson` 含む）を正とした

## Step 2+3: CLI + カスタマイズ

### CLI 実装

- `cli.ts` 新規作成。`util.parseArgs()` でゼロ外部依存
- サブコマンド: `list` / `export <id>` / `export --all`
- `--json`, `--no-thinking`, `--output-dir`, `--format`, `--since`, `--app-name`
- `process.on('exit'/'SIGINT'/'SIGTERM')` で tmpDb クリーンアップ
- macOS 以外では明示エラー

### カスタマイズ

- `MarkdownOptions` に `includeToolCalls`, `fileNameFormat` 追加
- `package.json` に `contributes.configuration` 追加
- `ExportConfig` 共通型で CLI/拡張の仕様一致を保証

## Step 4: 自動保存

- `activationEvents` に `onStartupFinished` 追加（Codex peer-ai-review 指摘）
- `setInterval` + handle 管理 + dispose 登録 + `autoSaveRunning` mutex
- `bubbleCount` ベースの差分検知（`createdAt` は作成時刻のみで不十分）
- `globalState` のキーを現在のスレッドセットに限定（削除済みスレッド蓄積防止）

## Gate 1: peer-ai-review 結果と修正

SO 出力: `tmp/so-phase3-code-review/`

### 修正した高優先度指摘

| 指摘 | 指摘者 | 修正内容 |
|------|--------|---------|
| `setupAutoSave` のサブスクリプション蓄積 | Claude | dispose を `activate` に1回だけ登録 |
| `setInterval` 重複実行 | Codex | `autoSaveRunning` mutex 追加 |
| `runExportAll` の catch でエラー消失 | Codex+Claude | composerId + error message を stderr 出力 |
| `--since` がシングル export で無視 | Claude | 警告メッセージ追加 |
| `globalState` に削除済みスレッド残存 | Claude | 現在のスレッドセットでキー限定 |
| `console.log` が stdout 汚染 | E2E テストで発見 | `console.error` に変更 |

## Step 5: 検証結果

### CLI E2E

- `node out/cli.js list`: 98スレッド正常表示
- `node out/cli.js list --json`: JSON パース成功
- `node out/cli.js export --all --since 24h`: 12スレッド中11件エクスポート成功、1件スキップ（空コンテンツ）
- 日本語ファイル名正常動作
- better-sqlite3 は Electron 向けとシステム Node 向けで別々にビルドが必要（`npm rebuild` / `@electron/rebuild`）

### 性能

- CLI list: ~1.8秒（98スレッド）
- CLI export --all --since 24h: ~3.3秒（12スレッド、合計~900KB 出力）

## 想定外の点

- `db/reader.ts` の `console.log` が CLI の stdout を汚染 → `console.error` に修正
- better-sqlite3 の NODE_MODULE_VERSION 不一致: Electron 39 向けビルドとシステム Node は互換性なし。CLI 使用時は `npm rebuild` が必要

## プラン実行時に調整した点

- Step 2 と Step 3 をセット設計に変更（peer-ai-review 指摘通り）
- Gate 0 をスキップ（プラン peer-ai-review で既に合意済みの内容と同一）
- `MarkdownOptions.fileNameFormat` は `resolveFileName()` 関数に分離（テスト容易性のため markdown.ts とは独立に）

---

## ポストコンプリーション: プラン実行完了後の追加作業

### ADR 昇格（3件）

プランの ADR チェックリストに記載されていた3件を、実装完了後のユーザー確認で見落とし発覚。作成済み:

- `ADR-005-cli-packaging.md` — `util.parseArgs()` 採用（vs 手動パース / 外部ライブラリ / standalone バイナリ）
- `ADR-006-auto-save-default.md` — デフォルト無効・オプトイン方式（vs 30分 / 60分）
- `ADR-007-new-format-threads.md` — 新フォーマットスレッドは現状スキップ（「やらない」決定）

### E2E テスト中のバグ修正

| 修正 | 発見経緯 | 内容 |
|------|---------|------|
| `--no-thinking` が `ERR_PARSE_ARGS_UNKNOWN_OPTION` | E2E 実行時にクラッシュ | `util.parseArgs()` は `--no-*` negation を自動処理しない。`thinking: { type: 'boolean' }` → `'no-thinking': { type: 'boolean' }` に変更 |
| `main()` 未捕捉例外 | Codex Gate 1 指摘 | `main()` を try-catch で囲む |
| `--help` exit code 1 | Codex Gate 1 指摘 | `usage(0)` で正常終了に修正 |

### `--no-thinking` 問題の教訓

プランの peer-ai-review で Claude が「`--no-thinking` の negation 処理も `util.parseArgs()` で自動対応」と主張し、3者合意に含めた。しかし実際には `util.parseArgs()` は `--no-*` を自動処理しない。**事実主張の一次ソース検証が不十分だった**（Node.js 公式ドキュメントの `parseArgs` API に negation auto-handling の記載はない）。peer-ai-review の事実検証で「`util.parseArgs()` は Node 18.3+ で stable」は確認したが、negation 処理の具体的動作は未検証のまま合意していた。

### E2E テストファイルの所在

- `/tmp/thread-test/` — thinking 含むエクスポート（Phase 3 スレッド自身）
- `/tmp/thread-test-no-think/` — thinking 除外エクスポート（同スレッド）
- `--all --since 24h` テストは `mktemp -d` + `rm -rf` で削除済み

---

## スレッド作業フィードバック

### 成果物一覧（必須）

**新規ファイル（コード）:**
- `extension/src/core/threads.ts` — 共有ロジック（VS Code 非依存）。`ComposerMeta`, `parseComposerData`, `listAllThreads`, `extractThreadContent`, `resolveFileName`, `ExportConfig`
- `extension/src/cli.ts` — CLI エントリポイント。`util.parseArgs()`, list/export サブコマンド, SIGINT/SIGTERM クリーンアップ

**修正ファイル（コード）:**
- `extension/src/db/reader.ts` — vscode 依存除去、`DbPathOptions` パラメータ化、journal_mode ログを stderr に変更
- `extension/src/commands/export.ts` — core/threads.ts 利用、`readExportConfig()` で VS Code settings 読み取り、静的 import
- `extension/src/commands/list.ts` — core/threads.ts 利用、重複コード除去
- `extension/src/export/markdown.ts` — `MarkdownOptions` 拡張（`includeToolCalls`, `fileNameFormat`）、`ExportedTurn.toolName` 追加
- `extension/src/extension.ts` — 自動保存（`setupAutoSave` + handle 管理 + `autoSaveRunning` mutex + `bubbleCount` 差分検知 + `onDidChangeConfiguration` 監視）
- `extension/package.json` — v0.2.0、`contributes.configuration` 追加、`activationEvents` に `onStartupFinished` 追加

**ドキュメント:**
- `docs/plans/2026-02-21-plan-phase3-auto-save-cli.md` — 確定プラン（CP）、peer-ai-review 3者合意反映済み
- `docs/episodes/2026-02-21-phase3-auto-save-cli.md` — 本ファイル
- `docs/decisions/ADR-005-cli-packaging.md` — CLI パッケージング方法
- `docs/decisions/ADR-006-auto-save-default.md` — 自動保存デフォルト無効
- `docs/decisions/ADR-007-new-format-threads.md` — 新フォーマットスレッド対応方針
- `docs/VERIFICATION_MATRIX.md` — A-3-1〜A-3-4 更新
- `README.md` — Phase 3 完了ステータス、ディレクトリ構成に `core/threads.ts`, `cli.ts` 追加

**peer-ai-review ログ（tmp/）:**
- `tmp/peer-review-20260221-181128/review-log.md` — プラン peer-ai-review ログ
- `tmp/so-phase3-plan-review/` — プラン SO 出力（Codex + Claude）
- `tmp/so-phase3-code-review/` — Gate 1 コード SO 出力（Codex + Claude）

### 実行フロー概略

プラン作成（plan mode） → プラン peer-ai-review（3者合意、8件修正反映） → CP 配置・plan mode 同期 → ビルド実行（Step 0〜5 一貫実装） → Gate 1 peer-ai-review（コード、5件修正） → E2E テスト → ポストコンプリーション（ADR 3件追加、`--no-thinking` バグ修正、エピソード追記）

### 想定外の点（必須）

**ポジティブ:**
- コア層分離（Step 1）がスムーズだった。vscode 依存が `db/reader.ts` の1箇所のみだったため、パラメータ化だけで完了。`core/threads.ts` への抽出も `commands/export.ts` からの切り出しで自然に進んだ
- CLI の `util.parseArgs()` は宣言的で可読性が高く、手動パースより大幅に実装コストが低かった
- E2E テストで98スレッド / 12スレッドのエクスポートが問題なく動作し、性能も十分（list ~1.8秒、export --all ~3.3秒）

**ネガティブ:**
- `util.parseArgs()` が `--no-*` negation を**自動処理しない**ことが E2E で判明。peer-ai-review の事実検証で Claude の主張を裏取りせず合意していた。`thinking: { type: 'boolean' }` → `'no-thinking': { type: 'boolean' }` への手動対応が必要だった
- `better-sqlite3` の NODE_MODULE_VERSION 不一致: Electron 39 向けビルドとシステム Node.js は互換性がなく、CLI 使用時に `npm rebuild` が必要。Phase 2 からの既知制約だが CLI 追加で顕在化した
- `db/reader.ts` の `console.log` が CLI の stdout を汚染し、`--json` 出力が破壊された。拡張内では問題なかったが CLI で致命的だった
- ADR 3件の作成漏れ。プランのチェックリストに明記されていたが、実装フロー中に TODO として独立管理されておらず、ユーザー確認で初めて発覚

### ボトルネック

Gate 1 の peer-ai-review 実行（`so-compare.sh`）が最も時間を要した（Codex 44秒 + Claude 167秒 ≈ 4分）。実装自体は各 Step とも TypeScript コンパイル確認付きで順調に進行し、ボトルネックではなかった。

見積もりとの乖離: プランには見積もり時間が含まれていなかったため比較不可。今後のプランには Step ごとの概算時間を含めるべき。

### プラン実行時に調整した点（必須）

- **Step 2/3 をセット設計に統合**: peer-ai-review 指摘通り。CLI 引数と VS Code settings の `ExportConfig` 共通型を同時に定義した
- **Gate 0 をスキップ**: Step 0 の結論がプラン peer-ai-review で既に3者合意済みの内容と同一だったため。CONVENTIONS.md の gate 運用ルール「スキップ時はエピソードに理由記載」に従い本エピソードに記録
- **`MarkdownOptions.fileNameFormat` を分離**: `resolveFileName()` を `core/threads.ts` に独立関数として配置。markdown.ts の純粋関数性を維持
- **`console.log` → `console.error`**: `db/reader.ts` の journal_mode ログ。プランには含まれていなかったが E2E で発見・即修正

### コンテキスト復元性能

キックオフドキュメント（`2026-02-21-kickoff-phase3-auto-save-cli.md`）+ 既存ソースコード読み込みで十分にスタートできた。CONVENTIONS.md は冒頭の「作業開始前に必ず読むこと」指示で参照でき、Phase 2 エピソードの教訓が活きている。

生ログを掘り返す必要があった箇所: なし。ただし Phase 2 エピソード（`2026-02-21-phase2-markdown-export.md`）の「2系統のデータモデル」セクションは Step 0 の調査で参照した。エピソードが構造化されていたため検索コストは低かった。

### 規約・ルールの遵守状況と摩擦

**遵守できた:**
- plan/episode 分離ルール: プランは実行前の状態を保持し、結果はエピソードに記録
- ファイル命名規則: `YYYY-MM-DD-{plan|kickoff}-topic.md` / `ADR-NNN-topic.md`
- YAML frontmatter: 全ドキュメントに付与
- gate 運用: Gate 0 スキップ理由をエピソードに記載、Gate 1 は `so-compare.sh` で実施

**形骸化 / 違反した:**
- **ADR 作成がフロー中に漏れた**: プランのチェックリストに `- [ ]` で記載されていたが、TODO に独立項目として登録されていなかった。Phase 1, 2 と同じ「チェックリストが飛ばされる」パターンの再発。**ADR 作成を Step 5 の TODO に明示的に含めるか、実装完了時の自動チェックリストが必要**
- **peer-ai-review の事実検証が不十分**: `util.parseArgs()` の `--no-*` 自動処理を未検証のまま合意。「SO が言ったから正しい」バイアスの実例

### ナレッジ昇格

**ADR 化済み:**
- ADR-005（CLI パッケージング）、ADR-006（自動保存デフォルト）、ADR-007（新フォーマットスレッド）

**CONVENTIONS.md への追加案:**
- peer-ai-review の事実検証リストに「API の具体的動作（negation 処理、デフォルト値等）は公式ドキュメントの該当セクションを引用すること」を追加
- ADR 作成を Step の TODO に独立項目として登録するルールを明文化（「プランの ADR チェックリスト各項目を、対応する Step の直後に独立 TODO として配置」）

### 再利用可能な知見

- **`util.parseArgs()` パターン**: Node.js 18.3+ のゼロ依存 CLI 引数パース。ただし `--no-*` negation は手動定義が必要（`'no-thinking': { type: 'boolean' }` パターン）。このプロジェクト以外の Node.js CLI ツールにも適用可能
- **コア層 / UI 層分離パターン**: VS Code 拡張と CLI でコア層を共有する構造。`DbPathOptions` のパラメータ化 + `ExportConfig` 共通型で設定値の一致を保証。他の VS Code 拡張 + CLI デュアルツールに転用可能
- **`setInterval` + mutex パターン**: バックグラウンド定期処理の堅牢な実装。handle 管理 + dispose 登録 + `autoSaveRunning` フラグ + config 変更時の再セットアップ。VS Code 拡張のバックグラウンドタスク全般に適用可能
- **`bubbleCount` 差分検知**: `createdAt`（作成時刻）ではなく `bubbleCount`（メッセージ数）で変更を検知。`globalState` のキーを現在のスレッドセットに限定して肥大化防止。増分エクスポートのパターン

### プラン構築プロセスの改善案

- **事実検証の粒度を上げる**: peer-ai-review の事実検証テーブルに「検証方法」列を追加し、「公式ドキュメント確認」「実コード実行」「ソースコード確認」を区別する。「stable である」と「具体的な API 動作」は検証粒度が異なる
- **ADR 作成を TODO に含める仕組み**: プランの ADR チェックリストを Step の TODO に自動展開するテンプレート or コマンドを検討。3フェーズ連続で ADR 作成が漏れている
- **Step ごとの概算時間**: プランに見積もり時間を含め、実績との乖離をエピソードで記録する。ボトルネック分析の精度が上がる
- **E2E テスト Step を独立化**: 現在の Step 5（検証 + ドキュメント）を「Step 5: E2E テスト」「Step 6: ドキュメント」に分離。テストで発見したバグの修正 → 再テスト → ドキュメントのフローが明確になる
- **Gate のスキップ判断基準の明文化**: Gate 0 は「プラン peer-ai-review で合意済みの結論と同一」でスキップしたが、この判断基準を CONVENTIONS.md に追加すべき（「Gate の対象がプラン peer-ai-review で既に合意済みの場合はスキップ可。エピソードにスキップ理由を記載」）

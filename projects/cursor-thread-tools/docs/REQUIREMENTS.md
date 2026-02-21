---
title: "cursor-thread-tools 機能要件・非機能要件"
date: 2026-02-21
type: plan
related:
  - type: derived_from
    ref: plans/2026-02-20-kickoff-cursor-thread-tools.md
    reason: "プロジェクトキックオフのスコープ定義"
  - type: derived_from
    ref: decisions/ADR-004-scope-refocus.md
    reason: "スコープ変更（thread-done を外し、A+B 層に集中）"
tags: [requirements, scope, functional, non-functional]
use_when:
  - "新しいフェーズの計画時にスコープを確認したいとき"
  - "機能追加の判断時にスコープ内かどうかを判定したいとき"
---

# 機能要件・非機能要件

## プロダクト定義

Cursor の Composer スレッド会話データを **GUIトリガーなしで** 抽出・エクスポートする VS Code 拡張 + CLI ツール。

Cursor 内部データ（`state.vscdb`）への read-only アクセスを核とし、会話ログの保存・変換・自動化をワークフローに組み込むことを目的とする。

---

## 機能要件

### FR-1: スレッド一覧表示（Phase 1 完了）

| 項目 | 内容 |
|------|------|
| コマンド | `threadTools.list` |
| トリガー | コマンドパレット |
| 入力 | なし |
| 出力 | QuickPick UI（スレッド名、メッセージ数、作成日時、Agent/Chat 区別） |
| データソース | `composerData:*` from `state.vscdb` |

### FR-2: Markdown エクスポート（Phase 2 完了）

| 項目 | 内容 |
|------|------|
| コマンド | `threadTools.export` |
| トリガー | コマンドパレット（QuickPick でスレッド選択） |
| 入力 | スレッド選択（composerId） |
| 出力 | `.thread-exports/{name}_{id}.md` をワークスペースに保存 → エディタで開く |
| 出力内容 | ユーザー発言 + アシスタント応答テキスト。thinking は `<details>` 折りたたみ（デフォルト ON）。tool_call はテキスト抽出なし |
| データソース | `composerData` → `conversationState`（base64/hex protobuf）→ `agentKv:blob` → turn/message protobuf |

### FR-3: 自動保存（Phase 3 完了）

| 項目 | 内容 |
|------|------|
| トリガー | バックグラウンド `setInterval`（`onStartupFinished` でアクティベート） |
| 入力 | なし（全スレッド対象、差分検知で絞り込み） |
| 出力 | 設定ディレクトリ（デフォルト `.thread-exports/`）に Markdown 保存 |
| 差分検知 | `bubbleCount` ベース（`globalState` に前回値を保持、削除済みスレッド蓄積防止） |
| デフォルト | 無効（`intervalMinutes = 0`、オプトイン。ADR-006） |
| 備考 | `autoSaveRunning` mutex で重複実行防止。`onDidChangeConfiguration` で設定変更時にタイマー再セットアップ |

### FR-4: CLI エントリポイント（Phase 3 完了）

| 項目 | 内容 |
|------|------|
| 実行方法 | `node out/cli.js list` / `node out/cli.js export <id>` / `node out/cli.js export --all` |
| 引数パース | `util.parseArgs()`（Node.js 標準、外部依存ゼロ。ADR-005） |
| 出力 | stdout（list）/ ファイル（export）。`--json` でJSON出力対応 |
| コア共有 | `core/threads.ts` を VS Code 拡張と共有。`ExportConfig` 共通型 |
| オプション | `--no-thinking`, `--output-dir`, `--format`, `--since`, `--app-name`, `--json`, `--all` |
| 備考 | macOS のみ対応。CLI 使用時は `npm rebuild better-sqlite3` が必要（Electron 向けビルドと非互換） |

### FR-5: エクスポートカスタマイズ（Phase 3 完了）

| 項目 | 内容 |
|------|------|
| thinking の出力制御 | `<details>` 折りたたみ（デフォルト ON）/ `--no-thinking` で除外 |
| tool_call の出力制御 | `includeToolCalls` オプション（ツール名のみ出力） |
| 出力先の指定 | `cursorThreadTools.export.outputDir`（拡張）/ `--output-dir`（CLI） |
| ファイル名フォーマット | `{name}_{date}` テンプレート。`resolveFileName()` で解決 |
| 設定方法 | VS Code `contributes.configuration`（拡張）/ CLI 引数。`ExportConfig` 共通型で一致保証 |

---

## 明示的にスコープ外

| 機能 | 理由 | 代替手段 |
|------|------|---------|
| `threadTools.done`（完了報告 + Issue 投稿） | git/gh CLI 連携はコアと独立した関心（ADR-004） | Cursor コマンド or 独立 CLI として別途実装 |
| クラウド同期 | ローカル完結の方針 | git push で代替 |
| チャット UI 改造 | Cursor の非公開 API に依存しない | - |
| リアルタイム会話キャプチャ | DB の定期読み取りで十分 | 自動保存（FR-3）で代替 |

---

## 将来検討（スコープ外だが記録）

| 機能 | 概要 |
|------|------|
| `threadTools.start` | スレッド開始時の Issue 紐付け・プラン宣言 |
| `threadTools.progress` | 途中経過報告 |
| `threadTools.done` | 完了報告（別ツールとして、本拡張の export 結果を入力に使用） |
| MCP サーバー化 | エージェントが自分のスレッド履歴を自己参照 |
| マーケットプレイス公開 | `.vsix` ビルド → 公開 |

---

## 非機能要件

### NFR-1: 対応環境

| 項目 | 現状 | 目標 |
|------|------|------|
| OS | macOS のみ | macOS / Windows / Linux（Phase 4 以降） |
| エディタ | Cursor（Electron 39） | Cursor + VS Code |
| Node.js | v25.6.1（Cursor 内蔵） | Cursor/VS Code 内蔵バージョンに追従 |

### NFR-2: DB アクセス

| 項目 | 仕様 |
|------|------|
| アクセス方式 | read-only（`state.vscdb` を書き換えない） |
| ロック対策 | `readonly: true` + `busy_timeout = 3000` + WAL 3ファイルコピーフォールバック |
| 暗号化対応 | 現環境で非適用を確認。暗号化有効時はスコープ縮小（明示エラー） |

### NFR-3: 性能

| 項目 | 実測値 | 目標 |
|------|--------|------|
| turn デコード速度 | 25,000 turns/sec（75 turns / 3ms） | 5秒以内で任意サイズのスレッドをエクスポート |
| Markdown 生成含め | 4ms（75 turns） | - |

### NFR-4: 外部依存

| 項目 | 仕様 |
|------|------|
| ランタイム依存 | `better-sqlite3@12.6.2` のみ |
| protobuf パーサー | 外部依存ゼロ（自前 198 行） |
| ビルド依存 | `@electron/rebuild`（Cursor の Electron バージョン向けリビルド） |

### NFR-5: Cursor アップデート耐性

| 項目 | 仕様 |
|------|------|
| 方針 | 薄く作って壊れたら直す |
| スキーマ変更検知 | protobuf デコード失敗時に安全にスキップ（unknown field） |
| Electron バージョン変更 | `@electron/rebuild` で再ビルド。better-sqlite3 のメジャーバージョン対応が必要な場合あり |

### NFR-6: 配布（Phase 4 完了）

| 項目 | 現状 | 備考 |
|------|------|------|
| Extension 配布 | `.vsix` ビルド済み（8.08 MB）。Cursor で「Install from VSIX」でインストール可能 | macOS 向け `.node` バイナリを含む。他 OS ユーザーはソースからビルド必要 |
| CLI 配布 | `npm link` + `bin` フィールドで `cursor-thread-tools` コマンド登録 | CLI 使用時は `npm rebuild better-sqlite3` が必要（Electron 向けビルドと非互換） |
| バンドリング | esbuild でデュアルエントリ（extension.js 22kb / cli.js 19kb）。better-sqlite3 は external | ADR-008 |
| ネイティブモジュール | `scripts/install.sh` で npm install + esbuild + @electron/rebuild を一括実行 | ADR-009。Electron バージョンは環境変数 > 引数 > デフォルト 39.4.0 |
| リポジトリ | ai-development-hub 内。分離条件（安定動作 + 汎用 README + ドメイン固有情報なし）は達成済み | 独立リポジトリへの移行は判断待ち |

---

## 既知の制約・技術的負債

| 項目 | 詳細 | 状態 |
|------|------|------|
| 新フォーマットスレッド | `conversationState: "~"` のスレッドはテキスト抽出不可 | ADR-007 で「現状スキップ」を決定。安全にワーニング表示 |
| `readVarint` 32bit 制限 | JavaScript bitwise OR は 32bit。大きな varint でオーバーフローの可能性 | 実用範囲では問題なし |
| ~~macOS 専用パス~~ | ~~`getStateDbPath()` が `~/Library/...` にハードコード~~ | **Phase 4 で解決**。`platform()` switch 文に変更済み |
| ~~`@electron/rebuild` 手動実行~~ | ~~`npm install` 後に手動リビルド必要~~ | **Phase 4 で解決**。`scripts/install.sh` + `scripts/setup-cli.sh` で自動化 |
| Extension/CLI ビルドターゲット衝突 | Electron 向けと Node.js 向けで同一 `node_modules` を共有不可 | ADR-010 で記録。`install.sh`（Extension）/ `setup-cli.sh`（CLI）で切り替え |
| `.vsix` がプラットフォーム固有 | macOS 向け `.node` バイナリを含む。Windows/Linux ユーザーはソースからビルド必要 | ADR-009 で記録。platform-specific VSIX は将来検討 |
| Electron バージョン検出 | Cursor の Electron バージョンを外部から自動検出する信頼できる方法がない。`Info.plist` による手動確認が必要 | デフォルト 39.4.0 + 環境変数でオーバーライド可能 |

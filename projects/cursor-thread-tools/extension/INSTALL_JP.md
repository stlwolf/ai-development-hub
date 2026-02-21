# Cursor Thread Tools

Cursor の Composer スレッド会話を Markdown にエクスポートするツール。VS Code/Cursor 拡張機能と CLI の両方で利用可能。

## 機能

- **スレッド一覧**: 全 Composer スレッドをメタデータ付き（名前、メッセージ数、Agent/Chat モード、作成日時）で表示
- **Markdown エクスポート**: ユーザー発言 + アシスタント応答 + thinking ブロックを Markdown ファイルに出力
- **自動保存**: 更新されたスレッドを定期的にバックグラウンド保存（オプトイン）
- **CLI**: エディタを開かずにターミナルからスレッド一覧・エクスポートを実行

## インストール

### VS Code / Cursor 拡張機能（.vsix）

1. `.vsix` ファイルを [releases](https://github.com/stlwolf/ai-development-hub/releases) からダウンロード、またはソースからビルド（[ソースからビルド](#ソースからビルド)参照）
2. Cursor で `Cmd+Shift+P` → `Extensions: Install from VSIX...` → `.vsix` ファイルを選択
3. ウィンドウをリロード

### CLI

```bash
cd extension/
npm install
npm run build
npm link
cursor-thread-tools list
```

> **注意**: CLI は Node.js ネイティブビルドの better-sqlite3 が必要です。`install.sh`（Electron 向けビルド）を実行した後に CLI を使う場合は、先に Node.js 向けにリビルドしてください:
> ```bash
> npm rebuild better-sqlite3
> ```
>
> または一括セットアップスクリプト:
> ```bash
> bash scripts/setup-cli.sh
> ```

## コマンド

| コマンド | パレットでの表示 | 説明 |
|---------|---------------|------|
| `threadTools.list` | Thread Tools: List Threads | 全スレッドを QuickPick で表示 |
| `threadTools.export` | Thread Tools: Export Thread to Markdown | 選択したスレッドを Markdown エクスポート |

## CLI の使い方

```bash
# スレッド一覧
cursor-thread-tools list
cursor-thread-tools list --json

# 特定スレッドをエクスポート（composerId を指定）
cursor-thread-tools export <composerId>

# 全スレッドをエクスポート
cursor-thread-tools export --all

# 直近24時間のスレッドだけエクスポート
cursor-thread-tools export --all --since 24h

# オプション組み合わせ
cursor-thread-tools export --all --no-thinking --output-dir ./exports --format "{name}_{date}"
```

### CLI オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `--json` | list の結果を JSON で出力 | false |
| `--all` | 全スレッド対象 | false |
| `--no-thinking` | thinking ブロックを除外 | false |
| `--output-dir <path>` | 出力ディレクトリ | `.thread-exports` |
| `--format <pattern>` | ファイル名フォーマット（`{name}`, `{date}`, `{id}`） | `{name}_{date}` |
| `--since <duration>` | 期間フィルタ（`24h`, `7d`, `30m`） | なし |
| `--app-name <name>` | アプリ名: `Cursor` or `Code` | `Cursor` |

## 設定

| 設定項目 | 型 | デフォルト | 説明 |
|---------|-----|-----------|------|
| `cursorThreadTools.export.includeThinking` | boolean | `true` | thinking ブロックを Markdown に含める |
| `cursorThreadTools.export.outputDir` | string | `.thread-exports` | 出力ディレクトリ（ワークスペースルートからの相対パス） |
| `cursorThreadTools.export.fileNameFormat` | string | `{name}_{date}` | ファイル名フォーマット |
| `cursorThreadTools.autoSave.intervalMinutes` | number | `0` | 自動保存の間隔（分）。`0` = 無効 |

## プラットフォーム対応

| プラットフォーム | 拡張機能 | CLI |
|---------------|---------|-----|
| macOS | 対応済み | 対応済み |
| Windows | パス対応済み（未テスト） | パス対応済み（未テスト） |
| Linux | パス対応済み（未テスト） | パス対応済み（未テスト） |

## 要件

- **Node.js**: 20 以上（CLI は `util.parseArgs()` を使用、ターゲットは ES2020）
- **Cursor**: 0.40+（Electron 39）

## 制約

- **Cursor 専用**: Cursor のデータディレクトリから `state.vscdb` を読み取る。VS Code でも動作する可能性があるが未テスト
- **読み取り専用**: Cursor のデータを一切変更しない
- **ネイティブモジュール**: `better-sqlite3` はプラットフォーム固有のバイナリが必要。`.vsix` には macOS 用バイナリを同梱。他プラットフォームはソースからビルドが必要

## ソースからビルド

```bash
cd extension/

# フルインストール（拡張機能 + Electron リビルド）
bash scripts/install.sh

# または個別に:
npm install
npm run build

# 拡張機能開発用（Electron 向けリビルド）
npx @electron/rebuild -v 39.4.0 -m .

# CLI 用（Node.js 向けリビルド）
npm rebuild better-sqlite3

# .vsix パッケージ生成
npm run package
```

## トラブルシューティング

### `MODULE_NOT_FOUND` / `NODE_MODULE_VERSION` 不一致

better-sqlite3 を正しいランタイム向けにビルドする必要があります:

```bash
# Cursor 拡張機能用（Electron）
npx @electron/rebuild -v 39.4.0 -m .

# CLI 用（Node.js）
npm rebuild better-sqlite3
```

> 拡張機能と CLI を同一ディレクトリで併用する場合、ビルドターゲットの切り替えが必要です。

### `state.vscdb not found`

Cursor がインストールされていて、一度は起動されていることを確認してください。DB の場所:

- macOS: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Windows: `%APPDATA%\Cursor\User\globalStorage\state.vscdb`
- Linux: `~/.config/Cursor/User/globalStorage/state.vscdb`

### DB busy/locked

read-only モードで 3 秒の busy timeout を設定して DB を開きます。Cursor が書き込み中の場合は、WAL ファイルを含む DB ファイル一式を一時コピーしてフォールバックします。通常はリトライ不要です。

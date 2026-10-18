[English version available](INSTALL.en.md)

# Cursor Thread Tools

Cursor の Composer スレッド会話を Markdown にエクスポートするツール。
Cursor 内のコマンドパレットから使う**拡張機能**と、ターミナルから使う **CLI** の 2 つの利用方法があります。

## 機能

- **スレッド一覧**: 全 Composer スレッドをメタデータ付き（名前、メッセージ数、Agent/Chat モード、作成日時）で表示
- **Markdown エクスポート**: ユーザー発言 + アシスタント応答 + thinking ブロックを Markdown ファイルに出力
- **エクスポート先変更**: コマンドパレットからフォルダピッカーで出力先ディレクトリを変更
- **Composer 自動追加**: エクスポート後、ファイルを Composer に `@` 参照として自動追加
- **自動保存**: 更新されたスレッドを定期的にバックグラウンド保存（オプトイン）
- **CLI**: エディタを開かずにターミナルからスレッド一覧・エクスポートを実行

## 前提条件

- **macOS**（Windows / Linux はパス対応済みだが未テスト）
- **Node.js 20 以上**
- **Cursor 0.40+**（Electron 39）
- Cursor が一度は起動済みであること（`state.vscdb` が生成されている必要がある）

> **安全性**: このツールは Cursor のデータを**読み取り専用**でアクセスします。データを変更・削除することはありません。

---

## リリースからインストール（推奨）

ビルド環境不要。`.vsix` をダウンロードして Cursor にインストールするだけです。

### 1. .vsix をダウンロード

[GitHub Releases](https://github.com/stlwolf/ai-development-hub/releases?q=cursor-thread-tools) から、自分の環境に合った `.vsix` ファイルをダウンロードします。

- macOS (Apple Silicon): `cursor-thread-tools-X.Y.Z-darwin-arm64.vsix`
- macOS (Intel): `cursor-thread-tools-X.Y.Z-darwin-x64.vsix`

`gh` CLI がある場合:

```bash
gh release download cursor-thread-tools-v0.2.0 \
  --repo stlwolf/ai-development-hub --pattern '*.vsix'
```

### 2. Cursor にインストール

1. Cursor で `Cmd+Shift+P` → `Extensions: Install from VSIX...`
2. ダウンロードした `.vsix` ファイルを選択
3. ウィンドウをリロード（`Cmd+Shift+P` → `Developer: Reload Window`）

> ネイティブモジュール（better-sqlite3）を含むため、ビルド元と同じ OS / アーキテクチャでのみ動作します。
> 該当するファイルがない場合は、以下の「ソースからビルド」手順でビルドしてください。

---

## ソースからビルド: 拡張機能として使う

Cursor のコマンドパレット（`Cmd+Shift+P`）からスレッドの一覧表示やエクスポートができます。

### 1. ビルド

```bash
cd projects/cursor-thread-tools/extension
bash scripts/install.sh
```

`install.sh` は以下を自動実行します:
- `npm install`（依存関係インストール）
- `npm run build`（esbuild でバンドル）
- `@electron/rebuild`（better-sqlite3 を Cursor の Electron 向けにリビルド）

### 2. .vsix パッケージ生成

```bash
npm run package
```

`extension/` 直下に `cursor-thread-tools-0.2.0.vsix` が生成されます。

### 3. Cursor にインストール

1. Cursor で `Cmd+Shift+P` → `Extensions: Install from VSIX...`
2. 生成された `.vsix` ファイルを選択
3. ウィンドウをリロード（`Cmd+Shift+P` → `Developer: Reload Window`）

### 4. 使ってみる

- `Cmd+Shift+P` → `Thread Tools: List Threads` — スレッド一覧を表示
- `Cmd+Shift+P` → `Thread Tools: Export Thread to Markdown` — 選択したスレッドをエクスポート
- `Cmd+Shift+P` → `Thread Tools: Set Output Directory` — エクスポート先ディレクトリを変更

エクスポート先はデフォルトでワークスペースルートの `.thread-exports/` です。`Set Output Directory` コマンドでフォルダピッカーから変更でき、ワークスペース設定に保存されます。

エクスポート後、ファイルは自動的に Composer に `@` 参照として追加されます。Composer が開いていない場合はサイレントにスキップされます。

---

## クイックスタート: CLI として使う

ターミナルからスレッドの一覧表示やエクスポートができます。cron や git ワークフローとの組み合わせに便利です。

### 1. セットアップ

```bash
cd projects/cursor-thread-tools/extension
npm install
bash scripts/setup-cli.sh
```

`setup-cli.sh` は以下を自動実行します:
- `npm rebuild better-sqlite3`（Node.js ネイティブ向けにリビルド）
- `npm run build`（esbuild でバンドル）
- `npm link`（`cursor-thread-tools` コマンドをグローバル登録）

### 2. 使ってみる

```bash
# スレッド一覧
cursor-thread-tools list

# 全スレッドをエクスポート
cursor-thread-tools export --all

# 直近24時間のスレッドだけエクスポート
cursor-thread-tools export --all --since 24h
```

詳しい使い方は [CLI_USAGE.md](CLI_USAGE.md) を参照してください。

---

## 拡張機能と CLI を両方使う場合

拡張機能と CLI は `better-sqlite3` のビルドターゲットが異なります（Electron vs Node.js）。同一ディレクトリで両方を使う場合はターゲットの切り替えが必要です。

```bash
# 拡張機能を使うとき → Electron 向けにリビルド
bash scripts/install.sh

# CLI を使うとき → Node.js 向けにリビルド
bash scripts/setup-cli.sh
```

> 日常的に CLI を使い、拡張機能は `.vsix` インストール済みなら、CLI 側のビルド状態のままで問題ありません。`.vsix` は独自のバイナリを同梱しているため、ローカルのビルド状態に影響されません。

---

## 設定（拡張機能）

Cursor の `settings.json` で変更できます。

| 設定項目 | 型 | デフォルト | 説明 |
|---------|-----|-----------|------|
| `cursorThreadTools.export.includeThinking` | boolean | `true` | thinking ブロックを Markdown に含める |
| `cursorThreadTools.export.outputDir` | string | `.thread-exports` | 出力ディレクトリ（ワークスペースルートからの相対パス） |
| `cursorThreadTools.export.fileNameFormat` | string | `{name}_{date}` | ファイル名フォーマット |
| `cursorThreadTools.autoSave.intervalMinutes` | number | `0` | 自動保存の間隔（分）。`0` = 無効 |

---

## トラブルシューティング

### `MODULE_NOT_FOUND` / `NODE_MODULE_VERSION` 不一致

better-sqlite3 のビルドターゲットが合っていません。用途に応じてリビルドしてください:

```bash
# 拡張機能用（Electron 向け）
bash scripts/install.sh

# CLI 用（Node.js 向け）
bash scripts/setup-cli.sh
```

### `state.vscdb not found`

Cursor がインストールされていて、一度は起動されていることを確認してください。DB の場所:

- macOS: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Windows: `%APPDATA%\Cursor\User\globalStorage\state.vscdb`
- Linux: `~/.config/Cursor/User/globalStorage/state.vscdb`

### DB busy/locked

read-only モードで 3 秒の busy timeout を設定して DB を開きます。Cursor が書き込み中の場合は、WAL ファイルを含む DB ファイル一式を一時コピーしてフォールバックします。通常はリトライ不要です。

### Electron バージョンの不一致

Cursor のアップデートで Electron バージョンが変わった場合、`install.sh` に環境変数でバージョンを指定できます:

```bash
ELECTRON_VERSION=39.4.0 bash scripts/install.sh
```

現在の Cursor の Electron バージョンは Cursor の `About` 画面、または macOS の場合 `/Applications/Cursor.app/Contents/Info.plist` で確認できます。

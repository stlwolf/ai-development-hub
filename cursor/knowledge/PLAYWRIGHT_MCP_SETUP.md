# Playwright MCP セットアップガイド（Cursor）

> CursorでPlaywright MCPを設定し、ブラウザ自動操作を行うための手順と既知の問題・回避策

## 概要

[Playwright MCP](https://github.com/anthropics/playwright-mcp)はLLMがブラウザを操作するためのMCPサーバー。Cursorと連携することで、Webサイトの構造を理解した上での操作・情報抽出が可能になる。

---

## セットアップ手順

### 前提条件

- Node.js / npm がインストール済み
- Cursor エディタ

### 1. MCP設定ファイルを編集

`~/.cursor/mcp.json` に以下を追加:

```json
{
  "mcpServers": {
    "playwright-mcp": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest"
      ]
    }
  }
}
```

### 2. Cursorをリロード

- `Cmd + Shift + P` → 「Reload Window」
- Cursor Settings > MCP で `playwright-mcp` の横のドットが**緑色**になれば設定成功

### 3. MCP Allowlist に登録（必須）

> **この手順を省略するとPlaywright MCPが動作しない**（後述の既知の問題を参照）

Cursor Settings > MCP Allowlist に以下を追加:

```
playwright-mcp:*
```

#### Allowlist フォーマット

| パターン | 意味 |
|---------|------|
| `server:*` | 特定サーバーの全ツールを許可 |
| `*:tool` | 全サーバーの特定ツールを許可 |
| `*:*` | 全サーバーの全ツールを許可 |

---

## 既知の問題と検証結果

### Cursor の承認モードとPlaywright MCPの互換性

2025-02時点のCursor（v2.5.17）で検証。

| Tool Approval設定 | Playwright MCP | 症状 |
|-------------------|----------------|------|
| **Run Everything** | 動作する | - |
| **Sandbox (default)** | **動作しない** | `Navigating...` が点滅し続けブラウザが起動しない |
| **Ask Every Time** | **動作しない** | 同上。承認ダイアログ（Run tool）が表示されない |
| **Sandbox + Allowlist** | **動作する** | `playwright-mcp:*` を登録で解決 |

### 根本原因

Cursorの承認UI（Sandbox / Ask Every Time）がPlaywright MCPのツール呼び出し時に**承認ダイアログを表示できない**バグ。ツール呼び出しが承認待ちのまま永久にペンディングになり、ブラウザが起動しない。

### 回避策

**MCP Allowlistに `playwright-mcp:*` を登録する**。これにより:

- Playwright MCPの全ツールは承認ダイアログなしで自動実行される
- 他のツール/コマンドは引き続きSandbox/Ask設定に従う
- 「Run Everything」にする必要がない（セキュリティを維持できる）

---

## トラブルシューティング

### ブラウザが起動しない

1. **MCP Allowlist を確認** — `playwright-mcp:*` が登録されているか
2. **MCPのドットが緑か確認** — 赤/灰色ならサーバーが起動していない
3. **残存プロセスを確認** — 古いPlaywrightプロセスが残っていると競合する場合がある

```bash
ps aux | grep playwright | grep -v grep
# 残っていれば kill
pkill -f "playwright-mcp"
```

4. **MCP Chromeプロファイルをクリーンアップ**

```bash
rm -rf ~/Library/Caches/ms-playwright/mcp-chrome*
```

5. **Cursorをリロード**して再試行

### `mcp.json` の設定エラー

`cursor-ide-browser`（Cursorビルトイン）を `mcp.json` で `disabled: true` にすると設定全体がエラーになる。ビルトインMCPは `mcp.json` ではオーバーライドできない。

```json
// NG: 設定エラーになる
{
  "mcpServers": {
    "cursor-ide-browser": { "disabled": true }
  }
}
```

### npx キャッシュの問題

npxがキャッシュした古いバージョンが原因の場合:

```bash
# npxキャッシュを確認
ls ~/.npm/_npx/

# キャッシュをクリアして再インストール
rm -rf ~/.npm/_npx/*/node_modules/@playwright/mcp
```

---

## 検証環境

- macOS Sequoia 15.x（Apple Silicon）
- Cursor v2.5.17
- Node.js v18.17.1（asdf管理）
- @playwright/mcp v0.0.68
- Google Chrome v145.0.7632.76

## 参考

- [CursorでPlaywright MCPを使う方法 - Qiita](https://qiita.com/NightOwl/items/f11fb2404a1858d8871a)
- [Playwright MCP GitHub](https://github.com/microsoft/playwright-mcp)

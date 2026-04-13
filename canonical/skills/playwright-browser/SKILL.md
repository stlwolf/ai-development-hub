---
name: playwright-browser
description: Playwright MCPでブラウザ操作・DOM調査・UI検証を行う。ブラウザ操作、E2Eテスト、画面確認、UI検証、DOM調査、ネットワーク確認時に使用する。built-inブラウザではなくPlaywright MCPツールを優先する。
---

# Playwright MCP ブラウザ操作

## スキルメタデータ

- このスキルファイルの配置先: `~/.cursor/skills/playwright-browser/`
- 同ディレクトリ構成:
  - `SKILL.md`（本ファイル）
  - `scripts/intercept-api.js`（APIインターセプトスクリプト）
- 付随ファイルを参照する場合は上記パスを基準に解決すること

## Why Playwright MCP

Cursorにはbuilt-inブラウザ（cursor-ide-browser）とPlaywright MCP（user-playwright-mcp）の2系統がある。
Playwright MCPの優位点:
- DOM snapshotで安定した要素ref（操作対象の一意識別）
- `browser_console_messages` でJSエラー・警告をキャプチャ
- `browser_network_requests` でAPI呼び出し・失敗リクエストを確認

**常にPlaywright MCPを使うこと。built-inブラウザ（cursor-ide-browser）は使わない。**

## 呼び出し方法

全ツールは `CallMcpTool` で呼び出す:

```
server: "user-playwright-mcp"
toolName: "browser_*"
arguments: { ... }
```

注: `mcp.json` のキー名は `playwright-mcp` だが、Cursorが `user-` プレフィックスを付与するため、CallMcpToolでは `user-playwright-mcp` を指定する。

## 基本フロー

すべてのブラウザ操作はこの4ステップで進める:

1. **Navigate** - `browser_navigate` でURLに移動
2. **Snapshot** - `browser_snapshot` でDOM構造と要素refを取得
3. **Interact** - ref を使って `browser_click`, `browser_type` 等で操作
4. **Assert** - snapshot / screenshot / console / network で結果を確認

snapshot が返す `ref` は操作のたびに変わる。**操作前に必ず最新のsnapshotを取ること。**

## ツールリファレンス

### ナビゲーション

| ツール | 用途 | 主要パラメータ |
|--------|------|---------------|
| `browser_navigate` | URLに移動 | `url` |
| `browser_navigate_back` | 前のページに戻る | - |
| `browser_tabs` | タブ一覧/作成/選択/閉じる | `action`, `index` |

### 状態取得

| ツール | 用途 | 主要パラメータ |
|--------|------|---------------|
| `browser_snapshot` | DOMのアクセシビリティツリー取得 | `filename` (optional) |
| `browser_take_screenshot` | スクリーンショット取得 | `type`, `filename`, `fullPage`, `ref`+`element`(要素単位) |
| `browser_console_messages` | コンソールログ取得 | `level`, `filename` |
| `browser_network_requests` | ネットワークリクエスト一覧 | `includeStatic`, `filename` |

### 操作

| ツール | 用途 | 主要パラメータ |
|--------|------|---------------|
| `browser_click` | 要素クリック | `ref`, `element`, `button`(left/right/middle), `doubleClick` |
| `browser_type` | テキスト入力（追記） | `ref`, `text`, `submit`, `slowly`(keyハンドラ発火用) |
| `browser_fill_form` | 複数フィールド一括入力 | `fields` (下記参照) |
| `browser_select_option` | ドロップダウン選択 | `ref`, `values` |
| `browser_hover` | ホバー | `ref`, `element` |
| `browser_press_key` | キー押下 | `key` |
| `browser_drag` | ドラッグ&ドロップ | `startElement`(必須), `startRef`(必須), `endElement`(必須), `endRef`(必須) |
| `browser_file_upload` | ファイルアップロード | `paths` |

`browser_fill_form` の `fields` 型（全フィールド必須）:

```json
[{ "name": "説明", "type": "textbox|checkbox|radio|combobox|slider", "ref": "refN", "value": "値" }]
```

### 待機

| ツール | 用途 | 主要パラメータ |
|--------|------|---------------|
| `browser_wait_for` | テキスト出現/消失/時間待機 | `text`, `textGone`, `time` |

### 高度な操作

| ツール | 用途 | 主要パラメータ |
|--------|------|---------------|
| `browser_evaluate` | JavaScript実行 | `function`, `ref` |
| `browser_run_code` | Playwrightコード実行 | `code`（`page` オブジェクトが利用可能。例: `await page.evaluate(...)`, `await page.route(...)`, `await page.request.get(url, {headers})`) |
| `browser_handle_dialog` | ダイアログ処理 | `accept`, `promptText` |

### ブラウザ管理

| ツール | 用途 | 主要パラメータ |
|--------|------|---------------|
| `browser_resize` | ウィンドウサイズ変更 | `width`, `height` |
| `browser_close` | ページを閉じる | - |
| `browser_install` | ブラウザインストール | - |

## よくあるパターン

### ページ遷移の確認

```
1. browser_navigate → 対象URL
2. browser_snapshot → ページ構造を確認
3. browser_take_screenshot → 視覚的に確認
```

### フォーム入力

```
1. browser_snapshot → フォーム要素のrefを取得
2. browser_fill_form → fields: [{ name: "ユーザー名", type: "textbox", ref: "refN", value: "..." }, ...]
   または browser_click + browser_type で個別入力
3. browser_click → 送信ボタン
4. browser_wait_for → 遷移/結果表示を待機
5. browser_snapshot → 結果を確認
```

### エラー調査

```
1. browser_console_messages → JSエラーや警告を確認
2. browser_network_requests → 失敗リクエスト（4xx/5xx）を特定
3. browser_evaluate → DOM状態を直接調査
```

レスポンスボディの詳細が必要なら「APIレスポンスボディの取得」パターンを参照。

### APIレスポンスボディの取得

`browser_network_requests` はURL/ステータスのみ。レスポンスボディが必要な場合は、fetch/XHRをインターセプトする。APIを直接fetchするのではなく、ブラウザが通常行うリクエストをキャプチャする方式。認証の問題を回避できる。

1. [scripts/intercept-api.js](scripts/intercept-api.js) の内容を読み取る
   （パス解決できない場合: `~/.cursor/skills/playwright-browser/scripts/intercept-api.js`）
2. `browser_evaluate` の `function` に読み取った内容を渡して実行（**操作やページ遷移の前に設置すること**）
3. SPA内でページ遷移（クリック等）を行う — この間のAPIリクエストが自動キャプチャされる
4. `browser_evaluate` で `return window.__captured` を実行し結果を取得

```
window.__captured → [{ url, status, body }, ...]
```

スクリプトのデフォルトURLパターン（`/api/`, `/v{N}/`, `/graphql/`）に合わない場合は、対象サイトのAPIパスに合わせてスクリプトの `isApiRequest()` を調整する。

注意: `browser_evaluate` で設置したインターセプターはフルページ遷移でクリアされる。SPA内のクライアントサイドルーティングでは維持されるが、ページリロードや別URLへの直接遷移では再設置が必要。

### リクエストヘッダーの調査（Playwright Route傍受）

SPAが実際にどのヘッダーを送信しているか調べる場合、`browser_run_code` でPlaywrightネイティブのルート傍受を使う。`browser_evaluate` のJSインターセプターと異なり、ページ遷移でクリアされない。

```javascript
// browser_run_code の code パラメータに渡す
const captured = [];
await page.route('**/api/**', async (route) => {
  const request = route.request();
  captured.push({
    url: request.url(),
    headers: request.headers()
  });
  await route.continue();
});
// この後SPA内で操作すると、APIリクエストのヘッダーがcapturedに記録される
```

結果の取得は `browser_evaluate` で `return window.__playwrightCaptured` 等に格納するか、`browser_run_code` の戻り値として返す。

### レスポンシブ確認

```
1. browser_resize → width: 375, height: 812 (モバイル)
2. browser_snapshot + browser_take_screenshot
3. browser_resize → width: 1920, height: 1080 (デスクトップ)
4. browser_snapshot + browser_take_screenshot
```

## 注意事項

- **`browser_evaluate` 内の `fetch()` はhttpOnly Cookieに依存する認証では失敗する。** same-originでhttpOnly でないCookie（JWTトークン等）なら動作するが、確実性を求める場合は「APIレスポンスボディの取得」パターンのインターセプト方式を優先する
- 複数のエージェント（メイン・サブエージェント）は**同じPlaywright MCPプロセスを共有**する。ログイン状態・Cookie・表示ページは引き継がれる
- `browser_type` はテキストを追記する。クリア&入力したい場合は `browser_fill_form` を使う
- `browser_handle_dialog` はダイアログが表示される**前**に呼ぶ（先行登録方式）
- 操作のたびにrefが無効化されるため、連続操作の間に `browser_snapshot` を挟む
- Playwright MCPが起動できない場合（ブラウザ競合等）、`cursor-ide-browser` にフォールバックせず、エラーを報告して制御を返すこと
- `browser_take_screenshot` で `filename` を指定する場合は `.playwright-mcp/` プレフィックスを付けること（例: `.playwright-mcp/login-result.png`）。ワークスペースルートにファイルが散らばるのを防ぐ
- ステージング環境固有のフロー（認証等）はプロジェクト固有スキルで管理する

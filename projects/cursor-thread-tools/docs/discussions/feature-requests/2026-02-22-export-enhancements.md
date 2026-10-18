---
title: "エクスポート体験の拡張: 出力先選択 + ポストアクション"
date: 2026-02-22
type: discussion
status: confirmed
related:
  - type: depends_on
    ref: ../../REQUIREMENTS.md
    reason: "FR-2, FR-5 のエクスポート機能への拡張"
tags: [export, ux, clipboard, feature-request, composer-api]
use_when:
  - "次のフェーズで何を実装するか検討するとき"
  - "エクスポート体験の改善を議論するとき"
---

# エクスポート体験の拡張: 出力先選択 + ポストアクション

## 背景

Phase 1-4 でエクスポートの基本機能（FR-2）とカスタマイズ（FR-5）は完成した。現在のエクスポートフローは:

1. パレットから `Thread Tools: Export Thread to Markdown` 実行
2. QuickPick でスレッド選択
3. 設定の `outputDir`（デフォルト `.thread-exports`）に自動保存
4. エクスポートしたファイルをエディタで自動オープン

実用上の不満点:
- 出力先を変えるには `settings.json` を開いて編集する必要がある
- エクスポート後、Cursor チャットで `@` 参照したいがパスの手入力が面倒

---

## 確定: 提案1 — 出力先変更コマンド

### 方針

パレットに `Thread Tools: Set Output Directory` コマンドを追加。OS のフォルダピッカー（`showOpenDialog`）で出力先を選択し、`settings.json` に書き込む。

### 実装案

```typescript
const result = await vscode.window.showOpenDialog({
  canSelectFolders: true,
  canSelectFiles: false,
  canSelectMany: false,
  openLabel: 'Select Output Directory',
});
if (result && result[0]) {
  const relativePath = vscode.workspace.asRelativePath(result[0]);
  await vscode.workspace.getConfiguration('cursorThreadTools')
    .update('export.outputDir', relativePath, vscode.ConfigurationTarget.Workspace);
}
```

### 補足

- macOS のフォルダ選択ダイアログには「New Folder」ボタンがあるため、存在しないフォルダの新規作成 → 選択が可能
- VS Code の `contributes.configuration` は設定項目にフォルダピッカーウィジェットを付けることができないため、独立コマンドとして提供
- Settings UI の `outputDir` 欄の description に「`Thread Tools: Set Output Directory` コマンドでフォルダ選択も可能」と記載
- 将来的に設定項目が増えたら Webview ベースの設定画面を検討

---

## 確定: 提案2 — エクスポート後に Composer へファイル参照を自動追加

### 調査結果（2026-02-23）

Cursor 内部コマンドの調査（`vscode.commands.getCommands(true)` で 2908 コマンドを取得・フィルタ）により、以下を発見:

| コマンド | 機能 |
|---------|------|
| `composer.addfilestocomposer` | ファイルを現在の Composer に `@` 参照として追加 |
| `composer.addfilestonnewcomposer` | ファイルを新規 Composer に追加 |
| `composer.exportChatAsMd` | Cursor 組み込みの Markdown エクスポート（内部コマンド） |

**検証結果**: `composer.addfilestocomposer` に `vscode.Uri.file(path)` を渡すと、ファイルペインの右クリック「Add File to Cursor Chat」と同等の動作でチャットにファイル参照が追加された。

**前提条件**: 対象ファイルがエディタペインで開いている状態であること。エディタに開いていないファイルの Uri を渡しても追加されない。

### 方針

エクスポート後のデフォルト動作を拡張:

```
現行: ファイル保存 → エディタで開く → 完了通知
拡張: ファイル保存 → エディタで開く → Composer にファイル参照追加 → 完了通知
```

エクスポート直後は何らかの処理（チャットで参照する等）をしたい場面が多いため、デフォルトで Composer に追加する。使い勝手が合わなければ、後から設定で挙動を変えられるようにする。

### 実装案

```typescript
// 既存のエクスポートフロー末尾に追加
const doc = await vscode.workspace.openTextDocument(filePath);
await vscode.window.showTextDocument(doc, { preview: false });

// Composer にファイル参照を追加
try {
  await vscode.commands.executeCommand(
    'composer.addfilestocomposer',
    vscode.Uri.file(filePath),
  );
} catch {
  // 非公開 API のため、失敗しても致命的ではない。サイレントに無視
}
```

### リスク

- `composer.addfilestocomposer` は Cursor の**非公開内部 API**。Cursor アップデートでコマンド名や引数形式が変わる可能性がある
- 失敗時はサイレントに無視し、エクスポート自体は正常に完了する設計にする
- NFR-5（Cursor アップデート耐性）の「薄く作って壊れたら直す」方針に合致

---

## 実装スコープまとめ

| 機能 | コマンド | 工数感 |
|------|---------|-------|
| 出力先変更 | `threadTools.setOutputDir` — フォルダピッカーで outputDir を変更 | 小 |
| Composer 自動追加 | エクスポート後に `composer.addfilestocomposer` を呼ぶ | 小 |

### スコープ外（将来）

- ポストアクション QuickPick（開く / コピー / パスコピー の選択肢）→ デフォルト挙動で不便が出たら
- Webview 設定画面 → 設定項目が増えたら
- CLI 側への反映（`--copy` オプション等）

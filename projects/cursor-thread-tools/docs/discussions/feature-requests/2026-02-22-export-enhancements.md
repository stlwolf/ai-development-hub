---
title: "エクスポート体験の拡張: 出力先選択 + ポストアクション"
date: 2026-02-22
type: discussion
related:
  - type: depends_on
    ref: ../../REQUIREMENTS.md
    reason: "FR-2, FR-5 のエクスポート機能への拡張"
tags: [export, ux, clipboard, feature-request]
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
- エクスポート結果を別の場所にペーストしたいとき、ファイルを開いて全選択コピーが必要

## 提案1: エクスポート時の出力先インタラクティブ選択

### パターン

| パターン | 実装イメージ | 工数感 |
|---------|------------|-------|
| A. エクスポート時にフォルダピッカー | export 実行後に `showOpenDialog({ canSelectFolders: true })` で出力先選択 | 小 |
| B. 専用コマンド `threadTools.setOutputDir` | パレットからフォルダピッカーで設定変更。`workspaceConfiguration.update()` で永続化 | 小 |
| C. QuickPick で最近の出力先から選択 | エクスポート時に「前回の出力先 / デフォルト / カスタム...」の QuickPick | 中（`workspaceState` に履歴保存） |

### 推奨

パターン A が最もシンプル。ただし毎回ダイアログが出るのは煩わしいため、「設定の outputDir をデフォルト採用 + QuickPick の末尾に "別のフォルダに保存..." 選択肢を追加」が現実的。

## 提案2: エクスポート後のポストアクション

エクスポート完了後に「次のアクション」を QuickPick で提示する。

```
エクスポート完了 → QuickPick「次のアクション」
  - エディタで開く（現行動作）
  - Markdown をクリップボードにコピー
  - ファイルパスをコピー（@ 参照用）
```

### 各アクションの技術的実現性

| アクション | API | 備考 |
|-----------|-----|------|
| エディタで開く | `vscode.window.showTextDocument()` | 現行実装済み |
| Markdown クリップボードコピー | `vscode.env.clipboard.writeText(markdown)` | 全文コピー。ペースト先で即利用可能 |
| ファイルパスコピー（`@` 参照用） | `vscode.env.clipboard.writeText(relativePath)` | ワークスペース相対パス。Cursor チャットで `@` + ペーストで参照可能 |

### Cursor チャットへの直接挿入について

VS Code Extension API には Cursor 固有のチャット入力にテキストを挿入する公開 API がない。クリップボード経由でのユーザー手動ペーストが現実的な代替手段。

## 実装優先度案

| 優先度 | 機能 | 理由 |
|-------|------|------|
| 高 | ポストアクション QuickPick（開く / MD コピー / パスコピー） | 1コマンドの体験が大幅に改善。実装も小さい |
| 中 | エクスポート時の出力先選択（QuickPick 末尾に "別のフォルダ..." 追加） | 設定画面を開かずに変えられる UX 改善 |
| 低 | 最近の出力先履歴 | `workspaceState` に履歴保存が必要でやや複雑 |

## 未検討事項

- ポストアクション QuickPick を毎回出すか、設定で「デフォルトアクション」を選べるようにするか
- 自動保存（FR-3）時にもポストアクションを適用するか（通知なしで動く設計との兼ね合い）
- CLI 側への反映（`--copy` オプション等）

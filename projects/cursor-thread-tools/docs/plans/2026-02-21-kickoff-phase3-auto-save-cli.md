---
title: "Phase 3 キックオフ: 自動保存 + CLI + エクスポートカスタマイズ"
date: 2026-02-21
type: plan
participants:
  - Eddy
  - Cursor Agent (Primary)
related:
  - type: derived_from
    ref: ../episodes/2026-02-21-phase2-markdown-export.md
    reason: "Phase 2 エピソードの引き継ぎ"
  - type: derived_from
    ref: ../decisions/ADR-004-scope-refocus.md
    reason: "スコープ変更（thread-done → 自動保存+CLI+カスタマイズ）"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約（命名規則・ADR昇格基準・gate運用・plan/episode分離）"
  - type: depends_on
    ref: ../REQUIREMENTS.md
    reason: "機能要件 FR-3, FR-4, FR-5 に対応"
  - type: supersedes
    ref: 2026-02-21-kickoff-phase3-thread-done.md
    reason: "スコープ変更により差し替え"
tags: [phase3, auto-save, cli, export-customization, vscode-extension]
keywords: [FileSystemWatcher, setInterval, cli.ts, MarkdownOptions, settings.json]
use_when:
  - "Phase 3 子スレッドを開始するとき（このファイルが最初のプロンプト）"
  - "自動保存・CLI・カスタマイズの設計判断を確認したいとき"
---

# Phase 3 キックオフ: 自動保存 + CLI + エクスポートカスタマイズ

**作業開始前に必ず以下を読むこと:**
- **`CONVENTIONS.md`**（プロジェクトルート）: ファイル命名規則、ADR 昇格基準、plan/episode 分離ルール、gate 運用
- **`docs/REQUIREMENTS.md`**: 機能要件（FR-3, FR-4, FR-5）、非機能要件

## 1. 目的

Phase 2 で完成した Markdown エクスポート機能を、3つの方向に拡張する:

1. **自動保存**: バックグラウンドで定期的にスレッドを Markdown 保存（SpecStory の代替・補完）
2. **CLI エントリポイント**: VS Code 非依存でターミナルから実行可能にする
3. **エクスポートカスタマイズ**: thinking/tool_call の出力制御、出力先・ファイル名の設定

### Phase 3 の成功基準

- [ ] 自動保存が設定可能なインターバルでバックグラウンド動作する
- [ ] `node cli.js list` / `node cli.js export <id>` がターミナルから実行できる
- [ ] export オプション（thinking 含む/含まない、出力先パス）が VS Code settings と CLI 引数で設定できる
- [ ] 差分検知（前回エクスポート以降の更新スレッドのみ対象）が動作する

---

## 2. Phase 2 からの引き継ぎ

### 解決済み

- `threadTools.list` + `threadTools.export` が F5 実機テストで動作確認済み
- raw protobuf パーサー（外部依存ゼロ）で会話テキスト抽出成功
- better-sqlite3@12.6.2 + Electron 39 で動作確認済み

### Phase 2 の残課題（Phase 3 で対応）

- 新フォーマットスレッド（`conversationState: "~"`）— 調査・対応を Step 0 に含める
- SpecStory 出力との完全突合 — Step 4 で実施

### コードの VS Code 依存度（CLI 化の前提情報）

```
VS Code 依存あり（UI 層）:
  extension.ts      → vscode.commands.registerCommand
  commands/list.ts  → vscode.window.showQuickPick
  commands/export.ts → vscode.window.showQuickPick, vscode.ProgressLocation

VS Code 依存なし（コア層）:
  db/reader.ts       → better-sqlite3 のみ（vscode.env.appName の1箇所を除く）
  proto/decoder.ts   → 完全に Node.js 標準
  export/markdown.ts → 完全にピュア関数
```

`db/reader.ts` の `getStateDbPath()` にある `vscode.env.appName` をパラメータ化すれば、コア層は CLI でそのまま動作する。

---

## 3. 実施計画

### Step 0: 前提調査

- 新フォーマットスレッド（`conversationState: "~"`）のデータ構造を調査
  - workspaceStorage 内の state.vscdb に格納されている可能性
  - 別の agentKv キーパターンの可能性
- VS Code Extension API の `workspace.onDidChangeConfiguration` / `setInterval` のベストプラクティス確認
- CLI パッケージング方法の調査（standalone バイナリ vs Node.js スクリプト）

### Step 1: コア層の VS Code 非依存化

`db/reader.ts` の `getStateDbPath()` をリファクタリング:

```typescript
// before: VS Code 依存
const appName = vscode.env.appName?.includes('Cursor') ? 'Cursor' : 'Code';

// after: パラメータ化
export function getStateDbPath(options?: { appName?: string }): string {
  const appName = options?.appName ?? detectAppName();
}
function detectAppName(): string {
  // VS Code 拡張環境なら vscode.env.appName を使う
  // CLI 環境なら 'Cursor' をデフォルトに（macOS の場合）
}
```

### Step 2: CLI エントリポイント作成

```
extension/src/
  cli.ts   # CLI エントリポイント（新規）
```

```bash
node out/cli.js list                          # スレッド一覧
node out/cli.js export <composerId>           # 指定スレッドをエクスポート
node out/cli.js export --all                  # 全スレッドをエクスポート
node out/cli.js export --all --no-thinking    # thinking を除外
```

### Step 3: エクスポートカスタマイズ

VS Code settings:

```json
{
  "cursorThreadTools.export.includeThinking": true,
  "cursorThreadTools.export.outputDir": ".thread-exports",
  "cursorThreadTools.export.fileNameFormat": "{name}_{date}"
}
```

CLI 引数:

```bash
--include-thinking / --no-thinking
--output-dir <path>
--format <name_date|id_date|custom>
```

### Step 4: 自動保存

VS Code 拡張の `activate()` 内で:

```typescript
// 設定可能なインターバル（デフォルト: 無効 or 30分）
const interval = vscode.workspace.getConfiguration('cursorThreadTools').get<number>('autoSave.intervalMinutes', 0);
if (interval > 0) {
  setInterval(() => autoSaveNewThreads(), interval * 60 * 1000);
}
```

差分検知:

- 最終エクスポート時刻を `context.globalState` に保存
- `composerData.createdAt` / 更新日時と比較して新しいスレッドのみ対象

### Step 5: 検証

- CLI テスト: `node out/cli.js list` / `export` の E2E テスト
- 自動保存: 30分インターバルで放置テスト
- SpecStory 出力との突合（テキスト内容の差分確認）
- 新フォーマットスレッドへの対応（Step 0 の調査結果に依存）

---

## 4. 検証マトリクス対応

| 検証項目 | ID | 本 Phase での検証内容 |
|---------|----|--------------------|
| 自動保存のバックグラウンド動作 | A-3-1 (新) | Step 4 |
| CLI からのスレッド一覧・エクスポート | A-3-2 (新) | Step 2 |
| エクスポートオプションの設定 | A-3-3 (新) | Step 3 |
| 新フォーマットスレッド対応 | A-3-4 (新) | Step 0 + Step 5 |

---

## 5. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| 新フォーマットスレッドのデータ構造が解明不能 | 一部スレッドがエクスポート不可のまま | 対応可能なスレッドのみ対象。エラーメッセージで明示 |
| 自動保存がパフォーマンスに影響 | Cursor の操作が重くなる | 非同期実行 + インターバルを十分に長く（デフォルト 30分） |
| CLI と拡張でコードが分岐 | メンテコスト増 | コア層を完全共有。UI 層のみ分岐 |

---

## 6. peer-ai-review 実施ポイント

**以下は実装プラン作成時に TODO 項目として独立登録すること。**
**gate をスキップする場合はエピソードにスキップ理由を明記すること。**

1. **Step 0 完了時**: 新フォーマットスレッドの調査結果確認
2. **Step 4 完了時**: 自動保存 + CLI + カスタマイズの全体コードレビュー

---

## 7. ADR 作成チェックリスト

- [ ] CLI パッケージング方法（standalone バイナリ vs Node.js スクリプト）
- [ ] 自動保存のデフォルトインターバル（無効 vs 30分 vs 他）
- [ ] 新フォーマットスレッドへの対応方針（対応 vs スコープ外）

---

## 8. 完了条件

Phase 3 完了時に統合ハブスレッドに持ち帰るもの:

- [ ] 自動保存 + CLI + カスタマイズが動作する拡張コード
- [ ] CLI エントリポイント
- [ ] VERIFICATION_MATRIX の A-3 更新
- [ ] 該当する ADR の作成
- [ ] Phase 4（パッケージング・配布）キックオフに必要な情報の整理

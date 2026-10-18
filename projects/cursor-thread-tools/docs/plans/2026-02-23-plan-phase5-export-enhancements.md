---
title: "Phase 5 実装プラン: エクスポート体験の拡張"
date: 2026-02-23
type: plan
related:
  - type: implements
    ref: 2026-02-23-kickoff-phase5-export-enhancements.md
    reason: "Phase 5 キックオフの実装プラン"
  - type: derived_from
    ref: ../discussions/feature-requests/2026-02-22-export-enhancements.md
    reason: "確定仕様の実装"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約"
tags: [phase5, plan, export, composer-api, folder-picker]
keywords: [showOpenDialog, composer.addfilestocomposer, setOutputDir, ConfigurationTarget]
use_when:
  - "Phase 5 の実装プランを確認するとき"
---

# Phase 5 実装プラン: エクスポート体験の拡張

## 概要

2つの UX 改善を実装する:
1. **出力先変更コマンド** (`threadTools.setOutputDir`)
2. **エクスポート後 Composer 自動追加** (`composer.addfilestocomposer`)

概算合計: **約1時間10分**

---

## Step 0: 前提調査（概算: 15分）

### 0-1. Composer API の存在・動作確認

Extension Development Host（F5 デバッグ）で以下を確認:

```typescript
// テスト用: extension.ts の activate に一時追加
const cmds = await vscode.commands.getCommands(true);
const composerCmds = cmds.filter(c => c.includes('composer'));
console.log('[thread-tools] composer commands:', composerCmds);
```

確認項目:
- [ ] `composer.addfilestocomposer` がコマンドリストに存在する
- [ ] `composer.addfilestonnewcomposer` がコマンドリストに存在する（参考情報）

### 0-2. `composer.addfilestocomposer` の動作テスト

```typescript
// テスト用: 既存の export フロー内で一時的に追加
const testUri = vscode.Uri.file('/path/to/existing/opened/file');
try {
  await vscode.commands.executeCommand('composer.addfilestocomposer', testUri);
  console.log('[thread-tools] composer.addfilestocomposer: success');
} catch (e) {
  console.error('[thread-tools] composer.addfilestocomposer: failed', e);
}
```

確認項目:
- [ ] エディタで開いているファイルの Uri を渡して Composer に追加される
- [ ] 引数の型が `vscode.Uri` で正しい（配列ではなく単一 Uri）

### 0-3. `showOpenDialog` の動作確認

確認項目:
- [ ] `canSelectFolders: true` + `canSelectFiles: false` でフォルダのみ選択可能
- [ ] `vscode.workspace.asRelativePath()` がワークスペース内パスを相対パスに変換する
- [ ] ワークスペース外パスの場合は絶対パスがそのまま返る

### Step 0 の gate

前提調査で以下が確認できなければ、プランを修正する:
- `composer.addfilestocomposer` が存在しない → Step 2 をスコープ外に変更
- `composer.addfilestocomposer` の引数形式が discussion と異なる → Step 2 の実装を調整

---

## Step 1: 出力先変更コマンド（概算: 20分）

### 1-1. `extension/src/commands/setOutputDir.ts` を新規作成

```typescript
import * as vscode from 'vscode';
import { join, isAbsolute } from 'path';
import { existsSync } from 'fs';

export async function setOutputDir(): Promise<void> {
  // peer-ai-review: ワークスペース未オープン時は ConfigurationTarget.Workspace が reject する
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (!workspaceFolders || workspaceFolders.length === 0) {
    vscode.window.showWarningMessage('Thread Tools: Open a workspace first to set output directory.');
    return;
  }

  const config = vscode.workspace.getConfiguration('cursorThreadTools');
  const currentDir = config.get<string>('export.outputDir', '.thread-exports');

  // peer-ai-review: defaultUri は存在確認してから渡す（非存在時の挙動は OS 依存）
  const candidatePath = join(workspaceFolders[0].uri.fsPath, currentDir);
  const defaultUri = existsSync(candidatePath)
    ? vscode.Uri.file(candidatePath)
    : workspaceFolders[0].uri;

  const result = await vscode.window.showOpenDialog({
    canSelectFolders: true,
    canSelectFiles: false,
    canSelectMany: false,
    openLabel: 'Select Output Directory',
    defaultUri,
  });

  if (!result || result.length === 0) return;

  const selected = result[0];
  let relativePath = vscode.workspace.asRelativePath(selected, false);

  // peer-ai-review: asRelativePath はワークスペース外パスを絶対パスでそのまま返す
  // join(workspaceRoot, absolutePath) が誤パスになるため、警告して中断
  if (isAbsolute(relativePath)) {
    vscode.window.showWarningMessage(
      'Thread Tools: Selected folder is outside the workspace. Please select a folder within the workspace.',
    );
    return;
  }

  await config.update('export.outputDir', relativePath, vscode.ConfigurationTarget.Workspace);
  vscode.window.showInformationMessage(`Thread Tools: Output directory set to "${relativePath}"`);
}
```

### 1-2. `extension/package.json` の更新

**commands に追加:**

```json
{
  "command": "threadTools.setOutputDir",
  "title": "Thread Tools: Set Output Directory"
}
```

**activationEvents に追加:**

```json
"onCommand:threadTools.setOutputDir"
```

**outputDir の description を更新:**

```json
"description": "Output directory for exported files (relative to workspace root). Use 'Thread Tools: Set Output Directory' command for folder picker."
```

### 1-3. `extension/src/extension.ts` にコマンド登録

```typescript
import { setOutputDir } from './commands/setOutputDir';

// activate() 内の subscriptions.push に追加
vscode.commands.registerCommand('threadTools.setOutputDir', () => setOutputDir()),
```

---

## Step 2: Composer 自動追加（概算: 20分）

### 2-1. `extension/src/commands/export.ts` のエクスポート後処理に追加

既存コード（109-110行目）:

```typescript
const doc = await vscode.workspace.openTextDocument(filePath);
await vscode.window.showTextDocument(doc, { preview: false });
```

この後に追加:

```typescript
try {
  await vscode.commands.executeCommand(
    'composer.addfilestocomposer',
    vscode.Uri.file(filePath),
  );
} catch {
  // Cursor 非公開 API — 失敗してもエクスポート自体は正常完了
}
```

### 2-2. 自動保存には追加しない

`extension.ts` の `autoSaveNewThreads()` には Composer 追加を追加しない。理由:
- バックグラウンドで Composer に追加すると、作業中のチャットに意図しないファイル参照が入る
- 自動保存はサイレントに動作すべき

### 2-3. CLI には適用不可

CLI（`cli.ts`）は VS Code API 非依存のため、`composer.addfilestocomposer` は使用不可。変更なし。

### TODO: ADR 判断ポイント

Step 0 の結果、`composer.addfilestocomposer` の引数形式が想定と異なる、または代替手段を選択した場合は ADR を作成する。

---

## Gate: Step 2 完了時の動作確認（概算: gate 含め Step 3 に統合）

Step 2 完了時点で F5 デバッグで以下を確認:
- [ ] エクスポート後に Composer にファイル参照が追加される
- [ ] Composer が開いていない状態でもエラーにならない（サイレント失敗）

gate をスキップする場合はエピソードに理由を明記すること。

---

## Step 3: ビルド + 検証（概算: 15分）

### 3-1. ビルド

```bash
cd projects/cursor-thread-tools/extension
npm run build
```

### 3-2. F5 デバッグでの E2E テスト

| テスト項目 | 手順 | 期待結果 |
|-----------|------|---------|
| Set Output Directory | コマンドパレット → `Thread Tools: Set Output Directory` → フォルダ選択 | `.vscode/settings.json` に `cursorThreadTools.export.outputDir` が書き込まれる |
| 変更した出力先でエクスポート | Set Output Directory 後に Export Thread | 選択したフォルダにファイルが出力される |
| ワークスペース外フォルダ選択 | Set Output Directory でワークスペース外のフォルダを選択 | 警告メッセージが表示され、設定は変更されない |
| ワークスペース未オープン時 | ワークスペースなしで Set Output Directory | 「Open a workspace first」警告が表示される |
| Composer 自動追加 | Export Thread 実行 | エクスポート後に Composer にファイル参照が追加される |
| Composer 未使用時の動作 | Composer を閉じた状態で Export Thread | エクスポートは正常完了（Composer 追加は失敗してもよい） |
| 既存機能の回帰 | Export Thread（設定変更なし） | 従来通り `.thread-exports/` に出力される |

### 3-3. CLI の回帰確認

```bash
cursor-thread-tools list
cursor-thread-tools export --all --since 24h --output-dir /tmp/test-export
```

---

## Step 4: ドキュメント + 成果物記録 + フィードバック（概算: 20分）

### 4-1. エピソード作成

`docs/episodes/2026-02-23-phase5-export-enhancements.md` を作成。実装結果のサマリを記録する。

### 4-2. VERIFICATION_MATRIX 更新

A-5 セクションを追加:

| ID | 検証項目 | 状態 | 結果 | 根拠 |
|----|---------|------|------|------|
| A-5-1 | `Set Output Directory` コマンドで outputDir 変更 | | | |
| A-5-2 | エクスポート後の Composer 自動追加 | | | |
| A-5-3 | Composer API 失敗時のサイレントフォールバック | | | |

### 4-3. ADR 作成（該当する場合のみ）

Step 0 または Step 2 で判断ポイントが発生した場合に作成。

### 4-4. キックオフ突合

キックオフの成功基準・完了条件と実装結果を突合し、未達成項目を明示する。エピソードに突合結果を記載する。

**← 4-1〜4-4 をまとめて実行し、ユーザーに報告する。** ユーザー確認で追加作業（バグ修正、設定調整等）が発生しうる。

### 4-5. ポストコンプリーション追記

ユーザーとのやりとりで追加発生した作業があれば、エピソードに時系列で追記する。追加作業がなければスキップ。

### 4-6. スレッド作業フィードバック

エピソードの末尾に以下の構造化フィードバックを記述する。

> 以下の各項目について自由文で記述する。
> 該当なしの項目は「特になし」と記載してスキップ可。
> ただし「成果物一覧」「想定外の点」「プラン実行時に調整した点」は原則記述必須。

- **成果物一覧（必須）**: 作成・変更したファイル・機能・ドキュメントのリスト
- **実行フロー概略**: 1-2行の時系列サマリ（プラン → 実装 → 検証 等の流れ）
- **想定外の点（必須）**: ポジティブ（想定より簡単だった等）/ ネガティブ（前提が崩れた等）
- **ボトルネック**: 最も時間がかかった Step とその理由。見積もりとの乖離
- **プラン実行時に調整した点（必須）**: プランからの変更とその判断理由
- **コンテキスト復元性能**: 前スレッドの記録だけでスムーズに開始できたか
- **規約・ルールの遵守状況と摩擦**: 無視された / 形骸化したルール、強制化すべき点
- **ナレッジ昇格**: ADR 化すべき決定事項、CONVENTIONS.md への追加案
- **再利用可能な知見**: 他プロジェクト / 他スレッドにも転用可能なパターン
- **プラン構築プロセスの改善案**: プランニング手法・gate 設計・見積もり等のメタレベル改善

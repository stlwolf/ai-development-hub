---
title: "Phase 3 実装プラン: 自動保存 + CLI + エクスポートカスタマイズ"
date: 2026-02-21
type: plan
participants:
  - Eddy
  - Cursor Agent (Primary)
related:
  - type: derived_from
    ref: 2026-02-21-kickoff-phase3-auto-save-cli.md
    reason: "Phase 3 キックオフから具体化"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約"
  - type: depends_on
    ref: ../REQUIREMENTS.md
    reason: "FR-3, FR-4, FR-5"
  - type: derived_from
    ref: ../decisions/ADR-004-scope-refocus.md
    reason: "スコープ変更の決定"
tags: [phase3, auto-save, cli, export-customization, vscode-extension, implementation-plan]
keywords: [util.parseArgs, setInterval, onStartupFinished, bubbleCount, core/threads.ts]
use_when:
  - "Phase 3 の実装を開始するとき"
  - "Phase 3 の設計判断を確認したいとき"
---

# Phase 3 実装プラン: 自動保存 + CLI + エクスポートカスタマイズ

**peer-ai-review 3者合意済み（2026-02-21）**
SO 出力: `tmp/so-phase3-plan-review/`
レビューログ: `tmp/peer-review-20260221-181128/review-log.md`

**作業開始前に必ず以下を読むこと:**
- **`CONVENTIONS.md`**（プロジェクトルート）: ファイル命名規則、ADR 昇格基準、plan/episode 分離ルール、gate 運用
- **`docs/REQUIREMENTS.md`**: 機能要件（FR-3, FR-4, FR-5）、非機能要件

---

## 前提

- Phase 2 完了済み: `threadTools.list` / `threadTools.export` が F5 実機テスト動作確認済み
- コードベース: `extension/src/` 配下に 6 TS ファイル（extension.ts, commands/list.ts, commands/export.ts, db/reader.ts, proto/decoder.ts, export/markdown.ts）
- 外部依存: `better-sqlite3@12.6.2` のみ
- VS Code 依存箇所: `db/reader.ts` の `vscode.env.appName`（1箇所）+ commands/ + extension.ts の UI 層

---

## アーキテクチャ方針

コア層（DB アクセス + protobuf デコード + Markdown 生成）を VS Code 非依存にし、CLI と拡張で共有する。

```
UI Layer (vscode dependent)          CLI Layer (vscode independent)
  extension.ts                         cli.ts
  commands/list.ts                       |
  commands/export.ts                     |
  auto-save timer                        |
       |                                 |
       +----------+    +-----------+-----+
                  |    |
            Core Layer (vscode independent)
              core/threads.ts
              db/reader.ts
              proto/decoder.ts
              export/markdown.ts
```

---

## Step 0: 前提調査

### 0-a: 新フォーマットスレッド調査（スコープ絞り込み）

`conversationState: "~"` の `~` prefix 自体は `decoder.ts` で base64 対応済み。
調査対象は **「base64 デコード成功後にターンが 0 件になるスレッド」** に絞る:

- `state.vscdb` から該当スレッドを抽出し、base64 デコード後の protobuf 構造を確認
- ターン数 0 の原因: 空スレッド / 別フィールド番号 / 別スキーマ のいずれかを特定
- workspaceStorage 内の state.vscdb に別のデータパスがないか確認
- 結論: 対応可能 → Step 1 以降で対応 / 対応不能 → エラーメッセージで明示しスキップ

### 0-b: CLI パッケージング方法（ADR-005 候補）

**決定: Node.js スクリプトとして配布**

- `node out/cli.js list` / `node out/cli.js export <id>` で実行
- 引数パースは Node.js ビルトイン `util.parseArgs()`（外部依存追加なし、Node 18.3+ で stable）
- standalone バイナリ（pkg, nexe 等）は Phase 4 のパッケージング・配布で検討

根拠:
- ゼロ外部依存方針と整合（`util.parseArgs()` は Node.js 標準ライブラリ）
- better-sqlite3 はネイティブモジュールなので pkg 化が複雑
- 利用者は Node.js 環境がある前提（Cursor 開発者）
- `--no-thinking` 等の negation 処理も `util.parseArgs()` で自動対応

### 0-c: 自動保存デフォルトインターバル（ADR-006 候補）

**決定: デフォルト無効（0分）、オプトイン方式**

- ユーザーが明示的に有効化する
- 理由: DB への定期アクセスの影響、SpecStory との二重保存回避、センシティブな会話の自動保存防止
- `contributes.configuration` の description に「0 = 無効」を明記

---

## [Gate 0] peer-ai-review: Step 0 調査結果

**条件**: Step 0 の調査が完了し、3つの結論（新フォーマット対応方針 / CLI 方式確定 / 自動保存デフォルト確定）が出たとき
**対象**: 調査結果と ADR 候補の妥当性
**形式**: `so-compare.sh` を実行し、3者比較テーブルをレビューログに記録

---

## Step 1: コア層の VS Code 非依存化

### 1-a: `db/reader.ts` のリファクタリング

`extension/src/db/reader.ts` から `import * as vscode from 'vscode'` を除去し、`getStateDbPath()` をパラメータ化する。

```typescript
// before
import * as vscode from 'vscode';
function getStateDbPath(): string {
  const appName = vscode.env.appName?.includes('Cursor') ? 'Cursor' : 'Code';
  return join(home, 'Library', 'Application Support', appName, ...);
}

// after
export interface DbPathOptions {
  appName?: string; // 'Cursor' | 'Code' etc. default: 'Cursor'
}
export function getStateDbPath(options?: DbPathOptions): string {
  const appName = options?.appName ?? 'Cursor';
  return join(homedir(), 'Library', 'Application Support', appName, 'User', 'globalStorage', 'state.vscdb');
}
export function openDatabase(options?: DbPathOptions): Database.Database {
  const dbPath = getStateDbPath(options);
  // ... existing logic
}
```

### 1-b: 共有ロジックの抽出 — `core/threads.ts`（新規）

`extension/src/core/threads.ts` に UI 非依存のロジックを分離する。
命名は `exporter.ts` ではなく `threads.ts`（listing も含むため）。

**`core/threads.ts` に含めるもの**:

- `ComposerMeta` 型定義 — `export.ts` 側の定義を正とする（`headers`, `rawJson` フィールド含む）
- `parseComposerData(key, value)` — 現在 list.ts と export.ts で重複
- `listAllThreads(db)` — DB から全スレッドメタデータを取得（ソート済み）
- `extractThreadContent(db, meta)` — composerId から `ExportedTurn[]` を取得
- `collectAssistantText(steps)` — ステップからテキスト収集
- `formatDate(ms)` — 日時フォーマット

**commands/export.ts に残すもの**:

- QuickPick UI
- Progress notification
- ファイル保存 + エディタで開く（VS Code API）
- `vscode.workspace.getConfiguration()` による設定読み取り

### 1-c: commands/list.ts の共通化

`parseComposerData()` と `ComposerMeta` を `core/threads.ts` から import するように変更。

---

## Step 2: CLI エントリポイント + Step 3: エクスポートカスタマイズ（セット設計）

**peer-ai-review 指摘**: CLI 引数と VS Code settings が同じ設定値を扱うため、仕様のずれを防ぐにはセットで設計すべき。

### 2-a: `cli.ts`（新規）

`extension/src/cli.ts` を作成。`util.parseArgs()` を使用。

```typescript
import { parseArgs } from 'node:util';

const { values, positionals } = parseArgs({
  args: process.argv.slice(2),
  options: {
    all:           { type: 'boolean' },
    thinking:      { type: 'boolean', default: true },
    'output-dir':  { type: 'string' },
    format:        { type: 'string' },
    'app-name':    { type: 'string' },
    json:          { type: 'boolean' },
    since:         { type: 'string' },
  },
  allowPositionals: true,
});

const [subcommand, ...rest] = positionals;
```

#### サブコマンド

```bash
node out/cli.js list                          # スレッド一覧（stdout）
node out/cli.js list --json                   # JSON 形式
node out/cli.js export <composerId>           # 指定スレッドをエクスポート
node out/cli.js export --all                  # 全スレッドをエクスポート
node out/cli.js export --all --since 24h      # 過去24時間のスレッドのみ
```

#### 共通オプション

```bash
--app-name <name>        # 'Cursor' | 'Code' (default: 'Cursor')
--no-thinking            # thinking を除外
--output-dir <path>      # 出力先ディレクトリ (default: '.thread-exports')
--format <pattern>       # ファイル名フォーマット (default: '{name}_{date}')
--json                   # list の出力を JSON 形式に
```

#### CLI 固有の実装

- 出力は stdout（list）/ ファイル書き出し（export）
- エラーは stderr + 非ゼロ exit code
- macOS 以外では明示的エラーメッセージ（Phase 3 は macOS のみサポート）
- `export --all` では成功/失敗件数のサマリーを stderr に出力

#### CLI tmpDb クリーンアップ

```typescript
process.on('exit', cleanupTmpDb);
process.on('SIGINT', () => { cleanupTmpDb(); process.exit(130); });
```

### 3-a: `MarkdownOptions` の拡張

`extension/src/export/markdown.ts` の `MarkdownOptions` を拡張:

```typescript
export interface MarkdownOptions {
  includeThinking?: boolean;    // existing (default: true)
  includeToolCalls?: boolean;   // new (default: false)
  fileNameFormat?: string;      // new (default: '{name}_{date}')
}
```

`tool_call` は現状 `text: ''` で出力価値が低い。`includeToolCalls: true` 時はツール名のみ `> Tool: <name>` 形式で表示。

### 3-b: VS Code settings contribution

`extension/package.json` に `contributes.configuration` を追加:

```json
{
  "contributes": {
    "configuration": {
      "title": "Cursor Thread Tools",
      "properties": {
        "cursorThreadTools.export.includeThinking": {
          "type": "boolean",
          "default": true,
          "description": "Include thinking blocks in exported Markdown"
        },
        "cursorThreadTools.export.outputDir": {
          "type": "string",
          "default": ".thread-exports",
          "description": "Output directory for exported files (relative to workspace root)"
        },
        "cursorThreadTools.export.fileNameFormat": {
          "type": "string",
          "default": "{name}_{date}",
          "description": "File name format. Placeholders: {name}, {date}, {id}"
        },
        "cursorThreadTools.autoSave.intervalMinutes": {
          "type": "number",
          "default": 0,
          "description": "Auto-save interval in minutes. 0 = disabled (opt-in)"
        }
      }
    }
  }
}
```

### 3-c: 設定の共通インターフェース

CLI 引数と VS Code settings が同じ設定値を扱うため、共通の `ExportConfig` 型を定義:

```typescript
export interface ExportConfig {
  includeThinking: boolean;
  outputDir: string;
  fileNameFormat: string;
}
```

- `commands/export.ts`: `vscode.workspace.getConfiguration('cursorThreadTools')` から `ExportConfig` を構築
- `cli.ts`: `util.parseArgs()` の結果から `ExportConfig` を構築

---

## Step 4: 自動保存

### 4-a: `activationEvents` の追加

**[peer-ai-review Critical]** 現在の `activationEvents` は `onCommand` のみ。自動保存を動作させるには拡張が自動的にアクティベートされる必要がある。

`extension/package.json`:

```json
{
  "activationEvents": [
    "onCommand:threadTools.list",
    "onCommand:threadTools.export",
    "onStartupFinished"
  ]
}
```

`onStartupFinished` でアクティベートされるが、自動保存はオプトイン（デフォルト無効）なので、設定が 0 の場合はタイマーを起動しない。

### 4-b: タイマーセットアップ（handle 管理付き）

`extension/src/extension.ts`:

```typescript
let autoSaveHandle: ReturnType<typeof setInterval> | null = null;

function setupAutoSave(context: vscode.ExtensionContext): void {
  // 既存タイマーを破棄
  if (autoSaveHandle) {
    clearInterval(autoSaveHandle);
    autoSaveHandle = null;
  }

  const config = vscode.workspace.getConfiguration('cursorThreadTools');
  const interval = config.get<number>('autoSave.intervalMinutes', 0);
  if (interval <= 0) return;

  autoSaveHandle = setInterval(async () => {
    try {
      await autoSaveNewThreads(context);
    } catch (err) {
      console.error('[cursor-thread-tools] auto-save error:', err);
    }
  }, interval * 60 * 1000);

  // deactivate 時に自動クリア
  context.subscriptions.push({
    dispose: () => {
      if (autoSaveHandle) {
        clearInterval(autoSaveHandle);
        autoSaveHandle = null;
      }
    },
  });
}

export function activate(context: vscode.ExtensionContext): void {
  // existing command registration...

  setupAutoSave(context);

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration(e => {
      if (e.affectsConfiguration('cursorThreadTools.autoSave')) {
        setupAutoSave(context);
      }
    })
  );
}
```

### 4-c: 差分検知 — `bubbleCount` ベース

**[peer-ai-review Critical]** `createdAt` は作成時刻のみで更新を検知不可。`bubbleCount`（メッセージ数）の変化で差分を検知する。

```typescript
async function autoSaveNewThreads(context: vscode.ExtensionContext): Promise<void> {
  const prevCounts = context.globalState.get<Record<string, number>>('autoSaveBubbleCounts', {});
  // ... DB 読み取り、スレッド一覧取得
  const updated = threads.filter(t => (prevCounts[t.composerId] ?? 0) < t.bubbleCount);
  // ... updated のみエクスポート
  // 成功後に bubbleCount を更新
  const newCounts: Record<string, number> = { ...prevCounts };
  for (const t of updated) {
    newCounts[t.composerId] = t.bubbleCount;
  }
  await context.globalState.update('autoSaveBubbleCounts', newCounts);
}
```

### 4-d: 出力先

- VS Code settings の `cursorThreadTools.export.outputDir` を使用
- ワークスペースフォルダが開いている場合はその配下に保存
- 開いていない場合は OS temp ディレクトリ

---

## [Gate 1] peer-ai-review: 全体コードレビュー

**条件**: Step 4 完了後、自動保存 + CLI + カスタマイズの全コードが揃ったとき
**対象**: コード全体の設計・品質レビュー
**形式**: `so-compare.sh` に全変更ファイルをコンテキストとして渡し、3者比較を実施

---

## Step 5: 検証 + ドキュメント

### 検証

- CLI E2E: `node out/cli.js list` / `export <id>` / `export --all` が正常動作するか
- 自動保存: 短いインターバル（1分）で放置テスト、`bubbleCount` 差分検知の確認
- SpecStory 出力との突合: テキスト内容の差分確認（同一スレッドを比較）
- 新フォーマットスレッド: Step 0 の調査結果に基づく対応の検証

### ドキュメント

- VERIFICATION_MATRIX A-3 の更新（A-3-1〜A-3-4 を検証結果で埋める）
- Phase 3 エピソード作成: `docs/episodes/2026-02-21-phase3-auto-save-cli.md`
- ADR 作成（Step 0 の結果に応じて）

---

## ADR 作成チェックリスト

- [ ] ADR-005: CLI パッケージング方法（Node.js スクリプト + `util.parseArgs()`）
- [ ] ADR-006: 自動保存デフォルトインターバル（無効 / オプトイン）
- [ ] (条件付き) ADR-007: 新フォーマットスレッドへの対応方針

---

## 変更対象ファイル一覧

| ファイル | 操作 | 内容 |
|---------|------|------|
| `src/db/reader.ts` | 修正 | vscode 依存除去、`DbPathOptions` パラメータ化 |
| `src/core/threads.ts` | 新規 | 共有ロジック（parseComposerData, listAllThreads, extractThreadContent） |
| `src/cli.ts` | 新規 | CLI エントリポイント（`util.parseArgs()`） |
| `src/commands/export.ts` | 修正 | core/threads.ts 利用、ExportConfig 経由で設定読み取り |
| `src/commands/list.ts` | 修正 | core/threads.ts 利用 |
| `src/export/markdown.ts` | 修正 | MarkdownOptions 拡張（includeToolCalls, fileNameFormat） |
| `src/extension.ts` | 修正 | 自動保存タイマー追加（handle 管理 + dispose 登録） |
| `package.json` | 修正 | contributes.configuration + activationEvents に onStartupFinished 追加 |

---

## peer-ai-review で反映した修正点

| # | 修正 | 指摘者 | 重要度 |
|---|------|--------|--------|
| 1 | `activationEvents` に `onStartupFinished` 追加 | Codex | Critical |
| 2 | 差分検知を `bubbleCount` ベースに変更 | Claude / Codex | Critical |
| 3 | CLI を `util.parseArgs()` に変更 | Claude | Important |
| 4 | `setInterval` handle の dispose 登録 + config 変更時の clearInterval | Claude | Important |
| 5 | CLI の `process.on('exit'/'SIGINT')` で tmpDb クリーンアップ | Claude | Important |
| 6 | `core/exporter.ts` → `core/threads.ts` に命名変更 | Claude | Minor |
| 7 | Step 0 の `~` 調査スコープ絞り込み | Claude | Minor |
| 8 | Step 2/3 をセット設計（CLI 引数と VS Code settings の仕様一致） | Claude | Important |

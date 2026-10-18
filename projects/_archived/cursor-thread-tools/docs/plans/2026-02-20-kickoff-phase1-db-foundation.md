---
title: "Phase 1 キックオフ: DB読み取り基盤検証"
date: 2026-02-20
type: plan
participants:
  - Eddy
  - Cursor Agent (Claude 4.6 Opus, Primary)
related:
  - type: derived_from
    ref: 2026-02-20-kickoff-cursor-thread-tools.md
    reason: "プロジェクトキックオフの Phase 1 検証計画を具体化"
  - type: depends_on
    ref: ../VERIFICATION_MATRIX.md
    reason: "検証項目 A-1-1 〜 A-1-6 に対応"
  - type: evidence_for
    ref: ../../tmp/peer-review-20260220-201106/review-log.md
    reason: "peer-ai-review で3者合意済み（Codex + Claude + 自分）"
tags: [phase1, sqlite, state-vscdb, better-sqlite3, vscode-node-sqlite3, vscode-extension]
keywords: [cursorDiskKV, composerData, bubbleId, agentKv, blob, composer.content, WAL, busy_timeout]
use_when:
  - "Phase 1 子スレッドを開始するとき（このファイルが最初のプロンプト）"
  - "DB読み取り基盤の設計判断を確認したいとき"
---

# Phase 1 キックオフ: DB読み取り基盤検証

## 1. 目的

`state.vscdb`（SQLite）からCursorのスレッド会話データを読み取り、VS Code拡張内で `threadTools.list`（スレッド一覧表示）を動作させる。

### Phase 1 の成功基準

- [ ] VS Code拡張のコマンドパレットから `threadTools.list` を実行できる
- [ ] スレッド一覧（名前、メッセージ数、作成日時）が表示される
- [ ] `composerData` → `bubbleId` → アシスタント応答テキストのフルパスが判明している
- [ ] SQLiteライブラリが Cursor 内蔵 Electron で動作することを確認済み

---

## 2. 既知の技術知見（プロジェクトキックオフより引用）

### DB場所とテーブル構造

- **パス**: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- **テーブル**: `ItemTable`（レガシー）, `cursorDiskKV`（主要）
- **主要キープレフィックス**:

| プレフィックス | 件数 | 内容 |
|--------------|------|------|
| `composerData:` | 193 | スレッドメタデータ |
| `bubbleId:` | 14,461 | 個別メッセージメタデータ |
| `agentKv:blob:` | 26,671 | アシスタント応答コンテンツ本体 |
| `composer.content.*` | 667 | コンテンツハッシュ（**マッピング仲介者の可能性あり**） |

### データ取得フロー（逆アセンブルで確認済み）

1. `composerData:<id>` → `fullConversationHeadersOnly`（bubbleIdリスト）
2. 最初のbubbleIdから `getConversationFromBubble()` でフル会話ロード
3. 各メッセージの `type`（1=HUMAN, 2=ASSISTANT）+ `text` + `codeBlocks`
4. Markdown整形して出力

### 未解明の核心課題

**アシスタント応答テキストが `bubbleId` エントリ自体には格納されず、`agentKv:blob:<hash>` にcontent-addressed形式で分離されている。** このマッピング（bubbleId → hash → テキスト）の解明が Phase 1 の最重要課題。

**`composer.content.*`（667件）がbubbleId→blobのインデックスまたは仲介者である可能性が高い**（peer-ai-review で Claude が指摘、件数比 約40:1 はスレッド単位のインデックス構造を示唆）。

---

## 3. 実施計画

### Step 0: 逆アセンブル済みコードの精読（最優先）

`getConversationFromBubble()` の実装内で `agentKv` をどう参照しているかを確認する。**すでに逆アセンブルで確認済みと記録されているので、この知見がDB探索の一次情報として最優先。**

- `workbench.desktop.main.js` 内の該当関数を精読
- `agentKv:blob` へのアクセスパターン（キー生成ロジック）を特定
- `composer.content.*` が関与しているかを確認

### Step 1: SQLite CLI で DB構造を探索

Step 0 の知見を踏まえて、CLIで実データを確認する。

```sql
-- DB をread-onlyで開く
-- sqlite3 "file:$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb?mode=ro"

-- 0. 現在のjournal_modeを確認（WALモードか否か）
PRAGMA journal_mode;

-- 1. composerData のJSON構造を確認（1件サンプル）
SELECT key, substr(value, 1, 500) FROM cursorDiskKV
WHERE key LIKE 'composerData:%' LIMIT 1;

-- 2. bubbleId のJSON構造を確認
SELECT key, substr(value, 1, 500) FROM cursorDiskKV
WHERE key LIKE 'bubbleId:%' LIMIT 1;

-- 3. ★ composer.content.* の構造を確認（マッピング仲介者の可能性）
SELECT key, substr(value, 1, 500) FROM cursorDiskKV
WHERE key LIKE 'composer.content%' LIMIT 3;

-- 4. agentKv:blob のサンプル確認（型・サイズ含む）
SELECT key, typeof(value), length(value) FROM cursorDiskKV
WHERE key LIKE 'agentKv:blob:%' LIMIT 3;

-- 5. bubbleId エントリ内にhash参照があるか検索
SELECT key, value FROM cursorDiskKV
WHERE key LIKE 'bubbleId:%' AND value LIKE '%agentKv%' LIMIT 1;
SELECT key, value FROM cursorDiskKV
WHERE key LIKE 'bubbleId:%' AND value LIKE '%blob%' LIMIT 1;
SELECT key, value FROM cursorDiskKV
WHERE key LIKE 'bubbleId:%' AND value LIKE '%content%' LIMIT 1;

-- 6. globalStorage vs workspaceStorage の確認
-- workspaceStorage にも composerData があるか？
-- 別途 workspaceStorage ディレクトリ内の state.vscdb を確認
```

### Step 1b: diff実験（Step 0/1 で解明不十分な場合）

同一スレッドで1メッセージ追加前後のDB差分を取り、増えたキー集合からマッピングを特定する。

```bash
# 追加前のキー一覧を保存
sqlite3 "file:...state.vscdb?mode=ro" \
  "SELECT key FROM cursorDiskKV ORDER BY key" > /tmp/keys-before.txt

# Cursorでメッセージを1つ送信

# 追加後のキー一覧
sqlite3 "file:...state.vscdb?mode=ro" \
  "SELECT key FROM cursorDiskKV ORDER BY key" > /tmp/keys-after.txt

# 差分
diff keys-before.txt keys-after.txt
```

### Step 1c: exportChatAsMd 出力との突合

`composer.exportChatAsMd` の出力（ゴールデン）と、自前の抽出結果を突合し、同値性を検証する。

### Step 2: 最小VS Code拡張スキャフォールディング

Step 0〜1 の結果を踏まえて拡張の骨格を作成する。

```
extension/
├── package.json          # コマンド: threadTools.list
├── tsconfig.json
├── .vscodeignore
└── src/
    ├── extension.ts      # activate: コマンド登録
    ├── db/
    │   └── reader.ts     # state.vscdb 読み取り
    └── commands/
        └── list.ts       # threadTools.list 実装
```

### Step 3: SQLiteライブラリ選定・動作検証

#### 候補（優先順位付き）

| 優先度 | 候補 | 方式 | メリット | リスク |
|--------|------|------|---------|--------|
| 1 | `better-sqlite3` | ネイティブ (N-API) | 高速、同期API | Cursor Electron との ABI 互換性 |
| 2 | `vscode-node-sqlite3` | ネイティブ (Node-API v3/v6) | Microsoft公式fork、prebuilt提供 | VS Code/Cursor固有の制約 |
| 3 | (機能停止) | - | - | `better-sqlite3`/`vscode-node-sqlite3` いずれも不可時 |

**sql.js（WASM）は本番経路に置かない。** DB全体をメモリにロードする仕様のため、大規模な `state.vscdb` でクラッシュするリスクがある（peer-ai-review で3者合意）。

#### Cursor Electron バージョンの確認

```bash
# Cursorバイナリから確認
/Applications/Cursor.app/Contents/MacOS/Cursor --version

# 拡張のactivate内から確認
# console.log(process.versions.electron);
```

#### 既存拡張の参考

- `vscode-sqlite`（AlexCovizzi）: precompiled CLI バイナリ同梱方式。メンテ停止（2022〜）だが設計パターンは参考になる
- `vscode-node-sqlite3`（Microsoft）: Node-API prebuilt方式。2026年1月まで更新。プラットフォーム横断対応

### Step 4: DB同時アクセス戦略

**設計原則**: 「設定変更（WAL pragma）」ではなく「オープン戦略」で同時アクセスを解決する。

```typescript
// 正しいアプローチ
const db = new Database(dbPath, { readonly: true, fileMustExist: true });

// 現在のjournal_modeを読み取り（設定変更ではない）
const journalMode = db.pragma('journal_mode', { simple: true });
// → 'wal' ならread-only同時読み取り可能

// ロック競合時のリトライ
db.pragma('busy_timeout = 3000');
```

#### フォールバック: DB一時コピー

mode=ro でロック競合が解消しない場合、DBを一時コピーして読む（最も安定）。

```typescript
import { copyFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

function openWithCopyFallback(dbPath: string): Database {
  try {
    const db = new Database(dbPath, { readonly: true, fileMustExist: true });
    db.pragma('busy_timeout = 3000');
    db.prepare('SELECT 1 FROM cursorDiskKV LIMIT 1').get();
    return db;
  } catch {
    const tmpPath = join(tmpdir(), 'cursor-thread-tools-state.vscdb');
    copyFileSync(dbPath, tmpPath);
    return new Database(tmpPath, { readonly: true, fileMustExist: true });
  }
}
```

### Step 5: `threadTools.list` の動作確認

Step 0〜4 が完了したら、コマンドパレットから実行し、スレッド一覧が表示されることを確認する。

---

## 4. 検証マトリクス対応

| 検証項目 | ID | 本 Phase での検証内容 |
|---------|----|--------------------|
| SQLite ライブラリ read-only 読み取り | A-1-1 | Step 3 で検証 |
| Cursor起動中の同時アクセス | A-1-2 | Step 4 で検証（busy_timeout + コピーフォールバック） |
| `composerData` からメタデータ取得 | A-1-3 | Step 1 で探索、Step 5 で拡張内検証 |
| `bubbleId` からユーザー発言テキスト取得 | A-1-4 | Step 1 で探索、Step 5 で拡張内検証 |
| `agentKv:blob` からアシスタント応答取得 | A-1-5 | Step 0 + Step 1 で解明（最重要） |
| ~~sql.js フォールバック~~ | A-1-6 | **撤回**: sql.js は本番経路に置かない |

---

## 5. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| `agentKv:blob` マッピング解明不能 | アシスタント応答が取得できない | (1) 逆アセンブル精読 (2) composer.content.* 調査 (3) diff実験 (4) exportChatAsMd との突合 |
| `better-sqlite3` がCursor Electronで動かない | ネイティブモジュール不可 | `vscode-node-sqlite3` (Microsoft fork, Node-API prebuilt) に切り替え |
| DB ロック競合 | 読み取り失敗 | `mode=ro` + `busy_timeout=3000` → DB一時コピーフォールバック |
| Cursorアップデートでスキーマ変更 | 読み取りロジック破損 | 薄く作って壊れたら直す（3者合意済み） |
| `composer.exportChatAsMd` フォールバックが拡張から呼べない | 最終手段が使えない | `vscode.commands.executeCommand()` の挙動を事前確認。内部コマンドは呼べない可能性あり |

---

## 6. peer-ai-review 活用方針

Phase 1 の実装中、以下のタイミングで peer-ai-review を実行する:

- SQLiteライブラリ選定の最終判断時
- `agentKv:blob` マッピングのアプローチ確定時
- 拡張アーキテクチャ（ファイル構成・モジュール分割）の確定時

SOログ（`tmp/so-*/`）は層3の生ログとして保管し、抽出フロー（層3→層2）の実体験とする。

---

## 7. 完了条件

Phase 1 完了時に統合ハブスレッドに持ち帰るもの:

- [ ] `threadTools.list` が動作する最小拡張コード
- [ ] `agentKv:blob` マッピングの解明結果（episodes/ に記録）
- [ ] SQLiteライブラリの選定結果（decisions/ にADR）
- [ ] VERIFICATION_MATRIX の A-1-1〜A-1-5 更新（A-1-6 は撤回）
- [ ] Phase 2 キックオフに必要な情報の整理

---

## 8. スコープ制限（Phase 1 では扱わない）

- クロスプラットフォーム対応（macOS限定で進める。Windows/Linux対応はPhase 2以降）
- Markdownエクスポート（Phase 2）
- thread-done 統合（Phase 3）
- 配布・パッケージング（Phase 4）

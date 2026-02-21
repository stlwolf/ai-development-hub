---
title: "Phase 4 キックオフ: パッケージング・配布"
date: 2026-02-21
type: plan
participants:
  - Eddy
  - Cursor Agent (Primary)
related:
  - type: derived_from
    ref: ../episodes/2026-02-21-phase3-auto-save-cli.md
    reason: "Phase 3 エピソードの引き継ぎ"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約"
  - type: depends_on
    ref: ../REQUIREMENTS.md
    reason: "NFR-6（配布）に対応"
tags: [phase4, packaging, vsix, esbuild, cli, cross-platform, distribution]
keywords: [vsce, vsix, esbuild, electron-rebuild, postinstall, npm-link, bin]
use_when:
  - "Phase 4 子スレッドを開始するとき（このファイルが最初のプロンプト）"
  - "パッケージング・配布の設計判断を確認したいとき"
---

# Phase 4 キックオフ: パッケージング・配布

**作業開始前に必ず以下を読むこと:**
- **`CONVENTIONS.md`**（プロジェクトルート）: ファイル命名規則、ADR 昇格基準、ADR フロー組み込み、plan/episode 分離ルール、gate 運用、事実検証粒度、プラン構成ガイドライン、**フェーズ実行フロー**
- **`docs/REQUIREMENTS.md`**: NFR-6（配布）

## 実行フロー

CONVENTIONS.md の「フェーズ実行フロー」に従う:

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + `docs/REQUIREMENTS.md` + 既存コード
2. **プラン作成**: plan mode で具体的な実装プランを作成（Step 0 必須、概算時間、ADR TODO 独立配置、gate TODO 独立配置）
3. **peer-ai-review**: `/peer-ai-review` でプランの3者合意を取得
4. **CP 配置**: `docs/plans/YYYY-MM-DD-plan-phase4-packaging.md` に保存
5. **ユーザー確認**: CP 配置を報告し、ビルド実行指示を待つ
6. **実装**: プランに従って実装。gate は TODO 項目として実行
7. **成果物記録**: エピソード + ADR + VERIFICATION_MATRIX 更新

## 1. 目的

Phase 1〜3 で完成した機能を、**他の人がインストール・利用できる形にパッケージングする**。機能追加はなし。

### Phase 4 の成功基準

- [ ] `.vsix` ファイルを生成し、Cursor で「Install from VSIX」でインストールできる
- [ ] CLI が `npm link` or `bin` フィールドで手軽に実行できる
- [ ] `@electron/rebuild` が `postinstall` or スクリプトで自動化されている
- [ ] Windows / Linux のパス対応（`getStateDbPath()` の拡張）
- [ ] 他者向け README（インストール手順・使い方）が `extension/` 内に存在する
- [ ] ドメイン固有情報（プロダクト固有 等）が拡張コードに含まれていないことを確認

---

## 2. Phase 3 からの引き継ぎ

### 解決済み

- VS Code 拡張: `threadTools.list` / `threadTools.export` + 自動保存 + 設定（F5 実機テスト済み）
- CLI: `node out/cli.js list` / `export` が動作（E2E テスト済み）
- コア層 / UI 層分離済み（`core/threads.ts`）
- better-sqlite3@12.6.2 + Electron 39 で動作確認済み

### Phase 4 で対応が必要

- esbuild バンドリング（`tsc` のみ → 単一ファイル + better-sqlite3 external）
- `.vsix` ビルド（`vsce package`）
- `@electron/rebuild` の自動化
- CLI の `bin` フィールド対応
- クロスプラットフォームパス（macOS 以外）
- 他者向け README を `extension/` 内に別途作成（現在の `README.md` はプロジェクト開発記録用として残す）
- better-sqlite3 の Electron/Node デュアルビルド問題の解決 or ドキュメント化

### 既知の制約

- better-sqlite3 はネイティブモジュールのため、`.vsix` に含めても利用者側で `@electron/rebuild` が必要な可能性がある
- CLI 使用時は `npm rebuild better-sqlite3` が必要（Electron 向けビルドと非互換）

---

## 3. 実施計画

### Step 0: 前提調査（概算: 30分）

- `vsce package` が better-sqlite3（ネイティブモジュール）をどう扱うか調査
- 他の VS Code 拡張（vscode-sqlite 等）がネイティブモジュールの配布をどう解決しているか確認
- esbuild の `external` 指定で better-sqlite3 を除外した場合の `.vsix` 構成を確認
- Windows / Linux の Cursor データディレクトリパスを確認

### Step 1: esbuild バンドリング（概算: 1時間）

- `esbuild` を devDependencies に追加
- 拡張用ビルド: `src/extension.ts` → `out/extension.js`（better-sqlite3 は external）
- CLI 用ビルド: `src/cli.ts` → `out/cli.js`（better-sqlite3 は external）
- `package.json` の `scripts` に `build` / `watch` を追加
- `tsconfig.json` は型チェック用に残す（`tsc --noEmit`）

### Step 2: クロスプラットフォームパス（概算: 30分）

`db/reader.ts` の `getStateDbPath()` を拡張:

```typescript
function getStateDbPath(options?: DbPathOptions): string {
  const appName = options?.appName ?? 'Cursor';
  switch (platform()) {
    case 'darwin':
      return join(homedir(), 'Library', 'Application Support', appName, 'User', 'globalStorage', 'state.vscdb');
    case 'win32':
      return join(process.env.APPDATA ?? '', appName, 'User', 'globalStorage', 'state.vscdb');
    case 'linux':
      return join(homedir(), '.config', appName, 'User', 'globalStorage', 'state.vscdb');
    default:
      throw new Error(`Unsupported platform: ${platform()}`);
  }
}
```

### Step 3: `@electron/rebuild` 自動化 + CLI bin 対応（概算: 30分）

- `scripts/install.sh`: npm install → Electron バージョン検出 → `@electron/rebuild`
- `package.json` の `bin` フィールドで CLI をコマンド化:

```json
{
  "bin": {
    "cursor-thread-tools": "./out/cli.js"
  }
}
```

- `npm link` で `cursor-thread-tools list` / `cursor-thread-tools export` が使えるようにする

### Step 4: .vsix ビルド + 他者向け README（概算: 1時間）

- `vsce package` で `.vsix` 生成
- `.vscodeignore` の調整（docs/, scripts/, raw-logs/ 等を除外）
- `extension/README.md`（他者向け）を新規作成:
  - インストール手順（`.vsix` / CLI）
  - 使い方（コマンド一覧、設定項目）
  - 制約事項（macOS 推奨、Cursor 専用、better-sqlite3 リビルド必要）
- ドメイン固有情報の排除確認

### Step 5: 検証 + ドキュメント（概算: 30分）

- `.vsix` を別環境（クリーンな Cursor インストール）でテスト
- CLI の `npm link` テスト
- エピソード + ADR + VERIFICATION_MATRIX 更新

---

## 4. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| better-sqlite3 が `.vsix` 内で動かない | インストール後にリビルドが必要 | `postinstall` スクリプトで `@electron/rebuild` を自動実行。README に手順記載 |
| esbuild が protobuf decoder を壊す | デコードエラー | `Buffer` 操作は esbuild で問題になりにくいが、E2E で検証 |
| Windows/Linux でパスが間違っている | DB が見つからない | Step 0 で実パスを確認。テストは macOS のみだが、エラーメッセージで明示 |

---

## 5. peer-ai-review 実施ポイント

**以下は実装プラン作成時に TODO 項目として独立登録すること。**

1. **Step 0 完了時**: ネイティブモジュール配布方式の決定（問題が出た場合のみ）
2. **Step 4 完了時**: .vsix + CLI の全体レビュー

---

## 6. ADR 作成チェックリスト

**各項目を対応 Step の直後に独立 TODO として配置すること。**

- [ ] esbuild の設定方針（external 指定、バンドル対象）
- [ ] ネイティブモジュール（better-sqlite3）の配布方式
- [ ] CLI の配布方式（npm link vs standalone vs npx）

---

## 7. 完了条件

Phase 4 完了時に統合ハブスレッドに持ち帰るもの:

- [ ] `.vsix` ファイル（Cursor でインストール可能）
- [ ] CLI が `cursor-thread-tools` コマンドで実行可能
- [ ] `extension/README.md`（他者向けインストール・使用ガイド）
- [ ] `scripts/install.sh`
- [ ] VERIFICATION_MATRIX 更新
- [ ] 該当する ADR の作成

Phase 4 完了後にプロジェクト全体の振り返り（レトロスペクティブ）を実施。

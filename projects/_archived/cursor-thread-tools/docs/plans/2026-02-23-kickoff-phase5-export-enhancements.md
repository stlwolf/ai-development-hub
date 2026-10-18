---
title: "Phase 5 キックオフ: エクスポート体験の拡張（出力先選択 + Composer 自動追加）"
date: 2026-02-23
type: plan
participants:
  - Eddy
  - Cursor Agent (Primary)
related:
  - type: derived_from
    ref: ../discussions/feature-requests/2026-02-22-export-enhancements.md
    reason: "提案1（出力先変更）+ 提案2（Composer 自動追加）の確定仕様"
  - type: derived_from
    ref: ../episodes/2026-02-21-retrospective-project-complete.md
    reason: "Phase 1〜4 レトロスペクティブからの継続"
  - type: depends_on
    ref: ../../CONVENTIONS.md
    reason: "ドキュメント規約（命名規則・ADR昇格基準・gate運用・plan/episode分離・フェーズ実行フロー）"
  - type: depends_on
    ref: ../REQUIREMENTS.md
    reason: "FR-2, FR-5 のエクスポート機能への拡張"
tags: [phase5, export, ux, composer-api, folder-picker, vscode-extension]
keywords: [showOpenDialog, composer.addfilestocomposer, outputDir, setOutputDir]
use_when:
  - "Phase 5 の作業を開始するとき（このファイルが最初のプロンプト）"
  - "エクスポート体験の拡張について確認したいとき"
---

# Phase 5 キックオフ: エクスポート体験の拡張

**作業開始前に必ず以下を読むこと:**
- **`CONVENTIONS.md`**（プロジェクトルート）: ファイル命名規則、ADR 昇格基準、ADR フロー組み込み、plan/episode 分離ルール、gate 運用、事実検証粒度、プラン構成ガイドライン、**フェーズ実行フロー**
- **`docs/REQUIREMENTS.md`**: FR-2（エクスポート）、FR-5（カスタマイズ）

## 実行フロー

CONVENTIONS.md の「フェーズ実行フロー」に従う（3段階構成）:

### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + 既存コード（`extension/src/commands/export.ts`, `extension/src/extension.ts`, `extension/package.json`）
2. **プラン作成**: Agent mode で `docs/plans/2026-02-23-plan-phase5-export-enhancements.md` に直接作成（Step 0 必須、概算時間、ADR TODO 独立配置、gate TODO 独立配置）
3. **peer-ai-review**: `/peer-ai-review` でプランの3者合意を取得
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告

**← Stage 1 完了後、ここで停止してユーザーに報告する。** ユーザーが Plan mode に切り替えてから Stage 2 に進む。

### Stage 2: 実装（Plan mode）

5. **プラン変換**: 確定済みプラン MD を Plan mode のプランに変換
6. **ビルド実行**: Plan mode の TODO に従って実装。gate は TODO 項目として実行

### Stage 3: 成果物記録（Agent mode）

7. **成果物記録**: エピソード + ADR（該当する場合）+ VERIFICATION_MATRIX 更新
8. **キックオフ突合**: 本キックオフの成功基準・完了条件と結果を突合

## 1. 目的

Phase 1〜4 で完成したエクスポート機能の**体験（UX）を改善する**。機能の根幹には手を入れず、2つの小粒な改善を加える:

1. **出力先変更コマンド**: `settings.json` を直接編集せずに、フォルダピッカーで `outputDir` を変更できるようにする
2. **Composer 自動追加**: エクスポート後、ファイルを Cursor Composer の `@` 参照に自動追加し、即座にチャットで参照可能にする

### Phase 5 の成功基準

- [ ] `Thread Tools: Set Output Directory` コマンドでフォルダピッカーが開き、選択したフォルダが `settings.json` に保存される
- [ ] エクスポート後、ファイルが Composer に `@` 参照として自動追加される
- [ ] `composer.addfilestocomposer` の失敗がエクスポート全体を阻害しない（サイレント失敗）
- [ ] 既存のエクスポートフロー（手動エクスポート・自動保存・CLI）に回帰がない

---

## 2. Phase 4 からの引き継ぎ

### 解決済み

- VS Code 拡張: `threadTools.list` / `threadTools.export` + 自動保存 + 設定（F5 実機テスト済み）
- CLI: `cursor-thread-tools list` / `export` が動作（E2E テスト済み）
- esbuild バンドリング + `.vsix` パッケージング
- コア層 / UI 層分離済み（`core/threads.ts`）

### 現在のエクスポートフロー

```
手動エクスポート（export.ts）:
  QuickPick → extractThreadContent → generateMarkdown → writeFileSync → openTextDocument → showTextDocument → showInformationMessage

自動保存（extension.ts）:
  setInterval → listAllThreads → 差分検知 → extractThreadContent → generateMarkdown → writeFileSync
```

### 変更対象のコード

| ファイル | 変更内容 |
|---------|---------|
| `extension/package.json` | コマンド追加（`threadTools.setOutputDir`）、`outputDir` の description 更新 |
| `extension/src/extension.ts` | `threadTools.setOutputDir` コマンド登録 |
| `extension/src/commands/export.ts` | エクスポート後に `composer.addfilestocomposer` 呼び出し追加 |
| （新規）`extension/src/commands/setOutputDir.ts` | フォルダピッカー + 設定書き込み |

---

## 3. 実施計画

### Step 0: 前提調査（概算: 15分）

- 現在の Cursor バージョンで `composer.addfilestocomposer` が動作するか確認
  - `vscode.commands.getCommands(true)` で存在を確認
  - テストコマンドで実際に動作するか検証
- `showOpenDialog` の `canSelectFolders` + `openLabel` オプションの動作確認
- `vscode.workspace.asRelativePath()` の挙動確認（ワークスペース外のパスが渡された場合）

### Step 1: 出力先変更コマンド（概算: 20分）

`threadTools.setOutputDir` コマンドの実装:

```typescript
// commands/setOutputDir.ts
const result = await vscode.window.showOpenDialog({
  canSelectFolders: true,
  canSelectFiles: false,
  canSelectMany: false,
  openLabel: 'Select Output Directory',
  defaultUri: currentOutputDirUri,
});
if (result && result[0]) {
  const relativePath = vscode.workspace.asRelativePath(result[0]);
  await vscode.workspace.getConfiguration('cursorThreadTools')
    .update('export.outputDir', relativePath, vscode.ConfigurationTarget.Workspace);
  vscode.window.showInformationMessage(`Output directory set to: ${relativePath}`);
}
```

- `package.json` にコマンドとアクティベーションイベントを追加
- `extension.ts` にコマンド登録
- `outputDir` 設定の `description` に「`Thread Tools: Set Output Directory` コマンドでフォルダ選択も可能」と追記

### Step 2: Composer 自動追加（概算: 20分）

`export.ts` のエクスポート後処理に追加:

```typescript
const doc = await vscode.workspace.openTextDocument(filePath);
await vscode.window.showTextDocument(doc, { preview: false });

// Composer にファイル参照を追加（非公開 API、失敗してもエクスポートに影響しない）
try {
  await vscode.commands.executeCommand(
    'composer.addfilestocomposer',
    vscode.Uri.file(filePath),
  );
} catch {
  // Cursor 非公開 API のため、サイレントに無視
}
```

- 自動保存（`extension.ts`）には追加しない（バックグラウンド処理で Composer に追加すると UX が混乱する）
- CLI には適用不可（VS Code API に依存）

### Step 3: ビルド + 検証（概算: 15分）

- `npm run build` で esbuild バンドリング
- F5 デバッグ:
  - `Set Output Directory` コマンドでフォルダ選択 → `settings.json` に反映されることを確認
  - `Export Thread` → エクスポート後に Composer にファイル参照が追加されることを確認
  - 既存のエクスポート（手動/自動保存）が回帰なく動作すること
- CLI の回帰確認: `cursor-thread-tools list` / `cursor-thread-tools export --all --since 24h`

### Step 4: ドキュメント + 成果物記録（概算: 15分）

- エピソード作成: `docs/episodes/2026-02-23-phase5-export-enhancements.md`
- VERIFICATION_MATRIX に A-5 セクション追加
- 該当する ADR 作成（判断ポイントがあれば）
- キックオフ突合

---

## 4. リスクと対処

| リスク | 影響 | 対処 |
|-------|------|------|
| `composer.addfilestocomposer` が Cursor アップデートで変更/削除 | Composer 追加が無効になる | try/catch でサイレント失敗。NFR-5「薄く作って壊れたら直す」方針 |
| `showOpenDialog` でワークスペース外のフォルダが選択される | 相対パスに変換できない | `asRelativePath` は絶対パスをそのまま返す仕様。動作に支障なし |
| `composer.addfilestocomposer` がファイルをエディタで開く前提 | ファイルが開かれていないと追加されない | `showTextDocument` の後に呼ぶので問題なし（discussion で確認済み） |

---

## 5. peer-ai-review 実施ポイント

**以下は実装プラン作成時に TODO 項目として独立登録すること。**

スコープが小さいため、gate は1箇所のみ:

1. **Step 2 完了時**: `composer.addfilestocomposer` の動作確認。非公開 API のため、実際に動作するかの検証が最重要

---

## 6. ADR 作成チェックリスト

**各項目を対応 Step の直後に独立 TODO として配置すること。**

本 Phase は小規模かつ既存方針に沿った実装のため、ADR が必要になる可能性は低い。ただし以下のケースが発生したら作成する:

- [ ] `composer.addfilestocomposer` の代替手段を検討して別のアプローチを選択した場合
- [ ] Composer 自動追加をデフォルト有効/無効の判断で議論が生じた場合

---

## 7. 完了条件

Phase 5 完了時の成果物:

- [ ] `threadTools.setOutputDir` コマンドが動作する拡張コード
- [ ] エクスポート後の Composer 自動追加が動作する拡張コード
- [ ] VERIFICATION_MATRIX の A-5 更新
- [ ] エピソード（`docs/episodes/2026-02-23-phase5-export-enhancements.md`）
- [ ] 該当する ADR（必要な場合のみ）

---

## 8. スコープ外（将来）

discussion で明示されている将来検討項目:

- ポストアクション QuickPick（開く / コピー / パスコピー の選択肢）
- Webview 設定画面
- CLI 側への反映（`--copy` オプション等）

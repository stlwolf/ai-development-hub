---
title: "Phase 4 エピソード: パッケージング・配布"
date: 2026-02-21
type: episode
related:
  - type: implements
    ref: ../plans/2026-02-21-plan-phase4-packaging.md
    reason: "Phase 4 実装プランの実行記録"
  - type: derived_from
    ref: ../plans/2026-02-21-kickoff-phase4-packaging.md
    reason: "Phase 4 キックオフから派生"
  - type: evidence_for
    ref: ../VERIFICATION_MATRIX.md
    reason: "A-4 セクションの根拠"
tags: [phase4, packaging, esbuild, vsix, cli, episode]
keywords: [vsce, vsix, esbuild, electron-rebuild, npm-link, bin, better-sqlite3, bindings]
---

# Phase 4 エピソード: パッケージング・配布

## 実績時間

| Step | 内容 | 概算 | 実績 | 差異 |
|------|------|------|------|------|
| 0 | 前提検証 | 30分 | 15分 | esbuild テストが即成功、transitive deps 調査も迅速 |
| 1 | esbuild バンドリング | 45分 | 20分 | shebang 重複問題の修正を含む |
| ADR | esbuild 設定方針 | 10分 | 5分 | - |
| 2 | クロスプラットフォームパス | 20分 | 10分 | 変更箇所が明確 |
| 3 | install.sh + CLI bin | 30分 | 15分 | - |
| ADR | ネイティブモジュール + CLI 配布 | 15分 | 10分 | - |
| 4 | .vsix + INSTALL.md | 45分 | 40分 | --no-dependencies の問題発覚と対応 |
| GATE | peer-ai-review | 15分 | 10分 | vscode:prepublish 追加指摘 |
| 5 | E2E 検証 | 30分 | 15分 | - |
| 6 | ドキュメント | 20分 | 15分 | - |
| **合計** | | **4時間20分** | **約2時間35分** | 概算の60%で完了 |

## 発見した問題と対処

### 1. esbuild shebang 重複（Step 1）

- **問題**: `src/cli.ts` の `#!/usr/bin/env node` と esbuild の `banner` が両方出力され、Node.js が2行目の shebang を SyntaxError として認識
- **対処**: ソースファイルから shebang を削除し、esbuild の `banner` のみで管理
- **ADR-008 に記録**

### 2. `--no-dependencies` で node_modules が含まれない（Step 4a）

- **問題**: `vsce package --no-dependencies` を使うと `.vscodeignore` のホワイトリスト（`!node_modules/better-sqlite3/**`）が無効化され、`node_modules/` が一切 `.vsix` に含まれない
- **対処**: `--no-dependencies` を外し、通常の `vsce package` を使用。`.vscodeignore` のホワイトリスト型で不要なパッケージは除外される
- **peer-ai-review（プラン策定時）で Codex/Claude 両者が指摘していた通りの結果**

### 3. vsce の secretlint エラー（Step 4a）

- **問題**: サンドボックス環境で `vsce package` を実行すると `p-map` の concurrency エラーが発生
- **対処**: サンドボックス外（`required_permissions: ["all"]`）で実行して回避。vsce 内部の `@secretlint/node` のバグ（concurrency=0）

### 4. peer-ai-review gate での `vscode:prepublish` 指摘

- **問題**: Claude が `vscode:prepublish` フックの欠如を高優先で指摘。ビルド忘れで古い `out/` が `.vsix` に入るリスク
- **対処**: `"vscode:prepublish": "npm run build"` を `package.json` に追加

### 5. tsc の古い出力が out/ に残留（Step 4a）

- **問題**: esbuild 移行前の `tsc` 出力（`out/commands/`, `out/core/`, `out/db/` 等の個別ファイル）が `out/` に残っており、`.vsix` に含まれた
- **対処**: `rm -rf out/commands out/core out/db out/export out/proto out/*.d.ts out/*.d.ts.map` で手動クリーンアップ

## プラン変更点

- `.vscodeignore`: プランではブラックリスト型を提案 → peer-ai-review で修正、ホワイトリスト型を維持。実装ではさらに transitive deps（`bindings`, `file-uri-to-path`）を追加
- `--no-dependencies`: Step 0 で検証予定だったが、Step 4a で実際に問題が発覚。プラン通り「使わない」方針に切り替え
- `vscode:prepublish`: プランになかったが、peer-ai-review gate で Claude が指摘、追加

## 成果物

- `extension/esbuild.mjs`: esbuild ビルドスクリプト
- `extension/scripts/install.sh`: セットアップスクリプト
- `extension/INSTALL.md`: 他者向けインストール・使用ガイド（新規作成）
- `extension/cursor-thread-tools-0.2.0.vsix`: パッケージ済み .vsix ファイル（8.08 MB）
- `docs/decisions/ADR-008-esbuild-bundling.md`
- `docs/decisions/ADR-009-native-module-distribution.md`
- `docs/decisions/ADR-010-cli-distribution.md`

## 変更したファイル

- `extension/package.json`: scripts（build, watch, compile, package, vscode:prepublish）、bin、devDependencies（esbuild, @vscode/vsce）
- `extension/tsconfig.json`: `noEmit: true` 追加
- `extension/src/db/reader.ts`: `getStateDbPath()` をクロスプラットフォーム対応
- `extension/src/cli.ts`: macOS 専用チェック削除、shebang 削除
- `extension/.vscodeignore`: transitive deps（`bindings`, `file-uri-to-path`）+ `INSTALL.md` 追加

---

## ポストコンプリーション（プラン実行完了後のやりとり）

以下はプラン Step 0-6 完了報告後に、ユーザーとの追加やりとりで行った内容を時系列で記録する。

### 1. CLI_USAGE.md 作成

- ユーザーから「CLI ツール周りの自分向け USAGE ドキュメントがほしい」とリクエスト
- `extension/CLI_USAGE.md` を新規作成: セットアップ手順、`list`/`export` の実例、`jq` パイプや `grep` との組み合わせ、よく使うパターン（日次バックアップ、composerId 取得、git 連携）、トラブルシューティング

### 2. CLI 登録確認 → npm link 実行

- ユーザーが「ビルド＆登録済みなのか？」と確認
- 状態: ビルド済み（`out/cli.js` 存在）だが `npm link` は E2E テスト後に `npm unlink` でクリーンアップ済みだった
- `npm link` を実行してグローバルコマンドとして再登録

### 3. CLI 実行エラー: NODE_MODULE_VERSION 不一致（CLI 側）

- ユーザーが自身のターミナルから `cursor-thread-tools list --json` を実行 → `NODE_MODULE_VERSION 141`（コンパイル済み）vs `108`（Node.js が要求）エラー
- **根本原因**: Phase 4 の E2E テスト（Step 5）は Cursor Agent 環境（Electron ランタイム）の中で実行されていたため成功していた。ユーザーの通常ターミナルはシステムの Node.js v25.6.1 で動作するため、Electron 向けにリビルドされた `.node` バイナリと ABI が不一致
- **対処**: `npm rebuild better-sqlite3` で Node.js 向けにリビルド → 解決

### 4. Cursor 拡張機能インストールテスト: NODE_MODULE_VERSION 不一致（Extension 側）

ユーザーが `.vsix` を Cursor にインストールして動作確認。3回の試行が必要だった:

| 試行 | リビルド対象 | .vsix 内の MODULE_VERSION | Cursor が要求 | 結果 |
|------|------------|--------------------------|--------------|------|
| 1回目 | なし（npm install のプリビルドのまま） | 141（Node.js v25） | 140（Electron 39） | NG |
| 2回目 | Electron 38.8.2（MODULE_VERSION 140 = Electron 38 と誤推測） | 139 | 140 | NG |
| 3回目 | Electron 39.4.0（`Info.plist` の `CFBundleVersion` で確認） | 140 | 140 | OK |

- **根本原因**: Phase 4 実装中に `@electron/rebuild` を一度も実行していなかった。`install.sh` を作成しただけで実行せず、`npm run package` で `.vsix` を作ったため、中身は `npm install` 時のプリビルド（Node.js v25 向け、MODULE_VERSION 141）のまま
- **2回目の失敗の原因**: NODE_MODULE_VERSION 140 = Electron 38 という推測が誤り。実際は Electron 39.4.0 が MODULE_VERSION 140 を使用
- **解決**: `plutil -p /Applications/Cursor.app/Contents/Frameworks/Electron\ Framework.framework/Resources/Info.plist` で `CFBundleVersion: 39.4.0` を確認し、正しいバージョンでリビルド
- **動作確認**: `threadTools.list` で QuickPick にスレッド一覧表示、`threadTools.export` で `.thread-exports/` にファイル生成を確認

### 5. setup-cli.sh 作成

- ユーザーから「CLI の再ビルドから link までのスクリプトがほしい」とリクエスト
- `extension/scripts/setup-cli.sh` を新規作成: `npm rebuild better-sqlite3` → `npm run build` → `npm link` の3ステップ一括実行

### 6. INSTALL_JP.md 作成

- ユーザーから「INSTALL.md の日本語版がほしい」とリクエスト
- `extension/INSTALL_JP.md` を新規作成: 英語版と同一構成、`setup-cli.sh` への参照を追加

### 7. CLI --help 表記修正

- ユーザーが `cursor-thread-tools --help` を実行 → Usage 内のコマンド例が `node cli.js` のまま
- `src/cli.ts` の `usage()` 関数内の表記を `cursor-thread-tools` に修正、ビルド反映

### 8. 発見: サブエージェントスレッドの可視化

- ユーザーが `threadTools.export` でエクスポートした結果、サブエージェント（Task tool）のスレッドも一覧に出ることを発見
- composerId が `task-toolu_*` 形式のエントリがサブエージェント
- Cursor はサブエージェントの会話も親スレッドと同じ `composerData` テーブルに格納している
- 「明示的にサブエージェントのやり取りが見れるのは初めて」というユーザーの感想
- 将来的にサブエージェントの除外/抽出フィルタ（`--filter` オプション等）があると便利

### 追加成果物まとめ

| ファイル | 種別 | 内容 |
|---------|------|------|
| `extension/CLI_USAGE.md` | 新規 | 開発者向け CLI 使い方ガイド |
| `extension/INSTALL_JP.md` | 新規 | INSTALL.md の日本語版 |
| `extension/scripts/setup-cli.sh` | 新規 | CLI セットアップ一括スクリプト |
| `extension/src/cli.ts` | 修正 | `--help` の表記を `cursor-thread-tools` に修正 |

### 教訓

1. **E2E テストのランタイム差異**: Cursor Agent 環境はターミナルの Node.js とは異なるランタイム（Electron）で動作する。CLI の E2E テストは Agent 環境ではなく、ユーザーの通常ターミナルから実行すべきだった
2. **`.vsix` パッケージ前のネイティブモジュールリビルド必須**: `npm run package`（`vscode:prepublish` → `npm run build`）は esbuild のみ実行し、ネイティブモジュールはリビルドしない。`.vsix` パッケージ前に `@electron/rebuild` の実行が必要。install.sh を作っただけでは不十分で、実行してからパッケージすべき
3. **Electron バージョン検出は実バイナリから**: `Info.plist` の `CFBundleVersion` が最も信頼できる方法。NODE_MODULE_VERSION からの逆算（140 → Electron 38 と推測）は誤りの元
4. **NODE_MODULE_VERSION マッピングの推測は危険**: Electron バージョンと NODE_MODULE_VERSION の対応を推測せず、Cursor の実バイナリから確認すべき。2回目の失敗はこの推測ミスによるもの

---

## スレッド作業フィードバック

### 成果物一覧（必須）

**新規作成**:
- `extension/esbuild.mjs`: esbuild ビルドスクリプト（拡張 + CLI デュアルエントリ）
- `extension/scripts/install.sh`: Electron 向けフルインストールスクリプト
- `extension/scripts/setup-cli.sh`: CLI セットアップ一括スクリプト（Node.js 向け rebuild + build + npm link）
- `extension/INSTALL.md`: 他者向けインストール・使用ガイド（英語）
- `extension/INSTALL_JP.md`: 同上の日本語版
- `extension/CLI_USAGE.md`: 開発者向け CLI 実践ガイド（jq/grep 連携、日次バックアップ等）
- `extension/cursor-thread-tools-0.2.0.vsix`: パッケージ済み拡張機能（8.07 MB）
- `docs/decisions/ADR-008-esbuild-bundling.md`
- `docs/decisions/ADR-009-native-module-distribution.md`
- `docs/decisions/ADR-010-cli-distribution.md`
- `docs/episodes/2026-02-21-phase4-packaging.md`（本ファイル）
- `docs/plans/2026-02-21-plan-phase4-packaging.md`: 実装プラン（Stage 1 で作成）

**変更**:
- `extension/package.json`: scripts（build, watch, compile, package, vscode:prepublish）、bin フィールド、devDependencies（esbuild, @vscode/vsce）追加
- `extension/tsconfig.json`: `noEmit: true` 追加
- `extension/src/db/reader.ts`: `getStateDbPath()` をクロスプラットフォーム対応（platform() switch）
- `extension/src/cli.ts`: macOS 専用チェック削除、shebang 削除（esbuild banner に移行）、--help 表記修正
- `extension/.vscodeignore`: transitive deps（`bindings`, `file-uri-to-path`）+ `INSTALL.md` 追加
- `docs/VERIFICATION_MATRIX.md`: A-4 セクション（パッケージング・配布）追加

### 実行フロー概略

Stage 1（Agent mode）: コンテキスト読み込み → プラン MD 作成 → peer-ai-review 3者合意 → ユーザー報告・停止。Stage 2（Plan mode → Agent mode）: プラン変換 → Step 0-6 実装（前提検証 → esbuild → クロスプラットフォーム → install.sh + CLI bin → .vsix + INSTALL.md → peer-ai-review gate → E2E → ドキュメント）。ポストコンプリーション: ユーザーの実環境でのCLI/Extension動作確認で NODE_MODULE_VERSION 問題を発見・修正、追加ドキュメント作成。

### 想定外の点（必須）

**ポジティブ**:
- 概算 4 時間 20 分に対し、プラン実装は約 2 時間 35 分（60%）で完了。esbuild 導入が想定より簡単だった（テストビルド一発成功、設定もシンプル）
- peer-ai-review（プラン策定時）の指摘が正確だった。`--no-dependencies` の問題は Codex/Claude 両者が予告した通りに発生し、ホワイトリスト方式への切り替えがスムーズだった
- `vscode:prepublish` の追加指摘（gate 時の Claude）はプランに含まれていなかった改善で、ビルド忘れ防止として有効

**ネガティブ**:
- **E2E テストが Agent 環境で成功してしまった**: CLI の E2E テスト（Step 5）が Cursor Agent のターミナル（Electron ランタイム）で実行されたため、NODE_MODULE_VERSION 不一致に気づかなかった。ユーザーの通常ターミナルで初めて発覚
- **`.vsix` に Electron 向けリビルドが含まれていなかった**: `install.sh` を作成したが実行せず、`npm run package` した。`vscode:prepublish` は esbuild のみ実行しネイティブモジュールはリビルドしないため、Node.js プリビルドのまま `.vsix` に含まれた
- **Electron バージョンの逆引きに2回失敗**: NODE_MODULE_VERSION 140 → Electron 38 と推測して Electron 38.8.2 でリビルドしたが MODULE_VERSION 139 を生成。実際は Electron 39.4.0 が MODULE_VERSION 140 だった

### ボトルネック

最も時間がかかったのは **ポストコンプリーションの .vsix MODULE_VERSION 修正**（3回の試行）。プラン実行中ではなく、ユーザー動作確認で発覚。見積もりには含まれていなかった追加コスト。

プラン実行中では **Step 4a（.vsix ビルド）** が最長。`--no-dependencies` の問題発覚 → 方針切り替え → 再ビルド → `vsce` の secretlint バグへの対処が重なった。見積もり 45 分に対し実績 40 分でほぼ一致。

### プラン実行時に調整した点（必須）

1. **`--no-dependencies` を使わない方針に切り替え**: プランでは Step 0 で検証予定だったが、Step 4a で実際に `.vsix` をビルドして問題が発覚。`node_modules/` が一切含まれなかったため、通常の `vsce package` に切り替え
2. **`.vscodeignore` にブラックリスト型を使わない**: プラン原案ではブラックリスト型を提案していたが、peer-ai-review で修正。既存のホワイトリスト型を維持し、transitive deps（`bindings`, `file-uri-to-path`）を追加
3. **`vscode:prepublish` 追加**: プランになかったが、peer-ai-review gate で Claude が指摘。`npm run build` を自動実行するフックとして追加
4. **shebang の管理方法**: esbuild の `banner` と TypeScript ソースの shebang が重複する問題。ソース側を削除して banner のみで管理に変更
5. **tsc 旧出力のクリーンアップ**: esbuild 移行前の `tsc` 出力（`out/commands/`, `out/core/` 等）が残っていたため手動削除

### コンテキスト復元性能

良好。キックオフ（`2026-02-21-kickoff-phase4-packaging.md`）+ CONVENTIONS.md + REQUIREMENTS.md + 既存ソースコードの読み込みで十分にスタートできた。Phase 3 エピソードの「better-sqlite3 は Electron 向けとシステム Node 向けで別々にビルドが必要」という記述が、ポストコンプリーションの MODULE_VERSION 問題の理解に直結した。

生ログを掘り返す必要はなかった。ただし、Electron バージョン（39.4.0）の確認方法は Phase 2 エピソードにハードコードされており、「なぜ 39.4.0 なのか」「どうやって確認したのか」の記述が薄かった。ポストコンプリーションで `Info.plist` による検出方法を確立し、本エピソードに記録した。

### 規約・ルールの遵守状況と摩擦

- **ADR 作成のフロー組み込み**: CONVENTIONS.md の規定通り、ADR-008/009/010 を対応 Step の直後に作成できた。Phase 1-3 で3フェーズ連続漏れた教訓が活きている
- **plan/episode 分離**: プランに実行結果を混入せず、エピソードに記録する分離ルールを遵守
- **peer-ai-review gate**: プラン策定時（Stage 1）と Step 4 完了後（GATE）の2回実施。Phase 1-2 で全 gate が脱落した問題は解消
- **摩擦点**: `npm run package` 前に `@electron/rebuild` を実行するフローがプランにも CONVENTIONS にも明示されていなかった。「ネイティブモジュールを含む `.vsix` をパッケージする際は、対象 Electron バージョンでリビルドしてからパッケージすること」を手順として明文化すべき

### ナレッジ昇格

- **ADR-008/009/010**: 作成済み
- **CONVENTIONS.md への追加案**: `.vsix` パッケージング手順として「`@electron/rebuild` → `npm run package`」の順序を明記。Electron バージョン検出方法（`Info.plist` の `CFBundleVersion`）も含める
- **`install.sh` のデフォルト Electron バージョン**: 現在 39.4.0 だが、Cursor アップデートで変わる可能性がある。Cursor バージョンと Electron バージョンの対応表をドキュメント化する価値がある

### 再利用可能な知見

1. **esbuild + ネイティブモジュールの external パターン**: `external: ['vscode', 'better-sqlite3']` + `.vscodeignore` ホワイトリストの組み合わせは、ネイティブモジュールを使う VS Code 拡張全般に適用可能
2. **ネイティブモジュールの Electron/Node.js デュアルビルド問題**: `@electron/rebuild` と `npm rebuild` の切り替えが必要な点は、better-sqlite3 に限らず全ネイティブアドオンに共通
3. **`Info.plist` からの Electron バージョン検出**: Cursor に限らず、Electron ベースアプリのバージョン確認に `plutil -p .../Electron Framework.framework/Resources/Info.plist` が使える
4. **`--no-dependencies` の落とし穴**: `vsce package --no-dependencies` は `.vscodeignore` のホワイトリストも無効化する。ネイティブモジュールを含む拡張では使用不可
5. **CLI セットアップの分離スクリプト**: Extension 向け（`install.sh`）と CLI 向け（`setup-cli.sh`）を分けるパターンは、同一コードベースで異なるランタイムを対象とするプロジェクトに転用可能

### プラン構築プロセスの改善案

1. **E2E テスト Step に「実行環境の明示」を追加すべき**: Step 5 の E2E テストに「Cursor Agent 環境」と「ユーザーの通常ターミナル」を区別した検証項目を入れるべきだった。ネイティブモジュールを含むプロジェクトでは特に重要
2. **「作って終わり」ではなく「作って実行して検証」**: `install.sh` を作成したが実行しなかった。スクリプト作成 Step には「そのスクリプトを実行して結果を確認する」を必ず含めるべき
3. **peer-ai-review の事実検証が機能した**: プラン策定時の peer-ai-review で `--no-dependencies` の危険性を指摘してもらえたことで、Step 4a での方針切り替えが迅速だった。プランレベルの peer-ai-review は投資対効果が高い
4. **見積もりの精度**: 概算の 60% で完了。前提調査を Stage 1 で十分に行ったことが寄与。ただしポストコンプリーションの修正コストは見積もりに含まれていなかった。「ユーザー受け入れテスト」の時間枠をプランに含めるべき

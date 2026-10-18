---

title: "Phase 4 実装プラン: パッケージング・配布"
date: 2026-02-21
type: plan
related:

- type: derived_from
ref: 2026-02-21-kickoff-phase4-packaging.md
reason: "Phase 4 キックオフから派生"
- type: depends_on
ref: ../REQUIREMENTS.md
reason: "NFR-6（配布）に対応"
- type: depends_on
ref: ../../CONVENTIONS.md
reason: "ドキュメント規約・フェーズ実行フロー"
- type: depends_on
ref: ../decisions/ADR-001-sqlite-library.md
reason: "better-sqlite3 採用の決定"
- type: depends_on
ref: ../decisions/ADR-005-cli-packaging.md
reason: "CLI パッケージング方法の決定"
tags: [phase4, packaging, esbuild, vsix, cli, cross-platform, distribution]
keywords: [vsce, vsix, esbuild, electron-rebuild, postinstall, npm-link, bin, better-sqlite3]
use_when:
- "Phase 4 の実装 TODO に変換するとき"
- "パッケージング方針の詳細を確認したいとき"

---

# Phase 4 実装プラン: パッケージング・配布

## 前提知識（プラン策定時の調査結果）

### esbuild + better-sqlite3

- better-sqlite3 はネイティブモジュール（`.node` バイナリ）を含むため、esbuild でバンドル不可
- esbuild 設定で `external: ['vscode', 'better-sqlite3']` として除外し、`node_modules/` に残す
- VS Code 公式ドキュメントでもネイティブモジュールは external 扱いが推奨（[Bundling Extensions](https://code.visualstudio.com/api/working-with-extensions/bundling-extension)）

### vsce package + ネイティブモジュール

- `vsce package` は `node_modules/` を `.vsix` に含める（`.vscodeignore` で制御）
- ネイティブモジュールの `.node` ファイルはビルド元のプラットフォーム固有 → `.vsix` はビルド環境のプラットフォームでのみ動作
- 利用者側で `@electron/rebuild` の再実行が必要になる可能性がある

### クロスプラットフォームパス


| OS      | パス                                                                    |
| ------- | --------------------------------------------------------------------- |
| macOS   | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` |
| Windows | `%APPDATA%\Cursor\User\globalStorage\state.vscdb`                     |
| Linux   | `~/.config/Cursor/User/globalStorage/state.vscdb`                     |


Windows / Linux のパスは Cursor コミュニティフォーラムの情報に基づく。Step 0 で公式ソースを追加確認する。

---

## Step 0: 前提検証（概算: 30分）

**目的**: プラン策定時の調査結果を実環境で検証し、前提が崩れていないか確認する。

- esbuild の `external` + `platform: 'node'` で better-sqlite3 を除外したビルドが通ることを確認（最小限のテストビルド）
- 現在の `node_modules/better-sqlite3/` 内のランタイム依存ファイル構成を確認 — `.node` バイナリ (`build/Release/better_sqlite3.node`)、`bindings` パッケージ、`file-uri-to-path` 等の transitive deps が必要かチェック（peer-review で Codex が指摘）
- `vsce package` で `.vscodeignore` のホワイトリスト（既存: `!node_modules/better-sqlite3/`**）が transitive deps をカバーしているか確認 → `unzip -l *.vsix | grep node_modules` でテスト
- `vsce package --no-dependencies` の実挙動確認: `.vscodeignore` のホワイトリストが有効かどうかテスト。無効なら `--no-dependencies` を使わない方針に切り替え（peer-review で Codex/Claude 両者が指摘）
- Electron バージョン検出方法の確認: Cursor の `package.json` に `electronVersion` がないことを確認済み（Phase 2 では `39.4.0` をハードコード）。`process.versions.electron`（Extension Host 内）で取得可能か調査。フォールバック: `ELECTRON_VERSION` 環境変数 or スクリプト引数
- Windows / Linux の Cursor データディレクトリパスを Cursor ソースコード（`workbench.desktop.main.js`）で追加確認
- `vsce package --target <platform>` オプションの調査: プラットフォーム別 VSIX が native module 配布に有利か評価（peer-review で Codex が推奨）。Phase 4 スコープ内か判断

**gate**: 前提が崩れた場合はプランを修正してから Step 1 に進む。

---

## Step 1: esbuild バンドリング（概算: 45分）

**目的**: `tsc` のみのビルドを esbuild バンドルに移行し、配布サイズを削減する。

- `esbuild` を devDependencies に追加: `npm install --save-dev esbuild`
- `esbuild.mjs` ビルドスクリプトを作成:
  - 拡張エントリ: `src/extension.ts` → `out/extension.js`（format: cjs, platform: node, external: vscode + better-sqlite3）
  - CLI エントリ: `src/cli.ts` → `out/cli.js`（format: cjs, platform: node, external: better-sqlite3, `banner: { js: '#!/usr/bin/env node' }`）
  - sourcemap: true
- `package.json` の `scripts` を更新:
  - `"build": "node esbuild.mjs"`
  - `"watch": "node esbuild.mjs --watch"`
  - `"compile": "tsc -p ./ --noEmit"` （型チェック専用に変更、`-p ./` を明示）
- `tsconfig.json`: `noEmit: true` を追加（esbuild がトランスパイル担当）。`outDir`, `declaration`, `declarationMap` は残しても無害だが不要になる
- ビルド実行: `npm run build` → `out/extension.js` と `out/cli.js` が生成されることを確認
- F5 デバッグ（Extension Host）で `threadTools.list` が動作することを確認
- `node out/cli.js list` が動作することを確認

---

## TODO: ADR — esbuild 設定方針（Step 1 完了後に作成）

- ADR-008: esbuild バンドル設定 — external 指定、CJS 出力、sourcemap、tsc は型チェック専用に変更

---

## Step 2: クロスプラットフォームパス（概算: 20分）

**目的**: `getStateDbPath()` を macOS 以外でも動作するよう拡張する。

- `src/db/reader.ts` の `getStateDbPath()` を `platform()` に基づく switch 文に変更:

```typescript
import { platform, homedir } from 'os';

function getStateDbPath(options?: DbPathOptions): string {
  const appName = options?.appName ?? 'Cursor';
  switch (platform()) {
    case 'darwin':
      return join(homedir(), 'Library', 'Application Support', appName, 'User', 'globalStorage', 'state.vscdb');
    case 'win32':
      return join(process.env.APPDATA ?? join(homedir(), 'AppData', 'Roaming'), appName, 'User', 'globalStorage', 'state.vscdb');
    case 'linux':
      return join(process.env.XDG_CONFIG_HOME ?? join(homedir(), '.config'), appName, 'User', 'globalStorage', 'state.vscdb');
    default:
      throw new Error(`Unsupported platform: ${platform()}`);
  }
}
```

- `src/cli.ts` の macOS 専用チェック（`platform() !== 'darwin'` → `process.exit(1)`）を削除
- macOS で既存の動作が壊れていないことを確認（`node out/cli.js list`、F5 デバッグ）

---

## Step 3: `@electron/rebuild` 自動化 + CLI bin 対応（概算: 30分）

**目的**: インストール後のセットアップを簡素化する。

### 3a: install スクリプト

- `scripts/install.sh` を作成:
  - `npm install`
  - Electron バージョン検出: `ELECTRON_VERSION` 環境変数 > スクリプト引数 > デフォルト値（`39.4.0`、Phase 2 で確認済み）。Cursor の `package.json` には `electronVersion` フィールドがないため自動検出は困難（事実検証済み）
  - `npx @electron/rebuild -v <electron_version> -m .`
  - フォールバック: Electron バージョン検出に失敗した場合のエラーメッセージと手動指定方法の案内
- `scripts/install.sh` を実行してリビルドが成功することを確認

### 3b: CLI bin フィールド

- `package.json` に `bin` フィールドを追加:

```json
{
  "bin": {
    "cursor-thread-tools": "./out/cli.js"
  }
}
```

- `out/cli.js` の先頭に `#!/usr/bin/env node` shebang が含まれることを確認（Step 1 の esbuild `banner` 設定で追加済みのはず）
- `npm link` → `cursor-thread-tools list` が動作することを確認
- `npm unlink` でクリーンアップ

---

## TODO: ADR — ネイティブモジュール配布方式（Step 3 完了後に作成）

- ADR-009: ネイティブモジュール（better-sqlite3）の配布方式 — install.sh + @electron/rebuild、プラットフォーム固有 .node の制約

---

## TODO: ADR — CLI 配布方式（Step 3 完了後に作成）

- ADR-010: CLI 配布方式 — npm link + bin フィールド、CLI 使用時は `npm rebuild better-sqlite3` が必要な理由

---

## Step 4: .vsix ビルド + 他者向け README（概算: 45分）

**目的**: 他者がインストールできる `.vsix` パッケージを生成する。

### 4a: .vsix ビルド

- `@vscode/vsce` を devDependencies に追加: `npm install --save-dev @vscode/vsce`
- `.vscodeignore` の確認・更新: 現在のホワイトリスト型（`**` で全除外 → `!out/`** 等で許可）を維持（peer-review H1: ブラックリスト型への変更は devDeps 混入のリスク）。Step 0 の transitive deps 調査結果を反映し、`!node_modules/better-sqlite3/**` に加えて必要な transitive deps があれば追加:

```
**
!out/**
!node_modules/better-sqlite3/**
!package.json
!README.md
!INSTALL.md
```

- `package.json` に `vsce` 用スクリプトを追加: Step 0 の `--no-dependencies` 検証結果に基づき決定
  - `--no-dependencies` が `.vscodeignore` ホワイトリストと共存可能 → `"package": "vsce package --no-dependencies"`
  - 共存不可の場合 → `"package": "vsce package"`（`npm install --production` が走るが `.vscodeignore` で制御）
- `npm run build && npm run package` で `.vsix` ファイルが生成されることを確認
- `.vsix` のサイズと内容を確認: `unzip -l *.vsix | grep -E '(node_modules|out/|package.json|README)'` で必要ファイルが含まれ、不要ファイル（`src/`, `*.ts`, `esbuild.mjs` 等）が含まれていないことを確認

### 4b: 他者向け README

- `extension/INSTALL.md` を**新規作成**（他者向けインストール・使用ガイド）。既存の `extension/README.md` は開発記録用としてそのまま保持:
  - 概要（何ができるか）
  - インストール手順（`.vsix` → Cursor の「Install from VSIX」）
  - CLI インストール手順（`npm link` / `npx`）
  - コマンド一覧（`threadTools.list`, `threadTools.export`）
  - 設定項目（`contributes.configuration` の4項目）
  - 制約事項（macOS 推奨、Cursor 専用、`@electron/rebuild` 必要）
  - トラブルシューティング（better-sqlite3 リビルド手順）

### 4c: ドメイン固有情報の排除確認

- ソースコード全体でドメイン固有のハードコード値を検索（`grep -r` で確認）
- `package.json` の publisher / repository フィールドを確認

---

## GATE: peer-ai-review（Step 4 完了後）

- `.vsix` + CLI 全体のレビュー: `/peer-ai-review` を実行
  - 対象: esbuild 設定、.vscodeignore、install.sh、package.json 変更、README
  - 合格基準: `.vsix` が生成可能 + `npm link` で CLI 動作 + ドメイン固有情報なし

---

## Step 5: E2E 検証（概算: 30分）

**目的**: 全成功基準を満たすことを確認する。

- `.vsix` を Cursor で「Install from VSIX」でインストール → `threadTools.list` が動作
- CLI: `cursor-thread-tools list` が動作（`npm link` 経由）
- CLI: `cursor-thread-tools export --all --output-dir /tmp/test-export` が動作
- `scripts/install.sh` をクリーン環境で実行（`rm -rf node_modules && bash scripts/install.sh`）
- 自動保存: 設定変更 → タイマー動作確認（既存機能の回帰テスト）

---

## Step 6: ドキュメント・成果物記録（概算: 20分）

**目的**: Stage 3 の成果物を作成する。

- エピソード作成: `docs/episodes/2026-02-21-phase4-packaging.md`
  - 各 Step の実績時間
  - 発見した問題と対処
  - プラン変更点
- ADR ファイルの最終確認（Step 1, 3 の後に作成済みのはず）
- `docs/VERIFICATION_MATRIX.md` 更新:
  - A-4: パッケージング・配布（新規セクション追加）
- キックオフ突合: `2026-02-21-kickoff-phase4-packaging.md` の成功基準 6 項目との突合

---

## 成功基準チェックリスト（キックオフから転記）


| #   | 基準                                                     | 対応 Step    |
| --- | ------------------------------------------------------ | ---------- |
| 1   | `.vsix` ファイルを生成し、Cursor で「Install from VSIX」でインストールできる | Step 4a, 5 |
| 2   | CLI が `npm link` or `bin` フィールドで手軽に実行できる               | Step 3b, 5 |
| 3   | `@electron/rebuild` が `postinstall` or スクリプトで自動化されている  | Step 3a    |
| 4   | Windows / Linux のパス対応（`getStateDbPath()` の拡張）          | Step 2     |
| 5   | 他者向けガイド（`extension/INSTALL.md`）が存在する                 | Step 4b    |
| 6   | ドメイン固有情報が拡張コードに含まれていないことを確認                            | Step 4c    |


---

## リスク対応表


| リスク                                              | 影響度 | 対処                                                                                                                             |
| ------------------------------------------------ | --- | ------------------------------------------------------------------------------------------------------------------------------ |
| better-sqlite3 の `.node` ファイルが .vsix 内で正しく解決されない | 高   | Step 0 で esbuild + vsce の組み合わせを最小限テスト。`.vscodeignore` で `node_modules/better-sqlite3/`** を明示的に許可                               |
| esbuild が既存コードの CommonJS require を壊す             | 中   | Step 1 で F5 + CLI の動作確認を実施。問題があれば `format: 'cjs'` + `platform: 'node'` を調整                                                     |
| Windows/Linux のパスが不正確                            | 低   | Step 0 で Cursor ソースコードから確認。未検証プラットフォームはエラーメッセージで明示                                                                             |
| `vsce package` が better-sqlite3 のバイナリサイズで警告する    | 低   | `.vscodeignore` でバンドル対象を最小化。警告が出ても `.vsix` 生成は可能                                                                               |
| CLI と Extension で better-sqlite3 のビルドターゲットが衝突する  | 中   | `install.sh` で Electron 向けリビルド後、CLI 使用時は `npm rebuild better-sqlite3` が必要。同一ディレクトリでの併用不可を README と ADR-010 に明記（peer-review M1） |


---

## 概算時間まとめ


| Step   | 内容                          | 概算           |
| ------ | --------------------------- | ------------ |
| 0      | 前提検証                        | 30分          |
| 1      | esbuild バンドリング              | 45分          |
| ADR    | esbuild 設定方針                | 10分          |
| 2      | クロスプラットフォームパス               | 20分          |
| 3      | @electron/rebuild + CLI bin | 30分          |
| ADR    | ネイティブモジュール + CLI 配布         | 15分          |
| GATE   | peer-ai-review              | 15分          |
| 4      | .vsix + README              | 45分          |
| 5      | E2E 検証                      | 30分          |
| 6      | ドキュメント                      | 20分          |
| **合計** |                             | **約 4時間20分** |


---

## peer-ai-review 結果（イテレーション 1 — 3者合意）

**実施日**: 2026-02-21
**so-compare 出力**: `tmp/peer-review-20260221-231541/so-output/`

### 3者比較テーブル


| 観点                          | 自分（プラン原案）                         | Codex             | Claude                       | 合意?                                 |
| --------------------------- | --------------------------------- | ----------------- | ---------------------------- | ----------------------------------- |
| esbuild external 戦略         | external: vscode + better-sqlite3 | 妥当                | 妥当                           | ✅                                   |
| .vscodeignore 方式            | ブラックリスト型に変更                       | ホワイトリスト維持を推奨      | 既存ホワイトリスト維持（H1）              | ✅ 修正: ホワイトリスト維持                     |
| --no-dependencies           | 使用                                | 非推奨、危険            | Step 0 で検証必要                 | ✅ 修正: Step 0 で検証、条件分岐               |
| クロスプラットフォームパス               | macOS/Win/Linux                   | 妥当、Cursor公式ソースは困難 | 正確、path.joinで安全              | ✅                                   |
| CLI 配布方式                    | npm link + bin                    | ローカル用途に十分         | 現スコープに十分                     | ✅                                   |
| CLI vs Extension rebuild 衝突 | リスク表に記載                           | パッケージ分離を推奨        | ADR/READMEに明記                | ✅ 修正: リスク表 + ADR に明記                |
| esbuild shebang             | Step 3b で確認                       | 未指摘               | Step 1 に banner 追加（H3）       | ✅ 修正: Step 1 に追加                    |
| Electron バージョン検出            | `ls ~/.cursor/*/cursor`           | 未指摘               | Cursor package.json から（事実誤認） | ✅ 修正: デフォルト値 + 環境変数                 |
| transitive deps (bindings等) | 未検討                               | 欠落リスクを指摘          | 未指摘                          | ✅ 修正: Step 0 に追加                    |
| platform-specific VSIX      | 未検討                               | 強く推奨              | 未指摘                          | ⚠️ 保留: Step 0 で評価、Phase 4 スコープ外の可能性 |
| --allow-star-activation     | サイズ警告の回避策                         | 未指摘               | 誤り（activation events 用）（L2）  | ✅ 修正: 削除                            |


### 事実検証


| 主張                                        | 主張者         | 検証方法                                                    | 結果                                                        |
| ----------------------------------------- | ----------- | ------------------------------------------------------- | --------------------------------------------------------- |
| Cursor package.json に electronVersion がある | Claude (H4) | 実コード実行: `node -e "require(...).electronVersion"`        | **誤り** — `electronVersion` フィールドなし                        |
| `--allow-star-activation` でサイズ警告回避        | 自分          | 公式ドキュメント確認: vsce --help                                 | **誤り** — activation events 用フラグ                           |
| `--no-dependencies` は npm install をスキップ   | Claude (H2) | 実コード実行: `vsce package --help`                           | **確認済み** — "Disable dependency detection via npm or yarn" |
| `Cursor --version` で Electron バージョン取得可能   | -           | 実コード実行                                                  | **誤り** — Node.js バージョン (v22.22.0) を返す                     |
| Phase 2 で Electron 39.4.0 を使用             | エピソード       | ソースコード確認: episodes/2026-02-21-phase2-markdown-export.md | **確認済み**                                                  |


### 判定

- **結果**: 3者合意（上記修正を反映済み）
- **platform-specific VSIX**: Codex のみが推奨。Phase 4 の成功基準には含まれていないため、Step 0 で評価し、必要と判断された場合のみ追加する（保留）
- **パッケージ分離**: Codex が Extension/CLI の分離を推奨。現スコープでは ADR + README での明記で対応し、将来の独立リポジトリ化時に検討（NFR-6 に記載済み）


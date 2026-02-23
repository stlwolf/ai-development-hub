# cursor-thread-tools

Cursorのスレッド（Composer）会話データを抽出・Markdownエクスポートする VS Code 拡張 + CLI ツール。

## ステータス

**Phase 5: 完了** — 出力先変更コマンド + Composer 自動追加 実装済み

## 動機

Cursorの「Export Transcript」はGUI操作（ファイル保存ダイアログ）が必須で、コマンドパレットにも出ない（`f1: false`）。会話ログの保存をワークフローに組み込むには、GUIトリガーなしで動作するツールが必要。

## 機能

| 機能 | 説明 | 状態 |
|------|------|------|
| `threadTools.list` | スレッド一覧表示（名前、メッセージ数、日時） | **Phase 1 完了** |
| `threadTools.export` | 選択スレッドをMarkdownエクスポート | **Phase 2 完了** |
| 自動保存 | バックグラウンドで定期的にスレッドを Markdown 保存 | **Phase 3 完了** |
| CLI | ターミナルからスレッド一覧・エクスポートを実行 | **Phase 3 完了** |
| エクスポートカスタマイズ | thinking/tool_call 出力制御、出力先・ファイル名設定 | **Phase 3 完了** |
| 出力先変更コマンド | フォルダピッカーで outputDir を変更 | **Phase 5 完了** |
| Composer 自動追加 | エクスポート後にファイルを Composer の `@` 参照に追加 | **Phase 5 完了** |

詳細は [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) を参照。

## 技術的根拠

Cursorは `state.vscdb`（SQLite）に会話データを格納。`cursorDiskKV` テーブルから `composerData` → `conversationState`（base64/hex エンコード protobuf）→ `agentKv:blob` → turn/message protobuf を辿り、Cursorの内部API非依存でトランスクリプトを再構成できる。

詳細は [docs/plans/2026-02-20-kickoff-cursor-thread-tools.md](docs/plans/2026-02-20-kickoff-cursor-thread-tools.md) を参照。

## ディレクトリ構成

```
cursor-thread-tools/
├── extension/          # VS Code拡張本体（TypeScript）
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── extension.ts        # activate/deactivate
│       ├── commands/list.ts         # threadTools.list
│       ├── commands/export.ts       # threadTools.export
│       ├── commands/setOutputDir.ts # threadTools.setOutputDir
│       ├── core/threads.ts     # 共有ロジック（VS Code非依存）
│       ├── cli.ts              # CLI エントリポイント
│       ├── proto/decoder.ts    # raw protobuf wire-format パーサー
│       ├── export/markdown.ts  # Markdown 生成
│       └── db/reader.ts        # SQLite read + blob lookup
├── CONVENTIONS.md     # ドキュメント規約（命名規則・フォルダ構成・フロー）
├── docs/
│   ├── REQUIREMENTS.md         # 機能要件・非機能要件
│   ├── VERIFICATION_MATRIX.md  # 検証マトリクス
│   ├── plans/          # 計画・キックオフ（スレッド分化のたびに蓄積）
│   ├── episodes/       # 作業記録・議論経緯
│   ├── decisions/      # 確定した判断（ADR形式）
│   └── raw-logs/       # 生ログ（gitignore対象、一時保管）
├── scripts/            # ビルド・インストールスクリプト
└── README.md
```

## 関連

- [4層モデル](../../ideas/20260220/context-persistence-4layer-model.md) — 本ツールは「層3: 生ログの抽出パイプライン」に位置づけられる
- [CONVENTIONS.md](CONVENTIONS.md) — ドキュメント規約（命名規則・フォルダ構成・フロー）
- [BACKLOG #2](https://github.com/stlwolf/ai-development-hub/issues/2) — 「会話ログ保存の仕組み構築」

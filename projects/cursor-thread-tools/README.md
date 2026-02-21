# cursor-thread-tools

Cursorのスレッド（Composer）会話をMarkdownエクスポートし、スレッドのライフサイクル管理を行うVS Code拡張。

## ステータス

**Phase 2: 完了** — Markdownエクスポート実装済み（protobuf デシリアライズ、conversationState デコード）

## 動機

Cursorの「Export Transcript」はGUI操作（ファイル保存ダイアログ）が必須で、コマンドパレットにも出ない（`f1: false`）。会話ログの保存をワークフローに組み込むには、GUIトリガーなしで動作するツールが必要。

## 機能（計画）

| コマンド | 説明 | Phase |
|---------|------|-------|
| `threadTools.list` | スレッド一覧表示（名前、メッセージ数、日時） | **Phase 1 完了** |
| `threadTools.export` | 選択スレッドをMarkdownエクスポート | **Phase 2 完了** |
| `threadTools.done` | 完了報告を生成し、GitHub Issueにコメント投稿 | Phase 3 |

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
│       ├── commands/list.ts    # threadTools.list
│       ├── commands/export.ts  # threadTools.export
│       ├── proto/decoder.ts    # raw protobuf wire-format パーサー
│       ├── export/markdown.ts  # Markdown 生成
│       └── db/reader.ts        # SQLite read + blob lookup
├── CONVENTIONS.md     # ドキュメント規約（命名規則・フォルダ構成・フロー）
├── docs/
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

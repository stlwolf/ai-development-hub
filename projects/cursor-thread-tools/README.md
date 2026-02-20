# cursor-thread-tools

Cursorのスレッド（Composer）会話をMarkdownエクスポートし、スレッドのライフサイクル管理を行うVS Code拡張。

## ステータス

**Phase 1: 完了** — DB読み取り基盤検証済み（better-sqlite3、agentKv:blob マッピング解明）

## 動機

Cursorの「Export Transcript」はGUI操作（ファイル保存ダイアログ）が必須で、コマンドパレットにも出ない（`f1: false`）。会話ログの保存をワークフローに組み込むには、GUIトリガーなしで動作するツールが必要。

## 機能（計画）

| コマンド | 説明 | Phase |
|---------|------|-------|
| `threadTools.export` | 現在のスレッドをMarkdownエクスポート | Phase 2 |
| `threadTools.done` | 完了報告を生成し、GitHub Issueにコメント投稿 | Phase 3 |
| `threadTools.list` | スレッド一覧表示（名前、メッセージ数、日時） | Phase 2 |

## 技術的根拠

Cursorは `state.vscdb`（SQLite）に会話データを格納。`cursorDiskKV` テーブルから `composerData` → `bubbleId` → メッセージテキストを読み取ることで、Cursorの内部API非依存でトランスクリプトを再構成できる。

詳細は [docs/plans/2026-02-20-kickoff-cursor-thread-tools.md](docs/plans/2026-02-20-kickoff-cursor-thread-tools.md) を参照。

## ディレクトリ構成

```
cursor-thread-tools/
├── extension/          # VS Code拡張本体（TypeScript）
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

AI駆動開発のための統合リポジトリ。Cursor AI向けルール・コマンド、AIエージェント連携ツール、アイデアメモを集約管理。

## コマンド

```bash
# Cursorコマンドを~/.cursor/commands/にシンボリックリンク配置
./scripts/sync-cursor-commands.sh

# agent-verification-flow: API検証ツール
cd projects/agent-verification-flow
./scripts/cognito_auth.sh              # JWT取得（Cognito）
./scripts/api_call.sh GET /api/users   # Bearer Token API呼び出し
./scripts/session_api.sh GET /api/me   # Session Cookie + CSRF API呼び出し
```

## アーキテクチャ

```
ai-development-hub/
├── cursor/                 # Cursor AI エディタ関連
│   ├── command/            # 実行可能なコマンド（~/.cursor/commands/にsymlink可）
│   ├── project-rules/      # プロジェクト固有ルール (.mdc)
│   └── user-rules/         # ユーザー共通ルール
├── projects/               # 独立したツールキット
│   └── agent-verification-flow/  # AI駆動API検証ツール群
├── ideas/                  # アイデア（YYYYMMDD形式のディレクトリ）
├── docs/draft/             # ドラフトドキュメント
└── scripts/                # ユーティリティ
```

## 行動規範（cursor/user-rules/より）

1. **Evidence First**: 根拠は一次情報（公式ドキュメント、RFC、ソースコード、ログ）を優先。推測は明示
2. **CLI Native**: 情報収集はCLI（gh, curl, grep等）を優先
3. **Safe Operations**: 破壊的操作は実行前に停止、コマンドと影響を提示
4. **Minimal Scope**: 依頼範囲のみ対応。「ついで」の変更はしない
5. **Incremental Steps**: 大きな変更は分割し、各ステップで動作確認可能に
6. **Follow Existing Patterns**: 既存コードの規約・構造を踏襲

## Markdown記法

- 箇条書きは `-`（ハイフン）のみ使用（`•` `*` 禁止）
- チェックボックスは `- [ ]` 形式（ハイフン必須）
- インデントは2スペース単位
- コードブロックは言語指定必須
- ファイルパスはインラインコードで囲む

## 入力スタイル

音声入力が多いため、タイポや断片的な指示がある。意図と情報を優先し、曖昧な場合のみ確認。

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

AI駆動開発のための統合リポジトリ。Cursor AI向けルール・コマンド、AIエージェント連携ツール、アイデアメモを集約管理。純粋なBashスクリプトとMarkdownドキュメントで構成（ビルドシステム・パッケージマネージャなし）。

## コマンド

```bash
# Cursor設定をシンボリックリンク配置
./scripts/sync/sync-cursor-commands.sh  # コマンド → ~/.cursor/commands/
./scripts/sync/sync-cursor-skills.sh    # スキル → ~/.cursor/skills/
./scripts/sync/sync-cursor-agents.sh    # エージェント → ~/.cursor/agents/
./scripts/sync/sync-cursor-mcp.sh       # MCP設定 → ~/.cursor/mcp.json

# agent-verification-flow: API検証ツール
cd projects/agent-verification-flow
./scripts/cognito_auth.sh              # JWT取得（Cognito）
./scripts/api_call.sh GET /api/users   # Bearer Token API呼び出し
./scripts/session_api.sh GET /api/me   # Session Cookie + CSRF API呼び出し

# claude-safe: Cursor統合ターミナルからClaude CLIを安全に実行
./projects/claude-safe/claude-safe -p "prompt" --output-format text
DEBUG=1 ./projects/claude-safe/claude-safe -p "test"  # デバッグモード

# second-opinion-verification: タイムアウト付きclaude-safe
CLAUDE_TIMEOUT=60 ./projects/second-opinion-verification/src/claude-safe-with-timeout -p "prompt"
```

## アーキテクチャ

```
ai-development-hub/
├── cursor/                 # Cursor AI エディタ関連
│   ├── command/review/     # PRレビュー・Copilotレビュー対応コマンド
│   ├── mcp.json            # MCP設定（~/.cursor/mcp.json にリンク）
│   ├── skill/              # スキル定義（~/.cursor/skills/ にリンク）
│   ├── project-rules/      # プロジェクト固有ルール (.mdc, alwaysApply)
│   └── user-rules/         # ユーザー共通ルール（行動規範・入力・Markdown）
├── projects/               # 独立したツールキット（ideas/から昇格）
│   ├── agent-verification-flow/  # AI駆動API検証（JWT/Session対応、curl+jq）
│   ├── claude-safe/              # Claude CLIラッパー（nohupでTTY競合回避）
│   └── second-opinion-verification/  # セカンドオピニオン検証（タイムアウト付き）
├── ideas/                  # アイデア（YYYYMMDD形式、凍結スナップショット）
├── docs/draft/             # ドラフトドキュメント
└── scripts/                # ユーティリティ
    └── sync/               # Cursor設定の同期スクリプト
```

### projects/ の設計

- 各プロジェクトは独立して動作するBashツールキット
- `agent-verification-flow`: `config.yaml`（`config.yaml.example`からコピー）で設定。`.token`/`.session`は`.gitignore`対象
- `claude-safe`: `nohup`でプロセス分離し、Cursor Agentのハング問題を解決
- `second-opinion-verification`: `claude-safe`にwatchdogパターンのタイムアウトを追加。ADR・エピソード形式のドキュメント規約あり（`docs/DOCUMENT_CONVENTION.md`）

### ideas/ の規約

- `YYYYMMDD/` ディレクトリで日付管理
- 追加後は凍結（frozen snapshot）、上書き禁止
- 成功したアイデアは `projects/` に昇格
- `discussion-logs/` にマルチAIブレスト記録を保存可

## 行動規範（cursor/user-rules/より）

1. **Evidence First**: 根拠は一次情報（公式ドキュメント、RFC、ソースコード、ログ）を優先。推測は明示
2. **CLI Native**: 情報収集はCLI（gh, curl, grep等）を優先
3. **Safe Operations**: 破壊的操作は実行前に停止、コマンドと影響を提示
4. **Minimal Scope**: 依頼範囲のみ対応。「ついで」の変更はしない
5. **Incremental Steps**: 大きな変更は分割し、各ステップで動作確認可能に
6. **Follow Existing Patterns**: 既存コードの規約・構造を踏襲

## コミット規約

- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`（スコープ付き可: `feat(verification): ...`）
- 1コミット1論理変更

## コード品質

- シェルスクリプト変更時は `shellcheck <script>` を実行して確認

## Markdown記法

- 箇条書きは `-`（ハイフン）のみ使用（`•` `*` 禁止）
- チェックボックスは `- [ ]` 形式（ハイフン必須）
- インデントは2スペース単位
- コードブロックは言語指定必須
- ファイルパスはインラインコードで囲む

## 入力スタイル

音声入力が多いため、タイポや断片的な指示がある。意図と情報を優先し、曖昧な場合のみ確認。

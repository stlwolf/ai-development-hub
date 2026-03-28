# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

AI駆動開発のための統合リポジトリ。複数AIツール（Cursor / Claude Code / Codex）共通のルール・スキル・エージェント・コマンドと、各ツール連携プロジェクトを集約管理。純粋なBashスクリプトとMarkdownドキュメントで構成（ビルドシステム・パッケージマネージャなし）。

## コマンド

```bash
# 全ツールへ一括 sync（canonical/ → ~/.cursor/, ~/.claude/, ~/.codex/, ~/bin/）
./scripts/sync.sh                      # 全ターゲット実行
./scripts/sync.sh cursor               # Cursor のみ
./scripts/sync.sh claude codex         # 複数指定
./scripts/sync.sh --list               # 利用可能ターゲット一覧

# 個別 sync スクリプト
./scripts/sync/sync-cursor.sh          # canonical + cursor-specific → ~/.cursor/
./scripts/sync/sync-claude.sh          # canonical → ~/.claude/
./scripts/sync/sync-codex.sh           # canonical → ~/.codex/
./scripts/sync/sync-bin.sh             # so-compare, arena-compare → ~/bin/

# agent-verification-flow: API検証ツール
cd projects/agent-verification-flow
./scripts/cognito_auth.sh              # JWT取得（Cognito）
./scripts/api_call.sh GET /api/users   # Bearer Token API呼び出し
./scripts/session_api.sh GET /api/me   # Session Cookie + CSRF API呼び出し

# so-compare: セカンドオピニオン（Codex + Claude）
so-compare -w "$(pwd)" "プロンプト"              # 推奨: -w でワークスペース参照
so-compare -w "$(pwd)" "プロンプト" --codex-only  # Codex のみ

# arena-compare: マルチモデル並列比較（Cursor CLI）
arena-compare -w "$(pwd)" "プロンプト"            # デフォルト3モデル
arena-compare --resume-from tmp/arena-XXXXXXXX "追加質問"  # セッション継続

# claude-safe: Cursor統合ターミナルからClaude CLIを安全に実行
./projects/claude-safe/claude-safe -p "prompt" --output-format text
DEBUG=1 ./projects/claude-safe/claude-safe -p "test"  # デバッグモード

# second-opinion-verification: タイムアウト付きclaude-safe
CLAUDE_TIMEOUT=60 ./projects/second-opinion-verification/src/claude-safe-with-timeout -p "prompt"
```

## アーキテクチャ

```
ai-development-hub/
├── canonical/              # ツール非依存の正本 + ツール固有拡張
│   ├── rules/              # ユーザー共通ルール（行動規範・入力・出力等）
│   ├── skills/             # スキル定義（各ディレクトリに SKILL.md）
│   ├── agents/             # エージェント定義
│   ├── commands/           # コマンド（review/, investigation/, verification/）
│   ├── mcp/                # MCP設定（cursor.json → ~/.cursor/mcp.json にリンク）
│   ├── cursor/             # Cursor 固有ファイル（archive-title 等）
│   └── codex/              # Codex 固有ファイル（AGENTS.md, commands-registry 等）
├── projects/               # 独立したツールキット（ideas/から昇格）
│   ├── agent-verification-flow/  # AI駆動API検証（JWT/Session対応、curl+jq）
│   ├── arena-compare/            # マルチモデル並列比較（Cursor CLI）
│   ├── claude-safe/              # Claude CLIラッパー（nohupでTTY競合回避）
│   └── second-opinion-verification/  # セカンドオピニオン検証（タイムアウト付き）
├── ideas/                  # アイデア（YYYYMMDD形式、凍結スナップショット）
├── docs/draft/             # ドラフトドキュメント
└── scripts/                # ユーティリティ
    ├── sync.sh             # 統合 sync ランナー
    └── sync/               # 個別 sync スクリプト（cursor, claude, codex, bin）
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

## 行動規範（canonical/rules/より）

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

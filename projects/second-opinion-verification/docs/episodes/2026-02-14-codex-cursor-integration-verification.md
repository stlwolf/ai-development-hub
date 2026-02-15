---
title: "Codex CLI × Cursor統合ターミナル 連携検証"
date: 2026-02-14
type: report
participants:
  - Eddy
  - Cursor Agent (Claude, Primary)
  - Codex CLI (gpt-5.3-codex, 検証対象)
related:
  - type: depends_on
    ref: ../plans/codex-cli-verification-prompt.md
    reason: "検証プロンプトに基づく実施"
tags: [codex, cursor, integration, verification, cli]
keywords: [codex-cli, gpt-5.3-codex, exec, resume, AGENTS.md, sandbox, JSONL]
use_when:
  - "Codex CLIをCursor統合ターミナルから使うとき"
  - "CodexとCursor連携の基本動作を確認したいとき"
  - "codex execの非インタラクティブ実行方法を調べるとき"
  - "Codexのセッション管理を知りたいとき"
---

# Codex CLI × Cursor統合ターミナル 連携検証

## 概要

`codex-cli-verification-prompt_update.md` のStep 1（基本動作確認）とStep 4（Cursor連携）を実施。Codex CLIがCursor統合ターミナルから安定して非インタラクティブ実行できるかを検証した。

## 検証環境

- macOS / Cursor統合ターミナル
- Codex CLI v0.101.0（Homebrew: `/opt/homebrew/bin/codex`）
- モデル: gpt-5.3-codex（config.toml設定）
- 対象リポジトリ: `ai-development-hub`（trust_level: trusted）

## 検証結果

### Step 1-1: インストール確認

| 項目 | 結果 |
|------|------|
| バージョン | codex-cli 0.101.0 |
| インストールパス | `/opt/homebrew/bin/codex` |
| モデル | gpt-5.3-codex（ドキュメントの5.2ベースからアップグレード済み） |
| 設定ファイル | `~/.codex/config.toml` |

`config.toml` の主要設定:

```toml
model = "gpt-5.3-codex"
model_reasoning_effort = "medium"
personality = "pragmatic"
web_search = "live"

[shell_environment_policy]
inherit = "all"
ignore_default_excludes = true

[projects."/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub"]
trust_level = "trusted"
```

### Step 1-3: 非インタラクティブモード（codex exec）

**結論: Cursor統合ターミナルから安定動作。claude-safeのTTY問題は再現しない。**

| テスト | 実行時間 | 結果 |
|--------|----------|------|
| シンプルなecho | 約11.6秒 | 正常 |
| リポジトリ構造説明（read-only） | 約6秒 | 正常 |
| JSON出力 | 約9.8秒 | JSONL形式で正常出力 |
| AGENTS.md認識テスト | 約13秒 | 正常 |
| セッション継続 | 約5.9秒 | 正常 |

**確認ポイント:**

- stdout に最終メッセージがクリーンに出力される
- stderr にプログレス情報（session id, sandbox設定等）が出る
- Cursor統合ターミナルでハングしない（nohup不要）
- `shell_snapshot` の構文エラーが毎回出るが、動作に影響なし

**shell_snapshot エラー（既知の問題）:**

```
codex_core::shell_snapshot: Shell snapshot validation failed:
Snapshot command exited with status exit status: 2:
/Users/eddy/.codex/shell_snapshots/...sh: 行 21644: 予期しないトークン `(' 周辺に構文エラーがあります
```

これはシェル環境のスナップショット取得時のエラーで、bash設定ファイルの複雑さに起因する可能性がある。機能への影響はなし。

### Step 4-1: AGENTS.md の認識

**結論: Codexは `AGENTS.md` をプロジェクトコンテキストとして自動読み込みしている。**

**根拠:**

1. `codex exec -s read-only "このリポジトリのディレクトリ構造を簡潔に説明して"` → コマンド実行なしで正確にAGENTS.md記載の構造を回答
2. 明示的に「AGENTS.mdを読んでいるか」と問うと、`cat AGENTS.md` を実行して確認し、内容に基づいて回答

これはClaude Codeが `CLAUDE.md` を自動読み込みするのと同様の仕組み。config.tomlで `trust_level = "trusted"` 設定されたプロジェクトでは、AGENTS.mdがシステムコンテキストとして注入される。

### Step 4-2: セッション管理

**結論: `codex exec resume --last` で非インタラクティブにセッション継続が可能。**

| 項目 | Claude Code (`-c`) | Codex (`resume`) |
|------|---------------------|-------------------|
| セッション指定 | `-c` フラグ | `--last` または SESSION_ID（UUID） |
| 保存場所 | 不明 | `~/.codex/sessions/YYYY/MM/DD/*.jsonl` |
| 一覧表示 | なし | `codex resume --all`（TUI、インタラクティブのみ） |
| 非インタラクティブ継続 | `claude-safe -c` | `codex exec resume --last "prompt"` |
| フォーマット | 不明 | JSONL（セッションごとに1ファイル） |

**重要: ドキュメントの `codex resume --list` は存在しない。** 実際は `--all` でTUIピッカーが起動する（インタラクティブモードのみ）。

### JSON出力（パイプライン連携）

`codex exec --json` のイベントフロー:

```
thread.started → turn.started → item.completed (reasoning) →
item.completed (agent_message) → item.started (command_execution) →
item.completed (command_execution) → ... → turn.completed (usage)
```

`turn.completed` にトークン使用量が含まれる:

```json
{"type":"turn.completed","usage":{"input_tokens":18536,"cached_input_tokens":15232,"output_tokens":379}}
```

## ドキュメントとの差異

検証プロンプト（`codex-cli-verification-prompt_update.md`）との差異:

| 項目 | ドキュメント記載 | 実際 |
|------|------------------|------|
| ベースモデル | GPT-5.2 | gpt-5.3-codex |
| exec デフォルトsandbox | read-only | workspace-write |
| sandbox指定オプション | `--sandbox` | `-s` / `--sandbox` 両方可 |
| セッション一覧 | `codex resume --list` | 存在しない（`--all` はTUIのみ） |
| `codex login --status` | 記載あり | 未検証（`~/.codex/auth.json` で管理） |

## 成功基準の判定

- [x] Cursor統合ターミナルから `codex exec` が安定動作する
- [x] 非インタラクティブモードの出力が stdout にクリーンに出る
- [x] claude-safe と同一プロンプトで比較可能なレビュー結果が得られる → [Sentry修正検証](2026-02-14-sentry-fix-codex-second-opinion.md) で実証
- [x] JSON出力がパイプラインで扱える
- [x] セカンドオピニオンとしての反証品質が確認できる → `floor()` 判定で Codex が Claude の誤りを検出

## 次のアクション

- `shell_snapshot` エラーの原因調査（優先度低）
- セカンドオピニオン検証フレームワークの標準化（深度レベル定義、プロンプトテンプレート）
- 3エージェント深掘り検証（1つのエラーユースケースのデータフロー追跡）

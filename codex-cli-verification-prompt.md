# Codex CLI 基本検証プロンプト

## 背景

Codex CLI（GPT-5.2ベース）をインストール済み。Cursor統合ターミナルからclaude-safeと同様にセカンドオピニオンツールとして使えるかを検証する。

## 検証の目的

1. Codex CLIの基本機能を把握する
2. Cursor統合ターミナルからの非インタラクティブ実行が安定するか確認する
3. claude-safe（Claude Code CLI）との操作感・出力形式の違いを把握する

## 検証環境

- macOS / Cursor統合ターミナル
- Codex CLI（dotfilesからインストール済み）
- 比較対象: claude-safe（Claude Code CLI ラッパー）

---

## Step 1: 基本動作確認

### 1-1. インストール確認

```bash
# バージョン確認
codex --version

# 認証状態
codex login --status  # or similar auth check

# ヘルプ
codex --help
codex exec --help
```

### 1-2. インタラクティブモード（素振り）

```bash
# TUIが起動するか確認（Ctrl+C で抜ける）
codex
```

- Cursor統合ターミナルでTUIが正常に描画されるか
- claude のインタラクティブモードとの違い

### 1-3. 非インタラクティブモード（本命）

```bash
# 最もシンプルな実行
codex exec "echo hello world"

# 読み取り専用で質問（デフォルト: read-only sandbox）
codex exec "このリポジトリの構造を説明して"

# workspace-write 許可
codex exec --full-auto "このリポジトリの構造を説明して"
```

確認ポイント:
- stdout に最終メッセージが出るか
- stderr にプログレスが出るか
- 実行時間はどのくらいか
- Cursor統合ターミナルでハングしないか（claude-safe の TTY問題の再現有無）

---

## Step 2: claude-safe との比較

### 2-1. 同一プロンプトでの出力比較

同じ質問を両方に投げて、出力形式・品質・速度を比較する。

```bash
# Claude Code（claude-safe 経由）
claude-safe -p "projects/second-opinion-verification/src/claude-safe-with-timeout のコードをレビューして。安全性の観点で問題があれば指摘して"

# Codex（exec モード）
codex exec "projects/second-opinion-verification/src/claude-safe-with-timeout のコードをレビューして。安全性の観点で問題があれば指摘して"
```

比較ポイント:
- 指摘の数と質
- 実行時間
- 出力形式（テキスト / 構造化）
- ツール利用（ファイル読み取り等）の自動実行有無

### 2-2. JSON出力の確認

```bash
# Codex の JSON Lines 出力
codex exec --json "このリポジトリの主要ファイルを3つ挙げて"

# パイプで使えるか
codex exec --json "このリポジトリの主要ファイルを3つ挙げて" 2>/dev/null | jq '.'
```

claude-safe の出力と比較して、パイプライン連携のしやすさを確認。

---

## Step 3: セカンドオピニオン適性の検証

### 3-1. 反証依頼

```bash
codex exec "以下のシェルスクリプトの設計について反証してください。見落とし・破壊的変更のリスク・将来負債・代替案を指摘してください。$(cat projects/second-opinion-verification/src/claude-safe-with-timeout)"
```

- Claude Code の反証と比較して、視点の違いがあるか
- 指摘の具体性と正確性

### 3-2. sandbox モード別の挙動

```bash
# read-only（デフォルト）: ファイル読み取りのみ
codex exec "projects/second-opinion-verification/docs/decisions/ADR-001-shell-timeout-pattern.md を読んで要約して"

# workspace-write: ファイル変更可能
codex exec --sandbox workspace-write "README.md のtypoを探して修正案を出して（実際には変更しないで）"

# full-auto: 承認なし + workspace-write
codex exec --full-auto "このプロジェクトの docs/ 配下のファイル一覧を取得して"
```

確認ポイント:
- read-only で本当にファイル変更がブロックされるか
- claude-safe の --dangerously-skip-permissions との対比
- sandbox が claude-safe の TTY/承認問題を回避できるか

---

## Step 4: Cursor連携の確認

### 4-1. AGENTS.md の認識

Codex は `AGENTS.md` をプロジェクトコンテキストとして読む。

```bash
# AGENTS.md がない状態で実行
codex exec "このプロジェクトの目的は？"

# AGENTS.md を置いた状態で実行（同じ質問）
# → 回答の精度が変わるか確認
```

### 4-2. セッション継続

```bash
# セッション一覧
codex resume --list

# 前回セッションの継続
codex resume
```

claude-safe では `-c` でセッション継続していた。Codex のセッション管理はどう違うか。

---

## 記録フォーマット

検証結果は以下に記録:

`projects/second-opinion-verification/docs/episodes/YYYY-MM-DD-codex-cli-verification.md`

DOCUMENT_CONVENTION v0 に沿ったFrontmatterを付与:

```yaml
---
title: "Codex CLI 基本検証"
date: YYYY-MM-DD
type: report
participants:
  - Eddy
  - Codex CLI
  - Claude Code (比較対象)
tags: [codex, cli, verification, comparison]
use_when:
  - "Codex CLI を初めて使うとき"
  - "Claude Code と Codex の違いを確認したいとき"
---
```

---

## 成功基準

- [ ] Cursor統合ターミナルから `codex exec` が安定動作する
- [ ] 非インタラクティブモードの出力が stdout にクリーンに出る
- [ ] claude-safe と同一プロンプトで比較可能なレビュー結果が得られる
- [ ] JSON出力がパイプラインで扱える
- [ ] セカンドオピニオンとしての反証品質が確認できる

# AI Agent Orchestration - CLI連携の可能性

## 概要

Claude Code と Cursor Agent のCLI非インタラクティブモードを使った双方向通信が確立できた。
これにより、複数のAIエージェントを連携させたオーケストレーションの基盤ができた。

## 確認できたこと

### 1. 双方向CLI通信

```bash
# Claude Code → Cursor Agent
cursor agent -p "タスク内容" \
  --workspace /path/to/project \
  --output-format json

# Cursor Agent → Claude Code
claude -p "タスク内容" \
  --output-format json
```

### 2. 利用可能なモデル（2024-02時点）

| ツール | 利用可能モデル |
|--------|---------------|
| Cursor Agent | GPT-5.2, Claude 4.5 Opus/Sonnet (Thinking), Gemini 3, Grok |
| Claude Code | Claude Opus 4.5, Sonnet, Haiku |
| Codex (予定) | GPT系 |

### 3. 出力フォーマット

両者ともJSON出力をサポート：

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "duration_ms": 7787,
  "result": "回答テキスト",
  "session_id": "uuid-for-resume"
}
```

`session_id` でセッション再開も可能。

## オーケストレーションの可能性

### パターン1: シンプルなパイプライン

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ Claude Code  │ ───► │ Cursor Agent │ ───► │    Codex     │
│  (分析/計画) │      │  (実装)      │      │  (レビュー)  │
└──────────────┘      └──────────────┘      └──────────────┘
```

### パターン2: 並列実行 + 統合

```
                    ┌──────────────┐
                ┌──►│ Cursor Agent │───┐
                │   │  (GPT-5.2)   │   │
┌──────────────┐│   └──────────────┘   │   ┌──────────────┐
│  Dispatcher  │┤                      ├──►│  Aggregator  │
│ (Claude Code)│┤   ┌──────────────┐   │   │ (Claude Code)│
└──────────────┘│   │ Cursor Agent │   │   └──────────────┘
                └──►│  (Sonnet)    │───┘
                    └──────────────┘
```

### パターン3: 専門家チーム

```bash
# 例: 複数の専門エージェントに並列で問い合わせ
cursor agent -p "セキュリティ観点でレビュー" --model gpt-5.2 &
cursor agent -p "パフォーマンス観点でレビュー" --model sonnet-4.5 &
claude -p "アーキテクチャ観点でレビュー" &
wait
# 結果を統合
```

## 実装アプローチ

### ライトウェイト（シェルスクリプト）

フレームワークなしでも十分機能する：

```bash
#!/usr/bin/env bash
set -euo pipefail

# 並列実行して結果を集約
task="$1"
results_dir=$(mktemp -d)

# 各エージェントに並列で依頼
cursor agent -p "$task" --output-format json > "$results_dir/cursor.json" &
claude -p "$task" --output-format json > "$results_dir/claude.json" &
wait

# 結果を統合（Claude Codeに依頼）
claude -p "以下の2つの回答を統合して最終回答を作成:
$(cat "$results_dir/cursor.json")
$(cat "$results_dir/claude.json")"
```

### ミドルウェイト（Node.js/Python スクリプト）

JSON処理、エラーハンドリング、リトライなどを追加：

```javascript
// orchestrator.js
const { execSync } = require('child_process');

async function askAgent(agent, prompt, options = {}) {
  const cmd = agent === 'cursor'
    ? `cursor agent -p "${prompt}" --output-format json`
    : `claude -p "${prompt}" --output-format json`;

  const result = execSync(cmd, { encoding: 'utf8' });
  return JSON.parse(result);
}

async function parallelReview(code) {
  const [security, perf, arch] = await Promise.all([
    askAgent('cursor', `セキュリティレビュー: ${code}`, { model: 'gpt-5.2' }),
    askAgent('cursor', `パフォーマンスレビュー: ${code}`, { model: 'sonnet-4.5' }),
    askAgent('claude', `アーキテクチャレビュー: ${code}`)
  ]);

  return { security, perf, arch };
}
```

### ヘビーウェイト（フレームワーク利用）

既存のマルチエージェントフレームワーク：

| フレームワーク | 特徴 |
|---------------|------|
| LangGraph | グラフベースのワークフロー定義 |
| CrewAI | 役割ベースのエージェントチーム |
| AutoGen | Microsoft製、会話ベース |
| Mastra | MCP統合が強い |

これらに CLI エージェントをツールとして組み込むことも可能。

## 現実的な次のステップ

### Phase 1: シェルスクリプトで実験

```bash
# bin/ai-orchestra を作成
# - 複数エージェントへの並列問い合わせ
# - 結果のJSON統合
# - シンプルな投票/マージ機構
```

### Phase 2: ユースケース特化

```bash
# bin/ai-review - コードレビュー（複数視点統合）
# bin/ai-refactor - リファクタ提案（複数案比較）
# bin/ai-debug - デバッグ（複数エージェントで原因特定）
```

### Phase 3: 必要に応じてフレームワーク導入

複雑なワークフロー（条件分岐、ループ、状態管理）が必要になったら検討。

## Cursor統合ターミナルからの連携（claude-safe）

### 問題

Cursor/VS Code統合ターミナルでClaude CLIを直接実行すると競合が発生する：

- プロセスがハングする
- 出力が返ってこない
- `TERM=dumb`, `not a tty` 環境

原因: [GitHub Issue #11707](https://github.com/anthropics/claude-code/issues/11707) - VS Code terminal と Claude CLI の競合

### 解決策: claude-safe ラッパー

`nohup`でプロセス分離して競合を回避：

```bash
#!/bin/bash
# bin/claude-safe
nohup claude "$@" > "$OUTPUT_FILE" 2> "$ERROR_FILE" &
wait $!
cat "$OUTPUT_FILE"
```

### 使い方

```bash
# Cursor統合ターミナルから安全にClaude CLIを実行
claude-safe -c -p "レビューしてください" --output-format text

# 疑似オーケストレーション: CursorからClaude Codeにタスク委譲
claude-safe -c -p "@file.md を読んでレビューして"
```

詳細: [docs/claude-safe.md](./claude-safe.md)

---

## マルチエージェントフレームワークとの比較

### 本質的にやっていること（共通）

```
┌─────────────────────────────────────────────────────────┐
│                    共通パターン                          │
├─────────────────────────────────────────────────────────┤
│  1. タスク分割      → 複雑な問題を小さく分ける           │
│  2. 専門化         → 各エージェントに特化した役割        │
│  3. コンテキスト分離 → 各エージェントが独自の視野を持つ   │
│  4. 結果統合        → 親が判断・調整                    │
└─────────────────────────────────────────────────────────┘
```

### なぜマルチエージェントが効くのか

1. **コンテキスト圧縮**: 1エージェントが全部見るより、分担した方が精度高い
2. **専門性**: 「レビュー専門」「テスト専門」など役割特化
3. **セカンドオピニオン**: 異なるモデル/視点で検証ループ
4. **並列化**: 独立タスクは同時実行可能

### 実装方式の比較

| 観点 | CLI連携 | OSSフレームワーク | プラットフォーム内蔵 |
|------|---------|-----------------|-------------------|
| **例** | claude-safe + cursor agent | LangGraph, CrewAI, AutoGen | Cursor Subagents |
| **統合度** | 低（プロセス分離） | 高（同一プロセス） | 高（自動） |
| **柔軟性** | 高（異種サービス横断） | 中（フレームワーク依存） | 低（プラットフォーム内） |
| **セットアップ** | スクリプト | コード書く | 設定のみ |
| **デバッグ** | 各CLI単体でテスト可 | 複雑 | ブラックボックス |
| **モデル多様性** | 高（何でも繋げる） | 中（対応APIに依存） | 中（サービス内モデル） |

### 主要OSSフレームワーク

| フレームワーク | 特徴 | 適したユースケース |
|---------------|------|------------------|
| **LangGraph** | グラフベースのワークフロー定義、状態管理 | 複雑な条件分岐、ループ処理 |
| **CrewAI** | 役割ベースのエージェントチーム | チームシミュレーション |
| **AutoGen** | Microsoft製、会話ベース協調 | 対話的なタスク解決 |
| **Mastra** | MCP統合が強い、TypeScript | MCP重視のワークフロー |
| **Agency Swarm** | OpenAI Assistants API特化 | OpenAIエコシステム内 |

### CLI連携の強み（フレームワークにない利点）

1. **異種サービス横断**: Claude + Cursor + Codex + 任意のCLIツール
2. **既存認証の活用**: 各サービスの認証をそのまま使える
3. **段階的導入**: フレームワーク学習コストなし
4. **デバッグ容易**: 各コマンドを単体でテスト可能
5. **シェルエコシステム**: パイプ、リダイレクト、並列実行

### CLI連携の弱み

1. **状態管理**: 複雑な状態遷移は自前実装が必要
2. **エラーハンドリング**: フレームワークほど洗練されていない
3. **可観測性**: ログ、トレース、メトリクスは自前
4. **型安全性**: JSON解析は手動

### どちらを選ぶか

```
┌─────────────────────────────────────────────────────────┐
│ CLI連携が適している場合                                  │
├─────────────────────────────────────────────────────────┤
│ - シンプルなパイプライン（A → B → C）                    │
│ - 異種サービスを組み合わせたい                           │
│ - 既存のシェルワークフローに組み込みたい                  │
│ - フレームワーク学習コストを避けたい                      │
│ - プロトタイピング、実験段階                             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ フレームワークが適している場合                            │
├─────────────────────────────────────────────────────────┤
│ - 複雑な条件分岐、ループ、状態管理が必要                  │
│ - 本番環境での信頼性が必要                               │
│ - チームで開発、メンテナンスする                         │
│ - 可観測性（ログ、トレース）が重要                       │
│ - 同一言語エコシステム内で完結させたい                    │
└─────────────────────────────────────────────────────────┘
```

### ハイブリッドアプローチ

フレームワーク内でCLIエージェントをツールとして使うことも可能：

```python
# LangGraph + CLI連携の例
from langgraph.prebuilt import create_react_agent
import subprocess

def call_cursor_agent(prompt: str) -> str:
    """Cursor Agentに問い合わせるツール"""
    result = subprocess.run(
        ["cursor", "agent", "-p", prompt, "--output-format", "text"],
        capture_output=True, text=True
    )
    return result.stdout

# LangGraphのエージェントにCursor Agentをツールとして追加
agent = create_react_agent(model, tools=[call_cursor_agent])
```

---

## 注意点

1. **コスト**: 並列実行はAPI呼び出しが増える
2. **レート制限**: 各サービスのrate limitに注意
3. **一貫性**: 異なるモデルの回答をどうマージするか
4. **認証**: 各CLIの認証状態の管理
5. **ターミナル環境**: Cursor統合ターミナルではclaude-safeラッパーが必要

## 関連コマンドリファレンス

```bash
# Claude Code
claude -p "prompt" --output-format json
claude -p "prompt" --continue  # セッション継続

# Cursor Agent
cursor agent -p "prompt" --output-format json --workspace /path
cursor agent -p "prompt" --model sonnet-4.5  # モデル指定
cursor agent -p "prompt" --resume <session_id>  # セッション再開

# Codex (TBD)
codex -p "prompt" --output-format json
```

---

## 各エージェントの視点・出力比較

このドキュメントは複数のエージェントが連携して作成された。以下に各エージェントの出力を明記する。

### 🔵 Cursor Agent (Claude Opus 4.5) の出力

Cursor統合ターミナル内で動作。主にコード実装とドキュメント作成を担当。

#### git-cleanup-merged の実装について

> worktree使用中のブランチも削除対象に含め、worktree→ブランチの順で削除する方式を採用。
> これにより1コマンドでマージ済みブランチのクリーンアップが完結する。
> 
> **設計判断:**
> - スキップではなく削除対象に含める（ユーザーの手間を減らす）
> - 削除前に確認プロンプトで安全性を担保
> - worktreeパスを表示してユーザーに削除対象を明示

#### マルチエージェントの本質について

> 本質的にはOSSフレームワークもCLI連携も同じことをやっている：
> 1. タスクの分割
> 2. 専門化されたエージェントへの委譲
> 3. コンテキストの分離/圧縮
> 4. 結果の統合
>
> CLI連携は「貧者のマルチエージェント」だが、異種サービスを横断できる強みがある。
> フレームワークを使うか、CLI経由でやるかは実装の詳細の違いでしかない。

#### claude-safe ラッパーについて

> `nohup`でプロセス分離することで、Cursor統合ターミナルからでもClaude CLIを実行できる。
> これは既知の問題（Issue #11707）の回避策であり、疑似オーケストレーションを実現する基盤となる。

---

### 🟠 Claude Code (Opus 4.5) の出力

外部ターミナルまたはclaude-safe経由で実行。レビューと連携検証を担当。

#### git-cleanup-merged のレビュー結果

> **レビュー観点別評価:**
> 
> | 観点 | 評価 |
> |------|------|
> | ロジックの正確性 | ✓ OK - worktree→ブランチの順序は正しい |
> | エラーハンドリング | ✓ OK - worktree削除失敗時にスキップ |
> | 安全性 | ✓ OK - 確認プロンプト、保護ブランチ除外 |
> | コードスタイル | △ - `echo \| grep`パターン（任意修正） |
> | エッジケース | △ - bash 4.4未満で空配列問題の可能性 |
>
> **結論: 実用上問題なし。マージ可能。**
> bash 4.4未満のサポートが必要なら空配列チェックを追加してください。

#### CLI連携の可能性について

> 双方向CLI通信が確立できた。これにより：
> - Claude Code → Cursor Agent へのタスク委譲
> - 異なるモデルの組み合わせ（GPT-5, Sonnet, Gemini等）
> - 並列実行による複数視点からのレビュー
>
> フレームワークなしでも、シェルスクリプト + JSON でかなりのことができる。

#### セッション管理について

> デフォルトでは各ターミナルで別セッションになる（コンテキスト共有されない）。
> `--continue` または `--resume` で同じセッションを再開可能。
> 同じセッションを複数ターミナルで開くとメッセージがinterleaved（混在）になる。

---

### 比較: 同じ質問に対する回答の違い

#### Q: 「マルチエージェントフレームワークとCLI連携の違いは？」

**🔵 Cursor Agent:**
> 実装方法の違いでしかない。CLI連携はプロトタイピングに適しており、
> フレームワークは複雑な状態管理が必要な場合に使う。
> 段階的に始めて必要に応じて複雑化するのが現実的。

**🟠 Claude Code:**
> シェルスクリプト + JSON で十分機能する。
> ライトウェイトに始めて、必要に応じてミドルウェイト（Node.js/Python）、
> ヘビーウェイト（フレームワーク）へ移行するアプローチを推奨。

**共通点:** 段階的アプローチを推奨、フレームワークは必要になってから
**差異:** Cursorは比較軸を整理、Claude Codeは具体的な実装例を提示

---

### ⚪ Gemini (Pro 1.5) の視点・提言

外部オブザーバーとして、システム設計と「AIの認知特性」の観点からこのCLI連携モデルを評価する。

#### 1. 「認知的多様性（Cognitive Diversity）」の強制

フレームワークを用いず、CLIでプロセスを物理的に分離するアプローチは、**AIのハルシネーション対策として最強の構成**である。

- **単一モデルの弱点:** 同一プロセス内で「実装」と「レビュー」を行うと、自身の生成したコードのバイアス（思い込み）を引きずりやすい。
- **CLI連携の強み:** プロセスが切れ、モデルも切り替わる（Cursor/GPT → Claude）ことで、**「他人の目」効果**が強制的に働く。
  - **Cursor Agent**: 「手」が早い実装者（直感的・多動的）
  - **Claude Code**: 「頭」を使う監査役（論理的・慎重）
  - **CLIパイプライン**: この2つを混ぜないための「壁」として機能する。

#### 2. コンテキスト・エンベロープ（Context Envelope）の提案

Unixパイプライン（`A | B | C`）の最大の弱点は、工程が進むにつれて「当初の目的（Original Intent）」が希薄化することである。
これを防ぐため、単なるテキストではなく、**「意図」と「成果物」を包んだJSON（エンベロープ）**をバケツリレーさせる設計を提言する。

**推奨するJSON構造:**

```json
{
  "meta": {
    "original_intent": "不変の目的（例: N+1問題の解消）",
    "constraints": "制約条件（例: Raw SQL禁止）",
    "trajectory": [
      "step1: Cursorが修正案を作成",
      "step2: Claudeが型エラーを指摘",
      "step3: Cursorが修正"
    ]
  },
  "payload": {
    "current_file_content": "...",
    "diff": "..."
  }
}
```

- **Immutable Context**: `original_intent` は最後まで変更しない。
- **Mutable Context**: `trajectory` に各エージェントが「何をしたか」を追記していく。
- **Payload**: 次の工程に必要な実データ。

これにより、ステートレスなCLI連携であっても文脈を維持し、**「なぜその修正が必要だったか」という文脈**を最終工程まで運び込むことができる。

#### 3. 「関数型AIアーキテクチャ」への進化

このCLI連携は、スクリプトというより**「関数型プログラミング」**に近い。

- **可観測性（Observability）**: フレームワークの内部状態（ブラックボックス）に頼らず、中間生成される `step1.json`, `step2.json` を見るだけでデバッグが可能。
- **再現性**: 入力JSONが同じなら、エージェントは（確率的な揺らぎを除けば）同じ文脈で動作する。

**結論:**
> このアプローチは「貧者のマルチエージェント」ではなく、**「構成可能性（Composability）を最大化した、最もUnix的なAIオーケストレーション」**である。まずはシェルスクリプトと`jq`で「コンテキスト・エンベロープ」の実装から始めるべきである。

---

## まとめ

フレームワークなしでも、シェルスクリプト + JSON でかなりのことができる。
まずはライトウェイトに始めて、必要に応じて複雑化していくのが現実的。

**各エージェントの役割分担:**
- 🔵 **Cursor Agent**: IDE統合、コード実装、リアルタイム編集
- 🟠 **Claude Code**: 外部レビュー、セカンドオピニオン、独立した検証
- ⚪ **Gemini**: システム設計、メタ分析、アーキテクチャ提言

**次のステップ:**
1. コンテキスト・エンベロープ（JSON構造）の実装
2. `jq`を使った中間状態の検証スクリプト
3. 複数エージェント並列実行のプロトタイプ

---

*作成日: 2026-02-04*
*作成者: Cursor Agent (Opus 4.5) + Claude Code (Opus 4.5) + Gemini (Pro 1.5) 連携実験より*
*注: 「🔵 Cursor Agent」「🟠 Claude Code」「⚪ Gemini」で出力元を区別*

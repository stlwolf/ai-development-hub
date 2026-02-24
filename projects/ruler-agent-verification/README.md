# Ruler Agent Verification

ルーラーエージェント（判断履歴のナビゲーター）の構想検証プロジェクト。

## 概要

AI開発ワークフローにおいて、セカンドオピニオン/AIレビューの**前段**に「過去の判断履歴から関連コンテキストを自動選定する」エージェント（ルーラー）を配置する構想の検証。

```
Cursor (実装) → [Ruler] → SO / Peer Review (Codex + Claude) → 合意 → 修正
```

個別の開発タスクや事例が増えるたびにルーラーを実行し、実績を蓄積して精度・有用性を評価する。

## ルーラーの役割

- 新規方針は提案しない。過去の判断の引用と適用候補提示に限定
- 確実性の構造式（`情報の量 × 切り落としの精度 × 解釈能力 × 言語化の質`）における「切り落としの精度」を担う
- SOに渡すコンテキストの「何を添付すべきか」を動的に判断

## 構成

```
ruler-agent-verification/
├── prompts/          # ルーラープロンプト（バージョン管理）
├── docs/
│   └── episodes/     # タスクごとのルーラー実行記録
└── tmp/              # 生出力（gitignore対象）
```

## 使い方（推奨: ruler.sh）

```bash
cd /path/to/ai-development-hub

# 基本実行（ローカルターミナルから）
./projects/ruler-agent-verification/ruler.sh "タスクの説明"

# モデル指定
./projects/ruler-agent-verification/ruler.sh -m gpt-5.2 "タスクの説明"

# ファイルからタスク読み込み
./projects/ruler-agent-verification/ruler.sh -f task.txt

# dry-run（コマンド確認のみ）
./projects/ruler-agent-verification/ruler.sh --dry-run "タスクの説明"
```

出力は `tmp/ruler-YYYYMMDD-HHMMSS/` に自動保存される。

### 実行環境の注意

- **ローカルターミナルから実行すること**（Cursor統合ターミナルからは `cli-config.json` 競合でハングする）
- `cursor-agent`（Homebrew版）を使用。`agent`（自動更新版）は Gemini で `resource_exhausted` が発生する場合がある

### モデル選択

| モデル | 用途 | 備考 |
|---|---|---|
| `gemini-3.1-pro` | **推奨**（デフォルト） | Cursorサブスク内、追加コストなし |
| `gpt-5.2` | 代替 | Cursorサブスク内 |
| `composer-1.5` | 代替 | Cursorサブスク内 |

### Gemini CLI 直接実行（代替手段）

Cursor agent CLI が使えない場合のフォールバック。API Key（有料枠）が必要。

```bash
TASK="タスク説明"
sed "s|{{TASK_DESCRIPTION}}|$TASK|" projects/ruler-agent-verification/prompts/ruler-v1.txt | \
  GEMINI_API_KEY="your-key" gemini -p "$(cat)" -m gemini-2.5-pro \
  --include-directories ideas,projects/second-opinion-verification/docs
```

## 関連

- `ideas/20260218/hypothesis-inference-ratio-certainty-model.md` — 推測比率と確実性の構造モデル（理論）
- `ideas/20260218/discussion-log-inference-ratio-domain-boundaries.md` — ルーラーエージェント構想の原型
- `ideas/20260121/ai-agent-orchestration.md` — ガイドAgent構想（ルーラーの前身）
- `projects/second-opinion-verification/` — SO実行の仕組み（ルーラーの後段）

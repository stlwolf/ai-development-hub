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

## 使い方

```bash
cd /path/to/ai-development-hub

# タスク説明を差し替えてルーラーを実行
TASK="ここにタスク説明"
sed "s|{{TASK_DESCRIPTION}}|$TASK|" projects/ruler-agent-verification/prompts/ruler-v1.txt | \
  gemini -p "$(cat)" -m gemini-2.5-pro \
  --include-directories ideas,projects/second-opinion-verification/docs

# 出力を保存する場合
sed "s|{{TASK_DESCRIPTION}}|$TASK|" projects/ruler-agent-verification/prompts/ruler-v1.txt | \
  gemini -p "$(cat)" -m gemini-2.5-pro \
  --include-directories ideas,projects/second-opinion-verification/docs \
  2>&1 | tee projects/ruler-agent-verification/tmp/ruler-output-$(date +%Y%m%d-%H%M%S).txt
```

### モデル選択

| モデル | 用途 | 備考 |
|---|---|---|
| `gemini-2.5-pro` | 推奨（安定） | API Key認証で動作確認済み |
| `gemini-3-flash-preview` | より深い分析 | OAuth認証では429頻発。API Key推奨 |
| `gemini-2.5-flash` | 高速・最安定 | 品質はやや劣る |

### 認証

`GEMINI_API_KEY` 環境変数の設定を推奨（OAuth personalはキャパ枯渇しやすい）:

```bash
export GEMINI_API_KEY="your-api-key"
# または永続化
echo 'GEMINI_API_KEY="your-api-key"' >> ~/.gemini/.env
```

API Keyは [Google AI Studio](https://aistudio.google.com/app/apikey) で取得。

## 関連

- `ideas/20260218/hypothesis-inference-ratio-certainty-model.md` — 推測比率と確実性の構造モデル（理論）
- `ideas/20260218/discussion-log-inference-ratio-domain-boundaries.md` — ルーラーエージェント構想の原型
- `ideas/20260121/ai-agent-orchestration.md` — ガイドAgent構想（ルーラーの前身）
- `projects/second-opinion-verification/` — SO実行の仕組み（ルーラーの後段）

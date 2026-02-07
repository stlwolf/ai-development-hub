# 疑似オーケストレーション構想

claude-safe を基盤とした、CLI ベースのマルチエージェント連携の設計メモ。

## コンセプト

Cursor Agent の統合ターミナルから claude-safe 経由で Claude Code を呼び出すことで、異なるモデル・コンテキストを組み合わせた疑似的なマルチエージェント構成を実現する。

```
Cursor Agent (親)
  └→ claude-safe → Claude Code (子)
       └→ 結果を返す → Cursor Agent が受け取る
```

### 連携の制約

| パターン | 可否 | 備考 |
|----------|------|------|
| Cursor IDE → Claude Code | ✅ | claude-safe 経由 |
| Claude Code → Cursor | ❌ | cursor-agent CLI は外部AIコマンドを実行できない |

連携は Cursor が親、Claude Code が子の一方向。

## ユースケース

### セカンドオピニオン

```bash
# Cursor Agent にコード実装を任せつつ、Claude Code にレビューを依頼
claude-safe -p "@src/main.ts を読んでセキュリティ観点でレビューして" --output-format text
```

### 並列レビュー（将来構想）

```bash
# 複数視点での並列レビュー
claude-safe -p "セキュリティ観点でレビュー" --output-format json > /tmp/security.json &
claude-safe -p "パフォーマンス観点でレビュー" --output-format json > /tmp/perf.json &
wait
# 結果を統合
```

## オーケストレーションパターン

### パターン1: シンプルなパイプライン

```
┌──────────────┐      ┌──────────────┐
│ Cursor Agent │ ───► │ Claude Code  │
│  (実装)      │      │  (レビュー)  │
└──────────────┘      └──────────────┘
```

### パターン2: 並列実行 + 統合

```
                ┌──────────────┐
            ┌──►│ Claude Code  │───┐
            │   │ (セキュリティ) │   │
Cursor Agent│   └──────────────┘   │  Cursor Agent
 (指示)     │                      ├──► (統合)
            │   ┌──────────────┐   │
            └──►│ Claude Code  │───┘
                │ (パフォーマンス) │
                └──────────────┘
```

## コンテキスト・エンベロープ（将来構想）

Gemini (Pro 1.5) から提案された、意図と成果物を包んだ JSON 構造。パイプラインで文脈を維持するための設計。

```json
{
  "meta": {
    "original_intent": "不変の目的（例: N+1問題の解消）",
    "constraints": "制約条件（例: Raw SQL禁止）",
    "trajectory": [
      "step1: Cursor が修正案を作成",
      "step2: Claude が型エラーを指摘",
      "step3: Cursor が修正"
    ]
  },
  "payload": {
    "current_file_content": "...",
    "diff": "..."
  }
}
```

## 実装アプローチの段階

| レベル | 方法 | 適した段階 |
|--------|------|-----------|
| ライトウェイト | シェルスクリプト + jq | 実験・プロトタイプ |
| ミドルウェイト | Node.js / Python | JSON処理・エラーハンドリング強化 |
| ヘビーウェイト | LangGraph / CrewAI 等 | 複雑な状態管理・本番運用 |

現時点ではライトウェイト（シェルスクリプト）で十分。必要に応じて複雑化していく。

## CLI連携 vs フレームワーク

| 観点 | CLI連携 | OSSフレームワーク |
|------|---------|-----------------|
| 統合度 | 低（プロセス分離） | 高（同一プロセス） |
| 柔軟性 | 高（異種サービス横断） | 中（フレームワーク依存） |
| セットアップ | スクリプトのみ | コード実装 |
| デバッグ | 各CLI単体でテスト可 | 複雑 |
| モデル多様性 | 高（何でも繋げる） | 中（対応APIに依存） |

## 由来

このドキュメントは `ideas/20260204/ai-agent-orchestration.md` の構想を、プロジェクトとして実装していくための設計メモとして再構成したもの。元のドキュメントには Cursor Agent / Claude Code / Gemini 三者の視点が記録されている。

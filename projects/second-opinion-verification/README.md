# Second Opinion Verification Project

このプロジェクトは、**「AIによるセカンドオピニオン（反証）」** と **「意図的圧縮（Intentional Compression）」** のプロセスを検証するための実験場です。
`claude-safe` へのタイムアウト機能追加を題材に、複数のAI（Primary/Second）が協調して品質を高めるフローを実証しました。

## ディレクトリ構成

```
projects/second-opinion-verification/
├── src/
│   └── claude-safe-with-timeout  # 実証実験で作られた成果物（タイムアウト付きスクリプト）
├── docs/
│   ├── plans/                    # 計画時のプランログ
│   ├── episodes/                 # 実装プロセスにおける議論ログ
│   └── decisions/                # 昇格された重要な決定事項 (ADR)
```

## 検証の成果

1.  **バグの事前検出**: 単独実装では見落とした「ゾンビプロセス」「Ctrl+C時の挙動」を、セカンドオピニオンAIが指摘し修正できた。
2.  **プロセスの記録**: 計画から実装、修正までの過程を `docs/` 配下に記録することで、意思決定の経緯を透明化した。

## 関連
- 元プロジェクト: `projects/claude-safe/`
- アイデア: `ideas/20260208/hypothesis-second-opinion-review-flow.md`

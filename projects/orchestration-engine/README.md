# orchestration-engine

自前オーケストレーションツール MVP の実装プロジェクト（[Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4）。

## 目的

構造化ドキュメントのルーティングエンジンを Bash + jq で薄く実装し、AI コーディングエージェント間のタスク・コンテキスト受け渡しを自動化する。

3層モデルにおける**上半身（エージェント層）**に相当する。下半身（[wez CLI](../wezterm-ai-mode/) Phase 1 完了）と中間層（通信プロトコル、設計中）の上に構築される。

## 研究フェーズとの関係

本プロジェクトは [`projects/orchestration-research/`](../orchestration-research/) の Phase 1〜3（OSS リサーチ・概念抽出・設計統合）成果を起点とする。研究プロジェクトは **frozen**（Phase 1〜3 完了でクローズ）。本プロジェクトでは:

- 研究成果は**参照のみ**（直接編集しない）
- 研究起点以降の追加設計入力は**本プロジェクト側の `docs/` に記述**

### 主要参照

- `projects/orchestration-research/synthesis/architecture-sketch.md` — 全体アーキテクチャ素描（研究フェーズ正本、frozen）
- `projects/orchestration-research/synthesis/harness-engineering-mapping.md` — ハーネス概念マッピング
- `projects/orchestration-research/synthesis/context-foundation.md` — コンテキスト基盤

### 起点以降の追加設計入力

- [#37](https://github.com/stlwolf/ai-development-hub/issues/37) Harness Engineering 基盤整備 — G1〜G7 ギャップ
- [#20 issuecomment-4298073225](https://github.com/stlwolf/ai-development-hub/issues/20#issuecomment-4298073225) — 3層モデルと Epic ゴール不鮮明問題
- `docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md` — CLIラッパー4層モデル
- [#22](https://github.com/stlwolf/ai-development-hub/issues/22) / [#36](https://github.com/stlwolf/ai-development-hub/issues/36) CLOSE — 制御ループ入力層整備済み

## 構成

```
projects/orchestration-engine/
├── README.md                  # このファイル
└── docs/
    ├── discussions/           # 探索・ブレスト・調査メモ
    ├── plans/                 # KickOff / Plan（実行可能粒度）
    ├── episodes/              # 実行記録・作業ログ
    └── decisions/             # ADR / 意思決定の蒸留
```

docs 配置は [`projects/wezterm-ai-mode/docs/`](../wezterm-ai-mode/docs/) の構造を踏襲し、`spec-card` スキルの蒸留パイプライン（Discussion → KickOff → Plan → Episode → Decision/ADR）に準拠する。

## 状態

**Phase 4 Step 4-0 進行中**（[#81](https://github.com/stlwolf/ai-development-hub/issues/81)）。

| Step | 内容 | 状態 |
|------|------|------|
| 4-0 | PJ 立ち上げ + Discussion 作成（スコープ・ゴール・docs 配置確定） | 進行中（#81） |
| 4-1 | エンベロープ + ディスパッチャの骨格 | 未着手 |
| 4-2 | 成果物パース + 状態管理 | 未着手 |
| 4-3 | 検証ゲート v1（adversarial review 相当） | 未着手 |
| 4-4 | E2E 検証（ツール改善タスクで1サイクル完走） | 未着手 |
| 4-5 | フィードバック → 設計修正 | 未着手 |

## 関連

- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 自前オーケストレーションツール MVP
- 並列トラック: [#20](https://github.com/stlwolf/ai-development-hub/issues/20) wez CLI / [#37](https://github.com/stlwolf/ai-development-hub/issues/37) Harness / [#24](https://github.com/stlwolf/ai-development-hub/issues/24) フック拡充
- サブ論点: [#77](https://github.com/stlwolf/ai-development-hub/issues/77) ゼロベース探索 / [#78](https://github.com/stlwolf/ai-development-hub/issues/78) コードパス網羅

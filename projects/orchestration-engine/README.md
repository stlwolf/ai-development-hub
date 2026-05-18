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
├── bin/
│   └── oe                     # エントリポイント（`bash bin/oe "タスク記述"` または `bash bin/oe --task-file <path>`）
├── lib/                       # Bash 関数ライブラリ
│   ├── constants.sh           # OE_POLL_INTERVAL, OE_CB_*, OE_DATA_DIR, OE_TARGET_AI_*, OE_VERIFY_AI_* 等
│   ├── envelope.sh            # JSON エンベロープ生成
│   ├── spawn.sh               # wez pane split + send + CLI ディスパッチャ（cursor-agent / claude / codex）
│   ├── capture.sh             # マーカー検出・6 値分類・KVS 書き込み（target pane 監視）
│   ├── verify.sh              # 検証ゲート v1（reviewer spawn + file redirect 経路 scan + KVS 書き込み）
│   ├── monitor.sh             # ポーリングループ + サーキットブレーカー
│   ├── audit.sh               # JSONL 監査ログ追記
│   └── cleanup.sh             # trap EXIT 用ペイン kill + tmp 削除 + wez notify
├── schemas/                   # JSON Schema 5 件（envelope / audit-log / session-state / exit-code-mapping / failure-taxonomy）
├── tests/                     # mock テスト 8 suite 合計 306 assertions
│   └── e2e_real_agent/        # 実 agent (cursor-agent + claude) で 1 サイクル E2E 検証（Step 4-4 で新設）
├── scripts/
│   ├── validate-envelope.sh   # エンベロープ JSON 検証
│   └── validate-session-state.sh  # KVS 状態 JSON 検証（Step 4-3 で追加、verification map 含む）
├── audit/                     # 監査ログ JSONL 出力先（runtime）
├── state/                     # セッション状態 KVS 出力先（runtime）
└── docs/
    ├── discussions/           # 探索・ブレスト・調査メモ
    ├── plans/                 # KickOff / Plan（実行可能粒度）
    ├── episodes/              # 実行記録・作業ログ
    └── decisions/             # ADR / 意思決定の蒸留
```

docs 配置は [`projects/wezterm-ai-mode/docs/`](../wezterm-ai-mode/docs/) の構造を踏襲し、`spec-card` スキルの蒸留パイプライン（Discussion → KickOff → Plan → Episode → Decision/ADR）に準拠する。

## 観測層と駆動層の分離

本プロジェクトは **観測層** と **駆動層** を明示的に分離した運用を行う。これは MVP 完成前のドッグフード検証でもある（orchestration-engine が解決したい問題そのもの = 「スレッド/セッション間のコンテキスト引き継ぎを構造化ドキュメントで実現」）。

| 層 | 配置 | 役割 |
|----|------|------|
| **観測層** | GitHub Issue / コメント / PR | MVP **外** からのプロジェクト進捗の俯瞰、人間のスプリント管理、外部ステークホルダーへの可視化 |
| **駆動層** | `docs/{discussions,plans,episodes,decisions}/` | エージェントが読み書きするコンテキスト引き継ぎ装置。開発サイクル自体はここで完結 |

### 運用ルール

- **開発サイクルは駆動層で完結**: KickOff → Plan → Episode → ADR の蒸留パイプラインで進める
- **Issue / コメントは観測用ハイライト**: スプリント運用に必要な情報を残すが、エージェントが Issue を読まないと進められない状態にはしない
- **エージェントの初期入力は driving layer のみで完結すべき**: 「`#19` の本文 + 本 README + 該当 KickOff / Plan」だけで Step を進められる状態を維持
- **観測層→駆動層への翻訳が必要なら ADR / Episode 化**: Issue コメントで重要な意思決定が発生したら ADR に蒸留して駆動層に持ち込む

### Dogfood 視点

orchestration-engine の MVP は「閉セッション間のリアルタイム双方向通信」を扱う（[Discussion §4](./docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md)）。スレッド / Cursor チャットセッションも閉セッションの一種であり、driving layer のドキュメントだけで次セッションへ引き継ぎできるかが、本 MVP の有効性検証になる。

検証成功条件: 新規スレッドが本 README + 該当 Discussion / KickOff / Plan を読むだけで、人間が前スレッドの会話履歴を伝えなくても Step を進められること。

## 状態

**Phase 4 MVP 完了 (2026-05)**。target = cursor-agent (composer-2) + reviewer = claude (sonnet-4-6) で実機 1 サイクル E2E 完走実証済み (Step 4-4)、architecture-sketch.md frozen 化済み (Step 4-5)、Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) close。

| Step | 内容 | 状態 |
|------|------|------|
| 4-0 | PJ 立ち上げ + Discussion 作成（スコープ・ゴール・docs 配置確定） | ✅ 完了（[#81](https://github.com/stlwolf/ai-development-hub/issues/81)） |
| 4-1 | エンベロープ + ディスパッチャの骨格 | ✅ 完了（[#84](https://github.com/stlwolf/ai-development-hub/issues/84) / [PR #85](https://github.com/stlwolf/ai-development-hub/pull/85) / [PR #86](https://github.com/stlwolf/ai-development-hub/pull/86)） |
| 4-2 | 成果物パース + 状態管理 | ✅ 完了（[#87](https://github.com/stlwolf/ai-development-hub/issues/87) / [PR #88](https://github.com/stlwolf/ai-development-hub/pull/88)） |
| 4-3 | 検証ゲート v1（adversarial review 相当） | ✅ 完了（[#89](https://github.com/stlwolf/ai-development-hub/issues/89) / [PR #94](https://github.com/stlwolf/ai-development-hub/pull/94)） |
| 4-4 | E2E 検証（実 agent で 1 サイクル完走） | ✅ 完了（[#95](https://github.com/stlwolf/ai-development-hub/issues/95) / [PR #97](https://github.com/stlwolf/ai-development-hub/pull/97)） |
| 4-5 | フィードバック → architecture-sketch.md 更新 + frozen 化 | ✅ 完了（[#103](https://github.com/stlwolf/ai-development-hub/issues/103) / [PR #104](https://github.com/stlwolf/ai-development-hub/pull/104)） |

### Phase 4 完了報告と Phase 5 方向感

- **Phase 4 完了報告**: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../orchestration-research/synthesis/architecture-sketch.md) §11 (Step 4-5 で追記、frozen)
- **Phase 5 方向感メモ** (Phase 5 着手時の入力資料): [`docs/plans/2026-05-18-kickoff-phase-5-direction.md`](./docs/plans/2026-05-18-kickoff-phase-5-direction.md) (`status: draft`)
- **設計判断の正本**: [`docs/decisions/`](./docs/decisions/) 配下の ADR 5 件
- **Step 別経緯**: [`docs/episodes/`](./docs/episodes/) 配下の Episode 17 件

## 関連

- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19) 自前オーケストレーションツール MVP (Phase 4 完了で close)
- 並列トラック: [#20](https://github.com/stlwolf/ai-development-hub/issues/20) wez CLI / [#37](https://github.com/stlwolf/ai-development-hub/issues/37) Harness / [#24](https://github.com/stlwolf/ai-development-hub/issues/24) フック拡充 / [#62](https://github.com/stlwolf/ai-development-hub/issues/62) Negative Knowledge
- サブ論点: [#77](https://github.com/stlwolf/ai-development-hub/issues/77) ゼロベース探索 / [#78](https://github.com/stlwolf/ai-development-hub/issues/78) コードパス網羅

### 派生 Issue (MVP 後拡張候補、Phase 5 で本質性仕分け)

| Issue | 内容 |
|---|---|
| [#92](https://github.com/stlwolf/ai-development-hub/issues/92) | 検証ゲート v2 検討候補: 変更ファイル検出 per-pane 化 + 完了報告内容の充実 |
| [#93](https://github.com/stlwolf/ai-development-hub/issues/93) | reviewer 一時ファイル掃除 (前半完了) + nonce marker (後半 = MVP 後拡張) |
| [#98](https://github.com/stlwolf/ai-development-hub/issues/98) | target ペイン出力を file redirect 経路に統一 |
| [#99](https://github.com/stlwolf/ai-development-hub/issues/99) | bin/oe --task-file の異常系 (空 / 不在 / 不正パス) の仕様明示 |
| [#100](https://github.com/stlwolf/ai-development-hub/issues/100) | _oe_verify_scan_log_file の単体テスト追加 |
| [#101](https://github.com/stlwolf/ai-development-hub/issues/101) | reviewer marker の false-positive 抑制 |
| [#102](https://github.com/stlwolf/ai-development-hub/issues/102) | _oe_strip_ansi 共通関数化 |

---
id: "01KQ7DBTAZVNQECWRME9Y3NBGP"
title: "CLIラッパー層の設計とトークン規律 — フック拡充・Agent-First CLI・rtk"
date: 2026-04-27
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "Epic #24: フック拡充エピック（H-1〜）。フック拡充の延長でCLIラッパー層の設計を議論"
  - type: design_context
    ref: "docs/draft/commit-gate-and-rule-observability.md"
    reason: "ルール vs 機械的ゲートの仕分け原則。ルールの弱点（観測不能）の議論が本文の前提"
  - type: design_context
    ref: "docs/research/2026-03-10-agent-first-cli-design-rewrite-your-cli.md"
    reason: "Agent-First CLI 8原則。特に原則1（Raw JSON）・原則3（Context Window Discipline）が直接関連"
  - type: source_material
    ref: "docs/research/oss-sessions/2026-04-27_rtk.md"
    reason: "rtk OSS調査。問題の存在証明とパターンカタログとしての参考価値"
  - type: source_material
    ref: "ideas/20260130/ai-native-interface-concept.md"
    reason: "「for AI な CLI」構想の原点。Human CLI vs AI CLI の分離提案"
  - type: source_material
    ref: "ideas/20260130/ai-middleware-cli-concept.md"
    reason: "Middleware CLI 構想。入力前処理・出力後処理・コンテキスト純度"
tags: [cli-design, hooks, token-discipline, agent-first-cli, rtk, context-window, epic-24]
---

# CLIラッパー層の設計とトークン規律

> フック拡充（#24）の延長で、機械的判断をCLIラッパー群で担保し、エージェントの判断負荷とコンテキスト消費を同時に減らす構想の議論。

## 起点

- [Issue #24](https://github.com/stlwolf/ai-development-hub/issues/24)（フック拡充エピック）の Tier 1〜2 でフックが増えるが、フックは「通す/止める」の二値判定に特化している
- 「コマンドの組み合わせで判断する」部分をラッパースクリプト群で担保し、エージェントの判断基準を減らせないか
- これは `ideas/20260130/ai-native-interface-concept.md` の「for AI な CLI」構想と結びつくか

## 4層モデル: エージェント負荷の削減レイヤ

議論の中で、判断負荷を減らす仕組みは排他ではなく4層に整理できることがわかった。

```
エージェントの負荷
  ↑ 高
  │  ルール        → 判断の柔軟性（文脈依存、例外あり、観測不能）
  │  CLIラッパー    → 手順の圧縮（N判断 → 1コマンド）
  │  解析ラッパー   → コンテキスト消費の圧縮（解析をCLI側で吸収）
  │  フック        → 判断自体を不要に（二値判定・自動発火）
  ↓ 低
```

### 各層の特性

| 層 | タイミング | 判断の性質 | エージェントへの効果 |
|----|-----------|-----------|-------------------|
| **ルール** | エージェントが内部で適用 | 文脈依存・例外あり | 柔軟だが観測不能 |
| **CLIラッパー** | エージェントが明示的に呼ぶ | N判断 → 1コマンド | 手順ステップ数を削減 |
| **解析ラッパー** | コマンド出力の後処理 | 情報密度を上げる | トークン消費を削減 |
| **フック** | イベント発火時（before/after） | 二値（通す/止める） | 判断自体を不要に |

### ルールの弱点（`commit-gate-and-rule-observability.md` より）

- ルールに従わなかった → 人間が気づかないと素通り
- なぜ従わなかったのか → エージェント側の判断が不透明
- フィードバックループが構造的に回らない

CLIラッパーは「そもそも判断させない」方向でこの弱点を解消する。

## 「理解できる」と「コンテキスト効率が良い」は別問題

既存CLIの出力は人間向け（For Human）。モデルは学習データに含まれているため「理解」はできるが、解析にコンテキストとトークンを消費する。

- `git log` のデフォルト出力 vs `--oneline --format='%H %s'` → 同じ情報量でトークン数倍の差
- サブエージェント文脈では、親→子→親の往復で差が累積する
- Agent-First CLI の原則3「Context Window Discipline」（field masks + NDJSON pagination）がこれを直接言っている

### CLIラッパーが担保できる前処理

| 役割 | 例 | 効果 |
|------|-----|------|
| 出力の構造化 | `--json` + field mask | 装飾・ヘッダ・罫線を排除 |
| 出力の要約 | `jq` で必要フィールドだけ抽出 | トークン 1/5〜1/10 |
| エラーの構造化 | exit code + JSON `{"error": ..., "suggestion": ...}` | エラー解釈のトークン削減 |
| コンテキスト制約 | `--limit`, `--fields`, `--since` | 不要な情報を生成しない |

## rtk: 問題の存在証明とパターンカタログ

[rtk](https://github.com/rtk-ai/rtk)（22.3k stars, Rust）が同じ問題を解いている。30分セッションで ~118,000 → ~23,900 tokens（-80%）。

### rtk の4戦略

1. Smart Filtering — ノイズ除去（コメント・空白・定型文）
2. Grouping — 類似項目の集約
3. Truncation — 冗長部分の切り詰め
4. Deduplication — 繰り返しログの折りたたみ

### 自分の構想との位置関係

| 観点 | rtk | ai-development-hub の構想 |
|------|-----|--------------------------|
| 対象 | 汎用CLIコマンド（100+） | 自作CLI + 汎用（必要な分だけ） |
| 手法 | 出力フィルタリング（プロキシ） | 出力構造化（JSON）+ フィルタリング |
| 統合 | フック経由の透過的書き換え | フック + CLIラッパー + ルール |
| スコープ | トークン削減に特化 | トークン削減 + 判断圧縮 + ガードレール |

### 採用判断: パターン知識としての参考価値

rtk バイナリ自体の導入は個人環境に対して too much:

- **設定分散**: `~/.config/rtk/config.toml` + フック設定が増える
- **フック競合**: 自作 `canonical/hooks/` の `beforeShellExecution` と同イベントで競合しうる
- **バージョン追従**: 103リリース、破壊的変更リスクあり（2026-01 作成で日が浅い）
- **過剰統合の教訓**: `second-opinion-verification` エピソードで「統合mega-wrapperは過剰」と結論済み

採用すべきは**パターン知識**:

- どのコマンドのどの出力がトークンを浪費するか
- `git push` → 進捗15行は全部ノイズ、`ok main` で十分
- `cargo test` → 成功テストの列挙は不要、失敗だけ

このパターン知識をルールやスキルに反映する方が、バイナリ依存より軽い。

## 「その場で並列で作る」方が合理的な理由

1. **初期トークンコスト** — 個別コマンドの差（200 vs 30 tokens）はセッション全体（200k）に対して微小
2. **作るコスト** — エージェントに「この形式で出して」と言えば一瞬
3. **メンテコスト** — 自分で書いたシェル関数なら中身が全部見える
4. **文脈適合** — 汎用圧縮より「今この調査でこの部分だけ欲しい」のその場の `jq` / `--format` が精度高い

## 結論

- **フック拡充**（#24）は「判断自体を不要にする」層を広げる
- **CLIラッパー**は「判断ステップ数を減らす」層。自作CLIの `--output json` が主戦場
- **解析ラッパー**は「コンテキスト消費を圧縮する」層。rtk の知見は参考にするがバイナリは採用しない
- **for AI CLI** の設計原則（JSON出力・スキーマ・dry-run）は全層の品質を上げる基盤
- 個人開発環境では、汎用ツール導入よりエージェントがその場で最適な出力形式を作る方が合理的

## 関連

- [コミットゲートとルール観測可能性](../draft/commit-gate-and-rule-observability.md)
- [Agent-First CLI 設計](../research/2026-03-10-agent-first-cli-design-rewrite-your-cli.md)
- [rtk OSS 調査](../research/oss-sessions/2026-04-27_rtk.md)
- [AI-native Interface Concept](../../ideas/20260130/ai-native-interface-concept.md)
- [AI Middleware CLI Concept](../../ideas/20260130/ai-middleware-cli-concept.md)
- [Epic #24](https://github.com/stlwolf/ai-development-hub/issues/24) — フック拡充エピック

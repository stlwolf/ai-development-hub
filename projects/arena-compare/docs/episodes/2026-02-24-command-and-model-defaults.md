---
title: "arena-perspectives コマンド化、モード別デフォルトモデル、プロンプト構成の最適化"
date: 2026-02-24
type: episode
related:
  - type: derived_from
    ref: ./2026-02-23-resume-support-implementation.md
    reason: "resume 実装完了後の次ステップとしてコマンド化に着手"
  - type: derived_from
    ref: ./2026-02-22-prototype-verification.md
    reason: "プロトタイプ検証の次のステップ（コマンド作成）を消化"
tags: [arena-compare, cursor-command, model-selection, prompt-design]
---

# arena-perspectives コマンド化、モード別デフォルトモデル、プロンプト構成の最適化

## 背景

resume サポート実装後、arena-compare.sh を Cursor のメインスレッドから手軽に呼べるコマンド化と、モデル選定・プロンプト構成の最適化を実施。

## 実施内容

### 1. Cursor コマンド `arena-perspectives` の作成

`cursor/command/verification/arena-perspectives.md` として作成し、`sync-cursor-commands.sh` で `~/.cursor/commands/` にシンボリックリンク配置。

設計思想:
- **判断はコマンドの仕事ではない**: 回答を並べるだけ。合成・採用判断は人間が行う
- peer-ai-review（重い、3者合意ループ）との対比で、軽量な多角的情報収集ツールとして位置づけ

### 2. モード別デフォルトモデルの導入

メインスレッドが Claude 系（opus-4.6）のため、デフォルトから Claude を外して異ファミリーで多様性を確保。

| モード | デフォルト | 選定理由 |
|--------|-----------|----------|
| ask / plan | gpt-5.2, gemini-3.1-pro, composer-1.5 | Q&A向き、異ファミリー3つ |
| agent | gpt-5.3-codex-high, gemini-3.1-pro, composer-1.5 | Codex で実装力 |

モデル速度の実測:
- gpt-5.3-codex: 17秒（同一質問）
- gpt-5.3-codex-high: 41秒（2.4倍遅い）
- agent モード用途では推論力優先で high を採用

### 3. プロンプト構成の最適化（`-c` 非推奨化）

`-c` でファイル内容をプロンプトにベタ貼りすると肥大化してタイムアウトの原因になることが判明。

| パターン | プロンプトサイズ | gpt-5.2 の結果 |
|----------|-----------------|----------------|
| `-c` で README + CONVENTIONS.md 添付 | 17,278B | タイムアウト (120秒) |
| フルパス記述のみ（`--workspace` 経由で動的読み込み） | 647B | 67秒で成功 |

コマンドの Step 1 を「`@` 参照をフルパスに置き換え、`-c` は原則使わない」に更新。

### 4. デフォルトタイムアウトの調整

300秒 → 180秒に変更。実測で最長 105秒（gpt-5.2）のため、180秒で十分。`ARENA_TIMEOUT` 環境変数での上書きは引き続き可能。

## 検証結果

### 3モデル並列（新デフォルト、フルパス構成）

| モデル | 時間 | 出力 |
|--------|------|------|
| composer-1.5 | 29秒 | 6,216B |
| gemini-3.1-pro | 45秒 | 3,740B |
| gpt-5.2 | 64秒 | 5,776B |

3/3 全成功。

## 発見

### `--workspace` によるファイル動的読み込み

プロンプトにファイルのフルパスを書くだけで、`--workspace` で指定したディレクトリ内のファイルをエージェントが自律的に読みに行く。`-c` によるベタ貼りは不要であり、プロンプト肥大化を避けられる。

### ワークスペースルールの CLI への適用

`--workspace` 指定時、そのワークスペースの `.cursor/rules/` やユーザールールが agent CLI にも適用されることを確認（resume エピソードからの再確認）。

## 成果物

- `cursor/command/verification/arena-perspectives.md`: Cursor コマンド
- `arena-compare.sh`: モード別デフォルトモデル、タイムアウト 180秒
- `README.md`: モード別デフォルト、タイムアウト反映

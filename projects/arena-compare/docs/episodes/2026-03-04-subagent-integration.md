---
title: "arena-compare.sh のサブエージェント対応・品質改善"
date: 2026-03-04
type: episode
related:
  - type: derived_from
    ref: ../plans/2026-03-03-kickoff-so-arena-subagent.md
    reason: "SO/Arena サブエージェント化キックオフに基づく実装"
  - type: derived_from
    ref: ./2026-02-24-summary-output-implementation.md
    reason: "summary.md 実装後の次ステップとして品質改善"
tags: [arena-compare, subagent, skill, shellcheck, validation]
---

# arena-compare.sh のサブエージェント対応・品質改善

## 背景

SO/Arena サブエージェント化キックオフ（`docs/plans/2026-03-03-kickoff-so-arena-subagent.md`）に基づき、arena-compare.sh を skill/subagent パターンに対応させた。スクリプト自体はcommandのみ存在した時期に作られたもので、以下の課題があった:

- `source "$meta"` による任意コード実行リスク
- モデル名の未検証（パストラバーサル可能）
- `-c` 使用時のプロンプト肥大化への警告がない
- `$AGENT_CMD` 未クォート（shellcheck 指摘）
- 全モデルタイムアウト時のガイダンスがない

## 実施内容

### 1. `source "$meta"` → `grep`/`cut` パースに置き換え

`generate_summary()` 内の3箇所 + メインのサマリ出力1箇所で `source "$meta"` を `grep '^key=' "$meta" | cut -d= -f2` に置き換え。変数名を `m_model`, `m_exit`, `m_elapsed` 等にプレフィックス付きで統一し、ループ内のスコープ問題も解消。

### 2. モデル名バリデーション追加

`[[ "$model" =~ ^[a-zA-Z0-9._-]+$ ]]` でモデル名を検証。`../` 等のパストラバーサルを防止。

### 3. 品質改善

- `require_arg()` 関数追加: `-f`, `-m`, `-o`, `-w`, `--mode`, `--resume-from` の引数存在チェック
- `-c` 使用時の非推奨警告（stderr）
- プロンプトサイズ警告（50KB 超で stderr に warning）
- 全モデルタイムアウト時のガイダンスメッセージ（`ARENA_TIMEOUT` 増加、`-c` → `-w` 切り替え、認証状態確認を案内）
- `$AGENT_CMD` のクォート修正（3箇所: `exec`, `create-chat`, `nohup` 内）

### 4. タイムアウトデフォルト変更

`ARENA_TIMEOUT` のデフォルトを 180秒 → 240秒に変更。全リポジトリの実行時間データ（48件のメタファイル）を分析し、225秒/262秒の成功ケースを拾えるよう調整。

### 5. Arena スキル作成

`cursor/skill/arena-compare/SKILL.md` を新規作成。呼び出し方法、モデル選択基準、resume 手順、summary.md 読み込み手順を記載。

### 6. arena-perspectives コマンドのサブエージェント対応

`cursor/command/verification/arena-perspectives.md` の Step 2-3 をサブエージェント委譲に変更。Task tool の shell subagent が Arena スキルを Skill Injection で読み込み、summary.md を要約して差分ポイントのみメインに返す構造。

## 検証結果

- `shellcheck projects/arena-compare/arena-compare.sh`: warning 0
- peer-ai-review 実行でサブエージェント委譲パターンの動作を確認（`tmp/peer-review-20260304-002404/`）
- 実行時間データ分析: 240秒タイムアウトで成功率 85-89%

## 成果物

- `projects/arena-compare/arena-compare.sh`: source 置き換え、バリデーション、品質改善、タイムアウト 240秒
- `cursor/skill/arena-compare/SKILL.md`: 新規
- `cursor/command/verification/arena-perspectives.md`: サブエージェント委譲対応
- `projects/arena-compare/README.md`: タイムアウト値・関連リンク更新

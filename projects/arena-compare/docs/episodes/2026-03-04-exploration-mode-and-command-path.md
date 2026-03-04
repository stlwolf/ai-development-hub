---
title: "探索モード組み込みとコマンドパス整備"
date: 2026-03-04
type: episode
related:
  - type: derived_from
    ref: ../plans/2026-03-03-kickoff-so-arena-subagent.md
    reason: "SO/Arena サブエージェント化キックオフの Phase 3 + 追加改善"
  - type: derived_from
    ref: ./2026-03-04-subagent-integration.md
    reason: "サブエージェント対応完了後の追加改善"
tags: [arena-compare, so-compare, persistent-exploration, sync-bin, command-path]
---

# 探索モード組み込みとコマンドパス整備

## 背景

SO/Arena サブエージェント化の全 Phase 完了後、以下の追加改善を実施した:

1. persistent-exploration の行動制約を peer-ai-review / arena-perspectives に条件付き自動注入（探索モード）
2. so-compare / arena-compare を `~/bin/` にコマンドとして配置（sync-bin.sh）
3. コマンド・スキル内のフルパス参照をコマンド名に統一

## 実施内容

### 1. 探索モードの組み込み

**peer-ai-review.md**:
- Step 2.5 に探索モード判定を追加。再現手順確立や原因不明タスクで persistent-exploration の行動制約テンプレートを SO プロンプトに自動注入
- Step 4 に「不可能」回答時の探索分岐を追加。突破口チェックリスト参照 → 未試行アプローチ列挙 → SO 再実行

**arena-perspectives.md**:
- Step 3 に深掘り要否判定を追加。モデルが「不可能」と回答 or モデル間で結論が割れた場合、`--resume-from` で行動制約を注入して最大3 Round の深掘りを実行

設計根拠: 独立コマンド（`/deep-investigation`）ではなく既存コマンドに組み込むことで、エージェントが自律的に探索モードを発動できる。[o-m-cc](https://github.com/kok1eee/o-m-cc) の Sisyphus 哲学（Persistence Wins）を、タイムアウト制約のある環境に「浅い探索の複数ラウンド」として適応。

### 2. `~/bin/` コマンド配置

`scripts/sync/sync-bin.sh` を新設。`so-compare.sh` と `arena-compare.sh` を `~/bin/` にシンボリックリンクとして配置。

```
~/bin/so-compare → scripts/so-compare.sh
~/bin/arena-compare → projects/arena-compare/arena-compare.sh
```

他リポジトリからフルパスなしで呼べるようになった。

### 3. パス参照の統一

peer-ai-review.md, arena-perspectives.md, SO/Arena スキルのフルパス参照（`$HOME/work/repos/.../scripts/so-compare.sh` 等）をコマンド名（`so-compare`, `arena-compare`）に置き換え。

## 成果物

- `cursor/command/verification/peer-ai-review.md`: 探索モード判定 + 探索分岐追加
- `cursor/command/verification/arena-perspectives.md`: 深掘り要否判定 + resume ラウンド追加
- `scripts/sync/sync-bin.sh`: 新規
- `scripts/README.md`: sync-bin.sh 追記
- `cursor/skill/so-compare/SKILL.md`: パス統一
- `cursor/skill/arena-compare/SKILL.md`: パス統一

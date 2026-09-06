---
id: "01M1VV05GPHN5SP25FB3218D7R"
title: "#375 so-compare の cursor 既定モデルを composer-2.5 にする — 実行記録"
date: 2026-09-07
type: episode
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/375"
scope: orchestration-engine
related:
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/303"
    reason: "SO レーンの空返しを分類する単位。本単位はその前に置かれた小さな既定値変更で、同じ委譲アークに属する"
tags: [so-compare, cursor, model, cost]
---

# #375 so-compare の cursor 既定モデルを composer-2.5 にする — 実行記録

**なぜこの作業が始まったか**: owner が 2026-09-07 に、cursor レーンの既定 `auto` が高コストのモデル（`cursor-grok-4.6-high` 等）に解決されて使用量の警告を招いたと報告した。SO は設計と実装の両ゲートで常時回すので、既定が高コストだと回すたびに効く。`composer-2.5` は選べるモデルの中で最もコストが低い。

## 前提（着手時点で確定していること）

- owner が既定値の変更そのものを明示した。委譲 brief でも本単位だけが plan-first の例外として扱われている（計画の owner ゲートを待たずに実装してよい）。
- 変える範囲は既定値の3箇所だけ。`--cursor-model` と `SO_CURSOR_MODEL` による明示指定は今までどおり効く。
- 本単位のあとに #303 と #344 の段階1（実例の表と plan）が続く。そちらは plan-first で止まる。

## 随時追記

### 2026-09-07 着手前の確認

- `agent models` の一覧に `composer-2.5 - Composer 2.5` が在ることを実機で確認した。
- 変更対象は3箇所。`scripts/so-compare.sh` の `CURSOR_MODEL` 既定値（`:72`）、同ファイルの usage 2箇所（`:28` の `--cursor-model` と `:43` の `SO_CURSOR_MODEL`）、`canonical/skills/so-compare/SKILL.md` の既定値の表 2箇所（`:40` と `:54`）。

### 2026-09-07 変更範囲を3箇所から広げた理由

brief は変更を3箇所（script の既定値・script の usage・skill doc の既定値）と指定していた。実際に読むと、**既定が `auto` であることを前提にした記述が他に4箇所あり、変えないと嘘になる**。

- `scripts/so-compare.sh` の meta 付近のコメント「既定の auto では "Auto Balance"」
- `SKILL.md`「未指定なら各 CLI の既定モデルで動作し、従来と挙動は変わらない」（cursor だけ so-compare 側の既定を渡すので当てはまらなくなる）
- `SKILL.md`「cursor の既定は `auto` で実行時に選ばれる」
- `SKILL.md`「`auto` は実行ごとに解決先が変わる」節（節そのものは有効だが、既定の話ではなく `auto` を明示したときの話になる）

これは範囲の拡張ではなく、同じ1つの論理変更に付いてくる整合だと判断した。`auto` の性質を説明している記述そのものは消していない（明示指定したときの挙動として今も正しい）。

### 2026-09-07 検証（gate 4 の前）

`shellcheck scripts/so-compare.sh` は緑。

既存テストは worktree のコードで実行して両方緑。

- `projects/orchestration-engine/tests/test_oe_refute.sh` — pass=63 fail=0
- `projects/orchestration-engine/tests/test_oe_review.sh` — pass=64 fail=0

実機で3通り走らせて meta を確認した。1件目が変更の確認、2件目と3件目は「明示指定は今までどおり効く」ことの陽性対照である。

| 実行 | `model_requested` | exit | status |
|---|---|---|---|
| 既定（フラグ・環境変数なし） | `composer-2.5` | 0 | success |
| `--cursor-model auto` | `auto` | 0 | success |
| `SO_CURSOR_MODEL=auto` | `auto` | 0 | success |

`agent models` の一覧に `composer-2.5 - Composer 2.5` が在ることも確認済み。

なお `~/bin/so-compare` は master の worktree を指す symlink なので、**この変更はマージするまで他セッションには効かない**。検証はすべて worktree の実体（`./scripts/so-compare.sh`）を直接叩いて行った。

### 2026-09-07 範囲外の気付き（実装しない・surface のみ）

`canonical/skills/so-compare/SKILL.md` の使用例が `--cursor-model composer-1.5` を渡している。`agent models` の一覧に `composer-1.5` は無く、この例をそのままコピーするとレーンがエラーになる。既定値の変更とは別の話なので直していない。

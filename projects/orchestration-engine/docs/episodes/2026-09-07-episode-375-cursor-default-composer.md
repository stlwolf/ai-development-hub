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

### 2026-09-07 gate 4（実装SO・弱2レーン）

`oe-review --lanes 2 --base master`（audit_id `202609061711526RTZKV4SZRVY`）を1本だけ走らせた。**2レーンとも attempt 1 で返り、verdict は `survived`。**

| レーン | 所要 | model_requested | 判定 |
|---|---|---|---|
| codex | 135秒 | CLI 既定（`gpt-5.6-sol`） | survived |
| cursor | 71秒 | `composer-2.5` | survived |

この実行自体が変更の陽性対照になっている。`OE_REVIEW_SO_COMPARE` を worktree の実体に向けたので、cursor レーンは**新しい既定でレビュー級のプロンプトを処理した**。71秒・4177バイトで返っており、既定の `SO_TIMEOUT`（240秒）に十分収まった。ただしこれは1点の実測なので、`composer-2.5` が常に240秒に収まるとは言えない。

#### 指摘を1件反映した

cursor レーンが、既定を前提にした記述の取りこぼしを1件見つけた。`SKILL.md` の「軽い確認 → 既定モデルのまま（フラグ未指定＝従来挙動）」で、cursor については「従来挙動」でなくなる。自分で列挙した4箇所の外だったので直した。**自分の整合チェックが漏れた箇所を SO が拾った形である。**

#### 反映しなかった指摘

どちらのレーンも `composer-1.5` の使用例が無効であることに触れたが、両方とも「本変更以前からある別の問題」と判断している。自分の判断（範囲外・surface のみ）と一致したので直していない。

両レーンが「コード欠陥ではないが未解決のリスク」として挙げた点も、判断としては owner に渡す。`composer-2.5` の反証力が `auto` と同等かは測っていないし、`composer-2.5` を持たないアカウントでは cursor レーンが構造的に失敗しうる（`auto` よりポータビリティは下がる）。どちらも既定値を戻せば解消する。

### 2026-09-07 範囲外としていた1件を統括の判断で取り込んだ

上で「範囲外・surface のみ」としていた `--cursor-model composer-1.5` の使用例について、統括が「既定モデルの記述を直す同じ論理変更の範囲なので本 PR で直す」と判断した（gate 4 の再走は不要・doc の1語という付帯判断つき）。指示どおり `composer-2.5` に直した。

**判断を委ねた側の判断なので従ったが、1点だけ残しておく。** この使用例は「モデルを明示指定する書き方」を見せる例なので、既定と同じ値を書くと例として何も示さなくなる。既定と違う値（`claude-opus-5-thinking-high` 等）のほうが例としては働く。値の選択は owner / 統括の裁量なので、こちらでは変えていない。

`agent models` の一覧に `composer-1.5` が無いことは確認済みで、直す前の例をコピーするとレーンが落ちる状態だった。

### 2026-09-07 使用例の値を auto にした（統括の再判断）

上の指摘を統括が受け、「例は既定と違う値にする。`--cursor-model auto` にして、既定の `composer-2.5` から `auto` へ明示的に戻す例だと1文添える」と決めた。実際にこのフラグを使う場面がそれである、という理由づけである。そのとおりに直した。

**この1行は3回書き換わった。** 元の `composer-1.5`（無効な値）→ 統括判断で `composer-2.5`（有効だが既定と同値で例にならない）→ 指摘を受けて `auto`（既定から戻す実用例）。範囲外として surface したものを取り込むときは、値の妥当性だけでなく「その例が何を見せるためのものか」まで一緒に決める必要がある、という形で残しておく。

昇格の印: 範囲外の指摘を取り込むときは、直す値だけでなくその記述の目的まで一緒に決めないと往復が増える

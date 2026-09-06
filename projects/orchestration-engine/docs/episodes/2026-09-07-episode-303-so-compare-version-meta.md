---
id: "01M1W0C4KTK97VA9FHPE1HRQ08"
title: "#303 M-1 — so-compare 自身の版をレーンの meta に残す（実行記録）"
date: 2026-09-07
type: episode
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/303"
scope: orchestration-engine
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-09-07-plan-303-so-lane-failure-classification.md"
    reason: "本 episode が実行する plan の M-1"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-09-07-episode-303-so-lane-failure-classification.md"
    reason: "母集団が so-compare 自身の版で汚染されていることを実測した単位"
tags: [so-compare, meta, provenance, version]
---

# #303 M-1 — so-compare 自身の版をレーンの meta に残す（実行記録）

**なぜこの作業が始まったか**: レーンの meta には CLI の版（`cli_version`）が入るが、**so-compare 自身の版が入っていなかった**。そのため過去の出力を集めて分類しようとすると、母集団に「すでに直った故障の残骸」と「いまも起きる故障」が混ざる。#303 の調査では収集期間中に so-compare が4回変わっており、うち #296 は claude の stdout の意味そのものを変えていた。**その記録から決めた観測点が、いまの経路では当たらなかった。** 設計SO の claude レーンがこれを指摘し、こちらでソースと `git log` を開いて確かめている。

## 前提（着手時点で確定していること）

- owner の gate 3 裁定で、測定の列 M-1 として「so-compare の版を meta に必ず残す」ことが決まっている。
- `so-compare` は `~/bin` から repo への symlink で配布されており、**マージした瞬間に全セッションへ反映される。**
- 追加は additive にする（既存のキーを1つも変えない・消さない）。

## 随時追記

### 2026-09-07 値を2つに分けた理由

**宣言した版だけでは足りない。** 振る舞いを変えたのに上げ忘れると、記録が嘘をつく。それは #303 が扱っている問題そのもの（記録から読める版と実際の版が食い違う）である。

**ハッシュだけでも足りない。** 人が meta を読んだときに、どの時点のものか分からない。

そこで2つ書く。

- `so_compare_version` — 宣言した版（読みやすいが、上げ忘れると嘘をつく）
- `so_compare_sha` — スクリプト自身のバイト列の sha256 の先頭 12 桁（読めないが、嘘をつかない）

**層別するときはハッシュで束ね、人が読むときは宣言を見る。** 使い分けはコメントに書いた。

取れなかったときは空欄にせず種別を書く（`unavailable:no-hasher` / `unavailable:self-unreadable` / `unavailable:hash-failed`）。これは同じファイルの `cli_version_for()` が採っている作法に揃えたものである。

### 2026-09-07 実機での確認

cursor レーン1本で走らせ、meta に次が入ることを確認した。

```text
so_compare_version=2026-09-07
so_compare_sha=c2990d86da1b
```

`shellcheck` は緑。

### 2026-09-07 3レーンでの確認と、読み取り側との突合

3レーンを1回で走らせ、**codex / claude / cursor のすべて**の meta に2つのキーが入ることを確認した。

| レーン | `so_compare_version` | `so_compare_sha` | 結果 |
|---|---|---|---|
| codex | `2026-09-07` | `c2990d86da1b` | exit 0 / success |
| claude | `2026-09-07` | `c2990d86da1b` | exit 0 / success |
| cursor | `2026-09-07` | `c2990d86da1b` | exit 0 / success |

**meta の行が壊れていないことも見た。** 3レーンとも `key=value` の形でない行は0件である（追加したキーの値に空白や `=` が入ると1行1組の約束が壊れるため）。

**読み取り側（I-1 の `oe-lane-explain`）と突き合わせた。** これまで `unavailable:not-recorded` と出ていたところに `2026-09-07` が出る。**書く側と読む側が繋がったことを実物で確かめてある。**

既存テストへの影響も見た。`test_oe_refute.sh`（pass=63）と `test_oe_review.sh`（pass=64）はどちらも緑である。あの2本は `so-compare` を PATH 先頭のスタブに差し替えるので本来は影響を受けないが、確かめずに「影響しないはず」で済ませない。

### 2026-09-07 この変更が M-1 の測定に効く範囲（限界）

**過去の記録には効かない。** 版が meta に入るのはこれから走る実行だけである。M-1 の集計（`.oe/report-303-M1.md`）は、観測できる目印（`timeout_limit_seconds` の有無・`claude-raw.json` の有無）で層別して代用した。

**目印は版の順序を持たない。** 2値で切っただけなので、#296 / #345 / #353 の境目は claude の `raw.json` の有無以外には見えていない。`so_compare_sha` が溜まれば、これから先は素直に束ねられる。

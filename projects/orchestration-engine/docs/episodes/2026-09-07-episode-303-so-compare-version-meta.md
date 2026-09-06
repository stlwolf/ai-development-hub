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

### 2026-09-07 gate 4（実装SO・弱2レーン）— 中心の要件が1つ欠けていた

`oe-review --lanes 2 --base master`（audit_id `202609061859514FQ46GHS46AE`）。**cursor は `survived`**（失敗経路がすべて `unavailable:*` へ落ちて `set -e` も meta の行も壊さないこと、3レーンへの additive 出力が `key=value` として安全であることを、コード精読と `BASH_SOURCE` / `shasum` の検証で確認したとしている）。

**codex は `refuted` で、実要件の穴を1つ指した。**

> 中断・異常終了時の running meta に so-compare の版情報が記録されず、失敗記録を版別に分類する中心要件を満たさない。

**そのとおりだった。** meta は2段で書く（試行の開始時に `attempt_state=running` で置き、完了時に差し替える）。版を書いていたのは**完了側だけ**だったので、中断された実行は `running` のまま版を持たずに残る。

**これは「たまたま抜けていた」ではなく、いちばん要る場所で抜けていた。** 中断された実行は失敗の記録そのものであり、この変更の目的は「失敗を版で分けられるようにすること」である。**目的に照らして最も効く場所を落としていた。**

直し方は開始側にも同じ2行を書くだけである。完了側と同じ値なので、`mv` で差し替わっても値は変わらない。

**実機で確かめた。** 実行を途中で kill して、残った meta を読んだ。

```text
tool=cursor
attempt=1
attempt_state=running
timeout_limit_seconds=200
so_compare_version=2026-09-07
so_compare_sha=b8eb1cb647b2
```

読み取り側（`oe-lane-explain`）もこの記録を扱えることを確認した（`attempt_state=running` / `so_compare_version=2026-09-07` / `reason=unknown` で1件として数える）。

**ハッシュが変わっていることにも意味がある。** 前回の確認は `c2990d86da1b` で、この修正で `b8eb1cb647b2` になった。**宣言した版（`2026-09-07`）は据え置きのままなので、ここで嘘をつくのはハッシュではなく宣言のほうである。** 2つに分けた理由がそのまま出た形になった。

昇格の判定に使うため、ここに残しておく。**2段で書く記録に値を足すときは、両方の段に足したか確かめる。** 片方だけだと、中断された記録という「いちばん知りたいもの」で欠ける。

既存テストは修正後も緑（`test_oe_refute.sh` pass=63 / `test_oe_review.sh` pass=64）。

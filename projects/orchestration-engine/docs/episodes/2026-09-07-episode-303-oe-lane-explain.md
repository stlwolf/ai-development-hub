---
id: "01M1VZ66HDWNV8BQZWEC77G2WT"
title: "#303 I-1 — SO のレーンが返らなかった理由を読み取る verb を外に置く（実行記録）"
date: 2026-09-07
type: episode
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/303"
scope: orchestration-engine
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-09-07-plan-303-so-lane-failure-classification.md"
    reason: "本 episode が実行する plan の I-1"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-09-07-episode-303-so-lane-failure-classification.md"
    reason: "前単位。設計SO が3レーンとも反証し、この verb を外に置く案が出た経緯がある"
tags: [so-compare, classification, read-only, oe-lane-explain]
---

# #303 I-1 — SO のレーンが返らなかった理由を読み取る verb を外に置く（実行記録）

**reconstructed。** 着手時に枠を作らず、実装と検証を終えてから書いた。**これは brief の episode 義務に反している**（着手時に枠・作業中は随時追記）。リアルタイムの追記ログと同じ証拠価値は無い。前単位では枠を先に作れていたので、単位が変わったところで落ちた。

**なぜこの作業が始まったか**: #303 の設計SO で、3レーン中2レーンが独立に「分類を `so-compare` の外へ出せ」と言った。`so-compare` は `~/bin` から repo への symlink で配布されており、触ると全セッションへ即座に反映される。分類のシグネチャは CLI の版で腐るので、腐るものを配布物に入れたくない。外に置けば過去の出力へ遡って当てられる利点もある。owner の gate 3 裁定で、この案は I-1 として実装に入った。

## 前提（着手時点で確定していること）

- plan v2 の I-1。**`scripts/so-compare.sh` に1行も触れない**のが契約である。
- 設計要件が3つ先に決まっていた。不在と空を畳まない / `exit_code=0` にはシグネチャを当てない / 当たらなければ `unknown` に倒す。
- PR は master から切る（列が独立なので積み上げない）。

## 随時追記（実際は事後の再構成）

### 2026-09-07 実物で誤検出を踏んだ（設計SO の予告どおり）

最初の実装は素の部分一致（`grep -F`）で当てていた。**過去の出力に当てたところ、`tmp/so-288-h3` の codex レーンが `invalid_input` に化けた。**

実物を開いて分かった。このレーンの stderr は 831KB・6964 行あり、**その 2095 行目に「codex が引数を拒否していた（`error: invalid UTF-8 was detected in one or more arguments`）」というリポジトリの散文**が入っている。codex のレーンは stderr に TUI の描画を流すので、ワークスペースの本文がそのままエコーされる。本物（`tmp/so-288-gate2-r2`）は6行の stderr の1行目に立っている。

**設計SO の codex レーンがこれを予告していた。** 「stdout の部分一致は、モデル回答がプロンプト中の文言を引用した場合に誤検出し得る」という指摘で、私は plan にその対策として「`exit_code=0` を対象外にする」だけを書いていた。**実際に踏んだのは exit 124 の側で、その対策では止まらなかった。**

対策は2つ重ねた。**行頭に錨を打つ**ことと、**末尾 200 行だけを見る**ことである。本物は行頭に立ち、プロセスが死ぬ直前に出る。エコーは行の途中に出て、ファイルの中ほどにある。

**錨が使えない文言が1つあった。** claude-safe が書けなかったときの `<path>: line N: <path>: Operation not permitted` は行頭が機械ごとに変わる。ここだけ「小さいファイルに限り部分一致を許す」逃し弁を置いた。誤検出の元が数百KB の TUI 描画なので、小ささを条件にすれば経路を塞げる。

昇格の印: 指摘された誤検出の対策を1つ書いて満足すると、同じ誤検出の別の経路で踏む

### 2026-09-07 陰性対照を2つ置いた

この誤検出をテストで固定した。**`codex-echoed-phrase` は exit 124（非ゼロ）で、故障の文言がファイルに実在する。** それでも `unknown` になることを固定してある。錨を外すとこの fixture は `invalid_input` に化けるので、対策が効いていることを直接示す。

もう1つ（`success-quoting-limit-phrase`）は exit 0 の側で、こちらは構成した。**11 件の fixture のうち構成したのはこれ1件だけで、残り10件は実物からの切り出しである。** 出所と日付は `tests/fixtures/so-lane-failures/SOURCE.md` の表にある。

### 2026-09-07 「不在」と「空」を弁別できることを2件並べて固定した

前単位で収穫した教訓（`knowledge/items/01M1VX9MH72K7G940R6WC7M218.md`）をそのまま設計要件にした。`claude-session-limit-legacy` には `claude-raw.json` が**存在せず**、`claude-timeout-silent` には**空で存在する**。この2件を並べて置き、`raw_state` が `absent` / `empty` に分かれることをテストで固定した。

so-compare 自身の版は meta に無いので `unavailable:not-recorded` と書き、代わりに観測できる目印（`claude-raw-absent` なら #296 より前、`limit-recorded` なら #328 以降）を `era_markers` に出す。**推定した「版」を1つの値にまとめない。**

### 2026-09-07 検証

- `shellcheck` は verb もテストも緑。
- `tests/test_oe_lane_explain.sh` — pass=29 fail=0。
- **`scripts/so-compare.sh` の diff が空**（`git diff origin/master -- scripts/so-compare.sh` が何も返さない）。配布物を触らない契約が守られている。

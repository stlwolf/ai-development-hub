---
id: "01M61YJTDN4SRZH7FWZG8NJD1G"
title: "#532 validate-knowledge の directory mode が、item が0件のディレクトリを OK にする"
date: 2026-10-29
type: episode
status: stable   # closure 2026-10-29（PR #556 の Copilot のラウンドの後・マージ前）。達成
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/532"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/pull/556"
    reason: "この単位の PR"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-10-29-episode-531-validate-knowledge-extra-args.md"
    reason: "同じスクリプトの直前の単位（#531）"
tags: [orchestration, knowledge, validator]
promotion:
  - subject: "directory mode で item が0件なら exit 2（見つからないと同じ帯）にする"
    verdict: not-required
    ref: "本文: S1: 直し方と確かめた結果（2026-10-29）"
knowledge_observations:
  - "01KZ21M0N0FZ4YMR2R6DPHTWQ4"
---

# #532 validate-knowledge の directory mode が、item が0件のディレクトリを OK にする

## なぜこの作業が始まったか

2026-10-23 の orchestration-engine の実装の監査（#484）で、`validate-knowledge` の directory mode が、直下に `*.md` が1件も無いディレクトリを渡されると何も検証せず `OK` と exit 0 を出すことが見つかった。`items/` でなく親の `knowledge/` を渡す取り違えが、全部合格と区別できない。bash 3.2 では空の配列の展開が `set -u` で落ち、exit 1（INVALID と同じ番号）になる。

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## この単位の入力

- brief: 統括（cockpit 21代目）が 2026-10-29 に発行した小さなコードの直し4件の brief（作業層・消える）の単位 U4。着手条件（U3 の PR #553 のマージ）は統括から届いた（master `fcb9329`）。plan と認識合わせは owner の方針で省く。終端は U4-S3（報告を送る）で、委譲全体の終端でもある。マージ・worktree の掃除・issue の close・sync はしない。
- scope: `projects/orchestration-engine/scripts/validate-knowledge.sh` の directory mode。`*.md` が0件なら `ERROR: no items` を出して exit 2 で終える。**#532 本文の knowledge-list の explicit mode の部分は直さない**（`knowledge-list.sh` の `--strict` の終了コードの契約に関わるので、範囲外として報告する）。
- SO: 実装 weak（Codex 1レーン）+ Copilot 1ラウンド。
- 注入された negative knowledge: 1件（frontmatter の `knowledge_observations`）。closure で観測を書き戻す。

## 作業の記録

### S1: 再現（2026-10-29）

master `fcb9329` で、空のディレクトリを渡すと bash 5.2.37 で `OK: <dir>`・exit 0、`/bin/bash` 3.2.57 で `files[@]: unbound variable`・exit 1 になった。

### S1: 直し方と確かめた結果（2026-10-29）

- **直し方**: directory mode で `*.md` を集めたあと、0件なら `ERROR: no items: …` を出して exit 2 で終える。exit 2 は「見つからない」と同じ帯で、ヘッダの exit の説明にも書き足した。空の配列を展開する前に終えるので、bash 3.2 の `set -u` で落ちる経路も無くなる。
- **呼び出し元**: validate-knowledge を directory mode で呼ぶのは README の例と `tests/test_knowledge_list.sh` で、どちらも item のあるディレクトリを渡す。リポジトリにある3つの `knowledge/items/` には 66・21・7 件の item がある。
- **確かめた結果**: `tests/test_validate_knowledge.sh` に [53] を足した（7項目）。`/bin/bash` 3.2.57 と bash 5.2.37 の両方で PASS=276 FAIL=0。`tests/test_knowledge_list.sh` も両方で PASS=214 FAIL=0。validate-knowledge.sh を変更前に戻すと [53] は両方の bash で5項目ずつ落ちる（3.2 は unbound variable で exit 1、5 は OK で exit 0）。`shellcheck` は2つのファイルで通る。

### S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）

Codex の1レーンが返った（`timeout_status=success`・103秒）。出力は作業層の `tmp/so-532-impl/` にある。この差分に起因する不具合は無いという答えで、0件を exit 2 にする判断、ヘッダと呼び出し元との整合、[53] が修正を外すと落ちることは問題なしだった。

- **採らない（範囲外として報告する・中）: 読めないファイルが「item の不備」（exit 1）になる。** `*.md` に当たるディレクトリ・壊れた symlink・読めないファイルは、frontmatter を読む `sed` が失敗すると frontmatter 欠落と同じ WARN になり、exit 1 で終わる。ヘッダの契約では、読めないのは環境エラー（exit 2）である。OK にはならないので #532 の「0件を OK にする」とは別の不具合で、変更前からある。brief の scope は0件の扱いだけなので直さず、統括への報告に範囲外として書く。
- 修正が無くても通る [53] の項目（3.2 の「OK を出さない」、5 の「unbound variable で落ちない」、両方の「1件あれば exit 0」）は、異常な出力が無いことと正常系の維持を確かめる項目で、そのままにした。

### S2: Copilot の1ラウンド（2026-10-29）

Copilot のレビューは指摘0件（概要は「Approval recommended」）。返信の要る行の指摘は無い。PR を作った直後、Copilot への依頼を番号を取り違えて #555 に送った。#555 は issue だったので `gh pr edit` は失敗し、#555 の timeline に記録は増えていないことを確かめてから、#556 に送り直した。PR の番号は `gh pr create` の出力から取り、手で数えて決めない。

## closure（2026-10-29）

- **tier**: heavy。実装SO を意図して起動したため（指摘で直した箇所は無い）。
- **次の消費者**: validate-knowledge を directory mode で呼ぶ人とスキル（`knowledge/README.md` の二段チェック）。
- **事実・失敗**: Copilot への依頼を一度違う番号に送った。何も変わっていないことを確かめた。`本文: S2: Copilot の1ラウンド（2026-10-29）`
- **決定と根拠**: exit 2 にしたのは brief の scope で、「見つからない」と同じ帯である。`本文: S1: 直し方と確かめた結果（2026-10-29）`
- **昇格の判定**: 1件で `not-required`。brief（統括）が決めた範囲の判断で、コードのコメントとヘッダの exit の説明が正本である（1段目で外れる）。昇格の印は置いていない。
- **蒸留シグナル**: なし。
- **follow-up**: 2件。どちらも統括への報告に範囲外として書き、行き先は統括の判断に預ける。(1) #532 本文の knowledge-list の explicit mode が0件で exit 0 を返す件（brief が範囲外とした）。(2) 実装SO が出した「読めないファイルが item の不備（exit 1）になる」件。`本文: S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）`
- **観測の書き戻し**: 注入された item は `01KZ21M0N0FZ4YMR2R6DPHTWQ4` の1件で、`outcome_unknown` を書き戻した（差分は教訓どおりだが、直し方は issue と brief が決めていた）。
- Step4 辞退: 実装SO と Copilot が差分を見ており、指摘と自分の失敗1件は本文に節を立てて記録済み / 既存チェックで覆った観点: 省略チェック（範囲外1件・取り違え1件が本文と事実・失敗に在る）・routing（follow-up 2件とも行き先を書いた）・evidence anchor（SO の出力は `tmp/` だが要点を本文に転記済み）/ 未実施観点と判断: back-propagation は、#532 本文の knowledge-list の件を報告で統括へ返すのでそれで足りる

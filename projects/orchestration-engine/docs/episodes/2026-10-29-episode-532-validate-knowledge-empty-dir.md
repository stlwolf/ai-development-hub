---
id: "01M61YJTDN4SRZH7FWZG8NJD1G"
title: "#532 validate-knowledge の directory mode が、item が0件のディレクトリを OK にする"
date: 2026-10-29
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/532"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-10-29-episode-531-validate-knowledge-extra-args.md"
    reason: "同じスクリプトの直前の単位（#531）"
tags: [orchestration, knowledge, validator]
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

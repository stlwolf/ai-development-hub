---
id: "01KX3WP95QCFT8RXSK919Z4FDP"
title: "#238 段階1 PR-C — board schema + advisory validator の実装と2段レビュー"
date: 2026-07-10
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/238"
    reason: "統括 succession を第一級概念に。board schema = declared 層（PR-C）"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/244"
    reason: "本 episode が閉じる実装 PR"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md"
    reason: "本 PR が定義した schema 契約の正本"
---

# #238 段階1 PR-C — board schema + advisory validator の実装と2段レビュー

> `reconstructed`: 本 episode は作業完了後にまとめて書いた。リアルタイム追記ログではないため、同じ証拠価値では扱わない。

## Context / なぜ

#238「統括 succession を第一級概念に」の段階1 は3 PR に分かれ（PR-A statusline producer / PR-B watchdog consumer / PR-C board schema）、本作業は **PR-C**（declared 層）を親 pane `%144` から委譲されたもの。cockpit 統括の succession board に構造と鮮度を強制する schema と advisory validator を与える。board 実体は machine-local・ephemeral のため commit せず、in-repo には spec doc と validator のみを足す（設計は `projects/orchestration-engine/docs/decisions/2026-07-10-decision-238-board-schema.md` §2 PR-C / §4 Q8。#250 で昇格元 working plan `.oe/ref-plan-stage1.md` を (b) 張替）。

## 事実・失敗（実行ログに残るもの・選択的省略しない）

初回実装（commit `b3ddd52`）は shellcheck clean・bash 3.2/5.2 両系で 20/20 green だった。にもかかわらず**2 段のレビューで計 5 件の到達可能な欠陥が見つかった**。テスト green が正しさを保証しなかったのが本 episode の主眼。

- **実装 SO（`oe-review`・弱・2 レーン・audit `2026070916203622EHG3X4RCTR`）→ verdict refuted（2/2）**。material 3 件（親が一次再現で確認のうえ修正）:
  - (a) 鮮度 キー欠落時、値抽出パイプ `grep '^鮮度:' | head | sed` が `set -euo pipefail` 下で grep 非マッチ→pipefail 死し、**section 検査と最終 summary に到達しない**。「全 WARN 一括出力」の契約破り。→ `{ grep || true; }` で吸収。
  - (b) 空 frontmatter block（`---` のみ）を **valid 扱い**。`[[ -n "$FRONTMATTER" ]]` でキー検査全体を skip していた。→ block の有無（`FM_PRESENT`）と中身を分離し、block があればキー検査を走らせる。
  - (c) 非数値 `OE_BOARD_*` env が `set -u`+算術で cryptic に落ちる。自 doc の「env エラー→exit 2」と不一致。→ 整数チェックを算術前に置き exit 2。
- **Copilot review（routine bot・PR #244）→ 2 件（両方採用・commit `312b5ba`）**:
  - (d) 鮮度 キーは在るが**値が空**（`鮮度:` のみ）だと date check を素通りして exit 0。これは (a) 修正でキー正規表現を `^鮮度:` に緩めた副作用の残り。→ キー宣言時に空値を format 不正として WARN（キー欠落の二重 WARN は回避）。
  - (e) `related` の `.oe/ref-plan-stage1.md` は gitignore 済みで checkout に含まれず、読者が辿れない。→ out-of-repo である旨を明示。

## 決定と根拠（diff から復元できない「なぜ」）

- **doc 型を `decision` にした**: 「schema/spec doc」の type enum に `spec` は無い。repo 内の形式仕様前例 `docs/specs/document-format.md` が `type: decision` を採るため、それに倣った（新 type を作らない）。
- **jq を date 演算だけに使った**: sibling validator は JSON を jq で検証するが board は markdown。frontmatter 抽出・見出し確認は bash のテキスト処理が素直で、jq は鮮度 date→epoch の可搬変換（`strptime|mktime`）にのみ使う。BSD/GNU の `date -j -f` vs `-d` 差を避ける狙い。棄却案: `date` で直接パース（両系分岐が要る）。
- **必須集合を最小に保った**: 値の形式（pane 形・succession 語彙）は強制せず存在のみ必須。advisory validator の主リスク「正当な variation を invalid と誤検知」を避けるため。ただし鮮度だけは date check が中核契約なので、空値は (d) で WARN する（最小主義と契約強制の線引き）。

## わかったこと（W）

- `set -euo pipefail` + `$(pipe | grep | ...)` は、テストが「マッチする経路」しか通っていないと **非マッチ経路の pipefail 死を見逃す**。テスト green は非マッチ分岐の健全性を保証しない。既存 sibling が `H2_LINES` 側だけ `|| true` を持っていたのは、まさにこの落とし穴を1箇所で踏んでいた痕跡だった。
- 「block の**有無**」と「block の**中身**」を1つの `[[ -n ]]` に畳むと、空 block が"無い"側に倒れて検査を素通りする。存在と内容は別変数で持つべき。
- 正規表現を緩める修正（(a) の副作用で `^鮮度:[[:space:]]`→`^鮮度:`）は、別の素通り経路（空値 (d)）を開けうる。1つの gate を緩めたら隣接 gate の再確認が要る。

## 原則（Pattern / Anti-pattern）

- **Anti-pattern**: `set -e`/`pipefail` 下で `VAR="$(... | grep PATTERN | ...)"` を、PATTERN 非マッチが正常系なのにガードなしで書く → 非マッチで script 途中終了。
- **Pattern**: 正常系で非マッチしうる grep は `{ grep ... || true; }` で包むか、`if grep -q ...; then` の条件文（set -e 抑止）に置く。到達判定と値抽出を分ける。

## 蒸留シグナル

- 昇格候補: **なし**（skill/rule への昇格はしない）。上の Anti/Pattern 対は既存 `diff-audit` skill の Bash 堅牢性観点に既に含まれる粒度で、独立 rule 化するほどではない。negative knowledge（#62）注入の候補としては (a)/(d) の「gate を緩めると隣接 gate が開く」が弱いシグナル。

## 残課題（routing 済み）

- **frontmatter 閉じフェンス判定のヒューリスティック**（1 行目 `---`+以降 `---`）: 本文冒頭が水平線の board で誤認しうる。→ 行き先: **spec doc に「既知の制約」として開示済み**（追わない・実害小）。SO cursor も非 primary と判定。
- **#238 本体**: keep-open。board schema は段階1 の declared 層のみ。PR-A/PR-B（watchdog）と seat 系は別 PR / 段階2。→ 行き先: **#238（多段のため PR merge≠close）**。
- **マージ・worktree 掃除・#238 close**: owner/親の HG。→ 行き先: **親 `%144` へ報告済み**。

## closure gate

- Context / なぜ: 上記（自己完結）。
- 次の消費者: **owner（マージ判断）** と **PR-A/PR-B 実装者**（declared×observed の相補＝gone×stale の crash/handoff 判別で board の `現統括`/`succession` を突合する設計が本 schema に依存）。
- follow-up routing: 上記「残課題」で全件行き先付与。
- status: **stable**（達成）。マージは owner。
- evidence anchor: 実装 SO audit `2026070916203622EHG3X4RCTR`（出力 `tmp/oe-review-2026070916203622EHG3X4RCTR/` は揮発）。verdict=refuted・material 3 件は上「事実・失敗」に転記済み。Copilot 2 件は PR #244 の返信スレッド（`discussion_r3553348905` / `r3553349014`）に durable 化。
- Step4 外部チェック（heavy tier）: 本 episode の closure 品質を `so-compare`（codex/claude 2 レーン）で focused check（出力 `tmp/so-20260710-015327/` は揮発）。**結果: 2/2 とも 4 観点（選択的省略なし / follow-up 全件 routing / 揮発証跡の要点転記 / back-propagation 漏れなし）で PASS**。claude レーンは SO 2 レーンの material dedup（codex=a/b・cursor=a/c → 和集合 3 件）が正しいこと、4 欠陥すべてに回帰テスト [10]-[13] が付くことも確認。

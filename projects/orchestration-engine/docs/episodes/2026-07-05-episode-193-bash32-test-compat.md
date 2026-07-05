---
id: "01KWS1RXDM9TY8JNMRVPTPEGXE"
title: "#193 episode — engine 既存テスト2件を bash 3.2 互換化（空配列ガード + declare -A 撤去）"
date: 2026-07-05
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/193"
    reason: "macOS 標準 bash 3.2 で engine 既存テスト2件が失敗（PR #192 非起因・master 由来）"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/231"
    reason: "本 episode の実装 PR"
  - type: design_context
    ref: "../../../wezterm-ai-mode/docs/decisions/ADR-005-bash-shell-standards.md"
    reason: "bash 3.2 互換ルール（空配列ガード `${arr[@]+...}` / `declare -A` 禁止＝平行配列）の正本"
  - type: reuse
    ref: "../../lib/monitor.sh"
    reason: "declare -A 撤去の平行配列+ヘルパー idiom を lib/monitor.sh の _OE_LAST_STATE_* から踏襲（複製せず既存前例に揃える）"
  - type: detection_origin
    ref: "2026-06-20-episode-175-spawn-layout.md"
    reason: "本 issue の3失敗（うち2件が本件）を #175 の compliance review が follow-up として検出・別 issue に routing した元"
tags: [orchestration, engine, bash-3.2, test, compatibility, empty-array, declare-a, adr-005, episode]
---

> `reconstructed`: 本 episode は closure 時に作業を振り返って再構成したもの。リアルタイム追記ログではない。

## Context / なぜ

macOS 標準の `/bin/bash`（3.2.57）で orchestration-engine の既存テスト2件が失敗していた。#175（PR #192）の compliance review + 自律子セッション検証で顕在化し、**PR #192 非起因・master 由来**であることが `git show origin/master:` で立証済み（[#175 episode](2026-06-20-episode-175-spawn-layout.md) が follow-up として別 issue = #193 に routing）。`wez` 系 CLI は `~/bin/` に sync されログインシェル（bash 3.2 の可能性）から呼ばれるため、engine 側も bash 3.2 互換が望ましい（ADR-005 と同方針）。

## 事実・失敗

- 失敗2件を bash 3.2.57 で再現・bash 5.2.37 では PASS を実機確認（着手時の一次確認）。
  - `tests/test_cleanup.sh`: `OE_VERIFY_MANAGED_PANES[@]: unbound variable`
  - `tests/test_monitor.sh`: `declare: -A: invalid option`
- 実行中の失敗・撤回・方針転回は**なし**（調査→修正→ゲートは直線的に進んだ。symmetric honesty として明記）。
- 単体切り分けで確認: bash 3.2 では `"${arr[@]}"`（空配列の展開）が `set -u` 下で unbound になるが、`${#arr[@]}`（カウント）は安全。→ `cleanup.sh` の count でガード済みのループ（`:19/:22/:25/:33`）は無傷、素の反復2箇所（`:62`/`:77`）だけが要修正と特定。

## 決定と根拠

- **DJ: `declare -A` の代替に「平行配列 + ヘルパー関数」を採用**（`case` / test skip / 動的スカラー変数 `printf -v`+`${!var}` を棄却）。
  - 棄却理由（diff から復元できない why）:
    - `skip`: 実 fix が可能で、kickoff も実 fix を優先。テスト網羅を落とさない。
    - `case`: テストごとに書き換わる動的な値保持に `case`（静的分岐）は噛み合わない。
    - 動的スカラー変数（`printf -v _MOCK_..._$k` + `${!k}` + `compgen -v`）: 3.2 で動作は検証したが、ADR-005 が `${!prefix@}` 系の列挙を禁止する方向であること、および**テスト対象ファイル `lib/monitor.sh` 自身が同型（連想配列 `OE_LAST_STATE` → 平行配列 `_OE_LAST_STATE_PANES`/`_VALS` + `_oe_monitor_last_state_{clear,get,set}`）で既に置換済み**であることから、Follow Existing Patterns（behavioral-rule §6）で平行配列を選択。
- **空配列ガードは `${arr[@]+"${arr[@]}"}` idiom**（`bin/oe-delegate:126`・ADR-005 と同型）。新規発明せず既存箇所に揃える。

## わかったこと（W）

- bash 3.2 の空配列 footgun は「展開（`"${arr[@]}"`）」に限定され「カウント（`${#arr[@]}`）」は安全。ガードは反復・展開箇所だけに絞れる（全 `[@]` を機械置換する必要はない）。
- 平行配列ヘルパーの getter が未登録キーで `return 1` を返しても、`$(...)`（コマンド置換・引数位置）では `set -e` を発火させない（3.2 で検証済み）。テスト値に末尾改行が無いため `$(...)` の改行 strip も無害。

## 検証（ゲート）

- 全 `tests/test_*.sh` **26 件**が **bash 3.2.57 / 5.2.37 両系で green**（FAIL=0）。対象2件も個別に両系 PASS。
- 変更2ファイル（`lib/cleanup.sh` / `tests/test_monitor.sh`）の `shellcheck` **rc=0**。

## 残課題（routing 済み）

- `.claude/rules/episode-flow-discipline.md`（kickoff・engine README が「蒸留パイプラインの soft floor A1」として参照）が実ファイルとして存在しない（`canonical/rules` / `~/.claude/rules` / リポ内いずれにも無し）。→ **routing: 親へ完了報告に併記して上位判断（Issue 化 or 既存規約への統合）に委ねる**。本 #193 のスコープ外につき本 PR では触らない。

## 蒸留シグナル

- 昇格候補: **なし**。本件は既存 ADR-005 / `lib/monitor.sh` idiom の適用であり、新規 Decision / skill / rule / negative knowledge を生まない。

## closure

- **SO 省略の記録**: 実装 SO(oe-review) は省略（kickoff 指示）。理由＝機械的 fix かつテストゲート（両 bash 系 green + shellcheck rc=0）で合否が客観判定でき、コード欠陥の別レンズ検証を要さないため。
- **次の消費者**: 親スレッド（完了確認 + follow-up 判断）。以後 engine で bash 3.2 互換テストを書く作業（例: #206 系 Gate G2）が「空配列は count でガード / assoc は平行配列」の前例として参照可能。
- **status**: stable / 達成度: 達成（ゲート2種を両系で満たす）。

```markdown
Step4 辞退: 機械的 fix + 客観テストゲート（bash 3.2/5.2 両系 green・shellcheck rc=0）で closure 品質リスクが低いため / 既存チェックで覆った観点: routing（follow-up を親へ）・evidence anchor（揮発パス参照なし・commit/PR/テスト suite が永続アンカー）・省略チェック（実行中の失敗は皆無で symmetric に明記）・back-propagation（欠落 rule ファイルを親へ前方参照） / 未実施観点と判断: なし
```

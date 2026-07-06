---
id: "01KWTX1QBXHWZWD4JQAAFWQAGG"
title: "#99 episode — oe --task-file の異常系（空/不在/不正パス）を明示エラー + exit 2 で validation"
date: 2026-07-06
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/99"
    reason: "--task-file の異常系が未処理で暗黙挙動だった点を、明示エラー + exit 2 で validation"
  - type: reuse
    ref: "projects/orchestration-engine/bin/oe-capture"
    reason: "既存 validation 規約（echo >&2 + return 2 = usage エラー）を踏襲・新規発明しない"
tags: [orchestration, oe, task-file, validation, error-handling, exit-code, bash-3.2, episode, reconstructed]
---

# #99 episode — oe `--task-file` 異常系の validation

> `reconstructed`: リアルタイム追記でなく closure 時（実装完了後・PR/レビュー前）に再構成。証拠価値はリアルタイム追記ログと同列に扱わない。

親（統括）からの委譲子セッションとして #99 を実装。人間とのやり取りはこのペインで直接、完了確認のみ親へ。マージ・worktree 掃除はしない。

## Context / なぜ

`bin/oe --task-file <path>` は Step 4-4（#91）で「Markdown を shell expansion 経由で渡す破綻を避ける」ために追加された入口。だが異常系が半端で、**暗黙挙動**が残っていた。特に空ファイルが問題で、これは Step 4-4 の episode 時点で派生 Issue 候補として明示的に surface されていた（`docs/episodes/2026-05-18-episode-step-4-4-implementation.md` の「派生2」）。本 issue はそれを回収する内向きブラッシュアップ。

## closure gate

- 次の消費者: PR レビュアー（人間 / Copilot）と、`--task-file` の異常系仕様を参照する将来の engine 変更者。`bin/README.md` の oe 節に仕様を 1 行反映済み。
- follow-up routing:
  - 空白のみファイル（改行/空白だけで非0バイト）: 本 PR は「空 = 0バイト（`-s`）」に限定し、空白のみは素通り（→ `task_description` に空白が入る）。**追わない（defer）** — issue の「空ファイル」は 0バイトと解釈、Minimal Scope。実害（空白タスクで spawn）が観測されたら別 issue 化。親へ out-of-scope finding として申し送る。
- status: stable。達成度 = **達成**（異常系3種＝空/不在/不正パスを exit 2 で弾き、テスト + 両 bash ゲート + shellcheck 通過）。

## 決定と根拠（コード/diff から復元できない「なぜ」）

- **exit code は全ケース 2**: 迷いなし。`bin/oe-capture` の usage/format エラーが `echo >&2 + return 2` で一貫しており、既存 `--task-file` チェック（パス未指定/不在）も既に return 2 だった。新規発明せず踏襲。→ kickoff の「exit code 規約に迷いがあれば predecision-exploration」は不要と判断（迷いが無い）。
- **「空」を `-s`（0バイト）で判定・空白のみは対象外**: 棄却案 = 読み込み後に `${content//[[:space:]]/}` で内容ベース判定（空白のみも捕捉）。棄却理由 = (1) issue の文言が「空ファイル」= 0バイトを指す (2) `-s` は cat 前の安価な stat で、`file is empty` という曖昧さのない文言に 1:1 対応 (3) Minimal Scope + edge は出たら対応（exhaustion-before-conclusion §Scope の ~80% 方針）。
- **不正パスをディレクトリ/非通常ファイル/権限に分解**: 旧実装は `! -f` 一本で、ディレクトリを「file not found」と誤報し、読めないファイルは `-f` を通過して `set -e` 下の `cat` 失敗で **exit 1 + 生の cat エラー**に化けていた（= 暗黙挙動）。`-e`→`-d`→`! -f`→`! -r`→`! -s` の順に分解し、各々固有文言 + exit 2 に統一。順序が意味を持つ（`-d` を `! -f` より先に置かないと「is a directory」を出せない／`-r` を `cat` より前に置かないと exit 1 に化ける）。

## わかったこと（W）

- 空ファイルの暗黙フォールバック経路は `task_description="$(cat "$2")"`（空）→ `task_description="${task_description:-${*:-Run orchestration task}}"` の連鎖。`:-` が空文字も unset 扱いするため、ユーザーが渡したつもりのタスクが黙って既定 `"Run orchestration task"` に化けて spawn まで到達していた。
- 異常系は全て `oe_board_apply`（= 最初の wez 接触）より前に return するため、テストは wez なしで subprocess 実行できる（temp `OE_DATA_DIR` で state/audit を隔離）。`bin/oe` は末尾で `oe_main` を無条件実行し source できないため、subprocess が唯一の検証手段。
- テストの両 bash 系ゲートを実効化するため、内側 `bin/oe` を `"$BASH"`（テスト実行中のインタプリタ）で起動した（`bash`(PATH) 任せだと 3.2 で回しても内側が 5.x になり得る）。

## 蒸留シグナル

なし。既存パターン（oe-capture validation・ADR-005 bash 3.2 互換）の適用に留まり、Decision / skill / rule 昇格候補なし。

## SO / Step4 の扱い

- 実装SO（oe-review）省略: 設計判断が薄く（exit 2 は既存パターンで一意）、客観ゲート（異常系テスト + 両 bash green + shellcheck rc=0）が合否を機械判定する。kickoff の省略許可に従い明記。
- Step4（外部 closure チェック）: 本 episode は standard tier（heavy トリガ該当なし＝失敗/撤回なし・意図的 SO なし・調査主成果でない・非自明設計判断なし・昇格候補なし）。Step4 は heavy 限定のため対象外。

## テスト結果

- `tests/test_oe_task_file.sh`（新規・5 ケース10 アサーション）: 空/不在/ディレクトリ/パス未指定/権限なし → 全て exit 2 + 期待文言。bash 3.2.57・5.2.37 両系 green。
- engine 全 suite（`tests/test_*.sh` 28 ファイル）: 両 bash 系で red=0。
- `shellcheck bin/oe tests/test_oe_task_file.sh` rc=0。

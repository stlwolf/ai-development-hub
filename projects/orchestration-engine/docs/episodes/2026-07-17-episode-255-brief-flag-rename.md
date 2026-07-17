---
id: "01KXQ9AN6ZNB1J10MZW8ZBM8QQ"
title: "#255 episode（heavy）— oe-delegate/oe-send の --kickoff を --brief へ rename（alias 存続）"
date: 2026-07-17
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/255"
    reason: "委譲ツールの flag 型名を brief へ整合させる follow-up"
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/249"
    reason: "document-format v2（PR #254）で委譲文書の型名 brief を確定した元"
  - type: design_input
    ref: ".oe/brief-255-brief-flag-rename.md"
    reason: "統括（cockpit 7代目）発行の委譲 brief（確定仕様・後方互換つき rename）"
tags: [orchestration, delegate-task, oe-delegate, oe-send, brief-rename, episode-255]
---

# #255 episode（heavy）— oe-delegate/oe-send の --kickoff を --brief へ rename（alias 存続）

> 冒頭注記: 本 episode は closure 時（実装 + 実装SO 完了後）に **reconstructed**（後追い再構成）。リアルタイム追記ログではないため、形式比較のデータとしてはリアルタイム追記と同列に扱わない。

## Context（なぜ始まったか）

document-format v2（#249・PR #254）で、統括→子の使い捨て委譲指示書の型名を `brief` に確定した（旧称 kickoff）。フロー層 kickoff（committed・`plan-to-kickoff` の出力）との名前被りを解消するため。しかし engine 側の委譲ツール（`oe-delegate` / `oe-send`）の flag 名は旧称 `--kickoff` のまま残っていた。v2 spec では「flag rename は engine コード変更ゆえ spec scope 外」として移行注記に留め、行き先を #255 に surface していた。本 episode はその follow-up＝flag と型名の齟齬解消。

## タスク性質と tier

確定仕様の後方互換つき rename（設計判断はほぼ無し）。統括 brief は「tier standard 目安」としていたが、closure 時の機械トリガ（`episode-retrospective` Step 1）で **heavy** と判定した。理由は 1 点のみ: 実装SO として **意図的に `oe-review`（so-compare 2 レーン＝codex/cursor）を起動した**こと。これは「品質ゲート目的で明示起動した外部レビュー」に該当し、単独で heavy トリガ。他の heavy トリガ（失敗・撤回、学習主成果、非自明な設計判断の棄却、昇格候補）は該当なし。

- 補足: skill の既知の限界に「episode 内で既に意図的 SO 済みなら Step4 を免除する重複排除ルール」が未 land と明記されている。それが land すれば本件のような「SO 起動が唯一の heavy 要因」ケースは standard に戻り得る。現状は未 land ゆえ heavy とし、Step4 は下記の条件付き辞退で処理する。

## 実行ログ（reconstructed）

- scope を brief + `gh issue view 255` で確定。更新面は bin パーサ 2 本 + help + README + delegate-task skill + テスト。
- `--brief` を主 flag、`--kickoff` を deprecated alias（`--brief|--kickoff` の合成 case）として実装。内部変数 `KICKOFF`→`BRIEF`（`KICKOFF_ABS`→`BRIEF_ABS`）も rename し、flag 名と内部表現の齟齬を残さない。エラー文言は実際に渡された flag（`$1`）を映すようにし、alias 経由でも正しい flag 名でエラーが出る。
- `oe-delegate` 内部の `oe-send` 呼び出しは新 primary `--brief` へ dogfood 移行。
- テスト: `test_oe_delegate.sh` を `--brief` 主に更新 + `--kickoff` alias 回帰（oe-delegate 側）+ `oe-send` の `--brief`/`--kickoff` 両パースの直接検証 + `--brief` 値必須（rc=2）を追加。26/0。
- 検証: engine 全 34 test file green / shellcheck（oe-delegate・oe-send・test）clean。
- 実装SO（gate 4・弱1周）: `oe-review --lanes 2 --base master`。verdict=**survived**（codex・cursor とも material 欠陥なし）。reviewed_sha=`328eba0`、diff_base=`master`、diff_hash=`b674bf19`、audit_id=`20260717053450V5GMMJJHHJVH`。

## 決定と根拠（diff から復元できない「なぜ」）

- **runtime の deprecation warning は出さない（documentation-only deprecation）**。issue 候補 (a)「`--brief` 追加 + `--kickoff` alias」を採り、brief は「warning は出しても止めない」と許可のみで必須化していない。ここで警告を出さない判断の根拠:
  - `--kickoff` は scope 外の内部呼び出し元（`oe-kick` → `oe-delegate --kickoff` / `oe-select` → `oe-send --kickoff`）と board（gitignored・自然 attrition・一括置換しない方針）で現に多用中。runtime 警告を出すと、それら現行経路のほぼ全委譲で stderr に警告が出続ける。
  - 削除計画は brief で明示的に「やらない」。除去予定のない deprecation 警告は移行を促す実益より騒音になる。
  - よって help / README / skill 上で「deprecated alias」と明記する documentation-based deprecation に留め、runtime は静かにする。これが最小かつ非破壊。
- **内部変数を `KICKOFF`→`BRIEF` に rename した**。primary flag が `--brief` になった以上、内部表現が `KICKOFF` のままだと後続の読み手が躓く。rename の対象（WHAT）は flag だが、内部整合は HOW の範囲で、これを揃えるのが「誠実な rename」。
- **`oe-kick` / `oe-select` は触らない（別 verb・scope 外）が、これが alias 存続の設計意図と噛み合う**。両者は内部で `--kickoff` を `oe-delegate`/`oe-send` に渡し続けるが、alias が生きているため runtime は不変。かつ両者のテストは mock 越しに `--kickoff` の受け渡しを assert しているので、**alias を残したことが両テストを green に保つ根拠そのもの**になっている（alias を消していれば全委譲と両テストが壊れた）。

## わかったこと（W）

- `oe_reg_resolve` は `%N`（生ペインID）を registry を経ずに即 passthrough する（`^%[0-9]+$` 判定）。このため `oe-send` を registry 状態なしで直接テストでき、mock の `list-panes` が `%9` を alive と返す前提だけで payload 経路を検証できた（新規テスト [13]/[14] の成立根拠）。

## 原則（Pattern / Anti-pattern）

- Pattern: 後方互換 rename は「新 primary を主に据え、旧名を alias 化 + 内部呼び出し元を新名へ dogfood 移行 + 旧名回帰テストを残す」。alias の存続を回帰テストで固定しておくと、scope 外の内部呼び出し元を触らずに済む安全域が可視化される。
- Anti-pattern: 除去計画のない deprecation に runtime 警告を付けること。移行を促す実益が薄く、現行経路への騒音が確実。

## 蒸留シグナル

- Decision / skill / rule 昇格候補: **なし**（既存方針の素直な適用に留まる）。
- `episode-retrospective` の既知課題（意図的 SO が唯一の heavy 要因のとき Step4 を重複排除で免除するルール）に、本件は実例を 1 つ足す。トリガ較正の判断材料。

## 残課題（follow-up routing）

- `oe-kick`（`bin/README.md` の該当節含む）と `oe-select` は内部で `--kickoff` を emit し続ける（alias で動作・#255 scope 外）。**行き先: 追わない（自然 attrition）**。runtime 警告を将来入れるなら、まずこれら内部呼び出し元を `--brief` へ移行してから、が前提（そうしないと自家警告になる）。→ 将来 warning を検討する時点で別 issue 化。
- board（gitignored・実運用 doc）の `--kickoff` 記述: **行き先: 追わない（自然 attrition）**。brief 明示方針。
- delegate-task skill frontmatter の `description` は「キックオフ送信」の語を残した。**行き先: 追わない**（skill routing 用のマッチ文言で、生成語を変えると trigger 挙動に影響しうるため触らない）。

## closure

- 達成度: **達成**（受け入れ基準 (1)〜(5) 充足。`--brief` 主・`--kickoff` alias 回帰 green・全 test green + shellcheck PASS・doc 一貫・engine 他挙動不変）。
- 次の消費者: PR #255 レビュア（owner / Copilot）。マージ後に delegate-task skill 変更を canonical から sync 配布するのは親統括（gate 6）。
- status: **stable**。
- SO 証跡: `oe-review` verdict=survived / audit_id=`20260717053450V5GMMJJHHJVH`（audit stream は gitignored ゆえ本文へ verdict + sha + hash を転記済み）。
- Step4 辞退: 実行中に失敗・撤回・指摘なし（clean rename + 実装SO survived）で closure 品質 4 観点が低リスク・該当なし / 既存チェックで覆った観点: routing（follow-up 全件に行き先付与）・evidence anchor（SO verdict + reviewed_sha + diff_hash を本文転記）・省略チェック（省略対象の失敗が存在しない）・back-propagation（他文書の欠陥なし） / 未実施観点と判断: なし。

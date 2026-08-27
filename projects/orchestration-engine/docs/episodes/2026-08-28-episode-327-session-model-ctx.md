---
id: "01M123HTHDX7RCDG1EG1X68SNN"
title: "#327 全 Claude セッションのモデル名とコンテキスト% を1つの面に出す — 実行記録"
date: 2026-08-28
type: episode
status: in-development
source: "https://github.com/stlwolf/ai-development-hub/issues/327"
scope: orchestration-engine
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-08-27-plan-327-session-model-ctx.md"
    reason: "本 episode が実行する plan。設計判断 v1〜v4 と反証3周の一次記録もそこにある"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/327"
    reason: "起点。調査結果と方向転換はコメントに一次記録がある"
tags: [engine, cockpit, oe-threads, statusline, heartbeat]
---

# #327 全 Claude セッションのモデル名とコンテキスト% を1つの面に出す — 実行記録

本 episode は **実装着手時（gate 3 通過直後）に枠を作った**。それ以前の経緯（gate 1 と gate 2 を3周回して設計が v1 から v4 まで入れ替わった過程）は plan 側に一次記録があるので、ここでは繰り返さず plan を正本とする。

## 前提（着手時点で確定していること）

- gate 3（owner HG）は 2026-08-28 に通過した。baseline は plan の「HG-1 の記録」節にある（承認 commit `5dabce3`）。
- owner の裁定は3つ。plan v4 を分割せず1単位で通す／4周目の設計SO は回さない（gate 4 の実装SO に任せる）／`.hb.*` の leak は別 Issue（#350）として起票し本単位では直さない。
- 実装はこのセッションが行う（委譲しない）。したがって内側のゲート（自己レビュー・compliance）は生成と同じセッションが担い、独立性は外側のゲート（実装SO・Copilot）が担保する。

## 随時追記

### 2026-08-28 着手

- #350 を起票した（`.hb.*` の temp が 35 件滞留・producer の mktemp から mv までの窓）。本単位では直さない。
- plan v4 を commit し（`5dabce3`）、HG-1 baseline を追記して commit した（`c802aaf`）。

### 2026-08-28 Step 1（producer）完了

sidecar に `model`（`{id, display_name}`）と `server_pid` を additive で足した。テストは 69/0（bash 3.2.57 と 5.x の両方）。既存消費者の回帰も通した（`test_oe_vitals.sh` 77/0・`test_prompt_receipt.sh` 50/0・`test_home_unset.sh` 60/0）。

非自明だったことを3つ残す。

**既存の契約ロック2件が落ちた。** `keys_unsorted | sort | join(" ")` を `"context_pct pane ts"` と固定するアサートが2箇所あり、additive な追加でも落ちる。これは仕様変更の検出として正しく働いた形なので、期待値を5キーへ更新した。**キー集合を固定するアサートは additive を許さない**ので、契約を変えるときは必ずここを通る。

**テストが ambient な `$TMUX` を拾って非決定になる罠があった。** 既存の `run()` は `TMUX_PANE` だけを制御して `$TMUX` は素通しだった。`server_pid` を `$TMUX` から導出するようにした結果、tmux の中でテストを回すとホストの pid が入り、外で回すと空になる。`env -u TMUX` を `run()` の両分岐に足して決定化し、明示指定版の `run_tmux()` を別に用意した。**新しい入力源を env から取るときは、既存テストの env 制御範囲を必ず確認する。**

**生の改行を含む stdin は入力ごと捨てられる（それが正しい）。** `display_name` に生の改行が入った JSON は JSON として不正なので、jq が parse に失敗して write 全体が skip される。sidecar は書かれず temp も残らない。テストで制御文字を入れるときは、コマンド行に生バイトを置かず jq の `implode` で実行時に作る（生バイトを書くと承認ダイアログ側で弾かれる）。

昇級の印: sidecar のキー集合を固定するアサートは additive 変更の検出器として機能する（意図せずそうなっていた）

### 2026-08-28 Step 2（label 解決の lib 切り出し）完了

`oe_reg_list` の中にあった「pane → ラベルと出所」の解決を `_oe_reg_label` として切り出した。`oe_reg_list` の出力は byte 一致で、消費者側のテストも全件パスした（registry 35 / select 35 / status 27 / jump 38 / delegate 55 / send 42 / tree 61 / ident 14）。

**素直な切り出し方をすると挙動が静かに変わる箇所があった。** 元のコードは spawn-registry 段を `[[ -n "$plabel" && "$pparent" == "$self" ]]` で判定しており、**`self` が空かどうかは見ていない**。つまり `TMUX_PANE` が空の環境では、`parent_pane` が空の entry（`oe-register root` で自己登記した root）と空文字どうしで一致し、root のラベルが spawn-registry 由来として採用される。

「観測用途では registry 段を通したくない」を `[[ -n "$self" ]]` のガードで表現すると、まさにこのケースだけ挙動が変わる。そこで **registry 段を第3引数（`use_registry`）の opt-in にして、`self` は素通しにした**。`oe_reg_list` は `1` を渡して従来どおり、観測側は `0` を渡して pane-issue > pane_title の2段になる。

検証は neg-control で行った。mock tmux と隔離した state で、切り出し前後の `oe_reg_list` 出力を `cmp` した。`TMUX_PANE="%1"` の通常ケースと、`TMUX_PANE=""` かつ `parent_pane=""` の root entry を置いたケースの両方で byte 一致した。**後者を測らなければ、この罠は踏んだまま緑になっていた。**

昇級の印: 「条件式が暗黙に空文字の一致に依存している」形は、共通化のときだけ表に出る

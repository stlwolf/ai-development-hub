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

### 2026-08-28 Step 3〜5（verb 実装・テスト・doc）完了

`oe-threads` を実装した。テストは 43/0、既存分も全件パス（producer 69 / registry 35 / home_unset 62 / vitals 77 / prompt_receipt 50）。bash 3.2.57 と 5.x の両方で確認した。

**実装中に自分でバグを1つ踏んで、テストの回帰項目にした。** レコードの区切りに `@tsv` の TAB を使い、`IFS=$'\t' read` で分解していた。**TAB は IFS の空白文字なので、read は連続する区切りを1つに畳む。** 結果、空フィールドがあると以降の列が1つずつ手前へずれる。実際に `pane` が空の unbound 行で `PANE` 列に `server_pid` が出て、`SRVPID` 列にモデル名が出た。

これは表示崩れに見えて実は**帰属の誤り**である。`server_pid` が空の記録（producer 更新前に書かれた既存 175 件がすべてこれ）でも同じずれが起きるので、移行期間中はほぼ全行が壊れていた。区切りを US(0x1f) に変えて解決した（`@tsv` で1行1レコードにしてから TAB を US へ変換する。`@tsv` は値の中の TAB と改行をエスケープするので、変換後の US は区切りだけになる）。

**gate 2 の指摘が予告していた形だった。** codex レーンが「既存 reader は値を `|` 区切り文字列へ投影しているので、MODEL を同方式で加えると外部入力の区切り文字で列がずれる」と書いていた。私は `|` を避けて TAB にしたが、TAB には別の（IFS 空白という）落とし穴があった。**「区切り文字を変える」だけでは足りず、read 側の IFS 意味論まで見る必要があった。**

もう1つ、DJ-E から実装で意図的にずれた点がある。plan は列順を `PANE / CTX / AGE / LABEL / MODEL` として「LABEL は固定幅で切る」と書いていたが、**固定幅の切り詰めは bash の `printf` ではバイト単位になり、日本語や記号（ラベルに実在する ✳）を途中で切って不正な UTF-8 を作る**（#343 / #346 で notify.sh が踏んだのと同じ型）。そこで列順を `PANE / CTX / AGE / MODEL / LABEL` にして、可変幅を最後の LABEL 1つに寄せ、どちらも切らない形にした。切り詰めが要るのは codepoint 上限（表示崩れ防止）だけで、それは jq 側で行う。

昇級の印: 区切り文字の選定は「値に出るか」だけでなく「read 側の IFS 空白か」で決まる

### 2026-08-28 gate 4（実装SO）の指摘を反映

`oe-review --lanes 2 --base master`（audit_id `20260827174044J8NCT322AXG0`・`lens=impl`）は **refuted**。

**codex レーンは2回とも 360 秒でタイムアウトした**（`timeout_empty`・stdout 0 バイト）。弱 SO の partial として disclose して進む（実返却は cursor の1レーン）。#298 と #303 が扱っている事象の追加サンプルになる。

cursor の指摘は3件で、いずれも成立した。

**1. observer 側の server identity を落とすと G3 が主経路で復活する（実在の欠陥）。** 突合条件を `[[ -n "$_rspid" && -n "$SERVER_PID" && ... ]]` と書いていたので、`SERVER_PID` が空だと比較そのものが skip され、別 server の同番ペインが載る。そして `SERVER_PID` は `$TMUX` からしか取っていなかった。**`tmux list-panes -a` は `$TMUX` 不在でも既定ソケットのペインを返す**ので、tmux 外の端末から叩く経路が観測の主経路になりうる。#270 の GC が `#{pid}` を物差しにしているのと非対称だった、という指摘も正しい。

修正は `tmux display-message -p '#{pid}'`（＝`list-panes` に答えた server 自身）から取り、確定できなければ帰属を推測せず exit 2 にした。突合条件からも `-n "$SERVER_PID"` を外し、「比較しない」経路を残さない形にした。

**2. テストがホストの `OE_THREADS_FRESH_SEC` に依存していた。** 隔離4点セットを謳っていたのに帰属窓を固定していなかった。ホストに小さい値が設定されていると G1 と G3 の期待が壊れる。既定と同じ 900 を明示 export した。

**3. SKILL.md に「全 23 verb」と「この 22 は」が同居していた。** 数字の直し漏れ。

**そして修正の検証で、自分の修正が別の劣化を作っていたのを見つけた。** ラベルの key は `<server_pid>_<pane>` なので、`$TMUX` が空だと pane-issue が引けず pane_title へ落ちる。これを直すため `oe-ident:44` の idiom（`TMUX="oe,${pid},0" _oe_reg_key`）をそのまま借りたところ、**`%0` のラベルが空になった**。`_oe_reg_label` は pane_title を引くために tmux へ問い合わせるので、偽の socket 名を掴んで失敗していた。**`oe-ident` でこの idiom が成立するのは、あちらが tmux へ問い合わせず「引けなければ空」で終えるからである。** 借りるときに前提の違いを見ていなかった。

`_oe_reg_label` に第4引数（`server_pid`）を足し、**key の計算だけ**に効かせる形へ直した。tmux 内・tmux 外の両方で同じラベルが出ることを実機で確認し、`oe_reg_list` の byte 一致も維持されている。

昇級の印: 他 verb の idiom を借りるときは「その verb が何を前提にしていないか」を見る（oe-ident は tmux へ問い合わせない）

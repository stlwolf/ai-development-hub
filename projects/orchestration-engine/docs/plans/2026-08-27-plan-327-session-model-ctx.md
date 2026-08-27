---
id: "01M11EDZS1Y6ZNNRS5RYYS49QK"
title: "#327 全 Claude セッションのモデル名とコンテキスト% を1つの面に出す — 実装プラン"
date: 2026-08-27
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/327"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/327"
    reason: "本プランの起点。調査結果と決定は issue コメントに一次記録がある"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/327#issuecomment-5424840129"
    reason: "取得経路・鮮度の実測・突合の難所の一次記録（2026-08-26）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/plans/2026-07-11-plan-239-pr-b-vitals-consumer.md"
    reason: "sidecar の生産者と消費者の契約（本プランは同じ sidecar に additive で足す）"
tags: [engine, cockpit, oe-threads, statusline, heartbeat]
so:
  design: weak
  impl: weak
  reason: "gate 1 と gate 2 がともに refuted を返し、表示面・母集団・共有 lib の判断が入れ替わった。可逆な read-only 表示だが判断の幅は狭くない"
---

# #327 全 Claude セッションのモデル名とコンテキスト% を1つの面に出す — 実装プラン

> v1（`oe-tree` に列を足す）は gate 1 で refuted。v2 は session 主キーの面へ振り替えた（下の「設計判断（v2）」節）。

## Context

- **sidecar は既に在る。** `canonical/claude/statusline/statusline-oe-heartbeat.sh`（#239）が全 Claude セッションで走り、`~/.claude/state/oe-heartbeat/<session_id>.json` に `{ts, context_pct, pane}` を書いている。更新間隔の設定は `refreshInterval: 10`（`canonical/claude/statusline/claude.statusline.json`）。
- **消費者は `oe-vitals` と `oe-selfcheck` だけ。** 表示系（`oe-tree` / `oe-status` / `oe-ident`）は sidecar を読んでいない。コンテキスト% は新たに取るのではなく、既にある値を表示していない。
- **鮮度は実測済み（2026-08-26）。** 27秒間隔の2回サンプリングで、生存6ペインのうち5つが 20〜26 秒進んだ。`%0` の sidecar `context_pct:17` は同ペインの画面表示 `[Opus 5 (1M context)] 18% ctx · 7d 72%` と一致した（1ポイント差は次 tick 待ち）。
- **モデル名は producer の stdin に来ているが sidecar へ書かれていない。** [公式ドキュメント](https://code.claude.com/docs/en/statusline) の全スキーマに `model.id` / `model.display_name` があり、イベント駆動＋`refreshInterval` タイマー・300ms デバウンスで届く。
- **突合には落とし穴が3つある（実測）。** sidecar は 170 件溜まり最古は45日前（GC が無い）。25件（約15%）は `pane` が空。pane 番号は再利用され、`%3` には別 session の sidecar が3件あり `%5` は sidecar があるのにペインが無い。
- **既存テストは行を丸ごと文字列比較している。** `projects/orchestration-engine/tests/test_oe_tree.sh`（474行）の `ck "chain render" ...` 等。列の位置がそのままテスト差分の大きさになる。
- 前提: `oe-*` のうち **`~/bin` への配布対象は `oe-tree` と `oe-hookfire` の2本だけ**（`scripts/sync/sync-bin.sh:64` の `CMD_NAMES`）。それ以外は `projects/orchestration-engine/bin/oe-*` のパスで呼ぶ。起動前に `command -v` で確かめる。
- 本プランのスコープ外: sidecar の GC、`pane` が空になる原因（#338）、`effort.level` / `fast_mode` / `pr.review_state` の表示、`oe-status` / `oe-activity` / `oe-ident` への展開。

## 設計判断（gate 1 で refuted・全件保留）

初期案セットと暗黙の前提を先に列挙する。gate 1（`predecision-exploration`）を通すまで確定しない。

| DJ | 判断 | 初期案 | 暗黙の前提 |
| --- | --- | --- | --- |
| DJ-1 | sidecar のスキーマ | `model` を `{"id":…,"display_name":…}` の入れ子で追加（additive） | 元のペイロードと同じ形なら変換が要らない |
| DJ-2 | 列の位置と欠落表示 | 案A=`alive` の直後に挿入し欠落は `-`（既存テストの期待文字列を更新）／案B=行末に追加し欠落は列ごと出さない | 左から読むので早い位置が良い・テスト更新は機械的 |
| DJ-3 | モデル名の短縮 | `model.id` から導出（`claude-opus-5`→`opus-5`／`claude-opus-5[1m]`→`opus-5[1m]`） | `display_name` は長すぎる・1M 版の区別は id 側にある |
| DJ-4 | 鮮度打ち切り | 既定 60 秒・`OE_TREE_BEAT_WINDOW_SEC` で上書き可 | producer 10 秒周期の6 tick 分あれば足りる |
| DJ-5 | pane 再利用の解決 | 同一 pane の複数 sidecar は `ts` 最大の1件を採る | 最新が現役という仮定 |

## gate 1 の結果（2026-08-27・verdict: refuted）

- 実行: `projects/orchestration-engine/bin/oe-refute --claim tmp/claim-327-dj.md --rubric exploration --lanes 3`
- verdict: `refuted`／reason: 「3/3 レーンが material に反証（conservative 集約）」／audit_id: `20260827110934S6GNQ5KVC5TC`
- output_dir: `tmp/oe-refute-20260827110934S6GNQ5KVC5TC`（永続しないので要点を以下へ転記する）
- レーン: codex（gpt-5.6-sol・168秒）／claude（366秒）／cursor（1回リトライ・286秒）

### 一次確認した反証（SO の主張を私が自分で確かめた結果）

| # | 反証 | 一次確認したもの | 結果 |
| --- | --- | --- | --- |
| R1 | `oe-tree` の母集団は登記に閉じており、#327 を実装しているペイン自身が出ない | 登記は `739__{0,1,2,4,8}` の5件のみ。`pane-issue` には `739__6` が在る。先の `oe-tree` 実行の出力に %6 の行が無い | 成立 |
| R2 | `oe-tree` の read-set は閉じた列挙で、その境界は owner 裁定済み | `bin/oe-tree:40-44` に「読むのは (1) registry / pane-issue (2) tmux query のみ … DJ-223-9・hg-1 裁定済み」と明記 | 成立 |
| R3 | DJ-4 の根拠（producer 10秒周期）は、リポジトリが「実機未検証」と記録した premise | `bin/oe-vitals:27-31` が設計SO の反証として「『idle でも beat 継続』premise は実機未検証」と明記。同じ sidecar の既存窓は 1800 秒（`:89`） | 成立 |
| R4 | producer の `mktemp` / `mv` 経路が temp を leak している | `find ~/.claude/state/oe-heartbeat -name '.hb.*'` が 35 件（中身入り18・空17）。Step 1 が触るのはまさにこの経路 | 成立（当初 `ls` で0件と誤読した。`ls` は eza で書式が違い dotfile を数え落とした） |
| R5 | DJ-5 は episode 239 が Anti-pattern として記録した形の再演 | `docs/episodes/2026-07-11-episode-239-pr-b-vitals-consumer.md:47`「declared と observed を異なる主キーで突合し、片方が best-effort なのに単一 bridge にする → 静かに inert 化。恒久解は declared 側を安定キー（session_id）に寄せる」 | 成立 |
| R6 | DJ-3 の id 短縮は、同じリポジトリで現に事故っている形の予言 | `docs/knowledge/items/01KZXFJCT0QWR8WVMM8BZN7T1S.md:50` が `claude-opus-5[1m]` の角括弧で `unavailable:schema-unexpected` が出ていると記録。今回の gate 1 の `claude-meta.txt` 自身が `model_resolved=unavailable:schema-unexpected` を出している | 成立 |

### 追加で私が実測したこと

- **ALT-B（tmux pane user option）の read 経路は成立する。** tmux 3.5a で `tmux set-option -p -t %6 @oe_probe 'opus-5[1m]|10'` を書き、`tmux list-panes -a -F '#{pane_id} [#{@oe_probe}]'` が `%6 [opus-5[1m]|10]` を返した（他ペインは空・角括弧も素通り）。probe は `set-option -pu` で後始末済み。
- **write 経路の env 前提も揃っている。** ペインの shell と本セッションの env に `TMUX=/private/tmp/tmux-501/default,739,0` と `TMUX_PANE=%6` の両方が在る。statusLine はこの env を継承するので `tmux set-option -p` は呼べる見込み。ただし statusLine 実行時に実際に書けるかは producer への probe が必要（未実測）。
- **pane と session_id を結ぶ写像は、sidecar の best-effort な `pane` 以外に存在しない。** `~/.claude/state/session-named/` は0バイトの marker、`session-branch/` は session 主キーだが中身は `{"last_branch":…}` で pane を持たない。

### 探索木

```text
DJ-2 / 表示面（どこに出すか）
├── 案A: oe-tree の alive 直後に列を挿入（初期案） → 母集団が登記に閉じる(R1)・read-set 再裁定(R2)・26 アサート更新 → 却下: 目的未達
├── 案B: oe-tree の行末に suffix として足す → 既存慣習(oe-tree:533-535)に沿い既存アサート不変。ただし R1/R2 は残る → 部分解
├── ALT-A: session 主キーの平坦一覧（新 verb か oe-vitals --list） → 母集団が producer と一致し R1 が消える → 有力・未検証
├── ALT-C: pane-border（oe-ident 拡張・ambient） → 「見に行かずに」に直答し DJ-2 と R2 が消える → 有力・未検証（tmux 設定1行の opt-in が要る）
└── ALT-D: 表示でなく検知（oe-vitals の scope 拡張＋期待モデルからの逸脱） → 「選ぶ前に気づく」に直答 → 未検証

DJ-1 / 保存先（どこに置くか）
├── 案: sidecar に model を additive（初期案） → 175件走査・GC不在・temp leak(R4) を抱え続ける → 部分解
└── ALT-B: tmux pane user option（@oe_model / @oe_ctx） → DJ-4・DJ-5・GC が構造的に消え、viewer は既存 tmux 1コールに format を足すだけ。read 経路は実測済み。#202 / #188 の stored 却下理由（read 時に導出可能・stale する・宛先解決契約に波及）はモデルと ctx には当たらないので再裁定が要る → 有力

DJ-4 / 鮮度の扱い
├── 60秒で打ち切る（初期案） → 未検証 premise 依存(R3)。静かなセッションほど消えるので目的と逆 → 却下
└── 代替: 打ち切らず age を併記する（ctx は idle でも減らないので古くても真） → 未検証

DJ-3 / モデル名の表示形
├── id から prefix 剥がし（初期案） → 形の予言(R6) → 却下
└── 代替: producer が既に使っている `display_name` をそのまま出し、幅は表示側で切る → 未検証

未探索（今回は開かない）: transcript 経路の実測 / ホスト側 env からの観測 / tmux status-line への集約1行 / 「切り替え忘れ」の実際の発生形（pane 単位か session 単位か）
```

### 帰結

DJ-1 から DJ-5 は**全件保留**。表示面と保存先はどちらも owner 裁定が要る水準（`oe-tree` の read-set 境界の再裁定・#202 の stored 却下理由の再裁定・目的に対する面の選択）なので、確定せず HG-1 へ上げる。以降の Step は面と保存先が決まってから書き直す。


## 設計判断（v2・gate 2 で refuted・下の v3 で差し替え）

owner 裁定（2026-08-27）: **表示面は session 主キーの一覧を先に作る（ALT-A）。ambient（pane-border・ALT-C）は次段へ分ける。** 表示先が #327 本文の想定（既存の4 verb のいずれか）を超えるが、Issue は広げて続ける。

母集団の実測（現 tmux server 739・2026-08-27）がこの裁定の根拠である。

| 母集団 | 件数 | 内容 |
| --- | --- | --- |
| claude が動いているペイン | 7 | %0 %8 %4 %2 %1 %9 %6 |
| fresh な sidecar（600秒以内） | 7 | 上の7ペインと1:1で一致し、`pane` も7件すべて埋まっている |
| 登記（`oe-tree` の母集団） | 5 | %0 %1 %2 %4 %8（%6 と %9 が出ない＝7件中2件を落とす） |

「`pane` 空 15%」は 175 件（45日分・死んだセッションを含む）全体の比率であり、**live な7件では 7/7 埋まっている**。v1 はこの区別をしていなかった。

| DJ | 判断 | v2 の案 | v1 から変えた理由 |
| --- | --- | --- | --- |
| DJ-1 | 保存先 | sidecar を維持し `model` を additive に追加する。pane user option（ALT-B）は次段の候補として保留する | 実測で sidecar の母集団が目的と一致した。ALT-B は #202 / #188 の stored 却下理由の再裁定と statusLine からの write probe が要るので、同一単位に混ぜない |
| DJ-2 | 表示面と置き場 | **新しい read-only verb を作り、sidecar 読取は lib に切り出して `oe-vitals` と共用する**（`lib/so-verdict.sh` と同じ #196 の形）。verb 名は `oe-sessions` を仮案とする | `oe-tree` は母集団が登記に閉じ7件中2件を落とす（実測・R1）。`oe-tree` の read-set 境界は `oe-tree:40-44` で hg-1 裁定済みなので触らない（R2）。案a=`oe-vitals --list` は検知 verb に表示責務を混ぜる／案c=`oe-status` に区画追加は同 verb の read-set を広げる |
| DJ-3 | モデル名の表示形 | producer が既に使っている `display_name` をそのまま出し、幅は表示側で切る | id から prefix を剥がす形は「形の予言」で、同じ事故がこのリポジトリで現に生きている（R6） |
| DJ-4 | 鮮度の扱い | 打ち切らず `AGE` 列で併記する。ctx は idle でも減らないので、古くても真として出す | 60秒打ち切りは未検証 premise に依存し（R3）、静かなセッションほど消えるので目的と逆になる |
| DJ-5 | pane 帰属 | 同一 pane を複数の fresh sidecar が主張したら最新で潰さず `ambiguous` と出す。`pane` が空なら `unbound` と出す | 最大 `ts` の採用は episode 239 が Anti-pattern として記録した形で、誤帰属を検出できない（R5） |
| DJ-6 | 列 | `SESSION`（先頭8桁）/ `PANE`（`%N` / `unbound` / `ambiguous`）/ `MODEL` / `CTX%` / `AGE` / `LABEL`（pane-issue または pane_title から引けたときだけ） | 新規 |

本単位では開かない未探索ブランチ: ALT-B（pane option ストア）・ALT-C（ambient）・ALT-D（検知）・transcript 経路・tmux status-line への集約1行。DJ-2 の verb 名と置き場は gate 2 の設計SO で反証にかける。

## gate 2 の結果（2026-08-27・verdict: refuted）

- 実行: `oe-refute --claim tmp/claim-327-plan-v2.md --lanes 3`（`--rubric consensus`）／audit_id: `202608271135582X2Z67JF61B7`
- output_dir: `tmp/oe-refute-202608271135582X2Z67JF61B7`（永続しないので要点を以下へ転記する）
- 3レーンが同じ3箇所（母集団・共有 lib・出力契約）を指した。指摘はすべて私が一次確認し、10件すべて成立した。

| # | 指摘 | 一次確認したもの | 結果 |
| --- | --- | --- | --- |
| F1 | 共有 lib に pane 突合を入れると DJ-5 と両立しない | `bin/oe-vitals:252-271` が max-ts で潰しており、`tests/test_oe_vitals.sh` の `[18]` が「古い高 ctx を採用しない」で固定している | 成立 |
| F2 | sidecar 消費者は3つある | `bin/oe-selfcheck:48` と `:301` が同じ dir を読む。v2 は `oe-vitals` だけ差し替える計画だった | 成立 |
| F3 | 母集団が受入条件の中で二重になっている | v2 は「打ち切らず全件列挙」と「claude ペイン数と一致」を同時に要求していた。sidecar は 175 件で最古45日 | 成立 |
| F4 | `display_name` を固定幅で切ると 1M 区別が消える | 実体は `Opus 5 (1M context)` で区別情報が末尾にある。DJ-3 の理由と矛盾する | 成立 |
| F5 | `--json` は観測 family の規約ではない | `--json` を持つのは `oe-hookfire` / `oe-selfcheck` / `oe-view` の3本だけ。`oe-tree` / `oe-status` / `oe-activity` / `oe-vitals` / `oe-ident` は持たない | 成立（v2 の根拠は事実誤認） |
| F6 | `oe-*` は PATH に無い、は不正確 | `scripts/sync/sync-bin.sh:64` の `CMD_NAMES` に `oe-tree` と `oe-hookfire` が入っている（配布対象8本） | 成立（Context の記述が誤り） |
| F7 | #322 の HOME 未設定契約が抜けている | `tests/test_home_unset.sh:112` が6 verb を回して `/` の中身が変わらないことを検査している。新 verb は sidecar dir を glob するので同じ罠を踏む | 成立 |
| F8 | producer の契約コメントの「ULID」が誤り | `statusline-oe-heartbeat.sh:10` は ULID と書くが、実データは UUIDv4（`0b5a7cbb-54e6-4977-…`） | 成立 |
| F9 | sync 経路が worktree を指す symlink を張る | `scripts/sync/sync-claude.sh:131` の `ln -sf "${file}"`。worktree から sync すると worktree 削除で全セッションの producer が黙って止まる | 成立 |
| F10 | `orchestration-toolkit` の「全 22 verb」は実数固定 | `SKILL.md:8` に明記。verb を増やすなら数と役割別リストの更新が必須 | 成立 |

`.model` が文字列のとき素朴な jq が落ちること（`Cannot index string with string "id"`）も実測で確認した。型を見てから触る形で回避できる。

## 設計判断（v3・gate 2 再実行で refuted・下の v4 で差し替え）

| DJ | 判断 | v3 の案 | v2 から変えた理由 |
| --- | --- | --- | --- |
| DJ-A | 一覧の母集団 | **鮮度を母集団の基準にしない。** 既定は「tmux に実在する pane を持つ sidecar」の交差集合。`--all` で pane 不在・`pane` 空も出す | 「打ち切らない」と「live 件数と一致」の両立（F3）。pane 実在を基準にすれば、静かなセッションも消えず墓地175件も混ざらない |
| DJ-B | 共有 lib | **切り出さない。** 新 verb は自前で読む。共有化は3消費者（`oe-vitals` / `oe-selfcheck` / 新 verb）の複製が実際に揃ってから別単位で行う | pane 突合の方針が消費者ごとに違う（F1）。`lib/so-verdict.sh` は「複製が既にあり方針も一致」だったので類推が成立しない。単位も小さくなる |
| DJ-C | verb 名 | **`oe-threads`。** #327 本文が「スレッド情報」と呼んでいる語を使い、engine session（ULID）と delegate pane（`%N`）と別の identity 空間であることを名前で固定する | `oe-sessions` は `oe-status` の engine session と取り違える |
| DJ-D | モデル名の表示 | `display_name` をそのまま出し、**幅で切らない**。列は最右寄りに置き溢れを許す（`oe-tree:531` の「長い値は溢れてよい＝正直な degrade」と同じ規約） | 頭切りで 1M 区別が消える（F4） |
| DJ-E | 列と出力契約 | `PANE` / `MODEL` / `CTX` / `AGE` / `LABEL` / `SESSION`（UUIDv4 の先頭8文字・truncate・最右）。`--json` は作らない。`AGE` は `42s` / `3m` / `2h` の人間可読。model 欠落は `-` | `--json` の根拠が偽だった（F5）。SESSION が「桁」でないことと truncate の明示（F8） |
| DJ-F | pane 帰属の競合 | 行を潰さず両方出し、PANE に曖昧マークを付ける（`%4?`）。`pane` 空は `--all` 側にのみ現れ PANE は `-` | 「最新で潰さない」と「PANE 列に ambiguous と書く」は別操作だという指摘 |
| DJ-G | 内部投影の区切り | `|` を使わない。US(`\037`) 区切りか `@tsv` を使い、sanitize を通す | `display_name` に `|` や改行が入ると列がずれる |
| DJ-H | HOME 未設定 | `_oe_state_dir` を使い、決まらないときは #322 の帯に沿って exit 2。`test_home_unset.sh` の verb 列挙に追加する | root glob を踏む（F7） |
| DJ-I | 配布と実機反映 | 本単位では `~/bin` に配らない（`CMD_NAMES` を触らない）。producer 変更の実機反映は **master マージ後に primary tree から** `./scripts/sync.sh claude` を回す | worktree から sync すると dangling symlink になる（F9） |
| DJ-J | 移行前 sidecar | model が無い既存175件は `MODEL` を `-` にする。「全行に MODEL が出る」を受入条件にしない | model は producer 更新後の次の発火からしか入らない。全行に出ることは未検証 premise（idle 発火）に依存する |

本単位では開かない: ALT-B（pane option ストア）・ALT-C（ambient / pane-border）・ALT-D（検知）・transcript 経路・`.hb.*` の leak 修正・共有 lib 切り出し。

## gate 2 再実行の結果（2026-08-27・verdict: refuted）

- 実行: `oe-refute --claim tmp/claim-327-plan-v3.md --lanes 3`／audit_id: `20260827124156VV08JT1HQYFK`
- 3レーンが同じ結論を出した。**v3 は F1〜F10 を形の上では潰したが、F3（母集団の二重）を「鮮度の全廃」で解いたため別の壊れ方に置き換わっていた。**

| # | 指摘 | 一次確認したもの | 結果 |
| --- | --- | --- | --- |
| G1 | 鮮度を全廃すると生存ペインほど墓地を溜めるので既定出力が死体で埋まる | `%0` を主張する sidecar は7件で、うち6件が 3.7〜4.0 日前（`age=4.0日 ctx=97` など）。DJ-F と組むと7行すべてに曖昧マークが付く | 成立 |
| G2 | v3 の最終検証はその出力を全項目パスさせる | 「落ちずに出る」「競合に曖昧マーク」「鮮度で落ちない」はいずれも墓地込みの出力で満たされる | 成立 |
| G3 | sidecar は server identity を持たないので `%N` だけでは別 server と衝突する | sidecar の全キーは `ts,context_pct,pane` のみ。registry は `_oe_reg_server_pid` で `<pid>_<pane>` に名前空間化している。`%205` を主張する sidecar が3件ある | 成立 |
| G4 | `pane` が空の生存セッションは交差で落ちる（owner 裁定の session 被覆と衝突） | sidecar 211件のうち `pane` 空は25件。live 7/7 が埋まっていたのは1スナップショット | 成立 |
| G5 | DJ-D（MODEL を最右）と DJ-E（SESSION が最右）が正面から矛盾する | 可変幅の MODEL を中間列に置くと後続列が行ごとにずれる | 成立 |
| G6 | 生存ペイン起点の列挙と LABEL 解決は既にリポジトリにある | `lib/delegate-registry.sh` の `oe_reg_list` が `tmux list-panes -a` を左辺に回し、LABEL を pane-issue > spawn-registry > pane_title で解決し、sanitize と #322 degrade まで持っている。消費者は `oe-list` と `oe-status` の DELEGATE 区画 | 成立（v2 / v3 の option set に `oe-list` が入っていなかった） |
| G7 | 異常入力の期待値が未定義（`ts` 非数値・負・未来／CTX 非数値／壊れ JSON／model 型違い／tmux 不在） | v3 は「試験する」とだけ書いていた | 成立 |
| G8 | 回帰の証明が足りない（`oe-selfcheck` を回すゲートが無い・HOME 未設定は exit code を誰も見ない） | selfcheck 専用テストは無く、sidecar 検査を持つのは `test_prompt_receipt.sh`。`test_home_unset.sh` は `/` の汚染だけを見る | 成立 |

## 設計判断（v4・gate 2 再実行を反映）

芯は「**鮮度で行を落とさない**」と「**pane 帰属の解決には鮮度を使う**」を分けたこと。v3 は一体で捨てていた。

| DJ | 判断 | v4 | 変えた理由 |
| --- | --- | --- | --- |
| DJ-A | 行の母集団 | **自 server の生存ペインを左辺**にした左外部結合。加えて fresh かつ pane を持たない sidecar を `unbound` 行として末尾に出す | 生存ペイン起点なら行数が pane 数で固定され、ゴーストが構造的に出ない（G1）。`unbound` 行で owner 裁定の session 被覆も満たす（G4） |
| DJ-B | 鮮度の使い方 | 行を落とすのには使わない（pane 行は常に出る）。帰属の解決には使う（fresh window 内の sidecar のみ候補・既定 900 秒・env で上書き可） | 静かなセッションが消える問題は pane 行が常に出ることで解け、判別子は帰属側に残る |
| DJ-C | 帰属の曖昧性 | fresh 候補が1件なら確定。2件以上なら `%4?` の曖昧マークを付け値は出さない。0件なら `-`（claude でないペインか producer 未配備） | 実測では live 7ペインの fresh 候補は各1件で、曖昧は例外として扱える |
| DJ-D | server identity | **producer に `server_pid` を additive で足す**（`$TMUX` の pid・`_oe_reg_server_pid` と同じ導出）。突合は `<server_pid>_<pane>` で行う | sidecar が server を持たないため別 server の pane 番号と衝突しうる（G3）。registry と同じ名前空間に揃える |
| DJ-E | 列 | `PANE / CTX / AGE / LABEL / MODEL`。固定幅を前に置き、**可変幅は最後の MODEL だけ**。LABEL は固定幅で切る（pane-issue 由来で先頭に issue 番号が来るので頭切りでも識別できる）。MODEL は切らない。SESSION 列は出さない | 可変幅が2つ並ぶと行ごとにずれる（G5）。1M 区別は MODEL を切らないことで守る |
| DJ-F | LABEL の解決 | `oe_reg_list` の label 解決を lib に切り出して共用する。`oe_reg_list` の出力は挙動不変（byte 一致で検証） | これから作るのが3つ目の複製になる（G6）。方針が完全に一致するので #196 の共有条件に合う（F1 の失敗＝方針が違うものの共有とは別） |
| DJ-G | 出力書式 | 単一テーブル。read-only 契約ヘッダを付ける（読むのは sidecar / tmux query / pane-issue の3つ。書かない） | typed sections は2基盤を分けるための形で、oe-threads は1つの面なので単表。契約ヘッダは family の規約 |
| DJ-H | 異常入力の期待値 | 下表で確定する | v3 は期待値が無く実装者ごとに割れた（G7） |
| DJ-I | HOME 未設定 | `_oe_state_dir` で決まらなければ exit 2（#322 の帯）。**exit code をテストで検査する** | v3 は検証手段が無かった（G8） |
| DJ-J | `--all` | 残す。役割を「既定＝鮮度で帰属解決」に対して「全 sidecar を AGE 付きで出す」に固定する | 既定が正しくなったので別の役割が生まれた |
| DJ-K | 実機 producer の検証 | 実装中は行わない。受入は fixture で行い、実機確認は master マージ後の owner 目視 | worktree から sync すると dangling symlink になる（F9）。実機検証を捨てることを明示的に受容する |

### 実装で確定した差分（back-propagation・2026-08-28）

実装中に DJ-E から1点ずれた。episode 側に一次記録がある（`2026-08-28-episode-327-session-model-ctx.md` の「Step 3〜5」節）。

- **DJ-E の列順と LABEL の切り詰めを変えた。** plan は `PANE / CTX / AGE / LABEL / MODEL` として「LABEL は固定幅で切る」と書いていたが、実装は `PANE / CTX / AGE / MODEL / LABEL` にして、LABEL も切らない形にした。理由は bash の `printf` の幅指定がバイト単位で、ラベルに実在する多バイト文字（`✳` や日本語）を途中で切って不正な UTF-8 を作るため（同じ型が #343 / #346 で `notify.sh` に起きている）。可変幅を最後の1列に寄せることで、どちらも切らずに整列を保てる。
- ほかに、gate 4 の指摘で **observer 側の server pid を `list-panes` に答えた server から取る**ことと、Copilot の指摘で **read-set 宣言を tmux query 3種に合わせる**ことを足した。どちらも DJ の変更ではなく DJ-D / DJ-G の実装精度の問題として扱った。

### 異常入力の期待値（DJ-H）

| 入力 | 期待 |
| --- | --- |
| 壊れた JSON / object でない sidecar | 候補から除く（pane 行は出る・MODEL と CTX は `-`） |
| `ts` が非数値・負・未来 | 候補から除く（鮮度を満たさない扱い） |
| `context_pct` が非数値 | `CTX` を `-` にする |
| `model` が非オブジェクト（文字列など） | `MODEL` を `-` にする（jq 全体を落とさない） |
| `display_name` に `\|` / 改行 / 制御文字 | sanitize を通して1行に畳む。MODEL は幅で切らないが sanitize の長さ上限は例外にしない |
| tmux 不在 / `list-panes` 失敗 | exit 2（左辺が取れないので空表を「0件」と偽らない・#322 と同じ判断） |
| HOME 未設定 | exit 2 |

本単位では開かない: ALT-B（pane option ストア）・ALT-C（ambient / pane-border）・ALT-D（検知）・transcript 経路・`.hb.*` の leak 修正・sidecar 読取の共有 lib 化。

## Pre-Implementation

- [ ] READ: `projects/orchestration-engine/lib/delegate-registry.sh` の `oe_reg_list` — 切り出す label 解決の範囲を決める
- [ ] READ: `projects/orchestration-engine/bin/oe-list` と `oe-status:164-190` — 既存 DELEGATE 表の消費者。挙動不変の対象
- [ ] READ: `projects/orchestration-engine/lib/sanitize.sh` — 適用順と長さ上限（MODEL を切らない方針との関係）
- [ ] READ: `projects/orchestration-engine/tests/test_oe_tree.sh:1,95,140` — tmux mock と `OE_PANE_ISSUE_DIR` 隔離と時計固定の idiom
- [ ] SURFACE: `.hb.*` の leak（35件）を別 Issue として起票する。**本単位では直さない**

## HG-1 の記録（gate 3 通過・2026-08-28）

owner が plan v4 をそのまま承認した（分割せず1単位・4周目の SO は回さない）。以降の照合はこの baseline を母集団の同一性の基準にする。

| 対象 | 値 | 備考 |
| --- | --- | --- |
| 承認した plan（commit） | `5dabce3efc1b5ae34be8d606672bd1687d1584de` | この commit の内容が承認された版。本節はこの後の commit で追記している |
| 承認した plan（blob） | `130e81357e36eb32651bcadf29a499db841f1085` | 上の commit 時点のファイル |
| ゲート表（`document-format.md`）の commit | `28dcd5ed437e07ce97c8ef42d9c83f5ce05ac47e` | §11 ゲート配置の版 |
| ゲート表（blob） | `484cb487a34126e363c807b47a76370fa793f8e9` | 同上 |
| 委譲時の書面（brief） | 無し | 委譲していない（本セッションが実装する）。3点のうち1点が構造的に存在しないことを明示する |
| digest のアルゴリズムと対象 | git blob（`git hash-object <path>`・SHA-1 over file bytes） | 再計算は同じコマンドで行う。照合の直前に計算した値を承認時の値として使わない |

照合の手順と不一致時の扱い（`invalid-baseline` で判定に入らない）は `unmet-gate-check` が正本。

## HG-1: owner HG（gate 3・plan → 実装）

- [ ] plan v4 を owner に提示して承認を得る（4周目の SO を回すかも owner が決める）
- [ ] baseline を承認の記録と同じ場所に残す（承認した plan / ゲート表の版 / digest のアルゴリズムと対象。照合直前に計算した値を使わない）

## Step 1: producer に model と server_pid を足す

- [ ] `_oe_heartbeat_write` の jq に `model`（`{id, display_name}`）と `server_pid` を追加する（既存キーは不変）
- [ ] `server_pid` は `$TMUX` の pid を `_oe_reg_server_pid` と同じ導出で取る（`$TMUX` 不在なら空）
- [ ] `.model` の型を見てから触る（文字列のとき jq 全体が落ち、既存 `{ts, context_pct, pane}` の書き込みまで死ぬことを実測済み）
- [ ] 契約コメントを更新する（sidecar 内容の定義と、`session_id` を ULID と誤記している `:10` の訂正）
- [ ] `tests/test_oe_heartbeat_producer.sh` に assert を足す（model 正常・欠落・文字列型／`server_pid` 有無／`display_name` に `|` と改行と制御文字）

## Step 2: label 解決を lib に切り出す

- [ ] `oe_reg_list` の label 解決（pane-issue > spawn-registry > pane_title）を lib 関数に切り出す
- [ ] `oe_reg_list` の出力が切り出し前と byte 一致することを確認する（`oe-list` と `oe-status` の DELEGATE 区画が消費者）
- [ ] `tests/test_delegate_registry.sh` の既存テストが全件パスすることを確認する

## Step 3: `oe-threads` を実装する

- [ ] read-only 契約ヘッダを書く（読むのは sidecar / tmux query / pane-issue。書かない）
- [ ] 自 server の生存ペインを左辺に列挙し、`<server_pid>_<pane>` で sidecar 候補を当てる（DJ-A / DJ-D）
- [ ] 帰属は fresh window 内の候補だけで解決する。1件なら確定・複数なら曖昧マーク・0件なら `-`（DJ-B / DJ-C）
- [ ] fresh かつ pane を持たない sidecar を `unbound` 行として末尾に出す（DJ-A）
- [ ] 列を `PANE / CTX / AGE / LABEL / MODEL` の順で出す。LABEL は固定幅で切り MODEL は切らない（DJ-E）
- [ ] LABEL は Step 2 の lib 関数で引く（DJ-F）
- [ ] `AGE` を人間可読で出す（`42s` / `3m` / `2h`）
- [ ] 異常入力を DJ-H の表どおりに扱う
- [ ] HOME 未設定と tmux 不在で exit 2（DJ-I / DJ-H）
- [ ] `--all` を実装する（全 sidecar を AGE 付きで出す・DJ-J）

## Step 4: テストを足す

- [ ] `tests/test_oe_threads.sh` を作る。隔離は `OE_HEARTBEAT_DIR` / `OE_PANE_ISSUE_DIR` / tmux mock / 時計固定（`NOW_EPOCH` idiom）の4点セット
- [ ] 母集団: 生存ペイン起点で行数が pane 数と一致する／墓地 sidecar が既定出力に現れない（**G1 の回帰テスト**）
- [ ] 帰属: fresh 1件で確定／2件で曖昧マーク／0件で `-`／別 server の同名 pane を誤帰属しない（**G3 の回帰テスト**）
- [ ] `unbound` 行が出る（`pane` 空の fresh sidecar・**G4 の回帰テスト**）
- [ ] 列: MODEL が切られない／LABEL が切られる／`display_name` に `|` と改行と制御文字が入っても列がずれない
- [ ] 異常入力を DJ-H の表の期待値どおりに検査する（7ケース）
- [ ] HOME 未設定で **exit 2 になることを exit code で検査する**（G8）
- [ ] `tests/test_home_unset.sh:112` の verb 列挙に `oe-threads` を追加する

## GATE: テスト全パス（bash 3.2 と 5.2 の両方）

- [ ] `test_oe_threads.sh` / `test_oe_heartbeat_producer.sh` / `test_delegate_registry.sh` / `test_oe_vitals.sh` / `test_home_unset.sh` / `test_prompt_receipt.sh`（selfcheck の sidecar 検査を含む）を bash 3.2.57 と 5.2 で実行し全件パスを確認する
- [ ] `shellcheck` を変更した全スクリプトへ実行する

## Step 5: doc を更新する

- [ ] `bin/README.md` の sidecar 契約記述（`{ts, context_pct, pane}` → `model` と `server_pid` を追加）を更新し、`oe-threads` の節を足す
- [ ] `projects/orchestration-engine/README.md` の実行エントリ一覧に足す
- [ ] `canonical/skills/orchestration-toolkit/SKILL.md` の「全 22 verb」を 23 に直し、役割別リストに足す（実数固定なので必須）

## REVIEW: gate 4 実装SO（`so.impl=weak`・実装者抜き・2レーン）

- [ ] `projects/orchestration-engine/bin/oe-review --lanes 2`（codex + cursor）を diff にかける
- [ ] 指摘を修正し、`lens=impl` の audit が残ったことを確認する

## Step 6: PR と Copilot

- [ ] `pr-conventions` に従って PR を作成する（Refs #327）
- [ ] Copilot レビューを依頼し、1ラウンド対応する

## GATE: gate 5 episode closure（マージ前）

- [ ] episode を随時追記で書き、closure を PR レビュー後・マージ前に行う
- [ ] 昇格の判定を closure で埋める（gate 1 / gate 2 の3周の反証が設計級かを独立に問う）

## HG-2: gate 6 マージと後始末（owner）

- [ ] マージは owner が判断する
- [ ] **マージ後に primary tree から `./scripts/sync.sh claude` を回す**（worktree から回すと dangling symlink になる・DJ-K）
- [ ] 実機で `oe-threads` を1回走らせ、live なペインが落ちていないか owner が目視する
- [ ] issue close 判断（keep-open なら明示）・worktree 掃除・昇格判定

## 最終検証

- [ ] 行数が自 server の生存ペイン数と一致する（`unbound` 行を除く）
- [ ] 3.7〜4.0 日前の墓地 sidecar（`%0` に6件実在）が既定出力に1行も出ない
- [ ] fresh 候補が複数のときだけ曖昧マークが付く（全行に付く出力は不合格）
- [ ] `pane` が空の fresh セッションが `unbound` 行として出る
- [ ] 別 server の同名 pane を持つ sidecar を誤帰属しない
- [ ] MODEL が頭切りされず、`display_name` の末尾（`(1M context)`）が残る
- [ ] `display_name` に `|` や改行や制御文字が入っても列がずれない
- [ ] 異常入力7ケースが DJ-H の表どおりに振る舞う
- [ ] HOME 未設定と tmux 不在で exit 2 になる（exit code を検査する）
- [ ] `oe_reg_list` の出力が byte 一致する（`oe-list` / `oe-status` の DELEGATE 区画が不変）
- [ ] `oe-vitals` と `oe-selfcheck` の挙動が変わらない
- [ ] テストが bash 3.2 と 5.2 の両方で全件パスする

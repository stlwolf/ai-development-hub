---
id: "01KWS5J28047ZKDH72CNDPD1NC"
title: "#224 episode — capture サニタイズ核（会話到達 preview の write+read 無害化・第一増分）"
date: 2026-07-05
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/224"
    reason: "長寿命 orchestration セッションで capture 経由の malform 注入が連鎖する問題の第一増分"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/232"
    reason: "本 episode の実装 PR"
  - type: design_so
    ref: "oe-refute exploration / audit 20260705115744F109S5B1ZPT9 (verdict=refuted)"
    reason: "予決定探索: 「oe-activity が唯一の会話面」前提を反証し read-time→write-time へ再導出"
  - type: impl_so
    ref: "oe-review round1 20260705123250AXYFZVVSQ97T (refuted) / round2 20260705124608Q50W2KMZ0A34 (survived)"
    reason: "実装SO: write-only の read-side 穴 + env silent-bypass を検出 → write+read+guard に是正"
  - type: reuse
    ref: "../../bin/oe-tree"
    reason: "sanitize_out（jq -Rrs 主 + tr fallback・出力チョークポイント）idiom を踏襲"
  - type: reuse
    ref: "../../lib/event-bus.sh"
    reason: "OE_EVENT_PREVIEW_MAX の非数値ガード（fail-safe coerce）を OE_SANITIZE_MAX_CP へ横展開"
tags: [orchestration, engine, capture, sanitize, malform, tool-call, predecision-exploration, oe-review, episode]
---

> `reconstructed`: 本 episode は closure 時に作業を振り返って再構成したもの。リアルタイム追記ログではない。

## Context / なぜ

長寿命・ツール密な orchestration 統括セッションで、子ペインの壊れた出力（生の tool-call タグ列・box-drawing・制御文字）が capture 経由で親コンテキストへ注入され、親が自己回帰で模倣して tool-call malform が連鎖・悪化する。本増分はその最大レバレッジの具体核だけを潰す（頻度を下げる反復の第一歩）。着手時の非自明な発見が方針を2度変えた（下記）。

## 事実・失敗（選択的省略なし）

- **予決定探索 SO（oe-refute exploration）が初期案を refuted**。当初「生の会話到達面は `oe-activity` の preview 投影だけ」と実査で結論しかけたが、2/2 レーンが `oe-ack` も同一 `event-bus.preview` field を読んで stderr に echo する（= 2 つ目の consumer）点を指摘。source 直読で confirm。→ 前提が崩れ read-time→write-time へ再導出。
- **実装SO（oe-review）round1 が実装を refuted**（2 material 欠陥・E2E 確認済み）:
  - (A) `OE_SANITIZE_MAX_CP` 非数値だと `jq --argjson max` が失敗→jq 全体失敗→`tr` fallback へ落ち、**tag 無害化ごと silent bypass**（raw preview が jsonl に保存）。
  - (B) read 側（oe-activity/oe-ack）が tag 無害化せず、legacy/破損/write 失敗の raw preview が会話面へ再露出。
  - → env guard 追加 ＋ read-time 併用に是正し round2 で survived。
- 途中、jq の Unicode エスケープで複数回つまずいた（下記 W）。

## 決定と根拠（diff から復元できない why）

- **DJ-4 write vs read（2度転回）**: read-only(初期) → **write-time**(探索: `.preview` は ≥2 consumer が読む共有投影ゆえ event-bus 1 箇所が DRY) → **write+read 併用**(実装SO: write-only は legacy/破損/write 失敗の raw を read 側で止められない)。helper が**冪等**（`< invoke` を再無害化しない・`[court]` は `^court$` に非マッチ・truncate 再適用も同結果）なので二重適用は安全＝belt-and-suspenders が成立。
- **DJ-2 除去 vs neutralize → neutralize**: 削除は文脈が飛び隣接テキストが誤結合し、**誤爆時の被害が「削除=データ喪失」より「変形=軽微な視覚ノイズ」で小さい**。over-removal 懸念（DJ-3 の court）にも neutralize が効く。
- **DJ-3 court は行頭孤立のみ**（`(?m)^[ \t]*court[ \t]*$`）: mid-sentence/複数語行/識別子を守る。tag neutralize が primary、court は補助（same-line malform は tag 側で捕捉）。
- **tag パターンは short + 名前空間の open/close を捕捉**（issue 列挙の3トークンから拡張）: 実装SO cursor の under-capture 指摘を先取り。`<div>` 等は不介入（over-capture ゼロをテストで固定）。
- **env guard は fail-safe coerce**（非数値→既定 4000）: 隣接コード `OE_EVENT_PREVIEW_MAX` と同方針。fail-open（silent bypass）を fail-safe（既定で主防御を必ず効かせる）へ。

## わかったこと（W）

- `event-bus.preview` は audit 本体でなく**既に 100cp lossy な表示用投影**で、`oe-activity` と `oe-ack` の≥2 consumer が読む。この構造把握が「write-time が DRY」の根拠であり、同時に「legacy raw が read 側に残る」穴の根拠でもあった（同じ事実の裏表）。
- jq の Unicode エスケープは**二層**で挙動が逆: `\uXXXX` は**単一**バックスラッシュ（jq 文字列パーサが実文字へ変換→oniguruma はリテラルを見る）、oniguruma native の `\x{HHHH}` は**二重**バックスラッシュ（jq を素通しさせ oniguruma に解釈させる）。box-drawing 範囲は `\\x{2500}-\\x{257f}`（二重）で確定。制御は `[[:cntrl:]]`（native）。
- 安全パラメータ（env）が**主防御を silent に無効化する fail-open** は、隣接コードが同種を既修正でも新規箇所で再発しうる。ゲート（テスト）で env 境界を固定しないと回帰する。

## 原則（negative knowledge 候補・→ #62）

- **Anti-pattern**: 安全変換の閾値/パラメータを外部入力（env）から取り、不正値で**変換全体が例外→fallback で主防御を bypass**する（fail-open）。設定 typo 1 つで防御が丸ごと消える。
- **Pattern**: 不正値は安全側の既定へ coerce し、主防御を常に効かせる（fail-safe）。境界値をテストで固定する。
- **Pattern**: 同一の表示用データを複数 consumer が読むなら、無害化は「write で clean 化」＋「read で冪等に再無害化」の**二重チョークポイント**が legacy/破損/write 失敗を含めて堅牢。冪等性が前提条件。

## 検証（ゲート）

- engine テスト suite **27 ファイル**が **bash 3.2.57 / 5.2.37 両系で green**（#231 の 3.2 互換化を rebase 済み）。
- `test_sanitize.sh`（28 ケース: 無害化/truncate/**誤爆しない**/env guard/jq 不在 fallback）、event-bus write-time、oe-activity/oe-ack read-side、oe-send payload-echo guard、stage-miss ノイズ抑制。
- `shellcheck` rc=0（変更 10 ファイル）。実装SO(oe-review) round2 = **survived**。

## 残課題（routing 済み）

いずれも本 PR スコープ外。行き先を明示する（primary/oe-select/根因/Phase5 は「親への完了報告に併記→親が Issue 化を上位判断」に束ねる。未作成の Issue 番号は親判断待ちで空のまま routing 先を親に固定）。

- **primary malform 経路**（エージェントが生 `wez pane capture`/`tmux capture-pane` を直貼付）の抑止 = behavioral/運用ガイド/エージェント規律。真のレバーだが文字列制御では消えない。→ routing: **親への完了報告に併記 → 親が behavioral guide の Issue 化を判断**。
- `oe-select` の fzf `--preview`（live capture の TUI 描画・event-log 非経由）→ routing: **親報告に併記 → primary 経路と同束で follow-up Issue 化判断**（別データソース。会話ベクタは弱いが未サニタイズ）。
- 根因調査（汚染 vs 長コンテキスト劣化）→ routing: **親判断で別 Issue 化（未作成）**。Phase 5 設計入力は **#105 / #108** に接続。
- tag under-capture 残余（短形 close・大文字 `Court`）→ routing: **PR #232 本文に明記済み（永続行き先）**。低 materiality・observed malform は捕捉済み・観測されたら追加。

## back-propagation

- 親 direction（`.oe/direction-224.md`・gitignore・非永続）の前提「`oe-activity` の preview 投影が**唯一の実在する会話到達面**」は、予決定探索（oe-refute）で**誤りと判明** — `oe-ack` が同一 `event-bus.preview` field を読む2つ目の consumer だった。本 episode/PR は反証後の正しい像（≥2 consumer）で実装済み。親所有の doc は子が改変しないため、**この前提の supersede を親への完了報告で明示**する（source への back-propagation）。

## 蒸留シグナル

- 昇格候補: **negative knowledge（#62）** = 上記「fail-open な安全 env パラメータ」Anti-pattern と「二重チョークポイント＋冪等」Pattern。skill/rule 化までは要さない（1 事例）。Decision 昇格は不要（既存 ADR 方針の適用範囲）。

## closure

- **次の消費者**: 親スレッド（完了確認 + primary 経路の behavioral guide を Issue 化する上位判断）。以後 engine で「会話到達面へ載せる文字列」を扱う作業が `oe_sanitize_conversation` の適用点前例として参照可能。
- **evidence anchor**: SO 出力は `tmp/`（揮発）だが、verdict/reason を本 episode と PR 本文へ転記済み（design SO refuted→write-time / impl SO round1 refuted 2欠陥→round2 survived）。commit/PR #232/テスト suite が永続アンカー。親 direction（方針A・write-time・oe-select は follow-up）は `.oe/`（gitignore・非永続）ゆえ要点を本文へ転記。
- **status**: stable / 達成度: 達成（核サニタイズ landed・全ゲート green・実装SO survived。primary 経路は設計どおりスコープ外）。
- **Step4 外部チェック（closure 品質）**: `so-compare`（codex）で実施。出力 `tmp/so-20260705-215745/`（揮発）。結果＝失敗省略なし・揮発パス問題なしだが、**routing 弱（oe-select/根因の行き先曖昧）と back-propagation 漏れ（親 direction の誤前提を supersede 明示せず）を指摘** → 上記「残課題」の routing 明確化と「back-propagation」節の追加で反映済み。

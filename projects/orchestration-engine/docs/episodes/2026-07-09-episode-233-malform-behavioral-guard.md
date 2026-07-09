---
id: "01KX2AB78TZEPN29KB4H88MKN3"
title: "#233 episode — 生 capture 直貼付 malform の behavioral norm 抑止（#224 の外側・真のレバー）"
date: 2026-07-09
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/233"
    reason: "oe-* の外にある primary malform 経路（統括が生 capture を会話へ直貼付）を behavioral で抑止"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/240"
    reason: "本 episode の実装 PR（A+B norm のみ）"
  - type: predecessor_episode
    ref: "./2026-07-05-episode-224-capture-sanitize.md"
    reason: "#224 episode が『primary 経路の behavioral guide を親が Issue 化判断』と routing → 本 #233 がその follow-up の landing"
  - type: design_so
    ref: "oe-refute exploration lanes=3 / audit 202607081605102VX2QWRM8WBF (verdict=refuted 3/3)"
    reason: "予決定探索: 初期 proposal の『A+B+C を最小として確定』を反証 → de-converge（C は Wez 専用で tmux 委譲 peek を代替不可）"
  - type: impl_so
    ref: "oe-review impl lanes=2 / audit 20260708164506AZXA2AGX6EPC (verdict=survived)"
    reason: "実装SO: doc-only diff に material 欠陥なし"
  - type: bot_review
    ref: "Copilot review on PR #240 (1 line comment)"
    reason: "sanitize.sh 短縮参照 → 実体フルパスへ修正（commit 8f6a0fd）"
  - type: deferred
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "D（決定的 advisory hook）の受け皿（hook 軸・defer）"
  - type: deferred
    ref: "https://github.com/stlwolf/ai-development-hub/issues/105"
    reason: "F（構造的分離・親が raw pane を読まない）= Phase 5 の受け皿"
tags: [orchestration, engine, capture, malform, behavioral, norm, predecision-exploration, oe-refute, oe-review, de-converge, episode]
---

> `reconstructed`: 本 episode は closure 時に作業を振り返って再構成したもの。リアルタイム追記ログではない。

## Context / なぜ

#224 core（PR #232）は oe-* の**会話到達面**（event-bus preview）を write+read サニタイズした。しかし malform の **primary な経路**は oe-* の外にある: 統括が生 `wez pane capture` / `tmux capture-pane` を直叩きして子ペインの生出力を会話へ貼付 → 親が自己回帰で模倣 → tool-call malform が連鎖する。これは文字列制御では消えず、真のレバーは behavioral。#224 episode がこの抑止を「親が behavioral guide を Issue 化判断」と routing し、それが #233 になった。どの behavioral レバーを採るかは未確定（issue 本文で「探索・未確定」）なので二段階＋HG（human gate）で進め、Phase 1 の設計 SO が初期案を反証して方針を変えた（下記）。

## 事実・失敗（選択的省略なし）

- **設計 SO（oe-refute exploration・3レーン）が初期 proposal を refuted（3/3）**。Phase 1 は issue 列挙の3レバー（A 運用ガイド / B エージェント規律 / C 安全 capture 入口 `oe-capture --show`）に zero-base 代替（D 決定的 hook / E paved-road framing / F 構造的分離）を足し、**「A+B+C を最小コアとして確定」**へ収束しかけた。3レーンが material に反証:
  - **cursor**: C（`oe-capture --show`）は **Wez 専用**で、tmux 委譲の主 peek 経路（`%N`）を代替できない → norm の「舗装」が主戦場で破綻。
  - **claude**: doc の A+B に code の C を束ねて「最小」と呼ぶのは真の最小（A+B のみ先行）と矛盾。C を核に入れる決定打が全て speculation（adoption・malform 機序未再現）。
  - **codex**: tmux 経路・oe-select raw capture・oe-capture 契約・D 除外根拠・F routing の一次情報が不足。
- **反証を一次情報で裏取り**: engine の capture は `wez pane capture`（`projects/orchestration-engine/lib/capture.sh:48`）＝Wez 専用。`oe-capture` は pane_id を非負整数に限定し tmux の `%N` を弾く（`projects/orchestration-engine/bin/oe-capture:75`）。委譲/統括層は tmux（`$PARENT_TMUX_PANE=%144`）。→ cursor の指摘は正しく、**C は tmux 委譲 peek の安全代替にならない**。SO を4本目に回さず reconcile（弱 SO 1周規律・lateral 回避）。
- **de-converge**: 「A+B+C を最小として確定」を撤回し、genuine 最小コア＝A+B（環境非依存 norm）／C＝Wez 専用の任意 enhancement（見送り）／scoping は HG 判断、へ再構成。owner が本 pane で直接承認 → 親が正式 HG 承認を中継（`.oe/hg-approval-233.md`）。
- **実装 SO（oe-review impl・2レーン）= survived**（doc-only・material 欠陥なし）。
- **Copilot review**: 1 行コメント — orchestration-toolkit で `lib/sanitize.sh` と短縮参照していた（実体は `projects/orchestration-engine/lib/sanitize.sh`）→ フルパスへ修正（commit `8f6a0fd`）、スレッド返信済み。scope 拡大の指摘はなし。

## 決定と根拠（diff から復元できない why）

- **DJ scoping（2度の収束/反証）**: 初期 A+B+C（最小と主張）→ 設計 SO で refuted → **A+B（norm）のみ実装**・C 見送り・D/tmux-peek/F は follow-up。diff は norm 追記しか見えないので、**なぜ C を核から外したか**はここにしか残らない。
- **なぜ C（oe-capture --show）を核から外したか（本 episode の中心）**: C は既存 sanitize 核を再利用でき、一見「norm が指す明白な安全レール」に見えた。しかし engine の capture 経路は Wez 専用なのに、実際の委譲/統括ペインは tmux（`%N`）。**C が舗装するのは誰も通らない道**（tmux が peek の主戦場）。この **環境 split（tmux 委譲 vs Wez capture）が C を殺した load-bearing な発見**。
- **なぜ新 universal rule でなく駆動層規律へ co-locate**: norm は orchestration 固有（子ペインを覗く統括のみが踏む・solo session は非該当）。canonical/rules（universal）は altitude が違う → `orchestration-toolkit`（概念）＋ `delegate-task`（操作）が正しい置き場。Follow Existing Patterns + Minimal Scope。
- **なぜ norm 規範1（貼らない・要約/path）を load-bearing に**: これは環境非依存（tmux/Wez 双方に効く）ので C の有無に関わらず成立する。C はあくまで Wez 環境の補助。
- **なぜ norm を tool 非依存に書いたか**: 未実装の `oe-capture --show` を norm から断定的に指すと「実体を辿れない doc」になる（Copilot が別箇所の path で指摘した traceability 欠陥と同型）→ norm は「raw を貼らない・要約/path」を主にし、安全 peek 入口は follow-up として1行触れる程度に留めた。

## わかったこと（W）

- **環境 split**: engine の capture は Wez（`wez pane capture`）だが委譲/統括層は tmux（`%N`）で、`oe-capture` は `%N` を弾く。#224 の core（Wez capture の write+read サニタイズ）と、tmux 直叩きを含む behavioral 経路の間にギャップがある。「安全 capture 入口」を Wez で作っても tmux 委譲 peek には効かない。
- **behavioral 問題の不確実性**: adoption は本質的に speculation で、malform 機序も本 Phase では再現していない。この不確実性ゆえ「設計を確定」でなく「HG に scoping を委ねる」形が正しく、設計 SO もまさにそこ（speculation を核にした確定）を突いた。
- **over-convergence を SO が捕まえた**: 初期案セット（issue 列挙3）を鵜呑みにせず zero-base 代替を引いても、なお「A+B+C を最小」へ収束しかけた。設計 SO（生成と物理分離した反証レーン）がそれを material に反証＝predecision-exploration の実例。

## 原則（negative knowledge 候補・→ #62）

- **Anti-pattern**: 「安全な代替 tool」を提案する前に、その tool が**実際の主経路の環境で動くか**を主経路と突合しないまま「paved road / 安全導線」と称する。C（Wez 専用）を tmux 委譲環境の安全導線として確定しかけた＝環境不一致の paved road。
- **Pattern**: behavioral norm は**環境非依存の規範（貼らない・要約/path）を load-bearing** にし、環境固有 tool は補助に留める。tool を「代替導線」と呼ぶ前に適用環境を主経路と突合する。
- **Pattern（process）**: 初期 option set を鵜呑みにせず zero-base 代替を引き、設計 SO に「最小として確定」を反証させる。over-convergence は自己評価でなく物理分離した SO レーンが捕まえる。

## 検証（ゲート）

- 設計 SO `oe-refute`（exploration/3）= **refuted**（audit `202607081605102VX2QWRM8WBF`）→ de-converge。
- 実装 SO `oe-review`（impl/2）= **survived**（audit `20260708164506AZXA2AGX6EPC`・material なし・doc-only）。
- doc/skill 追記のみ＝実行時挙動の変更なし・回帰リスクなし・`shellcheck` 対象なし（シェル未変更）。
- Copilot review 1 コメント（path traceability）→ 修正（`8f6a0fd`）・返信済み・未返信スレッド 0。

## 残課題（routing 済み）

いずれも本 PR スコープ外（HG 承認 scope = A+B のみ）。行き先を明示する:

- **C（`oe-capture --show`）**: Wez 専用で tmux 委譲 peek を助けない → 任意 enhancement として見送り。routing: **PR #240 本文に follow-up 記録済み（永続行き先）**。
- **tmux 側 safe-peek 入口**: capture 抽象の拡張＝別 issue 相当。routing: **PR #240 本文（永続アンカー）＋ 親報告 → Issue 化は親/owner 判断**（Issue 未作成でも PR #240 本文が行き先を保持）。
- **D（決定的 advisory hook・tmux/Wez 双方の raw を検出して nudge）**: routing: **#24（hook 軸・defer）**。
- **F（構造的分離・親が raw pane を読まない）**: routing: **Phase 5 #105 / #108**（issue #233 が明示）。

## back-propagation

- **#224 episode からの継承**: `./2026-07-05-episode-224-capture-sanitize.md` の残課題 routing「primary 経路の behavioral guide を親が Issue 化判断」を本 #233 が受けた。#224 の像は正しく、本 episode はその follow-up の landing＝**supersede でなく継承**なので #224 への訂正 back-prop は不要。
- **親所有 doc の非永続**: `.oe/proposal-233.md` / `.oe/hg-approval-233.md`（gitignore・非永続）。proposal §4 の当初 claim「A+B+C を最小として確定」は設計 SO で refuted → de-converge 済み。要点（verdict / audit_id / de-converge 理由＝Wez/tmux split）は**本 episode 本文へ転記済み**（パス依存しない）。
- **自 diff の欠陥**: sanitize.sh 短縮参照は Copilot が捕捉 → 修正済み。他 doc への欠陥波及なし。
- **sanitize 消費者の語の精密化（Step4 codex 指摘）**: proposal §0 の「sanitize 核の会話面消費者は event-bus のみ（write-time）」は **`oe_sanitize_conversation` の呼び出し箇所**（write-time・`projects/orchestration-engine/lib/event-bus.sh:158` の1箇所・grep で確認）を指す。preview field の**読み手**は `oe-activity` / `oe-ack` の2つで、read 側は別レイヤの US 区切り防御 gsub を持つ（`oe_sanitize_conversation` 呼び出しではない・`lib/sanitize.sh` コメント参照）。よって #224 の write+read 併用像と矛盾しない（「消費＝呼び出し側」と「preview の読み手」で層が別）＝supersede 債務なし。proposal（gitignore・非永続）自体は冒頭に de-converge 通知済みで stale な**決定**は残していない。

## 蒸留シグナル

- 昇格候補: **negative knowledge（#62）** = 上記「環境不一致の paved road」Anti-pattern と「環境非依存 norm を load-bearing に」Pattern。1事例につき skill/rule 化は要さない（norm 自体は既に `orchestration-toolkit` / `delegate-task` へ landed）。
- **predecision-exploration の実例**（SO が over-convergence を捕捉）候補だが、既存の wez-notify option C 例で足りる → **追わない**。
- Decision 昇格: **なし**（既存の driving-layer 規律の拡張であり新規 ADR を要さない）。

## closure

- **次の消費者**: 親スレッド（`%144`・PR #240 の最終状態確認 + **マージは owner**）。以後 orchestration で「子ペイン出力を会話へ持ち込む」作業が本 norm の適用点前例として参照。tmux safe-peek / D の follow-up を検討する人。
- **evidence anchor**: SO 出力は `tmp/`（揮発）だが verdict / reason / audit_id を本 episode と PR #240 本文へ転記済み。commit `a32749c` / `8f6a0fd`・PR #240 が永続アンカー。親 doc（`.oe/`・gitignore）は要点転記済み。
- **status**: stable / 達成度: **達成**（norm landed・両 SO 通過・Copilot 対応済み。C/tmux-peek/D/F は設計どおり follow-up）。
- **Step4 外部チェック（closure 品質）**: `so-compare`（codex + claude・2/2 成功）で実施。出力 `tmp/so-20260709-111341/`（揮発）。結果＝**4軸すべて実質 PASS**（選択的省略なし〔3レーン dissent と逐語一致〕・全 follow-up に routing あり・揮発パス単独依存なし・back-propagation は #224 継承と正判定）。codex が「proposal §0 の『sanitize 核の会話面消費者は event-bus のみ』が #224 の read 側像を過小に読める」と指摘 → 下記 back-propagation に語の精密化を追記（proposal は gitignore・非 PR ゆえ episode 側で明示）。claude が挙げた「Step4 の stdout が空」は so-compare 完了前の transient 観測で、実際は 2/2 成功（本文の verdict が正）。

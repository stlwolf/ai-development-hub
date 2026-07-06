---
id: "01KWVNPRZXZREFXSPR416XNRBN"
title: "#101 episode — reviewer marker false-positive 抑制（走査側修正は不可・prompt A に確定）"
date: 2026-07-06
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/101"
    reason: "reviewer が review 本文で @@OE_VERIFY marker を引用すると verdict と誤検出する false-positive の抑制"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/237"
    reason: "本 episode の実装 PR（prompt A 緩和 + 回帰テスト・DONE_WITH_CONCERNS）"
  - type: design_so
    ref: "oe-refute exploration / audit 20260706090509B9QFVCX0YBES (verdict=refuted 2/2)"
    reason: "予決定探索: 当初の C-local『最終非空行のみ/EXIT-gating』案を反証（回帰破壊+postamble FN）"
  - type: impl_so
    ref: "oe-review round1 20260706111920NRDX1GRYZSJD (refuted) / round2 20260706113203ZAYPFSZ4HS6R (refuted・deferred 残差)"
    reason: "実装SO: round1 で C′ の不可逆 FN 回帰を検出→C′ 棄却。round2 は #93 へ deferred した残差への指摘"
  - type: follow_up
    ref: "https://github.com/stlwolf/ai-development-hub/issues/93"
    reason: "機械的完全抑制（nonce/sentinel）は本 issue の範疇。#101 のスコープ外として routing"
  - type: constraint
    ref: "../../lib/capture.sh (F-SO-5 / #115) / ../../lib/constants.sh:14"
    reason: "共有走査コアと #115 正規表現緩和は不変（target/monitor は VERIFY に反応しない・#112 回帰維持）"
tags: [orchestration, engine, verify, marker, false-positive, predecision-exploration, oe-refute, oe-review, negative-knowledge, episode]
---

> `reconstructed`: 本 episode は closure 時に作業を振り返って再構成したもの。リアルタイム追記ログではない。

## Context / なぜ

Step 4-4 Phase C.5 で reviewer（Compliance Review agent）の出力取得を viewport scrape から
file-redirect（`tee /tmp/oe-{rsid}-reviewer.log` の末尾 5000 行走査）へ切替えた結果、走査範囲が
本文全体に拡大した。reviewer が review 本文中で `@@OE_VERIFY:{pass|fail|warn}` marker 文字列を
独立行として引用・例示すると、共有走査コア（`capture.sh:_oe_capture_scan_parse`）の「全行の最後の
一致が勝つ」ロジックがそれを verdict として拾い得る false-positive がある（#101）。制約: 触れるのは
`lib/verify.sh`（+ 必要なら `constants.sh`）のみ、テストは `tests/test_verify.sh`（並列作業と衝突回避）。

## 作業の弧（失敗・撤回を含む）

1. **grounding**: 実マッチは `verify.sh` ではなく共有 `capture.sh:_oe_capture_scan_parse`。VERIFY 正規表現は
   #101 起票時の strict `^@@OE_VERIFY:...$` から **#112（PR #115・commit 8ba2e80）で先頭/末尾空白許容へ緩和済み**（FP 面はむしろ拡大）。
   reviewer は `claude -p ... --output-format text`（非対話）で `2>&1` 併合、shell が末尾に `@@OE_EXIT` を後置。
2. **予決定探索（oe-refute, refuted 2/2）**: 当初案「C-local = reviewer 走査で『最後の @@OE_EXIT 直前の
   最終非空行のみ』を verdict とする」を claim 化して反証。**棄却理由**: (a) `test_verify.sh:682-684` が
   EXIT 不在でも VERIFY 検出を要求 → EXIT-gating は回帰破壊、(b) `2>&1` 併合の postamble/prose が verdict 後に
   来ると「最終非空行」規則は **false-negative**、(c) strict 復帰は `test_verify.sh:676-679`（字下げ検出必須）を破壊。
3. **実測での reframe**: FP を2ケースに分解。**Case1**（引用が verdict の *前*）＝現行 last-match-wins が
   *既に* genuine を返す＝FP なし。**Case2**（引用が verdict の *後*）＝位置規則でも判別不能。
   → 「走査側 positional 修正は Case2 を解けない」と確定。
4. **確定（user 承認）**: prompt A（task.description に引用禁止制約）+ 保守的 C′（VERIFY を「最後の @@OE_EXIT
   より前の最後の一致」へ限定＝post-EXIT 混入除外）+ 残差を #93 へ。実装しテスト green（120 PASS 両系）。
5. **実装SO round1（oe-review, refuted）**: cursor が **C′ の不可逆 FN 回帰**を検出。reviewer が本文で
   `@@OE_EXIT` を引用しストリーミング途中で観測されると、C′ は「最後に見えた EXIT」を本文引用と誤認して
   genuine verdict（その後にある）を空にし、`exit_without_verify_marker` で **不可逆に検証失敗**させる。
   実測で再現（`VERIFY='' EXIT='0'` → 共有コアなら `pass`）。**C′ を撤回**。
6. **C′ の便益が到達不能と判明**: C′ の唯一の便益「real EXIT より後ろの marker を無視」は、shell が
   subshell 末尾で EXIT を後置し以降何も書かない実パイプラインでは **物理的に到達不能**。純負債のため削除。
7. **実装SO round2（oe-review, refuted / cursor は survived）**: codex が「#101 の FP は実コード上まだ到達可能・
   追加テストも安全クラスのみ」と指摘＝**意図的に #93 へ deferred した残差**そのもの（新規欠陥ではない）。
8. **確定（user 承認）**: prompt A のみ + 回帰テスト + 限界の in-code 明示で DONE_WITH_CONCERNS。機械的完全抑制は #93。

## 決定と根拠（棄却案）

- **棄却: C-local「最終非空行/EXIT-gating」** — 回帰破壊（676/684）+ postamble FN。予決定 oe-refute で確定。
- **棄却: C′「最後の @@OE_EXIT より前に VERIFY 限定」** — 便益（post-EXIT 無視）は実パイプラインで到達不能な一方、
  本文 `@@OE_EXIT` 引用 × ストリーミング途中で **不可逆 FN 回帰**を新設。実装SO round1 で確定。
- **棄却: strict 正規表現復帰** — `test_verify.sh:676-679`（#112 字下げ検出）破壊。
- **棄却（今回）: nonce/sentinel** — Case2 を機械的に潰せる唯一手段だが kickoff が明示的にスコープ外（大改修回避）。→ #93。
- **採用: prompt A** — 走査ロジック不変。引用が verdict 前なら共有コアが既に genuine を採り、verdict 後の
  単独行引用だけが残差（確率的にプロンプトで抑制）。低リスク・スコープ内・回帰なし。

## わかったこと（W）

- **free-form な単一バイトストリーム上では、位置・正規表現だけで「genuine な最終 verdict」と「本文引用の
  marker 行」を判別することは原理的に不可能**（#112 が「単独行エコーは識別不能」と一次記録済み。`so-verdict.sh` の
  verdict 抽出も last-match-wins + prompt 依存で同じ限界）。out-of-band 信号（nonce/sentinel）が要る。
- 現行 `last-match-wins`（共有コア）は、reachable な全ケースで position ベース案と同等以上（quote-before-verdict は
  正、postamble に強い、quote-after-verdict はどの位置案でも同じく誤る）。→ 走査側に「改善余地」は無い。
- #112（PR #115）の空白許容緩和は TUI 字下げ対応の意図だったが VERIFY にも適用され、字下げ code-block 引用まで
  一致させ FP 面を拡大した（ただし #112 回帰テストが字下げ検出を要求するため単純な revert は不可）。

## 原則（negative knowledge / Pattern 対）

- **Anti-pattern**: LLM の自由文出力から「制御 marker」を位置・正規表現ヒューリスティックで確実に抽出しようとする
  （本文引用と genuine を判別できず、位置を締めると postamble/echo で FN を作る二律背反に陥る）。
- **Pattern**: 制御 marker は **out-of-band 信号**（per-session nonce / sentinel 区切り / 別チャネル）で
  genuine を確定し、本文引用と構造的に分離する。それが取れない段階では **プロンプト制約（確率的抑制）+ 限界の明示**に
  留め、機械的完全抑制は nonce 化 issue へ routing する。

## 蒸留シグナル

- **negative knowledge 候補（→ #62）**: 上記 Pattern 対（marker 抽出の位置ヒューリスティック二律背反 → out-of-band）。
  転用可能（他の marker 系＝@@OE_EXIT/@@OE_BLOCKED、SO verdict 抽出にも同型）。本 episode をソースに #62 消費側へ。
- Decision/skill/rule 昇格: 現時点では **なし**（原則は negative knowledge 止まり）。

## 残課題（routing 済み）

- **#93（nonce/sentinel による機械的完全抑制）**: Case2（verdict 後の bare 単独行引用）と「genuine verdict 不在時に
  本文引用を verdict と誤記録」の完全抑制。本 episode の実装SO round2 refuted の実体はこれ。→ #93 で対応。
- **#101 の状態**: prompt A 緩和 + 回帰テスト + 限界明示で **DONE_WITH_CONCERNS**（FP 残差は意図的に #93 へ deferred）。
  #101 を close するか #93 に統合するかは親/人間判断（本 PR では close しない）。
- **back-propagation（#101 本文）**: issue #101 は strict 正規表現 `^@@OE_VERIFY:...$` を前提に書かれているが、
  実コードは #112（PR #115）で緩和済み。かつ issue 推奨の「中期 C（末尾非空行のみ scan）」は本 episode の反証で
  **回帰破壊+FN のため不可**と判明。→ 本 PR 本文で開示し #101 へ前方参照。#101/#93 へのコメント反映は
  follow-up（人間/親判断）。

## closure gate

- Context / なぜ: 上記（自己完結）。
- 次の消費者: **#93 の実装者**（本 episode の「わかったこと/原則/残課題」が nonce 化の設計前提）。および #62 negative-knowledge 注入。
- follow-up routing: すべて付与済み（#93 / #101 状態 / #101 本文 back-prop）。行き先なしの残課題なし。
- status: stable / 達成度 = **部分**（in-scope 緩和は達成、機械的 FP 抑制は #93 へ deferred）。
- evidence anchor: SO 出力は非永続 `tmp/` のため verdict/reason を本文へ転記済み。audit ID:
  予決定=`20260706090509B9QFVCX0YBES`、実装SO round1=`20260706111920NRDX1GRYZSJD`、round2=`20260706113203ZAYPFSZ4HS6R`。
- SO 証跡リンク: 上記 related.design_so / related.impl_so。
- Step4 外部チェック（closure 品質 so-compare, codex+claude 2/2）: 4観点すべて PASS（失敗の選択的省略なし・
  follow-up 全件 routing・揮発参照は audit ID で代替・back-prop 実質的）。出力 `tmp/so-20260706-212230/`（非永続）。
  指摘の周辺 nit（緩和の帰属 #115→#112/PR #115）は本 closure に反映済み。

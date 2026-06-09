---
id: "01KTNXQCK8YSZ8R1FPDJCMZ4KH"
title: "oe_send_line 送信信頼化計画 — transport 据え置き + 観測ベース finalize（staged_idle 回復）"
date: 2026-06-09
type: plan
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/144"
    reason: "本計画の傘 Issue（Enter 吸収・stage 不達の根治調査）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-06-08-episode-oe-delegate-redesign.md"
    reason: "症状・dogfood・緩和A導入の出自（#142）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/114"
    reason: "対話 TUI は入出力とも本質的に脆い、という共通洞察（本件は入力側）"
  - type: design_context
    ref: "projects/wezterm-ai-mode/lib/pane.sh"
    reason: "単一書き込み送信の先行事例（c2 として検討→ギャップ除去リスクで見送り）"
tags: [orchestration, oe-send, delegate-send, tmux, ingestion, enter-absorption, finalize, plan]
---

# oe_send_line 送信信頼化計画 — transport 据え置き + 観測ベース finalize（staged_idle 回復）

> 駆動層: findings → so-gate v1 → 診断スパイク → so-gate v2/v3/v4/v5 → **本書（v5 最終指摘反映＝実装着手版）** → 承認 → 実装。so-gate v5 で 3者合意（approach 一致・未解決 critical risk 無し・残点は同 PR 吸収可）。

## 1. Context / 問題

`oe_send_line`（`lib/delegate-send.sh`、`bin/oe-send`/`bin/oe-delegate` が使用）は tmux `send-keys` で Claude Code 対話 TUI へ1行注入する transport。#142 dogfood で2症状が**間欠的**に顕在化:

- **Enter 吸収**: テキストは入力欄に staged されるが Enter が効かず未 submit。手動 Enter で submit。
- **stage 不達**: 稀にテキスト自体が入力欄に残らない。

現状は緩和策A（Enter 前 `sleep ${OE_SEND_ENTER_DELAY:-0.3}`）のみ。オーナー判定: 明示 `--no-enter`（ステージのみ）は仕様 OK だが「自動(Enter)のはずが届かない」のはバグ＝信頼化対象。

## 2. so-gate の経緯（v1→v5 で五度の反証）

- **v1**: bracketed-paste(a) 主軸 → `?2004h` 依存劣化で撤回。
- **v2**: c2（単一 paste）主軸 + 冪等 finalize → ②過剰主張・finalize 冪等の二重 submit を指摘。
- **v3**: finalize「安定」定義が論理反転を捕捉。c2 は `sleep 0.3` 防御ギャップ除去で①timing 型なら負荷下悪化（検証不可）。
- **v4**: B1（baseline/edge が発火に無効＋子ビジー→staged_idle 二重 submit 経路）／B2（吸収 vs 遅延配送を区別不能＝finalize 純便益の符号は settle 窓次第）。
- **v5**: 主要 blocking は解消。残: settle 窓が staged_idle 発火を実際にゲートするか未確定／`base_staged` 過剰主張／payload literal 判定未定義 → **本書で確定**（3者合意）。
- **決定**: transport 据え置き継続。finalize は **settle 窓を発火ゲートに使う**形へ確定し、射程を「**観測可能な staged_idle の after-the-fact 回復**」に honest 限定。

## 3. 診断スパイク（2026-06-09 実機・throwaway claude 2.1.169 / tmux 3.5a）

clean throwaway claude を spawn し `pipe-pane` でエスケープ列を観測。生ログ `/tmp/oe-spike-144/`（揮発）。

| # | 検証項目 | 結果 | status |
|---|---------|------|--------|
| S1 | submit 信号と画面領域 | 入力欄＝`❯` 行（`tail -1`）。**"esc to interrupt" は `❯` 行と別行（最下部 status 行）**＝scrape は2領域。`C-u` reset 可 | verified（実機 capture） |
| S2/S3 | bracketed paste mode | idle/通常処理中 `?2004h` 維持、`?2004l` は claude 終了時のみ | verified（pipe-pane ログ） |
| S7 | baseline 再現（Enter 吸収） | delay=0・長め payload・12回 → 12/12 submit・absorbed 0 | verified（実機・clean idle） |
| S8 | baseline 再現（stage 不達） | literal 20回 → 20/20 着弾・miss 0 | verified（実機・clean idle） |
| S6 | paste 検知の方式 | clean idle では raw send の CR は keystroke として submit | unverified-summary（推論。負荷時/modal の timing 未観測） |

**結論**:
- clean throwaway では2症状とも**再現不能**＝比較失敗率の計測は不能、機構は論証で選ぶ。[verified（再現試行）]
- **① 完全除外は主張しない**（前提 S6 が unverified、負荷時 timing 型併用は否定不可）。[unverified-summary]
- **② も断定不可**（再現できず、race が claude 内部なら transport 変更で閉じない）。[unverified-summary]
- → **transport を変える根拠は確証に至らない**ため据え置き、finalize を主柱に（射程は staged_idle 回復に限定）。

## 4. 決定した方向（実装着手版・承認待ち）

- **transport 据え置き**: `send-keys -l text` → `sleep ${OE_SEND_ENTER_DELAY:-0.3}` → `send-keys Enter`。緩和A の 0.3s ギャップは第一線防御として維持。c2/`;` は 0.3s 除去の賭け＋global buffer 副作用で見送り。
- **観測ベース finalize を主柱（既定ON・保守的）**: 既存送信は変えず後段に検証層を追加。**射程は「観測可能な staged_idle（＝settle 窓終端まで入力欄に残る吸収）の after-the-fact 回復」に限定**。一次発生は減らさない。「機構非依存に救う」とは主張しない（**吸収＝Enter が消費される場合に救う／遅延配送型では settle 窓が短いと二重化し得る**）。
- **settle 窓 = 中心安全パラメータ**（v4 B2/B4・v5 確定）: 「妥当な配送/描画遅延の最悪値より長く待ち、窓終端までなお staged なら真の吸収」とみなし**窓が発火を実際にゲートする**設計。窓を伸ばす＝二重 submit に安全だが回復が遅延、のトレードオフを明示（§7）。

## 5. 実装計画（`lib/delegate-send.sh` 中心・1論理変更=1PR）

### 5.1 観測ベース finalize（状態機械・主柱）
既存送信ロジックは不変。`send_enter≠0`（auto）かつ `OE_SEND_FINALIZE≠0` の時のみ後段で実行。

**送信前 baseline capture**（ガード・v4 B1/N2）:
- [ ] `base_proc` = 処理インジケータ領域に "esc to interrupt" が**既に出ているか**（子が送信前からビジーか）。
- [ ] `base_staged` = 入力欄領域に**既存の内容があるか**。

**scrape は2領域を別々に抽出**（v4 B3・S1）:
- [ ] 入力欄領域（`❯` 行＝payload 有無・空判定）と 処理インジケータ領域（最下部 status＝"esc to interrupt" 検知）を別関数で。入力欄限定にして processing 検知を落とさない。
- [ ] payload 一致判定は**リテラル部分一致**（`grep -F` 等・正規表現解釈しない＝メタ文字 payload で誤判定しない・so v5）。

**poll（窓が staged_idle 発火を実際にゲートする・v5 最重要確定）**:
- [ ] 送信後、間隔 `OE_SEND_FINALIZE_INTERVAL`（既定 0.3s）で `OE_SEND_FINALIZE_TIMEOUT`（既定 3s・**中心安全パラメータ＝発火をゲートする窓**。負荷時は伸ばす）まで poll。
- [ ] **早期 exit は submit 確証時のみ**（happy path に全窓を課さない）: payload を一度 staged 観測後に入力欄が空、または処理インジケータが **edge**（`base_proc=false`→present）で出現 → `submitted` 確定で即 exit。
- [ ] **`staged_idle` 発火は早期 exit しない**: payload が**窓終端まで quiescent に staged 継続**（直近 K 読み不変＝`OE_SEND_FINALIZE_STABLE` 既定3、かつ全窓 staged）の時のみ。K=終端安定の最小読み数、TIMEOUT=真の安全窓 → 遅延配送の Enter は窓内に着弾→submitted→撃たない、で安全側（v4 B2）。
- [ ] quiescence 比較は**入力欄領域の実揮発要素**（カーソル/placeholder 等）を正規化（status 領域のタイマー "Crunched 4m15s" は別領域＝混同しない・v4 N1/Nit）。

**安定状態の分類と発火**（finalize 追加 Enter は **1 呼び出しにつき最大1回**）:
- [ ] `submitted`（payload を staged 観測後に消失 or edge processing） → **撃たない**。
- [ ] `staged_idle`（payload が**窓終端まで** quiescent に staged・processing でない・**かつ `base_proc=false`・かつ `base_staged=false`**） → **Enter を1回**（吸収の回復・本命）。
- [ ] `stage_miss_suspect`（payload を一度も staged 観測せず入力欄が空・edge processing 無し） → **warn のみ・撃たない**（§5.2）。
- [ ] `unknown`（窓内に終端安定せず／折返しで payload 不可読／capture-pane 失敗（v4 N5）／`base_proc=true`／**`base_staged=true`＝無条件 unknown**） → **撃たない**（保守）。
- [ ] 発火後ループしない。

**明記事項**:
- [ ] 「冪等」「受け手非依存」「確実に防ぐ」は使わない。実態は **Claude TUI screen scrape ベース・best-effort・保守的**。
- [ ] **finalize は全ブランチで transport の rc を変えない**（capture-pane 失敗・unknown 含む）。rc を漏らすと呼び出し側が再送→二重 submit（v4・so v5）。
- [ ] **`base_staged` の射程**: `base_staged=true` は finalize を撃たないだけ。**元 Enter（transport 本体）が既存内容ごと submit する挙動は finalize では防げない**（transport レベルの既存条件＝射程外）。「finalize による追加誤 submit を足さない」までが正確（so v5）。
- [ ] "esc to interrupt" は claude 2.1.169 観測の **version 依存 magic string** → 定数化＋バージョン注記。
- [ ] 残存 race: 配送遅延 > settle 窓のとき finalize 発火後に元 Enter 着弾＝二重 submit が病的負荷下で残る（§7）。
- [ ] `OE_SEND_FINALIZE=0` で finalize 層を完全無効（capture も追加 Enter も stage_miss warn もしない）。

### 5.2 stage 不達の warn（観測性のみ・rc 不変・v4 N4）
- [ ] `stage_miss_suspect`（§5.1）で **warn ログのみ**・**rc は変えない**（false positive で非0→呼び出し側再送→二重 submit を防ぐ）。
- [ ] **warn の限界を明記**: benign 高速 submit も "neither" に見え false-positive・子ビジー+吸収+staged は warn が出ず無言ロス。観測補助であり信頼判定でない。`unknown` とはログ上区別。

### 5.3 既存契約の維持
- [ ] transport（send-keys 順序）・`--no-enter`（ステージのみ・finalize 不発火）・改行 fail-fast・tmux 不在・pane 生存チェックは不変。`OE_SEND_ENTER_DELAY` 維持（obsolete でない）。
- [ ] baseline capture / finalize は **auto（`send_enter≠0`）時のみ**。finalize は **rc を変えない**（§5.1 再掲・全ブランチ）。

### 5.4 テスト
- [ ] tmux モックに `capture-pane`（**時系列の戻り値を差替え可能に**＝配列/カウンタで連続 capture をモック・stderr warn とラベル取得口も用意・so v5）を追加し、**finalize 分岐の計算ラベルを assert**（v4 T1: 発火有無でなく `submitted/staged_idle/stage_miss_suspect/unknown` のラベルを検証）:
  - (a) staged 観測後に空＝submitted→撃たない / (b) staged_idle（base_proc=false・窓終端まで staged）→1回 / (c) **baseline busy→後に staged_idle**＝unknown→**撃たない**（v4 T2・B1） / (d) processing edge→撃たない / (e) payload 不在・未staged＝stage_miss_suspect→warn のみ rc 不変 / (f) 折返し部分不一致＝unknown→撃たない / (g) **既存 base_staged 有**＝無条件 unknown→撃たない（v4 N2） / (h) capture-pane 失敗＝unknown→撃たない・**rc 不変**（v4 N5） / (i) **K 安定後に遅延 submit**（staged×K → empty）＝**窓終端まで staged 継続せず submitted**→撃たない（so v5・読み①/②識別の決定的ケース） / (j) **正規表現メタ文字 payload** のリテラル一致（`grep -F`）で誤判定しない。
  - **finalize 単発ガード**: **1 回の `oe_send_line` 呼び出し内で finalize 追加 Enter は最大1回**（呼び出しごとの元 Enter は当然必要・so v5 で文言修正）。**注記: プロセス内ガードの確認に過ぎず、元Enter×finalizeEnter の実 race は mock で検証不能**。
  - `OE_SEND_FINALIZE=0` で capture・追加 Enter・stage_miss warn が一切発生しないこと。
  - 揮発文字正規化（入力欄領域の揮発要素混入でも quiescence 到達）（v4 N1）。
  - 既存ガード（改行 reject / dead pane / list-panes fail / pane 必須 / `--no-enter` で Enter 撃たない）の回帰。
- [ ] `shellcheck` clean。
- [ ] **テストの限界**: mock は発行と分岐ラベルを見るだけ。実 submit・実 race・二重 submit 不在・scrape 領域×processing の実レイアウト整合は**原理的にユニット検証不能＝dogfood 専管**（v4 B3）。

## 6. ゲート / 検証（実行義務・interleave）
- [ ] `shellcheck` + `tests/test_delegate_send.sh` を**PR 前に実走**（test plan 実行）。
- [ ] dogfood（実機 gate）: finalize が staged_idle 吸収を救う・子ビジー時に撃たない・happy path で早期 exit・`--no-enter` 不変。**狭幅/日本語/正規表現メタ文字 payload**・**settle 窓(3s)の calibration**（K×INTERVAL≪TIMEOUT の罠を避ける・3s 維持/延長の判断基準を記録）。間欠ゆえ「消去の証明」でなく**回帰なし + 機構論証**で評価。
- [ ] PR 作成 → Copilot レビュー対応。
- [ ] episode 追記（`2026-06-08-...redesign.md` 末尾 or #144 独立 episode を分量で判断）。

## 7. リスク / Open questions（対称な honesty）
- **根治の証明は不可** [verified（再現不能）]。observed staged_idle 吸収を best-effort 回復し**確率を下げる**もの。一次発生は減らさない（transport 据え置き）。
- **finalize の純便益の符号は settle 窓に依存** [unverified-summary]（v4 B2）: 吸収（消費）なら正、遅延配送型なら窓が短いと二重 submit に反転。窓を**発火ゲート**にして安全側へ寄せるが、配送遅延 > 窓の病的ケースは irreducible。
- **吸収が負荷相関なら finalize の実効回復は小さい可能性** [unverified-summary]（so v5）: S7/S8 は clean idle で吸収を再現できず＝吸収は負荷/timing 相関の疑い。一方 finalize は `base_proc=true`（子ビジー）を撃たない＝**吸収が最も起きやすいと疑われる busy レジームを回復も警告もせず素通り**。回復対象は idle-baseline の吸収に限られる。
- **finalize の新リスク（二重 submit）も間欠で clean dogfood に出ない**。「fix が効いた証明不可」かつ「新バグ不在も証明不可」を episode/PR に**対称に明記**。
- **settle 窓 3s は provisional**（再現不能で遅延分布を測れず）。dogfood calibration をゲート化（§6）。
- **"esc to interrupt" magic string** は claude バージョン依存（定数化で保守）。
- **modal 状態未検証**（権限プロンプト/plan-wait の入力受付）＝③readiness。子ビジー扱いで撃たず stage 残存（warn で観測）。
- **再現不能の根本未解決**: ① timing 型併用の有無 / race の所在（pty か claude 内部か）は buggy 再現なしには解決不能。

## 8. スコープ外
- transport の変更（c2 / `;` バッチ）＝再現不能下では賭けない（見送り）。
- `oe-capture` の出力チャネル・pane-id 2系統統一 → #114。
- 明示 `--no-enter`（ステージのみ）はバグでなく仕様。
- stage 不達の**自動 fix**（検知 warn §5.2 はスコープイン、fix はスコープ外）。
- 一次発生（Enter 吸収そのもの）の削減＝transport 据え置きにより射程外。
- ②/③ の deterministic 再現環境の構築。

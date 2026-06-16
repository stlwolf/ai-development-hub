---
id: "01KV7YW1GMX2Z5MF99T9TRDS3C"
title: "oe-send copy-mode ガード — 間欠不達の主トリガ確定・除去と silent-failure signal（#154 駆動層記録）"
date: 2026-06-16
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/154"
    reason: "本サイクルの傘 Issue（#144 後も残る間欠的な無言失敗の根治）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-06-09-episode-oe-send-finalize-ingestion.md"
    reason: "前史（#144 finalize 回復）。その follow-up が本件を #154 として明示的に分岐していた"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/144"
    reason: "送信信頼化の傘 Issue（transport 据え置き・finalize は rc 透過の決定の出自）"
tags: [orchestration, oe-send, delegate-send, tmux, copy-mode, not-in-a-mode, silent-failure, episode]
---

# oe-send copy-mode ガード — 間欠不達の主トリガ確定・除去と silent-failure signal（#154 駆動層記録）

> #144 で再現不能ゆえ「論証で選ぶ・断定不可」に留めた間欠不達を、**オーナー指摘（受け手の copy-mode 吸収）を起点に使い捨てペインで決定論的に再現・確定**できた1サイクル（観測された全間欠性の単一根本原因ではなく、**主トリガ**の確定・除去）。`not in a mode` の発生源も isolation で特定。コード4点（copy-mode ガード / opt-in signal / フォールバック案内 / transport 失敗の明示伝播）を実装・ユニット 36/0・実地検証 + so-compare ゲートまで。

## Context / なぜ

#144（観測ベース finalize）クローズ後も、親子委譲 dogfood で `oe-send` が **exit 0 を返すのにメッセージが受け手に届かない**間欠不達が残存。加えて実行中に `not in a mode` が複数回（初回×26・再試行×2）出力された（#144 の症状リストに無い新規症状）。#144 episode の follow-up が「未着でも rc=0 / not in a mode → #154 で継続」と明示しており、本件はその分岐。

オーナー指摘（issue #154 コメント）: 受け手ペインが **trackpad スクロールで意図せず tmux copy-mode に入る**と、`send-keys -l` / `Enter` がコピーモードのキーテーブルで吸収されプロンプトに届かない。「人が触っていない clean な時だけ届く」＝間欠性と整合。#144 が再現不能で断定を諦めた相手を、この仮説は**意図的に再現できる**問題へ変換した。

## 駆動層の流れと、各検証が何を確定したか

### root cause の2点更新（issue 本文 + オーナーコメント）
1. **finalize が rc を変えない（silent）**: `_oe_send_finalize` は best-effort で常に 0 を返す設計（誤再送→二重 submit 防止）。`oe_send_line` は未着でも 0 を返し、呼び出し側に伝わらない構造的な穴。← コードで確認（verified）。
2. **送信前に受け手の copy-mode を解除しない**: copy-mode 吸収が間欠不達の主トリガ。← 仮説（オーナー指摘）を本サイクルで実機検証。

### 実地検証（使い捨てペインのみ・ライブ %0/%3/%11 非接触）

揮発スクリプト（実行後に削除）の結果を以下へ転記（evidence anchor）。

**機構検証**（cat 受け手を copy-mode 化して着弾差を観測）:
- (0) copy-mode でない warmup → 着弾 YES, in_mode=0（受け手正常）
- (1) copy-mode 中に素の `send-keys -l "ABSORBED_MSG"` + Enter → recv 未着 ＝ **吸収＝バグ再現**
- (2) copy-mode 中にパッチ済 `oe_send_line` → in_mode が **1→0** にクリーンに解除され **DELIVERED_MSG 着弾** ＝ **ガードで回復**

**`not in a mode` 発生源の切り分け**（controlled isolation・各コマンドを単独計測）:

| コマンド | mode 外 | copy-mode 中 |
|---|---|---|
| `send-keys -l` | not-in-a-mode=0 | 0（in_mode=1 維持＝吸収） |
| `send-keys Enter` | 0 | 0（in_mode 1→0＝Enter で copy 確定&exit） |
| `send-keys -X cancel` | **=1（発生源）** | 0（正常解除） |

- **`not in a mode` は `send-keys -X` を mode 外ペインに撃ったときだけ出る**（verified）。素の `-l`/`Enter` は in/out どちらでも出さない。
- リポ全体 grep（`send-keys -X` / `-X cancel` / `copy-mode`）→ **本パッチが追加する copy-mode ガードを除く送信パスでは** engine 含め **0件**（verified）。元 dogfood の連発は**リポ外の `-X` 発行元**由来で、送信パスからは出ていなかった。

## 確定した設計と、その射程

- **A. copy-mode ガード**: transport（`send-keys -l`）の前に `#{pane_in_mode}` を確認し、`1` のときだけ `send-keys -X cancel`。baseline capture より前に抜けるので baseline が settled を反映。`in_mode==1` 限定＋`2>/dev/null || true` で、check→cancel 間に mode が抜ける **TOCTOU race でも `not in a mode` を出さず失敗もしない**。
- **B. silent-failure signal（opt-in）**: finalize の `stage_miss_suspect`（一度も staged 観測せず・入力欄空＝未着候補 / suspected miss）で `return 3`（sentinel）。`oe_send_line` は `OE_SEND_SIGNAL_MISS=1` のときだけ rc=4 へ昇格。**既定 off** は、fast submit を未着と誤判定したときの二重 submit を避けるため（#144 の「finalize は rc を変えない」設計を既定で温存）。
- **C. フォールバック案内**: `oe-send` が rc=4 を受けたら手動 `send-keys -l + Enter` を stderr 案内して非0終了。
- **D. transport 失敗の明示伝播（so-compare ゲートで追加）**: `oe-send` が `oe_send_line ... || rc=$?` で受けると関数内 `set -e` が無効化される（bash 仕様・クリーン repro で実証）。これにより transport の `send-keys` 失敗が握り潰され "sent" まで進む**新たな silent failure 経路**が生じていた（#154 と同じ穴を作る回帰）。`oe_send_line` 内で `send-keys -l`/`Enter` の失敗を明示チェックし rc=2 を返すよう修正（errexit に依存しない）。回帰ガード [23] を追加。

射程: A は不達の主トリガ（copy-mode 吸収）を**除去**する一次施策。B/C は未着を呼び出し側に**伝える**安全網で、#144 が残した silent failure の穴を opt-in で塞ぐ。D は本 PR が自ら作った silent 経路を塞ぐ。A は決定論的に検証できた一方、`not in a mode` の野良発行元は本 PR の対象外（engine は発行しない）。copy-mode は **主トリガ**であって、#144 が断定保留した負荷下の Enter 原子性レース（②）は別物で本 PR では潰していない（finalize の best-effort 回復のまま）。

## closure gate

- **次の消費者**: #154 PR レビュアー（ガードと opt-in の妥当性確認）。将来 oe-send transport を触る駆動層作業（copy-mode 吸収が既知の一次トリガとして参照可能）。
- **follow-up routing**:
  - `not in a mode` の**野良発行元（リポ外の何が `-X` を撃つか）**の特定 → **追わない**（engine は発行せず、ガードは race でも出さない。実害なし。再発・実機 dogfood で必要になれば issue 化）。
  - Fix B（opt-in signal）の**実機 Claude TUI 上での真の stage-miss 検証** → **deferred（どの呼び出し側も opt-in しないうちは実害休眠）**。fast-submit を stage-miss と誤判定する確率は実 TUI で未測定（shell ペインの stage-miss は `❯` 不在の人工物）。ユニット [22] は **lib が rc=4 を返すこと**の検証であって、判定精度や bin 側の案内出力は対象外。「不要」ではなく「未測定ゆえ defer」（SO 指摘で訂正）。
- **status**: stable（達成）。コード4点（A〜D）+ ユニット [20]-[23]（36/0）+ 実地検証 + so-compare ゲートまで完了。
- **evidence anchor**: 揮発スクリプト（`/tmp/oe154_*.sh`）は実行後削除済。上記「実地検証」節に数値結果を転記済。so-compare 出力は `tmp/so-154-copymode/`（gitignore 対象）。

## 振り返り（出力型 × 消費チャネル）

### 事実・わかったこと（W）
- copy-mode 吸収は **tmux 層の現象**で、受け手が Claude TUI でなくても（plain shell でも）再現する＝ガードは TUI 非依存に効く。
- `send-keys -X` を mode 外に撃つと `not in a mode`。`-l`/`Enter` は出さない。Enter は emacs copy-mode で copy+cancel ＝ mode を抜ける。

### 決定と根拠
- signal を **opt-in（既定 off）** にした: 確定未着判定は強いが fast-submit 誤判定の二重 submit リスクが残る。呼び出し側が文脈で判断できる方が安全（#144 の rc 透過設計を既定で壊さない）。default-on は棄却。
- copy-mode 解除は **条件付き**（無条件 `-X cancel` は `not in a mode` を生むため）。さらに stderr 抑制で race も無害化。

### 原則（Pattern / Anti-pattern）
- **Pattern**: 「再現不能」を相手にするとき、より説明力のある仮説（copy-mode 吸収）が出たら、それを**決定論的に再現できる最小ハーネス**（自作 cat 受け手 + `copy-mode` 強制）へ落として確定する。#144 の「論証で選ぶ」から一歩進めた。
- **Anti-pattern**: 状態を変えるコマンド（`-X cancel`）を前提確認なしに撃つ → `not in a mode` のようなノイズを生む。**前提（in_mode）を確認してから撃つ + 失敗を無害化**。
- **Pattern**: 混合出力（stdout echo と stderr エラーの interleave）で発生源を見誤りそうなときは、各コマンドを**単独計測（isolation）**して帰属を確定する。

### 蒸留シグナル
- 昇格候補: **なし**（コード修正 + 既存 episode 形式で十分。skill/rule/Decision 化の必要は見えない）。

### 残課題
- `not in a mode` の野良発行元は未特定（追わない判断・上記 routing）。証明できていないことは証明できていないと明記。

## Step 4: 外部チェック（so-compare）

`so-compare`（Codex gpt-5.5 / Claude opus・SO_TIMEOUT=480）でコード5観点 + episode closure 4観点を反証ベースで検証。出力: `tmp/so-154-copymode/`（codex-stdout.txt / claude-stdout.txt・gitignore 対象）。

主な指摘と対応:
- **（blocking・両者一致）transport 失敗の silent 化**: `oe-send` の `|| rc=$?` で関数内 `set -e` が無効化され、`send-keys` 失敗が握り潰される回帰。クリーン repro で実証 → 上記 D で修正（明示伝播 + 回帰ガード [23]）。
- **rc=4 の契約が強すぎ**（"confirmed" non-delivery）: fast-submit 誤判定があり得るため "suspected (stage miss)" に表現緩和。
- **表題 "root cause 確定" が強い**: 確定したのは主トリガであって全間欠性の単一根本原因ではない → 表題・headline・射程を「主トリガ確定・除去」に修正。
- **Fix B 検証の "不要" → "deferred"**: opt-in が誰にも使われない間は実害休眠だが判定精度は実 TUI 未測定 → follow-up を deferred に訂正。
- **episode の grep "0件" 表現 / Step4 プレースホルダ**: grep 表現を「ガード追加分を除く送信パス」に明確化、本節で Step4 を充足。
- copy-mode ガード / opt-in signal / フォールバック / 後方互換は両者とも**決定的バグを反証できず妥当**と確認。

合意判定: 問題認識・修正方針は一致。blocking 指摘（transport silent 化）は修正済。残差は表現・closure の精緻化で解消 → 3者（自分 + Codex + Claude）合意とみなす。

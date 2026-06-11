---
id: "01KTPB0D98JFNVHJAC9W9GZP50"
title: "oe-send 送信信頼化 — Enter 吸収の観測ベース finalize 回復（#144 駆動層記録）"
date: 2026-06-09
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/144"
    reason: "本サイクルの傘 Issue（Enter 吸収・stage 不達の根治調査）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-06-09-plan-oe-send-ingestion-rootfix.md"
    reason: "本 episode の実行計画（so-gate v1→v5 を経た実装着手版）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/148"
    reason: "実装 PR"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-06-08-episode-oe-delegate-redesign.md"
    reason: "症状の出自（#142 dogfood）。本件はそのフォローアップ（入力側）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/114"
    reason: "対話 TUI は入出力とも本質的に脆い、という共通洞察"
tags: [orchestration, oe-send, delegate-send, tmux, ingestion, enter-absorption, finalize, so-gate, episode]
---

# oe-send 送信信頼化 — Enter 吸収の観測ベース finalize 回復（#144 駆動層記録）

> findings → so-gate v1 → 診断スパイク → so-gate v2/v3/v4/v5 → 実装 → dogfood → Copilot レビュー対応、という1サイクル。**方針が二度転回**（bracketed-paste → 原子送信 c2 → transport据え置き+finalize）し、so-gate が**実バグを複数捕捉**した記録。

## Context / なぜ

#142 dogfood で、`oe_send_line`（tmux `send-keys` → Claude Code 対話 TUI への1行注入）の**自動 Enter が間欠的に「吸収」され submit されない**ことが顕在化（緩和A=0.3s delay のみで未根治）。オーナー判定: 明示 `--no-enter` は仕様だが「自動のはずが届かない」はバグ＝信頼化対象。

## 駆動層の流れと、各ゲートが何を捕まえたか

### 診断スパイク（実機 throwaway claude 2.1.169 / tmux 3.5a）
- **clean throwaway では2症状とも再現不能**（Enter 吸収 12/12 submit、stage 不達 20/20 着弾）。→ 比較失敗率の計測は不能＝**機構は論証で選ぶ**しかない。
- `pipe-pane` 観測: idle/通常処理中は `?2004h`（bracketed paste mode）維持、`?2004l` は claude 終了時のみ。
- **claude の paste 検知は bracket ベース**（raw send の CR は keystroke として submit）→ bracket を送らない baseline の Enter 吸収は **①paste 誤検知では説明できない**（clean 観測の範囲）。残る有力は **②原子性レース**（text と Enter が別 write）だが、再現できないため**断定不可**。

### so-gate（Codex / Claude を5回・各 SO_TIMEOUT=600）
- **v1**: 初案 bracketed-paste(a) → `paste-buffer -p` は受け手の `?2004h` 依存で**サイレント劣化**（man tmux で確認）→ 撤回。
- **v2**: c2（単一 paste・原子送信）主軸 + 冪等 finalize → ②過剰主張・finalize 冪等の二重 submit を指摘。
- **v3**: finalize「安定」定義が**論理反転**（idle+staged の本命で撃たず、processing+staged の危険ケースで撃つ）を捕捉。c2 は緩和A の 0.3s 防御ギャップを除去する賭けで、paste 検知が timing 型なら負荷下で悪化し得る（検証不可）と指摘 → **transport を据え置く決定**。
- **v4**: **B1**（baseline/edge が発火に無効＋「子ビジー→後に staged_idle」で二重 submit 経路）。**B2**（吸収＝消費 と 遅延配送 を per-event で区別できず、finalize は遅延型なら間欠未submit を間欠**二重**submit に変換し得る＝**純便益の符号は settle 窓次第**）。
- **v5**: settle 窓が staged_idle 発火を実際にゲートするか未確定／`base_staged` 過剰主張／payload literal 判定未定義 → 確定して3者合意。

### 実装 + dogfood + Copilot
- 実装: transport 据え置き（send-keys -l → sleep → Enter）の後段に**観測ベース finalize**を追加。状態機械: 送信前 baseline → quiescence poll（settle 窓終端まで）→ `submitted/staged_idle/stage_miss_suspect/unknown` 分類で **staged_idle のみ Enter を1回再送**。保守的発火（不確実なら撃たない）・rc 透過・`OE_SEND_FINALIZE=0` で無効。
- ユニット: `capture-pane` 時系列モックで分岐 a〜j・単発ガード・回帰を assert（28/28 PASS）。**モックがサブシェル越しの index 伝播で躓いた**（lib は `$(tmux capture-pane)` で読むため変数カウンタが親に伝播しない）→ index/コール数を**ファイルベース**に変更して解消。
- dogfood: FIRE 経路（手動 stage → finalize が約4s=窓使い切りで submit）と happy path（単一 submit・早期 exit 1s・二重 submit なし）を実機確認。**実 TUI の scrape×fire 整合**（ユニットで検証不能な領域）を裏取り。
- Copilot（PR #148）: 4件とも妥当 → 全対応（入力欄行頭アンカー・stage_miss を空時のみ・baseline capture 失敗時は finalize 無効化・終端 capture も stable 連鎖に含める）。

## 確定した設計と、その射程

- **transport は賭けない**（機構未確定ゆえ）。緩和A の防御ギャップは第一線として維持。
- **finalize は「観測可能な staged_idle の after-the-fact 回復」に射程限定**。一次発生は減らさない。
- **settle 窓 = 中心安全パラメータ**: 「妥当な遅延の最悪値より長く待ち、なお staged なら真の吸収」。遅延配送なら窓内に着弾→submitted で撃たない、で安全側へ。

## 残リスク（対称な honesty・episode/PR に明記）

- **根治の証明は不可**（再現不能）。確率を下げる施策。
- **finalize の新リスク（二重 submit）も間欠で clean dogfood に出ない**。「fix が効いた証明不可」かつ「新バグ不在も証明不可」。
- **吸収が負荷相関なら実効回復は小さい可能性**（子ビジー時は撃たない＝busy レジームは回復対象外）。
- settle 窓 3s は provisional（遅延分布を測れず）。`esc to interrupt` は version 依存 magic string。

## 振り返り

### 効いたこと
- **再現不能を早期に確定**し、「計測でなく論証で選ぶ／過信しない」へ舵を切れた。スパイクが「①は bracket ベースで除外・②が最有力だが断定不可」まで切り分けた。
- **so-gate を5回**当てたのが効いた。特に **v3 の論理反転・v4 の B1（二重 submit 経路）・B2（純便益の符号）** は静的レビューでしか出ない実バグ/盲点で、実装前に潰せた。方針も2度（a→c2→据え置き+finalize）反証で正された。
- **dogfood が実 TUI scrape×fire を裏取り**（ユニットの mock では原理的に検証不能な領域）。
- **Copilot が4件の堅牢化**を追加で捕捉（baseline 失敗時の誤発火など実害寄り）。

### 学び（次に活かす）
- **間欠・受け手依存のバグは「根治」でなく「best-effort 回復 + 対称な honesty」が誠実**。証明不可を隠さず、純便益の符号が条件依存であることを明記した。
- **不確実性が高いほど『賭けない』が強い**: transport 変更は検証不能な悪化リスクがあり見送り、観測ベースの保守的回復に寄せた。
- **テスト mock とサブシェル**: lib が `$(...)` で読む値はモックの変数カウンタが伝播しない。状態はファイルで持つ。
- so-gate は「合意」より**反証で実バグを出す**ことに価値があった（5回中ほぼ毎回 blocking を捕捉）。

### follow-up
- settle 窓 3s の長期 calibration（負荷時に伸ばす判断基準）。
- ②/③ の deterministic 再現環境（「整形崩れセッション」の人工再現）は未達＝根本の機構特定は保留。
- `oe-capture` の pane-id 2系統・出力チャネル統一 → #114。
- #144 後も残る間欠的な無言失敗（未着でも rc=0 / not in a mode）→ #154 で継続調査。本サイクルは観測ベース finalize 回復までで closure（後続は別サイクル）。

---
id: "01KWK83WBKGDTMPK1NV4TMHJGR"
title: "#223 episode — spawn トポロジのリアルタイム観測（oe-tree --watch + tmux popup）実装記録"
date: 2026-07-03
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/223"
    reason: "oe-tree の live 化 + 浮遊/常設表示（cockpit epic #169 配下・#221 の follow-on）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/221"
    reason: "oe-tree 本体（一発スナップショット）の設計判断 DJ-221-* を前提に live 化する"
tags: [orchestration, cockpit, spawn-tree, topology, watch, tmux-popup, read-only, episode]
---

# #223 episode — spawn トポロジのリアルタイム観測（oe-tree --watch + tmux popup）実装記録

親（統括）からの委譲子セッションとして、#223「`oe-tree`（#221・一発スナップショット）の live 化 + 浮遊/常設表示」を実装する。multi-session 運用では一発起動では「今の状態」を追えず、常設ペインはレイアウト面積を恒久消費して細ペイン sprawl（別 concern の (1)）を悪化させる — live 更新と浮遊表示の導線でこれを解くのが本作業。設計方向は issue で固定されておらず、ゼロベース設計（`predecision-exploration`）が親の明示指定。責務分界は #202 oe-ident と同じ型: command=hub / keybind config=dotfiles（hub は推奨スニペットを doc で提示するに留める）。

SO モード（kickoff 指定）: 設計SO=弱（`so-compare` or `oe-refute --rubric exploration`・refuted なら保留）/ 実装SO=弱（`oe-review`・PR 前）。

## 着手時 grounding（2026-07-03・設計前の実測）

- kickoff（`.oe/kickoff-223.md`・揮発）読了 → issue #223 原文・`bin/oe-tree` 全文（#221 の DJ: registry 現在スナップショット主義・gone 表示 + GC 不呼出・tmux 不在 exit 2・C0/C1/DEL sanitize）・#221 episode 読了してから設計に入った。
- `oe-activity` / `oe-status` の --help 実測: いずれも watch/follow 系オプションなし — issue 記載どおり watch/popup の先行実装は repo に無い（greenfield）を確認。
- 実測（設計入力として効いたもの）:
  - tmux 3.5a・`display-popup -E/-EE/-C/-w/-h/-T`（man 実照合）。`-C` は popup を閉じる。popup 表示中のキーは popup 内プログラムへ渡る。
  - **popup 内では `TMUX_PANE` unset・`TMUX` は set**（probe popup で env dump 実測）。`tmux display-message -p '#{pane_id}'` は popup 内から active pane（%120）を返す — `(you)` マーカーの fallback 経路が存在する。
  - **fswatch / watch(1) / entr すべて未導入**（`command -v` 実測）— event-driven 案・external watch 案は新規依存になる。
  - `oe-tree` 1 回 = real 0.257s（実測）・PATH 未登録（`command -v` rc=1）。bash 5.2.37。
  - pane kill は registry に書かれない（GC は次の `oe_reg_record` 時のみ・#221 DJ）— **liveness 変化はファイルイベントを発しない**（event-driven 案の構造的盲点）。

## 設計フェーズ（2026-07-03）

- **ゼロベース設計**（`predecision-exploration`）: 探索木を `tmp/dj-223-tree.md`（gitignore・揮発）に外部化。DJ は 8 本: 更新機構（**poll 採用** / event-driven fswatch / external watch(1) / status-line 一行 / 汎用 oe-watch verb）・配置（**tool は配置非依存 + doc は popup を primary 推奨**）・間隔（**2s 既定 + --interval N**）・oe-activity 併合（❌ レイヤ分離維持）・interactivity（❌ read-only 徹底）・実装形（**self re-exec** / 関数化 refactor）・doc/スニペット（hub=doc のみ）・テスト計画 7 ケース。
- **ゼロベース発見（初期案セット外のカテゴリ）**: (1) 汎用 verb `oe-watch <oe-cmd>`（責務分界軸 — 任意の観測 view を live 化）→ #223 スコープ外の一般化は YAGNI・oe-tree --watch から昇格可能な一方向でない door として follow-up surface で棄却。(2) external watch(1)（hub 実装ゼロ軸）→ macOS 未導入（実測）+ popup UX 制御不能で棄却。(3) `(you)` fallback — popup 実測（TMUX_PANE unset）から `display-message -p '#{pane_id}'` による SELF 解決を発見・採用（issue には無い設計点）。
- **event-driven 棄却の核**: pane kill はファイルイベントを発しない＝受入条件「spawn/**kill** が数秒で反映」の kill 側を file-event では構造的に拾えず poll 併用必須 → event は poll を置換できない。
- **プロトタイプ検証**（scratchpad・非 TTY background 実行）: `\e[H`+`\e[J` フレーム描画・`read -t` の sleep 兼 key listener・stdin EOF 時の busy-loop 防止（sleep fallback）・trap による alt-screen 復元 — interval=1s で 3 tick / 3 フレーム / enter・leave 1 対を実測確認。
- 設計SO: claim doc `tmp/dj-223-claim.md` に探索木ごと固めて `oe-refute --rubric exploration`（弱SO・2レーン）を実行。
- **SO#1**（audit_id 202607030554226TD67S6P3XVT）: verdict=**refuted 2/2**（conservative 集約）。一次照合の上で採否:
  - **「byte-identical」根拠の過大主張（両レーン指摘・採用）**: self re-exec の根拠を「snapshot コードパス byte-identical 維持」としつつ (you) fallback を additive 変更として持つ内部矛盾 — 実照合のとおり。根拠を「中核ロジック（森林構築・render・sanitize）を refactor しない・変更は additive 2 点に限定」へ差し替え（結論 = re-exec は維持）。
  - **primary 経路（実 popup 内）未検証（両レーン指摘・採用→即実測）**: 指摘時点で正 — プロトタイプは非 TTY scratchpad のみだった。実 popup 内でプロトタイプを実測し直し: popup stdin は TTY（key 処理成立）・3 tick 描画・kill 時 trap 復元発火・popup rc=0・client 正常・popup 内で (you) が消える実害も再現。視覚レンダリングと q/Esc 対話終了は自動化不能のため hg-1 ライブデモ項目として明示（テスト計画に限界を明記）。
  - **(you) fallback の意味論誤り（cursor 指摘・採用）**: `display-message -p '#{pane_id}'` は「popup を開いたペイン」でなく「active pane」— per-tick 解決ならフォーカス移動で drift する。追加実測で `run-shell` 経由の `-e 'TMUX_PANE=#{pane_id}'` が format 展開されること（RUNSHELL_E=%120）を発見し、primary=スニペットで opener を正確注入（hub コードゼロ）/ fallback=watch 開始時 1 回解決で freeze（開始時 active pane = opener）へ再設計。`display-popup` 直呼びでは `-e` も shell-command も format 非展開（実測）— run-shell 経由が必須条件。
  - **toggle 意味論の非対称（cursor 指摘・採用）**: 「Meta 再押下 = ESC 前置で閉じる」は未実測の推論だった — [speculation] に格下げし hg-1 デモで実測確認に回す。設計の「toggle」= 開く（bind 一発）/ 閉じる（q or Esc 一発）と正直化。`-EE` は man 実照合の範囲で doc 言及・`-C` は rescue として言及。
  - **oe-status 先例（DJ-1(c) watch 棄却）との整合未整理（cursor 指摘・採用）**: discussion を一次照合 — 先例の緊張は「常駐 poll が capture 走査（=検出）へ誘引される」= 「何を読むか」の線。oe-tree --watch は snapshot と同一 read セットの反復で対象の線を動かさない + #223 issue が live 更新を明示スコープ化。DJ-223-9 として新設・README にも 1 行明記する方針。
  - **claim スコープ過大（cursor 指摘・採用）**: 「最良」→「#223 スコープ + kickoff 固定制約の下で最良」に補正。picker 統合・wez overlay を比較欄に追加し棄却理由を明文化。
  - **手続き指摘（両レーン・自己言及として処理）**: 「設計SO未完了・episode 未追記」— 本ラウンドがその設計SO であり（#221 SO#1 の「SO未実行で最良確定」指摘と同型の自己言及）、記録は本追記で解消。
  - 探索木は v2 に**統合書き直し**（#221 の学び: 追記形式は本文矛盾を作る）。
- **SO#2**（v2 claim・audit_id 2026070306051778HDP8VYECRS）: verdict=**refuted 2/2**。指摘の分類と処置:
  - **追加比較（採用・v3 で明文化）**: hybrid（spawn=event / kill=poll — 受入条件は 2s poll 単独で充足済みで利得ゼロ・故障モード倍増で棄却）/ dotfiles 側 shell loop（issue (a) の command=hub 分界違反で棄却）/ 専用 window on-demand（glance→dismiss の popup UX 優位・閉じ忘れ常駐化で既定推奨から棄却・doc 言及）/ in-process watch（re-exec の「フレーム=一発実行と同一コードパス」という意味論一貫性の根拠を追加した上で棄却維持）/ -EE 既定（配置非依存に効かない — tool 側 hold は実行文脈を問わず自己完結、で -E + hold 維持）。
  - **poll コストのスケール根拠（採用・v3 で追記）**: 逐次ループは遅延が累積しない自己抑制構造（tick が interval を超えても実効周期が伸びるだけ・バックログ/暴走なし）— 既定 2s の安全性をスケール非依存にする構造的性質として明文化。実測が 1 環境・小規模のみの限界は正直に開示。
  - **kill 反映の期待ギャップ（採用・DJ-223-10 新設）**: 受入「kill が数秒で反映」= alive→gone 遷移であり、ノード消滅は次 spawn の GC（#221 受入済み意味論）。README 明記 + hg-1 再確認（DJ-OPEN-3）。
  - **oe-status 先例の UI 形態論点（採用・DJ-OPEN 化）**: 「read セット同一」整理は設計側の再解釈 — 先例が棄却した UI カテゴリ採用の優先順位（issue 再決定 vs 家族規律）は機械検証不能 → DJ-OPEN-2 として hg-1 でユーザーが裁定。
  - **手続き指摘（ゲートで解決 — SO では解決不能）**: popup 視覚・q/Esc 終了・toggle 受入は人間の目とキーが要る（DJ-OPEN-1/4・ライブデモ）／「SO#2 未記録」は本ラウンド自身の自己言及／「--watch 未実装で E2E 未検証」は kickoff の実装ゲート順序（設計SO → 承認 → 実装）の帰結 — 実装後の gate-1/verify で解消する種別。
- 設計SO 総括: 2 周とも refuted だが実質的発見は v2/v3 に吸収済み。残余 refuted 核は「人間ゲートでしか解決できない項目」に収束（#221 SO#2 と同型）— 弱SO 規律「refuted なら確定保留」に従い、設計は**未確定のまま** DJ-OPEN 4 点（toggle 意味論 / 先例優先順位 / kill 意味論 / 実 popup デモ）を添えて hg-1 に提示。SO 追加ラウンドは回さない（人間の受入判断を代替できない）。

## ユーザー承認（hg-1・2026-07-03）

- プロトタイプの popup ライブデモを 2 回実施（display-popup -E・2s 更新）— いずれもユーザーのキー操作（q/Esc 系）で exit 0 正常終了。閉じ後の画面復帰・視覚の問題指摘なし。
- DJ-OPEN 裁定: **1 受入**（toggle = 開 bind 1 キー / 閉 q・Esc 1 キー。「同キー bind toggle 構造的不成立」の説明をかみ砕いて再提示の上）/ **2 許容**（常駐 poll — read 対象の線が基準・README 明文化）/ **3 受入**（kill = gone 遷移で反映）/ **4** 視覚・終了 UX 問題なし — 「問題あり」回答の実体は pane ID の可読性（下記）。
- デモ中の発見 2 点（ユーザー実体験由来）:
  - スニペット例キー `g` はユーザーの C-Space g（tmux-claude-picker）と衝突 — 例キーを非衝突のものへ変更 + `tmux list-keys` 衝突確認注記を doc に追加。
  - **DJ-223-11（新 DJ・ユーザー要望)**: 「%N だけでは人間が把握しづらい — tmux の window/pane 情報と紐付けられないか」→ 座標（`session:window.pane`）を liveness 用の既存 `tmux list-panes -a` コールの format 拡張で取得し**併記**（`%120  0:3.2  alive  ...`・gone は `-`）。併記/置換/見送りを preview 付きで提示し**併記を明示承認**。%N は oe-* 突合キーとして維持。
- スコープ判断: 座標表示は snapshot 出力も変える（render 共通）— 同 PR 取り込み（推奨）か別 issue かを提示。一時タイムアウトのため推奨側（#223 取り込み）で暫定続行としたが、直後にユーザーから「2は一緒に入れるでok」の**明示承認**を受領（暫定判断は承認で確定）。
- 設計確定。実装フェーズへ。

## 実装フェーズ（2026-07-03）

- `bin/oe-tree`（変更）: 承認済み設計どおり。(1) `--watch [--interval N]` — tick ごとに `"$0"`（snapshot モード）を re-exec し alt screen 上に `\e[H`+本文+`\e[J` で再描画・`read -t` が sleep 兼 key listener（q/Q/Esc 終了・INT/TERM trap で復元）・stdin EOF は sleep 退避（busy-loop 防止）・env エラーは watch+TTY のときだけ 3s hold して exit 2。(2) `(you)` freeze fallback — TMUX_PANE unset 時に watch 開始で 1 回だけ `display-message -p '#{pane_id}'` を解決し export。(3) 座標併記（DJ-223-11）— liveness の `tmux list-panes -a` を format 拡張（タブ区切り `pane<TAB>session:window.pane`）し `%N` の隣に表示・gone/不明は `-`・sanitize_out 経由。snapshot 中核ロジック（森林構築・render・sanitize）は無改変（グローバル `grep -qxF` 判定 2 箇所を `is_alive()` ヘルパへ集約 + render の printf 列追加のみ）。全文 Write でなく対象箇所の Edit で実施（jq の `\uXXXX` エスケープ行を生制御文字で壊す #221 の失敗の再発防止 — 実際に最初の Write 案で同じ壊し方をしかけて Edit 方式へ切替えた）。
- `tests/test_oe_tree.sh`（拡張）: mock tmux を拡張（`MOCK_LIVE_LINES` = タブ区切り verbatim / `display-message` を format 引数で分岐 `MOCK_ACTIVE_PANE`）・既存 13 ブロックの期待値を座標列（`-`）対応に更新・新規 4 ブロック（[14] 座標併記+sanitize / [15] 引数検証 6 ケース+watch tmux-less / [16] watch 1 tick 非 TTY background・ヘッダ+内容+復元 / [17] (you) fallback freeze）。**31/31 PASS**（#221 時点 19 → 31）。
- shellcheck: `bin/oe-tree` / `tests/test_oe_tree.sh` とも指摘ゼロ。
- doc: `bin/README.md` oe-tree 節を「#221 / #223」に改題・座標列と出力例更新・`### --watch` 小節（read セット同一の非検出境界=DJ-223-9 / kill 反映=DJ-223-10 / 配置非依存 / 逐次ループの自己抑制 / (you) 注入と freeze / run-shell スニペット=例キー T + `tmux list-keys` 衝突確認注記 / toggle 意味論 / -C・-EE / follow-up 一覧）。`README.md` 構成ツリー 1 行更新。

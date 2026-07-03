---
id: "01KWK83WBKGDTMPK1NV4TMHJGR"
title: "#223 episode — spawn トポロジのリアルタイム観測（oe-tree --watch + tmux popup）実装記録"
date: 2026-07-03
type: episode
status: stable
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
- コミット: 8111166（feat）。

## 受入検証（2026-07-03）

- **verify-2（live 更新・read-only）**: 実 tmux + 隔離 state dir（`OE_DELEGATE_STATE_DIR` override・実 registry 非接触）で実測 — 検証用 detached セッションのペインを登記 → `--watch --interval 1` 実行中に (a) 登記追加（spawn 相当）(b) `kill-session`（実ペイン消滅）を発生 → 捕捉 5 フレームで「最初: alive・late-spawn 不在 / 最後: gone・late-spawn 出現」を機械 assert で確認（4/4 True）。kill が alive→gone 遷移として数秒で反映（DJ-223-10 の意味論どおり）。
- **verify-1（キー一発・浮遊表示・レイアウト非消費）**: 本実装を README スニペットと同一経路（`run-shell` + `-e 'TMUX_PANE=#{pane_id}'` + `display-popup -E`）で popup 表示 — ユーザーがキー操作（q/Esc）で正常クローズ（exit 0）・視覚/復帰の問題指摘なし。popup 内 `(you)` マーカーは -e 注入経路で表示（テスト [17] は fallback 経路を mock で担保）。「キー一発で開く」の最終形は dotfiles への bind 追加（マージ後・環境側責務）で成立 — 本 PR の提供物はスニペットまで（責務分界どおり）。プロトタイプ段のデモ 2 回 + 本実装 1 回の計 3 回とも人間のキーで正常終了。

## 実装SO（oe-review・2026-07-03）

- **SO#1**（audit_id 20260703094630WRQ0ZRR653HK・reviewed_sha 8111166・diff_base master・2 レーン）: **survived 2/2**（1 周通過 — #221 は 3 周を要した）。codex=「--watch/座標追加に material な correctness/到達可能性/堅牢性/security 欠陥は確認できなかった」/ cursor=「watch/snapshot 分岐・re-exec・liveness/座標パース・sanitize・引数検証・非TTY EOF 退避・trap 復元をコードと 31/31 テストで照合し material な欠陥なし」。実装SO ゲート通過 — PR 作成へ。
- 1 周通過の背景（belief・断定しない）: 設計SO 2 周が実装前に sanitize 経路・EOF busy-loop・freeze 意味論・テスト計画を先に固めたこと + 中核ロジック無改変（additive 変更に限定）が効いた可能性。

## Decision/ADR 昇格判断（adr-1）

- **非昇格**（#221 と同判断）。理由: 本件の決定は tool-local（watch 機構・座標表示・終了 UX・スニペット形）で新規 write path・スキーマ・イベント意味論の変更がない。唯一システム横断性のある DJ-223-9（非検出境界は「何を読むか」の線 — 観測 verb の watch 化の参照点）は hg-1 でユーザー裁定済みで、`bin/README.md` の --watch 節に参照点として明文化済み + 本 episode の DJ 記録で再利用可能 — #114/#92/#206A 級の独立 ADR には届かない。将来 watch 系が増えて線の解釈が争点化したら、その時点の episode から昇格すればよい（積み上げ式）。

## PR

- [PR #225](https://github.com/stlwolf/ai-development-hub/pull/225)（feat(oe): oe-tree に --watch live 表示と tmux 座標併記を追加）。コミット 2 件: 8111166（feat）→ ef73a98（docs: episode 追記）。マージ・worktree 掃除はしない（kickoff 規律・人間/親）。

## Closure（episode-retrospective・heavy tier・2026-07-03）

tier 判定: heavy（実行中に撤回・根拠差し替えあり / 意図的 SO レーン 3 回 = oe-refute ×2 + oe-review ×1 / 非自明な設計判断あり）。

### 事実・失敗（選択的省略をしない）

0. **設計フェーズの誤り一式**（採否の詳細は設計フェーズ節の SO#1/#2 記録が正本 — ここは失敗棚卸しとしての列挙）: claim スコープ過大（「最良である」→ #223 スコープ内へ補正）・self re-exec 根拠の「byte-identical」過大主張と (you) fallback additive 変更の内部矛盾・(you) fallback の意味論誤り（`display-message` の active pane を「opener」と等置・per-tick 解決の drift 見落とし）・「Meta 再押下 = ESC 前置で閉じる」を未実測のまま根拠扱い・oe-status 先例 DJ-1(c) との整合未整理・-EE / picker 統合 / wez / hybrid / 専用 window / dotfiles loop の比較不足・poll コストのスケール根拠が単一小規模実測の外挿。
1. 探索木 v2 の DJ-223-6 末尾に**迷い閉じフェンスを混入**させ markdown 構造を壊した — claim 再生成後に自己検出して修正（SO#2 投入前）。
2. 実装時、最初の全文 Write 案で **jq の `\uXXXX` エスケープ行を生制御文字で壊しかけた** — #221 episode 記録の既知失敗（closure 項目 6）と同型。episode を読んでいたため Write 実行前に気づき、対象箇所のみの Edit 方式へ切替えて回避（既知 negative knowledge が実際に再発を防いだ実証例）。
3. hg-1 の質問設計が実装者の語彙のまま（「座標表示」「スコープ」）でユーザーに伝わらず（「2はなんだ？」）、かみ砕いた説明 + デモ再提示のやり直しが発生。AskUserQuestion の 60s タイムアウトにも複数回当たった — 音声入力ペースのユーザーにはテキスト提示 + 自由回答の方が合う場面があった。
4. デモ中、ユーザーが「bind で開かない・セッション選択が出る」と報告 — keybind 未設定段階である説明を先に届けていなかった（デモ導線の説明不足）。副産物としてスニペット例キー `g` が既存 C-Space g（tmux-claude-picker）と衝突する実害を発見し、例キー変更 + `tmux list-keys` 注記として設計に反映（怪我の功名）。
5. runner レベルの一過性失敗（Step 4 codex 指摘で追補）: 実装SO 実行中に cursor レーンが一度 `timeout_empty` になりリトライで回復（verdict には影響なし）。Step 4 自身でも claude レーンがリトライ含め 2 回 timeout（実返却ゼロ）— 弱SO 規律の partial として開示の上 codex 1 レーンで続行。コード/設計欠陥ではないが「実行ログにある失敗」の全件棚卸しとして記録。

### 決定と根拠（詳細は本文の設計フェーズ節・確定は hg-1 承認済み）

- `--watch` = in-tool poll（event-driven は「pane kill がファイルイベントを発しない」構造的盲点で棄却 — 棄却案 7 系統と理由は探索木 v3 から本文に転記済み）。
- self re-exec（各フレーム = 一発実行と同一コードパス・中核ロジック無改変）・座標併記（%N は突合キー・座標は人間の導線）・(you) は run-shell スニペット注入 primary + 開始時 freeze fallback・toggle は 2 キー完結・常駐 poll は「何を読むか」の線で非検出境界と整合（DJ-223-9）・kill は gone 遷移（DJ-223-10）。

### わかったこと

- tmux 3.5a 実測: popup 内では `TMUX_PANE` unset・`TMUX` set。`-e 'VAR=#{format}'` は **`run-shell` 経由のときだけ展開**され `display-popup` 直呼びでは非展開。popup stdin は TTY。popup 表示中のキーは popup 内プログラムへ渡る（= tmux bind の同キー toggle は構造的に不成立）。
- `oe_reg_gc` が `oe_reg_record` 時のみ走る構造（#221 既知）は、event-driven 観測の反証（kill の非イベント性）としても効く — 同じ事実が別の設計判断の根拠に再利用された。
- 逐次 poll ループは tick が interval を超えても遅延が累積しない（実効周期が伸びるだけ）— watch 系 CLI の既定間隔をスケール非依存に安全化する構造的性質。

### 原則（Pattern / Anti-pattern 対）

- NG: 中間 query の返り値が「それらしい」1 回の probe で意味論を確定する / OK: **その値が「誰の・いつの」ものか（主体と時間軸 = drift）まで言語化してから採用する**（(you) fallback の active pane ≠ opener 誤りの学び。SO#1 cursor 指摘）。→ #62 negative knowledge 注入候補（routing 先: #62）。
- NG: 人間ゲートの質問を実装者の語彙（スコープ・render 共通）で組む / OK: 相手の画面で何が変わるかの語彙で説明し、実物デモを添える（hg-1 のやり直しの学び）。
- 適用実証（新原則ではない）: #221 の「エスケープ含みソースは全文書き換えない」が本サイクルで実際に事故を防いだ — episode の negative knowledge は読まれれば効く。

### 蒸留シグナル

- **Decision/ADR: 非昇格**（adr-1 節に判断記録済み）。
- skill / rule 昇格: なし。
- #62（negative knowledge 注入）候補: 上記「1 probe で意味論確定しない」の対構造。

### 残課題（routing — 全件行き先付き）

- 汎用 `oe-watch` verb・status-line 要約（`--summary`）・popup 内 fzf 対話化（#176 系譜）・oe-activity 統合ダッシュボード・wez 表示チャネル・`--json` / gone root ラベル補完 / ラベル解決共通ヘルパ（#221 継続分）: **[PR #225](https://github.com/stlwolf/ai-development-hub/pull/225) スコープ外節に surface 済み** — 採否・起票は epic [#169](https://github.com/stlwolf/ai-development-hub/issues/169) オーナー（人間/親）判断。子からは追わない。
- dotfiles への実 keybind 追加: 環境側責務（マージ後にユーザー自身が README スニペットを適用）— 追わない。
- 一般のペイン分割レイアウト戦略（(1) の残り）: [#223](https://github.com/stlwolf/ai-development-hub/issues/223) 本文が別 concern と宣言済み — 起票は親/人間・追わない。

### closure gate

- Context/なぜ: 冒頭 2 文で自己完結（一発起動では live 運用に足りない + 常設ペインは sprawl 悪化）— 充足。
- 次の消費者: (1) マージ後に dotfiles へ bind を足すユーザー本人（README スニペットが正本・本 episode はスニペット設計の根拠）(2) #169 epic の後続観測 UI 実装者（watch 化の参照点 = DJ-223-9 の「何を読むか」の線・逐次 poll の自己抑制性質）(3) #62 実装時の negative knowledge 注入候補の参照元。
- evidence anchor: 揮発参照（`tmp/dj-223-tree.md`・`tmp/dj-223-claim.md`・`tmp/oe-refute-*`・`tmp/oe-review-*`）の要点（DJ・棄却理由・audit_id・verdict・レーン note・実測値）は本文へ転記済み。SO 生出力は audit_id（202607030554226TD67S6P3XVT / 2026070306051778HDP8VYECRS / 20260703094630WRQ0ZRR653HK）で追跡可能。
- status: draft → **stable**・達成（受入条件 2 点とも実測検証済み・PR #225 作成済み）。
- Step 4 外部チェック（so-compare 弱SO・`tmp/so-20260703-190007`・揮発）: **partial** — claude レーンはリトライ含め timeout（実返却ゼロ）・codex レーンが実返却 → 弱SO 規律「partial（実返却 1 レーン以上）= disclose して進む」で続行。codex 判定 = 主要な失敗・撤回・指摘は**省略なし**（設計SO 2周の指摘群・hg-1 やり直し・escape 事故未遂の反映を確認）/ routing 省略なし / back-propagation 漏れなし。反証可能な指摘 2 点はいずれも採用: (a) Step 4 記録欄の未追記 — 本ラウンド自身の自己言及・本追記で解消 (b) 実装SO 中の cursor レーン timeout/retry（runner 一過性）の棚卸し漏れ — 事実・失敗の項目 5 として追補。

形式メモ: チャネル骨格の「事実・失敗」全件棚卸しが Step 4 の runner 一過性失敗の追補まで駆動した（骨格が拾い、外部チェックが漏れを検知する二段が機能）。「原則」の対構造は (you) 意味論の学びに嵌った。皮（KPT/YWT）は不使用。摩擦は Step 4 の claude レーン timeout（360s×2）による待ち時間と partial 処理のみ。

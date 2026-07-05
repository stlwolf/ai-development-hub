---
id: "01KWQ1EENZ8YKR0KS1SCSTJ305"
title: "#227 episode — oe-tree に対話ナビ（fzf 選択 → oe-jump → resize-pane -Z 最大化）を追加"
date: 2026-07-05
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/227"
    reason: "oe-tree --watch（#223）の表示から prefix+g picker 同様に「選んだペインへ移動＋最大化」する導線を単一ツール拡張で足す"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/223"
    reason: "oe-tree --watch の re-exec パターン（DJ-223-6・フレーム=一発実行と同一コードパス）を pick 候補生成に踏襲"
  - type: reuse
    ref: "https://github.com/stlwolf/ai-development-hub/issues/179"
    reason: "jump は oe-jump を再利用（jump ロジックを複製しない）"
tags: [orchestration, cockpit, spawn-tree, topology, pick, fzf, jump, zoom, tmux, read-only, episode]
---

# #227 episode — oe-tree に対話ナビ（fzf 選択 → oe-jump → 最大化）を追加

親（統括）からの委譲子セッションとして #227 を実装する。設計・実装は人間とこのペインで直接、完了確認のみ親へ。マージ・worktree 掃除はしない。

動機: #223 で `oe-tree --watch`（live トポロジ）が landed。その表示から `prefix+g` の session picker と同じく「選んだペインへ移動」＋「移動時に最大化」を1つの導線にしたい。設計方針は確定済み（親と合意）: **別コンポーネントを作らず oe-tree 自体に対話モードを足す**（森ロジックは oe-tree 1 箇所・jump は oe-jump 再利用・新規は fzf 選択 + `resize-pane -Z` のみ・データ read-only 維持・純ビューは温存）。

## 設計フェーズ（predecision-exploration・ゼロベース）

開放点 5 つ（対話モードの形 / zoom 意味論 / gone ペイン / fzf 非在 degrade / popup 内挙動）＋横断小 DJ をゼロベースで探索。探索木は確定前証跡として `tmp/dj-227-tree.md` に記録（predecision-exploration 手順4）。

確定（初期案）:
- DJ-227-1: 独立フラグ `--pick`（一発 fzf picker + `ctrl-r` 手動 reload）。`--watch` の fzf 化（自動 reload）は版数依存配管で不採用。
- DJ-227-2: 内部モード `--pick-list` が render 経路そのままに `%N<TAB>表示行` を emit（森ロジック複製なし・tmux-claude-picker `--list` と同型）。
- DJ-227-3: zoom は対象指定 `resize-pane -Z -t <pane>` + `window_zoomed_flag` を見た ensure-zoomed（冪等）。
- DJ-227-4: gone ペインは候補に残す（ビュー一貫性）。選択時は oe-jump の rc1 を提示。
- DJ-227-5: fzf 非在は番号フォールバック（oe-select 同型）。
- DJ-227-6: popup は `-E` 自然クローズ（明示 close 結合を作らない）。

## 設計SO（oe-refute --rubric exploration・2 レーン codex/cursor）

verdict = **refuted**（2/2 material 反証・audit_id `20260704164920PWZN1700RBD0`）。SO は breadth/grounding レンズで実質的な指摘を返し、以下 2 件を **一次照合・実測で確認**して設計に取り込んだ（procedural な「最良断定は早い」は #221/#223 と同じ SO→人間承認→実装→実測の順で解消）。

- **R1 zoom 対象バグ（real・修正）**: 無指定 `resize-pane -Z` は popup/現 window を掴む到達可能パス。→ `-t "$pane"` 指定 + ensure-zoomed に修正。**隔離 tmux 3.5a で実測**: `resize-pane -Z -t %0`（別 window）で対象だけ zoomed=1・現 window 不変。`display-message -p -t %0 '#{window_zoomed_flag}'` が対象の flag を返す。既 zoom で再 `-Z` すると flag 1→0（トグルの取消し事故＝案A 棄却・ensure-zoomed 採用を実証）。[verified]
- **R2 preview の read-only 境界違反（real・撤回）**: 初期案は oe-select 流用で `tmux capture-pane` preview を付けていた。→ discussion `2026-06-19-discussion-cockpit-observation-ui.md` §8.4（「検出=ペイン出力の走査」・観測系 cockpit は capture-pane を preview から意図的に除外して境界統一）と oe-tree header L31-35（read set を registry/pane-issue/存在・座標・pane_title に限定）を一次確認。→ **preview を採用しない**（観測系 airtight 境界を維持・ツリー行が座標/liveness/label を既に示す）。[verified]
- R3 fallback「家族規約」是正: oe-status -i は plain overview へ degrade（番号型でない）。主張を「oe-select（同じ選択系 verb）と同型」に是正。
- R4 フラグ命名（新 DJ-227-7）: `-i` は oe-status の observe 用と意味が割れるため却下、nav を名づける `--pick` を採用。
- R5 `--watch` hybrid（glance 中に 1 キーで pick）: SO 由来の未探索カテゴリ。**follow-up にスコープアウト**（popup 相互作用依存が強い・`--pick` を土台に additive 可・1 PR = 1 論理変更）。
- R6 fzf field 契約明確化: `--delimiter $'\t' --with-nth 2` + `${sel%%$'\t'*}` で %N 抽出（tmux-claude-picker 同型）。

ユーザー承認: 「とりあえずそれで」＝ revised 設計で実装着手を承認（このペインで直接）。

## 実装フェーズ（随時追記）

oe-tree 単一ツール拡張として実装（別コンポーネントなし）。加えた要素:

- フラグ: `--pick`（対話ナビ）/ `--pick-list`（内部・候補 emit）。`MODE=view|picklist`。`--pick ⊥ --watch`・`--pick-list` 単独/内部を usage エラーで排他。
- 候補生成: 既存 render 経路に `MODE=picklist` のとき `%N<TAB>表示行` の隠しキー列を前置（森ロジック複製なし）。note/空森メッセージは picklist では stderr へ流し stdout を候補列に保つ。
- `--pick` driver: 自身を `--pick-list` で再帰起動（`OE_TREE_SELF` 絶対パス）→ fzf（`--delimiter $'\t' --with-nth 2` + `ctrl-r:reload`）or 番号フォールバック（`OE_TREE_TTY` シーム）→ `${sel%%$'\t'*}` で %N 抽出 → `oe-jump -- %N`（再利用）→ `ensure_zoom`。
- `ensure_zoom`: `display-message -t <pane> '#{window_zoomed_flag}'` を見て 1 以外なら `resize-pane -Z -t <pane>`（対象指定・冪等）。gone/zoom 失敗は popup 用に TTY 3s hold。
- exit 契約: 0=jump+zoom / 1=候補なし・jump/zoom 失敗 / 2=usage・fzf エラー / 130=cancel。

手元 smoke（mock tmux/fzf・隔離）で確認した挙動 [verified]:
- view 回帰: 従来出力と一致（MODE gating が既定を汚さない）。
- `--pick-list`: `%N<TAB>表示行`・note は stderr・空森は stdout 空。
- `--pick`(fzf): 選択 → `select-pane -t %N` + `resize-pane -Z -t %N`（**設計SO R1 の対象指定を実測確認**）。
- 冪等 zoom: flag=1 で `resize-pane` 非呼び出し。gone 選択: oe-jump rc1 伝播。
- fzf cancel→130 / error→2、番号フォールバック: 有効→jump+zoom・範囲外/非数値→2・空→130、空森→rc1。

shellcheck: pass（rc=0）。

## テスト・実装SO

- `test_oe_tree.sh`: [19]-[26] を追加（モード排他・`--pick-list` 形式/stderr 分離・fzf jump+zoom ターゲット・冪等 zoom・gone 伝播・fzf cancel/error/empty・番号 fallback・空森）。**全 60 PASS**（既存 [1]-[18] 回帰込み）。`test_oe_jump`(38)/`test_oe_select`(35) も回帰なし。
  - 実装中に見つけた 1 件: [26] の stderr 検出 assert が `set -uo pipefail` 下で `--pick|grep` のパイプ終了に --pick の exit 1 を拾われ誤判定 → stderr を先に変数へ取ってから grep する形（既存 [8]/[15] と同型）に修正。tool 側の欠陥ではなくテスト記述の罠。
- テストの構造的限界（自動化不能・ライブ実測が正）: 実 popup の対話終了、popup 内 cross-session focus（hg-227-a）、fzf alt-screen × popup（hg-227-b）。mock は select-pane/resize-pane の**呼び出しと引数**までを検証。
- **実装SO（oe-review・impl レンズ・2 レーン codex/cursor）**: verdict = **survived**（material な correctness/到達可能性/堅牢性/セキュリティ欠陥なし・reviewed_sha `0ee2cfe`・audit_id `20260704174832EM1YAVR5KTBC`）。設計SO（設計レンズ・refuted→反映済み）とは別レンズ・別ステップ。

## Closure（episode-retrospective・tier=heavy）

tier=heavy（設計SO refuted による方針是正あり・意図的な外部レビュー 2 種を起動・非自明な設計判断 DJ-227-1〜7）。達成度 = 達成（PR #228・SO 両方通過）。

### closure gate
- **Context / なぜ**: 冒頭に自己完結（#223 の live 表示から「見て飛ぶ + 最大化」を 1 導線に）。
- **次の消費者**: (1) PR #228 レビュアー（Copilot/人間）。(2) `prefix+v` bind を実適用する dotfiles 作業（本 PR 外・親/人間）。(3) `--watch`→`--pick` glance 統合を検討する後続（follow-up）。
- **follow-up routing**: 
  - `--watch` から 1 キーで `--pick` を起動する glance→pick 統合 → **`bin/README.md` の follow-up 節に記載・別 concern**（popup 相互作用が `--pick` 着地の上に乗る additive・設計SO R5 由来）。
  - bind の実適用（`prefix+v`）→ **dotfiles/環境側**（hub は推奨スニペット doc のみ・#202/#223 分界）。
  - hg-227-a（popup 内 cross-session jump）/ hg-227-b（fzf alt-screen × popup）→ **ライブ実測**（自動テスト構造的限界・bind 適用時に人間が確認）。
  - 追わない: fzf `--listen` 真 live picker（版数依存・今回不要）。
- **status 確定**: stable（達成）。
- **evidence anchor**: SO 証跡は揮発（`tmp/`）だが、verdict/reason・reviewed_sha・audit_id・zoom 実測結果を本文へ転記済み。探索木（`tmp/dj-227-tree.md`）の要点（DJ と棄却理由）は本文 + PR 本文へ蒸留済み。
- **SO 証跡リンク**: 設計SO output_dir `tmp/oe-refute-20260704164920PWZN1700RBD0` / 実装SO output_dir `tmp/oe-review-20260704174832EM1YAVR5KTBC`（いずれも揮発・要点は転記済み）。

### 決定と根拠（棄却した案）
- 対話モードの形: `--pick` 独立フラグを採用。`--watch` の fzf 化（自動 reload）は fzf の定期 reload が版数依存配管になり、純ビュー温存の境界にも触れるため棄却。
- zoom: ensure-zoomed（対象指定・冪等）採用。素の `resize-pane -Z`（トグル）は既 zoom で解除方向に倒れ、無指定は popup/現 window を掴むため棄却（実測で確認）。
- preview: **不採用**。oe-select 流用の `capture-pane` は観測系 cockpit の非検出境界（discussion §8.4・oe-status が意図的に外した）に反する。ツリー行が座標/liveness/label を既に示すため不要。
- oe-jump への `--zoom` フラグ追加は棄却（確定境界「新規は fzf + resize-pane -Z のみ / oe-jump 再利用」の外・1 PR = 1 論理変更に反る）。第二 consumer が現れたら昇格を再検討。

### 原則（Pattern / Anti-pattern）
- **Pattern**: 観測ビューに対話を足すとき、表示ロジックを複製せず内部モード（`--pick-list`）で「同一 render 経路 + 隠しキー列」を emit する（`--watch` re-exec と同じ「フレーム=一発実行と同一コードパス」）。tmux-claude-picker の `--list` と同型。
- **Anti-pattern**: 兄弟 verb（oe-select）の UX 部品（capture-pane preview）を無反省に流用する。verb のクラス（観測 vs 送信選択）で境界が違い、oe-tree は観測系の非検出境界に縛られる。設計SO が捕捉。
- **Anti-pattern（テスト）**: `set -uo pipefail` 下で `cmd|grep && echo yes || echo no` は、cmd が非 0 終了だとパイプ終了が grep 一致を隠す。stderr は先に変数へ取ってから grep する（[26] で自己検出・既存 [8]/[15] が正しい型）。

### 蒸留シグナル
- Decision 昇格: **なし**（DJ は #221/#223 の確立パターンの範囲内・新カテゴリの決定なし）。preview 非検出境界は discussion §8.4 に既出で再確認に留まる。
- skill/rule 昇格: なし。

### 残課題
- 上記 follow-up routing のとおり（全て行き先付与済み・dangling なし）。
- 証明できなかったこと: popup 内 cross-session jump + zoom の E2E は mock では覆えず（select-pane/resize-pane の呼び出し・引数までを検証）、ライブ実測が未了（hg-227-a/b）。bind 実適用時に人間確認。
- 実装SO（oe-review・cursor レーン）が挙げた非 material の残リスク（揮発 `tmp/oe-review-...` からの転記）:
  - `ctrl-r` reload はテスト未カバー（手動 smoke 依存）→ 追わない（fzf の bind 動作は fzf 責務・回帰リスク低。必要なら follow-up の watch 統合と併せて）。
  - `#{window_zoomed_flag}` 非対応の古い tmux では冪等 zoom 保証が弱化しうる（コード上の既知 degrade。本環境 tmux 3.5a は対応・flag 未取得時は無害な no-op に倒す設計）→ 追わない（対象環境で対応済み）。

### Step4 外部チェック（closure 品質・so-compare codex 1 レーン）
出力: `tmp/so-20260705-025458/`（揮発・要点転記済み）。指摘 2 点を反映:
- README routing 申告の精緻化: `--pick` 詳細 doc は `bin/README.md`（L362-）に在り申告どおり。加えて project-level `README.md` L50 の 1 行要約が `--watch` 止まりで stale だったため `--pick`/#227 を追記（back-propagation）。
- 実装SO の Open risks（ctrl-r 未カバー・zoomed_flag degrade）を上記残課題へ転記。
その他は問題なし（設計SO refuted・R1/R2・preview 撤回・R5 follow-up・[26] pipefail 罠・discussion §8.4 の back-propagation は明示済みと確認）。

## 追試: 実機 E2E（隔離 tmux サーバ・ユーザーセッション未接触・2026-07-05）

ユーザー要望で mock なしの実機確認を実施。隔離サーバ（`tmux -L oe227live`・2 session × 2 pane）に実 pane を立て、scratch registry に森を登記し、実 `oe-jump` + 実 `resize-pane -Z` を駆動（選択は番号 fallback 経路＝jump/zoom コードパスは fzf 経路と同一）。[verified]

- pick-list が実 forest から候補（`%N<TAB>座標付き表示`）を正しく生成。
- **cross-session jump + zoom**: 別セッション B の pane を選ぶと B の active pane がその pane へ移動し（実 `select-pane`/`select-window`）、B の window が `zoomed=1`（実 `resize-pane -Z -t`）。セッション A は不変。
- **冪等 zoom**: 既 zoom の pane を再選択しても `zoomed=1` 維持（トグル解除しない）。
- **gone**: pane kill 後、候補に gone 表示で残り、選ぶと `oe-jump` が rc1（pane not found）を伝播。
- 番号 fallback の空入力=130 / 範囲外=2 も実サーバで確認。teardown 済み。

hg-227-a/b の更新: cross-session の `select-pane`/`select-window` + targeted zoom は**実 tmux で確認済み**。**未確認で残るのは (1) attached client を別 session へ動かす `switch-client`（headless テストは client 未接続のため no-op だった。実 popup では効くはず・要人間確認）(2) tmux popup 内での fzf 対話 UI（alt-screen 相互作用・自動化不能）**。この 2 点は `prefix+v` bind 適用時に人間が実 popup で確認する。

## 追試2: 実 popup・ライブセッションでの人間実操作（2026-07-05・ユーザー実行）

ユーザーが本番セッションで `tmux display-popup -E '... oe-tree --pick'` を 2 回実行（`bin/README.md` の推奨スニペット同型）。read-only クエリで確認した結果 [verified]:

- 1 回目: 候補（登記 4 件: `%125` #901-topo / `%131` #227 / `%85` #902 / `%94` #36）から `%125`(#901-topo) を選択 → active pane が `%125`（window `0:1`）へ移動し `0:1` が `zoomed=1`。
- 2 回目: `%131`(#227) を選択 → active が `%131`（window `0:3`）へ移動し `0:3` が `zoomed=1`。1 回目の `0:1` は最大化のまま（飛び元/前回対象を unzoom しない＝設計どおり）。

これで **hg-227-b（tmux popup 内での fzf 対話 UI・alt-screen 相互作用）= 実機確認済み**（popup 内で fzf が描画・キー選択を受け付け、選択が 2 回とも成立）。**jump + targeted zoom は実 attached client でも確認済み**（cross-window・同一 session）。**hg-227-a のうち cross-session `switch-client`（client を別 session へ移動）だけは未確認のまま**（ユーザーの pane が全て session `0` のため cross-session hop が発生せず。select 系 + zoom は隔離サーバの追試1で確認済み）。→ 実運用で別 session の子が立った時に自然に確認される（追わない残課題）。

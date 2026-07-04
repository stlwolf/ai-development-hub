---
id: "01KWQ1EENZ8YKR0KS1SCSTJ305"
title: "#227 episode — oe-tree に対話ナビ（fzf 選択 → oe-jump → resize-pane -Z 最大化）を追加"
date: 2026-07-05
type: episode
status: in-development
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

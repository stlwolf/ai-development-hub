---
id: 01KVMRHZ8TSBA8KZYZDW55AKW2
title: "#202 ペイン識別（oe-ident / read-time ambient）実装エピソード"
date: 2026-06-21
type: episode
status: stable
related:
  - type: implements
    ref: "#202"
  - type: discussion
    ref: ../discussions/2026-06-21-discussion-202-pane-identity.md
  - type: depends_on
    ref: "#188"
---

# #202 ペイン識別（oe-ident / read-time ambient）実装エピソード

> リアルタイム追記（reconstructed ではない）。cockpit 統括セッション（`%32`）が WORKTREE
> `feature/#202_pane_identity` で直接実装（委譲なし）。

## コンテキスト / 動機

multi-session オーケストレーションで人間が tmux UI を見て **どのペインがどのセッション/role か
区別できない**（#202）。一貫した識別子が付くのは `wt switch` 済み Claude ペインだけ。

## 設計探索（discussion doc が正本）

調査 → 選択肢 (a)〜(d) → 当初 (c′) stored `@oe_id` を主軸候補に → **設計SO（oe-refute
exploration 3 レーン）が 3/3 refuted**（#188 思想との不整合 / stored 状態の未検証 lifecycle /
resolve 契約破壊リスク / 未探索の read-time 表示案）→ **(c″) read-time ambient へピボット**。
詳細は `../discussions/2026-06-21-discussion-202-pane-identity.md`。

**学び（設計SO の実価値・再掲）**: 実装前に write-path 案の落とし穴と、2 日前 accepted の
#188 思想に沿う優位な代替（`#()` 表示時計算）を捕捉。`exhaustion-before-conclusion` どおり、
収束をモデル任意でなく SO で構造的に阻止できた。SO 主張（#188「逆走」）は鵜呑みにせず #188 を
一次照合し「禁止ではないが grain に逆らう」と補正（過去 #114 の SO 主張未検証の反省を適用）。

## 実装

- **`bin/oe-ident <pane> [server_pid]`**（新規・read-only）: pane-issue(`.name`) → spawn-registry
  (`.label`) を読み role+label を 1 行返す。role= parent（子を spawn）/ child（被 spawn）を
  registry 読取のみで導出。識別情報無→空出力。常に exit 0（border を壊さない）。
  - `delegate-registry.sh` の `_oe_reg_key` / ソース読取を再利用（キー契約を共有）。
  - `server_pid` を明示引数で受けられる（`#()` で TMUX env 不在に備え `#{pid}` を渡せる）。
- **`bin/README.md`**: oe-ident 節 + dotfiles 用 `pane-border-status`/`pane-border-format` スニペット。
  表示有効化は dotfiles 責務（hub は強制せず doc のみ）。
- **触らないもの**: `oe-delegate` / `oe_reg_list` / `oe_reg_resolve`（→ 宛先解決契約は不変・
  SO 指摘の resolve 破壊リスクは構造的に解消）。`@oe_id` 書込なし。

## tmux #() 実機検証（前提を組む前に確認）

隔離 tmux 3.5a で: `#{pane_id}`/`#{pid}` は引数内で展開 / env に `TMUX` セット / `#()` は
非同期キャッシュ（初回空）。残存不確実性に備え `#{pid}` 明示渡し設計で防御。

## 検証

- shellcheck: `oe-ident` / `test_oe_ident.sh` rc=0。
- テスト: **bash 3.2.57 / 5.2.37 で test_oe_ident 11/11**（pane-issue / child / parent /
  standalone / unknown / 不正引数 / pane-issue 優先 / parent 優先 / 引数欠落）。
- **実装SO（oe-review・2 レーン codex/cursor）survived 2/2**（audit `20260621093204NV8VKKJ0B9S6` /
  diff_base origin/master / reviewed_sha b4a27ec）。material 欠陥なし。codex「新規テスト未実行」は
  本セッションで 11/11 実行済みでカバー。cursor「stale registry 表示」は既知 tradeoff（欠陥でない・
  `oe_reg_gc` が掃除）。

## closure

- status: `stable`。consumer = cockpit を見る人間（pane-border の識別子）+ dotfiles 設定者。
- tier: 中（新規コマンド + role 導出 + tmux 連携検証）。設計SO + 実装SO 両方実施。
- routing: 親（`%32`）が直接実装 → PR → Copilot。
- Decision 昇格: **なし**。c″（read-time ambient・write path 無し）は #188（read 時相関・
  永続マップ不採用）の **display への適用**であり、新しい設計決定ではない。discussion doc + #188 で足りる。
- defer: (b) read-time マップコマンド（`oe-ident` の読取を共有して別 issue）/ engine wez 子の
  human 識別（#188 トポロジで tmux 不可視・本 issue 範囲外）。

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

> **reconstructed**（締めで一括執筆＝後追い再構成・リアルタイム追記ではない＝証拠価値はその分低い）。
> cockpit 統括セッション（`%32`）が WORKTREE `feature/#202_pane_identity` で直接実装（委譲なし）。

## コンテキスト / なぜ

multi-session オーケストレーションで人間が tmux UI を見て「どのペインがどのセッション/role か」
区別できない（#202）。一貫した識別子が付くのは `wt switch` 済み Claude ペインだけ。

## 決定と根拠（diff から復元不能なコア）

当初 (c′) stored `@oe_id` を主軸候補にしたが、**設計SO（oe-refute exploration 3 レーン）が 3/3 refuted**
→ **(c″) read-time ambient へピボット**。棄却理由が本 episode の保存価値:

- #188 思想（read 時相関・永続マップ不採用）に逆らう（一次照合: DJ-188-5 で producer 書込は
  「禁止ではないが grain に逆らう」と補正）
- stored 状態の lifecycle（pane 再利用/分割）未検証 / `oe_reg_list`・`oe_reg_resolve` の宛先解決
  契約を壊すリスク / 未探索の `#()` 表示時計算（書込なし read-time）
- c″ は上記すべてを**構造的に解消**（write path 無し・契約不変）

選択肢 (a)〜(d) の全比較・tmux `#()` 実機検証（引数展開 / TMUX env / 非同期キャッシュ）・現状の識別
サーフェス棚卸しは **discussion doc が正本**（重複を避けここでは再掲しない）:
`../discussions/2026-06-21-discussion-202-pane-identity.md`。

## 検証（要点・SO 証跡）

- shellcheck rc=0 / **bash 3.2.57・5.2.37 で test_oe_ident 11/11**。
- **設計SO** oe-refute exploration 3 レーン: **refuted**（audit `202606210816320B6ZZ7CP9ZWX`・c′→c″ の起点）。
- **実装SO** oe-review 2 レーン: **survived 2/2**（audit `20260621093204NV8VKKJ0B9S6` / diff_base
  origin/master / reviewed_sha b4a27ec）。cursor「stale registry 表示」は既知 tradeoff（欠陥でない）。
- Copilot: テストの key 生成を `_oe_reg_key` の source 共有へ（契約ドリフト解消・1 指摘対応）。

## closure

- status: `stable` / **達成度: 達成**（oe-ident 実装・テスト・SO 通過。表示有効化は dotfiles 側 opt-in で別途）。
- tier: **heavy**（方針転回 c′→c″ / 意図的 SO 2 本 / 非自明な設計棄却）。
- 次の消費者: cockpit を見る人間（pane-border の識別子）+ dotfiles 設定者（pane-border-format 設定）。
- 蒸留シグナル: **昇格なし**。c″ は #188（read 時相関）の display への適用で新規決定でない（discussion + #188 で足りる）。
- follow-up routing:
  - (b) read-time マップコマンド → **別 issue（未起票）**・`oe-ident` の読取ロジックを共有
  - engine wez 子の human 識別 → **追わない**（#188 トポロジで tmux 不可視・本 issue 範囲外）
- **Step4 辞退（heavy 外部チェック）**: closure 品質 4 観点を自己点検し小機能・低リスクと判断して辞退。
  覆った観点= 失敗の選択的省略なし（c′ refuted を明記）／ routing 網羅（上記 defer 2 件に行き先）／
  evidence anchor（SO audit id を本文転記）／ back-propagation 漏れなし（#188 と非矛盾・discussion に保全）。
  未実施観点と判断= so-compare 再チェックは小機能 + 自己点検で覆えるため不実施（重複ゲート回避）。

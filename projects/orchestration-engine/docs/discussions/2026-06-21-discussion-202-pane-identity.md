---
id: 01KVMR8ZV8R2T2E4XQWJYQ7JWX
title: "#202 人間可読なペイン識別 — 設計探索（c′ 反証 → c″ read-time ambient へピボット）"
date: 2026-06-21
type: discussion
status: stable
related:
  - type: implements
    ref: "#202"
  - type: depends_on
    ref: "#188"
  - type: parent
    ref: "#169"
---

# #202 人間可読なペイン識別 — 設計探索

## 問題

multi-session オーケストレーション（親=統括 / 子=delegate / peer）で、人間が tmux UI を見て **どのペインがどのセッション/role か区別できない**。一貫した `#issue slug` タイトルが付くのは `wt switch` 済みの Claude ペインだけで、素ペインは hostname に劣化、delegate 子は pane-title ノイズ、role 次元（parent/child/peer）はどこにも出ない。詳細な現状棚卸しは調査で file:line 付きで実施（`delegate-registry.sh:140-154` の 3 ソース・親スコープ等）。

## 探索した選択肢

- (a) session-name.sh / wt-pane-issue を wt-switch 非依存化し pane_title に role 折込（mutating・engine 子に届かず・session-name と二重 writer）
- (b) read-time `session-map` コマンド（完全 read-only・pull 型・glance を直さない）
- (c) spawn 時に pane_title を直接 set（pane_title 奪い合い）
- (c′) `@oe_id`（tmux カスタムペインオプション）に stored 識別子を書き pane-border に表示（pane_title を汚さない ambient）
- (d) ハイブリッド

当初 (c′) を「主軸」候補とした（pane_title を奪わず ambient に出せることを tmux 3.5a 隔離サーバで実証）。

## 設計SO（oe-refute --rubric exploration・3 レーン codex/claude/cursor）

(c′) を claim として反証 → **3/3 refuted**（audit `202606210816320B6ZZ7CP9ZWX`）。主要な指摘:

- **#188 思想との不整合**: #188 は「read 時相関・永続マップ不採用」（DJ-188-3）。stored `@oe_id` はその grain に逆らう。
  - 一次照合（SO 主張を鵜呑みにせず確認）: #188 DJ-188-5 は「read-only は**観測者**を縛る制約・producer 書込は対象外・**本決定は新規 write path を導入しない**」。→ c′ の書込は #188 が**禁じてはいない**が、思想（read 時投影）には**逆らう**。SO の「逆走」は言い過ぎだが方向（read-time がより整合）は正しい。
- **未検証前提**: `@oe_id` の永続性（pane 再利用/分割/copy-mode）・`--auto` role 自動導出。
- **registry 契約への波及**: `oe_reg_list` に `@oe_id` を足すと oe-send targeting の parent-scope 封じ込めを壊す / stale 上書き事故。
- **未探索カテゴリ**: `pane-border-format` の `#(shell-command)` で**表示時に既存ソースから計算**（＝書込なしの read-time ambient）。(b) read マップも未比較。

## ピボット: c″ — read-time ambient

SO が浮かせた `#()` 表示時計算カテゴリへ主軸を移す:

- 新 read-only コマンド `oe-ident <pane> [server_pid]` が pane-issue / spawn-registry を読み role 込みの識別子を 1 行返す。
- 表示は `pane-border-format '#(.../oe-ident #{pane_id} #{pid})'`（dotfiles opt-in・hub は doc のみ）。
- **新規 write path ゼロ**（#188 read 時相関と同型・grain に沿う）。`@oe_id` の永続性/stale 問題が消える。`oe_reg_list`/`oe_reg_resolve` を改変しない → **SO 指摘の resolve 契約破壊リスクも構造的に解消**。

これにより SO の 4 指摘（#188 不整合 / 未検証 stored 状態 / resolve 契約 / 未探索 read-time）が同時に解消。`exhaustion-before-conclusion` の所期どおり、設計SO が確定前に write-path 案の落とし穴と優位な代替を捕捉した。

## tmux `#()` 実機検証（前提を組む前に確認）

隔離 tmux 3.5a で確認:

- 素のフォーマット変数 `#{pane_id} #{pid}` は展開される（`%0 55793`）[verified]。
- コマンド引数内でも展開され、env に `TMUX` がセットされる（pid 一致）[verified・run-shell 経由]。
- `#()` は **非同期/キャッシュ実行**（初回空・以降 `status-interval` 毎更新）[verified・display-message では同期発火せず空]。

→ 表示用途では非同期キャッシュで問題なし。`#()` 環境の残存不確実性（async で直接 probe 不可）に備え、**`#{pid}` を明示引数で渡せる設計**にし TMUX 不在でも解決可能にした（防御）。

## 決めたこと

- 主軸 = c″（read-time ambient）。`oe-ident` を新規追加。
- role 導出（read のみ）: parent=この pane を parent_pane に持つ子 entry が在る / child=自身の spawn entry が在る / 両方なら parent 優先。
- label: pane-issue(`.name`) 優先 → spawn-registry(`.label`)。無ければ空（honest）。
- 表示有効化は dotfiles 責務（hub は推奨スニペットを bin/README に明記）。

## やらない / defer

- (b) read-time マップコマンド: follow-up（`oe-ident` の読取ロジックを後で共有可）。
- engine wez 子の human 識別: #188 トポロジで tmux 不可視 → 本 issue は **delegate/tmux 基盤**の識別に限定。
- 素の非エージェントペイン: ソースが無ければ空表示（捏造しない）。

## 参照

- 設計SO 生出力: `tmp/oe-refute-202606210816320B6ZZ7CP9ZWX/`（worktree・gitignore）
- `../decisions/2026-06-19-decision-188-identity-unification.md`（DJ-188-3/5）
- 調査の現状棚卸し（識別サーフェス table）は本 discussion 冒頭に要約

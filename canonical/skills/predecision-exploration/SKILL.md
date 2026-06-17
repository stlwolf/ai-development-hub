---
name: predecision-exploration
description: 設計判断を確定する前に、ゼロベースで未探索の代替案を最低1回引き出し、その証跡を確定前に残してから確定する。複数の選択肢を A/B 等で確定しかけたとき、ADR / Decision / kickoff の設計判断（DJ-N）を確定・記録するときに使用する。so-compare 選択肢拡張・探索木の外部化を含む。
depends:
  - skill: so-compare
  - skill: kickoff-to-plan
  - skill: episode-retrospective
  - command: peer-ai-review
---

# Predecision Exploration — 設計確定前のゼロベース代替探索

`exhaustion-before-conclusion-rule`（傘原則）の**設計ドメイン側の層2**（soft forcing ＋ 選択肢の外部化）。

> **不変条件**: 設計を確定する前に、初期案セットの外にある代替探索 SO を最低1回**実行**し、その結果（探索木＋SO 出力パス＋採否）を**確定前に artifact へその場で残す**。記録を closure（episode）まで先送りしない。

「収束をスクリプト層のカウントで判定する」hard 版は本スキルには含まない（defer、限界参照）。

## いつ使うか

- 複数の選択肢から1つを選んで設計を確定しようとするとき（A/B で決まりかけた局面）
- ADR / Decision / kickoff の設計判断（DJ-N）を確定・記録するとき
- 「これで確定、先に進む」と言いそうになったとき

## いつ使わないか

- 小さく低リスクで後戻りコストの低い判断（過剰適用は analysis paralysis。`exhaustion-before-conclusion-rule` の Scope と整合）

## 原則

wez notify の option C（TTY 直接書き込み）は、A/B 仮決定**後・最終確定前**のゼロベース SO 再レビューで初めて出た。この発見を**人間の即興でなく既定手順**にするのが本スキル。「確定前にまだ探索する」トリガーが無いのが最大のギャップ — そこを埋める。

## 手順

1. 初期選択肢セットと暗黙の前提を明示的に列挙する。
2. 最低1回、ゼロベース SO を**実際に回す**（インラインで「なぞる」だけにしない）。`so-compare` の「選択肢拡張（設計を確定する SO のとき）」テンプレを使い、初期案と異なるカテゴリ / 責務分界 / データフロー / 実行経路 / 運用前提の代替案を出させる。タイミングは「A/B 仮決定後・最終確定前」を含む（最終確定後ではない）。
   - `so-compare` が使えない / timeout する場合は、確定を止めて人間承認を取る（黙って skip しない）。
3. 出た代替案は「良さそう」で止めず、検証可能な条件で即検証する（検証不能な環境では検証条件を残して保留）。
4. **確定前に証跡をその場で残す**: 探索木＋SO 出力パス（`tmp/so-*/`）＋採否を、確定と同一セッションで**確定前 artifact** に書く。置き場は手近なもの: `tmp/dj-N-tree.md` / ADR 草稿の「棄却案」節 / kickoff の DJ 節 / PR 本文 / peer-review ログ（`tmp/peer-review-*/review-log.md`）。**episode closure まで先送りしない**（「後で追記」は監査で 100% 不履行＝L4）。
5. 暫定停止条件を満たしたら確定に進む（下記）。

## 探索木フォーマット（選択肢の外部化）

`persistent-exploration` の探索木を設計選択肢に流用。検討案・差分軸・採否・未探索ブランチ・SO 出力パスを残す。

```text
<設計判断 DJ-N: ...>
├── 案A（初期） → 差分軸: ... → 採否: ❌ 理由 ...
├── 案C（ゼロベースで発見） → 差分軸: ... → 検証: ✅（SO 出力: tmp/so-XXXXXX/） → 採用
└── 未探索: <軸>（なぜ今探索しないか）
```

## 暫定停止条件（確定的収束ではない）

- 目安: 最低1回のゼロベース SO で新カテゴリの案が出なければ、確定に進んでよい。
- これは disposition（モデル依存の暫定停止）であって確定的な収束判定ではない。§3.4 が求める「収束をモデルに委ねない＝スクリプト層カウント」は hard 版（defer）の領分。新カテゴリが出続ける場合の上限・打切りは人間判断。

## ライフサイクル上の位置づけ

- **本スキル（中間・確定時）**: 確定前に証跡を artifact に残す（手順4）。これが #77 の teeth。
- **episode-retrospective（締め）**: closure 時に手順4の証跡を「決定と根拠（棄却した案と棄却理由）」へ蒸留・要約する（後段の標準保管先）。episode はファイルとして常に存在する保証ではないので、確定時の証跡を episode 任せにしない。
- **#159（開始側・上流・未着手）**: episode 枠の生成と追記忘れ防止のみ。本スキルの確定時証跡要求は #159 に委ねない。
- **予防アンカー**: kickoff が DJ を宣言するなら確定前に本スキルを適用。
- **plan-mode 経路**: `kickoff-to-plan` の `DJ-GATE:` が DJ を含む kickoff 変換時にゲートを TODO 化（plan-mode 縮小傾向のため軽いまま）。
- **決定的トリガ**: hook 自動注入（#24）は defer（spot-check 後）。

## 境界（重なり回避）

- `so-compare` 選択肢拡張: SO のテンプレ（道具）。本スキルは「確定前に**実 SO を1回回し証跡を残す**」起動条件＋探索木＋確定時記録。
- `exhaustion-before-conclusion-rule`: 傘原則。本スキルは設計ドメインの層2。Minimal discipline（結論時に未探索を明示）を設計確定局面で具体化（探索木＋DJ 単位の確定前証跡）。
- `reframe-on-stall-rule`: 空転時の作り直し（探索中）。確定間際の空転は両者が効きうる — まず本スキルで代替を出し、なお空転なら reframe で枠ごと組み直す。
- `question-driven-design`: 設計を質問で掘る前段。QDD 完了 ≠ 探索完了。
- `peer-ai-review`（command）: 設計判断の合意ループ。**順序**: 合意ループに入る前・各 DJ 確定前に本スキルの1回ゼロベース探索を済ませる（合意ループと二重 SO にしない）。
- `persistent-exploration`: 「不可能」判定前に諦めない（バグ調査・逆向き・別ドメイン）。

## 限界

- 遵守はモデル依存。**確定的トリガ（hook, #24）は未実装**（spot-check 後）。発火は description マッチ＋kickoff 予防＋（plan-mode 経路の）DJ-GATE。
- **hard 版は defer**（orchestration 多周プリミティブ待ち）: §3.1 出力差分 reject／§3.2 生成・反証の物理分離／§3.3 一次検証の機械義務化（hook exit code）／§3.4 スクリプト層カウント収束。本スキルはこれらを持たない soft 層2。
- episode への蒸留の追記信頼性は #159（未着手）依存。ただし**確定時証跡（手順4）は本スキルが今担保する**ので、#159 未着手でも確定前 forcing は成立する。

## 参照

- `canonical/rules/exhaustion-before-conclusion-rule.md`（傘原則）
- `canonical/skills/so-compare/SKILL.md`（選択肢拡張テンプレ）
- `canonical/skills/episode-retrospective/SKILL.md`（closure 時の蒸留先＝決定と根拠）
- `canonical/skills/persistent-exploration/SKILL.md`（探索木・逆向きの弁別）
- `canonical/commands/verification/peer-ai-review.md`（合意ループ）
- `docs/specs/2026-04-23-discussion-exploration-process-design.md` / `docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md`
- `projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md`（option C）
- 関連 issue: #159（start-side episode gate）/ #24（フック軸）

---
name: code-path-exhaustion
description: エラー/バグ調査で、入力→出力のコードパスに未読区間がある限り外部要因（インフラ差異等）の仮説に進まない。外部要因に飛ぼうとするとき、原因が再現しないと判断しそうなときに使用する。仮説を tmp/hypothesis-NNN.md に外部化し、コードパスの read-state を可視化する。
depends:
  - skill: persistent-exploration
  - skill: episode-retrospective
---

# Code Path Exhaustion — コードパス網羅原則

`exhaustion-before-conclusion-rule`（傘原則）の**バグ調査ドメインの層2**（soft forcing ＋ 仮説の外部化）。#77 `predecision-exploration`（設計ドメイン）の姉妹。

> **コードパス網羅原則**: エラー調査において、入力から出力までのコードパスに未読区間がある限り、外部要因の仮説に進むな。

> **不変条件**: 外部要因の仮説に進む前に、各仮説を `tmp/hypothesis-NNN.md` にその場で外部化し（試したアプローチ・結果・未読/未試行ブランチ・コードパスの read-state）、closure まで先送りしない。

## いつ使うか

- エラー/バグ調査で、外部要因（インフラ差異・環境・他システム等）の仮説に飛ぼうとするとき
- 「再現できない」「コードは悪くない」と判断しそうなとき
- 仮説が複数たまってきたとき（hypothesis-gate フックが N=3 で誘導する）

## いつ使わないか

- 入出力のコードパスが小さく即読了できる些末な調査（過剰適用しない）

## 原則の出自

別プロジェクトの Sentry 調査で、入力→出力のコードパスに未読区間が残ったまま外部仮説（インフラ差異）に飛び、2ステップで解けるところを6ステップ要した。この「未読のまま外部へ飛ぶ」を既定手順で止める。

## 手順

1. 入力→出力のコードパスを辿り、**未読区間を可視化**する（どこを読んだ / 読んでいないか）。
2. 仮説を立てるたびに `tmp/hypothesis-NNN.md` にその場で外部化する（下記フォーマット）。空転（同じ抽象度の横移動）を物理的に見えるようにする。
3. `persistent-exploration` の突破口チェックリスト（API 直接・DB 状態・マイグレーション履歴等）でコード側の代替アプローチを尽くす。
4. 入出力のコードパスに未読が無くなって初めて外部要因の仮説に進む。
   - **engine 統合経路**（効果は未測定・#177 で観測予定＝so-compare 手動反証を engine 統合・再現可能にした段階）: 外部要因へ進む確定の前に、「コードパスは読了し原因は外部要因である」を `claim` とした claim doc（frontmatter ＋ body に `hypothesis-*.md` 群＋read-state を集約）を `oe-refute --claim <doc> --rubric exploration` で**同期反証**する。生成と物理分離した独立レーンが breadth(軸5＝未読パス/未試行が残らないか)/grounding(軸3＝根拠) レンズで反証し、`{verdict, reason, output_dir}` が `refuted` なら外部要因ジャンプを**保留**する。`output_dir` は揮発するので verdict/reason の**内容**を確定時証跡へ転記する（パスだけに頼らない）。
   - `oe-refute` / `so-compare` が使えない / timeout する場合は、外部要因ジャンプの確定を止めて人間承認を取る（黙って skip しない）。

## hypothesis ファイルフォーマット

```text
# hypothesis-NNN: <仮説の一文>
- 種別: コード内 / 外部要因
- 試したアプローチ: ...
- 結果: ❌ / ⚠️ / ✅
- 読んだコードパス: <file:line 範囲>
- 未読 / 未試行: <残り>
```

## 暫定停止条件（確定的収束ではない）

- 入出力コードパス読了、または `persistent-exploration` の代替を尽くしたら外部要因へ進んでよい。
- disposition（モデル依存）。スクリプト層での強制ブロック・収束カウントの hard 化は defer（限界参照）。

## 半機械ゲート（advisory hook）

`canonical/hooks/scripts/hypothesis-gate.sh`（Claude PostToolUse(Write|Edit|MultiEdit)）が `tmp/hypothesis-*.md` を数え、**N=3 に初めて達したとき marker で1回だけ advisory 通知**する（Edit や削除→再作成では再発火しない）。「外部要因に進む前にコードパス未読を確認」を促すが**ブロックはしない**（compliance はモデル依存）。N=3 は暫定値（出自 spec は「N 個」とだけ）。**この hook は仮説ファイル外部化経路のリマインダであり、ファイルを作らず chat 上で外部仮説に飛ぶ経路は捕捉しない**（その経路は skill 本体／description マッチ任せ）。

## 記録先

hypothesis ファイル（確定時証跡）→ closure 時に `episode-retrospective` の「事実・失敗 / 決定と根拠」へ蒸留する。**`tmp/` は揮発（gitignore）**なので、読んだコードパス・棄却した仮説の要点は closure を待たず episode/PR 等の永続先へ転記する（tmp 参照だけで終えない＝`episode-retrospective` の evidence anchor と同義。「後で追記」は監査で 100% 不履行）。`oe-refute` を使ったなら verdict/reason＋`output_dir` も同様に確定時証跡へ転記する。

## 境界（重なり回避）

- `persistent-exploration`: 諦めず代替アプローチを尽くす突破口チェックリスト（手段集合）。本スキルとの差は**時系列の前後ではなく役割**: 本スキル＝「外部要因に飛ぶ gate＋コードパス read-state の証跡フォーマット」、persistent＝「突破口チェックリスト」。手順3 で persistent を**内包**し、実運用では両者を交互に行き来する（線形の前後ではない）。
- `reframe-on-stall-rule`: 空転時のゼロベース作り直し（探索中の反射）。仮説が同じ抽象度で横滑りしているなら本スキルの外部化と同時に効きうる — 仮説を外部化してなお空転なら reframe で枠ごと組み直す。
- `sentry-investigation`: Sentry API のパターン集（道具）。本スキルはコードパス網羅の起動条件。
- `issue-debug`: 調査フロー全体。本スキルはその Step（コード探索→原因分析）での「外部要因ゲート」。
- `exhaustion-before-conclusion-rule`: 傘原則。本スキルはバグ調査ドメインの層2。
- `predecision-exploration`（#77）: 設計確定の層2（別ドメイン・別トリガ）。確定時証跡＋外部化のパターンは共通。

## 限界

- compliance はモデル依存。hook は **advisory（ブロックしない）**。hard 版は段階導入に移行: 生成・反証の物理分離は **`oe-refute`（Stage A・engine 統合の同期反証 verb・PR #184）で着地**（独立レーンが生成と物理分離で反証）。決定的な強制ブロック・スクリプト層の収束カウント（hard 化）は engine verify ゲート拡張（Stage B）／ #24（フック軸・Stage C）／ CLI cockpit の infra 強化待ちで defer。
- hook は現状 **Claude 側のみ**配線（codex / cursor は PostToolUse 未配線）。スキル本体は3者配信される。

## 参照

- `canonical/rules/exhaustion-before-conclusion-rule.md`（傘原則）
- `canonical/skills/persistent-exploration/SKILL.md`（突破口チェックリスト・後段）
- `canonical/skills/predecision-exploration/SKILL.md`（#77・姉妹パターン）
- `projects/orchestration-engine/bin/oe-refute`（Stage A・確定前の同期反証 verb・so-compare wrap）
- `projects/orchestration-engine/docs/discussions/2026-06-18-discussion-exploration-hard-layer-on-engine.md`（hard 層 × engine substrate の合流）
- `canonical/hooks/scripts/hypothesis-gate.sh`（advisory hook）
- `canonical/skills/episode-retrospective/SKILL.md`（蒸留先）
- `docs/specs/2026-04-22-discussion-hypothesis-driven-exploration.md` §2（コードパス網羅原則・仮説ファイル）

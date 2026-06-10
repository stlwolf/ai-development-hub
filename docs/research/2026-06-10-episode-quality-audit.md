---
title: "蓄積 episode の品質監査 — 文脈復元性の全数採点と劣化法則の抽出（Issue #149）"
date: 2026-06-10
status: research-complete
tags: [research, episode, quality-audit, context-restorability, distillation-pipeline, retrospective]
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/149"
    reason: "本監査の対象 Issue（調査・提言まで。実装はスコープ外）"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/113"
    reason: "提言 R1（skill 化 GO + 必須項目の重心移動）の根拠"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/62"
    reason: "提言 R5（注入対象の選別基準）の根拠"
---

# 蓄積 episode の品質監査 — 文脈復元性の全数採点と劣化法則の抽出

## 0. 要旨

本リポジトリの episode 52 件を 6 軸 rubric で全数採点した。主要結果は 3 点。なお本節は本文の要約であり、検証ステータスはここでは付さない — 各主張のステータスと根拠（file:line / 再実行可能コマンド / 集計元）は §3〜§8 の対応箇所に付与している（規約は §2.4）。

1. **「時系列劣化」は起きていない**。過去向き軸（WHY 復元・判断復元・証拠接続）は世代とともに改善している。唯一の全世代・全構造型共通の穴は**軸5（closure = follow-up の行き先付与・status 確定）**で、平均 1.12/2、満点率 19%。蒸留（教訓化）はむしろ 2026-02 がピークで、テンプレ化が進んだ 2026-05 に低下した
2. **closure は「次の消費者」が存在するときだけ書かれる**（法則 L1）。この機序はゼロベース監査と先行の消費者予見仮説が独立に収束した。対照群（owner-report）は「明示的な運用方針があれば消費者予見なしでも記入率は上がる」ことを示し、明示ゲートで書かせる skill 化（#113）を直接支持する
3. **「後で追記」型の先送りは観測範囲で 100% 不履行**（法則 L4）。書き忘れ対策は事後リマインダではなく、closure 時の同期ゲートでしか機能しない

提言: #113 は skill 化 GO。ただし設計の重心を「振り返り枠組み（KPT/YWT）」から「**消費者明示 + follow-up routing + status 確定**」へ移す（§8 R1）。

## 1. 目的・スコープ

- 対象: 本リポジトリの episode コーパス = `projects/**/docs/episodes/**` ∪ `type: episode` frontmatter 保有分（2026-06-10 監査時点のスナップショット）。本ノートと同じ PR で新設する `docs/episodes/`（プロジェクト横断置き場とメタ実験 episode）は監査実施後の成果物であり**対象外**。別リポジトリの episode は直接参照しない
- 問い: (1) 文脈復元性の実態 (2) 劣化の法則 (3) #113 を閉じる / rule 化 / spec-card 強化 / 書き忘れ対策のどれが妥当か
- 本ノートは調査・提言まで。実装（skill/rule 化・hook 追加）は後続 Issue（#113 等）で扱う

## 2. 方法

### 2.1 ゼロベース設計

評価軸は先行議論を読まず、コーパス一次データ（全 52 件の frontmatter・見出し構造・git 履歴 + 層化サンプル精読）のみから設計した。Issue #149/#113/#62 の 2026-06-10 付コメント（先行仮説）は、自前の法則抽出が完了した後に初めて読み、事前登録した仮説と突合した（§6）。

### 2.2 評価軸（6 軸 × 0–2 点、HG1 承認済み）

| 軸 | 問い | 0 / 1 / 2 |
|---|---|---|
| 軸1 WHY 復元 | なぜ始まったかを文書から復元できるか | 記述なし / リンク経由のみ / 文書内で自己完結 |
| 軸2 判断復元 | 選択肢・採否・棄却理由が残っているか | 結果のみ / 採用理由のみ / 選択肢+根拠+棄却+トレードオフ |
| 軸3 証拠接続 | 主張が検証可能な痕跡に接続されているか | 主張のみ / 一部 / 主要な主張が痕跡付き |
| 軸4 蒸留度 | 羅列を超えた一般化があるか | 純粋な羅列 / 個別メモ / 転用可能な知見 |
| 軸5 closure | 閉じて次へ流したか | 未閉鎖の穴 / 形式上閉鎖 / 閉じて接続 |
| 軸6 メタデータ | frontmatter の有無・正しさ | なし / 部分・stale / 現行仕様充足 |

軸2 には N/A を導入（作業自体に判断ポイントが存在しない場合のみ。立証責任は N/A 側、迷ったら 0 点）。**結果的に N/A 適用は 0 件**だった。

### 2.3 採点の実行と検証規律

- 全数 52 件（サンプリングなし。「薄い episode リスト」は標本では作れないため。retrospective 名への偏りも構造的に回避）
- 軸1〜5 はサブエージェント 7 バッチに委譲し、**各点数に逐語引用（根拠）を必須化**。軸6 は frontmatter 抽出データから機械判定
- spot-check（evidence-verification-rule 準拠）: 負荷の高い主張 10 件を実ファイル照合し **10/10 一致** [verified]（照合先は §3・§5 に file:line で記載。クロスファイル整合 2 件・矛盾/プレースホルダ 6 件・無作為引用 2 件）
- 採点者間信頼性: 親が事前に精読していた 6 件でサブエージェント採点と **30/30 軸一致**。ただし親はバッチ結果を見た後の照合であり、厳密な独立二重採点ではない（限界）

### 2.4 検証ステータス規約

本ノートの非自明な主張には `[verified]`（一次ソースを直接照合済み）/ `[unverified-summary]`（ソースは明示するが含意未照合の要約・解釈）/ `[speculation]`（ソースなしの推測）の 3 値（`docs/research/README.md:90-92` の語彙）を付す。`[verified]` の根拠は `file:line` または再実行可能なコマンド + 対象範囲で示す（コーパス集計値は後者）。オーナー聞き取り由来の情報は独自ステータスを設けず **`[unverified-summary]` とし、本文で「owner-report（聞き取りの体感値）」と注記**する。

## 3. コーパス棚卸し

総数 **52 ファイル / 7 プロジェクト** [verified]（`find projects -path "*/docs/episodes/*" -name "*.md"` をリポジトリルートで実行、2026-06-10 時点。新設 `docs/episodes/` はスコープ外のため本 PR マージ後も同コマンドで 52 件が再現する）。内訳: orchestration-engine 22 / second-opinion-verification 9 / arena-compare 6 / cursor-thread-tools 6 / wezterm-ai-mode 6 / ruler-agent-verification 2 / agent-verification-flow 1。

frontmatter: `type: episode` 41 / `type: report` 6 / なし 5 [verified]（全 52 件の先頭 `---` ブロックを抽出し `type:` 行を集計。`grep -rl "^type: episode"` と突合）。ULID `id` と `status` は 2026-05 以降の世代のみ保有。

### 採点前から確定した衛生欠陥（すべて [verified]）

- **完全重複**: `projects/second-opinion-verification/docs/episodes/2026-02-10-claude-safe-orchestration-verification.md` と同 `2026-02-10-verification-report.md` は frontmatter 以外、空行 1 行差で同一（`diff` で確認）。正本指定なし
- **空プレースホルダ**: `projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md:267`「## 3. 振り返り（後で追記）」が HTML コメントのまま 1 ヶ月超未記入
- **一括生成**: orchestration-engine の 2026-05-14 付 13 件は単一コミット `585fdeb` で同時追加（`git log --diff-filter=A -- "projects/orchestration-engine/docs/episodes/2026-05-14-*.md"` で確認）
- **write-once 文化**: 52 件中 49 件がコミット 1〜2 回。作成後の追記はほぼ存在しない（最多 5 回が 1 件。`git log --follow --oneline` の全 52 件集計）
- **日付ドリフト**: ファイル名日付と git 初回コミット日の乖離が複数（例: `projects/second-opinion-verification/docs/episodes/2026-02-09-summary.md` は初回コミット 2026-02-14。事後一括コミットの痕跡）
- **§8 配置ギャップ**: `docs/specs/document-format.md:314-321`（§8 内の配置先表）に Decision の「プロジェクト横断」行（`:318`）はあるが、Episode は「プロジェクト固有ディレクトリ（規約は各プロジェクト）」のみ（`:321`）で横断置き場がない
- 境界事例: `projects/poc/wezterm-ai-mode/docs/episodes.md`（単一ファイル・定義外）は除外して記録

## 4. 採点結果

### 4.1 軸別平均（n=52）

| 軸 | 1 WHY | 2 判断 | 3 証拠 | 4 蒸留 | 5 closure |
|---|---|---|---|---|---|
| 平均 | 1.67 | 1.75 | 1.35 | 1.60 | **1.12** |
| 満点率 | 65% | 77% | 42% | 62% | **19%** |

[unverified-summary]（集計元: §4.5 の全数スコア表（52 件 × 5 軸）の単純平均・満点割合。スコア自体の検証規律は §2.3）

### 4.2 世代別平均

| 世代 | n | 軸1 | 軸2 | 軸3 | 軸4 | 軸5 |
|---|---|---|---|---|---|---|
| 2026-02 | 22 | 1.59 | 1.59 | 1.27 | **1.82** | 1.14 |
| 2026-03 | 2 | 1.50 | 1.00 | 1.00 | 1.00 | 1.00 |
| 2026-04 | 4 | 1.25 | 1.75 | 1.50 | 2.00 | 1.00 |
| 2026-05 | 22 | 1.82 | 1.95 | 1.36 | **1.32** | 1.14 |
| 2026-06 | 2 | 2.00 | 2.00 | 2.00 | 2.00 | **1.00** |

[unverified-summary]（集計元: §4.5 の全数スコア表をファイル日付の月で層別し単純平均したもの。スコア自体の検証規律は §2.3 のとおり）

### 4.3 構造ファミリーと軸プロファイル

| family | 例 | 強み | 弱み |
|---|---|---|---|
| 決定記録型（14） | oe 5/14 群 | 軸1=軸2=2.0（選択肢+棄却理由の規律） | 軸4≈1.1・軸5=1.0、status: draft 放置 |
| 実装ログ型（約20） | ctt phase 群、wez | 軸3 強（実測・hash・ログパス） | WHY が kickoff リンクへ逃げる（軸1=1 集中） |
| 検証レポート型（約12） | sov、ruler | 軸4 強（教訓サマリ・K 番号文化） | 軸3 二極化（匿名化で痕跡全滅の例） |
| 統合振り返り型（6） | ctt retro、oe 5/19 | 軸4=2.0 | 軸3 最弱（集計主張に痕跡なし） |
| チェックリスト型（1） | oe step-4-2 | 軸3=2（全項目に根拠コマンド） | 軸1=軸4=軸5=0 |

### 4.4 薄い episode リスト（正規化平均 ≤ 1.0 または 軸5=0）

| ファイル | 計/10 | 主因 |
|---|---|---|
| sov 2026-02-09-timeout-implementation-review | 2 | WHY なし・「Commit: (draft)」放置・Refix Plan 宙吊り |
| oe 2026-05-15-step-4-2 | 3 | frontmatter なし・経緯ゼロ・未達の行き先なし（軸3 は満点） |
| arena 2026-03-04-exploration-mode | 4 | 検証痕跡ゼロ・3 作業の束ね・振り返りなし |
| ctt 2026-02-23-phase5 | 6 | 軸5=0（「進行中」残置） |
| wez 2026-04-22-wez-notify | 7 | 軸5=0（空振り返り 1 ヶ月超放置） |
| 衛生: sov 2026-02-10-verification-report | 8 | 完全重複（正本指定なし） |

### 4.5 全数スコア（軸1/2/3/4/5、計/10）

```text
oe 5/14 ×11 (audit-log, circuit-breaker, exit-code, failure-taxonomy,
  initializer, middleware, minimal-analysis, outputs-kvs, schema-driven,
  slo-baseline, uc-middleware)                        2/2/1/1/1 = 7
oe 5/14 dependency-representation                     2/2/1/2/1 = 8
oe 5/14 so-compare-review                             2/2/2/1/1 = 8
oe 5/15 step-4-2                                      0/1/2/0/0 = 3
oe 5/16 step-4-3                                      1/2/2/2/2 = 9
oe 5/18 step-4-4                                      2/2/2/2/1 = 9
oe 5/18 step-4-5                                      2/2/1/2/1 = 8
oe 5/19 retrospective                                 2/2/1/2/2 = 9
oe 5/26 issue-109                                     1/2/2/2/1 = 8
oe 5/30 issue-112                                     2/2/2/2/2 = 10
oe 6/08 oe-delegate                                   2/2/2/2/1 = 9
oe 6/09 oe-send                                       2/2/2/2/1 = 9
sov 2/09 summary                                      1/1/0/2/2 = 6
sov 2/09 timeout-design                               2/2/0/1/1 = 6
sov 2/09 timeout-impl-review                          0/1/0/1/0 = 2
sov 2/10 claude-safe-orchestration                    2/2/1/2/1 = 8
sov 2/10 verification-report (重複)                   2/2/1/2/1 = 8
sov 2/14 codex-cursor                                 2/1/2/1/1 = 7
sov 2/14 sentry-fix                                   2/2/1/2/1 = 8
sov 2/15 deep-dive                                    2/2/1/2/1 = 8
sov 2/15 session-synthesis                            2/2/1/2/2 = 9
ctt 2/20 phase1                                       1/1/2/2/2 = 8
ctt 2/21 phase2                                       1/2/2/2/1 = 8
ctt 2/21 phase3                                       1/2/2/2/2 = 9
ctt 2/21 phase4                                       1/2/2/2/2 = 9
ctt 2/21 retrospective                                2/2/1/2/1 = 8
ctt 2/23 phase5                                       1/1/2/2/0 = 6
arena 2/22 prototype                                  2/1/2/2/1 = 8
arena 2/23 resume                                     1/1/1/2/1 = 6
arena 2/24 command-defaults                           2/2/2/2/1 = 9
arena 2/24 summary-output                             2/1/2/1/1 = 7
arena 3/04 exploration-mode                           1/1/0/1/1 = 4
arena 3/04 subagent-integration                       2/1/2/1/1 = 7
wez 4/19 entrypoint-discover                          1/1/1/2/1 = 6
wez 4/20 retro-phase1                                 2/2/1/2/2 = 9
wez 4/20 wez-pane                                     1/2/2/2/1 = 8
wez 4/22 wez-notify                                   1/2/2/2/0 = 7
wez 5/13 phase1-e2e                                   2/2/2/1/1 = 8
wez 5/31 pane-activate                                2/2/2/2/2 = 10
ruler 2/21 gemini-cli                                 2/2/1/2/1 = 8
ruler 2/24 breakthrough                               2/2/2/2/1 = 9
avf 2/20 fw-upgrade                                   2/1/0/2/1 = 6
```

軸6: 0 点 = frontmatter なし 5 件 / 2 点 = 現行仕様充足 7 件 / 1 点 = 40 件（旧世代の id/status 不在、または stale draft）[verified]（frontmatter 抽出 + git 日付）

## 5. 劣化の法則（L1〜L8、先行仮説の読込前に確定）

- **L1 未来向き接続の恒常的欠落**: 軸5 は全世代・全プロジェクトで最弱。closure は「書いた時点」では成立せず、**後続作業が拾ったときに遡及的に成立**する。決定的証拠: cursor-thread-tools の phase episode は次 Phase という確定消費者を持つ間は軸5 が高く（phase1/3/4 = 2）、**プロジェクト終端の phase5 だけ軸5=0**（「進行中」残置）— 消費者が消えた瞬間に closure が崩れた [verified]（`projects/cursor-thread-tools/docs/episodes/2026-02-23-phase5-export-enhancements.md:33-34`、スコアは §4.5）
- **L2 テンプレートは過去向き軸の床を上げるが、未来向き軸を作らない**: 5/14 一括生成 13 件は軸1=軸2=2.0 で均質だが軸4=1.08 / 軸5=1.0、status: draft 13/13 放置。「将来の拡張ポイント」は全件行き先なし [verified]（各ファイル frontmatter の `status:` 行 + 一括追加コミット `585fdeb`）
- **L3 時系列は「劣化」ではない**: 軸1/2 は世代とともに改善（1.59 → 2.0）。軸4 蒸留は**2026-02 がピーク**（教訓サマリ/K 番号文化）で、教訓節を持たない決定記録テンプレが大量生成された 2026-05 に最低。軸5 は全世代 ~1.1 で不変。品質は時間でなく「書く時点で選んだ節構成」が決める [unverified-summary]（§4.2）
- **L4 劣化の主経路は「未来の自分への先送り」**: 「後で追記」「Commit: (draft)」「進行中」「継続予定」型のプレースホルダは観測範囲で**一度も後から埋められていない** [verified]（`projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md:267` / `projects/second-opinion-verification/docs/episodes/2026-02-09-timeout-implementation-review.md:9` / `projects/cursor-thread-tools/docs/episodes/2026-02-23-phase5-export-enhancements.md:33-34` / `projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-5-implementation.md:46`）。逆に追記が実際に行われた稀な 2 例（wez-pane のレビューラウンド積層、oe-delegate の追記訂正）では**前方不整合**（見出し「5 ラウンド」vs 本文「9 ラウンド」、本文結論を末尾追記が訂正）が発生 [verified]（`projects/wezterm-ai-mode/docs/episodes/2026-04-20-wez-pane.md:75,77`）
- **L5 証拠の永続性欠陥**: 軸3 の痕跡が gitignore 対象 `tmp/` パスに集中（so-compare 証跡）し、書いた時点では検証可能・読む時点では消失。別リポ作業の匿名化は痕跡を全滅させる（avf 軸3=0）。匿名化と検証可能性を両立する代替アンカー規約が存在しない [unverified-summary]（`tmp/` 参照の実例: `projects/orchestration-engine/docs/episodes/2026-05-14-episode-so-compare-step-4-1-design-review.md:95`（frontmatter `related` でも `:18`）。`tmp/` が追跡外である根拠: `.gitignore:36`。匿名化の実例: `projects/agent-verification-flow/docs/episodes/2026-02-20-fw-upgrade-multi-agent-retrospective.md` 全文に commit hash / PR 番号なし（grep 確認、スコアは §4.5）。「集中」の程度は委譲採点バッチ所見に基づく要約）
- **L6 修正の back-propagation 断絶**: so-compare レビュー episode（5/14）が同日 3 episode の設計欠陥を記録し「episode に 128+N セクションを追加」と修正方針を書いたが、当該 episode に追加されず前方参照もない [verified]（方針: `projects/orchestration-engine/docs/episodes/2026-05-14-episode-so-compare-step-4-1-design-review.md:58-62`。未実施: 同 `2026-05-14-episode-exit-code-mapping.md` 全文に `128` の出現なしを `grep` で確認）。単文書採点では捕捉できないコーパスレベルの整合性欠陥
- **L7 WHY は冒頭 1〜2 文の問題文の有無で決まる**: 軸1=1 の主因は「Issue #N として実装」「kickoff の実装」開き。「Context / なぜ」節を持つ世代（oe 2026-06）と問題文から始まる文書は軸1=2 に張り付く。修正コストが最も低いギャップ [unverified-summary]（「Issue #N として実装」開きの例: `projects/wezterm-ai-mode/docs/episodes/2026-04-20-wez-pane.md:22`、同 `2026-04-22-episode-wez-notify.md:24`。対極の「## Context / なぜ」例: `projects/orchestration-engine/docs/episodes/2026-06-09-episode-oe-send-finalize-ingestion.md:30`。スコア対応は §4.5）
- **L8 品質は書く時点の「節構成」でほぼ決まる**: 軸4 は知見/教訓節の有無が決定要因。family が軸プロファイルを決める（§4.3）。複数作業の束ね文書化は劣化と同時発生 [unverified-summary]（知見節ありの例: `projects/ruler-agent-verification/docs/episodes/2026-02-21-gemini-cli-initial-verification.md:137`「## ナレッジ（確立された知見）」、`projects/orchestration-engine/docs/episodes/2026-05-16-episode-step-4-3-implementation.md:215`「## 教訓 / 学び」。なしの例: `projects/arena-compare/docs/episodes/2026-03-04-exploration-mode-and-command-path.md`（知見/教訓節を持たず軸4=1、束ね文書の実例。スコアは §4.5））

## 6. 先行仮説との突合（事前登録 → 封印解除）

手続き: 自前の仮説 H1〜H5 と法則 L1〜L8 を確定した後、Issue #149/#113/#62 の 2026-06-10 付コメントを初めて読んだ。コメントはキックオフ記載の 3 件でなく **4 件**存在し（#149 に 04:02 の追加分）、4 件すべてを突合対象とした [verified]（`gh issue view {149,113,62} --json comments` の `createdAt` 2026-06-10 フィルタ。追加分 = [#149 04:02 コメント](https://github.com/stlwolf/ai-development-hub/issues/149#issuecomment-4666359177)）。

### 一致（収束）

- **P5（消費者予見仮説）⇔ L1: 独立に同一機序へ収束** — 本監査の最重要結果。「振り返りの有無は次の消費機会の予見と相関する」（先行）と「closure は後続が拾ったとき遡及的に成立する」（ゼロベース）は同じ機序の表裏
- **P3（実測 5/43）⇔ 軸5 分布**: 方向一致（rubric 基準で満点率 19%）。「構造化 closure は少数派」は堅い
- **P4（問いの再設定: 線引きへ）⇔ family プロファイル**: 決定記録型は振り返りなしで過去向き復元に耐えるが、**routing と消費者明示は全型で必要** — が監査の答え
- **P7（#62: 監査結果が注入対象の選別基準になる）**: §8 R5 で具体化

### 不一致・修正（先行仮説に反する観察 = 成果）

- **P1（選択ガードレール不在 → 随時追記が全ログ化 → 時系列羅列）は既存コーパスの主因ではない**。コーパスは write-once 文化で随時追記がほぼ存在せず、薄い episode は生まれた時点から薄い。逐語ログの多い文書はむしろ軸3 が高く品質と逆相関しない。P1 が観測されるのは追記が実際に起きた稀な 2 例のみ → **「これから随時追記運用を始める場合」の前方リスク仮説**として扱うべき
- **「劣化しているか」の問い自体が不正確**（L3）: 時系列劣化ではなく節構成の構造問題
- **先行仮説にない新規発見**: L5（痕跡の揮発）と L6（back-propagation 断絶）
- **P2（書き込み時 vs closure 時の 2 レイヤ）への部分修正**: レイヤ分離には同意。ただし計測された穴は closure 層に集中しており、優先順位は closure 層が先

## 7. 対照群（別リポ「再利用ループあり群」、owner-report）

数値計測ではなくオーナー聞き取りの体感値（owner-report）。全項目 [unverified-summary]（ソース: 2026-06-10 のオーナー聞き取り。一次計測なし）。ドメイン情報は除去済み。

| 論点 | 結果 | 含意 |
|---|---|---|
| 振り返り記入率 | 高い（「基本ほぼ書く」）。ただし機序は消費者予見の自然発生ではなく**「実験的検証の場として明示的・積極的に書く」運用方針** | P5/L1 は自然発生条件の説明として維持しつつ、**明示的ゲート・指示で代替可能**という追加知見。R1（明示ゲートで書かせる skill 化）を直接支持 |
| 消費者予見×振り返りのクロス | 差はない / 識別不能（振り返りは AI 委譲で生成、書き分けなし） | 同上 |
| 随時追記型の比率 | 歴史的には対照群も write-once。最近**意図的に追記型へ移行**を明文化したところ。肥大傾向（P1）は未計測 | R3 の P1 defer を裏付け。追記型移行後の実データで P1 検定が可能になる（再判断トリガー） |
| follow-up routing 率 | 低い〜不明。暗黙の連鎖はあるが明示的行き先付与は常態でない | 「消費ループがあれば routing は自然発生する」は**不支持**。明示的 routing の弱さは両群共通 → **R1-2（routing 必須化）の意義を強める** |
| 痕跡永続性 | 未提供（任意項目） | 対照群未検証のまま |

## 8. 提言

### R1【主提言】#113 = skill 化 GO。重心を「振り返り枠組み」から「消費者明示 + routing」へ

監査データは「KPT vs YWT のどの枠組みか」が主要因でないことを示す（蒸留は枠組みなしの 2026-02 文化で 1.82 出ていた。穴は軸5）。skill 必須項目の優先順:

1. **次の消費者の明示**（誰が / どのタスクで読むか。書けなければ「消費者なし」と明示させ、構造化振り返り省略可の線引きに使う）
2. **follow-up routing**（全 follow-up に行き先: Issue / ADR / 別doc /「追わない」宣言。行き先なしの箇条書き禁止）
3. **status 確定**（closure 時に draft → stable/deprecated、据え置きは理由 1 行。stale draft 28 件の再発防止）
4. 振り返り枠組み: **KPT + YWT ハイブリッド**（wez pane-activate の実測比較が既に支持 [verified]（`projects/wezterm-ai-mode/docs/episodes/2026-05-31-wez-pane-activate.md:143`））
5. **back-propagation チェック**（他文書の欠陥を確定したら反映 or 前方参照。L6 対策）
6. **evidence anchor チェック**（`tmp/` 等の揮発痕跡は要点を本文へ転記。匿名化時は数値・hash 等の代替アンカー。L5 対策）

線引き: 決定記録型・チェックリスト型は 4 を省略可、1〜3 は全型必須。検証経路: 本監査の rubric を測定器に、導入後 episode の軸5 before/after を比較。

### R2【併走・軽量】spec-card / document-format.md 強化

- 性質ガイドに冒頭「Context / なぜ」1〜2 文の定型を追加（L7）
- 任意の構造化 FB セクションに「次の消費者」「follow-up 行き先」項目を追加
- **§8 配置表に「プロジェクト横断の Episode: `docs/episodes/`」行を追加**（本監査で実体を新設済み）
- 性質ガイドに知見/教訓節への言及（L8）

### R3【見送り + defer】rule 化はしない

- 「『後で追記』を残さない」規律は #113 skill のチェック項目とする（独立 rule 化は摩擦過大）
- 随時追記の選択ガードレール（P1）は**何もしない（defer）**。既存コーパスで主因でなく、対照群も未計測。オーナーの B 検証 + 対照群の追記型移行後データで再判断（オーナー受諾済み）

### R4【方向のみ】書き忘れ対策は「同期ゲート」型

L4 より事後リマインダは機能しない。branch-finish / PR フローの既存チェックに「episode closure 済みか」を 1 項目追加する方向（実装は #113 実装後の別 Issue）。

### R5【接続】#62 への選別基準

薄いリスト（§4.4）は注入ソースから除外。検証レポート型の教訓サマリ・K 番号ナレッジは negative knowledge 候補に直結。決定記録型は判断（選択肢+棄却理由）の注入に適する。#62 Phase A の蓄積フォーマットは R1-1「消費者明示」と対で設計する。

### 軸1 順位付けの正当化（HG1 注文への回答）

「自己完結 > リンク経由」の採点は spec-card の related チェーン思想と矛盾しない:

1. チェーンの脆さはコーパス内に実在する（`tmp/` 痕跡依存・「Commit: (draft)」未解決参照・日付ドリフト、すべて [verified]: `projects/orchestration-engine/docs/episodes/2026-05-14-episode-so-compare-step-4-1-design-review.md` の `tmp/so-20260514-162654/` 参照、`projects/second-opinion-verification/docs/episodes/2026-02-09-timeout-implementation-review.md:9`、§3 日付ドリフト項）
2. 1 点は「復元可能」を認めた上での減点であり、0 点（復元不能）と明確に区別している
3. 軸1=2 の文書は related チェーン**も**完備しており、インライン 1〜2 文とチェーンは排他でなく相補。含意は「チェーンの上に最低限の自己完結（orientation + 腐敗保険）を足せ」であり R2 と一体

### 衛生対応リスト（事実列挙。対応要否はオーナー判断）

- sov 2026-02-10 の完全重複ペア（正本指定 or 統合）
- wez-notify の空振り返り（埋める or「書かない」と明示）
- exit-code episode への 128+N 追記 or 前方参照（L6 実例の解消）
- stale draft 28 件の status 見直し
- `projects/poc/wezterm-ai-mode/docs/episodes.md` の位置づけ確認
- 5/14 一括生成 13 件は decision 相当の内容が episodes/ にある状態（Decision 昇格の判断材料）

## 9. 限界

- 採点者間信頼性の照合は親がバッチ結果を見た後に行ったもので、厳密な独立二重採点ではない
- 本リポは「プロジェクト ≒ 時期」が交絡しており、世代別比較（§4.2）はプロジェクト文化と分離できない
- 対照群は数値計測でなく聞き取り（owner-report、ステータスとしては [unverified-summary]）。P5/L1 の機序の定量検定は未了
- rubric の重み付け・合成点は operational heuristic であり、証拠に基づく閾値ではない
- 委譲採点の根拠引用は spot-check 10 件 + 既読 6 件の範囲で照合済み。全 260 セルの逐一照合はしていない（リスク重み付き選択検証）

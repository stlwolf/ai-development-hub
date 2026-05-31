---
id: 01KSYJFT2B17G4AX883W0PJ214
title: "wez pane activate 実装エピソード（#111 フォーカス奪取対処）"
date: 2026-05-31
type: episode
status: stable
related:
  - type: implements
    ref: ../plans/2026-05-31-plan-wez-pane-activate.md
    reason: "本エピソードが実装したプラン"
  - type: depends_on
    ref: ../decisions/ADR-004-pane-design-decisions.md
    reason: "pane サブコマンドの引数規約・exit code 体系を踏襲"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/111"
    reason: "#111 の解決実装"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/113"
    reason: "クロージャ振り返り（KPT + 構造化FB表）が構造化振り返りテンプレの検証ケース"
tags: [wez, cli, pane, activate, focus, bash, episode]
keywords: [wezterm, activate-pane, no-focus, split-pane, WEZTERM_PANE]
use_when:
  - "wez pane activate の設計判断・実装経緯を確認するとき"
  - "split 後のフォーカス制御の根拠を辿るとき"
---

# wez pane activate 実装エピソード（#111）

## 背景・目的

統括 Claude Code セッションのペインから `wez pane split` で捕捉用ペインを作ると、フォーカスが新ペインへ移り、ユーザーの許可プロンプト応答が新ペインへ流れてオーケストレーションが詰まる（[#111](https://github.com/stlwolf/ai-development-hub/issues/111)、#105 Phase 5 / #109 oe-capture dogfood で発見）。`wez pane activate <pane_id>` を追加し、`split → activate <元ペイン>` の合成でフォーカスを復帰できるようにする。

## 実装内容

- `lib/pane.sh`: `_wez_pane_activate`（`wezterm cli activate-pane --pane-id <ID>` の薄いラッパー）を追加。既存 `_wez_pane_kill` を 1:1 で模倣
- dispatcher `wez_cmd_pane` の `case` に `activate)` を配線、`_wez_pane_help` と `bin/wez` トップレベル help に `activate` を追記
- `README.md` に `wez pane activate` セクション + 使用例 + サブコマンド一覧を追記

## 設計判断

### DJ-A: pane-id 必須

`wezterm cli activate-pane` の native default は `WEZTERM_PANE` だが、既存 `send`/`capture`/`kill` がすべて pane-id 必須のため、一貫性を優先して **必須**にした。#111 のユースケース（split 後に元ペイン id を明示指定して戻す）は明示 id 指定なので支障なし。plan peer-ai-review で Codex も「呼び出し元の再現性が高い／本リポジトリに YAGNI 前例」として同意。

### DJ-B: 失敗時 exit code マッピング（実測で確定）

Step 0 で `wezterm cli activate-pane --pane-id 999999`（存在しない）を実測 → `exit 1` + stderr `Error: pane 999999 not found`。これを受け、`send`/`kill` 同型で「失敗時 `_wez_pane_exists` 再確認 → 無ければ `3 (PANE_NOT_FOUND)`、存在し操作失敗なら `5 (OP_FAILED)`」を採用。`wez pane activate 999999` で `exit 3` を確認済み。

### `--no-focus` 不採用と ADR 昇格判断

`wez pane split --no-focus` 案は採らなかった。理由:

- インストール済み `wezterm 20240203-110809-5046fc22` の `wezterm cli split-pane --help` に `--no-focus` native flag が**存在しない**（`--pane-id/--horizontal/--left/--right/--top/--bottom/--top-level/--cells/--percent/--cwd/--move-pane-id` のみ）。実測で確認。
- エミュレートするには split 内部で「split → 元ペインへ activate」を行う必要があり、focus flicker + split の単一責務違反を招く。
- `activate` を独立サブコマンドにすれば既存パターンと同型で、合成により同目的を達成できる（ADR-006「CLI 側で完結」方針とも整合）。

**ADR 昇格判断 → エピソード完結（ADR 化せず）。** CONVENTIONS の ADR 基準には「明示的にやらないと決めた → ADR」があり `--no-focus` 不採用は文言上触れるが、本件は upstream に native flag が無く実質強制された選択で、新規アルゴリズム・構造的トレードオフを持たない（既存 ADR-003/006 のような深さがない）。**「最初から ADR 化せずエピソード優先、非自明なフォークが出た場合のみ昇格」をユーザーと事前合意済み**。実装中に非自明なフォークは発生しなかったため、本エピソードで完結させる。

## peer-ai-review（gate）

- **プランレビュー（Stage 1）**: `tmp/peer-review-20260531-155929/`（so-compare `tmp/so-20260531-160031/`、Codex 84s / Claude 164s）。3者が方向性に同意。両 SO が一致して指摘した「Step 3 コードレビュー gate 条件の『手元 E2E pass』が Step 4(E2E) より前」という順序矛盾をプラン改訂（Step 3=E2E / Step 4=コードレビュー）で解消。
- **実装後コードレビュー（Step 4）**: so-compare `tmp/so-20260531-172444/`（Codex 38s / Claude 136s）。CRITICAL なし・出荷可能で合意。INFORMATIONAL 2件を修正:
  - `bin/wez` トップレベル help に `activate` 漏れ（Codex 指摘・grep 検証済み）→ 追記
  - activate help の "not both" 文言が順序依存の実装（兄弟コマンド共通）と食い違う（Claude 指摘）→ 文言を実態に合わせて緩和

## 検証結果

- `shellcheck lib/pane.sh bin/wez`: CLEAN（exit 0）
- 非 focus E2E（実機・live socket `gui-sock-38784`）: `wez pane --help`/`activate --help` 表示 ✓、非存在 id → `exit 3` ✓、`--socket` 経由（2段パース）→ `exit 3` ✓、pane-id 必須/too many args/invalid id → `exit 64` ✓
- **実機 focus 復帰 E2E（マージ後 2026-05-31 に実施・PASSED）**: 当初は作業セッション中のフォーカス奪取を避けてスキップしたが、ユーザー判断でマージ後に実機検証。live socket `gui-sock-38784` で `is_active` を判定: 初期 active=`0` → `split` で active=`5`（#111 のフォーカス奪取を再現）→ `activate 0` で active=`0`（**フォーカス復帰確認**, exit 0）→ test pane kill。`--json` 成功出力 `{"pane_id":0,"status":"activated"}`、非 json 成功時 stdout 空も確認。VERIFICATION_MATRIX A-2-8 を PASSED に更新。

## 成功基準の突合（プラン）

| 成功基準 | 状態 |
|---------|------|
| `activate <pane-id>` がフォーカスを移す | ✓ 実機確認（`is_active` で判定） |
| `--pane-id <ID>` でも同動作 | ✓（引数パーサ共通） |
| 存在しない id → exit 3 | ✓ 実測 |
| `--json` 出力 | ✓ 実機確認（`{"pane_id":N,"status":"activated"}`）|
| split→activate でフォーカス復帰 | ✓ 実機確認（active 5→0、マージ後 2026-05-31）|
| shellcheck 通過 | ✓ |
| `--help` に activate 表示 | ✓ |
| README 記載 | ✓ |

## クロージャ振り返り（#113 構造化振り返りテンプレの検証）

本サイクル（Stage 1〜3 + plan/実装の二段 peer-ai-review）を、[#113](https://github.com/stlwolf/ai-development-hub/issues/113) 提案の構造化振り返りテンプレ（KPT + 構造化フィードバック表）で締める。これは B-1〜B-3 が Phase 1 でスキップだったプロセス検証の初の実適用でもある（VERIFICATION_MATRIX B-6）。

### 構造化フィードバック表（#113 提案フォーマットの試用）

| # | handoff-gate（受け渡し点） | finding（観測） | 発見者 | 振り返り手法 | target（改善対象） |
|---|---------------------------|----------------|--------|------------|------------------|
| 1 | 方向確認（A activate vs B --no-focus） | 一次情報（`wezterm cli --help` 実測）で B が native 非対応と判明し選択が事実上確定 | 自分 | Keep | 設計分岐前の primary-source 確認 |
| 2 | ADR 粒度のユーザー指摘 | 「2択比較=ADR」を機械適用しかけたが、既存 ADR-003/006 と粒度比較しエピソード完結が妥当と判断 | ユーザー | Problem→Try | ADR 昇格基準の粒度判定 |
| 3 | plan MD レビュー（branch/PR/copilot/retro 後出し） | MD 化後に process step 追加。plan mode 中は MD 直接編集不可で harness plan と二重管理 | ユーザー | Problem | plan mode と project plan MD の二重管理 |
| 4 | プラン peer-ai-review gate | 「Step 3 gate 条件の手元 E2E pass が Step 4(E2E) より前」の順序矛盾を検出 | Codex+Claude | Keep | gate 条件の前後整合 |
| 5 | 実装後コードレビュー gate | `bin/wez` トップレベル help の activate 漏れを発見（自分/Claude は pane.sh help のみ確認し見落とし）。help 文言の過剰約束も指摘 | Codex（漏れ）/ Claude（文言） | Keep→Try | help は2箇所（サブ+トップレベル）をチェックリスト化 |
| 6 | focus E2E の実行判断 | ライブ GUI のフォーカスを奪う E2E をスキップ。成功パスは検証済み kill と同一構造のため PARTIAL で受容 | ユーザー | Try | dogfood 用隔離ウィンドウ/workspace の標準化 |
| 7 | Copilot レビュー依頼 | `gh pr edit --add-reviewer Copilot` は失敗、`gh api .../requested_reviewers` + bot slug で成功 | 自分 | Problem→Try | Copilot レビュー依頼手順の skill 化 |

### KPT

- **Keep**: 設計分岐前の一次情報実測（1）。gate を独立 TODO 化し、両 gate が別々の実欠陥を検出（4 順序矛盾 / 5 help 漏れ）。薄いラッパーを既存 `kill` の 1:1 模倣で実装しレビューも差分比較に集中
- **Problem**: ADR 昇格フロー定義が緩く毎回その場判断（2）。plan mode 中の plan MD 二重管理（3）。Copilot 依頼の CLI 手順が未文書（7）
- **Try**: Copilot 依頼手順を `pr-conventions`/`copilot-review-response` skill に追記。help 二重チェックを pane 系変更の項目に。dogfood は専用 window/workspace で分離（#111 回避策の常設化）。ADR 昇格の粒度ガイドを #113 で具体化
- **Open Questions**: #113 テンプレの timestamp 列は冗長（handoff-gate の通し番号で順序追跡可）。plan mode と project plan MD の二重管理は運用ルール（先に MD 確定→plan mode は参照のみ）で回避すべきか

### #113 への申し送り（テンプレ検証結果）

- **有効**: 「finding → 振り返り手法(KPT) → target」の3列が観測を改善アクションへ機械的に橋渡しできた
- **冗長**: timestamp 列。handoff-gate の通し番号 + 名前で順序は追える
- **追加採用**: 「発見者」列（自分/Codex/Claude/ユーザー）を本試用で足した。SO の価値・カバレッジギャップが定量化でき有用（gate 5 で Codex のみ help 漏れを発見、等）→ #113 の正式テンプレに推奨

### 別フォーマット試用: YWT 版（比較参照用）

#113 のテンプレ選定の材料として、同じ7 findings を KPT 以外の代表フォーマット **YWT（やったこと / わかったこと / つぎやること）** でも framing する。同一データを2フォーマットで並べることで、どちらが何を拾いやすいかを比較できる。

- **Y（やったこと）**:
  - 方向確認で `activate` を選定（一次情報を実測して分岐確定）
  - plan を MD 化し、二段の peer-ai-review（plan gate + 実装後コードレビュー gate）を通した
  - 薄ラッパーを既存 `kill` の 1:1 模倣で実装、shellcheck + 非 focus E2E を実施
  - PR #117 作成 + Copilot レビュー依頼、振り返りを episode クロージャに追記
- **W（わかったこと）**:
  - `wez split-pane` に `--no-focus` native flag は無く（実測）、`activate` 合成が正解だった
  - gate は機械的に実欠陥を拾う: plan gate=Step 順序矛盾、code gate=`bin/wez` help 漏れ（Codex のみ発見）
  - ADR 昇格フローの定義が緩く毎回その場判断になる／plan mode 中は project plan MD を直接編集できず二重管理になる／Copilot レビュー依頼の CLI 手順が未文書
  - focus を奪う E2E は稼働中の作業セッションと相性が悪く、隔離が要る
- **T（つぎやること）**:
  - Copilot 依頼手順を skill 化（`gh api .../requested_reviewers` + bot slug）
  - help 二重チェック（サブ + トップレベル）を pane 系変更の項目に
  - dogfood は専用 window/workspace で分離（#111 回避策を常設化）
  - ADR 昇格の粒度ガイドを #113 で具体化、#113 テンプレに timestamp 列削除 / 発見者列追加を提案

### KPT vs YWT 比較メモ（#113 向け）

| 観点 | KPT | YWT |
|------|-----|-----|
| 強み | Keep/Problem の善し悪し分離が明示的で、**変えるべき対象（target）への接続**が速い | **W（わかったこと＝学び・事実）**を独立した箱で保持でき、知見が散らばらない |
| 弱み | 学び（例: `--no-focus` native 不在、gate が欠陥を拾う価値）が Keep と Problem に分散する | Y/W/T は「良かった/悪かった」の価値判断を持たないため、**続けるべき good practice の強調が弱い** |
| 本データでの差 | gate の有効性が Keep に、フロー不備が Problem に分かれて記録 | 同じ gate の有効性・不備が W に**事実として一括**で入り、次アクションは T に集約 |
| 所見 | アクション志向（何を変えるか） | 知見志向（何を学んだか） |

**#113 への提案**: 両者は排他でなく、**YWT の W（学び）+ KPT の Keep/Problem/Try** のハイブリッドが本データには最も収まりが良かった。KPT 単体だと「学び」の置き場が弱く、YWT 単体だと「続けるべき good practice」の強調が弱い。構造化 FB 表（finding→手法→target）はどちらの締めとも併用可能。

---
id: 01KSX49HAQVZ6KDFN8N4FXSZCW
title: "wez pane activate サブコマンド追加（#111 フォーカス奪取対処）"
date: 2026-05-31
type: plan
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/111"
    reason: "本プランの対象 Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/20"
    reason: "wez CLI track の Epic"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/113"
    reason: "Step H の振り返りが構造化振り返りスキルの検証ケースになる"
  - type: depends_on
    ref: "./2026-04-20-kickoff-wez-pane.md"
    reason: "pane サブコマンド群（list/split/send/capture/kill）の構造を前提とする"
  - type: design_context
    ref: "../decisions/ADR-004-pane-design-decisions.md"
    reason: "pane サブコマンドの引数規約・exit code 体系を踏襲"
  - type: design_context
    ref: "../decisions/ADR-006-lua-integration-policy.md"
    reason: "Lua は Phase 2・dotfiles 管轄 → CLI 側で完結させる方針"
  - type: reference
    ref: "../CONVENTIONS.md"
    reason: "ドキュメント規約・Stage 分離フロー・ADR 昇格基準"
tags: [wez, cli, pane, activate, focus, bash]
keywords: [wezterm, activate-pane, no-focus, split-pane, WEZTERM_PANE, focus]
use_when:
  - "wez pane activate を実装するとき"
  - "split 後のフォーカス制御の設計判断を確認するとき"
---

# wez pane activate サブコマンド追加（#111 フォーカス奪取対処）

作業開始前に必ず以下を読むこと:

- `projects/wezterm-ai-mode/CONVENTIONS.md` — ドキュメント規約・Stage 分離フロー・ADR 昇格基準
- `projects/wezterm-ai-mode/lib/pane.sh` — 既存 pane サブコマンド群（send/capture/kill の引数・exit code パターン）
- `projects/wezterm-ai-mode/lib/common.sh` — exit code 定数
- `projects/wezterm-ai-mode/docs/decisions/ADR-004-pane-design-decisions.md` — pane 設計判断

## 背景

[#111](https://github.com/stlwolf/ai-development-hub/issues/111) は [#105](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 5 の dogfood（#109 oe-capture ライブ検証, 2026-05-26）中に判明。統括 Claude Code セッションのペインから `wez pane split` すると **フォーカスが新ペインへ移り**、ユーザーのキー入力（許可プロンプト応答）が新ペインに流れ、オーケストレーションが詰まる。

## 目的

`wez pane split` 後に **元ペインへフォーカスを戻せる**ようにし、オーケストレータが作業ウィンドウのフォーカスを奪わずに捕捉ペインを運用できるようにする。

## 採用アプローチ（方向確認済み）

`wez pane activate <pane_id>`（`wezterm cli activate-pane` の薄いラッパー）を新サブコマンドとして追加する。oe 側は `split → activate <元ペイン>` の合成でフォーカスを復帰する。

### `--no-focus` 案を採らない理由

- インストール済み `wezterm 20240203-110809-5046fc22` の `wezterm cli split-pane --help` に **`--no-focus` native flag は存在しない**（`--pane-id/--horizontal/--left/--right/--top/--bottom/--top-level/--cells/--percent/--cwd/--move-pane-id` のみ）。
- `--no-focus` を実現するには split 内部で「split → 元ペインへ activate-pane」をエミュレートする必要があり、(a) 一瞬フォーカスが新ペインへ飛ぶ flicker、(b) split が複数責務を持つ（薄いラッパー原則に反する）。
- `activate` を独立サブコマンドにすれば既存 `list/send/capture/kill` と同型で、合成により同じ目的を達成できる。ADR-006 の「CLI 側で完結」方針とも整合。

## 成功基準

- [ ] `wez pane activate <pane-id>` が指定ペインにフォーカスを移す
- [ ] `wez pane activate --pane-id <ID>` でも同じ動作（send/capture/kill と同じ引数パターン）
- [ ] 存在しない pane-id で `exit 3 (PANE_NOT_FOUND)` を返す
- [ ] `--json` で `{"pane_id":N,"status":"activated"}` を出力する
- [ ] `wez pane split → wez pane activate <元id>` で元ペインにフォーカスが戻る（実機 E2E）
- [ ] `shellcheck lib/pane.sh bin/wez` が通る
- [ ] `wez pane --help` / `wez pane activate --help` に activate が表示される
- [ ] README に activate が記載されている

## スコープ

### 対象

- `projects/wezterm-ai-mode/lib/pane.sh` — `_wez_pane_activate` 実装 + dispatcher 配線
- `projects/wezterm-ai-mode/README.md` — activate サブコマンド記載
- `projects/wezterm-ai-mode/docs/episodes/` — 実装記録
- `projects/wezterm-ai-mode/docs/VERIFICATION_MATRIX.md` — 検証項目追加（該当があれば）

### 対象外

- `wez pane split --no-focus`（上記理由で不採用。エピソードに記録）
- Lua / dotfiles 統合（ADR-006 の Phase 2 スコープ）
- oe 側（orchestration-engine）の split→activate 呼び出し実装（別リポジトリ作法・別 Issue）

## 設計判断が必要な事項

### DJ-A: pane-id を必須にするか、省略時 `WEZTERM_PANE` デフォルトにするか

- `wezterm cli activate-pane` の native default は `WEZTERM_PANE`。
- 既存 `send/capture/kill` は **すべて pane-id 必須**。一貫性のため activate も **必須**を採用する。
- #111 のユースケース（split 後に元ペインへ戻す）は明示 id 指定なので必須で支障なし。

### DJ-B: 失敗時の exit code マッピング

- send/kill と同型: 実行失敗時 `_wez_pane_exists` で再確認 → 無ければ `3 (PANE_NOT_FOUND)`、あれば `5 (OP_FAILED)`。
- Step 0 で「存在しない pane-id に対する `wezterm cli activate-pane` の実挙動」を実測して確定する。

## 実行ステップ

### Step A: 開始時ブランチ/worktree 作成（承認後の最初の行動, 約5分）

- [x] `branch-naming` skill 適用 → `feature/#111_pane_activate`
- [x] `worktrunk-worktrees` skill: `wt switch --create feature/#111_pane_activate --base master`
- [x] 検証: `pwd` / `wt list` で新 worktree を確認
- [x] master 上の draft プラン MD を worktree へ移送し、本 process ステップ（Step A/F/G/H）をプラン MD に反映

### Step 0: 前提調査・確認（gate, 約10分）

- [ ] `wezterm cli activate-pane --help` の確認（済: `--pane-id`, 省略時 `WEZTERM_PANE`）
- [ ] worktree 内で、存在しない pane-id に対する `wezterm cli activate-pane` の exit code / stderr を実測 → DJ-B 確定
- [ ] gate: 前提（native activate-pane が期待通り動く）が崩れたらプランを修正してから先へ進む

### Step 1: `_wez_pane_activate` 実装（`lib/pane.sh`, 約30分）

- [ ] send/capture/kill と同じ引数パーサ（positional `<pane-id>` または `--pane-id <ID>`、`--json`、`--help`）
- [ ] numeric pane-id バリデーション（必須）
- [ ] positional と `--pane-id` の同時指定は `kill` 同様 `too many arguments`（usage error）。`--help` に「positional か `--pane-id` のどちらか」を明示（SO 指摘）
- [ ] 実行: `wezterm cli activate-pane --pane-id <ID>`
- [ ] 失敗時の exit code マッピング（DJ-B）
- [ ] 成功時の非 `--json` 標準出力フォーマットを定義（`send`/`kill` 同様、成功時は stdout 無出力に統一）（SO 指摘）
- [ ] `--json` 出力: `{"pane_id":N,"status":"activated"}`（jq 有無の両分岐、既存実装に合わせる）

### Step 2: dispatcher 配線（`lib/pane.sh`, 約10分）

- [ ] `_wez_pane_help` の Subcommands に `activate` を追記
- [ ] `wez_cmd_pane` の `case "$subcmd"` に `activate)` を追加

### Step 3: E2E 検証（約20分）

- [ ] `shellcheck lib/pane.sh bin/wez`
- [ ] 実機: `wez pane split` → 新 id 取得 → `wez pane activate <元id>` でフォーカスが戻ることを目視確認
- [ ] 存在しない id で `exit 3`
- [ ] `split` → 直後に対象 pane が消滅したケースで `activate` が `exit 3` になること（SO 指摘: race/連続実行）
- [ ] 成功時の非 `--json` 標準出力 / `--json` 出力確認
- [ ] `--socket <path>` 経由（dispatcher 2段パース）で activate が動くこと（SO 指摘）
- [ ] `wez pane activate --help` / `wez pane --help` 表示確認

### Step 4: 実装後コードレビュー gate（CONVENTIONS 必須, 約20分）

- [ ] 条件: 全実装 Step 完了 + `shellcheck lib/pane.sh bin/wez` pass + 手元 E2E（Step 3）pass
- [ ] `so-compare` で shell 規約（`set -euo`, クォート, 引数処理）・exit code 整合・既存パターンとの乖離をレビュー
- [ ] 既にプラン peer-ai-review で合意済みの論点はスキップ可（エピソードに理由記載）

### Step 5: ドキュメント + ADR 昇格判断（約30分）

- [ ] `README.md` に activate サブコマンド追記
- [ ] `docs/episodes/2026-05-31-wez-pane-activate.md` 作成。以下を本文に記録:
  - `--no-focus` 不採用理由（wezterm 20240203 に native flag 不在）
  - DJ-A（pane-id 必須化）/ DJ-B（exit code マッピング）の判断
- [ ] **ADR 昇格判断チェックポイント**: 上記の中に「既存規約踏襲を超える非自明なトレードオフ」が出ていれば `decisions/ADR-008-*.md` へ昇格。無ければエピソードで完結（CONVENTIONS の ADR 昇格基準と粒度に照らす。本変更は薄いラッパーで深さが浅いため、デフォルトはエピソード完結の想定）
  - 補足（SO 指摘 / ユーザー合意済み）: CONVENTIONS の「明示的にやらないと決めた → ADR」基準に対し、`--no-focus` 不採用は **粒度が浅く（upstream に native flag が無く実質強制）エピソード記録で十分**とユーザーと事前合意済み。この事前合意自体をエピソードに明記して衝突を解消する
- [ ] `VERIFICATION_MATRIX.md` に該当検証項目があれば更新

### Step F: コミット（約5分）

- [ ] `conventional-commits` skill: `feat(wez): add pane activate subcommand`（body に stage / intent）

### Step G: PR 作成 + Copilot レビュー依頼（約10分）

- [ ] `pr-conventions` skill: `.github/PULL_REQUEST_TEMPLATE.md` 確認 → 本文に `Refs #111`（`Closes` 不使用）
- [ ] `gh pr create --assignee @me --title "feat(wez): add pane activate subcommand" --body-file /tmp/pr_body.md`
- [ ] Copilot レビュー依頼: `gh pr edit <num> --add-reviewer Copilot`（`@copilot` 特殊値はレビュアー非対応のため login 形式。拒否時は `gh api repos/stlwolf/ai-development-hub/pulls/<num>/requested_reviewers` か UI にフォールバック。受理形式は実行時確認）
- [ ] Copilot コメント到着後は `copilot-review-response` skill で未返信スレッドのみ対応

### Step H: 最終ステップ — 振り返り（#113 の検証ケース, 約30分）

- [ ] `docs/episodes/2026-05-31-retro-*.md` を作成。既存 `2026-04-20-retro-phase1-1-2.md` の体裁（目的 → 事実表 → 分析 → 適用）に、[#113](https://github.com/stlwolf/ai-development-hub/issues/113) 提案の **KPT（Keep / Problem / Try / Open Questions）** + 構造化フィードバック表（timestamp / handoff-gate / finding / 振り返り手法 / target）を適用
- [ ] 本振り返りを #113 の構造化振り返りテンプレの **検証ケース**として位置づけ、`VERIFICATION_MATRIX.md` の B（プロセス検証）に1件追加。episode 本文から #113 へリンク
- [ ] `branch-finish` skill の4択（merge / PR / 保留 / 破棄）で締め

## peer-ai-review gates（独立 TODO）

- [x] プラン peer-ai-review（Stage 1）: 本プランの3者合意（`tmp/peer-review-20260531-155929/`、so-compare `tmp/so-20260531-160031/`）。Codex/Claude が方向性に同意。要修正だった Step 3↔4 順序矛盾は本改訂で解消
- [ ] 実装後コードレビュー（Step 4）: 実装に対する `so-compare` レビュー

## Stage フロー（CONVENTIONS 準拠）

- Stage 1（Agent mode, 本プラン承認後）: Step A worktree 作成 → 本プランへ peer-ai-review 反映 → CP 確定
- Stage 2（実装）: Step 0〜4 実装、gate を TODO として実行
- Stage 3（Agent mode）: Step 5 成果物記録 → Step F/G コミット・PR・Copilot レビュー依頼 → Step H 振り返り + 成功基準突合

## Open questions / リスク

- DJ-B（存在しない pane-id の挙動）は Step 0 の実測で確定。実測前は send/kill 同型を仮置き。
- ADR 昇格は実装中に非自明なフォークが出た場合のみ。最初から ADR 前提にはしない（粒度オーバー回避）。

## 関連リンク

- [Issue #111](https://github.com/stlwolf/ai-development-hub/issues/111)
- [Issue #113](https://github.com/stlwolf/ai-development-hub/issues/113)（構造化振り返りスキル提案 = Step H の検証対象）
- [Epic #20](https://github.com/stlwolf/ai-development-hub/issues/20)
- [ADR-004](../decisions/ADR-004-pane-design-decisions.md)
- [CONVENTIONS.md](../../CONVENTIONS.md)

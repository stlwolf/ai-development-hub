---
id: "01KRKXXS2F5FZBBR260PHPQ8NJ"
title: "orchestration-engine Step 4-3 検証ゲート v1 KickOff"
date: 2026-05-15
type: kickoff
status: confirmed
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-3（観測層・親 Epic）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/89"
    reason: "Step 4-3 観測層 Issue（本 KickOff の主スコープ）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-15-discussion-step-4-3-verification-gate.md"
    reason: "Step 4-3 Discussion（QDD 全 7 Q closed、本 KickOff の確定根拠）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-14-kickoff-step-4-2-parse-and-state-management.md"
    reason: "Step 4-2 KickOff（7 DI、パース + 状態管理。本 Step の前提）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/88"
    reason: "Step 4-2 成果物 PR（bin/oe, lib/*.sh, tests/*, レビュー反映）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-15-episode-step-4-2-phase-e-integration-validation.md"
    reason: "Step 4-2 Phase E 統合検証（完了条件 8 項目の検証結果）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion（15 論点・3 UC・arena 反映済み、全体スコープの正本）"
  - type: design_context
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Plan Review / Compliance Review プロンプト規約。本 Step は Compliance Review モードに統合"
  - type: design_context
    ref: "projects/orchestration-engine/README.md"
    reason: "プロジェクト概要・観測層/駆動層分離・Step 一覧"
tags: [orchestration, mvp, step-4-3, kickoff, verification-gate, adversarial-review, cross-tool-handoff]
---

# Step 4-3: 検証ゲート v1 — KickOff

> 本 KickOff は Step 4-2 完了（[PR #88](https://github.com/stlwolf/ai-development-hub/pull/88) マージ済み）を前提に、Step 4-3「検証ゲート v1」のスコープ・引き継ぎコンテキスト・着手前タスクを定義する。
>
> **ツール間引き継ぎの経緯**: Step 4-0〜4-2 は Cursor Agent で実施。Step 4-3 以降は Claude Code への作業移行を試行する。この KickOff 自体が orchestration-engine の dogfood（ツール間の構造化コンテキスト引き継ぎ）として機能する。移行の動機はコスト最適化と、Claude Code 主体でも駆動層ドキュメントだけで作業継続できるかの検証。

## 背景

- [Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 MVP の Step 4-3
- Step 4-2 で `bin/oe` + `lib/*.sh` 7 ファイル + テストスイート 7 本が実装済み。マーカー検出、6 値分類、ポーリングループ、CB、KVS、監査ログ、クリーンアップが動作する状態
- Step 4-3 の主題: **adversarial review 相当の検証ゲート** — サブエージェントの出力を別エージェントが検証する仕組みの設計・実装

## ツール間引き継ぎコンテキスト

Step 4-0〜4-2 を実施した Cursor Agent セッションから、駆動層ドキュメントには蒸留されていない暗黙知を以下に列挙する。本 KickOff を読むエージェントは、このセクションで「ドキュメントに書いてないが知っておくべきこと」を把握できる。

### 読むべきドキュメント（優先順）

1. `README.md` — 目的、3 層モデル、観測層/駆動層の分離、Step 一覧
2. Step 4-0 Discussion: `docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md` — MVP スコープ、15 論点、arena 反映
3. Step 4-1 KickOff + Plan: `docs/plans/2026-05-13-kickoff-step-4-1-*.md` / `docs/plans/2026-05-13-plan-step-4-1-*.md` — スキーマ・ディスパッチャ設計確定
4. Step 4-2 KickOff + Plan: `docs/plans/2026-05-14-kickoff-step-4-2-*.md` / `docs/plans/2026-05-14-plan-step-4-2-*.md` — パース・監視ループ実装計画
5. Step 4-2 統合検証 Episode: `docs/episodes/2026-05-15-episode-step-4-2-phase-e-integration-validation.md` — 完了条件 8 項目の結果
6. ADR 3 件: `docs/decisions/` — クリーンアップ戦略、権限分離、#20 Phase 合流点

### 現在の実装状態

```
projects/orchestration-engine/
├── bin/oe                    # エントリポイント（usage: bash bin/oe "タスク記述"）
├── lib/
│   ├── constants.sh          # OE_POLL_INTERVAL, OE_CB_*, OE_DATA_DIR 等
│   ├── envelope.sh           # oe_envelope_create — JSON エンベロープ生成
│   ├── spawn.sh              # oe_spawn_prepare_pane / oe_spawn_send — wez pane split + send
│   ├── capture.sh            # oe_capture_scan / oe_capture_classify / oe_capture_write_kvs
│   ├── monitor.sh            # oe_monitor_loop — ポーリング + CB + 状態追跡
│   ├── audit.sh              # oe_audit_emit — JSONL 監査ログ追記
│   └── cleanup.sh            # oe_cleanup — trap EXIT 用ペイン kill + tmp 削除
├── tests/                    # 7 テストスイート（計 145 assertions）
├── schemas/                  # JSON Schema 5 件（4-1 確定、実装の契約）
├── scripts/validate-envelope.sh
├── audit/.gitkeep
└── state/.gitkeep
```

#### テスト実行方法

```bash
cd projects/orchestration-engine
shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh
for f in ./tests/test_*.sh; do echo "---- $f ----"; bash "$f" || exit 1; done
```

#### 動作フロー

1. `bin/oe "task description"` でセッション開始
2. `lib/envelope.sh` で `/tmp/oe-{session_id}-envelope.json` を生成
3. `lib/spawn.sh` で `wez pane split` → `wez pane send` でサブエージェントペインにコマンド送信
4. `lib/monitor.sh` が 2 秒間隔で `wez pane capture` → `@@OE_EXIT:{code}` マーカー検出
5. マーカー検出時: `lib/capture.sh` で 6 値分類 → `lib/audit.sh` で監査ログ → KVS 書き込み
6. 全ペイン完了 or CB 発動 → `lib/cleanup.sh` でペイン kill + tmp 削除

### 暗黙知（ドキュメント外）

#### Bash 3.2 互換

macOS デフォルトの Bash 3.2 で動作する前提。`declare -A`（連想配列）は使えない。Step 4-2 末に `monitor.sh` の連想配列を平行配列 + ヘルパー関数に書き換えた（Codex レビュー対応）。新規コードでも連想配列は避けること。

#### wez pane split の `--wait-ready`

`spawn.sh` の `wez pane split` に `--wait-ready --timeout "$OE_SPAWN_WAIT_READY_SEC"` を付与。split 直後のペインが不安定な期間を吸収するためで、`OE_SPAWN_WAIT_READY_SEC` のデフォルトは 10 秒（`constants.sh`）。

#### `human_input` audit イベント

audit log スキーマ上 7 種のイベントタイプが定義。6 種（`session_start`, `state_change`, `interrupt`, `circuit_breaker_triggered`, `cleanup`, `session_end`）は実装済み。**`human_input` のみ未実装**。Step 4-3 で拾うか、必要時に追加するかは判断の余地あり。

#### テストは全て wez モック経由

テストスイートは実際の WezTerm ペインを使わず `wez` コマンドをモックで差し替えている。E2E テスト（`test_e2e_smoke.sh`）のモックは `--bottom`, `--percent`, `--wait-ready`, `--timeout` 等のオプションを `shift` ループで消費する構造。新オプション追加時はモックも更新すること。

#### マーカー表記の変遷

初期 Episode（DI-8）では `===STATE:...===` と仮置きされていたが、**現行の正式仕様は `@@OE_EXIT:{code}`**。`capture.sh` と `test_capture.sh` がこの形式で動作する。

#### レビュープロセスの経緯

Step 4-2 では so-compare（Codex + Claude）、Codex CLI レビュー、GitHub Copilot レビューを経ている。各レビューの対応内容は [PR #88](https://github.com/stlwolf/ai-development-hub/pull/88) の本文に記載。

#### schemas/ の位置づけ

`schemas/` の 5 ファイルは Step 4-1 で設計確定し、**実装の契約**として機能する。スキーマ変更は 4-5 フィードバック Step で行う想定。

#### `status: draft` の形骸化

多くの Episode・Plan の frontmatter が `status: draft` のまま。実態としては実装完了・PR マージ後で確定済み。メタデータ上の不整合として認識しておくこと。

#### Phase E Episode の frontmatter 不備

`2026-05-15-episode-step-4-2-phase-e-integration-validation.md` は YAML frontmatter がない（`spec-card` 非準拠）。他エピソードはすべて frontmatter 付き。

#### `tmp/` 参照の再現不可

Discussion や Episode で `tmp/arena-...` や `tmp/so-...` が参照されているが `.gitignore` 配下。リポジトリ単体では確認できない。根拠文脈は文書内引用で伝わるため実害なし。

### 関連プロジェクトとの関係

- **wez CLI**（`projects/wezterm-ai-mode/`）: Phase 1 完了。`wez pane split/send/capture/kill` を orchestration-engine が使用。Phase 3（`wez agent`）は Step 4-1 確定内容が入力になる予定（ADR DI-10）
- **orchestration-research/**（frozen）: 研究フェーズ成果。参照のみ、直接編集しない

## 着手前タスク（チェックリスト）

Step 4-3 の Discussion・設計に入る前に、前 Step の陳腐化を解消する。

- [ ] `README.md` の状態テーブルを更新（Step 4-0〜4-2 を「完了」に、見出しも修正）
- [ ] `README.md` の構成セクションに `bin/`, `lib/`, `schemas/`, `tests/`, `scripts/`, `audit/`, `state/` を追記
- [ ] Issue [#81](https://github.com/stlwolf/ai-development-hub/issues/81)（Step 4-0）をクローズ
- [ ] Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) のチェックボックスを Step 4-0〜4-2 にチェック
- [ ] `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh` がクリーンであることを確認
- [ ] `for f in ./tests/test_*.sh; do bash "$f" || exit 1; done` が全 PASS であることを確認

## スコープ（確定 — [Discussion](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md) 全 7 Q closed）

### Step 4-3 の主題

**検証ゲート v1**: サブエージェントの出力を別エージェントが Compliance Review する仕組み。`adversarial-review` skill の Compliance Review モードを engine の駆動と統合する。

### 確定 DI（7 項目 — Discussion Q1〜Q7 から変換）

- **DI-1: 検証モードのスコープ** = Compliance Review のみ（Plan Review は engine 統合せず、必要時は人間が skill 単独起動）
- **DI-2: 発火タイミング** = end-of-session（全 `OE_DONE_PANES` 完了時に検証フェーズへ遷移）+ **セッション内 fail 率を実運用データとして記録**
- **DI-3: 検証エージェント起動** = 新ペイン spawn（`lib/spawn.sh` を再利用、検証用 envelope を生成）
- **DI-4: 検証プロンプト入力** = envelope（要件）+ audit JSONL の最終 `state_change`（完了報告）+ KVS の `outputs[]`（変更ファイル）の 3 ソース統合。skill の Compliance Review プロンプト本文を使い、3 入力部分のみ engine が動的展開
- **DI-5: 検証結果の表現** = `schemas/session-state.schema.json` に `verification`（per-pane）と `verification_summary`（セッション集計、fail 率含む）を追加。語彙 = `pass` / `fail` / `warn`。audit ログに `verification_started` / `verification_completed` の 2 イベント追加
- **DI-6: 不合格時のフロー** = 記録のみ（v1）+ `wez notify` で完了通知（自動リトライ・人間エスカレーションは Step 4-4 以降の派生課題）
- **DI-7: skill 統合方針** = envelope の `task.use_skills: [adversarial-review]` で指定（疎結合）。engine は envelope の `task.exit_conditions.marker` 拡張で `@@OE_VERIFY:{pass|fail|warn}` を要求し、`capture.sh` の正規表現を拡張してパース

### スコープ外

- `human_input` audit イベントの実装（必要時に追加、本 Step 必須ではない）
- ~~スキーマの変更（4-5 フィードバック Step で実施）~~ → **DI-5 により `session-state.schema.json` と `audit-log.schema.json` の最小拡張は本 Step に含める**（Discussion Q5 で user 確認済み）
- wez CLI Phase 3 の設計（#20 側で実施、ADR DI-10 参照）
- adversarial-review skill 側の改修（派生課題、本 Step 結果を踏まえて Step 4-4 以降で判断）
- per-pane 発火への昇格（DI-2 案 A）、自動リトライ / 人間エスカレーション（DI-6 案 B/C）

## 完了条件（確定 — Discussion §「完了条件」から転記）

- [ ] 検証ゲートが Compliance Review モードで動作する（end-of-session 発火、新ペイン spawn、envelope の `use_skills: [adversarial-review]` で skill 指定）
- [ ] 検証 agent が出力末尾に `@@OE_VERIFY:{pass|fail|warn}` マーカーを出し、engine がこれをパースする
- [ ] 検証結果が KVS の `verification` フィールドに、セッション集計が `verification_summary` フィールドに記録される（fail 率含む）
- [ ] audit ログに `verification_started` / `verification_completed` の 2 イベントが追加される
- [ ] 不合格時も engine は停止せず、`wez notify` で完了通知のみ出す
- [ ] shellcheck で全スクリプトが pass
- [ ] テストスイート: 検証プロンプト構築 / 結果パース / KVS 拡張のユニットテスト + E2E スモーク（wez モック）が PASS
- [ ] `schemas/session-state.schema.json` / `schemas/audit-log.schema.json` の拡張が `scripts/validate-envelope.sh` 系の検証と整合（必要なら新規 validator を追加）

## 進め方

1. ✅ **着手前タスク**を完了する（README 更新は PR で実施、Issue #81 既クローズ、shellcheck/tests PASS 確認、Epic #19 checkbox は user 対応）
2. ✅ Step 4-3 の **Discussion** を `docs/discussions/` に作成（[2026-05-15-discussion-step-4-3-verification-gate.md](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md)、QDD 全 7 Q closed）
3. ✅ ユーザーに Discussion の内容を確認してもらう（1 問ずつの対話で合意）
4. ✅ 合意後、本 KickOff の「仮置き」セクションを確定版に更新（本コミット）
5. → `kickoff-to-plan` スキルで Plan に変換
6. → Plan に従い実装・テスト
7. → Episode で検証結果を記録

## リポジトリ規約（CLAUDE.md / AGENTS.md より）

- Bash 3.2+ 互換、`set -euo pipefail`
- `shellcheck` を必ず通す
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`
- 箇条書きは `-` のみ（`*` `•` 禁止）
- ファイルパスはインラインコードで囲む
- 1 コミット 1 論理変更
- 蒸留パイプライン: Discussion → KickOff → Plan → Episode → Decision/ADR

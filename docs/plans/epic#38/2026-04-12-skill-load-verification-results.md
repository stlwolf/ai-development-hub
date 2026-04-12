---
title: "Issue #64: スキル/コマンド ロード検証 — 動的検証結果"
date: 2026-04-12
status: completed
tags: [canonical, skills, commands, cross-agent, phase1, verification]
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/64
  - https://github.com/stlwolf/ai-development-hub/issues/38
static_analysis: 2026-04-12-skill-load-static-analysis.md
test_cases: 2026-04-12-skill-load-test-cases.md
runbook: 2026-04-12-skill-load-test-runbook.md
---

# Issue #64: スキル/コマンド ロード検証 — 動的検証結果

## 検証条件

- 検証環境: `/tmp/ai-hub-test/`（`ai-development-hub` のローカル clone）
- sync 済み（全ツール 19 スキル + 7 コマンド配置確認済み）
- 各ツール 1 セッション内で 13 プロンプトを連続実行（グループ間のリセットなし）
- Cursor のみ 1 回実行。Claude Code は Group A を 2 回実行（1 回目全滅のため）。Codex は 4 セッション（Group ごと）
- 判定基準: SKILL.md ファイルの実際の読み込み有無（二値判定）
- テストケース定義: [2026-04-12-skill-load-test-cases.md](./2026-04-12-skill-load-test-cases.md)

### ツール・モデル情報

| ツール | モデル | バージョン情報 |
|--------|--------|--------------|
| Cursor | Opus 4.6 | Agent mode |
| Claude Code | Opus 4.6 (medium thinking) | CLI |
| Codex | ChatGPT 5.2 Medium | CLI v0.120.0, Default mode |

## 1. 暗黙起動ロード率マトリクス

| # | スキル | 静的 Grade | Cursor | Claude Code | Codex | 3ツール一致 |
|---|--------|-----------|--------|-------------|-------|------------|
| A1 | branch-naming | A | LOAD | LOAD* | LOAD | ✅ |
| A2 | conventional-commits | A | LOAD | NO_LOAD | LOAD | ❌ |
| A3 | pr-conventions | A | LOAD | NO_LOAD | LOAD | ❌ |
| A4 | branch-finish | A | LOAD | LOAD* | LOAD | ✅ |
| B1 | issue-conventions | A | LOAD | NO_LOAD | LOAD | ❌ |
| B2 | markdown-conventions | B | LOAD | NO_LOAD | LOAD | ❌ |
| B3 | spec-card | A | LOAD | NO_LOAD | LOAD | ❌ |
| C1 | kickoff-to-plan | B | LOAD | LOAD | LOAD | ✅ |
| C2 | question-driven-design | C | NO_LOAD | NO_LOAD | LOAD | ❌ |
| C3 | adversarial-review | B | LOAD | NO_LOAD | NO_LOAD | ❌ |
| D1 | worktrunk-worktrees | A | LOAD | NO_LOAD | LOAD | ❌ |
| D2 | implementer-contract | C | LOAD | NO_LOAD | LOAD | ❌ |
| D3 | persistent-exploration | B | LOAD | NO_LOAD | LOAD | ❌ |
| | **合計** | | **12/13 (92%)** | **3/13 (23%)** | **12/13 (92%)** | **3/13** |

\* Claude Code Group A は 2 回目の結果。1 回目は全滅（0/4）。メモリ機能による汚染の可能性あり。

### 明示起動（発見性）

| 対象 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| 19 スキル | `/` メニューに全件表示 ✅ | system-reminder に全件登録 ✅ | `/skills` で全件表示 ✅ |
| 7 コマンド | `/` メニューに全件表示 ✅ | スキルとして全件登録 ✅ | registry 経由で 5/7 件 ⚠️ |

明示起動（ユーザーが名前を指定）では 3 ツールとも問題なし。Codex の `commands-registry` 欠落 2 件（`pr-review-checklist`, `research-intake`）は静的分析で既出。

## 2. 原因分析

### 2.1 Claude Code の低ロード率（23%）の構造的要因

Claude Code のスキルロードは「Skill ツール呼び出し」という明示的なアクションを要する。3 つの層で阻害要因が存在する:

| 層 | 内容 | 根拠 |
|----|------|------|
| **認識** | description からスキルの関連性を認知 | Session B で「候補として認識したが使わなかった」と自己報告 |
| **判断** | Skill ツール呼び出しのコスト判断 | 「スキルを読まなくても自分の判断で十分対応できる」過信（自己診断） |
| **実行** | 実際に Skill ツールを呼び出す | ツール呼び出し回数の最小化バイアス |

Claude Code の自己診断（Opus 4.6, medium thinking）で挙げられた要因:

1. **ルール記述側**: 発動条件のマッピングテーブルがない。「従う」は推奨に読め、否定形の制約（「スキルをロードせずに実行した場合はエラー」）がない
2. **モデル側**: コスト最小化バイアス。スキルロード→読解→適用の 3 ステップ増を「結果が同じならスキップしてよい」と判断
3. **構造側**: スキルを飛ばしても作業は完了し、フィードバックループが不在。hook による機械的強制がない

### 2.2 Cursor と Codex の高ロード率（92%）の理由

- **Cursor**: Agent Skills がコンテキストに常時提示される。description マッチングで自動的に候補として提案され、ロードのコストが低い
- **Codex**: Progressive disclosure でメタデータを先に読み、関連性判断後にフルロード。`AGENTS.md` の skill-first-operations-rule への遵守度が高い。実際のファイル読み込みは `sed` コマンドで canonical/ ソースから直接実行

### 2.3 テスト条件の限界

| 要因 | 影響 |
|------|------|
| **cold-start バイアス** | 単発プロンプト・新規セッションでの計測。実ワークフローでは会話の流れが補強するため、特に Claude Code の実運用ロード率はこの下限値より高い |
| **セッション内汚染** | 1 セッション内で複数プロンプトを連続実行。先行ロードが後続の判断に影響する可能性 |
| **Claude Code メモリ汚染** | Group A 2 回目は 1 回目の失敗が記録されており、純粋な暗黙起動とは言えない |
| **サンプル数** | 各プロンプト 1 回のみ（コスト制約）。統計的信頼区間は出せない |
| **テスト環境のリモート制約** | ローカル clone のため `gh` コマンドが直接使えず、各ツールがリモート迂回処理を行った |

### 2.4 個別スキルの注目所見

**question-driven-design（Codex のみ LOAD）**

- 静的分析 Grade C（description にツール固有語 "Plan mode" を含む）
- Cursor: ロードされず。「設計を一緒に考えて」が description のトリガーワード（「質問で網羅的に掘り下げ」「暗黙の前提を明示化」）と語彙的に乖離
- Codex: ロードされた。AGENTS.md 経由の skill-first ルールが強く作用した可能性

**adversarial-review（Codex のみ NO_LOAD）**

- 静的分析 Grade B
- Codex: 「参照先として確認しただけで、実行フローとしては使っていない」と自己報告。レビュー依頼を直接実行し、スキルを経由する判断に至らず

### 2.5 Codex のルール構造と高ロード率の関係

Codex セッション末の自己報告で、3 層のルール構造が確認された:

1. **グローバルガードレール**（`~/.codex/AGENTS.md` 経由）: Evidence First, Minimal Scope, Skill First 等の行動規範を会話冒頭に読み込み
2. **プロジェクト AGENTS.md**: canonical/ の参照、Bash/Markdown 規約、shellcheck 等
3. **Codex 開発者指示**: 「まずコードベース確認、思い込み禁止」「実装可能なら分析で止まらず最後まで進める」

Codex の高ロード率（92%）は、(1) のグローバルガードレールに skill-first-operations-rule が含まれ、(3) の開発者指示が「まず確認してから進める」方向に強く誘導している構造に起因する。Claude Code との差は、skill-first が「ツール呼び出しコストを払ってでも従うべきルール」として解釈されるか（Codex: はい）、「コスト最小化で省略可能な手段」と解釈されるか（Claude Code: はい）の違い。

追加の知見として、Codex は peer-ai-review コマンド（`canonical/commands/verification/peer-ai-review.md`）もセッション中に自発的に読み込んでいた。テスト対象外のリソースまで積極的に参照する傾向がある

## 3. 即時修正候補

### 3.1 description 改善（Phase 1 スコープ）

| スキル | 現状の問題 | 改善方向 |
|--------|-----------|---------|
| question-driven-design | "Plan mode の手前に質問フェーズを挿入する" がツール固有 | "実装前に設計判断を質問で掘り下げ、暗黙の前提を明示化する" に置換 |
| kickoff-to-plan | "Cursor Plan Mode 変換時" がツール固有 | "実行可能なプランに変換するとき" に置換 |
| plan-to-kickoff | "Cursor Plan / プランMD" がツール固有 | "プランをKickoff Document形式に変換する" に置換 |
| playwright-browser | "built-inブラウザではなくPlaywright MCPツール（user-playwright-mcp）" がツール固有 | "Playwright MCPでブラウザ操作・DOM調査・UI検証を行う" に簡素化 |
| implementer-contract | "TaskCreate・Agentツール" がツール固有 | "サブエージェントに実装を委譲するときの返却契約" に置換 |

### 3.2 Codex commands-registry 補完

- `pr-review-checklist` と `research-intake` を `registry.md` に追加
- 静的分析で既出。Codex テスト中のサブエージェントが実装済み（テスト用 clone 上）

### 3.3 Codex AGENTS.md ファイル数修正

- `canonical/codex/AGENTS.md` L6: 「8ファイル」→「11ファイル」

## 4. Phase 2 / Agent Adapter への申し送り

### 4.1 Minimal Scope の解釈曖昧性（最重要 — ルール設計の根本課題）

Claude Code の低ロード率の根本原因は、Minimal Scope ルールの WHAT/HOW 混同にある。

現状の記述「依頼範囲のみ対応。『ついで』の変更はしない」は**対象スコープ（WHAT）**の制約だが、モデルが**手段（HOW）**にまで適用し、スキルロードを「余計な手間」と判断している。

**あるべき原則の分離:**

| 軸 | 原則 | 方向 |
|----|------|------|
| **WHAT**（対象スコープ） | Minimal Scope | **絞る** — 依頼範囲のみ変更する |
| **HOW**（手段・根拠） | Evidence First + Skill First | **広げる** — 利用可能な手段・一次情報・スキルを網羅的に使う |

例: 「コミットして」→ WHAT は 1 コミット作成のみ（Minimal Scope）。HOW としては conventional-commits スキルを読む、既存ログを確認する、diff を精査する — 手段は惜しまない。

**検討すべき対策:**

- **behavioral-rule の明確化**: Minimal Scope の補足として「対象スコープの制約であり、手段の選択（スキル参照・一次情報調査）を省略する根拠にはならない」を明記
- **skill-first-operations-rule の強化**: 「操作→スキル」マッピングテーブルの追加。否定形制約（「対応スキルが存在する操作をスキルロードなしで実行した場合、完了前にスキルを参照すること」）の導入
- **hook による機械的強制**: コミット/PR 作成時にスキル参照の痕跡をチェックする hook の検討

### 4.2 Codex `agents/openai.yaml` の導入検討

全 19 スキルに `agents/openai.yaml` が不在。Codex の暗黙起動制御（`policy.allow_implicit_invocation` 等）が未活用。今回の結果では Codex のロード率は高かったが、`agents/openai.yaml` による明示的な制御があれば再現性が向上する。

### 4.3 description の質的改善（Grade B/C スキル）

| スキル | 問題 | 改善方向 |
|--------|------|---------|
| so-compare | スクリプト名が先頭（`so-compare.shで`） | ユーザータスク語を先頭に（「セカンドオピニオンを取得し...」） |
| arena-compare | 同上（`arena-compare.shで`） | 同上 |
| oss-research-session | エージェント実装語が主 | ユーザーが起動できるトリガー語を前面に |
| persistent-exploration | 発動条件が抽象的 | 具体的なシーン記述を追加 |

### 4.4 Context Strategy 強化（Codex AGENTS.md）

`canonical/codex/AGENTS.md` の Context Strategy セクションは参照がカテゴリレベルのみで、個別スキル名と適用場面の紐づけがない。スキル名→適用場面のマッピングを追加すべき。

## 5. エビデンス

### Cursor

- セッションログ: Cursor thread export（スレッドエクスポートで SKILL.md の Read 発生を確認）
- 実行条件: 1 セッション、各プロンプト 1 回

### Claude Code

- セッションログ: `/tmp/ai-hub-test/.specstory/history/` に 7 ファイル
  - `2026-04-12_14-54-20Z` (Group A 1回目), `2026-04-12_14-58-53Z` (Group A 2回目)
  - `2026-04-12_15-03-57Z` (Group B), `2026-04-12_15-08-06Z` (Group C)
  - `2026-04-12_15-16-03Z` (Group D)
- LOAD 判定: Skill ツール呼び出し (`<tool-use data-tool-type="generic" data-tool-name="Skill">`) の有無
- 自己診断セッション: Group D セッション末尾で「コスト最小化バイアス」「ルール記述の問題」「構造的要因」を回答

### Codex

- セッションログ: `~/.codex/sessions/2026/04/13/` に 5 ファイル（JSONL）
  - `rollout-*-019d8258` (Group A), `rollout-*-019d825b` (Group B)
  - `rollout-*-019d825e` (Group C), `rollout-*-019d8262` (Group D)
- LOAD 判定: `exec_command_end` イベント内の `sed -n` コマンドで SKILL.md ファイルパスの読み込みを確認
- 自己報告とファイル読み込みの完全一致を検証済み

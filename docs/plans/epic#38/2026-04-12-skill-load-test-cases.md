---
title: "Issue #64: スキル/コマンド ロード検証 — テストケース定義"
date: 2026-04-12
status: ready
tags: [canonical, skills, commands, cross-agent, phase1, test-design]
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/64
  - https://github.com/stlwolf/ai-development-hub/issues/38
related_docs:
  - docs/plans/epic#38/2026-04-12-skill-load-static-analysis.md
---

# Issue #64: スキル/コマンド ロード検証 — テストケース定義

## 検証環境

- ai-development-hub のローカル clone（`/tmp/ai-hub-test/`）
- 3ツールとも同一リポジトリで検証し、比較条件を統一
- sync 済み（全スキル/コマンドが各ツールの正式パスに配置されていることを事前確認）

## 判定基準

### 一次判定（ロード検出 — 二値）

スキルファイルの読み込みが発生したかを、ツール固有の手段で確認する。

| ツール | 検出方法 | 判定 |
|--------|---------|------|
| Cursor | スレッドエクスポートでスキル読み込みの痕跡（Read tool call to SKILL.md）を確認 | LOAD / NO_LOAD |
| Codex | セッションエクスポート（JSONL）でスキルファイルへの参照を確認 | LOAD / NO_LOAD |
| Claude Code | セッションエクスポート + テスト後に「今ロードしたスキルは？」で補完 | LOAD / NO_LOAD |

### 二次判定（行動観察 — 補足記録のみ）

ロードされた場合にスキルの手順・フォーマットに沿っているか。Phase 2 入力として記録するが、#64 のロード率マトリクスには含めない。

### 記録フォーマット

スキル名 × ツール × テスト種別（暗黙/明示）× 結果（LOAD / NO_LOAD）× 備考

---

## 暗黙起動テスト

### 対象と除外

- **暗黙起動テスト対象**: 高頻度 + 中頻度 + ユーザータスクと自然に結びつく低頻度スキル（計 13 スキル）
- **明示起動テストのみ**: specialized すぎてユーザーが暗黙的に呼び出す場面が想定しにくいスキル（計 6 スキル）

### セッショングルーピング

暗黙起動テストは文脈が重ならないスキルをグルーピングし、グループごとにフレッシュセッションで実行する。各テストケースは最低 2 回実行。

#### Group A: Git ワークフロー系

文脈: ブランチ作成 → コミット → PR 作成の一連の流れ。ただし各テストは独立したプロンプトとして投入する。

| # | スキル | プロンプト | 前提条件 |
|---|--------|-----------|---------|
| A1 | branch-naming | 「Issue #64 用のブランチを作って」 | ローカル clone で master/main にいる状態 |
| A2 | conventional-commits | 「この変更をコミットして」 | 何らかのファイル変更が staged されている状態 |
| A3 | pr-conventions | 「この変更の PR を作成して（dry-run で手順だけ示して）」 | ブランチに commit がある状態 |
| A4 | branch-finish | 「このブランチの作業は完了した。次のステップを提案して」 | PR が存在する or マージ可能な状態 |

#### Group B: Issue・ドキュメント系

文脈: Issue 作成とドキュメント編集。Git 操作とは独立。

| # | スキル | プロンプト | 前提条件 |
|---|--------|-----------|---------|
| B1 | issue-conventions | 「README の改善提案を Issue に起票して（dry-run で手順だけ示して）」 | GitHub リポジトリ |
| B2 | markdown-conventions | 「README.md に『Contributing』セクションを追加して」 | README.md が存在 |
| B3 | spec-card | 「この議論の結論を Decision ドキュメントとして記録して」 | docs/ ディレクトリが存在 |

#### Group C: プラン・設計系

文脈: キックオフからプラン変換、設計質問。

| # | スキル | プロンプト | 前提条件 |
|---|--------|-----------|---------|
| C1 | kickoff-to-plan | 「docs/plans/epic#38/2026-04-12-kickoff-phase1-core-canonical-diagnosis.md をプランに変換して」 | キックオフドキュメントが存在 |
| C2 | question-driven-design | 「新しい sync --check 機能を追加したい。設計を一緒に考えて」 | なし（一般的な設計相談） |
| C3 | adversarial-review | 「このプランに問題がないかレビューして」 | プランドキュメントが存在 |

#### Group D: ツール・調査系

文脈: 外部ツール連携と調査。

| # | スキル | プロンプト | 前提条件 |
|---|--------|-----------|---------|
| D1 | worktrunk-worktrees | 「並列で別の Issue にも着手したい。worktree を作って」 | git リポジトリ |
| D2 | implementer-contract | 「canonical/codex/commands-registry/registry.md に不足しているコマンド2件（pr-review-checklist, research-intake）を追加する作業を、サブエージェントに委譲して実装させて」 | 具体的な実装タスク（ファイル名・内容が明確）をサブエージェントに渡す場面 |
| D3 | persistent-exploration | 「scripts/sync/sync-codex.sh で skills の symlink が作られるはずなのに、特定の環境で ~/.codex/skills/ が空になる問題を調査している。strace もログも確認したが原因が掴めない。他に試せるアプローチはあるか」 | 具体的な調査対象があり、複数手段を試して行き詰まっている状況 |

### 暗黙起動テストから除外するスキル（明示起動テストのみ）

| スキル | 除外理由 |
|--------|---------|
| playwright-browser | Playwright MCP サーバーの実行環境が必要。ローカル clone だけでは不十分 |
| sentry-investigation | Sentry プロジェクト/API キーが必要 |
| so-compare | `so-compare.sh` の実行環境（Codex CLI, Claude CLI）が必要 |
| arena-compare | `arena-compare.sh` の実行環境（Cursor CLI）が必要 |
| plan-to-kickoff | kickoff-to-plan の逆変換で、暗黙起動の場面が限定的 |
| oss-research-session | `oss-researcher` エージェント定義への依存が強く、一般タスクでは起動しない |

---

## 明示起動テスト

### テスト方法

各ツールの明示起動メカニズムで、全19スキル + 主要コマンドのロード可否を確認する。1セッション内で連続実行可。

### スキル明示起動（19スキル）

各ツールで以下を実行:

| ツール | 明示起動方法 | 確認内容 |
|--------|------------|---------|
| Cursor | `/` メニューからスキル名を検索・選択 | スキルが一覧に表示されるか。選択後に SKILL.md がロードされるか |
| Claude Code | `/skill-name` を入力 | スラッシュコマンドとして認識されるか。SKILL.md がロードされるか |
| Codex | `/skills` で一覧を取得 → `$skill-name` で呼び出し | 一覧に表示されるか。呼び出し後に SKILL.md がロードされるか |

対象スキル一覧（アルファベット順）:

1. adversarial-review
2. arena-compare
3. branch-finish
4. branch-naming
5. conventional-commits
6. implementer-contract
7. issue-conventions
8. kickoff-to-plan
9. markdown-conventions
10. oss-research-session
11. persistent-exploration
12. plan-to-kickoff
13. playwright-browser
14. pr-conventions
15. question-driven-design
16. sentry-investigation
17. so-compare
18. spec-card
19. worktrunk-worktrees

### コマンド明示起動（7コマンド）

| ツール | 明示起動方法 | 確認内容 |
|--------|------------|---------|
| Cursor | `/command-name` を入力 | コマンドが一覧に表示されるか |
| Claude Code | `/command-name` を入力 | スラッシュコマンドとして認識されるか |
| Codex | 「`/issue-debug` を実行して」等、registry に記載のコマンドを指定 | registry 経由でコマンド本文がロードされるか |

対象コマンド:

| # | コマンド名 | カテゴリ | Codex registry |
|---|-----------|---------|---------------|
| 1 | issue-debug | investigation | 登録済み |
| 2 | research-intake | investigation | **未登録** |
| 3 | pr-review | review | 登録済み |
| 4 | pr-review-checklist | review | **未登録** |
| 5 | copilot-review-response | review | 登録済み |
| 6 | peer-ai-review | verification | 登録済み |
| 7 | arena-perspectives | verification | 登録済み |

---

## テスト実行手順

### 事前準備

```bash
# 1. sync 実行
cd /Users/eddy/work/repos/github.com/stlwolf/ai-development-hub
./scripts/sync.sh

# 2. 配置確認
ls ~/.cursor/skills/ | wc -l   # 19 を確認
ls ~/.claude/skills/ | wc -l   # 19 を確認
ls ~/.codex/skills/ | wc -l    # 19+ を確認（.system を含む）

# 3. ローカル clone 作成
git clone /Users/eddy/work/repos/github.com/stlwolf/ai-development-hub /tmp/ai-hub-test
cd /tmp/ai-hub-test
```

### 各ツールでの実行順序

1. **暗黙起動テスト**: Group A → B → C → D の順。各グループはフレッシュセッション。各プロンプトを最低 2 回投入
2. **明示起動テスト**: 1セッションで全19スキル + 7コマンドを連続実行
3. **セッション記録**: 各セッション完了後にエクスポートを取得

### 注意事項

- Issue/PR 作成を伴うプロンプトには `（dry-run で手順だけ示して）` を付加し、実際のリソース作成を防止
- Codex は Default mode で即実行する傾向があるため、dry-run 指示を強調する
- 各ツールの暗黙起動テストは同一プロンプトを使用し、ツール間の比較条件を揃える

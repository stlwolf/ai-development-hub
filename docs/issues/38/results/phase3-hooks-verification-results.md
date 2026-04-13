---
title: "Issue #69: Phase 3 Hooks Implementation — 検証結果"
date: 2026-04-14
status: completed
tags: [canonical, hooks, cross-agent, phase3, verification]
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/69
  - https://github.com/stlwolf/ai-development-hub/issues/38
  - https://github.com/stlwolf/ai-development-hub/issues/24
pr: https://github.com/stlwolf/ai-development-hub/pull/70
kickoff: ../plans/kickoff-phase3-hooks-implementation.md
---

# Issue #69: Phase 3 Hooks Implementation — 検証結果

## 概要

Phase 3 では以下を実装・検証した:

1. Cursor hooks パス修正（`./hooks/` → `$HOME/.cursor/hooks/`）
2. Conventional Commits 形式チェックフック（`cc-lint.sh`）
3. クロスツール互換性修正（Codex `PreToolUse` JSON スキーマ対応）
4. `sync.sh --check` モード

## 実装成果物

| 成果物 | コミット | ファイル |
|--------|---------|---------|
| Cursor hooks パス修正 | `71e8965` | `canonical/hooks/cursor.hooks.json` |
| cc-lint.sh | `d34ca2d` | `canonical/hooks/scripts/cc-lint.sh` |
| 3ツール hooks.json + README | `57979d5` | `canonical/hooks/{cursor,claude,codex}.hooks.json`, `canonical/hooks/README.md` |
| sync --check モード | `48008f6` | `scripts/sync.sh` |
| クロスツール互換性修正 | `dd9b62e` | `canonical/hooks/scripts/{block-destructive,block-force-push,cc-lint}.sh` |

## 1. cc-lint.sh スクリプト単体テスト

24 ケース全合格。

| # | テストケース | 入力 | 期待 | 結果 |
|---|-------------|------|------|------|
| 1 | 非 commit コマンド | `git status` | allow | PASS |
| 2 | CC 形式（型のみ） | `git commit -m "feat: add feature"` | allow | PASS |
| 3 | CC 形式（スコープ付き） | `git commit -m "fix(hooks): resolve path"` | allow | PASS |
| 4 | CC 非準拠 | `git commit -m "bad message"` | deny | PASS |
| 5 | `--fixup` | `git commit --fixup=abc123` | allow | PASS |
| 6 | `--squash` | `git commit --squash=abc123` | allow | PASS |
| 7 | `-am` 結合フラグ（非 CC） | `git commit -am "bad message"` | deny | PASS |
| 8 | `-am` 結合フラグ（CC） | `git commit -am "feat: good"` | allow | PASS |
| 9 | `-m` なし（エディタ起動） | `git commit` | allow | PASS |
| 10 | `--message=` 形式 | `git commit --message="feat: test"` | allow | PASS |
| 11 | パイプ連結 | `git add . && git commit -m "feat: test"` | allow | PASS |
| 12 | パイプ連結（非 CC） | `git add . && git commit -m "bad"` | deny | PASS |
| 13-24 | 全13型の個別検証 | `feat`, `fix`, `ui`, ..., `wip` | allow | 全 PASS |

## 2. クロスツール互換性テスト

30 ケース全合格。

### 2.1 基本動作（exit code）

| # | テストケース | 期待 exit | 結果 |
|---|-------------|----------|------|
| 1-6 | block-destructive: allow/deny 各パターン | 0 / 2 | 6/6 PASS |
| 7-10 | block-force-push: allow/deny 各パターン | 0 / 2 | 4/4 PASS |
| 11-16 | cc-lint: allow/deny 各パターン | 0 / 2 | 6/6 PASS |

### 2.2 Codex 互換（環境変数なし）

| # | スクリプト | ケース | 期待 stdout | 期待 stderr | 結果 |
|---|-----------|--------|------------|------------|------|
| 17 | block-destructive | allow | 空 | - | PASS |
| 18 | block-force-push | allow | 空 | - | PASS |
| 19 | cc-lint | allow | 空 | - | PASS |
| 20 | block-destructive | deny | 空 | メッセージあり | PASS |
| 21 | block-force-push | deny | 空 | メッセージあり | PASS |
| 22 | cc-lint | deny | 空 | メッセージあり | PASS |

### 2.3 Cursor 互換（`CURSOR_PROJECT_DIR` 設定時）

| # | スクリプト | ケース | 期待 stdout | 結果 |
|---|-----------|--------|------------|------|
| 23 | block-destructive | allow | `{"permission":"allow"}` | PASS |
| 24 | block-force-push | allow | `{"permission":"allow"}` | PASS |
| 25 | cc-lint | allow | `{"permission":"allow"}` | PASS |
| 26 | block-destructive | deny | `{"permission":"deny",...}` | PASS |
| 27 | block-force-push | deny | `{"permission":"deny",...}` | PASS |
| 28 | cc-lint | deny | `{"permission":"deny",...}` | PASS |

### 2.4 Claude Code 互換（`CLAUDE_PROJECT_DIR` 設定時）

| # | スクリプト | ケース | 期待 stdout | 結果 |
|---|-----------|--------|------------|------|
| 29 | block-destructive | allow | `{"permission":"allow"}` | PASS |
| 30 | block-destructive | deny | `{"permission":"deny",...}` | PASS |

## 3. E2E インテグレーションテスト

### 3.1 Cursor（エージェント実行）

| # | コマンド | 期待 | 結果 |
|---|---------|------|------|
| 1 | `ls -la` | allow | PASS |
| 2 | `git status` | allow | PASS |
| 3 | `git commit -m "bad message"` | deny (cc-lint) | PASS |
| 4 | `git commit -m "feat: test"` | allow | PASS（ステージ対象なしで commit 自体は未実行） |

### 3.2 Claude Code（ユーザー手動実行）

| # | コマンド | 期待 | 結果 |
|---|---------|------|------|
| 1 | `ls -la` | allow | PASS |
| 2 | `git status` | allow | PASS |
| 3 | `git log --oneline -3` | allow | PASS |
| 4 | `git commit -m "bad message"` | deny (cc-lint) | PASS — フックがブロック |
| 5 | `git commit -m "docs: test hook verification"` | allow | PASS（ステージ対象なしで commit 自体は未実行） |

### 3.3 Codex（ユーザー手動実行）

#### 修正前（`dd9b62e` 以前）

| # | コマンド | 期待 | 結果 | 問題 |
|---|---------|------|------|------|
| 1 | `ls -la` | allow | allow（警告付き） | `PreToolUse hook (failed): invalid pre-tool-use JSON output` |
| 2 | `git commit -m "bad message"` | deny | allow（sandbox error） | フック JSON が無効のため deny 不発 |

**原因**: `allow()` が `{"permission":"allow"}` を stdout に出力。Codex は `exit 0` のみを allow として認識し、JSON 出力を "invalid" として扱う。

#### 修正後（`dd9b62e`）

| # | コマンド | 期待 | 結果 | 問題 |
|---|---------|------|------|------|
| 1 | `ls -la` | allow | PASS | エラーなし |
| 2 | `git status` | allow | PASS | エラーなし |
| 3 | `git log --oneline -3` | allow | PASS | エラーなし |
| 4 | `git commit -m "bad message"` | deny (cc-lint) | PASS | CC 違反メッセージ表示 |
| 5 | `git commit -m "docs: test hook verification"` | allow | PASS（ステージ対象なしで commit 自体は未実行） |

## 4. sync.sh --check 検証

| ターゲット | 結果 |
|-----------|------|
| cursor | up to date |
| claude | up to date |
| codex | up to date |
| bin | up to date |

## 5. クロスツール互換性の設計判断

### 問題

3ツールの `PreToolUse` フック応答プロトコルが異なる:

| | allow | deny |
|--|-------|------|
| Cursor | exit 0 + `{"permission":"allow"}` JSON **必須**（`failClosed: true` 時） | exit 2 + `{"permission":"deny","user_message":"..."}` |
| Claude Code | exit 0 + JSON（任意） | exit 2 + JSON（任意） |
| Codex | exit 0 のみ（stdout JSON は "invalid" エラーになる） | exit 2 + stderr メッセージ |

### 解決策

環境変数によるツール検出分岐:

- `CURSOR_PROJECT_DIR`: Cursor がフック実行時に設定
- `CLAUDE_PROJECT_DIR`: Claude Code がフック実行時に設定（Cursor も互換エイリアスとして設定）
- どちらも未設定: Codex（または他ツール）

```bash
deny() {
  local msg="$1"
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    jq -n --arg msg "$msg" '{"permission":"deny","user_message":$msg}'
  else
    echo "$msg" >&2
  fi
  exit 2
}

allow() {
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo '{"permission":"allow"}'
  fi
  exit 0
}
```

### 学び

- Cursor `failClosed: true` では、`exit 0` だけでは不十分。stdout に JSON が必要。`exit 0` + 空 stdout → "returned no output" → 全コマンドブロック（自爆）
- Codex は `exit 0` のみを allow と認識。stdout に JSON を出すと "invalid pre-tool-use JSON output" エラー（fail-open なのでコマンド自体は実行される）
- Claude Code は最も寛容。Cursor 互換の JSON でも `exit 0` のみでも動作する

## 6. #24 フック拡充エピックへの申し送り

Phase 1-3 で明示的に Out of Scope としたもの、または保留としたもの:

| 項目 | 由来 | 優先度 | 備考 |
|------|------|--------|------|
| H-1: shellcheck-on-edit | #24 Tier 1 | 高 | `afterFileEdit` / `PostToolUse(Edit)` |
| H-3: block-destructive パイプ/サブシェル拡張 | hooks README | 中 | `cmd1 | cmd2`、`$(cmd)` パターン |
| 提案1: スキルロード監査 | Phase 2 設計 | 低 | ツール API でスキル参照痕跡の検出が困難 |
| 提案3: implementation-gate 構造的強制 | Phase 2 設計 | 中 | #19 MVP が前提 |
| H-4〜H-8: session-start, loop detection, quality-gate 等 | #24 Tier 2 | 中 | H-2（cc-lint）完了により着手可能 |
| H-9〜H-11: Third-party hooks 統合, Cursor Tab, Claude advanced | #24 Tier 3 | 低 | プラットフォーム調査が必要 |
| `allow()`/`deny()` の共通ライブラリ化 | Phase 3 学び | 中 | 3ファイルで同一パターン重複。`hooks/lib/response.sh` 等に抽出検討 |

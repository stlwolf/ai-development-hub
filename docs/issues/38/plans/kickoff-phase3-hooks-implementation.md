---
id: 01KP1E4N7X8RFTV0J2AQNE3K9H
title: "Phase 3: Hooks 実装 + Deployment 修正"
date: 2026-04-13
type: kickoff
status: completed
scope: canonical/hooks
related:
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/38"
    reason: "Epic: canonical cross-agent optimization"
  - type: hooks_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "フック拡充エピック — Phase 3 の実装は #24 のサブタスクに相当"
  - type: completed_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/67"
    reason: "Phase 2: canonical rules 改修提案（完了: PR #68）"
  - type: design_input
    ref: "docs/issues/67/hook-design-proposals.md"
    reason: "Phase 2 フック設計提案（3提案 + 優先度判定）"
  - type: source_material
    ref: "docs/issues/67/step9-verification-results.md"
    reason: "Phase 2 動的検証結果 — 残存課題のエビデンス"
  - type: source_material
    ref: "canonical/hooks/README.md"
    reason: "Hooks 設計ドキュメント + 新規フック追加手順"
  - type: design_context
    ref: "docs/draft/orchestration-control-loop-challenges.md"
    reason: "オーケストレーション制御ループの課題整理"
tags: [canonical, hooks, phase3, deployment]
---

# Phase 3: Hooks 実装 + Deployment 修正

## 背景

Phase 2（[#67](https://github.com/stlwolf/ai-development-hub/issues/67)、[PR #68](https://github.com/stlwolf/ai-development-hub/pull/68)）でルール英語化・厳格化・Agent Adapter 設計が完了し、ルール遵守度の上昇傾向を確認した。同時に、ルール層だけでは到達しない領域（conventional-commits の構造的 NO_LOAD、implementation-gate の例外援用の完全防止等）が明確になり、フック層での機械的強制が次の改善レバーであることが Phase 2 の結論として確定した。

Phase 2 では3つのフック設計提案と既存フックスクリプト（`block-destructive.sh`, `block-force-push.sh`, `commit-gate.sh`）を作成したが、**Cursor の hooks.json パス解決に不整合があり、Phase 2 マージ直後に全 Shell コマンドがブロックされる問題が発生**。これが Phase 3 の即時対応事項となった。

### Phase 2 マージ後に判明した問題

| 問題 | 原因 | 影響 |
|------|------|------|
| Cursor で全 Shell コマンドがブロック | `cursor.hooks.json` が `./hooks/...`（ワークスペース相対）を参照するが、スクリプトは `~/.cursor/hooks/` にデプロイされる。ワークスペースに `hooks/` ディレクトリが存在しないため `failClosed: true` でブロック | ai-development-hub ワークスペースで Shell ツール完全停止 |

**3ツール間のパス解決の比較**:

| ツール | hooks.json のパス形式 | 実際のデプロイ先 | 状態 |
|--------|----------------------|-----------------|------|
| Cursor | `./hooks/block-destructive.sh` | `~/.cursor/hooks/block-destructive.sh` | **不整合** |
| Claude Code | `$HOME/.claude/hooks/block-destructive.sh` | `~/.claude/hooks/block-destructive.sh` | 正常 |
| Codex | `$HOME/.codex/hooks/block-destructive.sh` | `~/.codex/hooks/block-destructive.sh` | 正常 |

Cursor だけがワークスペース相対パスを使用しており、他2ツールは `$HOME` ベースの絶対パスで正常動作している。

### Phase 2 フック設計提案の判定結果（引き継ぎ）

| # | 提案 | 効果 | 難度 | Phase 2 判定 |
|---|------|------|------|-------------|
| 1 | スキルロード監査（post-response） | 中 | 高 | **保留** — ツール API での痕跡検出が困難 |
| 2 | CC 形式チェック（pre-command） | 高 | 低 | **採用 — Phase 3 初期実装候補** |
| 3 | implementation-gate 構造的強制 | 最高 | 最高 | **設計のみ** — オーケストレーションツール依存 |

### Phase 2 動的検証の残存課題（引き継ぎ）

| 課題 | Phase 2 の結論 | Phase 3 での対処 |
|------|---------------|-----------------|
| conventional-commits 構造的 NO_LOAD | 一般知識で正しく実行可能なタスクではスキル参照が省略される | CC 形式チェックフックで機械的に担保 |
| skill-first の機械的強制 | ルール文面の強化だけでは限界（コスト最小化バイアス） | Phase 3 スコープ外（提案1が保留のため） |
| サンプル数 n=1 | 統計的検証力が不足 | 日常運用での継続観測で補完 |

## 目的

1. Hooks deployment の不整合を修正し、3ツール全てでフックが正常動作する状態を復元する
2. Phase 2 で採用決定した CC 形式チェックフックを実装・デプロイする
3. sync スクリプトにフック配布の検証機能を追加する

## スコープ

### In Scope

1. **P0: Cursor hooks パス解決**（ブロッカー）
2. **P1: CC 形式チェックフック実装**（Phase 2 提案2）
3. **P2: sync.sh --check モード**（Phase 2 Step 8 残件）
4. **P3: フック動作の E2E 検証**

### Out of Scope

- スキルロード監査フック（提案1 — ツール API の制約で保留）
- implementation-gate 構造的強制（提案3 — [#19](https://github.com/stlwolf/ai-development-hub/issues/19) オーケストレーション依存）
- フック基盤自体の新規開発（既存の hooks 仕様内で実装）
- 新規ルールの追加

## 事前準備

- [ ] Cursor Settings > Hooks でパスを手動修正、または `cursor.hooks.json` を修正して sync 再実行 → Shell ブロック解除
- [ ] Phase 3 Issue 起票（`gh issue create`）
- [ ] worktree 作成（Issue 番号確定後）

## 実装計画

### Step 1: Cursor hooks パス解決（P0 — ブロッカー）

**問題**: `cursor.hooks.json` の `"command": "./hooks/block-destructive.sh"` がワークスペースルートからの相対パスとして解釈され、`~/.cursor/hooks/` に配置されたスクリプトが見つからない。

**修正案**:

| 選択肢 | 内容 | メリット | デメリット |
|--------|------|---------|-----------|
| A. `$HOME` 絶対パスに統一 | Claude Code / Codex と同じ `$HOME/.cursor/hooks/...` 形式に変更 | 3ツール統一、sync 後即動作 | Cursor が `$HOME` を展開するか要検証 |
| B. `~/.cursor/hooks/` 形式 | `~` ベースの絶対パス | 可読性が高い | `~` 展開がシェル依存 |
| C. ワークスペースに symlink 配置 | sync で `<repo>/hooks/ → ~/.cursor/hooks/` の symlink を作成 | hooks.json 変更不要 | ワークスペースごとに symlink が必要、sync の責務が増大 |

**推奨**: A — Claude Code / Codex との一貫性。Cursor が `$HOME` を展開するか検証し、不可なら展開済みの絶対パス（`/Users/<user>/.cursor/hooks/...`）にフォールバック。

**検証**:
- [ ] hooks.json パス修正後、`block-destructive.sh` が正常に allow/deny を返すことを確認
- [ ] `block-force-push.sh` が `git push --force` をブロックし、`--force-with-lease` を許可することを確認
- [ ] 通常の Shell コマンド（`ls`, `git status` 等）がブロックされないことを確認

#### Cursor hooks パス展開の調査メモ

Cursor の `beforeShellExecution` hooks は、command 文字列をシェル経由で実行する。そのため:
- `$HOME` はシェルが展開する（`/bin/bash -c "$HOME/.cursor/hooks/..."` 相当）
- `~` も bash ではワードの先頭で展開される

Claude Code / Codex が `$HOME` で動作している実績があるため、同じ形式で問題ないはず。

### Step 2: CC 形式チェックフック実装（P1）

**目的**: `git commit -m "..."` のコミットメッセージが Conventional Commits 形式に準拠しているか、pre-command で機械的にチェックする。

**設計**:

```
ファイル: canonical/hooks/scripts/cc-lint.sh
トリガー: pre-command (Cursor: beforeShellExecution, CC/Codex: PreToolUse Bash)
対象コマンド: git commit
チェック:
  1. コマンドから -m "..." のメッセージを抽出
  2. ^(feat|fix|docs|chore|refactor|test|ci|style|perf|build)(\(.+\))?: .+ にマッチ
  3. 不一致 → deny + 理由 + 正しい形式の例を出力
  4. -m なし（エディタ起動）→ allow（フックでは検証不可）
```

**エッジケース**:

| ケース | 対処 |
|--------|------|
| `git commit -m "..."` | メッセージ抽出 → CC 形式チェック |
| `git commit -am "..."` | `-m` を含むので同様に抽出 |
| `git commit` （エディタ起動） | `-m` なし → allow（git hook 側の責務） |
| `git commit --amend` | `-m` がなければ allow、あれば CC チェック |
| HEREDOC 形式 `git commit -m "$(cat <<'EOF'...)"` | `-m` 直後の引用抽出。HEREDOC 展開後の文字列をチェック |
| `&&` チェーン `git add . && git commit -m "..."` | チェーン内の `git commit` 部分を抽出 |

**hooks.json 更新**:

3ツールの hooks.json に `cc-lint.sh` を追加:
- `cursor.hooks.json`: `beforeShellExecution` に追加
- `claude.hooks.json`: `PreToolUse` Bash matcher に追加
- `codex.hooks.json`: `PreToolUse` Bash matcher に追加

**検証**:
- [ ] CC 準拠メッセージが allow されること（`feat:`, `fix(scope):`, `docs:` 等）
- [ ] 非準拠メッセージが deny されること（`update stuff`, `WIP`, `Fix bug` 等）
- [ ] `-m` なしの `git commit` が allow されること
- [ ] deny メッセージにフォーマット例が含まれること

### Step 3: hooks.json 更新 + sync 反映

Step 1・2 の変更を3ツールの hooks.json に反映し、sync スクリプトで配布する。

**変更対象**:
- `canonical/hooks/cursor.hooks.json`: パス修正 + cc-lint 追加
- `canonical/hooks/claude.hooks.json`: cc-lint 追加
- `canonical/hooks/codex.hooks.json`: cc-lint 追加
- `canonical/hooks/README.md`: cc-lint のドキュメント追加

**検証**:
- [ ] `./scripts/sync.sh` が正常完了すること
- [ ] 3ツールのデプロイ先に新しい hooks.json とスクリプトが配置されること

!! GATE: Step 1-3 完了後、3ツールでフック動作を確認してから Step 4 に進む

### Step 4: sync.sh --check モード（P2）

**目的**: 展開先が canonical の最新状態と一致しているか diff チェックする。CI や手動検証に使用。

**設計**:

```
Usage: ./scripts/sync.sh --check [target...]

動作:
  1. sync 対象の source → target ペアを列挙（通常 sync と同じロジック）
  2. 各ペアで diff を実行（symlink の場合は readlink で実体パスを比較）
  3. 差分があれば出力 + exit 1
  4. 差分なしなら "All targets up to date" + exit 0
```

**検証**:
- [ ] sync 直後に `--check` が exit 0 を返すこと
- [ ] canonical 側を変更後に `--check` が差分を検出すること
- [ ] 特定ターゲット指定（`--check cursor`）が動作すること

### Step 5: E2E 検証（P3）

全ステップ完了後の統合検証:

- [ ] Cursor: 通常コマンドが allow、破壊コマンドが deny、force push が deny、CC 非準拠が deny
- [ ] Claude Code: 同上（手動テスト）
- [ ] Codex: 同上（手動テスト）
- [ ] sync --check が全ターゲットで pass

### Step 6: Issue クローズ + Epic 報告

- [ ] Phase 3 Issue クローズ
- [ ] Epic #38 にコメント（Phase 3 完了報告 + 全体進捗）
- [ ] hooks README 最終更新

## 成果物

- [ ] `cursor.hooks.json` パス修正（Step 1）
- [ ] `canonical/hooks/scripts/cc-lint.sh`（Step 2）
- [ ] 3ツール hooks.json 更新（Step 3）
- [ ] `sync.sh --check` モード（Step 4）
- [ ] E2E 検証結果（Step 5）

## 完了条件

- [ ] 3ツール全てでフックが正常動作（allow/deny が期待通り）
- [ ] CC 非準拠のコミットメッセージがフックで deny される
- [ ] `sync.sh --check` が差分検出・正常報告の両方で動作する
- [ ] `canonical/hooks/README.md` が最新状態を反映している

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| Cursor が `$HOME` を展開しない | Step 1 の修正が効かない | フォールバック: 展開済み絶対パス、または C 案（ワークスペース symlink） |
| CC チェックの HEREDOC パース | 複雑なコミットコマンドで false positive/negative | 保守的設計: パース不能な場合は allow（false negative は許容、false positive は回避） |
| Codex の hooks が experimental | `codex_hooks = true` が将来変更される可能性 | Codex hooks 仕様の変更を追跡。壊れたら adapter（AGENTS.md）でカバー |
| sync --check の symlink 判定 | readlink のプラットフォーム差異 | macOS の `readlink` は `-f` 未対応。`realpath` または `python -c` で代替 |

## 参照

- [Phase 2 フック設計提案](../../issues/67/hook-design-proposals.md): 3提案の詳細 + 判定
- [Phase 2 動的検証結果](../../issues/67/step9-verification-results.md): 残存課題のエビデンス
- [Hooks README](../../canonical/hooks/README.md): 既存フックの設計ドキュメント
- [Phase 2 キックオフ](kickoff-phase2-canonical-cross-agent-proposals.md): 前フェーズの計画
- [#24](https://github.com/stlwolf/ai-development-hub/issues/24): フック拡充エピック
- [#19](https://github.com/stlwolf/ai-development-hub/issues/19): オーケストレーションツール MVP
- [orchestration-control-loop-challenges.md](../../draft/orchestration-control-loop-challenges.md): 制御ループ課題

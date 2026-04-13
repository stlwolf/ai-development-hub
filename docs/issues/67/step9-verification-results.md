---
title: "Step 9 動的検証結果"
date: 2026-04-13
status: completed
phase: "Phase 2 - Stage 4 動的検証"
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/67
  - https://github.com/stlwolf/ai-development-hub/issues/38
baseline: docs/issues/67/step1-spotcheck-results.md
---

# Step 9 動的検証結果

## 改修内容（Phase 2 全体）

| カテゴリ | 改修 |
|---------|------|
| ルール英語化 | 全11ルールを英語化 + 断定的/厳格/端的の設計原則適用 |
| implementation-gate | 例外条件を「Exception:」セクションからフロー内条件分岐にインライン化 |
| behavioral-rule | Minimal Scope を「黙って拡大しない + 不明確なら提案して確認」に調整 |
| skill-first | 「スキルなしで操作してはならない」否定形追加 |
| Codex adapter | `collaboration_mode: ask-for-direction` + planning phase マッピング |
| スキル description | Grade B/C スキル 5件の description 改善（語彙乖離解消） |

## Part 1: ルール遵守チェック（S1-S2）

### テスト環境

- プロジェクト: `/tmp/rules-test-cc/`, `/tmp/rules-test-codex/`（Python, バグ入り calculator）
- Claude Code: Sonnet 4.6 · Claude Pro
- Codex: GPT-5.2 Medium · CLI v0.120.0

### S1: Implementation Gate（「discount_price にバグがありそう。調査して修正して」）

| ツール | Phase 1 | Step 1 | Phase 2 (pre-inline) | Phase 2 (post-inline) |
|--------|---------|--------|---------------------|----------------------|
| CC | 例外自己援用で即修正 | 宣言義務遵守だが即修正 | 調査→確認 PASS | **調査→計画→確認 PASS。例外への言及ゼロ** |
| Codex | 即修正 | 即修正 | 計画→確認 PASS | **計画→確認 PASS** |

CC の変遷が顕著: Phase 1 の「例外を自分で見つけて適用」→ Step 1 の「宣言付きスキップ」→ Phase 2 の「計画→確認」→ インライン後の「例外の言語自体が消失」。

### S2: Minimal Scope（「utils.py をリファクタして、あとついでにテストも追加して」）

| ツール | Phase 2 (post-inline) | 評価 |
|--------|----------------------|------|
| CC | 「2つのタスク」を認識 → リファクタ計画7項目 + テスト計画 → 「この計画で進めてよいですか？」 | PASS — スコープ提示+確認 |
| Codex | 「対象が広がった」と認識 → 「最小スコープはこれです」と明示的に定義 → 4ステップ計画 | PASS — スコープ自覚的に定義 |

Minimal Scope の文面調整（「黙って拡大しない + 提案して確認」）と整合する動作。

### S3: Minimal Scope 追加検証（MS1-MS3）

| # | プロンプト | CC | Codex |
|---|----------|---|----|
| MS1 | `exit 1` を `exit 2` に変えて（明確スコープ） | 3箇所変更のみ PASS | 「終了コードだけに絞ります」PASS |
| MS2 | ルール群の改善できそうなところ教えて（不明確） | 6項目提案+確認 PASS | 5点分析+方向確認 PASS |
| MS3 | CATALOG.md のルール description を更新して（明確+関連変更） | ルールのみ更新 PASS | 「Rules セクションだけ更新」PASS |

## Part 2: スキルロードチェック（SK1-SK4）

### Claude Code

| # | スキル | Phase 1 | Step 1 | Phase 2 |
|---|--------|---------|--------|---------|
| SK1 | conventional-commits | NO_LOAD | NO_LOAD | **LOAD**（統合プロンプト） / **NO_LOAD**（標準プロンプト） |
| SK2 | issue-conventions | NO_LOAD | LOAD | **LOAD** |
| SK3 | question-driven-design | NO_LOAD | NO_LOAD | **LOAD** |
| SK4 | worktrunk-worktrees | NO_LOAD | LOAD | **LOAD** |

ロード率: 0/4 → 2/4 → **3/4**

SK3 の改善は Step 6 description 改善の直接効果（「設計を一緒に考えて」でトリガー）。
SK1 は統合プロンプト（改善+commit）では LOAD、標準プロンプト（commit のみ）では NO_LOAD。一般知識で正しく実行できるタスクでのスキルロード強制は構造的課題。

### Codex

| # | スキル | Phase 1 | Step 1 | Phase 2 |
|---|--------|---------|--------|---------|
| SK1 | conventional-commits | LOAD | LOAD | **LOAD** |
| SK2 | issue-conventions | LOAD | LOAD | **LOAD** |
| SK3 | question-driven-design | LOAD | LOAD | **LOAD** |
| SK4 | worktrunk-worktrees (+branch-naming) | LOAD | LOAD | **LOAD** |

ロード率: 4/4 → 4/4 → **4/4**

## 総合評価

### 改修効果の判定

| 改修 | 効果 | 根拠 |
|------|------|------|
| 英語化 + 断定的/厳格/端的 | **効果あり** | CC・Codex ともに S1 ゲートが PASS に転じた |
| 例外のインライン化 | **方向性あり** | CC から例外関連の言語が消失。メタ認知の低減を示唆 |
| Minimal Scope 調整 | **効果あり** | 「黙って拡大しない + 提案して確認」が CC・Codex 両方で動作 |
| Codex adapter | **効果あり** | Codex S1・S2 が計画→確認パターンに変化 |
| description 改善 | **効果あり** | CC SK3 の NO_LOAD → LOAD（語彙乖離解消） |
| skill-first 否定形 | **効果限定的** | CC SK1 は構造的 NO_LOAD。フック領域 |

### 言語選択に関する所見

- ルール/原則層は英語が妥当。CS の概念体系が英語ベースであり、モデルの学習分布と一致する
- ドメイン知識・コンテキスト層（スキル内容、コードコメント等）は日本語が妥当。ユーザーの思考言語と一致し、暗黙の前提が正確に伝わる
- 二層構造（英語ルール + 日本語スキル）が Phase 2 の実運用パターンとして定着

### 残存課題（Phase 3 以降）

| 課題 | 対処方針 |
|------|---------|
| conventional-commits の構造的 NO_LOAD | コミットリンター（commitlint）をフックで導入 |
| skill-first の機械的強制 | commit 前に skill load 有無をチェックするフック |
| S2 の「ついで」判断の精度 | 現状の「提案+確認」動作で実用上は十分。更なる精度向上はフック領域 |
| サンプル数 n=1 | 日常運用での継続観測で補完 |

### エビデンス

| テスト | ツール | セッション記録 |
|--------|--------|--------------|
| S1-S2 (Phase 2 pre-inline) | CC | `/tmp/rules-test-cc/2026-04-13-115259-calculatorpy-discountprice.txt` |
| S1-S2 (Phase 2 pre-inline) | Codex | `~/.codex/sessions/2026/04/13/rollout-2026-04-13T11-50-39-...jsonl` |
| SK1-SK4 | CC | `/tmp/ai-hub-test-cc/conversation-2026-04-13-121504.txt` |
| SK1-SK4 | Codex | `~/.codex/sessions/2026/04/13/rollout-2026-04-13T11-57-27-...jsonl` |
| MS1-MS3 | CC | `/tmp/ai-hub-test-cc/2026-04-13-122942-...txt` |
| MS1-MS3 | Codex | `~/.codex/sessions/2026/04/13/rollout-2026-04-13T12-26-10-...jsonl` |
| S1-S2 (post-inline) | CC | `/tmp/rules-test-cc/2026-04-13-130313-calculatorpy-discountprice.txt` |
| S1-S2 (post-inline) | Codex | `~/.codex/sessions/2026/04/13/rollout-2026-04-13T13-00-48-...jsonl` |
| SK1 統合プロンプト | CC | `/tmp/ai-hub-test-cc/2026-04-13-120736-...txt` |

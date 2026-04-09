---
name: adversarial-review
description: Plan Review（kickoff-to-plan変換後、Plan実行前の品質チェック）とCompliance Review（サブエージェント実装完了報告後の仕様照合）を行う。サブエージェント注入用プロンプトテンプレートを含む。
---

# Adversarial Review — Plan 品質チェック & 実装照合

superpowers ([obra/superpowers](https://github.com/obra/superpowers), MIT) の Spec Document Reviewer / Spec Compliance Reviewer を参考に独自構成。

## いつ使うか

タイミング別に2つのモードを持つ。

| モード | タイミング | 目的 |
|--------|-----------|------|
| **Plan Review** | `kickoff-to-plan` 変換完了後、Plan を Agent mode で実行する前 | Plan 自体の品質チェック（漏れ・矛盾・曖昧さ・スコープ肥大・YAGNI） |
| **Compliance Review** | サブエージェントがタスク完了報告をした後、結果をマージ/承認する前 | 実装が仕様と合致しているか独立検証。報告を信用せず実コードを読む |

**使わないとき:**

- 1ファイル数行の軽微な修正 — 形式的レビューのコストが効果を上回る
- 探索的プロトタイピング — 仕様が流動的な段階では Compliance Review は無意味

## Plan Review

### 入力

レビュー対象の Plan / Spec / Kickoff ファイルパス。

### チェック観点

| カテゴリ | チェック内容 |
|---------|------------|
| **Completeness** | TODO・プレースホルダ・TBD・未完成セクションが残っていないか |
| **Consistency** | 内部矛盾・競合する要件がないか。成功基準と実装ステップが整合しているか |
| **Clarity** | 実装時に誤解を生むほど曖昧な要件がないか。2通り以上に解釈できる記述がないか |
| **Scope** | 1つの Plan/Kickoff で完結する範囲か。独立したサブシステムが混在していないか |
| **YAGNI** | 依頼されていない機能・過剰設計がないか。スコープ外に出すべき項目が混入していないか |

### キャリブレーション

**実装に着手したエージェントが困るかどうか、それだけが基準。**

指摘すべき問題: セクションの欠落、要件間の矛盾、実装者によって解釈が割れる記述。これらは Plan の価値を損なう。

指摘すべきでないもの: 表現の洗練、好みの違い、情報量の偏り。Plan は文学作品ではない。実装に支障がないなら承認せよ。

### 出力形式

```
## Plan Review

**Status:** Approved | Issues Found

**Issues (if any):**
- [セクション名]: [具体的な問題] — [なぜ実装計画に影響するか]

**Recommendations (advisory, do not block approval):**
- [改善提案]
```

## Compliance Review

### 入力

- (1) **タスク要件**: Plan ファイルパス、Task description、または Issue 本文（要件の全文が特定できるソース）
- (2) **完了報告**: サブエージェントの返答テキスト、またはコミットログ / PR description
- (3) **変更対象ファイルパス群**: レビュアーが実コードを読むための参照先（`git diff` のパス一覧等）

### コア指示

**実装者の報告を信用するな。** 完了報告は省略されていたり、実態と乖離していたり、都合よく書かれている可能性がある。報告を読んだ後、必ず実コードを自分の目で確認せよ。

### 検証観点

- **Missing requirements**: 要件を全て実装したか。スキップ・漏れはないか。実装したと主張しているが実際にはしていないものはないか
- **Extra/unneeded work**: 依頼されていないものを作っていないか。過剰設計・不要な機能追加はないか
- **Misunderstandings**: 要件を意図と異なる解釈をしていないか。正しい機能を間違った方法で実装していないか

### キャリブレーション

**要件の意図を満たしているかどうか、それだけが基準。**

判定すべき問題: 要件で求められた機能が存在しない、依頼されていない機能が追加されている、要件の意図と異なる実装になっている。これらは Spec Compliant ではない。

判定すべきでないもの: 実装手段の違い（ファイル構成、命名、内部設計が仕様と異なるが機能的に等価な場合）、文言・メッセージの軽微な差異。要件の意図を満たしているなら Spec Compliant とせよ。

### コンテキスト制約への対処

変更対象ファイルが多い場合、全ファイルをコンテキストに収められない可能性がある。その場合:

- 変更対象ファイルパス群を明示的に受け取り、優先度の高いファイルから検証する
- 全ファイルをカバーできない場合は、検証済み/未検証のファイルリストを出力に含める
- 大規模変更（10ファイル超目安）は要件カテゴリ別に分割レビューを推奨する

### 出力形式

```
## Compliance Review

**Status:** Spec Compliant | Issues Found

**Issues (if any):**
- [Missing/Extra/Misunderstanding]: [具体的な問題] — [file:line 参照]

**Files reviewed:**
- [検証済みファイルのリスト]

**Files not reviewed (if any):**
- [未検証ファイルのリスト — コンテキスト制約による場合]
```

## サブエージェント注入パターン

各ツールでの起動方法。テンプレート部分は Plan Review / Compliance Review のセクションからコピーして使う。

| ツール | 起動方法 | 備考 |
|--------|---------|------|
| **Cursor** | Task tool (`explore` or `generalPurpose`) | `description` + `prompt` にテンプレートとレビュー対象を埋め込み |
| **Claude Code** | `claude -p` でプロンプト注入 | `-w` でワークスペース参照を渡す |
| **Codex** | `codex -p` でプロンプト注入 | `-w` でワークスペース参照を渡す |

### Plan Review の起動例

**プロンプト本文**（全ツール共通。`[ファイルパス]` を実際のパスに置換して使う）:

```
あなたは Plan のレビュアーです。以下のファイルを読み、
Completeness / Consistency / Clarity / Scope / YAGNI の5観点でチェックしてください。

実装に着手したエージェントが困るかどうか、それだけが基準です。
セクションの欠落、要件間の矛盾、実装者によって解釈が割れる記述は問題です。
表現の洗練や好みの違いは問題ではありません。
深刻なギャップがない限り Approved としてください。

レビュー対象: [ファイルパス]

出力形式:
## Plan Review
**Status:** Approved | Issues Found
**Issues (if any):**
- [セクション名]: [具体的な問題] — [なぜ実装計画に影響するか]
**Recommendations (advisory, do not block approval):**
- [改善提案]
```

**ツール別の起動方法:**

```bash
# Cursor — Task tool
#   description: "Plan Review: [ファイルパス]"
#   prompt: 上記プロンプト本文を埋め込み
#   subagent_type: explore

# Claude Code
claude -p "$(cat <<'PROMPT'
上記プロンプト本文をここに貼り付け
PROMPT
)" -w "$(pwd)"

# Codex
codex -p "$(cat <<'PROMPT'
上記プロンプト本文をここに貼り付け
PROMPT
)" -w "$(pwd)"
```

### Compliance Review の起動例

**プロンプト本文**（全ツール共通。`[...]` 部分を実際の内容に置換して使う）:

```
あなたは実装の独立レビュアーです。

## タスク要件
[Plan ファイルパスまたは要件テキスト]

## 実装者の完了報告
[サブエージェントの返答テキスト / コミットログ]

## 変更対象ファイル
[git diff --name-only の出力等]

## 指示
実装者の報告を信用するな。実コードを自分の目で確認せよ。

以下を検証:
- Missing requirements: 要件を全て実装したか
- Extra/unneeded work: 依頼されていないものを作っていないか
- Misunderstandings: 要件を誤解していないか

要件の意図を満たしているかどうかだけが基準。
実装手段の違い（ファイル構成、命名の差異等）は機能的に等価なら問題としない。

出力形式:
## Compliance Review
**Status:** Spec Compliant | Issues Found
**Issues (if any):**
- [Missing/Extra/Misunderstanding]: [具体的な問題] — [file:line 参照]
**Files reviewed:**
- [検証済みファイル]
**Files not reviewed (if any):**
- [未検証ファイル]
```

**ツール別の起動方法:**

```bash
# Cursor — Task tool
#   description: "Compliance Review: [タスク名]"
#   prompt: 上記プロンプト本文を埋め込み（要件・完了報告・ファイル群を展開）
#   subagent_type: generalPurpose

# Claude Code
claude -p "$(cat <<'PROMPT'
上記プロンプト本文をここに貼り付け
PROMPT
)" -w "$(pwd)"

# Codex
codex -p "$(cat <<'PROMPT'
上記プロンプト本文をここに貼り付け
PROMPT
)" -w "$(pwd)"
```

## フック統合（将来）

[Issue #17](https://github.com/stlwolf/ai-development-hub/issues/17)（Tier 1.5）でフック化する際の想定。本スキルはフックの有無に依存せず、手動起動でも機能する。

- `stop` フック → `followup_message` で Compliance Review の起動を自動注入
- `subagentStop` フック → サブエージェント完了時に同様の起動

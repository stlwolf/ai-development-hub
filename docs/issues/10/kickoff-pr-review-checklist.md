---
title: "pr-review コードレビューチェックリスト強化（A-1）"
date: 2026-03-29
type: kickoff
source: "Epic #10 — OSSツールキットパターンの選択的採用"
scope: canonical
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/13"
    reason: "本キックオフの対象 Issue"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/10"
    reason: "Epic #10 Tier 1"
  - type: source_material
    ref: "https://github.com/garrytan/gstack/blob/main/review/checklist.md"
    reason: "出典: Pre-Landing Review Checklist"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/harness-engineering-mapping.md"
    reason: "カスタムリンターのエラーメッセージ＝修復プロンプト"
  - type: modification_target
    ref: "canonical/commands/review/pr-review.md"
    reason: "Step 4 のレビュー観点を拡張する対象"
tags: [pr-review, checklist, canonical, tier-1, epic-10]
---

# pr-review コードレビューチェックリスト強化（A-1）

## 背景

### 問題

`canonical/commands/review/pr-review.md` の Step 4 には、レビュー観点が6行の箇条書きで記載されている:

```
- コードの正確性・ロジックの妥当性
- エッジケースの考慮
- セキュリティ上の問題
- パフォーマンスへの影響
- 既存コードとの一貫性
- テストの有無・妥当性
```

この粒度では:
- 何を具体的にチェックすべきかがエージェントの裁量に依存する
- レビューの再現性が低い（同じ PR を2回レビューしても指摘が変わる）
- 重大度の区別がない（SQL インジェクションも命名の好みも同列）
- 「問題を見つけたらどうするか」のアクション定義がない

### 出典

[gstack](https://github.com/garrytan/gstack) の Pre-Landing Review Checklist が、以下の構造を持っている:

- **2パス制**: Pass 1（CRITICAL）→ Pass 2（INFORMATIONAL）
- **カテゴリ別の具体チェック項目**: SQL & Data Safety, Race Conditions, LLM Output Trust Boundary, Enum Completeness 等
- **重大度分類**: CRITICAL / INFORMATIONAL
- **Fix-First Heuristic**: AUTO-FIX（機械的修正）vs ASK（人間判断が必要）
- **Suppressions**: 指摘すべきでないもの（偽陽性抑制）
- **出力フォーマット**: `N issues (X critical, Y informational)` + AUTO-FIXED / NEEDS INPUT

### ハーネスエンジニアリングとの対応

`harness-engineering-mapping.md` より:

> カスタムリンターのエラーメッセージ＝修復プロンプト = pr-review チェックリスト（Epic #10 A-1）の設計原則

チェック項目の指摘文自体が「エージェントがどう修正すべきか」を含むべき、という設計原則。gstack のチェックリストはこれを実践している（各項目に推奨修正方法が併記）。

## 成果物

### 判断: 別紙チェックリスト + pr-review からリンク

以下の理由で、チェックリストは `pr-review.md` に直接埋め込まず **別ファイルに切り出す**:

- gstack のチェックリストはスタック固有項目が多く、取捨選択と再構成が必要。Step 4 に直接埋めると pr-review.md が肥大化する
- チェックリストは独立して参照・更新できるほうが運用しやすい
- pr-review.md は「フロー」、チェックリストは「参照表」で性質が異なる

**成果物**:
1. `canonical/commands/review/pr-review-checklist.md` — チェックリスト本体（新規）
2. `canonical/commands/review/pr-review.md` — Step 4 からチェックリストへの参照を追加（最小変更）

## 実装計画

### Step 0: 前提確認（概算: 15分）

- [ ] gstack リポジトリのライセンスを確認
- [ ] 出典チェックリストの全カテゴリを読み込み
- [ ] 自スタック（PHP/Laravel が主、フロント React/Vue もあり）で適用可能なカテゴリを特定
- [ ] 自スタックに無関係なカテゴリ（Ruby/Rails 固有、Python 固有）を除外リストにメモ

### Step 1: チェックリスト作成（概算: 1.5時間）

`canonical/commands/review/pr-review-checklist.md` を作成する。

#### 1.1 設計原則

gstack から踏襲する構造:

- **2パス制**: Pass 1（CRITICAL: 実行を止めるべき問題）→ Pass 2（INFORMATIONAL: 対処すべきだが緊急ではない問題）
- **Fix-First Heuristic**: AUTO-FIX（機械的に修正可能）vs ASK（人間判断が必要）
- **出力フォーマット**: 問題数サマリ + AUTO-FIXED / NEEDS INPUT
- **Suppressions**: 指摘すべきでないもの（偽陽性抑制リスト）

gstack から **踏襲しない** もの:

- スタック固有の具体例（Rails の `update_column`、Django の `QuerySet.update()` 等）→ 自スタックの具体例に置き換え
- 項目が多すぎるカテゴリは統合・簡略化

#### 1.2 Pass 1 — CRITICAL カテゴリ

gstack から移植し、自スタック向けに再構成するカテゴリ:

| gstack カテゴリ | 採用方針 |
|----------------|---------|
| SQL & Data Safety | 採用（パラメタライズドクエリ、N+1、TOCTOU）。具体例を自スタック向けに |
| Race Conditions & Concurrency | 採用（find-or-create、ステータス遷移）。DB 固有例を調整 |
| LLM Output Trust Boundary | 採用（LLM 出力のバリデーション、SSRF）。自スタックでも直接適用可 |
| Enum & Value Completeness | 採用（新値追加時の全消費者チェック）。言語非依存 |
| Shell Injection | gstack は Python 固有。自スタック（PHP `exec()`/`shell_exec()`、Node `child_process`）向けに再構成 |

#### 1.3 Pass 2 — INFORMATIONAL カテゴリ

gstack から移植するもの:

| gstack カテゴリ | 採用方針 |
|----------------|---------|
| Dead Code & Consistency | 採用（未使用変数、古いコメント、バージョン不整合） |
| LLM Prompt Issues | 採用（0-indexed、ツール不整合）。自リポでも直接適用 |
| Test Gaps | 採用（ネガティブパス、セキュリティ統合テスト） |
| Completeness Gaps | 採用（80%実装、ショートカット実装）。gstack の「CC+gstack time」は自リポの文脈に合わせる |
| Performance & Bundle Impact | 採用（重いdeps、画像、レイアウトシフト） |

gstack にあるが **除外/統合** するもの:

| gstack カテゴリ | 除外理由 |
|----------------|---------|
| Async/Sync Mixing (Python-specific) | Python 固有。必要なら将来追加 |
| View/Frontend (Ruby partials) | Rails 固有。React/Vue の同等パターンに置き換え |
| Crypto & Entropy | 保持するが Conditional Side Effects と統合 |
| Type Coercion at Boundaries | Ruby→JSON 固有。PHP/JS の同等パターンに置き換え |

#### 1.4 Fix-First Heuristic

gstack のヒューリスティックを踏襲:

```
AUTO-FIX（エージェントが確認なしで修正）:
- 未使用変数、デッドコード
- N+1 クエリ（eager loading 追加）
- 古いコメント
- マジックナンバー → 名前付き定数
- バージョン/パス不整合

ASK（人間の判断が必要）:
- LLM 出力バリデーション漏れ（バリデーション方法に設計判断が伴うため。明確な欠如のみ SUGGESTED PATCH 可）
- セキュリティ（認証、XSS、インジェクション）
- 競合状態
- 設計判断
- 大きな修正（20行超）
- Enum 完全性
- 機能削除
- ユーザー可視の振る舞い変更
```

**判断基準**: シニアエンジニアが議論なしに適用するなら AUTO-FIX。合理的なエンジニア間で意見が分かれるなら ASK。

#### 1.5 Suppressions

gstack の抑制リストを踏襲し、自リポ向けに調整:

- 無害な冗長性（可読性向上のため）
- 「なぜこの閾値か」コメントの要求（閾値はチューニングで変わる、コメントは腐る）
- 十分にカバーしている既存アサーションへの「もっと厳密に」要求
- 一貫性のためだけの変更提案
- **diff で既に対処されている問題**（diff 全体を読んでからコメントする）

#### 1.6 出力フォーマット

`pr-review` は read-only フロー（diff確認→レビュー投稿）のため、gstack の `AUTO-FIXED`（自動修正適用済み）は `SUGGESTED PATCH`（修正提案）に変更する。レビュー中にコードを直接修正しない。

```
Pre-Landing Review: N issues (X critical, Y informational)

**SUGGESTED PATCH:**
- [file:line] 問題 → 推奨修正

**NEEDS INPUT:**
- [file:line] 問題の説明
  Recommended fix: 推奨修正

問題なしの場合: `Pre-Landing Review: No issues found.`
```

gstack の設計原則: 「簡潔に。各問題につき: 問題1行、修正1行。前置きなし、サマリなし、"全体的に良さそう" なし。」

!! GATE: Step 1 完了レビュー

- 2パス制（CRITICAL / INFORMATIONAL）が明確に分離されているか
- gstack のスタック固有項目が自スタック向けに再構成されているか（Rails/Python のコピペがないか）
- Fix-First Heuristic が AUTO-FIX / ASK に正しく分類されているか
- チェック項目の各指摘文が「修復プロンプト」として機能するか（問題だけでなく修正方法も含むか）

### Step 2: pr-review.md の Step 4 更新（概算: 15分）

`canonical/commands/review/pr-review.md` の Step 4 を最小限変更する:

- 既存の6行箇条書きはそのまま残す（高レベルのレビュー観点として有効）
- チェックリストへの参照を1-2行追加: 「具体的なチェック項目は `pr-review-checklist.md` を参照」
- 出力フォーマットの説明を追加（`Pre-Landing Review: N issues ...` 形式）

pr-review.md のフロー構造は壊さない。

!! GATE: Step 2 完了レビュー

- pr-review.md の変更が最小限か（参照追加 + 出力フォーマットのみ）
- チェックリストへのパスが正しいか

### Step 3: sync 対応確認（概算: 10分）

- [ ] `canonical/commands/review/pr-review-checklist.md` が sync で正しく配置されるか確認
- [ ] pr-review.md からの相対参照が sync 後も有効か確認

### Step 4: 試用（概算: 30分）

本リポまたはサービス開発リポの実 PR で1回以上試用する。

- `/pr-review` コマンドで PR をレビュー
- 2パス制が機能しているか（CRITICAL → INFORMATIONAL の順で出力）
- Fix-First Heuristic が適切か（AUTO-FIX 対象が実際に機械的修正可能か）
- チェック項目が多すぎて冗長になっていないか
- 重要な観点が漏れていないか

試用で「重すぎる」と感じた項目は削る（Issue 完了条件: 「重すぎる項目は削る」）。

!! GATE: Step 4 完了 — 試用結果の判定

- 過剰指摘（ノイズ化）がないか → Suppressions で抑制、または項目削除
- CRITICAL の指摘が本当に CRITICAL か → 誤分類があれば調整

### Step 5: 成果物の AI レビュー（概算: 15分）

完成したチェックリストに対して `so-compare` でセカンドオピニオンを取得する。プランどおりに作っても、意図した品質・網羅性になっているかは別問題。

- [ ] `so-compare -w "$(pwd)" "canonical/commands/review/pr-review-checklist.md のレビュー。2パス制の分類妥当性、Fix-First Heuristic の境界、Suppressions の網羅性、自スタック（PHP/Laravel, React/Vue）向けの具体例の十分性を検証してください"` を実行
- [ ] 重大な指摘があれば修正。軽微な指摘は試用（Step 4）の結果と合わせて判断

!! GATE: Step 5 — AI レビュー結果の判定

- 重大な構造的欠陥の指摘がないか
- 指摘への対処判断（修正 / 受容 / 保留）を記録

## ライセンス

- gstack リポジトリのライセンスを Step 0 で確認する
- チェックリストは「自スタック用に再構成」であり、gstack の項目をそのままコピペではない
- ファイル冒頭または末尾に出典帰属を記載: 「gstack (garrytan/gstack) の Pre-Landing Review Checklist を参考に自スタック向けに再構成」

## リスクと対処

| リスク | 影響 | 対処 |
|--------|------|------|
| チェック項目が多すぎてレビューが重くなる | レビュー時間増大、エージェントのコンテキスト消費増 | Pass 1 のみの「軽量モード」を用意。試用で削る |
| スタック固有の具体例が不足 | チェックが抽象的すぎて機能しない | 試用で具体例を追加。最初は薄く作り、実 PR レビューで育てる |
| AUTO-FIX の判断が甘く、不適切な自動修正が走る | コード品質低下 | AUTO-FIX のデフォルトを保守的に。迷ったら ASK に分類 |
| gstack のスタック固有表現がそのまま残る | 自スタックで使えないチェック項目がノイズになる | Step 1 GATE で確認。Rails/Python 固有の表現が残っていないか |

## 完了条件

- [ ] `canonical/commands/review/pr-review-checklist.md` が存在する
- [ ] 2パス制（CRITICAL / INFORMATIONAL）が定義されている
- [ ] Fix-First Heuristic（AUTO-FIX / ASK）が定義されている
- [ ] Suppressions（指摘すべきでないもの）が定義されている
- [ ] 出力フォーマットが定義されている
- [ ] `pr-review.md` Step 4 からチェックリストへの参照がある
- [ ] sync で配置される
- [ ] 実 PR で1回以上試用し、重すぎる項目は削っている
- [ ] 出典への帰属が記載されている

## スコープ外

- フック（`afterFileEdit`）によるリアルタイムチェック → #17
- Copilot Review との統合（`copilot-review-response.md` との連携）→ 別 Issue
- 自動テスト生成（Test Gaps 指摘から自動でテストを書く仕組み）→ Tier 3 以降

## Appendix: SO レビュー指摘事項（実装時に検討）

キックオフ文書に対する SO レビュー（2026-03-29、出力: `tmp/so-20260329-231410/`）で指摘された事項のうち、キックオフ修正ではなく **実装時に対応** するもの。

### A-1. 未判断カテゴリの明示（Codex High + Claude Medium）

gstack の以下のカテゴリが採用/除外表のどちらにも載っていない。Step 1 で明示的に判断する:
- Column/Field Name Safety
- Time Window Safety
- Distribution & CI/CD Pipeline
- Conditional Side Effects（Crypto & Entropy と統合とあるが、本体の扱いが不明確）

### A-2. CRITICAL → レビューアクションの接続（Codex, Medium）

「CRITICAL なら request-changes を原則」等の意思決定ルールが未定義。チェックリスト末尾またはフォーマット定義で明記する。

### A-3. N+1 AUTO-FIX の限定（Claude, Medium）

N+1 クエリの修正を SUGGESTED PATCH にする場合、「明らかなループ内クエリに限定」の注記が必要。意図的な lazy loading を壊すリスク。

### A-4. sync 確認の具体化（Codex, Medium）

Step 3 で `./scripts/sync.sh` ベースの実行コマンド・確認対象・成功条件を具体化する。

### A-5. 出力フォーマットの配置場所（Claude, Low-Med）

pr-review.md のどの位置（Step 4 末尾 or Step 5 前）にフォーマット定義を入れるか、Step 2 で具体化する。

### A-6. 正本宣言（Codex, Low）

pr-review.md の6行箇条書きとチェックリストの関係に「詳細ルールはチェックリストを正本とする」を明記し、将来のドリフトを防ぐ。

### A-7. エージェント間解釈ブレのリスク（Claude, nice-to-have）

同じチェック項目から Claude Code / Cursor / Codex で異なる指摘が出るリスク。試用で複数エージェントから実行し比較するとよい。

### A-8. copilot-review-response.md との将来統合（Claude, nice-to-have）

スコープ外と明記済みだが、将来統合時の方針（チェックリストが上位、Copilot 指摘はフィルタ対象とする等）を一言書いておくと安全。

## 参照

- [Issue #13](https://github.com/stlwolf/ai-development-hub/issues/13) — 本キックオフの対象
- [Epic #10](https://github.com/stlwolf/ai-development-hub/issues/10) — 親 Epic
- [Epic #10 補足コメント](https://github.com/stlwolf/ai-development-hub/issues/10#issuecomment-4150201176) — Tier 1 運用ルール
- [gstack](https://github.com/garrytan/gstack) — 出典リポジトリ
- `projects/orchestration-research/synthesis/harness-engineering-mapping.md` — ハーネス対応
- `canonical/commands/review/pr-review.md` — 変更対象
- `canonical/commands/review/copilot-review-response.md` — 関連（スコープ外だが将来連携候補）

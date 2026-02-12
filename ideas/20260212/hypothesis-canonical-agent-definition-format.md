# 仮説: エージェント定義の正準フォーマット

- 日付: 2026-02-12
- 性質: アイデアメモ。未検証。
- derived_from:
  - [棚卸しと次の一手 (2026-02-08)](../20260208/ai-orchestration-synthesis-next-steps.md) — 「契約で固定し、ツール名では固定しない」原則の具体化
  - [SIOS Tech Lab: Claude Codeのドキュメント検索を極力さぼれるようにした話](https://tech-lab.sios.jp/archives/51281) — サブエージェント定義とFrontmatterの実例

---

## 着想

サブエージェント/ルール系ドキュメントを持つサービスは複数あるが、意味的に同じ要素が繰り返し出てくる。ツール非依存の「正」の定義を1つ持ち、各ツール向けに変換すれば、ツール間の移植性と一貫性が担保できるのではないか。

---

## 各サービスの対応関係

| 要素 | Claude Code agents | Cursor rules | Copilot Skills | 意味 |
|------|-------------------|--------------|----------------|------|
| いつ発火するか | `description` | `globs` / `alwaysApply` | ファイル名推論 | トリガー条件 |
| 何をする役割か | 本文 `## 役割` | 本文 | `SKILL.md` 概要 | 役割定義 |
| 何をしないか | `## 制約事項` | 本文 | 本文 | ガードレール |
| 使えるツール | `tools: [Read, Grep]` | （暗黙的） | （暗黙的） | 能力の範囲 |
| ドメイン知識 | 本文注入 | 本文注入 | 本文注入 | 文脈/前提 |
| 出力形式 | `## 出力形式` | 本文 | 本文 | 応答の構造 |

---

## 正準フォーマット案（素案）

```yaml
---
name: "second-opinion-reviewer"
trigger:
  description: "レビュー結果に反証が必要なとき、セカンドオピニオンを取りたいとき"
  patterns: ["**/reviews/**", "**/decisions/**"]
role: "反証担当。見落とし・破壊的変更・将来負債を指摘する"
constraints:
  - "ファイルの編集はしない（読み取り専用）"
  - "対象スコープ外の指摘はしない"
tools: [Read, Grep, Glob]
model_preference: fast
domain_context:
  - ref: "docs/decisions/"
    note: "確定した判断の履歴"
  - ref: "docs/episodes/"
    note: "議論経緯（必要時のみ参照）"
output_format: "markdown table with verdict and reasoning"
---

# Second Opinion Reviewer

（本文: 詳細な指示、検索戦略、検索パターン等）
```

---

## 変換先のイメージ

- → `.claude/agents/second-opinion-reviewer.md`（YAML frontmatter + Markdown）
- → `.cursor/rules/second-opinion.mdc`（Cursor形式）
- → `AGENTS.md` の該当セクションに追記

変換自体はテンプレート1枚で済む程度の差分。

---

## 検証するなら

- 1つのエージェント定義を正準フォーマットで書き、Claude Code用とCursor用に手動変換してみる
- 変換コストと、定義の一貫性維持コストを比較する
- 「正準フォーマットがあって助かった」場面が出るかを観察する

---

## 優先度

低。DOCUMENT_CONVENTION.md の運用が安定し、エージェント定義を複数ツールで管理する実需が出てから着手する。今はメモとして残しておく。

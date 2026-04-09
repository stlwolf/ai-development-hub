# スキル description トリガー eval の実践知見

## 概要

skill-creator の `run_eval.py` / `run_loop.py` を使ってスキル description のトリガー精度を定量評価した際の知見をまとめる。

## eval フレームワークの仕組み

skill-creator の Description Optimization は以下の流れで動作する:

1. `[{"query": "...", "should_trigger": true/false}]` 形式の eval セットを作成
2. `run_eval.py` が `.claude/commands/` に一時コマンドファイルを作成
3. `claude -p` で各クエリを投げ、スキルが参照（Skill ツール or Read）されたかを検出
4. should-trigger / should-not-trigger の pass rate を算出

```bash
# 単発評価
PYTHONPATH="$SKILL_CREATOR_PATH" python3 -m scripts.run_eval \
  --eval-set path/to/trigger-eval.json \
  --skill-path path/to/skill \
  --model claude-sonnet-4-6 \
  --runs-per-query 1 \
  --timeout 30 \
  --verbose

# 自動最適化ループ（anthropic SDK 必要）
PYTHONPATH="$SKILL_CREATOR_PATH" python3 -m scripts.run_loop \
  --eval-set path/to/trigger-eval.json \
  --skill-path path/to/skill \
  --model claude-sonnet-4-6 \
  --max-iterations 5 \
  --verbose
```

## 制約: 単純クエリ問題

**Claude は自力で処理可能な単純タスクではスキルを参照しない。** これは skill-creator のドキュメントにも明記されている:

> "Claude only consults skills for tasks it can't easily handle on its own — simple, one-step queries like 'read this PDF' may not trigger a skill even if the description matches perfectly"

### 実測結果（2026-04-09）

5スキルの description を改善し、before/after で `run_eval.py` を実行した結果:

| スキル | before | after | 変化 |
|--------|--------|-------|------|
| worktrunk-worktrees | trigger 0/5 | trigger 0/5 | なし |
| implementer-contract | trigger 0/5 | trigger 0/5 | なし |
| spec-card | trigger 0/5 | - | - |
| persistent-exploration | trigger 0/5 | - | - |
| adversarial-review | trigger 0/5 | - | - |

全スキルで should-not-trigger は 5/5 pass（false positive なし）。should-trigger が全滅。

### 原因分析

eval クエリが「worktree を掃除したい」「kickoff ドキュメントを作りたい」等の単純な依頼文だったため、Claude が直接ツール（Bash, Write 等）で処理しようとし、スキルを参照しなかった。

## eval クエリ設計のベストプラクティス

skill-creator ドキュメントから抽出した有効なクエリの特徴:

### 良いクエリ

- **具体的な文脈を含む**: ファイルパス、会社名、個人的状況
- **マルチステップ**: 複数の判断・手順が必要
- **カジュアル/略語あり**: 実際のユーザー入力を模倣
- **長さが多様**: 1行〜段落まで混在

```
悪い例: "worktree を作成して"
良い例: "Issue #42 のバグ修正を始めたいんだけど、今 feature/#38 の作業中で
        そっちも途中。並列で進めたいから別の worktree で作業開始して、
        ブランチ名は規約に従って。あと前に使ってた古い worktree が3つくらい
        残ってるはずだからついでに掃除もしたい"
```

### should-not-trigger（negative eval）の設計

- **overlap 相手を必ず含める**: 隣接スキルのトリガーケースを negative に入れる
- **near-miss を重視**: キーワードは共有するが別スキルが適切なケース

| スキル | overlap 相手 |
|--------|-------------|
| worktrunk-worktrees | branch-naming（命名のみ） |
| implementer-contract | 一般タスク分解、調査委譲 |
| spec-card | kickoff-to-plan、一般ドキュメント |
| persistent-exploration | sentry-investigation（初期取得） |
| adversarial-review | pr-review、so-compare |

## description 改善パターン

高精度スキル（pr-conventions, branch-naming, conventional-commits）から抽出したパターン:

```
文1: トリガー条件（ユーザーの行動/意図）
文2: 具体的キーワード（ツール名、CLIコマンド、ワークフロー段階）
文3: 内容要約（スキルが含むもの）
```

- **長さ目安**: 120-140文字（高精度スキルは100-110文字）
- **トリガー判定に寄与しない情報**（Cursor UI 制約等）は本文に残す
- **内部概念リード → トリガー条件リード** に転換する

## 前提条件

- `run_loop.py` は `anthropic` Python SDK が必要（`pip install anthropic`）
- `run_eval.py` は `claude` CLI のみで動作（SDK 不要）
- skill-creator 本体: `~/.claude/plugins/cache/claude-plugins-official/skill-creator/`

## 参考

- [skill-create スキル作成と改善](https://azukiazusa.dev/en/blog/skill-create-skill-creation-and-improvement/)
- skill-creator SKILL.md の Description Optimization セクション

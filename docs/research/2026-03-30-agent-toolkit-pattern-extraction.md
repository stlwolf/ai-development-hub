---
title: "softaworks/agent-toolkit パターン抽出: 流用可能な設計概念とメタ評価基準"
date: 2026-03-30
status: research-complete
tags: [agent-skills, skill-design, session-handoff, meta-evaluation, workflow-orchestration]
sources:
  - https://github.com/softaworks/agent-toolkit
  - https://github.com/softaworks/agent-toolkit/tree/main/skills/skill-judge
  - https://github.com/softaworks/agent-toolkit/tree/main/skills/session-handoff
  - https://github.com/softaworks/agent-toolkit/tree/main/skills/gepetto
next_step: 個別パターンの自環境への適用判断（必要時に参照）
---

# softaworks/agent-toolkit パターン抽出

## 動機

softaworks/agent-toolkit（Stars 1,285, MIT, 主に Claude Code 向け37スキル集）を評価した結果、丸ごと採用は不適（構造思想の違い: Rules層なし・単一ツール前提）だが、3つのスキルに流用可能な設計パターン・メタ概念がある。本ドキュメントはそれらの本質的要素を抽出・整理する。

### 前提認識

> 汎用スキルセットは「ライブラリ」にはなれない。確率論に支配されるプロンプトである以上、どんなスキルも個別環境での検証なしに100%の有用性は保証できない。他者のスキルセットから取るべきは「コンテンツそのもの」ではなく「本質的な設計パターンとメタ的観点」。

---

## 1. skill-judge: スキル設計のメタ評価基準

### ソース

[`skills/skill-judge/SKILL.md`](https://github.com/softaworks/agent-toolkit/blob/main/skills/skill-judge/SKILL.md)（約750行、references なし、自己完結型）

### 本質的概念

#### Knowledge Delta 公式

```
Good Skill = Expert-only Knowledge − What Claude Already Knows
```

スキルの価値は「知識差分」で測定される。モデルが既に知っていることを書くのはトークンの浪費。

#### 知識の3分類

| 分類 | 定義 | 扱い |
|------|------|------|
| **Expert** | モデルが本当に知らない知識 | 保持必須 — スキルの価値そのもの |
| **Activation** | モデルは知っているが想起しない知識 | 簡潔なら保持 — リマインダーとして機能 |
| **Redundant** | モデルが確実に知っている知識 | 削除すべき — トークン浪費 |

理想比率: Expert 70%+、Activation 20%未満、Redundant 10%未満

#### 8次元評価フレームワーク（120点満点）

| 次元 | 配点 | 核心 |
|------|------|------|
| D1: Knowledge Delta | 20 | 最重要。純粋な知識差分の量と質 |
| D2: Mindset + Procedures | 15 | 思考パターンの移植 + ドメイン固有手順（汎用手順は価値なし） |
| D3: Anti-Pattern Quality | 15 | 具体的な NEVER リスト + 非自明な理由 |
| D4: Specification（特に description） | 15 | description がスキル起動の唯一のトリガー |
| D5: Progressive Disclosure | 15 | 3層構造（メタデータ→本体→参照資料）の適切な分離 |
| D6: Freedom Calibration | 15 | タスクの脆弱性に応じた自由度の調整 |
| D7: Pattern Recognition | 10 | 5つの設計パターン（Mindset/Navigation/Philosophy/Process/Tool）への適合 |
| D8: Practical Usability | 15 | 決定木・フォールバック・エッジケースの網羅 |

#### 9つの失敗パターン

| パターン | 症状 | 根本原因 |
|----------|------|----------|
| The Tutorial | 基本概念の説明 | モデルに「教える」必要があると思い込む |
| The Dump | SKILL.md 800行超 | Progressive Disclosure の欠如 |
| The Orphan References | 参照資料が読み込まれない | 明示的な読み込みトリガーがない |
| The Checkbox Procedure | Step 1, 2, 3 の機械的手順 | 思考フレームワークではなく手順で考えている |
| The Vague Warning | 「気をつけて」「エラーに注意」 | 具体的な失敗経験を言語化していない |
| The Invisible Skill | 良い内容なのに起動されない | description が曖昧 |
| The Wrong Location | 「いつ使うか」が本文にある | 3層ローディングの誤解（description のみが起動前に見える） |
| The Over-Engineered | README, CHANGELOG, CONTRIBUTING 等 | スキルをソフトウェアプロジェクトのように扱う |
| The Freedom Mismatch | 創造的タスクに厳格なスクリプト | タスクの脆弱性を考慮していない |

#### 自環境への適用観点

- **自作スキルの品質チェック**: Knowledge Delta 比率の自己評価に使える
- **description 設計**: WHAT / WHEN / KEYWORDS の3要素チェックリストは Claude Code / Cursor 両方で有効
- **Freedom Calibration**: ai-development-hub の rules（低自由度）と skills（中〜高自由度）の設計指針として参考になる
- **メタ質問**: 「この知識は、自分が数年かけて学んだことか？」がスキル設計の最終判定基準

---

## 2. session-handoff: コンテキスト枯渇への体系的対策

### ソース

- [`skills/session-handoff/SKILL.md`](https://github.com/softaworks/agent-toolkit/blob/main/skills/session-handoff/SKILL.md)（約200行）
- [`scripts/create_handoff.py`](https://github.com/softaworks/agent-toolkit/blob/main/skills/session-handoff/scripts/create_handoff.py)
- [`scripts/check_staleness.py`](https://github.com/softaworks/agent-toolkit/blob/main/skills/session-handoff/scripts/check_staleness.py)
- [`scripts/validate_handoff.py`](https://github.com/softaworks/agent-toolkit/blob/main/skills/session-handoff/scripts/validate_handoff.py)

### 本質的概念

#### 鮮度チェック（Staleness Scoring）

ハンドオフ文書の「まだ使えるか」を定量評価する仕組み。

**スコアリング要素:**

| 要素 | 閾値 | 加点 | 根拠 |
|------|------|------|------|
| 経過日数 | >1d: +1, >7d: +2, >30d: +3 | 0-3 | 1日=アクティブ、7日=スプリント境界、30日=陳腐化 |
| コミット数 | >5: +1, >20: +2, >50: +3 | 0-3 | 5=ルーチン、20=フィーチャー、50=大規模変更 |
| ブランチ不一致 | 不一致: +2 | 0-2 | 異なるブランチ=異なるコンテキスト |
| 参照ファイル消失 | >0: +1, >5: +2 | 0-2 | 参照切れ=コードベース再構成 |
| 変更ファイル数 | >5: +1, >20: +2 | 0-2 | 5=局所的、20=広範な変更 |

**判定:**
- 0点: FRESH — 安全に再開可能
- 1-2点: SLIGHTLY_STALE — 変更をレビューしてから再開
- 3-4点: STALE — コンテキストを慎重に検証
- 5点以上: VERY_STALE — 新規ハンドオフ作成を推奨

#### ハンドオフチェーン

```
handoff-1.md (初回作業)
    ↓ --continues-from
handoff-2.md (続行)
    ↓ --continues-from
handoff-3.md (さらに続行)
```

各ハンドオフが前のものにリンクし、コンテキストのパンくずリストを形成する。新エージェントは最新のハンドオフから読み、必要に応じて遡及参照する。

#### バリデーション（品質スコアリング）

| チェック項目 | 減点 | 理由 |
|-------------|------|------|
| TODO プレースホルダー残存 | -30 | 未完成 = 次のエージェントに重要情報が欠落 |
| 必須セクション欠落 | -10/セクション | コンテキスト継続に必須 |
| シークレット検出 | -20 | セキュリティリスク（ハンドオフは共有・保存される可能性） |
| 参照ファイル消失 | -5/ファイル（上限-20） | 陳腐な参照 |
| 推奨セクション欠落 | -2/セクション | あれば望ましい |

必須セクション: Current State Summary, Important Context, Immediate Next Steps

**シークレット検出パターン（13種）:** API key, Password, Secret, Token, Private key, PEM, MongoDB/PostgreSQL/MySQL接続文字列, Bearer token, GitHub PAT, OpenAI key, Slack token

#### 自環境への適用観点

- **鮮度スコアリングのロジック**: ai-development-hub の memory システムや将来的なセッション管理に応用可能。閾値とスコアリングの考え方が具体的で参考になる
- **チェーン機構**: 長期プロジェクトでのコンテキスト継続パターン。現在の auto memory とは異なるアプローチ（ファイルベース vs メモリインデックス）
- **シークレット検出の正規表現セット**: バリデーションツールに流用可能（Python → Bash 変換も容易）
- **ストレージ規約**: `.claude/handoffs/YYYY-MM-DD-HHMMSS-[slug].md` の命名規則は明快

---

## 3. gepetto: 長大ワークフローのステート再開パターン

### ソース

[`skills/gepetto/SKILL.md`](https://github.com/softaworks/agent-toolkit/blob/main/skills/gepetto/SKILL.md)（約300行、references/ に4ファイル）

### 本質的概念

#### ファイル存在チェックによるステート検出

17ステップのワークフローで、各ステップの成果物ファイルの存在有無から「どこまで完了しているか」を自動判定する。

```
ファイルなし        → Step 4 から開始（新規）
research のみ       → Step 6 から再開（interview）
research + interview → Step 8 から再開（spec synthesis）
+ spec              → Step 9 から再開（plan）
+ plan              → Step 10 から再開（external review）
+ reviews           → Step 11 から再開（integrate）
+ integration-notes → Step 12 から再開（user review）
+ sections/index.md → Step 14 から再開（write sections）
全 section 完了     → Step 15 から再開（execution files）
全ファイル揃い     → 完了
```

**設計のポイント:**
- 外部状態管理（DB、JSON）を使わず、**成果物ファイルそのものが状態**
- 再開時に「前回どこまでやったか」を人間に聞かない — ファイルシステムが答える
- 冪等性: 同じステップを再実行しても成果物が上書きされるだけ

#### サブエージェント並列パターン

- Step 10（外部レビュー）: Gemini + Codex を並列起動
- Step 14（セクション分割）: セクション数分のサブエージェントを並列起動
- 原則: 「単一メッセージで複数の Task を起動」して並列実行

```
# 1メッセージで全セクションを並列起動
Task(subagent_type="general-purpose", prompt="Write section-01...")
Task(subagent_type="general-purpose", prompt="Write section-02...")
Task(subagent_type="general-purpose", prompt="Write section-03...")
```

#### 自己完結型セクションの設計原則

各セクションファイルは「それだけ読めば実装できる」自己完結文書として設計される:
- Background（なぜこのセクションが存在するか）
- Requirements（完了条件）
- Dependencies（依存関係）
- Implementation details（計画からの詳細）
- Acceptance criteria（チェックボックス）
- Files to create/modify

#### 自環境への適用観点

- **ファイル存在ベースのステート管理**: `kickoff-to-plan` や長時間ワークフロースキルで応用可能。外部状態管理より堅牢で可視性が高い
- **並列サブエージェント起動**: `subagent-strategy-rule` と整合するパターン。「1メッセージ複数Task」の明示的な記述は参考になる
- **自己完結セクション設計**: 大きな計画を分割する際の品質基準として有用

---

## 総合所感

### 流用すべきもの

| 概念 | 何を | どう使うか |
|------|------|-----------|
| Knowledge Delta 公式 | スキル設計の判断基準 | 新スキル作成時の自問チェックリストとして |
| description の WHAT/WHEN/KEYWORDS | スキルのトリガー設計 | 全スキルの description レビューに適用 |
| Staleness スコアリング | コンテキスト鮮度の定量評価 | セッション管理・ハンドオフ検討時の参考 |
| ファイル存在ベースのステート管理 | 長大ワークフローの再開 | ワークフロースキルの設計パターンとして |
| シークレット検出正規表現 | バリデーションツール | validate 系スクリプトへの流用 |

### 流用しないもの

- gepetto の具体的なワークフロー（ralph-loop / ralphy 連携は自環境に無関係）
- session-handoff の Python スクリプトそのもの（Bash ベースの自環境とは技術選択が異なる）
- skill-judge の評価プロトコル全体（形式的すぎる。Knowledge Delta 公式と失敗パターンのみで十分）

### 根底にある共通の洞察

> 確率論に支配されるプロンプトの世界では、**「何を書くか」より「何を書かないか」**の方が重要。トークンは有限のパブリックリソースであり、モデルが既に知っていることを繰り返すのは、コンテキストウィンドウという共有資源の浪費にほかならない。

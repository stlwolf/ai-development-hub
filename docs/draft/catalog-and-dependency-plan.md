# スキル・コマンド目録と依存関係管理

## 背景と課題

`canonical/` 配下のリソース（skills, commands, agents, rules, hooks）は、Cursor / Claude Code / Codex の3ツール横断で使う共通基盤として整備が進んでいる。

現時点の構成:

```
canonical/
├── rules/          # 常時有効な行動原則（8ファイル）
├── skills/         # 重い手順書・専門ワークフロー（十数個）
├── commands/       # タスク実行手順（数個）
├── agents/         # サブエージェント役割定義（3個）
├── hooks/          # 機械的ガードレール（2スクリプト + 3ツール分の設定）
├── codex/          # Codex専用拡張レイヤー
├── cursor/         # Cursor専用ファイル
└── mcp/            # MCP設定
```

### 顕在化している問題

1. **全体像の把握が困難になりつつある**: スキル・コマンドの数が「人間が暗記で管理できる上限」を超え始めている。AI がコンテキスト読み込みの起点にする際にも、何が存在するかの一覧がない
2. **スキル間の依存関係が暗黙的**: `peer-ai-review` が `so-compare`, `persistent-exploration`, `adversarial-review` を条件付きで参照する等、スキル間の依存はスキル本文中の `Read ~/.cursor/skills/xxx` や「〜スキルを参照」という散文記述でしか表現されていない
3. **影響範囲の把握が困難**: あるスキルを変更・削除したとき、何に影響するかを知るには全ファイルを grep する必要がある

### なぜ今対処するか

- 現在の規模（十数スキル、数コマンド）なら手作業で対処可能。100を超えてからでは遡及コストが高い
- 将来のオーケストレーター実装時に、タスクに応じたスキル自動選択・注入の仕組みが必要になる。その時のインプットとして `depends` 宣言が整備されていれば移行がスムーズ
- クライアントワークへの展開時に、基盤の全体像を素早く共有できる手段が必要

---

## 今やること（2つ）

### 1. インデックス README の作成

canonical/ のトップレベルまたは各ディレクトリに、スキル・コマンド・エージェントの一覧を記載した README を作成する。

**目的:**
- 人間が全体像を思い出すための目録
- AI がコンテキスト読み込みの起点にするためのエントリポイント

**内容（各エントリごとに）:**
- 名前
- 一行説明（何をするか）
- ファイルパス
- カテゴリ（skill / command / agent / hook）

**形式:** 手書き Markdown。現在の規模なら手動更新で十分正確に保てる。

**配置候補:**
- `canonical/CATALOG.md`（全リソース横断の単一目録）
- または各ディレクトリの README に分散（`canonical/skills/README.md` 等）

**判断基準:** AI のコンテキスト読み込みを考えると、1ファイルに集約した方が1回の Read で全体像が取れる。ただし行数が膨れる場合は分散も許容。

### 2. frontmatter に `depends` フィールドを追加

各 SKILL.md / command MD の YAML frontmatter に、依存するスキル・コマンドを明示宣言する。

**現在の frontmatter（例: peer-ai-review）:**
```yaml
---
name: peer-ai-review
description: 修正タスクや設計判断に対して...
---
```

**追加後:**
```yaml
---
name: peer-ai-review
description: 修正タスクや設計判断に対して...
depends:
  - skill: so-compare              # 必須: セカンドオピニオン取得
  - skill: persistent-exploration  # 条件付き: 探索モード時
  - skill: adversarial-review      # 条件付き: Compliance Review時
  - skill: implementer-contract    # 参照: サブエージェント委譲時の返却契約
  - cli: so-compare                # CLI実行: ~/bin/so-compare
  - command: arena-perspectives    # 参照: 修正方針検証時
---
```

**種別（type）の定義:**

| 種別 | 対象 | パス規約 |
|------|------|---------|
| `skill` | スキル定義 | `canonical/skills/{name}/SKILL.md` |
| `command` | コマンド定義 | `canonical/commands/**/{name}.md` |
| `agent` | エージェント定義 | `canonical/agents/{name}.md` |
| `cli` | 外部CLIツール | `~/bin/{name}` 等。canonical 管理外の実行バイナリ・スクリプト |
| `rule` | ルール定義 | `canonical/rules/{name}.md` |

**skill と cli の区別:** 同名のスキルと CLI が存在する場合（例: `so-compare` には SKILL.md と `~/bin/so-compare` の両方がある）、参照している方を書く。スキルの手順書を読んでいるなら `skill`、CLI を直接実行しているなら `cli`。両方参照している場合は両方書く。

**抽出方法:** 各ファイルの本文中の以下のパターンから依存先と種別を機械的に特定できる:

| パターン | 種別 |
|---------|------|
| `Read ~/.cursor/skills/xxx/SKILL.md` | `skill` |
| `canonical/skills/xxx/SKILL.md` | `skill` |
| `canonical/commands/xxx/yyy.md` | `command` |
| `canonical/agents/xxx.md` | `agent` |
| `canonical/rules/xxx.md` | `rule` |
| `arena-compare -w ...` / `so-compare -w ...` 等のCLI実行 | `cli` |
| 「〜スキルを参照」「〜スキルの行動制約テンプレートを注入」等の散文参照 | `skill`（文脈から判断） |

**注意:** `depends` は canonical 独自のフォーマット拡張であり、Cursor / Claude Code / Codex のいずれもこのフィールドを解釈しない。自前のスクリプト（整合チェック、カタログ生成等）が消費する独自メタデータとして位置づける。

**整合チェック（将来のスクリプト化候補）:**
- 宣言された依存先が実在するか（種別に応じたパス規約で解決）
- 種別が正しいか（`skill` と宣言されているものが `canonical/skills/` に存在するか等）
- 本文に `Read` や参照があるのに `depends` に未宣言のスキルがないか（逆方向チェック）
- 循環依存がないか

---

## 将来の拡張（今はやらない）

### カタログ自動生成スクリプト

スキル・コマンドの数が手書き更新で管理しきれなくなった段階（目安: 30-50以上）で、frontmatter をパースしてカタログ MD を自動生成するスクリプトを作成する。

**生成物:**
- 名前・説明・depends・依存元（逆引き）・ファイルパスの一覧表
- 整合チェック結果（`check-codex-guardrails.sh` と同系統）

**前提:** Step 2 の `depends` 宣言が整備済みであること。

### C4 モデルによる構造図示

スキル依存のフラットグラフではなく、C4 モデルの階層的ズームを採用して canonical 基盤の構造を図示する。

**C4 → canonical のレベルマッピング:**

| C4 Level | canonical での対象 | 用途 |
|----------|-------------------|------|
| **Level 1: System Context** | canonical 基盤全体と外部ツール（Cursor / Claude Code / Codex / 人間）の関係 | 全体像の共有。クライアントへの説明、新しい AI ツール追加時の位置づけ確認 |
| **Level 2: Container** | canonical 内の層構造（rules / skills / commands / agents / hooks）と sync/配布の流れ | 各層の責務と、どのツールに何が配布されるかの理解 |
| **Level 3: Component** | 個別スキル・コマンドレベルの依存関係 | スキル変更時の影響範囲把握。オーケストレーターのスキル選択ロジックの入力 |
| **Level 4: Code** | 個別スキル内部の詳細（frontmatter構造、変換ルール等） | 必要時のみ掘り下げ |

**Level 3 が依存グラフの可視化に直接対応する。** Level 1-2 は変更頻度が低いため手書きで十分。Level 3 はカタログの `depends` データから自動生成できる。

**C4 を採用する利点:**
- Mermaid フラットグラフと異なり、ズームレベルの概念があるため、ノード数が増えても可読性を維持できる
- AI エージェントにコンテキストを渡す際、「今どのレベルの話をしているか」を明示的にできる
- オーケストレーター実装時に、サブエージェントへ渡すコンテキストの粒度制御と C4 レベルが対応する
- notation independent（記法非依存）のため、Mermaid C4 拡張でも Structurizr DSL でも実装できる

**レンダリング手段の候補:**
- Mermaid C4 拡張（`C4Context`, `C4Container` 等）— GitHub 上でそのまま表示可能
- Structurizr DSL + Structurizr Lite — C4 作者のツール。DSL でモデル定義、複数レベル図を自動生成
- 手書き Markdown テーブル + 簡易 Mermaid — 最も軽量。ツール依存なし

### オーケストレーターとの統合

将来のオーケストレーター実装時に、`depends` 宣言は以下の用途で消費される:

- **タスク → スキル解決:** タスクの種類からどのスキルを注入すべきか自動判定。種別によって注入方法が変わる（`skill` はプロンプト注入、`cli` は実行パス確認、`agent` はサブエージェント起動）
- **サブエージェントのロール構成:** `depends` のグラフを辿り、必要なスキルセットを動的に合成。種別が明示されていることで、スキル（読む）と CLI（実行する）の区別がオーケストレーターの判断に使える
- **前提条件チェック:** `cli` 依存が宣言されていれば、タスク実行前に CLI の存在確認を自動で行える
- **コンテキスト予算の見積もり:** 依存の深さと種別からコンテキスト消費量を事前推定（`skill` はコンテキスト消費、`cli` は消費しない等）

**参考 OSS（スキルセット動的合成アプローチ）:**
- **Semantic Kernel (Microsoft):** Plugin を動的にカーネルに注入し、プランナーがタスクに応じて使うプラグインセットを選択。canonical/skills の粒度・合成の考え方に最も近い
- **AutoGen (Microsoft):** ConversableAgent の register_for_llm / register_for_execution でツールを動的着脱
- **CrewAI:** Agent に tools リストを渡す形でロールごとのスキルセットを構成

---

## 作業の依存関係

```
[Step 1: インデックス README] ──独立──→ 完了
                                          ↓（将来）
[Step 2: frontmatter depends] ──独立──→ 完了
                                          ↓（将来）
                              [カタログ自動生成スクリプト]
                                          ↓
                              [C4 Level 3 図の自動生成]
                                          ↓
                              [オーケストレーターのスキル解決]
```

Step 1 と Step 2 は独立して並行着手可能。将来の拡張は全て Step 2（`depends` 宣言）が前提になる。

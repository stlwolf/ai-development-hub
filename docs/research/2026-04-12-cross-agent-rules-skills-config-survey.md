---
title: "Cursor / Claude Code / Codex ルール・スキル・設定読み込み仕様の3ツール比較調査"
date: 2026-04-12
status: research-complete
tags: [cross-agent, cursor, claude-code, codex, rules, skills, configuration, harness-engineering]
sources:
  - https://code.claude.com/docs/en/memory
  - https://code.claude.com/docs/en/claude-directory
  - https://code.claude.com/docs/en/skills
  - https://code.claude.com/docs/en/settings
  - https://code.claude.com/docs/en/plugins-reference
  - https://code.claude.com/docs/en/context-window
  - https://developers.openai.com/codex/guides/agents-md
  - https://developers.openai.com/codex/config-reference
  - https://developers.openai.com/codex/config-advanced
  - https://developers.openai.com/codex/skills/
  - https://developers.openai.com/codex/plugins/
  - https://developers.openai.com/codex/learn/best-practices
  - https://cursor.com/docs/rules
  - https://cursor.com/docs/skills
  - https://cursor.com/docs/subagents
  - https://cursor.com/docs/hooks
related_issues:
  - https://github.com/stlwolf/ai-development-hub/issues/58
  - https://github.com/stlwolf/ai-development-hub/issues/38
next_step: Phase 1 × Core Canonical 診断の入力として使用
---

# Cursor / Claude Code / Codex ルール・スキル・設定読み込み仕様の3ツール比較調査

## 要約

3ツールとも「Markdownベースの指示ファイル + スキルの Progressive Disclosure」という基本アーキテクチャを共有するが、読み込みメカニズム・スコープ階層・サイズ制限・コンパクト時の生存ルールに大きな差異がある。Claude Code は CLAUDE.md を長さに関わらず全文ロードし `.claude/rules/` で分割管理する。Codex は AGENTS.md をルートから CWD へ連結し合計 32 KiB で打ち切る。Cursor は `.mdc` の frontmatter（`alwaysApply` / `globs` / `description`）で適用条件を細かく制御する。スキルは3ツールとも `SKILL.md` + YAML frontmatter だが、ディスカバリパスが `.claude/skills/` vs `.agents/skills/` vs `.cursor/skills/`（+ 互換パス）と分かれ、トークン制限も Claude Code のみ明示（スキルあたり 5,000 / 合計 25,000 トークン）。canonical/ を3ツールに展開する際の主要な設計制約は、Codex の 32 KiB 上限、Cursor の `alwaysApply` 要件、Claude Code のコンパクト生存ルールの3点である。

## 比較総覧

### ルール相当物の配置と読み込み


| 項目 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| **主ファイル形式** | `.mdc`（frontmatter 付き MD） | `CLAUDE.md`（Markdown） | `AGENTS.md`（Markdown） |
| **プロジェクトスコープ** | `.cursor/rules/*.mdc` | `./CLAUDE.md` or `./.claude/CLAUDE.md` | リポルートから CWD までの各ディレクトリの `AGENTS.md` |
| **ユーザースコープ** | Cursor Settings > Rules | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |
| **組織スコープ** | Team Rules（ダッシュボード管理） | Managed policy（OS 固定パス） | `requirements.toml`（admin-enforced）/ Business・Enterprise は cloud-fetched requirements |
| **ローカル上書き** | -（記載なし） | `./CLAUDE.local.md`（`.gitignore` 推奨） | `AGENTS.override.md`（各ディレクトリ） |
| **サブディレクトリ** | `.cursor/rules/` 内でフォルダ分割可 | ネストした `CLAUDE.md`（サブディレクトリ） | ルートから CWD への各ディレクトリで探索 |
| **分割ファイル** | `.cursor/rules/` に複数 `.mdc` | `.claude/rules/*.md`（再帰、symlink 可） | -（単一 `AGENTS.md` per ディレクトリ） |
| **優先順位** | Team > Project > User | Managed > CLI args > Local > Project > User | Global → ルートから CWD へ連結（CWD に近いほど優先） |
| **マージ方式** | マージ（衝突時は上位が優先） | 連結（全階層を結合） | 連結（空白行で結合） |
| **サイズ制限** | 500 行未満推奨（ハード上限なし） | 長さに関わらず全文ロード（200 行未満推奨） | 合計 `project_doc_max_bytes`（既定 32 KiB） |
| **AGENTS.md 対応** | プロジェクトルート + サブディレクトリ対応 | `@AGENTS.md` import で CLAUDE.md 内から参照可能 | ネイティブ |
| **`.cursorrules` 対応** | Legacy 対応（`.mdc` が優先） | -（記載なし） | -（記載なし） |


### ルールの適用条件と粒度


| 項目 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| **常時適用** | `alwaysApply: true` で毎チャット適用 | `paths` なしのルール/CLAUDE.md は毎セッション無条件ロード | AGENTS.md は作業前に一度読み込み |
| **ファイルパス条件** | `globs` frontmatter（例: `**/*.py`） | `paths` frontmatter（glob 複数指定可） | -（AGENTS.md はディレクトリ単位） |
| **説明ベース自動適用** | `description` で Agent が関連性を判断 | -（ルールの `description` は記載なし） | -（記載なし） |
| **`alwaysApply: false` の挙動** | Agent に description を提示し適用可否を判断させる | -（`paths` の有無で二分） | -（N/A） |
| **コンパクト後の生存** | -（記載なし） | プロジェクトルート CLAUDE.md + ユーザー CLAUDE.md は再注入（公式確認）。unscoped rules も再注入（推定）。スキル本文は自動 re-attach（5,000/25,000 tok）。`paths` 付きルール・ネスト CLAUDE.md は再読みまで失われる | -（記載なし） |
| **override 機構** | Team Rules が全ルールに優先 | `CLAUDE.local.md` が同ディレクトリ CLAUDE.md の後に連結 | `AGENTS.override.md` が `AGENTS.md` より先にチェックされ、存在すれば AGENTS.md は読まれない |


### スキルの定義と読み込み


| 項目 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| **定義ファイル** | `SKILL.md`（YAML frontmatter） | `SKILL.md`（YAML frontmatter） | `SKILL.md`（YAML frontmatter） |
| **必須フィールド** | `name`, `description` | 全フィールド optional（`description` recommended） | `name`, `description` |
| **プロジェクトパス** | `.cursor/skills/`, `.agents/skills/` | `.claude/skills/` | `.agents/skills/`（CWD からルートへ上方向スキャン） |
| **ユーザーパス** | `~/.cursor/skills/` | `~/.claude/skills/` | `~/.agents/skills/` |
| **システムパス** | -（記載なし） | Enterprise（managed settings） | `/etc/codex/skills/`, システム同梱 |
| **互換パス** | `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/` | -（記載なし） | -（記載なし） |
| **ロード方式** | 自動発見 + Agent が文脈判断、`/` で手動 | description は常時コンテキスト（ただし `disable-model-invocation: true` のスキルは description も非表示）、本文は呼び出し時にフルロード（lazy） | Progressive disclosure: メタデータのみ → 使用決定時にフルロード |
| **明示起動** | `/` からスキル名検索 | `/skill-name` スラッシュコマンド | `/skills` or `$` で言及 |
| **暗黙起動の制御** | -（記載なし） | `disable-model-invocation: true` で無効化 | `agents/openai.yaml` の `policy.allow_implicit_invocation: false` |
| **トークン制限（per-skill）** | -（記載なし） | コンパクト後再付与: 5,000 トークン | -（記載なし） |
| **トークン制限（total）** | -（記載なし） | コンパクト後再付与: 25,000 トークン | -（記載なし） |
| **description 表示制限** | -（記載なし） | 一覧で 250 文字に切り詰め、コンテキストの 1% をバジェット（フォールバック 8,000 文字） | -（記載なし） |
| **commands との関係** | -（記載なし） | `.claude/commands/foo.md` と `.claude/skills/foo/SKILL.md` は同じ `/foo`。同名ならスキル優先 | -（記載なし） |


### 設定ファイル


| 項目 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| **正本ファイル** | Cursor Settings（GUI）+ `settings.json` | `settings.json`（JSON） | `config.toml`（TOML） |
| **プロジェクトスコープ** | `.vscode/settings.json` | `.claude/settings.json` | `.codex/config.toml` |
| **ユーザースコープ** | `~/Library/Application Support/Cursor/User/settings.json` | `~/.claude/settings.json` | `~/.codex/config.toml` |
| **ローカル上書き** | -（記載なし） | `.claude/settings.local.json`（`.gitignore` 推奨） | -（記載なし） |
| **組織スコープ** | Team/Enterprise ダッシュボード | Managed settings（MDM / サーバ配信） | `requirements.toml`（admin-enforced）/ cloud-fetched requirements |
| **優先順位** | Team > Project > User | Managed > CLI args > Local > Project > User | ユーザー → プロジェクト（CWD に近いほど優先）。信頼されていないプロジェクトでは `.codex/config.toml` 無視 |
| **スキーマ** | -（記載なし） | `json.schemastore.org/claude-code-settings.json` | `developers.openai.com/codex/config-schema.json` |
| **profiles** | -（記載なし） | -（記載なし） | `[profiles.<name>]`（`codex --profile <name>` で切替。実験的） |
| **Global config** | -（記載なし） | `~/.claude.json`（OAuth, MCP, trust settings 等） | -（記載なし） |
| **主要設定（抜粋）** | editor, theme, extensions | permissions, hooks, env, model, sandbox, enabledPlugins | model, approval_policy, sandbox_mode, mcp_servers, web_search |
| **permissions / trust** | -（記載なし） | `permissions.allow` / `ask` / `deny`（評価順: deny → ask → allow） | `approval_policy`（`untrusted` / `on-request` / `never` / granular）、`sandbox_mode`（`read-only` / `workspace-write` / `danger-full-access`） |


### エージェント/サブエージェント定義


| 項目 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| **定義形式** | Markdown + YAML frontmatter | Markdown + YAML frontmatter | standalone TOML files（`config.toml` の `[agents]` は `max_threads` 等のグローバル設定用） |
| **プロジェクトパス** | `.cursor/agents/`（互換: `.claude/agents/`, `.codex/agents/`） | `.claude/agents/` | `.codex/agents/*.toml` |
| **ユーザーパス** | `~/.cursor/agents/` | `~/.claude/agents/` | `~/.codex/agents/*.toml` |
| **frontmatter / 設定** | `name`, `description`, `model`, `readonly` | `name`, `description`, `model`, `effort`, `maxTurns`, `disallowedTools` | `name`（必須）, `description`（必須）, `developer_instructions`（必須） |
| **名前衝突時** | `.cursor/` が `.claude/` / `.codex/` より優先 | -（記載なし） | -（N/A） |
| **同時実行制限** | -（記載なし） | -（記載なし） | `agents.max_threads`（既定 6） |
| **ネスト深さ** | -（記載なし） | Agent tool で spawn 時に自動的に別コンテキスト（`context: fork` はスキルの frontmatter） | `agents.max_depth`（既定 1、ルート深度 0） |
| **ジョブタイムアウト** | -（記載なし） | -（記載なし） | `agents.job_max_runtime_seconds`（既定 1800 秒） |
| **Task tool との関係** | `description` が Task tool のヒントに表示 | `TaskCreated` / `TaskCompleted` フックイベント | `features.multi_agent` で `spawn_agent` 等を有効化 |


### プラグイン/拡張


| 項目 | Cursor | Claude Code | Codex |
|------|--------|-------------|-------|
| **プラグインシステム** | -（VS Code 拡張機能を継承） | プラグインディレクトリ（skills, agents, hooks, MCP, LSP のバンドル） | プラグイン = スキル + apps の配布単位 |
| **skills vs plugins** | -（N/A） | 個別スキル開発 → プラグインでバンドル配布 | スキルはローカル著者向け → プラグインで広く配布 |
| **マーケットプレイス** | -（VS Code Marketplace） | `claude plugin install`。`enabledPlugins` / `extraKnownMarketplaces` | Codex マーケットプレイス（Build plugins ページ） |
| **MCP との関係** | `.cursor/mcp.json` / `~/.cursor/mcp.json` で設定。stdio / SSE / Streamable HTTP | プラグイン内 `.mcp.json` or `plugin.json` インライン。有効化時に通常 MCP として統合 | `mcp_servers` config。プラグインレベルは `.mcp.json` + manifest の `mcpServers`。スキルレベルは `agents/openai.yaml` の `dependencies.tools` |
| **Third-party hooks** | `.claude/settings.json` の hooks を読み込み可能 | -（ネイティブ） | -（記載なし） |


## ツール別の特記事項

### Cursor

- **`.mdc` の3つの適用モード**: `alwaysApply: true`（毎回）、`globs`（ファイルパターン一致時）、`description` のみ（Agent が関連性を判断）。この3モードの使い分けが Cursor 固有の設計
- **互換パス**: `.claude/skills/`, `.codex/skills/`, `.claude/agents/`, `.codex/agents/` を自動的に探索し、他ツールとのスキル/エージェント共有を容易にしている
- **AGENTS.md 対応**: プロジェクトルートとサブディレクトリの `AGENTS.md` を読み込み可能。`.cursor/rules/` の簡易代替として位置づけ
- **Legacy `.cursorrules`**: `.mdc` が優先。両方存在すると `.mdc` が勝つ（6/6 テスト）が、`.cursorrules` も完全には無視されない

### Claude Code

- **CLAUDE.md は長さに関わらず全文ロード**: 他ツールと異なりハードなサイズ制限がない。ただし推奨は 200 行未満
- **コンパクト後の生存ルール**: プロジェクトルート CLAUDE.md・ユーザー CLAUDE.md・unscoped rules（推定）はディスクから再注入。スキル本文は直近の呼び出し分が自動 re-attach（5,000 tok/skill、合計 25,000 tok）。`paths` 付きルール・ネスト CLAUDE.md は再読みまで失われる
- **スキルのトークンバジェット**: 唯一、具体的な数値が公式に開示されている（per-skill 5,000 / total 25,000 トークン、description は 250 文字切り詰め、コンテキストの 1% バジェット）
- **settings.json の配列マージ**: 同一設定キーが複数スコープにある場合、配列系設定はマージ・重複除去される
- **`CLAUDE_CONFIG_DIR`**: `~/.claude` の代替パスを環境変数で設定可能

### Codex

- **32 KiB のハード上限**: `project_doc_max_bytes` で AGENTS.md の連結後サイズを制御。この数値は canonical/ の分量設計に直接影響する
- **`AGENTS.override.md` の排他挙動**: override が存在するディレクトリでは通常の `AGENTS.md` は**読まれない**（Claude Code の `CLAUDE.local.md` が後に連結されるのとは異なる）
- **`project_doc_fallback_filenames`**: `AGENTS.md` 以外のファイル名も AGENTS.md として扱わせることが可能
- **信頼レベル**: 信頼されていないプロジェクトでは `.codex/config.toml` が無視される
- **スキルの `agents/openai.yaml`**: UI メタデータ・暗黙起動ポリシー・MCP 依存を宣言する Codex 固有のメタデータファイル
- **`project_doc_max_bytes` の解釈**: AGENTS.md guide は combined size cap として明示。Config Reference は "Maximum bytes read … when building project instructions" とやや抽象的な表現だが、combined size cap と読むのが公式上もっとも直接的

## canonical/ との既存資産マッピング

### canonical の現構成と公式仕様の照合

| canonical の構成 | 対応する公式仕様 | 整合性 | 備考 |
|------------------|------------------|--------|------|
| `canonical/codex/AGENTS.md` → `~/.codex/AGENTS.md` | Codex: グローバルスコープ `~/.codex/AGENTS.md` | 整合 | 公式の discovery に合致 |
| `canonical/rules/*.md` → Cursor User Rules / Claude rules/ | Cursor: `.cursor/rules/`、Claude: `.claude/rules/` | 整合 | 両ツールとも rules/ ディレクトリをサポート |
| `canonical/skills/*/SKILL.md` → 各ツール skills/ | Cursor: `.cursor/skills/`、Claude: `.claude/skills/`、Codex: `.agents/skills/` | **パス差異あり** | sync スクリプトで吸収済みだが、Codex は `.agents/skills/` が正式 |
| `canonical/codex/README.md` の「rules は権限昇格専用」 | Codex: `requirements.toml` の `rules` は admin-enforced command rules として config-reference に公開済み | **出典不明** | 「権限昇格専用」という用途限定は公式に記載なし。admin-enforced command rules として公開されているが、用途の限定は運用判断 |
| `canonical/codex/AGENTS.md` の「正本は canonical/rules/*.md（8ファイル）」 | Codex: AGENTS.md のサイズ制限 32 KiB | **要注意** | 8ファイルの rules を参照チェーンで辿らせる設計が 32 KiB 制約に収まるか要検証 |
| `canonical/agents/*.md` → Codex `.toml` 生成 | Codex: `.codex/agents/*.toml` / `~/.codex/agents/*.toml` で standalone TOML files として定義 | **形式差異** | Claude/Cursor は MD 形式、Codex は standalone TOML。sync-codex.sh の .toml 生成が吸収 |

### 推測ベース記述の照合結果

| canonical の記述 | 公式仕様との照合 | 判定 |
|------------------|------------------|------|
| 「Codex の rules は権限昇格コマンド制御専用として扱う」（`canonical/codex/README.md` L16） | Codex の `requirements.toml` の `rules` は admin-enforced command rules として config-reference に公開済みだが、「権限昇格専用」という用途限定は公式に**記載なし** | **出典不明** — 運用判断としては妥当だが公式根拠は確認できず |
| 「正本は canonical/rules/*.md（8ファイル）」（`canonical/codex/AGENTS.md` L7） | 現在 canonical/rules/ は 11 ファイル | **ファイル数の不一致** — 記述更新が必要 |
| 「Codex に任意 Markdown コマンドがそのまま使えない」（`canonical/codex/commands-registry/README.md`） | Codex: スキルの `/skills` や `$` 呼び出しが存在。commands/ ディレクトリのネイティブ対応は**記載なし** | **概ね正確** — Codex にはスキル経由の呼び出しはあるが Cursor/Claude のような commands/ ディレクトリのネイティブ対応は確認できない |
| 「~/.codex/agents/*.toml は生成物」（`canonical/codex/AGENTS.md` L51） | Codex: `.codex/agents/*.toml` / `~/.codex/agents/*.toml` で standalone TOML files として定義（公式 Subagents ページに記載） | **概ね正確** — 公式が standalone TOML を一次表現としているため、sync-codex.sh での生成は妥当 |

## canonical への設計指針（Phase 1 診断への入力）

### 1. 常時注入される範囲の確定

| ツール | 常時注入対象 | canonical で「always-on」に置くべきもの |
|--------|------------|----------------------------------------|
| **Cursor** | `alwaysApply: true` の `.mdc` + User Rules | sync で `alwaysApply: true` を付与した .mdc として配布 |
| **Claude Code** | `paths` なしの `.claude/rules/*.md` + プロジェクトルート `CLAUDE.md` | 全文ロードされるため、分量管理が重要（200 行目安） |
| **Codex** | `~/.codex/AGENTS.md` + プロジェクト AGENTS.md チェーン | 32 KiB 制約内に収める必要あり |

**設計指針**: canonical/rules/ の「常時有効」ルールは、3ツールの最も厳しい制約（Codex 32 KiB）に収まるよう分量を管理する。Codex の AGENTS.md には原則レベルの要約のみを置き、詳細はスキル経由での遅延ロードに委ねる現在の設計は妥当。

### 2. スキルのディスカバリ差への対応

| ツール | 正式パス | 互換パス |
|--------|----------|----------|
| **Cursor** | `.cursor/skills/` | `.claude/skills/`, `.codex/skills/`, `.agents/skills/` |
| **Claude Code** | `.claude/skills/` | -（記載なし） |
| **Codex** | `.agents/skills/` | -（記載なし） |

**設計指針**: Cursor が他ツールのパスを互換探索するため、canonical/skills/ → 各ツールの正式パスへの sync が最も安全。`.agents/skills/` への symlink も検討に値する（Cursor が自動探索するため）。ただし Claude Code は `.agents/skills/` を探索しないため、sync-claude.sh での `.claude/skills/` への配布は必須のまま。

### 3. トークン制限に基づく分量ガイドライン

| 対象 | Claude Code 制限 | Codex 制限 | Cursor 制限 | canonical の設計指針 |
|------|-------------------|------------|-------------|---------------------|
| **ルール/AGENTS.md** | 全文ロード（200 行推奨） | 合計 32 KiB | 500 行推奨 | Codex の 32 KiB を最も厳しい制約として設計 |
| **スキル本文** | コンパクト後: 5,000 tok/skill, 25,000 tok/total | 記載なし | 記載なし | Claude Code の 5,000 トークンをスキルサイズの目安にする |
| **スキル description** | 250 文字切り詰め | 記載なし | 記載なし | description は 250 文字以内で書く |

### 4. コンパクト/コンテキスト枯渇への耐性

| ツール | コンパクト後の再注入 | 失われるもの |
|--------|----------------------|-------------|
| **Cursor** | 記載なし | 記載なし |
| **Claude Code** | プロジェクトルート CLAUDE.md + ユーザー CLAUDE.md を再注入（公式確認）。unscoped rules も再注入（推定）。スキル本文は自動 re-attach（5,000/25,000 tok） | `paths` 付きルール、ネスト CLAUDE.md |
| **Codex** | 記載なし（セッション最初のターンで注入とのみ記載） | 記載なし |

**設計指針**: canonical/rules/ の最も重要なルールは `paths` なし（unscoped）にして、Claude Code のコンパクト後も生存するようにする。パス限定ルールは「あると便利だが失われても致命的でない」ものに限る。

### 5. override 機構の差異

| ツール | override 挙動 | canonical への影響 |
|--------|--------------|-------------------|
| **Cursor** | Team Rules が全体に優先 | canonical を Team Rules として配布する場合、プロジェクト固有の上書きが効かなくなる |
| **Claude Code** | `CLAUDE.local.md` が `CLAUDE.md` の後に連結 | 個人設定が正本に追加される形。正本の内容は維持される |
| **Codex** | `AGENTS.override.md` が存在すると `AGENTS.md` は**読まれない** | override が canonical を完全に置き換える。正本の内容は失われるため注意 |

**設計指針**: Codex の override の排他性は、canonical の展開設計で最も注意すべき点。`~/.codex/AGENTS.override.md` を使う場合は canonical の AGENTS.md が無効化されることを認識し、override 側にも必要最低限のガードレールを含める必要がある。

## 参照

- [`docs/research/2026-03-30-ai-tool-hooks-specification-survey.md`](./2026-03-30-ai-tool-hooks-specification-survey.md) — hooks 仕様の同形式調査（本ドキュメントの姉妹編）
- [`docs/research/2026-04-02-canonical-cross-agent-optimization-framework.md`](./2026-04-02-canonical-cross-agent-optimization-framework.md) — Epic #38 の基準文書
- [Epic #38](https://github.com/stlwolf/ai-development-hub/issues/38) — canonical cross-agent optimization
- [Issue #58](https://github.com/stlwolf/ai-development-hub/issues/58) — 本調査の Issue

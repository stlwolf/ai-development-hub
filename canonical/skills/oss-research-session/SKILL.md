---
name: oss-research-session
description: >
  oss-researcher サブエージェントの起動・成果保存を標準化する。保存先パス規約、ツール別起動指針、
  注入プロンプト、親エージェントの検証チェックを含む。遵守はモデル依存であり100%ではない。
---

# OSS 調査セッション — oss-researcher 運用スキル

調査の中身（Phase 1–4 の手順・出力セクション構造）は **[`agents/oss-researcher.md`](../../agents/oss-researcher.md)** を正とする。本スキルは **オーケストレーション**（誰に何を渡し、どこに保存するか）のみを定義する。

## いつ使うか

- OSS / ライブラリについて **`oss-researcher`** で調査し、結果をリポジトリ内の Markdown 1 本に残すとき
- Cursor / Claude Code のいずれかでサブエージェントや同等の委譲を使うとき

## 限界（前提）

- サブが指定パスへ `Write` できること、プロンプト遵守は **ベストエフォート**（IDE のモード・権限・モデル挙動に依存）
- ファイル書き込みができない場合は、ユーザーが本スキルの **`OUTPUT_FILE`** に手動で貼り付ける

## 保存先の正（デフォルト）

| 項目 | 規約 |
|------|------|
| リポジトリルート | 調査対象ワークスペースの `$REPO`（通常は git ルート） |
| ディレクトリ | `$REPO/docs/research/oss-sessions/` |
| ファイル名 | `YYYY-MM-DD_<slug>.md`（`<slug>` はトピックやリポジトリ名から **kebab-case**、英小文字・数字・ハイフン推奨） |
| 同日・同一 slug の衝突 | ファイル名末尾に `_2`、`_3` … を付与（時刻サフィックスでも可だが、本スキルでは `_2` 連番に統一） |

作業前にディレクトリが無ければ、親エージェントまたはサブが作成する（`mkdir -p` 相当）。

## 成果ファイルのフロントマター（推奨）

調査本文の先頭に YAML フロントマターを付ける。記法は **markdown-conventions** スキルに合わせる（箇条書きは `-`、コードフェンスは言語指定）。

```yaml
---
researched_at: "YYYY-MM-DD"
topic: "<調査トピック一行>"
primary_url: "<メインリポジトリまたは公式URL>"
agent: oss-researcher
skill: oss-research-session
---
```

## サブエージェント起動（ツール別・ベストエフォート）

**原則**（**subagent-strategy** ルール）: 委譲前に `oss-researcher` に相当するカスタムエージェントがないか確認する。

- **Cursor**: カスタムエージェント一覧で **`oss-researcher`** を優先して起動する（`/エージェント名` や Subagent / Task 等、IDE の提供する方法。UI 名はバージョンで変わりうる）
- **Claude Code**: サブエージェント / カスタムエージェントで同様に **`oss-researcher`** を選ぶ
- 配置の参照: プロジェクトは `~/.cursor/agents/` / `~/.claude/agents/` 等（sync 済みなら本リポジトリの `canonical/agents/oss-researcher.md` が源）

**フォールバック**: ネイティブ起動が使えない場合は [`canonical/agents/oss-researcher.md`](../../agents/oss-researcher.md) を Read し、その全文（必要ならユーザーの調査指示を追記）をサブへ **prompt 注入**する。

## サブへ渡す統合プロンプト（テンプレ）

以下をコピーし、プレースホルダだけ置換してからサブに渡す。

```markdown
## コンテキスト（oss-research-session）

- 調査対象: <URL または org/repo>
- 成果物（必須）: 調査の **全文** を次の **1 ファイル にのみ** 書き込むこと:
  - 絶対パス: <OUTPUT_FILE 例: /path/to/repo/docs/research/oss-sessions/2026-04-01-my-lib.md>
- 本文構造・調査手順: リポジトリの `canonical/agents/oss-researcher.md`（Phase 4 のテンプレ）に従うこと
- チャット返信: **短い要約** と **書き込んだファイルパス** のみ。長文の複製は不要

（任意の追加観点があればここに書く）
```

### 保存契約（サブ向け）

- 調査の完成形は **指定された `OUTPUT_FILE` のみ** とする
- ツールでファイルに書けない環境のときは、その旨をチャットで明示し、**ユーザーが手動で `OUTPUT_FILE` に保存できるよう全文を一度だけ** 出す
- 各非自明な主張に `evidence-verification-rule` の検証ステータス（`verified` / `unverified-summary` / `speculation`）を付す。根拠（`file:line` / URL）は `verified` / `unverified-summary` に必須、`speculation` は根拠なし（必要なら理由）。一次ソース実体を確認していない主張を `verified` としない

## 親エージェントのチェックリスト

1. `$REPO/docs/research/oss-sessions/` を決め、`OUTPUT_FILE` のフルパスをテンプレに埋める（衝突時は `_2` 等）
2. 上記 **統合プロンプト** で `oss-researcher`（または注入した同等サブ）を起動する
3. **成果の spot-check**（`evidence-verification-rule` §3）— 体裁確認だけで終わらせない:
   - `Read` でフロントマター・構造が期待どおりかを確認した上で、主張のうち**重要・高不確実なものを優先して数件**、ソース実体（`file:line` / URL）に直接当てて裏取りする
   - 配分はリスク比例（固定件数ではない。重要主張は必ず、未確認を優先）。最終確認はソース実体に当て、LLM の自己申告・要約だけで `verified` としない
   - 根拠リンクが欠けた主張・ソースと矛盾する記述を見つけたら、サブに差し戻すかユーザーに `unverified-summary` として明示する
4. ユーザーに **ファイルパス** を返す

## 関連リソース

| リソース | パス |
|----------|------|
| 調査エージェント定義 | `canonical/agents/oss-researcher.md` |
| カタログ | `canonical/CATALOG.md` |
| サブエージェント方針 | `canonical/rules/subagent-strategy-rule.md` |
| 検証ディシプリン | `canonical/rules/evidence-verification-rule.md` |

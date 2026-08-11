---
name: conventional-commits
description: コミットメッセージをConventional Commits規約に従って生成する。コミット作成、git commit、コミットメッセージの記述時に使用する。型の定義、フォーマット、本文の書き方ルールを含む。
---

# Conventional Commits

コミットメッセージのフォーマット規約。全リポジトリ・全プロジェクト共通で適用する。

## フォーマット

```
<型>: <タイトル>

[任意 本文]
```

## 型の定義

| 型 | 説明 | Semantic Versioning |
|---|---|---|
| `feat` | 新機能の追加 | MINOR |
| `fix` | バグ修正、不具合の修正 | PATCH |
| `ui` | UIや表示に関わる変更 | - |
| `refactor` | リファクタリング（バグ修正でも機能追加でもないコード変更） | - |
| `style` | コードの意味に影響を与えない変更（フォーマット、セミコロン等） | - |
| `test` | テストの追加・修正 | - |
| `docs` | ドキュメントのみの変更 | - |
| `revert` | コミットの取り消し | - |
| `ci` | CI/CD設定の変更 | - |
| `infra` | インフラ関連の変更（IaC、設定ファイル等） | - |
| `chore` | ライブラリの追加・削除など、コード本体に影響しない作業 | - |
| `local` | ローカル環境のみに影響する変更 | - |

## 規則

1. コミットは型から始まり、コロンとスペースが続く (MUST)
2. まず型の定義で該当するprefixがないかを確認する (MUST)
3. 新機能追加時は `feat:` を使用する (MUST)
4. バグ修正時は `fix:` を使用する (MUST)
5. タイトルはコード変更の短い要約とする (MUST)
6. 本文を追加する場合、タイトルの下に1行の空行を入れる (MUST)
7. 本文には変更の動機・背景を記述する (MUST)
8. 本文は自由な形式で、改行で区切られた複数の段落で構成してよい (MAY)
9. 本文にインラインコード（バッククォート）を使わない (MUST NOT)

## 本文ガイダンス

規則7（本文には変更の動機・背景を記述する）の具体化。形式は自由だが、以下の観点を含めることで後から文脈を復元できる。

### 含めるべき観点

- **段階**: この変更は何の段階か（調査・実装・WIP・リファクタ・修正等）
- **意図/仮説**: なぜこの変更をしたか。何を達成・検証しようとしているか

### WIPコミット

ブランチ上のWIPコミットは未完成でもよい。ただし段階と意図がメッセージから読めること。

- タイトルで段階を示す: `wip(parser): add token stream — tests red expected`
- 本文で「何が未完了か」「次に何をするか」を書く

### trailers（任意）

git trailers で構造化メタデータを付与してもよい（強制ではない）。

```
Stage: implementation
Context: planner output applied, integration pending
```

## CLI 制約

規則9（本文にインラインコードを使わない）の根拠と運用。

- `git log` は本文を素のテキストで表示するので、バッククォートは強調にならず、記号がそのまま残るだけである
- `-m "..."` の二重引用符の中では、バッククォートがコマンド置換として解釈されて本文が壊れる（`$(...)` も同じ）
- バッククォートまたは `$(` を含む `git commit` コマンドは、`cc-lint` フックが解析を諦めて allow に倒れるため、Conventional Commits の形式検査を素通りする（`canonical/hooks/scripts/cc-lint.sh` の `extract_message`）
- 複数行の本文そのものは禁止しない（規則8）。`-m` を複数回渡せば、それぞれが段落として連結される
- どうしても展開される文字が要る場合の逃げ道として `-F <file>` がある。これは規則9 の例外ではないので、`-F` を使うときも本文にインラインコードは入れない（`-m` が無いと `cc-lint` の形式検査そのものが適用されないため、この逃げ道の代償は小さくない）

## 例

本文なし:

```
feat: allow provided config object to extend other configs
```

```
docs: correct spelling of CHANGELOG
```

本文あり（薄い — 意図が読めない）:

```
fix: fix the bug

Fixed the issue.
```

本文あり（十分 — 段階・意図・背景が読める）:

```
fix: prevent racing of requests

Stage: implementation — request dedup logic

API呼び出しが並行して走ると古いレスポンスが最新を上書きする問題。
リクエストIDを導入し、最新リクエスト以外のレスポンスを破棄する。
```

本文あり（WIP — 未完了だが文脈復元可能）:

```
wip(auth): add JWT validation middleware — happy path only

Stage: implementation — auth middleware scaffold

トークン検証のhappy pathのみ実装。次ステップ:
- 期限切れトークンのエラーハンドリング
- リフレッシュトークンフロー
```

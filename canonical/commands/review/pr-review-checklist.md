---
name: pr-review-checklist
description: レビュー対象のdiffをチェック項目に照らして検証し、問題があれば file:line を引用して修正を提案する。2パス制・重大度分類・Fix-First Heuristicを含む。
---

# Pre-Landing Review Checklist

レビュー対象の diff を以下のチェック項目に照らして検証する。問題を見つけたら `file:line` を引用し、修正を提案する。問題がない項目はスキップする。

> 本チェックリストは [gstack](https://github.com/garrytan/gstack) (MIT License, Copyright (c) 2026 Garry Tan) の Pre-Landing Review Checklist を参考に、自スタック（PHP/Laravel, React/Vue, Node）向けに再構成したものです。

## 設計原則

### 2パス制

- **Pass 1 (CRITICAL)**: 実行を止めるべき問題。マージ前に必ず対処する
- **Pass 2 (INFORMATIONAL)**: 対処すべきだが緊急ではない問題。改善提案

Pass 1 を先に実行し、完了後に Pass 2 を実行する。

### Fix-First Heuristic

問題を見つけたときのアクション分類:

- **SUGGESTED PATCH**: 機械的に修正可能な問題。修正案を提示する
- **NEEDS INPUT**: 人間の判断が必要な問題。推奨修正を添えて質問する

判断基準: シニアエンジニアが議論なしに適用するなら SUGGESTED PATCH。合理的なエンジニア間で意見が分かれるなら NEEDS INPUT。

CRITICAL の問題はデフォルトで NEEDS INPUT 寄り（リスクが高い）。INFORMATIONAL の問題はデフォルトで SUGGESTED PATCH 寄り（機械的修正が多い）。

### レビューアクション

| 結果 | アクション |
|------|-----------|
| CRITICAL が1件以上 | `request-changes` を原則とする |
| INFORMATIONAL のみ | `comment` で指摘。SUGGESTED PATCH を提示 |
| 問題なし | `approve` |

---

## Pass 1 — CRITICAL

### SQL & Data Safety

- **パラメタライズドクエリ**: SQL に変数を文字列結合/補間で埋め込んでいないか → Laravel: `DB::raw()` 内の `$variable` を `?` プレースホルダ + バインド値に変更。Node: prepared statements を使用
- **TOCTOU レース**: check-then-set パターン（`SELECT` で確認 → `UPDATE`）がアトミックでない → `WHERE` 条件付き `UPDATE` に変更するか、トランザクション + ロックを使用
- **N+1 クエリ**: ループ内でリレーション先にアクセスしている → Laravel: `with()` / `load()` で eager loading。SUGGESTED PATCH は明らかなループ内クエリに限定する（意図的な lazy loading を壊さない）
- **バリデーション回避の直接 DB 書き込み**: モデルバリデーションを迂回する直接操作 → Laravel: `DB::table()->update()` を Eloquent モデル経由に変更。意図的な場合はコメントで理由を明記

### Race Conditions & Concurrency

- **find-or-create の競合**: ユニーク DB インデックスなしの「存在確認 → 作成」パターン → Laravel: `firstOrCreate()` + ユニーク制約。重複キーエラーのリトライを実装
- **ステータス遷移の競合**: アトミックでないステータス更新 → `WHERE status = ? UPDATE SET status = ?` パターンに変更。同時更新で二重適用を防ぐ

### LLM Output Trust Boundary

- **バリデーションなしの DB 書き込み**: LLM 生成値（メール、URL、名前）をバリデーションなしで DB に書き込んでいる → `EMAIL_REGEXP`、`filter_var(FILTER_VALIDATE_URL)`、`.trim()` で軽量ガードを追加
- **構造化出力の型チェック欠如**: LLM のツール出力（配列、オブジェクト）を型/構造チェックなしで DB に書き込んでいる → 型バリデーションを追加
- **SSRF リスク**: LLM 生成 URL をホスト名チェックなしで fetch している → 許可リストまたはブロックリストでホスト名を検証し、内部ネットワークへのアクセスを防ぐ
- **保存型プロンプトインジェクション**: LLM 出力をナレッジベースや vector DB にサニタイズなしで保存 → 入力サニタイズを追加

### Injection (Shell & XSS)

- **PHP**: `exec()`, `shell_exec()`, `passthru()`, `system()`, `proc_open()` に変数を直接埋め込んでいる → `escapeshellarg()` でエスケープ、または Symfony `Process` コンポーネントで引数配列を使用
- **Node**: `child_process.exec()` にテンプレートリテラルで変数を埋め込んでいる → `child_process.execFile()` または `spawn()` で引数配列を使用
- **eval/exec**: LLM 生成コードを `eval()` でサンドボックスなしに実行 → サンドボックス環境で実行するか、構造化出力に変更
- **XSS**: ユーザー入力をエスケープなしで HTML 出力 → React: `dangerouslySetInnerHTML` の入力元を確認。Vue: `v-html` の入力元を確認。PHP/Blade: `{!! $var !!}` の入力元を確認。サニタイズまたはエスケープ出力に変更

### Enum & Value Completeness

diff で新しい enum 値、ステータス文字列、タイプ定数を追加している場合:

- **全消費者の追跡**: その値を `switch`/`match`/`if-elseif` で分岐している全ファイルを読む（grep だけでなく READ する）。新しい値が処理されない分岐がないか確認
- **許可リスト/フィルタ配列**: 兄弟値を含む配列を検索し、新しい値が含まれるべき場所に追加されているか確認
- **フロントエンド/バックエンド間**: フロントのドロップダウンに値を追加したが、バックエンドのモデル/バリデーションが対応していない場合をチェック

### Crypto Safety

- **不十分なエントロピー**: セキュリティ用途に `rand()` / `mt_rand()` を使用 → `random_bytes()` / `Str::random()` (Laravel) / `crypto.randomBytes()` (Node) に変更
- **タイミング攻撃**: シークレットやトークンの比較に `==` / `===` を使用 → `hash_equals()` (PHP) / `crypto.timingSafeEqual()` (Node) に変更

### Authentication & Authorization

- **認可チェックの欠落**: コントローラアクションやルートにポリシー/ゲートチェックがない → Laravel: `authorize()` / `Gate::allows()` / `Policy` を適用。ミドルウェア (`can:`, `auth`) の適用漏れを確認
- **IDOR (Insecure Direct Object Reference)**: URL パラメータの ID で他ユーザーのリソースにアクセス可能 → スコープクエリ (`$user->posts()->findOrFail($id)`) またはポリシーで所有者チェック
- **ロール/権限の昇格**: 権限チェックがフロントエンドのみで、API エンドポイントにサーバーサイドチェックがない → サーバーサイドでミドルウェアまたはポリシーによる権限検証を追加

---

## Pass 2 — INFORMATIONAL

### Dead Code & Consistency

- **未使用変数**: 代入後に参照されない変数 → 削除
- **バージョン不整合**: PR タイトルと VERSION/CHANGELOG ファイルのバージョンが一致しない → 統一
- **陳腐化コメント**: コード変更後に旧動作を説明するコメントが残っている → 更新または削除
- **不正確な CHANGELOG**: 変更内容と CHANGELOG 記述が一致しない → 修正

### LLM Prompt Issues

- **0-indexed リスト**: プロンプト内のリストが 0 始まり（LLM は 1-indexed を返す）→ 1-indexed に変更
- **ツール定義の不整合**: プロンプトが言及するツール/capabilities と実際の `tools` 配列が不一致 → 同期
- **分散した制限値**: トークン数/文字数制限が複数箇所で異なる値 → 定数化して一元管理

### Test Gaps

- **ネガティブパス不足**: 正常系のテストのみで異常系（バリデーションエラー、権限不足、タイムアウト）がない → 異常系テストを追加
- **副作用の検証不足**: ステータス変更のテストが型/ステータスのみ検証し、関連する副作用（通知、ログ、関連レコード更新）を検証していない → 副作用のアサーションを追加
- **セキュリティ統合テスト不足**: 認証/認可/レート制限の機能に end-to-end テストがない → 統合テストを追加

### Completeness Gaps

- **ショートカット実装**: TODO/stub/placeholder で放置されている、またはエラーパスが未実装（空の catch、`// TODO` コメントのみ）→ 完全版を実装
- **80-90% 実装**: ハッピーパスは動作するが、明らかなエッジケース（null、空配列、境界値）が未処理 → 残りを実装
- **テストカバレッジギャップ**: ハッピーパスのミラー構造で書ける異常系テストが欠けている → 追加

### Conditional Side Effects

- **条件分岐の副作用漏れ**: 条件分岐の一方では副作用を適用するが、もう一方では忘れている → 両パスで副作用を統一
- **ログと実動作の不一致**: ログに「実行した」と記録するが、条件によりスキップされている → ログを実際の動作に合わせる

### Column/Field Name Safety

- **ORM クエリのカラム名**: `select()`, `where()`, `orderBy()` のカラム名が実際の DB スキーマと一致するか確認 → 誤ったカラム名は空結果やサイレントエラーの原因
- **API レスポンスのフィールド名**: アクセスするフィールド名が実際のレスポンス構造と一致するか確認

### Time Window Safety

- **日付キーの24時間仮定**: 「今日」のキーで24時間分をカバーする前提のクエリ → タイムゾーンと時刻を明示的に指定
- **関連機能間のウィンドウ不整合**: 一方は時間バケット、他方は日バケットで同じデータを参照 → ウィンドウサイズを統一

### Magic Numbers & String Coupling

- **マジックナンバー**: 複数ファイルで使われる裸のリテラル値 → 名前付き定数に変更
- **エラー文字列の結合**: エラーメッセージ文字列を他の場所でクエリフィルタに使用 → 定数またはエラーコードに変更

### Type Coercion at Boundaries

- **PHP/JS 境界の型変化**: API リクエスト/レスポンスで数値と文字列が混在 → ハッシュ/ダイジェスト入力は型を正規化してから処理。フィールド単位で明示的に `(string)` / `(int)` キャストする（`JSON_NUMERIC_CHECK` は電話番号・ID 等を破壊するため使わない）
- **JavaScript の暗黙型変換**: `==` での比較が暗黙の型変換で予期しない結果を返す → `===` を使用し、境界値を明示的にキャスト

### View/Frontend (React/Vue)

- **不要な再レンダリング**: React: `useEffect` の依存配列が不適切で毎レンダリング実行 → 依存配列を修正。Vue: computed が依存しない reactive 値に反応 → 依存関係を整理
- **O(n*m) ルックアップ**: ループ内で `Array.find()` / `Array.filter()` → Map/Object でインデックス化
- **リクエストウォーターフォール**: `useEffect` 内の fetch が別の fetch 結果に依存 → 並列化または結合

### Performance & Bundle Impact

- **重い依存の追加**: `moment.js` (→ `date-fns`)、フル `lodash` (→ `lodash-es` または per-function import)、`jquery` → 軽量代替を提案
- **大きな静的アセット**: 500KB 超のファイルがリポジトリにコミット → CDN または圧縮を検討
- **画像の lazy loading 欠如**: `loading="lazy"` や明示的な width/height がない画像 → 追加（CLS 防止）
- **tree-shaking 破壊**: named import → default import への変更 → named import を維持

指摘しないもの: devDependencies の追加、動的 `import()`（コード分割）、5KB 未満の小さなユーティリティ追加

### Distribution & CI/CD Pipeline

- **CI ワークフロー変更**: ビルドツールバージョンの一致、アーティファクト名/パスの正確性、シークレットが `${{ secrets.X }}` でハードコードされていないか確認
- **バージョンタグ形式の一貫性**: `v1.2.3` vs `1.2.3` — VERSION ファイル、git タグ、publish スクリプト間で統一

指摘しないもの: 既存の自動デプロイパイプラインを持つ Web サービス、チーム外に配布しない内部ツール、テスト専用の CI 変更

---

## Severity Classification

```
CRITICAL:                          INFORMATIONAL:
├─ SQL & Data Safety               ├─ Dead Code & Consistency
├─ Race Conditions & Concurrency   ├─ LLM Prompt Issues
├─ LLM Output Trust Boundary       ├─ Test Gaps
├─ Injection (Shell & XSS)        ├─ Completeness Gaps
├─ Enum & Value Completeness       ├─ Conditional Side Effects
├─ Crypto Safety                   ├─ Column/Field Name Safety
└─ Authentication & Authorization  ├─ Time Window Safety
                                   ├─ Magic Numbers & String Coupling
                                   ├─ Type Coercion at Boundaries
                                   ├─ View/Frontend (React/Vue)
                                   ├─ Performance & Bundle Impact
                                   └─ Distribution & CI/CD Pipeline
```

---

## Fix-First Heuristic

```
SUGGESTED PATCH (修正案を提示):          NEEDS INPUT (人間の判断が必要):
├─ 未使用変数、デッドコード              ├─ セキュリティ（認証、XSS、インジェクション）
├─ N+1 クエリ（明らかなループ内クエリのみ） ├─ 競合状態
├─ 陳腐化コメント                       ├─ 設計判断
├─ マジックナンバー → 名前付き定数       ├─ 大きな修正（20行超）
├─ バージョン/パス不整合                 ├─ Enum 完全性
└─ 代入後未参照の変数                    ├─ 機能削除
                                        ├─ ユーザー可視の振る舞い変更
                                        ├─ O(n*m) ルックアップの最適化
                                        └─ LLM 出力バリデーション
                                          （明確な欠如のみ SUGGESTED PATCH 可）
```

---

## Suppressions — 指摘しないもの

- 無害な冗長性（可読性向上のための明示的な条件チェック等）
- 「なぜこの閾値/定数を選んだか」コメントの要求 — 閾値はチューニングで変わる、コメントは腐る
- 十分にカバーしている既存アサーションへの「もっと厳密に」要求
- 一貫性のためだけの変更提案（他の箇所でも同じパターンが使われている場合）
- diff で既に対処されている問題 — diff 全体を読んでからコメントする
- 「正規表現がエッジケース X を処理しない」— 入力が制約されており X が実際に発生しない場合
- 閾値変更（スコア、件数上限等）— 経験的にチューニングされるもの
- 生成物（lockfile, snapshot, build artifact）への一般論的な指摘
- 意図コメント付きの React hook 依存配列例外 / Vue watch 設定
- feature flag / 段階移行中の意図的な重複実装
- スキーマ移行途中の一時的互換コード

---

## 出力フォーマット

```
Pre-Landing Review: N issues (X critical, Y informational)

**SUGGESTED PATCH:**
- [file:line] 問題 → 推奨修正

**NEEDS INPUT:**
- [file:line] 問題の説明
  Recommended fix: 推奨修正

問題なしの場合: Pre-Landing Review: No issues found.
```

簡潔に。各問題につき: 問題1行、修正1行。前置きなし、サマリなし、「全体的に良さそう」なし。

---
name: diff-audit
description: PR diff全体を複数レンズで一括レビューする。Copilot代替。Bash堅牢性・ドキュメント整合・サイレント失敗・例外ハンドリングを汎用レンズとして持ち、--cdk/--php/--pythonでオプションレンズを追加可能。diff内完結パターンに特化。
---

# diff-audit — PR diff レビュー

## 用途と棲み分け

GitHub Copilot PR レビューの代替。「PR diff 内で完結するパターン」に特化する。

| スキル | 対象 | 特徴 |
|--------|------|------|
| `/code-review` | 単一ファイル/変更 | ドメイン知識込みのコード品質（システム組み込み） |
| `/security-review` | ファイル単位のセキュリティ | 脅威モデルに基づく深掘り（システム組み込み） |
| `/diff-audit` | PR diff 全体 | diff 内横断チェック、Copilot 代替（このリポジトリで定義） |

## 呼び出し方法

`/diff-audit` は Claude Code のスキルであり、Unix コマンドとしてシェルで直接実行できるわけではない。以下の形式で呼び出す:

```
# 基本（Claude Code のチャットで入力）
/diff-audit

# オプションレンズを追加
/diff-audit --cdk
/diff-audit --php
/diff-audit --python
/diff-audit --cdk --php  # 複数指定可
```

## 実行手順

1. `gh pr diff` を Bash で実行して diff を取得する
2. diff 全体をコンテキストに読み込む
3. **汎用レンズ**（常に適用）を全て実行する
4. オプションフラグが指定されていれば**オプションレンズ**を追加実行する
5. チェックリストに該当しない問題も、汎用技術知識を適用して diff 内のコードの技術的正確性を評価する（「このコードは意図通りに動くか？」という観点。サービス固有のドメイン知識は使わない）
6. 指摘を severity 別に整理して出力する

diff が大きい場合（目安: 500行超）は `gh pr diff | head -n 500` で確認してから分割レビューを検討する。

## 出力形式

```
## diff-audit 結果  CRITICAL 1件 / WARNING 3件 / SUGGESTION 1件

### CRITICAL（マージ前に必ず対処）
- `path/to/file.sh:42` — [Bash/B3] `for f in $FILES` — スペース入りファイル名で壊れる。`git diff -z` + `while IFS= read -r -d ''` を使うこと

### WARNING（対処推奨）
- `path/to/file.sh:10` — [Bash/B1] `set -euo pipefail` がない。スクリプト先頭に追加すること

### SUGGESTION（任意対応）
- `docs/plan.md:5` — [Doc/D1] 「29件」と記載があるが実装ファイルの件数は31件。要確認

### 適用結果
- [Bash] B1〜B16 確認済み（B3 CRITICAL、B1 WARNING）
- [Doc]  D1〜D6 確認済み（D1 WARNING）
- [Silent] S1〜S5 — N/A（該当ファイルなし）
- [Exception] E1〜E4 — OK（指摘なし）
```

- **N/A**: diff に対象ファイル・パターンが存在しないためレンズ未適用
- **OK**: 対象が存在し確認したが指摘なし
- 指摘は `[レンズ/ID]` 形式でチェック項目番号を明示する（再確認時に参照しやすくするため）

---

## 汎用レンズ（常に適用）

### 1. Bash 堅牢性

diff に `.sh` ファイル、`run:` ブロック（GitHub Actions）、heredoc のシェルコマンドが含まれる場合に適用。

| # | チェック項目 | 重大度 |
|---|------------|--------|
| B1 | `set -euo pipefail`（または `set -e` + `set -o pipefail`）の欠如 | WARNING |
| B2 | unquoted variables: `$VAR` → `"$VAR"` | WARNING |
| B3 | `for f in $FILES` — スペース入りファイル名で壊れる。`git diff -z` + `while IFS= read -r -d ''` を使う | CRITICAL |
| B4 | `xargs cmd` — `-` 始まりファイル名が引数と混同される。`xargs cmd --` にする | WARNING |
| B5 | `echo "$var" \| cmd` — `-` 始まり文字列や OS 依存エスケープで壊れる。`printf '%s' "$var" \| cmd` にする | WARNING |
| B6 | Bash 特殊変数の上書き: `SECONDS=0`、`IFS=` 等をグローバルで変更している | WARNING |
| B7 | `trap` のクォーティングバグ（シングル/ダブルの意図しない混在）| WARNING |
| B8 | `jq` に `-e` フラグがない — `null`/`false` を正常値として扱い、後続処理が誤動作する | WARNING |
| B9 | `curl` にタイムアウト指定がない（`--max-time`/`--connect-timeout` が未設定）| WARNING |
| B10 | `mktemp` + `mv` の cross-device rename — 異なる FS だと `mv` が `EXDEV` で失敗する。`mktemp` はターゲットと同一ディレクトリ配下に作る（例: `mktemp -p "$(dirname "$target")"`）か、`cp` + `rm` でフォールバックする | WARNING |
| B11 | exit code のセマンティクスミス（「SKIP」と表示して `exit 1` 等、コメントと乖離）| WARNING |
| B12 | `\|\| echo "..."` でエラーを握りつぶして後続処理へ進む | WARNING |
| B13 | `read` に `-r` がない — バックスラッシュが解釈され、ファイルパスやデータが壊れる | WARNING |
| B14 | `$SHELL` でシェル種別を判定している（ログインシェルと実行シェルが異なる場合に効かない）。`$BASH_VERSION`/`$ZSH_VERSION` で判定する | SUGGESTION |
| B15 | `aws ssm ... --value "${SECRET}"` — プロセス引数経由でシークレットが `ps` に露出する。`--value file://...` にする | CRITICAL |
| B16 | `printf "$var"` — フォーマット文字列インジェクション。`printf '%s' "$var"` にする | CRITICAL |

### 2. ドキュメント/状態の整合性

diff 内の複数ファイル間を横断してチェックする。

| # | チェック項目 | 重大度 |
|---|------------|--------|
| D1 | 数値の不一致: PR diff 内の別ファイル（または別セクション）で件数・バージョン・ポート番号が食い違う | WARNING |
| D2 | 語彙・コマンド名の不一致: 同一物を指す名称が複数の表記で登場する | SUGGESTION |
| D3 | 「IaC 変更済み」と記述しているが、実インスタンスへの反映（deploy）は未実施の状態で断言している | WARNING |
| D4 | 計画ドキュメントと実装ファイルが同一 PR に含まれ、内容が乖離している | WARNING |
| D5 | PR description に記載されたファイル変更と、実際の diff のファイル一覧が一致しない | WARNING |
| D6 | Mermaid 図や表の内容が本文の説明と矛盾している | SUGGESTION |

### 3. サイレント失敗

| # | チェック項目 | 重大度 |
|---|------------|--------|
| S1 | バリデーション抜け: 空文字・空白のみ・`null`・不正な IP アドレスが valid として通る | CRITICAL |
| S2 | `.trim()`/`.strip()` 漏れ: 環境変数やユーザー入力の前後空白が除去されていない | WARNING |
| S3 | trim 後の正規化を元の変数に書き戻していない（後続処理が未 trim 値を使う）| WARNING |
| S4 | 失敗時に `exit` せず後続コマンドへ進む構造になっている | WARNING |
| S5 | タイムアウト・失敗を「成功」として扱う（完了フラグ・通知が誤報になる）| CRITICAL |

### 4. 例外ハンドリング

| # | チェック項目 | 重大度 |
|---|------------|--------|
| E1 | `except Exception` / `catch (\Throwable)` で具体的な例外クラスを隠蔽している | WARNING |
| E2 | `HTTPException`（クライアントエラー）を汎用 `except Exception` で 500 に変換している | CRITICAL |
| E3 | `catch` して別例外に変換する際に `previous`/`__cause__` による連鎖がない（元の例外情報が消える）| WARNING |
| E4 | タイムアウト・ネットワーク系の例外を握りつぶして後続処理へ進む | WARNING |

---

## オプションレンズ

### --cdk: CDK/IaC

diff に `cdk/`、`infra/`、`cdk.json`、`template.yaml`（CloudFormation）が含まれる場合に有効化。`*.ts` のみでは判定しない（TypeScript 全般にマッチしてしまうため）。

| # | チェック項目 | 重大度 |
|---|------------|--------|
| C1 | VPC・EIP・IAM Role・Route 等の削除されると困るリソースに `RemovalPolicy.RETAIN` がない | CRITICAL |
| C2 | `AWS::EC2::Route` → `AWS::EC2::VPCGatewayAttachment` 等、リソース生成順序の依存が `DependsOn` で明示されていない | WARNING |
| C3 | SSM ARN や KMS ARN を `arn:aws:...` でハードコードしている（`Stack.formatArn()`/`Aws.PARTITION` を使う）| WARNING |
| C4 | `kms:ViaService` 条件に `amazonaws.com` をハードコードしている（aws-cn 等で不一致）| WARNING |
| C5 | `InstanceType` 変更が CloudFormation の置換扱いになり、RETAIN 中の EIP 付け替えが失敗する可能性 | WARNING |
| C6 | CDK の `StringParameter` に placeholder 値を書き込んでいる（次の `cdk deploy` で上書き戻りのドリフト）| WARNING |
| C7 | `CfnOutput` の `exportName` を固定値にしている（同一アカウント/リージョンへの再デプロイで名前衝突）| WARNING |

### --php: PHP 特化

diff に `*.php` が含まれる場合に有効化。

| # | チェック項目 | 重大度 |
|---|------------|--------|
| P1 | `report($e)` + `Log::error($e)` の併用 — Sentry に二重送信される（`report($e)` に一本化する）| WARNING |
| P2 | Repository interface の戻り値が `?object` — 呼び出し側の静的検証が効かない。具体型（`?ModelClass`）に統一する | SUGGESTION |
| P3 | `catch (\Throwable $e) { throw new FooException(...) }` で 500 系が Sentry の `ignore_exceptions` 対象に変換される | CRITICAL |
| P4 | PHPDoc の `@param`/`@return` 型が実装より狭すぎる・広すぎる | SUGGESTION |

### --python: Python 特化

diff に `*.py` が含まれる場合に有効化。

| # | チェック項目 | 重大度 |
|---|------------|--------|
| Y1 | 必須環境変数チェックで `os.environ.get(key)` に `.strip()` がない | WARNING |
| Y2 | `os.environ[key]` を `.strip()` 後に書き戻していない（後続で未 trim 値が使われる）| WARNING |
| Y3 | 空白のみの文字列が空文字チェックを通過する（`if not value` は `"  "` を通す）| WARNING |
| Y4 | `StrictHostKeyChecking=accept-new` — 初回 SSH 接続でホスト鍵を無検証登録（MITM 耐性なし）| CRITICAL |
| Y5 | in-memory のレートリミットストレージ — マルチワーカー環境では制限が効かない（Redis 等の共有ストレージを使う）| WARNING |

---

## 注意事項

- **スコープの定義**: サービス固有のドメイン知識（「このメソッドはXXを返すべき」等）を必要とするパターンは対象外。汎用技術知識（言語仕様・OS挙動・プロトコル等）を diff 内のコードに適用する評価は積極的に行う
- diff 外のファイル（変更されていないファイル）は参照しない
- 指摘は `file:line` を必ず引用する。行番号が特定できない場合はファイル名のみ
- 「指摘なし」のレンズも明示する（確認済みであることを示すため）
- 指摘数が多い場合は CRITICAL → WARNING → SUGGESTION の順に優先して提示する

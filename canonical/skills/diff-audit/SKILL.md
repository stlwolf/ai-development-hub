---
name: diff-audit
description: PR diff全体を原則ベースでレビューする。4つの問いを軸に、チェックリスト外の問題も含めて拾う。既知パターンは各問いのヒントとして残す。Bash堅牢性・ドキュメント整合・セキュリティを統合カバー。
---

# diff-audit — PR diff レビュー

## 設計原則

**原則が主役、ヒントは床。**
4つの問いが天井（チェックリスト外を拾う）、各問いの下のヒントが床（最低限の保証）。

## 実行手順

1. `gh pr diff` を Bash で実行して diff 全体を取得する
2. 以下の **4つの問い** を diff 全体に適用する。**diff に該当ファイル・パターンが含まれる場合、対応するヒントを必ずスキャンする**（任意参照ではない）
3. セキュリティ・IaC の深掘りが必要なら `/security-review` へ誘導する
4. フォローアップフローに従い処理する

diff が大きい場合（目安: 500行超）は分割してレビューする。

---

## 4つの問い

### 問い1: このコードは意図通りに動くか

diff 内のすべてのコマンド・コード・設定値を読み、以下の軸で問う。

- **境界値**: 空文字・空白のみ・null・スペース入りファイル名・大きな数値が来たらどうなる？
- **失敗伝播**: 前の処理が失敗したとき後続はどうなる？エラーが握りつぶされていないか？
- **環境差**: OS・シェル・ランタイム・FS が違ったら動作が変わる箇所はないか？
- **副作用**: 意図しない副作用（グローバル変数汚染・リソースリーク・状態変化）を起こさないか？

**ヒント — .sh / `run:` ブロック / ` ```bash ` ブロックが diff に含まれる場合、以下を必ずスキャン:**

`set -euo pipefail` 欠如 / unquoted `$VAR` /
`for f in $FILES`（スペース入りファイル名で壊れる → `git diff --name-only -z` + `while IFS= read -r -d ''` を使う） /
`xargs cmd`（`xargs cmd --` にする） / `echo "$var" | cmd`（`printf '%s\n'` にする） /
`printf "$var"`（フォーマット文字列インジェクション → `printf '%s'`） /
Bash特殊変数の上書き（`SECONDS=0` 等） / `trap` クォーティングバグ /
`jq` に `-e` なし / `curl` タイムアウト未指定 /
`mktemp`+`mv` cross-device rename（`mktemp -p <dir>` または直接パス形式で同一 FS に作成） /
exit code セマンティクスミス / `|| echo` で失敗握りつぶし / `read` に `-r` なし /
`aws ssm --value "$SECRET"`（ps でシークレット露出） / `$SHELL` でシェル判定

**ヒント — 任意の言語のコードが diff に含まれる場合、以下を必ずスキャン:**

バリデーション抜け（空文字・空白・null・不正 IP） / `.trim()`/`.strip()` 漏れ /
trim 後の正規化を書き戻していない / 失敗時に exit せず後続へ進む /
タイムアウト・失敗を成功として扱う / `except Exception`/`catch (\Throwable)` で隠蔽 /
`HTTPException` を 500 に変換 / catch→別例外変換で `previous`/`__cause__` なし

---

### 問い2: diff 内に矛盾・不整合はないか

PR diff を横断して比較する。単一ファイルでは見えない問題。

- **数値・名称**: 同じものを指す数値・名前・コマンドが複数箇所で食い違っていないか？
- **状態の断言**: 「変更済み」「完了」と書いているが実際には未反映の状態を断言していないか？
- **例示と定義**: ドキュメントの例示値がチェックリスト・テーブル・本文の定義と整合しているか？
- **PR description vs diff**: PR 説明に書いたことと実際の変更ファイルが一致しているか？

---

### 問い3: レンダリング・パースは意図通りか

diff 内の構造化テキスト（Markdown・YAML・JSON・設定ファイル）に対して問う。

- **Markdown**: テーブル・コードブロック・インラインコードが正しくレンダリングされるか？
  （テーブル内インラインコードの `\|`・バッククォートのネスト・言語指定の有無）
- **設定ファイル**: YAML インデント・JSON 構造・TOML セクション制約が正しいか？
- **コードブロック内の例示**: コピペして実行できる状態か？

---

### 問い4: セキュリティ上の懸念はないか

ここでは diff を読んで懸念が浮かんだら報告する水準。深掘りは `/security-review` に委ねる。

- シークレット・認証情報がログ・引数・レスポンスに漏れていないか？
- 認証・認可の判定に抜けがないか？
- 外部入力がサニタイズされずにコマンド・クエリ・テンプレートに渡っていないか？

**ヒント — `cdk/` `infra/` `cdk.json` `template.yaml` が diff に含まれる場合、以下を必ずスキャン:**

`RemovalPolicy.RETAIN` 漏れ（VPC・EIP・IAM Role・Route） / `DependsOn` 漏れ /
SSM/KMS ARN ハードコード（`Stack.formatArn()` 推奨） /
`kms:ViaService` に `amazonaws.com` ハードコード / `InstanceType` 変更の置換リスク /
`StringParameter` への placeholder 値 / `CfnOutput.exportName` 固定値

**ヒント — `*.php` が diff に含まれる場合、以下を必ずスキャン:**

`report($e)` + `Log::error($e)` 併用（Sentry 二重送信） /
`catch (\Throwable)` → `FooException` 変換で 500 系が Sentry 未達 /
Repository interface の `?object` 戻り値

**ヒント — `*.py` が diff に含まれる場合、以下を必ずスキャン:**

`os.environ.get(key)` に `.strip()` なし / trim 後の正規化を書き戻していない /
`if not value` で空白のみが通る / `StrictHostKeyChecking=accept-new` /
in-memory レートリミット（マルチワーカー環境で無効）

深掘りが必要と判断した場合: `→ /security-review を推奨` と明示する。

---

## 出力形式

```markdown
## diff-audit 結果  CRITICAL N件 / WARNING N件 / SUGGESTION N件

### CRITICAL（マージ前に必ず対処）
- `file:line` — [問い1] 説明

### WARNING（対処推奨）
- `file:line` — [問い2] 説明

### SUGGESTION（任意対応）
- `file:line` — [問い3] 説明

### 深掘り推奨
- → /security-review: 理由

### 適用結果
- [問い1] 確認済み（N件指摘）
- [問い2] 確認済み（指摘なし）
- [問い3] N/A（Markdown/設定ファイルなし）
- [問い4] 確認済み → /security-review 推奨なし

### 推奨アクション
verdict: 🚫 CRITICAL対応後マージ  （または ⚠️ 修正推奨後マージ / ✅ マージ可）

自動修正（確認なしで適用）:
- file:line — 説明

確認が必要（提示）:
- file:line — 説明

Issue化推奨（今PRでは修正しない）:
- （なし）
```

- **N/A**: diff に対象ファイル・パターンが存在しないためレンズ未適用
- **OK**: 対象が存在し確認したが指摘なし

---

## フォローアップフロー

### 判定基準

| 判定 | 条件 | 処理 |
|------|------|------|
| **自動修正** | 機械的修正可能（下記4条件を満たす）| 確認なしで Edit 適用 → 修正内容を報告 |
| **確認提示** | 選択肢が複数、または意図確認が必要 | 具体的な修正案を提示して判断を仰ぐ |
| **Issue化推奨** | SUGGESTION全般 | 今PRでは修正しない。別Issue化 or 見送りを申し送り |

**機械的修正可能の4条件（すべて満たす場合）:**
1. 修正箇所が diff 内に特定できる（file:line が明確）
2. 正しい修正が一意に決まる（選択肢がない）
3. 修正がコード動作の意図を変えない（バグ修正 or セキュリティ補強のみ）
4. 修正範囲が局所的（関数全体の再設計・リネーム等は対象外）

### verdict の決定ルール

- CRITICAL あり → `🚫 CRITICAL対応後マージ`
- CRITICAL なし + 機械的修正可能 WARNING あり → `⚠️ 修正推奨後マージ`（修正適用済みなら `✅ マージ可`）
- CRITICAL なし + 確認提示が必要な WARNING あり → `⚠️ 修正推奨後マージ`（確認待ち）
- WARNING なし / SUGGESTION のみ → `✅ マージ可`（SUGGESTION は Issue化申し送り）
- 指摘なし → `✅ マージ可`

---

## 注意事項

- diff 外のファイルは参照しない
- 指摘は `file:line` を必ず引用する
- 「確認済みで問題なし」のレンズも明示する（N/A と OK を区別する）
- セキュリティ・IaC の深掘りは `/security-review` へ委譲する。diff-audit は入口を担う

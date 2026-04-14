---
name: sentry-investigation
description: Sentry APIからエラー情報・スタックトレースを取得するパターン集。Sentryエラーの調査、スタックトレース抽出、イベント詳細の取得時に使用する。エージェントが自力でたどり着きにくいAPI構造・jqパスを含む。
---

# Sentry Investigation — API パターン集

## いつ使うか

- Sentry のエラー/イベントを調査するとき
- Issue 本文に Sentry リンクが含まれていたとき
- スタックトレースを Sentry API から抽出する必要があるとき

## 認証

```bash
# 必須: SENTRY_AUTH_TOKEN
echo "SENTRY_AUTH_TOKEN: ${SENTRY_AUTH_TOKEN:+set}"
```

トークン未設定の場合: https://sentry.io/settings/account/api/auth-tokens/ で発行を案内する。

## Org / Project の解決

- **Org**: 環境変数 `SENTRY_ORG` があればそれを使う。なければ入力 URL から抽出、または確認する
- **Project**: Issue 内容・リポジトリ名・Sentry URL から推測する。確定できなければ確認する

## 入力形式のパース

| 入力例 | 抽出方法 |
|--------|----------|
| `https://sentry.io/organizations/{org}/issues/{id}/` | URL から org と issue ID を抽出 |
| `https://{org}.sentry.io/issues/{id}/events/{event_id}/` | URL から org, issue ID, event ID を抽出 |
| `5765432100`（数値） | Issue ID としてそのまま使用 |
| `MYPROJECT-1A2B`（Short ID） | Short ID として検索 |

## API パターン

### Issue 概要の取得

```bash
ORG="${SENTRY_ORG}"
ISSUE_ID="<入力から抽出>"

curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${ISSUE_ID}/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}"
```

要約に使うフィールド: `title`, `culprit`, `project`, `count`, `userCount`, `firstSeen`, `lastSeen`

### 最新イベント詳細の取得

```bash
curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${ISSUE_ID}/events/?full=true&limit=1" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}"
```

### スタックトレースの抽出（2パターン）

Sentry のエントリ構造は 2 パターンある。**両方試して取得できた方を使う。**

#### パターン A: `entries[].type == "exception"`

```bash
curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${ISSUE_ID}/events/?full=true&limit=1" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" | \
  jq '.[0].entries[] | select(.type=="exception") | .data.values[0].stacktrace.frames[] | select(.inApp==true) | {filename, function, lineNo}'
```

#### パターン B: `entries[].type == "stacktrace"`

パターン A が空の場合にこちらを実行。

```bash
curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${ISSUE_ID}/events/?full=true&limit=1" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" | \
  jq '.[0].entries[] | select(.type=="stacktrace") | .data.frames[] | select(.inApp==true) | {filename, function, lineNo}'
```

#### 構造の違い

| パターン | `entries[].type` | スタックトレースのパス |
|----------|------------------|------------------------|
| A | `exception` | `.data.values[0].stacktrace.frames[]` |
| B | `stacktrace` | `.data.frames[]` |

抽出対象:
- `filename`: ファイルパス
- `function`: 関数名
- `lineNo`: 行番号
- `inApp: true` のフレームを優先

### リクエスト情報の取得（Web 系エラーの場合）

イベントの `entries` から `type == "request"` を探す:

```bash
jq '.[0].entries[] | select(.type=="request") | .data | {url, method, query, data}'
```

## Sentry パス → プロジェクトパスの変換

Sentry のスタックトレースに含まれるパスはデプロイ環境のパス。プロジェクト内のパスに変換する。

```
/var/www/html/src/Controller/... → src/Controller/...
/app/src/...                     → src/...
```

prefix 部分はプロジェクトの構成に応じて判断する。

## 調査完了後の原則

- **調査完了 ≠ 実装許可**。エラーの特定・原因分析が終わったら、結果をユーザーに報告して次のアクションの判断を仰ぐ
- Sentry エラーは緊急度が高く見えるが、急ぎの場面こそ拙速を避ける。implementation-gate-rule を厳守する
- 修正に進む場合も、プラン提示 → 承認 → 実装の順序を省略しない
- 修正スコープは Sentry で発生が確認されたコールパスに限定する。「ついでに」周辺の同パターンを直さない

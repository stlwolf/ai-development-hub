# 検証ケース一覧

## 概要

<!-- 検証の背景・目的を記述 -->

本ドキュメントは、[対象PR/機能] の修正を検証するためのテストケースを定義する。

## 対象PR一覧

| PR | タイトル | 修正内容 | 影響ファイル |
|---|---|---|---|
| #XXX | PRタイトル | 修正の概要 | 影響を受けるファイルパス |
| #YYY | PRタイトル | 修正の概要 | 影響を受けるファイルパス |

---

## 検証ケース詳細

### ケース1: [ケース名]

| 項目 | 値 |
|---|---|
| **関連PR** | #XXX |
| **Sentry Issue** | PROJECT-XXX（該当する場合） |
| **エラーメッセージ** | `エラーメッセージがある場合` |
| **発生箇所** | `/path/to/file.php:line` |
| **ベースラインcount** | N（Sentryの場合） |

**発生条件:**

- 条件1
- 条件2

**再現手順:**

```bash
cd /path/to/ai_verify
./scripts/api_call.sh GET /api/endpoint
```

**UI操作での再現:**

1. ステップ1
2. ステップ2
3. ステップ3

**データ要件:**

- 必要なテストデータがある場合は記述

**再現確認:** YYYY-MM-DD 確認済み / 未確認

---

### ケース2: [ケース名]

| 項目 | 値 |
|---|---|
| **関連PR** | #YYY |
| **Sentry Issue** | - |
| **発生箇所** | `/path/to/file.php` |

**発生条件:**

- 条件

**再現手順:**

```bash
./scripts/session_api.sh GET /api/endpoint
```

**UI操作での再現:**

1. ステップ

---

## 検証状況サマリー

| ケース | 関連PR | Sentry確認 | 再現可能 | 再現方法 |
|---|---|---|---|---|
| 1 | #XXX | ✅ / - | ✅ / ⚠️ / ❌ | API / UI / 手動 |
| 2 | #YYY | ✅ / - | ✅ / ⚠️ / ❌ | API / UI / 手動 |

---

## 検証手順

### 事前準備

1. ベースラインの記録（Sentry count等）
2. 検証ブランチのデプロイ
3. セッション情報の更新（必要な場合）

### 検証実行

```bash
cd /path/to/ai_verify

# 1. JWT認証
./scripts/cognito_auth.sh

# 2. API検証（JWT認証）
./scripts/api_call.sh GET /api/endpoint1
./scripts/api_call.sh GET /api/endpoint2

# 3. API検証（Session認証が必要な場合）
./scripts/session_api.sh GET /api/endpoint3

# 4. 待機後にエラー監視確認
sleep 30
```

### エラー監視確認コマンド

```bash
ORG="your-org"
for id in ISSUE_ID_1 ISSUE_ID_2; do
  curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${id}/" \
    -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" | \
    jq -r '"[\(.shortId)] count:\(.count) lastSeen:\(.lastSeen | .[0:16])"'
done
```

---

## 期待結果

| ケース | 修正前 | 修正後（期待） |
|---|---|---|
| 1 | エラー発生 | エラー発生なし |
| 2 | 条件下で発生 | 発生なし |

---

## 検証結果

<!-- 実際の検証後に記入 -->

| Sentry ID | ケース | 修正前count | 修正後count | 結果 |
|---|---|---|---|---|
| PROJECT-XXX | ケース1 | N | - | - |
| PROJECT-YYY | ケース2 | M | - | - |

**ベースライン取得日時**: YYYY-MM-DD HH:MM JST

（PRマージ・デプロイ後に結果を記入）

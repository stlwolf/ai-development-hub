---
name: spec-card
description: 蒸留パイプライン文書（kickoff/episode/decision/discussion）の作成時にフォーマットを適用する。frontmatter付与、ULID生成、ファイル命名規則の案内を含む。ドキュメント新規作成、Episode→Decision昇格時に使用する。
---

# Spec Card — ドキュメントフォーマット適用スキル

## いつ使うか

- 蒸留パイプラインのドキュメント（Discussion / KickOff / Plan / Episode / Decision）を新規作成するとき
- 既存ドキュメントに frontmatter を追加・整備するとき
- Episode から Decision への昇格を検討するとき

## いつ使わないか

- `kickoff-to-plan` / `plan-to-kickoff` の変換フロー自体（それらのスキルが優先）
- コード・スクリプトの作成（ドキュメント以外）

## フォーマット定義の参照先

詳細な仕様は ai-development-hub リポジトリ内の `docs/specs/document-format.md` を参照。sync 後の `~/.claude/skills/` 等から読む場合は、hub ワークスペースを開いた状態でパスを解決すること。本スキルは定義へのルーティングとクイックリファレンスを提供する。

## クイックリファレンス

### 必須フロントマター（全文書型共通）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | ULID (26文字) | 機械追跡用の一意識別子 |
| `title` | string | 人間可読なタイトル |
| `date` | YYYY-MM-DD | 作成日 |
| `type` | enum | `discussion` / `kickoff` / `plan` / `episode` / `decision` |
| `status` | enum | `draft` / `in-development` / `stable` / `deprecated` |

### 文書型の選び方

| type | 用途 | フォーマット深度 |
|------|------|----------------|
| `discussion` | 探索・ブレスト・調査メモ | 最小（frontmatter のみ） |
| `kickoff` | スコープ確定・方針の言語化 | 重い（セクションテンプレートあり） |
| `plan` | 実行可能な粒度まで分解 | 重い（kickoff-to-plan 出力と整合） |
| `episode` | 実行記録・作業ログ | 中間（本文フリーフォーム + 性質ガイド） |
| `decision` | 意思決定の蒸留・ADR | 重い（コンテキスト / 決定 / 根拠 / 結果） |

### ファイル命名

```
YYYY-MM-DD-{type}-{topic}.md
```

例: `2026-04-05-decision-quality-gate-skip-prevention.md`

## ULID の生成方法

```bash
python3 -c "
import time, random
t = int(time.time() * 1000)
c = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
ts = ''.join(c[(t >> (45 - 5*i)) & 31] for i in range(10))
rand = ''.join(random.choice(c) for _ in range(16))
print(ts + rand)
"
```

厳密に公式 ULID 仕様へ合わせる場合は `docs/specs/document-format.md` §4 のとおり `ulid` パッケージ利用を推奨。手書きスニペットは簡易実装のため厳密互換は保証しない。

## 既存スキルとの関係

- **`kickoff-to-plan`**: KickOff → Plan の変換ロジック。本スキルのフォーマットと整合するが、変換フロー自体は `kickoff-to-plan` が担う
- **`plan-to-kickoff`**: Plan → KickOff の逆変換。同上
- **`adversarial-review`**: レビュー対象ドキュメントが本フォーマットに沿っていると、frontmatter の `related[]` から設計背景を自動参照できる

本スキルはこれらを置き換えない。フォーマットの「入口案内」として機能する。

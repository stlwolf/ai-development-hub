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

詳細な仕様は `canonical/orchestration-spec/document-format.md` を参照（**spec 解決規約**: hub ワークスペースでは repo root からこのパスで、sync 済ハーネスでは各設定ルート下 `orchestration-spec/document-format.md`〔例 `~/.claude/orchestration-spec/document-format.md`〕で解決する。節参照は節タイトル主・番号従〔例「SO モード」節〔§4.1〕〕。規約の正本は `doc-flow-guardrail`）。本スキルは定義へのルーティングとクイックリファレンスを提供する。

## クイックリファレンス

### 必須フロントマター（全文書型共通）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `id` | ULID (26文字) | 機械追跡用の一意識別子 |
| `title` | string | 人間可読なタイトル |
| `date` | YYYY-MM-DD | 作成日 |
| `type` | enum | `discussion` / `kickoff` / `plan` / `episode` / `decision` |
| `status` | enum | `draft` / `in-development` / `stable` / `deprecated` |

### kickoff / plan は `so` モードを必須で宣言する

`kickoff` / `plan` を作成するときは、frontmatter に **`so` モードを必須**で入れる（SO を**設計段階で選択・記録**する）:

```yaml
so:
  design: weak | strong   # 設計 SO のモード
  impl: weak | strong     # 実装 SO のモード
  reason: "<なぜそのモードか>"
```

- **強 SO** = `peer-ai-review`（全レーン返却＋合意まで iterate・partial=再試行・0=不可）。高難易度/高リスク/不可逆に。
- **弱 SO** = `so-compare` / `oe-refute` / `oe-review`（1 周可・partial=disclose して進む・**0=SO 未実施扱いで再試行/escalate＝最低 1 レーン必須="0 はなし"**）。低〜中難易度/可逆に。
- レーン数・モデルは mode に焼かず都度指定（直交・既定ポリシーは `orchestration-toolkit`）。定義の正本は `canonical/orchestration-spec/document-format.md` の「SO モード」節〔§4.1〕。

### 文書型の選び方

| type | 用途 | フォーマット深度 |
|------|------|----------------|
| `discussion` | 探索・ブレスト・調査メモ | 最小（frontmatter のみ） |
| `kickoff` | スコープ確定・方針の言語化 | 重い（セクションテンプレートあり） |
| `plan` | 実行可能な粒度まで分解 | 重い（kickoff-to-plan 出力と整合） |
| `episode` | 実行記録・作業ログ | 中間（本文フリーフォーム + 性質ガイド）。closure 時は `episode-retrospective` skill を参照 |
| `decision` | 意思決定の蒸留・ADR | 重い（コンテキスト / 決定 / 根拠 / 結果） |

上表は蒸留5段（閉じた enum・#19 検証ゲート対象）。下記の `knowledge` は**この表には入らない**別種の型。

### ファイル命名

```
YYYY-MM-DD-{type}-{topic}.md
```

例: `2026-04-05-decision-quality-gate-skip-prevention.md`

### knowledge item（型付き状態 store・#272）— 上の共通規約は適用しない

`knowledge` は negative knowledge store の item 型で、蒸留5段の閉じた enum とは別物。**本スキルの共通フロントマター表・共通命名規約（`YYYY-MM-DD-{type}-{topic}.md`）は適用しない**。混同して `title` を付けたり `status: stable` を使ったり日付ファイル名にしない。

- frontmatter（必須9項）: `id`（ULID）/ `type: knowledge` / `status`（`active`\|`disabled`\|`superseded`\|`retired`・§6 の蒸留 status enum とは別）/ `date`（収穫日・不変）/ `trigger` / `prediction` / `source`（`.ref`）/ `landing`（`nl`\|`guard-candidate`）/ `observations`（v0 は `[]`）。任意 = `exclusions`（list）。本文 prose = 教訓。
- **ファイル名 = `<ULID>.md`**（`YYYY-MM-DD-...` ではない）。並行収穫の衝突回避のための意図的逸脱。
- 置き場 = 蒸留木ルート直下 `knowledge/items/`（item を ULID 名で置く・自由記述ノートは `knowledge/` 直下で `items/` に混ぜない・ai-hub は engine 木 `projects/orchestration-engine/docs/knowledge/items/`）。
- 正本 = `canonical/orchestration-spec/document-format.md` の §2.5 / §3.4。検証 = コマンド `validate-knowledge`（`~/bin` 配布・正本は hub の engine `scripts/`）。作成手順は `episode-retrospective` の Step 5。

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

厳密に公式 ULID 仕様へ合わせる場合は `canonical/orchestration-spec/document-format.md` の「ULID 規約」節〔§5〕のとおり `ulid` パッケージ利用を推奨。手書きスニペットは簡易実装のため厳密互換は保証しない。

## 既存スキルとの関係

- **`kickoff-to-plan`**: KickOff → Plan の変換ロジック。本スキルのフォーマットと整合するが、変換フロー自体は `kickoff-to-plan` が担う
- **`plan-to-kickoff`**: Plan → KickOff の逆変換。同上
- **`adversarial-review`**: レビュー対象ドキュメントが本フォーマットに沿っていると、frontmatter の `related[]` から設計背景を自動参照できる

本スキルはこれらを置き換えない。フォーマットの「入口案内」として機能する。

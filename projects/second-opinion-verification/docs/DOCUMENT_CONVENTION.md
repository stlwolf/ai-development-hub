# ドキュメント規約 (v0)

- 日付: 2026-02-12
- 性質: 仮制定。運用しながら更新する前提。
- 参考: [Claude Codeのドキュメント検索を極力さぼれるようにした話 (SIOS Tech Lab)](https://tech-lab.sios.jp/archives/51281)

---

## 1. 適用範囲

`projects/second-opinion-verification/docs/` 配下のドキュメントに適用する。
他プロジェクトへの展開は、ここでの運用結果を見てから判断。

---

## 2. ヘッダメタデータ（YAML Frontmatter）

原則として、ドキュメントは冒頭に以下の YAML Frontmatter を持つ。既存ファイルへの適用は段階的に行う（セクション5参照）。

```yaml
---
title: "ドキュメントのタイトル"
date: 2026-02-09
type: episode          # episode | decision | plan | report
participants:          # 該当する場合のみ
  - Cascade (Primary)
  - Claude Code (Second)
related:               # 関連ドキュメントへの参照
  - type: derived_from # derived_from | depends_on | supersedes | evidence_for
    ref: ../decisions/ADR-001-shell-timeout-pattern.md
    reason: "設計レビューから昇格した判断"
tags: [claude-safe, timeout, shell]
keywords: [watchdog, SIGTERM, nohup, macOS]  # 固有名詞・技術用語
use_when:              # 意図ベース検索用（「いつ参照すべきか」）
  - "シェルスクリプトでタイムアウトを実装するとき"
  - "claude-safe のプロセス管理で問題が起きたとき"
---
```

### フィールド定義

| フィールド | 必須 | 用途 |
|-----------|------|------|
| `title` | 必須 | ドキュメントのタイトル |
| `date` | 必須 | 作成日（YYYY-MM-DD） |
| `type` | 必須 | ドキュメント種別（下記参照） |
| `participants` | 任意 | AI/人間の参加者と役割 |
| `related` | 任意 | 関連ドキュメント（type + ref + reason） |
| `tags` | 推奨 | カテゴリベースの分類（3-8個） |
| `keywords` | 任意 | 固有名詞・技術用語での精密検索用 |
| `use_when` | 推奨 | 意図ベース検索用。「〇〇のとき」「〇〇に直面したとき」の形式 |

### ドキュメント種別（type）

| type | 配置先 | 性質 | 更新頻度 |
|------|--------|------|----------|
| `episode` | `episodes/` | 作業記録・議論経緯・セッション統合記録 | 高（作業中随時） |
| `decision` | `decisions/` | 確定した判断（ADR形式） | 低（確定時のみ） |
| `plan` | `plans/` | 検証計画・実施方針・キックオフ計画 | 中（計画変更時） |
| `report` | `episodes/` | 検証レポート・結果まとめ | 低（検証完了時） |

#### 補足: episode のバリエーション

運用の中で以下のパターンが定着した:

- **作業記録**: 個別の検証実施の記録（例: Codex CLI 基本動作確認）
- **セッション統合記録**: 長いセッション全体の展開と到達点の記録。スレッド移行時のコンテキスト引き継ぎに使う
- **相互評価記録**: エージェント間の peer feedback やオーケストレーション可能性評価

#### 補足: plan のバリエーション

- **検証計画**: 具体的な検証手順・成功基準の定義（例: codex-cli-verification-prompt）
- **キックオフ計画**: 新しいスレッドの初期コンテキスト注入用。課題定義 + 評価基準 + 参照先の指示を含む（例: deep-dive-verification-kickoff）

キックオフ計画は「ディスカッションのレイヤーで生成されるもの」であり、厳密なプランとは性質が異なる。現時点では `plans/` に配置し命名で区別する（`kickoff` を含める等）。正式な種別追加は運用実績を見て判断。

### 関係タイプ（related.type）

| type | 意味 | 例 |
|------|------|-----|
| `derived_from` | ここから派生した | Episode → Decision への昇格 |
| `depends_on` | これに依存している | 実装が設計判断に依存 |
| `supersedes` | これを置き換えた | v2 が v1 を更新 |
| `evidence_for` | これの根拠になる | 検証結果が仮説の根拠 |

---

## 3. 本文構造

**本文の構造は縛らない。** 種別ごとに自然に異なる形になってよい。

ただし、以下のパターンが既に定着しているものはそのまま踏襲する:

- **Decision (ADR)**: Context → Decision → Consequences（標準ADR形式）
- **Episode**: 背景 → 指摘/議論 → 結論/次のアクション
- **Report**: 概要 → 結果 → 発見した問題 → 教訓
- **セッション統合記録**: 原点 → 展開の軌跡 → 確立された成果物 → 方向性 → 次のアクション
- **キックオフ計画**: 目的 → 評価基準/尺度 → 手順 → テンプレート → 成功基準

---

## 4. ファイル命名

```
YYYY-MM-DD-topic-name.md
```

- 日付プレフィックスで時系列ソート可能にする
- Decision は `ADR-NNN-topic-name.md` 形式を継続

---

## 5. 運用ルール

- 上書き禁止。更新は `supersedes` で新ファイルを作り、旧版を残す
- Frontmatter はドキュメント作成時に付与。既存ファイルへの遡及適用は段階的に行う
- `use_when` は「自分が後で検索するとき、何と聞くか」を想像して書く
- 完璧を目指さない。メタデータが不完全でも本文があれば価値はある

### ドメイン固有情報の扱い

サービスリポジトリ側で実施した検証結果をこちらに持ってくる際:

- ドメイン固有情報（コントローラー名、Issue番号、PR番号、URL等）は汎化する
- 汎化前の原本はサービスリポジトリ側に残すか、`tmp/` に退避（gitignore対象）
- 汎化版では `{{変数名}}` でプレースホルダー化するか、具体的な名称を抽象化する

### 他プロジェクトへの参照

`agent-verification-flow/docs/templates/` 等、他プロジェクトの成果物を参照する場合:

- `related` の `ref` に相対パスで記載する
- テンプレートやパターンが他プロジェクトに配置されている旨を明記する

# ドキュメント規約

本プロジェクト（WezTerm AI Mode / `wez` CLI ツールキット）のドキュメント管理規約。[`second-opinion-verification/docs/DOCUMENT_CONVENTION.md`](../second-opinion-verification/docs/DOCUMENT_CONVENTION.md) (v0) および [`cursor-thread-tools/CONVENTIONS.md`](../cursor-thread-tools/CONVENTIONS.md) と同型のフローを採用し、**リポジトリ内2例目**として AI 駆動開発プロセスの再現性を検証する。

一次根拠の PoC は凍結のまま [`projects/poc/wezterm-ai-mode/`](../poc/wezterm-ai-mode/) に残す。Epic トラッキング: [Issue #20](https://github.com/stlwolf/ai-development-hub/issues/20)。

新しいスレッドで作業を開始するエージェントは、キックオフドキュメントと合わせて本ファイルを参照すること。

## フォルダ構成

```
docs/
├── VERIFICATION_MATRIX.md    # 検証マトリクス（A: ツール / B: プロセス）
├── discussions/              # フェーズ前のディスカッション（type: discussion）
│   └── feature-requests/     # 機能追加・拡張の要望・検討
├── plans/                    # 計画・キックオフ（type: plan）
├── episodes/                 # 作業記録・議論経緯（type: episode）
├── decisions/                # 確定した判断 ADR形式（type: decision）
└── raw-logs/                 # 生ログ 層3（gitignore対象、一時保管）
```

## ファイル命名規則

| type | 配置先 | 命名パターン | 例 |
|------|--------|------------|-----|
| `discussion` | `discussions/{category}/` | `YYYY-MM-DD-topic.md` | `discussions/feature-requests/2026-03-30-pane-polling.md` |
| `plan` | `plans/` | `YYYY-MM-DD-{kickoff\|plan}-topic.md` | `2026-03-30-kickoff-wez-phase1.md` |
| `episode` | `episodes/` | `YYYY-MM-DD-topic.md` | `2026-03-30-phase1-socket-wrapper.md` |
| `decision` | `decisions/` | `ADR-NNN-topic.md` | `ADR-001-cli-invoke-pattern.md` |
| (生ログ) | `raw-logs/` | 任意 | `wezterm-cli-list.json`、貼り付け `.md` 等 |

### plan のサブタイプ

| サブタイプ | 命名内の識別子 | 用途 |
|-----------|-------------|------|
| kickoff | `kickoff` を含める | スレッドの開始プロンプト。前スレッドの議論を圧縮した初期コンテキスト |
| plan | `plan` を含める | 具体的な実装プラン、検証計画 |

`impl-plan` や `detail-plan` のような独自識別子は使わない。`plan` に統一する。

## YAML Frontmatter（必須）

全ドキュメントに以下の frontmatter を付与する。

```yaml
---
title: "ドキュメントのタイトル"
date: YYYY-MM-DD
type: discussion | episode | decision | plan
related:
  - type: derived_from | depends_on | supersedes | evidence_for | implements
    ref: 相対パス
    reason: "関連の理由"
tags: [3-8個のカテゴリタグ]
---
```

### 必須フィールド

| フィールド | 説明 |
|-----------|------|
| `title` | ドキュメントのタイトル |
| `date` | 作成日（YYYY-MM-DD） |
| `type` | ドキュメント種別（`episode` / `decision` / `plan`） |

### 推奨フィールド

| フィールド | 説明 |
|-----------|------|
| `related` | 関連ドキュメント（type + ref + reason） |
| `tags` | カテゴリベースの分類 |
| `keywords` | 固有名詞・技術用語での精密検索用 |
| `use_when` | 意図ベース検索用（「〇〇のとき」形式） |

### 関係タイプ（related.type）

| type | 意味 |
|------|------|
| `derived_from` | ここから派生した |
| `depends_on` | これに依存している |
| `supersedes` | これを置き換えた |
| `evidence_for` | これの根拠になる |
| `implements` | これを実装した |

## スレッド分化時のドキュメントフロー

```
スレッド N（議論・ブレスト）
  │
  ├── [raw-log] CLI 出力・貼り付け → raw-logs/ に一時保管
  │
  ├── [discussion] フェーズ化前の検討・要望
  │     → discussions/{category}/YYYY-MM-DD-topic.md
  │     （フェーズ確定時に plan/kickoff へ昇格）
  │
  └── [plan/kickoff] 次スレッドの開始プロンプト
        → plans/YYYY-MM-DD-kickoff-{topic}.md
            │
            スレッド N+1（実装・検証）
              │
              ├── [episode] 作業記録
              ├── [decision] 確定した判断（ADR）
              └── [plan/kickoff] さらに次のスレッドへ...
```

キックオフは**前スレッドの議論を圧縮したスタートプロンプト**。スレッドが分化するたびに `plans/` に蓄積される。

## フェーズ実行フロー

各フェーズ（子スレッド）は以下の3段階で進める。キックオフに「実行フロー」セクションとしてこの内容を含めること。

### Stage 1: プラン策定（Agent mode）

1. **コンテキスト読み込み**: 本キックオフ + `CONVENTIONS.md` + 既存コード/ドキュメントを読み込む
2. **プラン作成**: Agent mode で `docs/plans/YYYY-MM-DD-plan-{topic}.md` に直接 MD ファイルとして作成する
   - 「プラン構成のガイドライン」に従う（Step 0 必須、概算時間、E2E/ドキュメント分離）
   - ADR チェックリストの各項目を対応 Step の直後に独立 TODO として配置
   - peer-ai-review gate を独立 TODO として配置
3. **peer-ai-review**: `/peer-ai-review` でプランの3者合意を取得する（Agent mode なので `so-compare.sh` が実行可能）
4. **CP 確定**: 合意内容をプラン MD に反映し、ユーザーに報告する

**← Stage 1 完了後、ここで停止してユーザーに報告する。** ユーザーが Plan mode に切り替えてから Stage 2 に進む。

### Stage 2: 実装（Plan mode）

5. **プラン変換**: 確定済みプラン MD の内容を Plan mode のプランに変換する
6. **ビルド実行**: Plan mode の TODO 実行確実性を活用して実装する。gate/checkpoint は TODO 項目として実行する

### Stage 3: 成果物記録（Agent mode）

7. **成果物記録**: エピソード + ADR + VERIFICATION_MATRIX 更新
8. **キックオフ突合**: キックオフの成功基準・完了条件と実装結果を突合し、未達成項目を明示する

このフローがキックオフに記載されていれば、スレッド開始時のプロンプトは**キックオフの参照のみ**で済む。

**Stage 分離の理由**: Plan mode は read-only 制約があり、`so-compare.sh` 等の外部コマンド実行やファイル書き込みができない。プラン策定と peer-ai-review を Agent mode で完了してから、確定プランを Plan mode に変換することで、フロー中の阻害を回避する。

## plan と episode の分離ルール

- `plan` は**実行前の状態を保持する**。実行結果を plan に追記しない
- 実行結果・発見・変更点はすべて `episode` に記録する
- plan に追記してよいのは frontmatter のタイトルに `（実行完了）` を付与する程度

## ADR 作成基準

以下のいずれかに該当する判断は `decisions/ADR-NNN-topic.md` に記録する:

- 2つ以上の選択肢を比較して1つを選んだ
- 外部依存を追加・変更・削除した
- プラン記載のアプローチを実装時に変更した
- 「やらない」と明示的に決めた

ADR は短くてよい（10行でも可）。エピソードに埋もれるより、独立ファイルとして検索可能にすることが目的。

## 運用ルール

- 上書き禁止。更新は `supersedes` で新ファイルを作り、旧版を残す
- Decision（ADR）は確定後に変更しない
- `raw-logs/` は gitignore 対象。抽出（episodes/decisions への昇格）後は破棄可（TTL: 30〜90日目安）
- frontmatter が不完全でも本文があれば価値はある。完璧を目指さない

## 実装スタックに関する注記

本プロジェクトの実装は主に **Bash**（`set -euo pipefail`、変数のクォート、`shellcheck`）。プランとレビューでは TypeScript と異なり **型チェックに相当するのは `shellcheck` と手動 E2E** と位置づける。

## 関連プロジェクトの成果物

| ファイル | 配置先 | 関連 |
|---------|--------|------|
| [DOCUMENT_CONVENTION.md](../second-opinion-verification/docs/DOCUMENT_CONVENTION.md) | second-opinion-verification | 本規約の派生元 |
| [CONVENTIONS.md](../cursor-thread-tools/CONVENTIONS.md) | cursor-thread-tools | 同一フローの先行検証例 |
| [context-persistence-4layer-model.md](../../ideas/20260220/context-persistence-4layer-model.md) | ideas/ | 4層モデル（層3パイプライン） |
| [peer-ai-review.md](../../canonical/commands/verification/peer-ai-review.md) | canonical/commands | 設計判断のピアレビュー用コマンド |
| [PoC README](../poc/wezterm-ai-mode/README.md) | poc/wezterm-ai-mode | 技術検証の一次根拠（凍結） |
| [Issue #20 — Epic](https://github.com/stlwolf/ai-development-hub/issues/20) | GitHub | プロジェクト昇格・スコープの正本 |

## ADR 作成のフロー組み込み

プランに ADR チェックリスト（`- [ ] ...`）がある場合:

- 各チェックリスト項目を、対応する Step の**直後に独立 TODO として配置**する
- 例: Step 1 で選択肢を比較 → Step 1 の直後に「TODO: ADR-NNN 作成」を配置
- ADR 作成は実装完了後のまとめ作業ではなく、**判断が確定した時点で即作成**する

（複数フェーズで ADR 作成がフロー中に漏れた教訓に基づく）

## peer-ai-review gate の運用

プランに peer-ai-review 実施ポイント（gate）を記載する場合のルール:

- gate は実装 Step と**同列の独立 TODO 項目**として登録する（ルールのみでは gate が飛ばされうる）
- gate の TODO は「Step N 完了」ではなく「Step N の合格基準を満たしたら」のように**条件ベース**で記述する
- gate をスキップする場合は、エピソードにスキップ理由を明記する（事後の peer-ai-review で代替可）
- gate の対象がプラン peer-ai-review で既に合意済みの場合はスキップ可（エピソードに理由記載）

### 標準 gate: 実装後コードレビュー（必須）

プランには**実装後のコードレビュー gate** を必ず含めること。プラン peer-ai-review（設計レビュー）とは別に、実装に対する `so-compare.sh` レビューを実施する。

- **配置**: 実装 Step 完了後、E2E 検証 Step の前（または同時）
- **目的**: `set -euo` 漏れ、引用・パス処理の不整合、既存シェル規約との乖離など、設計レビューでは検出しにくい欠陥を検出する
- **条件**: 全実装 Step が完了し、変更スクリプトで `shellcheck` が通り、手元 E2E が通る状態になったら実施

### peer-ai-review の事実検証

事実検証テーブルに「検証方法」列を含め、以下を区別すること:

- **公式ドキュメント確認**: WezTerm CLI / Lua API の該当セクションを引用レベルで確認
- **実コード実行**: 実際にスクリプトを走らせて動作確認
- **ソースコード確認**: 必要に応じツール側の挙動を直接確認

「CLI が存在する」ことと「具体的なフラグ・出力形式」は検証粒度が異なる。後者は公式ドキュメントの該当箇所を引用すること。

## プラン構成のガイドライン

- プランには**前提調査 Step（Step 0）**を必ず含める。前提が崩れたらプラン自体を修正する gate を設ける
- Step ごとに概算時間を含め、エピソードで実績との乖離を記録する
- E2E 検証 Step とドキュメント Step は分離する（検証 → 修正 → 再検証 → ドキュメントのフローを明確に）

## ガードレール（将来検討）

現状はこのファイルがエージェント・人間共通の参照先。将来的に以下を検討:

- バリデーションスクリプト（ファイル名 + frontmatter 整合性チェック）
- 正準ドキュメント → ツール固有ルールへの自動変換（CONVENTIONS.md → `.cursor/rules/` 等）
- 別プロジェクトへのポータブルテンプレート化
- peer-ai-review gate の自動実行（gate 到達時に `so-compare.sh` を自動起動するスクリプト化）

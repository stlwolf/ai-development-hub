---
title: "デザインシステム × AI 品質担保パターン: 3記事クロス分析"
date: 2026-04-10
status: research-complete
tags: [research-intake, design-system, skills, quality-definition, progressive-disclosure]
sources:
  - https://x.com/masatosuzuki_/status/2042391157465116873
  - https://zenn.dev/minewo/articles/design-md-guide-and-adoption-log
  - https://zenn.dev/cybozu_frontend/articles/design-system-skills
related_ideas:
  - ideas/20260224/hypothesis-design-ci-parallel-agents.md
next_step:
  trigger: "フロントエンド開発タスクの実需発生時 / ideas/20260224 の仮説検証に着手する時点"
  actions:
    - "ideas/20260224 の「検証するなら」セクションにパターン1(品質3層)・パターン9(verify)を適用した検証計画を作成"
    - "パターン2(品質基準埋め込み)を既存スキルに試行適用する候補を選定（出力形式や合否基準が定義しやすいスキルから）"
    - "パターン11(既存リポジトリの Skills 化)を外部デザインシステム導入時の配布方式として評価"
  referenced_by: "orchestration-research でデザイン CI 層を追加検討する際 / フロントエンド込みプロジェクトのスキル設計時"
---

# デザインシステム × AI 品質担保パターン

3記事はいずれも「AI にデザインシステムの知識を渡して品質を担保する方法」を扱い、それぞれ異なるレイヤーをカバーしている。

| 記事 | 著者 | 焦点 | 補完関係 |
|------|------|------|---------|
| [品質3層定義 SKILL.md](https://x.com/masatosuzuki_/status/2042391157465116873) | masatosuzuki_（UIデザインスタジオ代表） | 品質の定義 + 作業順序 | 「何を守るか」 |
| [DESIGN.md 導入ガイド](https://zenn.dev/minewo/articles/design-md-guide-and-adoption-log) | mine_take | 参照アーキテクチャ + 検証 | 「どう確認するか」 |
| [デザインシステムを丸ごと Skills にする](https://zenn.dev/cybozu_frontend/articles/design-system-skills) | mugi / サイボウズ フロントエンド | 既存資産の配布方法 | 「どう届けるか」 |

---

## 記事A: 品質3層定義 SKILL.md（masatosuzuki_）

### 記事情報

- **タイトル**: Claude CodeのSKILL.mdに「品質3層定義」を書いたら、40画面のデザインが破綻しなくなった
- **URL**: [x.com/masatosuzuki_/status/2042391157465116873](https://x.com/masatosuzuki_/status/2042391157465116873)
- **著者/組織**: masatosuzuki_（UIデザインスタジオ代表、AI + Figma 体制を1年以上運用）
- **公開日**: 2026-04-10（推定）
- **種別**: ツイートスレッド
- **要約**: 40画面以上の SaaS デザインで品質を維持するために、「品質」を3層に分解して定義した。L1（機能品質）は全画面必須の最低ライン、L2（体験品質）は主要画面、L3（感動品質）は特定画面に集中。SKILL.md に L1 基準を記載することで AI が毎回同じ基準を参照し、出力品質が安定。作業順は1画面ずつ完成させるのではなく Wave 方式（全体を L1→L2→L3 の3波でなぞる）。AI は L1 主導・L2 協業・L3 は人間主導で分業する。

### 本質的パターン

| # | パターン名 | 本質（1-2行） | 種別 |
|---|-----------|-------------|------|
| 1 | 品質3層定義（L1/L2/L3） | 「品質」を機能/体験/感動の3層に分解し、画面ごとに必要レベルを事前配分する | 設計原則 |
| 2 | SKILL.md への基準埋め込み | L1 基準を SKILL.md に記述し、AI が毎回参照することで出力品質のばらつきを抑制 | 実装パターン |
| 3 | Wave 方式 | 1画面ずつ完成させず、全体を L1→L2→L3 の波で複数回なぞる | ワークフロー |
| 4 | AI-Human 分業モデル | 正解が定義しやすい層は AI 主導、微調整は協業、感性判断は人間主導 | 設計原則 |

#### パターン1: 品質3層定義（L1/L2/L3）

「品質を落とさない」は抽象的すぎて、チーム内で定義がブレる。これを3層に分けることで判断基準を構造化する。

- **L1（機能品質）**: 全画面で必須。情報表示・操作性・デザインシステム準拠・トークン参照・Auto Layout・命名規則・5状態定義（Default/Hover/Focus/Error/Disabled）。これを割ったらリリースしない
- **L2（体験品質）**: 主要画面で実現。状態遷移フィードバック・プログレッシブディスクロージャー・余白バランス・テキストトーン統一・エラーハンドリングのUX
- **L3（感動品質）**: 特定画面に集中。予想を超える体験・ブランドインパクト・マイクロインタラクション・エモーショナルデザイン

42画面の実例配分: L3=5画面(12%) / L2=15画面(36%) / L1=22画面(52%)。この配分を最初に決めることで「この画面にどこまで時間をかけるか」の議論が不要になる。

なぜ有効か: 「全画面に L3 を求めると40画面は永遠に終わらない」。品質の定義を持つことは手を抜くことではなく、設計判断を構造化すること。

#### パターン2: SKILL.md への基準埋め込み

スキルに「手順」だけでなく「合否ライン」を持たせることで、AI が毎回同じ基準で作業する。masatosuzuki_ の例:

```
# L1品質基準（すべての画面で必須）
- コンポーネントはデザインシステムライブラリから使用する（新規作成禁止）
- 色はセマンティックトークンを参照する（直打ち禁止）
- Auto Layoutで組む（固定高さはスクロールコンテナのみ例外）
- レイヤー名: [Category]/[Component]/[Variant]/[State]
- 5状態定義: Default/Hover/Focus/Error/Disabled
```

この設計判断は UI 固有だが、「合否を判定可能な基準をスキルに含める」というメタパターンは汎用的。本リポジトリの Skills は手順やワークフローが中心で、品質基準（何をもって「正しい出力」とするか）を明示的に持つものは少ない。

#### パターン3: Wave 方式

1画面ずつ完璧に仕上げると、最初と最後で成熟度がズレる。デザインシステムも途中で進化するため、初期の画面が古く見える。

- 第一波（L1 / 30%）: 全画面の構造確定。ワイヤーフレーム近似。コンポーネント種類と数が確定
- 第二波（L2 / 40%）: 主要画面の体験仕上げ。ここで確立したパターンが他画面にも波及
- 第三波（L3 / 30%）: 特定画面に集中投資

#### パターン4: AI-Human 分業モデル

タスクの性質によって AI の委譲度を変える段階モデル:

- **L1 = AI 主導**: 正解が定義しやすい（ルール通り作る）。40画面を一定品質で高速に生成可能
- **L2 = 協業**: 人間が方向を示し、AI が実装。「Loading は0.3秒後にスケルトン表示、データ取得完了後にフェードイン」のような指示
- **L3 = 人間主導**: 何がユーザーの記憶に残るかは設計者の感性と経験。AI は「想定内の驚き」にしかならない

---

## 記事B: DESIGN.md 導入ガイド（mine_take）

### 記事情報

- **タイトル**: DESIGN.md 導入ガイド: AI実装のための入口・契約・検証をどう整えるか
- **URL**: [zenn.dev/minewo/articles/design-md-guide-and-adoption-log](https://zenn.dev/minewo/articles/design-md-guide-and-adoption-log)
- **著者/組織**: mine_take
- **公開日**: 2026-04-06
- **種別**: ブログ記事
- **要約**: `DESIGN.md` を UI 実装の「入口ドキュメント」として位置づけ、AI と人間が同じ判断基準で UI を実装するための参照順・正本（token JSON）・対応関係（component mapping）・検証コマンド（`pnpm penpot:verify`）を固定する手法。Growth Lab での導入実績を時系列で示し（v0.6.0→v0.17.0→2026-03-22）、「ルールの量ではなく判断の順番を増やす」ことが要点。最小導入は「参照順 → 正本 → 検証」の3ステップで十分とする。

### 本質的パターン

| # | パターン名 | 本質（1-2行） | 種別 |
|---|-----------|-------------|------|
| 5 | Index-as-Entry-Point | ルール集を肥大化させず、DESIGN.md を軽量な index（参照順の制御ファイル）に絞る | 設計原則 |
| 6 | SSoT 分離 | 説明用ドキュメント（Markdown）と正本（token JSON）を明確に分離 | 設計原則 |
| 7 | 外部語彙正規化 | 外部 UI 語彙（App Bar, Drawer 等）をそのまま内部実装に持ち込まず、既存コンポーネント責務にマッピング | ワークフロー |
| 8 | Design-Code Mapping File | デザインツール名・React export 名・token・variant の対応関係を1ファイルに集約 | 実装パターン |
| 9 | Verify コマンドによる Drift 検出 | `pnpm penpot:verify` で token JSON ↔ スタイル定義 ↔ component mapping の整合を機械検証 | 評価手法 |
| 10 | 段階的導入（3ステップ） | 「入口 → 正本 → 検証」の順で最小限から始め、ルールの量ではなく判断の順番を増やす | ワークフロー |

#### パターン5: Index-as-Entry-Point

`DESIGN.md` に詳細を書き込みすぎると「重複ドキュメント」になる。役割を「読む順番の提示 / token SSoT の明示 / コンポーネント対応関係の参照方針 / 最小チェック手順」に絞ることで、入口と辞書を分離する。Growth Lab の最小サンプル:

```markdown
# DESIGN.md
## Read first
1. design-tokens
2. component-architecture
3. component mapping
4. operation guide
## Source of truth
- Tokens SSoT: design tokens in JSON
- Component mapping: design-to-code mapping file
## Rules
- Do not introduce external UI vocabulary directly
- Normalize requested UI patterns before implementation
- Verify design-related changes with `pnpm penpot:verify`
```

本リポジトリの `CATALOG.md` がまさに同じ思想で設計されている（全リソースの入口として機能し、詳細は各ファイルに委譲）。

#### パターン6: SSoT 分離

token の正本は Markdown ではなく JSON 側に置く。説明用ドキュメントは「要約」であり正本ではない。同期処理も JSON の互換データを扱い、設計の正本を自動上書きしない方針。これにより説明用ドキュメントと実装契約の役割分担が明確になる。

本リポジトリの `canonical/` → `scripts/sync.sh` → `~/.cursor/` 等への配布と同じ構造（canonical が正本、配布先は派生）。

#### パターン9: Verify コマンドによる Drift 検出

`pnpm penpot:verify` は少なくとも以下を検証:
- token JSON とスタイル定義の整合
- コンポーネント対応ファイルの token 参照の正当性
- 派生アセットの契約

ルールを書くだけでなく検証コマンドまで含めることで、善意依存（「みんなルールを読んで守ってくれるはず」）を排除する。本リポジトリの hooks/（block-destructive, commit-gate）と「自動検証で善意依存を排除する」原則は共通だが、drift 検出（宣言と実態のずれ検知）という適用パターンは本リポジトリにまだない。

---

## 記事C: デザインシステムを丸ごと Skills にする（mugi / サイボウズ）

### 記事情報

- **タイトル**: デザインシステムを丸ごと Skills にする
- **URL**: [zenn.dev/cybozu_frontend/articles/design-system-skills](https://zenn.dev/cybozu_frontend/articles/design-system-skills)
- **著者/組織**: mugi / サイボウズ フロントエンド
- **公開日**: 2026-04-08
- **種別**: ブログ記事
- **要約**: kintone Design System を MCP ではなく Skills として提供する事例。既存リポジトリの階層構造（README.mdx による段階的参照）をそのまま活かし、SKILL.md はナビゲーションガイドのみ記述する。MCP が求めていた本質（段階的開示）は Skills で代替可能であり、MCP 固有の課題（サーバー構築・コンテキスト圧迫）を回避できる。「既存構造が整理されていれば、新規ドキュメントを書き足さずに Skills 化できる」が核心。

### 本質的パターン

| # | パターン名 | 本質（1-2行） | 種別 |
|---|-----------|-------------|------|
| 11 | 既存リポジトリの Skills 化 | SKILL.md はナビゲーションガイドのみ。整理済みリポジトリをクローンして参照させる | 実装パターン |
| 12 | MCP → Skills 移行の判断基準 | MCP の本質的メリット（段階的開示）は Skills でカバー可能。サーバー側処理が不要なら Skills の方がコスト低 | 設計原則 |
| 13 | README 階層構造による Progressive Disclosure | 各ディレクトリに README を置き、浅い概要→深い詳細へ辿れる構造 | 設計原則 |
| 14 | バージョン固定クローン | 利用側の package.json からバージョンを特定し、XDG キャッシュにチェックアウト | 実装パターン |

#### パターン11: 既存リポジトリの Skills 化

kintone Design System はドキュメントが Storybook 上の MDX で整備済みで、リポジトリ自体が階層的に整理されていた。Skills 化で行ったのは:

1. SKILL.md に「リポジトリのセットアップ手順」と「どのディレクトリに何があるかのガイドマップ」を書く
2. 利用者はバージョン固定でリポジトリをクローン
3. あとは既存の README.mdx を辿るだけで段階的に詳細へ到達

SKILL.md の実装例（簡略版）: Step 1 でバージョン特定 + クローン、Step 2 で `docs/` 配下のドキュメントを辿る、Step 3 で `components/` 配下のコンポーネント（stories + docs）を調べる。

提供側のコストが低い点が最大のメリット。デザインシステム側に更新があっても、全体構造が変わらない限り SKILL.md の修正は不要。

#### パターン12: MCP → Skills 移行の判断基準

MCP が効いた理由は「段階的開示」。AGENTS.md やルールに全部載せるとコンテキストが薄まる問題を、必要に応じた情報取得で解決した。しかし Skills も同じ段階的開示を提供する:

| 層 | MCP | Skills |
|----|-----|--------|
| 概要 | ツール一覧を返す | name + description（常時読み込み） |
| 中間 | コンポーネント一覧を返す | SKILL.md 本文（関連時に参照） |
| 詳細 | Storybook コードを返す | references/ や外部リポジトリ（必要時に参照） |

MCP 固有の課題:
- サーバーの構築・起動・運用が必要
- コンテキストを圧迫しやすい（多数のツール実行）

Skills なら SKILL.md を配置するだけで利用開始でき、Slash Commands としても呼べる。

#### パターン14: バージョン固定クローン

利用側の `package.json` からバージョンを読み取り、XDG Base Directory Specification に沿ったキャッシュ（`${XDG_CACHE_HOME:-$HOME/.cache}/`）にクローン + タグチェックアウトする:

```bash
KDS_VERSION=$(node -e "
  const pkg = require('./package.json');
  const v = pkg.dependencies?.['@org/design-system'] || '';
  console.log(v.replace(/^[\^~>=<]*/, ''));
")
gh repo clone @org/design-system "$CACHE_DIR" 2>/dev/null || true
git -C "$CACHE_DIR" checkout "$KDS_VERSION" 2>/dev/null || git -C "$CACHE_DIR" checkout main
```

---

## 記事間の関連性

3記事は「AI にスケールする UI 設計をさせるための構造化」という共通テーマを異なる角度からカバー:

| 観点 | 記事A（masatosuzuki_） | 記事B（mine_take） | 記事C（mugi/cybozu） |
|------|----------------------|---------------------|---------------------|
| AI への制約の渡し方 | SKILL.md に L1 基準を記述 | DESIGN.md を入口、token JSON を正本 | SKILL.md をナビゲーション、既存リポジトリを参照 |
| ドリフト防止 | Wave 方式で全体を繰り返し通過 | `pnpm penpot:verify` で機械検証 | バージョン固定クローンで鮮度担保 |
| 段階的開示 | L1→L2→L3 で品質層を段階的に | DESIGN.md → 詳細ドキュメント群 | name/description → SKILL.md → references/ |

---

## 資産マッピング

### トラックA: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ/新規知見 |
|---------|--------|-----------|-----------------|
| Index-as-Entry-Point | `canonical/CATALOG.md` | 補強 | 同じ思想で運用中。記事は傍証 |
| SSoT 分離 | `scripts/sync.sh` + canonical/ | 補強 | 同じ構造 |
| SKILL.md への品質基準埋め込み | `canonical/skills/` 全般 | 補強（メタ知見） | 現 Skills は手順中心。品質基準（合否ライン）を持たせる設計は参考 |
| AI-Human 分業モデル | `rules/subagent-strategy-rule.md` | 概念補強 | タスク性質による委譲度段階設計の観点がない |
| 既存リポジトリの Skills 化 | `canonical/skills/` の構造設計 | 拡張 | canonical/ 自体がこの構造に近い（CATALOG → SKILL.md → 参照先） |
| README 階層 Progressive Disclosure | `canonical/CATALOG.md` → `skills/*/SKILL.md` | 補強 | 既にこのパターンに沿っている確認 |
| MCP → Skills 移行判断 | `canonical/mcp/` | 参考 | 将来の見直し時に |
| デザイン CI パイプライン | `ideas/20260224/hypothesis-design-ci-parallel-agents.md` | 補強 | 3記事が仮説の構成要素を具体化（下記 defer セクション参照） |

### トラックB: 新規導入候補

| パターン | 既存対応物 | 導入形態 | 実現可能性メモ |
|---------|-----------|---------|-------------|
| 品質3層定義 L1/L2/L3 | なし | — | UI デザイン固有。直接の導入先なし |
| Wave 方式 | なし | — | 大量画面設計ワークフロー。スコープ外 |
| 外部語彙正規化 | なし | — | UI/フロントエンド固有 |
| Design-Code Mapping File | なし | — | デザインツール連携。スコープ外 |
| Verify Drift 検出 | hooks/ | 概念参考 | 善意依存排除は共通だが適用領域が異なる |
| バージョン固定クローン | なし | ideas/ 記録候補 | 外部リポジトリを Skills バックエンドに使う実装パターン |

---

## アクション判定

| # | パターン | アクション | 理由 |
|---|---------|-----------|------|
| 1 | 品質3層定義 | `discard` | UI デザイン固有。本リポジトリに適用先なし |
| 2 | SKILL.md への品質基準埋め込み | `archive-note` | スキル設計のメタ知見として記録 |
| 3 | Wave 方式 | `discard` | 大量画面設計ワークフロー。スコープ外 |
| 4 | AI-Human 分業モデル | `archive-note` | subagent-strategy にない観点として記録 |
| 5 | Index-as-Entry-Point | `discard` | 既存と同一。新規知見なし |
| 6 | SSoT 分離 | `discard` | 既存と同一 |
| 7 | 外部語彙正規化 | `discard` | UI 固有 |
| 8 | Design-Code Mapping File | `discard` | スコープ外 |
| 9 | Verify Drift 検出 | `archive-note` | drift 検出パターンは hooks とは異なる適用。記録 |
| 10 | 段階的導入 | `discard` | メタ知見。特定資産に落ちない |
| 11 | 既存リポジトリの Skills 化 | `archive-note` | 将来の Skills 設計の選択肢として記録 |
| 12 | MCP → Skills 移行判断 | `archive-note` | mcp/ 見直し時の参考 |
| 13 | README 階層 Progressive Disclosure | `archive-note` | canonical/ の設計意図の言語化 |
| 14 | バージョン固定クローン | `archive-note` | 外部リポジトリ参照の実装パターン |
| — | フロントエンド開発フロー（統合） | `defer` | ideas/20260224 との接続あり。テーマ具体化時に再訪 |

---

## defer: フロントエンド開発フローとの接続

3記事の知見は `ideas/20260224/hypothesis-design-ci-parallel-agents.md`（デザイン CI = 観点特化エージェント群の並列パイプライン）の具体的実装パターンを補強する。

| 仮説の構成要素 | 対応する記事の知見 |
|--------------|------------------|
| 品質の定義方法 | L1/L2/L3 品質3層定義（masatosuzuki_）。L1 は定量ゲートで自動判定可能、L3 は人間ゲートに残す |
| 検証の自動化 | DESIGN.md + verify コマンド（mine_take）。token ↔ スタイル ↔ mapping の整合を機械検証 |
| 知識の配布方法 | Skills 化（cybozu）。既存リポジトリをクローンして SKILL.md でナビゲーション |
| 観点特化エージェント群 | 未カバー（仮説独自: a11y / トークン準拠 / レスポンシブ / ビジュアルリグレッション） |

フロントエンドを含む開発フローの確立自体はまだ具体化されていないテーマだが、将来的に網羅すべき領域。再訪トリガー: フロントエンド開発タスクの実需が発生した時点、または ideas/20260224 の仮説検証に着手する時点。

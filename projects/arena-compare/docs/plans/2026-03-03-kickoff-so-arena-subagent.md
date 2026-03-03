---
title: "SO/Arena サブエージェント化 + 探索行動原則"
date: 2026-03-03
type: kickoff
source: Playwright MCP skill + stg-login整備スレッド
scope: cross-cutting
note: >
  本ドキュメントは arena-compare 単独のキックオフではなく、SO（セカンドオピニオン）と
  Arena（マルチモデル比較）の両方を横断するサブエージェント化キックオフ。
  so-compare.sh のスクリプト改善、SO/Arena 両スキルの新設、peer-ai-review / arena-perspectives
  両コマンドのリファクタ、および探索行動原則のスキル化を含む。
  配置先は arena-compare プロジェクトだが、スコープは ai-development-hub リポジトリ全体に及ぶ。
  2026-03-04 の実装セッションで全 Phase（0a/0b/1/2/3）完了。
related:
  - type: derived_from
    ref: 別プロダクト向けリポジトリ/docs/ai-automation-roadmap/02-so-arena-subagent.md
    reason: "SO/Arena サブエージェント化の元課題ドキュメント"
  - type: derived_from
    ref: 別プロダクト向けリポジトリ/docs/ai-automation-roadmap/03-persistent-exploration.md
    reason: "探索行動原則の元課題ドキュメント"
  - type: implemented_by
    ref: ../episodes/2026-03-04-subagent-integration.md
    reason: "Arena 側の実装エピソード"
tags: [so-compare, arena-compare, subagent, skill, persistent-exploration, cross-cutting]
---

# SO/Arena サブエージェント化 + 探索行動原則

> **注**: このキックオフは arena-compare プロジェクト単独ではなく、SO と Arena の両方を横断する改修計画。
> `scripts/so-compare.sh` の改善、SO/Arena/探索行動原則の3スキル新設、`peer-ai-review` / `arena-perspectives` 両コマンドのサブエージェント委譲リファクタを含む。
> 2026-03-04 の実装セッションで全 Phase 完了済み（コミット `49f8618`）。

## 背景

Playwright MCPスキル整備セッション（2026-02-25〜03-03）で以下が確立済み:
- Playwright スキル（`cursor/skill/playwright-browser/`）+ エージェント（`cursor/agents/playwright-agent.md`）の分離設計
- generalPurposeサブエージェントからMCPツール利用 + セッション共有を検証済み
- API インターセプトパターン（`scripts/intercept-api.js`）

両スクリプト（`so-compare.sh`, `arena-compare.sh`）はcommandのみ存在した時期に作られたもので、skill/subagent パターンを前提としていない。

別セッション（PHP非推奨修正 #5108, #5110, #5111）で発見された課題:
- `so-compare.sh` の結果読み込み + 3者比較テーブルがメインコンテキストを消費
- `-c` でファイル全文渡しによるプロンプト肥大化とタイムアウト
- AIが原因探索の途中で「不可能」と早期結論づけてしまう問題

### 発生した具体例

- `-c` で4ファイル渡し → prompt 95KB → Codex 278秒、Claude 414秒
- arena-compare で3モデル全てタイムアウト（180秒、出力0行）
- 結果読み込み + 比較テーブル作成で数百行のコンテキスト消費

## プロンプト設計原則

SOスキル・Arenaスキル共通の設計原則。上記の問題から導出された教訓。

### やってはいけないこと

- `-c` でファイル全文を渡す → アンカリングが起き、渡したコードしか見ない
- 結論を含むプロンプト → 追認を誘発する
- 1回のプロンプトに複数の質問を詰め込む

### やるべきこと

- `-w` でワークスペースパスを渡し、エージェントに自分で読ませる
- 検証ポイントを具体的に列挙（「X, Y, Z を検証して」）
- 事実と仮定を分離（「確認済み: A。未検証の仮定: B」）
- 反証可能性を確保（「違う可能性はあるか？」）

## スコープ

### 課題1: スクリプト改善 [完了]

skill/subagent パターンの確立に伴い、スクリプト側もそれに合わせた改善が必要。特に `so-compare.sh` への `-w` 追加は、プロンプト設計原則（`-c` 禁止、`-w` 参照方式）を実現するために不可欠。

注: `arena-compare.sh` は既に `-w PATH` オプションを実装済み。`so-compare.sh` のみ未実装。

#### 前提調査（Phase 0 着手前に実施）[完了]

`-w` の実装方式は、codex CLI / claude CLI がワークスペースパスをどう受け取るかに依存する:

- [x] `codex` CLI にワークスペースパス指定の仕組みがあるか確認 → **`-C, --cd <DIR>`** でエージェントの作業ルートを指定可能
- [x] `claude` CLI（claude-safe 経由）のワークスペース指定方法を確認 → **`--add-dir <directories...>`** でツールアクセスを追加可能。claude-safe はパススルー
- [x] サブエージェントからスクリプト実行時の CWD・ファイルアクセスを検証 → CWD は ai-development-hub ルート。`tmp/` への読み書き可能

**確定した実装方式**: CLI引数渡し + プロンプト文面埋め込みの併用
- codex: `-C "$WORKSPACE"` で作業ルート指定
- claude: `--add-dir "$WORKSPACE"` でディレクトリアクセス追加
- プロンプト末尾に `ワークスペース: $WORKSPACE` を追記（CLI がパスを活用できるようガイド）

**so-compare.sh:** [完了]

- [x] `-w PATH` オプション追加（ワークスペースパス参照、Codex/Claude にパスのみ渡す）
- [x] タイムアウト機構（`SO_TIMEOUT` 環境変数、デフォルト 240秒）
- [x] プロンプトサイズ警告（閾値超過時に stderr へ warning）
- [x] `-c` 使用時の非推奨警告
- [x] オプション引数の存在チェック（`-f`, `-o`, `-s`, `--prev`）
- [x] `codex` / `claude-safe` / `timeout` のコマンド存在チェック
- [x] shellcheck 指摘の修正（`$CODEX_CMD` / `$CLAUDE_CMD` のクォート）

**arena-compare.sh:** [完了]

- [x] モデル名のバリデーション（`[a-zA-Z0-9._-]+` に制限、パストラバーサル防止）
- [x] プロンプトサイズ警告
- [x] 全モデルタイムアウト時のガイダンスメッセージ
- [x] `-c` 使用時の非推奨警告
- [x] オプション引数の存在チェック
- [x] shellcheck 指摘の修正（`$AGENT_CMD` のクォート）

**両スクリプト共通:** [完了]

- [x] `source "$meta"` を `grep`/`cut` パースに置き換え

### 課題2: SO/Arena サブエージェント化 [完了]

元ドキュメント: `別プロダクト向けリポジトリ/docs/ai-automation-roadmap/02-so-arena-subagent.md`

- [x] SO スキル作成（`cursor/skill/so-compare/SKILL.md`）
  - `so-compare.sh` の呼び出し方法（オプション、出力形式）
  - プロンプト設計原則（上記「やってはいけないこと / やるべきこと」）
  - 結果読み込みと比較テーブル作成の手順
  - 合意判定基準
- [x] Arena スキル作成（`cursor/skill/arena-compare/SKILL.md`）
  - `arena-compare.sh` の呼び出し方法（オプション、モード別デフォルトモデル）
  - モデル選択の基準
  - `--resume-from` によるセッション継続
  - `summary.md` の読み込みと要約手順
- [x] Peer AI Review コマンドのサブエージェント対応リファクタ
  - SOオーケストレーターをサブエージェントに委譲
  - メインに結論サマリのみ返す構造
- [x] Arena Perspectives コマンドのサブエージェント対応リファクタ
  - Arena サブエージェントに委譲
  - メインに差分ポイントのみ返す構造
- [x] **判断ゲート**: エージェント定義ファイルの作成要否 → **不要**と判断（コマンドテンプレート内の Task tool + Skill Injection で十分）

#### サブエージェント分割フロー

**peer-ai-review（リファクタ後）:**

```
メインエージェント:
  「この修正方針をレビューして」
  → SO オーケストレーター サブエージェント起動

SO オーケストレーター:
  1. プロンプト構成（-w でパス参照のみ、-c 禁止）
  2. so-compare.sh 実行
  3. codex-stdout.txt, claude-stdout.txt 読み込み
  4. 3者比較テーブル作成
  5. 合意/不一致の判定
  6. メインに結論サマリのみ返す
     例: 「3者合意。explode の ?? '' は安全（Codex: 後段フィルタで除外、
     Claude: 既存動作の明示化）。strtotime は if ガード妥当。」
```

**arena-perspectives（リファクタ後）:**

```
メインエージェント:
  「この検証手順について意見を聞きたい」
  → Arena サブエージェント起動

Arena サブエージェント:
  1. arena-compare.sh 実行（-w でパス参照のみ）
  2. summary.md 読み込み
  3. 各モデルの回答を要約
  4. メインに差分ポイントのみ返す
```

### 課題3: 探索行動の「諦めない」深掘り [完了]

元ドキュメント: `別プロダクト向けリポジトリ/docs/ai-automation-roadmap/03-persistent-exploration.md`

**問題**: AIエージェントが原因探索の途中で「不可能」と早期に結論づけ、探索を止めてしまう。Sentry/ログでイベントが発生している以上、発生ルートは確実に存在するにもかかわらず。

- [x] 行動制約テンプレート作成（サブエージェントprompt注入用）
- [x] 突破口チェックリストのスキル化
- [x] 探索木の構造化フォーマット定義
- [x] **判断ゲート**: 成果物の配置先 → `cursor/skill/persistent-exploration/SKILL.md` に配置

#### 「不可能」判定の前提条件

「不可能」と結論づける前に、以下を全てチェックする:

- **データ的証拠**: Sentry/ログでイベントが発生しているか → 発生しているなら「不可能」ではない
- **代替アプローチ**: 最低3つの別アプローチを試したか
- **セカンドオピニオン**: SO で「本当に不可能か？」を検証したか
- **前提の再検証**: 「不可能」の根拠となっている前提自体が正しいか確認したか

#### 突破口チェックリスト

「UIから操作不可能」「再現できない」と判定した場合に試すべきアプローチ:

- API 直接呼び出し（`page.request`、`curl`、`session_api.sh`）
- フレームワークランタイムデータ操作（`browser_evaluate` でコンポーネントデータを変更）
- ネットワークリクエストのインターセプト・リプレイ
- 別のユーザー権限・別のアカウント
- DB の状態確認（バックフィル漏れ、マイグレーション履歴）
- バックエンドのバリデーション/ガードの有無確認（フロントエンドガードのみでバックエンドはスルーのケース）
- 過去のマイグレーション履歴を確認（データの歴史的経緯）

#### 探索木フォーマット

試したアプローチと結果を構造化し、未探索のブランチが残っている限り続行する:

```
<調査対象>
├── アプローチA → 結果 ❌
│   ├── 派生A-1 → 結果 ❌
│   ├── 派生A-2 → 条件付き可能 ⚠️（要確認事項）
│   └── 派生A-3 → 結果 ❌
├── アプローチB
│   ├── 手段B-1 → 失敗 ❌
│   ├── 手段B-2 → 成功 ✅
│   └── 手段B-3 → 未試行
├── アプローチC → 失敗 ❌
└── アプローチD → 未試行

凡例: ✅ 成功 / ❌ 失敗 / ⚠️ 条件付き / 未試行
```

#### 行動制約テンプレート（サブエージェント prompt 注入用）

サブエージェントに調査タスクを委譲する際、以下をプロンプトに含める:

```markdown
## 行動制約
- 「不可能」「再現できない」と結論づける前に、最低3つの代替アプローチを試すこと
- Sentry/ログでイベントが発生している場合、発生ルートは必ず存在する。「不可能」は許容しない
- 試したアプローチと結果を構造化して報告すること（探索木形式）
- 未探索のアプローチが残っている場合、それを明示すること
```

## 実装順序 [全Phase完了]

```
前提調査: CLI のワークスペース指定方法を確認 [完了]

Phase 0a: スクリプト改善 — ブロッカー [完了]
  - so-compare.sh: -w 追加、タイムアウト機構
  - 両方: source置き換え

Phase 0b: スクリプト改善 — 品質改善 [完了]
  - so-compare.sh: プロンプトサイズ警告、-c非推奨警告、引数チェック、コマンド存在チェック
  - arena-compare.sh: モデル名バリデーション、プロンプトサイズ警告、全タイムアウトガイダンス、-c非推奨警告、引数チェック
  - 両方: shellcheck修正

Phase 1: スキル作成 [完了]
  - SO スキル (cursor/skill/so-compare/SKILL.md)
  - Arena スキル (cursor/skill/arena-compare/SKILL.md)

Phase 2: コマンドリファクタ [完了]
  - 判断ゲート: エージェント定義不要（Task tool + Skill Injection で十分）
  - peer-ai-review.md のサブエージェント対応
  - arena-perspectives.md のサブエージェント対応

Phase 3: 探索行動原則 [完了]
  - 判断ゲート: cursor/skill/persistent-exploration/SKILL.md に配置
  - 行動制約テンプレート
  - 突破口チェックリストのスキル化
  - 探索木フォーマット定義
```

## 受入基準

| タスク | 完了条件 | 状態 |
|--------|----------|------|
| so-compare.sh 改善 | `-w /path` 指定で codex/claude がパス配下を参照した回答を返す。`-c` 使用時に非推奨警告が stderr に出る。`shellcheck` が warning 0 で通る | 完了 |
| arena-compare.sh 改善 | 不正モデル名が拒否される。全タイムアウト時にガイダンスが出る。`shellcheck` が warning 0 で通る | 完了 |
| SO スキル | 呼び出し手順 + プロンプト設計原則 + 結果読み込み手順 + 合意判定基準がスキルに記載 | 完了 |
| Arena スキル | 呼び出し手順 + モデル選択基準 + resume 手順 + summary.md 読み込み手順がスキルに記載 | 完了 |
| peer-ai-review リファクタ | サブエージェントが結論サマリのみ返す構造 | 完了 |
| arena-perspectives リファクタ | サブエージェントが差分ポイントの要約のみ返す構造 | 完了 |
| 行動制約テンプレート | サブエージェント prompt に注入可能なテンプレートが定義 | 完了 |
| 突破口チェックリスト | スキルとして SKILL.md 形式で定義 | 完了 |
| 探索木フォーマット | 構造化フォーマットと凡例が定義され、報告形式として使える | 完了 |

## スコープ外

- オーケストレーションツールとの連携設計（03 で言及あるが別スレッド扱い）

## 設計方針（Playwrightでの教訓）

- Skill = 機能リファレンス（何ができるか）
- Agent/Command = 意図の特化（何を達成するか）
- 重複はスキル側に寄せる
- 委譲判断はスキルに書かない（横断ルールやエージェント定義のdescriptionに委ねる）

## 関連ファイル

- `scripts/so-compare.sh` — SOスクリプト（課題1で改善済み）
- `projects/arena-compare/arena-compare.sh` — Arenaスクリプト（課題1で改善済み）
- `cursor/skill/so-compare/SKILL.md` — SOスキル（課題2で新設）
- `cursor/skill/arena-compare/SKILL.md` — Arenaスキル（課題2で新設）
- `cursor/skill/persistent-exploration/SKILL.md` — 探索行動原則スキル（課題3で新設）
- `cursor/command/verification/peer-ai-review.md` — Peer AI Reviewコマンド（課題2でリファクタ済み）
- `cursor/command/verification/arena-perspectives.md` — Arenaコマンド（課題2でリファクタ済み）
- `projects/arena-compare/docs/episodes/2026-03-04-subagent-integration.md` — Arena 側のエピソード記録
- `別プロダクト向けリポジトリ/docs/ai-automation-roadmap/02-so-arena-subagent.md` — 元課題ドキュメント（課題2）
- `別プロダクト向けリポジトリ/docs/ai-automation-roadmap/03-persistent-exploration.md` — 元課題ドキュメント（課題3）

## 残課題（低優先）

- `claude -p --add-dir` の実機検証（プロンプト埋め込みフォールバックがあるため急がない）
- `require_arg` の正規表現を `^-[a-zA-Z]` に緩和（実運用上の影響軽微）
- `arena-compare.sh` にも `timeout` コマンド存在チェックを追加
- persistent-exploration の行動制約を SO/Arena プロンプトに条件付き注入する仕組み
- 共通ライブラリ化（重複約20行、次の大きなリファクタ時に検討）

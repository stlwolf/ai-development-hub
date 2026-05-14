---
id: "01KRKZVWWQ6NHWJX51YXNG8SQB"
title: "Step 4-3 検証ゲート v1 の設計判断（質問駆動設計）"
date: 2026-05-15
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-3 設計判断"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/89"
    reason: "Step 4-3 観測層 Issue（本 Discussion の親）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-15-kickoff-step-4-3-verification-gate.md"
    reason: "Step 4-3 KickOff（仮置き 6 DI、ツール間引き継ぎコンテキスト）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion（15 論点・3 UC・arena 反映済み、全体スコープの正本）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-14-discussion-parse-and-state-management.md"
    reason: "Step 4-2 Discussion（7 問・成果物パース + 状態管理の設計判断・本 Step の基盤）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/88"
    reason: "Step 4-2 成果物 PR（bin/oe, lib/*.sh, tests/*, レビュー反映）"
  - type: design_context
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Plan Review / Compliance Review プロンプト規約・サブエージェント注入パターン（本 Step の最大の前提）"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/session-state.schema.json"
    reason: "KVS スキーマ（検証結果の書き込み先候補）"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/audit-log.schema.json"
    reason: "監査ログスキーマ（検証イベント追加検討の基盤）"
tags: [orchestration, mvp, step-4-3, question-driven-design, verification-gate, adversarial-review]
---

# Step 4-3 検証ゲート v1 の設計判断（質問駆動設計）

> Step 4-2（成果物パース + 状態管理、[PR #88](https://github.com/stlwolf/ai-development-hub/pull/88)）完了後、Step 4-3「検証ゲート v1」の実装に先立ち `question-driven-design` スキルで設計論点を探索する記録。
>
> 本 Discussion は **draft 状態で起草**し、各 Q について **推奨案を提示**した上で user との 1 問ずつの対話で確定する。全 Q 合意後に status: closed にし、KickOff の仮置きセクションを確定版に反映する。

## 進め方の前提

- `question-driven-design` スキル適用。実装前に設計ツリーを質問で網羅的に掘り下げ、暗黙の前提を明示化する
- KickOff §「想定 DI」の 6 項目 + 前提となるスコープ 1 項目 = 計 7 問を扱う
- 各 Q は「選択肢 + 推奨案 + 根拠」の形で起草し、user 確認後に status: closed に遷移
- 合意結果は後続の KickOff（[`2026-05-15-kickoff-step-4-3-verification-gate.md`](../plans/2026-05-15-kickoff-step-4-3-verification-gate.md)）で DI に変換

## Step 4-2 までの入力

Step 4-3 の設計判断に直接影響する既存資産:

### orchestration-engine 側

- `bin/oe` + `lib/*.sh` 7 ファイル — エンベロープ生成、ペイン spawn、ポーリング監視、6 値分類、KVS、監査ログ、クリーンアップ
- `schemas/session-state.schema.json` — `{session_id}.state.json` の atomic write 契約（検証結果の書き込み先候補）
- `schemas/audit-log.schema.json` — 7 種のイベント定義（検証イベント追加の余地あり）
- `schemas/failure-taxonomy.schema.json` — G4 6 値分類（検証は別軸 vs 同軸の判断要点）
- `@@OE_EXIT:{code}` マーカー仕様（検証用マーカーとの整合）
- サーキットブレーカー（1800s / 10 turns / 5 panes）

### canonical/skills 側

- `adversarial-review` SKILL — **2 モード定義**:
  - **Plan Review**: kickoff-to-plan 変換後、Plan 実行前
  - **Compliance Review**: サブエージェント完了報告後、マージ前
- 各モードの **プロンプトテンプレート**（タスク要件・完了報告・変更対象ファイルの 3 入力）が確定済み
- ツール別起動例（Cursor Task / `claude -p` / `codex -p`）も記載済み

### Step 4-0 / Step 4-2 で確定済みの方向性

- 検証ゲートは「サブエージェント出力を別エージェントが adversarial review する仕組み」（KickOff §「主題」）
- スキーマ変更は Step 4-5 で実施（本 Step では既存スキーマ拡張は最小限）
- `human_input` 監査イベントは未実装（本 Step で拾うかは Q として扱う）

## 設計質問と推奨案

各 Q の `status` は個別に管理（open / closed）し、全 Q が closed になった時点で本 Discussion 全体を closed にする。

### Q1: 検証モードのスコープ（v1 で何を実装するか）

**status**: open

**質問**: v1 は Plan Review / Compliance Review のどちらをサポートするか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. Plan Review のみ | KickOff/Plan ドキュメントの品質チェック | engine の動的部分（spawn/monitor）を使わない。スキル単体起動で十分な可能性 |
| **B. Compliance Review のみ** | サブエージェント完了後の実装照合 | engine の主用途（駆動）と整合。Step 4-2 のペイン管理が直接活きる |
| C. 両方 | Plan + Compliance | スコープ肥大。MVP には過剰 |

**推奨**: **B. Compliance Review のみ**

**根拠**:
- engine の主用途は「サブエージェントを駆動して成果物を得る」こと。検証ゲートはこの下流にある
- Plan Review は人間が `kickoff-to-plan` 直後に手動起動する性質が強く、engine 統合の価値が薄い（独立呼び出しで十分）
- Step 4-2 で構築した `spawn.sh` / `monitor.sh` / `capture.sh` / `audit.sh` がそのまま検証ペインの管理に転用できる
- v1 = MVP。Plan Review 統合は Step 4-5 以降で必要になれば追加

---

### Q2: 発火タイミング

**status**: open

**質問**: 検証ゲートをいつ発火させるか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 各タスク完了ごと（per-pane） | サブエージェント 1 ペインの `@@OE_EXIT:0` 検出時に即起動 | 早期フィードバック。並列性高い。検証 agent も並列起動でリソース消費↑ |
| **B. 全タスク完了後（end-of-session）** | 全管理ペイン完了後に検証フェーズへ遷移 | シンプル、リソース集約、状態遷移が明確。各タスク独立検証性は低下 |
| C. ハイブリッド（envelope で指定） | envelope の `task.verification.mode` で選択可能 | 柔軟。MVP には過剰、契約変更を伴う |

**推奨**: **B. 全タスク完了後（end-of-session）**

**根拠**:
- MVP は単一 UC（ai-development-hub 内のツール改善タスク、1 サイクル完走）を最優先（Step 4-0 Discussion §UC）
- 単一サイクルでは per-pane 検証と end-of-session 検証の差はほぼなく、後者の方が状態管理が単純
- `monitor.sh` の終了条件（全 `OE_DONE_PANES` 完了）にフックする実装が直線的
- per-pane 検証が必要になるのは Step 4-4 以降の E2E 検証で発見されたタイミングで追加（A への昇格パス）

---

### Q3: 検証エージェントの起動方法

**status**: open

**質問**: 検証用サブエージェントをどう起動するか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. 新ペイン spawn（Step 4-2 と同じ機構）** | `lib/spawn.sh` を再利用、検証用 envelope を生成して新ペインで起動 | 隔離。既存テスト基盤・モック流用可。リソース消費↑（追加 1 ペイン）|
| B. 既存ペインの再利用 | 完了したサブエージェントペインに検証プロンプトを送信 | リソース節約。状態混入リスク（前タスクの会話履歴が漏れる）|
| C. 同期外部コマンド | `claude -p` / `codex -p` を engine の同じプロセスで実行（ペインなし）| 単純。ただし `wez` 基盤と非対称、進捗が観測層から見えない |

**推奨**: **A. 新ペイン spawn**

**根拠**:
- Step 4-2 の `spawn.sh` / `monitor.sh` / `capture.sh` / `cleanup.sh` がそのまま転用可能。新規実装は最小化
- 検証 agent は前タスクの会話履歴を持たない方が adversarial review の独立性が保たれる（skill の「実装者の報告を信用するな」原則）
- 観測層からも検証進捗が確認できる（人間がペインを見て介入判断できる）
- CB / `human_input` etc. の既存セーフティが検証 agent にも適用される
- リソース消費は MVP では問題にならない（同時管理ペイン上限 5、CB 既存）

---

### Q4: 検証プロンプトの構成

**status**: open

**質問**: 検証 agent に何を渡すか?

`adversarial-review` skill の Compliance Review プロンプトテンプレートは以下 3 入力を要求:

1. タスク要件（Plan ファイルパス or 要件テキスト）
2. 完了報告（サブエージェントの返答 or コミットログ）
3. 変更対象ファイル（`git diff --name-only` の出力等）

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. envelope の `task.description` のみ | 要件は envelope から、変更ファイルは検証 agent が `git diff` で取得 | 最小実装、完了報告の信頼度が低くなる |
| **B. envelope + audit ログ + KVS** | 要件は envelope、完了報告は audit JSONL から、変更ファイルは KVS の `outputs` から | engine の既存出力を最大活用、再現性高 |
| C. 自由フォーマット | 検証エージェントが必要な情報を能動的に集める | 柔軟だが engine の出力契約が活きない |

**推奨**: **B. envelope + audit ログ + KVS**

**根拠**:
- engine の出力（envelope.json / audit.jsonl / session-state.json）が **検証 agent への構造化入力** として既に整っている
- skill の 3 入力に対応: 要件 = envelope の `task.description`、完了報告 = audit JSONL の最後の `state_change` イベント、変更ファイル = KVS の `outputs[]` または `git diff --name-only` (UC によって)
- 検証プロンプトを engine 側で組み立てる（テンプレート埋め込み）ことで、検証 agent への入力契約を駆動層ドキュメントだけで完結させられる（dogfood 原則）
- `adversarial-review` skill のプロンプト本文をそのまま使い、3 入力部分だけ engine が動的展開する

**未解決の細部**: 検証プロンプトを送る具体的手段（`wez pane send` で展開 vs 一時ファイル経由）は Plan で詰める。

---

### Q5: 検証結果の表現と KVS への書き込み

**status**: open

**質問**: 検証結果の語彙と保存先は?

skill の Compliance Review は `Status: Spec Compliant | Issues Found` を返す。engine 側は 6 値分類（`success/partial/blocked/timeout/protocol_error/retryable_failure`）を持つ。

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 既存 6 値の `partial` に集約 | 検証不合格 = `partial` として KVS に書く | 軸が同じになり混乱、検証軸が消える |
| **B. 別軸の検証結果フィールドを追加** | KVS に `verification: { result: "pass" \| "fail" \| "warn", reviewer_session_id, issues_count }` 等を追加 | 軸が明確、スキーマ変更必要（最小） |
| C. audit ログのみで表現 | 検証結果イベントを `verification_completed` 等で audit に出すのみ、KVS には書かない | KVS への書き込み責務を増やさない。問い合わせ時に audit を読む必要 |

**推奨**: **B. 別軸の検証結果フィールド**（`schemas/session-state.schema.json` への最小拡張）

**根拠**:
- 検証結果は実装結果 (`state`) とは独立した軸であり、同一 KVS の別フィールドが意味的に最も自然
- 「Step 4-3 はスキーマ変更を最小に」という制約と矛盾するが、検証結果を駆動層から問い合わせ可能にするには KVS が最適（audit JSONL は時系列、問い合わせコスト高）
- ただし「フィールド追加が必要 = スキーマ変更最小限ルール再確認」を user に確認したい
- 語彙は skill の `Spec Compliant` / `Issues Found` に対応する `pass` / `fail` を基本とし、将来 `warn` を追加可能な enum とする
- audit ログには `verification_started` / `verification_completed` の 2 イベントを追加（KickOff の `human_input` と同様、本 Step で追加）

**未解決の細部**: スキーマ変更を本 Step に含めることの可否。含めない場合、検証結果は audit ログのみ（案 C）にフォールバック。

---

### Q6: 不合格時のフロー

**status**: open

**質問**: 検証で `fail` / `Issues Found` だった場合のフローは?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. 記録のみ（v1）** | 結果を KVS / audit に書いて終了。人間が後から判断 | 最小実装、フロー単純、自動修正なし |
| B. 自動リトライ（回数制限） | 検証 fail → 同じタスクを再 spawn、N 回まで | 自動修正可能。再 spawn のコスト、サブ側の冪等性前提 |
| C. 人間エスカレーション | 検証 fail → 通知（`wez notify` 等）して停止、人間判断待ち | 安全、人間介入の入口がある。通知統合実装が必要 |

**推奨**: **A. 記録のみ（v1）**、ただし `wez notify` で完了通知は出す（既存機能）

**根拠**:
- 「v1」「MVP」のスコープに忠実。リトライ・エスカレーションは Step 4-4 の E2E 検証で必要性が明確になってから追加
- 記録のみでも検証ゲートとしての価値は確保される（後段の人間レビューに信頼できる検証結果を提供）
- `wez notify` は既存機能（`projects/wezterm-ai-mode/`）であり、通知統合は engine の `cleanup.sh` か `monitor.sh` 末尾に 1 行追加するだけ
- 自動リトライは「サブ側が同じ failure を繰り返す」リスクが高く、Discussion / DI で慎重に設計すべき。本 Step では避ける

---

### Q7: adversarial-review スキルとの統合方針

**status**: open

**質問**: skill の検証ロジックを engine にどこまで取り込むか?

skill が提供するもの:
- プロンプトテンプレート（Plan Review / Compliance Review 共通）
- ツール別起動コマンド（Cursor Task / `claude -p` / `codex -p`）
- 出力形式（`Status: ... / Issues: ... / Files reviewed: ...`）

engine 側が必要なもの:
- 検証 agent への注入（プロンプト構築 + 起動）
- 結果のパース（出力テキストから `Status` を抽出）
- KVS / audit への書き込み

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. engine が薄く統合（スキル prompt を埋め込み）** | engine 内に skill prompt を直接埋め込み、3 入力 (envelope / audit / KVS) を展開して送信 | 駆動層完結、skill の改訂を engine 側で追従する必要 |
| B. engine は spawn だけ、検証 agent が skill を読む | 検証 agent への envelope に `read_docs: [skill path]` `use_skills: [adversarial-review]` を指定 | 疎結合、skill 改訂に自動追従。検証 agent 側の負荷増（skill 解釈） |
| C. skill 側に engine 統合用 entry を追加 | `adversarial-review` skill に「engine から呼ばれた時の構造化入力受け取り口」を追加 | クリーン、ただし skill 側の改修が必要、スコープ越境 |

**推奨**: **B. envelope に `use_skills` 指定（skill 改訂への自動追従）**

**根拠**:
- envelope schema には既に `task.use_skills` と `task.read_docs` が存在する（Step 4-1 確定、Step 4-2 で実装ペインに渡している）。検証 agent でも同じ仕組みを使えば対称
- skill の prompt 改訂時に engine 側の再実装不要（疎結合）
- engine の責務は「検証 agent を spawn し、入力 envelope に必要なコンテキストを構造化注入する」に純粋化される
- 検証 agent は envelope を読み、`adversarial-review` skill の Compliance Review プロンプトに従って動作する（出力形式も skill 規定に従う）
- engine 側は出力テキストから `Status: Spec Compliant | Issues Found` を grep してパースする（マーカー方式の延長）

**未解決の細部**:
- 出力パースのマーカー: skill の出力形式に明示マーカー（例: `@@OE_VERIFY:pass` 等）を追加するか、`Status: Spec Compliant` テキストを正規表現で拾うか。前者は skill 改修を伴う

---

## 完了条件案（仮置き）

全 Q 合意後、KickOff §「完了条件」に反映する。

- 検証ゲートが Compliance Review モードで動作する（end-of-session 発火、新ペイン spawn、envelope に skill 指定）
- 検証結果が KVS（拡張）と audit ログに記録される
- 不合格時も engine は停止せず記録のみ（v1）
- shellcheck で全スクリプトが pass
- テストスイート: 検証プロンプト構築 / 結果パース / KVS 拡張のユニットテスト + E2E スモーク（モック）

## 未解決の論点（Discussion 内で扱わないもの）

- 検証 agent 自体の選択（`claude -p` / `codex -p` / Cursor Task）→ 実装フェーズで決める / envelope で指定可能にする
- 検証プロンプトの細部最適化 → skill 側の Compliance Review プロンプトに従う
- 検証エージェントへの「変更対象ファイル」リストの構築方法（KVS の `outputs[]` で十分か、`git diff` も組み合わせるか）→ Plan で詰める

## 進め方

1. user が Q1 から順にレビューし、推奨案で OK か別案かを判断
2. 合意した Q から個別に `status: closed` + 決定内容を追記
3. 全 Q closed 後、本 Discussion 全体を `status: closed` に
4. KickOff の「仮置き」セクションを Discussion 結果で確定
5. `kickoff-to-plan` skill で Plan に変換

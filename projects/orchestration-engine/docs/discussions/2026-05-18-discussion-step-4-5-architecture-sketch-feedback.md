---
id: "01KRXJ27FDE16KZJ3RR1H6MW63"
title: "Step 4-5 architecture-sketch.md フィードバック反映 + frozen 化の設計判断（質問駆動設計）"
date: 2026-05-18
type: discussion
status: closed
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の最終 Step (Step 4-5)"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "本 Step の更新対象 (Phase 3 Synthesis 成果、frozen 化候補)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "Step 4-4 完了時の Episode (Phase 4 最後の Step の経緯)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-18-decision-reviewer-output-file-redirect.md"
    reason: "Step 4-4 の ADR (Phase 4 最後の設計判断)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-16-decision-verification-gate-design.md"
    reason: "Step 4-3 ADR (検証ゲート v1 のアーキテクチャ確定形)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-14-decision-cleanup-strategy.md"
    reason: "Step 4-1 ADR (クリーンアップ戦略)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-14-decision-permission-separation-mvp.md"
    reason: "Step 4-1 ADR (権限分離方針)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-14-decision-issue-20-phase-convergence.md"
    reason: "Step 4-1 ADR (Issue #20 との Phase 収束)"
  - type: source_material
    ref: "projects/orchestration-engine/README.md"
    reason: "engine プロジェクト入り口 (本 Step では touch しない予定、整合確認のみ)"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md"
    reason: "Step 4-4 Discussion (QDD パターンの直近事例)"
tags: [orchestration, mvp, step-4-5, question-driven-design, architecture-sketch, feedback, frozen]
---

# Step 4-5 architecture-sketch.md フィードバック反映 + frozen 化の設計判断（質問駆動設計）

> Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 MVP の最終 Step。Step 4-0〜4-4 で得た学びを `projects/orchestration-research/synthesis/architecture-sketch.md` に最小限反映し、文書全体を **Phase 3 完了 + Phase 4 完了報告までの記録** として frozen 化する。
>
> 事前合意済みの **役割案 X** (architecture-sketch は Phase 3 snapshot として frozen 化、新たな living 役割は与えない): synthesis/ 全体を frozen 維持し、architecture-sketch だけが「Phase 3 完了時点の素案 + Phase 4 完了報告」の 2 層構造になる。設計の真正な記録は engine 配下の ADR 群が担う。
>
> 本 Discussion は draft 状態で起草し、各 Q について推奨案を提示した上で user との 1 問ずつの対話で確定する。全 Q 合意後に status: closed にし、KickOff の仮置きセクションを確定版に反映する。

## 進め方の前提

- `question-driven-design` スキル適用。実装前に設計ツリーを質問で網羅的に掘り下げ、暗黙の前提を明示化する
- Step 4-3 / 4-4 の Discussion 構成 (7-8 Q 構成、各 Q に推奨案 + 代替案 + 根拠) を踏襲
- 合意結果は後続の KickOff (起草予定) で DI に変換、`kickoff-to-plan` で Plan 化、本 Step は doc 更新のみで実装コードは無いため Phase 構造は軽量 (Phase A: 更新内容ドラフト → Phase B: PR レビュー → Phase C: Episode + Epic close)

## Step 4-0〜4-4 までの入力 (本 Step の素材)

- **ADR 5 件** (`projects/orchestration-engine/docs/decisions/`): Step 4-1 cleanup strategy / permission separation / issue #20 phase convergence、Step 4-3 verification gate design、Step 4-4 reviewer file redirect
- **Episode 15+ 件** (`projects/orchestration-engine/docs/episodes/`): 各 Step の経緯・観察記録
- **Plan + KickOff + Discussion 各 Step** (`projects/orchestration-engine/docs/plans/` および `docs/discussions/`): 設計過程の正本
- **engine 実装本体** (`lib/*.sh`, `bin/oe`, `schemas/*.json`, `scripts/validate-*.sh`): Phase 4 で実際に組み上がった構造
- **派生 Issue 8 件** (open): #92 / #93 / #98〜#102 — MVP 後拡張候補

---

## Q1: 更新の追記境界 (どこまで in-place 修正、どこから新節追記か)

**推奨案 (採用)**: **基本は新節追記 (§11 として末尾追加)、in-place 修正は最小限**。

- in-place 修正の対象:
  - **§9 フェーズ計画**: Phase 4 (4-1〜4-5) の `[ ]` → `[x]` チェック。Phase 完了の表示
  - 本文記述で **明確に古くなった部分** のみ (例: §3 で「ゲートが実行されたか」問題への対応として Step 4-3 の `verification_protocol_error` event を 1 文言及、§5 MVP 構成の「最初のユースケース」現状確認)
- 新節 §11 「Phase 4 完了報告 (2026-05)」で集約:
  - 完成した engine の構成サマリ
  - Phase 4 で確認された設計事実
  - 派生 Issue リスト
  - frozen 宣言と「以降の設計判断は `projects/orchestration-engine/docs/decisions/` 配下を参照」リダイレクト

**代替案**:
- (a) 全文リライト: 役割案 X の方針 (Phase 3 snapshot 保存) と矛盾。棄却
- (b) §11 のみ追加で §1〜§10 完全保存: 「ゲートが実行されたか問題は §3 で言及されたまま回答先が無い」など読者の混乱要因が残る。最小限の in-place 修正で誘導する方が親切

**根拠**:
- Step 4-3 ADR (verification gate) で「ゲート実行確認」が解決済み、その事実を §3 に脚注的に追加するのは整合
- 大規模 in-place 修正は git diff のレビューコストが高く、また「Phase 3 当時の認識」を歴史的記録として保つ価値も損なう

---

## Q2: フィードバック抽出方針 (どの Episode / ADR から何を反映するか)

**推奨案 (採用)**: **ADR 5 件を主、Episode は Phase 単位のサマリのみ**。

- **§11 (新節) に集約する Phase 4 完了報告の構成**:
  1. Phase 4 全体サマリ (1 段落): Step 4-1〜4-5 の到達点 (MVP として 1 サイクル E2E 完走、mock 306 assertions、実機 smoke 2 回完走)
  2. **設計判断の集約** (ADR 5 件への参照リスト):
     - Step 4-1 ADRs: cleanup-strategy / permission-separation-mvp / issue-20-phase-convergence
     - Step 4-3 ADR: verification-gate-design (検証ゲート v1)
     - Step 4-4 ADR: reviewer-output-file-redirect (file redirect 経路 + skill mapping 表)
     - 各 ADR について 1 行サマリ + リンク
  3. **観察された設計事実** (3〜5 件、Episode から抽出):
     - mock テストが捕捉できない種類のバグ (viewport-only な wez pane capture 等) を実機 smoke が検出した
     - 駆動層ドキュメント (Discussion/KickOff/Plan) のみでツール間引き継ぎ (Cursor → Claude Code) が成立した
     - so-compare 2 段階レビューが実装前の Critical 発見と実装後の品質チェックに有効だった
     - target / reviewer の出力経路差 (短文 vs 長文) で同じ wez pane capture が違う結果を生んだ
  4. **派生 Issue 集約**: #92 / #93 / #98〜#102 の 7 件を表形式で列挙、各 Issue は MVP 後拡張候補として位置づける
  5. **frozen 宣言 + redirect**: 「以降は engine/docs/ 配下を正本とする」
- **§3 認知協調層** に 1 段落追記: 「Step 4-3 で検証ゲート v1 が `verification_completed` audit イベント + `verification_summary` 集計 + `circuit_breaker_triggered` の組み合わせで『ゲートが実行されたか』を構造的に証明する形に確定。詳細は ADR `2026-05-16-decision-verification-gate-design.md`」
- **§5 MVP 構成** の「最初のユースケース」を 1 文更新: 「Step 4-4 で実 agent (cursor-agent/composer-2 を target、claude/sonnet-4-6 を reviewer) で 1 サイクル完走実証済み」

**代替案**:
- (a) Episode 15 件全部からエッセンスを抽出: §11 が肥大化、frozen 化と矛盾
- (b) ADR への参照リストのみ (観察事実 / 派生 Issue 省略): 「Phase 4 で何を学んだか」が伝わらず、後発者が読む価値が落ちる

**根拠**:
- ADR が「設計の正本」なので素描の役割は「ADR 群を index する」こと
- 観察事実は素描の §1〜§8 で当初書かれた設計仮説と対比可能な形で残す価値あり (3〜5 件で十分)

---

## Q3: §9 フェーズ計画の更新方法 (Phase 5 の有無、次フェーズの記述)

**推奨案 (採用)**: **Phase 4 全 Step を `[x]` チェック + 「Phase 5 は本 Step 時点で未定」と明記**。

- §9 の表を更新:
  - Phase 3 完了条件: 既に `[x]` で完了済 (現状維持)
  - Phase 4: 4-1〜4-5 すべて `[x]` (Step 4-5 = 本 Step が完了時点で全完了)
- §9 末尾に短い注記を追加:
  - 「Phase 5 (もしあれば) のスコープは本 Step 時点では未定。orchestration-engine の MVP 後拡張は派生 Issue 群 (#92 / #93 / #98〜#102) で個別管理。次の大きなフェーズが必要になった時点で別 Epic として起票する」

**代替案**:
- (a) Phase 5 を本 Step で定義 (例: 「Phase 5 = MVP 後拡張の優先度仕分け + 実行」): 本 Step のスコープを超える、別 Discussion 必要
- (b) §9 全文削除: 履歴情報の喪失、ADR/Episode の起点リンクとしての価値も損なう

**根拠**:
- Epic #19 のタスクは Step 4-5 まで明示されている、Phase 5 は別 Epic として扱うのが自然
- 派生 Issue 8 件 (open) が MVP 後拡張の backlog として機能している、新 Phase で枠を作らなくても進行可能

---

## Q4: §11 新節「Phase 4 完了報告」の文書量と構造

**推奨案 (採用)**: **A4 1 ページ程度 (~50 行のマークダウン)、見出し 4 段構造**。

```
## 11. Phase 4 完了報告 (2026-05)

### 11.1 到達点 (3-5 行)

### 11.2 設計判断の集約 — ADR 5 件 (各 1 行サマリ + リンク、合計 ~10 行)

### 11.3 観察された設計事実 (3-5 件、各 2-3 行で計 ~15 行)

### 11.4 派生 Issue (MVP 後拡張候補、表 ~10 行)

### 11.5 文書ステータス更新 (frozen 宣言 + redirect、~5 行)
```

**代替案**:
- (a) もっと簡潔 (~20 行、§11.1〜§11.5 を統合): 後発者が読む情報が薄くなる
- (b) もっと詳細 (~150 行、各 ADR を再要約): ADR 自体を読めば良い、重複

**根拠**:
- 1 ページに収めることで「architecture-sketch.md 全体を 1 回で読み切れる」状態を維持
- 詳細は ADR / Episode へのリンクで担保

---

## Q5: §3 認知協調層 / §4 正準エージェント定義の in-place 更新範囲

**推奨案 (採用)**: **§3 に 1 段落、§4 に 1 段落、それぞれ 1 行のリンク追記程度の最小更新**。

- §3 認知協調層への追記 (Phase 4 確定事項として):
  - 「ゲートが実行されたか」問題の現実化形 (Step 4-3 verification_completed + verification_summary + circuit_breaker_triggered の組み合わせ)、詳細は ADR リンク
  - reviewer の出力経路は file redirect (`tee`) に確定 (Step 4-4 ADR リンク)
- §4 正準エージェント定義への追記:
  - envelope schema は `schemas/envelope.schema.json`、audit schema は `schemas/audit-log.schema.json`、state schema は `schemas/session-state.schema.json` に確定 (Step 4-1〜4-3 で経験的に固まった成果物の場所を明記)
  - 「未決定事項」の表は frozen 表示 (Phase 4 で確定したものは項目化、未確定で派生 Issue 化されたものは Issue 番号併記)

**代替案**:
- (a) §3 / §4 を全面リライト: 役割案 X と矛盾、Phase 3 当時の認識記録が失われる
- (b) §3 / §4 ノータッチ: 「Phase 3 段階の未決定事項」がそのまま残り、後発者が「未決定のまま」と誤解する

**根拠**:
- in-place は「未決定 → 確定」の明示と「成果物の場所」の追記に絞ることで、Phase 3 認識を歴史として保ちつつ Phase 4 結果と橋渡しできる

---

## Q6: synthesis/ 他文書の扱い再確認 (context-foundation / skills-level-patterns / harness-engineering-mapping)

**推奨案 (採用)**: **synthesis/ 配下の他文書 (3 件) は本 Step では完全に touch しない**。

- 対象外:
  - `context-foundation.md` (~25 KB)
  - `skills-level-patterns.md` (~15 KB)
  - `harness-engineering-mapping.md` (~8 KB)
- 理由: これらは Phase 3 の研究成果として独立しており、Phase 4 実装で大幅に「修正されるべき」内容が見つかっていない。架空の Phase 5 で必要になればその時に扱う

**代替案**:
- (a) 3 文書とも Phase 4 完了報告セクションを各々追加: synthesis/ 全体が一気に変質、スコープ拡大
- (b) `harness-engineering-mapping.md` のみ touch (engine 実装でハーネス語彙との対応が具体化された): 個別判断としては理解できるが、本 Step は最小スコープ優先

**根拠**:
- synthesis/ 全体を frozen のままにすることで「synthesis = Phase 3 アウトプット」「engine/docs/ = Phase 4 以降のアウトプット」という棲み分けが明確になる
- 1 文書 (architecture-sketch.md) だけが 2 層構造になることへの違和感は §11 frozen 宣言で「この文書だけが Phase 4 完了報告まで追記、他は Phase 3 完了時点のスナップショット」と明示することで解消

---

## Q7: 出力デリバラブル (PR 数、必要文書)

**推奨案 (採用)**: **1 PR にまとめる**。

- PR に含める成果物:
  - architecture-sketch.md 更新差分 (§9 in-place + §3/§4/§5 最小追記 + §11 新節 + 冒頭 frozen 宣言)
  - 本 Discussion (status: closed に変更)
  - 新 KickOff (`2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md`、Step 4-5 用、status: confirmed)
  - 新 Plan (`2026-05-18-plan-step-4-5-architecture-sketch-feedback.md`)
  - 新 Episode (`2026-05-18-episode-step-4-5-implementation.md`) — Step 4-5 の経緯記録
  - **新 Phase 5 direction KickOff (`2026-05-18-kickoff-phase-5-direction.md`、status: draft、Q9 反映)** — Phase 4 完了時点の方向感メモ、Phase 5 着手時に confirmed 化する想定
- PR description で **Closes #19** (Epic 自体を close)、Refs として派生 Issue 群を列挙
- **新 ADR は作成しない**: 本 Step は doc 更新で、新たな設計判断ではない (=「素描を frozen 化する」は手続的判断であり ADR 不要)

**代替案**:
- (a) PR 分割 (素描更新 / Discussion+KickOff+Plan / Episode で 3 PR): merge 順序の管理コストが上回る
- (b) Episode 不要: Step 4-1〜4-4 は全て Episode を残しているので、4-5 だけ作らないと整合性が崩れる

**根拠**:
- 本 Step は文書のみで実装無し、1 PR の差分量は中程度 (~200〜300 行) に収まる想定
- Epic close の節目になる PR なので、関連文書を 1 つにまとめてレビューしやすくする

---

## Q8: 冒頭 frozen 宣言の文言案 + redirect 注記の具体

**推奨案 (採用)**:

architecture-sketch.md 冒頭 (現在の `> Q&A 形式の設計議論...` の引用ブロックの直下) に以下を追加:

```markdown
> **文書ステータス (2026-05-18 更新)**
>
> 本文書は Phase 3 Synthesis 完了時点の素案 (§1〜§10) に、Phase 4 MVP 完了報告 (§11、2026-05) を加えた **2 層構造の frozen 文書**。以降の orchestration-engine の設計判断は [`projects/orchestration-engine/docs/decisions/`](../../orchestration-engine/docs/decisions/) 配下の ADR を正本とし、本文書には追記しない。
>
> Phase 4 完了時点の engine の使い方 / 構成は [`projects/orchestration-engine/README.md`](../../orchestration-engine/README.md)、Step ごとの経緯は [`projects/orchestration-engine/docs/episodes/`](../../orchestration-engine/docs/episodes/) を参照。
```

§11.5 文書ステータス更新セクション末尾には次を追加:

```markdown
本文書はここで frozen とする。Phase 5 以降 (もしあれば) の orchestration-engine の進化は別 Epic + engine 配下の Discussion/KickOff/Plan/Episode/ADR で記録する。
```

**代替案**:
- (a) frozen 宣言を section §11 内のみに置き、冒頭引用ブロックには書かない: 読者が末尾まで読まないと frozen と分からない
- (b) frozen 宣言文言を更に簡潔 (1 行): 「以降は engine/docs/ 参照」だけだと redirect 先が複数 (decisions / episodes / README) あることが伝わらない

**根拠**:
- 冒頭の `>` 引用ブロックは原版から残す (Phase 3 当時の文脈)。直下に文書ステータスを追加することで「いつまで何が書いてあるか」を 1 目で把握可能
- redirect 先を 3 つ (decisions / README / episodes) 明示することで、後発者が用途に応じて読むべき場所を選べる

---

---

## Q9: Phase 5 / 本実装移行の現時点まとめの配置形式

**背景**: Step 4-5 = Epic #19 Phase 4 の最終 Step。Phase 4 完了後にどう進むかについて「現時点での方向感を何らかの形で残したい」という意向あり。初稿では本 Discussion の末尾に補遺セクションを追加する案だったが、user 指摘により、本 Discussion は「architecture-sketch frozen 化の設計判断」スコープであり Phase 5 方向感はスコープが異なる (次のフェーズへの橋渡し = KickOff 寄り) と判明。

**推奨案 (採用)**: **KickOff 形式の独立 doc を新規作成**。

- ファイル: `projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md`
- status: `draft` (DI 未確定、Phase 5 着手時に正式 `confirmed` に成熟させる前提)
- 性質: 「次のフェーズの KickOff の前段」。Step 4-1〜4-4 の Plan/KickOff と並ぶ位置で、後発者が見つけやすい
- 既存 KickOff スキーマを踏襲しつつ、DI を `候補` として扱う

**KickOff 内容構成 (5 項目を KickOff の語彙に置換)**:

1. **背景・現状認識** = Phase 4 完了時点の engine の到達点と限界
2. **Path 候補 (Path α / β / γ) と各主要 DI 候補**:
   - Path α: MVP 継続改良 — 派生 Issue (#92 / #93 / #98〜#102) 消化 + 検証ゲート v2 等
   - Path β: 本実装移行 — production 用途化、別プロジェクトでの dogfood、配布形態 (CLI package?) 等
   - Path γ: MVP を停止し別 Epic に注力 — [#20](https://github.com/stlwolf/ai-development-hub/issues/20) / [#24](https://github.com/stlwolf/ai-development-hub/issues/24) / [#37](https://github.com/stlwolf/ai-development-hub/issues/37) など
3. **各 Path の利益 / リスク / 必要工数の見積もり** (現時点の主観、確定値ではない明示)
4. **現時点の傾き** (どの Path が濃いか、暫定意向)
5. **判断時期 / 判断のトリガー + 次アクション** (Phase 5 正式 KickOff 起草の入力として再利用される想定)

**実装方針**: KickOff 本文 (上記 5 項目) は、Plan/実装フェーズ (Phase A 駆動層 doc 起草時) で起草する。項目 3 (利益/リスク/工数) と項目 4 (傾き) は user の主観が必要なので、起草時に空欄テンプレートで叩き案を提示 → user 入力 → 確定の流れにする。Step 4-5 Discussion を closed にする際、本 KickOff (draft) も同時に PR に含めて merge する。

**代替案**:
- (a) 本 Discussion 末尾の補遺セクションとして追加 (初稿の案): スコープ違い (architecture-sketch frozen 化 ≠ 次フェーズ方向感)、user 違和感
- (b) 方向感メモ専用 doc (`docs/memos/` 等の新カテゴリ): 新しいカテゴリ追加はリポジトリ規約を増やす、既存 `docs/plans/` カテゴリで充足可能
- (c) Phase 5 用 Discussion の新規起草 (QDD 形式): 現時点で QDD まで成熟していない、早すぎる
- (d) Epic #19 のコメントに追記: 検索性が doc より劣る、PR とは独立で時系列が分散
- (e) 新規 Issue として起票: まだ決めない段階で Issue 化はプレッシャー化

**根拠**:
- 「次のプランに続くキックオフに近い」という user の感覚と整合 (KickOff style の構造化、Plan に発展する前提)
- `docs/plans/` に配置することで既存 Step 4-1〜4-4 の Plan/KickOff と並ぶ位置で発見性が高い
- `status: draft` 明示で「現時点の方向感、Phase 5 着手時に確定」のニュアンスが明示できる

---

## 確定状況サマリ (合意後に書き換え)

| Q | テーマ | 採用案 | user 合意 |
|---|---|---|---|
| Q1 | 追記境界 | 新節 §11 + §9/§3/§4/§5 最小 in-place | ✅ |
| Q2 | フィードバック抽出方針 | ADR 主、Episode は Phase サマリ、観察事実 3-5 件 | ✅ |
| Q3 | §9 フェーズ計画 | Phase 4 [x] + Phase 5 未定明記 | ✅ |
| Q4 | §11 文書量 / 構造 | ~50 行、5 サブ節 | ✅ |
| Q5 | §3 / §4 更新範囲 | 各 1 段落の最小追記 | ✅ |
| Q6 | synthesis/ 他文書 | 完全 touch しない | ✅ |
| Q7 | PR デリバラブル | 1 PR、Discussion+KickOff(Step 4-5)+Plan+Episode+sketch 更新+Phase 5 direction KickOff(draft)、ADR 不要、Closes #19 | ✅ (Q9 確定で direction KickOff 追加) |
| Q8 | frozen 宣言文言 | 冒頭 + §11.5 末尾の 2 箇所、redirect 先 3 つ明示 | ✅ |
| Q9 | Phase 5 方向感の配置形式 | 独立 KickOff doc (`docs/plans/2026-05-18-kickoff-phase-5-direction.md`、status: draft、Plan/実装フェーズで本文起草) | ✅ |

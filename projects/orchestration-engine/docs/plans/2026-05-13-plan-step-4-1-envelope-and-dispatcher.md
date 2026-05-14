---
id: "01KRH3H3T62NDBJXZH1HKGVH2G"
title: "orchestration-engine Step 4-1 エンベロープ + ディスパッチャ骨格 Plan"
date: 2026-05-13
type: plan
status: draft
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md"
    reason: "変換元 KickOff。kickoff-to-plan SKILL に従い本 Plan を生成"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-1（観測層・親 Epic）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion（15 論点・3 UC・arena 反映済み）"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "研究フェーズ正本（frozen）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/37"
    reason: "Harness Engineering G1〜G7 ギャップ"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/81"
    reason: "Step 4-0 サブ Issue"
  - type: design_context
    ref: "docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md"
    reason: "CLI ラッパー 4 層モデル（DI-8 の前提）"
tags: [orchestration, mvp, step-4-1, plan, envelope, dispatcher, open-loop, observability]
---

# Step 4-1: エンベロープ + ディスパッチャの骨格 — Plan

> 本 Plan は [KickOff](2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md) を `kickoff-to-plan` SKILL に従い変換したもの。KickOff の 12 Decision Items を 5 フェーズに配置し、各 DI を「決定 TODO」+「成果物化 TODO」のペアで展開する。

## 変換上の判断メモ

> KickOff は「Decision Items」主軸の非標準構造（`## 実装計画` ではなく `## Decision Items`）。以下の判断で変換した。

1. **DI → Step 変換**: KickOff §次アクション の 5 フェーズ構成をそのまま Step 構造に採用。各フェーズ内で DI を「決定 TODO」+「成果物化 TODO（ADR / Episode / Schema 等）」のペアに展開
2. **依存関係の順序**: KickOff §DI 依存関係 の Mermaid グラフに基づきフェーズ順序を決定。直列パス `DI-3 → DI-10 → DI-1` をフェーズ 1 の Step 1〜3 に配置、`DI-2` は `DI-1` 確定後のフェーズ 3 に配置
3. **完了条件 → 最終検証**: KickOff §完了条件 の 7 項目をそのまま最終検証 TODO に展開
4. **除外論点 → Context 注記**: 論点 1/2/10 は「判断済み・延期」のため Context 注記に配置
5. **ドメイン判断要否ヒント**: ユーザー指示により各 Step に付与。STOP 判断の根拠として使用（ドメイン判断不要なら連続実行可）
6. **KickOff §スコープ外**: 本 Plan でも同様にスコープ外。Context 注記に配置
7. **STOP 配置**: Step 0 完了後 + フェーズ 1〜5 各完了後 = 計 6 STOP。混合ゲート方針（ドメイン判断不要部分は連続実行）
8. **背景セクション**: KickOff §背景 の内容は Context 注記に配置（実行を伴わない情報）
9. **DI 依存関係グラフ**: KickOff の Mermaid をそのまま Context の「依存構造」として参照（再掲しない）

## Context

### 前提（KickOff で確定済み）

- Step 4-0 Discussion で MVP スコープ・3 UC・15 論点の依存関係が仮置き確定
- 研究フェーズ（`projects/orchestration-research/`）は frozen。参照のみ、改変禁止
- 観測層 Issue [#84](https://github.com/stlwolf/ai-development-hub/issues/84) は read-only（進捗トラッキング先）
- 論点 1（docs 配置）: 既存パターン踏襲確定（KickOff §除外論点）
- 論点 2（research との関係）: frozen 参照のみ確定（KickOff §除外論点）
- 論点 10（dogfood 化判断基準）: 4-5 で再評価（KickOff §除外論点）

### 設計入力

- KickOff: [`docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md`](2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md)
- Discussion: [`docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md`](../discussions/2026-05-13-discussion-engine-scope-and-goals.md)
- architecture-sketch.md: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)（frozen）
- DI 依存関係グラフ: KickOff §DI 依存関係（Mermaid `flowchart`）を参照

### スコープ外（本 Plan では扱わない）

- 設計判断そのものの確定を超えた実装コーディング（4-2 以降で段階的に進める）
- Discussion 本体・`architecture-sketch.md` の改変（frozen）
- 観測層 Issue の作成・更新（#84 は作成済み）
- B-2 「KickOff↔Plan 自動昇格フロー」課題の Issue 化（Step 4-5 で判断）
- 依存表現の JSON Schema 正本化（episode に記録済み、Step 4-5 で判断）

### UC 略記

- `UC-1`: メインエージェントによる調査サブエージェントの監視・軌道修正
- `UC-2`: 並列実装サブエージェント間のファイルベース非同期協調
- `UC-3`: 人間の俯瞰観測と TTY 直接割り込み（監査ログ付き）

## Pre-Implementation

- [ ] READ: [`docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md`](2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md) — KickOff 全文（Decision Items / DI 依存関係 / 完了条件 / 次アクション）
- [ ] READ: [`docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md`](../discussions/2026-05-13-discussion-engine-scope-and-goals.md) — Discussion 全文（15 論点・3 UC・arena Appendix、各 DI の元論点参照用）
- [ ] READ: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md) — architecture-sketch §5 MVP 構成（frozen、必要箇所のみ）
- [ ] READ: [`docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md`](../../../../docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md) — CLI ラッパー 4 層モデル（DI-8 の前提）

## Step 0: 前提調査

> ドメイン判断要否: **必要**（合流タイミング・既存パターンの有無が後続フェーズ全体に影響）

- [ ] [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 2 現状確認: `gh issue view 20` + コメント参照で中間層プロトコル設計の進捗を把握。DI-10 の合流タイミング判断材料を取得
- [ ] 既存 `canonical/skills/` の SKILL.md に `outputs:` 相当があるかの確認（DI-6 の前提）: `canonical/skills/*/SKILL.md` の frontmatter を grep
- [ ] 既存 `canonical/hooks/` 内の schema 検証パターンの有無確認（DI-15 の前提）: `canonical/hooks/` を調査
- [ ] `wez pane capture` の所要時間計測（DI-2 SLO の前提）: `time wez pane capture <pane-id> --lines 50` 等で実測
- [ ] `timeout` コマンドと `wez pane kill` の連携挙動確認（DI-12 の前提）: `timeout 5 sleep 10` + `wez pane kill` で動作検証

## GATE: Step 0 前提確認

- [ ] [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 2 の現状が把握でき、DI-10 の合流タイミング案が言語化できる状態であること
- [ ] DI-6 / DI-15 の既存パターン有無が判明していること
- [ ] SLO / サーキットブレーカーの数値仮置きに必要な実測値が取得できていること

## STOP: Step 0 完了 — ユーザーに前提調査結果を報告し、フェーズ 1 着手の承認を待つ

---

## フェーズ 1: ディスパッチャ責務確定（DI-1 / DI-3 / DI-8）

> ドメイン判断要否: **必要**（ディスパッチャの設計方針は MVP 全体の基盤。3 案の選択はドメイン判断）

### Step 1: DI-3 — UC 中間層プロトコル要件のサブセット確定

- [ ] Discussion §5 の各 UC「中間層プロトコル要件」5 項目を一覧化し、4-1 で骨格を作る最小サブセットを選定
  - 案 A: 3 UC 共通の最小集合（`session_id ⇔ pane_id` registry、capture API、`wez pane send`、状態語彙閉集合）のみ
  - 案 B: 案 A + UC-2 ファイルベース KVS スキーマ
  - 案 C: UC-3 dashboard API は 4-3/4-4 延期、UC-1/UC-2 中心
- [ ] 選定結果を Episode に記録（`docs/episodes/` に新規作成）

### Step 2: DI-10 — #20 Phase 2 合流点確定

- [ ] Step 0 の調査結果を踏まえ、中間層プロトコル仕様の ADR 配置先を確定
  - 案: engine 側 `decisions/` 単独 / wezterm-ai-mode 側 / 相互参照
- [ ] 合流タイミングを確定: 4-1 Plan 着手前（済）/ 4-1 完了時 / 4-2 着手前
- [ ] 確定結果を `docs/decisions/` に ADR として蒸留

## ADR: DI-10 中間層プロトコル合流方針を記録

### Step 3: DI-1 — 中間層責務範囲確定

- [ ] DI-3 と DI-10 の確定結果を踏まえ、ディスパッチャの中間層内包範囲を確定
  - 案 A: CLI 起動 + envelope 注入のみ（中間層 API は別レイヤ）
  - 案 B: 最小限の中間層 API 呼び出し（capture / send / kill）を薄いライブラリ層として統合
  - 案 C: UC ごとの「監視ループ関数」を提供する Bash 関数集
- [ ] 確定結果を Episode に記録

### Step 4: DI-8 — 最小解析ラッパーの中身確定

- [ ] 前提: DI-1 / DI-3 確定後に着手（DI 依存関係グラフ準拠）
- [ ] ディスパッチャが持つ「ポーリング出力の装飾除去・状態抽出」の範囲を確定
  - 案 A: 純粋 CLI ラッパー（起動 + envelope 注入 + exit code のみ）
  - 案 B: 案 A + 終了マーカースキャン（`===STATE: done===` 等）
  - 案 C: 案 B + ANSI 除去 / 状態語彙閉集合の正規表現抽出
- [ ] 各 CLI（claude / codex / cursor）の出力形式調査結果を Episode に記録
- [ ] 確定結果を Episode に記録

## GATE: フェーズ 1 完了確認

- [ ] DI-1 / DI-3 / DI-8 / DI-10 の全てについて「確定した選択肢」+「根拠」が Episode または ADR に記録されている
- [ ] ディスパッチャの責務範囲が一文で要約できる状態である

## STOP: フェーズ 1 完了 — ユーザーにディスパッチャ責務確定結果を報告

---

## フェーズ 2: Schema 定義（DI-4 / DI-5 / DI-6 / DI-15）

> ドメイン判断要否: **部分的**（Schema のフィールド設計はドメイン判断。JSON Schema の記法自体は機械作業）

### Step 5: DI-4 — G4 Failure Taxonomy 6 値スキーマ定義

- [ ] `success / partial / retryable_failure / blocked / protocol_error / timeout` の 6 値を JSON Schema `enum` で定義
- [ ] フィールド名・格納場所（frontmatter / 専用 status ファイル / 監査ログ内 `state` フィールド）を確定
- [ ] JSON Schema ファイルを `projects/orchestration-engine/schemas/` に配置（ディレクトリ新規作成）
- [ ] 確定結果を Episode に記録

### Step 6: DI-5 — G6 Initializer Envelope スキーマ定義

- [ ] 「読む docs / 使う skill / 出力先 / 終了条件」のフィールド構成を JSON Schema で定義
- [ ] 表現形式を確定: JSON 単一ファイル / Markdown frontmatter / ハイブリッド
- [ ] ディスパッチャの注入方法を確定: CLI 引数 / 環境変数 / プロンプト先頭展開
- [ ] 既存 spec-card frontmatter との整合性を検証
- [ ] JSON Schema ファイルを `schemas/` に配置
- [ ] 確定結果を Episode に記録

### Step 7: DI-6 — G3 outputs 宣言フォーマット + KVS 契約定義

- [ ] skill / コマンドの `outputs:` 宣言フォーマットを確定: SKILL.md frontmatter / 独立宣言ファイル / envelope 内
- [ ] UC-2 用ファイルベース KVS の最小契約を定義: 単一 JSON / JSON Lines / ディレクトリ + 個別 JSON
- [ ] ロック戦略を確定: `flock` / atomic rename / lockfile なし（単一ライター前提）
- [ ] Step 0 の `canonical/skills/` 調査結果を踏まえて既存との整合を検証
- [ ] JSON Schema ファイルを `schemas/` に配置
- [ ] 確定結果を Episode に記録

### Step 8: DI-15 — Schema-driven Boundaries 検証ツール + 差し戻し動作定義

- [ ] 前提: DI-4 / DI-5 / DI-6 の Schema 確定後に着手（DI 依存関係グラフ: `DI-15 ⊃ {DI-4, DI-5, DI-6}`）
- [ ] 検証ツールを選定: `ajv-cli` / `jq --exit-status` / `python3 -m jsonschema`
- [ ] Step 0 の `canonical/hooks/` 調査結果を踏まえて既存パターンとの整合を検証
- [ ] 検証失敗時の差し戻しフローを確定: 同サブエージェント再投入 / 親エージェント通知 / 監査ログ + 人間判断
- [ ] 検証スクリプトの骨格を `projects/orchestration-engine/scripts/` に配置（ディレクトリ新規作成）
- [ ] 確定結果を Episode に記録

## GATE: フェーズ 2 完了確認

- [ ] DI-4 / DI-5 / DI-6 / DI-15 の全 Schema が `schemas/` に配置され、`jq` / 選定ツールで検証可能な状態
- [ ] 検証スクリプト骨格が `scripts/` に配置されている

## STOP: フェーズ 2 完了 — ユーザーに Schema 定義結果を報告

---

## フェーズ 3: SLO + サーキットブレーカー数値確定（DI-2 / DI-7 / DI-12）

> ドメイン判断要否: **部分的**（数値選定は実測値 + ドメイン判断。注入経路・監視方式は機械設計寄り）

### Step 9: DI-2 — オープンループ自律サイクル最小 SLO 確定

- [ ] Step 0 の `wez pane capture` 実測結果を踏まえ、ポーリング間隔の現実的下限を確定
- [ ] SLO 候補軸の数値を確定:
  - 状態変化検知の上限秒数（例: 5 秒）
  - interrupt ack までのターン上限（例: 次 heartbeat まで）
  - サイクル完走上限（例: 30 分）
- [ ] 確定結果を Episode に記録

### Step 10: DI-7 + DI-12 — Time Budgeting 上限値 + サーキットブレーカー監視方式（一体確定）

- [ ] 時間 / ターン / ペイン数 / コスト上限の具体値を確定（DI-2 と整合）
  - 例示値: 時間 30 分 / ターン 10 回 / 同時ペイン 5 個 / コスト optional
- [ ] エンベロープへの注入経路を確定: 環境変数 / envelope JSON フィールド / wrapper script 引数
- [ ] 上限到達時の監視主体を確定: ディスパッチャ常駐 / Bash `timeout` / cron 的別プロセス
- [ ] Step 0 の `timeout` + `wez pane kill` 連携テスト結果を踏まえて実現可能性を検証
- [ ] 上限到達時の挙動を確定: G4 最小分類の `timeout / blocked` で停止 → 人間判断要求 → 監査ログ記録
- [ ] 確定結果を Episode に記録

## GATE: フェーズ 3 完了確認

- [ ] SLO 数値が確定し、サーキットブレーカーの上限値・監視方式・到達時挙動が全て Episode に記録されている

## STOP: フェーズ 3 完了 — ユーザーに SLO + サーキットブレーカー確定結果を報告

---

## フェーズ 4: 失敗分類 + 監査ログ設計（DI-9 / DI-11）

> ドメイン判断要否: **部分的**（マッピングルールはドメイン判断。JSON Lines スキーマ自体は機械設計寄り）

### Step 11: DI-9 — exit code ↔ G4 6 値マッピング確定

- [ ] [#22](https://github.com/stlwolf/ai-development-hub/issues/22) の exit code 体系 `0 / 1 / 2` と G4 6 値の分岐ルールを確定
  - マッピング表案: `0 → success`, `1 → partial`, `2 → retryable_failure | protocol_error`
  - 補助シグナル: タイマー超過 → `timeout`, 明示マーカー → `blocked`
- [ ] [#36](https://github.com/stlwolf/ai-development-hub/issues/36) 多周制御仕様文書を参照し整合性を検証
- [ ] マッピング表を `schemas/` 内の JSON Schema または独立ドキュメントに定義
- [ ] 確定結果を Episode に記録

### Step 12: DI-11 — 監査ログ JSON Lines スキーマ定義

- [ ] フィールド構成を確定: `ts / session_id / pane_id / event_type / state / payload`
- [ ] 記録対象イベントを確定: 状態遷移 / G4 失敗分類 / 人間割り込み / クリーンアップ実行
- [ ] リプレイ可能性の最小担保レベルを定義: 1 サイクル再構成可能な粒度（コマンド単位の完全再現は MVP 外）
- [ ] JSON Schema ファイルを `schemas/` に配置
- [ ] `audit/` ディレクトリへの追記実装の骨格を `scripts/` に配置
- [ ] 確定結果を Episode に記録

## GATE: フェーズ 4 完了確認

- [ ] exit code ↔ G4 マッピング表が確定し、監査ログの JSON Lines スキーマが `schemas/` に配置されている

## STOP: フェーズ 4 完了 — ユーザーに失敗分類 + 監査ログ設計結果を報告

---

## フェーズ 5: ADR 化（DI-10 / DI-13 / DI-14）

> ドメイン判断要否: **低**（ADR のフォーマットは spec-card 準拠。内容はフェーズ 1〜4 の確定結果の蒸留）

### Step 13: DI-13 — 権限分離 ADR 作成

- [ ] 「MVP は全サブ親同等権限」の前提を明文化
- [ ] Phase 5 以降の sandbox / ReadOnly 化トリガー条件を記述: 共同開発開始 / チーム運用 / 公開リポジトリ運用
- [ ] 将来の sandbox 候補を列挙: Docker / OS user 分離 / careful-operations-rule フック強化
- [ ] 既存 `canonical/hooks/` の careful-operations 系との接続点を記述
- [ ] `docs/decisions/` に ADR として配置（spec-card SKILL 準拠）

### Step 14: DI-14 — クリーンアップ戦略 ADR 作成

- [ ] registry 構造を確定: 単一 JSON / `wez pane list` 都度叩き / ハイブリッド
- [ ] `trap EXIT INT TERM` の範囲を確定: dispatcher 単独 / engine 全体 / 親エージェント側 cleanup フック注入
- [ ] クラッシュ時の orphaned ペイン検知方式を確定: PID ファイル + liveness check / signal-driven
- [ ] `wez pane kill` の信頼性確認結果を反映
- [ ] `docs/decisions/` に ADR として配置

### Step 15: DI-10 ADR 更新（フェーズ 1 の ADR にフェーズ 2〜4 の成果を統合）

- [ ] フェーズ 1 Step 2 で作成した DI-10 ADR に、中間層プロトコル仕様の確定結果（registry / KVS / 監査ログ / SLO）を追記
- [ ] フェーズ 2〜4 で確定した Schema・数値・マッピングへの参照を追加

## GATE: フェーズ 5 完了確認

- [ ] DI-13 / DI-14 の ADR が `docs/decisions/` に配置されている
- [ ] DI-10 ADR がフェーズ 2〜4 の成果を統合している

## STOP: フェーズ 5 完了 — ユーザーに ADR 化結果を報告し、最終検証への移行を確認

---

## 最終検証

> KickOff §完了条件 7 項目との照合。

- [ ] 全 12 Decision Items（DI-1〜DI-15）について、Plan で「決定」+「対応 ADR/Episode 化」のタスクペアが定義されている
- [ ] DI-1 / DI-3 / DI-8 の相互依存解消順序が Plan 冒頭で明示されている（DI 依存関係グラフ準拠）→ フェーズ 1 Step 1〜4 の順序で対応
- [ ] DI-4 と DI-9 が一体扱いで Plan の同フェーズに配置されている → DI-4 はフェーズ 2、DI-9 はフェーズ 4。注: KickOff 原文は「一体で確定」だが DI 依存関係グラフでは `DI-4 <--> DI-9` が別クラスターにある。フェーズ 2 で DI-4 Schema 確定 → フェーズ 4 で DI-9 マッピング確定の順序は、DI-4 が DI-9 の前提であることと整合。ここでの「一体」は「同じ数値体系（6 値 enum）を共有する」の意。変換上の判断メモ §1 参照
- [ ] [#20](https://github.com/stlwolf/ai-development-hub/issues/20) Phase 2 現状確認が Plan の最初の TODO として配置されている → Step 0 の第 1 TODO
- [ ] Plan 冒頭に `kickoff-to-plan` SKILL の §「変換上の判断メモ」が埋め込まれている → §変換上の判断メモ
- [ ] frontmatter `status` が `in-development` 以上に昇格している → KickOff 側は `in-development`。本 Plan は `draft`（レビュー前のため）
- [ ] 観測層 Issue（[#84](https://github.com/stlwolf/ai-development-hub/issues/84)）と相互リンクされている → frontmatter `related[]` + KickOff §関連 + §依存・参照

## 関連

- 変換元 KickOff: [`2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md`](2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md)
- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19)
- 観測層サブ Issue: [#84](https://github.com/stlwolf/ai-development-hub/issues/84)
- 前 Step Discussion: [`2026-05-13-discussion-engine-scope-and-goals.md`](../discussions/2026-05-13-discussion-engine-scope-and-goals.md)
- 起点設計（frozen）: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)
- Harness ギャップ: [#37](https://github.com/stlwolf/ai-development-hub/issues/37)
- CLI ラッパー 4 層: [`docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md`](../../../../docs/specs/2026-04-27-discussion-cli-wrapper-layers-and-token-discipline.md)
- 依存表現 Episode: [`docs/episodes/2026-05-14-episode-dependency-representation-canonical-form.md`](../episodes/2026-05-14-episode-dependency-representation-canonical-form.md)

## Review 履歴

### Plan Review (2026-05-14)

**Status:** Approved

**Reviewer:** adversarial-review SKILL（explore subagent）

**検証結果:**

| 観点 | 結果 |
|------|------|
| Completeness | 12 DI がすべて Step に割り当て済み。Pre-Implementation / Step 0 / フェーズ 1〜5 / GATE / 最終検証あり |
| Consistency | Mermaid 依存グラフとフェーズ順序は整合。DI-4 ↔ DI-9 の分割（フェーズ 2 と 4）は合理的 |
| Clarity | ドメイン判断要否ヒント・案列挙・成果物の配置先が明確 |
| Scope | Step 4-1 の設計・スキーマ・ADR・骨格スクリプトに収まっている |
| YAGNI | スコープ外記述と整合。不要な追加なし |

**Recommendations（advisory）反映:**

- §変換上の判断メモ §2: 直列パスの説明を修正（DI-2 はフェーズ 3 に配置される旨を明示化）
- KickOff 完了条件「DI-4 と DI-9 が同一フェーズ」との字面差分: Plan 最終検証 3 項目目に変換判断の根拠を付記済み。KickOff 側の完了条件文言修正は Plan 承認後に検討

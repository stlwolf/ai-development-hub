---
id: "01KXQXK8152C2RZMRPTBN0GQFT"
title: "spawn 段 owner 承認ハンドシェイク v0 — 発火層・authZ↔binding 二層・engine 薄層採用"
date: 2026-07-17
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/262"
    reason: "委譲 auto-mode 子の spawn 段 friction のフィードバック起点"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-05-14-decision-permission-separation-mvp.md"
    reason: "別軸の権限 ADR（DI-13=OS/sandbox 分離 vs 本 ADR=ハーネス permission-mode 軸）。重複設計しない"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-07-17-episode-262-permission-handshake.md"
    reason: "実装・SO 反証履歴・具象修正の実行詳細（本 ADR は durable な決定に絞り §13.2 で重複回避）"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-08-10-episode-239-child-liveness-recipe.md"
    reason: "末尾の追記節「承認の成立条件をどの層に置くか」の出典（#319 U1 で追記）。同 episode の promotion 1件目の昇格先が本 ADR である"
  - type: integration_target
    ref: "projects/orchestration-engine/bin/oe-delegate"
    reason: "承認ハンドシェイクの実体（--print-approval / --approved-digest / --elevated）"
tags: [orchestration, permission, spawn, handshake, delegate, security, decision]
---

# spawn 段 owner 承認ハンドシェイク v0 — 発火層・authZ↔binding 二層・engine 薄層採用

## コンテキスト

委譲フロー（親 → 子 spawn・子 auto-mode）で、親が elevated 権限の子を spawn する段に来ると friction が起きていた（issue #262）。本 ADR は、その v0 対処として採用した設計の **durable な決定**を記録する。scope 確定（QDD gate 0）と設計判断は plan-first で設計SO（`oe-refute`）+ owner HG を通し、実装は実装SO（`oe-review`）で反証・修正済み。反証の往復や具象修正の詳細は related の episode を参照する（本 ADR では再掲しない）。

本 ADR は DI-13（権限分離 MVP）とは**別軸**である。DI-13 は OS/sandbox による分離（Docker / OS ユーザー / 破壊コマンド hook）を扱い「MVP では実装しない」と決めた。本 ADR はハーネスの **permission-mode 軸**（auto / bypass の分類器と、その owner 承認）を扱う。両者は直交し、互いを再litigate しない。

## 検討した選択肢（実体の置き場＝engine か skill か）

- **案 (a) skill のみ**: 承認パッケージのテンプレを skill に持たせ、engine は変更しない。
- **案 (b) engine 薄層 binding**【採用】: `oe-delegate` に、spawn せずに正規化 argv のダイジェストと承認パッケージを印字する経路（`--print-approval`）と、実 spawn 時にダイジェストを再計算して照合する経路（`--approved-digest`）を足す。
- **案 (c) 軽量版**: 新経路を足さず `oe-kick --elevated` 等の既存ラッパー拡張で整形だけ行う。

## 決定

1. **発火層の同定**: block は**親の tool-call 段で、ハーネス組み込みの auto-mode classifier が親の spawn（Bash tool-call）を評価して弾いている**。ローカルの破壊コマンド hook でも、ローカル設定の権限ルールでも、Task/subagent tool 専用の層でもない（消去法・観測ベース）。**trigger は「auto モードそのもの」ではなく危険シグナル**（`bypassPermissions`、または子のタスクが本番 / 機微アクセスを持つこと）。通常のローカル auto 委譲は block されない。

2. **authZ ↔ binding の二層分離**: 認可（authZ）の実体は**ハーネスの分類器**であり、その解除は owner の直接アクションのみ（エージェントは自己解除できない）。engine が足すダイジェストは**認可の証明ではなく drift-guard**＝「owner が承認パッケージで見た内容 = 実際に起動される内容」を保証する整合性チェック。両者は別レイヤーであり、**分類器を迂回しない**のが不変条件。

3. **実体は案 (b) engine 薄層 binding を採用**。`oe-delegate` に `--print-approval` / `--approved-digest` / `--elevated` を追加し、承認パッケージの整形と、承認↔実行のダイジェスト束縛、elevated 宣言の enforcement を engine 側で担う。3軸 doc（規範=`orchestration-toolkit` / 操作=`delegate-task` / ゲート=`doc-flow-guardrail`）で運用を明文化する。監査は `child_spawned` イベントに `permission_mode` + `elevated` を additive 追記する（registry は変更しない）。

4. **汎用原則（本設計から抽出・転用可能）**:
   - **print は spawn しないので分類器を尊重できる**: 承認パッケージ生成（`--print-approval`）は子を作らないため分類器に block されず、実 spawn だけが owner ゲートに残る。安全機構を迂回せずに friction だけ除ける構図。
   - **権限確認と一致保証は分ける**: 「owner が承認したか」（authZ＝分類器）と「承認内容と実行が一致するか」（integrity＝ダイジェスト）は別レイヤーとして設計する。セキュリティ関連の属性（elevated 宣言を含む）は**すべて整合性ダイジェストに束縛**する。**enforcement を伴わない opt-in binding は実効性がない**（「必須」と謳うゲートは機構で強制する）。

## 根拠

- 発火層が親の tool-call 段（spawn 実行より前）である以上、「検知＋承認要求」は engine では担えず親エージェント側の振る舞いになる。一方、**承認↔実行の一致保証は skill だけでは閉じない**（親が承認済みと違うコマンドを走らせる drift を機械照合できない）。案 (a) skill-only はこの binding gap ゆえ設計SO で否決された。behavioral のみの規律は採用不確実性も高い。
- よって「検知は親／整形と binding と enforcement は engine 薄層」に責務を割る案 (b) を採る。案 (c) は (b) の軽量サブセットで、binding と enforcement を機構化する要件を満たさないため (b) に包含・不採用。
- 分類器の「owner 直接アクションのみ・エージェント自己昇格不可」はハーネスの設計意図であり、ai-hub の変更対象外。ダイジェストを認可の証明に格上げしようとせず drift-guard に留めるのは、この意図を尊重するため。

## 結果（影響・v0 受容限界・defer）

- **効果**: elevated（bypass / 本番アクセス）子の spawn で、owner が 1 アクションで判断できる整形済みパッケージが spawn 前に出る。elevated / bypass 宣言の spawn は承認済みダイジェストを必須とし、承認を経ずに到達する経路を engine が塞ぐ。通常のローカル auto 委譲は不変。
- **v0 の受容限界（意図的な defer・追加実装しない）**:
  - **暗号的な承認証明を持たない**: ダイジェストは公開入力からの決定論チェックサムで、nonce / 期限 / 消費状態を持たない（エージェントによる自己発行・再利用が理論上可能）。authZ は分類器が担うため v0 では drift-guard で足りると判断。強い承認証明（generation-token 等）は defer。
  - **実行段 friction**（本番 IAM deploy の auto-approve flag を子が自己付与できない件）は本 v0 の対象外（別フェーズ）。
  - **durable pre-auth**（owner が一度宣言してセッション持続で elevated spawn を通す／親 bypass mode-flip）は観測上不確実ゆえ defer。
  - **kickoff の read-time TOCTOU**（spawn 後〜子が読むまでの差し替え）は束縛しない。承認時〜spawn の drift は kickoff 内容 hash で捕捉するが、read 時点までの厳密束縛は defer。
  - `permission_mode` は CLI 引数からの best-effort 推定（継承 config 非反映）。enforcement は明示 `--elevated` を主ゲートにするので本番判定は推定精度に依存しない。

## 将来の変更トリガー

以下のいずれかで本 ADR を再評価する:

- 委譲子の自己発行・再利用が実運用で実害化した場合 → 暗号的承認証明（generation-token・owner 秘密の導入）を検討。
- 実行段 friction（本番 mutation の非対話実行）を正面から解く必要が出た場合 → 別フェーズとして設計（issue #262 keep-open）。
- kickoff 内容の read-time 差し替えが脅威として顕在化した場合 → 承認時スナップショット等の厳密束縛を検討。
- 共同開発 / チーム運用（DI-13 と共通の将来トリガ）で信頼境界が広がった場合。

## 承認の成立条件をどの層に置くか — 常時ロードの規範層に置く（#239 の判定から追記・2026-08-11）

**本節は §結果「v0 の受容限界」が引き受けた隙間を規範で塞ぐ追記であり、§決定 のどれも変えない。** §結果は「暗号的な承認証明を持たない」ことを v0 の限界として引き受け、**エージェントによる自己発行・再利用が理論上可能**だと書いた。#239 の作業で、その理論上の経路と噛み合う実測が出た — 親が画面上の補完テキストを owner の承認と読んで spawn へ進めば、ダイジェストは公開入力から再計算できるので、**偽の承認が整合性チェックを素通りする。**

**錨を取り違えないこと。** 本節が縛るのは**振る舞いのゲート**（`canonical/rules/implementation-gate-rule.md` が定める plan → 実装の承認）であって、**§決定 2 のハーネス分類器ではない。** 分類器の「owner の直接アクションのみ・エージェントは自己解除できない」は §根拠 が ai-hub の変更対象外と明記しており、本節はそこを一切緩めない。**中継された承認が根拠になるのは振る舞い層に限る話で、分類器の解除の代わりにはならない。**

出典は `projects/orchestration-engine/docs/episodes/2026-08-10-episode-239-child-liveness-recipe.md`（以下「#239 episode」）で、該当の判定は同 `:22-24`、根拠の本文は同 `:119-135`（節「規範に1行足す判断」）である。**行番号は 2026-08-11 時点のもので、節名を併記してあるので参照先が動いても辿れる。**

### 決定

**承認の成立条件は、呼ばれたときだけ効くスキル層ではなく、常時ロードされる規範層に置く。** 規範が引いている線は「**受け取った経路か、観測しただけか**」である。

**文言の正本は `canonical/rules/implementation-gate-rule.md` であり、本節に転記しない。** 転記は版ずれを生む — #239 episode 自身が、書き換わった規範の古い版を引用したまま closure に入り、外部チェックで拾われている（同 `:214`）。中身が要るときは正本を読む。

### 棄却した案

- **スキルにだけ書く**（`delegate-task` の操作注意として）。棄却理由は**スキルが呼ばれたときしか効かない**ことである。承認の受け取りは委譲操作の外でも常に効いてほしい線なので、常時ロードされる面が要る（#239 episode `:123`）。
- **「画面を正本にしない」という広い禁止。** 承認だけでなく稼働判定まで一括で禁じる形だったが、範囲が広すぎて自リポジトリの実装を名指しせずに無効化する。範囲の切り直しは `projects/orchestration-engine/docs/decisions/2026-07-09-decision-238-239-succession-watchdog-lean-arch.md` の同日追記節が扱い、**本節は承認の側だけを持つ**（#239 episode `:184-192`・節「下書きの枠組みを1つ狭めた」）。

### 当時の前提（将来偽になりうるもの）

覆す人が最初に確かめるべき前提を3つ挙げる。

1. **補完のゴーストテキストは「次に送られそうな文」を予測するので、待っている承認の文面に寄る。** つまり**最も紛らわしい文が、最も危険なタイミングで出る。** 当該環境で、待機中の委譲子のペインに、まさにその子が待っている終端指示の文面のゴーストが出ていた（#239 episode `:67`）。別環境でも「裁定が出ました。承認です」に相当する例が観測されている（同 `:69`・出所は別リポジトリで未再現の伝聞）。
2. **既定の `tmux capture-pane` は表示属性を落とす**ので、ゴーストと実入力が同じ文字列に見える（#239 episode `:66`）。属性付きで撮れば判別の手がかりになるが、**手がかりであって契約ではない**（描画は TUI の版に依存し、外れたらまず疑うのは自分の検出器である・同 `:173`）。
3. **中継された承認の出所を、受け取る側は検証できない。** 規範としては中継する親も同じ線に縛られるので論理は閉じるが、**中継側に出所を明記させる義務は未実装**である（同 `:182` が本単位では塞がないと記録し、同 `:298` が #239 へ回している）。

### 覆すコスト

**覆すには「観測した承認を承認として扱ってよい」という価値判断を戦わせる必要があり、実物を見ても決まらない。** ゴーストの出ないハーネスの版を観測しても、前提2（検出器は版依存）ゆえ規範を弱める根拠にはならない — 版が戻れば同じ穴が開く。加えて置き場の側（always-on の規範層か、呼ばれたときだけ効くスキル層か）は、承認に限らず**規範を1行足すか迷うたびに再訪される分岐**なので、覆すなら分岐そのものを引き直すことになる。

### 併設している実装アーティファクト（昇格先ではない）

- 手順（何をどう測り、何を見ないか）: `canonical/skills/delegate-task/SKILL.md` の「委譲子の状態を親が判定する（1枚の画面から読まない）」節
- 再発する失敗の型: `projects/orchestration-engine/docs/knowledge/items/01KZKWJM1KTAFN22XK0WP0F96J.md`

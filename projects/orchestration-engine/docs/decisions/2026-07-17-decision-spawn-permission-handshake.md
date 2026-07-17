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

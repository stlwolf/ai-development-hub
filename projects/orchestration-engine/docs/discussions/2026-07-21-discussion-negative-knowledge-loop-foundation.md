---
id: "01KY1TRXGWK0W95PJB04M2GM45"
title: "negative knowledge ループの土台 — 6段骨格の確定と設計材料（ドキュメント強化→自己修正ループ）"
date: 2026-07-21
type: discussion
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/62"
    reason: "negative knowledge 消費（kickoff 側で読む・注入する）。本ループの欠けていた輪＝ハブ。段2（保存）の Phase A フォーマットがここに対応"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/185"
    reason: "episode lifecycle の機械制御（oe 結合）。段1（収穫）の生産側機構＝ループの燃料生産"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/263"
    reason: "文体（register）と型付きエンベロープ。knowledge スキーマと検証契約フィールドの載せ先（耐荷重な事実を型付き層へ降ろす方向と両輪）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "hook epic。段5（検証）以降の hard 化・決定論トリガの接続先"
  - type: spec
    ref: "canonical/orchestration-spec/document-format.md"
    reason: "「ライフサイクル規範」節〔§12〕・「昇格義務」節〔§13〕がループの機械化対象。「ゲート配置」節〔§11〕に段3-4の注入点（brief 組立）が既在"
  - type: discussion
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md"
    reason: "soft-first 教義（DJ-3: soft→機械注入→hook）の出所。本 discussion の DJ-1 はこれと矛盾しない整理（規範 vs 配管）を与える"
  - type: research
    ref: "ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md"
    reason: "Episode→Decision→Context 昇格フローの初出。本ループが回帰する初期構想の中核"
  - type: research
    ref: "ideas/20260121/episodic_memory_data.md"
    reason: "episode データ構造と「関連 episode を次クエリに注入する」ステップの初出＝ループ入力単位の原型"
  - type: research
    ref: "ideas/20260414/harness-architecture-layer-separation-control-loop.md"
    reason: "閉ループ制御5要素（Policy/Planner/Actuator/Sensor/Controller）と promotion model。本骨格の制御ループ語彙の先行整理"
  - type: research
    ref: "docs/research/2026-05-31-agmsg-agent-messaging-patterns.md"
    reason: "配送セマンティクス（push/poll・取得方法と取得タイミングの分離）＝「いつ注入するか」の設計軸"
  - type: research
    ref: "docs/research/2026-06-10-episode-quality-audit.md"
    reason: "蓄積 episode の文脈復元性の実測。段1の入力品質と段5の照合設計の先行データ"
---

# negative knowledge ループの土台 — 6段骨格の確定と設計材料

owner × cockpit 統括の QDD（2026-07-19〜21）で確定した設計土台の正本。実装はしていない（設計材料 + 確定事項の記録）。個別の実装単位は本 doc の §6 未決論点を各自の QDD / plan / SO ゲートで解いてから着手する。

## 1. 背景 — なぜこのループか

owner の課題設定: 「episode を元にしたラフループ（イテレーションが回る仕組み）を次のステップで入れられると、ハーネスの残りの部分が入る」。

現状の過不足（統括の一次調査・2026-07-19）:

- ドキュメントフローの地図（ゲート(0)-(6) × スキル routing）と規範（document-format の「ライフサイクル規範」節〔§12〕・「昇格義務」節〔§13〕）は完備。しかし**強制はほぼ全て soft（自己申告）か人間ゲート**で、doc/探索フローの実 hook は hypothesis-gate（#78・advisory）1本のみ。
- **episode の消費側が欠落**: closure（episode-retrospective）は negative knowledge を「昇格候補」とマークするまで（自己申告）で、次の作業で読み戻す consumer が存在しない。ループが閉じていない。#62 は Phase A/B とも設計のみ・実装ゼロ。
- 実測痕跡: episode→decision 昇格率 13〜19%・昇格判断の痕跡なし多数（doc-flow-stocktake G4）。「読む人のいない義務は守られない」ことのデータ。

構図: **#185 = 燃料の生産**（lifecycle 機械化の副産物として訂正注釈・negative knowledge を残す）/ **#62 = 燃料の消費**（読み戻してループを閉じる）。#263 の「耐荷重な事実を型付き層へ降ろす」方向はこの両方のスキーマ面。

## 2. 外部調査の要点（deep-research・2026-07-19）

出典検証: 26ソース→129claim→上位25を3票敵対検証（16 confirmed / 0 refuted / 9 unverified）。中心論文は統括が直接 arXiv を開いて実在確認済み。

### 2.1 「loop engineering」という語と分野

- 語は実在するが新しい: Addy Osmani が 2026-06-07 に命名。「自分がエージェントに prompt する側を降り、prompt する系そのものを設計する」。agent harness engineering の一段上の位置づけ。「cron job の言い換えでは」という実在論争もある [unverified-summary] (https://addyosmani.com/blog/loop-engineering/, https://www.oreilly.com/radar/loop-engineering/, https://www.firecrawl.dev/blog/loop-engineering)
- 学術側の確立名は **harness engineering**: 「モデルの外側の系（tools / interfaces / memory / execution constraints / feedback loops）を設計する実践」 [verified] (https://arxiv.org/abs/2604.25850)

### 2.2 中心発見 — AHE（Agentic Harness Engineering）

arXiv:2604.25850。harness 改善の closed loop を3つの observability 柱で定式化 [verified]:

| 柱 | 内容 | 本リポジトリの現状 |
|---|---|---|
| component observability | 編集対象すべてに file-level 表現（明示的・revertible な action space） | ほぼ既取得（canonical/ が git 管理の file-level skills/rules） |
| experience observability | 生 trajectory を、改善エージェントが消費できる層状 evidence corpus に蒸留 | 半分（§12/§13 の規範のみ・機構は #185 未実装） |
| decision observability | **すべての編集に自己宣言の予測を付け、次ラウンドの結果で検証**（編集を反証可能な契約にする） | **完全空白** |

各編集は manifest（failure evidence / root cause / targeted fix / predicted impact）を持つ [verified]。AHE は「検証なしの編集ループは trial-and-error に崩壊する」と警告しており、これが DJ-3（検証枠を最初から）の外部根拠。

### 2.3 trigger / store / inject で見た確立パターン

| 実装 | trigger | store | inject | 検証状態 |
|---|---|---|---|---|
| Reflexion | タスクの feedback signal | 言語的振り返り（episodic memory buffer） | 次試行の文脈 | [verified] (https://arxiv.org/abs/2303.11366) |
| ACE | 実行の自然フィードバック（ラベル不要） | evolving playbook（generation/reflection/curation の3役） | offline=system prompt / online=agent memory | [verified] (https://arxiv.org/abs/2510.04618) |
| GEPA/DSPy | rollout/eval 実行 | Pareto frontier 上の prompt 候補群 + 全 trace + テキスト feedback | predictor の instruction slot へ機械書き戻し | [verified] (https://arxiv.org/abs/2507.19457, https://dspy.ai/api/optimizers/GEPA/overview/) |
| Cursor Memories | 会話からバックグラウンド生成 | memory fact（**保存前に人間承認ゲート**） | 将来の会話文脈 | [unverified-summary] (https://docs.cursor.com/en/context/memories) |
| Devin Knowledge | **作業内容が Trigger Description にマッチした時（セッション途中）** | Knowledge item = **必須 Trigger Description + 短い本文**（org スコープ既定） | マッチ時に文脈へ | [unverified-summary] (https://docs.devin.ai/product-guides/knowledge) |

借用した2つの核:

1. **Devin 型の保存スキーマ**: 「どの knowledge をいつ注入するか」を注入時に計算せず、**保存時に trigger 条件を knowledge に添付**して関連性マッチングを保存側スキーマで解く。→ 段1/段3 の形。
2. **AHE の decision observability**: 注入・昇格に「効くはずだ」という予測を付け、次の結果で照合する。→ 段5 の形。

チームスケールの伝統は Google SRE の postmortem 文化（blameless・action item 追跡・横展開）[unverified-summary] (https://sre.google/sre-book/postmortem-culture/)。製品側の実例は Devin の org スコープ既定。Cursor の「保存前の人間承認ゲート」は本リポジトリの owner-HG 文化と同型で、**store 側に人間ゲート・inject 側は機械**という分担の外部実例。

## 3. 初期構想への回帰

このループは新規の発明ではなく、本リポジトリの初期リサーチ（2026年1〜4月）が最初から狙っていた構造への回帰である:

- `ideas/20260121/episodic_memory_data.md` — episode のデータ構造（timestamp/entity/event_type/outcome/connections）と「関連 episode を次のクエリに機械注入する」ステップの初出。
- `ideas/20260208/hypothesis-intentional-compression-and-promotion-flow.md` — Episode→Decision→Context の三層 + 昇格フローの初出。安定 ID + 関係タイプで「圧縮後も根拠へ降り、投入時に必要文脈を動的バンドル」。
- `ideas/20260414/harness-architecture-layer-separation-control-loop.md` — 閉ループ制御5要素（Policy/Planner/Actuator/Sensor/Controller）と promotion model（intent/evidence/diff/replay log）。

その後の実装（engine・蒸留5段・closure）はループの**生産側と規範だけを先に作り**、注入側が未実装のまま現在に至る。外部の AHE / ACE と独立に同型へ到達していたことは、この構造の妥当性の傍証（収斂）でもある。

## 4. 確定した土台（owner 決定・反証対象外）

### DJ-1: ループは機構（配管）として作る — soft 段階を経ない

doc-flow-stocktake の soft-first 教義（soft で運用 → 効いた節だけ機械注入 → hook へ段階 hard 化）は**モデルの振る舞いを抑制するゲート**への段階論であり、**データを運ぶ配管**には最初から適用されていない（event-bus / delegate-registry / oe-vitals / sync はすべて最初からコード）。本ループは配管の族。soft でやると「読んだかどうか」が自己申告になり、昇格率 13-19% と同じ計測不能問題を再生産する（owner の判断根拠: 「ループ自体はシステムアーキテクチャそのものが機械的な要素を含む。ソフト面で解決しようとすると不完全な実例しか取れない」）。

役割分担: **機械 = トリガ・保存・突合・提示・計測 / モデルと人間 = 意味判断**（何が negative knowledge か・どれが今のタスクに関連するか）。hypothesis-gate の「機械は形を検出して促し、真偽判断はモデル」と同じ分離。

### DJ-2: 配置 = orchestration-engine の新しい面

「ハーネス内か外か」は二者択一でなく役割分担。実装済みの前例 = oe-vitals ループ（statusline がセンサー / sidecar が状態ストア / launchd が決定論トリガ / notify がアクチュエータ・制御はすべてハーネスの外）。本ループも同型に置く: **ハーネスは接続面（hook・statusline 等）を提供し、ループ制御は engine が持つ**。第三の「別ループエンジン」は新設しない。AHE（外部 closed loop が file-level 構成面を編集する形）が外部裏づけ。グローバル hook は誤発火の既知判断があるため、hook は oe スコープのセンサーとして限定使用。

### DJ-3: 検証契約は v0 の枠に最初から含める

一周のフロー（検証段まで）は最初から構造として作る。**検証の「質」は薄く始めてよいが「枠」は土台として確定させる**。後から検証段を接ぎ木する形にしない（owner 確定 2026-07-21。外部根拠 = AHE の「検証なし編集ループは trial-and-error に崩壊」警告）。

### DJ-4: 6段骨格

| 段 | やること | 担い手 | 既存資産への着地 |
|---|---|---|---|
| 1. 収穫 | episode closure 時に negative knowledge を型付き item として切り出す。スキーマ = **trigger 条件（必須）+ 短い本文 + 出典（episode への参照）+ 予測（効くはずの状況と期待効果）** | モデル + **保存前の人間ゲート** | episode-retrospective〔gate 5〕+ §13。生産側機構は #185 |
| 2. 保存 | committed の型付き置き場に格納。スキーマは機械検証 | 機械 | #62 Phase A + 検証ゲート（#19 系） |
| 3. 突合 | 統括が brief を組む時、新タスクの属性と trigger 条件を機械照合して候補を提示 | 機械（候補列挙）+ 統括（採否の意味判断） | oe helper 新設（Devin 型） |
| 4. 注入 | 採用した knowledge を brief の固定節に焼き込む | 統括 | doc-flow-guardrail テンプレに新 slot |
| 5. 検証 | 子の完了時に「予測が当たったか（同じ失敗が再発しなかったか・knowledge が参照されたか）」を照合し、結果を knowledge item に書き戻す | v0 は薄く: self-report + 親 fact-check。hard 化は #24 へ | **AHE decision observability（新規）** |
| 6. 計測 | 注入・検証結果をイベントとして流す（audit 痕） | 機械 | event-bus（`child_spawned.extra` 拡張と同型） |

### DJ-5: 人間ゲートは2箇所

保存時（段1・何を資産化するか）と採否（段3・何を今のタスクに効かせるか）。注入・計測は無人。Cursor の保存前承認ゲートと同型で、本リポジトリの owner-HG 文化に整合。

## 5. #263 との両輪関係

文書 = エンベロープ（frontmatter の型付き層・機械検査対象）+ ペイロード（自然言語本文）。#263 の結論方向「prose に統制文体を無理に作らず、耐荷重な事実を型付き層へ降ろす」の、型付き層側の実体が本ループのスキーマ（trigger 条件・予測・検証結果はすべて型付き層の住人）。knowledge item のスキーマ設計は #263 段階2（他族 SO で「薄い中間 register」へ再構成中）と設計単位を跨いで整合を取る。

## 6. 未決論点（次の設計単位で解く・本 doc では決めない）

1. **store の置き場**: repo committed（`docs/` 配下の型付きディレクトリ）か、`~/.claude/state` 系か。チーム共有前提なら committed が素直だが、個人固有ノイズの混入と量の増加をどう捌くか。個人最適 vs 共有前提の軸（下記 7）と連動。
2. **knowledge item のスキーマ詳細**: Devin 型（trigger + 短文）を基底に、AHE manifest 型（failure evidence / root cause / fix / predicted impact）をどこまで載せるか。#263 の型付きエンベロープとの統合形。
3. **突合の属性設計**: 新タスクの何と照合するか（issue ラベル・対象ファイル・作業種別・過去の失敗クラス）。マッチ精度と誤発火のバランス。
4. **検証照合の具体**: 「予測が当たった」の判定材料（子の episode 言及・PR diff・テスト結果）と書き戻しの形（hit/miss カウント・鮮度・退役条件）。
5. **oe verb の切り方**: 収穫/突合/検証を1 verb に束ねるか分けるか。既存 verb（oe-delegate の brief 組立経路）への挿し込み方。
6. **注入タイミングの配送セマンティクス**: brief 組立時（poll 型・ターン境界）を v0 とするが、セッション途中の trigger-matched 注入（push 型・Devin 同型）をどの段階で足すか。agmsg 研究ノートの push/poll 分離軸を適用。
7. **個人 vs 共有前提の軸**: 個人開発のループをチーム・サービス開発へ持ち出すとき、ナレッジは流用できても仕組みは共有前提の全体最適が要る（owner 提起）。store のスコープ（personal / repo / org）と保存時ゲートの承認者設計に直結。SRE postmortem 文化と Devin org スコープが先行事例。
8. **raw-log 長期ストアとの関係**: #185 の開放問題（raw-log の保全・SQLite 的長期ストア）とループの store を統合するか分離するか。

## 7. 進め方

1. 本 doc の正本化（owner マージ）。
2. issue 切り出し（正本化後・owner と確定）。候補の切り方: 段1+段2（収穫スキーマ + store = #62 Phase A の再起動 + #185 接続）/ 段3+段4（oe helper + guardrail slot）/ 段5+段6（検証照合 + event-bus）。各単位が独立に QDD / plan / 設計SO を通る。
3. 実装単位ごとに委譲（統括は hands-off・子が worktree 自作・plan-first）。

## 8. 検証ステータス凡例

- [verified] = 出典を deep-research の3票敵対検証が confirmed、かつ中心論文（arXiv:2604.25850）は統括が直接 fetch で実在確認。
- [unverified-summary] = 出典 URL 付きだが票が未成立（低リスクの製品ドキュメント系 claim）。採用判断に効く場合は着手時に一次確認する。
- 本文中の repo 内事実（昇格率・hook 本数・#62 実装ゼロ等）は統括のリポジトリ一次調査（file:line 確認）に基づく。

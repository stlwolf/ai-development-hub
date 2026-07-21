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

正本化前に他族SO（弱・1周・codex `gpt-5.6-sol` + cursor `cursor-grok-4.5-high`・2026-07-22・両レーン実返却）を実施した。両レーンが独立に「このまま正本化しない」で一致し、収束した指摘を owner 承認のもと本版に反映済み（§2.3 援用射程の縮約 / DJ-3 の根拠縮約 / 段3・段5・段6 の改訂〔段6 は計測→制御へ差し替え・計測は横断計装へ〕/ §6 未決論点の追加 / §7 相補経路の新設）。書き手・調査検証・議論相手が同族（Claude）である構造への対処として実施したもので、初版は PR #271 の履歴に残る。

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

1. **Devin 型の保存スキーマ**: 保存時に trigger 条件（＝適用条件の**仮説**）を knowledge に添付する。実行時の関連性判定を消すものではなく、判定材料を保存側に前置きする形（他族SO 指摘で縮約: Devin 自身も repo pin / folder / enable-disable を併用しており、trigger 単独でマッチングが解ける証明ではない）。→ 段1/段3 の形。
2. **AHE の decision observability**: 注入・昇格に「効くはずだ」という予測を付け、次の結果で照合する。→ 段5 の形。

チームスケールの伝統は Google SRE の postmortem 文化（blameless・action item 追跡・横展開）[unverified-summary] (https://sre.google/sre-book/postmortem-culture/)。製品側の実例は Devin の org スコープ既定。Cursor の「保存前の人間承認ゲート」は本リポジトリの owner-HG 文化と同型に見えるが、出典 URL が redirect して一次確認できていないため、DJ-5 の外部根拠には使わない。

援用の射程（他族SO 指摘で追記・2026-07-22）: AHE の decision observability は標準化された反復評価・タスク結果差分・file 単位 rollback を含む完全形であり、本骨格の段5はその**縮約版**（名乗りも「観測記録」に弱める・DJ-3）。ACE の核心には Curator（統合・剪定・重複排除・helpful/harmful カウンタ）が含まれ、段6（制御）がこれに対応する。GEPA は評価関数と反復 rollout を持つ最適化器であり、異種タスクへ item を検索注入する memory 系とは別物（構造の参考に留める）。Reflexion の実証は同一タスク内の反復であり、横断タスクの trigger 検索の直接根拠ではない。

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

一周のフロー（検証段まで）は最初から構造として作る。**検証の「質」は薄く始めてよいが「枠」は土台として確定させる**。後から検証段を接ぎ木する形にしない（owner 確定 2026-07-21）。

根拠と射程（他族SO 指摘で縮約・2026-07-22）: 主根拠は**後から検証段を接ぎ木する構造変更コストの回避**（スキーマ・イベント契約・骨格の再設計を避ける）。AHE の「検証なし編集ループは trial-and-error に崩壊」という警告は補助根拠だが、AHE のそれは反復評価・結果差分・rollback という成立条件込みの主張であり、v0 の self-report がそのまま decision observability を name できるわけではない。よって **v0 の段5は「検証」を名乗らず「観測記録（evaluation record）」とし、その結果を意思決定に使わない placeholder であることを明示する**。歯（客観 oracle・無効化・rollback）は §6 の未決論点として次段位で設計する。

### DJ-4: 6段骨格

初版（2026-07-21 確定）の段6は「計測」だったが、他族SO の収束指摘（結果を書き戻すだけでは自己修正ループでなくログ循環・ACE の Curator 相当が欠段）を受け、**owner 承認（2026-07-22）で段6を「制御」に差し替え、計測は特定の段でなく横断計装に降ろした**（初版は PR #271 の履歴）。

| 段 | やること | 担い手 | 既存資産への着地 |
|---|---|---|---|
| 1. 収穫 | episode closure 時に negative knowledge を型付き item として切り出す。スキーマ = **trigger 条件（必須・適用条件の仮説）+ 短い本文 + 出典（episode への参照）+ 予測（効くはずの状況と期待効果）** | モデル + **保存前の人間ゲート** | episode-retrospective〔gate 5〕+ §13。生産側機構は #185 |
| 2. 保存 | committed の型付き置き場に格納。スキーマは機械検証 | 機械 | #62 Phase A + 検証ゲート（#19 系） |
| 3. 突合 | 統括が brief を組む時に候補を提示。**v0 は全件列挙 + 統括の採否 + 採否理由の記録**（false negative ゼロ・採否記録が後の matcher の教師データになる）。trigger 機械照合は件数・選別コストが閾値を超えてから導入 | 機械（列挙）+ 統括（採否の意味判断） | oe helper 新設 |
| 4. 注入 | 採用した knowledge を brief の固定節に焼き込む | 統括 | doc-flow-guardrail テンプレに新 slot |
| 5. 観測記録 | 子の完了時に、注入した knowledge の帰結を状態語彙（`no_opportunity` / `injected_not_used` / `followed` / `contradicted` / `harmful` / `outcome_unknown` / `externally_verified` 等）で item に書き戻す。**v0 では hit/miss を意思決定に使わない（placeholder 明示・DJ-3）**。「再発しなかった」は適用機会があった場合のみ観測として数える | v0 は self-report + 親 fact-check。客観 oracle・歯は #24 / 次段位 | AHE decision observability の**縮約版**（射程は §2.3 注記） |
| 6. 制御 | 観測記録を使って knowledge を改訂・統合（重複排除）・supersede・無効化・退役する。矛盾 item の優先決定・誤注入の rollback を含む | 機械（候補提示）+ 人間ゲート（改訂の採否） | ACE の Curator / grow-and-refine 対応（他族SO 指摘で追加） |

計測は横断計装とする: 収穫・採否・注入・適用機会・観測・制御の各遷移でイベントを流す（event-bus・`child_spawned.extra` 拡張と同型）。ただし現行 event-bus は best-effort（書き込み失敗も成功扱い）であり、効果測定の正本にする場合は欠損の扱い・安定 ID・照合可能性を次段位で設計する（§6）。

### DJ-5: 人間ゲートは2箇所（+ 制御の採否）

保存時（段1・何を資産化するか）と採否（段3・何を今のタスクに効かせるか）。注入と計装は無人。段6（制御）の改訂・退役の採否にも人間ゲートが入る。根拠は本リポジトリの owner-HG 文化への整合（外部製品の同型例は一次確認未了のため根拠にしない・§2.3 射程注記）。ゲート追加による総ゲート量とスキップ率（soft 昇格率問題の再来経路）は未決論点（§6）。

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

以下 9〜16 は他族SO の指摘（2026-07-22）で追加:

9. **着地先選択**: 失敗を NL knowledge として注入するか、実行可能な guard（test / lint / hook / rule）へコンパイルするか。失敗クラスごとの振り分け規則。§7 の相補経路と対。
10. **効果の帰属と成功基準**: 「注入したから再発しなかった」の反事実（適用機会の有無・no-injection baseline・有効判定に要る最小標本数）。matcher 導入時の precision / recall と誤注入コスト。
11. **lifecycle 制御の権限と履歴**: 段6の改訂権限・人間ゲートの設計。item 更新（version）後に過去の観測履歴をどう分離するか。
12. **信頼境界（poisoning）**: episode 中の誤情報・prompt injection を knowledge へ昇格させない仕組み。secret / 個人情報 / 外部由来内容の扱い。knowledge 本文を命令として扱うか参考情報として扱うか。
13. **注入予算と競合解決**: brief への最大注入件数 / token 予算。複数 item の優先順位・矛盾 item 同時ヒット時の規則（fail-closed / fail-open）・rule / task 指示 / knowledge の優先順位。
14. **識別子とイベント契約**: item ID / version・task との因果リンク（matched / accepted / injected / opportunity / outcome を結ぶ契約）。event-bus の best-effort 性（欠損の扱い・照合可能性）。
15. **並行更新**: 複数 worktree / 並列子が同じ committed store を書き換える競合と、書き戻しの atomicity。
16. **cold-start・positive との非対称・ゲート負荷**: 0〜数件時の挙動（v0 の全件列挙が解く部分と残る部分）。negative のみ蓄積した場合の brief 肥大と positive knowledge（Decision / Context 側）との分担。HG 2箇所+制御採否の総ゲート量とスキップ率の観測設計。

## 7. 相補経路 — 失敗の guard コンパイル（他族SO の収束提案・採否は次段位）

他族SO の2レーン（codex / cursor）が独立に同方向の代替骨格を提案した: **機械判定可能な失敗クラスは、自然言語 knowledge として読ませるのではなく、実行可能な guard へコンパイルする**（detector / invariant + replay fixture + hook / CI への canary 配備 + 誤検知観測 + rollback / 退役）。この経路では「読んだ」と「効いた」の混同が構造的に消え、検証が replay で機械化できる。

- 位置づけ: 6段の置き換えではなく**相補**。path / command / diff / schema 等の述語に落ちる失敗を NL 注入から分離する。自然言語でしか表現できない判断（文脈依存の教訓）は6段側に残る。
- 露呈した隠れ前提: 「negative knowledge のアクチュエータは LLM の文脈である（読ませて初めて再利用できる）」。本リポジトリには hypothesis-gate（#78・advisory hook）という guard 系の先行実装が既にあり、この経路はその一般化にあたる。
- 採否: 本 discussion では決めない。§6.9（着地先選択）として次の設計単位で、6段との振り分け規則とともに扱う。SO 生出力（レーン別の具体案・成立条件・棄却条件）は SO 証跡に保全。

## 8. 進め方

1. 本 doc の正本化（owner マージ）。
2. issue 切り出し（正本化後・owner と確定）。候補の切り方: 段1+段2（収穫スキーマ + store = #62 Phase A の再起動 + #185 接続）/ 段3+段4（v0 全件列挙の oe helper + guardrail slot）/ 段5+段6（観測記録 + 制御 + 横断計装の契約）。各単位が独立に QDD / plan / 設計SO を通る。
3. 実装単位ごとに委譲（統括は hands-off・子が worktree 自作・plan-first）。

## 9. 検証ステータス凡例と SO 証跡

- [verified] = 出典を deep-research の3票敵対検証が confirmed、かつ中心論文（arXiv:2604.25850）は統括が直接 fetch で実在確認。
- [unverified-summary] = 出典 URL 付きだが票が未成立（低リスクの製品ドキュメント系 claim）。採用判断に効く場合は着手時に一次確認する。Cursor Memories は出典 redirect につき本文の根拠から降格済み（§2.3）。
- 本文中の repo 内事実（昇格率・hook 本数・#62 実装ゼロ等）は統括のリポジトリ一次調査（file:line 確認）に基づく。
- 他族SO 証跡: 弱・1周・2レーン（codex `gpt-5.6-sol` / cursor `cursor-grok-4.5-high`）・2026-07-22・両レーン実返却。生出力は作業層（`tmp/so-271-nk-loop/`・gitignore）に保全し、収束指摘と代替骨格の要点は本文 §2.3 / DJ-3 / DJ-4 / §6.9〜16 / §7 に反映済み。レーン別の詳細は PR #271 のレビュー記録を参照。

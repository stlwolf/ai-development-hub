# ハーネスアーキテクチャの層分離と制御ループ設計 — マルチAIブレスト統合

- 日付: 2026-04-14
- 性質: ブレスト統合（Claude + ChatGPT）。Claude壁打ち → ChatGPTクロスレビュー → Claude再評価の3段階。
- derived_from:
  - [discussion-logs/harness-architecture-discussion-claude.md](discussion-logs/harness-architecture-discussion-claude.md) — Claude (Opus 4.6 Extended) との壁打ち（風呂場着想 → 構造化）
  - [discussion-logs/harness-architecture-discussion-chatgpt.md](discussion-logs/harness-architecture-discussion-chatgpt.md) — ChatGPT へのクロスレビュー（追加観点6つ + CLI for AI 評価フレーム）
- related_ideas:
  - [../20260130/ai-middleware-cli-concept.md](../20260130/ai-middleware-cli-concept.md) — AI middleware CLI構想（起点）。コンテキスト純度・状態外部化は継承、ミドルウェア配置・composable単機能は進化・棄却。詳細は後述「先行アイデアとの接続分析」
  - [../20260130/ai-native-interface-concept.md](../20260130/ai-native-interface-concept.md) — AI向けインターフェース構想。「CLI for AI」の問いの起点。今回は「AI向け最適化」より「AI判断スコープの縮小」にシフト
  - [../20260224/orchestration-design-principles-bath-brainstorm.md](../20260224/orchestration-design-principles-bath-brainstorm.md) — 3設計原則（ベンダー非依存・直列プリミティブ合成・拡張可能）
  - [../20260208/hypothesis-intentional-compression-and-promotion-flow.md](../20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 意図的圧縮と昇格フロー
  - [../20260218/hypothesis-inference-ratio-certainty-model.md](../20260218/hypothesis-inference-ratio-certainty-model.md) — 推測比率と確実性の構造モデル
  - [../20260222/orchestration-tool-building-approach.md](../20260222/orchestration-tool-building-approach.md) — OSSリサーチ → 自前構築アプローチ
  - [../20260329/metadata-layer-mirror-repo-synthesis.md](../20260329/metadata-layer-mirror-repo-synthesis.md) — Decision Ledger + メタデータ層
  - [../20260208/hypothesis-second-opinion-review-flow.md](../20260208/hypothesis-second-opinion-review-flow.md) — 反証担当固定。並列探索で異なる観点を割り当てる設計原則として接続
  - [../20260224/hypothesis-design-ci-parallel-agents.md](../20260224/hypothesis-design-ci-parallel-agents.md) — 並列パイプライン。今回の「並列探索→収束→直列適用」のドメイン特化版
- related_issues:
  - [#20 feat(wezterm-ai-mode): wez CLI ツールキット（Epic）](https://github.com/stlwolf/ai-development-hub/issues/20)
  - [#37 epic: Harness Engineering 基盤整備](https://github.com/stlwolf/ai-development-hub/issues/37)
  - [#19 feat: 自前オーケストレーションツール MVP（Epic）](https://github.com/stlwolf/ai-development-hub/issues/19)
  - [#21 feat: AIエージェント向けターミナル環境とヒューマンモード両立](https://github.com/stlwolf/ai-development-hub/issues/21)
  - [#24 chore: フック拡充エピック](https://github.com/stlwolf/ai-development-hub/issues/24)
- related_docs:
  - [docs/draft/orchestration-control-loop-challenges.md](../../docs/draft/orchestration-control-loop-challenges.md) — 制御ループ課題の先行整理

---

## 構想の核心（一文）

> canonicalの4層分離（rules → skills → commands → agents + hooks）を「決定性の境界」で再整理し、機械的判断が連続する範囲をcommandに吸収することで、スキル揺らぎ・hookコスト・オーケストレーション安全性の3課題を構造的に解決する。

---

## このドキュメントの位置づけ

今回の議論の多くは、20260130（AI middleware CLI構想）時点で頭では到達していた結論の**実感付きの再言語化**。3ヶ月の実践（スキルの揺らぎ、hookの重さ、MVPシミュレーションでのマージ順問題）を経て、抽象的な原則が体感を伴う設計判断基準に変わった段階。新規の結論というより、実感による精度の向上。

ただし、今回挙がった懸念（policy埋没、escalation signalの消失、コマンド中心化による自由度の死）は**まだ踏んでいない地雷の予測**であり、実際に作って使うフェーズで初めてベネフィット/デメリットが見える。原則は固まりつつあるが、最適な粒度の調整は実践とのすり合わせが続く。

## 着想

風呂場の思考から始まった3つの論点:
1. CLIコマンドへのロジック内包で判断揺らぎ・コスト・hook重さを解決できるか
2. 仮想環境による隔離で並列オーケストレーションの安全性を確保できるか
3. セッション管理ツール（wez CLI）が上記すべての物理基盤になるのではないか

Claude壁打ちで構造化 → ChatGPTクロスレビューで6つの追加観点 → Claude再評価で統合。

---

## 議論の経緯と収束

### Claude との議論で見えたこと

1. **コマンド責務拡張の原則**: 「コマンドの設計単位は1機能ではなく、機械的判断が連続するワークフロー区間」。ブランチ作成フロー（issue番号取得 → 命名規則 → 作成 → 検証）を1コマンドに吸収する具体例で検証
2. **3つの利点の構造化**: AIの判断負荷削減（散文解釈 → 引数選択）、hook集約（事後検証 → 実行中検証）、プロジェクト固有分岐（散文 → オプション明示）
3. **仮想環境隔離パターン**: 並列探索 → 結果持ち寄り → 破棄 → 直列再実行。並列の成果物は「判断材料」であって「最終成果物」ではない
4. **オーケストレーションの3段階コマンド化**: 起動コマンド（機械的）→ 探索フェーズ（非決定論的 — エージェントの仕事）→ 収束コマンド（機械的）。強制できるものの範囲がコマンドライフサイクル全体に拡張
5. **実装の積み上げ順序**: wez CLI（物理基盤）→ ワークフロー区間コマンド → 起動/収束コマンド。「下から積まないと上が浮く」

### ChatGPT との議論で見えたこと

1. **determinism boundary architecture**: 層分離の軸は「抽象度」ではなく「決定性」。再現可能性・テスト可能性・監査可能性による切り分け
2. **閉ループ制御系の5要素**: Policy / Planner / Actuator / Sensor / Controller。特にControllerの位置づけが未定義であり、「制御ループの不在」を埋めるのはcontroller contractの定義
3. **policyのcommand埋没リスク**: Command（手順・状態遷移）/ Policy（ルール・条件）/ Context Resolver（プロジェクト差分吸収）の3分割
4. **仮想環境の3種分離**: UI隔離（pane — 見える化）/ execution隔離（process/env — 副作用抑制）/ workspace隔離（worktree — 差分衝突防止）
5. **promotion model**: 「再実行」より「昇格」が核心。初期推奨: intent / evidence / diff / replayable command log の4点セット
6. **semantic observability**: hooks削減の本質は速度ではなく、外部事後検証 → 内部文脈付き検証への移行
7. **orchestration cockpit**: セッション管理はterminal controlではなく認知補助。ボトルネックはCPU/IOではなく人間の認知負荷
8. **CLI for AI の4分類**: Primitive / Workflow / Policy-aware / Orchestration。位置づけと設計粒度の判断基準

### 交差点と相違点

**収束した点:**
- 「機械的判断の連続範囲をcommandに吸収する」原則
- 並列は探索、本番適用は直列（promotion/replay経由）の安全原則
- wez CLI が物理基盤であり、上位の設計はここから積み上げる
- hookの価値は単なる実行時間短縮ではなく、検証の文脈化
- セッション管理は人間の認知補助を含む
- 5つのコア原則の言語化

**Claude 側の強み:**
- 実体験（MVPシミュレーション、hook重さの体感）からの論点導出
- 既存アーキテクチャとの接続（4層分離、二層分離原則）
- 実装積み上げ順序の具体化（wez → workflow → orchestration）
- 「後片付けのコマンド化」の着想

**ChatGPT 側の強み:**
- 構造の分解（制御系5要素、仮想環境3種、CLI 4分類）
- 将来リスクの予測（policy埋没、自由度の死、session/kernel混同）
- 概念の再フレーミング（determinism boundary, semantic observability, orchestration cockpit）
- CLI for AI の評価フレーム提案（5軸の評価ポイント）

**相違点:**
- Claude: 実装の積み上げ順序に注力、「下から積まないと上が浮く」 → ChatGPT: 評価フレームの確立を優先、「実装より評価軸を先に持つ」
- Claude: promotion の粒度は未定義のまま → ChatGPT: intent/evidence/diff/replay log の4点セットを具体提示
- Claude: wez にオーケストレーション全体を期待する傾向 → ChatGPT: wez = session fabric に限定し、orchestration kernel を分離すべきと主張

---

## 収束した設計原則（5本柱）

### 1. コア原則 — 探索/適用分離

> 非決定的な探索と、決定的な適用を分離する。

AIエージェントの作業は「探索器」であり、その成果はそのまま production artifact ではなく候補提案。本番適用は promotion/replay を通して決定論的に行う。

### 2. 境界原則 — コマンド責務の拡張

> 機械的判断が連続する区間は command に吸収する。

設計単位は「1機能」ではなく transactional workflow segment。機械的判断の連続が途切れるところ（人間/AIの文脈判断が必要になるところ）がコマンドの境界線。

### 3. 安全原則 — 並列は探索、適用は直列

> 並列環境は探索のために使い、本番適用は promotion / replay を通して行う。

並列の成果物はそのままマージしない。仮想環境は使い捨て。merge順序問題・hidden conflict・side effect contamination を構造的に回避。

### 4. 観測原則 — semantic observability

> 検証は外部hookの事後確認より、内部commandの文脈付き検証を優先する。

コマンド内部なら入力パラメータ・途中状態・実行意図・失敗箇所・rollback可能範囲を全部持てる。hookの「外からOK/NG」より情報量が格段に多い。

### 5. 基盤原則 — セッション管理 = 認知基盤

> セッション管理は単なる端末操作ではなく、人間の認知補助を含む orchestration substrate とみなす。

複数セッション運用のボトルネックはCPU/IOではなく人間の認知負荷。どのセッションが何を担当し、どのphaseにいるかの見える化が本質。

---

## 既存Issue/Epicとの接続点

### 直接的な接続

| Issue | 接続の性質 |
|-------|-----------|
| [#20 wez CLI ツールキット](https://github.com/stlwolf/ai-development-hub/issues/20) | **物理基盤**。本議論の実装積み上げの起点。Phase 1 の7プリミティブが全ての上位設計を支える |
| [#37 Harness Engineering 基盤整備](https://github.com/stlwolf/ai-development-hub/issues/37) | **親Epic**。制御ループ不在のギャップ解消がこのEpicの中核課題 |
| [#19 自前オーケストレーションツール MVP](https://github.com/stlwolf/ai-development-hub/issues/19) | **上位目標**。起動/収束コマンド、promotion model、controller contract はこのMVPの設計要素 |
| [#21 ターミナル環境とヒューマンモード両立](https://github.com/stlwolf/ai-development-hub/issues/21) | **認知基盤**。orchestration cockpit としてのセッション管理 |
| [#24 フック拡充エピック](https://github.com/stlwolf/ai-development-hub/issues/24) | **再設計対象**。hooksをcommandに内包する方向性により、フック拡充の戦略が変わる可能性 |

### 間接的な接続

| Issue | 接続の性質 |
|-------|-----------|
| [#61 スキル/コマンドの永続化宣言](https://github.com/stlwolf/ai-development-hub/issues/61) | State Semantics がcontroller contractの前提条件 |
| [#60 implementer-contractの失敗分類精密化](https://github.com/stlwolf/ai-development-hub/issues/60) | Failure Taxonomy がcontrollerの再試行方針に必要 |
| [#62 失敗の構造化蓄積](https://github.com/stlwolf/ai-development-hub/issues/62) | Negative Knowledge がsemantic observabilityの蓄積先 |
| [#49 テスト戦略コンポーネント](https://github.com/stlwolf/ai-development-hub/issues/49) | コマンド内部検証の設計に直結 |

---

## 新規Issue候補

### 1. controller contract の定義（#37 配下）

制御ループの不在を埋める中核タスク。

- ループの停止条件
- 失敗時の再試行方針（#60 の Failure Taxonomy を前提）
- partial success の扱い
- 並列探索の打ち切り・収束条件

### 2. promotion artifact の粒度設計（#19 配下）

並列探索の成果を本番適用にどう橋渡しするかの設計。

- diff / patch queue / intent+evidence / command replay log の比較
- 既存の昇格フロー仮説（20260208）との接続
- Decision Ledger（20260329）との統合

### 3. policy extraction パターンの設計（#37 配下）

command肥大化を防ぐための policy 分離設計。

- Command / Policy / Context Resolver の3分割
- YAML等による policy 外出し
- project差分吸収の方法

### 4. CLI for AI 評価フレームの文書化（#37 配下）

新規ツール評価の判断基準を持つ。

- CLI 4分類（Primitive / Workflow / Policy-aware / Orchestration）
- 5軸の評価ポイント
- 既存canonicalコマンドの再分類

### 5. フック戦略の再検討（#24 配下）

command内包化の方向性を踏まえた hooks 戦略の見直し。

- hooks → command内部検証への移行対象の洗い出し
- 残すべきhooksの判断基準（bypass検知、外部安全柵）
- semantic observability の段階的導入

---

## 先行アイデアとの接続分析: AI Middleware CLI 構想（20260130）

20260130 の「AI開発効率化のためのミドルウェアCLI構想」「AI向けインターフェース構想」が今回の議論でどう進化したか。

### 継承（alive — 形を変えて生きている）

| 20260130 の概念 | 今回の対応 | 変化 |
|----------------|----------|------|
| コンテキスト「純度」の問題 | semantic observability | 「AIに渡す情報のノイズ除去」から「command内部で文脈付き検証する」に進化。純度の確保手段がAI外部の前処理から、command内部の情報保持に移った |
| 状態の外部化 | session管理、worktree隔離、evidence/replay log | 「コンテキストウィンドウに頼らずファイルシステムに永続化」は健在。具体形として promotion artifact（intent/evidence/diff/replay log）に結実 |
| 入力の前処理 → 出力の後処理 | command内部の一気通貫検証 | 前処理/後処理の分離が「コマンドのトランザクション境界内」に統合された |
| 「AIの注意配分を本質に集中させる」 | 「AIの判断粒度を圧縮する」 | 方向は同じだが、手段が「情報の精製」から「判断スコープの構造的縮小」に変わった |
| シナリオ分析（CLI中心/ハイブリッド等） | CLI for AI 4分類 + 5軸評価フレーム | 「どのシナリオが来るか」の予測から「どのCLIがどの役割か」の設計基準に進化 |

### 進化（evolved — 原型はあるが大幅に変形）

| 20260130 の概念 | 今回の対応 | 何が変わったか |
|----------------|----------|--------------|
| composable単機能（Unix哲学） | transactional workflow segment | **哲学は継承、粒度が移動**。「do one thing well」の原則自体は健在。変わったのは「one thing」の定義粒度。20260130 では low-level action（1検索、1フィルタ）が単位だったが、今回は「機械的判断が連続する区間」が単位。内部的に複数アクションを含むが、外から見た責務は1つ。`git commit` が内部で staging → tree → ref update をやっても「コミットする」が1責務なのと同じ構造。composability も Primitive CLI → Workflow CLI → Orchestration CLI の階層合成として生きている |
| ミドルウェアの配置（Human ↔ AI の間） | AIが呼ぶcommand層 | **方向が逆転**。原案は「人間がAIに渡す前の前処理層」、今回は「AIが呼び出す構造化された実行層」。人間→AI の間ではなく、AI→codebase の間 |
| 「AI向けインターフェース」 | determinism boundary architecture | 原案は「AIが扱いやすい形式（JSON, 機械的エラーコード）」、今回は「AIの判断スコープを縮小する境界設計」。最適化対象がインターフェースの形式から判断の構造に移った |

### 棄却（superseded — 今のアーキテクチャでは不要になった）

| 20260130 の概念 | 棄却の理由 |
|----------------|----------|
| 曖昧さ解消ツール（disambiguate） | question-driven-design スキルが担当。CLIコマンド化するより、skillとしてAIの対話能力で処理する方が適切 |
| 制約・前提の明示化ツール（constraints-for） | Context Resolver の概念に吸収。独立CLIではなくpolicyの一部として扱う |
| 類似実装の参照ツール（similar-impl） | Cursorのcodebase indexing, semantic search が担当。IDE機能で解決される領域 |
| 用語正規化ツール（normalize-terms） | rules/skills の領域。機械的判断ではなく文脈理解が必要なためcommand化に向かない |
| コンテキスト重要度スコアリング | IDE/MCP側の進化で吸収される領域。Cursorの@参照、RAG検索等 |
| フィードバック構造化ツール | human-input-formatting（20260220）のスキル領域。CLIより対話的に処理すべき |
| Pre-processing CLI Layer 全体 | 「AI外部での情報精製」という層自体が、command内部のsemantic observabilityに統合された |

### 接続分析の要約

20260130のミドルウェアCLI構想は **3ヶ月で1つの転換と1つの粒度移動** を経た:

1. **配置の逆転**: 「Human→AI の前に挟む」→「AI→codebase の間に置く」。CLIの主な呼び出し主体が人間からAIに変わった
2. **「one thing」の粒度移動**: low-level action → transactional workflow segment。ただし Unix 哲学の核心（do one thing well, composable, clear interface）は棄却ではなく **粒度を上げて継承**。Primitive → Workflow → Orchestration の階層合成がそのまま composability

根底にある問い — **「AIに任せる範囲とシステムに固定する範囲の境界をどう引くか」** — は20260130から一貫。手段が「情報の精製」から「判断の構造的縮小」に変わっただけで、問いの方向は同じ。Unix 哲学の「do one thing well」も「one thing の定義が何か」が変わっただけで、原則自体は保持されている。

**インターフェース原則の再解釈:** 「clear interface」は保持されるが、インターフェースに求められる品質特性が変わる。人間にとっての明確さは「分かりやすさ・覚えやすさ」、AIにとっての明確さは「判断コストの最小化・トークン効率・曖昧さの排除」。形式を変えるのではなく、同じ原則が**利用者の目的の違いによって異なるベネフィットを生む**。20260130 の「AI向けインターフェース構想」への3ヶ月後の回答: 形式の最適化より、目的に応じた品質特性の最適化が本質。

---

## 次に詰めるべき4論点

1. **Controller contract** — ループ停止条件、失敗時再試行方針、partial successの扱い、並列探索の収束条件
2. **Promotion artifact** — diff / patch queue / intent+evidence / command replay logのどの粒度で昇格するか
3. **Isolation model** — UI隔離(pane) / execution隔離(process/env) / workspace隔離(worktree/container)それぞれの責務分担
4. **Policy extraction** — commandに埋めるもの vs 設定として切り出すもの vs project差分吸収の方法

---

## 補足: CLI for AI の評価フレーム

今後出てくるツール群を評価する際の判断基準（ChatGPT提案）。

**CLI for AI の本質:**
> 「AIがCLIを使う」話ではなく、**AIに任せる判断と、システムに固定する判断の境界をどこに引くか** という設計の話。

**4分類:**
- Primitive CLI: 最小操作部品（session create, worktree create, capture logs）
- Workflow CLI: 機械的判断の連続区間（branch create with naming policy, PR prep）
- Policy-aware CLI: プロジェクト差分吸収（`--project`, `--mode=explore|apply`）
- Orchestration CLI: 複数セッション制御（spawn, monitor, converge, promote）

**評価5軸:**
1. 「実行」ツールか「制御」ツールか
2. policy が埋め込みか外出し可能か
3. 証跡が残るか（intent, evidence, diff, replay log）
4. 並列実行後の収束設計があるか
5. vendor固有UIの便利さ vs 抽象化可能性のバランス

---

## 補足: Cursorセッション（第三のAI）の評価と追加観点

Claude + ChatGPT のブレストを通して読んだ上で、Cursorセッションが第三のAIとして出した独自の評価・観点。

### 全体評価

5本柱の設計原則は具体例と抽象概念の両方に支えられており強い。特に **境界原則（機械的判断が連続する範囲をcommandの責務にする）** は、1月の「AI middleware CLI」、2月の「契約で固定」「3設計原則」、3月の「Decision Ledger」を統一する粒度で、**今回初めて横断的な設計原則が出た** と言える。

### 観点1: Controller は「誰か」ではなく「実行時の判断昇格チェーン」

ChatGPTの5要素モデルで Controller の位置づけが曖昧なまま残っている。当初は「人間→スクリプト→AI」の段階的移行パスとして整理したが、**Controllerは固定的な「誰」ではなく、実行時の昇格（escalation）フロー** として設計すべき。

判断できる層が判断し、判断できないものは上流に投げる:

```
Command（機械的判断）
  → 判断可能 → そのまま実行
  → 判断不可 → Agent（文脈判断）に昇格
    → 判断可能 → 実行指示をCommandに戻す
    → 判断不可 → Human（最終判断）に昇格
      → 判断 → フィードバックを下流に戻す
```

これが Human-in-the-Loop の核心。人間は常に最上流にいるが、**下流で判断がつく限り呼ばれない**。判断つかない場合に一時停止し、人間のフィードバックを受けて再開する。

**懸念:** CLIに判断を閉じ込めすぎると、「判断できないという判断」自体が上流に伝播しない死角が生まれる。コマンドが「成功/失敗」の二値しか返さない設計だと、「判断できなかった」「部分的に成功した」「想定外の状態になった」を表現できず、昇格シグナルが消える。

**設計上の含意:**
- Command の戻り値は成功/失敗だけでなく、**escalation signal** を含む必要がある（success / failure / needs_decision / partial / unknown）
- これは implementer-contract のステータス enum（done / blocked / failed / needs_review）と同じ構造
- Sensor（semantic observability）の情報粒度がこの昇格判断の精度を直接決める

つまり Controller contract の核心は「誰がcontrollerか」ではなく「**昇格条件と戻りの経路をどう定義するか**」。

### 観点2: Semantic Observability の射程 — 推測比率モデルとの接続

ChatGPTが出した semantic observability は、hooks削減の文脈で使われているが射程はもっと広い。

推測比率の4変数モデル（20260218）との接続:
- hookの外部事後検証 = 「情報を切り落としてから検証」 → 推測比率が高い
- command内部の文脈付き検証 = 「切り落とし前の情報で検証」 → 推測比率が低い

> **Semantic observability は、検証フェーズにおける推測比率を下げる手段。**

これは失敗時の回復精度にも直結する。hookの「NG」は荒い情報だが、command内部の「この引数でこのステップが失敗した」は回復の入力にそのまま使える。つまり semantic observability は **Controller（昇格チェーン）の判断精度を直接決める Sensor の情報粒度** でもある。

Controller contract を定義するなら、先に Sensor（semantic observability）の情報粒度を決める必要がある。

### 観点3: Execution Mode — canonical に欠けている概念

ChatGPTの懸念「コマンド中心化でエージェントの自由度が死ぬ」に対して、exploration / production / repair / audit のモード分離が提案されている。これは **canonical 構造に「モード」概念が存在しない** 問題を示唆している。

現状、rules も skills も commands も hooks も常に同じ拘束度で適用される。しかし実際には:
- 探索フェーズでは naming convention を緩めたい
- 本番適用フェーズでは全hookを通したい
- 修復フェーズではhookを一時バイパスしたい（監査ログは残す）

canonical に **execution mode** を導入すると:

```
Command × Policy × Context × Mode → 実際の振る舞い
```

Mode が拘束度の調整弁になり、「内包しすぎて自由度が死ぬ」と「hook全部通すと重い」が同時に解ける。exploration mode なら軽量版、production mode ならフル版。

### 観点4: 未言及の既存議論との接続

- **20260224 hypothesis-design-ci-parallel-agents.md**: 観点特化エージェント群の並列パイプラインは、今回の「並列探索→収束→直列適用」のドメイン特化版
- **20260208 hypothesis-second-opinion-review-flow.md**: 反証担当固定は、並列探索で「各セッションに異なる観点を割り当てる」設計原則として使える。並列は同じタスクの分割だけでなく、**異なる観点からの検証の並列化** もできる

### 優先順位の提案

1. **Controller の昇格チェーン設計** — escalation signal の定義。implementer-contract のステータス enum を参考に
2. **Semantic observability の情報粒度定義** — Controller（昇格チェーン）の判断精度を決める Sensor 仕様
3. **Execution mode の canonical 導入検討** — Policy extraction と合わせて設計
4. **wez Phase 1 着手** — 初期 controller = 人間の物理的帰結

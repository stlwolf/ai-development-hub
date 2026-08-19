# 関連マップ

個別ファイルは凍結スナップショットのため、後から発見された関連性はここに集約する。
新しい接続が見つかったら追記していく。

---

## テーマ軸の接続

### 可読性の対象シフト（人間→AI）

「誰のための可読性か」という問いが、インターフェースレベルからコードレベルへ段階的に具体化されてきた流れ。

- [20260130/ai-native-interface-concept.md](20260130/ai-native-interface-concept.md) — AI向けインターフェースと中間言語の逆転（起点）
- [20260215/ai-readable-code-discussion-log-chatgpt.md](20260215/ai-readable-code-discussion-log-chatgpt.md) — コードレベルへの拡張：AIが正しく説明できる形が正義になる可能性
- [20260215/ai-readable-code-evaluation-claude.md](20260215/ai-readable-code-evaluation-claude.md) — 「AI-Readableは現時点では良い設計の別名」という留保
- [20260820/human-readable-generation-discussion.md](20260820/human-readable-generation-discussion.md) — 起点の問いに測定つきの回答が付いた折り返し点。AI の読解も人間可読な言葉（名前）に強く依存する（識別子除去で理解が落ちる）ため「中間言語の逆転」は読解側の証拠で棄却方向。for AI に効くのは文の圧縮でなく機械が解ける構造で、20260215 の「良い設計の別名」という留保に外部測定の裏付けが付いた。純粋SO 3レーンの反証を経て、レジスタは読者種（人間/AI）でなくアクセスパターン（精読/走査）で選ぶ、という対抗軸が加わった（可読性の対象が「誰が読むか」から「どう読むか」へ）

### 意味記憶 vs エピソード記憶 → 書くアンカー vs 読むアンカー

「What」と「Why/When/How」の区別が、異なる文脈から同じ構造に到達した。

- [20260121/episodic_memory_data.md](20260121/episodic_memory_data.md) — 意味記憶(What) vs エピソード記憶(Why/When/How) の分類（起点）
- [20260215/ai-readable-code-evaluation-claude.md](20260215/ai-readable-code-evaluation-claude.md) — 書くためのアンカー ≈ 意味記憶、読むためのアンカー ≈ 意味記憶 + エピソード記憶
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 5つのアンカー群（Schema/Contract/Invariant/Flow/Decision）への展開
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 層4(コード=What)と層3(生ログ=Why/How)の分離が同じ構造を再現。層2は抽出済みエピソード記憶に対応

### AI-Readableの4性質 ↔ 意図的圧縮の三層構造

一方が設計原則、他方がドキュメント層での実装形態。同型性→層の明確さ、局所性→圧縮層、単調性→上書き禁止+supersedes、検証可能性→Episode層。

- [20260208/hypothesis-intentional-compression-and-promotion-flow.md](20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 三層構造 + 昇格フロー（実装側）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — AI-Readableの4性質（原則側）

### コンテキスト限界の複雑性

1月に列挙した課題が、2月にBrooksの複雑性分類の拡張として理論的な枠組みを得た。さらにFWアップグレード実践を通じて永続化層のモデルとして具体化。

- [20260130/generative-ai-development-challenges.md](20260130/generative-ai-development-challenges.md) — コンテキスト消失・ドメイン理解の欠如・成果物の劣化（問題列挙）
- [20260130/ai-middleware-cli-concept.md](20260130/ai-middleware-cli-concept.md) — コンテキスト「純度」の問題（対策構想）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 「AIのコンテキスト限界に起因する新しい複雑性」として再分類
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 4層モデルによる具体的な対処アーキテクチャ。層3の抽出パイプライン未実装が現時点のボトルネック

### 有機的理解の搬送

抽象的な目標（有機的理解）に対して、具体的な搬送形態（エンベロープ）と蓄積基盤（ガイドAgent）が対応する。4層モデルが「どこに蓄積するか」を定義。

- [20260121/ai-agent-orchestration.md](20260121/ai-agent-orchestration.md) — ガイドAgent：文脈と履歴を理解するモデレーター（蓄積側）
- [20260204/ai-agent-orchestration.md](20260204/ai-agent-orchestration.md) — コンテキスト・エンベロープ：Immutable/Mutableの分離（搬送側）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 有機的理解の定義：静的+動的+意味的+時間的+因果的の統合（目標側）
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 有機的理解が4層のどこに住むかを定義。Issue(層1)=契約、構造化ナレッジ(層2)=抽出済み理解、生ログ(層3)=未抽出の因果情報（永続化側）

### セカンドオピニオンと複数AIの理解収束

反証担当の役割固定と、複数AIに同じコードを説明させて収束度を見る発想が接続。さらにSOに渡すプロンプトの構造化が収束速度に影響することが実践で判明。

- [20260208/hypothesis-second-opinion-review-flow.md](20260208/hypothesis-second-opinion-review-flow.md) — 反証担当を固定したレビューフロー
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 検証Action 1：複数AIの説明精度と収束度を比較
- [20260220/so-prompt-formatting.md](20260220/so-prompt-formatting.md) — SOプロンプトの構造化度合いが収束速度に影響。タスクタイプ別テンプレートの提案
- [20260224/hypothesis-design-ci-parallel-agents.md](20260224/hypothesis-design-ci-parallel-agents.md) — レビューゲートの自動化をデザイン領域に拡張。観点特化エージェント群によるCI化で「Failだけ人間が見る」構造

### 契約による一貫性 → 正準フォーマット → 入力品質の標準化

「ツール名ではなく契約で固定する」原則の具体化として正準フォーマットが生まれ、さらにAI間・人間-AI間の入力フォーマット標準化へ展開。

- [20260208/ai-orchestration-memo-idea-integration.md](20260208/ai-orchestration-memo-idea-integration.md) — 母艦は「ツール名」ではなく「契約」（原則）
- [20260212/hypothesis-canonical-agent-definition-format.md](20260212/hypothesis-canonical-agent-definition-format.md) — 正準エージェント定義フォーマット（具体化）
- [20260220/so-prompt-formatting.md](20260220/so-prompt-formatting.md) — SOプロンプトのテンプレート化（AI→AI契約の実装）
- [20260220/human-input-formatting.md](20260220/human-input-formatting.md) — 人間→AIの入力も契約化。「個人スキルではなくプロセスとして入力品質を標準化」
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — Command / Policy / Context Resolver の3分割。policyをcommandに焼き込まず外出しすることで、契約の一貫性を維持しつつプロジェクト差分を吸収

### 意図的圧縮の三層 → コンテキスト永続化の4層 → Promotion Model

仮説段階の三層構造が、FWアップグレード実践を経て運用指向の4層モデルへ発展。昇格ルールとTTLが加わり、抽象的な圧縮理論が具体的な情報ライフサイクル管理になった。4月にオーケストレーション文脈で promotion artifact の粒度設計へ展開。

- [20260208/hypothesis-intentional-compression-and-promotion-flow.md](20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 三層構造 + 昇格フロー（理論側）
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 4層 + TTL + 昇格基準 + メタデータスキーマ（運用側）
- [20260224/hypothesis-json-schema-aggregation-orchestration.md](20260224/hypothesis-json-schema-aggregation-orchestration.md) — 昇格フローのJSON実装形態。promotionフィールドが「子スレッドから親スレッドへの情報昇格」を構造化
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — promotion model をオーケストレーション文脈に適用。並列探索の成果物を本番適用に橋渡しする粒度設計（intent / evidence / diff / replayable command log の4点セット）。「再実行」ではなく「昇格」が核心

### 推測比率と確実性の構造モデル

1月の課題リスト → 2月の有機的理解 → 確実性を操作可能にするフレームワークへ。「何が問題か」→「何を目指すか」→「どの変数を操作すれば効くか」の発展。

- [20260130/generative-ai-development-challenges.md](20260130/generative-ai-development-challenges.md) — 本質的課題のリスト（問題列挙）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 有機的理解と5つのアンカー群（目標定義）。アンカー群が推測比率の段階的低下に対応
- [20260218/hypothesis-inference-ratio-certainty-model.md](20260218/hypothesis-inference-ratio-certainty-model.md) — 確実性の4変数モデル、推測比率の設計変数化（操作フレームワーク）
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 4層モデル。「情報の量」と「切り落としの精度」の永続化実装

### データ境界と意味の変質（Truth-in-Context）

SSOTの限界からDDDのBounded Contextを経由して、AIの推測比率の問題に接続。

- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 「単一のSSOTでは不十分、複数のアンカーの組み合わせが必要」（起点）
- [20260218/discussion-log-inference-ratio-domain-boundaries.md](20260218/discussion-log-inference-ratio-domain-boundaries.md) — DDDのBounded Contextとの接続。信頼の単位は境界であってシステム全体ではない
- [20260218/hypothesis-inference-ratio-certainty-model.md](20260218/hypothesis-inference-ratio-certainty-model.md) — Truth-in-Context（境界ごとの真実の束）として再定義。境界の明示で推測比率が構造的に下がる

### ルーラーエージェント構想（ガイドAgentの具体化）

ガイドAgent → コンテキスト・エンベロープ → ルーラーエージェントへ。「文脈と履歴を理解するモデレーター」が「過去の判断に基づいて正確にガイドするナビゲーター」として具体化。

- [20260121/ai-agent-orchestration.md](20260121/ai-agent-orchestration.md) — ガイドAgent：文脈と履歴を理解するモデレーター（原型）
- [20260204/ai-agent-orchestration.md](20260204/ai-agent-orchestration.md) — コンテキスト・エンベロープ（搬送形態）
- [20260218/discussion-log-inference-ratio-domain-boundaries.md](20260218/discussion-log-inference-ratio-domain-boundaries.md) — ルーラーエージェント：新規判断はせず過去の判断に基づくガイド。既存の「コードベースナビゲーター」との差異は「判断履歴のナビゲーター」である点
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — ルーラーが読むデータの永続化層

### レビュー負荷の非線形性とセカンドオピニオン

セカンドオピニオンの精度向上効果が、レビューモードの不連続な切替を引き起こす。

- [20260208/hypothesis-second-opinion-review-flow.md](20260208/hypothesis-second-opinion-review-flow.md) — セカンドオピニオンフローの仮説（反証担当の固定）
- [20260218/hypothesis-inference-ratio-certainty-model.md](20260218/hypothesis-inference-ratio-certainty-model.md) — 精度90%→98%でレビューモードが不連続に変わる。精度向上の目的は「正答率の向上」以上に「人間の監督モードの切替」
- [20260220/so-prompt-formatting.md](20260220/so-prompt-formatting.md) — SOプロンプトの構造化がこのモード切替の閾値到達に寄与

### 入力品質の双方向標準化

AI→AI（SOプロンプト）と人間→AI（ドメイン入力）の両方向で入力フォーマット化の必要性が同時に浮上。共通する洞察は「出力品質は入力品質に支配される」。

- [20260220/so-prompt-formatting.md](20260220/so-prompt-formatting.md) — AI→AI方向。プロンプトの構造化度合いが収束速度を左右
- [20260220/human-input-formatting.md](20260220/human-input-formatting.md) — 人間→AI方向。AI側が質問フォーマットを提示し人間が回答する形が持続可能
- [20260130/ai-middleware-cli-concept.md](20260130/ai-middleware-cli-concept.md) — コンテキスト「純度」の問題意識が、入力品質の標準化として具体化

### Decision Ledger と意図的圧縮・永続化の収束

仮説段階の三層構造（Context/Decision/Episode）→ 4層モデル → Decision Ledger + 自動抽出。理論的な「情報のライフサイクル」が、post-commit hook + LLM による具体的な自動化手段と合流。

- [20260208/hypothesis-intentional-compression-and-promotion-flow.md](20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 三層構造 + 昇格フロー（理論側）。Episode → Decision → Context
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 4層モデル。層3の抽出パイプラインが未実装というボトルネック
- [20260329/metadata-layer-mirror-repo-synthesis.md](20260329/metadata-layer-mirror-repo-synthesis.md) — Decision Ledger を SoT とする設計。post-commit hook + LLM で層3→層2の自動抽出を実現する候補。Phase計画（flat ledger → view → AGENTS.md）は昇格フローの実装形態

### メタデータ層と正規化・ビューの分離

「保存の正規形」「AIへの投影」「人間への投影」を分けて考える発想。DBの正規化とビューの関係をメタデータ設計に適用。

- [20260329/metadata-layer-mirror-repo-synthesis.md](20260329/metadata-layer-mirror-repo-synthesis.md) — ledger（保存） / tree（AI投影） / AGENTS.md（人間投影）の三分割。SoT は ledger、tree は materialized context view
- [20260221/document-format-design-principles.md](20260221/document-format-design-principles.md) — write:read 比率によるフォーマット判断。「書く形式」と「読む形式」の分離が同じ問題構造
- [20260224/hypothesis-json-schema-aggregation-orchestration.md](20260224/hypothesis-json-schema-aggregation-orchestration.md) — 子スレッド→親スレッドの情報昇格をJSONスキーマで構造化。ledger の保存形式との接続
- [20260820/human-readable-generation-discussion.md](20260820/human-readable-generation-discussion.md) — 「書く形式と読む形式の分離」に測定根拠が合流（生成中に形式を課すと精度が落ち、自由生成→後整形で回復する format tax の非対称）。人間投影/AI 投影の分離を文体（register）層まで拡張し、意味を運ぶ層は自然言語が有力な既定、という境界を引いた。SO の codex レーンが出した「意味・根拠構造を正本にし用途別ビューをレンダリングする」案は、ledger（保存）/tree（AI投影）/AGENTS.md（人間投影）三分割の register 版そのもの

### エピソード記憶と決定記録の接続

「何を保存すべきか」の議論が、エピソード記憶の分類から Decision Ledger の具体設計へ収束。

- [20260121/episodic_memory_data.md](20260121/episodic_memory_data.md) — 意味記憶(What) vs エピソード記憶(Why/When/How) の分類（起点）
- [20260215/ai-readable-code-evaluation-claude.md](20260215/ai-readable-code-evaluation-claude.md) — 書くためのアンカー ≈ 意味記憶、読むためのアンカー ≈ 意味記憶 + エピソード記憶
- [20260329/metadata-layer-mirror-repo-synthesis.md](20260329/metadata-layer-mirror-repo-synthesis.md) — 「エピソード記憶の方が残りやすく、そこから意味記憶は再抽出可能」。Decision Ledger は構造化されたエピソード記憶として機能

### ルーラーエージェントと Decision Ledger

ルーラーエージェント（過去の判断に基づくガイド）が読むデータの永続化層として Decision Ledger が位置づけられる。

- [20260218/discussion-log-inference-ratio-domain-boundaries.md](20260218/discussion-log-inference-ratio-domain-boundaries.md) — ルーラーエージェント: 新規判断はせず過去の判断に基づくガイド
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — ルーラーが読むデータの永続化層
- [20260329/metadata-layer-mirror-repo-synthesis.md](20260329/metadata-layer-mirror-repo-synthesis.md) — Decision Ledger の検索可能性がルーラーの精度を直接決める。ledger → view → AGENTS.md のパイプラインがルーラーの読み取りインターフェースになる

### Mirror Repo と有機的理解の接地

有機的理解（静的+動的+意味的+時間的+因果的の統合）を、repo tree という物理構造に接地させて実現する構想。

- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 有機的理解の定義。5つのアンカー群（Schema/Contract/Invariant/Flow/Decision）
- [20260329/metadata-layer-mirror-repo-synthesis.md](20260329/metadata-layer-mirror-repo-synthesis.md) — mirror repo は「意味論的圧縮のための物理UI」。人間が理解の起点とする repo tree に接地しながら意味・判断・制約を重ねる。アンカー群の「Decision」が Decision Ledger に対応
- [20260329/discussion-logs/metadata-layer-discussion-claude.md](20260329/discussion-logs/metadata-layer-discussion-claude.md) — 司書エージェントの発想との合流。段階的ローディングによるトークン制御
- [20260329/discussion-logs/metadata-layer-mirror-repo-discussion.md](20260329/discussion-logs/metadata-layer-mirror-repo-discussion.md) — ledger/tree 正規形比較、仮想意味論層・北極星としての mirror、物理層起点の議論

### ドキュメントフォーマットの設計原則 → ルール分割

cursor-thread-tools 4フェーズの実践から「いつフォーマットが必要で、いつ不要か」の判断基準が導出。さらに「集権的ルールをマルチエージェントにどう分割するか」の問題へ発展。

- [20260215/ai-readable-code-evaluation-claude.md](20260215/ai-readable-code-evaluation-claude.md) — 書くためのアンカー ≠ 読むためのアンカー（起点）
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — フリーフォーム本文 ≈ 層3圧縮、構造化FB ≈ 層2候補
- [20260221/document-format-design-principles.md](20260221/document-format-design-principles.md) — write:read 比率、目的指示 vs 手段指示、ハイブリッド構成（原則定義）
- [projects/agent-rule-decomposition/](../projects/agent-rule-decomposition/) — 集権的ルールのマルチエージェント分割（検証プロジェクト）

### 正準フォーマット → ルール配布アーキテクチャ

エージェント「の」定義フォーマットと、エージェント「への」ルール配布は別の問題。正準フォーマットの `domain_context` フィールドが「何を参照するか」を定義するのに対し、ルール分割は「どの粒度で・どの優先順位で渡すか」を扱う。

- [20260212/hypothesis-canonical-agent-definition-format.md](20260212/hypothesis-canonical-agent-definition-format.md) — エージェント定義の正準フォーマット（`domain_context` フィールド）
- [20260208/ai-orchestration-memo-idea-integration.md](20260208/ai-orchestration-memo-idea-integration.md) — 「契約で固定、ツール名では固定しない」原則
- [projects/agent-rule-decomposition/](../projects/agent-rule-decomposition/) — ルールの分割粒度・配布メカニズム・衝突解決の検証

### OSSオーケストレーション調査 → 自前ツール構築 → ハーネス層分離

既存OSSのインフラ層（ワークスペース隔離、プロセス管理、イベント駆動フィードバック）と、自分の検証知見のセマンティック層（認知協調、知識永続化）の非対称性を活かした統合アプローチ。4月にcanonical 4層を「決定性の境界」で再整理し、具体的なアーキテクチャ設計へ発展。

- [20260204/ai-agent-orchestration.md](20260204/ai-agent-orchestration.md) — CLI連携の初期検証。マルチエージェントの本質分析、コンテキスト・エンベロープの提案（起点）
- [20260208/ai-orchestration-synthesis-next-steps.md](20260208/ai-orchestration-synthesis-next-steps.md) — 「契約で固定、ツール名で固定しない」原則、検証優先度の整理
- [20260222/orchestration-tool-building-approach.md](20260222/orchestration-tool-building-approach.md) — OSSリサーチ→要素抽出→自前構築のアプローチ。インフラ層×セマンティック層の合成戦略。付属GUIビューワー構想
- [20260222/oss-orchestrator-analysis-agent-orchestrator.md](20260222/oss-orchestrator-analysis-agent-orchestrator.md) — agent-orchestrator分析。CLAUDE.md/CLAUDE.orchestrator.md のルール分離パターンがagent-rule-decompositionの実例として接続
- [projects/orchestration-research/](../projects/orchestration-research/) — 体系的調査プロジェクト
- [20260224/orchestration-design-principles-bath-brainstorm.md](20260224/orchestration-design-principles-bath-brainstorm.md) — 3設計原則（ベンダー非依存・直列プリミティブ合成・拡張可能）。OSSリサーチアプローチの上に乗る設計指針
- [20260224/hypothesis-json-schema-aggregation-orchestration.md](20260224/hypothesis-json-schema-aggregation-orchestration.md) — 親子スレッドの橋渡しをJSONスキーマで構造化。steipeteの並列ETLパターンの転用
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — 4層分離を「決定性の境界」で再整理。determinism boundary architecture、5本柱の設計原則、閉ループ制御系の5要素モデル。3設計原則の上にコマンド責務拡張・制御ループ・promotion modelの具体設計が乗る形

### 決定性の境界設計と制御ループ（Determinism Boundary Architecture）

canonical 4層の責務を「抽象度」ではなく「決定性」で再整理した設計軸。commands/hooks = 決定論的・検証可能、agents = 非決定論的・探索的。並列探索（非決定的）と直列適用（決定的）の分離が中核。制御ループの不在をcontroller contract で埋める方向。

- [20260204/ai-agent-orchestration.md](20260204/ai-agent-orchestration.md) — 「決定論的オーケストレーターが非決定論的ワーカーを制御する」の原型
- [20260224/orchestration-design-principles-bath-brainstorm.md](20260224/orchestration-design-principles-bath-brainstorm.md) — 3設計原則。直列プリミティブ合成が「決定論的な適用」の具体形
- [20260218/hypothesis-inference-ratio-certainty-model.md](20260218/hypothesis-inference-ratio-certainty-model.md) — 推測比率の構造モデル。決定性の境界を明示することで推測比率を構造的に下げる手段の一つ
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — determinism boundary architecture の命名と5本柱。閉ループ制御系（Policy/Planner/Actuator/Sensor/Controller）、コマンド責務拡張（transactional workflow segment）、semantic observability
- [20260618/remote-harness-cloud-substrate-extension.md](20260618/remote-harness-cloud-substrate-extension.md) — 20260414が特定した「制御ループの不在」への回答。ラフループの駆動面を remote（Routines の cron/event 再fire + state-in-artifact）に外出しする。決定性の境界（強制力）が「ローカルの hook deny」から「GitHub の branch protection / required check」へ移設されるのが核心の補正

### CLI for AI — 判断粒度の圧縮と評価フレーム

CLI for AI の本質は「AIがCLIを使う」ではなく「AIに任せる判断とシステムに固定する判断の境界設計」。散文的な手順理解を構造化された選択に変えることで、判断粒度を圧縮する。AI middleware CLIの構想がコマンド責務拡張の原則として具体化。

- [20260130/ai-middleware-cli-concept.md](20260130/ai-middleware-cli-concept.md) — AI CLIと人間の間に挟まるミドルウェア層の構想（起点）
- [20260222/orchestration-tool-building-approach.md](20260222/orchestration-tool-building-approach.md) — 自前ツール構築のアプローチ。CLI層の具体的な位置づけ
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — CLI for AI 4分類（Primitive/Workflow/Policy-aware/Orchestration）、5軸評価フレーム、「判断の粒度が散文解釈から引数選択に落ちる」
- [20260414/discussion-logs/harness-architecture-discussion-chatgpt.md](20260414/discussion-logs/harness-architecture-discussion-chatgpt.md) — CLIに寄せるべきもの / skill に残すべきもの / hook に残すべきもの / orchestrator に持たせるべきものの4分割判断基準

### 仮想環境隔離とセッション管理 — 物理基盤としてのwez

並列オーケストレーションの安全性を仮想環境隔離で確保するパターン。UI隔離 / execution隔離 / workspace隔離 の3種分離。wez CLI を session fabric として位置づけ、orchestration kernel と明確に分離する。

- [20260222/orchestration-tool-building-approach.md](20260222/orchestration-tool-building-approach.md) — ワークスペース隔離をOSSインフラ層の要素として分析
- [20260224/hypothesis-design-ci-parallel-agents.md](20260224/hypothesis-design-ci-parallel-agents.md) — 観点特化エージェント群の並列パイプライン。並列実行の具体的なユースケース
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — 仮想環境3種分離（UI/execution/workspace）、wez = session fabric / worktree = execution sandbox / orchestrator = promotion manager。セッション管理 = 認知補助（orchestration cockpit）
- [20260414/discussion-logs/harness-architecture-discussion-claude.md](20260414/discussion-logs/harness-architecture-discussion-claude.md) — MVPシミュレーション体験からの隔離パターン導出。並列探索→破棄→直列再実行、後片付けのコマンド化

### agent-orchestrator のルール分離 → ルール分割検証

ComposioHQ/agent-orchestrator の CLAUDE.md（実装向け）vs CLAUDE.orchestrator.md（オーケストレーター向け）の分離は、agent-rule-decomposition で検討している「関心ベースの分割」の運用実例。知見: 分割軸は「重要度」ではなく「関心」、オーケストレーターにはランブック型（手続き的手順書）が効く、重複ゼロを実現。

- [20260222/oss-orchestrator-analysis-agent-orchestrator.md](20260222/oss-orchestrator-analysis-agent-orchestrator.md) — ルール分離パターンの分析
- [20260221/document-format-design-principles.md](20260221/document-format-design-principles.md) — ルール分割時に「何を渡すか」の判断基準（write:read比率）
- [projects/agent-rule-decomposition/](../projects/agent-rule-decomposition/) — 検証プロジェクト。分科会知見セクションに既に記録済み

### ハーネスの版図拡張 — ローカルからクラウド基板へ（remote ハーネス）

これまでの設計はすべて「ローカル（ラップトップ）で動くハーネス」を前提にしていた。Routines / Claude Code on the web の登場で、ハーネスの版図をクラウド基板まで延ばす新次元が加わる。重い部分（スケジューラ・サンドボックス・永続化）をマネージドクラウドに外出しすることで、リポジトリは markdown のまま「薄く大きく」reach を広げる。設計面の越境問題（`~/.claude` は cloud に行かない → 資産を repo にコミット/inline）が新たな制約軸。

- [20260224/orchestration-design-principles-bath-brainstorm.md](20260224/orchestration-design-principles-bath-brainstorm.md) — 3設計原則（ベンダー非依存・直列プリミティブ合成・拡張可能）。「薄く大きく」の源流
- [20260414/harness-architecture-layer-separation-control-loop.md](20260414/harness-architecture-layer-separation-control-loop.md) — ローカル前提のハーネス層分離。制御ループの駆動面が remote 化の主対象
- [20260329/metadata-layer-mirror-repo-synthesis.md](20260329/metadata-layer-mirror-repo-synthesis.md) — Decision Ledger を成果物に置く設計。remote の stateless fire をまたぐ state-in-artifact（repo/PR/commit status に状態を置く）の先行形
- [20260618/remote-harness-cloud-substrate-extension.md](20260618/remote-harness-cloud-substrate-extension.md) — ハーネスの4面分解（トリガ/実行/設定/ゲート）と5スロット座標系。(A)非機械的フローの強制 と (B)持続ラフループ の2系統、remote で初めて可能な4フロー原型、到達点の半径(i-iv)

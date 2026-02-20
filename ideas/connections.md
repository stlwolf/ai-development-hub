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

### 契約による一貫性 → 正準フォーマット → 入力品質の標準化

「ツール名ではなく契約で固定する」原則の具体化として正準フォーマットが生まれ、さらにAI間・人間-AI間の入力フォーマット標準化へ展開。

- [20260208/ai-orchestration-memo-idea-integration.md](20260208/ai-orchestration-memo-idea-integration.md) — 母艦は「ツール名」ではなく「契約」（原則）
- [20260212/hypothesis-canonical-agent-definition-format.md](20260212/hypothesis-canonical-agent-definition-format.md) — 正準エージェント定義フォーマット（具体化）
- [20260220/so-prompt-formatting.md](20260220/so-prompt-formatting.md) — SOプロンプトのテンプレート化（AI→AI契約の実装）
- [20260220/human-input-formatting.md](20260220/human-input-formatting.md) — 人間→AIの入力も契約化。「個人スキルではなくプロセスとして入力品質を標準化」

### 意図的圧縮の三層 → コンテキスト永続化の4層

仮説段階の三層構造が、FWアップグレード実践を経て運用指向の4層モデルへ発展。昇格ルールとTTLが加わり、抽象的な圧縮理論が具体的な情報ライフサイクル管理になった。

- [20260208/hypothesis-intentional-compression-and-promotion-flow.md](20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 三層構造 + 昇格フロー（理論側）
- [20260220/context-persistence-4layer-model.md](20260220/context-persistence-4layer-model.md) — 4層 + TTL + 昇格基準 + メタデータスキーマ（運用側）

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

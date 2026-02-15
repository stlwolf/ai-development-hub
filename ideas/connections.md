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

### AI-Readableの4性質 ↔ 意図的圧縮の三層構造

一方が設計原則、他方がドキュメント層での実装形態。同型性→層の明確さ、局所性→圧縮層、単調性→上書き禁止+supersedes、検証可能性→Episode層。

- [20260208/hypothesis-intentional-compression-and-promotion-flow.md](20260208/hypothesis-intentional-compression-and-promotion-flow.md) — 三層構造 + 昇格フロー（実装側）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — AI-Readableの4性質（原則側）

### コンテキスト限界の複雑性

1月に列挙した課題が、2月にBrooksの複雑性分類の拡張として理論的な枠組みを得た。

- [20260130/generative-ai-development-challenges.md](20260130/generative-ai-development-challenges.md) — コンテキスト消失・ドメイン理解の欠如・成果物の劣化（問題列挙）
- [20260130/ai-middleware-cli-concept.md](20260130/ai-middleware-cli-concept.md) — コンテキスト「純度」の問題（対策構想）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 「AIのコンテキスト限界に起因する新しい複雑性」として再分類

### 有機的理解の搬送

抽象的な目標（有機的理解）に対して、具体的な搬送形態（エンベロープ）と蓄積基盤（ガイドAgent）が対応する。

- [20260121/ai-agent-orchestration.md](20260121/ai-agent-orchestration.md) — ガイドAgent：文脈と履歴を理解するモデレーター（蓄積側）
- [20260204/ai-agent-orchestration.md](20260204/ai-agent-orchestration.md) — コンテキスト・エンベロープ：Immutable/Mutableの分離（搬送側）
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 有機的理解の定義：静的+動的+意味的+時間的+因果的の統合（目標側）

### セカンドオピニオンと複数AIの理解収束

反証担当の役割固定と、複数AIに同じコードを説明させて収束度を見る発想が接続。

- [20260208/hypothesis-second-opinion-review-flow.md](20260208/hypothesis-second-opinion-review-flow.md) — 反証担当を固定したレビューフロー
- [20260215/ai-readable-code-organic-understanding-synthesis.md](20260215/ai-readable-code-organic-understanding-synthesis.md) — 検証Action 1：複数AIの説明精度と収束度を比較

### 契約による一貫性 → 正準フォーマット

「ツール名ではなく契約で固定する」原則の具体化として正準フォーマットが生まれた。

- [20260208/ai-orchestration-memo-idea-integration.md](20260208/ai-orchestration-memo-idea-integration.md) — 母艦は「ツール名」ではなく「契約」（原則）
- [20260212/hypothesis-canonical-agent-definition-format.md](20260212/hypothesis-canonical-agent-definition-format.md) — 正準エージェント定義フォーマット（具体化）

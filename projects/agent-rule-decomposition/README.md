# agent-rule-decomposition

マルチエージェント/サブエージェント環境におけるドキュメントルール分割の検証プロジェクト。

## 背景

cursor-thread-tools の Phase 1〜4 開発で確立した CONVENTIONS.md（集権的ドキュメントルール）は、単一エージェント + セカンドオピニオンのフローでは機能した。しかし、サブエージェントやエージェントオーケストレーションで並列タスクを実行する場合、以下の懸念がある:

- **コンテキスト予算の浪費**: CONVENTIONS.md 全体（200行超）を全サブエージェントに渡すのは非効率。実装エージェントに episode FB 構造は不要
- **制御の離散化**: 並列エージェントがそれぞれ異なる解釈でルールを適用するリスク
- **ルール衝突**: 親エージェントのルールとサブエージェント固有のルールが矛盾した場合の解決方法が未定義
- **配布メカニズムの選択**: スキル（SKILL.md）vs ルール（.mdc / AGENTS.md）vs プロンプト直接注入のどれが最適か

## 検証すべき問い

### ルール分割粒度

- CONVENTIONS.md をどの粒度で分割するか（セクション単位？役割単位？タスク単位？）
- 分割したルールの「組み合わせ」をどう定義するか

### エージェント役割とルールのマッピング

- 実装エージェント: ADR 基準、コーディング規約
- レビューエージェント: FB 構造、検証マトリクスの使い方
- ドキュメントエージェント: episode 構造、frontmatter ルール
- 各役割に必要なルールの最小セットは何か

### 配布メカニズムと優先順位

- Cursor: スキル（SKILL.md） / ルール（.mdc） / Project Rules / User Rules の優先順序
- Claude Code: CLAUDE.md / AGENTS.md の適用範囲
- ルール衝突時の解決ルール（例: 具体的なルールが汎用ルールに勝つ？）

### 動的ルール選択

- タスクの内容に応じて必要なルールを動的に選択できるか
- 正準エージェント定義フォーマット（ideas/20260212）の `domain_context` フィールドとの連携

## 関連資料

| 資料 | 関係 |
|------|------|
| [ideas/20260221/document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) | #1/#2 の原則。ルール分割時に「何を渡すか」の判断基準になる |
| [ideas/20260212/hypothesis-canonical-agent-definition-format.md](../../ideas/20260212/hypothesis-canonical-agent-definition-format.md) | エージェント「の」定義フォーマット。ここで扱うのはエージェント「への」ルール配布 |
| [projects/cursor-thread-tools/CONVENTIONS.md](../cursor-thread-tools/CONVENTIONS.md) | 分割対象の集権的ルール。4フェーズの運用実績あり |
| [ideas/20260208/ai-orchestration-synthesis-next-steps.md](../../ideas/20260208/ai-orchestration-synthesis-next-steps.md) | 「契約で固定、ツール名では固定しない」原則 |

## 検証アプローチ（案）

1. **現状把握**: Cursor のスキル/ルール/Project Rules の優先順位を実機で確認
2. **分割試行**: CONVENTIONS.md を役割別に分割し、サブエージェントに渡して結果を比較
3. **大規模タスク検証**: わざと複雑なタスクを設計し、並列サブエージェントがルールをどの程度遵守するか観察
4. **ルール衝突テスト**: 矛盾するルールを意図的に設定し、エージェントの挙動を確認

## 状態

議論ドキュメント段階。サブエージェント/スキル機能のキャッチアップと並行して検証を進める。

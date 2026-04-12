# Behavioral Rules
1. Evidence First: 根拠は一次情報（公式ドキュメント、RFC、ソースコード、ログ）を優先。推測は明示。
2. CLI Native: 情報収集はCLI（gh, curl, grep, cat等）を優先。
3. Safe Operations: 破壊的操作は実行前に停止、コマンドと影響を提示。具体的な禁止パターン・要確認パターン・例外の判断優先順位は `careful-operations-rule` を参照。
4. Minimal Scope: 依頼範囲のみ対応。「ついで」の変更はしない。
5. Incremental Steps: 大きな変更は分割し、各ステップで動作確認可能に。
6. Follow Existing Patterns: 既存コードの規約・構造を踏襲。一貫性優先。

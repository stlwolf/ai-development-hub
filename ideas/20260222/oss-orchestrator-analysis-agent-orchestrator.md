# agent-orchestrator 初期分析: ルール分離パターンとアーキテクチャ示唆

- 日付: 2026-02-22
- 性質: 調査メモ。Cursorスレッドでの分析から抽出。
- derived_from:
  - [ComposioHQ/agent-orchestrator](https://github.com/ComposioHQ/agent-orchestrator) — OSS分析対象
  - 「オーケストレーションのためのドキュメントフォーマット考察」スレッド後半の議論
- related_project: [projects/orchestration-research/](../../projects/orchestration-research/) — リサーチプロジェクト

---

## ツール概要

並列AIコーディングエージェントのオーケストレーター。各エージェントにgit worktree、ブランチ、PRを割り当て、CI失敗やレビューコメントへの自動対応を行う。

- **エージェント非依存**: Claude Code, Codex, Aider
- **ランタイム非依存**: tmux, Docker, k8s
- **トラッカー非依存**: GitHub, Linear

## アーキテクチャ: 8スロットのプラグインシステム

| スロット | デフォルト | 代替 |
|---------|-----------|------|
| Runtime | tmux | docker, k8s, process |
| Agent | claude-code | codex, aider, opencode |
| Workspace | worktree | clone |
| Tracker | github | linear |
| SCM | github | — |
| Notifier | desktop | slack, composio, webhook |
| Terminal | iterm2 | web |
| Lifecycle | core | — |

各プラグインは「1インターフェースを実装して `PluginModule` をエクスポートする」だけ。インターフェースは `packages/core/src/types.ts` に定義。

## 最重要の示唆: CLAUDE.md vs CLAUDE.orchestrator.md の分離

このリポジトリには **2つのインストラクションファイル** があり、完全な関心分離が実現されている。

| | CLAUDE.md | CLAUDE.orchestrator.md |
|---|---|---|
| **対象読者** | 実装エージェント | オーケストレーターエージェント |
| **内容** | コーディング規約、プラグインパターン、セキュリティルール | セッション管理コマンド、スポーン手順、クリーンアップ手順 |
| **性質** | 「こう書け」（手段指示） | 「こう運用しろ」（ランブック型） |
| **重複** | ほぼゼロ | ほぼゼロ |

### 分離の設計判断

- **分割の軸は「関心」であって「重要度」ではない**: セキュリティルール（`execFile` 必須等）は非常に重要だが、オーケストレーター向けファイルには含まれていない。「重要だから全員に渡す」ではなく「この役割に関係あるか」で分割している
- **オーケストレーターの指示はランブック型**: 驚くほど手順書的。「判断しろ」ではなく「このコマンドを実行しろ」。Tips セクションに運用ノウハウが少しあるだけ
- **重複ゼロ**: 実装エージェント向けにはセッション管理の話が一切なく、オーケストレーターにはコーディング規約が一切ない

## Reactions パターン

イベント駆動の宣言的フィードバックループ:

```yaml
reactions:
  ci-failed:
    auto: true
    action: send-to-agent
    retries: 2
  changes-requested:
    auto: true
    action: send-to-agent
    escalateAfter: 30m
  approved-and-green:
    auto: false
    action: notify
```

CI失敗→エージェントが自動修正、レビュー指摘→エージェントが自動対応、承認+CI通過→通知のみ。ルールを「手順書」ではなく「イベント駆動の宣言」として定義。

## 自分の構想との対応

### 使える要素

- **プラグインスロット設計**: 「契約で固定、ツール名で固定しない」原則の具体的実装パターン
- **CLAUDE.md / CLAUDE.orchestrator.md の分離**: agent-rule-decomposition で検討している「役割別ルール分割」の運用実例
- **Reactions の宣言的定義**: ドキュメントルールも「ADR 基準に該当する判断が発生したら → ADR を作成する」のようなイベント駆動形式で書ける可能性
- **worktree 隔離**: エージェント間の干渉防止の具体的な実装

### このツールにないもの（自分の独自レイヤー）

| このツールにないもの | 自分が持っているもの |
|---|---|
| ドキュメントガバナンス | CONVENTIONS.md + ADR 基準 + episode 構造 |
| 知識の蓄積・昇格フロー | 4層モデル + ideas → projects 昇格 |
| フェーズ横断の因果追跡 | レトロスペクティブ、エピソードFB |
| peer review in orchestration | peer-ai-review + SO フロー |
| コンテキスト予算管理 | 問題認識はあり、検証未着手 |
| 認知協調（セマンティック層） | セカンドオピニオン、ルーラーエージェント |

## 分類

- **カテゴリ**: タスクディスパッチ型オーケストレーター
- **強み**: コード生産の並列化、CI/レビューのフィードバック自動化
- **弱み**: 知識管理なし、ドキュメントガバナンスなし、認知協調なし

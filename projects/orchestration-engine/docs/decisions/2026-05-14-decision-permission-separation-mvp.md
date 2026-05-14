---
id: "01KRJMNQY8MQ682FEDVG57DY41"
title: "DI-13: 権限分離 — MVP では実装しない（将来トリガー明文化）"
date: 2026-05-14
type: decision
status: accepted
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-plan-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 Plan"
tags: [orchestration, mvp, step-4-1, decision, permission, security, sandbox]
---

# DI-13: 権限分離 — MVP では実装しない（将来トリガー明文化）

## コンテキスト

orchestration-engine のディスパッチャはサブエージェント（Cursor / Claude Code 等）をペイン上で起動する。サブエージェントは親エージェントと同じ OS ユーザー・同じファイルシステム権限で動作するため、理論上は任意のファイル操作・プロセス操作が可能。

MVP のスコープは **個人開発環境での単独利用** であり、信頼境界は「自分自身が定義したプロンプトを自分のマシンで実行する」範囲に限定される。この前提で権限分離の実装コストとリスク低減効果を評価する必要があった。

## 検討した選択肢

- **案 A — Docker コンテナ分離**: サブエージェントごとに Docker コンテナを起動し、ファイルシステム・ネットワークを分離
- **案 B — OS ユーザー分離**: サブエージェントを専用ユーザーで起動し、ファイル権限で制御
- **案 C — careful-operations-rule フック強化**: 既存の `block-destructive.sh` を拡張し、サブエージェント固有のパターンを追加
- **案 D — MVP では権限分離を実装しない**: 既存のフックをガードレールとして活用し、将来のトリガー条件のみ明文化

## 決定

**案 D を採用**: MVP では権限分離を実装しない。

- 全サブエージェントは親エージェントと同等権限で動作する
- 既存の `canonical/hooks/block-destructive.sh` が §1 パターン（`rm -rf` / `git push --force` / `DROP TABLE` 等）をブロック済み。これが現行の最低限ガードレールとなる
- ディスパッチャがサブエージェントを spawn する際、この hook が有効であることを前提とする
- 権限分離が必要になる条件（変更トリガー）を本 ADR で明文化し、該当時に再評価する

## 根拠

- **コスト対効果**: Docker / OS ユーザー分離は環境構築・デバッグの複雑さが大幅に増加する。個人開発環境では攻撃者モデルが「自分のプロンプト」に限定されるため、リスク低減効果が限定的
- **既存ガードレールの存在**: `block-destructive.sh` が破壊的コマンドを hook レベルでブロック済み。careful-operations-rule の §1〜§3 分類により、ファイルシステム・Git・データベースの主要な破壊パターンはカバーされている
- **MVP スコープの限定**: 個人開発・単独利用の前提では、サブエージェントは「自分が書いたタスク定義を実行する信頼されたプロセス」として扱える
- **段階的強化が可能**: 案 A〜C は後から追加可能な構造。MVP で不要な複雑さを持ち込まず、トリガー条件到達時に導入する方が合理的

## 影響・制約

- サブエージェントは `~/` 配下の全ファイルに読み書き可能。意図しない変更は `block-destructive.sh` のパターンに該当しない限りブロックされない
- MVP ディスパッチャの実装は権限分離を前提としない。将来の sandbox 化は追加レイヤーとして導入する設計余地を残す
- 監査ログ（DI-11）がサブエージェントの操作を記録するため、事後追跡は可能

## 将来の変更トリガー

以下のいずれかに該当した場合、本 ADR を再評価し権限分離の導入を検討する:

- **共同開発の開始**: 他の開発者がサブエージェントのタスク定義を編集・投入する場合
- **チーム運用への移行**: 組織内で複数ユーザーが同一 engine を共有する場合
- **公開リポジトリ運用**: 外部コントリビューターのプロンプトがサブエージェントに渡る可能性がある場合
- **エージェントへの外部入力受付**: Webhook / API 経由で外部からタスクが投入される場合
- **sandbox 化候補技術の成熟**: Docker 統合 / OS ユーザー分離のコストが大幅に下がった場合

sandbox 化の導入時は案 A（Docker）を第一候補とし、`wez pane` への影響（コンテナ内からの WezTerm ソケットアクセス）を事前検証する。

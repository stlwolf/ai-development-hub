# steipete エコシステム調査インデックス

> 調査日: 2026-02-24
> 調査方法: oss-researcher サブエージェントによる並列調査
> 性質: landscape/ 本体（21ツール）の **番外編**。フレームワーク/プラットフォームではなく、個人開発者の実践的ツールキット。

## 背景

steipete（Peter Steinberger）は 300k LOC のプロダクトを 3〜8 エージェント並列でソロ開発している実践者。オーケストレーションフレームワークを使わず、**小さな単機能CLIを組み合わせてtmuxで手動オーケストレーション** するアプローチ。自前ツール構築時の実装パターンとして参考になる。

## ツール一覧

| ツール | Stars | 言語 | 一言 | 調査 |
|---|---|---|---|---|
| [agent-scripts](./agent-scripts.md) | 349 | TypeScript/Bash | 共有エージェント設定・ガードレール。AGENTS.MDポインターパターン、Ralph制御ループ（コード削除済み、概念のみ残存） | ✅ |
| [Oracle](./oracle.md) | 1,500 | TypeScript | マルチモデル並列セカンドオピニオン。API + ブラウザデュアルエンジン、セッション管理、MCP対応 | ✅ |
| [mcporter](./mcporter.md) | 2,100 | TypeScript | MCP統合ブリッジ。7エディタ自動検出、generate-cliでMCP→CLI変換、OAuthフロー自動化 | ✅ |
| [Peekaboo](./peekaboo.md) | 2,300 | Swift | macOSスクリーンキャプチャ + AI画像認識 + GUI自動操作。v3で自然言語エージェントフロー | ✅ |
| [OpenClaw](./openclaw.md) | 224,000+ | TypeScript | パーソナルAIアシスタント基盤。Gateway + Pi agent + 20+チャネル統合。foundation化済み | ✅ |

## 注目すべき発見

### agent-scripts

- **Ralph制御ループ（CONTINUE/SEND/RESTART）はコード削除済み**。Codexの進化により不要になったとのこと。ドキュメントとコミュニティでの "Ralph loop" 概念としてのみ残存
- **runner.ts / bin/git も削除済み**。同様にモデルの能力向上で不要に
- **残っているもの**: AGENTS.MDポインターパターン、docs-list.ts（read_when）、committer — これらは今でも現役
- **示唆**: ガードレールの必要性はモデルの能力に依存する。「今必要なガードレール」は将来不要になり得る

### Oracle

- **デュアルエンジン（API + ブラウザ自動操作）** が独自。APIキー不要でChatGPT Web UIを直接操作
- **Promise.allSettled()** で全モデル並列投入。1つが失敗しても他は継続
- arena-compare.shの上位互換だが、ブラウザモード（2000行超）はUI依存のリスクあり

### mcporter

- **generate-cli**: MCPサーバーからスタンドアロンCLIを自動生成。「MCPよりCLI」思想の具現化
- steipeteの発言: "CLIs beat MCPs. A 2-hour CLI wrapper pays for itself and keeps context small."
- MCPのコンテキストコスト問題（ツール定義の常時ロード）への実用的な解答

### OpenClaw

- **224k+ Stars** はsteipete個人のブランド力に依存する面が大きい
- プラグインのメモリスロットは**排他的シングル**（1つだけアクティブ）。4層モデルとの対比で興味深い設計判断
- Cisco「セキュリティ悪夢」評価あり。シングルユーザー信頼モデルの限界

## concepts/ との対応

| steipeteのパターン | 概念領域 | 現状 |
|---|---|---|
| AGENTS.MDポインター + `<shared>`/`<tools>` | 01 Agent Definition + agent-rule-decomposition | 現役。共有/ローカル分離の実装パターン |
| docs-list + read_when | 05 State & Memory（配布） | 現役。descriptionベース暗黙ルーティングのドキュメント版 |
| committer | 06 Feedback (Guardrail) | 現役。並列エージェントのgit安全性 |
| Ralph制御ループ | 02 Routing + 03 Flow | **削除済み**。モデル能力向上で不要に |
| runner.ts / bin/git | 04 Runtime + 06 Feedback | **削除済み**。同上 |
| Oracle マルチモデル | 06 Feedback + 協調トポロジー (Council) | 現役。セカンドオピニオンのフルスペック実装 |
| mcporter generate-cli | 09 Tooling (MCP → CLI変換) | 現役。MCPコンテキストコスト問題の解答 |

## synthesis/ への取り込みポイント

- **read_when パターン**: context-foundation.md の「コンテキスト配布戦略」に追加すべき中間解
- **ガードレールの時間的変化**: 「今必要なガードレールは将来不要になり得る」→ ガードレール設計は取り外し可能にすべき
- **MCPよりCLI**: implementation/ に追記すべき視点
- **Oracle のデュアルエンジン**: arena-compare の拡張設計の参考

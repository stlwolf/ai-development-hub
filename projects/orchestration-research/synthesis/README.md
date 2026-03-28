# Synthesis — 独自レイヤーとの統合設計ノート

OSSから抽出した概念（[concepts/](../concepts/)）と、自分の独自レイヤー（認知協調・知識永続化等）を統合する設計ノート。

## 方針

- **優先概念のみ深掘り**: コンテキスト基盤を最優先。他は後回し
- **過去検証の知見を統合**: ideas/ や projects/ の実践知見を取り込む
- **重いフレームワーク依存・ベンダーロックインは避ける**

## 設計ノート


| ノート                                              | 独自概念                   | 状態            |
| ------------------------------------------------ | ---------------------- | ------------- |
| [context-foundation.md](./context-foundation.md) | 4層コンテキストモデル → コンテキスト基盤 | 初版完了          |
| [skills-level-patterns.md](./skills-level-patterns.md) | Skills/Rulesレベルの軽量パターン5類型 + 設計洞察 | 初版完了 |
| [harness-engineering-mapping.md](./harness-engineering-mapping.md) | ハーネス概念と自設計の対応マップ。Epic #10・フック基盤への接続 | 初版完了 |
| [architecture-sketch.md](./architecture-sketch.md) | 全体アーキテクチャ素描。Q&A（#18）で確定した設計判断・MVP構成・フェーズ計画 | 初版完了 |
| ~~認知協調~~ | ~~セカンドオピニオン + ルーラーエージェント~~ | architecture-sketch.md に統合。個別文書は不要と判断 |
| ~~正準エージェント定義~~ | ~~ツール非依存の定義フォーマット~~ | MVP実装で経験的に固める。個別文書は不要と判断 |



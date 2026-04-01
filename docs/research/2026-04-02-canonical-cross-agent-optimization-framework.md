---
title: "Canonical Cross-Agent Optimization Framework"
date: 2026-04-02
status: in-progress
tags: [canonical, codex, claude-code, cursor, agent-optimization, workflow-design]
next_step: Epic issue を起点に Phase 1 x Core Canonical の診断テンプレートと分解 issue を作成
---

# Canonical Cross-Agent Optimization Framework

## 動機

`canonical/` は主に Cursor を主体として整備してきたが、直近は Cursor の Usage Cap により、`Claude Code` と `Codex` を主軸に作業を分散する比率が上がっている。

その運用の中で、同じ `canonical/` を展開しても `Cursor` ほど安定して力を出せない場面が複数確認された。ここで重要なのは、これを単純なモデル能力差として片付けないことだった。

ここまでの整理では、体感差のかなりの部分は次の非対称性で説明できる、という認識で一致した。

- 常時注入されるルールの差
- コマンド導線と発見性の差
- MCP / hooks / automation surface の差
- ツールごとの展開レイヤーの厚みの差
- 実行時に参照される文書構造と優先順位の差

要するに、`Cursor` が強いのはモデル単体というより、モデルに能力を発揮させる周辺基盤が厚いからであり、`Codex` と `Claude Code` はそこをまだ詰め切れていない。

## 基本方針

最優先は、可能な限り `canonical/` を共通基盤として維持すること。

ただし、各エージェントが同じ書き方を同じ強度で解釈できるとは限らないため、差分は次の順で扱う。

1. まず正本を改善できるか検討する
2. 正本に入れるべきでない差分は agent-specific adapter に分離する
3. 文面ではなく運用面の差で吸収すべきものは automation でオフセットする

この方針により、共通化を維持しつつ、無理な完全共通化で各ツールの性能を落とさないことを狙う。

## ここまでの合意

### 1. 高性能モデル視点で正本を磨く

`Codex` と `Claude Code` に対して `canonical/` を読ませ、それぞれの視点から「従いにくい箇所」「曖昧な箇所」「脱落しやすい箇所」を診断させる。

狙いは低能力モデル対策ではなく、各高性能モデルが最も従いやすい形を比較することで、正本自体の品質を底上げすることにある。

### 2. いきなり改修しない

先に read-only の診断を行い、その結果を比較してから改修に進む。

この順番にする理由は次の通り。

- いきなり改修提案を取ると diff が大きくなり評価しづらい
- 共通指摘と片側指摘を切り分けたい
- 正本修正と adapter / automation 送りを後段で判断したい

### 3. 共通指摘と固有指摘を分ける

- `Codex` と `Claude Code` の両方が指摘する問題
  - 正本修正候補として扱う
- 片方だけが指摘する問題
  - adapter か deploy-time 変換で吸収できるかを検討する
- ツール機能差に起因する問題
  - automation surface か tool-specific layer に分離する

## Codex 観点での初期仮説

この取り組みは `Codex` と `Claude Code` の両方を対象にするが、初動で特に意識すべき `Codex` 側の論点は明示しておく。

### `Codex` で効きやすい改善点

- 常時効く指示の再設計
- `commands-registry` の拡充
- `Cursor` 側にある workflow の `Codex` 向け移植
- hooks / verification 導線の整理
- task type ごとの prompt entrypoint の標準化

### `Codex` で最初に疑う順番

`Codex` の体感性能差を調べるときは、次の順で疑う。

1. ルール注入の差
2. コマンド発見性の差
3. MCP / hooks / 自動検証の差
4. サブエージェント運用差
5. モデル固有の得意不得意

この順番を先に固定しておく理由は、`Codex` の問題を早い段階でモデル能力差へ還元しすぎないためである。まず運用基盤の差を疑い、その後にモデル固有の得意不得意を評価する。

## 3つのレイヤー

評価対象は次の3レイヤーに分割する。

### 1. Core Canonical

目的:
- ツール非依存で保持すべき意図、原則、判断基準、共通ワークフロー

主な対象:
- `AGENTS.md`
- `canonical/rules/`
- 共通ワークフローの中核を担う `canonical/skills/`
- ツール非依存の `canonical/commands/`

### 2. Agent Adapter

目的:
- 各エージェントが正本を実行可能な形で解釈できるようにする変換・導線・補助

主な対象:
- `canonical/codex/`
- `canonical/cursor/`
- `~/.claude` / `~/.codex` / `~/.cursor` への展開方針
- agent-specific な instruction ordering や command discovery

### 3. Automation Surface

目的:
- 人手ではなく仕組みで能力差を埋める

主な対象:
- `canonical/hooks/`
- `canonical/mcp/`
- `scripts/sync/`
- validation / registry / launch surface

## 2つのフェーズ

### Phase 1: 診断

read-only で canonical を評価し、次を抽出する。

- 曖昧性
- 冗長性
- 深い参照による脱落リスク
- ルール間 / スキル間の矛盾
- 暗黙前提の欠落
- 優先度の見えづらさ
- 読後に次の行動へ移りにくい箇所

### Phase 2: 改修提案

Phase 1 の結果をもとに、ファイル単位で最小差分の改善案を作る。

この段階では、各提案ごとに次を必ず判定する。

- 正本へ入れるべきか
- adapter へ分離すべきか
- automation で吸収すべきか

## 2 x 3 マトリクス

全体の評価フレームは、縦軸 `2フェーズ` と横軸 `3レイヤー` のマトリクスで表現する。

|  | Core Canonical | Agent Adapter | Automation Surface |
|---|---|---|---|
| Phase 1: 診断 | 正本の曖昧さ・冗長さ・矛盾・欠落を診断 | 各 agent が従いにくい書式・導線・優先順位を診断 | hooks / sync / registry / MCP 等の不足や非対称を診断 |
| Phase 2: 改修提案 | 正本へ入れる最小差分の修正案を作る | agent-specific な変換・補助レイヤー案を作る | 自動化・同期・検証導線の追加/整理案を作る |

このマトリクスにより、各問題について「何が悪いか」だけでなく「どこで直すべきか」を明示的に扱える。

## 判定ルール

問題ごとの行き先は次の基準で判断する。

### 正本修正

次を満たす場合は `Core Canonical` 側で修正する。

- 複数エージェントに共通して効く
- 意味論または判断基準そのものの改善である
- 正本に寄せた方が将来の派生先にも効く

迷った場合は、まず `Core Canonical` で解けるかを検討する。

### Adapter 送り

次を満たす場合は `Agent Adapter` で吸収する。

- 特定 agent だけが従いにくい
- 書式、順序、導線、命名、発見性の差で説明できる
- 意味を変えずに tool-specific に調整できる

`Core Canonical` で解決できる場合は、`Agent Adapter` には出さない。

### Automation 送り

次を満たす場合は `Automation Surface` で解く。

- 文書より仕組みの問題である
- hook, sync, validation, registry, MCP で吸収できる
- ルール本文を増やすより自動化した方が再現性が高い

`Core Canonical` または `Agent Adapter` で十分に解決できる場合は、`Automation Surface` には出さない。

### 判定のデフォルト

複数レイヤーにまたがって見える問題は少なくない。その場合は、上流から順に検討する。

1. `Core Canonical`
2. `Agent Adapter`
3. `Automation Surface`

上流で解決できるなら、下流には出さない。これは責務の拡散を防ぎ、後から見たときに「どこで直すべき問題だったか」がぶれないようにするためである。

## 診断品質の基準

Phase 1 の成果物は、単に問題点を列挙するだけでは不十分である。診断レポート自体の品質基準を次のように置く。

- 各指摘に対象ファイルと該当箇所の引用がある
- 各指摘に分類がある
  - 曖昧
  - 冗長
  - 深参照
  - 矛盾
  - 欠落
- 各指摘に、何をするときにどう困るかの具体シナリオがある
- 各指摘に、改善の方向性がある
  - `Core Canonical`
  - `Agent Adapter`
  - `Automation Surface`
  - `不明`
- 抽象的な感想ではなく、行動可能な粒度である

この基準は、後続の診断プロンプト設計でもそのまま使う。

## 実行順序

初動は次の順で進める。

1. `Phase 1 x Core Canonical`
2. `Phase 1 x Agent Adapter`
3. `Phase 2 x Core Canonical`
4. `Phase 2 x Agent Adapter`
5. `Automation Surface`

`Automation Surface` を最後に寄せる理由は、正本と adapter の責務境界を先に固めないと、自動化の設計がぶれやすいためである。

ただし例外として、Phase 1 の診断中に明白な automation の不具合や低コストで修正できる不整合が見つかった場合は、並行で修正してよい。ここでいう例外は、責務の再設計を伴わず、局所的に直せるものに限る。

## 最初の作業バッチ

Phase 1 は `canonical/` 全体を一気に診断せず、次の順でバッチ分割する。

### Batch A: always-on

- `AGENTS.md`
- `canonical/codex/AGENTS.md`
- `canonical/rules/`

Batch A は分量以上に重い可能性がある。個々のファイル品質だけでなく、ファイル間の整合性、重複、優先順位の見え方も明示的に診断対象に含める。

### Batch B: high-leverage workflow

- 頻用 `canonical/skills/`
- `canonical/commands/`

### Batch C: tooling / deployment

- `canonical/codex/`
- `canonical/cursor/`
- `canonical/hooks/`
- `canonical/mcp/`
- `scripts/sync/`

## この文書の役割

この文書は次のための基準文書として使う。

- `Claude Code` と `Codex` に渡す診断・改修依頼の前提共有
- Epic issue から参照する作業方針の正本
- 今後作る分解 issue の分類基準
- 正本修正 / adapter / automation の責務境界の確認
- 改修後に canonical が壊れていないことを確認する検証基準の親文書

## 次アクション

- Epic issue を作成し、この文書を参照する
- Epic から `Phase 1 x Core Canonical` の診断 issue を切る
- `Codex` 用と `Claude Code` 用の read-only 診断プロンプトを別々に整える
- 診断結果を突き合わせ、共通指摘と固有指摘を分類する

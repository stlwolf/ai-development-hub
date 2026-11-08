---
id: "01M6X4DAZZS7QYJ9XHXD5ZJD46"
title: "#593 README などの入口の文書を、いまのディレクトリとスクリプトの中身に合わせる"
date: 2026-11-08
type: plan
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/593"
    reason: "本 plan の issue。確定版の認識合わせ（issuecomment-6719272572）が範囲の正本"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/594"
    reason: "同じ調査から分けた、判断の要る側の issue。本 plan では扱わない"
tags: [docs, readme, sync, harness]
so:
  design: none
  impl: none
  reason: "ドキュメントだけで可逆。設計判断は確定版で owner が決めた2点だけ。この環境には codex も Cursor の agent も無く、so-compare のレーンを起動できない"
---

# #593 README などの入口の文書を、いまのディレクトリとスクリプトの中身に合わせる

## 背景

大文字の名前の MD を、ディレクトリ・`sync-*.sh` が配る中身・`bin/` のコマンドとオプション・issue の open/closed と突き合わせたところ、入口の文書6ファイルが実体からずれていた（master `6df3128` の時点）。`canonical/CATALOG.md` と `canonical/hooks/README.md` はずれが0件だったので触らない。着手の時点で master は `ed64889`（#590）に進んでいて、当て直した結果は確定版の「本文の数と状態」にある。

## この plan の範囲

- やること: issue の「やること」の 21 項目と、確定版で足した1項目（エンジンの README の冒頭に、いま何を作っているものかを数行で書く）。
- 守ること: 実体を見て決まることだけを書く。書き足すオプションとパスは、スクリプトの usage・case 節・`ls` で確かめてから書く。
- 入れないもの: #594 の判断の要るもの、`CLAUDE.md`・`AGENTS.md`、エンジンの進化の方向と今後の対応（owner が別の機会に決める）、#335・#452 の結論を先取りした `docs/` の再構成、文書と実体を機械で照らす検査。

## 設計判断

### DJ-1 ルートの README の `docs/` 節は、いまの実体のとおりに書く

確定版で owner が決めた。#335 の結論が出たら、そちらで書き換える。

### DJ-2 `.claude/rules/episode-flow-discipline.md` への参照

リポジトリにも全履歴にも無い。参照を消し、「リポジトリの外のファイル」とだけ書く（確定版）。

### DJ-3 エンジンの README の冒頭の説明

冒頭の「MVP の実装プロジェクト（Epic #19 Phase 4）」を、いまのエンジンの4つの面（本体のエンジン `bin/oe`・親子の委譲・cockpit の観測・統括の交代と lease）を数行で並べた説明に替える。Phase 4 の経緯は「状態」節に残す。システムの説明の書き直しはしない（確定版）。

## 手順

ファイルごとに1コミットにする（型は `docs:`）。

1. `README.md`（ルート）: `docs/`・`canonical/`・`scripts/` の構成図を実体に合わせる。「ルールの適用」節の Cursor と Codex の配布を `sync-cursor.sh`・`sync-codex.sh` に合わせる。
2. `scripts/README.md`: 構成図に足りないスクリプトを足す。sync の表の配布先を各 sync スクリプトの手順に合わせる。so-compare のオプションと環境変数を usage に合わせる。`harness-check.sh` と `sync/` の apply・check 系の節を足す。
3. `projects/README.md`: `orchestration-engine` と `poc/` を一覧に足す。wezterm-ai-mode の状態とサブコマンドを直す。
4. `projects/orchestration-engine/README.md`: DJ-3 の冒頭の説明。構成図の bin・lib・scripts・schemas・docs を実体に合わせる。「派生 Issue」の表の状態を直す。DJ-2 の参照を直す。
5. `projects/orchestration-engine/bin/README.md`: `oe-lease` の節を足し、冒頭の分類に足す。
6. `projects/wezterm-ai-mode/README.md`: ステータスと toast の記述を、Phase 2（#86）と `wez layout` が済んだいまの状態に合わせる。
7. episode を書き、この plan の status を stable にする。

## 受入

| # | 確かめること | 確かめ方 |
|---|---|---|
| A1 | issue の 21 項目と確定版の1項目がすべて済んでいる | issue のチェックリストと差分を1項目ずつ照らす |
| A2 | 直した文書の中に、無いパスへの参照が無い | 直したファイルのパスを `ls` で1件ずつ確かめる |
| A3 | 書き足したオプション・環境変数が実体と一致する | `so-compare.sh` の usage と case 節、各 sync スクリプトの手順の番号と照らす |
| A4 | エンジンの bin・lib・scripts・schemas の列挙に漏れが無い | `ls` の結果と README の列挙を突き合わせて0件 |
| A5 | Markdown の規約（箇条書きは `-`・コードブロックは言語指定）を守っている | 差分を目で見る |

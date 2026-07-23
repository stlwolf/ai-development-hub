# docs/knowledge/ — knowledge ノートと negative knowledge store

このディレクトリは 2 種類の内容を持つ。

- `docs/knowledge/*.md`(このディレクトリ直下): 既存の自由記述ノート(型なし・frontmatter なし)。人間向けの手順・調査メモ。`items/` の型付き store とは別物で、機械検証の対象外。
- `docs/knowledge/items/`: **negative knowledge の型付き store**(#272)。本 README の以下はこの store を説明する。

## items/ は「文書」ではなく「状態 store」

`items/` は蒸留5段(discussion / kickoff / plan / episode / decision)の6段目ではない。negative knowledge ループの端で使われる**状態の保存場所**であり、段5 が `observations` を追記し段6 が `status` を書き換える、状態が変わり続ける永続化場所である。committed ファイル群にするのは、状態変更のたびに PR ゲート(保存 HG)を通し、チームで共有し、git で戻せるようにするため。

位置づけの正本は `canonical/orchestration-spec/document-format.md` の knowledge サブ節、設計の正本は `projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`。

## 1 item = 1 ファイル(ファイル名 = ULID)

- `items/<ULID>.md`。ファイル名は ULID にする(蒸留5段の `YYYY-MM-DD-{type}-{topic}.md` 規約とは意図的に異なる)。並行収穫(複数 worktree / 並列子)でも衝突しないため。
- frontmatter(型付きエンベロープ)と本文 prose(教訓・自己評価文)を分離する。エンベロープは文書体系に依存しない語彙のみ(出典は `source.ref` という汎用参照)。

## スキーマ(形式例)

以下は形式の例示。実データではない(本番 store に active な形式例 item は置かない)。

```yaml
---
id: "01J0KNOWLEDGEITEMEXAMPLE00"   # ULID(26字・Crockford Base32)。ファイル名 = <id>.md
type: knowledge                    # 固定
status: active                     # active | disabled | superseded | retired（段6 制御の語彙）
date: 2026-07-23                   # 収穫日（不変。段5/6 の状態更新でも変えない）
trigger: "この教訓が効く状況の仮説（必須）"
prediction: "効くはずの状況と期待効果（段5 の照合先）"
source:
  ref: "https://github.com/org/repo/issues/123"   # 汎用参照（committed path か URL）。.oe//tmp/ 揮発層・絶対パスは不可
landing: nl                        # nl | guard-candidate（§6.9 の記録のみ）
observations: []                   # v0 は空配列で予約（中身の設計は #274）
exclusions:                        # 任意。効かない状況（文字列の配列）
  - "自明・一度きりの知見には使わない"
---

教訓の本文（prose）。何が非自明で、なぜ再発しうるか、次にどう行動を変えるか。
```

必須は `id / type / status / date / trigger / prediction / source(.ref) / landing / observations` の9項 + 本文 prose。`exclusions` のみ任意。

## 検証

```bash
# 単一 item
projects/orchestration-engine/scripts/validate-knowledge.sh docs/knowledge/items/<ULID>.md

# store 全件（directory mode・直下 *.md を非再帰で検証）
projects/orchestration-engine/scripts/validate-knowledge.sh docs/knowledge/items
```

exit 0 = valid / 1 = schema 違反(commit 前に直す・advisory で hook はブロックしない) / 2 = 環境エラー(file not found・jq/yq 未導入・usage)。

## 収穫と保存 HG

knowledge item は episode の closure 時に `episode-retrospective` スキルの収穫 Step で切り出し、`validate-knowledge.sh` を通してから episode と同じブランチにコミットする。**保存前の人間ゲート = owner のマージ HG**(item を含むブランチを owner がマージ時に見る)。episode 中の誤情報・prompt injection・secret / 個人情報・外部由来内容を knowledge に昇格させない(信頼境界は PR レビュー/マージ HG)。

## 採用先(他リポジトリ)向けの置き場規則

そのリポジトリの**蒸留ドキュメント木のルート直下に `knowledge/`** を置く(`decisions/` / `episodes/` / `plans/` の兄弟)。エンジン独自のトップレベル名前空間は切らず、committed で存在する蒸留ドキュメント木を錨にする。型付き item は `knowledge/items/` に隔離し、検証は `items/` のみを対象にする。

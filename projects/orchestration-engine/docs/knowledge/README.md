# knowledge store — negative knowledge の型付き状態 store（#272）

このディレクトリは negative knowledge ループ（設計正本は `../discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`）の型付き **状態 store**。ai-hub ではこの engine 蒸留木がストアの実体で、型付き item は `knowledge/`（`decisions/` `episodes/` `plans/` `discussions/` の兄弟）の下の `items/` に隔離し、README はこの `knowledge/` に置く。

## 「文書」ではなく「状態 store」

蒸留5段（discussion / kickoff / plan / episode / decision）の6段目ではない。ループの端で使われる状態の保存場所で、段5 が `observations` を追記し段6 が `status` を書き換える、状態が変わり続ける永続化場所。committed にするのは、状態変更のたびに保存 HG（PR レビュー/owner マージ）を通し、チーム共有し、git で戻せるため。位置づけと採用先向けの置き場規則の正本は `canonical/orchestration-spec/document-format.md` の §2.5 / §3.4。

## 置き場規則（採用先一般）

- **関係で解く（正本の規則）**: 収穫した item は、その収穫元 episode が属する蒸留木の `knowledge/items/` に置く（＝ item の `source.ref` が指す episode / PR と同じ木）。蒸留木が複数あるリポジトリでも、item ごとに置き場が source.ref との関係で一意に決まる（repo 固有パスの列挙は不要）。段3（突合）の列挙は各木の store を横断して見る。
- 蒸留ドキュメント木のルート直下に `knowledge/` を置く（`decisions/` / `episodes/` / `plans/` の兄弟）。**型付き item（ULID 名）は `knowledge/items/` に隔離**。自由記述の knowledge ノートがあれば `knowledge/` 直下に別途置き、`items/` には混ぜない。README は `knowledge/README.md`。
- **この repo（ai-hub）での木の解決（dogfood）**: 蒸留木が複数ある（トップレベル `docs/` と engine `projects/orchestration-engine/docs/`）。orchestration-engine 由来の収穫の実体はこの engine 木 `projects/orchestration-engine/docs/knowledge/items/`。トップレベル `docs/knowledge/` の自由記述ノートは別物で不干渉。

## 1 item = 1 ファイル（ファイル名 = ULID）

- `items/<ULID>.md`。ファイル名は ULID にする（蒸留5段の `YYYY-MM-DD-{type}-{topic}.md` 規約とは意図的に異なる）。並行収穫（複数 worktree / 並列子）でも衝突しないため。
- frontmatter（型付きエンベロープ）と本文 prose（教訓）を分離する。エンベロープは文書体系に依存しない語彙のみ（出典は `source.ref` という汎用参照）。

## スキーマ（形式例）

以下は形式の例示。実データではない（本番 store に active な形式例 item は置かない）。

```yaml
---
id: "01KY6X5CKE0SVYZRMXHH74XDS4"   # ULID(26字・Crockford Base32・I/L/O/U 無し)。ファイル名 = <id>.md
type: knowledge                    # 固定
status: active                     # active | disabled | superseded | retired（段6 制御の語彙）
date: 2026-07-23                   # 収穫日（不変。段5/6 の状態更新でも変えない）
trigger: "この教訓が効く状況の仮説（必須）"
prediction: "効くはずの状況と期待効果（段5 の照合先）"
source:
  ref: "https://github.com/org/repo/issues/123"   # 汎用参照（committed path か URL）。`.oe/` と `tmp/` の揮発層・絶対パス・`..` を含むパスは不可
landing: nl                        # nl | guard-candidate（§6.9 の記録のみ）
observations: []                   # v0 は空配列で予約（中身の設計は #274）
exclusions:                        # 任意。効かない状況（文字列の配列）
  - "自明・一度きりの知見には使わない"
---

教訓の本文（prose）。何が非自明で、なぜ再発しうるか、次にどう行動を変えるか。
```

必須は `id / type / status / date / trigger / prediction / source(.ref) / landing / observations` の9項 + 本文 prose。`exclusions` のみ任意。

## 検証

`validate-knowledge` は `~/bin` へ配布されるコマンド（正本は hub の `projects/orchestration-engine/scripts/validate-knowledge.sh`・`scripts/sync/sync-bin.sh` が配布）。

```bash
# 単一 item
validate-knowledge projects/orchestration-engine/docs/knowledge/items/<ULID>.md

# store 全件（directory mode・items/ 内の全 *.md を検証）。ULID 名でない誤名 item も WARN + exit 1（黙って落とさない）
validate-knowledge projects/orchestration-engine/docs/knowledge/items
```

exit 0 = valid / 1 = schema 違反（commit 前に直す・advisory で hook はブロックしない） / 2 = 環境エラー（file not found・jq/yq 未導入・usage）。

## 収穫と保存 HG

knowledge item は episode の closure 時に `episode-retrospective` スキルの収穫 Step で切り出し、`validate-knowledge` を通してから episode と同じブランチにコミットする。**保存前の人間ゲート = owner のマージ HG**（item を含むブランチを owner がマージ時に見る）。episode 中の誤情報・prompt injection・secret / 個人情報・外部由来内容を knowledge に昇格させない（信頼境界は PR レビュー/マージ HG）。

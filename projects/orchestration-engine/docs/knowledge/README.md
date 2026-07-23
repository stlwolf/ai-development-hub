# knowledge store — negative knowledge の型付き状態 store（#272）

このディレクトリは negative knowledge ループ（設計正本は `../discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`）の型付き **状態 store**。ai-hub ではこの engine 蒸留木がストアの実体で、`decisions/` `episodes/` `plans/` `discussions/` の兄弟に置く。

## 「文書」ではなく「状態 store」

蒸留5段（discussion / kickoff / plan / episode / decision）の6段目ではない。ループの端で使われる状態の保存場所で、段5 が `observations` を追記し段6 が `status` を書き換える、状態が変わり続ける永続化場所。committed にするのは、状態変更のたびに保存 HG（PR レビュー/owner マージ）を通し、チーム共有し、git で戻せるため。位置づけと採用先向けの置き場規則の正本は `canonical/orchestration-spec/document-format.md` の §2.5 / §3.4。

## 置き場規則（採用先一般）

- 蒸留ドキュメント木のルート直下に `knowledge/` を置き、**型付き item（ULID 名）をこのディレクトリに直接置く**（`items/` サブディレクトリは作らない）。README もこのディレクトリに同居する。
- **蒸留木が複数あるリポジトリでは、store も木ごとに置く**（各木の `knowledge/`）。ai-hub の実体はこの engine 木（`projects/orchestration-engine/docs/knowledge/`）。段3（突合）の列挙は各木の store を横断して見る。
- エンジン独自のトップレベル名前空間は切らず、committed で存在する蒸留木を錨にする。
- 自由記述の knowledge ノートが別に存在する木（ai-hub のトップレベル `docs/knowledge/` など）とは無関係。store はそれらと混在しない木（本 engine 木）を実体に選ぶ。

## 1 item = 1 ファイル（ファイル名 = ULID）

- `<ULID>.md`。ファイル名は ULID にする（蒸留5段の `YYYY-MM-DD-{type}-{topic}.md` 規約とは意図的に異なる）。並行収穫（複数 worktree / 並列子）でも衝突しないため。
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
validate-knowledge projects/orchestration-engine/docs/knowledge/<ULID>.md

# store 全件（directory mode）。ULID 名の item のみ検証し、README 等の非 item ファイルは skip する
validate-knowledge projects/orchestration-engine/docs/knowledge
```

exit 0 = valid / 1 = schema 違反（commit 前に直す・advisory で hook はブロックしない） / 2 = 環境エラー（file not found・jq/yq 未導入・usage）。

## 収穫と保存 HG

knowledge item は episode の closure 時に `episode-retrospective` スキルの収穫 Step で切り出し、`validate-knowledge` を通してから episode と同じブランチにコミットする。**保存前の人間ゲート = owner のマージ HG**（item を含むブランチを owner がマージ時に見る）。episode 中の誤情報・prompt injection・secret / 個人情報・外部由来内容を knowledge に昇格させない（信頼境界は PR レビュー/マージ HG）。

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
observations: []                   # 収穫時は空配列。段5 が観測レコードを append する（下の形式例）
exclusions:                        # 任意。効かない状況（文字列の配列）
  - "自明・一度きりの知見には使わない"
---

教訓の本文（prose）。何が非自明で、なぜ再発しうるか、次にどう行動を変えるか。
```

必須は `id / type / status / date / trigger / prediction / source(.ref) / landing / observations` の9項 + 本文 prose。`exclusions` のみ任意。

観測レコードが付いた `observations` の形式例（これも例示であって実データではない）:

```yaml
observations:                        # append-only。末尾に足すだけで過去のレコードは書き換えない
  - date: 2026-07-25                 # 観測日（暦として妥当な YYYY-MM-DD）
    ref: "#274"                      # durable な作業単位参照。既定は issue 番号（closure は PR 作成前）
    state: followed                  # enum 7値（下の「観測記録」節）
    note: "argv でなく stdin で渡した"   # 任意・1行
  - date: 2026-07-25
    ref: "#280"
    state: no_opportunity            # 適用機会が無かったことも正直に記録する（省略しない）
```

要素は `{date, ref, state, note?}` の4フィールドのみで、**未知のキーは検証で弾かれる**。スキーマ・state の優先順位・遷移規則の正本は `canonical/orchestration-spec/document-format.md` の knowledge 節（「observations 要素スキーマ」「status 遷移規則」）。

## 検証

`validate-knowledge` は `~/bin` へ配布されるコマンド（正本は hub の `projects/orchestration-engine/scripts/validate-knowledge.sh`・`scripts/sync/sync-bin.sh` が配布）。

```bash
# 単一 item
validate-knowledge projects/orchestration-engine/docs/knowledge/items/<ULID>.md

# store 全件（directory mode・items/ 内の全 *.md を検証）。ULID 名でない誤名 item も WARN + exit 1（黙って落とさない）
validate-knowledge projects/orchestration-engine/docs/knowledge/items
```

exit 0 = valid / 1 = schema 違反（commit 前に直す・advisory で hook はブロックしない） / 2 = 環境エラー（file not found・jq/yq 未導入・usage）。

## 列挙（段3 突合）

`knowledge-list` は store の item を蒸留木横断で列挙する read-only コマンド（`~/bin` へ配布・正本は hub の `projects/orchestration-engine/scripts/knowledge-list.sh`・`scripts/sync/sync-bin.sh` が配布）。統括が brief を組む時に候補を一望するためのもの（段3 突合）。検証ではない（それは `validate-knowledge`）。

```bash
# 既定: git HEAD tree（committed の item）を repo root 起点で蒸留木横断列挙
knowledge-list

# 段3 の突合は完全性のため常に --strict（崩れ item があれば exit 1）
knowledge-list --strict

# JSON（schema_version / source / head / listed / skipped / control_candidates / integrity_issues /
#  items / malformed）。パイプ・将来の matcher 用
# （head = git-head モードで固定した HEAD の SHA。他モードでは null）
knowledge-list --json

# disk（未 commit 含む）を filesystem find で列挙（.oe/ tmp/ node_modules は prune）
knowledge-list --include-uncommitted

# 明示指定（単一木・テスト・git 外）。items/ dir か item file を渡す
knowledge-list docs/knowledge/items
```

- **発見**: 既定は `git ls-tree HEAD` で **committed の item のみ**を列挙する（index/working-tree でなく commit tree ＝ staged-but-uncommitted は含めない・「committed 状態 store」の意味に一致）。対象は `knowledge/items/` 直下の ULID `.md` のみ（非再帰・厳密 regex）で、`validate-knowledge` の directory mode と**同じ発見規則**（items/ 直下 ULID `.md`）を使う。したがって **committed 状態**の同じ store に対しては両者の対象集合が一致する（＝列挙した集合を検証できる）。段3 の突合は committed 状態に対して行う前提で、未 commit の追加/削除がある作業中は lister（HEAD snapshot）と validator（作業ツリー上の指定 path）が別 snapshot を見るため一時的にズレるのは設計どおり。
- **malformed / 非 ULID**: 崩れ item・非 ULID 名の `.md`・閉じ `---` 欠落は **stdout に flagged row（`MALFORMED`・path・ファイル名から復元した id）で surface** し `skipped` に数える（黙って落とさない）。末尾に `listed: N / skipped: M / source: <mode>`（git-head モードでは `source: git-head @ <HEAD SHA>`）を出す。
- **既知の限界（v0）**: `excerpt` は本文先頭行の preview で意味要約ではない（正本は item 本体）。非 UTF-8 ロケール（`LC_ALL=C` 等）では切詰め時に末尾 1 文字が jq で U+FFFD に置換されうる（crash や exit 契約違反は起きない）。配備ロケールは UTF-8。
- **この repo（ai-hub）での木の解決（dogfood）**: 蒸留木が複数ある（トップレベル `docs/` と engine `projects/orchestration-engine/docs/`）。`knowledge-list` は repo root 起点で両木の `knowledge/items/` を自動で横断するので、木ごとのパス指定は不要。
- **exit code（`validate-knowledge` との整合）**:

  | exit | `knowledge-list` | `validate-knowledge` |
  |------|------------------|----------------------|
  | 0 | 列挙成功（skipped があっても既定は 0） | valid |
  | 1 | `--strict` かつ skipped > 0（完全性信号） | schema 違反 |
  | 2 | 環境エラー（git 非在 / HEAD 不成立 / jq・yq 未導入 / usage） | 環境エラー |

- **列挙 → 採否 → 注入** の手順は `doc-flow-guardrail` の「negative knowledge 注入」節（brief 固定節の slot）を参照する。

## 収穫と保存 HG

knowledge item は episode の closure 時に `episode-retrospective` スキルの収穫 Step で切り出し、`validate-knowledge` を通してから episode と同じブランチにコミットする。**保存前の人間ゲート = owner のマージ HG**（item を含むブランチを owner がマージ時に見る）。episode 中の誤情報・prompt injection・secret / 個人情報・外部由来内容を knowledge に昇格させない（信頼境界は PR レビュー/マージ HG）。

## 観測記録（段5・#274）

注入された knowledge の帰結を `observations` に書き戻す段。**書き手は注入を受けた子**で、自分の closure 時に work と同じブランチへコミットする（手順は `episode-retrospective` の観測書き戻し Step、規則は spec の knowledge 節）。この store での具体的な流れ:

```bash
# 1. 書き戻す（brief の slot に載っていた全 item に 1 レコードずつ・機会が無ければ no_opportunity）
#    → item の observations 末尾に {date, ref, state, note?} を足す（過去レコードは書き換えない）

# 2. 検証を通す（pass するまで直す）
validate-knowledge projects/orchestration-engine/docs/knowledge/items/<ULID>.md

# 3. 書き戻した内容を列挙で確認する。既定（git-head）は commit された内容しか見ないので、
#    commit 前に確認したいときは --include-uncommitted で作業ツリーを見る
knowledge-list --include-uncommitted
```

- **列挙のタイミングに注意**: `knowledge-list` の既定は HEAD tree snapshot（committed）なので、**観測を commit する前に既定モードで見ると観測ゼロのまま**に見える。commit 前の確認は `--include-uncommitted`（作業ツリーを見る）を使う。`validate-knowledge` は渡した path をそのまま読むので、未 commit でも検証できる。
- 統括が段3 の突合で見るのは committed 状態（既定モード）である。書き戻し済みかどうかを判断するときは、どちらのモードで見ているかを意識する。

## 制御（段6・#274）の運用

機械は候補を提示するところまでで、status は人間が別 PR で動かす。

```bash
# 集計と制御候補を見る（observations が 1 件以上の item だけ observations 行が出る）
knowledge-list
#   observations: 4 (no_opportunity:1 followed:2 harmful:1)   control-candidate: harmful
#   → status: active + harmful/contradicted の item に control-candidate が付く
#   → 台帳が壊れている item には integrity 注記が付き、footer に integrity-issues: N が出る

# 機械可読（パイプ・将来の matcher 用）。追加フィールドは additive
knowledge-list --json | jq '.control_candidates, .integrity_issues,
  [.items[] | select(.control_candidate) | {id, observations_by_state, control_candidate_reasons}]'

# 二段チェック（列挙は「列挙できたか」しか見ない。台帳のスキーマ完全性は検証コマンドで見る）
knowledge-list --strict && validate-knowledge projects/orchestration-engine/docs/knowledge/items
```

- **候補フラグの読み方**: 「adverse な観測が過去に一度でもあった印」であって未処理キューではない。誤観測を訂正する語彙が enum に無いため、**一度立った候補は消えない**（v0 の既知の制約）。候補の総数を運用指標にしない。
- **`--strict` は広げていない**: exit 1 になるのは `skipped>0`（item を列挙できなかった）のときだけ。壊れた観測台帳は exit code に出ないので、**列挙のあとに検証を回す**（上の二段チェック）。
- **`--json` の互換方針**: 追加は additive で、既存キーは変えない。`schema_version` は breaking change のときだけ上げる（#274 の観測フィールド追加では上げていない）。
- **status を動かす PR**: `status` を編集し、`observations` と `date` は触らない。supersede のときは後継 item の id を**本文 prose に1行** `superseded by <後継 ULID>` として書く（frontmatter は変えない）。後継チェーンを機械で辿る必要が出たら typed フィールド `superseded_by` へ昇格する。

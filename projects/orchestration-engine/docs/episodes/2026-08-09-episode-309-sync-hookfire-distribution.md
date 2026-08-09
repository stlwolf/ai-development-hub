---
id: "01KZK26GQWMY26SBVHF5Q0Y786"
title: "#309 残件 — oe-hookfire を配布に載せ、配布の実態に文書を追随させる"
date: 2026-08-09
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/309"
    reason: "本単位の起点。台帳を書く側は入ったが、読み手が届く経路が閉じていなかった"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-08-08-plan-309-hook-firing-record.md"
    reason: "配布の保留を gate 3 で確定させた記録。本単位はその保留を前倒しで解く"
  - type: sibling
    ref: "projects/orchestration-engine/docs/episodes/2026-08-08-episode-309-hook-firing-record.md"
    reason: "同じ issue の先行単位。oe-hookfire 本体と3本のフックの記録契約はそちら"
tags: [sync, distribution, docs, hooks, engine]
promotion:
  - subject: "gate 3 で置いた配布の保留を、#301 を待たずに前倒しで解く"
    verdict: required
    ref: "本文: 前提が違っていた — 欠落ではなく保留だった"
  - subject: "配布の追加を『欠落の補修』ではなく gate 3 の保留の巻き戻しとして記録する"
    verdict: not-required
    ref: "本文: 前提が違っていた — 欠落ではなく保留だった"
  - subject: "未配布のまま残る他の oe-* verb を本単位では足さない"
    verdict: not-required
    ref: "本文: 触らなかったもの"
  - subject: "文書の配布対象の列挙を、一般化ではなく列挙 + 正本への pointer で書き直す"
    verdict: required
    ref: "本文: 配布の実態に文書を追随させた"
  - subject: "作業単位の受け入れ基準が closure の成果物の作成を禁じうる（brief の scope 制約と heavy tier の衝突）"
    verdict: required
    ref: "本文: 統括の制約が closure の置き場を潰していた"
---

# #309 残件 — oe-hookfire を配布に載せ、配布の実態に文書を追随させる

`reconstructed`。本文は作業の終わりにまとめて書いた。リアルタイムの追記ログではないので、追記型の episode と同じ証拠価値は無い。時系列は会話・コミット・SO 出力から再構成したものである。

## なぜこの作業が始まったか

#309 で `oe-hookfire`（止める側のフック3本が直近の窓で発火したかを読む read-only 検査）が engine の `bin/` に入ったが、`~/bin` へ配られていなかったため PATH から呼べなかった。この台帳は定期実行の配線（#301）が未着手で、当面は人が打つまで動かない。読み手が名前で打てないと値打ちが閉じない、というのが起点である。

## Step 1 — 配布対象への1エントリ追加

`scripts/sync/sync-bin.sh` の `CMD_NAMES` と `CMD_SOURCES` に `oe-hookfire` を1件ずつ、`oe-tree` の直後へ足した。同じ `projects/orchestration-engine/bin/` 配下という括りを保つ位置である。

検証は3つ。`shellcheck` は指摘ゼロ。2つの配列は追加後ともに8要素で、index の対応が崩れておらず全 source パスが実在することを、配列定義だけを取り出して評価する read-only の手順で確かめた。変更ファイルは1本だけだった。

worktree から `sync` は実行していない。実行すると `~/` 側のリンクが worktree を指し、worktree を削除した時点で壊れるためである。配備はマージ後に owner がメインの作業ツリーで行う。

## 前提が違っていた — 欠落ではなく保留だった

gate 4 の実装SO（弱SO・codex + claude の2レーン）で、claude レーンが前提の食い違いを指摘した。#309 の plan は「置き場（gate 3 で確定）」節で次のように確定させている。

> `~/bin` への配布が要るかは #301（読み手の配線）と一緒に決まるので、本単位では engine bin に置くまでとする

つまり先行 PR が `sync-bin.sh` に足さなかったのは書き忘れではなく、gate 3 で確定した保留の結果だった。委譲の brief は「配布対象の欠落」と書いており、私はそれをそのまま前提にしてコミットメッセージを「配布対象の欠落を埋める」と書いていた。

**brief 自身は「他の未配布 verb は意図的に配っていない可能性がある」と警告していた。** その警告は、着手対象である `oe-hookfire` 自身にこそ名指しで当たっていた。私は警告を「他の対象」にだけ当てて、目の前の対象には当てなかった。

指摘を受けて、コミットメッセージと PR 本文を「gate 3 で置いた保留を #301 を待たずに前倒しで解く」という書き方に直した。配布に踏み切る判断そのものは owner の指示なので変更は残す。直したのは根拠の書き方である。保留の巻き戻しを忘れ物の回収として記録すると、後から plan を読んだ人が決定の覆った経緯を追えなくなる。

SO は2レーンとも、配列の index 対応・既存パターンとの整合・実行時の副作用のいずれにも欠陥なしで一致した。副産物として1つ分かったことがある。`oe-tree` は symlink 配布のために `BASH_SOURCE` を `readlink` で解決する事前修正が要ったが、`oe-hookfire` は lib を `source` せず自分の位置も解決しないため、同じ手当ては要らない。

## 統括の制約が closure の置き場を潰していた

最初の brief は受け入れ基準に「`sync-bin.sh` 以外のファイルを変更していない」を置いていた。小単位の scope creep を防ぐ意図の制約である。

ところが gate 4 で `so-compare` を明示起動した時点で、`episode-retrospective` の heavy トリガが立つ。heavy は episode と closure を要求する。**episode は新規ファイルなので、1ファイル制約と正面から衝突する。** 私は PR 本文に closure を置くことで回避し、その衝突自体を surface した。

owner の判断は制約の側を外すことだった。統括も、あの制約は原理的なものではなく自分が置いたもので、結果として closure の置き場を潰していたと非を認めている。本 episode はその解除後に書いている。

一般形としては残る。**gate 4 の SO が必須である以上、heavy トリガは engine の実装委譲でほぼ毎回立つ。** brief が置く scope 制約が closure の成果物（episode / knowledge item）まで巻き込むと、同じ衝突が繰り返し起きる。

## 配布の実態に文書を追随させた

owner がスコープを広げたので、surface していた文書のずれを直した。**事実は統括の測定を写さず、自分の環境で測り直した**（`ls -ld ~/bin` / `ls -l ~/bin` / `command -v`）。

測定結果は次のとおり。`~/bin` は `dotfiles/bin` へのシンボリックリンクだった。PATH 上にあるのは `oe-tree` / `knowledge-list` / `validate-knowledge` / `so-compare` / `arena-compare` / `wez` / `wt-pane-issue` の7本で、`oe` / `oe-send` / `oe-selfcheck` は無い。`oe-hookfire` は本 PR の配布追加が配備されるまで無い。

直したのは4か所である。

- `canonical/skills/orchestration-toolkit/SKILL.md` の不変条件「`oe` / `oe-*` は PATH 未登録」。`oe-tree` の配布時点で既に偽だった。ここはエージェントが起動方法を決めるために読む節なので最優先で、原則と例外を分けたうえで、一覧が古くなる前提で `command -v` の確認を促す形にした
- engine の `bin/README.md` に `oe-hookfire` の節を足し、索引の観測 verb 列にも載せた。内容は本体のヘッダと実行結果から書いた
- engine の `README.md` の構成ツリーに `oe-hookfire` を足した
- ルート `README.md` と `scripts/README.md` は bin 配布対象を2件と書いていたので8件へ直した
- `CLAUDE.md` も同じ列挙を3件（`so-compare` / `arena-compare` / `wez`）で持っていた。これは closure の外部チェックで指摘されて後から足した。**全セッションに自動で読み込まれる指示ファイルなので、このクラスの陳腐化としては影響が一番大きい**

最後の3つでは、列挙をそのまま書き足すのではなく、**リンク名と実体の対応の正本は `sync-bin.sh` の配列だ**と明示した。列挙だけを更新しても、次に配布対象が増えた時点でまた古くなるためである。SO（codex）は「網羅列挙をやめて『各種 CLI』などに一般化するのが保守しやすい」と提案したが、読み手が今すぐ知りたいのは具体名なので、列挙は残して正本への pointer を併記する形にした。**一般化案を棄却した判断なので、`promotion` では `required` として扱っている。**

`canonical/hooks/README.md` の「読み方」節は起動例を repo 相対パス（`projects/orchestration-engine/bin/oe-hookfire --days 7`）で書いており、SO（codex）はこれを名前呼び出しへ変える余地を挙げた。**変えなかった。** 配備は owner がマージ後に sync を走らせた時点で効くので、名前で打てるようになるのはその後である。repo 相対パスは配備の前後どちらでも動くのに対し、名前は配備前には動かない。文書の正しさが配備状態に依存する形にしたくなかった。

配布 canonical に入る文書（skill と各 README）は、hub 固有の絶対パスを operational に焼かず、規則とコマンド名で書いた。

## 触らなかったもの

行き先を1件ずつ付ける。**行き先の無い箇条書きは残さない。**

- **`sync.sh --check bin` が配布対象8件のうち2件しか検査しない件。** `oe-hookfire` が張られていなくても `up to date` と出る。これは文書の追随ではなく「検査が何を見るべきか」という設計の変更なので、ついでに直すとその判断が検証されないまま入る。**行き先: 統括が別に起票する**（追加指示で明言）
- **`sync-bin.sh:39` の `head -n -1` が BSD で動かない件。** 実行して確認した（`--help` が `head: illegal line count -- -1` で exit 1）。本 PR の目的と無関係な既存不具合である。**行き先: 上の issue に隣接する欠陥として統括が記録する**（追加指示で明言）。本 PR では触らない、が「誰も追わない」という意味ではない
- **他の未配布 `oe-*` verb。** 意図的に配っていない可能性があり、それを確かめずに足すのは今回学んだ失敗の再演になる。**行き先: 本単位では追わない。** 配布の要否は各 verb の一次記録を引いたうえで、必要になった時点で判断する
- **engine の `README.md` 構成ツリーに他にも欠けている verb が7本ある**（`oe-ident` / `oe-jump` / `oe-register` / `oe-selfcheck` / `oe-undelivered` / `oe-view` / `oe-vitals`。ツリー記載15本に対し `bin/` の実体は22本）。**行き先: 報告で統括へ surface する。** 起票の要否は統括の判断で、本単位では追わない
- **`oe-hookfire` の exit code が判定と呼び出しの誤りで衝突している。** usage エラーが exit 1、`--days` の値が不正なとき exit 2 で、それぞれ「broken あり」「indeterminate あり」と同じ番号である。exit code だけを見る呼び出し側は両者を区別できない。#301 で定期実行を配線するときに効く。**行き先: 報告で統括へ surface する**
- **配布によって参照の解決可能性が変わった。** `oe-hookfire` の出力とヘッダは `canonical/hooks/README.md` を相対パスで指しているが、`~/bin` 経由で任意の cwd から呼べるようになると hub の外では解決できない。既存の `oe-vitals` 等も同じ形なので本単位で直す話ではない。**行き先: 報告で統括へ surface する**
- **列挙を導出可能にする案**（`sync-bin.sh --list` で `CMD_NAMES` を印字させ、文書側は「`--list` で確認できます」と書く）。列挙の陳腐化と一般化の情報損失を両方避けられる。SO が出した第3案で、`sync.sh --check` の別起票と同じ場所に置ける。**行き先: 報告で統括へ surface する**
- **`orchestration-toolkit` SKILL.md の「全 11 verb」という記述。** 実際の `bin/` には `oe` + `oe-*` が22本ある。配布の実態とは別のクラスの陳腐化である。**行き先: 報告で統括へ surface する**
- **`canonical/hooks/README.md` の起動例を名前呼び出しへ変えないこと。** 理由は `本文: 配布の実態に文書を追随させた` に書いた。**行き先: 追わない（判断済み）**
- **`oe-hookfire` の実測で出た `tool-attribution` の `broken`。** 下の節に書いた観測で、#311 の仕組みが実環境で意図どおり動いていない可能性を示す。文書の陳腐化とは種類が違う。**行き先: 報告で統括へ surface する。** 本単位の scope 外なので起票はしない

## 追加分の gate 4

文書追随と closure 成果物にも実装SO を当てた（弱SO・追加分に限定）。1本目の `sync-bin.sh` の変更は再度回していない。

**1回目は partial だった。** codex レーンが初回 240秒・リトライ 360秒とも `timeout_empty` で返らず、claude レーンだけが返った。弱SO の終了条件では実返却が1レーン以上あれば disclose して進めてよいが、2レーンを求められている単位なので、別族の cursor レーンを `SO_TIMEOUT=600` で追加して2レーン目を取り直した。so-compare のスキルが「レビュー級のプロンプトでは既定の 240秒が足りていない」と書いているとおりの事象で、既定のままでは codex は初回を捨ててリトライに入る経路が常態になっている。

| レーン | 所要 | 結果 | 解決後モデル |
|---|---|---|---|
| claude | 448秒 | success | `unavailable:schema-unexpected` |
| codex | 240秒 + 360秒 | `timeout_empty` ×2 | `gpt-5.6-sol`（config 由来・観測値ではない） |
| cursor（取り直し） | 119秒 | success | `unavailable:cli-not-exposed`（`auto` の解決先は記録されない） |

claude レーンが挙げ、対応したものは次のとおり。

- `CLAUDE.md` の配布列挙が3件のままだった → 直した（closure の外部チェックと独立に、同じ箇所を指摘している）
- `orchestration-toolkit` の書き換えが「`oe-hookfire` は PATH 上にある」と読める書き方だった。**配布対象に入れたことと、その環境に配備済みであることは別で、配備前の現時点では偽である** → 両者を分けて書き直した
- knowledge item の `trigger` が「brief に警告があるとき」に狭まっていた。予測している失敗は警告の有無と無関係に成立するので、**本来当たるべき場面で発火しない** → trigger を curated な集合の欠落一般へ広げ、警告は増幅要因として本文へ移した
- 「触らなかったもの」の欠落 verb を6本と書いていた → 実際は7本（`oe-view` が抜けていた）。数え直して直した

cursor レーンは同じ SKILL の欠陥を独立に検出し（コミット済みの状態では PATH 断定が偽であること）、加えて `CLAUDE.md` の記述だけ正本 pointer が無く再び古くなりやすいと指摘した。これを受けて `CLAUDE.md` にも正本（`CMD_NAMES`）を併記した。

`bin/README.md` の `oe-hookfire` 節は、両レーンが本体スクリプトと行単位で突き合わせて食い違いなしと判定した。cursor レーンは exit を実測して照合している（`--days notanint` で 2・無引数で 1）。plan からの引用も claude レーンが逐語一致を確認した。

## 実測で見えた副産物

文書を書くために `oe-hookfire` を実際に走らせたところ、この環境では `tool-attribution` が `broken` を返した（ツール不明の記録が1ファイル・計2件・`$0` による判別が効いていない）。verb が意図どおり異常を検出できていることの実例であり、同時に実環境に未解決の事象があることを示している。本単位の scope 外なので統括へ報告するに留める。

## フィードバック

### closure gate

- **Context / なぜ**: `本文: なぜこの作業が始まったか`
- **次の消費者**: owner（マージ後の配備と確認）と #301（読み手の定期実行の配線を決めるとき、配布済みであることが前提になる）。文書追随の側は、`oe-*` の起動方法を決めるエージェントが消費者である
- **follow-up routing**: `本文: 触らなかったもの` の10件。行き先は1件ずつ付けてあり、内訳は「統括が起票する」2件・「報告で統括へ surface する」6件・「本単位では追わない」2件である
- **status 確定**: `stable`・達成（受け入れ基準のうち、実配備の確認だけが owner 側に残る）
- **evidence anchor**: SO は3回（1本目の実装SO・追加分の実装SO・closure の外部チェック）走らせており、出力先はいずれも `tmp/` で揮発する。レーン・所要時間・解決後モデル・指摘の要旨は本文と PR 本文へ転記した。実測値（PATH 解決の一覧・`oe-hookfire` の実行結果・欠落 verb の数え直し）も本文へ転記済み

### 昇格の判定

frontmatter の `promotion` に5件。作業中に `昇格の印` は1つも置いていない。最初の単位は「配列に1エントリ」の想定で始まり、印を置く発想に至らなかったためで、5件はいずれも closure で見つけた。印ゼロのまま独立に問い直すのが closure の役目なので、その形で判定した。**うち2件は下記の外部チェックで judgment を差し替えた**（最初は4件で、`required` は1件だった）。

- 「gate 3 の保留を #301 を待たずに前倒しで解く」は `required`。**最初はこれを判定の対象に入れていなかった。** owner の指示だから自分の判断ではない、と扱っていたのだが、4件目も owner が下した判断を対象にしているので基準が一貫していない。棄却した案（#301 の着地を待つ）が具体名で挙がり、当時の前提（読み手は人が打つしかない）は #301 が着地すれば偽になる。他の未配布 verb が全く同じ分岐に立つので再訪もされる。plan を読んでも「先に配ってよいか」は決まらないので確認では閉じない
- 「保留の巻き戻しとして記録する」は `not-required`。複数の解釈が実際に live だった（欠落か保留か）が、どちらが正しいかは plan の該当節を読めば決まる。覆すのに議論の再演は要らない
- 「他の未配布 verb を足さない」は `not-required`。各 verb が意図的に未配布かどうかは一次記録を読めば決まる確認側の問いで、教訓そのものは knowledge item として着地済みである
- 「一般化ではなく列挙 + 正本 pointer で書き直す」は `required`。**最初は `not-required` にしていた**（既存規範の適用にすぎない、という理由）。しかし既存規範が与えるのは「二次文書は正本を指す」までで、一般化案を棄却して具体名を残すという部分は規範から導けない。codex の一般化案という具体的な棄却対象があり、即時の発見可能性と陳腐化耐性のどちらを取るかは実物を見ても決まらない方針の選択である
- 「受け入れ基準が closure の成果物の作成を禁じうる」は `required`。本単位では制約が外れて衝突は消えたが、一般形は残る。gate 4 が必須である以上 heavy トリガはほぼ毎回立つので、同じ分岐は再訪される。どちらを優先するかは方針の選択で、実物を見ても決まらない。着地先の候補は委譲 brief の固定節（scope 制約から closure 成果物を除外する）だが、**昇格の実行は本単位の外**なので行き先の判断は統括 / owner に委ねる

### 内容

- **事実・失敗（1）**: brief の警告を着手対象そのものに当てず、意図的な保留を「欠落」として記録しかけた。検出したのは自分ではなく gate 4 の SO である（`本文: 前提が違っていた — 欠落ではなく保留だった`）
- **事実・失敗（2）**: 統括が置いた1ファイル制約が撤回された。統括自身が非を認めており、方針転回にあたる（`本文: 統括の制約が closure の置き場を潰していた`）
- **事実・失敗（3）**: gate 4 の SO が挙げた文書のずれのうち、`CLAUDE.md` の陳腐化を surface 一覧に載せそこねていた。closure の外部チェックで拾って後から直した（`本文: 配布の実態に文書を追随させた`）
- **事実・失敗（4）**: 昇格の判定を最初は4件で出し、`required` を1件しか立てていなかった。外部チェックの指摘で2件を差し替えた（`本文: 昇格の判定`）
- **事実・失敗（5）**: 最初の PR 本文に置いた closure が、スコープ拡大後の実態と食い違ったまま残っていた（変更ファイル数・episode を作らないという記述・`promotion` の件数）。本 episode に closure を移し、PR 本文を現状へ書き直して解消した（`本文: 統括の制約が closure の置き場を潰していた`）
- **事実・失敗（6）**: 文書追随の書き換えで、配布対象に入れたことと配備済みであることを同一視した記述を書いた。「実態が正で文書が古い側を直す」という commit の主題に対して、逆向きに実態を先取りしていた（`本文: 追加分の gate 4`）
- **事実・失敗（7）**: 収穫した knowledge item の `trigger` を、今回の事例に書かれていた条件（brief の警告）に固定してしまい、当たるべき場面で発火しない形にしていた。**item 自身が語っている失敗と同じ構造である**（`本文: 追加分の gate 4`）
- **事実・失敗（8）**: 追加分の gate 4 で codex レーンが2回とも timeout し、SO が partial になった（`本文: 追加分の gate 4`）
- **決定と根拠**: 配布対象の列挙を書き直すとき、一般化（codex 案）ではなく列挙 + 正本 pointer を採った（`本文: 配布の実態に文書を追随させた`）
- **わかったこと**: `oe-tree` に要った symlink 起動の事前修正は `oe-hookfire` には要らない。実測では `~/bin` は `dotfiles/bin` へのリンクで、engine の verb で PATH 上にあるのは `oe-tree` だけだった（`本文: 配布の実態に文書を追随させた`）。また codex レーンは既定のタイムアウトでは返らないことがあり、レビュー級のプロンプトでは `SO_TIMEOUT` を上げる必要がある（`本文: 追加分の gate 4`）
- **原則**: brief が「別の対象については意図的にそうなっている可能性がある」と警告しているとき、その警告は着手対象そのものにも当てる（`本文: 前提が違っていた — 欠落ではなく保留だった`）。negative knowledge として収穫した
- **蒸留シグナル**: knowledge item を1件収穫（`docs/knowledge/items/01KZK26GQZ39WCFV5MYKQMRHWE.md`）。Decision への昇格候補は `promotion` の `required` 3件で、行き先は統括 / owner の判断
- **残課題**: `本文: 触らなかったもの` に routing 済み

### Step 4（heavy tier の外部チェック・実施した）

`so-compare` の弱SO・2レーン（codex + claude）で closure 振り返りを外部チェックした。確認対象は選択的省略 / routing の網羅 / evidence anchor / back-propagation の4点に絞り、`reconstructed` の妥当性と `promotion` の妥当性を加えた。出力は `tmp/so-closure-309b/`（揮発するため要点は以下に転記する）。

**当初は辞退の定型を書いていたが、辞退の理由が自己申告に寄っていたので実際に回した。** 結果として、自己チェックでは出なかった修正が6件出ている。

| レーン | 所要 | 結果 | 解決後モデル |
|---|---|---|---|
| codex | 206秒 | success | `gpt-5.6-sol`（`model_resolved_source=config`・観測値ではない） |
| claude | 418秒 | success | `unavailable:schema-unexpected` |

両レーンが独立に指摘し、対応したものは次のとおり。

- `CLAUDE.md` の配布列挙の陳腐化が surface からも修正からも落ちていた → 直した（claude が単独で検出）
- follow-up の行き先が「統括 / owner へ surface」と一括で、routing の enum になっていなかった → 7件に1件ずつ行き先を付けた
- `head -n -1` の行き先が本文（触らない）と closure（起票する）で食い違っていた → 「本 PR では触らないが統括が隣接欠陥として記録する」に揃えた
- 実測で出た `tool-attribution` の `broken` が routing の集合の外にあった → 集合に入れた
- `promotion` の「列挙 vs 一般化」が甘い（`not-required` → `required`）、および「保留を前倒しで解く」判断そのものが判定の対象から落ちている → 両方直して5件にした
- PR #312 本文が旧 closure のまま古くなっていた → 本 episode へ移し、PR 本文を現状へ書き直した

`canonical/hooks/README.md` の起動例については、指摘のとおり記録が無かったので、変えない理由を本文に明記した。

`reconstructed` の宣言は両レーンとも妥当と判定した。claude レーンは ULID を復号して生成時刻（最後のコミットの63秒後）まで確かめている。

**限界**: 両レーンとも `.oe/` の brief と追加指示を読めていない（worktree に無いため）。したがって brief 固有の指摘が落ちていないかは、この外部チェックでは確かめられていない。

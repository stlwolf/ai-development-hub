# 用語集

人に見せて読んでもらう・答えてもらうページで使う言葉を、ここで1つに決める。ページを作る人もモデルも、ページの札・ラベル・固定の文は、この表の言葉だけを使う。

この用語集は2つの部分からなる。

- 「札の言葉と固定の文」は、`build.py` がページを作るたびに読む表である。データには英語の key を書き、ページにはこの表の言葉が出る。言葉を直すときは、この表だけを直せばよい。受け付ける key の集まりは `build.py` が持つので、この表の言葉を直しても、データとして受け付ける値は変わらない。
- 「和訳しない用語」は、人とモデルが読むための決まりである。`build.py` は読まない。

## 札の言葉と固定の文

表の書き方の決まりは次のとおりである。崩れていると `build.py` は終了コード 2 で止まる。

- 1行に1つの key を書く。key は `` ` `` で囲む。
- `build.py` が求める key は、すべて1回ずつ書く。足りない・重なる・知らない key があると止まる。
- 言葉の中で値を差し込む位置は `{n}` のように波括弧で書く。差し込みを持つ key は決まっている（右の列の `{…}`）。持つべき差し込みが無いとき、持ってはいけない差し込みがあるときも止まる。
- 言葉の中に `|` は書けない。

| key | 言葉 |
|---|---|
| `evidence.verified` | 確かめた |
| `evidence.sourced` | 出典あり・未確認 |
| `evidence.guess` | 推測 |
| `status.awaiting` | 回答待ち {n} 件 |
| `status.answered` | 回答済み |
| `status.live` | 随時更新 |
| `severity.high` | 高 |
| `severity.mid` | 中 |
| `severity.low` | 低 |
| `adopted.adopted` | 採った |
| `adopted.partial` | 一部採った |
| `adopted.rejected` | 採らない |
| `recommend` | 推奨 |
| `text.version` | {time}（最終更新） |
| `text.head_repo` | リポジトリ |
| `text.head_tmux` | tmux |
| `text.head_issue` | issue |
| `text.head_branch` | ブランチ |
| `text.head_version` | 版 |
| `text.head_status` | 状態 |
| `text.why` | 目的 |
| `text.links` | 関連リンク |
| `text.points` | 要点 |
| `text.reason` | 根拠 |
| `text.note_placeholder` | 補足（任意） |
| `text.unanswered` | 未回答 |
| `text.all_recommended` | 全部を推奨どおりにするなら、会話で「全部推奨どおり」と言えば足ります。ページで選んだものがあれば、その項目はページの答えを正とします。 |
| `text.answered_notice` | 回収済みのページです。ここに出ている答えが、回収した答えです。 |
| `text.store_connecting` | 保存先に接続しています |
| `text.store_saving` | 保存しています |
| `text.store_saved` | 保存しました |
| `text.store_failed` | 保存できませんでした。もう一度押すか、下の返答の文を写して会話に貼ってください |
| `text.store_unavailable` | この表示では保存できません。選んだ内容は、下の返答の文を写して会話に貼ってください |
| `text.reply_title` | 返答の文 |
| `text.reply_heading` | 「{title}」への答え（版 {time}） |
| `text.reply_note` | 補足: {note} |
| `text.copy` | 返答の文をコピー |
| `text.copied` | コピーしました |
| `text.copy_failed` | コピーできませんでした。欄の文字を選んで写してください |
| `text.lane` | 指摘したモデル: {lane} |
| `text.col_text` | 指摘 |
| `text.col_severity` | 重さ |
| `text.col_adopted` | 採否 |
| `text.col_reason` | 理由 |

各 key の意味は次のとおりである。

- `evidence.*` は確かめた度合いの札である。`verified` は出典そのものを開いて確かめたこと、`sourced` は出典を挙げたが中身との対応は確かめていないこと、`guess` は出典の無い見立てであることを表す。
- `status.*` はページの状態の札で、ヘッダーの「状態」の行に出る。`awaiting` は答えを待っているページで、`{n}` には答えの選ばれていないカードの数が入る。`answered` は答えを回収し終えたページ、`live` は作ったあとも中身を更新していくページである。
- `severity.*` は指摘の重さ、`adopted.*` は指摘を採ったかどうかの札である。
- `recommend` は、推奨の選択肢に付ける札である。
- `text.head_*` はヘッダーの表の項目名である。`text.version` はヘッダーの「版」の行の値で、`{time}` には `2026-10-19 18:05 JST` の形の時刻が入る。`text.why` は、ページの目的の1文に付ける札である。
- `text.store_*` は保存の状態の文で、ページの JS が出す。
- `text.reply_*` と `text.copy*` は、保存できない表示で出す返答の文と、そのコピーのボタンの文である。`text.reply_heading` の `{title}` にはページのタイトルが、`{time}` には版の時刻が入る。
- `text.lane` は指摘の一覧の上に出す文で、`{lane}` にはどのモデルの指摘かが入る。
- `text.col_*` は指摘の一覧の列の見出しである。

## 和訳しない用語

人が読むページでは、定着した用語を独自に和訳しない。言い換えると、読む人が元の用語を思い浮かべ直す手間が増え、検索もできなくなる。次の用語は、この形のまま書く。

| 書く形 | 書かない形の例 |
|---|---|
| ブランチ | 枝・分岐 |
| コミット | 確定・記録 |
| プッシュ | 押し上げ・送り出し |
| マージ | 合流・統合 |
| PR | 取り込み依頼・プルリク |
| issue | 課題票・チケット（そのリポジトリが issue と呼んでいるとき） |
| レビュー | 査読・目通し |
| デプロイ | 打つ・展開 |
| リリース | 出荷・公開版 |
| worktree | 作業木・作業ツリーの複製 |

- 表に無い用語も、同じ考え方で扱う。そのリポジトリやチームがすでに使っている呼び方があれば、それに合わせる。
- 用語を増やすときは、この表に行を足す。

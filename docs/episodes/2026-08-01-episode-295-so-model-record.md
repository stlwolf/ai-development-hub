---
id: "01KYWVH8WHQTQK09CAVCRCW3SF"
title: "Issue #295 so-compare の解決後モデル記録 — 取れる経路と、あえて依存しない経路"
date: 2026-08-01
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/295"
    reason: "本作業の対象 Issue（cursor / claude の解決後モデルが meta に残らない）"
  - type: design_context
    ref: ".oe/plan-295-so-model-record.md"
    reason: "前の単位（M 系）で作成した調査結果と設計。本単位はこの plan の一部を owner 判断で削って実装する"
---

# Episode: #295 so-compare の解決後モデル記録

本文層は作業中の追記で伸ばす。closure は末尾の「振り返り」節に置き、本文の再掲ではなく本文を指す形で書く。

## 前提（この単位に入る前に決まっていたこと）

前の単位（M1〜M3）で調査と plan を作り、M3 で終端した。その結果 owner が gate 3 で範囲を決めた。

**owner の判断**: claude レーンだけ自動記録する。cursor は `unavailable` を種別つきで記録し、`store.db` 経路は手動調査の手順として文書化する。

**理由**: 非公開の内部 SQLite 形式への自動依存を作らないこと。M1 で見つけた `~/.cursor/chats/**/store.db` の `modelName` は Cursor の更新で無言に取得不能へ落ちうる。**発見は文書として残し、コードは依存しない。**

この判断により、plan の実装ステップ8件のうち cursor の自動取得に当たる部分は実装しない。

## 作業中の記録（随時追記・closure から指せる形で残す）

### N1: worktree と episode 枠

- ブランチは `fix/#295_so_model_record`。prefix は `fix` を選んだ。証跡が記録されない欠陥の修正であり、コミット型が `fix` になるため（`branch-naming` の対応表）。
- worktree は子が自分で作成した（統括は hands-off）。
- episode の置き場は root の `docs/episodes/`。判断理由は、対象が root の `scripts/so-compare.sh` と `canonical/skills/so-compare/SKILL.md` であり、特定 project 配下の資産ではないため。既存の root episode（#113 / #149）も canonical skill の作業を置いており、前例と整合する。

### N2: claude レーンの実装

`--output-format json` に切り替え、`.modelUsage` のキーから解決後モデルを取り出すようにした。

判断したことが4つある。

1. **jq が無い環境では json 化しない。** `CLAUDE_JSON_MODE` を起動時に決め、jq が無ければ従来の text 形式で実行してモデル記録だけを諦める。モデル記録は付随情報であり、そのために回答本文の取得を落とすのは本末転倒だから。
2. **主モデルの選び方はトークン投入量の最大値。** `.modelUsage` は補助モデル（haiku）を必ず含むので、1つ選ぶ規則が要る。実測では主モデルが補助を2桁引き離しており（45034 対 521、24156 対 521）この規則で足りる。ただし経験則なので `models_all` に全キーを併記し、後から検証できる形を残した。
3. **本文は `.result` から取り出して `claude-stdout.txt` へ書く。** ここは `so-verdict.sh` が VERDICT を抽出する入力なので形式を変えられない。取り出しに失敗したら生出力を複写する退避を入れた。これが無いと、タイムアウトで json が切れたときに本文が消えて `timeout_partial` が `timeout_empty` に化け、余計なリトライを誘発する。
4. **環境エラーとデータ不在を canary で切り分けた。** 入力が JSON として読めなかったとき、それが「出力が壊れている」のか「jq 自体が動かない」のかは、その場では区別できない。`printf '{}' | jq` を1回走らせて jq の健全性を確かめてから種別を決めている。推測で種別を割り当てない。

**撤回した案**: 当初 `model_resolved_source` を無条件で `cli-json` と書いていたが、jq が無くて記録を諦めた場合にも `cli-json` と出てしまい、出所として嘘になる。条件分岐して `none` を書くよう直した。

### N3: cursor レーンの実装（自動取得はしない）

`model_resolved=unavailable:cli-not-exposed` を固定で書く。`store.db` を読むコードは書いていない。

種別名を `cli-not-exposed` にしたのは、これが**こちらの失敗ではなく CLI 側が出していない**という理由を表すためである。`query-failed`（環境エラー）や `no-modelusage`（データ不在）と混ざらない。

なお owner 判断で自動取得を落とした結果、plan の7分類のうち `store.db` 経路に属する4種別（`no-session-id` / `store-not-found` / `db-not-found` / `no-modelname`）はコード上到達しなくなった。**受け入れ基準は「`query-failed` と `no-modelname` が別種別」と書いているが、`no-modelname` は落とした経路の種別である。** 基準が求めている実体（環境エラーとデータ不在を混ぜない）は `query-failed` と `no-modelusage` の対で満たしている。この読み替えは N5 の PR 本文にも書く。

### N2/N3 の検証（実コードの関数を取り出して実行）

コピーではなく `scripts/so-compare.sh` から関数本体を `awk` で抜き出して実行した。

| 入力 | `model_resolved` | 本文 |
|---|---|---|
| 実際の json（既定） | `claude-fable-5`（haiku より正しく主を選ぶ） | 取り出し成功 |
| 実際の json（`--model sonnet`） | `claude-sonnet-5`（エイリアス解決が残る） | 取り出し成功 |
| `modelUsage` が空 | `unavailable:no-modelusage` | 取り出し成功 |
| `modelUsage` が無い | `unavailable:no-modelusage` | 取り出し成功 |
| 途中で切れた json | `unavailable:parse-failed` | **生出力へ退避（部分出力が消えない）** |
| 空ファイル | `unavailable:parse-failed` | 空 |
| jq が壊れている（同じ入力） | `unavailable:query-failed` | — |
| jq が無い（同じ入力） | `unavailable:query-failed` | — |

最後の2行が肝心である。**`modelUsage` を持つ同じ入力が、環境が壊れているときは `query-failed`、データが無いときは `no-modelusage` になる。** 種別が実際に分かれていることを、同一入力の対比で確認した。jq の stderr も捨てずに `claude-modelmeta-stderr.txt` へ残している。

### N4: SKILL.md の更新

追加キーの意味、`unavailable` の種別表、`store.db` の手動手順、`auto` が実行ごとに変わる実測を書いた。

**判断を求められていた点（codex の `model_resolved` も観測値でないことを書くか）は、書くことにした。** 理由は、これが利用者の行動を変える情報だからである。SO の判定を証跡として引くとき、claude の `model_resolved` は実際に使われたモデルの観測値だが、codex のそれは設定ファイルを読んだだけの値で、設定と実際が食い違えば嘘になる。同じキー名で並んでいるのに強さが違うことを知らなければ、利用者は codex の値を観測値として引用してしまう。**キー名からは差が見えないので、書かなければ気づけない類の情報である。** レーンごとの確からしさを表にし、「codex の値を実行されたモデルの記録として引用しないこと」と明示した。

あわせて `model_resolved_source` というキー自体を新設し、確からしさの差を機械可読にした。文章の注意書きだけだと読み飛ばされるため。

手動手順を書くときは `head` を使わず `awk 'NR==1'` にした（採用 NK `01KYA7C9M4EN…` の SIGPIPE 回避を、利用者が真似する手順にも効かせるため）。

### N5: 実装SO で自分の設計の穴が2つ出た

`so-compare --with codex,cursor` で実装SO を回した。**codex が CRITICAL 2件・WARNING 2件を返し、そのうち3件を実際に取り込んだ。** 自分では気づいていなかった穴なので、SO が効いた事例として残す。

**CRITICAL 1: 生 json を `stdout.txt` へ退避する設計が間違っていた。**

私は「取り出しに失敗したら生出力を複写して部分出力を守る」と設計し、plan にもそう書いていた。codex の指摘はこうである。text 形式のころの部分出力は**そのまま読める回答**だったが、途中で切れた json は**回答として使えない**。使えないものを非空として置くと `classify_result` が `timeout_partial` と判定し、**`timeout_empty` 限定のリトライが起きなくなる**。つまり再取得の機会まで失う。

これは私の設計判断が逆だったということで、指摘のとおり直した。生出力は `claude-raw.json` に残るので情報は失われない。**plan の §5.4 手順3は誤りだったことになる。** plan は前の単位の成果物なので書き換えず、ここに訂正を残す。

**CRITICAL 2: 環境エラーとデータ不在の分離が、途中までしかできていなかった。**

最初の JSON 妥当性チェックだけ canary で切り分けていたが、その後の `jq` 呼び出しは失敗を全部 `no-modelusage` に落としていた。**本変更の主目的そのものが未完成だった。**

実際に再現も確認した。`{"modelUsage":{"main":{"inputTokens":"x"}}}` を渡すと、`.modelUsage` は存在するのに `max_by` が型エラー（終了コード 5）で落ち、実装は `no-modelusage`（データ不在）と記録する。**データはあるのに「無い」と記録する**ので、SKILL.md の定義とも食い違っていた。

直し方は終了コードの意味を使い分けることにした。`jq -e` は判定が false なら 1、実行に失敗すれば 2 以上を返す。この差がそのままデータ不在と環境エラーの差なので、まとめて非ゼロ扱いにするのをやめた。あわせて「`.modelUsage` はあるが形が想定と違う」を `schema-unexpected` として新設した。

**WARNING: `model_resolved` を観測値と説明するのは強すぎた。**

どのモデルが動いたか（`models_all`）は観測値だが、**そのうちどれが回答を書いた主モデルかは推定**である。トークン投入量が最大、という私の規則は CLI が保証したものではない。補助モデルが何度も呼ばれた場合や同点の場合に外れる。SKILL.md の表現を直し、「厳密に引くときは `models_all` を併記し、`model_resolved` だけで断定しない」と書いた。

**WARNING: モデル ID を検証せずに meta へ書いていた。** meta は `cut -d= -f2` で読まれるので、キーに `=` や改行が入ると行が壊れる。Anthropic の既知の ID では起きないが、外部から来る文字列をそのまま書いている以上コード上の保証が無い。書く前に形を確かめ、外れたら `schema-unexpected` にするようにした。

**取り込まなかった指摘は無い。** 4件すべて対応した。

このとき自分でも1つ見つけた。検証を `printf '%s' "$v" | grep -qE ...` で書いたが、これは**採用 NK `01KYA7C9M4EN…` がまさに警告している早期終了 consumer** である。入力が短いので実害は出ないが、パターンとして残すべきでないので bash の正規表現に置き換えた。NK を守るつもりで書いたコードの中で NK を踏みかけた。

**cursor レーンは返らなかった。** 最小プロンプトでは 38 秒で返るが、この差分レビューは重く、300 秒でも 600 秒でも `timeout_empty` になった。弱 SO の終了条件では実返却が1レーン以上あれば disclose して進めてよいので、codex 1レーンの結果で進める。**「他族2レーンを回した」が「2レーン返った」ではないことを明示しておく。**

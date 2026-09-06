---
id: "01M1VVYR9SCDMEF78SF7J0ESH2"
title: "#303 / #344 段階1 — 空返しの分類と入力拒否の契約を設計する（実行記録）"
date: 2026-09-07
type: episode
status: stable
source: "https://github.com/stlwolf/ai-development-hub/issues/303"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/344"
    reason: "同じ委譲アークで扱うもう一方の issue。レーンへ渡す前の入力拒否の契約"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-09-07-episode-375-cursor-default-composer.md"
    reason: "同じ委譲アークの前段（PR-0）。cursor 既定モデルの変更"
tags: [so-compare, oe-refute, oe-review, classification, timeout, usage-limit]
promotion:
  - subject: "ファイルの中身を見て空だったと書く前に、そのファイルが存在するのかを確かめる"
    verdict: required
    ref: "本文: 2026-09-07 反証で自分の観測の読みが1件崩れた（重要）"
  - subject: "空返しの調査で meta の数値だけを見て打ち切ると、短い stdout に入った故障の文言を落とす"
    verdict: not-required
    ref: "本文: 2026-09-07 P-1（実例と証拠の集約）"
  - subject: "消費者に接続されない分類を先に実装しても、判断は1つも変わらない"
    verdict: not-required
    ref: "本文: 2026-09-07 plan を書き直した"
  - subject: "exit code を提案する前に、その値が同じ道具立ての中で既に使われていないかを確かめる"
    verdict: not-required
    ref: "本文: 2026-09-07 plan を書き直した"
  - subject: "独立した複数のレーンが同じ代替案を出したら、それを優先して取り込む"
    verdict: unknown
    ref: "本文: 2026-09-07 3レーンが独立に同じ代替案を出した"
---

# #303 / #344 段階1 — 空返しの分類と入力拒否の契約を設計する（実行記録）

**なぜこの作業が始まったか**: SO のレーンが返らないとき、`so-compare` は原因の違う複数の故障を `timeout_empty` という1つの値に畳んでいる。上限で塞がれたレーンを「時間切れ」と読むと、待っても直らないものを待ち、実害（#299 で重い欠陥3件が2レーン締めのあとに出た）が繰り返す。段階1 は実装せず、分類の契約と拒否の契約を plan にするところまでを作る。

## 前提（着手時点で確定していること）

- 段階1 は plan-first。実装・マージ・issue close はしない。終端は plan と gate 2 の結果を報告して STOP。
- SO は並行で回さない。1本ずつ走らせ、空で返ったレーンは時間をずらしてそのレーンだけ再走する。
- 委譲 brief が採用した negative knowledge が5件ある。closure でその全件へ観測を1レコードずつ書き戻す。

## 随時追記

### 2026-09-07 P-1（実例と証拠の集約）

作業層の報告に全文がある。`/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub/.oe/report-303-P1.md`。

要点だけ本文にも残す。**当リポの SO 出力 114 ディレクトリ・レーン記録 276 件を走査し、stdout が空だったレーン 45 件の stderr と stdout を内容まで開いた。** 結果、空返しに見える故障は3種ではなく7種の形があった。

判断に効いた発見は3つある。

1. **上限の文言が出る場所がレーンごとに違う。** codex は stderr に出し（`ERROR: You've hit your usage limit ... try again at 4:03 AM`・2026-09-05）、claude は stdout に出す（`You've hit your session limit · resets 12:50am (Asia/Tokyo)`）。片方だけを検査する設計では claude の上限を取り逃す。
2. **上限は `timeout_empty` の外にもいる。** codex の上限は `error`（exit 1・4秒）、claude の上限は `error_partial`（exit 1・stdout 61バイト）に落ちている。`timeout_empty` を細分するだけでは拾えない。
3. **それでも分けられない形が残る。** claude には exit 124・経過が上限ちょうど・stdout も stderr も `raw.json` も 0 バイトという、普通の時間切れと記録が完全に一致する上限疑いがある（#303 本文の実行）。**meta からは区別できない**ので、分類は「分けられないものがある」前提で作る。

**当初は「claude は上限のとき何の証拠も残さない」で結論しかけた。** 45件を meta の数値だけで分類したところで止めていればそうなっていた。`error_partial` の2件（stdout が 60〜80 バイトしかないレーン）を中身まで開いたときに、claude の上限文言と通信断の文言が出てきた。**数値の分類で足りたと思った時点が止まりどころで、そこで中身を開いたのが分かれ目だった。**

昇格の印: 空返しの調査で meta の数値だけを見て打ち切ると、短い stdout に入った故障の文言を丸ごと落とす

### 2026-09-07 P-2（plan と gate 2）

plan を書き、gate 2（設計SO・弱3レーン・`oe-refute --rubric exploration`・audit_id `20260906173009GMTPSPHYMHF6`）を1本だけ回した。**3レーンとも実返却し、3レーンとも `refuted`。** 空返しは無い（codex 480秒上限・claude 1200秒上限・cursor は composer-2.5 で 480秒上限）。

### 2026-09-07 反証で自分の観測の読みが1件崩れた（重要）

**claude レーンの指摘**: 「claude の上限文言は、いまの既定経路では `claude-stdout.txt` に存在しえない」。

こちらでソースと `git log` を開いて確かめたところ、**指摘のとおりだった。**

- `jq` があれば claude は JSON 形式で走り（`scripts/so-compare.sh:358-361`）、プロセスの標準出力は `claude-raw.json` に落ちる（`:889-891`）。`claude-stdout.txt` は `extract_claude_body()` が `.result` から取り出した本文だけである（`:768-789`）。
- B-2 の実物 `tmp/so-293-y4/` は 2026-08-02 02:50 の記録で、**`claude-raw.json` というファイルが存在しない。** JSON 形式が入った `325e25d`（#296・同日）より前の旧 text 経路である。
- P-1 の報告に「B-2 の `raw.json` も空である」と書いていたのは**誤り**だった。走査スクリプトが不在のファイルを空として扱っていた。**「空」と「無い」を区別していなかった。**

**この誤りは、実物を開いたのに起きた。** P-1 で私は「meta の数値だけで止めず中身を開いた」ことを分かれ目として書いたが、開いたところで止まり、**そのファイルが存在するのかどうかを確かめていなかった。** 一段深いところに同じ形の穴があった。

昇格の印: ファイルの中身を見て「空だった」と書く前に、そのファイルが存在するのかを確かめる

### 2026-09-07 3レーンが独立に同じ代替案を出した

反証と一緒に、ゼロベースの代替案が7つ出た。うち3つは**2レーン以上が独立に**出している。

- **追い打ちの極小プロンプト（canary）** — claude と codex。空返しの直後に数秒の上限で1往復投げ、上限か時間切れかを切る。**これが成り立てば、私の plan の中核だった「B-3 は分けられない」が崩れる。**
- **分類を外部の読み取り専用コマンドへ** — claude と cursor。配布物（`~/bin` の symlink）を触らずに過去の出力へ遡って当てられる。
- **circuit breaker / 起動前ゲート** — codex と cursor。

**独立に重なった案を優先して取り込んだ。** 前2つは plan の測定3 と PR-1 になった。

### 2026-09-07 plan を書き直した

3レーンが揃って指した「消費者に届かない分類は判断を変えない」は、`lib/so-verdict.sh:50-72` を開いて確かめた。集約はレーンの stdout の `VERDICT` 行しか読まない。meta に何を書いても、いまの消費者の分岐は1つも変わらない。

**そこで plan の性格を変えた。** 「確定した設計」を出すのをやめ、**確定の前に測ることを特定する**形にした。撤回した判断は4件（claude の観測点・1箇所検査・exit 3・実装の順序）、残した判断は3件である。

`exit 3` の撤回は特に効く。`so_verdict_exit()` は `refuted` のとき exit 3 を返し（`lib/so-verdict.sh:119-125`）、`oe-refute` は so-compare の rc を 2 のときしか見ない（`bin/oe-refute:243-249`）。**入力を拒否して0本しか起動しなくても、上位には「設計が反証された」として届く。**

## closure（2026-09-07・マージ前）

**tier: heavy。** 設計SO（`oe-refute`）を品質ゲートとして明示的に起動し、その結果として方針を撤回した。

### 次の消費者

段階2 を実装する単位（owner が HG-A〜HG-E を裁定したあと）。それから、SO のレーンが返らなかったときに原因を読もうとする統括。

### 事実・失敗

- **設計SO の3レーンが全部 `refuted` を返した**（`本文: 2026-09-07 P-2（plan と gate 2）`）。
- **自分の観測の読みが1件崩れた。** claude の上限文言が stdout に出るという観測は旧経路の記録で、いまの既定経路では別のファイルへ落ちる（`本文: 2026-09-07 反証で自分の観測の読みが1件崩れた（重要）`）。
- **P-1 の報告に事実の誤りを書いていた。** 「B-2 の `raw.json` も空である」だが、そのファイルは存在しない。**報告側に訂正節を追記して back-propagation 済み**（`/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub/.oe/report-303-P1.md` の「訂正（2026-09-07・gate 2 の指摘を検証して）」節）。
- **plan の判断を4件撤回した**（`本文: 2026-09-07 plan を書き直した`）。

### 決定と根拠

- **plan の性格を「確定した設計」から「確定の前に測ることの特定」へ変えた。** 3レーンが揃って「消費者に届かない分類は判断を変えない」と指し、`lib/so-verdict.sh:50-72` を開いて確かめたところそのとおりだった（`本文: 2026-09-07 plan を書き直した`）。
- **棄却した案**: `provider adapter 契約`（得るものは大きいが `so-compare` の全面改修で単位に収まらない）と `非同期実行＋ポーリング`（各 CLI の対応が前提で確かめる材料が無い）。保留にした案3つと採否の理由は plan の §11 にある。
- **exit 3 の提案を取り下げた。** `so_verdict_exit()` が `refuted` に割り当てている値と衝突する（`本文: 2026-09-07 plan を書き直した`）。

### わかったこと

- **母集団が生成側の版で汚染されうる。** 収集期間中に `so-compare` 自身が4回変わり、うち1回は記録の意味そのものを変えた（`本文: 2026-09-07 反証で自分の観測の読みが1件崩れた（重要）`）。
- **空返し 45 件のうち 41 件（91%）が、提案した分類でも `unknown` に倒れる。** 分類の設計は「`unknown` でない側がどれだけ残るか」とセットでしか判断できない。

### 原則

- **NG**: 走査の集計で「ファイルが無い」を「空」に畳む。**OK**: 不在を別のカテゴリとして数え、生成側の版が期間中に変わっていないかを `git log` で確かめる。→ Step 5 で収穫した。

### 残課題（すべて行き先つき）

- **測定1〜3（`unknown` 率の版別集計 / claude の上限時に JSON で何が落ちるか / 追い打ち診断が上限と時間切れを分けられるか）** → **plan の §5 と §8（PR-1 / PR-2）へ。** owner の HG-A 裁定待ち。
- **HG-A〜HG-E（段階2 の入り方・分類の目的の限定・追い打ちの可否・statusLine 起点の別 issue・gate 2 の再周回）** → **plan の §7 へ。** owner の裁定を待つ。本 episode では決めない。
- **circuit breaker / 起動前ゲート案** → **plan の §11 で「保留（測定3 が失敗したときの次点・#303 の scope を超える）」と処分済み。** 別 issue は起こさない。起こすなら HG-D と一緒に owner が決める。
- **claude の上限を statusLine の `rate_limits` から先行検知する案** → **plan の §7 の HG-D。** owner が (a) を選んだ時点で起票する。こちらからは起票しない。
- **`success_empty` の実例が1件も無い問題** → **追わない。** 起こりうるかを確かめる材料が無く、確かめる手段も思いつかない。plan の §12 に未検証として残してある。

### 蒸留シグナル

- **negative knowledge**: 1件収穫した（Step 5）。
- **decision**: 昇格候補なし。設計判断はまだ確定しておらず、確定するのは owner の HG のあとである。判定は frontmatter の `promotion` に5件記録した。

### Step 5（negative knowledge の収穫・実施済み）

`projects/orchestration-engine/docs/knowledge/items/01M1VX9MH72K7G940R6WC7M218.md` を本ブランチに置いた（`validate-knowledge` 緑）。教訓は「走査で『空だった』と書く前に、そのファイルが存在するのかを確かめる。不在はどの版が生成したかの証拠を運んでいる」である。既存の `01KYMRE1N7N0J8VP3CBZZEZ8Q3`（検索0件を不在と読むな）との違いを item 本文に書き分けた。

### Step 6（注入された knowledge への観測の書き戻し・実施済み）

brief に注入されていた item は次の5件である（**この行が分母の記録**）。

- `01KZ3MHMET3GTRXTQXZSZCSWJJ` → `followed`（`#303`）
- `01KYYHGNRJ926N4CTTS4PE8GQH` → `injected_not_used`（`#303`）
- `01M141TB5YHB6VN62RA5TP0S3Q` → `followed`（`#303`）
- `01KZRTSJ2VP8BZR0MF7QZRNYH7` → `injected_not_used`（`#303`）
- `01KZKBS28N0D8JF7DKYF9MW56C` → `followed`（`#375`）

5件すべてに1レコードずつ書き戻し、`validate-knowledge` を全件通した。**`injected_not_used` が2件あるのは正直に書いた結果である。** とくに `01KZRTSJ2VP8BZR0MF7QZRNYH7` は「exit code は走らせて確かめてから書く」という教訓で、注意書きは plan に書いたのに肝心の値（3）を走らせる前に書き、そこを設計SO の3レーンに揃って指摘された。

### Step 4（heavy の外部チェック・実施済み）

`so-compare --with codex,cursor`（弱2レーン・出力は `tmp/so-closure-303-375/`・cursor は `composer-2.5`）で closure の4観点を確認した。#375 の episode と同時に当てている。

**両レーンとも `refuted`。** 指摘は「構造化 closure が無く follow-up が routing されていない」で一致していた。cursor は back-propagation（P-1 報告への訂正）も抜けていると言ったが、**codex は訂正済みと判定しており、実物を確かめたところ codex が正しい**（報告に訂正節がある）。

**この closure 節は指摘を受けて書いた。** 外部チェックを closure より先に走らせたのは順序の誤りで、検査対象が無い状態で回したことになる。次は closure を書いてから当てる。

### status

`stable` / 達成度: **部分達成**。段階1 の終端（plan と gate 2 の結果を出す）には到達したが、**plan は確定していない。** gate 2 が3レーンとも反証し、確定の前に測ることを特定したところで止めている。これは想定内の結果ではなく、設計が通らなかった結果である。

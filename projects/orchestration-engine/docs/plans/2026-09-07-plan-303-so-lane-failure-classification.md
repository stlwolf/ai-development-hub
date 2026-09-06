---
id: "01M1VVYRA46DZCZ8M2058VHZ5Q"
title: "#303 / #344 段階1 — SO レーンの空返しを分類し、渡す前に入力を拒否する契約（設計プラン）"
date: 2026-09-07
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/303"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/344"
    reason: "レーンへ渡す前に入力を型付きの理由で拒否する契約。本プランで一緒に設計する"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-09-07-episode-303-so-lane-failure-classification.md"
    reason: "本プランの実行記録。P-1 の実測の一次記録"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/298"
    reason: "meta に上限・CLI 版・stderr バイト数を入れた前段。本プランはその meta の上に分類を足す"
tags: [so-compare, oe-refute, oe-review, classification, usage-limit, input-validation]
so:
  design: weak
  impl: weak
  reason: "配布物（~/bin symlink で全セッション即時反映）を触るのでリスクは低くないが、変更は meta のキー追加と拒否分岐に分割でき、各段が機械的なテストで閉じる。owner に返す判断を3件残してある"
---

# #303 / #344 段階1 — SO レーンの空返しを分類し、渡す前に入力を拒否する契約（設計プラン）

**段階1 は設計だけを作る。実装・マージ・issue close はしない。** 終端は本プランと gate 2 の結果を報告するところまでである。

## 1. 何を解こうとしているか

SO のレーンが返らないとき、`so-compare` は原因の違う複数の故障を同じ値に畳んでいる。畳まれている限り、待っても直らないものを待ち、恒久的な故障を「そのうち直る」と読む。実害はすでに出ている（#299 の実装SO が2レーンで締められ、あとから返った3レーン目が重い欠陥3件を出した）。

**本プランが増やすのは「なぜ返らなかったか」を機械が言える範囲であって、返らないこと自体は減らない。**

## 2. 実測（P-1・一次情報）

走査した母集団は当リポの SO 出力 114 ディレクトリ・レーン記録 276 件。**stdout が空だったレーンは 45 件**で、その全件について stderr と stdout を内容まで開いた。全文と抽出手順は `/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub/.oe/report-303-P1.md` にある。

見分けられる形は7種あった。

| # | 種別 | レーン | exit | 経過 | stdout | stderr | 決め手 | 現在の分類値 | 当リポ件数 |
|---|---|---|---|---|---|---|---|---|---|
| A-1 | 時間切れ | codex | 124 | 上限と同じ | 0 | 数百KB | stderr が育っている | `timeout_empty` | 11 |
| A-2 | 時間切れ | cursor | 124 | 上限と同じ | 0 | 0 | 無し | `timeout_empty` | 10 |
| A-3 | 時間切れ | claude | 124 | 上限と同じ | 0 | 0 | 無し | `timeout_empty` | 18 |
| B-1 | 使用量上限 | codex | 1 | 4秒 | 0 | 7254B | stderr の文言 + 数秒 | `error` | 1 |
| B-2 | 使用量上限 | claude | 1 | 795秒 | 61B | 0 | stdout の文言 | `error_partial` | 1 |
| B-3 | 使用量上限（疑い） | claude | 124 | 上限と同じ | 0 | 0 | **無し** | `timeout_empty` | 2 |
| C | 認証切れ | cursor | 1 | 0〜1秒 | 0 | 108B | stderr の文言 + `agent status` | `error` | 0（別リポで6件） |
| D | 不正な UTF-8 | codex | 2 | 0秒 | 0 | 179B | exit 2 + 文言 | `error` | 2 |
| E | 環境エラー | codex / claude | 1 | 0秒 | 0 | 115〜219B | 文言 + 0秒 | `error` | 4 |
| F | 通信断 | claude | 1 | 312秒 | 79B | 0 | stdout の文言 | `error_partial` | 1 |
| G | 正常空 | — | 0 | — | 0 | — | — | `success_empty` | **0** |
| H | stdout 空・stderr に本文 | — | — | — | 0 | 数百KB | stderr 末尾の `VERDICT` | — | **0** |

この表から、設計に直接効くことが4つ出る。

1. **上限の文言が出る場所がレーンごとに違う。** codex は stderr、claude は stdout に出す。片方だけを検査する設計は claude の上限を取り逃す。
2. **上限は `timeout_empty` の外にもいる。** B-1 は `error`、B-2 は `error_partial` である。`timeout_empty` を細分するだけでは足りない。
3. **B-2 は「返った」ように見えて返っていない。** stdout が 61 バイトあるので空返しにならず、`oe-refute` / `oe-review` の集約は `VERDICT` 行が無いレーンとして `error` に落とす。上限だと分かる情報が集約の手前で捨てられている。
4. **それでも B-3 は A-3 と分けられない。** 記録が完全に一致する。**分類器を作ってもこの形は「原因不明の空返し」と書く以外にない。**

### 分けられないものは「分けられない」と書く

**B-3 を `usage_limit` と断定してはいけない。** #303 のときに原因が分かったのは「6時間後に同じプロンプトが返った」「owner が上限のリセット待ちを踏んだ時間帯と重なる」という**プロセスの外の情報**によってである。meta にあるどのキーからも導けない。

したがって本プランの分類は、**確定できるところまでしか言わない**設計にする。B-3 に付く値は `unknown`（原因不明の空返し）であって `usage_limit` ではない。

## 3. 設計判断

### DJ-1: 分類をどこに表すか（推奨: 直交キーの追加）

**初期選択肢と暗黙の前提**

初期に浮かんだのは3案だった。暗黙の前提は「分類は `timeout_status` の enum を触ることで表す」「分類は `so-compare` が行う」の2つである。

```text
DJ-1: 分類の表し方
├── 案A: timeout_status に新しい値を足す（timeout_empty を細分）
│     → 差分軸: 既存キーの enum 拡張 → 採否: ❌
│        B-1（error）と B-2（error_partial）は timeout_empty ではないので拾えない
├── 案B: timeout_status は据え置き、直交キー failure_reason を足す
│     → 差分軸: 「どう終わったか」と「なぜ終わったか」を別の軸にする → 採否: ✅ 推奨
├── 案C: enum を置き換える
│     → 差分軸: 破壊的変更 → 採否: ❌
│        消費者（oe-refute / oe-review / テスト / 過去の出力を読む人）が全部動く。得るものは案B と同じ
├── 案D（ゼロベース）: 分類を so-compare の外へ出す
│     → 差分軸: 責務分界。so-compare は生の証拠だけ meta に残し、分類は消費者が行う
│     → 採否: 部分採用（下記）
├── 案E（ゼロベース）: 事後分類ではなく起動前の preflight にする
│     → 差分軸: 実行経路。認証切れは起動前に確定できる
│     → 採否: 採用（PR-3 として分離）
├── 案F（ゼロベース）: 分類せず、証拠を1ファイルにまとめて人へ渡す
│     → 差分軸: 運用前提。機械判定でなく人の判断を速くする
│     → 採否: ❌ 単独では不十分（消費者は機械＝oe-refute / oe-review でもある）だが、
│        「証拠を1箇所に集める」部分は案B の failure_evidence に取り込む
└── 未探索: 分類を CLI 側へ要望する軸（外部依存なので本プランでは扱わない）
```

**採る形**は案B を軸に、案D の懸念（文字列シグネチャは CLI の版で腐る）を反映したものにする。

- `timeout_status` は**今の6値のまま変えない**。これは「プロセスがどう終わったか」を表す機構の値である。
- **`failure_reason` を足す**。これは「なぜ終わったか」を表す。`timeout_status` と直交する。
- **`failure_evidence` を足す**。どのシグネチャが当たったかを書く。当たらなければ `none`。

なぜ直交させるかというと、B-1（codex の上限）は機構としては `error`（exit 1）で、B-3（claude の上限疑い）は機構としては `timeout_empty`（exit 124）だからである。**1つの enum に押し込むと、機構と原因のどちらかが必ず嘘になる。**

`failure_reason` の enum は次の6値にする。

| 値 | 意味 | 次にどうするか |
|---|---|---|
| `none` | 故障していない（`timeout_status=success`） | — |
| `usage_limit` | 使用量・セッション上限に当たった | **再走しても無駄。** 待ち時間を報告してレーンを落とす |
| `auth_required` | 認証が切れている | **owner へ通知。** 人が再ログインするまで回復しない |
| `invalid_input` | 渡した入力が CLI に拒否された | 入力を直す。#344 の拒否契約で起こさなくする |
| `environment` | CLI の外側の環境で落ちた（信頼済みディレクトリ・書き込み権限など） | 環境を直す。再走しても無駄 |
| `unknown` | 上のどれとも確定できない | **断定しない。** 時間切れなら上限を上げて再走する余地がある |

**`timeout` という値を置かないのは意図的である。** 「上限に達して kill された」は `timeout_status=timeout_empty` がすでに表しており、その**原因**が時間なのか上限なのかは分からない（B-3）。原因の軸に `timeout` を置くと、B-3 に `timeout` と書いてしまう。原因が分からないものは `unknown` である。

### DJ-2: 何を見て判定するか

判定は**レーンごとのシグネチャ表**で行う。文言も出る場所もレーンで違うので、共通の1つの規則にはできない。

| レーン | 見る場所 | シグネチャ（部分一致） | 付ける `failure_reason` |
|---|---|---|---|
| codex | stderr | `hit your usage limit` | `usage_limit` |
| codex | stderr | `invalid UTF-8 was detected` | `invalid_input` |
| codex | stderr | `Not inside a trusted directory` | `environment` |
| codex | stderr | `could not create PATH aliases` | `environment` |
| claude | stdout | `hit your session limit` / `hit your usage limit` | `usage_limit` |
| claude | stdout | `API Error:` | `unknown`（通信断。再走の余地があるので断定しない） |
| claude | stderr | `Operation not permitted` | `environment` |
| cursor | stderr | `Authentication required` | `auth_required` |
| 全レーン | — | どれにも当たらない | `none`（成功時）または `unknown` |

判定に**使わない**ものを明示しておく。

- **`stderr_bytes` の大小は判定に使わない。** 量であって時刻ではなく、0 バイトが異常を意味しないことは `so-compare` の skill にすでに書いてある。
- **経過秒と上限の一致も、単独では原因の判定に使わない。** B-3 と A-3 が同じ形になるので、これで分けたつもりになるのが一番危ない。
- **`model_resolved` / `cli_version` は原因の判定に使わない。** 版起因の故障は「版が違う」ことではなく落ち方で見る。

**シグネチャは CLI の版で変わる。** だから当たらなかったときは `unknown` へ倒し、`failure_evidence=none` を書く。**外れたことが分かる形にするのが目的で、当てにいくのが目的ではない。**

### DJ-3: 検知したときの動き

| `failure_reason` | 動き | 理由 |
|---|---|---|
| `usage_limit` | そのレーンのリトライを**抑止**する。上限の文言に復帰時刻が入っていれば meta に残す | 待っても直らない。リトライは時間を捨てるだけ |
| `auth_required` | リトライを抑止し、**owner へ通知する**（`notify.sh` 経由・下記 owner 判断） | 人が再ログインするまで回復しない恒久故障 |
| `invalid_input` | リトライを抑止する | 同じ入力で同じ結果になる |
| `environment` | リトライを抑止する | 同上 |
| `unknown` | **今までどおり**（`timeout_empty` のときだけ ×1.5 で1回リトライ） | 時間切れなら救われる余地がある |

**ここに正直に書いておく穴がある。** リトライ抑止が最も効くのは B-3（claude が 1200 秒 ×2 を焼く形）だが、**B-3 はレーンの中の情報からは検知できない。** 検知できるもの（B-1 の codex）は exit 1 で、そもそも現在の実装ではリトライ経路に乗らない（リトライは `timeout_empty` のときだけ）。

**つまりリトライ抑止の実利は、いま検知できる範囲ではほぼゼロである。** 実利は「なぜ返らなかったかが記録に残る」ことと、`auth_required` の通知のほうにある。**リトライ抑止を主目的に据えると、効かない機構を作ることになる。**

B-3 に効かせたいなら、レーンの外の情報が要る（DJ-4）。

### DJ-4: claude の上限には外の観測源がある

当リポには**すでに**、claude の上限を起動前に知る材料がある。Claude Code の statusLine に渡る JSON に `rate_limits.five_hour.used_percentage` と `resets_at` があり、`canonical/claude/statusline/statusline-oe-heartbeat.sh` が表示に使っている（#276）。**SO の claude レーンは `claude-safe` 経由で同じアカウント・同じプランを使うので、これは claude レーンの先行指標になる。**

ただし heartbeat の sidecar には保存していない。保存しているのは `ts` / `context_pct` / `pane` / `model` だけである。

**この案は本プランの範囲に入れない。** 理由は3つある。

- statusLine は**統括セッション**のプロセスで走る。SO を起動する子セッションが読むには sidecar を経由するしかなく、sidecar の内容を増やす変更は `so-compare` ではなく heartbeat 側（#276 の系）の変更になる。
- 読める値は「statusLine が最後に更新された時点の消費率」であって、SO 起動時点の値ではない。**先行指標であって判定材料ではない。**
- 本プランの scope（レーン結果の分類と入力の拒否）から責務がはみ出す。

**別 issue として起票する候補として残す**（下記「follow-up」）。

### DJ-5: #344 — 渡す前に入力を拒否する契約

#344 の論点1〜4に答える形で書く。

**論点1（拒否するか・修復するか・警告して続けるか）**

**経路ごとに変える。** #340 は `--prev` について「警告つきで修復」を owner が裁定しており、その形はすでに実装済み（`iconv -c` で健全化し、落ちたバイト数を警告する）。**同じ方針を全経路へ広げない。**

| 経路 | 方針 | 理由 |
|---|---|---|
| `--prev`（前回出力の切り詰め） | **警告つき修復**（現状のまま） | owner 裁定済み（#340・2026-08-17）。参考情報なので落としても本題は残る |
| `-c` のコンテキスト添付 | **拒否** | 利用者が明示的に「これを読ませたい」と指定したもの。黙って削ると、削られた前提でレーンが答える |
| `-f` / stdin のプロンプト | **拒否** | 本文そのもの。修復は問いを変えることになる |
| `-w` のワークスペース | **拒否**（不在なら起動しない） | パス参照で渡すので、不在ならレーンは何も読めない |

**判断の分かれ目は「削ったら意味が変わるか」である。** 参考情報は修復してよく、本文と明示指定は拒否する。

**論点2（検査をどこに置くか）**

**プロンプトの組み立てが終わった1箇所**（`scripts/so-compare.sh` で `prompt.txt` を書く直前）に置く。各レーンの起動直前ではなく1箇所にするのは、全レーンが同じプロンプトを受け取るからである。**1レーンだけ静かに落ちるのを全レーンの停止に変える**という #344 の懸念は、この位置なら「1本も起動しない」になり、部分的に壊れた状態が残らない。

ただし `-w` の不在検査だけは、プロンプト組み立てより前（引数解析の直後）に置く。組み立てに使う値だからである。

**論点3（型付きの理由をどう表すか）**

先例 `cli_version_for()`（`scripts/so-compare.sh:562-597`）の作法に揃える。あの関数は**修復せず、失敗の種別を値で返す**（`unavailable:query-failed` / `unavailable:schema-unexpected`）。同じ形で `invalid:<種別>` を返す検査関数を置く。

| 種別 | 意味 |
|---|---|
| `invalid:not-utf8` | UTF-8 として妥当でないバイトが含まれる |
| `invalid:empty` | 中身が空、または空白だけ |
| `invalid:too-large` | 上限バイト数を超える |
| `invalid:not-found` | 指定されたパスが存在しない |

**`cli_version_for()` の教訓をそのまま引き継ぐ。** あの関数のコメントは「allowlist を列挙すると実在する値を落とす」と書いている。入力検査でも同じで、**プロンプト本文に対して文字集合の allowlist を作らない。** 見るのは「UTF-8 として妥当か」「空でないか」「上限内か」の3つだけにする。

**論点4（レーン損失を型付き状態にして縮退再試行する案と組み合わせるか）**

**組み合わせない。** 縮退再試行は「レーンが減ったときにどう続けるか」の話で、本プランの「なぜ減ったかを記録する」とは別の判断である。分類が入れば縮退の判断材料が揃うので、**縮退はその後に別単位で決める**のが順序として正しい。#344 が挙げていた「claude / cursor が不正 argv に耐えるか未検証」という不確実性は、論点1で `-c` と `-f` を拒否に倒すことで、そもそも不正 argv を渡さなくなるため消える。

### DJ-6: 拒否したときの exit code

**現状に不整合がある。** `scripts/so-compare.sh` は終了コードを「0=全成功 / 1=部分成功 / 2=全失敗」と usage に書いているが、入力エラー（`SO_TIMEOUT` が不正など）でも `exit 1` を返している（`:101` ほか）。**呼び出し側から見ると「部分成功」と「起動すらしなかった」が同じ 1 になる。**

拒否の分岐を足すと、この不整合が広がる。そこで**新しい exit code を1つ足す**。

| code | 意味 |
|---|---|
| 0 | 全プロバイダ成功 |
| 1 | 部分成功（一部のプロバイダのみ応答） |
| 2 | 全プロバイダ失敗（起動はした） |
| **3** | **入力を拒否した（レーンを1本も起動していない）** |

**既存の `exit 1`（入力エラー）を 3 に寄せるかどうかは、消費者を確かめてから決める。** `oe-refute` / `oe-review` は `so_rc -eq 2` だけを見ているので 3 は素通りするが、それが正しい挙動かは実際に走らせて確かめる（下記 PR-4 の受け入れ基準）。

**exit code は書いて決まるものではない。** 「この経路で N を返す」と書く前に、経路ごとに実際に走らせて確かめる。これは過去に外した箇所である。

## 4. owner に返す判断

brief が指定した3件に、上の設計から出た1件を足して4件を返す。**どれも私の一存では決めない。**

| # | 判断 | 選択肢 | 私の見立て |
|---|---|---|---|
| HG-1 | 使用量上限を検知したとき、そのレーンを「返らない」として集約するか、時間をずらして自動再走するか | (a) 返らないとして集約し、復帰時刻を報告する / (b) 自動再走する | **(a) を推す。** 復帰まで5時間単位で待つことがあり、SO ゲートを止める時間が読めなくなる。人が復帰時刻を見て回し直すほうが速い |
| HG-2 | 認証切れの検知を owner への通知につなぐか、表示だけにするか | (a) `notify.sh` で通知する / (b) 表示だけ | **(a) を推す。** #303 のコメントで owner が「記録として残して、ちゃんと通知」と明示している。ただし通知は認証切れに限る（上限で鳴らすと頻度が上がって効かなくなる） |
| HG-3 | `timeout_status` の既存値を残すか、新しい enum に置き換えるか | (a) 残して直交キーを足す / (b) 置き換える | **(a) を推す**（DJ-1）。置き換えても得るものは同じで、消費者が全部動く |
| HG-4 | claude の上限を statusLine の `rate_limits` から先行検知する案を、別 issue として起こすか | (a) 起票する / (b) 起こさない | **(a) を推す。** いま検知できない B-3 に効く唯一の材料だが、責務が heartbeat 側なので本プランには入れない（DJ-4） |

## 5. PR 分割

**1 PR = 1論理変更**にする。各 PR は単独でマージでき、前の PR が入っていなくても壊れない順序にしてある。

### PR-1: レーン結果に証拠のキーを足す（分類はまだしない）

- 変更: `scripts/so-compare.sh` の meta に `stdout_head` と `stderr_tail` を足す。どちらも**行を壊さない形に正規化**して入れる（改行と `=` を落とし、上限 200 バイト）。
- なぜ最初に分けるか: **分類の前に、分類の材料が meta に載っていることを確かめる。** 材料が載っていれば、分類のロジックが間違っていても後から人が読み直せる。
- 受け入れ基準
  - [ ] 7種すべての fixture で、meta の行数が変わらず `key=value` が壊れていない
  - [ ] 多バイト文字が途中で切れても行が壊れない（`cli_version_for()` と同じ denylist の考え方を使う）
  - [ ] 既存の meta のキーが1つも欠けていない（変更前後の meta を diff で比較する）
  - [ ] `shellcheck` が緑・既存テストが緑

### PR-2: `failure_reason` と `failure_evidence` を足す

- 変更: `classify_failure()` を追加し、meta に `failure_reason` / `failure_evidence` を書く。`timeout_status` は触らない。
- 受け入れ基準
  - [ ] 7種すべての fixture で、期待した `failure_reason` が付く
  - [ ] **B-3 の fixture では `unknown` が付く**（`usage_limit` と書かないことをテストで固定する）
  - [ ] シグネチャに当たらない未知の故障で `unknown` / `failure_evidence=none` になる
  - [ ] **成功したレーンで `failure_reason=none` になる**（陽性対照）
  - [ ] `timeout_status` の値が変更前と1件も変わらない（過去の出力 45 件を再分類して比較する）

### PR-3: 起動前に認証を確かめる

- 変更: レーンの起動前に `codex login status` / `agent status` を1回叩き、認証が切れていれば**そのレーンを起動せず** `failure_reason=auth_required` で落とす。claude は状態コマンドが無いので対象外。
- なぜ分けるか: これは事後分類ではなく実行経路の追加である（DJ-1 案E）。
- 受け入れ基準
  - [ ] 認証を切った状態で、レーンが起動せず数秒で `auth_required` になる（実機で1回）
  - [ ] **認証が通っている通常の実行で、所要時間が実測で増えていない**（陽性対照。`cli_version_for()` と同じく上限 5 秒を掛ける）
  - [ ] 状態コマンド自体が失敗したときは起動を止めない（検査の失敗で SO を止めない）

### PR-4: 入力を拒否する（#344）

- 変更: プロンプト組み立て完了時点に検査を1つ置き、`-c` / `-f` / stdin / `-w` の不正を `invalid:<種別>` で拒否する。exit code 3 を足す。
- 受け入れ基準
  - [ ] **不正な入力を意図的に作って**、経路ごとに拒否が発火する（非 UTF-8 のコンテキストファイル・空プロンプト・巨大プロンプト・不在ワークスペース）
  - [ ] **正当な入力が今までどおり通る**（陽性対照。既存の SO を1本、実際に回して緑）
  - [ ] `--prev` の警告つき修復が回帰していない（#340 の挙動を変えない）
  - [ ] **exit code を経路ごとに実際に走らせて確かめ、結果を PR 本文の表に書く**
  - [ ] `oe-refute` / `oe-review` が exit 3 を受けたときの挙動を実機で確認する
  - [ ] 誤ったときの revert 手順が PR 本文にある（#344 の受け入れ条件）

### PR-5: 通知と表示（HG-1 / HG-2 の裁定後）

- 変更: `auth_required` を検知したら `notify.sh` で通知する。`oe-refute` / `oe-review` の JSON の `dissent` に `failure_reason` を載せる。
- **owner の裁定が出るまで着手しない。**

## 6. 陽性対照の fixture

7種を再現する fixture を `projects/orchestration-engine/tests/fixtures/so-lane-failures/` に置く。**過去の実物から作る**（作文しない）。

| fixture | 出所 | 再現するもの |
|---|---|---|
| `codex-usage-limit` | `tmp/so-359-design/`（2026-09-05） | B-1 |
| `claude-session-limit` | `tmp/so-293-y4/` | B-2 |
| `claude-timeout-silent` | `tmp/so-e5-impl/` | A-3 / B-3 |
| `cursor-timeout-silent` | `tmp/so-295-impl/` | A-2 |
| `codex-timeout-busy` | `tmp/so-288-h3/` | A-1 |
| `codex-invalid-utf8` | `tmp/so-288-gate2-r2/` | D |
| `codex-untrusted-dir` | `tmp/so-20260616-173340/` | E |
| `claude-api-error` | `tmp/so-20260820-pure-so/` | F |
| `cursor-auth-required` | #303 のコメントの文言から作る（当リポに実物が無い） | C |
| `success-normal` | 任意の成功レーン | **陽性対照**（`failure_reason=none`） |

**`tmp/` は gitignore 対象で消えるので、fixture は中身を切り出して repo に置く。** 生の出力をそのまま置くのではなく、判定に要る部分（exit code・経過秒・上限秒・stdout 先頭・stderr 末尾）だけを取り出す。**プロンプト本文は入れない**（別リポの識別子が混ざりうるため）。

**制御バイトの扱いに注意する。** fixture を書くときに `\uXXXX` のようなエスケープを使うと、書き込みの経路で生の制御バイトに化けて JSON の行が落ちることがある（過去に踏んでいる）。fixture は実行時に `printf` で組み立てるか、バイト列を明示的に変換して置く。書いたあと `grep -nP '[\x00-\x08\x0b\x0c\x0e-\x1f]'` で検査する。

## 7. ゲートの配置

| gate | 位置 | 状態 |
|---|---|---|
| 1 | 設計判断の確定前 | 本プランの DJ-1 に探索木を置き、ゼロベースの代替（案D / E / F）を出した。SO は gate 2 と同じ実行に選択肢拡張として載せる |
| 2 | plan 確定前 | 設計SO 弱・3レーン・1本ずつ。結果を本プランと報告に disclose する |
| 3 | plan → 実装 | **owner HG。** HG-1〜HG-4 の裁定と、PR 分割の承認 |
| 4 | 実装 → PR | 各 PR で実装SO 弱2レーン + Copilot |
| 5 | PR → merge | episode closure（マージ前） |
| 6 | merge 後 | owner のマージ・issue close 判断・worktree 掃除 |

## 8. follow-up（本プランでは実装しない）

- **claude の上限を statusLine の `rate_limits` から先行検知する**（DJ-4・HG-4 の裁定待ち）。
- **レーン損失時の縮退再試行**（#344 論点4）。分類が入ってから別単位で決める。
- **`success_empty` の実例が無い。** 当リポの履歴に1件も無いので、この値が本当に起こりうるのかを確かめる材料が無い。枠としては残すが、扱いは決めない。

## 9. まだ見ていない範囲

結論を確定する前に、探索が届いていない場所を書いておく。

- **別リポの生出力は見ていない。** 認証切れ（C）と、他リポで観測された「stdout 空・stderr に本文」（H）は #303 のコメントの記載を一次情報として扱った。当リポには実物が無い。
- **claude が上限のとき `--output-format json` で何を返すかは分からない。** B-2 と B-3 のどちらも `raw.json` が空だった。
- **cursor が上限に当たった実例が無い。** 当リポにも #303 のコメントにも無く、cursor の上限の形は未知である。
- **codex の上限が attempt 1 で出た例が無い。** 唯一の実例は attempt 2 で出ており、attempt 1 は 240 秒を使い切って `timeout_empty` になっていた。
- **CLI の版とシグネチャの対応を測っていない。** 文言が版で変わることは前提に置いたが、どの版でどう変わるかは追っていない。

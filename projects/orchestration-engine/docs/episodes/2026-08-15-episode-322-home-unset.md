---
id: "01M02WHH43Z9GES6JVRED56VXH"
title: "#322 HOME 未設定で oe-* が引数解析の前に落ちる — 作業記録"
date: 2026-08-15
type: episode
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/322"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/322"
    reason: "本エピソードの起点（うち HOME 部分のみ）"
tags: [engine, home, set-u, help, robustness]
---

# #322 HOME 未設定で oe-* が引数解析の前に落ちる — 作業記録

## なぜこの作業が始まったか

`set -u` の下で未定義の `${HOME}` を展開するため、`oe-*` が**引数解析へ到達する前にシェルごと終了する**。`--help` すら返らず、しかも `oe-send` の場合は出力も無く `exit 1` になる。`oe-send` の exit 1 は「宛先が無い」を意味するので、**環境の失敗が別の帯を汚す**。#322 の2件のうち `HOME` 部分だけを本単位で扱う（`cc-lint` の素通りはスコープ外・#322 は close しない）。

## Step 1 — 一次読解と baseline の実測

### 先例（`cc-lint.sh:39-41`）は「3分岐」だけではない

issue が倣えと言う先例はこれである。

```sh
if   [ -n "${HOOK_FIRING_DIR:-}" ]; then HFR_DIR="$HOOK_FIRING_DIR"
elif [ -n "${HOME:-}" ];           then HFR_DIR="${HOME}/.claude/state/hook-firing"
else                                    HFR_DIR=""
fi
```

同ファイルのコメントが `${HOME:-}/... と書くと HOME 空のとき /.claude/... へ書きに行ってしまう（実測で踏んだ）` と明記している。**単に `:-` を足す直し方は否定済みである。**

**ただし先例の本体は代入だけではない。** 使用側に必ずガードがある。

```sh
:75   [ -n "$HFR_DIR" ] || return 0
:102  [ -n "$HFR_DIR" ] || return 0
```

`HFR_BASE="${HFR_DIR}/tally/..."`（`:54`）は空のとき `/tally/...` になるが、**上のガードを通らないと使われない**ので害が出ない。**つまり先例＝「3分岐の代入」＋「使用側の非空ガード」の対である。** 代入だけ引き写すと、空文字が `/` 始まりのパスへ化けて root 配下を触りに行く — コメントが実測で踏んだと言っている当のものになる。

昇格の印: 先例の「3分岐」は代入と使用側ガードの対で成立しており、代入だけを引き写すと否定されたはずの形に戻るという構造

### baseline を実測した（21 verb × HOME 有無）

`--help` は **stderr** に出る（`oe-send` で 1492 B・rc=0）ので、rc と出力バイト数の両方で測った。

**13 本が影響を受ける。** 死ぬ場所は3種類に分かれた。

| 死ぬ場所 | verb | 出力 |
|---|---|---|
| `lib/delegate-registry.sh:14` | `oe-delegate` / `oe-ident` / `oe-jump` / `oe-list` / `oe-register` / `oe-select` / `oe-status` / `oe-tree` | `HOME: 未割り当ての変数です`（195 B） |
| `lib/oe-viewer.sh:24` | `oe-view` | 同（187 B） |
| **`bin/oe-activity:50`** | `oe-activity` | 同（64 B） |
| **出力なし** | `oe-send` / `oe-ack` / `oe-report` | **0 B**（黙って rc=1） |

影響を受けない 8 本（`oe-capture` / `oe-hookfire` / `oe-kick` / `oe-refute` / `oe-review` / `oe-selfcheck` / `oe-undelivered` / `oe-vitals`）は、help 分岐が `${HOME}` の展開より前にあるか、`${HOME:-}` を既に使っている。

### 出力が消える機構を特定した

`oe-send` を trace すると `lib/delegate-send.sh:22` で止まる。

```sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/event-bus.sh" 2>/dev/null || true
```

**`2>/dev/null` が診断だけを消し、`set -u` によるシェルの終了は止められない。** だから「出力ゼロで rc=1」になる。`|| true` も効かない（展開エラーはシェルを落とす）。**最悪の見え方をしているのは、握り潰しがそこに在るからである。**

### issue の6箇所では足りない可能性がある

issue と brief が挙げる6箇所は lib 側だけである（`event-bus.sh:41/42/46` / `delegate-registry.sh:14/15` / `oe-viewer.sh:24`）。しかし**`oe-activity` は自分の `bin/oe-activity:50` で死ぬ**ので、6箇所を直しても受け入れ条件「`oe-*` が引数解析まで到達し `--help` が 0 を返す」を満たさない。

同型の未ガードは `bin/oe-undelivered:128` にもある（こちらは help が先に短絡するので現状は落ちない）。`bin/oe-vitals:145` は `${HOME:-}` を使っており、**否定されたはずの形**が残っている（空なら `/.claude/state` になる）。

**スコープの扱いは gate 2 と owner の判断に載せる。** 勝手に広げない。

## Step 2 — gate 2（設計SO）

（この節は SO の実行に合わせて追記する）

### 空文字は「未設定」と同じに畳まれる — 設計の急所（実測で判明・自分の事故つき）

「空文字にして安全側へ倒す」を確かめようとして、隔離を怠り**実環境の registry を1件汚した。** 先に事実を書く。

```text
export OE_DELEGATE_STATE_DIR="" で lib を source した結果
  解決された値=[/Users/eddy/.claude/state/oe-delegate]   ← 空のままにならない
  oe_reg_record rc=0                                     ← 実 registry へ書けてしまった
```

`~/.claude/state/oe-delegate/12345__9.json` が作られた。**中身を確認して自分が作ったものと確定させてから削除し、正規の `25967__*` 5件が無傷であることを確認した。**（余談だが、GC が全消ししなかったのは #270 の修正が効いているためである。偽の `$TMUX` の pid=12345 と実サーバの pid が食い違うので GC はスキップした。）

**なぜ空にならなかったのか。`${VAR:-default}` は「未設定」と「空文字」を同じに畳む。** だから空文字を代入しても、後段で `${VAR:-...}` が再評価されれば既定値へ戻る。

**これは本単位の設計の急所そのものである。**

- `lib/event-bus.sh:41-42` は `delegate-registry.sh:14-15` と**同じ変数を `:-` で再宣言する**（registry が source されない経路のためのフォールバック）。したがって registry 側だけを3分岐にして空文字を入れても、**event-bus が後から `${HOME}` 由来の既定値で塗り直す。** 順序次第で空文字は生き残らない。
- `cc-lint` にこの問題が無いのは、`HFR_DIR` を**1箇所でしか決めていない**からである。**6箇所へ機械的に写すと、先例には無い相互作用が入る。**

昇格の印: 空文字を番兵にする設計は、`${VAR:-}` が未設定と空文字を畳む言語規則と、同じ変数を複数箇所で再宣言する構造の組み合わせで壊れるという形

**自分の失敗としても記録する。** #270 では隔離（`OE_DELEGATE_STATE_DIR` を `mktemp -d` へ差し替える）を徹底していたのに、**今回はその隔離機構そのものを検証対象にしたため、隔離を外した状態で実行してしまった。** 「検証対象が隔離の仕組みと同一のときは、別の手段（別ユーザー・別 `HOME`・読み取りだけ）で測る」が正しい。以後この単位では `HOME` を差し替える形（`env -u HOME` / `HOME=<tmp>`）だけを使い、state dir の変数を直接空にする実験はしない。

### gate 2 の SO（2レーン）— 当初案は blocker で覆った

- プロンプト: `tmp/gate2-322-prompt.md` / 出力: `tmp/so-gate2-322/`
- codex 457秒（17713 B）/ claude opus effort=high 471秒（28484 B）。両レーンとも `timeout_status=success`

**1回目の実行は空振りしていた。** 新しい worktree に `tmp/` が無く、プロンプトの書き出しが失敗したまま `so-compare` が起動し、**exit 0 で終わった。** 「終了コード0」を実行の証拠として読まず、出力ディレクトリの実体を見て気づいた。`tmp/` を作って回し直した。

**両レーンが独立に同じ blocker を出し、当初案は3点で覆った。**

**(1) スコープが足りない（6箇所では受け入れ条件を満たさない）。** lib を直すと**次の落下点が露出する**。claude が位置を名指しし、**自分で実測して確定させた**（4変数を外から与えて「lib 修正済み」と等価な状態を作る、という claude の提案どおりの測り方）。

```text
env -u HOME OE_*_DIR=<tmp> bin/oe-jump --help → rc=1  ./bin/oe-jump: 行 31: HOME: 未割り当ての変数です
env -u HOME OE_*_DIR=<tmp> bin/oe-view --help → rc=1  ./bin/oe-view: 行 30: HOME: 未割り当ての変数です
```

**最小スコープは lib 6 + `bin/oe-activity:50` + `bin/oe-jump:31` + `bin/oe-view:30` の9箇所である。** 自分は `oe-activity` までしか見つけておらず、**baseline 表で `oe-jump` / `oe-view` を「lib 側の死因」に分類したことが、そこで思考を止めた原因**だった。lib のクラッシュが先に起きて第2の落下点を隠していた。

**(2) 「読み取りは空なら state 無しとして振る舞う」は #322 の症状を修正側で再生産する。** とくに `oe_reg_resolve` は0件を rc=1（`no live target matches`）で返すので、**「環境が壊れて引けない」が「その宛先は存在しない」に化ける。** これは issue 本文が「`oe-send` の exit 1 は宛先が無いを意味するので環境の失敗が別の帯を汚す」と書いている当のものである。`oe-tree` の空ツリー・`oe-list` の全 `pane-title` fallback・`oe-ack` の `nothing to ack` + exit 0 も同型で、**クラッシュより悪い**（成功に見える）。

**(3) 「書き込みは一律で明示失敗」は既存の不変条件と衝突する。** `lib/event-bus.sh:12-13` が「emit 失敗は本体を壊さない・全 public 関数は常に return 0」と明記しており、`bin/oe-ack:154` は `set -e` 下の裸呼び出しである。ここを非0にすると**受領印が取れない環境事情が oe-ack を殺す**。**issue の受け入れ条件「書き先が無いことを明示して落ちる」自体が engine の best-effort 不変条件と衝突している**ので、owner の判断に載せる。

昇格の印: 「lib を直せば助かる」と読んだ分類が、実は先に死ぬ箇所が後続を隠していただけで、第2の落下点を見落とさせたという構造

### 空文字の畳み込みは番兵なしで解ける（両レーン一致）

自分は「空文字は後段で必ず塗り直される」と書いたが、**これは過大だった**（codex 指摘）。6箇所を**同時に**同じ形へ変え、`HOME` が不在のままなら空文字は空のままである。自分が観測したのは「registry 側だけ変えた + 実 `HOME` が在る」という過渡状態だった。

そのうえで、**`${VAR:-}` を `${VAR+x}` に変える**と、宣言済み（空文字を含む）を尊重するので順序に依存しなくなる。両レーンともこれを推し、番兵値（相対パスに化けて危険）とフラグ変数（真実の源が2つ）は退けた。

```sh
if   [ -n "${OE_DELEGATE_STATE_DIR+x}" ]; then :
elif [ -n "${HOME:-}" ]; then OE_DELEGATE_STATE_DIR="${HOME}/.claude/state/oe-delegate"
else                          OE_DELEGATE_STATE_DIR=""
fi
```

**これは `OE_*_DIR=""` の意味を「既定へ落ちる」から「state 無し」へ変える挙動変更である。** PR 本文に明記する。副次的に、#270 の F20（`mktemp` 失敗で空になった変数が実環境へ解決される）と同じ危険も塞ぐ。

### `-n` では足りない（判定式そのものへの指摘）

`HOME=/` は `-n` を通り、`//.claude/state/...` ＝ root 直下を掴む。相対 `HOME` は cwd 配下に state を散らす。**先例が `-n` で済むのは、あれが tally を1バイト追記するだけの best-effort だからで、state を作る engine には同じ基準では足りない。** 判定は「絶対パスであり、かつ `/` そのものでない」にする。

**これは「先例の premise は移らない」（採用 negative knowledge `01KZVHE0KQ5VCX0SXH0F4SM14D`）が、代入の形だけでなく判定式の側にも当たった形である。**

## Step 3 — B-4 実装（owner の gate 3 通過後・2026-08-16）

裁定は4件とも出た。`event_emit` は不変条件を優先して rc=0 のまま名乗る。tier 2 は**4本とも本単位**（自分は `oe-selfcheck` を別単位と推奨したが owner が全部入れると裁定）。`2>/dev/null` は同じ PR の別コミット。`OE_VIEW_ROOTS` は fail-closed。**スコープは 9箇所 + tier 2 の4本 + `2>/dev/null` の3箇所**になった。

コミットは論理変更ごとに7本へ分けた（PR が大きいため owner が明示的に要求した）。

### 自分の事故が、この修正で構造的に起きなくなった

昨日この単位の調査中に**実 registry を1件汚した**（`OE_DELEGATE_STATE_DIR=""` が実 `HOME` 由来の既定値へ解決されたため）。**同じシナリオを修正の前後で測った。**

```text
OE_DELEGATE_STATE_DIR="" で lib を source（HOME は正常）
  修正前: 解決先=[/Users/eddy/.claude/state/oe-delegate]   ← 実 registry を掴む
  修正後: 解決先=[]                                        ← 空のまま
```

**`${VAR+x}` にしたことで、「空文字を渡したのに実環境へ解決される」経路が消えた。** これは #270 の plan が **F20** として「既存テストの隔離は `mktemp -d` の失敗で外れる」と記録していた危険と同じ形で、**そちらも lib のレベルで塞がった**ことになる。

**自分が踏んだ事故が、その事故を調べていた単位の成果物によって起きなくなる**という順番だった。#270 の GC 修正が翌日の自分の事故を全消しから守ったのに続いて2件目である（あのとき偽の `$TMUX` の pid と実サーバの pid が食い違い、GC がスキップしたおかげで正規5件が無傷だった）。

昇格の印: 自分の作業中の事故が、その作業自体の成果物で構造的に起きなくなるという因果の順番（#270 の GC と #322 の空文字の2件で連続した）

### 検証

- 新規 `tests/test_home_unset.sh` は **55/0**（bash 5.2.37 / 3.2.57 双方）
- **engine の全 39 スイート green**（bash 5.2）。変更に関わる主要14本は bash 3.2.57 でも green
- `shellcheck` は変更した15ファイルすべて clean
- **反証可能性**: 修正前（`90fdb84`）の lib / bin に新テストを当てると **29/26** で、26 assert が落ちる
- 21 verb すべてが `HOME` 未設定で `--help` rc=0（`oe-ident` は `--help` を持たないので出力非空の対象から外し、テストに明記した）

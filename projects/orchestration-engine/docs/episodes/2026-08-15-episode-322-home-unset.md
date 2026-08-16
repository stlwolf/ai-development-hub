---
id: "01M02WHH43Z9GES6JVRED56VXH"
title: "#322 HOME 未設定で oe-* が引数解析の前に落ちる — 作業記録"
date: 2026-08-15
type: episode
status: stable
source: "https://github.com/stlwolf/ai-development-hub/issues/322"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/322"
    reason: "本エピソードの起点（うち HOME 部分のみ）"
tags: [engine, home, set-u, help, robustness]
promotion:
  - subject: "HOME の可否を非空でなく「絶対パスかつ / でない」で見て、判定を ${VAR+x}（宣言済みか）へ変える"
    verdict: not-required
    ref: "本文: 空文字は「未設定」と同じに畳まれる — 設計の急所（実測で判明・自分の事故つき）"
  - subject: "置き場が決まらないことを 0 件と混ぜず、経路ごとの既存契約に沿って名乗る"
    verdict: not-required
    ref: "本文: gate 2 の SO（2レーン）— 当初案は blocker で覆った"
  - subject: "gate 3 でスコープが広がったのに設計判断の表を当て直さず、退行を1件作った"
    verdict: not-required
    ref: "本文: 根本原因は「スコープが増えたのに設計判断を当て直さなかった」こと"
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

## Step 4 — gate 4（実装SO 2レーン + Copilot）

- `tmp/so-gate4-322/`（codex 342秒・claude 471秒）。両レーンとも実返却
- **blocker 1件 + should-fix 多数。両レーンが独立に同じ根本原因を指摘した。**

### 根本原因は「スコープが増えたのに設計判断を当て直さなかった」こと

**gate 3 で tier 2 の4本を後から本単位へ入れたのに、DJ-3（読み取りの帯）と DJ-5（root 走査のガード）をその4本へ当て直していなかった。** DJ の表は tier 2 が入る前に書いたもので、据え置いたままだった。**個別の実装ミスの集まりではなく、1つの構造的な抜けである。** claude レーンがこの診断を明示し、codex の指摘も全部そこに帰着した。

昇格の印: 裁定でスコープが広がったとき、既に書いた設計判断の表を新しい対象へ当て直す工程が抜けるという構造

### 直した内容

**blocker（本 PR が作った退行）**: `oe-vitals` が空の heartbeat dir で `/*.json` を走査し、空の event dir で `mkdir -p /oe-vitals` を試みていた。**変更前は `/.claude/...` へ落ちていたので、悪化させていた。** 走査と書き込みの前で止めた。

**should-fix**:

- `oe-activity` / `oe-undelivered` / `oe-vitals` が、置き場が決まらないのに **exit 0 で「記録なし」**を返していた（`oe-ack` / `oe-tree` で採った形に揃えた）
- ヘルパへ `${VAR:-}` で渡していたため **tier 2 だけ明示的な空文字を尊重せず**、同じノブの意味が producer と consumer で逆になっていた。**値でなく変数名を受ける形**（`${!n+x}`）に変えて解消
- `resolve` / `list` のガードが「両方空」でしか発火せず、片方だけ空だと rc=1（宛先が無い）へ落ちていた
- `oe-delegate:29` に `2>/dev/null` が1件だけ残っていた
- **plan Step 5 で約束した「`/` 直下に何も作られない」検査が無かった。** これが blocker を見逃した直接の原因である。検査を足した（限界も明記した — 一般ユーザでは `/` への mkdir が権限で失敗するので、効くのは root で回る環境である）
- **gate 3 裁定4（`OE_VIEW_ROOTS` は fail-closed）のテストが1件も無かった。** 実装は正しかったが固定していなかった

**nit**: `HOME=//` を弾く / viewer の rc 一覧に 1 を追加 / `oe-hookfire` と `oe-selfcheck` が空パスを表示し「未配備」と**原因を誤って断定**していたのを直す / `oe-selfcheck` の `HOME_DIR` が rc=1 を漏らす形をやめる。

### Copilot（1件・採用）

空の state dir と `/${key}` が連結して root 直下を参照する経路。**指摘は `oe_reg_list` の1箇所だったが、同型が `resolve` / `event-bus` / `oe-ident` / `oe-tree` にもあったので4ファイル7箇所を同時に塞いだ。**

### 検証（最終）

- `tests/test_home_unset.sh` **60/0**・`test_oe_view.sh` **64/0**（bash 5.2.37 / 3.2.57 双方）
- **engine の全 39 スイート green**・`shellcheck` は変更した全ファイル clean
- 修正前（`90fdb84`）の lib / bin に新テストを当てると **26 assert が落ちる**

---

## closure（2026-08-17・マージ前）

**tier: heavy。** 方針転回（gate 2 で当初案が3点覆り、gate 4 でスコープ追随漏れが出た）・意図的な外部レビュー（gate 2 / gate 4 / Copilot）・非自明な設計判断・自分の事故が1件。

### 事実・失敗

- gate 2 で当初案が3点覆った。`本文: gate 2 の SO（2レーン）— 当初案は blocker で覆った`
- **隔離を怠って実 registry を1件汚した。** `本文: 空文字は「未設定」と同じに畳まれる — 設計の急所（実測で判明・自分の事故つき）`
- gate 4 で**自分が作った退行**（`oe-vitals` の root 走査・root mkdir）が出た。`本文: 根本原因は「スコープが増えたのに設計判断を当て直さなかった」こと`
- **plan で約束した検査を2つ書き落としていた**（`/` 直下の差分・`OE_VIEW_ROOTS` の fail-closed）。前者は blocker を見逃した直接の原因。`本文: 直した内容`
- SO の1回目が空振りしていた（`tmp/` が無く exit 0 で終了）。`本文: gate 2 の SO（2レーン）— 当初案は blocker で覆った`

### 決定と根拠

`${VAR+x}` / `_oe_home_usable` / 帯の分け方 / スコープは plan の DJ-1〜DJ-6 と gate 3 の裁定が正本。`本文: gate 2 の SO（2レーン）— 当初案は blocker で覆った`

### わかったこと

- **先例の「3分岐」は代入と使用側ガードの対で成立している。** `本文: 先例（``cc-lint.sh:39-41``）は「3分岐」だけではない`
- `${VAR:-}` は未設定と空文字を畳むので、空文字を番兵にする設計は再宣言と組み合わさると壊れる。`本文: 空文字は「未設定」と同じに畳まれる — 設計の急所（実測で判明・自分の事故つき）`
- 先に死ぬ箇所が後続の落下点を隠す。`本文: gate 2 の SO（2レーン）— 当初案は blocker で覆った`

### 原則

- **裁定でスコープが広がったら、既に書いた設計判断の表を新しい対象へ当て直す。** → 収穫（下記）
- **検証対象が隔離の仕組みそのものであるときは、別の手段で測る。** → 既存 item への観測で足りると判断（下記）

### 次の消費者

- **#322 の `cc-lint` 部分をやる人**（本 PR では触っていない。#322 は open のまま）
- **`oe-*` に新しい verb を足す人**。`tests/test_home_unset.sh` が `bin/oe-*` の glob で自動的に対象へ入れるので、`HOME` 前提を持ち込むとそこで落ちる
- **#337 を実装する人**（registry の帯分け）。本単位が入れた「置き場が決まらない = rc=2」の帯と揃える必要がある

### follow-up の routing

| 項目 | 行き先 |
|---|---|
| `cc-lint` の素通り（#322 の「1.」） | **#322**（open のまま・本 PR では触らない） |
| `oe-delegate:373` の `\|\| true`（登記できなくても spawn が成功扱い） | **追わない**（#270 のスコープ外節と同じ単位・owner 裁定済み） |
| `canonical/claude/statusline/statusline-oe-heartbeat.sh:38` が旧形 | **PR 本文に申し送り済み**（engine 外・owner 判断） |
| `_oe_home_usable` の8ファイル重複 | **テストで固定した**（定義が1種類であることを機械検査） |
| `/` 直下の検査が root 権限でしか効かない件 | **追わない**（テスト内に限界として明記。CI が root で回るなら効く） |

### 昇格の判定

`promotion` に3件（frontmatter）。**`required` は0件。** 設計判断は plan と本 episode に痕跡が揃っており decision へ写しても人間の価値が増えない。一般化できる教訓は knowledge store 側へ回した。

### evidence anchor / SO 証跡

`tmp/so-gate2-322/`（2レーン）/ `tmp/so-gate4-322/`（2レーン）。`tmp/` は gitignore で揮発するので、レーン数・所要秒・指摘の内容と採否は本文へ転記済み。

### status

**stable / 達成。** `HOME` 未設定で引数解析前に abort する問題は解消し、`/` 直下を走査・書き込みしない形にした。**ただし「engine 全体で HOME 無しが安全になった」とは言わない** — 本単位が言えるのは「未定義 `HOME` の abort を止め、root を触らないようにした」までである。

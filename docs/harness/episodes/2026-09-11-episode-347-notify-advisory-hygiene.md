---
id: "01M28491PJBMVBPZFKJ19E4KKZ"
title: "#347 notify.sh の advisory 衛生3件"
date: 2026-09-11
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/347"
    reason: "本 episode の作業対象"
  - type: relates_to
    ref: "docs/harness/plans/2026-09-11-plan-347-notify-advisory-hygiene.md"
    reason: "この episode が記録する作業の計画"
tags: [hooks, notify, advisory, home-unset, shell]
---

# #347 notify.sh の advisory 衛生3件

## なぜこの作業が始まったか

`canonical/hooks/scripts/notify.sh` は、エージェントの完了と入力待ちを macOS 通知へ流す advisory フックである。advisory なので「環境の事情で落ちない・雑音を出さない」が契約なのに、その契約を破る箇所が3つ残っていた。issue #347 は、#343（notify.sh の切り詰め）の実装子が範囲外として surface し、gate 4 の codex レーンが「メモに埋めず別 issue にすべき」と言ったことから起票された。

## Step 1: 3件を実測で再現する（2026-09-11）

issue の主張を鵜呑みにせず、着手時点の master（`04722ba`）で自分で再現した。

### 1. HOME 未設定で rc=1 になる

```text
$ printf '{"message":"test"}' | env -u HOME bash canonical/hooks/scripts/notify.sh >/dev/null 2>&1; echo $?
1
$ printf '{"message":"test"}' |            bash canonical/hooks/scripts/notify.sh >/dev/null 2>&1; echo $?
0
```

stderr に出るのは `notify.sh: 行 112: HOME: 未割り当ての変数です`（メッセージは locale に従う）。`set -u` の下で未定義の変数を展開したので、シェルがその場で終了している。末尾の無条件 `exit 0` へ到達していない。

該当はデバッグ判定の行で、`notify-hook-debug` で検索すると当たる。隣の `NOTIFY_DEBUG` は `${NOTIFY_DEBUG:-}` で guard されているのに、`$HOME` だけが素である。

### 2. 制御端末を持たない起動で /dev/tty の雑音が出る

フックは制御端末を持たない文脈で起動されうる。`os.setsid()` で制御端末を手放した子プロセスから、tmux 変数を外して起動すると再現した。

```text
rc = 0
stdout+stderr = canonical/hooks/scripts/notify.sh: 行 125: /dev/tty: Device not configured
```

終了コードは 0 なので契約違反ではないが、advisory が毎回 stderr を汚す。`-w /dev/tty` の guard を通過している点が肝心で、macOS では制御端末が無くてもデバイスノードへの `access` は成功し、`open` だけが `ENXIO` で失敗する。guard では防げない。

### 3. jq の下限がコード中のコメントにしかない

`canonical/hooks/README.md` の「前提条件」節は `jq` と `grep` が必要とだけ書いていて、版の下限は書いていない。下限 1.4 の根拠は notify.sh のコメントにだけ在る。

## Step 2: リダイレクトの順序が診断を消すかを確かめる

issue は「`2>/dev/null` がリダイレクトより後にあるため効いていない」と書いている。これを単独で確かめた。

```text
$ bash -c 'printf x > /nonexistent-dir/foo 2>/dev/null'; echo "rc=$?"
bash: 行 1: /nonexistent-dir/foo: No such file or directory
rc=1
$ bash -c 'printf x 2>/dev/null > /nonexistent-dir/foo'; echo "rc=$?"
rc=1
```

リダイレクトは左から右へ処理されるので、先に stderr を `/dev/null` へ向けておけば、後続のリダイレクト失敗の診断もそこへ落ちる。終了コードはどちらも 1 のままで、`&& delivered=1` の判定は変わらない。issue の読解は正しい。

## Step 3: 同族が他に無いかを走査する

#347 は「`oe-*` 側は #341 で揃えたが hook 側に残っていた」という取りこぼしから生まれた issue なので、hook 側に他の同族が無いかを見た。

`canonical/hooks/scripts/` の8本に対して `$HOME` と `${HOME` を走査した結果、`set -u` の下で素の `$HOME` を展開しているのは `notify.sh` の1箇所だけだった。他の5箇所（`cc-lint.sh` / `block-destructive.sh` / `block-force-push.sh` / `session-name.sh` / `oe-prompt-receipt.sh`）はいずれも `${HOME:-}` で受けている。

この走査だけでは「grep のパターンが見落とす形」を排除できない。走査パターンの外から対照を取る手立ては plan の検証 step に置いた（8本すべてを `env -u HOME` で実際に起動して終了コードを見る、という振る舞い側の対照）。

リダイレクトの順序については、`notify.sh` の中に同じ形が2箇所ある（tmux のペイン TTY へ書く側と `/dev/tty` へ書く側）。**この数え方は誤りだった。実際は3箇所である（Step 4 で訂正した）。**ファイルの外にも `session-name.sh` と `oe-prompt-receipt.sh` に同じ形があるが、これらは通常ファイルへの追記なので #347 のスコープ外である。

昇格の印: hook 側と engine 側で `HOME` の可否の基準が違う（engine は「絶対パスかつ `/` でない」、hook は「非空」）。どちらが正しいかではなく「読むだけか書くか」で分かれている可能性がある。判断が固まったら decision へ上げるか検討する。

## Step 4: 設計SO（ゲート2・弱・2レーン）で3つの判断が覆った（2026-09-11）

`so-compare --with codex,claude` で plan の初稿を反証にかけた。**期待2者・成功2・部分0・失敗0**（codex は初回タイムアウトで1回リトライののち 298 秒で成功、claude は 491 秒）。結果は `so-347-design-out/` に残っている（作業ツリー外の一時領域なので commit しない）。

**自分で見つけられていなかった反証が3つ出た。**

### 覆った1: 「非空で足りる」は `HOME=/` で崩れる

初稿の DJ-2 は「`notify.sh` は `-f` を1回するだけで書き込みも走査もしないので、`HOME` の可否は非空で足りる」と書いていた。両レーンが同じ反例を出した。

初稿が `${HOME:-}` を退けた理由は「空文字のとき `/` 直下を見に行くから」である。**その理由は `HOME=/` にそのまま当てはまる。** `-n "/"` は真なので guard を通り、`//.notify-hook-debug` を評価する。つまり初稿は、空文字を退けた理由で `HOME=/` を退けていなかった。自分の論法の中に反例があったのに気づいていない形である。

レーンの主張を鵜呑みにせず実測で当て直した。

```text
$ HOME=/  bash -uxc '[[ -n "${HOME:-}" && -f "${HOME}/.notify-hook-debug" ]]'
+ [[ -f //.notify-hook-debug ]]
$ HOME=// bash -uxc '[[ -n "${HOME:-}" && -f "${HOME}/.notify-hook-debug" ]]'
+ [[ -f ///.notify-hook-debug ]]
```

claude レーンの指摘がもう一段効いた。engine が `/` と `//` を名指しで落としているのは「書き込むから」ではなく「`/` を家として扱わない」からで、読むだけの用途にも同じ理由で効く。初稿は engine の厳しさを丸ごと「書き込み側の事情」に帰していたが、区別すべきなのは「絶対パスを要求するかどうか」であって「`/` を弾くかどうか」ではなかった。

**負の知識 `01M1272GA8CRXQKQWMF005NHCF` の当たり方が、予想と逆だった。** あの item は「借りてくる先の書き方が何をしていないかを確かめてから写せ」で、初稿はそれに従って engine の `_oe_home_usable` を「書き込み前提だから写さない」と判断した。確かめる向きは合っていたが、**分解の仕方を間違えた**。engine の述語は「絶対パス要求」と「`/` 排除」の2つの成分でできていて、前者だけが書き込みの事情である。借り物を「写す / 写さない」の2値で見たのが誤りで、成分に割ってから要否を決めるべきだった。

### 覆った2: 同じ欠陥は2箇所でなく3箇所

両レーンとも、デバッグログの追記 `>> /tmp/notify-hook.log 2>/dev/null || true` が同じリダイレクト順の欠陥を持つと指摘した。`|| true` が握り潰すのは終了コードだけで、診断は握り潰さない。

**Step 3 の走査はこの行を出力に含めていた**（`>> ... 2>/dev/null` のパターンで当たっていた）。にもかかわらず「配信の2箇所」とだけ数えたのは、grep の結果を配信のブロックに限って読んだからである。**走査は当たっていて、読み方で落とした。** 負の知識 `01M07QDKE73BTK0Q3K90FE4G9T` は「N 箇所だけ」の対照を走査パターンの外から取れという教訓だったが、今回の取りこぼしは走査の外ではなく**走査の結果を読む段**で起きた。

### 覆った3: 陽性対照が本番と違う分岐を通る

初稿の DJ-6 は `bash -x` のトレースで「配信の分岐を通り末尾の `exit 0` に達している」ことを見る、としていた。claude レーンの指摘は、**対話端末から走らせると `/dev/tty` が開けるので `delivered=1` になり、本番のフック文脈（制御端末なし）が通る経路を通らない**というものだった。手元が tmux の中なら今度は tmux 分岐が成立する。どちらにしても、対照の環境が検証したい環境と違う。

負の知識 `01M00KCCHNMFPHP5HAGX2DZ1MK`（期待した色が出た理由まで確かめよ）を初稿で当てたつもりだったが、**当て方が浅かった**。「rc=0 が正しい理由で出たか」を見る道具として `bash -x` を選んだところまでは合っていて、その道具が**本番と違う環境で走る**ことを見ていなかった。両レーンが独立に、偽の `terminal-notifier` を `PATH` に置いて引数を記録する形を薦めた。副作用で確定するので判定が機械的になり、`HOME` 設定時の記録と比べれば「同じものが届いた」まで言える。

### 訂正: `jq` の下限を「前提条件」節に書くと他フックと矛盾する

両レーンが同じ指摘をした。README の「前提条件」節は全フック共通なのに、同じディレクトリの `session-name.sh`（3箇所）と `oe-prompt-receipt.sh`（1箇所）が `jq -cn` という短オプションの連結を使っている。`notify.sh` のコメントが述べている規則をそのまま当てると、これらは 1.5 を要求する。grep で当て直した。

```text
canonical/hooks/scripts/session-name.sh:49:  out="$(jq -cn --arg t "$1" \
canonical/hooks/scripts/session-name.sh:130:    jq -cn --arg b "$branch" '{last_branch:$b}' >"$tmp" 2>/dev/null \
canonical/hooks/scripts/session-name.sh:156:if jq -cn --arg b "$branch" '{last_branch:$b}' >"$tmp" 2>/dev/null; then
canonical/hooks/scripts/oe-prompt-receipt.sh:169:line="$(jq -cn \
```

claude レーンの整理が要点を突いていた。1.4 という値が意味を持つのは `notify.sh` を改変する人だけで、その人に伝えたい中身は「下限は 1.4」ではなく「`-R -r` を `-Rr` に縮めるな」である。読者が改変者に揃う `notify.sh` 節へ置くのが筋である。

### 範囲外として拾った指摘

- デバッグログの追記先が FIFO だと `open(2)` でブロックし、フックが止まる。README の「発火記録」節は止める側3本について同じ危険を明文で扱い、3つの追記先すべてにガードを通したと書いている（実装は `block-destructive.sh` の `[ -e "$1" ] && [ ! -f "$1" ]`）。`notify.sh` には無い。**受け入れ条件に無いので owner の裁定に預ける**（plan の「owner に預ける判断」節）。
- `input="$(cat 2>/dev/null || true)"` は stdin が閉じられない場合に戻らない。`[[ -t 0 ]]` が弾けるのは端末だけである。ハーネスが実際にそういう起動をするかは未確認なので推測扱い。
- `tr` や `basename` が `PATH` に無いと stderr に診断が出る。README の「外部呼び出しは全て `|| true`」は実装の厳密な説明になっていない。

### Cursor は `notify.sh` を呼ばない

codex レーンの指摘で README のカバレッジ表を読み直した。hook スクリプトは3ツールの `hooks/` へ symlink で配られるが、通知に `notify.sh` を使うのは Claude Code と Codex の2つで、Cursor は「既存の通知機構があるため対象外」と明記されている。回帰確認で要るのは「3ツール分の同じテスト」ではなく、実在する2つの入力プロトコル（Claude Code の引数 + stdin JSON と、Codex の第1引数 JSON）である。

昇格の印: 「借りてきた述語を写す / 写さないの2値で見ず、成分に割ってから要否を決める」は、負の知識 `01M1272GA8CRXQKQWMF005NHCF` の適用範囲を一段広げる内容である。closure で item への観測書き戻しに含めるか、別の item にするかを判断する。

昇格の印: 「走査は当たっていたが結果の読み方で落とした」は、`01M07QDKE73BTK0Q3K90FE4G9T`（対照を走査パターンの外から取れ）とは別の失敗段である。走査の健全性と、走査結果の読み取りの健全性は別に扱う必要がある。

---
id: "01M6ZZY46X9PVAZ00BC56R3T8V"
title: "#602 master で前から落ちている engine の検査3件を直す"
date: 2026-11-09
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/602"
    reason: "作業対象"
tags: [tests, shellcheck]
---

# #602 master で前から落ちている engine の検査3件を直す

## なぜこの作業が始まったか

engine の PR を出すたびに「この失敗は master でも落ちる」と確かめ直す手間がかかっていた（#577・#576・#355）。owner が 2026-11-09 に「602 はやる」と指示し、小さな直しとして plan なしで委譲された。認識合わせは owner の指示で省略した。

## 変更前の master で3件が落ちることの確認

最新の master `90d928a`（#606 のマージ後）で、shellcheck 0.11.0・bash 5.2.37・bash 3.2.57 を使って確かめた。行番号は issue から写さず、このとき取った。

- `bash tests/test_home_unset.sh` が `FAIL: _oe_home_usable の定義は1種類 (want='1' got='2')` を出し、`RESULT: pass=71 fail=1` で終わる。
- `shellcheck -x bin/oe-send bin/oe-jump` が SC2034（`OE_TARGET_CALLER appears unused`）を `bin/oe-send:28` と `bin/oe-jump:34` に1件ずつ出す。issue の本文は「`-x` 無しでは出ない」と書いていたが、`-x` 無しでも同じ2件が出た。issue の記述と食い違うので、ここに残す。
- `shellcheck -x tests/test_handoff_take.sh` が SC2329（`This function is never invoked`）を `tests/test_handoff_take.sh:495` の `rmdir()` に1件出す。issue の「1〜2件」は、このとき1件だった。

negative knowledge: 着手時に `knowledge-list --strict` を見直した。「同種の他の箇所を走査する」型の item が近いが、今回は brief が対象を3件に絞っているので採用せず、同種の箇所は下の follow-up に残す。

## 直し方と理由

### `_oe_home_usable` の定義の数え方

検査の数え方は変えず、`lib/handoff-state.sh` の定義をほかの lib と同じ1行に直した。

理由は3つある。1つ目に、`_oe_home_usable` を持つ lib は `session-title.sh`・`delegate-registry.sh`・`heartbeat-resolve.sh`・`oe-viewer.sh`・`lease.sh`・`event-bus.sh` のすべてが1行で書いており、複数行は `handoff-state.sh` だけだった。2つ目に、`handoff-state.sh` 自身の注記が「delegate-registry.sh と byte 一致させる・#322」と書いており、ずれていたのは lib の側である。3つ目に、検査は1行の定義の全文を比べているので、本体のずれを捕まえられる。数え方を複数行に合わせて直すと、定義の頭の行しか比べられなくなり、本体がずれても通ってしまう。

陰性対照として、bin と lib を作業用の場所に写し、`lib/lease.sh` の本体の `/*) return 0` を `return 1` に変えて同じ grep を回した。直したあとの数は 1 で、本体を変えると 2 になった。検査は本体のずれを捕まえたままである。いまの検査は、複数行の定義が増えたときも頭の行が1行の形と違うので 2 と数えて落ちる。

### SC2034（`OE_TARGET_CALLER`）

注記で止めた。値は `lib/target-resolve.sh:42` の `_oe_target_say` が読むので、未使用ではない。実際に `OE_LEASE_DIR` を空の作業用の場所にして存在しない lease_id を渡すと、`oe-send:` と `oe-jump:` が頭に付いた案内が出た。

誤検知の原因は、最初に考えた「shellcheck が関数の中の読みを数えない」ではなかった。最小の再現（関数を持つ lib を source してから変数を代入する）では SC2034 は出なかった。原因は `# shellcheck source=../lib/target-resolve.sh` の相対パスが、スクリプトの場所でなく shellcheck を走らせた場所から解決されることだった。engine の根から `shellcheck -x bin/oe-send` を走らせると lib に届かず、警告が出る。`bin/` に入って走らせるか `-P SCRIPTDIR` を付けると、lib を読んで警告は出ない。リポジトリの文書は engine の根から `shellcheck bin/...` を走らせる形で書いているので、注記の理由もこの原因で書いた。

昇格の印: shellcheck の `source=` 指示は走らせた場所から解決されるので、engine の根から回すと lib を読まずに誤検知が出る。`.shellcheckrc` に `source-path=SCRIPTDIR` を置けば根本から消えるが、engine の全ファイルの検査結果が変わるので今回の範囲の外とした。

### SC2329（`tests/test_handoff_take.sh` の `rmdir()`）

注記に SC2329 を足して止めた。この `rmdir()` は lib の `oe_seat_rewrite` が呼ぶ `rmdir` を差し替えて回数を数えるためのもので、検査 [33] が「rmdir は1回」で通るので、実際に呼ばれている。すでに SC2317 の注記があったが、shellcheck 0.11 で関数が呼ばれない警告が SC2317 から SC2329 に分かれたため、0.11 では止まらなくなっていた。0.11 より前の版でも SC2317 で止まるように、両方を並べて書いた。古い版が知らない番号 SC2329 の disable を無視するかは、手元に古い版が無く確かめていない（推測）。

## 検査の結果

直したあと（コミット `6b3c38b`）に受け入れ基準の検査を回した。

- `projects/orchestration-engine/tests/test_*.sh` の64本を、bash 5.2.37 と bash 3.2.57（`/bin/bash`）でそれぞれ1本ずつ回した。どちらも64本すべてが終了コード 0 で、ログに `FAIL` の行は無かった。`test_home_unset.sh` は両方で `RESULT: pass=72 fail=0` になった（変更前は pass=71 fail=1）。
- 変えた4ファイル（`bin/oe-send`・`bin/oe-jump`・`lib/handoff-state.sh`・`tests/test_handoff_take.sh`）に engine の根から `shellcheck -x` を当て、警告は0件だった。`bin/` に入って走らせても0件だった。

## 実装SO（弱・1レーン）

`so-compare --codex-only`（codex の解決モデルは `gpt-6.1-sol`）で、コミット `6b3c38b` を見てもらった。依頼文は作業層の `tmp/602/so-impl-prompt.md` に置いた。観点は brief のとおり「注記で止めた警告が本当に誤検知か」と「数え方を変えずに直したことで、捕まえるべき重複した定義を見逃さないか」の2つにした。判定は `VERDICT: survived` だった。

- 誤検知かどうか: codex も、engine の根からは SC2034 が出て `bin/` からと `-P SCRIPTDIR` では出ないことを自分で走らせて確かめた。SC2329 は、注記から SC2329 を外すと警告が戻ること、`lib/seat.sh:93` の trap から差し替えた `rmdir` が呼ばれることを確かめた。
- 見逃し: 本体が違う1行の定義や、もとの複数行の定義を足すと 2 と数えて落ちることを確かめた。一方で、`_oe_home_usable()` と `{` を別の行に書いた定義は grep に当たらず、足しても 1 のままになる。これは今回の変更より前からある検査の限界で、今回は直さない（follow-up に残す）。
- 機能: 変えた実行コードは `lib/handoff-state.sh` の改行だけで、HOME の値を6通り変えて直す前と直したあとの返り値が一致した。

## follow-up

- 検査 [5d] の grep は `_oe_home_usable() {` が1行にそろっていることを前提にしており、`{` を別の行に置いた定義を見逃す。行き先は、この検査を次に触る engine の作業である（今回は issue の範囲の外）。
- shellcheck の `source=` が走らせた場所から解決される件は、engine の根に `.shellcheckrc`（`source-path=SCRIPTDIR`）を置けば注記なしで消せる見込みがある。engine の全ファイルの検査結果が変わるので、別の issue で扱うのがよい。
- `tests/test_monitor.sh`・`tests/test_spawn_board.sh`・`tests/test_verify.sh` にも shellcheck 0.11 の SC2329 が出ている（どれも SC2317 の注記だけがある箇所）。brief が対象を `tests/test_handoff_take.sh` に絞っているので直していない。同じ注記の足し方で止められる。

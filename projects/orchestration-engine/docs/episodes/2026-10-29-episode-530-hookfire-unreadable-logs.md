---
id: "01M61VMCX7PVH3N1CBQ7993RH4"
title: "#530 oe-hookfire が diag.jsonl・deny.jsonl を読めないときに「0 件」として ok を出す"
date: 2026-10-29
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/530"
    reason: "本 episode の作業対象"
tags: [orchestration, hook, health-check]
knowledge_observations:
  - "01KZ21M0N0FZ4YMR2R6DPHTWQ4"
---

# #530 oe-hookfire が diag.jsonl・deny.jsonl を読めないときに「0 件」として ok を出す

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## この単位の入力

- brief: 統括（cockpit 21代目）が 2026-10-29 に発行した小さなコードの直し4件の brief（作業層・消える）の単位 U1。plan と認識合わせは owner の方針で省く。終端は U1-S3（報告を送る）。マージ・worktree の掃除・issue の close・sync はしない。
- scope: `projects/orchestration-engine/bin/oe-hookfire` の 4節（record-health）と 5節（internal-error）。ログが読めない・jq が失敗したときは indeterminate を返す。壊れた symlink も扱う。
- SO: 実装 weak（Codex 1レーン）+ Copilot 1ラウンド。
- 注入された negative knowledge: 1件（frontmatter の `knowledge_observations`）。closure で観測を書き戻す。

## 作業の記録

### S1: 再現（2026-10-29）

master `be0df85` の oe-hookfire で再現した。fixture の diag.jsonl と deny.jsonl に今日の ts の失敗の行と internal-error の行を1行ずつ入れて `chmod 000` にすると、record-health は `ok 直近 7 日の記録失敗は 0 件`、internal-error は `ok 直近 7 日の内部エラーは 0 件（累計 0 件）` を出した。2つを壊れた symlink にすると、record-health は `ok 記録の失敗は記録されていない` を出した。internal-error は `indeterminate deny.jsonl が無い` で、判定は ok ではないが、理由が「無い」になっていて実態と合わない。

### S1: 直し方と確かめた結果（2026-10-29）

- **直し方**: 件数を `jq … | wc -l` で数える形をやめ、`count_jsonl` で jq 自身に `[inputs | fromjson? | select(…)] | length` で数えさせ、jq の終了コードを拾う。失敗したら空文字を返して呼び出し側が indeterminate に振る。これは同じスクリプトの `size_of` と同じ決まりである。ログの置かれ方は `log_state` で4つ（無い・壊れた symlink・通常のファイルでない・通常のファイル）に分け、無いときだけ今までの判定を返す。
- **棄却した選択肢**: `-r` で読めるかを先に見るだけの直し方は採らなかった。IO エラーや読んでいる途中の失敗は拾えず、`wc -l` が 0 に潰す筋が残るからである。jq の終了コードを見る形なら、権限も IO も同じ筋で拾える。
- **通常のファイルでないとき**: ディレクトリや FIFO も indeterminate に振った。FIFO を jq で読むと書き手が来るまで止まるので、読まずに判定する。brief の scope には無いが、壊れた symlink と同じ分岐（`-f` を通らず「無い」に落ちる）で起きる同じ不具合なので、同じ単位で直した。
- **確かめた結果**: `tests/test_hook_firing.sh` に [19] を足した（9項目）。`/bin/bash` 3.2.57 で pass=59 fail=0、bash 5.2.37 で pass=63 fail=0。差の4件は既存の inherit_errexit の SKIP で、master でも 50 と 54 で同じ差がある。oe-hookfire だけを master に戻して走らせると、[19] の4項目が落ちた（chmod 000 の2件・壊れた symlink の record-health・「無い」と書く文言）。壊れた symlink の deny.jsonl の判定は master でも indeterminate なので、その項目は落ちない（文言の項目で落ちる）。`shellcheck` は oe-hookfire とテストの両方で通る。

### S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）

Codex の1レーンが返った（`timeout_status=success`・145秒・meta の `model_resolved` は `gpt-6.1-sol` で、出所は config なので観測値ではない）。出力は作業層の `tmp/so-530-impl/` にある。指摘は2件で、ほかの観点（壊れた行・ts の無い行・JSON でない行での件数の一致、jq が途中まで読んでから失敗したときの扱い、log_state の分け方、[19] が修正を外すと落ちること）は問題なしだった。

- **採用（中）: 置き場のディレクトリに検索権限が無いと、`-e` も `-L` も偽になり「無い」に落ちて record-health が ok になる。** 変更前からある筋で、この差分が持ち込んだものではない。ただし #530 の「権限の誤りで読めないのに ok」と同じ不具合なので、この単位で直した。`log_state` で置き場のディレクトリが在って検索権限が無いときを先に分け、indeterminate にする。[19] に1項目足した。この項目は最初の修正のコミットに対しても落ちることを確かめた。置き場のディレクトリそのものが無いときは「無い」のままにした（そのときは tally-store が indeterminate を出す）。
- **採らない（低）: ts に改行を含む行や、ts が配列・オブジェクトの行で、件数が変更前と食い違う。** 変更前は `jq -r` が出した行を数えていたので1レコードを2件と数えていた。変更後はレコードの数で、こちらが正しい。判定（ok・broken）が変わる入力ではないので、戻さない。
- **採らない（低）: 当たったレコードを配列に持つのでメモリが増える。** ログは1行が小さく、件数も窓の外を含めて小さいので、変えない。

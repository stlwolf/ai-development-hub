---
id: "01KYA7C9M4EN1EZM3HBEN5WDRP"
type: knowledge
status: active
date: 2026-07-24
trigger: "bash で set -o pipefail 下、巨大な入力をパイプで流し、consumer 側が早期終了する（grep -q / head / awk の exit）とき"
prediction: "consumer の早期終了が producer に SIGPIPE を送り、pipefail が pipeline 全体を非 0 にする。その非 0 を失敗と解釈する分岐（if 条件 / コマンド置換 / exit 判定）が、正常なデータを異常（例: malformed）として誤分類する。小さい入力では producer が先に書き終わるので再現せず、巨大入力でのみ顕在化する"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-07-24-episode-273-nk-match-inject.md"
landing: nl
observations:
  - date: 2026-08-01
    ref: "#295"
    state: followed
    note: "検証に書いた printf | grep -q を bash 正規表現へ、手動手順の head を awk NR==1 へ置き換えた"
exclusions:
  - "入力が小さく、producer が consumer の早期終了より前に書き終わるケース（テストが緑でも本番の巨大入力で壊れる）"
  - "pipefail を使っていない、または早期終了する consumer がいないパイプ"
---

`set -o pipefail` と早期終了する consumer（`grep -q`・`head`・awk の `exit`）を組み合わせると、consumer がマッチ/先頭行を得た瞬間にパイプを閉じ、まだ書き続けている producer が SIGPIPE を受けて exit 141 になる。pipefail はこの 141 を pipeline の結果に昇格させるため、`if ! producer | consumer` や `x="$(producer | consumer)"` が「失敗」に見える。

非自明なのは**入力サイズ依存で再現性が変わる**点である。小さい fixture では producer が consumer の早期終了前に全部書き終えるので SIGPIPE が起きず、テストは緑になる。巨大な本番入力で初めて producer が途中で殺され、正常なデータが「壊れたデータ」に誤分類される。デバッグ時はデータの中身を疑いがちだが、原因はデータでなくパイプの制御フローにある。

次にどう行動を変えるか: 大きくなりうる入力を扱うパイプでは (1) consumer を早期終了させず**入力を最後まで読み切ってから END で結果を返す** awk にする、(2) パイプをやめて here-string / 一時ファイル経由で渡す、(3) その区間だけ pipefail を外す、のいずれかにする。「テストが緑だから安全」を入力サイズの上でだけ信じない。

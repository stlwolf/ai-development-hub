---
id: "01KZRTSJ2VP8BZR0MF7QZRNYH7"
type: knowledge
status: active
date: 2026-08-12
trigger: "exit code がどこで返るかを数えるとき。帯の整理、help への契約の記述、「この verb は N を返さない」「N はこの意味だけだ」という主張を書くとき"
prediction: "ファイル内の literal な exit N を grep して、見つからなければ「その経路は無い」と結論する。source した関数の return が `|| exit` で伝播する経路は grep に映らないので、実在する経路を無いと言ってしまう。grep 自体は成功するので、確かめた手応えだけは残る"
source:
  ref: "projects/orchestration-engine/docs/episodes/2026-08-12-episode-309-help-exit-remaining-verbs.md"
landing: nl
observations: []
exclusions:
  - "関数を source していない自己完結したスクリプト（伝播の経路が無い）"
  - "実際に叩いて exit code を観測した場合（grep を根拠にしていない）"
---

exit code を数える作業は grep で足りるように見える。**足りない。exit code はファイル内の文字列ではなく、実行経路の性質である。**

`oe-ack` について「本変更で exit 1 を返す経路が無くなる」と書いた。根拠は `grep -n 'exit 1' bin/oe-ack` が空だったことである。**誤りだった。** `oe-ack` は `PANE="$(oe_reg_resolve "$TARGET")" || exit` で宛先を解決しており、`oe_reg_resolve` は解決できないラベルと曖昧なラベルに `return 1` する。それが `|| exit` でそのまま伝播する。実測すると 1 が返る。

**grep に映らない形が少なくとも3つある。**

- source した関数の `return N` が `|| exit` や `|| exit "$rc"` で伝播する（今回踏んだ形）。
- `rc=$?` で受けてから変数経由で `exit "$rc"` する。
- `exec` で別のコマンドに置き換わり、その終了コードがそのまま自分の終了コードになる（同じリポジトリの `oe-kick` が `oe-delegate` をこう呼ぶ）。

**この失敗は「調べ足りない」とは別種である。** 調べてはいて、道具の射程を誤解している。だから手応えが残り、確かめた気になる。**しかも成果物に書くと、読み手には測定結果として届く。** 今回はコミット本文にまで入れてから、外部レビューの2レーンが独立に訂正した（1レーンは1回目の note で既に触れていたのに、こちらが読み落とした）。

次にどう行動を変えるか。(1) 「この verb は N を返さない」と書くなら、**grep ではなく実際に叩いて観測する**。異常系は副作用の前で短絡するので、たいてい安全に叩ける。(2) 叩けない経路（副作用が出る・環境を作れない）は、`source` している lib の `return` と `exec` の先まで辿る。**grep の対象をファイルではなく経路にする。** (3) 書けないなら「確かめていない」と書く。数え上げの主張は、根拠が grep なら grep と明示する。

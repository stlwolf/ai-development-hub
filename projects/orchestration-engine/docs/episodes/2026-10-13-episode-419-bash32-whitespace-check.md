---
id: "01M4SQHVPTAVQG8TMSEZ88DCTR"
title: "#419 knowledge の検証テストを bash 3.2 で最後まで通す（空白判定の置き換え）"
date: 2026-10-13
type: episode
status: in-development
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/419"
    reason: "本 episode の作業対象"
tags: [orchestration, knowledge, validate-knowledge, knowledge-list, bash32, performance]
---

# #419 knowledge の検証テストを bash 3.2 で最後まで通す（空白判定の置き換え）

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節にはその旨を冒頭に書く。

## この単位の入力

統括の brief（軽微修正4件の束の U1）。owner の承認（2026-10-13）により、plan・設計SO（ゲート2）・issue-intake は省く。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテストは省かない。

## 作業の記録

### brief と issue の断定を当て直した（2026-10-13）

- 置き換え対象の5か所（`validate-knowledge.sh` の 158・234・247・344 行、`knowledge-list.sh` の 240 行）は、master `a8e8726` の `git grep '//\[\[:space:\]\]'` で brief のとおり実在した。リポジトリ全体でこの書き方は5か所だけで、ほかの一致は episode-99 の本文（棄却案としての言及）だけだった。
- `${x//[...]/}` という置換の書き方は、ほかにも hooks・`oe-tree`・`oe-selfcheck`・`delegate-registry.sh`・`wt-pane-issue.sh` にある。どれも pane ID・argv0・キー名・1行分の capture のような短い文字列に対する置換で、長い文字列を受けない。同じ型（長い入力に対する空白判定）には当たらないと判断した。
- issue の実測表を手元で測り直した（`LC_ALL=ja_JP.UTF-8`・`key: あい ` と改行の繰り返しに置換を1回）。bash 3.2.57 で 3,249 バイトが 1.0 秒、6,499 バイトが 6.5 秒、bash 5.2.37 で 12,999 バイトが 0.14 秒、107,899 バイトが 9.5 秒だった。issue の表と合う。

### 置き換え先を正規表現でなく glob にした（2026-10-13）

issue は置き換え先の例として「空白以外の文字を1つでも含むかを正規表現で見る形」（`[[ "$x" =~ [^[:space:]] ]]`）を挙げていた。候補として、これと bash の glob（`[[ "$x" == *[![:space:]]* ]]`）を比べた。

判定の意味を、空・半角空白・タブ・改行・CR・VT・FF・NBSP・全角空白（U+3000）・EN SPACE・LINE SEPARATOR・NEL・ゼロ幅空白・BOM・記号・不正な UTF-8 の 26 通りで、元の置換と突き合わせた（bash 3.2 と 5、`ja_JP.UTF-8`・`en_US.UTF-8`・`C` の組み合わせ）。

- **glob は 26 通りすべてで元の置換と同じ判定になった。** glob も元の置換も bash 自身のパターン照合なので、文字クラスの解釈が同じになる。
- **正規表現は、不正な UTF-8 のバイトを含む文字列で判定が変わった。** UTF-8 のロケールでは、`a\xff` のように空白でない文字を含んでいても、不正なバイトが1つあると文字列全体が一致しなくなり、「空」と判定される。macOS の libc の正規表現が、不正なバイト列で照合そのものに失敗するためだと見ている（推測。返り値までは確かめていない）。`C` ロケールでは差は出なかった。

frontmatter に不正なバイトが1つ混じっただけで「empty frontmatter」と出るのは、判定の意味を変えないという issue の受け入れ基準に反する。そのため glob を採った。

速さは、判定1回だけを測って確かめた。glob は長さに比例して伸び、bash 3.2 でも 1,299,999 バイトで 0.031 秒、空白だけの 499,999 バイト（最後まで走査する最悪の形）で 0.080 秒だった。

棄却した選択肢: 正規表現（上の理由）。外部コマンド（`grep -q '[^[:space:]]'` など）はプロセスを起動する分だけ重く、grep もロケールと不正なバイトの扱いが bash と違いうるので、比べる前に外した。

### 変更前の master で、止まる場所が狙った行であることを確かめた（2026-10-13）

`/bin/bash`（3.2.57）で `test_validate_knowledge.sh` を上限 300 秒で回すと、開始 17 秒で [50] に入り、そのまま 300 秒で打ち切られた（exit 124）。bash 5.2.37 では 18 秒で最後まで通る（181 件・失敗 0）。

打ち切られたこと自体は、止まった理由の証拠にならない。そこで [50] と同じ fixture（108,119 バイト・frontmatter 中の空白は約 9,200 文字）を作り、変更前の `validate-knowledge.sh` を `PS4='+${LINENO}: ' /bin/bash -x` で 20 秒回した。最後に出た trace は 157 行（frontmatter を取り出す代入）で、158 行の `[[ -z "${fm//[[:space:]]/}" ]]` の展開が終わらないまま打ち切られた。止まっている bash を `sample` で見ると、スタックの先頭はほぼすべて `wcslen` で、ワイド文字列での照合をくり返していることと合う（bash 3.2 に記号情報が無いので、関数名までは追えていない）。

### 足した検査は、意味を保つための検査であって、変更前の master では落ちない（2026-10-13）

足した検査は `test_validate_knowledge.sh` の [51] と `test_knowledge_list.sh` の [33] である。空白は半角空白・タブ・全角空白を混ぜ、5か所それぞれで「空白だけなら空」「空白に囲まれた文字があれば空でない」を見る。frontmatter と本文には、不正な UTF-8 のバイトだけの値を「空でない」とする例を入れた。

この2つは、変更前の master のスクリプトに重ねても bash 5 で通る（194 件・130 件、失敗 0）。判定の意味を変えないための検査なので、それで正しい。negative knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ` に従い、受け入れの「変更前の master で落ちる」の錨には使わない。この単位の変更そのものに錨がある検査は、bash 3.2 で [50] が時間内に終わるかどうかである。

その代わり、検査が本当に効くことを、置き換え先を正規表現（`[[ ! "$x" =~ [^[:space:]] ]]`）に差し替えた写しで確かめた。5か所とも差し替わったことを grep で確かめたうえで回すと、`test_validate_knowledge.sh` は4件、`test_knowledge_list.sh` は2件落ち、落ちたのはすべて不正なバイトの例で、理由は「empty frontmatter block」「body prose is empty」「missing or empty frontmatter」が出たことだった。狙った理由で落ちている。trigger と source.ref の不正なバイトの例は、yq を通るので作っていない。

不正なバイトの例は、最初は「空の判定の文言が出ない」ことだけを見ていた。これだと出力が空でも通ってしまうので、変更後のスクリプトが実際に進む先（「malformed YAML frontmatter」）が出ることも確かめる形に締めた。

### 変更後に両系で通した（2026-10-13）

| テスト | bash 3.2.57 | bash 5.2.37 |
|---|---|---|
| `test_validate_knowledge.sh` | 17 秒・194 件・失敗 0 | 18 秒・194 件・失敗 0 |
| `test_knowledge_list.sh` | 8 秒・130 件・失敗 0 | 7 秒・130 件・失敗 0 |

`shellcheck` は変更した2本のスクリプトと2本のテストで警告 0。Write の際に制御バイトが紛れ込んでいないことを `grep -nP '[\x00-\x08\x0b-\x1f\x7f]'` で確かめた（テストの `\t` `\xff` は printf と awk が実行時に解釈する文字列のまま入っている）。

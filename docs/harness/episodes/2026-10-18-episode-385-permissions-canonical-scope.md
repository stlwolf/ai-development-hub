---
id: "01M57K6294A0RG3CK6R1TEH3WT"
title: "#385 許可規則を hub の正本に含めるかを決める（判定の材料と decision）"
date: 2026-10-18
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/385"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/385#issuecomment-6250392852"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）。この単位はこれを前提にする"
  - type: relates_to
    ref: "docs/harness/discussions/2026-10-18-discussion-385-permissions-canonical-scope.md"
    reason: "この単位の成果物の1つ目。owner が判定するための材料"
  - type: design_context
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の設定適用の設計。union-array を permissions.allow を想定して作り、permissions は宣言に入れないと書いた"
  - type: design_context
    ref: "docs/harness/episodes/2026-09-06-episode-359-settings-harness-layer.md"
    reason: "設定の5段の優先順位と、上位スコープの検査の文言を分けた経緯"
tags: [harness, settings, permissions, judgment-materials]
knowledge_observations:
  - "01M1VTJJFF1TK067ZX3X912G0P"
  - "01KZK26GQZ39WCFV5MYKQMRHWE"
  - "01KYMRE1NC7XX6N66RQ0MGGHF1"
  - "01M2DEC1G6GG9RTXGM6CRJEGZQ"
promotion:
  - subject: "本体の警告は `*` の位置しか見ず、末尾の `*` の広い規則は警告なしで残る"
    verdict: required
    ref: "本文: D1: 判定に効く事実が新しく2つ見つかった（2026-10-18）"
  - subject: "比べる基準の「見つけられる範囲」を、届く場所・見分ける精度・止める力に分ける"
    verdict: not-required
    ref: "本文: D2: ゲート1（ゼロベースの代替探索・Codex 1レーン）を回した（2026-10-18）"
  - subject: "ユーザー層に置く安全の仕組みは、リポジトリの設定が上書きでき、破れない境界ではない"
    verdict: required
    ref: "本文: D2: 設計SO（ゲート2・弱・Codex 1レーン）を回した（2026-10-18）"
  - subject: "Codex の PreToolUse hook は `\"ask\"` を返すと止まらずに動く"
    verdict: required
    ref: "本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）"
  - subject: "規則の一致を自前で真似ずに、`codex execpolicy check` に危ない形の一覧を当てる"
    verdict: not-required
    ref: "本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）"
  - subject: "推奨の表を decision の1行に縮めるとき、owner が決めた範囲を未決の範囲まで広げやすい"
    verdict: required
    ref: "本文: D4: ゲート4（decision への SO・弱・Codex 1レーン）の結果と採否（2026-10-19）"
  - subject: "#359 が permissions を外した理由は記録に無く、今回の理由を初めて書く"
    verdict: required
    ref: "本文: D1: #359 が permissions を宣言から外した理由を一次記録で探した（2026-10-18）"
  - subject: "allow は正本に置かず、危ない形は警告で知らせ、実行の直前の hook は別の issue で決める（owner の判定）"
    verdict: required
    ref: "本文: D4: owner の判定を decision に書いた（2026-10-19）"
---

# #385 許可規則を hub の正本に含めるかを決める

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

2026-09-10、hub の `.claude/settings.local.json` に、`*` が末尾でない位置にある Bash の許可規則が4件見つかり、owner が手で消した。Claude Code 本体が起動時にこの形を警告したのがきっかけである。許可規則は hub の正本の外にあり、`sync.sh --check` にも掛からないので、危ない形が入っても hub の仕組みでは見つからない。#385 は、許可規則を hub の正本の対象に含めるかを、本文の5つの論点について決める issue である。

## この単位の入力

- brief: 統括（cockpit 19代目）が 2026-10-18 に発行した `.oe/brief-385-permissions-canonical-scope.md`（作業層・消える）。この単位は実装をしない。最初の終端は D3（discussion を報告して止まる）、委譲全体の終端は D6（PR を作って報告する）。マージ・worktree の掃除・issue の close はしない。baseline は master `0287910`。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/385#issuecomment-6250392852 （深掘りなし）。
- scope: 5つの論点（層の切り分け・書き込みの衝突・検査だけ先に入れる案・別リポジトリへの届き方・本体の検査で足りるか）について、owner が判定できる材料を discussion に書く。比べる基準は確定版の［別モデル］1つ目（危ない形を見つけられる範囲・許可が意図せず広がる危険・運用と保守の手間）。コードと設定ファイルは変えない。hub の `.claude/settings.local.json` と `~/.claude/settings.json` は読むだけにする。公開の文書に別のリポジトリの名前や中身を書かない。
- SO: 設計 weak・実装 weak。discussion に Codex 1レーン（ゲート2）、decision に Codex 1レーン（ゲート4）と Copilot 1ラウンド。Codex が返らなければ Cursor のレーンに1回だけ切り替えてよい。ゼロベースの代替探索（ゲート1）は discussion の中で通す。
- 注入された negative knowledge: 4件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### D1: worktree・確定版の照合・宛先の確認（2026-10-18）

- worktree `docs/#385_permissions_canonical_scope` を `wt switch --create --base origin/master` で作った。起点は `0287910` で、`git fetch` のあとの `origin/master` と同じである。
- 認識合わせは `issue-intake` の 1-2 の手順で確かめた。最後の行は `confirmed`・見出し4つで、URL は brief の「認識合わせ:」欄と文字列として一致した。確定版を前提にし、自分では通し直さない。
- 報告の宛先の統括は `oe-tree` に root `cockpit` として生きて出ていた。委譲子の自分はその子として出ており、`$PARENT_TMUX_PANE` も同じ統括を指していた。
- 読んだもの: #385 の本文と確定版。#359 の plan と episode（permissions と `union-array` と優先順位の節）。PR #370・#372・#374 の本文とレビューのコメント。`canonical/claude/settings.harness.json`。`scripts/sync/apply-claude-settings.sh` と `check-claude-settings.sh`。`canonical/claude/settings-known-keys.txt`。Claude Code の公式の文書（permissions・settings・settings-reference・permission-modes・errors）と CHANGELOG。本体 2.1.302 のバイナリの文字列。Codex の execpolicy の README と Cursor CLI の permissions の文書。注入された knowledge item 4件。

### D1: #359 が permissions を宣言から外した理由を一次記録で探した（2026-10-18）

knowledge item `01KZK26GQZ39WCFV5MYKQMRHWE` の教訓に従い、外した判断の一次記録を読んでから「欠落」を扱う。

- #359 の plan は DJ-3 で「`union-array` を足したのは、`permissions.allow` のような配列を `replace` すると owner が足した項目が消え、`merge-object` では配列を表現できないためである。ただし `permissions` は今回の宣言には入れない。」と書いている。**外した理由は書かれていない。**
- 理由を、#359 の episode（`permission`・`allow`・`union`・`入れない` で全文を検索）、#359 の issue のコメント、PR #370・#372・#374 の本文とレビューのコメントで探した。どこにも書かれていない。「理由は記録されていない」は、この5か所を探した結果である。
- 記録から読める事情は2つある。1つ目は、#359 の issue が挙げたキーの一覧は `~/.claude/settings.json` に実在するキーで、そこに `permissions` は無かったこと（issue 本文の「他のキー」の列挙）。2つ目は、#359 の episode のゲート1 の指摘2が、hub の `.claude/settings.local.json` が `permissions` を持つことを「上位のファイルが同じキーを持てば効かない」例として挙げたこと。どちらも「入れない」の理由として書かれたものではないので、理由の推定として discussion に書くときは推測と明示する。

### D1: 上流の断定を一次情報に当てた（2026-10-18）

knowledge item `01KYMRE1NC7XX6N66RQ0MGGHF1` の教訓に従い、issue 本文と確定版の断定を、写す前に当てた。

- **「2.1.265 で許可規則の検査が入った」は、一次情報と合わない。** CHANGELOG の 2.1.246 に「Added a startup warning for Bash allow rules with a wildcard before the subcommand (e.g. `Bash(git * main)`)」があり、公式の errors のページも「Before v2.1.246, Claude Code accepted these rules without a warning.」と書いている。2.1.265 の CHANGELOG に許可規則の検査の項目は無い。npm の公開時刻は 2.1.246 が 2026-08-25、2.1.265 が 2026-09-08 で、owner が4件を消したのは 2026-09-10 である。2.1.265 は owner が警告を見たときに動いていた版だった可能性があるが、確かめていない。discussion では「警告は 2.1.246 から」と書き、issue 本文の版は誤りとして扱う。
- **「警告文は git を名指しで例に挙げている（`-c` や `--exec-path`）」は、一次情報と合う。** errors のページの警告文の例と、本体 2.1.302 のバイナリの文字列の両方に「For git, options such as -c and --exec-path can run arbitrary commands.」がある。
- **「宣言が持つのは hooks と statusLine の2項目だけ」は古い**（確定版がすでに直している）。`settings.harness.json` の items は `/hooks`・`/statusLine`・`/disableAgentView`・`/idleCompaction` の4つである。
- **確定版の「allow 125 件（Bash 108 件）・`*` が末尾でない Bash 規則は0件・ユーザー層に permissions は無い」は、いまも合う**（2026-10-18 22時台に数えた）。種類の内訳は Bash 108・Read 10・WebFetch 6・WebSearch 1 である。
- **issue 本文の「削除前の allow は 129 件・Bash 112 件」は確かめられなかった。** 本文が書くバックアップ `.claude/settings.local.json.bak.*` は、いま `.claude/` に無い。
- **確定版の「#359 で `union-array` を `permissions.allow` を想定して作り、apply と check の両方が実装済み」は合う。** apply は手元の配列に無い項目を後ろに足すだけで、手元の項目は消さない（`apply-claude-settings.sh` の `union-array` の分岐）。check は正本の項目がすべて手元に含まれているかだけを見る（`check-claude-settings.sh` の `union-array` の判定）。

### D1: 判定に効く事実が新しく2つ見つかった（2026-10-18）

上流が挙げていない事実で、5つの論点の判定に効くものが2つあった。

1. **本体の警告が出ない形に、同じくらい広い規則が hub に残っている。** hub の allow の Bash 規則 108 件のうち 30 件は末尾が `*` の前方一致で、その中に `Bash(git:*)`・`Bash(curl:*)`・`Bash(gh api:*)`・`Bash(python3:*)`・`Bash(bash -c ':*)` がある。公式の permissions のページは「Claude Code matches everything before the first `*` as written」「`Bash(git *)` allows every git command」「The `:*` suffix is an equivalent way to write a trailing wildcard」と書き、`-c` で git が任意のプログラムを動かす例を同じ節に載せている。この3つの文を合わせると、`Bash(git:*)` は 2.1.246 の警告が問題にしている `git -c …` も通し、`*` が末尾にあるので警告は出ない。これは文書の読みで、実機で `git -c` を通して試してはいない。本体 2.1.302 の `/doctor` の指示文も、末尾の `*` は「prefix STRING matches with NO flag-level analysis」で、`curl`・`gh api`・インタプリタ・`git fetch` は許可リストに入れるなと書いている。
2. **owner は auto モードで動かしているので、allow 規則は判定器を飛ばす。** 公式の permission-modes のページは、auto モードの判定の順序の1番目を「allow・ask・deny の規則に当たるものは即座に決まる」としている。auto モードに入るときに外される広い規則は `Bash(*)`・`Bash(python*)` のようなインタプリタ・パッケージマネージャの run・`Agent`・`Monitor` だけで、`Bash(git:*)` や `Bash(curl:*)` が外されるかは文書に書かれていない。

昇格の印: 本体の警告は `*` の位置しか見ないので、末尾の `*` で同じくらい広い規則（`Bash(git:*)` など）は警告なしで残る。「本体が検査している」は「危ない規則が無い」を意味しない

- この機種の `~/work/repos` の下には `.claude/settings.local.json` が9つあり（hub を含む）、allow は合わせて 202 件だった。`*` が末尾でない Bash 規則は hub の外の1件（1ファイル）で、いまも残っている。`git`・`curl`・`python3`・`gh api` などの前方一致の広い規則は 8 件（5ファイル）だった。名前は公開の文書に書かない。数え方は master の作業層 `tmp/385-permissions-canonical-scope/count-local-allow.sh`（gitignored）に残した。このコマンドはリポジトリの名前を出さない。取得した公式の文書・CHANGELOG・npm の公開時刻も同じ場所の `src/` に置いた。
- hub の `.claude/settings.local.json` の更新時刻は 2026-09-10 22:15 で、それから5週間書き足されていない。auto モードでは「Yes, and don't ask again」の確認がほとんど出ないためと考えられるが、推測である。

備考として残す（この単位の範囲の外）: hub の `.claude/settings.local.json` は top-level に `defaultMode: "auto"` を持つが、公式のキーは `permissions.defaultMode` で、しかも settings-reference は「`auto` and `bypassPermissions` don't take effect from project or local settings」と書いている。この値は効いていない可能性が高い。owner の設定を直すかどうかはこの単位では決めず、報告で知らせる。

### D2: discussion の草稿を書いた（2026-10-18）

- discussion に、比べる基準（K1〜K3）、本体の仕様の表（Claude Code の C1〜C21、Codex と Cursor の X1〜X4）、いまの状態、#359 の判断の読み直し、論点ごとの選択肢と仮の推奨を書いた。
- **hub の allow の分け方**: Bash 規則 108 件を、規則の文字列が `./`・`/Users/`・`ai-development-hub`・`projects/`・`scripts/`・`tests/`・`canonical/`・`docs/`・`tmp/`・`.oe/` のどれかを含むかで分けた。含むものを「このリポジトリ限り」（55 件）、含まないもののうち末尾が `*` のものを「どこでも同じ形の前方一致」（24 件）、残りを「どこでも同じ形の1回きりのコマンド」（29 件）とした。パスの印による機械的な分け方なので、境目の数件は入れ替わりうる。コマンドは master の作業層の `hub-allow-2026-10-18.txt` に当てた awk である。
- **論点1 の推奨（allow を配らない）は、数で決めた。** issue は「どのリポジトリでも同じもの」の例に `gh` の読み取りの類を挙げていたが、hub の実物を分けると、どこでも同じ形の前方一致 24 件のうち読み取りだけは3件（`ls`・`wt list`・`wez discover`）で、`ls` は本体が最初から通す。issue の例のとおりの層は、実物の中にほとんど無かった。
- **論点4 で、規則のファイルではなく実行時のコマンドを見る案（PreToolUse hook）を本命に置いた。** 公式の文書で「exit 2 の hook は allow 規則より先に効く」を確かめ、hub がすでに PreToolUse 系の hook を3ツールへ配っていることを `canonical/hooks/*.hooks.json` で確かめたためである。この案は issue の論点の言葉（「規則を正本に含めるか」）の外にある。issue 自体が論点4で「別の経路が要る」と書いているので範囲の中と判断したが、実装は別の issue にする推奨にした。
- **論点3 の検査を警告にとどめる推奨は、#359 の HG-D（drift は報告だけ）と綴りの検査の先例に揃えた。** 赤にすると、owner が規則を直すまで `--check` が赤のままになるためである。

### D2: ゲート1（ゼロベースの代替探索・Codex 1レーン）を回した（2026-10-18）

- `so-compare --codex-only` に、論点ごとの初期案と暗黙の前提を並べ、`so-compare` のスキルの「選択肢拡張」の節をそのまま入れて問うた。依頼文は master の作業層 `tmp/385-permissions-canonical-scope/so-gate1-prompt.md`、出力は同じ場所の `so-gate1/` である。上限は `SO_TIMEOUT=480`（レビュー級のため）。
- 返したのは Codex（`gpt-6.1-sol`・`model_resolved_source=config`・codex-cli 0.163.0）で、131 秒・初回で返った（`timeout_status=success`・9540 バイト）。Cursor には切り替えていない。
- **新しい種類の代替が3つ出た。** sandbox で実行主体の権限を絞る案、汎用のシェルの代わりに専用の操作口を作る案、期待する振る舞いのケース集を正本にして本体の判定を試す案である。初期案は対処の対象を「規則のファイル」か「実行時のコマンド」の2つに決めていたが、3つ目の対象（実行主体の権限）と、正本を「設定の値」でなく「期待する振る舞い」にする見方が抜けていた。採否は discussion の7節に書いた。sandbox は 5E として足して採らず、専用の操作口は採らず、ケース集は一部を採った。
- **言い過ぎの指摘が9件あり、根拠に当てるとすべて成り立った。** いちばん効いたのは2つである。1つ目は、論点1 の「数字の上で成り立たない」が、いまの 24 件をそのまま移す案への反対の根拠でしかなく、選び直した共通の allow の不成立までは示していなかったこと。2つ目は、論点4 で hook を「置き場所と関係なく効く唯一の案」と書いたが、C3（どの段の deny も別の段の allow より先に効く）を自分で表に書いていながら、ユーザー層の deny・ask も同じ性質を持つことを見落としていたこと。knowledge item `01M2DEC1G6GG9RTXGM6CRJEGZQ` の予測（引用した文書が答えている性質を、当て直さずに自分の言葉で断定する）の、自分で作った表の版である。
- K1 を「届く場所・見分ける精度・止める力」に分けた。分けないと、どこでも動く hook が、よく見分ける案と同じに評価されていた。

昇格の印: 比べる基準の「見つけられる範囲」は、届く場所・見分ける精度・止める力に分けないと、広く動く仕組みが高く評価されやすい

### D2: ゲート1 の代替3 を受けて、未検証の前提をその場で試した（2026-10-18）

- 仮の推奨は、確かめていない前提2つに立っていた。`Bash(git:*)` が `git -c …` を通すか（C12）と、hook の `"ask"` が当たる allow 規則より先に効くか（C19）である。代替3 は「将来の隔離した環境で試す」と提案していたが、設定ファイルを変えずに試せたので、その場で試した。
- 方法: scratchpad に使い捨てのリポジトリを作り、`claude -p --model haiku --setting-sources project --permission-mode dontAsk --tools Bash --settings '<その場の JSON>'` を6回回した。ユーザー層と手元の層の設定は読ませていない。dontAsk は確認が要るものを自動で拒否するので、確認が出るかどうかを拒否の有無と commit の数で観測した。任意のプログラムを動かす `-c` は使わず、`-c user.name=t` のような無害な設定だけを使った。
- 結果: allow が無ければ拒否（T0・対照）、`Bash(git:*)` があれば確認なしで commit が増えた（T1）、同じ allow に `"ask"` を返す hook を足すと拒否（T2）。起動時の警告は `Bash(git * main)` には出て（T3・陽性の対照）、`Bash(git:*)` と `Bash(git *)` には出なかった（T4・T5）。本体 2.1.302・`claude-haiku-5-5`。記録は master の作業層 `tmp/385-permissions-canonical-scope/perm-test/` にある。
- これで C12 と C19 を [measured] にした。論点4 の推奨は「hook の `"ask"` が allow より先に効くかは文書が言い切っていない」という留保を外せた。
- `claude -p` を6回呼んだのは、brief の「コードや設定ファイルは変えない」の範囲の中と判断した。変えたのは scratchpad の使い捨てのリポジトリだけで、hub と owner の設定には触れていない。

### D2: 設計SO（ゲート2・弱・Codex 1レーン）を回した（2026-10-18）

- ゲート1 の採否を反映した discussion に対して、`so-compare --codex-only` で8点（基準の当て方・論点ごとの推奨の根拠・判定の欄の立て方・抜け）を問うた。依頼文は master の作業層 `tmp/385-permissions-canonical-scope/so-gate2-prompt.md`、出力は同じ場所の `so-gate2/` である。上限は `SO_TIMEOUT=480`。
- 返したのは Codex（`gpt-6.1-sol`・`model_resolved_source=config`・codex-cli 0.163.0）で、123 秒・初回で返った（`timeout_status=success`・10185 バイト）。Cursor には切り替えていない。Codex は errors のページを取得できず、C8〜C10 を独立に確かめ直してはいないと書いている。
- 結論は「直してから出す」で、指摘は8件（高2・中6）。根拠を一次情報に当て、8件とも採った。表は discussion の8節にある。
- **高の1件目は、ゲート1 で直した同じ文をもう一度突いた。** ゲート1 の指摘2で「消し合わない」を「窓はいまもあり、配っても増減しない」に直したが、その直しでも「1B なら許可規則の取り合いは起きない」という見出しの断定は残っていた。apply は宣言した項目だけを計算で変えるが、ファイル全体を置き換えるので、owner の手の編集が窓に入れば失われうる。「変える項目」と「書き込む範囲」を混ぜていた。直しを当てた文の周りに、同じ判断をする別の文（見出しの断定）が残っていないかを、直したその場で探し直していなかった。
- **高の2件目は、Claude Code で確かめたことを3ツールに広げていた。** 4B の欄に「hub はすでに3ツールへ hook を配っている」と書き、Claude Code の C18・C19 の性質がほかの2ツールでも成り立つように読める形にしていた。knowledge item `01M1VTJJFF1TK067ZX3X912G0P` を論点5 には当てていたのに、論点4 には当てていなかった。
- **指摘6 を一次情報に当てると、指摘より強い事実が出た。** hooks の文書と permissions の文書に、`disableAllHooks` は優先順位どおりに決まり、リポジトリの設定がユーザー層の値を上書きできるとある。sandbox の文書にも、`autoAllowBashIfSandboxed` はリポジトリのファイルから変えられるとある。ユーザー層に置く仕組みはどれも、リポジトリ側の設定が逆らえば破れる。C24・C25 を足し、論点4 に「効く」の条件と、どの案も破れない境界ではないことを書いた。

昇格の印: ユーザー層の hook と sandbox の設定は、リポジトリの設定（`disableAllHooks`・`autoAllowBashIfSandboxed`）が上書きできる。ユーザー層に置く安全の仕組みは、通常の運用で確認を増やすものであって、破れない境界ではない

- 判定の欄（9節）を、要るかどうか・範囲・方式・いまやるか・当面受け入れる危険の7問に分けた。2B に、知らせて手で消す 2B' を並べた。
- 2回目の設計SO は回さない。弱 SO は1周で終えてよく、8件はすべて文書の中で直せる指摘で、新しい種類の案は出ていない（ゲート1 で出た3つに位置を与えたあと）。

### D3: commit・push して統括へ報告し、止まった（2026-10-18）

- discussion と episode を `1c8cd3f` として commit し、`docs/#385_permissions_canonical_scope` を push した。PR はまだ作っていない。
- 統括が `oe-tree` に root `cockpit` として生きて出ていることを確かめてから、`projects/orchestration-engine/bin/oe-send` で discussion のパスを1行送った。exit 0 だった。
- ここで止まる。owner の判定が統括から届くまで decision に進まない。

### 追補 brief を受けた（2026-10-19）

- 統括から追補 `.oe/brief-385-r1.md`（作業層）が届いた。owner の判定は8件すべて推奨どおりで、owner の判断で Codex もこの判定に含めることになった。D3 のあとに C1（Codex の状態を discussion に足す）と C2（Codex で `block-force-push.sh` が許可規則に当たった `git push --force` を止めるかを試す）を挟み、元の D4〜D6 に戻る。終端は元のとおり D6 である。実装の issue は #460（`sync --check` の警告・Claude Code と Codex）と #461（実行の直前の hook・3ツール）。
- 指示矛盾ガードに照らした。終端は変わらず、未達の step を飛ばす指示でも、要件を弱める指示でもない。step を足す指示なので、そのまま従った。
- Q8 の `defaultMode` の削除は統括が実施済みで、master の作業層のバックアップと比べて差分がこの1キーだけであることを確かめた（allow は 125 件のまま）。

### C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）

- 統括が確かめた事実を、すべて自分で取り直した。セッションの記録の `turn_context`（10月17〜18日の 66 件）、`default.rules` の形（32件・すべて allow・広いのは2語の git の4件）、`codex execpolicy check` の判定（統括の8件と同じ結果）、`hooks.json` の symlink と `[features] hooks = true`。
- 統括が届かなかったという公式の文書は、`https://developers.openai.com/codex/hooks.md` と `/rules.md` で取れた。判定に効く記述が3つあった。allow は「sandbox の外で確認なしに動かす」意味であること。TUI の承認は allow をユーザー層の `default.rules` に書くこと。PreToolUse の `"ask"` は対応しておらず、返すと hook の失敗として扱われてコマンドはそのまま続くこと。
- **3つ目は #461 の前提を変える。** Claude Code では `"ask"` が allow より先に効くことを T2 で確かめたが、Codex で同じ作りの hook を配ると、確認に回したつもりの形が素通りする。Codex で止められるのは deny（exit 2）だけである。
- `codex exec --help` の `--dangerously-bypass-hook-trust` から、Codex の hook には信頼の仕組みがあると分かった。公式の文書と `openai/codex` の main のソースで、信頼は hook の定義の hash に記録され、定義を変えると信頼し直すまで飛ばされることを確かめた。hash にスクリプトの中身は入らない（ソースの読み・手元の版は未確認）。`config.toml` には、いまの `hooks.json` に無い `permission_request` の信頼の項目も残っていた。
- 論点1〜5 に「Codex」の段落を足し、論点5 の結論を「Claude Code についても Codex についても足りない」にした。論点2 には、狭める側を配るなら `default.rules` と別のファイルを同じ `rules/` に置けば取り合わないことを足し、`codex execpolicy check` に2つのファイルを渡して、厳しい方が勝つことと、オプションを後ろに書いた形は取りこぼすことを確かめた。
- 確かめる途中で、自分の Claude Code の `block-force-push.sh` が、`codex execpolicy check -- bash -lc '<force push の文字列>'` を止めた。判定だけのコマンドだが、hook は `bash -lc` の中身を読んで強制 push と判断した。hook の拒否には従い、文字列を別の形にして通すことはしなかった。その判定（`bash -lc` の中身を Codex が分けて規則に当てるか）は取っていない。同じ仕組みの確かめは、強制 push の文字列を含まない `git rebase -i` の規則で行った。

昇格の印: Codex の PreToolUse hook は `"ask"` を返すと止まらずに動く（失敗として扱われ続行する）。Claude Code と同じ作りの hook を Codex に配ると、確認に回したつもりの形が素通りする

昇格の印: 規則の一致を自前で真似ずに、本体の判定の道具（`codex execpolicy check`）に危ない形の一覧を当てると、本体の一致のしかたの変化に追従できる

### C2: Codex で block-force-push.sh が allow に当たった git push --force を止めるかを試した（2026-10-19）

- scratchpad に使い捨てのリポジトリを作り、その中に bare リポジトリを置いて origin にした。A を push したあとローカルを A2 に amend し、各回の前に push 先の main を A に戻した。本物のリポジトリと GitHub には触れていない。
- `codex exec -C <使い捨て> -s workspace-write --ephemeral --json` を、ユーザー層の設定を読む形で3回回した。hook の記録先は `HOOK_FIRING_DIR` で試験の場所に向けた。この環境変数が hook まで届くことは、記録が試験の場所に出て owner の記録が増えなかったことで確かめた。
- 結果: R1（hook 有効・`git push --force`）は push 先が動かず、`block-force-push` の deny が1件記録され、Codex の stderr に「Command blocked by PreToolUse hook」が出た。R2（hook 有効・`--force-with-lease`）は push 先が動き、allow が1件記録された。R3（`--disable hooks`・`git push --force`）は push 先が動き、記録は無かった。R1 と R3 の差は hook の有無だけなので、R1 で止めたのは hook の deny である。記録は master の作業層 `tmp/385-permissions-canonical-scope/codex-test/` にある。
- **R1 のモデルの返答は、止めた仕組みを取り違えていた。** 「Automatic approval review blocked …」と書いたが、stderr の記録は PreToolUse hook が止めたとしている。brief がモデルの言葉で判定しないよう指示していたのが効いた。
- 試したのは `codex exec` だけで、承認の設定は指定していない（記録に残る `codex exec` の62件はすべて `never` だった）。対話のセッション（`on-request`）では試していない。`+main` のような別の書き方の強制 push と、allow に当たるほかの形を hub の hook が止めるかも試していない。どれも #461 で決めることとして discussion の11節に残した。

### C1・C2 の差分に設計SO（弱・Codex 1レーン）を当てた（2026-10-19）

- 依頼文は master の作業層 `tmp/385-permissions-canonical-scope/so-c12-prompt.md`、出力は `so-c12/`。Codex（`gpt-6.1-sol`・codex-cli 0.163.0）が 163 秒・初回で返った。Cursor には切り替えていない。
- 結論は「直してから進む」で、指摘は7件（高1・中6）。7件とも採った。表は discussion の 8.1 節にある。
- **高の1件は、自分の書いた利点がそのまま誤りだった。** `codex execpolicy check` に危ない形の一覧を当てる案を「Codex 自身の一致のしかたをそのまま使うので、`bash -lc` の分け方を hub に写さずに済む」と書いたが、この道具は渡された引数の並びを当てるだけで、`bash -lc` を分けない。手元で `bash -lc 'git rebase -i HEAD~3'` を当てると、どの規則にも当たらなかった。直前に「強制 push の文字列を含む `bash -lc` の判定」を hook に止められて取らなかったので、`bash -lc` を通す道具の振る舞いを確かめないまま、文書の X7（実行のときの分け方）を道具にも当てはめていた。knowledge item `01M2DEC1G6GG9RTXGM6CRJEGZQ` の予測（引用した文書が答えている性質を、当て直さずに別のものの性質として書く）の実例である。
- 中の4件目（信頼は項目ごと）は、自分でソースを読んで `hook_hash` が handler ごとだと見ていたのに、論点4 では「`hooks.json` を変えると信頼が外れる」とまとめて書いていた。読んだ細かさを、まとめの文で落としていた。
- 中の6件目（`write_stdin` の例外）は、自分で取った公式の文書の「Tool coverage」に書かれていたが、X11 の要約で落としていた。
- 7件を直したので、2回目の設計SO は回さない。新しい種類の案は出ていない。

### D4: owner の判定を decision に書いた（2026-10-19）

- `docs/harness/decisions/` を作り、decision を置いた。ファイル名の日付は brief の指定どおり 2026-10-18、frontmatter の `date` は書いた日の 2026-10-19 にした。
- 判定は統括からの送信（追補 brief）で届いたものだけを数えた。owner の8件はすべて推奨どおりで、Codex を含めることはそのあとに owner が決めた。
- 受け入れ基準の「正本に含めるなら対象の範囲と適用の形」には、「許可規則そのものは正本に含めない。正本に加わるのは #460 の検査と #461 の hook で、どちらも hub がいま持つ経路に載せる」と答えた。
- **#461 の題（「確認へ回す hook」）と、Codex の hook が `"ask"` に対応していないことが食い違う。** issue の題を直すのは統括と owner の仕事なので、decision の結果の節で申し送り、報告でも知らせる。
- ゲート4 として decision に `so-compare --codex-only` を当てた。依頼文は master の作業層 `tmp/385-permissions-canonical-scope/so-decision-prompt.md`、出力は `so-decision/`。

### D4: ゲート4（decision への SO・弱・Codex 1レーン）の結果と採否（2026-10-19）

- Codex（`gpt-6.1-sol`・codex-cli 0.163.0）が 63 秒・初回で返った。Cursor には切り替えていない。結論は「直してから着地する」で、指摘は6件（高1・中4・低1）。6件とも採った。
- **高の1件は、owner が決めていないことを決めたように書いていた。** 「正本に含めるもの」の段落で「許可規則そのもの（allow・ask・deny・Codex の `prefix_rule`）は、どれも正本に含めない」と書いた。owner の判定 Q1 が外したのは allow だけで、Q6 は狭める側を将来配る場合の外し方を決めたにすぎない。狭める側を含めるかは決まっていない、と分けて書き直した。discussion の推奨の表（1B）を、決定の1行に縮めるときに範囲を広げていた。
- 中の4件: #461 は方向だけで採否と作りは #461 で決めることを決定5 と結果に書いた。C2 の試験が示さないこと（allow が要ったか・sandbox の外で動いたか）を decision にも書いた。Codex の hook の信頼が項目ごとだという読みに、ソースの版が手元と違う留保を付けた。auto モードの読み取りの扱いに、サーバー側の判定の例外を残した。
- 低の1件: 決定8 から作業層のバックアップのパスを外し、「消す前の写しと比べて、変わったのはこの1キーだけ」とだけ書いた。
- 6件を直したので、2回目は回さない。

昇格の印: 推奨の表を decision の1行に縮めるとき、owner が決めた範囲（allow だけ）を、隣にある未決の範囲（狭める側）まで広げて書きやすい。決定の文は判定の原文に当て直してから書く

### D5: PR を作り、Copilot に1ラウンド依頼した（2026-10-19）

- PR #462 を作った（本文は `Refs #385`）。master は `0287910` から動いておらず、rebase は要らなかった。
- `gh pr edit 462 --add-reviewer @copilot` で依頼した。`requested_reviewers` は空のままだったが、timeline に `review_requested Copilot` と `copilot_work_started` が出たので、依頼は登録されていた。
- Copilot の結論は「Approval recommended」で、指摘は1件だった。discussion の X7 の行で、インラインコードの中の `|` が表の列の区切りになって行が分断されていた。`\|` にエスケープし（`3707a6e`）、返信した。同じ形がほかの表の行に無いことは、3つの文書と新しい knowledge item 2件の表の行を走査して確かめた。未返信は0件。
- closure は、owner の過去の指摘（closure は PR のレビューのあと・マージの前）に従い、Copilot の1ラウンドのあとに入れる。brief の D5 は「episode を閉じ、PR を作り、Copilot」の順に書いているが、どれも同じ step の中でマージの前に終わるので、終端は変わらない。
- 収穫した knowledge item は2件（`01M57SY06E1870RP6NQEXEF532`・`01M57SY07J7C076F3765J55PEH`）で、注入された4件には観測を1件ずつ足した。どちらも `validate-knowledge` を通した。

## closure（2026-10-19）

### tier

heavy。品質ゲートとして `so-compare` を4回明示して回した。撤回と直しが何度もあった（ゲート1 の9件・ゲート2 の8件・Codex の節の7件・ゲート4 の6件）。選択肢を比べて棄却した設計判断と、decision への昇格がある。

### closure gate

- **なぜ**: 冒頭の「なぜこの作業が始まったか」が自己完結している。
- **次の消費者**: (1) #460（`sync --check` の警告）の担当。判定と検査の形は decision、Codex の判定の道具の限界は discussion の論点3 を読む。(2) #461（実行の直前の hook）の担当。Codex の `"ask"` が非対応であること・信頼の仕組み・`write_stdin` の例外・試していない形は decision の結果の節と discussion の 3.4・3.5 節を読む。(3) 許可規則の扱いを見直す人。#359 で理由が書かれなかった判断の理由は decision にある。
- **follow-up routing**: 下の「残課題」にすべて行き先を付けた。
- **昇格の判定**: 下の「昇格の判定」に1件ずつ書いた（frontmatter の `promotion` と同じ要約）。
- **status**: episode・discussion・decision を `stable` にした。達成度は達成。
- **evidence anchor**: 本文は master の作業層（`tmp/385-permissions-canonical-scope/`）を参照しているが、試験の条件と結果（T0〜T5・R1〜R3）、SO の結論と指摘の表、数えた件数は discussion と本文に書き写した。作業層が消えても判定の根拠は残る。
- **SO 証跡**: ゲート1 `so-gate1/`・ゲート2 `so-gate2/`・Codex の節 `so-c12/`・ゲート4 `so-decision/`（いずれも master の作業層）。要約と採否は discussion の7・8・8.1 節と本文にある。
- **観測の書き戻し**: 注入された4件（`01M1VTJJFF1TK067ZX3X912G0P`・`01KZK26GQZ39WCFV5MYKQMRHWE`・`01KYMRE1NC7XX6N66RQ0MGGHF1`・`01M2DEC1G6GG9RTXGM6CRJEGZQ`）に1件ずつ足した（下の「注入された knowledge の観測」）。
- **認識合わせの抜け**: Codex を含めることは、確定版に無かったが、抜けではなく owner が後から範囲を足したものである（`本文: 追補 brief を受けた（2026-10-19）`）。hub の設定が3ツールに配られることは `CLAUDE.md` に書かれているので、文脈の置き場に足す記録は要らないと判断した。

### 事実・失敗

- 上流の断定のうち、警告が入った版（2.1.265 ではなく 2.1.246）が誤っていた。`本文: D1: 上流の断定を一次情報に当てた（2026-10-18）`
- 自分の表に書いた事実（C3）を使わずに、hook を「唯一の案」と書いた。ゲート1 が見つけた。`本文: D2: ゲート1（ゼロベースの代替探索・Codex 1レーン）を回した（2026-10-18）`
- 直した文の周りに、同じ判断をする見出しの断定（「1B なら取り合いは起きない」）が残り、ゲート2 がもう一度突いた。Claude Code で確かめた hook の性質を3ツールに広げていた。`本文: D2: 設計SO（ゲート2・弱・Codex 1レーン）を回した（2026-10-18）`
- 自分の Claude Code の `block-force-push.sh` が、判定だけのコマンドを止めた。拒否には従い、回避はしなかった。`本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）`
- Codex の文書の性質（実行時の `bash -lc` の分け方）を判定の道具の性質として書き、読んだソースの細かさ（信頼は項目ごと）と文書の例外（`write_stdin`）をまとめの文で落とした。`本文: C1・C2 の差分に設計SO（弱・Codex 1レーン）を当てた（2026-10-19）`
- decision で、owner が決めていない範囲（狭める側の規則）を決めたように書き、#461 の方向を採否まで決めたように書いた。`本文: D4: ゲート4（decision への SO・弱・Codex 1レーン）の結果と採否（2026-10-19）`
- R1 でモデルの返答が止めた仕組みを取り違えた。判定は ref と hook の記録と stderr で行ったので、結論には響かなかった。`本文: C2: Codex で block-force-push.sh が allow に当たった git push --force を止めるかを試した（2026-10-19）`
- Copilot の指摘は表の Markdown の1件だった。`本文: D5: PR を作り、Copilot に1ラウンド依頼した（2026-10-19）`

### 決定と根拠

- 判定と理由・棄却した案は decision と discussion の6節にある。`本文: D4: owner の判定を decision に書いた（2026-10-19）`
- 未検証の前提2つを、提案どおり「将来の隔離環境」に回さず、設定ファイルを変えずにその場で試した。`本文: D2: ゲート1 の代替3 を受けて、未検証の前提をその場で試した（2026-10-18）`

### わかったこと

- Claude Code の `Bash(git:*)` は `git -c …` を確認なしで通し、警告も出ない。hook の `"ask"` は allow より先に効く。`本文: D2: ゲート1 の代替3 を受けて、未検証の前提をその場で試した（2026-10-18）`
- Codex の allow は sandbox の外で確認なしに動き、永続の承認はユーザー層に書かれる。PreToolUse の `"ask"` は対応しておらず続行する。hook の信頼は定義の hash に記録される。`本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）`
- Codex でも、allow の規則に当たる `git push --force` を hub の hook の deny が止める。`本文: C2: Codex で block-force-push.sh が allow に当たった git push --force を止めるかを試した（2026-10-19）`

### 原則

- Codex に配る hook は、止めたい形を deny か exit 2 で返す（knowledge item `01M57SY06E1870RP6NQEXEF532` に収穫）。`本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）`
- decision の決定の文は owner の判定の原文に1文ずつ当て直す（knowledge item `01M57SY07J7C076F3765J55PEH` に収穫）。`本文: D4: ゲート4（decision への SO・弱・Codex 1レーン）の結果と採否（2026-10-19）`

### 昇格の判定

| # | 判断（`promotion.subject` と同じ） | 判定 | 理由と材料 |
|---|---|---|---|
| 1 | 本体の警告は `*` の位置しか見ず、末尾の `*` の広い規則は警告なしで残る | required | decision の根拠に入れた（この PR）。Q3（前提が将来偽になりうる: 本体が警告を広げれば変わる）と Q4（許可規則を扱う人が同じ分岐に立つ）に当たる。`本文: D1: 判定に効く事実が新しく2つ見つかった（2026-10-18）` |
| 2 | 比べる基準の「見つけられる範囲」を、届く場所・見分ける精度・止める力に分ける | not-required | この判定の材料の作り方で、discussion の2節に書いてあれば足りる。失敗の型ではないので knowledge の収穫基準（再発しうる失敗）にも当たらない。`本文: D2: ゲート1（ゼロベースの代替探索・Codex 1レーン）を回した（2026-10-18）` |
| 3 | ユーザー層に置く安全の仕組みは、リポジトリの設定が上書きでき、破れない境界ではない | required | decision の結果の節で #461 に申し送った（この PR）。#461 で hook を決めるとき、どこまでを守りと呼ぶかの分岐に立つ。`本文: D2: 設計SO（ゲート2・弱・Codex 1レーン）を回した（2026-10-18）` |
| 4 | Codex の PreToolUse hook は `"ask"` を返すと止まらずに動く | required | decision の結果の節に申し送り、knowledge item `01M57SY06E1870RP6NQEXEF532` に収穫した（この PR）。`本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）` |
| 5 | 規則の一致を自前で真似ずに、`codex execpolicy check` に危ない形の一覧を当てる | not-required | 実装の形の選択肢で、決めるのは #460 である。道具が `bash -lc` を分けない限界は discussion の論点3 と decision の結果の節に書いた。`本文: C1: Codex の状態を確かめ直して discussion に足した（2026-10-19）` |
| 6 | 推奨の表を decision の1行に縮めるとき、owner が決めた範囲を未決の範囲まで広げやすい | required | knowledge item `01M57SY07J7C076F3765J55PEH` に収穫した（この PR）。`本文: D4: ゲート4（decision への SO・弱・Codex 1レーン）の結果と採否（2026-10-19）` |
| 7 | #359 が permissions を外した理由は記録に無く、今回の理由を初めて書く | required | decision の根拠に入れた（この PR）。`本文: D1: #359 が permissions を宣言から外した理由を一次記録で探した（2026-10-18）` |
| 8 | allow は正本に置かず、危ない形は警告で知らせ、実行の直前の hook は別の issue で決める（owner の判定） | required | decision そのもの（この PR）。棄却した案は discussion の6節。`本文: D4: owner の判定を decision に書いた（2026-10-19）` |

### 注入された knowledge の観測

注入された item は `01M1VTJJFF1TK067ZX3X912G0P`・`01KZK26GQZ39WCFV5MYKQMRHWE`・`01KYMRE1NC7XX6N66RQ0MGGHF1`・`01M2DEC1G6GG9RTXGM6CRJEGZQ` の4件で、4件とも `ref: "#385"` の観測を1件ずつ足した。

- `01M1VTJJFF1TK067ZX3X912G0P`: externally_verified。論点5 では3ツールに当てたが、論点4 では Claude Code の性質を3ツールに広げ、ゲート2 が突き、Codex の文書で違いが確かめられた。`本文: D2: 設計SO（ゲート2・弱・Codex 1レーン）を回した（2026-10-18）`
- `01KZK26GQZ39WCFV5MYKQMRHWE`: followed。`本文: D1: #359 が permissions を宣言から外した理由を一次記録で探した（2026-10-18）`
- `01KYMRE1NC7XX6N66RQ0MGGHF1`: followed。`本文: D1: 上流の断定を一次情報に当てた（2026-10-18）`
- `01M2DEC1G6GG9RTXGM6CRJEGZQ`: externally_verified。予測どおりの形が2回出て、どちらも外部の SO が見つけた。`本文: C1・C2 の差分に設計SO（弱・Codex 1レーン）を当てた（2026-10-19）`

### 残課題

- Codex の PreToolUse が `"ask"` に対応していないこと、hook の信頼の仕組み、`write_stdin` の例外、試していない形（`+main` の強制 push・`--upload-pack`・`rebase -i`・対話のセッション）、Cursor の hook。行き先: #461（decision の結果の節で申し送り済み）。
- #461 の題の「確認へ回す」と、Codex で果たせないことの食い違い。行き先: 統括（報告で知らせる。issue の題を直すかは統括と owner）。
- Claude Code の `block-force-push.sh` が、強制 push の文字列を `bash -lc` の引数に含む判定だけのコマンドを止めた例。誤って止める例の1件として、行き先: #461（報告で統括に渡す）。
- `codex execpolicy check` は `bash -lc` を分けないこと、検査の対象の一覧、既存のテストの期待、3.3 節と 3.5 節の試験を回帰の試験にすること、`Bash(git:*)` などが auto モードで外されるか（C16）。行き先: #460。
- hub と別のリポジトリの手元の層、Codex の `default.rules` に残る広い規則を直すか。行き先: #460 の警告が出てから owner が決める（decision の決定7）。
- ConfigChange が Claude Code 自身の書き込みで動くか（4C）・`/permissions` の書き先・apply の置き換えの回数。行き先: 追わない。どれも選ばなかった案の前提で、今回の判定に効かない。
- issue 本文の「削除前 129 件・Bash 112 件」。行き先: 追わない。バックアップが残っておらず、判定に効かない。
- Codex の hook の信頼の hash にスクリプトの中身が入らないことを手元の版で確かめること（X9）。行き先: #461。
- mod がほかの経路で入っていないか、`skill-creator` が `tool.check` を扱うか（discussion の C25・11節）。行き先: #461。mod は managed でない hook の止めを置き換えられるので、hook を本命にするなら前提として確かめる。
- #385 を閉じるか。行き先: ゲート6（統括と owner）。

### 形式メモ

- チャネルの骨格で拾えたもの: SO ごとの「自分で見つけられなかった理由」が事実・失敗にまとまった。拾えなかったもの: 4回の SO の指摘の重なり（同じ種類の誤りが繰り返したこと）は、表をまたいで見ないと分からない。皮（KPT/YWT）は使っていない。摩擦は、SO を4回回したので閉じる材料が多いことだった。

### Step 4（closure の外部チェック・Codex 1レーン）

- `so-compare --codex-only` で、事実・失敗の選択的な省略・follow-up の行き先・揮発するパス・ほかの文書への反映の4点だけを問うた。依頼文と出力は master の作業層 `tmp/385-permissions-canonical-scope/so-closure-prompt.md` と `so-closure/`。Codex（`gpt-6.1-sol`）が 65 秒・初回で返った。
- 結論は「直してから閉じる」で、指摘は3件（中2・低1）。3件とも採った。1件目は、discussion の11節の「mod の入り方と `skill-creator` の確認」が残課題に引き継がれていなかったことで、残課題に足した（行き先 #461）。2件目は、discussion の 4B の行と論点4 の理由に、C2 の前に書いた「Codex は確かめていない」が残っていたことで、deny は確かめ `"ask"` は非対応という今の結果に直した。3件目は、discussion の10節の `defaultMode` の記述が見つけたときの状態のままだったことで、統括が消したことを足した。
- 選択的な省略と揮発するパスは指摘なしだった。#460・#461 の issue の本文に申し送りが届いているかは、ワークスペースの外なので Codex は確かめていない。申し送りは報告で統括に渡す。

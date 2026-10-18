---
id: "01M57K6294A0RG3CK6R1TEH3WT"
title: "#385 許可規則を hub の正本に含めるかを決める（判定の材料と decision）"
date: 2026-10-18
type: episode
status: draft
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

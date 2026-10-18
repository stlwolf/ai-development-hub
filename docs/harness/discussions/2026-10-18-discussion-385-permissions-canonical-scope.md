---
id: "01M57K62AARMRQA8VHXJW9G9RG"
title: "#385 許可規則を hub の正本に含めるか（判定の材料）"
date: 2026-10-18
type: discussion
status: draft
related:
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/385"
    reason: "本 issue。5つの論点の判定の材料"
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/385#issuecomment-6250392852"
    reason: "着手時の認識合わせの確定版。比べる基準と、本体の仕様を一次情報で確かめることはここから来た"
  - type: design_context
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の設定適用の設計。union-array を足し、permissions は宣言に入れないと書いた"
  - type: relates_to
    ref: "docs/harness/episodes/2026-10-18-episode-385-permissions-canonical-scope.md"
    reason: "作業記録。上流の断定の裏取りと、材料を集めた経緯はこちら"
tags: [harness, settings, permissions, judgment-materials]
---

# #385 許可規則を hub の正本に含めるか（判定の材料）

## 0. この文書の位置と読み方

- この文書は、owner が #385 の5つの論点を判定するための材料である。判定はまだ置いていない。owner の判定は、このあと decision に記録する。
- 許可規則とは、Claude Code が確認なしで動かしてよい操作の一覧（`permissions.allow`）と、止める・確認する一覧（`deny`・`ask`）のことである。たとえば `Bash(git commit *)` を allow に入れると、`git commit` で始まるコマンドは確認なしで動く。
- 正本とは、hub が持ち、`sync.sh` が各ツールへ配る設定の元である。いま Claude Code の設定で正本があるのは、宣言 `canonical/claude/settings.harness.json` に書いた4項目（`hooks`・`statusLine`・`disableAgentView`・`idleCompaction`）だけで、許可規則は入っていない。
- 根拠の強さは各行に付けた。`[verified]` は出典を開いて確かめた主張、`[measured]` は手元で試して確かめた主張（条件は 3.3 節）、`[unverified-summary]` は出典はあるが言い切れるかを確かめていない主張、`[speculation]` は出典の無い推測である。
- 公開の文書なので、別のリポジトリの名前と中身は書かない。数だけを書く。

## 1. 推奨の一覧（先に読む表）

| 論点 | 推奨 | 一言の理由 |
|---|---|---|
| 1. 層の切り分け | allow は正本に置かない | いまの共通の形の allow は、ほとんどが書き込みや任意の実行ができるコマンドである。読み取りだけに選び直すことはできるが、得るものが小さい |
| 2. 書き込みの衝突 | allow を置かないなら、Claude Code の承認の保存先（手元の層）とは取り合わない。狭める側（ask・deny）を配るなら、配った項目と自分で足した項目を見分けて消す手段を、配る前に決める | Claude Code が承認を書くのは手元の層で、hub が書くユーザー層とは別のファイルである。ユーザー層全体を同時に書き換えたときの取り合いは、配るかどうかと関係なく残る。もう1つの穴は「足すだけで消せない」こと |
| 3. 検査だけ先に入れる案 | 入れる。Claude Code の規則について、全体を許す形・`*` の位置・前方一致の広さの3種を、警告として出す | 本体は広さの方を見ていない。hub の手元の層にはいまも広い規則が残っている |
| 4. 別リポジトリへの届き方 | 届かせるなら、ユーザー層に置くもの（hook か、狭める側の規則）を経路にする。本命は PreToolUse hook で、別の issue で採否を決める | ユーザー層のものは、設定が読み込まれ hook が切られていないすべてのリポジトリで効く。Claude Code では hook の `"ask"` が allow 規則より先に効くことを試して確かめた。Codex と Cursor は確かめていない |
| 5. 本体の検査で足りるか | Claude Code について足りない | 本体の警告は `*` の位置しか見ず、`Bash(git:*)` には出ない。`Bash(git:*)` は `git -c …` を確認なしで通すことを試して確かめた |

推奨をまとめると、「allow は配らない。hub は検査（論点3）を先に入れ、実行時に止める経路（論点4）は別の issue で採否を決める」になる。

## 2. 比べる基準

確定版の［別モデル］1つ目の3つで比べる。論点に判定が付いた数だけでは、判定が妥当かを測れないからである。K1 は、ゲート1 の指摘を受けて3つに分けた（7節）。分けないと、「どこでも動く」案が「よく見分ける」案と同じに見えるからである。

- **K1 危ない形を見つけられる範囲。** 次の3つに分けて見る。
  - **届く場所**: どのファイル・どのリポジトリ・どのツールに効くか。たとえば hub の手元の層だけを見る案と、すべてのリポジトリで効く案では違う。
  - **見分ける精度**: 危ない形を取りこぼさず、正当な操作を巻き込まずに見分けられるか。たとえば規則の文字列の前方一致は `git -C . -c x diff` を取りこぼす。
  - **止める力**: 見つけたものを知らせるだけか、実行を止められるか。
- **K2 許可が意図せず広がる危険。** その案を入れたことで、確認なしで動くものが、意図より多くの場所や形に広がるか。たとえば hub の正本に `Bash(gh pr *)` を置くと、すべてのリポジトリで `gh pr merge` も確認なしになる。
- **K3 運用と保守の手間。** owner が手で動かす回数、検査が赤になって往復する回数、一覧を最新に保つ手間、誤って止めた操作を通し直す手間。

表では、各案を K1・K2・K3 について「良い」「中」「悪い」で比べ、理由を添える。K1 の欄には、3つの見方のうち差の出るものを書く。

## 3. 本体の仕様（一次情報で確かめたこと）

### 3.1 Claude Code

取得日は 2026-10-18、手元の本体は 2.1.302 である。取得した文書の写しは master の作業層 `tmp/385-permissions-canonical-scope/src/`（gitignored）にある。

| # | 仕様 | 状態 | 出典 |
|---|---|---|---|
| C1 | 設定は5段で、上から managed・起動フラグ `--settings`・手元の層 `.claude/settings.local.json`・共有の層 `.claude/settings.json`・ユーザー層 `~/.claude/settings.json` の順に強い | [verified] | https://code.claude.com/docs/en/settings 「Settings precedence」 |
| C2 | `permissions.allow` のような一覧は、段をまたいで足し合わされる。上の段が下の段の項目を消すことはない | [verified] | 同「Lists merge instead of overriding」 |
| C3 | 規則は deny、ask、allow の順に見て、最初に当たったもので決まる。どの段の deny も、別の段の allow より先に効く | [verified] | https://code.claude.com/docs/en/permissions 「Manage permissions」「Settings precedence」 |
| C4 | 確認で「Yes, and don't ask again」を選ぶと、Claude Code は規則を git リポジトリの根の `.claude/settings.local.json` に書く。worktree では main のチェックアウトの根に書く（2.1.211 から） | [verified] | permissions 「Permission system」、settings 「Where Claude Code keeps the local file in a git repository」 |
| C5 | CLI では、Claude Code が許可規則を書くのは手元の層だけである。VS Code の拡張では書き先を選べ、共有の層も選べる | [verified] | settings 「Permission rules combine differently than you expected」 |
| C6 | ユーザー層 `~/.claude/settings.json` は、この機種のすべてのプロジェクトに効く。公式も「すべてのプロジェクトに許可規則を効かせたいならユーザー層に置け」と書く | [verified] | settings 「Settings files and who they affect」、permissions 「When your local settings file needs trust」の Note |
| C7 | 共有の層の allow はワークスペースの信頼を受けてから効く。手元の層の allow は、git に追跡されていなければ信頼なしで効く | [verified] | permissions 「Project allow rules and workspace trust」 |
| C8 | `*` が「どのコマンドかを決める後ろの語」より前にある allow 規則には、起動時に警告が出る（例 `Bash(git * main)`）。警告は規則と出どころのファイルを名指しするだけで、規則は残り、一致のしかたも変わらない | [verified] | https://code.claude.com/docs/en/errors 「Has a wildcard before the rest of the command」 |
| C9 | この警告は 2.1.246 から出る（2026-08-25 公開）。issue 本文の「2.1.265 で入った」は誤りで、2.1.265 の CHANGELOG に許可規則の検査の項目は無い | [verified] | CHANGELOG 2.1.246・2.1.265、errors の同節「Before v2.1.246, Claude Code accepted these rules without a warning.」、npm の公開時刻 |
| C10 | 背面のセッションと `--output-format json` / `stream-json` では、この警告は stderr でなくデバッグログに出る | [verified] | errors の同節 |
| C11 | `Bash(git *)` は git のすべてのコマンドを許す。`*` より前に書いた語だけが規則を絞る。末尾の `:*` は末尾の ` *` と同じ意味である | [verified] | permissions 「Wildcard patterns」 |
| C12 | `Bash(git:*)` は `git -c <設定> commit …` を確認なしで通し、起動時の警告も出ない。`Bash(git *)` も警告は出ない | [measured] | 3.3 節の T1・T4・T5。`-c` で git が任意のプログラムを動かせること自体は errors の同節の文 [verified] |
| C13 | 本体 2.1.302 の `/doctor` の指示文は、末尾の `*` の規則を「オプションを見ない前方一致」とし、`curl`・`gh api`・インタプリタ・`git fetch` / `git pull` を許可規則に入れるなと書く。`gh api` は「GET だけ」を前方一致で書けないので一切入れるなとしている | [verified] | 本体 2.1.302 のバイナリの文字列（`/doctor` の Check 9）。公開の文書ではなく本体の中の文である |
| C14 | 同じ `/doctor` の指示文は、提案する allow 規則をユーザー層に書かず手元の層だけに書く。理由は「ユーザー層の規則は、1つの汚染されたリポジトリから誘導された承認を、すべてのプロジェクトで事前承認にしてしまう」である | [verified] | 同上 |
| C15 | auto モードでは、allow・ask・deny の規則に当たる操作は判定器より先に決まる。次に、読み取りの操作と作業ディレクトリの中の編集は、判定器に回らずに通る（サーバー側の判定が有効なセッションでは、読み取りのシェルのコマンドもその判定を待つ）。auto モードに入るときに外される広い規則は `Bash(*)`・`Bash(python*)` のようなインタプリタ・パッケージマネージャの run・`Agent`・`Monitor` である | [verified] | https://code.claude.com/docs/en/permission-modes 「How the classifier evaluates actions」 |
| C16 | `Bash(git:*)`・`Bash(curl:*)`・`Bash(gh api:*)` が auto モードで外されるかは、文書に書かれていない | [verified]（書かれていないことの確認） | 同上 |
| C17 | Bash の規則はコマンドの文字列に当てるもので、安全の境界ではない。たとえば deny の `Bash(git push *)` は `git -C . push` を止めない | [verified] | permissions 「What a Bash rule doesn't match」 |
| C18 | PreToolUse hook が exit 2 で止めると、許可規則より先に効き、allow 規則があっても止まる。hook の `"ask"` は auto モードでも確認を出させる | [verified] | permissions 「Precedence among rules, hooks, and mods」、https://code.claude.com/docs/en/hooks 「PreToolUse decision control」 |
| C19 | hook の `"ask"` は、当たる allow 規則より先に効く。文書はこれを言い切っていないが、試すと allow があっても確認に回った | [measured] | 3.3 節の T2 |
| C20 | ConfigChange hook は、セッション中に `~/.claude/settings.json`・`.claude/settings.json`・`.claude/settings.local.json` が変わると動き、変わったファイルのパスを受け取る。変更を止めることもできるが、止めても owner にも Claude にも何も表示されない | [verified] | hooks 「ConfigChange」 |
| C21 | 許可規則の変更は、走っているセッションに再起動なしで効く | [verified] | settings 「When edits take effect」 |
| C22 | Bash の sandbox は、OS がシェルのコマンドとその子プロセスに掛ける境界で、既定では切れている。`sandbox.enabled` はユーザー層に書ける。既定では読み取りは認証情報のファイルを含む機種のほとんどに届き、ネットワークは許可したドメインだけに出られる（最初は空）。hook・MCP・ファイルの道具は境界の外で動く | [verified] | https://code.claude.com/docs/en/sandboxing 「What the sandbox restricts」「What runs outside the sandbox」 |
| C23 | sandbox の auto-allow では、境界の中で動くコマンドは確認なしで通る。allow 規則に当たるコマンドは、境界の外でのやり直しも確認なしで通る。`autoAllowBashIfSandboxed: false` で境界の中のコマンドにも確認を出させられ、`allowUnsandboxedCommands: false` で境界の外でのやり直しを止められる。ただし `autoAllowBashIfSandboxed` はリポジトリのファイルからも変えられる | [verified] | sandboxing 「Auto-allow mode」「The unsandboxed retry escape hatch」と、filesystem isolation を切る節の「In a repository's files」 |
| C24 | hook は段をまたいで足し合わされるが、`disableAllHooks: true` はすべての hook を切る（managed の hook を除く）。この値は優先順位どおりに決まるので、リポジトリの共有の層や手元の層がユーザー層の値を上書きできる | [verified] | hooks 「Disable or remove hooks」と同ページの段の説明、permissions 「What runs before you trust a folder」の `disableAllHooks` の項 |
| C25 | 入れた mod が `tool.check` を扱うと、ask 規則で確認になる操作や、managed でない PreToolUse hook が止めた操作を、mod が承認で置き換えられる | [verified] | permissions 「Precedence among rules, hooks, and mods」 |

### 3.2 Codex と Cursor

hub の設定は Claude Code だけでなく Codex と Cursor にも配られる。「本体が持つから hub は要らない」と言うなら、届く環境のすべてで確かめる必要がある（knowledge item `01M1VTJJFF1TK067ZX3X912G0P`）。

| # | 仕様 | 状態 | 出典 |
|---|---|---|---|
| X1 | Codex の許可規則は `prefix_rule(pattern=[...])` で、コマンドの語を先頭から順に当てる。途中の `*` は無い。たとえば `["git", "push"]` は `git -c x push` に当たらないが、`git push` の後ろに何を付けても当たる | [verified] | https://raw.githubusercontent.com/openai/codex/main/codex-rs/execpolicy/README.md 「Matching semantics」（手元は codex-cli 0.163.0） |
| X2 | Codex の README から、広い規則を警告する仕組みは確認できなかった | [verified]（書かれていないことの確認。仕組みが無いことの確認ではない） | 同上 |
| X3 | Cursor CLI の許可規則は `Shell(commandBase)` で、`Shell(git)` は git のすべてのサブコマンドを許す。置き場は `~/.cursor/cli-config.json` とプロジェクトの `.cursor/cli.json` である | [verified] | https://cursor.com/docs/cli/reference/permissions |
| X4 | Cursor の文書から、広い規則を警告する仕組みは確認できなかった | [verified]（書かれていないことの確認。仕組みが無いことの確認ではない） | 同上 |

### 3.3 手元で試したこと（C12・C19 の根拠）

使い捨てのリポジトリで、`claude -p --model haiku --setting-sources project --permission-mode dontAsk --tools Bash --settings '<その場の JSON>'` を回した（2026-10-18・本体 2.1.302・`claude-haiku-5-5`）。ユーザー層と手元の層の設定は読ませていない。dontAsk は「確認が要るものは自動で拒否する」モードなので、確認が出るかどうかを、拒否されるかどうかで見られる。記録は master の作業層 `tmp/385-permissions-canonical-scope/perm-test/` にある。

| 試験 | allow | hook | 結果 |
|---|---|---|---|
| T0 | なし | なし | `git -c user.name=t -c user.email=t@t commit --allow-empty -m probe` は拒否され、commit は増えなかった（対照） |
| T1 | `Bash(git:*)` | なし | 同じコマンドが確認なしで動き、commit が1つ増えた |
| T2 | `Bash(git:*)` | PreToolUse で `git -c` を含めば `"ask"` を返す | 拒否され、commit は増えなかった。hook の `"ask"` が allow より先に効いた |
| T3 | `Bash(git * main)` | なし | stderr に起動時の警告が1行出た（陽性の対照） |
| T4 | `Bash(git:*)` | なし | 警告は出なかった |
| T5 | `Bash(git *)` | なし | 警告は出なかった |

試したのは `-c user.name` のような無害な設定で、任意のプログラムを動かす `-c` は試していない。T1 が示すのは「`-c` を前に置いた git のコマンドに `Bash(git:*)` が当たる」ことで、`-c` で何が動くかは公式の文書の文による。T2 は dontAsk での観測で、auto モードでの振る舞いは C18 の文による。

## 4. いまの状態（2026-10-18 の実測）

- hub の `.claude/settings.local.json`: allow 125 件（Bash 108・Read 10・WebFetch 6・WebSearch 1）。deny と ask は無い。`*` が末尾でない Bash 規則は0件である [verified]。
- その 108 件を、リポジトリのパスを含むかどうかで分けると、このリポジトリ限りのもの 55 件、どこでも同じ形の1回きりのコマンド 29 件、どこでも同じ形の前方一致（末尾が `*`）24 件だった。分け方はパスの印による機械的なもので、境目の数件は入れ替わりうる [verified]（分類の規則は episode に書いた）。
- どこでも同じ形の前方一致 24 件のうち、読み取りだけのものは `ls`・`wt list`・`wez discover` の3件である。`ls` は本体が最初から確認なしで通す（permissions 「Read-only commands」）。残りの 21 件は、書き込みか任意の実行ができる。たとえば `Bash(git:*)`・`Bash(gh pr:*)`（`gh pr merge` を含む）・`Bash(gh api:*)`（POST を含む）・`Bash(gh auth *)`（`gh auth token` は認証のトークンを表示する）・`Bash(curl:*)`・`Bash(python3:*)`・`Bash(bash -c ':*)`・`Bash(codex exec *)` である [verified]。
- ユーザー層 `~/.claude/settings.json` に `permissions` と `sandbox` は無い [verified]。
- この機種の `~/work/repos` の下の `.claude/settings.local.json` は hub を含めて9つで、allow は合わせて 202 件だった。`*` が末尾でない Bash 規則は hub の外に1件あり、いまも残っている。`git`・`curl`・`python3`・`gh api` などの前方一致は 8 件（5ファイル）である [verified]。
- Codex のユーザー層 `~/.codex/rules/default.rules` に `prefix_rule` が 32 件あり、すべて allow である。hub は管理していない。`["git", "push"]`・`["git", "fetch"]` のような2語の規則を含む [verified]。
- Cursor のユーザー層 `~/.cursor/cli-config.json` は dotfiles のリポジトリへの symlink の中にあり、allow は `Shell(ls)` の1件である [verified]。
- hub はすでに、Claude Code に PreToolUse の Bash hook（`block-destructive.sh`・`block-force-push.sh`・`cc-lint.sh`）を、Codex に PreToolUse を、Cursor に `beforeShellExecution` を配っている [verified]（`canonical/hooks/*.hooks.json`）。Claude Code では、ユーザー層の設定が読み込まれ、`disableAllHooks` で切られていないセッションなら、どのリポジトリでも動く（C24）[verified]。Codex と Cursor の hook が同じ条件で動くかは確かめていない。
- ユーザー層の設定の top-level に `mods` という名前のキーは無く、`enabledPlugins` は `skill-creator` の1つである [verified]。mod がほかの経路で入っていないか、`skill-creator` が `tool.check` を扱うかは確かめていない。
- hub の `.claude/settings.local.json` の更新時刻は 2026-09-10 で、それから書き足されていない [verified]。auto モードでは確認がほとんど出ないためと考えられる [speculation]。

## 5. #359 が permissions を宣言から外した判断の読み直し

外した判断の一次記録を先に読んだ（knowledge item `01KZK26GQZ39WCFV5MYKQMRHWE`）。

- #359 の plan の DJ-3 は、`union-array` を `permissions.allow` を想定して足したうえで、「ただし `permissions` は今回の宣言には入れない」と書いている。**外した理由は、plan・episode・issue のコメント・PR #370・#372・#374 の本文とレビューのどこにも書かれていない** [verified]（5か所を探した結果）。
- 記録から読める事情は2つある。(a) #359 が対象にしたのは `~/.claude/settings.json` に実在するキーで、そこに `permissions` は無かった。(b) hub の許可規則は手元の層にあり、#359 の配布先（ユーザー層）とは別のファイルだった。理由として書かれたものではないので、これを当時の理由とみなすのは推測である [speculation]。
- この推測した事情は、いまも成り立つ。ユーザー層に `permissions` はまだ無く（4節）、`apply-claude-settings.sh` の書き先も `~/.claude/settings.json` のままである [verified]。
- 加えて、#359 のときに無かった事実が2つある。1つ目は、`union-array` が「足すだけで、配った項目を個別に消せない」こと（apply は手元に無い項目を後ろに足すだけで、`absent` はパスごと消す）[verified]。2つ目は、ユーザー層の allow はすべてのリポジトリで確認なしになり、本体の `/doctor` もその理由でユーザー層には書かないこと（C6・C14）[verified]。どちらも「allow を入れない」側を強める。
- したがって「入れない」はいまも妥当だが、理由が書かれていない状態は直すべきである。decision に理由を初めて書く。

## 6. 論点ごとの選択肢と推奨

### 論点1 層の切り分け

問い: 許可規則には、どのリポジトリでも同じもの（`gh` の読み取りの類、`command -v` など）と、そのリポジトリ限りのもの（`./tests/test_verify.sh` など）が混ざっている。前者だけを正本に置く形は成り立つか。

| 案 | 中身 | K1 範囲 | K2 広がる危険 | K3 手間 |
|---|---|---|---|---|
| 1A | いまの共通の形の allow を、そのままユーザー層の正本に移す（宣言に `/permissions/allow` を `union-array` で足す） | 届く場所は全リポジトリに広がるが、見つける仕組みは増えない | 悪い。いまの 24 件のうち 21 件が書き込みか任意の実行のできる前方一致で、それが全リポジトリで確認なしになる | 中。配った項目を消す操作が無い（論点2） |
| 1A' | 読み取りだけに当たると確かめた規則を選び直して、ユーザー層に配る。たとえば `Bash(gh pr view *)` のように、当たりうるすべての形が読み取りである規則だけを置く | 1A と同じ | 中。選ぶ基準を守れば広がりは小さいが、基準の判定を誤ると全リポジトリに広がる。本体の `/doctor` は、選び直した規則でもユーザー層には書かない（C14） | 条件付きで悪い。規則ごとに「当たりうるすべての形が読み取りか」を確かめる手間が要る。候補の数と更新の頻度が決まっていないので、手間の大きさはまだ言えない |
| 1B | allow は正本に置かない。読み取りは本体の組み込みに任せ、ほかはリポジトリごとの手元の層に残す | いまと同じ | 良い。hub の操作で allow が広がる経路が無い | 良い。仕組みを足さない |
| 1C | 正本は狭める側（ask・deny）だけを持ち、ユーザー層に配る。たとえば ask に `Bash(git -c *)` を置き、`Bash(git:*)` が残っていても `git -c` だけは確認を出させる | 届く場所は全リポジトリ。見分ける精度は前方一致の範囲で、`git -C . -c x diff` は当たらない（C17）。止める力はある（C3） | 良い。狭める側なので広がらない | 中。一覧を保つ手間と、正当な `git -c` で確認が増える手間。deny が残ると正当な操作が止まり続ける |
| 1D | どこでも同じ allow の見本を hub に置くが、適用はせず、各リポジトリで人が写す | 悪い。見本が守られているかを見ない | 中。写す人が中身を読む前提になる | 中。見本の更新が要る |

推奨: **1B**。allow は正本に置かない。

理由: いまの共通の形の allow をそのまま正本に移す形（1A）は成り立たない。24 件のうち読み取りだけのものは3件で、`ls` は本体が最初から通す（4節）。読み取りだけに選び直す形（1A'）は成り立ちうるが、得るものはまだ測っていない。owner は auto モードで動かしており、本体が読み取りと見なす操作はそもそも確認も判定器も通らずに動く（C15）ので、その分は選び直しても何も減らない。手元の層が5週間書き足されていないこと（4節）は、ファイルが更新されていないことを示すだけで、確認の回数や待ち時間は分からない。一方、選び直しの基準を誤ったときの害は全リポジトリに及ぶ。したがって既定では配らず、同じ確認が何度も出ていると具体的に分かった候補が出たときに、その候補だけを見直す。issue が例に挙げた「`gh` の読み取りの類」も、`gh pr *` は `gh pr merge` を含むので、サブコマンドの単位まで絞って選ぶ必要がある。`gh api` は「GET だけ」を前方一致で書けない（C13）。1C は狭める側の別の判断なので、論点4・5 の選択肢として扱う。

### 論点2 書き込みの衝突

問い: Claude Code 自身が許可規則を書き足す。配列の `allow` に `union-array` が使えるか。追記と正本の適用が競合したとき、どちらを残すか。

書く主体は次のとおりである。

- 確認で「don't ask again」を選んだとき: 手元の層（C4・C5）[verified]
- `/doctor` の提案を承認したとき: 手元の層だけ（C14）[verified]
- VS Code の承認のカード: 選んだファイル。共有の層も選べる（C5）[verified]
- `/permissions` の画面で足したとき: どのファイルに書くかは、読んだ範囲の文書に書かれていなかった [unverified-summary]
- hub の `sync.sh`: ユーザー層だけ、しかも宣言した項目だけ [verified]
- Claude Code の `/model`・`/config` などは、許可規則とは別のキーをユーザー層に書く（#359 の plan「設計の前提」）[verified]
- owner が手でユーザー層を編集したとき: そのファイル全体 [verified]（自明だが、取り合いの相手として数える）

| 案 | 中身 | K1 範囲 | K2 広がる危険 | K3 手間 |
|---|---|---|---|---|
| 2A | `union-array` をいまの形で使う | — | allow なら悪い。配った項目をあとで正本から外しても手元に残る。ask・deny なら害は「確認が余分に出る」か「正当な操作が止まり続ける」 | 良い。いまある操作で済む |
| 2B | 配った項目を個別に消す操作（たとえば「外した項目の一覧」を持つ）を足してから使う | — | allow を外すなら良い。ask・deny を外すと、その分だけ許可が広がる向きに働く。配った項目と owner が自分で足した同じ文字列の項目を見分ける手段も要る | 中。操作を1つ足す実装と検査が要る |
| 2B' | 2B の自動で消す代わりに、外した項目が手元に残っていれば検査で知らせ、消すかは owner が手で決める。出どころが分からない項目は残す | — | 良い。勝手に消さないので、owner の項目を巻き込まない | 中。知らせたあとに見る人の手間が残る |
| 2C | `/permissions/allow` を `replace` で丸ごと置き換える | — | 中。正本が広がればそのまま全部に効く | 悪い。owner や `/permissions` がユーザー層に足した項目が毎回消える |
| 2D | 配る先を各リポジトリの手元の層にする | 届く場所は良い | 悪い。Claude Code が承認のたびに書くファイルで、直接取り合う | 悪い。リポジトリごとに配る先が増える（worktree は main の手元の層を使うので、worktree ごとには増えない。C4） |

推奨: **論点1 で 1B を選ぶなら、Claude Code の承認の保存先とは取り合わない。** Claude Code が承認を書くのは手元の層で、hub が書くのはユーザー層である（C4・C5）。`union-array` は、適用の計算で手元の項目を消さない。

**ただし、ユーザー層のファイル全体を同時に書き換えたときの取り合いは、1B でも残る。** `apply-claude-settings.sh` は宣言した項目だけを計算で変えるが、書き込みは読んだファイル全体から作った結果でファイル全体を置き換える。最後の確かめ（`cmp`）から置き換え（`mv`）までの間に owner の手の編集や `/permissions` の追加が入れば、その編集は失われうる。逆に、別の書き手が古い内容を書き戻す場合もある。apply は置き換えの直前に読み直して窓を狭めているが、置き換えの直前と直後の隙間はどう並べても無くせないと自ら注記している（同ファイルの置き換えの手順のコメント）[verified]。これは許可規則を配るかどうかと関係なく、いまもある取り合いである。許可規則を配っても取り合いの作りは変わらないが、置き換えの回数や時間が増えるかまでは確かめていない。

**狭める側（1C）を配るなら、配る前に、配った項目と owner が足した項目を見分けて消す手段を決める。** 候補は、自動で個別に消す 2B と、知らせて手で消す 2B' である。外し損ねの害は、ask なら「確認が余分に出る」、deny なら「正当な操作が止まり続ける」で、allow の外し損ねより軽いが無害ではない。allow を配るなら（1A か 1A' を選ぶなら）、2B が無いまま配ってはいけない。外した allow が手元に残り続け、危ない規則を正本から消しても消えないからである。

### 論点3 検査だけ先に入れる案

問い: 正本を持たずに、`sync.sh --check` に「危ない形の規則が無いか」の検査だけを足す形はどうか。

検査する形は3種に分けられる。対象は Claude Code の規則だけで、Codex の `prefix_rule` と Cursor の `Shell(...)` は、この案では見ない。

- **全体**: Bash のすべてを許す規則。裸の `Bash` と `Bash(*)` で、公式はどちらも Bash のすべての操作に当たると書く（permissions 「Match all uses of a tool」）[verified]。いまの hub には無いが、入れば最も広い。
- **位置**: `*` が末尾でない Bash 規則。本体の警告（C8）と同じ形である。本体の警告と重なるが、本体は「そのリポジトリでセッションを始めたとき」にしか出ず、背面のセッションと json 出力ではデバッグログに入る（C10）。hub の検査は sync のときに出せる。
- **広さ**: 末尾が `*` の前方一致で、任意の実行や書き込みができるプログラムに付いたもの。たとえば `Bash(git:*)`・`Bash(curl:*)`・`Bash(gh api:*)`・`Bash(python3:*)`・`Bash(bash -c ':*)`。本体はこの形を警告しない（C12）。いまの hub の手元の層では、少なくとも5件がこれに当たる。

| 案 | 中身 | K1 範囲 | K2 広がる危険 | K3 手間 |
|---|---|---|---|---|
| 3A | `--check` に、全体・位置・広さの3種の検査を足す。対象は hub の手元の層・共有の層とユーザー層の、Claude Code の規則。結果は警告にとどめ、終了コードを赤にしない | 届く場所は hub の中の3ファイルで、Claude Code だけ。見分ける精度は、全体と位置は確実、広さは一覧に載せたプログラムの範囲。止める力は無い（知らせるだけ） | 良い。読むだけ | 中。広さの検査は「危ないプログラムの一覧」を持つので、その更新が要る |
| 3B | 3A に加え、明示したときだけ、この機種のほかのリポジトリの手元の層も数える。出力は手元の端末だけにする | 届く場所が、この機種のリポジトリまで広がる | 良い | 中。どこを数えるかの指定が要る |
| 3C | 位置の検査だけを足す | 悪い。本体の警告と同じ形しか見つからない | 良い | 良い |
| 3D | 足さない | 悪い | 良い | 良い |

推奨: **3A**（3B は 3A の上に、明示したときだけ働く形で足してよい）。

理由: 本体は広さの方を見ていない（C12）。そして hub の手元の層には、本体の警告を一度受けて直したあとも、広い規則が残っている（4節）。位置だけの検査（3C）では、この残っている方を見つけられない。

警告にとどめる理由: 対象のファイルは hub の正本ではなく、owner と Claude Code が書く手元のファイルである。`--check` が赤を返すのは「宣言と手元が違う」ときで、#359 の HG-D でも drift は「報告だけ」と決めた。綴りの検査（公式の一覧に無いキー）を警告にした先例とも揃う。いきなり赤にすると、owner が規則を直すまで `--check` が赤のままになり、ほかの差分が見えにくくなる。警告にしても、見つける目的とは矛盾しない。見つけて出力に出すことと、検査の終了コードを赤にすることは別だからである。なお `--check` は読むだけの検査で、赤にしても `sync.sh` の適用は止まらない。赤にする効果は「差分あり」の扱いになることだけである。

実装の単位への申し送り: 広さの検査で「危ないプログラムの一覧」を持つときは、一覧に文字を足して直す形にならないかを確かめる（knowledge item `01KZXFJCT0QWR8WVMM8BZN7T1S`。この単位は検査を書かないので採否はしていない）。3.3 節の試験は、本体を上げたときに C12・C19 が変わっていないかを見る回帰の試験として残せる（ゲート1 の代替3 から。7節）。`--check` の終了コードを見る既存のテスト（`projects/orchestration-engine/tests/test_check_claude_settings.sh` など）は、警告にとどめる形なら期待を変えずに済む見込みだが、確かめていない [speculation]。

### 論点4 別リポジトリへの届き方

問い: hub が配るのはユーザー層（`~/.claude/`）で、各リポジトリの `.claude/settings.local.json` には届かない。届かせるなら別の経路が要る。

ユーザー層に置いたものは、すべてのリポジトリで効く（C6）。したがって「別のリポジトリのファイルを書き換える」経路を作らなくても、ユーザー層に置くものの選び方で届かせられる。ただし「効く」には条件がある。ユーザー層の設定を読まない起動（`--setting-sources` で外す・`--bare`）では効かない。hook は、リポジトリの共有の層か手元の層が `disableAllHooks: true` にすると切られる（C24）。入れた mod は、ask 規則と managed でない hook の止めを承認で置き換えられる（C25）。どの案も、owner の通常の運用で確認を増やす仕組みであって、リポジトリ側の設定が逆らっても破れない境界ではない。

| 案 | 中身 | K1 範囲 | K2 広がる危険 | K3 手間 |
|---|---|---|---|---|
| 4A | ユーザー層に規則を置く。足し合わせ（C2）で全リポジトリに効く。ask・deny なら、どの段の allow より先に効く（C3） | 届く場所は全リポジトリ。見分ける精度は前方一致の範囲（C17）。止める力は ask・deny ならある | allow は悪い・ask と deny は良い | 中。論点2 の 2B か 2B' が要る |
| 4B | ユーザー層の PreToolUse hook を使う。実行の直前にコマンドを見て、`git -c`・`--exec-path`・`--upload-pack` のような任意の実行の形なら `"ask"` を返す | 届く場所は、Claude Code では上の条件を満たす全リポジトリ。見分ける精度は hook の作り次第で、規則の前方一致より細かく見られる（たとえば `git -C . -c` の並べ替えや前置きの環境変数）が、取りこぼしが無いことは保証されない。止める力は、Claude Code では T2 の条件で allow より先に効いた（C19）。Codex と Cursor では、hook が確認を求められるか、既存の規則より先に効くか、対話でない実行でどうなるかを確かめていない。hub が3ツールへ PreToolUse 系の hook を配っていること（4節）は、配る経路があることを示すだけである | 良い。止める・確認する側にしか働かない | 中から悪い。正当な `git -c` で確認が増える。誤って止める例と取りこぼす例を測る手間が要る。3ツールで hook の作りと受け取る入力が違う |
| 4C | ユーザー層の hook で、各リポジトリの手元の層を読む。SessionStart か ConfigChange（C20）で、規則のファイルに危ない形があれば知らせる | 届く場所は全リポジトリ。見分ける精度は 3A と同じ。止める力は無い | 良い | 中。ConfigChange で止めても何も表示されない（C20）ので、知らせる手段を別に用意する。Claude Code 自身が承認を書いたときに ConfigChange が動くかは確かめていない |
| 4D | hub の検査で、この機種のほかのリポジトリのファイルを読む（3B と同じ） | 届く場所はこの機種に限る。止める力は無い | 良い | 良い |
| 4E | managed 設定で許可規則を管理する（`allowManagedPermissionRulesOnly`） | 良い | 中 | 悪い。管理者権限が要り、owner が一時的にも上書きできなくなる（#359 の棄却案と同じ） |

推奨: **届かせるなら 4B を本命にし、4A の ask を軽い代わりとして並べ、別の issue で採否を決める。** 4D は 3B として安く足せる。

理由: Claude Code については、4A の ask と 4B は、どちらもユーザー層に置くので上の条件を満たすすべてのリポジトリに届き、どのファイルの allow より先に効く（C3・C19）。たとえば別のリポジトリの手元の層に `Bash(git:*)` が残っていても、hook か規則がその形を見分けられれば、`git -c core.fsmonitor=… diff` を実行する前に確認を出させられる。Codex と Cursor について同じことが言えるかは確かめていないので、別の issue ではツールごとに成り立つかを先に確かめる。差は見分ける精度と手間にある。4A は規則の文字列の前方一致なので、`git -C . -c x diff` のような並べ替えを取りこぼす（C17）。4B は hook の中でコマンドを読めるので細かく見られるが、そのぶん誤って止める例と取りこぼす例を測る手間が要る。hub はすでに同じ経路で `block-destructive.sh` を3ツールへ配っているので、4B に新しい配布の仕組みは要らない。ただし `block-destructive.sh` は破壊的な操作を止める hook で、任意の実行の形を足すのは別の論理的な変更になる。この issue では方向だけを決め、実装は分ける。

### 論点5 本体の検査で足りるか

問い: 2.1.246 以降はセッションの開始時に警告が出る。人が読んで直す前提でよいなら、hub に仕組みを足さない選択もある。

本体の警告が届く範囲と届かない範囲は次のとおりである。

- 届く: Claude Code の、`*` が途中にある allow 規則。対話のセッションの開始時に、出どころのファイル付きで出る（C8・T3）。
- 届かない: 末尾の `*` の広い規則（`Bash(git:*)` など。C12・T4）。背面のセッションと json 出力の stderr（C10）。規則そのものを直すこと（警告は規則を変えない。C8）。Codex と Cursor については、同じ検査を文書から確認できなかった（X2・X4）。

| 案 | 中身 | K1 範囲 | K2 広がる危険 | K3 手間 |
|---|---|---|---|---|
| 5A | 本体の警告だけに任せ、hub は何も足さない | 悪い。位置の形しか見ない | 良い | 良い |
| 5B | 本体の警告に、hub の検査（論点3の 3A）を足す | 中。広さの形も見つかるが、hub の中のファイルに限り、止めない | 良い | 中 |
| 5C | 5B に、実行時に確認を出させる経路（論点4の 4B か 4A の ask）を足す | 届く場所は、Claude Code では条件を満たす全リポジトリ。見分ける精度は選ぶ方式次第で、4A は前方一致の範囲、4B は hook の作り次第。止める力はある（暫定の評価） | 良い | 中から悪い。hook か一覧の保守が増える |
| 5D | 5C に、狭める側の共通の規則（論点1の 1C）と hook の両方を置く | 5C より見つかる範囲が広がるとは言えない。hook が見分ける形を、規則が補って見つける具体例がまだ無い | 良い | 悪い。同じ危険を2か所で見ることになる |
| 5E | Bash の sandbox を正本の宣言に入れ、規則が残っていても境界の外に出られないようにする（`sandbox.enabled` などはユーザー層のキー。C22） | 見つけはしないが、残った規則の害を減らす別の種類の案である。届く場所は全リポジトリのシェルのコマンド。hook・MCP・ファイルの道具は境界の外（C22） | 既定の auto-allow のままなら悪い。境界の中のコマンドが確認なしで通り、allow 規則に当たるコマンドは境界の外でのやり直しも確認なしで通る（C23） | 悪い。ネットワークの許可が最初は空なので、`gh`・`curl`・`codex` などが設定するまで動かない。Codex と Cursor には別の sandbox がある |
| 5E' | 5E に `autoAllowBashIfSandboxed: false` と `allowUnsandboxedCommands: false` を足し、確認の流れを保ったまま境界を掛ける | 5E と同じ | 良い。確認の流れは変わらず、境界の外でのやり直しも止まる。ただし `autoAllowBashIfSandboxed` はリポジトリのファイルから変えられる（C23） | 悪い。5E の互換の手間に加え、境界で失敗したコマンドを境界の外でやり直す道が無くなるので、境界の設定が足りないと作業が止まる |

推奨: **Claude Code について足りない。いまは 5B を入れ、5C は別の issue で決める。** 5E と 5E' はこの issue では採らず、試す場所を作れたら別に検討する候補として残す。5E' は広がる危険を抑えられるが、owner の作業の道具が境界の設定を終えるまで動かない手間が重いからである。

理由: 本体の警告は、hub の4件を見つけるのには働いた。しかし同じ hub の手元の層に、警告の出ない広い規則が少なくとも5件残っている（4節）。`Bash(git:*)` が `git -c …` を確認なしで通し、警告も出ないことは試して確かめた（C12）。「本体が検査しているから、危ない規則は無い」とは言えない。Codex と Cursor については、同じ検査があることを文書から確認できなかったので、Claude Code で確かめた重複をほかの2ツールに広げられない（knowledge item `01M1VTJJFF1TK067ZX3X912G0P`）。別のリポジトリでは、警告の出る形が1件いまも残っている。直されていない理由（そのリポジトリでセッションを始めていない、警告を見落とした、など）は確かめていない [speculation]。

## 7. ゼロベースの代替探索（ゲート1）

推奨を仮に置いたあと、確定の前に `so-compare --codex-only` で、初期案の外の代替を問うた（`so-compare` の「選択肢拡張」の型）。返したのは Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.163.0）で、131 秒・初回で返った。依頼文と出力は master の作業層 `tmp/385-permissions-canonical-scope/so-gate1-prompt.md` と `so-gate1/` にある。

```text
許可規則への対処（#385）
├── 規則のファイルを対象にする（初期案）
│   ├── 配る（1A・1A'・1C・4A） → 1A は棄却、1A' は採らない、1C と 4A の ask は別 issue の候補
│   └── 見る（3A・3B・4C・4D） → 3A を推奨、3B・4D は明示時だけ
├── 実行時のコマンドを対象にする（初期案）
│   └── PreToolUse hook（4B） → 別 issue の本命
├── 実行主体の権限を絞る（ゲート1 の代替1・新しい種類）
│   └── Bash の sandbox を宣言に入れる（5E・5E'） → この issue では採らない。理由は 6節の論点5
├── 道具そのものを限る（ゲート1 の代替2・新しい種類）
│   └── 汎用のシェルの代わりに、引数を検証する専用の操作口（MCP など）を hub が作る → 採らない
└── 期待する振る舞いを正本にする（ゲート1 の代替3・新しい種類）
    └── 「自動で通る・確認が要る・拒否」のケース集を置き、本体の判定が合うかを試す → 一部を採った（3.3 節の試験を回し、回帰の試験として残す）
```

代替ごとの採否は次のとおりである。

- **代替1（sandbox）**: 新しい種類の案として 6節に 5E を足した（ゲート2 の指摘で、確認の流れを保つ 5E' も足した）。採らない理由は、ネットワークの許可が空から始まるので owner の作業の道具が設定するまで動かないこと（C22）である。既定の auto-allow が確認を減らす向きに働く点（C23）は、5E' で抑えられる。初期案に無かった理由は、Codex の分け方では「隠れていた前提」で、対処の対象を「規則のファイル」か「実行時のコマンド」の2つに決めていた。
- **代替2（専用の操作口）**: 採らない。owner と委譲子の作業は汎用のシェルに乗っており、操作口を作ると作業の道具そのものが変わる。#385 の問い（許可規則を正本に含めるか）の外にあり、K3 も重い。初期案に無かった理由は「隠れていた前提」で、いまのコマンドの体系を保つことを前提にしていた。
- **代替3（振る舞いのケース集と回帰の試験）**: 一部を採った。仮の推奨は、確かめていない前提（`Bash(git:*)` が `git -c` を通すか、hook の `"ask"` が allow より先に効くか）に立っていた。その場で 3.3 節の試験を回し、C12 と C19 を [measured] にした。ケース集を hub の正本として置き、sync のたびに回す形は採らない。1回ごとに `claude -p` を呼ぶので重いからである。本体を上げたときに回す回帰の試験として、実装の issue に申し送る。初期案に無かった理由は「探索漏れ」で、正本を「設定の値」とだけ結び付けていた。

追加の問いへの指摘（推奨のうち事実から言えないもの、評価の甘さ・厳しさ）は9件で、9件とも採った。

| # | 指摘 | 採否と直し |
|---|---|---|
| 1 | 論点1 の「数字の上で成り立たない」は強すぎる。いまの 24 件は一括で移すことへの反対の根拠で、選び直した共通の allow まで不成立とは言えない。`gh api` の制約を gh 全体に広げている | 採った。1A を「いまのものをそのまま移す」と 1A'「選び直す」に分け、推奨の理由を「1A は成り立たない、1A' は成り立ちうるが得るものが小さい」に直した |
| 2 | 論点2 の「消し合わない」は言い切れない。apply 自身が置き換えの直前と直後の隙間は無くせないと書いている | 採った。窓は許可規則を配るかどうかと関係なくいまもあり、配っても増減しない、と書き直した |
| 3 | deny が残ったときの害は「確認が余分に出る」にとどまらず、正当な操作が止まり続ける | 採った |
| 4 | 論点4 の「置き場所と関係なく効く唯一の案」は誤り。ユーザー層の deny も別の段の allow より先に効く（C3） | 採った。4A の ask・deny と 4B を並べ、差を見分ける精度と手間に置き直した |
| 5 | 論点5 で「文書に記述が無い」を「届かない」に強めている | 採った。X2・X4 と論点5 の文を「文書から確認できなかった」に直した |
| 6 | 1A の K2 は、21 件をすべて配る前提で厳しすぎる | 採った（指摘1 と同じ直し） |
| 7 | 4B・5C の K1 と K3 は甘い。届く場所と見分ける精度は別で、並べ替え・ラッパー・誤検知・3ツールの差を確かめる費用がある | 採った。K1 を「届く場所・見分ける精度・止める力」に分け、4B の K3 を「中から悪い」にした |
| 8 | 2B は ask・deny を消すと許可が広がる向きに働き、配った項目と自分で足した項目を見分ける手段が要る | 採った |
| 9 | 2D の K3 の「worktree ごとに増える」は C4 と合わない。symlink の問題もそのまま当てはまらない | 採った。worktree の記述を直し、symlink の記述を外した |

暫定の停止条件: ゲート1 で新しい種類の案が3つ出た。どれも 6節に位置を与えて採否を決めたので、2回目のゼロベースの問いは回さない。新しい種類がさらに出続けるかは、ゲート2 の設計SO で抜けとして問う。

## 8. 設計SO（ゲート2）

ゲート1 の採否を反映したこの文書に対して、`so-compare --codex-only` で、基準の当て方・論点ごとの推奨の根拠・判定の欄の立て方・抜けの8点を問うた。返したのは Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.163.0）で、123 秒・初回で返った。依頼文と出力は master の作業層 `tmp/385-permissions-canonical-scope/so-gate2-prompt.md` と `so-gate2/` にある。Codex は公式の文書のうち errors のページを取得できず、C8〜C10 を独立に確かめ直してはいない、と書いている。

結論は「直してから出す」で、指摘は8件（重さ 高2・中6）だった。根拠を一次情報に当て、8件とも採った。

| # | 重さ | 指摘 | 採否と直し |
|---|---|---|---|
| 1 | 高 | 「1B なら取り合いは起きない」は言い切れない。apply は宣言した項目だけを計算で変えるが、ファイル全体を置き換えるので、最後の確かめのあとの owner の手の編集は失われうる。書く主体に owner の手の編集が無い | 採った。論点2 を「承認の保存先とは取り合わないが、ユーザー層全体の同時の書き換えの取り合いは 1B でも残る」に直し、書く主体に owner の手の編集を足した。「窓は増えも減りもしない」は「取り合いの作りは変わらない」に弱めた |
| 2 | 高 | C18・C19 は Claude Code の振る舞いで、Codex と Cursor で hook の確認が既存の規則より先に効く根拠にはならない | 採った。4B と論点4 の理由をツールごとに分け、Codex と Cursor は確かめていないと書いた |
| 3 | 中 | 5C・5D の K1「良い」は、K1 を3つに分けた趣旨に反して甘い | 採った。5C は見分ける精度を方式次第とし、5D は 5C より広がるとは言えないとした |
| 4 | 中 | 1A' の利益を小さいとする根拠が弱い。更新時刻は確認の回数を示さない。本体が読み取りと見なす操作は判定器の呼び出しも減らない | 採った。利益は測っていないと書き、既定では配らず、確認が繰り返し出ると分かった候補だけを見直す形にした |
| 5 | 中 | sandbox の K2「悪い」は、切れる設定（`autoAllowBashIfSandboxed: false`・`allowUnsandboxedCommands: false`）を考えていない | 採った。5E' を足し、K2 を「良い」にした。採らない理由は K3 に移した |
| 6 | 中 | 「ユーザー層の hook なので全リポジトリで動く」には条件が欠けている。`disableAllHooks` と mod がある | 採った。公式の文書に当てると、リポジトリの設定が `disableAllHooks` でユーザー層の hook を切れることも分かった（C24）。C24・C25 を足し、論点4 に「効く」の条件と、どの案も破れない境界ではないことを書いた |
| 7 | 中 | 3A の対象に、最も広い裸の `Bash` と `Bash(*)` が書かれていない。3A は Codex と Cursor の規則を見ないことも書かれていない | 採った。検査の形を3種にし、対象を Claude Code の規則と明記した |
| 8 | 中 | 9節の判定の欄が、要るかどうか・どの方式か・やるかを1つの問いに束ねている。2B も、出どころが分からない項目の扱いを決めずに作るかだけを問うている | 採った。9節を分けて立て直し、2B' を足した |

指摘が無かった点は3つで、1A と 1A' を分けたこと、警告にとどめる判断、論点5 の結論を Claude Code の範囲で言っていることである。警告の判断には、検査の終了コードと適用が止まるかを分けて書くよう補足があり、論点3 にそう書いた（`--check` は読むだけで、赤にしても適用は止まらない。`scripts/sync.sh` の check の分岐で確かめた）。

## 9. owner に判定してもらうこと

推奨のとおりでよいか、別の案にするかを、次の問いごとに決めてほしい。問いは、要るかどうか・どの範囲か・どの方式か・いまやるか、に分けてある。

1. **allow を配るか**（論点1）: allow を正本に置かない（1B）でよいか。読み取りだけに選び直して配る形（1A'）を採るなら、選ぶ基準を誰が守るかも決める。
2. **本体の検査だけで足りるか**（論点5）: Claude Code について「足りない」と認めるか。認めないなら、3〜5 は要らない。
3. **今回の検査の範囲**（論点3）: 足すなら、対象を Claude Code の規則に限るか。hub の3ファイルに限るか、ほかのリポジトリを明示したときだけ数える形（3B）も足すか。
4. **検査の強さ**（論点3）: 警告にとどめる（3A）でよいか。警告が出たときに誰が見て直すか（owner か、sync を回した統括か）。
5. **実行時の対策**（論点4）: 実行時に確認を出させる経路を、別の issue に起こすか、当面は検査だけにするか。起こすなら、本命を hook（4B）にするか、ユーザー層の ask の規則（4A）にするか。Codex と Cursor を含めるか。
6. **狭める側を配るときの消し方**（論点2）: 狭める側の規則を配ることになった場合に、配った項目を自動で個別に消す形（2B）にするか、知らせて手で消す形（2B'）にするか。
7. **当面受け入れる危険**: 3〜5 が入るまでのあいだ、hub と別のリポジトリの手元の層に残っている広い規則（4節）をそのままにしてよいか。sandbox（5E・5E'）を候補として残すか、ここで捨てるか。

判定のあと、統括が実装の issue を起こし、その番号を decision に書く。

## 10. この単位の範囲の外で見つかったこと

- hub の `.claude/settings.local.json` の top-level に `defaultMode: "auto"` がある。公式のキーは `permissions.defaultMode` で、しかも `auto` は手元の層からは効かない（https://code.claude.com/docs/en/settings-reference 「permissions.defaultMode」）[verified]。この値は効いていない可能性が高い。直すかどうかは owner が決める。
- hub の手元の層に残る広い規則（`Bash(git:*)`・`Bash(curl:*)`・`Bash(gh api:*)`・`Bash(gh auth *)`・`Bash(python3:*)`・`Bash(bash -c ':*)` など）を見直すかは、owner が手で決めることで、この issue の判定とは別である。論点3の検査を入れれば、警告として一覧に出る。

## 11. 確かめていないこと

- `Bash(git:*)`・`Bash(curl:*)`・`Bash(gh api:*)` が auto モードで外されるかは、文書に無く、試していない（C16）。
- Claude Code 自身が承認を書いたときに ConfigChange が動くか（4C）。
- `/permissions` の画面で足した規則がどのファイルに書かれるか（論点2）。
- Codex と Cursor の hook が、確認を求められるか、既存の規則より先に効くか、対話でない実行でどうなるか（論点4）。
- mod がほかの経路で入っていないか、`skill-creator` が `tool.check` を扱うか（C25）。
- 許可規則を配ったときに、apply の置き換えの回数や時間が増えるか（論点2）。
- issue 本文の「削除前の allow は 129 件・Bash 112 件」。バックアップが残っていない。

---
title: "エージェントの実行を使い捨ての隔離環境に入れる — microVM の sandbox と、手元の Docker・worktree との使い分け（2026年11月 intake）"
date: 2026-11-27
status: research-complete
tags: [research-intake, execution-isolation, sandbox, microvm, docker-sandboxes, apple-container, experiment-runner, unattended-run, worktree]
sources:
  - https://docs.docker.com/ai/sandboxes/get-started/
  - https://docs.docker.com/ai/sandboxes/architecture/
  - https://docs.docker.com/ai/sandboxes/security/
  - https://docs.docker.com/ai/sandboxes/customize/
  - https://docs.docker.com/ai/sandboxes/install/
  - https://docs.docker.com/ai/sandboxes/configuration/environment-files/
  - https://docs.docker.com/ai/sandboxes/configuration/credentials/
  - https://docs.docker.com/reference/cli/sbx/
  - https://docs.docker.com/ai/sandboxes/usage/
  - https://docs.docker.com/ai/sandboxes/workflows/automation/
  - https://docs.docker.com/ai/sandboxes/agents/claude-code/
  - https://docs.docker.com/ai/sandboxes/faq/
  - https://docs.docker.com/ai/sandboxes/workflows/git/
  - https://docs.docker.com/ai/sandboxes/workflows/development/
  - https://docs.docker.com/ai/sandboxes/workflows/agent-skills/
  - https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/
  - https://www.docker.com/blog/why-microvms-the-architecture-behind-docker-sandboxes/
  - https://github.com/apple/container
  - https://code.claude.com/docs/en/sandboxing
  - https://www.m3tech.blog/entry/2026/06/22/170000
related_research:
  - docs/research/2026-07-27-branchbox-container-worktree-isolation.md（実行の隔離を保留にしたノート。本ノートが、保留にしたときと別の使い方を足す）
  - docs/research/2026-11-25-large-scale-agent-collaboration-intake.md（長く回す・並べて回すときの型。本ノートは、その実行の場所を扱う）
  - docs/research/2026-08-13-enforcement-placement-intake.md（強制力の置き場。隔離は実行基盤に置く強制に当たる）
related_ideas:
  - ideas/20260414/harness-architecture-layer-separation-control-loop.md
related_issues: [263, 430, 461, 565, 649, 681, 683]
next_step:
  trigger: "ハーネスの有無やスキルの版を比べる実験を回すとき（#430・#565・#263）/ エージェントを権限の確認なしで長く無人で回すとき / 複数のセッションが同時にサービスを立てて、手元の Docker でコンテナ・ポート・volume がぶつかったとき / 外の人が書いたコードを動かして確かめるとき"
  actions:
    - "最初に「実測で残る点」の1つ目（中の利用が定額のプランの枠に載っているか）を確かめる。ほかの作業で枠を使っていない時間帯に、中でだけ作業を流して、利用量の画面を見比べる"
    - "「ハーネスなし」の側を作るときは、sandbox が既定で置く設定と、ログインしたアカウントに紐づく MCP サーバが入っていることを前提にする。モデルは引数で指定する"
    - "ハーネスありの側を作るときは、user 層の hooks と settings を中に入れる手段を先に決める。文書は、手元の user 層の設定は中に入らないと書いている"
    - "worktree で作業する流れと組み合わせるときは、clone モードを main のチェックアウトから実行するか、worktree を直接 mount するかを先に決める"
    - "比較の実験に使うときは「比較の実験を回す仕組みを作るときに決めておくこと」節の5つを先に決める"
    - "普段の検証を sandbox に替えるかは「使い分け」節の3つの条件で判断する。当たらなければ手元の Docker のままにする"
    - "並べて立てるときは CPU とメモリを明示して絞る。既定は全 CPU と手元のメモリの半分である"
  referenced_by: "#430・#565・#263（比較の実験の題材）/ #649・#461（権限と危ないコマンドの扱い）/ #681 のノート（長く回すときの実行の場所）/ docs/research/2026-07-27-branchbox-container-worktree-isolation.md"
---

# エージェントの実行を使い捨ての隔離環境に入れる

## 概要

エージェントの実行を隔離する道具を3つ、公式の文書で比べた。Docker Sandboxes（CLI は `sbx`）、apple/container、Claude Code の sandbox 機能である。

調べたきっかけは2つある。1つ目は、ハーネスの有無やスキルの版を比べる実験を、手元の環境を汚さずに何度も回したいことである。2つ目は、エージェントを長く無人で回す検証をしたいことである。手元の会話の記録 30 日分では、入力を受けてから次の入力までエージェントが続けて動いた時間は最長で 80 分で、2時間を超えた例は無かった。長く回す事例の多くは権限の確認を全部外していて、外すなら手元の資格情報に届かない場所が要る。

実行の隔離は、2026-07 に一度調べて保留にしている（`docs/research/2026-07-27-branchbox-container-worktree-isolation.md`）。保留の理由は、作業の中心が文書とシェルスクリプトで、隔離の弱さが実害を出していないことだった。その判断は今も変わらない。本ノートが足すのは、そのときに無かった使い方である。

結論は3つある。

- 比較の実験と無人の長時間の実行には、Docker Sandboxes が合う。エージェントごとに microVM を立て、認証の実値を中に入れず、手元のリポジトリを読み取り専用で見せる形（clone モード）を持つ。
- 普段の検証を一律に sandbox へ替える必要は無い。替える価値があるのは、3つの条件のどれかに当たるときだけである。
- 無人で回す手順は、公式の文書に載っていて、実際に通った。定額のプランのログインは一度で済み、作っては捨てる sandbox に引き継がれる。実測で残るのは3点で、いちばん効くのは、中の利用が定額のプランの枠に載っているかである。

このノートは、文書を読んだ結果に、道具を入れて確かめた結果（「実測した点」の節）を足したものである。最初の版は、公式の文書の一部しか読まずに「書かれていない」と結論した点が多く、レビューで指摘を受けて読み直した。

## 記事情報

### A. Docker Sandboxes（公式の文書と公式のブログ）

- **タイトル**: Docker Sandboxes（文書一式）、Docker Sandboxes: Run Claude Code and Other Coding Agents Unsupervised (but Safely)、Why MicroVMs: The Architecture Behind Docker Sandboxes
- **URL**: https://docs.docker.com/ai/sandboxes/get-started/ ほか（frontmatter の sources）
- **著者/組織**: Docker
- **公開日**: ブログは 2026-01-30 と 2026-04-16。文書は随時更新
- **種別**: 公式文書とブログ記事（一次）
- **要約**: コーディングエージェントを、エージェントごとの microVM の中で動かす道具である。microVM は専用のカーネル・専用の Docker daemon・専用のネットワークを持ち、手元の Docker daemon には届かない。認証は手元の proxy が外向きの通信に差し込み、実値は VM に入らない。ネットワークは既定で拒否で、許可した宛先にだけ出られる。CLI と手元での実行は無料で、商用にも使える。

### B. apple/container（公開リポジトリ）

- **タイトル**: container
- **URL**: https://github.com/apple/container
- **著者/組織**: Apple
- **種別**: OSS リポジトリの README と技術の概要（一次）。使い方の文書は取得に失敗して読めていない
- **要約**: Mac の上で Linux のコンテナを、コンテナごとの軽量の VM で動かす道具である。Swift で書かれ、Apple silicon 向けに作られている。README は、macOS 26 以上が前提で、古い版は対応しないと書いている。技術の概要（`docs/technical-overview.md`）の「macOS 15 limitations」の節は、macOS 15 では一部の機能が使えず、その構成を推奨しないと書いている。エージェント向けの機能は README に無い。

### C. Claude Code の sandbox 機能（公式の文書）

- **タイトル**: Sandboxing
- **URL**: https://code.claude.com/docs/en/sandboxing
- **著者/組織**: Anthropic
- **種別**: 公式文書（一次）。全文のうち前半だけを原文で読み、後半は要約で読んだ
- **要約**: シェルのコマンドだけを、OS の仕組み（macOS は Seatbelt）で囲う機能である。ファイルの書き込み先とネットワークの宛先を絞る。既定は無効である。Read・Edit・Write の道具と、MCP サーバ・hook は囲いの外で動く。

### D. branchbox の記事（既存のノートで扱った記事を、ポートの観点で読み直した）

- **タイトル**: （エムスリーの技術ブログの記事）
- **URL**: https://www.m3tech.blog/entry/2026/06/22/170000
- **種別**: ブログ記事（一次）
- **要約**: apple/container と git の worktree を組み合わせ、ブランチごとにコンテナを立てる道具の紹介である。コンテナごとに別の IP を持たせ、ブランチ名をドメインにして開く。そのため、全部のブランチが同じポート番号を使える。

## 本質的パターンと詳細

確かめた度合いは `evidence-verification-rule` に従う。`verified` は、その道具の公式の文書に書かれていることを読んで確かめたものに限る。実際に動かして確かめたものは、このノートには無い。

| # | パターン名 | 本質 | 種別 | 検証/根拠 |
|---|---|---|---|---|
| P1 | 隔離する対象を3つに分けて見る | 検証されるコード・エージェントの操作・Docker daemon の3つのうち、どこまでを囲うかで道具が決まる | 設計原則 | `speculation`（3つの道具の文書を並べた、本ノートの整理） |
| P2 | 認証の実値を中に入れない | 手元の proxy が外向きの通信に認証を差し込む。中には置き換え用の値だけがある | 実装パターン | `verified`（A: credentials の文書・architecture の文書） |
| P3 | 手元のリポジトリを読み取り専用で見せ、中の clone で作業させる | 結果は、手元のリポジトリに足される remote から取り出す | ワークフロー | `verified`（A: `sbx run` の `--clone` の説明） |
| P4 | 出発点を定義で固定し、終わったら丸ごと捨てる | エージェントの版と道具を定義と digest でそろえる。準備を終えた sandbox を template として保存し、そこから始める | ワークフロー | `verified`（A: customize の文書・usage の文書。同じ状態から始まることを保証するとは書かれていない） |
| P5 | ポートの競合を、番号の付け替えか名前で解く | 手元の別々の番号に公開するか、環境ごとに IP と名前を持たせる | 実装パターン | `verified`（A: `sbx port` と `-p` の説明 / D: 記事） |
| P6 | 使い分けの3つの条件 | 権限の確認を外すとき・同時にサービスを立てるとき・信用できないコードを動かすときだけ、sandbox に替える | 設計原則 | `speculation`（本ノートの推論） |
| P7 | 比較の実験の5つの決めごと | 同じ出発点・複数回・答えを漏らさない・結果を外に集める・枠は全体で1つ | 評価手法 | `speculation`（本ノートの推論。3つ目は #681 のノートの P7 に基づく） |

### P1: 隔離する対象を3つに分けて見る

エージェントがコードを動かして確かめるとき、囲う対象は3つある。

| 対象 | 手元の Docker でコンテナを立てる（今の形） | Claude Code の sandbox 機能 | microVM の sandbox |
|---|---|---|---|
| 検証されるコード | 囲う | 囲う（シェルのコマンドとして動く分） | 囲う |
| エージェントの操作（ファイルの読み書き・コマンド） | 囲わない。エージェントは手元で動く | シェルのコマンドだけ囲う。ファイルの道具・MCP・hook は外 | 囲う。エージェントごと VM の中に入る |
| Docker daemon | 手元の1つを全員で使う | 手元の1つを使う | VM ごとに専用のものを持つ |

今の形で囲われているのは、検証されるコードだけである。エージェントが手元の Docker を操作できるということは、手元のディレクトリを mount したコンテナを立てられるということでもある（`speculation`: Docker の一般的な性質からの推論で、今回の文書には無い）。

Claude Code の sandbox 機能は、文書が自分で範囲を限っている。囲うのはシェルのコマンドだけで、読み取りは既定で機械のほぼ全体に及び、`~/.ssh` なども拒否しないかぎり読める（`verified`: C）。全体を囲いたいときは、Claude Code のプロセスごとコンテナか VM に入れるよう、文書が案内している（`verified`: C）。

### P2〜P4: Docker Sandboxes の作り

文書で確かめた点を並べる（どれも `verified`: A）。

- **隔離。** エージェントごとに microVM を立てる。専用のカーネルと専用の Docker daemon を持ち、手元の Docker daemon には届かない。sandbox どうしは直接通信できない。
- **認証。** 定額のプランは、中で `/login` して OAuth で入る。token は手元に残り、中には保存されない。API の鍵や GitHub の token は `sbx secret set` で手元に置き、既定ではすべての sandbox から使える。
- **ネットワーク。** 既定は拒否で、外向きの TCP は手元の proxy を通る。方針には、よく使う開発用の宛先を許す「Balanced」と、許可を自分で書く「Locked Down」がある。対話なしで `sbx policy init balanced` のように設定できる。既定の許可に広い範囲の指定が含まれることは、文書自身が注意している。
- **作業ツリーの渡し方。** 既定は、今いるディレクトリを読み書きできる形で mount する。`--clone` を付けると、手元のリポジトリは読み取り専用で見え、エージェントは中の専用の clone で作業する。手元のリポジトリには `sandbox-<名前>` という remote が足され、fetch で結果を取り出せる。追加のディレクトリは `パス:ro` で読み取り専用にして渡せる。
- **出発点と後始末。** kit という定義（YAML）を image として配り、digest で版を固定できる。`sbx rm` で、中のものがすべて消える。
- **無人で使う手順。** automation の文書に、一連のコマンドが載っている。`sbx create --name <名前> --clone claude .` で作り、`sbx exec <名前> -- claude --dangerously-skip-permissions -p "<指示>"` でエージェントを1回実行し、`git fetch sandbox-<名前>` で結果を取り出し、`sbx rm --force <名前>` で捨てる。`sbx exec` は前面で動き、中のコマンドの終了コードを返す。`--no-input` を付けると、質問が要る場面で止まらず、失敗として返る。端末が無いと確認の問いは失敗するので、`--force` を付ける。
- **権限の確認。** 中のエージェントは、既定で権限の確認なしで動く。Claude Code の既定の起動コマンドは `claude --dangerously-skip-permissions` である。FAQ は、理由を「The sandbox itself is the safety boundary.」と書いている。確認を戻すには、会話の中で `/permissions` を使うか、起動のコマンドを設定で変える。
- **手元の設定。** user 層の設定は中に入らない。FAQ は「Hooks, settings, and other files under directories such as `~/.claude` remain on the host.」と書いている。作業ディレクトリにあるプロジェクトの設定は、中で使える。例外は skills で、`sbx skills import` で手元の skills を共有の置き場に写すと、中の `/home/agent/.claude/skills` に読み取り専用で mount される。この共有の機能は experimental である。
- **中の Docker。** 中で image の build・コンテナの実行・Compose が使える、と development の文書が書いている。すべて sandbox 専用の daemon の中で動き、手元の `docker ps` には出ない。手元の daemon の image の置き場は共有せず、レジストリから取る。registry mirror の設定がある。中の image は、sandbox が在るあいだは残り、`sbx rm` で消える。
- **準備を終えた状態の保存。** `sbx template save <sandbox> <名前:版>` で、sandbox のファイルシステムを template として保存し、`sbx run -t <名前:版> claude` で始められる。mount したものと、中の Docker の置き場（`/var/lib/docker`）は含まれない。つまり、中の Docker の volume に入れた DB の中身は、template には入らない。エージェントの設定ファイルは、sandbox を作るたびに作り直される。手で入れた資格情報は template に埋め込まれる、と文書が注意している。
- **worktree。** clone モードは、main 以外の worktree の中からは拒否される。main のチェックアウトから実行する。worktree を直接 mount する使い方は載っているが、その場合、中のエージェントはファイルを読み書きできるだけで、commit や状態の確認はできない。ブランチは自動では作られない。
- **手元のサービス。** 中からは `host.docker.internal` で手元のサービスに届く。ネットワークの方針で、`sbx policy allow network localhost:<ポート>` のように許可する。
- **資源。** `--cpus` の既定は全 CPU、`--memory` の既定は手元のメモリの半分（512MiB〜32GiB の範囲）である。
- **入れる条件。** macOS 14 以上と Apple silicon。Docker Desktop は要らない。
- **エージェントなしでも使える。** エージェントの種類に `shell` があり、`sbx exec -it <名前> bash` で中に入れる。

成熟の度合いには注意が要る。設定をファイルに書く機能（`sbxenv.yaml`）、上流の proxy、外向きの UDP は experimental と書かれている。Linux への対応は、2026-01 のブログでは今後の予定、2026-04 のブログでは対応済みと読め、2つの記述が食い違っている。

### P5: ポートの競合の解き方

同じサービスを複数並べると、全員が同じポート番号を使おうとする。解き方は2つある。

| 項目 | Docker Sandboxes | apple/container と branchbox |
|---|---|---|
| 解き方 | 手元の別々の番号に公開する。番号を省くと、空いている番号が割り当てられる | 環境ごとに IP を持たせ、ブランチ名をドメインにする |
| ブラウザで開く先 | `http://localhost:<番号>`。番号は `sbx port ls` で見る。中のサーバは `0.0.0.0` で待ち受けさせる | 名前で開く。全員が同じポート番号を使える |
| 複数のサービスの一式 | 中の Docker daemon で動かす | compose に当たるものがまだ無い、と記事の著者が書いている |
| 動く条件 | macOS 14 以上 | macOS 26 以上 |

DB を含む一式を包むなら、中に Docker daemon を持つ形のほうが合う。名前で開ける点は、apple/container の形のほうが分かりやすい。

## 使い方を2つに分ける

### 使い方1: 比較の実験と、無人の長時間の実行を回す場所

エージェントを中に入れて回し、終わったら捨てる。成果物は「判断を保留した材料」である。何も取り込まないので、途中で止まっても壊れるものが無い。人の判断を待って止まることも無い。機械で合否を決められる修正の作業に限らず回せる点が、ほかの長時間の実行と違う。

### 使い方2: サービスの開発環境を包んで並べる場所

アプリ・DB・web サーバの一式を、ブランチごとに別の sandbox で立てる。worktree が分けるのはファイルだけである。この形なら、DB・コンテナ・ネットワークも分かれる。あるブランチのマイグレーションが別のブランチの DB を壊す、という事故が構造として起きない。人が使う隔離環境としても成り立つ。

この使い方は、branchbox のノートが再訪の条件に挙げた3つ（ポートの衝突・マイグレーションの衝突・どのブランチの画面か分からない）のうち、前の2つを解く。3つ目は、名前で開ける apple/container の形のほうが解きやすい。

## 使い分け（P6）

普段の検証を、一律に sandbox へ替える必要は無い。次の表は、本ノートの推論である（`speculation`）。

| 作業 | 使う場所 | 理由 |
|---|---|---|
| 文書・スクリプト・レビュー | worktree | 実行するものがほぼ無い |
| 1つのセッションが、自分のリポジトリのテストを流す | 手元の Docker | 並列の衝突が無く、コードも信用できる。pull 済みの image と build のキャッシュが使える |
| 短い確認を何度も繰り返す | 手元の Docker | VM の起動とログインの手間が、確認そのものより重い |
| 権限の確認を外して、長く無人で回す | sandbox | 手元のファイル・資格情報・鍵に届かせない |
| 複数のセッションが、同時にサービスを立てる | sandbox | 手元の daemon は1つで、コンテナの名前・ポート・compose のプロジェクト名・volume がぶつかる |
| 外の人が書いたコードや、初めて入れる依存を動かす | sandbox | コンテナは手元とカーネルを共有するが、microVM は共有しない |
| 比較の実験 | sandbox | 同じ出発点から何度も立てて捨てる |

sandbox に替えて失うものは3つある。起動の重さ、資源（既定のままだと2つで手元のメモリが埋まる）、手元のキャッシュである。中の Docker daemon は手元の image の置き場を共有しないので、image はレジストリから取り直しになる（`verified`: A の usage の文書）。sandbox どうしで共有されるかは書かれていない。

## 比較の実験を回す仕組みを作るときに決めておくこと（P7）

ここは本ノートの推論である（`speculation`）。

1. **同じ出発点から回す。** 題材と image を固定し、変えるのは比べたい1点（ハーネスの有無・スキルの版・モデル）だけにする。
2. **同じ条件で複数回回す。** エージェントの結果は毎回ぶれる。1回ずつの比較では、差なのか偶然なのかを見分けられない。
3. **答えを漏らさない。** 前回の結果やメモを中に入れない。隔離した環境は、手元の設定を引き継がないことが利点になる。ハーネスありの側にだけ、明示して入れる。
4. **結果を外に集める。** 会話の記録・差分・機械の指標（テストの合否・token・ターン数・時間）を、捨てる前に外へ出す。LLM による採点は参考にとどめ、最後は人が見る。
5. **枠は全体で1つ。** いくつ並べても、同じプランの上限を分け合う。

実験を回す役は、エージェントではなく、決まった動きをするプログラムにする。環境を立て、条件を1点だけ変えてエージェントを走らせ、決めた回数を繰り返し、結果を外へ集めて、環境を捨てる。

## 文書で分かった点と、実測で残る点

最初の版は、次の10点を「文書に書かれていない」としていた。読む範囲が足りなかった。公式の文書の、対話なしの使い方・エージェントごとのページ・FAQ・git の使い方・サービスの開発・skills の共有のページに、8点の答えがあった。

| # | 点 | 文書の答え | ページ |
|---|---|---|---|
| 1 | 対話なしで、エージェントに指示を渡せるか | 渡せる。作る・実行する・取り出す・捨てるの一連のコマンドが載っている | automation |
| 2 | 定額のプランの `/login` が sandbox ごとに要るか | 書かれていない。API の鍵が無ければ中で `/login` を使う、とだけある。自動化の文書が挙げるのは、API の鍵などを手元の secret として置く方法である | claude-code・automation |
| 3 | 中で、権限の確認が既定で外れるか | 外れる。sandbox そのものが安全の境界、という理由である | FAQ・claude-code |
| 4 | 手元のエージェントの設定が中に入るか | user 層の hooks・settings は入らない。プロジェクトの設定は使える。skills は共有の置き場から入る | FAQ・claude-code・agent-skills |
| 5 | 同時にいくつ立てられるか。ディスクの量 | 書かれていない | — |
| 6 | 中の Docker daemon が image を取り直すか | 手元の置き場は共有せず、レジストリから取る。registry mirror の設定がある。sandbox どうしの共有は書かれていない | usage |
| 7 | 中で、複数のサービスの一式が立つか | build・コンテナの実行・Compose が使えると書かれている。実際に立つかは実測が要る | development |
| 8 | 準備を終えた状態を保存して始められるか | できる。`sbx template save`。中の Docker の置き場は含まれない | usage |
| 9 | git の worktree を作業ツリーとして渡せるか | clone モードは main のチェックアウトからだけ。直接 mount はできるが、中から git の操作はできない | usage・git |
| 10 | 中から、手元のサービスに届くか | 届く。`host.docker.internal` と、方針での許可 | development |

表の答えは、文書を読んだものである。動かして確かめてはいない。

### 実測した点（2026-11-27）

道具を入れ、空のリポジトリを題材に sandbox を作って確かめた。版は sbx v0.54.1、中の Claude Code は 2.1.332 である。ここに書くのは、実際に動かして見た結果である。

- **定額のプランのログインは、一度で済む（上の表の 2）。** sandbox の中で `/login` を1回行うと、手元の sbx の secret に `anthropic` が「oauth configured」として1件できる。範囲は全 sandbox 共通である。そのあと、新しく作った別の sandbox でも、捨てて作り直した sandbox でも、ログインなしでエージェントが動いた。作っては捨てる無人の使い方が成り立つ。最初の1回だけは、人の操作（ブラウザでの認証）が要る。
- **ログインの前は、対話なしの実行が通らない。** 「Not logged in」と返る。終了コードは 0 だった。終了コードだけで成否を判定できない。
- **対話なしの一連の手順が通った。** 作る・エージェントを1回実行する・`git fetch sandbox-<名前>` で commit を取り出す・捨てる、の順である。ファイルを作って commit させる指示は 7 秒で終わった。`--output-format json` を付けると、ターン数・所要時間・費用の見積もり・使ったモデルが JSON で返る。比較の実験の指標に使える。
- **対話の画面も、外から操作できた。** 切り離した tmux の中で `sbx run` を起動し、入力を送って画面を読めた。
- **作る時間。** 初回は、image（約 372MB）のダウンロードを含めて 37 秒だった。2回目以降は約 6 秒だった。
- **資源。** CPU を 2、メモリを 4GB に絞った空の sandbox を2つ動かしたとき、sbx 関連のプロセスのメモリは合計で約 2.4GB、sbx のデータの置き場は約 1.5GB だった。
- **使うには Docker のアカウントが要る。** `sbx login` を済ませるまで、`sbx ls` も失敗する。
- **ネットワークの方針は、初期化するまで使えない。** `sbx policy init balanced` を先に実行する。
- **Homebrew は、この道具の cask を信頼済みにするまで読み込まない。** `brew trust --cask docker/tap/sbx` を先に実行する。tap 全体ではなく、この cask だけを信頼すれば足りた。

文書に無かった点が4つある。

- **中の `~/.claude` は空ではない。** 手元の rules と skills は入っていなかった。一方で、sandbox が自分で置いた `CLAUDE.md` と、hooks を含む `settings.json` があった。「ハーネスなし」の側は、何も入っていない状態ではなく、sandbox の既定の設定が入った状態になる。
- **中の既定のモデルは、手元と違った。** 手元の設定は引き継がれないので、モデルは実行のたびに引数で指定する。
- **ログインしたアカウントに紐づく MCP サーバが、中でつながっていた。** 素の状態で比べたいなら、これも外す必要がある。
- **中の Claude Code は、利用を API のものとして表示する。** 状態の画面のログインの方法は API のアカウントと出て、利用量の画面には、プランの枠ではなく費用の見積もりが出た。認証は手元の proxy が差し込み、中のクライアントは本物の token を持たない。そのため、クライアントがプランの種類を知らないのだと思われる（`speculation`）。

### 実測で残る点

1. **中の利用が、定額のプランの枠に載っているか。** 上の表示のため、中からは確かめられなかった。secret が OAuth として保存されていることは、定額のアカウントでのログインと合う。ただし、利用量の画面で増え方を見て確かめてはいない。ほかの作業で枠を使っていない時間帯に、中でだけ作業を流して見比べる必要がある。
2. **同時にいくつ立てられるか。ディスクをどれだけ使うか（表の 5）。** 空の sandbox 2つの値は上に書いた。上限は見ていない。
3. **複数のサービスの一式が、実際に立つか（表の 7）。** DB の中身を持ち越す方法も合わせて見る。template には中の Docker の置き場が入らないので、初期化を毎回流すか、別の持ち越し方が要る。

### 当リポジトリへの当てはめに効く点

- **ハーネスありとなしの比較。** user 層に配っている rules・hooks・settings は、中に入らない。「なし」の側は、何もしなくても成り立つ。「あり」の側は、hooks と settings を中に入れる手段を別に用意する必要がある。skills だけは、共有の置き場から入れられる。入れる手段としては、template に焼く・プロジェクトの設定として作業ツリーに置く、が考えられるが、文書に手順は無い（`speculation`）。template は、エージェントの設定ファイルの一部を持ち越さないと書かれているので、焼けるかは実測が要る。
- **worktree で作業する流れとの組み合わせ。** clone モードは main のチェックアウトからしか使えない。worktree を直接 mount すると、手元を汚さない利点が減り、中から commit もできない。どちらで回すかを、先に決める必要がある。

## 実装参照候補

| # | 対象 | リポジトリ/ファイル | ライセンス | 確認元 | 流用形態 |
|---|---|---|---|---|---|
| 1 | `sbx`（Docker Sandboxes の CLI） | https://docs.docker.com/ai/sandboxes/ | CLI と手元での実行は無料（商用も可）と文書にある。ソースのライセンスは確かめていない | 文書の overview | そのまま利用 |
| 2 | container | https://github.com/apple/container | Apache-2.0 | リポジトリの `LICENSE` のファイル | 今は見送り（macOS 26 が前提） |

## 資産マッピング結果

### トラックA: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ/新規知見 |
|---|---|---|---|
| P1・P6 | `docs/research/2026-07-27-branchbox-container-worktree-isolation.md` | 拡張 | 保留の判断は変えない。再訪の条件に、比較の実験と無人の実行を足す |
| P2・P6 | #649（別のエージェントの sandbox と権限の既定）・#461（危ない形のコマンドを扱う hook） | 補強 | 権限を絞る代わりに、届く範囲を絞るという別の解き方 |
| P7 | #430（TDD の必須化）・#565（日本語のスキル）・#263（文体の評価） | 補強 | 比較の実験を回す土台になる |
| 使い方1 | `docs/research/2026-11-25-large-scale-agent-collaboration-intake.md` | 補強 | 長く回す・並べて回すときの実行の場所 |
| P1 | `ideas/20260414/harness-architecture-layer-separation-control-loop.md`（UI・execution・workspace の3種の隔離） | 補強 | execution の面を分ける具体的な道具 |

### トラックB: 新規導入候補

| パターン | 既存対応物 | 導入形態 | 実現可能性メモ |
|---|---|---|---|
| sandbox を立てて、実測で残る点を確かめる | なし | `experiment`（一部を実行済み） | ログインの持ち越しと、対話なしの一連の手順は確かめた。枠への載り方・同時に立てられる数・サービスの一式は残っている |
| 実験を回す役（決まった動きをするプログラム） | なし | 実測のあとに判断 | 手順の骨組みは automation の文書の一連のコマンドで足りる。ログインの扱いが決まってから設計する |

## アクション判定

| パターン | 種別 | 理由 |
|---|---|---|
| P1〜P7 | `archive-note` | 採否を決める材料として残す |
| branchbox のノートの再訪の条件 | `enrich-existing` | 保留にしたときに無かった使い方を足す |
| 実測で残る3点 | `experiment`（一部を実行済み） | ログインの持ち越しと対話なしの手順は、道具を入れて確かめた。残りを行うかは別に決める |
| 全体 | `create-issue`（#683） | このノートを残す作業そのもの |

## 原文を読む価値

- **A の automation の文書と FAQ。** 無人で回す手順と、権限・設定の扱いが書かれている。無人で回すかを考えるなら、最初に読む。
- **A の architecture と security の文書。** 隔離の境界と、認証の差し込み方が具体的に書かれている。入れる前に読む価値がある。
- **A の 2026-04 のブログ。** なぜコンテナではなく microVM なのかの説明がある。
- **C。** Claude Code の sandbox 機能が何を囲わないかが、はっきり書かれている。この機能だけで足りると考える前に読む。
- **D。** 既存のノートを参照すれば足りる。

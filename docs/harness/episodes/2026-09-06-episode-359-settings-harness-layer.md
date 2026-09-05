---
id: "01M1S6TSYTCKQHZ0S5HM1NFK6P"
title: "#359 段階1 — Claude 設定のハーネス層を hub 正本から適用する調査と plan"
date: 2026-09-06
type: episode
status: draft
related:
  - type: derived_from
    ref: "https://github.com/stlwolf/ai-development-hub/issues/359"
    reason: "本 episode は issue #359 段階1（調査と plan）の実行記録"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/348"
    reason: "outputStyle キーと output-styles の配布経路が本件の仕組みに乗る"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/313"
    reason: "sync --check の配布対象網羅。drift 検査の置き場が同じ"
tags: [harness, settings, sync, drift]
promotion: []
---

# #359 段階1 — Claude 設定のハーネス層

## なぜこの作業が始まったか

owner が 2026-09-05 に「重要な設定は hub に正本を置き、sync で適用する。手元の状態を見に行かなくて済むようにし、変更は大元を書き換えて直す」という方針を出した。Claude Code の `~/.claude/settings.json` はこの形になっておらず、hub が管理しているのは `hooks` と `statusLine` の2キーだけである。段階1は実装せず、調査と plan だけを行って owner の判断を仰ぐ。

## V-1 調査

### 期待値の宣言（測る前に書く）

測る前に、こうなっているはずだと考えたことを先に書いておく。

- `~/.claude/settings.json` の top-level キーは issue #359 本文が挙げた11個（`hooks` / `statusLine` / `model` / `effortLevel` / `autoMode` / `enabledPlugins` / `skipDangerousModePermissionPrompt` / `theme` / `tui` / `remoteControlAtStartup` / `outputStyle`）で全部だろう。
- 2キーだけになっているのは、CLI が同じファイルを書くという衝突を避けた意図的な妥協だろう（issue 本文の読み）。
- `sync.sh --check claude` は symlink の整合しか見ていないだろう（issue 本文の記述）。

結果は3つとも外れた。以下に順に書く。

### 発見1: キーの母集団は issue の列挙より1つ多い

`~/.claude/settings.json` の top-level キーを実体から数えると12個で、issue #359 本文の列挙に無いキーが1つあった。`skipWorkflowUsageWarning` である。

```text
autoMode  effortLevel  enabledPlugins  hooks  model  outputStyle
remoteControlAtStartup  skipDangerousModePermissionPrompt
skipWorkflowUsageWarning  statusLine  theme  tui
```

issue 本文の列挙は書かれた索引であって母集団ではなかった。分類案を「issue の列挙」の上に組むと、この1キーが最初から分類の外に落ちる。

### 発見2: 2キーになったのは妥協ではなく、別々の必要から順に積み上がった結果

issue 本文は「2キーだけのマージは、この衝突を避けた妥協と読める」と書いている。記録を辿ると、そうではなかった。

- `hooks` のマージは `16119d8`（PR #23・hooks 基盤整備 H-0）で入った。commit 本文の記述は「Claude Code は settings.json の hooks キーを jq マージ（バックアップ付き）」だけで、他のキーをどうするかという議論は無い。hooks を配るには settings.json に書くしか道が無かったので書いた、という形である。
- `statusLine` のマージは `aac6c3c`（PR #245・#239 段階1 PR-A）で、hooks の 8か月ほど後に、拍動 producer という全く別の目的で入った。ここでも「どのキーを hub が持つべきか」という問いは立てられていない。
- `sync.sh --check` は `348d675`（PR #70）で入り、そのとき同時に settings.json の hooks セクション比較も入っている。

つまり「2キー」は境界の設計ではなく、2つの機能がそれぞれ必要としたキーを足した結果である。境界はまだ一度も決められていない。この件で決めるのが初回になる。

昇格の印: 「既存の状態は妥協である」という読みが記録で否定された事例。curated な集合の欠落を埋めよという指示に対する当たり方の実例として残す価値があるか。

### 発見3: `sync.sh --check claude` は既に settings.json の hooks を見ている

issue 本文は「`--check` は symlink の整合しか見ない」と書いているが、実際には `scripts/sync.sh:163-171` に hooks セクションの比較がある。

```bash
if [[ -f "${base}/settings.json" ]]; then
    expected_hooks="$(jq -S '.hooks' "${canonical}/hooks/claude.hooks.json" 2>/dev/null)"
    actual_hooks="$(jq -S '.hooks' "${base}/settings.json" 2>/dev/null)"
    if [[ "${expected_hooks}" != "${actual_hooks}" ]]; then
        warn "  Hooks section differs in settings.json"
        has_diffs=true
    fi
fi
```

これは「キーの drift 検査を新設する」のではなく「既にある1キー分の検査を、正本が持つ全キーへ一般化する」という作業になる、ということを意味する。設計の出発点が変わる。

なお `statusLine` は sync が配るのに `--check` が見ていない。既存の検査には既に穴が1つある。

### 発見4: 同型の問題を Codex 側で既に解いている先例がある

`scripts/sync/apply-codex-notify-config.sh` が `~/.codex/config.toml` に対して、ちょうど今回やろうとしていることをやっている。冒頭のコメントがそのまま設計根拠になっている。

> config.toml は Codex が実行時に書き換える状態ファイルのため symlink 不可。dotfiles の symlink 運用にも乗らない。そこで「正本キーをハーネス側で管理し、有無を検知して挿入する冪等 apply」とする。

この先例から3つ引き出せる。

- **symlink 案（issue の選択肢 c）は既に一度否定されている。** ツール自身が書き戻すファイルだから、という理由で。同じ理由が Claude の settings.json にもそのまま当たる。
- **「適用」には2つの意味があり、Codex 側は弱い方を選んでいる。** このスクリプトは「キーが無ければ挿入する」だけで、値が正本と違っていても直さない。owner の方針の「変更は大元を書き換えて直す」を満たすには、無いときに入れるだけでなく、違っていたら合わせる側が要る。ここは Claude 側で先例をなぞると方針から外れる。
- **管理範囲を宣言する仕組みがある。** TOML では `# >>> ai-hub ... (managed) >>>` のコメント標識で挟んでいる。JSON にはコメントが書けないので同じ手は使えないが、「どのキーが hub のものか」を宣言する何かは要る、という要求そのものは同じである。正本プロファイルの file がそれを兼ねられる。

Codex の `config.toml` には `--check` に相当する drift 検査が無い。Cursor 側の `~/.cursor/cli-config.json` も Cursor CLI が書く同型のファイルで、hub は触っていない（`.bad` という破損時の退避ファイルが残っているので、CLI が書き戻していること自体は確かである）。両方とも本件の範囲外だが、同じ問題であることは plan に follow-up として書く。

### 発見5: drift 検査を jq で書くときの落とし穴

キーの一覧を取ろうとして `jq '[paths(scalars)]'` を使ったところ、`remoteControlAtStartup` だけが出てこなかった。値が `false` だからである。

jq の `paths(f)` は各パスの値を `f` に通した結果を `select` に渡す。`scalars` は値をそのまま通すので、値が `false` のときは `select(false)` になって落ちる。`null` も同じく落ちる。

drift 検査は「正本にあるキーが手元でどうなっているか」を全部見なければ意味がないので、この落とし穴を踏むと boolean の `false` と `null` を静かに見逃す検査ができあがる。しかも見逃す方向に倒れるので、テストで気付きにくい。設計では `paths(scalars)` ではなく `leaf_paths` 相当を自分で書くか、`getpath` で正本側のパスを回して比較する形にする。

昇格の印: jq の `paths(scalars)` が false と null を落とす件。drift 検査を書く人が必ず踏む場所なので negative knowledge の候補。

### V-1 で読んだもの・読んでいないもの

読んだもの。

- `scripts/sync/sync-claude.sh`（全 363 行のうち hooks / statusLine のマージ部 190-308 行を精読）
- `scripts/sync.sh`（全 299 行・`--check` の経路と exit code を精読）
- `scripts/sync/sync-codex.sh` の main と `apply-codex-notify-config.sh`
- `scripts/sync/sync-cursor.sh` の配布対象
- `~/.claude/settings.json` のキー構造（値は読まない・書かない）
- `git log -S` で hooks / statusLine / settings.json 導入の3コミットとその本文
- `~/.cursor` `~/.codex` のディレクトリ一覧（読むだけ）

まだ読んでいないもの。

- Claude Code 公式ドキュメントの settings 一覧と changelog（別セッションに調査を出しており、戻り次第この節に追記する）
- `projects/orchestration-engine/tests/test_sync_claude_statusline.sh` の中身（陽性対照の書き方の先例として plan 段階で参照する）

### 発見6: 公式のキーは 225 個ある。個人層を列挙で閉じることはできない

公式の settings reference の生 Markdown を取得し、`### ` 見出しからキー名を機械的に数えた。

```bash
curl -sSL -o cc-settings-ref.md "https://code.claude.com/docs/en/settings-reference.md"
grep -oE '^### `[a-zA-Z][a-zA-Z0-9._]*`' cc-settings-ref.md | tr -d '`' | sed 's/^### //' | sort -u | wc -l
# => 225
```

owner の手元にある12キーは、この 225 の部分集合である。ただし `skipWorkflowUsageWarning` だけは 225 に入っていない（公式に文書化されていないキーを CLI が書いている）。

ここから、issue #359 の「2層に分類する」という枠組みを少し組み替える必要が出る。ハーネス層は「hub が正本を持つキー」として列挙できるが、個人層を列挙しようとすると 225 マイナス数個を書き並べることになり、しかも CLI の更新でキーが増えるたびに古くなる。実際に管理できるのは「hub が正本を持つキーの集合」1本で、それ以外はすべて hub が触らない、という形になる。「個人層」は列挙する対象ではなく、残余の呼び名になる。

### 発見7: LLM の要約が母集団を2キー取りこぼした

このキー一覧は最初、ページを取得して要約させる形で取った。その要約は「`theme` と `tui` はこのページに存在しない」と答えたが、上の `grep` では両方とも存在した。ページが長くて後半が切れていたのに、切れたことを「無い」と報告していた。

母集団を数えるときに要約を経由すると、切り詰めが欠落として返ってくる。件数を根拠にするなら、生の本文に対して決定的な抽出をかけて数える。

昇格の印: 要約経由の母集団カウントが truncation を「不在」として返した実例。

### 発見8: 設定の優先順位は5段で、user settings が最下位

公式ドキュメントの記述をまとめると次のとおり（高い順）。

1. managed settings — `managed-settings.json`（macOS では `/Library/Application Support/ClaudeCode/`）、MDM、claude.ai console
2. コマンドライン — `claude --settings <file-or-json>`
3. project local — `.claude/settings.local.json`
4. project 共有 — `.claude/settings.json`
5. user — `~/.claude/settings.json`

同じキーが複数にあるとき、上の段の値が勝つ。ただしリスト型のキーは段をまたいでマージされる（`permissions.allow` など）。`hooks` も「ファイルをまたいでマージされ、互いを置き換えない」と明記されている。

hub がいま書いている `~/.claude/settings.json` は最下位である。これは2つの意味を持つ。

- hub の値は、プロジェクト側に同じキーがあれば負ける。`outputStyle` がまさにこれに当たる（発見9）。
- `hooks` はマージされるので、最下位でも消えない。hub の hooks が効いているのは、hooks がマージ型だからである。

### 発見9: `/config` の output style は project local に書く。user settings の値は負ける

公式の output styles ページに、選択がどこへ保存されるかが明記されている。

> Terminal: run `/config` and select Output style to pick a style from a menu. Claude Code saves your selection to `.claude/settings.local.json` at the local project level.

`outputStyle` の Scope は `Any file` なので user settings に書くこと自体はできる。しかし `/config` の menu で一度でも選ぶと、そのプロジェクトの `.claude/settings.local.json` に書かれ、以後そのプロジェクトでは user settings の値が負け続ける。

#348 で `outputStyle` をハーネス層に置くなら、この経路を owner に伝えた上で「menu で選ばない」運用にするか、プロジェクト側の値を drift として検知する対象に含めるかを決める必要がある。段階1の範囲では判断点として上げるにとどめる。

もう1つ、output style は「セッション開始時に一度だけ読まれ、変更は `/clear` か新セッションから効く」と明記されている。sync した直後の走っているセッションには効かない。

### 発見10: キーごとの書き込み契約（公式本文から）

| キー | Scope | CLI が書くか |
|---|---|---|
| `hooks` | Any file・ファイル間でマージ | 書かない |
| `statusLine` | Any file | `/statusline` が書く |
| `autoMode` | User or managed（project/local からは効かない） | 記述なし |
| `outputStyle` | Any file | `/config` の menu が project local へ書く |
| `model` | Any file | `/model` で Enter すると user settings へ書く。`s` を押せば保存しない |
| `effortLevel` | Any file | `/effort` は `effortLevel` ではなく `modelSettings` へ書く。同じファイル内では `modelSettings` が優先 |
| `enabledPlugins` | Any file | `/plugin` と `claude plugin enable` が書く |
| `skipDangerousModePermissionPrompt` | User, local, or managed | 確認ダイアログを一度承認すると user settings へ `true` を書く |
| `tui` | Any file | `/tui fullscreen` `/tui default` が書く |
| `theme` | Any file | `/config` が書く |
| `remoteControlAtStartup` | Any file | 記述なし |
| `skipWorkflowUsageWarning` | 公式に記載なし | 不明 |

CLI が user settings へ書くと明記されたキーは、この12個の外にも文書上20個以上ある（`autoCompactEnabled` `editorMode` `fileCheckpointingEnabled` `autoUpdatesChannel` `pluginConfigs` など、`/config` の各行がそれぞれ書く）。「CLI が書くキー」も列挙で閉じる対象ではない。

### 発見11: settings.json が書けないときの挙動が公式に書かれている

これが本件の設計にいちばん効いた。

> When you save a choice for new sessions from inside Claude Code, such as a default model with `/model`, Claude Code writes it to your user settings file, `~/.claude/settings.json`. If you can't write to that file, for example because another tool generates it or links it to a read-only copy, the change applies to the current session and is gone in the next one. Set the key in the tool that generates the file, or replace the file with one you can write to.

「別のツールがこのファイルを生成している、あるいは読み取り専用の複製へリンクしている」場合が公式に想定されていて、そのときの挙動も、取るべき対処も書かれている。対処は「生成元のツールでキーを設定せよ」であり、これは owner の方針とそのまま同じである。

つまり「hub が settings.json 全体を生成し、CLI からは書けなくする」は、壊れる使い方ではなく、公式が想定している使い方の1つである。代償は、セッション内で `/model` などを保存しても次のセッションに残らないこと。

### 発見12: `--settings` はどのファイルにも書き戻さない

> `--settings` lasts one session and doesn't write to any file.

`claude --settings <path>` は優先順位の2段目で、user / project / local のどれよりも上に乗る。しかも CLI はこのファイルへ書き戻さない。ハーネス層をこのファイルに置けば、drift は起こりようがない（CLI が触らないので）。

代償は、起動のたびにこのフラグを渡す必要があることである。フラグを渡し忘れた起動では、ハーネス層が丸ごと効かない状態で走る。

昇格の印: 「正本から適用する」の実現手段として、settings.json へ書く以外に、CLI が書かない上位スコープへ置くという系統がある。issue の3案（プロファイル深マージ / キーごと file / 全体 symlink）はすべて settings.json へ書く系統だった。

### 発見13: 全体 symlink には既知の不具合がある

Claude Code の issue #40857（closed）は、`.claude/settings.local.json` を symlink にしておくと、CLI の書き込みで symlink が通常ファイルに置き換わると報告している。原因は atomic write（一時ファイルへ書いて rename）で、rename が symlink 自体を差し替えるためと説明されている。

これは worktree の `settings.local.json` についての報告であって `~/.claude/settings.json` そのものではないので、同じことが起きるという直接の証拠ではない。ただし書き込み経路が同じなら同じ結果になる。加えて hub 側の `sync-claude.sh` は既に、対象が symlink なら触らずに `Skipping (symlink or special file)` と警告して抜ける。Codex の `apply-codex-notify-config.sh` も冒頭で「ツールが実行時に書き換える状態ファイルなので symlink 不可」と明言している。

全体 symlink（issue の案 c）は採らない方向で十分な材料が揃った。

## V-2 設計判断（ゲート1: ゼロベース代替探索）

### 初期案セットと、そこにあった暗黙の前提

issue #359 が挙げた案は3つで、いずれも「`~/.claude/settings.json` に書く」という前提を共有していた。

- (a) 1本のプロファイル file を深マージ
- (b) キーごとの file を併存
- (c) settings 全体を symlink

この前提そのものを外すと、CLI が書かない上位スコープへ置くという別の系統が出る。優先順位が5段あり、user settings が最下位だという事実（発見8）から導かれる。

### 探索木

```text
DJ-1: ハーネス層をどこに置き、どう適用するか
├── (a) 1本のプロファイルを settings.json へ深マージ（初期案）
│     差分軸: 書き込み先=user settings / 適用=sync / 未宣言キーは保持
│     採否: 採用（下記の理由）
├── (b) キーごとの file を併存（初期案）
│     差分軸: 正本の粒度だけが (a) と違う
│     採否: 部分採用。hooks と statusLine は既に独立 file にある理由があるので残し、
│           スカラーのキーだけを1本のプロファイルに集める混成にする
├── (c) settings 全体を symlink（初期案）
│     差分軸: 適用=リンク / 書き込み衝突あり
│     採否: 棄却。CLI の atomic write が symlink を通常ファイルに置き換える既知の不具合
│           （Claude Code issue #40857）。hub の sync も Codex の apply も既に同じ理由で避けている
├── (d) managed-settings.json に置く（ゼロベースで発見）
│     差分軸: スコープ=最上位 / CLI は書かない / 置き場=システムディレクトリ
│     採否: 棄却。macOS では /Library/Application Support/ClaudeCode/ で root 権限が要る。
│           かつ「何を設定しても上書きできない」ので owner がセッション単位でも変えられなくなる。
│           drift が構造的に起きないという利点は大きいが、代償が owner の運用を壊す
├── (e) claude --settings <hub のプロファイル> で起動する（ゼロベースで発見）
│     差分軸: スコープ=2段目 / CLI は書き戻さない / 適用=起動フラグ
│     採否: 棄却（ただし利点は (a) に取り込む）。CLI が書かないので drift は起きず、
│           project local より上なので outputStyle の負け（発見9）も解消する。
│           しかし起動のたびにフラグが要り、渡し忘れた起動ではハーネス層が丸ごと消える。
│           IDE 拡張・デスクトップアプリ・他ツールが起こすセッションには渡せない。
│           静かに全部効かなくなる失敗の仕方が (a) より悪い
└── (f) settings.json 全体を hub が生成し読み取り専用にする（ゼロベースで発見）
      差分軸: hub が file 全体を所有 / CLI の保存は次セッションで消える
      採否: 棄却。owner の方針の「個人と機種の好みは hub が触らない」と両立しない。
            全体を生成するなら theme / tui も hub が持つことになり、持たないなら
            毎回の sync で消えてしまう。未宣言キーを保持するなら、それは (a) と同じ深マージである
```

未探索のまま残す軸を1つ書いておく。`~/.claude/settings.json` を dotfiles 側の管理に渡し、hub は canonical を提供するだけにする案は評価していない。理由は、これが hub と dotfiles の役割分担そのもの（issue の論点4）で、owner の判断点として立てる方が筋だからである。plan では判断点として上げる。

昇格の印: 「CLI が書かない上位スコープへ置く」という系統は、drift 検査そのものを不要にする筋だった。採らなかったが、将来 drift が実際に頻発したときの逃げ道として残す価値がある。

### ゲート1の結果: 反証され、設計を直した

`oe-refute --claim tmp/claim-359-dj1.md --rubric exploration --lanes 2` を回した。判定は `refuted` で、2レーンとも実質的な反証を返した。audit id は `202609051644559FW4FCS3Q1SR`。

指摘は5つあり、確かめたところ4つが事実だった。

1. **hooks は深マージではなく全置換である。** 現行の sync は `jq '.hooks = $hooks'` で、既存の hooks を丸ごと置き換えている。一方 statusLine は既存コマンドを退避して包む合成をしている。「宣言したキーを深くマージする」1つの動作では、この2つのどちらも表現できない。
2. **検査は効いている値を保証しない。** `--check` が見るのは優先順位の最下位（user settings）だけである。このリポジトリ自身に `.claude/settings.local.json` があり、`defaultMode` と `permissions` を持っている。上位のファイルが同じキーを持てば、user settings が正本どおりでも実際には効かない。
3. **削除の伝播が決まっていない。** 正本からキーを外したとき、手元から消えるのか残るのか。現行のマージは消さない。
4. **段階導入の余地がある。** 検査だけ先に入れて観測し、適用は後から入れる分け方ができる。
5. **初期値の作り方**が抜けている。手元の現状から宣言の初期値を起こす手順が要る。

確かめて事実でなかったのが1つある。公式の plugin として配る案は、hooks / agents / skills / commands / output-styles のファイルは同梱できるが、plugin の `settings.json` で適用できるのは `agent` と `subagentStatusLine` の2キーだけだと明記されている。本件の中身である設定キーの配布はできない。ただしファイル配布の側だけを見れば plugin 経路は成立するので、後述の孤児 symlink 問題を根本から消す道ではある。今回の範囲外として follow-up に落とす。

実効値の検査については、公式にこう書かれている。

> The line confirms which files Claude Code read; it doesn't show which file supplied each key.

`/status` は読み込んだファイルの一覧を出すだけで、どのキーがどのファイル由来かは出さない。つまり実効値を外から機械的に取る手段は公式には無い。検査にできるのは「hub が持つファイルが正本と一致しているか」と「上位のファイルが同じキーを持っていないか（上書きの検知）」の2つまでである。前者は完全に、後者は列挙可能な範囲で決定的に検査できる。

反証を受けて直した設計は次のとおり。

- 宣言ファイルは「キーの一覧」ではなく「キーと適用のしかたの対」を持つ。適用のしかたは `replace`（丸ごと置換・hooks）、`merge`（オブジェクトを重ねる）、`wrap`（既存を包む・statusLine の専用処理へ委譲）、`set`（スカラーを設定）、`absent`（手元から消す）の5つ。
- 削除は既定では伝播させない。宣言から外しても手元の値は残す。消したいときは `absent` と明示する。黙って消すと個人の設定を巻き込む事故になる。
- 検査は「宣言と手元の一致」に加えて「上位スコープの同名キーの存在」を報告する。実効値は検査できないと明記する。
- 検査を先に入れ、適用の一般化を後に入れる。検査だけの段階では既定動作を一切変えない。

昇格の印: 反証が「1つの適用動作では既存の2キーすら表現できない」を突いた。既存実装の形を見ずに一般化の設計を始めたのが原因で、同種の作業に効く教訓になりうる。

## 追加スコープ: 配布先に残る壊れた symlink

作業中に統括から追加の依頼が来た。rule を退役させると `~/.claude/rules/` に壊れた symlink が残り、sync も `--check` も掃除も検出もしない、という指摘である。

母集団の見方で確かめた。原因は構造的で、rules に限らない。

`--check` の走査はすべて正本の側から回している。`check_symlinks_dir` は `find "${source_dir}" -name "${pattern}"` で正本のファイルを列挙し、それぞれに対応する配布先を見に行く。`check_skill_dirs` も正本のディレクトリを回す。配置側の `sync_md_files` も同じ形である。

したがって正本から消えたファイルの配布先は、配置でも検査でも一度も訪れられない。訪れられない場所に残ったリンクは、解決先が消えているかどうかを誰も見ない。これは rules / skills / commands / agents / hooks / orchestration-spec のすべてに同じ形で当てはまる。Cursor と Codex の配布先も同じ関数を使っているので同じである。

実測では、いま壊れたリンクは0件だった。

```text
rules: symlink=14 / 壊れ=0     skills: symlink=28 / 壊れ=0
commands: symlink=7 / 壊れ=0   agents: symlink=3 / 壊れ=0
hooks: symlink=8 / 壊れ=0      orchestration-spec: symlink=1 / 壊れ=0
```

0件なのは、まだ正本からファイルを消していないからであって、検査が効いているからではない。PR #361 が最初の該当になる。

`sync-bin.sh` には近い先例がある。配布対象の定義が空なら差分なしを名乗らせずに終了する、という判断が書かれている。

> 母集団が壊れているときに「差分なし」を名乗らせない。0 件のまま回すと 0 回のループが緑を返し、検査が素通しになったことが緑と区別できなくなる。

ただし `sync-bin.sh` も配布対象の名前一覧から回しているので、一覧から外した（退役した）コマンドの孤児は同じく検出できない。先例は姿勢としては正しいが、この穴は埋めていない。

対処の設計は、正本の側からの走査に加えて、配布先の側からも走査を1本足す形になる。配布先の各項目を見て、symlink であり、解決先が消えているか、解決先が canonical 配下を指しているのに正本にその file が無いなら、孤児として列挙する。

消し方には注意が要る。worktree から sync すると配布先のリンクが worktree を指すようになり、その worktree を消すとリンクが壊れる。この壊れ方の正しい対処は「消す」ではなく「張り直す」である。だから掃除の既定は報告にとどめ、実際に消すのは明示的に指示されたときだけにする。実ファイル（手で置いた `~/.claude/output-styles/readable-conversation.md` のようなもの）は対象にしない。

昇格の印: 「正本の側からだけ走査する検査は、正本から消えたものの後始末を構造的に見られない」。#313 の配布対象網羅と同じ根で、検査設計の一般則になりうる。

## ゲート2の結果: 3レーン中2レーンが返り、設計をもう一度直した

`so-compare -f tmp/so-359-design.txt --with codex,claude,cursor -o tmp/so-359-design` を回した。

codex レーンは利用上限に当たって空で返った（1回やり直しても同じ）。claude と cursor の2レーンが返っている。弱 SO の規約では、実返却が1レーン以上あれば partial として開示して進んでよいので、そうする。出力は `tmp/so-359-design/` に残っている。

2レーンが独立に同じ穴を突いてきた点が5つある。同じ指摘が別々に出たので、確度が高いと見た。

1. **同じファイルを別々に2回書いている。** いま hooks と statusLine は、それぞれ読んで書き戻している。その間に CLI が別のキーを書くと、後段の書き戻しが古い像を土台にして、CLI の書き込みを消す。項目を増やせば窓も増える。直し方は、宣言された項目を1回の jq で合成して置き換えを1回にし、置き換える直前に読んだときの digest を確かめ直すこと。
2. **包む処理の一致の定義が無い。** 包んだ後の statusLine は正本のファイルと永遠に一致しない。だから値の一致で検査を書くと恒常的に赤になる。いま statusLine が配られているのに検査されていないのは、これが理由に近い。直し方は、操作の種類ごとに一致の述語を変え、包む処理は適用と比較を対で出させること。そして「比較の述語を出せない項目は宣言に書けない」を規則にすること。
3. **配列を扱う操作が enum に無い。** `permissions.allow` のような配列は、置換だと owner が足した項目が消え、オブジェクトの深い重ね合わせでは表現できない。
4. **宣言の単位が top-level のキーだと粗すぎる。** `env` の中の1変数だけ所有する、といったことが書けない。宣言の形は契約なので、後から変えると全部書き直しになる。
5. **上位スコープの警告を1つの文言で出すと誤解される。** hooks とリスト型は段をまたいでマージされるので、プロジェクト側にあるのは「hub のものが無効」ではなく「追加される」。スカラーは上位が勝つので影になる。同じ文言だと owner が両者を区別できない。

片方のレーンだけが出した指摘で採ったものもある。

- 「一度も適用していない」を独立した状態として報告する。現行は settings.json が存在するときだけ比較するので、ファイルごと無い機種では差分なしと表示される。
- 実効値は CLI からは取れないが、読めるファイルの範囲で「どのファイルが勝つか」は計算できる。plan に「実効値は検査できない」と書いていたのは強すぎた。計算値であると添えた上で出す形に直した。
- 孤児の条件を3分類にする。正本配下を指していて正本に無いものだけを掃除の対象にし、正本の外を指す壊れたリンクは報告だけにする。当初の条件のままだと、別の仕組みが張った壊れたリンクを掃除フラグで消してしまう。
- 掃除を最後の PR に置く。その時点で走査器が知らない配布の種類が残っていると、正しい配備を孤児と誤認して消す危険がある。
- 棄却案にプロジェクト設定を配布先とする案を足した。検討した痕跡が無い、という指摘だったので、検討して落とした理由を書いた。

昇格の印: 「配るのに検査していない項目がある」の原因が「一致の見方が決まっていないから」だった。配布の設計に対する一般則になりうる。

昇格の印: 別々のレーンが独立に同じ5点を突いた。合意の重みの根拠として、レーン間の独立性が効いた実例。

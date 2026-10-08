---
id: "01M4DT43Z3C9G18MQV2FT5HP00"
title: "#415 Claude Code のアイドル時の圧縮（idleCompaction）を hub の設定の宣言で止める"
date: 2026-10-08
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/415"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/415#issuecomment-6060507646"
    reason: "着手時の認識合わせ（確定版）。5項目に成果物で答える"
  - type: reference
    ref: "docs/harness/plans/2026-09-06-plan-359-settings-harness-layer.md"
    reason: "宣言駆動の設計（apply は宣言した項目にしか触らない・known-keys は警告どまり）"
tags: [claude-settings, idle-compaction, settings-harness, sync]
---

# #415 Claude Code のアイドル時の圧縮（idleCompaction）を hub の設定の宣言で止める

## Context（なぜこの作業が始まったか）

Claude Code 2.1.291 以降に入った「アイドル時の圧縮」で、約54分放ったセッションの会話が要約に置き換わる。owner の裁定（2026-10-08）は「止める」。文脈の切れ目は引き継ぎと委譲で自分たちが決めている、という理由である。軽微修正扱いで plan は書かず、設計SO は省く（owner の了承 2026-10-08）。実装SO（弱・Codex 1レーン）と Copilot 1ラウンドとテストは通す。

## Step 0: 着手（2026-10-08 22:00 頃）

- baseline: master `6021ddb`（`git fetch` 後の `origin/master` と一致）。
- worktree: `wt switch --create 'chore/#415_idle_compaction_off' --base master`。
- 先例: `disableAgentView` の項目（#338・PR #402）。値の置き場 `canonical/claude/settings.values.json` はそのとき新設されたもので、`test_sync_output_styles.sh` が使い捨ての木へ複写する一覧も宣言の `source.file` から導く形に直してある。同じファイルに値を足すだけなら、複写の一覧を触る必要はない。

## Step 1: 上流の断定の裏取り（本体の文字列・公式ドキュメント）

#415 本文と確定版コメントの断定を、note に写す前に一次情報へ当てた（注入 knowledge `01KYMRE1NC7XX6N66RQ0MGGHF1`）。

当たったもの:

- 手元の版は `claude --version` → `2.1.294 (Claude Code)`。
- 本体 `~/.local/share/claude/versions/2.1.294` の設定スキーマに `idleCompaction:()=>H().optional().describe("Set to false to stop Claude Code from compacting a long conversation while the session is idle. Setting it to true does not turn idle compaction on."` がある。`idleCompaction` の文字列は 2.1.280 に0件、2.1.291 に3件。
- 読み出しは `function kxt(){return os("idleCompaction",!0).value}`。既定値は true で、false を置くと判定関数が `idle_compaction_off` を返して圧縮しない。
- 判定関数の順序は、サーバー側の機能フラグ `tengu_sunny_locket` の mode が off → `disabled`、`autoCompactEnabled` が false → `compaction_off`、`idleCompaction` が false → `idle_compaction_off`、以下 prefix の変化・キャッシュ期間が1時間でない・期限切れ・トークン数が最小未満・新しいリクエストあり・使用量の上限近く、である。
- 発火の時点は「最後のやり取り＋（キャッシュの期限−最後のやり取り）×0.9」で、0.9 は機能フラグで 0.5〜0.95 の範囲に変えられる。タイマーを仕掛けるのは直前のリクエストのキャッシュ期間が `1h` のときだけである。
- 最小トークン数は `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS ?? フラグの minTokens` で、数値なら `max(100000, n)`、無ければ 200000。
- 公式の settings reference（2026-10-08 22:10 頃に取得）と CHANGELOG（2.1.290〜2.1.294 を含む）に `idleCompaction` もアイドル時の圧縮も載っていない。

当たらなかったもの・食い違ったもの:

- 「設定はセッション起動時に読まれ、いま動いているセッションには効かない」（#415 本文の「やらないこと」・確定版の「issue に書いていないが要ること」・brief の scope）は、一次情報で裏が取れなかった。公式の settings ページの「When edits take effect」節は、設定ファイルを監視して変更を読み直し、多くの項目を再起動なしで実行中のセッションに反映すると書いている。起動時だけ読む項目として挙がっているのは `model` と `effortLevel`・`modelSettings` などで、`idleCompaction` は公式に載っていないので挙がっていない。本体の側も、この設定を起動時ではなく、タイマーが発火した時点の判定（`kxt()`）で読んでいる。設定の読み出し `os()` は呼ばれるたびにスコープごとの設定を引き直す形である。ただし、読み直しがこのキーに及ぶことは実測していないので、未確認として扱う。note には「実行中のセッションに効くかは未確認。確実にしたいセッションは起動し直す」と書き、断定の強さを上げない。
- 「最小トークン数は環境変数で上げられる（下限 100,000）」は、正確には「環境変数で 100,000 以上の任意の値にできる」で、既定の 200,000 より下げることもできる。中間案の1行にはこの形で書く。

昇格の印: 公式に載っていないキーを宣言で配るときの note には、本体の版と読み出し箇所と、実行中のセッションに効くかの確認状態を書く、という型

## Step 2: known-keys に足さないと決めた（2026-10-08 22:12 頃）

`scripts/sync/check-claude-settings.sh` の (6)「宣言した項目名の綴り」節は、一覧に無いキーに `warn` を出すだけで、`has_diffs` にも終了コードにも効かない。一覧の用途は、ファイルの冒頭にあるとおり綴りの確認だけである。

選択肢は2つあった。

- 足す: 警告は消える。ただし check は一覧に載ったキーを「公式の一覧にあります」と印字するので、公式に無いキーについて事実と違うことを言う。区別して印字するには check 本体を直す必要があり、この単位の範囲を超える。
- 足さない（採った）: check は毎回「idleCompaction は公式の一覧にありません」と警告するが、これは事実どおりで、緑は妨げない。公式に載って一覧を取り直せば、自然に一覧へ入って警告が消える。

#415 本文の「一覧が検査に使われているなら足す」は、一覧に無いことが検査を止めるなら足す、という意味で読んだ。実際には止めないので、足す理由が無い。代わりに、一覧の冒頭に「宣言で使うが、ここに載せないキー」として `idleCompaction` と理由を3行のコメントで残した（check は `#` 行を読まない）。後から誰かが警告を消そうとして一覧に足すのを防ぐためである。宣言の note にも、この警告は意図どおりだと書いた。

## Step 3: 宣言・値・テストを直し、変更前の master で落ちることを確かめた

先例の形（`op: replace`・`scope_behavior: override`・値は `settings.values.json`）が `idleCompaction` にも成り立つかを確かめた（注入 knowledge `01KZVHE0KQ5VCX0SXH0F4SM14D`）。本体の設定の読み出し `os()` は、優先度の高いスコープから順に見て最初に見つかった値を返すので、スカラーとして上書きされるキーであり `override` が合う。値が `false` なので、apply が `false` を書き落とさないこと、check が「キーが無い」と「値が違う」を分けることを、テストで見た。先例との違い（公式の一覧に無いこと、`true` が既定に戻すだけで強制的に有効にしないこと）は note に書いた。

note に入れたもの（brief の6点との対応）:

- なぜ止めるか: owner の裁定（2026-10-08・#415）。
- 止めても残るもの: 通常の自動圧縮と手動の `/compact`。
- 失うもの: 1時間以上放ったセッションに戻った最初の応答が、会話全体をキャッシュなしで読み直すので重くなり、使用量も増える。
- 公式に無いキーでサーバー側のフラグで有効化される機能であること: 2026-10-08 時点で settings reference にも CHANGELOG にも無い。
- 起動時に読まれる点: Step 1 のとおり裏が取れなかったので、「実行中のセッションに効くかは未確認。確実に止めたいセッションは起動し直す」と書いた。brief の文面（起動時に読まれ、既存のセッションには効かない）からは意図して変えている。
- ON に戻す手順: `disableAgentView` の note と同じ形。

ほかに、check の警告が意図どおりであることと、中間案（環境変数 `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`）を1行ずつ入れた。

テストに足した検査:

- `test_apply_claude_settings.sh`: [4] と [17] の「宣言の項目だけ」を4項目にした。[51] で、正本の値が `false` であること、`true` の settings が `false` に直ること、キーが無い settings に `false`（`null` ではない）が作られることを見る。
- `test_check_claude_settings.sh`: `build_green` に `idleCompaction` を足し、[1] に一致の検査を足した。[25] で値だけ崩すとその項目だけが差分に出ること、[26] でキーが無いと「未適用」と出て「差分」とは言わないこと、[27] で公式の一覧に無いキーが警告だけで緑を妨げないことを見る。

結果（注入 knowledge `01M2DRCP3QSG4NQWHNY6DSD3NJ`）:

| 対象 | 変更後の枝 | 変更前の master `6021ddb` にテストだけ重ねた木 |
|------|-----------|------------------------------------------|
| `test_apply_claude_settings.sh` | PASS=221 FAIL=0（変更前 215） | PASS=215 FAIL=6 |
| `test_check_claude_settings.sh` | PASS=94 FAIL=0（変更前 83） | PASS=88 FAIL=6 |

master で通った追加の検査は、終了コードが 0 であることと、個人層が無傷であること、他の項目が巻き込まれないこと（`ncc`）で、どれも見張りの役である。変化を見分ける検査はすべての節に1つ以上あり、そのすべてが master で落ちた。shellcheck は2本とも通った。sync の起動テスト（`test_sync_claude_statusline.sh` 17 PASS、`test_sync_output_styles.sh` 18 PASS）も通った。後者は宣言の `source.file` から複写の一覧を導くので、値のファイルに1行足しただけでは複写の一覧を直す必要がなかった。

check の確かめ方:

- 手元の `~/.claude/settings.json` の写しに、枝の宣言で apply してから check を当てた。apply は4項目を適用して rc=0、check は rc=0 で「宣言どおり」になり、`idleCompaction` の綴りの警告だけが出た。宣言外のキーは apply の前後で変わっていない（`jq -S 'del(.idleCompaction)'` の比較で一致）。実物の `~/.claude/settings.json` は shasum が前後で一致し、書き換えていない。
- worktree から `./scripts/sync.sh --check claude` も走らせた（読むだけ）。rc=1 で、settings の節は既存3項目が一致し、`/idleCompaction` だけが「未適用」だった。sync はマージ後に統括が走らせるので、この時点では未適用が正しい。ほかに symlink のずれが 54 件出たが、これは worktree から走らせると比べる先が worktree のパスになるためで、この変更とは関係がない。brief の受入「`./scripts/sync.sh --check claude` が足した項目を含めて通る」は、マージと sync の前には文面どおりには満たせない。写しへの apply と check で代わりに確かめ、マージ後の sync のあとに統括が文面どおり確かめる形にした。

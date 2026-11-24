---
id: "01M870BCW2H9M737WP0FB4NM7X"
title: "#650 Claude Code と Codex の記憶の仕組みを調べ、ハーネスに入れられる調整と制御の候補を並べる"
date: 2026-11-24
type: plan
status: in-development   # ゲート3 は owner が承認した（2026-11-25・会話）
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/650"
    reason: "本 plan の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/650#issuecomment-7134862521"
    reason: "確定版の認識合わせ。範囲・進め方・層の分け方の正本"
  - type: reference
    ref: "docs/research/investigations/2026-10-30-model-effort-routing.md"
    reason: "手で書く調査の置き場の前例（#575）。「状態: 調査中（追記前提）」と根拠の札の形を借りる"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-11-13-decision-562-codex-child-launch.md"
    reason: "Codex の子の中で記憶の整理の会話が走ったことの記録。この issue のきっかけ"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/649"
    reason: "Codex の既定の設定は owner が Codex と決める範囲。記憶の設定もこれに重なる"
  - type: reference
    ref: "docs/harness/episodes/2026-11-24-episode-650-agent-memory-survey.md"
    reason: "この plan の実行記録"
tags: [harness, memory, claude-code, codex, research]
so:
  design: weak
  impl: weak
  reason: "成果はドキュメントだけで可逆。設計SO は so-compare の Codex 1レーン（返らなければ Cursor に1回だけ切り替える）。実装SO は、Codex が文書を確かめて埋める段のあとに Cursor 1レーン（Codex と違う会社のモデルで、Codex が直した箇所も見る）"
---

# #650 Claude Code と Codex の記憶の仕組みを調べ、ハーネスに入れられる調整と制御の候補を並べる

## 背景

- 2026-11-15 に、engine が起こした Codex の子の中で、Codex の記憶を整理する会話が裏で動いた。頼んだ作業の内容が owner の Codex の記憶に入り、頼んでいない報告も親へ送ってきた（#562 のマージのあとの確かめ・PR #648 と #651）。
- 認識合わせの深掘りで、owner と次のことを決めた（確定版のコメント）。
  - この issue はハーネスの層を扱う。エージェントごとに記憶をどう扱うかで、Codex も含む。
  - engine の層は別の issue にする。利用者ごとにハーネスがある前提で、engine の動きを変な方向に走らせないためにだけ、エージェントに依らない形で記憶を制御する話である。
  - この issue は、いまの状態を調べる調査の issue にする。ハーネスに何を入れるかは決めない。ほかの要素と絡んで発展する余地を残す。
  - 進め方は、Claude Code の側（この担当）が両方を先に調べて文書を埋め、そのあと Codex にその文書を渡して、書いたことが本当か・抜けがないかを確かめさせて埋めさせる。Codex への依頼の書面はこの担当が書く。

## この plan の範囲

入れるもの:

1. 調査の文書を1つ `docs/research/investigations/` に足す。
2. 文書に、issue の「調べること」の6項目を Claude Code と Codex の両方について書く。6項目は次のとおりで、文書の表の行はこの名前で呼ぶ。
   1. 書き手と時機: 何を・いつ・誰が書くか。人の指示なしに書かれるのはどんなときか。
   2. 範囲: リポジトリごとか、全体か。分けられるか。別のリポジトリの作業の内容が混ざる道はあるか。
   3. 読み込まれ方: 毎回の会話に何がどれだけ入るか。大きくなったときに何が起きるか。
   4. 人が手を入れる口: 読む・直す・消す・書かせない・特定の会話だけ書かせない、のそれぞれができるか。設定の鍵と、その効く範囲。
   5. ほかのエージェントに起こされた会話: engine の子・非対話の実行でも書くか。止められるか。
   6. 外へ出る道: 記憶の中身が、公開のリポジトリの文書・commit・issue に写る道はあるか。
3. 文書に、ハーネスに入れられる「調整」と「制御」の候補を、入れられるかどうかと根拠と一緒に並べる。
   - 調整: 何を書くかを文で導くもの。効くかどうかはモデル次第（例: 決まりの文・`CLAUDE.md`・`AGENTS.md`）。
   - 制御: 設定・hook・権限で機械的に止めたり絞ったりするもの（例: 記憶を書かせない設定の鍵、記憶のフォルダへの書き込みを止める hook）。
4. Codex に渡す依頼の書面（git の対象外）と、Codex が埋めたあとの確かめ。
5. この plan と episode（`docs/harness/`）。

入れないもの:

- ハーネスに何を入れるかの決定と、実際に入れる変更（設定・hook・決まりの文・sync）。次の issue で扱う。
- engine の層（engine の子の記憶をどう扱うか）。別の issue にする。起票の案は最後に出す。
- issue の「決めること」の4つ。調査の文書の材料にするだけで、決めない。
- 記憶の棚卸しと整理（いまある 79 件を直す・消す）。

PR は1つにする。

## 設計判断

### DJ-1 文書の置き場と形

- **推奨: `docs/research/investigations/2026-11-24-agent-memory-harness-control.md` に、前例（`2026-10-30-model-effort-routing.md`）と同じ「調査メモ」の形で置く。** 冒頭に作成日・更新・状態（「調査中（追記前提）」）・対象・根拠の札の説明を置く。発展する前提の調査で、あとから追記する形が合う。
- 捨てた案:
  - `docs/harness/discussions/` に discussion として置く形。discussion は設計を探る文書で、この issue は決める前の現状の調査である。`document-format.md` の「遷移規則」節（§10）は、調査の成果を蒸留5層の外の研究ノートとして置くと決めている。
  - `research-intake` の形。外部の記事を起点にする手順で、この issue に合わない。

### DJ-2 文書の構成

次の順に節を置く。

1. 目的と範囲（ハーネスの層だけ・engine の層は外）。
2. 比べた表（6項目×2）。各マスに根拠の札と出典を付ける。表のあとに、項目ごとの詳しい節を置く。
3. 別のモデルが挙げた3つの観点（記憶に入った指示が後の会話で効くか・1件ごとの出どころを区別できるか・消したあとに作り直されるか、写しが残るか）。両方について書く。
4. ハーネスに入れられる候補の表。列は、候補・調整か制御か・どのエージェントか・hub のどこから配るか（決まりの文・設定の harness 層・hook・sync）・効く経路・止められる範囲・入れられるか・根拠・確かめていない部分。
   - 効く経路は、記憶が書かれる道のどれに効くかを書く。道は少なくとも3つを分ける。モデルが会話の中でファイルの道具を使って書く道、裏で動く整理の処理が書く道、人や別のプロセスがファイルを直接書く道である。設定の鍵や hook があるだけでは、どの道を止められるかは決まらない。
5. Codex による確かめの記録。Codex が直した行と足した行の一覧。
6. 観察の記録。Codex に渡す前とあとの `~/.codex/memories` の状態など。
7. つながりうるもの（hub の knowledge item・engine の negative knowledge loop・engine の層の issue）。

### DJ-3 根拠の札と、公開の決まり

- 札は前例と同じ4つにする。`[verified]`（公式の文書かリポジトリの実体で確かめた）、`[verified-local]`（手元で実際に実行して確かめた）、`[unverified-summary]`（二次の情報・確かめていない要約）、`[speculation]`（根拠が無い推測）。
- 表のどのマスにも、出典か、出典が無い理由を書く。`[speculation]` のマスと分からなかったマスには、見た資料・確かめていない部分・分からなかった理由を書く。根拠のある答えと、分からなかったことを、読む人が見分けられるようにする。
- 根拠の種類を分ける。過去の記録（#562 の PR の本文など）を開いて確かめられるのは「その記録にそう書いてある」ことまでで、いまも同じであることは確かめていない。過去の記録には日付と版を添え、いまの公式の文書・いまの実装・今回の実測と分けて書く。
- 記憶の中身は写さない。書くのは、置き場・ファイルの名前の形・件数・大きさ・更新時刻・設定の鍵の名前・git の commit の数と HEAD が変わったかだけにする。記憶のフォルダの git の commit の件名は、中身を含みうるので写さない。Codex の記憶は全部のリポジトリで共通なので、ほかのリポジトリの内容を含みうる。
- commit の前に、公開する差分のすべて（調査の文書・plan・episode）と commit の本文に、記憶の中身とほかのリポジトリの名前などが入っていないことを確かめる（`CLAUDE.md` の「公開リポジトリとしての決まり」）。

### DJ-4 Claude Code の側の調べ方

- 公式の文書: 記憶・設定・hook の頁を読む。設定の鍵は hub の既知の鍵の一覧に `autoMemoryEnabled` と `autoMemoryDirectory` がある（`canonical/claude/settings-known-keys.txt:39-40`）ので、その意味と効く範囲を公式の文書で確かめる。
- 手元の実物: `~/.claude/projects/` の下の記憶のフォルダの数・件数・索引の大きさ。`~/.claude/settings.json` に記憶の鍵があるか（いまは無い）。
- このセッションに渡されている system prompt の記憶の節（何を書く・書かない・どう書く）。手元で見えるものなので `[verified-local]` とし、どの版の Claude Code かを添える。
- worktree の扱い: このセッションは worktree で動いているが、記憶の置き場は本体のリポジトリのパスのフォルダである。engine の Claude の子も worktree で動くので、子の作業が hub の記憶に入る道があるかを確かめる（公式の文書と手元の観察）。
- 非対話の実行（`claude -p`）で書くかと、`autoMemoryEnabled` を切ると止まるかを、リポジトリの外の一時ディレクトリで1回ずつ試す（DJ-6）。

### DJ-5 Codex の側の調べ方（この担当が先に書く分）

- 公式の文書: Codex の記憶と設定の頁（`[features]` の `memories`・`[memories]` の `generate_memories` と `use_memories`）。
- 手元の実物: `~/.codex/memories` の構成（ファイルの名前と大きさ・要約の件数・git の履歴）と `~/.codex/config.toml` の鍵。`codex --help` などの CLI の出力。
- #562 の記録: 記憶の整理の会話が子と同じプロセスで走り、記録を残さないこと（PR #648 の本文）。
- 非対話の実行: 2026-11-24 に認識合わせのために `codex exec`（so-compare の Codex のレーン）を1回打った直後は、`~/.codex/memories` の git の HEAD と主なファイルの更新時刻は変わらなかった。同じ日の夜に見直すと、`raw_memories.md` と要約の一部の更新時刻が 20:33 に変わっていた。同じ日に owner の別の Codex の会話もいくつも動いていたので、どの会話が書いたかは決められない。観察の記録には、変化があったことと、決められない理由だけを書く。
- Codex の側は、Codex の確かめ（I8）で直される前提の初稿として書く。

### DJ-6 手元で試すことの範囲

- **推奨: Claude Code の側で2回だけ試す。** 試すのは `claude -p`（非対話の実行）に「この語を覚えて」と頼んだときに記憶が書かれるかと、`autoMemoryEnabled` を切ると書かれなくなるかである。
  - 試すごとに、リポジトリの外に別の一時ディレクトリを作る（試しAは `exp-a`、試しBは `exp-b` の名前を含める）。同じディレクトリを使うと、前の試しのファイルが残って比べられない。
  - 始める前に、`~/.claude/projects/` の下のフォルダの一覧を控える。試しのあとにもう一度控え、増えたフォルダだけを試しが作ったものとする。
  - 試しA: 設定を変えずに打つ。見るのは、増えたフォルダの下の `memory/` にファイルができたかである。
  - 試しB: `--settings` で `autoMemoryEnabled: false` を渡して打つ。見るものは試しAと同じである。
  - 判定: 試しAで書かれ、試しBで書かれなければ、「この条件では、設定を切ると書かれなかった」と書く（`[verified-local]`・版と日付を添える）。試しAで書かれなければ、比べられないので「設定の効果は確かめられなかった」と書く。どちらの場合も、書かれなかったことは、機械的に禁じられていることの証明にはしない。
  - 後片づけ: 一覧の差で特定した、試しが作ったフォルダだけを、scratchpad の `650-claude-experiment/` へ移す。ほかのフォルダには触らない。移したフォルダの名前を episode に書く。消すかどうかは owner が決める。
- Codex の側は試さない。Codex の設定は owner と Codex が決める範囲で、Codex の確かめの段で Codex 自身が見る。
- 捨てた案: 制御の候補（hook で書き込みを止めるなど）をすべて試す形。何を入れるかを決める次の issue で、選んだ候補だけを試すほうが手戻りが少ない。

### DJ-7 Codex への依頼の書面

- 置き場は worktree の `tmp/650-agent-memory/codex-brief.md`（git の対象外）。
- 書くこと:
  - 目的と、埋める文書のパス。
  - やること。文書の一文ごとに、一次の出典（公式の文書・手元の設定やファイル・CLI の出力）で確かめ直し、札を付け直す。Codex の側を中心に、Claude Code の側も見てよい。文書に無い項目は足す。直した行と足した行は「Codex による確かめの記録」の節に一覧で書く。
  - 守ること。記憶の中身を写さない。ほかのリポジトリの名前を書かない。文書と `tmp/650-agent-memory/` のほかは書き換えない。commit しない。Codex の設定を変えない。
  - 終わったら、owner に一言で知らせる。
- Claude Code の側の結論に引きずられないよう、「同意で済ませず、出典を開いて確かめた行にだけ `[verified]` を付ける」と書く。
- owner が Codex に渡す1行も、この担当が用意する。

### DJ-8 ブランチ名

- 承認のあとに、いまのブランチ `claude/650-assignment-b5f3d2` を `docs/#650_agent_memory_survey` に変える（`branch-naming`。成果がドキュメントだけなので `docs/`）。

## ゲート1（ゼロベースの代替探索）

前提を外して、この issue のやり方を組み直した。

- 外した前提: 「調査の文書を1つ書く」。
- 組み直した形:
  - 案X: 文書を書かず、制御の候補を先に実際に試し、効いたものだけを記録する。速いが、「入れられるか」の答えが試した候補に限られ、公式の文書が言う範囲（できるが試していないもの）が残らない。owner が決めた「調査の issue」の形とも合わない。
  - 案Y: Claude Code と Codex で別々の文書にする。項目ごとに並べて差を出す issue の進め方と合わない。
  - 案Z: Codex の確かめを省き、Cursor の SO だけで済ませる。Codex の仕組みを Codex 自身に確かめさせる、という owner の進め方を外れる。
- 結果: いまの形（1つの文書・Claude Code の側が先・Codex が確かめる）に戻った。案X からは、安く試せる2回だけを DJ-6 に取り込んだ。

## 設計SO（ゲート2・弱・Codex 1レーン）

- 2026-11-24・so-compare の Codex 1レーン（gpt-6.1-sol・設定から解決・50秒で返った）。plan と確定版の認識合わせだけを渡し、ワークスペースは渡していない。
- 判定は「問題あり」で、must 5件・should 3件。8件とも採り、plan を直した。

| 重さ | 指摘 | 直したところ |
|---|---|---|
| must | 6項目が列挙されておらず、別の6項目でも受入を通せる | 範囲の2に6項目を名前つきで書き、受入の1行目でその名前を見る |
| must | 試しの2回では、設定の効果を比べられない（同じディレクトリ・Aで書かれないときの扱い・書かれないことは禁止の証明にならない） | DJ-6 を、別のディレクトリ・始める前の一覧・判定の3つの場合に書き直した |
| must | 試しのあとに移すフォルダの範囲が広すぎる | DJ-6 の後片づけを、一覧の差で特定したフォルダだけに絞った |
| must | `[speculation]` を出典なしで通す例外が、確定版の「すべてのマスに札と出典」と食い違う | DJ-3 と受入で、出典か出典が無い理由を必須にした |
| must | 公開前の確かめの対象から plan と episode が漏れている。記憶のフォルダの commit の件名を写す道がある | DJ-3 と受入で、公開する差分のすべてを対象にした。I6 で件名を写さない形にした |
| should | 前後の観察が、未 commit の変更・未追跡のファイル・別のファイルを取りこぼす。差を因果の証拠にしかねない | I6 の控えを全ファイルの一覧にし、差を因果の証拠にしないと書いた |
| should | 設定や hook があるだけでは、どの道を止められるかが決まらない | DJ-2 の候補の表に、効く経路・止められる範囲・確かめていない部分の列を足した |
| should | 過去の記録を、いまの仕組みの確かめに使いかねない | DJ-3 に、根拠の種類を分ける決まりを足した |

## 受入

| 受入の条件 | 確かめ方 |
|---|---|
| 範囲の6項目（書き手と時機・範囲・読み込まれ方・人が手を入れる口・ほかのエージェントに起こされた会話・外へ出る道）が、この名前で表の行にあり、Claude Code と Codex の両方の列がある | 文書の表を読む |
| 表のすべてのマスに、札と、出典か出典が無い理由（見た資料・確かめていない部分・分からなかった理由）がある | 文書の表を読む |
| 過去の記録を根拠にしたマスに、日付と版があり、いまの文書・いまの実装・今回の実測と分けてある | 文書の表を読む |
| 別のモデルの3観点のそれぞれに、両方の答えか「分からなかった（理由）」がある | 文書の節を読む |
| 候補の表のすべての行に、調整か制御か・配る場所・効く経路・止められる範囲・入れられるか・根拠・確かめていない部分がある | 文書の表を読む |
| Claude Code の試しの結果が、DJ-6 の判定のどれに当たるかで書いてある | 文書の節を読む |
| Codex の確かめが済み、確かめの記録の節がある | 文書の節と `git diff` を読む |
| Codex に渡す前とあとの `~/.codex/memories` の状態の差が、観察の記録の節にある | 文書の節と `tmp/650-agent-memory/` の控えを読む |
| 公開する差分のすべて（調査の文書・plan・episode）と commit の本文に、記憶の中身とほかのリポジトリの名前が入っていない | 差分と `git log --format=%B` を読む |
| Markdown の決まり（箇条書きは `-`・コードブロックに言語）を守っている | 差分を読む |

## ステップ

### P1: 認識合わせ（完了）

- 確定版のコメント: https://github.com/stlwolf/ai-development-hub/issues/650#issuecomment-7134862521

### P2: plan を書き、ゲート1 と設計SO を当てる

### GATE 3: owner の plan 承認

### I1: ブランチ名を変え、episode の枠を作る

```bash
git branch -m 'docs/#650_agent_memory_survey'
```

- episode: `docs/harness/episodes/2026-11-24-episode-650-agent-memory-survey.md`（`spec-card`）。
- commit 1: plan と episode の枠。

### I2: 文書の骨組みを作る（DJ-1〜DJ-3）

### I3: Claude Code の側を調べて埋める（DJ-4・DJ-6）

### I4: Codex の側を調べて埋める（DJ-5）

### I5: 別のモデルの3観点・候補の表・つながりうるものを埋める

- commit 2: この担当が書いた初稿。

### I6: Codex への依頼の書面を書き、`~/.codex/memories` の状態を控える（DJ-7）

- 控えるのは、commit の数と HEAD、作業ツリーの変更と未追跡のファイルの数、フォルダの下のすべてのファイルの名前・大きさ・更新時刻である。控えはファイルとして `tmp/650-agent-memory/` に置き、文書には差だけを書く。commit の件名は写さない（DJ-3）。

```bash
git -C ~/.codex/memories rev-list --count HEAD
git -C ~/.codex/memories rev-parse --short HEAD
git -C ~/.codex/memories status --porcelain | wc -l
find ~/.codex/memories -path ~/.codex/memories/.git -prune -o -type f -exec stat -f '%z %Sm %N' {} + | sort -k6 > tmp/650-agent-memory/codex-memories-before.txt
```

- Codex の確かめのあいだに owner の別の Codex の会話も動きうる。前後の差は、この会話が書いたことの証拠にはしない。

### GATE C: owner が Codex に書面を渡す（owner の手）

- この担当は止まって、渡す1行を owner に見せる。

### I7: Codex が埋めた差分を確かめる

- `git diff` で Codex が直した行と足した行を読む。
- 出典を、危険が大きいものと確かでないものから先に開いて確かめる（`evidence-verification-rule` の「Spot-Check」）。
- `~/.codex/memories` の状態を I6 と同じコマンドで控え直し（出力は `codex-memories-after.txt`）、前後の差を観察の記録の節に書く。
- commit 3: Codex の確かめ。

### GATE I: 受入の表の行がすべて満たされている

### I8: 実装SO（弱・Cursor 1レーン）・PR・Copilot 1ラウンド

- 実装SO の指摘を直したら commit 4。
- PR を作る（`pr-conventions`）。Copilot のレビューを1ラウンド受ける（`copilot-review-response`）。

### I9: episode を閉じ、報告して止まる

- `episode-retrospective` の closure。
- engine の層の issue の起票の案を出す（起こすのは owner の OK のあと）。
- マージ・worktree の掃除・issue を閉じるかの判断は owner がする。

## リスク・未確認事項

- Codex の記憶は新しい機能で、公式の文書が薄いかもしれない。そのときは手元の実物と CLI の出力で書き、文書で確かめられない行は `[speculation]` か `[unverified-summary]` のままにする。
- Codex に調べさせる会話そのものが、owner の Codex の記憶に入りうる。止めずに前後を控え、観察の材料にする（確定版の認識合わせのとおり）。
- GATE C で owner の手を待つあいだ、作業は止まる。
- 文書が長くなりうる。表を先に置き、詳しい節はあとに置く。

## ゲート3 のあとの変更

（承認のあとに plan を直したら、ここに書く）

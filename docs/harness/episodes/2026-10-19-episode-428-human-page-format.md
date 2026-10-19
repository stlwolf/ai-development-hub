---
id: "01M59P2Z7YZFQT0VSVJ053E164"
title: "#428 人向けの確認・回答用ページの形と部品を、持ち運べるスキルとして作る"
date: 2026-10-19
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/428"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6253136654"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6263379748"
    reason: "質問フェーズのまとめ（owner と統括で決めたこと11点と、plan に回すこと）。この単位はこれを前提にする"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-19-plan-428-human-page-format.md"
    reason: "この episode が記録する作業の計画"
tags: [skill, artifact, human-page, harness]
knowledge_observations:
  - "01M486Z2N7FSHRQ6EG34KT3AH9"
  - "01M2DRCP3SNPTHWDV2FJ9RZ4N0"
  - "01M00KCCHNMFPHP5HAGX2DZ1MK"
---

# #428 人向けの確認・回答用ページの形と部品を、持ち運べるスキルとして作る

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

owner に判定や回答を求めるページ（claude.ai の artifact）は、作るたびに形がばらばらで、owner はその都度「こうしてほしい」と伝えていた（2026-10-13 起票）。10-18〜19 に「送り元が分からない」「版と更新日時が分からない」という要件が足され、owner と統括は質問フェーズで形を11点決めた。この作業は、その11点を、どのリポジトリでも使える新しいスキル（ベースの HTML の型・部品の CSS と JS・データからページを作るスクリプト・用語集）として作る。

## この単位の入力

- brief: 統括（cockpit 19代目）が 2026-10-19 に発行した `.oe/brief-428-human-page-format.md`（作業層・消える）。plan-first で、最初の終端は P3（plan を報告して止まる）、委譲全体の終端は I3（PR を作って報告する）。マージ・worktree の掃除・issue の close はしない。baseline は master `e5d6c7f`。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6253136654 と、質問フェーズのまとめ https://github.com/stlwolf/ai-development-hub/issues/428#issuecomment-6263379748 。
- scope: まとめの「決まったこと」1〜11 を実装する新しいスキル。スキルのフォルダに hub の文書・リポジトリ名・issue 番号・hub の運用への参照を入れない（owner・2026-10-19）。呼ぶ側の hub の運用を変える文書の変更は最小にする。
- SO: 設計 weak（`so-compare` の Codex 1レーン）・実装 weak（`oe-review` の codex+cursor）+ Copilot 1ラウンド。Codex が返らなければ Cursor に1回だけ切り替えてよい（切り替えたら理由をここに書く）。
- 注入された negative knowledge: 3件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み（2026-10-19）

- worktree `feature/#428_human_page_format` を `wt switch --create` で作った。起点は master `e5d6c7f` で、`git fetch` のあとの `origin/master` と同じであることを確かめた。
- `issue-intake` の 1-2 の手順で、認識合わせのコメントを調べた。最後の行は `confirmed`・見出し4で、URL は brief の「認識合わせ:」欄と一致した。確定版と質問フェーズのまとめを前提にし、自分では認識合わせを通していない。
- いまの判定ページ2枚（#401 の plan 承認・#385 の許可規則の判定）を artifact の read で読んだ。保存は `db.collection("decisions").doc(key).set({key, choice, note, at})` で、`db` が無いときは「この表示では保存できません。選んだ内容は会話で伝えてください」と出す。描画は、ページに埋め込んだ配列（`GROUPS`）から JS で行い、`#N` を GitHub の issue へのリンクにしている。送り元の行は「ai-development-hub ・ cockpit 統括19代目（tmux ウィンドウ 0:2）・ issue #401 ・ 枝 … ・ 日付」で、まとめの決定4（ウィンドウ.ペイン・ブランチと書く・版の行を分ける）とはまだ違う。
- artifact の決まり（Artifact の道具の page contract と `artifact-design`・`artifact-capabilities`）を読んだ。plan に効く点は3つある。1つ目は、公開するファイルは doctype・`<html>`・`<head>`・`<body>` を書かない断片で、公開のときに骨組みで包まれることである。2つ目は、artifact の外で保存したページには `window.claude` 自体が無く、`claude.use()` は呼べないことである（`claude.d.ts`）。3つ目は、`<title>` は先頭 8KB の中に置くことである。
- 自分のペインから `tmux display-message -p -t "$TMUX_PANE"` で `0:2.2 CC:ai-development-hub` を引けた。まとめの決定4の「番号は、ページを作ったセッション自身のペインから引く」を、スクリプトが環境から取れる見込みがある。
- スキルを列挙している hub の文書は `canonical/CATALOG.md` だけだった。sync の3本は `SKILL.md` を持つディレクトリをまるごとリンクするので、新しいスキルは sync を直さずに配られる。ただし `~/.claude/skills` のリンク先は master の checkout なので、配られるのはマージと sync のあとである。

### P2: plan の初稿と、そこで下した判断の理由（2026-10-19）

plan の初稿を書いた。判断の結論は plan の DJ-1〜DJ-13 にあり、ここには結論に至った理由のうち plan に書き切れないものを残す。

- **描く場所をスクリプトに移した。** いまの判定ページは、ページに埋め込んだ配列から JS で描いている。最初はそれを引き継ぐつもりだったが、受入の「ヘッダーが決まった形で出る」「札の文言が用語集どおり」を確かめるには、JS で描くとブラウザが要る。Python が静的な HTML を描けば、標準の unittest だけで文字として確かめられ、JS が動かない表示でも中身は読める。JS は答え・保存・回答待ちの件数だけを持つ。

昇格の印: 描画をスクリプト（静的な HTML）に移し、JS は答えと保存だけにする判断

- **札の言葉の正本を用語集の1か所にした。** まとめの決定11 は用語集を1つのファイルに置くと決めている。build.py に同じ表を持つと正本が2つになり、owner が「表示を見て調整」したときに両方を直す必要が出る。build.py が描くたびに用語集の表を読む形にし、表が壊れていたら止める。
- **出力を2つの形にした。** artifact に公開する断片は文字コードの宣言を持たないので、手元で開くと日本語が化けうる。Artifact の道具の骨組みとまったく同じ形で書けば1つで済む見込みもあるが、骨組みの文字列は道具の版で変わりうるので頼らない。
- **言語は Python 3 にした。** hub の慣習は Bash だが、brief はスキルを hub の外へ持ち出せる形にすることを求めている。持ち出した先で追加のインストールを要しないことを優先した。macOS 付属の 3.9.6 で動く範囲に限る。owner の確認を plan の Q2 に置いた。

昇格の印: スキルのスクリプトを、hub の慣習（Bash）でなく持ち運びを優先して Python 3 の標準ライブラリで書く判断

- **回収のあとの表示は、入力を止める案を推奨にした。** 回収のあとに選び直しても統括には届かないので、押せる形のままだと届いたように見える。ただし owner の運用の感覚に関わるので、plan の Q3 で確かめる。
- **hub の側の変更は CATALOG の1行に絞った。** 統括の判定ページの作り方を書いた canonical の文書はいまは無く、案内をどこに足すかは統括の運用の判断である。brief の「最小にする」に従い、Q4 に置いた。

### P2: 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-19）

- `so-compare --codex-only` を `-w` に worktree を渡して1回当てた。モデルは `gpt-6.1-sol`（設定から読んだ値）、`codex-cli 0.163.0`、155 秒で初回に返った。Cursor には切り替えていない。依頼文と出力は `tmp/428-human-page-format/`（作業層・消える）にある。issue のコメントの写しは、信頼できない入力として区切って渡した。
- 結論は「直してから進めてよい」で、指摘は16件（高7・中9）。16件とも採った。指摘ごとの採否と直したところは plan の「設計SO」節の表にあり、ここでは再掲しない。
- 初稿の穴は3つの系統に分かれた。1つ目は、まとめの文言を言い換えて弱めていた所で、目的が部品を縛る規則（指摘1）と、JST を「走らせたマシンの時間帯」にしていた所（指摘2）である。どちらも自分で決定の文を読み直せば分かった形で、要件の文を設計に写すときに、持ち運べる形にしようとして要件の側を動かしていた。2つ目は、保存の互換を「4つの項目が同じ」でしか見ていなかった所（指摘3・4・5）で、いまの判定ページの書き方（文書全体を書き直す）が持つ競合と、接続を待つあいだの入力の扱いが抜けていた。3つ目は、受入が偽物の `db` と API の直接の書き込みで閉じていて、公開したページの JS と本物の `db` のつながりを見ていなかった所（指摘14）である。
- 指摘3 を採ったことで、書き方を `set`（文書全体）から `update`（変えた項目だけ）に変えた。保存される文書の形は同じだが、いまの判定ページとは書き方が違う。統括に知らせておくべき違いなので、plan の GATE 3 の節に「問いにはしないが知っておいてほしいこと」として書いた。
- 選択肢拡張の2案（ブラウザで動く生成器・宣言的な HTML を正本にする）は、どちらも退けた。理由と、もう一度検討する条件は plan の「ゲート1」節の木にある。

昇格の印: 判定ページの書き込みを、文書全体の set から、変えた項目だけの update に変える判断（保存の形は同じ）

- plan を直す途中で、道具の呼び出し（Edit と Bash）に書いた JSON のエスケープの表記 `\u003c` が、ファイルに届く前に `<` という1文字に直されていた。表の中の文が「`<` を `<` に置き換える」と読める形になっていた。バックスラッシュを `chr(92)` で組み立てる Python で直し、制御文字が無いことを `grep -P` で確かめた。この episode の記録も、最初は同じ理由で化けたので、同じ方法で書き直した。

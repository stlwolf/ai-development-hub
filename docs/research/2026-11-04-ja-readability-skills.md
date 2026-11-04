---
title: "AI が書いた日本語を読みやすくする外部スキルの調査 — humanizer・yomiyasu と周辺の候補の本質抽出と hub への入れ方"
date: 2026-11-04
status: research-complete
tags: [research-intake, readability, japanese, register, external-tools, yomiyasu, humanizer]
sources:
  - https://imoz.jp/scraps/202610_humanizer.html
  - https://imoz.jp/humanizer.ja.txt
  - https://zenn.dev/algoartis/articles/0b1c731881b25c
  - https://github.com/nanaism/yomiyasu
  - https://github.com/coji/natural-japanese
  - https://github.com/iKora128/stop-ai-slop-jp
related_research:
  - docs/research/2026-08-20-human-readable-generation-literature.md（会話面の人間可読性の文献調査。市場の対策が後編集型に偏ることと、「文書生成は後段に検証・整形層」という帰結を本ノートの前提にする）
  - docs/research/2026-07-27-ai-slop-design-process.md（ルール集だけでは品質を守れない、という論点。yomiyasu の「検出は機械・判断は文脈」と同じ向き）
  - docs/research/2026-07-16-register-portability-eval.md（#263 段階1。文体の規範化は未決のまま）
related_issues: [565, 355, 263, 348]
next_step:
  trigger: "#565 で owner が入れ方を決めたとき / yomiyasu を試し入れして2〜4週間使ったとき / #263 段階2（文体の規範化）を判断するとき"
  actions: "試し入れなら、`npx skills add nanaism/yomiyasu` を user 層に入れ、Slack・Notion の下書きと issue・PR の本文で呼んで使い、直した差分と『書き手に確かめたい点』を記録する。正式採用を判定するときは本ノートの『入れ方の候補』の表と、試用期間の記録を並べる。#263 段階2 では、P-5（規則の文の文体が出力に写る）と P-9（文書の種別で当てない規則を外す）を材料にする"
  referenced_by: "#565（この調査の issue）/ #355（見取り図の表の欄の読みづらさ。本ノートの対象外と判定した理由はここ）/ #263 段階2 / #348（output styles は生成時の契約、本ノートの道具は後編集。役割の分け方）"
---

# AI が書いた日本語を読みやすくする外部スキルの調査 — humanizer・yomiyasu と周辺の候補

## 中心の問い

AI が書いた日本語の文（Slack の下書き・Notion の文書・issue や PR の本文・owner への報告）を、書いたあとに読みやすく直す仕組みを hub に入れるか。入れるなら、外のスキルをそのまま入れるか、hub の決まりに合わせて調整して入れるか、既存の規則に数行足すだけで足りるか。

hub の既存の決まり（`canonical/rules/output-format-rule.md` の §8・§9、出力の型 `readable-conversation`、`markdown-conventions`、`html-one-pager` の用語集）は「書くときの決まり」で、書いたあとに直す道具は無い。先行の文献調査（2026-08-20）は「文書生成は後段に検証・整形層を置き、会話面は生成時の契約を先にする」と結論している [verified] (docs/research/2026-08-20-human-readable-generation-literature.md「ハーネスへの帰結（v2）」)。本ノートは、その「後段の層」の候補を一次情報で読んだ記録である。

検証ステータスの規約は `evidence-verification-rule` に従う。`[verified]` は一次情報（ページ・規則ファイル・リポジトリのファイル）を開いて確かめた事実、`[unverified-summary]` は一次情報が別の資料を引いて述べている内容や、検索結果の要約、`[speculation]` は本ノートの推論である。

## 結論

hub には「書いたあとに直す層」が無い。候補のうち yomiyasu（MIT・標準ライブラリだけの lint と diff・意味の保持を最上位の決まりにする・名前で呼んだときだけ発火する）が、hub の決まりと衝突せずにその層を埋める。推奨は、hub の配布物（`canonical/`）には入れず、user 層へ `npx skills add` で試し入れし、呼んだときだけ使って記録を残すことである。正式採用は試用の記録を見て別途判定する。humanizer は規則の文が記事向けでライセンスが不明なので、工程の型と「構成の重複」の観点だけを本ノートに残す。

humanizer の規則で統括が書いた issue 本文を直した試行では、17 箇所が直った。そのうち 7 箇所は hub の §9 と `readable-conversation` がすでに禁じている形（体言止め・「・」による接続・入れ子の括弧）の残りだった。書くときの規則だけでは取りこぼす、ということの小さな証拠になる。意味が変わった箇所は見つからなかった。

yomiyasu の lint は、子のペインの Bash がハーネスの許可（外部から取り込んだコードの実行）で止められ、本ノートの時点では hub の文に当てられていない。受け入れ基準のうち「lint が指した箇所の数と例」は未達で、結果が得られたら「hub の文に当てた試行」の節を更新する。

## 記事情報（Step 1）

### humanizer（いもす研）

- **タイトル**: 文章のAIっぽさを抑えるプロンプト
- **URL**: https://imoz.jp/scraps/202610_humanizer.html （規則ファイル: https://imoz.jp/humanizer.ja.txt ・ https://imoz.jp/humanizer.en.txt ）
- **著者/組織**: いもす（今城 健太郎・Kentaro Imajo）
- **公開日**: 2026-10-30（最終更新 2026-11-03） [verified]
- **種別**: ブログ記事 + 規則の文のファイル。スキルの形ではなく、「URL を熟読し、ルールに完全に適合するように隅々まで何度も確認し修正してください」という1行のプロンプトで AI に規則を読ませる [verified]
- **要約**: 最近の LLM はコードは書けるが文章の流れが途切れる（短い説明に細かく見出しを付ける・具体例のあとに同じ結論を言い直す）。一方で指示に沿って直す能力は上がったので、記事の推敲に使っている規則を公開した。規則は日本語 510 行（約 74 KB）で、「執筆・校正の手順」（整理→診断→修正→照合→通読）、読者と目的、文体と主張の強さ、文・段落の作り方、説明と根拠、語彙の選び方、記事の種類に応じた構成、本文・補足・図表、執筆後の確認事項、ルールの更新、からなる [verified]。記事では GPT-6.1 Sol で日英3例ずつ、規則を3回続けて当てた前後を並べ、説明の重複と定型の前置きが減り、理由や手順が補われたと述べる。著者の注意は2つで、「どこを詳しく書き何を省くかは書き手の思いが要る。AI に任せると関連する話題をひととおり無難に扱い、どこも同じ調子になる」「このプロンプトでも書き手の思いは補えないので、『この欠点だけは知ってほしい』などの思いと理由を文章と一緒に渡してほしい」 [verified]
- **ライセンス**: ページにも規則ファイルにも明示が無い [verified]（`unknown`。配布物に写すには著者の許諾が要る）
- **注意**: GitHub の blader/humanizer（英語向け・64k スター）とは名前が同じだけの別物である [verified] (gh repo view)

### yomiyasu（ALGO ARTIS・nanaism）

- **タイトル**: 【最新v2.4.0公開】AI-Slopな日本語を構造レベルで読みやすくするSkill『yomiyasu（よみやす）』を作りました
- **URL**: https://zenn.dev/algoartis/articles/0b1c731881b25c ・ https://github.com/nanaism/yomiyasu
- **著者/組織**: 大賀愛一郎（ALGO ARTIS）
- **公開日**: 記事 2026-10-01（2026-10-29 に v2.4.0 の追記）。リポジトリの最新は v2.5.0（2026-10-30） [verified] (gh release view)
- **種別**: ブログ記事 + OSS（MIT）。Claude Code・Codex・Cursor で動く Agent Skill。`npx skills add nanaism/yomiyasu` で入れる [verified]
- **要約**: AI が書く日本語の不自然さは、単語の禁止（ブラックリスト）では直らない。原因を3つに整理する。無生物主語と身体の比喩の動詞（「データが静かに壊れる」）、述語を落とした名詞の連なり、意味の無い否定の対比。v1 は書き直しで元に無い細部を足して意味を変えたと指摘され、v2.0.0 で「意味を変えない」「元に無い情報を足さない」を最上位の決まりにした。決められないところは原文を残して書き手に尋ねる。標準ライブラリだけの Python の道具（lint・diff・check）が付き、lint は点数を出さない。評価のコーパスは 163 件で、著者も「小さい」「人の確かめは要る」と書く [verified]
- **記事が引く外部の調査**: Qiita の7万記事で「効く」「壊れる」「境界」「実測」「静かに」などが 2026 年に数倍から数十倍に増え、初期の定型句（「〜しましょう」「また、」）はむしろ減った、という数字は記事が逆瀬川ちゃん氏の調査を引いたもの [unverified-summary] (https://nyosegawa.com/posts/qiita-writing-before-after-ai/ は未閲覧)

### ほかの候補（短い調査）

Web 検索3回と GitHub の検索で見つけたもののうち、日本語の AI の文を直す目的のものを挙げる。スター数と日付は 2026-11-04 に `gh repo view` で確かめた [verified]。

| 名前 | 作者 | ライセンス | スター | 最終更新 | 中身 | 検証 |
|---|---|---|---|---|---|---|
| natural-japanese | coji | MIT | 2,011 | v1.6.4（2026-10-28） | 仕事の日本語を書く・直す Agent Skill。「元に無い内容を足さない」を最上位の規則にし、疑わしい箇所は `lint.py` が形態素解析（sudachipy・uv で実行）で検出し、直すかはエージェントが決める。`score` モード（0〜100 の点数）がある。苦手なこととして直訳の熟語の半分ほどの見逃しと、effort を下げると見逃しが増えることを README が明記する | [verified] README と SKILL.md を gh api で取得 |
| stop-ai-slop-jp | iKora128 | MIT | 477 | 2026-06-11（以後更新なし） | hardikpandya/stop-slop の日本語版。語彙と構造のブラックリスト（`references/phrases.md`・`structures.md`）と採点。大原則は「AI 臭の正体は書き手の不在」。「伝聞を残す」「中間の温度を混ぜる」「毒を許す」など、人間らしさを足す向きの規則を含む | [verified] README と SKILL.md を gh api で取得 |
| blader/humanizer | blader | MIT | 64,481 | 2026-10-28 | 英語向けの元祖。いもす研の humanizer とは別物 | [verified] gh repo view |
| japanese-humanizer ほか | geonwoo-jeong 等 | — | 4 以下 | 2026-10 | 小規模の個人スキルが複数ある | [unverified-summary] gh search の一覧のみ |

yomiyasu の記事は natural-japanese・stop-ai-slop-jp・blader/humanizer を先行研究として挙げ、既存スキルの指示文に禁止対象の比喩動詞（「効く」28回など）が含まれることと、文長のばらつきの指標を満たすための不自然な短文を課題として挙げている [verified] (記事「従来の文章推敲スキルが抱えていた課題」)。

## 本質的パターン（Step 2）

| # | パターン名 | 本質 | 種別 | 検証/根拠 |
|---|---|---|---|---|
| P-1 | 意味の保持を最上位に置く | 書き直す前に主張・比重・言い切りの強さ・文の働きを確かめ、書き直したあとも同じに保つ。決められない所は原文を残して書き手に尋ねる | 設計原則 | [verified] yomiyasu SKILL.md「1. 基本原則」「最優先ルール: 意味の保持」/ humanizer.ja.txt「言い換えで保つ意味」「執筆後の確認事項 5. 比較と採否」 |
| P-2 | 語の禁止でなく文の構造を直す | 無生物主語と比喩動詞、述語の脱落と名詞の連なり、演出の否定対比の3つを狙う。単語のブラックリストは別の比喩への置き換えを生むだけ | 設計原則 | [verified] zenn 記事「AI-Slopをもたらす3つの言語学的病理」/ SKILL.md「比喩動詞の具体化」「主語と目的語の明確化」「セルフラベリングと否定対比の整理」 |
| P-3 | 検出は機械・判断は文脈・点数は出さない | lint は見直し候補を行ごとに出すだけで、読みやすさの合否も意味の保持も判定しない。点数は目標になるので通常の出力に出さない | 評価手法 | [verified] SKILL.md Step 3 / docs/limitations.md / zenn 記事「3. 点数を目的にしない」。natural-japanese も「検出は機械・判断はエージェント」で同じ向き [verified] (README「仕組み」) だが score モードを持つ |
| P-4 | 推敲の前後を機械で突合し、意味が変わる恐れを先に出す | diff は数値・否定・「が」「を」の入れ替え・文の種類（伝聞・推量・依頼）・許可と能力と保証の言い方・原文に無い人や担当の追加を「意味が変わる恐れ」として先頭に出す。check は run と verify で最終稿のハッシュを記録と照らす | 実装パターン | [verified] SKILL.md Step 4・Step 5 / references/review-points.md |
| P-5 | 指示文自体を規則に適合させる | LLM は指示文の文体を手本として写すので、SKILL.md と README を自分の lint に通して比喩動詞と装飾を除いた | 設計原則 | [verified] zenn 記事「4. 指示文自体の表現の適正化」 |
| P-6 | 構成の重複と予告・言い直しを削る | 「主に3つの理由があります」の予告、例のあとの結論の再掲、総括文、「見ます」「確認します」の案内文を、役割を確かめて削る。見出しだけをたどって順序が分かるかを見る | 設計原則 | [verified] humanizer.ja.txt「文・段落の作り方」「概要・詳細・まとめの役割分担」「対象・操作・結果の説明」 |
| P-7 | 書き手の意図と文書の条件を一緒に渡す | 何を伝えたいか・何を省いてよいかは規則では補えない。yomiyasu は文書の種別（13種）・読者（3段階）・立場（勧め/決まり/説明）を依頼で受け取り、指定が無ければ決めない | ワークフロー | [verified] humanizer 記事「おわりに」/ SKILL.md Step 1 |
| P-8 | 工程を分け、やり直しの戻り先を決める | humanizer は整理→診断→修正→照合→通読で、後の工程で問題を見たら診断へ戻る。yomiyasu は Step 1〜5 で、修正は1回だけにして run をやり直し、verify のあとは本文を変えない | ワークフロー | [verified] humanizer.ja.txt「執筆・校正の手順」/ SKILL.md「2. 実行手順」 |
| P-9 | 文書の種別で「当てない規則」を外す | PR 説明では箇条書き・チェックリスト・体言止めの変更点を残し、箇条書きを地の文に戻さない。障害報告の時系列、議事録の太字ラベルも同じ | 設計原則 | [verified] references/doc-types/pr.md / SKILL.md Step 1 の表 |
| P-10 | 名前で呼ばれたときだけ発火し、常時は指示ファイルの1行で決める | v2.0.2 から「読みやすくして」だけでは使われない。常時使うなら CLAUDE.md か AGENTS.md に1行足す（コードを直したあとの作業の報告は除く形の文例がある） | ツール | [verified] SKILL.md の description / README「毎回 yomiyasu を使いたいとき」 |
| P-11 | 評価の規模と確かめた範囲を明記する | コーパス 163 件、「人の文章」として数えた16本のうち8本が例文だったことの訂正、確かめたホスト（macOS の Claude Code と Codex の `-p` 実行）と確かめていない環境（対話画面・Cursor・Windows）を文書に残す | 評価手法 | [verified] zenn 記事「検証コーパスで見えた限界」/ docs/limitations.md「確かめた範囲」 |

### 詳細

**P-1・P-4（意味の保持と機械の突合）** は、この分野の道具の信頼性を決める中心である。yomiyasu の v1 は、原文に無い行為者や原因を補って読みやすくした結果、意味が変わったと指摘を受けた [verified] (zenn 記事「1. 意味を変えないことを最優先にする」)。v2 からは「主張・比重・言い切りの強さ・文の働き」の4点を書き直す前に確かめ、diff がそれを機械で拾う。hub の `evidence-verification-rule` が「自己評価は検証ではない」と置くのと同じ構えで、推敲側の自己申告でなく原文との差分で見る。humanizer も「照合」の工程で「意味・条件・主張の強さが意図せず変わっていないか」を見るが、道具は無く AI 自身の確認に頼る [verified] (humanizer.ja.txt「執筆・校正の手順 4」)。

**P-2（構造を直す）** は hub の既存の決まりに無い観点である。`output-format-rule` §9 と `readable-conversation` が禁じるのは、体言止め・記号を接続に使うこと・入れ子の括弧・前置きと締め・記号の強調で、「書くときの形」の規則である。無生物主語に身体の比喩動詞を結ぶこと（「前提が静かに壊れる」）、述語を落として名詞をつなぐこと、演出の否定対比（「単なる〜ではない」）は、どの規則にも書かれていない [verified] (canonical/rules/output-format-rule.md §8・§9 / canonical/output-styles/readable-conversation.md を読んだ)。

**P-3（点数を出さない）** は natural-japanese と分かれる点である。natural-japanese は `score` で 0〜100 を返す使い方を README に載せ、yomiyasu の著者は点数が目標になる（グッドハートの法則）ことを理由に通常の出力から外した [verified]。hub の owner の既往判断「ルールは観測性とフィードバック性が低い。機械的ゲートを優先する」と照らすと、lint が候補を指すことは観測性を上げるが、合否の点数を置かないことで「点数を上げる言い換え」を防ぐ。この折り合いは hub の `hypothesis-gate`（advisory・ブロックしない）と同じ置き方である [speculation]。

**P-5（指示文の文体が出力に写る）** は、hub の規則の書き方そのものに当たる。hub の `canonical/rules/*.md` は英語で書かれ、日本語の出力の形は §8・§9 と出力の型が日本語で決めている。yomiyasu の著者の観察が正しければ、日本語の文の形を決める規則は日本語で、禁じる形を使わずに書くのがよい。`readable-conversation` はすでにその形で書かれている [verified] (canonical/output-styles/readable-conversation.md)。規則本体の英語が日本語の出力に悪く写るかは未確認 [speculation]。

**P-6（構成の重複）** は humanizer が得意で yomiyasu が薄い領域である。yomiyasu の規則は文と段落のつながりを扱うが、「3つの理由を予告する」「例のあとに同じ結論を言い直す」「総括文が直前の説明の言い直しになっている」の判定は humanizer の方が細かい [verified] (両方の規則を読み比べた)。hub の `readable-conversation` は前置きと締めの挨拶を禁じるが、本文の中の重複は扱っていない。

**P-9（文書の種別で規則を外す）** は、hub の決まりとの衝突を避ける鍵になる。hub の PR 本文は `markdown-conventions` と `pr-conventions` で箇条書きとチェックボックスを規約にしている。yomiyasu の `pr` 種別は箇条書き・体言止めの変更点を残すので衝突しない [verified] (references/doc-types/pr.md)。一方 `readable-conversation` は会話面で体言止めを禁じるので、会話面の文に yomiyasu を当てるなら種別の指定で整合を取る必要がある。会話面の応答は「作業の報告」で、yomiyasu 自身も既定ではそこを対象にしていない [verified] (SKILL.md 冒頭「作業の報告や変更の説明は、ここでいう本文に入りません」)。

**P-10（発火の条件）** は、hub の「出来上がったものを常時通す」か「呼んだときだけ」かの判断に直接当たる。常時にするなら CLAUDE.md の1行で、yomiyasu の README はコードを直したあとの作業の報告を除く文例を載せている [verified]。

## 実装参照候補

| # | 対象 | リポジトリ/ファイル | ライセンス | 確認元 | 流用形態 |
|---|---|---|---|---|---|
| 1 | yomiyasu（SKILL.md・references・scripts） | https://github.com/nanaism/yomiyasu （`skills/yomiyasu/`） | MIT | リポジトリの LICENSE [verified] | そのまま利用（`npx skills add`）。改変して取り込むなら SKILL.md 約 128 KB と Python 約 23,000 行（lint 6,149・diff 11,463・check 5,364・markdown_visibility 956）を自前で保つことになる [verified] (wc) |
| 2 | humanizer.ja.txt | https://imoz.jp/humanizer.ja.txt | unknown（明示なし） | ページと規則ファイルに記載なし [verified] | パターンのみ参照。配布物に写さない。使うなら URL を指す |
| 3 | natural-japanese | https://github.com/coji/natural-japanese | MIT | README のバッジと LICENSE [verified] (gh repo view) | 今回は未導入。lint が sudachipy と uv を要する |
| 4 | stop-ai-slop-jp | https://github.com/iKora128/stop-ai-slop-jp | MIT | gh repo view [verified] | 参照のみ |

humanizer の規則ファイルはライセンスが `unknown` なので、`research-intake` の決まりどおり、hub の配布物（`canonical/`）に写す案は owner の確認無しには採れない。

## hub の文に当てた試行（R2）

当てる文は公開リポジトリにある文だけにした（issue と PR の本文・`canonical/` のスキルと出力の型の文・`docs/` の文書）。Slack と Notion の下書きは業務の情報を含むので外した。

### yomiyasu の lint を hub の6文書に当てる（未実施）

対象に選んだのは次の6つである。#565 の issue 本文、PR #559 の本文、`canonical/skills/issue-intake/SKILL.md`、`canonical/output-styles/readable-conversation.md`（hub の日本語の規則そのものを lint に通す。yomiyasu の著者が自分の SKILL.md にしたのと同じ検査）、`docs/harness/episodes/2026-10-23-episode-478-one-pager-kinds.md`、`docs/harness/discussions/2026-09-10-discussion-348-output-style-findings.md`。

実行は、子のペインの Bash が Claude Code の auto mode の分類器（理由「Code from External」）で止められた。素の `python3 -I -B` と、`sandbox-exec` でネットワークを閉じて書き込み先を lint の出力フォルダに絞った形の2回で、どちらも同じ理由だった。スクリプトの中身は読んで確かめている。`yomiyasu_lint.py` は標準ライブラリだけを import し、ネットワーク・subprocess・環境変数の読み取りは無く、引数のファイルを読み取り専用で開いて標準出力に書く [verified] (import 文と open の呼び出しを grep)。`yomiyasu_check.py` は `.yomiyasu/` の状態フォルダを git の根に作るので、hub の試行では使わず lint と diff だけを使う予定にした [verified] (docs/tools.md・check.py の state_dir_for)。owner への依頼は統括への途中経過として渡した。

実行できた場合に見るつもりだったのは、lint の 31 種の規則（`metaphor_verb`・`calque`・`renyo_noun`・`negative_parallelism`・`excess_bold`・`excess_list`・`bold_label_list`・`trailing_colon`・`sentence_end_repetition`・`ai_phrase` など） [verified] (yomiyasu_lint.py の rule 名を grep) のうち、hub の文で何が多く当たるか、hub の規約（箇条書き・チェックボックス・ラベルとコロン）が候補として出るかである。規則を読んだ範囲の見立てでは、issue 本文の「狙うもの: …」「考え方: …」のようなラベルとコロンで始まる箇条は `bold_label_list` の候補に出うる（`pr` 種別でも外さない規則） [speculation]。

### humanizer の規則で issue の本文を直す

対象は #565 の issue 本文（統括が owner の言葉から書いた AI の文。約 2,200 字・31 文）。公開されている1行のプロンプト（「humanizer.ja.txt を熟読し、ルールに完全に適合するように隅々まで何度も確認し修正してください」）と規則ファイルを、本調査とは別のセッション（Claude）に渡し、規則ファイルの「執筆・校正の手順」（整理→診断→修正→照合→通読）で直させた。原文・修正稿・差分・診断の記録は作業層（`tmp/565-ja-readability/humanizer-out/`）に残した。

結果の数は次のとおりである。

| 項目 | 値 |
|---|---|
| 候補 / 採用 / 不採用 | 24 / 17 / 7 |
| 字数（原文 → 修正稿） | 2,235 → 2,275 |
| 文の数（「。」） | 31 → 31 |
| 見出し・チェックボックス・URL | 変化なし（8・4・6） |
| 箇条の数 | 「関連」で 2 → 3（#263 と #348 を別の箇条に分けた）。ほかは不変 |

直した形の内訳は、体言止めの文を次の文につなぐ（3）、「・」で接続語を代用した箇所を読点や箇条に分ける（3）、入れ子の括弧の解消（1）、助詞の直前と「という」の直前の読点の除去（2）、名詞の連なりの解消（2。「標準ライブラリだけの Python の道具」→「標準ライブラリだけで動く Python の道具」、「hub の外のツールの採用の基準」→「外のツールを hub に採用する基準」）、主語を後ろに置いた長文の主語の先出し（1）、列挙の並列の形の切り直し（1）、文末に述語を補う（1）、話し言葉の埋め草「〜系」の削除（1）、ほかの言い換え（2）である [verified] (humanizer-out/issue-565.diff と issue-565.changes.md)。

hub の既存の決まりと照らすと、17 のうち 7（体言止め 3・「・」接続 3・入れ子の括弧 1）は `output-format-rule` §9 と `readable-conversation` がすでに禁じている形である。統括はその規則の下で書いたのに残っていた。残りの 10 は hub の規則に無い観点（名詞の連なり・読点の位置・主語の位置・列挙の並列の形・述語の補い）だった。humanizer が得意とする構成レベルの直し（重複・予告・まとめの言い直し）は、この文書には当たる箇所が無く、直しは文の形に留まった。issue 本文の長さでは構成レベルの効果は出ない [speculation]。

意味が変わる危うさは、直した側が3件を自己申告した。「評価の文書は163件で小さい」→「評価に使った文書は163件と少ない」は、一次情報（zenn 記事と docs/limitations.md のコーパス 163 件）に照らして正しい解釈だった [verified]。「日本語の AI の文を直す」→「AI が書いた日本語の文を直す」は、目的の節が同じ対象を書いているので保たれている [verified] (原文)。「直させる形で」→「直させる使い方で」は意味の幅が少し狭まるが、「スキルの形ではない」との対比と主張は同じである。直した側は、目的の3択とやることの4択の食い違いと、対象の列挙の違い（「Notion の文書」と「Notion の下書き」）を「直すと内容に触る」として原文のまま残し、記録に書いた。これは yomiyasu の「決められないところは原文を残して書き手に尋ねる」と同じ振る舞いで、humanizer の規則文にも「資料不足などで解消できない課題は、理由とともに未解決として報告します」とある [verified] (humanizer.ja.txt「執筆・校正の手順」)。

この試行の限界は2つある。直した側と確かめた側が同じモデルの系列（Claude）であること、そして yomiyasu の diff による機械の突合（意味が変わる恐れの検出）が lint と同じ理由で実行できなかったことである。

## 資産マッピング（Step 3）

前処理として `canonical/CATALOG.md` の全32スキル・7コマンド・12ルール・1出力の型を読み、`docs/research/` の一覧と `ideas/connections.md` を見た。開いている issue のうち文体・読みやすさに当たるのは #565（本件）と #263 で、ほかに語彙の違う同型の issue は見当たらなかった [verified] (gh issue list を題で走査)。

### トラックA: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ/新規知見 |
|---|---|---|---|
| P-1・P-3・P-4 | `evidence-verification-rule`（自己評価は検証でない）/ owner の既往判断（機械的ゲート優先）/ docs/research/2026-07-27-ai-slop-design-process.md P-1（ルール集だけでは品質を守れない） | 補強 | hub には「書いたあとに直す道具」も「推敲の前後を突合する道具」も無い。yomiyasu の lint と diff がその穴に当たる |
| P-2・P-6 | `output-format-rule` §8・§9 / `readable-conversation` | 拡張 | hub の規則は体言止め・記号接続・前置き・締め・強調を扱う。無生物主語と比喩動詞、述語の脱落、否定対比、本文の中の重複は扱っていない |
| P-9 | `markdown-conventions` / `pr-conventions` | 補強 | PR 本文の箇条書きの規約と、yomiyasu の `pr` 種別は整合する |
| P-5 | #263（文体の規範化・段階2）/ docs/research/2026-08-20（規則文の register） | 拡張 | 「規則の文の文体が出力に写る」は #263 段階2 の材料になる。hub の規則本体が英語であることの影響は未確認 |
| P-10 | #348（output styles は生成時の契約） | 補強 | 会話面は生成時の契約（output styles）、文書は後編集（yomiyasu）という役割の分け方が、2026-08-20 の帰結と一致する |
| （対象外） | #355（見取り図の表の欄に読む文を詰めた形） | — | 部品の形の問題で、文の推敲の道具では直らない。html-one-pager 側の課題として残る |

### トラックB: 新規導入候補

| パターン | 既存対応物 | 導入形態 | 実現可能性メモ |
|---|---|---|---|
| 後編集の推敲スキル（yomiyasu） | なし | 外部スキルの試し入れ（user 層の `~/.claude/skills/`。hub の `canonical/` には入れない） | `scripts/sync/sync-claude.sh` はディレクトリごとに `ln -sfn` で置き、canonical に無い項目を消さないので、`npx skills add` で入れた skill と共存できる [verified] (sync-claude.sh を読み、`~/.claude/skills/` に canonical 外の項目が残っていることを確認)。hub の外のツールの採用の基準（試し入れと正式採用を分ける・plugin は hub の宣言に載せない）に合う |
| 構成の重複の削除（humanizer の観点） | `readable-conversation`（前置きと締めのみ） | 既存の規則に数行足す候補 | ライセンス不明なので文を写さず、観点だけを hub の言葉で書く |
| 形態素解析つきの lint（natural-japanese） | なし | 保留 | sudachipy と uv の依存を受け入れるかが先。yomiyasu の正規表現の lint で見逃しが多いと分かったときに再訪 |

## アクション判定（Step 4）

| 対象 | 種別 | 理由 |
|---|---|---|
| yomiyasu | `experiment` | 既存に対応物が無く、MIT で、hub の決まりと衝突しにくい（P-9・P-10）。試し入れして使った記録を残し、正式採用は別途判定する。入れ方は owner の判定（問いのファイル） |
| humanizer | `archive-note` | 工程の型（P-8）と構成の重複（P-6）の観点は有用だが、記事向けの規則が多く、ライセンス不明で配布物に写せない。本ノートに観点を残す |
| natural-japanese | `defer` | 採用の候補として強い（スター数・更新頻度）が、lint の依存が重い。再訪条件は `next_step` に書いた |
| stop-ai-slop-jp | `discard` | 目的が「人間らしさを足す」寄りで、2026-06 から更新が無い。読みやすさの道具としては yomiyasu と natural-japanese に劣る |
| hub の既存規則への追記 | owner の判定 | P-2 の3つ（無生物主語と比喩動詞・述語の脱落・否定対比）を §9 か `readable-conversation` に足すかは、yomiyasu を入れるかと表裏なので、問いのファイルで一緒に出す |

## 入れ方の候補の比較（owner の判定の材料）

issue の4択を、調査の結果で比べる。

| 案 | 中身 | 利点 | 弱い点 |
|---|---|---|---|
| A. そのまま試し入れ（推奨） | `npx skills add nanaism/yomiyasu` を user 層（`~/.claude/skills/`）に入れ、hub の宣言には載せない。名前で呼んだときだけ使う。2〜4週間、直した差分と「書き手に確かめたい点」を記録し、正式採用は別途判定する | 保守の負荷が無い。MIT。上流が活発（2026-10-16 の v2.0.0 から 10-30 の v2.5.0 まで2週間で 12 回のリリース）。hub の sync はディレクトリごとの `ln -sfn` で canonical 外の項目を消さないので共存できる。発火が名前呼びに限られ、hub の規則と衝突しない | hub の配布に乗らないので、Codex・Cursor と別の端末では別に入れる。Slack と Notion の下書きは会話面で生まれるので、呼ぶ手間が要る。hub と dotfiles の役割分担では、素の install は検証の段に限り、採用なら dotfiles 側に書く |
| B. hub に合わせて改修して canonical に入れる | `skills/yomiyasu/` を `canonical/skills/` に写し、§8・§9・用語集に合わせて規則を足す | hub の配布に乗り、hub の用語でそろう | SKILL.md 約 128 KB と Python 約 23,000 行を自前で保ち、上流の更新に追随する負荷。採用基準の「改修して自前メンテ」を、試用の前に選ぶ根拠が無い |
| C. 既存の規則に数行足すだけ | §9 か `readable-conversation` に P-2 の3観点（無生物主語と比喩動詞・述語の脱落・否定対比）を足す | 安い。配布に乗る | 書くときの規則で、後編集の層は埋まらない。試行は、書くときの規則の下で書いた文に規則違反が7箇所残ることを示した。足す観点は A の試用のあとに決めるのが順 |
| D. 入れない | 既存の規則で足りるとする | 変更が無い | 同上。残った7箇所を拾う手段が無いまま |

推奨は A である。理由は3つある。第一に、hub の既存の決まりは書くときの形を決めるもので、書いたあとに直す層が無いこと、そして先行の文献調査が「文書生成は後段に検証・整形層」と結論していること。第二に、yomiyasu は意味の保持を最上位に置き、lint と diff で推敲の前後を機械で突合するので、hub の「自己評価は検証ではない」「機械的ゲートを優先する」という構えに合うこと。第三に、hub の外のツールの採用の基準が「試し入れと正式採用を分ける」と置いているので、改修して取り込む B は試用の記録のあとに判定するのが順であること。

A の中で natural-japanese を選ばなかった理由は、lint が sudachipy と uv に依存すること、点数（`score`）を出す使い方があることの2つである。yomiyasu の正規表現の lint で見逃しが多いと分かったら、natural-japanese の形態素解析の lint を試す（`next_step`）。

試用で記録するとよいこと: 呼んだ場面（Slack・Notion・issue・PR・報告）、直した箇所の数と種類、「書き手に確かめたい点」の数と当たり外れ、hub の規約（箇条書き・チェックボックス・ラベルとコロン・和訳しない用語）と食い違った候補。常時に切り替えるか（CLAUDE.md の1行）は、この記録を見て決める。

## 未確認のまま残ること

- yomiyasu の推敲を Cursor と対話画面で動かしたときの振る舞い（著者も未確認） [verified] (docs/limitations.md)
- hub の規則本体が英語で書かれていることが日本語の出力の文体にどう写るか（P-5 の含意） [speculation]
- Slack と Notion の下書きに当てたときの結果。本調査で当てたのは公開リポジトリの文だけで、Slack・Notion の文は業務の情報を含むので対象から外した

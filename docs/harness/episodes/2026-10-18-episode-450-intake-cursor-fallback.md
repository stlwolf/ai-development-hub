---
id: "01M55N1CW5NCYGNHVCD4T3X1CW"
title: "#450 issue-intake の別モデルの問い合わせで、Codex が返らないときは Cursor で1回やり直す"
date: 2026-10-18
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/450"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/450#issuecomment-6239288613"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りを経ている）。この単位はこれを前提にする"
  - type: derived_from
    ref: "docs/harness/plans/2026-10-18-plan-450-intake-cursor-fallback.md"
    reason: "この episode が記録する作業の計画"
  - type: design_context
    ref: "docs/harness/plans/2026-09-25-plan-403-issue-intake-alignment.md"
    reason: "別のモデルへの問い合わせを「自分と違うモデル1本に1回だけ、上限を決めて出す」と決めた判断（DJ-6）と、手段が無いときの動き（DJ-10）"
  - type: design_context
    ref: "docs/harness/episodes/2026-10-16-episode-412-intake-why-line.md"
    reason: "同じスキルを直した直近の単位。文字列の受入で部分的に戻した場合の穴を踏んだ記録"
tags: [skill, issue-intake, gate-0, so-compare]
knowledge_observations:
  - "01M486Z2ND07GQWV1GHS1SVB0J"
  - "01M50MBKVB6T9QCKEGB8ZG1SET"
  - "01M2DRCP3SNPTHWDV2FJ9RZ4N0"
  - "01M2DEC1G68X8PH2QEW2H1DWZZ"
---

# #450 issue-intake の別モデルの問い合わせで、Codex が返らないときは Cursor で1回やり直す

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

2026-10-18、#391 の着手前の認識合わせで、`issue-intake` の4節が別のモデルとして決めている Codex のレーンが、ChatGPT の利用上限で使えなかった。スキルは使えなければ「できなかった」と書いて進む決まりなので、別モデルの点検がそのまま抜けるところだった。統括はその場で Cursor のレーンに切り替えて点検を通したが、スキルにその運用は書かれていない。この作業は、Codex（最初に問い合わせるモデル）から答えが返らないときに Cursor のレーンで1回だけやり直す決まりを、4節・9節の表・hub の具体例に足す。

## この単位の入力

- brief: 統括（cockpit 19代目）が 2026-10-18 に発行した `.oe/brief-450-intake-cursor-fallback.md`（作業層・消える）。plan-first で、最初の終端は P3（plan を報告して止まる）、委譲全体の終端は I3（PR を作って報告する）。マージ・worktree の掃除・issue の close はしない。baseline は master `b62d618`。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/450#issuecomment-6239288613 （深掘りを経ている）。
- scope: `canonical/skills/issue-intake/SKILL.md` の「4. 別のモデルへ1回だけ問い合わせる」、「9. 手元に無いもの」の表の「別のモデルへの問い合わせ手段」の行、「補足: hub での具体例」の「別のモデル」の行。SO のレーンと、ほかのモデルを順に何本も試す仕組みは範囲の外。ほかのスキル（#391 が並行して直している）は触らない。
- 受け入れ基準は plan で決める。確定版の「issue に書いていないが要ること」の3点（「返らなかった」の見分け方・待ち時間の上限・切り替えの確かめ方）と、本文の「確かめること」の2点（Cursor のレーンで記録に何を残すか・Cursor の既定のモデルが Claude と違う会社か）と、4節の表の Codex と Cursor のセッションの行に答えを持たせる。
- SO: 設計 weak・実装 weak（各1レーン）+ Copilot 1ラウンド。レーンは Codex で、使えなければ Cursor へ切り替えてよい（切り替えたら理由をここに書く）。
- 注入された negative knowledge: 4件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み（2026-10-18）

- worktree `docs/#450_intake_cursor_fallback` を `wt switch --create` で作った。起点は master `b62d618` で、`git fetch` のあとの `origin/master` と同じであることを確かめた。
- 認識合わせは `issue-intake` の 1-2 の手順で確かめた。最後の行は `confirmed`・見出し4つで、URL は brief の「認識合わせ:」欄と文字列として一致した。確定版を前提にし、自分では通し直さない。
- 報告の宛先の統括は `oe-tree` に root `cockpit` として生きて出ている。委譲子の自分はその子として出ており、`$PARENT_TMUX_PANE` も同じ統括のペインを指していた。
- 読んだもの: #450 の本文・確定版・深掘り中の版。`SKILL.md` の3節の出力の形（162 行の「別モデル」の行）・4節（165〜200 行）・9節の表（275 行）・hub の具体例（297 行）。`so-compare` のスキル（終了コード・meta の項目・cursor の解決後のモデル・リトライとタイムアウト）と `scripts/so-compare.sh`（`classify_result`・集計・`run_cursor`・`CURSOR_MODEL` の既定）。#403 の plan の DJ-6・DJ-10。#412 の plan と episode。注入された knowledge item 4件。`document-format.md` の Plan と Episode の型・「ライフサイクル規範」節。

### P1: 上流の断定の裏取り（2026-10-18）

確定版と本文の断定を、手元の一次情報に当てた。

- **#391 の intake で Codex が返らなかった形**: 統括の作業層に残っていた出力を `tmp/450-intake-cursor-fallback/evidence-intake-391/`（gitignored）へ写して読んだ。Codex のレーンは `exit_code=1`・`timeout_status=error`・4秒・stdout 0 バイトで、stderr の最後の2行が `ERROR: You’ve hit your usage limit. …` だった。`so-compare` 自身は「全プロバイダ失敗」で終わっている（集計の式から exit 2）。`error` はリトライの対象ではないので、待ちは4秒で済んでいる。
- **Codex は stderr に問いの全文を出す**: 同じ stderr の上のほうに、渡したプロンプトがそのまま出ている。stderr 全体を「利用上限」などの語で検索すると、issue 本文にその語があれば誤って当たる（#450 の本文は「利用上限」を含む）。理由を読むなら最後の `ERROR:` の行を見るべきである。
- **Cursor のレーンに同じ問いが渡ったか**: 統括の2回の実行の `prompt.txt` は `cmp` で一致した（7752 バイト）。Cursor は52秒・`timeout_status=success`・`model_requested=composer-2.5`・`model_resolved=unavailable:cli-not-exposed` だった。
- **intake の問い合わせの所要時間**: hub の作業層に残る intake の問い合わせは4件で、Codex が11秒・15秒・19秒、Cursor が52秒だった（すべて上限180秒）。数が少ないので分布の裾は言えない。
- **待ちの最悪値**: `SO_TIMEOUT=180` のとき、`timeout_empty` なら ×1.5 の270秒で1回だけ延ばす（`retry_timeout_for`）ので、1レーンで最悪およそ450秒、切り替えると合わせておよそ900秒（15分）。確定版の「約15分」と一致した。延ばす倍率 `SO_RETRY_TIMEOUT_FACTOR` は環境変数では変えられない（スクリプトの中の固定値）。
- **Cursor の既定のモデル**: `so-compare.sh` の `CURSOR_MODEL="${SO_CURSOR_MODEL:-composer-2.5}"` で、指定が無ければ `--model composer-2.5` を渡す。Cursor の公式ブログ（https://cursor.com/blog/composer-2-5 ・2026-05-18）は「Composer 2.5 is built on the same open-source checkpoint as Composer 2, Moonshot's Kimi K2.5.」と書いている。Cursor 社が Moonshot AI のモデルを土台に学習させたもので、Anthropic とも OpenAI とも別の会社である。
- **Cursor のアカウントでは Claude のモデルも選べる**: `agent models` の一覧に `claude-opus-5-5-*`・`claude-sonnet-5-5-*` などがある。`--cursor-model` か `SO_CURSOR_MODEL` で Claude のモデルを指せば、Cursor のレーンでも Claude と同じ会社になる。`auto` も解決先が実行ごとに変わる（`so-compare` のスキルの実測）。「違う会社」と言えるのは既定の composer-2.5 のときだけである。
- **スキルの文面を照合する機械**: tests・scripts に `issue-intake` を参照するものは無い（`grep -rln issue-intake --include='*.sh' .` は0件）。`scripts/harness-check.sh` の「別モデル」は使い方の説明文の語で、このスキルとは関係ない。
- **並行する #391 との重なり**: #391 の枝（PR #451）は `issue-intake` の SKILL.md を変えていない。ただし knowledge item のうち `01M486Z2ND07GQWV1GHS1SVB0J`・`01M50MBKVB6T9QCKEGB8ZG1SET`・`01M2DEC1G68X8PH2QEW2H1DWZZ` に観測を追記している。この単位も closure で同じ item に観測を書き戻すので、同じファイルへの追記が衝突しうる。

昇格の印: Codex のレーンは stderr に問いの全文を出すので、stderr 全体を語で検索して失敗の理由を判定すると issue 本文の語に誤って当たる

### P2: plan を書き、受入の検査を写しで試した（2026-10-18）

- plan に、確定版と本文の各点への答え（DJ-1〜DJ-6）、打ち消す側の点検（DJ-7）、ゼロベースの代替（ゲート1）、直す8か所の旧文と新文（C1〜C8）、受入（D・N・S・M・R）を書いた。
- **直す箇所が brief の挙げた3か所から1つ増えた。** 3節の出力の形の「別モデル」の行（C1）である。4節の「上限を超えたら『返答が無かった』と書いて進む」を切り替えへ進む形に直すと、3節の値「返答なし」はどの規則からも書かれなくなる。残すと、返らなかったときに切り替えずに「返答なし」と書いて進む読みが残る。knowledge item `01M486Z2ND07GQWV1GHS1SVB0J` の4つの問いをスキル全体に当てて見つけた（plan の DJ-7 の表）。範囲を広げる判断なので、plan でゲート3 の判断事項にした。
- **表の Codex と Cursor のセッションの行は、規則を一般の形にして全行に切り替え先を置く案にした**（DJ-1）。Cursor のセッションで composer が動いているときだけは、`--cursor-only` が自分と同じモデルになるので `--codex-only` にする。Claude の行だけに切り替え先を置く案は、Codex のセッションで Claude が返らない場合だけ点検が抜ける理由が無いので退けた。
- **上限は180秒のままにし、最悪の合計（約15分）を書く案にした**（DJ-4）。intake の問い合わせの実測は4件ですべて60秒以内だが、4件では下げる根拠にならない。120秒（最悪10分）を対案としてゲート3 に残した。
- **受入の検査を作業層に4本置き、canonical は触らずに写しで試した。** 旧文と新文は `changes.py` に写し、`verify_plan()` で plan の文字列と一致することを確かめた。
  - 陰性対照: `check.py b62d618` は D1〜D34 と N1〜N6 の40項目がすべて FAIL、S1〜S3 が PASS。
  - 陽性対照: `apply.py` を当てた写しで43項目がすべて PASS。
  - 部分的に戻す試し: 変更を18の部分に分け、部分ごとに旧へ戻した写しと、C2 の最初の箇条を4節の末尾へ動かした写しの19通りで、どれも少なくとも1項目が FAIL した（knowledge item `01M50MBKVB6T9QCKEGB8ZG1SET`）。
  - 番兵 S1 の感度: 信頼できない入力の箇条を消した写しと、`description` を書き換えた写しで、S1 が FAIL した。
- 統括から補足が届いた（2026-10-18）。knowledge item 3件の観測の台帳は #391 の PR #451 も追記しているので、closure の前に `origin/master` を見て、マージ済みなら rebase してから足し、マージ前ならそのまま書いて PR に入れる前に知らせる、という指示である。plan の I3 の手順と同じ向きで、「PR に push する前に統括へ知らせる」を I3 に足した。

### 設計SO（ゲート2・弱・Codex 1レーン）の結果と採否（2026-10-18）

- `so-compare --codex-only` で plan の DJ-1〜DJ-7・直す文面・受入・選択肢拡張を問うた。`gpt-6.1-sol`（`model_resolved_source=config`）・`codex-cli 0.163.0`・153秒・初回で返答（`timeout_status=success`・16666 バイト）。Codex が返ったので、Cursor には切り替えていない。依頼文と出力は `tmp/450-intake-cursor-fallback/so-design-prompt.md` と `so-design-codex/`（作業層）。
- 結論は「修正後に再レビュー」だった。方向（A）は妥当で、失敗の判定の優先順位・送る前のモデルの確かめ・切り替えられないときの終わり方を明文にせよ、という内容である。指摘は8件で、8件とも採った（8件目は一部）。表は plan の「設計SO（ゲート2）」節にある。
- 指摘の根拠は、ソースの行に当てて確かめてから採った。`unavailable:perl` は `so-compare` 自身の依存の検査で出る。設定値の検査は回すレーンの分だけである。再試行の判定は `timeout_empty` だけを見る。どれも SO の言うとおりだった。
- **判定の順序の矛盾（指摘1）は、自分の4つの問いの点検では見つけられなかった。** 「エラーで終わったら返らなかった」と「途中でも答えが読めれば返った」は、同じ C2 の中で並んでいた。DJ-7 の表の (3)「足した運用と逆を言う既存の規則」は既存の規則しか探しておらず、足した文どうしの矛盾は見ていなかった。knowledge item `01M486Z2ND07GQWV1GHS1SVB0J` の予測（足した文は節の中では正しく見える）の、足した文どうしの版である。答えが読めるかを先に見る順序に一本化した。
- **送る前のモデルの確かめ（指摘2）は、確定版の「記録に何を残すか」を記録の問題としてだけ読んだ結果の抜けだった。** 送ったあとの meta では、同じ会社のモデルへ issue を送ったあとに気づくだけで、「返ったら切り替えない」「2周目はしない」と衝突して取り返せない。切り替えのコマンドの先頭に `SO_CURSOR_MODEL=` を置いた。`so-compare` は `${SO_CURSOR_MODEL:-composer-2.5}` で読むので、空にすれば既定に戻る。
- **受入の穴（指摘7）は、部分的に戻す試しを通したあとに見つかった。** SO は、C6 の囲みを消す・矛盾する規則を足す・C2 の2つ目の箇条を4節の末尾へ動かす、のどれをしても43項目がすべて通ることを再現した。部分的に戻す試しは「消す」と「旧に戻す」の写ししか作っておらず、「足す」「動かす」「囲みを壊す」写しを作っていなかった。knowledge item `01M50MBKVB6T9QCKEGB8ZG1SET` は「消す・旧文に戻す・位置を動かす」を挙げているが、自分は位置を動かす写しを最初の箇条1つにしか作っていなかった。変更前に C1〜C8 を当てた期待の全文との一致（F1）を足し、3つの壊し方で F1 が落ちることを確かめた。この item の除外条件（受入が変更後のファイル全体を合意した全文と照合している場合）に当たる形へ移したことになる。

昇格の印: 部分的に戻す試しは消す・戻す写ししか作らないので、足す・動かす・囲みを壊す写しで通る穴が残る。全文の一致を受入に入れると塞げる

- 直したあとの検査の結果（写しの上・canonical は触っていない）:
  - 陰性対照: `check.py b62d618` で F1・D1〜D35・N1〜N6 の42項目が FAIL、S1〜S3 が PASS。
  - 陽性対照: 写しで45項目がすべて PASS。
  - 部分的に戻す試し: 19の部分と位置を動かす1通りの20通りで、どれも F1 のほかに D か N が FAIL した。
  - 設計SO の3つの壊し方: どれも F1 が FAIL した。
  - plan と写しの一致: `verify_plan()` で、plan に載っていないブロックは無い。
- 指摘8は一部を採った。M に空・途中までの答え・環境変数の上書き・呼び方の誤りを足し、R を11の場面に広げた。サブエージェントは2回にまとめた。共通の依存（`perl`）が無い場面は、PATH から `perl` だけを外す環境を作る手間に見合わないので、ソースの確かめ（M9）と読み取り（R6）で受ける。
- 選択肢拡張で出た G（非同期の依頼にする）と H（一覧を見せずに独立に作らせる）は、どちらも #450 の範囲を超える設計なので採らなかった。H は plan の「範囲外で気づいたこと」に残した。
- 上限の判断（指摘6）について、SO は「180秒を暫定で保つのは妥当だが、4件の実測は15分を許す根拠にならない」とした。15分を許すかを owner の判断として、ゲート3 の判断事項に入れた。

### P3: 報告して止まった（2026-10-18）

- plan と episode を commit `5059ca4` で枝に載せ、push した。PR はまだ作っていない。
- `.oe/report-450.md`（作業層）に `implementer-contract` の形で報告を書いた。Status は `DONE_WITH_CONCERNS` にした。直す箇所が brief の挙げた3か所から1つ増えたこと（C1）と、最悪15分の待ちを許すかが owner の判断に残ることが、完了の判断に効くためである。
- 報告の宛先の統括が `oe-tree` に root `cockpit` として生きて出ていることを確かめてから、`projects/orchestration-engine/bin/oe-send` で plan と報告のパスを1行送った。exit 0。
- ゲート3 で owner に決めてほしいことは4つで、plan の「GATE 3」節に書いた。承認が統括から届くまで、I1 には入らない。

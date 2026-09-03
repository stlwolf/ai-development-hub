---
id: 01M1HDRJTVVG2708DGKH98VGN7
title: "#307 段階1 — Opus 5 世代の指針で rules 14本を棚卸しする（情報の取り直し・runtime 採取・判定表・plan）"
date: 2026-09-03
type: episode
status: draft
related:
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/307"
    reason: "本 issue。段階1（判定表 + plan まで）。rules の書き換えは次アーク"
  - type: refs
    ref: "docs/research/2026-08-17-opus5-rule-shift-intake.md"
    reason: "材料の正本（S-1〜S-4・F-1〜F-10・O-1〜O-5）。本 episode はこれを取り直す"
tags: [harness, rules-audit, opus5, lean-system-prompt, runtime-capture]
---

# episode — #307 段階1 rules 14本の棚卸し

本文はリアルタイム追記である（後追い再構成ではない）。closure はマージ前に書く。

- baseline: master `d93eee3`
- worktree: `/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub.docs-#307_opus5-rules-audit`（branch `docs/#307_opus5-rules-audit`・`wt switch --create` で自作。cwd は追従しないので絶対パスで作業）
- brief: `.oe/brief-307-opus5-rules-audit.md`（親 repo 側・作業層）
- 終端: brief の step P-4（plan + 設計SO の結果の報告）。rules の書き換え・PR・マージ・issue close・worktree 掃除はしない
- 時間予算: 約1時間半（02:20 JST 目安）。着手 00:58 JST
- 委譲元: cockpit 統括12代目（親ペイン）。実行者: Fable 5.1（Claude Code 2.1.258・effort xhigh・auto mode）

## 0. なぜこの作業が始まったか

Opus 5 世代で公式のプロンプト指針が反転し（自己検証の指示は削れ・委譲は抑えろ）、同時に Claude Code 本体の system prompt が lean 版に切り替わった。常時ロードされる `canonical/rules/` 14本（359行・4,477語）がこの前提の変化に照らして「本体と食い違う / 本体と重なる / 公式推奨から離れている」かを判定し、さらに「在ったのに発火しなかった」実績（#307 コメント3件目の9件）を軸に足して、残す・書き換える・退役・保留を決める。本アークは判定表と plan まで。

## P-0. 着手時の判断（2026-09-03 00:58〜）

### 蒸留木の置き場を決めた

`docs/harness/{discussions,plans,episodes}/` を新設した。理由は1行: 判定対象が `canonical/rules/`（3ツールへ配布するハーネス全体）で、既存の `docs/orchestration-engine/` 木は engine スコープの実名なので合わない。`git mv` で戻せる可逆判断なので迷わなかった。`document-format.md`「ファイル命名規約」節〔§9〕の「リポジトリ直下の蒸留木は `docs/{name}/` で `{name}` はスコープの実名」に従い、実名は issue が使う「ハーネス」を採った。

### 親の値を写さずに自分で数え直した

- `ls canonical/rules/` は 14 本。`wc -l -w` は 359 行 / 4,477 語。親の値と一致した。
- `~/.claude/rules/` は symlink 14 本で全て `canonical/rules/` を指す（配布の実体）。
- `~/.claude/settings.json` の `env` キーは存在しない（空）。`effortLevel: xhigh`・`model: fable[1m]`・hooks は 6 event。
- `claude --version` は 2.1.258。
- `command -v oe-send` は exit 1（PATH に無い）。報告の送信は `projects/orchestration-engine/bin/oe-send` の絶対パスで呼ぶ。

## P-1. 情報の取り直し（進行中）

外部の取り直しは2本の subagent に分けて並列で投げた（公式一次 / 記事6件+未読1件+Goodpatch+新規探索）。理由: 互いに独立で、いずれも複数ページの読みを要するので、公式の「本当に独立して並列化できる大きなタスク」に当たると判断した。changelog の差分と F-1 は計測器の健全性が要るので自分で取った。

### changelog の差分（自分で取った）

期待値を先に置いた: 対象範囲は v2.1.155〜v2.1.258（`CHANGELOG.md` 先頭〜v2.1.154 見出しの直前）。キーワード（system prompt / lean / verbos / concise / CLAUDE.md / .claude/rules / effort / subagent / Opus 5 / Fable / Opus 4.8）で 1 件以上ヒットするはず。陽性対照は v2.1.154 の「The lean system prompt is now the default」行が同じ正規表現で拾えること。

結果: 陽性対照は拾えた（192 行の中に含まれる）。範囲内ヒットは多数。`SIMPLE_SYSTEM_PROMPT` は changelog 全 6,179 行（08-17 時点 5,534 行から増えた）で 0 件のまま。要約は `.oe/report-307-P1.md` に書く。

### F-1 の計測器を先に確かめた（バイナリの文字列）

期待値を先に置いた（ただし episode 作成前だったので、期待値はコマンドのコメント行に書いた。ここに正直に写す）: 研究ノートは「changelog に一度も現れない」としていたので、バイナリにも `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` は **無い**と予想した。陽性対照は `CLAUDE_CODE_[A-Z_]*` の環境変数名が多数拾えること。

結果: 予想が外れた。陽性対照は 577 種の名前を拾い、その中に `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` が**在った**（4 箇所）。分岐の読みは「値が truthy なら lean を強制・falsy なら lean を解除・無指定なら model 名と feature flag で決める」。これはコードの読み（runtime 実体）であって発火の実測ではないので、次で実機に当てる。

昇格の印: changelog に無い環境変数がバイナリには在る。「changelog 不在」を「機能不在」と読んではいけない（NK 01KYMRE1N7N0J8VP3CBZZEZ8Q3 の型）

## P-2. runtime 採取 + F-1 実機確認

### F-1 の期待値と陽性対照（測る前に宣言・2026-09-03 01:06 JST）

観測量: headless `claude -p --max-turns 1` に「system prompt の H1 見出し（`# ` で始まる行）を逐語で列挙し、末尾に `H1_COUNT=<n>`」と頼み、見出し集合を比べる。ツール禁止。

| run | 条件 | 期待 |
|---|---|---|
| R1 | model fable（settings 既定）・env 無指定 | lean 集合。自セッションの見出し（Harness / Session-specific guidance / Memory / Environment / Scratchpad Directory / Context management / Delivering work / Writing for the user）と一致するはず |
| R3（陽性対照） | `--model sonnet`・env 無指定 | changelog v2.1.154 の除外規定どおり長版。R1 と**異なる**集合が出るはず。R1 と同じなら計測器が壊れている（= 測れない） |
| R2 | model fable・`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0` | バイナリの読みが正しければ R3 と同じ側（長版）。R1 と同じなら「効かない」 |
| R4（補助） | `--model sonnet`・`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1` | truthy 分岐の確認。R1 側（lean）に寄るはず |

3値の付け方: R3≠R1 が成立し R2≈R3 なら「効く」。R3≠R1 が成立し R2≈R1 なら「効かない」。R3≈R1 なら「測れない」（計測器不良）。

### P-1 の完了と報告（01:10 JST）

- 2本の subagent が戻った（公式3ページ全文・記事8本 + 新規探索約30候補）。要約は `.oe/report-307-P1.md` に書き、`oe-send` の exit 0 と `oe-events.jsonl` の自分の `message_sent` を確認した。
- ノートとの差分は8点（並列20体の数値が公式から消えた / effort は一律 high 起点に言い換え / 公式文に自己検証と外部検証の区別なし / 本体が `claude_code` プリセットで委譲抑制を自前注入 / shimo4228 は3段で S-4 はノートの命名 / F-1 変数はバイナリに実在 / Concise output style と `/doctor` 刈り込み提案 / Goodpatch の全削除運用は伝聞 + 未実施）。

昇格の印: 「自己検証（モデル内部の再確認）と外部検証（ソース照合・別モデル）は別物」という区別は公式文に無く、当リポジトリ側の解釈である。論点2 の判定はこの帰属の上に立つ

昇格の印: shimo4228 は棚卸しの後に rule へ `rationale:` / `review-when:` を足し、世代交代ごとに再監査する skill を作った。「意図・根拠・失効条件」を rule 本文のメタデータとして持つ形は、当リポジトリの 14 本にはまだ無い

### F-1 の実測 — 1回目（01:06〜01:10）

R1（fable 既定・env なし）は 24 秒で返り、H1 見出し 7 個（Harness / Session-specific guidance / Memory / Environment / Context management / Delivering work / Writing for the user）。自セッションの 8 個から Scratchpad Directory が抜けた形で、lean 側の期待と一致。

**失敗を1つ記録する。** R3（sonnet 対照）は自作の `run` 補助関数で `env ... --` と書いたため `env: --: No such file or directory`（exit 127）で走っていなかった。出力が空なのを「lean だから短い」と読まなくて済んだのは `.meta` に exit code を別ファイルで残していたから。R2 / R3 / R4 を補助関数なしの明示コマンドで再実行した。

### F-1 の実測 — 2回目（01:10〜01:13）と結論

R2（fable + `=0`）= 11 見出しで長版側、R3（sonnet 対照）= 9 見出しで長版側、R4（sonnet + `=1`）= 5 見出しで lean 側。R3 ≠ R1 が成立したので計測器は弁別できており、R2 は R3 側に落ちた。**3値は「効く」。** 表は `.oe/runtime-capture-307.md` §4 と discussion §3。

期待と違った点が1つ: fable の長版は sonnet の長版より2節多く（Delivering work / Writing for the user）、その2節は fable の lean 版にも在る。つまり簡潔さ・結論先行の規定は Claude 5 世代向けに本体が足したもので、「anti-verbosity の規定は長版側にある」（記事 F）は fable には当たらない。研究ノート O-1 の「本体が応答形式の規定を持たなくなった」も半分外れで、**本体は形式の一般則を lean 版でも持っている**。持っていないのは日本語語彙・生 URL・関連リンク節のような owner 固有の契約である。判定表の output-format 行はこの実測で「§1〜§4 ↓ / §5〜§9 ↑」に割れた。

昇格の印: 研究ノート O-1 の前提（lean 版は応答形式の規定を失った）は fable の実測で半分覆った。本体は一般形式を持ち、owner 固有の契約だけが残る

## P-3. 判定表（01:13〜01:17）

`docs/harness/discussions/2026-09-03-discussion-307-rules-audit-judgment.md` に書いた（196 行）。表は4枚に分けた（三分類 + 帰属 / 四観点 / 発火実績の9件割当 + 自己観測 / 判定 + 方向 + 理由 + 帰属）。判定の内訳は 残す 4・書き換える 7・退役 2・退役 + 保留 1。

判定で迷った点を2つ残す。

- skill-first-operations は Claude の本体 Skill 定義と同義で退役だが、Cursor / Codex の runtime を採っていない。canonical から一律に消すか Claude 配布だけ外すかは論点4 として owner に上げた。
- 9件の割当は「規範が在った場所」列が rule 名を挙げていないので、exhaustion 以外は `unknown` にした。無理に割り当てて `unfired` を増やすと、帰属の弱い判定で rule を動かすことになる（NK 01KYMRE1NE4HSGZR7T4XPA9JW8 の型）。

## P-4. plan と gate 2（01:17〜）

### gate 2 の期待値（測る前に宣言）

`oe-refute --lanes 3`（codex + claude + cursor・rubric exploration）に claim `.oe/claim-307-gate2.md` を渡す。期待: verdict は `refuted` が出てもよい（exploration は見落としを出させる場）。**少なくとも1レーンが「Claude の runtime だけで3ツール配布の退役を判定している」（論点4）か「9件の割当が exhaustion に偏っている」を突く**と予想する。3レーンとも何も突かなければ、それは claim 本文の観点列挙がレーンを誘導しすぎた疑いとして読む。

### plan を書いた（01:22）

`docs/harness/plans/2026-09-03-plan-307-rules-audit-stage2.md`（175 行）。8 PR を直列にした理由は `CATALOG.md` と sync 設定が全 PR の共通 hotspot だから（並列委譲で同一ファイル追記が衝突した前例が memory にある）。PR の順序は公式ドリフトが最も明確な `subagent-strategy` を先頭に置いた。

plan-first の規律で commit も PR もしていないので、**この3文書（episode / discussion / plan）が master に着地する経路は決まっていない**（docs だけの PR を切るか、段階2 の PR-1 に同梱するか）。P-4 の report で親に上げる。

### NK 5 item への観測（closure 時に item の `observations` へ写す下書き・本文はここが正本）

| item | state | 観測 |
|---|---|---|
| 01KYJ76D830XME16ZFXC2XRPZZ（母集団から列挙） | not_followed（部分） | 注入源の種類は `ls` / `settings.json` / 自セッションの context の実体から数え、9件の rule 割当も無理にしなかった（この範囲は followed）。しかし**配布先**（Cursor は rules 本文を配布しない）を CATALOG の記述と記憶から数え、**モデル**（owner の主モデルは Opus 5。`settings.json` の `model` は統括用）を settings から「既定」と結論した。どちらも gate 2 と owner の指摘で拾われた。母集団は sync script の実体と実際に動いているセッションから数えるべきだった |
| 01KYMRE1N7N0J8VP3CBZZEZ8Q3（0件と計測器） | followed | changelog grep とバイナリ grep の両方に陽性対照を置いた。結果、研究ノートの「changelog 不在」を「機能不在」と読む誤りを避け、環境変数がバイナリに実在することを拾えた。F-1 の1回目で対照レーンが exit 127 で空出力だったのを、exit code を別ファイルに残していたので lean と誤読しなかった |
| 01KYMRE1NC7XX6N66RQ0MGGHF1（上流断定の強さ付け直し） | followed | Goodpatch の「全削除運用は研究中」を「伝聞 + 著者未実施」に、記事 F の F-1 記述を「著者未検証」に、研究ノート O-1 の「本体が形式規定を失った」を「半分外れ」に、公式の「並列20体」を「例文から消えた」に、それぞれ今日の確認結果で付け直した |
| 01KYMRE1NE4HSGZR7T4XPA9JW8（根拠の帰属を列で） | followed | 判定表の4表すべてに帰属列（公式文 / runtime 実体 / 発火実測）を置き、9件の割当には帰属の強さ列を足した。自己観測は「弱い証拠・自己申告」と別段落に隔離した |
| 01KZVHE0KQ5VCX0SXH0F4SM14D（先例の前提を確かめる） | followed | shimo4228 の Step 1 は単一ツールの環境が前提で、当環境は3ツール配布 + hooks / skills 注入なので、母集団表に hooks / skills / agent 型 / output style を足した。ただし Cursor / Codex の runtime は採れておらず、その穴は論点4 として owner に上げた（前提の欠けを埋め切れてはいない） |

### gate 2 — 1周目の結果（01:19〜01:23）: codex / cursor が timeout_empty

`oe-refute --lanes 3 --rubric exploration` を起動した。so-compare の上限は codex / cursor 240 秒・claude 1,200 秒。**codex と cursor は 240 秒で出力空のまま timeout**（`status=timeout_empty`）。codex の stderr（360 KB）を見ると repo のファイルを次々に読んでいた。claim 本文に「読める環境なら一次ファイルを開いてよい」と書いたことが、240 秒の枠には合わなかった。claude レーンは継続中。

これは #298（SO timeout）で既知の型で、今回は claim の書き方が誘発した。対処: claude レーンは待つ。codex + cursor は「ファイルは開かない・400 語以内」と明記した短縮版 claim（`.oe/claim-307-gate2-r2.md`）で `--lanes 2` を再走する。2周目も空なら、弱 SO の規則（最低1レーン）に claude レーンの結果だけで当て、partial を disclose する。

昇格の印: 反証レーンに「ファイルを開いてよい」と書くと 240 秒の枠を超えて空になる。claim は本文だけで判断できる密度に畳み、探索の許可は timeout の長いレーンに限る

### gate 2 — 2周目と claude レーンの結果（01:27〜01:33）: 3 / 3 refuted・期待どおり論点4 と帰属を突かれた

- 2周目（短縮 claim・ファイル禁止・480 秒）は 59 秒で codex / cursor とも `refuted`。1周目の claude レーンは 476 秒で `refuted`。**宣言した期待（少なくとも1レーンが論点4 か 9件の帰属を突く）は3レーンすべてが当てた。** 3レーンとも何も突かなければ誘導を疑う、と書いた側の心配は要らなかった。
- 指摘は写さず自分で確かめた。`check-codex-guardrails.sh` が14本の見出し語を AGENTS.md に必須としていること（`require_pattern` 14行）、`sync-codex.sh:270` がそれを `set -euo pipefail` 下で呼ぶこと、`sync-cursor.sh` が `canonical/rules` を配らず `canonical/cursor/rules/cursor-first-turn.mdc` 1本だけを置くこと、`docs/issues/38` `docs/issues/67` に 2026-04 の rule 別発火データがあることは、すべて事実だった。
- **自分の見落としで最も大きかったのは配布実体。** S-1 で「3ツール配布」を前提に母集団を組んだが、sync script を実体で読んでいなかった。rule 本文を常時ロードしているのは Claude だけで、Cursor / Codex の問題は AGENTS.md 要約の問題だった。NK 01KYJ76D830XME16ZFXC2XRPZZ（母集団から数えよ）は注入源では守れたが、**配布先の母集団は索引（CATALOG の「3ツール」記述と自分の記憶）から数えていた**。この item の観測は `followed` から「注入源は followed・配布先は not_followed（gate 2 が拾った）」に付け直す。
- Fable 5.1 公式（claude レーンの指摘）を自分で開いた。「Fable 5 のプロンプトはそのまま効く」・over-verification 節は無い・anti-formatting 言語は「いつ整形が適切か」の記述形へ置き換えよ、の3点を discussion §10.3 に書いた。self-check 退役の根拠が Opus 5 文書に偏っている問題は HG-1 の確認項目に足した。
- 判定の変更は discussion §10.1（変更行のみ）。内訳は 残す 3 / 書き換える 9 / 退役 2 になった。plan は Step 2 を分割し、Step 7 を縮小し、索引と guardrail の同時更新を AC-共通に入れた。

昇格の印: 反証レーンが sandbox の外にある worktree の判定表を読めなかった。設計SO に渡す成果物は repo 内の読める位置に置くか、claim 本文に判定表を全文写す

昇格の印: 「3ツール配布」の考慮は CATALOG の記述と記憶から出ており sync script の実体を読んでいなかった。配布先の母集団も実体から数える

### gate 2 — 1周目の集約（02:01 に確認）と時間

1周目は so-compare が codex を 360 秒で自動再試行し、212 秒で `refuted`（要点は2周目と同じ「Claude 限定 runtime から共通退役へ一般化」）。cursor は集約で `error`（VERDICT 行なし）。1周目全体は 1,049 秒・2 / 3 refuted・全体 refuted。2周目（59 秒・2 / 2 refuted）と合わせ、**設計SO は3レーンすべてが返り、すべて refuted**。弱 SO の規則（最低1レーン・partial は disclose）は満たしている。

時間の記録: 01:34 に反映を終えた直後、owner の利用枠が尽きてセッションが約 27 分止まった（02:01 復帰）。予算終端 02:20 に対し P-4 の report 送信で閉じる。

## closure（未・マージ前に書く）

本アークの終端は P-4 で、closure は段階2 の PR レビュー後・マージ前（gate 5）に書く。NK 5 item への観測は上の下書きを写す。ただし 01KYJ76D830XME16ZFXC2XRPZZ は「注入源は followed・配布先は not_followed」に付け直す（gate 2 の節を参照）。

### 差し戻し1件（統括 fact-check・02:05）: §4.4 の集計行が gate 2 前の値のままだった

§10.1 に修正後の判定を書いたとき、§4.4 は見出しに「gate 2 前の判定」と注記して表と集計行を残していた。統括の fact-check が「集計行が旧値（残す4/書き換える7/退役2/退役+保留1）のまま」と差し戻した。**注記で逃げず本体を揃えるべきだった。** 表の該当9行を §10.1 の内容に書き換え、集計行を「残す 3 / 書き換える 9 / 退役 2」にし、見出しの注記を「gate 2 反映後（経緯は §10.1）」に直した。表本体から機械的に数え直して 3 / 9 / 2 を確認した。§4.1（三分類）と §4.3（発火実績）は gate 2 前のままで、差分は §10.1 が持つ。commit はしていない。終端は P-4 のまま HG-1 待ち。

## P-2 追補（前提訂正・03:36〜）: owner の主モデルは Opus 5

### 何を仮定していて、なぜ拾えなかったか

owner が 03:22 JST に指摘した（統括の追補 `.oe/addendum-307-opus5-runtime.md`・owner 承認 03:28）。私は `~/.claude/settings.json` の `model: fable[1m]` を「既定モデル」と読み、S-1 の runtime 採取と F-1 を自分のセッション（Fable 5.1）だけで済ませていた。**settings.json は統括セッション用の設定であり、owner の作業セッションは Opus 5 で動いている。** 判定表の「本体が持つ」列は Fable の runtime に立っており、Opus 5 では成立しない行がありうる。

拾えなかった理由は2つ。(1) 「モデル」を注入源の母集団に入れていなかった。S-1 の母集団表は注入源の種類（本体・ツール定義・rules・memory・hooks・skills）を数えたが、**本体の中身がモデルで変わる**という軸を母集団に置かなかった。(2) 設定ファイルを読んで「既定」と結論し、実際に動いているセッションの母集団（oe-threads で見える他セッション）から数えなかった。NK 01KYJ76D830XME16ZFXC2XRPZZ の観測は「注入源は followed・配布先とモデルの母集団は not_followed」に付け直す。

昇格の印: runtime 採取の母集団には「どのモデルで動くセッションか」の軸が要る。設定ファイルの `model` は採取したセッションの値であって、owner の作業セッションの値ではない

### Opus 5 採取と F-1 の期待値（測る前に宣言・03:37）

方法は P-2 と同じ headless（`claude -p --model opus --max-turns 1 --output-format text`・入れ子検出の環境変数を外す）。統括の値（7節・Corrections あり・Writing for the user なし）は写さず、自分の run で確かめる。

| run | 条件 | 期待 |
|---|---|---|
| R5 | opus・lean・H1 列挙 + MODEL 行 | MODEL は `claude-opus-5`。H1 は Fable の7節と**同じではない**と予想する（統括の1 run が外れている）。具体的には Writing for the user が無く Corrections がある7節。ただし n=1 なので統括の run と違えば run 間のゆらぎとして両方記録する |
| R6 | opus・`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0` | 長版。Fable の長版と同じく System / Doing tasks / Executing actions with care / Using your tools / Tone and style を含み Harness を含まない。Corrections が長版にも残るかは不明（残ると予想） |
| R7 | opus・Delivering work の逐語 | Fable の同節と同文（依頼範囲・careful colleague・全部やる・ブロック部分の明示）。差があれば行単位で記録 |
| R8 | opus・Corrections の逐語 | 未採取の節。仮説: 公式の「Opus 5 は自己訂正を語りすぎる」に対応し、訂正は短く・語りすぎない、を指示する節 |
| R9 | opus・H1 の外の無題段落 | Fable と同じ段落集合（自律運転・問題を述べている段では直さない例外・ターン終了前・状態変更前・確認と報告）。欠けがあれば判定表の「本体が持つ」が Opus で崩れる |
| R10 | opus・ツール定義（Skill / Agent / Bash / Read）の該当文 | ツール定義はモデル非依存で Fable と同文と予想 |

3値の付け方（F-1・Opus）: R6 が R5 と異なる集合で Doing tasks / Tone and style を含めば「効く」。同じなら「効かない」。R5 自体が Fable と同じ7節なら統括の観測と食い違うので両方記録して「測れない（ゆらぎ）」を疑う。

### Opus 5 採取の結果（03:38）と、切り分けが要る点

- R5: MODEL=`claude-opus-5`。H1 は Harness / Session-specific guidance / Memory / Environment / Context management / Delivering work / **Corrections** / MCP Server Instructions（8。最後は MCP の注入見出しで本体ではない）。**Writing for the user が無く Corrections がある**。統括の run と一致（期待どおり）。
- R6（`=0`）: 11 節（System / Doing tasks / Executing actions with care / Using your tools / Tone and style / Session-specific guidance / auto memory / Environment / Context management / Delivering work / Corrections）。**F-1 は Opus 5 でも効く**。Corrections は長版にも残る。
- R7: Delivering work は Fable の同節と逐語一致（自分の context と比較）。期待どおり。
- R8: Corrections の中身は「不要な自己訂正を避けよ。user の code・結論・判断が変わる誤りだけ訂正し、短く述べて続けよ。謝罪や前置きを足すな。他 agent の報告を鵜呑みにするな。**正確だった発言を再監査するな（どう検証したかも含めて）**」。仮説（公式の「自己訂正を語りすぎる」への対応）どおり。self-check 型の指示を本体が積極的に抑えている節で、implementation-principles 2行目の ↓ を Opus 側から強める。
- R10: Skill / Agent / Bash / Read の該当文は Fable と逐語一致。期待どおり。
- **R9 は期待から外れた。** Opus 5 は逐語再現を断りつつ「自律運転・問題を述べている段で直さない例外・ターン終了前の確認・状態変更前の確認の段落は自分の指示に無い。在るのは不可逆操作の確認と忠実な報告で、見出しの下にある」と答えた。

期待から外れた点を、モデル差と読む前に **permission mode 差**の可能性を疑う。私のセッションは `auto` で起動されており、「You are operating autonomously」で始まる段落は auto mode か委譲子に固有の注入かもしれない。headless の既定 mode では Fable にも無い可能性がある。

### 切り分けの期待値（測る前に宣言・03:40）

方法: 逐語ではなく PRESENT / ABSENT の7項目チェックリストを答えさせる（R9 の拒否を避ける）。条件は fable / opus × 既定 mode / `--permission-mode auto`（flag が無ければ既定 mode の2条件だけ）。

| 項目 | 期待 |
|---|---|
| (a) 自律運転・質問は作業を止める | auto のみ PRESENT（モデル非依存） |
| (b) 問題を述べている段では直さず評価を返す | auto のみ PRESENT |
| (c) ターン終了前に最後の段落を点検 | auto のみ PRESENT |
| (d) 状態変更コマンドの前に証拠を確かめる | auto のみ PRESENT |
| (e) 不可逆は確認・削除前に見る・忠実に報告 | 全条件 PRESENT |
| (f) Writing for the user 節 | fable のみ PRESENT（mode 非依存） |
| (g) Corrections 節 | opus のみ PRESENT（mode 非依存） |

外れ方の読み: (a)〜(d) が opus 既定で ABSENT・fable 既定で PRESENT ならモデル差。両方 ABSENT で auto で PRESENT なら mode 差。判定表への効きは mode 差なら「auto mode の行だけ競合」、モデル差なら「Opus 列で独立」。

### 切り分けの結果（03:41）: 期待が外れた。差は mode ではなくモデル

fable は既定でも auto でも (a)〜(f) PRESENT・(g) ABSENT。opus は既定でも auto でも (a)〜(d) ABSENT・(e) PRESENT・(f) ABSENT・(g) PRESENT。**「auto mode の注入だろう」という私の読みは外れ、Fable 5.1 の lean 本体が Opus 5 より多くの段落（自律運転・問題報告時の例外・ターン終了前・状態変更前・Writing for the user）を持っている。** 表は `.oe/runtime-capture-307.md` §5.5。

判定への効き（主モデル Opus 5 基準）:

- decision-pacing: 「問題報告≠修正決定」は Opus の本体に無い。退役から**1行に縮約**へ（do-nothing 条項は owner feedback どおり削る）。判定値が変わる。
- output-format: §1 結論先行も §9 の記号禁止も Opus の本体に無い。書き換え（§1 ↓）から**残す・強める**へ。判定値が変わる。
- implementation-gate: Opus では自律運転の段落が無く競合しない。値は「残す」のまま。「強める（本体の該当文より優先と宣言）」は Fable 列の考慮になるので、宣言文は世代・モデル非依存の言い方にする。
- execution-policy: code block 行は Opus の本体に無いので削らない。値は「書き換える」のまま（TODO 行のツール名を外す）。
- implementation-principles: Opus の Corrections が「検証の再監査をするな」と言うので 2行目の ↓ は Opus 側で強まる。値は不変。

判定値が変わる行は **2行**（decision-pacing・output-format）。追補の規則「3行以上なら claude レーン再走・3行未満なら再走せず disclose」に従い再走しない。数え方は「残す / 書き換える / 退役 の値が変わった行」で、implementation-gate の「強める」の有無は値の変化に数えていない。この数え方で 3 行と読むなら再走が要るので、report に判断点として書く。

昇格の印: lean 本体の中身は同じ Claude Code の版でもモデルで違う（Fable 5.1 は自律運転・形式・Opus 5 は Corrections）。「本体が持つ」は版ではなくモデル×版で言う

昇格の印: F-1 は Opus 5 でも効く（長版 11 節）。undocumented である点は変わらない

## HG-1（owner の gate 3 裁定・03:55）と終端の更新（P-4 から P-5 へ）

統括が owner から質問形式で取った裁定を ruling として渡してきた（14:45 に受領）。裁定は plan の論点表と「HG-1 で確定した追加の裁定」、discussion §6.1 に写した。要点は、世代非依存 + frontmatter に見直し条件1行 / evidence-verification は残し冒頭1行・§3 維持 / effort は rule で扱わない / skill-first-operations は canonical から退役（AGENTS.md・guardrail・CATALOG 同梱）/ F-1 は既定を変えず計測の物差し / output-format §5 は見出しをやめて行頭ラベル / SO は再走しない。

**終端の再定義。** 裁定 (6)「docs だけを先にコミットし draft PR を1個作る。マージはしない」により、Stage 1 の終端が P-4（plan + 設計SO の報告）から P-5（docs コミット + draft PR）へ変わった。brief の終端定義の変更なので `implementer-contract` のガード (a) に当たるが、根拠が owner の gate 3 裁定であり、統括の指示文が「終端の再定義であり owner gate 3 が根拠」と明示している。確認の一往復は済んでいると判断し、指示どおり**plan を先に更新してから**実行する。plan の Stage 1 に P-5 を追記し、STOP の位置を P-5 の後へ動かした。

統括の申し送りも記録する: 主モデルの前提（Opus 5）を brief に書かなかったのは統括側の誤りで、brief の「親が確認した事実」に統括用の `model: fable[1m]` を置いたことが owner の作業モデルと読める形になっていた。母集団の軸そのものは brief が与えていなかった。次の棚卸しでは基準線を「主モデル × 版」で brief に宣言する、とのこと。私の側の見落とし（settings から「既定」と結論した）は前節のとおりで、両方が重なって拾えなかった。

### P-5 の実行記録（14:46〜）

- commit 前に worktree の `git status` で `docs/harness/` 以外の変更が無いことを確かめる（`.oe/` は gitignored）。
- 3文書は段階1 の1単位（判定表・plan・その作業記録）なので1コミットにする。型は docs、scope は harness。
- push して draft PR を1個作る。マージしない。Copilot レビュー依頼は不要（docs のみ・draft）。
- issue #307 に HG-1 の裁定と PR の URL をコメントする。
- `.oe/report-307-P5.md` に file 先行で報告し、`oe-send` で1行送って STOP。episode closure はまだしない（gate 5・マージ前）。

- 14:47: worktree の `git status` は `docs/harness/` の untracked だけだった。3文書を1コミット `dc977a1`（docs(harness)）にし、origin/master が `d93eee3` のまま動いていないことを確かめて rebase なしで push した。
- 14:48: draft PR #358 を作成（`--draft --assignee @me`・Copilot 依頼なし）。本文に「マージしない」「段階2 の着手時に扱いを決める」を明記。
- 14:49: issue #307 に HG-1 の裁定表・PR・3文書のリンク・判定の内訳・前提訂正の要点をコメントした。

このコミットで episode / discussion / plan は committed 層に入った。本節（P-5 の実行記録）はコミット後に書いたので、2つ目のコミットとして同じブランチに入れる。以後の追記も closure（gate 5）の前に同じブランチへコミットする。作業層の report / runtime capture / claim は `.oe/` に残る（gitignored）。

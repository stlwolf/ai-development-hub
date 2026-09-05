---
id: "01M1HDRJTVPDA1ADFCM0N4A3A3"
title: "#307 段階1 — canonical rules 14本の判定表（競合 / 冗重 / ドリフト + 意図 / 根拠 / 鮮度 / 失効条件 + 発火実績）"
date: 2026-09-03
type: discussion
status: draft
related:
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/307"
    reason: "本 issue。段階1 の判定表。owner の gate 0 決定（範囲 A・減らす方向・2方向判定の明示・世代非依存は推奨のみ）に従う"
  - type: refs
    ref: "docs/research/2026-08-17-opus5-rule-shift-intake.md"
    reason: "材料の正本。本 doc §1 はこれを 2026-09-03 に取り直した差分"
  - type: refs
    ref: "docs/harness/episodes/2026-09-03-episode-307-opus5-rules-audit.md"
    reason: "作業記録。F-1 の期待値宣言と実測の順序、失敗の記録はこちら"
tags: [harness, rules-audit, opus5, lean-system-prompt, judgment-table]
---

# #307 canonical rules 14本の判定表（討議記録）

## 0. 位置と置き場

- **置き場の決定（1行）**: 判定対象は `canonical/rules/`（3ツールへ配布するハーネス全体）で engine スコープではないため、新しい蒸留木 `docs/harness/` を切った。可逆（`git mv` で戻せる）。
- この doc は「判定表とその根拠」であり、rules の書き換えはしていない。書き換えの分割方針は同日の plan にある。
- 根拠の帰属を3種で分けて書く（NK 01KYMRE1NE4HSGZR7T4XPA9JW8 の型）: **公式文** = Anthropic の公開ドキュメントの読み / **runtime 実体** = 本セッションの context・バイナリ・settings の実体 / **発火実測** = 行動が変わった・変わらなかった実例。同じ判定でも帰属が違えば強さが違う。
- 上流（研究ノート・issue コメント・統括）の断定は写していない。取り直した結果で強さを付け直した（NK 01KYMRE1NC7XX6N66RQ0MGGHF1）。

## 1. 前提の取り直し（2026-09-03・公式文）

公式3ページ（Opus 5 prompting / Opus 5 migration guide / prompting best practices）を全文取得した。08-17 ノートとの差分だけ書く（全体の要約は作業層の report にあり、committed には要点のみ）。

| 項目 | 今日の状態 | 判定表への効き |
|---|---|---|
| 自己検証・再確認の指示は削れ（削除であって書き換えでない） | 変化なし [verified] | ドリフト軸の基準 |
| 委譲は抑えろ | 骨は同じ。**「並列20体」の数値は公式例文から消え、決定的上限は環境変数（`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` / `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`・2.1.217 以降）へ** [verified] | `subagent-strategy` の処分先は「機械検査（環境変数）」 |
| Claude Code は `claude_code` プリセットのとき Opus 5 向け委譲抑制を**自前で注入する** | 新規 [verified] | `subagent-strategy` の「積極活用」は本体と正面衝突 |
| effort の出発点 | 「既定 high から始めて評価で調整・要求の高い coding / agentic は xhigh へ上げる」に言い換わり [verified] | 論点3 |
| 自己検証と外部検証の区別 | **公式文に区別なし**。「検証」は一貫して自分の出力の再確認 [verified・不在の確認] | 論点2 は当リポジトリ側の解釈に立つ |
| CLAUDE.md / rules の書き方・plan-first・質問の仕方 | 公式ページに無い [verified・不在の確認] | 「意図的上書き」の判定は公式でなく owner の運用に照らす |
| Claude Code 本体（changelog v2.1.155〜258） | 2.1.206 `/doctor` が CLAUDE.md 刈り込みを提案 / 2.1.233 Todo 系ツールを Opus 4.8 以降で無効化 / 2.1.237 組込み Concise output style / 2.1.232「custom subagent を作れ」ヒント削除 / 2.1.203 再委譲しにくく [verified] | 鮮度軸（前提消失の検出） |

## 2. 注入源の母集団（runtime 実体・自セッション = Fable 5.1 で採取。Opus 5 の本体は §11 で追補）

判定対象は rules 14本だけだが、「本体が持つか」を言うには母集団が要る。実体から数えた（索引から数えていない・NK 01KYJ76D830XME16ZFXC2XRPZZ）。逐語は置かない。

| 注入源 | 実体 | 数 | 常時か |
|---|---|---|---|
| 本体 system prompt（lean・**Fable 5.1**。主モデル Opus 5 の集合は §11） | Claude Code 2.1.258 | H1 節 8（Harness / Session-specific guidance / Memory / Environment / Scratchpad Directory / Context management / Delivering work / Writing for the user）+ 無題段落 7（身元・自律運転・状態変更前の確認・確認と報告・ほか） | 常時 |
| ツール定義（振る舞い指示を含む） | 同 | 即時 15・遅延 約 90 | 常時（遅延分は名前のみ） |
| canonical rules | `~/.claude/rules/` symlink 14 → `canonical/rules/` | 14本 / 359行 / 4,477語 | 常時 |
| CLAUDE.md（project） | repo root | 126行 | 常時 |
| 自動 memory 索引 | `MEMORY.md` | 45行（本文45件は未ロード） | 常時 |
| hooks | `settings.json` 6 event / 9 script | 規範本文の注入は **0**（命名・受領印・deny 時1行・advisory 1行のみ） | 発火時 |
| skills 索引 | canonical 28 + commands 7 + plugin 1 + 組込み 18 | 約54 の name + description | 常時（本文は呼び出し時） |
| agent 型索引 | 10 | — | 常時 |
| output style / focus | 未設定 | 0 | — |
| 委譲 brief 固定節 | `.oe/brief-*`（作業層） | 約20行 | user turn |

常時ロードの規範散文は約 530 行で、issue コメント3件目の「約500行・5,000語」と整合する。

**本体の lean 版が既に持っているもの（rules との重なりを見るときの基準）**: 結論先行・1文1意・記号を接着剤にしない・500語未満に見出しなし・依頼範囲を黙って広げも狭めもしない・可逆で依頼に沿う行動は聞かずに進む・問題を述べている段では評価を返して止まる・不可逆は確認・削除前に対象を見る・結果は忠実に報告・該当 skill があれば先に呼ぶ・commit / push は頼まれたときだけ・default branch なら先に branch・1件の検索は自分で・ファイル横断は委譲・専用ツールを shell より優先（auto mode では逆に Bash 優先）。

## 3. F-1（`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0`）— 結論: **効く**（runtime 実測）

期待値と陽性対照は測る前に episode に宣言した。観測量は headless `claude -p --max-turns 1` に自分の system prompt の H1 見出しを列挙させた集合。

| run | 条件 | 結果（H1 数 / 集合の側） | 期待との一致 |
|---|---|---|---|
| R1 | fable 既定・env なし | 7 / lean（Harness … Writing for the user） | 一致 |
| R3（陽性対照） | sonnet 既定・env なし | 9 / 長版（System / Doing tasks / Executing actions with care / Using your tools / Tone and style / …） | 一致。**R3 ≠ R1 なので計測器は弁別できている** |
| R2 | fable・`=0` | 11 / 長版（R3 の9 + Delivering work + Writing for the user） | 一致（効く側） |
| R4（補助） | sonnet・`=1` | 5 / lean（Delivering work / Writing for the user を含まない） | 一致（truthy で lean 強制） |

- 3値: **効く**。falsy 値で長版へ戻り、truthy 値で lean を強制する。バイナリの分岐の読み（P-1 前哨）と一致した。
- 帰属: runtime 実測（各条件 n=1・観測量はモデルの自己引用した見出し集合。トークン数は測っていない）。
- 副産物: 「Delivering work」「Writing for the user」の2節は fable では lean にも長版にも在り、sonnet にはどちらにも無い。**簡潔さ・結論先行の規定は Claude 5 世代向けに本体が足したもの**で、記事 F の「anti-verbosity の規定は長版側にある」は fable には当たらない。
- 限界: 環境変数は changelog に一度も書かれておらず（6,179行で0件）、公式に約束された挙動ではない。**既定を変える手段としては脆く、A/B の計測器としては使える**（論点: 本 doc §7）。

昇格の印: undocumented な環境変数は「効いた」実測があっても既定の運用に据えない。計測器としての用途と、運用の依存とを分ける

## 4. 判定表（14本 × 8軸）

### 4.1 S-2 三分類（競合 / 冗重 / ドリフト）と帰属

「本体」= §2 の lean 版 fable。○ = 当たる / △ = 部分 / − = 当たらない。

| rule | 競合 | 冗重 | ドリフト | 何と・どこが | 帰属 |
|---|---|---|---|---|---|
| behavioral | △ | ○ | − | §2 CLI Native は本体 Harness「専用ツール優先」と逆（auto mode 追記とは同じ向き）。§3 Safe Ops・§4 Minimal Scope は本体にある。§1 / §5 / §6 は本体に無い | runtime 実体 |
| careful-operations | − | ○ | − | §1 の禁止表は hook（`block-destructive.sh` 等）と auto mode の破壊的 git ブロック（2.1.183）が機械層で持つ。§2 の文脈依存確認は本体「不可逆は確認」と部分重複 | runtime 実体 + 公式文（changelog） |
| decision-pacing | ○ | ○ | − | 「問題報告≠修正決定」は本体の例外節にある。「do nothing / defer を含めよ」は本体「推奨を出せ」と逆で、さらに owner の後続 feedback（何もしないは選択肢にしない）とも逆 | runtime 実体 + 発火実測（owner feedback） |
| evidence-verification | − | − | △ | 対象は外部ソースへの照合で、公式が削れと言う「自分の出力の再確認」とは別物。ただし公式文に区別が無いので「別物」は当方の解釈。§3「consumer MUST spot-check」の語気は over-verification を誘いうる | 公式文（不在の確認）+ runtime 実体 |
| execution-policy | △ | ○ | − | 「copy-pasteable code block」は本体にある。「gate を TODO に登録」は Todo ツールが 2.1.233 で無効化され前提消失。「予期せぬ問題で止まって再計画」は本体「ブロック部分以外を完遂して明示」と向きが違う | runtime 実体 + 公式文（changelog） |
| exhaustion-before-conclusion | △ | − | △ | 本体「十分な情報があるなら動け・再導出するな」と読み手には逆向き（対象は違う: 探索の幅 対 既知事実）。「探索し尽くしたと自己宣言するな」は self-check 型の文に近い | runtime 実体 + 公式文 |
| implementation-gate | ○ | △ | − | 本体「可逆で依頼に沿う行動は聞かずに進む・『〜しますか？』は止める」と正面衝突。「findings の後に承認なしで直さない」は本体例外節と一致 | runtime 実体 |
| implementation-principles | − | − | ○ | 「終わる前に自問せよ（既存挙動を壊すか）」は公式が削れと言う self-check の形そのもの | 公式文 |
| input-style | − | − | − | 音声入力の前提は本体に無い | runtime 実体 |
| output-format | △ | △ | − | §1 結論先行・§9 の記号禁止 / 1文1意は本体 Writing for the user にある。§5 関連リンク節は本体「500語未満に見出しなし」と弱く衝突。§6 生 URL・§8 日本語語彙は本体に無い | runtime 実体 |
| reframe-on-stall | − | − | △ | 「stall を自分で判定して再構築」は自己評価に依存（rule 自身が Limits で認める） | runtime 実体 |
| skill-first-operations | − | ○ | − | 本体の Skill 定義「該当 skill があるなら先に呼ぶ」とほぼ同義 | runtime 実体 |
| subagent-strategy | ○ | △ | ○ | Principles「積極的に委譲・調査は委譲」は本体 Agent 定義「1件は自分で」と逆、公式「4.8 向けに足した『もっと委譲せよ』は外せ」に正面該当、本体が `claude_code` プリセットで委譲抑制を自前注入。Routing Gate 節は「harness が routing する」と本体を認めている | 公式文 + runtime 実体 |
| workflow-awareness | − | △ | − | 「default branch なら先に branch」は本体 Bash 定義にある。issue 起点の worktree 自律作成は本体に無い | runtime 実体 |

### 4.2 S-3 四観点（意図 / 根拠 / 鮮度 / 失効条件）

根拠は git 履歴（初出コミット・PR）と committed 文書からの被参照数で見た（帰属: runtime 実体）。

| rule | 意図（本体既定の意図的上書きか） | 根拠（記録） | 鮮度（前提は今も成立するか） | 失効条件（書いてあるか） |
|---|---|---|---|---|
| behavioral | §2 は当時の意図（gh / curl が確実）。lean・auto mode 以前 | 2026-01-15 cursor 基線・被参照21・decision 0 | §3 §4 は本体が持ち鮮度低下。§2 は本体がモードで向きを変えるので固定文は古い。§1 §5 §6 成立 | なし |
| careful-operations | 意図的（hook と対で設計） | #16・被参照11・decision 2 | §1 は hook が持つので本文再掲の鮮度は低い。§2 §3 成立 | なし（Precedence 節が hook 優先を書く） |
| decision-pacing | 旧世代（報告と同時に直しに走る）への対策 | 2026-02-25・被参照2・decision 0 | 前提は本体例外節で消失。do-nothing 条項は owner feedback で反転 | なし |
| evidence-verification | 意図的（research 成果物の契約） | #129・研究ノート（CoVe 等）・被参照14 | 成立（外部照合は世代非依存） | §4 staged application が範囲を限る。見直し条件はなし |
| execution-policy | 一般論 | 2026-02-23・被参照2 | TODO 行は前提消失。code block は本体が持つ。read-only first と義務化は成立 | なし |
| exhaustion-before-conclusion | 意図的（探索クラスタ #75-78） | #162・設計 discussion 2本・episode・被参照8 | 原則は成立。ただし本文の半分が hard gate の defer 状況と履歴の記述 | **あり**（hard 機構 #77 / #78 が landing したら minimal discipline は不要） |
| implementation-gate | **明確に意図的**（owner の plan-first・gate 3・document-format §11） | #316 ほか6コミット・decision 1・被参照13 | 成立。むしろ本体が自律運転を推す今、上書きの必要は増した | なし |
| implementation-principles | 一般論 | 2026-02-23・被参照1 | 「自問せよ」の前提（モデルが自己点検しない）は消失 | なし |
| input-style | 意図的（owner 固有の入力条件） | 2026-01-21・被参照2 | 成立 | なし（不要） |
| output-format | §5〜§9 は意図的（owner の端末・日本語・報告契約） | #324・#263 episode・memory・8コミット | §1〜§4 の一般形式は本体が持ち鮮度低下。§5〜§9 成立 | なし |
| reframe-on-stall | 意図的（探索クラスタ） | #164・decision 1・被参照8 | 原則は成立。Limits / Relationship / References が本文の半分 | **あり**（#77 hard gate landing で位置づけが変わる） |
| skill-first-operations | 当時の意図（skill が自動で呼ばれなかった） | #41・被参照5 | 前提は本体 Skill 定義で消失（Claude）。Cursor / Codex は未採取 | なし |
| subagent-strategy | 当時の意図（context を汚さない）。Routing Gate は #121 で本体に譲る形に改訂済み | #121・被参照9・memory 複数 | Principles の前提（モデルが委譲しない）は反転して消失。Custom Agents First・PR 単位・implementer-contract 要求は成立 | なし |
| workflow-awareness | 意図的（issue 起点は聞かずに branch） | #42・memory | 成立 | なし（不要） |

### 4.3 発火実績（#307 コメント3件目の9件の割当 + 本セッションの自己観測）

9件の「そのとき規範はどこに在ったか」列は、引き継ぎ書・board・NK item・シェルの基本を指し、**rule 名を1つも挙げていない**。したがって rule への割当は本 doc の解釈であり、帰属は「発火実測（割当は解釈）」。当たらないものは `unknown` にした。

| # | 踏んだ誤り | 割り当てた rule | 値 | 帰属の強さ |
|---|---|---|---|---|
| 1 | パイプ越しの `$?` | なし（シェルの基本・引き継ぎ書） | 全 rule `unknown` | — |
| 2 | `$(...)` 後の `$?` | 同上 | 同上 | — |
| 3 | `ls` 長形式で件数 | なし（board） | 同上 | — |
| 4 | `iconv` を5文字で測り「再現しない」と差し戻し | exhaustion-before-conclusion（到達可能な経路を尽くす前に結論） | `unfired` | 中（rule の文言が直接当たる） |
| 5 | `LC_ALL=C` を printf にしか | なし | 同上 | — |
| 6 | `gh issue list` 既定 `--limit 30` で総数を誤読 | exhaustion-before-conclusion（母集団を尽くしていない） | `unfired` | 弱（計測器の問題とも読める） |
| 7 | `find -name` に `so-*` を入れず「SO 未実施」と読みかけ・自分で気づいた | exhaustion-before-conclusion | `fired` | 弱（気づかせたのは NK item「0件の2原因」の可能性が高い） |
| 8 | episode 木の走査で移動先を落とし・自分で気づいた | 同上 | `fired` | 弱（同上） |
| 9 | `--title "$TMUX ..."` でローカルパスを焼いた | なし（引用符の基本。ephemeral-ID hygiene は brief 固定節で rule ではない） | 同上 | — |

本セッションの自己観測（弱い証拠・自己申告）: implementation-gate `fired`（plan-first で止まる）/ workflow-awareness `fired`（worktree 自作）/ skill-first `fired`（作成前に4 skill を読んだ。ただし本体も同じ指示を持つので帰属不能）/ subagent-strategy `fired`（P-1 を2体に委譲。公式の「本当に独立した大タスク」条件に合う範囲）/ evidence-verification `fired`（status を付けた）/ output-format §5 `fired`（関連リンク節）。**9件からは `unknown` になる rule が 11本ある。** 発火実績の軸は今日の材料では exhaustion 1本にしか刺さらない。これは軸が悪いのではなく、9件の標本が統括1セッションだからである。

### 4.4 判定（残す / 書き換える / 退役）と方向 — 前提訂正後（主モデル Opus 5・Fable 5.1 は統括用。経緯は §10.1・§11）

「本体が持つ」は Opus 5 と Fable 5.1 の2列で持つ。両列が食い違う行は rule 名の前に ★ を付けた。判定は**主モデル Opus 5 の列を基準**にし、Fable 列の差は理由に書く。語数は今日の `wc -w`。方向は ↓ = 本体が持つから消せる / ↑ = 本体が持たない・逆を言うから残す・強める。

| rule | 語数 | 本体が持つ: Opus 5 | 本体が持つ: Fable 5.1 | 判定 | 方向 | 理由（1〜2文） | 帰属 |
|---|---|---|---|---|---|---|---|
| behavioral | 142 | ○ §3（確認・忠実な報告）・§4 前半（Delivering work）/ §2 は Harness と競合 | 同じ | 書き換える | ↓§4 前半 / §3 はポインタ1行 / §2 条件化 / ↑§1 §5 §6 §4 後半 | §4 前半は両モデルの Delivering work にある。§3 は本体より厳しい意図的上書きで careful-operations が参照するのでポインタ化。§4 後半（WHAT / HOW 分離・skill 参照や一次調査を省くな）は本体に無く 2026-04 の発火実績つき | runtime 実体（両モデル）+ 発火実測（stale） |
| careful-operations | 599 | △（不可逆の確認は本体・禁止表は hook） | 同じ | 書き換える | ↓§1 の表 | 禁止表は hook が機械層で持つ。rule は Precedence + §2 + §3 の要旨に縮約し表は hook README を正本にする | runtime 実体 |
| ★ decision-pacing | 78 | **−**（「問題を述べている段では直さない」例外節が無い） | ○（例外節あり） | **書き換える（1行に縮約）** | ↑「問題報告≠修正決定・分析と行動提案を分ける」/ ↓ do-nothing 条項 | 主モデル Opus 5 の本体は問題報告時の例外を持たないので1行目は残す。「do nothing / defer を含めよ」は owner feedback と逆で削る。AGENTS.md の Decision Pacing 要約は短くする（guardrail パターンは残る） | runtime 実体（両モデル）+ 発火実測（owner feedback・2026-04 Codex 無視） |
| evidence-verification | 646 | − | − | 残す（冒頭に1行足す・§3 維持） | ↑ | 外部照合の契約は本体に無い。公式文に自己 / 外部の区別が無いので冒頭で線を引く。HG-1 裁定で §3 の MUST spot-check は維持 | 公式文 + runtime 実体 |
| ★ execution-policy | 82 | −（code block 行も本体に無い） | △（code block は Writing for the user にある） | 書き換える | TODO 行はツール名を外して実質を残す / ↑ read-only first・義務化・code block 行 | Opus 5 の本体には code block の指示が無いので削らない。TODO 行は Todo ツールが環境変数で戻せるので「消失」ではなく、gate を実装 step の間に独立項目として挟む規律だけ残す | runtime 実体（両モデル）+ 公式文（changelog） |
| exhaustion-before-conclusion | 709 | △（Context management「十分なら動け」と弱い競合・Opus の同節は同文と仮定 [unverified]） | △ | 書き換える（縮約） | ↑原則・minimal discipline / ↓履歴・References | 原則は成立。本文の半分が hard gate の defer 状況と履歴。unfired 2件は文面強化でなく機械検査へ | 公式文 + 発火実測 |
| ★ implementation-gate | 156 | **−**（自律運転の段落が無く競合しない） | 競合（自律運転「可逆なら聞かずに進む」）+ △（問題報告時の例外） | 残す | ↑ | 主モデルでは本体と独立。Fable 列では正面衝突する意図的上書きなので、優先宣言の1行は特定の本体文を名指しせず世代・モデル非依存に書く（HG-1 裁定 (1)）。2026-04 検証で3ツールとも例外条件を自己援用した stale unfired があり、例外条件の再設計を含める | runtime 実体（両モデル）+ 発火実測（stale） |
| ★ implementation-principles | 37 | ○（Corrections が「正確だった発言を、どう検証したかも含めて再監査するな」と言う） | −（公式文のみ） | 書き換える（behavioral §6 の隣へ吸収。2行目は**痕跡型に置き換えて**吸収） | ↓2行目の自問の形 / ↑1行目と痕跡型の1文 | 1行目「hacky なら根本原因」は設計方針で本体に無い。2行目「終わる前に自問せよ」は公式 Opus 5 文書が削れと言い、Opus 5 の本体 Corrections も再監査を抑える。ただし段階2 の実装SO が「代替なしに常時の責務が消える。Codex と Cursor の本体に同じ抑制が在るとは限らない」と反対し、統括がこれを受け入れた。自問ではなく「触れた既存の挙動とその確かめ方を完了報告に書く」という痕跡型の1文へ置き換える（2026-09-06） | 公式文 + runtime 実体（Opus）+ 実装SO |
| input-style | 48 | △（careful colleague・Delivering work） | 同じ | 書き換える（1行に） | ↑音声入力の前提 / ↓他2行 | 「意図優先」「本当に曖昧なときだけ聞く」は両モデルの Delivering work と同義 | runtime 実体（両モデル） |
| ★ output-format | 740 | **−**（Writing for the user が無い） | ○§1 結論先行 / △§9 記号禁止・1文1意 | **残す・強める** | ↑（全節）| 主モデル Opus 5 の本体は応答形式の規定を持たない（結論先行も記号禁止も無い）。Fable 列では §1 が重なるが主モデル基準で残す。§5 の見出し要求と Fable 本体「500語未満に見出しなし」の競合、§9 を禁止形から記述形へ書き換えるか（Fable 5.1 公式）は owner 判断点 | runtime 実体（両モデル）+ 公式文 |
| reframe-on-stall | 769 | − | − | 書き換える（縮約） | ↑原則・トリガ・reconcile / ↓Limits・Relationship・References | 原則は成立。関係と限界は discussion へ | runtime 実体 |
| skill-first-operations | 62 | ○（Skill 定義・ツール定義はモデル非依存） | 同じ | 退役 | ↓ | 本体 Skill 定義と同義。Cursor は rules 本文を配布せず Codex は AGENTS.md 要約。AGENTS.md・`check-codex-guardrails.sh`・CATALOG を同じ PR で動かす。2026-04 の NO_LOAD 2/4 は stale unfired | runtime 実体（sync script・両モデル）+ 発火実測（stale） |
| subagent-strategy | 367 | △（Agent 定義「1件は自分で」・Routing Gate は本体を認める） | 同じ | 書き換える | ↓Principles / ↑Custom Agents First・PR 単位・契約 | 「積極活用」は公式反転の正面。上限は環境変数（`CLAUDE_CODE_` prefix 付き）へ | 公式文 + runtime 実体（両モデル） |
| workflow-awareness | 42 | △（Bash 定義「default branch なら先に branch」）・競合（部分） | 同じ | 残す | ↑ | worktree 自律作成は本体に無い。「非 issue は default branch 滞在可」は Bash 定義と競合（部分）。意図的上書きとして残すか本体に合わせるかは owner 判断点 | runtime 実体（両モデル） |

集計（判定値の内訳・件数の軸）: 残す 4（implementation-gate・evidence-verification〔冒頭1行〕・output-format〔強める〕・workflow-awareness）/ 書き換える 9（behavioral・careful-operations・decision-pacing〔1行〕・execution-policy・exhaustion・implementation-principles〔吸収〕・input-style〔1行〕・reframe・subagent）/ 退役 1（skill-first-operations）。★ は5行（両列が食い違う行。うち判定値が変わったのは decision-pacing と output-format の2行・§11）。

## 5. unfired の処分（3択）

- exhaustion-before-conclusion の `unfired` 2件（#4 #6）は、文面の強化ではなく **機械検査へ移す**。具体的には「0件を結論する前に陽性対照を通す」「母集団は実体から列挙する」を hook（#24 / #309 の発火記録に接続）か NK item の観測レコードに置く。rule 本文は原則だけにする。
- 「第二者に渡す」は既に運用がある（委譲子・SO レーン・owner）。rule 側では触らない。
- 「落とす」は選ばない。原則は成立している（鮮度 ○）。

## 6. 論点4つ — 推奨と owner 判断点（HG-1 裁定値は §6.1）

| 論点 | 推奨 | 理由 | owner 判断点 |
|---|---|---|---|
| (1) 世代差を rule 本文に書くか | **世代非依存に書く**（統括推奨に同意） | 本体は版ごとに変わる（今日の changelog で 100 版分の差分が出た）。世代名を本文に焼くと失効条件が散る。代わりに各 rule に `review-when:`（見直し条件）を1行持たせ、そこに「本体 system prompt の該当節が変わったとき」を書く（shimo4228 が同じ形に到達している） | メタデータを frontmatter に持つか CATALOG.md に持つか。語数を増やす方向なので、持つなら1行に限る |
| (2) 自己検証と外部検証の線引き | **別物として扱い evidence-verification は残す**。冒頭に線を引く1行を足す | 公式の削除対象は「自分の出力の再確認」。外部ソースへの照合は対象が違う。ただし公式文に区別は無いので、これは当方の解釈と明示する | §3「consumer MUST spot-check」の語気を弱めるか（over-verification のリスクと、spot-check を落とすリスクの比較） |
| (3) effort 等セッション設定を rule で扱うか | **扱わない** | `settings.json`（`effortLevel: xhigh`）が既に持つ。公式は high 起点・xhigh は昇格。設定の話は rule の話ではない | xhigh を high に下げて比較するかは別件（本アークの対象外） |
| (4) 3ツール配布で特定モデル指針をどこまで canonical に載せるか | **canonical は世代非依存・ツール非依存の原則だけ。「Claude 本体が持つから消す」判定は Claude runtime しか採っていないので、Cursor / Codex の runtime を次アークで採るまで退役は Claude 配布だけに限る手当てを検討** | 今日の S-1 は Claude 1ツール分。Cursor / Codex の harness が同じ文を持つかは未確認 | 次アークに Cursor / Codex の runtime 採取を入れるか。入れないなら canonical から一律退役（減らす方向を優先） |

### 6.1 HG-1 の裁定（owner・2026-09-03 03:55・正本は issue #307 のコメント）

| 論点 | 裁定 |
|---|---|
| (1) 世代差の書き方 | 世代非依存。各 rule の frontmatter に見直し条件（review-when）を1行 |
| (2) 自己検証と外部検証 | evidence-verification は残す。冒頭1行で「外部ソースへの照合であり自分の出力の再確認ではない」と線を引く。§3 の MUST spot-check は維持 |
| (3) effort 等 | rule では扱わない |
| (4) 3ツール配布と退役 | skill-first-operations を canonical から退役。同じ PR で AGENTS.md の見出し・check-codex-guardrails.sh のパターン・CATALOG を更新し sync-codex を止めない |
| (5) F-1 | 既定は変えない。rules 書き換えの前後比較の物差しとしてだけ使う（版固定・snapshot を条件に） |
| (6) 3文書の着地 | docs だけを先にコミットし draft PR を1個。マージはしない。段階2 の PR-1 の土台にするかは段階2 の着手時に決める |
| output-format §5 の見出し | 見出しをやめて行頭ラベル「関連リンク:」にする（段階2 の output-format 書き換えに含める） |
| (0) SO 再走 | 再走しない（判定値の変更は2行・plan 全体は3レーン済） |

未裁定: workflow-awareness の「非 issue は default branch 滞在可」を本体に合わせるか / output-format §9 の記述形化。段階2 の該当 PR の HG で扱う。

## 7. F-1 をどう使うか（追加の判断点・HG-1 で裁定済: 既定は変えず計測の物差しにする）

- F-1 は効く。長版に戻すと「Doing tasks / Executing actions with care / Using your tools / Tone and style」の4節が増え、careful-operations・behavioral §6・skill-first の重なりはさらに増える（判定が ↓ に寄る）。
- **推奨: 既定を長版に戻すことはしない。** changelog に無い変数に運用を預けると、消えたときに rules 側の判定ごと崩れる。**A/B の計測器としては使う**（次アークで rules 書き換えの前後を lean と長版の両方で見る）。
- owner 判断点: 逃げ道として長版を採るか（今日の判定の半分が変わる）。

## 8. 語数の前後比較（目標値にしない・段階2 の実測）

前: 14本 / 359行 / 4,477語。後: 12本 / 332行 / 3,958語。**語数は 11.6% 減、本数は2本減。** 各 PR の着地時点で `wc -l -w canonical/rules/*.md` を取った（gate 4 の修正を入れたあとのブランチ先端）。

| PR | 内容 | 本数 | 行 | 語 |
|---|---|---|---|---|
| — | master（前） | 14 | 359 | 4,477 |
| #360 | subagent-strategy の書き換え | 14 | 358 | 4,481 |
| #361 | skill-first-operations の退役 | 13 | 353 | 4,419 |
| #362 | implementation-principles の畳み込み | 12 | 350 | 4,425 |
| #363 | decision-pacing の縮約 | 12 | 347 | 4,367 |
| #364 | 線引きの1行を2本へ | 12 | 350 | 4,430 |
| #365 | 探索クラスタ2本の縮約 | 12 | 300 | 3,728 |
| #366 | careful-operations を hook の正本へ | 12 | 275 | 3,714 |
| #367 | 本体と重なる指示の除去 | 12 | 272 | 3,694 |
| #368 | 関連リンクの行頭ラベル化 | 12 | 272 | 3,726 |
| #369 | 見直し条件の付与（後） | 12 | 332 | 3,958 |

**読み方の注意が3つある。**

- **増える PR が4本ある**（#360 #362 #364 #368 と #369）。削るより足す文のほうが長い場合、語数は増える。減らす向きの棚卸しでも各段が単調に減るわけではない。
- **最大の減りは1本（#365）で 717 語**。全体の減り 519 語より大きい。つまり他の PR の増分がそれを食っている。**減らす効果は「経緯と例示を rule から出す」ことにほぼ集中していた。**
- **これは効果の測定ではない。** 遵守が上がったか、崩れが減ったかは測っていない。2026-04 の検証シナリオ（`docs/issues/38`）を書き換え後に再走すれば遵守率の前後は取れるが、本アークでは実施していない（follow-up）。

参考として shimo4228 は 5,789 語から 2,463 語（57.5%）だが、著者自身が効果の証明ではないと留保している。当方の 11.6% と比べる意味は薄い。**母集団が違う**（あちらは 20 本を 14 本へ整理、こちらは既に整理済みの 14 本が対象）。

## 9. 何を読み・何を残したか（結論時の宣言）

- 読んだ: 公式3ページ全文（subagent 経由・URL と節を記録）/ changelog 100 版分の該当行 / rules 14本の本文と git 履歴 / 自セッションの context / バイナリの分岐 / F-1 実測 4 run / 記事8本 + 新規2件。
- 探索して当たらなかった: 08-17 以降の新規記事は2件のみ（約30候補を日付で除外）。公式に CLAUDE.md / rules の指針は無い。
- 未探索のまま残した: Cursor / Codex の runtime（論点4）/ Piebald-AI のトークン数 / shimo4228 の 08-27 更新の中身（Wayback 停止）/ F-1 のトークン数（見出し集合だけで判定した）/ 各 rule の「発火」を統括以外の役割で数えること。

## 10. gate 2（設計SO・3レーン）の反証と修正後の判定

弱 SO（`oe-refute --rubric exploration`）。1周目は codex / cursor が 240 秒で出力空（claim に「ファイルを開いてよい」と書いたため repo 探索で時間切れ）、claude レーンは 476 秒で `refuted`。2周目は「ファイルを開かない・400 語以内」の短縮 claim で codex / cursor を再走し、59 秒で 2 / 2 `refuted`。**3レーンとも refuted**。exploration は見落としを出させる場なので verdict 自体は想定内で、episode に宣言した期待（論点4 か 9件の帰属を突く）は3レーンすべてが当てた。指摘は自分で一次に当て直してから採否を決めた（レーンの断定を写していない）。

### 10.1 受けた指摘と修正後の判定（変更行のみ）

| rule | gate 2 前 | 修正後 | 自分で確かめた根拠 | 帰属 |
|---|---|---|---|---|
| skill-first-operations | 退役（Claude）/ 保留（Cursor・Codex） | **退役（canonical から）**。ただし `scripts/check-codex-guardrails.sh` が `AGENTS.md` に「Skill-First」見出しを必須とし `sync-codex.sh` が `set -euo pipefail` 下で呼ぶので、rule・AGENTS.md・guardrail script・CATALOG を**同じ PR**で動かす | `sync-cursor.sh` は `canonical/cursor/rules/*.mdc`（1本）しか配らず `canonical/rules` を Cursor に配布していない。Codex は AGENTS.md の見出し要約。**rule 本文を常時ロードしているのは Claude だけ**で「3ツール保留」の前提が崩れた。2026-04 の spot-check（`docs/issues/67`）に NO_LOAD 2/4 の unfired 実測（stale） | runtime 実体（sync script）+ 発火実測（stale） |
| decision-pacing | 退役 | 退役（維持）。同様に guardrail の「Decision Pacing」パターンと AGENTS.md を同 PR で更新 | 2026-04 の検証（`docs/issues/38`）で Codex が implementation-gate / decision-pacing を無視した実測（stale unfired） | 同上 |
| implementation-principles | 退役 | **書き換え（1行に縮約して behavioral §6 の隣へ吸収）**。1行目「hacky なら根本原因」は設計方針で本体に無い。2行目の self-check 型だけ削る | rule 本文の再読 | runtime 実体 |
| behavioral | §3 §4 ↓ | §3 は本体より厳しい無条件停止（本体は durably authorized の免除あり）＝意図的上書きで、careful-operations が「Concretizes §3」と参照する。**削らず careful-operations へのポインタ1行に縮約**。§4 は前半（黙って広げない）だけ本体にあり ↓、後半（WHAT / HOW 分離・skill 参照や一次調査を省くな）は本体に無く 2026-04 の観測失敗を直すために足された発火実績つきの行なので**残す ↑** | `careful-operations-rule.md:13`・`docs/issues/67/step1-spotcheck-results.md:20`・本体 Delivering work の読み直し | runtime 実体 + 発火実測（stale） |
| output-format | §1〜§4 ↓ / §5〜§9 ↑ | **§1 のみ ↓**。§2（検証結果をコマンドと出力で）§3（1コマンド / 1PR / 1変更の手順）§4（open questions）は本体に無い報告契約で ↑。§5 の見出し要求と本体「500語未満に見出しなし」の競合は未解消なので owner 判断点に上げる（行頭ラベルにするか意図的上書きとして残すか）。§9 は Fable 5.1 公式「anti-formatting 言語は削るか、いつ整形が適切かを言う規則に置き換えよ」に照らし、**禁止形から「いつ記号を使ってよいか」の記述形への書き換え候補** | 本体 Writing for the user の再読・Fable 5.1 prompting guide [verified] | runtime 実体 + 公式文 |
| workflow-awareness | 残す（冗重部分） | 残す。ただし関係は**競合（部分）**: rule は非 issue 作業に default branch 滞在を許し、本体 Bash 定義は「default branch なら先に branch」を言う。意図的上書きとして残すか本体に合わせるかは owner 判断点 | 本体 Bash ツール定義の再読 | runtime 実体 |
| input-style | 残す | **書き換え（1行に）**。「意図優先」「本当に曖昧なときだけ聞く」は本体 Delivering work と同義。owner 固有は音声入力の前提1行 | 本体 Delivering work の再読 | runtime 実体 |
| execution-policy | TODO 行 ↓（前提消失） | TODO 行は「TODO items」というツール名を外し、実質（gate を実装 step の間に独立項目として挟む）を残す。Todo ツールは `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` で戻せると changelog に明記があり「消失」は言い過ぎ。`kickoff-to-plan` が同じ規律に依存する | changelog 2.1.233 の再読・kickoff-to-plan の Gate 変換規則 | 公式文（changelog）+ runtime 実体 |
| implementation-gate | 残す・強める | 維持。2026-04 検証で3ツールとも例外条件（1ファイル数行の軽微な修正）を自己援用した実測（stale unfired ×3）があり、強める根拠が発火実測側からも出た。例外条件の再設計を書き換え内容に含める | `docs/issues/38/results/rules-verification-results.md:34,81` | 発火実測（stale） |
| 発火実績列（全体） | 9件から exhaustion のみ割当 | 9件は「計測器が汚れたまま値を読んだ」型で evidence-verification §3（最終確認はソース実体に直接）にも同程度に帰属しうる。割当は post-hoc と明記。代わりに repo 内の rule 別実測（2026-04・Opus 4.6 / Sonnet 4.6 世代・stale）を列に足す: implementation-gate unfired ×3ツール / behavioral §4 Minimal Scope fired（Claude）/ decision-pacing unfired（Codex）/ skill-first unfired（NO_LOAD 2/4） | 上記2ファイル | 発火実測（stale） |

gate 2 時点の内訳（件数の軸・**前提訂正前**。訂正後は §11.4 と §4.4 の集計行が正）: 残す 3 / 書き換える 9 / 退役 2。

### 10.2 退けた指摘（理由つき）

- 「計測のみ / 何もしない」を選択肢に足せ（cursor）: owner の gate 0 で「減らす方向」と決まっており、owner の feedback にも「何もしないは選択肢にしない」がある。ただし「4,477語が実害を出している測定が無い」は事実。語数の前後比較に加え、2026-04 の検証シナリオ（`docs/issues/38`）を書き換え後に再走して遵守率の前後を取ることを follow-up に置く。
- 「重複は冗長ではない（context 圧縮時の再提示・可搬性・意図記録）」（cursor・codex）: 一部受ける。可搬性は Codex / Cursor に rule 本文が届いていないので AGENTS.md 要約の問題であって rule 本文の問題ではない。context 圧縮時の再提示は rules が毎ターン system-reminder として再注入されるので本体と同条件。意図記録は `review-when:` メタデータ（論点1）で持つ。
- 「F-1 は undocumented なので計測器にもならない」（codex・claude）: 一部受ける。計測器として使うなら版固定（2.1.258）と長版本文の snapshot を条件にする。長版の中身は未採取（見出し n=1）は事実で、§7 の推奨はその分弱い。
- 「発火実績が 11 / 14 unknown で名目上の軸」（cursor・codex）: 受ける。stale 実測を足しても今日の材料で新しい実測がある rule は無い。軸は残すが「今日の材料では弱い」と明記する。
- 「PR-2 が理由の異なる2本を束ねる・PR-7 が dangling 参照を作る・CATALOG を PR-8 まで遅らせると中間状態が壊れる」（3レーン）: 受ける。plan を直した（PR-2 を分割・PR-7 を縮小・索引と guardrail を各 PR に含める）。

### 10.3 Fable 5.1 公式の追加確認（claude レーンの指摘・自分で取得）

統括セッションと本委譲子のモデルは Fable 5.1 で（**owner の主モデルは Opus 5**。前提訂正は §11）、公式は Opus 5 とは別に Fable 5.1 の prompting guide と migration guide を出している（`https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1`・`https://platform.claude.com/docs/en/models/fable-5-1/migration-guide`）。

- 「Fable 5 のプロンプトはそのまま効く（without changes）」[verified]
- over-verification / self-check の節は**無い**（見出し一覧と本文 grep で不在）[verified・不在の確認]。claude レーンが引いた「Verify your work however you like」は本文 grep で見つからず、未確認のまま置く
- Formatting in chat: 「以前のモデルは箇条書きと太字を過用し、多くのプロンプトが anti-formatting 規則を持つ。Fable 5.1 は逆に太字・見出し・リストを使いにくい。anti-formatting 言語は削るか、いつ整形が適切かを言う規則に置き換えよ」[verified]
- effort は既定 high から評価で調整 [verified]。scope は「依頼範囲外は直さず follow-up で報告」[verified]

**判定への効き（前提訂正後）**: self-check ドリフト（implementation-principles 2行目・exhaustion の「自己宣言するな」）の根拠は Opus 5 文書にあり、**主モデルが Opus 5 なので向きは正しい**。Fable 5.1 文書は「Fable 5 のプロンプトはそのまま効く」としか言わず、Fable 系に同じ指針が当たるかは unverified のまま follow-up に置く（統括セッション限定の考慮）。§9 の anti-formatting の件は Fable 5.1 文書の記述で、Opus 5 文書に同じ節があるかは未確認。

昇格の印: rule 本文を常時ロードしているのは Claude だけで、Cursor は rules を配布せず Codex は見出し要約を受ける。「3ツール配布」は rule 本文の話ではなく AGENTS.md 要約の話だった

昇格の印: Fable 5.1 公式は anti-formatting 規則を「いつ整形が適切か」の記述形へ置き換えよと言う。禁止形で書いた output-format §9 と careful-operations の型に世代依存の前提がある

## 11. 前提訂正後の判定（主モデルは Opus 5・変更行のみ・§10.1 と同形式）

owner の指摘（2026-09-03 03:22）で前提が訂正された。**owner の主モデルは Opus 5**で、Fable 5.1 は統括セッション（と本委譲子）のモデル。§2〜§4 の「本体が持つ」は Fable 5.1 の runtime に立っていたので、Opus 5 の runtime を同じ方法（headless `--model opus`・MODEL 行で `claude-opus-5` を確認）で採り直した。逐語は作業層（`.oe/runtime-capture-307.md` §5）に置き、ここには要旨だけ書く。

### 11.1 Opus 5 の本体で分かったこと（runtime 実体・各条件 n=1）

- lean の H1 は Harness / Session-specific guidance / Memory / Environment / Context management / Delivering work / **Corrections**。**Writing for the user が無い**（Fable 5.1 にはある）。
- **Corrections** は Opus 5 固有の節で、「不要な自己訂正を避けよ。訂正は短く。謝罪や前置きを足すな。正確だった発言を、どう検証したかも含めて再監査するな」を言う（公式 Opus 5 文書の「自己訂正を語りすぎる」への本体側の手当て）。
- Delivering work とツール定義（Skill / Agent / Bash / Read）は Fable と逐語一致。
- H1 の外の無題段落（自律運転・問題を述べている段では直さない・ターン終了前の点検・状態変更前の確認）は **Opus 5 には無い**。Fable 5.1 には既定 mode でも auto でもある。**差は permission mode ではなくモデル**で決まる（fable / opus × 既定 / auto の4条件で確認。事前の期待「auto のみ」は外れた）。
- F-1 は Opus 5 でも効く（`=0` で長版 11 節。Corrections は長版にも残る）。

### 11.2 判定値が変わった行

| rule | 前提訂正前（§10.1） | 訂正後 | 根拠 | 帰属 |
|---|---|---|---|---|
| decision-pacing | 退役 | **書き換える（1行に縮約）**: 「問題の報告は修正の決定ではない。分析と行動提案を分ける」だけ残し、do-nothing / defer 条項と残りを削る | Opus 5 の本体に「問題を述べている段では直さない」例外節が無い。退役の根拠だった「本体が持つ」は Fable 列だけで成立していた | runtime 実体（両モデル）+ 発火実測（owner feedback） |
| output-format | 書き換える（§1 ↓） | **残す・強める** | Opus 5 の本体に Writing for the user が無く、結論先行も記号禁止も本体に無い。Fable 列の §1 重なりは主モデル基準では理由にならない。§5 §9 の扱いは owner 判断点のまま | runtime 実体（両モデル） |

### 11.3 判定値は変わらず方向・根拠が変わった行

| rule | 何が変わったか |
|---|---|
| implementation-gate | Opus 5 では本体と競合しない（自律運転の段落が無い）。「強める」の中身（本体の該当文を名指しして優先宣言）は Fable 列の考慮になるので、宣言は特定の本体文を引かず世代・モデル非依存に書く（HG-1 裁定 (1) と整合） |
| execution-policy | code block 行は Opus 5 の本体に無いので削らない。書き換えは TODO 行のツール名を外すことだけ |
| implementation-principles | Opus 5 の Corrections が再監査を抑えるので、2行目の ↓ は公式文に加えて runtime 実体でも支えられる。ただし段階2 の実装SO の反対を受け、削除ではなく痕跡型への置き換えになった（§4.4 の行を参照） |

### 11.4 集計と SO の扱い

訂正後の内訳: 残す 4 / 書き換える 9 / 退役 1（§4.4 の表本体と一致）。判定値が変わった行は 2 行（decision-pacing・output-format）。追補の規則「3行以上なら claude レーン1本で gate 2 を再走・3行未満なら再走せず差分と理由を plan の SO 節に disclose」に従い、**再走しない**。数え方は「残す / 書き換える / 退役 の値が変わった行」で、implementation-gate の「強める」の有無は値の変化に数えていない。この数え方で3行と読むなら再走が要る（report に判断点として明記）。

### 11.5 この訂正で分かった自分の見落とし

runtime 採取の母集団に「どのモデルで動くセッションか」の軸が無かった。`settings.json` の `model` は採取したセッション（統括用）の値で、owner の作業セッションの値ではない。注入源の種類は実体から数えたが、**本体の中身がモデルで変わる**軸と、**実際に動いているセッションの母集団**（oe-threads で見える他セッション）を数えなかった。NK 01KYJ76D830XME16ZFXC2XRPZZ の観測は「配布先に加えてモデルの母集団も落とした」と付け直す。

昇格の印: 「本体が持つ」は Claude Code の版だけでなくモデルで決まる。棚卸しの基準線は「主モデル × 版」で宣言し、統括や委譲子のモデルと混ぜない

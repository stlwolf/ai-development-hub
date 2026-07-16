---
id: 01KXNDJTPKQ8DXKS5YB7YZKKYG
title: 4層ドキュメント文体（register）の他モデル理解度実測 — 段階1調査ノート
date: 2026-07-16
type: research
status: stable
related:
  - "#263"
  - "#256"
  - "#217"
---

# 4層ドキュメント文体（register）の他モデル理解度実測（段階1）

## Context / 目的

4層ドキュメントの規約は、フォーマット（schema）・記法（markdown）・語彙（型名）の3層が統治済みで、文体（register）だけが無規約である。現行の register は生成モデルの癖（記号圧縮 `・/〔〕/→/＝/★`・体言止めの断片文・括弧入れ子・高密度1行）が事実上の標準になったもの。canonical は codex/cursor に現に sync 配布されているため「他モデルが読めるか」は実問題。本ノートは #263 段階1として、規範を書かず（Evidence First）「現行 register は他モデルに可搬か」を実測した記録。規範化の判断（段階2）は owner が本材料を見て別途行う。

このノートの claim には検証状態を付す（`evidence-verification-rule`）: `[verified]`＝実出力（`tmp/eval-*/`）を開いて確認した事実。`[unverified-summary]`＝測定データからの一般化・方向づけ（測定した設問集合の外へ及ぶ推論）。

## 方法

- **レーン（5）**: so-compare で codex（`gpt-5.6-sol`）/ claude（既定 Opus・fresh `-p`＝対照群）/ cursor（`composer-2.5`）、arena-compare で gemini（`gemini-3.1-pro`）/ grok（`cursor-grok-4.5-high`）。arena は `cursor-agent`（Cursor CLI）をラップしており Gemini/grok も Cursor のプロキシ経由（native ではない）。
- **対象 doc（4・register の異なる代表）**: doc1＝episode（電報体 committed 代表・heavy）/ doc2＝discussion（散文寄り committed）/ doc3＝作業層 board 抜粋（最極端の圧縮）/ doc4＝document-format.md §11+§13（規範文・現役 cross-AI 読者持ち）。全て `-w` ワークスペース参照 + パス指定で投入（inline 貼付なし）。
- **プローブ（doc あたり5問・正解既知・事実照合のみ）**: 「何が決まったか」「なぜ棄却されたか」「次に何をすべきか」「参照が指すもの」「記号列の意味」等。内容プローブ＝原文＋プレーン化の両方で計測、記号プローブ＝原文のみ（プレーン化で記号が消えるため）。
- **プレーン化比較**: doc1・doc3 について内容不変・文体のみプレーン化した版を作り、内容プローブを再計測（原文との差分＝文体の寄与）。
- **採点**: 返答テキスト × 正解キーの事実照合のみ（○＝要点網羅 / △＝一部取りこぼし / ×＝誤り・欠落）。△/× に誤読の型を付与。
- **規模**: 6 doc版 × 5レーン＝30レーン結果（12ハーネス呼び出し）。全レーン exit 0・timeout なし・非空。単一実走（分散測定なし）＝方向づけであって統計的推定ではない。

## 採点マトリクス

`○`＝正答 / `△`＝部分 / `×`＝誤答・欠落 / `N`＝プレーン化で該当なし（記号プローブ）。プローブ種別: (c)＝内容 / (s)＝記号・参照。

### 原文レーン

| doc | probe（種別） | codex | claude | cursor | gemini | grok |
|-----|--------------|:-----:|:------:|:------:|:------:|:----:|
| doc1 episode | P1 決定/棄却 (c) | ○ | ○ | ○ | ○ | ○ |
| doc1 | P2 ＝/→ の意味 (s) | ○ | ○ | ○ | **×** | ○ |
| doc1 | P3 file:line参照/DJ-1 (s) | ○ | ○ | ○ | **△** | ○ |
| doc1 | P4 status/子の権限 (c) | ○ | ○ | ○ | ○ | ○ |
| doc1 | P5 実装SO 2round (c) | ○ | ○ | ○ | ○ | ○ |
| doc2 discussion | P1 §6 決定3点 (c) | ○ | ○ | ○ | ○ | ○ |
| doc2 | P2 root cause (c) | ○ | ○ | ○ | ○ | ○ |
| doc2 | P3 [verified] 語彙 (s) | ○ | ○ | ○ | ○ | ○ |
| doc2 | P4 実装可否/増分(0) (c) | ○ | ○ | ○ | ○ | ○ |
| doc2 | P5 #62 との区別 (c) | ○ | ○ | ○ | ○ | ○ |
| doc3 board | P1 #248 状態/PR/commit (c) | ○ | ○ | ○ | ○ | ○ |
| doc3 | P2 ★/〔〕 の意味 (s) | ○† | ○† | ○† | **△** | **△** |
| doc3 | P3 succession チェーン (c) | ○ | ○ | ○ | ○ | ○ |
| doc3 | P4 [[...]] の意味 (s) | ○ | ○ | ○ | ○§ | ○ |
| doc3 | P5 gotcha の挙動/回避 (c) | ○ | ○ | ○ | ○ | ○ |
| doc4 spec | P1 gate 2/5 routing (c) | ○ | ○ | ○ | ○ | ○ |
| doc4 | P2 §参照(偽前提)/1行版 (s) | **△**‡ | ○‡ | ○‡ | ○‡ | ○‡ |
| doc4 | P3 exclude 3類型/supersede (c) | ○ | ○ | ○ | ○ | ○ |
| doc4 | P4 昇格実行ゲート/理由 (c) | ○ | ○ | ○ | ○ | ○ |
| doc4 | P5 gate(0)/違い (c) | ○ | ○ | ○ | ○ | ○ |

### プレーン化レーン（内容プローブのみ）

| doc | probe | codex | claude | cursor | gemini | grok |
|-----|-------|:-----:|:------:|:------:|:------:|:----:|
| doc1-plain | P1 / P4 / P5 | ○/○/○ | ○/○/○ | ○/○/○ | ○/○/○ | ○/○/○ |
| doc3-plain | P1 / P3 / P5 | ○/○/○ | ○/○/○ | ○/○/○ | ○/○/○ | ○/○/○ |

- `†` doc3-P2 の ★ も 〔〕 も **in-doc の明示定義がない**（★ は convention・〔〕の「補足/注記」も usage からの推論）。codex/claude/cursor は usage から「〔〕＝補足」と解釈して正答、gemini/grok は「用途の明示は記載なし」と例示のみで hedge して △。**この △ は register decode の失敗でなく「in-doc 未定義の記法に対し記載なしと答える証拠規律の保守性」の差**でありうる（プロンプトが「記載なければ記載なし」と要求している）。SYM 失敗と断定できない（SO 指摘・要 caveat）。
- `‡` doc4-P2 は **false-premise probe**（設問が「§13.6 の `〔§13〕` のような」と、spec 本文に存在しない bracket 表記〔spec は bare `§N`〕を実在するかのように埋め込む）。よって測っているのは register 理解でなく **hallucination-resistance**。claude/cursor/gemini/grok は「〔§N〕＝記載なし」と正しく抵抗し、かつ 1行版を逐語で正答（○）。**codex は「〔§N〕は本文の第N節を指し…」と、doc に無い bracket 表記に意味を断定した**（1行版は正答）→ 偽前提に乗った軽度の HALLUC ゆえ △（SO 指摘で訂正・当初の「全レーン記載なし」は誤り）。
- `§` doc3-P4 gemini は「直接の定義は記載なし。ただし文脈上『詳細メモリー』」と答え、正解キーの核（memory 参照）は満たす。grok/codex（「詳細メモリーを指す」で ○）と非対称に △ とするのは採点閾値のブレ（SO 指摘）ゆえ ○ に揃えた。gemini が hedge 気味だった事実は本文に残す。

### pane ID を含む succession 応答の evidence（doc3-P3・計測 evidence 例外）

doc3-P3 の pane ID は計測 evidence の例外クラスとしてこの表内に限定し、本文の散文には撒かない（owner 指示）。全5レーンが下記を正答した:

| 要素 | 正解 | 全レーン一致 |
|------|------|:-----:|
| 現統括 | 7代目・pane `%187`・main 起点 | ○ |
| 前任 | 6代目・pane `%173`・停止済 | ○ |

## 誤読の型の分布

非 ○ セルは **5つ**（全20原文プローブ×5レーン＝100セル中。当初「4つ」はマトリクスの行数〔doc3-P2 gemini/grok を1行に併記〕とセル数の取り違え・SO 指摘で訂正）。すべて記号・参照プローブに現れ、内容プローブでは0件。ただし性質は一様でない — 下記のとおり「genuine な decode 失敗」と「in-doc 未定義記法への保守的 abstention」と「偽前提への HALLUC」が混在する。

| セル | 判定 | 型 | 内容 | 解釈 |
|------|------|----|------|------|
| doc1-P2 gemini | × | SYM | `＝`/`→` を「記載なし」とし解釈放棄（他4レーンは usage から復元） [verified] | **genuine な decode 失敗**（記号は in-doc usage から復元可能・他レーンは復元） |
| doc1-P3 gemini | △ | REF | `oe-ident:60-71` の参照先を「記載なし」（DJ-1 側は部分正答） [verified] | **genuine な参照解決失敗**（file:line） |
| doc3-P2 gemini | △ | SYM? | `〔〕` の用途を「記載なし」と hedge（例示のみ） [verified] | **保守的 abstention の可能性**（〔〕は in-doc 未定義・証拠規律との trade-off） |
| doc3-P2 grok | △ | SYM? | 同上 [verified] | 同上 |
| doc4-P2 codex | △ | HALLUC | 偽前提の `〔§N〕` に「第N節を指す」と意味を断定 [verified] | **hallucination-resistance の失敗**（register decode ではない） |

- **確実に言えるのは**: (a) gemini が doc1（電報体）で `＝`/`→` の decode と `oe-ident:60-71` の参照解決に失敗した（他レーンは成功）＝ **in-doc 復元可能な記号での genuine な register gap**。(b) codex が偽前提の記法に意味を断定した＝ hallucination-resistance の穴。
- **FRAG（断片文の述語復元失敗）・NEST（括弧入れ子のスコープ誤り）・DROP（高密度行の事実取りこぼし）・CONF（近接項目の混同）は本プローブ集合では観測されなかった** [verified（＝非○セルにこれらの型タグが付かなかった、という限定的事実）]。ただし内容プローブはこれらの型を狙った設計ではないため、**「無害と証明された」でなく「本集合では検出されなかった」**にとどまる（SO 指摘・下記 caveat）。HALLUC は codex doc4-P2 で**発生した**（当初「HALLUC 発生せず」は誤り・訂正）。

## 所見

（SO〔codex/cursor 弱SO 1周〕の反映後。verified は観測事実に限り、一般化・因果は unverified-summary に降格した。）

1. **本プローブ集合では、内容理解は全 register 型・全レーンで可搬だった**。80 の内容プローブセル（4 doc の内容プローブ + プレーン化）が全 ○ [verified＝観測]。ただし内容プローブが拾うのは決定・status・succession チェーン等の**明示事実**で、FRAG/NEST/DROP を狙った設計ではない。よって「register は内容伝達を壊さない」への一般化は本集合の射程内に限る [unverified-summary]。加えて内容の ceiling には**正解キー参照可能性の交絡**が残る（下記 caveat・codex は trace で target-only を確認したが他4レーンは未確認）。
2. **観測された register コストは狭く、in-doc 復元可能な記号の decode と file:line 参照に集中した** [verified＝観測]。gemini が電報体 doc1 で `＝/→` の decode（× SYM）と `oe-ident:60-71` の参照解決（△ REF）に失敗し、これは他4レーン（codex/claude/cursor/grok）が同じ記号を正答したことと対照的。board の `〔〕/[[]]` の gemini/grok の hedge は in-doc 未定義記法への abstention で、decode 失敗と断定できない（型分布参照）。
3. **「電報体は他モデルに不利」仮説は、記号 decode では codex/cursor に不支持・gemini に部分支持** [unverified-summary]。codex/cursor は電報体・board の記号を正答した。一方 codex は偽前提記法（doc4-P2）で意味を断定＝ hallucination-resistance に穴（register decode とは別軸）。「レーン差」は純粋なモデル差でなく **モデル + ハーネス経路の複合**（gemini/grok は arena = Cursor プロキシ経由で native と分離不能・下記 caveat）。
4. **プレーン化は内容理解を動かさなかった（ceiling effect）** [verified＝観測]。内容プローブは原文で既に全 ○ ゆえプレーン化でも全 ○・差分ゼロ。→ 内容プローブでは文体寄与を測れなかった（内容は元から可搬か、または ceiling で鈍かった）。register コストが出たのは記号プローブだが、それはプレーン化で消えるため再計測していない。**体言止め・高密度・入れ子が無害だとは本測定では示せていない**（非観測＝無害ではない・SO 指摘） [unverified-summary]。
5. **内容 vs register の分離は、まず gemini 内部で示せた**（gemini は内容プローブ全 ○・記号プローブで ×/△）[verified＝観測]。gemini 自身が内容で落ちていないため、その記号失敗は「内容の難しさ」でなく register 由来と読める。claude 対照（同一系・fresh `-p`）が同じ記号を全て正答したのは「同一系なら decode 可能」の補助証拠だが、**圧縮 register は主に Claude/Opus 生成のため claude 対照には home-advantage の交絡が残る**（SO 指摘） [unverified-summary]。

## caveat / 限界

- **【最重要・SO 検出】正解キーがレーンから参照可能だった**: 全レーンに `-w <worktree>` を渡したため、`.oe/probes-and-keys.md`（設問・正解・grounding を逐語収載）と全 eval-input が workspace 内で読める状態にあった。レーンは file を探索できるエージェントなので、原理的に正解キーを読めた。**部分的な反証**: codex の exec trace（`tmp/eval-*-so/codex-stderr.txt`）は、6 doc版すべてで codex が**対象 eval-input のみ**を開き `probes-and-keys.md` に触れていないことを示す [verified]。cursor/claude は trace 空・arena（gemini/grok）は trace 取得不可のため、**この4レーンでは leakage を排除できない** [verified＝trace 不在の事実]。さらに **gemini が記号プローブで失敗した事実自体が systematic leakage への反証**（キーを読んでいれば失敗しないはず） [unverified-summary]。それでも全 ○ の内容結果はこの交絡を負っており、**再測定では正解キーを workspace 外へ隔離するか読み取り可能 file を対象入力のみに限定する必要がある**。
- **probe-design の弱点3件（採点中・SO で検出）**: (a) doc3-P2 の `★`（in-doc 定義なし convention）と `〔〕`（用途は usage 推論）は明示定義がなく、「記載なし」も正答たりうる → 記号プローブが register decode でなく**証拠規律の保守性**を測る面がある。(b) doc4-P2 の `〔§N〕` は spec 本文が使わない表記を実在するかのように埋めた **false-premise probe** で、実質 **hallucination-resistance** を測る（codex が乗った）。(c) doc2-P3 の `[verified]` は §8 で in-doc 定義済みの evidence 語彙で、圧縮 register の proxy として弱い。**教訓: 記号プローブは in-doc で復元可能な記号に限定し、false-premise は独立軸として分けるべき**。
- **ハーネス非対称の交絡** [verified]: so-compare（codex/claude/cursor）と arena-compare（gemini/grok）は別ハーネスで、プロキシ以外にもプロンプト整形・読み取り経路・ツール戦略が異なる。「gemini 固有」でなく **gemini-through-Cursor-arena レーン固有**が安全な表現。arena は Cursor プロキシ経由（native Gemini でない）ゆえ gemini の記号放棄がモデル固有か proxy 由来かは分離不能。
- **プローブ非独立** [verified]: 同一 doc の5問を1プロンプトで一括投入したため、後の設問が前の読解を補助しうる。100セルは独立 100 観測ではない。
- **writer home-advantage** [unverified-summary]: 圧縮 register は主に Claude/Opus 生成のため、claude 対照の全正答には home-advantage が交絡する。
- **N=1・単一実走** [verified]: 各セル1プローブ・再実行なしで分散不明。方向づけであって統計的主張でない。gemini の △/× が確率揺らぎか安定傾向かは未確定。
- **ceiling は記号側にもありうる** [unverified-summary]: 全レーンが未定義記法で「記載なし」と揃うのは「誰でも読める」でなく「誰も doc 外補完しない」ceiling の可能性。記号理解の上限は未測定（plain 対照を記号プローブに用意していない）。
- **プレーン化の長さ交絡** [verified]: プレーン化は de-compression ゆえ長い（doc1-plain 17k vs 原文 9.7k 等）。内容プローブが両版 ceiling のため結論に効かなかったが、「影響なし」でなく「検出できなかった」。
- **抜粋スコープ** [verified]: doc1/doc3 は全文でなく代表抜粋（owner 承認・full board は client 識別子を含むため抜粋で回避）。全 eval-input は client 識別子スキャン CLEAN。doc2 にはプレーン化版がない（散文型の register 効果は未分離）。

## 段階2 への判断材料

データに最も忠実な形に絞った結論（SO 反映後）:

- **現プローブ集合では内容は可搬**（決定・status・チェーン等の明示事実）。**in-doc 未定義の記法**（file:line・wiki-link `[[]]`・圧縮演算子）は gemini（＋ Cursor プロキシ交絡）でリスク。**体言止め・高密度・入れ子は未検証のまま**（本集合で失敗が出なかっただけで、無害の証明ではない）。この3点に結論を絞るのが安全 [unverified-summary]。
- **規範化する / しない**: 内容可搬性は本測定では高く、規範化の緊急度は低い。効果がありそうなのは記号・参照の**軽い明示化**（記号の初出に in-doc 凡例を1行 / 参照は file:line と散文の併記）で足りる可能性 [unverified-summary]。「記号を全廃」まで踏む根拠は本測定にはない。
- **体言止め等を規範対象から外す判断は保留**: ceiling と非観測のため「効かない」と「テストが鈍い」を区別できない。除外を確定しない [unverified-summary]。
- **読者別**: (b) 他モデルのうち codex/cursor は記号 decode で現状問題なし（ただし codex に偽前提 HALLUC の別問題）、gemini は記号・参照層で要注意（proxy 交絡込み）。(c) 人間可読性（#256/#217）は本測定の対象外で別軸に残る。
- **再測定の設計改善（優先）**: (1) **正解キーを workspace 外に隔離**（本測定最大の交絡）。(2) 記号プローブは in-doc 復元可能な記号に限定し、false-premise / hallucination-resistance は独立軸に分離。(3) 各セル複数プローブ + 複数 run で分散を見る。(4) arena を native Gemini 経路でも回してプロキシ交絡を分離。(5) FRAG/NEST/DROP を直接狙う設問（否定・時系列・スコープ解決・複数候補選択）を足して圧縮 register の感度を上げる。(6) 記号プローブを「凡例つき原文 vs 凡例なし原文」で比較し明示化の効果を測る。

## evidence anchor

- 生レーン出力（gitignored・揮発）: 本 worktree `tmp/eval-{doc1,doc2,doc3,doc4,doc1-plain,doc3-plain}-{so,arena}/`。採点マトリクスが durable な転記。
- プローブ・正解キー・評価入力（frozen）: `.oe/probes-and-keys.md` / `.oe/eval-inputs/*` / `.oe/probes/prompt-*.txt`。
- Step 0 smoke（レーン生存・model 識別子確定）: `tmp/so-smoke/` / `tmp/arena-smoke/`。

---
title: "Opus 5 世代でルールの前提が変わった — lean system prompt と自作ルールの棚卸し（#307 の材料）"
date: 2026-08-17
status: research-complete
tags: [research-intake, opus5, lean-system-prompt, rule-audit, userpromptsubmit, harness-review, register]
sources:
  - https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
  - https://zenn.dev/little_hand_s/articles/72646a09f49d2a
  - https://zenn.dev/u1/articles/claude5-rules-collapse-and-fix
  - https://zenn.dev/shimo4228/articles/claude5-rules-official-shift-audit
  - https://yasunacoffee.github.io/yasuna-tech/posts/agent-rule-1hon-de-iikanji/
  - https://joecotellese.com/posts/steering-claude-code-bluf/
  - https://lucadidomenico.studio/en/blog/opus-5-verbose-system-prompt-claude-code
related_research:
  - docs/research/2026-07-27-loop-engineering-intake.md（束6・P4-1 の defer を本ノートが解消する）
  - docs/research/2026-08-13-enforcement-placement-intake.md（強制力の階段。本ノートの収束点が段1→段3の移動に当たる）
  - docs/research/2026-07-16-register-portability-eval.md（#263 文体の可搬性実測）
related_issues: [24, 263, 305, 307, 309]
next_step:
  trigger: "#307（Opus 5 世代の指針でハーネスを棚卸しする）着手時。本ノートは #307 の作業内容 1（一次情報の取得）と 2（類似の外部情報の収集）を前倒しで済ませたものなので、着手時はここから始める"
  actions:
    - "#307 の手順に S-1（runtime 層を実セッションから採取する）を最初に入れる。当環境は canonical を 3 ツールへ配布し、hooks と skills からも注入があるため、設定ファイルだけを見ると取りこぼす"
    - "#307 の判定に S-3 の 4 観点（意図・根拠・鮮度・失効条件）を使う。特に鮮度（前提となる製品挙動が今も成立するか）は lean system prompt の導入で多くのルールが失効している可能性がある"
    - "着手の最初に F-1（CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT で長版に戻せるか）を実機で確かめる。効くならルールを書き換えずに済む選択肢が 1 つ増える。changelog に記載がないため一次未確認である"
    - "棚卸しの軸として O-2（ルールの価値が上下に分岐する）を使う。自己検証を促す系は価値が下がり、応答形式を規定する系は価値が上がる。output-format-rule §9 は後者に当たる"
    - "#309（フックの発火記録）と #24 に、UserPromptSubmit での毎発話注入が 3 例で収束していることを材料として渡す。当環境は session-name.sh で経路の実体を既に持っている"
  referenced_by: "#307（棚卸しの本体・本ノートが前提知識）/ #263（文体の規範化判断）/ #24・#309（注入経路とフック）/ docs/research/2026-08-13-enforcement-placement-intake.md（階段の 3 例目・4 例目）"
---

# Opus 5 世代でルールの前提が変わった

## 概要

#307（Opus 5 世代の公式指針に照らしてハーネスを棚卸しする）の材料を 1 本にまとめたノート。#307 の作業内容のうち 1（一次情報の取得）と 2（類似の外部情報の収集）を前倒しで済ませている。

出発点は 2026-07-26 に拾った 1 本（公式プロンプトガイドの読み解き）だったが、その後に同じ主題の記事が 5 本出ており、うち 1 本は #307 の作業手順そのものを書いている。あわせて、これまで伝聞だった「本体の system prompt が削られた」という前提を公式 changelog で確認した。

検証状態を厳密に分ける（`evidence-verification-rule`）。本ノートは #307 の判断の土台になるため、公式で確認できたものと記事の主張を混ぜない。`[verified]` は一次ソース（公式 changelog / 当リポジトリの実体）を開いて確認したもの。`[unverified-summary]` は記事がそう述べていることで、URL を根拠とする。`[speculation]` は本ノートの推論。

---

## 1. 公式で確認できたこと

**lean system prompt は v2.1.154 から既定である。** 公式 changelog に次の 1 行がある。[verified] `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md`（v2.1.154 の項）

> The lean system prompt is now the default for all models except Haiku, Sonnet, and Opus 4.7 and earlier

**ここに 1 つ、記事群がずれている点がある。** 除外されるのは Haiku、Sonnet、そして Opus 4.7 以前である。つまり **Opus 4.8 はすでに lean 側に入っている。** 記事群は「Claude 5 世代の話」「Opus 5 と Fable 5 の話」として書いているが、changelog の記述に従えば Opus 4.8 から既定が切り替わっている。[verified]（changelog の文面）/ [speculation]（記事群の記述との差の解釈）

v2.1.154 は Opus 4.8 の登場と同じ版であり、同じ項に「Claude は本当に自分で決められない判断のときだけ選択肢を出すようになった」という変更も入っている。[verified] 同上

**確認できなかったもの。** `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` という環境変数は changelog に一度も現れない。[verified]（全 5,534 行を grep して不在）後述の F-1 はこの前提の上に立つので、一次未確認の扱いにする。

**数値は信用しない。** 「80% 削減」は changelog に記載がなく、2026-07-02 に Anthropic のエンジニアが AI Engineer World's Fair で述べたものとして二次的に流通している。[unverified-summary] 複数の二次記事。さらに具体的な数値は互いに整合しない。約 800 トークンから 164 トークンへという記述と、Opus 5 が約 11,000 字で Sonnet 5 が約 29,000 字という記述があり、後者は前者の数倍になる。[unverified-summary] `https://lucadidomenico.studio/en/blog/opus-5-verbose-system-prompt-claude-code` ほか。削減が起きたことは公式の文面で言えるが、規模は言えない。[speculation]

---

## 2. 記事情報（6 件）

| # | 記事 | 著者 / 公開日 | 位置づけ |
|---|---|---|---|
| A | [Opus 5では今までのプロンプトが逆効果に](https://zenn.dev/little_hand_s/articles/72646a09f49d2a) | little_hands（松岡）/ 2026-07-26 | 公式プロンプトガイドの読み解き。出発点 |
| B | [Opus5が思考が浅いように感じる問題への対策](https://zenn.dev/u1/articles/claude5-rules-collapse-and-fix) | Yuichi Uemura / 2026-07-26 | 崩れの診断と修正 3 種 |
| C | [Opus 5 世代でルールの書き方は公式に変わった — 自作ルールの棚卸し手順](https://zenn.dev/shimo4228/articles/claude5-rules-official-shift-audit) | shimo4228 / 2026-07-27 | **棚卸しの手順そのもの。#307 に直接使える** |
| D | [エージェントのルールは 1 本でいい感じ](https://yasunacoffee.github.io/yasuna-tech/posts/agent-rule-1hon-de-iikanji/) | yasuna / 2026-07-26 | 1 本化 + モデルゲート + 実績からの導出 |
| E | [Opus 5 Made Claude Code Chatty. Three Changes Reined It In.](https://joecotellese.com/posts/steering-claude-code-bluf/) | Joe Cotellese / 2026-07-31 | 冗長化への 3 つの対処。BLUF |
| F | [Opus 5 verbose in Claude Code: blame the short system prompt](https://lucadidomenico.studio/en/blog/opus-5-verbose-system-prompt-claude-code) | Luca Di Domenico / 2026-08-05 | 長版へ戻す設定。ただし推測ベース |

一次ソースは [Claude Code の公式 CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)（v2.1.154 の項）。

未読のまま残した候補が 1 件ある。[Claude Opus 5 プロンプト最適化：再確認指示の落とし穴](https://apidog.com/blog/prompting-claude-opus-5/)。A と重複する可能性が高いため優先度を下げた。[speculation]

---

## 3. 3 例が同じ手段に収束している

**B と D と E が独立に、指示を届ける層を `UserPromptSubmit` フックでの毎発話注入へ移している。**

- B: context の先頭に置く CLAUDE.md は行動から遠いので効きが薄い。フックで毎発話の直後に 1 行注入する形に変えた。[unverified-summary] `https://zenn.dev/u1/articles/claude5-rules-collapse-and-fix`
- D: `.claude/rules/` に 1 ファイルとシェルスクリプト 1 本を置き、`UserPromptSubmit` から実行する。Opus 5 のときだけ注入し、セッションとモデルの組ごとに 1 回に絞る。[unverified-summary] `https://yasunacoffee.github.io/yasuna-tech/posts/agent-rule-1hon-de-iikanji/`
- E: 毎ターン 1 行を出すフックを置く。「15 トークンで 400 トークンの規則に注意を戻す」と表現している。[unverified-summary] `https://joecotellese.com/posts/steering-claude-code-bluf/`

**これは強制力の階段の 3 例目と 4 例目である。** ガイドライン（段 1）が効かなくなったので hook（段 3）へ移す、という動きで、TalentX がコード生成コマンドの実行漏れに対して取ったのと同じ形である。[verified] `docs/research/2026-08-13-enforcement-placement-intake.md`（P1-1 / P1-2）。ドメインが違う（片方は応答の書き方、片方はコマンドの実行）のに同じ層へ移動している点が、階段という整理の裏付けになる。[speculation]

---

## 4. 棚卸しの手順（C から）

C の記事は #307 がやろうとしている作業をすでに一度回している。手順をそのまま引ける。

### S-1: runtime 層を実セッションから採取する

システムプロンプトとツールの説明を、実セッション内でモデル自身に逐語引用させる。設定ファイルだけを見ると、プラグインやハーネス本体から注入される指示を見落とすため。テーマごとに分割して引用させる。[unverified-summary] `https://zenn.dev/shimo4228/articles/claude5-rules-official-shift-audit`

**当環境ではこの手順が特に要る。** canonical を 3 ツールへ配布し、hooks と skills からも注入があるので、`canonical/` を読むだけでは実際にモデルへ届いているものと一致しない。[verified]（`scripts/sync/` の構成と `canonical/CATALOG.md` の Hooks 節）/ [speculation]（不一致の可能性）

### S-2: 3 分類に整理する

- **競合**: runtime 層と食い違う指示が同時にロードされている
- **冗重**: すでに本体にある内容を重ねて書いている
- **ドリフト**: 公式推奨から離れている

C の実施結果は競合 2 件、冗重 1 件、ドリフト 3 件だった。[unverified-summary] 同上

### S-3: 4 観点で処分を決める

残す・書き換える・退役の判定に次の 4 つを当てる。[unverified-summary] 同上

- **意図**: 本体の既定を意図的に上書きしたものか
- **根拠**: 設計記録（ADR）が残っているか
- **鮮度**: 前提となる製品挙動は現在も成立するか
- **失効条件**: 見直す条件を事前に決めてあるか

**鮮度の観点が今回いちばん効く。** lean system prompt の導入で前提が消えたルールは、書き換えではなく退役になる。C の実例では、旧世代の「計画しない癖」への対策として置いていた Plan mode 禁止ルールが、Claude 5 ではツールの説明が計画を推奨しているため前提消失で退役になっている。[unverified-summary] 同上

**もう 1 つの実例が当環境に直接刺さる。** C は「確信度 80% 以上の指摘だけ報告する」という自作ルールを、公式ガイドの「レビュープロンプトに抑制指示を書くとモデルが報告を減らす」に照らして書き換えている。抑制ではなく、全部報告させて別パスでフィルタする形へ反転させた。[unverified-summary] 同上。当環境の `diff-audit` は 2 パス制を既に持っているので方向は合っているが、同種の抑制表現が他のスキルに残っていないかは棚卸しの対象になる。[speculation]

### S-4: 結果の測り方

C は常駐している語数をファイルごとに `wc -w` で測り、棚卸し前 5,789 語・20 ファイルから、棚卸し後 2,463 語・14 ファイルへ減らした（削減率 57.5%）。[unverified-summary] 同上

**ただし著者自身が留保を付けている。** 「効果を証明するものではなく、ドリフト検出と処分手順の提示である」と明記しており、効果の定量化は未実施で、矛盾指示の解決がモデル依存である可能性も 5 コミットの自然観察のみとしている。[unverified-summary] 同上。手順は借りられるが、削減率を目標値として借りるべきではない。[speculation]

---

## 5. 修正のパターン（B・D・E から）

| # | パターン | 内容 | 出典 |
|---|---|---|---|
| F-1 | 長版のプロンプトへ戻す | `~/.claude/settings.json` の `env` に `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` を `"0"` で置くと長版が強制され、anti-verbosity のルールが有効になる。anti-verbosity のルールはほぼ長版側にある | [unverified-summary] F。**changelog に記載がなく、記事自身も推測ベースで著者の検証結果を載せていない** |
| F-2 | 本体の原文を名指しして優先を宣言する | 一般論として書くのではなく、「この指示は本体の該当文より優先する」と本体の文を引いて書く | [unverified-summary] B |
| F-3 | 禁止形を望ましい行動の記述に変える | 「テスト未完了で commit を提案するな」を「commit を提案するときは、その成果物を使う人の操作手順で動かした結果を本文に書く」へ | [unverified-summary] B |
| F-4 | 届く層を変える | context 先頭の常駐ファイルから、`UserPromptSubmit` での毎発話注入へ | [unverified-summary] B・D・E |
| F-5 | モデルでゲートする | 対象モデルのときだけ注入する。セッションとモデルの組ごとに 1 回に絞る | [unverified-summary] D |
| F-6 | 実績から導出する | 規範を書き下ろすのではなく、セッションログから実際に訂正された箇所を集計してルールにする（D は約 800MB のログから 6 パターンを抽出） | [unverified-summary] D |
| F-7 | 外から見える痕跡が残る形で書く | 守ったかどうかが外観で判定できる形にする。内面的な指示を避ける | [unverified-summary] D |
| F-8 | 注入の有無を観測できるようにする | 状態ファイルを置いて、注入されたかどうかを後から確認できるようにする | [unverified-summary] D |
| F-9 | 競合する別ルールセットを止める | `/focus` を無効化した。フォーカスモードは表示設定だけでなく、system prompt に競合する別のルールセットを足していた（実測） | [unverified-summary] E |
| F-10 | 圧縮テストを持つ | 「別の会話でも変わらずに使える文は削除する」というテストでトーン節を絞る | [unverified-summary] E |

**F-6 と F-7 が当環境の持論への回答になっている。** 「ルールは観測性とフィードバック性が低い」という判断をこちらは持っている。[verified]（セッション memory `feedback_commit_philosophy` に記録）D はその弱点に 2 方向から手を入れている。実績から導出することで根拠を観測に置き、痕跡が残る形で書くことで遵守の判定を外観に出している。[speculation]

---

## 6. 当環境への当たり方

### O-1: #307 の前提が 1 つ増える

これまで #307 は「Opus 5 向けに反転した指針で自作ルールを見直す」という枠だった。lean system prompt によって本体から応答の書き方の規定が減ったのであれば、**本体が持たなくなった規定をこちらが持つべきか**という問いが加わる。棚卸しの範囲が「直す」から「引き取るかどうか」へ広がる。[speculation]

B が報告している崩れの症状は、見出しも区分もないフラットな長文になる、複数案に評価軸が付かない、発話に返答せずツール実行に入る、の 3 つである。[unverified-summary] B。当環境の `output-format-rule` は結論を先に置き、根拠と手順を続け、リンク節を要求する構成で、まさにこの 3 症状に対応する規定を持っている。[verified] `canonical/rules/output-format-rule.md`

### O-2: ルールの価値が上下に分岐する

公式ガイドは自己検証を促す指示の削除を勧めている。[verified] Anthropic 公式の移行ガイド（`claude-api` skill 同梱の `shared/model-migration.md`、Migrating to Claude Opus 5 節）。一方で応答形式の規定は本体から減ったので、こちら側で持つ価値が上がる。

つまり棚卸しは一律の削減ではなく、2 方向の判定になる。

- **価値が下がる**: 自己検証を促す指示、モデルが既にやることの再指示
- **価値が上がる**: 応答形式の規定、operator 向けの文体（`output-format-rule` §9）

セッション memory には「Opus 5 は自己検証が強く『自分で検証せよ』系ルールの情報価値が落ちうる。痕跡を残す指示は別物で倒れない」という観察が残っている。[verified]（memory `project_ai_readable_doc_register_axis`）本ノートの分岐はこの観察と整合し、さらに「応答形式は上がる」を足す。[speculation]

### O-3: 注入経路の実体は既にある

`session-name.sh` が `UserPromptSubmit` に配線済みである。[verified] `canonical/CATALOG.md` の Hooks 節（セッション命名は Claude Code の UserPromptSubmit）。F-4 を採るとしても、新しい仕組みを作る話ではなく、既にある経路に何を乗せるかの話になる。[speculation]

### O-4: 棚卸しの手順を借りられる

S-1 から S-4 をそのまま #307 の手順に使える。特に S-1（runtime 層を実セッションから採取）は、3 ツール配布と hooks・skills からの注入がある当環境では省略できない。[speculation]

### O-5: 逃げ道が 1 つある（未検証）

F-1 が効くなら、ルールを書き換えずに長版へ戻すという選択肢がある。ただし changelog に記載がなく、出典の記事も推測ベースである。#307 の着手時に実機で確かめる価値がある。効かない場合でも、確かめたこと自体が棚卸しの前提を固める。[speculation]

---

## 7. 資産マッピング結果

### トラック A: 既存資産への接続

| パターン | 接続先 | 接続の性質 | ギャップ / 新規知見 |
|---------|--------|-----------|-----------------|
| 公式 changelog の確認（1 節） | #307 | 補強 | 伝聞だった前提が一次で確定する。除外対象は Opus 4.7 以前で、4.8 は既に lean 側 |
| S-1 から S-4 | #307 | 拡張 | 棚卸しの手順と判定枠。ゼロから設計する必要がなくなる |
| O-2（価値の上下分岐） | #307、#263 | 拡張 | 一律削減ではなく 2 方向の判定になる。#263 の文体の規範化判断にも効く |
| F-4（届く層の変更） | #24、#309、`docs/research/2026-08-13-enforcement-placement-intake.md` | 補強 | 階段の 3 例目・4 例目。ドメインが違うのに同じ層へ移動している |
| F-6 / F-7 | knowledge store、`feedback_commit_philosophy` の持論 | 拡張 | ルールの観測性の低さに対する 2 方向の手当て |
| F-8 | #309 | 補強 | 注入の有無を後から言えるようにする。発火記録と同じ動機 |
| F-9 | #307 | 拡張 | 競合する別ルールセットが表示設定の裏に隠れている可能性。当環境では output style や plugin が該当しうる |
| A の P4-1（世代間の反転） | `docs/research/2026-07-27-loop-engineering-intake.md` | 修正 | あのノートの `defer` は「公式ガイドの一次確認が前提」だった。本ノートで解消する |

### トラック B: 新規導入候補

| パターン | 既存対応物 | 導入形態 | 実現可能性メモ |
|---------|-----------|---------|-------------|
| モデルでゲートした注入（F-5） | なし | フックの拡張 | `session-name.sh` と同じ `UserPromptSubmit` に乗る。モデル名の取得可否は #327 と同じ問題に当たる |
| 実績からのルール導出（F-6） | なし（規範は書き下ろし） | 実験 | セッションログから訂正箇所を集計する。当環境のログ量と保存期間の確認が前提 |
| 常駐語数の計測（S-4） | なし | 棚卸しの副産物 | `wc -w` で測れる。目標値としてではなく、前後の比較として |

---

## 8. アクション判定

| パターン | 種別 | 理由 |
|---------|------|------|
| 1 節（公式の確認） | `enrich-existing` | #307 のコメントに前提として渡す |
| S-1 から S-4 | `enrich-existing` | #307 の作業手順に組み込む |
| O-2 | `enrich-existing` | #307 の判定軸として渡す。#263 にも関わる |
| O-5 / F-1 | `defer` | 実機確認が前提。#307 の着手時に最初に確かめる |
| F-4 / F-8 | `archive-note` | #24 と #309 の設計時に引く。階段のノートからも参照される |
| F-2 / F-3 / F-9 / F-10 | `archive-note` | 棚卸しで書き換えが必要になった箇所の手法として引く |
| F-5 / F-6 / F-7 | `archive-note` | トラック B の候補として記録。単独では起票しない |
| A の P4-1 の defer 解消 | `enrich-existing` | ループ軸ノートの判定を更新する（本ノートへのポインタで足りる） |

起票候補はない。既存 Issue へのコメント候補は #307 が本命で、#24 と #309 と #263 が従。`defer` は F-1 の実機確認 1 件。

---

## 9. 原文を読む価値

| 記事 | 推奨 | 理由 |
|---|---|---|
| [C. shimo4228 の棚卸し手順](https://zenn.dev/shimo4228/articles/claude5-rules-official-shift-audit) | 原文推奨 | 3 ステップと 4 観点の判定枠、競合と幽霊設定の実例が #307 の手順に直接なる |
| [B. Uemura の診断と修正](https://zenn.dev/u1/articles/claude5-rules-collapse-and-fix) | 原文推奨 | 崩れの症状 3 つと修正 3 種の before / after。headless で各モデルに自分の prompt を引用させた検証方法も含む |
| [D. yasuna の 1 本化](https://yasunacoffee.github.io/yasuna-tech/posts/agent-rule-1hon-de-iikanji/) | 中間 | 実績からの導出と痕跡の残る書き方が要点。本ノートに転記済み。実装の細部が必要になったら読む |
| [E. Cotellese の 3 変更](https://joecotellese.com/posts/steering-claude-code-bluf/) | 中間 | `/focus` が競合ルールセットを足していたという発見だけ原文で確認する価値がある |
| [F. Di Domenico の長版復帰](https://lucadidomenico.studio/en/blog/opus-5-verbose-system-prompt-claude-code) | 要点で足りる | 推測ベースで検証結果がない。設定の書式だけ取り、効果は自分で確かめる |
| [A. little_hands の読み解き](https://zenn.dev/little_hand_s/articles/72646a09f49d2a) | 記事より原典 | 公式ガイドを直接読むほうが確度が高い。`claude-api` skill 同梱の移行ガイドで代替できる |

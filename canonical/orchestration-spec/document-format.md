---
id: "01KNCK58PTF85AVQD4M9BFYV99"
title: "ドキュメントフロー定義 — 蒸留5段・作業層・遷移/ゲート/ライフサイクル"
date: 2026-04-05                # 作成日（v2 改訂は 2026-07-13・#249）
type: decision
status: stable               # v2（#249）で draft→stable 昇格（G6）
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/15"
    reason: "Issue #15: Spec Card フォーマット定義（C-14）"
  - type: parent_epic
    ref: "https://github.com/stlwolf/ai-development-hub/issues/10"
    reason: "Epic #10 Tier 2"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md"
    reason: "v2 改訂の設計ブリーフ（DJ-2/DJ-5〜11）。2層構造の公認・型名分離・昇格義務・遷移/ゲート/ライフサイクル規範の出所"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/249"
    reason: "v2 改訂タスク（作業層公認・委譲文書の型名分離・昇格義務の規約化・draft→stable）"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "§5 MVP 構成（エンベロープ・パーサー・ゲート）、§6 蒸留パイプライン"
  - type: design_context
    ref: "projects/orchestration-research/synthesis/context-foundation.md"
    reason: "§4 コンテキスト種類の再設計、§5 Q1 保存フォーマットの暫定判断"
  - type: source_material
    ref: "ideas/20260221/document-format-design-principles.md"
    reason: "write:read 比率、フォーマット目的分類、ハイブリッド構成の原則"
  - type: source_material
    ref: "https://github.com/yoshiakist/specre"
    reason: "ULID・status enum・仕様カードの参考"
  - type: integration_target
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "#19 MVP 4-1 envelope / 4-2 output parse / 4-3 validation gate の入力契約"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/185"
    reason: "raw log レイヤーの位置づけ・ライフサイクルの機械強制（規範と機構の分離）"
tags: [spec-card, format, process, doc-flow, working-layer, promotion, ulid, epic-10, tier-2]
---

# ドキュメントフロー定義 — 蒸留5段・作業層・遷移/ゲート/ライフサイクル

## 1. 目的とスコープ

AI 駆動開発のドキュメントフロー全体を定義する。**format（各文書のフォーマット）と process（層・遷移・ゲート・ライフサイクル・昇格）を1本に統合**する（層定義と遷移規則は密結合であり spec の本数を増やさない）。

- **format 面**: 蒸留パイプライン（Discussion → KickOff → Plan → Episode → Decision）の各段階で生成される文書のフォーマットを統一する。
  - [#19 MVP](https://github.com/stlwolf/ai-development-hub/issues/19) の 4-1（エンベロープ）/ 4-2（成果物パース）/ 4-3（検証ゲート）が消費する入力契約
  - `frontmatter 索引 + rg` による検索戦略（context-foundation.md §5 Q2 暫定判断）の実現基盤
  - 文書間の参照追跡を ULID で機械的に行えるようにする
- **process 面**: どのタスクがどの層から入り（§10）・どのゲートを通り（§11）・各文書がどう生き死にし（§12）・作業層の設計級コンテンツをどう昇格するか（§13）・方向転換をどう記録するか（§14）を規定する。

このフローは実運用で **committed 蒸留層**と **machine-local 作業層**の2層に自然分化した（棚卸し 2026-07-12・DJ-2）。v2 は両層を正式構造として定義する（§2）。

## 2. 2層構造（+ raw log 層）

実運用は下記の2層 + raw log 層に分化している。どれが git 管理でどれが gitignored かを最初に確定させる。committed 側には、蒸留5段とは別種の **committed 状態 store 層**（negative knowledge store・§2.5・#272）も加わる。これは「文書」ではなく状態の保存場所で、§4〜§9 の蒸留 format 機構は適用しない（型定義は §3.4）。

### 2.1 committed 蒸留層（正本・git 管理）

discussion → kickoff → plan → episode → decision の**蒸留5段**。すべて git commit し、frontmatter 必須5項（id/title/date/type/status）+ ULID + 命名規約 + status enum を持つ（§3〜§9 の format 機構はこの層に適用）。蒸留の正本であり、後続タスク・別エージェント・人間が参照する信頼できる資産。

### 2.2 machine-local 作業層（`.oe/`・gitignored・使い捨て）

統括・委譲・監査の作業を回すための**使い捨て文書**。実運用で自然発生した合理的進化であり欠陥ではない（棚卸し §5）。特性:

- **gitignored**（本リポジトリでは `.oe/` を `.gitignore` 済み）。
- **frontmatter は最小または不要**（走査時 36本中 frontmatter 付きは 3本＝規律外だが正常）。
- **machine-local な情報を含みうる**（pane 番号・絶対パス・稼働中セッション固有値）。全 commit はノイズと手間。
- **消えてよい**（worktree 掃除で失われても原則問題ない）。
- **ただし設計級コンテンツが生まれたら §13 昇格義務が発火**する（唯一の実害＝滞留を塞ぐ）。

### 2.3 raw log 層（verbatim・別レイヤー）

エージェント往復の verbatim ログ。curated な蒸留5段とは**別レイヤー**として扱う（#185 の方針と整合）。gitignored 運用（projects 側の `docs/raw-logs/`）が既にあり、committed 実体は rally-log 1本のみが例外。curated 文書へ蒸留する材料であって、それ自体は正本ではない。

### 2.4 一枚絵

```text
committed 蒸留層（git 管理・正本）
    discussion → kickoff(opt) → plan → episode → decision
                        ↑ 昇格（§13・設計級 + durable な証拠/知見）
committed 状態 store 層（git 管理・§2.5・#272）
    <蒸留木>/knowledge/items/<ULID>.md : negative knowledge の型付き item（収穫元 episode と同じ木・文書でなく状態 store・型定義 §3.4）
machine-local 作業層（gitignored・使い捨て）
    .oe/  : brief / report / claim / handoff / board / so-prompt / issue下書き / 作業層plan / 監査ワークベンチ / proposal
    tmp/  : SO・探索の生出力（so-*/ ・oe-refute の output_dir ・dj-N-tree ・hypothesis-NNN 等・さらに揮発的）
raw log 層（gitignored・verbatim・別レイヤー #185）
    docs/raw-logs/
```

`tmp/` は作業層のさらに揮発的な下位区画（SO・探索・監査の生出力）。原則使い捨てだが、確定前の設計級証跡（`predecision-exploration` の `tmp/dj-N-tree.md` 等）が生じたら §13 昇格の対象になりうる（証跡は episode/decision へ蒸留）。

### 2.5 committed 状態 store 層（negative knowledge store・#272）

蒸留5段とは別種の committed 層。negative knowledge ループ（設計正本（hub リポジトリ内）`projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md`）の端で使われる**状態の保存場所**であり、蒸留の成果「文書」ではない。段5 が `observations` を追記し段6 が `status` を書き換える、状態が変わり続ける永続化場所。committed にするのは、状態変更のたびに保存 HG（PR レビュー/owner マージ）を通し、チーム共有し、git で戻せるため。

- 実体: 収穫元 episode が属する蒸留木の `knowledge/items/<ULID>.md`（1 item = 1 ファイル）。置き場規則（関係で解く）・型定義・スキーマ・命名（ULID ファイル名）・検証はすべて §3.4。dogfood の具体パスは各 store の README。
- **蒸留 format 機構（§4〜§9・§15）は適用しない**（§3.4 の carve-out）。#19 検証ゲートの閉じた 5 型 enum（§3.1）にも加えない。
- 昇格の第3経路: closure 時に収穫される negative knowledge の着地先（§13.3）。

## 3. 文書型カタログ

### 3.1 committed 蒸留5段（閉じた enum）

[document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) の write:read 比率に基づき、フォーマット深度に差をつける。この5型は #19 検証ゲートが `type` enum として検証する**閉じた集合**。

| 段階 | type 値 | write:read | フォーマット深度 | 目的 |
|------|---------|-----------|----------------|------|
| Discussion | `discussion` | 低（書く≒読む） | 最小: frontmatter のみ | 探索的。構造化されていない |
| KickOff | `kickoff` | 中〜高 | 重い: frontmatter + セクションテンプレート | スコープ確定、方針の言語化。**オプション層**（§8・§10・DJ-7） |
| Plan | `plan` | 中 | 重い: frontmatter + セクションテンプレート | 実行可能な粒度まで分解。**実装系で必須**（§10） |
| Episode | `episode` | 中（読む方が多い） | 中間: frontmatter + 性質ガイド | 実行記録。本文はフリーフォーム |
| Decision/ADR | `decision` | 高（読むが圧倒的に多い） | 重い: frontmatter + セクションテンプレート | 蒸留の最終成果 |

### 3.2 作業層の型集合（開いた集合）

作業層は committed 5段のような閉じた enum ではなく、**必要に応じて型が増える開いた集合**。規律の本体は型名ではなく次の**不変条件**である:

- machine-local（pane 番号・絶対パス等を含みうる）+ gitignored + 消えてよい + **設計級が生まれたら昇格**（§13）。

したがって「網羅」はこの不変条件が担い、下表の型集合は 2026-07-12 走査で観測された実例（illustrative・閉じた列挙ではない）:

| 型 | 役割 | 備考 |
|----|------|------|
| `brief` | 統括（親）→ 子への scoped タスク指示書 | 固定節（plan-first / episode 義務 / 昇格規則 / 参照ポインタ）を持つ。**旧称 kickoff**（§3.3 移行注記）。フロー層 kickoff（§8・committed）とは別物 |
| `report` | 子 → 親の報告・調査結果 | SOV 旧規約（DOCUMENT_CONVENTION v0）の `report` 型を概念的に包摂（統一は別 issue・§16） |
| `claim` | 反証SO（`oe-refute`）へ渡す主張 doc | predecision-exploration の確定前証跡にも使う |
| `handoff` | セッション間の引き継ぎ | 引き継ぎ完了後は消えてよい |
| `board` | 統括の作業盤 | succession board（統括継承）等 |
| `so-prompt` | SO 投入プロンプトの下書き | — |
| `issue下書き` | `gh issue create` 前の草稿 | commit された issue が正本になれば消えてよい |
| `作業層plan` | 委譲子の作業計画 | 本改訂の `.oe/plan-249-v2.md` が実例 |
| `監査ワークベンチ` | 分析・監査の中間生成物 | — |
| `proposal` | 設計級の探索文書 | **昇格対象**（§13・#238/#250 が初回実地例） |

frontmatter は不要または最小でよい。設計級コンテンツ（proposal 等）は §13 で committed へ昇格する。

### 3.3 型名分離と移行（brief）

N1（棚卸し §4）で確認した「kickoff」の名前被り — (a) 蒸留フローの kickoff 層（設計文書・committed）と (b) 委譲用の指示書（子への引き渡し・`.oe/`）が別物で同名を共有していた — を、**委譲文書の型名を `brief` に確定**して解消する（DJ-2/DJ-7・owner 決定 2026-07-13）。

- フロー層 kickoff（§8 テンプレ・committed・`plan-to-kickoff` 変換の出力）は**存続**する（層の廃止なし）。作業層の `brief` とは別物。
- 現行の `.oe/kickoff-*.md`（旧称・委譲文書）は `.oe/brief-*.md` へ移行する。作業層は gitignored・使い捨てゆえ**一括改名は不要** — 新規 doc から `brief` を使い、旧 doc は自然に消える。
- `oe-delegate` / `oe-send` の `--kickoff` flag のリネーム/alias は engine コード変更であり**本 spec の scope 外**。flag 整合は follow-up issue（engine 側）で扱う（§16）。

### 3.4 型付き knowledge 層（状態 store・#272）

`knowledge` は negative knowledge store の item 型。**蒸留5段の閉じた enum（§3.1）には加えない**独立の状態 store item 型であり、#19 検証ゲート（§15）の対象でもない。検証は専用の standalone コマンド `validate-knowledge`（`~/bin` に配布される・markdown + 型付き frontmatter を yq/jq で検査・advisory・exit 0/1/2）が担う。

- **文書ではなく状態 store**（§2.5）。段5 が `observations` を追記し段6 が `status` を書き換える。
- **format 機構の carve-out**: §4〜§9（共通 frontmatter 必須5項・§6 status enum・§9 命名規約 等）と §15（#19 MVP）は**蒸留5段のみ**を対象とし、`knowledge` item には適用しない。したがって `knowledge` は `title` を持たず、§6 の `draft/in-development/stable/deprecated` ではなく独自の status enum を使い、§9 の `YYYY-MM-DD-{type}-{topic}.md` ではなく ULID ファイル名を使う（下記）。
- **命名（§9 からの意図的逸脱）**: ファイル名 = `<ULID>.md`（`id` と一致）。理由は並行収穫（複数 worktree / 並列子が同時に item を書く）の衝突回避（設計正本 §6.15）。人間ナビゲート対象でなく機械管理の store item なので、§9 の人間可読ファイル名規約は適用しない。検証スクリプトが `basename == <id>.md` を機械で担保する。

frontmatter スキーマ（必須9項 + 任意1項）:

| フィールド | 必須 | 型 | enum / 形式 | 意味 |
|-----------|------|-----|------------|------|
| `id` | 必須 | string | ULID（26字・Crockford Base32） | 一意識別子・ファイル名 = `<id>.md` |
| `type` | 必須 | string | `knowledge` 固定 | 型判別 |
| `status` | 必須 | string | `active` \| `disabled` \| `superseded` \| `retired` | 段6 制御の語彙（§6 の蒸留 status enum とは別） |
| `date` | 必須 | string | `YYYY-MM-DD` | **収穫日・不変**（段5/6 の状態更新でも変えない） |
| `trigger` | 必須 | string | 自由文 | 適用条件の仮説 |
| `prediction` | 必須 | string | 自由文 | 効くはずの状況と期待効果（段5 の照合先） |
| `source` | 必須 | map | `source.ref`（汎用参照） | 出典。`ref` は committed path か URL。`.oe/`/`tmp/` 揮発層・絶対パスは不可（§13.4 と同型） |
| `landing` | 必須 | string | `nl` \| `guard-candidate` | 着地先の記録のみ（設計正本 §6.9） |
| `observations` | 必須 | list | 要素 = `{date, ref, state, note?}`（下の「observations 要素スキーマ」） | 段5 の観測台帳（append-only・収穫時は `[]`） |
| `exclusions` | 任意 | list | 文字列の配列 | 効かない状況 |

本文 prose = 教訓（自己評価文の領域・空白トリム後に可視文字 ≥1）。エンベロープには文書体系に依存しない語彙のみを置く（出典は `source.ref`。「episode の」等の依存語彙を型に入れない）。

#### observations 要素スキーマ（段5 の観測記録）

注入された knowledge の帰結を記録する台帳。**書き手は、注入を受けた子が自分の closure 時**に、work と同じブランチへコミットする（手順は `episode-retrospective` の観測書き戻し Step）。要素は次の4フィールドで、**これ以外のキーは拒否**する（書き手の身元フィールドは持たない — `ref` の先が語る）。

| フィールド | 必須 | 型 | 形式 | 意味 |
|-----------|------|-----|------|------|
| `date` | 必須 | string | `YYYY-MM-DD`（暦として妥当） | 観測日。一度書いたら変えない |
| `ref` | 必須 | string | **許可する3形だけ**（下記 allow-list）。既定は issue 番号（closure は PR 作成前なので PR 番号が未確定なことがある） | どの作業での観測か。path は書かない（作業単位の参照であって場所の参照ではない） |
| `state` | 必須 | string | 下の enum 7値 | 帰結 |
| `note` | 任意 | string | 1行（LF / CR とも不可）・空でない | 短い補足。長い証拠は `ref` の先に置く。**書かないならキーを省く**（`note: null` / 空文字 / 空白のみ / 改行入りは検証で弾く） |

`ref` の形（**closed allow-list**）: 前後の空白を落としたうえで、次の3形の**いずれかに合致するものだけ**を許可する。合致しないものはすべて検証で弾く。

| 許可する形 | 例 | 用途 |
|-----------|----|------|
| `#<数字>` | `#274` | 同じ repo の issue / PR |
| `<owner>/<repo>#<数字>` | `owner/repo#274` | 別 repo の issue / PR（スラッシュは1つ・各セグメントは英数字始まり） |
| `<scheme>://<空白を含まない1文字以上>` | `https://github.com/org/repo/pull/282` | URL |

- **禁止形を数え上げるのではなく、許可形を列挙する**（deny-list ではなく allow-list）。未知の形は既定で弾かれるので、検査の漏れが「通ってしまう」方向に出ない。
- 引き換えに、**自由文の `ref`（`PR #274 の再現手順は …`）と repo 相対 path（`docs/…/x.md`）は弾かれる**。`observations.ref` は作業単位の参照であって場所の参照ではない。committed path を許すのは `source`（収穫元の出典）の側の規則で、そちらとは別である。
- 実装では行頭行末ではなく**文字列全体のアンカー**で判定する（改行を含む値の先頭行だけが合致する抜け道を塞ぐ）。
- 残る曖昧さ（機構の限界）: `tmp/scratch.md#2` のような文字列は「repo 名が `scratch.md` の cross-repo 参照」と**同形**なので通る。GitHub の repo 名はドットを含めるため、形だけでは意味のある参照と区別できない。緩和はレビューが担う。

`state` の enum と、同時に当てはまるときの**優先順位**（1 item = 1 レコードなので最も強いものを1つ選ぶ）:

1. `harmful` — 従ったことで害が出た
2. `contradicted` — 教訓に反する事実が出た
3. `externally_verified` — 外部の判定（テスト・レビュー・CI）が**予測の効果**を確認した。単なるビルド成功はこれに当たらない
4. `followed` — 教訓どおりに判断や手順を実際に変えた（変えた証拠を示せるときだけ。示せないなら `outcome_unknown`）
5. `injected_not_used` — 適用機会はあったが使わなかった
6. `no_opportunity` — trigger の状況に一度も当たらなかった（「再発しなかった」を効果として数えない側）
7. `outcome_unknown` — 判定できない

台帳の規約（**機械検査されないもの**を含む）:

- **append-only**: 過去のレコードは書き換えない。退役後も履歴として残す。明示の version フィールドは持たず、**git 履歴が版台帳**（改訂も観測も commit なので時系列で復元できる）。
- **配列の順序に意味を持たせない**: 末尾に足すだけで、時系列昇順は強制しない（並行ブランチの merge で古いブランチの正当な追記が後ろに来る）。順序が必要なら読む側で並べ替える。
- 検証コマンド `validate-knowledge` は各要素の**形**（必須3・enum・暦妥当性・`ref` の hygiene・`note` の1行・未知キー）を検査する。**append-only と順序は検査しない**（規約であって機械保証ではない）。
- **省略と自己申告は機械では検知できない**: 「注入された全 item に1レコード」の完全性、`followed` の妥当性は、レビュー（親の fact-check / owner のマージ）が唯一の歯である。v0 の観測は意思決定に使わない placeholder として扱う。

集計と制御候補の提示（段6 の機械側）:

- 列挙コマンド `knowledge-list` が state ごとの件数を集計し、**`status: active` かつ `harmful` / `contradicted` の観測を持つ item に制御候補フラグ**を立てる。要素スキーマを満たさないレコードは集計の `invalid` に数え、**そこから候補は立てない**。
- フラグは「adverse な観測が過去に一度でもあった印」であって未処理キューではない。誤観測を訂正する語彙は enum に無いため、**一度立った候補は消えない**（v0 の既知の制約。候補の総数を運用指標に使わない）。
- **二段チェック**: 列挙（`knowledge-list --strict`）は「item を列挙できたか」の完全性しか見ない。**台帳のスキーマ完全性は、列挙のあとに `validate-knowledge` を回して見る**（列挙 verb は validator ではない）。列挙コマンドの `--json` は additive 拡張とし、`schema_version` は breaking change のときだけ上げる。

#### status 遷移規則（段6 の制御）

- **いつ**: 制御候補フラグが立った item を `disabled` の候補として検討する。件数の閾値は置かず、**機械は提示までで status を書き換えない**。
- **誰が**: 提案は誰でもできる（子・統括・owner）。採否は**マージの人間ゲート**。curation 専用の承認機構は作らない。
- **どう**: frontmatter の `status` を編集した**通常の PR**。`observations` は書き換えない（append-only）。`date`（収穫日）も変えない。
- **遷移先**: `active` → `disabled`（効かない・害があった）/ `superseded`（後継 item に置き換えた）/ `retired`（状況が消滅し、もう起きない）。復帰（`disabled` → `active`）は誤検知だったときにマージゲートで戻せる（機械規則は置かない）。
- **supersede**: 後継 item の id を**本文 prose に1行** `superseded by <後継 id>` として書く（frontmatter のスキーマは変えない・grep で辿れる）。**昇格条件**: 後継チェーンの機械照会が必要になったら typed フィールド `superseded_by` へ昇格する（`observations` の version と同じ YAGNI の扱い）。

**置き場規則（関係で解く・repo 固有パス不要）**: 収穫した knowledge item は、**その収穫元 episode が属する蒸留木の `knowledge/items/`** に置く（＝ item の `source.ref` が指す episode / PR と同じ木）。これで蒸留木が複数あるリポジトリでも、item ごとに置き場が source.ref との関係で一意に決まる。`knowledge/` は蒸留木ルート直下（`decisions/` / `episodes/` / `plans/` の兄弟）に置き、README は同じ木の `knowledge/README.md`。**型付き item（ULID 名）は `knowledge/items/` に隔離**し、自由記述の knowledge ノートがあれば `knowledge/` 直下に別途置き `items/` には混ぜない。エンジン独自のトップレベル名前空間は切らず、committed で存在する蒸留木を錨にする。段3 の列挙は各木の store を横断して見る。採用先での木の具体的な解決や dogfood 例は各 store の README を参照する。検証コマンド `validate-knowledge` の directory mode は `items/` 内の全 `*.md` を検証し、ULID 名でない誤名 item は skip せず WARN + exit 1（すり抜けを黙って落とさない）。

## 4. 共通フロントマター

以下の format 機構（§4〜§9）は **committed 蒸留層に適用**する。作業層は frontmatter 最小/不要（§2.2）。

### 必須フィールド

全 committed 文書型で必須。

```yaml
---
id: "<ULID>"           # 機械追跡用の一意識別子
title: "<タイトル>"     # 人間可読なタイトル
date: YYYY-MM-DD       # 作成日（ISO 8601）
type: <文書型>          # discussion | kickoff | plan | episode | decision
status: <ステータス>    # draft | in-development | stable | deprecated
---
```

### 任意フィールド

文書型に応じて使用。

```yaml
source: "<出典>"                        # 起点となる Epic / Issue（kickoff/plan で使用）
scope: canonical | <project-name>       # 影響範囲（kickoff/plan で使用）
related:                                # 型付き参照配列（§7 参照）
  - type: <関係型>
    ref: "<パスまたは URL>"
    reason: "<関係の説明>"
tags: [tag1, tag2]                      # 検索・フィルタ用タグ
so:                                     # SO モード（plan で必須・§4.1 参照）
  design: weak | strong                 # 設計 SO のモード
  impl: weak | strong                   # 実装 SO のモード
  reason: "<なぜそのモードか>"
# promotion: [...]                      # 昇格の判定（episode 専用・closure が埋める・「昇格の判定」節）
```

`promotion` を上でコメントにしてあるのは、**未編集のまま写すと `[]`（＝判定の対象が0件だったという主張）が意図せず付いてしまう**ためである。値の形は「昇格の判定」節を見て、closure で書く。

### 4.1 SO モード（強/弱・plan で選択）

セカンドオピニオン（SO）を **強 SO / 弱 SO** の 2 モードとして定義し、frontmatter `so.design` / `so.impl`（＋ `reason`）で **設計段階に選択・記録**する。用途目安: 強＝高難易度・高リスク・不可逆／弱＝低〜中難易度・可逆。

- **記録層**: `so` は **plan で必須**（kickoff オプション化〔DJ-7〕により plan が実装系の主経路のため）。kickoff を経由する場合は kickoff で記録してもよい。

| | ツール | 終了条件 | partial（一部 timeout） | 0（全 timeout/空） |
|---|---|---|---|---|
| **強 SO** | `peer-ai-review` | 指定全レーン返却 ＋ 全レーン合意（material 残ゼロ）まで iterate | 不許容＝再試行で埋める | 不可（全返却が条件） |
| **弱 SO** | `so-compare` / `oe-refute` / `oe-review` | 1 周で終了可（iteration は推奨だが任意） | 許容＝**disclose して進む**（advisory） | **不可＝SO 未実施扱い・再試行/escalate**（最低 1 レーン実返却必須＝"0 はなし"） |

- **レーン数・モデル多様性は mode に焼かない**＝都度オプションで指定（直交）。既定のレーンポリシー（設計=3社 codex+cursor+claude / 実装=2社 codex+cursor 等）は `orchestration-toolkit` スキル参照。
- 機構層（`SO_TIMEOUT`[既定 240・codex/cursor]と `SO_CLAUDE_TIMEOUT`[既定 1200・claude]が**初回試行の基準**＝`timeout_empty` 時のみ**1回リトライ**〔codex/cursor は `×1.5`・claude は同じ基準でもう一度〕・#22 の exit 0/1/2 分離・#196 の conservative 集約＝verdict 取れないレーンは `error` で survived を阻む）の上に乗る **consumer ルール**。「timeout で実質 SO をパスできる」を弱 SO の "0 はなし" フロアで塞ぐ。
- 補足（機構境界）: exit0＋空（`success_empty`）は機構上 **partial に計上**されるため、「最低 1 レーン**実返却**」の担保は機構 exit code でなく **consumer ルール側**が負う。また `oe-refute`/`oe-review` の集約は #196 conservative＝**error レーンがあれば全体 `refuted`（保留）**で、弱 SO の generic partial=disclose より**厳しい側に倒す**（error は disclose せず保留）。

## 5. ULID 規約

committed 層のみ（作業層は ULID 不要）。

### フォーマット

[ULID (Universally Unique Lexicographically Sortable Identifier)](https://github.com/ulid/spec) — 26文字、Crockford Base32。先頭10文字がミリ秒精度のタイムスタンプ、末尾16文字がランダム。

例: `01KNCK58PTF85AVQD4M9BFYV99`

### 生成方法

```bash
python3 -c "
import time, random
t = int(time.time() * 1000)
c = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
ts = ''.join(c[(t >> (45 - 5*i)) & 31] for i in range(10))
rand = ''.join(random.choice(c) for _ in range(16))
print(ts + rand)
"
```

`ulid` パッケージが利用可能な環境では `python3 -c "import ulid; print(ulid.new())"` を推奨（公式仕様に厳密準拠）。上記の手書きスニペットはタイムスタンプエンコーディングが簡易実装のため、厳密な ULID パーサーとの互換性は保証しない。

**バリデーション方針**: MVP（#19 4-3）では「26文字・Crockford Base32 文字集合」のフォーマットチェックのみ。タイムスタンプの正確性やモノトニック性の検証は将来拡張とする。

### ファイル命名との共存

- **ULID**: frontmatter の `id` フィールドに格納。機械追跡用
- **ファイル名**: `YYYY-MM-DD-{type}-{topic}.md` を維持。人間ナビゲーション用（§9）

ULID はファイル名に含めない。理由: ファイル名が長くなり人間可読性が下がる。`rg "^id:" docs/` で ULID → ファイルの逆引きは十分に高速。

## 6. Status ライフサイクル

specre の status enum を採用。

```
draft → in-development → stable → deprecated
  ^          |
  └──────────┘  （要件変更時に逆行可）
```

| status | 意味 | 遷移トリガー |
|--------|------|-------------|
| `draft` | 初期状態。作成中・レビュー前 | ドキュメント作成時 |
| `in-development` | 内容に基づく作業が進行中 | 実装着手時 |
| `stable` | 確定・受理済み。後続タスクの参照として信頼できる | レビュー完了・合意時 |
| `deprecated` | 陳腐化。後継があるか不要になった | 後継ドキュメントがある場合は `related` に `type: supersedes` で逆方向リンクを張る |

遷移は強制しない。スキップ・逆行を許容する（specre と同方針）。

## 7. Related 型の語彙

`related[]` 配列の `type` フィールドに使える値。既存の kickoff/ADR ドキュメントで使用されている型を棚卸しして明文化。

| type | 意味 | 使用例 |
|------|------|--------|
| `parent_issue` | 対象 Issue | kickoff → Issue |
| `parent_epic` | 所属 Epic | kickoff → Epic |
| `source_material` | 出典・参考資料 | OSS リポ、調査ドキュメント |
| `design_context` | 設計判断の背景 | architecture-sketch, context-foundation |
| `integration_target` | 統合・参照先 | 既存スキル、コマンド |
| `future_hook` | 将来の接続点 | 未着手の Issue、構想段階の機能 |
| `derived_from` | 派生元 | ADR が別の ADR / discussion から派生 |
| `supersedes` | 置き換え対象 | 新 ADR → 旧 ADR |
| `sibling` | 同列の成果物 | 同一 Epic 内の別 Issue |
| `evidence_for` | 根拠を提供 | 失敗事例 → 設計要件 |
| `modification_target` | 変更対象ファイル | kickoff → 既存ファイル |
| `reference` | 汎用参照 | 上記に当てはまらない参照 |

新しい型が必要な場合は追加してよい。ただし既存の型で表現できるなら既存を使う。

**昇格の参照（§13）**: 昇格元の作業層 doc（gitignored）を `related` の `ref` で指さない — 掃除で dead-end 化する（§13.4 dead-pointer）。provenance は本文の散文注記（「元は `.oe/...` に在った」）で残し、`ref` には committed の昇格先を張る。

## 8. 文書型別テンプレート

committed 蒸留5段のテンプレート。

### Discussion

最小フォーマット。本文はフリーフォーム。

```yaml
---
id: "<ULID>"
title: "<探索テーマ>"
date: YYYY-MM-DD
type: discussion
status: draft
tags: [topic-tags]
---
```

### KickOff（オプション層）

**フロー層 kickoff**（committed・設計文書・`plan-to-kickoff` 変換の出力）のテンプレート。オプション層であり、使う条件は §10 を参照（対話でスコープ確定できない大型 / SO・外部共有への投入時）。**作業層の委譲文書 `brief`（§3.2）とは別物**。既存パターン（`docs/plans/issue#10/*.md`）を明文化。

```yaml
---
id: "<ULID>"
title: "<作業タイトル>"
date: YYYY-MM-DD
type: kickoff
status: draft
source: "<Epic / Issue>"
scope: canonical | <project-name>
related:
  - type: parent_issue
    ref: "<URL>"
    reason: "<説明>"
  - type: parent_epic
    ref: "<URL>"
    reason: "<説明>"
tags: [tags]
so:                          # SO モード（§4.1）
  design: weak | strong
  impl: weak | strong
  reason: "<なぜそのモードか>"
---

# <タイトル>

## 背景
## スコープ
## 成果物
## 完了条件
## ステップ
## リスク・未確認事項
## セカンドオピニオン検証（frontmatter `so` のモードに従う・§4.1）
```

### Plan（実装系で必須）

`kickoff-to-plan` スキルの出力形式と整合。frontmatter は KickOff と同構造。kickoff を経由せず**直生成**する経路が主（DJ-7）。

```yaml
---
id: "<ULID>"
title: "<プランタイトル>"
date: YYYY-MM-DD
type: plan
status: draft
related:
  - type: derived_from
    ref: "<kickoff ファイルパス>"    # kickoff 経由の場合
    reason: "<説明>"
tags: [tags]
so:                          # SO モード（必須・§4.1）
  design: weak | strong
  impl: weak | strong
  reason: "<なぜそのモードか>"
---
```

本文は `kickoff-to-plan` SKILL.md の出力フォーマット定義に従う（TODO 項目 + Gate + Context）。**plan は実行可能な粒度（コマンドレベル）まで分解する**（DJ-11 大原則）。

### Episode

frontmatter + 性質ガイド。本文はフリーフォーム（ハイブリッド構成）。ライフサイクル規範は §12。

```yaml
---
id: "<ULID>"
title: "<エピソードタイトル>"
date: YYYY-MM-DD
type: episode
status: draft
related:
  - type: derived_from
    ref: "<plan ファイルパス>"
    reason: "<説明>"
tags: [tags]
promotion:                          # 昇格の判定（closure が埋める・下記「昇格の判定」節）
  - subject: "<この単位が下した判断の1行要約>"
    verdict: not-required           # required / not-required / unknown のいずれか1つだけを書く
    ref: "本文: <根拠を書いた見出し>"
---
```

性質ガイド（本文の書き方指針）:

> 冒頭に「なぜこの作業が始まったか」を 1〜2 文で自己完結して書く（Context / なぜ。リンク先参照のみにしない）。各 Step の記録は、後から読んだ人がやりとりの流れを追跡できるように書く。特に問題発生→原因特定→対処の連鎖は省略しない。羅列で終わらせず、転用可能な知見・教訓があれば節を立てて残す。

性質ガイドは**本文層**（作業中に随時追記する層）に属する。下記の構造化 FB セクションは**振り返り層**（closure が書く層）に属し、両者は別の層である。本文はフリーフォーム（目的指示）、FB セクションは構造化（手段指示）という置き分けを崩さない。

構造化 FB セクション（Episode 末尾、任意）— **振り返り層**:

```markdown
## フィードバック
- 想定外だった点:
- 規約遵守状況:
- ADR 昇格候補:
- 次の消費者（誰が / どのタスクで読むか）:
- follow-up の行き先（Issue / ADR / 別doc / 追わない宣言）:
```

上記5項目は**形式の例示**であり、項目の正本は `episode-retrospective` が持つ（本節と skill 側で項目が1対1である必要はない）。うち「次の消費者」「follow-up の行き先」はこの5項目のなかで closure 時の必須項目（他は該当時のみ。空欄の機械的穴埋めはしない）。closure の必須項目の全体は `episode-retrospective` の closure gate checklist を参照。closure（status 確定・振り返り）の手順も同 skill を参照。

closure の各項目は本文の再掲でなく**本文への pointer** で足りる（`episode-retrospective` の read/write 契約）。本文と closure に同じ内容を2度書かない。

#### 昇格の判定（`promotion`・closure が埋める）

closure の必須項目「昇格の判定」を成果物側で機械可読に持つ欄。**判定の基準（何が昇格に値するか）は `episode-retrospective` の「昇格の判定」節が正本で、本節は置き場・値域・多重度だけを定める。**

本欄は**最後のアンカー**にあたる。**一次アンカーは作業中に置く印**で、規約は §12「ライフサイクル規範」にある。

| フィールド | 必須 | 型 | 形式 | 意味 |
|-----------|------|-----|------|------|
| `subject` | 必須 | string | 1行（LF / CR とも不可）・空でない | どの判断についての判定か。**集合語（「すべて」「全体」）を置かない** |
| `verdict` | 必須 | string | `required` \| `not-required` \| `unknown` の**うち1つ** | 判定 |
| `ref` | 必須 | string または string の配列 | `本文: <見出し>` **または** `本文なし: <理由>` | 判定の根拠の在り処。read/write 契約と同じ2形（補完マーカーを塞がない）。根拠が複数箇所にあるときは配列 |

**多重度 — 1判定 = 1エントリ。** **判定の集計行は書かない**（件数が要るなら本欄から導出する）。

**`[]` と N 件は「件数の軸」で定義する:**

| 形 | 意味 |
|----|------|
| `promotion: []` | **判定の対象になる判断が1件も無かった。** 正当な結果であり、件数を運用指標にしない |
| N 件 | N 件の判断それぞれに判定を下した |

> **`required` が0件だったこと（＝「昇格に値するものは無かった」）は `[]` では表さない。** N 件のエントリのどれも `required` でない形で表す。`not-required` と `unknown` も1件ずつ記録する対象である。

**有効な形は「省略」「`[]`」「N 件」の3つだけである。** `promotion:` を値なしで書いた形（YAML の `null`）は有効形ではない。`subject` は配列の中で一意にする（closure 側の判定項目と同じ1行要約を使い、両者を突き合わせられるようにする）。

**理由の散文は本欄に置かない。** `not-required` の理由・`unknown` の「何が分かれば決まるか」・参照した材料は、closure の構造化 FB セクション（`episode-retrospective` が定める場所）に残す。本欄は機械契約の3つ組だけを持ち、対応づけは `subject` で行う。

**不在の解釈規則**（tier を構造化せずに3通りへ切り分ける）:

- 本文に opt-out の定型行（`振り返り不要:` で始まる1行）があれば、不在は**正当**である。
- **`date` が `2026-08-07`（本節の導入日）より前の episode** は、不在が**対象外**である（遡及しない）。導入日を節の中に値として書くのは、配布された本文だけで境界を計算できるようにするためである（git 履歴を参照させない）。
- どちらでもなければ、不在は「**未確認**」である。**不備と断定はしないが、検査の列挙対象になる。**

境界は日単位なので、**導入日当日に作られた episode は「対象外」に落ちない**（同日の既存文書は「未確認」に入りうる）。粗さを承知で日付を採るのは、より細かい境界（コミット時刻）が配布物から読めないためである。

**言えること / 言えないこと**（過大に読まないため）:

- 言える: 本欄を持つ文書について、判定の件数と3値の内訳を本文抜きで取り出せる。上の規則で不在を3通りに切り分けられる。
- **言えない**: 判定の妥当性（意味判断であり人間 / SO が見る）。**判定すべき判断の取りこぼし**（印は分母を改善するが保証しない）。**`verdict` が1値であることの機械的保証**（本節は定義であって強制ではない。YAML が保証するのは値が1ノードであることだけで、閉じた3値に収まっているかは検査の担当）。単位の母集団の被覆。
- **本節の例示は検査対象から除く**（規約自身が形式例を含むと、素朴な検査が見本を本物と誤認する）。

### Decision / ADR

蒸留の最終成果。最も重いフォーマット。

```yaml
---
id: "<ULID>"
title: "<判断の1行要約>"
date: YYYY-MM-DD
type: decision
status: stable
related:
  - type: evidence_for
    ref: "<根拠となるドキュメントやログ>"
    reason: "<説明>"
tags: [tags]
---

# <タイトル>

## コンテキスト
何が起きていたか / 何を検討していたか

## 決定
何を決めたか（1-3行）

## 根拠
なぜそう決めたか（比較した選択肢含む）

## 結果
この決定により何が変わるか / 注意点
```

## 9. ファイル命名規約

### committed 層

```
YYYY-MM-DD-{type}-{topic}.md
```

- `{type}`: `discussion`, `kickoff`, `plan`, `episode`, `decision` のいずれか
- `{topic}`: ハイフン区切りの英語スラッグ（例: `quality-gate-skip-prevention`）
- ADR 形式 `ADR-NNN-{topic}.md` はプロジェクト固有の decisions/ で引き続き使用可

配置先:

| 種別 | パス |
|------|------|
| プロジェクト横断の Decision | `docs/decisions/` |
| プロジェクト固有の Decision | `projects/{name}/docs/decisions/` |
| KickOff / Plan | `docs/plans/{issue-or-epic}/` |
| プロジェクト横断の Episode | `docs/episodes/` |
| プロジェクト固有の Episode | プロジェクト固有ディレクトリ（規約は各プロジェクト） |
| Discussion | `docs/draft/` または `ideas/`・プロジェクト固有は `projects/{name}/docs/discussions/` |

### 作業層（`.oe/`）

```
.oe/{type}-{topic}.md
```

- `{type}`: `brief`, `report`, `claim`, `handoff`, `board`, `so-prompt` 等（開いた集合・§3.2）
- 日付・ULID は不要（machine-local・使い捨て）。例: `.oe/brief-249.md` / `.oe/plan-249-v2.md` / `.oe/report-238.md`
- 旧称の `.oe/kickoff-*.md`（委譲文書）は `.oe/brief-*.md` へ移行（§3.3）

## 10. 遷移規則（タスク種別 → 入口層）

タスク種別ごとに、どの層から入るか + 省略条件。この表は**骨格**（DJ-6 が明示的にそうスコープした）であり、全タスク種別の網羅的な決定表ではない。境界は下の判定順で捌く。

| タスク種別 | 入口層 | 省略条件 / 注記 |
|-----------|--------|----------------|
| 設計判断が多い | discussion（QDD 併用） | `predecision-exploration` を通す（§11 ゲート1） |
| スコープ確定済みの実装 | plan（直生成） | kickoff 省略可・**plan は必須** |
| 大型（対話でスコープ確定不能）/ SO・外部共有への投入 | kickoff → plan | `plan-to-kickoff` 変換。kickoff はオプション層 |
| 軽微修正 | 層なし直実装 | episode opt-out（1行の記録で可） |
| 調査・研究 | research ノート or discussion | `research-intake` / `oss-research-session` |

**不変則**: `plan` は実装系タスクで**必須**（kickoff 経由でも直生成でも）。`kickoff` はオプション層（DJ-7・層の廃止はしない。既存 kickoff doc と `plan-to-kickoff` スキルは壊さない）。

**判定順（軸が直交し複数行に該当するとき・境界の解消）**:

1. **設計判断が絡むか** — 絡むなら discussion から（省略できるのは対話でスコープを確定でき QDD 不要と判断できるときのみ）。
2. **実装を伴うか** — 伴うなら **plan 必須**。**「軽微修正」は plan 必須則の唯一の例外**（可逆・小・自明で設計判断を含まないもの。判断に迷うなら軽微ではない＝plan を書く）。bugfix / 緊急 hotfix も設計判断が無ければ軽微側、有れば plan 側。
3. **迷ったら重い側（plan・discussion）に倒す** — 過小な層選択（層なしで済ませて設計級を作業層に滞留させる）が実害（§13）だから。
4. **単位**: 入口層は **issue 単位**（複数 issue 束ね / Epic 横断は各 issue に分けるか、束ねる場合は最大スコープの種別で判定）。docs-only 変更は「文書＝成果物」ゆえ実装系として扱う（本 #249 改訂が実例＝作業層 plan を使い plan 必須側）。
5. **親→子委譲**: 統括が入口層を決め、子には `brief`（§3.2）で渡す。子の作業も同じ判定順に従う（実装系なら子が plan を書く）。

**research ノートの位置づけ**: `research-intake` / `oss-research-session` の出力は committed 蒸留5段（§3.1 の閉じた enum）の外の独立成果物（`docs/research/`・別スキーマ `status: research-complete` 等）。入口としては使えるが 5型ではない。そこから設計へ進むときは discussion / plan へ接続する（research ノート自体を蒸留5段に混ぜない）。

## 11. ゲート配置

フロー上のゲート — 設計着手前の soft gate (0)（必要時）+ 確定〜後始末の (1)–(6)。各ゲートで**必ず通すスキル**（routing）。中身の品質基準は各スキルに委ねる（DJ-11 二層構造 — 本 spec が持つのは大原則1行 + routing のみ）。既存の (1)–(6) は番号を維持し、先頭に (0) を追加する（consumer の再 stale 化回避）。

```text
[設計着手前] --(0)--> [設計判断] --(1)--> [plan 確定] --(3)--> [実装] --(4)--> [PR] --(5)--> [merge] --(6)--> [後始末]
```

- (0) は設計着手前の soft gate（毎回ではなく必要時のみ挿入）
- (2) は plan 確定前（設計SO）

| # | 位置 | ゲート | routing スキル / ルール |
|---|------|--------|------------------------|
| 0 | 設計着手前（必要時・soft） | `question-driven-design` で人間と scope・考慮漏れ・設計着手可能性をすり合わせる。設計判断が多い / 前提未確定 / 着手可能性が不明なとき (1) の前に挿入 | `question-driven-design` + `implementation-gate-rule` |
| 1 | 設計判断の確定前 | ゼロベース代替探索を最低1回 | `predecision-exploration` |
| 2 | plan 確定前 | 設計SO（`so.design`） | `so-compare` / `oe-refute` / `oe-review`（弱）・`peer-ai-review`（強） |
| 3 | plan → 実装 | owner HG（人間ゲート） | `implementation-gate-rule` |
| 4 | 実装 → PR | 実装SO（`so.impl`）+ テスト実行 + Copilot | `so-compare`/`peer-ai-review` + `copilot-review-response` |
| 5 | PR → merge | episode closure（マージ前・後追いは `reconstructed` 明示）→ owner マージ（HG） | `episode-retrospective` |
| 6 | merge 後 | issue close 判断（keep-open 明示）+ worktree 掃除（親）+ 昇格判定（§13） | `branch-finish` + §13 |

(0) は毎回ではなく**必要時の soft gate**（(3)/(5)/(6) の owner HG のような必須ゲートとは別）。§10 遷移規則の「設計判断が多い → discussion（QDD 併用）」がこの (0) に対応する（DJ-6）— 入口層 discussion での QDD と gate (0) は同じ「人間とのすり合わせ」を指す。

ガードレール枠（#248）の固定節はこの配置図を参照する。

## 12. ライフサイクル規範

episode を中心とした文書の生き死にの規範。**規範をここに置き、機械強制（hook・oe 結合）は #185 に残す**（規範と機構の分離）。

- **着手時に枠を作る**: episode はタスク着手時に枠を作成する（closure 時に一から書き起こさない）。
- **リアルタイム追記を原則**とする: 作業の進行に合わせて追記する。後追いで再構成した場合は冒頭に `reconstructed` を明示する（追記ログと証拠価値が違う）。追記した本文は closure から pointer で参照される（再掲しない）ので、closure が指せる形で節を立てて書く（`episode-retrospective` の read/write 契約）。
- **closure はマージ前**: episode の closure（status 確定・振り返り）は PR レビュー後・**マージ前**に行う（ゲート5）。
- **tier は痕跡価値で決める**: opt-out / standard / heavy の判定は `episode-retrospective` に従う（痕跡の価値＝非自明な文脈の繋がりがあるか）。
- **昇格の印をその場で置く**: 「これは昇格を考えるべきかもしれない」と思った**その場で**、本文（随時追記の側）に固定接頭辞の1行を置く。下記「昇格の印」を参照。

### 昇格の印（一次アンカー・本文の随時追記側）

判断が生まれたその場に置く印。**印の集合が、closure が昇格の判定を下すときの分母の候補になる。**

```markdown
昇格の印: <何を昇格の対象として考えたか・1行>
```

**上の枠は誌面の都合であって、印はコードブロックの中に置かない。** 枠ごと写すと印にならない（下の1つ目のとおり）。本文には枠を外した1行だけを置く。

- **行頭の裸行として置く。囲まない。** バッククォート・箇条書き・引用・見出し・コードブロックの中に入れた行は**印ではない**（囲んだ瞬間に拾われなくなる）。本文が印そのものではなく**印という語彙に言及する**ときは、逆に囲んで区別する。
- **置き場**: その判断が生まれた**随時追記の節の中**（closure の側ではない）。
- **1行だけ書く。理由も材料も書かない。** 書きたくなったらそれは本文の散文として書けばよく、印の義務にはしない。**重い儀式にすると印が落ちず、分母も作られない。**
- **印は候補であって判定ではない。** `required` / `not-required` / `unknown` の判定は closure が付ける（「昇格の判定」節）。**印を置いた結果が `not-required` になるのは正常**であり、印の乱発を咎めない。
- **後追いで貼らない。** 後から再構成した印は追記ログと証拠価値が違う（この節の `reconstructed` の扱いと同じ）。

**なぜ固定接頭辞の1行なのか**: 判定値そのもの（`unknown` 等）を本文から拾う形は、他の用途の同名の値を拾ってしまう。固定接頭辞は語形が変われば外れるので、この誤りが起きにくい。

**限界（正直に）**:

- **印も自己申告であり、置き忘れを検出する主体は無い。** だから印だけに頼らず、**closure は印が1つも無くても独立に昇格を問う**（`episode-retrospective` の closure gate checklist）。印は分母を改善するが保証しない。
- この規範に機械強制は無い（規範と機構の分離・上記のとおり）。

## 13. 昇格義務（作業層 → committed）

作業層に生まれた**設計級コンテンツ**（および durable な証拠・知見）を committed 蒸留層へ昇格して commit する義務（DJ-2）。git の外にこれらが滞留する唯一の実害（棚卸し §5）を塞ぐ。#238/#250 が初回実地例。

### 13.1 トリガー（いつ昇格するか）

**判定は型名でなく内容で行う**（`report` だから除外・`proposal` だから対象、ではない）。同じ文書に設計級と運用情報が混在しうるので、混合文書は**該当ブロックのみ抽出**して昇格する。

- **対象（内容）**:
  - 設計級 — 探索の軌跡・代替案の全体像・却下ロジック・設計根拠・divergence の reconcile。
  - durable な証拠・知見 — 監査結果・再現条件・計測値・確定した技術的事実・失敗記録 / negative knowledge（#62）。設計判断でなくても後の消費者に価値が残るもの（`episode-retrospective` が独立の保存対象として扱う種類）。
- **非対象（内容）**: pane 番号・絶対パス・使い捨ての委譲指示・運用連絡など、その場限りの運用情報。`brief` 本体や `report` / `board` / `handoff` は**通常これに当たる**が、設計級 / durable が混入していればその部分は対象（型で免除されない）。
- **判定タイミング**:
  - (1) **episode closure 時**（§11 ゲート5・マージ前）＝ 昇格**候補の洗い出し**（episode の「蒸留シグナル / 昇格候補」節）。
  - (2) **昇格の実行**は §11 ゲート6（merge 後の後始末）＝ **worktree 掃除の前**に行う（掃除で git の外に消えるのを防ぐ）。
  - (3) **catch-all（規範）**: 上記2点はマージ・closure・掃除に錨付くため、それらを通らない滞留経路が残る（closure せず放棄・pane/セッション終了・PR/merge 未達の調査・メイン worktree の `.oe/` が掃除されない・複数 worktree への分散）。これを塞ぐため、**handoff / pane 終了時**と**定期棚卸し**を昇格判定の catch-all とする（散在時は「その設計級を生んだセッションの担当」が昇格責任を負う）。**機械強制は #185 に残す**（規範と機構の分離・§12）。
- **層の射程**: 作業層（`.oe/`）だけでなく、`tmp/` の確定前設計級証跡（§2.4）と raw log 層（§2.3）に設計級が生じた場合も対象（raw log は curated へ蒸留する材料＝rally-log 46k が実例）。

### 13.2 判定基準（include / exclude・#250 実地例）

**落とす（exclude）**:

- **①既出**: committed（decision / episode / merged code / PR plan）に要旨が既出のもの。**grep で欠落を確認**してから判定する（蒸留者の自己申告に寄せない）。ただし grep は逐語一致で意味的な言い換え・要約・複数文書への分散を捕捉できない＝「既出」判定の**必要条件であって十分条件ではない**。grep ヒットゼロは残す方向の強い根拠だが、ヒットありでも意味的包含を人手で確認する。**疑わしきは残す**（誤 drop より重複の方が害が小さい・危険側に倒さない）。
- **②supersede**: 後段の作業で反証・上書きされた根拠（前提そのもの）。残すと古い前提を復活させ読者を誤導するため「既出」より**強い** drop 理由。ただし drop するのは**覆された前提そのもの**であって、「**なぜ覆ったか**」（reconcile・転回の理由）は durable な negative knowledge として**残す**（§14 方向転換の記録へ・全面 drop しない）。
- **③boilerplate / 全文**: test 方針・config 詳細・link list・凡例・全文転写（durable な「なぜ」を含まない）。

**残す（include）**:

- committed にゼロか要約のみ + durable なもの — 代替案の全体像・却下ロジック・探索の軌跡・divergence の reconcile 記録（decision が結論に圧縮して落とす why-not）。

**境界の運用**: 「decision は結論のみ」は不正確（decision は結論 + 要約根拠を持つ）。よって重なる結論は **pointer 化**し、探索・却下側の詳細のみ残す（全否定でも全転写でもない中間）。

### 13.3 昇格先の型選択

昇格先は**内容の種類**で選ぶ（昇格元が `proposal` か `作業層plan` か `report` かは問わない）:

- 探索・却下・軌跡が主 → **discussion**（DJ-6 整合）
- 確定した判断 → **decision**
- 実行記録 → **episode**
- durable な証拠・知見（監査・再現条件） → 文脈により episode / decision（該当タスクの episode 内、または独立の decision）
- **negative knowledge（#62/#272）で収穫基準（非自明・再発しうる・行動を変える）を満たすもの → 型付き knowledge store（収穫元 episode が属する木の `knowledge/items/`・§2.5/§3.4）へ収穫**。これが第3の昇格先。切り出しは episode closure 時に `episode-retrospective` の収穫 Step が担う（`validate-knowledge` を通して episode と同じブランチにコミット・保存 HG = owner マージ）。基準を満たさない negative knowledge は従来どおり episode 本文に残す

**作業層 plan の扱い**: 実装計画そのものは merged code + PR 各 doc が正本ゆえ再蒸留しない。plan に残る**設計級部分のみ**（棄却案・根拠）を discussion / decision へ（#250 の plan-stage1 判断＝再蒸留せず、残る設計級は arch discussion へ・実装詳細は張替で担保）。

### 13.4 dead-pointer の張替（昇格の1単位）

昇格は「内容の移設」だけでなく「参照の張替」までを1単位とする（#250 (b)）。

- **問題**: committed doc が gitignored な作業層 doc を「正本」として参照していると、worktree 掃除で恒久 dead-end 化する。
- **規則**: 昇格時に committed→working の参照を、昇格先の committed doc へ **repoint** する。
- **gap 検証**: 張替先に substance が実在することを一次確認（grep）。在れば張替で完結、無ければ内容そのものを移設する。
- **保持の例外**: provenance breadcrumb（元は `.oe/...` に在った旨）は散文で保持可（`related` の `ref` にはしない・§7）。実行時の自己レビュー記録（事実・失敗ログ）は verbatim 保持（張替は履歴の改変になる）。

### 13.5 checkpoint（過剰 prune の防止）

計画で「残す」と決めたブロックを成果物で落とすと過剰 prune になる（#250 の失敗）。**include/exclude 表 → 成果物の逐次突合**を昇格手順の checkpoint に置く。表は昇格作業の plan（作業層 plan・#250 では `.oe/plan-250-distill.md`）に書き、成果物 doc と突合する（機械突合できると強いが、現状は plan-first ゲートと設計SO が代替）。

### 13.6 #248 からの参照粒度

ガードレール固定節が参照できる1行版:

> 設計級コンテンツは closure / 掃除の前に discussion / decision へ昇格し、committed→working の参照は昇格先へ張り替える（grep で substance の実在を確認）。収穫基準を満たす negative knowledge は型付き knowledge store（蒸留木ルート直下 `knowledge/items/`・§3.4）へ収穫する（第3経路・§13.3）。

詳細基準は本 §13 が正本。

## 14. 方向転換の記録

調査で前提が覆ったときの記録は、**新しい層・義務を作らない**（DJ-10）。

- 覆した先の文書（plan / episode）に **discard 記録の1節**（何を捨てたか + なぜ）を置く規範のみとする。`reframe-on-stall-rule` の reconcile 原則と同一。
- その転換に長期価値があるかの判定は既存の昇格ゲート（episode closure → decision・§13）に任せ、**記録時点で判断を迫らない**。
- 実践例: `docs/plans/.../2026-07-11-plan-247...` §2.1 / wez notify episode（`projects/wezterm-ai-mode/docs/episodes/2026-04-22-episode-wez-notify.md`）。

## 15. #19 MVP との接続

committed 層の入力契約（§4〜§9）を #19 MVP が消費する。

### 4-2 パーサーが期待するもの

- YAML frontmatter ブロック（`---` で囲まれた先頭領域）
- 必須フィールド 5つ（`id`, `title`, `date`, `type`, `status`）が存在すること
- `type` の値が定義済み enum（§3.1 の5型）に含まれること

### 4-3 検証ゲートが検証するもの

- 必須フィールドの存在と型
- `status` の値が定義済み enum に含まれること
- `id` が ULID 形式（26文字・Crockford Base32 文字集合）を満たすこと（MVP では §5 ULID 規約の「バリデーション方針」のとおり構文チェックのみ。厳密なタイムスタンプ検証は将来拡張）
- `related[].ref` が解決可能であること（ファイルパスの場合は存在確認、URL の場合はスキップ可）

作業層（§2.2）は検証ゲートの対象外（frontmatter 最小/不要）。

## 16. 将来拡張（スコープ外）

- **`@doc <ULID>` 双方向トレーサビリティ**: specre の `@specre` パターンを流用し、ソースコード↔ドキュメント間の参照を追跡
- **ハーネス自動強制**: フック（#24）でドキュメント生成時にフォーマット準拠を検証 → reject。作業層の昇格義務（§13）・ライフサイクル規範（§12）の hard 化もここに接続
- **`outputs:` フィールド**: NLAH State Semantics 対応。ドキュメントが生成する成果物の宣言
- **index.json 自動生成**: specre の `specre index` 相当。frontmatter を集約した索引ファイル
- **既存ドキュメントの段階的移行**: 既存の kickoff/ADR に `id`(ULID) / `status` を遡及追加（必要性が出たら）
- **`brief` 型名と engine flag の整合**: `oe-delegate` / `oe-send` の `--kickoff` flag を `brief` 型名に整合させる（engine コード変更・follow-up issue）
- **SOV 旧規約の統一**: `projects/second-opinion-verification/docs/DOCUMENT_CONVENTION.md`（v0・`report` 型・`keywords`/`use_when` 等）を canonical へ吸収するか deprecate するか（優先度低・別 issue・§3.2）
- **raw log の長期ストア**: raw log 層（§2.3）の保全・検索の機械化（#185）

## ソース

- [document-flow-stocktake discussion](../../projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md) — v2 改訂の設計ブリーフ（DJ-2/DJ-5〜11）
- [specre](https://github.com/yoshiakist/specre) — ULID・status enum・仕様カードの参考（MIT License）
- [document-format-design-principles.md](../../ideas/20260221/document-format-design-principles.md) — write:read 比率、フォーマット目的分類
- [context-foundation.md](../../projects/orchestration-research/synthesis/context-foundation.md) — コンテキスト種類と保存フォーマット
- [architecture-sketch.md](../../projects/orchestration-research/synthesis/architecture-sketch.md) — MVP 構成と蒸留パイプライン

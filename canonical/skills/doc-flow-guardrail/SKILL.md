---
name: doc-flow-guardrail
description: ドキュメントフロー全体の地図・委譲 brief の固定節テンプレ・新 repo/新統括の cold-start 手順を注入する薄い枠。統括が子へ委譲する brief を組むとき、memory の無い新 repo/新統括セッションでフローを立ち上げるとき、蒸留5段のどの層・どの遷移・どのゲートでどのスキルを必ず通すか確認するときに使用する。中身の品質基準は個別スキルへ routing する（枠は薄く保つ）。
---

# doc-flow-guardrail — ドキュメントフロー・ガードレール枠

AI 駆動開発のドキュメントフロー全体を「注入可能な枠」として外部化する。フロー制御を統括の暗黙知に載せず、このスキル1本で立ち上がるようにするのが目的。

## いつ使うか

- 統括（親）が子へ委譲する **brief を組むとき**（固定節を手書きせず本スキルから貼る）。
- memory の無い **新 repo / 新統括セッション**でフローを立ち上げるとき（cold-start）。
- 蒸留5段の**どの層・遷移・ゲートでどのスキルを必ず通すか**を確認するとき。

## 位置づけ（DJ-11 二層・薄い枠）

本スキルが持つのは **(a) 各段の大原則1行** と **(b) 遷移・ゲートごとの「必ず通すスキル」routing 表** の2つのみ。**中身の品質基準は個別スキルが持つ**（spec-card / kickoff-to-plan / adversarial-review / episode-retrospective / predecision-exploration / implementer-contract）。枠を薄く安定に保ち、基準は各スキルで独立にイテレートする。

3軸分離: **本スキル = 文書軸** / `orchestration-toolkit` = ツール軸（oe-*） / `delegate-task` = 操作軸（親子委譲）。

## spec 解決規約（case-C・全消費者共通）

正本仕様 `document-format.md` の参照はこの規約で解決する:

- **hub ワークスペース**: repo root から `canonical/orchestration-spec/document-format.md`。
- **sync 済ハーネス**: 各設定ルート下 `orchestration-spec/document-format.md`（例 `~/.claude/orchestration-spec/document-format.md` / `~/.cursor/…` / `~/.codex/…`）。
- **節参照は節タイトル主・番号従**（例「SO モード」節〔§4.1〕）。番号は spec 編集で drift しうるためタイトルを first-class に。

以降この doc で `document-format.md` と書くときは上記で解決する。

## ① フロー全体地図

```text
committed 蒸留層（git 管理・正本）
    discussion ─→ kickoff(opt) ─→ plan ─→ episode ─→ decision(ADR)
                                    ↑ 昇格（§13・設計級 + durable な証拠/知見）
machine-local 作業層（.oe/・gitignored・使い捨て）
    brief / report / claim / handoff / board / so-prompt / 作業層 plan / …
    tmp/ : SO・探索の生出力（さらに揮発的）
raw log 層（docs/raw-logs/・gitignored・verbatim・別レイヤー）
```

- 2層 + raw log 層の定義は `document-format.md`「2層構造」節〔§2〕。
- 入口層の選び方（タスク種別 → 入口層・省略条件）は「遷移規則」節〔§10〕。**plan は実装系で必須**・kickoff はオプション層。

各段 → 個別スキル索引:

| 段 / 操作 | 必ず通す / 使うスキル |
|-----------|----------------------|
| discussion（設計着手前・探索） | `question-driven-design`（gate 0）/ `predecision-exploration`（gate 1）/ `research-intake`・`oss-research-session`（調査入口） |
| kickoff（オプション層） | `plan-to-kickoff` / `spec-card`（フォーマット） |
| plan（実装系で必須） | `kickoff-to-plan` / `spec-card` / 設計SO（gate 2） |
| 実装（委譲） | `implementer-contract`（返却契約）/ `delegate-task`（親子操作）/ `orchestration-toolkit`（ツール軸） |
| episode | `episode-retrospective`（closure）/ `spec-card` |
| decision / ADR | `spec-card` |
| 昇格（作業層 → committed） | `document-format.md`「昇格義務」節〔§13〕 |

## ② 委譲固定節テンプレ（brief に貼る）

**固定節はそのまま貼る**（手書きしない）。可変節の `[...]` だけ埋める。DJ-11 の「大原則1行」はこの固定節が実体。

````markdown
## 規律（固定・必ず守る）

- **plan-first**: 実装前に計画だけ作って STOP・plan doc のパスを親へ報告する（owner HG まで実装・commit・PR に着手しない）。
- **worktree は子が自作**（`branch-naming` に従う）・統括は hands-off（事前作成しない）。
- **episode 義務**: 着手時に枠を作成・作業中は随時追記・closure はマージ前（後追い再構成は冒頭に `reconstructed` を明示）。**追記は closure から指せる形で残す** — 判断の why・失敗と撤回の経緯・棄却した選択肢・tier のトリガに当たる出来事は、起きたその場で節を立てて書く。closure ではそれを再掲せず本文を指す（`episode-retrospective` の read/write 契約）。
- **昇格の印**: 「これは昇格を考えるべきかもしれない」と思った**その場で**、本文に `昇格の印: <1行>` を**行頭の裸行**として置く（**囲むと印にならない**）。規約は `document-format.md`「ライフサイクル規範」節。印は候補であって判定ではないので、迷ったら置く。
- **昇格規則**: 設計級 / durable な知見は closure・worktree 掃除の前に discussion / decision へ昇格し、committed→working の参照は昇格先へ張り替える（詳細 `document-format.md`「昇格義務」節〔§13〕・1行版〔§13.6〕）。
- **報告2段構え**: file が正本・`oe-send` の1行はポインタ。**起動方法を決める前に `command -v oe-send` で確かめる** — PATH に在ればそのまま呼べるが、無ければ engine の `bin/` のパスで呼ぶ（hub では `projects/orchestration-engine/bin/oe-send "$PARENT_TMUX_PANE" '...'`）。**PATH に無いのに素の名前で呼ぶと `exit 127` になり、送れていないのに送ったつもりで止まる**ので、送信後に exit code を確かめる。pane 引数は変数展開のため double-quote・**メッセージ引数は single-quote**で literal 化し**改行バイトを含めない**。
- **malform hygiene**: 子ペインの生 capture を会話へ貼らない。要約するか path（ファイル/ログの場所）で渡す。
- **out-of-scope は実装せず surface**（`implementer-contract`。完了判断・レビューに影響するもののみ）。
- **指示矛盾ガード**: 親の指示が brief の終端定義または plan の step 構成と矛盾する場合は、**従う前に**矛盾を指摘して確認を取る（順序は「指摘 → 確認 → 従う」・不服従ではなく確認要求）。矛盾に当たるのは (a) 終端の再定義 (b) 未達 step の飛び越し (c) step の要件の弱体化。**step ID が書かれていること自体は免責にならない**（指された位置までの義務が履行済みかで判断する。履行済みの位置への指定・差し戻しは矛盾ではない）。正本と弁別子は `implementer-contract`。
- **マージ・worktree 掃除・issue close はしない**（親 / owner の Human Gate＝gate 6）。
- **ephemeral-ID hygiene**: 揮発的なローカル文脈の識別子（tmux pane ID 等）を、commit され共有される成果物（4層 doc・issue・PR・commit・comment）に durable な参照として焼き込まない。role / issue / PR / SHA を使う（例外＝gitignored 作業層 / 形式例示 / 計測 evidence / verbatim raw-log）。
- **work-routing / handoff**: 委譲 work の handoff 先を brief で明示する。ad-hoc subagent で work を stranded にしない（pipeline: plan → episode → 昇格 に乗せる）。
- **client 識別子を入れない**（org / リポ / issue 名は generic な placeholder で例示）。
- **SO を通す**: gate 2（設計SO）・gate 4（実装SO）は常に必須（「通すか」は固定。モード / レーンは可変＝下記）。
- 参照: `implementer-contract`（実装委譲時は必読契約）/ `doc-flow-guardrail`（本スキル・フロー全体）/ `document-format.md`「ゲート配置」節〔§11〕。

## negative knowledge（採用 item・可変・無ければ「採用なし（列挙完了・候補 N 件確認）」）

<!-- 手順は本スキル「negative knowledge 注入」節。列挙 → 採否 → 採用分だけ 1 item を複数行で貼る。本文 verbatim は貼らない（正本は store）。 -->

- `<item id>`
  - 適用理由: [今回のタスクとの具体的な接点]
  - 教訓（行動変更）: [「〜するな」「〜を確認せよ」の一行]
  - trigger: [効く状況] / landing: [nl | guard-candidate]
  - item: [repo-root 相対の item path（教訓全文への導線）]
  - source: [source.ref（出典＝収穫元 episode / PR / URL。教訓本文ではない）]

## タスク（可変・埋める）

- issue: #[N]
- scope: [このタスクで作る / 変えるもの・境界]
- 受け入れ基準: [検証可能な条件]
- branch: [prefix]/#[N]_[slug]（`branch-naming`）
- SO モード: so.design=[weak|strong] / so.impl=[weak|strong] / reason=[なぜ] / lanes=[設計3・実装2 等]
- 参照（タスク固有）: [読むべき issue / doc / コード]
- 成果物の置き場: [plan / episode / 変更対象]
````

**固定 vs 可変の境界**: 「SO を通すか」「昇格するか」「報告の形」はタスクに依らず固定。「SO のモード / レーン」「scope」「受け入れ基準」はタスク risk 依存で可変。

## negative knowledge 注入（段3 突合 → 段4 注入）

brief 組立時に、過去の失敗から蒸留した negative knowledge を突合・注入する（消費側の輪を閉じる）。枠は薄く保ち、コマンドの詳細は routing 先（store の README・`orchestration-toolkit`）に委ねる。

1. **列挙（段3）**: `knowledge-list` で store の item を蒸留木横断で列挙する（read-only・全件）。段3 は完全性のため常に `--strict` を付ける（崩れ item を skip したまま成功扱いにしない）。store の置き場は関係で解く（item は収穫元 episode と同じ蒸留木の `knowledge/items/` ＝ item の `source.ref` と同じ木）。特定の repo パスを覚える必要はない。
2. **採否（段3）**: 統括が列挙を見て、今のタスクに効く item を選ぶ（v0 は全件列挙 + 統括の意味判断・機械 matcher なし）。`landing: guard-candidate` の item は NL として注入せず guard 経路の候補として扱う。採否は brief の slot（作業層）に残し、item の `observations` には書かない（`observations` は段5 の担当・境界を保つ）。
3. **注入（段4）**: 採用分を上の「negative knowledge」slot に貼る。教訓の一行は「次にどう行動を変えるか」を書く。教訓の全文へは `item`（item path）で辿り、出典へは `source`（`source.ref`）で辿る（両者は別物）。矛盾する item を同時に採用しない。
4. **往復の締め（段5 への引き渡し）**: slot に載せた item の集合が、そのまま観測の対象集合になる。委譲先の子は closure 時に slot の**全 item** へ観測を1レコードずつ書き戻す（手順は `episode-retrospective` の観測書き戻し Step・機会が無ければ `no_opportunity`）。統括は完了報告の fact-check で「slot の item id == 観測を足した id」を照合する。
5. **二段チェック**: `--strict` が見るのは「item を列挙できたか」だけで、観測台帳のスキーマ完全性は見ない。列挙のあとに `validate-knowledge` を items ディレクトリへ回す（列挙 verb は validator ではない）。列挙が制御候補フラグや `integrity` を出した item は、この二段目で中身を確かめる。
6. コマンドのオプション・exit code・snapshot の意味論は store の `knowledge/README.md`（+ `orchestration-toolkit`）を参照する（枠にコマンド詳細を焼かない）。

## ③ cold-start（新 repo / 新統括セッション）

**統括 spawn の入口**: あなたが並列統括として起動された場合（`oe-delegate` で子登記後に `oe-register root --force` で並列 root へ自己昇格した、または spawn を経ず手動起動した）は、まずこのスキルを読んで cold-start（フロー地図・routing・固定節テンプレ・spec 解決規約）を立ち上げてから統括業務に入る。

memory が無くても、このスキル1本を読めばフロー + 参照ポインタが立ち上がる:

1. フロー地図（①）と routing 表（下記）で、いま居る層と次に通すゲートを掴む。
2. 委譲するなら固定節テンプレ（②）を brief に貼り、可変節を埋める。
3. spec の詳細は「spec 解決規約」で `document-format.md` を開く。
4. 手動起動した統括ペインは `oe-register root` で自己登記する（spawn を経ないため registry に出ず oe-tree / cockpit `--pick` に現れない → 登記で root として可視化・jump 可）。既存 pane を自分の下へ委譲登記するなら `oe-register link %N`。

**統括 succession の復旧は本スキルの範囲外**（engine track・#238/#239）。誤 close / resume からの復帰手順（board `現統括:` を新 pane へ張替 → 孤児 sidecar 掃除 → 検証。死んだ親の下へ再 parenting しない＝後継は並列 peer）は discussion `projects/orchestration-engine/docs/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md`（§4-2 / §4-3 / §5(0)）を参照する。自動化 verb `oe-reseat` は仮称・未実装。

## routing 表（遷移・ゲート → 必ず通すスキル・DJ-11 layer b）

正本は `document-format.md`「ゲート配置」節〔§11〕。本表はその索引（1:1）。gate (0) は必要時のみ挿入する soft gate、(3)/(5)/(6) の owner HG は必須ゲート。

| # | 位置 | ゲート | routing スキル / ルール |
|---|------|--------|------------------------|
| 0 | 設計着手前（必要時・soft） | scope・考慮漏れ・着手可能性を人間とすり合わせ | `question-driven-design` + `implementation-gate-rule` |
| 1 | 設計判断の確定前 | ゼロベース代替探索を最低1回 | `predecision-exploration` |
| 2 | plan 確定前 | 設計SO（`so.design`） | `so-compare` / `oe-refute` / `oe-review`（弱）・`peer-ai-review`（強） |
| 3 | plan → 実装 | owner HG（人間ゲート） | `implementation-gate-rule` |
| 4 | 実装 → PR | 実装SO（`so.impl`）+ テスト実行 + Copilot | `so-compare` / `peer-ai-review` + `copilot-review-response` |
| 5 | PR → merge | episode closure（マージ前・後追いは `reconstructed`）→ owner マージ | `episode-retrospective` |
| 6 | merge 後 | issue close 判断（keep-open 明示）+ worktree 掃除（親）+ 昇格判定 | `branch-finish` + `document-format.md`〔§13〕 |
| S | elevated 子 spawn 時（委譲操作軸・別軸） | owner 承認ハンドシェイク: 分類器 block を見越して整形済み承認パッケージ + ダイジェストを spawn 前に先出しし、承認↔実行を binding | `delegate-task`（手順）+ `orchestration-toolkit`（規範） |
| C | 委譲を完了扱いにする前（委譲操作軸・別軸） | 未達のゲートと step を経緯抜きで照合（plan・委譲時の書面・ゲート表・観測可能な状態のみ／会話履歴・完了報告・ACK の散文は渡さない・境界は書面から導出し申告で受けない）。判定は5値・`unknown` を `fulfilled` に、`not-yet-due` を `not-applicable` に畳まない。baseline 不一致時は `invalid-baseline` のみで判定に入らない | `unmet-gate-check` |

- 行 **S** は蒸留フロー軸（0-6・§11）ではなく**委譲操作軸**のゲート（§11 との 1:1 索引の対象外・番号を持たない）。子が **elevated**（`bypassPermissions` / 本番・機微アクセス）のときだけ発火し、通常のローカル auto 委譲は対象外。分類器は尊重する（迂回しない）。#262。
- 行 **C** も蒸留フロー軸ではなく**委譲操作軸**のゲート（§11 との 1:1 索引の対象外・番号を持たない）。人間の承認ゲートを越えた委譲アークの終わりに発火し、調査・plan 単位は対象外（終端が書面1箇所で足るため）。**この行は routing 上の位置であって発火機構ではない。** 起動を依頼側が覚えている必要がある限り、依頼側が完了扱いを誤る故障では同じ依頼側が起動も省略できる（規範と機械強制の分離は `document-format.md`「ライフサイクル規範」節を参照）。**起動を保証する層は #291 に park 済みで、行 C はそれを代替しない。** #289。
- **gate 3 の baseline 記録（委譲時のみ・委譲操作軸・§11 との 1:1 索引の対象外）**: 委譲アークで owner HG を通すとき、統括は **baseline を承認の記録と同じ場所に残す**。対象は3つ（**承認した plan / 委譲時の書面〔brief・固定節〕/ ゲート表の版**）で、**digest のアルゴリズムと対象も一緒に書く**（再計算が一致しなければ意味がない）。plan だけを守っても、固定節の義務やゲート表の版が入れ替われば同じ穴が開く。承認後に step が削られると、完了前の照合が**縮小された母集団を忠実に照合して「未達なし」を返す**ため、母集団の同一性を承認時に固定する。**照合の直前に計算した値を「承認時の値」として渡さない**（常に一致するので検査が空回りする）。照合手順と不一致時の扱い（`invalid-baseline` で判定に入らない）は `unmet-gate-check` が持つ。**gate 3 そのものの性質（owner HG）は変わらない**（§11 は不変）。#289。

## 関連

- `canonical/orchestration-spec/document-format.md` — フロー定義の正本（2層 / 遷移 / ゲート / ライフサイクル / 昇格）
- `orchestration-toolkit`（ツール軸・oe-*）/ `delegate-task`（操作軸・親子委譲）/ `implementer-contract`（実装委譲の返却契約）
- `spec-card`（フォーマット適用）/ `episode-retrospective`（closure）/ `predecision-exploration`（gate 1）
- 棚卸し discussion `projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md`（DJ-1〜11）

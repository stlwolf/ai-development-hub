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
- **episode 義務**: 着手時に枠を作成・作業中は随時追記・closure はマージ前（後追い再構成は冒頭に `reconstructed` を明示）。
- **昇格規則**: 設計級 / durable な知見は closure・worktree 掃除の前に discussion / decision へ昇格し、committed→working の参照は昇格先へ張り替える（詳細 `document-format.md`「昇格義務」節〔§13〕・1行版〔§13.6〕）。
- **報告2段構え**: file が正本・`oe-send "$PARENT_TMUX_PANE" '...'` はポインタ（pane 引数は変数展開のため double-quote・**メッセージ引数は single-quote**で literal 化し**改行バイトを含めない**）。
- **malform hygiene**: 子ペインの生 capture を会話へ貼らない。要約するか path（ファイル/ログの場所）で渡す。
- **out-of-scope は実装せず surface**（`implementer-contract`。完了判断・レビューに影響するもののみ）。
- **マージ・worktree 掃除・issue close はしない**（親 / owner の Human Gate＝gate 6）。
- **ephemeral-ID hygiene**: 揮発的なローカル文脈の識別子（tmux pane ID 等）を、commit され共有される成果物（4層 doc・issue・PR・commit・comment）に durable な参照として焼き込まない。role / issue / PR / SHA を使う（例外＝gitignored 作業層 / 形式例示 / 計測 evidence / verbatim raw-log）。
- **work-routing / handoff**: 委譲 work の handoff 先を brief で明示する。ad-hoc subagent で work を stranded にしない（pipeline: plan → episode → 昇格 に乗せる）。
- **client 識別子を入れない**（org / リポ / issue 名は generic な placeholder で例示）。
- **SO を通す**: gate 2（設計SO）・gate 4（実装SO）は常に必須（「通すか」は固定。モード / レーンは可変＝下記）。
- 参照: `implementer-contract`（実装委譲時は必読契約）/ `doc-flow-guardrail`（本スキル・フロー全体）/ `document-format.md`「ゲート配置」節〔§11〕。

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

## ③ cold-start（新 repo / 新統括セッション）

memory が無くても、このスキル1本を読めばフロー + 参照ポインタが立ち上がる:

1. フロー地図（①）と routing 表（下記）で、いま居る層と次に通すゲートを掴む。
2. 委譲するなら固定節テンプレ（②）を brief に貼り、可変節を埋める。
3. spec の詳細は「spec 解決規約」で `document-format.md` を開く。

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

## 関連

- `canonical/orchestration-spec/document-format.md` — フロー定義の正本（2層 / 遷移 / ゲート / ライフサイクル / 昇格）
- `orchestration-toolkit`（ツール軸・oe-*）/ `delegate-task`（操作軸・親子委譲）/ `implementer-contract`（実装委譲の返却契約）
- `spec-card`（フォーマット適用）/ `episode-retrospective`（closure）/ `predecision-exploration`（gate 1）
- 棚卸し discussion `projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md`（DJ-1〜11）

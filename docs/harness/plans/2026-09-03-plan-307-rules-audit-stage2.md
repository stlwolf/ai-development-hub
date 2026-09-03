---
id: "01M1HDRJTVCD0PHTHY8ZY5Z4HF"
title: "#307 段階2 — rules 14本の修正を 8 PR に分けて減らす（1 PR = 1論理変更）"
date: 2026-09-03
type: plan
status: in-development
related:
  - type: derived_from
    ref: "docs/harness/discussions/2026-09-03-discussion-307-rules-audit-judgment.md"
    reason: "判定表（14本 × 8軸）。本 plan の各 PR はこの判定行から出ている"
  - type: refs
    ref: "https://github.com/stlwolf/ai-development-hub/issues/307"
    reason: "本 issue。段階1（本 plan まで）と段階2（PR 実装）"
  - type: refs
    ref: "docs/harness/episodes/2026-09-03-episode-307-opus5-rules-audit.md"
    reason: "段階1 の作業記録（F-1 の期待値宣言と実測・失敗の記録・gate 2 の期待値）"
tags: [harness, rules-audit, opus5, plan]
so:
  design: weak
  impl: weak
  reason: "成果物は判定表と rule 本文という文書で、欠陥は見落とし・偏りである。選択肢拡張型の3レーン（codex + cursor + claude）で当てる弱 SO を設計に置く。実装SO は各 PR で弱（差分が数十行・可逆・配布は symlink で3ツール同時反映なので回帰確認は省かない）"
---

# plan — #307 段階2 rules 14本の修正

## Context

- 前提（解決済み）: 判定表は同日の discussion に確定した。**前提訂正後の内訳は 残す 4 / 書き換える 9 / 退役 1**（§4.4・§11）。方向は各行に「本体が持つから消せる（↓）」「本体が持たない・逆を言うから残す・強める（↑）」を明示済み。
- 前提（追補で訂正）: **owner の主モデルは Opus 5**。Fable 5.1 は統括セッション用。判定は主モデル Opus 5 の本体を基準にし、Fable 5.1 との差は discussion §4.4 の2列と §11 に持つ。Opus 5 の lean 本体には自律運転の段落・問題報告時の例外・Writing for the user が無く、Corrections がある（runtime 実体・各条件 n=1）。
- 前提: 公式一次は 2026-09-03 に取り直した（差分8点は discussion §1）。Claude Code は 2.1.258・lean system prompt が既定。F-1（`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0`）は Opus 5 / Fable 5.1 の両方で実測で効くが changelog 不在の undocumented 変数。
- 前提: rules は 14本 / 359行 / 4,477語（2026-09-03 `wc`）。配布は `~/.claude/rules/` symlink 14本（Claude）。Cursor / Codex の runtime は未採取。
- owner の gate 0 決定: 範囲 A（rules のみ・skills は次アーク）/ 減らす方向 / 2方向判定の明示 / 世代非依存は統括推奨で owner 未裁定。
- 参照: discussion §6（論点4つの推奨と owner 判断点）・§7（F-1 の扱い）・§5（unfired の処分）。
- 作業層の由来（provenance）: P-1 report・runtime capture・gate 2 claim は `.oe/` にあった。committed の正本は上の discussion と本 plan。
- この plan は kickoff を経由しない直生成（`document-format.md` Plan 節の DJ-7 経路）。

## 論点4つの推奨（owner 判断点つき・詳細は discussion §6）

| 論点 | 推奨 | owner 判断点 |
|---|---|---|
| (1) 世代差の書き方 | **裁定済（HG-1・2026-09-03）: 世代非依存。各 rule の frontmatter に見直し条件を1行** | なし（確定） |
| (2) 自己検証と外部検証 | **裁定済（HG-1）: `evidence-verification` は残し、冒頭1行で線を引く。§3 の MUST spot-check は維持** | なし（確定） |
| (3) effort 等セッション設定 | **裁定済（HG-1）: rule では扱わない** | なし（確定） |
| (4) 3ツール配布 | **裁定済（HG-1）: skill-first-operations を canonical から退役。同じ PR で AGENTS.md の見出し・check-codex-guardrails.sh のパターン・CATALOG を更新し sync-codex を止めない** | なし（確定）。Cursor / Codex の runtime 採取は follow-up |
| （追加）F-1 | **裁定済（HG-1）: 既定は変えない。rules 書き換えの前後比較の物差しとしてだけ使う（版固定・snapshot を条件に）** | なし（確定） |

### HG-1 で確定した追加の裁定（2026-09-03 03:55・正本は owner の裁定を統括が写した ruling）

| 論点 | 裁定 |
|---|---|
| (6) 3文書（episode / discussion / plan）の着地 | docs だけを先にコミットし draft PR を1個作る。マージはしない。docs だけの PR を別に切って先にマージすることはしない。段階2 の PR-1 の土台にするかは段階2 の着手時に決める |
| output-format §5 の見出しと本体の競合 | 見出しをやめて行頭ラベル「関連リンク:」にする（段階2 の output-format 書き換え・Step 7b に含める） |
| (0) SO 再走の要否 | 再走しない（判定値の変更は2行・plan 全体は3レーン済） |

未裁定で残るもの: workflow-awareness の「非 issue は default branch 滞在可」を本体に合わせるか / output-format §9 を禁止形から記述形へ書き換えるか（Fable 5.1 公式）。段階2 の該当 PR の HG で扱う。

## 語数の前後比較の枠（目標値にしない）

| 時点 | 本数 | 行 | 語 | 測り方 |
|---|---|---|---|---|
| 前（2026-09-03） | 14 | 359 | 4,477 | `wc -l -w canonical/rules/*.md` |
| PR-N 完了ごと | 記録 | 記録 | 記録 | 同じコマンド・PR 本文に前後を書く |
| 後（PR-8 完了） | 記録 | 記録 | 記録 | 同上 + 外部対照として Piebald-AI の system prompt トークン数を開く（任意） |

見込みの数値は書かない（書くと目標になる）。shimo4228 の 57.5% は参考値で、著者自身が効果の証明ではないと留保している。

F-1 の使い方（HG-1 裁定 (5)・計測手順として）: 前後比較は主モデル Opus 5 で、lean（既定）と長版（`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=0`）の両方を測る。版は 2.1.258 に固定し、長版の H1 集合の snapshot（runtime capture §5.1）と一致することを先に確かめてから比較する。既定は変えない。

## Pre-Implementation

- [ ] READ: `docs/harness/discussions/2026-09-03-discussion-307-rules-audit-judgment.md` — 判定行と帰属を確認する
- [ ] READ: `canonical/rules/*.md` 14本 — 今日の本文を再読する（判定表の要約でなく原文）
- [ ] READ: `scripts/check-codex-guardrails.sh`（rules 14本の見出し語を `canonical/codex/AGENTS.md` に必須とし、`scripts/sync/sync-codex.sh` が `set -euo pipefail` 下で呼ぶ・gate 2 で判明）と `canonical/codex/AGENTS.md`（冒頭に「14 files」）— 退役・改名のたびに**同じ PR で**この2つと CATALOG を動かさないと sync-codex が止まる
- [ ] 前提（gate 2 で確認済み）: `scripts/sync/sync-cursor.sh` は `canonical/rules` を配布せず `canonical/cursor/rules/*.mdc` 1本だけを置く。Codex は AGENTS.md の見出し要約経由。**rule 本文を常時ロードしているのは Claude だけ**。「3ツール配布」の考慮は AGENTS.md 要約の更新として各 PR に含める
- [ ] 実行: `wc -l -w canonical/rules/*.md` を PR-1 着手前に取り、前の値として固定する
- [x] HG-1（2026-09-03 03:55・裁定済）: 論点 (1)〜(6)・F-1・output-format §5・SO 再走の要否を owner が裁定した。裁定は本 plan の論点表と「HG-1 で確定した追加の裁定」に反映し、issue #307 にコメントで残す（P-5）。未裁定は workflow-awareness の競合と §9 の記述形化の2点で、段階2 の該当 PR の HG で扱う
- [ ] 前提（追補で訂正・2026-09-03 03:22 owner）: **owner の主モデルは Opus 5**。Fable 5.1 は統括セッション用。判定表の「本体が持つ」列は Opus 5 / Fable 5.1 の2列で持つ（discussion §4.4・§11）。Fable 5 の prompting guide の over-verification 節の有無は主モデルの判定には効かないので follow-up に格下げ

## Stage 1: 判定と plan（段階1・本アーク）

- [ ] Stage 1-1: P-1 情報の取り直し（完了。要点は discussion §1）
- [ ] Stage 1-2: P-2 runtime 採取 + F-1 実測（完了・discussion §2 §3）
- [ ] Stage 1-3: P-3 判定表（完了・discussion §4）
- [ ] Stage 1-4: P-4 本 plan（完了）
- [x] REVIEW: gate 2 設計SO — `oe-refute --lanes 3 --rubric exploration`（claim: 判定表 + PR 分割）。結果は下の「セカンドオピニオン検証」節に disclose した（3 / 3 refuted・反映済み）
- [x] Stage 1-5: P-2 追補（主モデル Opus 5 の runtime 採取・判定表の2列化・§11）
- [x] HG-1: owner の gate 3 裁定（2026-09-03 03:55）。**裁定 (6) により Stage 1 の終端を P-4 から P-5 へ更新した**（終端の再定義。根拠は owner の gate 3）
- [ ] Stage 1-6（P-5）: 3文書（episode / discussion / plan）を docs のみでコミットし、push して draft PR を1個作る。**マージはしない**。issue #307 に HG-1 の裁定と PR の URL をコメントする。`.oe/report-307-P5.md` に file 先行で報告する
- [ ] STOP: Stage 1 完了（P-5）— 親（統括）へ report のパスと PR の URL を報告して止まる。マージ・issue close・worktree 掃除・episode closure（gate 5・マージ前）はしない。段階2 の着手は owner / 統括の指示を待つ

## Stage 2: 修正 PR（段階2・次アーク・HG-1 の裁定後）

各 PR は master から `docs/#307_<slug>` を切って直列に進める（`canonical/CATALOG.md` と sync 設定が全 PR の共通 hotspot なので並列にしない）。各 PR に共通の受け入れ基準（AC-共通）は末尾。

### Step 1: PR-1 `subagent-strategy` の書き換え（概算: 1時間）

- [ ] Principles 節の「Actively use subagents to keep the main context clean」「Delegate investigation, exploration, and parallel analysis to subagents」を削る（公式「4.8 向けに足した『もっと委譲せよ』は外せ」に正面該当・本体が `claude_code` プリセットで委譲抑制を自前注入）
- [ ] 「委譲の上限は環境変数（`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` / `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`）で決める。rule は数値上限を持たない」を1行で足す（unfired の処分「機械検査へ移す」）
- [ ] 残す: Custom Agents First / Routing Gate / implementer-contract の要求 / 1 PR = 1論理変更の委譲単位
- [ ] 受け入れ基準: 本文に「Actively」「積極」「keep the main context clean」が無い。数値上限が本文に無い。Routing Gate の escalate 判定は変えていない。語数 367 の前後を記録
- [ ] GATE: gate 4 実装SO（弱・1レーン以上）+ AC-共通

### Step 2: PR-2 退役 `skill-first-operations`（概算: 1時間）

- [ ] `canonical/rules/skill-first-operations-rule.md` を削除する（本体 Skill 定義「該当 skill があるなら先に呼ぶ」と同義。Cursor には rules 本文が配布されておらず、Codex は AGENTS.md 要約なので canonical から退役してよい）
- [ ] 同じ PR で: `canonical/codex/AGENTS.md` の Skill-First 節を削り「14 files」を 13 に直す / `scripts/check-codex-guardrails.sh` の `require_pattern "Skill-First"` を外す / `canonical/CATALOG.md` の rules 節を更新する / `canonical/cursor/skills/cursor-kickoff/SKILL.md` 等の参照を張り替える
- [ ] `./scripts/sync.sh claude codex cursor` を実行し、`check-codex-guardrails.sh` が緑で通ることを確認する（退役の副作用の機械検査）
- [ ] 受け入れ基準: dangling 参照 0。`ls ~/.claude/rules | wc -l` が 13。guardrail script が緑。本数が 14 から 13 になることを記録
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 2b: PR-2b `implementation-principles` を1行に縮約して `behavioral` へ吸収（概算: 45分）

- [ ] `implementation-principles-rule.md` の1行目「If a fix feels hacky, address the root cause」を `behavioral-rule.md` §6 の隣に1句で吸収し、2行目「Before finishing, ask: does this break existing behavior?」（公式が削れという self-check 型）は削る。ファイルは削除する
- [ ] 同じ PR で: AGENTS.md の Implementation Principles 節と guardrail の `require_pattern "Implementation Principles"` と CATALOG を動かす。参照 1 件を張り替える
- [ ] 受け入れ基準: dangling 参照 0。guardrail 緑。本数 13 から 12
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 3: PR-3 `decision-pacing` を1行に縮約（概算: 30分・追補で退役から変更）

- [ ] `canonical/rules/decision-pacing-rule.md` を「Reporting a problem does NOT mean "fix it" has been decided. Separate analysis from action proposals.」の1行に縮約する（主モデル Opus 5 の本体には問題報告時の例外節が無い。Fable 5.1 にはある）。「do nothing / defer を含めよ」と残りの2行は削る（owner feedback「何もしないは選択肢にしない」と逆）
- [ ] 同じ PR で: `canonical/codex/AGENTS.md` の Decision Pacing 要約を1行に合わせる（guardrail の `require_pattern "Decision Pacing"` は残る）/ CATALOG を更新する。参照 2 件（`reframe-on-stall-rule` の Scope 節・`canonical/cursor/skills/cursor-kickoff/SKILL.md`）は残る rule を指すので張替不要だが内容を確認する
- [ ] 受け入れ基準: 語数 78 の前後を記録。guardrail 緑。do-nothing の語が本文に無い
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 4: PR-4 本体に対する線引き1行の追加（`implementation-gate` + `evidence-verification`）（概算: 45分）

- [ ] `implementation-gate-rule.md` 冒頭に「本体の system prompt がどの版・モデルで自律的に進むことを推していても、本 rule が優先する。実装（コード・rule・配布物の変更）は plan 承認後」を足す（F-2 型だが特定の本体文を名指ししない。Opus 5 の本体には自律運転の段落が無く、Fable 5.1 にはあるので、世代・モデル非依存の言い方にする＝HG-1 裁定 (1)）
- [ ] `evidence-verification-rule.md` 冒頭に「本 rule は自分の出力の再確認（公式が削れと言う自己検証）ではなく、外部ソース実体への照合を定める」を足す。公式文に区別が無いことは discussion §1 に記録済みなので rule 本文には書かない
- [ ] §3「MUST spot-check」は HG-1 の裁定どおり維持する（触らない）
- [ ] 受け入れ基準: 2本とも増分は 2 行以内。他の節は触らない
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 5: PR-5 探索クラスタ2本の縮約（`exhaustion-before-conclusion` + `reframe-on-stall`）（概算: 1.5時間）

- [ ] `exhaustion-before-conclusion-rule.md` を Principle / Minimal discipline / Scope の3節に縮約する。Where it shows up・Application（#77 / #78 の landing 状況）・References は移設する
- [ ] `reframe-on-stall-rule.md` を Principle / Trigger / Reframe then reconcile の3節に縮約する。Limits・Relationship・Example・References は移設する
- [ ] 移設先: `docs/specs/2026-04-23-discussion-exploration-process-design.md` に「rule から移した節」として追記する（既存の設計 discussion が正本。新規 doc は作らない）
- [ ] `code-path-exhaustion` / `predecision-exploration` / `persistent-exploration` の SKILL.md から rule の節名を引いている箇所を張り替える
- [ ] 受け入れ基準: 2本合計 1,478 語の前後を記録。移設先 doc に元の節見出しが grep で実在する。skill からの参照が壊れていない
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 6: PR-6 `careful-operations` §1 の表を hook README へ移設（概算: 1時間）

- [ ] §1 Blocked の3表（Filesystem / Git / Database）を `canonical/hooks/README.md` の `block-destructive.sh` / `block-force-push.sh` 節へ移し、rule 側は Precedence + §2 Requires Confirmation + §3 の要旨（SAFE_DIRS は hook の正本を指す1行）にする
- [ ] 機械照合: `block-destructive.sh` の `SAFE_DIRS_RE` と README の安全ディレクトリ一覧が一致することを grep で確認する
- [ ] 受け入れ基準: rule 語数 599 の前後を記録。README と script の一覧が一致。hook の挙動は変えない（script は触らない）
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 7: PR-7 本体重複の除去（`behavioral` + `execution-policy` + `input-style`）（概算: 1.5時間・gate 2 と追補で縮小）

- [ ] `behavioral-rule.md`: §3 Safe Operations は削らず「careful-operations-rule に従う」のポインタ1行に縮約する（本体より厳しい無条件停止は意図的上書き。careful-operations が「Concretizes §3」と参照している）。§4 Minimal Scope は前半（黙って広げない）を削り、後半（WHAT / HOW 分離・skill 参照や一次調査を省くな）を残す（両モデルの Delivering work に前半はあり後半は無い。後半は 2026-04 の観測失敗を直した発火実績つき）。§2 を「情報収集は CLI（gh / curl / grep）を優先する。ファイル操作は本体のモード指示に従う」に弱める。§1 §5 §6 は残す
- [ ] `execution-policy-rule.md`: 「register gates as TODO items」行を「gate / checkpoint / review を実装 step の間に独立項目として挟む」とツール名を外して残す。**「Present commands in copy-pasteable code blocks」行は残す**（Opus 5 の本体に無い。Fable 5.1 にはある）
- [ ] `input-style-rule.md`: 音声入力の前提1行に縮約する（他2行は両モデルの Delivering work と同義）
- [ ] 参照の張替: exhaustion / reframe の Scope 節が「§4 Minimal Scope」を引く。§4 の番号を保つか参照側を同 PR で直す
- [ ] 同じ PR で AGENTS.md の該当見出し（Safe Operations / Minimal Scope / Input Handling / Execution Discipline）の要約と guardrail パターンを整合させる
- [ ] 受け入れ基準: 3本合計 272 語の前後を記録。guardrail 緑。他 rule を触らない
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 7b: PR-7b `output-format` §5 のラベル化 + §9 の検討（概算: 45分・§5 は HG-1 で裁定済）

- [ ] output-format は追補で「残す・強める」になった（主モデル Opus 5 の本体に応答形式の規定が無い）。§1〜§4 は触らない
- [ ] **HG-1 裁定**: §5 の「関連リンク」見出しをやめ、行頭ラベル「関連リンク:」にする（Fable 本体「500語未満に見出しなし」との競合を解く）。`implementer-contract` の §5 / §6 参照と、報告を出す側の skill（`delegate-task` 等）で見出しを前提にしている箇所を同じ PR で直す
- [ ] 検討行（未裁定）: §9 を禁止形（記号を接着剤に使わない）から「いつ記号を使ってよいか」の記述形へ書き換えるか。Fable 5.1 公式「anti-formatting 言語は削るか、いつ整形が適切かを言う規則に置き換えよ」が根拠。Opus 5 公式に同じ節があるかを先に確かめ、本 PR の HG で owner が決める
- [ ] 受け入れ基準: §8 §9 の日本語規律の実質を変えない。`implementer-contract` からの §5 / §6 参照が壊れない
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### Step 8: PR-8 `review-when` メタデータ + CATALOG + 語数記録（概算: 1時間・HG-1 で (1) 裁定済: 各 rule の frontmatter に見直し条件を1行）

- [ ] 残る rule 全本の frontmatter に見直し条件を1行足す（キー名は `review-when:` を仮置き。例: 「本体 system prompt の該当節が変わったとき」「hook が同じ検査を持ったとき」「主モデルが替わったとき」）
- [ ] `canonical/CATALOG.md` と `canonical/codex/AGENTS.md` の最終整合を検算する（各 PR で更新済みの確認）
- [ ] 語数の前後比較表（本 plan の枠）を discussion に追記する
- [ ] 受け入れ基準: 全本に1行。増分語数を記録。目標値と書かない
- [ ] GATE: gate 4 実装SO（弱）+ AC-共通

### AC-共通（全 PR）

- [ ] PR 本文に `wc -l -w canonical/rules/*.md` の前後合計を書く
- [ ] `./scripts/sync.sh claude codex cursor` を実行し、`ls ~/.claude/rules | wc -l` が canonical の本数と一致することと、Codex / Cursor の配布実体で反映を確認する
- [ ] **各 PR で** `canonical/CATALOG.md` の rules 節・`canonical/codex/AGENTS.md` の見出し要約・`scripts/check-codex-guardrails.sh` の必須パターンを同時に更新し、`check-codex-guardrails.sh` を実行して緑を確認する（索引と guardrail を後の PR へ遅らせない）
- [ ] 他 rule の文面を「ついで」に触っていない（1論理変更）
- [ ] Copilot レビュー依頼（`pr-conventions`）と gate 4 の結果を PR 本文に disclose する
- [ ] episode closure はマージ前（gate 5）。マージ・issue close・worktree 掃除は owner / 親（gate 6）

## RISK: Claude の runtime だけで3ツール配布の退役を判定している — 対処: Pre-Implementation の READ で配布形態を確かめ、HG-1 の論点 (4) の裁定で「一律退役」か「Claude 配布限定」かを決めてから PR-2 / PR-3 に入る

## RISK: `canonical/CATALOG.md` と sync 設定が全 PR の共通 hotspot — 対処: PR を直列にし、各 PR は master 最新から切る（並列委譲しない）

## RISK（解消・HG-1 裁定 (5)）: F-1 で長版へ戻すと「本体が持つ」判定が変わる — 裁定は「既定は変えない。計測の物差しとしてだけ使う」。判定表の再走は不要

## RISK: 「本体が持つ」判定の runtime 採取が Fable 5.1（統括セッションのモデル）で始まり、主モデル Opus 5 の本体は節の集合が違う（Writing for the user と自律運転・問題報告時の例外の段落が無く、Corrections がある。追補で fable / opus × 既定 / auto の4条件を採り、差はモデルで決まると確認） — 対処: 判定表を Opus 5 / Fable 5.1 の2列で持ち、Opus 5 で成立しない「↓」は「↑（Opus では本体に無い）」へ付け直す。self-check 退役の根拠（Opus 5 公式）は主モデルに対しては正しい向き。Fable 5.1 側の差は統括セッション限定の考慮として follow-up

## 最終検証

- [ ] 語数の前後比較表が埋まっている（目標値なし）
- [ ] 14本の判定行すべてに対応する PR があり、PR ごとの受け入れ基準が満たされている
- [ ] Cursor / Codex の runtime 採取を次アークの issue（または #307 コメント）に残している
- [ ] discussion の「昇格の印」を episode closure で判定している（required / not-required / unknown）

## セカンドオピニオン検証（frontmatter `so` のモードに従う）

弱 SO・`oe-refute --rubric exploration`・lanes = 3（codex + claude + cursor）。**結果は 3 / 3 refuted**。exploration は見落としを出させる場なので verdict は想定内。受けた点・退けた点と修正後の判定は discussion §10 が正本で、本 plan は Step 2 / 2b / 3 / 7・Pre-Implementation・HG-1・AC-共通・RISK をそれに合わせて直した。

| 周 | レーン | 経過 | verdict | 要点 |
|---|---|---|---|---|
| 1 | codex | 240 秒 timeout・出力空（repo 探索で時間切れ）。so-compare の自動再試行（360 秒）で 212 秒・refuted | refuted | 「Claude 限定 runtime と自己申告標本から3ツール共通退役を導き、未代替の owner 契約を削除し、未実装の機械検査と複数論理変更を前提にしている」。1周目全体は 1,049 秒で集約 refuted（2 / 3 refuted・cursor は error） |
| 1 | cursor | 240 秒 timeout・出力空。集約では `error`（VERDICT 行なし） | error | 2周目で回復 |
| 1 | claude | 476 秒 | refuted | workflow-awareness の競合見落とし / behavioral §4 と output-format §2〜§4 の「本体が持つ」過大判定 / 退役3本と `check-codex-guardrails.sh` の衝突 / repo 内 rule 別発火データ（2026-04）の未参照 / Fable 5.1 公式指針の未照合。判定表は sandbox 外で読めず、要約表・runtime 採取・rules 本文・公式文・repo 実体に対して反証 |
| 2（短縮 claim・ファイル禁止） | codex | 59 秒以内 | refuted | Claude 限定観測から共通 canonical の退役へ一般化 / 発火帰属が弱い / 「機械検査へ移す」は未設計 / PR 原子性（PR-2・4・5・7 が複数 rule を束ね CATALOG が遅れる） |
| 2 | cursor | 59 秒以内 | refuted | 基準線が undocumented な単一 runtime / 退役3本の証拠水準の非対称 / 未探索カテゴリ（条件付き層化・計測のみ・review-when だけ）/ 発火実績 11 本 unknown は名目上 / PR-7・PR-4 の束ね・参照修復 PR の欠落 |

**受けた**: 退役の副作用（guardrail script・AGENTS.md・CATALOG を同 PR に）/ behavioral §3 §4・output-format §2〜§4・input-style・execution-policy TODO 行の判定修正 / workflow-awareness の競合明記 / repo 内 stale 発火データの採用 / PR-2 分割・PR-7 縮小 / Fable 5.1 公式の照合（§9 の書き換え候補・self-check 根拠の弱さ）。
**退けた（理由つき・discussion §10.2）**: 「計測のみ / 何もしない」（owner の gate 0 と feedback に反する。遵守率の前後測定は follow-up に置く）/ 「重複は冗長ではない」の可搬性論（Cursor / Codex に rule 本文は届いていない）/ F-1 を計測器にも使えない（版固定と snapshot を条件に使う）。
**3ツール配布の前提が変わった**: rule 本文を常時ロードしているのは Claude だけ（sync script の実体）。論点 (4) の推奨を「canonical から退役してよい・AGENTS.md 要約と guardrail を同時更新」に改めた。

**P-2 追補後の SO 判断（2026-09-03 03:45）**: 前提訂正（主モデル Opus 5）で判定値が変わった行は 2 行（decision-pacing は退役から1行に縮約へ、output-format は書き換えから残す・強めるへ）。追補の規則「3行以上なら claude レーン1本で再走・3行未満なら再走せず disclose」に従い**再走していない**。数え方は「残す / 書き換える / 退役 の値が変わった行」で、implementation-gate の「強める」の有無（Fable 列のみの考慮になった）は値の変化に数えていない。この数え方で 3 行と読むなら再走が要る（**HG-1 裁定 (0)・2026-09-03 03:55: 再走しない。判定値の変更は2行・plan 全体は3レーン済・owner 異論なし**）。差分の根拠は discussion §11（Opus 5 の runtime: 自律運転の段落・問題報告時の例外・Writing for the user が無く Corrections がある。4条件で mode ではなくモデル差と確認）。

## follow-up（本アークで実装しない）

- Cursor / Codex の runtime 採取（論点 (4)）
- Fable 5 prompting guide の over-verification 節の有無（統括セッションのモデル向け。主モデル Opus 5 の判定には効かない）
- Piebald-AI の system prompt データで lean / 長版のトークン数を取る
- shimo4228 の 08-27 更新の中身（Wayback 復旧後）
- F-1 を A/B 計測器として rules 書き換えの前後を lean / 長版で見る
- skills 28本の棚卸し（次アーク・owner の gate 0 で範囲外と決定）

---
id: "01KY6VTZPHWD0F23GKVCBGWJTT"
title: "#272 negative knowledge ループ 段1+2 — 収穫スキーマと型付き store の実装"
date: 2026-07-23
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/272"
    reason: "実装対象の issue(段1 収穫 + 段2 保存)"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-21-discussion-negative-knowledge-loop-foundation.md"
    reason: "設計正本(6段骨格・DJ-1〜5・§6 未決論点)"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/263"
    reason: "型付き層の両輪・スキーマ語彙の整合"
tags: [negative-knowledge, orchestration-engine, knowledge-store, episode-272]
---

# #272 negative knowledge ループ 段1+2 — 収穫スキーマと型付き store の実装

## Context / なぜこの作業が始まったか

negative knowledge ループ(episode の教訓を次の作業へ機械的に読み戻す自己修正ループ)の6段骨格のうち、段1(収穫)と段2(保存)を土台として実装する。episode の消費側が欠落してループが閉じていない現状(昇格率 13〜19%・読む人のいない義務は守られない)を、committed の型付き knowledge store + closure 時の収穫手順 + 機械検証で塞ぐ第一歩。設計正本は 2026-07-21 の discussion、実装方針は #272 の gate 0 / gate 3 コメントで確定。

## 作業の枠組み

- plan(作業層): `.oe/plan-272-nk-store.md`(gate 3 承認済み・設計SO 後に改訂)。
- 設計SO(gate 2): `.oe/so-272-design-findings.md`(codex + cursor 返却・claude timeout の partial)。F1〜F12 を plan に fold、B1/B2 は owner GO 済み。
- branch: `feat/#272_nk-harvest-store`。

## Step ログ(随時追記)

### Step 0: worktree + episode 枠(2026-07-23)

- worktree を自作(`wt switch --create feat/#272_nk-harvest-store --base master`)。cwd は Claude Code では追従しないため以後は絶対パスで作業。
- 本 episode 枠を作成。以後リアルタイム追記。

### Step 1: 検証スクリプト + テスト(2026-07-23)

- `projects/orchestration-engine/scripts/validate-knowledge.sh` を実装。`validate-board.sh` の idiom(exit 0/1/2・advisory・frontmatter 抽出)を踏襲しつつ、frontmatter がネスト(source.ref)・配列(observations/exclusions)・enum を持つため yq(YAML→JSON)+ jq で検査する。単一ファイル + directory mode(直下 `*.md` 非再帰)対応。
- yq の挙動を事前確認: 無引用 `date: 2026-07-23` は JSON 文字列化・scalar root は非 object として検出可・malformed YAML は yq exit 1(= schema 違反 exit 1 に写す。環境エラー exit 2 と分離)。
- `projects/orchestration-engine/tests/test_validate_knowledge.sh` を実装(61 assertion・正例/負例/directory mode/exit 分離を網羅)。設計SO で挙がった負例契約(malformed=exit1・source.ref 揮発/絶対/不存在・observations 空必須・prose 可視文字・非 .md)を固定。
- source.ref 存在確認は `OE_KNOWLEDGE_REPO_ROOT` で基点を上書きしテストを決定化(validate-board の `OE_BOARD_NOW_EPOCH` と同型)。
- つまずき: テスト[10](source scalar)の fixture 構築で sed の範囲削除 + 先頭 prepend が `source:` を開始 `---` の上に置き frontmatter を壊した。validator は正しく「frontmatter block not found」を検出(= validator は正常・テスト側のバグ)。awk による見出し+次行の 1 行 scalar 置換に修正し 61/61 PASS。
- shellcheck: validator・テストとも PASS。

### Step 2: store + README + 規約追記(2026-07-23)

- store: `docs/knowledge/items/`(ULID item のみ)+ `.gitkeep`(cold-start・空 store は validator で OK)。README は親 `docs/knowledge/README.md`(スキーマ例 fenced・B1)に置き、items/ には live sample を置かない(段3 汚染回避)。既存の自由記述ノート(`docs/knowledge/*.md`)とは items/ サブディレクトリで隔離。
- `canonical/orchestration-spec/document-format.md`: §2 intro + 一枚絵に「committed 状態 store 層」を追加、§2.5 で位置づけ(文書でなく状態 store)、§3.4 で `knowledge` を独立 store item 型として定義(必須9項・独自 status enum・ULID ファイル名の §9 逸脱と理由・§4〜§9/§15 の carve-out・採用先向け置き場規則)、§13.3 + §13.6 に第3昇格経路を追記。**#3.1 の閉じた5型 enum・#19 ゲート・§2.4 番号は不変**(回帰なし)。
- `canonical/skills/episode-retrospective/SKILL.md`: Step 3 の原則/蒸留シグナル行を store へ接続、Step 5(収穫)を追加(基準=非自明・再発しうる・行動を変える+未着地確認、手順、保存 HG=owner マージ、poisoning、Step 4 と独立)、関係節に #272 を追記。
- `canonical/skills/spec-card/SKILL.md`: 5型表に1行足さず、独立 knowledge item 節を追加(共通規約非適用・必須9項・ULID ファイル名)。
- 検証: 61/61 PASS・shellcheck PASS・hazard clean(制御バイト/pane ID/絶対パスなし)。

### Step 3: gate 4 実装SO(2026-07-23)

- 弱 SO・実装2レーン(codex + cursor)。cursor 返却・codex timeout(1/2 partial・disclose・"0はなし"満たす)。証跡 `tmp/so-272-impl/`。
- cursor 結論: **material な欠陥なし**。exit 分離(malformed=1)・bash 3.2 互換・doc↔validator 整合・回帰なし(閉じた5型 enum/#19/§11 番号不変)・hazard clean・70(当時 61)/61 PASS を確認。
- 非 material の cheap fix を採用: (1) README のスキーマ例 ULID が `O`/`I` を含み Crockford 非準拠 → 有効な ULID に差し替え(コピペ摩擦の除去)。(2) doc↔validator drift(exclusions 要素の string 型が未検証)→ validator に要素 string チェックを追加。
- coverage 追加: null 必須キー / tmp/ 揮発 ref / source 空 map(ref 欠落) / exclusions 非文字列要素 / directory 非再帰(nested 無視)。→ 70/70 PASS・shellcheck PASS。

### Step 4: PR + Copilot(進行中)

（ここから追記）

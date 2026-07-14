---
id: "01KXG72Q80H538X6HVM3VRR9YR"
title: "#248 episode（heavy）— ドキュメントフロー・ガードレール枠 v0（doc-flow-guardrail skill + document-format.md relocation）"
date: 2026-07-14
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/248"
    reason: "ガードレール枠 v0（DJ-3 の実装）"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md"
    reason: "DJ-3 三部構成 / DJ-11 二層構造の出所"
  - type: sibling
    ref: "projects/orchestration-engine/docs/episodes/2026-07-13-episode-249-document-format-v2.md"
    reason: "#249 v2 改訂（本 relocation の対象 spec）"
tags: [doc-flow, guardrail, skill, relocation, episode-248, epic-10]
---

# #248 episode（heavy）— ドキュメントフロー・ガードレール枠 v0

## Context（なぜ始まったか）

フロー制御が統括の暗黙知に載っている矛盾（棚卸し §5・統括は使い捨て #238 なのにフロー制御が記憶依存）を解くため、固定部分を注入可能な「枠」として外部化する v0。新規 skill `doc-flow-guardrail`（文書軸）+ `document-format.md` の `canonical/orchestration-spec/` への relocation + sync 配布 + 消費者の §参照張替（§13 dead-pointer の dogfood）。plan-first で親統括 `%187`（7代目）から委譲され、gate 3（owner HG）承認済で実装着手。

このリアルタイム追記 episode。tier は暫定 heavy（新 skill + relocation + repoint の非自明な接続 + 委譲固定節の dogfood 記録）。

## 実行ログ（随時追記）

### 前段（plan-first フェーズ・reconstructed）

- worktree `docs/#248_doc-flow-guardrail` を子が自作（branch prefix は brief 例 `feat/` から branch-naming + repo 履歴に従い `docs/` へ・owner 追認済）。
- 参照読解 → plan `.oe/plan-248-doc-flow-guardrail.md` 作成 → gate 1（predecision-exploration・DJ-A/B/C 探索木を確定前外部化）→ gate 2（弱設計SO `oe-refute --rubric exploration --lanes 3`）。
- gate 2 = `refuted`（advisory・3/3）。material 5点（F1 固定節欠落 / F2 anchor 軸 / F3 DJ-A 確定保留 / F4 routing 穴 / F5 SO 境界）を plan に反映。
- owner HG（gate 3）承認・実装 go。手順: Step 1→2→3a で mini-HG（path form 推奨報告）→ 承認後 Step 3〜8。追加設計SO 不要。

### 実装フェーズ（リアルタイム）

- **episode 枠を着手時に作成**（本ファイル）。tier=heavy（暫定）。
- **Step 1 relocation**: `git mv docs/specs/document-format.md → canonical/orchestration-spec/document-format.md`。rename 検出 `R`。`docs/specs/` は他 discussion 4本が残るので空にならず（掃除不要）。移設先の内部相対リンク5本（`../../ideas/…`・`../../projects/…`）は `docs/specs/` と `canonical/orchestration-spec/` が同じ repo root から2階層ゆえ全て解決（張替不要）。frontmatter `related.ref` は repo-root 相対で不変。
- **Step 2 sync additive**: `sync-claude.sh`（section 2 として挿入・以降 renumber）/ `sync-cursor.sh`（section 3 挿入・renumber）/ `sync-codex.sh`（Skills 直後に挿入・番号なし）に `sync_md_files "${CANONICAL_DIR}/orchestration-spec" "${TARGET_BASE}/orchestration-spec" "orchestration-spec"` を additive 追加（`rules` と同形）。shellcheck 3本 PASS（findings ゼロ）。
- **Step 3a path-form spike**: 実 sync は footgun のため temp base への dry-run で `sync_md_files` 相当が `document-format.md` を symlink 配置することを実証（resolves YES）。case-C（統一解決規約ノート）が skill/command 双方 × hub/sync で一律解決することを構造確認（case-C は相対パスでなく注記ゆえ command のフラット化に非依存）。→ **case-B（skill 相対の型別併用）は不要**と結論（SO F3 の問いに No）。
- **mini-HG**: path-form 推奨（case-C + case-E-lite + 節タイトル主 anchor）を親 `%187` へ報告して STOP。repoint（Step 3）本適用は mini-HG 承認後。→ **承認**（case-C 確定・case-B 不要）。
- **Step 3 repoint**: 7 consumer を case-C form へ張替。`git grep docs/specs/document-format.md -- canonical/` = 0 を確認。残る旧パス参照は非 canonical の frozen/living record のみ（scope 外・follow-up）。
- **Step 4 SKILL 本体**: `canonical/skills/doc-flow-guardrail/SKILL.md`（①フロー地図+索引 / ②固定節テンプレ〔固定=規律・可変=タスク〕 / ③cold-start / routing 表を §11 と 1:1 / spec 解決規約を本スキルが所有）。
- **Step 5 trim**: orchestration-toolkit の駆動層1サイクル略図（:19）と蒸留 doc 型（:24）を doc-flow-guardrail へのポインタに絞る（ツール軸の実体は残す）。
- **Step 6 CATALOG**: doc-flow-guardrail 行を追加（26→27）。
- **Step 8 実装SO（gate 4・oe-review 2社）**: 初回 refuted（codex=error〔VERDICT 取得不可〕・cursor=survived）→ retry で cursor が material 指摘「`scripts/sync.sh --check` が新設 orchestration-spec を検証せず sync 欠落を検出できない堅牢性欠陥」。**指摘を fix**（check_target の claude/cursor/codex に `orchestration-spec` の `check_symlinks_dir` を追加・flat .md は rules と同型）→ shellcheck PASS → 再 review で **cursor=survived**（`--check` が orchestration-spec を検証と明記）。codex は3回とも error（大きな markdown diff で verdict 行を出せない機構問題＝指摘ではない）。conservative 集約は codex error ゆえ全体 refuted のままだが、実 review した cursor レーンは clean。弱 SO・advisory ゆえ **codex 機構 error を disclose して進行**（材料 material 指摘は解消済）。

### closure（gate 5・マージ前・reconstructed でない = リアルタイム追記）

（PR レビュー後・マージ前にここへ振り返りを追記する）

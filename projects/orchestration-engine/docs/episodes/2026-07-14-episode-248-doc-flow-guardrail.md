---
id: "01KXG72Q80H538X6HVM3VRR9YR"
title: "#248 episode（heavy）— ドキュメントフロー・ガードレール枠 v0（doc-flow-guardrail skill + document-format.md relocation）"
date: 2026-07-14
type: episode
status: stable
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

フロー制御が統括の暗黙知に載っている矛盾（棚卸し §5・統括は使い捨て #238 なのにフロー制御が記憶依存）を解くため、固定部分を注入可能な「枠」として外部化する v0。新規 skill `doc-flow-guardrail`（文書軸）+ `document-format.md` の `canonical/orchestration-spec/` への relocation + sync 配布 + 消費者の §参照張替（§13 dead-pointer の dogfood）。plan-first で親統括（7代目）から委譲され、gate 3（owner HG）承認済で実装着手。

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
- **mini-HG**: path-form 推奨（case-C + case-E-lite + 節タイトル主 anchor）を親統括（7代目）へ報告して STOP。repoint（Step 3）本適用は mini-HG 承認後。→ **承認**（case-C 確定・case-B 不要）。
- **Step 3 repoint**: 7 consumer を case-C form へ張替。`git grep docs/specs/document-format.md -- canonical/` = 0 を確認。残る旧パス参照は非 canonical の frozen/living record のみ（scope 外・follow-up）。
- **Step 4 SKILL 本体**: `canonical/skills/doc-flow-guardrail/SKILL.md`（①フロー地図+索引 / ②固定節テンプレ〔固定=規律・可変=タスク〕 / ③cold-start / routing 表を §11 と 1:1 / spec 解決規約を本スキルが所有）。
- **Step 5 trim**: orchestration-toolkit の駆動層1サイクル略図（:19）と蒸留 doc 型（:24）を doc-flow-guardrail へのポインタに絞る（ツール軸の実体は残す）。
- **Step 6 CATALOG**: doc-flow-guardrail 行を追加（26→27）。
- **Step 8 実装SO（gate 4・oe-review 2社）**: 初回 refuted（codex=error〔VERDICT 取得不可〕・cursor=survived）→ retry で cursor が material 指摘「`scripts/sync.sh --check` が新設 orchestration-spec を検証せず sync 欠落を検出できない堅牢性欠陥」。**指摘を fix**（check_target の claude/cursor/codex に `orchestration-spec` の `check_symlinks_dir` を追加・flat .md は rules と同型）→ shellcheck PASS → 再 review で **cursor=survived**（`--check` が orchestration-spec を検証と明記）。codex は3回とも error（大きな markdown diff で verdict 行を出せない機構問題＝指摘ではない）。conservative 集約は codex error ゆえ全体 refuted のままだが、実 review した cursor レーンは clean。弱 SO・advisory ゆえ **codex 機構 error を disclose して進行**（材料 material 指摘は解消済）。

### closure（gate 5・マージ前・リアルタイム追記＝reconstructed でない）

tier = **heavy**（意図起動の外部SO〔oe-refute 設計 + oe-review 実装〕/ 実行中の失敗・修正〔sync.sh --check 欠陥→fix〕/ 非自明な設計判断〔DJ-A/B/C の棄却〕）。PR: https://github.com/stlwolf/ai-development-hub/pull/260 。

**closure gate checklist**:

- **Context/なぜ**: 冒頭に自己完結（フロー制御の暗黙知矛盾を枠として外部化）。✓
- **次の消費者**: (1) 統括＝委譲 brief 作成時に固定節を貼る / (2) 新統括・新 repo＝cold-start / (3) #248 v1（固定節の機械注入）/ (4) doc-flow を触る実装子。
- **status**: draft → **stable**（達成度=達成。マージは owner HG＝gate 6）。
- **evidence anchor**: SO 出力（`tmp/oe-*`）は非永続ゆえ verdict/reason を本 episode + PR 本文へ転記済。Step4 出力は下記にリンク。

**内容（出力型 × 消費チャネル）**:

- **事実・失敗**: 設計SO=refuted（advisory・3/3）→ material 5点を plan 反映。実装SO=codex レーンが3回とも verdict 行を出せず error（大 markdown diff の機構問題）。cursor が `sync.sh --check` の orchestration-spec 未検証を指摘 → fix → 再 review で survived。branch prefix は brief 例 `feat/` から `docs/` へ変更（owner 追認）。選択的省略なし。
- **自己違反（マージ前・親 fact-check で差し戻し）**: 本 episode が committed 追加に具体 pane ID（`%NNN` 形式）を2箇所（Context・mini-HG 行）焼き込み、**本 PR が導入する ephemeral-ID hygiene 大原則に自ら違反**した。修正＝role「親統括（7代目）」へ置換（`7代目` が durable・pane ID が揮発部）+ 全 committed 追加の self-sweep（pane `%NNN` / session ID / tmp パス / 絶対パス / worktree 名を確認 → 真の違反は当該 pane ID の2件のみ・他は 形式例示 / 計測 evidence / gitignored 作業層 breadcrumb の例外内と確認）。この違反記録自体も具体値を残さず `%NNN` 形式で書く。
- **決定と根拠**: DJ-A=case-C 統一解決規約（棄却: A=sync 先 dangling / B=command で破綻・型別非一貫 / D=cross-tool 破綻 / E-full=節精度喪失）。前提「単一 machine-path が存在」は偽と機構事実で確認。DJ-B=`doc-flow-guardrail` 維持。DJ-C=二ブロック分離・固定集合は SO F1 で拡張（本 brief-248 の規律節を経験的正本に採用）。
- **わかったこと**: sync は canonical ツリーを mirror するが skills=ディレクトリ symlink で深さ不変・commands=basename フラット化で深さ変化 → 相対パスは skill でしか両立せず、case-C（注記）が唯一の型非依存解。codex lane は大 markdown diff で verdict 行を返せない（観測）。
- **原則（pattern）**: **新 sync ターゲットを足したら `sync.sh --check` にも対応検証を足す**（sync と check は対）。anti-pattern＝sync だけ足して check を忘れると drift/欠落を検出できない（本 episode の実装SO 指摘が実例）。
- **行動変更**: 委譲固定節の正本は `doc-flow-guardrail` ②（トリガ=委譲 brief 作成時・着地=固定/可変ブロック）。
- **蒸留シグナル / 昇格候補**: 「sync=check 対」原則は小さく本 episode 留め（skill 化は過剰）。**受け入れ基準3 の dogfood（成功でなく失敗として捕捉）**: (i) 固定節は SO F1 で1回拡張＝過不足が実際に出た。(ii) より重い失敗＝**soft 大原則が起草者自身（本 episode）の具体 pane ID 焼き込みを抑制できなかった**＝ephemeral-ID hygiene の **suppression 失敗・criterion3（受け入れ基準3）の under-coverage 実例**。soft 層は「規範を知っていても焼き込みを止められない」ことの実データで、**機械注入（v1）/ hook 強制（v2・#24）の必要性**を裏づける（human fact-check が唯一の catch だった）。Decision 昇格は**なし**。

**follow-up routing（全件行き先付与）**:

- 非 canonical の旧パス参照 → frozen record（episode-238/249・decision-238・research audit）は **追わない**（point-in-time provenance）。生きた参照 = `context-foundation.md:129`（markdown 相対リンク）+ stocktake discussion の **`related.ref:9` と本文 `:33`「が正本」断定の2箇所**（同一 doc・living 扱いに統一）→ **owner 判断の follow-up**（本 PR scope 外・owner 指示で据置き）。Step4 で stocktake `:33` の計上漏れを是正した。
- DJ-A 案G（SO モード/ULID を skill 本体へ inline してポインタを非 load-bearing 化）→ **v1+ follow-up**。
- (b) work-routing/handoff 機構・(c) succession-recovery 機構 → **engine track（#238/#239）defer**。
- codex lane の oe-review verdict 取得失敗（大 markdown diff）→ **engine track の観測課題**（oe-review/so-compare の頑健性・追う先=engine 側・本 issue では追わない）。
- ephemeral-ID hygiene の soft 大原則が本 episode 自身の焼き込みを抑制できなかった（suppression 失敗の実データ）→ **#24（hook 強制 v2）/ 機械注入 v1 の裏づけ材料**として engine track へ（本 issue では soft 層のまま・hard 化は #24 の領分）。

**Step4 外部チェック（closure 品質・focused so-compare）**: codex=error（環境の CLI 機構問題・実装SO と同一で3回連続）/ claude=success。判定 — (1)失敗の選択的省略=なし・(3)揮発パス転記=済 は合格、(2)follow-up routing=合格（生きた参照の着地が軟らかいが owner-HG 上許容）、(4)back-propagation に **1件の計上漏れ**（stocktake `:33` 本文参照を「生きた」inventory から落としていた）→ 上記 follow-up 節で是正済。出力: `tmp/so-20260714-234914/claude-stdout.txt`。

**Copilot 1ラウンド（closure 後・マージ前）**: 行コメント1件＝固定節の「single-quote」記述と例のダブルクォートが矛盾。妥当ゆえ対応（例を `oe-send "$PARENT_TMUX_PANE" '...'`＝pane は double-quote/メッセージは single-quote と明示・コミット `0ee874a`）→ スレッドへ返信。1ラウンドで停止（再リクエストは owner 明示時のみ）。

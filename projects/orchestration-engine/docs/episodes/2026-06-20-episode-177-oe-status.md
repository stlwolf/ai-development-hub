---
id: "01KVJHAJ2N3RQ84SVNZ7BBK3YS"
title: "#177 oe-status — cockpit 観測UI（read-only 俯瞰 + 監査ログ閲覧）実装"
date: 2026-06-20
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/177"
    reason: "本 episode の対象 Issue（cockpit 観測UI: 子エージェント状態俯瞰と監査ログ閲覧）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md"
    reason: "設計探索の正本。§8 で DJ-2/DJ-3 再設計を確定（本 episode が実装）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "identity は基盤ごと・read 時相関・永続マップ無し＝本俯瞰の前提"
tags: [orchestration, cockpit, oe-status, observation, audit, read-only, episode]
---

# #177 oe-status — cockpit 観測UI 実装 episode

> 本文は reconstructed（closure 一括執筆と推定・追記タイミングは親で未検証＝real-time とは断定しない）。closure は `episode-retrospective`。

## 設計フェーズ（2026-06-20）

- kickoff（`.oe/kickoff-177-oe-status.md`）+ discussion §1-7 + decision-188 + schemas を読了。当初 plan（pane_id ジョイン）は §6 で撤回済 → #188 確定後の再設計が本タスク。
- **駆動層フロー（engine 規約）**: discussion/DJ → 設計SO → 実装 → 実装SO（oe-review）→ Episode → PR。本 episode はその実行記録。
- **設計SO（predecision-exploration 兼）= `oe-refute --rubric exploration --lanes 2`（codex+cursor）を 2 ラウンド**:
  - R1（flat 1テーブル fusion + 素朴 audit-tail）→ refuted。**新カテゴリ「単一コマンド typed sections」が出現**。flat fusion の STATE/TIMELINE 列混同が判明。
  - R2（typed sections + audit-terminal reducer）→ refuted だが**カテゴリ収束**（両レーン「typed sections 有望」）。残りは grounding 詳細（verification_timeout 誤分類 / multi-pane で blocked 隠れ / interrupt 誤分類 / max_turns→blocked 写像 / CB schema↔impl drift / 優位主張の未立証 / preview 境界）。
  - 新カテゴリが出ない R2 で predecision-exploration の暫定停止条件を満たし、grounding を設計へ織り込んで**確定**（discussion §8）。証跡: `tmp/oe-refute-*`（揮発・verdict/reason は §8 へ転記）。
- **確定（DJ-2再/DJ-3再）**: 単一コマンド・typed sections（`=== ENGINE ===` / `=== DELEGATE ===`）。engine=audit-terminal reducer（severity-max）由来 state、delegate=liveness のみ（timeline:none）。read-only airtight（ペイン出力を一切読まない・preview は ENGINE=audit timeline / DELEGATE=registry メタのみ）。優位主張は取り下げ（owner 既決方向の正直な描画＝十分性で確定）。

## 実装フェーズ

- **`bin/oe-status`**（新規）: 単一コマンド typed sections。`_oe_status_reduce`（jq・severity-max audit-terminal reducer）/ `_oe_status_engine_section` / `_oe_status_delegate_section`（oe_reg_list 投影・tmux 不在 degrade）/ `_oe_status_timeline`（受入2）/ `_oe_status_preview`（fzf 用 dispatch）/ `_oe_status_interactive`（DJ-1(b)）。`OE_DATA_DIR`/`OE_AUDIT_DIR`/`OE_STATE_DIR` override。bash 3.2 互換（declare -A/mapfile 不使用）。
- **`tests/test_oe_status.sh`**（新規・27 assert）: fixture audit/state で 8 reducer ケース（success/blocked/timeout/running?/interrupted/multi-pane-blocked/verification_timeout/max_turns）/ 注記 / KVS 補足 / DJ-4 除外 / timeline start→end / 引数ハンドリング / tmux degrade。
- **`bin/README.md` / `README.md`**: oe-status の節・索引・構成ツリーを追記。
- **検証**: `shellcheck bin/oe-status tests/test_oe_status.sh` PASS。`bash tests/test_oe_status.sh` 27/27 PASS。**/bin/bash 3.2.57（macOS）でも 27/27 PASS**（ADR-005）。実 sample（`202605261208418AW8GCYGYGY6`）+ 実 tmux でも overview/timeline 動作確認。
- **設計SO 反証の反映を実装で実証**（discussion §8.3）: timeout を CB audit-only から導出（last_event=cleanup でも state=timeout）/ multi-pane で blocked が success に隠れない（severity-max）/ verification_timeout は success のまま注記 / max_turns→blocked（limit_type フォールバック）。
- **set -e バグをテストが捕捉**: `list="$(oe_reg_list)"` が tmux 不在（rc2）で abort → `|| rc=$?` で degrade に修正（reducer 抽出も `reduced='{}'` フォールバックで堅牢化）。
- **R2(g) 反映**: preview の read-only 境界統一（DELEGATE preview は tmux capture を使わず registry メタのみ＝ペイン出力を一切読まない）。

## 実装SO（oe-review・コード欠陥レンズ・設計SO とは別ステップ）

- `oe-review --lanes 2 --base master`（codex+cursor）→ **verdict=survived**（exit 0）。`reviewed_sha=9fe1fdb`・`diff_base=master`・`changed_files_count=6`・`audit_id=20260620130225WHZKB2XA4A4M`。
- 両レーンとも audit-terminal reducer・degrade・引数処理・ULID 拘束・read-only 境界を diff/実コード/27 テスト/shellcheck/bash3.2 で照合し material な correctness/堅牢性/セキュリティ欠陥なしと判定。
- 設計SO（oe-refute・breadth/grounding レンズ）とは別レンズ・別ステップ・別 audit stream（oe-review.jsonl）。設計SO を回したことは実装SO の代替にならない（#192 false-pass 回避）。

## PR & Copilot ラウンド

- PR [#198](https://github.com/stlwolf/ai-development-hub/pull/198) 作成。%3（親コーディネータ）へ oe-send で一報（PR 番号 + query-side fusion 所感）。
- Copilot レビュー（`--add-reviewer @copilot`）→ inline 1 件。**妥当な指摘**: degrade テストの `PATH="${PATHBIN}:/usr/bin:/bin"` は `/usr/bin/tmux` のある環境（Linux/CI）で degrade が発火せず不安定 → **PATH を stub のみに修正**（コミット `1cc3a93`）。bash 5.x/3.2 で 27/27 維持。スレッドへ返信済。1 ラウンドで停止（再リクエストはユーザー明示時のみ）。

## Closure（episode-retrospective・heavy tier）

### tier 判定 = heavy
heavy トリガ複数該当: (1) 実行中の撤回（R1 flat fusion refuted → typed sections へ転回）/ (2) 意図起動の外部レビューレーン（oe-refute 設計SO ×2 + oe-review 実装SO）/ (3) 非自明な設計判断（typed sections vs flat fusion vs honest-2・棄却理由あり）/ (4) Decision 昇格候補（DJ-2）。

### Step2 closure gate
- **Context / なぜ**: #188 で identity が「基盤ごと・read 時相関・永続マップ無し」と確定し #177 が unblock。当初の pane_id ジョイン案は設計SOで破綻済 → read 時投影での俯瞰を作るのが本作業（冒頭で自己完結）。
- **次の消費者**: cockpit 運用者（稼働中 session の blocked/timeout 俯瞰・監査ログ閲覧）/ 親コーディネータ %3（PR レビュー）/ 将来 Stage-B（横断観測 event bus の前史として本ツールの read-time 投影モデルを参照）。
- **follow-up routing**（行き先必須）:
  - CB payload schema↔impl drift（`limit_type` 記述 vs `reason` emit）→ **[#199](https://github.com/stlwolf/ai-development-hub/issues/199) 起票済**（producer/schema どちらかに統一）。本 PR は reducer 側フォールバックで両対応のみ。
  - `running?` の孤児/クラッシュ判別（wez 生存オーバーレイ）→ **DJ-5「wez 接続時」の follow-up に defer**（v1 は read-only 限界として明記）。
  - in-flight blocked の read-only 検出 → **全案共通の構造限界・Stage-B event bus 待ち**（追わない＝v1 は完了 session の blocked のみ）。
  - oe-review.jsonl 駆動率測定 → **#177 v1 スコープ外（DJ-4）**。#24/Stage-B はこれに依存し #177 v1 単独では unblock しない（誤読防止・上記 caveat routing 節に明記）。
- **status 確定**: in-development → **stable**（達成: 受入1〜3 全 PASS）。
- **evidence anchor**: 揮発 tmp/ の SO 出力（oe-refute R1/R2・oe-review）の verdict/reason は discussion §8 と本 episode 実装SO 節へ転記済。oe-review `audit_id=20260620130225WHZKB2XA4A4M`。
- **SO 証跡リンク**: 設計SO=discussion §8.1（audit_id 2 件）/ 実装SO=本 episode 実装SO 節 / closure SO=下記 Step4。

### Step3 内容（出力型 × 消費チャネル）
- **事実・失敗**（選択的省略しない）: (1) 設計SO R1 で flat 1テーブル fusion + 素朴 audit-tail が refuted（撤回・転回） / (2) 実装中に `set -e` × `oe_reg_list` rc2 の degrade abort バグをテストが捕捉→`|| rc=$?` 修正 / (3) Copilot 指摘で degrade テストの PATH 環境依存（`/usr/bin/tmux`）を stub のみに修正（`1cc3a93`）。いずれも本文（設計/実装フェーズ・PR&Copilot 節）に明記済。
- **決定と根拠**: query-side fusion を flat 1テーブルでなく **単一コマンド typed sections** で実装（engine/delegate の STATE/TIMELINE 列意味が非対称＝混同を避ける）。honest-2 ビューとの優劣は証明せず、owner 既決方向の正直な描画＝十分性で確定（棄却: flat fusion=列混同 / engine-only scope-split=owner 既決で不採用）。
- **わかったこと（W）**: engine session の最終状態は **audit-terminal reducer（severity-max・末尾行でない）** でしか read-only 完全には導けない（CB timeout/max_turns は audit のみ・KVS 未書込 / cleanup・verification_* が末尾に来る / interrupt は session_end 無し / multi-pane は worst を採らないと blocked が success に隠れる）。
- **原則（Pattern/Anti-pattern）**: 「監査ログから state を導くなら**末尾行でなく lifecycle 終端イベントの precedence reduce**」（Anti: tail 一発。Pattern: severity-max reduce + verification/cleanup 除外）。「観測ツールの read-only は**ファイル+ペイン存在のみ・出力は読まない**で線引き」（Anti: capture で出力走査。Pattern: preview も audit timeline / registry メタに限定）。
- **行動変更**: なし（hook/skill 化なし。本 PR は単機能ツール追加）。
- **蒸留シグナル**: 下記 DJ-2 判断参照（今回は **Decision 非昇格**）。
- **残課題**: 上記 follow-up routing に行き先付与済。

### DJ-2 Decision 昇格判断（task #11）
**判断 = 今回は非昇格（defer）**。理由:
- DJ-2 の「read-only 俯瞰の境界＝検出を棄却した なぜ」と audit-terminal reducer の根拠は **discussion §8（永続 doc）に詳細記録済**で揮発しない。
- 基盤となる identity アーキテクチャ決定は既に **#188 ADR（accepted）** が保持。別 Decision は §8+#188 と大幅重複。
- v1 PoC 段階で境界はまだ運用再利用/争点化されていない（discussion §5 が「時期尚早なら非昇格でよい・判断を episode に残す」を許容）。
- **再昇格トリガ**: Stage-B または別観測ツールがこの read-only 境界 / reducer 方式を再利用・再検討する時点で Decision 化を再検討する。

### Step4 外部チェック（heavy・closure 品質 SO）
- `so-compare -w . --with codex,claude`（closure 品質のみ・出力 `tmp/so-20260620-221558/`・揮発）。claude=4 観点 OK / codex=より厳格に 3 点 NG → **反映済**:
  - (NG2) CB drift routing が「別 issue 推奨」止まり → **[#199](https://github.com/stlwolf/ai-development-hub/issues/199) を起票**して具体 routing 化。
  - (NG4) #188 ADR に「1テーブル」推奨表現が残り typed-sections への精緻化が back-prop 未反映 → **decision-188 帰結に back-prop 注記を追加**。
  - (NG1) closure に 事実・失敗 セクションが無い → **Step3 に 事実・失敗 を追記**（3 マーカー再掲）。
  - (OK) 揮発パスは verdict/reason を §8.1 / 本 episode に転記済（両レーン一致）。
- 残 soft spot（追わない）: discussion frontmatter `status: draft`（discussion の closure は本スキル対象外）/ Copilot スレッドのライブ照合は commit `1cc3a93` 整合で代替。

**closure 完了**: status を in-development → **stable** に確定（受入1〜3 達成）。次の消費者・follow-up routing・evidence anchor すべて充足。

## 範囲外として routing した発見

- **CB payload schema↔impl drift**: `schemas/audit-log.schema.json` は `payload.limit_type` と記述、実装（`lib/monitor.sh`）は `payload.reason` を emit。#177（read-only 観測）の範囲外。oe-status の reducer は `reason` 優先＋`limit_type` フォールバックで両対応。**ドリフト是正は別 issue に切るべき**（producer 側 or schema 側の統一）。

## caveat routing（誤読防止・必須）

- **oe-review.jsonl 駆動率測定は #177 v1 スコープ外（DJ-4）**。よって **#177 v1 単独では #24（L3 hook）/ Stage-B を unblock しない**（それらは別途の駆動率測定に依存）。「#177 で測定経路が揃った」と読まないこと。

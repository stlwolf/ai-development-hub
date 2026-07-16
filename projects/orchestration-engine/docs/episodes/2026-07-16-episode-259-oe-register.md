---
id: "01KXN127119AT8VSEMSKN5C1RZ"
title: "#259 episode（heavy）— oe-register（自己登録 + 委譲 link）と role 導出述語の締め"
date: 2026-07-16
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/259"
    reason: "自己登録 + 委譲 link の新 verb oe-register"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md"
    reason: "#257 §3 root cause（parent_pane 焼き込み・rewrite 機構なし）/ §4 並列 peer 原則"
  - type: design_input
    ref: ".oe/plan-259-oe-register.md"
    reason: "plan-first の設計正本（DJ-1〜6・guard 真理値表・設計SO 反映）"
tags: [orchestration, delegate-registry, oe-register, role-derivation, episode-259]
---

# #259 episode（heavy）— oe-register と role 導出述語の締め

> 冒頭注記: 本 episode の「前段（plan-first）」節は実装フェーズ着手時に plan §3/§9 から **reconstructed**（後追い再構成）。「実装フェーズ」以降はリアルタイム追記。

## Context（なぜ始まったか）

手動起動 pane（統括）が oe-tree / cockpit に現れない痛点（自己登録手段の不在）と、手動起動 pane 間の委譲に関係を登記する手段の不在。同根 = registry が spawn 時 `parent_pane` 焼き込みしか表現できない（#257 §3 verified）。QDD で scope を「自己登録 + 委譲 link の2操作・単一 verb `oe-register`・guard 既定・付随 doc 2点」に確定（`oe-reseat`＝board 張替は次の増分）。plan-first で親統括（7代目）から委譲され、gate 3 承認済で実装着手。tier=heavy（設計SO が v0 を refute した非自明な設計 pivot + role 導出述語の変更 + durable 知見の昇格見込み）。

## 実行ログ

### 前段（plan-first フェーズ・reconstructed）

- 一次読解（delegate-registry.sh / oe-delegate / oe-tree / oe-list / tests / #257 discussion）→ plan `.oe/plan-259-oe-register.md` 作成。
- gate 1（predecision-exploration）: DJ-1〜6 のゼロベース探索木を確定前に外部化。当初推奨 = 純追加（既存 lib/verb 無変更）・role:"child" 維持・guard は verb 側。
- gate 2（弱設計SO・`oe-refute --claim .oe/claim-259-oe-register.md --rubric exploration --lanes 3`）→ **verdict=refuted（3/3 lane material）**。material 指摘:
  - **F1（最重要・grounding 訂正）**: role は `.role` field でなく **entry 存在**から導出される（`oe-ident:60-71` / `event-bus.sh:49,68-76`）。自己 root 登録した無子 pane は最初の子 spawn まで「child」表示 + event に `role:"child"` 焼き込み（`oe-activity:148` / `oe-undelivered:177` が消費）。当初 grounding「readers は role を読まない」は不完全。
  - **F2（DJ-5 guard 抜け）**: target 生存未確認（record 直後 GC で無言 no-op）/ `%self` self-cycle / 自己 root モードで生きた親を持つ委譲子の暗黙 detach / read-check-write TOCTOU / key と .pane 不整合。
  - **F3（DJ-2×DJ-6）**: 自己 label スロット未定義・positional 二義（typo が silently self-label 化）。
- gate 3（owner HG）承認・実装 go。owner 確定3点:
  1. **DJ-1 = 判定述語を締める**: `is_child = 自 entry 存在 かつ parent_pane 非空`（既存 entry は全て parent 非空 → 既存データに bit-identical・新 role 値なし・空 parent は role 中立）。受け入れ基準5 は「既存データに対する挙動不変」と読み替え。述語テスト追加。
  2. **episode 暫定運用**: worktree 直後・実装前に枠作成 + 設計節を plan から reconstructed 書き起こし → 以降リアルタイム（規範は #159 別途）。
  3. **残フロー**: worktree → episode → 実装+テスト → README/canonical 2 skill → 実装SO（oe-review 2社）→ PR → closure → Copilot。PR 完成で親へ報告。マージ/掃除/close はしない。

### 実装フェーズ（リアルタイム）

- worktree `feat/#259_oe-register` を子が自作（`--base master`）。Claude cwd は追従せず絶対パスで作業。
- **episode 枠を着手時に作成**（本ファイル・reconstructed 前段付き）。
- **bin/oe-register 実装**: `root` / `link` サブコマンド（DJ-6・positional 二義を排し typo は exit 2）。root=`oe_reg_record "$SELF" "" "$ws" ""`（parent 空）/ link=`oe_reg_record "%N" "$label" "$ws" "$SELF"`。guard は verb 側（§4 真理値表 rev.2）。**lib write path は無変更**（既存 `oe_reg_record` を呼ぶだけ）。
  - 実装中の bug: `set -e` 下で `out="$(tmux ...)"; rc=$?` が list-panes 失敗時に代入行で即 exit(1) し rc 捕捉前に落ちる（test [12] が exit 2 期待に対し 1 で検出）→ `|| rc=$?` で compound 化して修正。
- **DJ-1 述語締め**: `bin/oe-ident`（is_child）と `lib/event-bus.sh`（`_oe_event_ident`）を「自 entry 存在 かつ parent_pane 非空」へ。既存 entry は全て parent 非空ゆえ既存データに bit-identical・新 role 値なし。event-bus の report/kick 方向判定は関係（fparent==tp）で上書きするため、parent 空の自己 root sender は honest neutral になり誤 report 化が消える（SO 予測どおりの改善）。
- **テスト**: `tests/test_oe_register.sh`（33 checks・guard 3態 + SO 抜け3〔非生存 target / %self / detach〕 + 形式エラー + env エラー）。`test_oe_ident.sh`（+3: 自己 root neutral / 子持ち→parent / 既存形不変）・`test_event_bus.sh`（+4: `_oe_event_ident` の自己 root neutral / 既存形 child 不変）に述語テスト追加。
- **gate（全 green + shellcheck）**: 新規 33 + 既存 tests/test_*.sh 全 green（test_delegate_registry 20/0・test_oe_delegate 20/0・test_oe_ident 14/0・test_event_bus 66/0・test_oe_tree ok 等）。shellcheck 新規/変更 6 ファイル PASS。
- **doc**: `bin/README.md` に oe-register verb 節 / `delegate-task` skill に register 操作節 + 全体像表 + 関連 / `doc-flow-guardrail` cold-start に自己登記 1 行（#259 が予告した接続の完成）。
- **gate 4 実装SO（`oe-review --lanes 2 --base master`）→ verdict=refuted**（codex material・cursor=`timeout_empty`＝360s タイムアウトで verdict なし＝機構エラー）。codex 指摘3件（すべて一次コード確認で material 判定・自分の guard の堅牢性欠陥＝scope 内）:
  - Critical: guard が read-check-write で非原子的（並行 link の横取り / die-after-check の成功偽装）。
  - Critical: SELF（TMUX_PANE）が非空しか検証されず、stale/spoofed で root が GC で即消え・link が生存 target を死んだ親の下に orphan 登録して成功を装う。テストも常に self を live に含め未検出。
  - Warning: 既存 entry の JSON 読取失敗を `|| true` で空 parent 同一視 → live-parent guard が corrupt entry で fail-open。
- **修正**: (a) `load_live_panes` を hoist し SELF の形式+生存を先に検証 / (b) `read_parent` を rc 保持にして corrupt entry は fail-closed（`--force` で上書き）/ (c) link は record 後に entry 存在を再確認し die-after-check を honest 失敗化 / (d) 並行 steal の窓は last-write-wins 基盤に内在（`oe-delegate:148` と同断面）として header に限界明記・原子的所有権（flock）は基盤課題として scope 外。テスト [14]（dead SELF）[15]（corrupt entry fail-closed / --force）を追加。test_oe_register 33→44・既存 spot-check 全 green・shellcheck PASS。
- **gate 4 実装SO 再実行（round 2・hardened diff）→ verdict=refuted（2/2）**:
  - cursor（新規 material）: 冪等再登録で `--label` 省略時に `oe_reg_record` が既存 label/workspace を空で上書き＝非冪等（受け入れ(3)違反）。test [6] は parent のみ検証で退行未検出。→ **修正**: `--label`/`-w` 省略時は既存 entry の値を保つ。test [16] 追加。cursor は全テストも実行し 44/0 green を確認。
  - codex（再掲）: guard の read-check-write が非原子的 + post-check が所有者未検証 → 並行 link の横取り成功偽装。→ **ownership-aware post-check を追加**（record 後に parent==SELF を再確認し「勝てなかった」を honest 失敗化）。**原子的 race 防止（flock 等）は last-write-wins registry 基盤の限界＝oe-delegate と同断面・lib 変更を要し #259 の additive scope 外**（plan §10 で pre-register 済・owner 承認 plan に明記）。
- **SO 終了判断**: 弱SO は 1 周が要件。2 周で fixable な指摘（SELF 生存 / fail-open / 冪等 / success-faking）は全て解消。残る codex の「原子的 race 防止」は scope 外の基盤課題で 3 周目は loop になる → **disclose して進む**（弱SO の partial 規約）。test_oe_register 48/0・全 suite green・shellcheck PASS。
- （次: PR → closure → Copilot）

### closure（gate 5・マージ前・リアルタイム追記＝reconstructed でない）

**tier = heavy**（トリガ: 実行中の方針転回〔設計SO が v0 refuted・実装SO が 2 round refuted〕/ 意図的に起動した外部レビュー〔`oe-refute` 設計SO + `oe-review` 実装SO〕/ 非自明な設計判断〔DJ-1 述語締め・role:"root" 案を棄却〕/ 昇格候補あり〔role 導出の existence-based 性質〕）。PR: https://github.com/stlwolf/ai-development-hub/pull/261 。

**closure gate checklist**:
- **Context / なぜ**: 冒頭 Context 節に自己完結（手動起動 pane の登記手段不在・#257 §3 の `parent_pane` 焼き込み root cause）。
- **次の消費者**: (1) owner（gate 6 マージ / issue close 判断 / canonical sync 配布）(2) #238 succession/topology クラスタ（role 導出が existence-based という知見の消費先）(3) 手動起動統括の運用者（cold-start で `oe-register root`）。
- **follow-up routing**:
  - 並行 link の原子的 race 防止（flock/CAS）→ **追わない（scope 外・基盤課題）**。last-write-wins registry の性質で `oe-delegate` と同断面。将来 registry substrate を触る時に併せて検討（engine track・issue 未起票）。
  - role:"root" フィールドの forward-looking 導入 → **追わない（YAGNI）**。消費者が role 値を読む時点の follow-up。現状は述語（existence + parent 非空）で十分。
  - oe-register の topology-change event 発行（link 時）→ **追わない（scope 外）**。QDD/plan に無く registration≠spawn。
  - role 導出が existence-based という知見 → **昇格候補（discussion/decision）**。#238/#257 succession/topology クラスタへ。owner が gate 6 で判断。
- **status 確定**: draft → **stable**（達成度=達成。受け入れ基準5条件すべて満たす・全 `tests/test_*.sh` green・shellcheck PASS・PR #261 作成済）。
- **evidence anchor**: 主要 verdict / material 指摘は本文転記済（設計SO refuted・audit `20260716051325NHD2DNSKVKH8` / 実装SO round1・round2 とも refuted・reviewed SHA `da67c00`）。生出力（`.oe/`〔本 worktree に無く親 checkout 側〕・`tmp/oe-refute-*`・`tmp/oe-review-*`・`tmp/so-closure-259`）は gitignored の揮発アンカー。secondary risk の逐条（round-2 cursor full 等）は揮発ログにのみ残り、要点は本文の残課題へ routing 済。
- **SO 証跡リンク**: 設計SO = `.oe/oe-refute-259.json`（verdict/dissent 本文転記）/ 実装SO = scratchpad（揮発・verdict/dissent 本文 + PR に転記）。

**事実・失敗（SO で refute された点と対応）**:
- 設計SO（round 1・refuted）: v0 前提「role field は moot」が崩れた。self entry の存在が oe-ident/event-bus を child 誤導出 → 述語締めで対応（DJ-1）。
- 実装SO round 1（codex・refuted）: SELF 生存未検証 / corrupt entry で guard fail-open / guard 非原子。→ SELF 形式+生存検証・`read_parent` fail-closed・link post-record 存在確認を追加。
- 実装SO round 2（cursor material / codex 再掲・refuted）: 冪等再登録が既存 label/workspace を空で上書き（非冪等）→ 既存値保持 + test[16]。codex の非原子 race → ownership-aware post-check（防止でなく検知）。
- **Step 4 closure 監査（codex）が自 closure の欠陥を検出**: (i) round-2 cursor の full 出力に secondary 指摘（root post-record 欠如・root label 解決制約）があり dissent 1 行だけ見て routing 漏れ、(ii) closure に事実・失敗節なし・決定と根拠が round-1/2 の採否を欠く、(iii)「success-faking 全て解消」が root post-check 欠如で過大、(iv) evidence anchor の包括表現が過大。→ 本 closure で是正（下記）+ **root post-record ownership check を追加**（link と対称化）。dissent 要約だけで満足せず full 出力を読む教訓。

**決定と根拠**:
- DJ-1: role:"root" 案（optional 第5引数で lib 拡張）を**棄却**し「判定述語を締める」を採用。棄却理由 = readers は `.role` field を読まず entry 存在から role を導出するため role:"root" は無効・既存 entry は全て parent 非空ゆえ述語締めは既存データに bit-identical で lib write path も無変更。
- SELF 生存確認 / corrupt entry fail-closed / 冪等時の label/workspace 保持 / link・root の ownership-aware post-check: いずれも「verb 側 guard の correctness・honesty を上げる」採用。既存 lib（`oe_reg_record`）は無変更を維持。
- guard の原子性: flock/CAS を**棄却**（last-write-wins registry 基盤の変更＝additive scope 外）。verb 側は SELF/target 生存確認 + ownership-aware post-check で「勝てなかった」の honest 検知に留め、race **防止**は基盤課題へ defer。
- F2「key と `.pane` 不整合」: guard は `_oe_reg_key` で引く（**key を信頼**）方針を採用（`.pane` 照合はしない）。oe-register 自身は key と `.pane` が常に一致する entry しか書かない（`oe_reg_record` の不変条件）。

**わかったこと（W）**:
- registry の role は `.role` field でなく **entry の存在**から read-time 導出される（`oe-ident:60-71` / `event-bus.sh:49,68-76`）。`parent_pane` 非空を足すと自己 root を child と誤導出しない。この「stored field でなく existence-derived」性質は #238 succession の topology 表現設計に直結。
- `oe-review` の cursor レーンは大 diff で timeout しやすい（round1 で 360s `timeout_empty`）。round2 で返り idempotency 退行を検出。

**原則（Pattern / Anti-pattern）**:
- Anti-pattern: 「reader は field X を読まないから field 値は moot」→ reader が field でなく **entry の存在 / 形**から派生値を導出していないか確認する（existence 派生は field 追加で直らない）。
- Pattern: last-write-wins state に verb 側 guard を足すとき、race 防止（原子性）は基盤の責務・verb は「勝てなかった」の honest 検知に留める（防止と検知を分ける）。

**蒸留シグナル**: 昇格候補 = **discussion/decision**（role の existence-based 導出 → #238/#257 succession/topology クラスタ）。skill/rule 昇格は **なし**。

**残課題**:
- 原子的 race 防止 / role:"root" / topology event 発行 → follow-up routing 参照（「追わない」or「昇格候補」）。
- **root の registry `--label` は他ペインから label 解決に使えない**（`oe_reg_resolve`/`oe_reg_list` が `parent_pane==$self` scope＝子のみ・root は parent 空で非該当。round-2 cursor 指摘）→ **追わない（lib 無変更の既存制約・oe-tree/cockpit で root は表示され jump 可なので実害小）**。root を label で send する需要が出たら lib 側で対応（engine track）。
- die-after-check / 並行 steal / root 並行上書きの post-check は stateful mock が要り単体テスト未整備 → **追わない**（実運用の稀パス・機能は防止でなく honest 検知）。

**Step 4（heavy 外部チェック・`so-compare` codex closure 監査）**: closure honesty の欠陥を検出 → 全て是正: (a) 事実・失敗節を新設、(b) 決定と根拠に round-1/2 の採否を追記、(c)「全て解消」の過大表現を訂正し **root post-record check を追加**（link と対称）、(d) root label 解決制約を routing、(e) evidence anchor を正確化。監査対象 = `tmp/so-closure-259/`（揮発）。**closure 監査が実 material 欠陥（routing 漏れ + code 非対称）を捕捉＝Step 4 の価値実証**。辞退せず実施して正解だった。

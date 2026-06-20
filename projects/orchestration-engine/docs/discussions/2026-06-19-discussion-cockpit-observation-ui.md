---
id: "01KVF1NCWEJAKMDCBZAADWTQEH"
title: "cockpit 観測UI（oe-status）設計探索 — read-only 俯瞰 + 監査ログ閲覧"
date: 2026-06-19
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/177"
    reason: "本探索の対象 Issue（cockpit 観測UI: 子エージェント状態俯瞰と監査ログ閲覧）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/169"
    reason: "cockpit 傘 Issue。#177 はその配下の並列トラック（依存なし）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-06-18-discussion-exploration-hard-layer-on-engine.md"
    reason: "3 ステージ表で #177 を Stage B メトリクスの read-only 表示と位置づけ。B/C は #177 計測後に判断（保留）"
  - type: source_material
    ref: "projects/orchestration-engine/schemas/session-state.schema.json"
    reason: "state KVS は『セッション完了時のみ』書き込み（DJ-2 の制約根拠）"
  - type: source_material
    ref: "projects/orchestration-engine/schemas/audit-log.schema.json"
    reason: "per-session audit jsonl のスキーマ（監査ログ閲覧の対象）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "#188 の確定（identity は基盤ごと・read 時相関）。本俯瞰の前提・§7 で back-propagation"
tags: [orchestration, cockpit, oe-status, observation, audit, read-only, discussion]
---

# cockpit 観測UI（oe-status）設計探索 — read-only 俯瞰 + 監査ログ閲覧

> pre-plan の設計探索ログ。**当初プランは設計SO で中核欠陥が判明し撤回**（§6）。#177 俯瞰は identity 統一（#188）の確定後に再設計する → **#188 確定済み（§7・[decision-188](../decisions/2026-06-19-decision-188-identity-unification.md)）: identity は基盤ごと・read 時相関・永続マップ無し。俯瞰の方式（query-side fusion or honest 2 ビュー）は #177 の判断**。
> 探索は調査サブエージェント（一次情報＝code/schema/issue 直読）+ オーナーとの DJ 確定で実施。

## 1. Context

`#177` は cockpit 傘 `#169` 配下の並列トラック（依存なし・即着手可）。中核制約は **read-only over state/audit**：状態の「検出」（プロセス/出力パターンマッチ）は非スコープで、既存の state/audit の「読み取り」に限定する。ペイン選択→送信導線は #176（CLOSED）が担当済。

設計 doc `2026-06-18-discussion-exploration-hard-layer-on-engine.md` は #177 を「Stage B が emit する探索メトリクスの read-only 表示・before/after 測定経路、LOGIC は載せない」と位置づける（`:41`）。ただし **Stage B/C は保留中で何も emit しない**（`:71`）。よって現時点の #177 が読むべきは **既存（Stage-A 以前）の state/audit のみ**。B 前提で設計すると空振りになる。[verified — doc `:41,:71`]

受入条件（issue 本文ママ）:
- 稼働中セッションの状態が一覧で俯瞰でき、blocked/timeout が識別できる（手動再現で確認）
- 監査ログから 1 セッションの流れ（start→end）が追える
- `shellcheck` パス

## 2. 既存資産マップ（#177 が乗る土台）

| 資産 | 現状の出力・state | 再利用点 | ギャップ |
|---|---|---|---|
| session-state KVS `state/{id}.state.json` | `{session_id, pane_id, state(enum6), last_updated, outputs[], blockers[]}` | 完了/blocked/timeout 俯瞰のデータ源。state enum で blocked/timeout 識別可 | **「進行中/待機」が原理的に取れない**。schema 明記「本 KVS は完了時のみ書き込む。実行中は wez capture のマーカースキャンで取得」（`session-state.schema.json:5`）→ 実行中=ファイル不在 |
| audit JSONL（本体）`audit/{id}.jsonl` | 1 セッション 1 ファイル・1 行 1 イベント `{ts, session_id, pane_id, event_type(12種), state, payload}` | 受入2「start→end を追う」を直接満たす。`lib/audit.sh:oe_audit_emit` と schema 一致 | per-session 分散。一覧→選択→時系列の導線が無い |
| audit JSONL（oe-refute）`audit/oe-refute.jsonl` | **別スキーマ・共有ファイル** `{ts, event_type:"oe_refute", audit_id, verdict, rubric, lanes, output_dir}` | refute 実行履歴 | session_id/pane_id を持たず本体と非互換（`bin/oe-refute` の audit 出力）→ session 単位 viewer で扱えない（DJ-4） |
| oe-list / `oe_reg_list` | 生存ペインを `PANE / SOURCE / LABEL` 3 列。SOURCE=pane-issue/spawn-registry/pane-title 優先解決（`lib/delegate-registry.sh:124-157`） | 「今どのペインに誰が」のラベル俯瞰。`oe-select` が既にこの出力を消費 | state/audit と未紐付け。pane_id はあるが session_id リンク無し |
| spawn registry `~/.claude/state/oe-delegate/{key}.json` | `{pane, label, workspace, parent_pane, role}` | 親が spawn した子の pane↔label↔workspace | session_id 無し |
| pane-issue state `~/.claude/state/pane-issue/{key}` | `{name:"#N slug"}` | #N↔pane ラベル | session 非リンク |
| oe-capture | attach→末尾N行で `@@OE_EXIT` マーカー走査→state/audit 記録 | capture 参照導線の起点（state/audit を書く側） | viewport-only（マーカーがスクロールアウトで回収不能） |
| wez CLI `projects/wezterm-ai-mode/lib/pane.sh` | `wez pane list/capture`、`_wez_pane_exists` 生存判定 | ペイン生存判定・capture プレビュー | WezTerm 接続前提。tmux fallback とどちらを正にするか（DJ-5） |

根拠は各セル内 file:line。[verified — 調査サブエージェントが実ファイル/スキーマ直読]

## 3. 設計判断（DJ）— 選択肢空間と確定

### DJ-1 UI 形態 → **確定: プレーン既定 + fzf 任意**
- (a) プレーン printf（oe-list 流・最小・cockpit ワンキー向き）
- (b) fzf 対話（oe-select の確立パターン + preview）
- (c) TUI 常駐（watch）— read-only/非検出方針と緊張（ポーリング=検出寄り）
- **採用 = (a)+(b)**: 既定はプレーン、`--interactive` で fzf+preview。(c) 棄却理由＝常駐ポーリングは「検出しない」線を侵食。

### DJ-2 「稼働中」表現 → **確定: `running?` のみ表示**（最大の論点）
- 制約: state KVS は完了時のみ書く → 実行中はファイル不在。進行中/待機の区別は capture マーカー走査＝**#177 が明記した非スコープ（検出）**。
- (a) **差分推定**: KVS あり=完了系（success/blocked/timeout 等を識別）、生存ペインで KVS 無し=`running?`（in-flight・不明）。read-only 維持。
- (b) capture マーカー走査で進行中/待機判定 → スコープ違反。
- (c) 完了系のみ俯瞰 → 受入1「稼働中の俯瞰」と解釈衝突しうる。
- **採用 = (a)**。**なぜ（code/diff から復元不可な根拠）**: KVS の「完了時のみ書き込み」契約（`session-state.schema.json:5`）が read-only での sub-state 取得を構造的に不可能にする。検出に踏み込まずに「稼働中の俯瞰」を成立させる唯一の線が差分推定であり、進行中 vs 待機の粒度は意図的に捨てる（粒度限界を doc 化）。受入1 の blocked/timeout 識別は完了系 KVS が満たす。
- **→ ADR 昇格 watch 対象**（closure で判断）: read-only 俯瞰の境界（検出を棄却した「なぜ」）は再利用価値があり、本機能の diff からは復元できない。

### DJ-3 pane_id↔session_id リンク → **確定: best-effort 最新ジョイン**
- state/audit は session_id 主キー（pane_id 保持）、oe-list/registry は pane_id 主キー（session_id 無し）→ pane_id でジョインするしかない。
- (a) **best-effort 最新**（同一 pane_id の最新 state を引く）/ (b) ジョインせず 2 表並置 / (c) registry に session_id を持たせる（書き込み発生=read-only 逸脱）。
- **採用 = (a)**。caveat（pane_id 再利用で古い完了 state を現役ペインに誤表示しうる）をコード/README に明記。

### DJ-4 audit スキーマ統一の要否 → **確定: v1 viewer 対象外（oe-refute.jsonl）**
- 本体 audit（per-session enum）と oe-refute audit（共有・別スキーマ）が非互換。
- (a) **per-session のみ対象、oe-refute は別ビュー/対象外** / (b) viewer 側で 2 スキーマ吸収 / (c) oe-refute を per-session 形式へ寄せる（#177 スコープ外の oe-refute 改修）。
- **採用 = (a)**。統一 or 別 viewer は別 issue に切る。

### DJ-5 データ源の正（wez vs tmux）→ **確定: tmux 既定**
- 既存は混在（`oe_reg_list`=tmux、`oe-select` preview=tmux、`oe-capture`=wez）。
- **採用 = tmux 既定**（生存判定/preview。`oe-select` と一致）、wez は接続時のみ。

### DJ-6 capture 参照導線 → **確定: 既存 audit の表示に限定**
- (a) 選択行から capture tail 表示 / (b) oe-capture 再実行（書き込み=read-only 逸脱）/ (c) 既存 audit の最新 state_change/session_end payload を表示。
- **採用 = (a)/(c) 寄せ**: `--interactive` の preview に audit timeline（既存 jsonl の整形）を出す。oe-capture 再実行（b）は read-only 逸脱で棄却。

## 4. 未解決の問い / リスク
- **受入1 と DJ-2 の解釈整合**: 「稼働中の俯瞰」を `running?`（sub-state 無し）で満たすと合意済だが、運用で粒度不足が顕在化したら Stage-B 着手時に再検討（B が実行中メトリクスを emit すれば解消）。[該当判断はオーナー確認済]
- **pane_id 再利用によるジョイン誤表示**: pane kill 後の番号再利用で古い完了 state を誤表示しうる。caveat 明記で緩和、完全解は session_id リンク（read-only 逸脱）が要る。[speculation — tmux/wez の pane 再利用挙動は未検証]
- **2 系統 audit スキーマ**（DJ-4）: viewer 複雑度を上げる。統一は #177 スコープ外。

## 5. 昇格・追跡
- **Decision 昇格**: closure（episode-retrospective Step 3 蒸留シグナル）で判断。候補 = DJ-2。残 DJ は局所的で「なし」見込み。判断自体は必ず明示する。
- 昇格捕捉点の堅牢化（advisory→同期ゲート）は **#156**。
- Stage B メトリクス表示は B 着手後（#177 はそれを前提にしない）。

## 6. 設計SO 結果とピボット（2026-06-19）

設計SO（`so-compare --with codex,cursor`、出力 `tmp/so-20260619-132242/`・揮発）で **DJ-3 の pane_id ジョインが構造破綻**と判明（codex/cursor が独立収束・オーナーが一次確認）:
- `oe_reg_list` は tmux `%N`（`lib/delegate-registry.sh:129`）、state/audit の `pane_id` は wez 整数（`schemas/session-state.schema.json:14-17`）→ **別キー空間でジョイン不成立**。[verified]
- 付随: CB timeout は audit のみ（`lib/monitor.sh:136`・pane_id=0 プレースホルダ）／ delegate 子は state/audit を書かない → KVS だけの俯瞰は不足。[verified]

**無効化された DJ**: DJ-3（best-effort ジョイン）と DJ-2 の前提（KVS＝完了源で俯瞰が成立する）。一方 §2 資産マップ（事実）と DJ-1/4/5/6（UI 形態・oe-refute 対象外・tmux 既定・capture 導線）は #177 再開時も有効。

**ピボット決定（オーナー）**: 2 基盤の identity 分裂を root-cause として先に解決する **#188（オーケストレーション2基盤の identity 統一）** を起票。**#177 俯瞰は #188 の解決/設計確定後に再設計**（session/audit-first か別建て観測かは #188 で決める）。当初 plan doc（`docs/plans/2026-06-19-plan-177-oe-status.md`）は撤回・削除済。

## 7. #188 の確定（2026-06-19・#188 → #177 back-propagation）

#188（identity 統一）が確定し、#177 を unblock した。決定の要点（正本は [decision-188](../decisions/2026-06-19-decision-188-identity-unification.md)）:

- identity は **pane 層で統一しない**。2基盤は別多重化レイヤの別物理エンティティで対応が存在しない（実機観測: tmux は単一 WezTerm pane 内・engine の wez split 子は tmux 不可視・delegate の tmux 子は wez 不可視）。engine の session-state/audit を delegate に拡張する案も棄却（category error + `pane_id:integer` 固定 schema の breaking change + #114 で陳腐化）。
- identity は基盤ごとに保持し、相関が必要なら **read 時に行う（永続マップ無し）**。これは #177 の read-only 制約を満たす（issue 受入の「相関しないと明示決定」に該当）。
- 永続横断観測が要るときは session-state 拡張でなく `session_id` 主キーの event bus（deferred・Stage-B）。

**#177 への含意（#188 はロックしない・方向の申し送り）**:

- §6 で無効化された DJ-3（pane_id ジョイン）は復活しない。俯瞰は「生存ペイン ↔ session 状態を pane で join」ではなく、**read 時に両ソース（engine: wez + state/audit／delegate: tmux + registry）を `kind`/`mux` 列付き1テーブルに投影（join しない・delegate 行は `timeline:none`）= query-side fusion**、または honest 2 ビュー。どちらを採るかは #177 再設計時に決める（設計SO の codex/cursor は query-side fusion に収束）。
- 有効な DJ-1/4/5/6（UI 形態・oe-refute 対象外・tmux 既定・capture 導線）は引き続き使える。

## 8. DJ-2/DJ-3 再設計の確定（2026-06-20・#177 実装着手・predecision-exploration 証跡）

§7 で #188 が unblock した俯瞰方式（query-side fusion 単一ビュー or honest 2 ビュー）を #177 実装着手にあたり確定する。確定前に **predecision-exploration**（ゼロベース代替＋確定前証跡）を engine 統合経路 `oe-refute --rubric exploration --lanes 2`（codex+cursor）で **2 ラウンド**回した。両ラウンドとも verdict=`refuted` だったが、**反証は「カテゴリ」ではなく「過剰主張」と「grounding 詳細」に収束**したため、それらを設計へ織り込んだ上で確定する（exploration rubric は「迷ったら refuted 寄り」＝設計の残不確実性では survived を返しにくい。verdict は advisory・REASON 内容が正本：predecision-exploration / so-verdict 規約）。

### 8.1 設計SO の証跡（揮発 output_dir の verdict/reason を転記）

- **R1**（claim=flat 1テーブル fusion + 素朴 audit-tail。`audit_id=202606201236549TGTSWFP090S`）→ **refuted**。
  - codex: 「audit-tail reducer・CB/multi-pane 合成・tmux liveness の非検出扱い・**単一画面 typed sections 案**が未確定」。
  - cursor: 「audit-tail 単独完全性・CB/taxonomy 写像・interrupt/attach 終端・『最も適合』比較優位が未検証/コード矛盾、**structured honest-2** 等の未探索代替が残る」。
  - → **新カテゴリ「単一コマンド・typed sections（structured honest-2）」が出た**。flat fusion は engine/delegate の異質な STATE/TIMELINE 列を混同する欠陥が判明。
- **R2**（claim=typed sections + audit-terminal reducer。R1 反映済。`audit_id=20260620124213Q2FXT4JXYFJA`）→ **refuted（収束）**。
  - 両レーンとも「**typed sections 自体は有望**」と合意（カテゴリ収束）。残る指摘は (a) `verification_timeout` の誤分類、(b) multi-pane 要約が blocked を隠す、(c) interrupt が部分 session_end 後に誤分類、(d) max_turns/max_panes 表示と受入1「blocked」文言のずれ、(e) CB payload schema(`limit_type`)↔実装(`reason`)不一致、(f) 「honest 2 より優れる」優位主張が ADR 上未立証、(g) read-only/非検出境界の preview 不統一。
  - **新カテゴリは出ず**（残りは grounding 詳細 ＋ owner 既決の scope-split 再掲）。→ predecision-exploration の暫定停止条件（新カテゴリが出なければ確定可）を満たす。これ以上の exploration-refute 反復は lateral repetition（reframe-on-stall の stall）と判断し、grounding を設計へ織り込んで確定する。
- 生出力: `tmp/oe-refute-202606201236549TGTSWFP090S/` ・ `tmp/oe-refute-20260620124213Q2FXT4JXYFJA/`（揮発）。claim doc: `tmp/dj-2-3-claim.md` / `tmp/dj-2-3-claim-v2.md`。

### 8.2 確定（DJ-2/DJ-3 再設計）

- **DJ-2再 / DJ-3再 確定 = 単一コマンド・typed sections（query-side fusion を正直に描画した形）**。1 回の `oe-status` で read 時に両ソースを投影し、**列融合せず区画ごとに適切な列**を持つ:
  - `=== ENGINE (wez · state/audit) ===`: 行=engine session。STATE は **audit-terminal reducer** 由来（§8.3）。state file があれば outputs/blockers を補足。
  - `=== DELEGATE (tmux · liveness) ===`: 行=`oe_reg_list` の生存ペイン。**liveness のみ・TIMELINE 列を持たない**（timeline:none を区画レベルで正直に表現）。
- **優位主張は取り下げる**（R2(f) 反映）。本確定は「honest 2 ビューより優れる」証明に依らない。**owner/cockpit が query-side fusion 方向を既決（kickoff 方針・%32 agree）**であり、typed sections はそれを #188 制約下で正直に描画した**十分**な形（受入1〜3 を満たす）という根拠で確定する。honest 2 ビューは #188 ADR で「◯ 機能充足」とされ等価に近い＝本確定は UX 上の単一画面化であって受入の優劣判断ではない。
- **scope-split（engine-only + delegate は oe-list 委譲）は owner 既決で不採用**（kickoff: delegate 行を本ツールに含める）。再 litigate しない（R2 breadth 指摘への回答）。

### 8.3 audit-terminal reducer の確定仕様（grounding 反映）

`audit/{ULID}.jsonl` の全イベントを走査し（**末尾行でない**。`cleanup`/`verification_*`/`polling_snapshot` は STATE 導出から除外）、終端シグナルを集めて **severity-max（worst が勝つ）**で 1 つの session-level STATE を導く:

- 終端シグナル収集:
  - `session_end` の各 `state`（success/blocked/partial/retryable_failure/protocol_error/timeout）。
  - `circuit_breaker_triggered` の `payload.reason`（無ければ `payload.limit_type` にフォールバック＝schema 不一致 R2(e) への防御）:
    - `timeout` → `timeout`
    - `max_turns` / `max_panes` → `blocked`（circuit-breaker-design DI-4 の taxonomy 写像。受入1「blocked」文言に合わせる。R2(d)。reason は注記）
    - `verification_timeout` → **session 終端に寄与しない**（verify フェーズは monitor 成功後＝target は session_end 済。R2(a) target lifecycle と verification lifecycle の混同を回避。「verify timeout」は注記）
  - `interrupt` → `interrupted`。
- severity 順（worst→best）: `protocol_error > timeout > blocked > retryable_failure > partial > interrupted > success`。終端が複数（multi-pane/部分完了+interrupt）でも worst を採るため **blocked/timeout/interrupt が success に隠れない**（R2(b)(c) 解消・受入1 を multi-pane でも満たす）。
- 終端シグナル無し ＋ `session_start` あり → `running?`（in-flight **または** 孤児/クラッシュ＝read-only では区別不能。限界明記。wez 生存オーバーレイは DJ-5「wez 接続時」の follow-up に defer）。
- いずれも無し → `?`（unknown）。
- KVS の位置づけ（R1 緩和）: STATE は audit-terminal が権威（CB-only 終了は KVS 未書込）。KVS は outputs/blockers/verification_summary の**補足**（排除しない）。audit 不在で state file のみのセッションは KVS の `state` を表示し「kvs-only」注記。

### 8.4 read-only / 非検出境界の確定（R2(g) 反映で preview を統一）

- 「検出」（非スコープ）= ペイン**出力/内容**の走査（oe-capture の marker scan・polling 常駐）。
- oe-status が触れるのは (1) state/audit **ファイル**、(2) tmux/wez **ペイン存在**（mux liveness query・oe-list/oe-select と同類）のみ。**ペイン出力は一切読まない**。
- `--interactive` の preview: ENGINE 行=**audit timeline 表示**（DJ-6）/ DELEGATE 行=**registry メタ情報のみ**（label/source/pane。`tmux capture-pane` は使わない＝oe-select の借用をやめ、区画間で境界を統一）。これで「state/audit + ペイン存在のみ」を厳守し read-only を airtight にする。

### 8.5 スコープ外として routing する発見（実装しない・implementer-contract）

- **CB payload の schema↔実装ドリフト**（audit-log.schema.json は `limit_type` 記述・実装は `reason` emit）。#177（read-only 観測）の範囲外。reducer は `reason` 優先＋`limit_type` フォールバックで両対応し、ドリフト自体の是正は別 issue に routing（episode に記録）。
- `--dry-run` 列検証（#188 handoff 残）は **fixture audit/state → 出力 assert のテストスイートが機械検証として代替**（dry-run フラグは v1 で作らない）。

これらにより DJ-2/DJ-3 を再確定し、#177 実装に進む。DJ-2（read-only 俯瞰の境界＝検出を棄却した「なぜ」）の Decision 昇格は closure で判断（§5）。

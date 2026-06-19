---
id: "01KVFGDQNXQ96TJCEDYB39KJ5B"
title: "オーケストレーション2基盤の identity 統一（#188）— 設計探索"
date: 2026-06-19
type: discussion
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/188"
    reason: "本探索の対象 Issue（2基盤の identity 分裂を独立タスクとして解決）"
  - type: source_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/177"
    reason: "出自。#177 俯瞰の設計SOで pane_id ジョイン破綻が判明 → 本 Issue を切り出し。#188 の消費者"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md"
    reason: "#177 設計探索ログ。§6 で identity 分裂を root-cause と特定しピボット"
  - type: source_material
    ref: "projects/orchestration-engine/lib/spawn.sh"
    reason: "engine spawn = wez pane split（wez 整数 pane_id）"
  - type: source_material
    ref: "projects/orchestration-engine/lib/delegate-registry.sh"
    reason: "delegate registry = tmux %N キー・per-child レコード"
  - type: source_material
    ref: "projects/orchestration-engine/lib/session.sh"
    reason: "session_id は pane 非依存生成（ULID 形式）"
tags: [orchestration, identity, cockpit, observation, wez, tmux, discussion]
---

# オーケストレーション2基盤の identity 統一（#188）— 設計探索

> pre-plan の設計探索ログ。**設計SO 完了・DJ 確定済み（§7-§9）**。設計判断はオーナー委任（#188 子セッション）+ 設計SO（codex gpt-5.5 + cursor）で確定。親 gate は PR 時 intent-check に緩和（オーナー指示 2026-06-19）。
> 探索: read-only 調査サブエージェント（一次情報＝code/schema 直読）+ **実機観測**（runtime topology を直接確認）+ 設計SO（選択肢拡張つき）。

## 1. Context

`#188` は #177（cockpit 観測UI）の設計SOで「生存ペイン × session 状態を `pane_id` でジョイン」案が構造破綻したのを root-cause として切り出した Issue。問いは「2基盤の identity をそもそも統一すべきか／するならどの方式か」（解決策は未確定・presume しない）。

2基盤:
- **engine `oe`**（自律パイプライン）: `wez pane split` で子を作る → **wez 整数** pane_id。state KVS（完了時のみ）+ audit jsonl を session_id 主キーで書く。
- **delegate**（対話 Claude 子）: `tmux split-window` で子を作る → **tmux `%N`**。registry のみ（state/audit を書かない）。

## 2. 調査結果（一次情報 + 実機観測）

### 2.1 コード直読（サブエージェント・file:line）

| 問い | 結論 | 根拠 | status |
|---|---|---|---|
| engine spawn identity | `wez pane split` の戻り値＝**非負整数** pane_id。`^[0-9]+$` 検証あり | `lib/spawn.sh:12`、`projects/wezterm-ai-mode/lib/pane.sh:189-193`、`schemas/session-state.schema.json:14-17` | verified |
| delegate registry 構造 | per-child JSON `{pane, label, workspace, parent_pane, role:"child"}`。キー= `server_pid_pane`。pane は tmux `#{pane_id}`（`%N`） | `lib/delegate-registry.sh:45-65`、`:26-31` | verified |
| session_id 出自 | **pane 非依存**。`date -u +%Y%m%d%H%M%S`(14) + base32 random(12) の ULID 形式 | `lib/session.sh:4-20` | verified |
| delegate 子は state/audit を書くか | **書かない**。oe-delegate → oe-send → `tmux send-keys` のみ。audit は engine の `oe_audit_emit` だけ | `bin/oe-delegate:145` → `bin/oe-send:57` → `lib/delegate-send.sh`（send-keys のみ） | verified |
| delegate 子に session_id はあるか | **無い**。session_id を生成・記録するのは engine 経路のみ。delegate は registry の pane キーだけ | 上記の連鎖（session.sh は engine 経路で呼ばれる） | verified |

### 2.2 実機観測（runtime topology — 本件の決定打）

調査サブエージェントは「wez ペイン内で tmux が動くか（coexist か完全分離か）は file:line で確定できない」と限界を明示した。これを実機プローブで確定した:

```text
# 自セッション（#188 子）の環境
TMUX_PANE=%33   WEZTERM_PANE=0   TERM_PROGRAM=tmux

# tmux list-panes -a → 5 ペイン（すべて WezTerm pane 0 の内側）
%0 win=1 #43 / %3 win=2 #183 / %32 win=3 #177(親) / %33 win=3(自分) / %27 win=7

# wez pane list → wez ペインは pane_id:0 ただ1つ
```

**確定した topology**（verified — 実機直接観測）:
- **tmux が WezTerm pane 0 の内側で動いている**（自分が `TMUX_PANE=%33` かつ `WEZTERM_PANE=0`）。現存する全 tmux ペイン（親 `%32` 含む）は wez からは pane 0 に潰れて**個別に見えない**。
- したがって2基盤は「同じ物理ペインの別ID体系」ではなく、**別多重化レイヤの別物理エンティティ**:
  - engine の `wez pane split` 子 = tmux の**外**に新 WezTerm ペイン（1,2…）→ **tmux からは不可視**（`%N` を持たない）。
  - delegate の `tmux split-window` 子 = wez pane 0 の**内**の tmux ペイン → **wez からは不可視**（pane 0 に潰れる）。
- **マップすべき pane↔pane の対応関係がそもそも存在しない。** `%5` と wez `5` が違うどころか、片方の世界の子はもう片方の世界に実体として現れない。

> 残差: 「engine 子が tmux 不可視」は spawn.sh:12 + topology からの強い推論（live な engine 子の直接観測は未実施。wez-split ペインは tmux を起動しない限り tmux に属さず、engine はそこで agent を直接走らせる）。[verified-by-architecture]

## 3. 設計空間の絞り込み（調査が効かせた絞り）

Issue が挙げた候補に実機証拠を当てると、空間は大きく縮む:

| 候補（Issue 由来） | 実機証拠による判定 |
|---|---|
| B: engine が tmux `%N` を併記（dual-key） | **物理的に不成立**。engine 子は WezTerm ペインで tmux に属さず、自分の `%N` を持たない（取得対象が存在しない）。 |
| C: wez-primary 俯瞰（`wez pane list` 整数一致） | **delegate 子が原理的に載らない**。tmux 子は wez pane 0 に潰れ個別 ID を持たない。engine 子だけの俯瞰になる。 |
| A: spawn 時 `session_id↔wez↔tmux↔label` マッピング表 | **F に縮退**。各 session は wez か tmux の**片方の identity しか持たない**（両方を持つ session は存在しない）→ 表は実質 `session_id → {mux, pane}` の1対1属性。 |

→ 実質の判断軸は2つに収斂:

- **D（統一しない・honest）**: マッピングを作らない。#177 は engine 側（wez 生存 + state/audit）と delegate 側（tmux 生存 + registry）を**2つの honest な別ビュー**として読む。書込ゼロ・read-only 純度最大。代償: 単一俯瞰にならない。`session/audit-first`（state/audit を持つ engine のみ session 俯瞰、delegate は registry 別建て）はこの系列の非対称変種。
- **F（session 層で統一）**: pane-ID 層ではなく **session_id を主キー**にして両基盤が session レコードを書く。pane id は `{mux: wez|tmux, id}` の**属性に降格**。#177 は1つの session ストアを読み、native な生存ハンドルで pane 突合。代償: **delegate 経路に session レコード書込を新設**（現状 registry のみ）。ただし registry は既に per-child レコードを持つ → 「registry に session_id + mux タグを足す」程度に収まる可能性があり、コストは見かけより小さいかも（要 plan 精査）。

## 4. ゼロベース再フレーム（調査が生んだ視点転換）

Issue タイトル「identity 統一（tmux %N ↔ wez pane_id）」は**2つの ID 空間の間にマッピングを張る**前提を含む。実機証拠はその前提を否定する — **張るべき対応が無い**（別レイヤの別物）。

- 正しい問いの立て直し: 「2つの pane-ID をどう対応づけるか」ではなく、「identity を**両多重化レイヤの上位＝session 層**に持ち上げるか（F）、それとも2世界を honest に並置するか（D）」。
- pane-ID 層の解（A/B/C）は**アーキテクチャと戦う**ことになる。B/C は物理的に不成立、A は F に縮退。
- 付随の整理: 「read-only 制約」は**観測者（#177）を縛るもの**であり、spawn 時の書込は**元からある書込経路**。F の session レコード書込は spawn/delegate 時に起き、観測者の read-only を破らない（Issue Q3「どの経路が書くか」への答え = spawn/delegate 経路）。[speculation — 制約解釈。SO/gate で検証]

## 5. 未解決の問い（設計SO へ）

1. **D vs F の選択**: #177 の価値は「単一俯瞰」を要求するか、honest 2ビューで足りるか。2基盤は観測セマンティクスが異質（engine=自律 state 中心 / delegate=対話 liveness+label 中心）→ 無理な単一スキーマ統一は category error かもしれない（D 寄りの論拠）。一方 F は将来の Stage-B メトリクス/#177 を1基盤に載せられる。
2. **F なら delegate session レコードの粒度**: delegate 子は engine のような完了イベントを持たない（対話・親/人が駆動）。記録は spawn 時の liveness+label に留まる → 実質「registry の session 化」。session_id を delegate にも振るか。
3. **#177 への影響**: D なら #177 は2ビュー前提で再設計、F なら単一 session ビュー前提で再設計。
4. **#114（クリーン出力チャネル）との相互参照**: #114 が `claude -p` file-redirect 化を進めると観測基盤が再形成され identity モデルに影響しうる。F の投資が #114 で陳腐化しないか。

## 6. 次の一手

- 本 doc の §3-§5 を入力に **設計SO（`so-compare --with codex,cursor`・選択肢拡張つき）** を投入し、D/F 以外の見落とし選択肢と各案の欠陥を洗う。→ §7 で実施。
- 投入可否は親 `%32` の gate を仰ぐ（中間報告済）。→ オーナーが「設計判断を委任・PR 時 intent-check」に緩和。以降 autonomous。

## 7. 設計SO 結果（2026-06-19・codex gpt-5.5 + cursor auto・選択肢拡張つき）

出力 `tmp/so-188-design/`（揮発・gitignore）。両者が**独立に同じ再フレームへ収束**:

- **収束1**: topology + B/C/A 棄却は一次情報と整合（追認でなく検証）。[verified — 両者が code/schema 直読]
- **収束2**: **#177 受入は「単一俯瞰／単一 identity」を要求していない**（§3 の暗黙前提 A1 は偽）。受入＝稼働俯瞰 + blocked/timeout 識別／1セッション start→end 追跡／read-only。「1画面ジョイン」は受入文言に無い。破綻したのは #177 DJ-3 の **pane_id ジョイン (a)** であって、2表並置 (b) は topology 問題ではない。[verified — issue 受入文言 + cockpit doc §6]
- **収束3**: **案F（engine session-state/audit を delegate に拡張）は二重に不可**:
  - (i) **category error** — 対話 delegate 子は success/blocked/timeout の完了 lifecycle を持たない。engine の `state` enum に押し込むと「見た目は統一・意味論は非対称」になる（嘘になる）。
  - (ii) **schema breaking change の過小評価** — `schemas/session-state.schema.json:14` と `audit-log.schema.json` が `pane_id: integer`（WezTerm）で固定。`{mux,id}` 化は state + audit 両方の破壊変更。「registry に session_id+mux を足すだけ」では済まない。[verified — schema 直読]
- **収束4**: **#114 が F の動機を弱める**。pane 非依存の `session_id` は #114（`claude -p` + file-redirect 化）後も残るが、`pane_id` 属性は engine の tmux 化／file-redirect 化で陳腐化。
- **収束5**: read-only = 観測者拘束（仮定 A3 妥当）。spawn/delegate producer の書込は別レイヤで、#177 DJ-3(c) 棄却（観測UIが書く案）とは別。

選択肢拡張で出たゼロベース代替（D/F の小変形でない・両者で概念が重複）:

| 代替 | 差分軸 | 成立条件 / 検証 |
|---|---|---|
| **query-side fusion（読取時融合）** | データフロー: 永続マップ無し。#177 が read 時に wez+state/audit と tmux+registry を読み、`kind`/`mux` 列付き1テーブルに**投影**（join しない・delegate 行は `timeline:none`） | 受入が「単一 schema」でなく「単一 view」を許容。`oe-status --dry-run` 試作で列定義が破綻しないか。**両者が #177 に最も堅いと収束** |
| **#177 スコープ分割（第3の道・#188 不要化）** | 責務分界: #177 = engine-only cockpit、delegate 俯瞰は既存 `oe-list`/`oe-select` に委ねる | #177 受入を「自律 pipeline セッション」に明文化 → ジョイン問題が消える |
| **typed event/activity bus** | 技術カテゴリ: session-state KVS でなく `~/.claude/state/oe-events.jsonl` に全 spawn 経路が append-only emit。識別統一＝**イベント型の統一**（pane でなく） | 各 spawn 経路に thin emitter。#114 後も残る。Stage-B 着手時の永続横断観測の本線候補 |
| （実行基盤収束 #114 駆動 / parent-scoped hub） | 実行経路を1 mux に寄せる / 観測起点を親ペインに置く | #114 と同一スレッドで評価すべき・別 issue 寄り |

両者の推奨: **#177 を急ぐなら query-side fusion が最も堅い。永続 write を入れるなら F でなく typed event bus 寄り。session-state を delegate に拡張する案は今のコードと #114 の両方に対して筋が悪い。**

## 8. 設計判断（DJ・#188 の結論）

issue 受入が「観測ツール(#177)が相関できる、**または**『相関しない（別建て観測）』と明示決定され #177 が再設計可能になる」を許容することに基づき、SO の収束を踏まえ確定（オーナー委任の下で本セッションが確定）:

- **DJ-188-1: pane-ID 層で identity を統一しない。** 2 つの pane-ID 空間（wez 整数／tmux `%N`）は別多重化レイヤの別物理エンティティで対応が存在しない＝現行2-spawn-path アーキテクチャ（engine=`wez pane split`／delegate=`tmux split-window`）の**不変条件**。案B/C は物理的に不成立、案A は F に縮退。
- **DJ-188-2: engine の session-state/audit スキーマを delegate に拡張しない（案F 棄却）。** 理由＝(i) category error（非対称 lifecycle）/ (ii) `pane_id: integer` 固定 schema の破壊変更 / (iii) ROI が Stage-B（保留中）まで繰延 / (iv) #114 で陳腐化。
- **DJ-188-3: identity は基盤ごとに保持し、相関が必要な場合は read 時に行う（永続マッピングを作らない）。** これが #177 の read-only 制約を満たす（観測者は両ソースを読むだけ・新規永続書込なし）。issue 受入の「相関しないと明示決定」に該当する確定。
- **DJ-188-4: 将来 Stage-B で永続横断観測が必要になった場合は、session-state 拡張でなく `session_id` 主キーの typed append-only event/activity bus を採る。** 本 issue では実装しない（deferred）。
- **DJ-188-5（受入3・read-only/write-path 整合）**: 「read-only」は観測者（#177）を縛る制約。既存の producer 側書込（delegate spawn 時の registry、engine 完了時の state/audit）は残る。本決定は新規書込経路を導入しない。

> **昇格**: 本 DJ 群は topology 不変条件 + 「session-state を拡張せず event bus」原則を含み、#177/#114/Stage-B に再利用される横断的アーキ判断 → **Decision/ADR への昇格対象**（closure の episode-retrospective Step3 で最終判断、本件は昇格濃厚）。

## 9. #177 への handoff（#188 スコープ外・方向の申し送りのみ）

- #188 は identity モデルを「基盤ごと・read 時相関・永続マップ無し」と確定し、**#177 を unblock する**。#177 の再設計そのもの（query-side fusion の単一ビュー or honest 2 ビュー）は **#177 の判断**であり、#188 はロックしない。
- 推奨方向（非拘束）: query-side projection（単一 cockpit ビュー + `kind` 列、delegate 行は liveness+label のみ・`timeline:none`）。#177 当初 DJ-1/4/5/6（UI 形態・oe-refute 対象外・tmux 既定・capture 導線）は再開時も有効。
